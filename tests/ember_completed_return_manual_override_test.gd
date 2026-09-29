extends SceneTree
## test-matrix-timeout-seconds: 1200

## Touching the flight controls during a completed Ember expedition's return
## cruise hands the pilot the craft; releasing them resumes the flight home.
##
## The abandoned visit's return already resumes this way. The completed one did
## not: the first manual input on the cruise home retired the return approach
## for good, and with it the station-return contract the survey had earned.
##
## Orbit and corridor staging is ember_abandon_return_manual_override_test's.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const Store := preload("res://scripts/persistence/user_data_store.gd")
const ISOLATED_STORE_PATH := "memory://ember-completed-return-override.json"
const CRAFT_ID: StringName = &"arrow_provisional"
const FRAME_BUDGET_GRACE := 30
const ORBIT_STANDOFF_M := 500.0
const ORBIT_HOLD_SPEED_MPS := 8.0
const LOCOMOTION_TICK_BUDGET := 240
const DEPARTURE_TICK_BUDGET := 240
const ORBIT_STAGE_TICK_BUDGET := 420
const HANDOFF_TICK_BUDGET := 600
const LANDING_TICK_BUDGET := 1500
const DISEMBARK_TICK_BUDGET := 600
const REBOARD_TICK_BUDGET := 600
const ABANDON_TICK_BUDGET := 2400
const FLIGHT_CONTROL_ACTIONS: Array[StringName] = [
	&"move_forward", &"move_back", &"move_left", &"move_right",
	&"pitch_up", &"pitch_down", &"roll_left", &"roll_right",
	&"sprint_boost", &"brake", &"hover", &"fire", &"barrel_roll",
	&"landing_assist",
]
const ON_FOOT_ACTIONS: Array[StringName] = [
	&"interact", &"move_forward", &"move_back", &"move_left", &"move_right",
	&"sprint_boost", &"jump",
]

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


## Staging for the survey: after the real disembark and outbound route walk,
## the pilot is placed once inside each authored relay-survey checkpoint radius
## (the survey's checkpoints sit 170 m and 400 m out, minutes of walking) and
## then back where the outbound walk ended. Checkpoint admission, the reward
## commit, the return walk, re-board, the Host's takeoff, ascent and orbit
## return, the return cruise and the manual override are all production.
const OUTBOUND_ROUTE_LEGS: Array = [
	["x", -9.0, false, &"move_back", 90],
	["z", 8.0, true, &"move_right", 120],
	["x", 17.5, true, &"move_forward", 150],
	["z", 0.5, false, &"move_left", 120],
	["x", 41.5, true, &"move_forward", 150],
]
const RETURN_ROUTE_LEGS: Array = [
	["x", 18.5, false, &"move_back", 150],
	["z", 8.0, true, &"move_right", 120],
	["x", -9.0, false, &"move_back", 150],
	["z", 0.5, false, &"move_left", 120],
]
const RELAY_ANCHOR := Vector3(180.0, 120009.0, -44.0)
const RETURN_ANCHOR := Vector3(540.0, 120030.0, -210.0)
const CHECKPOINT_TICK_BUDGET := 240
const ORBIT_RETURN_TICK_BUDGET := 6000


var _failures: Array[String] = []
var _assertions := 0
var _store: UserDataStore


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	_store = Store.new(ISOLATED_STORE_PATH, MemoryFilesystem.new())
	game.configure_runtime_settings_persistence(
		_store, "memory://ember-completed-return-override-legacy.cfg"
	)
	root.add_child(game)
	for _boot_frame in 240:
		await process_frame
		await physics_frame
		if bool(game.get("_initialized")):
			break
	game.set("_initialized", true)
	game.canopy_motion_time = 0.04
	game.boarding_motion_time = 0.08
	game.disembarking_motion_time = 0.06
	var player := game.player as PlayerController
	var host := game.ember_surface_loop_host as EmberSurfaceLoopHost
	var berth := game.ember_surface_berth as EmberSurfaceBerth
	var cruise := game.planetary_cruise_binding as PlanetaryCruiseProductionBinding
	await _wait_until(func() -> bool: return game.get_flyable_ships().size() >= 9, 4.0)
	var craft: HeroShip = null
	for candidate: HeroShip in game.get_flyable_ships():
		if candidate.get_ship_id() == CRAFT_ID:
			craft = candidate
	_check(craft != null and host != null and berth != null and cruise != null,
		"production Main composes the craft, Ember host, berth and cruise binding")
	if craft == null or host == null or berth == null or cruise == null:
		await _tear_down(game)
		_finish()
		return
	game.start_shift()
	await process_frame
	game.set("_guided_return_ready_for_completion", false)
	game.set("_guided_activity_complete", true)
	game.phase = GameFlow.Phase.COMPLETE
	await _await_free_on_foot(game, player)
	_check(await _walk_and_board(game, player, craft), "the pilot boards at the yard")
	_check(await _launch(game), "the craft launches into free flight")
	game.set("_active_activity_id", &"")
	var begun := game.call(&"_begin_player_ember_surface_journey", 1) as Dictionary
	_check(bool(begun.get("accepted", false)),
		"the player's Ember expedition is admitted (%s)" % begun.get("reason", &"?"))
	var staged: bool = bool(begun.get("accepted", false)) \
		and await _stage_orbital_approach(game, craft, cruise) \
		and await _stage_corridor_entry(game, craft, host) \
		and await _advance_to_phase(host, EmberSurfaceLoopHost.Phase.LANDED, LANDING_TICK_BUDGET) \
		and await _advance_to_phase(host, EmberSurfaceLoopHost.Phase.SURFACE_OUTBOUND, DISEMBARK_TICK_BUDGET)
	_check(staged, "the craft lands at the caldera and the pilot disembarks")
	if not staged:
		await _tear_down(game)
		_finish()
		return
	var completed := await _complete_survey(game, player, host, craft)
	_check(completed, "the pilot completes the relay survey and re-boards (host phase %d)" % host.get_phase())
	if not completed:
		await _tear_down(game)
		_finish()
		return
	var receipts_after_survey := _saved_receipts()
	_check(receipts_after_survey == 1,
		"the completed survey saves exactly one reward receipt (%d)" % receipts_after_survey)
	var shown := game.hud.get("_activity_reward_summary") as Dictionary
	_check(int(shown.get("total_receipts", -1)) == receipts_after_survey
			and str(shown.get("last_reward_label", "")) == "Survey data accepted",
		"the HUD reward summary shows the saved survey receipt (%s)" % shown)
	var cruising := await _wait_for(
		func() -> bool: return _return_cruising(game, craft), ORBIT_RETURN_TICK_BUDGET)
	_check(cruising, "the Host's ascent hands the craft to the cruise home (host %d, last %s)" % [
		host.get_phase(),
		(game.get("_last_mudds_return_approach_result") as Dictionary).get("reason", &"?")])
	if not cruising:
		await _tear_down(game)
		_finish()
		return
	for _cruise_tick in 60:
		await physics_frame
		await process_frame
	var home: Vector3 = game.world.get_ship_spawn().origin
	var distance_before := craft.global_position.distance_to(home)
	Input.action_press(&"move_forward")
	var released_to_pilot := await _wait_for(
		func() -> bool: return not bool(cruise.get_snapshot().get("engagement_requested", true)), 30)
	for _held in 20:
		await physics_frame
		await process_frame
	Input.action_release(&"move_forward")
	_check(released_to_pilot, "held flight controls hand the craft back to the pilot")
	var resumed := await _wait_for(func() -> bool: return _return_cruising(game, craft), 1800)
	var journey: Object = game.get("_planetary_journey")
	print("OVERRIDE distance_before=%.0f m distance_after=%.0f m resumed=%s last=%s abandon_active=%s stranded=%s" % [
		distance_before, craft.global_position.distance_to(home), resumed,
		(game.get("_last_mudds_return_approach_result") as Dictionary).get("reason", &"?"),
		journey.get("_ember_abandon_return_active"),
		journey.call(&"stranded_return_available")])
	_check(resumed, "releasing the controls resumes the completed expedition's cruise home")
	_check(not bool(journey.get("_ember_abandon_return_active"))
			and not bool(journey.call(&"stranded_return_available")),
		"the resumed return is still the completed expedition's, not an abandoned one")
	_check(_saved_receipts() == receipts_after_survey,
		"the manual override neither loses nor repeats the saved reward")
	await _tear_down(game)
	_finish()


func _saved_receipts() -> int:
	var rewards := _store.get_snapshot().get("game_flow_reward_store", {}) as Dictionary
	return int(rewards.get("total_receipts", 0))


func _survey_index(game: GameFlow) -> int:
	return int(game.activity_director.get_activity_snapshot(&"ember_beacon_survey").get(
		"next_checkpoint_index", -1))


func _complete_survey(
		game: GameFlow,
		player: PlayerController,
		host: EmberSurfaceLoopHost,
		craft: HeroShip,
	) -> bool:
	var region := _landing_region(game)
	if not is_instance_valid(region):
		return false
	for leg: Array in OUTBOUND_ROUTE_LEGS:
		if not await _walk_leg(player, region, leg):
			print("SURVEY outbound leg failed %s at %s" % [leg, region.to_local(player.global_position)])
			return false
	if not await _advance_to_phase(host, EmberSurfaceLoopHost.Phase.ON_FOOT, 180):
		print("SURVEY host did not reach ON_FOOT: %d" % host.get_phase())
		return false
	var staging := player.global_transform
	var loaded := game.ember_streaming_bootstrap.get_loaded_instance() as Node3D
	var up := region.global_basis.y.normalized()
	for index in 2:
		var anchor := RELAY_ANCHOR if index == 0 else RETURN_ANCHOR
		var target := loaded.global_transform * anchor
		player.teleport_to(Transform3D(player.global_basis, target + up * 1.5))
		var reached := await _wait_for(
			func() -> bool: return _survey_index(game) >= index + 1, CHECKPOINT_TICK_BUDGET)
		print("SURVEY checkpoint %d reached=%s index=%d player_local=%s" % [
			index, reached, _survey_index(game), loaded.to_local(player.global_position)])
		if not reached:
			return false
	for _settle in 12:
		await physics_frame
		await process_frame
	player.teleport_to(staging)
	for _settle in 6:
		await physics_frame
		await process_frame
	for leg: Array in RETURN_ROUTE_LEGS:
		if not await _walk_leg(player, region, leg):
			print("SURVEY return leg failed %s at %s" % [leg, region.to_local(player.global_position)])
			return false
	var area := craft.get_node_or_null(^"ShipBoardingArea") as ShipBoardingArea
	if not await _walk_until(
		&"move_forward",
		func() -> bool: return area in player.get_nearby_interactables(),
		120
	):
		print("SURVEY boarding area not reached")
		return false
	for _press in 12:
		await _press_live_action(&"interact", 1)
		for _settle in 6:
			await physics_frame
			await process_frame
		if host.get_phase() >= EmberSurfaceLoopHost.Phase.BOARDING \
				and host.get_phase() != EmberSurfaceLoopHost.Phase.FAILED:
			break
	return await _wait_for(
		func() -> bool: return player.is_seated() \
			and host.get_phase() >= EmberSurfaceLoopHost.Phase.REBOARDED \
			and host.get_phase() != EmberSurfaceLoopHost.Phase.FAILED,
		REBOARD_TICK_BUDGET)


func _walk_leg(player: PlayerController, region: Node3D, leg: Array) -> bool:
	var axis := str(leg[0])
	var bound := float(leg[1])
	var greater := bool(leg[2])
	var predicate := func() -> bool:
		var local := region.to_local(player.global_position)
		var value := local.x if axis == "x" else local.z
		return value >= bound if greater else value <= bound
	return await _walk_until(StringName(leg[3]), predicate, int(leg[4]))


func _landing_region(game: GameFlow) -> Node3D:
	var loaded := game.ember_streaming_bootstrap.get_loaded_instance()
	if not is_instance_valid(loaded):
		return null
	return loaded.get_node_or_null(^"LandingRegion") as Node3D


func _return_cruising(game: GameFlow, craft: HeroShip) -> bool:
	var report := craft.get_planetary_cruise_attachment_report()
	return bool(game.get("_mudds_return_approach_active")) \
		and bool(game.planetary_cruise_binding.get_snapshot().get("engagement_requested", false)) \
		and StringName(report.get("state", &"inactive")) in [
			HeroShip.PLANETARY_CRUISE_STATE_ACCELERATING,
			HeroShip.PLANETARY_CRUISE_STATE_CRUISING,
		]


func _walk_and_board(game: GameFlow, player: PlayerController, craft: HeroShip) -> bool:
	var boarding := craft.get_boarding_position()
	var up := craft.global_basis.y.normalized()
	var approach := craft.global_basis.x.normalized()
	player.teleport_to(Transform3D(
		Basis.looking_at(-approach, Vector3.UP),
		boarding + up * 0.05 + approach * 6.0
	))
	player.set_control_enabled(true)
	for _stage_tick in 4:
		await physics_frame
		await process_frame
	var arrived := await _walk_until(
		&"move_forward",
		func() -> bool: return game.boarding_candidate == craft,
		LOCOMOTION_TICK_BUDGET
	)
	if not arrived:
		player.teleport_to(Transform3D(player.global_basis, boarding + up * 0.05))
		arrived = await _wait_until(
			func() -> bool: return game.boarding_candidate == craft, 2.0
		)
	if not arrived:
		return false
	for _attempt in 3:
		await _press_live_action(&"interact", 1)
		if await _wait_until(
			func() -> bool: return game.phase == GameFlow.Phase.START_ENGINES, 2.0
		):
			break
	return game.phase == GameFlow.Phase.START_ENGINES


func _launch(game: GameFlow) -> bool:
	_release_all_actions()
	Input.action_press(&"hover")
	Input.action_press(&"move_forward")
	var ticks := 0
	while game.phase != GameFlow.Phase.FREE_FLIGHT and ticks < DEPARTURE_TICK_BUDGET:
		await physics_frame
		await process_frame
		ticks += 1
	var airborne := game.phase == GameFlow.Phase.FREE_FLIGHT
	for _leg_tick in 24:
		await physics_frame
		await process_frame
	Input.action_release(&"hover")
	Input.action_release(&"move_forward")
	for _settle_tick in 4:
		await physics_frame
		await process_frame
	return airborne


func _stage_orbital_approach(
		game: GameFlow,
		craft: HeroShip,
		cruise: PlanetaryCruiseProductionBinding,
	) -> bool:
	var frame := game.ember_streaming_bootstrap.get_coordinate_frame_for_session()
	var canonical := cruise.get_snapshot().get(
		"canonical_destination_orbital", {}
	) as Dictionary
	for _index in ORBIT_STAGE_TICK_BUDGET:
		var decoded := frame.orbital_to_world_streaming_position(
			canonical, frame.get_generation()
		)
		var navigation := decoded.get("position", Vector3.INF) as Vector3
		if navigation.is_finite():
			craft.global_position = navigation + Vector3.BACK * ORBIT_STANDOFF_M
			craft.global_basis = Basis.IDENTITY
			craft.velocity = (
				navigation - craft.global_position
			).normalized() * ORBIT_HOLD_SPEED_MPS
		await physics_frame
		var controller := (cruise.get_snapshot().get("controller", {}) as Dictionary)
		var approach := controller.get("final_approach", {}) as Dictionary
		if StringName(approach.get("state_id", &"")) == &"final_approach":
			return true
	return false


func _stage_corridor_entry(
		game: GameFlow,
		craft: HeroShip,
		host: EmberSurfaceLoopHost,
	) -> bool:
	var loaded := game.ember_streaming_bootstrap.get_loaded_instance()
	if not is_instance_valid(loaded):
		return false
	var region := loaded.get_node_or_null(^"LandingRegion") as Node3D
	if not is_instance_valid(region):
		return false
	var corridor := (
		(host.get_snapshot().get("approach_entry", {}) as Dictionary)
			.get("envelope", {}) as Dictionary
	).get("corridor_transform_region_local_m", Transform3D.IDENTITY) as Transform3D
	craft.global_transform = region.global_transform * corridor
	craft.velocity = Vector3.ZERO
	for _index in HANDOFF_TICK_BUDGET:
		await physics_frame
		await process_frame
		if host.get_phase() == EmberSurfaceLoopHost.Phase.FAILED:
			return false
		if host.get_phase() > EmberSurfaceLoopHost.Phase.IDLE:
			return true
	return false


func _advance_to_phase(host: EmberSurfaceLoopHost, phase: int, tick_budget: int) -> bool:
	for _index in tick_budget:
		if host.get_phase() == phase:
			return true
		if host.get_phase() == EmberSurfaceLoopHost.Phase.FAILED:
			return false
		await physics_frame
		await process_frame
	return host.get_phase() == phase


func _walk_until(action: StringName, predicate: Callable, tick_budget: int) -> bool:
	Input.action_press(action)
	var ticks := 0
	while not bool(predicate.call()) and ticks < tick_budget:
		await physics_frame
		await process_frame
		ticks += 1
	Input.action_release(action)
	for _settle_tick in 4:
		await physics_frame
		await process_frame
	return bool(predicate.call())


func _wait_for(predicate: Callable, tick_budget: int) -> bool:
	for _index in tick_budget:
		if bool(predicate.call()):
			return true
		await physics_frame
		await process_frame
	return bool(predicate.call())


func _press_live_action(action: StringName, physics_ticks: int) -> void:
	Input.action_press(action)
	for _tick in maxi(1, physics_ticks):
		await physics_frame
	Input.action_release(action)
	await physics_frame
	await process_frame


func _release_all_actions() -> void:
	for action: StringName in FLIGHT_CONTROL_ACTIONS:
		Input.action_release(action)
	for action: StringName in ON_FOOT_ACTIONS:
		Input.action_release(action)


func _wait_until(predicate: Callable, timeout_seconds: float) -> bool:
	var frame_budget := (
		int(ceil(maxf(timeout_seconds, 0.0) * float(Engine.physics_ticks_per_second)))
		+ FRAME_BUDGET_GRACE
	)
	var deadline := Time.get_ticks_msec() + int(ceil(maxf(timeout_seconds, 0.0) * 1000.0))
	var frames := 0
	while not bool(predicate.call()):
		if frames >= frame_budget and Time.get_ticks_msec() >= deadline:
			return false
		await physics_frame
		await process_frame
		frames += 1
	return true




func _await_free_on_foot(game: GameFlow, player: PlayerController) -> void:
	_release_all_actions()
	await _wait_until(
		func() -> bool: return (
			not bool(game.get("_transition_busy"))
			and not player.is_seated()
			and player.is_control_enabled()
		),
		4.0
	)


func _tear_down(game: Node) -> void:
	_release_all_actions()
	game.queue_free()
	for _teardown_frame in 12:
		await process_frame
		await physics_frame


func _on_reward(_receipt: Dictionary) -> Dictionary:
	return {"accepted": true, "reason": &"ember_completed_return_override_reward"}


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		return
	_failures.append(description)
	push_error("EMBER_COMPLETED_RETURN_OVERRIDE_TEST: %s" % description)


func _finish() -> void:
	if _failures.is_empty():
		print("EMBER_COMPLETED_RETURN_OVERRIDE_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	print("EMBER_COMPLETED_RETURN_OVERRIDE_TEST_FAILED: %s" % ", ".join(_failures))
	quit(1)
