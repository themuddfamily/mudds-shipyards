extends SceneTree

const LocalShipInputSourceType := preload("res://scripts/control/local_ship_input_source.gd")

const STICK_DEADZONE := 0.18
const LOOK_PIXELS_PER_FULL_AXIS := 100.0
const HERO_LOOK_DEGREES_PER_FULL_AXIS := 18.0

# Godot's standardized SDL-compatible joypad indices.
const AXIS_LEFT_X := 0
const AXIS_LEFT_Y := 1
const AXIS_RIGHT_X := 2
const AXIS_RIGHT_Y := 3
const AXIS_LEFT_TRIGGER := 4
const AXIS_RIGHT_TRIGGER := 5
const BUTTON_A := 0
const BUTTON_B := 1
const BUTTON_X := 2
const BUTTON_Y := 3
const BUTTON_BACK := 4
const BUTTON_START := 6
const BUTTON_LEFT_STICK := 7
const BUTTON_LEFT_SHOULDER := 9
const BUTTON_RIGHT_SHOULDER := 10
const BUTTON_DPAD_UP := 11
const BUTTON_DPAD_DOWN := 12
const BUTTON_DPAD_LEFT := 13
const BUTTON_DPAD_RIGHT := 14

const GAMEPLAY_ACTIONS: Array[StringName] = [
	&"move_forward", &"move_back", &"move_left", &"move_right",
	&"pitch_up", &"pitch_down", &"roll_left", &"roll_right",
	&"jump", &"sprint_boost", &"interact",
	&"hover", &"fire", &"barrel_roll", &"landing_assist",
	&"toggle_ship_camera_view", &"camera_distance_in", &"camera_distance_out",
	&"brake", &"pause", &"toggle_controls_overlay", &"toggle_first_person",
]

# Every action a player must reach to finish one complete shift, paired with the
# loop step it serves. Enumerated from the project InputMap rather than prose so
# a keyboard-only regression on any single step turns this audit red.
const LOOP_CRITICAL_ACTIONS := {
	&"interact": "begin shift / board / operate doors / disembark",
	&"jump": "begin shift alternate and on-foot traversal",
	&"move_forward": "walk to the craft and apply forward throttle",
	&"move_back": "walk back and apply reverse throttle",
	&"move_left": "strafe on foot and yaw left",
	&"move_right": "strafe on foot and yaw right",
	&"sprint_boost": "sprint on foot and boost in flight",
	&"pitch_up": "pitch up during flight and landing approach",
	&"pitch_down": "pitch down during flight and landing approach",
	&"roll_left": "roll left during flight",
	&"roll_right": "roll right during flight",
	&"brake": "decelerate for combat and dock approach",
	&"fire": "engage the range targets and the defender",
	&"hover": "hold station while lining up a berth",
	&"landing_assist": "request the strict landing contract",
	&"pause": "pause and reach the settings panel",
	&"toggle_controls_overlay": "read the in-game control reference",
}

var _failures: Array[String] = []


class NeutralInputProvider:
	extends RefCounted

	func get_action_strength(_action: StringName) -> float:
		return 0.0

	func is_action_pressed(_action: StringName) -> bool:
		return false


class MutableInputProvider:
	extends RefCounted

	var strengths: Dictionary = {}
	var pressed: Dictionary = {}

	func get_action_strength(action: StringName) -> float:
		return float(strengths.get(action, 0.0))

	func is_action_pressed(action: StringName) -> bool:
		return bool(pressed.get(action, false))

	func set_pressed(action: StringName, value: bool) -> void:
		pressed[action] = value
		strengths[action] = 1.0 if value else 0.0


class FocusReportingSource:
	extends LocalShipInputSource

	var reported_focus := true

	func _query_application_focus() -> bool:
		return reported_focus


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_keyboard_attitude_bindings()
	_test_loop_critical_actions_reach_the_gamepad()
	_test_controller_mapping_and_deadzone()
	_test_new_controller_bindings_are_collision_free()
	_test_system_edges_and_camera_distance_backlog()
	await _test_focus_and_tree_reentry_boundaries()
	await _test_scene_tree_pause_boundary()
	await _test_detached_focus_resynchronization()
	_test_mouse_backlog_chunking()
	_test_mouse_attitude_is_sampling_rate_stable()
	await process_frame
	_finish()


func _test_keyboard_attitude_bindings() -> void:
	_check(_has_physical_key(&"pitch_up", KEY_UP), "Up Arrow provides an explicit keyboard pitch-up axis")
	_check(_has_physical_key(&"pitch_down", KEY_DOWN), "Down Arrow provides an explicit keyboard pitch-down axis")
	_check(_has_physical_key(&"roll_left", KEY_Q), "Q provides an explicit keyboard roll-left axis")
	_check(_has_physical_key(&"roll_right", KEY_R), "R provides an explicit keyboard roll-right axis")
	_check(
		_has_physical_key(&"interact", KEY_E) and not _has_physical_key(&"roll_right", KEY_E),
		"E remains interaction-only and cannot roll the craft while exiting"
	)
	_check(
		not InputMap.has_action(&"engine_start") and not InputMap.has_action(&"engine_stop"),
		"retired manual engine actions are absent from the authored InputMap"
	)
	_check(_has_physical_key(&"landing_assist", KEY_L), "L still engages landing assist")
	_check(_has_physical_key(&"toggle_ship_camera_view", KEY_V), "V still toggles the ship camera")
	_check(_has_mouse_button(&"fire", MOUSE_BUTTON_LEFT), "left mouse still fires")
	_check(_has_mouse_button(&"brake", MOUSE_BUTTON_RIGHT), "right mouse still brakes")
	_check(
		_has_physical_key(&"toggle_controls_overlay", KEY_F1),
		"F1 still toggles the controls overlay after it became a mapped action"
	)
	# The on-foot view toggle deliberately does not reuse V. V is the *ship*
	# camera and is live in the same session; one key that means two different
	# cameras depending on where you are standing is the kind of binding players
	# learn wrong once and never trust again.
	_check(
		_has_physical_key(&"toggle_first_person", KEY_C)
		and not _has_physical_key(&"toggle_ship_camera_view", KEY_C),
		"C toggles the on-foot first/third person view without colliding with V"
	)


## Loop coverage, not tuning: each action a full shift requires must be usable
## without a keyboard, and no loop action may sit outside the audited roster.
func _test_loop_critical_actions_reach_the_gamepad() -> void:
	for action: StringName in LOOP_CRITICAL_ACTIONS:
		_check(
			InputMap.has_action(action),
			"loop-critical action %s exists in the project InputMap" % action
		)
		_check(
			_has_any_joypad_event(action),
			"%s is reachable from the gamepad (%s)" % [
				action,
				str(LOOP_CRITICAL_ACTIONS[action]),
			]
		)
		_check(
			GAMEPLAY_ACTIONS.has(action),
			"loop-critical action %s stays inside the audited gameplay roster" % action
		)
	var unreachable: Array[StringName] = []
	for action: StringName in GAMEPLAY_ACTIONS:
		if not _has_any_joypad_event(action):
			unreachable.append(action)
	_check(
		unreachable.is_empty(),
		"no audited gameplay action remains keyboard-only (offenders: %s)" % str(unreachable)
	)


func _test_controller_mapping_and_deadzone() -> void:
	var expected_axes := [
		[&"move_forward", AXIS_LEFT_Y, -1.0, "left-stick up controls forward throttle"],
		[&"move_back", AXIS_LEFT_Y, 1.0, "left-stick down controls reverse throttle"],
		[&"move_left", AXIS_LEFT_X, -1.0, "left-stick left controls yaw left"],
		[&"move_right", AXIS_LEFT_X, 1.0, "left-stick right controls yaw right"],
		[&"pitch_up", AXIS_RIGHT_Y, -1.0, "right-stick up controls pitch up"],
		[&"pitch_down", AXIS_RIGHT_Y, 1.0, "right-stick down controls pitch down"],
		[&"roll_left", AXIS_RIGHT_X, -1.0, "right-stick left controls roll left"],
		[&"roll_right", AXIS_RIGHT_X, 1.0, "right-stick right controls roll right"],
		[&"brake", AXIS_LEFT_TRIGGER, 1.0, "left trigger controls braking"],
		[&"fire", AXIS_RIGHT_TRIGGER, 1.0, "right trigger controls fire"],
	]
	for expected: Array in expected_axes:
		var action := expected[0] as StringName
		_check(
			_has_joy_axis(action, int(expected[1]), float(expected[2])),
			str(expected[3])
		)
		_check(
			is_equal_approx(InputMap.action_get_deadzone(action), STICK_DEADZONE),
			"%s uses the calibrated %.2f controller deadzone" % [action, STICK_DEADZONE]
		)

	var expected_buttons := [
		[&"sprint_boost", BUTTON_LEFT_STICK, "L3 controls boost"],
		[&"hover", BUTTON_A, "A controls hover assist while piloting"],
		[&"barrel_roll", BUTTON_B, "B triggers the classic barrel roll"],
		[&"interact", BUTTON_X, "X controls interaction"],
		[&"toggle_ship_camera_view", BUTTON_Y, "Y toggles the ship camera"],
		[&"landing_assist", BUTTON_DPAD_LEFT, "D-pad Left engages landing assist"],
		[&"toggle_first_person", BUTTON_DPAD_RIGHT, "D-pad Right toggles the on-foot view"],
		[&"camera_distance_in", BUTTON_LEFT_SHOULDER, "LB moves the chase camera nearer"],
		[&"camera_distance_out", BUTTON_RIGHT_SHOULDER, "RB moves the chase camera farther"],
		[&"pause", BUTTON_START, "Start opens pause"],
		[&"toggle_controls_overlay", BUTTON_BACK, "Back opens the controls overlay"],
	]
	for expected: Array in expected_buttons:
		var action := expected[0] as StringName
		_check(
			_has_joy_button(action, int(expected[1])),
			str(expected[2])
		)
		_check(
			is_equal_approx(InputMap.action_get_deadzone(action), STICK_DEADZONE),
			"%s uses the calibrated %.2f controller deadzone" % [action, STICK_DEADZONE]
		)


func _test_new_controller_bindings_are_collision_free() -> void:
	var expected_bindings := {
		&"landing_assist": BUTTON_DPAD_LEFT,
		&"toggle_first_person": BUTTON_DPAD_RIGHT,
		&"camera_distance_in": BUTTON_LEFT_SHOULDER,
		&"camera_distance_out": BUTTON_RIGHT_SHOULDER,
		&"toggle_controls_overlay": BUTTON_BACK,
	}
	var distinct_buttons := {}
	for action: StringName in expected_bindings:
		var button_index := int(expected_bindings[action])
		distinct_buttons[button_index] = true
		var users := _gameplay_actions_for_joy_button(button_index)
		_check(
			users.size() == 1 and users[0] == action,
			"%s owns controller button %d without a gameplay mapping collision" % [
				action,
				button_index,
			]
		)
	_check(
		distinct_buttons.size() == expected_bindings.size(),
		"every newly completed controller action has a distinct physical button"
	)


func _test_system_edges_and_camera_distance_backlog() -> void:
	var provider := MutableInputProvider.new()
	provider.strengths[&"move_forward"] = 0.65
	for action: StringName in [
		&"barrel_roll",
		&"landing_assist",
		&"camera_distance_in",
	]:
		provider.set_pressed(action, true)
	var source := LocalShipInputSourceType.new() as LocalShipInputSource
	source.set_input_provider(provider)
	var first := source.next_command(3000)
	var held := source.next_command(3001)
	_check(
		first.barrel_roll and first.landing
		and not first.engine_start and not first.engine_stop,
		"live controller edges are sampled without resurrecting retired engine fields"
	)
	_check(
		is_equal_approx(first.camera_distance_delta, -1.0),
		"camera-near enters ShipCommand as one signed distance step"
	)
	_check(
		is_equal_approx(first.throttle, 0.65)
		and is_equal_approx(held.throttle, 0.65),
		"held analogue input remains sampled on every command"
	)
	_check(
		not held.barrel_roll
		and not held.landing
		and is_zero_approx(held.camera_distance_delta),
		"held lifecycle and camera buttons cannot repeat edge-triggered commands"
	)
	for action: StringName in [
		&"barrel_roll",
		&"landing_assist",
		&"camera_distance_in",
	]:
		provider.set_pressed(action, false)
	source.next_command(3002)
	provider.set_pressed(&"camera_distance_out", true)
	_check(
		is_equal_approx(source.next_command(3003).camera_distance_delta, 1.0),
		"camera-far produces the opposite signed edge after release"
	)
	provider.set_pressed(&"camera_distance_out", false)
	source.next_command(3004)
	source.queue_camera_distance_delta(2.5)
	var queued_first := source.next_command(3005)
	var queued_second := source.next_command(3006)
	var queued_tail := source.next_command(3007)
	_check(
		is_equal_approx(queued_first.camera_distance_delta, 1.0)
		and is_equal_approx(queued_second.camera_distance_delta, 1.0)
		and is_equal_approx(queued_tail.camera_distance_delta, 0.5),
		"multiple wheel steps drain through bounded command deltas without being lost"
	)
	source.queue_camera_distance_delta(-3.0)
	source.clear_pending_camera_distance_delta()
	_check(
		is_zero_approx(source.next_command(3008).camera_distance_delta),
		"explicit camera-distance clearing drops the complete queued edge backlog"
	)
	source.free()


func _test_focus_and_tree_reentry_boundaries() -> void:
	var provider := MutableInputProvider.new()
	provider.strengths[&"move_forward"] = 0.7
	var source := LocalShipInputSourceType.new() as LocalShipInputSource
	root.add_child(source)
	source.set_input_provider(provider)
	source.next_command(4000)
	provider.set_pressed(&"landing_assist", true)
	provider.set_pressed(&"camera_distance_out", true)
	var initial_edges := source.next_command(4001)
	_check(
		initial_edges.landing
		and is_equal_approx(initial_edges.camera_distance_delta, 1.0),
		"focused input produces lifecycle and camera edges normally"
	)
	source.queue_look_motion(Vector2(40.0, -30.0))
	source.queue_camera_distance_delta(2.0)
	source.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(
		source.next_command(4002).is_neutral(),
		"focus loss immediately neutralizes held and queued local input"
	)
	source.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	var focus_return := source.next_command(4003)
	_check(
		is_equal_approx(focus_return.throttle, 0.7)
		and not focus_return.landing
		and is_zero_approx(focus_return.camera_distance_delta)
		and is_zero_approx(focus_return.look_yaw_delta)
		and is_zero_approx(focus_return.look_pitch_delta),
		"focus return restores held axes but primes held edges and clears stale impulses"
	)
	provider.set_pressed(&"landing_assist", false)
	provider.set_pressed(&"camera_distance_out", false)
	source.next_command(4004)
	provider.set_pressed(&"landing_assist", true)
	provider.set_pressed(&"camera_distance_out", true)
	var focus_repress := source.next_command(4005)
	_check(
		focus_repress.landing
		and is_equal_approx(focus_repress.camera_distance_delta, 1.0),
		"release and repress after focus return creates exactly one fresh edge"
	)

	provider.set_pressed(&"landing_assist", false)
	provider.set_pressed(&"camera_distance_out", false)
	source.next_command(4006)
	root.remove_child(source)
	provider.set_pressed(&"landing_assist", true)
	provider.set_pressed(&"camera_distance_in", true)
	source.queue_look_motion(Vector2(80.0, 20.0))
	source.queue_camera_distance_delta(-2.0)
	root.add_child(source)
	var reentered := source.next_command(4007)
	_check(
		is_equal_approx(reentered.throttle, 0.7)
		and not reentered.landing
		and is_zero_approx(reentered.camera_distance_delta)
		and is_zero_approx(reentered.look_yaw_delta),
		"tree re-entry rejects detached impulses and primes buttons held during detachment"
	)
	var reentered_held := source.next_command(4008)
	_check(
		not reentered_held.landing
		and is_zero_approx(reentered_held.camera_distance_delta),
		"held edges remain suppressed throughout the re-entered stream"
	)
	provider.set_pressed(&"landing_assist", false)
	provider.set_pressed(&"camera_distance_in", false)
	source.next_command(4009)
	provider.set_pressed(&"landing_assist", true)
	provider.set_pressed(&"camera_distance_in", true)
	var reentry_repress := source.next_command(4010)
	_check(
		reentry_repress.landing
		and is_equal_approx(reentry_repress.camera_distance_delta, -1.0),
		"release and repress after tree re-entry produces one fresh controller edge"
	)
	source.queue_free()
	await process_frame


func _test_scene_tree_pause_boundary() -> void:
	var provider := MutableInputProvider.new()
	var source := LocalShipInputSourceType.new() as LocalShipInputSource
	root.add_child(source)
	source.set_input_provider(provider)
	source.next_command(5000)
	# Stage both sampled and unsampled transients before pausing. The pause boundary
	# must revoke all of them, including the lifecycle FIFO copy.
	provider.set_pressed(&"landing_assist", true)
	var staged_edge := source.next_command(5001)
	var generation_before_pause := source.get_delivery_generation()
	source.queue_look_motion(Vector2(70.0, -50.0))
	source.queue_camera_distance_delta(2.0)
	source.queue_action_edge(&"landing_assist")
	paused = true
	provider.set_pressed(&"landing_assist", false)
	provider.set_pressed(&"interact", true)
	provider.set_pressed(&"camera_distance_out", true)
	provider.strengths[&"move_forward"] = 0.8
	# Queues attempted while SceneTree-paused must also be rejected.
	source.queue_look_motion(Vector2(100.0, 100.0))
	source.queue_camera_distance_delta(-3.0)
	source.queue_action_edge(&"interact")
	var paused_sample := source.next_command(5002)
	_check(
		staged_edge.landing
		and paused_sample.is_neutral()
		and source.get_delivery_generation() > generation_before_pause
		and source.drain_pending_commands().is_empty(),
		"SceneTree pause revokes sampled delivery and neutralizes held or queued flight input"
	)
	paused = false
	var generation_after_unpause := source.get_delivery_generation()
	var resumed := source.next_command(5003)
	var resumed_held := source.next_command(5004)
	_check(
		is_equal_approx(resumed.throttle, 0.8)
		and not resumed.landing
		and not resumed.interact
		and is_zero_approx(resumed.camera_distance_delta)
		and is_zero_approx(resumed.look_yaw_delta)
		and is_zero_approx(resumed.look_pitch_delta)
		and not resumed_held.interact
		and is_zero_approx(resumed_held.camera_distance_delta),
		"unpause restores held axes but primes paused UI/controller buttons without manufacturing edges"
	)
	_check(
		_has_joy_button(&"ui_down", BUTTON_DPAD_DOWN)
		and not InputMap.has_action(&"engine_stop"),
		"D-pad Down remains UI navigation without a live manual engine action"
	)
	provider.set_pressed(&"interact", false)
	provider.set_pressed(&"camera_distance_out", false)
	source.next_command(5005)
	provider.set_pressed(&"interact", true)
	provider.set_pressed(&"camera_distance_out", true)
	var repressed := source.next_command(5006)
	_check(
		repressed.interact
		and is_equal_approx(repressed.camera_distance_delta, 1.0),
		"release and repress after unpause creates exactly one fresh controller edge"
	)
	_check(
		source.drain_pending_commands(generation_before_pause).is_empty(),
		"pre-pause delivery generation cannot drain the resumed queue"
	)
	var resumed_batch := source.drain_pending_commands(generation_after_unpause)
	_check(
		resumed_batch.size() == 1 and resumed_batch[0].interact,
		"stale-generation rejection preserves the fresh post-pause lifecycle edge"
	)
	source.queue_free()
	await process_frame


func _test_detached_focus_resynchronization() -> void:
	var provider := MutableInputProvider.new()
	provider.strengths[&"move_forward"] = 0.7
	var source := FocusReportingSource.new()
	source.reported_focus = true
	root.add_child(source)
	source.set_input_provider(provider)
	source.next_command(6000)
	provider.set_pressed(&"landing_assist", true)
	var staged := source.next_command(6001)
	var generation_before_detach := source.get_delivery_generation()
	root.remove_child(source)
	# Focus is lost while detached, so no application notification reaches the
	# source. Re-entry must query current Window state instead of trusting its cache.
	source.reported_focus = false
	provider.set_pressed(&"landing_assist", true)
	source.queue_look_motion(Vector2(80.0, 30.0))
	source.queue_camera_distance_delta(2.0)
	source.queue_action_edge(&"interact")
	root.add_child(source)
	var reentered_unfocused := source.next_command(6002)
	_check(
		staged.landing
		and reentered_unfocused.is_neutral()
		and source.get_delivery_generation() > generation_before_detach
		and source.drain_pending_commands().is_empty(),
		"re-entry resnapshots missed detached focus loss and rejects stale delivery or impulses"
	)

	# Exercise the opposite missed transition: cached focus is false, focus returns
	# while detached, and held axes should resume without turning held buttons into
	# new edges.
	root.remove_child(source)
	source.reported_focus = true
	provider.set_pressed(&"camera_distance_in", true)
	source.queue_look_motion(Vector2(-90.0, -40.0))
	source.queue_camera_distance_delta(-2.0)
	root.add_child(source)
	var reentered_focused := source.next_command(6003)
	var reentered_held := source.next_command(6004)
	_check(
		is_equal_approx(reentered_focused.throttle, 0.7)
		and not reentered_focused.landing
		and is_zero_approx(reentered_focused.camera_distance_delta)
		and is_zero_approx(reentered_focused.look_yaw_delta)
		and not reentered_held.landing
		and is_zero_approx(reentered_held.camera_distance_delta),
		"re-entry resnapshots missed detached focus gain while priming every held edge"
	)
	for action: StringName in [&"landing_assist", &"camera_distance_in"]:
		provider.set_pressed(action, false)
	source.next_command(6005)
	provider.set_pressed(&"landing_assist", true)
	provider.set_pressed(&"camera_distance_in", true)
	var fresh := source.next_command(6006)
	_check(
		fresh.landing and is_equal_approx(fresh.camera_distance_delta, -1.0),
		"release and repress after focus-resynchronized re-entry creates one fresh edge"
	)
	source.queue_free()
	await process_frame


func _test_mouse_backlog_chunking() -> void:
	var source := _make_source()
	source.queue_look_motion(Vector2(250.0, -150.0))
	var first := source.next_command(1000)
	var second := source.next_command(1001)
	var third := source.next_command(1002)
	var drained := source.next_command(1003)
	_check(
		is_equal_approx(first.look_yaw_delta, 1.0)
		and is_equal_approx(first.look_pitch_delta, 1.0),
		"a coalesced mouse burst is bounded to one look impulse per component per tick"
	)
	_check(
		is_equal_approx(second.look_yaw_delta, 1.0)
		and is_equal_approx(second.look_pitch_delta, 0.5)
		and is_equal_approx(third.look_yaw_delta, 0.5)
		and is_zero_approx(third.look_pitch_delta),
		"excess mouse motion drains over later commands instead of being discarded"
	)
	_check(
		is_zero_approx(drained.look_yaw_delta)
		and is_zero_approx(drained.look_pitch_delta),
		"mouse backlog reaches an exact neutral command after its physical delta is consumed"
	)
	source.free()


func _test_mouse_attitude_is_sampling_rate_stable() -> void:
	# Model a 0.1 second mouse sweep. At 30 Hz each 120 px sample exceeds the
	# per-command bound; 60 and 120 Hz do not. All rates must nevertheless produce
	# the same HeroShip-style attitude once their backlog has drained.
	var physical_sweep := 360.0
	var yaw_30 := _sampled_attitude(30, Vector2(physical_sweep, 0.0))
	var yaw_60 := _sampled_attitude(60, Vector2(physical_sweep, 0.0))
	var yaw_120 := _sampled_attitude(120, Vector2(physical_sweep, 0.0))
	var pitch_30 := _sampled_attitude(30, Vector2(0.0, -physical_sweep))
	var pitch_60 := _sampled_attitude(60, Vector2(0.0, -physical_sweep))
	var pitch_120 := _sampled_attitude(120, Vector2(0.0, -physical_sweep))
	var expected_attitude_degrees := (
		physical_sweep / LOOK_PIXELS_PER_FULL_AXIS * HERO_LOOK_DEGREES_PER_FULL_AXIS
	)
	var expected_yaw := Basis(Vector3.UP, -deg_to_rad(expected_attitude_degrees))
	var expected_pitch := Basis(Vector3.RIGHT, deg_to_rad(expected_attitude_degrees))
	_check(
		yaw_30.is_equal_approx(yaw_60)
		and yaw_60.is_equal_approx(yaw_120)
		and yaw_30.is_equal_approx(expected_yaw),
		"30/60/120 Hz sampling reaches the same final yaw attitude after backlog drain"
	)
	_check(
		pitch_30.is_equal_approx(pitch_60)
		and pitch_60.is_equal_approx(pitch_120)
		and pitch_30.is_equal_approx(expected_pitch),
		"30/60/120 Hz sampling reaches the same final pitch attitude after backlog drain"
	)


func _sampled_attitude(sample_rate: int, total_motion: Vector2) -> Basis:
	var source := _make_source()
	var attitude_probe := Node3D.new()
	var sample_count := maxi(1, int(round(float(sample_rate) * 0.1)))
	var motion_per_sample := total_motion / float(sample_count)
	var timestamp := 2000
	for _sample_index in sample_count:
		source.queue_look_motion(motion_per_sample)
		var command := source.next_command(timestamp)
		_apply_hero_look(attitude_probe, command.look_yaw_delta, command.look_pitch_delta)
		timestamp += 1
	# The largest test sweep needs fewer than four residual ticks. Keep a generous
	# deterministic ceiling so a regression cannot hang the suite indefinitely.
	for _drain_index in 16:
		var command := source.next_command(timestamp)
		timestamp += 1
		var impulse := Vector2(command.look_yaw_delta, command.look_pitch_delta)
		if impulse.is_zero_approx():
			break
		_apply_hero_look(attitude_probe, impulse.x, impulse.y)
	var result := attitude_probe.basis
	attitude_probe.free()
	source.free()
	return result


func _apply_hero_look(attitude: Node3D, yaw_delta: float, pitch_delta: float) -> void:
	# This is the unchanged HeroShip look-consumer contract: a normalized angular
	# impulse followed by local yaw, local pitch, and basis orthonormalization.
	attitude.rotate_object_local(
		Vector3.UP,
		-yaw_delta * deg_to_rad(HERO_LOOK_DEGREES_PER_FULL_AXIS)
	)
	attitude.rotate_object_local(
		Vector3.RIGHT,
		pitch_delta * deg_to_rad(HERO_LOOK_DEGREES_PER_FULL_AXIS)
	)
	attitude.basis = attitude.basis.orthonormalized()


func _make_source() -> LocalShipInputSource:
	var source := LocalShipInputSourceType.new()
	source.look_motion_for_full_axis = LOOK_PIXELS_PER_FULL_AXIS
	source.set_input_provider(NeutralInputProvider.new())
	return source


func _has_physical_key(action: StringName, physical_keycode: Key) -> bool:
	if not InputMap.has_action(action):
		return false
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == physical_keycode:
			return true
	return false


func _has_mouse_button(action: StringName, button_index: MouseButton) -> bool:
	if not InputMap.has_action(action):
		return false
	for event: InputEvent in InputMap.action_get_events(action):
		if (
			event is InputEventMouseButton
			and (event as InputEventMouseButton).button_index == button_index
		):
			return true
	return false


func _has_joy_axis(action: StringName, axis: int, direction: float) -> bool:
	if not InputMap.has_action(action):
		return false
	for event: InputEvent in InputMap.action_get_events(action):
		if event is not InputEventJoypadMotion:
			continue
		var motion := event as InputEventJoypadMotion
		if motion.axis == axis and is_equal_approx(motion.axis_value, direction):
			return true
	return false


func _has_joy_button(action: StringName, button_index: int) -> bool:
	if not InputMap.has_action(action):
		return false
	for event: InputEvent in InputMap.action_get_events(action):
		if (
			event is InputEventJoypadButton
			and (event as InputEventJoypadButton).button_index == button_index
		):
			return true
	return false


func _has_any_joypad_event(action: StringName) -> bool:
	if not InputMap.has_action(action):
		return false
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventJoypadButton or event is InputEventJoypadMotion:
			return true
	return false


func _gameplay_actions_for_joy_button(button_index: int) -> Array[StringName]:
	var users: Array[StringName] = []
	for action: StringName in GAMEPLAY_ACTIONS:
		if _has_joy_button(action, button_index):
			users.append(action)
	return users


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("CONTROL_MAPPING_TEST_OK")
		quit(0)
	else:
		print("CONTROL_MAPPING_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
