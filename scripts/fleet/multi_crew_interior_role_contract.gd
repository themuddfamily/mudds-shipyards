class_name MultiCrewInteriorRoleContract
extends RefCounted

## Bounded role/layout contract for a larger modern vessel.
##
## This is deliberately a data-and-audit seam, not multiplayer gameplay.  A
## peer may send an intent for one of these roles, but the role never owns
## movement truth, seat reservation, damage, landing, or occupancy.  The
## production ship still owns the physical markers and MovingInteriorFrame;
## this contract only gives the future session coordinator a stable, reviewable
## mapping from a named role to an actual seat and walkable route.

const SCHEMA_VERSION := 1
const CONTRACT_ID: StringName = &"halyard_multi_crew_interior_v1"
const SHIP_ID: StringName = &"halyard_new_design"

const REQUIRED_CONNECTED_SPACES := [
	"flight_deck",
	"crew_cabin",
	"aft_systems_bay",
]
const REQUIRED_ROUTE_PREFIX: StringName = &"port_airstair"
const ROLE_LAYOUT_STATUS: StringName = &"layout_contract_only"

## Every role has a physical anchor.  The two extra cabin seats are explicitly
## reserved for a later passenger/crew increment rather than silently becoming
## untracked occupancy.
const ROLE_DEFINITIONS := [
	{
		"role_id": &"pilot",
		"display_name": "Pilot",
		"seat_id": &"pilot_station",
		"anchor_source": &"pilot_seat_anchor",
		"route_spaces": ["port_airstair", "crew_cabin", "flight_deck"],
		"intent_channels": ["ship_command_intent"],
	},
	{
		"role_id": &"co_pilot",
		"display_name": "Co-pilot",
		"seat_id": &"co_pilot_station",
		"anchor_source": &"co_pilot_station_anchor",
		"route_spaces": ["port_airstair", "crew_cabin", "flight_deck"],
		"intent_channels": ["flight_assist_intent"],
	},
	{
		"role_id": &"navigator",
		"display_name": "Navigator",
		"seat_id": &"crew_port_00",
		"anchor_source": &"crew_seat_anchor",
		"route_spaces": ["port_airstair", "crew_cabin"],
		"intent_channels": ["navigation_intent"],
	},
	{
		"role_id": &"sensor_operator",
		"display_name": "Sensor operator",
		"seat_id": &"crew_starboard_00",
		"anchor_source": &"crew_seat_anchor",
		"route_spaces": ["port_airstair", "crew_cabin"],
		"intent_channels": ["sensor_intent"],
	},
	{
		"role_id": &"systems_engineer",
		"display_name": "Systems engineer",
		"seat_id": &"crew_port_01",
		"anchor_source": &"crew_seat_anchor",
		"route_spaces": ["port_airstair", "crew_cabin", "aft_systems_bay"],
		"intent_channels": ["repair_intent"],
	},
	{
		"role_id": &"passenger",
		"display_name": "Passenger",
		"seat_id": &"crew_starboard_01",
		"anchor_source": &"crew_seat_anchor",
		"route_spaces": ["port_airstair", "crew_cabin"],
		"intent_channels": ["passenger_manifest_intent"],
	},
]

const RESERVED_SEAT_IDS := ["crew_port_02", "crew_starboard_02"]

## This split is the important part of the contract.  The first owner may
## receive an input intent; the remaining owners alone may change authoritative
## state.  None of these values is a client or a role object.
const AUTHORITY_OWNERS := {
	"intent_owner": &"peer_input",
	"seat_reservation_owner": &"server_session",
	"movement_truth_owner": &"ship_simulation",
	"damage_resolution_owner": &"combat_authority",
	"landing_lease_owner": &"landing_authority",
	"occupancy_owner": &"moving_interior_frame",
}

const FORBIDDEN_DIRECT_CAPABILITIES := [
	"movement_truth",
	"seat_reservation",
	"damage_resolution",
	"landing_lease",
	"occupancy_mutation",
	"respawn",
]


static func get_contract() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"contract_id": CONTRACT_ID,
		"ship_id": SHIP_ID,
		"layout_status": ROLE_LAYOUT_STATUS,
		"roles": get_roles(),
		"reserved_seat_ids": RESERVED_SEAT_IDS.duplicate(),
		"authority_owners": AUTHORITY_OWNERS.duplicate(),
		"forbidden_direct_capabilities": FORBIDDEN_DIRECT_CAPABILITIES.duplicate(),
	}


static func get_roles() -> Array:
	var roles: Array = []
	for definition: Dictionary in ROLE_DEFINITIONS:
		var role := definition.duplicate(true)
		role["layout_status"] = ROLE_LAYOUT_STATUS
		role["authority"] = AUTHORITY_OWNERS.duplicate()
		role["direct_capabilities"] = []
		roles.append(role)
	return roles


## Audit real production markers and the walkable-interior report.  The caller
## supplies local seat positions because this keeps the contract independent of
## a particular scene instance while still requiring the actual scene to prove
## the positions and route markers.
static func audit(context: Dictionary, roles: Array = get_roles()) -> Dictionary:
	var errors := PackedStringArray()
	var resolved_seat_ids: Array = []
	var role_ids: Array = []
	var report: Dictionary = context.get("interior_report", {}) as Dictionary
	var anchor_positions: Dictionary = context.get("anchor_positions", {}) as Dictionary
	var anchor_sources: Dictionary = context.get("anchor_sources", {}) as Dictionary
	var bounds := report.get("ship_local_bounds", AABB()) as AABB
	var connected = report.get("connected_spaces", [])

	if str(context.get("ship_id", "")) != str(SHIP_ID):
		errors.append("role layout is attached to the wrong ship")
	if roles.size() != ROLE_DEFINITIONS.size():
		errors.append("role table must contain six named roles")
	if not bool(report.get("physical_deck_collision", false)):
		errors.append("role layout requires physical deck collision")
	if not bool(report.get("moving_occupant_compensation", false)):
		errors.append("role layout requires MovingInteriorFrame compensation")
	for space: String in REQUIRED_CONNECTED_SPACES:
		if not connected.has(space):
			errors.append("connected interior is missing %s" % space)

	for role_variant in roles:
		if not role_variant is Dictionary:
			errors.append("role entry is not a dictionary")
			continue
		var role: Dictionary = role_variant
		var role_id := StringName(str(role.get("role_id", "")))
		var seat_id := StringName(str(role.get("seat_id", "")))
		role_ids.append(role_id)
		resolved_seat_ids.append(seat_id)
		if role_id == StringName():
			errors.append("role has no stable ID")
		if seat_id == StringName():
			errors.append("role %s has no seat ID" % role_id)
		if not anchor_positions.has(seat_id):
			errors.append("role %s has no physical seat anchor" % role_id)
		else:
			var position: Vector3 = anchor_positions[seat_id]
			if not bounds.has_point(position):
				errors.append("role %s seat anchor leaves the interior bounds" % role_id)
		if not anchor_sources.has(seat_id):
			errors.append("role %s has no published anchor source" % role_id)
		var route: Array = role.get("route_spaces", []) as Array
		if route.is_empty() or route[0] != REQUIRED_ROUTE_PREFIX:
			errors.append("role %s route does not begin at the port airstair" % role_id)
		for route_space: String in route:
			if route_space != REQUIRED_ROUTE_PREFIX and not connected.has(route_space):
				errors.append("role %s route names a non-physical space %s" % [role_id, route_space])
		var intent_channels: Array = role.get("intent_channels", []) as Array
		if intent_channels.is_empty():
			errors.append("role %s has no intent channel" % role_id)
		var direct_capabilities: Array = role.get("direct_capabilities", []) as Array
		for capability: String in direct_capabilities:
			if FORBIDDEN_DIRECT_CAPABILITIES.has(capability):
				errors.append("role %s directly owns forbidden %s" % [role_id, capability])
		var authority: Dictionary = role.get("authority", {}) as Dictionary
		for authority_key: String in AUTHORITY_OWNERS:
			if authority.get(authority_key, null) != AUTHORITY_OWNERS[authority_key]:
				errors.append("role %s has an authority drift in %s" % [role_id, authority_key])

	if _duplicates(role_ids):
		errors.append("role IDs must be unique")
	if _duplicates(resolved_seat_ids):
		errors.append("seat assignments must be unique")
	var all_physical_seats = context.get("physical_seat_ids", [])
	for seat_id: String in RESERVED_SEAT_IDS:
		if not all_physical_seats.has(seat_id):
			errors.append("reserved future seat %s is not physically published" % seat_id)
	for seat_id: String in resolved_seat_ids:
		if not all_physical_seats.is_empty() and not all_physical_seats.has(seat_id):
			errors.append("assigned seat %s is not in the physical seat roster" % seat_id)

	return {
		"schema_version": SCHEMA_VERSION,
		"contract_id": CONTRACT_ID,
		"valid": errors.is_empty(),
		"errors": errors,
		"role_count": roles.size(),
		"role_ids": role_ids,
		"seat_ids": resolved_seat_ids,
		"reserved_seat_ids": RESERVED_SEAT_IDS.duplicate(),
		"layout_status": ROLE_LAYOUT_STATUS,
	}


static func _duplicates(values: Array) -> bool:
	var seen := {}
	for value: String in values:
		if seen.has(value):
			return true
		seen[value] = true
	return false
