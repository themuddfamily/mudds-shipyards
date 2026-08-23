class_name StationSolarReadabilityPresentation
extends RefCounted

## Passive readability cap for the shipyard's existing Environment.
##
## VisualQualityController still chooses the renderer profile. This adapter
## captures that profile's exact values, narrows only its broad glare/exposure
## terms, and restores the captured values when the station leaves the tree.
## It never creates renderer resources or samples a camera heading.

const COMPONENT_ID: StringName = &"station-solar-readability-presentation"
const MAX_SAFE_GENERATION := 9_007_199_254_740_991

const MAX_TONEMAP_EXPOSURE := 1.08
const MAX_GLOW_INTENSITY := 0.34
const MAX_GLOW_STRENGTH := 1.05
const MAX_GLOW_BLOOM := 0.006
const MIN_GLOW_HDR_THRESHOLD := 1.35
const MAX_GLOW_HDR_SCALE := 2.0
const MAX_GLOW_HDR_LUMINANCE_CAP := 3.5
const MAX_FOG_SUN_SCATTER := 0.04
const MAX_VOLUMETRIC_FOG_ANISOTROPY := 0.35
const GLOW_LEVEL_CAPS := [0.0, 0.7, 0.5, 0.18, 0.0, 0.0, 0.0]

## Reduced-flash keeps the same steady sun silhouette while lowering every
## retained exposure/glow contribution that can make a camera turn feel like a
## flash. Values are absolute caps, never multipliers on a previously applied
## profile, so repeated settings signals cannot compound.
const REDUCED_FLASH_MAX_TONEMAP_EXPOSURE := 0.94
const REDUCED_FLASH_MAX_GLOW_INTENSITY := 0.18
const REDUCED_FLASH_MAX_GLOW_STRENGTH := 0.72
const REDUCED_FLASH_MAX_GLOW_BLOOM := 0.002
const REDUCED_FLASH_MIN_GLOW_HDR_THRESHOLD := 1.65
const REDUCED_FLASH_MAX_GLOW_HDR_SCALE := 1.35
const REDUCED_FLASH_MAX_GLOW_HDR_LUMINANCE_CAP := 2.4
const REDUCED_FLASH_MAX_FOG_SUN_SCATTER := 0.015
const REDUCED_FLASH_MAX_VOLUMETRIC_FOG_ANISOTROPY := 0.2
const REDUCED_FLASH_GLOW_LEVEL_CAPS := [
	0.0, 0.38, 0.22, 0.06, 0.0, 0.0, 0.0,
]

## The exact sun centre keeps the existing bright silhouette. Only the secondary
## halo is narrowed: at 15 degrees it contributes under 3.5%, and at 30 degrees
## under 0.02%, instead of veiling a broad camera heading.
const SUN_CORE_FOCUS := 260.0
const SUN_HALO_FOCUS := 48.0
const SUN_HALO_STRENGTH := 0.18
const REDUCED_FLASH_SUN_HALO_STRENGTH := 0.08

var _environment_ref: WeakRef
var _sky_material_ref: WeakRef
var _environment_instance_id := 0
var _sky_material_instance_id := 0
var _generation := 0
var _baseline: Dictionary = {}
var _current: Dictionary = {}
var _sky_baseline: Dictionary = {}
var _reduced_flash := false
var _last_result: Dictionary = {}


func configure(
		environment: Environment, sky_material: ShaderMaterial,
		reduced_flash: bool = false
	) -> Dictionary:
	if _generation != 0:
		return _result(false, &"already_configured")
	if environment == null or not is_instance_valid(environment):
		return _result(false, &"environment_unavailable")
	if sky_material == null or not is_instance_valid(sky_material) \
			or sky_material.shader == null:
		return _result(false, &"sky_material_unavailable")
	if not _sky_contract_is_bounded(sky_material):
		return _result(false, &"sky_glare_contract_invalid")
	_environment_ref = weakref(environment)
	_sky_material_ref = weakref(sky_material)
	_environment_instance_id = environment.get_instance_id()
	_sky_material_instance_id = sky_material.get_instance_id()
	_baseline = _read_environment(environment)
	_sky_baseline = _read_sky(sky_material)
	_reduced_flash = reduced_flash
	_generation = 1
	_apply_bounded_values(environment, sky_material)
	_current = _read_environment(environment)
	_last_result = _result(true, &"solar_readability_presented")
	return _last_result.duplicate(true)


func detach(reason: StringName, expected_generation: int) -> Dictionary:
	if expected_generation != _generation:
		return _result(false, &"stale_generation")
	if _generation >= MAX_SAFE_GENERATION:
		return _result(false, &"generation_exhausted")
	var identity_reason := _identity_reason()
	if not identity_reason.is_empty():
		return _result(false, identity_reason)
	_apply_environment(_environment(), _baseline)
	_apply_sun_halo(
		_sky_material(), float(_sky_baseline.get("sun_halo", SUN_HALO_STRENGTH))
	)
	_current = _baseline.duplicate(true)
	_generation += 1
	_last_result = _result(true, reason)
	_environment_ref = null
	_sky_material_ref = null
	return _last_result.duplicate(true)


func get_generation() -> int:
	return _generation


## Applies the caller-owned accessibility state immediately. The lifecycle
## generation is stable across settings changes and fences detach/re-entry only.
func set_reduced_flash(
		enabled: bool, expected_generation: int
	) -> Dictionary:
	if expected_generation != _generation:
		return _result(false, &"stale_generation")
	var identity_reason := _identity_reason()
	if not identity_reason.is_empty():
		return _result(false, identity_reason)
	_reduced_flash = enabled
	_apply_bounded_values(_environment(), _sky_material())
	_current = _read_environment(_environment())
	_last_result = _result(
		true,
		&"reduced_flash_presented" if enabled \
			else &"normal_readability_restored",
	)
	return _last_result.duplicate(true)


func get_snapshot() -> Dictionary:
	var environment := _environment()
	var sky_material := _sky_material()
	return {
		"component_id": COMPONENT_ID,
		"active": environment != null and sky_material != null,
		"generation": _generation,
		"environment_instance_id": _environment_instance_id,
		"sky_material_instance_id": _sky_material_instance_id,
		"baseline": _baseline.duplicate(true),
		"current": _current.duplicate(true),
		"actual": _read_environment(environment) if environment != null else {},
		"sky": _read_sky(sky_material),
		"sky_baseline": _sky_baseline.duplicate(true),
		"reduced_flash": _reduced_flash,
		"profile_id": &"reduced_flash" if _reduced_flash else &"normal_bounded",
		"last_result": _last_result.duplicate(true),
		"node_budget": 0,
		"resource_budget": 0,
		"camera_heading_sampling": false,
		"light_direction_authority": false,
		"environment_selection_authority": false,
		"gameplay_authority": false,
	}.duplicate(true)


func audit() -> Dictionary:
	var snapshot := get_snapshot()
	var errors := PackedStringArray()
	var identity_reason := _identity_reason()
	if not identity_reason.is_empty():
		errors.append(String(identity_reason))
	if snapshot.actual != snapshot.current:
		errors.append("bounded_environment_values_drift")
	if not _sky_contract_matches_mode(_sky_material()):
		errors.append("bounded_sun_lobe_drift")
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"snapshot": snapshot,
		"presentation_only": true,
	}.duplicate(true)


static func sun_lobe_at_alignment(alignment: float) -> float:
	var bounded_alignment := clampf(alignment, 0.0, 1.0)
	return pow(bounded_alignment, SUN_CORE_FOCUS) \
		+ SUN_HALO_STRENGTH * pow(bounded_alignment, SUN_HALO_FOCUS)


func _apply_bounded_values(
		environment: Environment, sky_material: ShaderMaterial
	) -> void:
	var values := _baseline.duplicate(true)
	var exposure_cap := REDUCED_FLASH_MAX_TONEMAP_EXPOSURE \
		if _reduced_flash else MAX_TONEMAP_EXPOSURE
	var intensity_cap := REDUCED_FLASH_MAX_GLOW_INTENSITY \
		if _reduced_flash else MAX_GLOW_INTENSITY
	var strength_cap := REDUCED_FLASH_MAX_GLOW_STRENGTH \
		if _reduced_flash else MAX_GLOW_STRENGTH
	var bloom_cap := REDUCED_FLASH_MAX_GLOW_BLOOM \
		if _reduced_flash else MAX_GLOW_BLOOM
	var threshold_floor := REDUCED_FLASH_MIN_GLOW_HDR_THRESHOLD \
		if _reduced_flash else MIN_GLOW_HDR_THRESHOLD
	var hdr_scale_cap := REDUCED_FLASH_MAX_GLOW_HDR_SCALE \
		if _reduced_flash else MAX_GLOW_HDR_SCALE
	var luminance_cap := REDUCED_FLASH_MAX_GLOW_HDR_LUMINANCE_CAP \
		if _reduced_flash else MAX_GLOW_HDR_LUMINANCE_CAP
	var scatter_cap := REDUCED_FLASH_MAX_FOG_SUN_SCATTER \
		if _reduced_flash else MAX_FOG_SUN_SCATTER
	var anisotropy_cap := REDUCED_FLASH_MAX_VOLUMETRIC_FOG_ANISOTROPY \
		if _reduced_flash else MAX_VOLUMETRIC_FOG_ANISOTROPY
	var level_caps := REDUCED_FLASH_GLOW_LEVEL_CAPS \
		if _reduced_flash else GLOW_LEVEL_CAPS
	values.tonemap_exposure = minf(
		float(_baseline.tonemap_exposure), exposure_cap
	)
	values.glow_intensity = minf(
		float(_baseline.glow_intensity), intensity_cap
	)
	values.glow_strength = minf(
		float(_baseline.glow_strength), strength_cap
	)
	values.glow_bloom = minf(float(_baseline.glow_bloom), bloom_cap)
	values.glow_hdr_threshold = maxf(
		float(_baseline.glow_hdr_threshold), threshold_floor
	)
	values.glow_hdr_scale = minf(
		float(_baseline.glow_hdr_scale), hdr_scale_cap
	)
	values.glow_hdr_luminance_cap = minf(
		float(_baseline.glow_hdr_luminance_cap), luminance_cap
	)
	values.fog_sun_scatter = minf(
		float(_baseline.fog_sun_scatter), scatter_cap
	)
	values.volumetric_fog_anisotropy = minf(
		float(_baseline.volumetric_fog_anisotropy),
		anisotropy_cap
	)
	var bounded_levels: Array[float] = []
	var baseline_levels := _baseline.glow_levels as Array
	for index in level_caps.size():
		bounded_levels.append(minf(
			float(baseline_levels[index]), float(level_caps[index])
		))
	values.glow_levels = bounded_levels
	_apply_environment(environment, values)
	_apply_sun_halo(
		sky_material,
		minf(
			float(_sky_baseline.sun_halo),
			REDUCED_FLASH_SUN_HALO_STRENGTH
		) if _reduced_flash else float(_sky_baseline.sun_halo),
	)


func _read_environment(environment: Environment) -> Dictionary:
	if environment == null:
		return {}
	var glow_levels: Array[float] = []
	for index in GLOW_LEVEL_CAPS.size():
		glow_levels.append(environment.get_glow_level(index))
	return {
		"tonemap_exposure": environment.tonemap_exposure,
		"glow_intensity": environment.glow_intensity,
		"glow_strength": environment.glow_strength,
		"glow_bloom": environment.glow_bloom,
		"glow_hdr_threshold": environment.glow_hdr_threshold,
		"glow_hdr_scale": environment.glow_hdr_scale,
		"glow_hdr_luminance_cap": environment.glow_hdr_luminance_cap,
		"glow_levels": glow_levels,
		"fog_sun_scatter": environment.fog_sun_scatter,
		"volumetric_fog_anisotropy": environment.volumetric_fog_anisotropy,
	}.duplicate(true)


func _apply_environment(environment: Environment, values: Dictionary) -> void:
	environment.tonemap_exposure = float(values.tonemap_exposure)
	environment.glow_intensity = float(values.glow_intensity)
	environment.glow_strength = float(values.glow_strength)
	environment.glow_bloom = float(values.glow_bloom)
	environment.glow_hdr_threshold = float(values.glow_hdr_threshold)
	environment.glow_hdr_scale = float(values.glow_hdr_scale)
	environment.glow_hdr_luminance_cap = float(values.glow_hdr_luminance_cap)
	var glow_levels := values.glow_levels as Array
	for index in glow_levels.size():
		environment.set_glow_level(index, float(glow_levels[index]))
	environment.fog_sun_scatter = float(values.fog_sun_scatter)
	environment.volumetric_fog_anisotropy = float(
		values.volumetric_fog_anisotropy
	)


func _read_sky(sky_material: ShaderMaterial) -> Dictionary:
	if sky_material == null:
		return {}
	return {
		"sun_direction": sky_material.get_shader_parameter(&"sun_direction"),
		"sun_focus": sky_material.get_shader_parameter(&"sun_focus"),
		"sun_halo": sky_material.get_shader_parameter(&"sun_halo"),
		"sun_halo_focus": sky_material.get_shader_parameter(&"sun_halo_focus"),
	}.duplicate(true)


func _apply_sun_halo(sky_material: ShaderMaterial, strength: float) -> void:
	if sky_material != null:
		sky_material.set_shader_parameter(&"sun_halo", strength)


func _sky_contract_is_bounded(sky_material: ShaderMaterial) -> bool:
	if sky_material == null:
		return false
	var state := _read_sky(sky_material)
	return state.sun_direction is Vector3 \
		and (state.sun_direction as Vector3).is_normalized() \
		and is_equal_approx(float(state.sun_focus), SUN_CORE_FOCUS) \
		and is_equal_approx(float(state.sun_halo), SUN_HALO_STRENGTH) \
		and is_equal_approx(float(state.sun_halo_focus), SUN_HALO_FOCUS)


func _sky_contract_matches_mode(sky_material: ShaderMaterial) -> bool:
	if sky_material == null or _sky_baseline.is_empty():
		return false
	var state := _read_sky(sky_material)
	var expected_halo := minf(
		float(_sky_baseline.sun_halo), REDUCED_FLASH_SUN_HALO_STRENGTH
	) if _reduced_flash else float(_sky_baseline.sun_halo)
	return state.sun_direction == _sky_baseline.sun_direction \
		and is_equal_approx(float(state.sun_focus), float(_sky_baseline.sun_focus)) \
		and is_equal_approx(float(state.sun_halo), expected_halo) \
		and is_equal_approx(
			float(state.sun_halo_focus), float(_sky_baseline.sun_halo_focus)
		)


func _identity_reason() -> StringName:
	var environment := _environment()
	var sky_material := _sky_material()
	if environment == null:
		return &"environment_unavailable"
	if sky_material == null:
		return &"sky_material_unavailable"
	if environment.get_instance_id() != _environment_instance_id:
		return &"environment_identity_drift"
	if sky_material.get_instance_id() != _sky_material_instance_id:
		return &"sky_material_identity_drift"
	return &""


func _environment() -> Environment:
	if _environment_ref == null:
		return null
	var candidate: Variant = _environment_ref.get_ref()
	return candidate as Environment \
		if is_instance_valid(candidate) and candidate is Environment else null


func _sky_material() -> ShaderMaterial:
	if _sky_material_ref == null:
		return null
	var candidate: Variant = _sky_material_ref.get_ref()
	return candidate as ShaderMaterial \
		if is_instance_valid(candidate) and candidate is ShaderMaterial else null


func _result(
		accepted: bool, reason: StringName, extra: Dictionary = {}
	) -> Dictionary:
	var result := {
		"accepted": accepted,
		"reason": reason,
		"generation": _generation,
		"presentation_only": true,
		"gameplay_authority": false,
	}
	for key: Variant in extra:
		result[key] = extra[key]
	return result.duplicate(true)
