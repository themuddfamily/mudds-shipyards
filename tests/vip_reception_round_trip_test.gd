extends SceneTree

## test-matrix-display: input-only
## test-matrix-timeout-seconds: 900
## STATION-VIP-CALLER: ordinary Boot/menu/input route; no rendered-pixel claims.
## Run in the matrix's isolated X11/dummy-renderer session with Dummy audio and
## an empty private profile. The independent outer supervisor owns the 900s cap.
## Each walking leg has a 40s cap and a 5s progress watchdog; boot has 60s,
## individual UI/interaction boundaries 5s. No retries or alternate routes.
## Observations below never write actor/camera poses or interaction candidates.

const SPAWN := Vector3(-8.5, 0.18, 11.0)
const SUITE_ORIGIN := Vector3(-5.15, 4.2, 70.6)
const ARRIVAL_METRES := 0.16
const ACTIONS := [&"ui_accept", &"move_forward", &"move_back", &"move_left", &"move_right", &"interact", &"sprint_boost", &"jump"]

var _boot: Node
var _game: GameFlow
var _player: PlayerController
var _door: StationDoor
var _seat: StationSeat
var _player_id := 0
var _spawn := Vector3.ZERO
var _leg := "boot"
var _failure := ""
var _deadline := 0
var _monitoring := false
var _previous_position := Vector3.ZERO
var _unsupported_seconds := 0.0
var _seat_transition := ""
var _seat_transition_deadline := 0
var _boarding_completions := 0
var _standing_completions := 0
var _initial_mouse_mode := Input.MOUSE_MODE_VISIBLE
var _forward_strength := 0.0
var _move_deadzone := 0.0
var _completed_legs := 0


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_initial_mouse_mode = Input.mouse_mode
	_deadline = Time.get_ticks_msec() + 900_000
	var boot_scene := load("res://scenes/boot.tscn") as PackedScene
	if boot_scene == null:
		_fail("production Boot resource unavailable")
	else:
		_boot = boot_scene.instantiate()
		_boot.connect(&"startup_completed", func(main: Node): _game = main as GameFlow)
		root.add_child(_boot)
		current_scene = _boot
		if await _wait(func(): return is_instance_valid(_game), 60.0, "production Boot startup_completed"):
			await _route()
	await _finish()


func _route() -> void:
	_leg = "initialized-main"
	_player = _game.get_node_or_null(^"Player") as PlayerController
	var spawn_marker := _game.get_node_or_null(^"ShipyardWorld/PlayerSpawn") as Node3D
	_door = _game.get_node_or_null(^"ShipyardWorld/AftJunctionStack/VIPAccess") as StationDoor
	_seat = _game.get_node_or_null(^"ShipyardWorld/VipReceptionSuite/Structure/Fitout/Armchair03/StationSeatInteraction") as StationSeat
	var suite := _game.get_node_or_null(^"ShipyardWorld/VipReceptionSuite") as Node3D
	if not _require(bool(_game.get("_initialized")) and _game.hud is GameHUD and _player != null
		and spawn_marker != null and _door != null and _seat != null and suite != null,
		"initialized Main, real HUD, player, authored spawn, VIP door and Armchair03 required"):
		return
	if not _require(spawn_marker.global_position.distance_to(SPAWN) < 0.001
		and suite.global_position.distance_to(SUITE_ORIGIN) < 0.001,
		"authored spawn/suite differs from shared ROADMAP route"):
		return
	if not _require(_horizontal(_player.global_position - SPAWN) <= 0.05
		and absf(_player.global_position.y - SPAWN.y) < 0.3,
		"fresh ordinary player must already occupy the authored spawn"):
		return
	if not _require(_game.phase == GameFlow.Phase.INTRO and _game.get_recovery_available_snapshot().is_empty(),
		"fresh profile must expose INTRO without interrupted-session recovery"):
		return
	_spawn = spawn_marker.global_position
	_player_id = _player.get_instance_id()
	_previous_position = _player.global_position
	_player.boarding_completed.connect(func(): _boarding_completions += 1)
	_player.disembarking_completed.connect(func(): _standing_completions += 1)
	_monitoring = true
	physics_frame.connect(_observe_player)
	for action in [&"move_left", &"move_right", &"move_forward", &"move_back"]:
		_move_deadzone += InputMap.action_get_deadzone(action)
	_move_deadzone /= 4.0
	if not _require(_move_deadzone >= 0.0 and _move_deadzone < 1.0, "movement deadzone must allow ordinary input"):
		return
	_leg = "begin-shift"
	if not await _button("IntroBeginShiftButton"):
		return
	if not await _wait(func(): return _game.phase == GameFlow.Phase.APPROACH_SHIP, 5.0, "Begin Shift enters on-foot phase"):
		return
	var dismiss := _game.hud.find_child("RuntimeStatusDismissButton", true, false) as Button
	if dismiss != null and dismiss.is_visible_in_tree() and not dismiss.disabled:
		_leg = "dismiss-runtime-status"
		if not await _activate(dismiss):
			return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		# A real click is the controller's ordinary mouse recapture seam.
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = root.size * 0.5
		click.pressed = true
		Input.parse_input_event(click)
		await process_frame
		click = InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = root.size * 0.5
		Input.parse_input_event(click)
		await process_frame
	if not _require(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "ordinary mouse click must capture playable look controls"):
		return
	if not await _wait(func(): return _player.is_on_floor(), 5.0, "spawn has real ground support"):
		return

	# World positions are source-derived navigation goals, never assigned poses.
	var outbound: Array[Dictionary] = [
		{"name": "central-x0", "point": Vector3(0, 0.15, 11)},
		{"name": "central-z30", "point": Vector3(0, 0.15, 30)},
		{"name": "aft-approach", "point": Vector3(0, 0.15, 46.3)},
		{"name": "lower-junction", "point": Vector3(0, 0.15, 55.2)},
		{"name": "stair-base", "point": Vector3(-5.7, 0.15, 51)},
		{"name": "stair-top", "point": Vector3(-5.7, 4.35, 60.8)},
		{"name": "upper-bypass-west", "point": Vector3(-4.6, 4.2, 63)},
		{"name": "upper-bypass-east", "point": Vector3(-3.6, 4.2, 63)},
		{"name": "upper-bypass-aft", "point": Vector3(-3.6, 4.2, 67)},
		{"name": "vip-approach", "point": Vector3(-5.15, 4.35, 68.9)},
	]
	for waypoint in outbound:
		if not await _walk("out/" + str(waypoint.name), waypoint.point):
			return
	_leg = "vip-door-open"
	if not _require(_door.get_state_name() == &"CLOSED" and _door.is_portal_blocked(), "fresh VIP door must be CLOSED with actual blocker"):
		return
	if not await _face(_door.global_position):
		return
	if not await _wait(func(): return _game.station_interaction_candidate == _door and _prompt_contains("OPEN"), 5.0,
		"ordinary VIP OPEN prompt/candidate"):
		return
	await _tap(&"interact")
	if not await _wait(func(): return _door.is_open() and not _door.is_portal_blocked(), 5.0,
		"actual VIP OPEN state and removed portal blocker before crossing"):
		return

	var inside: Array[Dictionary] = [
		{"name": "suite-threshold", "point": SUITE_ORIGIN + Vector3(0, 0.15, 1.5)},
		{"name": "reception", "point": SUITE_ORIGIN + Vector3(-1.3, 0.15, 4.6)},
		{"name": "front-plate-west", "point": SUITE_ORIGIN + Vector3(-1.3, 0.15, 5.5)},
		{"name": "front-plate-east", "point": SUITE_ORIGIN + Vector3(1.99, 0.15, 5.5)},
		{"name": "armchair03-entry", "point": SUITE_ORIGIN + Vector3(1.99, 0, 7.49)},
	]
	if not _require(_horizontal(_seat.get_entry_transform().origin - inside.back().point) < 0.04
		and str(_seat.get_meta("seat_label", "")) == "RECEPTION ARMCHAIR 03", "authored Armchair03 entry and identity match source route"):
		return
	for waypoint in inside:
		if not await _walk("in/" + str(waypoint.name), waypoint.point):
			return
	if not await _sit_and_stand():
		return

	# The same supported lanes, in reverse; no staged return or rescue.
	for index in range(inside.size() - 2, -1, -1):
		var waypoint := inside[index]
		if not await _walk("return/" + str(waypoint.name), waypoint.point):
			return
	for index in range(outbound.size() - 1, -1, -1):
		var waypoint := outbound[index]
		if not await _walk("return/" + str(waypoint.name), waypoint.point):
			return
	if not await _walk("return/original-spawn", _spawn):
		return
	# Prove controls still move this supported body, then walk back to spawn.
	var before := _player.global_position
	if not await _walk("return/controls-usable", _spawn + Vector3(0.75, 0, 0)):
		return
	if not _require(_horizontal(_player.global_position - before) >= 0.5, "ordinary movement must remain usable after return"):
		return
	if not await _walk("return/spawn-after-controls", _spawn):
		return
	_leg = "complete"
	_require(_completed_legs == 32 and _player.get_instance_id() == _player_id and _player.is_on_floor()
		and _horizontal(_player.global_position - _spawn) <= 0.5
		and absf(_player.global_position.y - _spawn.y) <= 0.25
		and not _player.is_seated() and _boarding_completions == 1 and _standing_completions == 1,
		"full route, same supported player on original central deck, exactly one SIT and STAND")


func _sit_and_stand() -> bool:
	_leg = "armchair03-sit"
	if not await _face(_seat.get_seat_anchor().global_position):
		return false
	if not await _wait(func(): return _game.station_interaction_candidate == _seat and _prompt_contains("SIT") and _prompt_contains("RECEPTION ARMCHAIR 03"), 5.0, "normal SIT prompt for RECEPTION ARMCHAIR 03"):
		return false
	_seat_transition = "sit"
	_seat_transition_deadline = Time.get_ticks_msec() + 5_000
	await _tap(&"interact")
	if not await _wait(func(): return _player.is_seated_at(_seat.get_seat_anchor()) and _player.is_station_seated() and _seat.is_reserved_for(_player) and _boarding_completions == 1 and _prompt_contains("STAND"), 5.0,
		"normal SIT completes in Armchair03 with STAND prompt"):
		return false
	_seat_transition = "seated"
	await physics_frame
	_leg = "armchair03-stand"
	_seat_transition = "stand"
	_seat_transition_deadline = Time.get_ticks_msec() + 5_000
	await _tap(&"interact")
	if not await _wait(func(): return not _player.is_seated() and not _seat.is_reserved_for(_player) and _standing_completions == 1 and _player.is_on_floor(), 5.0, "normal STAND completes with real floor support"):
		return false
	if not _require(_horizontal(_player.global_position - _seat.get_exit_transform().origin) <= 0.2
		and absf(_player.global_position.y - _seat.get_exit_transform().origin.y) <= 0.15,
		"STAND must use Armchair03's authored supported exit"):
		return false
	_seat_transition = ""
	return true


func _walk(name: String, target: Vector3) -> bool:
	_leg = name
	if not _failure.is_empty():
		return false
	print("VIP_ROUTE_LEG ", _leg, " target=", target)
	var limit := Time.get_ticks_msec() + 40_000
	var progress_limit := Time.get_ticks_msec() + 5_000
	var best := _horizontal(target - _player.global_position)
	while _failure.is_empty() and Time.get_ticks_msec() < limit:
		var offset := target - _player.global_position
		var distance := _horizontal(offset)
		var speed := _horizontal(_player.velocity)
		if distance <= ARRIVAL_METRES and speed <= 0.04:
			_set_forward(0.0)
			if not _require(absf(offset.y) <= 0.25 and _player.is_on_floor(), "waypoint must be reached on its actual supported deck"):
				return false
			_completed_legs += 1
			print("VIP_ROUTE_REACHED ", _leg, " position=", _player.global_position, " support=", _support_description())
			return true
		if distance < best - 0.08:
			best = distance
			progress_limit = Time.get_ticks_msec() + 5_000
		if Time.get_ticks_msec() >= progress_limit:
			_fail("walking stalled for 5s before target=%s distance=%.3f" % [target, distance])
			break
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			_fail("gameplay lost captured mouse/look input")
			break
		var yaw := atan2(-offset.x, -offset.z)
		var error := wrapf(yaw - _player.get_look_yaw(), -PI, PI)
		if distance > ARRIVAL_METRES:
			_mouse_yaw(error)
		# Input.get_vector applies the mean movement deadzone. Invert that
		# mapping so a slow approach remains live ordinary analog action input.
		var fraction := clampf(distance * 2.0 / maxf(_player.walk_speed, 0.1), 0.12, 1.0)
		var strength := _move_deadzone + (1.0 - _move_deadzone) * fraction
		_set_forward(strength if distance > ARRIVAL_METRES and absf(error) < 0.08 else 0.0)
		await physics_frame
	_set_forward(0.0)
	if _failure.is_empty():
		_fail("walking exceeded 40s before target=%s" % target)
	return false


func _face(target: Vector3) -> bool:
	_set_forward(0.0)
	var limit := Time.get_ticks_msec() + 5_000
	while _failure.is_empty() and Time.get_ticks_msec() < limit:
		var offset := target - _player.global_position
		var error := wrapf(atan2(-offset.x, -offset.z) - _player.get_look_yaw(), -PI, PI)
		if absf(error) < 0.03 and _horizontal(_player.velocity) < 0.04:
			return true
		if not _require(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "normal look requires captured mouse"):
			return false
		_mouse_yaw(error)
		await physics_frame
	if _failure.is_empty():
		_fail("ordinary mouse look failed to face interaction")
	return false


func _mouse_yaw(radians: float) -> void:
	if absf(radians) < 0.001:
		return
	var event := InputEventMouseMotion.new()
	event.relative = Vector2(-radians / _player.mouse_sensitivity, 0)
	event.screen_relative = event.relative
	Input.parse_input_event(event)


func _set_forward(strength: float) -> void:
	if is_equal_approx(_forward_strength, strength):
		return
	_forward_strength = strength
	_action(&"move_forward", strength > 0.0, strength)


func _action(action: StringName, pressed: bool, strength: float = 1.0) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	event.strength = strength if pressed else 0.0
	Input.parse_input_event(event)


func _tap(action: StringName) -> void:
	_action(action, true)
	await physics_frame
	await process_frame
	_action(action, false)
	await physics_frame
	await process_frame


func _button(node_name: String) -> bool:
	if not await _wait(func():
		var button := _game.hud.find_child(node_name, true, false) as Button
		return button != null and button.is_visible_in_tree() and not button.disabled,
		5.0, "visible enabled HUD action " + node_name):
		return false
	return await _activate(_game.hud.find_child(node_name, true, false) as Button)


func _activate(button: Button) -> bool:
	root.grab_focus()
	button.grab_focus()
	await process_frame
	if not _require(root.gui_get_focus_owner() == button, "actual HUD button must receive focus"):
		return false
	var activated := [false]
	button.pressed.connect(func(): activated[0] = true, CONNECT_ONE_SHOT)
	await _tap(&"ui_accept")
	return await _wait(func(): return activated[0], 5.0, "focused ui_accept activates actual HUD button")


func _prompt_contains(text: String) -> bool:
	# Read the rendered HUD control, rather than manufacturing a prompt from
	# the desired candidate. The HUD rewrites only the live binding glyph.
	var label := _game.hud.get("_interaction_label") as Label
	return label != null and label.is_visible_in_tree() and text in label.text


func _wait(predicate: Callable, seconds: float, description: String) -> bool:
	var limit := Time.get_ticks_msec() + int(seconds * 1000.0)
	while _failure.is_empty() and Time.get_ticks_msec() < limit:
		if bool(predicate.call()):
			return true
		if Time.get_ticks_msec() >= _deadline:
			_fail("internal 900s route deadline")
			return false
		await process_frame
	if _failure.is_empty():
		_fail("boundary timed out: " + description)
	return false


func _observe_player() -> void:
	# Runs at EVERY physics boundary, including menu, interaction and waiting
	# periods. Leg arrival alone could conceal a rescue in the middle of a walk.
	if not _monitoring or not _failure.is_empty():
		return
	if not is_instance_valid(_game) or not is_instance_valid(_player) \
		or _game.get_node_or_null(^"Player") != _player or _player.get_instance_id() != _player_id:
		_fail("original Main player identity/lifetime changed")
		return
	var position := _player.global_position
	var delta := _player.get_physics_process_delta_time()
	var displacement := position - _previous_position
	_previous_position = position
	var seat_motion := not _seat_transition.is_empty()
	if seat_motion:
		if not is_instance_valid(_seat) or _horizontal(position - _seat.get_entry_transform().origin) > 1.8:
			_fail("seat transition escaped the actual Armchair03 entry/anchor corridor")
			return
		if _seat_transition != "seated" and Time.get_ticks_msec() > _seat_transition_deadline:
			_fail("ordinary seat handoff exceeded 5s")
			return
	var horizontal_limit := (maxf(_player.walk_speed, 8.0) if seat_motion else _player.walk_speed) * delta + 0.08
	var on_stairs := position.x > -7.2 and position.x < -4.2 and position.z > 50.5 and position.z < 61.3
	var vertical_limit := (8.0 * delta + 0.08) if seat_motion else (absf(_player.velocity.y) * delta + 0.06)
	if on_stairs:
		vertical_limit += PlayerController.STEP_UP_MAX_HEIGHT
	if not position.is_finite() or _horizontal(displacement) > horizontal_limit or absf(displacement.y) > vertical_limit:
		_fail("movement discontinuity/rescue: displacement=%s limits=(%.3f,%.3f)" % [displacement, horizontal_limit, vertical_limit])
		return
	if not seat_motion:
		if _player.is_seated() or _player.collision_layer == 0 or _player.collision_mask == 0:
			_fail("walking lost normal on-foot collision/embodiment")
			return
		var supported := _player.is_on_floor() or not _support_hit().is_empty()
		_unsupported_seconds = 0.0 if supported else _unsupported_seconds + delta
		if _unsupported_seconds > (0.35 if on_stairs else 0.2):
			_fail("lost real ground/collision support for %.3fs" % _unsupported_seconds)
			return
	if Time.get_ticks_msec() >= _deadline:
		_fail("internal 900s route deadline")


func _support_hit() -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(_player.global_position + Vector3.UP * 0.12,
		_player.global_position - Vector3.UP * 0.36, PhysicsLayers.WORLD)
	query.exclude = [_player.get_rid()]
	return _player.get_world_3d().direct_space_state.intersect_ray(query)


func _support_description() -> String:
	var hit := _support_hit()
	var collider := hit.get("collider") as Node
	return str(collider.get_path()) if is_instance_valid(collider) else "none"


func _horizontal(vector: Vector3) -> float:
	return Vector2(vector.x, vector.z).length()


func _require(condition: bool, description: String) -> bool:
	if not condition:
		_fail(description)
	return condition and _failure.is_empty()


func _fail(description: String) -> void:
	if not _failure.is_empty():
		return
	var observation := ""
	if is_instance_valid(_player) and _player.is_inside_tree():
		var collisions: Array[String] = []
		for index in _player.get_slide_collision_count():
			var collision := _player.get_slide_collision(index)
			var collider := collision.get_collider() as Node
			collisions.append("%s normal=%s" % [str(collider.get_path()) if is_instance_valid(collider) else "none", collision.get_normal()])
		var candidate := _game.station_interaction_candidate if is_instance_valid(_game) else null
		observation = " position=%s velocity=%s floor=%s support=%s collisions=%s candidate=%s seat_motion=%s" % [
			_player.global_position, _player.velocity, _player.is_on_floor(), _support_description(), collisions,
			str(candidate.get_path()) if is_instance_valid(candidate) else "none", _seat_transition]
	if is_instance_valid(_door):
		observation += " VIP_state=%s portal_blocked=%s" % [_door.get_state_name(), _door.is_portal_blocked()]
	_failure = "VIP_RECEPTION_ROUND_TRIP_FAILED leg=%s: %s%s" % [_leg, description, observation]
	push_error(_failure)


func _finish() -> void:
	_monitoring = false
	if physics_frame.is_connected(_observe_player):
		physics_frame.disconnect(_observe_player)
	for action in ACTIONS:
		_action(action, false)
	_forward_strength = 0.0
	if is_instance_valid(_game):
		_game.release_mouse_capture()
	if is_instance_valid(_boot):
		_boot.queue_free() # Boot owns Main and joins its startup worker on exit.
	await process_frame
	await process_frame
	Input.mouse_mode = _initial_mouse_mode
	if _failure.is_empty() and _leg == "complete" and _completed_legs == 32:
		print("VIP_RECEPTION_ROUND_TRIP_OK")
		quit(0)
	else:
		if _failure.is_empty():
			_fail("route returned without full completion")
		quit(1)
