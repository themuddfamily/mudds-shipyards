extends SceneTree

const ProfileScript := preload(
	"res://scripts/world/definitions/planetary_atmosphere_profile.gd"
)
const PresentationScript := preload(
	"res://scripts/world/planetary_cloud_presentation.gd"
)
const EXPECTED_ASSERTIONS := 42
const SHADER_CODE := """shader_type spatial;
uniform float cloud_base_radius_m = 100.0;
uniform float cloud_top_radius_m = 200.0;
uniform float cloud_coverage_unitless = 0.1;
uniform float cloud_observer_layer_factor_unitless = 0.2;
uniform vec3 cloud_wind_velocity_mps = vec3(1.0, 2.0, 3.0);
uniform vec3 cloud_wind_offset_m = vec3(4.0, 5.0, 6.0);
uniform float non_owned_gain = 0.33;
void fragment() { ALBEDO = vec3(non_owned_gain * 0.0); }
"""
const CANVAS_SHADER_CODE := """shader_type canvas_item;
uniform float cloud_base_radius_m = 100.0;
uniform float cloud_top_radius_m = 200.0;
uniform float cloud_coverage_unitless = 0.1;
uniform float cloud_observer_layer_factor_unitless = 0.2;
uniform vec3 cloud_wind_velocity_mps = vec3(1.0, 2.0, 3.0);
uniform vec3 cloud_wind_offset_m = vec3(4.0, 5.0, 6.0);
void fragment() { COLOR = vec4(0.0); }
"""
const EXPECTED_PARAMETERS := [
	"cloud_base_radius_m",
	"cloud_top_radius_m",
	"cloud_coverage_unitless",
	"cloud_observer_layer_factor_unitless",
	"cloud_wind_velocity_mps",
	"cloud_wind_offset_m",
]
const COMMON_AUTHORITY_KEYS := [
	"renderer", "gameplay", "streaming", "save", "network", "physics",
	"world_generation", "terrain_generation", "collision_generation",
	"origin_shift", "weather_clock", "audio",
]
const ADJACENT_AUTHORITY_KEYS := [
	"material_ownership", "shader_ownership", "cloud_geometry", "cloud_volume",
	"textures", "noise", "cloud_density", "cloud_lighting",
	"weather_selection", "weather_clock", "time_accumulation", "time_wrapping",
	"wind_simulation", "camera", "visual_quality", "origin_application",
	"movement", "landing", "gameplay",
]
const CAPABILITY_KEYS := [
	"cloud_material_uniform_adapter_implemented",
	"visible_cloud_renderer_implemented", "production_cloud_shader_implemented",
	"cloud_geometry_implemented", "weather_selection_implemented",
	"weather_simulation_implemented", "clock_implemented", "caller_time_only",
	"transactional_material_apply", "consolidated_resource_changed_notification",
	"tree_exit_restores_baseline", "tree_reentry_reapplies_current_generation",
]

var _assertions := 0
var _failures := PackedStringArray()
var _events: Array[Dictionary] = []
var _adapter: PlanetaryCloudPresentation
var _profile: PlanetaryAtmosphereProfile
var _material: ShaderMaterial
var _shader: Shader
var _probe_signal_reentry := false
var _signal_reentry_results: Array[Dictionary] = []
var _material_attack_armed := false
var _material_attack_mode: StringName = &""
var _material_reentry_results: Array[Dictionary] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_configuration_rejections()
	var fixture := _make_fixture()
	_adapter = fixture.adapter
	_profile = fixture.profile
	_material = fixture.material
	_shader = fixture.shader
	_adapter.presentation_committed.connect(_on_presentation_committed)
	_material.changed.connect(_on_material_changed)
	_test_configuration_and_source_detachment()
	_test_exact_layer_boundaries_and_global_values()
	_test_scalars_wind_and_caller_time()
	_test_invalid_and_overflow_atomicity()
	_test_owned_drift_and_non_owned_state()
	_test_real_resource_and_signal_transactions()
	await _test_detach_reentry()
	_test_reset_reports_and_structured_red()
	await _test_expired_target_fails_closed()
	if is_instance_valid(_adapter):
		_adapter.queue_free()
	await process_frame
	_finish()


func _test_configuration_rejections() -> void:
	var adapter := PresentationScript.new() as PlanetaryCloudPresentation
	root.add_child(adapter)
	var invalid_profile := ProfileScript.new() as PlanetaryAtmosphereProfile
	invalid_profile.cloud_top_altitude_m = NAN
	var no_shader := ShaderMaterial.new()
	var canvas_material := _material_for_code(CANVAS_SHADER_CODE)
	var state := adapter.get_state_snapshot()
	_check(
		adapter.configure(null, _make_material()).reason == &"missing_profile"
		and adapter.configure(ProfileScript.new(), null).reason == &"missing_material"
		and adapter.get_state_snapshot() == state,
		"missing profile/material reject without partial configuration"
	)
	_check(
		adapter.configure(invalid_profile, _make_material()).reason == &"invalid_profile"
		and adapter.configure(ProfileScript.new(), no_shader).reason == &"missing_shader"
		and adapter.configure(ProfileScript.new(), canvas_material).reason
		== &"shader_not_spatial",
		"invalid profile and absent/non-spatial shaders have exact reasons"
	)
	var missing_code := SHADER_CODE.replace(
		"uniform float cloud_coverage_unitless = 0.1;\n", ""
	)
	var wrong_type_code := SHADER_CODE.replace(
		"uniform vec3 cloud_wind_offset_m = vec3(4.0, 5.0, 6.0);",
		"uniform float cloud_wind_offset_m = 4.0;"
	)
	_check(
		adapter.configure(
			ProfileScript.new(), _material_for_code(missing_code)
		).reason == &"shader_uniform_contract_mismatch"
		and adapter.configure(
			ProfileScript.new(), _material_for_code(wrong_type_code)
		).reason == &"shader_uniform_contract_mismatch",
		"missing and mistyped required uniforms reject by introspected schema"
	)
	var bad_baseline := _make_material()
	bad_baseline.set_shader_parameter(&"cloud_coverage_unitless", 1.1)
	_check(
		adapter.configure(ProfileScript.new(), bad_baseline).reason
		== &"invalid_material_baseline"
		and adapter.reset_for_reuse(0).reason == &"not_configured"
		and not bool(adapter.audit().valid),
		"out-of-bounds baseline, premature reset, and unconfigured audit fail closed"
	)
	adapter.queue_free()


func _test_configuration_and_source_detachment() -> void:
	var baseline := _parameter_values(_material)
	var configured := _adapter.configure(_profile, _material)
	var state := _adapter.get_state_snapshot()
	_check(
		configured.accepted and configured.reason == &"configured"
		and int(configured.generation) == 1 and int(configured.revision) == 1
		and state.profile_id == &"temperate_game_scale"
		and state.equation_version == PresentationScript.EQUATION_VERSION,
		"valid profile/material configure exact generation and equation identity"
	)
	_check(
		state.renderer.baseline == baseline
		and state.renderer.expected == baseline
		and state.renderer.actual == baseline
		and state.renderer.owned_parameters == EXPECTED_PARAMETERS
		and bool(state.renderer.current_values_applied),
		"configuration freezes exact six-parameter baseline and weak target identity"
	)
	_check(
		bool(_adapter.audit().valid) and _adapter.get_child_count() == 0
		and not _adapter.is_processing() and not _adapter.is_physics_processing(),
		"configured adapter is valid, childless, and has no private cadence"
	)
	var snapshot := _adapter.get_state_snapshot()
	_check(
		_adapter.configure(ProfileScript.new(), _make_material()).reason
		== &"already_configured"
		and _adapter.get_state_snapshot() == snapshot,
		"successful configuration is immutable"
	)
	_profile.profile_id = &"caller_mutated"
	_profile.planet_radius_m = 500000.0
	_profile.cloud_coverage_unitless = 0.99
	_profile.wind_velocity_mps = Vector3(100.0, 100.0, 100.0)
	var frozen := _adapter.get_profile_snapshot()
	_check(
		frozen.profile_id == &"temperate_game_scale"
		and frozen.geometry.planet_radius_m == 120000.0
		and frozen.weather.cloud_coverage_unitless == 0.55
		and frozen.weather.wind_velocity_mps == Vector3(12.0, 0.0, -4.0),
		"caller profile mutation cannot retune frozen radii, coverage, or wind"
	)


func _test_exact_layer_boundaries_and_global_values() -> void:
	var below := _adapter.present_observation(2999.999, 10.0, 0.5, 0.8, 1)
	var base := _adapter.present_observation(3000.0, 10.0, 0.5, 0.8, 1)
	var below_top := _adapter.present_observation(5999.999, 10.0, 0.5, 0.8, 1)
	var top := _adapter.present_observation(6000.0, 10.0, 0.5, 0.8, 1)
	_check(
		below.accepted and base.accepted and below_top.accepted and top.accepted
		and below.observation.cloud_observer_layer_factor_unitless == 0.0
		and is_equal_approx(
			base.observation.cloud_observer_layer_factor_unitless, 0.44
		)
		and is_equal_approx(
			below_top.observation.cloud_observer_layer_factor_unitless, 0.44
		)
		and top.observation.cloud_observer_layer_factor_unitless == 0.0,
		"observer membership is exactly cloud-base inclusive and top exclusive"
	)
	_check(
		base.observation.cloud_base_radius_m == 123000.0
		and base.observation.cloud_top_radius_m == 126000.0
		and _material.get_shader_parameter(&"cloud_base_radius_m") == 123000.0
		and _material.get_shader_parameter(&"cloud_top_radius_m") == 126000.0,
		"profile surface altitudes map to exact body-centred cloud radii"
	)
	var expected_wind := Vector3(6.0, 0.0, -2.0)
	var expected_offset := Vector3(60.0, 0.0, -20.0)
	_check(
		is_equal_approx(below.observation.cloud_coverage_unitless, 0.44)
		and is_equal_approx(top.observation.cloud_coverage_unitless, 0.44)
		and below.observation.cloud_wind_velocity_mps == expected_wind
		and top.observation.cloud_wind_velocity_mps == expected_wind
		and below.observation.cloud_wind_offset_m == expected_offset
		and top.observation.cloud_wind_offset_m == expected_offset,
		"global coverage and wind remain independent of observer layer membership"
	)
	var orbit := _adapter.present_observation(20000.0, 10.0, 0.5, 0.8, 1)
	_check(
		orbit.accepted and bool(orbit.observation.sample.vacuum)
		and orbit.observation.cloud_observer_layer_factor_unitless == 0.0
		and is_equal_approx(orbit.observation.cloud_coverage_unitless, 0.44)
		and orbit.observation.cloud_wind_velocity_mps == expected_wind
		and orbit.observation.cloud_wind_offset_m == expected_offset,
		"sampler vacuum zeros only observer membership, not the global cloud layer"
	)


func _test_scalars_wind_and_caller_time() -> void:
	var clear := _adapter.present_observation(3000.0, 12345.0, 0.0, 0.0, 1)
	_check(
		clear.accepted and clear.observation.cloud_coverage_unitless == 0.0
		and clear.observation.cloud_observer_layer_factor_unitless == 0.0
		and clear.observation.cloud_wind_velocity_mps == Vector3.ZERO
		and clear.observation.cloud_wind_offset_m == Vector3.ZERO,
		"zero caller scalars produce exact clear coverage and stationary wind"
	)
	var full := _adapter.present_observation(3000.0, 100.0, 1.0, 1.0, 1)
	_check(
		full.accepted
		and is_equal_approx(full.observation.cloud_coverage_unitless, 0.55)
		and full.observation.cloud_wind_velocity_mps == Vector3(12.0, 0.0, -4.0)
		and full.observation.cloud_wind_offset_m == Vector3(1200.0, 0.0, -400.0),
		"full scalars preserve authored signed wind and exact time-derived offset"
	)
	var time_zero := _adapter.present_observation(3000.0, 0.0, 1.0, 1.0, 1)
	_check(
		time_zero.accepted
		and time_zero.observation.cloud_wind_velocity_mps == Vector3(12.0, 0.0, -4.0)
		and time_zero.observation.cloud_wind_offset_m == Vector3.ZERO,
		"caller epoch zero preserves velocity with exact zero offset"
	)
	var before_duplicate := _adapter.get_state_snapshot()
	var event_count := _events.size()
	var cadence_30 := _adapter.present_observation(3000.0, 0.0, 1.0, 1.0, 1)
	var cadence_60 := _adapter.present_observation(3000.0, 0.0, 1.0, 1.0, 1)
	var cadence_120 := _adapter.present_observation(3000.0, 0.0, 1.0, 1.0, 1)
	_check(
		cadence_30.reason == &"unchanged" and cadence_60.reason == &"unchanged"
		and cadence_120.reason == &"unchanged"
		and _adapter.get_state_snapshot() == before_duplicate
		and _events.size() == event_count,
		"30/60/120-equivalent complete observations are pure and signal-free"
	)
	var huge_zero_wind := _adapter.present_observation(
		3000.0, 1.0e100, 0.0, 1.0, 1
	)
	_check(
		huge_zero_wind.accepted
		and huge_zero_wind.observation.cloud_wind_offset_m == Vector3.ZERO,
		"finite caller time has no hidden cap when computed wind offset stays zero"
	)


func _test_invalid_and_overflow_atomicity() -> void:
	var before := _adapter.get_state_snapshot()
	var values_before := _parameter_values(_material)
	var event_count := _events.size()
	var rejected := [
		_adapter.present_observation(NAN, 0.0, 1.0, 1.0, 1),
		_adapter.present_observation(-120000.01, 0.0, 1.0, 1.0, 1),
		_adapter.present_observation(0.0, NAN, 1.0, 1.0, 1),
		_adapter.present_observation(0.0, -0.1, 1.0, 1.0, 1),
		_adapter.present_observation(0.0, 0.0, -0.01, 1.0, 1),
		_adapter.present_observation(0.0, 0.0, 1.0, 1.01, 1),
		_adapter.present_observation(0.0, 0.0, 1.0, 1.0, 0),
		_adapter.present_observation(0.0, 0.0, 1.0, 1.0, 1.0),
	]
	var all_rejected := true
	for result: Dictionary in rejected:
		all_rejected = all_rejected and not bool(result.accepted)
	_check(
		all_rejected and rejected[0].reason == &"invalid_altitude"
		and rejected[2].reason == &"invalid_caller_time"
		and rejected[4].reason == &"invalid_weather_intensity"
		and rejected[5].reason == &"invalid_cloud_coverage"
		and rejected[6].reason == &"stale_generation",
		"nonfinite/range/scalar/generation inputs have exact typed-red reasons"
	)
	_check(
		_adapter.get_state_snapshot() == before
		and _parameter_values(_material) == values_before
		and _events.size() == event_count,
		"all invalid observations are atomic and signal-free"
	)
	var wind_length := Vector3(12.0, 0.0, -4.0).length()
	var exact_time := PresentationScript.MAX_CLOUD_WIND_OFFSET_M / wind_length
	var exact := _adapter.present_observation(3000.0, exact_time, 1.0, 1.0, 1)
	_check(
		exact.accepted and is_equal_approx(
			exact.observation.cloud_wind_offset_m.length(),
			PresentationScript.MAX_CLOUD_WIND_OFFSET_M
		),
		"exact maximum derived wind-offset boundary remains accepted"
	)
	before = _adapter.get_state_snapshot()
	values_before = _parameter_values(_material)
	event_count = _events.size()
	var above_time := (
		PresentationScript.MAX_CLOUD_WIND_OFFSET_M + 0.25
	) / wind_length
	var overflow := _adapter.present_observation(
		3000.0, above_time, 1.0, 1.0, 1
	)
	_check(
		overflow.reason == &"wind_offset_out_of_bounds"
		and _adapter.get_state_snapshot() == before
		and _parameter_values(_material) == values_before
		and _events.size() == event_count,
		"a stable representable wind offset 0.25 m above the maximum rejects atomically"
	)


func _test_owned_drift_and_non_owned_state() -> void:
	_material.set_shader_parameter(&"non_owned_gain", 0.77)
	_check(
		bool(_adapter.audit().valid)
		and is_equal_approx(
			float(_material.get_shader_parameter(&"non_owned_gain")), 0.77
		),
		"extra caller shader uniform is non-owned and audit-green"
	)
	_material.set_shader_parameter(&"cloud_coverage_unitless", 0.99)
	_check(
		not bool(_adapter.audit().valid)
		and (_adapter.audit().errors as PackedStringArray).has(
			"owned_material_state_drift"
		),
		"external owned-uniform mutation is structured red"
	)
	var observation := _adapter.get_state_snapshot().last_observation as Dictionary
	var repaired := _adapter.present_observation(
		observation.inputs.altitude_m,
		observation.inputs.caller_time_seconds,
		observation.inputs.weather_scalar,
		observation.inputs.cloud_scalar,
		1
	)
	_check(
		repaired.reason == &"material_reapplied" and bool(_adapter.audit().valid)
		and is_equal_approx(
			float(_material.get_shader_parameter(&"non_owned_gain")), 0.77
		),
		"duplicate observation repairs owned drift without touching extra uniforms"
	)


func _test_real_resource_and_signal_transactions() -> void:
	_material_reentry_results.clear()
	_material_attack_mode = &"reentry_only"
	_material_attack_armed = true
	var before_revision := int(_adapter.get_state_snapshot().revision)
	var result := _adapter.present_observation(3500.0, 10.0, 0.9, 0.9, 1)
	_check(
		result.accepted and _material_reentry_results.size() == 3
		and _all_reason(_material_reentry_results, &"reentrant_call"),
		"real ShaderMaterial.changed callback cannot reenter any public mutator"
	)
	_probe_signal_reentry = true
	var signaled := _adapter.present_observation(3600.0, 11.0, 0.9, 0.9, 1)
	_probe_signal_reentry = false
	_check(
		signaled.accepted and _signal_reentry_results.size() == 3
		and _all_reason(_signal_reentry_results, &"reentrant_call")
		and int(_adapter.get_state_snapshot().revision) == before_revision + 2,
		"post-commit signal observes committed values and rejects all mutator reentry"
	)

	var original_shader := _shader
	var previous_state := _adapter.get_state_snapshot()
	var previous_values := _parameter_values(_material)
	var previous_events := _events.size()
	_material_reentry_results.clear()
	_material_attack_mode = &"replace_shader"
	_material_attack_armed = true
	var target_attack := _adapter.present_observation(3700.0, 12.0, 0.8, 0.8, 1)
	var target_state := _adapter.get_state_snapshot()
	_check(
		not bool(target_attack.accepted)
		and target_attack.reason == &"target_chain_changed_during_apply"
		and int(target_state.revision) == int(previous_state.revision)
		and target_state.last_observation == previous_state.last_observation
		and int(target_state.presented_observation_count)
		== int(previous_state.presented_observation_count)
		and _events.size() == previous_events
		and _all_reason(_material_reentry_results, &"reentrant_call"),
		"changed callback shader replacement cannot commit state, count, or signal"
	)
	_material.shader = original_shader
	_set_parameter_values(_material, previous_values)
	_check(bool(_adapter.audit().valid), "caller target restoration recovers exact retained state")

	previous_state = _adapter.get_state_snapshot()
	previous_values = _parameter_values(_material)
	previous_events = _events.size()
	_material_reentry_results.clear()
	_material_attack_mode = &"overwrite_parameter"
	_material_attack_armed = true
	var value_attack := _adapter.present_observation(3800.0, 13.0, 0.7, 0.7, 1)
	_check(
		not bool(value_attack.accepted)
		and value_attack.reason == &"renderer_state_changed_during_apply"
		and _adapter.get_state_snapshot() == previous_state
		and _parameter_values(_material) == previous_values
		and _events.size() == previous_events
		and _all_reason(_material_reentry_results, &"reentrant_call"),
		"changed callback parameter overwrite rolls back the full transaction"
	)

	previous_state = _adapter.get_state_snapshot()
	previous_values = _parameter_values(_material)
	previous_events = _events.size()
	_material_reentry_results.clear()
	_material_attack_mode = &"mutate_schema"
	_material_attack_armed = true
	var schema_attack := _adapter.present_observation(3900.0, 14.0, 0.6, 0.6, 1)
	_check(
		not bool(schema_attack.accepted)
		and schema_attack.reason == &"shader_schema_changed_during_apply"
		and int(_adapter.get_state_snapshot().revision) == int(previous_state.revision)
		and _adapter.get_state_snapshot().last_observation
		== previous_state.last_observation
		and _events.size() == previous_events
		and _all_reason(_material_reentry_results, &"reentrant_call"),
		"changed callback schema mutation is a distinct no-commit typed red"
	)
	_shader.code = SHADER_CODE
	_set_parameter_values(_material, previous_values)
	_check(bool(_adapter.audit().valid), "schema restoration recovers exact retained state")


func _test_detach_reentry() -> void:
	var successful := _adapter.present_observation(4000.0, 15.0, 0.5, 0.5, 1)
	var state := _adapter.get_state_snapshot()
	var expected := _adapter.get_renderer_snapshot().expected as Dictionary
	var baseline := _adapter.get_renderer_snapshot().baseline as Dictionary
	var events := _events.size()
	root.remove_child(_adapter)
	_check(
		successful.accepted and _parameter_values(_material) == baseline
		and bool(_adapter.get_renderer_snapshot().baseline_applied_while_detached),
		"whole-component detach restores all six exact material baselines"
	)
	root.add_child(_adapter)
	_check(
		_parameter_values(_material) == expected
		and _adapter.get_generation() == int(state.generation)
		and int(_adapter.get_state_snapshot().revision) == int(state.revision)
		and _events.size() == events and bool(_adapter.audit().valid),
		"re-entry reapplies retained generation without revision, signal, or identity drift"
	)
	await process_frame


func _test_reset_reports_and_structured_red() -> void:
	var old_generation := _adapter.get_generation()
	var baseline := _adapter.get_renderer_snapshot().baseline as Dictionary
	var reset := _adapter.reset_for_reuse(old_generation)
	_check(
		reset.accepted and reset.reason == &"reset"
		and int(reset.generation) == old_generation + 1
		and not bool(_adapter.get_state_snapshot().has_presented_observation)
		and _parameter_values(_material) == baseline,
		"reset applies baseline before tombstoning the old generation"
	)
	_check(
		_adapter.present_observation(3000.0, 0.0, 1.0, 1.0, old_generation).reason
		== &"stale_generation",
		"pre-reset generation cannot mutate reused material state"
	)
	var audit := _adapter.audit()
	_check(
		_exact_authority(audit.authority, COMMON_AUTHORITY_KEYS, &"renderer")
		and _exact_authority(audit.adjacent_authority, ADJACENT_AUTHORITY_KEYS)
		and _exact_capabilities(audit.capabilities)
		and audit.owned_shader_parameters == EXPECTED_PARAMETERS,
		"audit freezes exact renderer-only authority, capability, and owned roster"
	)
	_check(
		audit.performance.runtime_child_node_count == 0
		and audit.performance.owned_renderer_node_count == 0
		and audit.performance.owned_material_resource_count == 0
		and audit.performance.owned_shader_resource_count == 0
		and audit.performance.renderer_resource_allocations_after_configuration == 0
		and audit.performance.process_loop_count == 0
		and not _contains_live_capability(audit),
		"detached audit reports zero nodes/resources/process and no live capability"
	)
	var audit_attack := audit
	audit_attack.state.profile.weather.cloud_coverage_unitless = 9.0
	audit_attack.authority.renderer = false
	var renderer_attack := _adapter.get_renderer_snapshot()
	renderer_attack.baseline.cloud_coverage_unitless = 9.0
	_check(
		_adapter.audit().state.profile.weather.cloud_coverage_unitless == 0.55
		and bool(_adapter.audit().authority.renderer)
		and _adapter.get_renderer_snapshot().baseline.cloud_coverage_unitless == 0.1,
		"nested audit and renderer snapshots are deeply detached"
	)
	var child := Node.new()
	_adapter.add_child(child)
	_check(
		not bool(_adapter.audit().valid)
		and (_adapter.audit().errors as PackedStringArray).has(
			"passive_adapter_gained_child_nodes"
		),
		"unexpected child authority is structured red"
	)
	_adapter.remove_child(child)
	child.free()
	_adapter.set("_generation", PresentationScript.MAX_SAFE_GENERATION)
	var before := _adapter.get_state_snapshot()
	var exhausted := _adapter.reset_for_reuse(PresentationScript.MAX_SAFE_GENERATION)
	_check(
		exhausted.reason == &"generation_exhausted"
		and _adapter.get_state_snapshot() == before,
		"safe-integer generation exhaustion is atomic and never wraps"
	)
	_adapter.set("_generation", old_generation + 1)


func _test_expired_target_fails_closed() -> void:
	var fixture := _make_fixture()
	var adapter := fixture.adapter as PlanetaryCloudPresentation
	var material := fixture.material as ShaderMaterial
	var shader := fixture.shader as Shader
	var configured := adapter.configure(fixture.profile, material)
	root.remove_child(adapter)
	fixture.clear()
	material = null
	shader = null
	await process_frame
	_check(
		configured.accepted and not bool(adapter.audit().valid)
		and not bool(adapter.get_renderer_snapshot().target_available)
		and adapter.present_observation(3000.0, 0.0, 1.0, 1.0, 1).reason
		== &"renderer_target_unavailable",
		"expired weak material/shader identities fail closed without live reports"
	)
	adapter.free()


func _on_presentation_committed(reason: StringName, snapshot: Dictionary) -> void:
	_events.append({"reason": reason, "snapshot": snapshot.duplicate(true)})
	if int(snapshot.revision) != int(_adapter.get_state_snapshot().revision) \
			or snapshot.renderer.expected != snapshot.renderer.actual:
		_failures.append("presentation signal observed uncommitted parameter state")
	if _probe_signal_reentry:
		_signal_reentry_results = [
			_adapter.configure(_profile, _material),
			_adapter.present_observation(
				3000.0, 0.0, 1.0, 1.0, _adapter.get_generation()
			),
			_adapter.reset_for_reuse(_adapter.get_generation()),
		]


func _on_material_changed() -> void:
	if not _material_attack_armed:
		return
	_material_attack_armed = false
	_material_reentry_results = [
		_adapter.configure(_profile, _material),
		_adapter.present_observation(
			3000.0, 0.0, 1.0, 1.0, _adapter.get_generation()
		),
		_adapter.reset_for_reuse(_adapter.get_generation()),
	]
	if _material_attack_mode == &"replace_shader":
		_material.shader = _shader_for_code(SHADER_CODE)
	elif _material_attack_mode == &"overwrite_parameter":
		_material.set_shader_parameter(&"cloud_base_radius_m", 777.0)
	elif _material_attack_mode == &"mutate_schema":
		_shader.code = SHADER_CODE.replace(
			"uniform float cloud_coverage_unitless = 0.1;\n", ""
		)


func _make_fixture() -> Dictionary:
	var profile := ProfileScript.new() as PlanetaryAtmosphereProfile
	var material := _make_material()
	var adapter := PresentationScript.new() as PlanetaryCloudPresentation
	adapter.name = "PlanetaryCloudPresentation"
	root.add_child(adapter)
	return {
		"profile": profile,
		"material": material,
		"shader": material.shader,
		"adapter": adapter,
	}


func _make_material() -> ShaderMaterial:
	var material := _material_for_code(SHADER_CODE)
	material.set_shader_parameter(&"cloud_base_radius_m", 100.0)
	material.set_shader_parameter(&"cloud_top_radius_m", 200.0)
	material.set_shader_parameter(&"cloud_coverage_unitless", 0.1)
	material.set_shader_parameter(
		&"cloud_observer_layer_factor_unitless", 0.2
	)
	material.set_shader_parameter(
		&"cloud_wind_velocity_mps", Vector3(1.0, 2.0, 3.0)
	)
	material.set_shader_parameter(
		&"cloud_wind_offset_m", Vector3(4.0, 5.0, 6.0)
	)
	return material


func _material_for_code(code: String) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = _shader_for_code(code)
	return material


func _shader_for_code(code: String) -> Shader:
	var shader := Shader.new()
	shader.code = code
	return shader


func _parameter_values(material: ShaderMaterial) -> Dictionary:
	var values := {}
	for parameter_name: String in EXPECTED_PARAMETERS:
		values[parameter_name] = material.get_shader_parameter(parameter_name)
	return values.duplicate(true)


func _set_parameter_values(material: ShaderMaterial, values: Dictionary) -> void:
	for parameter_name: String in EXPECTED_PARAMETERS:
		material.set_shader_parameter(parameter_name, values[parameter_name])


func _all_reason(results: Array[Dictionary], reason: StringName) -> bool:
	for result: Dictionary in results:
		if result.reason != reason:
			return false
	return true


func _exact_authority(
		value: Variant,
		expected_keys: Array,
		true_key: StringName = &""
	) -> bool:
	if value is not Dictionary:
		return false
	var dictionary := value as Dictionary
	if dictionary.size() != expected_keys.size():
		return false
	for key: String in expected_keys:
		if not dictionary.has(key) or dictionary[key] is not bool:
			return false
		if bool(dictionary[key]) != (StringName(key) == true_key):
			return false
	return true


func _exact_capabilities(value: Variant) -> bool:
	if value is not Dictionary or (value as Dictionary).size() != CAPABILITY_KEYS.size():
		return false
	for key: String in CAPABILITY_KEYS:
		if not (value as Dictionary).get(key) is bool:
			return false
	var capabilities := value as Dictionary
	return bool(capabilities.cloud_material_uniform_adapter_implemented) \
		and bool(capabilities.caller_time_only) \
		and bool(capabilities.transactional_material_apply) \
		and bool(capabilities.consolidated_resource_changed_notification) \
		and bool(capabilities.tree_exit_restores_baseline) \
		and bool(capabilities.tree_reentry_reapplies_current_generation) \
		and not bool(capabilities.visible_cloud_renderer_implemented) \
		and not bool(capabilities.production_cloud_shader_implemented) \
		and not bool(capabilities.cloud_geometry_implemented) \
		and not bool(capabilities.weather_selection_implemented) \
		and not bool(capabilities.weather_simulation_implemented) \
		and not bool(capabilities.clock_implemented)


func _contains_live_capability(value: Variant) -> bool:
	if value is Node or value is Resource or value is WeakRef \
			or value is Callable or value is Signal:
		return true
	if value is Dictionary:
		for key: Variant in value:
			if _contains_live_capability(key) \
					or _contains_live_capability((value as Dictionary)[key]):
				return true
	elif value is Array:
		for entry: Variant in value:
			if _contains_live_capability(entry):
				return true
	return false


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: %s" % description)


func _finish() -> void:
	print("PLANETARY_CLOUD_PRESENTATION_ASSERTIONS: ", _assertions)
	if _assertions != EXPECTED_ASSERTIONS:
		_failures.append(
			"assertion count drifted: expected %d got %d"
			% [EXPECTED_ASSERTIONS, _assertions]
		)
	if _failures.is_empty():
		print("PLANETARY_CLOUD_PRESENTATION_TEST_OK")
		quit(0)
	else:
		print(
			"PLANETARY_CLOUD_PRESENTATION_TEST_FAILED: ",
			", ".join(_failures)
		)
		quit(1)
