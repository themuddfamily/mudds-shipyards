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
## --production-input-route instead enters through Boot and keeps authored tuning
## and the default Input-backed sampler; its event driver is never a provider.

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

const EXPECTED_ASSERTIONS := 44
const PRODUCTION_INPUT_ASSERTIONS := 47

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
var _production_input_route := false
var _sortie_diagnostics := false
var _diagnostic_wall_ms := -1
var _diagnostic_physics_frame := -1
var _diagnostic_process_frame := -1
var _boot: StartupLoader


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


class ControllerInputEvents:
	extends ControllerStateProvider

	var _flight_actions: Array[StringName] = []

	func _init(source: LocalShipInputSource) -> void:
		if source == null:
			return
		_flight_actions.assign([
			source.throttle_forward_action, source.throttle_reverse_action,
			source.yaw_left_action, source.yaw_right_action, source.pitch_up_action, source.pitch_down_action,
			source.roll_left_action, source.roll_right_action, source.brake_action, source.fire_action,
		])

	func set_button(button_index: int, pressed: bool) -> void:
		var event := InputEventJoypadButton.new()
		event.device = 0
		event.button_index = button_index
		event.pressed = pressed
		Input.parse_input_event(event)
		# Deliver this synthetic physics-tick input before the next ship sample;
		# outer process-frame flushing can span several catch-up physics ticks.
		Input.flush_buffered_events()

	func set_axis(axis_index: int, value: float) -> void:
		var event := InputEventJoypadMotion.new()
		event.device = 0
		event.axis = axis_index
		event.axis_value = clampf(value, -1.0, 1.0)
		# Guidance requests resolved action strength, like the legacy provider.
		# Native joystick events first cross InputMap's deadzone; invert that map.
		if event.axis_value != 0.0:
			var action := _bound_axis_action(axis_index, event.axis_value)
			if not action.is_empty():
				var deadzone := InputMap.action_get_deadzone(action)
				event.axis_value = signf(event.axis_value) * (deadzone + (1.0 - deadzone) * absf(event.axis_value))
		Input.parse_input_event(event)
		# Keep synthetic guidance delivery on its existing physics-tick cadence.
		Input.flush_buffered_events()

	func _bound_axis_action(axis_index: int, direction: float) -> StringName:
		for action: StringName in _flight_actions:
			for binding: InputEvent in InputMap.action_get_events(action):
				if not binding is InputEventJoypadMotion:
					continue
				var motion := binding as InputEventJoypadMotion
				if motion.axis == axis_index and motion.device in [-1, 0] \
						and signf(motion.axis_value) == signf(direction):
					return action
		return &""

	func steering_strengths_match() -> bool:
		var matched := true
		for axis in [0, 1, 3]:
			for value in [-1.0, -0.4, -0.05, 0.05, 0.4, 1.0]:
				var action := _bound_axis_action(axis, value)
				set_axis(axis, value)
				var observed := Input.get_action_strength(action) if not action.is_empty() else -1.0
				if not is_equal_approx(observed, absf(value)):
					print("CONTROLLER_INPUT_SCALAR_MISMATCH: axis=", axis, " action=", action,
						" desired=", value, " raw=", Input.get_joy_axis(0, axis), " observed=", observed)
					matched = false
				set_axis(axis, 0.0)
				if not action.is_empty() and Input.get_action_strength(action) != 0.0:
					matched = false
		var brake_action := _bound_axis_action(AXIS_LEFT_TRIGGER, 1.0)
		set_axis(AXIS_LEFT_TRIGGER, 1.0)
		if brake_action.is_empty() or not Input.is_action_pressed(brake_action):
			matched = false
		set_axis(AXIS_LEFT_TRIGGER, 0.0)
		if not brake_action.is_empty() and Input.is_action_pressed(brake_action):
			matched = false
		return matched

	func release_all() -> void:
		for axis in [0, 1, 2, 3, 4, 5]:
			set_axis(axis, 0.0)
		for button in [0, 2, 3, 4, 6, 7, 10, 13]:
			set_button(button, false)


## Native event driver for the optional Settings/re-entry release scenario.
## This object is never installed as a LocalShipInputSource provider.
class SettingsNativeInputEvents:
	extends ControllerStateProvider

	var desktop := false
	var ship: HeroShip
	var missing: Array[StringName] = []
	var held: Dictionary = {}

	func _init(use_desktop: bool, controlled_ship: HeroShip = null) -> void:
		desktop = use_desktop
		ship = controlled_ship

	func set_action(action: StringName, strength: float, mouse: bool = false) -> void:
		if strength <= 0.0:
			if held.has(action):
				_emit(held[action], 0.0, action)
				held.erase(action)
			return
		var selected: InputEvent
		for binding: InputEvent in InputMap.action_get_events(action):
			if desktop and ((mouse and binding is InputEventMouseButton) \
					or (not mouse and binding is InputEventKey)):
				selected = binding
				break
			if not desktop and (binding is InputEventJoypadButton or binding is InputEventJoypadMotion):
				selected = binding
				break
		if selected == null:
			if action not in missing:
				missing.append(action)
			return
		held[action] = selected
		_emit(selected, strength, action)

	func _emit(binding: InputEvent, strength: float, action: StringName) -> void:
		var event := binding.duplicate() as InputEvent
		if event is InputEventKey:
			var key := event as InputEventKey
			key.pressed = strength > 0.0
			if key.keycode == 0:
				key.keycode = key.physical_keycode
			if key.physical_keycode == 0:
				key.physical_keycode = key.keycode
			key.unicode = int(key.keycode) if int(key.keycode) < 0x110000 else 0
		elif event is InputEventMouseButton:
			(event as InputEventMouseButton).pressed = strength > 0.0
		elif event is InputEventJoypadButton:
			(event as InputEventJoypadButton).device = 0
			(event as InputEventJoypadButton).pressed = strength > 0.0
		elif event is InputEventJoypadMotion:
			var motion := event as InputEventJoypadMotion
			motion.device = 0
			var deadzone := InputMap.action_get_deadzone(action)
			motion.axis_value = signf(motion.axis_value) * (deadzone + (1.0 - deadzone) * strength) if strength > 0.0 else 0.0
		Input.parse_input_event(event)
		Input.flush_buffered_events()

	func motion(relative: Vector2) -> void:
		var event := InputEventMouseMotion.new()
		event.relative = relative
		event.screen_relative = relative
		Input.parse_input_event(event)
		Input.flush_buffered_events()

	func wheel(outward: bool) -> void:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_WHEEL_DOWN if outward else MOUSE_BUTTON_WHEEL_UP
		event.pressed = true
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		event = event.duplicate() as InputEventMouseButton
		event.pressed = false
		Input.parse_input_event(event)
		Input.flush_buffered_events()

	func set_button(button_index: int, pressed: bool) -> void:
		if desktop and button_index in [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]:
			if pressed:
				wheel(button_index == JOY_BUTTON_RIGHT_SHOULDER)
			return
		var actions := {
			JOY_BUTTON_A: &"hover", JOY_BUTTON_B: &"barrel_roll", JOY_BUTTON_X: &"interact",
			JOY_BUTTON_Y: &"toggle_ship_camera_view", JOY_BUTTON_BACK: &"toggle_controls_overlay",
			JOY_BUTTON_START: &"pause", JOY_BUTTON_LEFT_STICK: &"sprint_boost",
			JOY_BUTTON_LEFT_SHOULDER: &"camera_distance_in", JOY_BUTTON_RIGHT_SHOULDER: &"camera_distance_out",
			JOY_BUTTON_DPAD_LEFT: &"landing_assist",
		}
		if actions.has(button_index):
			set_action(actions[button_index], 1.0 if pressed else 0.0)

	func set_axis(axis_index: int, value: float) -> void:
		# Existing guidance requests resolved analogue strength. Desktop guidance
		# supplies the same angular demand as native mouse pixels per physics tick.
		if desktop and ship != null and axis_index in [AXIS_LEFT_X, AXIS_RIGHT_Y]:
			var pixels := value * deg_to_rad(ship.yaw_speed_degrees) \
				* ship.get_physics_process_delta_time() / maxf(ship.mouse_sensitivity, 0.000001)
			if axis_index == AXIS_LEFT_X:
				motion(Vector2(pixels, 0.0))
			else:
				motion(Vector2(0.0, -pixels if ship.invert_mouse_y else pixels))
			return
		var pairs := {
			AXIS_LEFT_X: [&"move_left", &"move_right"],
			AXIS_LEFT_Y: [&"move_forward", &"move_back"],
			AXIS_RIGHT_X: [&"roll_left", &"roll_right"],
			AXIS_RIGHT_Y: [&"pitch_up", &"pitch_down"],
		}
		if pairs.has(axis_index):
			var pair: Array = pairs[axis_index]
			# Opposite actions may share one physical joy axis. Release the old
			# direction before pressing its replacement so a late release cannot
			# overwrite the new native axis value with zero.
			if value < 0.0:
				set_action(pair[1], 0.0)
				set_action(pair[0], -value)
			else:
				set_action(pair[0], 0.0)
				set_action(pair[1], value)
		elif axis_index == AXIS_LEFT_TRIGGER:
			set_action(&"brake", value, desktop)
		elif axis_index == AXIS_RIGHT_TRIGGER:
			set_action(&"fire", value, desktop)

	func release_all() -> void:
		for action: StringName in held.keys():
			set_action(action, 0.0)


## Observe each consumed command after the production ship, before a later
## neutral physics tick can replace its one-tick mouse impulse.
class SettingsFlightMouseWitness extends Node:
	var ship: HeroShip
	var mouse_axes_seen := false

	func _physics_process(_delta: float) -> void:
		var command := ship.get_last_ship_command()
		mouse_axes_seen = mouse_axes_seen or (command != null \
			and absf(command.look_yaw_delta) > 0.001 and absf(command.look_pitch_delta) > 0.001)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if "--settings-reentry-input-route" in OS.get_cmdline_user_args():
		await _run_settings_reentry()
		return
	_production_input_route = "--production-input-route" in OS.get_cmdline_user_args()
	_sortie_diagnostics = _production_input_route and "--sortie-diagnostics" in OS.get_cmdline_user_args()
	_sortie_timing_sample("boot_begin")
	var game: GameFlow
	if _production_input_route:
		var boot_scene: PackedScene = load("res://scenes/boot.tscn")
		_boot = boot_scene.instantiate() as StartupLoader
		root.add_child(_boot)
		var completed_main: Node = await _boot.startup_completed
		game = completed_main as GameFlow
	else:
		game = MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "production Main instantiates for the physical controller sortie")
	if game == null:
		_finish()
		return
	if not _production_input_route:
		root.add_child(game)
	await process_frame
	await physics_frame
	if _production_input_route:
		root.grab_focus()
		var menu_ready := await _wait_until(func() -> bool: return _boot.get_main() == game and StartupLoader.is_title_menu_ready(game) and not is_instance_valid(_boot.get_loading_screen()) and root.has_focus(), 2.0)
		_check(menu_ready, "ordinary Boot completes and presents an interactive focused Begin Shift menu")
		if not menu_ready:
			await _clean_up(game, null)
			_finish()
			return

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

	var authored_tuning: Dictionary = _sortie_tuning(game, torrent) if _production_input_route else {}
	if not _production_input_route:
		# The original accelerated fixture remains distinct from ordinary controls.
		game.canopy_motion_time = 0.0
		game.boarding_motion_time = 0.08
		game.disembarking_motion_time = 0.08
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
			game.canopy_motion_time + game.boarding_motion_time + 1.0 if _production_input_route else 1.2
		),
		"controller X drives the physical canopy, boarding path, and pilot-seat handoff"
	)
	_check(
		game.get_active_ship() == torrent and torrent.is_piloted() and player.is_seated(),
		"the same visible player and parked Torrent now share piloting authority"
	)

	var source := torrent.get_command_source() as LocalShipInputSource
	var provider: ControllerStateProvider = ControllerInputEvents.new(source) if _production_input_route else ControllerStateProvider.new()
	_check(source != null, "the piloted Torrent exposes its production local command source")
	if source == null:
		await _clean_up(game, provider)
		_finish()
		return
	if _production_input_route:
		_check(source == torrent.get_local_input_source() and source.get_input_provider() == null \
			and source.is_enabled_owner() and (provider as ControllerInputEvents).steering_strengths_match(),
			"ordinary flight retains the default sampler and exact native steering strengths without an injected provider")
	else:
		source.set_input_provider(
			provider,
			LocalShipInputSource.INPUT_PROVIDER_INPUT_MAP_RESOLVED,
		)

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
	provider.set_axis(AXIS_LEFT_Y, -1.0)
	_check(
		await _wait_until(
			func() -> bool:
				return str(torrent.get_telemetry().get("engine_state", "")) == "ONLINE",
			0.6
		),
		"left-stick flight demand automatically wakes propulsion"
	)
	_check(
		game.phase == GameFlow.Phase.START_ENGINES and engine_events == [&"ONLINE"],
		"automatic wake publishes one immediate transition without advancing the sortie"
	)
	_check(
		await _wait_until(
			func() -> bool:
				return (
					not bool(torrent.get_telemetry().get("landed", true))
					and game.phase == GameFlow.Phase.LAUNCH
				),
			1.0
		),
		"real left-stick thrust physically clears the docking latch and begins the sortie"
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
	if _production_input_route and not opponent_destroyed:
		var shot := game.get_last_player_shot_result()
		var reason := ""
		var raw_reason := str(shot.get("reason", "")).left(80)
		for character_index: int in raw_reason.length():
			var character := raw_reason[character_index]
			reason += character if character in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-" else "_"
		var status := ""
		var raw_status := str(shot.get("status", "")).left(80)
		for character_index: int in raw_status.length():
			var character := raw_status[character_index]
			status += character if character in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-" else "_"
		print("CONTROLLER_OPPONENT_SHOT_FAILURE: accepted=%d resolved=%d hit=%d damaged=%d applied_damage=%.3f remaining_health=%.3f last_sequence=%d reason=%s status=%s" % [
			int(bool(shot.get("accepted", false))), int(bool(shot.get("resolved", false))),
			int(bool(shot.get("hit", false))), int(bool(shot.get("damaged", false))),
			float(shot.get("applied_damage", 0.0)), float(shot.get("remaining_health", -1.0)),
			int(shot.get("last_sequence", -1)), reason, status,
		])
	_check(
		opponent_destroyed and game.phase == GameFlow.Phase.RETURN_TO_YARD,
		"controller dogfighting defeats the live interceptor and authorizes return"
	)
	if _production_input_route and (not opponent_destroyed or game.phase != GameFlow.Phase.RETURN_TO_YARD):
		await _clean_up(game, provider)
		_finish()
		return
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
		await _fly_to_waypoint(torrent, provider, return_waypoint, 1.0, 0.45 if _production_input_route else -1.0),
		"controller steering physically returns the Torrent to its broad landing capture"
	)
	await _brake_ship(torrent, provider, 0.45, 2.5)
	var nose_to_dock := (parked_transform.origin - torrent.global_position).normalized()
	var nose_aligned := await _align_ship(torrent, provider, nose_to_dock, 0.995, 2.5)
	_check(
		nose_aligned,
		"controller yaw and pitch point the visible nose toward the berth"
	)
	if _production_input_route and not nose_aligned:
		print("CONTROLLER_RETURN_STAGING_FAILURE: ship_x=%.6f ship_y=%.6f ship_z=%.6f waypoint_x=%.6f waypoint_y=%.6f waypoint_z=%.6f parked_x=%.6f parked_y=%.6f parked_z=%.6f speed=%.6f" % [
			torrent.global_position.x, torrent.global_position.y, torrent.global_position.z,
			return_waypoint.x, return_waypoint.y, return_waypoint.z,
			parked_transform.origin.x, parked_transform.origin.y, parked_transform.origin.z,
			torrent.velocity.length(),
		])
		await _clean_up(game, provider)
		_finish()
		return
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

	_check(
		await _wait_until(
			func() -> bool:
				return str(torrent.get_telemetry().get("engine_state", "")) == "OFFLINE",
			2.0
		),
		"the physically secured Torrent automatically idles offline"
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
			game.canopy_motion_time + game.disembarking_motion_time + 1.0 if _production_input_route else 1.5
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
		"CONTROLLER_PHYSICAL_SORTIE_INPUTS: left-stick/L3/X/Back/Start/RB/Y/right-stick/LT/RT/A/D-pad-Left"
	)
	if _production_input_route:
		_check(source.get_input_provider() == null and _sortie_tuning(game, torrent) == authored_tuning,
			"Boot-to-exit ordinary input route preserves all authored sortie tuning and the default sampler")
		print("CONTROLLER_PRODUCTION_INPUT_ROUTE: Boot > Begin Shift > same-body sortie > docked exit; one run, not three fresh runs or native controls")

	await _clean_up(game, provider)
	_finish()


## External orchestration first runs accessibility_reentry_integration_test's
## --settings-process-write to exit 0, then starts this distinct process with
## --settings-reentry-input-route and the SAME isolated XDG_DATA_HOME.
## Run on a private rendered display with --audio-driver Dummy and an unchanged
## outer 300-second deadline. Source synthetic input is not physical hardware.
func _run_settings_reentry() -> void:
	_production_input_route = true
	_sortie_diagnostics = "--sortie-diagnostics" in OS.get_cmdline_user_args()
	var desktop := SettingsNativeInputEvents.new(true)
	var pad := SettingsNativeInputEvents.new(false)
	var isolated := OS.get_environment("XDG_DATA_HOME").simplify_path()
	_check(DisplayServer.get_name() != "headless", "Settings input scenario requires a private rendered display for real captured mouse input")
	_check(isolated.is_absolute_path() and isolated != "/" \
		and isolated != (OS.get_environment("HOME") + "/.local/share").simplify_path() \
		and OS.get_user_data_dir().simplify_path().begins_with(isolated + "/") \
		and FileAccess.file_exists("user://mudds_user_data.json"),
		"distinct read process requires the prior UI writer's isolated durable profile")
	if not _failures.is_empty():
		await _settings_abort(null, desktop, pad)
		return
	var boot_scene: PackedScene = load("res://scenes/boot.tscn")
	_boot = boot_scene.instantiate() as StartupLoader
	root.add_child(_boot)
	var completed: Node = await _boot.startup_completed
	var game := completed as GameFlow
	_check(game != null, "ordinary Boot supplies Settings scenario Main")
	if game == null:
		await _settings_abort(game, desktop, pad)
		return
	_check(await _wait_until(func() -> bool: return StartupLoader.is_title_menu_ready(game) \
		and not is_instance_valid(_boot.get_loading_screen()) and root.has_focus(), 2.0),
		"fresh process reaches the ordinary interactive title menu")
	var player := game.get_node_or_null("Player") as PlayerController
	var ship := game.get_node_or_null("ArrowReconShip") as HeroShip
	var world := game.get_node_or_null("ShipyardWorld") as ShipyardWorld
	var settings := game.get_runtime_settings()
	_check(player != null and ship != null and world != null and settings != null, "Settings scenario resolves production player, free-sortie Arrow, world and preferences")
	if player == null or ship == null or world == null or settings == null:
		await _settings_abort(game, desktop, pad)
		return
	var tuning := _sortie_tuning(game, ship)
	_check(_settings_saved_preferences_match(game) \
		and bool(game.get_runtime_settings_persistence_report().load_status.get("accepted", false)),
		"fresh Boot loads the UI writer's actual 91 FOV, 1.2 scale, reduced motion and captions")
	_check(is_equal_approx(player.get_authored_camera_fov(), 91.0) \
		and is_equal_approx(float(game.hud.get_accessibility_report().ui_scale), 1.2) \
		and bool(game.hud.get_accessibility_report().captions_enabled) \
		and is_zero_approx(ship.maximum_chase_camera_rotation_lag_degrees),
		"saved preferences reach the real player, HUD and free-sortie camera")
	var recovery: Dictionary = (game.get("_solo_safe_recovery_context") as Dictionary).duplicate(true)
	var resume_home_pilot: bool = recovery.get("location", "") == "mudds_home_berth" \
		and recovery.get("mode", "") == "pilot"
	print("SETTINGS_BEGIN_BEFORE: %s" % JSON.stringify(_settings_begin_context(game, player)))
	await _settings_tap(desktop, &"interact")
	# Saved home pilots traverse the authored boarding path after the title fade.
	# Fresh/on-foot starts retain the original on-foot phase and fade budget.
	var begin_budget := GameHUD.INTRO_FADE_SECONDS + 0.5
	if resume_home_pilot:
		begin_budget += 2.0 * game.canopy_motion_time + game.boarding_motion_time
	var began := await _wait_until(func() -> bool:
		if resume_home_pilot:
			return game.phase == GameFlow.Phase.START_ENGINES and bool(game.get("_piloting")) \
				and player.is_seated() and not bool(game.get("_transition_busy"))
		return game.phase == GameFlow.Phase.APPROACH_SHIP and player.is_control_enabled(), begin_budget)
	print("SETTINGS_BEGIN_AFTER: %s" % JSON.stringify(_settings_begin_context(game, player)))
	_check(began,
		"native keyboard Begin completes the saved home-pilot recovery" if resume_home_pilot \
		else "native keyboard Begin completes the authored title fade")
	if not began:
		await _settings_abort(game, desktop, pad)
		return
	if resume_home_pilot and not await _settings_exit_recovered_home_pilot(game, player, world, desktop, recovery):
		await _settings_abort(game, desktop, pad)
		return
	for driver: SettingsNativeInputEvents in [desktop, pad]:
		await _settings_on_foot_controls(game, player, driver)
		if not _failures.is_empty():
			await _settings_abort(game, desktop, pad)
			return
	# Restore a hidden Help overlay through its native action before mouse work.
	var help := game.hud.get("_help_panel") as Control
	if help.visible:
		await _settings_tap(desktop, &"toggle_controls_overlay")
	var camera_basis := player.get_camera().global_basis
	desktop.motion(Vector2(12.0, 6.0))
	await physics_frame
	await process_frame
	_check(not player.get_camera().global_basis.is_equal_approx(camera_basis), "native captured on-foot mouse motion turns the real camera")
	desktop.motion(Vector2(-12.0, -6.0))
	await physics_frame
	await process_frame
	for driver: SettingsNativeInputEvents in [desktop, pad]:
		if not await _settings_free_sortie(game, player, ship, world, driver):
			await _settings_abort(game, desktop, pad)
			return
	_check(_settings_saved_preferences_match(game) and _sortie_tuning(game, ship) == tuning \
		and ship.get_local_input_source().get_input_provider() == null,
		"both ordinary control families preserve saved preferences, authored tuning and the Input-backed sampler")
	_check(desktop.missing.is_empty() and pad.missing.is_empty(),
		"all exercised controls have current InputMap bindings (desktop=%s pad=%s)" % [desktop.missing, pad.missing])
	if not _failures.is_empty():
		await _settings_abort(game, desktop, pad)
		return
	await _settings_tap(desktop, &"pause")
	var pause_main := game.hud.get("_pause_main_page") as Control
	var exit_button := pause_main.find_child("ExitButton", true, false) as Control
	for step in 100:
		if root.gui_get_focus_owner() == exit_button:
			break
		await _settings_tap(desktop, &"ui_focus_next")
	_check(paused and root.gui_get_focus_owner() == exit_button, "native keyboard navigation reaches ordinary Exit to desktop")
	if not _failures.is_empty():
		await _settings_abort(game, desktop, pad)
		return
	desktop.release_all()
	pad.release_all()
	print("SETTINGS_REENTRY_INPUT_ROUTE_TEST_OK: %d assertions; two authored free sorties after actual saved-profile restart; native synthetic desktop/gamepad input, physical hardware NOT_RUN" % _assertions)
	await _settings_tap(desktop, &"ui_accept")
	for frame in 120:
		await process_frame
	_check(false, "ordinary Exit must terminate this process with exit 0")
	await _settings_abort(game, desktop, pad)


func _settings_exit_recovered_home_pilot(game: GameFlow, player: PlayerController, world: ShipyardWorld, driver: SettingsNativeInputEvents, recovery: Dictionary) -> bool:
	var craft := game.get_active_ship()
	_check(craft != null and craft in game.ships and not craft.is_destroyed() \
		and String(craft.get_ship_id()) == recovery.get("craft_id", "") \
		and String(craft.get_home_berth_id()) == recovery.get("berth_id", "") \
		and craft.is_piloted() and player.is_seated_at(craft.get_pilot_seat_anchor()),
		"Begin resumes the exact saved home craft and physical pilot seat")
	if not _failures.is_empty():
		return false
	var berth_id := craft.get_home_berth_id()
	var berth := world.get_berth_node(berth_id) as ShipBerth
	_check(berth != null and berth.get_occupant() == craft and berth.get_reservation_owner() == craft \
		and berth.get_reserved_ship_id() == craft.get_ship_definition().ship_id \
		and craft.global_transform.is_equal_approx(world.get_berth_transform(berth_id)) \
		and bool(craft.get_telemetry().landed) and not craft.is_landing_active(),
		"Recovered pilot remains physically docked at its exact occupied home berth")
	var source := craft.get_local_input_source()
	_check(source != null and source.get_input_provider() == null and source.is_enabled_owner(),
		"Recovered pilot retains its ordinary Input-backed lifecycle owner")
	if not _failures.is_empty():
		return false
	driver.release_all()
	_check(await _wait_until(func() -> bool: return craft.get_telemetry().engine_state == &"OFFLINE", 2.0),
		"Neutral native controls permit the recovered craft's authored automatic shutdown")
	if not _failures.is_empty():
		return false
	var settled_exit := player.settle_exit_onto_support(craft.get_exit_transform())
	var seated_position := player.global_position
	var exit_completions := [0]
	var on_exit_completed := func() -> void: exit_completions[0] += 1
	player.disembarking_completed.connect(on_exit_completed)
	await _settings_tap(driver, &"interact")
	var exited := await _wait_until(func() -> bool: return not craft.is_piloted() and not player.is_seated() \
		and not bool(game.get("_piloting")) and not bool(game.get("_transition_busy")) \
		and game.phase in [GameFlow.Phase.APPROACH_SHIP, GameFlow.Phase.COMPLETE] \
		and player.is_control_enabled() and player.is_on_floor(),
		2.0 * game.canopy_motion_time + game.disembarking_motion_time + 1.0)
	player.disembarking_completed.disconnect(on_exit_completed)
	_check(exited and exit_completions[0] == 1 \
		and player.global_position.distance_to(seated_position) > 0.25 \
		and player.global_position.distance_to(settled_exit.origin) < 0.25 \
		and berth.get_occupant() == craft and berth.get_reservation_owner() == craft \
		and bool(craft.get_telemetry().landed),
		"Native E physically disembarks the recovered pilot onto the home deck while retaining the docked craft")
	return _failures.is_empty()


func _settings_begin_context(game: GameFlow, player: PlayerController) -> Dictionary:
	var intro := game.hud.get("_intro") as Control
	var focus := root.gui_get_focus_owner()
	return {
		"phase": game.phase, "control_enabled": player.is_control_enabled(),
		"seated": player.is_seated(), "piloting": game.get("_piloting"),
		"transition_busy": game.get("_transition_busy"),
		"recovery_context": game.get("_solo_safe_recovery_context"),
		"recovery_pending": game.get("_solo_safe_recovery_pending"),
		"hud_started": game.hud.get("_started"),
		"intro_visible": intro != null and intro.visible,
		"focus": str(focus.get_path()) if focus != null else "",
	}


func _settings_saved_preferences_match(game: GameFlow) -> bool:
	var settings := game.get_runtime_settings()
	return is_equal_approx(settings.camera_fov, 91.0) and is_equal_approx(settings.ui_scale, 1.2) \
		and settings.reduced_motion and settings.captions_enabled


func _settings_tap(driver: SettingsNativeInputEvents, action: StringName) -> void:
	driver.set_action(action, 1.0)
	await physics_frame
	await process_frame
	driver.set_action(action, 0.0)
	await physics_frame
	await process_frame


func _settings_on_foot_controls(game: GameFlow, player: PlayerController, driver: SettingsNativeInputEvents) -> void:
	var family := "desktop" if driver.desktop else "current gamepad"
	var help := game.hud.get("_help_panel") as Control
	var was_visible := help.visible
	await _settings_tap(driver, &"toggle_controls_overlay")
	_check(help.visible != was_visible, "%s toggles the real controls overlay" % family)
	await _settings_tap(driver, &"toggle_controls_overlay")
	_check(help.visible == was_visible, "%s toggles the real controls overlay back" % family)
	if help.visible:
		await _settings_tap(driver, &"toggle_controls_overlay")
	await _settings_tap(driver, &"pause")
	_check(paused, "%s pauses the live shift" % family)
	await _settings_tap(driver, &"pause")
	_check(not paused and player.is_control_enabled(), "%s resumes the same live player" % family)
	var mode := player.get_camera_view_mode()
	await _settings_tap(driver, &"toggle_first_person")
	_check(player.get_camera_view_mode() != mode, "%s selects the other on-foot camera" % family)
	await _settings_tap(driver, &"toggle_first_person")
	_check(player.get_camera_view_mode() == mode, "%s restores the original on-foot camera" % family)
	for action: StringName in [&"move_forward", &"move_back", &"move_left", &"move_right"]:
		var position := player.global_position
		driver.set_action(action, 1.0)
		for frame in 6:
			await physics_frame
			await process_frame
		driver.set_action(action, 0.0)
		_check(player.global_position.distance_to(position) > 0.001, "%s physically walks with %s" % [family, action])
	_check(await _wait_until(func() -> bool: return player.is_on_floor(), 2.0), "%s reaches supported ground before Jump" % family)
	var height := player.global_position.y
	await _settings_tap(driver, &"jump")
	_check(await _wait_until(func() -> bool: return player.global_position.y > height + 0.03, 0.5), "%s Jump lifts the actual supported player" % family)
	_check(await _wait_until(func() -> bool: return player.is_on_floor(), 2.0), "%s returns to usable floor support" % family)


func _settings_walk_to_ship(player: PlayerController, ship: HeroShip, game: GameFlow, driver: SettingsNativeInputEvents) -> bool:
	var world := game.world as ShipyardWorld
	if world == null or not is_finite(player.sprint_speed) or player.sprint_speed <= 0.0 \
			or not is_finite(player.ground_acceleration) or player.ground_acceleration <= 0.0 \
			or not is_finite(player.ground_deceleration) or player.ground_deceleration <= 0.0 \
			or Engine.physics_ticks_per_second <= 0:
		driver.release_all()
		return false
	var branch := world.get_node_or_null(^"ExposedDockLattice/PortBranchArm") as StaticBody3D
	var north_rail := world.get_node_or_null(^"ExposedDockLattice/BranchRail/Collision") as CollisionShape3D
	var branch_cargo := world.get_node_or_null(^"OperationalLattice/Activities/PortBranchCargoLine") as StationOperationsActivity
	var apron := world.get_node_or_null(^"ExposedDockLattice/PortBerthNode") as StaticBody3D
	var apron_collision: CollisionShape3D = apron.get_node_or_null(^"Collision") as CollisionShape3D if apron != null else null
	var player_collision := player.get_node_or_null(^"PlayerCollision") as CollisionShape3D
	if branch == null or north_rail == null or not north_rail.shape is BoxShape3D \
			or branch_cargo == null or apron_collision == null or not apron_collision.shape is BoxShape3D \
			or player_collision == null or not player_collision.shape is CapsuleShape3D:
		driver.release_all()
		return false
	var radius := (player_collision.shape as CapsuleShape3D).radius
	var apron_shape := apron_collision.shape as BoxShape3D
	if not is_finite(radius) or radius <= 0.0 or not apron_shape.size.is_finite():
		driver.release_all()
		return false
	var start := world.to_local(player.global_position)
	var apron_corner := world.to_local(apron_collision.to_global(Vector3(
		apron_shape.size.x * 0.5 - radius * 2.0,
		apron_shape.size.y * 0.5,
		apron_shape.size.z * 0.5 - radius * 2.0)))
	var boarding := world.to_local(ship.get_boarding_position())
	# Arrow already publishes its ground route around the wing. Resolve it
	# from the physical tail apron on the marker's side, before the climb.
	# The deck-max inset used before crossed the registry slab's 0.40m side;
	# the public ground strip crosses the existing threshold near its toe.
	var ground_entry := ship.get_exterior_boarding_waypoints(world.to_global(
		Vector3(apron_corner.x, apron_corner.y, boarding.z)))
	if ground_entry.size() < 2:
		driver.release_all()
		return false
	var ground_strip := world.to_local(ground_entry[0].origin)
	if not ground_strip.is_finite() or not ground_entry[1].origin.is_finite() \
			or absf(ground_strip.y - apron_corner.y) >= radius:
		driver.release_all()
		return false
	apron_corner.z = ground_strip.z
	# Branch centerz15.5 is inside the actual transfer machinery. Follow the
	# north-side embodied corridor using its physical rail and cargo declarations.
	var rail_shape := north_rail.shape as BoxShape3D
	var rail_inner_z := world.to_local(north_rail.to_global(Vector3(0.0, 0.0, rail_shape.size.z * 0.5))).z
	var branch_lane_z := rail_inner_z + radius * 2.0
	var cargo_front_z := INF
	for volume: Dictionary in branch_cargo.get_solid_volume_contract():
		var position: Vector3 = volume.position
		var size: Vector3 = volume.size
		cargo_front_z = minf(cargo_front_z, world.to_local(branch_cargo.to_global(
			position - Vector3(0.0, 0.0, size.z * 0.5))).z)
	if not is_finite(cargo_front_z) or branch_lane_z + radius >= cargo_front_z:
		driver.release_all()
		return false
	# These are physical deck anchors, not a diagonal across the intentional void.
	var apron_start := apron_collision.to_local(player.global_position)
	var starts_on_apron := absf(apron_start.x) <= apron_shape.size.x * 0.5 \
		and absf(apron_start.z) <= apron_shape.size.z * 0.5
	var route: Array[Vector3] = []
	if starts_on_apron:
		# After the desktop sortie, Arrow remains reboard-blocked until the
		# walker leaves its interaction reach. Go outward from the port-flank
		# exit, then along the aft strip to the tail apron before returning.
		# Returning inward to branch center first would cross the parked wing.
		route.append(world.to_global(Vector3(start.x, apron_corner.y, apron_corner.z)))
		route.append(world.to_global(apron_corner))
	else:
		# Enter PortBranchArm via CentralJunction and skirt the Arrow's tail.
		route.append(world.to_global(Vector3(start.x, apron_corner.y, branch_lane_z)))
		route.append(world.to_global(Vector3(apron_corner.x, apron_corner.y, branch_lane_z)))
		route.append(world.to_global(apron_corner))
	route.append(ground_entry[1].origin)
	route.append(ship.get_boarding_position())
	var path_distance := 0.0
	var previous := player.global_position
	for waypoint: Vector3 in route:
		path_distance += (waypoint - previous).slide(Vector3.UP).length()
		previous = waypoint
	# Bound the supported path by authored sprint speed and the original
	# 30-tick reserve. Digital diagonals can project only cos(45deg) of full
	# speed along a leg; account for that geometry for desktop key input only.
	var projection := sqrt(0.5) if driver.desktop else 1.0
	var frame_budget := _frame_budget(maxf(WALK_TRAVEL_SECONDS,
		path_distance / (player.sprint_speed * projection)))
	driver.ship = null
	driver.set_action(&"sprint_boost", 1.0)
	var started := Engine.get_physics_frames()
	var frames := 0
	var leg := 0
	var segment_origin := player.global_position
	var corner_braking := false
	var physics_delta := 1.0 / float(Engine.physics_ticks_per_second)
	var requested_axes := Vector2.ZERO
	var arrived := false
	var intact := true
	while frames <= frame_budget:
		# Abort while still near deck height, well before Main's below-yard rescue.
		# A recalled player can never turn this route into a successful approach.
		if not player.is_control_enabled() or player.is_seated() \
				or game.phase != GameFlow.Phase.APPROACH_SHIP \
				or world.to_local(player.global_position).y < apron_corner.y - radius:
			intact = false
			break
		var final_distance := player.get_interaction_origin().distance_to(ship.get_boarding_position())
		if game.boarding_candidate == ship and final_distance < 3.1 and player.is_on_floor():
			arrived = true
			break
		if frames == frame_budget:
			break
		var horizontal_velocity := player.velocity.slide(Vector3.UP)
		var horizontal_speed := horizontal_velocity.length()
		# A corner cannot be captured at sprint speed: the real neutral stopping
		# distance is ~1.01m, exceeding the existing .38m capsule tolerance.
		# Keep neutral braking latched until stopped, then either advance inside
		# that same tolerance or reapproach if the stop ended outside it.
		if corner_braking and horizontal_velocity.is_zero_approx():
			corner_braking = false
		while leg < route.size() - 1 and horizontal_velocity.is_zero_approx() \
				and (route[leg] - player.global_position).slide(Vector3.UP).length() <= radius:
			segment_origin = route[leg]
			leg += 1
		var offset := ((ship.get_boarding_position() - player.get_interaction_origin()) \
			if leg == route.size() - 1 else route[leg] - player.global_position).slide(Vector3.UP)
		var stopping_distance := horizontal_speed * horizontal_speed / (2.0 * player.ground_deceleration)
		if leg < route.size() - 1 and not corner_braking and horizontal_speed > 0.0 \
				and offset.length() <= stopping_distance + horizontal_speed * physics_delta:
			corner_braking = true
		var desired := offset.normalized()
		var predicted_cross := Vector3.ZERO
		if corner_braking:
			# Zero movement uses the actual Player's ground_deceleration. A
			# reverse or lateral key would instead keep accelerating at 34m/s².
			desired = Vector3.ZERO
		elif driver.desktop:
			var segment := (route[leg] - segment_origin).slide(Vector3.UP)
			var segment_length := segment.length()
			if segment_length > 0.0:
				var along := segment / segment_length
				var from_start := (player.global_position - segment_origin).slide(Vector3.UP)
				var along_distance := from_start.dot(along)
				var cross := from_start - along * along_distance
				var cross_velocity := horizontal_velocity - along * horizontal_velocity.dot(along)
				# Predict signed lateral stopping displacement under the real
				# corrective acceleration, plus one tick of input observation.
				var cross_drift := cross_velocity * (cross_velocity.length() / (2.0 * player.ground_acceleration) + physics_delta)
				predicted_cross = cross + cross_drift
				if predicted_cross.length() > radius:
					# Recover the canonical segment before pursuing its far end.
					desired = -predicted_cross.normalized()
				else:
					var lookahead_distance := clampf(along_distance + radius * 2.0, 0.0, segment_length)
					var lookahead := segment_origin + along * lookahead_distance
					desired = ((lookahead - player.global_position).slide(Vector3.UP) - cross_drift).normalized()
		var yaw := player.get_node("%CameraYaw") as Node3D
		var forward := (-yaw.global_basis.z).slide(Vector3.UP).normalized()
		var right := forward.cross(Vector3.UP).normalized()
		requested_axes = Vector2(desired.dot(right) if absf(desired.dot(right)) > 0.08 else 0.0,
			-desired.dot(forward) if absf(desired.dot(forward)) > 0.08 else 0.0)
		if driver.desktop:
			# Native keys are binary. Preserve the desired heading by choosing
			# its nearest realizable key direction, rather than pressing both
			# keys for every small analog component at a non-cardinal camera yaw.
			requested_axes = _settings_nearest_key_direction(requested_axes)
		driver.set_axis(AXIS_LEFT_X, requested_axes.x)
		driver.set_axis(AXIS_LEFT_Y, requested_axes.y)
		await physics_frame
		frames = Engine.get_physics_frames() - started
	driver.release_all()
	await physics_frame
	await process_frame
	var succeeded := intact and arrived and frames <= frame_budget \
		and game.boarding_candidate == ship and player.is_on_floor() \
		and player.get_interaction_origin().distance_to(ship.get_boarding_position()) < 3.2
	if not succeeded:
		print("SETTINGS_WALK_FAILED: %s" % JSON.stringify({
			"desktop": driver.desktop, "frames": frames, "frame_budget": frame_budget,
			"leg": leg, "position": str(player.global_position), "velocity": str(player.velocity),
			"floor": player.is_on_floor(), "route_intact": intact,
			"candidate_matches": game.boarding_candidate == ship,
			"distance": player.get_interaction_origin().distance_to(ship.get_boarding_position()),
		}))
	return succeeded


func _settings_nearest_key_direction(desired: Vector2) -> Vector2:
	if desired.is_zero_approx():
		return Vector2.ZERO
	var heading := desired.normalized()
	var nearest := Vector2.ZERO
	var best_alignment := -INF
	for x: int in [-1, 0, 1]:
		for y: int in [-1, 0, 1]:
			var candidate := Vector2(x, y).normalized()
			if candidate.is_zero_approx():
				continue
			var alignment := candidate.dot(heading)
			if alignment > best_alignment:
				best_alignment = alignment
				nearest = candidate
	return nearest


func _settings_free_sortie(game: GameFlow, player: PlayerController, ship: HeroShip, world: ShipyardWorld, driver: SettingsNativeInputEvents) -> bool:
	var family := "desktop" if driver.desktop else "current gamepad"
	_check(await _settings_walk_to_ship(player, ship, game, driver), "%s physically approaches the free-sortie Arrow using movement and sprint" % family)
	if not _failures.is_empty():
		return false
	await _settings_tap(driver, &"interact")
	_check(await _wait_until(func() -> bool: return ship.is_piloted() and player.is_seated() \
		and game.get_active_ship() == ship, game.canopy_motion_time + game.boarding_motion_time + 1.0),
		"%s physically boards Arrow through its ordinary interaction" % family)
	if not _failures.is_empty():
		return false
	driver.ship = ship
	var source := ship.get_local_input_source()
	_check(source != null and source.get_input_provider() == null and source.is_enabled_owner(), "%s retains the default Input-backed ship owner" % family)
	if not _failures.is_empty():
		return false
	var berth_id := ship.get_home_berth_id()
	var parked := world.get_berth_transform(berth_id)
	var berth := world.get_berth_node(berth_id) as ShipBerth
	var initial_zoom := ship.get_chase_camera_distance()
	await _tap_provider_button(driver, JOY_BUTTON_RIGHT_SHOULDER)
	_check(is_equal_approx(ship.get_chase_camera_distance(), initial_zoom + ship.chase_camera_zoom_step), "%s zooms the real chase camera outward" % family)
	await _tap_provider_button(driver, JOY_BUTTON_LEFT_SHOULDER)
	_check(is_equal_approx(ship.get_chase_camera_distance(), initial_zoom), "%s zooms the real chase camera inward" % family)
	var view := ship.get_camera_view()
	await _settings_tap(driver, &"toggle_ship_camera_view")
	_check(ship.get_camera_view() != view and ship.get_camera().current, "%s selects the live cockpit camera" % family)
	await _settings_tap(driver, &"toggle_ship_camera_view")
	_check(ship.get_camera_view() == view and ship.get_camera().current, "%s restores the live chase camera" % family)
	driver.set_action(&"move_forward", 1.0)
	_check(await _wait_until(func() -> bool: return ship.get_telemetry().engine_state == &"ONLINE" \
		and not bool(ship.get_telemetry().landed) and game.phase == GameFlow.Phase.FREE_FLIGHT, 2.0),
		"%s thrust automatically wakes propulsion and physically releases the berth" % family)
	driver.release_all()
	_check(berth.get_occupant() == null and berth.get_reservation_owner() == null, "%s departure releases the real berth lease" % family)
	if not _failures.is_empty():
		return false
	var outbound := parked * Vector3(0.0, 8.0, -30.0)
	_check(await _fly_to_waypoint(ship, driver, outbound, 1.5, 0.6), "%s physically flies to clear control-test airspace" % family)
	if not _failures.is_empty():
		return false
	# Both families cross the complete ordinary held-control roster. Directional
	# checks also require physical attitude changes; no command is injected.
	for row: Array in [
		[&"move_back", &"throttle", -1.0], [&"move_left", &"yaw", -1.0],
		[&"move_right", &"yaw", 1.0], [&"pitch_up", &"pitch", 1.0],
		[&"pitch_down", &"pitch", -1.0], [&"roll_left", &"roll", -1.0],
		[&"roll_right", &"roll", 1.0],
		[&"hover", &"hover", true], [&"brake", &"brake", true],
	]:
		await _settings_probe_control(ship, driver, row[0], row[1], row[2])
		if not _failures.is_empty():
			return false
	await _settings_boost_acceleration(ship, driver)
	if not _failures.is_empty():
		return false
	if driver.desktop:
		var basis := ship.global_basis
		var witness := SettingsFlightMouseWitness.new()
		witness.process_physics_priority = ship.process_physics_priority + 1
		witness.ship = ship
		ship.add_child(witness)
		for frame in 4:
			driver.motion(Vector2(10.0, -5.0))
			await physics_frame
			await process_frame
		var mouse_rotation := (basis.inverse() * ship.global_basis).get_euler()
		witness.set_physics_process(false)
		var mouse_axes_seen := witness.mouse_axes_seen
		witness.queue_free()
		print("SETTINGS_FLIGHT_MOUSE_RESULT: %s" % JSON.stringify({
			"mouse_axes_seen": mouse_axes_seen,
			"x_rotation_seen": absf(mouse_rotation.x) > 0.0001,
			"y_rotation_seen": absf(mouse_rotation.y) > 0.0001,
			"rotation": [mouse_rotation.x, mouse_rotation.y, mouse_rotation.z],
		}))
		_check(mouse_axes_seen and absf(mouse_rotation.x) > 0.0001 and absf(mouse_rotation.y) > 0.0001,
			"desktop captured mouse yaw and pitch reach the real command and rotate both hull axes")
		await _settings_probe_control(ship, driver, &"brake", &"brake", true, true)
	# Fire is witnessed both at the consumed input and the real weapon signal.
	await _settings_fire(ship, driver, false)
	if driver.desktop:
		await _settings_fire(ship, driver, true)
	var before_roll := ship.global_basis
	await _settings_tap(driver, &"barrel_roll")
	_check(float(ship.get("_roll_animation")) > 0.0 and not ship.global_basis.is_equal_approx(before_roll), "%s barrel-roll press starts the real completed-over-time roll" % family)
	_check(await _wait_until(func() -> bool: return float(ship.get("_roll_animation")) <= 0.001, \
		360.0 / (ship.roll_speed_degrees * 2.2) + 0.5), "%s barrel roll finishes without a held or injected control" % family)
	if not _failures.is_empty():
		return false
	var capture := parked * Vector3(0.0, 8.0, -15.0)
	_check(await _fly_to_waypoint(ship, driver, capture, 1.0, 0.45), "%s physically returns to the registered berth capture" % family)
	_check(await _align_ship(ship, driver, (parked.origin - ship.global_position).normalized(), 0.995, 3.5), "%s native steering and hover align the actual landing approach" % family)
	await _brake_ship(ship, driver, 0.35, 1.2)
	var report := world.get_landing_assist_report(ship, berth_id)
	_check(bool(report.get("assist_capture_accepted", false)), "%s reaches its real landing capture contract" % family)
	if not _failures.is_empty():
		return false
	await _settings_tap(driver, &"landing_assist")
	_check(await _wait_until(func() -> bool: return ship.is_landing_active(), 0.6), "%s landing binding acquires ordinary landing assist" % family)
	_check(await _wait_until(func() -> bool: return game.phase == GameFlow.Phase.SHUT_DOWN, 4.5), "%s physically lands through the production shutdown phase" % family)
	driver.release_all()
	_check(await _wait_until(func() -> bool: return ship.get_telemetry().engine_state == &"OFFLINE", 2.0), "%s neutral controls reach the authored 1.5-second automatic shutdown" % family)
	_check(berth.get_occupant() == ship and berth.get_reservation_owner() == ship \
		and bool(ship.get_landing_contract_report().get("strict_dock_acceptance", false)), "%s landing restores exact berth and craft ownership" % family)
	if not _failures.is_empty():
		return false
	await _settings_tap(driver, &"interact")
	_check(await _wait_until(func() -> bool: return not ship.is_piloted() and not player.is_seated() \
		and player.is_control_enabled(), game.canopy_motion_time + game.disembarking_motion_time + 1.0),
		"%s physically exits to usable on-foot controls at the real craft exit" % family)
	_check(player.global_position.distance_to(ship.get_exit_transform().origin) < 0.25, "%s exit retains the actual physical disembark location" % family)
	driver.ship = null
	return _failures.is_empty()


func _settings_probe_control(ship: HeroShip, driver: SettingsNativeInputEvents, action: StringName, field: StringName, expected: Variant, mouse: bool = false) -> void:
	var before := ship.global_basis
	var observed := false
	var reversed := false
	driver.set_action(action, 1.0, mouse)
	for frame in range(18 if action == &"move_back" else 6):
		await physics_frame
		await process_frame
		var command := ship.get_last_ship_command()
		if command != null:
			observed = observed or (bool(command.get(field)) == bool(expected) if expected is bool \
				else float(command.get(field)) * float(expected) > 0.5)
			reversed = reversed or ship.velocity.dot(-ship.global_basis.z.normalized()) < -0.01
	driver.release_all()
	if action == &"move_back":
		_check(reversed, "%s reverse thrust physically moves the craft backwards" % ("desktop" if driver.desktop else "current gamepad"))
	var directional := field in [&"yaw", &"pitch", &"roll"]
	var physical := not ship.global_basis.is_equal_approx(before) if directional else true
	_check(observed and physical, "%s native %s reaches consumed %s%s%s" % [
		"desktop" if driver.desktop else "current gamepad", action, field, " via mouse" if mouse else "",
		" and rotates the real hull" if directional else ""])


func _settings_boost_acceleration(ship: HeroShip, driver: SettingsNativeInputEvents) -> void:
	# Compare two short real velocity windows under steady native thrust. No
	# camera, velocity, engine state or tuning is assigned by this scenario.
	var family := "desktop" if driver.desktop else "current gamepad"
	await _brake_ship(ship, driver, 0.25, 2.0)
	driver.set_action(&"move_forward", 1.0)
	_check(await _wait_until(func() -> bool: return float(ship.get_telemetry().throttle) >= 0.99, 1.0),
		"%s reaches steady ordinary thrust before comparing boost acceleration" % family)
	if not _failures.is_empty():
		driver.release_all()
		return
	var forward := -ship.global_basis.z.normalized()
	var velocity_before := ship.velocity.dot(forward)
	var frame_before := Engine.get_physics_frames()
	for frame in 6:
		await physics_frame
	var normal_time := float(Engine.get_physics_frames() - frame_before) / float(Engine.physics_ticks_per_second)
	var normal_acceleration := (ship.velocity.dot(forward) - velocity_before) / normal_time
	driver.set_action(&"sprint_boost", 1.0)
	velocity_before = ship.velocity.dot(forward)
	frame_before = Engine.get_physics_frames()
	var boost_consumed := false
	for frame in 6:
		await physics_frame
		var command := ship.get_last_ship_command()
		boost_consumed = boost_consumed or (command != null and command.boost and command.throttle > 0.99)
	var boost_time := float(Engine.get_physics_frames() - frame_before) / float(Engine.physics_ticks_per_second)
	var boost_acceleration := (ship.velocity.dot(forward) - velocity_before) / boost_time
	var authored_extra := ship.thrust_acceleration * (ship.boost_multiplier - 1.0) \
		* float(ship.get_telemetry().engine_power)
	driver.release_all()
	# Both windows stay at low speed; the 25% margin admits residual throttle
	# settling while still requiring the authored boost's added acceleration.
	_check(boost_consumed and authored_extra > 0.0 and normal_acceleration > 0.0 \
		and boost_acceleration - normal_acceleration > authored_extra * 0.75,
		"%s native boost increases real forward acceleration (ordinary=%.3f boosted=%.3f authored_extra=%.3f m/s²)" % [
			family, normal_acceleration, boost_acceleration, authored_extra,
		])


func _settings_fire(ship: HeroShip, driver: SettingsNativeInputEvents, mouse: bool) -> void:
	_check(await _wait_until(func() -> bool: return bool(ship.get_telemetry().weapon_ready), 2.5), "ordinary weapon cooldown permits the next native fire probe")
	var shots := [0]
	var on_shot := func(_origin: Vector3, _direction: Vector3) -> void: shots[0] += 1
	ship.projectile_fired.connect(on_shot)
	await _settings_probe_control(ship, driver, &"fire", &"fire", true, mouse)
	ship.projectile_fired.disconnect(on_shot)
	_check(shots[0] > 0, "%s native fire emits a real weapon shot%s" % ["desktop" if driver.desktop else "current gamepad", " via mouse" if mouse else ""])


func _settings_abort(game: GameFlow, desktop: SettingsNativeInputEvents, pad: SettingsNativeInputEvents) -> void:
	desktop.release_all()
	pad.release_all()
	paused = false
	await _clean_up(game, null)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	print("SETTINGS_REENTRY_INPUT_ROUTE_TEST_FAILED: ", "; ".join(_failures))
	quit(1)


func _sortie_tuning(game: GameFlow, ship: HeroShip) -> Dictionary:
	return {
		"canopy": game.canopy_motion_time, "boarding": game.boarding_motion_time, "exit": game.disembarking_motion_time,
		"weapon_cooldown": ship.weapon_cooldown, "maximum_speed": ship.maximum_speed,
		"thrust": ship.thrust_acceleration, "brake": ship.brake_acceleration, "drag": ship.passive_drag,
		"throttle_response": ship.throttle_response, "yaw": ship.yaw_speed_degrees, "assist": ship.flight_assist_strength,
	}


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
	arrival_radius: float,
	arrival_stop_speed: float = -1.0
	) -> bool:
	_sortie_timing_sample("fly_begin")
	var frame_budget := _frame_budget(FLIGHT_TRAVEL_SECONDS)
	var frames := 0
	var initial_sequence := -1
	var initial_basis := Basis.IDENTITY
	if _production_input_route:
		var initial_command := ship.get_last_ship_command()
		initial_sequence = initial_command.sequence if initial_command != null else -1
		initial_basis = ship.global_basis.orthonormalized()
	while frames < frame_budget:
		frames += 1
		var offset := waypoint - ship.global_position
		var distance := offset.length()
		if _sortie_diagnostics and (frames == 1 or frames % 120 == 0):
			_sortie_guidance_sample("fly", ship, offset.normalized(), distance, frames)
		if distance <= arrival_radius:
			_neutralize_flight_axes(provider)
			if arrival_stop_speed < 0.0 or ship.velocity.length() <= arrival_stop_speed:
				_sortie_timing_sample("fly_end_arrived")
				return true
			# The ordinary return must stop at its approach marker before aiming
			# at the berth. Crossing the marker at speed is not settled staging.
			provider.set_axis(AXIS_LEFT_TRIGGER, 1.0)
			await physics_frame
			continue
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
	var arrived := ship.global_position.distance_to(waypoint) <= arrival_radius \
		and (arrival_stop_speed < 0.0 or ship.velocity.length() <= arrival_stop_speed)
	if _production_input_route and not arrived:
		_print_guidance_failure(ship, waypoint - ship.global_position, frames, 0, initial_sequence, initial_basis)
		print("CONTROLLER_WAYPOINT_STAGING_FAILURE: ship_x=%.6f ship_y=%.6f ship_z=%.6f waypoint_x=%.6f waypoint_y=%.6f waypoint_z=%.6f speed=%.6f" % [
			ship.global_position.x, ship.global_position.y, ship.global_position.z,
			waypoint.x, waypoint.y, waypoint.z, ship.velocity.length(),
		])
	_sortie_timing_sample("fly_end_budget")
	return arrived


func _brake_ship(
	ship: HeroShip,
	provider: ControllerStateProvider,
	maximum_speed: float,
	nominal_seconds: float
	) -> bool:
	_sortie_timing_sample("brake_begin")
	_neutralize_flight_axes(provider)
	provider.set_axis(AXIS_LEFT_TRIGGER, 1.0)
	var stopped := await _wait_until(
		func() -> bool: return ship.velocity.length() <= maximum_speed,
		nominal_seconds
	)
	provider.set_axis(AXIS_LEFT_TRIGGER, 0.0)
	await physics_frame
	_sortie_timing_sample("brake_end")
	return stopped


func _align_ship(
	ship: HeroShip,
	provider: ControllerStateProvider,
	desired_direction: Vector3,
	minimum_dot: float,
	nominal_seconds: float
	) -> bool:
	_sortie_timing_sample("align_begin")
	var direction := desired_direction.normalized()
	var frame_budget := _frame_budget(nominal_seconds)
	var frames := 0
	var initial_sequence := -1
	var initial_basis := Basis.IDENTITY
	if _production_input_route:
		var initial_command := ship.get_last_ship_command()
		initial_sequence = initial_command.sequence if initial_command != null else -1
		initial_basis = ship.global_basis.orthonormalized()
	provider.set_button(BUTTON_A, true)
	while frames < frame_budget:
		frames += 1
		var forward := -ship.global_basis.z.normalized()
		if _sortie_diagnostics and (frames == 1 or frames % 120 == 0):
			_sortie_guidance_sample("align", ship, direction, -1.0, frames)
		if forward.dot(direction) >= minimum_dot and ship.global_basis.y.dot(Vector3.UP) > 0.94:
			_neutralize_flight_axes(provider)
			provider.set_button(BUTTON_A, false)
			await physics_frame
			_sortie_timing_sample("align_end_aligned")
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
	var aligned := (
		(-ship.global_basis.z.normalized()).dot(direction) >= minimum_dot
		and ship.global_basis.y.dot(Vector3.UP) > 0.94
	)
	if _production_input_route and not aligned:
		_print_guidance_failure(ship, direction, frames, 1, initial_sequence, initial_basis)
	_sortie_timing_sample("align_end_budget")
	return aligned


func _aim_and_fire_until_removed(
	ship: HeroShip,
	provider: ControllerStateProvider,
	target: Node3D,
	completion: Callable,
	nominal_seconds: float
	) -> bool:
	var frame_budget := _frame_budget(nominal_seconds)
	var frames := 0
	var minimum_alignment := 1.0
	var maximum_alignment := -1.0
	var gate_frames := 0
	var consumed_fire_frames := 0
	var initial_sample := Vector2(-1.0, -1.0)
	var initial_health := -1.0
	var previous_camera_position := Vector3.INF
	if _production_input_route:
		initial_sample = _aim_diagnostic_sample(ship, target)
		if target is RangeOpponent:
			initial_health = (target as RangeOpponent).get_health()
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
		if _production_input_route:
			minimum_alignment = minf(minimum_alignment, alignment)
			maximum_alignment = maxf(maximum_alignment, alignment)
			gate_frames += int(alignment >= 0.997)
		var yaw_demand := local_desired.x * 4.2
		var pitch_demand := local_desired.y * 4.2
		if _production_input_route and target is RangeOpponent:
			# Follow the observed line-of-sight angular motion with ordinary stick
			# demand; the existing positional feedback and fire gate stay intact.
			var camera_velocity := ship.velocity
			if previous_camera_position.is_finite():
				camera_velocity = (aiming_origin - previous_camera_position) / ship.get_physics_process_delta_time()
			previous_camera_position = aiming_origin
			var relative_velocity := (target as RangeOpponent).velocity - camera_velocity
			var angular_velocity := offset.cross(relative_velocity) / offset.length_squared()
			var local_angular_velocity := ship.global_basis.orthonormalized().inverse() * angular_velocity
			var turn_rate := deg_to_rad(ship.yaw_speed_degrees) * float(ship.get_telemetry().get("engine_power", 0.0))
			if turn_rate > 0.000001:
				yaw_demand -= local_angular_velocity.y / turn_rate
				pitch_demand += local_angular_velocity.x / turn_rate
		provider.set_axis(AXIS_LEFT_X, clampf(yaw_demand, -1.0, 1.0))
		provider.set_axis(AXIS_LEFT_Y, 0.0)
		provider.set_axis(AXIS_RIGHT_X, 0.0)
		provider.set_axis(AXIS_RIGHT_Y, -clampf(pitch_demand, -1.0, 1.0))
		provider.set_axis(AXIS_LEFT_TRIGGER, 1.0)
		provider.set_axis(AXIS_RIGHT_TRIGGER, 1.0 if alignment >= 0.997 else 0.0)
		# One simulation step per aim/fire update, for the reason given on
		# [method _fly_to_waypoint]. The firing gate reads `alignment` sampled on this
		# same tick, so an idle await here would fire against a stale alignment.
		await physics_frame
		if _production_input_route:
			var consumed := ship.get_last_ship_command()
			if consumed != null:
				consumed_fire_frames += int(consumed.fire)
	_neutralize_flight_axes(provider)
	var completed := bool(completion.call())
	if _production_input_route and not completed:
		var final_sample := _aim_diagnostic_sample(ship, target)
		var final_health := (target as RangeOpponent).get_health() if is_instance_valid(target) and target is RangeOpponent else -1.0
		print("CONTROLLER_AIM_FAILURE: frames=%d min_alignment=%.6f max_alignment=%.6f gate_frames=%d consumed_fire_frames=%d initial_health=%.3f final_health=%.3f initial_angular_rad_s=%.6f final_angular_rad_s=%.6f initial_camera_alignment=%.6f final_camera_alignment=%.6f" % [
			frames, minimum_alignment, maximum_alignment, gate_frames, consumed_fire_frames,
			initial_health, final_health, initial_sample.x, final_sample.x,
			initial_sample.y, final_sample.y,
		])
	return completed


## Numeric-only failure detail for unchanged waypoint/attitude guidance.
## kind=0 is waypoint travel; kind=1 is attitude alignment.
func _print_guidance_failure(ship: HeroShip, direction: Vector3, frames: int, kind: int, initial_sequence: int, initial_basis: Basis) -> void:
	var normalized := direction.normalized()
	var local_direction := ship.global_basis.orthonormalized().inverse() * normalized
	var consumed := ship.get_last_ship_command()
	print("CONTROLLER_GUIDANCE_FAILURE: kind=%d frames=%d local_x=%.6f local_y=%.6f local_z=%.6f forward_dot=%.6f upright_dot=%.6f consumed_hover=%d consumed_yaw=%.6f consumed_pitch=%.6f speed=%.6f" % [
		kind, frames, local_direction.x, local_direction.y, local_direction.z,
		(-ship.global_basis.z.normalized()).dot(normalized), ship.global_basis.y.dot(Vector3.UP),
		int(consumed.hover) if consumed != null else -1,
		consumed.yaw if consumed != null else 0.0, consumed.pitch if consumed != null else 0.0,
		ship.velocity.length(),
	])
	var telemetry := ship.get_telemetry()
	var forward := -ship.global_basis.z.normalized()
	var up := ship.global_basis.y.normalized()
	var basis_change := initial_basis.get_rotation_quaternion().angle_to(ship.global_basis.orthonormalized().get_rotation_quaternion())
	print("CONTROLLER_GUIDANCE_BRANCH_FAILURE: kind=%d tree_paused=%d can_process=%d physics_processing=%d piloted=%d landed=%d engine_state=%s engine_power=%.6f docked_latch=%d departure_lift_active=%d landing_active=%d start_sequence=%d end_sequence=%d basis_change_rad=%.6f desired_world_x=%.6f desired_world_y=%.6f desired_world_z=%.6f forward_x=%.6f forward_y=%.6f forward_z=%.6f up_x=%.6f up_y=%.6f up_z=%.6f" % [
		kind, int(paused), int(ship.can_process()), int(ship.is_physics_processing()),
		int(ship.is_piloted()), int(bool(telemetry.get("landed", false))),
		str(telemetry.get("engine_state", &"")), float(telemetry.get("engine_power", 0.0)),
		int(bool(ship.get("_docked_latch"))), int(bool(ship.get("_departure_lift_active"))),
		int(ship.is_landing_active()), initial_sequence, consumed.sequence if consumed != null else -1,
		basis_change, normalized.x, normalized.y, normalized.z,
		forward.x, forward.y, forward.z, up.x, up.y, up.z,
	])


## Read-only motion and reticle diagnostics; unavailable samples use -1.
func _aim_diagnostic_sample(ship: HeroShip, target: Node3D) -> Vector2:
	if not is_instance_valid(target):
		return Vector2(-1.0, -1.0)
	var camera := ship.get_camera()
	var offset := target.global_position - camera.global_position
	if offset.length_squared() <= 0.001:
		return Vector2(-1.0, -1.0)
	var angular_speed := -1.0
	if target is CharacterBody3D:
		var relative_velocity := (target as CharacterBody3D).velocity - ship.velocity
		angular_speed = offset.cross(relative_velocity).length() / offset.length_squared()
	var screen_center := camera.get_viewport().get_visible_rect().size * 0.5
	var camera_alignment := camera.project_ray_normal(screen_center).normalized().dot(offset.normalized())
	return Vector2(angular_speed, camera_alignment)


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
	if is_instance_valid(_boot):
		_boot.queue_free()
	elif is_instance_valid(game):
		game.queue_free()
	await process_frame
	await physics_frame
	await process_frame


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if _sortie_diagnostics:
		_sortie_timing_sample("check_%d" % _assertions)
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


## Optional latest CPU/render monitor samples, not stage averages or GPU times.
func _sortie_timing_sample(stage: String) -> void:
	if not _sortie_diagnostics:
		return
	var wall_ms := Time.get_ticks_msec()
	var physics_frame_count := Engine.get_physics_frames()
	var process_frame_count := Engine.get_process_frames()
	print("SORTIE_DIAGNOSTICS_SAMPLE: stage=%s wall_ms=%d delta_wall_ms=%d physics_frames=%d delta_physics_frames=%d process_frames=%d delta_process_frames=%d fps=%.3f latest_process_ms=%.6f latest_physics_ms=%.6f latest_draw_calls=%d latest_primitives=%d" % [
		stage, wall_ms, wall_ms - _diagnostic_wall_ms if _diagnostic_wall_ms >= 0 else 0,
		physics_frame_count, physics_frame_count - _diagnostic_physics_frame if _diagnostic_physics_frame >= 0 else 0,
		process_frame_count, process_frame_count - _diagnostic_process_frame if _diagnostic_process_frame >= 0 else 0,
		Engine.get_frames_per_second(), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
	])
	_diagnostic_wall_ms = wall_ms
	_diagnostic_physics_frame = physics_frame_count
	_diagnostic_process_frame = process_frame_count


func _sortie_guidance_sample(kind: String, ship: HeroShip, desired: Vector3, distance: float, step: int) -> void:
	var command := ship.get_last_ship_command()
	var telemetry := ship.get_telemetry()
	_sortie_timing_sample("%s_step_%d" % [kind, step])
	print("SORTIE_DIAGNOSTICS_GUIDANCE: kind=%s step=%d position_x=%.6f position_y=%.6f position_z=%.6f desired_x=%.6f desired_y=%.6f desired_z=%.6f distance=%.6f speed=%.6f forward_dot=%.6f consumed_sequence=%d consumed_yaw=%.6f consumed_pitch=%.6f consumed_throttle=%.6f consumed_brake=%d" % [
		kind, step, ship.global_position.x, ship.global_position.y, ship.global_position.z,
		desired.x, desired.y, desired.z, distance, ship.velocity.length(),
		(-ship.global_basis.z.normalized()).dot(desired), command.sequence if command != null else -1,
		command.yaw if command != null else 0.0, command.pitch if command != null else 0.0,
		command.throttle if command != null else 0.0, int(command.brake) if command != null else -1,
	])
	print("SORTIE_DIAGNOSTICS_CONTACT_STATE: kind=%s step=%d actual_throttle=%.6f engine_power=%.6f slide_collision_count=%d" % [
		kind, step, float(telemetry.get("throttle", 0.0)), float(telemetry.get("engine_power", 1.0)),
		ship.get_slide_collision_count(),
	])
	for collision_index: int in ship.get_slide_collision_count():
		var collision := ship.get_slide_collision(collision_index)
		var normal := collision.get_normal()
		var local_shape := collision.get_local_shape()
		var shape_name := str((local_shape as Node).name).c_escape().replace(" ", "_") if local_shape is Node else "unknown"
		var collider := collision.get_collider()
		print("SORTIE_DIAGNOSTICS_CONTACT: kind=%s step=%d index=%d normal_x=%.6f normal_y=%.6f normal_z=%.6f local_shape=%s collider_class=%s" % [
			kind, step, collision_index, normal.x, normal.y, normal.z, shape_name,
			collider.get_class() if is_instance_valid(collider) else "none",
		])


func _finish() -> void:
	var expected := PRODUCTION_INPUT_ASSERTIONS if _production_input_route else EXPECTED_ASSERTIONS
	if _assertions != expected:
		_failures.append(
			"assertion contract drifted: expected %d, observed %d"
			% [expected, _assertions]
		)
	if _failures.is_empty():
		print("CONTROLLER_PHYSICAL_SORTIE_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		print("CONTROLLER_PHYSICAL_SORTIE_TEST_FAILED: ", "; ".join(_failures))
		quit(1)
