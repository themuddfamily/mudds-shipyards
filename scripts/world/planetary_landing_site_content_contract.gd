class_name PlanetaryLandingSiteContentContract
extends Resource

## Bounded authored content declaration for one visitable planetary landing site.
##
## This is a handoff manifest only. It does not load scenes, stream terrain,
## move actors, resolve activities, grant rewards, or persist a visit.

const SCHEMA_VERSION := 1
const CONTENT_CLASS: StringName = &"NEW"
const EVIDENCE_STATUS: StringName = &"modern_interpretation"
const MAX_ID_LENGTH := 64
const MAX_NAME_LENGTH := 96
const MAX_IDS := 32
const MIN_LANDMARKS := 3
const MIN_ROUTE_LENGTH_M := 4.0
const MAX_ROUTE_LENGTH_M := 100_000.0
const MIN_LANDING_AREA_M2 := 1_024.0
const MAX_LANDING_AREA_M2 := 100_000_000.0

@export_category("Identity")
@export var world_id: StringName = &"ember_moon"
@export var site_id: StringName = &"ember_caldera"
@export var display_name := "Ember Caldera"
@export var return_target_id: StringName = &"mudds_shipyards"

@export_category("Authored handoff references")
@export_file(".tscn") var scene_path := "res://scenes/world/planets/ember_moon.tscn"
@export_file(".tres") var world_definition_path := "res://assets/world/planets/ember_moon_world.tres"
@export_file(".tres") var landing_region_path := "res://assets/world/planets/ember_caldera_landing_region.tres"
@export var landmark_ids := PackedStringArray([
	"ember_pad_guidance_port", "ember_sample_rack", "ember_staging_relay",
])
@export var route_anchor_ids := PackedStringArray([
	"ember_pad_guidance_port", "ember_staging_relay",
])
@export var activity_ids := PackedStringArray(["caldera_relay_scan"])
@export var reward_ids := PackedStringArray(["ember_relay_data"])
@export var recovery_ids := PackedStringArray([
	"return_to_landed_ship", "abort_to_orbit_return",
])

@export_category("Authored scale")
@export_range(MIN_LANDING_AREA_M2, MAX_LANDING_AREA_M2, 1.0)
var landing_area_m2 := 9_216.0
@export_range(MIN_ROUTE_LENGTH_M, MAX_ROUTE_LENGTH_M, 0.1)
var route_length_m := 96.0

@export_category("Authority and evidence")
@export var activity_authority_id: StringName = &"activity_director"
@export var reward_authority_id: StringName = &"game_flow_reward_authority"
@export var recovery_authority_id: StringName = &"planetary_landing_return_contract"
@export var evidence_references := PackedStringArray([
	"res://docs/PLANETARY_DESTINATION_CONTENT_CONTRACT.md",
])
@export_multiline var evidence_notes := "Bounded authored landing-site content; modern interpretation only."


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	_validate_id(errors, "world_id", world_id)
	_validate_id(errors, "site_id", site_id)
	_validate_id(errors, "return_target_id", return_target_id)
	_validate_id(errors, "activity_authority_id", activity_authority_id)
	_validate_id(errors, "reward_authority_id", reward_authority_id)
	_validate_id(errors, "recovery_authority_id", recovery_authority_id)
	if display_name.is_empty() or display_name.length() > MAX_NAME_LENGTH or display_name.contains("\n"):
		errors.append("display_name must be bounded single-line copy")
	_validate_path(errors, "scene_path", scene_path, ".tscn")
	_validate_path(errors, "world_definition_path", world_definition_path, ".tres")
	_validate_path(errors, "landing_region_path", landing_region_path, ".tres")
	_validate_id_list(errors, "landmark_ids", landmark_ids, MIN_LANDMARKS)
	_validate_id_list(errors, "route_anchor_ids", route_anchor_ids, 2)
	_validate_id_list(errors, "activity_ids", activity_ids, 1)
	_validate_id_list(errors, "reward_ids", reward_ids, 1)
	_validate_id_list(errors, "recovery_ids", recovery_ids, 1)
	if not is_finite(landing_area_m2) or landing_area_m2 < MIN_LANDING_AREA_M2 or landing_area_m2 > MAX_LANDING_AREA_M2:
		errors.append("landing_area_m2 is outside authored bounds")
	if not is_finite(route_length_m) or route_length_m < MIN_ROUTE_LENGTH_M or route_length_m > MAX_ROUTE_LENGTH_M:
		errors.append("route_length_m is outside authored bounds")
	if evidence_references.is_empty():
		errors.append("evidence_references must contain an authored record")
	return errors


func is_definition_valid() -> bool:
	return get_validation_errors().is_empty()


func get_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"identity": {"world_id": world_id, "site_id": site_id, "display_name": display_name, "return_target_id": return_target_id},
		"references": {"scene_path": scene_path, "world_definition_path": world_definition_path, "landing_region_path": landing_region_path},
		"content": {"landmark_ids": landmark_ids.duplicate(), "route_anchor_ids": route_anchor_ids.duplicate(), "landing_area_m2": landing_area_m2, "route_length_m": route_length_m},
		"handoffs": {"activity_ids": activity_ids.duplicate(), "reward_ids": reward_ids.duplicate(), "recovery_ids": recovery_ids.duplicate(), "activity_authority_id": activity_authority_id, "reward_authority_id": reward_authority_id, "recovery_authority_id": recovery_authority_id},
		"evidence": {"content_class": CONTENT_CLASS, "status": EVIDENCE_STATUS, "historical_claim": false, "references": evidence_references.duplicate()},
		"authority": {"movement": false, "streaming": false, "activity": false, "reward": false, "save": false, "network": false},
	}.duplicate(true)


func _validate_id_list(errors: PackedStringArray, field_name: String, values: PackedStringArray, minimum: int) -> void:
	if values.size() < minimum or values.size() > MAX_IDS:
		errors.append("%s must contain %d to %d IDs" % [field_name, minimum, MAX_IDS])
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
	if value.is_empty() or not value.begins_with("res://") or not value.ends_with(suffix):
		errors.append("%s must be a bounded res:// path" % field_name)
