class_name PlanetaryAtmosphereProfile
extends Resource

## Strict, data-only description of one game-scale planetary atmosphere.
##
## Every distance is metres, velocity is metres per second, density is kilograms
## per cubic metre, optical coefficients are inverse metres, gain is decibels,
## and normalized controls are unitless. Consumers decide how to render, play,
## simulate, persist, or synchronize these hints.

const SCHEMA_VERSION := 1
const UNIT_SYSTEM: StringName = &"game_scale_si"
const CONTENT_CLASS: StringName = &"NEW"
const EVIDENCE_STATUS: StringName = &"modern_interpretation"
const EVIDENCE_SCOPE: StringName = &"game_scale_atmosphere_parameters"
const MAX_EVIDENCE_REFERENCES := 32
const MAX_EVIDENCE_REFERENCE_LENGTH := 192

const MIN_PLANET_RADIUS_M := 1_000.0
const MAX_PLANET_RADIUS_M := 100_000_000.0
const MAX_ATMOSPHERE_ALTITUDE_M := 10_000_000.0
const MAX_DENSITY_KG_M3 := 100.0
const MAX_DENSITY_SCALE_HEIGHT_M := 1_000_000.0
const MAX_DENSITY_FALLOFF_EXPONENT := 32.0
const MAX_OPTICAL_COEFFICIENT_PER_M := 1.0
const MAX_VISIBILITY_M := 10_000_000.0
const MAX_WIND_SPEED_MPS := 500.0
const MAX_ENTRY_SPEED_MPS := 100_000.0
const MIN_AUDIO_GAIN_DB := -80.0
const MAX_AUDIO_GAIN_DB := 24.0

@export_category("Identity and evidence")
@export var profile_id: StringName = &"temperate_game_scale"
@export var display_name := "Temperate game-scale atmosphere"
@export var evidence_references := PackedStringArray()
@export_multiline var evidence_notes := "New game-scale tuning profile; not a claim about a historical or real atmosphere."

@export_category("Geometry (metres)")
@export_range(MIN_PLANET_RADIUS_M, MAX_PLANET_RADIUS_M, 1.0) var planet_radius_m := 120_000.0
@export_range(0.0, MAX_ATMOSPHERE_ALTITUDE_M, 1.0) var reference_altitude_m := 0.0
@export_range(1.0, MAX_ATMOSPHERE_ALTITUDE_M, 1.0) var atmosphere_top_altitude_m := 20_000.0

@export_category("Density")
@export_range(0.000001, MAX_DENSITY_KG_M3, 0.000001) var reference_density_kg_m3 := 1.225
@export_range(0.1, MAX_DENSITY_SCALE_HEIGHT_M, 0.1) var density_scale_height_m := 4_000.0
@export_range(0.01, MAX_DENSITY_FALLOFF_EXPONENT, 0.01) var density_falloff_exponent := 1.0

@export_category("Optics (inverse metres)")
@export_color_no_alpha var rayleigh_scattering_per_m := Color(0.0000058, 0.0000135, 0.0000331, 1.0)
@export_color_no_alpha var mie_scattering_per_m := Color(0.000021, 0.000021, 0.000021, 1.0)
@export_color_no_alpha var absorption_per_m := Color(0.0000007, 0.0000019, 0.0000001, 1.0)
@export_range(-0.99, 0.99, 0.01) var mie_anisotropy_unitless := 0.76

@export_category("Visibility and fog")
@export_range(0.1, MAX_VISIBILITY_M, 0.1) var maximum_visibility_m := 20_000.0
@export_range(0.0, MAX_VISIBILITY_M, 0.1) var fog_start_distance_m := 1_500.0
@export_range(0.1, MAX_VISIBILITY_M, 0.1) var fog_end_distance_m := 12_000.0
@export_range(0.0, 1.0, 0.001) var fog_density_unitless := 0.22

@export_category("Cloud layer")
@export_range(0.0, MAX_ATMOSPHERE_ALTITUDE_M, 1.0) var cloud_base_altitude_m := 3_000.0
@export_range(0.0, MAX_ATMOSPHERE_ALTITUDE_M, 1.0) var cloud_top_altitude_m := 6_000.0
@export_range(0.0, 1.0, 0.001) var cloud_coverage_unitless := 0.55

@export_category("Weather")
@export var wind_velocity_mps := Vector3(12.0, 0.0, -4.0)
@export_range(0.0, 1.0, 0.001) var weather_intensity_unitless := 0.35

@export_category("Entry effects")
@export_range(0.0, MAX_ATMOSPHERE_ALTITUDE_M, 1.0) var entry_effect_start_altitude_m := 18_000.0
@export_range(0.0, MAX_ATMOSPHERE_ALTITUDE_M, 1.0) var entry_effect_full_altitude_m := 10_000.0
@export_range(0.0, MAX_ENTRY_SPEED_MPS, 0.1) var entry_effect_minimum_speed_mps := 160.0
@export_range(0.0, MAX_ENTRY_SPEED_MPS, 0.1) var entry_effect_full_speed_mps := 340.0

@export_category("Audio hints")
@export var exterior_audio_profile_id: StringName = &"temperate_exterior"
@export var interior_audio_profile_id: StringName = &"temperate_interior"
@export_range(MIN_AUDIO_GAIN_DB, MAX_AUDIO_GAIN_DB, 0.1) var exterior_wind_gain_db := -6.0
@export_range(MIN_AUDIO_GAIN_DB, 0.0, 0.1) var interior_attenuation_db := -18.0


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	_validate_stable_id(errors, "profile_id", str(profile_id))
	_validate_ui_copy(errors, "display_name", display_name, 96)
	_validate_evidence_references(errors)
	if evidence_notes.is_empty() or evidence_notes != evidence_notes.strip_edges():
		errors.append("evidence_notes must be non-empty and trimmed")

	_validate_range(errors, "planet_radius_m", planet_radius_m, MIN_PLANET_RADIUS_M, MAX_PLANET_RADIUS_M)
	_validate_range(errors, "reference_altitude_m", reference_altitude_m, 0.0, MAX_ATMOSPHERE_ALTITUDE_M)
	_validate_range(errors, "atmosphere_top_altitude_m", atmosphere_top_altitude_m, 1.0, MAX_ATMOSPHERE_ALTITUDE_M)
	if _is_finite_float(reference_altitude_m) and _is_finite_float(atmosphere_top_altitude_m) \
			and reference_altitude_m >= atmosphere_top_altitude_m:
		errors.append("reference_altitude_m must be below atmosphere_top_altitude_m")
	if _is_finite_float(planet_radius_m) and _is_finite_float(atmosphere_top_altitude_m) \
			and atmosphere_top_altitude_m > planet_radius_m:
		errors.append("atmosphere_top_altitude_m must not exceed planet_radius_m")

	_validate_range(errors, "reference_density_kg_m3", reference_density_kg_m3, 0.000001, MAX_DENSITY_KG_M3)
	_validate_range(errors, "density_scale_height_m", density_scale_height_m, 0.1, MAX_DENSITY_SCALE_HEIGHT_M)
	_validate_range(errors, "density_falloff_exponent", density_falloff_exponent, 0.01, MAX_DENSITY_FALLOFF_EXPONENT)

	_validate_coefficient_color(errors, "rayleigh_scattering_per_m", rayleigh_scattering_per_m)
	_validate_coefficient_color(errors, "mie_scattering_per_m", mie_scattering_per_m)
	_validate_coefficient_color(errors, "absorption_per_m", absorption_per_m)
	_validate_range(errors, "mie_anisotropy_unitless", mie_anisotropy_unitless, -0.99, 0.99)

	_validate_range(errors, "maximum_visibility_m", maximum_visibility_m, 0.1, MAX_VISIBILITY_M)
	_validate_range(errors, "fog_start_distance_m", fog_start_distance_m, 0.0, MAX_VISIBILITY_M)
	_validate_range(errors, "fog_end_distance_m", fog_end_distance_m, 0.1, MAX_VISIBILITY_M)
	_validate_range(errors, "fog_density_unitless", fog_density_unitless, 0.0, 1.0)
	if _is_finite_float(fog_start_distance_m) and _is_finite_float(fog_end_distance_m) \
			and fog_start_distance_m >= fog_end_distance_m:
		errors.append("fog_start_distance_m must be below fog_end_distance_m")
	if _is_finite_float(fog_end_distance_m) and _is_finite_float(maximum_visibility_m) \
			and fog_end_distance_m > maximum_visibility_m:
		errors.append("fog_end_distance_m must not exceed maximum_visibility_m")

	_validate_range(errors, "cloud_base_altitude_m", cloud_base_altitude_m, 0.0, MAX_ATMOSPHERE_ALTITUDE_M)
	_validate_range(errors, "cloud_top_altitude_m", cloud_top_altitude_m, 0.0, MAX_ATMOSPHERE_ALTITUDE_M)
	_validate_range(errors, "cloud_coverage_unitless", cloud_coverage_unitless, 0.0, 1.0)
	if _is_finite_float(cloud_base_altitude_m) and _is_finite_float(cloud_top_altitude_m) \
			and cloud_base_altitude_m >= cloud_top_altitude_m:
		errors.append("cloud_base_altitude_m must be below cloud_top_altitude_m")
	if _is_finite_float(cloud_top_altitude_m) and _is_finite_float(atmosphere_top_altitude_m) \
			and cloud_top_altitude_m > atmosphere_top_altitude_m:
		errors.append("cloud_top_altitude_m must not exceed atmosphere_top_altitude_m")

	if not _is_finite_vector(wind_velocity_mps) or wind_velocity_mps.length() > MAX_WIND_SPEED_MPS:
		errors.append("wind_velocity_mps must be finite and no faster than %s metres per second" % MAX_WIND_SPEED_MPS)
	_validate_range(errors, "weather_intensity_unitless", weather_intensity_unitless, 0.0, 1.0)

	_validate_range(errors, "entry_effect_start_altitude_m", entry_effect_start_altitude_m, 0.0, MAX_ATMOSPHERE_ALTITUDE_M)
	_validate_range(errors, "entry_effect_full_altitude_m", entry_effect_full_altitude_m, 0.0, MAX_ATMOSPHERE_ALTITUDE_M)
	_validate_range(errors, "entry_effect_minimum_speed_mps", entry_effect_minimum_speed_mps, 0.0, MAX_ENTRY_SPEED_MPS)
	_validate_range(errors, "entry_effect_full_speed_mps", entry_effect_full_speed_mps, 0.0, MAX_ENTRY_SPEED_MPS)
	if _is_finite_float(entry_effect_start_altitude_m) and _is_finite_float(entry_effect_full_altitude_m) \
			and entry_effect_full_altitude_m >= entry_effect_start_altitude_m:
		errors.append("entry_effect_full_altitude_m must be below entry_effect_start_altitude_m")
	if _is_finite_float(entry_effect_start_altitude_m) and _is_finite_float(atmosphere_top_altitude_m) \
			and entry_effect_start_altitude_m > atmosphere_top_altitude_m:
		errors.append("entry_effect_start_altitude_m must not exceed atmosphere_top_altitude_m")
	if _is_finite_float(entry_effect_minimum_speed_mps) and _is_finite_float(entry_effect_full_speed_mps) \
			and entry_effect_minimum_speed_mps >= entry_effect_full_speed_mps:
		errors.append("entry_effect_minimum_speed_mps must be below entry_effect_full_speed_mps")

	_validate_stable_id(errors, "exterior_audio_profile_id", str(exterior_audio_profile_id))
	_validate_stable_id(errors, "interior_audio_profile_id", str(interior_audio_profile_id))
	_validate_range(errors, "exterior_wind_gain_db", exterior_wind_gain_db, MIN_AUDIO_GAIN_DB, MAX_AUDIO_GAIN_DB)
	_validate_range(errors, "interior_attenuation_db", interior_attenuation_db, MIN_AUDIO_GAIN_DB, 0.0)
	return errors


func is_definition_valid() -> bool:
	return get_validation_errors().is_empty()


## Canonical composition accessor. The exported `_m` field remains stable for
## existing resources while cross-contract code uses one unabbreviated unit.
func get_planet_radius_meters() -> float:
	return planet_radius_m


func get_atmosphere_top_altitude_meters() -> float:
	return atmosphere_top_altitude_m


func get_geometry_snapshot() -> Dictionary:
	return {
		"planet_radius_m": planet_radius_m,
		"reference_altitude_m": reference_altitude_m,
		"atmosphere_top_altitude_m": atmosphere_top_altitude_m,
	}.duplicate(true)


func get_density_snapshot() -> Dictionary:
	return {
		"reference_density_kg_m3": reference_density_kg_m3,
		"density_scale_height_m": density_scale_height_m,
		"density_falloff_exponent": density_falloff_exponent,
	}.duplicate(true)


func get_optics_snapshot() -> Dictionary:
	return {
		"rayleigh_scattering_per_m": rayleigh_scattering_per_m,
		"mie_scattering_per_m": mie_scattering_per_m,
		"absorption_per_m": absorption_per_m,
		"mie_anisotropy_unitless": mie_anisotropy_unitless,
		"maximum_visibility_m": maximum_visibility_m,
		"fog_start_distance_m": fog_start_distance_m,
		"fog_end_distance_m": fog_end_distance_m,
		"fog_density_unitless": fog_density_unitless,
	}.duplicate(true)


func get_weather_snapshot() -> Dictionary:
	return {
		"cloud_base_altitude_m": cloud_base_altitude_m,
		"cloud_top_altitude_m": cloud_top_altitude_m,
		"cloud_coverage_unitless": cloud_coverage_unitless,
		"wind_velocity_mps": wind_velocity_mps,
		"weather_intensity_unitless": weather_intensity_unitless,
	}.duplicate(true)


func get_entry_effect_snapshot() -> Dictionary:
	return {
		"start_altitude_m": entry_effect_start_altitude_m,
		"full_altitude_m": entry_effect_full_altitude_m,
		"minimum_speed_mps": entry_effect_minimum_speed_mps,
		"full_speed_mps": entry_effect_full_speed_mps,
	}.duplicate(true)


func get_audio_hint_snapshot() -> Dictionary:
	return {
		"exterior_audio_profile_id": exterior_audio_profile_id,
		"interior_audio_profile_id": interior_audio_profile_id,
		"exterior_wind_gain_db": exterior_wind_gain_db,
		"interior_attenuation_db": interior_attenuation_db,
	}.duplicate(true)


func get_authority_report() -> Dictionary:
	return {
		"renderer": false,
		"gameplay": false,
		"streaming": false,
		"save": false,
		"network": false,
		"physics": false,
		"world_generation": false,
		"terrain_generation": false,
		"collision_generation": false,
		"origin_shift": false,
		"weather_clock": false,
		"audio": false,
	}.duplicate(true)


func audit() -> Dictionary:
	var errors := get_validation_errors()
	return {
		"schema_version": SCHEMA_VERSION,
		"unit_system": UNIT_SYSTEM,
		"valid": errors.is_empty(),
		"errors": errors,
		"profile_id": profile_id,
		"display_name": display_name,
		"content_class": CONTENT_CLASS,
		"evidence_status": EVIDENCE_STATUS,
		"evidence_scope": EVIDENCE_SCOPE,
		"evidence_references": evidence_references.duplicate(),
		"evidence_notes": evidence_notes,
		"evidence": {
			"content_class": CONTENT_CLASS,
			"status": EVIDENCE_STATUS,
			"scope": EVIDENCE_SCOPE,
			"references": evidence_references.duplicate(),
			"notes": evidence_notes,
		},
		"geometry": get_geometry_snapshot(),
		"density": get_density_snapshot(),
		"optics": get_optics_snapshot(),
		"weather": get_weather_snapshot(),
		"entry_effects": get_entry_effect_snapshot(),
		"audio_hints": get_audio_hint_snapshot(),
		"authority": get_authority_report(),
	}.duplicate(true)


func get_audit_report() -> Dictionary:
	return audit().duplicate(true)


func _validate_evidence_references(errors: PackedStringArray) -> void:
	if evidence_references.size() > MAX_EVIDENCE_REFERENCES:
		errors.append("evidence references must contain at most %d entries" % MAX_EVIDENCE_REFERENCES)
	var seen := PackedStringArray()
	for reference in evidence_references:
		if reference.is_empty() or reference != reference.strip_edges() \
				or reference.contains("\n") or reference.contains("\r") \
				or reference.length() > MAX_EVIDENCE_REFERENCE_LENGTH:
			errors.append("evidence references must be non-empty, trimmed, single-line, and at most %d characters" % MAX_EVIDENCE_REFERENCE_LENGTH)
		elif seen.has(reference):
			errors.append("evidence reference '%s' is duplicated" % reference)
		else:
			seen.append(reference)


static func _validate_stable_id(errors: PackedStringArray, field_name: String, value: String) -> void:
	if not _is_stable_id(value):
		errors.append("%s must be a 1-64 character lowercase snake_case identifier" % field_name)


static func _validate_ui_copy(errors: PackedStringArray, field_name: String, value: String, maximum_length: int) -> void:
	if value.is_empty() or value != value.strip_edges() or value.contains("\n") \
			or value.contains("\r") or value.length() > maximum_length:
		errors.append("%s must be non-empty, trimmed, single-line, and at most %d characters" % [field_name, maximum_length])


static func _is_stable_id(value: String) -> bool:
	if value.is_empty() or value.length() > 64 or value.begins_with("_") or value.ends_with("_") \
			or value.contains("__"):
		return false
	var first_code := value.unicode_at(0)
	if first_code < 97 or first_code > 122:
		return false
	for index in value.length():
		var code := value.unicode_at(index)
		var lower_letter := code >= 97 and code <= 122
		var digit := code >= 48 and code <= 57
		if not lower_letter and not digit and code != 95:
			return false
	return true


static func _validate_range(errors: PackedStringArray, field_name: String, value: float, minimum: float, maximum: float) -> void:
	if not _is_finite_float(value) or value < minimum or value > maximum:
		errors.append("%s must be finite and in the range %s to %s" % [field_name, minimum, maximum])


static func _validate_coefficient_color(errors: PackedStringArray, field_name: String, value: Color) -> void:
	if not _is_finite_float(value.r) or not _is_finite_float(value.g) or not _is_finite_float(value.b) \
			or not _is_finite_float(value.a) or value.r < 0.0 or value.g < 0.0 or value.b < 0.0 \
			or value.r > MAX_OPTICAL_COEFFICIENT_PER_M or value.g > MAX_OPTICAL_COEFFICIENT_PER_M \
			or value.b > MAX_OPTICAL_COEFFICIENT_PER_M or value.a != 1.0:
		errors.append("%s RGB channels must be finite in 0..%s inverse metres and alpha must equal 1" % [field_name, MAX_OPTICAL_COEFFICIENT_PER_M])


static func _is_finite_float(value: float) -> bool:
	return not is_nan(value) and not is_inf(value)


static func _is_finite_vector(value: Vector3) -> bool:
	return _is_finite_float(value.x) and _is_finite_float(value.y) and _is_finite_float(value.z)
