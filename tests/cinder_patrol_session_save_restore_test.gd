extends SceneTree

## Focused production round trip for the active GameFlow-owned patrol. It uses
## the real Main, PatrolActivity, ActivityDirector, and atomic UserDataStore,
## while keeping every byte in one injected in-memory filesystem.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const ROUTE := preload("res://assets/activities/cinder_reach_checkpoint_route.tres")
const Store := preload("res://scripts/persistence/user_data_store.gd")
const Filesystem := preload("res://scripts/persistence/user_data_filesystem.gd")
const SessionPersistence := preload(
	"res://scripts/persistence/cinder_patrol_session_persistence.gd"
)
const NearbyActivitySessionAdapter := preload(
	"res://scripts/persistence/nearby_sector_activity_session_adapter.gd"
)

const STORE_PATH := "memory://cinder-patrol-session.json"
const CORRUPT_STORE_PATH := "memory://corrupt-cinder-patrol-session.json"
const SLOT: StringName = &"cinder_patrol_session"


class MemoryFilesystem extends Filesystem:
	var files: Dictionary = {}

	func file_exists(path: String) -> bool:
		return files.has(path)

	func directory_exists(_path: String) -> bool:
		return false

	func ensure_parent_directory(_path: String) -> Error:
		return OK

	func sync_directory(_path: String) -> Error:
		return OK

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
		"seed-patrol-session-foreign-data"
	)
	var first := await _make_game(first_store)
	if first == null:
		_finish()
		return
	first.set_physics_process(false)
	var selected := first.select_activity_kind(GameFlow.ACTIVITY_KIND_PATROL)
	var craft := first.get_flyable_ships()[1] as HeroShip
	first.active_ship = craft
	first.set("_piloting", true)
	first.phase = GameFlow.Phase.FREE_FLIGHT
	var started := first.request_activity_start(ROUTE.activity_id)
	craft.global_position = Vector3.ZERO
	first.call("_physics_process", 0.5)
	craft.global_position = ROUTE.get_checkpoint_position(0)
	first.call("_physics_process", 0.75)
	var before := first.get_active_activity_snapshot()
	var saved := first.save_cinder_patrol_session()
	var stored_generation := first_store.get_generation()
	_check(
		bool(selected.get("accepted", false))
			and bool(started.get("accepted", false))
			and bool(saved.get("accepted", false))
			and before.get("state_id", &"") == &"active"
			and before.get("phase_id", &"") == &"dwell"
			and int(before.get("next_checkpoint_index", -1)) == 0
			and is_equal_approx(float(before.get("current_time_seconds", -1.0)), 1.25)
			and is_equal_approx(float(before.get("dwell_elapsed_seconds", -1.0)), 0.75),
		"normal GameFlow selection saves the exact active patrol clock and dwell"
	)
	var first_payload := first_store.get_snapshot()
	_check(
		(first_payload.get(String(SLOT), {}) as Dictionary)
			.get("schema_version", 0) == NearbyActivitySessionAdapter.SCHEMA_VERSION
			and ((first_payload.get("foreign", {}) as Dictionary)
				.get("pilot_callsign", "") == "MUDDS")
			and first.get_cinder_patrol_session_persistence_report()
				.get("shares_runtime_settings_store", false),
		"the patrol codec merges into GameFlow's one existing atomic store"
	)
	await _retire_game(first)

	var second_store := Store.new(STORE_PATH, filesystem) as UserDataStore
	var second := await _make_game(second_store)
	if second == null:
		_finish()
		return
	second.set_physics_process(false)
	var restored := second.get_active_activity_snapshot()
	var integration := second.get_activity_integration_report()
	var report := second.get_cinder_patrol_session_persistence_report()
	var patrol := integration.get("patrol_activity") as PatrolActivity
	_check(
		bool((report.get("restore_status", {}) as Dictionary).get("accepted", false))
			and integration.get("selected_activity_kind", &"")
				== GameFlow.ACTIVITY_KIND_PATROL
			and int(integration.get("attached_route_owner_count", 0)) == 1
			and restored.get("state_id", &"") == &"active"
			and restored.get("phase_id", &"") == &"dwell"
			and int(restored.get("session_generation", -1))
				== int(before.get("session_generation", -2))
			and is_equal_approx(
				float(restored.get("current_time_seconds", -1.0)),
				float(before.get("current_time_seconds", -2.0))
			)
			and is_equal_approx(
				float(restored.get("dwell_elapsed_seconds", -1.0)),
				float(before.get("dwell_elapsed_seconds", -2.0))
			)
			and int(restored.get("patrol_actor_instance_id", -1)) == 0,
		"a fresh GameFlow startup adopts the same active route and patrol authority"
	)

	var lifecycle_counts := {
		"started": 0,
		"checkpoint": 0,
		"completed": 0,
		"failed": 0,
		"reset": 0,
	}
	patrol.patrol_started.connect(
		func(_snapshot: Dictionary) -> void:
			lifecycle_counts.started = int(lifecycle_counts.started) + 1
	)
	patrol.checkpoint_dwell_completed.connect(
		func(_snapshot: Dictionary, _checkpoint: int) -> void:
			lifecycle_counts.checkpoint = int(lifecycle_counts.checkpoint) + 1
	)
	patrol.patrol_completed.connect(
		func(_snapshot: Dictionary) -> void:
			lifecycle_counts.completed = int(lifecycle_counts.completed) + 1
	)
	patrol.patrol_failed.connect(
		func(_snapshot: Dictionary) -> void:
			lifecycle_counts.failed = int(lifecycle_counts.failed) + 1
	)
	patrol.patrol_reset.connect(
		func(_snapshot: Dictionary) -> void:
			lifecycle_counts.reset = int(lifecycle_counts.reset) + 1
	)
	var restored_state := patrol.capture_persistence_state()
	var restore_again := patrol.restore_persistence_state(
		second.get_activity_director(), restored_state, patrol.get_generation()
	)
	_check(
		not bool(restore_again.get("accepted", true))
			and restore_again.get("reason", &"") == &"patrol_already_live"
			and patrol.capture_persistence_state() == restored_state
			and lifecycle_counts == {
				"started": 0, "checkpoint": 0, "completed": 0,
				"failed": 0, "reset": 0,
			},
		"restore is startup-only and replays no historical lifecycle signal"
	)

	var restored_craft := second.get_flyable_ships()[1] as HeroShip
	restored_craft.global_position = ROUTE.get_checkpoint_position(0)
	second.active_ship = restored_craft
	second.set("_piloting", true)
	second.phase = GameFlow.Phase.INTERCEPTOR_ENGAGEMENT
	second.call("_physics_process", 5.0)
	var unrelated_phase := second.get_active_activity_snapshot()
	second.phase = GameFlow.Phase.FREE_FLIGHT
	second.set("_piloting", false)
	second.call("_physics_process", 5.0)
	var not_piloting := second.get_active_activity_snapshot()
	second.set("_piloting", true)
	second.active_ship = null
	second.call("_physics_process", 5.0)
	var no_ship := second.get_active_activity_snapshot()
	_check(
		is_equal_approx(float(unrelated_phase.get("current_time_seconds", -1.0)), 1.25)
			and unrelated_phase == not_piloting
			and not_piloting == no_ship
			and lifecycle_counts == {
				"started": 0, "checkpoint": 0, "completed": 0,
				"failed": 0, "reset": 0,
			},
		"restored patrol time and dwell freeze outside piloted FREE_FLIGHT"
	)

	second.active_ship = restored_craft
	second.call("_physics_process", 0.25)
	var resumed := second.get_active_activity_snapshot()
	_check(
		is_equal_approx(float(resumed.get("current_time_seconds", -1.0)), 1.5)
			and is_equal_approx(float(resumed.get("dwell_elapsed_seconds", -1.0)), 1.0)
			and int(resumed.get("patrol_actor_instance_id", 0))
				== restored_craft.get_instance_id()
			and lifecycle_counts == {
				"started": 0, "checkpoint": 0, "completed": 0,
				"failed": 0, "reset": 0,
			},
		"the next valid production ship sample binds once and resumes exact dwell"
	)

	var adapter := SessionPersistence.new() as CinderPatrolSessionPersistence
	adapter.configure(second_store, SLOT)
	var exact_live := adapter.save_state(
		patrol.capture_persistence_state(),
		patrol,
		second.get_activity_director(),
		"exact-live-cinder-patrol-session"
	)
	restored_craft.global_position = ROUTE.get_checkpoint_position(1)
	second.call("_physics_process", 0.25)
	restored_craft.global_position = ROUTE.get_checkpoint_position(0)
	second.call("_physics_process", 0.25)
	var interruption_saved := second.save_cinder_patrol_session()
	var after_interruption := patrol.capture_persistence_state()
	var persisted_after_interruption := _stored_patrol_state(second_store)
	_check(
		bool(exact_live.get("accepted", false))
			and bool(interruption_saved.get("accepted", false))
			and is_equal_approx(
				float(after_interruption.get("dwell_elapsed_seconds", -1.0)), 0.25
			)
			and persisted_after_interruption == _canonical(after_interruption),
		"an occupied-to-interrupted edge preserves the next exact live dwell save"
	)

	var live_state := patrol.capture_persistence_state()
	var malformed := live_state.duplicate(true)
	malformed["forged_extra_key"] = true
	var forged_clock := live_state.duplicate(true)
	forged_clock.elapsed_seconds = float(forged_clock.elapsed_seconds) + 0.125
	forged_clock.dwell_elapsed_seconds = (
		float(forged_clock.dwell_elapsed_seconds) + 0.125
	)
	var forged_forward_checkpoint := live_state.duplicate(true)
	forged_forward_checkpoint.next_checkpoint_index = 1
	forged_forward_checkpoint.completed_checkpoint_count = 1
	forged_forward_checkpoint.dwell_checkpoint_index = PatrolActivity.ANY_CHECKPOINT
	forged_forward_checkpoint.dwell_elapsed_seconds = 0.0
	forged_forward_checkpoint.checkpoint_occupied = false
	(forged_forward_checkpoint.activity_state as Dictionary).next_checkpoint_index = 1
	var forged_generation := live_state.duplicate(true)
	forged_generation.generation = int(forged_generation.generation) + 4
	forged_generation.activity_generation = int(forged_generation.activity_generation) + 4
	(forged_generation.activity_state as Dictionary).generation = int(
		forged_generation.activity_generation
	)
	var forged_terminal := live_state.duplicate(true)
	forged_terminal.terminal_reason = "forged_failure"
	var forged_states: Array[Dictionary] = [
		malformed,
		forged_clock,
		forged_forward_checkpoint,
		forged_generation,
		forged_terminal,
	]
	var generation_before_rejection := second_store.get_generation()
	var signals_before_rejection := lifecycle_counts.duplicate(true)
	var rejected: Array[Dictionary] = []
	for case_index in forged_states.size():
		rejected.append(adapter.save_state(
			forged_states[case_index],
			patrol,
			second.get_activity_director(),
			"rejected-cinder-patrol-session-%d" % case_index
		))
	var corrupt_record := (
		second_store.get_snapshot().get(String(SLOT), {}) as Dictionary
	).duplicate(true)
	((corrupt_record.activities as Array)[0] as Dictionary).reward_granted = true
	var corrupt_validation := adapter.validate_record(
		corrupt_record, patrol, second.get_activity_director()
	)
	var wrapper_mismatch := (
		second_store.get_snapshot().get(String(SLOT), {}) as Dictionary
	).duplicate(true)
	((wrapper_mismatch.activities as Array)[0] as Dictionary).generation = (
		int(((wrapper_mismatch.activities as Array)[0] as Dictionary).generation) + 1
	)
	var wrapper_validation := adapter.validate_record(
		wrapper_mismatch, patrol, second.get_activity_director()
	)
	_check(
		not bool(rejected[0].get("accepted", true))
			and rejected[0].get("reason", &"") == &"patrol_session_payload_corrupt"
			and not bool(rejected[1].get("accepted", true))
			and rejected[1].get("reason", &"") == &"patrol_session_not_live_capture"
			and not bool(rejected[2].get("accepted", true))
			and rejected[2].get("reason", &"") == &"patrol_session_not_live_capture"
			and not bool(rejected[3].get("accepted", true))
			and rejected[3].get("reason", &"") == &"patrol_session_not_live_capture"
			and not bool(rejected[4].get("accepted", true))
			and rejected[4].get("reason", &"") == &"patrol_session_payload_corrupt"
			and not bool(corrupt_validation.get("accepted", true))
			and corrupt_validation.get("reason", &"") == &"patrol_session_payload_corrupt"
			and not bool(wrapper_validation.get("accepted", true))
			and wrapper_validation.get("reason", &"") == &"patrol_session_payload_corrupt",
		"malformed, forged, forward, generation, terminal, and record corruption are fenced"
	)
	_check(
		second_store.get_generation() == generation_before_rejection
			and lifecycle_counts == signals_before_rejection,
		"every rejected persistence ingress writes no bytes and emits no lifecycle signal"
	)

	var valid_record := (
		second_store.get_snapshot().get(String(SLOT), {}) as Dictionary
	).duplicate(true)
	await _retire_game(second)
	var corrupt_store := Store.new(CORRUPT_STORE_PATH, filesystem) as UserDataStore
	corrupt_store.load()
	var startup_corruption := valid_record.duplicate(true)
	var startup_activity := (startup_corruption.activities as Array)[0] as Dictionary
	(startup_activity.progress as Dictionary).patrol_state = {"forged": true}
	corrupt_store.commit(
		{String(SLOT): startup_corruption, "foreign": {"pilot_callsign": "MUDDS"}},
		corrupt_store.get_generation(),
		"seed-valid-envelope-corrupt-patrol-record"
	)
	var corrupt_slot_before := (
		corrupt_store.get_snapshot().get(String(SLOT), {}) as Dictionary
	).duplicate(true)
	var corrupt_game := await _make_game(corrupt_store)
	if corrupt_game != null:
		var corrupt_report := corrupt_game.get_cinder_patrol_session_persistence_report()
		var corrupt_integration := corrupt_game.get_activity_integration_report()
		_check(
			not bool((corrupt_report.get("restore_status", {}) as Dictionary)
				.get("accepted", true))
				and (corrupt_report.get("restore_status", {}) as Dictionary)
					.get("reason", &"") == &"patrol_session_payload_corrupt"
				and corrupt_integration.get("selected_activity_kind", &"")
					== GameFlow.ACTIVITY_KIND_TIMED_RACE
				and int((corrupt_integration.get("patrol_activity") as PatrolActivity)
					.get_generation()) == 0
				and corrupt_store.get_snapshot().get(String(SLOT), {})
					== corrupt_slot_before,
			"startup corruption neither adopts patrol authority nor rewrites its slot"
		)
		await _retire_game(corrupt_game)

	_check(
		second_store.get_generation() > stored_generation,
		"normal resume and exact saves advance only UserDataStore's commit generation"
	)
	_finish()


func _stored_patrol_state(store: UserDataStore) -> Dictionary:
	var record := store.get_snapshot().get(String(SLOT), {}) as Dictionary
	var activities := record.get("activities", []) as Array
	if activities.size() != 1 or not activities[0] is Dictionary:
		return {}
	var progress := (activities[0] as Dictionary).get("progress", {}) as Dictionary
	return (progress.get("patrol_state", {}) as Dictionary).duplicate(true)


func _canonical(state: Dictionary) -> Dictionary:
	var decoded: Variant = JSON.parse_string(JSON.stringify(state))
	return (decoded as Dictionary).duplicate(true) if decoded is Dictionary else {}


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
	print("CINDER_PATROL_SESSION_SAVE_RESTORE_TEST_OK: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)
