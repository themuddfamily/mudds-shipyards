extends SceneTree

const Store := preload("res://scripts/persistence/user_data_store.gd")
const Lifecycle := preload("res://scripts/persistence/save_reentry_lifecycle.gd")

const STORE_PATH := "memory://save-reentry.json"

var _failures := PackedStringArray()
var _assertions := 0


class MemoryFilesystem extends UserDataFilesystem:
	var files: Dictionary = {}

	func file_exists(path: String) -> bool:
		return files.has(path)

	func directory_exists(_path: String) -> bool:
		return false

	func ensure_parent_directory(_path: String) -> Error:
		return OK

	func read_bytes(path: String, maximum_bytes: int) -> Dictionary:
		if not files.has(path):
			return {"error": ERR_FILE_NOT_FOUND, "bytes": PackedByteArray()}
		var bytes := (files[path] as PackedByteArray).duplicate()
		if bytes.size() > maximum_bytes:
			return {"error": ERR_FILE_CORRUPT, "bytes": PackedByteArray()}
		return {"error": OK, "bytes": bytes}

	func write_bytes_and_flush(path: String, bytes: PackedByteArray) -> Error:
		files[path] = bytes.duplicate()
		return OK

	func remove_path(path: String) -> Error:
		if not files.has(path):
			return ERR_FILE_NOT_FOUND
		files.erase(path)
		return OK

	func rename_path(from_path: String, to_path: String) -> Error:
		if not files.has(from_path):
			return ERR_FILE_NOT_FOUND
		if files.has(to_path):
			return ERR_ALREADY_EXISTS
		files[to_path] = (files[from_path] as PackedByteArray).duplicate()
		files.erase(from_path)
		return OK


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var filesystem := MemoryFilesystem.new()
	var store := Store.new(STORE_PATH, filesystem)
	_check(bool(store.load().accepted), "store opens an empty authority")
	var lifecycle := Lifecycle.new(store)
	_check(bool(lifecycle.restore().accepted), "missing save namespace restores as first run")

	var opened := lifecycle.open_session("slot-a", 41, 1, "save-open-001")
	_check(
		bool(opened.accepted) and opened.reason == &"opened"
		and opened.state == Lifecycle.STATE_ACTIVE,
		"fresh logical session opens at attachment generation one"
	)
	var payload := {
		"location": "central_berth",
		"ship": {"id": "torrent", "health": 0.92},
		"activity": {"id": "timed_race", "phase": "return"},
	}
	var checkpoint := lifecycle.save_checkpoint(
		"slot-a", 41, 1, 120, payload, "save-checkpoint-001"
	)
	_check(
		bool(checkpoint.accepted) and checkpoint.reason == &"checkpointed"
		and int(checkpoint.checkpoint_generation) == 1
		and int(checkpoint.physics_tick) == 120,
		"checkpoint commits opaque gameplay state with monotonic progress"
	)
	var bytes_before := (filesystem.files.get(STORE_PATH, PackedByteArray()) as PackedByteArray).duplicate()
	var regressed := lifecycle.save_checkpoint(
		"slot-a", 41, 1, 119, {"location": "stale"}, "save-checkpoint-002"
	)
	_check(
		not bool(regressed.accepted) and regressed.reason == &"physics_tick_regressed"
		and (filesystem.files.get(STORE_PATH, PackedByteArray()) as PackedByteArray) == bytes_before,
		"regressed checkpoint rejects before changing durable bytes"
	)
	var detached := lifecycle.detach_session("slot-a", 41, 1, "save-detach-001")
	_check(
		bool(detached.accepted) and detached.reason == &"detached"
		and detached.state == Lifecycle.STATE_DETACHED,
		"detach persists lifecycle state without replaying the checkpoint"
	)
	var stale_reentry := lifecycle.reenter_session("slot-a", 41, 1, "save-reenter-stale")
	_check(
		not bool(stale_reentry.accepted)
		and stale_reentry.reason == &"stale_attachment_generation",
		"duplicate attachment generation cannot re-enter a detached session"
	)
	var reentered := lifecycle.recover_last_safe_checkpoint("slot-a", 41, 2, "save-reenter-001")
	_check(
		bool(reentered.accepted) and reentered.reason == &"reentered"
		and reentered.state == Lifecycle.STATE_ACTIVE
		and int(reentered.checkpoint_generation) == 1
		and int(reentered.physics_tick) == 120,
		"next attachment generation restores exact checkpoint progress"
	)
	var recovered_retry := lifecycle.recover_last_safe_checkpoint(
		"slot-a", 41, 2, "save-reentry-retry"
	)
	_check(
		bool(recovered_retry.accepted) and recovered_retry.reason == &"already_active"
		and int(recovered_retry.checkpoint_generation) == 1
		and int(recovered_retry.physics_tick) == 120,
		"re-entry recovery is idempotent after a lost successful handoff response"
	)
	var stale_recovery := lifecycle.recover_last_safe_checkpoint(
		"slot-a", 41, 1, "save-reentry-stale-recovery"
	)
	_check(
		not bool(stale_recovery.accepted)
		and stale_recovery.reason == &"stale_attachment_generation",
		"re-entry recovery rejects a stale attachment without rewinding the checkpoint"
	)
	var post_reentry := lifecycle.save_checkpoint(
		"slot-a", 41, 2, 121, {"location": "flight_lane", "ship": {"id": "torrent"}},
		"save-checkpoint-002"
	)
	_check(
		bool(post_reentry.accepted) and int(post_reentry.checkpoint_generation) == 2,
		"post-re-entry save advances one checkpoint under the new attachment"
	)
	var closed := lifecycle.close_session("slot-a", 41, 2, "save-close-001")
	_check(
		bool(closed.accepted) and closed.reason == &"closed"
		and closed.state == Lifecycle.STATE_CLOSED,
		"clean close preserves the final checkpoint as closed state"
	)

	var restored := Lifecycle.new(store)
	var restore_status := restored.restore()
	_check(
		bool(restore_status.accepted) and restore_status.reason == &"restored"
		and restored.get_snapshot().state == Lifecycle.STATE_CLOSED
		and int(restored.get_snapshot().checkpoint_generation) == 2
		and restored.get_snapshot().payload.location == "flight_lane",
		"a new lifecycle object restores the final save without scene authority"
	)
	var forged := restored.reenter_session("slot-a", 41, 3, "save-forged-reentry")
	_check(
		not bool(forged.accepted) and forged.reason == &"session_not_detached",
		"closed state cannot be revived through the detached re-entry path"
	)
	_check(bool(restored.audit().valid), "restored contract audit is valid")

	var malformed := Lifecycle.decode_snapshot({
		"schema_version": Lifecycle.SCHEMA_VERSION + 1,
		"state": Lifecycle.STATE_CLOSED,
		"slot_id": "slot-a",
		"session_id": 41,
		"attachment_generation": 2,
		"checkpoint_generation": 2,
		"physics_tick": 121,
		"payload": {},
	})
	_check(not bool(malformed.accepted) and malformed.reason == &"newer_schema", "newer save schemas fail closed")

	if not _failures.is_empty():
		printerr("save_reentry_lifecycle_test failures: ", "; ".join(_failures))
		quit(1)
	else:
		print("save_reentry_lifecycle_test: %d assertions passed" % _assertions)
		quit(0)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(description)
