class_name PlanetaryBiomeWeatherHandoffContract
extends Resource

## Data-only handoff for authored biome/material and weather presentation hints.
##
## This resource does not generate terrain, simulate weather, resolve hazards,
## stream cells, or own gameplay. IDs are opaque references for later world,
## navigation, audio, and presentation authorities.

const SCHEMA_VERSION := 1
const CONTENT_CLASS: StringName = &"NEW"
const EVIDENCE_STATUS: StringName = &"modern_interpretation"
const MAX_ID_LENGTH := 64
const MAX_ITEMS := 16
const MIN_BIOMES := 2
const MIN_WEATHER_PROFILES := 2
const WEATHER_KINDS := [&"clear", &"dust_front", &"thermal_updraft", &"ash_fall"]

@export var world_id: StringName = &"ember_moon"
@export var region_id: StringName = &"ember_caldera"
@export var display_name := "Ember Caldera Biome and Weather Handoff"

@export_category("Authored biome/material layers")
@export var biome_ids := PackedStringArray(["ember_ash_shelf", "ember_sulfur_ridge", "ember_shadow_ice"])
@export var biome_display_names := PackedStringArray(["Ash Shelf", "Sulfur Ridge", "Shadow Ice"])
@export var biome_material_ids := PackedStringArray(["regolith_ash_v1", "sulfur_rock_v1", "shadow_ice_v1"])
@export var biome_route_ids := PackedStringArray(["caldera_pad_to_staging", "caldera_staging_to_ridge", "caldera_shadow_ice_loop"])
@export var biome_altitude_min_m := PackedFloat32Array([120000.0, 120040.0, 120120.0])
@export var biome_altitude_max_m := PackedFloat32Array([120040.0, 120140.0, 120300.0])

@export_category("Authored weather profiles")
@export var weather_profile_ids := PackedStringArray(["ember_clear", "ember_dust_front", "ember_thermal_lift"])
@export var weather_display_names := PackedStringArray(["Clear Ember Sky", "Incoming Dust Front", "Thermal Lift"])
@export var weather_kind_ids := PackedStringArray(["clear", "dust_front", "thermal_updraft"])
@export var weather_audio_hint_ids := PackedStringArray(["surface_wind_low", "surface_dust_surge", "surface_thermal_rumble"])
@export var weather_visibility_scale := PackedFloat32Array([1.0, 0.42, 0.78])
@export var weather_route_ids := PackedStringArray(["caldera_pad_to_staging", "caldera_overlook_route", "caldera_shadow_ice_loop"])

@export_category("Authored references and evidence")
@export_file(".tscn") var scene_path := "res://scenes/world/planets/ember_moon.tscn"
@export var evidence_references := PackedStringArray(["res://docs/PLANETARY_BIOME_WEATHER_HANDOFF_CONTRACT.md"])
@export_multiline var evidence_notes := "Authored biome/material and weather IDs for Ember; no runtime simulation or procedural generation is claimed."


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	_validate_id(errors, "world_id", world_id)
	_validate_id(errors, "region_id", region_id)
	if display_name.is_empty() or display_name.length() > 96 or display_name.contains("\n"):
		errors.append("display_name must be bounded single-line copy")
	_validate_parallel_biomes(errors)
	_validate_parallel_weather(errors)
	_validate_path(errors, "scene_path", scene_path, ".tscn")
	if evidence_references.is_empty():
		errors.append("evidence_references must contain an authored record")
	for reference in evidence_references:
		if String(reference).length() > 256 or not String(reference).begins_with("res://"):
			errors.append("evidence references must be bounded res:// paths")
	return errors


func is_definition_valid() -> bool:
	return get_validation_errors().is_empty()


func get_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"unit_system": &"game_scale_si_body_local",
		"identity": {"world_id": world_id, "region_id": region_id, "display_name": display_name},
		"biomes": _biome_snapshot(),
		"weather_profiles": _weather_snapshot(),
		"references": {"scene_path": scene_path},
		"evidence": {"content_class": CONTENT_CLASS, "status": EVIDENCE_STATUS,
			"historical_claim": false, "procedural_generation": false,
			"references": evidence_references.duplicate()},
		"authority": {"terrain_generation": false, "material_resolution": false,
			"weather_simulation": false, "navigation": false, "audio": false,
			"hazard_resolution": false, "streaming": false, "save": false, "network": false},
	}.duplicate(true)


func get_audit_report() -> Dictionary:
	var errors := get_validation_errors()
	return {"schema_version": SCHEMA_VERSION, "valid": errors.is_empty(),
		"errors": errors, "snapshot": get_snapshot()}.duplicate(true)


func _biome_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in biome_ids.size():
		result.append({"id": StringName(biome_ids[index]), "display_name": String(biome_display_names[index]),
			"material_id": StringName(biome_material_ids[index]), "route_id": StringName(biome_route_ids[index]),
			"altitude_min_m": biome_altitude_min_m[index], "altitude_max_m": biome_altitude_max_m[index]})
	return result


func _weather_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in weather_profile_ids.size():
		result.append({"id": StringName(weather_profile_ids[index]), "display_name": String(weather_display_names[index]),
			"kind": StringName(weather_kind_ids[index]), "audio_hint_id": StringName(weather_audio_hint_ids[index]),
			"visibility_scale": weather_visibility_scale[index], "route_id": StringName(weather_route_ids[index])})
	return result


func _validate_parallel_biomes(errors: PackedStringArray) -> void:
	if biome_ids.size() < MIN_BIOMES or biome_ids.size() > MAX_ITEMS:
		errors.append("biome_ids must contain 2 to %d entries" % MAX_ITEMS)
	var arrays := [biome_display_names.size(), biome_material_ids.size(), biome_route_ids.size(),
		biome_altitude_min_m.size(), biome_altitude_max_m.size()]
	for size in arrays:
		if size != biome_ids.size():
			errors.append("biome fields must be parallel")
			break
	var seen := {}
	for index in biome_ids.size():
		_validate_id(errors, "biome_ids[%d]" % index, StringName(biome_ids[index]))
		if seen.has(biome_ids[index]):
			errors.append("biome IDs must be unique")
		seen[biome_ids[index]] = true
		if index < biome_altitude_min_m.size() and index < biome_altitude_max_m.size():
			if not is_finite(biome_altitude_min_m[index]) or not is_finite(biome_altitude_max_m[index]) or biome_altitude_min_m[index] > biome_altitude_max_m[index]:
				errors.append("biome altitude bounds must be finite and ordered")


func _validate_parallel_weather(errors: PackedStringArray) -> void:
	if weather_profile_ids.size() < MIN_WEATHER_PROFILES or weather_profile_ids.size() > MAX_ITEMS:
		errors.append("weather_profile_ids must contain 2 to %d entries" % MAX_ITEMS)
	var arrays := [weather_display_names.size(), weather_kind_ids.size(), weather_audio_hint_ids.size(), weather_visibility_scale.size(), weather_route_ids.size()]
	for size in arrays:
		if size != weather_profile_ids.size():
			errors.append("weather fields must be parallel")
			break
	var seen := {}
	for index in weather_profile_ids.size():
		_validate_id(errors, "weather_profile_ids[%d]" % index, StringName(weather_profile_ids[index]))
		if seen.has(weather_profile_ids[index]):
			errors.append("weather profile IDs must be unique")
		seen[weather_profile_ids[index]] = true
		if index < weather_kind_ids.size() and not WEATHER_KINDS.has(StringName(weather_kind_ids[index])):
			errors.append("weather kind must be authored")
		if index < weather_visibility_scale.size() and (not is_finite(weather_visibility_scale[index]) or weather_visibility_scale[index] < 0.0 or weather_visibility_scale[index] > 1.0):
			errors.append("weather visibility scale must be in 0..1")


func _validate_id(errors: PackedStringArray, field: String, value: StringName) -> void:
	var text := String(value)
	if text.is_empty() or text.length() > MAX_ID_LENGTH or not text.is_valid_identifier():
		errors.append("%s must be a bounded identifier" % field)


func _validate_path(errors: PackedStringArray, field: String, value: String, extension: String) -> void:
	if value.is_empty() or not value.begins_with("res://") or not value.ends_with(extension):
		errors.append("%s must be a res:// path ending in %s" % [field, extension])
