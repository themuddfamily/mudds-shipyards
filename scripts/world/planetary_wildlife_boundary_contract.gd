class_name PlanetaryWildlifeBoundaryContract
extends Resource

## Explicit wildlife boundary for an authored planetary landing region.
##
## Wildlife is optional content, never an implicit procedural system. The
## default policy deliberately records that this world has no wildlife. If a
## future world opts into wildlife, every creature remains a checked-in,
## body-local authored handoff. This Resource does not spawn, move, simulate,
## damage, reward, or persist an actor.

const SCHEMA_VERSION := 1
const CONTENT_CLASS: StringName = &"NEW"
const EVIDENCE_STATUS: StringName = &"modern_interpretation"
const MAX_ID_LENGTH := 64
const MAX_NAME_LENGTH := 96
const MAX_NOTE_LENGTH := 512
const MAX_ENTRIES := 32
const MIN_HAZARDS := 1
const WILDLIFE_POLICIES := [&"none_authored", &"authored_fixed"]

@export_category("Identity")
@export var world_id: StringName = &"ember_moon"
@export var landing_region_id: StringName = &"ember_caldera"
@export var display_name := "Ember Caldera Wildlife Boundary"

@export_category("Deliberate wildlife choice")
@export var wildlife_policy: StringName = &"none_authored"
@export var deliberately_authored := false
@export var wildlife_ids := PackedStringArray()
@export var wildlife_display_names := PackedStringArray()
@export var wildlife_kind_ids := PackedStringArray()
@export var wildlife_positions_body_local_m := PackedVector3Array()

@export_category("Hazard handoffs")
@export var hazard_ids := PackedStringArray([
	"ember_regolith_collapse",
	"ember_relay_arc",
])
@export var hazard_recovery_ids := PackedStringArray([
	"return_to_landed_ship",
	"safe_recovery_at_staging_relay",
])
@export var hazard_route_ids := PackedStringArray([
	"ember_caldera_pad_to_staging",
	"ember_caldera_pad_to_staging",
])
@export var hazard_authority_id: StringName = &"planetary_surface_hazard_content_contract"
@export var recovery_authority_id: StringName = &"planetary_landing_return_contract"

@export_category("Procedural boundary and evidence")
@export var procedural_spawning := false
@export var evidence_references := PackedStringArray([
	"res://docs/PLANETARY_DESTINATION_CONTENT_CONTRACT.md",
])
@export_multiline var evidence_notes := (
	"Wildlife is deliberately absent from Ember Caldera. Hazards remain "
	+ "authored handoffs with explicit recovery routes; no procedural spawning."
)


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	_validate_id(errors, "world_id", world_id)
	_validate_id(errors, "landing_region_id", landing_region_id)
	if display_name.is_empty() or display_name.length() > MAX_NAME_LENGTH or display_name.contains("\n"):
		errors.append("display_name must be bounded single-line copy")
	if not WILDLIFE_POLICIES.has(wildlife_policy):
		errors.append("wildlife_policy is not an explicit authored boundary")
	if procedural_spawning:
		errors.append("procedural_spawning must remain false")
	_validate_parallel_wildlife(errors)
	_validate_parallel_hazards(errors)
	_validate_id(errors, "hazard_authority_id", hazard_authority_id)
	_validate_id(errors, "recovery_authority_id", recovery_authority_id)
	if evidence_references.is_empty():
		errors.append("evidence_references must contain an authored record")
	for reference in evidence_references:
		if String(reference).length() > 256 or not String(reference).begins_with("res://"):
			errors.append("evidence references must be bounded res:// paths")
	if evidence_notes.length() > MAX_NOTE_LENGTH:
		errors.append("evidence_notes exceeds the bounded note length")
	return errors


func is_definition_valid() -> bool:
	return get_validation_errors().is_empty()


func get_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"unit_system": &"game_scale_si_body_local",
		"identity": {
			"world_id": world_id,
			"landing_region_id": landing_region_id,
			"display_name": display_name,
		},
		"wildlife": {
			"policy": wildlife_policy,
			"deliberately_authored": deliberately_authored,
			"entries": _wildlife_snapshot(),
			"procedural_spawning": false,
		},
		"hazards": _hazard_snapshot(),
		"handoffs": {
			"hazard_authority_id": hazard_authority_id,
			"recovery_authority_id": recovery_authority_id,
		},
		"evidence": {
			"content_class": CONTENT_CLASS,
			"status": EVIDENCE_STATUS,
			"historical_claim": false,
			"procedural_generation": false,
			"references": evidence_references.duplicate(),
		},
		"authority": {
			"wildlife_spawn": false,
			"wildlife_simulation": false,
			"hazard_resolution": false,
			"recovery": false,
			"save": false,
			"network": false,
		},
	}.duplicate(true)


func _wildlife_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in wildlife_ids.size():
		result.append({
			"id": StringName(wildlife_ids[index]),
			"display_name": String(wildlife_display_names[index]) if index < wildlife_display_names.size() else "",
			"kind": StringName(wildlife_kind_ids[index]) if index < wildlife_kind_ids.size() else &"",
			"position_body_local_m": wildlife_positions_body_local_m[index] if index < wildlife_positions_body_local_m.size() else Vector3.ZERO,
		})
	return result


func _hazard_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in hazard_ids.size():
		result.append({
			"id": StringName(hazard_ids[index]),
			"recovery_id": StringName(hazard_recovery_ids[index]) if index < hazard_recovery_ids.size() else &"",
			"route_id": StringName(hazard_route_ids[index]) if index < hazard_route_ids.size() else &"",
		})
	return result


func _validate_parallel_wildlife(errors: PackedStringArray) -> void:
	if wildlife_policy == &"none_authored":
		if deliberately_authored:
			errors.append("none_authored wildlife policy cannot be deliberately_authored")
		if not wildlife_ids.is_empty() or not wildlife_display_names.is_empty() or not wildlife_kind_ids.is_empty() or not wildlife_positions_body_local_m.is_empty():
			errors.append("none_authored wildlife policy must have empty authored entries")
		return
	if wildlife_policy == &"authored_fixed" and not deliberately_authored:
		errors.append("authored_fixed wildlife requires deliberate authorship")
	if wildlife_ids.is_empty() or wildlife_ids.size() > MAX_ENTRIES:
		errors.append("authored_fixed wildlife must contain bounded authored entries")
	if wildlife_display_names.size() != wildlife_ids.size() or wildlife_kind_ids.size() != wildlife_ids.size() or wildlife_positions_body_local_m.size() != wildlife_ids.size():
		errors.append("wildlife authored fields must be parallel to IDs")
	for index in wildlife_ids.size():
		_validate_id(errors, "wildlife id %d" % index, StringName(wildlife_ids[index]))
		if index < wildlife_display_names.size() and _invalid_copy(wildlife_display_names[index]):
			errors.append("wildlife display name %d must be bounded single-line copy" % index)
		if index < wildlife_kind_ids.size():
			_validate_id(errors, "wildlife kind %d" % index, StringName(wildlife_kind_ids[index]))
		if index < wildlife_positions_body_local_m.size() and not _finite_vector(wildlife_positions_body_local_m[index]):
			errors.append("wildlife position %d must be finite" % index)


func _validate_parallel_hazards(errors: PackedStringArray) -> void:
	if hazard_ids.size() < MIN_HAZARDS or hazard_ids.size() > MAX_ENTRIES:
		errors.append("hazard_ids must contain bounded authored hazards")
	if hazard_recovery_ids.size() != hazard_ids.size():
		errors.append("hazard recovery IDs must be parallel to IDs")
	if hazard_route_ids.size() != hazard_ids.size():
		errors.append("hazard routes must be parallel to IDs")
	for index in hazard_ids.size():
		_validate_id(errors, "hazard id %d" % index, StringName(hazard_ids[index]))
		if index < hazard_recovery_ids.size():
			_validate_id(errors, "hazard recovery %d" % index, StringName(hazard_recovery_ids[index]))
		if index < hazard_route_ids.size():
			_validate_id(errors, "hazard route %d" % index, StringName(hazard_route_ids[index]))


func _invalid_copy(value: String) -> bool:
	return value.is_empty() or value.length() > MAX_NAME_LENGTH or value.contains("\n")


func _finite_vector(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)


func _validate_id(errors: PackedStringArray, field_name: String, value: StringName) -> void:
	var text := String(value)
	if text.is_empty() or text.length() > MAX_ID_LENGTH or text.begins_with("_") or text.ends_with("_") or text.contains("__"):
		errors.append("%s must be lowercase snake_case" % field_name)
		return
	for code in text.to_ascii_buffer():
		if not ((code >= 97 and code <= 122) or (code >= 48 and code <= 57) or code == 95):
			errors.append("%s must be lowercase snake_case" % field_name)
			return
