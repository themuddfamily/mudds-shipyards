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

	await _test_selection_and_authority_boundary(game, director, hud)
	await _test_physics_progress_reentry_and_completion(
		game, director, hud, combat_before
	)
	_test_failure_reset_and_generation_safety(game, hud)

	await _clean_up(game)
	await _test_queued_activity_requests()
	_finish()


func _test_selection_and_authority_boundary(
	game: GameFlow,
	director: ActivityDirector,
	hud: GameHUD
	) -> void:
	var initial := game.get_activity_integration_report()
	var race := initial.get("race_session") as CinderTimedRaceSession
	var patrol := initial.get("patrol_activity") as PatrolActivity
	var activation_center_before_detach := initial.get(
		"convoy_activation_center", Vector3.INF
	) as Vector3
	_check(
		int(initial.get("director_count", 0)) == 1
		and director.get_definition(ROUTE.activity_id) == ROUTE
		and activation_center_before_detach.is_finite()
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
	var race_generation := int(race.get_presentation_snapshot().get("session_generation", -1))
	var parent := game.get_parent()
	parent.remove_child(game)
	await process_frame
	var detached_selection := game.select_activity_kind(GameFlow.ACTIVITY_KIND_PATROL)
	var detached_start := game.request_activity_start(ROUTE.activity_id)
	var detached := game.get_activity_integration_report()
	_check(
		not bool(detached_selection.get("accepted", true))
		and detached_selection.get("reason", &"") == &"detached"
		and not bool(detached_start.get("accepted", true))
		and detached_start.get("reason", &"") == &"detached"
		and detached.get("selected_activity_kind", &"") == GameFlow.ACTIVITY_KIND_TIMED_RACE
		and not bool(detached.get("selection_locked", true))
		and int(detached.get("attached_route_owner_count", -1)) == 0
		and int(race.get_presentation_snapshot().get("session_generation", -2)) == race_generation
		and not bool(patrol.get_presentation_snapshot().get("attached", true))
		and detached.get("convoy_activation_center", Vector3.ZERO) == Vector3.INF,
		"detached activity selection and report reject world-space route-owner work without sampling Ember's stale transform"
	)
	parent.add_child(game)
	await process_frame
	await process_frame
	var reentered := game.get_activity_integration_report()
	_check(
		reentered.get("selected_activity_kind", &"") == GameFlow.ACTIVITY_KIND_TIMED_RACE
		and int(reentered.get("attached_route_owner_count", 0)) == 1
		and bool(race.get_presentation_snapshot().get("attached", false))
		and (reentered.get("convoy_activation_center", Vector3.INF) as Vector3).is_finite()
		and reentered.get("convoy_activation_center", Vector3.INF) == activation_center_before_detach,
		"re-entry restores the original timed-race owner and its current Ember activation transform"
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
		and int(start.get("patrol_actor_instance_id", 0)) == route_ship.get_instance_id()
		and start.get("patrol_actor_status_id", &"") == &"tracked"
		and bool(game.get_activity_integration_report().get("selection_locked", false)),
		"the selected patrol admits the production ship before its first tick and locks interpretation"
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
		and int(travel.get("patrol_actor_instance_id", 0)) == route_ship.get_instance_id()
		and travel.get("patrol_actor_status_id", &"") == &"tracked"
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
	var reward_record := (
		(game.get_activity_reward_report().get("authority", {}) as Dictionary).get(
			"record", {}
		) as Dictionary
	)
	var reward_receipt := reward_record.get("last_receipt", {}) as Dictionary
	_check(
		int(reward_record.get("total_receipts", 0)) == 1
			and reward_receipt.get("activity_id", "") == "cinder_relay_patrol"
			and reward_receipt.get("reward_id", "") \
				== "return_patrol_log_to_shipyard"
			and bool(reward_receipt.get("granted", false))
			and not bool(reward_receipt.get("replay_allowed", true)),
		"the completed physical patrol persists one non-replayable Shipyard log receipt"
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
		"terminal ticks do not resample, re-complete, or move reward state into the activity card"
	)

	var reset_events := {"count": 0}
	var restart_events := {"count": 0}
	var director_start_events := {"count": 0}
	patrol.patrol_reset.connect(
		func(_snapshot: Dictionary) -> void:
			reset_events["count"] = int(reset_events["count"]) + 1
	)
	patrol.patrol_started.connect(
		func(_snapshot: Dictionary) -> void:
			restart_events["count"] = int(restart_events["count"]) + 1
	)
	director.activity_started.connect(
		func(activity_id: StringName, _generation: int) -> void:
			if activity_id == ROUTE.activity_id:
				director_start_events["count"] = int(director_start_events["count"]) + 1
	)
	var terminal_patrol_id := patrol.get_instance_id()
	var terminal_generation := int(completed.get("session_generation", -1))
	root.remove_child(game)
	await process_frame
	root.add_child(game)
	await process_frame
	await process_frame
	var preserved_terminal := game.get_active_activity_snapshot()
	var preserved_report := game.get_activity_integration_report()
	_check(
		int(preserved_report.get("patrol_activity_instance_id", 0)) == terminal_patrol_id
		and int(preserved_terminal.get("session_generation", -1)) == terminal_generation
		and preserved_terminal.get("state_id", &"") == &"completed"
		and int(reset_events["count"]) == 0
		and int(restart_events["count"]) == 0
		and int(director_start_events["count"]) == 0,
		"terminal Main detach/re-entry preserves one completed generation without auto-restart"
	)
	var board_opened := hud.open_activity_board()
	var board := hud.get_activity_selection_report()
	var board_buttons := board.get("buttons", {}) as Dictionary
	var patrol_button := (
		(hud.get("_pause") as Control).find_child(
			"PatrolActivityButton", true, false
		) as Button
	)
	var samples_before_repeat := int(
		game.get_activity_integration_report().get("position_sample_count", -1)
	)
	if patrol_button != null:
		patrol_button.emit_signal("pressed")
	var repeated := game.get_active_activity_snapshot()
	var board_after_repeat := hud.get_activity_selection_report()
	_check(
		board_opened
		and "REPEAT" in str(
			(board_buttons.get(&"patrol", {}) as Dictionary).get("text", "")
		)
		and patrol_button != null
		and repeated.get("state_id", &"") == &"active"
		and repeated.get("phase_id", &"") == &"travel"
		and int(repeated.get("session_generation", -1)) > terminal_generation
		and int(repeated.get("completed_checkpoint_count", -1)) == 0
		and is_zero_approx(float(repeated.get("dwell_elapsed_seconds", -1.0)))
		and int(reset_events["count"]) == 1
		and int(restart_events["count"]) == 1
		and int(director_start_events["count"]) == 1
		and int(game.get_activity_integration_report().get("position_sample_count", -2))
		== samples_before_repeat
		and "LOCKED" in str(board_after_repeat.get("status", ""))
		and "NOT CHANGED" not in str(board_after_repeat.get("status", "")),
		"the selected Activity Board action resets then starts exactly one fresh patrol generation"
	)
	hud.set_paused(false)


func _test_failure_reset_and_generation_safety(game: GameFlow, hud: GameHUD) -> void:
	var first_repeat_generation := int(
		game.get_active_activity_snapshot().get("session_generation", -1)
	)
	_check(
		game.call("_fail_active_activity", &"ship_destroyed")
		and game.get_active_activity_snapshot().get("state_id", &"") == &"failed"
		and game.get_active_activity_snapshot().get("failure_reason", &"") == &"ship_destroyed"
		and "PATROL  FAILED — SHIP DESTROYED" in str(hud.get_activity_objective_report().get("text", "")),
		"current-generation ship destruction fails patrol and publishes the typed reason"
	)
	var failure_repeat := game.request_activity_start(ROUTE.activity_id)
	var replacement_generation := int(failure_repeat.get("session_generation", -1))
	var patrol := game.get_activity_integration_report().get("patrol_activity") as PatrolActivity
	var stale := patrol.fail(&"stale_destruction", first_repeat_generation)
	_check(
		bool(failure_repeat.get("accepted", false))
		and replacement_generation > first_repeat_generation
		and not bool(stale.get("accepted", true))
		and stale.get("reason", &"") == &"stale_generation"
		and game.get_active_activity_snapshot().get("state_id", &"") == &"active",
		"a player start repeats failure once and fences delayed destruction from the replacement generation"
	)
	var repeat_samples_before := int(
		game.get_activity_integration_report().get("position_sample_count", -1)
	)
	game.active_ship.global_position = ROUTE.get_checkpoint_position(0)
	game.call("_physics_process", 0.25)
	var repeat_dwell := game.get_active_activity_snapshot()
	_check(
		repeat_dwell.get("phase_id", &"") == &"dwell"
		and is_equal_approx(float(repeat_dwell.get("dwell_elapsed_seconds", -1.0)), 0.25)
		and int(game.get_activity_integration_report().get("position_sample_count", -2))
		== repeat_samples_before + 1,
		"one repeated-generation physics tick produces one ship sample and one fresh dwell increment"
	)
	var return_aborted := bool(
		game.call("_fail_active_activity", &"returned_to_shipyard")
	)
	var aborted := game.get_active_activity_snapshot()
	_check(
		return_aborted
		and aborted.get("state_id", &"") == &"aborted"
		and aborted.get("abort_reason", &"") == &"returned_to_shipyard"
		and "PATROL  ABORTED — RETURNED TO SHIPYARD" in str(
			hud.get_activity_objective_report().get("text", "")
		),
		"a return aborts the replacement generation without converting it to failure"
	)
	var return_start := game.request_activity_start(ROUTE.activity_id)
	var return_generation := int(return_start.get("session_generation", -1))
	_check(
		bool(return_start.get("accepted", false))
		and return_generation > replacement_generation
		and game.get_active_activity_snapshot().get("state_id", &"") == &"active",
		"a player start repeats an aborted patrol while the locked route identity remains stable"
	)
	var route_ship := game.active_ship
	var finite_position := route_ship.global_position
	route_ship.global_position = Vector3.INF
	game.call("_physics_process", 0.1)
	var nonfinite_failure := game.get_active_activity_snapshot()
	route_ship.global_position = finite_position
	_check(
		nonfinite_failure.get("state_id", &"") == &"failed"
		and nonfinite_failure.get("failure_reason", &"") == &"patrol_actor_invalid_position"
		and nonfinite_failure.get("recovery_action_id", &"") == &"reset_patrol_then_restart",
		"production non-finite ship sampling fails patrol instead of leaving it active"
	)


func _test_queued_activity_requests() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	var store := Store.new(
		"memory://queued-patrol-production-settings.json", MemoryFilesystem.new()
	) as UserDataStore
	_check(
		game.configure_runtime_settings_persistence(
			store, "memory://queued-patrol-production-legacy.cfg"
		),
		"the queued-request fixture configures an isolated real Main"
	)
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame

	var before := game.get_activity_integration_report()
	var race := before.get("race_session") as CinderTimedRaceSession
	var patrol := before.get("patrol_activity") as PatrolActivity
	var race_generation := int(race.get_presentation_snapshot().get("session_generation", -1))
	var selected := game.select_activity_kind(GameFlow.ACTIVITY_KIND_PATROL)
	var route_ship := game.get_flyable_ships()[1] as HeroShip
	game.active_ship = route_ship
	game.set("_piloting", true)
	game.phase = GameFlow.Phase.FREE_FLIGHT
	var started := game.request_activity_start(ROUTE.activity_id)
	var patrol_before_queue := patrol.get_presentation_snapshot()
	var hud := game.get_node_or_null(^"HUD") as GameHUD
	var hud_before_queue := hud.get_activity_objective_report() if hud != null else {}
	game.queue_free()
	var queued_selection := game.select_activity_kind(GameFlow.ACTIVITY_KIND_PATROL)
	var queued_start := game.request_activity_start(ROUTE.activity_id)
	var queued_failure := game.fail_active_activity(&"queued_recovery")
	var queued_reset := game.reset_active_activity()
	var after := game.get_activity_integration_report()
	_check(
		bool(selected.get("accepted", false))
		and bool(started.get("accepted", false))
		and game.is_queued_for_deletion()
		and not bool(queued_selection.get("accepted", true))
		and queued_selection.get("reason", &"") == &"detached"
		and not bool(queued_start.get("accepted", true))
		and queued_start.get("reason", &"") == &"detached"
		and not queued_failure and not queued_reset
		and after.get("selected_activity_kind", &"") == GameFlow.ACTIVITY_KIND_PATROL
		and bool(after.get("selection_locked", false))
		and int(after.get("attached_route_owner_count", -1))
		== int(before.get("attached_route_owner_count", -2))
		and int(race.get_presentation_snapshot().get("session_generation", -2)) == race_generation
		and patrol.get_presentation_snapshot() == patrol_before_queue
		and (hud.get_activity_objective_report() if hud != null else {}) == hud_before_queue,
		"queued Main rejects selection, start, failure, and reset before route or HUD mutation"
	)
	await process_frame
	await process_frame
	_check(
		not is_instance_valid(game),
		"the queued-request fixture frees normally after both ingress guards reject"
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
