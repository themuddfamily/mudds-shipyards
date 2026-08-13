extends SceneTree

const TORRENT_SCENE := preload("res://scenes/ships/torrent_interceptor.tscn")
const HUD_SCENE := preload("res://scenes/ui/hud.tscn")
const LocalShipInputSourceType := preload("res://scripts/control/local_ship_input_source.gd")

const INPUT_DEADZONE := 0.18
const INPUT_DEADZONE_TOLERANCE := 0.005
const MOUSE_SAMPLE_RATES: Array[int] = [30, 60, 120]
const MOUSE_TRIAL_SECONDS := 0.5
const MOUSE_TOTAL_MOTION := Vector2(180.0, -90.0)
const MOUSE_ATTITUDE_TOLERANCE_DEGREES := 0.12
const SATURATED_DIAGONAL_TRIAL_SECONDS := 0.1
const SATURATED_DIAGONAL_TOTAL_MOTION := Vector2(360.0, -360.0)
const SATURATED_DIAGONAL_PIXELS_PER_FULL_AXIS := 100.0
const SATURATED_DIAGONAL_TOLERANCE_DEGREES := 0.01
const SATURATED_DIAGONAL_DRAIN_LIMIT := 16
const CHASE_ROTATION_RESPONSE := 7.0
const CHASE_MAXIMUM_LAG_DEGREES := 8.0

var _failures: Array[String] = []
var _stage: Node3D


class FakeInputProvider:
	extends RefCounted

	var strengths: Dictionary = {}
	var pressed: Dictionary = {}

	func get_action_strength(action: StringName) -> float:
		return float(strengths.get(action, 0.0))

	func is_action_pressed(action: StringName) -> bool:
		return bool(pressed.get(action, false))


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_stage = Node3D.new()
	_stage.name = "FlightQualityClosureTestRoot"
	root.add_child(_stage)

	_test_production_input_map()
	_test_local_adapter_axis_contract()
	_test_mouse_backlog_conservation()
	await _test_mouse_attitude_frame_rate_stability()
	await _test_saturated_diagonal_mouse_attitude_frame_rate_stability()
	await _test_parked_and_startup_mouse_boundaries()
	await _test_chase_response_bounds()
	await _test_cockpit_sight_contract()
	await _test_in_world_telemetry_hooks()

	_release_test_actions()
	_stage.queue_free()
	await process_frame
	_finish()


func _test_production_input_map() -> void:
	var keyboard_contract := {
		&"pitch_up": KEY_UP,
		&"pitch_down": KEY_DOWN,
		&"roll_left": KEY_Q,
		&"roll_right": KEY_R,
	}
	for action: StringName in keyboard_contract:
		_check(InputMap.has_action(action), "production InputMap defines %s" % action)
		_check(
			_action_has_physical_key(action, keyboard_contract[action]),
			"%s has its production physical-key binding" % action
		)

	var analogue_contract := [
		[&"move_forward", JOY_AXIS_LEFT_Y, -1.0, "left-stick up throttle"],
		[&"move_back", JOY_AXIS_LEFT_Y, 1.0, "left-stick down reverse"],
		[&"move_left", JOY_AXIS_LEFT_X, -1.0, "left-stick left yaw"],
		[&"move_right", JOY_AXIS_LEFT_X, 1.0, "left-stick right yaw"],
		[&"pitch_up", JOY_AXIS_RIGHT_Y, -1.0, "right-stick up pitch"],
		[&"pitch_down", JOY_AXIS_RIGHT_Y, 1.0, "right-stick down pitch"],
		[&"roll_left", JOY_AXIS_RIGHT_X, -1.0, "right-stick left roll"],
		[&"roll_right", JOY_AXIS_RIGHT_X, 1.0, "right-stick right roll"],
		[&"fire", JOY_AXIS_TRIGGER_RIGHT, 1.0, "right trigger fire"],
		[&"brake", JOY_AXIS_TRIGGER_LEFT, 1.0, "left trigger brake"],
	]
	for mapping: Array in analogue_contract:
		var action := mapping[0] as StringName
		_check(InputMap.has_action(action), "production InputMap defines joypad action %s" % action)
		_check(
			_action_has_joy_axis(action, int(mapping[1]), float(mapping[2])),
			"%s maps %s" % [action, str(mapping[3])]
		)

	var button_contract := [
		[&"sprint_boost", JOY_BUTTON_LEFT_STICK, "left-stick press boost"],
		[&"hover", JOY_BUTTON_A, "A hover"],
		[&"barrel_roll", JOY_BUTTON_B, "B barrel roll"],
		[&"toggle_ship_camera_view", JOY_BUTTON_Y, "Y camera toggle"],
		[&"interact", JOY_BUTTON_X, "X interaction"],
	]
	for mapping: Array in button_contract:
		var action := mapping[0] as StringName
		_check(InputMap.has_action(action), "production InputMap defines joypad button action %s" % action)
		_check(
			_action_has_joy_button(action, int(mapping[1])),
			"%s maps %s" % [action, str(mapping[2])]
		)

	var flight_actions := PackedStringArray([
		"move_forward", "move_back", "move_left", "move_right",
		"pitch_up", "pitch_down", "roll_left", "roll_right",
		"sprint_boost", "brake", "hover", "fire", "barrel_roll",
		"toggle_ship_camera_view", "interact",
	])
	for action: String in flight_actions:
		_check(
			absf(InputMap.action_get_deadzone(action) - INPUT_DEADZONE) <= INPUT_DEADZONE_TOLERANCE,
			"%s uses the shared 0.18 controller deadzone" % action
		)


func _test_local_adapter_axis_contract() -> void:
	var provider := FakeInputProvider.new()
	provider.strengths = {
		&"move_forward": 0.8,
		&"move_back": 0.15,
		&"move_right": 0.55,
		&"move_left": 0.10,
		&"pitch_up": 0.7,
		&"pitch_down": 0.2,
		&"roll_right": 0.6,
		&"roll_left": 0.1,
	}
	provider.pressed = {
		&"sprint_boost": true,
		&"brake": true,
		&"hover": true,
		&"fire": true,
	}
	var source := LocalShipInputSourceType.new() as LocalShipInputSource
	_stage.add_child(source)
	source.set_input_provider(provider)
	var command := source.next_command(1000)
	_check(is_equal_approx(command.throttle, 0.65), "local adapter preserves signed controller throttle")
	_check(is_equal_approx(command.yaw, 0.45), "local adapter preserves signed controller yaw")
	_check(is_equal_approx(command.pitch, 0.5), "local adapter preserves signed controller pitch")
	_check(is_equal_approx(command.roll, 0.5), "local adapter preserves signed controller roll")
	_check(command.boost and command.brake and command.hover and command.fire, "local adapter carries controller held buttons into one command")
	source.queue_free()


func _test_mouse_backlog_conservation() -> void:
	var source := LocalShipInputSourceType.new() as LocalShipInputSource
	_stage.add_child(source)
	source.look_motion_for_full_axis = 100.0
	source.queue_look_motion(Vector2(250.0, -175.0))
	var commands: Array[ShipCommand] = []
	for index in 4:
		commands.append(source.next_command(2000 + index))
	_check(
		commands.size() == 4
		and is_equal_approx(commands[0].look_yaw_delta, 1.0)
		and is_equal_approx(commands[1].look_yaw_delta, 1.0)
		and is_equal_approx(commands[2].look_yaw_delta, 0.5)
		and is_zero_approx(commands[3].look_yaw_delta),
		"oversized horizontal mouse motion drains across ticks without saturation loss"
	)
	_check(
		commands.size() == 4
		and is_equal_approx(commands[0].look_pitch_delta, 1.0)
		and is_equal_approx(commands[1].look_pitch_delta, 0.75)
		and is_zero_approx(commands[2].look_pitch_delta)
		and is_zero_approx(commands[3].look_pitch_delta),
		"oversized vertical mouse motion drains independently without saturation loss"
	)
	source.clear_pending_look_motion()
	_check(source.next_command(2010).is_neutral(), "explicit input-boundary clear discards the complete mouse backlog")
	source.queue_free()


func _test_mouse_attitude_frame_rate_stability() -> void:
	var results: Dictionary = {}
	for samples_per_second: int in MOUSE_SAMPLE_RATES:
		var ship := await _make_online_ship("MouseRate%d" % samples_per_second)
		if ship == null:
			continue
		ship.velocity = Vector3(0.0, 0.0, -10.0)
		var start_basis := ship.global_basis
		var sample_count := maxi(1, roundi(float(samples_per_second) * MOUSE_TRIAL_SECONDS))
		var per_sample := MOUSE_TOTAL_MOTION / float(sample_count)
		for _sample_index in sample_count:
			ship.apply_look_motion(per_sample)
			ship.call("_physics_process", 1.0 / float(samples_per_second))
		var relative := start_basis.inverse() * ship.global_basis
		results[samples_per_second] = {
			"basis": relative,
			"forward": -relative.z.normalized(),
			"up": relative.y.normalized(),
			"angle": rad_to_deg(Quaternion(Basis.IDENTITY).angle_to(Quaternion(relative))),
		}
		_check(_basis_is_orthonormal(relative), "%d Hz equivalent mouse trial leaves a finite orthonormal attitude" % samples_per_second)
		ship.queue_free()
		await process_frame

	_check(results.size() == MOUSE_SAMPLE_RATES.size(), "30/60/120 Hz equivalent mouse trials all complete")
	if results.size() != MOUSE_SAMPLE_RATES.size():
		return
	var baseline := results[60] as Dictionary
	for samples_per_second in [30, 120]:
		var candidate := results[samples_per_second] as Dictionary
		_check(
			rad_to_deg((baseline.forward as Vector3).angle_to(candidate.forward as Vector3)) <= MOUSE_ATTITUDE_TOLERANCE_DEGREES,
			"%d Hz equivalent mouse heading agrees with 60 Hz" % samples_per_second
		)
		_check(
			rad_to_deg((baseline.up as Vector3).angle_to(candidate.up as Vector3)) <= MOUSE_ATTITUDE_TOLERANCE_DEGREES,
			"%d Hz equivalent mouse pitch/roll frame agrees with 60 Hz" % samples_per_second
		)
		_check(
			absf(float(candidate.angle) - float(baseline.angle)) <= MOUSE_ATTITUDE_TOLERANCE_DEGREES,
			"%d Hz equivalent mouse total attitude response agrees with 60 Hz" % samples_per_second
		)


func _test_saturated_diagonal_mouse_attitude_frame_rate_stability() -> void:
	var results: Dictionary = {}
	var thirty_hz_saturated := false
	for samples_per_second: int in MOUSE_SAMPLE_RATES:
		var ship := await _make_online_ship("SaturatedDiagonalRate%d" % samples_per_second)
		if ship == null:
			continue
		# Force the live adapter's component-wise command bound to 100 px. A
		# 360/-360 px sweep over 0.1 s therefore saturates both components at
		# 30 Hz (120 px per sample), while 60 and 120 Hz remain unsaturated.
		ship.mouse_sensitivity = (
			deg_to_rad(ship.maximum_mouse_turn_degrees)
			/ SATURATED_DIAGONAL_PIXELS_PER_FULL_AXIS
		)
		ship.velocity = Vector3(0.0, 0.0, -10.0)
		var start_basis := ship.global_basis
		var sample_count := maxi(
			1,
			roundi(float(samples_per_second) * SATURATED_DIAGONAL_TRIAL_SECONDS)
		)
		var per_sample := SATURATED_DIAGONAL_TOTAL_MOTION / float(sample_count)
		for _sample_index in sample_count:
			ship.apply_look_motion(per_sample)
			ship.call("_physics_process", 1.0 / float(samples_per_second))
			var sampled := ship.get_last_ship_command()
			if (
				samples_per_second == 30
				and is_equal_approx(absf(sampled.look_yaw_delta), 1.0)
				and is_equal_approx(absf(sampled.look_pitch_delta), 1.0)
			):
				thirty_hz_saturated = true

		var backlog_drained := false
		for _drain_index in SATURATED_DIAGONAL_DRAIN_LIMIT:
			ship.call("_physics_process", 1.0 / float(samples_per_second))
			var drained_sample := ship.get_last_ship_command()
			if (
				is_zero_approx(drained_sample.look_yaw_delta)
				and is_zero_approx(drained_sample.look_pitch_delta)
			):
				backlog_drained = true
				break
		_check(backlog_drained, "%d Hz saturated diagonal mouse backlog fully drains" % samples_per_second)
		var relative := start_basis.inverse() * ship.global_basis
		results[samples_per_second] = relative
		_check(
			_basis_is_orthonormal(relative),
			"%d Hz saturated diagonal mouse trial leaves a finite orthonormal attitude" % samples_per_second
		)
		ship.queue_free()
		await process_frame

	_check(thirty_hz_saturated, "30 Hz diagonal trial saturates both live mouse command components")
	_check(results.size() == MOUSE_SAMPLE_RATES.size(), "30/60/120 Hz saturated diagonal mouse trials all complete")
	if results.size() != MOUSE_SAMPLE_RATES.size():
		return
	var baseline := results[60] as Basis
	for samples_per_second in [30, 120]:
		var candidate := results[samples_per_second] as Basis
		_check(
			_basis_attitude_delta_degrees(baseline, candidate)
			<= SATURATED_DIAGONAL_TOLERANCE_DEGREES,
			"%d Hz saturated diagonal attitude agrees with 60 Hz within %.2f degrees"
			% [samples_per_second, SATURATED_DIAGONAL_TOLERANCE_DEGREES]
		)

	var maximum_mouse_turn := deg_to_rad(18.0)
	var expected_rotation_vector := Vector3(
		-SATURATED_DIAGONAL_TOTAL_MOTION.y
			/ SATURATED_DIAGONAL_PIXELS_PER_FULL_AXIS * maximum_mouse_turn,
		-SATURATED_DIAGONAL_TOTAL_MOTION.x
			/ SATURATED_DIAGONAL_PIXELS_PER_FULL_AXIS * maximum_mouse_turn,
		0.0
	)
	var expected := Basis(Quaternion(
		expected_rotation_vector.normalized(),
		expected_rotation_vector.length()
	))
	_check(
		_basis_attitude_delta_degrees(expected, baseline)
		<= SATURATED_DIAGONAL_TOLERANCE_DEGREES,
		"saturated diagonal mouse response matches the combined yaw/pitch rotation vector"
	)


func _test_parked_and_startup_mouse_boundaries() -> void:
	var ship := await _make_ship("ParkedStartupBoundary")
	if ship == null:
		return
	ship.engine_start_time = 0.12
	ship.set_piloted(true)
	var parked_basis := ship.global_basis
	ship.apply_look_motion(Vector2(900.0, -700.0))
	ship.call("_physics_process", 1.0 / 60.0)
	_check(ship.global_basis.is_equal_approx(parked_basis), "parked mouse input cannot rotate the ship")
	ship.request_engine_start()
	ship.apply_look_motion(Vector2(-800.0, 600.0))
	for _index in 8:
		ship.call("_physics_process", 1.0 / 60.0)
	_check(str(ship.get_telemetry().engine_state) == "ONLINE", "startup boundary probe reaches online state")
	_check(ship.global_basis.is_equal_approx(parked_basis), "mouse input during startup cannot rotate the ship")
	ship.call("_physics_process", 1.0 / 60.0)
	_check(ship.global_basis.is_equal_approx(parked_basis), "first online flight tick has no queued startup attitude snap")
	ship.velocity = Vector3(0.0, 0.0, -10.0)
	ship.apply_look_motion(Vector2(60.0, 0.0))
	ship.call("_physics_process", 1.0 / 60.0)
	_check(not ship.global_basis.is_equal_approx(parked_basis), "fresh online mouse input still reaches the attitude path")
	ship.queue_free()
	await process_frame


func _test_chase_response_bounds() -> void:
	var ship := await _make_online_ship("ChaseResponse")
	if ship == null:
		return
	_check(ship.has_method("get_current_chase_camera_rotation_lag_degrees"), "ship exposes observable chase rotation lag")
	_check(
		is_equal_approx(float(ship.get("chase_camera_rotation_response")), CHASE_ROTATION_RESPONSE),
		"chase rotation uses the agreed 7 inverse-second response"
	)
	_check(
		is_equal_approx(float(ship.get("maximum_chase_camera_rotation_lag_degrees")), CHASE_MAXIMUM_LAG_DEGREES),
		"chase rotation lag is capped at eight degrees"
	)
	var camera := ship.get_camera()
	_check(camera != null and camera.name == &"ShipCamera", "chase response probe uses the production chase camera")
	ship.velocity = Vector3(0.0, 0.0, -10.0)
	ship.apply_look_motion(Vector2(120.0, 0.0))
	ship.call("_physics_process", 1.0 / 60.0)
	var initial_lag := _get_chase_lag(ship)
	_check(initial_lag > 0.5 and initial_lag <= CHASE_MAXIMUM_LAG_DEGREES + 0.1, "known turn creates bounded non-zero chase boom lag")
	_check(_camera_forward_is_nose_locked(ship, camera), "active chase optical axis remains nose-locked while the boom lags")
	var previous_lag := initial_lag
	var monotonic := true
	var maximum_observed := initial_lag
	for _index in 45:
		ship.call("_physics_process", 1.0 / 60.0)
		var current_lag := _get_chase_lag(ship)
		maximum_observed = maxf(maximum_observed, current_lag)
		if current_lag > previous_lag + 0.05:
			monotonic = false
		previous_lag = current_lag
		if not _camera_forward_is_nose_locked(ship, camera):
			monotonic = false
	_check(monotonic, "neutral chase lag decays monotonically while the optical axis stays on the nose")
	_check(previous_lag < 0.25, "chase boom settles within 0.25 degrees after 0.75 seconds")
	_check(maximum_observed <= CHASE_MAXIMUM_LAG_DEGREES + 0.1, "observed chase lag never exceeds its configured cap")

	ship.apply_look_motion(Vector2(4000.0, -3000.0))
	for _index in 6:
		ship.call("_physics_process", 1.0 / 120.0)
		maximum_observed = maxf(maximum_observed, _get_chase_lag(ship))
	_check(maximum_observed <= CHASE_MAXIMUM_LAG_DEGREES + 0.1, "extreme mouse input cannot exceed the chase lag cap")
	_check(_basis_is_orthonormal(camera.global_basis), "chase camera keeps a finite orthonormal basis under extreme input")
	ship.set_cockpit_view(true)
	_check(_get_chase_lag(ship) <= 0.1, "entering cockpit view clears latent chase lag")
	ship.set_cockpit_view(false)
	_check(_get_chase_lag(ship) <= 0.1, "returning to chase view begins from the current ship attitude")
	ship.queue_free()
	await process_frame


func _test_cockpit_sight_contract() -> void:
	var ship := await _make_ship("CockpitSight")
	if ship == null:
		return
	ship.set_piloted(true)
	ship.set_cockpit_view(true)
	var camera := ship.get_camera()
	_check(camera != null and camera.name == &"CockpitCamera" and camera.current, "cockpit sight probe uses the live pilot-eye camera")
	_check(camera != null and camera.near <= 0.05, "cockpit near plane preserves close in-world instruments")
	_check(_camera_forward_is_nose_locked(ship, camera), "cockpit forward axis remains aligned with the physical nose")
	_check(ship.has_method("get_cockpit_quality_report"), "ship exposes a deterministic cockpit quality report")
	var report := {}
	if ship.has_method("get_cockpit_quality_report"):
		var value: Variant = ship.call("get_cockpit_quality_report")
		_check(value is Dictionary, "cockpit quality report is a Dictionary")
		if value is Dictionary:
			report = value as Dictionary
	_check(bool(report.get("valid", false)), "cockpit quality report validates")
	_check(_string_array(report.get("errors", [])).is_empty(), "cockpit quality report has no errors")
	_check(bool(report.get("forward_sight_clear", false)), "cockpit center and near-center forward sight rays are clear of opaque meshes")
	_check(int(report.get("opaque_obstruction_count", -1)) == 0, "cockpit quality report finds no opaque forward obstruction")
	_check(int(report.get("sight_sample_count", 0)) >= 5, "cockpit quality samples center plus offset forward rays")
	_check(float(report.get("sight_distance", 0.0)) >= 10.0, "cockpit quality proves at least ten metres of clear forward sight")
	_check(float(report.get("camera_near", 1.0)) <= 0.05, "cockpit report agrees with the production near plane")
	_check(float(report.get("camera_forward_alignment", 0.0)) > 0.999, "cockpit report proves nose-aligned optical forward")
	_check(report.get("forward_panel_size", Vector2.ZERO) is Vector2 and (report.get("forward_panel_size", Vector2.ZERO) as Vector2).x > 0.0, "cockpit report exposes a non-zero in-world forward panel")
	_check(float(report.get("forward_panel_area", 0.0)) > 0.01, "in-world forward panel has usable physical area")
	_check(bool(report.get("anti_glare_texture_loaded", false)), "forward panel exposes its anti-glare texture hook")
	_check(bool(report.get("instrument_readout_present", false)), "cockpit retains a usable in-world instrument readout")
	_check(str(report.get("modern_interpretation", "")) in ["modern", "presentation", "presentation_only"], "cockpit quality remains labelled as modern interpretation")
	ship.queue_free()
	await process_frame


func _test_in_world_telemetry_hooks() -> void:
	var ship := await _make_ship("TelemetryHooks")
	if ship == null:
		return
	var telemetry := ship.get_telemetry()
	_check(telemetry.get("velocity_world", null) is Vector3, "ship telemetry exposes world velocity for in-world flight cues")
	_check(telemetry.get("flight_forward_world", null) is Vector3, "ship telemetry exposes world nose direction for flight cues")
	_check(telemetry.get("camera_view", null) is StringName, "ship telemetry exposes the active camera-view identity")
	if telemetry.get("velocity_world", null) is Vector3:
		_check((telemetry.velocity_world as Vector3).is_finite(), "world velocity telemetry is finite")
	if telemetry.get("flight_forward_world", null) is Vector3:
		var forward := telemetry.flight_forward_world as Vector3
		_check(forward.is_finite() and absf(forward.length() - 1.0) < 0.001, "world flight-forward telemetry is finite and normalized")
		_check(forward.dot(-ship.global_basis.z.normalized()) > 0.999, "flight-forward telemetry agrees with the visible nose")
	_check(str(telemetry.get("camera_view", "")) == "CHASE", "default telemetry reports chase view")
	ship.set_cockpit_view(true)
	_check(str(ship.get_telemetry().get("camera_view", "")) == "COCKPIT", "telemetry follows the live cockpit view switch")

	var hud := HUD_SCENE.instantiate() as GameHUD
	root.add_child(hud)
	await process_frame
	_check(hud.has_method("get_flight_cue_report"), "HUD exposes an auditable in-world flight cue report")
	_check(hud.has_method("update_ship_telemetry"), "HUD consumes the stable ship telemetry dictionary")
	if hud.has_method("set_mode"):
		hud.set_mode("piloting")
	var viewport_center := root.get_visible_rect().size * 0.5
	var forward_data := ship.get_telemetry()
	forward_data["velocity_world"] = forward_data.flight_forward_world * 35.0
	forward_data.merge(_flight_path_payload(viewport_center, true, false, false, 1.0, &"forward"), true)
	hud.update_ship_telemetry(forward_data)
	var forward_report := _get_flight_cue_report(hud)
	_test_flight_cue_report_shape(forward_report)
	_check(bool(forward_report.get("visible", false)), "meaningful forward velocity makes the flight-path cue visible")
	_check(not bool(forward_report.get("clamped", true)) and not bool(forward_report.get("rearward", true)), "aligned forward flight cue is unclamped and forward-facing")
	_check(float(forward_report.get("alignment", 0.0)) > 0.98, "aligned forward flight cue reports strong nose agreement")
	var forward_position := _cue_screen_position(forward_report)
	_check(forward_position.distance_to(viewport_center) <= 18.0, "aligned forward velocity places the cue near screen center")

	var right_data := forward_data.duplicate(true)
	var camera := ship.get_camera()
	right_data["velocity_world"] = (-camera.global_basis.z + camera.global_basis.x * 0.45).normalized() * 35.0
	right_data.merge(_flight_path_payload(viewport_center + Vector2(90.0, 0.0), true, false, false, 0.91, &"forward"), true)
	hud.update_ship_telemetry(right_data)
	var right_report := _get_flight_cue_report(hud)
	_check(_cue_screen_position(right_report).x > forward_position.x + 2.0, "camera-right velocity displaces the flight-path cue screen-right")

	var upward_data := forward_data.duplicate(true)
	upward_data["velocity_world"] = (-camera.global_basis.z + camera.global_basis.y * 0.4).normalized() * 35.0
	upward_data.merge(_flight_path_payload(viewport_center + Vector2(0.0, -75.0), true, false, false, 0.93, &"forward"), true)
	hud.update_ship_telemetry(upward_data)
	var upward_report := _get_flight_cue_report(hud)
	_check(_cue_screen_position(upward_report).y < forward_position.y - 2.0, "upward velocity displaces the flight-path cue upward")

	var rearward_data := forward_data.duplicate(true)
	rearward_data["velocity_world"] = camera.global_basis.z.normalized() * 35.0
	rearward_data.merge(_flight_path_payload(viewport_center + Vector2(0.0, 120.0), true, true, true, -1.0, &"rearward"), true)
	hud.update_ship_telemetry(rearward_data)
	var rearward_report := _get_flight_cue_report(hud)
	_check(bool(rearward_report.get("visible", false)) and bool(rearward_report.get("rearward", false)), "rearward velocity is explicitly represented rather than mirrored")
	_check(str(rearward_report.get("visual_state", "")) in ["rearward", "reverse", "rev"], "rearward flight cue has a distinct semantic visual state")

	var slow_data := forward_data.duplicate(true)
	slow_data["velocity_world"] = (forward_data.flight_forward_world as Vector3) * 1.0
	slow_data["flight_path_visible"] = false
	hud.update_ship_telemetry(slow_data)
	_check(not bool(_get_flight_cue_report(hud).get("visible", true)), "flight-path cue hides below meaningful flight speed")
	var landed_data := forward_data.duplicate(true)
	landed_data["landed"] = true
	landed_data["flight_path_visible"] = false
	hud.update_ship_telemetry(landed_data)
	_check(not bool(_get_flight_cue_report(hud).get("visible", true)), "flight-path cue hides while landed")
	if hud.has_method("set_mode"):
		hud.set_mode("on-foot")
	_check(not bool(_get_flight_cue_report(hud).get("visible", true)), "flight-path cue hides outside piloting mode")

	hud.queue_free()
	ship.queue_free()
	await process_frame


func _test_flight_cue_report_shape(report: Dictionary) -> void:
	_check(bool(report.get("valid", false)), "flight cue report validates")
	_check(_string_array(report.get("errors", [])).is_empty(), "flight cue report has no errors")
	for key: String in ["visible", "clamped", "rearward", "screen_position", "alignment", "reticle_visible"]:
		_check(report.has(key), "flight cue report exposes %s" % key)
	_check(_cue_mouse_filter_is_ignored(report), "flight cue controls ignore mouse input")
	_check(bool(report.get("reticle_visible", false)), "fixed center reticle remains visible while piloting")


func _make_ship(label: String) -> HeroShip:
	var ship := TORRENT_SCENE.instantiate() as HeroShip
	_check(ship != null, "%s Torrent fixture instantiates" % label)
	if ship == null:
		return null
	ship.name = label
	_stage.add_child(ship)
	ship.global_position = Vector3(0.0, 40.0, 0.0)
	await process_frame
	return ship


func _make_online_ship(label: String) -> HeroShip:
	var ship := await _make_ship(label)
	if ship == null:
		return null
	ship.engine_start_time = 0.01
	ship.set_piloted(true)
	ship.request_engine_start()
	ship.call("_physics_process", 0.02)
	_check(str(ship.get_telemetry().engine_state) == "ONLINE", "%s fixture reaches online flight state" % label)
	return ship


func _action_has_physical_key(action: StringName, physical_keycode: Key) -> bool:
	if not InputMap.has_action(action):
		return false
	for mapped_event: InputEvent in InputMap.action_get_events(action):
		if mapped_event is InputEventKey and (mapped_event as InputEventKey).physical_keycode == physical_keycode:
			return true
	return false


func _action_has_joy_axis(action: StringName, axis: int, axis_value: float) -> bool:
	if not InputMap.has_action(action):
		return false
	for mapped_event: InputEvent in InputMap.action_get_events(action):
		if mapped_event is InputEventJoypadMotion:
			var motion := mapped_event as InputEventJoypadMotion
			if int(motion.axis) == axis and is_equal_approx(motion.axis_value, axis_value):
				return true
	return false


func _action_has_joy_button(action: StringName, button_index: int) -> bool:
	if not InputMap.has_action(action):
		return false
	for mapped_event: InputEvent in InputMap.action_get_events(action):
		if mapped_event is InputEventJoypadButton and int((mapped_event as InputEventJoypadButton).button_index) == button_index:
			return true
	return false


func _get_chase_lag(ship: HeroShip) -> float:
	if ship == null or not ship.has_method("get_current_chase_camera_rotation_lag_degrees"):
		return INF
	return float(ship.call("get_current_chase_camera_rotation_lag_degrees"))


func _camera_forward_is_nose_locked(ship: HeroShip, camera: Camera3D) -> bool:
	return (
		ship != null and camera != null
		and (-camera.global_basis.z.normalized()).dot(-ship.global_basis.z.normalized()) > 0.999
	)


func _basis_is_orthonormal(basis: Basis) -> bool:
	return (
		basis.x.is_finite() and basis.y.is_finite() and basis.z.is_finite()
		and absf(basis.x.length() - 1.0) < 0.002
		and absf(basis.y.length() - 1.0) < 0.002
		and absf(basis.z.length() - 1.0) < 0.002
		and absf(basis.x.dot(basis.y)) < 0.002
		and absf(basis.x.dot(basis.z)) < 0.002
		and absf(basis.y.dot(basis.z)) < 0.002
	)


func _basis_attitude_delta_degrees(from: Basis, to: Basis) -> float:
	if not _basis_is_orthonormal(from) or not _basis_is_orthonormal(to):
		return INF
	return rad_to_deg(
		Quaternion(from.orthonormalized()).angle_to(Quaternion(to.orthonormalized()))
	)


func _get_flight_cue_report(hud: Node) -> Dictionary:
	if hud == null or not hud.has_method("get_flight_cue_report"):
		return {}
	var value: Variant = hud.call("get_flight_cue_report")
	return value as Dictionary if value is Dictionary else {}


func _cue_screen_position(report: Dictionary) -> Vector2:
	var value: Variant = report.get("screen_position", Vector2.INF)
	return value as Vector2 if value is Vector2 else Vector2.INF


func _flight_path_payload(
	screen_position: Vector2,
	visible: bool,
	clamped: bool,
	rearward: bool,
	alignment: float,
	visual_state: StringName
	) -> Dictionary:
	return {
		"flight_path_screen_position": screen_position,
		"flight_path_visible": visible,
		"flight_path_clamped": clamped,
		"flight_path_rearward": rearward,
		"flight_path_alignment": alignment,
		"flight_path_visual_state": visual_state,
	}


func _cue_mouse_filter_is_ignored(report: Dictionary) -> bool:
	if bool(report.get("mouse_filter_ignored", false)):
		return true
	for key: String in ["marker", "connector"]:
		var node: Variant = report.get(key, null)
		if not (node is Control) or (node as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
			return false
	return report.has("marker") and report.has("connector")


func _string_array(value: Variant) -> PackedStringArray:
	if value is PackedStringArray:
		return value as PackedStringArray
	var result := PackedStringArray()
	if value is Array:
		for item: Variant in value:
			result.append(str(item))
	return result


func _release_test_actions() -> void:
	for action: StringName in [
		&"move_forward", &"move_back", &"move_left", &"move_right",
		&"pitch_up", &"pitch_down", &"roll_left", &"roll_right",
		&"sprint_boost", &"brake", &"hover", &"fire", &"barrel_roll",
		&"toggle_ship_camera_view", &"interact",
	]:
		Input.action_release(action)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("FLIGHT_QUALITY_CLOSURE_TEST_OK")
		quit(0)
	else:
		print("FLIGHT_QUALITY_CLOSURE_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
