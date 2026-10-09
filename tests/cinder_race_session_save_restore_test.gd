extends SceneTree

## Focused production round trip for the active GameFlow-owned timed race. It
## uses the real Main/session/director and the existing atomic UserDataStore,
## while keeping every byte in one injected in-memory filesystem.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const ROUTE := preload("res://assets/activities/cinder_reach_checkpoint_route.tres")
const Store := preload("res://scripts/persistence/user_data_store.gd")
const Filesystem := preload("res://scripts/persistence/user_data_filesystem.gd")
const SessionPersistence := preload(
	"res://scripts/persistence/cinder_race_session_persistence.gd"
)
const NearbyActivitySessionAdapter := preload(
	"res://scripts/persistence/nearby_sector_activity_session_adapter.gd"
)

const STORE_PATH := "memory://cinder-race-session.json"
const SLOT: StringName = &"cinder_timed_race_session"

class MemoryFilesystem extends Filesystem:
	var files: Dictionary = {}
	func file_exists(path: String) -> bool: return files.has(path)
	func directory_exists(_path: String) -> bool: return false
	func ensure_parent_directory(_path: String) -> Error: return OK
	func sync_directory(_path: String) -> Error: return OK
	func read_bytes(path: String, maximum_bytes: int) -> Dictionary:
		if not files.has(path):
			return {"error": ERR_FILE_NOT_FOUND, "bytes": PackedByteArray()}
		var bytes := (files[path] as PackedByteArray).duplicate()
		return {
			"error": OK if bytes.size() <= maximum_bytes else ERR_FILE_CORRUPT,
			"bytes": bytes if bytes.size() <= maximum_bytes else PackedByteArray(),
		}
	func write_bytes_and_flush(path: String, bytes: PackedByteArray) -> Error:
		files[path] = bytes.duplicate()
		return OK
	func remove_path(path: String) -> Error:
		if not files.has(path): return ERR_FILE_NOT_FOUND
		files.erase(path)
		return OK
	func rename_path(from_path: String, to_path: String) -> Error:
		if not files.has(from_path): return ERR_FILE_NOT_FOUND
		files[to_path] = (files[from_path] as PackedByteArray).duplicate()
		files.erase(from_path)
		return OK

class RejectingDiskFilesystem extends Filesystem:
	var reject_writes := false
	func write_bytes_and_flush(path: String, bytes: PackedByteArray) -> Error:
		return ERR_UNAVAILABLE if reject_writes else super.write_bytes_and_flush(path, bytes)
	func remove_path(path: String) -> Error:
		return ERR_UNAVAILABLE if reject_writes else super.remove_path(path)
	func rename_path(from_path: String, to_path: String) -> Error:
		return ERR_UNAVAILABLE if reject_writes else super.rename_path(from_path, to_path)

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var filesystem := MemoryFilesystem.new()
	var first_store := Store.new(STORE_PATH, filesystem) as UserDataStore
	first_store.load()
	first_store.commit(
		{"foreign": {"pilot_callsign": "MUDDS"}},
		first_store.get_generation(),
		"seed-race-session-foreign-data"
	)
	var first := await _make_game(first_store)
	if first == null:
		_finish()
		return
	first.set_physics_process(false)
	var craft := first.get_flyable_ships()[1] as HeroShip
	first.active_ship = craft
	first.set("_piloting", true)
	first.phase = GameFlow.Phase.FREE_FLIGHT
	var started := first.request_activity_start(ROUTE.activity_id)
	first.call("_physics_process", 2.0)
	first.call("_physics_process", 3.25)
	craft.global_position = ROUTE.get_checkpoint_position(0)
	first.call("_physics_process", 0.0)
	var first_session := (
		first.get_activity_integration_report().race_session
		as CinderTimedRaceSession
	)
	var penalized := first_session.apply_penalty(
		1.5, &"course_boundary", first_session.get_session_generation()
	)
	craft.global_position = ROUTE.get_checkpoint_position(1)
	first.call("_physics_process", 0.0)
	var saved := first.save_cinder_race_session()
	var before := first.get_active_activity_snapshot()
	var stored_generation := first_store.get_generation()
	_check(
		bool(started.get("accepted", false))
			and bool(penalized.get("accepted", false))
			and bool(saved.get("accepted", false))
			and before.get("state_id", &"") == &"active"
			and int(before.get("next_checkpoint_index", -1)) == 2
			and is_equal_approx(float(before.get("current_time_seconds", -1.0)), 4.75)
			and is_equal_approx(float(before.get("penalty_seconds", -1.0)), 1.5),
		"the production session saves an exact active clock, penalty, and ordered gate"
	)
	_check(
		(first_store.get_snapshot().get("cinder_timed_race_session", {}) as Dictionary)
			.get("schema_version", 0) == NearbyActivitySessionAdapter.SCHEMA_VERSION
			and ((first_store.get_snapshot().get("foreign", {}) as Dictionary)
				.get("pilot_callsign", "") == "MUDDS")
			and first.get_cinder_race_session_persistence_report()
			.get("shares_runtime_settings_store", false),
		"the race record merges into GameFlow's one existing atomic store"
	)
	await _retire_game(first)

	var second_store := Store.new(STORE_PATH, filesystem) as UserDataStore
	var second := await _make_game(second_store)
	if second == null:
		_finish()
		return
	second.set_physics_process(false)
	var restored := second.get_active_activity_snapshot()
	var report := second.get_cinder_race_session_persistence_report()
	_check(
		bool((report.get("restore_status", {}) as Dictionary).get("accepted", false))
			and restored.get("state_id", &"") == &"active"
			and int(restored.get("session_generation", -1))
				== int(before.get("session_generation", -2))
			and int(restored.get("next_checkpoint_index", -1)) == 2
			and is_equal_approx(
				float(restored.get("current_time_seconds", -1.0)),
				float(before.get("current_time_seconds", -2.0))
			)
			and float(restored.get("last_time_seconds", -2.0)) == -1.0
			and float(restored.get("best_time_seconds", -2.0)) == -1.0,
		"a fresh GameFlow restores the same active authority generations and current result"
	)

	var restored_session := (
		second.get_activity_integration_report().race_session
		as CinderTimedRaceSession
	)
	var lifecycle_counts := {"started": 0, "checkpoint": 0, "completed": 0}
	restored_session.session_started.connect(
		func(_snapshot: Dictionary) -> void:
			lifecycle_counts.started = int(lifecycle_counts.started) + 1
	)
	restored_session.checkpoint_advanced.connect(
		func(_snapshot: Dictionary) -> void:
			lifecycle_counts.checkpoint = int(lifecycle_counts.checkpoint) + 1
	)
	restored_session.session_completed.connect(
		func(_snapshot: Dictionary) -> void:
			lifecycle_counts.completed = int(lifecycle_counts.completed) + 1
	)
	var parent := second.get_parent()
	parent.remove_child(second)
	await process_frame
	var detached_before := second.get_active_activity_snapshot()
	var detached_advance := restored_session.advance_physics(
		10.0, restored_session.get_session_generation()
	)
	var detached_after := second.get_active_activity_snapshot()
	parent.add_child(second)
	await process_frame
	await process_frame
	var reentered_before_phase := second.get_active_activity_snapshot()
	var restored_craft := second.get_flyable_ships()[1] as HeroShip
	second.active_ship = restored_craft
	second.set("_piloting", true)
	second.phase = GameFlow.Phase.INTERCEPTOR_ENGAGEMENT
	second.call("_physics_process", 10.0)
	var unrelated_phase_after := second.get_active_activity_snapshot()
	_check(
		detached_before == detached_after
			and float(reentered_before_phase.get("current_time_seconds", -1.0))
			== float(unrelated_phase_after.get("current_time_seconds", -2.0))
			and int(reentered_before_phase.get("next_checkpoint_index", -1))
			== int(unrelated_phase_after.get("next_checkpoint_index", -2))
			and not bool(detached_advance.get("accepted", true))
			and detached_advance.get("reason", &"") == &"not_attached"
			and int(lifecycle_counts.started) == 0
			and int(lifecycle_counts.checkpoint) == 0
			and int(lifecycle_counts.completed) == 0,
		"detach/re-entry and unrelated piloting advance no saved time or historic signal"
	)

	second.phase = GameFlow.Phase.FREE_FLIGHT
	second.call("_physics_process", 0.25)
	for checkpoint_index in range(2, ROUTE.get_checkpoint_count()):
		restored_craft.global_position = ROUTE.get_checkpoint_position(checkpoint_index)
		second.call("_physics_process", 0.0)
	var completed := second.get_active_activity_snapshot()
	_check(
		completed.get("state_id", &"") == &"completed"
			and is_equal_approx(float(completed.get("last_time_seconds", -1.0)), 5.0)
			and is_equal_approx(float(completed.get("best_time_seconds", -1.0)), 5.0)
			and int(lifecycle_counts.started) == 0
			and int(lifecycle_counts.checkpoint) == 3
			and int(lifecycle_counts.completed) == 1,
		"the restored authority resumes once and preserves current, last, and best results"
	)

	_check(second.reset_active_activity(), "the restored terminal result resets through production")
	var replacement := second.request_activity_start(ROUTE.activity_id)
	var countdown_state := restored_session.capture_persistence_state()
	second.call("_physics_process", 2.0)
	var live_state := restored_session.capture_persistence_state()
	var adapter := SessionPersistence.new() as CinderRaceSessionPersistence
	adapter.configure(second_store, SLOT)
	var exact_live := adapter.save_state(
		live_state,
		restored_session,
		second.get_activity_director(),
		"exact-live-cinder-race-session"
	)
	var generation_before_rejection := second_store.get_generation()
	var signals_before_rejection := lifecycle_counts.duplicate(true)
	var persistence_signal_count := {"count": 0}
	var count_snapshot_signal := func(_snapshot: Dictionary) -> void:
		persistence_signal_count.count = int(persistence_signal_count.count) + 1
	restored_session.session_active.connect(count_snapshot_signal)
	restored_session.penalty_changed.connect(count_snapshot_signal)
	restored_session.session_failed.connect(count_snapshot_signal)
	restored_session.session_reset.connect(count_snapshot_signal)
	restored_session.presentation_changed.connect(count_snapshot_signal)
	restored_session.lap_advanced.connect(
		func(_snapshot: Dictionary, _lap_time_seconds: float) -> void:
			persistence_signal_count.count = int(persistence_signal_count.count) + 1
	)
	var forged_generation_mismatch := live_state.duplicate(true)
	(forged_generation_mismatch.activity_state as Dictionary).generation = (
		int(forged_generation_mismatch.session_generation) - 1
	)
	var stale := live_state.duplicate(true)
	stale.session_generation = int(stale.session_generation) - 1
	(stale.activity_state as Dictionary).generation = int(stale.session_generation)
	(stale.race_state as Dictionary).generation = int(stale.session_generation)
	var forged_forward_gate := live_state.duplicate(true)
	(forged_forward_gate.activity_state as Dictionary).next_checkpoint_index = 2
	(forged_forward_gate.race_state as Dictionary).next_checkpoint_index = 2
	var forged_higher_generation := live_state.duplicate(true)
	forged_higher_generation.session_generation = (
		int(forged_higher_generation.session_generation) + 4
	)
	(forged_higher_generation.activity_state as Dictionary).generation = int(
		forged_higher_generation.session_generation
	)
	(forged_higher_generation.race_state as Dictionary).generation = int(
		forged_higher_generation.session_generation
	)
	var forged_results := live_state.duplicate(true)
	(forged_results.race_state as Dictionary).last_time_seconds = 6.0
	(forged_results.race_state as Dictionary).best_time_seconds = 4.0
	var countdown_route_divergence := countdown_state.duplicate(true)
	(countdown_route_divergence.activity_state as Dictionary).next_checkpoint_index = 1
	var failed_checkpoint_divergence := live_state.duplicate(true)
	(failed_checkpoint_divergence.activity_state as Dictionary).state = (
		CheckpointRouteActivity.State.FAILED
	)
	(failed_checkpoint_divergence.activity_state as Dictionary).failure_reason = "forged_failure"
	(failed_checkpoint_divergence.activity_state as Dictionary).next_checkpoint_index = 1
	(failed_checkpoint_divergence.race_state as Dictionary).state = TimedCheckpointRace.State.FAILED
	(failed_checkpoint_divergence.race_state as Dictionary).failure_reason = "forged_failure"
	var failed_reason_divergence := live_state.duplicate(true)
	(failed_reason_divergence.activity_state as Dictionary).state = CheckpointRouteActivity.State.FAILED
	(failed_reason_divergence.activity_state as Dictionary).failure_reason = "route_failure"
	(failed_reason_divergence.race_state as Dictionary).state = TimedCheckpointRace.State.FAILED
	(failed_reason_divergence.race_state as Dictionary).failure_reason = "race_failure"
	var forged_states: Array[Dictionary] = [
		forged_generation_mismatch,
		stale,
		forged_forward_gate,
		forged_higher_generation,
		forged_results,
		countdown_route_divergence,
		failed_checkpoint_divergence,
		failed_reason_divergence,
	]
	var forged_results_by_case: Array[Dictionary] = []
	for case_index in forged_states.size():
		forged_results_by_case.append(adapter.save_state(
			forged_states[case_index],
			restored_session,
			second.get_activity_director(),
			"rejected-cinder-race-session-%d" % case_index
		))
	_check(
		bool(replacement.get("accepted", false)) and bool(exact_live.get("accepted", false)),
		"a legitimate reset and next generation still admit the exact live capture"
	)
	_check(
		not bool(forged_results_by_case[0].get("accepted", true))
			and forged_results_by_case[0].reason == &"race_session_payload_corrupt",
		"a mismatched route generation is rejected"
	)
	_check(
		not bool(forged_results_by_case[1].get("accepted", true))
			and forged_results_by_case[1].reason == &"race_session_not_live_capture",
		"a coherent but stale generation is rejected as non-live"
	)
	_check(
		not bool(forged_results_by_case[2].get("accepted", true))
			and forged_results_by_case[2].reason == &"race_session_not_live_capture",
		"a coherent same-generation forward gate skip is rejected as non-live"
	)
	_check(
		not bool(forged_results_by_case[3].get("accepted", true))
			and forged_results_by_case[3].reason == &"race_session_not_live_capture",
		"a coherent arbitrary higher generation is rejected as non-live"
	)
	_check(
		not bool(forged_results_by_case[4].get("accepted", true))
			and forged_results_by_case[4].reason == &"race_session_not_live_capture",
		"altered last and best results are rejected as non-live"
	)
	_check(
		not bool(forged_results_by_case[5].get("accepted", true))
			and forged_results_by_case[5].reason == &"race_session_payload_corrupt",
		"COUNTDOWN route/race checkpoint divergence is rejected"
	)
	_check(
		not bool(forged_results_by_case[6].get("accepted", true))
			and forged_results_by_case[6].reason == &"race_session_payload_corrupt",
		"FAILED route/race checkpoint divergence is rejected"
	)
	_check(
		not bool(forged_results_by_case[7].get("accepted", true))
			and forged_results_by_case[7].reason == &"race_session_payload_corrupt",
		"FAILED route/race failure-reason divergence is rejected"
	)
	_check(
		second_store.get_generation() == generation_before_rejection
			and lifecycle_counts == signals_before_rejection
			and int(persistence_signal_count.count) == 0,
		"all rejected persistence attempts write no bytes and emit no lifecycle signal"
	)
	_check(
		second_store.get_generation() > stored_generation
			and int(second.get_active_activity_snapshot().get("session_generation", 0)) == 3,
		"normal reset/restart remains the sole source of the replacement generation"
	)

	await _retire_game(second)
	await _test_race_write_recovery()
	await _test_saved_race_progress_write_recovery()
	await _test_running_race_progress_publication()
	_finish()


func _race_receipts(game: GameFlow) -> int:
	return int((game.get_activity_reward_report().authority.record.get("reward_counts", {}) as Dictionary).get("return_race_record_to_shipyard", 0))


func _complete_real_race(game: GameFlow, elapsed: float) -> bool:
	var craft := game.get_flyable_ships()[1] as HeroShip
	game.active_ship = craft
	game.set("_piloting", true)
	game.phase = GameFlow.Phase.FREE_FLIGHT
	var started := game.request_activity_start(ROUTE.activity_id)
	game.call("_physics_process", 2.0)
	game.call("_physics_process", elapsed)
	for checkpoint in ROUTE.get_checkpoint_count():
		craft.global_position = ROUTE.get_checkpoint_position(checkpoint)
		game.call("_physics_process", 0.0)
	return bool(started.get("accepted", false)) and game.get_active_activity_snapshot().get("state_id") == &"completed"


func _test_race_write_recovery() -> void:
	const path := "user://cinder-race-write-recovery.json"
	var filesystem := RejectingDiskFilesystem.new()
	var store := Store.new(path, filesystem) as UserDataStore
	var game := await _make_game(store)
	game.set_physics_process(false)
	_check(_complete_real_race(game, 0.25) and _race_receipts(game) == 1,
		"a genuine physical Main race completes and acknowledges its first paid result on real disk")
	var owner := game.cinder_race_session
	var generation := owner.get_session_generation()
	var before := owner.capture_persistence_state()
	var bytes := FileAccess.get_file_as_bytes(path)
	var events := {"count": 0}
	owner.session_reset.connect(func(_snapshot: Dictionary) -> void: events.count += 1)
	owner.presentation_changed.connect(func(_snapshot: Dictionary) -> void: events.count += 1)
	filesystem.reject_writes = true
	var rejected_reset := game.reset_active_activity()
	_check(not rejected_reset and game.cinder_race_session == owner
		and owner.capture_persistence_state() == before and FileAccess.get_file_as_bytes(path) == bytes
		and int(events.count) == 0,
		"a rejected paid race reset keeps both live authorities, results, disk bytes and unpublished lifecycle")
	await _retire_game(game)

	var resumed_filesystem := RejectingDiskFilesystem.new()
	var resumed_store := Store.new(path, resumed_filesystem) as UserDataStore
	var resumed := await _make_game(resumed_store)
	resumed.set_physics_process(false)
	var restored := resumed.cinder_race_session
	_check(restored.get_session_generation() == generation and restored.capture_persistence_state() == before
		and _race_receipts(resumed) == 1 and resumed.reset_active_activity(),
		"fresh Main retains the paid result and an ordinary accepted reset saves its exact IDLE generation")
	var idle_bytes := FileAccess.get_file_as_bytes(path)
	resumed_filesystem.reject_writes = true
	_check(_complete_real_race(resumed, 0.75) and restored.get_session_generation() == generation + 2
		and _race_receipts(resumed) == 1 and FileAccess.get_file_as_bytes(path) == idle_bytes,
		"the next actual physical route completes while every start, countdown, gate and terminal save is rejected")
	_check(not resumed.reset_active_activity()
		and not bool(resumed.select_activity_kind(GameFlow.ACTIVITY_KIND_PATROL).get("accepted", false)),
		"the unpaid live race cannot reset or switch away after the missed writes")
	resumed_filesystem.reject_writes = false
	var unpaid := restored.capture_persistence_state()
	var unpaid_reset := restored.reset_with_persistence(restored.get_session_generation(), resumed.save_cinder_race_session)
	_check(not bool(unpaid_reset.get("accepted", false)) and restored.capture_persistence_state() == unpaid
		and FileAccess.get_file_as_bytes(path) == idle_bytes and _race_receipts(resumed) == 1,
		"a genuine staged reset cannot bypass the unpaid completed race after writes recover")
	resumed.call("_retry_owed_game_flow_activity_rewards")
	var row := resumed_store.get_snapshot().cinder_timed_race_session.activities[0] as Dictionary
	_check(_race_receipts(resumed) == 2 and int(row.generation) == generation + 2
		and bool(row.reward_requested) and bool(row.reward_granted)
		and is_equal_approx(float(restored.get_presentation_snapshot().last_time_seconds), 0.75)
		and is_equal_approx(float(restored.get_presentation_snapshot().best_time_seconds), 0.25),
		"ordinary retry recovers the genuine next-generation race and pays once after writes recover (%s)" %
		resumed.get_cinder_race_session_persistence_report().last_save_status.get("reason", ""))
	if _race_receipts(resumed) != 2:
		await _retire_game(resumed)
		return
	resumed.call("_retry_owed_game_flow_activity_rewards")
	_check(_race_receipts(resumed) == 2, "repeated ordinary retry cannot duplicate the recovered race reward")
	_check(resumed.reset_active_activity(), "the recovered paid race accepts a durable ordinary reset")
	var idle_generation := restored.get_session_generation()
	var next_idle_bytes := FileAccess.get_file_as_bytes(path)
	resumed_filesystem.reject_writes = true
	var started := resumed.request_activity_start(ROUTE.activity_id)
	resumed.call("_physics_process", 2.0)
	resumed.call("_fail_active_activity", &"ship_destroyed")
	var failed := restored.capture_persistence_state()
	_check(bool(started.get("accepted", false)) and resumed.get_active_activity_snapshot().state_id == &"failed"
		and not resumed.reset_active_activity() and restored.capture_persistence_state() == failed
		and FileAccess.get_file_as_bytes(path) == next_idle_bytes,
		"a genuine failed next run retains its owner and saved IDLE while reset writes still fail")
	resumed_filesystem.reject_writes = false
	var adapter := resumed.get("_cinder_race_session_persistence") as CinderRaceSessionPersistence
	var unfenced := {"result": {}}
	var discarded := {"session": null, "director": null}
	restored.reset_with_persistence(restored.get_session_generation(), func(candidate: CinderTimedRaceSession, director: ActivityDirector) -> Dictionary:
		discarded.session = candidate
		discarded.director = director
		unfenced.result = adapter.save(candidate, director, "unfenced-race-reset")
		return {"accepted": false})
	_check(not bool(unfenced.result.get("accepted", true))
		and unfenced.result.get("reason") == &"unproven_race_session_generation"
		and not is_instance_valid(discarded.director)
		and not restored.owns_staged_persistence_reset(discarded.session, null)
		and restored.capture_persistence_state() == failed and FileAccess.get_file_as_bytes(path) == next_idle_bytes,
		"an authentic reset scratch cannot prove a generation jump without its current owner handoff")
	_check(resumed.reset_active_activity() and restored.get_session_generation() == idle_generation + 2
		and resumed.get_active_activity_snapshot().state_id == &"idle" and _race_receipts(resumed) == 2,
		"ordinary reset durably recovers the failed unsaved race using both genuine owner transitions")
	await _retire_game(resumed)
	var fresh := await _make_game(Store.new(path, RejectingDiskFilesystem.new()))
	fresh.set_physics_process(false)
	_check(fresh.cinder_race_session.get_session_generation() == idle_generation + 2
		and fresh.get_active_activity_snapshot().state_id == &"idle" and _race_receipts(fresh) == 2
		and _complete_real_race(fresh, 0.5) and _race_receipts(fresh) == 3,
		"fresh Main retains the recovered IDLE generations and the next physical race pays its new identity once")
	await _retire_game(fresh)


func _test_saved_race_progress_write_recovery() -> void:
	for saved_phase: String in ["countdown", "active", "timeout", "abort"]:
		var path := "user://cinder-race-%s-progress-recovery.json" % saved_phase
		var filesystem := RejectingDiskFilesystem.new()
		var store := Store.new(path, filesystem) as UserDataStore
		var game := await _make_game(store)
		game.set_physics_process(false)
		var prior_time := 1.0 if saved_phase == "active" else 0.25
		_check(_complete_real_race(game, prior_time) and _race_receipts(game) == 1 and game.reset_active_activity(),
			"the %s progress case begins with a real paid race and saved reset" % saved_phase)
		var craft := game.get_flyable_ships()[1] as HeroShip
		var started := game.request_activity_start(ROUTE.activity_id)
		if saved_phase == "countdown":
			game.call("_physics_process", 0.5)
		else:
			game.call("_physics_process", 2.0)
			game.call("_physics_process", 0.25)
			craft.global_position = ROUTE.get_checkpoint_position(0)
			game.call("_physics_process", 0.0)
		var saved := game.save_cinder_race_session()
		var early := game.cinder_race_session.capture_persistence_state()
		var early_bytes := FileAccess.get_file_as_bytes(path)
		_check(bool(started.get("accepted", false)) and bool(saved.get("accepted", false))
			and game.get_active_activity_snapshot().state_id == (&"countdown" if saved_phase == "countdown" else &"active"),
			"real disk accepts the genuine early %s state before the write failure" % saved_phase)
		filesystem.reject_writes = true
		if saved_phase == "active":
			await _retire_game(game)
			store = Store.new(path, filesystem)
			game = await _make_game(store)
			game.set_physics_process(false)
			_check(game.cinder_race_session.capture_persistence_state() == early,
				"fresh Main restores the accepted ACTIVE identity and physical checkpoint before later writes fail")
			craft = game.get_flyable_ships()[1] as HeroShip
			game.active_ship = craft
			game.set("_piloting", true)
			game.phase = GameFlow.Phase.FREE_FLIGHT
		var owner := game.cinder_race_session
		var generation := owner.get_session_generation()
		if saved_phase == "countdown":
			game.call("_physics_process", 1.5)
			game.call("_physics_process", 0.75)
		else:
			game.call("_physics_process", 0.5)
		if saved_phase in ["timeout", "abort"]:
			for checkpoint in range(1, 3):
				craft.global_position = ROUTE.get_checkpoint_position(checkpoint)
				game.call("_physics_process", 0.0)
			if saved_phase == "timeout":
				owner.advance_physics(120.0, generation)
			var before_reset := owner.capture_persistence_state()
			var events := {"count": 0}
			owner.session_reset.connect(func(_snapshot: Dictionary) -> void: events.count += 1)
			owner.presentation_changed.connect(func(_snapshot: Dictionary) -> void: events.count += 1)
			_check(game.get_active_activity_snapshot().state_id == (&"failed" if saved_phase == "timeout" else &"active")
				and not game.reset_active_activity() and game.cinder_race_session == owner
				and owner.capture_persistence_state() == before_reset and int(events.count) == 0
				and FileAccess.get_file_as_bytes(path) == early_bytes and _race_receipts(game) == 1,
				"rejected %s reset after unsaved physical progress preserves both owners, events and bytes" % saved_phase)
			filesystem.reject_writes = false
			_check(game.reset_active_activity() and owner.get_session_generation() == generation + 1
				and int(events.count) == 2 and game.get_active_activity_snapshot().state_id == &"idle"
				and _race_receipts(game) == 1,
				"ordinary %s reset recovers unsaved progress with one durable IDLE publication and no completion entitlement" % saved_phase)
			await _retire_game(game)
			var fresh := await _make_game(Store.new(path, RejectingDiskFilesystem.new()))
			fresh.set_physics_process(false)
			_check(fresh.get_active_activity_snapshot().state_id == &"idle"
				and fresh.cinder_race_session.get_session_generation() == generation + 1
				and _race_receipts(fresh) == 1 and _complete_real_race(fresh, 0.5) and _race_receipts(fresh) == 2,
				"fresh Main retains the recovered %s reset and pays only the next physical completion" % saved_phase)
			await _retire_game(fresh)
			continue
		for checkpoint in range(0 if saved_phase == "countdown" else 1, ROUTE.get_checkpoint_count()):
			craft.global_position = ROUTE.get_checkpoint_position(checkpoint)
			game.call("_physics_process", 0.0)
		var completed := owner.capture_persistence_state()
		_check(game.get_active_activity_snapshot().state_id == &"completed" and _race_receipts(game) == 1
			and not game.reset_active_activity() and owner.capture_persistence_state() == completed
			and FileAccess.get_file_as_bytes(path) == early_bytes,
			"physical completion after saved %s keeps pending debt and bytes unchanged while all later saves fail" % saved_phase)
		filesystem.reject_writes = false
		game.call("_retry_owed_game_flow_activity_rewards")
		var row := store.get_snapshot().cinder_timed_race_session.activities[0] as Dictionary
		_check(_race_receipts(game) == 2 and int(row.generation) == generation and bool(row.reward_granted)
			and is_equal_approx(float(owner.get_presentation_snapshot().last_time_seconds), 0.75)
			and is_equal_approx(float(owner.get_presentation_snapshot().best_time_seconds), minf(prior_time, 0.75)),
			"ordinary retry saves and acknowledges genuine same-generation %s completion once (%s)" % [saved_phase,
			game.get_cinder_race_session_persistence_report().last_save_status.get("reason", "")])
		if _race_receipts(game) != 2:
			await _retire_game(game)
			continue
		game.call("_retry_owed_game_flow_activity_rewards")
		_check(_race_receipts(game) == 2 and game.reset_active_activity()
			and owner.get_session_generation() == generation + 1 and game.get_active_activity_snapshot().state_id == &"idle",
			"recovered %s completion cannot replay and ordinary reset publishes its durable next IDLE generation" % saved_phase)
		await _retire_game(game)


func _test_running_race_progress_publication() -> void:
	for publication_case: String in ["active", "failed", "countdown_active", "countdown_failed"]:
		var from_countdown := publication_case.begins_with("countdown_")
		var terminal_kind := "failed" if publication_case.ends_with("failed") else "active"
		var path := "user://cinder-race-%s-progress-publication.json" % publication_case
		var filesystem := RejectingDiskFilesystem.new()
		var store := Store.new(path, filesystem) as UserDataStore
		var game := await _make_game(store)
		game.set_physics_process(false)
		_check(_complete_real_race(game, 0.25) and _race_receipts(game) == 1 and game.reset_active_activity(),
			"the %s publication case starts after genuine paid completion and durable reset" % publication_case)
		var owner := game.cinder_race_session
		var craft := game.get_flyable_ships()[1] as HeroShip
		var started := game.request_activity_start(ROUTE.activity_id)
		if from_countdown:
			game.call("_physics_process", 0.5)
		else:
			game.call("_physics_process", 2.0)
			game.call("_physics_process", 0.25)
			craft.global_position = ROUTE.get_checkpoint_position(0)
			game.call("_physics_process", 0.0)
		var early_saved := game.save_cinder_race_session()
		var early := owner.capture_persistence_state()
		var early_bytes := FileAccess.get_file_as_bytes(path)
		_check(bool(started.get("accepted", false)) and bool(early_saved.get("accepted", false))
			and owner.get_acknowledged_persistence_state() == early
			and int(early.race_state.next_checkpoint_index) == (0 if from_countdown else 1)
			and int(early.race_state.state) == (TimedCheckpointRace.State.COUNTDOWN if from_countdown else TimedCheckpointRace.State.ACTIVE),
			"real disk acknowledges the actual running boundary before %s write interruption" % publication_case)
		filesystem.reject_writes = true
		if from_countdown:
			game.call("_physics_process", 1.5)
			game.call("_physics_process", 0.75)
		else:
			game.call("_physics_process", 0.5)
		for checkpoint in range(0 if from_countdown else 1, 3):
			craft.global_position = ROUTE.get_checkpoint_position(checkpoint)
			game.call("_physics_process", 0.0)
		if terminal_kind == "failed":
			owner.advance_physics(120.0, owner.get_session_generation())
		var latest := owner.capture_persistence_state()
		var rejected := game.save_cinder_race_session()
		_check(not bool(rejected.get("accepted", false)) and FileAccess.get_file_as_bytes(path) == early_bytes
			and owner.get_acknowledged_persistence_state() == early and int(latest.race_state.next_checkpoint_index) == 3
			and game.get_active_activity_snapshot().state_id == StringName(terminal_kind) and _race_receipts(game) == 1,
			"rejected later %s writes keep the first acknowledged boundary while the real ordered owner progresses" % publication_case)
		filesystem.reject_writes = false
		var saved := game.save_cinder_race_session()
		_check(bool(saved.get("accepted", false)) and owner.capture_persistence_state() == latest
			and owner.get_acknowledged_persistence_state() == latest and _race_receipts(game) == 1,
			"ordinary save publishes authentic multiple-gate %s progress after writes recover (%s)" % [publication_case, saved.get("reason", "")])
		await _retire_game(game)
		if not bool(saved.get("accepted", false)):
			continue
		var fresh := await _make_game(Store.new(path, RejectingDiskFilesystem.new()))
		fresh.set_physics_process(false)
		var restored := fresh.cinder_race_session
		_check(restored.capture_persistence_state() == latest and _race_receipts(fresh) == 1,
			"fresh Main restores exact published %s gate, clock, results and generation without historic payout" % terminal_kind)
		if terminal_kind == "failed":
			fresh.call("_physics_process", 10.0)
			_check(restored.capture_persistence_state() == latest and fresh.reset_active_activity(),
				"the saved timeout stays FAILED until the player explicitly resets it")
			_check(_complete_real_race(fresh, 0.5) and _race_receipts(fresh) == 2,
				"only the next genuine race after a published failure receives its new-generation credit")
		else:
			craft = fresh.get_flyable_ships()[1] as HeroShip
			fresh.active_ship = craft
			fresh.set("_piloting", true)
			fresh.phase = GameFlow.Phase.FREE_FLIGHT
			fresh.call("_physics_process", 0.25)
			for checkpoint in range(3, ROUTE.get_checkpoint_count()):
				craft.global_position = ROUTE.get_checkpoint_position(checkpoint)
				fresh.call("_physics_process", 0.0)
			_check(fresh.get_active_activity_snapshot().state_id == &"completed"
				and is_equal_approx(float(restored.get_presentation_snapshot().last_time_seconds), 1.0)
				and _race_receipts(fresh) == 2,
				"the reloaded ACTIVE owner consumes only its remaining physical gates and pays once")
		fresh.call("_retry_owed_game_flow_activity_rewards")
		_check(_race_receipts(fresh) == 2, "repeated retry after published %s cannot invent another reward" % terminal_kind)
		await _retire_game(fresh)


func _make_game(store: UserDataStore) -> GameFlow:
	var game := MAIN_SCENE.instantiate() as GameFlow
	if game == null or not game.configure_runtime_settings_persistence(store):
		_check(false, "the isolated GameFlow accepts its one injected atomic store")
		return null
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame
	return game


func _retire_game(game: GameFlow) -> void:
	game.set("_piloting", false)
	game.queue_free()
	for _frame in 3:
		await process_frame


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
		push_error("FAIL: " + message)


func _finish() -> void:
	for failure in _failures:
		push_error(failure)
	print("CINDER_RACE_SESSION_SAVE_RESTORE_TEST_OK: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)
