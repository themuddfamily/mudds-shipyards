class_name CrewSeatRoleAuthority
extends RefCounted

const RoleProfile := preload("res://scripts/fleet/crew_role_gameplay_profile.gd")

## Runtime seat/role authority for a multi-crew ship.
##
## This is the production seam between a ship's physical seat markers and a
## future session coordinator. It owns only the authoritative seat assignment
## and role capability ledger. MovingInteriorFrame continues to own occupant
## registration and movement truth; ship/combat/landing authorities continue to
## own their respective state. A client can request a role, but only the server
## peer can commit it.

const SCHEMA_VERSION := 1
const POLICY_VERSION: StringName = &"crew_seat_role_authority_v1"
const MAX_SAFE_INTEGER := 9_007_199_254_740_991
const MAX_ID_LENGTH := 64

const ROLE_PILOT: StringName = RoleProfile.ROLE_PILOT
const ROLE_GUNNER: StringName = RoleProfile.ROLE_GUNNER
const ROLE_PASSENGER: StringName = RoleProfile.ROLE_PASSENGER
const ROLE_ENGINEER: StringName = RoleProfile.ROLE_ENGINEER
const ROLES := RoleProfile.ROLES

const CAPABILITY_SHIP_COMMAND: StringName = RoleProfile.CAPABILITY_SHIP_COMMAND
const CAPABILITY_WEAPON_CONTROL: StringName = RoleProfile.CAPABILITY_WEAPON_CONTROL
const CAPABILITY_SYSTEMS_CONTROL: StringName = RoleProfile.CAPABILITY_SYSTEMS_CONTROL
const CAPABILITY_PASSENGER_ACCESS: StringName = RoleProfile.CAPABILITY_PASSENGER_ACCESS

const ACTION_FLIGHT_COMMAND: StringName = RoleProfile.ACTION_FLIGHT_COMMAND
const ACTION_GUNNER_FIRE: StringName = RoleProfile.ACTION_GUNNER_FIRE
const ACTION_ENGINEER_REPAIR: StringName = RoleProfile.ACTION_ENGINEER_REPAIR
const ACTION_PASSENGER_PING: StringName = RoleProfile.ACTION_PASSENGER_PING

const ROLE_CAPABILITIES := RoleProfile.ROLE_CAPABILITIES

const FORBIDDEN_DIRECT_CAPABILITIES := [
	&"movement_truth",
	&"damage_resolution",
	&"landing_lease",
	&"occupancy_mutation",
	&"respawn",
]

var _authority_peer_id := 1
var _roster_sealed := false
var _seats: Dictionary = {}
var _assignments: Dictionary = {}
var _last_request_sequence_by_peer: Dictionary = {}
var _last_intents: Dictionary = {}
var _event_sequence := 0
var _last_result: Dictionary = {}


func _init(authority_peer_id: int = 1) -> void:
	_authority_peer_id = authority_peer_id
	_last_result = _result(false, &"uninitialized")


## Stable Halyard layout: one pilot, one gunner at the second flight-deck
## station, one engineer, and five passenger seats. The returned records name
## the physical marker contracts already published by HalyardCrewTransport;
## this method does not instantiate nodes or mutate the ship.
static func get_halyard_roster() -> Array:
	return [
		_seat_record(&"pilot_station", &"pilot_seat_anchor", ROLE_PILOT),
		_seat_record(&"co_pilot_station", &"co_pilot_station_anchor", ROLE_GUNNER),
		_seat_record(&"crew_port_00", &"crew_seat_anchor", ROLE_PASSENGER),
		_seat_record(&"crew_starboard_00", &"crew_seat_anchor", ROLE_PASSENGER),
		_seat_record(&"crew_port_01", &"crew_seat_anchor", ROLE_ENGINEER),
		_seat_record(&"crew_starboard_01", &"crew_seat_anchor", ROLE_PASSENGER),
		_seat_record(&"crew_port_02", &"crew_seat_anchor", ROLE_PASSENGER),
		_seat_record(&"crew_starboard_02", &"crew_seat_anchor", ROLE_PASSENGER),
	]


## Register the published Halyard markers before the session accepts claims.
func register_halyard_roster(
		vessel_id: StringName = &"halyard_new_design",
		frame_id: StringName = &"halyard_walkable_interior",
		seat_generation: int = 1
) -> Dictionary:
	if _roster_sealed:
		return _remember(_result(false, &"roster_sealed"))
	if not _valid_id(vessel_id) or not _valid_id(frame_id):
		return _remember(_result(false, &"invalid_frame_identity"))
	if not _valid_positive_integer(seat_generation):
		return _remember(_result(false, &"invalid_seat_generation"))
	for record_variant in get_halyard_roster():
		var record := record_variant as Dictionary
		var registered := register_seat(
			StringName(record.seat_id),
			vessel_id,
			StringName(record.role),
			frame_id,
			seat_generation,
			StringName(record.anchor_id)
		)
		if not bool(registered.get("accepted", false)):
			return registered
	return seal_roster()


## The ship/session coordinator owns the roster boundary. Once sealed, a late
## or duplicate marker cannot silently become an authoritative seat.
func seal_roster() -> Dictionary:
	if _roster_sealed:
		return _remember(_result(false, &"roster_already_sealed"))
	if _seats.is_empty():
		return _remember(_result(false, &"empty_roster"))
	for role: StringName in ROLES:
		if not _has_role(role):
			return _remember(_result(false, &"roster_missing_role", {"role": role}))
	_roster_sealed = true
	_event_sequence += 1
	return _remember(_result(true, &"roster_sealed"))


## Registers one physical marker. Registration is configuration, not occupancy;
## no client/source peer is accepted here and registration is frozen on seal.
func register_seat(
		seat_id: StringName,
		vessel_id: StringName,
		role: StringName,
		frame_id: StringName = &"",
		seat_generation: int = 1,
		anchor_id: StringName = &""
) -> Dictionary:
	if _roster_sealed:
		return _remember(_result(false, &"roster_sealed"))
	if not _valid_id(seat_id) or not _valid_id(vessel_id):
		return _remember(_result(false, &"invalid_seat_identity"))
	if not _valid_role(role):
		return _remember(_result(false, &"invalid_role"))
	if not _valid_id_or_empty(frame_id) or not _valid_id_or_empty(anchor_id):
		return _remember(_result(false, &"invalid_frame_identity"))
	if not _valid_positive_integer(seat_generation):
		return _remember(_result(false, &"invalid_seat_generation"))
	if _seats.has(seat_id):
		return _remember(_result(false, &"duplicate_seat"))
	_seats[seat_id] = {
		"seat_id": seat_id,
		"vessel_id": vessel_id,
		"role": role,
		"frame_id": frame_id,
		"anchor_id": anchor_id,
		"seat_generation": seat_generation,
		"capabilities": (ROLE_CAPABILITIES[role] as Array).duplicate(),
	}
	return _remember(_result(true, &"registered", {"seat": _seats[seat_id]}))


## Atomically claim a seat. Invalid requests never advance the peer sequence or
## event sequence, so retries and malicious requests cannot consume lifecycle.
func claim(
		source_peer_id: int,
		occupant_peer_id: int,
		avatar_id: StringName,
		seat_id: StringName,
		requested_role: StringName,
		request_sequence: int
) -> Dictionary:
	var request_status := _validate_request(source_peer_id, occupant_peer_id, avatar_id, request_sequence)
	if not request_status.is_empty():
		return _remember(_result(false, request_status))
	if not _roster_sealed:
		return _remember(_result(false, &"roster_not_sealed"))
	if not _seats.has(seat_id):
		return _remember(_result(false, &"unknown_seat"))
	var seat := _seats[seat_id] as Dictionary
	if requested_role != StringName(seat.role):
		return _remember(_result(false, &"role_mismatch"))
	var key := _assignment_key(occupant_peer_id, avatar_id)
	if _assignments.has(key):
		return _remember(_result(false, &"avatar_already_seated"))
	for assignment_variant in _assignments.values():
		var assignment := assignment_variant as Dictionary
		if StringName(assignment.get("seat_id", &"")) == seat_id:
			return _remember(_result(false, &"seat_occupied"))
	_last_request_sequence_by_peer[occupant_peer_id] = request_sequence
	_assignments[key] = {
		"occupant_peer_id": occupant_peer_id,
		"avatar_id": avatar_id,
		"seat_id": seat_id,
		"vessel_id": seat.vessel_id,
		"role": seat.role,
		"frame_id": seat.frame_id,
		"anchor_id": seat.anchor_id,
		"seat_generation": int(seat.seat_generation),
		"claim_sequence": request_sequence,
	}
	_event_sequence += 1
	return _remember(_result(true, &"claimed", {"assignment": _assignments[key]}))


## Release is accepted once for the current assignment and generation. A late
## release cannot clear a reused physical seat.
func release(
		source_peer_id: int,
		occupant_peer_id: int,
		avatar_id: StringName,
		seat_id: StringName,
		request_sequence: int,
		seat_generation: int = 0
) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	if occupant_peer_id <= 0 or not _valid_id(avatar_id) or not _valid_nonnegative_integer(request_sequence):
		return _remember(_result(false, &"invalid_release_request"))
	var key := _assignment_key(occupant_peer_id, avatar_id)
	if not _assignments.has(key):
		return _remember(_result(false, &"assignment_not_found"))
	var assignment := _assignments[key] as Dictionary
	if StringName(assignment.get("seat_id", &"")) != seat_id:
		return _remember(_result(false, &"seat_mismatch"))
	if seat_generation > 0 and int(assignment.get("seat_generation", 0)) != seat_generation:
		return _remember(_result(false, &"stale_seat_generation"))
	if not _accept_sequence(occupant_peer_id, request_sequence):
		return _remember(_result(false, &"stale_request_sequence"))
	_assignments.erase(key)
	_last_intents.erase(key)
	_last_request_sequence_by_peer[occupant_peer_id] = request_sequence
	_event_sequence += 1
	return _remember(_result(true, &"released", {"assignment": assignment}))


## Server lifecycle cleanup is one logical event even when a peer occupied more
## than one role. Every removed assignment is returned for frame cleanup.
func release_peer(source_peer_id: int, occupant_peer_id: int) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	if occupant_peer_id <= 0:
		return _remember(_result(false, &"invalid_peer_id"))
	var removed: Array = []
	for key_variant in _assignments.keys():
		var key := StringName(key_variant)
		var assignment := _assignments[key] as Dictionary
		if int(assignment.get("occupant_peer_id", 0)) == occupant_peer_id:
			removed.append(assignment.duplicate(true))
			_assignments.erase(key)
			_last_intents.erase(key)
	if not removed.is_empty():
		removed.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
			return str(left.get("seat_id", "")) < str(right.get("seat_id", ""))
		)
		_event_sequence += 1
	_last_request_sequence_by_peer.erase(occupant_peer_id)
	return _remember(_result(true, &"peer_released", {"assignments": removed}))


## Atomically hands one physical seat from its current occupant to a newly
## admitted avatar. The seat ledger, intent receipt, and both peer sequence
## cursors move in one server-owned event; no caller can observe a free-seat
## window or make the new avatar inherit the old avatar's intent receipt.
func handoff(
		source_peer_id: int,
		previous_occupant_peer_id: int,
		previous_avatar_id: StringName,
		seat_id: StringName,
		release_request_sequence: int,
		new_occupant_peer_id: int,
		new_avatar_id: StringName,
		requested_role: StringName,
		claim_request_sequence: int,
		seat_generation: int = 0
) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	if previous_occupant_peer_id <= 0 or new_occupant_peer_id <= 0 \
			or not _valid_id(previous_avatar_id) or not _valid_id(new_avatar_id):
		return _remember(_result(false, &"invalid_handoff_request"))
	if not _valid_nonnegative_integer(release_request_sequence) \
			or not _valid_nonnegative_integer(claim_request_sequence):
		return _remember(_result(false, &"invalid_handoff_sequence"))
	if not _roster_sealed:
		return _remember(_result(false, &"roster_not_sealed"))
	if not _seats.has(seat_id):
		return _remember(_result(false, &"unknown_seat"))
	var seat := _seats[seat_id] as Dictionary
	if StringName(seat.get("role", &"")) != requested_role:
		return _remember(_result(false, &"role_mismatch"))
	var previous_key := _assignment_key(previous_occupant_peer_id, previous_avatar_id)
	if not _assignments.has(previous_key):
		return _remember(_result(false, &"assignment_not_found"))
	var previous_assignment := _assignments[previous_key] as Dictionary
	if StringName(previous_assignment.get("seat_id", &"")) != seat_id:
		return _remember(_result(false, &"seat_mismatch"))
	if seat_generation > 0 and int(previous_assignment.get("seat_generation", 0)) != seat_generation:
		return _remember(_result(false, &"stale_seat_generation"))
	var new_key := _assignment_key(new_occupant_peer_id, new_avatar_id)
	if _assignments.has(new_key):
		return _remember(_result(false, &"avatar_already_seated"))
	if not _accept_sequence(previous_occupant_peer_id, release_request_sequence):
		return _remember(_result(false, &"stale_request_sequence"))
	if not _accept_sequence(new_occupant_peer_id, claim_request_sequence):
		return _remember(_result(false, &"stale_request_sequence"))
	_assignments.erase(previous_key)
	_last_intents.erase(previous_key)
	var assignment := {
		"occupant_peer_id": new_occupant_peer_id,
		"avatar_id": new_avatar_id,
		"seat_id": seat.seat_id,
		"vessel_id": seat.vessel_id,
		"role": seat.role,
		"frame_id": seat.frame_id,
		"anchor_id": seat.anchor_id,
		"seat_generation": int(seat.seat_generation),
		"claim_sequence": claim_request_sequence,
	}
	_assignments[new_key] = assignment
	_last_request_sequence_by_peer[previous_occupant_peer_id] = release_request_sequence
	_last_request_sequence_by_peer[new_occupant_peer_id] = claim_request_sequence
	_event_sequence += 1
	return _remember(_result(true, &"role_handoff", {
		"previous_assignment": previous_assignment,
		"assignment": assignment,
	}))


## Authorizes a role capability without granting movement, damage, landing, or
## occupancy authority. This is intentionally a pure read of the ledger.
func authorize_action(
		occupant_peer_id: int,
		avatar_id: StringName,
		capability: StringName
) -> Dictionary:
	if occupant_peer_id <= 0 or not _valid_id(avatar_id):
		return _result(false, &"invalid_actor")
	var assignment := get_assignment(occupant_peer_id, avatar_id)
	if assignment.is_empty():
		return _result(false, &"assignment_not_found")
	var role := StringName(assignment.get("role", &""))
	var capabilities: Array = ROLE_CAPABILITIES.get(role, []) as Array
	if not capabilities.has(capability):
		return _result(false, &"capability_denied", {"role": role, "capability": capability})
	return _result(true, &"capability_authorized", {"role": role, "capability": capability})


## Accepts one role-specific gameplay intent. The server owns admission and
## sequencing; the returned normalized receipt is consumed by the downstream
## ship, combat, repair, or presentation authority. This method never mutates
## movement, damage, landing, or occupancy state.
func submit_intent(
		source_peer_id: int,
		occupant_peer_id: int,
		avatar_id: StringName,
		action: StringName,
		payload: Dictionary,
		request_sequence: int
) -> Dictionary:
	var request_status := _validate_request(source_peer_id, occupant_peer_id, avatar_id, request_sequence)
	if not request_status.is_empty():
		return _remember(_result(false, request_status))
	var key := _assignment_key(occupant_peer_id, avatar_id)
	if not _assignments.has(key):
		return _remember(_result(false, &"assignment_not_found"))
	var assignment := _assignments[key] as Dictionary
	var role := StringName(assignment.get("role", &""))
	var validation: Dictionary = RoleProfile.validate_intent(role, action, payload)
	if not bool(validation.get("accepted", false)):
		return _remember(_result(false, validation.get("status", &"invalid_intent")))
	var normalized_payload: Dictionary = validation.get("payload", {}) as Dictionary
	_last_request_sequence_by_peer[occupant_peer_id] = request_sequence
	var intent := {
		"occupant_peer_id": occupant_peer_id,
		"avatar_id": avatar_id,
		"seat_id": assignment.seat_id,
		"vessel_id": assignment.vessel_id,
		"role": role,
		"action": action,
		"channel": RoleProfile.get_role_profile(role).get("channel", &""),
		"payload": normalized_payload,
		"request_sequence": request_sequence,
		"seat_generation": int(assignment.seat_generation),
	}
	_last_intents[key] = intent
	_event_sequence += 1
	return _remember(_result(true, &"intent_accepted", {"intent": intent}))


func get_last_intent(occupant_peer_id: int, avatar_id: StringName) -> Dictionary:
	return (_last_intents.get(_assignment_key(occupant_peer_id, avatar_id), {}) as Dictionary).duplicate(true)


func get_assignment(occupant_peer_id: int, avatar_id: StringName) -> Dictionary:
	var assignment: Variant = _assignments.get(_assignment_key(occupant_peer_id, avatar_id), {})
	return (assignment as Dictionary).duplicate(true)


func get_snapshot() -> Dictionary:
	var seats: Array = []
	for seat_variant in _seats.values():
		seats.append((seat_variant as Dictionary).duplicate(true))
	seats.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return str(left.get("seat_id", "")) < str(right.get("seat_id", ""))
	)
	var assignments: Array = []
	for assignment_variant in _assignments.values():
		assignments.append((assignment_variant as Dictionary).duplicate(true))
	assignments.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return str(left.get("seat_id", "")) < str(right.get("seat_id", ""))
	)
	var intents: Array = []
	for intent_variant in _last_intents.values():
		intents.append((intent_variant as Dictionary).duplicate(true))
	intents.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return str(left.get("seat_id", "")) < str(right.get("seat_id", ""))
	)
	return {
		"schema_version": SCHEMA_VERSION,
		"policy_version": POLICY_VERSION,
		"authority_peer_id": _authority_peer_id,
		"roster_sealed": _roster_sealed,
		"event_sequence": _event_sequence,
		"seats": seats,
		"assignments": assignments,
		"intents": intents,
	}.duplicate(true)


func audit() -> Dictionary:
	var role_counts := {}
	for role: StringName in ROLES:
		role_counts[role] = 0
	for seat_variant in _seats.values():
		var role := StringName((seat_variant as Dictionary).get("role", &""))
		role_counts[role] = int(role_counts.get(role, 0)) + 1
	return {
		"schema_version": SCHEMA_VERSION,
		"policy_version": POLICY_VERSION,
		"valid": _authority_peer_id > 0 and not _seats.is_empty(),
		"authority_peer_id": _authority_peer_id,
		"roster_sealed": _roster_sealed,
		"registered_seat_count": _seats.size(),
		"occupied_seat_count": _assignments.size(),
		"role_counts": role_counts,
		"server_owns_seat_reservation": true,
		"server_owns_role_assignment": true,
		"server_owns_role_intent_admission": true,
		"client_can_mutate_ledger": false,
		"owns_movement": false,
		"owns_ship_simulation": false,
		"owns_damage_or_landing": false,
		"owns_occupancy": false,
		"forbidden_direct_capabilities": FORBIDDEN_DIRECT_CAPABILITIES.duplicate(),
	}.duplicate(true)


func get_last_result() -> Dictionary:
	return _last_result.duplicate(true)


static func _seat_record(seat_id: StringName, anchor_id: StringName, role: StringName) -> Dictionary:
	return {"seat_id": seat_id, "anchor_id": anchor_id, "role": role}


func _validate_request(
		source_peer_id: int,
		occupant_peer_id: int,
		avatar_id: StringName,
		request_sequence: int
) -> StringName:
	if source_peer_id != _authority_peer_id:
		return &"unauthorized_source"
	if occupant_peer_id <= 0 or not _valid_id(avatar_id):
		return &"invalid_claim_request"
	if not _valid_nonnegative_integer(request_sequence):
		return &"invalid_request_sequence"
	if not _accept_sequence(occupant_peer_id, request_sequence):
		return &"stale_request_sequence"
	return &""


func _accept_sequence(occupant_peer_id: int, request_sequence: int) -> bool:
	return request_sequence > int(_last_request_sequence_by_peer.get(occupant_peer_id, -1))


func _assignment_key(occupant_peer_id: int, avatar_id: StringName) -> StringName:
	return StringName("%d:%s" % [occupant_peer_id, str(avatar_id)])


func _has_role(role: StringName) -> bool:
	for seat_variant in _seats.values():
		if StringName((seat_variant as Dictionary).get("role", &"")) == role:
			return true
	return false


func _valid_role(value: StringName) -> bool:
	return value in ROLES


func _valid_id_or_empty(value: StringName) -> bool:
	return value == &"" or _valid_id(value)


func _valid_id(value: StringName) -> bool:
	var text := str(value)
	if text.is_empty() or text.length() > MAX_ID_LENGTH:
		return false
	for index in text.length():
		var codepoint := text.unicode_at(index)
		var ascii_alphanumeric := (codepoint >= 48 and codepoint <= 57) \
			or (codepoint >= 65 and codepoint <= 90) \
			or (codepoint >= 97 and codepoint <= 122)
		if not (ascii_alphanumeric or codepoint == 95 or codepoint == 45):
			return false
	return true


func _valid_positive_integer(value: int) -> bool:
	return value > 0 and value <= MAX_SAFE_INTEGER


func _valid_nonnegative_integer(value: int) -> bool:
	return value >= 0 and value <= MAX_SAFE_INTEGER


func _result(accepted: bool, status: StringName, payload: Dictionary = {}) -> Dictionary:
	var result := {
		"accepted": accepted,
		"status": status,
		"event_sequence": _event_sequence,
	}
	for key in payload:
		result[key] = payload[key]
	return result.duplicate(true)


func _remember(result: Dictionary) -> Dictionary:
	_last_result = result.duplicate(true)
	return result.duplicate(true)
