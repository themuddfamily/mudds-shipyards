extends SceneTree

const RIG_SCENE := preload(
	"res://scenes/world/components/planetary_atmosphere_world_rig.tscn"
)
const EXPECTED_ASSERTIONS := 39
const COMMON_AUTHORITY_KEYS := [
	"renderer", "gameplay", "streaming", "save", "network", "physics",
	"world_generation", "terrain_generation", "collision_generation",
	"origin_shift", "weather_clock", "audio",
]

var _assertions := 0
var _failures := PackedStringArray()
var _rig: PlanetaryAtmosphereWorldRig
var _world: PlanetaryWorldDefinition
var _profile: PlanetaryAtmosphereProfile
var _terrain: PlanetaryTerrainProfile
var _current_observation: Dictionary = {}
var _cloud_material: ShaderMaterial
var _cloud_attack_armed := false
var _cloud_attack_mode: StringName = &""
var _cloud_reentry_results: Array[Dictionary] = []
var _root_signal_events: Array[Dictionary] = []
var _probe_root_signal_reentry := false
var _root_signal_reentry_results: Array[Dictionary] = []
var _root_signal_snapshot_committed := false
var _configuration_attack_rig: PlanetaryAtmosphereWorldRig
var _configuration_attack_world: PlanetaryWorldDefinition
var _configuration_attack_profile: PlanetaryAtmosphereProfile
var _configuration_attack_terrain: PlanetaryTerrainProfile
var _configuration_attack_armed := false
var _configuration_attack_mode: StringName = &""
var _configuration_reentry_results: Array[Dictionary] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var host := Node3D.new()
	host.name = "AtmosphereRigTestHost"
	root.add_child(host)
	var first := RIG_SCENE.instantiate() as PlanetaryAtmosphereWorldRig
	var second := RIG_SCENE.instantiate() as PlanetaryAtmosphereWorldRig
	host.add_child(first)
	host.add_child(second)
	await process_frame
	_test_authored_topology(first)
	_test_resource_ownership(first, second)
	await _test_configuration_postflight(host)
	_test_configuration_rejections(first)
	_world = _world_definition()
	_profile = PlanetaryAtmosphereProfile.new()
	_terrain = PlanetaryTerrainProfile.new()
	_rig = first
	_rig.presentation_committed.connect(_on_root_presentation_committed)
	_test_configuration_and_source_detachment(first)
	_test_observation_boundaries(first)
	_test_strict_inputs_and_signal_reentry(first)
	_test_partial_failure_and_exact_retry(first)
	await _test_lifecycle(first, host)
	_test_structured_scene_mutations(first, second)
	_test_detached_reports(first)
	host.queue_free()
	await process_frame
	_finish()


func _test_authored_topology(rig: PlanetaryAtmosphereWorldRig) -> void:
	var audit := rig.audit()
	var topology := audit.topology as Dictionary
	_check(
		rig.name == &"PlanetaryAtmosphereWorldRig"
		and rig.scene_file_path == PlanetaryAtmosphereWorldRig.RIG_SCENE_PATH
		and rig.get_child_count() == 6
		and int(topology.total_node_count) == 7
		and int(topology.expected_total_node_count) == 7,
		"authored rig has the exact root plus six-child seven-node topology"
	)
	_check(
		rig.get_scene_environment() != null
		and rig.get_cloud_shell() != null and rig.get_sun_light() != null
		and rig.get_atmosphere_presentation() != null
		and rig.get_sky_presentation() != null
		and rig.get_cloud_presentation() != null
		and rig.get_sun_presentation() != null,
		"one environment chain, shell, sun, and all four typed adapters are present"
	)
	_check(
		int(topology.world_environment_node_count) == 0
		and int(topology.collision_object_count) == 0
		and int(topology.mesh_instance_count) == 1
		and int(topology.light_count) == 1
		and not rig.is_processing() and not rig.is_physics_processing(),
		"standalone rig installs no WorldEnvironment, collision, or automatic cadence"
	)
	_check(
		not bool(audit.valid)
		and (audit.errors as PackedStringArray) == PackedStringArray([
			"rig_not_configured",
		]),
		"unconfigured rig is structurally green but operationally typed red"
	)


func _test_resource_ownership(
		first: PlanetaryAtmosphereWorldRig,
		second: PlanetaryAtmosphereWorldRig
	) -> void:
	var first_environment := first.get_scene_environment()
	var second_environment := second.get_scene_environment()
	var first_sky := first_environment.sky
	var second_sky := second_environment.sky
	var first_cloud_material := first.get_cloud_material()
	var second_cloud_material := second.get_cloud_material()
	_check(
		first_environment != second_environment
		and first_sky != second_sky
		and first_sky.sky_material != second_sky.sky_material
		and first_cloud_material != second_cloud_material
		and first_environment.resource_local_to_scene
		and first_sky.resource_local_to_scene
		and first_sky.sky_material.resource_local_to_scene
		and first_cloud_material.resource_local_to_scene,
		"two rigs own exclusive mutable Environment, Sky, sky material, and cloud material"
	)
	_check(
		first.get_cloud_shell().mesh == second.get_cloud_shell().mesh
		and first_cloud_material.shader == second_cloud_material.shader
		and not first.get_cloud_shell().mesh.resource_local_to_scene
		and not first_cloud_material.shader.resource_local_to_scene,
		"two rigs share exactly the immutable cloud mesh and shader"
	)
	var mesh := first.get_cloud_shell().mesh as SphereMesh
	_check(
		mesh.radius == 1.0 and mesh.height == 2.0
		and mesh.radial_segments == 64 and mesh.rings == 32
		and mesh.get_surface_count() == 1
		and first.get_cloud_material().shader.get_mode() == Shader.MODE_SPATIAL,
		"shared shell recipe is a bounded one-surface unit sphere with spatial shader"
	)
	var light := first.get_sun_light()
	_check(
		light.transform.is_equal_approx(
			PlanetaryAtmosphereWorldRig.AUTHORED_LIGHT_TRANSFORM
		)
		and light.light_color.is_equal_approx(
			PlanetaryAtmosphereWorldRig.AUTHORED_LIGHT_COLOR
		)
		and is_equal_approx(
			light.light_energy, PlanetaryAtmosphereWorldRig.AUTHORED_LIGHT_ENERGY
		)
		and not light.shadow_enabled
		and (-light.transform.basis.z).is_equal_approx(Vector3.DOWN),
		"one authored fixed sun has exact baseline, emitted direction, and no shadows"
	)


func _test_configuration_rejections(rig: PlanetaryAtmosphereWorldRig) -> void:
	var world := _world_definition()
	var profile := PlanetaryAtmosphereProfile.new()
	var terrain := PlanetaryTerrainProfile.new()
	var airless := _world_definition()
	airless.has_atmosphere = false
	airless.atmosphere_definition_id = &""
	var mismatched := PlanetaryAtmosphereProfile.new()
	mismatched.profile_id = &"wrong_atmosphere"
	var before := rig.get_snapshot()
	_check(
		rig.configure(null, profile, terrain).reason == &"missing_world_definition"
		and rig.configure(world, null, terrain).reason == &"missing_atmosphere_profile"
		and rig.configure(world, profile, null).reason == &"missing_terrain_profile"
		and rig.configure(airless, profile, terrain).reason
		== &"invalid_atmospheric_composition"
		and rig.configure(world, mismatched, terrain).reason
		== &"invalid_atmospheric_composition"
		and rig.get_snapshot() == before,
		"missing, airless, and mismatched compositions reject without rig mutation"
	)


func _test_configuration_postflight(host: Node3D) -> void:
	var rig := RIG_SCENE.instantiate() as PlanetaryAtmosphereWorldRig
	host.add_child(rig)
	await process_frame
	_configuration_attack_rig = rig
	_configuration_attack_world = _world_definition()
	_configuration_attack_profile = PlanetaryAtmosphereProfile.new()
	_configuration_attack_terrain = PlanetaryTerrainProfile.new()
	_configuration_reentry_results.clear()
	_configuration_attack_mode = &"mutate_sun_transform"
	rig.get_cloud_presentation().presentation_committed.connect(
		_on_configuration_child_committed
	)
	_configuration_attack_armed = true
	var result := rig.configure(
		_configuration_attack_world,
		_configuration_attack_profile,
		_configuration_attack_terrain,
	)
	var snapshot := rig.get_snapshot()
	_check(
		not bool(result.accepted)
		and result.reason == &"partial_configuration_failure"
		and result.failed_adapter_id == &"rig_postflight"
		and (result.configured_adapter_ids as PackedStringArray)
		== PackedStringArray(["atmosphere", "sky", "cloud"])
		and (result.unattempted_adapter_ids as PackedStringArray)
		== PackedStringArray(["sun"])
		and (result.scene_errors as PackedStringArray).has(
			"authored_sun_contract_drift"
		)
		and bool(snapshot.terminal_configuration_failure)
		and int(snapshot.generation) == 0 and int(snapshot.revision) == 0
		and _all_reason(_configuration_reentry_results, &"reentrant_call")
		and not bool(rig.audit().valid),
		"child configuration callback drift is terminally caught before aggregate commit"
	)
	_configuration_attack_rig = null
	_configuration_attack_world = null
	_configuration_attack_profile = null
	_configuration_attack_terrain = null
	rig.queue_free()
	await process_frame

	var composition_rig := RIG_SCENE.instantiate() as PlanetaryAtmosphereWorldRig
	host.add_child(composition_rig)
	await process_frame
	_configuration_attack_rig = composition_rig
	_configuration_attack_world = _world_definition()
	_configuration_attack_profile = PlanetaryAtmosphereProfile.new()
	_configuration_attack_terrain = PlanetaryTerrainProfile.new()
	_configuration_reentry_results.clear()
	_configuration_attack_mode = &"mutate_profile_identity"
	composition_rig.get_atmosphere_presentation().presentation_committed.connect(
		_on_configuration_child_committed
	)
	_configuration_attack_armed = true
	var composition_result := composition_rig.configure(
		_configuration_attack_world,
		_configuration_attack_profile,
		_configuration_attack_terrain,
	)
	_check(
		not bool(composition_result.accepted)
		and composition_result.reason == &"partial_configuration_failure"
		and composition_result.failed_adapter_id == &"rig_postflight"
		and (composition_result.configured_adapter_ids as PackedStringArray)
		== PackedStringArray(["atmosphere"])
		and (composition_result.unattempted_adapter_ids as PackedStringArray)
		== PackedStringArray(["sky", "cloud", "sun"])
		and (composition_result.scene_errors as PackedStringArray).has(
			"composition_input_drift"
		)
		and not bool((composition_result.composition as Dictionary).valid)
		and _all_reason(_configuration_reentry_results, &"reentrant_call")
		and bool(composition_rig.get_snapshot().terminal_configuration_failure),
		"child configuration callback source mutation fails composition postflight before a mixed adapter commit"
	)
	_configuration_attack_rig = null
	_configuration_attack_world = null
	_configuration_attack_profile = null
	_configuration_attack_terrain = null
	_configuration_attack_mode = &""
	composition_rig.queue_free()
	await process_frame


func _test_configuration_and_source_detachment(
		rig: PlanetaryAtmosphereWorldRig
	) -> void:
	var configured := rig.configure(_world, _profile, _terrain)
	var snapshot := rig.get_snapshot()
	_check(
		configured.accepted and configured.reason == &"configured"
		and rig.get_generation() == 1 and int(snapshot.revision) == 1
		and bool(snapshot.coherent)
		and snapshot.adapter_generations == {
			"atmosphere": 1, "sky": 1, "cloud": 1, "sun": 1,
		},
		"valid detached composition configures all four adapters at generation one"
	)
	_check(
		rig.get_cloud_shell().scale == Vector3.ONE * 126_000.0
		and rig.get_scene_environment().background_mode == Environment.BG_SKY
		and rig.get_scene_environment().fog_enabled
		and bool(rig.audit().valid),
		"configured body-centred shell uses exact cloud-top radius and green targets"
	)
	var frozen := rig.get_snapshot()
	_world.world_id = &"mutated_world"
	_profile.profile_id = &"mutated_profile"
	_profile.wind_velocity_mps = Vector3(499.0, 0.0, 0.0)
	_terrain.profile_id = &"mutated_terrain"
	_check(
		rig.get_snapshot() == frozen and bool(rig.audit().valid),
		"caller world, atmosphere, and terrain mutation cannot alter frozen composition"
	)
	_check(
		rig.configure(_world, _profile, _terrain).reason == &"already_configured",
		"successful composition is immutable and cannot be reconfigured"
	)


func _test_observation_boundaries(rig: PlanetaryAtmosphereWorldRig) -> void:
	var cloud_base := _observation(3_000.0, 0.0)
	_current_observation = cloud_base.duplicate(true)
	var presented := rig.present_observation(cloud_base, 1)
	var receipts := presented.adapter_receipts as Dictionary
	var atmosphere_sample := (receipts.atmosphere as Dictionary).sample as Dictionary
	var cloud_observation := (receipts.cloud as Dictionary).observation as Dictionary
	_check(
		presented.accepted and presented.reason == &"observation_presented"
		and (presented.accepted_adapter_ids as PackedStringArray)
		== PackedStringArray(["atmosphere", "sky", "cloud", "sun"])
		and rig.get_snapshot().successful_observation_count == 1,
		"one strict body-local observation reaches all adapters in deterministic order"
	)
	var sky_observation := rig.get_sky_presentation().get_state_snapshot().last_observation \
		as Dictionary
	var sun_evaluation := rig.get_sun_presentation().get_state_snapshot().last_evaluation \
		as Dictionary
	_check(
		(sky_observation.inputs as Dictionary).direction_to_sun
		== PlanetaryAtmosphereWorldRig.AUTHORED_BODY_TO_SUN_DIRECTION
		and (sun_evaluation.inputs as Dictionary).normalized_body_to_sun
		== PlanetaryAtmosphereWorldRig.AUTHORED_BODY_TO_SUN_DIRECTION
		and PlanetaryAtmosphereWorldRig.AUTHORED_BODY_TO_SUN_DIRECTION
		== -PlanetaryAtmosphereWorldRig.AUTHORED_EMITTED_LIGHT_DIRECTION,
		"sky and sun policy consume the authenticated inverse emitted-light direction"
	)
	_check(
		is_equal_approx(float(atmosphere_sample.cloud_layer_factor), 0.55)
		and is_equal_approx(
			float(cloud_observation.cloud_observer_layer_factor_unitless), 0.55
		)
		and cloud_observation.cloud_base_radius_m == 123_000.0
		and cloud_observation.cloud_top_radius_m == 126_000.0,
		"cloud base is inclusive and uses exact profile-derived body radii"
	)
	var atmosphere_top := _observation(20_000.0, 1.0)
	_current_observation = atmosphere_top.duplicate(true)
	var vacuum := rig.present_observation(atmosphere_top, 1)
	var vacuum_receipts := vacuum.adapter_receipts as Dictionary
	var vacuum_sample := (vacuum_receipts.atmosphere as Dictionary).sample as Dictionary
	var vacuum_cloud := (vacuum_receipts.cloud as Dictionary).observation as Dictionary
	_check(
		vacuum.accepted and bool(vacuum_sample.vacuum)
		and float(vacuum_sample.density_ratio) == 0.0
		and float(vacuum_cloud.cloud_observer_layer_factor_unitless) == 0.0
		and rig.get_scene_environment().fog_density == 0.0,
		"exact atmosphere top is vacuum with zero cloud membership and fog density"
	)


func _test_strict_inputs_and_signal_reentry(
		rig: PlanetaryAtmosphereWorldRig
	) -> void:
	var before := rig.get_snapshot()
	var invalid := _observation(0.0, 0.0)
	invalid["extra"] = true
	var bad_view := _observation(0.0, 0.0)
	bad_view.view_direction_body_local = Vector3(2.0, 0.0, 0.0)
	var bad_time := _observation(0.0, INF)
	var wind_overflow := _observation(0.0, 100_000.0)
	_check(
		rig.present_observation(invalid, 1).reason == &"invalid_observation_schema"
		and rig.present_observation(bad_view, 1).reason == &"invalid_view_direction"
		and rig.present_observation(bad_time, 1).reason == &"invalid_caller_time"
		and rig.present_observation(wind_overflow, 1).reason
		== &"cloud_wind_offset_out_of_bounds"
		and rig.present_observation(_observation(), 1.0).reason == &"stale_generation"
		and rig.present_observation(_observation(), 2).reason == &"stale_generation"
		and rig.get_snapshot() == before,
		"strict schema, finite bounds, unit direction, and exact generation reject atomically"
	)
	_current_observation = _observation(2_000.0, 2.0)
	_probe_root_signal_reentry = true
	_root_signal_reentry_results.clear()
	var signal_count := _root_signal_events.size()
	var committed := rig.present_observation(_current_observation, 1)
	_probe_root_signal_reentry = false
	_check(
		committed.accepted and _root_signal_events.size() == signal_count + 1
		and _all_reason(_root_signal_reentry_results, &"reentrant_call")
		and _root_signal_snapshot_committed,
		"post-commit root signal sees committed state and rejects configure/present reentry"
	)
	var before_duplicate := rig.get_snapshot()
	var duplicate_signals := _root_signal_events.size()
	var duplicate := rig.present_observation(_current_observation, 1)
	_check(
		duplicate.accepted and duplicate.reason == &"unchanged"
		and rig.get_snapshot() == before_duplicate
		and _root_signal_events.size() == duplicate_signals,
		"exact repeated observation is deterministic and signal-free"
	)


func _test_partial_failure_and_exact_retry(
		rig: PlanetaryAtmosphereWorldRig
	) -> void:
	_cloud_material = rig.get_cloud_material()
	_cloud_material.changed.connect(_on_cloud_material_changed)
	_current_observation = _observation(4_000.0, 3.0)
	var before := rig.get_snapshot()
	var before_signals := _root_signal_events.size()
	var before_parameters := _cloud_parameters(_cloud_material)
	_cloud_reentry_results.clear()
	_cloud_attack_mode = &"overwrite_parameter"
	_cloud_attack_armed = true
	var partial := rig.present_observation(_current_observation, 1)
	var after := rig.get_snapshot()
	_check(
		not bool(partial.accepted)
		and partial.reason == &"partial_presentation_failure"
		and partial.failed_adapter_id == &"cloud"
		and (partial.accepted_adapter_ids as PackedStringArray)
		== PackedStringArray(["atmosphere", "sky"])
		and (partial.unattempted_adapter_ids as PackedStringArray)
		== PackedStringArray(["sun"])
		and _all_reason(_cloud_reentry_results, &"reentrant_call"),
		"real cloud Resource callback yields typed accepted-prefix partial failure"
	)
	_check(
		int(after.revision) == int(before.revision)
		and int(after.successful_observation_count)
		== int(before.successful_observation_count)
		and int(after.partial_failure_count) == int(before.partial_failure_count) + 1
		and not bool(after.coherent)
		and after.pending_observation == partial.pending_observation
		and _cloud_parameters(_cloud_material) == before_parameters
		and _root_signal_events.size() == before_signals
		and not bool(rig.audit().valid),
		"partial failure rolls its child target back and advances only explicit failure telemetry"
	)
	var different := _observation(4_001.0, 3.0)
	var pending_before := rig.get_snapshot()
	_check(
		rig.present_observation(different, 1).reason
		== &"pending_observation_mismatch"
		and rig.get_snapshot() == pending_before,
		"pending partial state accepts only the exact same observation for repair"
	)
	var repaired := rig.present_observation(_current_observation, 1)
	_check(
		repaired.accepted and repaired.reason == &"observation_presented"
		and (repaired.committed_adapter_ids as PackedStringArray)
		== PackedStringArray(["cloud", "sun"])
		and bool(rig.get_snapshot().coherent)
		and (rig.get_snapshot().pending_observation as Dictionary).is_empty()
		and bool(rig.audit().valid)
		and _root_signal_events.size() == before_signals + 1,
		"exact retry lets unchanged prefix and remaining adapters converge without rollback fiction"
	)

	_current_observation = _observation(5_000.0, 4.0)
	var before_postflight := rig.get_snapshot()
	var before_postflight_signals := _root_signal_events.size()
	_cloud_reentry_results.clear()
	_cloud_attack_mode = &"mutate_shell_scale"
	_cloud_attack_armed = true
	var postflight := rig.present_observation(_current_observation, 1)
	_check(
		not bool(postflight.accepted)
		and postflight.reason == &"partial_presentation_failure"
		and postflight.failed_adapter_id == &"rig_postflight"
		and (postflight.accepted_adapter_ids as PackedStringArray)
		== PackedStringArray(["atmosphere", "sky", "cloud"])
		and (postflight.unattempted_adapter_ids as PackedStringArray)
		== PackedStringArray(["sun"])
		and (postflight.scene_errors as PackedStringArray).has(
			"cloud_shell_scale_drift"
		)
		and int(rig.get_snapshot().revision) == int(before_postflight.revision)
		and int(rig.get_snapshot().successful_observation_count)
		== int(before_postflight.successful_observation_count)
		and _root_signal_events.size() == before_postflight_signals
		and _all_reason(_cloud_reentry_results, &"reentrant_call"),
		"Resource callback shell drift fails postflight with no aggregate success"
	)
	rig.get_cloud_shell().scale = Vector3.ONE * 126_000.0
	var postflight_repair := rig.present_observation(_current_observation, 1)
	_check(
		postflight_repair.accepted
		and (postflight_repair.committed_adapter_ids as PackedStringArray)
		== PackedStringArray(["sun"])
		and bool(rig.audit().valid)
		and _root_signal_events.size() == before_postflight_signals + 1,
		"exact retry after composition repair converges only the unattempted suffix"
	)


func _test_lifecycle(
		rig: PlanetaryAtmosphereWorldRig,
		host: Node3D
	) -> void:
	var before := rig.get_snapshot()
	var signal_count := _root_signal_events.size()
	host.remove_child(rig)
	await process_frame
	_check(
		not rig.is_inside_tree() and _all_adapters_at_baseline(rig)
		and rig.get_snapshot() == before
		and _root_signal_events.size() == signal_count,
		"whole-rig detach restores all four exact baselines without state or signal churn"
	)
	host.add_child(rig)
	await process_frame
	_check(
		rig.is_inside_tree() and _all_adapters_at_expected(rig)
		and rig.get_snapshot() == before
		and _root_signal_events.size() == signal_count
		and bool(rig.audit().valid),
		"whole-rig re-entry reapplies retained generation across all four adapters"
	)


func _test_structured_scene_mutations(
		first: PlanetaryAtmosphereWorldRig,
		second: PlanetaryAtmosphereWorldRig
	) -> void:
	var shell := first.get_cloud_shell()
	var parent := first.get_parent() as Node3D
	first.rotation = Vector3(0.0, 0.1, 0.0)
	var root_rotation_red := (first.audit().errors as PackedStringArray).has(
		"body_local_ancestor_basis_drift"
	)
	first.rotation = Vector3.ZERO
	parent.rotation = Vector3(0.0, 0.1, 0.0)
	var ancestor_rotation_red := (first.audit().errors as PackedStringArray).has(
		"body_local_ancestor_basis_drift"
	)
	parent.rotation = Vector3.ZERO
	parent.scale = Vector3(1.5, 1.5, 1.5)
	var ancestor_scale_red := (first.audit().errors as PackedStringArray).has(
		"body_local_ancestor_basis_drift"
	)
	parent.scale = Vector3.ONE
	parent.position = Vector3(123.0, -456.0, 789.0)
	var translation_green := bool(first.audit().valid)
	parent.position = Vector3.ZERO
	_check(
		root_rotation_red and ancestor_rotation_red and ancestor_scale_red
		and translation_green and first.global_transform.basis == Basis.IDENTITY,
		"identity global basis and every ancestor rotation/scale are required; translation-only rebase stays green"
	)
	var original_environment := first.scene_environment
	first.scene_environment = original_environment.duplicate(true) as Environment
	var environment_red := not bool(first.audit().valid)
	first.scene_environment = original_environment
	var original_sky := original_environment.sky
	original_environment.sky = original_sky.duplicate(true) as Sky
	var sky_red := not bool(first.audit().valid)
	original_environment.sky = original_sky
	var original_material := first.get_cloud_material()
	shell.material_override = original_material.duplicate(true)
	var material_red := not bool(first.audit().valid)
	shell.material_override = original_material
	_check(
		environment_red and sky_red and material_red and bool(first.audit().valid),
		"same-recipe Environment, Sky, and cloud-material replacements are identity reds"
	)
	var original_mesh := shell.mesh
	var replacement := SphereMesh.new()
	replacement.radius = 1.0
	replacement.height = 2.0
	replacement.radial_segments = 64
	replacement.rings = 32
	shell.mesh = replacement
	_check(
		not bool(first.audit().valid)
		and (first.audit().errors as PackedStringArray).has(
			"renderer_resource_contract_drift"
		),
		"same-recipe private mesh replacement is structured red by authored identity"
	)
	shell.mesh = original_mesh
	var shader := first.get_cloud_material().shader
	var source := shader.code
	var schema_variants := [
		source.replace(
			"uniform float cloud_coverage_unitless : hint_range(0.0, 1.0) = 0.0;",
			"uniform vec3 cloud_coverage_unitless = vec3(0.0);"
		).replace(
			"1.0 - cloud_coverage_unitless",
			"1.0 - cloud_coverage_unitless.x"
		),
		source.replace("cloud_top_radius_m", "renamed_cloud_top_radius_m"),
		source.replace("varying vec3 body_direction;", "uniform float extra_uniform = 0.0;\nvarying vec3 body_direction;"),
	]
	var all_schema_red := true
	for variant: String in schema_variants:
		var candidate := Shader.new()
		candidate.code = variant
		all_schema_red = all_schema_red and not _cloud_uniform_contract_matches(candidate)
	_check(
		all_schema_red,
		"missing, mistyped, and extra cloud shader uniforms fail the exact reflected contract"
	)
	_check(
		bool(first.audit().valid)
		and (second.audit().errors as PackedStringArray)
		== PackedStringArray(["rig_not_configured"]),
		"schema probes do not mutate the live shared shader identity or either scene contract"
	)


func _test_detached_reports(rig: PlanetaryAtmosphereWorldRig) -> void:
	var snapshot := rig.get_snapshot()
	var audit := rig.audit()
	(snapshot.world as Dictionary).clear()
	(snapshot.targets as Dictionary)["cloud_mesh_instance_id"] = -1
	(audit.capabilities as Dictionary)["cross_adapter_atomicity"] = true
	(audit.authority as Dictionary)["gameplay"] = true
	var fresh := rig.get_snapshot()
	var fresh_audit := rig.audit()
	_check(
		not (fresh.world as Dictionary).is_empty()
		and int((fresh.targets as Dictionary).cloud_mesh_instance_id) > 0
		and not bool((fresh_audit.capabilities as Dictionary).cross_adapter_atomicity)
		and not bool((fresh_audit.authority as Dictionary).gameplay),
		"nested snapshots, targets, capabilities, and authority are deeply detached"
	)
	_check(
		_exact_authority(fresh_audit.authority, COMMON_AUTHORITY_KEYS, &"renderer")
		and (fresh_audit.evidence as Dictionary) == {
			"content_class": &"NEW",
			"status": &"modern_interpretation",
			"source_bounded": false,
			"confidence": &"none",
		}
		and not bool(fresh_audit.cross_adapter_atomicity),
		"audit freezes exact renderer-only authority, evidence, and non-atomic contract"
	)
	_check(
		int((fresh_audit.topology as Dictionary).total_node_count) == 7
		and int((fresh_audit.performance as Dictionary).mesh_instance_count) == 1
		and int((fresh_audit.performance as Dictionary).mesh_surface_count) == 1
		and int((fresh_audit.performance as Dictionary).directional_light_count) == 1
		and int((fresh_audit.performance as Dictionary).shadow_casting_light_count) == 0
		and int((fresh_audit.performance as Dictionary).collision_object_count) == 0
		and int((fresh_audit.performance as Dictionary).process_loop_count) == 0,
		"audit freezes exact seven-node, one-surface, one-light, zero-authority census"
	)
	_check(
		not _contains_live_object(fresh)
		and not _contains_live_object(fresh_audit),
		"public reports contain no Node, Resource, Callable, or other live capability"
	)


func _on_root_presentation_committed(
		reason: StringName,
		snapshot: Dictionary
	) -> void:
	_root_signal_events.append({"reason": reason, "snapshot": snapshot.duplicate(true)})
	_root_signal_snapshot_committed = snapshot == _rig.get_snapshot()
	if _probe_root_signal_reentry:
		_root_signal_reentry_results = [
			_rig.configure(_world, _profile, _terrain),
			_rig.present_observation(_current_observation, _rig.get_generation()),
		]


func _on_cloud_material_changed() -> void:
	if not _cloud_attack_armed:
		return
	_cloud_attack_armed = false
	_cloud_reentry_results = [
		_rig.configure(_world, _profile, _terrain),
		_rig.present_observation(_current_observation, _rig.get_generation()),
	]
	if _cloud_attack_mode == &"overwrite_parameter":
		_cloud_material.set_shader_parameter(&"cloud_base_radius_m", 777.0)
	elif _cloud_attack_mode == &"mutate_shell_scale":
		_rig.get_cloud_shell().scale = Vector3.ONE


func _on_configuration_child_committed(
		_reason: StringName,
		_snapshot: Dictionary
	) -> void:
	if not _configuration_attack_armed:
		return
	_configuration_attack_armed = false
	_configuration_reentry_results = [
		_configuration_attack_rig.configure(
			_configuration_attack_world,
			_configuration_attack_profile,
			_configuration_attack_terrain,
		),
		_configuration_attack_rig.present_observation(_observation(), 0),
	]
	if _configuration_attack_mode == &"mutate_profile_identity":
		_configuration_attack_profile.profile_id = &"callback_mutated_profile"
	else:
		_configuration_attack_rig.get_sun_light().rotation = Vector3(0.1, 0.0, 0.0)


func _world_definition() -> PlanetaryWorldDefinition:
	var world := PlanetaryWorldDefinition.new()
	world.world_id = &"atmosphere_rig_fixture"
	world.display_name = "Atmosphere Rig Fixture"
	world.sector_id = &"planetary_test_sector"
	world.content_note = "Invented standalone atmosphere-rig composition fixture."
	world.scene_path = PlanetaryAtmosphereWorldRig.RIG_SCENE_PATH
	world.scene_anchor_id = &"atmosphere_rig_scene"
	world.scene_anchor = Transform3D.IDENTITY
	world.navigation_anchor_id = &"atmosphere_rig_navigation"
	world.navigation_anchor = Transform3D(
		Basis.IDENTITY, Vector3(0.0, 130_000.0, 0.0)
	)
	world.orbital_anchor_id = &"atmosphere_rig_orbit"
	world.orbital_anchor = Transform3D(
		Basis.IDENTITY, Vector3(0.0, 140_000.0, 0.0)
	)
	world.surface_anchor_id = &"atmosphere_rig_surface"
	world.surface_anchor = Transform3D(
		Basis.IDENTITY, Vector3(0.0, 120_000.0, 0.0)
	)
	world.body_radius_metres = 120_000.0
	world.has_atmosphere = true
	world.atmosphere_definition_id = &"temperate_game_scale"
	world.terrain_definition_id = &"default_planetary_terrain"
	world.landing_region_ids = PackedStringArray(["atmosphere_rig_landing"])
	world.evidence_status = PlanetaryWorldDefinition.EvidenceStatus.MODERN_INTERPRETATION
	world.evidence_notes = "Invented standalone atmosphere-rig fixture."
	return world


func _observation(
		altitude_m: float = 0.0,
		caller_time_seconds: float = 0.0
	) -> Dictionary:
	return {
		"body_local_observer_m": Vector3.UP * (120_000.0 + altitude_m),
		"view_direction_body_local": Vector3.FORWARD,
		"fog_path_distance_m": 12_000.0,
		"speed_mps": 200.0,
		"weather_scalar": 1.0,
		"cloud_scalar": 1.0,
		"caller_time_seconds": caller_time_seconds,
	}


func _cloud_parameters(material: ShaderMaterial) -> Dictionary:
	var result := {}
	for parameter_name: String in PlanetaryCloudPresentation.OWNED_SHADER_PARAMETERS:
		result[parameter_name] = material.get_shader_parameter(parameter_name)
	return result.duplicate(true)


func _cloud_uniform_contract_matches(shader: Shader) -> bool:
	var actual := {}
	for entry: Dictionary in shader.get_shader_uniform_list():
		actual[str(entry.get("name", ""))] = int(entry.get("type", TYPE_NIL))
	return actual == {
		"cloud_base_radius_m": TYPE_FLOAT,
		"cloud_top_radius_m": TYPE_FLOAT,
		"cloud_coverage_unitless": TYPE_FLOAT,
		"cloud_observer_layer_factor_unitless": TYPE_FLOAT,
		"cloud_wind_velocity_mps": TYPE_VECTOR3,
		"cloud_wind_offset_m": TYPE_VECTOR3,
	}


func _all_adapters_at_baseline(rig: PlanetaryAtmosphereWorldRig) -> bool:
	for adapter: Node in [
		rig.get_atmosphere_presentation(),
		rig.get_sky_presentation(),
		rig.get_cloud_presentation(),
		rig.get_sun_presentation(),
	]:
		var renderer := adapter.call(&"get_renderer_snapshot") as Dictionary
		if renderer.get("actual", {}) != renderer.get("baseline", {}):
			return false
	return true


func _all_adapters_at_expected(rig: PlanetaryAtmosphereWorldRig) -> bool:
	for adapter: Node in [
		rig.get_atmosphere_presentation(),
		rig.get_sky_presentation(),
		rig.get_cloud_presentation(),
		rig.get_sun_presentation(),
	]:
		var renderer := adapter.call(&"get_renderer_snapshot") as Dictionary
		if renderer.get("actual", {}) != renderer.get("expected", {}):
			return false
	return true


func _all_reason(results: Array[Dictionary], reason: StringName) -> bool:
	if results.is_empty():
		return false
	for result: Dictionary in results:
		if result.get("reason", &"") != reason:
			return false
	return true


func _exact_authority(
		value: Variant,
		expected_keys: Array,
		true_key: StringName = &""
	) -> bool:
	if value is not Dictionary:
		return false
	var authority := value as Dictionary
	if authority.size() != expected_keys.size():
		return false
	for key: String in expected_keys:
		if not authority.has(key) or authority[key] is not bool:
			return false
		if bool(authority[key]) != (StringName(key) == true_key):
			return false
	return true


func _contains_live_object(value: Variant) -> bool:
	if value is Object or value is Callable:
		return true
	if value is Dictionary:
		for key: Variant in value:
			if _contains_live_object(key) or _contains_live_object(value[key]):
				return true
	elif value is Array:
		for entry: Variant in value:
			if _contains_live_object(entry):
				return true
	return false


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: %s" % description)
	else:
		_failures.append(description)
		push_error("FAIL: %s" % description)


func _finish() -> void:
	if _assertions != EXPECTED_ASSERTIONS:
		_failures.append(
			"assertion count drifted: expected %d got %d"
			% [EXPECTED_ASSERTIONS, _assertions]
		)
	print("PLANETARY_ATMOSPHERE_WORLD_RIG_ASSERTIONS: %d" % _assertions)
	if _failures.is_empty():
		print("PLANETARY_ATMOSPHERE_WORLD_RIG_TEST_OK")
		quit(0)
	else:
		print(
			"PLANETARY_ATMOSPHERE_WORLD_RIG_TEST_FAILED: %s"
			% ", ".join(_failures)
		)
		quit(1)
