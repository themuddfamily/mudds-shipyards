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
var _postdock_selected := false
var _postdock_active := false
var _postdock_exited := false
var _postdock_start: Dictionary = {}
var _postdock_body_id := 0
var _postdock_ground_start := Vector3.ZERO
var _postdock_exit_route_observed := false
var _postdock_exit_motion_observed := false
var _postdock_exit_samples: Array[Dictionary] = []
var _reboard_selected := false
var _reboard_active := false
var _reboard_complete := false
var _reboard_released: Dictionary = {}
var _reboard_cabin: Dictionary = {}
var _reboard_seated: Dictionary = {}
var _pilot_exit_selected := false
var _pilot_exit_active := false
var _pilot_exit_retired := false
var _pilot_exit_grounded := false
var _pilot_exit_complete := false
var _pilot_exit_start: Dictionary = {}
var _pilot_exit_ground_start := Vector3.ZERO
var _pilot_exit_helm_sent := -1
var _pilot_exit_route_observed := false
var _pilot_exit_motion_observed := false
var _pilot_exit_samples: Array[Dictionary] = []
var _pilot_exit_deadline := 0
var _pilot_reclaim_selected := false
var _pilot_reclaim_active := false
var _pilot_reclaim_complete := false
var _pilot_reclaim_retired: Dictionary = {}
var _pilot_reclaim_cabin: Dictionary = {}
var _pilot_reclaim_seated: Dictionary = {}
var _pilot_reclaim_producer: Dictionary = {}
var _pilot_reclaim_probe_results: Array[Dictionary] = []
var _pilot_reclaim_consumed_ready := false


func _run() -> void:
	_pilot_reclaim_selected = "--postdock-pilot-reclaim" in OS.get_cmdline_user_args()
	_pilot_exit_selected = _pilot_reclaim_selected or "--postdock-pilot-exit" in OS.get_cmdline_user_args()
	_reboard_selected = _pilot_exit_selected or "--postdock-passenger-reboard" in OS.get_cmdline_user_args()
	_postdock_selected = _reboard_selected or "--postdock-passenger-exit" in OS.get_cmdline_user_args()
	await super._run()


func _peer_arguments(role: String, display: PackedStringArray) -> PackedStringArray:
	var args := super._peer_arguments(role, display)
	if _postdock_selected:
		args.append("--postdock-passenger-exit")
	if _reboard_selected:
		args.append("--postdock-passenger-reboard")
	if _pilot_exit_selected:
		args.append("--postdock-pilot-exit")
	if _pilot_reclaim_selected:
		args.append("--postdock-pilot-reclaim")
	return args


func _peer_profile() -> Dictionary:
	var profile := super._peer_profile()
	profile["script"] = "res://tests/network/jovian_network_two_client_return_test.gd"
	return profile


func _print_peer_success() -> void:
	# Inherited coordinator alone prints this after all actual peer OS exits0.
	if _pilot_reclaim_selected:
		print("JOVIAN_NETWORK_TWO_CLIENT_PILOT_RECLAIM_OK checks=%d" % _checks)
	elif _pilot_exit_selected:
		print("JOVIAN_NETWORK_TWO_CLIENT_PILOT_EXIT_OK checks=%d" % _checks)
	elif _reboard_selected:
		print("JOVIAN_NETWORK_TWO_CLIENT_PASSENGER_REBOARD_OK checks=%d" % _checks)
	elif _postdock_selected:
		print("JOVIAN_NETWORK_TWO_CLIENT_PASSENGER_EXIT_OK checks=%d" % _checks)
	else:
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
	if _postdock_selected:
		return await _host_postdock_exit()
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
	if result and _postdock_selected:
		result = await _client_postdock_exit()
		if result and _reboard_selected:
			result = await _client_postdock_reboard()
		if result and _pilot_exit_selected:
			result = await _client_postdock_pilot_exit()
		if result and _pilot_reclaim_selected:
			result = await _client_postdock_pilot_reclaim()
		if not _pilot_exit_selected and physics_frame.is_connected(_postdock_observe):
			physics_frame.disconnect(_postdock_observe)
		_release_walk()
	return result


func _client() -> void:
	await super._client()
	# The selected final invariants also cover the inherited retained/leaving
	# handshake. Disconnect before its subsequent session teardown.
	if _pilot_exit_selected and physics_frame.is_connected(_postdock_observe):
		physics_frame.disconnect(_postdock_observe)


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
		await _press(&"landing_assist")
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


func _client_ownership_record() -> Dictionary:
	# Clients consume authority publication; their local authority registry is
	# intentionally empty and must not be used as a presentation snapshot.
	var sections := _game.network_session.get_authoritative_snapshot().get("sections", {}) as Dictionary
	for ownership: Dictionary in sections.get("ownership", []):
		if StringName(ownership.get("ship_id", &"")) == _craft.ship_id:
			return ownership
	return {}


func _client_return_consumed(docked: Dictionary) -> bool:
	var sample := _flight_pose_sample()
	var operation := sample.get("operation_presentation", {}) as Dictionary
	var landing := _client_landing_record()
	var ownership := _client_ownership_record()
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
		and int(ownership.get("owner_peer_id", 0)) == int(_flight_start.pilot_peer) \
		and int(ownership.get("ship_generation", 0)) == int(_flight_start.identities.ownership.ship_generation) \
		and int(ownership.get("ownership_generation", 0)) == int(_flight_start.identities.ownership.ownership_generation)


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
		"landing_record": _primitive_fields(_client_landing_record(), ["entity_id", "entity_generation", "state"]),
		"ownership_record": _primitive_fields(_client_ownership_record(),
			["ship_id", "ship_generation", "owner_peer_id", "ownership_generation", "state"])}


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
			var source := binding.get("source") as NetworkRemotePilotCommandSource
			if is_instance_valid(source):
				arrival["landing_request_serial"] = int(source.get_roll_receipt().get("landing_request", 0))
		elif is_instance_valid(_flight_anchor):
			arrival["local"] = _client_return_receipt()
			arrival["controls_neutral"] = _return_controls_neutral()
			arrival["local_identity_current"] = _local_flight_current()
	snapshot["return"] = arrival
	if _postdock_active:
		snapshot["postdock"] = _postdock_receipt()
		snapshot["postdock_start"] = _postdock_start
	if _reboard_active:
		snapshot["reboard"] = {"released": _reboard_released, "cabin": _reboard_cabin,
			"seated": _reboard_seated, "complete": _reboard_complete, "current": _reboard_receipt()}
	if _pilot_exit_active:
		snapshot["pilot_exit"] = _pilot_exit_receipt()
	if _pilot_reclaim_active:
		snapshot["pilot_reclaim"] = _pilot_reclaim_receipt()
	return snapshot


## This continuation starts only after the complete original physical return.
## Observations may retire a cabin body; the test never restores its binding.
func _host_postdock_exit() -> bool:
	_return_stage = "host.postdock_stand"
	var avatar := GameFlow.network_client_boarding_avatar_id(int(_flight_start.passenger_peer))
	var body := _game.get_network_remote_body_simulation().get_body(avatar) as PlayerController
	if not _require(body != null, "postdock starts with original authoritative passenger body"):
		return false
	_postdock_body_id = body.get_instance_id()
	_postdock_start = _postdock_receipt()
	_postdock_active = true
	_write("host.postdock_go", _postdock_start)
	if not await _postdock_wait(func():
		return (_flight_file_exists("client_b.postdock_stood")
			and _host_postdock_cabin_current()), 8.0,
		"original passenger releases exact co_pilot_station and stands supported with original cabin berth/body within8s"):
		return false
	_write("host.postdock_stand_checked", _postdock_receipt())
	_return_stage = "host.postdock_cabin_walk"
	if not await _postdock_wait(func():
		if not _flight_file_exists("client_b.postdock_hatch") or not _host_postdock_cabin_current():
			return false
		var current := _game.get_network_remote_body_simulation().get_body(avatar) as PlayerController
		return (current.global_position.distance_to(_postdock_hatch_approach()) <= 0.5
			and current.global_position.distance_to(_craft.to_global(_vector_from(_read("client_b.postdock_stood").ship_local_position))) >= 0.6),
		15.0, "host observes actual supported cabin locomotion from released chair to authored hatch approach"):
		return false
	_write("host.postdock_hatch_checked", _postdock_receipt())
	_return_stage = "host.postdock_exterior"
	if not await _postdock_wait(func():
		return (_flight_file_exists("client_b.postdock_exterior")
			and _host_postdock_released()), 8.0,
		"ordinary hatch exit releases passenger cabin occupancy, chair, moving-body publication and movement generation within8s"):
		return false
	_postdock_exited = true
	_write("host.postdock_exterior_checked", _postdock_receipt())
	_return_stage = "host.postdock_ground_walk"
	if not await _postdock_wait(func():
		return (_flight_file_exists("client_b.postdock_ground_walk")
			and _flight_file_exists("client.postdock_retained") and _host_postdock_released()), 15.0,
		"original pilot consumes unchanged landed arrival while original passenger measurably walks supported berth ground"):
		return false
	var ground := _read("client_b.postdock_ground_walk")
	if not _require(bool(ground.get("selected", false)) and bool(ground.get("ground_supported", false))
		and float(ground.get("ground_distance_m", 0.0)) >= 1.0
		and bool(_read("client.postdock_retained").get("selected", false)),
		"both original clients explicitly consumed the selected continuation and real ground-walk result"):
		return false
	_write("host.postdock_complete", _postdock_receipt())
	if _reboard_selected:
		return await _host_postdock_reboard()
	_return_stage = "postdock.retained"
	return true


func _client_postdock_exit() -> bool:
	_return_stage = "client.postdock_start"
	if not await _return_wait(func(): return _flight_file_exists("host.postdock_go"), 8.0,
		"selected host confirms complete original return before any passenger release"):
		return false
	if not _require(bool(_read("host.postdock_go").get("selected", false)),
		"host explicitly selected postdock passenger exit on its original process"):
		return false
	_postdock_start = _postdock_receipt()
	_postdock_active = true
	# Keep checking during inherited ordinary walk/look/input helpers as well.
	physics_frame.connect(_postdock_observe)
	if _role == "client":
		for boundary: Array in [["host.postdock_stand_checked", 8.0], ["host.postdock_hatch_checked", 15.0],
			["host.postdock_exterior_checked", 8.0], ["client_b.postdock_ground_walk", 15.0]]:
			if not await _postdock_wait(func(): return _flight_file_exists(str(boundary[0])), float(boundary[1]),
				"original pilot retains helm/source/stream/delivery epoch through " + str(boundary[0])):
				return false
		_write("client.postdock_retained", _postdock_receipt())
		return await _postdock_wait(func(): return _flight_file_exists("host.postdock_complete"), 8.0,
			"original pilot consumes unchanged landed home arrival at completed passenger exit")
	_return_stage = "client_b.postdock_stand"
	await _press(&"interact")
	if not await _postdock_wait(_local_postdock_cabin_current, 8.0,
		"sampled ordinary Interact consumes chair release and restores supported unseated original Player within8s"):
		return false
	_write("client_b.postdock_stood", _postdock_receipt())
	if not await _postdock_wait(func(): return _flight_file_exists("host.postdock_stand_checked"), 8.0,
		"host independently confirms actual chair release before cabin/hatch occupancy release"):
		return false
	_return_stage = "client_b.postdock_cabin_walk"
	if not await _walk_to((_craft as JovianLightFreighter).get_cabin_stand_transform().origin, true):
		return false
	# Cross aft of the solid pilot-chair back before turning toward the hatch.
	# A direct diagonal from the cabin stand intersects that chair's collider.
	# This port clearance also leaves room for the ordinary 0.30 m walk radius.
	if not await _walk_to(_craft.to_global(Vector3(-1.10, 0.52, -6.70)), true):
		return false
	var route := _craft.get_exterior_exit_waypoints()
	if not _require(route.size() >= 3, "same Jovian retains authored cockpit-to-hatch exit waypoints"):
		return false
	# These exterior poses belong to the confirmed exit animation. Interact
	# from the supported cabin, outside the pilot-seat promotion radius, before
	# the production exit opens the door and follows every exterior waypoint.
	if not await _walk_to(_postdock_hatch_approach(), true):
		return false
	if not _require(_local_postdock_cabin_current(), "same supported cabin body reaches authored hatch approach"):
		return false
	_write("client_b.postdock_hatch", _postdock_receipt())
	if not await _postdock_wait(func(): return _flight_file_exists("host.postdock_hatch_checked"), 8.0,
		"host consumes original body walking to actual hatch before exit input"):
		return false
	_return_stage = "client_b.postdock_hatch_interact"
	if not _require(not _game._network_client_near_pilot_seat(_craft),
		"ordinary cabin exit prompt is outside the pilot-seat promotion radius"):
		return false
	await _look(_craft.get_boarding_position() + Vector3.UP * 1.2)
	_write("client_b.postdock_interaction", _postdock_receipt())
	if not await _postdock_wait(func():
		return (_game.boarding_candidate == _craft
			and not is_instance_valid(_game.station_interaction_candidate)), 8.0,
		"ordinary aim discovers actual pilot-hatch boarding interaction away from occupied helm"):
		return false
	await _press(&"interact")
	# Production owns the transition and any cabin-body retirement. Do not walk
	# from a misplaced spawn back to the berth to manufacture a successful exit.
	_return_stage = "client_b.postdock_exterior"
	if not await _postdock_wait(_local_postdock_ground_current, 8.0,
		"hatch Interact leaves original Player supported beside authored berth exit with released cabin/hatch/body claims within8s"):
		return false
	if not _require(_postdock_exit_route_observed and _postdock_exit_motion_observed,
		"confirmed exit physically traverses the complete original authored exterior route instead of relocating to station spawn"):
		return false
	_postdock_exited = true
	_postdock_ground_start = _player.global_position - _game.world.global_position
	_write("client_b.postdock_exterior", _postdock_receipt())
	if not await _postdock_wait(func(): return _flight_file_exists("host.postdock_exterior_checked"), 8.0,
		"host confirms legitimate cabin-body retirement before exterior locomotion"):
		return false
	_return_stage = "client_b.postdock_ground_walk"
	var clear := _postdock_ground_exit() - _craft.global_basis.x.normalized() * 1.5
	if not await _walk_to(clear, false):
		return false
	if not _require(_local_postdock_ground_current() and _postdock_ground_distance() >= 1.0,
		"ordinary input walks same supported Player at least1m clear on freight-berth ground"):
		return false
	_write("client_b.postdock_ground_walk", _postdock_receipt())
	return await _postdock_wait(func(): return _flight_file_exists("host.postdock_complete"), 8.0,
		"selected host confirms original pilot, occupied home lease and passenger exterior result together")


func _postdock_observe() -> void:
	if _postdock_active and not _aborted():
		_require(_postdock_invariants(), "original peer/Player, current landed owner and uninvolved pilot remain valid throughout " + _return_stage)
		if _pilot_reclaim_active:
			return
		if _pilot_exit_active:
			_observe_pilot_exit_motion()
			return
		if _role == "client_b" and _return_stage == "client_b.postdock_exterior" \
				and int(_player.get("_embodiment_state")) == PlayerController.EmbodimentState.DISEMBARKING:
			var expected := _craft.get_exterior_exit_waypoints()
			var actual := _player.get("_transition_waypoints") as Array
			var current: bool = _player.get("_transition_frame") == _craft and actual.size() == expected.size() + 1
			if not actual.is_empty():
				current = current and (actual[0] as Transform3D).origin.is_equal_approx(
					_craft.to_global(Vector3(-1.10, 0.52, -6.70)))
			for index in mini(maxi(actual.size() - 1, 0), expected.size()):
				current = current and (actual[index + 1] as Transform3D).is_equal_approx(expected[index])
			_require(current, "live production passenger exit retains every original authored exterior waypoint and frame")
			_postdock_exit_route_observed = _postdock_exit_route_observed or current
			var position := _craft.to_local(_player.global_position)
			if not _postdock_exit_samples.is_empty():
				_postdock_exit_motion_observed = _postdock_exit_motion_observed \
					or position.distance_to(_vector_from(_postdock_exit_samples[0].position)) >= 1.0
			_postdock_exit_samples.append({"tick": Engine.get_physics_frames(), "position": _vector_values(position)})


func _postdock_wait(predicate: Callable, seconds: float, description: String) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline and not _aborted():
		if not _require(_postdock_invariants(), "postdock retained pilot/home/identity invariants throughout " + _return_stage):
			return false
		if bool(predicate.call()):
			return _require(true, description)
		await _ticks(1)
	return _require(false, description)


func _postdock_invariants() -> bool:
	if _pilot_reclaim_active:
		return _pilot_reclaim_invariants()
	if _pilot_exit_active:
		return _pilot_exit_invariants()
	if _role == "host":
		var remote := (_game.get("_network_remote_pilots") as Dictionary).get(_craft.ship_id, {}) as Dictionary
		var source := remote.get("source") as NetworkRemotePilotCommandSource
		var manifest := _host_flight_manifest()
		return _host_return_docked() and _pilot_is_current(int(_flight_start.pilot_peer)) \
			and source == _flight_source and source != null and source.is_enabled_owner() \
			and source.get_pilot_peer_id() == int(_flight_start.pilot_peer) and source.get_ship_id() == _craft.ship_id \
			and _craft.get("_command_source") == source \
			and source.get_stream_id() == int(_postdock_start.source.stream_id) \
			and source.get_delivery_generation() == int(_postdock_start.source.delivery_generation) \
			and manifest.client == _flight_manifest.client and manifest.ownership == _flight_manifest.ownership \
			and _peer_generation(int(_flight_start.passenger_peer)) == int(_flight_manifest.client_b.peer_generation) \
			and _game.phase == GameFlow.Phase.INTRO and not _player.is_seated() and not _player.is_control_enabled() \
			and (_reboard_cabin.is_empty() or _reboard_cabin_identity_current()) \
			and (not _reboard_complete or _host_reboard_seated_current())
	var source := _craft.get("_default_local_command_source") as ShipCommandSource
	var active := _craft.get("_command_source") as ShipCommandSource
	return _same_identity() and _walking_identity_is_preserved() \
		and _postdock_arrival_current() \
		and (source == null or (source.get_stream_id() == int(_postdock_start.source.stream_id)
			and source.get_delivery_generation() == int(_postdock_start.source.delivery_generation))) \
		and (_local_flight_current() and _return_controls_neutral()
			and (not _reboard_complete or _reboard_relationship_matches(_reboard_seated, true)) if _role == "client" else
			((source == null or not source.is_enabled_owner()) and (active == null or not active.is_enabled_owner())
			and not bool(_game.get("_piloting"))
			and (not _postdock_exited or _reboard_active or _local_postdock_ground_current())
			and (_reboard_cabin.is_empty() or _reboard_cabin_identity_current())
			and (not _reboard_complete or _local_reboard_seated_current(_reboard_seated))))


func _postdock_arrival_current() -> bool:
	var landing := _client_landing_record()
	var ownership := _client_ownership_record()
	var sample := _flight_pose_sample()
	var operation := sample.get("operation_presentation", {}) as Dictionary
	return int(sample.get("pilot_peer_id", 0)) == int(_flight_start.pilot_peer) \
		and bool(operation.get("landed", false)) and bool(operation.get("docked", false)) \
		and not bool(operation.get("landing", true)) and landing.get("state") == &"landed" \
		and int(landing.get("entity_generation", 0)) == _return_generation \
		and _station_position().distance_to(_vector_from(_read("host.return_docked").position)) <= 0.5 \
		and int(ownership.get("owner_peer_id", 0)) == int(_flight_start.pilot_peer) \
		and int(ownership.get("ship_generation", 0)) == int(_flight_start.identities.ownership.ship_generation) \
		and int(ownership.get("ownership_generation", 0)) == int(_flight_start.identities.ownership.ownership_generation)


func _postdock_occupancies() -> Array:
	var held: Array = []
	var peer := int(_flight_start.passenger_peer)
	var avatar := GameFlow.network_client_boarding_avatar_id(peer)
	for row: Dictionary in _game.network_session.get_boarding_snapshot().get("occupancies", []):
		if int(row.get("peer_id", 0)) == peer or row.get("avatar_id") == avatar:
			held.append(_primitive_fields(row, ["peer_id", "avatar_id", "ship_id", "ship_generation",
				"frame_id", "frame_generation", "role", "seat_id", "seat_generation", "claim_sequence"]))
	return held


func _host_postdock_cabin_current() -> bool:
	var peer := int(_flight_start.passenger_peer)
	var avatar := GameFlow.network_client_boarding_avatar_id(peer)
	var simulation := _game.get_network_remote_body_simulation()
	var body := simulation.get_body(avatar) as PlayerController
	var record := simulation.get_body_record(avatar)
	var publication := _publication(avatar)
	var wire := publication.get("wire", {}) as Dictionary
	var owner: CrewSeatRoleAuthority = _craft.get_crew_role_authority()
	return body != null and body.get_instance_id() == _postdock_body_id \
		and body.is_on_floor() and not body.is_seated() \
		and body.get_cabin_containment_report().get("frame") == _craft \
		and record.get("seat_state") == &"standing" and int(record.get("owner_peer_id", 0)) == peer \
		and int(record.get("entity_generation", 0)) == int(_postdock_host_generation()) \
		and simulation.get_body_crew_seat(avatar) == null and owner != null and owner.get_assignment(peer, avatar).is_empty() \
		and _postdock_occupancies() == _postdock_start.occupancies \
		and publication.get("occupant") == body and not bool(publication.get("seated", true)) \
		and int(wire.get("entity_generation", 0)) == int(_postdock_host_generation()) \
		and wire.get("parent_frame_id") == StringName("frame_%s" % _craft.ship_id) \
		and int(wire.get("parent_frame_generation", 0)) == int(_flight_manifest.client_b.wire.parent_frame_generation) \
		and int(wire.get("occupancy_state", -1)) == NetworkMovingInteriorRelationship.STATE_WALKING


func _postdock_host_generation() -> int:
	return int(_flight_manifest.client_b.wire.entity_generation)


func _local_postdock_cabin_current() -> bool:
	var view := _game.network_session.get_passenger_replica_snapshot()
	var source := _game.get_network_remote_body_intent_source()
	var relationship := _game.network_session.get_moving_interior_latest_relationship(
		GameFlow.network_client_boarding_avatar_id(_initial_peer_id))
	return _supported_cabin() and not _player.is_seated() and not _player.is_station_seated() \
		and _player.get_cabin_containment_report().get("frame") == _craft \
		and not bool(view.get("seated", true)) and (view.get("assignment", {}) as Dictionary).is_empty() \
		and (_game.get("_network_client_boarding_claim") as Dictionary) == _postdock_start.claim \
		and source != null and source.is_bound() and source.get_entity_id() == StringName(_walking_identity.entity_id) \
		and source.get_entity_generation() == int(_walking_identity.entity_generation) \
		and int(relationship.get("entity_generation", 0)) == source.get_entity_generation() \
		and relationship.get("parent_frame_id") == StringName("frame_%s" % _craft.ship_id) \
		and int(relationship.get("parent_frame_generation", 0)) == int(_postdock_start.relationship.parent_frame_generation) \
		and int(relationship.get("occupancy_state", -1)) == NetworkMovingInteriorRelationship.STATE_WALKING


func _host_postdock_released() -> bool:
	var peer := int(_flight_start.passenger_peer)
	var avatar := GameFlow.network_client_boarding_avatar_id(peer)
	var simulation := _game.get_network_remote_body_simulation()
	var owner: CrewSeatRoleAuthority = _craft.get_crew_role_authority()
	return _postdock_occupancies().is_empty() and owner != null and owner.get_assignment(peer, avatar).is_empty() \
		and simulation.get_body(avatar) == null and simulation.get_body_record(avatar).is_empty() \
		and _game.network_session.get_movement_avatar_snapshot(avatar).is_empty() \
		and _publication(avatar).is_empty() and _game.network_session.get_moving_interior_occupancy(avatar).is_empty()


func _local_postdock_ground_current() -> bool:
	var source := _game.get_network_remote_body_intent_source()
	var view := _game.network_session.get_passenger_replica_snapshot()
	var avatar := GameFlow.network_client_boarding_avatar_id(_initial_peer_id)
	var area := _craft.get_node_or_null(^"ShipBoardingArea") as ShipBoardingArea
	return _same_identity() and _walking_identity_is_preserved() \
		and not bool(_game.get("_transition_busy")) and not _player.is_seated() and not _player.is_station_seated() \
		and _player.is_on_floor() and _player.is_control_enabled() \
		and _game.phase in [GameFlow.Phase.APPROACH_SHIP, GameFlow.Phase.COMPLETE] \
		and not bool(_player.get_cabin_containment_report().get("active", true)) \
		and not (_craft.get_moving_interior_component() as MovingInteriorFrame).is_occupant_registered(_player) \
		and _game.get("_cabin_ship") == null and _game.get("_boarding_area") == null \
		and (_game.get("_network_client_boarding_claim") as Dictionary).is_empty() \
		and (_game.get("_network_client_boarding_request") as Dictionary).is_empty() \
		and (source == null or not source.is_bound()) \
		and not bool(view.get("seated", true)) and (view.get("assignment", {}) as Dictionary).is_empty() \
		and _game.network_session.get_moving_interior_latest_relationship(avatar).is_empty() \
		and area != null and area.get_reservation_token() != _player \
		and _player.global_position.distance_to(_postdock_ground_exit()) <= 2.5


## Only the selected final inherited handshake changes its passenger predicate.
## All original board, departure and complete-return calls still use super.
func _passenger_is_current(peer: int) -> bool:
	if _postdock_selected and _postdock_exited and _role == "host":
		if _reboard_complete:
			return peer == int(_flight_start.passenger_peer) and _postdock_invariants() and _host_reboard_seated_current()
		return peer == int(_flight_start.passenger_peer) and _postdock_invariants() and _host_postdock_released()
	return super._passenger_is_current(peer)


func _pilot_is_current(peer: int) -> bool:
	if _pilot_reclaim_selected and _pilot_reclaim_complete and _role == "host":
		return peer == int(_flight_start.pilot_peer) and _pilot_reclaim_invariants() and _host_pilot_reclaim_seated_current()
	if _pilot_exit_selected and _pilot_exit_complete and _role == "host":
		return peer == int(_flight_start.pilot_peer) and _pilot_exit_invariants() and _host_pilot_exit_retired()
	return super._pilot_is_current(peer)


## A fresh boarding is allowed only after the complete accepted exterior walk.
## Keep the released context immutable; a new claim is not the old flight seat.
func _host_postdock_reboard() -> bool:
	_return_stage = "host.reboard_start"
	if not _require(_host_postdock_released() and _flight_file_exists("host.postdock_complete"),
		"reboard begins after accepted actual exit with every original passenger claim retired"):
		return false
	_reboard_released = {"body_id": str(_postdock_body_id),
		"identity": _flight_manifest.client_b.duplicate(true),
		"occupancies": _postdock_start.occupancies.duplicate(true),
		"assignment": _postdock_start.assignment.duplicate(true), "released": _postdock_receipt()}
	_reboard_active = true
	_write("host.reboard_go", _reboard_released)
	_return_stage = "host.reboard_clearance"
	if not await _postdock_wait(func(): return _flight_file_exists("client_b.reboard_clear"), 15.0,
		"same supported exterior passenger ordinarily clears existing reboard suppression with old grants retired"):
		return false
	if not _require(_host_postdock_released(), "ordinary clearance cannot restore any released passenger grant"):
		return false
	_write("host.reboard_clear_checked", _postdock_receipt())
	_return_stage = "host.reboard_approach"
	if not await _postdock_wait(func(): return _flight_file_exists("client_b.reboard_hatch_approached"), 15.0,
		"original exterior passenger walks back to authored hatch inside existing waypoint bound"):
		return false
	if not await _postdock_wait(func(): return _flight_file_exists("client_b.reboard_hatch"), 8.0,
		"ordinary exterior look discovers original hatch inside existing interaction bound"):
		return false
	_return_stage = "host.reboard_cabin"
	if not await _postdock_wait(func():
		return (_flight_file_exists("client_b.reboard_cabin") and _host_reboard_body_current(false)),
		8.0, "same authenticated passenger ordinarily reboards with one fresh cabin claim and a new supported body on an advanced input stream within8s"):
		return false
	_reboard_cabin = _reboard_receipt()
	_write("host.reboard_cabin_checked", _reboard_cabin)
	if not await _postdock_wait(func(): return _flight_file_exists("client_b.reboard_cabin_consumed"), 5.0,
		"passenger consumes host-confirmed fresh body/frame and exact boarding grant within5s"):
		return false
	_return_stage = "host.reboard_chair"
	# The unchanged waypoint helper owns its15s locomotion bound; allow that
	# walk before starting the existing8s physical chair transition bound.
	if not await _postdock_wait(func(): return _flight_file_exists("client_b.reboard_chair_approached"),
		15.0, "original passenger walks from fresh supported cabin berth to its authored co-pilot chair"):
		return false
	if not await _postdock_wait(func(): return _flight_file_exists("client_b.reboard_chair"), 8.0,
		"ordinary passenger look discovers exact original chair inside existing transition bound"):
		return false
	if not await _postdock_wait(_host_reboard_seated_current, 8.0,
		"ordinary passenger Interact claims exactly one original co_pilot_station with current fresh body/frame/seat generations within8s"):
		return false
	_reboard_seated = _reboard_receipt()
	_write("host.reboard_seated", _reboard_seated)
	_return_stage = "host.reboard_convergence"
	if not await _postdock_wait(func(): return _flight_files_ready(".reboard_converged"), 5.0,
		"both actual clients consume the current fresh passenger body/frame and seated chair result within5s"):
		return false
	if not _require(_host_reboard_seated_current(), "same original pilot and strict occupied home lease survive both actual client confirmations"):
		return false
	_reboard_complete = true
	_write("host.reboard_complete", _reboard_receipt())
	if _pilot_exit_selected:
		return await _host_postdock_pilot_exit()
	_return_stage = "reboard.retained"
	return true


func _client_postdock_reboard() -> bool:
	_return_stage = _role + ".reboard_start"
	if not _require(_flight_file_exists("host.postdock_complete") and (_role != "client_b" or _postdock_exited),
		"complete original passenger exit precedes selected reboard phase"):
		return false
	# Only this accepted phase boundary releases the exterior-only invariant.
	_reboard_active = true
	if not await _postdock_wait(func(): return _flight_file_exists("host.reboard_go"), 8.0,
		"host independently confirms retired passenger context before any reboard input"):
		return false
	_reboard_released = _read("host.reboard_go")
	if _role == "client":
		if not await _postdock_wait(func(): return _flight_file_exists("client_b.reboard_clear"), 15.0,
			"original pilot retains helm while passenger ordinarily clears existing reboard suppression"):
			return false
		if not await _postdock_wait(func(): return _flight_file_exists("host.reboard_clear_checked"), 8.0,
			"host confirms old passenger grants remain retired at clearance"):
			return false
		if not await _postdock_wait(func(): return _flight_file_exists("client_b.reboard_hatch_approached"), 15.0,
			"original pilot retains helm while passenger walks to same hatch"):
			return false
		if not await _postdock_wait(func(): return _flight_file_exists("client_b.reboard_hatch"), 8.0,
			"original pilot retains helm while passenger discovers hatch interaction"):
			return false
		if not await _postdock_wait(func(): return _flight_file_exists("host.reboard_cabin_checked"), 8.0,
			"original pilot retains helm through fresh passenger cabin admission"):
			return false
		if not await _postdock_wait(func(): return _flight_file_exists("client_b.reboard_cabin_consumed"), 5.0,
			"original pilot retains helm through passenger fresh grant convergence"):
			return false
		if not await _postdock_wait(func(): return _flight_file_exists("client_b.reboard_chair_approached"), 15.0,
			"original pilot retains helm through passenger walk to original chair"):
			return false
		if not await _postdock_wait(func(): return _flight_file_exists("client_b.reboard_chair"), 8.0,
			"original pilot retains helm through passenger aim at original chair"):
			return false
		return await _client_reboard_convergence()
	if not _require(_local_postdock_ground_current(), "same supported exterior Player retains fully released claims before walking back"):
		return false
	_return_stage = "client_b.reboard_clearance"
	# Reuse the accepted ingress corridor; the direct lateral path crosses
	# ServiceCabinet02. Both goals remain on the authored freight apron.
	var corridor := Vector3(-42.0, 0.38, _craft.get_boarding_position().z)
	var clear := corridor - Vector3(0.0, 0.0, GameFlow.BOARDING_FALLBACK_REACH + 1.5)
	if not await _walk_to(corridor, false):
		return false
	if not await _walk_to(clear, false):
		return false
	var retired_source := _game.get_network_remote_body_intent_source()
	if not _require(_same_identity() and _player.get_instance_id() == _initial_player_id
		and _player.is_on_floor() and _player.is_control_enabled() and not _player.is_seated()
		and not _player.is_station_seated() and not _game.get("_transition_busy")
		and not bool(_player.get_cabin_containment_report().get("active", true))
		and (_game.get("_network_client_boarding_claim") as Dictionary).is_empty()
		and (retired_source == null or not retired_source.is_bound())
		and _game.get("_reboard_blocked_ship") != _craft
		and _player.get_interaction_origin().distance_to(_craft.get_boarding_position()) > GameFlow.BOARDING_FALLBACK_REACH,
		"same supported original passenger physically clears production7m suppression without reviving old claims"):
		return false
	_write("client_b.reboard_clear", _reboard_receipt())
	if not await _postdock_wait(func(): return _flight_file_exists("host.reboard_clear_checked"), 8.0,
		"host confirms old passenger grant retirement before ordinary return to hatch"):
		return false
	_return_stage = "client_b.reboard_approach"
	if not await _walk_to(corridor, false):
		return false
	if not await _walk_to(_craft.get_boarding_position(), false):
		return false
	_write("client_b.reboard_hatch_approached", _reboard_receipt())
	await _look(_craft.get_boarding_position() + Vector3.UP * 1.2)
	if not await _postdock_wait(func():
		return (_game.boarding_candidate == _craft and not is_instance_valid(_game.station_interaction_candidate)),
		8.0, "ordinary walk and aim rediscover same authored hatch from actual berth ground"):
		return false
	_write("client_b.reboard_hatch", _reboard_receipt())
	_return_stage = "client_b.reboard_hatch_interact"
	await _press(&"interact")
	if not await _postdock_wait(_local_reboard_cabin_current, 8.0,
		"ordinary hatch Interact consumes new boarding answer and supported original Player with current body generation and advanced input stream within8s"):
		return false
	_write("client_b.reboard_cabin", _reboard_receipt())
	if not await _postdock_wait(func(): return _flight_file_exists("host.reboard_cabin_checked"), 8.0,
		"host independently observes new body and cabin claim after old exterior context was retired"):
		return false
	_reboard_cabin = _read("host.reboard_cabin_checked")
	if not await _postdock_wait(func():
		return (_local_reboard_cabin_current() and _reboard_relationship_matches(_reboard_cabin, false)), 5.0,
		"actual consumed fresh body/frame agrees with host before accepting new walking-helper identity"):
		return false
	var source := _game.get_network_remote_body_intent_source()
	# This is a phase-specific expected identity captured from accepted runtime
	# facts, after proving both local consumption and independent host identity.
	_walking_identity = {"peer_id": _initial_peer_id, "entity_id": str(source.get_entity_id()),
		"entity_generation": source.get_entity_generation(), "player_id": str(_initial_player_id)}
	_write("client_b.reboard_cabin_consumed", _reboard_receipt())
	_return_stage = "client_b.reboard_chair_approach"
	var contract := (_craft as JovianLightFreighter).get_passenger_station_role_contract()
	if not await _walk_to((contract.entry_transform as Transform3D).origin, true):
		return false
	_write("client_b.reboard_chair_approached", _reboard_receipt())
	await _look((_craft as JovianLightFreighter).get_copilot_seat_anchor().global_position + _craft.global_basis.y.normalized() * 1.2)
	if not await _postdock_wait(func():
		return (_game.station_interaction_candidate is ShipCrewSeat
			and (_game.station_interaction_candidate as ShipCrewSeat).get_seat_anchor()
				== (_craft as JovianLightFreighter).get_copilot_seat_anchor()),
		8.0, "ordinary cabin walk and look discover original co_pilot_station"):
		return false
	_write("client_b.reboard_chair", _reboard_receipt())
	_return_stage = "client_b.reboard_chair_interact"
	await _press(&"interact")
	if not await _postdock_wait(func(): return _flight_file_exists("host.reboard_seated"), 8.0,
		"host confirms fresh exact chair claim after ordinary passenger Interact within8s"):
		return false
	return await _client_reboard_convergence()


func _client_reboard_convergence() -> bool:
	if not await _postdock_wait(func(): return _flight_file_exists("host.reboard_seated"),
		8.0, "original pilot retains helm during bounded passenger chair transition"):
		return false
	_reboard_seated = _read("host.reboard_seated")
	_return_stage = _role + ".reboard_convergence"
	if not await _postdock_wait(func():
		return (_reboard_relationship_matches(_reboard_seated, true)
			and (_role == "client" or _local_reboard_seated_current(_reboard_seated))),
		5.0, "actual consumed fresh passenger body/frame and co-pilot anchor agree with host's unique current chair claim within5s"):
		return false
	_write(_role + ".reboard_converged", _reboard_receipt())
	if not await _postdock_wait(func(): return _flight_file_exists("host.reboard_complete"), 8.0,
		"host confirms both actual clients and retained pilot/home lease at complete passenger reboard"):
		return false
	_reboard_complete = true
	_return_stage = "reboard.retained"
	return _require(_reboard_relationship_matches(_reboard_seated, true)
		and (_role == "client" or _local_reboard_seated_current(_reboard_seated)),
		"fresh passenger identity remains consumed at original chair through final inherited retention handshake")


func _host_reboard_body_current(seated: bool) -> bool:
	var peer := int(_flight_start.passenger_peer)
	var avatar := GameFlow.network_client_boarding_avatar_id(peer)
	var simulation := _game.get_network_remote_body_simulation()
	var body := simulation.get_body(avatar) as PlayerController
	var record := simulation.get_body_record(avatar)
	var publication := _publication(avatar)
	var wire := publication.get("wire", {}) as Dictionary
	var held := _postdock_occupancies()
	var movement := _game.network_session.get_movement_avatar_snapshot(avatar)
	if body == null or held.size() != 1 or _reboard_released.is_empty():
		return false
	var claim := held[0] as Dictionary
	var previous := (_reboard_released.occupancies as Array)[0] as Dictionary
	# Same-generation rebinding is supported; this admission has a new body,
	# boarding claim and input stream, all checked against their real owners.
	var current_entity := int(record.get("entity_generation", 0))
	var admitted_source := _read("client_b.reboard_cabin").get("body_source", {}) as Dictionary
	var retired_source := _read("client_b.postdock_stood").get("body_source", {}) as Dictionary
	return body.get_instance_id() != _postdock_body_id \
		and _peer_generation(peer) == int(_flight_manifest.client_b.peer_generation) \
		and current_entity > 0 \
		and int(record.get("owner_peer_id", 0)) == peer and record.get("entity_id") == avatar \
		and body.get_cabin_containment_report().get("frame") == _craft \
		and (body.is_seated() if seated else body.is_on_floor() and not body.is_seated()) \
		and claim.get("avatar_id") == str(avatar) and int(claim.get("peer_id", 0)) == peer \
		and claim.get("ship_id") == str(_craft.ship_id) and claim.get("role") == str(GameFlow.NETWORK_CABIN_BERTH_ROLE) \
		and int(claim.get("claim_sequence", 0)) > int(previous.get("claim_sequence", 0)) \
		and int(claim.get("ship_generation", 0)) == int(previous.get("ship_generation", 0)) \
		and int(claim.get("frame_generation", 0)) == int(previous.get("frame_generation", 0)) \
		and int(claim.get("seat_generation", 0)) > 0 \
		and publication.get("occupant") == body and int(publication.get("owner_peer_id", 0)) == peer \
		and int(wire.get("entity_generation", 0)) == current_entity and wire.get("entity_id") == avatar \
		and wire.get("parent_frame_id") == StringName("frame_%s" % _craft.ship_id) \
		and int(wire.get("parent_frame_generation", 0)) == int(claim.get("frame_generation", -1)) \
		and int(wire.get("occupancy_state", -1)) == (NetworkMovingInteriorRelationship.STATE_SEATED if seated else NetworkMovingInteriorRelationship.STATE_WALKING) \
		and int(movement.get("entity_generation", 0)) == current_entity and int(movement.get("owner_peer_id", 0)) == peer \
		and int(movement.get("stream_id", -1)) == int(admitted_source.get("stream_id", -2)) \
		and int(movement.get("stream_id", -1)) > int(retired_source.get("stream_id", -1))


func _host_reboard_seated_current() -> bool:
	if not _host_reboard_body_current(true):
		return false
	var peer := int(_flight_start.passenger_peer)
	var avatar := GameFlow.network_client_boarding_avatar_id(peer)
	var simulation := _game.get_network_remote_body_simulation()
	var body := simulation.get_body(avatar) as PlayerController
	var seat := simulation.get_body_crew_seat(avatar)
	var owner: CrewSeatRoleAuthority = _craft.get_crew_role_authority()
	if owner == null or seat == null:
		return false
	var assignment := owner.get_assignment(peer, avatar)
	var count := 0
	for row: Dictionary in owner.get_snapshot().get("assignments", []):
		if int(row.get("occupant_peer_id", 0)) == peer or row.get("avatar_id") == avatar \
			or row.get("seat_id") == JovianLightFreighter.COPILOT_SEAT_ID:
			count += 1
	return count == 1 and body.is_seated_at((_craft as JovianLightFreighter).get_copilot_seat_anchor()) \
		and _body_follows_anchor(body, (_craft as JovianLightFreighter).get_copilot_seat_anchor(), true) \
		and seat.get_ship() == _craft and seat.get_seat_id() == JovianLightFreighter.COPILOT_SEAT_ID \
		and assignment.get("role") == &"passenger" and assignment.get("avatar_id") == avatar \
		and assignment.get("seat_id") == JovianLightFreighter.COPILOT_SEAT_ID \
		and int(assignment.get("seat_generation", 0)) > 0 \
		and int(assignment.get("claim_sequence", 0)) > int(_reboard_released.assignment.get("claim_sequence", 0)) \
		and (_reboard_seated.is_empty() or (int(assignment.get("seat_generation", 0)) == int(_reboard_seated.assignment.seat_generation)
			and int(assignment.get("claim_sequence", 0)) == int(_reboard_seated.assignment.claim_sequence)))


func _reboard_cabin_identity_current() -> bool:
	if _reboard_cabin.is_empty():
		return false
	var expected: int = int(_reboard_cabin.body_record.entity_generation)
	if _role == "host":
		var avatar := GameFlow.network_client_boarding_avatar_id(int(_flight_start.passenger_peer))
		var simulation := _game.get_network_remote_body_simulation()
		var body := simulation.get_body(avatar) as PlayerController
		return body != null and str(body.get_instance_id()) == str(_reboard_cabin.body.instance_id) \
			and int(simulation.get_body_record(avatar).get("entity_generation", 0)) == expected \
			and _postdock_occupancies() == _reboard_cabin.occupancies \
			and int(_game.network_session.get_movement_avatar_snapshot(avatar).get("stream_id", -1)) == int(_reboard_cabin.movement.stream_id)
	var source := _game.get_network_remote_body_intent_source()
	var claim := _game.get("_network_client_boarding_claim") as Dictionary
	var held := (_reboard_cabin.occupancies as Array)[0] as Dictionary
	var result: Dictionary = _game.network_session.get_boarding_intent_result_replica()
	return _player.get_instance_id() == _initial_player_id and source != null and source.is_bound() \
		and source.get_entity_id() == GameFlow.network_client_boarding_avatar_id(_initial_peer_id) \
		and source.get_entity_generation() == expected and int(source.get_audit().get("stream_id", -1)) == int(_reboard_cabin.movement.stream_id) \
		and claim.get("ship_id") == _craft.ship_id and claim.get("seat_id") == StringName(held.get("seat_id", "")) \
		and claim.get("role") == StringName(held.get("role", "")) \
		and bool(result.get("accepted", false)) and result.get("role") == claim.get("role") \
		and result.get("action") == &"board_any" and result.get("status") == &"boarded" \
		and result.get("seat_id") == claim.get("seat_id") \
		and int(result.get("sequence", -1)) == int(held.get("claim_sequence", 0))


func _local_reboard_cabin_current() -> bool:
	var source := _game.get_network_remote_body_intent_source()
	var claim := _game.get("_network_client_boarding_claim") as Dictionary
	var result: Dictionary = _game.network_session.get_boarding_intent_result_replica()
	var relationship := _game.network_session.get_moving_interior_latest_relationship(
		GameFlow.network_client_boarding_avatar_id(_initial_peer_id))
	return _same_identity() and _player.get_instance_id() == _initial_player_id and _supported_cabin() \
		and not _player.is_seated() and _player.get_cabin_containment_report().get("frame") == _craft \
		and claim.get("ship_id") == _craft.ship_id and claim.get("role") == GameFlow.NETWORK_CABIN_BERTH_ROLE \
		and bool(result.get("accepted", false)) and result.get("seat_id") == claim.get("seat_id") \
		and result.get("action") == &"board_any" and result.get("status") == &"boarded" \
		and result.get("role") == GameFlow.NETWORK_CABIN_BERTH_ROLE \
		and result.get("ship_id") == _craft.ship_id and result.get("avatar_id") == GameFlow.network_client_boarding_avatar_id(_initial_peer_id) \
		and int(result.get("sequence", 0)) > int(_postdock_start.boarding.get("sequence", 0)) \
		and source != null and source.get_entity_id() == GameFlow.network_client_boarding_avatar_id(_initial_peer_id) \
		and source.get_entity_generation() > 0 \
		and int(source.get_audit().get("stream_id", -1)) > int(_postdock_start.body_source.get("stream_id", -1)) \
		and int(relationship.get("entity_generation", 0)) == source.get_entity_generation() \
		and relationship.get("parent_frame_id") == StringName("frame_%s" % _craft.ship_id) \
		and int(relationship.get("parent_frame_generation", 0)) == int(_postdock_start.relationship.parent_frame_generation) \
		and int(relationship.get("occupancy_state", -1)) == NetworkMovingInteriorRelationship.STATE_WALKING


func _reboard_relationship_matches(expected: Dictionary, seated: bool) -> bool:
	if expected.is_empty():
		return false
	var avatar := GameFlow.network_client_boarding_avatar_id(int(_flight_start.passenger_peer))
	var relationship := _game.network_session.get_moving_interior_latest_relationship(avatar)
	var wire := expected.get("wire", {}) as Dictionary
	var pose := relationship.get("frame_local_transform", Transform3D.IDENTITY) as Transform3D
	return relationship.get("entity_id") == avatar \
		and int(relationship.get("entity_generation", 0)) == int(wire.get("entity_generation", -1)) \
		and relationship.get("parent_frame_id") == StringName(wire.get("parent_frame_id", "")) \
		and int(relationship.get("parent_frame_generation", 0)) == int(wire.get("parent_frame_generation", -1)) \
		and int(relationship.get("server_tick", 0)) >= int(wire.get("server_tick", 0)) \
		and int(relationship.get("occupancy_state", -1)) == (NetworkMovingInteriorRelationship.STATE_SEATED if seated else NetworkMovingInteriorRelationship.STATE_WALKING) \
		and (not seated or _craft.to_global(pose.origin).distance_to(
			(_craft as JovianLightFreighter).get_copilot_seat_anchor().global_position) <= 0.05)


func _local_reboard_seated_current(expected: Dictionary) -> bool:
	if expected.is_empty():
		return false
	var source := _game.get_network_remote_body_intent_source()
	var view := _game.network_session.get_passenger_replica_snapshot()
	var assignment := view.get("assignment", {}) as Dictionary
	var wanted := expected.get("assignment", {}) as Dictionary
	var held := (expected.get("occupancies", []) as Array)[0] as Dictionary
	var claim := _game.get("_network_client_boarding_claim") as Dictionary
	return _same_identity() and _player.get_instance_id() == _initial_player_id and _local_passenger_is_current() \
		and _body_follows_anchor(_player, (_craft as JovianLightFreighter).get_copilot_seat_anchor(), true) \
		and _reboard_relationship_matches(expected, true) and source != null and source.is_bound() \
		and source.get_entity_generation() == int(expected.body_record.entity_generation) \
		and int(source.get_audit().get("stream_id", -1)) == int(expected.movement.stream_id) \
		and int(view.get("entity_generation", 0)) == source.get_entity_generation() \
		and claim.get("seat_id") == StringName(held.get("seat_id", "")) and claim.get("role") == StringName(held.get("role", "")) \
		and assignment.get("avatar_id") == GameFlow.network_client_boarding_avatar_id(_initial_peer_id) \
		and int(assignment.get("occupant_peer_id", 0)) == _initial_peer_id \
		and assignment.get("vessel_id") == _craft.ship_id \
		and int(assignment.get("seat_generation", 0)) == int(wanted.get("seat_generation", -1)) \
		and int(assignment.get("claim_sequence", 0)) == int(wanted.get("claim_sequence", -1))


func _reboard_receipt() -> Dictionary:
	var receipt := _postdock_receipt()
	receipt["reboard_selected"] = _reboard_selected
	var avatar := GameFlow.network_client_boarding_avatar_id(int(_flight_start.passenger_peer))
	if _role == "host":
		receipt["movement"] = _primitive_fields(_game.network_session.get_movement_avatar_snapshot(avatar),
			["entity_generation", "owner_peer_id", "mode", "stream_id", "last_sequence"])
		receipt["assignment"] = _primitive_fields(_craft.get_crew_role_authority().get_assignment(
			int(_flight_start.passenger_peer), avatar),
			["occupant_peer_id", "avatar_id", "vessel_id", "role", "seat_id", "seat_generation", "claim_sequence", "frame_id"])
	else:
		receipt["passenger_relationship"] = _primitive_fields(_game.network_session.get_moving_interior_latest_relationship(avatar),
			["entity_id", "entity_generation", "parent_frame_id", "parent_frame_generation", "occupancy_state", "server_tick"])
		receipt["boarding_answer"] = _game.network_session.get_boarding_intent_result_replica()
		receipt["assignment"] = _primitive_fields((_game.network_session.get_passenger_replica_snapshot().get("assignment", {}) as Dictionary),
			["occupant_peer_id", "avatar_id", "vessel_id", "role", "seat_id", "seat_generation", "claim_sequence", "frame_id"])
	return receipt


func _postdock_hatch_approach() -> Vector3:
	return _craft.to_global(Vector3(-1.75, 0.52, -6.30))


func _postdock_ground_exit() -> Vector3:
	var route := _craft.get_exterior_exit_waypoints()
	return (route.back() as Transform3D).origin if not route.is_empty() else Vector3.INF


func _postdock_ground_distance() -> float:
	return ((_player.global_position - _game.world.global_position) - _postdock_ground_start).slide(Vector3.UP).length()


## Selected only after the entire accepted passenger exit/reboard journey.
## A landed pilot's ordinary E confirms disembark directly, then production
## stands the original Player along the full authored hatch/airstair route.
func _host_postdock_pilot_exit() -> bool:
	_return_stage = "host.pilot_exit_ready"
	if not await _postdock_wait(func(): return _flight_files_ready(".pilot_exit_ready"), 8.0,
		"both actual clients finish the full accepted passenger reboard before pilot exit"):
		return false
	_pilot_exit_start = {"hull_position": _vector_values(_station_position()),
		"pilot_seat": _flight_manifest.client.seat.duplicate(true),
		"passenger": _reboard_seated.duplicate(true)}
	_pilot_exit_active = true
	_write("host.pilot_exit_go", _pilot_exit_receipt())
	if not await _postdock_wait(func(): return _flight_files_ready(".pilot_exit_armed"), 8.0,
		"both actual client observers arm the selected final invariants before pilot authority can retire"):
		return false
	_pilot_exit_deadline = Time.get_ticks_msec() + 10000
	_write("host.pilot_exit_input_go", {})
	_return_stage = "host.pilot_exit_retirement"
	if not await _postdock_wait(func(): return _flight_file_exists("client.pilot_exit_input") and _host_pilot_exit_retired(), 8.0,
		"ordinary original-pilot Interact retires exact pilot seat, source, ownership, command queue and publication within8s"):
		return false
	_pilot_exit_retired = true
	_write("host.pilot_exit_retired", _pilot_exit_receipt())
	_return_stage = "host.pilot_exit_ground"
	if not await _postdock_wait(func(): return _flight_file_exists("client.pilot_exit_ground"),
		maxf(0.0, float(_pilot_exit_deadline - Time.get_ticks_msec()) / 1000.0),
		"original pilot physically traverses every authored hatch waypoint and reaches supported berth ground within10s"):
		return false
	var ground := _read("client.pilot_exit_ground")
	if not _require(bool(ground.get("ground_current", false))
		and bool(ground.get("route_observed", false)) and bool(ground.get("motion_observed", false))
		and float(ground.get("exit_distance_m", INF)) <= 0.8,
		"pilot ground receipt proves continuous authored exit rather than a station-spawn relocation"):
		return false
	_write("host.pilot_exit_ground_checked", _pilot_exit_receipt())
	_return_stage = "host.pilot_exit_ground_walk"
	if not await _postdock_wait(func(): return _flight_file_exists("client.pilot_exit_ground_walk"), 15.0,
		"released pilot uses ordinary movement on freight-berth ground while retired helm cannot move the hull"):
		return false
	var walked := _read("client.pilot_exit_ground_walk")
	if not _require(bool(walked.get("ground_current", false)) and float(walked.get("ground_distance_m", 0.0)) >= 1.0
		and bool(walked.get("helm_quiet", false)) and _host_pilot_exit_retired(),
		"same original pilot walks at least1m with no surviving pilot command producer or authority"):
		return false
	_write("host.pilot_exit_walk_checked", _pilot_exit_receipt())
	_return_stage = "host.pilot_exit_convergence"
	if not await _postdock_wait(func(): return _flight_files_ready(".pilot_exit_converged"), 5.0,
		"both original clients consume retired pilot ownership and retain exact passenger chair and landed generation within5s"):
		return false
	_pilot_exit_complete = true
	_write("host.pilot_exit_complete", _pilot_exit_receipt())
	if not _require(_pilot_exit_invariants(), "final original pilot is released, original passenger stays seated and same occupied home lease remains strict"):
		return false
	if _pilot_reclaim_selected:
		return await _host_postdock_pilot_reclaim()
	return true


func _client_postdock_pilot_exit() -> bool:
	_return_stage = _role + ".pilot_exit_ready"
	if not _require(_reboard_complete and _flight_file_exists("host.reboard_complete"),
		"pilot exit begins only after the complete original passenger reboard result"):
		return false
	_write(_role + ".pilot_exit_ready", {})
	if not await _postdock_wait(func(): return _flight_file_exists("host.pilot_exit_go"), 8.0,
		"host retains full accepted prefix until both actual clients finish passenger reboard"):
		return false
	_pilot_exit_start = _read("host.pilot_exit_go").get("start", {}) as Dictionary
	_pilot_exit_active = true
	_write(_role + ".pilot_exit_armed", {})
	if not await _postdock_wait(func(): return _flight_file_exists("host.pilot_exit_input_go"), 8.0,
		"host confirms both client observers switched phase before allowing original pilot Interact"):
		return false
	_pilot_exit_deadline = Time.get_ticks_msec() + 10000
	_return_stage = _role + ".pilot_exit_retirement"
	if _role == "client":
		_write("client.pilot_exit_input", _pilot_exit_receipt())
		await _press(&"interact")
	if not await _postdock_wait(func(): return _flight_file_exists("host.pilot_exit_retired"), 8.0,
		"host independently observes actual original-pilot authority retirement after ordinary Interact"):
		return false
	if not await _postdock_wait(_client_pilot_exit_retired, 5.0,
		"actual client consumes unowned same hull and withdrawn original-pilot moving-interior publication within5s"):
		return false
	_pilot_exit_retired = true
	_return_stage = _role + ".pilot_exit_ground"
	if _role == "client":
		if not await _postdock_wait(_local_pilot_exit_ground_current,
			maxf(0.0, float(_pilot_exit_deadline - Time.get_ticks_msec()) / 1000.0),
			"ordinary landed pilot exit reaches supported authored berth endpoint within10s"):
			return false
		if not _require(_pilot_exit_route_observed and _pilot_exit_motion_observed
			and _player.global_position.distance_to(_postdock_ground_exit()) <= 0.8,
			"same pilot Player stands and continuously traverses all production hatch/airstair waypoints before ground walking"):
			return false
		_pilot_exit_grounded = true
		_pilot_exit_ground_start = _player.global_position - _game.world.global_position
		_pilot_exit_helm_sent = int(_game.get("_network_remote_helm_sent"))
		_write("client.pilot_exit_ground", _pilot_exit_receipt())
	if not await _postdock_wait(func(): return _flight_file_exists("host.pilot_exit_ground_checked"),
		maxf(0.0, float(_pilot_exit_deadline - Time.get_ticks_msec()) / 1000.0),
		"host accepts actual authored pilot exit while passenger retains its exact co-pilot assignment"):
		return false
	_return_stage = _role + ".pilot_exit_ground_walk"
	if _role == "client":
		var clear := _postdock_ground_exit() - _craft.global_basis.x.normalized() * 1.5
		if not await _walk_to(clear, false):
			return false
		if not _require(_local_pilot_exit_ground_current() and _pilot_exit_ground_distance() >= 1.0
			and int(_game.get("_network_remote_helm_sent")) == _pilot_exit_helm_sent,
			"original pilot's ordinary forward/strafe inputs move only its supported ground body at least1m"):
			return false
		_write("client.pilot_exit_ground_walk", _pilot_exit_receipt())
	if not await _postdock_wait(func(): return _flight_file_exists("host.pilot_exit_walk_checked"), 15.0,
		"host observes stable hull and retained occupied home lease throughout released-pilot ground input"):
		return false
	_return_stage = _role + ".pilot_exit_convergence"
	if not _require(_pilot_exit_invariants() and _client_pilot_exit_retired(),
		"actual client retains released pilot authority, exact passenger chair and committed home arrival"):
		return false
	_write(_role + ".pilot_exit_converged", _pilot_exit_receipt())
	if not await _postdock_wait(func(): return _flight_file_exists("host.pilot_exit_complete"), 8.0,
		"host accepts both actual client final pilot-exit confirmations"):
		return false
	_pilot_exit_complete = true
	return _require(_pilot_exit_invariants(), "original actors retain selected final ground/chair roles through inherited release handshake")


## The exterior hatch actually admits a cabin berth on this hull. Capture and
## consume that real body before using ordinary cabin input to claim the helm.
func _host_postdock_pilot_reclaim() -> bool:
	_return_stage = "host.pilot_reclaim_ready"
	if not await _postdock_wait(func(): return _flight_files_ready(".pilot_reclaim_ready"), 8.0,
		"both original clients finish accepted pilot exit and ground walk before reclaim"):
		return false
	_pilot_reclaim_retired = _read("client.pilot_reclaim_ready")
	_pilot_reclaim_active = true
	_write("host.pilot_reclaim_go", _pilot_reclaim_receipt())
	if not await _postdock_wait(func(): return _flight_files_ready(".pilot_reclaim_armed"), 8.0,
		"both actual clients arm reclaim invariants before any new pilot claim"):
		return false
	_write("host.pilot_reclaim_input_go", {})
	_return_stage = "host.pilot_reclaim_clearance"
	if not await _postdock_wait(func(): return _flight_file_exists("client.pilot_reclaim_clear"), 15.0,
		"same exterior pilot clears the existing lockout through the accepted supported apron corridor"):
		return false
	if not _require(_host_pilot_exit_retired(), "ordinary exterior clearance leaves old pilot authority fully retired"):
		return false
	_write("host.pilot_reclaim_clear_checked", _pilot_reclaim_receipt())
	_return_stage = "host.pilot_reclaim_hatch"
	if not await _postdock_wait(func(): return _flight_file_exists("client.pilot_reclaim_hatch_approached"), 15.0,
		"same supported original pilot walks back to the authored exterior hatch"):
		return false
	if not await _postdock_wait(func(): return _flight_file_exists("client.pilot_reclaim_hatch"), 8.0,
		"ordinary look discovers the actual hatch before pilot re-entry"):
		return false
	_return_stage = "host.pilot_reclaim_cabin"
	if not await _postdock_wait(func(): return _flight_file_exists("client.pilot_reclaim_cabin")
		and _host_pilot_reclaim_cabin_current(), 8.0,
		"ordinary hatch input admits one current supported pilot-owned cabin body and a fresh claim"):
		return false
	_pilot_reclaim_cabin = _pilot_reclaim_receipt()
	_write("host.pilot_reclaim_cabin_checked", _pilot_reclaim_cabin)
	if not await _postdock_wait(func(): return _flight_file_exists("client.pilot_reclaim_cabin_consumed"), 5.0,
		"original pilot consumes independently confirmed body and frame before using cabin walking identity"):
		return false
	_return_stage = "host.pilot_reclaim_chair"
	if not await _postdock_wait(func(): return _flight_file_exists("client.pilot_reclaim_chair_approached"), 15.0,
		"ordinary supported cabin walk reaches the actual pilot-seat approach"):
		return false
	if not await _postdock_wait(func(): return _flight_file_exists("client.pilot_reclaim_chair"), 8.0,
		"ordinary pilot aim discovers the real cockpit boarding interaction"):
		return false
	if not await _postdock_wait(_host_pilot_reclaim_seated_current, 8.0,
		"ordinary cockpit Interact establishes a fresh pilot claim, ownership and source with a delivered higher wire epoch"):
		return false
	_pilot_reclaim_seated = _pilot_reclaim_receipt()
	_write("host.pilot_reclaim_seated", _pilot_reclaim_seated)
	_return_stage = "host.pilot_reclaim_convergence"
	if not await _postdock_wait(func(): return _flight_files_ready(".pilot_reclaim_converged"), 5.0,
		"both original clients consume the exact current pilot claim, frame and ownership while passenger stays seated"):
		return false
	_game.network_session.movement_intent_result.connect(_on_pilot_reclaim_probe_result)
	_write("host.pilot_reclaim_probe_go", {})
	_return_stage = "host.pilot_reclaim_retired_stream_probe"
	var refused := await _postdock_wait(func(): return _flight_file_exists("client.pilot_reclaim_probe_sent")
		and not _pilot_reclaim_probe_results.is_empty(), 8.0,
		"actual authenticated admission answers the single reconstructed retired-stream negative probe")
	_game.network_session.movement_intent_result.disconnect(_on_pilot_reclaim_probe_result)
	if not refused:
		return false
	if not _require(_pilot_reclaim_probe_results.size() == 1
		and _pilot_reclaim_probe_results[0].get("status") == &"stale_stream"
		and _host_pilot_reclaim_seated_current(),
		"one actual stale_stream refusal preserves the exact new pilot source, ownership, passenger and occupied home lease"):
		return false
	_write("host.pilot_reclaim_probe_checked", _pilot_reclaim_receipt())
	_pilot_reclaim_complete = true
	_write("host.pilot_reclaim_complete", _pilot_reclaim_receipt())
	return _require(_pilot_reclaim_invariants() and _host_pilot_reclaim_seated_current(),
		"same pilot reclaims current helm without departing the occupied home berth or changing the passenger")


func _client_postdock_pilot_reclaim() -> bool:
	_return_stage = _role + ".pilot_reclaim_ready"
	if not _require(_pilot_exit_complete and _flight_file_exists("host.pilot_exit_complete"),
		"full accepted original pilot exit and ground walk precedes reclaim"):
		return false
	if _role == "client":
		var source := _craft.get("_default_local_command_source") as ShipCommandSource
		var body_source := _game.get_network_remote_body_intent_source()
		_pilot_reclaim_retired = {"helm_epoch": int(_game.get("_network_remote_helm_stream_epoch")),
			"producer": _node_identity(source), "producer_stream": source.get_stream_id() if source != null else -1,
			"producer_delivery": source.get_delivery_generation() if source != null else -1,
			"body_stream": int(body_source.get_audit().get("stream_id", -1)) if body_source != null else -1,
			"exit_answer": _game.network_session.get_boarding_intent_result_replica(),
			"ownership": _client_ownership_record()}
		if not _require(source != null and source == _flight_source and int(_pilot_reclaim_retired.helm_epoch) >= 0
			and _pilot_reclaim_ground_current() and _client_pilot_exit_retired(),
			"immutable retired producer and actual old wire epoch are captured from the accepted released pilot"):
			return false
	_write(_role + ".pilot_reclaim_ready", _pilot_reclaim_retired)
	if not await _postdock_wait(func(): return _flight_file_exists("host.pilot_reclaim_go"), 8.0,
		"host retains accepted exit invariants until both actual clients finish its ground endpoint"):
		return false
	_pilot_reclaim_retired = _read("host.pilot_reclaim_go").get("retired", {}) as Dictionary
	_pilot_reclaim_active = true
	_write(_role + ".pilot_reclaim_armed", {})
	if not await _postdock_wait(func(): return _flight_file_exists("host.pilot_reclaim_input_go"), 8.0,
		"both client observers switch to reclaim roles before original pilot moves or claims"):
		return false
	if _role == "client":
		if not await _client_pilot_reclaim_route():
			return false
	else:
		for stage: Array in [["client.pilot_reclaim_clear", 15.0], ["host.pilot_reclaim_clear_checked", 8.0],
			["client.pilot_reclaim_hatch_approached", 15.0], ["client.pilot_reclaim_hatch", 8.0],
			["host.pilot_reclaim_cabin_checked", 8.0], ["client.pilot_reclaim_cabin_consumed", 5.0],
			["client.pilot_reclaim_chair_approached", 15.0], ["client.pilot_reclaim_chair", 8.0]]:
			_return_stage = "client_b.pilot_reclaim." + str(stage[0])
			if not await _postdock_wait(func(): return _flight_file_exists(str(stage[0])), float(stage[1]),
				"same passenger keeps its exact chair throughout " + str(stage[0])):
				return false
	if not await _postdock_wait(func(): return _flight_file_exists("host.pilot_reclaim_seated"), 8.0,
		"host confirms the newly reclaimed current pilot authority"):
		return false
	_pilot_reclaim_seated = _read("host.pilot_reclaim_seated")
	_return_stage = _role + ".pilot_reclaim_convergence"
	if not await _postdock_wait(_client_pilot_reclaim_consumed, 5.0,
		"actual client consumes the exact current pilot/ownership/frame identities and fresh pose within5s"):
		return false
	if _role == "client":
		_pilot_reclaim_producer = _pilot_reclaim_local_producer()
	_pilot_reclaim_consumed_ready = true
	_write(_role + ".pilot_reclaim_converged", _pilot_reclaim_receipt())
	if not await _postdock_wait(func(): return _flight_file_exists("host.pilot_reclaim_probe_go"), 8.0,
		"host establishes both actual new-role confirmations before the retired-stream negative probe"):
		return false
	if _role == "client":
		# Explicit reconstructed negative probe, not a captured historical wire.
		# The complete positive journey above uses only ordinary player input.
		var movement := _pilot_reclaim_seated.get("pilot_movement", {}) as Dictionary
		var current_helm := _game.get("_network_remote_helm") as Dictionary
		var probe_tick: int = int(current_helm.get("last_stamp", -1))
		if not _require(probe_tick >= 0, "retired-stream probe uses the current ordinary helm's actual emitted clock stamp"):
			return false
		var wire := NetworkRemotePilotCommandSource.build_helm_intent(_initial_peer_id, _craft.ship_id,
			int(movement.get("entity_generation", 0)), 0,
			probe_tick, null, int(_pilot_reclaim_retired.helm_epoch))
		var sent := _game.network_session.send_movement_intent(wire)
		if not _require(bool(sent.get("accepted", false)), "single reconstructed retired-stream probe enters real authenticated transport"):
			return false
		_write("client.pilot_reclaim_probe_sent", {"reconstructed_stale_stream_probe": true, "wire": wire, "sent": sent})
	if not await _postdock_wait(func(): return _flight_file_exists("host.pilot_reclaim_probe_checked"), 8.0,
		"host observes actual retired-stream refusal without changing any current pilot or passenger authority"):
		return false
	if not await _postdock_wait(func(): return _flight_file_exists("host.pilot_reclaim_complete"), 8.0,
		"host confirms both actual client reclaimed-pilot results before final handshake"):
		return false
	_pilot_reclaim_complete = true
	return _require(_pilot_reclaim_invariants() and _client_pilot_reclaim_consumed(),
		"same original pilot and passenger retain their correct current seated roles at the unchanged home berth")


func _client_pilot_reclaim_route() -> bool:
	_return_stage = "client.pilot_reclaim_clearance"
	var corridor := Vector3(-42.0, 0.38, _craft.get_boarding_position().z)
	var clear := corridor - Vector3(0.0, 0.0, GameFlow.BOARDING_FALLBACK_REACH + 1.5)
	if not await _walk_to(corridor, false) or not await _walk_to(clear, false):
		return false
	if not _require(_pilot_reclaim_ground_current() and _game.get("_reboard_blocked_ship") != _craft
		and _player.get_interaction_origin().distance_to(_craft.get_boarding_position()) > GameFlow.BOARDING_FALLBACK_REACH,
		"same original pilot clears7m suppression on the accepted supported apron with old claims retired"):
		return false
	_write("client.pilot_reclaim_clear", _pilot_reclaim_receipt())
	if not await _postdock_wait(func(): return _flight_file_exists("host.pilot_reclaim_clear_checked"), 8.0,
		"host confirms old pilot authority remains retired at exterior clearance"):
		return false
	_return_stage = "client.pilot_reclaim_hatch"
	if not await _walk_to(corridor, false) or not await _walk_to(_craft.get_boarding_position(), false):
		return false
	_write("client.pilot_reclaim_hatch_approached", _pilot_reclaim_receipt())
	await _look(_craft.get_boarding_position() + Vector3.UP * 1.2)
	if not await _postdock_wait(func(): return _game.boarding_candidate == _craft
		and not is_instance_valid(_game.station_interaction_candidate), 8.0,
		"ordinary exterior aim discovers the same authored hatch"):
		return false
	_write("client.pilot_reclaim_hatch", _pilot_reclaim_receipt())
	await _press(&"interact")
	if not await _postdock_wait(_local_pilot_reclaim_cabin_current, 8.0,
		"ordinary hatch Interact consumes actual new cabin claim and supported original Player"):
		return false
	_write("client.pilot_reclaim_cabin", _pilot_reclaim_receipt())
	if not await _postdock_wait(func(): return _flight_file_exists("host.pilot_reclaim_cabin_checked"), 8.0,
		"host independently observes actual pilot-owned walking body and current generation"):
		return false
	_pilot_reclaim_cabin = _read("host.pilot_reclaim_cabin_checked")
	if not await _postdock_wait(func(): return _local_pilot_reclaim_cabin_current()
		and _pilot_reclaim_relationship_matches(_pilot_reclaim_cabin, false), 5.0,
		"pilot consumes exact host-confirmed walking frame before advancing expected walking identity"):
		return false
	var source := _game.get_network_remote_body_intent_source()
	_walking_identity = {"peer_id": _initial_peer_id, "entity_id": str(source.get_entity_id()),
		"entity_generation": source.get_entity_generation(), "player_id": str(_initial_player_id)}
	_write("client.pilot_reclaim_cabin_consumed", _pilot_reclaim_receipt())
	_return_stage = "client.pilot_reclaim_chair"
	if not await _walk_to((_craft as JovianLightFreighter).get_cabin_stand_transform().origin, true):
		return false
	_write("client.pilot_reclaim_chair_approached", _pilot_reclaim_receipt())
	await _look(_craft.get_pilot_seat_anchor().global_position + _craft.global_basis.y.normalized() * 1.2)
	if not await _postdock_wait(func(): return _game.boarding_candidate == _craft
		and not is_instance_valid(_game.station_interaction_candidate)
		and _game._network_client_near_pilot_seat(_craft), 8.0,
		"ordinary supported cockpit aim discovers the actual pilot-seat swap interaction"):
		return false
	_write("client.pilot_reclaim_chair", _pilot_reclaim_receipt())
	await _press(&"interact")
	return true


func _pilot_reclaim_occupancies() -> Array:
	var result: Array = []
	var peer := int(_flight_start.pilot_peer)
	var avatar := GameFlow.network_client_boarding_avatar_id(peer)
	for held: Dictionary in _game.network_session.get_boarding_snapshot().get("occupancies", []):
		if int(held.get("peer_id", 0)) == peer or held.get("avatar_id") == avatar:
			result.append(_primitive_fields(held, ["peer_id", "avatar_id", "ship_id", "ship_generation",
				"frame_id", "frame_generation", "role", "seat_id", "seat_generation", "claim_sequence"]))
	return result


func _pilot_reclaim_ground_current() -> bool:
	var source := _game.get_network_remote_body_intent_source()
	return _same_identity() and _player.get_instance_id() == _initial_player_id and _player.is_on_floor() \
		and _player.is_control_enabled() and not _player.is_seated() and not _player.is_station_seated() \
		and not bool(_game.get("_transition_busy")) and not bool(_game.get("_piloting")) \
		and not bool(_player.get_cabin_containment_report().get("active", true)) \
		and (_game.get("_network_client_boarding_claim") as Dictionary).is_empty() \
		and (_game.get("_network_client_boarding_request") as Dictionary).is_empty() \
		and (source == null or not source.is_bound())


func _local_pilot_reclaim_cabin_current() -> bool:
	var source := _game.get_network_remote_body_intent_source()
	var claim := _game.get("_network_client_boarding_claim") as Dictionary
	var answer := _game.network_session.get_boarding_intent_result_replica()
	return _same_identity() and _player.get_instance_id() == _initial_player_id and _supported_cabin() \
		and not _player.is_seated() and _player.get_cabin_containment_report().get("frame") == _craft \
		and source != null and source.get_entity_id() == GameFlow.network_client_boarding_avatar_id(_initial_peer_id) \
		and source.get_entity_generation() > 0 and int(source.get_audit().get("stream_id", -1)) > int(_pilot_reclaim_retired.body_stream) \
		and claim.get("ship_id") == _craft.ship_id and claim.get("role") == GameFlow.NETWORK_CABIN_BERTH_ROLE \
		and bool(answer.get("accepted", false)) and answer.get("action") == &"board_any" and answer.get("status") == &"boarded" \
		and answer.get("avatar_id") == source.get_entity_id() and answer.get("ship_id") == _craft.ship_id \
		and answer.get("seat_id") == claim.get("seat_id") \
		and int(answer.get("sequence", 0)) > int((_pilot_reclaim_retired.exit_answer as Dictionary).get("sequence", 0))


func _host_pilot_reclaim_cabin_current() -> bool:
	var peer := int(_flight_start.pilot_peer)
	var avatar := GameFlow.network_client_boarding_avatar_id(peer)
	var simulation := _game.get_network_remote_body_simulation()
	var body := simulation.get_body(avatar) as PlayerController
	var record := simulation.get_body_record(avatar)
	var publication := _publication(avatar)
	var wire := publication.get("wire", {}) as Dictionary
	var movement := _game.network_session.get_movement_avatar_snapshot(avatar)
	var held := _pilot_reclaim_occupancies()
	var source := _read("client.pilot_reclaim_cabin").get("body_source", {}) as Dictionary
	if body == null or held.size() != 1:
		return false
	var claim := held[0] as Dictionary
	var owner: CrewSeatRoleAuthority = _craft.get_crew_role_authority()
	return body.is_on_floor() and not body.is_seated() and body.get_cabin_containment_report().get("frame") == _craft \
		and record.get("seat_state") == &"standing" and int(record.get("entity_generation", 0)) > 0 \
		and int(record.get("owner_peer_id", 0)) == peer and record.get("entity_id") == avatar \
		and owner != null and owner.get_assignment(peer, avatar).is_empty() \
		and claim.get("role") == str(GameFlow.NETWORK_CABIN_BERTH_ROLE) and claim.get("ship_id") == str(_craft.ship_id) \
		and claim.get("avatar_id") == str(avatar) and int(claim.get("peer_id", 0)) == peer \
		and int(claim.get("ship_generation", 0)) == int(_pilot_reclaim_retired.ownership.ship_generation) \
		and int(claim.get("claim_sequence", 0)) > int((_pilot_reclaim_retired.exit_answer as Dictionary).get("sequence", 0)) \
		and publication.get("occupant") == body and wire.get("entity_id") == avatar \
		and int(wire.get("entity_generation", 0)) == int(record.entity_generation) \
		and int(wire.get("occupancy_state", -1)) == NetworkMovingInteriorRelationship.STATE_WALKING \
		and wire.get("parent_frame_id") == StringName("frame_%s" % _craft.ship_id) \
		and int(movement.get("owner_peer_id", 0)) == peer and int(movement.get("entity_generation", 0)) == int(record.entity_generation) \
		and int(movement.get("stream_id", -1)) == int(source.get("stream_id", -2)) \
		and int(movement.get("stream_id", -1)) > int(_pilot_reclaim_retired.body_stream)


func _pilot_reclaim_registry() -> Dictionary:
	var pilots: Array = _game.network_session.get_remote_ship_command_snapshot().get("pilots", [])
	return pilots[0] as Dictionary if pilots.size() == 1 else {}


func _host_pilot_reclaim_seated_current() -> bool:
	if _pilot_reclaim_cabin.is_empty():
		return false
	var peer := int(_flight_start.pilot_peer)
	var avatar := GameFlow.network_client_boarding_avatar_id(peer)
	var remote := (_game.get("_network_remote_pilots") as Dictionary).get(_craft.ship_id, {}) as Dictionary
	var source := remote.get("source") as NetworkRemotePilotCommandSource
	var held := _pilot_reclaim_occupancies()
	var publication := _publication(avatar)
	var wire := publication.get("wire", {}) as Dictionary
	var ownership := _game.network_session.get_owned_ship(_craft.ship_id)
	var movement := _pilot_reclaim_registry()
	if source == null or held.size() != 1 or movement.is_empty():
		return false
	var claim := held[0] as Dictionary
	var delivered := source.get_roll_receipt()
	var simulation := _game.get_network_remote_body_simulation()
	var command := _craft.get_last_ship_command()
	var identity := {"instance_id": str(source.get_instance_id()),
		"stream_id": source.get_stream_id(), "delivery_generation": source.get_delivery_generation()}
	return not is_instance_valid(_flight_source) and str(source.get_instance_id()) != str(_postdock_start.source.identity.instance_id) \
		and _craft.get("_command_source") == source and source.is_enabled_owner() \
		and source.get_pilot_peer_id() == peer and source.get_ship_id() == _craft.ship_id \
		and int(remote.get("peer_id", 0)) == peer and _craft.is_remote_piloted() \
		and int(ownership.get("owner_peer_id", 0)) == peer \
		and int(ownership.get("ship_generation", 0)) == int(_pilot_reclaim_retired.ownership.ship_generation) \
		and int(ownership.get("ownership_generation", 0)) > int(_pilot_reclaim_retired.ownership.ownership_generation) \
		and claim.get("role") == "pilot" and claim.get("avatar_id") == str(avatar) \
		and int(claim.get("peer_id", 0)) == peer and claim.get("ship_id") == str(_craft.ship_id) \
		and int(claim.get("ship_generation", 0)) == int(ownership.get("ship_generation", -1)) \
		and claim.get("frame_id") == str(StringName("frame_%s" % _craft.ship_id)) \
		and int(claim.get("frame_generation", 0)) > 0 \
		and claim.get("seat_id") == str(StringName("%s_pilot" % _craft.ship_id)) \
		and int(claim.get("seat_generation", 0)) > 0 \
		and int(claim.get("claim_sequence", 0)) > int(_pilot_reclaim_cabin.pilot_occupancies[0].claim_sequence) \
		and publication.get("occupant") == _craft.get_pilot_seat_anchor() \
		and bool(publication.get("seated", false)) and int(publication.get("remote_pilot_peer_id", 0)) == peer \
		and int(publication.get("owner_peer_id", 0)) == peer and int(wire.get("entity_generation", 0)) > 0 \
		and wire.get("entity_id") == avatar and wire.get("parent_frame_id") == StringName("frame_%s" % _craft.ship_id) \
		and int(wire.get("parent_frame_generation", 0)) == int(claim.get("frame_generation", -1)) \
		and int(wire.get("occupancy_state", -1)) == NetworkMovingInteriorRelationship.STATE_SEATED \
		and int(movement.get("owner_peer_id", 0)) == peer and int(movement.get("entity_generation", 0)) > 0 \
		and int(movement.get("stream_id", -1)) > int(_pilot_reclaim_retired.helm_epoch) \
		and int(delivered.get("stream", -1)) == int(movement.get("stream_id", -2)) \
		and int(delivered.get("sequence", -1)) >= 0 \
		and int(movement.get("last_sequence", -1)) >= int(delivered.get("sequence", 0)) \
		and int(source.get_audit().get("delivered", 0)) > 0 \
		and simulation.get_body(avatar) == null and simulation.get_body_record(avatar).is_empty() \
		and _game.network_session.get_movement_avatar_snapshot(avatar).is_empty() \
		and command != null and is_zero_approx(command.throttle) and not command.boost and not command.landing \
		and (_pilot_reclaim_seated.is_empty() or (identity == _pilot_reclaim_seated.remote_source
			and held == _pilot_reclaim_seated.pilot_occupancies and ownership == _pilot_reclaim_seated.ownership
			and int(wire.entity_generation) == int(_pilot_reclaim_seated.pilot_wire.entity_generation)
			and int(movement.stream_id) == int(_pilot_reclaim_seated.pilot_movement.stream_id)))


func _pilot_reclaim_relationship_matches(expected: Dictionary, seated: bool) -> bool:
	var avatar := GameFlow.network_client_boarding_avatar_id(int(_flight_start.pilot_peer))
	var wire := expected.get("pilot_wire", {}) as Dictionary
	var current := _game.network_session.get_moving_interior_latest_relationship(avatar)
	var pose := current.get("frame_local_transform", Transform3D.IDENTITY) as Transform3D
	return not wire.is_empty() and current.get("entity_id") == avatar \
		and int(current.get("entity_generation", 0)) == int(wire.get("entity_generation", -1)) \
		and current.get("parent_frame_id") == StringName(wire.get("parent_frame_id", "")) \
		and int(current.get("parent_frame_generation", 0)) == int(wire.get("parent_frame_generation", -1)) \
		and int(current.get("server_tick", 0)) >= int(wire.get("server_tick", 0)) \
		and int(current.get("occupancy_state", -1)) == (NetworkMovingInteriorRelationship.STATE_SEATED if seated else NetworkMovingInteriorRelationship.STATE_WALKING) \
		and (not seated or _craft.to_global(pose.origin).distance_to(_craft.get_pilot_seat_anchor().global_position) <= 0.05)


func _pilot_reclaim_local_producer() -> Dictionary:
	var source := _craft.get("_default_local_command_source") as ShipCommandSource
	if source == null:
		return {}
	return {"instance_id": str(source.get_instance_id()), "stream_id": source.get_stream_id(),
		"delivery_generation": source.get_delivery_generation(), "authority_peer_id": source.get_authority_peer_id()}


func _client_pilot_reclaim_consumed() -> bool:
	if _pilot_reclaim_seated.is_empty():
		return false
	var expected := _pilot_reclaim_seated.get("ownership", {}) as Dictionary
	var current := _client_ownership_record()
	var sample := _flight_pose_sample()
	var ownership_matches: bool = int(current.get("owner_peer_id", 0)) == int(_flight_start.pilot_peer) \
		and int(current.get("ship_generation", 0)) == int(expected.get("ship_generation", -1)) \
		and int(current.get("ownership_generation", 0)) == int(expected.get("ownership_generation", -1))
	if not ownership_matches or not _pilot_reclaim_relationship_matches(_pilot_reclaim_seated, true) \
		or int(sample.get("pose_tick", 0)) < int(_pilot_reclaim_seated.home.pose_tick) \
		or int(sample.get("pilot_peer_id", 0)) != int(_flight_start.pilot_peer):
		return false
	if _role == "client_b":
		return _local_reboard_seated_current(_reboard_seated)
	var producer := _pilot_reclaim_local_producer()
	var source := _craft.get("_default_local_command_source") as ShipCommandSource
	var helm := _game.get("_network_remote_helm") as Dictionary
	var answer := _game.network_session.get_boarding_intent_result_replica()
	var held: Dictionary = _pilot_reclaim_seated.pilot_occupancies[0]
	var claim := _game.get("_network_client_boarding_claim") as Dictionary
	var body_source := _game.get_network_remote_body_intent_source()
	return _local_pilot_is_current() and _body_follows_anchor(_player, _craft.get_pilot_seat_anchor(), true) \
		and source == _flight_source and _craft.get("_command_source") == source and source.is_enabled_owner() \
		and int(producer.authority_peer_id) == _initial_peer_id \
		and int(producer.stream_id) > int(_pilot_reclaim_retired.producer_stream) \
		and int(producer.delivery_generation) > int(_pilot_reclaim_retired.producer_delivery) \
		and int(helm.get("producer_stream", -1)) == int(producer.stream_id) \
		and int(helm.get("producer_id", 0)) == source.get_instance_id() \
		and int(helm.get("stream_id", -1)) > int(_pilot_reclaim_retired.helm_epoch) \
		and int(helm.get("stream_id", -1)) == int(_pilot_reclaim_seated.pilot_movement.stream_id) \
		and bool(answer.get("accepted", false)) and answer.get("status") == &"seat_swapped" \
		and answer.get("action") == &"swap" and answer.get("role") == &"pilot" \
		and answer.get("ship_id") == _craft.ship_id and answer.get("avatar_id") == GameFlow.network_client_boarding_avatar_id(_initial_peer_id) \
		and answer.get("seat_id") == StringName(held.seat_id) and int(answer.get("sequence", 0)) == int(held.claim_sequence) \
		and claim.get("ship_id") == _craft.ship_id and claim.get("seat_id") == StringName(held.seat_id) and claim.get("role") == &"pilot" \
		and (_game.get("_network_client_boarding_request") as Dictionary).is_empty() \
		and (body_source == null or not body_source.is_bound()) \
		and (_pilot_reclaim_producer.is_empty() or producer == _pilot_reclaim_producer)


func _pilot_reclaim_invariants() -> bool:
	if not _pilot_exit_complete or not _craft.is_inside_tree() or _player.get_instance_id() != _initial_player_id \
		or _station_position().distance_to(_vector_from(_pilot_exit_start.hull_position)) > 0.05 or _craft.velocity.length() > 0.05:
		return false
	if _role == "host":
		return _host_return_docked() and _host_reboard_seated_current() and _reboard_cabin_identity_current() \
			and not is_instance_valid(_flight_source) \
			and _game.phase == GameFlow.Phase.INTRO and not _player.is_seated() and not _player.is_control_enabled() \
			and _peer_generation(int(_flight_start.pilot_peer)) == int(_flight_manifest.client.peer_generation) \
			and _peer_generation(int(_flight_start.passenger_peer)) == int(_flight_manifest.client_b.peer_generation) \
			and (_pilot_reclaim_seated.is_empty() or _host_pilot_reclaim_seated_current())
	var landing := _client_landing_record()
	var operation := _flight_pose_sample().get("operation_presentation", {}) as Dictionary
	var owner := int(_client_ownership_record().get("owner_peer_id", -1))
	var source := _craft.get("_default_local_command_source") as ShipCommandSource
	var active := _craft.get("_command_source") as ShipCommandSource
	return _same_identity() and _walking_identity_is_preserved() \
		and landing.get("state") == &"landed" and int(landing.get("entity_generation", 0)) == _return_generation \
		and bool(operation.get("landed", false)) and bool(operation.get("docked", false)) and not bool(operation.get("landing", true)) \
		and owner in [0, int(_flight_start.pilot_peer)] and _reboard_relationship_matches(_reboard_seated, true) \
		and (_role != "client_b" or (_local_reboard_seated_current(_reboard_seated) and _reboard_cabin_identity_current()
			and (source == null or not source.is_enabled_owner()) and (active == null or not active.is_enabled_owner())
			and _return_controls_neutral())) \
		and (not _pilot_reclaim_consumed_ready or _client_pilot_reclaim_consumed())


func _on_pilot_reclaim_probe_result(result: Dictionary) -> void:
	var remote := (_game.get("_network_remote_pilots") as Dictionary).get(_craft.ship_id, {}) as Dictionary
	var registry := _pilot_reclaim_registry()
	var source := remote.get("source") as NetworkRemotePilotCommandSource
	if _flight_file_exists("host.pilot_reclaim_probe_go") \
		and _game.network_session.multiplayer.get_remote_sender_id() == int(_flight_start.pilot_peer) \
		and not bool(result.get("accepted", false)) and result.get("status") == &"stale_stream" \
		and int(remote.get("peer_id", 0)) == int(_flight_start.pilot_peer) and remote.get("craft") == _craft \
		and source != null and source.get_ship_id() == _craft.ship_id and _craft.get("_command_source") == source \
		and int(registry.get("owner_peer_id", 0)) == int(_flight_start.pilot_peer) \
		and int(registry.get("stream_id", -1)) > int(_pilot_reclaim_retired.helm_epoch) \
		and int(source.get_roll_receipt().get("stream", -2)) == int(registry.get("stream_id", -1)):
		_pilot_reclaim_probe_results.append(result.duplicate(true))


func _pilot_reclaim_receipt() -> Dictionary:
	var peer := int(_flight_start.pilot_peer)
	var avatar := GameFlow.network_client_boarding_avatar_id(peer)
	var receipt := {"selected": _pilot_reclaim_selected, "stage": _return_stage, "role": _role,
		"retired": _pilot_reclaim_retired.duplicate(true), "complete": _pilot_reclaim_complete,
		"hull_position": _vector_values(_station_position()), "hull_speed": _craft.velocity.length(),
		"hull_error_m": _station_position().distance_to(_vector_from(_pilot_exit_start.hull_position)),
		"player": _node_identity(_player), "old_source_alive": is_instance_valid(_flight_source),
		"passenger": _reboard_receipt(), "probe_refusals": _pilot_reclaim_probe_results.duplicate(true)}
	if _role == "host":
		var simulation := _game.get_network_remote_body_simulation()
		var publication := _publication(avatar)
		var remote := (_game.get("_network_remote_pilots") as Dictionary).get(_craft.ship_id, {}) as Dictionary
		var source := remote.get("source") as NetworkRemotePilotCommandSource
		var owner: CrewSeatRoleAuthority = _craft.get_crew_role_authority()
		receipt["home"] = _host_return_receipt()
		receipt["home_leaves"] = {"docked_current": _host_return_docked(),
			"occupant_is_hull": _flight_berth.get_occupant() == _craft,
			"reservation_owner_is_hull": _flight_berth.get_reservation_owner() == _craft,
			"passenger_seated_current": _host_reboard_seated_current(),
			"passenger_body_current": _reboard_cabin_identity_current(),
			"pilot_peer_generation": _peer_generation(peer),
			"passenger_peer_generation": _peer_generation(int(_flight_start.passenger_peer))}
		receipt["ownership"] = _game.network_session.get_owned_ship(_craft.ship_id)
		receipt["pilot_occupancies"] = _pilot_reclaim_occupancies()
		receipt["pilot_body"] = _node_identity(simulation.get_body(avatar))
		receipt["pilot_body_record"] = simulation.get_body_record(avatar)
		receipt["pilot_body_movement"] = _game.network_session.get_movement_avatar_snapshot(avatar)
		receipt["pilot_role_assignment"] = owner.get_assignment(peer, avatar) if owner != null else {}
		receipt["pilot_wire"] = _primitive_fields(publication.get("wire", {}) as Dictionary,
			["entity_id", "entity_generation", "parent_frame_id", "parent_frame_generation", "occupancy_state", "server_tick"])
		receipt["pilot_publication"] = {"occupant": _node_identity(publication.get("occupant") as Node),
			"owner_peer_id": int(publication.get("owner_peer_id", 0)), "seat_anchor": _node_identity(_craft.get_pilot_seat_anchor())}
		receipt["pilot_movement"] = _pilot_reclaim_registry()
		receipt["remote_source"] = {"instance_id": str(source.get_instance_id()), "stream_id": source.get_stream_id(),
			"delivery_generation": source.get_delivery_generation()} if source != null else {}
		receipt["source_leaves"] = {"remote_peer_id": int(remote.get("peer_id", 0)),
			"active_source": _node_identity(_craft.get("_command_source") as Node),
			"source_is_active": source != null and _craft.get("_command_source") == source,
			"source_enabled_owner": source != null and source.is_enabled_owner(),
			"source_peer_id": source.get_pilot_peer_id() if source != null else 0,
			"source_ship_id": source.get_ship_id() if source != null else &"",
			"piloted": _craft.is_piloted(), "remote_piloted": _craft.is_remote_piloted(),
			"wire_receipt": source.get_roll_receipt() if source != null else {},
			"audit": source.get_audit() if source != null else {}}
		var command := _craft.get_last_ship_command()
		receipt["consumed_command"] = command.to_dictionary() if command != null else {}
	else:
		var source := _game.get_network_remote_body_intent_source()
		receipt["ownership"] = _client_ownership_record()
		receipt["arrival"] = _client_return_receipt()
		receipt["body_source"] = source.get_audit() if source != null else {}
		receipt["claim"] = (_game.get("_network_client_boarding_claim") as Dictionary).duplicate(true)
		receipt["boarding_answer"] = _game.network_session.get_boarding_intent_result_replica()
		receipt["pilot_relationship"] = _game.network_session.get_moving_interior_latest_relationship(avatar)
		receipt["producer"] = _pilot_reclaim_local_producer()
		receipt["helm_wire"] = (_game.get("_network_remote_helm") as Dictionary).duplicate(true)
		receipt["local_leaves"] = {"same_identity": _same_identity(), "walking_identity": _walking_identity_is_preserved(),
			"phase": _game.phase, "transition_busy": bool(_game.get("_transition_busy")),
			"floor": _player.is_on_floor(), "control": _player.is_control_enabled(), "seated": _player.is_seated(),
			"station_seated": _player.is_station_seated(), "piloting": bool(_game.get("_piloting")),
			"position": _vector_values(_player.global_position - _game.world.global_position),
			"cabin_containment": _player.get_cabin_containment_report(),
			"boarding_candidate": _node_identity(_game.boarding_candidate),
			"station_candidate": _node_identity(_game.station_interaction_candidate),
			"reboard_blocked_ship": _node_identity(_game.get("_reboard_blocked_ship") as Node),
			"boarding_distance_m": _player.get_interaction_origin().distance_to(_craft.get_boarding_position()),
			"pilot_anchor_error_m": _player.global_position.distance_to(_craft.get_pilot_seat_anchor().global_position),
			"passenger_seated_current": _local_reboard_seated_current(_reboard_seated) if _role == "client_b" else true}
	return receipt


func _pilot_exit_owner_retired(ownership: Dictionary) -> bool:
	return ownership.get("ship_id") == _craft.ship_id and int(ownership.get("owner_peer_id", -1)) == 0 \
		and int(ownership.get("ship_generation", 0)) == int(_flight_start.identities.ownership.ship_generation) \
		and int(ownership.get("ownership_generation", 0)) > int(_flight_start.identities.ownership.ownership_generation)


func _host_pilot_exit_retired() -> bool:
	var peer := int(_flight_start.pilot_peer)
	var avatar := GameFlow.network_client_boarding_avatar_id(peer)
	var simulation := _game.get_network_remote_body_simulation()
	var owner: CrewSeatRoleAuthority = _craft.get_crew_role_authority()
	for held: Dictionary in _game.network_session.get_boarding_snapshot().get("occupancies", []):
		if int(held.get("peer_id", 0)) == peer or held.get("avatar_id") == avatar:
			return false
	var active := _craft.get("_command_source") as ShipCommandSource
	return not (_game.get("_network_remote_pilots") as Dictionary).has(_craft.ship_id) \
		and not is_instance_valid(_flight_source) and not _craft.is_remote_piloted() and not _craft.is_piloted() \
		and not active is NetworkRemotePilotCommandSource \
		and int(_game.network_session.get_remote_ship_command_snapshot().get("pilot_count", -1)) == 0 \
		and _pilot_exit_owner_retired(_game.network_session.get_owned_ship(_craft.ship_id)) \
		and owner != null and owner.get_assignment(peer, avatar).is_empty() \
		and simulation.get_body(avatar) == null and simulation.get_body_record(avatar).is_empty() \
		and _game.network_session.get_movement_avatar_snapshot(avatar).is_empty() \
		and _publication(avatar).is_empty() and _game.network_session.get_moving_interior_occupancy(avatar).is_empty()


func _client_pilot_exit_retired() -> bool:
	if not _flight_file_exists("host.pilot_exit_retired"):
		return false
	var retirement_home := _read("host.pilot_exit_retired").get("home", {}) as Dictionary
	var retirement_pose_tick: int = int(retirement_home.get("pose_tick", 0))
	var pose := _flight_pose_sample()
	if retirement_pose_tick <= 0:
		return false
	var pilot_avatar := GameFlow.network_client_boarding_avatar_id(int(_flight_start.pilot_peer))
	var local_source := _craft.get("_default_local_command_source") as ShipCommandSource
	var active := _craft.get("_command_source") as ShipCommandSource
	var answer := _game.network_session.get_boarding_intent_result_replica()
	# Coasting pose headers retain last-pilot attribution. Current ownership
	# retires in its own ledger; require a fresh pose in the boarding-tick domain.
	return _pilot_exit_owner_retired(_client_ownership_record()) \
		and not pose.is_empty() and pose.get("ship_id") == _craft.ship_id \
		and int(pose.get("pose_tick", 0)) >= retirement_pose_tick \
		and _game.network_session.get_moving_interior_latest_relationship(pilot_avatar).is_empty() \
		and not bool(_game.get("_piloting")) \
		and (local_source == null or not local_source.is_enabled_owner()) \
		and (active == null or not active.is_enabled_owner()) \
		and (_role != "client" or ((_game.get("_network_remote_helm") as Dictionary).is_empty()
			and (_game.get("_network_client_helm_input_sources") as Dictionary).is_empty()
			and (_game.get("_network_client_boarding_claim") as Dictionary).is_empty()
			and bool(answer.get("accepted", false)) and answer.get("status") == &"disembarked"
			and answer.get("action") == &"disembark" and answer.get("role") == &"pilot"
			and answer.get("avatar_id") == pilot_avatar and answer.get("ship_id") == _craft.ship_id
			and int(answer.get("sequence", 0)) > int(_pilot_exit_start.pilot_seat.get("claim_sequence", 0))))


func _pilot_exit_invariants() -> bool:
	if not _reboard_complete or _pilot_exit_start.is_empty():
		return false
	if not _craft.is_inside_tree() or _player.get_instance_id() != _initial_player_id \
			or _station_position().distance_to(_vector_from(_pilot_exit_start.hull_position)) > 0.05 \
			or _craft.velocity.length() > 0.05:
		return false
	if _role == "host":
		return _host_return_docked() and _host_reboard_seated_current() and _reboard_cabin_identity_current() \
			and _peer_generation(int(_flight_start.pilot_peer)) == int(_flight_manifest.client.peer_generation) \
			and _peer_generation(int(_flight_start.passenger_peer)) == int(_flight_manifest.client_b.peer_generation) \
			and _game.phase == GameFlow.Phase.INTRO and not _player.is_seated() and not _player.is_control_enabled() \
			and (not _pilot_exit_retired or _host_pilot_exit_retired())
	var landing := _client_landing_record()
	var operation := _flight_pose_sample().get("operation_presentation", {}) as Dictionary
	var ownership := _client_ownership_record()
	var owner_peer := int(ownership.get("owner_peer_id", -1))
	return _same_identity() and _walking_identity_is_preserved() \
		and bool(operation.get("landed", false)) and bool(operation.get("docked", false)) \
		and not bool(operation.get("landing", true)) and landing.get("state") == &"landed" \
		and int(landing.get("entity_generation", 0)) == _return_generation \
		and owner_peer in [0, int(_flight_start.pilot_peer)] \
		and _reboard_relationship_matches(_reboard_seated, true) \
		and (_role != "client_b" or (_local_reboard_seated_current(_reboard_seated)
			and _reboard_cabin_identity_current() and _return_controls_neutral())) \
		and (not _pilot_exit_retired or _client_pilot_exit_retired()) \
		and (_role != "client" or not _pilot_exit_grounded or (_local_pilot_exit_ground_current()
			and int(_game.get("_network_remote_helm_sent")) == _pilot_exit_helm_sent))


func _local_pilot_exit_ground_current() -> bool:
	var source := _game.get_network_remote_body_intent_source()
	var area := _craft.get_node_or_null(^"ShipBoardingArea") as ShipBoardingArea
	var avatar := GameFlow.network_client_boarding_avatar_id(_initial_peer_id)
	return _same_identity() and _walking_identity_is_preserved() and not _player.is_seated() \
		and not _player.is_station_seated() and _player.is_on_floor() and _player.is_control_enabled() \
		and not bool(_game.get("_transition_busy")) and not bool(_game.get("_piloting")) \
		and _game.phase in [GameFlow.Phase.APPROACH_SHIP, GameFlow.Phase.COMPLETE] \
		and not bool(_player.get_cabin_containment_report().get("active", true)) \
		and not _craft.get_moving_interior_component().is_occupant_registered(_player) \
		and _game.get("_cabin_ship") == null and _game.get("_boarding_area") == null \
		and (_game.get("_network_client_boarding_claim") as Dictionary).is_empty() \
		and (_game.get("_network_client_boarding_request") as Dictionary).is_empty() \
		and (source == null or not source.is_bound()) \
		and _game.network_session.get_moving_interior_latest_relationship(avatar).is_empty() \
		and area != null and area.get_reservation_token() != _player \
		and _player.global_position.distance_to(_postdock_ground_exit()) <= 2.5


func _observe_pilot_exit_motion() -> void:
	if _role != "client" or int(_player.get("_embodiment_state")) != PlayerController.EmbodimentState.DISEMBARKING:
		return
	var expected := _craft.get_exterior_exit_waypoints()
	var actual := _player.get("_transition_waypoints") as Array
	var current: bool = _player.get("_transition_frame") == _craft and actual.size() == expected.size() and expected.size() >= 3
	for index in mini(actual.size(), expected.size()):
		current = current and (actual[index] as Transform3D).is_equal_approx(expected[index])
	_require(current, "live original pilot exit retains every authored hatch/airstair waypoint and reference frame")
	_pilot_exit_route_observed = _pilot_exit_route_observed or current
	var position := _craft.to_local(_player.global_position)
	if not _pilot_exit_samples.is_empty():
		_pilot_exit_motion_observed = _pilot_exit_motion_observed \
			or position.distance_to(_vector_from(_pilot_exit_samples[0].position)) >= 1.0
	_pilot_exit_samples.append({"tick": Engine.get_physics_frames(), "position": _vector_values(position)})


func _pilot_exit_ground_distance() -> float:
	return ((_player.global_position - _game.world.global_position) - _pilot_exit_ground_start).slide(Vector3.UP).length()


func _pilot_exit_receipt() -> Dictionary:
	var receipt := {"selected": _pilot_exit_selected, "stage": _return_stage, "role": _role,
		"player": _node_identity(_player), "start": _pilot_exit_start.duplicate(true),
		"hull_position": _vector_values(_station_position()), "hull_speed": _craft.velocity.length(),
		"hull_error_m": _station_position().distance_to(_vector_from(_pilot_exit_start.hull_position)),
		"authority_retired": _pilot_exit_retired, "complete": _pilot_exit_complete}
	if _role == "host":
		var peer := int(_flight_start.pilot_peer)
		var avatar := GameFlow.network_client_boarding_avatar_id(peer)
		var simulation := _game.get_network_remote_body_simulation()
		var owner: CrewSeatRoleAuthority = _craft.get_crew_role_authority()
		var active := _craft.get("_command_source") as ShipCommandSource
		receipt["retired"] = _host_pilot_exit_retired()
		receipt["retirement_leaves"] = {
			"remote_binding_absent": not (_game.get("_network_remote_pilots") as Dictionary).has(_craft.ship_id),
			"original_source_alive": is_instance_valid(_flight_source), "active_source": _node_identity(active),
			"active_source_is_remote": active is NetworkRemotePilotCommandSource,
			"piloted": _craft.is_piloted(), "remote_piloted": _craft.is_remote_piloted(),
			"ownership_retired": _pilot_exit_owner_retired(_game.network_session.get_owned_ship(_craft.ship_id)),
			"occupancies": _game.network_session.get_boarding_snapshot().get("occupancies", []),
			"crew_owner_present": owner != null,
			"role_assignment": owner.get_assignment(peer, avatar) if owner != null else {},
			"body": _node_identity(simulation.get_body(avatar)), "body_record": simulation.get_body_record(avatar),
			"movement": _game.network_session.get_movement_avatar_snapshot(avatar),
			"publication_empty": _publication(avatar).is_empty(),
			"network_occupancy": _game.network_session.get_moving_interior_occupancy(avatar)}
		receipt["ownership"] = _game.network_session.get_owned_ship(_craft.ship_id)
		receipt["remote_commands"] = _game.network_session.get_remote_ship_command_snapshot()
		receipt["home"] = _host_return_receipt()
		receipt["home_leaves"] = {"docked_current": _host_return_docked(),
			"occupant_is_hull": _flight_berth.get_occupant() == _craft,
			"reservation_owner_is_hull": _flight_berth.get_reservation_owner() == _craft,
			"passenger_seated_current": _host_reboard_seated_current(),
			"passenger_body_identity_current": _reboard_cabin_identity_current(),
			"pilot_peer_generation": _peer_generation(peer),
			"passenger_peer_generation": _peer_generation(int(_flight_start.passenger_peer)),
			"host_phase": _game.phase, "host_seated": _player.is_seated(), "host_control": _player.is_control_enabled()}
		receipt["passenger"] = _reboard_receipt()
	else:
		var local_source := _craft.get("_default_local_command_source") as ShipCommandSource
		var active := _craft.get("_command_source") as ShipCommandSource
		var area := _craft.get_node_or_null(^"ShipBoardingArea") as ShipBoardingArea
		var source := _game.get_network_remote_body_intent_source()
		var pilot_avatar := GameFlow.network_client_boarding_avatar_id(int(_flight_start.pilot_peer))
		receipt["ownership"] = _client_ownership_record()
		receipt["arrival"] = _client_return_receipt()
		var retirement_home := _read("host.pilot_exit_retired").get("home", {}) as Dictionary
		receipt["retirement_pose"] = {
			"boundary_pose_tick": int(retirement_home.get("pose_tick", 0)),
			"consumed_pose_tick": int(_flight_pose_sample().get("pose_tick", 0)),
			"consumed_ship_id": _flight_pose_sample().get("ship_id", &""),
			"coast_header_pilot_peer_id": int(_flight_pose_sample().get("pilot_peer_id", -1))}
		receipt["local_leaves"] = {"same_identity": _same_identity(), "walking_identity": _walking_identity_is_preserved(),
			"player_is_original": _player.get_instance_id() == _initial_player_id,
			"phase": _game.phase, "transition_busy": bool(_game.get("_transition_busy")),
			"piloting": bool(_game.get("_piloting")), "floor": _player.is_on_floor(),
			"control": _player.is_control_enabled(), "seated": _player.is_seated(),
			"station_seated": _player.is_station_seated(), "cabin_containment": _player.get_cabin_containment_report(),
			"frame_registered": _craft.get_moving_interior_component().is_occupant_registered(_player),
			"cabin_ship": _node_identity(_game.get("_cabin_ship") as Node),
			"boarding_area": _node_identity(_game.get("_boarding_area") as Node),
			"hatch_reserved_by_player": area != null and area.get_reservation_token() == _player,
			"boarding_request_pending": not (_game.get("_network_client_boarding_request") as Dictionary).is_empty(),
			"body_source": source.get_audit() if source != null else {},
			"local_source_owner": local_source != null and local_source.is_enabled_owner(),
			"active_source_owner": active != null and active.is_enabled_owner(),
			"remote_helm": (_game.get("_network_remote_helm") as Dictionary).duplicate(true),
			"helm_input_bindings": (_game.get("_network_client_helm_input_sources") as Dictionary).size(),
			"pilot_relationship": _game.network_session.get_moving_interior_latest_relationship(pilot_avatar),
			"passenger_relationship_current": _reboard_relationship_matches(_reboard_seated, true),
			"passenger_seated_current": _local_reboard_seated_current(_reboard_seated) if _role == "client_b" else true}
		receipt["ground_current"] = _local_pilot_exit_ground_current() if _role == "client" else false
		receipt["ground_distance_m"] = _pilot_exit_ground_distance() if _pilot_exit_grounded else 0.0
		receipt["exit_distance_m"] = _player.global_position.distance_to(_postdock_ground_exit())
		receipt["route_observed"] = _pilot_exit_route_observed
		receipt["motion_observed"] = _pilot_exit_motion_observed
		receipt["exit_samples"] = _pilot_exit_samples.duplicate(true)
		receipt["helm_quiet"] = _pilot_exit_helm_sent >= 0 and int(_game.get("_network_remote_helm_sent")) == _pilot_exit_helm_sent
		receipt["claim"] = (_game.get("_network_client_boarding_claim") as Dictionary).duplicate(true)
		receipt["boarding_answer"] = _game.network_session.get_boarding_intent_result_replica()
	return receipt


func _postdock_receipt() -> Dictionary:
	var peer := int(_flight_start.passenger_peer)
	var avatar := GameFlow.network_client_boarding_avatar_id(peer)
	var source: Variant = _flight_source
	# Remote command sources need not be children of the scene tree. Their
	# object identity and stream remain valid without a scene-tree path.
	var source_identity := {"valid": is_instance_valid(source)}
	if is_instance_valid(source):
		source_identity["instance_id"] = str(source.get_instance_id())
	var receipt := {"selected": _postdock_selected, "stage": _return_stage, "role": _role,
		"peer_id": peer if _role == "host" else _initial_peer_id,
		"peer_generation": _peer_generation(peer) if _role == "host" else _initial_peer_generation,
		"avatar_id": str(avatar), "source": {"identity": source_identity,
			"stream_id": source.get_stream_id() if is_instance_valid(source) else -1,
			"delivery_generation": source.get_delivery_generation() if is_instance_valid(source) else -1}}
	if _role == "host":
		var simulation := _game.get_network_remote_body_simulation()
		var body := simulation.get_body(avatar) as PlayerController
		receipt["body"] = _node_identity(body)
		receipt["body_record"] = _primitive_fields(simulation.get_body_record(avatar),
			["entity_id", "entity_generation", "owner_peer_id", "seat_state", "avatar_mode", "last_intent_tick"])
		receipt["occupancies"] = _postdock_occupancies()
		receipt["assignment"] = _primitive_fields(_craft.get_crew_role_authority().get_assignment(peer, avatar),
			["peer_id", "avatar_id", "ship_id", "vessel_id", "role", "seat_id", "seat_generation", "claim_sequence"])
		receipt["wire"] = _primitive_fields(_publication(avatar).get("wire", {}) as Dictionary,
			["entity_id", "entity_generation", "parent_frame_id", "parent_frame_generation", "occupancy_state", "server_tick", "sequence"])
		if body != null:
			receipt["ship_local_position"] = _vector_values(_craft.to_local(body.global_position))
			receipt["supported"] = body.is_on_floor()
			receipt["seated"] = body.is_seated()
		receipt["home"] = _host_return_receipt()
	else:
		var intent := _game.get_network_remote_body_intent_source()
		receipt["player"] = _node_identity(_player)
		receipt["ship_local_position"] = _vector_values(_craft.to_local(_player.global_position))
		receipt["position"] = _vector_values(_player.global_position - _game.world.global_position)
		receipt["claim"] = _primitive_fields(_game.get("_network_client_boarding_claim") as Dictionary,
			["ship_id", "seat_id", "role", "peer_id", "avatar_id", "ship_generation", "frame_generation", "seat_generation", "claim_sequence"])
		receipt["relationship"] = _primitive_fields(_game.network_session.get_moving_interior_latest_relationship(
			GameFlow.network_client_boarding_avatar_id(_initial_peer_id)),
			["entity_id", "entity_generation", "parent_frame_id", "parent_frame_generation", "occupancy_state", "server_tick"])
		receipt["body_source"] = _primitive_fields(intent.get_audit() if intent != null else {},
			["entity_id", "entity_generation", "stream_id", "sequence", "opening_confirmed", "bound"])
		var view := _game.network_session.get_passenger_replica_snapshot()
		receipt["passenger_view"] = _primitive_fields(view, ["ship_id", "entity_generation", "binding_generation", "seated", "server_tick"])
		receipt["assignment"] = _primitive_fields(view.get("assignment", {}) as Dictionary,
			["peer_id", "avatar_id", "ship_id", "vessel_id", "role", "seat_id", "seat_generation", "claim_sequence"])
		receipt["boarding"] = _primitive_fields(_game.get_network_client_boarding_audit(),
			["sequence", "confirmations", "requests", "last_status", "request_pending", "server_tick"])
		receipt["supported"] = _player.is_on_floor()
		receipt["control_enabled"] = _player.is_control_enabled()
		receipt["seated"] = _player.is_seated()
		receipt["ground_supported"] = _local_postdock_ground_current() if _role == "client_b" else false
		receipt["ground_distance_m"] = _postdock_ground_distance() if _postdock_exited else 0.0
		receipt["exit_route_observed"] = _postdock_exit_route_observed
		receipt["exit_motion_observed"] = _postdock_exit_motion_observed
		receipt["exit_samples"] = _postdock_exit_samples.duplicate(true)
		if _role == "client_b":
			receipt["interaction"] = _postdock_interaction_receipt()
		receipt["arrival"] = _client_return_receipt()
	return receipt


func _postdock_interaction_receipt() -> Dictionary:
	var area: ShipBoardingArea = _craft.get_node_or_null(^"ShipBoardingArea") as ShipBoardingArea
	var origin: Vector3 = _player.get_interaction_origin()
	var facing: Vector3 = _player.get_interaction_direction()
	var nearby: Array[Dictionary] = []
	for node: Node3D in _player.get_nearby_interactables():
		var offset: Vector3 = node.global_position - origin
		var row: Dictionary = {"identity": _node_identity(node), "distance_m": offset.length(),
			"facing_dot": facing.dot(offset.normalized()),
			"ship_local_position": _vector_values(_craft.to_local(node.global_position))}
		if node is ShipCrewSeat:
			row["role"] = (node as ShipCrewSeat).get_role()
			row["seat_id"] = (node as ShipCrewSeat).get_seat_id()
		nearby.append(row)
	return {"boarding_candidate": _node_identity(_game.boarding_candidate),
		"station_candidate": _node_identity(_game.station_interaction_candidate),
		"reboard_blocked_ship": _node_identity(_game.get("_reboard_blocked_ship") as Node),
		"origin_ship_local": _vector_values(_craft.to_local(origin)),
		"facing_ship_local": _vector_values(_craft.global_basis.inverse() * facing),
		"boarding_point_ship_local": _vector_values(_craft.to_local(_craft.get_boarding_position())),
		"boarding_distance_m": origin.distance_to(_craft.get_boarding_position()),
		"fallback_reach_m": GameFlow.BOARDING_FALLBACK_REACH,
		"boardable": _craft.is_boardable(), "piloted": _craft.is_piloted(),
		"engine_state": _craft.get_telemetry().get("engine_state", &""),
		"area": _node_identity(area),
		"area_available_for_player": area != null and area.is_available_for(_player),
		"area_reservation_is_player": area != null and area.get_reservation_token() == _player,
		"nearby": nearby}
