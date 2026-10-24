## test-matrix-display: input-only
extends "res://tests/network/jovian_network_pilot_handback_test.gd"

## HELM-BOOST: retain ordinary boarding/departure/braking and both yaw turns,
## compare equal full-throttle baseline/boost windows on the actual host, then
## retain the complete ordinary Interact handback and cabin walk. Inputs are
## synthetic Godot actions, sampled by the original production local source.
## No provider, command, pose, velocity, engine or authority is staged here.
const BOOST_SAMPLE_TICKS := 30
const BOOST_ACTIONS := [&"move_forward", &"sprint_boost", &"brake"]
var _boost_stage := "yaw"
var _boost_trial := ""
var _boost_identity: Dictionary = {}
var _boost_reference: Dictionary = {}
var _boost_results: Dictionary = {}
var _boost_capture := Callable()


func _peer_profile() -> Dictionary:
	var profile := super._peer_profile()
	profile["script"] = "res://tests/network/jovian_network_two_client_boost_test.gd"
	return profile


func _print_peer_success() -> void:
	# The unchanged coordinator requires three actual process exits0 first.
	print("JOVIAN_NETWORK_TWO_CLIENT_BOOST_OK checks=%d" % _checks)


func _host_yaw() -> bool:
	var result := await super._host_yaw()
	if result:
		result = await _host_boost()
	_release_boost_actions()
	return result


func _client_yaw() -> bool:
	var result := await super._client_yaw()
	if result:
		result = await _client_boost()
	_release_boost_actions()
	return result


func _release_boost_actions() -> void:
	for action: StringName in BOOST_ACTIONS:
		_action(action, false)
		Input.action_release(action)


func _boost_initialize() -> void:
	_boost_identity = {"session": _game.network_session.get_instance_id(),
		"craft": _craft.get_instance_id(), "producer": _flight_source.get_instance_id(),
		"stream": _flight_source.get_stream_id()}
	if _role == "client":
		var saved := (_game.get("_network_client_helm_input_sources") as Dictionary).get(_craft.get_instance_id(), {}) as Dictionary
		_boost_capture = saved.get("capture", Callable())


func _boost_current() -> bool:
	if _game.network_session.get_instance_id() != int(_boost_identity.session) \
		or _craft.get_instance_id() != int(_boost_identity.craft) \
		or _flight_source.get_instance_id() != int(_boost_identity.producer) \
		or _flight_source.get_stream_id() != int(_boost_identity.stream):
		return false
	if _role != "client":
		return true
	var saved := (_game.get("_network_client_helm_input_sources") as Dictionary).get(_craft.get_instance_id(), {}) as Dictionary
	var capture: Callable = saved.get("capture", Callable())
	return _flight_source is LocalShipInputSource and (_flight_source as LocalShipInputSource).get_input_provider() == null \
		and saved.get("source") == _flight_source and capture == _boost_capture and capture.is_valid() \
		and _flight_source.command_produced.is_connected(capture)


func _boost_wait(predicate: Callable, seconds: float, description: String) -> bool:
	# Keep the inherited exact lease/seat/entity and original wire-stream checks,
	# the original300s profile, shared abort and all earlier route deadlines.
	return await _yaw_wait(func():
		return _require(_boost_current(), "original session/craft/source and production capture remain current throughout " + _boost_stage) \
			and bool(predicate.call()), seconds, description)


func _boost_command_matches(command: ShipCommand, throttle: float, boosting: bool, braking: bool) -> bool:
	return command != null and command.is_valid() and is_equal_approx(command.throttle, throttle) \
		and command.boost == boosting and command.brake == braking \
		and is_zero_approx(command.yaw) and is_zero_approx(command.pitch) and is_zero_approx(command.roll) \
		and is_zero_approx(command.look_yaw_delta) and is_zero_approx(command.look_pitch_delta) \
		and is_zero_approx(command.camera_distance_delta) and not command.hover \
		and not command.barrel_roll and not command.fire and not command.fire_pressed \
		and not command.landing and not command.engine_start and not command.engine_stop \
		and not command.interact and not command.camera_toggle


func _boost_host_command(throttle: float, boosting: bool, braking: bool, after: Dictionary) -> bool:
	var command := _craft.get_last_ship_command()
	var audit := (_flight_source as NetworkRemotePilotCommandSource).get_audit()
	var controls := audit.get("controls", {}) as Dictionary
	var wire := (_flight_source as NetworkRemotePilotCommandSource).get_roll_receipt()
	return _boost_command_matches(command, throttle, boosting, braking) \
		and command.stream_id == int(_boost_identity.stream) and command.sequence > int(after.command_sequence) \
		and bool(audit.get("holding", false)) and int(audit.get("delivered", 0)) > int(after.delivered) \
		and int(wire.get("sequence", -1)) > int((after.wire_receipt as Dictionary).get("sequence", -1)) \
		and is_equal_approx(float(controls.get("throttle", INF)), throttle) \
		and bool(controls.get("boost", not boosting)) == boosting \
		and bool(controls.get("brake", not braking)) == braking


func _boost_pilot_capture(throttle: float, boosting: bool, braking: bool, after: Dictionary) -> bool:
	var command := _craft.get_last_ship_command()
	var capture := _game.get("_network_remote_helm") as Dictionary
	return _boost_command_matches(command, throttle, boosting, braking) \
		and command.stream_id == _flight_source.get_stream_id() \
		and command.sequence > int(after.get("command_sequence", -1)) \
		and int(capture.get("sample_sequence", -1)) >= command.sequence \
		and int(capture.get("sequence", 0)) > int(after.wire_sequence) \
		and int(_game.get("_network_remote_helm_sent")) > int(after.sent)


func _host_boost() -> bool:
	_boost_initialize()
	for boosting: bool in [false, true]:
		_boost_trial = "boosted" if boosting else "baseline"
		if not await _host_boost_trial(boosting):
			return false
	var baseline: Dictionary = _boost_results.baseline
	var boosted: Dictionary = _boost_results.boosted
	if not _require(int(baseline.sample_ticks) == BOOST_SAMPLE_TICKS and int(boosted.sample_ticks) == BOOST_SAMPLE_TICKS \
		and is_equal_approx(float(baseline.sample_seconds), float(boosted.sample_seconds)) \
		and is_equal_approx(float(baseline.engine_power), float(boosted.engine_power)) \
		and float(boosted.speed_gain) >= float(baseline.speed_gain) * 1.20,
		"same host craft gains>=20percent more actual forward speed under boost across equal30tick full-throttle windows with unchanged engine power"):
		return false
	_boost_stage = "retained"
	_write("host.boost_complete", _boost_results)
	return true


func _host_boost_trial(boosting: bool) -> bool:
	_boost_stage = "host." + _boost_trial + ".prepare"
	_boost_reference = _boost_host_receipt()
	if not _require(_craft.velocity.length() <= 0.5,
		"ordinary prior braking leaves host speed<=0.5m/s before " + _boost_trial):
		return false
	_write(_boost_file("host", "prepare"), _boost_reference)
	if not await _boost_wait(func(): return _boost_clients_ready("ready"), 8.0,
		"both original seated clients consume current neutral host before " + _boost_trial):
		return false
	if not _require(int(_read(_boost_file("client", "ready")).get("wire_stream", -1)) == int(_yaw_start.wire_stream),
		"original pilot capture retains the authoritative original wire stream before " + _boost_trial):
		return false
	_boost_stage = "host." + _boost_trial + ".accelerate"
	_write(_boost_file("host", "go"), {})
	if not await _boost_wait(func():
		var telemetry := _craft.get_telemetry()
		return _boost_host_command(1.0, boosting, false, _boost_reference) \
			and telemetry.get("engine_state") == HeroShip.ENGINE_ONLINE \
			and is_equal_approx(float(telemetry.get("throttle", 0.0)), 1.0), 8.0,
		"ordinary sampled forward input reaches ONLINE full thrust with expected boost demand within8s"):
		return false
	# Sample at identical pre-physics boundaries. Awaiting physics_frame directly
	# cannot skip ticks when several physics steps share one rendered frame.
	await physics_frame
	var first := _boost_host_receipt()
	var nose := _vector_from(first.nose)
	var first_speed := _craft.velocity.dot(nose)
	var engine_power := float(_craft.get_telemetry().engine_power)
	if not _require(first_speed >= 0.0 and first_speed <= 5.0 and engine_power > 0.0,
		"full-throttle measurement begins at comparable low forward speed without staging motion"):
		return false
	for _tick in BOOST_SAMPLE_TICKS:
		if _aborted() or not _require(_host_flight_current() and _yaw_stream_current() and _boost_current() \
			and _boost_host_command(1.0, boosting, false, _boost_reference) \
			and is_equal_approx(float(_craft.get_telemetry().throttle), 1.0) \
			and _craft.get_telemetry().get("engine_state") == HeroShip.ENGINE_ONLINE \
			and is_equal_approx(float(_craft.get_telemetry().engine_power), engine_power) \
			and _craft.velocity.length() < _craft.maximum_speed * 0.70 \
			and _yaw_attitude_error(first) <= 0.1,
			"unchanged full-throttle delivered helm stays below normal cap with constant attitude/power during " + _boost_trial):
			return false
		await physics_frame
	var measured := _boost_host_receipt()
	var seconds := float(BOOST_SAMPLE_TICKS) / float(Engine.physics_ticks_per_second)
	var gain := _craft.velocity.dot(nose) - first_speed
	var expected := _craft.thrust_acceleration * (_craft.boost_multiplier if boosting else 1.0) * engine_power - _craft.passive_drag
	measured.merge({"sample_ticks": Engine.get_physics_frames() - int(first.physics_tick),
		"sample_seconds": seconds, "start_forward_speed": first_speed, "speed_gain": gain,
		"observed_acceleration": gain / seconds, "expected_acceleration": expected,
		"engine_power": engine_power, "start": first})
	_boost_results[_boost_trial] = measured
	if not _require(int(measured.sample_ticks) == BOOST_SAMPLE_TICKS and gain > 0.0 \
		and absf(gain / seconds - expected) <= 0.8,
		"actual host velocity gain matches authored thrust/boost multiplier, engine power and drag within0.8m/s2 across exactly30ticks"):
		return false
	_boost_stage = "host." + _boost_trial + ".release"
	var release_msec := Time.get_ticks_msec()
	_write(_boost_file("host", "measured"), measured)
	if not await _boost_wait(func():
		return _flight_file_exists(_boost_file("client", "released")) \
			and _boost_host_command(0.0, false, false, measured),
		_handback_remaining(release_msec + 1000),
		"host receives fresh same-wire neutral boost/forward release within1s; holding/delivery advance excludes timeout neutral"):
		return false
	_write(_boost_file("host", "neutral"), _boost_host_receipt())
	_boost_stage = "host." + _boost_trial + ".brake"
	var stopped_since := [-1]
	if not await _boost_wait(func():
		if _boost_host_command(0.0, false, true, measured) and _craft.velocity.length() <= 0.5:
			if int(stopped_since[0]) < 0:
				stopped_since[0] = Time.get_ticks_msec()
		else:
			stopped_since[0] = -1
		return int(stopped_since[0]) >= 0 and Time.get_ticks_msec() - int(stopped_since[0]) >= 1000,
		10.0, "ordinary sampled brake holds actual host speed<=0.5m/s for1s within10s after " + _boost_trial):
		return false
	var stopped := _boost_host_receipt()
	var brake_release_msec := Time.get_ticks_msec()
	_write(_boost_file("host", "stopped"), stopped)
	if not await _boost_wait(func(): return _boost_host_command(0.0, false, false, stopped),
		_handback_remaining(brake_release_msec + 1000),
		"ordinary brake release produces fresh delivered neutral within1s"):
		return false
	_boost_reference = _boost_host_receipt()
	_write(_boost_file("host", "stable"), _boost_reference)
	_boost_stage = "host." + _boost_trial + ".replica_convergence"
	if not await _boost_wait(func(): return _boost_clients_ready("converged"), 5.0,
		"both actual client hulls converge<=0.5m and<=2deg with advanced original-owner poses within5s after " + _boost_trial):
		return false
	if not _require(_craft.velocity.length() <= 0.5 and _host_passenger_follows_anchor(true),
		"host remains stopped with original co-pilot at actual anchor after both replica receipts"):
		return false
	_write(_boost_file("host", "complete"), _boost_host_receipt())
	return true


func _client_boost() -> bool:
	_boost_initialize()
	for boosting: bool in [false, true]:
		_boost_trial = "boosted" if boosting else "baseline"
		if not await _client_boost_trial(boosting):
			return false
	if not await _boost_wait(func(): return _flight_file_exists("host.boost_complete"), 8.0,
		"host verifies actual boost speed gain against equal baseline before ordinary Interact handback"):
		return false
	_boost_results = _read("host.boost_complete")
	_boost_stage = "retained"
	return true


func _client_boost_trial(boosting: bool) -> bool:
	_boost_stage = _role + "." + _boost_trial + ".prepare"
	if not await _boost_wait(func(): return _flight_file_exists(_boost_file("host", "prepare")), 8.0,
		"host prepares low-speed ordinary " + _boost_trial + " after unchanged route"):
		return false
	_boost_reference = _read(_boost_file("host", "prepare"))
	if not await _boost_wait(func():
		return _yaw_consumed_after(_boost_reference) and not Input.is_action_pressed(&"move_forward") \
			and not Input.is_action_pressed(&"sprint_boost") and not Input.is_action_pressed(&"brake"), 8.0,
		"actual client consumes advanced original-owner pose with no forward/boost/brake held before authorization"):
		return false
	var ready := _boost_client_receipt()
	if _role == "client":
		ready.merge(_yaw_capture_identity())
	_write(_boost_file(_role, "ready"), ready)
	if not await _boost_wait(func(): return _flight_file_exists(_boost_file("host", "go")), 8.0,
		"host authorizes measured " + _boost_trial + " after both actual clients ready"):
		return false
	_boost_stage = _role + "." + _boost_trial + ".accelerate"
	if _role == "client":
		_action(&"move_forward", true)
		_action(&"sprint_boost", boosting)
	var capture_observed := [_role != "client"]
	if not await _boost_wait(func():
		if _role == "client" and _boost_pilot_capture(1.0, boosting, false, ready):
			capture_observed[0] = true
		return _flight_file_exists(_boost_file("host", "measured")), 8.0,
		"host completes equal full-throttle authoritative physics window from ordinary sampled actions"):
		return false
	var held := _boost_client_receipt()
	if _role == "client":
		_action(&"sprint_boost", false)
		_action(&"move_forward", false)
	if not _require(bool(capture_observed[0]),
		"original production LocalShipInputSource samples expected forward/boost demand and advances capture and ENet send cursors"):
		return false
	_boost_stage = _role + "." + _boost_trial + ".release"
	if _role == "client":
		if not await _boost_wait(func(): return _boost_pilot_capture(0.0, false, false, held), 1.0,
			"released synthetic forward/boost actions become a fresh neutral production capture and ENet send"):
			return false
		_write(_boost_file("client", "released"), _boost_client_receipt())
	if not await _boost_wait(func(): return _flight_file_exists(_boost_file("host", "neutral")), 8.0,
		"host confirms fresh delivered neutral within its single1s release budget"):
		return false
	_boost_stage = _role + "." + _boost_trial + ".brake"
	if _role == "client":
		_action(&"brake", true)
	if not await _boost_wait(func(): return _flight_file_exists(_boost_file("host", "stopped")), 10.0,
		"host confirms actual ordinary braked stop after acceleration window"):
		return false
	if _role == "client":
		_action(&"brake", false)
	if not await _boost_wait(func(): return _flight_file_exists(_boost_file("host", "stable")), 8.0,
		"host confirms fresh neutral brake release before actual replica convergence"):
		return false
	_boost_reference = _read(_boost_file("host", "stable"))
	_boost_stage = _role + "." + _boost_trial + ".replica_convergence"
	if not await _boost_wait(func():
		return _yaw_consumed_after(_boost_reference) and _yaw_attitude_error(_boost_reference) <= 2.0 \
			and _station_position().distance_to(_vector_from(_boost_reference.position)) <= 0.5 \
			and _body_follows_anchor(_player, _flight_anchor, true), 8.0,
		"actual client craft position/attitude converges to stopped host with fresh current-owner pose and original Player anchor"):
		return false
	_write(_boost_file(_role, "converged"), _boost_client_receipt())
	return await _boost_wait(func(): return _flight_file_exists(_boost_file("host", "complete")), 8.0,
		"host confirms both real client replicas within its unchanged finite5s convergence bound")


func _boost_file(role: String, boundary: String) -> String:
	return role + ".boost_" + _boost_trial + "." + boundary


func _boost_clients_ready(boundary: String) -> bool:
	return _flight_file_exists(_boost_file("client", boundary)) and _flight_file_exists(_boost_file("client_b", boundary))


func _boost_host_receipt() -> Dictionary:
	var receipt := _yaw_host_receipt()
	receipt.merge({"physics_tick": Engine.get_physics_frames(), "telemetry": _craft.get_telemetry(),
		"velocity": _vector_values(_craft.velocity), "stage": _boost_stage})
	return receipt


func _boost_client_receipt() -> Dictionary:
	var receipt := _yaw_client_receipt()
	var command := _craft.get_last_ship_command()
	receipt.merge({"stage": _boost_stage, "command_sequence": command.sequence if command != null else -1,
		"command": command.to_dictionary() if command != null else {}})
	return receipt


func _handback_host_current() -> bool:
	# The inherited checks already require actual owner0/generation+1, a retired
	# remote source, OFFLINE neutral helm and the supported walking former pilot.
	# Keep former boost demand explicitly visible in this acceptance boundary.
	var command := _craft.get_last_ship_command()
	return super._handback_host_current() and command != null and not command.boost \
		and is_zero_approx(command.throttle)


func _handback_local_current(require_hud: bool) -> bool:
	if not super._handback_local_current(require_hud):
		return false
	return not Input.is_action_pressed(&"sprint_boost") and not Input.is_action_pressed(&"brake")


func _failure_snapshot(description: String) -> Dictionary:
	var snapshot := super._failure_snapshot(description)
	snapshot["boost"] = {"stage": _boost_stage, "trial": _boost_trial, "identity": _boost_identity,
		"reference": _boost_reference, "results": _boost_results,
		"move_forward": Input.is_action_pressed(&"move_forward"),
		"sprint_boost": Input.is_action_pressed(&"sprint_boost"), "brake": Input.is_action_pressed(&"brake")}
	return snapshot
