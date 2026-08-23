class_name NetworkAuthoritativeSnapshot
extends RefCounted

## Server-published typed state boundary for the first multiplayer slice.
##
## The existing movement, ship-ownership, projectile, boarding, damage/respawn,
## and landing authorities each own their own ledger. This synchronizer joins
## their already-committed detached records into one generation-fenced
## snapshot. It does not move nodes, apply damage, reserve seats or berths,
## spawn projectiles, or call RPC; server adapters publish here and replicas
## consume the copied result.

const SCHEMA_VERSION := 2
const POLICY_VERSION: StringName = &"network_authoritative_snapshot_v2"
const MAX_SAFE_INTEGER := 9_007_199_254_740_991
const MAX_ENTRIES_PER_SECTION := 256
const LANDING_STATES := [&"flying", &"landing_pending", &"landed"]
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
	&"ownership": [&"ship_id", &"ship_generation", &"owner_peer_id", &"ownership_generation"],
	&"projectiles": [
		&"projectile_id", &"projectile_generation", &"source_entity_id",
		&"source_generation", &"state",
	],
	&"boarding": [
		&"seat_id", &"seat_generation", &"occupant_peer_id", &"avatar_id",
		&"vessel_id", &"role",
	],
	&"respawn": [
		&"entity_id", &"entity_generation", &"component_generation", &"state",
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
	_server_tick = server_tick
	_event_sequence = event_sequence
	_revision += 1
	_sections = _copy_sections(incoming)
	_remember_landing_progress(landing)
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
	_server_tick = server_tick
	_event_sequence = event_sequence
	_revision = revision
	_sections = _copy_sections(incoming_variant as Dictionary)
	_remember_landing_progress(landing)
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
		"server_owns_boarding_snapshot": true,
		"server_owns_respawn_snapshot": true,
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
	return {"valid": true}


func _valid_landing_entry(entry: Dictionary) -> bool:
	var position_variant: Variant = entry.get("position")
	return _valid_positive_integer(entry.get("landing_revision")) \
		and _valid_nonnegative_integer(entry.get("landing_server_tick")) \
		and position_variant is Vector3 \
		and (position_variant as Vector3).is_finite() \
		and StringName(entry.get("state", &"")) in LANDING_STATES


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
		if field == &"ownership_generation":
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
	if section_name == &"boarding" and int(entry.get("occupant_peer_id", 0)) <= 0:
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
