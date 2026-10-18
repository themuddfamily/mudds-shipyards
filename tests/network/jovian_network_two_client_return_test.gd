## test-matrix-display: input-only
extends "res://tests/network/jovian_network_two_client_flight_test.gd"

## NET-JOVIAN-RETURN: extend the entire ordinary departure before the inherited
## retained-seat handshake. Input is the only action; all arrival facts are read.
const RETURN_NEUTRAL_ACTIONS := [&"move_forward", &"move_back", &"move_left", &"move_right",
	&"pitch_up", &"pitch_down", &"roll_left", &"roll_right", &"sprint_boost", &"brake",
	&"hover", &"fire", &"barrel_roll", &"interact"]
var _return_stage := "departure"
var _return_start: Dictionary = {}
var _return_generation := 0
var _return_landing_held := false


func _peer_profile() -> Dictionary:
	var profile := super._peer_profile()
	profile["script"] = "res://tests/network/jovian_network_two_client_return_test.gd"
	return profile


func _print_peer_success() -> void:
	# Inherited coordinator alone prints this after all actual peer OS exits0.
	print("JOVIAN_NETWORK_TWO_CLIENT_RETURN_OK checks=%d" % _checks)


func _host_scenario() -> bool:
	if not await super._host_scenario():
		return false
	_return_stage = "host.capture_and_availability"
	var report: Dictionary = _game.call(&"_get_landing_assist_report_for_ship", _craft)
	var capture := _primitive_fields(report, ["valid", "selected_berth_id", "assist_capture_accepted",
		"docked_hull_fits", "berth_available", "compatibility_accepted", "preview_non_mutating"])
	_return_start = {"capture": capture, "berth_id": str(_flight_berth.berth_id) if is_instance_valid(_flight_berth) else "",
		"pose_tick": int(_game.get("_network_boarding_server_tick")),
		"landing_request": (_flight_source as NetworkRemotePilotCommandSource).get_roll_receipt().get("landing_request", 0)}
	if not _require(_host_flight_identity_current() and _host_departure_is_physical()
		and is_instance_valid(_flight_berth) and _flight_berth.berth_id == &"jovian_freight_berth"
		and _craft.get_home_berth_id() == _flight_berth.berth_id
		and StringName(report.get("selected_berth_id", &"")) == _flight_berth.berth_id
		and bool(report.get("valid", false)) and bool(report.get("assist_capture_accepted", false))
		and bool(report.get("docked_hull_fits", false)) and bool(report.get("berth_available", false))
		and bool(report.get("compatibility_accepted", false)) and bool(report.get("preview_non_mutating", false))
		and _flight_berth.get_occupant() == null and _flight_berth.get_reservation_owner() == null
		and _flight_berth.can_accept(_craft.get_ship_definition(), _craft),
		"actual stopped craft has valid home capture/fit and a free compatible physical berth"):
		return false
	_write("host.return_start", _return_start)
	if not await _return_wait(func(): return _flight_files_ready(".return_ready"), 8.0,
		"both original seated clients are ready for one ordinary landing input"):
		return false
	_write("host.return_go", {})
	_return_stage = "host.accepted_request"
	if not await _return_wait(_host_return_request_accepted, 8.0,
		"authenticated original pilot's new landing request is accepted with current landing_pending handoff within8s"):
		return false
	_return_generation = int(_return_handoff().get("entity_generation", 0))
	_write("host.return_accepted", {"entity_generation": _return_generation})
	_return_stage = "host.physical_dock"
	if not await _return_wait(_host_return_docked, 120.0,
		"host physically docks at actual home transform with strict contract, valid occupied lease and committed landed publication within120s"):
		return false
	_write("host.return_docked", _host_return_receipt())
	_return_stage = "host.client_convergence"
	if not await _return_wait(func(): return _flight_files_ready(".return_converged"), 5.0,
		"both original clients consume committed landed arrival and converge actual hulls within5s of host completion"):
		return false
	if not _require(_host_return_docked() and _host_passenger_follows_anchor(true),
		"physical dock and original authoritative seated identities remain intact through both client arrivals"):
		return false
	_write("host.return_complete", _host_return_receipt())
	_return_stage = "retained"
	return true


func _client_scenario() -> bool:
	if not await super._client_scenario():
		return false
	var result := await _client_return()
	# Also release after any return failure, before inherited capture retention.
	if _role == "client":
		_action(&"landing_assist", false)
		Input.action_release(&"landing_assist")
	_return_landing_held = false
	return result


func _client_return() -> bool:
	_return_stage = "client.return_start"
	if not await _return_wait(func(): return _flight_file_exists("host.return_start"), 8.0,
		"host observes actual home capture and free berth at the unchanged stopped endpoint"):
		return false
	_return_start = _read("host.return_start")
	_write(_role + ".return_ready", {})
	if not await _return_wait(func(): return _flight_file_exists("host.return_go"), 8.0,
		"host authorizes one ordinary landing input after both seated clients are ready"):
		return false
	_return_stage = "client.accepted_request"
	if _role == "client":
		_return_landing_held = true
		_action(&"landing_assist", true)
		await _ticks(2)
		_action(&"landing_assist", false)
		_return_landing_held = false
	if not await _return_wait(func(): return _flight_file_exists("host.return_accepted"), 8.0,
		"host accepts the original pilot's single ordinary landing input within8s"):
		return false
	_return_generation = int(_read("host.return_accepted").get("entity_generation", 0))
	_return_stage = "client.physical_dock"
	if not await _return_wait(func(): return _flight_file_exists("host.return_docked"), 120.0,
		"host establishes physical home docking and committed arrival within120s"):
		return false
	var docked := _read("host.return_docked")
	_return_stage = "client.arrival_convergence"
	if not await _return_wait(func(): return _client_return_consumed(docked), 5.0,
		"actual hull converges<=0.5m, original Player anchor<=0.05m, fresh same-pilot pose and authoritative matching generation consume landed arrival within5s"):
		return false
	_write(_role + ".return_converged", _client_return_receipt())
	if not await _return_wait(func(): return _flight_file_exists("host.return_complete"), 8.0,
		"host retains original source, ownership and both seated generations after both committed arrivals"):
		return false
	_return_stage = "retained"
	return _require(_client_return_consumed(docked), "both original seated client identity and consumed physical arrival remain current")


func _return_wait(predicate: Callable, seconds: float, description: String) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline and not _aborted():
		if not _require(_host_flight_identity_current() if _role == "host" else
			(_local_flight_current() and _return_controls_neutral()),
			"original source/owner, real Players and seat/entity generations remain current throughout " + _return_stage):
			return false
		if bool(predicate.call()):
			return _require(true, description)
		await _ticks(1)
	return _require(false, description)


func _return_controls_neutral() -> bool:
	for action: StringName in RETURN_NEUTRAL_ACTIONS:
		if Input.is_action_pressed(action):
			return false
	return _return_landing_held or not Input.is_action_pressed(&"landing_assist")


func _return_handoff() -> Dictionary:
	return (_game.get("_network_landing_handoffs") as Dictionary).get(_craft.ship_id, {}) as Dictionary


func _host_return_request_accepted() -> bool:
	var binding := (_game.get("_network_remote_pilots") as Dictionary).get(_craft.ship_id, {}) as Dictionary
	var result := binding.get("landing_result", {}) as Dictionary
	var handoff := _return_handoff()
	var entity := _game.network_session.get_landing_entity(_craft.ship_id)
	return int((_flight_source as NetworkRemotePilotCommandSource).get_roll_receipt().get("landing_request", 0)) \
		> int(_return_start.get("landing_request", 0)) \
		and bool(result.get("accepted", false)) and result.get("status") == &"network_landing_reserved" \
		and handoff.get("entity_id") == _craft.ship_id and int(handoff.get("entity_generation", 0)) > 0 \
		and handoff.get("target_id") == _flight_berth.berth_id and handoff.get("state") == &"landing_pending" \
		and int(handoff.get("remote_pilot_peer_id", 0)) == int(_flight_start.pilot_peer) \
		and entity.get("state") == &"landing_pending" and int(entity.get("owner_peer_id", 0)) == 1 \
		and int(entity.get("entity_generation", 0)) == int(handoff.get("entity_generation", -1)) \
		and _craft.is_landing_active()


func _host_return_docked() -> bool:
	var contract := _craft.get_landing_contract_report()
	var handoff := _return_handoff()
	var entity := _game.network_session.get_landing_entity(_craft.ship_id)
	var token := StringName((_game.get("_berth_tokens") as Dictionary).get(_craft.get_instance_id(), &""))
	var dock := _flight_berth.get_dock_transform()
	return bool(_craft.get_telemetry().get("landed", false)) and not _craft.is_landing_active() \
		and _craft.velocity.length() <= 0.05 and _craft.global_position.distance_to(dock.origin) <= 0.05 \
		and rad_to_deg(_craft.global_basis.orthonormalized().get_rotation_quaternion().angle_to(
			dock.basis.orthonormalized().get_rotation_quaternion())) <= 0.5 \
		and bool(contract.get("contract_accepted", false)) and bool(contract.get("strict_dock_acceptance", false)) \
		and contract.get("phase") == HeroShip.LANDING_PHASE_DOCKED and contract.get("berth_id") == _flight_berth.berth_id \
		and bool(contract.get("reservation_token_bound", false)) \
		and _flight_berth.get_occupant() == _craft and _flight_berth.get_reservation_owner() == _craft \
		and not token.is_empty() and _flight_berth.has_valid_lease(_craft, token, _craft.ship_id) \
		and (_game.get("_reserved_berth_ids") as Dictionary).get(_craft.get_instance_id()) == _flight_berth.berth_id \
		and handoff.get("physical_token") == token and handoff.get("entity_id") == _craft.ship_id \
		and handoff.get("state") == &"landed" and handoff.get("target_id") == _flight_berth.berth_id \
		and _return_generation > 0 and int(handoff.get("entity_generation", 0)) == _return_generation \
		and handoff.has("completion_retry") and not bool(handoff.get("completion_retry", true)) \
		and entity.get("entity_id") == _craft.ship_id and entity.get("state") == &"landed" \
		and entity.get("target_id") == _flight_berth.berth_id \
		and int(entity.get("entity_generation", 0)) == _return_generation and int(entity.get("owner_peer_id", 0)) == 1


func _client_landing_record() -> Dictionary:
	var sections := _game.network_session.get_authoritative_snapshot().get("sections", {}) as Dictionary
	for landing: Dictionary in sections.get("landing", []):
		if StringName(landing.get("entity_id", &"")) == _craft.ship_id:
			return landing
	return {}


func _client_return_consumed(docked: Dictionary) -> bool:
	var sample := _flight_pose_sample()
	var operation := sample.get("operation_presentation", {}) as Dictionary
	var landing := _client_landing_record()
	# Client prediction intentionally stays physically unlanded; consumed host
	# presentation plus the authoritative landing section prove its arrival.
	return _local_flight_current() and _body_follows_anchor(_player, _flight_anchor, true) \
		and _station_position().distance_to(_vector_from(docked.position)) <= 0.5 \
		and int(sample.get("pose_tick", -1)) > int(docked.get("pose_tick", 0)) \
		and int(sample.get("pilot_peer_id", 0)) == int(_flight_start.pilot_peer) \
		and bool(operation.get("landed", false)) and bool(operation.get("docked", false)) \
		and not bool(operation.get("landing", true)) \
		and _return_generation > 0 and int(landing.get("entity_generation", 0)) == _return_generation \
		and StringName(landing.get("state", &"")) == &"landed" \
		and int(_game.network_session.get_owned_ship(_craft.ship_id).get("owner_peer_id", 0)) == int(_flight_start.pilot_peer)


func _host_return_receipt() -> Dictionary:
	var dock := _flight_berth.get_dock_transform()
	var token := StringName((_game.get("_berth_tokens") as Dictionary).get(_craft.get_instance_id(), &""))
	return {"position": _vector_values(_station_position()), "speed": _craft.velocity.length(),
		"landed": bool(_craft.get_telemetry().get("landed", false)), "landing_active": _craft.is_landing_active(),
		"dock_origin_error_m": _craft.global_position.distance_to(dock.origin),
		"dock_orientation_error_degrees": rad_to_deg(_craft.global_basis.orthonormalized().get_rotation_quaternion().angle_to(
			dock.basis.orthonormalized().get_rotation_quaternion())),
		"physical_lease_valid": not token.is_empty() and _flight_berth.has_valid_lease(_craft, token, _craft.ship_id),
		"bookkeeping_berth_id": str((_game.get("_reserved_berth_ids") as Dictionary).get(_craft.get_instance_id(), &"")),
		"pose_tick": int(_game.get("_network_boarding_server_tick")),
		"contract": _primitive_fields(_craft.get_landing_contract_report(),
			["phase", "contract_accepted", "strict_dock_acceptance", "berth_id", "reservation_token_bound"]),
		"handoff": _primitive_fields(_return_handoff(),
			["entity_id", "entity_generation", "target_id", "state", "remote_pilot_peer_id", "completion_retry"]),
		"landing_entity": _primitive_fields(_game.network_session.get_landing_entity(_craft.ship_id),
			["entity_id", "entity_generation", "owner_peer_id", "state", "target_id"])}


func _client_return_receipt() -> Dictionary:
	var sample := _flight_pose_sample()
	return {"position": _vector_values(_station_position()),
		"seat_anchor_error_m": _player.global_position.distance_to(_flight_anchor.global_position),
		"consumed_pose": _primitive_fields(sample, ["ship_id", "pose_tick", "pilot_peer_id"]),
		"operation": _primitive_fields(sample.get("operation_presentation", {}) as Dictionary, ["landed", "docked", "landing"]),
		"landing_record": _primitive_fields(_client_landing_record(), ["entity_id", "entity_generation", "state"])}


func _failure_snapshot(description: String) -> Dictionary:
	var snapshot := super._failure_snapshot(description)
	var arrival := {"stage": _return_stage, "start": _return_start, "entity_generation": _return_generation,
		"landing_input_held": Input.is_action_pressed(&"landing_assist")}
	if is_instance_valid(_game) and is_instance_valid(_craft) and is_instance_valid(_player):
		if _role == "host" and is_instance_valid(_flight_berth):
			arrival["physical"] = _host_return_receipt()
			arrival["occupant_is_craft"] = _flight_berth.get_occupant() == _craft
			arrival["reservation_owner_is_craft"] = _flight_berth.get_reservation_owner() == _craft
			var binding := (_game.get("_network_remote_pilots") as Dictionary).get(_craft.ship_id, {}) as Dictionary
			arrival["request_result"] = _primitive_fields(binding.get("landing_result", {}) as Dictionary, ["accepted", "status"])
		elif is_instance_valid(_flight_anchor):
			arrival["local"] = _client_return_receipt()
			arrival["controls_neutral"] = _return_controls_neutral()
	snapshot["return"] = arrival
	return snapshot
