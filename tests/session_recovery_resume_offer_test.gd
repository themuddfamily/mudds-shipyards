extends SceneTree

## Unclean shutdown -> resume offer. A running marker left by a session that
## never reached mark_clean_shutdown makes the next start a recovery; the
## startup card then offers "Resume Last Save" (naming the save, including a
## fallback to a rotated copy) or "Start Fresh", each emitting its own intent.

const Coordinator := preload("res://scripts/diagnostics/crash_recovery_coordinator.gd")
const Store := preload("res://scripts/persistence/user_data_store.gd")
const HudType := preload("res://scripts/ui/hud.gd")
const GameFlowScript := preload("res://scripts/game/game_flow.gd")

const STORE_PATH := "memory://resume_offer.json"

var _assertions := 0
var _failures := PackedStringArray()
var _requests: Array[StringName] = []


class FakeFilesystem extends UserDataFilesystem:
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
	call_deferred(&"_run")


func _run() -> void:
	var recovery_snapshot := _test_unclean_shutdown_is_detected_and_clean_quit_is_not()
	_test_save_summary_names_the_resumed_save()
	await _test_startup_card_offers_resume_or_start_fresh(recovery_snapshot)
	_finish()


func _test_unclean_shutdown_is_detected_and_clean_quit_is_not() -> Dictionary:
	var filesystem := FakeFilesystem.new()
	var store := Store.new(STORE_PATH, filesystem) as UserDataStore
	store.load()
	var first = Coordinator.new(store)
	first.restore()
	_check(first.begin_session(1, "resume-start-1").reason == &"started", "the first session writes its running marker at start")
	# The process dies here: no mark_clean_shutdown.
	var crashed_store := Store.new(STORE_PATH, filesystem) as UserDataStore
	crashed_store.load()
	var second = Coordinator.new(crashed_store)
	second.restore()
	var interrupted: Dictionary = second.get_snapshot()
	var recovered: Dictionary = second.begin_session(2, "resume-start-2")
	_check(
		bool(recovered.accepted) and recovered.reason == &"recovered_previous_session" and bool(recovered.recovered),
		"the next start detects the unclean shutdown from the left-over marker"
	)
	_check(
		bool(second.mark_clean_shutdown(2, 10, 0.5, "resume-clean-2").accepted),
		"a clean quit clears the marker"
	)
	var clean_store := Store.new(STORE_PATH, filesystem) as UserDataStore
	clean_store.load()
	var third = Coordinator.new(clean_store)
	third.restore()
	_check(third.begin_session(3, "resume-start-3").reason == &"started", "after a clean quit the next start is not treated as a crash")
	return interrupted


func _test_save_summary_names_the_resumed_save() -> void:
	var flow = GameFlowScript.new()
	flow.set("_runtime_settings_load_status", {
		"accepted": true, "reason": &"loaded", "store_reason": &"ok", "generation": 12,
		"store_status": {"reason": &"ok", "generation": 12},
	})
	_check(str(flow.get_session_recovery_save_summary()).contains("last good save (save 12)"), "a normal load names the save Resume continues from")
	flow.set("_runtime_settings_load_status", {
		"accepted": true, "reason": &"loaded", "store_reason": &"primary_invalid_backup_loaded", "generation": 11,
		"store_status": {"reason": &"primary_invalid_backup_loaded", "generation": 11},
	})
	_check(str(flow.get_session_recovery_save_summary()).contains("previous good save (save 11)"), "a damaged save names the backup Resume will use")
	flow.set("_runtime_settings_load_status", {
		"accepted": true, "reason": &"loaded", "store_reason": &"primary_invalid_backup_loaded", "generation": 9,
		"store_status": {
			"reason": &"primary_invalid_backup_loaded", "generation": 9,
			"fallback": &"rotated_history", "history_index": 2,
		},
	})
	_check(str(flow.get_session_recovery_save_summary()).contains("rotated copy 2"), "a damaged save and backup name the rotated copy Resume will use")
	flow.free()


func _test_startup_card_offers_resume_or_start_fresh(interrupted: Dictionary) -> void:
	var hud := HudType.new()
	root.add_child(hud)
	await process_frame
	hud.session_recovery_continue_requested.connect(func(_t: int, _g: int) -> void: _requests.append(&"resume"))
	hud.session_recovery_discard_requested.connect(func(_t: int, _g: int) -> void: _requests.append(&"start_fresh"))
	hud.set_session_recovery_save_summary("Resume continues from your last good save (save 12).")
	var recovery := {
		"schema_version": 1,
		"state": "running",
		"session_id": maxi(1, int(interrupted.get("session_id", 1))),
		"startup_generation": maxi(1, int(interrupted.get("startup_generation", 1))),
		"unclean_start_count": 1,
		"last_physics_tick": 0,
		"last_elapsed_physics_seconds": 0.0,
	}
	var recommendation := {
		"available": true,
		"requires_caller_choice": true,
		"severity": &"review_prior_session",
		"choices": [&"normal_start", &"safe_graphics_windowed", &"discard"],
		"safe_start_patch": {},
		"applies_settings": false,
		"persists_settings": false,
	}
	var presented := hud.present_session_recovery_notice(recovery, recommendation)
	_check(bool(presented.accepted), "the interrupted-session card is presented")
	var detail := hud.get("_recovery_prompt_detail") as Label
	var actions := hud.get("_recovery_prompt_actions") as HBoxContainer
	_check(detail.text.contains("last good save (save 12)"), "the card names the save that Resume keeps")
	var resume := actions.get_child(1) as Button
	var fresh := actions.get_child(2) as Button
	_check(resume.text == "Resume Last Save" and fresh.text == "Start Fresh", "the card offers Resume Last Save and Start Fresh")
	fresh.pressed.emit()
	_check(_requests.size() == 1 and _requests[0] == &"start_fresh", "Start Fresh emits its own intent and latches the choice")
	resume.pressed.emit()
	_check(_requests.size() == 1, "a second choice after the latch is ignored")
	hud.queue_free()
	await process_frame


func _check(condition: bool, label: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", label)
	else:
		_failures.append(label)
		push_error("FAIL: %s" % label)


func _finish() -> void:
	if _failures.is_empty():
		print("SESSION_RECOVERY_RESUME_OFFER_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	printerr("SESSION_RECOVERY_RESUME_OFFER_TEST_FAILED: %d/%d assertions failed" % [_failures.size(), _assertions])
	for failure in _failures:
		printerr(" - ", failure)
	quit(1)
