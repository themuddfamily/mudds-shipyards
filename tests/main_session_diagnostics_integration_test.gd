extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const GameFlowType := preload("res://scripts/game/game_flow.gd")
const Store := preload("res://scripts/persistence/user_data_store.gd")
const Filesystem := preload("res://scripts/persistence/user_data_filesystem.gd")
const Coordinator := preload("res://scripts/diagnostics/crash_recovery_coordinator.gd")
const Record := preload("res://scripts/diagnostics/session_diagnostic_record.gd")
const CRASH_LOG_PATH := "user://diagnostics/crash-log.json"

var _failures: Array[String] = []
var _assertions := 0


class MemoryFilesystem extends Filesystem:
	var files: Dictionary = {}
	var write_count := 0
	var fail_write_number := -1
	var fail_all_writes := false
	var fail_diagnostic_stage := false
	var diagnostic_stage_attempts := 0
	var diagnostic_publications := 0

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
		# Rotated `.bak.N` history copies (fe0a916d5) are best-effort side
		# copies, not diagnostic commit attempts, so they are not counted.
		if path.get_extension().is_valid_int() and path.get_basename().ends_with(".bak"):
			if fail_all_writes:
				return ERR_FILE_CANT_WRITE
			files[path] = bytes.duplicate()
			return OK
		write_count += 1
		if path == CRASH_LOG_PATH + ".tmp":
			diagnostic_stage_attempts += 1
			if fail_diagnostic_stage:
				return ERR_FILE_CANT_WRITE
		if fail_all_writes or write_count == fail_write_number:
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
		if to_path == CRASH_LOG_PATH:
			diagnostic_publications += 1
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
		and StringName(started.last_status.reason) == &"started"
		and int(started.session_id) == 1,
		"Main composition publishes a running privacy-safe session marker"
	)
	var startup := flow._record_session_startup_completed()
	flow._advance_session_diagnostics_physics(0.25)
	flow.set("_piloting", true)
	flow._observe_session_diagnostic_runtime_mode()
	flow._advance_session_diagnostics_physics(0.5)
	flow.set("_ember_surface_journey_active", true)
	flow._observe_session_diagnostic_runtime_mode()
	flow._advance_session_diagnostics_physics(0.75)
	flow.set("_ember_surface_journey_active", false)
	flow._observe_session_diagnostic_runtime_mode()
	flow.set("_piloting", false)
	flow._observe_session_diagnostic_runtime_mode()
	var events := flow.get_session_diagnostics_snapshot().bridge.record.events as Array
	var observed_modes: Array[int] = []
	var bounded := true
	var previous_tick := -1
	var previous_elapsed := -1.0
	for event in events:
		var fields := event.fields as Dictionary
		if event.event_code == "control_source_changed":
			observed_modes.append(int(fields.input_device_code))
		bounded = bounded \
			and int(event.session_id) == int(started.session_id) \
			and int(event.physics_tick) >= previous_tick \
			and float(event.session_elapsed_physics_seconds) >= previous_elapsed \
			and not fields.has("name") and not fields.has("path") \
			and not fields.has("text") and not fields.has("token")
		previous_tick = int(event.physics_tick)
		previous_elapsed = float(event.session_elapsed_physics_seconds)
	_check(
		bool(startup.accepted)
		and events.size() == 6
		and events[0].event_code == "session_started"
		and observed_modes == [1, 2, 3, 2, 1]
		and previous_tick == 3
		and is_equal_approx(previous_elapsed, 1.5)
		and bounded,
		"real startup and station/flight/surface handoffs retain bounded caller-timed observations"
	)
	var closed := flow.mark_orderly_session_shutdown()
	var finished := flow.get_session_diagnostics_snapshot()
	var persisted_events := (
		store.get_snapshot().get("session_diagnostics", {}) as Dictionary
	).get("events", []) as Array
	_check(
		bool(closed.accepted)
		and StringName(closed.reason) == &"orderly_shutdown"
		and StringName(finished.bridge.get("state", "")) == &"clean"
		and persisted_events.size() == 7
		and persisted_events[-1].event_code == "session_ended"
		and int(persisted_events[-1].physics_tick) == 3
		and is_equal_approx(float(persisted_events[-1].session_elapsed_physics_seconds), 1.5),
		"caller-confirmed shutdown commits its final observation and clears the running marker"
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
		and int(recovery.get("session_id", 0)) == 2
		and int(restarted.get_session_diagnostics_snapshot().session_id) == 3
		and (restarted.get_session_diagnostics_snapshot().bridge.record.events as Array).size() == 8
		and restarted.phase == recovery_phase,
		"fresh startup restores the bounded ring and advances the marker-owned session identity"
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
	_test_crash_log_publication_retry()
	_test_persistent_diagnostic_write_failure()
	_test_orderly_shutdown_composition()
	await _test_detach_reentry_and_free_remain_dirty()
	_test_malformed_crash_log_is_repaired_at_startup()
	if _failures.is_empty():
		print("MAIN_SESSION_DIAGNOSTICS_INTEGRATION_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	printerr("MAIN_SESSION_DIAGNOSTICS_INTEGRATION_TEST_FAILED: ", JSON.stringify(_failures))
	quit(1)


## Exercises Main's production consumer with caller-provided physics deltas and
## an injected filesystem; this does not simulate a real operating-system crash.
func _test_crash_log_publication_retry() -> void:
	var filesystem := MemoryFilesystem.new()
	var path := "memory://main-crash-log-retry.json"
	var flow := _new_pending_crash_log_flow(path, filesystem)
	var initial := flow.get_session_diagnostics_snapshot()
	var captured := JSON.parse_string(JSON.stringify(initial.bridge.record)) as Dictionary
	_check(bool(initial.bridge.recovery_flush_pending)
		and bool(initial.bridge.coordinator.recovery_event_recorded)
		and not bool(initial.bridge.coordinator.recovery_event_published)
		and filesystem.diagnostic_stage_attempts == 1
		and not filesystem.file_exists(CRASH_LOG_PATH),
		"CRASH_LOG_RETRY_EXPECTED: startup retains failed publication (pending=%s, attempts=%d, exists=%s)"
		% [initial.bridge.recovery_flush_pending, filesystem.diagnostic_stage_attempts,
			filesystem.file_exists(CRASH_LOG_PATH)])
	var store := flow.get("_runtime_settings_user_data_store") as Store
	var foreign_before := _foreign_payload_snapshot(store.get_snapshot())
	flow._record_session_startup_completed()
	for delta in [0.0, -1.0, NAN, INF]:
		flow._advance_session_diagnostics_physics(delta)
	flow._advance_session_diagnostics_physics(0.5)
	_check(filesystem.diagnostic_stage_attempts == 1,
		"CRASH_LOG_RETRY_EXPECTED: no publication retry before one second (attempts=%d)"
		% filesystem.diagnostic_stage_attempts)
	flow._advance_session_diagnostics_physics(0.5)
	_check(filesystem.diagnostic_stage_attempts == 2
		and bool(flow.get_session_diagnostics_snapshot().bridge.recovery_flush_pending),
		"CRASH_LOG_RETRY_EXPECTED: first second retries once and retains refusal (attempts=%d, pending=%s)"
		% [filesystem.diagnostic_stage_attempts,
			flow.get_session_diagnostics_snapshot().bridge.recovery_flush_pending])
	var bridge := flow.get("_session_diagnostics_bridge") as SessionDiagnosticLifecycleBridge
	var stable := bridge.mark_stable(2, 1.0, "retry-current-stable")
	_check(bool(stable.accepted) and StringName(bridge.get_snapshot().state) == &"stable",
		"CRASH_LOG_RETRY_EXPECTED: caller stable checkpoint keeps retry eligible (status=%s)" % stable)
	# Each mode handoff successfully persists the ordinary ring. Those saves
	# must neither clear nor shorten the separate failed-publication interval.
	for tick in range(8):
		flow.set("_piloting", tick % 2 == 0)
		flow._advance_session_diagnostics_physics(0.125)
	_check(filesystem.diagnostic_stage_attempts == 3
		and filesystem.diagnostic_publications == 0
		and not filesystem.file_exists(CRASH_LOG_PATH),
		"CRASH_LOG_RETRY_EXPECTED: repeated refusal stays throttled across ring saves (attempts=%d, publications=%d, exists=%s)"
		% [filesystem.diagnostic_stage_attempts, filesystem.diagnostic_publications,
			filesystem.file_exists(CRASH_LOG_PATH)])
	filesystem.fail_diagnostic_stage = false
	flow._advance_session_diagnostics_physics(0.5)
	_check(filesystem.diagnostic_stage_attempts == 3,
		"CRASH_LOG_RETRY_EXPECTED: writable storage still waits for retry boundary (attempts=%d)"
		% filesystem.diagnostic_stage_attempts)
	flow._advance_session_diagnostics_physics(0.5)
	var recovered := flow.get_session_diagnostics_snapshot()
	# An absent log is the expected old-code RED outcome, not a JSON parse error.
	var snapshots: Array = []
	if filesystem.file_exists(CRASH_LOG_PATH):
		var parsed: Variant = JSON.parse_string(
			(filesystem.files[CRASH_LOG_PATH] as PackedByteArray).get_string_from_utf8()
		)
		if parsed is Array:
			snapshots = parsed as Array
	_check(filesystem.diagnostic_stage_attempts == 4
		and filesystem.diagnostic_publications == 1
		and not bool(recovered.bridge.recovery_flush_pending)
		and bool(recovered.bridge.coordinator.recovery_event_published)
		and snapshots == [captured],
		"CRASH_LOG_RETRY_EXPECTED: recovery publishes the exact captured snapshot once (attempts=%d, publications=%d, pending=%s, actual=%s, expected=%s)"
		% [filesystem.diagnostic_stage_attempts, filesystem.diagnostic_publications,
			recovered.bridge.recovery_flush_pending, snapshots, [captured]])
	var crashes := 0
	for event in recovered.bridge.record.events:
		if event.event_code == "crash_detected":
			crashes += 1
	_check(crashes == 1 and recovered.bridge.record.events.size() > captured.events.size(),
		"CRASH_LOG_RETRY_EXPECTED: retry preserves one crash event while live ring advances (crashes=%d, live=%d, captured=%d)"
		% [crashes, recovered.bridge.record.events.size(), captured.events.size()])
	var attempts_after_success := filesystem.diagnostic_stage_attempts
	var publications_after_success := filesystem.diagnostic_publications
	for tick in range(16):
		flow.set("_piloting", tick % 2 == 0)
		flow._advance_session_diagnostics_physics(0.125)
	_check(filesystem.diagnostic_stage_attempts == attempts_after_success
		and filesystem.diagnostic_publications == publications_after_success,
		"CRASH_LOG_RETRY_EXPECTED: success stops further publication attempts (actual=%d/%d, expected=%d/%d)"
		% [filesystem.diagnostic_stage_attempts, filesystem.diagnostic_publications,
			attempts_after_success, publications_after_success])
	var wire: Variant = JSON.parse_string(
		(filesystem.files[path] as PackedByteArray).get_string_from_utf8()
	)
	var wire_foreign := _foreign_payload_snapshot((wire as Dictionary).payload)
	_check(wire_foreign == foreign_before
		and _foreign_payload_snapshot(store.get_snapshot()) == foreign_before,
		"CRASH_LOG_RETRY_EXPECTED: complete foreign payload survives retry in memory and on wire (wire=%s, memory=%s, expected=%s)"
		% [wire_foreign, _foreign_payload_snapshot(store.get_snapshot()), foreign_before])
	flow.mark_orderly_session_shutdown()
	var writes_after_clean := filesystem.write_count
	flow._advance_session_diagnostics_physics(2.0)
	flow.free()
	_check(filesystem.write_count == writes_after_clean,
		"CRASH_LOG_RETRY_EXPECTED: successful publication adds no writes after clean or free (actual=%d, expected=%d)"
		% [filesystem.write_count, writes_after_clean])

	var clean_filesystem := MemoryFilesystem.new()
	var pending_at_clean := _new_pending_crash_log_flow(
		"memory://main-crash-log-retry-clean.json", clean_filesystem
	)
	pending_at_clean._record_session_startup_completed()
	var clean_status := pending_at_clean.mark_orderly_session_shutdown()
	var clean_snapshot := pending_at_clean.get_session_diagnostics_snapshot()
	var clean_writes := clean_filesystem.write_count
	clean_filesystem.fail_diagnostic_stage = false
	pending_at_clean._advance_session_diagnostics_physics(2.0)
	pending_at_clean.free()
	_check(bool(clean_status.accepted) and StringName(clean_snapshot.bridge.state) == &"clean"
		and bool(clean_snapshot.bridge.recovery_flush_pending)
		and clean_filesystem.write_count == clean_writes
		and clean_filesystem.diagnostic_stage_attempts == 1
		and clean_filesystem.diagnostic_publications == 0,
		"CRASH_LOG_RETRY_EXPECTED: clean session suppresses a still-pending publication through free (status=%s, writes=%d/%d, attempts=%d, publications=%d)"
		% [clean_status, clean_filesystem.write_count, clean_writes,
			clean_filesystem.diagnostic_stage_attempts, clean_filesystem.diagnostic_publications])


func _new_pending_crash_log_flow(path: String, filesystem: MemoryFilesystem) -> GameFlow:
	var prior_store := Store.new(path, filesystem)
	var loaded := prior_store.load()
	var seeded := prior_store.commit({
		"settings": {"graphics": {"quality": 2}, "accessibility": [true, false]},
		"progress": {"credits": 73, "completed": ["alpha", "beta"]},
		"foreign_extension": {"nested": [{"fraction": 0.25, "empty": {}}, null], "flag": true},
	}, prior_store.get_generation(), "retry-foreign-payload")
	var coordinator := Coordinator.new(prior_store)
	var restored := coordinator.restore()
	var begun := coordinator.begin_session(1, "retry-prior-start")
	var record := Record.new(prior_store)
	var attached := record.attach_session(1)
	var observed := record.record_lifecycle_observation(Record.LifecycleObservation.STARTUP_COMPLETED, 1, 0, 0.0)
	var persisted := record.persist("retry-prior-ring")
	var current_store := Store.new(path, filesystem)
	var reloaded := current_store.load()
	_check(bool(loaded.accepted) and bool(seeded.accepted) and bool(restored.accepted)
		and bool(begun.accepted) and bool(attached.accepted) and bool(observed.accepted)
		and bool(persisted.accepted) and bool(reloaded.accepted),
		"CRASH_LOG_RETRY_EXPECTED: fixture creates and reloads a legitimate unfinished session (loaded=%s, seeded=%s, restored=%s, begun=%s, attached=%s, observed=%s, persisted=%s, reloaded=%s)"
		% [loaded, seeded, restored, begun, attached, observed, persisted, reloaded])
	filesystem.fail_diagnostic_stage = true
	var flow := GameFlowType.new()
	flow.set("_runtime_settings_user_data_store", current_store)
	flow.set_session_diagnostics_filesystem(filesystem)
	flow._initialize_session_diagnostics()
	return flow


func _foreign_payload_snapshot(payload: Dictionary) -> Dictionary:
	var foreign := payload.duplicate(true)
	foreign.erase("crash_recovery")
	foreign.erase("session_diagnostics")
	return JSON.parse_string(JSON.stringify(foreign)) as Dictionary


func _test_persistent_diagnostic_write_failure() -> void:
	var filesystem := MemoryFilesystem.new()
	var path := "memory://diagnostic-retry.json"
	var flow := _new_composed_marker_flow(path, filesystem)
	var store := flow.get("_runtime_settings_user_data_store") as Store
	filesystem.fail_all_writes = true
	var writes_before := filesystem.write_count
	flow._record_session_startup_completed()
	_check(filesystem.write_count == writes_before + 1,
		"first diagnostic save is attempted immediately")
	for delta in [0.0, -1.0, NAN, INF]:
		flow._advance_session_diagnostics_physics(delta)
	_check(filesystem.write_count == writes_before + 1,
		"zero and invalid deltas cannot bypass the retry delay")
	for tick in range(16):
		flow.set("_piloting", tick % 2 == 0)
		flow._advance_session_diagnostics_physics(0.125)
	_check(filesystem.write_count == writes_before + 3,
		"persistent failure retries once per second despite frequent new observations")
	var retained := flow.get_session_diagnostics_snapshot().bridge.record.events as Array
	_check(bool(flow.get("_session_diagnostics_persist_pending")) and retained.size() > 2,
		"failed saves retain the latest observation ring as pending")
	filesystem.fail_all_writes = false
	flow._advance_session_diagnostics_physics(0.5)
	_check(filesystem.write_count == writes_before + 3,
		"storage recovery waits for the existing retry delay")
	flow._advance_session_diagnostics_physics(0.5)
	var reloaded := Store.new(path, filesystem)
	var loaded := reloaded.load()
	_check(filesystem.write_count == writes_before + 4
		and not bool(flow.get("_session_diagnostics_persist_pending"))
		and bool(loaded.accepted)
		and reloaded.get_snapshot().session_diagnostics.events == JSON.parse_string(JSON.stringify(retained)),
		"retry recovery commits all retained observations to reloadable storage")
	flow.set("_piloting", true)
	flow._observe_session_diagnostic_runtime_mode()
	_check(filesystem.write_count == writes_before + 5,
		"successful persistence resets the delay for the next observation")
	filesystem.fail_all_writes = true
	flow.set("_piloting", false)
	flow._observe_session_diagnostic_runtime_mode()
	filesystem.fail_all_writes = false
	var closed := flow.mark_orderly_session_shutdown()
	_check(bool(closed.accepted)
		and store.get_snapshot().session_diagnostics.events[-1].event_code == "session_ended"
		and not bool(flow.get("_session_diagnostics_persist_pending")),
		"explicit orderly shutdown flushes pending data without waiting for retry delay")
	flow.free()
	var replacement := _new_composed_marker_flow(path, filesystem, store)
	var replacement_writes := filesystem.write_count
	replacement.set("_piloting", true)
	replacement._observe_session_diagnostic_runtime_mode()
	_check(filesystem.write_count == replacement_writes + 1,
		"a replacement session starts with prompt diagnostic persistence")
	replacement.free()


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
		and successful_filesystem.write_count - successful_writes_before == 3
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
		and safe_failure_filesystem.write_count - safe_failure_writes_before == 3
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
	diagnostics_failure_filesystem.fail_write_number = diagnostics_failure_writes_before + 3
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
		and diagnostics_failure_filesystem.write_count - diagnostics_failure_writes_before == 3
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
	var production_events := (
		store.get_snapshot().get("session_diagnostics", {}) as Dictionary
	).get("events", []) as Array
	_check(
		production_events.size() == 2
		and production_events[0].event_code == "session_started"
		and production_events[1].event_code == "control_source_changed"
		and int(production_events[1].fields.input_device_code) == 1,
		"real Main startup commits completion and its initial station handoff"
	)
	var markers_before := _session_marker_namespace_snapshot(store.get_snapshot())
	# Reentry can save unrelated activity namespaces in this shared document.
	# Preserve the complete marker identities, counters, times and event ring,
	# rather than requiring every other persistence owner to remain idle.
	# This focused marker test does not need to re-compose every gameplay binding;
	# suppress that unrelated deferred work while retaining the real tree hooks.
	flow.set("_initialized", false)
	root.remove_child(flow)
	await process_frame
	var detached_store := Store.new(path, filesystem)
	var detached_reload := detached_store.load()
	_check(
		bool(detached_reload.get("accepted", false))
		and _session_marker_namespace_snapshot(store.get_snapshot()) == markers_before
		and _session_marker_namespace_snapshot(detached_store.get_snapshot()) == markers_before
		and StringName(detached_store.get_snapshot().safe_start_recovery.state) == &"starting"
		and StringName(detached_store.get_snapshot().crash_recovery.state) == &"running",
		"plain Main-node detach retains both complete dirty markers and diagnostics on disk"
	)
	root.add_child(flow)
	await process_frame
	var reentered_store := Store.new(path, filesystem)
	var reentered_reload := reentered_store.load()
	_check(
		bool(reentered_reload.get("accepted", false))
		and _session_marker_namespace_snapshot(store.get_snapshot()) == markers_before
		and _session_marker_namespace_snapshot(reentered_store.get_snapshot()) == markers_before
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
		and _session_marker_namespace_snapshot(store.get_snapshot()) == markers_before
		and _session_marker_namespace_snapshot(restarted_store.get_snapshot()) == markers_before
		and StringName(restarted_store.get_snapshot().safe_start_recovery.state) == &"starting"
		and StringName(restarted_store.get_snapshot().crash_recovery.state) == &"running",
		"queued free leaves both dirty markers for fresh-process recovery instead of inferring shutdown"
	)


func _session_marker_namespace_snapshot(payload: Dictionary) -> Dictionary:
	# Normalize the in-memory and persisted JSON number representations without
	# dropping any field or diagnostic event from the comparison.
	return JSON.parse_string(JSON.stringify({
		"safe_start_recovery": payload.get("safe_start_recovery"),
		"crash_recovery": payload.get("crash_recovery"),
		"session_diagnostics": payload.get("session_diagnostics"),
	})) as Dictionary


## A crash-log.json left empty or truncated (power loss, disk fault) was never
## repaired: every later append refused it as `log_invalid`, so no launch after
## that could record a crash or a lifecycle observation in the local log.
func _test_malformed_crash_log_is_repaired_at_startup() -> void:
	var filesystem := MemoryFilesystem.new()
	var path := "memory://malformed-crash-log.json"
	var log_path := "user://diagnostics/crash-log.json"
	var truncated := '[{"capacity": 64, "events": [{"event_co'.to_utf8_buffer()
	filesystem.files[log_path] = truncated
	var store := Store.new(path, filesystem)
	_check(bool(store.load().get("accepted", false)), "malformed-log fixture store loads empty")
	var crashed := GameFlowType.new()
	crashed.set("_runtime_settings_user_data_store", store)
	crashed.set_session_diagnostics_filesystem(filesystem)
	crashed._initialize_session_diagnostics()
	crashed.free()
	var relaunched_store := Store.new(path, filesystem)
	_check(bool(relaunched_store.load().get("accepted", false)), "malformed-log fixture relaunch loads the running marker")
	var relaunched := GameFlowType.new()
	relaunched.set("_runtime_settings_user_data_store", relaunched_store)
	relaunched.set_session_diagnostics_filesystem(filesystem)
	relaunched._initialize_session_diagnostics()
	var status := relaunched.get_session_diagnostics_snapshot()
	var written := filesystem.read_bytes(log_path, 256 * 1024)
	var parsed: Variant = JSON.parse_string(
		(written.get("bytes", PackedByteArray()) as PackedByteArray).get_string_from_utf8()
	)
	_check(
		StringName(status.last_status.get("reason", &"")) == &"recovered"
			and not bool(status.bridge.get("recovery_flush_pending", true))
			and parsed is Array and not (parsed as Array).is_empty(),
		"startup repairs a malformed crash log so the prior crash is recorded (%s)"
			% status.last_status.get("reason", "")
	)
	_check(
		filesystem.files.get(log_path + ".rejected", PackedByteArray()) == truncated,
		"the malformed crash log is quarantined intact rather than discarded"
	)
	relaunched.mark_orderly_session_shutdown()
	relaunched.free()


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
