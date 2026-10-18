## test-matrix-display: input-only
extends "res://tests/network/jovian_network_two_client_flight_test.gd"

## HELM-YAW-TURN: retain the entire ordinary two-client departure, then turn
## through normal pilot action events. Commands, attitude and replicas are read
## from production objects; files coordinate peers and carry comparison targets.
## This does not add a disembark/reboard qualification to inherited handback.
const YAW_ACTIONS := [&"move_left", &"move_right"]
var _yaw_stage := "departure"
var _yaw_direction := ""
var _yaw_start: Dictionary = {}
var _yaw_local_start: Dictionary = {}
var _yaw_turn: Dictionary = {}
var _yaw_stop: Dictionary = {}
var _yaw_max_drift_degrees := 0.0


func _peer_profile() -> Dictionary:
	var profile := super._peer_profile()
	profile["script"] = "res://tests/network/jovian_network_two_client_yaw_test.gd"
	return profile


func _print_peer_success() -> void:
	# Only the inherited coordinator prints this after all three actual OS exits0.
	print("JOVIAN_NETWORK_TWO_CLIENT_YAW_OK checks=%d" % _checks)


func _host_scenario() -> bool:
	var result := await super._host_scenario()
	if result:
		result = await _host_yaw()
	_release_yaw_actions()
	return result


func _client_scenario() -> bool:
	var result := await super._client_scenario()
	if result:
		result = await _client_yaw()
	_release_yaw_actions()
	return result


func _release_yaw_actions() -> void:
	for action: StringName in YAW_ACTIONS:
		_action(action, false)
		Input.action_release(action)


func _host_yaw() -> bool:
	_yaw_start = {"source_stream": _flight_source.get_stream_id(),
		"wire_stream": int((_flight_source as NetworkRemotePilotCommandSource).get_roll_receipt().get("stream", -1))}
	if not _require(_yaw_start.wire_stream >= 0 and _host_flight_current(),
		"yaw begins with unchanged original host producer, wire stream, owner and both original seated identities"):
		return false
	for index in YAW_ACTIONS.size():
		_yaw_direction = "left" if index == 0 else "right"
		if not await _host_yaw_direction(-1.0 if index == 0 else 1.0):
			return false
	_yaw_stage = "retained"
	return true


func _host_yaw_direction(command_sign: float) -> bool:
	_yaw_stage = "host." + _yaw_direction + ".prepare"
	_yaw_turn = _yaw_host_receipt()
	_yaw_stop = {}
	_yaw_max_drift_degrees = 0.0
	_write(_yaw_file("host", "prepare"), _yaw_turn)
	if not await _yaw_wait(func(): return _yaw_clients_ready("ready"), 8.0,
		"both original clients are ready with current consumed owner and neutral yaw before " + _yaw_direction):
		return false
	var pilot_ready := _read(_yaw_file("client", "ready"))
	if not _require(int(pilot_ready.get("wire_stream", -1)) == int(_yaw_start.wire_stream),
		"pilot's production capture and authoritative remote source retain the same original wire stream"):
		return false
	_yaw_stage = "host." + _yaw_direction + ".turn"
	# One host clock owns the genuine 2s bound, including delivery of this go
	# authorization to the pilot. Clients use loose finite handshake waits only.
	var authorized_msec := Time.get_ticks_msec()
	_write(_yaw_file("host", "go"), {})
	if not await _yaw_wait(func():
		return _yaw_host_command(command_sign, int(_yaw_turn.command_sequence), int(_yaw_turn.delivered)) \
			and -command_sign * _yaw_heading_change(_yaw_turn) >= 3.0,
		maxf(0.0, float(authorized_msec + 2000 - Time.get_ticks_msec()) / 1000.0),
		"host consumes same-stream valid " + _yaw_direction + " command and changes heading>=3deg with correct sign inside2s of input authorization"):
		return false
	_yaw_turn = _yaw_host_receipt().merged({"heading_change_degrees": _yaw_heading_change(_yaw_turn),
		"authorization_to_turn_msec": Time.get_ticks_msec() - authorized_msec})
	_yaw_stage = "host." + _yaw_direction + ".release"
	# Start before authorizing release, so the 1s budget includes file scheduling
	# and actual input release. Never restart it when a delayed receipt arrives.
	var release_authorized_msec := Time.get_ticks_msec()
	_write(_yaw_file("host", "turned"), _yaw_turn)
	if not await _yaw_wait(func():
		return _flight_file_exists(_yaw_file("client", "released")) \
			and _yaw_host_command(0.0, int(_yaw_turn.command_sequence), int(_yaw_turn.delivered)),
		maxf(0.0, float(release_authorized_msec + 1000 - Time.get_ticks_msec()) / 1000.0),
		"host consumes fresh delivered neutral helm<=1s including normal input release latency after " + _yaw_direction):
		return false
	_yaw_stop = _yaw_host_receipt().merged({"release_authorization_to_neutral_msec": Time.get_ticks_msec() - release_authorized_msec})
	_yaw_stage = "host." + _yaw_direction + ".neutral_stability"
	var stable_since := Time.get_ticks_msec()
	if not await _yaw_wait(func():
		_yaw_max_drift_degrees = maxf(_yaw_max_drift_degrees, absf(_yaw_heading_change(_yaw_stop)))
		if not _require(_yaw_host_command(0.0, int(_yaw_stop.command_sequence) - 1, int(_yaw_turn.delivered))
			and _yaw_max_drift_degrees <= 0.5 and _host_passenger_follows_anchor(true),
			"neutral host command, actual passenger anchor and heading drift<=0.5deg hold throughout1s"):
			return false
		return Time.get_ticks_msec() - stable_since >= 1000,
		2.0, "authoritative " + _yaw_direction + " heading holds<=0.5deg drift for1s once neutral"):
		return false
	_yaw_stop = _yaw_host_receipt().merged({"maximum_neutral_heading_drift_degrees": _yaw_max_drift_degrees})
	_yaw_stage = "host." + _yaw_direction + ".replica_convergence"
	var convergence_started_msec := Time.get_ticks_msec()
	_write(_yaw_file("host", "stable"), _yaw_stop)
	if not await _yaw_wait(func(): return _yaw_clients_ready("converged"),
		maxf(0.0, float(convergence_started_msec + 2000 - Time.get_ticks_msec()) / 1000.0),
		"both original actual client hull attitudes converge<=2deg with advanced current-owner consumed poses inside2s of host stabilization"):
		return false
	if not _require(_yaw_host_command(0.0, int(_yaw_stop.command_sequence) - 1, int(_yaw_turn.delivered))
		and absf(_yaw_heading_change(_yaw_stop)) <= 0.5 and _host_passenger_follows_anchor(true),
		"host retains neutral attitude and exact moving-anchor support through both client attitude receipts"):
		return false
	_write(_yaw_file("host", "complete"), _yaw_host_receipt())
	return true


func _client_yaw() -> bool:
	if _role == "client":
		_yaw_local_start = _yaw_capture_identity()
	for index in YAW_ACTIONS.size():
		_yaw_direction = "left" if index == 0 else "right"
		if not await _client_yaw_direction(YAW_ACTIONS[index], -1.0 if index == 0 else 1.0):
			return false
	_yaw_stage = "retained"
	return true


func _client_yaw_direction(action: StringName, command_sign: float) -> bool:
	_yaw_stage = _role + "." + _yaw_direction + ".prepare"
	_yaw_stop = {}
	if not await _yaw_wait(func(): return _flight_file_exists(_yaw_file("host", "prepare")), 8.0,
		"host prepares ordinary " + _yaw_direction + " action after unchanged departure"):
		return false
	_yaw_turn = _read(_yaw_file("host", "prepare"))
	if not await _yaw_wait(func():
		return _yaw_consumed_after(_yaw_turn) and not Input.is_action_pressed(&"move_left") \
			and not Input.is_action_pressed(&"move_right"), 8.0,
		"original client consumes advanced current-owner pose and holds neither yaw action before authorization"):
		return false
	var ready := _yaw_client_receipt()
	if _role == "client":
		ready.merge(_yaw_capture_identity())
	_write(_yaw_file(_role, "ready"), ready)
	if not await _yaw_wait(func(): return _flight_file_exists(_yaw_file("host", "go")), 8.0,
		"host authorizes " + _yaw_direction + " only after both original seated clients are ready"):
		return false
	_yaw_stage = _role + "." + _yaw_direction + ".turn"
	if _role == "client":
		_action(action, true)
	var capture_observed := [_role != "client"]
	if not await _yaw_wait(func():
		if _role == "client" and _yaw_pilot_capture_matches(command_sign, ready):
			capture_observed[0] = true
		return _flight_file_exists(_yaw_file("host", "turned")), 8.0,
		"host reports bounded authoritative signed turn from original pilot action"):
		return false
	# Release first, including failure paths; capture proof reads production data
	# while held and never manufactures a command or directly calls its producer.
	if _role == "client":
		_action(action, false)
		_write(_yaw_file("client", "released"), {"capture_observed": capture_observed[0]})
	if not _require(bool(capture_observed[0]),
		"normal local provider command reaches current production helm capture and advances ENet send cursor while yaw is held"):
		return false
	_yaw_turn = _read(_yaw_file("host", "turned"))
	_yaw_stage = _role + "." + _yaw_direction + ".neutral_stability"
	if not await _yaw_wait(func(): return _flight_file_exists(_yaw_file("host", "stable")), 8.0,
		"host observes delivered neutral within1s of release authorization and<=0.5deg heading drift for1s"):
		return false
	_yaw_stop = _read(_yaw_file("host", "stable"))
	_yaw_stage = _role + "." + _yaw_direction + ".replica_convergence"
	# Host owns the single 2s convergence budget; this loose wait cannot extend it.
	if not await _yaw_wait(func(): return _yaw_client_converged(_yaw_stop), 8.0,
		"actual local craft basis matches host<=2deg with an advanced current-owner consumed pose and original real Player anchor"):
		return false
	_write(_yaw_file(_role, "converged"), _yaw_client_receipt())
	if not await _yaw_wait(func(): return _flight_file_exists(_yaw_file("host", "complete")), 8.0,
		"host confirms both original client attitudes within its single2s deadline"):
		return false
	return true


func _yaw_wait(predicate: Callable, seconds: float, description: String) -> bool:
	return await _flight_wait(func():
		if not _require(_yaw_stream_current(), "original producer and wire streams remain current throughout " + _yaw_stage):
			return false
		return bool(predicate.call()), seconds, description)


func _yaw_stream_current() -> bool:
	if _role == "host":
		return _flight_source.get_stream_id() == int(_yaw_start.source_stream) \
			and int((_flight_source as NetworkRemotePilotCommandSource).get_roll_receipt().get("stream", -1)) == int(_yaw_start.wire_stream)
	return _role != "client" or (_yaw_capture_identity() == _yaw_local_start \
		and int(_yaw_local_start.producer_id) == _flight_source.get_instance_id() \
		and int(_yaw_local_start.producer_stream) == _flight_source.get_stream_id() \
		and int(_yaw_local_start.session_id) == _game.network_session.get_instance_id() \
		and str(_yaw_local_start.ship_id) == str(_craft.ship_id))


func _yaw_host_command(command_sign: float, newer_than: int, delivered_after: int) -> bool:
	var command := _craft.get_last_ship_command()
	var audit := (_flight_source as NetworkRemotePilotCommandSource).get_audit()
	var controls := audit.get("controls", {}) as Dictionary
	return command != null and command.is_valid() and command.stream_id == int(_yaw_start.source_stream) \
		and command.sequence > newer_than and bool(audit.get("holding", false)) \
		and int(audit.get("delivered", 0)) > delivered_after \
		and is_equal_approx(command.yaw, command_sign) and is_equal_approx(float(controls.get("yaw", INF)), command_sign) \
		and is_zero_approx(command.throttle) and is_zero_approx(command.pitch) and is_zero_approx(command.roll) \
		and is_zero_approx(command.look_yaw_delta) and is_zero_approx(command.look_pitch_delta) \
		and not command.brake and not command.boost and not command.hover \
		and (not is_zero_approx(command_sign) or command.is_neutral())


func _yaw_pilot_capture_matches(command_sign: float, ready: Dictionary) -> bool:
	var command := _craft.get_last_ship_command()
	var capture := _game.get("_network_remote_helm") as Dictionary
	return command != null and command.is_valid() and _flight_source is LocalShipInputSource \
		and command.stream_id == _flight_source.get_stream_id() and is_equal_approx(command.yaw, command_sign) \
		and int(capture.get("sample_sequence", -1)) >= command.sequence \
		and int(capture.get("sequence", 0)) > int(ready.get("wire_sequence", 0)) \
		and int(_game.get("_network_remote_helm_sent")) > int(ready.get("sent", 0))


func _yaw_capture_identity() -> Dictionary:
	var capture := _game.get("_network_remote_helm") as Dictionary
	return {"producer_id": int(capture.get("producer_id", 0)), "producer_stream": int(capture.get("producer_stream", -1)),
		"wire_stream": int(capture.get("stream_id", -1)), "session_id": int(capture.get("session_id", 0)),
		"ship_id": str(capture.get("ship_id", ""))}


func _yaw_consumed_after(host: Dictionary) -> bool:
	var sample := _flight_pose_sample()
	return int(sample.get("pose_tick", -1)) > int(host.get("pose_tick", 0)) \
		and int(sample.get("pilot_peer_id", 0)) == int(_flight_start.pilot_peer)


func _yaw_client_converged(host: Dictionary) -> bool:
	# The coordinator's quaternion is only a target. This comparison reads the
	# actual client craft basis, alongside its independently consumed network tick.
	return _yaw_consumed_after(host) and _yaw_attitude_error(host) <= 2.0 \
		and _body_follows_anchor(_player, _flight_anchor, true)


func _yaw_heading_change(reference: Dictionary) -> float:
	var initial_nose := _vector_from(reference.nose)
	var up := _vector_from(reference.up)
	var current_nose := (-_craft.global_basis.z).normalized().slide(up).normalized()
	return rad_to_deg(initial_nose.slide(up).normalized().signed_angle_to(current_nose, up))


func _yaw_attitude_error(reference: Dictionary) -> float:
	var values: Array = reference.rotation
	var target := Quaternion(float(values[0]), float(values[1]), float(values[2]), float(values[3])).normalized()
	return rad_to_deg(_craft.global_basis.orthonormalized().get_rotation_quaternion().angle_to(target))


func _yaw_file(role: String, boundary: String) -> String:
	return role + ".yaw_" + _yaw_direction + "." + boundary


func _yaw_clients_ready(boundary: String) -> bool:
	return _flight_file_exists(_yaw_file("client", boundary)) and _flight_file_exists(_yaw_file("client_b", boundary))


func _yaw_host_receipt() -> Dictionary:
	var result := _host_flight_receipt()
	var rotation := _craft.global_basis.orthonormalized().get_rotation_quaternion()
	var command := _craft.get_last_ship_command()
	result.merge({"rotation": [rotation.x, rotation.y, rotation.z, rotation.w],
		"nose": _vector_values(-_craft.global_basis.z.normalized()), "up": _vector_values(_craft.global_basis.y.normalized()),
		"command_sequence": command.sequence if command != null else -1,
		"command": command.to_dictionary() if command != null else {},
		"producer": _producer_state(_flight_source), "source_stream": _flight_source.get_stream_id(),
		"delivered": int((_flight_source as NetworkRemotePilotCommandSource).get_audit().get("delivered", 0)),
		"wire_receipt": (_flight_source as NetworkRemotePilotCommandSource).get_roll_receipt()})
	return result


func _yaw_client_receipt() -> Dictionary:
	var result := _client_flight_receipt()
	var rotation := _craft.global_basis.orthonormalized().get_rotation_quaternion()
	var capture := _game.get("_network_remote_helm") as Dictionary
	result.merge({"rotation": [rotation.x, rotation.y, rotation.z, rotation.w],
		"wire_sequence": int(capture.get("sequence", 0)), "sent": int(_game.get("_network_remote_helm_sent")),
		"attitude_error_degrees": _yaw_attitude_error(_yaw_stop) if not _yaw_stop.is_empty() else -1.0})
	return result


func _node_identity(node: Node) -> Dictionary:
	if not is_instance_valid(node):
		return {"valid": false}
	# Remote command sources can be valid while intentionally outside the tree.
	return {"valid": true, "instance_id": str(node.get_instance_id()),
		"path": str(node.get_path()) if node.is_inside_tree() else ""}


func _failure_snapshot(description: String) -> Dictionary:
	var snapshot := super._failure_snapshot(description)
	var yaw := {"stage": _yaw_stage, "direction": _yaw_direction, "start": _yaw_start,
		"local_start": _yaw_local_start, "turn": _yaw_turn, "stop": _yaw_stop,
		"maximum_neutral_heading_drift_degrees": _yaw_max_drift_degrees,
		"move_left": Input.is_action_pressed(&"move_left"), "move_right": Input.is_action_pressed(&"move_right")}
	if is_instance_valid(_game) and is_instance_valid(_craft) and is_instance_valid(_player) \
		and is_instance_valid(_flight_source):
		yaw["actual"] = _yaw_host_receipt() if _role == "host" else _yaw_client_receipt()
		# Retain the inherited anchor predicate exactly; an observed rotation
		# failure records its real error and existing linear-motion tolerance.
		yaw["inherited_moving_anchor_tolerance_m"] = 0.05 + _craft.velocity.length() * _craft.get_physics_process_delta_time()
		if _role == "host":
			var peer := int(_read("host.seats_confirmed").get("passenger_peer", 0))
			var body := _game.get_network_remote_body_simulation().get_body(GameFlow.network_client_boarding_avatar_id(peer)) as PlayerController
			var anchor := (_craft as JovianLightFreighter).get_copilot_seat_anchor()
			yaw["host_passenger_anchor_error_m"] = body.global_position.distance_to(anchor.global_position) if is_instance_valid(body) else -1.0
	snapshot["yaw"] = yaw
	return snapshot
