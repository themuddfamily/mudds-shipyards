extends SceneTree

const ProfileScript := preload(
	"res://scripts/world/definitions/planetary_atmosphere_profile.gd"
)
const PresentationScript := preload(
	"res://scripts/world/planetary_entry_heat_presentation.gd"
)
const ENTRY_SHADER := preload(
	"res://scripts/rendering/planetary_entry_heat_overlay.gdshader"
)
const EXPECTED_ASSERTIONS := 44
const OWNED_PARAMETER: StringName = &"entry_effect_intensity_unitless"
const COMMON_AUTHORITY_KEYS := [
	"renderer", "gameplay", "streaming", "save", "network", "physics",
	"world_generation", "terrain_generation", "collision_generation",
	"origin_shift", "weather_clock", "audio",
]
const ADJACENT_AUTHORITY_KEYS := [
	"material_ownership", "shader_ownership", "target_geometry_ownership",
	"ship_visibility", "ship_attachment", "movement", "airflow_direction",
	"physics_drag", "damage", "gameplay_heat", "weather", "clock",
	"visual_quality", "particles", "lights", "audio", "streaming", "save",
	"network",
]

var _assertions := 0
var _failures := PackedStringArray()
var _events: Array[Dictionary] = []
var _adapter: PlanetaryEntryHeatPresentation
var _profile: PlanetaryAtmosphereProfile
var _material: ShaderMaterial
var _shader: Shader
var _replacement_shader: Shader
var _material_attack_armed := false
var _material_attack_mode: StringName = &""
var _material_reentry_results: Array[Dictionary] = []
var _signal_attack_armed := false
var _signal_reentry_results: Array[Dictionary] = []


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
	_test_exact_sampler_boundaries()
	_test_determinism_and_invalid_inputs()
	_test_owned_drift_and_non_owned_uniform()
	_test_resource_changed_transactions()
	_test_signal_reentry_and_detachment()
	await _test_queued_adapter_rejects_atomically()
	_test_reset_and_detached_reports()
	await _test_target_expiry()
	if is_instance_valid(_adapter):
		_adapter.queue_free()
	await process_frame
	_finish()


func _test_configuration_rejections() -> void:
	var adapter := PresentationScript.new() as PlanetaryEntryHeatPresentation
	root.add_child(adapter)
	var invalid_profile := ProfileScript.new() as PlanetaryAtmosphereProfile
	invalid_profile.entry_effect_full_speed_mps = NAN
	var no_shader := ShaderMaterial.new()
	var canvas := Shader.new()
	canvas.code = "shader_type canvas_item; uniform float entry_effect_intensity_unitless = 0.0;"
	var canvas_material := ShaderMaterial.new()
	canvas_material.shader = canvas
	var state := adapter.get_state_snapshot()
	_check(
		adapter.configure(null, _make_material()).reason == &"missing_profile"
		and adapter.configure(ProfileScript.new(), null).reason == &"missing_material"
		and adapter.get_state_snapshot() == state,
		"missing profile/material reject atomically"
	)
	_check(
		adapter.configure(invalid_profile, _make_material()).reason == &"invalid_profile"
		and adapter.configure(ProfileScript.new(), no_shader).reason == &"missing_shader"
		and adapter.configure(ProfileScript.new(), canvas_material).reason
		== &"shader_not_spatial",
		"invalid profile and absent/non-spatial shader have exact reasons"
	)
	var missing := _material_for_code(
		"shader_type spatial; uniform float unrelated = 0.0;"
	)
	var wrong_type := _material_for_code(
		"shader_type spatial; uniform vec3 entry_effect_intensity_unitless = vec3(0.0);"
	)
	_check(
		adapter.configure(ProfileScript.new(), missing).reason
		== &"shader_uniform_contract_mismatch"
		and adapter.configure(ProfileScript.new(), wrong_type).reason
		== &"shader_uniform_contract_mismatch",
		"missing and mistyped owned uniforms fail introspected schema"
	)
	var nonzero := _make_material()
	nonzero.set_shader_parameter(OWNED_PARAMETER, 0.01)
	_check(
		adapter.configure(ProfileScript.new(), nonzero).reason
		== &"baseline_must_be_zero"
		and adapter.reset_for_reuse(0).reason == &"not_configured"
		and not bool(adapter.audit().valid),
		"only exact zero baseline configures and premature reset stays red"
	)
	var shared_material := _make_material()
	shared_material.resource_local_to_scene = false
	_check(
		adapter.configure(ProfileScript.new(), shared_material).reason
		== &"material_not_exclusive"
		and adapter.get_state_snapshot() == state,
		"shared ShaderMaterial fails the exact exclusivity witness atomically"
	)
	adapter.queue_free()


func _test_configuration_and_source_detachment() -> void:
	var configured := _adapter.configure(_profile, _material)
	var state := _adapter.get_state_snapshot()
	_check(
		configured.accepted and configured.reason == &"configured"
		and configured.generation == 1 and configured.revision == 1
		and state.profile_id == &"temperate_game_scale"
		and state.equation_version == PresentationScript.EQUATION_VERSION,
		"configure commits exact identity, generation, and revision"
	)
	_check(
		state.renderer.baseline[OWNED_PARAMETER] == 0.0
		and state.renderer.expected[OWNED_PARAMETER] == 0.0
		and state.renderer.actual[OWNED_PARAMETER] == 0.0
		and state.renderer.owned_parameters == [String(OWNED_PARAMETER)],
		"configure freezes the exact one-uniform zero baseline"
	)
	_check(
		bool(_adapter.audit().valid) and _adapter.get_child_count() == 0
		and not _adapter.is_processing() and not _adapter.is_physics_processing(),
		"adapter is valid, childless, and has no hidden cadence"
	)
	var frozen_before := _adapter.get_profile_snapshot()
	_profile.profile_id = &"caller_mutated"
	_profile.entry_effect_start_altitude_m = 17000.0
	_profile.entry_effect_full_altitude_m = 9000.0
	_profile.entry_effect_minimum_speed_mps = 200.0
	_profile.entry_effect_full_speed_mps = 400.0
	var frozen_after := _adapter.get_profile_snapshot()
	_check(
		frozen_after == frozen_before
		and frozen_after.profile_id == &"temperate_game_scale"
		and frozen_after.entry_effects.start_altitude_m == 18000.0
		and frozen_after.entry_effects.full_speed_mps == 340.0,
		"source mutation cannot retune the frozen profile/sampler"
	)
	_check(
		_adapter.configure(ProfileScript.new(), _make_material()).reason
		== &"already_configured",
		"successful configuration is immutable"
	)


func _test_exact_sampler_boundaries() -> void:
	var top := _adapter.present_observation(20000.0, 340.0, 1)
	var above := _adapter.present_observation(20001.0, 340.0, 1)
	_check(
		top.accepted and above.accepted
		and top.observation.vacuum and above.observation.vacuum
		and top.observation.entry_effect_intensity_unitless == 0.0
		and above.observation.entry_effect_intensity_unitless == 0.0,
		"atmosphere top and above are exact zero-intensity vacuum"
	)
	var start := _adapter.present_observation(18000.0, 340.0, 1)
	var below_start := _adapter.present_observation(17999.0, 340.0, 1)
	_check(
		start.observation.entry_effect_intensity_unitless == 0.0
		and below_start.observation.entry_effect_intensity_unitless > 0.0,
		"entry altitude start is exact zero and just below is positive"
	)
	var full := _adapter.present_observation(10000.0, 340.0, 1)
	var below_full := _adapter.present_observation(9999.0, 340.0, 1)
	_check(
		full.observation.entry_effect_intensity_unitless == 1.0
		and below_full.observation.entry_effect_intensity_unitless == 1.0
		and _material.get_shader_parameter(OWNED_PARAMETER) == 1.0,
		"full altitude and below map to exact one at full speed"
	)
	var minimum := _adapter.present_observation(10000.0, 160.0, 1)
	var above_minimum := _adapter.present_observation(10000.0, 160.001, 1)
	_check(
		minimum.observation.entry_effect_intensity_unitless == 0.0
		and above_minimum.observation.entry_effect_intensity_unitless > 0.0,
		"minimum speed is exact zero and just above is positive"
	)
	var full_speed := _adapter.present_observation(10000.0, 340.0, 1)
	var over_full_speed := _adapter.present_observation(10000.0, 400.0, 1)
	_check(
		full_speed.observation.entry_effect_intensity_unitless == 1.0
		and over_full_speed.observation.entry_effect_intensity_unitless == 1.0,
		"full speed and above map to exact one inside the entry shell"
	)
	var midpoint := _adapter.present_observation(14000.0, 250.0, 1)
	_check(
		midpoint.accepted
		and is_equal_approx(
			midpoint.observation.entry_effect_intensity_unitless, 0.25
		)
		and midpoint.observation.sample.inputs.path_distance_m == 0.0
		and midpoint.observation.sample.inputs.weather_scalar == 0.0
		and midpoint.observation.sample.inputs.cloud_scalar == 0.0,
		"midpoint multiplies altitude/speed factors and samples no optics/weather"
	)


func _test_determinism_and_invalid_inputs() -> void:
	var first := _adapter.present_observation(14000.0, 250.0, 1)
	var revision: int = int(_adapter.get_state_snapshot().revision)
	var cadence_30: Dictionary = (
		first.observation as Dictionary
	).duplicate(true)
	var cadence_60 := _adapter.present_observation(14000.0, 250.0, 1)
	var cadence_120 := _adapter.present_observation(14000.0, 250.0, 1)
	_check(
		cadence_60.reason == &"unchanged" and cadence_120.reason == &"unchanged"
		and cadence_30 == cadence_60.observation
		and cadence_30 == cadence_120.observation
		and _adapter.get_state_snapshot().revision == revision,
		"identical 30/60/120-equivalent caller samples are timestep-free"
	)
	var before := _adapter.get_state_snapshot()
	_check(
		_adapter.present_observation(true, 250.0, 1).reason == &"invalid_altitude"
		and _adapter.present_observation("14000", 250.0, 1).reason == &"invalid_altitude"
		and _adapter.present_observation(NAN, 250.0, 1).reason == &"invalid_altitude"
		and _adapter.present_observation(INF, 250.0, 1).reason == &"invalid_altitude",
		"wrong-type and nonfinite altitude observations reject"
	)
	_check(
		_adapter.present_observation(14000.0, true, 1).reason == &"invalid_speed"
		and _adapter.present_observation(14000.0, -0.001, 1).reason == &"invalid_speed"
		and _adapter.present_observation(14000.0, INF, 1).reason == &"invalid_speed"
		and _adapter.present_observation(
			14000.0, PlanetaryAtmosphereProfile.MAX_ENTRY_SPEED_MPS + 1.0, 1
		).reason == &"invalid_speed",
		"wrong-type, negative, nonfinite, and over-ceiling speeds reject"
	)
	_check(
		_adapter.present_observation(14000.0, 250.0, 1.0).reason
		== &"stale_generation"
		and _adapter.present_observation(14000.0, 250.0, 0).reason
		== &"stale_generation"
		and _adapter.get_state_snapshot() == before,
		"generation type/value reds leave exact prior state"
	)


func _test_owned_drift_and_non_owned_uniform() -> void:
	var non_owned_before: Variant = _material.get_shader_parameter(
		&"entry_heat_max_alpha"
	)
	var presented := _adapter.present_observation(10000.0, 340.0, 1)
	_check(
		presented.accepted
		and _material.get_shader_parameter(OWNED_PARAMETER) == 1.0
		and _material.get_shader_parameter(&"entry_heat_max_alpha")
		== non_owned_before,
		"mapping changes only the one owned uniform"
	)
	_material.set_shader_parameter(OWNED_PARAMETER, 0.4)
	var red_audit := _adapter.audit()
	var revision: int = int(_adapter.get_state_snapshot().revision)
	var repaired := _adapter.present_observation(10000.0, 340.0, 1)
	_check(
		not red_audit.valid and red_audit.errors.has("owned_material_state_drift")
		and repaired.accepted and repaired.reason == &"material_reapplied"
		and _material.get_shader_parameter(OWNED_PARAMETER) == 1.0
		and _adapter.get_state_snapshot().revision == revision + 1,
		"external owned drift is visible and duplicate observation repairs it"
	)
	var retained_observation: Dictionary = (
		_adapter.get_state_snapshot().last_observation as Dictionary
	).duplicate(true)
	var retained_revision: int = int(_adapter.get_state_snapshot().revision)
	_material.resource_local_to_scene = false
	var exclusivity_audit := _adapter.audit()
	var exclusivity_red := _adapter.present_observation(10000.0, 340.0, 1)
	_check(
		not exclusivity_audit.valid
		and exclusivity_audit.errors.has("material_identity_drift")
		and exclusivity_red.reason == &"renderer_target_unavailable"
		and _adapter.get_state_snapshot().revision == retained_revision
		and _adapter.get_state_snapshot().last_observation == retained_observation,
		"loss of live material exclusivity fails closed without state drift"
	)
	_material.resource_local_to_scene = true


func _test_resource_changed_transactions() -> void:
	_adapter.present_observation(14000.0, 250.0, 1)
	var before := _adapter.get_state_snapshot()
	var events_before := _events.size()
	_material_attack_mode = &"property"
	_material_attack_armed = true
	var property_attack := _adapter.present_observation(10000.0, 340.0, 1)
	_check(
		property_attack.reason == &"renderer_state_changed_during_apply"
		and _adapter.get_state_snapshot() == before
		and _events.size() == events_before
		and _material.get_shader_parameter(OWNED_PARAMETER) == 0.25,
		"Resource.changed property overwrite rolls back with no false commit"
	)
	_check(
		_material_reentry_results.size() == 3
		and _all_reentrant(_material_reentry_results),
		"real Resource.changed callback blocks configure/present/reset reentry"
	)
	_material_reentry_results.clear()
	_replacement_shader = Shader.new()
	_replacement_shader.code = _shader.code
	_material_attack_mode = &"target"
	_material_attack_armed = true
	var target_attack := _adapter.present_observation(10000.0, 340.0, 1)
	var target_attack_state := _adapter.get_state_snapshot()
	_check(
		target_attack.reason == &"target_chain_changed_during_apply"
		and target_attack_state.generation == before.generation
		and target_attack_state.revision == before.revision
		and target_attack_state.last_observation == before.last_observation
		and target_attack_state.presented_observation_count
		== before.presented_observation_count
		and _events.size() == events_before,
		"callback target replacement cannot create a successful commit"
	)
	_material.shader = _shader
	_material.set_shader_parameter(OWNED_PARAMETER, 0.25)
	_material_reentry_results.clear()
	var shader_code := _shader.code
	_material_attack_mode = &"schema"
	_material_attack_armed = true
	var schema_attack := _adapter.present_observation(10000.0, 340.0, 1)
	var schema_attack_state := _adapter.get_state_snapshot()
	_check(
		schema_attack.reason == &"shader_schema_changed_during_apply"
		and schema_attack_state.generation == before.generation
		and schema_attack_state.revision == before.revision
		and schema_attack_state.last_observation == before.last_observation
		and schema_attack_state.presented_observation_count
		== before.presented_observation_count
		and _events.size() == events_before,
		"callback shader-schema drift cannot create a successful commit"
	)
	_shader.code = shader_code
	_material.set_shader_parameter(OWNED_PARAMETER, 0.25)
	_check(
		bool(_adapter.audit().valid),
		"restored exact shader/material chain returns audit green"
	)


func _test_signal_reentry_and_detachment() -> void:
	_signal_attack_armed = true
	var committed := _adapter.present_observation(10000.0, 340.0, 1)
	_check(
		committed.accepted and _signal_reentry_results.size() == 3
		and _all_reentrant(_signal_reentry_results),
		"presentation signal observes committed state and blocks all mutators"
	)
	var event_snapshot := _events.back().snapshot as Dictionary
	event_snapshot.profile.clear()
	event_snapshot.renderer.actual.clear()
	_check(
		not _adapter.get_profile_snapshot().is_empty()
		and not _adapter.get_renderer_snapshot().actual.is_empty(),
		"signal payload mutation cannot alter retained profile or renderer state"
	)
	var generation := _adapter.get_generation()
	var revision: int = int(_adapter.get_state_snapshot().revision)
	root.remove_child(_adapter)
	_check(
		_material.get_shader_parameter(OWNED_PARAMETER) == 0.0
		and _adapter.get_generation() == generation
		and _adapter.get_state_snapshot().revision == revision,
		"tree exit restores exact zero without advancing lifecycle identity"
	)
	var detached_before := _adapter.get_state_snapshot()
	var detached_events := _events.size()
	var detached := _adapter.present_observation(14000.0, 250.0, generation)
	_check(
		not detached.accepted and detached.reason == &"presentation_detached"
		and _adapter.get_state_snapshot() == detached_before
		and _events.size() == detached_events
		and _material.get_shader_parameter(OWNED_PARAMETER) == 0.0,
		"detached observation rejects atomically without retaining deferred intent"
	)
	root.add_child(_adapter)
	var reentry_intensity: Variant = _material.get_shader_parameter(OWNED_PARAMETER)
	var fresh := _adapter.present_observation(14000.0, 250.0, generation)
	_check(
		reentry_intensity == 1.0
		and fresh.accepted
		and _material.get_shader_parameter(OWNED_PARAMETER) == 0.25
		and _adapter.get_generation() == generation,
		"tree reentry restores last live intent before a fresh observation updates it"
	)


func _test_queued_adapter_rejects_atomically() -> void:
	var fixture := _make_fixture()
	var adapter := fixture.adapter as PlanetaryEntryHeatPresentation
	var material := fixture.material as ShaderMaterial
	var events: Array[Dictionary] = []
	_check(
		adapter.configure(fixture.profile as PlanetaryAtmosphereProfile, material).accepted
		and adapter.present_observation(10000.0, 340.0, 1).accepted,
		"queued fixture has one live entry-heat presentation before deletion"
	)
	adapter.presentation_committed.connect(func(_reason: StringName, _snapshot: Dictionary) -> void:
		events.append({})
	)
	adapter.queue_free()
	var before := adapter.get_state_snapshot()
	var queued := adapter.present_observation(14000.0, 250.0, 1)
	_check(
		adapter.is_queued_for_deletion()
		and not queued.accepted and queued.reason == &"presentation_detached"
		and adapter.get_state_snapshot() == before and events.is_empty()
		and material.get_shader_parameter(OWNED_PARAMETER) == 1.0,
		"queued adapter rejects observation atomically before material or retained intent drift"
	)
	await process_frame


func _test_reset_and_detached_reports() -> void:
	var before := _adapter.get_state_snapshot()
	_check(
		_adapter.reset_for_reuse(0).reason == &"stale_generation"
		and _adapter.get_state_snapshot() == before,
		"stale reset is atomic"
	)
	var reset := _adapter.reset_for_reuse(1)
	_check(
		reset.accepted and reset.reason == &"reset" and reset.generation == 2
		and _material.get_shader_parameter(OWNED_PARAMETER) == 0.0
		and not _adapter.get_state_snapshot().has_presented_observation,
		"reset restores zero and advances generation exactly once"
	)
	_adapter._generation = PresentationScript.MAX_SAFE_GENERATION
	var exhaustion_before := _adapter.get_state_snapshot()
	var exhausted := _adapter.reset_for_reuse(
		PresentationScript.MAX_SAFE_GENERATION
	)
	_check(
		exhausted.reason == &"generation_exhausted"
		and _adapter.get_state_snapshot() == exhaustion_before
		and _material.get_shader_parameter(OWNED_PARAMETER) == 0.0,
		"safe generation exhaustion is typed red and exactly atomic"
	)
	_adapter._generation = 2
	var audit := _adapter.audit()
	var snapshot := _adapter.get_state_snapshot()
	_check(
		audit.evidence.size() == 4 and audit.evidence == {
			"content_class": &"NEW",
			"status": &"modern_interpretation",
			"source_bounded": false,
			"confidence": &"none",
		}
		and snapshot.evidence == audit.evidence,
		"snapshot/audit freeze exact four-key NEW evidence"
	)
	_check(
		audit.authority.size() == COMMON_AUTHORITY_KEYS.size()
		and _authority_matches(audit.authority, COMMON_AUTHORITY_KEYS, true)
		and audit.adjacent_authority.size() == ADJACENT_AUTHORITY_KEYS.size()
		and _authority_matches(
			audit.adjacent_authority, ADJACENT_AUTHORITY_KEYS, false
		),
		"authority is renderer-only with exact adjacent denials"
	)
	_check(
		audit.capabilities.entry_intensity_material_adapter_implemented
		and audit.capabilities.transactional_material_apply
		and not audit.capabilities.physical_heating_simulation
		and not audit.capabilities.directional_bow_shock
		and not audit.capabilities.production_ship_integration
		and not audit.capabilities.quality_selection,
		"capabilities distinguish normalized adapter from deferred systems"
	)
	var clean_profile_id: StringName = StringName(
		_adapter.get_profile_snapshot().profile_id
	)
	audit.state.profile.clear()
	audit.evidence.clear()
	snapshot.renderer.baseline.clear()
	_check(
		_adapter.get_profile_snapshot().profile_id == clean_profile_id
		and _adapter.audit().evidence.size() == 4
		and _adapter.get_renderer_snapshot().baseline.has(OWNED_PARAMETER)
		and not _contains_object(_adapter.audit()),
		"nested reports are detached and contain no live Object authority"
	)


func _test_target_expiry() -> void:
	var adapter := PresentationScript.new() as PlanetaryEntryHeatPresentation
	root.add_child(adapter)
	var profile := ProfileScript.new() as PlanetaryAtmosphereProfile
	var material := _make_material()
	var shader := material.shader
	_check(
		adapter.configure(profile, material).accepted,
		"expiry fixture configures before releasing caller target"
	)
	material = null
	shader = null
	await process_frame
	_check(
		adapter.present_observation(14000.0, 250.0, 1).reason
		== &"renderer_target_unavailable"
		and not bool(adapter.audit().valid),
		"expired weak target fails closed in mutation and audit"
	)
	adapter.queue_free()


func _make_fixture() -> Dictionary:
	var adapter := PresentationScript.new() as PlanetaryEntryHeatPresentation
	var profile := ProfileScript.new() as PlanetaryAtmosphereProfile
	var material := _make_material()
	root.add_child(adapter)
	return {
		"adapter": adapter,
		"profile": profile,
		"material": material,
		"shader": material.shader,
	}


func _make_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.resource_local_to_scene = true
	material.shader = ENTRY_SHADER
	material.set_shader_parameter(OWNED_PARAMETER, 0.0)
	return material


func _material_for_code(code: String) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = code
	var material := ShaderMaterial.new()
	material.resource_local_to_scene = true
	material.shader = shader
	return material


func _on_material_changed() -> void:
	if not _material_attack_armed:
		return
	_material_attack_armed = false
	_material_reentry_results = [
		_adapter.configure(ProfileScript.new(), _make_material()),
		_adapter.present_observation(14000.0, 250.0, _adapter.get_generation()),
		_adapter.reset_for_reuse(_adapter.get_generation()),
	]
	match _material_attack_mode:
		&"property":
			_material.set_shader_parameter(OWNED_PARAMETER, 0.73)
		&"target":
			_material.shader = _replacement_shader
		&"schema":
			_shader.code = "shader_type spatial; uniform float removed = 0.0;"


func _on_presentation_committed(reason: StringName, snapshot: Dictionary) -> void:
	_events.append({
		"reason": reason,
		"snapshot": snapshot.duplicate(true),
	})
	if not _signal_attack_armed:
		return
	_signal_attack_armed = false
	_signal_reentry_results = [
		_adapter.configure(ProfileScript.new(), _make_material()),
		_adapter.present_observation(14000.0, 250.0, _adapter.get_generation()),
		_adapter.reset_for_reuse(_adapter.get_generation()),
	]


func _all_reentrant(results: Array[Dictionary]) -> bool:
	for result in results:
		if bool(result.get("accepted", true)) \
				or result.get("reason", &"") != &"reentrant_call":
			return false
	return true


func _authority_matches(
		candidate: Dictionary,
		keys: Array,
		renderer_true: bool
	) -> bool:
	for key: String in keys:
		if not candidate.has(key) or not candidate[key] is bool:
			return false
		if bool(candidate[key]) != (renderer_true and key == "renderer"):
			return false
	return true


func _contains_object(value: Variant) -> bool:
	if value is Object or value is Callable or value is Signal:
		return true
	if value is Dictionary:
		for key: Variant in value:
			if _contains_object(key) or _contains_object(value[key]):
				return true
	if value is Array:
		for item: Variant in value:
			if _contains_object(item):
				return true
	return false


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _assertions != EXPECTED_ASSERTIONS:
		_failures.append(
			"assertion count mismatch: expected %d, got %d"
			% [EXPECTED_ASSERTIONS, _assertions]
		)
	if _failures.is_empty():
		print("PLANETARY_ENTRY_HEAT_PRESENTATION_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error("PLANETARY_ENTRY_HEAT_PRESENTATION_TEST_FAIL: %s" % failure)
	quit(1)
