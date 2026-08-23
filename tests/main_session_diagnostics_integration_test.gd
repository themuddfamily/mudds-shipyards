extends SceneTree

const GameFlowType := preload("res://scripts/game/game_flow.gd")
const Store := preload("res://scripts/persistence/user_data_store.gd")
const Filesystem := preload("res://scripts/persistence/user_data_filesystem.gd")

var _failures: Array[String] = []
var _assertions := 0


class MemoryFilesystem extends Filesystem:
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
	var store := Store.new("memory://main-session-diagnostics.json", filesystem)
	_check(bool(store.load().get("accepted", false)), "isolated diagnostics store loads empty")
	var flow := GameFlowType.new()
	flow.set("_runtime_settings_user_data_store", store)
	flow.set_session_diagnostics_filesystem(filesystem)
	flow._initialize_session_diagnostics()
	var started := flow.get_session_diagnostics_snapshot()
	_check(
		bool(started.available)
		and bool(started.bridge.get("coordinator", {}).get("active", false))
		and StringName(started.last_status.reason) == &"started",
		"Main composition publishes a running privacy-safe session marker"
	)
	for transition_code in [2, 4, 5, 6, 7, 8, 9]:
		flow.record_session_lifecycle_transition(transition_code, 6, transition_code != 5)
	var events := flow.get_session_diagnostics_snapshot().bridge.record.events as Array
	var observed_codes := {}
	var bounded := true
	for event in events:
		var fields := event.fields as Dictionary
		observed_codes[int(fields.input_device_code)] = true
		bounded = bounded and event.event_code == "control_source_changed" \
			and fields.size() == 3 \
			and not fields.has("name") and not fields.has("path")
	_check(
		 events.size() == 8
		 and observed_codes.size() == 8
		 and bounded,
		"GameFlow lifecycle transitions retain only bounded numeric diagnostic fields"
	)
	var closed := flow.mark_orderly_session_shutdown()
	var finished := flow.get_session_diagnostics_snapshot()
	_check(
		bool(closed.accepted)
		and StringName(closed.reason) == &"orderly_shutdown"
		and StringName(finished.bridge.get("state", "")) == &"clean",
		"caller-confirmed Main shutdown clears the running marker without touching gameplay state"
	)
	var unclean := GameFlowType.new()
	unclean.set("_runtime_settings_user_data_store", store)
	unclean.set_session_diagnostics_filesystem(filesystem)
	unclean._initialize_session_diagnostics()
	unclean.free()
	flow.free()
	var restarted_store := Store.new("memory://main-session-diagnostics.json", filesystem)
	_check(bool(restarted_store.load().accepted), "restart fixture loads the prior running marker")
	var restarted := GameFlowType.new()
	restarted.set("_runtime_settings_user_data_store", restarted_store)
	restarted.set_session_diagnostics_filesystem(filesystem)
	restarted._initialize_session_diagnostics()
	var recovery := restarted.get_recovery_available_snapshot()
	var recovery_phase := restarted.phase
	_check(
		StringName(recovery.get("state", "")) == &"running"
		and int(recovery.get("session_id", 0)) == 1
		and restarted.phase == recovery_phase,
		"unclean restart exposes a detached recovery snapshot without changing GameFlow phase"
	)
	var recommendation := restarted.get_session_start_recommendation()
	_check(
		bool(recommendation.available)
		and bool(recommendation.requires_caller_choice)
		and recommendation.choices == [&"normal_start", &"safe_graphics_windowed", &"discard"]
		and not bool(recommendation.applies_settings)
		and not bool(recommendation.persists_settings)
		and restarted.phase == recovery_phase,
		"safe-start guidance is an explicit recommendation rather than an automatic settings change"
	)
	var conflicting_flags := restarted.apply_command_line_recovery_args(
		PackedStringArray(["--safe-mode", "--discard-recovery"])
	)
	_check(
		not bool(conflicting_flags.accepted)
		and StringName(conflicting_flags.reason) == &"conflicting_recovery_flags"
		and not restarted.get_recovery_available_snapshot().is_empty(),
		"conflicting command-line recovery flags reject without consuming the receipt"
	)
	var acknowledged := restarted.choose_session_start_recovery(&"normal_start")
	_check(
		bool(acknowledged.accepted)
		and restarted.get_recovery_available_snapshot().is_empty(),
		"caller normal-start choice retires only the detached recovery receipt"
	)
	var replayed := restarted.choose_session_start_recovery(&"normal_start")
	_check(not bool(replayed.accepted), "replayed recovery choice is rejected")
	restarted.free()
	var discard_store := Store.new("memory://main-session-diagnostics.json", filesystem)
	_check(bool(discard_store.load().accepted), "discard fixture reloads the running marker")
	var discard_flow := GameFlowType.new()
	discard_flow.set("_runtime_settings_user_data_store", discard_store)
	discard_flow.set_session_diagnostics_filesystem(filesystem)
	discard_flow._initialize_session_diagnostics()
	var discarded := discard_flow.apply_command_line_recovery_args(
		PackedStringArray(["--discard-recovery"])
	)
	_check(
		bool(discarded.accepted)
		and discard_flow.get_recovery_available_snapshot().is_empty(),
		"caller discard clears only the in-memory recovery receipt"
	)
	discard_flow.mark_orderly_session_shutdown()
	discard_flow.free()
	if _failures.is_empty():
		print("MAIN_SESSION_DIAGNOSTICS_INTEGRATION_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	printerr("MAIN_SESSION_DIAGNOSTICS_INTEGRATION_TEST_FAILED: ", _failures)
	quit(1)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(description)
		push_error("FAIL: " + description)
