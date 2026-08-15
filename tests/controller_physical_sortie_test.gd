extends SceneTree

## Controller-only, production-scene proof of the complete embodied Torrent loop.
##
## The player walks from Main's real spawn to the parked craft using standardized
## joypad motion events. After boarding, an injected controller-state provider is
## read by the production LocalShipInputSource; no gameplay method is called to
## board, launch, return, land, shut down, or exit. The only accelerated values
## are exported transition/system durations and ordinary flight-response properties.
##
## The shift start, controls overlay, and pause/resume steps are driven by real
## joypad button events so the loop needs no keyboard at any point.

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
const BUTTON_DPAD_UP := 11
const BUTTON_DPAD_DOWN := 12
const BUTTON_DPAD_LEFT := 13

const EXPECTED_ASSERTIONS := 44

## Nominal durations for the two locomotion budgets. These are no longer wall-clock
## timeouts: each is converted into a number of simulated frames by
## [method _frame_budget], because every metre the avatar walks and the craft flies
## is integrated in `_physics_process`. See [method _frame_budget] for why the
## wall clock is the wrong instrument here.
const WALK_TRAVEL_SECONDS := 5.0
const FLIGHT_TRAVEL_SECONDS := 14.0

## Extra simulated frames every bounded loop is granted on top of the frames its
## nominal duration implies. A frame count, never a wall-clock grace: widening a
## timeout would make the divergence worse rather than better, since the wall clock
## keeps running exactly while the physics loop is being starved.
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


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "production Main instantiates for the physical controller sortie")
	if game == null:
		_finish()
		return
	root.add_child(game)
	await process_frame
	await physics_frame

	var player := game.get_node_or_null("Player") as PlayerController
	var torrent := game.get_node_or_null("TorrentInterceptor") as HeroShip
	var world := game.get_node_or_null("ShipyardWorld") as ShipyardWorld
	var opponent := game.get_node_or_null("RangeOpponent") as RangeOpponent
	_check(
		player != null and torrent != null and world != null and opponent != null,
		"live player, Torrent, world, and combat opponent resolve from Main"
	)
	if player == null or torrent == null or world == null or opponent == null:
		await _clean_up(game, null)
		_finish()
		return

	# These are public editor-facing tuning properties, not state transitions.
	game.canopy_motion_time = 0.0
	game.boarding_motion_time = 0.08
	game.disembarking_motion_time = 0.08
	torrent.engine_start_time = 0.02
	torrent.weapon_cooldown = 0.06
	torrent.maximum_speed = 70.0
	torrent.thrust_acceleration = 72.0
	torrent.brake_acceleration = 80.0
	torrent.passive_drag = 8.0
	torrent.throttle_response = 30.0
	torrent.yaw_speed_degrees = 180.0
	torrent.flight_assist_strength = 12.0

	var spawn_position := player.global_position
	var parked_transform := torrent.global_transform
	var approach_distance_m := player.get_interaction_origin().distance_to(
		torrent.get_boarding_position()
	)
	var walked_displacement_m := 0.0
	var departure_distance_m := 0.0
	var range_excursion_m := 0.0
	var landing_approach_distance_m := 0.0
	var berth_id := torrent.get_home_berth_id()
	var berth := world.get_berth_node(berth_id) as ShipBerth
	_check(
		berth != null
		and berth.get_occupant() == torrent
		and berth.get_reservation_owner() == torrent,
		"the physical Torrent begins under its exact occupied central-berth lease"
	)

	await _tap_physical_joy_button(BUTTON_X)
	_check(
		await _wait_until(func() -> bool: return game.phase == GameFlow.Phase.APPROACH_SHIP, 0.5)
		and player.is_control_enabled()
		and not player.is_seated(),
		"controller X starts the production HUD and grants on-foot approach authority"
	)

	# Gate C's settings/re-entry scenario also needs the overlay and pause panel
	# without a keyboard. Both are driven here by real joypad button events.
	var hud := game.hud
	var help_panel: Control = null
	var pause_panel: Control = null
	if hud != null:
		help_panel = hud.get("_help_panel") as Control
		pause_panel = hud.get("_pause") as Control
	_check(
		help_panel != null and pause_panel != null and not pause_panel.visible,
		"the started HUD exposes a live controls overlay and a hidden pause panel"
	)
	var help_initially_visible := help_panel != null and help_panel.visible
	await _tap_physical_joy_button(BUTTON_BACK)
	_check(
		help_panel != null and help_panel.visible != help_initially_visible,
		"controller Back toggles the controls overlay with no keyboard involved"
	)
	await _tap_physical_joy_button(BUTTON_BACK)
	_check(
		help_panel != null and help_panel.visible == help_initially_visible,
		"a released and re-pressed controller Back toggles the same overlay exactly once"
	)
	await _tap_physical_joy_button(BUTTON_START)
	_check(
		pause_panel != null and pause_panel.visible and paused,
		"controller Start pauses the live shift and halts the gameplay tree"
	)
	await _tap_physical_joy_button(BUTTON_START)
	_check(
		pause_panel != null and not pause_panel.visible and not paused,
		"controller Start resumes the same shift and restores the gameplay tree"
	)

	var walked_to_ship := await _walk_player_to_ship(player, torrent, game)
	walked_displacement_m = player.global_position.distance_to(spawn_position)
	_check(walked_to_ship, "left-stick input physically walks from spawn to the Torrent")
	_check(
		player.global_position.distance_to(spawn_position) > 8.0
		and game.boarding_candidate == torrent,
		"the live proximity system, not a ship-selection shortcut, owns the candidate"
	)
	await _tap_physical_joy_button(BUTTON_X)
	_check(
		await _wait_until(
			func() -> bool: return game.phase == GameFlow.Phase.START_ENGINES,
			1.2
		),
		"controller X drives the physical canopy, boarding path, and pilot-seat handoff"
	)
	_check(
		game.get_active_ship() == torrent and torrent.is_piloted() and player.is_seated(),
		"the same visible player and parked Torrent now share piloting authority"
	)

	var source := torrent.get_command_source() as LocalShipInputSource
	var provider := ControllerStateProvider.new()
	_check(source != null, "the piloted Torrent exposes its production local command source")
	if source == null:
		await _clean_up(game, provider)
		_finish()
		return
	source.set_input_provider(provider)

	var initial_distance := torrent.get_chase_camera_distance()
	await _tap_provider_button(provider, BUTTON_RIGHT_SHOULDER)
	_check(
		is_equal_approx(
			torrent.get_chase_camera_distance(),
			initial_distance + torrent.chase_camera_zoom_step
		),
		"controller RB adjusts the chase distance through the sampled command"
	)
	await _tap_provider_button(provider, BUTTON_Y)
	_check(
		torrent.get_camera_view() == &"COCKPIT" and torrent.get_camera().current,
		"controller Y selects the live physical cockpit camera"
	)
	await _tap_provider_button(provider, BUTTON_Y)
	_check(
		torrent.get_camera_view() == &"CHASE" and torrent.get_camera().current,
		"a released and re-pressed controller Y returns to chase view exactly once"
	)

	var engine_events: Array[StringName] = []
	torrent.engine_state_changed.connect(func(state: StringName) -> void:
		engine_events.append(state)
	)
	await _tap_provider_button(provider, BUTTON_DPAD_UP)
	_check(
		await _wait_until(
			func() -> bool:
				return str(torrent.get_telemetry().get("engine_state", "")) == "ONLINE",
			0.6
		),
		"D-pad Up starts the engine through the immutable controller command"
	)
	_check(
		await _wait_until(func() -> bool: return game.phase == GameFlow.Phase.LAUNCH, 0.4)
		and engine_events == [&"STARTING", &"ONLINE"],
		"startup produces one ordered transition and enters the guided launch phase"
	)

	provider.set_axis(AXIS_LEFT_Y, -1.0)
	_check(
		await _wait_until(
			func() -> bool: return not bool(torrent.get_telemetry().get("landed", true)),
			1.0
		),
		"real left-stick thrust physically clears the docking latch"
	)
	provider.set_axis(AXIS_LEFT_Y, 0.0)
	await physics_frame
	await process_frame
	departure_distance_m = torrent.global_position.distance_to(parked_transform.origin)
	_check(
		departure_distance_m > 0.01
		and berth.get_occupant() == null
		and berth.get_reservation_owner() == null,
		"physical departure moves the craft and releases the complete old lease"
	)

	_check(
		await _fly_to_waypoint(torrent, provider, Vector3(0.0, 8.0, -78.0), 5.0),
		"controller steering flies the live craft through the launch aperture"
	)
	await _brake_ship(torrent, provider, 0.8, 2.0)
	range_excursion_m = torrent.global_position.distance_to(parked_transform.origin)
	_check(
		game.phase == GameFlow.Phase.TARGET_PRACTICE
		and torrent.global_position.z < -66.0,
		"the physical launch threshold activates the production target range"
	)

	var accepted_combat_result := false
	var target_nodes := get_nodes_in_group("shipyard_targets")
	target_nodes.sort_custom(func(first: Node, second: Node) -> bool:
		return str(first.name) < str(second.name)
	)
	_check(target_nodes.size() == 4, "the guided sortie resolves all four live physical range drones")
	for target_value: Node in target_nodes:
		var target := target_value as Node3D
		var target_name := str(target.name)
		var destroyed := await _aim_and_fire_until_removed(
			torrent,
			provider,
			target,
			func() -> bool:
				return not is_instance_valid(target) or bool(target.get_meta("destroyed", false)),
			2.5
		)
		var shot_result := game.get_last_player_shot_result()
		accepted_combat_result = accepted_combat_result or (
			bool(shot_result.get("accepted", false))
			and bool(shot_result.get("resolved", false))
			and shot_result.get("source_entity") == torrent
		)
		_check(destroyed, "controller fire destroys %s through live hitscan authority" % target_name)
	_check(
		accepted_combat_result,
		"right-trigger fire is accepted and resolved by the production combat authority"
	)
	_check(
		world.get_destroyed_target_count() == 4
		and game.phase == GameFlow.Phase.INTERCEPTOR_ENGAGEMENT
		and opponent.is_active(),
		"clearing the real range launches the live defence interceptor"
	)

	var opponent_destroyed := await _aim_and_fire_until_removed(
		torrent,
		provider,
		opponent,
		func() -> bool: return not opponent.is_active(),
		3.5
	)
	_check(
		opponent_destroyed and game.phase == GameFlow.Phase.RETURN_TO_YARD,
		"controller dogfighting defeats the live interceptor and authorizes return"
	)
	_check(
		not torrent.is_destroyed() and float(torrent.get_telemetry().get("hull", 0.0)) > 0.0,
		"the continuous physical sortie retains a live return-capable craft"
	)

	var return_waypoint := Vector3(0.0, 2.0, -18.0)
	await _brake_ship(torrent, provider, 0.8, 2.0)
	await _align_ship(
		torrent,
		provider,
		(return_waypoint - torrent.global_position).normalized(),
		0.98,
		3.5
	)
	_check(
		await _fly_to_waypoint(torrent, provider, return_waypoint, 1.0),
		"controller steering physically returns the Torrent to its broad landing capture"
	)
	await _brake_ship(torrent, provider, 0.45, 2.5)
	var nose_to_dock := (parked_transform.origin - torrent.global_position).normalized()
	_check(
		await _align_ship(torrent, provider, nose_to_dock, 0.995, 2.5),
		"controller yaw and pitch point the visible nose toward the berth"
	)
	await _brake_ship(torrent, provider, 0.35, 1.2)
	landing_approach_distance_m = torrent.global_position.distance_to(parked_transform.origin)
	var capture_report := world.get_landing_assist_report(torrent, berth_id)
	_check(
		bool(capture_report.get("assist_capture_accepted", false))
		and capture_report.get("selected_berth_id", &"") == berth_id
		and berth.contains_assist_capture(torrent.global_position)
		and torrent.velocity.length() <= berth.get_assist_capture_maximum_speed(),
		"the returned craft is inside its registered broad assist-capture contract"
	)
	_check(
		(-torrent.global_basis.z.normalized()).dot(nose_to_dock) > 0.995
		and (-torrent.global_basis.z.normalized()).dot(
			-parked_transform.basis.z.normalized()
		) < -0.95,
		"landing acquisition is genuinely nose-first, opposite the final parked heading"
	)

	await _tap_provider_button(provider, BUTTON_DPAD_LEFT)
	_check(
		await _wait_until(func() -> bool: return torrent.is_landing_active(), 0.6),
		"D-pad Left obtains the live staged landing-assist contract"
	)
	_check(
		await _wait_until(func() -> bool: return game.phase == GameFlow.Phase.SHUT_DOWN, 4.5),
		"landing assist physically returns the craft to the shutdown phase"
	)
	var landing_report := torrent.get_landing_contract_report()
	_check(
		bool(landing_report.get("contract_accepted", false))
		and bool(landing_report.get("strict_dock_acceptance", false))
		and landing_report.get("berth_id", &"") == berth_id,
		"the completed return retains the exact accepted central-berth contract"
	)
	_check(
		torrent.global_transform.is_equal_approx(parked_transform)
		and berth.get_occupant() == torrent
		and berth.get_reservation_owner() == torrent
		and berth.get_reserved_ship_id() == torrent.get_ship_definition().ship_id,
		"landing restores the exact dock transform, occupant, owner, and ship identity"
	)

	await _tap_provider_button(provider, BUTTON_DPAD_DOWN)
	_check(
		await _wait_until(
			func() -> bool:
				return str(torrent.get_telemetry().get("engine_state", "")) == "OFFLINE",
			0.6
		),
		"D-pad Down shuts down the physically secured Torrent"
	)
	await _tap_provider_button(provider, BUTTON_X)
	_check(
		await _wait_until(
			func() -> bool:
				return (
					not torrent.is_piloted()
					and not player.is_seated()
					and player.is_control_enabled()
					and game.phase == GameFlow.Phase.COMPLETE
				),
			1.5
		),
		"controller X drives the physical canopy and disembarking path back to deck"
	)
	_check(
		game.phase == GameFlow.Phase.COMPLETE
		and game.is_guided_activity_complete()
		and game.get_active_ship() == torrent,
		"the full controller sortie completes only after the embodied exit"
	)
	_check(
		player.is_control_enabled()
		and player.global_position.distance_to(spawn_position) > 8.0
		and player.global_position.distance_to(torrent.get_exit_transform().origin) < 0.25,
		"the same player regains on-foot control at the physical ship exit, not at spawn"
	)
	print(
		"CONTROLLER_PHYSICAL_SORTIE_EVIDENCE: approach=%.3fm walked=%.3fm departure=%.3fm range_excursion=%.3fm landing_approach=%.3fm exit_from_spawn=%.3fm exit_marker_error=%.3fm"
		% [
			approach_distance_m,
			walked_displacement_m,
			departure_distance_m,
			range_excursion_m,
			landing_approach_distance_m,
			player.global_position.distance_to(spawn_position),
			player.global_position.distance_to(torrent.get_exit_transform().origin),
		]
	)
	print(
		"CONTROLLER_PHYSICAL_SORTIE_PHASES: APPROACH_SHIP > START_ENGINES > LAUNCH > TARGET_PRACTICE > INTERCEPTOR_ENGAGEMENT > RETURN_TO_YARD > SHUT_DOWN > COMPLETE"
	)
	print(
		"CONTROLLER_PHYSICAL_SORTIE_INPUTS: left-stick/L3/X/Back/Start/RB/Y/D-pad-Up/right-stick/LT/RT/A/D-pad-Left/D-pad-Down"
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
		BUTTON_DPAD_UP,
		BUTTON_DPAD_DOWN,
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
	if _assertions != EXPECTED_ASSERTIONS:
		_failures.append(
			"assertion contract drifted: expected %d, observed %d"
			% [EXPECTED_ASSERTIONS, _assertions]
		)
	if _failures.is_empty():
		print("CONTROLLER_PHYSICAL_SORTIE_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		print("CONTROLLER_PHYSICAL_SORTIE_TEST_FAILED: ", "; ".join(_failures))
		quit(1)
