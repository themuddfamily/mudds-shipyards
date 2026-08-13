class_name VisualQualityController
extends RefCounted

## Applies local, renderer-aware visual profiles to an Environment and Viewport.
##
## This component deliberately does not change ProjectSettings or RenderingServer
## globals. Calling [method get_profile] or constructing this class is side-effect
## free; supplied resources are only changed by [method apply_profile].

enum QualityLevel {
	LOW,
	MEDIUM,
	HIGH,
}


class RenderContext:
	extends RefCounted

	var renderer_method: StringName
	var headless: bool


	func _init(method: StringName, is_headless: bool) -> void:
		renderer_method = method
		headless = is_headless


const RENDERER_FORWARD_PLUS := &"forward_plus"
const RENDERER_MOBILE := &"mobile"
const RENDERER_COMPATIBILITY := &"gl_compatibility"

const _PROFILES := {
	QualityLevel.LOW: {
		"name": &"low",
		"ssao_enabled": false,
		"ssao_intensity": 1.0,
		"ssao_radius": 0.8,
		"ssao_detail": 0.3,
		"ssil_enabled": false,
		"ssil_intensity": 0.55,
		"ssil_radius": 2.0,
		"taa_enabled": false,
		"glow_enabled": false,
		"glow_intensity": 0.18,
		"glow_bloom": 0.0,
		"glow_hdr_threshold": 1.35,
		"tonemap_mode": Environment.TONE_MAPPER_REINHARDT,
		"fog_enabled": false,
		"fog_aerial_perspective": 0.0,
		"fog_sun_scatter": 0.0,
		"volumetric_fog_enabled": false,
		"volumetric_fog_density": 0.0006,
		"volumetric_fog_length": 72.0,
		"volumetric_fog_sky_affect": 0.04,
	},
	QualityLevel.MEDIUM: {
		"name": &"medium",
		"ssao_enabled": true,
		"ssao_intensity": 1.3,
		"ssao_radius": 1.0,
		"ssao_detail": 0.45,
		"ssil_enabled": false,
		"ssil_intensity": 0.65,
		"ssil_radius": 2.75,
		"taa_enabled": true,
		"glow_enabled": true,
		"glow_intensity": 0.28,
		"glow_bloom": 0.04,
		"glow_hdr_threshold": 1.2,
		"tonemap_mode": Environment.TONE_MAPPER_FILMIC,
		"fog_enabled": true,
		"fog_aerial_perspective": 0.06,
		"fog_sun_scatter": 0.025,
		"volumetric_fog_enabled": false,
		"volumetric_fog_density": 0.0008,
		"volumetric_fog_length": 84.0,
		"volumetric_fog_sky_affect": 0.05,
	},
	QualityLevel.HIGH: {
		"name": &"high",
		"ssao_enabled": true,
		"ssao_intensity": 1.5,
		"ssao_radius": 1.25,
		"ssao_detail": 0.55,
		"ssil_enabled": true,
		"ssil_intensity": 0.7,
		"ssil_radius": 3.5,
		"taa_enabled": true,
		"glow_enabled": true,
		"glow_intensity": 0.38,
		"glow_bloom": 0.06,
		"glow_hdr_threshold": 1.05,
		"tonemap_mode": Environment.TONE_MAPPER_AGX,
		"fog_enabled": true,
		"fog_aerial_perspective": 0.12,
		"fog_sun_scatter": 0.05,
		"volumetric_fog_enabled": true,
		"volumetric_fog_density": 0.0012,
		"volumetric_fog_length": 96.0,
		"volumetric_fog_sky_affect": 0.06,
	},
}


## Returns a detached profile dictionary. An invalid quality returns an empty
## dictionary instead of silently selecting a different profile.
static func get_profile(quality: int) -> Dictionary:
	if not _PROFILES.has(quality):
		return {}
	return (_PROFILES[quality] as Dictionary).duplicate(true)


## Captures the effective runtime renderer. Godot may fall back from the
## project-selected method, so querying RenderingServer is more reliable than
## reading ProjectSettings here.
static func get_runtime_context() -> RenderContext:
	return RenderContext.new(
		StringName(RenderingServer.get_current_rendering_method()),
		DisplayServer.get_name() == "headless"
	)


## Returns a detached feature matrix for a renderer. This is useful for menus,
## tests, and explaining why an effect was skipped without changing anything.
static func get_capabilities(renderer_method: StringName, headless: bool = false) -> Dictionary:
	var capabilities := {
		"known_renderer": false,
		"headless": headless,
		"environment": false,
		"ssao": false,
		"ssil": false,
		"taa": false,
		"volumetric_fog": false,
	}
	if headless:
		return capabilities

	match renderer_method:
		RENDERER_FORWARD_PLUS:
			capabilities["known_renderer"] = true
			capabilities["environment"] = true
			capabilities["ssao"] = true
			capabilities["ssil"] = true
			capabilities["taa"] = true
			capabilities["volumetric_fog"] = true
		RENDERER_MOBILE:
			capabilities["known_renderer"] = true
			capabilities["environment"] = true
		RENDERER_COMPATIBILITY:
			capabilities["known_renderer"] = true
			capabilities["environment"] = true
			# Godot 4.7 supports SSAO in Compatibility, but not Mobile.
			capabilities["ssao"] = true
	return capabilities


## Applies [param quality] to the supplied resources and returns an audit
## report. [param context] is optional; production callers should omit it so the
## effective renderer and headless state are detected. Supplying a context is a
## deterministic seam for tests and editor-side resource authoring.
##
## Unsupported effects are left untouched, rather than setting properties the
## active renderer cannot use. A null Environment, invalid profile, headless
## display, or unknown renderer is a safe no-op.
static func apply_profile(
	environment: Environment,
	viewport: Viewport = null,
	quality: int = QualityLevel.HIGH,
	context: RenderContext = null
) -> Dictionary:
	var resolved_context := context if context != null else get_runtime_context()
	var profile := get_profile(quality)
	var capabilities := get_capabilities(resolved_context.renderer_method, resolved_context.headless)
	var report := _make_report(quality, resolved_context, capabilities)

	if profile.is_empty():
		report["reason"] = &"invalid_quality"
		return report
	if environment == null or not is_instance_valid(environment):
		report["reason"] = &"missing_environment"
		return report
	if resolved_context.headless:
		report["reason"] = &"headless"
		report["skipped_features"] = _all_features()
		return report
	if not bool(capabilities["known_renderer"]):
		report["reason"] = &"unsupported_renderer"
		report["skipped_features"] = _all_features()
		return report

	var applied := PackedStringArray()
	var skipped := PackedStringArray()

	# Tonemapping, glow, and depth/height fog are available in every known
	# Godot 4.7 renderer. Numeric values are profile-owned, while scene-scale fog
	# density remains authored by the supplied Environment.
	environment.tonemap_mode = int(profile["tonemap_mode"])
	if environment.tonemap_mode == Environment.TONE_MAPPER_AGX:
		environment.tonemap_agx_contrast = 1.25
		environment.tonemap_agx_white = 16.29
	applied.append("tonemap")

	environment.glow_enabled = bool(profile["glow_enabled"])
	environment.glow_intensity = float(profile["glow_intensity"])
	environment.glow_bloom = float(profile["glow_bloom"])
	environment.glow_hdr_threshold = float(profile["glow_hdr_threshold"])
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	applied.append("glow")

	environment.fog_enabled = bool(profile["fog_enabled"])
	environment.fog_aerial_perspective = float(profile["fog_aerial_perspective"])
	environment.fog_sun_scatter = float(profile["fog_sun_scatter"])
	applied.append("fog")

	if bool(capabilities["ssao"]):
		environment.ssao_enabled = bool(profile["ssao_enabled"])
		environment.ssao_intensity = float(profile["ssao_intensity"])
		environment.ssao_radius = float(profile["ssao_radius"])
		environment.ssao_detail = float(profile["ssao_detail"])
		applied.append("ssao")
	else:
		skipped.append("ssao")

	if bool(capabilities["ssil"]):
		environment.ssil_enabled = bool(profile["ssil_enabled"])
		environment.ssil_intensity = float(profile["ssil_intensity"])
		environment.ssil_radius = float(profile["ssil_radius"])
		applied.append("ssil")
	else:
		skipped.append("ssil")

	if bool(capabilities["volumetric_fog"]):
		environment.volumetric_fog_enabled = bool(profile["volumetric_fog_enabled"])
		environment.volumetric_fog_density = float(profile["volumetric_fog_density"])
		environment.volumetric_fog_length = float(profile["volumetric_fog_length"])
		environment.volumetric_fog_sky_affect = float(profile["volumetric_fog_sky_affect"])
		environment.volumetric_fog_temporal_reprojection_enabled = quality == QualityLevel.HIGH
		environment.volumetric_fog_temporal_reprojection_amount = 0.9
		applied.append("volumetric_fog")
	else:
		skipped.append("volumetric_fog")

	if bool(capabilities["taa"]):
		if viewport != null and is_instance_valid(viewport):
			viewport.use_taa = bool(profile["taa_enabled"])
			applied.append("taa")
		else:
			skipped.append("taa:missing_viewport")
	else:
		skipped.append("taa")

	report["applied"] = true
	report["applied_features"] = applied
	report["skipped_features"] = skipped
	return report


static func _make_report(quality: int, context: RenderContext, capabilities: Dictionary) -> Dictionary:
	var profile := get_profile(quality)
	return {
		"applied": false,
		"quality": quality,
		"quality_name": profile.get("name", &"invalid"),
		"renderer_method": context.renderer_method,
		"headless": context.headless,
		"reason": &"",
		"applied_features": PackedStringArray(),
		"skipped_features": PackedStringArray(),
		"capabilities": capabilities.duplicate(true),
	}


static func _all_features() -> PackedStringArray:
	return PackedStringArray(["tonemap", "glow", "fog", "ssao", "ssil", "volumetric_fog", "taa"])
