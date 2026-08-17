extends SceneTree

const ProfileScript := preload(
	"res://scripts/world/definitions/planetary_atmosphere_profile.gd"
)
const SamplerScript := preload(
	"res://scripts/world/planetary_atmosphere_sampler.gd"
)
const PresentationScript := preload(
	"res://scripts/world/planetary_atmosphere_presentation.gd"
)
const EXPECTED_ASSERTIONS := 34
const COMMON_AUTHORITY_KEYS := [
	"renderer", "gameplay", "streaming", "save", "network", "physics",
	"world_generation", "terrain_generation", "collision_generation",
	"origin_shift", "weather_clock", "audio",
]
const ADJACENT_AUTHORITY_KEYS := [
	"ship_movement", "player_movement", "landing", "navigation", "camera",
	"weather_selection", "cloud_advection", "entry_gameplay", "damage", "reward",
]
const EXPECTED_RENDERER_PROPERTIES := [
	"fog_density",
	"fog_light_color",
	"fog_light_energy",
	"fog_sky_affect",
]

var _assertions := 0
var _failures := PackedStringArray()
var _signal_adapter: PlanetaryAtmospherePresentation
var _signal_profile: PlanetaryAtmosphereProfile
var _signal_environment: Environment
var _signal_events: Array[Dictionary] = []
var _signal_post_commit_checks := PackedByteArray()
var _probe_reentry := false
var _reentry_results: Array[Dictionary] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_configuration_rejections()
	var fixture := _make_fixture()
	var adapter := fixture.adapter as PlanetaryAtmospherePresentation
	var profile := fixture.profile as PlanetaryAtmosphereProfile
	var environment := fixture.environment as Environment
	var sampler := fixture.sampler as PlanetaryAtmosphereSampler
	_signal_adapter = adapter
	_signal_profile = profile
	_signal_environment = environment
	adapter.presentation_committed.connect(_on_presentation_committed)
	_test_configuration_and_detachment(adapter, profile, environment, sampler)
	_test_fog_and_atmosphere_boundaries(adapter, profile, environment, sampler)
	_test_cloud_entry_and_invalid_observations(adapter, profile, environment)
	_test_structured_red_and_repair(adapter, profile, environment)
	await _test_tree_detach_reentry(adapter, profile, environment)
	_test_reset_generation_and_reports(adapter, profile, environment)
	await _test_expired_environment_fails_closed()
	if is_instance_valid(adapter):
		adapter.queue_free()
	await process_frame
	_finish()


func _test_configuration_rejections() -> void:
	var adapter := PresentationScript.new() as PlanetaryAtmospherePresentation
	root.add_child(adapter)
	var environment := _environment()
	var invalid_profile := _profile()
	invalid_profile.reference_density_kg_m3 = NAN
	var before := adapter.get_state_snapshot()
	var missing_profile := adapter.configure(null, environment)
	var missing_environment := adapter.configure(_profile(), null)
	var invalid := adapter.configure(invalid_profile, environment)
	var reset := adapter.reset_for_reuse(0)
	_check(
		missing_profile.reason == &"missing_profile"
		and missing_environment.reason == &"missing_environment"
		and invalid.reason == &"invalid_profile"
		and reset.reason == &"not_configured"
		and adapter.get_state_snapshot() == before,
		"missing/invalid configuration and premature reset reject without partial state"
	)
	_check(
		not bool(adapter.audit().valid)
		and (adapter.audit().errors as PackedStringArray).has(
			"presentation_not_configured"
		),
		"unconfigured audit fails closed with one typed reason"
	)
	adapter.queue_free()


func _test_configuration_and_detachment(
		adapter: PlanetaryAtmospherePresentation,
		profile: PlanetaryAtmosphereProfile,
		environment: Environment,
		sampler: PlanetaryAtmosphereSampler
	) -> void:
	var baseline := _renderer_values(environment)
	var configured := adapter.configure(profile, environment)
	var snapshot := adapter.get_state_snapshot()
	var renderer := snapshot.renderer as Dictionary
	_check(
		configured.accepted and configured.reason == &"configured"
		and int(configured.generation) == 1 and int(configured.revision) == 1
		and bool(snapshot.configured) and snapshot.profile_id == profile.profile_id
		and snapshot.equation_version == SamplerScript.EQUATION_VERSION,
		"valid profile and caller Environment configure exact generation/profile/equation identity"
	)
	_check(
		int(renderer.environment_instance_id) == environment.get_instance_id()
		and renderer.baseline == baseline and renderer.expected == baseline
		and renderer.actual == baseline and bool(renderer.current_values_applied)
		and (renderer.owned_properties as Array)
		== EXPECTED_RENDERER_PROPERTIES,
		"configuration freezes the exact four-property baseline and target identity"
	)
	_check(
		bool(adapter.audit().valid) and adapter.get_child_count() == 0
		and not adapter.is_processing() and not adapter.is_physics_processing(),
		"configured adapter is valid, childless, and owns no frame cadence"
	)
	var duplicate := adapter.configure(_profile(), _environment())
	_check(
		duplicate.reason == &"already_configured"
		and adapter.get_state_snapshot() == snapshot,
		"successful configuration is immutable and cannot replace profile or renderer"
	)

	profile.profile_id = &"mutated_source"
	profile.fog_density_unitless = 0.99
	profile.rayleigh_scattering_per_m = Color(1.0, 0.0, 0.0, 1.0)
	var frozen := adapter.get_profile_snapshot()
	_check(
		frozen.profile_id == &"temperate_game_scale"
		and is_equal_approx(float((frozen.optics as Dictionary).fog_density_unitless), 0.22)
		and (frozen.optics as Dictionary).rayleigh_scattering_per_m
		== Color(0.0000058, 0.0000135, 0.0000331, 1.0),
		"source profile mutation cannot retune the detached presentation or sampler"
	)
	# The fixture sampler was configured before source mutation and therefore
	# provides the exact same immutable upstream reference sample.
	_check(
		sampler.get_snapshot().profile_id == frozen.profile_id,
		"independent sampler fixture shares the exact frozen profile identity"
	)


func _test_fog_and_atmosphere_boundaries(
		adapter: PlanetaryAtmospherePresentation,
		profile: PlanetaryAtmosphereProfile,
		environment: Environment,
		sampler: PlanetaryAtmosphereSampler
	) -> void:
	var generation := adapter.get_generation()
	var fog_start_result := adapter.present_observation(
		0.0, 1500.0, 0.0, 1.0, 1.0, generation
	)
	var fog_start_sample := sampler.sample(0.0, 1500.0, 0.0, 1.0, 1.0)
	_check(
		fog_start_result.accepted
		and adapter.get_state_snapshot().last_sample == fog_start_sample
		and is_zero_approx(environment.fog_density)
		and is_zero_approx(environment.fog_sky_affect),
		"the exact frozen fog-start boundary presents zero density and sky affect"
	)
	var fog_end_result := adapter.present_observation(
		0.0, 12000.0, 0.0, 1.0, 1.0, generation
	)
	var fog_end_sample := sampler.sample(0.0, 12000.0, 0.0, 1.0, 1.0)
	var expected_density := (
		-log(1.0 - float(fog_end_sample.fog_factor)) / 12000.0
	)
	_check(
		fog_end_result.reason == &"observation_presented"
		and adapter.get_state_snapshot().last_sample == fog_end_sample
		and is_equal_approx(environment.fog_density, expected_density)
		and is_equal_approx(environment.fog_sky_affect, 0.11)
		and is_equal_approx(environment.fog_light_energy, 1.0),
		"fog-end opacity maps through the exact negative-log path equation"
	)
	_check(
		environment.fog_light_color.is_equal_approx(
			_expected_scattering_color(adapter.get_profile_snapshot())
		)
		and environment.fog_enabled
		and environment.fog_depth_begin == 91.0
		and environment.fog_depth_end == 777.0,
		"renderer owns its derived colour only and leaves fog enable/depth policy untouched"
	)

	var below_top_result := adapter.present_observation(
		19999.999, 12000.0, 0.0, 1.0, 1.0, generation
	)
	var below_top := adapter.get_state_snapshot().last_sample as Dictionary
	_check(
		below_top_result.accepted and not bool(below_top.vacuum)
		and float(below_top.density_ratio) > 0.0
		and environment.fog_density > 0.0,
		"the representable point below atmosphere top remains a nonzero presentation"
	)
	var exact_top_result := adapter.present_observation(
		20000.0, 12000.0, 500.0, 1.0, 1.0, generation
	)
	var exact_top := adapter.get_state_snapshot().last_sample as Dictionary
	_check(
		exact_top_result.accepted and bool(exact_top.vacuum)
		and is_zero_approx(environment.fog_density)
		and is_zero_approx(environment.fog_sky_affect)
		and is_equal_approx(environment.fog_light_energy, 0.35),
		"the exact atmosphere-top boundary is vacuum with zero fog influence"
	)
	var before_duplicate := adapter.get_state_snapshot()
	var signal_count := _signal_events.size()
	var duplicate := adapter.present_observation(
		20000.0, 12000.0, 500.0, 1.0, 1.0, generation
	)
	_check(
		duplicate.reason == &"unchanged"
		and adapter.get_state_snapshot() == before_duplicate
		and _signal_events.size() == signal_count,
		"an identical observation is revision- and signal-free"
	)


func _test_cloud_entry_and_invalid_observations(
		adapter: PlanetaryAtmospherePresentation,
		_profile_source: PlanetaryAtmosphereProfile,
		environment: Environment
	) -> void:
	var generation := adapter.get_generation()
	var at_cloud_base := adapter.present_observation(
		3000.0, 0.0, 160.0, 1.0, 1.0, generation
	)
	var base_sample := adapter.get_state_snapshot().last_sample as Dictionary
	var at_cloud_top := adapter.present_observation(
		6000.0, 0.0, 340.0, 1.0, 1.0, generation
	)
	var top_sample := adapter.get_state_snapshot().last_sample as Dictionary
	_check(
		at_cloud_base.accepted and at_cloud_top.accepted
		and is_equal_approx(float(base_sample.cloud_layer_factor), 0.55)
		and is_zero_approx(float(top_sample.cloud_layer_factor))
		and is_zero_approx(float(base_sample.entry_effect_intensity)),
		"cloud base/top and entry minimum remain exact sampler boundaries"
	)
	var full_entry := adapter.present_observation(
		10000.0, 0.0, 340.0, 1.0, 1.0, generation
	)
	var full_sample := adapter.get_state_snapshot().last_sample as Dictionary
	_check(
		full_entry.accepted
		and is_equal_approx(float(full_sample.entry_effect_intensity), 1.0)
		and not bool((adapter.audit().capabilities as Dictionary).cloud_renderer_implemented)
		and not bool((adapter.audit().capabilities as Dictionary).entry_renderer_implemented),
		"cloud and entry samples are detached truth without overclaiming renderer channels"
	)

	var before_invalid := adapter.get_state_snapshot()
	var before_environment := _renderer_values(environment)
	var before_signals := _signal_events.size()
	var wrong_generation := adapter.present_observation(
		0.0, 0.0, 0.0, 1.0, 1.0, generation + 1
	)
	var nan_altitude := adapter.present_observation(
		NAN, 0.0, 0.0, 1.0, 1.0, generation
	)
	var infinite_path := adapter.present_observation(
		0.0, INF, 0.0, 1.0, 1.0, generation
	)
	var invalid_scalar := adapter.present_observation(
		0.0, 0.0, 0.0, 1.01, 1.0, generation
	)
	_check(
		wrong_generation.reason == &"stale_generation"
		and nan_altitude.reason == &"invalid_altitude"
		and infinite_path.reason == &"invalid_path_distance"
		and invalid_scalar.reason == &"invalid_weather_intensity"
		and adapter.get_state_snapshot() == before_invalid
		and _renderer_values(environment) == before_environment
		and _signal_events.size() == before_signals,
		"stale generation and non-finite/out-of-range observations reject with byte-stable state"
	)


func _test_structured_red_and_repair(
		adapter: PlanetaryAtmospherePresentation,
		profile: PlanetaryAtmosphereProfile,
		environment: Environment
	) -> void:
	var generation := adapter.get_generation()
	adapter.present_observation(0.0, 12000.0, 0.0, 1.0, 1.0, generation)
	var expected_density := environment.fog_density
	environment.fog_density = 0.91
	var renderer_red := adapter.audit()
	_check(
		not bool(renderer_red.valid)
		and (renderer_red.errors as PackedStringArray).has("owned_renderer_state_drift"),
		"structured red: external owned-property mutation invalidates the audit"
	)
	var repair := adapter.present_observation(
		0.0, 12000.0, 0.0, 1.0, 1.0, generation
	)
	_check(
		repair.reason == &"renderer_reapplied"
		and is_equal_approx(environment.fog_density, expected_density)
		and bool(adapter.audit().valid),
		"repeating the caller observation repairs renderer drift through a committed update"
	)

	environment.fog_enabled = false
	environment.fog_depth_begin = 333.0
	environment.fog_depth_end = 999.0
	_check(
		bool(adapter.audit().valid)
		and not environment.fog_enabled
		and environment.fog_depth_begin == 333.0
		and environment.fog_depth_end == 999.0,
		"non-owned quality/depth properties remain caller authority and do not invalidate audit"
	)

	var timer := Timer.new()
	timer.name = "ForbiddenClock"
	adapter.add_child(timer)
	var child_red := adapter.audit()
	_check(
		not bool(child_red.valid)
		and (child_red.errors as PackedStringArray).has(
			"passive_adapter_gained_child_nodes"
		),
		"structured red: any injected child invalidates the passive adapter budget"
	)
	adapter.remove_child(timer)
	timer.queue_free()
	var original_profile_id := adapter.get("_profile_id") as StringName
	adapter.set("_profile_id", &"forged_profile")
	var identity_red := adapter.audit()
	adapter.set("_profile_id", original_profile_id)
	_check(
		not bool(identity_red.valid)
		and (identity_red.errors as PackedStringArray).has("profile_snapshot_drift")
		and bool(adapter.audit().valid),
		"structured red: frozen profile identity drift is detected and reversible"
	)

	_probe_reentry = true
	_reentry_results.clear()
	adapter.present_observation(1000.0, 12000.0, 0.0, 1.0, 1.0, generation)
	_probe_reentry = false
	var all_reentrant := _reentry_results.size() == 3
	for result in _reentry_results:
		all_reentrant = all_reentrant and result.reason == &"reentrant_call"
	_check(
		all_reentrant
		and not _signal_post_commit_checks.is_empty()
		and bool(_signal_post_commit_checks[-1]),
		"post-commit signal observes committed state and rejects every mutator reentry"
	)
	_check(
		profile.profile_id == &"mutated_source",
		"signal reentry cannot reconfigure or mutate the released source profile"
	)


func _test_tree_detach_reentry(
		adapter: PlanetaryAtmospherePresentation,
		_profile_source: PlanetaryAtmosphereProfile,
		environment: Environment
	) -> void:
	var generation := adapter.get_generation()
	adapter.present_observation(0.0, 12000.0, 0.0, 1.0, 1.0, generation)
	var expected := _renderer_values(environment)
	var baseline := adapter.get_renderer_snapshot().baseline as Dictionary
	var before := adapter.get_state_snapshot()
	var signal_count := _signal_events.size()
	var parent := adapter.get_parent()
	parent.remove_child(adapter)
	await process_frame
	var detached := adapter.get_state_snapshot()
	_check(
		not adapter.is_inside_tree() and _renderer_values(environment) == baseline
		and int(detached.generation) == generation
		and int(detached.revision) == int(before.revision)
		and detached.last_sample == before.last_sample
		and _signal_events.size() == signal_count,
		"tree detach restores baseline and freezes generation/sample/signals"
	)
	parent.add_child(adapter)
	await process_frame
	var reentered := adapter.get_state_snapshot()
	_check(
		adapter.is_inside_tree() and _renderer_values(environment) == expected
		and int(reentered.generation) == generation
		and int(reentered.revision) == int(before.revision)
		and reentered.last_sample == before.last_sample
		and _signal_events.size() == signal_count
		and bool(adapter.audit().valid),
		"tree reentry reapplies the same resource state without replay or generation churn"
	)


func _test_reset_generation_and_reports(
		adapter: PlanetaryAtmospherePresentation,
		_profile_source: PlanetaryAtmosphereProfile,
		environment: Environment
	) -> void:
	var old_generation := adapter.get_generation()
	var baseline := adapter.get_renderer_snapshot().baseline as Dictionary
	var reset := adapter.reset_for_reuse(old_generation)
	var reset_snapshot := adapter.get_state_snapshot()
	_check(
		reset.accepted and reset.reason == &"reset"
		and adapter.get_generation() == old_generation + 1
		and not bool(reset_snapshot.has_presented_sample)
		and (reset_snapshot.last_sample as Dictionary).is_empty()
		and _renderer_values(environment) == baseline,
		"reset advances generation, clears sample, and restores the exact baseline"
	)
	var before_stale := adapter.get_state_snapshot()
	var stale := adapter.present_observation(
		0.0, 12000.0, 0.0, 1.0, 1.0, old_generation
	)
	_check(
		stale.reason == &"stale_generation"
		and adapter.get_state_snapshot() == before_stale,
		"pre-reset generation cannot revive stale atmosphere presentation"
	)

	var snapshot := adapter.get_state_snapshot()
	var audit := adapter.audit()
	(snapshot.profile as Dictionary).clear()
	(snapshot.last_sample as Dictionary)["fog_factor"] = 99.0
	(snapshot.renderer as Dictionary).clear()
	(snapshot.authority as Dictionary)["gameplay"] = true
	(audit.evidence as Dictionary)["status"] = &"source_authentic"
	(audit.capabilities as Dictionary)["cloud_renderer_implemented"] = true
	var fresh := adapter.get_state_snapshot()
	var fresh_audit := adapter.audit()
	_check(
		not (fresh.profile as Dictionary).is_empty()
		and (fresh.last_sample as Dictionary).is_empty()
		and not (fresh.renderer as Dictionary).is_empty()
		and not bool((fresh.authority as Dictionary).gameplay)
		and (fresh_audit.evidence as Dictionary).status == &"modern_interpretation"
		and not bool((fresh_audit.capabilities as Dictionary).cloud_renderer_implemented),
		"state/audit/profile/sample/renderer/evidence snapshots are deeply detached"
	)
	_check(
		_exact_authority(fresh_audit.authority, COMMON_AUTHORITY_KEYS, &"renderer")
		and _exact_authority(fresh_audit.adjacent_authority, ADJACENT_AUTHORITY_KEYS)
		and (fresh_audit.owned_renderer_properties as Array)
		== EXPECTED_RENDERER_PROPERTIES,
		"audit freezes exact renderer-only authority and the four-property ownership roster"
	)
	_check(
		not _contains_live_capability(fresh)
		and not _contains_live_capability(fresh_audit)
		and not _contains_live_capability(adapter.get_renderer_snapshot()),
		"all public reports contain detached values and no Node/Resource/WeakRef capability"
	)
	_check(
		int((fresh_audit.performance as Dictionary).runtime_child_node_count) == 0
		and int((fresh_audit.performance as Dictionary).owned_environment_resource_count) == 0
		and int((fresh_audit.performance as Dictionary).owned_sky_resource_count) == 0
		and int((fresh_audit.performance as Dictionary).process_loop_count) == 0,
		"performance audit freezes a childless passive adapter with zero owned renderer resources"
	)


func _test_expired_environment_fails_closed() -> void:
	var adapter := PresentationScript.new() as PlanetaryAtmospherePresentation
	root.add_child(adapter)
	var environment := _environment()
	var configured := adapter.configure(_profile(), environment)
	var generation := adapter.get_generation()
	_check(configured.accepted, "environment-expiry fixture configures normally")
	environment = null
	await process_frame
	var report := adapter.audit()
	var result := adapter.present_observation(
		0.0, 12000.0, 0.0, 1.0, 1.0, generation
	)
	_check(
		not bool(report.valid)
		and (report.errors as PackedStringArray).has("environment_unavailable")
		and result.reason == &"environment_unavailable",
		"expired weak renderer target fails audit and observation closed"
	)
	adapter.queue_free()


func _on_presentation_committed(reason: StringName, snapshot: Dictionary) -> void:
	_signal_events.append({
		"reason": reason,
		"generation": int(snapshot.get("generation", -1)),
		"revision": int(snapshot.get("revision", -1)),
	})
	_signal_post_commit_checks.append(
		1 if snapshot == _signal_adapter.get_state_snapshot() else 0
	)
	if _probe_reentry:
		var generation := _signal_adapter.get_generation()
		_reentry_results.append(_signal_adapter.present_observation(
			0.0, 0.0, 0.0, 1.0, 1.0, generation
		))
		_reentry_results.append(_signal_adapter.reset_for_reuse(generation))
		_reentry_results.append(_signal_adapter.configure(
			_signal_profile, _signal_environment
		))
	(snapshot.get("profile", {}) as Dictionary).clear()
	(snapshot.get("renderer", {}) as Dictionary).clear()


func _make_fixture() -> Dictionary:
	var profile := _profile()
	var sampler := SamplerScript.new() as PlanetaryAtmosphereSampler
	var sampler_config := sampler.configure(profile)
	if not bool(sampler_config.accepted):
		push_error("atmosphere sampler fixture failed to configure")
	var environment := _environment()
	var adapter := PresentationScript.new() as PlanetaryAtmospherePresentation
	adapter.name = "PlanetaryAtmospherePresentation"
	root.add_child(adapter)
	return {
		"adapter": adapter,
		"profile": profile,
		"sampler": sampler,
		"environment": environment,
	}


func _profile() -> PlanetaryAtmosphereProfile:
	return ProfileScript.new() as PlanetaryAtmosphereProfile


func _environment() -> Environment:
	var environment := Environment.new()
	environment.fog_enabled = true
	environment.fog_density = 0.0045
	environment.fog_light_color = Color(0.31, 0.37, 0.44, 1.0)
	environment.fog_light_energy = 0.82
	environment.fog_sky_affect = 0.27
	environment.fog_depth_begin = 91.0
	environment.fog_depth_end = 777.0
	return environment


func _renderer_values(environment: Environment) -> Dictionary:
	return {
		"fog_density": environment.fog_density,
		"fog_light_color": environment.fog_light_color,
		"fog_light_energy": environment.fog_light_energy,
		"fog_sky_affect": environment.fog_sky_affect,
	}



func _expected_scattering_color(profile_snapshot: Dictionary) -> Color:
	var optics := profile_snapshot.get("optics", {}) as Dictionary
	var rayleigh := optics.rayleigh_scattering_per_m as Color
	var mie := optics.mie_scattering_per_m as Color
	var combined := Vector3(
		rayleigh.r + mie.r,
		rayleigh.g + mie.g,
		rayleigh.b + mie.b
	)
	var strongest := maxf(combined.x, maxf(combined.y, combined.z))
	var normalized := combined / strongest
	return Color(
		0.18 + normalized.x * 0.62,
		0.18 + normalized.y * 0.62,
		0.18 + normalized.z * 0.62,
		1.0
	)


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
	for key in expected_keys:
		if not dictionary.has(key) or dictionary[key] is not bool:
			return false
		if bool(dictionary[key]) != (StringName(key) == true_key):
			return false
	return true


func _contains_live_capability(value: Variant) -> bool:
	if value is Node or value is Resource or value is WeakRef \
			or value is Callable or value is Signal:
		return true
	if value is Dictionary:
		for key: Variant in (value as Dictionary):
			if _contains_live_capability(key) \
					or _contains_live_capability((value as Dictionary)[key]):
				return true
	elif value is Array:
		for entry: Variant in value as Array:
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
	print("PLANETARY_ATMOSPHERE_PRESENTATION_ASSERTIONS: ", _assertions)
	if _assertions != EXPECTED_ASSERTIONS:
		_failures.append(
			"assertion count drifted: expected %d got %d"
			% [EXPECTED_ASSERTIONS, _assertions]
		)
	if _failures.is_empty():
		print("PLANETARY_ATMOSPHERE_PRESENTATION_TEST_OK")
		quit(0)
	else:
		print(
			"PLANETARY_ATMOSPHERE_PRESENTATION_TEST_FAILED: ",
			", ".join(_failures)
		)
		quit(1)
