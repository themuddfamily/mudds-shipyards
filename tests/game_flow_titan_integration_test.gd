extends SceneTree

const ROUTE := preload("res://tests/titan_transport_berth_test.gd").ROUTE
const OLD_TRANSFORMS := preload("res://tests/station_route_registry_integration_test.gd").EXPECTED_BERTH_TRANSFORMS
var _failures: Array[String] = []
var _frames := 0
var _supported := 0
var _clear := 0
var _game: GameFlow
var _ship: HeroShip
var _player: PlayerController
var _engine_edges: Array[Dictionary] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var boot := (load("res://scenes/boot.tscn") as PackedScene).instantiate() as StartupLoader
	root.add_child(boot)
	_game = await boot.startup_completed as GameFlow
	await _wait_frames(3)
	_check(StartupLoader.is_title_menu_ready(_game), "ordinary Boot reaches Begin Shift")
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_X
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await _wait_frames(2)
	event = InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_X
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await _wait_frames(45)
	_player = _game.player
	_ship = _game.get_node("TitanMediumTransport") as HeroShip
	_ship.engine_state_changed.connect(_on_engine_edge)
	var identity := _player.get_instance_id()
	var world := _game.world
	var berth := world.get_berth_node(&"titan_home_berth") as ShipBerth
	var dock := berth.get_dock_transform()
	_check(_game.phase == GameFlow.Phase.APPROACH_SHIP and _player.is_control_enabled()
		and _player.global_position.distance_to(world.get_player_spawn().origin) < 0.25,
		"normal Begin Shift keeps actual Player at ordinary spawn")
	_check(_game.get_flyable_ships().size() == 10 and berth.get_occupant() == _ship
		and berth.get_reservation_owner() == _ship, "one real Titan joins fleet with own occupied lease")
	var old_unchanged := true
	for id in OLD_TRANSFORMS:
		old_unchanged = old_unchanged and world.get_berth_transform(id).is_equal_approx(OLD_TRANSFORMS[id])
	_check(old_unchanged, "all original nine berth transforms remain unchanged")
	for index in ROUTE.size():
		if not await _walk_to(ROUTE[index], index):
			await _fail_exit("production station route failed")
			return
	var hatch := _ship.get_node("TitanOriginalShell/CabinHatchInteraction") as ShipCabinHatch
	await _aim(hatch.global_position)
	await _tap(&"interact")
	await _wait_frames(30)
	_check(_ship.is_canopy_open(), "normal E at physical stern control opens actual hatch/ramp")
	# Follow the supported apron around the moving leaves, up both leaves and
	# along the actual cabin aisle. No pose/velocity writes or board-method calls.
	var local_route := [Vector3(1.9, 0, 14.5), Vector3(0, 0, 14.5),
		Vector3(0, 0, 13), Vector3(0, 0.4, 10.5), Vector3(0, 0.8, 8),
		Vector3(0, 0.8, 6.5), Vector3(0, 0.8, -4.2)]
	for point in local_route:
		if not await _walk_to(_ship.to_global(point), 30):
			await _fail_exit("physical stern/cabin walk failed")
			return
	await _tap(&"interact")
	for frame in 240:
		if _game._piloting and not _game._transition_busy: break
		await _wait_frames(1)
	var area := _ship.get_node("ShipBoardingArea") as ShipBoardingArea
	_check(_game.active_ship == _ship and _game._piloting and not _game._transition_busy
		and _player.is_seated_at(_ship.get_pilot_seat_anchor())
		and area.get_reservation_token() == _player and _player.get_instance_id() == identity,
		"normal helm interaction completes actual pilot anchor/reservation with same Player")
	_check(not _ship.is_canopy_open(), "pilot boarding seals physical access")
	if not _failures.is_empty():
		await _fail_exit("boarding contract failed")
		return
	_check(_hull_leg_clear(Vector3.UP * 5), "whole real hull clears 5m departure leg")
	_engine_edges.clear()
	Input.action_press(&"move_forward")
	for frame in 500:
		var telemetry := _ship.get_telemetry()
		if not bool(telemetry.landed) and not _ship._departure_lift_active: break
		await _wait_frames(1)
	_release_inputs()
	var starting_ticks := -1
	var exact_timer := false
	if _engine_edges.size() == 2 and _engine_edges[0].state == HeroShip.ENGINE_STARTING \
			and _engine_edges[1].state == HeroShip.ENGINE_ONLINE:
		starting_ticks = int(_engine_edges[1].tick) - int(_engine_edges[0].tick)
		exact_timer = is_equal_approx(float(_engine_edges[0].remaining), 3.4) and is_zero_approx(float(_engine_edges[1].remaining))
	_check(exact_timer and starting_ticks >= 203 and starting_ticks <= 205,
		"normal thrust runs real 3.4s inherited engine clock: %d actual physics ticks, edges=%s" % [starting_ticks, _engine_edges])
	_check(StringName(_ship.get_telemetry().engine_state) == HeroShip.ENGINE_ONLINE,
		"completed timed startup reaches actual ONLINE propulsion")
	_check((_ship.global_position - dock.origin).dot(dock.basis.y) >= 4.99
		and berth.get_occupant() == null and berth.get_reservation_owner() == null,
		"actual five metre departure lift releases own lease")
	var target := dock * Vector3(0, 10, -31.2)
	_check(_hull_leg_clear(target - _ship.global_position), "whole real hull clears commanded flight leg")
	var arrived := false
	for frame in 1800:
		var offset := target - _ship.global_position
		var distance := offset.length()
		_release_inputs()
		if distance < 0.6 and _ship.velocity.length() <= 0.35:
			arrived = true
			break
		var local_direction := _ship.global_basis.inverse() * offset.normalized()
		var pitch_error := atan2(local_direction.y, -local_direction.z)
		if absf(pitch_error) > 0.003:
			Input.action_press(&"pitch_up" if pitch_error > 0 else &"pitch_down", clampf(absf(pitch_error) * 3, 0.08, 1))
		var desired_speed := minf(6.0, distance * 0.9)
		if _ship.velocity.length() > desired_speed + 0.1:
			Input.action_press(&"brake")
		elif distance > 0.45:
			Input.action_press(&"move_forward", clampf((desired_speed - _ship.velocity.length()) * 0.3 + 0.13, 0.12, 0.8))
		await _wait_frames(1)
		if frame % 180 == 0: print("TITAN_FLIGHT: frame=", frame, " local=", dock.affine_inverse() * _ship.global_position, " speed=", _ship.velocity.length(), " distance=", distance)
	_release_inputs()
	var local_flight := dock.affine_inverse() * _ship.global_position
	_check(arrived and _game.phase == GameFlow.Phase.FREE_FLIGHT
		and local_flight.distance_to(Vector3(0, 10, -30)) <= 2
		and -local_flight.z >= 30 and _ship.velocity.length() <= 0.5
		and not berth.contains_oriented_bounds(_ship.global_transform, _ship.get_landing_collision_report().local_bounds)
		and is_equal_approx(_ship.get_telemetry().hull, 220),
		"actual healthy FREE_FLIGHT reaches frozen home-local goal: %s speed=%s" % [local_flight, _ship.velocity.length()])
	if not _failures.is_empty():
		await _fail_exit("flight endpoint failed")
		return
	var capture := _game._get_active_landing_assist_report()
	print("TITAN_CAPTURE_BEFORE_L: ", capture)
	_check(bool(capture.get("assist_capture_accepted", false))
		and StringName(capture.get("selected_berth_id", &"")) == &"titan_home_berth",
		"unchanged real capture gate accepts own berth before normal L")
	await _tap(&"landing_assist")
	for frame in 600:
		if _game.phase == GameFlow.Phase.SHUT_DOWN: break
		await _wait_frames(1)
	_check(_game.phase == GameFlow.Phase.SHUT_DOWN and berth.get_occupant() == _ship
		and berth.get_reservation_owner() == _ship and _ship.global_position.distance_to(dock.origin) <= 0.05
		and _ship.velocity.length() <= 0.05 and _ship.global_basis.is_equal_approx(dock.basis), "normal L restores exact own occupied dock lease")
	await _wait_frames(90)
	_check(StringName(_ship.get_telemetry().engine_state) == HeroShip.ENGINE_OFFLINE
		and _ship.global_position.distance_to(dock.origin) <= 0.05 and _ship.velocity.length() <= 0.05,
		"ninety neutral physics ticks retain stable OFFLINE dock")
	await _tap(&"interact")
	for frame in 180:
		if not _game._transition_busy and not _player.is_seated(): break
		await _wait_frames(1)
	_check(not _player.is_seated() and _player.get_instance_id() == identity
		and not area.is_reserved() and not _game._piloting, "normal E returns same Player to landed cabin and releases helm")
	for point in [Vector3(0, 0.8, 6.5), Vector3(1.4, 0.8, 7.1)]:
		if not await _walk_to(_ship.to_global(point), 40):
			await _fail_exit("return cabin walk failed")
			return
	await _aim(hatch.global_position)
	await _tap(&"interact")
	await _wait_frames(30)
	_check(_ship.is_canopy_open(), "normal cabin hatch control opens supported exit")
	for point in [Vector3(0, 0.8, 7.1), Vector3(0, 0.8, 8), Vector3(0, 0.4, 10.5),
		Vector3(0, 0, 13), Vector3(0, 0, 14.5)]:
		if not await _walk_to(_ship.to_global(point), 50):
			await _fail_exit("physical ramp exit failed")
			return
	_check(_frames > 1000 and _supported == _frames and _clear == _frames,
		"all %d actual walking samples supported/capsule-clear (%d/%d)" % [_frames, _supported, _clear])
	_check(_player.get_instance_id() == identity and _player.is_on_floor()
		and _ship.to_local(_player.global_position).distance_to(Vector3(0, 0, 14.5)) < 0.08,
		"same Player walks at least 1m exterior to supported real exit endpoint")
	if not _failures.is_empty():
		await _fail_exit("final walking contract failed")
		return
	_release_inputs()
	await _key(KEY_ESCAPE)
	var exit_button := _game.hud.find_child("ExitButton", true, false) as Control
	for frame in 160:
		if root.gui_get_focus_owner() == exit_button: break
		await _key(KEY_TAB)
	_check(is_instance_valid(exit_button) and root.gui_get_focus_owner() == exit_button, "normal pause Tab reaches Exit to desktop")
	if not _failures.is_empty():
		await _fail_exit("normal Quit focus failed")
		return
	print("TITAN_USER_DATA_DIR: ", OS.get_user_data_dir())
	print("GAME_FLOW_TITAN_INTEGRATION_TEST_PASS")
	await _key(KEY_ENTER)
	for frame in 120: await process_frame
	await _fail_exit("normal Main Quit did not terminate OS process")

func _on_engine_edge(state: StringName) -> void:
	_engine_edges.append({"state": state, "tick": Engine.get_physics_frames(), "remaining": _ship.get("_engine_timer")})

func _hull_leg_clear(motion: Vector3) -> bool:
	var support := _game.world.get_node("TitanTransportBerth/BerthDeck") as StaticBody3D
	for node in _ship.find_children("*", "CollisionShape3D", true, false):
		var collision := node as CollisionShape3D
		if collision.disabled or not collision.get_parent() is PhysicsBody3D: continue
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = collision.shape
		query.transform = collision.global_transform
		query.motion = motion
		query.collision_mask = PhysicsLayers.WORLD | PhysicsLayers.SHIP
		query.margin = 0
		query.exclude = [_ship.get_rid(), support.get_rid()]
		var result := _ship.get_world_3d().direct_space_state.cast_motion(query)
		if result[0] < 1 or result[1] < 1:
			print("TITAN_BLOCKED_LEG: ", collision.name, " motion=", motion, " fractions=", result)
			return false
	return true

func _aim(target: Vector3) -> void:
	# Right-stick events work through the real on-foot look sampler even on a
	# headless display, where mouse capture has no operating-system surface.
	for frame in 180:
		var direction := (target - _player.get_interaction_origin()).slide(Vector3.UP).normalized()
		var forward := _player.get_interaction_direction().slide(Vector3.UP).normalized()
		var angle := forward.signed_angle_to(direction, Vector3.UP)
		if absf(angle) < 0.03: break
		var motion := InputEventJoypadMotion.new()
		motion.axis = JOY_AXIS_RIGHT_X
		motion.axis_value = -signf(angle) * (0.4 if absf(angle) < 0.25 else 1.0)
		Input.parse_input_event(motion)
		Input.flush_buffered_events()
		await _wait_frames(1)
	var release := InputEventJoypadMotion.new()
	release.axis = JOY_AXIS_RIGHT_X
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	await _wait_frames(2)
	print("TITAN_AIM: direction=", _player.get_interaction_direction(), " target=", target, " origin=", _player.get_interaction_origin(), " selected=", _game.station_interaction_candidate)

func _walk_to(target: Vector3, index: int) -> bool:
	var reached := false
	for frame in 900:
		var offset := (target - _player.global_position).slide(Vector3.UP)
		if absf(offset.x) < 0.02: offset.x = 0
		if absf(offset.z) < 0.02: offset.z = 0
		if offset.length() < 0.035:
			reached = true
			break
		var direction := (_player.get_node("%CameraYaw") as Node3D).global_basis.inverse() * offset.normalized()
		_release_inputs()
		var strength := 0.4 if offset.length() < 0.8 else 1.0
		Input.action_press(&"move_right" if direction.x > 0 else &"move_left", absf(direction.x) * strength)
		Input.action_press(&"move_back" if direction.z > 0 else &"move_forward", absf(direction.z) * strength)
		await _wait_frames(1)
		_observe()
	_release_inputs()
	for frame in 12:
		await _wait_frames(1)
		_observe()
	print("TITAN_WALK: leg=", index, " target=", target, " actual=", _player.global_position, " reached=", reached)
	return reached

func _observe() -> void:
	_frames += 1
	if _player.is_on_floor(): _supported += 1
	var collision := _player.get_node("PlayerCollision") as CollisionShape3D
	var capsule := collision.shape.duplicate() as CapsuleShape3D
	capsule.radius -= 0.005
	capsule.height -= 0.01
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = collision.global_transform
	query.margin = 0
	query.collision_mask = PhysicsLayers.WORLD | PhysicsLayers.SHIP
	query.exclude = [_player.get_rid()]
	var hits := _player.get_world_3d().direct_space_state.intersect_shape(query, 8)
	if hits.is_empty(): _clear += 1
	elif _clear == _frames - 1: print("TITAN_CAPSULE_FIRST_HIT: pose=", _player.global_position, " hits=", hits)

func _tap(action: StringName) -> void:
	if action == &"interact" or action == &"landing_assist":
		await _key(KEY_E if action == &"interact" else KEY_L)
		return
	Input.action_press(action)
	await _wait_frames(2)
	Input.action_release(action)
	await _wait_frames(2)

func _key(key: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await physics_frame
		await process_frame

func _release_inputs() -> void:
	for action in [&"move_forward", &"move_back", &"move_left", &"move_right", &"pitch_up", &"pitch_down", &"brake", &"sprint_boost", &"interact", &"landing_assist"]:
		Input.action_release(action)

func _wait_frames(count: int) -> void:
	for frame in count:
		await physics_frame
		await process_frame

func _check(condition: bool, message: String) -> void:
	print("PASS: " if condition else "FAIL: ", message)
	if not condition: _failures.append(message)

func _fail_exit(message: String) -> void:
	_check(false, message)
	_release_inputs()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_game.queue_free()
	await _wait_frames(3)
	quit(1)
