extends SceneTree

const CLUSTER_SCENE := preload("res://scenes/world/components/nearby_sector_cluster.tscn")
const HUD_SCENE := preload("res://scenes/ui/hud.tscn")
const GameFlowScript := preload("res://scripts/game/game_flow.gd")
const StoreScript := preload("res://scripts/persistence/user_data_store.gd")
const FilesystemScript := preload("res://scripts/persistence/user_data_filesystem.gd")

class MemoryFilesystem extends FilesystemScript:
	var files: Dictionary = {}
	var refuse_payment := false
	func file_exists(path: String) -> bool: return files.has(path)
	func directory_exists(_path: String) -> bool: return false
	func ensure_parent_directory(_path: String) -> Error: return OK
	func read_bytes(path: String, maximum_bytes: int) -> Dictionary:
		if not files.has(path):
			return {"error": ERR_FILE_NOT_FOUND, "bytes": PackedByteArray()}
		var bytes := (files[path] as PackedByteArray).duplicate()
		return {"error": OK if bytes.size() <= maximum_bytes else ERR_FILE_CORRUPT,
			"bytes": bytes if bytes.size() <= maximum_bytes else PackedByteArray()}
	func write_bytes_and_flush(path: String, bytes: PackedByteArray) -> Error:
		var document: Variant = JSON.parse_string(bytes.get_string_from_utf8())
		if refuse_payment and document is Dictionary and str((document.get("commit", {}) as Dictionary).get("id", "")).begins_with("game-flow-reward-"):
			return ERR_CANT_CREATE
		files[path] = bytes.duplicate(); return OK
	func remove_path(path: String) -> Error:
		if not files.has(path): return ERR_FILE_NOT_FOUND
		files.erase(path); return OK
	func rename_path(from_path: String, to_path: String) -> Error:
		if not files.has(from_path): return ERR_FILE_NOT_FOUND
		files[to_path] = (files[from_path] as PackedByteArray).duplicate()
		files.erase(from_path); return OK

class CargoWorld extends Node3D:
	var cluster: NearbySectorCluster
	func get_nearby_sector_cluster() -> Node:
		return cluster

class RefusingDiskFilesystem extends FilesystemScript:
	var refuse_payment := false
	var refuse_debt := false
	var refuse_sync := false
	func write_bytes_and_flush(path: String, bytes: PackedByteArray) -> Error:
		var document: Variant = JSON.parse_string(bytes.get_string_from_utf8())
		if document is Dictionary:
			var commit_id: String = str((document.get("commit", {}) as Dictionary).get("id", ""))
			if (refuse_payment and commit_id.begins_with("game-flow-reward-")) or (refuse_debt and commit_id.begins_with("cinder-cargo-delivery-")):
				return ERR_CANT_CREATE
		return super.write_bytes_and_flush(path, bytes)
	func sync_directory(path: String) -> Error:
		if refuse_sync and FileAccess.file_exists(path):
			var document: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if document is Dictionary and str((document.get("commit", {}) as Dictionary).get("id", "")).begins_with("game-flow-reward-"):
				refuse_sync = false
				return ERR_UNAVAILABLE
		return OK

var _assertions := 0
var _failures := PackedStringArray()
var _reward_calls := 0
var _current_flow: GameFlow


func _init() -> void:
	call_deferred(&"_run")


func _accept_reward(request: Dictionary) -> Dictionary:
	_reward_calls += 1
	return _current_flow.call("_commit_game_flow_activity_reward", request)


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() == 3 and args[0] == "--cinder-debt-child":
		await _run_disk_child(args[1], args[2])
		return
	var filesystem := MemoryFilesystem.new()
	var store := StoreScript.new("memory://cinder-cargo-delivery.json", filesystem)
	_check(bool(store.load().accepted), "the existing atomic store loads")
	_check(bool(store.commit({"foreign": {"accessibility": "retained"}}, 0, "seed").accepted),
		"foreign user data is seeded before cargo completion")

	var first := await _make_runtime(store)
	var first_binding := first.binding as NearbySectorActivityBinding
	var fixture := _build_fixture()
	first_binding.set("_cargo_activity", fixture.activity)
	first_binding.set("_cargo_authority", fixture.authority)
	first_binding.set("_cargo_source_entity", fixture.source)
	var bound := (first.flow as GameFlow).bind_cinder_cargo_delivery_persistence(first_binding)
	var reward_bound := first_binding.configure_cargo_reward_handoff(
		Callable(self, &"_accept_reward")
	)
	var delivered := _complete(first_binding)
	var generation := int((fixture.activity as CargoDeliveryActivity).get_generation())
	var read_through := first_binding.request_cargo_reward(generation)
	var duplicate := first_binding.request_cargo_reward(generation)
	var persisted := first_binding.get_cinder_cargo_delivery_persistence_snapshot()
	_check(bool(bound.accepted) and bool(reward_bound.accepted) and bool(delivered.accepted)
		and bool(read_through.accepted) and not bool(duplicate.accepted)
		and _reward_calls == 1 and int(store.get_generation()) == 3,
		"ledger completion and generation-matched reward handoff commit one durable receipt")
	_check((store.get_snapshot().foreign as Dictionary).accessibility == "retained"
		and not bool(((persisted.delivery as Dictionary).reward_receipt as Dictionary).replay_allowed)
		and not bool(((persisted.delivery as Dictionary).transfer_receipt as Dictionary).replay_allowed),
		"both replay fences merge without replacing foreign store data")
	var paid_before: Dictionary = store.get_snapshot()
	var persistence: CinderCargoDeliveryPersistence = CinderCargoDeliveryPersistence.new()
	persistence.configure(store, CinderCargoDeliveryPersistence.SLOT_ID)
	_check(persistence.save(fixture.activity, fixture.authority, "paid-downgrade-attempt").accepted and store.get_snapshot() == paid_before and store.get_generation() == 3, "same terminal readback cannot downgrade its authoritative paid acknowledgement")
	await _retire(first, fixture)

	var reloaded_store := StoreScript.new("memory://cinder-cargo-delivery.json", filesystem)
	var second := await _make_runtime(reloaded_store)
	var second_binding := second.binding as NearbySectorActivityBinding
	var rebound := (second.flow as GameFlow).bind_cinder_cargo_delivery_persistence(second_binding)
	var restored := second_binding.get_snapshot().cargo as Dictionary
	var view := (second.hud as GameHUD).set_nearby_activity_snapshot(second_binding.get_snapshot())
	var card := _cargo_card(view)
	var world := (second.cluster as NearbySectorCluster).get_cinder_cargo_access().get_cargo_presentation_state()
	var replay := second_binding.request_cargo_reward(int(restored.get("generation", 0)))
	_check(bool(rebound.accepted) and int(restored.state) == CargoDeliveryActivity.State.COMPLETED
		and int(restored.generation) == 1 and bool(restored.delivery_persisted)
		and (restored.accepted_receipt as Dictionary).is_empty(),
		"reload restores delivered presentation without transfer receipt inventory authority")
	_check((card.cargo_progress as Dictionary).stage_id == &"delivery_recorded"
		and "DELIVERY RECEIPT SAVED" in str((card.cargo_progress as Dictionary).summary)
		and world.state_id == &"committed" and world.geometry_state == &"delivered",
		"retained HUD and route-cue geometry show the saved delivery")
	_check(not bool(replay.accepted) and replay.reason == &"cargo_reward_unavailable"
		and _reward_calls == 1 and int(reloaded_store.get_generation()) == 3,
		"restored presentation cannot replay cargo reward or mutate the store")

	var fresh_fixture := _build_fixture()
	second_binding.set("_cargo_activity", fresh_fixture.activity)
	second_binding.set("_cargo_authority", fresh_fixture.authority)
	second_binding.set("_cargo_source_entity", fresh_fixture.source)
	second_binding.call("_bind_cargo_reward_handoff")
	var fresh := second_binding.start_cargo_run()
	second_binding.submit_cargo_phase(&"load_crate")
	var active := second_binding.get_snapshot().cargo as Dictionary
	_check(bool(fresh.accepted) and int(active.state) == CargoDeliveryActivity.State.ACTIVE
		and not bool(active.get("delivery_persisted", false))
		and int(active.next_phase_index) == 1 and int(reloaded_store.get_generation()) == 3,
		"a fresh incomplete manifest run stays session-scoped and overrides summary presentation")
	await _retire(second, fresh_fixture)

	var third_store := StoreScript.new("memory://cinder-cargo-delivery.json", filesystem)
	var third := await _make_runtime(third_store)
	var third_binding := third.binding as NearbySectorActivityBinding
	(third.flow as GameFlow).bind_cinder_cargo_delivery_persistence(third_binding)
	var stable := third_binding.get_snapshot().cargo as Dictionary
	_check(int(stable.state) == CargoDeliveryActivity.State.COMPLETED
		and bool(stable.delivery_persisted) and int(stable.next_phase_index) == int(stable.phase_count)
		and int(third_store.get_generation()) == 3,
		"later reload discards incomplete cargo and retains terminal delivery receipt")
	await _retire(third, {})

	await _test_legacy_summary(filesystem, store.get_snapshot().cinder_cargo_delivery)
	await _test_saved_unpaid_start_retry()
	await _run_disk_processes()

	for failure in _failures: push_error(failure)
	print("CINDER_CARGO_DELIVERY_PERSISTENCE_ROUNDTRIP_TEST_OK: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _make_runtime(store: UserDataStore) -> Dictionary:
	store.load()
	var cluster := CLUSTER_SCENE.instantiate() as NearbySectorCluster
	root.add_child(cluster)
	var hud := HUD_SCENE.instantiate() as GameHUD
	root.add_child(hud)
	await process_frame
	var flow := GameFlowScript.new() as GameFlow
	flow.set("_runtime_settings_user_data_store", store)
	flow.set("_runtime_settings_persistence_injected", true)
	var reward_authority: GameFlowRewardAuthority = GameFlowRewardAuthority.new()
	reward_authority.configure(store)
	flow.set("_game_flow_reward_authority", reward_authority)
	_current_flow = flow
	return {"cluster": cluster, "binding": cluster.get_node(^"ActivityBinding"),
		"hud": hud, "flow": flow}


func _build_fixture() -> Dictionary:
	var authority := CargoTransferAuthority.new()
	root.add_child(authority)
	var item := CargoItemDefinition.new()
	item.item_id = &"cinder_supply_crates"; item.display_name = "Cinder supply crates"; item.unit_capacity = 1
	authority.register_item(item)
	var source := Node.new(); var destination := Node.new()
	authority.add_child(source); authority.add_child(destination)
	var source_handle := authority.register_entity(source, &"source", &"source_manifest", 8,
		{&"cinder_supply_crates": 4}).handle as Dictionary
	var destination_handle := authority.register_entity(destination, &"destination", &"destination_manifest", 8).handle as Dictionary
	var contract := CargoDeliveryContract.new(&"cinder_platform_supply_run", source_handle,
		destination_handle, &"cinder_supply_crates", 1,
		[&"load_crate", &"clear_gate", &"dock_platform"], 120.0)
	return {"authority": authority, "source": source, "source_handle": source_handle, "destination_handle": destination_handle,
		"activity": CargoDeliveryActivity.new(authority, contract)}


func _complete(binding: NearbySectorActivityBinding) -> Dictionary:
	binding.start_cargo_run()
	for phase: StringName in [&"load_crate", &"clear_gate", &"dock_platform"]:
		binding.submit_cargo_phase(phase)
	var activity := binding.get("_cargo_activity") as CargoDeliveryActivity
	return activity.submit_transfer(activity.get_generation())


func _test_legacy_summary(filesystem: MemoryFilesystem, terminal: Dictionary) -> void:
	var legacy: Dictionary = terminal.duplicate(true)
	legacy.schema_version = 1
	legacy.delivery.erase("generation")
	legacy.delivery.erase("ordered_phases")
	legacy.delivery.erase("deadline_seconds")
	legacy.delivery.erase("transfer_proof")
	legacy.delivery.reward_receipt.granted = false
	var store: UserDataStore = StoreScript.new("memory://cinder-legacy-summary.json", filesystem)
	store.load()
	store.commit({"cinder_cargo_delivery": legacy}, 0, "legacy-paid-summary")
	var runtime: Dictionary = await _make_runtime(store)
	var binding: NearbySectorActivityBinding = runtime.binding
	(runtime.flow as GameFlow).bind_cinder_cargo_delivery_persistence(binding)
	var presentation: Dictionary = binding.get_snapshot().cargo
	_check(int(presentation.generation) == 0 and bool(presentation.delivery_persisted) and not binding.request_cargo_reward(1).accepted, "legacy v1 remains generation0 presentation without reward entitlement")
	await _retire(runtime, {})


func _test_saved_unpaid_start_retry() -> void:
	var filesystem := MemoryFilesystem.new()
	var store: UserDataStore = StoreScript.new("memory://cinder-start-retry.json", filesystem)
	store.load()
	var protected_data := {"pilot": "retained", "inventory": [7, 11]}
	store.commit({"foreign": protected_data}, 0, "seed-start-retry")
	var runtime := await _make_runtime(store)
	var flow: GameFlow = runtime.flow
	var binding: NearbySectorActivityBinding = runtime.binding
	var hud: GameHUD = runtime.hud
	var world := CargoWorld.new()
	world.cluster = runtime.cluster
	root.add_child(world)
	flow.world = world
	flow.hud = hud
	var fixture := _build_fixture()
	var activity: CargoDeliveryActivity = fixture.activity
	var authority: CargoTransferAuthority = fixture.authority
	binding.set("_cargo_activity", activity)
	binding.set("_cargo_authority", authority)
	binding.set("_cargo_source_entity", fixture.source)
	flow.bind_cinder_cargo_delivery_persistence(binding)
	flow._configure_cinder_cargo_reward_handoff(binding)
	filesystem.refuse_payment = true
	var delivered := _complete(binding)
	var generation := activity.get_generation()
	var unpaid: Dictionary = binding.get_snapshot().cargo
	var before_retry := store.get_snapshot()
	var proof: Dictionary = before_retry.cinder_cargo_delivery.delivery.transfer_proof.duplicate(true)
	var transfers: Array = authority.to_dictionary().committed_transfers.duplicate(true)
	_check(delivered.accepted and bool(unpaid.delivery_persisted)
		and bool(unpaid.reward_retry_available) and not bool(before_retry.cinder_cargo_delivery.delivery.reward_receipt.granted)
		and store.get_generation() == 2 and transfers.size() == 1,
		"refused payment leaves one genuinely transferred saved completion available for ordinary Start retry")
	hud.clear_activity_objective()
	var pending_visible := flow._sync_cinder_cargo_activity_hud()
	var pending_report := hud.get_activity_objective_report()
	_check(pending_visible and bool(pending_report.visible)
		and StringName(pending_report.activity_id) == &"cinder_platform_supply_run"
		and str(pending_report.text).contains("START TO RETRY REWARD"),
		"saved unpaid completion keeps ordinary flight HUD Start-to-retry guidance visible")
	var refused := flow._start_nearby_activity(binding, &"cinder_platform_supply_run")
	_check(not bool(refused.accepted) and refused.reason == &"reward_callback_rejected"
		and store.get_snapshot() == before_retry and activity.get_generation() == generation,
		"ordinary Start reaches the refused payment callback without restarting or changing the saved completion")
	var stale := binding.request_cargo_reward(generation + 1)
	_check(not bool(stale.accepted) and store.get_snapshot() == before_retry,
		"stale saved-completion retry cannot publish payment")
	filesystem.refuse_payment = false
	var paid := flow._start_nearby_activity(binding, &"cinder_platform_supply_run")
	var after_payment := store.get_snapshot()
	_check(bool(paid.accepted) and paid.reason == &"reward_request_committed"
		and int((after_payment.get("game_flow_reward_store", {}) as Dictionary).get("total_receipts", 0)) == 1
		and bool(after_payment.cinder_cargo_delivery.delivery.reward_receipt.granted)
		and int(after_payment.cinder_cargo_delivery.delivery.generation) == generation
		and activity.get_generation() == generation and activity.get_state() == CargoDeliveryActivity.State.COMPLETED,
		"ordinary Start pays the exact saved unpaid generation once without starting another sortie")
	var repeated := flow._start_nearby_activity(binding, &"cinder_platform_supply_run")
	var replay := binding.request_cargo_reward(generation)
	_check(not bool(repeated.accepted) and not bool(replay.accepted)
		and store.get_snapshot() == after_payment and store.get_generation() == 3,
		"repeated ordinary Start and explicit replay cannot pay or persist a second receipt")
	_check(authority.get_quantity(fixture.source_handle, &"cinder_supply_crates") == 3
		and authority.get_quantity(fixture.destination_handle, &"cinder_supply_crates") == 1
		and authority.to_dictionary().committed_transfers == transfers
		and store.get_snapshot().cinder_cargo_delivery.delivery.transfer_proof == proof
		and store.get_snapshot().foreign == before_retry.foreign,
		"ordinary payment retries preserve actual manifests, exact transfer ledger/proof and unrelated player data")
	hud.clear_activity_objective()
	_check(not flow._sync_cinder_cargo_activity_hud()
		and not bool(hud.get_activity_objective_report().visible),
		"paid saved completion stops contributing the flight HUD retry objective")
	world.queue_free()
	await _retire(runtime, fixture)


func _run_disk_processes() -> void:
	var folder: String = OS.get_user_data_dir().path_join("cinder-debt-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	DirAccess.make_dir_recursive_absolute(folder)
	var path: String = folder.path_join("delivery.json")
	for mode: String in ["earn", "pay", "paid"]:
		var args: PackedStringArray = PackedStringArray(["--headless", "--audio-driver", "Dummy", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/cinder_cargo_delivery_persistence_roundtrip_test.gd", "--", "--cinder-debt-child", mode, path])
		print("CINDER_DEBT_CHILD_COMMAND ", OS.get_executable_path(), " ", JSON.stringify(args))
		var child: Dictionary = OS.execute_with_pipe(OS.get_executable_path(), args, false)
		var pid: int = int(child.get("pid", -1))
		_check(pid > 0, "disk child launches: " + mode)
		if pid <= 0:
			break
		print("CINDER_DEBT_CHILD_PID ", pid)
		var deadline: int = Time.get_ticks_msec() + 70000
		var transcript: String = ""
		while OS.is_process_running(pid) and Time.get_ticks_msec() < deadline:
			transcript += (child.stdio as FileAccess).get_buffer(65536).get_string_from_utf8()
			transcript += (child.stderr as FileAccess).get_buffer(65536).get_string_from_utf8()
			await process_frame
		var timed_out: bool = OS.is_process_running(pid)
		if timed_out:
			OS.kill(pid)
			var reap_deadline: int = Time.get_ticks_msec() + 2000
			while OS.is_process_running(pid) and Time.get_ticks_msec() < reap_deadline:
				await process_frame
		transcript += (child.stdio as FileAccess).get_buffer(65536).get_string_from_utf8()
		transcript += (child.stderr as FileAccess).get_buffer(65536).get_string_from_utf8()
		(child.stdio as FileAccess).close()
		(child.stderr as FileAccess).close()
		var code: int = OS.get_process_exit_code(pid)
		print(transcript)
		print("CINDER_DEBT_CHILD_EXIT ", pid, " ", code, " reaped=", not OS.is_process_running(pid))
		_check(not timed_out and code == 0 and transcript.count("CINDER_DEBT_CHILD_OK " + mode) == 1, "actual-file cold process completes: " + mode)
		if timed_out or code != 0 or transcript.count("CINDER_DEBT_CHILD_OK " + mode) != 1:
			break
	print("CINDER_DEBT_ACTUAL_STORE_RETAINED ", path)


func _run_disk_child(mode: String, path: String) -> void:
	print("CINDER_DEBT_CHILD_RUNNING ", mode, " pid=", OS.get_process_id())
	var filesystem: RefusingDiskFilesystem = RefusingDiskFilesystem.new()
	var store: UserDataStore = StoreScript.new(path, filesystem)
	store.load()
	if mode == "earn":
		_check(store.commit({"foreign": {"pilot": "retained", "inventory": [7, 11]}}, 0, "seed-disk").accepted, "actual file seed publishes")
	var runtime: Dictionary = await _make_runtime(store)
	var binding: NearbySectorActivityBinding = runtime.binding
	(runtime.flow as GameFlow).bind_cinder_cargo_delivery_persistence(binding)
	var fixture: Dictionary = {}
	if mode == "earn":
		fixture = _build_fixture()
		binding.set("_cargo_activity", fixture.activity)
		binding.set("_cargo_authority", fixture.authority)
		binding.set("_cargo_source_entity", fixture.source)
		filesystem.refuse_debt = true
		binding.configure_cargo_reward_handoff(Callable(self, "_accept_reward"))
		var delivered: Dictionary = _complete(binding)
		_check(delivered.accepted and _reward_calls == 0 and store.get_generation() == 1, "refused debt save invokes no payment")
		_check(not binding.reset_cargo_run().accepted and not binding.start_cargo_run().accepted, "live unsaved earned debt blocks reset and start")
		var earned_owner: CargoDeliveryActivity = fixture.activity
		binding.call("_on_cargo_berth_occupancy_changed", null)
		binding.call("_on_cargo_berth_occupancy_changed", fixture.source)
		_check(binding.get("_cargo_activity") == earned_owner and not binding.start_cargo_run().accepted and store.get_generation() == 1, "departure after refused debt publication retains the exact earned retry owner")

		filesystem.refuse_debt = false
		filesystem.refuse_payment = true
		var generation: int = (fixture.activity as CargoDeliveryActivity).get_generation()
		_check(not binding.request_cargo_reward(generation).accepted and _reward_calls == 1 and store.get_generation() == 2, "genuine debt precedes refused real reward publication")
		var debt: Dictionary = store.get_snapshot().cinder_cargo_delivery.delivery
		_check(int(debt.generation) == generation and not debt.reward_receipt.granted and debt.transfer_receipt.transfer_id == "cinder_platform_supply_run_g1" and int(debt.transfer_proof.source_quantity_after) == 3 and int(debt.transfer_proof.destination_quantity_after) == 1, "real file retains exact earned identity and quantities")
		_check(not binding.reset_cargo_run().accepted and not binding.start_cargo_run().accepted, "durable unpaid debt blocks reset and start")
		var before_stale: Dictionary = store.get_snapshot()
		_check(not binding.request_cargo_reward(generation + 1).accepted and store.get_snapshot() == before_stale and _reward_calls == 1, "stale debt generation cannot enter payment callback")
		var replacement: Dictionary = _build_fixture()
		var replacement_activity: CargoDeliveryActivity = replacement.activity
		replacement_activity.adopt_terminal_generation_floor(generation)
		replacement_activity.start(generation)
		for phase: StringName in [&"load_crate", &"clear_gate", &"dock_platform"]:
			replacement_activity.submit_phase(phase, replacement_activity.get_generation())
		replacement_activity.submit_transfer(replacement_activity.get_generation())
		var persistence: CinderCargoDeliveryPersistence = CinderCargoDeliveryPersistence.new()
		persistence.configure(store, CinderCargoDeliveryPersistence.SLOT_ID)
		_check(not persistence.save(replacement_activity, replacement.authority, "replace-unpaid").accepted and store.get_snapshot() == before_stale, "another genuine completion cannot replace existing unpaid debt")
		(replacement.authority as Node).queue_free()
		var parent: Node = binding.get_parent()
		parent.remove_child(binding)
		_check(not binding.request_cargo_reward(generation).accepted and not binding.call("_checkpoint_cargo_completion", (fixture.activity as CargoDeliveryActivity).get_snapshot()).accepted and store.get_snapshot() == before_stale and _reward_calls == 1, "retained removed owner cannot publish or pay debt")
		parent.add_child(binding)

		_check((fixture.authority as CargoTransferAuthority).get_quantity(fixture.source_handle, &"cinder_supply_crates") == 3 and (fixture.authority as CargoTransferAuthority).get_quantity(fixture.destination_handle, &"cinder_supply_crates") == 1, "reward retry leaves actual manifests conserved")
	elif mode == "pay":
		_check(not binding.start_cargo_run().accepted and not binding.reset_cargo_run().accepted, "cold unpaid debt blocks replacement")
		var before: Dictionary = store.get_snapshot().cinder_cargo_delivery.delivery.transfer_proof.duplicate(true)
		filesystem.refuse_sync = true
		binding.configure_cargo_reward_handoff(Callable(self, "_accept_reward"))
		_check(not filesystem.refuse_sync, "real published reward sync refusal was exercised")
		_check(_reward_calls == 1 and store.get_generation() == 3 and store.get_snapshot().cinder_cargo_delivery.delivery.reward_receipt.granted and int(store.get_snapshot().game_flow_reward_store.total_receipts) == 1, "fresh current binding reconciles exact published payment once atomically")
		var recovered_authority: GameFlowRewardAuthority = _current_flow.get("_game_flow_reward_authority") as GameFlowRewardAuthority
		var recovered_result: Dictionary = recovered_authority.get_snapshot().get("last_result", {})
		var consumed_request: Dictionary = binding.get_station_defense_reward_snapshot().get("last_request", {})
		_check(recovered_result.get("accepted", false) and recovered_result.get("granted", false) and str(consumed_request.get("activity_id", "")) == str(CinderCargoDeliveryPersistence.REWARD_ACTIVITY_ID) and int(consumed_request.get("activity_generation", 0)) == 1, "published payment recovery returns acceptance and consumes the matching adapter request")
		_check(store.get_snapshot().cinder_cargo_delivery.delivery.transfer_proof == before and binding.get_cargo_transfer_authority().to_dictionary().committed_transfers.is_empty(), "cold reward retry changes no inventory or transfer proof")
		var before_replay: Dictionary = store.get_snapshot()
		_check(not binding.request_cargo_reward(1).accepted and store.get_snapshot() == before_replay, "paid cold owner cannot replay")
	else:
		binding.configure_cargo_reward_handoff(Callable(self, "_accept_reward"))
		_check(_reward_calls == 0 and store.get_generation() == 3 and not binding.request_cargo_reward(1).accepted, "second cold load keeps one payment")
		fixture = _build_fixture()
		binding.set("_cargo_activity", fixture.activity)
		binding.set("_cargo_authority", fixture.authority)
		binding.set("_cargo_source_entity", fixture.source)
		var started: Dictionary = binding.start_cargo_run()
		_check(started.accepted and int(started.generation) > 1 and int(started.generation) == 2 and not (fixture.activity as CargoDeliveryActivity).adopt_terminal_generation_floor(9).accepted, "next legitimate delivery advances actual generation and rejects late floor adoption")
		_check(store.get_generation() == 3 and _reward_calls == 0, "new incomplete run creates no entitlement")
	var expected_foreign: Dictionary = JSON.parse_string(JSON.stringify({"pilot": "retained", "inventory": [7, 11]}, "", true, true)) as Dictionary
	_check(store.get_snapshot().foreign == expected_foreign, "unrelated actual-file inventory survives")
	for suffix: String in ["", ".bak"]:
		if FileAccess.file_exists(path + suffix):
			var retained_path: String = path + "." + mode + suffix
			DirAccess.copy_absolute(path + suffix, retained_path)
			print("CINDER_DEBT_PHASE_STORE_RETAINED ", retained_path)

	await _retire(runtime, fixture)
	for failure: String in _failures:
		push_error(failure)
	if _failures.is_empty():
		print("CINDER_DEBT_CHILD_OK ", mode)
	quit(0 if _failures.is_empty() else 1)


func _cargo_card(view: Dictionary) -> Dictionary:
	for candidate in view.get("cards", []) as Array:
		var card := candidate as Dictionary
		if StringName(card.get("activity_id", &"")) == &"cinder_platform_supply_run": return card
	return {}


func _retire(runtime: Dictionary, fixture: Dictionary) -> void:
	(runtime.cluster as Node).queue_free(); (runtime.hud as Node).queue_free(); (runtime.flow as Object).free()
	if not fixture.is_empty(): (fixture.authority as Node).queue_free()
	for _frame in 3: await process_frame


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition: _failures.append(message)
