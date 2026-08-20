class_name PlanetarySurfaceHazardContentContract
extends Resource

## Bounded authored landmark and hazard handoff for one planetary landing site.
##
## This is a content declaration, not a generator or gameplay owner. Landmark
## and hazard positions are authored body-local metres. A later production
## owner may resolve the IDs through navigation, activity, reward, save, and
## recovery authorities without this Resource spawning, moving, damaging, or
## rewarding anything.

const SCHEMA_VERSION := 1
const CONTENT_CLASS: StringName = &"NEW"
const EVIDENCE_STATUS: StringName = &"modern_interpretation"
const MAX_ID_LENGTH := 64
const MAX_NAME_LENGTH := 96
const MAX_NOTE_LENGTH := 512
const MAX_CONTENT_ITEMS := 32
const MIN_LANDMARKS := 3
const MIN_HAZARDS := 2
const MIN_ACTIVITY_HANDOFFS := 1
const MIN_REWARD_HANDOFFS := 1
const HAZARD_KIND_IDS := [
	&"unstable_terrain",
	&"exposed_reactor",
	&"dust_surge",
	&"collapsed_structure",
]

@export_category("Identity")
@export var world_id: StringName = &"ember_moon"
@export var landing_region_id: StringName = &"ember_caldera"
@export var display_name := "Ember Caldera Surface Content"

@export_category("Authored landmarks")
@export var landmark_ids := PackedStringArray([
	"ember_pad_guidance_port",
	"ember_sample_rack",
	"ember_staging_relay",
	"ember_caldera_overlook",
])
@export var landmark_display_names := PackedStringArray([
	"Guidance Port",
	"Sample Rack",
	"Staging Relay",
	"Caldera Overlook",
])
@export var landmark_positions_body_local_m := PackedVector3Array([
	Vector3(18.0, 120000.0, 0.0),
	Vector3(42.0, 120000.0, 0.0),
	Vector3(96.0, 120000.0, 0.0),
	Vector3(420.0, 120025.0, -180.0),
])
@export var landmark_route_ids := PackedStringArray([
	"ember_caldera_pad_to_staging",
	"ember_caldera_pad_to_staging",
	"ember_caldera_pad_to_staging",
	"ember_caldera_overlook_route",
])
@export var landmark_kinds := PackedStringArray([
	"landing_pad",
	"sample_station",
	"relay",
	"overlook",
])

@export_category("Recoverable authored hazards")
@export var hazard_ids := PackedStringArray([
	"ember_regolith_collapse",
	"ember_relay_arc",
	"ember_dust_surge",
])
@export var hazard_display_names := PackedStringArray([
	"Regolith Collapse",
	"Relay Arc",
	"Dust Surge",
])
@export var hazard_positions_body_local_m := PackedVector3Array([
	Vector3(164.0, 120001.0, 8.0),
	Vector3(92.0, 120001.0, -5.0),
	Vector3(260.0, 120012.0, -94.0),
])
@export var hazard_kind_ids := PackedStringArray([
	"unstable_terrain",
	"exposed_reactor",
	"dust_surge",
])
@export var hazard_recovery_ids := PackedStringArray([
	"return_to_landed_ship",
	"safe_recovery_at_staging_relay",
	"abort_to_orbit_return",
])
@export var hazard_route_ids := PackedStringArray([
	"ember_caldera_pad_to_staging",
	"ember_caldera_pad_to_staging",
	"ember_caldera_overlook_route",
])

@export_category("Activity and reward handoffs")
@export var activity_ids := PackedStringArray([
	"caldera_relay_scan",
	"regolith_sample_recovery",
])
@export var reward_ids := PackedStringArray([
	"ember_relay_data",
	"ember_sample_cache",
])
@export var activity_authority_id: StringName = &"activity_director"
@export var reward_authority_id: StringName = &"game_flow_reward_authority"
@export var recovery_authority_id: StringName = &"planetary_landing_return_contract"

@export_category("Authored references and evidence")
@export_file(".tscn") var scene_path := "res://scenes/world/planets/ember_moon.tscn"
@export_file(".tres") var landing_region_path := "res://assets/world/planets/ember_caldera_landing_region.tres"
@export var evidence_references := PackedStringArray([
	"res://docs/PLANETARY_DESTINATION_CONTENT_CONTRACT.md",
])
@export_multiline var evidence_notes := (
	"Bounded modern Ember content: fixed landmarks, recoverable hazards, and "
	+ "opaque activity/reward handoffs. No procedural generation is implied."
)


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	_validate_id(errors, "world_id", world_id)
	_validate_id(errors, "landing_region_id", landing_region_id)
	if display_name.is_empty() or display_name.length() > MAX_NAME_LENGTH or display_name.contains("\n"):
		errors.append("display_name must be bounded single-line copy")
	_validate_path(errors, "scene_path", scene_path, ".tscn")
	_validate_path(errors, "landing_region_path", landing_region_path, ".tres")
	_validate_parallel_landmarks(errors)
	_validate_parallel_hazards(errors)
	_validate_id_list(errors, "activity_ids", activity_ids, MIN_ACTIVITY_HANDOFFS)
	_validate_id_list(errors, "reward_ids", reward_ids, MIN_REWARD_HANDOFFS)
	_validate_id(errors, "activity_authority_id", activity_authority_id)
	_validate_id(errors, "reward_authority_id", reward_authority_id)
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
		"landmarks": _landmark_snapshot(),
		"hazards": _hazard_snapshot(),
		"handoffs": {
			"activity_ids": activity_ids.duplicate(),
			"reward_ids": reward_ids.duplicate(),
			"activity_authority_id": activity_authority_id,
			"reward_authority_id": reward_authority_id,
			"recovery_authority_id": recovery_authority_id,
		},
		"references": {
			"scene_path": scene_path,
			"landing_region_path": landing_region_path,
		},
		"evidence": {
			"content_class": CONTENT_CLASS,
			"status": EVIDENCE_STATUS,
			"historical_claim": false,
			"procedural_generation": false,
			"references": evidence_references.duplicate(),
		},
		"authority": {
			"renderer": false,
			"terrain_generation": false,
			"streaming": false,
			"movement": false,
			"hazard_resolution": false,
			"activity": false,
			"reward": false,
			"recovery": false,
			"save": false,
			"network": false,
		},
	}.duplicate(true)


func get_audit_report() -> Dictionary:
	var errors := get_validation_errors()
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"snapshot": get_snapshot(),
	}.duplicate(true)


func _landmark_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in landmark_ids.size():
		result.append({
			"id": StringName(landmark_ids[index]),
			"display_name": String(landmark_display_names[index]) if index < landmark_display_names.size() else "",
			"position_body_local_m": landmark_positions_body_local_m[index] if index < landmark_positions_body_local_m.size() else Vector3.ZERO,
			"route_id": StringName(landmark_route_ids[index]) if index < landmark_route_ids.size() else &"",
			"kind": StringName(landmark_kinds[index]) if index < landmark_kinds.size() else &"",
		})
	return result


func _hazard_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in hazard_ids.size():
		result.append({
			"id": StringName(hazard_ids[index]),
			"display_name": String(hazard_display_names[index]) if index < hazard_display_names.size() else "",
			"position_body_local_m": hazard_positions_body_local_m[index] if index < hazard_positions_body_local_m.size() else Vector3.ZERO,
			"kind": StringName(hazard_kind_ids[index]) if index < hazard_kind_ids.size() else &"",
			"recovery_id": StringName(hazard_recovery_ids[index]) if index < hazard_recovery_ids.size() else &"",
			"route_id": StringName(hazard_route_ids[index]) if index < hazard_route_ids.size() else &"",
		})
	return result


func _validate_parallel_landmarks(errors: PackedStringArray) -> void:
	_validate_id_list(errors, "landmark_ids", landmark_ids, MIN_LANDMARKS)
	if landmark_display_names.size() != landmark_ids.size():
		errors.append("landmark display names must be parallel to IDs")
	if landmark_positions_body_local_m.size() != landmark_ids.size():
		errors.append("landmark positions must be parallel to IDs")
	if landmark_route_ids.size() != landmark_ids.size():
		errors.append("landmark routes must be parallel to IDs")
	if landmark_kinds.size() != landmark_ids.size():
		errors.append("landmark kinds must be parallel to IDs")
	for index in landmark_ids.size():
		if index < landmark_display_names.size() and _invalid_copy(landmark_display_names[index]):
			errors.append("landmark display name %d must be bounded single-line copy" % index)
		if index < landmark_positions_body_local_m.size() and not _finite_vector(landmark_positions_body_local_m[index]):
			errors.append("landmark position %d must be finite" % index)
		if index < landmark_route_ids.size():
			_validate_id(errors, "landmark route %d" % index, StringName(landmark_route_ids[index]))
		if index < landmark_kinds.size():
			_validate_id(errors, "landmark kind %d" % index, StringName(landmark_kinds[index]))


func _validate_parallel_hazards(errors: PackedStringArray) -> void:
	_validate_id_list(errors, "hazard_ids", hazard_ids, MIN_HAZARDS)
	if hazard_display_names.size() != hazard_ids.size():
		errors.append("hazard display names must be parallel to IDs")
	if hazard_positions_body_local_m.size() != hazard_ids.size():
		errors.append("hazard positions must be parallel to IDs")
	if hazard_kind_ids.size() != hazard_ids.size():
		errors.append("hazard kinds must be parallel to IDs")
	if hazard_recovery_ids.size() != hazard_ids.size():
		errors.append("hazard recovery IDs must be parallel to IDs")
	if hazard_route_ids.size() != hazard_ids.size():
		errors.append("hazard routes must be parallel to IDs")
	for index in hazard_ids.size():
		if index < hazard_display_names.size() and _invalid_copy(hazard_display_names[index]):
			errors.append("hazard display name %d must be bounded single-line copy" % index)
		if index < hazard_positions_body_local_m.size() and not _finite_vector(hazard_positions_body_local_m[index]):
			errors.append("hazard position %d must be finite" % index)
		if index < hazard_kind_ids.size():
			var kind := StringName(hazard_kind_ids[index])
			if not HAZARD_KIND_IDS.has(kind):
				errors.append("hazard kind %d is not in the authored hazard catalog" % index)
		if index < hazard_recovery_ids.size():
			_validate_id(errors, "hazard recovery %d" % index, StringName(hazard_recovery_ids[index]))
		if index < hazard_route_ids.size():
			_validate_id(errors, "hazard route %d" % index, StringName(hazard_route_ids[index]))


func _validate_id_list(errors: PackedStringArray, field_name: String, values: PackedStringArray, minimum: int) -> void:
	if values.size() < minimum or values.size() > MAX_CONTENT_ITEMS:
		errors.append("%s must contain %d to %d IDs" % [field_name, minimum, MAX_CONTENT_ITEMS])
	var seen := {}
	for value in values:
		_validate_id(errors, "%s item" % field_name, StringName(value))
		if seen.has(value):
			errors.append("%s must not contain duplicate IDs" % field_name)
		seen[value] = true


func _validate_id(errors: PackedStringArray, field_name: String, value: StringName) -> void:
	var text := String(value)
	if text.is_empty() or text.length() > MAX_ID_LENGTH or text.begins_with("_") or text.ends_with("_") or text.contains("__"):
		errors.append("%s must be lowercase snake_case" % field_name)
		return
	for code in text.to_ascii_buffer():
		if not ((code >= 97 and code <= 122) or (code >= 48 and code <= 57) or code == 95):
			errors.append("%s must be lowercase snake_case" % field_name)
			return


func _validate_path(errors: PackedStringArray, field_name: String, value: String, suffix: String) -> void:
	if value.is_empty() or value.length() > 256 or not value.begins_with("res://") or not value.ends_with(suffix):
		errors.append("%s must be a bounded res:// path" % field_name)


func _invalid_copy(value: String) -> bool:
	return value.is_empty() or value.length() > MAX_NAME_LENGTH or value.contains("\n")


func _finite_vector(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)
