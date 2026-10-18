## test-matrix-display: input-only
extends "res://tests/network/jovian_network_two_client_boarding_test.gd"

## NET-JOVIAN-DEPART: select-only continuation of the unchanged ordinary route.
## The pilot supplies action events; all commands, movement, leases and replicas
## remain production-owned. The inherited coordinator owns abort and OS exits.
const FLIGHT_ROLES := ["client", "client_b"]
var _flight_stage := "boarding"
var _flight_start: Dictionary = {}
var _flight_manifest: Dictionary = {}
var _flight_source: ShipCommandSource
var _flight_anchor: Node3D
var _flight_berth: ShipBerth
var _flight_saw_throttle := false
var _flight_saw_brake := false
var _flight_departed := false
var _flight_pose_ready := false


func _peer_profile() -> Dictionary:
	var profile := super._peer_profile()
	profile["script"] = "res://tests/network/jovian_network_two_client_flight_test.gd"
	return profile


func _print_peer_success() -> void:
	# Only the inherited coordinator calls this, after all actual OS exits0.
	print("JOVIAN_NETWORK_TWO_CLIENT_FLIGHT_OK checks=%d" % _checks)


func _host_scenario() -> bool:
	_flight_stage = "host.flight_start"
	var seats := _read("host.seats_confirmed")
	var remote := (_game.get("_network_remote_pilots") as Dictionary).get(_craft.ship_id, {}) as Dictionary
	_flight_source = remote.get("source") as ShipCommandSource
	for node: Node in get_nodes_in_group(ShipBerth.GROUP):
		var berth := node as ShipBerth
		if berth != null and berth.get_occupant() == _craft:
			_flight_berth = berth
	_flight_manifest = _host_flight_manifest()
	if not _require(_flight_berth != null and _flight_source is NetworkRemotePilotCommandSource
		and _host_flight_current() and bool(_craft.get_telemetry().get("landed", false))
		and (_game.get("_reserved_berth_ids") as Dictionary).get(_craft.get_instance_id()) == _flight_berth.berth_id
		and (_game.get("_berth_tokens") as Dictionary).has(_craft.get_instance_id()),
		"departure begins at this ship's occupied production berth with both exact seated identities"):
		return false
	var initial_nose := -_craft.global_basis.z.normalized()
	_flight_start = {"position": _vector_values(_station_position()), "nose": _vector_values(initial_nose),
		"pose_tick": int(_game.get("_network_boarding_server_tick")),
		"pilot_peer": int(seats.pilot_peer), "passenger_peer": int(seats.passenger_peer),
		"berth_id": str(_flight_berth.berth_id), "identities": _flight_manifest}
	_write("host.flight_start", _flight_start)
	if not await _flight_wait(func(): return _flight_files_ready(".flight_ready"), 8.0,
		"both original clients observe initial host pose clock and retain original seats before flight"):
		return false
	_write("host.flight_go", {})
	_flight_stage = "host.forward_5m"
	var initial_position := _vector_from(_flight_start.position)
	if not await _flight_wait(func():
		_observe_flight_command()
		return _flight_saw_throttle and (_station_position() - initial_position).dot(initial_nose) >= 5.0 \
			and _host_departure_is_physical(), 10.0,
		"host consumes current pilot positive throttle, travels5m along initial nose and physically releases berth within10s"):
		return false
	_flight_departed = true
	_write("host.flight_departed", _host_flight_receipt())
	_flight_stage = "host.brake_stop"
	var stopped_since := [-1]
	if not await _flight_wait(func():
		_observe_flight_command()
		if _flight_saw_brake and _craft.velocity.length() <= 0.5:
			if int(stopped_since[0]) < 0:
				stopped_since[0] = Time.get_ticks_msec()
		else:
			stopped_since[0] = -1
		return int(stopped_since[0]) >= 0 and Time.get_ticks_msec() - int(stopped_since[0]) >= 1000 \
			and _host_departure_is_physical(), 10.0,
		"host consumes current pilot brake and holds authoritative speed<=0.5m/s for1s within10s"):
		return false
	_write("host.flight_stopped", _host_flight_receipt())
	_flight_stage = "host.replica_convergence"
	if not await _flight_wait(func(): return _flight_files_ready(".flight_converged"), 5.0,
		"both actual client craft converge within0.5m of host's station-frame stopped pose within5s"):
		return false
	if not _require(_host_departure_is_physical() and _host_flight_current()
		and _host_passenger_follows_anchor(true),
		"host retains exact pilot source, ownership and both original seat/entity generations after shared departure"):
		return false
	_write("host.flight_complete", _host_flight_receipt())
	_flight_stage = "retained"
	return true


func _client_scenario() -> bool:
	var result := await _client_flight()
	# This also runs on any hook failure, before the inherited failure-capture
	# barrier. First-failure capture has already retained the actual held input.
	if _role == "client":
		for action in [&"move_forward", &"brake"]:
			_action(action, false)
			Input.action_release(action)
	return result


func _client_flight() -> bool:
	_flight_stage = "client.flight_start"
	var initialization_deadline := Time.get_ticks_msec() + 8000
	_flight_source = _craft.get("_default_local_command_source") as ShipCommandSource
	_flight_anchor = _player.get("_seat_anchor") as Node3D
	_flight_manifest = _local_flight_manifest()
	if not await _flight_wait(func(): return _flight_file_exists("host.flight_start"), 8.0,
		"host records confirmed seats, station-frame pose and initial pose clock"):
		return false
	_flight_start = _read("host.flight_start")
	if not _require(int(_flight_start.get("pose_tick", 0)) > 0
		and int(_flight_start.get("pilot_peer", 0)) == int(_read("host.seats_confirmed").get("pilot_peer", -1))
		and _local_flight_current(), "same seated Player observes current host pilot identity before movement"):
		return false
	# Seat confirmation can precede the first consumed craft pose. Keep checking
	# all seat/source/identity predicates while waiting inside the same initial8s.
	if not await _flight_wait(func():
		var sample := _flight_pose_sample()
		return int(sample.get("pose_tick", -1)) > int(_flight_start.pose_tick) \
			and int(sample.get("pilot_peer_id", 0)) == int(_flight_start.pilot_peer),
		maxf(0.0, float(initialization_deadline - Time.get_ticks_msec()) / 1000.0),
		"initial consumed craft pose advances past host start tick with current pilot owner inside initial8s"):
		return false
	_flight_pose_ready = true
	if not _require(_local_flight_current(), "current consumed pilot owner remains enforced after initial pose readiness"):
		return false
	_write(_role + ".flight_ready", _client_flight_receipt())
	if not await _flight_wait(func(): return _flight_file_exists("host.flight_go"), 8.0,
		"host authorizes flight after both seated clients are ready"):
		return false
	_flight_stage = "client.forward_5m"
	if _role == "client":
		_action(&"move_forward", true)
	if not await _flight_wait(func(): return _flight_file_exists("host.flight_departed"), 10.0,
		"host confirms actual authoritative5m forward departure within10s"):
		return false
	if _role == "client":
		_action(&"move_forward", false)
		_action(&"brake", true)
	_flight_stage = "client.brake_stop"
	if not await _flight_wait(func(): return _flight_file_exists("host.flight_stopped"), 10.0,
		"host confirms authoritative braked stop and1s stable speed within10s"):
		return false
	if _role == "client":
		_action(&"brake", false)
	var stopped := _read("host.flight_stopped")
	var stopped_position := _vector_from(stopped.position)
	_flight_stage = "client.replica_convergence"
	if not await _flight_wait(func():
		var sample := _flight_pose_sample()
		return int(sample.get("pose_tick", -1)) > int(_flight_start.pose_tick) \
			and int(sample.get("pilot_peer_id", 0)) == int(_flight_start.pilot_peer) \
			and _station_position().distance_to(stopped_position) <= 0.5 \
			and _body_follows_anchor(_player, _flight_anchor, true), 5.0,
		"actual client hull converges<=0.5m in station frame with advanced consumed pose tick and same pilot owner within5s"):
		return false
	_write(_role + ".flight_converged", _client_flight_receipt())
	if not await _flight_wait(func(): return _flight_file_exists("host.flight_complete"), 8.0,
		"host confirms both actual replicas and retained authoritative seat generations"):
		return false
	_flight_stage = "retained"
	return _require(_local_flight_current() and _body_follows_anchor(_player, _flight_anchor, true),
		"original real Player remains at original anchor with honest role/HUD and unchanged authority after departure")


func _flight_wait(predicate: Callable, seconds: float, description: String) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline and not _aborted():
		if not _require(_host_flight_current() if _role == "host" else _local_flight_current(),
			"exact source/owner, authenticated Players and seat/entity generations remain current throughout " + _flight_stage):
			return false
		if bool(predicate.call()):
			return _require(true, description)
		await _ticks(1)
	return _require(false, description)


func _host_flight_manifest() -> Dictionary:
	var seats := _read("host.seats_confirmed")
	var manifest := {"ownership": _primitive_fields(_game.network_session.get_owned_ship(_craft.ship_id),
		["ship_id", "ship_generation", "owner_peer_id", "ownership_generation"])}
	for role: String in FLIGHT_ROLES:
		var peer := int(seats.get("pilot_peer" if role == "client" else "passenger_peer", 0))
		var avatar := GameFlow.network_client_boarding_avatar_id(peer)
		var publication := _publication(avatar)
		var held_seat: Dictionary = {}
		for held: Dictionary in _game.network_session.get_boarding_snapshot().get("occupancies", []):
			if int(held.get("peer_id", 0)) == peer and held.get("ship_id") == _craft.ship_id \
				and held.get("avatar_id") == avatar:
				held_seat = _primitive_fields(held,
					["peer_id", "avatar_id", "ship_id", "ship_generation", "role", "seat_id", "seat_generation", "claim_sequence"])
		if role == "client_b":
			var owner: CrewSeatRoleAuthority = _craft.get_crew_role_authority()
			held_seat = _primitive_fields(owner.get_assignment(peer, avatar) if owner != null else {},
				["peer_id", "avatar_id", "ship_id", "role", "seat_id", "seat_generation", "claim_sequence"])
		manifest[role] = {"peer_generation": _peer_generation(peer), "seat": held_seat,
			"occupant": _node_identity(publication.get("occupant") as Node),
			"wire": _primitive_fields(publication.get("wire", {}) as Dictionary,
				["entity_id", "entity_generation", "parent_frame_id", "parent_frame_generation"])}
	return manifest


func _host_flight_current() -> bool:
	return _host_flight_identity_current() \
		and (not _flight_departed or _host_departure_is_physical())


## Identity survives a later ordinary landing; departure still separately
## requires the actual unlanded craft and freed berth in its default caller.
func _host_flight_identity_current() -> bool:
	var seats := _read("host.seats_confirmed")
	var pilot := int(seats.get("pilot_peer", 0))
	var passenger := int(seats.get("passenger_peer", 0))
	var remote := (_game.get("_network_remote_pilots") as Dictionary).get(_craft.ship_id, {}) as Dictionary
	var source := remote.get("source") as NetworkRemotePilotCommandSource
	return _pilot_is_current(pilot) and _passenger_is_current(passenger) \
		and source != null and source == _flight_source and source.is_enabled_owner() \
		and source.get_pilot_peer_id() == pilot and source.get_ship_id() == _craft.ship_id \
		and _craft.get("_command_source") == source \
		and int(_game.network_session.get_owned_ship(_craft.ship_id).get("owner_peer_id", 0)) == pilot \
		and _host_passenger_follows_anchor() \
		and _host_flight_manifest() == _flight_manifest \
		and _game.phase == GameFlow.Phase.INTRO and not _player.is_seated() and not _player.is_control_enabled()


func _local_flight_manifest() -> Dictionary:
	var claim := _game.get("_network_client_boarding_claim") as Dictionary
	var view := _game.network_session.get_passenger_replica_snapshot()
	return {"claim": _primitive_fields(claim,
		["ship_id", "seat_id", "role", "avatar_id", "peer_id", "peer_generation", "seat_generation", "claim_sequence"]),
		"passenger_assignment": _primitive_fields(view.get("assignment", {}) as Dictionary,
			["ship_id", "seat_id", "role", "avatar_id", "peer_id", "seat_generation", "claim_sequence"])}


func _local_flight_current() -> bool:
	var current := _local_pilot_is_current() if _role == "client" else _local_passenger_is_current()
	var source := _craft.get("_default_local_command_source") as ShipCommandSource
	var active := _craft.get("_command_source") as ShipCommandSource
	var passenger_has_no_producer := _role == "client" or ((source == null or not source.is_enabled_owner())
		and (active == null or not active.is_enabled_owner()))
	var sample := _flight_pose_sample()
	var owner_current := not _flight_pose_ready or int(sample.get("pilot_peer_id", 0)) == int(_flight_start.pilot_peer)
	return current and _walking_identity_is_preserved() and _player.get_instance_id() == _initial_player_id \
		and _player.is_seated_at(_flight_anchor) and _body_follows_anchor(_player, _flight_anchor) \
		and source == _flight_source \
		and _local_flight_manifest() == _flight_manifest and passenger_has_no_producer and owner_current


func _body_follows_anchor(body: PlayerController, anchor: Node3D, stopped: bool = false) -> bool:
	# Production follows the cleaned live anchor with no body offset. Allow at
	# most one physics tick of ship travel while moving, then only5cm stopped.
	var tolerance := 0.05 if stopped else 0.05 + _craft.velocity.length() * _craft.get_physics_process_delta_time()
	return is_instance_valid(body) and is_instance_valid(anchor) \
		and body.global_position.distance_to(anchor.global_position) <= tolerance


func _host_passenger_follows_anchor(stopped: bool = false) -> bool:
	var passenger := int(_read("host.seats_confirmed").get("passenger_peer", 0))
	var body := _game.get_network_remote_body_simulation().get_body(
		GameFlow.network_client_boarding_avatar_id(passenger)) as PlayerController
	return _body_follows_anchor(body, (_craft as JovianLightFreighter).get_copilot_seat_anchor(), stopped)


func _host_departure_is_physical() -> bool:
	return not bool(_craft.get_telemetry().get("landed", true)) and is_instance_valid(_flight_berth) \
		and _flight_berth.get_occupant() != _craft and _flight_berth.get_reservation_owner() != _craft \
		and not (_game.get("_reserved_berth_ids") as Dictionary).has(_craft.get_instance_id()) \
		and not (_game.get("_berth_tokens") as Dictionary).has(_craft.get_instance_id())


func _observe_flight_command() -> void:
	var command := _craft.get_last_ship_command()
	if command != null and command.is_valid() and command.stream_id == _flight_source.get_stream_id():
		_flight_saw_throttle = _flight_saw_throttle or command.throttle > HeroShip.AUTOMATIC_ENGINE_INTENT_EPSILON
		_flight_saw_brake = _flight_saw_brake or command.brake


func _station_position() -> Vector3:
	# Production pose transport uses a translation-only station frame. Subtract
	# each peer's actual station position so rebases cannot manufacture travel.
	return _craft.global_position - _game.world.global_position


func _flight_pose_sample() -> Dictionary:
	return _game._network_craft_pose_stream.latest_sample(_craft.ship_id)


func _flight_file_exists(name: String) -> bool:
	return FileAccess.file_exists(_directory.path_join(name))


func _flight_files_ready(suffix: String) -> bool:
	return _flight_file_exists("client" + suffix) and _flight_file_exists("client_b" + suffix)


func _vector_values(vector: Vector3) -> Array:
	return [vector.x, vector.y, vector.z]


func _vector_from(values: Array) -> Vector3:
	return Vector3(float(values[0]), float(values[1]), float(values[2]))


func _host_flight_receipt() -> Dictionary:
	return {"position": _vector_values(_station_position()), "speed": _craft.velocity.length(),
		"pose_tick": int(_game.get("_network_boarding_server_tick")),
		"saw_consumed_throttle": _flight_saw_throttle, "saw_consumed_brake": _flight_saw_brake,
		"landed": bool(_craft.get_telemetry().get("landed", true)), "berth_released": _host_departure_is_physical(),
		"identities": _host_flight_manifest()}


func _client_flight_receipt() -> Dictionary:
	return {"position": _vector_values(_station_position()), "player": _node_identity(_player),
		"anchor": _node_identity(_flight_anchor),
		"seat_anchor_error_m": _player.global_position.distance_to(_flight_anchor.global_position) if is_instance_valid(_flight_anchor) else -1.0,
		"identities": _local_flight_manifest(),
		"consumed_pose": _primitive_fields(_flight_pose_sample(), ["ship_id", "pose_tick", "pilot_peer_id"])}


func _failure_snapshot(description: String) -> Dictionary:
	var snapshot := super._failure_snapshot(description)
	var flight := {"stage": _flight_stage, "start": _flight_start,
		"saw_consumed_throttle": _flight_saw_throttle, "saw_consumed_brake": _flight_saw_brake}
	if is_instance_valid(_game) and is_instance_valid(_craft) and is_instance_valid(_player):
		flight["station_position"] = _vector_values(_station_position())
		flight["speed"] = _craft.velocity.length()
		flight["landed"] = bool(_craft.get("_landed"))
		flight["consumed_pose"] = _primitive_fields(_flight_pose_sample(), ["ship_id", "pose_tick", "pilot_peer_id"])
		var command := _craft.get_last_ship_command()
		if command != null:
			flight["consumed_command"] = {"stream_id": command.stream_id, "sequence": command.sequence,
				"throttle": command.throttle, "brake": command.brake}
		flight["input"] = {"move_forward": Input.is_action_pressed(&"move_forward"), "brake": Input.is_action_pressed(&"brake")}
		if _role == "host":
			flight["identities"] = _host_flight_manifest()
			flight["berth_released"] = _host_departure_is_physical()
		else:
			flight["local"] = _client_flight_receipt()
	snapshot["flight"] = flight
	return snapshot
