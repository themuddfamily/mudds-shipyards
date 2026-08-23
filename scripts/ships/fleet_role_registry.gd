class_name FleetRoleRegistry
extends RefCounted

## Data-driven role contract for the currently implemented production fleet.
##
## ShipDefinition remains the authority for identity, compatibility tags and
## handling values. This registry is the policy layer that says what those
## values mean to a pilot: the intended story, the scale band, and the axes a
## craft owns as its signature. It deliberately has no scene, berth, landing,
## combat or lifecycle authority.

const SCHEMA_VERSION := 1
const MINIMUM_DIFFERING_HANDLING_AXES := 14

const HIGHER_IS_BETTER := [
	"maximum_speed", "thrust_acceleration", "brake_acceleration", "boost_speed",
	"boost_multiplier", "yaw_speed_degrees", "roll_speed_degrees",
	"throttle_response", "maximum_hull", "landing_maximum_speed",
]
const LOWER_IS_BETTER := ["passive_drag", "engine_start_time", "weapon_cooldown"]

## Every entry is keyed by a stable ShipDefinition ID, not a display string.
## The signature directions are checked against the complete live roster, so a
## tuning pass cannot silently turn a role into a strict upgrade.
const ROLE_CONTRACTS := {
	&"torrent_provisional": {
		"role_id": &"torrent_interceptor",
		"role_name": "Interceptor",
		"required_tags": [&"small_craft", &"interceptor"],
		"scale_band": &"small",
		"interior_expected": false,
		"crew_story": "A forgiving first sortie fighter with the quickest weapon cadence.",
		"weakness": "Less top speed and agility than the specialist recon/interceptor hulls.",
		"signature_axes": {
			"boost_multiplier": &"maximum",
			"weapon_cooldown": &"minimum",
			"landing_maximum_speed": &"maximum",
		},
	},
	&"arrow_provisional": {
		"role_id": &"arrow_reconnaissance",
		"role_name": "Reconnaissance ship",
		"required_tags": [&"small_craft", &"recon"],
		"scale_band": &"small",
		"interior_expected": false,
		"crew_story": "A light-footed scout that trades launch punch for a high boost ceiling.",
		"weakness": "Slower launch and weapon cadence than the fighter specialists.",
		"signature_axes": {"boost_speed": &"maximum"},
	},
	&"jovian_provisional": {
		"role_id": &"jovian_light_freighter",
		"role_name": "Light freighter",
		"required_tags": [&"medium_craft", &"light_freighter", &"freight", &"cargo"],
		"scale_band": &"medium",
		"interior_expected": true,
		"crew_story": "A durable utility hull whose connected hold and cabin make the route the mission.",
		"weakness": "The fleet's slowest and least agile craft.",
		"signature_axes": {
			"maximum_speed": &"minimum",
		},
		"crew_role_capabilities": {
			&"engineer": {
				"seat_id": &"passenger_port_01",
				"anchor_id": &"passenger_port_01",
				"physical": true,
				"capabilities": [&"systems_control"],
				"actions": [&"engineer_repair"],
				"authority_owner": &"CrewSeatRoleAuthority",
				"consumer_owner": &"JovianLightFreighter",
				"generation_fenced": true,
				"sequence_fenced": true,
			},
		},
	},
	&"zenith_b7_observed": {
		"role_id": &"zenith_interceptor",
		"role_name": "Interceptor (B7 label)",
		"required_tags": [&"small_craft", &"interceptor", &"single_pilot", &"zenith_b7"],
		"scale_band": &"small",
		"interior_expected": false,
		"crew_story": "A brittle, high-response interceptor for pilots who can hold the nose on target.",
		"weakness": "The lowest hull margin in the fleet.",
		"signature_axes": {
			"yaw_speed_degrees": &"maximum",
			"roll_speed_degrees": &"maximum",
			"maximum_hull": &"minimum",
		},
	},
	&"halyard_new_design": {
		"role_id": &"halyard_crew_transport",
		"role_name": "Crew transport",
		"required_tags": [&"medium_craft", &"crew_transport", &"multi_crew"],
		"scale_band": &"medium",
		"interior_expected": true,
		"crew_story": "A long-haul carrier whose walkable flight deck and cabin are the payoff.",
		"weakness": "The worst acceleration, braking, boost, landing gate, spool and weapon cadence.",
		"signature_axes": {
			"maximum_speed": &"maximum",
			"thrust_acceleration": &"minimum",
			"brake_acceleration": &"minimum",
			"boost_multiplier": &"minimum",
			"landing_maximum_speed": &"minimum",
			"engine_start_time": &"maximum",
			"weapon_cooldown": &"maximum",
		},
	},
	&"bulwark_heavy_gunship": {
		"role_id": &"bulwark_heavy_gunship",
		"role_name": "Heavy gunship",
		"required_tags": [&"medium_craft", &"gunship", &"bulwark_gunship", &"single_pilot"],
		"scale_band": &"medium",
		"interior_expected": false,
		"crew_story": "An armored gunline hull that trades agility for durable sustained fire.",
		"weakness": "Slower and less responsive than the small-craft specialists.",
		"signature_axes": {
			"maximum_hull": &"maximum",
		},
	},
}


static func get_role_contract(ship_id: StringName) -> Dictionary:
	return (ROLE_CONTRACTS.get(ship_id, {}) as Dictionary).duplicate(true)


## Detached discoverability contract for optional multicrew capabilities. This
## returns policy data only: it cannot claim a seat, mutate a ship, or dispatch
## a repair/action request.
static func get_crew_role_contract(ship_id: StringName, role: StringName) -> Dictionary:
	var contract := get_role_contract(ship_id)
	var roles := contract.get("crew_role_capabilities", {}) as Dictionary
	return (roles.get(role, {}) as Dictionary).duplicate(true)


static func get_supported_ship_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for ship_id: StringName in ROLE_CONTRACTS:
		ids.append(ship_id)
	ids.sort_custom(func(first: StringName, second: StringName) -> bool:
		return str(first) < str(second)
	)
	return ids


## Audit definitions without instantiating a scene. This makes the contract
## usable by import/package checks and keeps the policy independent of runtime
## authority. Each input must be a ShipDefinition resource.
static func audit_definitions(definitions: Array) -> Dictionary:
	var errors: PackedStringArray = []
	var warnings: PackedStringArray = []
	var by_id: Dictionary = {}
	for candidate in definitions:
		if not candidate is ShipDefinition:
			errors.append("fleet role input is not a ShipDefinition")
			continue
		var definition := candidate as ShipDefinition
		var ship_id := definition.get_ship_id()
		if by_id.has(ship_id):
			errors.append("duplicate ShipDefinition ID '%s'" % ship_id)
			continue
		by_id[ship_id] = definition
		_validate_definition_contract(definition, errors)

	var expected_ids := get_supported_ship_ids()
	for ship_id: StringName in expected_ids:
		if not by_id.has(ship_id):
			errors.append("role contract is missing production craft '%s'" % ship_id)
	for ship_id: StringName in by_id:
		if not ROLE_CONTRACTS.has(ship_id):
			errors.append("unsupported production craft '%s' has no role contract" % ship_id)

	var profiles := {}
	for ship_id: StringName in by_id:
		profiles[ship_id] = _profile(by_id[ship_id] as ShipDefinition)
	if by_id.size() >= 2:
		_validate_pairwise_separation(profiles, errors)
		_validate_non_dominance(profiles, errors)
		_validate_signatures(profiles, errors)

	var role_ids := {}
	for ship_id: StringName in by_id:
		if not ROLE_CONTRACTS.has(ship_id):
			continue
		var role_id: StringName = ROLE_CONTRACTS[ship_id].role_id
		if role_ids.has(role_id):
			errors.append("role ID '%s' is assigned more than once" % role_id)
		role_ids[role_id] = ship_id
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"warnings": warnings,
		"craft_count": by_id.size(),
		"role_count": role_ids.size(),
		"ship_ids": by_id.keys(),
		"role_ids": role_ids.keys(),
		"profiles": profiles,
	}


static func _validate_definition_contract(definition: ShipDefinition, errors: PackedStringArray) -> void:
	var ship_id := definition.get_ship_id()
	var contract: Dictionary = ROLE_CONTRACTS.get(ship_id, {})
	if contract.is_empty():
		return
	if definition.get_role() != str(contract.role_name):
		errors.append("%s role name drifted: expected '%s'" % [ship_id, contract.role_name])
	var tags := definition.get_compatibility_tags()
	for required_tag: StringName in contract.required_tags:
		if not tags.has(required_tag):
			errors.append("%s is missing required role tag '%s'" % [ship_id, required_tag])
	var expected_medium: bool = contract.scale_band == &"medium"
	if tags.has(&"medium_craft") != expected_medium:
		errors.append("%s scale band disagrees with its role contract" % ship_id)
	if tags.has(&"small_craft") == expected_medium:
		errors.append("%s has an incompatible small/medium craft tag" % ship_id)
	if not definition.is_definition_valid():
		errors.append("%s publishes an invalid ShipDefinition" % ship_id)
	_validate_crew_role_capabilities(ship_id, contract, errors)


static func _validate_crew_role_capabilities(
		ship_id: StringName,
		contract: Dictionary,
		errors: PackedStringArray
) -> void:
	var roles := contract.get("crew_role_capabilities", {}) as Dictionary
	for role_variant in roles.keys():
		var role := StringName(role_variant)
		var capability := roles[role] as Dictionary
		if capability.is_empty():
			errors.append("%s crew role '%s' has an empty capability contract" % [ship_id, role])
			continue
		for key in [&"seat_id", &"anchor_id", &"authority_owner", &"consumer_owner"]:
			if not capability.has(key) or str(capability[key]).is_empty():
				errors.append("%s crew role '%s' is missing %s" % [ship_id, role, key])
		for list_key in [&"capabilities", &"actions"]:
			var values := capability.get(list_key, []) as Array
			if values.is_empty():
				errors.append("%s crew role '%s' has no %s" % [ship_id, role, list_key])
		if not bool(capability.get("physical", false)):
			errors.append("%s crew role '%s' must publish a physical station" % [ship_id, role])
		if not bool(capability.get("generation_fenced", false)) \
				or not bool(capability.get("sequence_fenced", false)):
			errors.append("%s crew role '%s' is missing lifecycle fencing" % [ship_id, role])


static func _profile(definition: ShipDefinition) -> Dictionary:
	var profile := definition.get_flight_profile().duplicate()
	profile.merge(definition.get_systems_profile())
	return profile


static func _validate_pairwise_separation(profiles: Dictionary, errors: PackedStringArray) -> void:
	var ids: Array = profiles.keys()
	for first_index in ids.size():
		for second_index in range(first_index + 1, ids.size()):
			var first: StringName = ids[first_index]
			var second: StringName = ids[second_index]
			var differing := 0
			for axis: String in profiles[first]:
				if not is_equal_approx(float(profiles[first][axis]), float(profiles[second][axis])):
					differing += 1
			if differing < MINIMUM_DIFFERING_HANDLING_AXES:
				errors.append("%s and %s differ on only %d handling axes" % [first, second, differing])


static func _validate_non_dominance(profiles: Dictionary, errors: PackedStringArray) -> void:
	for first: StringName in profiles:
		for second: StringName in profiles:
			if first == second:
				continue
			if _count_advantages(profiles[first], profiles[second]) == 0:
				errors.append("%s is a strict upgrade over %s" % [second, first])


static func _validate_signatures(profiles: Dictionary, errors: PackedStringArray) -> void:
	for ship_id: StringName in ROLE_CONTRACTS:
		if not profiles.has(ship_id):
			continue
		var signatures: Dictionary = ROLE_CONTRACTS[ship_id].signature_axes
		for axis: String in signatures:
			if not profiles[ship_id].has(axis):
				errors.append("%s signature axis '%s' is not a ShipDefinition axis" % [ship_id, axis])
				continue
			var want_maximum: bool = signatures[axis] == &"maximum"
			var subject := float(profiles[ship_id][axis])
			for other: StringName in profiles:
				if other == ship_id:
					continue
				var value := float(profiles[other].get(axis, subject))
				if want_maximum and value >= subject:
					errors.append("%s no longer owns the contracted maximum of %s" % [ship_id, axis])
				if not want_maximum and value <= subject:
					errors.append("%s no longer owns the contracted minimum of %s" % [ship_id, axis])


static func _count_advantages(first: Dictionary, second: Dictionary) -> int:
	var advantages := 0
	for axis: String in HIGHER_IS_BETTER:
		if float(second.get(axis, 0.0)) > float(first.get(axis, 0.0)):
			advantages += 1
	for axis: String in LOWER_IS_BETTER:
		if float(second.get(axis, 0.0)) < float(first.get(axis, 0.0)):
			advantages += 1
	return advantages
