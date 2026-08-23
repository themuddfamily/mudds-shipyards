extends SceneTree

const BindingScript := preload("res://scripts/world/ember_surface_loop_production_binding.gd")
const StoreScript := preload("res://scripts/persistence/user_data_store.gd")
const FilesystemScript := preload("res://scripts/persistence/user_data_filesystem.gd")
const STORE_PATH := "memory://ember-return.json"
const SLOT := &"return_slot"

var _failures := PackedStringArray()


class MemoryFilesystem extends FilesystemScript:
	var files: Dictionary = {}
	var fail_write_once := false
	func file_exists(path: String) -> bool: return files.has(path)
	func directory_exists(_path: String) -> bool: return false
	func ensure_parent_directory(_path: String) -> Error: return OK
	func read_bytes(path: String, maximum_bytes: int) -> Dictionary:
		if not files.has(path):
			return {"error": ERR_FILE_NOT_FOUND, "bytes": PackedByteArray()}
		var bytes := (files[path] as PackedByteArray).duplicate()
		return {
			"error": OK if bytes.size() <= maximum_bytes else ERR_FILE_CORRUPT,
			"bytes": bytes if bytes.size() <= maximum_bytes else PackedByteArray(),
		}
	func write_bytes_and_flush(path: String, bytes: PackedByteArray) -> Error:
		if fail_write_once:
			fail_write_once = false
			return ERR_FILE_CANT_WRITE
		files[path] = bytes.duplicate()
		return OK
	func remove_path(path: String) -> Error:
		if not files.has(path): return ERR_FILE_NOT_FOUND
		files.erase(path)
		return OK
	func rename_path(from_path: String, to_path: String) -> Error:
		if not files.has(from_path): return ERR_FILE_NOT_FOUND
		if files.has(to_path): return ERR_ALREADY_EXISTS
		files[to_path] = (files[from_path] as PackedByteArray).duplicate()
		files.erase(from_path)
		return OK


class Runtime:
	func get_presentation_snapshot() -> Dictionary:
		return {
			"state_id": &"completed", "generation": 7,
			"attachment_generation": 4, "reward_authority": false,
		}
	func get_snapshot() -> Dictionary:
		return {
			"phase_id": &"completed", "return_target_id": &"mudds_shipyards",
			"world_id": &"ember_moon", "run_generation": 7,
			"attachment_generation": 4,
		}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var filesystem := MemoryFilesystem.new()
	var store := StoreScript.new(STORE_PATH, filesystem) as UserDataStore
	_check(bool(store.load().get("accepted", false)), "store loads before binding")
	_check(
		bool(store.commit(
			{"settings": {"volume": 0.75}, "diagnostics": {"boot": "kept"}},
			0, "seed-unrelated"
		).get("accepted", false)),
		"fixture publishes unrelated namespaces",
	)
	var binding := BindingScript.new()
	_check(
		bool(binding.configure_planetary_return_persistence(store, SLOT).get("accepted", false)),
		"binding accepts the existing loaded store",
	)
	filesystem.fail_write_once = true
	var failed_save := binding.save_planetary_return_persistence(
		Runtime.new(), Runtime.new(), _receipt(), 1, "return-write-fails"
	)
	_check(
		not bool(failed_save.get("accepted", false))
		and failed_save.get("reason") == &"temp_write_failed"
		and store.get_snapshot() == {
			"settings": {"volume": 0.75}, "diagnostics": {"boot": "kept"},
		},
		"a forced write failure publishes no partial return and preserves every namespace",
	)
	var saved := binding.save_planetary_return_persistence(
		Runtime.new(), Runtime.new(), _receipt(), 1, "return-write-succeeds"
	)
	var published := store.get_snapshot()
	_check(
		bool(saved.get("accepted", false))
		and published.settings.volume == 0.75
		and published.diagnostics.boot == "kept"
		and published.return_slot.payload_kind == "ember_planetary_return"
		and published.return_slot.session.completed_return.returned_receipt.berth_receipt.token == "lease-7",
		"the exact return receipt is atomically added under its slot without replacing siblings",
	)
	var stale_save := binding.save_planetary_return_persistence(
		Runtime.new(), Runtime.new(), _receipt(), 2, "stale-return-generation"
	)
	_check(
		stale_save.reason == &"return_persistence_stale_generation"
		and store.get_generation() == 2,
		"the published return generation cannot be overwritten or replay-saved",
	)

	var wrong_slot := BindingScript.new()
	wrong_slot.configure_planetary_return_persistence(store, &"another_return_slot")
	_check(
		wrong_slot.restore_planetary_return_persistence().reason == &"return_persistence_wrong_slot",
		"a return belonging to another slot is rejected",
	)

	var valid_payload := store.get_snapshot()
	var newer_payload := valid_payload.duplicate(true)
	newer_payload.return_slot.schema_version = 2
	_check(bool(store.commit(newer_payload, 2, "newer-inner-schema").get("accepted", false)), "newer fixture commits")
	var newer_binding := BindingScript.new()
	newer_binding.configure_planetary_return_persistence(store, SLOT)
	_check(
		newer_binding.restore_planetary_return_persistence().reason == &"return_persistence_newer_schema",
		"a newer return schema fails closed",
	)
	_check(bool(store.commit(valid_payload, 3, "restore-valid-return").get("accepted", false)), "valid fixture is restored")

	var corrupt_payload := valid_payload.duplicate(true)
	corrupt_payload.return_slot.run_generation = 8
	_check(bool(store.commit(corrupt_payload, 4, "corrupt-generation").get("accepted", false)), "corrupt fixture commits")
	var corrupt_binding := BindingScript.new()
	corrupt_binding.configure_planetary_return_persistence(store, SLOT)
	var corrupt_result := corrupt_binding.restore_planetary_return_persistence()
	_check(
		corrupt_result.reason == &"return_persistence_payload_corrupt",
		"wrapper/session generation drift is rejected",
	)
	_check(bool(store.commit(valid_payload, 5, "restore-valid-return-2").get("accepted", false)), "valid fixture is restored again")

	var active_payload := valid_payload.duplicate(true)
	active_payload.return_slot.session.surface_attachment.active = true
	_check(bool(store.commit(active_payload, 6, "active-surface-record").get("accepted", false)), "active fixture commits")
	var active_binding := BindingScript.new()
	active_binding.configure_planetary_return_persistence(store, SLOT)
	_check(
		active_binding.restore_planetary_return_persistence().reason == &"return_persistence_surface_attachment_active",
		"persisted active-surface authority is rejected",
	)
	_check(bool(store.commit(valid_payload, 7, "restore-valid-return-3").get("accepted", false)), "valid fixture is restored a third time")

	var reward_payload := valid_payload.duplicate(true)
	reward_payload.return_slot.session.reward_replay_allowed = true
	_check(bool(store.commit(reward_payload, 8, "reward-authority-record").get("accepted", false)), "reward fixture commits")
	var reward_binding := BindingScript.new()
	reward_binding.configure_planetary_return_persistence(store, SLOT)
	_check(
		reward_binding.restore_planetary_return_persistence().reason == &"return_persistence_reward_authority_present",
		"persisted reward authority is rejected",
	)
	_check(bool(store.commit(valid_payload, 9, "restore-valid-return-4").get("accepted", false)), "valid fixture is restored for re-entry")

	var reloaded_store := StoreScript.new(STORE_PATH, filesystem) as UserDataStore
	_check(bool(reloaded_store.load().get("accepted", false)), "a fresh process store reloads the return")
	var reentered := BindingScript.new()
	reentered.configure_planetary_return_persistence(reloaded_store, SLOT)
	var restored := reentered.restore_planetary_return_persistence()
	_check(
		bool(restored.get("accepted", false))
		and bool(restored.detached) and bool(restored.fresh_station)
		and bool(restored.requires_retirement)
		and restored.session.run_generation == 7,
		"fresh station re-entry replays the detached return exactly once",
	)
	_check(
		reentered.restore_planetary_return_persistence().reason == &"return_persistence_stale_generation",
		"the same live binding cannot replay the receipt twice",
	)
	filesystem.fail_write_once = true
	var failed_retirement := reentered.retire_planetary_return_persistence(
		reloaded_store.get_generation(), "retire-write-fails"
	)
	_check(
		not bool(failed_retirement.get("accepted", false))
		and failed_retirement.reason == &"temp_write_failed"
		and reloaded_store.get_snapshot().has("return_slot"),
		"failed retirement leaves the published receipt recoverable",
	)

	var retry_store := StoreScript.new(STORE_PATH, filesystem) as UserDataStore
	_check(bool(retry_store.load().get("accepted", false)), "a fresh process reloads after failed retirement")
	var retry_binding := BindingScript.new()
	retry_binding.configure_planetary_return_persistence(retry_store, SLOT)
	var retry_restored := retry_binding.restore_planetary_return_persistence()
	_check(
		bool(retry_restored.get("accepted", false)),
		"failed retirement permits one recovery replay in a fresh binding",
	)
	var retired := retry_binding.retire_planetary_return_persistence(
		retry_store.get_generation(), "retire-return-slot"
	)
	_check(
		bool(retired.get("accepted", false))
		and retry_store.get_snapshot() == {
			"settings": {"volume": 0.75}, "diagnostics": {"boot": "kept"},
		},
		"explicit retirement atomically removes only the return namespace",
	)
	var final_store := StoreScript.new(STORE_PATH, filesystem) as UserDataStore
	_check(bool(final_store.load().get("accepted", false)), "retired store reloads")
	var final_binding := BindingScript.new()
	final_binding.configure_planetary_return_persistence(final_store, SLOT)
	_check(
		final_binding.restore_planetary_return_persistence().reason == &"return_persistence_not_found"
		and final_store.get_snapshot().settings.volume == 0.75
		and final_store.get_snapshot().diagnostics.boot == "kept"
		and not bool(final_binding.get_planetary_return_persistence_snapshot().owns_save_authority)
		and not bool(final_binding.get_planetary_return_persistence_snapshot().owns_movement_authority)
		and not bool(final_binding.get_planetary_return_persistence_snapshot().owns_berth_authority)
		and not bool(final_binding.get_planetary_return_persistence_snapshot().owns_reward_authority),
		"retirement survives reload and the bridge owns no gameplay authority",
	)

	binding.free()
	wrong_slot.free()
	newer_binding.free()
	corrupt_binding.free()
	active_binding.free()
	reward_binding.free()
	reentered.free()
	retry_binding.free()
	final_binding.free()
	await process_frame
	if not _failures.is_empty():
		for failure in _failures:
			push_error(failure)
		quit(1)
		return
	print("EMBER_RETURN_PERSISTENCE_TEST_OK: failed writes recover and explicit retirement survives re-entry")
	quit(0)


func _receipt() -> Dictionary:
	return {
		"accepted": true,
		"reason": &"returned_to_station",
		"berth_receipt": {
			"accepted": true,
			"reason": &"return_berth_occupied",
			"berth_id": &"mudds_return_berth",
			"token": &"lease-7",
			"session_generation": 7,
			"attachment_generation": 4,
			"actor_instance_id": 11,
			"craft_instance_id": 22,
		},
		"contract_receipt": {
			"accepted": true,
			"reason": &"returned_to_station",
			"phase_id": &"completed",
		},
	}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
