extends SceneTree
## test-matrix-timeout-seconds: 900

## Touching the flight controls during an abandoned Ember expedition's return
## cruise hands the pilot the craft; releasing them resumes the flight home.
##
## The HUD tells an abandoning pilot to "fly clear of Ember's surface, then
## release flight controls for the Mudds return", and the outbound leg already
## resumes the same way. The return did not: the first manual input on the
## 8,000 km cruise home retired the approach for good, leaving the pilot out at
## Ember with no route back (the pause row offered a new Ember expedition).
##
## Staging is ember_repeat_visit_landing_test's: the craft is held at the
## navigation anchor until the real final approach activates, then placed once
## at the corridor entry. The descent, landing, disembark, abandon, re-board,
## surface departure, return cruise and manual override are all production.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const Store := preload("res://scripts/persistence/user_data_store.gd")
const ISOLATED_STORE_PATH := "memory://ember-abandon-return-override.json"
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


var _failures: Array[String] = []
var _assertions := 0


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	var isolated_store := Store.new(ISOLATED_STORE_PATH, MemoryFilesystem.new())
	game.configure_runtime_settings_persistence(
		isolated_store, "memory://ember-abandon-return-override-legacy.cfg"
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
	var begun := game.begin_ember_surface_journey(
		host, game.activity_director, Callable(self, &"_on_reward"), 1
	)
	_check(bool(begun.get("accepted", false)), "the Ember expedition is admitted")
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
	var abandoned := game.abandon_ember_surface_journey(&"player_abandoned")
	_check(bool(abandoned.get("accepted", false)), "the abandon is admitted from the surface")
	for _settle in 12:
		await physics_frame
		await process_frame
	_check(await _reboard_after_abandon(player, host, craft), "the pilot re-boards at the caldera")
	_check(await _advance_until_abandon_commits(game, host), "the abandon commits off the pad")
	# Clear the terrain with ordinary thrust, then release for the queued return.
	var cleared := false
	Input.action_press(&"move_forward")
	for _tick in 2400:
		await physics_frame
		await process_frame
		var altitude := (craft.global_position - berth.global_position).dot(berth.global_basis.y)
		if altitude >= 1200.0:
			cleared = true
			break
	Input.action_release(&"move_forward")
	_check(cleared, "ordinary thrust clears the Ember terrain")
	var cruising := await _wait_for(func() -> bool: return _return_cruising(game, craft), 1800)
	_check(cruising, "the queued return engages the cruise home (%s)" % [
		(game.get("_planetary_journey").get("_last_ember_abandon_return_arm_result") as Dictionary).get("reason", &"?")])
	if not cruising:
		print("RETURN not cruising: active=%s pending=%s cruise=%s ship=%s" % [
			game.get("_mudds_return_approach_active"),
			game.get("_planetary_journey").get("_ember_abandon_return_arm_pending"),
			cruise.get_snapshot().get("last_reason", &"?"),
			craft.get_planetary_cruise_attachment_report().get("state", &"?")])
		await _tear_down(game)
		_finish()
		return
	for _cruise_tick in 60:
		await physics_frame
		await process_frame
	var home: Vector3 = game.world.get_ship_spawn().origin
	var distance_before := craft.global_position.distance_to(home)
	# The pilot nudges the controls mid-cruise: control is theirs while held.
	Input.action_press(&"move_forward")
	var released_to_pilot := await _wait_for(
		func() -> bool: return not bool(cruise.get_snapshot().get("engagement_requested", true)), 30)
	for _held in 20:
		await physics_frame
		await process_frame
	Input.action_release(&"move_forward")
	_check(released_to_pilot, "held flight controls hand the craft back to the pilot")
	var resumed := await _wait_for(func() -> bool: return _return_cruising(game, craft), 1800)
	var distance_after := craft.global_position.distance_to(home)
	print("OVERRIDE distance_before=%.0f m distance_after=%.0f m resumed=%s arm=%s last=%s" % [
		distance_before, distance_after, resumed,
		(game.get("_planetary_journey").get("_last_ember_abandon_return_arm_result") as Dictionary).get("reason", &"?"),
		(game.get("_last_mudds_return_approach_result") as Dictionary).get("reason", &"?")])
	_check(
		resumed,
		"releasing the controls resumes the cruise home from %.0f km out" % (distance_after / 1000.0)
	)
	await _tear_down(game)
	_finish()


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


func _reboard_after_abandon(
		player: PlayerController,
		host: EmberSurfaceLoopHost,
		craft: HeroShip,
	) -> bool:
	var area := craft.get_node_or_null(^"ShipBoardingArea") as ShipBoardingArea
	if not is_instance_valid(area):
		return false
	if not (area in player.get_nearby_interactables()):
		if not await _walk_until(
			&"move_forward",
			func() -> bool: return area in player.get_nearby_interactables(),
			120
		):
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
		func() -> bool: return player.is_seated() and host.get_phase() in [
			EmberSurfaceLoopHost.Phase.REBOARDED,
			EmberSurfaceLoopHost.Phase.TAKEOFF,
			EmberSurfaceLoopHost.Phase.ASCENT,
			EmberSurfaceLoopHost.Phase.ORBIT_RETURN,
			EmberSurfaceLoopHost.Phase.IDLE,
		],
		REBOARD_TICK_BUDGET
	)


func _advance_until_abandon_commits(game: GameFlow, host: EmberSurfaceLoopHost) -> bool:
	for _index in ABANDON_TICK_BUDGET:
		if host.get_phase() == EmberSurfaceLoopHost.Phase.IDLE \
				and not bool(game.get("_ember_surface_journey_active")):
			return true
		if host.get_phase() == EmberSurfaceLoopHost.Phase.FAILED:
			return false
		await physics_frame
		await process_frame
	return host.get_phase() == EmberSurfaceLoopHost.Phase.IDLE \
		and not bool(game.get("_ember_surface_journey_active"))


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
	return {"accepted": true, "reason": &"ember_abandon_return_override_reward"}


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		return
	_failures.append(description)
	push_error("EMBER_ABANDON_RETURN_OVERRIDE_TEST: %s" % description)


func _finish() -> void:
	if _failures.is_empty():
		print("EMBER_ABANDON_RETURN_OVERRIDE_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	print("EMBER_ABANDON_RETURN_OVERRIDE_TEST_FAILED: %s" % ", ".join(_failures))
	quit(1)
