extends SceneTree

const ProfileScript := preload(
	"res://scripts/world/definitions/planetary_atmosphere_profile.gd"
)
const PresentationScript := preload(
	"res://scripts/world/planetary_sky_presentation.gd"
)
const EXPECTED_ASSERTIONS := 47
const EXPECTED_RENDERER_PROPERTIES := [
	"sky_top_color", "sky_horizon_color", "ground_horizon_color",
]
const COMMON_AUTHORITY_KEYS := [
	"renderer", "gameplay", "streaming", "save", "network", "physics",
	"world_generation", "terrain_generation", "collision_generation",
	"origin_shift", "weather_clock", "audio",
]
const ADJACENT_AUTHORITY_KEYS := [
	"environment_ownership", "world_environment_ownership",
	"sky_resource_ownership", "sky_material_ownership", "background_mode",
	"ambient_light", "reflections", "fog", "clouds", "sun_light", "camera",
	"weather_selection", "weather_clock", "ship_movement", "player_movement",
	"landing", "gameplay",
]
const CAPABILITY_KEYS := [
	"procedural_sky_color_renderer_implemented", "fog_renderer_implemented",
	"cloud_renderer_implemented", "sun_renderer_implemented",
	"shell_renderer_implemented", "ambient_reflection_policy_implemented",
	"caller_driven_observations_only", "transactional_renderer_apply",
	"consolidated_resource_changed_notification", "tree_exit_restores_baseline",
	"tree_reentry_reapplies_current_generation",
]

var _assertions := 0
var _failures := PackedStringArray()
var _events: Array[Dictionary] = []
var _adapter: PlanetarySkyPresentation
var _profile: PlanetaryAtmosphereProfile
var _environment: Environment
var _material: ProceduralSkyMaterial
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
	_environment = fixture.environment
	_material = fixture.material
	_adapter.presentation_committed.connect(_on_presentation_committed)
	_material.changed.connect(_on_material_changed)
	_test_configuration_and_frozen_inputs()
	_test_exact_shell_paths_and_colours()
	_test_sun_view_mapping_and_cadence()
	_test_invalid_observations_are_atomic()
	_test_renderer_drift_and_non_owned_state()
	_test_signal_and_resource_reentry()
	await _test_detach_reentry()
	await _test_queued_adapter_rejects_atomically()
	_test_reset_reports_and_structured_red()
	_test_target_identity_replacement()
	await _test_expired_target_fails_closed()
	if is_instance_valid(_adapter):
		_adapter.queue_free()
	await process_frame
	_finish()


func _test_configuration_rejections() -> void:
	var adapter := PresentationScript.new() as PlanetarySkyPresentation
	root.add_child(adapter)
	var invalid_profile := ProfileScript.new() as PlanetaryAtmosphereProfile
	invalid_profile.planet_radius_m = NAN
	var no_sky_environment := Environment.new()
	no_sky_environment.background_mode = Environment.BG_SKY
	var wrong_mode := _make_target()
	wrong_mode.environment.background_mode = Environment.BG_COLOR
	var wrong_material_environment := Environment.new()
	wrong_material_environment.background_mode = Environment.BG_SKY
	wrong_material_environment.sky = Sky.new()
	wrong_material_environment.sky.sky_material = ShaderMaterial.new()
	var state := adapter.get_state_snapshot()
	_check(
		adapter.configure(null, _make_target().environment).reason
		== &"missing_profile"
		and adapter.configure(ProfileScript.new(), null).reason
		== &"missing_environment"
		and adapter.get_state_snapshot() == state,
		"missing profile/environment reject without partial state"
	)
	_check(
		adapter.configure(invalid_profile, _make_target().environment).reason
		== &"invalid_profile"
		and adapter.configure(ProfileScript.new(), wrong_mode.environment).reason
		== &"background_mode_not_sky"
		and adapter.configure(ProfileScript.new(), no_sky_environment).reason
		== &"missing_sky",
		"invalid profile and absent/non-sky target chain have stable reasons"
	)
	_check(
		adapter.configure(
			ProfileScript.new(), wrong_material_environment
		).reason == &"unsupported_sky_material"
		and adapter.reset_for_reuse(0).reason == &"not_configured"
		and not bool(adapter.audit().valid)
		and (adapter.audit().errors as PackedStringArray).has(
			"presentation_not_configured"
		),
		"custom shader target, premature reset, and unconfigured audit fail closed"
	)
	adapter.queue_free()


func _test_configuration_and_frozen_inputs() -> void:
	var baseline := _renderer_values(_material)
	var result := _adapter.configure(_profile, _environment)
	var snapshot := _adapter.get_state_snapshot()
	_check(
		result.accepted and result.reason == &"configured"
		and int(result.generation) == 1 and int(result.revision) == 1
		and snapshot.profile_id == &"temperate_game_scale"
		and snapshot.equation_version == PresentationScript.EQUATION_VERSION,
		"valid target configures exact profile/equation/generation identity"
	)
	_check(
		snapshot.renderer.baseline == baseline
		and snapshot.renderer.expected == baseline
		and snapshot.renderer.actual == baseline
		and snapshot.renderer.owned_properties == EXPECTED_RENDERER_PROPERTIES
		and bool(snapshot.renderer.current_values_applied),
		"configuration freezes the exact three-colour renderer baseline"
	)
	_check(
		bool(_adapter.audit().valid) and _adapter.get_child_count() == 0
		and not _adapter.is_processing() and not _adapter.is_physics_processing(),
		"configured adapter is valid, childless, and caller-cadence only"
	)
	var duplicate := _adapter.configure(ProfileScript.new(), _make_target().environment)
	_check(
		duplicate.reason == &"already_configured"
		and _adapter.get_state_snapshot() == snapshot,
		"configuration is immutable after its first successful commit"
	)
	_profile.profile_id = &"caller_mutated"
	_profile.planet_radius_m = 999999.0
	_profile.rayleigh_scattering_per_m = Color(1.0, 0.0, 0.0, 1.0)
	var frozen := _adapter.get_profile_snapshot()
	_check(
		frozen.profile_id == &"temperate_game_scale"
		and is_equal_approx(float(frozen.geometry.planet_radius_m), 120000.0)
		and frozen.optics.rayleigh_scattering_per_m
		== Color(0.0000058, 0.0000135, 0.0000331, 1.0),
		"source profile mutation cannot retune the detached sampler or mapping"
	)


func _test_exact_shell_paths_and_colours() -> void:
	var baseline := _adapter.get_renderer_snapshot().baseline as Dictionary
	var result := _adapter.present_observation(
		19000.0, Vector3.UP, Vector3.UP, Vector3.UP, 1
	)
	var observation := result.observation as Dictionary
	_check(
		result.accepted and result.reason == &"observation_presented"
		and is_equal_approx(float(observation.zenith_path_distance_m), 1000.0)
		and is_equal_approx(
			float(observation.horizon_path_distance_m),
			sqrt(140000.0 * 140000.0 - 139000.0 * 139000.0)
		)
		and not bool(observation.vacuum),
		"metre altitude maps to exact radial and tangent spherical-shell paths"
	)
	var expected_top := _expected_atmospheric_color(
		baseline.sky_top_color,
		observation.zenith_sample.optical_transmittance_rgb,
		observation.scattering_tint
	)
	var expected_horizon := _expected_atmospheric_color(
		baseline.sky_horizon_color,
		observation.horizon_sample.optical_transmittance_rgb,
		observation.scattering_tint
	)
	_check(
		_material.sky_top_color == expected_top
		and _material.sky_horizon_color == expected_horizon
		and _material.ground_horizon_color == _expected_atmospheric_color(
			baseline.ground_horizon_color,
			observation.horizon_sample.optical_transmittance_rgb,
			observation.scattering_tint
		),
		"top and both horizon colours use exact component-wise transmittance mapping"
	)
	_check(
		float(observation.horizon_path_distance_m)
		> float(observation.zenith_path_distance_m)
		and observation.horizon_sample.optical_transmittance_unitless
		< observation.zenith_sample.optical_transmittance_unitless,
		"near-top horizon has the longer optical path and lower transmittance"
	)
	var exact_top := _adapter.present_observation(
		20000.0, Vector3.UP, Vector3.UP, Vector3.UP, 1
	)
	_check(
		exact_top.accepted and bool(exact_top.observation.vacuum)
		and is_zero_approx(exact_top.observation.zenith_path_distance_m)
		and is_zero_approx(exact_top.observation.horizon_path_distance_m)
		and _renderer_values(_material) == baseline,
		"exact atmosphere top is vacuum and restores authored baseline exactly"
	)
	var above_top := _adapter.present_observation(
		25000.0, Vector3.UP, Vector3.UP, Vector3.UP, 1
	)
	_check(
		above_top.accepted and bool(above_top.observation.vacuum)
		and _renderer_values(_material) == baseline,
		"finite above-top observations remain exact baseline vacuum"
	)
	var below_top := _adapter.present_observation(
		19999.0, Vector3.UP, Vector3.UP, Vector3.UP, 1
	)
	_check(
		below_top.accepted and not bool(below_top.observation.vacuum)
		and below_top.observation.zenith_path_distance_m > 0.0
		and below_top.observation.horizon_path_distance_m > 0.0
		and _renderer_values(_material) != baseline,
		"representable below-top observation remains non-vacuum and non-baseline"
	)
	var below_reference := _adapter.present_observation(
		-100.0, Vector3.UP, Vector3.UP, Vector3.UP, 1
	)
	_check(
		below_reference.accepted
		and bool(below_reference.observation.zenith_sample.below_reference_altitude)
		and is_equal_approx(
			float(below_reference.observation.zenith_path_distance_m), 20000.0
		)
		and not bool(below_reference.observation.vacuum),
		"below-reference altitude retains the sampler density clamp and bounded shell path"
	)


func _test_sun_view_mapping_and_cadence() -> void:
	var toward := _adapter.present_observation(
		0.0, Vector3.UP, Vector3.UP, Vector3.UP, 1
	)
	var toward_tint := toward.observation.scattering_tint as Color
	var away := _adapter.present_observation(
		0.0, Vector3.DOWN, Vector3.UP, Vector3.UP, 1
	)
	var away_tint := away.observation.scattering_tint as Color
	_check(
		is_equal_approx(float(toward.observation.view_sun_alignment), 1.0)
		and is_equal_approx(float(toward.observation.sun_elevation), 1.0)
		and toward.observation.normalized_mie_phase
		> away.observation.normalized_mie_phase
		and toward_tint != away_tint,
		"caller sun/view alignment deterministically modulates bounded Mie tint"
	)
	var below_horizon_sun := _adapter.present_observation(
		0.0, Vector3.UP, Vector3.UP, Vector3.DOWN, 1
	)
	_check(
		below_horizon_sun.accepted
		and is_equal_approx(float(below_horizon_sun.observation.sun_elevation), -1.0)
		and below_horizon_sun.observation.scattering_tint
		== _expected_scattering_tint(_adapter.get_profile_snapshot(), 0.0),
		"sun below the local horizon contributes zero Mie weight without clock policy"
	)
	var before_duplicate := _adapter.get_state_snapshot()
	var event_count := _events.size()
	var cadence_30 := _adapter.present_observation(
		0.0, Vector3.UP, Vector3.UP, Vector3.DOWN, 1
	)
	var cadence_60 := _adapter.present_observation(
		0.0, Vector3.UP, Vector3.UP, Vector3.DOWN, 1
	)
	var cadence_120 := _adapter.present_observation(
		0.0, Vector3.UP, Vector3.UP, Vector3.DOWN, 1
	)
	_check(
		cadence_30.reason == &"unchanged" and cadence_60.reason == &"unchanged"
		and cadence_120.reason == &"unchanged"
		and _adapter.get_state_snapshot() == before_duplicate
		and _events.size() == event_count,
		"30/60/120-equivalent repeated calls are timestep-free and signal-free"
	)


func _test_invalid_observations_are_atomic() -> void:
	var before := _adapter.get_state_snapshot()
	var renderer_before := _renderer_values(_material)
	var event_count := _events.size()
	var rejected := [
		_adapter.present_observation(NAN, Vector3.UP, Vector3.UP, Vector3.UP, 1),
		_adapter.present_observation(-120000.01, Vector3.UP, Vector3.UP, Vector3.UP, 1),
		_adapter.present_observation(INF, Vector3.UP, Vector3.UP, Vector3.UP, 1),
		_adapter.present_observation(0.0, Vector3.ZERO, Vector3.UP, Vector3.UP, 1),
		_adapter.present_observation(0.0, Vector3(0, 2, 0), Vector3.UP, Vector3.UP, 1),
		_adapter.present_observation(0.0, Vector3.UP, Vector3.INF, Vector3.UP, 1),
		_adapter.present_observation(0.0, Vector3.UP, Vector3.UP, Vector3.ZERO, 1),
		_adapter.present_observation(0.0, Vector3.UP, Vector3.UP, Vector3.UP, 0),
		_adapter.present_observation(0.0, Vector3.UP, Vector3.UP, Vector3.UP, 1.0),
	]
	var all_rejected := true
	for result: Dictionary in rejected:
		all_rejected = all_rejected and not bool(result.accepted)
	_check(
		all_rejected and rejected[0].reason == &"invalid_altitude"
		and rejected[3].reason == &"invalid_view_direction"
		and rejected[5].reason == &"invalid_surface_up_direction"
		and rejected[6].reason == &"invalid_sun_direction"
		and rejected[7].reason == &"stale_generation",
		"nonfinite/range/direction/stale inputs have exact structured-red reasons"
	)
	_check(
		_adapter.get_state_snapshot() == before
		and _renderer_values(_material) == renderer_before
		and _events.size() == event_count,
		"every rejected observation is atomic and signal-free"
	)


func _test_renderer_drift_and_non_owned_state() -> void:
	var non_owned := {
		"ground_bottom_color": _material.ground_bottom_color,
		"sky_curve": _material.sky_curve,
		"background_energy_multiplier": _environment.background_energy_multiplier,
	}
	_material.sky_curve = 0.37
	_environment.background_energy_multiplier = 1.7
	_check(
		bool(_adapter.audit().valid)
		and is_equal_approx(_material.sky_curve, 0.37)
		and is_equal_approx(_environment.background_energy_multiplier, 1.7),
		"non-owned material and Environment fields do not invalidate the component"
	)
	var expected := _adapter.get_renderer_snapshot().expected as Dictionary
	_material.sky_horizon_color = Color(1.0, 0.0, 1.0, 1.0)
	_check(
		not bool(_adapter.audit().valid)
		and ( _adapter.audit().errors as PackedStringArray).has(
			"owned_renderer_state_drift"
		),
		"external owned-colour mutation produces one structured-red audit"
	)
	var last := _adapter.get_state_snapshot().last_observation as Dictionary
	var repaired := _adapter.present_observation(
		last.inputs.altitude_m,
		last.inputs.view_direction,
		last.inputs.surface_up_direction,
		last.inputs.direction_to_sun,
		1
	)
	_check(
		repaired.reason == &"renderer_reapplied"
		and _renderer_values(_material) == expected
		and is_equal_approx(_material.sky_curve, 0.37)
		and is_equal_approx(_environment.background_energy_multiplier, 1.7),
		"duplicate observation repairs owned drift without overwriting non-owned state"
	)
	_material.ground_bottom_color = non_owned.ground_bottom_color


func _test_signal_and_resource_reentry() -> void:
	var before_revision := int(_adapter.get_state_snapshot().revision)
	_material_reentry_results.clear()
	_material_attack_mode = &"reentry_only"
	_material_attack_armed = true
	var result := _adapter.present_observation(
		1000.0, Vector3.UP, Vector3.UP, Vector3.UP, 1
	)
	_check(
		result.accepted and _material_reentry_results.size() == 3
		and _all_reason(_material_reentry_results, &"reentrant_call"),
		"real consolidated Resource.changed callback cannot reenter any mutator"
	)
	_probe_signal_reentry = true
	var signaled := _adapter.present_observation(
		2000.0, Vector3.UP, Vector3.UP, Vector3.UP, 1
	)
	_probe_signal_reentry = false
	_check(
		signaled.accepted and _signal_reentry_results.size() == 3
		and _all_reason(_signal_reentry_results, &"reentrant_call")
		and int(_adapter.get_state_snapshot().revision) == before_revision + 2,
		"post-commit signal observers see committed revision and cannot reenter"
	)

	var original_sky := _environment.sky
	var previous_state := _adapter.get_state_snapshot()
	var previous_values := _renderer_values(_material)
	var previous_events := _events.size()
	_material_reentry_results.clear()
	_material_attack_mode = &"replace_sky"
	_material_attack_armed = true
	var replaced_target := _adapter.present_observation(
		3000.0, Vector3.UP, Vector3.UP, Vector3.UP, 1
	)
	var replaced_state := _adapter.get_state_snapshot()
	_check(
		not bool(replaced_target.accepted)
		and replaced_target.reason == &"target_chain_changed_during_apply"
		and int(replaced_state.revision) == int(previous_state.revision)
		and int(replaced_state.presented_observation_count)
		== int(previous_state.presented_observation_count)
		and replaced_state.last_observation == previous_state.last_observation
		and _renderer_values(_material) == previous_values
		and _events.size() == previous_events
		and _all_reason(_material_reentry_results, &"reentrant_call"),
		"changed callback target replacement rolls back with no commit, count, or signal"
	)
	_environment.sky = original_sky
	_check(
		bool(_adapter.audit().valid),
		"restoring the attacked target chain exposes the retained coherent state"
	)

	previous_state = _adapter.get_state_snapshot()
	previous_values = _renderer_values(_material)
	previous_events = _events.size()
	_material_reentry_results.clear()
	_material_attack_mode = &"overwrite_top"
	_material_attack_armed = true
	var overwritten_property := _adapter.present_observation(
		4000.0, Vector3.UP, Vector3.UP, Vector3.UP, 1
	)
	_check(
		not bool(overwritten_property.accepted)
		and overwritten_property.reason == &"renderer_state_changed_during_apply"
		and _adapter.get_state_snapshot() == previous_state
		and _renderer_values(_material) == previous_values
		and _events.size() == previous_events
		and _all_reason(_material_reentry_results, &"reentrant_call"),
		"changed callback property overwrite rolls back the full transaction signal-free"
	)


func _test_detach_reentry() -> void:
	var state := _adapter.get_state_snapshot()
	var expected := _adapter.get_renderer_snapshot().expected as Dictionary
	var baseline := _adapter.get_renderer_snapshot().baseline as Dictionary
	var events := _events.size()
	root.remove_child(_adapter)
	_check(
		_renderer_values(_material) == baseline
		and not bool(_adapter.get_state_snapshot().inside_tree)
		and bool(_adapter.get_renderer_snapshot().baseline_applied_while_detached),
		"whole-component detach restores exact caller-authored baseline"
	)
	var detached_before := _adapter.get_state_snapshot()
	var detached_events := _events.size()
	var detached := _adapter.present_observation(
		4500.0, Vector3.FORWARD, Vector3.UP, Vector3.RIGHT, 1
	)
	_check(
		not detached.accepted and detached.reason == &"presentation_detached"
		and _adapter.get_state_snapshot() == detached_before
		and _events.size() == detached_events
		and _renderer_values(_material) == baseline,
		"detached sky observation rejects atomically without retaining deferred renderer intent"
	)
	var detached_reset := _adapter.reset_for_reuse(int(detached_before.generation))
	_check(
		not detached_reset.accepted and detached_reset.reason == &"presentation_detached"
		and _adapter.get_state_snapshot() == detached_before
		and _events.size() == detached_events
		and _renderer_values(_material) == baseline,
		"detached sky reset rejects atomically without tombstoning the live caller"
	)
	root.add_child(_adapter)
	var reentry_values := _renderer_values(_material)
	var fresh := _adapter.present_observation(
		4500.0, Vector3.FORWARD, Vector3.UP, Vector3.RIGHT, 1
	)
	_check(
		reentry_values == expected
		and fresh.accepted
		and _renderer_values(_material) == _adapter.get_renderer_snapshot().expected
		and _adapter.get_generation() == int(state.generation)
		and int(_adapter.get_state_snapshot().revision) == int(state.revision) + 1
		and _events.size() == events + 1 and bool(_adapter.audit().valid),
		"re-entry restores last live sky values before a fresh observation commits"
	)
	var reentered_generation := _adapter.get_generation()
	var reentered_reset := _adapter.reset_for_reuse(reentered_generation)
	_check(
		reentered_reset.accepted and reentered_reset.reason == &"reset"
		and _adapter.get_generation() == reentered_generation + 1
		and not bool(_adapter.get_state_snapshot().has_presented_observation)
		and _renderer_values(_material) == baseline,
		"re-added sky adapter accepts a fresh reuse reset"
	)
	await process_frame


func _test_queued_adapter_rejects_atomically() -> void:
	var fixture := _make_fixture()
	var adapter := fixture.adapter as PlanetarySkyPresentation
	var environment := fixture.environment as Environment
	var material := fixture.material as ProceduralSkyMaterial
	var events: Array[Dictionary] = []
	_check(
		adapter.configure(fixture.profile as PlanetaryAtmosphereProfile, environment).accepted
		and adapter.present_observation(
			4000.0, Vector3.FORWARD, Vector3.UP, Vector3.RIGHT, 1
		).accepted,
		"queued fixture has one live sky presentation before deletion"
	)
	adapter.presentation_committed.connect(func(_reason: StringName, _snapshot: Dictionary) -> void:
		events.append({})
	)
	adapter.queue_free()
	var before := adapter.get_state_snapshot()
	var values_before := _renderer_values(material)
	var queued := adapter.present_observation(
		4500.0, Vector3.FORWARD, Vector3.UP, Vector3.RIGHT, 1
	)
	_check(
		adapter.is_queued_for_deletion()
		and not queued.accepted and queued.reason == &"presentation_detached"
		and adapter.get_state_snapshot() == before and events.is_empty()
		and _renderer_values(material) == values_before,
		"queued sky adapter rejects observation atomically before renderer or retained intent drift"
	)
	var queued_reset := adapter.reset_for_reuse(int(before.generation))
	_check(
		adapter.is_queued_for_deletion()
		and not queued_reset.accepted and queued_reset.reason == &"presentation_detached"
		and adapter.get_state_snapshot() == before and events.is_empty()
		and _renderer_values(material) == values_before,
		"queued sky adapter rejects reset atomically before caller tombstone or signal drift"
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
		and _renderer_values(_material) == baseline,
		"reset tombstones old callers and restores the exact baseline"
	)
	_check(
		_adapter.present_observation(
			0.0, Vector3.UP, Vector3.UP, Vector3.UP, old_generation
		).reason == &"stale_generation",
		"pre-reset generation cannot mutate the reused component"
	)
	var report := _adapter.audit()
	_check(
		_exact_authority(report.authority, COMMON_AUTHORITY_KEYS, &"renderer")
		and _exact_authority(report.adjacent_authority, ADJACENT_AUTHORITY_KEYS)
		and _exact_capabilities(report.capabilities)
		and report.owned_renderer_properties == EXPECTED_RENDERER_PROPERTIES,
		"audit freezes exact renderer-only authority, capability, and ownership rosters"
	)
	_check(
		report.performance.runtime_child_node_count == 0
		and report.performance.owned_environment_resource_count == 0
		and report.performance.owned_sky_resource_count == 0
		and report.performance.owned_sky_material_resource_count == 0
		and report.performance.renderer_resource_allocations_after_configuration == 0
		and report.performance.process_loop_count == 0
		and not _contains_live_capability(report),
		"detached audit reports zero allocations/process and exposes no live capability"
	)
	var report_attack := report
	report_attack.state.profile.geometry.planet_radius_m = -1.0
	report_attack.authority.renderer = false
	var snapshot_attack := _adapter.get_renderer_snapshot()
	snapshot_attack.baseline.sky_top_color = Color.RED
	_check(
		_adapter.audit().state.profile.geometry.planet_radius_m == 120000.0
		and bool(_adapter.audit().authority.renderer)
		and _adapter.get_renderer_snapshot().baseline.sky_top_color != Color.RED,
		"nested audit and renderer snapshots are deeply detached"
	)
	var child := Node.new()
	_adapter.add_child(child)
	_check(
		not bool(_adapter.audit().valid)
		and (_adapter.audit().errors as PackedStringArray).has(
			"passive_adapter_gained_child_nodes"
		),
		"unexpected child authority is a structured-red audit"
	)
	_adapter.remove_child(child)
	child.free()
	_adapter.set("_generation", PresentationScript.MAX_SAFE_GENERATION)
	var before := _adapter.get_state_snapshot()
	var exhausted := _adapter.reset_for_reuse(PresentationScript.MAX_SAFE_GENERATION)
	_check(
		exhausted.reason == &"generation_exhausted"
		and _adapter.get_state_snapshot() == before,
		"safe-integer generation exhaustion rejects atomically without wrap"
	)
	_adapter.set("_generation", old_generation + 1)


func _test_target_identity_replacement() -> void:
	var original_sky := _environment.sky
	var replacement_sky := Sky.new()
	replacement_sky.sky_material = ProceduralSkyMaterial.new()
	_environment.sky = replacement_sky
	_check(
		not bool(_adapter.audit().valid)
		and (_adapter.audit().errors as PackedStringArray).has("sky_identity_drift")
		and _adapter.present_observation(
			0.0, Vector3.UP, Vector3.UP, Vector3.UP, _adapter.get_generation()
		).reason == &"renderer_target_unavailable",
		"replacement Sky identity fails closed instead of mutating another target"
	)
	_environment.sky = original_sky
	var original_material := original_sky.sky_material
	original_sky.sky_material = ProceduralSkyMaterial.new()
	_check(
		not bool(_adapter.audit().valid)
		and (_adapter.audit().errors as PackedStringArray).has(
			"sky_material_identity_drift"
		),
		"replacement material identity is independently structured red"
	)
	original_sky.sky_material = original_material
	_check(
		bool(_adapter.audit().valid),
		"restoring the exact weak target chain restores a green audit"
	)


func _test_expired_target_fails_closed() -> void:
	var fixture := _make_fixture()
	var adapter := fixture.adapter as PlanetarySkyPresentation
	var environment := fixture.environment as Environment
	var configured := adapter.configure(fixture.profile, environment)
	fixture.clear()
	environment = null
	await process_frame
	_check(
		configured.accepted and not bool(adapter.audit().valid)
		and not bool(adapter.get_renderer_snapshot().target_available)
		and adapter.present_observation(
			0.0, Vector3.UP, Vector3.UP, Vector3.UP, 1
		).reason == &"renderer_target_unavailable",
		"freed target graph invalidates weak identities and sampling fails closed"
	)
	adapter.free()


func _on_presentation_committed(reason: StringName, snapshot: Dictionary) -> void:
	_events.append({"reason": reason, "snapshot": snapshot.duplicate(true)})
	if int(snapshot.revision) != int(_adapter.get_state_snapshot().revision) \
			or snapshot.renderer.expected != snapshot.renderer.actual:
		_failures.append("presentation signal observed uncommitted state")
	if _probe_signal_reentry:
		_signal_reentry_results = [
			_adapter.configure(_profile, _environment),
			_adapter.present_observation(
				0.0, Vector3.UP, Vector3.UP, Vector3.UP, _adapter.get_generation()
			),
			_adapter.reset_for_reuse(_adapter.get_generation()),
		]


func _on_material_changed() -> void:
	if not _material_attack_armed:
		return
	_material_attack_armed = false
	_material_reentry_results = [
		_adapter.configure(_profile, _environment),
		_adapter.present_observation(
			0.0, Vector3.UP, Vector3.UP, Vector3.UP, _adapter.get_generation()
		),
		_adapter.reset_for_reuse(_adapter.get_generation()),
	]
	if _material_attack_mode == &"replace_sky":
		var replacement := Sky.new()
		replacement.sky_material = ProceduralSkyMaterial.new()
		_environment.sky = replacement
	elif _material_attack_mode == &"overwrite_top":
		_material.sky_top_color = Color(1.0, 0.0, 1.0, 1.0)


func _make_fixture() -> Dictionary:
	var profile := ProfileScript.new() as PlanetaryAtmosphereProfile
	var target := _make_target()
	var adapter := PresentationScript.new() as PlanetarySkyPresentation
	adapter.name = "PlanetarySkyPresentation"
	root.add_child(adapter)
	return {
		"profile": profile,
		"environment": target.environment,
		"sky": target.sky,
		"material": target.material,
		"adapter": adapter,
	}


func _make_target() -> Dictionary:
	var material := ProceduralSkyMaterial.new()
	material.sky_top_color = Color(0.025, 0.045, 0.08, 1.0)
	material.sky_horizon_color = Color(0.12, 0.18, 0.24, 1.0)
	material.ground_bottom_color = Color(0.018, 0.022, 0.03, 1.0)
	material.ground_horizon_color = Color(0.08, 0.11, 0.15, 1.0)
	material.sky_curve = 0.13
	var sky := Sky.new()
	sky.sky_material = material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.background_energy_multiplier = 0.9
	return {"environment": environment, "sky": sky, "material": material}


func _renderer_values(material: ProceduralSkyMaterial) -> Dictionary:
	return {
		"sky_top_color": material.sky_top_color,
		"sky_horizon_color": material.sky_horizon_color,
		"ground_horizon_color": material.ground_horizon_color,
	}


func _expected_atmospheric_color(
		baseline: Color,
		transmittance: Color,
		tint: Color
	) -> Color:
	return Color(
		clampf(baseline.r * transmittance.r + tint.r * (1.0 - transmittance.r), 0.0, 1.0),
		clampf(baseline.g * transmittance.g + tint.g * (1.0 - transmittance.g), 0.0, 1.0),
		clampf(baseline.b * transmittance.b + tint.b * (1.0 - transmittance.b), 0.0, 1.0),
		baseline.a
	)


func _expected_scattering_tint(profile_snapshot: Dictionary, mie_weight: float) -> Color:
	var optics := profile_snapshot.optics as Dictionary
	var rayleigh := optics.rayleigh_scattering_per_m as Color
	var mie := optics.mie_scattering_per_m as Color
	var combined := Vector3(
		rayleigh.r + mie.r * mie_weight,
		rayleigh.g + mie.g * mie_weight,
		rayleigh.b + mie.b * mie_weight
	)
	var normalized := combined / maxf(combined.x, maxf(combined.y, combined.z))
	return Color(
		0.18 + normalized.x * 0.62,
		0.18 + normalized.y * 0.62,
		0.18 + normalized.z * 0.62,
		1.0
	)


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
	return bool(capabilities.procedural_sky_color_renderer_implemented) \
		and bool(capabilities.caller_driven_observations_only) \
		and bool(capabilities.transactional_renderer_apply) \
		and bool(capabilities.consolidated_resource_changed_notification) \
		and bool(capabilities.tree_exit_restores_baseline) \
		and bool(capabilities.tree_reentry_reapplies_current_generation) \
		and not bool(capabilities.fog_renderer_implemented) \
		and not bool(capabilities.cloud_renderer_implemented) \
		and not bool(capabilities.sun_renderer_implemented) \
		and not bool(capabilities.shell_renderer_implemented) \
		and not bool(capabilities.ambient_reflection_policy_implemented)


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
	print("PLANETARY_SKY_PRESENTATION_ASSERTIONS: ", _assertions)
	if _assertions != EXPECTED_ASSERTIONS:
		_failures.append(
			"assertion count drifted: expected %d got %d"
			% [EXPECTED_ASSERTIONS, _assertions]
		)
	if _failures.is_empty():
		print("PLANETARY_SKY_PRESENTATION_TEST_OK")
		quit(0)
	else:
		print("PLANETARY_SKY_PRESENTATION_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
