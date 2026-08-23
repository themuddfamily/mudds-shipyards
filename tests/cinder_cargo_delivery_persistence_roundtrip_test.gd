extends SceneTree

const CLUSTER_SCENE := preload("res://scenes/world/components/nearby_sector_cluster.tscn")
const HUD_SCENE := preload("res://scenes/ui/hud.tscn")
const GameFlowScript := preload("res://scripts/game/game_flow.gd")
const StoreScript := preload("res://scripts/persistence/user_data_store.gd")
const FilesystemScript := preload("res://scripts/persistence/user_data_filesystem.gd")

class MemoryFilesystem extends FilesystemScript:
	var files: Dictionary = {}
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
		files[path] = bytes.duplicate(); return OK
	func remove_path(path: String) -> Error:
		if not files.has(path): return ERR_FILE_NOT_FOUND
		files.erase(path); return OK
	func rename_path(from_path: String, to_path: String) -> Error:
		if not files.has(from_path): return ERR_FILE_NOT_FOUND
		files[to_path] = (files[from_path] as PackedByteArray).duplicate()
		files.erase(from_path); return OK

var _assertions := 0
var _failures := PackedStringArray()
var _reward_calls := 0


func _init() -> void:
	call_deferred(&"_run")


func _accept_reward(_request: Dictionary) -> Dictionary:
	_reward_calls += 1
	return {"accepted": true, "reason": &"caller_reward_receipt_accepted"}


func _run() -> void:
	var filesystem := MemoryFilesystem.new()
	var store := StoreScript.new("memory://cinder-cargo-delivery.json", filesystem)
	_check(bool(store.load().accepted), "the existing atomic store loads")
	_check(bool(store.commit({"foreign": {"accessibility": "retained"}}, 0, "seed").accepted),
		"foreign user data is seeded before cargo completion")

	var first := await _make_runtime(store)
	var first_binding := first.binding as NearbySectorActivityBinding
	var fixture := _build_fixture()
	first_binding.set("_cargo_activity", fixture.activity)
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
		and _reward_calls == 1 and int(store.get_generation()) == 2,
		"ledger completion and generation-matched reward handoff commit one durable receipt")
	_check((store.get_snapshot().foreign as Dictionary).accessibility == "retained"
		and not bool(((persisted.delivery as Dictionary).reward_receipt as Dictionary).replay_allowed)
		and not bool(((persisted.delivery as Dictionary).transfer_receipt as Dictionary).replay_allowed),
		"both replay fences merge without replacing foreign store data")
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
		and int(restored.generation) == 0 and bool(restored.delivery_persisted)
		and (restored.accepted_receipt as Dictionary).is_empty(),
		"reload restores delivered presentation without transfer receipt inventory authority")
	_check((card.cargo_progress as Dictionary).stage_id == &"delivery_recorded"
		and "DELIVERY RECEIPT SAVED" in str((card.cargo_progress as Dictionary).summary)
		and world.state_id == &"committed" and world.geometry_state == &"delivered",
		"retained HUD and route-cue geometry show the saved delivery")
	_check(not bool(replay.accepted) and replay.reason == &"cargo_reward_unavailable"
		and _reward_calls == 1 and int(reloaded_store.get_generation()) == 2,
		"restored presentation cannot replay cargo reward or mutate the store")

	var fresh_fixture := _build_fixture()
	second_binding.set("_cargo_activity", fresh_fixture.activity)
	second_binding.set("_cargo_source_entity", fresh_fixture.source)
	second_binding.call("_bind_cargo_reward_handoff")
	var fresh := second_binding.start_cargo_run()
	second_binding.submit_cargo_phase(&"load_crate")
	var active := second_binding.get_snapshot().cargo as Dictionary
	_check(bool(fresh.accepted) and int(active.state) == CargoDeliveryActivity.State.ACTIVE
		and not bool(active.get("delivery_persisted", false))
		and int(active.next_phase_index) == 1 and int(reloaded_store.get_generation()) == 2,
		"a fresh incomplete manifest run stays session-scoped and overrides summary presentation")
	await _retire(second, fresh_fixture)

	var third_store := StoreScript.new("memory://cinder-cargo-delivery.json", filesystem)
	var third := await _make_runtime(third_store)
	var third_binding := third.binding as NearbySectorActivityBinding
	(third.flow as GameFlow).bind_cinder_cargo_delivery_persistence(third_binding)
	var stable := third_binding.get_snapshot().cargo as Dictionary
	_check(int(stable.state) == CargoDeliveryActivity.State.COMPLETED
		and bool(stable.delivery_persisted) and int(stable.next_phase_index) == int(stable.phase_count)
		and int(third_store.get_generation()) == 2,
		"later reload discards incomplete cargo and retains terminal delivery receipt")
	await _retire(third, {})

	for failure in _failures: push_error(failure)
	print("CINDER_CARGO_DELIVERY_PERSISTENCE_ROUNDTRIP_TEST_OK: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _make_runtime(store: UserDataStore) -> Dictionary:
	var cluster := CLUSTER_SCENE.instantiate() as NearbySectorCluster
	root.add_child(cluster)
	var hud := HUD_SCENE.instantiate() as GameHUD
	root.add_child(hud)
	await process_frame
	var flow := GameFlowScript.new() as GameFlow
	flow.set("_runtime_settings_user_data_store", store)
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
	return {"authority": authority, "source": source,
		"activity": CargoDeliveryActivity.new(authority, contract)}


func _complete(binding: NearbySectorActivityBinding) -> Dictionary:
	binding.start_cargo_run()
	for phase: StringName in [&"load_crate", &"clear_gate", &"dock_platform"]:
		binding.submit_cargo_phase(phase)
	var activity := binding.get("_cargo_activity") as CargoDeliveryActivity
	return activity.submit_transfer(activity.get_generation())


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
