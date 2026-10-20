## test-matrix-display: input-only
extends "res://tests/network/jovian_network_two_client_flight_test.gd"

## HELM-REVERSE-FLIGHT: unchanged ordinary boarding/departure, then sampled
## reverse, delivered neutral, ordinary brake and actual stopped replicas.
## The inherited coordinator owns isolation, abort and all three OS exits.
const REVERSE_ACTIONS := [&"move_back", &"brake"]
var _reverse_stage := "departure"
var _reverse_start: Dictionary = {}
var _reverse_local_start: Dictionary = {}
var _reverse_effect: Dictionary = {}
var _reverse_neutral: Dictionary = {}
var _reverse_stopped: Dictionary = {}


func _peer_profile() -> Dictionary:
	var profile := super._peer_profile()
	profile["script"] = "res://tests/network/jovian_network_two_client_reverse_test.gd"
	return profile


func _print_peer_success() -> void:
	# Called only by the inherited coordinator after all actual OS exits0.
	print("JOVIAN_NETWORK_TWO_CLIENT_REVERSE_OK checks=%d" % _checks)


func _host_scenario() -> bool:
	var result := await super._host_scenario()
	if result:
		result = await _host_reverse()
	_release_reverse_actions()
	return result


func _client_scenario() -> bool:
	var result := await super._client_scenario()
	if result:
		result = await _client_reverse()
	_release_reverse_actions()
	return result


func _release_reverse_actions() -> void:
	for action: StringName in REVERSE_ACTIONS:
		_action(action, false)
		Input.action_release(action)


func _host_reverse() -> bool:
	_reverse_stage = "host.prepare"
	_reverse_start = _reverse_host_receipt()
	if not _require(int(_reverse_start.wire_receipt.get("stream", -1)) >= 0
		and _host_flight_current(), "reverse starts with original producer, wire stream and exact seated crew"):
		return false
	_write("host.reverse_prepare", _reverse_start)
	if not await _reverse_wait(func(): return _flight_files_ready(".reverse_ready"), 8.0,
		"both original clients consume current-owner poses and are ready with reverse released"):
		return false
	var ready := _read("client.reverse_ready")
	if not _require(int(ready.get("wire_stream", -1)) == int(_reverse_start.wire_receipt.stream),
		"original pilot capture and host source retain the same wire stream"):
		return false
	_reverse_stage = "host.reverse_1m"
	var authorized_msec := Time.get_ticks_msec()
	_write("host.reverse_go", {})
	if not await _reverse_wait(func():
		return _reverse_host_command(-1.0, false, _reverse_start) \
			and _reverse_distance() >= 1.0 \
			and _craft.velocity.dot(_vector_from(_reverse_start.nose)) < 0.0,
		_remaining(authorized_msec, 2.0),
		"fresh same-source negative throttle powers host>=1m backward with negative signed velocity within2s of authorization"):
		return false
	_reverse_effect = _reverse_host_receipt().merged({"authorization_to_effect_msec": Time.get_ticks_msec() - authorized_msec})
	_reverse_stage = "host.reverse_release"
	var release_msec := Time.get_ticks_msec()
	_write("host.reverse_effect", _reverse_effect)
	if not await _reverse_wait(func():
		return _flight_file_exists("client.reverse_released") \
			and _reverse_host_command(0.0, false, _reverse_effect),
		_remaining(release_msec, 1.0),
		"normal reverse release reaches fresh delivered fully neutral host command within1s including authorization delivery"):
		return false
	_reverse_neutral = _reverse_host_receipt().merged({"release_to_neutral_msec": Time.get_ticks_msec() - release_msec})
	if not _require(bool(_read("client.reverse_released").get("capture_observed", false)),
		"held reverse advanced the original local sampled producer, capture and actual ENet send cursor"):
		return false
	_reverse_stage = "host.brake_stop"
	var brake_msec := Time.get_ticks_msec()
	_write("host.reverse_brake_go", _reverse_neutral)
	var stopped_since := [-1]
	if not await _reverse_wait(func():
		if _reverse_host_command(0.0, true, _reverse_neutral) and _craft.velocity.length() <= 0.5:
			if int(stopped_since[0]) < 0:
				stopped_since[0] = Time.get_ticks_msec()
		else:
			stopped_since[0] = -1
		return int(stopped_since[0]) >= 0 and Time.get_ticks_msec() - int(stopped_since[0]) >= 1000 \
			and _host_passenger_follows_anchor(true),
		_remaining(brake_msec, 10.0),
		"ordinary current-source brake holds actual authoritative speed<=0.5m/s for1s within10s"):
		return false
	_reverse_stopped = _reverse_host_receipt()
	_reverse_stage = "host.brake_release"
	var brake_release_msec := Time.get_ticks_msec()
	_write("host.reverse_braked", _reverse_stopped)
	if not await _reverse_wait(func():
		return _flight_file_exists("client.reverse_brake_released") \
			and _reverse_host_command(0.0, false, _reverse_stopped),
		_remaining(brake_release_msec, 1.0),
		"brake release reaches fresh delivered fully neutral host command within1s"):
		return false
	_reverse_stopped = _reverse_host_receipt().merged({"brake_release_to_neutral_msec": Time.get_ticks_msec() - brake_release_msec})
	_reverse_stage = "host.replica_convergence"
	var convergence_msec := Time.get_ticks_msec()
	_write("host.reverse_stopped", _reverse_stopped)
	if not await _reverse_wait(func(): return _flight_files_ready(".reverse_converged"),
		_remaining(convergence_msec, 5.0),
		"both actual client hulls converge<=0.5m with newer current-owner consumed poses within5s of final neutral"):
		return false
	if not _require(_reverse_host_command(0.0, false, _reverse_stopped)
		and _craft.velocity.length() <= 0.5 and _host_passenger_follows_anchor(true),
		"original host source, ownership, supported copilot and neutral stopped craft survive both client receipts"):
		return false
	_write("host.reverse_complete", _reverse_host_receipt())
	_reverse_stage = "retained"
	return true


func _client_reverse() -> bool:
	_reverse_stage = _role + ".prepare"
	if _role == "client":
		_reverse_local_start = _reverse_capture_identity()
	if not await _reverse_wait(func(): return _flight_file_exists("host.reverse_prepare"), 8.0,
		"host prepares reverse only after unchanged ordinary shared departure"):
		return false
	_reverse_start = _read("host.reverse_prepare")
	if not await _reverse_wait(func():
		return _reverse_consumed_after(_reverse_start) and not Input.is_action_pressed(&"move_back") \
			and not Input.is_action_pressed(&"brake"), 8.0,
		"same seated client consumes an advanced original-owner pose before reverse authorization"):
		return false
	var ready := _reverse_client_receipt()
	if _role == "client":
		ready.merge(_reverse_capture_identity())
	_write(_role + ".reverse_ready", ready)
	if not await _reverse_wait(func(): return _flight_file_exists("host.reverse_go"), 8.0,
		"host authorizes ordinary reverse after both clients are ready"):
		return false
	_reverse_stage = _role + ".reverse_1m"
	if _role == "client":
		_action(&"move_back", true)
	var capture_observed := [_role != "client"]
	if not await _reverse_wait(func():
		if _role == "client" and _reverse_pilot_capture_matches(ready):
			capture_observed[0] = true
		# Keep sampling while held if the effect receipt arrives before this
		# client has observed its own produced frame; the host's 1s stays fixed.
		return bool(capture_observed[0]) and _flight_file_exists("host.reverse_effect"), 8.0,
		"normal local reverse is sampled and sent, and host proves its bounded backward effect"):
		return false
	if _role == "client":
		_action(&"move_back", false)
		_write("client.reverse_released", {"capture_observed": capture_observed[0]})
	_reverse_effect = _read("host.reverse_effect")
	_reverse_stage = _role + ".reverse_release"
	if not await _reverse_wait(func(): return _flight_file_exists("host.reverse_brake_go"), 8.0,
		"host proves fresh delivered neutral before authorizing ordinary brake"):
		return false
	_reverse_neutral = _read("host.reverse_brake_go")
	_reverse_stage = _role + ".brake_stop"
	if _role == "client":
		_action(&"brake", true)
	if not await _reverse_wait(func(): return _flight_file_exists("host.reverse_braked"), 10.0,
		"host consumes ordinary brake and holds its authoritative stop for1s inside10s"):
		return false
	if _role == "client":
		_action(&"brake", false)
		_write("client.reverse_brake_released", {})
	_reverse_stage = _role + ".brake_release"
	if not await _reverse_wait(func(): return _flight_file_exists("host.reverse_stopped"), 8.0,
		"host proves fresh delivered fully neutral command after brake release within1s"):
		return false
	_reverse_stopped = _read("host.reverse_stopped")
	_reverse_stage = _role + ".replica_convergence"
	if not await _reverse_wait(func():
		return _reverse_consumed_after(_reverse_stopped) \
			and _station_position().distance_to(_vector_from(_reverse_stopped.position)) <= 0.5 \
			and _body_follows_anchor(_player, _flight_anchor, true), 8.0,
		"actual local hull converges<=0.5m with a newer consumed host pose and original supported Player anchor"):
		return false
	_write(_role + ".reverse_converged", _reverse_client_receipt())
	if not await _reverse_wait(func(): return _flight_file_exists("host.reverse_complete"), 8.0,
		"host confirms both actual replicas inside its single5s deadline"):
		return false
	_reverse_stage = "retained"
	return true


func _remaining(started_msec: int, seconds: float) -> float:
	return maxf(0.0, float(started_msec + int(seconds * 1000.0) - Time.get_ticks_msec()) / 1000.0)


func _reverse_wait(predicate: Callable, seconds: float, description: String) -> bool:
	return await _flight_wait(func():
		if not _require(_reverse_stream_current(), "original producer/wire identity remains current throughout " + _reverse_stage):
			return false
		return bool(predicate.call()), seconds, description)


func _reverse_stream_current() -> bool:
	if _role == "host":
		return _flight_source.get_stream_id() == int(_reverse_start.source_stream) \
			and int((_flight_source as NetworkRemotePilotCommandSource).get_roll_receipt().get("stream", -1)) == int(_reverse_start.wire_receipt.stream)
	return _role != "client" or (_reverse_capture_identity() == _reverse_local_start \
		and int(_reverse_local_start.producer_id) == _flight_source.get_instance_id() \
		and int(_reverse_local_start.producer_stream) == _flight_source.get_stream_id() \
		and int(_reverse_local_start.session_id) == _game.network_session.get_instance_id() \
		and str(_reverse_local_start.ship_id) == str(_craft.ship_id))


func _reverse_host_command(throttle: float, brake: bool, previous: Dictionary) -> bool:
	var command := _craft.get_last_ship_command()
	var audit := (_flight_source as NetworkRemotePilotCommandSource).get_audit()
	var controls := audit.get("controls", {}) as Dictionary
	return command != null and command.is_valid() and command.stream_id == int(_reverse_start.source_stream) \
		and command.sequence > int(previous.command_sequence) and bool(audit.get("holding", false)) \
		and int(audit.get("delivered", 0)) > int(previous.delivered) \
		and is_equal_approx(command.throttle, throttle) and is_equal_approx(float(controls.get("throttle", INF)), throttle) \
		and command.brake == brake and bool(controls.get("brake", not brake)) == brake \
		and is_zero_approx(command.yaw) and is_zero_approx(command.pitch) and is_zero_approx(command.roll) \
		and is_zero_approx(command.look_yaw_delta) and is_zero_approx(command.look_pitch_delta) \
		and not command.boost and not command.hover and not command.fire \
		and not command.barrel_roll and not command.landing \
		and (brake or not is_zero_approx(throttle) or command.is_neutral())


func _reverse_pilot_capture_matches(ready: Dictionary) -> bool:
	var command := _craft.get_last_ship_command()
	var capture := _game.get("_network_remote_helm") as Dictionary
	return command != null and command.is_valid() and _flight_source is LocalShipInputSource \
		and command.stream_id == _flight_source.get_stream_id() and is_equal_approx(command.throttle, -1.0) \
		and int(capture.get("sample_sequence", -1)) >= command.sequence \
		and int(capture.get("sequence", 0)) > int(ready.get("wire_sequence", 0)) \
		and int(_game.get("_network_remote_helm_sent")) > int(ready.get("sent", 0))


func _reverse_capture_identity() -> Dictionary:
	var capture := _game.get("_network_remote_helm") as Dictionary
	return {"producer_id": int(capture.get("producer_id", 0)), "producer_stream": int(capture.get("producer_stream", -1)),
		"wire_stream": int(capture.get("stream_id", -1)), "session_id": int(capture.get("session_id", 0)),
		"ship_id": str(capture.get("ship_id", ""))}


func _reverse_consumed_after(host: Dictionary) -> bool:
	var sample := _flight_pose_sample()
	return int(sample.get("pose_tick", -1)) > int(host.get("pose_tick", 0)) \
		and int(sample.get("pilot_peer_id", 0)) == int(_flight_start.pilot_peer)


func _reverse_distance() -> float:
	return -(_station_position() - _vector_from(_reverse_start.position)).dot(_vector_from(_reverse_start.nose))


func _reverse_host_receipt() -> Dictionary:
	var result := _host_flight_receipt()
	var command := _craft.get_last_ship_command()
	result.merge({"nose": _vector_values(-_craft.global_basis.z.normalized()),
		"velocity": _vector_values(_craft.velocity), "command_sequence": command.sequence if command != null else -1,
		"command": command.to_dictionary() if command != null else {},
		"source_stream": _flight_source.get_stream_id(),
		"delivered": int((_flight_source as NetworkRemotePilotCommandSource).get_audit().get("delivered", 0)),
		"audit": (_flight_source as NetworkRemotePilotCommandSource).get_audit(),
		"wire_receipt": (_flight_source as NetworkRemotePilotCommandSource).get_roll_receipt()})
	if not _reverse_start.is_empty():
		result["reverse_distance_m"] = _reverse_distance()
	return result


func _reverse_client_receipt() -> Dictionary:
	var result := _client_flight_receipt()
	var capture := _game.get("_network_remote_helm") as Dictionary
	result.merge({"wire_sequence": int(capture.get("sequence", 0)), "sent": int(_game.get("_network_remote_helm_sent"))})
	return result


func _node_identity(node: Node) -> Dictionary:
	if not is_instance_valid(node):
		return {"valid": false}
	# Remote command sources can be valid while intentionally outside the tree.
	return {"valid": true, "instance_id": str(node.get_instance_id()),
		"path": str(node.get_path()) if node.is_inside_tree() else ""}


func _failure_snapshot(description: String) -> Dictionary:
	var snapshot := super._failure_snapshot(description)
	var reverse := {"stage": _reverse_stage, "start": _reverse_start, "local_start": _reverse_local_start,
		"effect": _reverse_effect, "neutral": _reverse_neutral, "stopped": _reverse_stopped,
		"move_back": Input.is_action_pressed(&"move_back"), "brake": Input.is_action_pressed(&"brake")}
	if is_instance_valid(_game) and is_instance_valid(_craft) and is_instance_valid(_player) \
		and is_instance_valid(_flight_source):
		reverse["actual"] = _reverse_host_receipt() if _role == "host" else _reverse_client_receipt()
	snapshot["reverse"] = reverse
	return snapshot
