class_name NetworkHalyardPassengerBinding
extends RefCounted

signal cinder_navigator_ping_result_forwarded(result: Dictionary)
signal cinder_navigator_ping_tombstones_forwarded(result: Dictionary)

## One authored chair, admitted through the server's existing walking body.
## A cabin berth admits entry; only supported overlap grants this physical role.
var authority: CrewSeatRoleAuthority
var engineer: NetworkJovianEngineerBinding
var _session: NetworkEnetSessionAdapter
var _ship: HeroShip
var _requests: Dictionary = {}
var _gunner_errors: Dictionary = {}
var _simulation: NetworkRemoteBodySimulation
var _sequence := 0
var _generation := 1
var _migration := 1
var _lifetime := 0
var _elapsed := 0.0
var _retired := false
var _remote_navigator_submit_depth := 0
var navigator_submit: Callable
var navigator_release: Callable
var _navigator_bridge: NetworkCinderNavigatorPingBridge
var _navigator_presentation_generation := 0


func attach(session: NetworkEnetSessionAdapter, ship: HeroShip,
		simulation: NetworkRemoteBodySimulation, generation: int) -> bool:
	if not is_instance_valid(session) or not session.is_server() or not is_instance_valid(ship) \
			or not is_instance_valid(simulation) or ship.get_crew_role_authority() != null:
		return false
	var owner := CrewSeatRoleAuthority.new(1)
	var roster := owner.register_cinder_roster() if ship is CinderCargoHauler else owner.register_halyard_roster()
	if not roster.accepted or not ship.attach_crew_role_authority(owner).accepted:
		return false
	authority = owner
	_session = session
	_ship = ship
	_simulation = simulation
	_generation = generation
	_migration = int(session.get_migration_snapshot().migration_generation)
	_lifetime = ship.get_component_damage().get_ledger_generation()
	if ship is CinderCargoHauler:
		_navigator_bridge = NetworkCinderNavigatorPingBridge.new()
		_navigator_bridge.attach(session, ship, generation)
		_navigator_presentation_generation = generation
	if ship is HalyardCrewTransport:
		engineer = NetworkJovianEngineerBinding.new()
		if not engineer.attach_shared(session, ship, simulation, authority, generation):
			detach()
			return false
		_session.gunner_intent_requested.connect(_submit_gunner)
	_session.peer_disconnected.connect(_peer_disconnected)
	return true


func owns(owner: CrewSeatRoleAuthority) -> bool:
	return owner != null and owner == authority and is_instance_valid(_ship) and _ship.get_crew_role_authority() == owner


func next_request_sequence(previous: int) -> int:
	# Engineer requests and releases advance this same roster. A later chair
	# claim must follow that translated cursor even after last_intent is erased.
	if engineer != null:
		previous = maxi(previous, engineer.get_request_sequence_cursor())
	_sequence = maxi(_sequence, previous) + 1
	return _sequence


func claim(record: Dictionary, seat: ShipCrewSeat) -> Dictionary:
	if not _live() or not is_instance_valid(seat) or seat.get_ship() != _ship \
			or not _physical_crew_seat_matches(seat) \
			or seat.get_role_contract().is_empty():
		return {"accepted": false, "status": &"passenger_unavailable"}
	var body := record.get("body") as PlayerController
	var peer := int(record.get("owner_peer_id", 0))
	var frame: MovingInteriorFrame = _ship.get_moving_interior_component()
	var avatar := StringName(record.get("entity_id", &""))
	if body == null or peer <= 1 or peer not in _session.get_admitted_peer_ids() \
			or _simulation.get_body(avatar) != body \
			or int(_simulation.get_body_record(avatar).get("owner_peer_id", 0)) != peer \
			or record.get("craft") != _ship or record.get("frame") != frame \
			or not frame.is_occupant_registered(body) or not body.is_on_floor() \
			or body.get_interaction_origin().distance_to(seat.get_entry_transform().origin) > 3.25 \
			or seat not in body.get_nearby_interactables():
		return {"accepted": false, "status": &"passenger_body_mismatch"}
	var result := authority.claim(1, peer, avatar, seat.get_seat_id(), seat.get_role(), next_request_sequence(0))
	if _ship is CinderCargoHauler and result.accepted:
		_ship.refresh_loadmaster_status_display()
	return result


func release(record: Dictionary) -> void:
	if not owns(authority):
		return
	if engineer != null:
		engineer.release(record)
	var peer := int(record.get("owner_peer_id", 0))
	var avatar := StringName(record.get("entity_id", &""))
	var assignment := authority.get_assignment(peer, avatar)
	if _navigator_bridge != null:
		_forward_navigator_tombstones(_navigator_bridge.release_peer(peer))
	if not assignment.is_empty() and assignment.get("seat_id") == CinderCargoHauler.NAVIGATOR_STATION_SEAT_ID and navigator_release.is_valid():
		navigator_release.call(peer)
	if not assignment.is_empty():
		_ship.release_crew_role(1, peer, avatar, StringName(assignment.seat_id),
			next_request_sequence(int(authority.get_last_intent(peer, avatar).get("request_sequence", 0))), int(assignment.seat_generation))
	_gunner_errors.erase(peer)
	_elapsed = 1.0


func _peer_disconnected(peer: int, _receipt: Dictionary) -> void:
	if engineer != null:
		engineer.retire_peer_requests(peer)
	for avatar in _requests.keys():
		if avatar == GameFlow.network_client_boarding_avatar_id(peer):
			_requests.erase(avatar)
	if owns(authority):
		for row in authority.get_snapshot().get("assignments", []):
			if int(row.occupant_peer_id) == peer:
				release({"owner_peer_id": peer, "entity_id": row.avatar_id})


func advance(delta: float) -> void:
	if not is_instance_valid(_session) or not _session.is_server() or not _session.is_session_active() or not owns(authority):
		return
	var migration := int(_session.get_migration_snapshot().migration_generation)
	var lifetime := _ship.get_component_damage().get_ledger_generation()
	if migration != _migration or lifetime != _lifetime or (_ship.is_destroyed() and not _retired):
		_release_all()
		_requests.clear()
		_migration = migration
		_lifetime = lifetime
		_generation += 1
		if _navigator_bridge != null:
			_retire_navigator_publication(&"lifecycle_changed")
			_navigator_bridge.attach(_session, _ship, _generation)
			_navigator_presentation_generation = _generation
		_retired = _ship.is_destroyed()
		_elapsed = 1.0
	if _live():
		for row in authority.get_snapshot().get("assignments", []):
			if int(row.occupant_peer_id) <= 1 or row.role not in [&"passenger", &"gunner", &"engineer"]:
				continue
			var avatar := StringName(row.avatar_id)
			var seat := _simulation.get_body_crew_seat(avatar)
			if seat == null or not _physical_crew_seat_matches(seat) or seat.get_role_contract().is_empty():
				_simulation.stand_crew_body(avatar)
				release({"owner_peer_id": row.occupant_peer_id, "entity_id": avatar})
	if engineer != null:
		engineer.advance(delta)
	_elapsed += delta
	if _elapsed < 0.2:
		return
	_elapsed = 0.0
	for peer in _session.get_admitted_peer_ids():
		var boarded := false
		for entity in _simulation.get_body_entity_ids():
			var active := _simulation.get_body_record(entity)
			var active_body := _simulation.get_body(entity)
			if active_body != null and int(active.get("owner_peer_id", 0)) == int(peer) and active_body.get_cabin_containment_report().get("frame") == _ship:
				boarded = true
		if not boarded:
			continue
		if _ship is HalyardCrewTransport:
			var gunner_assignment := {}
			for row in authority.get_snapshot().get("assignments", []):
				if int(row.occupant_peer_id) == int(peer) and row.role == &"gunner":
					gunner_assignment = row.duplicate(true)
			var gunner_avatar := StringName(gunner_assignment.get("avatar_id", &""))
			var gunner_record := _simulation.get_body_record(gunner_avatar)
			var gunner_body := _simulation.get_body(gunner_avatar)
			var gunner_seat := _simulation.get_body_crew_seat(gunner_avatar)
			_session.publish_gunner_snapshot(int(peer), {
				"ship_id": _ship.get_ship_id(), "binding_generation": _generation,
				"assignment": gunner_assignment, "entity_generation": int(gunner_record.get("entity_generation", 0)),
				"seated": _live() and gunner_body != null and gunner_seat != null
					and gunner_record.get("seat_state") == &"seated" and _physical_crew_seat_matches(gunner_seat)
					and gunner_body.is_seated_at(gunner_seat.get_seat_anchor()),
				"gameplay": _ship.get_gunner_gameplay_state(), "error": _gunner_errors.get(peer, &""),
			})
		var assignment := {}
		for row in authority.get_snapshot().get("assignments", []):
			if int(row.occupant_peer_id) == int(peer) and row.role == &"passenger":
				assignment = row.duplicate(true)
		var avatar := StringName(assignment.get("avatar_id", &""))
		var body := _simulation.get_body(avatar)
		var record := _simulation.get_body_record(avatar)
		_session.publish_passenger_snapshot(int(peer), {
			"ship_id": _ship.get_ship_id(), "binding_generation": _generation,
			"assignment": assignment, "entity_generation": int(record.get("entity_generation", 0)),
			"manifest": _ship.get_loadmaster_manifest_snapshot(),
			"navigator": _ship.get_navigator_ping_snapshot() if _ship is CinderCargoHauler else {},
			"seated": _live() and body != null and not record.is_empty() and record.get("seat_state") == &"seated"
				and is_instance_valid(_simulation.get_body_crew_seat(avatar))
				and _physical_passenger_seat_matches(_simulation.get_body_crew_seat(avatar))
				and body.is_seated_at(_simulation.get_body_crew_seat(avatar).get_seat_anchor()),
		})


## This existing authenticated intent transport carries a role-specific action.
## Every capability still requires the actual host chair/body and current claim.
func submit_readiness(peer: int, payload: Dictionary) -> Dictionary:
	var fields := ["action", "avatar_id", "entity_generation", "seat_generation", "claim_sequence", "request_sequence", "binding_generation", "migration_generation", "server_tick"]
	if not _live() or _ship.get_component_damage().get_ledger_generation() != _lifetime or not _ship is CinderCargoHauler or peer not in _session.get_admitted_peer_ids() or payload.size() != fields.size():
		return {"accepted": false, "status": &"loadmaster_unavailable"}
	for field in fields:
		if not payload.has(field):
			return {"accepted": false, "status": &"invalid_loadmaster_payload"}
	for field in ["entity_generation", "seat_generation", "claim_sequence", "request_sequence", "binding_generation", "migration_generation"]:
		if not payload[field] is int or int(payload[field]) <= 0 or int(payload[field]) > 9007199254740991:
			return {"accepted": false, "status": &"invalid_loadmaster_generation"}
	if payload.action not in [&"cargo_manifest_ready", &"navigator_ping"] or not (payload.avatar_id is String or payload.avatar_id is StringName) or str(payload.avatar_id).length() > 64:
		return {"accepted": false, "status": &"invalid_loadmaster_action"}
	if not payload.server_tick is int or int(payload.server_tick) < _session.get_boarding_server_tick() - 120 or int(payload.server_tick) > _session.get_boarding_server_tick() + 12:
		return {"accepted": false, "status": &"stale_loadmaster_tick"}
	var avatar := StringName(payload.avatar_id)
	var record := _simulation.get_body_record(avatar)
	var body := _simulation.get_body(avatar)
	var seat := _simulation.get_body_crew_seat(avatar)
	var assignment := authority.get_assignment(peer, avatar)
	if record.is_empty() or body == null or seat == null or seat.get_ship() != _ship or seat.get_role_contract().is_empty() \
			or int(record.owner_peer_id) != peer or int(record.entity_generation) != int(payload.entity_generation) \
			or record.seat_state != &"seated" or not _physical_passenger_seat_matches(seat) or not body.is_seated_at(seat.get_seat_anchor()) \
			or not _ship.get_moving_interior_component().is_occupant_registered(body) or assignment.is_empty() \
			or assignment.seat_id != seat.get_seat_id() or assignment.role != &"passenger" \
			or assignment.seat_id != (CinderCargoHauler.NAVIGATOR_STATION_SEAT_ID if payload.action == &"navigator_ping" else CinderCargoHauler.LOADMASTER_STATION_SEAT_ID) \
			or int(assignment.seat_generation) != int(payload.seat_generation) or int(assignment.claim_sequence) != int(payload.claim_sequence):
		return {"accepted": false, "status": &"loadmaster_not_seated"}
	if int(payload.binding_generation) != _generation or int(payload.migration_generation) != _migration or int(_session.get_migration_snapshot().migration_generation) != _migration:
		return {"accepted": false, "status": &"stale_loadmaster_generation"}
	if int(payload.request_sequence) <= int(_requests.get(avatar, 0)):
		return {"accepted": false, "status": &"stale_loadmaster_sequence"}
	_requests[avatar] = int(payload.request_sequence)
	var sequence := next_request_sequence(int(authority.get_last_intent(peer, avatar).get("request_sequence", 0)))
	if payload.action == &"navigator_ping":
		# Preserve the authenticated client cursor separately from the translated
		# roster cursor. Only this consumed-current gate owns a terminal reply.
		var request := payload.duplicate(true)
		request["ship_id"] = _ship.get_ship_id()
		request["seat_id"] = seat.get_seat_id()
		var result := {"accepted": false, "status": &"navigator_consumer_unavailable"}
		if navigator_submit.is_valid():
			_remote_navigator_submit_depth += 1
			result = navigator_submit.call(peer, avatar, int(assignment.seat_generation), sequence)
			_remote_navigator_submit_depth -= 1
		_session.publish_navigator_request_result(peer, request, result)
		return result
	return _ship.submit_loadmaster_readiness(peer, avatar, sequence)


## The same existing publication bridge also serves Cinder while the host
## observes another craft. Presentation never changes the selected helm.
func publish_navigator_ping(peer: int, avatar: StringName, generation: int, sequence: int) -> Dictionary:
	if not _live() or _navigator_bridge == null:
		return {"accepted": false, "status": &"navigator_consumer_unavailable"}
	var peer_generation := 0
	for record: Dictionary in _session.get_migration_snapshot().get("peers", []):
		if int(record.get("peer_id", 0)) == peer and bool(record.get("active", false)):
			peer_generation = int(record.get("peer_generation", 0))
	var result := _navigator_bridge.submit_ping(peer, peer_generation, avatar, generation, sequence,
		{"channel": &"sensor", "marker_id": CinderCargoHauler.NAVIGATOR_ROUTE_ID},
		_session.get_boarding_server_tick(), _migration)
	cinder_navigator_ping_result_forwarded.emit(result.duplicate(true))
	return result


## True only during the authenticated remote callback, never host-local calls.
func is_submitting_remote_navigator_request() -> bool:
	return _remote_navigator_submit_depth > 0


func get_navigator_presentation_ship() -> CinderCargoHauler:
	return _ship as CinderCargoHauler if owns(authority) and _navigator_bridge != null else null


func get_navigator_presentation_generation() -> int:
	return _navigator_presentation_generation if get_navigator_presentation_ship() != null else 0


## Bridge detach clears its own generation before returning the envelope.
## Keep this owner's old generation live only through synchronous forwarding.
func _retire_navigator_publication(reason: StringName) -> Dictionary:
	if _navigator_bridge == null:
		return {}
	var result := _navigator_bridge.detach(reason)
	_forward_navigator_tombstones(result)
	_navigator_presentation_generation = 0
	return result


func _forward_navigator_tombstones(result: Dictionary) -> void:
	if int(result.get("tombstone_count", 0)) > 0:
		cinder_navigator_ping_tombstones_forwarded.emit(result.duplicate(true))


func _submit_gunner(peer: int, payload: Dictionary) -> void:
	var seat := _simulation.get_body_crew_seat(StringName(payload.get("avatar_id", &"")))
	if not is_instance_valid(seat) or seat.get_ship() != _ship:
		return
	var result := dispatch_gunner(peer, payload)
	_gunner_errors[peer] = StringName((result.get("effect", {}) as Dictionary).get("status", result.get("status", &"invalid_request"))) if not result.accepted or result.get("consumed", true) == false else &""
	_elapsed = 1.0


func dispatch_gunner(peer: int, payload: Dictionary) -> Dictionary:
	if not _live() or not _ship is HalyardCrewTransport or peer not in _session.get_admitted_peer_ids():
		return _result(false, &"session_unavailable")
	var fields := ["avatar_id", "entity_generation", "seat_generation", "claim_sequence", "target_generation", "trigger", "aim_local", "request_sequence", "binding_generation", "migration_generation", "server_tick"]
	if payload.size() != fields.size():
		return _result(false, &"invalid_gunner_payload")
	for field in fields:
		if not payload.has(field):
			return _result(false, &"invalid_gunner_payload")
	for field in ["entity_generation", "seat_generation", "claim_sequence", "target_generation", "request_sequence", "binding_generation", "migration_generation"]:
		if not payload[field] is int or int(payload[field]) <= 0 or int(payload[field]) > 9007199254740991:
			return _result(false, &"invalid_gunner_generation")
	if not payload.trigger is bool or not payload.aim_local is Vector3 \
			or not (payload.aim_local as Vector3).is_finite() \
			or not is_equal_approx((payload.aim_local as Vector3).length(), 1.0):
		return _result(false, &"invalid_gunner_aim")
	if not (payload.avatar_id is String or payload.avatar_id is StringName) \
			or str(payload.avatar_id).length() > 64 or not str(payload.avatar_id).is_valid_identifier():
		return _result(false, &"invalid_gunner_identity")
	if not payload.server_tick is int or int(payload.server_tick) < _session.get_boarding_server_tick() - 120 \
			or int(payload.server_tick) > _session.get_boarding_server_tick() + 12:
		return _result(false, &"stale_gunner_tick")
	var avatar := StringName(payload.avatar_id)
	var record := _simulation.get_body_record(avatar)
	var body := _simulation.get_body(avatar)
	var seat := _simulation.get_body_crew_seat(avatar)
	var assignment := authority.get_assignment(peer, avatar)
	var frame: MovingInteriorFrame = _ship.get_moving_interior_component()
	if record.is_empty() or body == null or seat == null or seat.get_ship() != _ship \
			or int(record.owner_peer_id) != peer or int(record.entity_generation) != int(payload.entity_generation) \
			or record.seat_state != &"seated" or seat.get_role_contract().is_empty() \
			or not _physical_crew_seat_matches(seat) or seat.get_role() != &"gunner" \
			or assignment.get("seat_id") != seat.get_seat_id() \
			or not body.is_seated_at(seat.get_seat_anchor()) or not frame.is_occupant_registered(body) \
			or assignment.is_empty() or assignment.role != &"gunner" \
			or int(assignment.seat_generation) != int(payload.seat_generation) \
			or int(assignment.claim_sequence) != int(payload.claim_sequence):
		return _result(false, &"gunner_not_seated")
	if int(payload.binding_generation) != _generation or int(payload.migration_generation) != _migration \
			or int(_session.get_migration_snapshot().migration_generation) != _migration:
		return _result(false, &"stale_gunner_generation")
	if int(payload.request_sequence) <= int(_requests.get(avatar, 0)):
		return _result(false, &"stale_gunner_sequence")
	if int(payload.target_generation) != int(_ship.get_gunner_gameplay_state().target_generation):
		return _result(false, &"stale_target_generation")
	_requests[avatar] = int(payload.request_sequence)
	# The host builds the aim ray from the exact seated body, never client origin.
	if not body.has_meta(HalyardCrewTransport.HALYARD_CREW_ROLE_OCCUPANT_META):
		body.set_meta(HalyardCrewTransport.HALYARD_CREW_ROLE_OCCUPANT_META, {
			"authority": authority, "avatar_id": avatar, "occupant_peer_id": peer,
			"seat_id": assignment.seat_id, "seat_generation": assignment.seat_generation,
			"role": &"gunner", "frame": frame,
		})
	if payload.trigger and not _ship.request_solo_crew_weapon_power(avatar, seat, body, peer):
		return _result(false, &"gunner_power_unavailable")
	var direction: Vector3 = (_ship.global_basis.orthonormalized() * (payload.aim_local as Vector3)).normalized()

	return _ship.submit_crew_intent(1, peer, avatar, CrewSeatRoleAuthority.ACTION_GUNNER_FIRE, {
		"weapon_id": HalyardCrewTransport.HALYARD_CREW_WEAPON_ID, "target_id": &"free_aim",
		"target_generation": int(payload.target_generation), "trigger": bool(payload.trigger),
		"origin": body.get_interaction_origin(), "direction": direction,
	}, next_request_sequence(int(authority.get_last_intent(peer, avatar).get("request_sequence", 0))))


func _result(accepted: bool, status: StringName) -> Dictionary:
	return {"accepted": accepted, "status": status}


func _physical_crew_seat_matches(seat: ShipCrewSeat) -> bool:
	if is_instance_valid(seat) and _ship is HalyardCrewTransport and seat.get_ship() == _ship and seat.get_role() == &"engineer":
		var contract: Dictionary = _ship.get_engineer_station_role_contract()
		return contract.get("seat") == seat.get_seat_anchor() and contract.get("seat_id") == seat.get_seat_id()
	if is_instance_valid(seat) and _ship is HalyardCrewTransport and seat.get_ship() == _ship and seat.get_role() == &"gunner":
		var contract: Dictionary = _ship.get_gunner_station_role_contract()
		return contract.get("seat") == seat.get_seat_anchor() and contract.get("seat_id") == seat.get_seat_id()
	return _physical_passenger_seat_matches(seat)


func _physical_passenger_seat_matches(seat: ShipCrewSeat) -> bool:
	if not is_instance_valid(seat) or seat.get_ship() != _ship or seat.get_role() != &"passenger":
		return false
	var contract: Dictionary = _ship.get_navigator_station_role_contract() if _ship is CinderCargoHauler and seat.get_seat_id() == CinderCargoHauler.NAVIGATOR_STATION_SEAT_ID else _ship.get_passenger_station_role_contract()
	return not contract.is_empty() and contract.get("seat_id") == seat.get_seat_id() and contract.get("seat") == seat.get_seat_anchor()


func _release_all() -> void:
	if not owns(authority):
		return
	for row in authority.get_snapshot().get("assignments", []):
		if int(row.occupant_peer_id) > 1 and is_instance_valid(_simulation):
			_simulation.stand_crew_body(StringName(row.avatar_id))
		release({"owner_peer_id": row.occupant_peer_id, "entity_id": row.avatar_id})


func detach() -> void:
	_release_all()
	if engineer != null:
		engineer.detach()
		engineer = null
	if _navigator_bridge != null:
		_retire_navigator_publication(&"passenger_binding_detached")
	_navigator_bridge = null
	navigator_submit = Callable()
	navigator_release = Callable()
	_requests.clear()
	_gunner_errors.clear()
	if is_instance_valid(_session) and _session.gunner_intent_requested.is_connected(_submit_gunner):
		_session.gunner_intent_requested.disconnect(_submit_gunner)
	if is_instance_valid(_session) and _session.peer_disconnected.is_connected(_peer_disconnected):
		_session.peer_disconnected.disconnect(_peer_disconnected)
	if owns(authority):
		_ship.detach_crew_role_authority(authority)
	authority = null


func _live() -> bool:
	return owns(authority) and not _ship.is_destroyed() and _ship.is_inside_tree() \
		and is_instance_valid(_session) and _session.is_server() and _session.is_session_active() \
		and is_instance_valid(_simulation)
