extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const StoreScript := preload("res://scripts/persistence/user_data_store.gd")
const FilesystemScript := preload("res://scripts/persistence/user_data_filesystem.gd")

class PublicationSyncFilesystem extends FilesystemScript:
	var fail_published_sync := false
	var published := false
	func rename_path(from_path: String, to_path: String) -> Error:
		var result := super.rename_path(from_path, to_path)
		if result == OK and from_path.ends_with(".tmp"):
			published = true
		return result
	func sync_directory(_path: String) -> Error:
		if fail_published_sync and published:
			published = false
			return ERR_FILE_CANT_WRITE
		return OK

var _assertions := 0
var _failures := PackedStringArray()

func _init() -> void:
	call_deferred(&"_run")

func _run() -> void:
	# Optional genuine backup diagnosis preserves all default recovery routes.
	if OS.get_cmdline_user_args().has("--mining-backup-trust-only"):
		await _backup_trust_reproduction()
		for failure in _failures: push_error(failure)
		print("CINDER_MINING_DURABLE_RECOVERY_TEST_%s: %d assertions" % ["OK" if _failures.is_empty() else "FAILED", _assertions])
		quit(0 if _failures.is_empty() else 1)
		return
	var directory := "/tmp/mudds-mining-durable-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var path := directory.path_join("profile.json")
	var seed := StoreScript.new(path)
	seed.load()
	seed.commit({"foreign": {"cargo": "keep", "setting": 17}}, 0, "mining-seed")
	var first := await _main(path)
	var binding := first.binding as NearbySectorActivityBinding
	_mining_intent(first.game, &"start_requested")
	first.game.call(&"_advance_cinder_mining_extraction", 2.0, first.sample)
	var active := binding.get_activity_snapshot(&"mining")
	var checkpoint := FileAccess.get_file_as_bytes(path)
	first.game.call(&"_advance_cinder_mining_extraction", 0.2, first.sample)
	_check(FileAccess.get_file_as_bytes(path) == checkpoint, "unsaved fractions within the half-second cadence are not promised")
	DirAccess.make_dir_absolute(path + ".tmp")
	first.game.call(&"_advance_cinder_mining_extraction", 0.5, first.sample)
	_check(FileAccess.get_file_as_bytes(path) == checkpoint, "failed active checkpoint retains last successful file")
	await _retire(first.game)
	DirAccess.remove_absolute(path + ".tmp")
	var second := await _main(path, false)
	binding = second.binding as NearbySectorActivityBinding
	var restored := binding.get_activity_snapshot(&"mining")
	_check(restored.state_id == &"active" and int(restored.generation) == int(active.generation)
		and is_equal_approx(float(restored.elapsed_seconds), 2.0) and bool(restored.resume_required), "fresh production Main restores last successful active progress")
	var station_bytes := FileAccess.get_file_as_bytes(path)
	var station_sample := (second.sample as Dictionary).duplicate(true)
	station_sample.position = Vector3.ZERO
	var waiting := second.game.call(&"_advance_cinder_mining_extraction", 1.0, station_sample) as Dictionary
	_check(waiting.reason == &"mining_resume_required" and binding.get_activity_snapshot(&"mining").state_id == &"active"
		and FileAccess.get_file_as_bytes(path) == station_bytes, "cold station spawn suspends progress without destructive RESET")
	_mining_intent(second.game, &"start_requested")
	_check(bool(binding.get_activity_snapshot(&"mining").resume_required), "ordinary Start outside the authored approach cannot resume")
	(second.game as GameFlow).active_ship.global_position = CinderMiningPlatformActivity.APPROACH_ANCHOR
	_mining_intent(second.game, &"start_requested")
	_check(not bool(binding.get_activity_snapshot(&"mining").resume_required)
		and int(binding.get_activity_snapshot(&"mining").generation) == int(active.generation)
		and is_equal_approx(float(binding.get_activity_snapshot(&"mining").elapsed_seconds), 2.0), "ordinary Start at approach resumes the same generation and timer")
	# Advance to the genuine terminal owner before blocking payment, so its
	# terminal checkpoint is durable even though capacity publication fails.
	binding.advance_mining_activity(4.0)
	DirAccess.make_dir_absolute(path + ".tmp")
	var unpaid := binding.request_mining_reward()
	_check(bool(unpaid.accepted) and not bool(unpaid.capacity_persisted), "real failed capacity publication retains genuine unpaid completion")
	await _retire(second.game)
	var third := await _main(path, false)
	binding = third.binding as NearbySectorActivityBinding
	var terminal := binding.get_activity_snapshot(&"mining")
	_check(terminal.state_id == &"complete" and bool(terminal.get("persistence_retry_available", false))
		and int(terminal.generation) == int(active.generation), "fresh production Main restores genuinely owed terminal capacity")
	var owed_bytes := FileAccess.get_file_as_bytes(path)
	_mining_intent(third.game, &"reset_requested")
	var refused := binding.start_mining_activity(CinderMiningPlatformActivity.APPROACH_ANCHOR)
	_mining_intent(third.game, &"start_requested")
	_check(not bool(refused.accepted) and binding.get_activity_snapshot(&"mining").state_id == &"complete"
		and FileAccess.get_file_as_bytes(path) == owed_bytes, "failed ordinary Start retry and Reset preserve the owed terminal generation")
	DirAccess.remove_absolute(path + ".tmp")
	_mining_intent(third.game, &"start_requested")
	var paid := binding.get_activity_snapshot(&"mining")
	var paid_bytes := FileAccess.get_file_as_bytes(path)
	var stale := binding.call(&"_persist_mining_capacity", unpaid) as Dictionary
	_check(bool(paid.get("capacity_persisted", false)) and int(paid.generation) == int(active.generation)
		and not bool(binding.request_mining_reward().accepted) and not bool(binding.retry_mining_capacity_persistence().accepted)
		and FileAccess.get_file_as_bytes(path) == paid_bytes, "ordinary Start pays exactly the restored owed extraction without duplicate writes")
	_mining_intent(third.game, &"reset_requested")
	var old_binding := binding
	var fourth := await _main(path)
	binding = fourth.binding as NearbySectorActivityBinding
	var reset := binding.get_activity_snapshot(&"mining")
	_check(reset.state_id == &"reset" and int(reset.generation) == int(active.generation), "paid Reset survives fresh Main with its true generation")
	_mining_intent(fourth.game, &"start_requested")
	var next := binding.get_activity_snapshot(&"mining")
	_check(int(next.generation) == int(active.generation) + 1 and is_zero_approx(float(next.elapsed_seconds)), "next real mining run starts exactly the next generation")
	var stale_bytes := FileAccess.get_file_as_bytes(path)
	var old_writer := old_binding.call("_persist_mining_session") as Dictionary
	_check(not bool(old_writer.accepted) and old_writer.reason == &"mining_session_stale"
		and FileAccess.get_file_as_bytes(path) == stale_bytes, "retained old Main cannot overwrite the later real saved generation")
	await _retire(third.game)
	stale = binding.call(&"_persist_mining_capacity", unpaid) as Dictionary
	_check(not bool(stale.accepted) and stale.reason == &"mining_capacity_generation_mismatch"
		and FileAccess.get_file_as_bytes(path) == stale_bytes, "stale completion callback cannot pay a later generation")
	var completed := fourth.game.call(&"_advance_cinder_mining_extraction", 6.0, fourth.sample) as Dictionary
	_check(bool((completed.get("reward_result", {}) as Dictionary).get("capacity_persisted", false))
		and not bool(binding.request_mining_reward().accepted), "next actual extraction completes and records capacity once")
	_mining_intent(fourth.game, &"reset_requested")
	_mining_intent(fourth.game, &"start_requested")
	fourth.game.call(&"_advance_cinder_mining_extraction", 1.0, fourth.sample)
	var away := fourth.game.call(&"_advance_cinder_mining_extraction", 0.1, station_sample) as Dictionary
	_check(away.reason == &"extraction_interrupted" and binding.get_activity_snapshot(&"mining").state_id == &"reset", "leaving the approach after continuation preserves physical interruption")
	_check((fourth.store.get_snapshot().foreign as Dictionary).cargo == "keep"
		and int((fourth.store.get_snapshot().foreign as Dictionary).setting) == 17, "all mining commits preserve unrelated cargo and settings")
	await _retire(fourth.game)
	await _test_published_sync(directory.path_join("sync.json"))
	_test_record_compatibility(path)
	var cleanup := DirAccess.open(directory)
	for filename in cleanup.get_files(): DirAccess.remove_absolute(directory.path_join(filename))
	DirAccess.remove_absolute(directory)
	for failure in _failures: push_error(failure)
	print("CINDER_MINING_DURABLE_RECOVERY_TEST_%s: %d assertions" % ["OK" if _failures.is_empty() else "FAILED", _assertions])
	quit(0 if _failures.is_empty() else 1)


## Mining's real capacity owner pays its six-second extraction, rotating the
## genuine unpaid terminal into backup. This is not an inventory/currency grant.
func _backup_trust_reproduction() -> void:
	var path := "user://mining_backup_trust_%d.json" % Time.get_ticks_usec()
	var retained := await _main(path)
	var binding := retained.binding as NearbySectorActivityBinding
	var shared := retained.store as UserDataStore
	retained.game.call("_on_settings_save_requested")
	var seeded := shared.get_snapshot()
	seeded["mining_trust_unrelated"] = {"inventory": {"units": 4, "samples": ["caller-owned"]}, "note": "keep"}
	_check(seeded.has("runtime_settings") and shared.commit(seeded, shared.get_generation(), "unit-mining-trust-unrelated").accepted,
		"Mining diagnosis seeds caller data alongside actual saved runtime settings")
	_mining_intent(retained.game, &"start_requested")
	var active := binding.get_activity_snapshot(&"mining")
	_check(active.state_id == &"active" and int(active.generation) > 0,
		"ordinary Start admits the actual authored Mining approach and generation")
	var completed := retained.game.call("_advance_cinder_mining_extraction", 6.0, retained.sample) as Dictionary
	var reward: Dictionary = completed.get("reward_result", {})
	var earned := (binding.get("_mining_activity") as RefCounted).call("get_snapshot") as Dictionary
	print("MINING_BACKUP_COMPLETION: ", {"advance": completed, "owned": _mining_owned_state(binding),
		"persistence": binding.get_cinder_mining_capacity_persistence_snapshot(), "source": shared.get_loaded_source()})
	_check(bool(completed.get("accepted", false)) and bool(reward.get("accepted", false))
		and bool(reward.get("capacity_persisted", false)) and is_equal_approx(float(earned.elapsed_seconds), 6.0),
		"the actual six-second extraction publishes one genuine capacity acknowledgement")
	var paid_bytes := FileAccess.get_file_as_bytes(path)
	var unpaid_bytes := FileAccess.get_file_as_bytes(path + ".bak")
	var paid: Variant = JSON.parse_string(paid_bytes.get_string_from_utf8())
	var unpaid: Variant = JSON.parse_string(unpaid_bytes.get_string_from_utf8())
	var readable: bool = paid is Dictionary and unpaid is Dictionary
	_check(readable, "actual Mining publication retains readable paid primary and unpaid predecessor")
	if not readable:
		await _retire(retained.game)
		return
	var codec := CinderMiningCapacityPersistence.new()
	codec.configure(shared, &"cinder_mining_capacity")
	var paid_record: Dictionary = paid.payload.get("cinder_mining_capacity", {})
	var unpaid_record: Dictionary = unpaid.payload.get("cinder_mining_capacity", {})
	var valid: bool = codec.validate_record(paid_record).accepted and codec.validate_record(unpaid_record).accepted
	_check(valid, "both genuine Mining witness documents satisfy the existing typed receipt codec")
	if not valid:
		await _retire(retained.game)
		return
	var genuine: bool = paid_record.session.capacity_paid and not unpaid_record.session.capacity_paid \
		and unpaid_record.session.reward_requested and unpaid_record.capacity.is_empty() and not paid_record.capacity.is_empty() \
		and int(paid_record.session.generation) == int(unpaid_record.session.generation) \
		and int(paid_record.session.state) == CinderMiningPlatformActivity.State.COMPLETE \
		and int(unpaid_record.session.state) == CinderMiningPlatformActivity.State.COMPLETE \
		and float(unpaid_record.session.elapsed_seconds) == 6.0 \
		and paid.payload.has("runtime_settings") and paid.payload.has("mining_trust_unrelated") \
		and paid.payload.runtime_settings == unpaid.payload.runtime_settings \
		and paid.payload.mining_trust_unrelated == unpaid.payload.mining_trust_unrelated
	print("MINING_BACKUP_GENUINE_WITNESSES: ", {"paid": paid_record, "unpaid": unpaid_record, "reward": reward})
	_check(genuine, "real paid capacity and its same-generation earned-unpaid predecessor retain full settings and caller data")
	if not genuine:
		await _retire(retained.game)
		return
	var corrupt := "corrupt newer paid Mining primary".to_utf8_buffer()
	var staged := _write_mining_witness(path + ".paid-witness", paid_bytes) and _write_mining_witness(path, corrupt)
	_check(staged, "retained Mining probe preserves paid evidence before corrupting the newer primary")
	if not staged:
		await _retire(retained.game)
		return
	var preflight := UserDataStore.new(path)
	var selected := preflight.load()
	var artifacts := _mining_recovery_artifacts(path)
	print("MINING_BACKUP_RETAINED_PREFLIGHT: ", {"load": selected, "source": preflight.get_loaded_source()})
	_check(selected.accepted and preflight.get_loaded_source() == &"backup" and artifacts.get(".recovery") == corrupt,
		"the real store selects the genuine unpaid backup and preserves the exact corrupt primary")
	var before := _mining_owned_state(binding)
	_mining_intent(retained.game, &"start_requested")
	_mining_intent(retained.game, &"start_requested")
	print("MINING_BACKUP_RETAINED_START: ", {"feedback": ((retained.game as GameFlow).hud.get("_nearby_activity_feedback") as Label).text, "owned": _mining_owned_state(binding),
		"persistence": binding.get_cinder_mining_capacity_persistence_snapshot(), "source": shared.get_loaded_source(), "payload": shared.get_snapshot()})
	_check(_mining_owned_state(binding) == before and shared.get_loaded_source() == &"backup"
		and shared.get_snapshot() == selected.payload and _mining_recovery_artifacts(path) == artifacts,
		"repeated ordinary retained Start cannot discard paid Mining state or promote untrusted backup authority")
	_mining_intent(retained.game, &"reset_requested")
	print("MINING_BACKUP_RETAINED_RESET: ", {"feedback": ((retained.game as GameFlow).hud.get("_nearby_activity_feedback") as Label).text, "owned": _mining_owned_state(binding),
		"persistence": binding.get_cinder_mining_capacity_persistence_snapshot(), "source": shared.get_loaded_source()})
	_check(_mining_owned_state(binding) == before and shared.get_snapshot() == selected.payload
		and _mining_recovery_artifacts(path) == artifacts,
		"ordinary retained Reset preserves paid Mining acknowledgement, settings and recovery artifacts")
	await _retire(retained.game)
	_check(_mining_recovery_artifacts(path) == artifacts, "retained Mining teardown preserves all authority witnesses for explicit repair")

	# Fresh and direct probes are independent of retained-control mutations.
	path += "_fresh"
	staged = _write_mining_witness(path + ".paid-witness", paid_bytes) and _write_mining_witness(path, corrupt) \
		and _write_mining_witness(path + ".bak", unpaid_bytes)
	_check(staged, "fresh Mining probe stages the exact genuine paid and earned-unpaid documents")
	if not staged:
		return
	preflight = UserDataStore.new(path)
	selected = preflight.load()
	artifacts = _mining_recovery_artifacts(path)
	_check(selected.accepted and preflight.get_loaded_source() == &"backup" and artifacts.get(".recovery") == corrupt,
		"fresh Mining probe independently selects and retains the genuine fallback witnesses")
	var fresh := await _main(path)
	var fresh_binding := fresh.binding as NearbySectorActivityBinding
	shared = fresh.store as UserDataStore
	before = _mining_owned_state(fresh_binding)
	var ready := fresh_binding.get_cinder_mining_capacity_persistence_snapshot()
	print("MINING_BACKUP_FRESH_ADOPTION: ", {"owned": before, "persistence": ready,
		"source": shared.get_loaded_source(), "payload": shared.get_snapshot()})
	_check(not bool(ready.last_result.get("accepted", false))
		and int(before.activity.state) == CinderMiningPlatformActivity.State.IDLE and int(before.activity.generation) == 0
		and not before.capacity_paid and before.capacity.is_empty(),
		"fresh Main refuses backup-derived Mining timer, generation and unpaid capacity entitlement")
	_mining_intent(fresh.game, &"start_requested")
	_mining_intent(fresh.game, &"start_requested")
	_mining_intent(fresh.game, &"reset_requested")
	print("MINING_BACKUP_FRESH_CONTROLS: ", {"feedback": ((fresh.game as GameFlow).hud.get("_nearby_activity_feedback") as Label).text, "owned": _mining_owned_state(fresh_binding),
		"persistence": fresh_binding.get_cinder_mining_capacity_persistence_snapshot(), "source": shared.get_loaded_source(), "payload": shared.get_snapshot()})
	_check(_mining_owned_state(fresh_binding) == before and shared.get_loaded_source() == &"backup"
		and shared.get_snapshot() == selected.payload and _mining_recovery_artifacts(path) == artifacts,
		"ordinary fresh Start, repeated capacity retry and Reset preserve untrusted state and complete caller settings/data")
	await _retire(fresh.game)
	_check(_mining_recovery_artifacts(path) == artifacts, "fresh Mining teardown retains paid witness, unpaid fallback and quarantine")

	path += "_direct"
	staged = _write_mining_witness(path + ".paid-witness", paid_bytes) and _write_mining_witness(path, corrupt) \
		and _write_mining_witness(path + ".bak", unpaid_bytes)
	_check(staged, "direct typed Mining probe stages independent genuine witness documents")
	if not staged:
		return
	shared = UserDataStore.new(path)
	selected = shared.load()
	artifacts = _mining_recovery_artifacts(path)
	_check(selected.accepted and shared.get_loaded_source() == &"backup" and artifacts.get(".recovery") == corrupt,
		"direct typed persistence receives real backup-selected authority")
	codec = CinderMiningCapacityPersistence.new()
	_check(codec.configure(shared, &"cinder_mining_capacity").accepted, "the real Mining persistence owner configures without replacing store authority")
	var loaded := codec.load()
	print("MINING_BACKUP_DIRECT_LOAD: ", {"load": loaded, "source": shared.get_loaded_source()})
	_check(not loaded.accepted and shared.get_snapshot() == selected.payload and _mining_recovery_artifacts(path) == artifacts,
		"typed Mining load refuses adoption from backup without changing preserved authority documents")
	var saved := codec.save(earned, reward, "unit-mining-backup-direct")
	var saved_retry := codec.save(earned, reward, "unit-mining-backup-direct-retry")
	print("MINING_BACKUP_DIRECT_SAVE: ", {"save": saved, "retry": saved_retry,
		"source": shared.get_loaded_source(), "payload": shared.get_snapshot()})
	_check(not saved.accepted and not saved_retry.accepted and shared.get_loaded_source() == &"backup"
		and shared.get_snapshot() == selected.payload and _mining_recovery_artifacts(path) == artifacts,
		"typed Mining capacity publication repeatedly refuses untrusted repayment/promotion and preserves all settings/caller data")


func _write_mining_witness(path: String, bytes: PackedByteArray) -> bool:
	var writer := FileAccess.open(path, FileAccess.WRITE)
	if writer == null:
		return false
	writer.store_buffer(bytes)
	writer.close()
	return true


func _mining_recovery_artifacts(path: String) -> Dictionary:
	var absolute := ProjectSettings.globalize_path(path)
	var directory := DirAccess.open(absolute.get_base_dir())
	var result := {}
	if directory == null:
		return result
	var name := absolute.get_file()
	for filename in directory.get_files():
		if filename == name or filename.begins_with(name + "."):
			result[filename.trim_prefix(name)] = FileAccess.get_file_as_bytes(absolute.get_base_dir().path_join(filename))
	return result


func _mining_owned_state(binding: NearbySectorActivityBinding) -> Dictionary:
	return {"activity": (binding.get("_mining_activity") as RefCounted).call("get_snapshot"),
		"capacity_paid": binding.get("_mining_capacity_paid"), "capacity": (binding.get("_restored_mining_capacity") as Dictionary).duplicate(true)}


func _test_published_sync(path: String) -> void:
	var filesystem := PublicationSyncFilesystem.new()
	var runtime := await _main(path, true, filesystem)
	var binding := runtime.binding as NearbySectorActivityBinding
	_mining_intent(runtime.game, &"start_requested")
	binding.advance_mining_activity(6.0)
	# Let the requested-session checkpoint publish normally. Fail only the
	# capacity acknowledgement publication, after the real rename succeeds.
	var activity := binding.get("_mining_activity") as RefCounted
	var request := activity.call("request_reward") as Dictionary
	binding.call("_persist_mining_session")
	filesystem.published = false
	filesystem.fail_published_sync = true
	var reconciled := binding.call("_persist_mining_capacity", request) as Dictionary
	var bytes := FileAccess.get_file_as_bytes(path)
	_check(bool(reconciled.accepted) and reconciled.reason == &"mining_session_published_reconciled"
		and not bool(binding.request_mining_reward().accepted)
		and FileAccess.get_file_as_bytes(path) == bytes, "post-publication directory-sync failure reconciles the actual paid record without duplicate capacity")
	await _retire(runtime.game)
	var store := StoreScript.new(path)
	var persistence := CinderMiningCapacityPersistence.new()
	persistence.configure(store, &"cinder_mining_capacity")
	var restored := persistence.load()
	_check(bool(restored.accepted) and bool((restored.session as Dictionary).capacity_paid), "reconciled paid acknowledgement is durable in a fresh real store")


func _test_record_compatibility(path: String) -> void:
	var store := StoreScript.new(path)
	store.load()
	var persistence := CinderMiningCapacityPersistence.new()
	persistence.configure(store, &"cinder_mining_capacity")
	var activity := CinderMiningPlatformActivity.new()
	activity.start(CinderMiningPlatformActivity.APPROACH_ANCHOR)
	activity.advance_physics(5.999999)
	_check(int(activity.get_snapshot().state) == CinderMiningPlatformActivity.State.ACTIVE, "approximate six-second timer cannot create an inconsistent terminal checkpoint")
	activity.advance_physics(0.000001)
	var reward := activity.request_reward()
	var record := persistence.capture(activity.get_snapshot(), reward).record as Dictionary
	var malformed := record.duplicate(true)
	malformed.schema_version = {"invalid": 2}
	_check(not bool(persistence.validate_record(malformed).accepted), "malformed schema type is safely refused")
	malformed = record.duplicate(true)
	(malformed.session as Dictionary).elapsed_seconds = 5.0
	_check(not bool(persistence.validate_record(malformed).accepted), "terminal session requires the actual full timer")
	malformed = record.duplicate(true)
	(malformed.session as Dictionary).elapsed_seconds = NAN
	_check(not bool(persistence.validate_record(malformed).accepted), "non-finite timer cannot restore an entitlement")
	malformed = record.duplicate(true)
	(malformed.session as Dictionary).generation = 1.5
	_check(not bool(persistence.validate_record(malformed).accepted), "fractional generation is refused")
	malformed = record.duplicate(true)
	(malformed.capacity as Dictionary).reward_receipt = []
	_check(not bool(persistence.validate_record(malformed).accepted), "malformed receipt type is safely refused")
	var legacy := record.duplicate(true)
	legacy.erase("session")
	legacy.schema_version = 1
	var payload := store.get_snapshot()
	payload.cinder_mining_capacity = legacy
	store.commit(payload, store.get_generation(), "legacy-mining")
	var legacy_bytes := FileAccess.get_file_as_bytes(path)
	var loaded := persistence.load()
	_check(bool(loaded.accepted) and (loaded.session as Dictionary).is_empty()
		and FileAccess.get_file_as_bytes(path) == legacy_bytes, "legacy capacity is unchanged presentation with no invented session")
	payload.cinder_mining_capacity = record.duplicate(true)
	(payload.cinder_mining_capacity as Dictionary).schema_version = 3
	store.commit(payload, store.get_generation(), "newer-mining")
	var future_bytes := FileAccess.get_file_as_bytes(path)
	var refused := persistence.save(activity.get_snapshot(), reward, "must-refuse-newer")
	_check(not bool(persistence.load().accepted) and not bool(refused.accepted)
		and FileAccess.get_file_as_bytes(path) == future_bytes, "unsupported newer mining record is preserved and never overwritten")


func _main(path: String, approach := true, filesystem: RefCounted = null) -> Dictionary:
	var store := StoreScript.new(path, filesystem)
	var game := MAIN_SCENE.instantiate() as GameFlow
	game.configure_runtime_settings_persistence(store, path + ".legacy")
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	var cluster := await _load_main_mining_cluster(game)
	var binding := cluster.get_node(^"ActivityBinding") as NearbySectorActivityBinding
	game.bind_cinder_mining_capacity_persistence(binding)
	var craft := game.get_flyable_ships()[1] as HeroShip
	game.active_ship = craft
	if approach: craft.global_position = CinderMiningPlatformActivity.APPROACH_ANCHOR
	return {"game": game, "binding": binding, "store": store, "sample": {
		"available": true, "actor_kind": &"ship", "actor_instance_id": craft.get_instance_id(),
		"position": CinderMiningPlatformActivity.APPROACH_ANCHOR}}

func _retire(game: GameFlow) -> void:
	game.queue_free()
	for _frame in 3: await process_frame

func _mining_intent(game: GameFlow, action: StringName) -> void:
	game.call(&"_on_hud_nearby_activity_intent_requested", {
		"activity_id": CinderMiningPlatformActivity.ACTIVITY_ID, "reason": action,
	})


func _load_main_mining_cluster(game: GameFlow) -> NearbySectorCluster:
	game.get_node(^"CinderStreamingProductionBinding").set_physics_process(false)
	var bootstrap := game.get_node(^"CinderStreamingBootstrap") as CinderStreamingBootstrap
	bootstrap.update_position(CinderStreamingBootstrap.EXPECTED_NAVIGATION_ANCHOR)
	for _frame in 60:
		if bootstrap.get_loaded_instance() != null:
			return bootstrap.get_loaded_instance() as NearbySectorCluster
		await process_frame
	_check(false, "actual Main loads mining through the production Cinder bootstrap")
	return null


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition: _failures.append(message)
