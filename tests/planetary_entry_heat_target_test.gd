extends SceneTree

const TARGET_SCENE := preload(
	"res://scenes/effects/planetary_entry_heat_target.tscn"
)
const ProfileScript := preload(
	"res://scripts/world/definitions/planetary_atmosphere_profile.gd"
)
const EXPECTED_ASSERTIONS := 35
const EXPECTED_BOUNDS := AABB(
	Vector3(-4.0, -2.0, -7.0), Vector3(8.0, 4.0, 14.0)
)
const EXPECTED_EXPANDED := AABB(
	Vector3(-4.25, -2.25, -7.25), Vector3(8.5, 4.5, 14.5)
)
const OWNED_PARAMETER: StringName = &"entry_effect_intensity_unitless"
const COMMON_AUTHORITY_KEYS := [
	"renderer", "gameplay", "streaming", "save", "network", "physics",
	"world_generation", "terrain_generation", "collision_generation",
	"origin_shift", "weather_clock", "audio",
]
const ADJACENT_AUTHORITY_KEYS := [
	"collision", "damage", "movement", "ship_visibility",
	"engine_presentation", "damage_presentation", "gameplay_heat",
	"physics_drag", "weather", "time", "audio", "streaming", "save",
	"network", "visual_quality",
]

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var first := TARGET_SCENE.instantiate() as PlanetaryEntryHeatTarget
	var second := TARGET_SCENE.instantiate() as PlanetaryEntryHeatTarget
	root.add_child(first)
	root.add_child(second)
	await process_frame
	_test_authored_contract(first, second)
	_test_exclusive_material_and_shared_immutable_resources(first, second)
	await _test_audit_mutations(first)
	await _test_adapter_lifecycle(first)
	first.queue_free()
	second.queue_free()
	await process_frame
	_finish()


func _test_authored_contract(
		first: PlanetaryEntryHeatTarget,
		second: PlanetaryEntryHeatTarget
	) -> void:
	var overlay := first.get_overlay()
	var compression := first.get_compression_bow()
	var material := first.get_material()
	var presentation := first.get_presentation()
	var audit := first.audit()
	_check(
		first != null and second != null and bool(audit.valid),
		"real authored target instantiates twice with green contract: %s" % [audit.errors]
	)
	_check(
		first.get_child_count() == 3
		and first.get_node("Overlay") == overlay
		and first.get_node("CompressionBow") == compression
		and first.get_node("Presentation") == presentation,
		"target direct roster is exactly Overlay, CompressionBow, plus Presentation"
	)
	_check(
		first.authored_visual_bounds == EXPECTED_BOUNDS
		and first.overlay_standoff_m == 0.25
		and first.get_expanded_visual_bounds() == EXPECTED_EXPANDED,
		"authored AABB expands by the exact 0.25 metre standoff"
	)
	_check(
		overlay.position == EXPECTED_EXPANDED.get_center()
		and overlay.rotation == Vector3.ZERO
		and overlay.scale == EXPECTED_EXPANDED.size * 0.5,
		"one unit sphere is deterministically scaled to the bounded AABB"
	)
	var sphere := overlay.mesh as SphereMesh
	var compression_ring := compression.mesh as TorusMesh
	_check(
		sphere != null and sphere.radius == 1.0 and sphere.height == 2.0
		and sphere.radial_segments == 32 and sphere.rings == 16
		and sphere.get_surface_count() == 1,
		"immutable overlay mesh has exact one-surface bounded recipe"
	)
	_check(
		overlay.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		and overlay.gi_mode == GeometryInstance3D.GI_MODE_DISABLED
		and overlay.visibility_range_begin == 0.0
		and overlay.visibility_range_end == 0.0
		and compression_ring != null
		and is_equal_approx(compression_ring.inner_radius, 0.82)
		and is_equal_approx(compression_ring.outer_radius, 1.0)
		and compression_ring.rings == 32
		and compression_ring.ring_segments == 12
		and compression.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		and compression.gi_mode == GeometryInstance3D.GI_MODE_DISABLED,
		"overlay and bounded compression bow have no shadows, GI, or hidden distance policy"
	)
	_check(
		material != null and material.resource_local_to_scene
		and material.shader != null
		and material.shader.get_mode() == Shader.MODE_SPATIAL
		and material.get_shader_parameter(OWNED_PARAMETER) == 0.0,
		"exclusive material starts at the exact invisible zero baseline"
	)
	_check(
		audit.nodes.mesh_instance_count == 2
		and audit.nodes.collision_object_count == 0
		and audit.nodes.collision_shape_count == 0
		and audit.nodes.light_count == 0
		and audit.nodes.particle_count == 0
		and audit.nodes.audio_count == 0,
		"target owns two bounded renderers and no collision/light/particle/audio nodes"
	)
	_check(
		not first.is_processing() and not first.is_physics_processing()
		and not first.has_method("_process") and not first.has_method("_physics_process")
		and not presentation.is_processing()
		and not presentation.is_physics_processing(),
		"target and child adapter own no process cadence"
	)


func _test_exclusive_material_and_shared_immutable_resources(
		first: PlanetaryEntryHeatTarget,
		second: PlanetaryEntryHeatTarget
	) -> void:
	var first_overlay := first.get_overlay()
	var second_overlay := second.get_overlay()
	var first_compression := first.get_compression_bow()
	var second_compression := second.get_compression_bow()
	var first_material := first.get_material()
	var second_material := second.get_material()
	_check(
		first_overlay.mesh == second_overlay.mesh
		and first_material.shader == second_material.shader
		and first_compression.mesh != second_compression.mesh
		and first_compression.material_override == first_material
		and second_compression.material_override == second_material,
		"live targets share immutable authored resources while each bounded bow uses its target material"
	)
	_check(
		first_material != second_material
		and first_material.get_instance_id() != second_material.get_instance_id(),
		"each live target receives an exclusive local ShaderMaterial"
	)
	first_material.set_shader_parameter(OWNED_PARAMETER, 0.6)
	_check(
		first_material.get_shader_parameter(OWNED_PARAMETER) == 0.6
		and second_material.get_shader_parameter(OWNED_PARAMETER) == 0.0,
		"one target's intensity cannot mutate another live target"
	)
	first_material.set_shader_parameter(OWNED_PARAMETER, 0.0)
	var audit := first.audit()
	_check(
		audit.performance.renderer_node_count == 2
		and audit.performance.surface_count == 2
		and audit.performance.submission_hint_count == 2
		and audit.performance.live_material_count_per_target == 1
		and audit.performance.live_mesh_resource_count_per_target == 2
		and audit.performance.shared_mesh_resource_count == 1
		and audit.performance.shared_shader_resource_count == 1,
		"allocation/submission audit freezes the bounded Stage-1 target"
	)
	_check(
		audit.capabilities.authored_target_resource_ownership
		and audit.capabilities.exclusive_live_material
		and audit.capabilities.immutable_shared_mesh
		and audit.capabilities.immutable_shared_shader
		and audit.capabilities.high_low_same_target_contract
		and not audit.capabilities.physical_bow_shock
		and audit.capabilities.directional_airflow_shape
		and not audit.capabilities.ship_integration,
		"capabilities state the visual proxy and production deferrals exactly"
	)
	_check(
		audit.authority.renderer
		and audit.authority.size() == COMMON_AUTHORITY_KEYS.size()
		and _authority_matches(
			audit.authority, COMMON_AUTHORITY_KEYS, true
		)
		and audit.adjacent_authority.size() == ADJACENT_AUTHORITY_KEYS.size()
		and _authority_matches(
			audit.adjacent_authority, ADJACENT_AUTHORITY_KEYS, false
		),
		"target authority is renderer-only and all adjacent domains are false"
	)
	_check(
		audit.evidence.size() == 4 and audit.evidence == {
			"content_class": &"NEW",
			"status": &"modern_interpretation",
			"source_bounded": false,
			"confidence": &"none",
		},
		"target freezes the exact four-key NEW evidence roster"
	)


func _test_audit_mutations(target: PlanetaryEntryHeatTarget) -> void:
	var overlay := target.get_overlay()
	var material := target.get_material()
	var mesh := overlay.mesh
	var transform_before := overlay.transform
	overlay.position.x += 0.1
	_check(
		not bool(target.audit().valid)
		and target.audit().errors.has("overlay_transform_drift"),
		"overlay transform drift is structured red"
	)
	overlay.transform = transform_before
	var shader := material.shader
	material.shader = null
	_check(
		not bool(target.audit().valid)
		and target.audit().errors.has("entry_shader_contract_invalid"),
		"missing entry shader is structured red"
	)
	material.shader = shader
	var same_recipe_mesh := mesh.duplicate() as SphereMesh
	overlay.mesh = same_recipe_mesh
	_check(
		not bool(target.audit().valid)
		and target.audit().errors.has("overlay_mesh_identity_drift"),
		"private same-recipe mesh replacement is structured red"
	)
	overlay.mesh = mesh
	var same_recipe_material := material.duplicate() as ShaderMaterial
	same_recipe_material.resource_local_to_scene = true
	overlay.material_override = same_recipe_material
	_check(
		not bool(target.audit().valid)
		and target.audit().errors.has("overlay_material_identity_drift"),
		"private same-recipe material replacement is structured red"
	)
	overlay.material_override = material
	var same_schema_shader := Shader.new()
	same_schema_shader.code = shader.code
	material.shader = same_schema_shader
	_check(
		not bool(target.audit().valid)
		and target.audit().errors.has("entry_shader_identity_drift"),
		"same-source shader replacement is structured identity red"
	)
	material.shader = shader
	var shader_code := shader.code
	shader.code = shader_code + "\n// same-schema source drift"
	await process_frame
	_check(
		not bool(target.audit().valid)
		and target.audit().errors.has("entry_shader_source_drift"),
		"same-schema authored shader source mutation is structured red"
	)
	shader.code = shader_code.replace(
		"uniform float entry_heat_fresnel_exponent : hint_range(0.25, 8.0) = 2.4;\n",
		""
	).replace("entry_heat_fresnel_exponent);", "2.4);")
	await process_frame
	_check(
		not bool(target.audit().valid)
		and target.audit().errors.has("entry_shader_schema_drift"),
		"authored shader schema mutation is structured red"
	)
	shader.code = shader_code
	await process_frame
	material.set_shader_parameter(&"entry_heat_max_alpha", 0.5)
	_check(
		not bool(target.audit().valid)
		and target.audit().errors.has("entry_display_parameter_drift"),
		"authored non-owned display-uniform mutation is structured red"
	)
	material.set_shader_parameter(&"entry_heat_max_alpha", 0.62)
	material.set_shader_parameter(OWNED_PARAMETER, 1.1)
	_check(
		not bool(target.audit().valid)
		and target.audit().errors.has("entry_intensity_out_of_bounds"),
		"out-of-bounds entry intensity is structured red"
	)
	material.set_shader_parameter(OWNED_PARAMETER, 0.0)
	var collision := CollisionShape3D.new()
	target.add_child(collision)
	_check(
		not bool(target.audit().valid)
		and target.audit().errors.has("forbidden_authority_node_present"),
		"added collision authority is structured red"
	)
	target.remove_child(collision)
	collision.queue_free()
	_check(
		bool(target.audit().valid)
		and overlay.mesh == mesh and overlay.material_override == material
		and material.shader == shader and shader.code == shader_code,
		"restoring exact authored resource identities/values returns audit green"
	)
	var report := target.audit()
	report.nodes.clear()
	report.evidence.clear()
	_check(
		not target.audit().nodes.is_empty()
		and target.audit().evidence.size() == 4
		and not _contains_object(target.audit()),
		"target reports are deeply detached and carry no live Object"
	)


func _test_adapter_lifecycle(target: PlanetaryEntryHeatTarget) -> void:
	var presentation := target.get_presentation()
	var material := target.get_material()
	var compression := target.get_compression_bow()
	var profile := ProfileScript.new() as PlanetaryAtmosphereProfile
	var configured := presentation.configure(profile, material)
	var full := presentation.present_observation(10000.0, 340.0, 1)
	_check(
		configured.accepted and full.accepted
		and material.get_shader_parameter(OWNED_PARAMETER) == 1.0
		and bool(target.audit().valid),
		"real target composes with adapter at full sampler intensity"
	)
	var midpoint := presentation.present_observation(14000.0, 250.0, 1)
	_check(
		midpoint.accepted
		and is_equal_approx(material.get_shader_parameter(OWNED_PARAMETER), 0.25)
		and compression.material_override == material,
		"one resolved intensity continuously drives both hull heat and compression bow"
	)
	presentation.present_observation(10000.0, 340.0, 1)
	var generation := presentation.get_generation()
	var revision: int = int(presentation.get_state_snapshot().revision)
	root.remove_child(target)
	_check(
		material.get_shader_parameter(OWNED_PARAMETER) == 0.0
		and compression.material_override == material
		and presentation.get_generation() == generation
		and presentation.get_state_snapshot().revision == revision,
		"whole-target exit restores zero without changing identity"
	)
	var detached_state := presentation.get_state_snapshot()
	var detached_reset := presentation.reset_for_reuse(generation)
	_check(
		not bool(detached_reset.accepted)
			and detached_reset.reason == &"presentation_detached"
			and presentation.get_state_snapshot() == detached_state
			and material.get_shader_parameter(OWNED_PARAMETER) == 0.0,
		"a detached reset rejects before generation, retained observation, revision, or material mutation"
	)
	root.add_child(target)
	await process_frame
	_check(
		material.get_shader_parameter(OWNED_PARAMETER) == 1.0
		and compression.material_override == material
		and presentation.get_generation() == generation
		and presentation.get_state_snapshot().revision == revision
		and bool(target.audit().valid),
		"whole-target reentry reapplies retained intensity without duplication"
	)
	var live_reset := presentation.reset_for_reuse(generation)
	var reset_generation := presentation.get_generation()
	var live_represented := presentation.present_observation(
		10000.0, 340.0, reset_generation
	)
	_check(
		bool(live_reset.accepted)
			and live_reset.reason == &"reset"
			and reset_generation == generation + 1
			and bool(live_represented.accepted)
			and material.get_shader_parameter(OWNED_PARAMETER) == 1.0,
		"a current re-entered target still accepts reset and a fresh generation observation"
	)
	var queued_state := presentation.get_state_snapshot()
	var queued_material: Variant = material.get_shader_parameter(OWNED_PARAMETER)
	presentation.queue_free()
	var queued_reset := presentation.reset_for_reuse(reset_generation)
	_check(
		presentation.is_inside_tree()
			and presentation.is_queued_for_deletion()
			and not bool(queued_reset.accepted)
			and queued_reset.reason == &"presentation_detached"
			and presentation.get_state_snapshot() == queued_state
			and material.get_shader_parameter(OWNED_PARAMETER) == queued_material,
		"a queued reset rejects before generation, retained observation, revision, or material mutation"
	)


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
		print("PLANETARY_ENTRY_HEAT_TARGET_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error("PLANETARY_ENTRY_HEAT_TARGET_TEST_FAIL: %s" % failure)
	quit(1)
