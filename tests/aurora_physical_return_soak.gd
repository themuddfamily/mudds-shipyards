extends "res://tests/ember_transit_movement_soak.gd"

## Long explicit acceptance, excluded from the default *_test.gd matrix.
## Default: a near-home fixture placed once before Aurora return admission.
## --aurora-full-roundtrip: real Halyard yard launch, 12 Mm outbound, surface
## supported coastal survey, durable reward, shared home return, berth landing and walking.
## One inherited initial on-foot yard placement precedes boarding. No full-mode
## in-flight or surface placement is used; zero staging means expedition staging.
## --aurora-local-berth: bounded real Halyard launch/landing/exit/walk only.
const AURORA_CANONICAL_STORE := "user://aurora-canonical-completed-journey.json"
const AuroraSurvey := preload("res://scripts/activities/aurora_coastal_survey.gd")

func _run() -> void:
	var full_roundtrip := "--aurora-full-roundtrip" in OS.get_cmdline_user_args()
	var local_berth := "--aurora-local-berth" in OS.get_cmdline_user_args()
	var game := MAIN_SCENE.instantiate() as GameFlow
	var filesystem: UserDataFilesystem = UserDataFilesystem.new() if full_roundtrip else MemoryFilesystem.new()
	if full_roundtrip:
		for suffix in ["", ".tmp", ".bak", ".bak.tmp"]:
			if filesystem.file_exists(AURORA_CANONICAL_STORE + suffix):
				_check(false, "canonical Aurora requires a fresh isolated disk profile")
				_finish()
				return
	var store := Store.new(AURORA_CANONICAL_STORE if full_roundtrip else "memory://aurora-home-return.json", filesystem)
	game.configure_runtime_settings_persistence(store, "user://aurora-canonical.cfg" if full_roundtrip else "memory://aurora-home-return.cfg")
	root.add_child(game)
	for tick in 240:
		await physics_frame
		await process_frame
		if bool(game.get("_initialized")) and game.get_flyable_ships().size() >= 9:
			break
	game.canopy_motion_time = 0.04
	game.boarding_motion_time = 0.08
	game.disembarking_motion_time = 0.06
	game.start_shift()
	await process_frame
	game.set("_guided_return_ready_for_completion", false)
	game.set("_guided_activity_complete", true)
	game.phase = GameFlow.Phase.COMPLETE
	var craft: HeroShip
	for candidate: HeroShip in game.get_flyable_ships():
		if candidate.get_ship_id() == (&"halyard_new_design" if full_roundtrip or local_berth else &"torrent_provisional"):
			craft = candidate
	await _await_free_on_foot(game, game.player)
	_check(await _walk_and_board(game, game.player, craft), "home fixture boards the real craft")
	_check(await _launch_completed(game, craft) if full_roundtrip else await _launch(game, craft), "home fixture physically departs its berth")
	if full_roundtrip and not _failures.is_empty():
		await _tear_down(game)
		_finish()
		return
	game.set("_active_activity_id", &"")
	var home := game.world.get_berth_node(craft.get_home_berth_id()) as ShipBerth
	var journey := game._planetary_journey
	var expedition: RefCounted = game.get("_aurora_expedition")
	var sampler := LegSampler.new()
	sampler.step(game)
	if local_berth:
		var climb_direction := (craft.global_basis.y * 0.8 - craft.global_basis.z * 0.6).normalized()
		Input.action_press(&"move_forward")
		for tick in 600:
			var local := craft.global_basis.inverse() * climb_direction
			_set_signed_action(&"pitch_up", &"pitch_down", atan2(local.y, Vector2(local.x, local.z).length()) * 3.0)
			await physics_frame
			await process_frame
			sampler.step(game)
		_release_all_actions()
		_check(await _fly_home_berth(game, sampler), "ordinary Halyard flight returns to its actual berth, exits and walks")
		await _tear_down(game)
		_finish()
		return
	if full_roundtrip:
		sampler.start_physics_sampling(self, game, &"aurora_outbound")
		_physics_samplers.append(sampler)
		if not await _full_aurora_outbound(game, craft, sampler):
			await _tear_down(game)
			_finish()
			return
		await sampler.stop_physics_sampling()
		_check(sampler.max_ship_step_m < 335.0 and sampler.max_player_step_m < 335.0
			and sampler.occupancy_failures == 0 and sampler.max_physics_frame_gap <= 1,
			"every outbound physics tick preserves bounded same-actor movement and exact pilot ownership")
		if not _failures.is_empty() or not await _full_aurora_surface(game, craft, store, filesystem):
			await _tear_down(game)
			_finish()
			return
		sampler = LegSampler.new()
		_physics_samplers.append(sampler)
		sampler.start_physics_sampling(self, game, &"aurora_return")
		if not await _full_aurora_departure(game, craft, sampler):
			await _tear_down(game)
			_finish()
			return
	else:
		craft.global_transform = home.get_dock_transform() * Transform3D(Basis.IDENTITY, Vector3(0.0, 120.0, -50_000.0))
		craft.global_basis = Basis.looking_at((home.get_dock_transform().origin - craft.global_position).normalized(), Vector3.UP)
		craft.velocity = Vector3.ZERO
		craft.reset_physics_interpolation()
		for tick in 4:
			await physics_frame
			await process_frame
		_check(bool(journey.admit_aurora_visit(craft, false).get("accepted", false)), "Aurora lane admits the near-home fixture before return ownership")
		expedition.set("_ship", craft)
		expedition.set("_home", home)
		expedition.set("_station_visible", game.world.visible)
		expedition.set("_station_environment", game.get_viewport().world_3d.environment)
		expedition.set("state", &"return_cruise")
		_check(bool(journey.begin_aurora_return().get("accepted", false)), "typed Aurora return admits the same actor")
		sampler = LegSampler.new()
		sampler.step(game)
	for tick in (72_000 if full_roundtrip else 6000):
		await physics_frame
		await process_frame
		sampler.step(game)
		if tick % 600 == 0:
			print("AURORA_HOME_CRUISE tick=", tick, " state=", expedition.get("state"), " speed=", craft.velocity.length(), " result=", (journey.get_aurora_visit_snapshot().get("last_return_result", {}) as Dictionary).get("reason"))
		if not expedition.is_active():
			break
	if full_roundtrip:
		_check(sampler.distance_flown_m > 11_800_000.0 and sampler.rebase_count > 1100,
			"the ordinary Aurora home leg physically crosses the full twelve-million-metre route")
	var snapshot := journey.get_aurora_visit_snapshot()
	_check(bool(snapshot.get("return_handoff_ready", false)) and not expedition.is_active()
		and game.phase == GameFlow.Phase.FREE_FLIGHT and game.active_ship == craft
		and game.player.is_seated() and craft.is_piloted() and not bool(craft.get_telemetry().get("landed", true)),
		"authenticated shell handoff retains exact actors in ordinary manual flight before home docking")
	_check(not bool(journey.get("_planetary_return_physical_arrival_required"))
		and not bool(journey.get("_ember_abandon_return_active")),
		"Aurora handoff never manufactures Ember reward or abandon ownership")
	if bool(snapshot.get("return_handoff_ready", false)):
		_check(await _fly_home_berth(game, sampler),
			"ordinary pilot inputs physically reach the original home lease, dock, exit and walk")
	_check(sampler.max_ship_step_m < 335.0 and sampler.max_player_step_m < 335.0
		and sampler.occupancy_failures == 0 and not craft.is_destroyed(),
		"typed home cruise through actual docking preserves actor continuity and pilot ownership")
	_check(is_equal_approx(float(craft.get_telemetry().get("hull", 0)), float(craft.get_telemetry().get("maximum_hull", -1)))
		and int(expedition.get_visit_snapshot().get("staging_events", -1)) == 0
		and not is_instance_valid(game.aurora_streaming_bootstrap.get_loaded_instance())
		and game.player.is_on_floor() and game.player.is_control_enabled(),
		"home return retains full hull, zero expedition placements, unloaded Aurora and a supported controllable pilot")
	if full_roundtrip and _failures.is_empty():
		var reloaded := Store.new(AURORA_CANONICAL_STORE, filesystem)
		_check(bool(reloaded.load_read_only().get("accepted", false)) and _aurora_reward_count(reloaded) == 1,
			"the once-paid Aurora reward remains durable after full return and walking exit")
		if _failures.is_empty():
			print("AURORA_CANONICAL_HEALTHY_ROUNDTRIP_OK reward_count=1 zero_expedition_staging=true initial_yard_foot_fixture=true supported_home_walk=true")
	print("AURORA_HOME_RETURN distance=", sampler.distance_flown_m, " rebases=", sampler.rebase_count, " hull=", craft.get_telemetry().get("hull"))
	await _tear_down(game)
	_finish()

func _finish() -> void:
	_release_all_actions()
	print("AURORA_PHYSICAL_RETURN_SOAK_", "OK" if _failures.is_empty() else "FAILED", ": ", _checks, " assertions")
	quit(0 if _failures.is_empty() else 1)

func _full_aurora_outbound(game: GameFlow, craft: HeroShip, sampler: LegSampler) -> bool:
	var departure := craft.global_position
	var climb_direction := (craft.global_basis.y * 0.8 - craft.global_basis.z * 0.6).normalized()
	Input.action_press(&"move_forward")
	for tick in 1800:
		var local := craft.global_basis.inverse() * climb_direction
		_set_signed_action(&"pitch_up", &"pitch_down", atan2(local.y, Vector2(local.x, local.z).length()) * 3.0)
		await physics_frame
		await process_frame
		sampler.step(game)
		if craft.global_position.distance_to(departure) > 500.0:
			break
	_release_all_actions()
	var bootstrap := game.aurora_streaming_bootstrap
	var frame := bootstrap.get_coordinate_frame_for_session()
	var encoded := frame.body_local_to_orbital_position(
		bootstrap.get_navigation_destination().get("body_local_position_meters"), frame.get_generation())
	var anchor := frame.orbital_to_world_streaming_position(
		encoded.get("coordinate"), frame.get_generation()).get("position", Vector3.INF) as Vector3
	for tick in 900:
		Input.action_press(&"brake")
		var direction := (anchor - craft.global_position).normalized()
		var local := craft.global_basis.inverse() * direction
		if (-craft.global_basis.z).dot(direction) > 0.99995 and craft.velocity.length() == 0.0:
			break
		_set_signed_action(&"move_right", &"move_left", atan2(local.x, -local.z) * 3.0)
		_set_signed_action(&"pitch_up", &"pitch_down", atan2(local.y, Vector2(local.x, local.z).length()) * 3.0)
		await physics_frame
		await process_frame
		sampler.step(game)
	_release_all_actions()
	for tick in 4:
		await physics_frame
		await process_frame
		sampler.step(game)
	var expedition: RefCounted = game.get("_aurora_expedition")
	_check(expedition.request(), "full round trip starts Aurora through production admission after real yard departure")
	for tick in 48_000:
		await physics_frame
		await process_frame
		sampler.step(game)
		if tick % 1200 == 0:
			print("AURORA_FULL_OUTBOUND tick=", tick, " state=", expedition.get("state"), " distance=", sampler.distance_flown_m, " rebases=", sampler.rebase_count, " hull=", craft.get_telemetry().get("hull"))
		if expedition.get("state") == &"landed" or not expedition.is_active() or craft.is_destroyed():
			break
	var berth := expedition.get("_berth") as ShipBerth
	var arrived: bool = expedition.get("state") == &"landed" and is_instance_valid(berth) \
		and berth.get_occupant() == craft and bool(craft.get_telemetry().get("landed", false))
	_check(arrived and sampler.distance_flown_m > 11_800_000.0 and sampler.rebase_count > 1100,
		"unstaged outward flight physically crosses twelve million metres and docks at Aurora")
	return arrived


func _full_aurora_departure(game: GameFlow, craft: HeroShip, sampler: LegSampler) -> bool:
	var expedition: RefCounted = game.get("_aurora_expedition")
	var pad_basis := craft.global_basis
	var pose := craft.global_transform
	var velocity := craft.velocity
	_check(expedition.request() and craft.global_transform == pose and craft.velocity == velocity,
		"full return admission preserves the physically landed craft")
	var climb_direction := (pad_basis.y * 0.85 - pad_basis.z * 0.5).normalized()
	var height := 0.0
	Input.action_press(&"move_forward")
	for tick in 1800:
		var local := craft.global_basis.inverse() * climb_direction
		_set_signed_action(&"move_right", &"move_left", atan2(local.x, -local.z) * 3.0)
		_set_signed_action(&"pitch_up", &"pitch_down", atan2(local.y, Vector2(local.x, local.z).length()) * 3.0)
		await physics_frame
		await process_frame
		sampler.step(game)
		var pad_origin: Vector3 = expedition.call("_landing_region_origin")
		height = (craft.global_position - pad_origin).dot(pad_basis.y)
		if height >= 1200.0:
			break
	_release_all_actions()
	_check(height >= 1200.0 and not bool(craft.get_telemetry().get("landed", true)),
		"ordinary pilot controls physically clear Aurora before home cruise")
	return height >= 1200.0


func _aurora_reward_count(store: UserDataStore) -> int:
	var ledger := store.get_snapshot().get("game_flow_reward_store", {}) as Dictionary
	return int((ledger.get("reward_counts", {}) as Dictionary).get(String(AuroraSurvey.REWARD_ID), 0))


## Walk with actual local movement axes; no position, attitude or velocity writes.
func _walk_aurora_target(game: GameFlow, target: Node3D, radius: float, local_point: Variant = null) -> bool:
	var player := game.player as PlayerController
	if not is_instance_valid(target) or not player.is_control_enabled() or player.is_seated():
		return false
	var speed: float = player.walk_speed
	if not is_finite(speed) or speed <= 0.0:
		return false
	var target_position: Vector3 = target.to_global(local_point) if local_point is Vector3 else target.global_position
	var distance := player.global_position.distance_to(target_position)
	var initial_position := player.global_position
	var initial_floor := player.is_on_floor()
	var peak_distance_from_start := 0.0
	var first_contact: Dictionary = {}
	# Use the existing locomotion budget as reserve, never an unbounded wait.
	var allowance := int(ceil(distance / speed * Engine.physics_ticks_per_second)) + LOCOMOTION_TICK_BUDGET
	var started := Engine.get_physics_frames()
	var reached := false
	while Engine.get_physics_frames() - started <= allowance:
		peak_distance_from_start = maxf(peak_distance_from_start, player.global_position.distance_to(initial_position))
		if first_contact.is_empty() and player.get_slide_collision_count() > 0:
			var contact := player.get_slide_collision(0)
			var collider := contact.get_collider() as Node
			first_contact = {"collider": str(collider.get_path()) if is_instance_valid(collider) else "",
				"normal": contact.get_normal(), "position": contact.get_position(), "physics_tick": Engine.get_physics_frames()}
		target_position = target.to_global(local_point) if local_point is Vector3 else target.global_position
		var offset := (target_position - player.global_position).slide(player.up_direction)
		if offset.length() <= radius:
			reached = true
			break
		if not player.is_control_enabled() or player.is_seated() or not target.is_inside_tree():
			break
		var camera := player.get_node(^"CameraRig/CameraYaw") as Node3D
		var direction := offset.normalized()
		_set_signed_action(&"move_right", &"move_left", camera.global_basis.x.dot(direction))
		_set_signed_action(&"move_forward", &"move_back", -camera.global_basis.z.dot(direction))
		await physics_frame
		await process_frame
	_release_all_actions()
	for tick in 4:
		await physics_frame
		await process_frame
	var supported: bool = player.is_on_floor() and player.is_control_enabled() and not player.is_seated()
	if not reached or not supported:
		var surface := game.aurora_streaming_bootstrap.get_loaded_instance() as Node3D
		var region := surface.get_node_or_null(^"LandingRegion") as Node3D if is_instance_valid(surface) else null
		var camera := player.get_node(^"CameraRig/CameraYaw") as Node3D
		var final_contacts: Array[Dictionary] = []
		for index in player.get_slide_collision_count():
			var contact := player.get_slide_collision(index)
			var collider := contact.get_collider() as Node
			final_contacts.append({"collider": str(collider.get_path()) if is_instance_valid(collider) else "",
				"normal": contact.get_normal(), "position": contact.get_position()})
		print("AURORA_SURFACE_WALK_BLOCKED ", {"target": str(target.get_path()),
			"initial_world": initial_position, "player_world": player.global_position, "target_world": target_position,
			"initial_region": region.to_local(initial_position) if is_instance_valid(region) else Vector3.INF,
			"player_region": region.to_local(player.global_position) if is_instance_valid(region) else Vector3.INF,
			"target_region": region.to_local(target_position) if is_instance_valid(region) else Vector3.INF,
			"velocity": player.velocity, "up": player.up_direction, "camera_basis": camera.global_basis,
			"initial_floor": initial_floor, "final_floor": player.is_on_floor(), "control": player.is_control_enabled(),
			"seated": player.is_seated(), "reached": reached, "radius": radius, "speed": speed,
			"allowance": allowance, "elapsed_physics": Engine.get_physics_frames() - started,
			"peak_distance_from_start": peak_distance_from_start, "first_slide_contact": first_contact, "final_slide_contacts": final_contacts})
	return reached and supported


## Reuse aurora_visit_loop_test's ordinary coastal corridor and landward lookout
## opening. Resolve every point in the live LandingRegion; only input moves actors.
func _walk_aurora_coastal_route(game: GameFlow, region: Node3D, points: Array) -> bool:
	for point: Vector3 in points:
		if not await _walk_aurora_target(game, region, 0.7, point):
			return false
	return true


func _full_aurora_surface(game: GameFlow, craft: HeroShip, store: UserDataStore, filesystem: UserDataFilesystem) -> bool:
	var expedition: RefCounted = game.get("_aurora_expedition")
	var player := game.player as PlayerController
	_check(not craft.is_destroyed() and is_equal_approx(float(craft.get_telemetry().get("hull", 0)),
		float(craft.get_telemetry().get("maximum_hull", -1)))
		and int(expedition.get_visit_snapshot().get("staging_events", -1)) == 0,
		"full ordinary Aurora arrival retains a healthy hull and zero expedition placements")
	if not _failures.is_empty():
		return false
	expedition.request_exit()
	var on_foot := await _wait_until(func() -> bool:
		return expedition.get("state") == &"surface" and not bool(game.get("_transition_busy")) \
			and not player.is_seated() and player.is_on_floor() and player.is_control_enabled(), 4.0)
	_check(on_foot, "Aurora physically disembarks the same pilot onto supported surface ground")
	if not on_foot:
		return false
	var surface := game.aurora_streaming_bootstrap.get_loaded_instance() as Node3D
	var survey: RefCounted = expedition.get("survey")
	if not is_instance_valid(surface) or survey == null:
		_check(false, "the production Aurora survey and streamed surface remain live")
		return false
	_check(_aurora_reward_count(store) == 0, "the real Aurora survey starts unpaid")
	var region := surface.get_node(^"LandingRegion") as Node3D
	var coastal_routes: Array = [
		[Vector3(-7, 0, -17), Vector3(8, 0, -17), Vector3(20, 0, -7), Vector3(25, 0, 2), Vector3(29, 0, 1)],
		[Vector3(33, 0, 2), Vector3(43, 0, -8), Vector3(55, 0, -20), Vector3(60, 0, -20), Vector3(66, 0, -17)],
		[Vector3(60, 0, -20), Vector3(54, 0, -20), Vector3(52, 0, -27), Vector3(52, 0, -32)],
	]
	for index in AuroraSurvey.ANCHORS.size():
		var anchor := surface.find_child(AuroraSurvey.ANCHORS[index], true, false) as Node3D
		var walked: bool = await _walk_aurora_coastal_route(game, region, coastal_routes[index])
		if walked:
			walked = await _walk_aurora_target(game, anchor, 2.5)
		_check(walked, "ordinary supported walking reaches Aurora survey anchor %s" % AuroraSurvey.ANCHORS[index])
		if not walked:
			return false
		await _press_live_action(&"interact", 1)
		var route := survey.call(&"snapshot") as Dictionary
		var expected: int = CheckpointRouteActivity.State.COMPLETED if index == 2 else CheckpointRouteActivity.State.ACTIVE
		_check(int(route.get("state", -1)) == expected and int(route.get("next_checkpoint_index", -1)) == maxi(index, 0),
			"ordinary interaction advances the real coastal observation objective")
		if not _failures.is_empty():
			return false
	var reloaded := Store.new(AURORA_CANONICAL_STORE, filesystem)
	_check(_aurora_reward_count(store) == 1 and bool(reloaded.load_read_only().get("accepted", false))
		and reloaded.get_snapshot() == store.get_snapshot() and reloaded.get_generation() == store.get_generation(),
		"completed coastal observations commit exactly one reward through real disk serialization")
	var ledger := (store.get_snapshot().get("game_flow_reward_store", {}) as Dictionary).duplicate(true)
	await _press_live_action(&"interact", 1)
	game.save_interrupted_aurora_visit()
	game.save_interrupted_aurora_visit()
	var repeated := Store.new(AURORA_CANONICAL_STORE, filesystem)
	_check(_aurora_reward_count(store) == 1 and store.get_snapshot().get("game_flow_reward_store", {}) == ledger
		and bool(repeated.load_read_only().get("accepted", false)) and _aurora_reward_count(repeated) == 1,
		"repeated supported interaction and visit saves preserve the durable once-only reward")
	if not _failures.is_empty():
		return false
	print("AURORA_CANONICAL_SURVEY_DURABLE_ONCE_OK reward_count=1")
	var boarding := craft.get_node(^"ShipBoardingArea") as Node3D
	var returned: bool = await _walk_aurora_coastal_route(game, region, [
		Vector3(52, 0, -27), Vector3(54, 0, -20), Vector3(43, 0, -8), Vector3(33, 0, 2),
		Vector3(20, 0, -7), Vector3(8, 0, -17), Vector3(-7, 0, -17),
	])
	if returned:
		returned = await _walk_aurora_target(game, craft, 2.5, craft.to_local(craft.get_boarding_position()))
	_check(returned, "the pilot walks back to the physically landed ship without placement")
	if not returned:
		return false
	await _press_live_action(&"interact", 1)
	var seated := await _wait_until(func() -> bool:
		return expedition.get("state") == &"landed" and player.is_seated() and craft.is_piloted() \
			and (boarding as ShipBoardingArea).get_reservation_token() == player, 4.0)
	_check(seated, "ordinary Aurora boarding restores the same craft and exact pilot reservation")
	return seated and _failures.is_empty()
