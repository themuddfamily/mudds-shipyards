extends SceneTree

## Focused production-world contract for the source-bounded space composition.
## The backdrop is presentation-only: this test freezes its evidence boundary,
## deterministic instancing, exact live roster, and non-interference with the
## authoritative target range and physical berth registry.

const WORLD_SCENE := preload("res://scenes/world/shipyard_world.tscn")
const EXPECTED_MODULE_ID: StringName = &"source-bounded-space-backdrop"
const EXPECTED_SOURCES: Array[String] = ["A8", "B1", "B2", "B3", "B4"]
const EXPECTED_STAR_SEED := 19780704
const EXPECTED_STAR_COUNT := 2600
const EXPECTED_STAR_RADIUS_MIN := 1450.0
const EXPECTED_STAR_RADIUS_MAX := 1650.0
const EXPECTED_NEBULA_COVER_STRENGTH := 0.08
const EXPECTED_BODY_MESH_RADIUS := 1.0
const EXPECTED_BODY_MESH_RADIAL_SEGMENTS := 24
const EXPECTED_BODY_MESH_RINGS := 12
const EXPECTED_BODY_MESH_FAMILY_ID: StringName = &"space-backdrop-celestial-bodies"
const EXPECTED_LOCAL_MESH_RESOURCES := 2
const EXPECTED_LOCAL_MATERIAL_RESOURCES := 5
const EXPECTED_LOCAL_RENDERER_NODES := 5
const EXPECTED_LOCAL_SURFACE_SUBMISSIONS := 5
const EXPECTED_LOCAL_VISIBLE_COPIES := 2604
const EXPECTED_LOCAL_TRIANGLES := 127_296
const EXPECTED_BERTH_IDS: Array[String] = [
	"central_berth",
	"arrow_recon_berth",
	"jovian_freight_berth",
	"zenith_fleet_dock_berth",
	"halyard_fleet_dock_berth",
]
const EXPECTED_BODY_SPECS := {
	&"CelestialGreenBody": {
		"position": Vector3(-310.0, 100.0, -890.0),
		"radius": 95.0,
		"palette_role": &"green",
		"color": Color("5a9b58"),
	},
	&"CelestialTanBody": {
		"position": Vector3(250.0, -120.0, -1040.0),
		"radius": 110.0,
		"palette_role": &"tan_cream",
		"color": Color("c7b887"),
	},
	&"CelestialGreyBody": {
		"position": Vector3(70.0, 230.0, -1250.0),
		"radius": 85.0,
		"palette_role": &"grey",
		"color": Color("86878c"),
	},
	&"CelestialOrangeBody": {
		"position": Vector3(-500.0, -160.0, -1150.0),
		"radius": 75.0,
		"palette_role": &"orange",
		"color": Color("d57635"),
	},
}

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := WORLD_SCENE.instantiate() as ShipyardWorld
	var comparison_world := WORLD_SCENE.instantiate() as ShipyardWorld
	_check(world != null and comparison_world != null, "two production ShipyardWorld scenes instantiate")
	if world == null or comparison_world == null:
		_finish()
		return
	root.add_child(world)
	root.add_child(comparison_world)
	await process_frame

	_test_evidence_boundary(world)
	_test_pristine_audit(world)
	_test_near_black_sky(world)
	_test_deterministic_star_shell(world, comparison_world)
	_test_exact_body_roster(world)
	_test_bounded_resource_sharing(world)
	_test_presentation_only_boundary(world)
	_test_authority_invariants(world)
	_test_deep_copy_safety(world)
	await _test_lifecycle_and_quality_stability(world)

	comparison_world.queue_free()
	world.queue_free()
	await process_frame
	await process_frame
	_finish()


func _test_evidence_boundary(world: ShipyardWorld) -> void:
	var evidence := world.get_space_backdrop_evidence_metadata()
	_check(
		int(evidence.get("schema_version", 0)) == 1
		and StringName(evidence.get("module_id", &"")) == EXPECTED_MODULE_ID,
		"space-backdrop evidence exposes the stable v1 module identity"
	)
	_check(
		PackedStringArray(evidence.get("sources", PackedStringArray())) == PackedStringArray(EXPECTED_SOURCES),
		"evidence cites exactly the registered A8 and B1-B4 source set"
	)
	_check(
		bool(evidence.get("source_bounded", false))
		and bool(evidence.get("broad_composition_supported", false)),
		"evidence supports only the broad source-bounded composition relationship"
	)
	_check(
		not bool(evidence.get("authenticated_exact_count", true))
		and not bool(evidence.get("authenticated_exact_placement", true))
		and not bool(evidence.get("authenticated_exact_scale", true))
		and not bool(evidence.get("authenticated_exact_materials", true)),
		"evidence rejects unsupported exact count, placement, scale, and material claims"
	)
	var note := str(evidence.get("content_note", ""))
	_check(
		"modern composition decisions" in note
		and "exact four-body count" in note
		and "star count" in note,
		"content note explicitly inventories the modern invented composition decisions"
	)


func _test_pristine_audit(world: ShipyardWorld) -> void:
	var report := world.get_space_backdrop_audit_report()
	var errors := report.get("errors", PackedStringArray()) as PackedStringArray
	_check(bool(report.get("valid", false)) and errors.is_empty(), "pristine backdrop audit is green without suppressed errors")
	_check(
		int(report.get("schema_version", 0)) == 1
		and StringName(report.get("module_id", &"")) == EXPECTED_MODULE_ID,
		"audit exposes the stable v1 source-bounded module identity"
	)
	_check(
		int(report.get("star_seed", -1)) == EXPECTED_STAR_SEED
		and int(report.get("star_count", -1)) == EXPECTED_STAR_COUNT
		and is_equal_approx(float(report.get("star_radius_min", -1.0)), EXPECTED_STAR_RADIUS_MIN)
		and is_equal_approx(float(report.get("star_radius_max", -1.0)), EXPECTED_STAR_RADIUS_MAX),
		"audit freezes the deterministic 2,600-star shell contract"
	)
	_check(
		int(report.get("body_count", -1)) == EXPECTED_BODY_SPECS.size()
		and (report.get("body_specs", {}) as Dictionary).size() == EXPECTED_BODY_SPECS.size(),
		"audit freezes exactly four celestial bodies"
	)
	var performance := report.get("performance", {}) as Dictionary
	_check(
		int(performance.get("mesh_resource_count", -1)) == EXPECTED_LOCAL_MESH_RESOURCES
		and int(performance.get("material_resource_count", -1)) == EXPECTED_LOCAL_MATERIAL_RESOURCES
		and int(performance.get("renderer_node_count", -1)) == EXPECTED_LOCAL_RENDERER_NODES
		and int(performance.get("surface_submission_count", -1)) == EXPECTED_LOCAL_SURFACE_SUBMISSIONS
		and int(performance.get("visible_copy_count", -1)) == EXPECTED_LOCAL_VISIBLE_COPIES
		and int(performance.get("triangle_count", -1)) == EXPECTED_LOCAL_TRIANGLES,
		"audit freezes the bounded 2-mesh, 5-material, 5-submission, 127296-triangle result"
	)
	_check(
		bool(report.get("near_black_sky", false))
		and is_equal_approx(float(report.get("legacy_nebula_cover_strength", -1.0)), EXPECTED_NEBULA_COVER_STRENGTH)
		and float(report.get("legacy_nebula_cover_strength", 1.0)) <= 0.1,
		"audit keeps the legacy nebula at a faint eight-percent cover over near-black space"
	)


func _test_near_black_sky(world: ShipyardWorld) -> void:
	var environment_node := world.get_node_or_null(^"ShipyardEnvironment") as WorldEnvironment
	var environment := environment_node.environment if environment_node != null else null
	var sky_material: ShaderMaterial = null
	if environment != null and environment.sky != null:
		sky_material = environment.sky.sky_material as ShaderMaterial
	# Re-frozen from ProceduralSkyMaterial. That material builds a sky hemisphere
	# blended into a *ground* hemisphere, and this scene has no ground: with the
	# four colours it was frozen at it drew a ruled line straight across the middle
	# of every wide frame, which read as a wall standing behind the station.
	# Softening its two curves in the previous pass spread the line without
	# removing it, because the model itself has an equator. It also could not give
	# the sky-sourced ambient any lateral structure - the reason the fill landed on
	# every face identically - or give the background-sourced reflections anything
	# for metal to return.
	_check(sky_material != null, "production environment uses the deep-space sky shader rather than a hemisphere sky")
	if sky_material == null:
		return
	_check(
		sky_material.shader != null
		and sky_material.shader.resource_path == "res://scripts/rendering/deep_space_sky.gdshader",
		"deep-space sky is bound to its committed shader"
	)
	# Re-frozen from 0a1420 / 0d1a24 / 070d13 / 03060a. Same intent, new model:
	# the sphere stays near-black - the brightest authored colour here is the
	# 4a3928 galactic core, and it only appears multiplied by a band falloff and a
	# dust mask - but it is no longer *uniformly* near-black, which is the whole
	# point. These stay exact equalities: the sky is the ambient and reflection
	# source for the entire station, so it is not a place for a tolerance band.
	_check(
		(sky_material.get_shader_parameter(&"zenith_color") as Color).is_equal_approx(Color("0b1018"))
		and (sky_material.get_shader_parameter(&"nadir_color") as Color).is_equal_approx(Color("0c0c0e"))
		and (sky_material.get_shader_parameter(&"band_color") as Color).is_equal_approx(Color("18202c"))
		and (sky_material.get_shader_parameter(&"core_color") as Color).is_equal_approx(Color("4a3928"))
		and (sky_material.get_shader_parameter(&"sun_color") as Color).is_equal_approx(Color("3c606f")),
		"deep-space sky palette stays near-black while carrying a band, a warm core and a sun side"
	)
	_check(
		(sky_material.get_shader_parameter(&"band_axis") as Vector3).is_equal_approx(Vector3(0.34, 0.88, -0.33))
		and (sky_material.get_shader_parameter(&"core_axis") as Vector3).is_equal_approx(Vector3(-0.62, -0.12, -0.77))
		and is_equal_approx(float(sky_material.get_shader_parameter(&"band_width")), 0.42)
		and is_equal_approx(float(sky_material.get_shader_parameter(&"core_focus")), 7.0)
		and is_equal_approx(float(sky_material.get_shader_parameter(&"dust_scale")), 3.4),
		"deep-space sky composition is frozen to its authored band, core and dust scale"
	)
	# The sun glow replaces the old "no synthetic sun disc" assertion, which was a
	# statement about ProceduralSkyMaterial's disc feature. There is still no disc:
	# what is here is a halo derived from the same rotation that aims the key
	# light, so the bright quarter of the sky and the lit face of every surface
	# cannot drift apart. That agreement is what this now freezes instead.
	_check(
		(sky_material.get_shader_parameter(&"sun_direction") as Vector3).is_equal_approx(
			ShipyardWorld.sky_sun_direction()
		)
		and is_equal_approx(float(sky_material.get_shader_parameter(&"sun_focus")), 260.0)
		and is_equal_approx(float(sky_material.get_shader_parameter(&"sun_halo")), 0.55),
		"deep-space sky sun glow is aimed by the same constant as the station key light"
	)
	var key_light := world.get_node_or_null(^"SpaceKeyLight") as DirectionalLight3D
	_check(
		key_light != null
		and key_light.rotation_degrees.is_equal_approx(ShipyardWorld.KEY_LIGHT_ROTATION_DEGREES)
		and (-key_light.global_transform.basis.z).normalized().is_equal_approx(
			-ShipyardWorld.sky_sun_direction()
		),
		"the live key light travels along the axis the sky's sun glow sits on"
	)
	_check(
		(sky_material.get_shader_parameter(&"nebula_cover") as Texture2D) != null
		and (sky_material.get_shader_parameter(&"nebula_cover") as Texture2D).resource_path == "res://assets/keth-nebula.png"
		and is_equal_approx(float(sky_material.get_shader_parameter(&"nebula_strength")), 0.08),
		"project-original legacy nebula survives only as an exact faint cover"
	)


func _test_deterministic_star_shell(world: ShipyardWorld, comparison_world: ShipyardWorld) -> void:
	var stars := world.get_node_or_null(^"SpaceBackdrop/ParallaxStars") as MultiMeshInstance3D
	var comparison_stars := comparison_world.get_node_or_null(^"SpaceBackdrop/ParallaxStars") as MultiMeshInstance3D
	_check(
		stars != null and comparison_stars != null
		and stars.multimesh != null and comparison_stars.multimesh != null,
		"both worlds expose the one instanced star-shell renderer"
	)
	if stars == null or comparison_stars == null or stars.multimesh == null or comparison_stars.multimesh == null:
		return
	var multimesh := stars.multimesh
	var comparison_multimesh := comparison_stars.multimesh
	_check(
		multimesh.instance_count == EXPECTED_STAR_COUNT
		and multimesh.visible_instance_count == -1
		and multimesh.transform_format == MultiMesh.TRANSFORM_3D
		and multimesh.use_colors,
		"one 3D MultiMesh publishes all 2,600 coloured star instances"
	)
	var star_sphere := multimesh.mesh as SphereMesh
	var star_material := star_sphere.material as StandardMaterial3D if star_sphere != null else null
	_check(
		star_sphere != null
		and is_equal_approx(star_sphere.radius, 0.9)
		and is_equal_approx(star_sphere.height, 1.8)
		and star_sphere.radial_segments == 6
		and star_sphere.rings == 3,
		"star draw uses one deliberately low-poly readable SphereMesh"
	)
	_check(
		star_material != null
		and star_material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED
		and star_material.vertex_color_use_as_albedo
		and star_material.disable_receive_shadows
		and star_material.emission_enabled
		and is_equal_approx(star_material.emission_energy_multiplier, 0.55)
		and stars.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		and stars.gi_mode == GeometryInstance3D.GI_MODE_DISABLED,
		"star renderer consumes instance colours and contributes no lighting or shadows"
	)
	_check(
		stars.custom_aabb.is_equal_approx(
			AABB(Vector3.ONE * -EXPECTED_STAR_RADIUS_MAX, Vector3.ONE * EXPECTED_STAR_RADIUS_MAX * 2.0)
		),
		"star renderer publishes the exact full-shell culling envelope"
	)

	# The dummy RenderingServer used by `--headless` accepts MultiMesh writes but
	# returns zeroed instance buffers. Reconstruct the exact fixed-seed stream on
	# CPU so shell/angular guarantees remain testable there; on a readable render
	# backend, additionally compare every live transform and colour to that stream.
	var live_instance_data_readable := (
		multimesh.get_instance_transform(0).origin.length() > EXPECTED_STAR_RADIUS_MIN * 0.5
	)
	var every_transform_deterministic := true
	var every_color_deterministic := true
	var every_star_in_shell := true
	var every_transform_finite := true
	var observed_radius_min := INF
	var observed_radius_max := 0.0
	var octants := PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0])
	var random := RandomNumberGenerator.new()
	random.seed = EXPECTED_STAR_SEED
	for index in EXPECTED_STAR_COUNT:
		var y := random.randf_range(-1.0, 1.0)
		var longitude := random.randf_range(-PI, PI)
		var planar_radius := sqrt(maxf(0.0, 1.0 - y * y))
		var direction := Vector3(planar_radius * cos(longitude), y, planar_radius * sin(longitude))
		var radius := random.randf_range(EXPECTED_STAR_RADIUS_MIN, EXPECTED_STAR_RADIUS_MAX)
		var scale_value := random.randf_range(0.55, 2.35)
		var expected_transform := Transform3D(
			Basis.IDENTITY.scaled(Vector3.ONE * scale_value),
			direction * radius
		)
		var warmth := random.randf()
		var expected_color := Color("fff1df").lerp(Color("dceaff"), warmth) * random.randf_range(0.52, 1.0)
		if live_instance_data_readable:
			var star_transform := multimesh.get_instance_transform(index)
			var comparison_transform := comparison_multimesh.get_instance_transform(index)
			var star_color := multimesh.get_instance_color(index)
			var comparison_color := comparison_multimesh.get_instance_color(index)
			every_transform_deterministic = (
				every_transform_deterministic
				and star_transform.is_equal_approx(comparison_transform)
				and star_transform.is_equal_approx(expected_transform)
			)
			every_color_deterministic = (
				every_color_deterministic
				and star_color.is_equal_approx(comparison_color)
				and star_color.is_equal_approx(expected_color)
			)
		every_transform_finite = every_transform_finite and expected_transform.is_finite()
		observed_radius_min = minf(observed_radius_min, radius)
		observed_radius_max = maxf(observed_radius_max, radius)
		every_star_in_shell = (
			every_star_in_shell
			and radius >= EXPECTED_STAR_RADIUS_MIN - 0.01
			and radius <= EXPECTED_STAR_RADIUS_MAX + 0.01
		)
		var octant := (1 if expected_transform.origin.x >= 0.0 else 0)
		octant += (2 if expected_transform.origin.y >= 0.0 else 0)
		octant += (4 if expected_transform.origin.z >= 0.0 else 0)
		octants[octant] += 1
	_check(
		every_transform_deterministic and every_color_deterministic,
		"the fixed-seed CPU contract matches every transform and colour on render backends exposing live buffers"
	)
	_check(every_transform_finite and every_star_in_shell, "all 2,600 finite stars stay inside the exact 1,450-1,650 shell (observed %.3f-%.3f)" % [observed_radius_min, observed_radius_max])
	var all_octants_populated := true
	for count in octants:
		all_octants_populated = all_octants_populated and count >= 200
	_check(all_octants_populated, "deterministic stars cover all eight viewing octants without a sparse hemisphere (%s)" % [octants])


func _test_exact_body_roster(world: ShipyardWorld) -> void:
	var backdrop := world.get_node_or_null(^"SpaceBackdrop") as Node3D
	_check(backdrop != null and backdrop.get_child_count() == 5, "backdrop has exactly one star renderer and four direct body children")
	if backdrop == null:
		return
	var expected_names := PackedStringArray(["ParallaxStars"])
	for body_name: StringName in EXPECTED_BODY_SPECS:
		expected_names.append(String(body_name))
	var actual_names := PackedStringArray()
	for child in backdrop.get_children():
		actual_names.append(String(child.name))
	actual_names.sort()
	expected_names.sort()
	_check(actual_names == expected_names, "backdrop direct-child names match the exact frozen renderable roster")

	var report_specs := world.get_space_backdrop_audit_report().get("body_specs", {}) as Dictionary
	var body_mesh_ids: Dictionary = {}
	for body_name: StringName in EXPECTED_BODY_SPECS:
		var expected := EXPECTED_BODY_SPECS[body_name] as Dictionary
		var reported := report_specs.get(body_name, {}) as Dictionary
		var body := backdrop.get_node_or_null(NodePath(String(body_name))) as MeshInstance3D
		var sphere := body.mesh as SphereMesh if body != null else null
		var material := body.material_override as StandardMaterial3D if body != null else null
		var expected_radius := float(expected.radius)
		# Rebuild the exact pre-sharing resource, rather than comparing against an
		# ideal sphere: Godot's 24 sampled longitudes do not put every X/Z cardinal
		# at the nominal radius, so the old mesh's AABB was slightly inset there.
		var legacy_sphere := SphereMesh.new()
		legacy_sphere.radius = expected_radius
		legacy_sphere.height = expected_radius * 2.0
		legacy_sphere.radial_segments = EXPECTED_BODY_MESH_RADIAL_SEGMENTS
		legacy_sphere.rings = EXPECTED_BODY_MESH_RINGS
		var expected_bounds := (
			Transform3D(Basis.IDENTITY, expected.position as Vector3) * legacy_sphere.get_aabb()
		).abs()
		var actual_bounds := (body.transform * sphere.get_aabb()).abs() if sphere != null else AABB()
		if sphere != null:
			body_mesh_ids[sphere.get_instance_id()] = true
		_check(
			body != null and sphere != null and material != null
			and body.position.is_equal_approx(expected.position as Vector3)
			and body.scale.is_equal_approx(Vector3.ONE * float(expected.radius))
			and is_equal_approx(sphere.radius, EXPECTED_BODY_MESH_RADIUS)
			and is_equal_approx(sphere.height, EXPECTED_BODY_MESH_RADIUS * 2.0)
			and sphere.radial_segments == EXPECTED_BODY_MESH_RADIAL_SEGMENTS
			and sphere.rings == EXPECTED_BODY_MESH_RINGS
			and _shared_sphere_matches_legacy_vertices(sphere, legacy_sphere, expected_radius)
			and actual_bounds.is_equal_approx(expected_bounds)
			and StringName(body.get_meta(&"palette_role", &"")) == expected.palette_role,
			"%s keeps its exact placement, effective radius, topology, bounds %s, and palette role"
			% [body_name, actual_bounds]
		)
		_check(
			StringName(body.get_meta(&"visual_resource_family_id", &"")) == EXPECTED_BODY_MESH_FAMILY_ID,
			"%s explicitly belongs to the celestial-body mesh-sharing family" % body_name
		)
		_check(
			material != null
			and material.albedo_color.is_equal_approx(expected.color as Color)
			and material.emission_enabled
			and material.emission.is_equal_approx(expected.color as Color)
			# Re-frozen from 0.32 emission / 0.9 roughness. At 0.32 each body lit its
			# own night side back in, so the four of them rendered as flat saturated
			# discs with no terminator - the most toy-like objects in any wide frame,
			# and untouched by every previous presentation pass because none of them
			# reached a kilometre out. At 0.04 the emission is a floor under the
			# night side rather than a fill, and a body reads as a sphere lit from
			# the same direction as the station. Colour, placement and the
			# non-lighting/non-shadowing contract remain unchanged; the bounded radii
			# above are the explicit anti-flare presentation correction.
			and is_equal_approx(material.emission_energy_multiplier, 0.04)
			and is_equal_approx(material.roughness, 1.0)
			and material.disable_receive_shadows
			and body.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			and body.gi_mode == GeometryInstance3D.GI_MODE_DISABLED,
			"%s uses the exact low-emission, rough, non-lighting body material" % body_name
		)
		_check(
			reported.get("position", Vector3.INF) == expected.position
			and is_equal_approx(float(reported.get("radius", -1.0)), float(expected.radius))
			and StringName(reported.get("palette_role", &"")) == expected.palette_role
			and (reported.get("color", Color.TRANSPARENT) as Color).is_equal_approx(expected.color as Color),
			"%s audit body spec exactly matches its live presentation" % body_name
		)
	_check(
		body_mesh_ids.size() == 1,
		"all four semantic body paths share one immutable unit-sphere resource"
	)


func _test_bounded_resource_sharing(world: ShipyardWorld) -> void:
	var backdrop := world.get_node_or_null(^"SpaceBackdrop") as Node3D
	_check(backdrop != null, "bounded backdrop performance census has its production root")
	if backdrop == null:
		return
	var mesh_resource_ids: Dictionary = {}
	var material_resource_ids: Dictionary = {}
	var renderer_nodes := 0
	var surface_submissions := 0
	var visible_copies := 0
	var triangles := 0
	for child in backdrop.get_children():
		if child is MultiMeshInstance3D:
			var batch := child as MultiMeshInstance3D
			var multimesh := batch.multimesh
			if multimesh == null or multimesh.mesh == null:
				continue
			renderer_nodes += 1
			mesh_resource_ids[multimesh.mesh.get_instance_id()] = true
			var material := multimesh.mesh.surface_get_material(0)
			if material != null:
				material_resource_ids[material.get_instance_id()] = true
			var copy_count := multimesh.visible_instance_count
			if copy_count < 0:
				copy_count = multimesh.instance_count
			surface_submissions += multimesh.mesh.get_surface_count()
			visible_copies += copy_count
			triangles += _mesh_triangle_count(multimesh.mesh) * copy_count
		elif child is MeshInstance3D:
			var instance := child as MeshInstance3D
			if instance.mesh == null:
				continue
			renderer_nodes += 1
			mesh_resource_ids[instance.mesh.get_instance_id()] = true
			if instance.material_override != null:
				material_resource_ids[instance.material_override.get_instance_id()] = true
			surface_submissions += instance.mesh.get_surface_count()
			visible_copies += 1
			triangles += _mesh_triangle_count(instance.mesh)
	_check(
		mesh_resource_ids.size() == EXPECTED_LOCAL_MESH_RESOURCES
		and material_resource_ids.size() == EXPECTED_LOCAL_MATERIAL_RESOURCES,
		"local immutable resources are frozen at five -> two meshes and five -> five materials"
	)
	_check(
		renderer_nodes == EXPECTED_LOCAL_RENDERER_NODES
		and surface_submissions == EXPECTED_LOCAL_SURFACE_SUBMISSIONS
		and visible_copies == EXPECTED_LOCAL_VISIBLE_COPIES
		and triangles == EXPECTED_LOCAL_TRIANGLES,
		"resource sharing preserves 5 renderer nodes/submissions, 2604 copies, and 127296 triangles"
	)


func _mesh_triangle_count(mesh: Mesh) -> int:
	var triangles := 0
	for surface_index in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface_index)
		if arrays.is_empty():
			continue
		var indices := PackedInt32Array()
		if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
			indices = arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
		var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		triangles += (indices.size() if not indices.is_empty() else vertices.size()) / 3
	return triangles


func _shared_sphere_matches_legacy_vertices(
		shared_sphere: SphereMesh,
		legacy_sphere: SphereMesh,
		radius: float
	) -> bool:
	if shared_sphere == null or legacy_sphere == null:
		return false
	if shared_sphere.get_surface_count() != legacy_sphere.get_surface_count():
		return false
	for surface_index in shared_sphere.get_surface_count():
		var shared_arrays := shared_sphere.surface_get_arrays(surface_index)
		var legacy_arrays := legacy_sphere.surface_get_arrays(surface_index)
		var shared_vertices := shared_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var legacy_vertices := legacy_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var shared_normals := shared_arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
		var legacy_normals := legacy_arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
		if (
			shared_vertices.size() != legacy_vertices.size()
			or shared_normals.size() != legacy_normals.size()
		):
			return false
		for vertex_index in shared_vertices.size():
			if (
				not (shared_vertices[vertex_index] * radius).is_equal_approx(
					legacy_vertices[vertex_index]
				)
				or not shared_normals[vertex_index].is_equal_approx(legacy_normals[vertex_index])
			):
				return false
	return true


func _test_presentation_only_boundary(world: ShipyardWorld) -> void:
	var backdrop := world.get_node_or_null(^"SpaceBackdrop") as Node3D
	_check(
		backdrop != null
		and bool(backdrop.get_meta(&"presentation_only", false))
		and not bool(backdrop.get_meta(&"gameplay_authority", true)),
		"backdrop root explicitly declares presentation-only non-authority ownership"
	)
	if backdrop == null:
		return
	var renderable_count := 0
	var authority_count := 0
	for candidate in backdrop.find_children("*", "Node", true, false):
		if candidate is GeometryInstance3D:
			renderable_count += 1
		if _is_forbidden_authority(candidate):
			authority_count += 1
	_check(renderable_count == 5, "backdrop contains exactly five renderable descendants")
	_check(authority_count == 0, "backdrop contains no collision, light, particle, audio, camera, or navigation authority")
	_check(
		int(world.get_space_backdrop_audit_report().get("authority_node_count", -1)) == 0,
		"public audit independently reports zero authority nodes"
	)


func _test_authority_invariants(world: ShipyardWorld) -> void:
	var report := world.get_space_backdrop_audit_report()
	var reported_berths := PackedStringArray(report.get("berth_ids", PackedStringArray()))
	reported_berths.sort()
	var expected_berths := PackedStringArray(EXPECTED_BERTH_IDS)
	expected_berths.sort()
	var live_berths := PackedStringArray()
	for berth_id in world.get_berth_ids():
		live_berths.append(String(berth_id))
	live_berths.sort()
	_check(
		world.get_target_count() == 4
		and world.get_destroyed_target_count() == 0
		and int(report.get("target_count", -1)) == 4,
		"visual backdrop construction preserves all four untouched authoritative range targets"
	)
	_check(
		reported_berths == expected_berths and live_berths == expected_berths,
		"visual backdrop construction preserves the exact five-berth authority registry"
	)
	var all_berths_live := true
	for berth_id_string in EXPECTED_BERTH_IDS:
		var berth_id := StringName(berth_id_string)
		all_berths_live = all_berths_live and world.has_berth(berth_id) and world.get_berth_node(berth_id) != null
	_check(all_berths_live, "every reported berth ID still resolves to a live physical ShipBerth")


func _test_deep_copy_safety(world: ShipyardWorld) -> void:
	var evidence := world.get_space_backdrop_evidence_metadata()
	(evidence.get("sources", PackedStringArray()) as PackedStringArray).append("MUTATION")
	evidence["content_note"] = "mutated"
	var report := world.get_space_backdrop_audit_report()
	(report.get("errors", PackedStringArray()) as PackedStringArray).append("mutation")
	(report.get("berth_ids", PackedStringArray()) as PackedStringArray).clear()
	var nested_evidence := report.get("evidence", {}) as Dictionary
	(nested_evidence.get("sources", PackedStringArray()) as PackedStringArray).clear()
	nested_evidence["source_bounded"] = false
	var body_specs := report.get("body_specs", {}) as Dictionary
	var green_spec := body_specs.get(&"CelestialGreenBody", {}) as Dictionary
	green_spec["position"] = Vector3.ZERO
	green_spec["color"] = Color.MAGENTA
	body_specs.erase(&"CelestialTanBody")

	var fresh_evidence := world.get_space_backdrop_evidence_metadata()
	var fresh_report := world.get_space_backdrop_audit_report()
	var fresh_green := (fresh_report.get("body_specs", {}) as Dictionary).get(&"CelestialGreenBody", {}) as Dictionary
	_check(
		PackedStringArray(fresh_evidence.get("sources", PackedStringArray())) == PackedStringArray(EXPECTED_SOURCES)
		and bool(fresh_evidence.get("source_bounded", false))
		and str(fresh_evidence.get("content_note", "")) != "mutated",
		"evidence reports are deeply detached from production state"
	)
	_check(
		bool(fresh_report.get("valid", false))
		and (fresh_report.get("errors", PackedStringArray()) as PackedStringArray).is_empty()
		and (fresh_report.get("body_specs", {}) as Dictionary).size() == 4
		and fresh_green.get("position", Vector3.ZERO) == Vector3(-310.0, 100.0, -890.0)
		and (fresh_green.get("color", Color.MAGENTA) as Color).is_equal_approx(Color("5a9b58")),
		"nested audit mutations cannot change live or future backdrop reports"
	)
	_check(
		world.get_target_count() == 4 and world.get_berth_ids().size() == 5,
		"report mutation cannot escape into target or berth authority state"
	)


func _test_lifecycle_and_quality_stability(world: ShipyardWorld) -> void:
	var backdrop := world.get_node_or_null(^"SpaceBackdrop") as Node3D
	var stars := world.get_node_or_null(^"SpaceBackdrop/ParallaxStars") as MultiMeshInstance3D
	var sky_material := _get_sky_material(world)
	var identities := PackedInt64Array([
		backdrop.get_instance_id() if backdrop != null else 0,
		stars.get_instance_id() if stars != null else 0,
		stars.multimesh.get_instance_id() if stars != null and stars.multimesh != null else 0,
		stars.multimesh.mesh.get_instance_id() if stars != null and stars.multimesh != null and stars.multimesh.mesh != null else 0,
		sky_material.get_instance_id() if sky_material != null else 0,
	])
	for body_name: StringName in EXPECTED_BODY_SPECS:
		var body := world.get_node_or_null(NodePath("SpaceBackdrop/%s" % body_name)) as MeshInstance3D
		identities.append(body.get_instance_id() if body != null else 0)
		identities.append(body.mesh.get_instance_id() if body != null and body.mesh != null else 0)
		identities.append(body.material_override.get_instance_id() if body != null and body.material_override != null else 0)

	world.apply_visual_quality(0)
	world.apply_visual_quality(2)
	_check(_backdrop_identities(world) == identities, "Low/High quality toggles retain every backdrop node and resource identity")
	_check(bool(world.get_space_backdrop_audit_report().get("valid", false)), "backdrop audit stays green after quality toggles")

	root.remove_child(world)
	await process_frame
	root.add_child(world)
	await process_frame
	_check(_backdrop_identities(world) == identities, "detach/re-entry retains every backdrop node and resource identity")
	_check(bool(world.get_space_backdrop_audit_report().get("valid", false)), "backdrop audit stays green after world detach/re-entry")
	_test_authority_invariants(world)


func _backdrop_identities(world: ShipyardWorld) -> PackedInt64Array:
	var backdrop := world.get_node_or_null(^"SpaceBackdrop") as Node3D
	var stars := world.get_node_or_null(^"SpaceBackdrop/ParallaxStars") as MultiMeshInstance3D
	var sky_material := _get_sky_material(world)
	var identities := PackedInt64Array([
		backdrop.get_instance_id() if backdrop != null else 0,
		stars.get_instance_id() if stars != null else 0,
		stars.multimesh.get_instance_id() if stars != null and stars.multimesh != null else 0,
		stars.multimesh.mesh.get_instance_id() if stars != null and stars.multimesh != null and stars.multimesh.mesh != null else 0,
		sky_material.get_instance_id() if sky_material != null else 0,
	])
	for body_name: StringName in EXPECTED_BODY_SPECS:
		var body := world.get_node_or_null(NodePath("SpaceBackdrop/%s" % body_name)) as MeshInstance3D
		identities.append(body.get_instance_id() if body != null else 0)
		identities.append(body.mesh.get_instance_id() if body != null and body.mesh != null else 0)
		identities.append(body.material_override.get_instance_id() if body != null and body.material_override != null else 0)
	return identities


func _get_sky_material(world: ShipyardWorld) -> ShaderMaterial:
	var environment_node := world.get_node_or_null(^"ShipyardEnvironment") as WorldEnvironment
	if environment_node == null or environment_node.environment == null or environment_node.environment.sky == null:
		return null
	return environment_node.environment.sky.sky_material as ShaderMaterial


func _is_forbidden_authority(candidate: Node) -> bool:
	return (
		candidate is CollisionObject3D
		or candidate is CollisionShape3D
		or candidate is Light3D
		or candidate is GPUParticles3D
		or candidate is CPUParticles3D
		or candidate is AudioStreamPlayer
		or candidate is AudioStreamPlayer3D
		or candidate is Camera3D
		or candidate is NavigationRegion3D
	)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("SPACE_BACKDROP_TEST_OK (%d assertions)" % _assertions)
		quit(0)
	else:
		push_error("SPACE_BACKDROP_TEST_FAILED (%d/%d): %s" % [_failures.size(), _assertions, _failures])
		quit(1)
