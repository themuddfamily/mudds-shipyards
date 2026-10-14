class_name NetworkJovianEngineerBinding
extends RefCounted

## Composes actual engineer chairs with their existing role and repair owners.
## The host body's physical overlap admits the role. Client requests never
## claim occupancy, change integrity, or spend inventory.
const CrewAuthority := preload("res://scripts/ships/crew_seat_role_authority.gd")

var authority: CrewSeatRoleAuthority
var gunner: NetworkBulwarkGunnerBinding
var passenger: NetworkHalyardPassengerBinding
var loadmaster: NetworkHalyardPassengerBinding
var _session: NetworkEnetSessionAdapter
var _ship: HeroShip
var _shared_authority := false
var _simulation: NetworkRemoteBodySimulation
var _generation := 1
var _sequence := 0
var _request_sequences: Dictionary = {}
var _request_peers: Dictionary = {}
var _errors: Dictionary = {}
var _elapsed := 0.0
var _migration := 1
var _component_lifetime := 0
var _retired := false


func attach(session: NetworkEnetSessionAdapter, ship: JovianLightFreighter,
		simulation: NetworkRemoteBodySimulation, generation: int) -> bool:
	if not is_instance_valid(session) or not session.is_server() \
			or not is_instance_valid(ship) or not is_instance_valid(simulation) \
			or ship.get_crew_role_authority() != null:
		return false
	_session = session
	_ship = ship
	_simulation = simulation
	_generation = generation
	_migration = int(session.get_migration_snapshot().migration_generation)
	_component_lifetime = ship.get_component_damage().get_ledger_generation()
	authority = CrewAuthority.new(1)
	if not authority.register_jovian_roster().accepted or not ship.attach_crew_role_authority(authority).accepted:
		authority = null
		return false
	_simulation.crew_seat_claim = claim
	_simulation.crew_seat_release = release
	_session.engineer_intent_requested.connect(submit)
	_session.peer_disconnected.connect(_peer_disconnected)
	return true


## Halyard's passenger binding owns its one roster and physical claim path.
## Reuse this repair provider without attaching a second seat authority.
func attach_shared(session: NetworkEnetSessionAdapter, ship: HalyardCrewTransport,
		simulation: NetworkRemoteBodySimulation, owner: CrewSeatRoleAuthority, generation: int) -> bool:
	if not is_instance_valid(session) or not session.is_server() or not is_instance_valid(ship) \
			or not is_instance_valid(simulation) or owner == null or ship.get_crew_role_authority() != owner:
		return false
	_session = session
	_ship = ship
	_simulation = simulation
	authority = owner
	_shared_authority = true
	_generation = generation
	_migration = int(session.get_migration_snapshot().migration_generation)
	_component_lifetime = ship.get_component_damage().get_ledger_generation()
	return true


func detach() -> void:
	if loadmaster != null:
		loadmaster.detach()
		loadmaster = null
	if passenger != null:
		passenger.detach()
		passenger = null
	if gunner != null:
		gunner.detach()
		gunner = null
	if not _shared_authority and is_instance_valid(_simulation):
		for entity in _simulation.get_body_entity_ids():
			_simulation.stand_crew_body(StringName(entity))
	_release_all_assignments()
	if not _shared_authority and is_instance_valid(_simulation):
		_simulation.crew_seat_claim = Callable()
		_simulation.crew_seat_release = Callable()
	if is_instance_valid(_session) and _session.engineer_intent_requested.is_connected(submit):
		_session.engineer_intent_requested.disconnect(submit)
	if is_instance_valid(_session) and _session.peer_disconnected.is_connected(_peer_disconnected):
		_session.peer_disconnected.disconnect(_peer_disconnected)
	if not _shared_authority and is_instance_valid(_ship) and _ship.get_crew_role_authority() == authority:
		_ship.detach_crew_role_authority(authority)
	authority = null
	_request_sequences.clear()
	_request_peers.clear()
	_errors.clear()


func retire_peer_requests(peer_id: int) -> void:
	for avatar in _request_peers.keys():
		if int(_request_peers[avatar]) == peer_id:
			_request_peers.erase(avatar)
			_request_sequences.erase(avatar)
	_errors.erase(peer_id)


func _peer_disconnected(peer_id: int, _receipt: Dictionary) -> void:
	retire_peer_requests(peer_id)
	if _owns_authority():
		# GameFlow releases the body first. This also handles peer loss during
		# a interrupted acquisition without retaining a dead request cursor.
		authority.release_peer(1, peer_id)


func next_request_sequence(previous: int) -> int:
	_sequence = maxi(_sequence, previous) + 1
	return _sequence


func get_request_sequence_cursor() -> int:
	return _sequence


func claim(record: Dictionary, seat: ShipCrewSeat) -> Dictionary:
	if loadmaster != null and seat.get_ship() is CinderCargoHauler:
		return loadmaster.claim(record, seat)
	if passenger != null and seat.get_ship() is HalyardCrewTransport:
		return passenger.claim(record, seat)
	if gunner != null and seat.get_ship() is BulwarkHeavyGunship:
		return gunner.claim(record, seat)
	if not _live() or not is_instance_valid(seat) or seat.get_ship() != _ship \
			or seat.get_seat_id() != _engineer_seat_id() \
			or seat.get_role_contract().is_empty():
		return _result(false, &"engineer_unavailable")
	var body := record.get("body") as PlayerController
	var frame: MovingInteriorFrame = _ship.get_moving_interior_component()
	var peer_id := int(record.get("owner_peer_id", 0))
	if body == null or peer_id <= 1 or peer_id not in _session.get_admitted_peer_ids() \
			or record.get("craft") != _ship or record.get("frame") != frame \
			or not frame.is_occupant_registered(body) or not body.is_on_floor() \
			or body.get_interaction_origin().distance_to(seat.get_entry_transform().origin) > 3.25 \
			or seat not in body.get_nearby_interactables():
		return _result(false, &"engineer_body_mismatch")
	_sequence += 1
	return authority.claim(1, peer_id, StringName(record.entity_id), seat.get_seat_id(), &"engineer", _sequence)


func release(record: Dictionary) -> void:
	if loadmaster != null:
		loadmaster.release(record)
	if passenger != null:
		passenger.release(record)
	if gunner != null:
		gunner.release(record)
	if not _owns_authority():
		return
	var peer_id := int(record.get("owner_peer_id", 0))
	var avatar := StringName(record.get("entity_id", &""))
	_errors.erase(peer_id)
	_elapsed = 1.0
	var assignment := authority.get_assignment(peer_id, avatar)
	if assignment.is_empty() or assignment.get("role") != &"engineer":
		return
	_sequence = maxi(_sequence, maxi(int(assignment.claim_sequence), int(authority.get_last_intent(peer_id, avatar).get("request_sequence", 0)))) + 1
	_ship.release_crew_role(1, peer_id, avatar, _engineer_seat_id(), _sequence, int(assignment.seat_generation))


func submit(peer_id: int, payload: Dictionary) -> void:
	var provider := _halyard_engineer_for_peer(peer_id)
	if provider != null:
		provider.submit(peer_id, payload)
		return
	var result := dispatch(peer_id, payload)
	_errors[peer_id] = StringName((result.get("effect", {}) as Dictionary).get("status", result.get("status", &"invalid_request"))) if not result.accepted or result.get("consumed", true) == false else &""
	_elapsed = 1.0


func dispatch(peer_id: int, payload: Dictionary) -> Dictionary:
	var provider := _halyard_engineer_for_peer(peer_id)
	if provider != null:
		return provider.dispatch(peer_id, payload)
	if payload.get("action") in [&"cargo_manifest_ready", &"navigator_ping"] and loadmaster != null:
		return loadmaster.submit_readiness(peer_id, payload)
	if not _live() or peer_id not in _session.get_admitted_peer_ids():
		return _result(false, &"session_unavailable")
	var fields := ["avatar_id", "entity_generation", "seat_generation", "claim_sequence", "component_generation", "component_id", "repair", "request_sequence", "binding_generation", "migration_generation", "server_tick"]
	if payload.size() != fields.size():
		return _result(false, &"invalid_engineer_payload")
	for field in fields:
		if not payload.has(field):
			return _result(false, &"invalid_engineer_payload")
	for field in ["entity_generation", "seat_generation", "claim_sequence", "component_generation", "request_sequence", "binding_generation", "migration_generation"]:
		if not payload[field] is int or int(payload[field]) <= 0 or int(payload[field]) > 9007199254740991:
			return _result(false, &"invalid_engineer_generation")
	if not (payload.repair is float or payload.repair is int) or not is_finite(float(payload.repair)) \
			or float(payload.repair) not in [0.0, 0.2]:
		return _result(false, &"invalid_engineer_repair")
	for field in ["avatar_id", "component_id"]:
		if not (payload[field] is String or payload[field] is StringName) \
				or str(payload[field]).length() > 64 or not str(payload[field]).is_valid_identifier():
			return _result(false, &"invalid_engineer_identity")
	if not payload.server_tick is int or int(payload.server_tick) < _session.get_boarding_server_tick() - 120 \
			or int(payload.server_tick) > _session.get_boarding_server_tick() + 12:
		return _result(false, &"stale_engineer_tick")
	var avatar := StringName(payload.avatar_id)
	var record := _simulation.get_body_record(avatar)
	var body := _simulation.get_body(avatar)
	var seat := _simulation.get_body_crew_seat(avatar)
	var assignment := authority.get_assignment(peer_id, avatar)
	var frame: MovingInteriorFrame = _ship.get_moving_interior_component()
	if record.is_empty() or body == null or seat == null or seat.get_ship() != _ship \
			or int(record.owner_peer_id) != peer_id or int(record.entity_generation) != int(payload.entity_generation) \
			or record.seat_state != &"seated" or seat.get_role_contract().is_empty() \
			or seat.get_seat_id() != _engineer_seat_id() \
			or seat.get_seat_anchor() != _ship.call(&"get_engineer_seat_anchor") \
			or not body.is_seated_at(seat.get_seat_anchor()) \
			or not frame.is_occupant_registered(body) or assignment.is_empty() \
			or assignment.role != &"engineer" or int(assignment.seat_generation) != int(payload.seat_generation) \
			or int(assignment.claim_sequence) != int(payload.claim_sequence):
		return _result(false, &"engineer_not_seated")
	if int(payload.binding_generation) != _generation or int(payload.migration_generation) != _migration \
			or int(_session.get_migration_snapshot().migration_generation) != _migration:
		return _result(false, &"stale_engineer_generation")
	if int(payload.request_sequence) <= int(_request_sequences.get(avatar, 0)):
		return _result(false, &"stale_engineer_sequence")
	_request_sequences[avatar] = int(payload.request_sequence)
	_request_peers[avatar] = peer_id
	_sequence = maxi(_sequence, maxi(int(assignment.claim_sequence), int(authority.get_last_intent(peer_id, avatar).get("request_sequence", 0)))) + 1
	return _ship.submit_crew_intent(1, peer_id, avatar, CrewAuthority.ACTION_ENGINEER_REPAIR, {
		"system_id": StringName(payload.component_id), "repair": float(payload.repair),
		"system_generation": int(payload.component_generation),
	}, _sequence)


func advance(delta: float) -> void:
	if loadmaster != null:
		loadmaster.advance(delta)
	if passenger != null:
		passenger.advance(delta)
	if gunner != null:
		gunner.advance(delta)
	if _owns_authority() and _ship.is_destroyed() and not _retired:
		_release_all_assignments()
		_retired = true
		if is_instance_valid(_session) and _session.is_server() and _session.is_session_active():
			for peer_id in _session.get_admitted_peer_ids():
				if not _peer_is_aboard(int(peer_id)):
					continue
				_session.publish_engineer_snapshot(int(peer_id), {
					"ship_id": _ship.get_ship_id(), "binding_generation": _generation,
					"assignment": {}, "seated": false, "entity_generation": 0,
					"gameplay": {}, "components": {}, "error": &"ship_destroyed",
				})
	if not _live():
		return
	for row in authority.get_snapshot().get("assignments", []):
		if int(row.occupant_peer_id) <= 1 or row.role != &"engineer":
			continue
		var avatar := StringName(row.avatar_id)
		var seat := _simulation.get_body_crew_seat(avatar)
		if seat == null or seat.get_role_contract().is_empty():
			_simulation.stand_crew_body(avatar)
			release({"owner_peer_id": int(row.occupant_peer_id), "entity_id": avatar})
	var migration := int(_session.get_migration_snapshot().migration_generation)
	var lifetime := _ship.get_component_damage().get_ledger_generation()
	if migration != _migration or lifetime != _component_lifetime:
		if migration != _migration and not _shared_authority:
			# Preserve the existing global migration recovery, including
			# ordinary bunks and StationSeats outside either crew ledger.
			for entity in _simulation.get_body_entity_ids():
				_simulation.stand_crew_body(StringName(entity))
		else:
			# A Jovian reuse retires only this ledger's bodies, preserving
			# the sibling Bulwark gunner and its weapon demand.
			for row in authority.get_snapshot().get("assignments", []):
				if int(row.occupant_peer_id) > 1 and (not _shared_authority or row.role == &"engineer"):
					_simulation.stand_crew_body(StringName(row.avatar_id))
		_release_all_assignments()
		_migration = migration
		_component_lifetime = lifetime
		_retired = false
		_generation += 1
		_request_sequences.clear()
	_elapsed += delta
	if _elapsed < 0.2:
		return
	_elapsed = 0.0
	var model := _ship.get_component_damage()
	var components := {}
	for component_id in model.COMPONENT_ORDER:
		components[component_id] = model.get_component_integrity(component_id)
	for peer_id in _session.get_admitted_peer_ids():
		# Multiple craft providers share one replica slot. Publish only for a
		# body aboard this craft, including the empty assignment after standing.
		if not _peer_is_aboard(int(peer_id)):
			continue
		var assignment := {}
		for row in authority.get_snapshot().get("assignments", []):
			if int(row.occupant_peer_id) == int(peer_id) and row.role == &"engineer":
				assignment = row.duplicate(true)
		var avatar := StringName(assignment.get("avatar_id", &""))
		var record := _simulation.get_body_record(avatar)
		var seated: bool = not record.is_empty() and record.seat_state == &"seated" \
			and _simulation.get_body_crew_seat(avatar) != null
		_session.publish_engineer_snapshot(int(peer_id), {
			"ship_id": _ship.get_ship_id(), "binding_generation": _generation,
			"assignment": assignment, "seated": seated,
			"entity_generation": int(record.get("entity_generation", 0)),
			"gameplay": _ship.call(&"get_engineer_gameplay_state"), "components": components,
			"error": _errors.get(peer_id, &""),
		})


func _release_all_assignments() -> void:
	if not _owns_authority():
		return
	for row in authority.get_snapshot().get("assignments", []):
		if _shared_authority and row.role != &"engineer":
			continue
		_sequence = maxi(_sequence, maxi(int(row.claim_sequence), int(authority.get_last_intent(int(row.occupant_peer_id), StringName(row.avatar_id)).get("request_sequence", 0)))) + 1
		_ship.release_crew_role(1, int(row.occupant_peer_id), StringName(row.avatar_id), StringName(row.seat_id), _sequence, int(row.seat_generation))


func _owns_authority() -> bool:
	return is_instance_valid(_ship) and authority != null and _ship.get_crew_role_authority() == authority


func _live() -> bool:
	return is_instance_valid(_session) and _session.is_server() and _session.is_session_active() \
		and is_instance_valid(_ship) and _ship.is_inside_tree() and not _ship.is_destroyed() \
		and _ship.get_crew_role_authority() == authority and authority != null \
		and is_instance_valid(_simulation)


func _result(accepted: bool, status: StringName) -> Dictionary:
	return {"accepted": accepted, "status": status}


func owns_role_authority(owner: CrewSeatRoleAuthority) -> bool:
	return owner != null and (owner == authority or (gunner != null and gunner.owns(owner)) or (passenger != null and passenger.owns(owner)) or (loadmaster != null and loadmaster.owns(owner)))

func role_authority_for(craft: HeroShip) -> CrewSeatRoleAuthority:
	return loadmaster.authority if craft is CinderCargoHauler and loadmaster != null else passenger.authority if craft is HalyardCrewTransport and passenger != null else gunner.authority if craft is BulwarkHeavyGunship and gunner != null else authority if craft == _ship else null

func next_role_sequence(owner: CrewSeatRoleAuthority, previous: int) -> int:
	return loadmaster.next_request_sequence(previous) if loadmaster != null and loadmaster.owns(owner) else passenger.next_request_sequence(previous) if passenger != null and passenger.owns(owner) else gunner.next_request_sequence(previous) if gunner != null and gunner.owns(owner) else next_request_sequence(previous)


func _engineer_seat_id() -> StringName:
	return HalyardCrewTransport.ENGINEER_SEAT_ID if _ship is HalyardCrewTransport else JovianLightFreighter.ENGINEER_SEAT_ID


func _peer_is_aboard(peer_id: int) -> bool:
	for entity in _simulation.get_body_entity_ids():
		var record := _simulation.get_body_record(entity)
		var body := _simulation.get_body(entity)
		if int(record.get("owner_peer_id", 0)) == peer_id and body != null \
				and body.get_cabin_containment_report().get("frame") == _ship:
			return true
	return false


func _halyard_engineer_for_peer(peer_id: int) -> NetworkJovianEngineerBinding:
	if passenger != null and passenger.engineer != null and passenger.engineer._peer_is_aboard(peer_id):
		return passenger.engineer
	return null
