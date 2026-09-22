extends "res://tests/ember_transit_movement_soak.gd"

## Long explicit acceptance, excluded from the default *_test.gd matrix.
## Default: a near-home fixture placed once before Aurora return admission.
## --aurora-full-roundtrip: real Halyard yard launch, 12 Mm outbound, surface
## departure and shared home return, ordinary berth landing, exit and walking.
## --aurora-local-berth: bounded real Halyard launch/landing/exit/walk only.
func _run() -> void:
	var full_roundtrip := "--aurora-full-roundtrip" in OS.get_cmdline_user_args()
	var local_berth := "--aurora-local-berth" in OS.get_cmdline_user_args()
	var game := MAIN_SCENE.instantiate() as GameFlow
	var store := Store.new("memory://aurora-home-return.json", MemoryFilesystem.new())
	game.configure_runtime_settings_persistence(store, "memory://aurora-home-return.cfg")
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
	_check(await _launch(game, craft), "home fixture physically departs its berth")
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
		if not await _full_aurora_outbound(game, craft, sampler) or not await _full_aurora_departure(game, craft, sampler):
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
		var direction := (anchor - craft.global_position).normalized()
		var local := craft.global_basis.inverse() * direction
		if (-craft.global_basis.z).dot(direction) > 0.99995:
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
