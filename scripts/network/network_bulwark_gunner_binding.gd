class_name NetworkBulwarkGunnerBinding
extends RefCounted

## Scoped adapter for the actual Bulwark chair and its existing siege lance.
## The host owns body, role, muzzle, target ray, charge, ammunition and damage.
const CrewAuthority := preload("res://scripts/ships/crew_seat_role_authority.gd")
var authority: CrewSeatRoleAuthority
var _session: NetworkEnetSessionAdapter
var _ship: BulwarkHeavyGunship
var _simulation: NetworkRemoteBodySimulation
var _combat: LiveCombatAuthority
var _generation := 1
var _migration := 1
var _lifetime := 0
var _sequence := 0
var _requests: Dictionary = {}
var _errors: Dictionary = {}
var _elapsed := 0.0
var _retired := false

func attach(session: NetworkEnetSessionAdapter, ship: BulwarkHeavyGunship,
		simulation: NetworkRemoteBodySimulation, combat: LiveCombatAuthority, generation: int) -> bool:
	if not is_instance_valid(session) or not session.is_server() or not is_instance_valid(ship) \
			or not is_instance_valid(simulation) or not is_instance_valid(combat) or ship.get_crew_role_authority() != null:
		return false
	var owner := CrewAuthority.new(1)
	if not owner.register_bulwark_roster().accepted or not ship.attach_crew_role_authority(owner).accepted:
		return false
	if not ship.attach_gunner_combat_authority(combat).accepted:
		ship.detach_crew_role_authority(owner)
		return false
	authority = owner
	_session = session
	_ship = ship
	_simulation = simulation
	_combat = combat
	_generation = generation
	_migration = int(session.get_migration_snapshot().migration_generation)
	_lifetime = ship.get_component_damage().get_ledger_generation()
	_session.gunner_intent_requested.connect(submit)
	_session.peer_disconnected.connect(_peer_disconnected)
	return true

func owns(owner: CrewSeatRoleAuthority) -> bool:
	return owner != null and owner == authority and is_instance_valid(_ship) and _ship.get_crew_role_authority() == owner

func next_request_sequence(previous: int) -> int:
	_sequence = maxi(_sequence, previous) + 1
	return _sequence

func claim(record: Dictionary, seat: ShipCrewSeat) -> Dictionary:
	if not _live() or seat.get_ship() != _ship or seat.get_seat_id() != BulwarkHeavyGunship.GUNNER_SEAT_ID \
			or seat.get_role() != &"gunner" or seat.get_role_contract().is_empty():
		return _result(false, &"gunner_unavailable")
	var body := record.get("body") as PlayerController
	var peer := int(record.get("owner_peer_id", 0))
	var frame := _ship.get_moving_interior_component()
	if body == null or peer <= 1 or peer not in _session.get_admitted_peer_ids() \
			or record.get("craft") != _ship or record.get("frame") != frame \
			or not frame.is_occupant_registered(body) or not body.is_on_floor() \
			or body.get_interaction_origin().distance_to(seat.get_entry_transform().origin) > 3.25 \
			or seat not in body.get_nearby_interactables():
		return _result(false, &"gunner_body_mismatch")
	return authority.claim(1, peer, StringName(record.entity_id), seat.get_seat_id(), &"gunner", next_request_sequence(0))

func release(record: Dictionary) -> void:
	if not owns(authority):
		return
	var peer := int(record.get("owner_peer_id", 0))
	var avatar := StringName(record.get("entity_id", &""))
	var assignment := authority.get_assignment(peer, avatar)
	if assignment.is_empty():
		return
	_ship.release_crew_role(1, peer, avatar, StringName(assignment.seat_id),
		next_request_sequence(int(authority.get_last_intent(peer, avatar).get("request_sequence", 0))), int(assignment.seat_generation))
	var body := record.get("body") as PlayerController
	if not is_instance_valid(body):
		body = _simulation.get_body(avatar) as PlayerController
	if is_instance_valid(body):
		var tag := body.get_meta(HeroShip.SOLO_CREW_ROLE_OCCUPANT_META, {}) as Dictionary
		if tag.get("craft") == _ship and tag.get("authority") == authority and tag.get("avatar_id") == avatar \
				and int(tag.get("occupant_peer_id", 0)) == peer \
				and int(tag.get("seat_generation", 0)) == int(assignment.seat_generation):
			if bool(tag.get("weapon_power_started", false)) and owns(authority) and not _ship.is_piloted():
				_ship.request_engine_stop()
			body.remove_meta(HeroShip.SOLO_CREW_ROLE_OCCUPANT_META)
	_requests.erase(avatar)
	_errors.erase(peer)
	_elapsed = 1.0

func submit(peer: int, payload: Dictionary) -> void:
	var result := dispatch(peer, payload)
	_errors[peer] = StringName((result.get("effect", {}) as Dictionary).get("status", result.get("status", &"invalid_request"))) if not result.accepted or result.get("consumed", true) == false else &""
	_elapsed = 1.0

func dispatch(peer: int, payload: Dictionary) -> Dictionary:
	if not _live() or peer not in _session.get_admitted_peer_ids():
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
	var frame := _ship.get_moving_interior_component()
	if record.is_empty() or body == null or seat == null or seat.get_ship() != _ship \
			or int(record.owner_peer_id) != peer or int(record.entity_generation) != int(payload.entity_generation) \
			or record.seat_state != &"seated" or seat.get_role_contract().is_empty() \
			or seat.get_seat_anchor() != _ship.get_gunner_station_anchor() \
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
	_requests[avatar] = int(payload.request_sequence)
	if int(payload.target_generation) != int(_ship.get_gunner_gameplay_state().target_generation):
		return _result(false, &"stale_target_generation")
	# The tag carries the same exact role owner used by solo cleanup; power
	# wakes only on admitted physical demand and keeps the dock latch intact.
	var tag := body.get_meta(HeroShip.SOLO_CREW_ROLE_OCCUPANT_META, {}) as Dictionary
	if tag.is_empty():
		body.set_meta(HeroShip.SOLO_CREW_ROLE_OCCUPANT_META, {
			"craft": _ship, "authority": authority, "avatar_id": avatar, "occupant_peer_id": peer,
			"seat_id": assignment.seat_id, "seat_generation": assignment.seat_generation, "role": &"gunner", "frame": frame,
		})
	if payload.trigger and not _ship.request_solo_crew_weapon_power(avatar, seat, body, peer):
		return _result(false, &"gunner_power_unavailable")
	var muzzle := _ship.get_node_or_null("LeftMuzzle") as Marker3D
	var profile := _combat.get_weapon_profile(_ship, BulwarkHeavyGunship.BULWARK_CREW_WEAPON_ID)
	if muzzle == null or float(profile.get("range", 0.0)) <= 0.0:
		return _result(false, &"gunner_weapon_unavailable")
	var direction: Vector3 = (_ship.global_basis.orthonormalized() * (payload.aim_local as Vector3)).normalized()
	var eye: Vector3 = body.get_interaction_origin()
	var endpoint: Vector3 = eye + direction * float(profile.range)
	var exclusions: Array[RID] = [body.get_rid(), _ship.get_rid()]
	for child in _ship.find_children("*", "CollisionObject3D", true, false):
		exclusions.append((child as CollisionObject3D).get_rid())
	var query := PhysicsRayQueryParameters3D.create(eye, endpoint, PhysicsLayers.HITSCAN_QUERY_MASK, exclusions)
	query.collide_with_areas = true
	var hit := body.get_world_3d().direct_space_state.intersect_ray(query)
	var collider := hit.get("collider") as Node
	var target: StringName = &"free_aim"
	if is_instance_valid(collider):
		endpoint = hit.get("position", endpoint)
		target = StringName("sight_%d" % collider.get_instance_id())
		var published: Variant = (collider as HeroShip).get_ship_id() if collider is HeroShip else collider.get_meta(&"target_id", &"")
		if (published is String or published is StringName) and not str(published).is_empty() and str(published).length() <= 64:
			target = StringName(published)
	return _ship.submit_crew_intent(1, peer, avatar, CrewAuthority.ACTION_GUNNER_FIRE, {
		"weapon_id": BulwarkHeavyGunship.BULWARK_CREW_WEAPON_ID, "target_id": target,
		"target_generation": int(payload.target_generation), "trigger": bool(payload.trigger),
		"origin": muzzle.global_position, "direction": (endpoint - muzzle.global_position).normalized(),
	}, next_request_sequence(int(authority.get_last_intent(peer, avatar).get("request_sequence", 0))))

func advance(delta: float) -> void:
	if not owns(authority):
		return
	var migration := int(_session.get_migration_snapshot().migration_generation)
	var lifetime := _ship.get_component_damage().get_ledger_generation()
	if _ship.is_destroyed() or migration != _migration or lifetime != _lifetime:
		_release_all()
		if not _retired or migration != _migration or lifetime != _lifetime:
			_generation += 1
		_retired = _ship.is_destroyed()
		_migration = migration
		_lifetime = lifetime
		_requests.clear()
	for row in authority.get_snapshot().get("assignments", []):
		if int(row.occupant_peer_id) <= 1:
			continue
		var seat := _simulation.get_body_crew_seat(StringName(row.avatar_id))
		if seat == null or seat.get_role_contract().is_empty():
			_simulation.stand_crew_body(StringName(row.avatar_id))
			release({"owner_peer_id": int(row.occupant_peer_id), "entity_id": StringName(row.avatar_id)})
	_elapsed += delta
	if _elapsed < 0.2 or not _session.is_session_active():
		return
	_elapsed = 0.0
	for peer in _session.get_admitted_peer_ids():
		var assignment := {}
		for row in authority.get_snapshot().get("assignments", []):
			if int(row.occupant_peer_id) == int(peer) and row.role == &"gunner":
				assignment = row.duplicate(true)
		var record := _simulation.get_body_record(StringName(assignment.get("avatar_id", &"")))
		_session.publish_gunner_snapshot(int(peer), {
			"ship_id": _ship.get_ship_id(), "binding_generation": _generation, "assignment": assignment,
			"entity_generation": int(record.get("entity_generation", 0)),
			"seated": not record.is_empty() and record.get("seat_state") == &"seated",
			"gameplay": _ship.get_gunner_gameplay_state(), "error": &"ship_destroyed" if _retired else _errors.get(peer, &""),
		})

func _peer_disconnected(peer: int, _receipt: Dictionary) -> void:
	if owns(authority):
		for row in authority.get_snapshot().get("assignments", []):
			if int(row.occupant_peer_id) == peer:
				release({"owner_peer_id": peer, "entity_id": StringName(row.avatar_id)})
	_errors.erase(peer)

func _release_all() -> void:
	if not owns(authority):
		return
	for row in authority.get_snapshot().get("assignments", []):
		if int(row.occupant_peer_id) > 1:
			_simulation.stand_crew_body(StringName(row.avatar_id))
		# The host's ordinary solo chair borrows this same ledger. Retire
		# its assignment too; Main then releases its exact physical tag.
		release({"owner_peer_id": int(row.occupant_peer_id), "entity_id": StringName(row.avatar_id)})

func detach() -> void:
	_release_all()
	if is_instance_valid(_session):
		if _session.gunner_intent_requested.is_connected(submit):
			_session.gunner_intent_requested.disconnect(submit)
		if _session.peer_disconnected.is_connected(_peer_disconnected):
			_session.peer_disconnected.disconnect(_peer_disconnected)
	if owns(authority):
		_ship.detach_crew_role_authority(authority)
	authority = null
	_requests.clear()
	_errors.clear()

func _live() -> bool:
	return owns(authority) and is_instance_valid(_session) and _session.is_server() \
		and _session.is_session_active() and _ship.is_inside_tree() and not _ship.is_destroyed() \
		and is_instance_valid(_simulation)

func _result(accepted: bool, status: StringName) -> Dictionary:
	return {"accepted": accepted, "status": status}
