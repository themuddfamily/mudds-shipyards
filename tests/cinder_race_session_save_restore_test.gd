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
	var live_state := restored_session.capture_persistence_state()
	var adapter := SessionPersistence.new() as CinderRaceSessionPersistence
	adapter.configure(second_store, SLOT)
	var forged := live_state.duplicate(true)
	(forged.activity_state as Dictionary).generation = int(forged.session_generation) - 1
	var generation_before_rejection := second_store.get_generation()
	var forged_result := adapter.save_state(
		forged,
		restored_session,
		second.get_activity_director(),
		"forged-cinder-race-session"
	)
	var stale := live_state.duplicate(true)
	stale.session_generation = int(stale.session_generation) - 1
	(stale.activity_state as Dictionary).generation = int(stale.session_generation)
	(stale.race_state as Dictionary).generation = int(stale.session_generation)
	var stale_result := adapter.save_state(
		stale,
		restored_session,
		second.get_activity_director(),
		"stale-cinder-race-session"
	)
	_check(
		bool(replacement.get("accepted", false))
			and not bool(forged_result.get("accepted", true))
			and forged_result.get("reason", &"") == &"race_session_payload_corrupt"
			and not bool(stale_result.get("accepted", true))
			and stale_result.get("reason", &"") == &"stale_race_session"
			and second_store.get_generation() == generation_before_rejection,
		"forged and stale snapshots are rejected without changing store authority"
	)
	_check(
		second_store.get_generation() > stored_generation
			and int(second.get_active_activity_snapshot().get("session_generation", 0)) == 3,
		"normal reset/restart remains the sole source of the replacement generation"
	)

	await _retire_game(second)
	_finish()


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
