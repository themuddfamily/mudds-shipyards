class_name PlanetarySettlementHazardEvidenceRollup
extends RefCounted

## Detached evidence rollup for the authored settlement and hazard manifests.
##
## This seam joins already-authored content without becoming a settlement,
## hazard, navigation, activity, reward, recovery, or streaming authority. It
## is deliberately a rollup: callers may replace either source with a detached
## snapshot and receive a rejection rather than silently accepting drift.

const SettlementScript := preload("res://scripts/world/planetary_settlement_structure_contract.gd")
const HazardScript := preload("res://scripts/world/planetary_surface_hazard_content_contract.gd")

const SCHEMA_VERSION := 1
const MAX_ITEMS := 32
const MIN_SETTLEMENT_LANDMARKS := 4
const MIN_SETTLEMENT_STRUCTURES := 3
const MIN_SETTLEMENT_HAZARDS := 2
const MIN_SURFACE_HAZARDS := 2
const REQUIRED_WORLD_ID: StringName = &"ember_moon"
const REQUIRED_LANDING_REGION_ID: StringName = &"ember_caldera"
const REQUIRED_RETURN_TARGET_ID: StringName = &"mudds_shipyards"
const REQUIRED_ACTIVITY_AUTHORITY_ID: StringName = &"activity_director"
const REQUIRED_REWARD_AUTHORITY_ID: StringName = &"game_flow_reward_authority"
const REQUIRED_RECOVERY_AUTHORITY_ID: StringName = &"planetary_landing_return_contract"

var _settlement_snapshot: Dictionary = {}
var _hazard_snapshot: Dictionary = {}
var _configuration_errors := PackedStringArray()


func _init(
		settlement_snapshot: Dictionary = {},
		hazard_snapshot: Dictionary = {}
	) -> void:
	if settlement_snapshot.is_empty():
		settlement_snapshot = SettlementScript.new().get_snapshot()
	if hazard_snapshot.is_empty():
		hazard_snapshot = HazardScript.new().get_snapshot()
	_settlement_snapshot = settlement_snapshot.duplicate(true)
	_hazard_snapshot = hazard_snapshot.duplicate(true)
	_configuration_errors = _validate_sources(_settlement_snapshot, _hazard_snapshot)


func is_definition_valid() -> bool:
	return _configuration_errors.is_empty()


func get_validation_errors() -> PackedStringArray:
	return _configuration_errors.duplicate()


## Validate detached source snapshots without retaining caller-owned data.
func validate_sources(settlement_snapshot: Dictionary, hazard_snapshot: Dictionary) -> Dictionary:
	var errors := _validate_sources(settlement_snapshot, hazard_snapshot)
	return {
		"accepted": errors.is_empty(),
		"reason": &"settlement_hazard_evidence_valid" if errors.is_empty() else &"settlement_hazard_evidence_rejected",
		"errors": errors,
		"snapshot": _build_snapshot(settlement_snapshot, hazard_snapshot),
	}.duplicate(true)


func get_snapshot() -> Dictionary:
	return _build_snapshot(_settlement_snapshot, _hazard_snapshot)


func get_audit_report() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": is_definition_valid(),
		"errors": get_validation_errors(),
		"snapshot": get_snapshot(),
		"production_wiring": false,
		"authority": get_authority_report(),
	}.duplicate(true)


func get_authority_report() -> Dictionary:
	return {
		"renderer": false,
		"terrain": false,
		"navigation": false,
		"settlement": false,
		"hazard": false,
		"activity": false,
		"reward": false,
		"recovery": false,
		"streaming": false,
		"save": false,
		"network": false,
	}.duplicate(true)


func _build_snapshot(settlement: Dictionary, hazards: Dictionary) -> Dictionary:
	var settlement_identity: Dictionary = settlement.get("identity", {})
	var hazard_identity: Dictionary = hazards.get("identity", {})
	var settlement_landmarks: Array = settlement.get("landmarks", [])
	var settlement_structures: Array = settlement.get("structures", [])
	var settlement_hazard_records: Array = settlement.get("hazards", [])
	var surface_hazard_records: Array = hazards.get("hazards", [])
	var settlement_routes := _route_ids_from_records(settlement_landmarks)
	settlement_routes.append_array(_route_ids_from_records(settlement_structures))
	settlement_routes.append_array(_route_ids_from_records(settlement.get("landing_sites", [])))
	var surface_routes := _route_ids_from_records(hazards.get("landmarks", []))
	return {
		"schema_version": SCHEMA_VERSION,
		"identity": {
			"world_id": StringName(settlement_identity.get("world_id", &"")),
			"landing_region_id": StringName(hazard_identity.get("landing_region_id", &"")),
			"settlement_id": StringName(settlement_identity.get("settlement_id", &"")),
			"return_target_id": StringName(settlement_identity.get("return_target_id", &"")),
		},
		"counts": {
			"settlement_landmarks": settlement_landmarks.size(),
			"settlement_structures": settlement_structures.size(),
			"settlement_hazards": settlement_hazard_records.size(),
			"surface_hazards": surface_hazard_records.size(),
			"surface_hazard_landmarks": (hazards.get("landmarks", []) as Array).size(),
		},
		"routes": {
			"settlement": _unique_strings(settlement_routes),
			"surface_hazard": _unique_strings(surface_routes),
		},
		"handoffs": {
			"activity_authority_id": _handoff_value(settlement, "activity_authority_id"),
			"reward_authority_id": _handoff_value(settlement, "reward_authority_id"),
			"recovery_authority_id": _handoff_value(settlement, "recovery_authority_id"),
			"activity_ids": _merged_ids(settlement, hazards, "activity_ids"),
			"reward_ids": _merged_ids(settlement, hazards, "reward_ids"),
			"recovery_ids": _merged_ids_with_records(settlement, hazards, "recovery_ids", "hazards"),
		},
		"evidence": {
			"content_class": &"NEW",
			"status": &"modern_interpretation",
			"historical_claim": false,
			"procedural_generation": false,
			"settlement_references": _evidence_references(settlement),
			"hazard_references": _evidence_references(hazards),
		},
		"authority": get_authority_report(),
	}.duplicate(true)


func _validate_sources(settlement: Dictionary, hazards: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	if settlement.is_empty():
		errors.append("settlement evidence snapshot is required")
	if hazards.is_empty():
		errors.append("surface hazard evidence snapshot is required")
	if not errors.is_empty():
		return errors
	var settlement_identity: Variant = settlement.get("identity", {})
	var hazard_identity: Variant = hazards.get("identity", {})
	if not settlement_identity is Dictionary:
		errors.append("settlement identity must be a dictionary")
	if not hazard_identity is Dictionary:
		errors.append("surface hazard identity must be a dictionary")
	if not errors.is_empty():
		return errors
	var si := settlement_identity as Dictionary
	var hi := hazard_identity as Dictionary
	if StringName(si.get("world_id", &"")) != REQUIRED_WORLD_ID:
		errors.append("settlement world ID must be ember_moon")
	if StringName(hi.get("world_id", &"")) != REQUIRED_WORLD_ID:
		errors.append("surface hazard world ID must match settlement world")
	if StringName(hi.get("landing_region_id", &"")) != REQUIRED_LANDING_REGION_ID:
		errors.append("surface hazard landing region must be ember_caldera")
	if StringName(si.get("return_target_id", &"")) != REQUIRED_RETURN_TARGET_ID:
		errors.append("settlement return target must be mudds_shipyards")
	_validate_evidence(errors, "settlement", settlement.get("evidence", {}))
	_validate_evidence(errors, "surface hazard", hazards.get("evidence", {}))
	_validate_handoffs(errors, settlement, hazards)
	_validate_settlement_content(errors, settlement)
	_validate_surface_hazards(errors, hazards)
	_validate_cross_routes(errors, settlement, hazards)
	return errors


func _validate_evidence(errors: PackedStringArray, label: String, evidence: Variant) -> void:
	if not evidence is Dictionary:
		errors.append("%s evidence must be a dictionary" % label)
		return
	var record := evidence as Dictionary
	if bool(record.get("historical_claim", true)):
		errors.append("%s evidence cannot claim historical authentication" % label)
	if bool(record.get("procedural_generation", true)):
		errors.append("%s evidence cannot claim procedural generation" % label)
	if StringName(record.get("status", &"")) != &"modern_interpretation":
		errors.append("%s evidence status must be modern_interpretation" % label)
	var references: Variant = record.get("references", [])
	if not references is Array and not references is PackedStringArray:
		errors.append("%s evidence references must be an array" % label)
		return
	if references.is_empty():
		errors.append("%s evidence requires at least one reference" % label)
	else:
		for reference in references:
			if not String(reference).begins_with("res://"):
				errors.append("%s evidence references must use res:// paths" % label)


func _validate_handoffs(errors: PackedStringArray, settlement: Dictionary, hazards: Dictionary) -> void:
	var settlement_handoffs: Variant = settlement.get("handoffs", {})
	var hazard_handoffs: Variant = hazards.get("handoffs", {})
	if not settlement_handoffs is Dictionary or not hazard_handoffs is Dictionary:
		errors.append("settlement and hazard handoffs must be dictionaries")
		return
	var sh := settlement_handoffs as Dictionary
	var hh := hazard_handoffs as Dictionary
	for key in ["activity_authority_id", "reward_authority_id", "recovery_authority_id"]:
		if StringName(sh.get(key, &"")) != StringName(hh.get(key, &"")):
			errors.append("settlement and hazard %s must share one authority" % key)
	if StringName(sh.get("activity_authority_id", &"")) != REQUIRED_ACTIVITY_AUTHORITY_ID:
		errors.append("activity handoff must use activity_director")
	if StringName(sh.get("reward_authority_id", &"")) != REQUIRED_REWARD_AUTHORITY_ID:
		errors.append("reward handoff must use game_flow_reward_authority")
	if StringName(sh.get("recovery_authority_id", &"")) != REQUIRED_RECOVERY_AUTHORITY_ID:
		errors.append("recovery handoff must use planetary_landing_return_contract")
	_validate_unique_id_array(errors, "settlement reward", sh.get("reward_ids", []))
	_validate_unique_id_array(errors, "surface hazard reward", hh.get("reward_ids", []))
	var all_rewards := _array_to_strings(sh.get("reward_ids", []))
	all_rewards.append_array(_array_to_strings(hh.get("reward_ids", [])))
	if _unique_strings(all_rewards).size() != all_rewards.size():
		errors.append("settlement and surface hazards must not duplicate reward IDs")
	_validate_nonempty_id_array(errors, "settlement recovery", sh.get("recovery_ids", []))
	var hazard_recoveries: Variant = hh.get("recovery_ids", [])
	if _array_to_strings(hazard_recoveries).is_empty():
		hazard_recoveries = _recovery_ids_from_records(hazards.get("hazards", []))
	_validate_nonempty_id_array(errors, "surface hazard recovery", hazard_recoveries)


func _validate_settlement_content(errors: PackedStringArray, settlement: Dictionary) -> void:
	var landmarks: Variant = settlement.get("landmarks", [])
	var structures: Variant = settlement.get("structures", [])
	var hazards: Variant = settlement.get("hazards", [])
	if not landmarks is Array or (landmarks as Array).size() < MIN_SETTLEMENT_LANDMARKS:
		errors.append("settlement evidence needs multiple navigable landmarks")
	if not structures is Array or (structures as Array).size() < MIN_SETTLEMENT_STRUCTURES:
		errors.append("settlement evidence needs multiple authored structures")
	if not hazards is Array or (hazards as Array).size() < MIN_SETTLEMENT_HAZARDS:
		errors.append("settlement evidence needs recoverable hazards")
	if landmarks is Array:
		_validate_record_ids(errors, "settlement landmark", landmarks as Array)
	if structures is Array:
		_validate_record_ids(errors, "settlement structure", structures as Array)
	if hazards is Array:
		_validate_record_ids(errors, "settlement hazard", hazards as Array)


func _validate_surface_hazards(errors: PackedStringArray, hazards: Dictionary) -> void:
	var records: Variant = hazards.get("hazards", [])
	if not records is Array or (records as Array).size() < MIN_SURFACE_HAZARDS:
		errors.append("surface hazard evidence needs multiple authored hazards")
		return
	_validate_record_ids(errors, "surface hazard", records as Array)
	for index in (records as Array).size():
		var record: Variant = (records as Array)[index]
		if record is Dictionary and StringName((record as Dictionary).get("recovery_id", &"")) == &"":
			errors.append("surface hazard %d must expose a recovery ID" % index)


func _validate_cross_routes(errors: PackedStringArray, settlement: Dictionary, hazards: Dictionary) -> void:
	var route_ids := _route_ids_from_records(settlement.get("landmarks", []))
	route_ids.append_array(_route_ids_from_records(settlement.get("structures", [])))
	route_ids.append_array(_route_ids_from_records(settlement.get("landing_sites", [])))
	route_ids.append_array(_route_ids_from_records(hazards.get("landmarks", [])))
	var routes := {}
	for route_id in route_ids:
		routes[StringName(route_id)] = true
	for record in hazards.get("hazards", []):
		if record is Dictionary:
			var route_id := StringName((record as Dictionary).get("route_id", &""))
			if route_id == &"" or not routes.has(route_id):
				errors.append("surface hazard route must resolve to authored content")


func _validate_record_ids(errors: PackedStringArray, label: String, records: Array) -> void:
	if records.size() > MAX_ITEMS:
		errors.append("%s records exceed the bounded content limit" % label)
	var seen := {}
	for index in records.size():
		var record: Variant = records[index]
		if not record is Dictionary:
			errors.append("%s %d must be a dictionary" % [label, index])
			continue
		var id := StringName((record as Dictionary).get("id", &""))
		if id == &"":
			errors.append("%s %d must have a stable ID" % [label, index])
		elif seen.has(id):
			errors.append("duplicate %s ID" % label)
		seen[id] = true


func _validate_unique_id_array(errors: PackedStringArray, label: String, values: Variant) -> void:
	var ids := _array_to_strings(values)
	if ids.is_empty():
		errors.append("%s IDs must not be empty" % label)
	if _unique_strings(ids).size() != ids.size():
		errors.append("%s IDs must not contain duplicates" % label)


func _validate_nonempty_id_array(errors: PackedStringArray, label: String, values: Variant) -> void:
	var ids := _array_to_strings(values)
	if ids.is_empty():
		errors.append("%s IDs must not be empty" % label)
	for id in ids:
		if id.is_empty():
			errors.append("%s contains an empty ID" % label)


func _route_ids_from_records(records: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if not records is Array:
		return result
	for record in records as Array:
		if record is Dictionary:
			var route_id := StringName((record as Dictionary).get("route_id", &""))
			if route_id != &"":
				result.append(route_id)
	return result


func _array_to_strings(values: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if values is Array or values is PackedStringArray:
		for value in values:
			result.append(StringName(value))
	return result


func _unique_strings(values: Array[StringName]) -> Array[StringName]:
	var result: Array[StringName] = []
	for value in values:
		if not result.has(value):
			result.append(value)
	return result


func _merged_ids(first: Dictionary, second: Dictionary, key: String) -> Array[StringName]:
	var values := _array_to_strings((first.get("handoffs", {}) as Dictionary).get(key, []))
	values.append_array(_array_to_strings((second.get("handoffs", {}) as Dictionary).get(key, [])))
	return _unique_strings(values)


func _merged_ids_with_records(
		first: Dictionary,
		second: Dictionary,
		key: String,
		record_key: String
	) -> Array[StringName]:
	var values := _merged_ids(first, second, key)
	values.append_array(_recovery_ids_from_records(second.get(record_key, [])))
	return _unique_strings(values)


func _recovery_ids_from_records(records: Variant) -> Array[StringName]:
	var values: Array[StringName] = []
	if not records is Array:
		return values
	for record in records as Array:
		if record is Dictionary:
			var recovery_id := StringName((record as Dictionary).get("recovery_id", &""))
			if recovery_id != &"":
				values.append(recovery_id)
	return values


func _handoff_value(source: Dictionary, key: String) -> StringName:
	return StringName((source.get("handoffs", {}) as Dictionary).get(key, &""))


func _evidence_references(source: Dictionary) -> Array:
	var references: Variant = (source.get("evidence", {}) as Dictionary).get("references", [])
	return _array_to_strings(references)
