## test-matrix-display: input-only
extends "res://tests/network/jovian_network_two_client_boost_test.gd"

## HELM-HOVER: the full ordinary boarding/departure/yaw/boost route precedes
## pitch/forward actions that create real upward motion, sampled hover correction,
## a fresh delivered release, both actual replicas and full ordinary handback.
## No command/provider/pose/velocity/engine/authority is assigned by this test.
const HOVER_SAMPLE_TICKS := 30
const HOVER_ACTIONS := [&"pitch_up", &"move_forward", &"hover", &"brake"]
var _hover_reference: Dictionary = {}
var _hover_result: Dictionary = {}


func _peer_profile() -> Dictionary:
	var profile := super._peer_profile()
	profile["script"] = "res://tests/network/jovian_network_two_client_hover_test.gd"
	return profile


func _print_peer_success() -> void:
	print("JOVIAN_NETWORK_TWO_CLIENT_HOVER_OK checks=%d" % _checks)


func _host_boost() -> bool:
	var result := await super._host_boost()
	if result:
		result = await _host_hover()
	_release_hover_actions()
	return result


func _client_boost() -> bool:
	var result := await super._client_boost()
	if result:
		result = await _client_hover()
	_release_hover_actions()
	return result


func _release_hover_actions() -> void:
	for action: StringName in HOVER_ACTIONS:
		_action(action, false)
		Input.action_release(action)


func _hover_command(throttle: float, pitch: float, hovering: bool, after: Dictionary) -> bool:
	var command := _craft.get_last_ship_command()
	if command == null or not command.is_valid() or command.stream_id != int(_boost_identity.stream) \
		or command.sequence <= int(after.get("command_sequence", -1)) \
		or not is_equal_approx(command.throttle, throttle) or not is_equal_approx(command.pitch, pitch) \
		or command.hover != hovering or not is_zero_approx(command.yaw) or not is_zero_approx(command.roll) \
		or not is_zero_approx(command.look_yaw_delta) or not is_zero_approx(command.look_pitch_delta) \
		or not is_zero_approx(command.camera_distance_delta) or command.brake or command.boost \
		or command.barrel_roll or command.fire or command.fire_pressed or command.landing \
		or command.engine_start or command.engine_stop or command.interact or command.camera_toggle:
		return false
	if _role == "host":
		var audit := (_flight_source as NetworkRemotePilotCommandSource).get_audit()
		var controls := audit.get("controls", {}) as Dictionary
		var wire := (_flight_source as NetworkRemotePilotCommandSource).get_roll_receipt()
		return bool(audit.get("holding", false)) and int(audit.get("delivered", 0)) > int(after.delivered) \
			and int(wire.get("sequence", -1)) > int((after.wire_receipt as Dictionary).get("sequence", -1)) \
			and is_equal_approx(float(controls.get("throttle", INF)), throttle) \
			and is_equal_approx(float(controls.get("pitch", INF)), pitch) \
			and bool(controls.get("hover", not hovering)) == hovering
	var capture := _game.get("_network_remote_helm") as Dictionary
	return int(capture.get("sample_sequence", -1)) >= command.sequence \
		and int(capture.get("sequence", 0)) > int(after.wire_sequence) \
		and int(_game.get("_network_remote_helm_sent")) > int(after.sent)


func _hover_tilt_degrees() -> float:
	return rad_to_deg(_craft.global_basis.y.normalized().angle_to(Vector3.UP))


func _host_hover() -> bool:
	_boost_stage = "host.hover.prepare"
	_hover_reference = _boost_host_receipt()
	_write("host.hover_prepare", _hover_reference)
	if not await _boost_wait(func(): return _flight_files_ready(".hover_ready"), 8.0,
		"both original seated clients consume the stopped host before actual pitch/forward preparation"):
		return false
	_boost_stage = "host.hover.pitch"
	var pitch_deadline := Time.get_ticks_msec() + 3000
	_write("host.hover_pitch", {})
	if not await _boost_wait(func():
		return _hover_command(1.0, 1.0, false, _hover_reference) and _hover_tilt_degrees() >= 20.0,
		_handback_remaining(pitch_deadline), "sampled pitch-up/forward produces actual host tilt>=20deg within3s"):
		return false
	_hover_reference = _boost_host_receipt()
	_write("host.hover_tilted", _hover_reference)
	_boost_stage = "host.hover.climb"
	if not await _boost_wait(func():
		return _hover_command(1.0, 0.0, false, _hover_reference) and _craft.velocity.y >= 18.0 \
			and _hover_tilt_degrees() >= 20.0 and _hover_tilt_degrees() <= 50.0 \
			and is_equal_approx(float(_craft.get_telemetry().throttle), 1.0),
		4.0, "ordinary forward alone creates actual upward speed>=18m/s at20..50deg tilt within4s"):
		return false
	_hover_reference = _boost_host_receipt()
	_boost_stage = "host.hover.correct"
	_write("host.hover_go", _hover_reference)
	if not await _boost_wait(func():
		return _hover_command(0.0, 0.0, true, _hover_reference) \
			and is_zero_approx(float(_craft.get_telemetry().throttle)), 2.0,
		"fresh sampled hover and released forward reach the original authoritative source with zero actual throttle within2s"):
		return false
	await physics_frame
	var first := _boost_host_receipt()
	var initial_tilt := _hover_tilt_degrees()
	if not _require(initial_tilt >= 15.0 and _craft.velocity.y >= 4.0,
		"hover measurement begins with meaningful actual tilt>=15deg and upward speed>=4m/s after throttle response"):
		return false
	var delta := 1.0 / float(Engine.physics_ticks_per_second)
	var engine_power := float(_craft.get_telemetry().engine_power)
	var hover_reduction := 0.0
	var maximum_vertical_error := 0.0
	var maximum_tilt_error := 0.0
	for _tick in HOVER_SAMPLE_TICKS:
		if _aborted() or not _require(_host_flight_current() and _yaw_stream_current() and _boost_current() \
			and _hover_command(0.0, 0.0, true, _hover_reference) \
			and _craft.get_telemetry().get("engine_state") == HeroShip.ENGINE_ONLINE \
			and is_zero_approx(float(_craft.get_telemetry().throttle)) \
			and is_equal_approx(float(_craft.get_telemetry().engine_power), engine_power),
			"original delivered hover alone stays ONLINE with unchanged engine power throughout30 physics ticks"):
			return false
		# Account only for the two existing pre-hover momentum terms so ordinary
		# drag/nose assistance cannot masquerade as hover's vertical braking.
		var before_hover := _craft.velocity.move_toward(Vector3.ZERO, _craft.passive_drag * delta)
		if before_hover.length_squared() > 0.01:
			before_hover = before_hover.lerp(-_craft.global_basis.z.normalized() * before_hover.length(),
				1.0 - exp(-_craft.flight_assist_strength * engine_power * 0.35 * delta))
		var expected_y := move_toward(before_hover.y, 0.0,
			_craft.brake_acceleration * lerpf(HeroShip.FAILED_ENGINE_MANUAL_BRAKE_FACTOR, 1.0, engine_power) * delta)
		var expected_tilt := _hover_tilt_degrees() * exp(-2.0 * delta)
		hover_reduction += absf(before_hover.y) - absf(expected_y)
		await physics_frame
		maximum_vertical_error = maxf(maximum_vertical_error, absf(_craft.velocity.y - expected_y))
		maximum_tilt_error = maxf(maximum_tilt_error, absf(_hover_tilt_degrees() - expected_tilt))
		if not _require(maximum_vertical_error <= 0.05 and maximum_tilt_error <= 0.05,
			"actual host hover matches authored vertical brake and exponential upright step within0.05m/s and0.05deg each tick"):
			return false
	_hover_result = _boost_host_receipt().merged({"start": first, "sample_ticks": Engine.get_physics_frames() - int(first.physics_tick),
		"sample_seconds": HOVER_SAMPLE_TICKS * delta, "initial_tilt_degrees": initial_tilt,
		"final_tilt_degrees": _hover_tilt_degrees(), "hover_vertical_reduction": hover_reduction,
		"maximum_vertical_error": maximum_vertical_error, "maximum_tilt_error": maximum_tilt_error})
	if not _require(int(_hover_result.sample_ticks) == HOVER_SAMPLE_TICKS and hover_reduction >= 3.0 \
		and _hover_tilt_degrees() <= initial_tilt * 0.40 \
		and absf(_craft.velocity.y) < absf(_vector_from(first.velocity).y),
		"exact30tick actual hover window removes>=3m/s beyond ordinary drag/assist and reduces tilt>=60percent and vertical speed"):
		return false
	if not await _boost_wait(func():
		return _hover_command(0.0, 0.0, true, _hover_reference) \
			and _hover_tilt_degrees() <= 0.75 and absf(_craft.velocity.y) <= 0.05,
		3.0, "ordinary held hover finishes upright<=0.75deg with vertical speed<=0.05m/s within3s"):
		return false
	_hover_reference = _boost_host_receipt()
	_hover_result["release_reference"] = _hover_reference
	var release_deadline := Time.get_ticks_msec() + 1000
	_write("host.hover_measured", _hover_result)
	_boost_stage = "host.hover.release"
	if not await _boost_wait(func():
		return _flight_file_exists("client.hover_released") and _hover_command(0.0, 0.0, false, _hover_reference),
		_handback_remaining(release_deadline),
		"hover release delivers fresh same-stream neutral within1s including pilot capture/send; holding/delivery exclude timeout neutral"):
		return false
	_write("host.hover_neutral", _boost_host_receipt())
	_boost_stage = "host.hover.brake"
	var stopped_since := [-1]
	if not await _boost_wait(func():
		if _boost_host_command(0.0, false, true, _hover_reference) and _craft.velocity.length() <= 0.5:
			if int(stopped_since[0]) < 0:
				stopped_since[0] = Time.get_ticks_msec()
		else:
			stopped_since[0] = -1
		return int(stopped_since[0]) >= 0 and Time.get_ticks_msec() - int(stopped_since[0]) >= 1000,
		10.0, "ordinary sampled brake holds actual host speed<=0.5m/s for1s within10s after hover release"):
		return false
	_hover_reference = _boost_host_receipt()
	var brake_release_deadline := Time.get_ticks_msec() + 1000
	_write("host.hover_stopped", _hover_reference)
	if not await _boost_wait(func(): return _boost_host_command(0.0, false, false, _hover_reference),
		_handback_remaining(brake_release_deadline), "ordinary brake release delivers fresh neutral within1s after hover"):
		return false
	_hover_reference = _boost_host_receipt()
	_write("host.hover_stable", _hover_reference)
	_boost_stage = "host.hover.replica_convergence"
	if not await _boost_wait(func(): return _flight_files_ready(".hover_converged"), 5.0,
		"both actual client hulls consume fresh original-owner poses and converge<=0.5m and<=2deg within5s after hover"):
		return false
	if not _require(_craft.velocity.length() <= 0.5 and _host_passenger_follows_anchor(true),
		"host remains stopped with original co-pilot at actual anchor after hover replica receipts"):
		return false
	_write("host.hover_complete", _hover_result)
	_boost_stage = "retained"
	return true


func _client_hover() -> bool:
	_boost_stage = _role + ".hover.prepare"
	if not await _boost_wait(func(): return _flight_file_exists("host.hover_prepare"), 8.0,
		"host prepares actual sampled hover after the full unchanged boost route"):
		return false
	_hover_reference = _read("host.hover_prepare")
	if not await _boost_wait(func(): return _yaw_consumed_after(_hover_reference), 8.0,
		"original seated client consumes fresh host pose before pitch/forward authorization"):
		return false
	_write(_role + ".hover_ready", _boost_client_receipt())
	if not await _boost_wait(func(): return _flight_file_exists("host.hover_pitch"), 8.0,
		"host authorizes actual sampled pitch-up/forward only after both clients ready"):
		return false
	var ready := _boost_client_receipt()
	if _role == "client":
		_action(&"move_forward", true)
		_action(&"pitch_up", true)
	var pitch_captured := [_role != "client"]
	if not await _boost_wait(func():
		if _role == "client" and _hover_command(1.0, 1.0, false, ready):
			pitch_captured[0] = true
		return _flight_file_exists("host.hover_tilted"), 8.0, "host observes real pitch tilt from original pilot input"):
		return false
	if _role == "client":
		_action(&"pitch_up", false)
	if not _require(bool(pitch_captured[0]), "original production input source and ENet capture sampled held pitch/forward"):
		return false
	if not await _boost_wait(func(): return _flight_file_exists("host.hover_go"), 8.0,
		"host creates genuine upward motion from ordinary forward action before hover authorization"):
		return false
	_boost_stage = _role + ".hover.correct"
	ready = _boost_client_receipt()
	if _role == "client":
		_action(&"move_forward", false)
		_action(&"hover", true)
	var hover_captured := [_role != "client"]
	if not await _boost_wait(func():
		if _role == "client" and _hover_command(0.0, 0.0, true, ready):
			hover_captured[0] = true
		return _flight_file_exists("host.hover_measured"), 8.0,
		"host measures30 actual hover physics ticks and finishes ordinary uprighting"):
		return false
	var held := _boost_client_receipt()
	if _role == "client":
		_action(&"hover", false)
	if not _require(bool(hover_captured[0]), "original production input source samples hover alone and advances capture/send cursors"):
		return false
	_boost_stage = _role + ".hover.release"
	if _role == "client":
		if not await _boost_wait(func(): return _hover_command(0.0, 0.0, false, held), 1.0,
			"released hover becomes a fresh same-source neutral production capture and actual ENet send"):
			return false
		_write("client.hover_released", _boost_client_receipt())
	if not await _boost_wait(func(): return _flight_file_exists("host.hover_neutral"), 8.0,
		"host confirms fresh delivered hover release inside its original single1s budget"):
		return false
	if _role == "client":
		_action(&"brake", true)
	if not await _boost_wait(func(): return _flight_file_exists("host.hover_stopped"), 10.0,
		"host confirms actual ordinary braked stop after hover"):
		return false
	if _role == "client":
		_action(&"brake", false)
	if not await _boost_wait(func(): return _flight_file_exists("host.hover_stable"), 8.0,
		"host receives ordinary brake release before replica comparison"):
		return false
	_hover_reference = _read("host.hover_stable")
	_boost_stage = _role + ".hover.replica_convergence"
	if not await _boost_wait(func():
		return _yaw_consumed_after(_hover_reference) and _yaw_attitude_error(_hover_reference) <= 2.0 \
			and _station_position().distance_to(_vector_from(_hover_reference.position)) <= 0.5 \
			and _body_follows_anchor(_player, _flight_anchor, true), 8.0,
		"actual original client hull position/attitude converge with fresh original-owner pose and real Player anchor"):
		return false
	_write(_role + ".hover_converged", _boost_client_receipt())
	if not await _boost_wait(func(): return _flight_file_exists("host.hover_complete"), 8.0,
		"host confirms both actual replicas inside its5s bound before complete ordinary Interact handback"):
		return false
	_hover_result = _read("host.hover_complete")
	_boost_stage = "retained"
	return true


func _handback_host_current() -> bool:
	var command := _craft.get_last_ship_command()
	return super._handback_host_current() and command != null and not command.hover and is_zero_approx(command.pitch)


func _handback_local_current(require_hud: bool) -> bool:
	return super._handback_local_current(require_hud) and not Input.is_action_pressed(&"hover") \
		and not Input.is_action_pressed(&"pitch_up")


func _failure_snapshot(description: String) -> Dictionary:
	var snapshot := super._failure_snapshot(description)
	snapshot["hover"] = {"reference": _hover_reference, "result": _hover_result,
		"hover": Input.is_action_pressed(&"hover"), "pitch_up": Input.is_action_pressed(&"pitch_up")}
	return snapshot
