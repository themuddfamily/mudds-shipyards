extends SceneTree

const WORLD_SCENE := preload("res://scenes/world/shipyard_world.tscn")
const Presenter := preload(
	"res://scripts/world/station_solar_readability_presentation.gd"
)
const SKY_SHADER := preload("res://scripts/rendering/deep_space_sky.gdshader")
const RuntimeSettingsScript := preload(
	"res://scripts/settings/runtime_settings.gd"
)
const EXPECTED_ASSERTIONS := 17

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_bounded_adapter()
	await _test_production_world_lifecycle()
	_finish()


func _test_bounded_adapter() -> void:
	var environment := Environment.new()
	environment.tonemap_exposure = 1.24
	environment.glow_intensity = 0.46
	environment.glow_strength = 1.12
	environment.glow_bloom = 0.02
	environment.glow_hdr_threshold = 1.3
	environment.glow_hdr_scale = 2.4
	environment.glow_hdr_luminance_cap = 5.0
	var source_levels := [0.0, 0.6, 0.6, 0.42, 0.15, 0.0, 0.0]
	for index in source_levels.size():
		environment.set_glow_level(index, float(source_levels[index]))
	environment.fog_sun_scatter = 0.14
	environment.volumetric_fog_anisotropy = 0.58
	var sky_material := ShaderMaterial.new()
	sky_material.shader = SKY_SHADER
	var sun_direction := Vector3(0.25, 0.5, 0.829156).normalized()
	sky_material.set_shader_parameter(&"sun_direction", sun_direction)
	sky_material.set_shader_parameter(&"sun_focus", Presenter.SUN_CORE_FOCUS)
	sky_material.set_shader_parameter(&"sun_halo", Presenter.SUN_HALO_STRENGTH)
	sky_material.set_shader_parameter(&"sun_halo_focus", Presenter.SUN_HALO_FOCUS)
	var baseline := _environment_values(environment)
	# Use the explicitly preloaded script instead of relying on a per-worktree
	# global class cache, which is absent in a clean checkout.
	var presenter = Presenter.new()
	var configured := presenter.configure(environment, sky_material)
	_check(
		bool(configured.accepted) and configured.reason == &"solar_readability_presented",
		"the passive adapter accepts the existing Environment and authored sky",
	)
	var snapshot := presenter.get_snapshot()
	var bounded := snapshot.current as Dictionary
	_check(
		is_equal_approx(float(bounded.tonemap_exposure), Presenter.MAX_TONEMAP_EXPOSURE)
		and is_equal_approx(float(bounded.glow_intensity), Presenter.MAX_GLOW_INTENSITY)
		and is_equal_approx(float(bounded.glow_strength), Presenter.MAX_GLOW_STRENGTH)
		and is_equal_approx(float(bounded.glow_bloom), Presenter.MAX_GLOW_BLOOM)
		and is_equal_approx(float(bounded.glow_hdr_threshold), Presenter.MIN_GLOW_HDR_THRESHOLD)
		and is_equal_approx(float(bounded.glow_hdr_scale), Presenter.MAX_GLOW_HDR_SCALE)
		and is_equal_approx(float(bounded.glow_hdr_luminance_cap), Presenter.MAX_GLOW_HDR_LUMINANCE_CAP)
		and is_equal_approx(float(bounded.fog_sun_scatter), Presenter.MAX_FOG_SUN_SCATTER)
		and is_equal_approx(float(bounded.volumetric_fog_anisotropy), Presenter.MAX_VOLUMETRIC_FOG_ANISOTROPY),
		"exposure, bloom, luminance, and sun-scatter terms have deterministic ceilings",
	)
	var bounded_levels := bounded.glow_levels as Array
	_check(
		is_equal_approx(float(bounded_levels[3]), 0.18)
		and is_zero_approx(float(bounded_levels[4]))
		and is_zero_approx(float(bounded_levels[5]))
		and is_zero_approx(float(bounded_levels[6])),
		"large glow mips are withheld while local emissive spill remains",
	)
	var fifteen_degrees := Presenter.sun_lobe_at_alignment(cos(deg_to_rad(15.0)))
	var thirty_degrees := Presenter.sun_lobe_at_alignment(cos(deg_to_rad(30.0)))
	_check(
		is_equal_approx(Presenter.sun_lobe_at_alignment(1.0), 1.18)
		and fifteen_degrees > 0.0 and fifteen_degrees < 0.04
		and thirty_degrees > 0.0 and thirty_degrees < 0.0002,
		"the bright sun centre survives while ordinary camera offsets receive negligible halo",
	)
	_check(
		(sky_material.get_shader_parameter(&"sun_direction") as Vector3) == sun_direction
		and is_equal_approx(float(sky_material.get_shader_parameter(&"sun_focus")), 260.0)
		and int(snapshot.node_budget) == 0 and int(snapshot.resource_budget) == 0
		and not bool(snapshot.camera_heading_sampling)
		and not bool(snapshot.light_direction_authority)
		and not bool(snapshot.gameplay_authority),
		"presentation preserves sun direction/core and adds no resource or authority",
	)
	var reduced := presenter.set_reduced_flash(
		true, presenter.get_generation()
	)
	var reduced_snapshot := presenter.get_snapshot()
	var reduced_values := reduced_snapshot.current as Dictionary
	var reduced_levels := reduced_values.glow_levels as Array
	_check(
		bool(reduced.accepted) and reduced.reason == &"reduced_flash_presented"
		and bool(reduced_snapshot.reduced_flash)
		and reduced_snapshot.profile_id == &"reduced_flash"
		and is_equal_approx(float(reduced_values.tonemap_exposure),
			Presenter.REDUCED_FLASH_MAX_TONEMAP_EXPOSURE)
		and is_equal_approx(float(reduced_values.glow_intensity),
			Presenter.REDUCED_FLASH_MAX_GLOW_INTENSITY)
		and is_equal_approx(float(reduced_values.glow_strength),
			Presenter.REDUCED_FLASH_MAX_GLOW_STRENGTH)
		and is_equal_approx(float(reduced_values.glow_bloom),
			Presenter.REDUCED_FLASH_MAX_GLOW_BLOOM)
		and is_equal_approx(float(reduced_values.glow_hdr_threshold),
			Presenter.REDUCED_FLASH_MIN_GLOW_HDR_THRESHOLD)
		and is_equal_approx(float(reduced_values.glow_hdr_scale),
			Presenter.REDUCED_FLASH_MAX_GLOW_HDR_SCALE)
		and is_equal_approx(float(reduced_values.glow_hdr_luminance_cap),
			Presenter.REDUCED_FLASH_MAX_GLOW_HDR_LUMINANCE_CAP)
		and is_equal_approx(float(reduced_levels[3]), 0.06),
		"reduced flash deterministically lowers the retained exposure/glow profile",
	)
	_check(
		is_equal_approx(float(sky_material.get_shader_parameter(&"sun_halo")),
			Presenter.REDUCED_FLASH_SUN_HALO_STRENGTH)
		and (sky_material.get_shader_parameter(&"sun_direction") as Vector3) \
			== sun_direction
		and is_equal_approx(float(sky_material.get_shader_parameter(&"sun_focus")),
			Presenter.SUN_CORE_FOCUS)
		and int(reduced_snapshot.node_budget) == 0
		and int(reduced_snapshot.resource_budget) == 0,
		"reduced flash lowers only the secondary halo without resources or sun authority",
	)
	var reduced_again := presenter.set_reduced_flash(
		true, presenter.get_generation()
	)
	_check(
		bool(reduced_again.accepted)
		and _environment_values(environment) == reduced_values,
		"repeated reduced-flash application is exact and non-compounding",
	)
	var normal_again := presenter.set_reduced_flash(
		false, presenter.get_generation()
	)
	_check(
		bool(normal_again.accepted)
		and normal_again.reason == &"normal_readability_restored"
		and _environment_values(environment) == bounded
		and is_equal_approx(float(sky_material.get_shader_parameter(&"sun_halo")),
			Presenter.SUN_HALO_STRENGTH),
		"disabling reduced flash restores the normal bounded profile exactly",
	)
	var stale := presenter.detach(&"stale", presenter.get_generation() + 1)
	_check(
		not bool(stale.accepted) and stale.reason == &"stale_generation"
		and _environment_values(environment) == bounded,
		"a stale detach cannot alter the live bounded presentation",
	)
	var detached := presenter.detach(&"fixture_detached", presenter.get_generation())
	_check(
		bool(detached.accepted) and _environment_values(environment) == baseline
		and is_equal_approx(float(sky_material.get_shader_parameter(&"sun_halo")),
			Presenter.SUN_HALO_STRENGTH),
		"a current detach restores every selected profile value exactly",
	)


func _test_production_world_lifecycle() -> void:
	var world := WORLD_SCENE.instantiate() as ShipyardWorld
	root.add_child(world)
	await process_frame
	await physics_frame
	var world_environment := world.get_node_or_null(
		^"ShipyardEnvironment"
	) as WorldEnvironment
	var report := world.get_station_solar_readability_report()
	var presentation := report.presentation as Dictionary
	_check(
		world_environment != null and world_environment.environment != null
		and root.find_children("*", "WorldEnvironment", true, false).size() == 1
		and bool(report.active) and int(report.attach_count) == 1
		and bool((world.get_space_backdrop_audit_report() as Dictionary).valid)
		and int(presentation.node_budget) == 0
		and int(presentation.resource_budget) == 0,
		"the production shipyard uses its one existing Environment with a valid zero-budget adapter",
	)
	if world_environment == null or world_environment.environment == null:
		world.queue_free()
		await process_frame
		return
	var environment := world_environment.environment
	var profile_baseline := presentation.baseline as Dictionary
	var normal_profile := presentation.current as Dictionary
	var direct_child_count := world.get_child_count()
	var settings = RuntimeSettingsScript.new()
	var settings_bound := world.bind_station_solar_runtime_settings(settings)
	settings.reduced_flash = true
	report = world.get_station_solar_readability_report()
	presentation = report.presentation as Dictionary
	var production_reduced := presentation.current as Dictionary
	_check(
		bool(settings_bound.accepted) and bool(report.runtime_settings_bound)
		and bool(report.reduced_flash) and bool(presentation.reduced_flash)
		and is_equal_approx(float(production_reduced.tonemap_exposure),
			Presenter.REDUCED_FLASH_MAX_TONEMAP_EXPOSURE)
		and is_equal_approx(float(production_reduced.glow_bloom),
			Presenter.REDUCED_FLASH_MAX_GLOW_BLOOM)
		and is_equal_approx(float((presentation.sky as Dictionary).sun_halo),
			Presenter.REDUCED_FLASH_SUN_HALO_STRENGTH)
		and int(report.attach_count) == 1
		and world.get_child_count() == direct_child_count,
		"the live RuntimeSettings signal immediately applies the zero-budget reduced profile",
	)
	settings.reduced_flash = false
	report = world.get_station_solar_readability_report()
	presentation = report.presentation as Dictionary
	_check(
		not bool(report.reduced_flash) and not bool(presentation.reduced_flash)
		and (presentation.current as Dictionary) == normal_profile
		and is_equal_approx(float((presentation.sky as Dictionary).sun_halo),
			Presenter.SUN_HALO_STRENGTH)
		and int(report.attach_count) == 1,
		"disabling the live setting restores normal bounds without reattachment",
	)
	settings.reduced_flash = true
	var parent := world.get_parent()
	parent.remove_child(world)
	await process_frame
	var detached_report := world.get_station_solar_readability_report()
	_check(
		not bool(detached_report.active) and int(detached_report.detach_count) == 1
		and bool(detached_report.reduced_flash)
		and _environment_values(environment) == profile_baseline,
		"whole-station detach restores the exact selected visual-quality profile",
	)
	parent.add_child(world)
	await process_frame
	await process_frame
	report = world.get_station_solar_readability_report()
	presentation = report.presentation as Dictionary
	_check(
		bool(report.active) and int(report.attach_count) == 2
		and int(report.detach_count) == 1
		and bool(presentation.reduced_flash)
		and is_equal_approx(float((presentation.current as Dictionary).glow_bloom),
			Presenter.REDUCED_FLASH_MAX_GLOW_BLOOM)
		and bool((world.get_space_backdrop_audit_report() as Dictionary).valid),
		"station re-entry reapplies exactly one bounded presentation",
	)
	world.apply_visual_quality(1)
	report = world.get_station_solar_readability_report()
	presentation = report.presentation as Dictionary
	_check(
		bool(report.active) and int(report.attach_count) == 3
		and int(report.detach_count) == 2
		and world.get_child_count() == direct_child_count
		and bool((presentation.current as Dictionary).glow_levels is Array)
		and is_equal_approx(
			float((presentation.current as Dictionary).glow_bloom),
			Presenter.REDUCED_FLASH_MAX_GLOW_BLOOM
		),
		"quality reselection derives fresh bounded values without nodes or compounding",
	)
	world.queue_free()
	await process_frame
	await process_frame


func _environment_values(environment: Environment) -> Dictionary:
	var levels: Array[float] = []
	for index in Presenter.GLOW_LEVEL_CAPS.size():
		levels.append(environment.get_glow_level(index))
	return {
		"tonemap_exposure": environment.tonemap_exposure,
		"glow_intensity": environment.glow_intensity,
		"glow_strength": environment.glow_strength,
		"glow_bloom": environment.glow_bloom,
		"glow_hdr_threshold": environment.glow_hdr_threshold,
		"glow_hdr_scale": environment.glow_hdr_scale,
		"glow_hdr_luminance_cap": environment.glow_hdr_luminance_cap,
		"glow_levels": levels,
		"fog_sun_scatter": environment.fog_sun_scatter,
		"volumetric_fog_anisotropy": environment.volumetric_fog_anisotropy,
	}.duplicate(true)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _assertions != EXPECTED_ASSERTIONS:
		_failures.append(
			"expected %d assertions, ran %d" % [EXPECTED_ASSERTIONS, _assertions]
		)
	if _failures.is_empty():
		print("STATION_SOLAR_READABILITY_PRESENTATION_TEST_OK: 17 assertions")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
