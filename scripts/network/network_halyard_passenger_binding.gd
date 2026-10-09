class_name NetworkHalyardPassengerBinding
extends RefCounted

## One authored chair, admitted through the server's existing walking body.
## A cabin berth admits entry; only supported overlap grants this physical role.
var authority: CrewSeatRoleAuthority
var _session: NetworkEnetSessionAdapter
var _ship: HalyardCrewTransport
var _simulation: NetworkRemoteBodySimulation
var _sequence := 0
var _generation := 1
var _migration := 1
var _lifetime := 0
var _elapsed := 0.0
var _retired := false


func attach(session: NetworkEnetSessionAdapter, ship: HalyardCrewTransport,
		simulation: NetworkRemoteBodySimulation, generation: int) -> bool:
	if not is_instance_valid(session) or not session.is_server() or not is_instance_valid(ship) \
			or not is_instance_valid(simulation) or ship.get_crew_role_authority() != null:
		return false
	var owner := CrewSeatRoleAuthority.new(1)
	if not owner.register_halyard_roster().accepted or not ship.attach_crew_role_authority(owner).accepted:
		return false
	authority = owner
	_session = session
	_ship = ship
	_simulation = simulation
	_generation = generation
	_migration = int(session.get_migration_snapshot().migration_generation)
	_lifetime = ship.get_component_damage().get_ledger_generation()
	_session.peer_disconnected.connect(_peer_disconnected)
	return true


func owns(owner: CrewSeatRoleAuthority) -> bool:
	return owner != null and owner == authority and is_instance_valid(_ship) and _ship.get_crew_role_authority() == owner


func next_request_sequence(previous: int) -> int:
	_sequence = maxi(_sequence, previous) + 1
	return _sequence


func claim(record: Dictionary, seat: ShipCrewSeat) -> Dictionary:
	if not _live() or not is_instance_valid(seat) or seat.get_ship() != _ship \
			or seat.get_role() != &"passenger" or seat.get_seat_id() != HalyardCrewTransport.LOADMASTER_STATION_SEAT_ID \
			or seat.get_role_contract().is_empty():
		return {"accepted": false, "status": &"passenger_unavailable"}
	var body := record.get("body") as PlayerController
	var peer := int(record.get("owner_peer_id", 0))
	var frame := _ship.get_moving_interior_component()
	var avatar := StringName(record.get("entity_id", &""))
	if body == null or peer <= 1 or peer not in _session.get_admitted_peer_ids() \
			or _simulation.get_body(avatar) != body \
			or int(_simulation.get_body_record(avatar).get("owner_peer_id", 0)) != peer \
			or record.get("craft") != _ship or record.get("frame") != frame \
			or not frame.is_occupant_registered(body) or not body.is_on_floor() \
			or body.get_interaction_origin().distance_to(seat.get_entry_transform().origin) > 3.25 \
			or seat not in body.get_nearby_interactables():
		return {"accepted": false, "status": &"passenger_body_mismatch"}
	return authority.claim(1, peer, avatar, seat.get_seat_id(), &"passenger", next_request_sequence(0))


func release(record: Dictionary) -> void:
	if not owns(authority):
		return
	var peer := int(record.get("owner_peer_id", 0))
	var avatar := StringName(record.get("entity_id", &""))
	var assignment := authority.get_assignment(peer, avatar)
	if not assignment.is_empty():
		_ship.release_crew_role(1, peer, avatar, StringName(assignment.seat_id),
			next_request_sequence(int(authority.get_last_intent(peer, avatar).get("request_sequence", 0))), int(assignment.seat_generation))
	_elapsed = 1.0


func _peer_disconnected(peer: int, _receipt: Dictionary) -> void:
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
		_migration = migration
		_lifetime = lifetime
		_generation += 1
		_retired = _ship.is_destroyed()
		_elapsed = 1.0
	if _live():
		for row in authority.get_snapshot().get("assignments", []):
			if int(row.occupant_peer_id) <= 1 or row.role != &"passenger":
				continue
			var avatar := StringName(row.avatar_id)
			var seat := _simulation.get_body_crew_seat(avatar)
			if seat == null or seat.get_role_contract().is_empty():
				_simulation.stand_crew_body(avatar)
				release({"owner_peer_id": row.occupant_peer_id, "entity_id": avatar})
	_elapsed += delta
	if _elapsed < 0.2:
		return
	_elapsed = 0.0
	for peer in _session.get_admitted_peer_ids():
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
			"seated": _live() and body != null and not record.is_empty() and record.get("seat_state") == &"seated"
				and body.is_seated_at(_ship.get_loadmaster_station_anchor()),
		})


func _release_all() -> void:
	if not owns(authority):
		return
	for row in authority.get_snapshot().get("assignments", []):
		if int(row.occupant_peer_id) > 1 and is_instance_valid(_simulation):
			_simulation.stand_crew_body(StringName(row.avatar_id))
		release({"owner_peer_id": row.occupant_peer_id, "entity_id": row.avatar_id})


func detach() -> void:
	_release_all()
	if is_instance_valid(_session) and _session.peer_disconnected.is_connected(_peer_disconnected):
		_session.peer_disconnected.disconnect(_peer_disconnected)
	if owns(authority):
		_ship.detach_crew_role_authority(authority)
	authority = null


func _live() -> bool:
	return owns(authority) and not _ship.is_destroyed() and _ship.is_inside_tree() \
		and is_instance_valid(_session) and _session.is_server() and _session.is_session_active() \
		and is_instance_valid(_simulation)
