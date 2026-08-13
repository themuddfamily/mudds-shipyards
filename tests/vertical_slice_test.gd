extends SceneTree

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		_fail("main scene did not load")
		_finish()
		return
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame

	var world: Node3D = game.get_node("ShipyardWorld")
	var player: CharacterBody3D = game.get_node("Player")
	var ship: CharacterBody3D = game.get_node("TorrentInterceptor")
	var opponent: CharacterBody3D = game.get_node("RangeOpponent")
	var hud: CanvasLayer = game.get_node("HUD")
	game.canopy_motion_time = 0.08
	game.boarding_motion_time = 0.18
	game.disembarking_motion_time = 0.15
	_check(_all_controls_passthrough(hud.get("_hud") as Control), "gameplay HUD passes mouse look and fire input through")

	game.start_shift()
	await process_frame
	_check(game.phase == GameFlow.Phase.APPROACH_SHIP, "shift begins on foot")
	_check(player.visible and player.call("is_control_enabled"), "player can physically approach ship")

	var starting_player_position := player.global_position
	Input.action_press("move_forward")
	Input.action_press("sprint_boost")
	for _step in 240:
		await physics_frame
		if bool(game.get("_near_ship")):
			break
	Input.action_release("move_forward")
	Input.action_release("sprint_boost")
	_check(player.global_position.distance_to(starting_player_position) > 6.0, "real movement input crosses the physical station deck")
	_check(bool(game.get("_near_ship")), "walking into boarding range exposes the ship interaction")
	Input.action_press("interact")
	await physics_frame
	Input.action_release("interact")
	await process_frame
	_check(game.phase == GameFlow.Phase.BOARDING, "real interaction input starts a visible boarding phase")
	_check(player.visible and not player.call("is_control_enabled"), "the actual player remains visible during control handoff")
	await create_timer(0.65).timeout
	await physics_frame
	_check(game.phase == GameFlow.Phase.START_ENGINES, "physical seating and canopy closure enter cockpit startup")
	_check(player.visible and player.call("is_seated"), "the actual player sits visibly in the pilot seat")
	_check(
		player.global_position.distance_to((ship.call("get_pilot_seat_anchor") as Node3D).global_position) < 0.08,
		"seated player occupies the moving ship's physical anchor"
	)
	_check(not bool(ship.call("is_canopy_open")), "canopy seals around the seated pilot")
	_check(ship.call("get_camera").current, "ship chase camera becomes current")

	ship.call("request_engine_start")
	await create_timer(2.2).timeout
	await physics_frame
	var telemetry: Dictionary = ship.call("get_telemetry")
	_check(str(telemetry.engine_state) == "ONLINE", "engine completes deliberate startup")
	_check(game.phase == GameFlow.Phase.LAUNCH, "online engine advances to launch")

	# Put a real drone directly under the chase-camera reticle while the ship is
	# still inside the launch phase. This catches offset-cannon parallax and also
	# proves an early range kill is counted without bypassing the launch gate.
	var targets: Array[Node] = []
	for candidate in world.find_children("*", "StaticBody3D", true, false):
		if candidate.get_meta("is_shipyard_target", false):
			targets.append(candidate)
	_check(targets.size() == world.call("get_target_count"), "all target drones are physical raycast bodies")
	ship.global_position.y += 14.0
	await physics_frame
	var ship_camera: Camera3D = ship.call("get_camera")
	var screen_center := ship_camera.get_viewport().get_visible_rect().size * 0.5
	var camera_direction := ship_camera.project_ray_normal(screen_center).normalized()
	var early_target := targets.pop_front() as Node3D
	var early_target_position := ship_camera.global_position + camera_direction * 28.0
	early_target.position = (early_target.get_parent() as Node3D).to_local(early_target_position)
	early_target.set_meta("base_position", early_target.position)
	await physics_frame
	Input.action_press("fire")
	await physics_frame
	Input.action_release("fire")
	var pulse_presentation := game.get_node_or_null("PulseWeaponPresentation") as PulseWeaponPresentation
	_check(
		pulse_presentation != null and pulse_presentation.get_active_effect_count() > 0,
		"real fire input creates a pooled travelling pulse presentation"
	)
	_check(float(early_target.get_meta("health", 100.0)) < 100.0, "camera-center reticle converges an offset cannon onto a nearby target")
	# Use the same emitted ray for a deterministic second damage pulse. The
	# preceding real input assertion is what validates the gameplay fire path.
	var early_muzzle := ship.get_node("LeftMuzzle") as Marker3D
	game.call("_on_projectile_fired", early_muzzle.global_position, (early_target.global_position - early_muzzle.global_position).normalized())
	await process_frame
	_check(game.destroyed_targets == 1, "a launch-phase target kill is retained")
	_check(game.phase == GameFlow.Phase.LAUNCH, "an early target kill cannot skip the launch gate")

	# Move only vertically into the illuminated launch lane; forward progress is
	# still entirely driven by gameplay throttle input below.
	ship.global_position.y = 9.0
	ship.velocity = Vector3.ZERO
	await physics_frame
	var launch_start_position := ship.global_position
	Input.action_press("move_forward")
	Input.action_press("sprint_boost")
	for _step in 300:
		await physics_frame
		if game.phase != GameFlow.Phase.LAUNCH:
			break
	Input.action_release("move_forward")
	Input.action_release("sprint_boost")
	_check(ship.global_position.distance_to(launch_start_position) > 50.0, "real throttle input flies the ship through the launch corridor")
	_check(game.phase == GameFlow.Phase.TARGET_PRACTICE, "player-driven gate crossing advances to target practice")
	_check(
		player.global_position.distance_to((ship.call("get_pilot_seat_anchor") as Node3D).global_position) < 0.08,
		"visible pilot remains attached inside the moving spacecraft"
	)

	# A/D must steer without permanently rolling the physics body, and the arcade
	# assist must turn momentum with the visible nose instead of retaining the old
	# travel vector. This is the human-facing flight-direction regression.
	ship.global_basis = Basis.IDENTITY
	ship.velocity = Vector3(0.0, 0.0, -36.0)
	Input.action_press("move_right")
	Input.action_press("move_forward")
	for _step in 54:
		await physics_frame
	Input.action_release("move_right")
	Input.action_release("move_forward")
	var ship_up := ship.global_basis.y.normalized()
	var ship_forward := -ship.global_basis.z.normalized()
	var travel_direction := ship.velocity.normalized()
	_check(ship_up.dot(Vector3.UP) > 0.98, "keyboard steering keeps the physical ship upright")
	_check(ship_forward.dot(travel_direction) > 0.9, "arcade flight assist moves the ship in its visible forward direction")

	for target in targets:
		var target_position: Vector3 = (target as Node3D).global_position
		for hit_index in 2:
			var result: Dictionary = world.call(
				"register_projectile_hit",
				target_position + Vector3(0.0, 0.0, 4.0),
				target_position - Vector3(0.0, 0.0, 4.0)
			)
			_check(bool(result.get("target", false)), "pulse cannon ray hits marked drone")
			await physics_frame
	await process_frame
	await process_frame
	_check(game.destroyed_targets == world.call("get_target_count"), "destroyed targets update mission state")
	_check(game.phase == GameFlow.Phase.INTERCEPTOR_ENGAGEMENT, "clearing drones launches a live opposing spacecraft")
	_check(bool(opponent.call("is_active")), "range-defence interceptor physically enters the shared world")
	var opponent_activation_position := opponent.global_position
	for _step in 12:
		await physics_frame
	_check(opponent.global_position.distance_to(opponent_activation_position) > 0.2, "opposing spacecraft autonomously manoeuvres in the shared physics world")

	# Exercise autonomous incoming fire, directional HUD feedback, outgoing
	# real-input fire, staged enemy damage, and a physical destruction transition.
	ship.global_position = Vector3(-48.0, 30.0, -190.0)
	ship.global_basis = Basis.IDENTITY
	ship.velocity = Vector3.ZERO
	opponent.global_position = ship.global_position + Vector3(0.0, 0.0, 40.0)
	opponent.global_basis = Basis.IDENTITY
	opponent.velocity = Vector3.ZERO
	opponent.set("cruise_speed", 0.0)
	opponent.set("chase_speed", 0.0)
	opponent.set("acceleration", 0.0)
	opponent.set("telegraph_time", 0.05)
	opponent.set("weapon_cooldown", 0.2)
	opponent.set("_cooldown_remaining", 0.0)
	await physics_frame
	await process_frame
	var hull_before: float = float(ship.call("get_telemetry").get("hull", 0.0))
	for _step in 90:
		await physics_frame
		if float(ship.call("get_telemetry").get("hull", 0.0)) < hull_before:
			break
	_check(float(ship.call("get_telemetry").get("hull", 0.0)) < hull_before, "autonomous opposing fire damages the hero ship")
	var damage_direction := hud.get("_damage_direction") as Control
	_check(damage_direction != null and damage_direction.visible, "incoming fire produces directional hull feedback")
	var hero_damage := ship.call("get_damage_presentation") as HeroDamagePresentation
	_check(hero_damage != null and hero_damage.get_live_world_effect_count() > 0, "incoming hit creates a detached hero impact effect")
	var current_hull := float(ship.call("get_telemetry").get("hull", 100.0))
	ship.call(
		"apply_damage",
		maxf(0.0, current_hull - 65.0),
		ship.global_position + Vector3(-3.0, 1.0, 0.0),
		Vector3.LEFT
	)
	await process_frame
	_check(hero_damage.get_damage_stage() == HeroDamagePresentation.DamageStage.DAMAGED, "hero hull damage reaches the persistent spark stage")
	var hero_damage_sparks := hero_damage.get_node("DamageSparks") as CPUParticles3D
	_check(hero_damage_sparks.emitting, "damaged hero ship emits persistent hull sparks")
	ship.call(
		"apply_damage",
		37.0,
		ship.global_position + Vector3(-1.75, 1.0, 4.8),
		Vector3.BACK
	)
	await process_frame
	_check(hero_damage.get_damage_stage() == HeroDamagePresentation.DamageStage.CRITICAL, "hero hull damage reaches the critical engine stage")
	var hero_engine_smoke := hero_damage.get_node("EngineSmoke") as CPUParticles3D
	_check(hero_engine_smoke.emitting, "critical hero damage produces persistent engine smoke")
	_check(float(ship.call("get_telemetry").get("engine_power", 1.0)) < 1.0, "critical engine damage degrades available thrust")

	opponent.set_physics_process(false)
	ship_camera = ship.call("get_camera")
	screen_center = ship_camera.get_viewport().get_visible_rect().size * 0.5
	camera_direction = ship_camera.project_ray_normal(screen_center).normalized()
	opponent.global_position = ship_camera.global_position + camera_direction * 30.0
	opponent.global_basis = Basis.IDENTITY
	await physics_frame
	await process_frame
	var enemy_start_health: float = float(opponent.call("get_health"))
	for shot_index in 2:
		Input.action_press("fire")
		await physics_frame
		await physics_frame
		Input.action_release("fire")
		await create_timer(0.24).timeout
	_check(float(opponent.call("get_health")) < enemy_start_health, "real reticle fire damages the opposing spacecraft")
	var enemy_smoke := opponent.find_child("EngineSmoke", true, false) as CPUParticles3D
	_check(enemy_smoke != null and enemy_smoke.emitting, "critical enemy damage produces persistent engine smoke")
	Input.action_press("fire")
	await physics_frame
	await physics_frame
	Input.action_release("fire")
	await process_frame
	_check(not bool(opponent.call("is_active")), "enemy craft reaches a staged physical destruction state")
	_check(game.phase == GameFlow.Phase.RETURN_TO_YARD, "winning the dogfight assigns the return objective")

	var landing_transform: Transform3D = world.call("get_ship_spawn")
	ship.global_transform = landing_transform.translated(Vector3(0.0, 3.0, 0.0))
	ship.velocity = Vector3.ZERO
	game.call("_try_request_landing")
	_check(ship.call("is_landing_active"), "landing assist accepts a slow craft over the physical berth")
	await create_timer(2.0).timeout
	await physics_frame
	telemetry = ship.call("get_telemetry")
	_check(bool(telemetry.landed), "landing assist returns ship to physical pad")
	_check(game.phase == GameFlow.Phase.SHUT_DOWN, "landing advances to shutdown")
	Input.action_press("move_forward")
	await physics_frame
	Input.action_release("move_forward")
	telemetry = ship.call("get_telemetry")
	_check(bool(telemetry.landed) and ship.velocity.length() < 0.1, "docking latch prevents accidental relaunch during shutdown")

	ship.call("request_engine_stop")
	await process_frame
	game.call("_try_exit_ship")
	await process_frame
	_check(game.phase == GameFlow.Phase.DISEMBARKING, "shutdown opens the canopy and begins physical disembarking")
	_check(player.visible and player.call("is_seated"), "pilot remains visible in the seat while the canopy opens")
	await create_timer(0.55).timeout
	await physics_frame
	_check(game.phase == GameFlow.Phase.COMPLETE, "shutdown permits same-world physical ship exit")
	_check(player.visible and player.call("is_control_enabled"), "player resumes on-foot exploration beside ship")
	_check(not player.call("is_seated"), "disembarking restores the actual player to on-foot embodiment")
	_check(player.global_position.distance_to(ship.call("get_exit_transform").origin) < 0.2, "player exits at physical boarding step")
	await physics_frame
	_check(not player.test_move(player.global_transform, Vector3.UP * 0.01), "exit marker is outside ship collision")
	game.call("_on_interact_requested")
	await process_frame
	_check(game.phase == GameFlow.Phase.COMPLETE, "completed shift cannot accidentally reboard into a stale mission")

	game.queue_free()
	await process_frame
	await process_frame
	await process_frame
	_finish()


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_fail(description)


func _fail(description: String) -> void:
	_failures.append(description)
	push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("VERTICAL_SLICE_TEST_OK")
		quit(0)
	else:
		print("VERTICAL_SLICE_TEST_FAILED: ", ", ".join(_failures))
		quit(1)


func _all_controls_passthrough(control: Control) -> bool:
	if control.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		print("INFO: mouse filter blocks gameplay at ", control.get_path(), " value=", control.mouse_filter)
		return false
	for child in control.get_children():
		if child is Control and not _all_controls_passthrough(child as Control):
			return false
	return true
