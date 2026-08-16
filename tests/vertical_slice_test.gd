extends SceneTree

## Extra simulated physics frames granted on top of the frames a wait's nominal
## duration implies. This is a frame count, never a wall-clock grace. See
## [method _wait_until] for why every wait in this slice is budgeted in frames.
const FRAME_BUDGET_GRACE := 30

## Nominal simulated seconds the cannon needs to clear its 0.22 s cooldown
## between the two aimed shots. This bounds the wait; it is never spent in full,
## because the gap is ended by the cannon actually coming ready. See the shot
## loop for why an over-long gap is as wrong as a too-short one.
const SHOT_COOLDOWN_SECONDS := 0.24

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
	var seated_in_budget := await _wait_until(
		func() -> bool: return game.phase == GameFlow.Phase.START_ENGINES,
		0.65
	)
	await physics_frame
	_check(seated_in_budget, "physical seating and canopy closure complete inside their bounded budget")
	_check(game.phase == GameFlow.Phase.START_ENGINES, "physical seating and canopy closure enter cockpit startup")
	_check(player.visible and player.call("is_seated"), "the actual player sits visibly in the pilot seat")
	_check(
		player.global_position.distance_to((ship.call("get_pilot_seat_anchor") as Node3D).global_position) < 0.08,
		"seated player occupies the moving ship's physical anchor"
	)
	_check(not bool(ship.call("is_canopy_open")), "canopy seals around the seated pilot")
	_check(ship.call("get_camera").current, "ship chase camera becomes current")

	var engine_online_in_budget := await _apply_forward_demand_for_one_tick(ship)
	var telemetry: Dictionary = ship.call("get_telemetry")
	_check(engine_online_in_budget, "one accepted flight-demand tick wakes the engine ONLINE")
	_check(str(telemetry.engine_state) == "ONLINE", "automatic engine wake is visible in telemetry")
	_check(game.phase == GameFlow.Phase.START_ENGINES, "automatic engine wake alone retains the launch-ready phase")
	Input.action_press(&"move_forward")
	var departed_berth := await _wait_until(
		func() -> bool: return not bool(ship.call("get_telemetry").get("landed", true)),
		0.5
	)
	Input.action_release(&"move_forward")
	_check(departed_berth, "sustained real thrust physically clears the occupied berth")
	_check(
		await _wait_until(func() -> bool: return game.phase == GameFlow.Phase.LAUNCH, 0.1),
		"physical departure advances the guided sortie to launch"
	)

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
		# The cannon counts its cooldown down in `_physics_process`, so wait for the
		# cannon itself to come ready. The gap must be the real one and no longer:
		# the ship is still flying while the target is stationary, so every extra
		# simulated frame between shots carries the reticle further off the drone.
		# A nominal sleep was wrong in both directions here — too few simulated
		# frames and the second shot is refused on cooldown, too many and it misses.
		_check(
			await _wait_until(
				func() -> bool: return float(ship.get("_weapon_timer")) <= 0.0,
				SHOT_COOLDOWN_SECONDS
			),
			"pulse cannon clears its cooldown inside its bounded budget"
		)
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
	var landed_in_budget := await _wait_until(
		func() -> bool: return bool(ship.call("get_telemetry").get("landed", false)),
		2.0
	)
	await physics_frame
	telemetry = ship.call("get_telemetry")
	_check(landed_in_budget, "landing assist completes inside its bounded budget")
	_check(bool(telemetry.landed), "landing assist returns ship to physical pad")
	_check(game.phase == GameFlow.Phase.SHUT_DOWN, "landing advances to shutdown")
	Input.action_press("move_forward")
	await physics_frame
	Input.action_release("move_forward")
	telemetry = ship.call("get_telemetry")
	_check(bool(telemetry.landed) and ship.velocity.length() < 0.1, "docking latch prevents accidental relaunch during shutdown")

	_check(
		await _wait_for_automatic_engine_offline(ship),
		"neutral controls shut the landed engine OFFLINE on the finite physics-idle budget"
	)
	game.call("_try_exit_ship")
	# `_try_exit_ship` enters DISEMBARKING and opens the canopy synchronously, and
	# only unseats the pilot after it awaits `canopy_motion_finished`. The seated
	# pilot therefore exists at exactly this instant, and observing it here is the
	# precise measurement. Observing it one `process_frame` later was a race on the
	# wrong clock: under load a single frame carries enough delta to run out both
	# the 0.08 s canopy and the 0.15 s disembark motion, so the probe arrived after
	# the pilot had legitimately left the seat and scored a healthy slice as a
	# failure.
	_check(game.phase == GameFlow.Phase.DISEMBARKING, "shutdown opens the canopy and begins physical disembarking")
	_check(player.visible and player.call("is_seated"), "pilot remains visible in the seat while the canopy opens")
	await process_frame
	var exit_in_budget := await _wait_until(
		func() -> bool: return game.phase == GameFlow.Phase.COMPLETE,
		0.55
	)
	await physics_frame
	_check(exit_in_budget, "physical disembark completes inside its bounded budget")
	_check(game.phase == GameFlow.Phase.COMPLETE, "shutdown permits same-world physical ship exit")
	_check(player.visible and player.call("is_control_enabled"), "player resumes on-foot exploration beside ship")
	_check(not player.call("is_seated"), "disembarking restores the actual player to on-foot embodiment")
	_check(player.global_position.distance_to(ship.call("get_exit_transform").origin) < 0.2, "player exits at physical boarding step")
	await physics_frame
	_check(not player.test_move(player.global_transform, Vector3.UP * 0.01), "exit marker is outside ship collision")
	game.call("_on_interact_requested")
	await process_frame
	_check(game.phase == GameFlow.Phase.COMPLETE, "completed shift cannot accidentally reboard into a stale mission")

	await _release_combat_audio_before_main_teardown(game)
	game.queue_free()
	await process_frame
	await process_frame
	await process_frame
	_finish()


func _release_combat_audio_before_main_teardown(game: Node) -> void:
	var combat_audio := game.get_node_or_null("CombatAudioPresentation") as CombatAudioPresentation
	if combat_audio == null:
		return
	for candidate in combat_audio.find_children("*", "AudioStreamPlayer3D", true, false):
		var player := candidate as AudioStreamPlayer3D
		player.stop()
		player.stream_paused = false
		player.stream = null
	# Give both the scene loop and audio backend a bounded boundary in which to
	# release the final explosion playback before the presentation bank is freed.
	await process_frame
	var mixer_release_seconds := maxf(
		0.05,
		AudioServer.get_time_to_next_mix() + AudioServer.get_output_latency()
	)
	await create_timer(mixer_release_seconds).timeout
	var parent := combat_audio.get_parent()
	if parent != null:
		parent.remove_child(combat_audio)
	combat_audio.free()
	await process_frame


func _apply_forward_demand_for_one_tick(ship: HeroShip) -> bool:
	Input.action_press(&"move_forward")
	await physics_frame
	await process_frame
	var accepted := (
		str(ship.get_telemetry().get("engine_state", &"")).to_upper() == "ONLINE"
		and ship.get_last_ship_command().throttle > 0.0
	)
	Input.action_release(&"move_forward")
	return accepted


func _wait_for_automatic_engine_offline(ship: HeroShip) -> bool:
	for action in [&"move_forward", &"move_back", &"move_left", &"move_right", &"fire", &"landing_assist"]:
		Input.action_release(action)
	var frame_budget := (
		int(ceil(HeroShip.AUTOMATIC_ENGINE_IDLE_SHUTDOWN_SECONDS * float(Engine.physics_ticks_per_second)))
		+ FRAME_BUDGET_GRACE
	)
	for _frame in frame_budget:
		if str(ship.get_telemetry().get("engine_state", &"")).to_upper() == "OFFLINE":
			return true
		await physics_frame
		await process_frame
	return str(ship.get_telemetry().get("engine_state", &"")).to_upper() == "OFFLINE"


## Waits for `predicate` on a finite simulation-frame budget.
##
## Godot's smoothed engine delta and the physics clock can diverge on a busy
## machine because the engine drops physics steps rather than letting the
## simulation spiral. Every condition this slice used to sleep
## for — canopy closure and seating, engine spin-up, landing, the physical exit
## — is advanced by a frame callback, and a `SceneTree` timer measures neither
## the clock that advances them nor the monotonic one. It was observed firing
## both early and late relative to what it stood in for, so lengthening a sleep
## would not have helped.
##
## `nominal_seconds` is kept as the expected simulated duration and becomes a
## finite frame budget, so a genuinely stuck slice still fails. Both loops advance each
## iteration because some conditions settle in `_physics_process` and others in
## `_process`.
func _wait_until(predicate: Callable, nominal_seconds: float) -> bool:
	var frame_budget := (
		int(ceil(maxf(nominal_seconds, 0.0) * float(Engine.physics_ticks_per_second)))
		+ FRAME_BUDGET_GRACE
	)
	for _frame in frame_budget:
		if bool(predicate.call()):
			return true
		await physics_frame
		await process_frame
	return bool(predicate.call())


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
