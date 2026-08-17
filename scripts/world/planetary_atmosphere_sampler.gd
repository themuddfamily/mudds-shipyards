class_name PlanetaryAtmosphereSampler
extends RefCounted

## Pure deterministic evaluator for one validated [PlanetaryAtmosphereProfile].
##
## Configuration copies only value snapshots. The source Resource is never
## mutated or retained, and caller mutation after configuration cannot retune an
## established sampler. Sampling has no clock or delta input and changes no
## state. Every returned quantity is a bounded hint for later consumers; this
## class owns no renderer, physics, ship, gameplay, weather-clock, audio, save,
## world-generation, or network authority.

const SCHEMA_VERSION := 1
const EQUATION_VERSION: StringName = &"game_scale_atmosphere_v1"
const MAX_OPTICAL_DEPTH_UNITLESS := 64.0
const MAX_EXTINCTION_PER_M := 3.0
const MIN_TRANSMITTANCE_UNITLESS := 0.0
const MAX_TRANSMITTANCE_UNITLESS := 1.0
const LUMINANCE_WEIGHTS := Vector3(0.2126, 0.7152, 0.0722)

var _configured := false
var _profile_id: StringName = &""
var _source_profile_schema_version := 0
var _geometry: Dictionary = {}
var _density: Dictionary = {}
var _optics: Dictionary = {}
var _weather: Dictionary = {}
var _entry_effects: Dictionary = {}


## Freezes detached value snapshots from a currently valid profile. Failed
## configuration leaves the sampler retryable; successful configuration is
## immutable.
func configure(profile: PlanetaryAtmosphereProfile) -> Dictionary:
	if _configured:
		return _result(false, &"already_configured")
	if profile == null:
		return _result(false, &"missing_profile")
	var source_audit := profile.get_audit_report()
	if not profile.is_definition_valid() or not bool(
		source_audit.get("valid", false)
	):
		return _result(false, &"invalid_profile", {
			"profile_errors": (
				source_audit.get("errors", PackedStringArray()) \
				as PackedStringArray
			).duplicate(),
		})
	var geometry := profile.get_geometry_snapshot()
	var density := profile.get_density_snapshot()
	var optics := profile.get_optics_snapshot()
	var weather := profile.get_weather_snapshot()
	var entry_effects := profile.get_entry_effect_snapshot()
	if not _snapshots_are_finite_and_bounded(
		geometry, density, optics, weather, entry_effects
	):
		return _result(false, &"invalid_profile_snapshot")

	_configured = true
	_profile_id = source_audit.get("profile_id", &"") as StringName
	_source_profile_schema_version = int(source_audit.get("schema_version", 0))
	_geometry = geometry.duplicate(true)
	_density = density.duplicate(true)
	_optics = optics.duplicate(true)
	_weather = weather.duplicate(true)
	_entry_effects = entry_effects.duplicate(true)
	return _result(true, &"configured", {"snapshot": get_snapshot()})


func is_configured() -> bool:
	return _configured


## Returns one detached sample. The sight path controls optical depth and fog;
## optional weather/cloud multipliers are finite normalized values.
func sample(
		altitude_m: float,
		path_distance_m: float,
		speed_mps: float,
		weather_scalar: float = 1.0,
		cloud_scalar: float = 1.0
	) -> Dictionary:
	if not _configured:
		return _result(false, &"not_configured")
	if not is_finite(altitude_m) \
		or altitude_m < -float(_geometry.get("planet_radius_m", 0.0)) \
		or altitude_m > PlanetaryAtmosphereProfile.MAX_ATMOSPHERE_ALTITUDE_M:
		return _result(false, &"invalid_altitude")
	if not is_finite(path_distance_m) or path_distance_m < 0.0 \
		or path_distance_m > PlanetaryAtmosphereProfile.MAX_VISIBILITY_M:
		return _result(false, &"invalid_path_distance")
	if not is_finite(speed_mps) or speed_mps < 0.0 \
		or speed_mps > PlanetaryAtmosphereProfile.MAX_ENTRY_SPEED_MPS:
		return _result(false, &"invalid_speed")
	if not _is_unit_interval(weather_scalar):
		return _result(false, &"invalid_weather_intensity")
	if not _is_unit_interval(cloud_scalar):
		return _result(false, &"invalid_cloud_coverage")
	var sample_data := _sample_unchecked(
		altitude_m,
		path_distance_m,
		speed_mps,
		weather_scalar,
		cloud_scalar
	)
	if not _sample_is_finite_and_bounded(sample_data):
		return _result(false, &"sample_out_of_bounds")
	return _result(true, &"sampled", sample_data)


func get_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"equation_version": EQUATION_VERSION,
		"configured": _configured,
		"profile_id": _profile_id,
		"source_profile_schema_version": _source_profile_schema_version,
		"geometry": _geometry.duplicate(true),
		"density": _density.duplicate(true),
		"optics": _optics.duplicate(true),
		"weather": _weather.duplicate(true),
		"entry_effects": _entry_effects.duplicate(true),
	}.duplicate(true)


func audit() -> Dictionary:
	var errors := PackedStringArray()
	if not _configured:
		errors.append("atmosphere sampler is not configured")
	elif _profile_id.is_empty() or _source_profile_schema_version != (
		PlanetaryAtmosphereProfile.SCHEMA_VERSION
	) or not _snapshots_are_finite_and_bounded(
		_geometry, _density, _optics, _weather, _entry_effects
	):
		errors.append("frozen atmosphere profile contract is invalid")
	return {
		"schema_version": SCHEMA_VERSION,
		"equation_version": EQUATION_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"snapshot": get_snapshot(),
		"boundary_policy": {
			"below_reference": &"clamp_density_to_reference",
			"at_or_above_atmosphere_top": &"exact_vacuum",
			"cloud_layer": &"base_inclusive_top_exclusive_box",
			"entry_altitude": &"zero_at_start_full_at_or_below_full",
			"entry_speed": &"zero_at_minimum_full_at_or_above_full",
			"optional_scalar_default": 1.0,
		},
		"purity": {
			"delta_or_clock_input": false,
			"mutates_source_profile": false,
			"mutates_sampler_during_sample": false,
		},
		"authority": {
			"renderer": false,
			"physics": false,
			"ship": false,
			"gameplay": false,
			"weather_clock": false,
			"audio": false,
			"save": false,
			"streaming": false,
			"world_generation": false,
			"origin_shift": false,
			"network": false,
		},
	}.duplicate(true)


func get_audit_report() -> Dictionary:
	return audit().duplicate(true)


func _sample_unchecked(
		altitude_m: float,
		path_distance_m: float,
		speed_mps: float,
		weather_scalar: float,
		cloud_scalar: float
	) -> Dictionary:
	var reference_altitude := float(_geometry.reference_altitude_m)
	var atmosphere_top := float(_geometry.atmosphere_top_altitude_m)
	var vacuum := altitude_m >= atmosphere_top
	var below_reference := altitude_m < reference_altitude
	var density_ratio := _density_ratio(altitude_m, vacuum)
	var density_kg_m3 := clampf(
		float(_density.reference_density_kg_m3) * density_ratio,
		0.0,
		float(_density.reference_density_kg_m3)
	)

	var extinction_per_m := _extinction_per_m(density_ratio, vacuum)
	var optical_depth_rgb := Color(
		clampf(
			extinction_per_m.r * path_distance_m,
			0.0,
			MAX_OPTICAL_DEPTH_UNITLESS
		),
		clampf(
			extinction_per_m.g * path_distance_m,
			0.0,
			MAX_OPTICAL_DEPTH_UNITLESS
		),
		clampf(
			extinction_per_m.b * path_distance_m,
			0.0,
			MAX_OPTICAL_DEPTH_UNITLESS
		),
		1.0
	)
	var optical_depth_unitless := clampf(
		Vector3(
			optical_depth_rgb.r,
			optical_depth_rgb.g,
			optical_depth_rgb.b
		).dot(LUMINANCE_WEIGHTS),
		0.0,
		MAX_OPTICAL_DEPTH_UNITLESS
	)
	var optical_transmittance := clampf(
		exp(-optical_depth_unitless),
		MIN_TRANSMITTANCE_UNITLESS,
		MAX_TRANSMITTANCE_UNITLESS
	)
	var optical_transmittance_rgb := Color(
		exp(-optical_depth_rgb.r),
		exp(-optical_depth_rgb.g),
		exp(-optical_depth_rgb.b),
		1.0
	)
	var fog_factor := _fog_factor(
		path_distance_m, density_ratio, weather_scalar, vacuum
	)
	var maximum_visibility := float(_optics.maximum_visibility_m)
	var strongest_extinction := maxf(
		extinction_per_m.r,
		maxf(extinction_per_m.g, extinction_per_m.b)
	)
	var visibility_m := maximum_visibility
	if not vacuum and strongest_extinction > 0.0:
		visibility_m = clampf(
			1.0 / strongest_extinction, 0.0, maximum_visibility
		)
	var cloud_factor := _cloud_layer_factor(
		altitude_m, cloud_scalar, vacuum
	)
	var wind_velocity := Vector3.ZERO if vacuum else (
		(_weather.wind_velocity_mps as Vector3)
		* weather_scalar
	)
	var entry_intensity := _entry_effect_intensity(
		altitude_m, speed_mps, vacuum
	)

	return {
		"sample_schema_version": SCHEMA_VERSION,
		"profile_id": _profile_id,
		"equation_version": EQUATION_VERSION,
		"inputs": {
			"altitude_m": altitude_m,
			"path_distance_m": path_distance_m,
			"speed_mps": speed_mps,
			"weather_scalar": weather_scalar,
			"cloud_scalar": cloud_scalar,
			"effective_weather_intensity_unitless": clampf(
				float(_weather.weather_intensity_unitless) * weather_scalar,
				0.0,
				1.0
			),
			"effective_cloud_coverage_unitless": clampf(
				float(_weather.cloud_coverage_unitless) * cloud_scalar,
				0.0,
				1.0
			),
		},
		"vacuum": vacuum,
		"below_reference_altitude": below_reference,
		"density_ratio": density_ratio,
		"density_kg_m3": density_kg_m3,
		"extinction_per_m": extinction_per_m,
		"optical_depth_rgb": optical_depth_rgb,
		"optical_depth_unitless": optical_depth_unitless,
		"optical_transmittance_rgb": optical_transmittance_rgb,
		"optical_transmittance_unitless": optical_transmittance,
		"visibility_m": visibility_m,
		"fog_factor": fog_factor,
		"cloud_layer_factor": cloud_factor,
		"wind_velocity_mps": wind_velocity,
		"entry_effect_intensity": entry_intensity,
	}


func _density_ratio(altitude_m: float, vacuum: bool) -> float:
	if vacuum:
		return 0.0
	var reference_altitude := float(_geometry.reference_altitude_m)
	var clamped_altitude := maxf(altitude_m, reference_altitude)
	var normalized_height := (
		clamped_altitude - reference_altitude
	) / float(_density.density_scale_height_m)
	var falloff := pow(
		maxf(normalized_height, 0.0),
		float(_density.density_falloff_exponent)
	)
	return clampf(exp(-falloff), 0.0, 1.0)


func _extinction_per_m(
		density_ratio: float,
		vacuum: bool
	) -> Color:
	if vacuum:
		return Color(0.0, 0.0, 0.0, 1.0)
	var rayleigh := _optics.rayleigh_scattering_per_m as Color
	var mie := _optics.mie_scattering_per_m as Color
	var absorption := _optics.absorption_per_m as Color
	return Color(
		clampf(
			(rayleigh.r + mie.r + absorption.r)
			* density_ratio,
			0.0,
			MAX_EXTINCTION_PER_M
		),
		clampf(
			(rayleigh.g + mie.g + absorption.g)
			* density_ratio,
			0.0,
			MAX_EXTINCTION_PER_M
		),
		clampf(
			(rayleigh.b + mie.b + absorption.b)
			* density_ratio,
			0.0,
			MAX_EXTINCTION_PER_M
		),
		1.0
	)


func _fog_factor(
		path_distance_m: float,
		density_ratio: float,
		weather_scalar: float,
		vacuum: bool
	) -> float:
	if vacuum:
		return 0.0
	var fog_start := float(_optics.fog_start_distance_m)
	var fog_end := float(_optics.fog_end_distance_m)
	var distance_factor := clampf(
		(path_distance_m - fog_start) / (fog_end - fog_start),
		0.0,
		1.0
	)
	var smooth_distance := distance_factor * distance_factor \
		* (3.0 - 2.0 * distance_factor)
	return clampf(
		smooth_distance * float(_optics.fog_density_unitless)
		* density_ratio * weather_scalar,
		0.0,
		1.0
	)


func _cloud_layer_factor(
		altitude_m: float,
		cloud_scalar: float,
		vacuum: bool
	) -> float:
	if vacuum:
		return 0.0
	var cloud_base := float(_weather.cloud_base_altitude_m)
	var cloud_top := float(_weather.cloud_top_altitude_m)
	if altitude_m < cloud_base or altitude_m >= cloud_top:
		return 0.0
	return clampf(
		float(_weather.cloud_coverage_unitless) * cloud_scalar,
		0.0,
		1.0
	)


func _entry_effect_intensity(
		altitude_m: float,
		speed_mps: float,
		vacuum: bool
	) -> float:
	if vacuum:
		return 0.0
	var start_altitude := float(_entry_effects.start_altitude_m)
	var full_altitude := float(_entry_effects.full_altitude_m)
	var minimum_speed := float(_entry_effects.minimum_speed_mps)
	var full_speed := float(_entry_effects.full_speed_mps)
	var altitude_factor := 0.0
	if altitude_m <= full_altitude:
		altitude_factor = 1.0
	elif altitude_m < start_altitude:
		altitude_factor = (
			start_altitude - altitude_m
		) / (start_altitude - full_altitude)
	var speed_factor := 0.0
	if speed_mps >= full_speed:
		speed_factor = 1.0
	elif speed_mps > minimum_speed:
		speed_factor = (
			speed_mps - minimum_speed
		) / (full_speed - minimum_speed)
	return clampf(altitude_factor * speed_factor, 0.0, 1.0)


func _sample_is_finite_and_bounded(candidate: Dictionary) -> bool:
	var extinction := candidate.get(
		"extinction_per_m", Color(-1, -1, -1, -1)
	) as Color
	var depth := candidate.get("optical_depth_rgb", Color(-1, -1, -1, -1)) as Color
	var transmittance := candidate.get(
		"optical_transmittance_rgb", Color(-1, -1, -1, -1)
	) as Color
	var wind := candidate.get("wind_velocity_mps", Vector3.INF) as Vector3
	return _is_unit_interval(candidate.get("density_ratio", NAN)) \
		and _is_finite_range(
			candidate.get("density_kg_m3", NAN),
			0.0,
			float(_density.reference_density_kg_m3)
		) \
		and _is_bounded_color(extinction, MAX_EXTINCTION_PER_M) \
		and _is_bounded_color(depth, MAX_OPTICAL_DEPTH_UNITLESS) \
		and _is_bounded_color(transmittance, 1.0) \
		and _is_finite_range(
			candidate.get("optical_depth_unitless", NAN),
			0.0,
			MAX_OPTICAL_DEPTH_UNITLESS
		) \
		and _is_unit_interval(
			candidate.get("optical_transmittance_unitless", NAN)
		) \
		and _is_finite_range(
			candidate.get("visibility_m", NAN),
			0.0,
			float(_optics.maximum_visibility_m)
		) \
		and _is_unit_interval(candidate.get("fog_factor", NAN)) \
		and _is_unit_interval(candidate.get("cloud_layer_factor", NAN)) \
		and wind.is_finite() \
		and wind.length() <= PlanetaryAtmosphereProfile.MAX_WIND_SPEED_MPS \
		and _is_unit_interval(candidate.get("entry_effect_intensity", NAN))


static func _snapshots_are_finite_and_bounded(
		geometry: Dictionary,
		density: Dictionary,
		optics: Dictionary,
		weather: Dictionary,
		entry_effects: Dictionary
	) -> bool:
	# Source validation owns the full relationship contract. This second check
	# proves the retained sampler payload contains only finite values of the
	# expected runtime types before the Resource reference is released.
	var scalar_values := [
		geometry.get("planet_radius_m", NAN),
		geometry.get("reference_altitude_m", NAN),
		geometry.get("atmosphere_top_altitude_m", NAN),
		density.get("reference_density_kg_m3", NAN),
		density.get("density_scale_height_m", NAN),
		density.get("density_falloff_exponent", NAN),
		optics.get("maximum_visibility_m", NAN),
		optics.get("fog_start_distance_m", NAN),
		optics.get("fog_end_distance_m", NAN),
		optics.get("fog_density_unitless", NAN),
		weather.get("cloud_base_altitude_m", NAN),
		weather.get("cloud_top_altitude_m", NAN),
		weather.get("cloud_coverage_unitless", NAN),
		weather.get("weather_intensity_unitless", NAN),
		entry_effects.get("start_altitude_m", NAN),
		entry_effects.get("full_altitude_m", NAN),
		entry_effects.get("minimum_speed_mps", NAN),
		entry_effects.get("full_speed_mps", NAN),
	]
	for value: Variant in scalar_values:
		if not value is float or not is_finite(float(value)):
			return false
	for color_key in [
		"rayleigh_scattering_per_m",
		"mie_scattering_per_m",
		"absorption_per_m",
	]:
		if not optics.get(color_key) is Color:
			return false
		var color := optics.get(color_key) as Color
		if not _is_finite_color(color):
			return false
	var wind: Variant = weather.get("wind_velocity_mps", Vector3.INF)
	return wind is Vector3 and (wind as Vector3).is_finite()


static func _is_bounded_color(value: Color, maximum: float) -> bool:
	return _is_finite_color(value) and value.a == 1.0 \
		and value.r >= 0.0 and value.r <= maximum \
		and value.g >= 0.0 and value.g <= maximum \
		and value.b >= 0.0 and value.b <= maximum


static func _is_finite_color(value: Color) -> bool:
	return is_finite(value.r) \
		and is_finite(value.g) \
		and is_finite(value.b) \
		and is_finite(value.a)


static func _is_unit_interval(value: Variant) -> bool:
	return _is_finite_range(value, 0.0, 1.0)


static func _is_finite_range(
		value: Variant,
		minimum: float,
		maximum: float
	) -> bool:
	return value is float and is_finite(float(value)) \
		and float(value) >= minimum and float(value) <= maximum


func _result(
		accepted: bool,
		reason: StringName,
		details: Dictionary = {}
	) -> Dictionary:
	var result := {
		"accepted": accepted,
		"reason": reason,
		"configured": _configured,
		"profile_id": _profile_id,
		"equation_version": EQUATION_VERSION,
	}
	result.merge(details, true)
	return result.duplicate(true)
