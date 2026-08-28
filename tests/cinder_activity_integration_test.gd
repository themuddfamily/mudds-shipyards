extends SceneTree

## Focused production integration for the timed Cinder activity. It uses the
## real Main, ActivityDirector, physical ship position, physics-delta seam, and
## HUD, then verifies the separate GameFlow return-incentive receipt without
## entering guided combat.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const ROUTE := preload("res://assets/activities/cinder_reach_checkpoint_route.tres")
const Store := preload("res://scripts/persistence/user_data_store.gd")
const Filesystem := preload("res://scripts/persistence/user_data_filesystem.gd")

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
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "production Main instantiates with the timed Cinder session")
	if game == null:
		_finish()
		return
	game.configure_runtime_settings_persistence(
		Store.new("memory://cinder-activity-integration.json", MemoryFilesystem.new())
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
		"Main exposes its director, HUD, and independent combat authority"
	)
	if director == null or hud == null or combat_before == null:
		await _clean_up(game)
		_finish()
		return

	_test_scene_and_authority_boundary(game, director, hud)
	await _test_countdown_pause_progress_reentry_and_completion(
		game, director, hud, combat_before
	)
	_test_failure_reset_and_generation_recovery(game, director, hud)

	await _clean_up(game)
	_finish()


func _test_scene_and_authority_boundary(
	game: GameFlow,
	director: ActivityDirector,
	hud: GameHUD
	) -> void:
	var integration := game.get_activity_integration_report()
	var session := integration.get("session") as CinderTimedRaceSession
	var audit := session.audit() if session != null else {}
	_check(
		int(integration.get("director_count", 0)) == 1
		and director.get_definition(ROUTE.activity_id) == ROUTE
		and session != null
		and audit.get("route_resource_path", "") == ROUTE.resource_path
		and not bool(audit.get("owns_checkpoint_geometry", true)),
		"one session composes the one registered shared route without checkpoint duplication"
	)
	_check(
		not bool(integration.get("gameplay_authority", true))
		and not bool(integration.get("grants_rewards", true))
		and not bool(integration.get("combat_authority", true))
		and not bool(integration.get("ship_authority", true))
		and not bool(integration.get("berth_authority", true))
		and not bool(audit.get("grants_rewards", true))
		and not bool(audit.get("network_authority", true)),
		"the timed session adapter claims no reward, combat, ship, berth, network, or general gameplay authority"
	)
	var rewards := game.get_activity_reward_report()
	var reward_authority := rewards.get("authority", {}) as Dictionary
	_check(
		bool(rewards.get("configured", false))
			and bool(reward_authority.get("reward_grant_authority", false))
			and reward_authority.get("reward_authority_id", &"") \
				== &"game_flow_reward_authority"
			and reward_authority.get("reward_store_id", &"") \
				== &"game_flow_reward_store"
			and not bool(reward_authority.get("activity_authority", true))
			and not bool(reward_authority.get("currency_authority", true)),
		"GameFlow composes one separate persisted return-incentive authority"
	)
	var rejected := game.request_activity_start(ROUTE.activity_id)
	_check(
		not bool(rejected.get("accepted", true))
		and rejected.get("reason", &"") == &"not_in_free_flight",
		"on-foot or guided play cannot start the free-flight race"
	)
	_check(
		not bool(hud.get_activity_objective_report().get("visible", true)),
		"the activity HUD line stays hidden before a race starts"
	)


func _test_countdown_pause_progress_reentry_and_completion(
	game: GameFlow,
	director: ActivityDirector,
	hud: GameHUD,
	combat_before: LiveCombatAuthority
	) -> void:
	# Stand in for the completed physical boarding/engine transition while keeping
	# the production ship as the sole sampled position source.
	var fleet := game.get_flyable_ships()
	var route_ship := fleet[1] as HeroShip
	game.active_ship = route_ship
	game.set("_piloting", true)
	game.phase = GameFlow.Phase.FREE_FLIGHT
	game.call("_start_default_free_flight_activity")
	var started := game.get_active_activity_snapshot()
	var session_generation := int(started.get("session_generation", -1))
	_check(
		started.get("state_id", &"") == &"countdown"
		and session_generation == 1
		and is_equal_approx(float(started.get("countdown_remaining_seconds", -1.0)), 2.0)
		and int(started.get("lap_count", 0)) == 1,
		"normal free flight starts one timed lap with the readable two-second countdown"
	)
	game.call("_start_default_free_flight_activity")
	_check(
		int(game.get_active_activity_snapshot().get("session_generation", -1))
		== session_generation,
		"re-observing free flight cannot duplicate or restart the running session"
	)
	var hud_started := hud.get_activity_objective_report()
	_check(
		bool(hud_started.get("visible", false))
		and hud_started.get("state_id", &"") == &"countdown"
		and "START 2.0s" in str(hud_started.get("text", ""))
		and "L1/1" in str(hud_started.get("text", "")),
		"the HUD presents countdown and lap state before accepting gates"
	)

	# A paused SceneTree does not dispatch GameFlow's physics callback, so the
	# caller-owned race clock and sampler must remain byte-for-byte unchanged.
	var before_pause := game.get_active_activity_snapshot()
	var samples_before_pause := int(
		game.get_activity_integration_report().get("position_sample_count", -1)
	)
	paused = true
	await physics_frame
	await physics_frame
	paused = false
	var after_pause := game.get_active_activity_snapshot()
	_check(
		after_pause == before_pause
		and int(game.get_activity_integration_report().get("position_sample_count", -2))
		== samples_before_pause,
		"paused physics advances neither countdown nor physical position sampling"
	)

	# Disable automatic dispatch after the pause witness, then invoke the same
	# production callback directly with exact finite physics deltas.
	game.set_physics_process(false)
	game.call("_physics_process", 1.25)
	var countdown_step := game.get_active_activity_snapshot()
	_check(
		countdown_step.get("state_id", &"") == &"countdown"
		and is_equal_approx(float(countdown_step.get("countdown_remaining_seconds", -1.0)), 0.75)
		and int(game.get_activity_integration_report().get("position_sample_count", -1))
		== samples_before_pause,
		"caller physics delta advances countdown exactly without early route sampling"
	)
	game.call("_physics_process", 0.75)
	var active := game.get_active_activity_snapshot()
	_check(
		active.get("state_id", &"") == &"active"
		and is_zero_approx(float(active.get("current_time_seconds", -1.0)))
		and int(game.get_activity_integration_report().get("position_sample_count", -1))
		== samples_before_pause + 1,
		"the countdown boundary activates and samples the real ship exactly once in that physics tick"
	)

	# A later anchor occupied first must preserve route order.
	route_ship.global_position = ROUTE.get_checkpoint_position(1)
	var before_out_of_order_samples := int(
		game.get_activity_integration_report().get("position_sample_count", -1)
	)
	game.call("_physics_process", 0.1)
	_check(
		int(game.get_active_activity_snapshot().get("next_checkpoint_index", -1)) == 0
		and int(game.get_activity_integration_report().get("position_sample_count", -1))
		== before_out_of_order_samples + 1,
		"one production tick performs one sample and rejects an out-of-order physical anchor"
	)
	route_ship.global_position = ROUTE.get_checkpoint_position(0)
	game.call("_physics_process", 0.1)
	_check(
		int(game.get_active_activity_snapshot().get("next_checkpoint_index", -1)) == 1
		and "G2/5" in str(hud.get_activity_objective_report().get("text", "")),
		"occupying gate one advances the shared director, timed session, and HUD once"
	)

	var integration_before_reentry := game.get_activity_integration_report()
	var session_id := int(integration_before_reentry.get("session_instance_id", 0))
	var director_id := director.get_instance_id()
	var samples_before_reentry := int(integration_before_reentry.get("position_sample_count", -1))
	var snapshot_before_reentry := game.get_active_activity_snapshot()
	var parent := game.get_parent()
	parent.remove_child(game)
	await process_frame
	_check(
		not bool(game.get_active_activity_snapshot().get("attached", true))
		and game.get_active_activity_snapshot().get("state_id", &"") == &"active"
		and int(game.get_active_activity_snapshot().get("next_checkpoint_index", -1)) == 1,
		"whole-Main detach disconnects translation while retaining the live lap and gate"
	)
	parent.add_child(game)
	await process_frame
	await process_frame
	var after_reentry := game.get_activity_integration_report()
	var snapshot_after_reentry := game.get_active_activity_snapshot()
	_check(
		int(after_reentry.get("session_instance_id", 0)) == session_id
		and game.get_activity_director().get_instance_id() == director_id
		and bool(snapshot_after_reentry.get("attached", false))
		and int(snapshot_after_reentry.get("session_generation", -1)) == session_generation
		and float(snapshot_after_reentry.get("current_time_seconds", -1.0))
		== float(snapshot_before_reentry.get("current_time_seconds", -2.0))
		and int(after_reentry.get("position_sample_count", -1)) == samples_before_reentry,
		"Main re-entry reuses one session/director identity without hidden time, reset, or duplicate sampling"
	)
	_check(
		bool(hud.get_activity_objective_report().get("visible", false))
		and hud.get_activity_objective_report().get("state_id", &"") == &"active"
		and "G2/5" in str(hud.get_activity_objective_report().get("text", ""))
		and game.get_combat_authority() == combat_before,
		"re-entry re-synchronises the detached activity card without replacing combat authority"
	)

	var session := after_reentry.get("session") as CinderTimedRaceSession
	var completion_witness := {"count": 0}
	session.session_completed.connect(
		func(_snapshot: Dictionary) -> void:
			completion_witness["count"] = int(completion_witness["count"]) + 1
	)
	for index in range(1, ROUTE.get_checkpoint_count()):
		route_ship.global_position = ROUTE.get_checkpoint_position(index)
		var sample_before := int(
			game.get_activity_integration_report().get("position_sample_count", -1)
		)
		game.call("_physics_process", 0.1)
		var step := game.get_active_activity_snapshot()
		var expected_next := (
			0 if index == ROUTE.get_checkpoint_count() - 1 else index + 1
		)
		_check(
			int(step.get("next_checkpoint_index", -1)) == expected_next
			and int(game.get_activity_integration_report().get("position_sample_count", -1))
			== sample_before + 1,
			"physical gate %d advances through exactly one production sample" % (index + 1)
		)
	var completed := game.get_active_activity_snapshot()
	_check(
		completed.get("state_id", &"") == &"completed"
		and int(completed.get("next_checkpoint_index", -1)) == 0
		and int(completed.get("lap_number", 0)) == 1
		and float(completed.get("last_time_seconds", -1.0)) > 0.0
		and is_equal_approx(
			float(completed.get("last_time_seconds", -1.0)),
			float(completed.get("best_time_seconds", -2.0))
		),
		"the real ship completes one ordered timed lap with its first best time"
	)
	var completed_text := str(hud.get_activity_objective_report().get("text", ""))
	_check(
		int(completion_witness["count"]) == 1
		and "FINISH" in completed_text
		and "BEST" in completed_text,
		"completion emits once and the compact HUD records finish and best times"
	)
	var reward_report := game.get_activity_reward_report()
	var reward_record := (
		(reward_report.get("authority", {}) as Dictionary).get("record", {})
		as Dictionary
	)
	var reward_receipt := reward_record.get("last_receipt", {}) as Dictionary
	_check(
		int(reward_record.get("total_receipts", 0)) == 1
			and reward_receipt.get("activity_id", "") \
				== "cinder_reach_checkpoint_route"
			and reward_receipt.get("reward_id", "") \
				== "return_race_record_to_shipyard"
			and bool(reward_receipt.get("granted", false))
			and not bool(reward_receipt.get("replay_allowed", true)),
		"the real completed lap persists one granted, non-replayable Shipyard receipt"
	)
	var store_generation_after_reward := int(
		(reward_report.get("authority", {}) as Dictionary).get(
			"store_generation", -1
		)
	)
	game.call("_on_cinder_session_completed", completed)
	var duplicate_reward_report := game.get_activity_reward_report()
	var duplicate_authority := (
		duplicate_reward_report.get("authority", {}) as Dictionary
	)
	var duplicate_record := duplicate_authority.get("record", {}) as Dictionary
	_check(
		int(duplicate_record.get("total_receipts", 0)) == 1
			and int(duplicate_authority.get("store_generation", -2)) \
				== store_generation_after_reward
			and (duplicate_reward_report.get("last_result", {}) as Dictionary).get(
				"reason", &""
			) == &"reward_already_consumed",
		"a repeated terminal callback cannot duplicate the reward receipt or store write"
	)
	var samples_at_finish := int(
		game.get_activity_integration_report().get("position_sample_count", -1)
	)
	game.call("_physics_process", 0.1)
	_check(
		int(completion_witness["count"]) == 1
		and int(game.get_activity_integration_report().get("position_sample_count", -2))
		== samples_at_finish,
		"a terminal session neither resamples nor emits duplicate completion"
	)


func _test_failure_reset_and_generation_recovery(
	game: GameFlow,
	_director: ActivityDirector,
	hud: GameHUD
	) -> void:
	var completed := game.get_active_activity_snapshot()
	var completed_generation := int(completed.get("session_generation", -1))
	var recorded_best := float(completed.get("best_time_seconds", -1.0))
	_check(game.reset_active_activity(), "a completed production race resets explicitly")
	var reset := game.get_active_activity_snapshot()
	var reset_generation := int(reset.get("session_generation", -1))
	_check(
		reset.get("state_id", &"") == &"idle"
		and reset_generation == completed_generation + 1
		and is_equal_approx(float(reset.get("best_time_seconds", -2.0)), recorded_best)
		and not bool(hud.get_activity_objective_report().get("visible", true)),
		"reset clears current progress, advances generation, preserves best, and hides the card"
	)
	var restarted := game.request_activity_start(ROUTE.activity_id)
	var destruction_generation := int(restarted.get("session_generation", -1))
	_check(
		bool(restarted.get("accepted", false))
		and destruction_generation == reset_generation + 1,
		"the same free flight starts a fresh countdown after reset"
	)
	game.call("_physics_process", 2.0)
	var integration := game.get_activity_integration_report()
	var session := integration.get("session") as CinderTimedRaceSession
	var stale := session.fail(&"stale_destruction", completed_generation)
	_check(
		not bool(stale.get("accepted", true))
		and stale.get("reason", &"") == &"stale_generation"
		and game.get_active_activity_snapshot().get("state_id", &"") == &"active",
		"a delayed pre-reset destruction cannot fail the replacement generation"
	)
	_check(
		game.call("_fail_active_activity", &"ship_destroyed")
		and game.get_active_activity_snapshot().get("state_id", &"") == &"failed"
		and game.get_active_activity_snapshot().get("failure_reason", &"") == &"ship_destroyed",
		"the production destruction seam synchronously fails the current generation"
	)
	_check(
		"FAILED — SHIP DESTROYED" in str(hud.get_activity_objective_report().get("text", "")),
		"the HUD presents destruction failure without reward language"
	)
	_check(game.reset_active_activity(), "a destruction failure resets for the next sortie")
	var return_start := game.request_activity_start(ROUTE.activity_id)
	var return_generation := int(return_start.get("session_generation", -1))
	game.call("_physics_process", 2.0)
	_check(
		return_generation > destruction_generation
		and game.call("_fail_active_activity", &"returned_to_shipyard")
		and game.get_active_activity_snapshot().get("failure_reason", &"") == &"returned_to_shipyard",
		"the production return seam fails only its fresh generation"
	)
	_check(
		game.reset_active_activity()
		and game.get_active_activity_snapshot().get("state_id", &"") == &"idle",
		"return failure resets cleanly for later free-flight activation"
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
	print("CINDER_ACTIVITY_INTEGRATION_TEST_ASSERTIONS: ", _assertions)
	if _failures.is_empty():
		print("CINDER_ACTIVITY_INTEGRATION_TEST_OK")
		quit(0)
	else:
		print("CINDER_ACTIVITY_INTEGRATION_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
