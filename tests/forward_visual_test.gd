extends SceneTree

const VisualQuality := preload("res://scripts/rendering/visual_quality_controller.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_profile_contracts()
	_test_capability_matrix()
	await _test_application_and_safety()
	_finish()


func _test_profile_contracts() -> void:
	var low: Dictionary = VisualQuality.get_profile(VisualQuality.QualityLevel.LOW)
	var medium: Dictionary = VisualQuality.get_profile(VisualQuality.QualityLevel.MEDIUM)
	var high: Dictionary = VisualQuality.get_profile(VisualQuality.QualityLevel.HIGH)

	_check(low.get("name") == &"low", "low profile is addressable")
	_check(medium.get("name") == &"medium", "medium profile is addressable")
	_check(high.get("name") == &"high", "high profile is addressable")
	_check(not bool(low.get("ssao_enabled")), "low disables SSAO")
	_check(bool(medium.get("ssao_enabled")) and not bool(medium.get("ssil_enabled")), "medium uses SSAO without SSIL")
	_check(bool(high.get("ssao_enabled")) and bool(high.get("ssil_enabled")), "high enables both screen-space lighting effects")
	_check(not bool(low.get("taa_enabled")) and bool(medium.get("taa_enabled")) and bool(high.get("taa_enabled")), "TAA scales from low to medium and high")
	_check(
		int(low.get("tonemap_mode")) == Environment.TONE_MAPPER_REINHARDT
		and int(medium.get("tonemap_mode")) == Environment.TONE_MAPPER_FILMIC
		and int(high.get("tonemap_mode")) == Environment.TONE_MAPPER_AGX,
		"tonemapping quality is deterministic"
	)
	_check(
		float(low.get("glow_intensity")) < float(medium.get("glow_intensity"))
		and float(medium.get("glow_intensity")) < float(high.get("glow_intensity")),
		"glow intensity increases monotonically"
	)
	_check(not bool(low.get("fog_enabled")) and bool(medium.get("fog_enabled")) and bool(high.get("volumetric_fog_enabled")), "fog progresses from disabled to volumetric")
	_check(VisualQuality.get_profile(-1).is_empty(), "invalid quality has no implicit fallback")

	# Callers cannot mutate the controller's source profile through a returned
	# Dictionary, which keeps future applications deterministic.
	high["taa_enabled"] = false
	_check(bool(VisualQuality.get_profile(VisualQuality.QualityLevel.HIGH)["taa_enabled"]), "returned profiles are detached copies")


func _test_capability_matrix() -> void:
	var forward: Dictionary = VisualQuality.get_capabilities(&"forward_plus")
	var compatibility: Dictionary = VisualQuality.get_capabilities(&"gl_compatibility")
	var mobile: Dictionary = VisualQuality.get_capabilities(&"mobile")
	var headless: Dictionary = VisualQuality.get_capabilities(&"forward_plus", true)
	var unknown: Dictionary = VisualQuality.get_capabilities(&"future_renderer")

	_check(bool(forward["ssao"]) and bool(forward["ssil"]) and bool(forward["taa"]) and bool(forward["volumetric_fog"]), "Forward+ exposes the complete profile")
	_check(bool(compatibility["environment"]) and bool(compatibility["ssao"]), "Compatibility retains common effects and Godot 4.7 SSAO")
	_check(not bool(compatibility["ssil"]) and not bool(compatibility["taa"]) and not bool(compatibility["volumetric_fog"]), "Compatibility rejects Forward+-only effects")
	_check(bool(mobile["environment"]) and not bool(mobile["ssao"]) and not bool(mobile["taa"]), "Mobile keeps only common profile effects")
	_check(not bool(headless["environment"]) and not bool(headless["ssao"]), "headless mode advertises no visual effects")
	_check(not bool(unknown["known_renderer"]), "unknown renderers fail closed")


func _test_application_and_safety() -> void:
	var viewport := SubViewport.new()
	viewport.name = "ForwardVisualTestViewport"
	root.add_child(viewport)
	var environment := Environment.new()
	environment.fog_density = 0.0037

	# Construction, profile reads, and capability reads have no side effects.
	var original_environment := _snapshot(environment)
	var original_taa := viewport.use_taa
	VisualQuality.new()
	VisualQuality.get_profile(VisualQuality.QualityLevel.HIGH)
	VisualQuality.get_capabilities(&"forward_plus")
	_check(_snapshot(environment) == original_environment and viewport.use_taa == original_taa, "inspection APIs do not mutate supplied state")

	var forced_headless := VisualQuality.RenderContext.new(&"forward_plus", true)
	var headless_report: Dictionary = VisualQuality.apply_profile(environment, viewport, VisualQuality.QualityLevel.HIGH, forced_headless)
	_check(not bool(headless_report["applied"]) and headless_report["reason"] == &"headless", "headless application is an explicit no-op")
	_check(_snapshot(environment) == original_environment and viewport.use_taa == original_taa, "headless no-op preserves all resource values")

	# The default production path must use effective runtime state rather than
	# the renderer requested in project.godot. This also covers automatic driver
	# fallback and the dummy renderer used by command-line test runners.
	var runtime_environment := Environment.new()
	var runtime_before := _snapshot(runtime_environment)
	var runtime_context: VisualQuality.RenderContext = VisualQuality.get_runtime_context()
	var runtime_report: Dictionary = VisualQuality.apply_profile(runtime_environment, null, VisualQuality.QualityLevel.HIGH)
	if runtime_context.headless:
		_check(not bool(runtime_report["applied"]) and runtime_report["reason"] == &"headless", "runtime path detects the real headless display")
		_check(_snapshot(runtime_environment) == runtime_before, "runtime headless detection preserves Environment state")
	elif bool(VisualQuality.get_capabilities(runtime_context.renderer_method)["known_renderer"]):
		_check(bool(runtime_report["applied"]), "runtime path applies on a recognized graphical renderer")
	else:
		_check(not bool(runtime_report["applied"]) and runtime_report["reason"] == &"unsupported_renderer", "runtime path fails closed on an unknown renderer")

	var forward := VisualQuality.RenderContext.new(&"forward_plus", false)
	var can_apply_forward_profile := runtime_context.headless or runtime_context.renderer_method == &"forward_plus"
	if can_apply_forward_profile:
		# Dummy/headless resource setters are safe for deterministic testing. On a
		# real renderer, only exercise Forward+-only setters when Forward+ is active.
		var high_report: Dictionary = VisualQuality.apply_profile(environment, viewport, VisualQuality.QualityLevel.HIGH, forward)
		_check(bool(high_report["applied"]) and high_report["reason"] == &"", "Forward+ high profile applies")
		_check(environment.ssao_enabled and environment.ssil_enabled and environment.volumetric_fog_enabled, "Forward+ high enables advanced Environment effects")
		_check(viewport.use_taa, "Forward+ high enables viewport TAA")
		_check(environment.tonemap_mode == Environment.TONE_MAPPER_AGX, "Forward+ high applies AgX tonemapping")
		_check(is_equal_approx(environment.glow_intensity, 0.46), "Forward+ high applies the authored glow intensity")
		# Station-scale grading: contact darkening must reach directly lit faces,
		# emissive spill must span more than the default narrow blur pyramid, and
		# AgX must not compress the scene into the flat foot of its curve.
		_check(environment.ssao_light_affect > 0.0, "Forward+ high lets SSAO darken directly lit surfaces")
		_check(environment.ssao_radius > 2.0, "Forward+ high uses a station-scale SSAO radius")
		# Zero-based accessor: indices 3 and 4 are the inspector's glow_levels/4 and /5.
		# Index 5 must stay silent: that mip is effectively full-screen, and letting
		# it through veils the whole frame whenever an emissive changes state.
		_check(environment.get_glow_level(3) > 0.0 and environment.get_glow_level(4) > 0.0, "Forward+ high spreads glow past the default narrow pyramid")
		_check(is_zero_approx(environment.get_glow_level(5)) and is_zero_approx(environment.get_glow_level(6)), "Forward+ high withholds the full-screen glow mips")
		_check(environment.tonemap_agx_white < 16.0, "Forward+ high narrows the AgX white point onto the scene's real range")
		_check(environment.adjustment_enabled and environment.adjustment_saturation < 1.0, "Forward+ high grades saturation down after tonemapping")
		_check(is_equal_approx(environment.fog_density, 0.0037), "profiles preserve scene-scale fog density")
		_check((high_report["applied_features"] as PackedStringArray).has("taa"), "application report includes viewport work")

		var low_report: Dictionary = VisualQuality.apply_profile(environment, viewport, VisualQuality.QualityLevel.LOW, forward)
		_check(bool(low_report["applied"]), "Forward+ low profile applies after high")
		_check(not environment.ssao_enabled and not environment.ssil_enabled and not environment.volumetric_fog_enabled, "low disables supported advanced effects")
		_check(not environment.glow_enabled and not environment.fog_enabled and not viewport.use_taa, "low removes expensive post-processing")
		_check(not environment.adjustment_enabled, "low removes the colour-grading pass")
		_check(environment.tonemap_mode == Environment.TONE_MAPPER_REINHARDT, "low applies its inexpensive tonemapper")

	# Compatibility applies supported state but leaves unsupported values exactly
	# as authored. This is stronger than merely avoiding a crash.
	var authored_ssil_enabled := environment.ssil_enabled
	var authored_ssil_intensity := 0.37
	var authored_volumetric_enabled := environment.volumetric_fog_enabled
	var authored_volumetric_density := 0.0042
	var authored_taa := viewport.use_taa
	environment.ssil_intensity = authored_ssil_intensity
	environment.volumetric_fog_density = authored_volumetric_density
	var compatibility := VisualQuality.RenderContext.new(&"gl_compatibility", false)
	var compatibility_report: Dictionary = VisualQuality.apply_profile(environment, viewport, VisualQuality.QualityLevel.MEDIUM, compatibility)
	_check(bool(compatibility_report["applied"]) and environment.ssao_enabled, "Compatibility applies its supported SSAO path")
	_check(
		environment.ssil_enabled == authored_ssil_enabled
		and is_equal_approx(environment.ssil_intensity, authored_ssil_intensity)
		and environment.volumetric_fog_enabled == authored_volumetric_enabled
		and is_equal_approx(environment.volumetric_fog_density, authored_volumetric_density)
		and viewport.use_taa == authored_taa,
		"Compatibility no-ops unsupported properties"
	)
	var compatibility_skips := compatibility_report["skipped_features"] as PackedStringArray
	_check(compatibility_skips.has("ssil") and compatibility_skips.has("volumetric_fog") and compatibility_skips.has("taa"), "Compatibility reports every unsupported feature")

	if can_apply_forward_profile:
		var missing_viewport_report: Dictionary = VisualQuality.apply_profile(environment, null, VisualQuality.QualityLevel.HIGH, forward)
		_check(bool(missing_viewport_report["applied"]), "missing viewport does not block Environment configuration")
		_check((missing_viewport_report["skipped_features"] as PackedStringArray).has("taa:missing_viewport"), "missing viewport is reported without an error")

	var before_invalid := _snapshot(environment)
	var invalid_report: Dictionary = VisualQuality.apply_profile(environment, viewport, 999, forward)
	_check(not bool(invalid_report["applied"]) and invalid_report["reason"] == &"invalid_quality", "invalid profile fails safely")
	_check(_snapshot(environment) == before_invalid, "invalid profile preserves Environment state")

	var missing_environment_report: Dictionary = VisualQuality.apply_profile(null, viewport, VisualQuality.QualityLevel.HIGH, forward)
	_check(not bool(missing_environment_report["applied"]) and missing_environment_report["reason"] == &"missing_environment", "missing Environment fails safely")

	var unknown_environment := Environment.new()
	unknown_environment.glow_enabled = true
	var unknown_before := _snapshot(unknown_environment)
	var unknown := VisualQuality.RenderContext.new(&"future_renderer", false)
	var unknown_report: Dictionary = VisualQuality.apply_profile(unknown_environment, viewport, VisualQuality.QualityLevel.HIGH, unknown)
	_check(not bool(unknown_report["applied"]) and unknown_report["reason"] == &"unsupported_renderer", "unknown renderer fails closed")
	_check(_snapshot(unknown_environment) == unknown_before, "unknown renderer preserves Environment state")

	viewport.queue_free()
	await process_frame
	await process_frame


func _snapshot(environment: Environment) -> Dictionary:
	return {
		"tonemap_mode": environment.tonemap_mode,
		"glow_enabled": environment.glow_enabled,
		"glow_intensity": environment.glow_intensity,
		"fog_enabled": environment.fog_enabled,
		"fog_density": environment.fog_density,
		"ssao_enabled": environment.ssao_enabled,
		"ssil_enabled": environment.ssil_enabled,
		"volumetric_fog_enabled": environment.volumetric_fog_enabled,
	}


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("FORWARD_VISUAL_TEST_OK")
		quit(0)
	else:
		print("FORWARD_VISUAL_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
