extends SceneTree

## Focused production integration for the patrol interpretation of the existing
## Cinder route. Every travel/dwell mutation flows through real Main physics and
## one physical active_ship position sample; the test never submits to the
## ActivityDirector or PatrolActivity directly to advance route progress.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const ROUTE := preload("res://assets/activities/cinder_reach_checkpoint_route.tres")
const Store := preload("res://scripts/persistence/user_data_store.gd")
const STORE_PATH := "memory://patrol-production-settings.json"

var _assertions := 0
var _failures: Array[String] = []


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


func _initialize() -> void:
	_run()


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	var store := Store.new(STORE_PATH, MemoryFilesystem.new()) as UserDataStore
	_check(
		game.configure_runtime_settings_persistence(
			store, "memory://patrol-production-legacy.cfg"
		),
		"the production fixture injects isolated settings before Main startup"
	)
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame

	var director := game.get_activity_director()
	var hud := game.get_node_or_null(^"HUD") as GameHUD
	var combat_before := game.get_combat_authority()
	_check(
		director != null and hud != null and combat_before != null,
		"production Main resolves its director, HUD, and independent combat authority"
	)
	if director == null or hud == null or combat_before == null:
		await _clean_up(game)
		_finish()
		return

	_test_selection_and_authority_boundary(game, director, hud)
	await _test_physics_progress_reentry_and_completion(
		game, director, hud, combat_before
	)
	_test_failure_reset_and_generation_safety(game, hud)

	await _clean_up(game)
	_finish()


func _test_selection_and_authority_boundary(
	game: GameFlow,
	director: ActivityDirector,
	hud: GameHUD
	) -> void:
	var initial := game.get_activity_integration_report()
	var race := initial.get("race_session") as CinderTimedRaceSession
	var patrol := initial.get("patrol_activity") as PatrolActivity
	_check(
		int(initial.get("director_count", 0)) == 1
		and director.get_definition(ROUTE.activity_id) == ROUTE
		and initial.get("selected_activity_kind", &"")
		== GameFlow.ACTIVITY_KIND_TIMED_RACE
		and int(initial.get("attached_route_owner_count", 0)) == 1
		and bool(race.get_presentation_snapshot().get("attached", false))
		and not bool(patrol.get_presentation_snapshot().get("attached", true)),
		"Main begins with the unchanged race default and exactly one shared-route owner"
	)
	var patrol_audit := patrol.audit()
	_check(
		patrol_audit.get("route_resource_path", "") == ROUTE.resource_path
		and bool(patrol_audit.get("shares_activity_director_route", false))
		and not bool(patrol_audit.get("owns_checkpoint_geometry", true)),
		"patrol composes the exact published Cinder definition without copied geometry"
	)
	_check(
		not bool(initial.get("gameplay_authority", true))
		and not bool(initial.get("grants_rewards", true))
		and not bool(initial.get("combat_authority", true))
		and not bool(initial.get("ship_authority", true))
		and not bool(initial.get("berth_authority", true))
		and not bool(initial.get("network_authority", true))
		and not bool(patrol_audit.get("grants_rewards", true)),
		"selection and sampling add no gameplay, reward, combat, ship, berth, or network authority"
	)

	var selected := game.select_activity_kind(GameFlow.ACTIVITY_KIND_PATROL)
	var patrol_selected := game.get_activity_integration_report()
	_check(
		bool(selected.get("accepted", false))
		and selected.get("reason", &"") == &"selected"
		and patrol_selected.get("selected_activity_kind", &"")
		== GameFlow.ACTIVITY_KIND_PATROL
		and int(patrol_selected.get("attached_route_owner_count", 0)) == 1
		and not bool(race.get_presentation_snapshot().get("attached", true))
		and bool(patrol.get_presentation_snapshot().get("attached", false)),
		"the explicit pre-start selector atomically transfers the one route attachment"
	)
	var rejected := game.request_activity_start(ROUTE.activity_id)
	_check(
		not bool(rejected.get("accepted", true))
		and rejected.get("reason", &"") == &"not_in_free_flight"
		and not bool(game.get_activity_integration_report().get("selection_locked", true)),
		"selection is available before boarding but activity start remains free-flight gated"
	)
	_check(
		not bool(hud.get_activity_objective_report().get("visible", true)),
		"selecting a patrol does not invent active HUD progress"
	)


func _test_physics_progress_reentry_and_completion(
	game: GameFlow,
	director: ActivityDirector,
	hud: GameHUD,
	combat_before: LiveCombatAuthority
	) -> void:
	var route_ship := game.get_flyable_ships()[1] as HeroShip
	game.active_ship = route_ship
	game.set("_piloting", true)
	game.phase = GameFlow.Phase.FREE_FLIGHT
	var start := game.request_activity_start(ROUTE.activity_id)
	var generation := int(start.get("session_generation", -1))
	var patrol := game.get_activity_integration_report().get("patrol_activity") as PatrolActivity
	_check(
		bool(start.get("accepted", false))
		and start.get("activity_kind", &"") == GameFlow.ACTIVITY_KIND_PATROL
		and start.get("state_id", &"") == &"active"
		and start.get("phase_id", &"") == &"travel"
		and generation == 1
		and bool(game.get_activity_integration_report().get("selection_locked", false)),
		"the selected patrol starts one generation in travel and locks interpretation"
	)
	var locked := game.select_activity_kind(GameFlow.ACTIVITY_KIND_TIMED_RACE)
	_check(
		not bool(locked.get("accepted", true))
		and locked.get("reason", &"") == &"selection_locked"
		and int(game.get_activity_integration_report().get("attached_route_owner_count", 0)) == 1,
		"a live route generation cannot be handed to the inactive race adapter"
	)
	game.call("_start_default_free_flight_activity")
	_check(
		int(game.get_active_activity_snapshot().get("session_generation", -1))
		== generation,
		"re-observing free flight neither duplicates nor restarts the patrol"
	)

	game.set_physics_process(false)
	route_ship.global_position = Vector3.ZERO
	var samples_before := int(
		game.get_activity_integration_report().get("position_sample_count", -1)
	)
	game.call("_physics_process", 0.5)
	var travel := game.get_active_activity_snapshot()
	_check(
		travel.get("phase_id", &"") == &"travel"
		and is_equal_approx(float(travel.get("current_time_seconds", -1.0)), 0.5)
		and int(game.get_activity_integration_report().get("position_sample_count", -1))
		== samples_before + 1
		and "PATROL  TRAVEL G1/5" in str(hud.get_activity_objective_report().get("text", "")),
		"one production tick samples the real ship once and publishes travel state"
	)

	route_ship.global_position = ROUTE.get_checkpoint_position(0)
	var director_before_dwell := director.get_activity_snapshot(ROUTE.activity_id)
	game.call("_physics_process", 0.5)
	var dwell := game.get_active_activity_snapshot()
	_check(
		dwell.get("phase_id", &"") == &"dwell"
		and is_equal_approx(float(dwell.get("dwell_elapsed_seconds", -1.0)), 0.5)
		and is_equal_approx(float(dwell.get("dwell_remaining_seconds", -1.0)), 1.5)
		and int(director_before_dwell.get("next_checkpoint_index", -1)) == 0
		and int(director.get_activity_snapshot(ROUTE.activity_id).get("next_checkpoint_index", -1)) == 0
		and "PATROL  DWELL G1/5  HOLD 1.5s" in str(hud.get_activity_objective_report().get("text", "")),
		"arrival opens visible dwell while the director still owns uncommitted progress"
	)
	route_ship.global_position = ROUTE.get_checkpoint_position(1)
	game.call("_physics_process", 0.25)
	var interrupted := game.get_active_activity_snapshot()
	_check(
		interrupted.get("phase_id", &"") == &"dwell"
		and is_zero_approx(float(interrupted.get("dwell_elapsed_seconds", -1.0)))
		and not bool(interrupted.get("checkpoint_occupied", true)),
		"leaving the physical checkpoint resets continuous dwell without route progress"
	)
	route_ship.global_position = ROUTE.get_checkpoint_position(0)
	game.call("_physics_process", 2.0)
	var first_committed := game.get_active_activity_snapshot()
	_check(
		first_committed.get("phase_id", &"") == &"travel"
		and int(first_committed.get("completed_checkpoint_count", 0)) == 1
		and int(first_committed.get("next_checkpoint_index", 0)) == 1
		and int(director.get_activity_snapshot(ROUTE.activity_id).get("next_checkpoint_index", 0)) == 1,
		"one uninterrupted production dwell commits patrol and director exactly once"
	)

	route_ship.global_position = ROUTE.get_checkpoint_position(1)
	game.call("_physics_process", 0.4)
	var before_reentry := game.get_active_activity_snapshot()
	var integration_before := game.get_activity_integration_report()
	var patrol_id := patrol.get_instance_id()
	var director_id := director.get_instance_id()
	var samples_at_detach := int(integration_before.get("position_sample_count", -1))
	root.remove_child(game)
	await process_frame
	await process_frame
	_check(
		not bool(patrol.get_presentation_snapshot().get("attached", true))
		and patrol.get_presentation_snapshot().get("phase_id", &"") == &"dwell"
		and is_equal_approx(
			float(patrol.get_presentation_snapshot().get("dwell_elapsed_seconds", -1.0)),
			0.4
		),
		"whole-Main detach freezes the selected patrol's partial dwell and disconnects it"
	)
	root.add_child(game)
	await process_frame
	await process_frame
	var after_reentry := game.get_activity_integration_report()
	var snapshot_after := game.get_active_activity_snapshot()
	_check(
		int(after_reentry.get("patrol_activity_instance_id", 0)) == patrol_id
		and game.get_activity_director().get_instance_id() == director_id
		and int(after_reentry.get("attached_route_owner_count", 0)) == 1
		and bool(snapshot_after.get("attached", false))
		and int(snapshot_after.get("session_generation", -1)) == generation
		and snapshot_after.get("phase_id", &"") == before_reentry.get("phase_id", &"")
		and is_equal_approx(
			float(snapshot_after.get("dwell_elapsed_seconds", -1.0)),
			float(before_reentry.get("dwell_elapsed_seconds", -2.0))
		)
		and int(after_reentry.get("position_sample_count", -1)) == samples_at_detach
		and game.get_combat_authority() == combat_before,
		"re-entry restores the same patrol/director identity without time, sampling, or combat churn"
	)

	var completed_events := {"count": 0}
	patrol.patrol_completed.connect(
		func(_snapshot: Dictionary) -> void:
			completed_events["count"] = int(completed_events["count"]) + 1
	)
	game.call("_physics_process", 1.6)
	for checkpoint_index in range(2, ROUTE.get_checkpoint_count()):
		route_ship.global_position = ROUTE.get_checkpoint_position(checkpoint_index)
		game.call("_physics_process", 2.0)
	var completed := game.get_active_activity_snapshot()
	_check(
		completed.get("state_id", &"") == &"completed"
		and completed.get("phase_id", &"") == &"complete"
		and int(completed.get("completed_checkpoint_count", 0)) == ROUTE.get_checkpoint_count()
		and int(completed_events["count"]) == 1
		and "PATROL  COMPLETE 5/5" in str(hud.get_activity_objective_report().get("text", "")),
		"ordered physical dwell completes once and publishes detached completion progress"
	)
	var samples_at_finish := int(
		game.get_activity_integration_report().get("position_sample_count", -1)
	)
	game.call("_physics_process", 0.5)
	_check(
		int(completed_events["count"]) == 1
		and int(game.get_activity_integration_report().get("position_sample_count", -2))
		== samples_at_finish
		and "REWARD" not in str(hud.get_activity_objective_report().get("text", "")).to_upper(),
		"terminal ticks do not resample, re-complete, or imply a reward"
	)


func _test_failure_reset_and_generation_safety(game: GameFlow, hud: GameHUD) -> void:
	var completed_generation := int(
		game.get_active_activity_snapshot().get("session_generation", -1)
	)
	var recorded_duration := float(
		game.get_active_activity_snapshot().get("last_duration_seconds", -1.0)
	)
	_check(game.reset_active_activity(), "a completed patrol resets explicitly")
	var reset := game.get_active_activity_snapshot()
	_check(
		reset.get("state_id", &"") == &"idle"
		and int(reset.get("session_generation", -1)) == completed_generation + 1
		and is_equal_approx(float(reset.get("last_duration_seconds", -2.0)), recorded_duration)
		and not bool(hud.get_activity_objective_report().get("visible", true)),
		"reset advances generation, retains last duration, and hides inactive HUD state"
	)
	var restarted := game.request_activity_start(ROUTE.activity_id)
	var replacement_generation := int(restarted.get("session_generation", -1))
	var patrol := game.get_activity_integration_report().get("patrol_activity") as PatrolActivity
	var stale := patrol.fail(&"stale_destruction", completed_generation)
	_check(
		not bool(stale.get("accepted", true))
		and stale.get("reason", &"") == &"stale_generation"
		and replacement_generation > completed_generation
		and game.get_active_activity_snapshot().get("state_id", &"") == &"active",
		"a delayed pre-reset destruction cannot fail the replacement patrol generation"
	)
	_check(
		game.call("_fail_active_activity", &"ship_destroyed")
		and game.get_active_activity_snapshot().get("state_id", &"") == &"failed"
		and game.get_active_activity_snapshot().get("failure_reason", &"") == &"ship_destroyed"
		and "PATROL  FAILED — SHIP DESTROYED" in str(hud.get_activity_objective_report().get("text", "")),
		"current-generation ship destruction fails patrol and publishes the typed reason"
	)
	_check(game.reset_active_activity(), "destruction failure resets for a later sortie")
	var return_start := game.request_activity_start(ROUTE.activity_id)
	var return_generation := int(return_start.get("session_generation", -1))
	_check(
		return_generation > replacement_generation
		and game.call("_fail_active_activity", &"returned_to_shipyard")
		and game.get_active_activity_snapshot().get("state_id", &"") == &"aborted"
		and game.get_active_activity_snapshot().get("abort_reason", &"") == &"returned_to_shipyard"
		and "PATROL  ABORTED — RETURNED TO SHIPYARD" in str(hud.get_activity_objective_report().get("text", "")),
		"a physical return aborts only its fresh patrol generation without calling it failure"
	)
	_check(
		game.reset_active_activity()
		and game.get_active_activity_snapshot().get("state_id", &"") == &"idle",
		"return abort resets cleanly while the locked patrol selection remains stable"
	)


func _clean_up(game: GameFlow) -> void:
	paused = false
	game.set("_piloting", false)
	game.queue_free()
	await process_frame
	await process_frame


func _check(condition: bool, description: String) -> bool:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)
	return condition


func _finish() -> void:
	print("PATROL_PRODUCTION_INTEGRATION_TEST_ASSERTIONS: ", _assertions)
	if _failures.is_empty():
		print("PATROL_PRODUCTION_INTEGRATION_TEST_OK")
		quit(0)
	else:
		print("PATROL_PRODUCTION_INTEGRATION_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
