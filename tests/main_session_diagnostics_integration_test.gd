extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const GameFlowType := preload("res://scripts/game/game_flow.gd")
const Store := preload("res://scripts/persistence/user_data_store.gd")
const Filesystem := preload("res://scripts/persistence/user_data_filesystem.gd")

var _failures: Array[String] = []
var _assertions := 0


class MemoryFilesystem extends Filesystem:
	var files: Dictionary = {}
	var write_count := 0
	var fail_write_number := -1

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
		write_count += 1
		if write_count == fail_write_number:
			return ERR_FILE_CANT_WRITE
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
	_test_orderly_shutdown_composition()
	await _test_detach_reentry_and_free_remain_dirty()
	if _failures.is_empty():
		print("MAIN_SESSION_DIAGNOSTICS_INTEGRATION_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	printerr("MAIN_SESSION_DIAGNOSTICS_INTEGRATION_TEST_FAILED: ", _failures)
	quit(1)


func _test_orderly_shutdown_composition() -> void:
	var successful_filesystem := MemoryFilesystem.new()
	var successful := _new_composed_marker_flow(
		"memory://orderly-composite-success.json",
		successful_filesystem
	)
	var successful_before := _unrelated_state_snapshot(successful)
	var successful_writes_before := successful_filesystem.write_count
	var closed := successful.mark_orderly_shutdown()
	var safe_status := closed.get("safe_start", {}) as Dictionary
	var diagnostics_status := closed.get("session_diagnostics", {}) as Dictionary
	_check(
		bool(closed.get("accepted", false))
		and StringName(closed.get("reason", &"")) == &"orderly_shutdown"
		and bool(safe_status.get("accepted", false))
		and StringName(safe_status.get("reason", &"")) == &"clean_shutdown"
		and bool(diagnostics_status.get("accepted", false))
		and StringName(diagnostics_status.get("reason", &"")) == &"orderly_shutdown"
		and successful_filesystem.write_count - successful_writes_before == 2
		and StringName(
			successful.get_safe_start_recovery_report().policy_snapshot.state
		) == &"clean_shutdown"
		and StringName(successful.get_session_diagnostics_snapshot().bridge.state) == &"clean",
		"one explicit orderly close independently publishes both clean markers"
	)
	_check(
		_unrelated_state_snapshot(successful) == successful_before,
		"orderly marker composition does not mutate gameplay, settings, network, or recovery-choice state"
	)
	safe_status["reason"] = &"caller_mutation"
	diagnostics_status["reason"] = &"caller_mutation"
	_check(
		StringName(
			successful.get_safe_start_recovery_report().orderly_shutdown_status.reason
		) == &"clean_shutdown"
		and StringName(
			successful.get_session_diagnostics_snapshot().last_status.reason
		) == &"orderly_shutdown",
		"composite marker statuses are detached from both retained owners"
	)
	var writes_after_close := successful_filesystem.write_count
	var repeated := successful.mark_orderly_shutdown()
	_check(
		bool(repeated.get("accepted", false))
		and StringName(repeated.get("reason", &"")) == &"orderly_shutdown"
		and StringName(
			(repeated.get("safe_start", {}) as Dictionary).get("reason", &"")
		) == &"already_clean"
		and StringName(
			(repeated.get("session_diagnostics", {}) as Dictionary).get("reason", &"")
		) == &"already_clean"
		and successful_filesystem.write_count == writes_after_close,
		"repeat HUD/window close ingress is idempotent across both marker owners"
	)
	successful.free()

	var safe_failure_filesystem := MemoryFilesystem.new()
	var safe_failure := _new_composed_marker_flow(
		"memory://orderly-composite-safe-failure.json",
		safe_failure_filesystem
	)
	var safe_failure_before := _unrelated_state_snapshot(safe_failure)
	var safe_failure_writes_before := safe_failure_filesystem.write_count
	safe_failure_filesystem.fail_write_number = safe_failure_writes_before + 1
	var safe_partial := safe_failure.mark_orderly_shutdown()
	_check(
		not bool(safe_partial.get("accepted", true))
		and StringName(safe_partial.get("reason", &"")) == &"orderly_shutdown_partial_failure"
		and not bool(
			(safe_partial.get("safe_start", {}) as Dictionary).get("accepted", true)
		)
		and bool(
			(safe_partial.get("session_diagnostics", {}) as Dictionary).get("accepted", false)
		)
		and safe_failure_filesystem.write_count - safe_failure_writes_before == 2
		and StringName(safe_failure.get_safe_start_recovery_report().policy_snapshot.state) == &"starting"
		and StringName(safe_failure.get_session_diagnostics_snapshot().bridge.state) == &"clean"
		and _unrelated_state_snapshot(safe_failure) == safe_failure_before,
		"a failed safe-start clean write cannot skip diagnostics or mutate unrelated state"
	)
	safe_failure.free()

	var diagnostics_failure_filesystem := MemoryFilesystem.new()
	var diagnostics_failure := _new_composed_marker_flow(
		"memory://orderly-composite-diagnostics-failure.json",
		diagnostics_failure_filesystem
	)
	var diagnostics_failure_before := _unrelated_state_snapshot(diagnostics_failure)
	var diagnostics_failure_writes_before := diagnostics_failure_filesystem.write_count
	diagnostics_failure_filesystem.fail_write_number = diagnostics_failure_writes_before + 2
	var diagnostics_partial := diagnostics_failure.mark_orderly_shutdown()
	_check(
		not bool(diagnostics_partial.get("accepted", true))
		and StringName(diagnostics_partial.get("reason", &"")) == &"orderly_shutdown_partial_failure"
		and bool(
			(diagnostics_partial.get("safe_start", {}) as Dictionary).get("accepted", false)
		)
		and not bool(
			(diagnostics_partial.get("session_diagnostics", {}) as Dictionary).get("accepted", true)
		)
		and diagnostics_failure_filesystem.write_count - diagnostics_failure_writes_before == 2
		and StringName(
			diagnostics_failure.get_safe_start_recovery_report().policy_snapshot.state
		) == &"clean_shutdown"
		and StringName(
			diagnostics_failure.get_session_diagnostics_snapshot().bridge.state
		) == &"starting"
		and _unrelated_state_snapshot(diagnostics_failure) == diagnostics_failure_before,
		"a failed diagnostics clean write still follows a successful safe-start write without unrelated mutation"
	)
	diagnostics_failure.free()


func _test_detach_reentry_and_free_remain_dirty() -> void:
	var filesystem := MemoryFilesystem.new()
	var path := "memory://orderly-composite-dirty.json"
	var store := Store.new(path, filesystem)
	var flow := MAIN_SCENE.instantiate() as GameFlow
	flow.set_physics_process(false)
	_check(
		flow.configure_runtime_settings_persistence(store, path + ".cfg"),
		"real Main dirty-marker fixture installs isolated persistence before startup"
	)
	flow.set_session_diagnostics_filesystem(filesystem)
	root.add_child(flow)
	flow.set_physics_process(false)
	await process_frame
	await process_frame
	var writes_before := filesystem.write_count
	var generation_before := store.get_generation()
	var bytes_before := (filesystem.files[path] as PackedByteArray).duplicate()
	# This focused marker test does not need to re-compose every gameplay binding;
	# suppress that unrelated deferred work while retaining the real tree hooks.
	flow.set("_initialized", false)
	root.remove_child(flow)
	await process_frame
	root.add_child(flow)
	await process_frame
	_check(
		filesystem.write_count == writes_before
		and store.get_generation() == generation_before
		and filesystem.files[path] == bytes_before
		and StringName(store.get_snapshot().safe_start_recovery.state) == &"starting"
		and StringName(store.get_snapshot().crash_recovery.state) == &"running",
		"plain Main-node detach and retained-tree reentry publish no clean marker"
	)
	flow.queue_free()
	await process_frame
	await process_frame
	var restarted_store := Store.new(path, filesystem)
	var reloaded := restarted_store.load()
	_check(
		bool(reloaded.get("accepted", false))
		and filesystem.write_count == writes_before
		and restarted_store.get_generation() == generation_before
		and filesystem.files[path] == bytes_before
		and StringName(restarted_store.get_snapshot().safe_start_recovery.state) == &"starting"
		and StringName(restarted_store.get_snapshot().crash_recovery.state) == &"running",
		"queued free leaves both dirty markers for fresh-process recovery instead of inferring shutdown"
	)


func _new_composed_marker_flow(
	path: String,
	filesystem: MemoryFilesystem,
	store: Store = null
	) -> GameFlow:
	var marker_store := store if store != null else Store.new(path, filesystem)
	var flow := GameFlowType.new()
	_check(
		flow.configure_runtime_settings_persistence(marker_store, path + ".cfg"),
		"composite fixture installs isolated persistence before startup"
	)
	flow._initialize_runtime_settings()
	flow.set_session_diagnostics_filesystem(filesystem)
	flow._initialize_session_diagnostics()
	return flow


func _unrelated_state_snapshot(flow: GameFlow) -> Dictionary:
	var diagnostics := flow.get_session_diagnostics_snapshot()
	return {
		"phase": flow.phase,
		"settings": flow.get_runtime_settings().to_dictionary(),
		"network_mode": flow.get("_network_session_mode"),
		"recovery_available": flow.get_recovery_available_snapshot(),
		"recovery_command": diagnostics.recovery_command,
		"recovery_hud": diagnostics.recovery_hud,
	}.duplicate(true)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(description)
		push_error("FAIL: " + description)
