class_name PlanetaryDestinationContentContract
extends Resource

## Authored content manifest for one visitable planetary destination.
##
## This is a data-only join between the already-authored world, landing region,
## surface route, activity, and return authorities. It does not load scenes,
## stream terrain, move a ship/player, resolve activities, grant rewards, or
## persist session state. A production owner may use the validated IDs as
## handoff keys, but this Resource never becomes that owner.

const SCHEMA_VERSION := 1
const CONTENT_CLASS: StringName = &"NEW"
const EVIDENCE_STATUS: StringName = &"modern_interpretation"
const EVIDENCE_SCOPE: StringName = &"authored_planetary_destination_content"
const MAX_ID_LENGTH := 64
const MAX_DISPLAY_NAME_LENGTH := 96
const MAX_NOTE_LENGTH := 512
const MAX_SCENE_PATH_LENGTH := 256
const MAX_CONTENT_ITEMS := 32
const MIN_ORBITAL_LANDMARKS := 2
const MIN_SURFACE_LANDMARKS := 3
const MIN_LANDING_AREA_M2 := 1024.0
const MAX_LANDING_AREA_M2 := 100_000_000.0
const MAX_SILHOUETTE_RADIUS_M := 100_000_000.0

@export_category("Identity")
@export var world_id: StringName = &"ember_moon"
@export var display_name := "Ember Moon"
@export var orbital_silhouette_id: StringName = &"ember_moon_airless_caldera"
@export var return_target_id: StringName = &"mudds_shipyards"

@export_category("Authored references")
@export_file(".tscn") var scene_path := "res://scenes/world/planets/ember_moon.tscn"
@export_file(".tres") var world_definition_path := "res://assets/world/planets/ember_moon_world.tres"
@export_file(".tres") var landing_region_path := "res://assets/world/planets/ember_caldera_landing_region.tres"
@export var landing_region_ids := PackedStringArray(["ember_caldera"])
@export var orbital_landmark_ids := PackedStringArray([
	"ember_orbit_entry", "ember_navigation", "ember_surface_entry",
])
@export var surface_landmark_ids := PackedStringArray([
	"ember_pad_guidance_port", "ember_sample_rack", "ember_staging_relay",
])
@export var surface_route_ids := PackedStringArray(["ember_caldera_pad_to_staging"])

@export_category("Activity and recovery handoffs")
## IDs are resolved by existing activity/reward owners; this manifest owns no
## activity lifecycle or reward inventory.
@export var activity_ids := PackedStringArray(["caldera_relay_scan"])
@export var reward_ids := PackedStringArray(["ember_relay_data"])
@export var failure_recovery_ids := PackedStringArray([
	"return_to_landed_ship", "abort_to_orbit_return",
])
@export var activity_authority_id: StringName = &"activity_director"
@export var reward_authority_id: StringName = &"game_flow_reward_authority"
@export var recovery_authority_id: StringName = &"planetary_landing_return_contract"

@export_category("Authored scale")
## The radius is a content witness, not a replacement for the world definition
## datum. Composition callers must compare both values before using the entry.
@export_range(1.0, MAX_SILHOUETTE_RADIUS_M, 1.0) var orbital_silhouette_radius_m := 120_000.0
@export_range(MIN_LANDING_AREA_M2, MAX_LANDING_AREA_M2, 1.0) var substantial_landing_area_m2 := 9_216.0

@export_category("Evidence")
@export var evidence_references := PackedStringArray([
	"res://docs/PLANETARY_DESTINATION_CONTENT_CONTRACT.md",
])
@export_multiline var evidence_notes := (
	"Original modern Ember Moon content manifest. IDs describe bounded authored "
	+ "handoffs and make no historical, procedural-galaxy, or production-completion claim."
)


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	_validate_id(errors, "world_id", world_id)
	_validate_id(errors, "orbital_silhouette_id", orbital_silhouette_id)
	_validate_id(errors, "return_target_id", return_target_id)
	_validate_ui_copy(errors, "display_name", display_name, MAX_DISPLAY_NAME_LENGTH)
	_validate_path(errors, "scene_path", scene_path, ".tscn")
	_validate_path(errors, "world_definition_path", world_definition_path, ".tres")
	_validate_path(errors, "landing_region_path", landing_region_path, ".tres")
	_validate_id(errors, "activity_authority_id", activity_authority_id)
	_validate_id(errors, "reward_authority_id", reward_authority_id)
	_validate_id(errors, "recovery_authority_id", recovery_authority_id)
	_validate_id_list(errors, "landing_region_ids", landing_region_ids, 1)
	_validate_id_list(errors, "orbital_landmark_ids", orbital_landmark_ids, MIN_ORBITAL_LANDMARKS)
	_validate_id_list(errors, "surface_landmark_ids", surface_landmark_ids, MIN_SURFACE_LANDMARKS)
	_validate_id_list(errors, "surface_route_ids", surface_route_ids, 1)
	_validate_id_list(errors, "activity_ids", activity_ids, 1)
	_validate_id_list(errors, "reward_ids", reward_ids, 1)
	_validate_id_list(errors, "failure_recovery_ids", failure_recovery_ids, 1)
	if not is_finite(orbital_silhouette_radius_m) or orbital_silhouette_radius_m <= 0.0 \
		or orbital_silhouette_radius_m > MAX_SILHOUETTE_RADIUS_M:
		errors.append("orbital_silhouette_radius_m must be finite and positive")
	if not is_finite(substantial_landing_area_m2) \
		or substantial_landing_area_m2 < MIN_LANDING_AREA_M2 \
		or substantial_landing_area_m2 > MAX_LANDING_AREA_M2:
		errors.append("substantial_landing_area_m2 must be within the authored bound")
	if not _valid_resource_reference(scene_path, PackedScene):
		errors.append("scene_path must resolve to an authored PackedScene")
	if not _valid_resource_reference(world_definition_path, PlanetaryWorldDefinition):
		errors.append("world_definition_path must resolve to a PlanetaryWorldDefinition")
	if not _valid_resource_reference(landing_region_path, PlanetaryLandingRegionDefinition):
		errors.append("landing_region_path must resolve to a PlanetaryLandingRegionDefinition")
	if evidence_references.is_empty():
		errors.append("evidence_references must contain at least one authored record")
	for reference in evidence_references:
		if String(reference).length() > MAX_SCENE_PATH_LENGTH:
			errors.append("evidence reference exceeds the bounded path length")
	if evidence_notes.length() > MAX_NOTE_LENGTH:
		errors.append("evidence_notes exceeds the bounded note length")
	return errors


func is_definition_valid() -> bool:
	return get_validation_errors().is_empty()


func get_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"unit_system": &"game_scale_si",
		"identity": {
			"world_id": world_id,
			"display_name": display_name,
			"orbital_silhouette_id": orbital_silhouette_id,
			"return_target_id": return_target_id,
		},
		"references": {
			"scene_path": scene_path,
			"world_definition_path": world_definition_path,
			"landing_region_path": landing_region_path,
		},
		"authored_content": {
			"landing_region_ids": landing_region_ids.duplicate(),
			"orbital_landmark_ids": orbital_landmark_ids.duplicate(),
			"surface_landmark_ids": surface_landmark_ids.duplicate(),
			"surface_route_ids": surface_route_ids.duplicate(),
			"orbital_silhouette_radius_m": orbital_silhouette_radius_m,
			"substantial_landing_area_m2": substantial_landing_area_m2,
		},
		"handoffs": {
			"activity_ids": activity_ids.duplicate(),
			"reward_ids": reward_ids.duplicate(),
			"failure_recovery_ids": failure_recovery_ids.duplicate(),
			"activity_authority_id": activity_authority_id,
			"reward_authority_id": reward_authority_id,
			"recovery_authority_id": recovery_authority_id,
		},
		"evidence": {
			"content_class": CONTENT_CLASS,
			"status": EVIDENCE_STATUS,
			"scope": EVIDENCE_SCOPE,
			"historical_claim": false,
			"references": evidence_references.duplicate(),
		},
		"authority": _authority_snapshot(),
	}.duplicate(true)


func get_audit_report() -> Dictionary:
	var errors := get_validation_errors()
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"snapshot": get_snapshot(),
		"authority": _authority_snapshot(),
	}.duplicate(true)


func _authority_snapshot() -> Dictionary:
	return {
		"renderer": false,
		"gameplay": false,
		"streaming": false,
		"activity": false,
		"reward": false,
		"recovery": false,
		"save": false,
		"network": false,
		"terrain_generation": false,
		"collision_generation": false,
	}


func _validate_id_list(
		errors: PackedStringArray,
		field_name: String,
		values: PackedStringArray,
		minimum_count: int
	) -> void:
	if values.size() < minimum_count or values.size() > MAX_CONTENT_ITEMS:
		errors.append("%s must contain %d to %d unique IDs" % [field_name, minimum_count, MAX_CONTENT_ITEMS])
	var seen := {}
	for index in values.size():
		var value := StringName(values[index])
		_validate_id(errors, "%s[%d]" % [field_name, index], value)
		if seen.has(value):
			errors.append("%s must not contain duplicate IDs: %s" % [field_name, value])
		seen[value] = true


func _validate_id(errors: PackedStringArray, field_name: String, value: StringName) -> void:
	var text := String(value)
	if text.is_empty() or text.length() > MAX_ID_LENGTH or text.begins_with("_") \
		or text.ends_with("_") or text.contains("__"):
		errors.append("%s must be a lowercase snake_case identifier" % field_name)
		return
	for code in text.to_ascii_buffer():
		if not ((code >= 97 and code <= 122) or (code >= 48 and code <= 57) or code == 95):
			errors.append("%s must be a lowercase snake_case identifier" % field_name)
			return


func _validate_ui_copy(errors: PackedStringArray, field_name: String, value: String, maximum: int) -> void:
	if value.is_empty() or value.length() > maximum or value.contains("\n"):
		errors.append("%s must be bounded single-line copy" % field_name)


func _validate_path(errors: PackedStringArray, field_name: String, value: String, suffix: String) -> void:
	if value.is_empty() or value.length() > MAX_SCENE_PATH_LENGTH \
		or not value.begins_with("res://") or not value.ends_with(suffix):
		errors.append("%s must be a bounded res:// %s path" % [field_name, suffix])


func _valid_resource_reference(path: String, expected_type: Variant) -> bool:
	if path.is_empty() or not ResourceLoader.exists(path):
		return false
	var resource := ResourceLoader.load(path)
	return resource != null and is_instance_of(resource, expected_type)
