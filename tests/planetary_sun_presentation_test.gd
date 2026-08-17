extends SceneTree

const WorldScript := preload(
	"res://scripts/world/definitions/planetary_world_definition.gd"
)
const ProfileScript := preload(
	"res://scripts/world/definitions/planetary_atmosphere_profile.gd"
)
const PresentationScript := preload(
	"res://scripts/world/planetary_sun_presentation.gd"
)
const BODY_RADIUS_M := 120_000.0
const ATMOSPHERE_TOP_M := 20_000.0
const BASELINE_ENERGY := 3.5
const BASELINE_COLOR := Color(0.82, 0.64, 0.46, 1.0)
const EXPECTED_RENDERER_PROPERTIES := ["light_color", "light_energy"]
const EXPECTED_EVIDENCE := {
	"content_class": &"NEW",
	"status": &"modern_interpretation",
	"source_bounded": false,
	"confidence": &"none",
}
const COMMON_AUTHORITY_KEYS := [
	"renderer", "gameplay", "streaming", "save", "network", "physics",
	"world_generation", "terrain_generation", "collision_generation",
	"origin_shift", "weather_clock", "audio",
]
const ADJACENT_AUTHORITY_KEYS := [
	"directional_light_node_ownership", "directional_light_creation",
	"light_direction_or_transform", "sun_ephemeris",
	"time_or_day_night_clock", "absolute_energy_or_lux",
	"calibrated_colorimetry", "temperature", "angular_distance", "shadows",
	"occlusion_query", "terrain_horizon", "cloud_or_weather",
	"environment_or_sky", "camera", "origin_or_rebase", "physics",
	"gameplay", "streaming", "save", "network",
]
const CAPABILITY_KEYS := [
	"baseline_relative_light_energy_implemented",
	"baseline_relative_light_color_hint_implemented",
	"transactional_renderer_apply", "caller_driven_observations_only",
	"tree_exit_restores_baseline",
	"tree_reentry_reapplies_current_generation",
	"target_tree_exit_restores_baseline",
	"target_tree_reentry_reapplies_current_generation",
	"direction_or_orientation_implemented", "absolute_energy_or_lux_implemented",
	"calibrated_colorimetry_implemented", "shadow_or_occlusion_implemented",
	"clock_or_ephemeris_implemented", "environment_or_sky_implemented",
]
const EXPECTED_ASSERTIONS := 43

var _assertions := 0
var _failures := PackedStringArray()
var _events: Array[Dictionary] = []
var _adapter: PlanetarySunPresentation
var _host: Node3D
var _light: DirectionalLight3D
var _world: PlanetaryWorldDefinition
var _profile: PlanetaryAtmosphereProfile
var _signal_reentry_armed := false
var _signal_reentry_results: Array[Dictionary] = []
var _signal_observed_committed_state := false


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await _test_configuration_rejections()
	_make_main_fixture()
	_test_configuration_and_source_detachment()
	_test_exact_baseline_relative_mapping()
	_test_strict_observations_and_generation()
	_test_renderer_drift_and_forbidden_properties()
	_test_signal_reentry_and_detached_payload()
	await _test_adapter_and_target_lifecycle()
	_test_reset_and_generation_exhaustion()
	_test_detached_audit_and_authority()
	await _test_expired_target_fails_closed()
	if is_instance_valid(_host):
		_host.queue_free()
	await process_frame
	_finish()


func _test_configuration_rejections() -> void:
	var host := Node3D.new()
	root.add_child(host)
	var adapter := PresentationScript.new() as PlanetarySunPresentation
	var light := _make_light()
	host.add_child(light)
	host.add_child(adapter)
	var state := adapter.get_state_snapshot()
	_check(
		adapter.configure(null, null, light, BASELINE_ENERGY, BASELINE_COLOR).reason
		== &"missing_world_definition"
		and adapter.configure(_make_world(false), null, null, 1.0, Color.WHITE).reason
		== &"missing_directional_light"
		and adapter.get_state_snapshot() == state,
		"missing definition/target reject without partial configuration"
	)
	_check(
		adapter.configure(_make_world(false), null, light, NAN, BASELINE_COLOR).reason
		== &"invalid_authored_energy"
		and adapter.configure(
			_make_world(false), null, light,
			PresentationScript.MAX_AUTHORED_LIGHT_ENERGY + 0.001,
			BASELINE_COLOR
		).reason == &"invalid_authored_energy"
		and adapter.configure(
			_make_world(false), null, light, BASELINE_ENERGY,
			Color(INF, 1.0, 1.0, 1.0)
		).reason == &"invalid_authored_color",
		"nonfinite and above-ceiling authored baselines reject exactly"
	)
	_check(
		adapter.configure(
			_make_world(false), null, light, BASELINE_ENERGY + 1.0,
			BASELINE_COLOR
		).reason == &"renderer_baseline_mismatch",
		"explicit authored baseline must exactly match the target"
	)
	var invalid_world := _make_world(false)
	invalid_world.body_radius_metres = NAN
	_check(
		adapter.configure(
			invalid_world, null, light, BASELINE_ENERGY, BASELINE_COLOR
		).reason == &"policy_configuration_failed"
		and adapter.configure(
			_make_world(true), null, light, BASELINE_ENERGY, BASELINE_COLOR
		).policy_reason == &"missing_atmosphere_profile"
		and adapter.configure(
			_make_world(false), ProfileScript.new(), light,
			BASELINE_ENERGY, BASELINE_COLOR
		).policy_reason == &"unexpected_atmosphere_profile",
		"invalid atmospheric/airless policy joins retain typed upstream reasons"
	)
	_check(
		adapter.reset_for_reuse(0).reason == &"not_configured"
		and not bool(adapter.audit().valid)
		and (adapter.audit().errors as PackedStringArray).has(
			"presentation_not_configured"
		),
		"premature lifecycle mutation and unconfigured audit fail closed"
	)
	host.queue_free()
	await process_frame


func _make_main_fixture() -> void:
	_host = Node3D.new()
	root.add_child(_host)
	_light = _make_light()
	_adapter = PresentationScript.new() as PlanetarySunPresentation
	_world = _make_world(true)
	_profile = ProfileScript.new() as PlanetaryAtmosphereProfile
	_host.add_child(_light)
	_host.add_child(_adapter)


func _test_configuration_and_source_detachment() -> void:
	var result := _adapter.configure(
		_world, _profile, _light, BASELINE_ENERGY, BASELINE_COLOR
	)
	_adapter.presentation_committed.connect(_on_presentation_committed)
	var state := _adapter.get_state_snapshot()
	_check(
		result.accepted and result.reason == &"configured"
		and int(result.generation) == 1 and int(result.revision) == 1
		and state.world_id == &"sun_presentation_world"
		and state.equation_version == PresentationScript.EQUATION_VERSION,
		"valid atmospheric composition commits generation one exactly"
	)
	_check(
		state.renderer.baseline == _renderer_values(_light)
		and state.renderer.expected == state.renderer.baseline
		and state.renderer.owned_properties == EXPECTED_RENDERER_PROPERTIES
		and bool(state.renderer.current_values_applied),
		"configuration freezes the exact explicit two-property baseline"
	)
	_check(
		bool(_adapter.audit().valid) and _adapter.get_child_count() == 0
		and not _adapter.is_processing() and not _adapter.is_physics_processing(),
		"configured adapter is valid, childless, and caller-cadence only"
	)
	_check(
		_adapter.configure(
			_make_world(false), null, _light, BASELINE_ENERGY, BASELINE_COLOR
		).reason == &"already_configured"
		and _adapter.get_state_snapshot() == state,
		"configuration becomes immutable after its first successful commit"
	)
	_world.world_id = &"caller_mutated"
	_world.body_radius_metres = 900_000.0
	_profile.profile_id = &"caller_mutated"
	_profile.rayleigh_scattering_per_m = Color(1.0, 0.0, 0.0, 1.0)
	var frozen := _adapter.get_policy_snapshot()
	_check(
		frozen.world_id == &"sun_presentation_world"
		and is_equal_approx(float(frozen.body_radius_m), BODY_RADIUS_M)
		and frozen.atmosphere_profile_id == &"temperate_game_scale"
		and bool(_adapter.audit().valid),
		"source Resource mutation cannot retune the private detached policy"
	)


func _test_exact_baseline_relative_mapping() -> void:
	var day := _adapter.present_observation(_observation(Vector3.UP), 1)
	_check(
		bool(day.get("accepted", false)),
		"atmospheric daylight evaluates before mapping (reason=%s, policy=%s)" % [
			day.get("reason", &"missing"), day.get("policy_reason", &"none")
		]
	)
	if not bool(day.get("accepted", false)):
		return
	var hint := day.evaluation.directional_light_hint as Dictionary
	var expected := _mapped_values(hint)
	_check(
		day.accepted and day.reason == &"observation_presented"
		and day.renderer_values == expected
		and _renderer_values(_light) == expected,
		"atmospheric daylight baseline-composes exact policy color and energy hints"
	)
	_check(
		float(expected.light_energy) < BASELINE_ENERGY
		and expected.light_color != BASELINE_COLOR
		and float(expected.light_energy) >= 0.0,
		"atmospheric attenuation remains normalized and bounded by authored values"
	)
	var malformed := day.evaluation.duplicate(true) as Dictionary
	malformed.directional_light_hint.erase("direct_transmittance_unitless")
	var extra := day.evaluation.duplicate(true) as Dictionary
	extra.directional_light_hint.unexpected = 0.0
	_check(
		not _adapter._policy_evaluation_is_valid(malformed)
		and not _adapter._policy_evaluation_is_valid(extra),
		"directional policy hint validation freezes the exact six-key roster"
	)
	var horizon := _adapter.present_observation(_observation(Vector3.RIGHT), 1)
	_check(
		horizon.accepted and horizon.renderer_values.light_energy == 0.0
		and horizon.renderer_values.light_color == BASELINE_COLOR,
		"exact spherical horizon keeps color metadata and applies zero energy"
	)
	var night := _adapter.present_observation(_observation(Vector3.DOWN), 1)
	_check(
		night.accepted and night.renderer_values.light_energy == 0.0
		and night.renderer_values.light_color == BASELINE_COLOR,
		"occulted full night is exact zero energy without inventing a color"
	)
	var vacuum := _adapter.present_observation(
		_observation(Vector3.UP, BODY_RADIUS_M + ATMOSPHERE_TOP_M), 1
	)
	_check(
		vacuum.accepted and vacuum.renderer_values == {
			"light_color": BASELINE_COLOR,
			"light_energy": BASELINE_ENERGY,
		},
		"exact atmosphere-top vacuum daylight restores the authored baseline"
	)
	var airless: Dictionary = _make_fixture(false)
	var airless_adapter := airless.adapter as PlanetarySunPresentation
	var airless_result: Dictionary = airless_adapter.present_observation(
		_observation(Vector3.UP), 1
	)
	_check(
		airless_result.accepted
		and airless_result.renderer_values.light_color == BASELINE_COLOR
		and airless_result.renderer_values.light_energy == BASELINE_ENERGY,
		"airless direct daylight is the exact authored color and energy"
	)
	(airless.host as Node).queue_free()


func _test_strict_observations_and_generation() -> void:
	var before := _adapter.get_state_snapshot()
	var renderer_before := _renderer_values(_light)
	_check(
		_adapter.present_observation(_observation(Vector3.UP), 1.0).reason
		== &"stale_generation"
		and _adapter.present_observation(_observation(Vector3.UP), 0).reason
		== &"stale_generation",
		"generation ingress accepts only the exact current safe integer"
	)
	_check(
		_adapter.present_observation({}, 1).reason
		== &"policy_evaluation_rejected"
		and _adapter.present_observation({
			"body_local_observer_m": Vector3.UP * BODY_RADIUS_M,
			"normalized_body_to_sun": Vector3(INF, 0.0, 0.0),
		}, 1).policy_reason == &"invalid_sun_direction",
		"strict policy observation schema and finite unit direction remain intact"
	)
	_check(
		_adapter.get_state_snapshot() == before
		and _renderer_values(_light) == renderer_before,
		"rejected generation and observation inputs are atomic"
	)
	var repeated := _adapter.present_observation(
		_observation(Vector3.UP, BODY_RADIUS_M + ATMOSPHERE_TOP_M), 1
	)
	_check(
		repeated.accepted and repeated.reason == &"unchanged"
		and int(repeated.revision) == int(before.revision),
		"identical observation with exact renderer state is signal-free"
	)


func _test_renderer_drift_and_forbidden_properties() -> void:
	var before_transform := _light.transform
	var before_shadow := _light.shadow_enabled
	var before_cull_mask := _light.light_cull_mask
	var before_indirect := _light.light_indirect_energy
	var observation := _observation(Vector3.UP)
	var presented := _adapter.present_observation(observation, 1)
	var expected := presented.renderer_values as Dictionary
	_light.light_energy = 0.125
	_light.light_color = Color(0.1, 0.2, 0.3, 1.0)
	_check(
		not bool(_adapter.audit().valid)
		and (adapter_errors() as PackedStringArray).has(
			"owned_renderer_state_drift"
		),
		"external owned-property drift is an explicit red audit"
	)
	var repaired := _adapter.present_observation(observation, 1)
	_check(
		repaired.accepted and repaired.reason == &"renderer_reapplied"
		and _renderer_values(_light) == expected and bool(_adapter.audit().valid),
		"duplicate observation repairs both owned fields transactionally"
	)
	_light.shadow_enabled = not before_shadow
	_light.light_cull_mask = 0x0000FFFF
	_light.light_indirect_energy = 0.37
	var caller_shadow := _light.shadow_enabled
	var caller_cull_mask := _light.light_cull_mask
	var caller_indirect := _light.light_indirect_energy
	var unchanged := _adapter.present_observation(observation, 1)
	_check(
		unchanged.reason == &"unchanged" and _light.transform == before_transform
		and _light.shadow_enabled == caller_shadow
		and _light.light_cull_mask == caller_cull_mask
		and _light.light_indirect_energy == caller_indirect,
		"direction, shadows, cull mask, and indirect energy remain caller-owned"
	)
	_light.shadow_enabled = before_shadow
	_light.light_cull_mask = before_cull_mask
	_light.light_indirect_energy = before_indirect


func _test_signal_reentry_and_detached_payload() -> void:
	_signal_reentry_armed = true
	var before_events := _events.size()
	var result := _adapter.present_observation(_observation(Vector3.DOWN), 1)
	_check(
		result.accepted and _events.size() == before_events + 1
		and _signal_observed_committed_state,
		"presentation signal observes the fully committed renderer and state"
	)
	_check(
		_signal_reentry_results.size() == 3
		and _all_results_have_reason(
			_signal_reentry_results, &"reentrant_call"
		),
		"signal observers cannot reenter configure, present, or reset"
	)
	var state := _adapter.get_state_snapshot()
	_events[-1].snapshot.renderer.baseline.light_energy = 999.0
	_events[-1].snapshot.evidence.content_class = &"mutated"
	_check(
		_adapter.get_state_snapshot() == state
		and _adapter.get_state_snapshot().evidence == EXPECTED_EVIDENCE,
		"nested presentation payload mutation cannot alter retained state"
	)


func _test_adapter_and_target_lifecycle() -> void:
	var day := _adapter.present_observation(_observation(Vector3.UP), 1)
	var day_values := day.renderer_values as Dictionary
	_host.remove_child(_adapter)
	await process_frame
	_check(
		_renderer_values(_light) == _adapter.get_renderer_snapshot().baseline
		and bool(_adapter.get_renderer_snapshot().baseline_applied_while_inactive),
		"adapter tree exit restores the exact authored baseline"
	)
	var detached_night := _adapter.present_observation(
		_observation(Vector3.DOWN), 1
	)
	_check(
		detached_night.accepted and detached_night.renderer_values.light_energy == 0.0
		and _renderer_values(_light) == _adapter.get_renderer_snapshot().baseline,
		"detached presentation retains a candidate without leaking renderer state"
	)
	_host.add_child(_adapter)
	await process_frame
	_check(
		_light.light_energy == 0.0
		and bool(_adapter.get_renderer_snapshot().current_values_applied),
		"adapter re-entry reapplies the retained generation without a new commit"
	)
	_host.remove_child(_light)
	await process_frame
	_check(
		_renderer_values(_light) == _adapter.get_renderer_snapshot().baseline
		and bool(_adapter.get_renderer_snapshot().baseline_applied_while_inactive),
		"independent target tree exit restores the authored baseline"
	)
	var outside_day := _adapter.present_observation(_observation(Vector3.UP), 1)
	_check(
		outside_day.accepted and outside_day.renderer_values == day_values
		and _renderer_values(_light) == _adapter.get_renderer_snapshot().baseline,
		"target-outside-tree evaluation commits state but keeps baseline applied"
	)
	_host.add_child(_light)
	await process_frame
	_check(
		_renderer_values(_light) == day_values and bool(_adapter.audit().valid),
		"target re-entry reapplies the current generation exactly once"
	)


func _test_reset_and_generation_exhaustion() -> void:
	var before := _adapter.get_state_snapshot()
	_check(
		_adapter.reset_for_reuse(0).reason == &"stale_generation"
		and _adapter.reset_for_reuse(1.0).reason == &"stale_generation"
		and _adapter.get_state_snapshot() == before,
		"stale and float reset generations reject atomically"
	)
	var reset := _adapter.reset_for_reuse(1)
	_check(
		reset.accepted and reset.reason == &"reset"
		and int(reset.generation) == 2
		and _renderer_values(_light) == _adapter.get_renderer_snapshot().baseline
		and not bool(_adapter.get_state_snapshot().has_presented_observation),
		"reset restores baseline before advancing and clearing observation state"
	)
	var reset_state := _adapter.get_state_snapshot()
	_adapter._generation = PresentationScript.MAX_SAFE_GENERATION
	var exhausted := _adapter.reset_for_reuse(
		PresentationScript.MAX_SAFE_GENERATION
	)
	_check(
		exhausted.reason == &"generation_exhausted"
		and _renderer_values(_light) == _adapter.get_renderer_snapshot().baseline
		and int(_adapter.get_state_snapshot().revision) == int(reset_state.revision),
		"safe-integer generation exhaustion never wraps or mutates renderer state"
	)
	_adapter._generation = 2


func _test_detached_audit_and_authority() -> void:
	var audit := _adapter.audit()
	var state := _adapter.get_state_snapshot()
	var mutated := audit.duplicate(true)
	mutated.state.renderer.baseline.light_energy = 99.0
	mutated.evidence.content_class = &"mutated"
	mutated.authority.renderer = false
	_check(
		bool(audit.valid) and _adapter.audit() == audit
		and audit.evidence == EXPECTED_EVIDENCE
		and audit.state.evidence == EXPECTED_EVIDENCE,
		"audit, state, evidence, source evidence, and renderer values are detached"
	)
	_check(
		_exact_authority(audit.authority)
		and _exact_false_dictionary(
			audit.adjacent_authority, ADJACENT_AUTHORITY_KEYS
		),
		"common renderer-only and adjacent all-false authority rosters are exact"
	)
	_check(
		_exact_capabilities(audit.capabilities)
		and not bool(audit.limitations.absolute_energy_or_lux_produced)
		and not bool(audit.limitations.calibrated_colorimetry_produced)
		and not bool(audit.limitations.direction_matches_observation_verified),
		"capabilities distinguish normalized property application from physical sun authority"
	)
	_check(
		not _contains_live_object(audit)
		and not _contains_live_object(state)
		and not _contains_live_object(_adapter.get_renderer_snapshot()),
		"all public reports contain detached values and no live renderer authority"
	)


func _test_expired_target_fails_closed() -> void:
	var fixture := _make_fixture(false)
	var adapter := fixture.adapter as PlanetarySunPresentation
	var light := fixture.light as DirectionalLight3D
	var light_ref: WeakRef = weakref(light)
	light.queue_free()
	await process_frame
	_check(
		light_ref.get_ref() == null
		and adapter.present_observation(_observation(Vector3.UP), 1).reason
		== &"directional_light_unavailable"
		and not bool(adapter.audit().valid)
		and (adapter.audit().errors as PackedStringArray).has(
			"directional_light_identity_drift"
		),
		"freed target fails closed without exposing a stale renderer identity"
	)
	(fixture.host as Node).queue_free()


func _make_fixture(atmospheric: bool) -> Dictionary:
	var host := Node3D.new()
	root.add_child(host)
	var light := _make_light()
	var adapter := PresentationScript.new() as PlanetarySunPresentation
	host.add_child(light)
	host.add_child(adapter)
	var configured := adapter.configure(
		_make_world(atmospheric),
		ProfileScript.new() if atmospheric else null,
		light,
		BASELINE_ENERGY,
		BASELINE_COLOR
	)
	if not bool(configured.accepted):
		_failures.append("fixture failed to configure: %s" % configured.reason)
	return {"host": host, "light": light, "adapter": adapter}


func _make_light() -> DirectionalLight3D:
	var light := DirectionalLight3D.new()
	light.light_color = BASELINE_COLOR
	light.light_energy = BASELINE_ENERGY
	light.shadow_enabled = true
	light.light_cull_mask = 0x00FFFFFF
	light.light_indirect_energy = 0.63
	light.light_volumetric_fog_energy = 0.41
	light.directional_shadow_max_distance = 321.0
	light.rotation = Vector3(0.3, -0.7, 0.2)
	return light


func _make_world(atmospheric: bool) -> PlanetaryWorldDefinition:
	var world := WorldScript.new() as PlanetaryWorldDefinition
	world.world_id = &"sun_presentation_world"
	world.display_name = "Sun Presentation World"
	world.sector_id = &"sun_presentation_sector"
	world.content_note = "Invented normalized sun-presentation fixture."
	world.scene_path = "res://scenes/world/planets/sun_presentation_world.tscn"
	world.scene_anchor_id = &"sun_presentation_scene"
	world.scene_anchor = Transform3D.IDENTITY
	world.navigation_anchor_id = &"sun_presentation_navigation"
	world.navigation_anchor = Transform3D(
		Basis.IDENTITY, Vector3.UP * (BODY_RADIUS_M + 1_000.0)
	)
	world.orbital_anchor_id = &"sun_presentation_orbit"
	world.orbital_anchor = Transform3D(
		Basis.IDENTITY, Vector3.UP * (BODY_RADIUS_M + ATMOSPHERE_TOP_M)
	)
	world.surface_anchor_id = &"sun_presentation_surface"
	world.surface_anchor = Transform3D(
		Basis.IDENTITY, Vector3.UP * BODY_RADIUS_M
	)
	world.body_radius_metres = BODY_RADIUS_M
	world.has_atmosphere = atmospheric
	world.atmosphere_definition_id = (
		&"temperate_game_scale" if atmospheric else &""
	)
	world.terrain_definition_id = &"sun_presentation_terrain"
	world.landing_region_ids = PackedStringArray(["sun_presentation_landing"])
	world.evidence_status = WorldScript.EvidenceStatus.MODERN_INTERPRETATION
	world.evidence_notes = "Invented normalized sun-presentation fixture."
	return world


func _observation(
		sun_direction: Vector3,
		observer_radius_m: float = BODY_RADIUS_M
	) -> Dictionary:
	return {
		"body_local_observer_m": Vector3.UP * observer_radius_m,
		"normalized_body_to_sun": sun_direction,
	}


func _mapped_values(hint: Dictionary) -> Dictionary:
	var tint := hint.recommended_color as Color
	return {
		"light_color": Color(
			BASELINE_COLOR.r * tint.r,
			BASELINE_COLOR.g * tint.g,
			BASELINE_COLOR.b * tint.b,
			BASELINE_COLOR.a
		),
		"light_energy": Vector2(BASELINE_ENERGY * float(
			hint.recommended_energy_factor_unitless
		), 0.0).x,
	}


func _renderer_values(light: DirectionalLight3D) -> Dictionary:
	return {
		"light_color": light.light_color,
		"light_energy": light.light_energy,
	}


func adapter_errors() -> PackedStringArray:
	return (_adapter.audit().errors as PackedStringArray).duplicate()


func _all_results_have_reason(
		results: Array[Dictionary],
		reason: StringName
	) -> bool:
	for result: Dictionary in results:
		if result.get("reason", &"") != reason:
			return false
	return true


func _on_presentation_committed(
		reason: StringName,
		snapshot: Dictionary
	) -> void:
	_events.append({"reason": reason, "snapshot": snapshot.duplicate(true)})
	if not _signal_reentry_armed:
		return
	_signal_reentry_armed = false
	_signal_observed_committed_state = (
		snapshot == _adapter.get_state_snapshot()
		and snapshot.renderer.actual == snapshot.renderer.expected
	)
	_signal_reentry_results = [
		_adapter.configure(
			_make_world(false), null, _light, BASELINE_ENERGY, BASELINE_COLOR
		),
		_adapter.present_observation(_observation(Vector3.UP), snapshot.generation),
		_adapter.reset_for_reuse(snapshot.generation),
	]


func _exact_authority(value: Variant) -> bool:
	if value is not Dictionary:
		return false
	var authority := value as Dictionary
	if authority.size() != COMMON_AUTHORITY_KEYS.size():
		return false
	for key: String in COMMON_AUTHORITY_KEYS:
		if not authority.has(key) or authority[key] is not bool:
			return false
		if bool(authority[key]) != (key == "renderer"):
			return false
	return true


func _exact_false_dictionary(value: Variant, keys: Array) -> bool:
	if value is not Dictionary:
		return false
	var dictionary := value as Dictionary
	if dictionary.size() != keys.size():
		return false
	for key: String in keys:
		if not dictionary.has(key) or dictionary[key] is not bool \
				or bool(dictionary[key]):
			return false
	return true


func _exact_capabilities(value: Variant) -> bool:
	if value is not Dictionary:
		return false
	var capabilities := value as Dictionary
	if capabilities.size() != CAPABILITY_KEYS.size():
		return false
	for key: String in CAPABILITY_KEYS:
		if not capabilities.has(key) or capabilities[key] is not bool:
			return false
	return bool(capabilities.baseline_relative_light_energy_implemented) \
		and bool(capabilities.baseline_relative_light_color_hint_implemented) \
		and bool(capabilities.transactional_renderer_apply) \
		and bool(capabilities.caller_driven_observations_only) \
		and bool(capabilities.tree_exit_restores_baseline) \
		and bool(capabilities.tree_reentry_reapplies_current_generation) \
		and bool(capabilities.target_tree_exit_restores_baseline) \
		and bool(capabilities.target_tree_reentry_reapplies_current_generation) \
		and not bool(capabilities.direction_or_orientation_implemented) \
		and not bool(capabilities.absolute_energy_or_lux_implemented) \
		and not bool(capabilities.calibrated_colorimetry_implemented) \
		and not bool(capabilities.shadow_or_occlusion_implemented) \
		and not bool(capabilities.clock_or_ephemeris_implemented) \
		and not bool(capabilities.environment_or_sky_implemented)


func _contains_live_object(value: Variant) -> bool:
	if value is Object or value is WeakRef or value is Callable or value is Signal:
		return true
	if value is Dictionary:
		for key: Variant in (value as Dictionary):
			if _contains_live_object(key) \
					or _contains_live_object((value as Dictionary)[key]):
				return true
	elif value is Array:
		for item: Variant in value as Array:
			if _contains_live_object(item):
				return true
	return false


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	_check(
		_assertions == EXPECTED_ASSERTIONS - 1,
		"the focused assertion roster remains exact"
	)
	print("PLANETARY_SUN_PRESENTATION_TEST_ASSERTIONS: %d" % _assertions)
	if _failures.is_empty():
		print("PLANETARY_SUN_PRESENTATION_TEST_OK")
		quit(0)
		return
	print("PLANETARY_SUN_PRESENTATION_TEST_FAILURES: %s" % _failures)
	quit(1)
