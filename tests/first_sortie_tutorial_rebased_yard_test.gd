extends SceneTree

## Flies the pending guided first sortie on production Main after the common
## world origin has been left offset by a planetary return, with real controller
## input. Flight manoeuvres reuse controller_physical_sortie_test's
## controller-state provider and guidance helpers.

const MAIN_SCENE := preload("res://scenes/main.tscn")

const AXIS_LEFT_X := 0
const AXIS_LEFT_Y := 1
const AXIS_RIGHT_X := 2
const AXIS_RIGHT_Y := 3
const AXIS_LEFT_TRIGGER := 4
const AXIS_RIGHT_TRIGGER := 5

const BUTTON_A := 0
const BUTTON_X := 2
const BUTTON_Y := 3
const BUTTON_BACK := 4
const BUTTON_START := 6
const BUTTON_LEFT_STICK := 7
const BUTTON_RIGHT_SHOULDER := 10
const BUTTON_DPAD_LEFT := 13

const WALK_TRAVEL_SECONDS := 5.0
const FLIGHT_TRAVEL_SECONDS := 14.0
const FRAME_BUDGET_GRACE := 30

var _failures := PackedStringArray()
var _assertions := 0


class ControllerStateProvider:
	extends RefCounted

	var buttons: Dictionary = {}
	var axes: Dictionary = {}

	func set_button(button_index: int, pressed: bool) -> void:
		buttons[button_index] = pressed

	func set_axis(axis_index: int, value: float) -> void:
		axes[axis_index] = clampf(value, -1.0, 1.0)

	func release_all() -> void:
		buttons.clear()
		axes.clear()

	func get_action_strength(action: StringName) -> float:
		if not InputMap.has_action(action):
			return 0.0
		var strength := 0.0
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventJoypadButton:
				var button := event as InputEventJoypadButton
				if bool(buttons.get(button.button_index, false)):
					strength = 1.0
			elif event is InputEventJoypadMotion:
				var motion := event as InputEventJoypadMotion
				var actual := float(axes.get(motion.axis, 0.0))
				if signf(actual) == signf(motion.axis_value):
					strength = maxf(strength, absf(actual))
		return strength

	func is_action_pressed(action: StringName) -> bool:
		return (
			InputMap.has_action(action)
			and get_action_strength(action) > InputMap.action_get_deadzone(action)
		)


func _init() -> void:
	call_deferred("_run")


## The first-sortie card the HUD is holding right now, or an empty step when
## none is attached.
func _card(game: GameFlow) -> StringName:
	var presenter: RefCounted = game.hud.get("_first_sortie_tutorial_presenter")
	var snapshot := presenter.call(&"get_snapshot") as Dictionary
	if snapshot.is_empty() or not bool(snapshot.get("attached", false)):
		return &""
	return StringName(snapshot.get("step_id", &""))


## The common-world floating origin is left where the last planetary return put
## it: a real Aurora round trip (aurora_visit_loop_test's abandon path) ends
## with ShipyardWorld at this offset from Main's origin. The guided first
## sortie is still pending afterwards, so its launch threshold and interceptor
## spawn must follow the yard rather than the original world origin.
const AURORA_RETURN_RESIDUAL := Vector3(-31.0, -4.203125, -48.5)
const GUIDED_ENEMY_SPAWN_IN_YARD := Vector3(24.0, 12.0, -148.0)


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	root.add_child(game)
	await process_frame
	await physics_frame
	var player := game.get_node_or_null("Player") as PlayerController
	var torrent := game.get_node_or_null("TorrentInterceptor") as HeroShip
	var world := game.get_node_or_null("ShipyardWorld") as ShipyardWorld
	var opponent := game.get_node_or_null("RangeOpponent") as RangeOpponent
	var owner := game.common_world_origin_rebase_owner
	if player == null or torrent == null or world == null or opponent == null or owner == null:
		_check(false, "production Main composes player, Torrent, world, opponent and origin owner")
		await _clean_up(game, null)
		_finish()
		return
	# Translate every common-world root exactly as the origin owner's committed
	# transaction does, including the physics-server transforms.
	var roster := owner.call(&"_capture_live_roster") as Dictionary
	_check(
		bool(owner.call(&"_apply_root_translation", roster.roots, AURORA_RETURN_RESIDUAL))
			and bool(owner.call(&"_synchronize_collision_transforms", roster.covered))
			and world.global_position.is_equal_approx(AURORA_RETURN_RESIDUAL),
		"the yard sits at the residual a real Aurora return leaves"
	)
	for _settle in 4:
		await physics_frame
		await process_frame
	game.canopy_motion_time = 0.0
	game.boarding_motion_time = 0.08
	torrent.weapon_cooldown = 0.06
	torrent.maximum_speed = 70.0
	torrent.thrust_acceleration = 72.0
	torrent.brake_acceleration = 80.0
	torrent.passive_drag = 8.0
	torrent.throttle_response = 30.0
	torrent.yaw_speed_degrees = 180.0
	torrent.flight_assist_strength = 12.0
	var yard := world.global_transform
	var parked := torrent.global_transform

	await _tap_physical_joy_button(BUTTON_X)
	await _wait_until(func() -> bool: return game.phase == GameFlow.Phase.APPROACH_SHIP, 0.5)
	_check(await _walk_player_to_ship(player, torrent, game), "left stick walks to the Torrent")
	await _tap_physical_joy_button(BUTTON_X)
	_check(
		await _wait_until(func() -> bool: return game.phase == GameFlow.Phase.START_ENGINES, 1.2),
		"controller X boards and seats the pilot"
	)
	var source := torrent.get_command_source() as LocalShipInputSource
	var provider := ControllerStateProvider.new()
	source.set_input_provider(provider, LocalShipInputSource.INPUT_PROVIDER_INPUT_MAP_RESOLVED)
	provider.set_axis(AXIS_LEFT_Y, -1.0)
	await _wait_until(func() -> bool: return game.phase == GameFlow.Phase.LAUNCH, 1.6)
	provider.set_axis(AXIS_LEFT_Y, 0.0)
	await _brake_ship(torrent, provider, 0.3, 1.0)
	_check(
		game.phase == GameFlow.Phase.LAUNCH and _card(game) == &"launch"
			and torrent.global_position.distance_to(parked.origin) < 20.0,
		"a craft still inside the bay keeps the launch step (%s, %s, %.1f m out)"
			% [GameFlow.Phase.keys()[game.phase], _card(game),
				torrent.global_position.distance_to(parked.origin)]
	)
	# Halfway to the -66 m launch aperture: still inside the bay.
	await _fly_to_waypoint(torrent, provider, yard * Vector3(0.0, 8.0, -36.0), 3.0)
	await _brake_ship(torrent, provider, 0.8, 2.0)
	var bay_z := (yard.affine_inverse() * torrent.global_position).z
	_check(
		game.phase == GameFlow.Phase.LAUNCH and _card(game) == &"launch"
			and bay_z > -50.0 and torrent.global_position.distance_to(parked.origin) < 70.0,
		"the range stays closed until the yard's launch aperture (%s, %s at yard z %.1f)"
			% [GameFlow.Phase.keys()[game.phase], _card(game), bay_z]
	)
	await _fly_to_waypoint(torrent, provider, yard * Vector3(0.0, 8.0, -78.0), 5.0)
	await _brake_ship(torrent, provider, 0.8, 2.0)
	_check(
		game.phase == GameFlow.Phase.TARGET_PRACTICE and _card(game) == &"fire",
		"clearing the yard's launch aperture opens the range (%s)" % _card(game)
	)
	var target_nodes := get_nodes_in_group("shipyard_targets")
	target_nodes.sort_custom(func(first: Node, second: Node) -> bool:
		return str(first.name) < str(second.name)
	)
	for target_value: Node in target_nodes:
		var target := target_value as Node3D
		await _aim_and_fire_until_removed(torrent, provider, target, func() -> bool:
			return not is_instance_valid(target) or bool(target.get_meta("destroyed", false)), 2.5)
	_check(
		game.phase == GameFlow.Phase.INTERCEPTOR_ENGAGEMENT and opponent.is_active(),
		"clearing the range launches the defence interceptor"
	)
	var spawn_in_yard := yard.affine_inverse() * opponent.global_position
	_check(
		opponent.is_active()
			and spawn_in_yard.distance_to(GUIDED_ENEMY_SPAWN_IN_YARD) < 20.0,
		"the interceptor enters from the yard's authored spawn (at %s in yard space)" % spawn_in_yard
	)
	await _clean_up(game, provider)
	_finish()


func _walk_player_to_ship(
	player: PlayerController,
	ship: HeroShip,
	game: GameFlow
	) -> bool:
	var frame_budget := _frame_budget(WALK_TRAVEL_SECONDS)
	var frames := 0
	_set_physical_joy_button(BUTTON_LEFT_STICK, true)
	while frames < frame_budget:
		frames += 1
		var offset := ship.get_boarding_position() - player.get_interaction_origin()
		var flat_offset := offset.slide(Vector3.UP)
		if flat_offset.length() <= 3.1:
			break
		var desired := flat_offset.normalized()
		var camera_yaw := player.get_node_or_null("CameraYaw") as Node3D
		var reference_basis := camera_yaw.global_basis if camera_yaw != null else player.global_basis
		var forward := (-reference_basis.z).slide(Vector3.UP).normalized()
		var right := forward.cross(Vector3.UP).normalized()
		_set_physical_joy_axis(AXIS_LEFT_X, clampf(desired.dot(right), -1.0, 1.0))
		_set_physical_joy_axis(AXIS_LEFT_Y, clampf(-desired.dot(forward), -1.0, 1.0))
		# Advance exactly one simulation step per steering update. `PlayerController`
		# integrates locomotion in `_physics_process`, so also awaiting an idle frame
		# here would let a load-dependent number of physics steps run against stale
		# stick values and make the walked path itself a function of machine load.
		await physics_frame
	_release_physical_joypad()
	for _settle in 4:
		await physics_frame
		await process_frame
	return game.boarding_candidate == ship


func _fly_to_waypoint(
	ship: HeroShip,
	provider: ControllerStateProvider,
	waypoint: Vector3,
	arrival_radius: float
	) -> bool:
	var frame_budget := _frame_budget(FLIGHT_TRAVEL_SECONDS)
	var frames := 0
	while frames < frame_budget:
		frames += 1
		var offset := waypoint - ship.global_position
		var distance := offset.length()
		if distance <= arrival_radius:
			_neutralize_flight_axes(provider)
			return true
		var desired := offset.normalized()
		var local_desired := ship.global_basis.orthonormalized().inverse() * desired
		var alignment := (-ship.global_basis.z.normalized()).dot(desired)
		var stopping_distance := ship.velocity.length_squared() / maxf(2.0 * ship.brake_acceleration, 1.0)
		var should_brake := distance < stopping_distance + arrival_radius + 0.75
		if ship.velocity.length() < 1.0 and distance > arrival_radius:
			should_brake = false
		var throttle := 1.0 if alignment > 0.72 and not should_brake else 0.0
		provider.set_axis(AXIS_LEFT_X, clampf(local_desired.x * 3.4, -1.0, 1.0))
		provider.set_axis(AXIS_LEFT_Y, -throttle)
		provider.set_axis(AXIS_RIGHT_X, 0.0)
		provider.set_axis(AXIS_RIGHT_Y, -clampf(local_desired.y * 3.4, -1.0, 1.0))
		provider.set_axis(AXIS_LEFT_TRIGGER, 1.0 if should_brake else 0.0)
		provider.set_axis(AXIS_RIGHT_TRIGGER, 0.0)
		# Advance exactly one simulation step per guidance update. `HeroShip` samples
		# one immutable command per `_physics_process` tick, so awaiting an idle frame
		# as well would run a load-dependent number of ticks against stale axes and
		# make the flown trajectory — and therefore the arrival pose — a function of
		# machine load rather than of the controller behaviour under test.
		await physics_frame
	_neutralize_flight_axes(provider)
	return ship.global_position.distance_to(waypoint) <= arrival_radius


func _brake_ship(
	ship: HeroShip,
	provider: ControllerStateProvider,
	maximum_speed: float,
	nominal_seconds: float
	) -> bool:
	_neutralize_flight_axes(provider)
	provider.set_axis(AXIS_LEFT_TRIGGER, 1.0)
	var stopped := await _wait_until(
		func() -> bool: return ship.velocity.length() <= maximum_speed,
		nominal_seconds
	)
	provider.set_axis(AXIS_LEFT_TRIGGER, 0.0)
	await physics_frame
	return stopped


func _align_ship(
	ship: HeroShip,
	provider: ControllerStateProvider,
	desired_direction: Vector3,
	minimum_dot: float,
	nominal_seconds: float
	) -> bool:
	var direction := desired_direction.normalized()
	var frame_budget := _frame_budget(nominal_seconds)
	var frames := 0
	provider.set_button(BUTTON_A, true)
	while frames < frame_budget:
		frames += 1
		var forward := -ship.global_basis.z.normalized()
		if forward.dot(direction) >= minimum_dot and ship.global_basis.y.dot(Vector3.UP) > 0.94:
			_neutralize_flight_axes(provider)
			provider.set_button(BUTTON_A, false)
			await physics_frame
			return true
		var local_desired := ship.global_basis.orthonormalized().inverse() * direction
		provider.set_axis(AXIS_LEFT_X, clampf(local_desired.x * 3.8, -1.0, 1.0))
		provider.set_axis(AXIS_LEFT_Y, 0.0)
		provider.set_axis(AXIS_RIGHT_X, 0.0)
		provider.set_axis(AXIS_RIGHT_Y, -clampf(local_desired.y * 3.8, -1.0, 1.0))
		provider.set_axis(AXIS_LEFT_TRIGGER, 1.0)
		provider.set_axis(AXIS_RIGHT_TRIGGER, 0.0)
		# One simulation step per attitude update, for the reason given on
		# [method _fly_to_waypoint]: the achieved heading must not depend on how many
		# physics ticks the engine happened to fit inside an idle frame.
		await physics_frame
	_neutralize_flight_axes(provider)
	provider.set_button(BUTTON_A, false)
	await physics_frame
	return (
		(-ship.global_basis.z.normalized()).dot(direction) >= minimum_dot
		and ship.global_basis.y.dot(Vector3.UP) > 0.94
	)


func _aim_and_fire_until_removed(
	ship: HeroShip,
	provider: ControllerStateProvider,
	target: Node3D,
	completion: Callable,
	nominal_seconds: float
	) -> bool:
	var frame_budget := _frame_budget(nominal_seconds)
	var frames := 0
	while frames < frame_budget and not bool(completion.call()):
		frames += 1
		if not is_instance_valid(target):
			break
		var aiming_origin := ship.get_camera().global_position
		var offset := target.global_position - aiming_origin
		if offset.length_squared() <= 0.001:
			break
		var desired := offset.normalized()
		var local_desired := ship.global_basis.orthonormalized().inverse() * desired
		var alignment := (-ship.global_basis.z.normalized()).dot(desired)
		provider.set_axis(AXIS_LEFT_X, clampf(local_desired.x * 4.2, -1.0, 1.0))
		provider.set_axis(AXIS_LEFT_Y, 0.0)
		provider.set_axis(AXIS_RIGHT_X, 0.0)
		provider.set_axis(AXIS_RIGHT_Y, -clampf(local_desired.y * 4.2, -1.0, 1.0))
		provider.set_axis(AXIS_LEFT_TRIGGER, 1.0)
		provider.set_axis(AXIS_RIGHT_TRIGGER, 1.0 if alignment >= 0.997 else 0.0)
		# One simulation step per aim/fire update, for the reason given on
		# [method _fly_to_waypoint]. The firing gate reads `alignment` sampled on this
		# same tick, so an idle await here would fire against a stale alignment.
		await physics_frame
	_neutralize_flight_axes(provider)
	return bool(completion.call())


func _neutralize_flight_axes(provider: ControllerStateProvider) -> void:
	for axis in [
		AXIS_LEFT_X,
		AXIS_LEFT_Y,
		AXIS_RIGHT_X,
		AXIS_RIGHT_Y,
		AXIS_LEFT_TRIGGER,
		AXIS_RIGHT_TRIGGER,
	]:
		provider.set_axis(axis, 0.0)


func _tap_provider_button(provider: ControllerStateProvider, button_index: int) -> void:
	provider.set_button(button_index, true)
	await physics_frame
	await process_frame
	provider.set_button(button_index, false)
	await physics_frame
	await process_frame


func _tap_physical_joy_button(button_index: int) -> void:
	_set_physical_joy_button(button_index, true)
	await physics_frame
	await process_frame
	_set_physical_joy_button(button_index, false)
	await physics_frame
	await process_frame


func _set_physical_joy_axis(axis_index: int, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = 0
	event.axis = axis_index
	event.axis_value = clampf(value, -1.0, 1.0)
	Input.parse_input_event(event)


func _set_physical_joy_button(button_index: int, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button_index
	event.pressed = pressed
	Input.parse_input_event(event)


func _release_physical_joypad() -> void:
	for axis in [AXIS_LEFT_X, AXIS_LEFT_Y, AXIS_RIGHT_X, AXIS_RIGHT_Y, AXIS_LEFT_TRIGGER, AXIS_RIGHT_TRIGGER]:
		_set_physical_joy_axis(axis, 0.0)
	for button in [
		BUTTON_A,
		BUTTON_X,
		BUTTON_Y,
		BUTTON_BACK,
		BUTTON_START,
		BUTTON_LEFT_STICK,
		BUTTON_RIGHT_SHOULDER,
		BUTTON_DPAD_LEFT,
	]:
		_set_physical_joy_button(button, false)


## Frames a nominal duration of simulated time is worth at the project's configured
## physics tick rate, plus a fixed frame grace.
##
## Every loop in this suite drives the production controller stack and then waits
## for the result, and every one of those results — avatar locomotion, craft
## translation and rotation, weapon cooldowns, phase transitions — is integrated in
## `_physics_process`. Under load Godot drops physics steps to avoid a spiral of
## death while the wall clock keeps running, so a `Time.get_ticks_msec()` deadline
## ends a loop after far fewer simulated steps than the manoeuvre needs and scores
## a perfectly healthy sortie as a failure. Counting frames grants the same amount
## of simulation however busy the box is, and still fails a genuinely stuck
## manoeuvre because the budget remains finite.
func _frame_budget(seconds: float) -> int:
	var required := int(ceil(maxf(seconds, 0.0) * float(Engine.physics_ticks_per_second)))
	return maxi(required, 1) + FRAME_BUDGET_GRACE


func _wait_until(predicate: Callable, nominal_seconds: float) -> bool:
	var frame_budget := _frame_budget(nominal_seconds)
	var frames := 0
	while frames < frame_budget:
		if bool(predicate.call()):
			return true
		await physics_frame
		await process_frame
		frames += 1
	return bool(predicate.call())


func _clean_up(game: Node, provider: ControllerStateProvider) -> void:
	_release_physical_joypad()
	if provider != null:
		provider.release_all()
	if is_instance_valid(game):
		game.queue_free()
	await process_frame
	await physics_frame
	await process_frame


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("FIRST_SORTIE_TUTORIAL_REBASED_YARD_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		print("FIRST_SORTIE_TUTORIAL_REBASED_YARD_TEST_FAILED: ", "; ".join(_failures))
		quit(1)
