class_name NetworkAuthoritativeSnapshot
extends RefCounted

## Server-published typed state boundary for the first multiplayer slice.
##
## The existing movement, ship-ownership, projectile, boarding, damage/respawn,
## repair, and landing authorities each own their own ledger. This synchronizer joins
## their already-committed detached records into one generation-fenced
## snapshot. It does not move nodes, apply damage, reserve seats or berths,
## spawn projectiles, or call RPC; server adapters publish here and replicas
## consume the copied result.

const SCHEMA_VERSION := 5
const POLICY_VERSION: StringName = &"network_authoritative_snapshot_v5"
const MAX_SAFE_INTEGER := 9_007_199_254_740_991
const MAX_ENTRIES_PER_SECTION := 256
const LANDING_STATES := [&"flying", &"landing_pending", &"landed"]
const DAMAGE_RESPAWN_STATES := [
	&"active", &"healthy", &"damaged", &"destroyed", &"recovering",
	&"recovery_ready", &"ready", &"respawn_pending", &"respawning",
]
const REPAIR_STATES := [&"started", &"progress", &"completed", &"aborted"]
const OWNERSHIP_STATES := [&"owned", &"released", &"transferred", &"disconnected"]
const BOARDING_STATES := [&"boarded", &"released", &"transferred", &"disconnected"]
const PROJECTILE_STATES := [&"spawned", &"active", &"impacted", &"expired", &"aborted"]
const SECTION_NAMES := [
	&"movement", &"ownership", &"projectiles", &"boarding", &"respawn", &"landing",
]
const SECTION_ID_FIELDS := {
	&"movement": &"entity_id",
	&"ownership": &"ship_id",
	&"projectiles": &"projectile_id",
	&"boarding": &"seat_id",
	&"respawn": &"entity_id",
	&"landing": &"entity_id",
}
const SECTION_REQUIRED_FIELDS := {
	&"movement": [&"entity_id", &"entity_generation", &"owner_peer_id", &"mode"],
	&"ownership": [
		&"ship_id", &"ship_generation", &"owner_peer_id", &"owner_peer_generation",
		&"ownership_generation", &"ownership_revision", &"ownership_server_tick", &"state",
	],
	&"projectiles": [
		&"projectile_id", &"projectile_generation", &"source_entity_id",
		&"source_generation", &"owner_peer_id", &"projectile_revision",
		&"projectile_server_tick", &"position", &"terminal", &"state",
	],
	&"boarding": [
		&"seat_id", &"seat_generation", &"occupant_peer_id", &"occupant_peer_generation",
		&"avatar_id", &"vessel_id", &"ship_generation", &"role",
		&"boarding_revision", &"boarding_server_tick", &"state",
	],
	&"respawn": [
		&"entity_id", &"entity_generation", &"component_generation",
		&"damage_revision", &"damage_server_tick", &"health", &"destroyed",
		&"recovery_generation", &"damage_event_count", &"state",
	],
	&"landing": [
		&"entity_id", &"entity_generation", &"landing_revision",
		&"landing_server_tick", &"position", &"state",
	],
}
const COMPONENT_MODIFIER_FIELDS := [&"engine_power", &"weapon_power", &"targeting_power"]
const COMPONENT_DISABLED_FIELDS := [&"engine_disabled", &"weapon_disabled", &"targeting_disabled"]

var _authority_peer_id := 1
var _server_tick := -1
var _event_sequence := -1
var _revision := 0
var _sections: Dictionary = {}
var _landing_high_water: Dictionary = {}
var _damage_high_water: Dictionary = {}
var _ownership_high_water: Dictionary = {}
var _boarding_high_water: Dictionary = {}
var _projectile_high_water: Dictionary = {}
var _projectile_source_high_water: Dictionary = {}
var _last_result: Dictionary = {}


func _init(p_authority_peer_id: int = 1) -> void:
	_authority_peer_id = maxi(1, p_authority_peer_id)
	_last_result = _result(false, &"uninitialized")


## Publishes only records already committed by the server-owned authorities.
## Every section is validated before any snapshot state changes, and all input
## arrays/dictionaries are deep-copied so a caller cannot mutate a packet after
## publication.
func publish(
	source_peer_id: int,
	server_tick: int,
	event_sequence: int,
	movement: Array,
	ownership: Array,
	projectiles: Array,
	boarding: Array,
	respawn: Array,
	landing: Array = []
) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	if not _valid_nonnegative_integer(server_tick):
		return _remember(_result(false, &"invalid_server_tick"))
	if not _valid_nonnegative_integer(event_sequence):
		return _remember(_result(false, &"invalid_event_sequence"))
	if server_tick < _server_tick:
		return _remember(_result(false, &"stale_server_tick"))
	if event_sequence <= _event_sequence:
		return _remember(_result(false, &"stale_event_sequence"))
	var incoming := {
		&"movement": movement,
		&"ownership": ownership,
		&"projectiles": projectiles,
		&"boarding": boarding,
		&"respawn": respawn,
		&"landing": landing,
	}
	var section_status := _validate_sections(incoming)
	if not bool(section_status.get("valid", false)):
		return _remember(_result(false, section_status.get("status", &"invalid_sections")))
	var landing_status := _validate_landing_progress(landing)
	if not bool(landing_status.get("valid", false)):
		return _remember(_result(false, landing_status.get("status", &"stale_landing_snapshot")))
	var damage_status := _validate_damage_progress(respawn)
	if not bool(damage_status.get("valid", false)):
		return _remember(_result(false, damage_status.get("status", &"stale_damage_snapshot")))
	var ownership_status := _validate_ownership_progress(ownership)
	if not bool(ownership_status.get("valid", false)):
		return _remember(_result(false, ownership_status.get("status", &"stale_ownership_snapshot")))
	var boarding_status := _validate_boarding_progress(boarding)
	if not bool(boarding_status.get("valid", false)):
		return _remember(_result(false, boarding_status.get("status", &"stale_boarding_snapshot")))
	var projectile_status := _validate_projectile_progress(projectiles)
	if not bool(projectile_status.get("valid", false)):
		return _remember(_result(false, projectile_status.get("status", &"stale_projectile_snapshot")))
	_server_tick = server_tick
	_event_sequence = event_sequence
	_revision += 1
	_sections = _copy_sections(incoming)
	_remember_landing_progress(landing)
	_remember_damage_progress(respawn)
	_remember_ownership_progress(ownership)
	_remember_boarding_progress(boarding)
	_remember_projectile_progress(projectiles)
	return _remember(_result(true, &"published", {
		"revision": _revision,
		"snapshot": get_snapshot(),
	}))


## Applies one server-issued snapshot on a replica. The transport adapter must
## authenticate the packet before calling this method; this boundary still
## checks the authority peer, ordering, schema, and every lifecycle identity.
func apply_replica(source_peer_id: int, packet: Dictionary) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	if not packet.has("schema_version") or int(packet.get("schema_version", 0)) != SCHEMA_VERSION:
		return _remember(_result(false, &"schema_version_mismatch"))
	if StringName(packet.get("policy_version", &"")) != POLICY_VERSION:
		return _remember(_result(false, &"policy_version_mismatch"))
	if int(packet.get("authority_peer_id", 0)) != _authority_peer_id:
		return _remember(_result(false, &"authority_peer_mismatch"))
	var server_tick := int(packet.get("server_tick", -1))
	var event_sequence := int(packet.get("event_sequence", -1))
	var revision := int(packet.get("revision", 0))
	if not _valid_nonnegative_integer(server_tick) or not _valid_nonnegative_integer(event_sequence):
		return _remember(_result(false, &"invalid_snapshot_order"))
	if revision <= 0:
		return _remember(_result(false, &"invalid_snapshot_revision"))
	if server_tick < _server_tick or event_sequence <= _event_sequence or revision <= _revision:
		return _remember(_result(false, &"stale_snapshot"))
	var incoming_variant: Variant = packet.get("sections", {})
	if not incoming_variant is Dictionary:
		return _remember(_result(false, &"invalid_sections"))
	var section_status := _validate_sections(incoming_variant as Dictionary)
	if not bool(section_status.get("valid", false)):
		return _remember(_result(false, section_status.get("status", &"invalid_sections")))
	var landing := (incoming_variant as Dictionary).get(&"landing", []) as Array
	var landing_status := _validate_landing_progress(landing)
	if not bool(landing_status.get("valid", false)):
		return _remember(_result(false, landing_status.get("status", &"stale_landing_snapshot")))
	var respawn := (incoming_variant as Dictionary).get(&"respawn", []) as Array
	var damage_status := _validate_damage_progress(respawn)
	if not bool(damage_status.get("valid", false)):
		return _remember(_result(false, damage_status.get("status", &"stale_damage_snapshot")))
	var ownership := (incoming_variant as Dictionary).get(&"ownership", []) as Array
	var ownership_status := _validate_ownership_progress(ownership)
	if not bool(ownership_status.get("valid", false)):
		return _remember(_result(false, ownership_status.get("status", &"stale_ownership_snapshot")))
	var boarding := (incoming_variant as Dictionary).get(&"boarding", []) as Array
	var boarding_status := _validate_boarding_progress(boarding)
	if not bool(boarding_status.get("valid", false)):
		return _remember(_result(false, boarding_status.get("status", &"stale_boarding_snapshot")))
	var projectiles := (incoming_variant as Dictionary).get(&"projectiles", []) as Array
	var projectile_status := _validate_projectile_progress(projectiles)
	if not bool(projectile_status.get("valid", false)):
		return _remember(_result(false, projectile_status.get("status", &"stale_projectile_snapshot")))
	_server_tick = server_tick
	_event_sequence = event_sequence
	_revision = revision
	_sections = _copy_sections(incoming_variant as Dictionary)
	_remember_landing_progress(landing)
	_remember_damage_progress(respawn)
	_remember_ownership_progress(ownership)
	_remember_boarding_progress(boarding)
	_remember_projectile_progress(projectiles)
	return _remember(_result(true, &"replica_applied", {
		"revision": _revision,
		"snapshot": get_snapshot(),
	}))


func get_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"policy_version": POLICY_VERSION,
		"authority_peer_id": _authority_peer_id,
		"server_tick": _server_tick,
		"event_sequence": _event_sequence,
		"revision": _revision,
		"sections": _copy_sections(_sections),
	}.duplicate(true)


func get_section(section_name: StringName) -> Array:
	return (_sections.get(section_name, []) as Array).duplicate(true)


func audit() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"policy_version": POLICY_VERSION,
		"authority_peer_id": _authority_peer_id,
		"server_owns_movement_snapshot": true,
		"server_owns_ship_ownership_snapshot": true,
		"server_owns_projectile_snapshot": true,
		"projectile_records_are_presentation_only": true,
		"server_owns_boarding_snapshot": true,
		"boarding_records_are_presentation_only": true,
		"server_owns_respawn_snapshot": true,
		"damage_respawn_records_are_presentation_only": true,
		"server_owns_repair_snapshot": true,
		"repair_records_are_presentation_only": true,
		"server_owns_landing_snapshot": true,
		"landing_records_are_presentation_only": true,
		"client_can_mutate_snapshot": false,
		"replicas_apply_only_server_packets": true,
		"replicas_interpolate_or_present_only": true,
		"section_count": SECTION_NAMES.size(),
		"revision": _revision,
	}.duplicate(true)


func get_last_result() -> Dictionary:
	return _last_result.duplicate(true)


func _validate_sections(raw_sections: Dictionary) -> Dictionary:
	if raw_sections.size() != SECTION_NAMES.size():
		return {"valid": false, "status": &"invalid_section_set"}
	for section_name in SECTION_NAMES:
		if not raw_sections.has(section_name):
			return {"valid": false, "status": &"missing_section"}
		var entries_variant: Variant = raw_sections.get(section_name)
		if not entries_variant is Array:
			return {"valid": false, "status": &"invalid_section_array"}
		var entries := entries_variant as Array
		if entries.size() > MAX_ENTRIES_PER_SECTION:
			return {"valid": false, "status": &"section_capacity"}
		var seen: Dictionary = {}
		var id_field: StringName = SECTION_ID_FIELDS[section_name]
		var required: Array = SECTION_REQUIRED_FIELDS[section_name]
		for entry_variant in entries:
			if not entry_variant is Dictionary:
				return {"valid": false, "status": &"invalid_section_entry"}
			var entry := entry_variant as Dictionary
			for field_variant in required:
				var field: StringName = field_variant
				if not entry.has(field):
					return {"valid": false, "status": &"missing_section_field"}
			if not _valid_id(entry.get(id_field)):
				return {"valid": false, "status": &"invalid_section_identity"}
			var identity := String(entry.get(id_field))
			if seen.has(identity):
				return {"valid": false, "status": &"duplicate_section_identity"}
			seen[identity] = true
			if not _valid_entry_generations(entry, section_name):
				return {"valid": false, "status": &"invalid_section_generation"}
			if not _valid_component_modifiers(entry):
				return {"valid": false, "status": &"invalid_component_modifiers"}
			if section_name == &"landing" and not _valid_landing_entry(entry):
				return {"valid": false, "status": &"invalid_landing_record"}
			if section_name == &"respawn" and not _valid_damage_entry(entry):
				return {"valid": false, "status": &"invalid_damage_record"}
			if section_name == &"ownership" and not _valid_ownership_entry(entry):
				return {"valid": false, "status": &"invalid_ownership_record"}
			if section_name == &"boarding" and not _valid_boarding_entry(entry):
				return {"valid": false, "status": &"invalid_boarding_record"}
			if section_name == &"projectiles" and not _valid_projectile_entry(entry):
				return {"valid": false, "status": &"invalid_projectile_record"}
	return {"valid": true}


func _valid_landing_entry(entry: Dictionary) -> bool:
	var position_variant: Variant = entry.get("position")
	return _valid_positive_integer(entry.get("landing_revision")) \
		and _valid_nonnegative_integer(entry.get("landing_server_tick")) \
		and position_variant is Vector3 \
		and (position_variant as Vector3).is_finite() \
		and StringName(entry.get("state", &"")) in LANDING_STATES


func _valid_damage_entry(entry: Dictionary) -> bool:
	var health_variant: Variant = entry.get("health")
	if not (health_variant is float or health_variant is int) \
			or not is_finite(float(health_variant)) or float(health_variant) < 0.0:
		return false
	var state := StringName(entry.get("state", &""))
	var destroyed := bool(entry.get("destroyed", false))
	if not entry.get("destroyed") is bool \
			or not _valid_positive_integer(entry.get("damage_revision")) \
			or not _valid_nonnegative_integer(entry.get("damage_server_tick")) \
			or not _valid_nonnegative_integer(entry.get("recovery_generation")) \
			or not _valid_nonnegative_integer(entry.get("damage_event_count")) \
			or not state in DAMAGE_RESPAWN_STATES:
		return false
	if state == &"destroyed" and (not destroyed or float(health_variant) > 0.0):
		return false
	if state in [&"active", &"healthy", &"damaged"] and destroyed:
		return false
	if destroyed and int(entry.get("recovery_generation", 0)) <= 0:
		return false
	if entry.has("maximum_health"):
		var maximum_variant: Variant = entry.get("maximum_health")
		if not (maximum_variant is float or maximum_variant is int) \
				or not is_finite(float(maximum_variant)) \
				or float(maximum_variant) <= 0.0 \
				or float(health_variant) > float(maximum_variant):
			return false
	if entry.has("repair"):
		var repair_variant: Variant = entry.get("repair")
		if not repair_variant is Dictionary \
				or not _valid_repair_entry(repair_variant as Dictionary, entry):
			return false
	return true


func _valid_repair_entry(repair: Dictionary, damage: Dictionary) -> bool:
	var progress_variant: Variant = repair.get("progress")
	var state := StringName(repair.get("state", &""))
	var terminal_variant: Variant = repair.get("terminal")
	if not _valid_positive_integer(repair.get("repair_generation")) \
			or not _valid_positive_integer(repair.get("repair_sequence")) \
			or not _valid_nonnegative_integer(repair.get("repair_server_tick")) \
			or not _valid_id(repair.get("component_id")) \
			or int(repair.get("component_generation", 0)) \
				!= int(damage.get("component_generation", 0)) \
			or not _valid_positive_integer(repair.get("owner_peer_id")) \
			or not _valid_positive_integer(repair.get("owner_peer_generation")) \
			or not _valid_id(repair.get("avatar_id")) \
			or not _valid_id(repair.get("seat_id")) \
			or not _valid_nonnegative_integer(repair.get("seat_generation")) \
			or not (progress_variant is int or progress_variant is float) \
			or not is_finite(float(progress_variant)) \
			or float(progress_variant) < 0.0 or float(progress_variant) > 1.0 \
			or not state in REPAIR_STATES \
			or not terminal_variant is bool \
			or bool(terminal_variant) != (state in [&"completed", &"aborted"]):
		return false
	if state == &"started":
		return float(progress_variant) == 0.0
	if state == &"progress":
		return float(progress_variant) > 0.0
	if state == &"completed":
		return float(progress_variant) == 1.0
	return true


func _valid_ownership_entry(entry: Dictionary) -> bool:
	var owner_peer_id := int(entry.get("owner_peer_id", -1))
	var owner_peer_generation := int(entry.get("owner_peer_generation", -1))
	var state := StringName(entry.get("state", &""))
	if owner_peer_id < 0 or not state in OWNERSHIP_STATES \
			or not _valid_positive_integer(entry.get("ownership_revision")) \
			or not _valid_nonnegative_integer(entry.get("ownership_server_tick")):
		return false
	if owner_peer_id == 0:
		return owner_peer_generation == 0 and state in [&"released", &"disconnected"]
	return owner_peer_generation > 0 and state in [&"owned", &"transferred"]


func _valid_boarding_entry(entry: Dictionary) -> bool:
	var occupant_peer_id := int(entry.get("occupant_peer_id", -1))
	var occupant_peer_generation := int(entry.get("occupant_peer_generation", -1))
	var avatar_id := StringName(entry.get("avatar_id", &""))
	var state := StringName(entry.get("state", &""))
	if occupant_peer_id < 0 or not _valid_id(StringName(entry.get("vessel_id", &""))) \
			or not _valid_id(StringName(entry.get("role", &""))) \
			or not state in BOARDING_STATES \
			or not _valid_positive_integer(entry.get("boarding_revision")) \
			or not _valid_nonnegative_integer(entry.get("boarding_server_tick")):
		return false
	if occupant_peer_id == 0:
		return occupant_peer_generation == 0 and avatar_id.is_empty() \
			and state in [&"released", &"disconnected"]
	return occupant_peer_generation > 0 and _valid_id(avatar_id) \
		and state in [&"boarded", &"transferred"]


func _valid_projectile_entry(entry: Dictionary) -> bool:
	var position_variant: Variant = entry.get("position")
	var terminal_variant: Variant = entry.get("terminal")
	var state := StringName(entry.get("state", &""))
	if not position_variant is Vector3 or not (position_variant as Vector3).is_finite() \
			or not terminal_variant is bool or not state in PROJECTILE_STATES \
			or int(entry.get("owner_peer_id", 0)) <= 0 \
			or not _valid_positive_integer(entry.get("projectile_revision")) \
			or not _valid_nonnegative_integer(entry.get("projectile_server_tick")):
		return false
	return bool(terminal_variant) == (state in [&"impacted", &"expired", &"aborted"])


## A newer canonical envelope cannot regress one landing entity's own
## generation/revision. Equal records are allowed because unrelated canonical
## sections may publish while a landing remains unchanged.
func _validate_landing_progress(records: Array) -> Dictionary:
	for record_variant in records:
		var record := record_variant as Dictionary
		var entity_id := StringName(record.get("entity_id", &""))
		var prior := _landing_high_water.get(entity_id, {}) as Dictionary
		if prior.is_empty():
			continue
		var entity_generation := int(record.get("entity_generation", 0))
		var prior_generation := int(prior.get("entity_generation", 0))
		var landing_revision := int(record.get("landing_revision", 0))
		var prior_revision := int(prior.get("landing_revision", 0))
		if entity_generation < prior_generation:
			return {"valid": false, "status": &"stale_landing_generation"}
		if landing_revision < prior_revision \
				or (entity_generation > prior_generation and landing_revision <= prior_revision):
			return {"valid": false, "status": &"stale_landing_revision"}
		if int(record.get("landing_server_tick", 0)) \
				< int(prior.get("landing_server_tick", 0)):
			return {"valid": false, "status": &"stale_landing_server_tick"}
		if entity_generation == prior_generation and landing_revision == prior_revision \
				and record != (prior.get("record", {}) as Dictionary):
			return {"valid": false, "status": &"stale_landing_revision"}
	return {"valid": true}


func _remember_landing_progress(records: Array) -> void:
	for record_variant in records:
		var record := (record_variant as Dictionary).duplicate(true)
		_landing_high_water[StringName(record.get("entity_id", &""))] = {
			"entity_generation": int(record.get("entity_generation", 0)),
			"landing_revision": int(record.get("landing_revision", 0)),
			"landing_server_tick": int(record.get("landing_server_tick", 0)),
			"record": record,
		}


func _validate_damage_progress(records: Array) -> Dictionary:
	for record_variant in records:
		var record := record_variant as Dictionary
		var entity_id := StringName(record.get("entity_id", &""))
		var prior := _damage_high_water.get(entity_id, {}) as Dictionary
		if prior.is_empty():
			continue
		var entity_generation := int(record.get("entity_generation", 0))
		var prior_entity_generation := int(prior.get("entity_generation", 0))
		var component_generation := int(record.get("component_generation", 0))
		var prior_component_generation := int(prior.get("component_generation", 0))
		var damage_revision := int(record.get("damage_revision", 0))
		var prior_revision := int(prior.get("damage_revision", 0))
		if entity_generation < prior_entity_generation:
			return {"valid": false, "status": &"stale_damage_entity_generation"}
		if component_generation < prior_component_generation:
			return {"valid": false, "status": &"stale_damage_component_generation"}
		if damage_revision < prior_revision \
				or (entity_generation > prior_entity_generation and damage_revision <= prior_revision):
			return {"valid": false, "status": &"stale_damage_revision"}
		if int(record.get("damage_server_tick", 0)) \
				< int(prior.get("damage_server_tick", 0)):
			return {"valid": false, "status": &"stale_damage_server_tick"}
		if entity_generation == prior_entity_generation \
				and component_generation == prior_component_generation \
				and damage_revision == prior_revision \
				and record != (prior.get("record", {}) as Dictionary):
			return {"valid": false, "status": &"stale_damage_revision"}
		var repair_status := _validate_repair_progress(record, prior)
		if not bool(repair_status.get("valid", false)):
			return repair_status
	return {"valid": true}


func _validate_repair_progress(record: Dictionary, prior: Dictionary) -> Dictionary:
	var prior_record := prior.get("record", {}) as Dictionary
	var prior_repair := prior_record.get("repair", {}) as Dictionary
	if prior_repair.is_empty():
		return {"valid": true}
	var repair := record.get("repair", {}) as Dictionary
	if repair.is_empty():
		if int(record.get("component_generation", 0)) \
				> int(prior_record.get("component_generation", 0)):
			return {"valid": true}
		return {"valid": false, "status": &"repair_lifecycle_missing"}
	var generation := int(repair.get("repair_generation", 0))
	var prior_generation := int(prior_repair.get("repair_generation", 0))
	var sequence := int(repair.get("repair_sequence", 0))
	var prior_sequence := int(prior_repair.get("repair_sequence", 0))
	if generation < prior_generation:
		return {"valid": false, "status": &"stale_repair_generation"}
	if sequence < prior_sequence:
		return {"valid": false, "status": &"stale_repair_sequence"}
	if int(repair.get("repair_server_tick", 0)) \
			< int(prior_repair.get("repair_server_tick", 0)):
		return {"valid": false, "status": &"stale_repair_server_tick"}
	if generation == prior_generation and sequence == prior_sequence:
		return {"valid": repair == prior_repair, "status": &"stale_repair_sequence"}
	if generation > prior_generation:
		if StringName(repair.get("state", &"")) != &"started":
			return {"valid": false, "status": &"repair_generation_not_started"}
		return {"valid": true}
	if bool(prior_repair.get("terminal", false)):
		return {"valid": false, "status": &"repair_generation_terminal"}
	if StringName(repair.get("state", &"")) == &"started" \
			or float(repair.get("progress", 0.0)) < float(prior_repair.get("progress", 0.0)):
		return {"valid": false, "status": &"invalid_repair_transition"}
	return {"valid": true}


func _remember_damage_progress(records: Array) -> void:
	for record_variant in records:
		var record := (record_variant as Dictionary).duplicate(true)
		_damage_high_water[StringName(record.get("entity_id", &""))] = {
			"entity_generation": int(record.get("entity_generation", 0)),
			"component_generation": int(record.get("component_generation", 0)),
			"damage_revision": int(record.get("damage_revision", 0)),
			"damage_server_tick": int(record.get("damage_server_tick", 0)),
			"record": record,
		}


func _validate_ownership_progress(records: Array) -> Dictionary:
	for record_variant in records:
		var record := record_variant as Dictionary
		var ship_id := StringName(record.get("ship_id", &""))
		var prior := _ownership_high_water.get(ship_id, {}) as Dictionary
		if prior.is_empty():
			continue
		if int(record.get("ship_generation", 0)) < int(prior.get("ship_generation", 0)):
			return {"valid": false, "status": &"stale_ownership_ship_generation"}
		if int(record.get("ship_generation", 0)) == int(prior.get("ship_generation", 0)) \
				and int(record.get("ownership_generation", 0)) < int(prior.get("ownership_generation", 0)):
			return {"valid": false, "status": &"stale_ownership_generation"}
		var revision := int(record.get("ownership_revision", 0))
		var prior_revision := int(prior.get("ownership_revision", 0))
		if revision < prior_revision:
			return {"valid": false, "status": &"stale_ownership_revision"}
		if int(record.get("ownership_server_tick", 0)) \
				< int(prior.get("ownership_server_tick", 0)):
			return {"valid": false, "status": &"stale_ownership_server_tick"}
		if revision == prior_revision and record != (prior.get("record", {}) as Dictionary):
			return {"valid": false, "status": &"stale_ownership_revision"}
	return {"valid": true}


func _remember_ownership_progress(records: Array) -> void:
	for record_variant in records:
		var record := (record_variant as Dictionary).duplicate(true)
		_ownership_high_water[StringName(record.get("ship_id", &""))] = {
			"ship_generation": int(record.get("ship_generation", 0)),
			"ownership_generation": int(record.get("ownership_generation", 0)),
			"ownership_revision": int(record.get("ownership_revision", 0)),
			"ownership_server_tick": int(record.get("ownership_server_tick", 0)),
			"record": record,
		}


func _validate_boarding_progress(records: Array) -> Dictionary:
	for record_variant in records:
		var record := record_variant as Dictionary
		var seat_id := StringName(record.get("seat_id", &""))
		var prior := _boarding_high_water.get(seat_id, {}) as Dictionary
		if prior.is_empty():
			continue
		if int(record.get("seat_generation", 0)) < int(prior.get("seat_generation", 0)):
			return {"valid": false, "status": &"stale_boarding_seat_generation"}
		if int(record.get("ship_generation", 0)) < int(prior.get("ship_generation", 0)):
			return {"valid": false, "status": &"stale_boarding_ship_generation"}
		var revision := int(record.get("boarding_revision", 0))
		var prior_revision := int(prior.get("boarding_revision", 0))
		if revision < prior_revision:
			return {"valid": false, "status": &"stale_boarding_revision"}
		if int(record.get("boarding_server_tick", 0)) \
				< int(prior.get("boarding_server_tick", 0)):
			return {"valid": false, "status": &"stale_boarding_server_tick"}
		if revision == prior_revision and record != (prior.get("record", {}) as Dictionary):
			return {"valid": false, "status": &"stale_boarding_revision"}
	return {"valid": true}


func _remember_boarding_progress(records: Array) -> void:
	for record_variant in records:
		var record := (record_variant as Dictionary).duplicate(true)
		_boarding_high_water[StringName(record.get("seat_id", &""))] = {
			"seat_generation": int(record.get("seat_generation", 0)),
			"ship_generation": int(record.get("ship_generation", 0)),
			"boarding_revision": int(record.get("boarding_revision", 0)),
			"boarding_server_tick": int(record.get("boarding_server_tick", 0)),
			"record": record,
		}


func _validate_projectile_progress(records: Array) -> Dictionary:
	for record_variant in records:
		var record := record_variant as Dictionary
		var projectile_id := StringName(record.get("projectile_id", &""))
		var source_id := StringName(record.get("source_entity_id", &""))
		var source_generation := int(record.get("source_generation", 0))
		# Retained tombstones from an older source generation may coexist with
		# current fire. Only a live projectile can improperly revive that source.
		if source_generation < int(_projectile_source_high_water.get(source_id, 0)) \
				and not bool(record.get("terminal", false)):
			return {"valid": false, "status": &"stale_projectile_source_generation"}
		var prior := _projectile_high_water.get(projectile_id, {}) as Dictionary
		if prior.is_empty():
			continue
		var generation := int(record.get("projectile_generation", 0))
		var prior_generation := int(prior.get("projectile_generation", 0))
		if generation < prior_generation:
			return {"valid": false, "status": &"stale_projectile_generation"}
		if generation == prior_generation and bool(prior.get("terminal", false)):
			if record != (prior.get("record", {}) as Dictionary):
				return {"valid": false, "status": &"projectile_generation_terminal"}
			continue
		var revision := int(record.get("projectile_revision", 0))
		var prior_revision := int(prior.get("projectile_revision", 0))
		if revision < prior_revision:
			return {"valid": false, "status": &"stale_projectile_revision"}
		if int(record.get("projectile_server_tick", 0)) \
				< int(prior.get("projectile_server_tick", 0)):
			return {"valid": false, "status": &"stale_projectile_server_tick"}
		if revision == prior_revision and record != (prior.get("record", {}) as Dictionary):
			return {"valid": false, "status": &"stale_projectile_revision"}
	return {"valid": true}


func _remember_projectile_progress(records: Array) -> void:
	for record_variant in records:
		var record := (record_variant as Dictionary).duplicate(true)
		_projectile_high_water[StringName(record.get("projectile_id", &""))] = {
			"projectile_generation": int(record.get("projectile_generation", 0)),
			"projectile_revision": int(record.get("projectile_revision", 0)),
			"projectile_server_tick": int(record.get("projectile_server_tick", 0)),
			"terminal": bool(record.get("terminal", false)),
			"record": record,
		}
		var source_id := StringName(record.get("source_entity_id", &""))
		_projectile_source_high_water[source_id] = maxi(
			int(_projectile_source_high_water.get(source_id, 0)),
			int(record.get("source_generation", 0))
		)


func _valid_component_modifiers(entry: Dictionary) -> bool:
	for field_variant in COMPONENT_MODIFIER_FIELDS:
		var field: StringName = field_variant
		if not entry.has(field):
			continue
		var value: Variant = entry.get(field)
		if not (value is float or value is int) or not is_finite(float(value)) \
				or float(value) < 0.0 or float(value) > 1.0:
			return false
	for field_variant in COMPONENT_DISABLED_FIELDS:
		var disabled_field: StringName = field_variant
		if entry.has(disabled_field) and not entry.get(disabled_field) is bool:
			return false
	return true


func _valid_entry_generations(entry: Dictionary, section_name: StringName) -> bool:
	for key in entry.keys():
		var field := StringName(key)
		if field in [
			&"ownership_generation", &"recovery_generation",
			&"owner_peer_generation", &"occupant_peer_generation",
		]:
			if not _valid_nonnegative_integer(entry.get(key)):
				return false
		elif field.ends_with("_generation") or field == &"component_generation":
			if not _valid_positive_integer(entry.get(key)):
				return false
	for key in [&"owner_peer_id", &"occupant_peer_id"]:
		if entry.has(key) and not _valid_nonnegative_integer(entry.get(key)):
			return false
	if section_name == &"movement" and int(entry.get("owner_peer_id", 0)) <= 0:
		return false
	return true


func _copy_sections(source: Dictionary) -> Dictionary:
	var copied: Dictionary = {}
	for section_name in SECTION_NAMES:
		var entries: Array = source.get(section_name, []) as Array
		var section_copy: Array = []
		for entry_variant in entries:
			section_copy.append((entry_variant as Dictionary).duplicate(true))
		section_copy.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
			var id_field: StringName = SECTION_ID_FIELDS[section_name]
			return str(left.get(id_field, "")) < str(right.get(id_field, ""))
		)
		copied[section_name] = section_copy
	return copied


func _valid_id(value: Variant) -> bool:
	if not value is String and not value is StringName:
		return false
	var text := String(value)
	if text.is_empty() or text.length() > 64:
		return false
	for index in text.length():
		var codepoint := text.unicode_at(index)
		var alpha_numeric := (codepoint >= 48 and codepoint <= 57) \
			or (codepoint >= 65 and codepoint <= 90) \
			or (codepoint >= 97 and codepoint <= 122)
		if not (alpha_numeric or codepoint == 95 or codepoint == 45):
			return false
	return true


func _valid_nonnegative_integer(value: Variant) -> bool:
	return value is int and value >= 0 and value <= MAX_SAFE_INTEGER


func _valid_positive_integer(value: Variant) -> bool:
	return value is int and value > 0 and value <= MAX_SAFE_INTEGER


func _result(accepted: bool, status: StringName, payload: Dictionary = {}) -> Dictionary:
	var result := {
		"schema_version": SCHEMA_VERSION,
		"policy_version": POLICY_VERSION,
		"accepted": accepted,
		"status": status,
		"authority_peer_id": _authority_peer_id,
		"server_tick": _server_tick,
		"event_sequence": _event_sequence,
		"revision": _revision,
	}
	for key in payload:
		result[key] = payload[key]
	return result


func _remember(result: Dictionary) -> Dictionary:
	_last_result = result.duplicate(true)
	return _last_result.duplicate(true)
