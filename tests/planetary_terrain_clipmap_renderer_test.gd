extends SceneTree

const RendererScript := preload(
	"res://scripts/world/planetary_terrain_clipmap_renderer.gd"
)
const AuroraTerrain := preload(
	"res://assets/world/planets/aurora_temperate_terrain.tres"
)

const RESOLUTION := 65
const LANDING_CENTER := Vector3.UP * 120000.0
const FLATTEN_RADIUS_M := 120.0
const VISUAL_CLEARANCE_M := 94.0
const COLLISION_CLEARANCE_M := 48.0
const EXPECTED_RING_COUNT := 5
const EXPECTED_VERTEX_COUNT := EXPECTED_RING_COUNT * RESOLUTION * RESOLUTION
const EXPECTED_VISIBLE_TRIANGLE_COUNT := 40_096
const EXPECTED_FULL_TRIANGLE_COUNT := (
	EXPECTED_RING_COUNT * (RESOLUTION - 1) * (RESOLUTION - 1) * 2
)
const EXPECTED_COLLISION_VERTEX_COUNT := 16_640
const EXPECTED_COLLISION_TRIANGLE_COUNT := 32_768
const EXPECTED_COLLISION_DISTANCE_M := 1_500.0

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var renderer := RendererScript.new() as PlanetaryTerrainClipmapRenderer
	root.add_child(renderer)
	await process_frame

	_check(
		not bool(renderer.configure(null, RESOLUTION).get("accepted", true)),
		"configuration rejects a missing terrain profile without mutating the renderer",
	)
	var folded_profile := AuroraTerrain.duplicate(true) as PlanetaryTerrainProfile
	folded_profile.collision_maximum_distance_meters = 60.0
	_check(
		not bool(renderer.configure(
			folded_profile,
			RESOLUTION,
			20_260_830,
			LANDING_CENTER,
			FLATTEN_RADIUS_M,
			VISUAL_CLEARANCE_M,
			COLLISION_CLEARANCE_M,
		).get("accepted", true))
		and renderer.get_generation() == 0,
		"configuration rejects an outer collision circle that cannot contain the square landing clearance",
	)
	var configured := renderer.configure(
		AuroraTerrain,
		RESOLUTION,
		20_260_830,
		LANDING_CENTER,
		FLATTEN_RADIUS_M,
		VISUAL_CLEARANCE_M,
		COLLISION_CLEARANCE_M,
	)
	_check(
		bool(configured.get("accepted", false))
		and renderer.get_generation() == 1
		and renderer.get_revision() == 0,
		"Aurora's real profile configures one bounded caller-driven generation",
	)
	_check(
		not bool(renderer.configure(AuroraTerrain, RESOLUTION).get("accepted", true))
		and not bool(renderer.rebuild(LANDING_CENTER, 0).get("accepted", true))
		and renderer.get_node_or_null(^"CommittedTerrain") == null,
		"duplicate configuration and a stale rebuild fail before scene mutation",
	)

	var rebuilt := renderer.rebuild(LANDING_CENTER, renderer.get_generation())
	var snapshot := renderer.get_snapshot()
	_check(
		bool(rebuilt.get("accepted", false))
		and int(snapshot.get("ring_count", 0)) == EXPECTED_RING_COUNT
		and int(snapshot.get("render_vertex_count", 0)) == EXPECTED_VERTEX_COUNT
		and int(snapshot.get("render_triangle_count", 0))
			== EXPECTED_VISIBLE_TRIANGLE_COUNT,
		"one north-pole rebuild creates the exact five-ring 65x65 clipmap",
	)
	_check(
		int(snapshot.get("collision_ring_count", 0)) == 1
		and int(snapshot.get("collision_triangle_count", 0))
			== EXPECTED_COLLISION_TRIANGLE_COUNT
		and int(snapshot.get("collision_vertex_count", 0))
			== EXPECTED_COLLISION_VERTEX_COUNT
		and is_equal_approx(
			float(snapshot.get("collision_maximum_distance_m", 0.0)),
			EXPECTED_COLLISION_DISTANCE_M,
		)
		and snapshot.get("collision_topology")
			== &"square_clearance_to_circular_profile_boundary"
		and float(snapshot.get("minimum_generated_height_m", -INF))
			>= AuroraTerrain.minimum_elevation_meters
		and float(snapshot.get("maximum_generated_height_m", INF))
			<= AuroraTerrain.maximum_elevation_meters,
		"generated render and profile-distance collision stay inside Aurora's frozen envelope",
	)

	var committed := renderer.get_node(^"CommittedTerrain") as Node3D
	var visuals := committed.get_node(^"TerrainVisuals") as Node3D
	var mesh_report := _inspect_visual_meshes(visuals)
	_check(
		int(mesh_report.get("renderer_count", 0)) == EXPECTED_RING_COUNT
		and int(mesh_report.get("surface_count", 0)) == EXPECTED_RING_COUNT
		and int(mesh_report.get("material_count", 0)) == 1,
		"five ring renderers share one immutable vertex-colour material",
	)
	_check(
		int(mesh_report.get("triangle_count", 0))
			== int(snapshot.get("render_triangle_count", -1))
		and int(mesh_report.get("backward_triangle_count", -1)) == 0,
		"every generated terrain triangle uses Godot's outward clockwise front face",
	)
	var collision_report := _inspect_collision_clearance(
		committed.get_node(^"TerrainCollision") as StaticBody3D
	)
	_check(
		int(collision_report.get("shape_count", 0)) == 1
		and int(collision_report.get("face_count", 0))
			== int(snapshot.get("collision_triangle_count", -1))
		and float(collision_report.get("minimum_square_radius_m", 0.0))
			>= COLLISION_CLEARANCE_M - 0.01
		and float(collision_report.get("maximum_tangent_radius_m", 0.0))
			>= EXPECTED_COLLISION_DISTANCE_M - 0.1
		and float(collision_report.get("maximum_tangent_radius_m", INF))
			<= EXPECTED_COLLISION_DISTANCE_M + 0.1
		and int(collision_report.get("backward_triangle_count", -1)) == 0,
		"one outward terrain surface hands off at the 96 m patch and reaches the 1.5 km collision boundary",
	)

	var landing_height := renderer.sample_height(Vector3.UP)
	var distant_height := renderer.sample_height(
		Vector3(0.18, 0.96, -0.21).normalized()
	)
	_check(
		bool(landing_height.get("accepted", false))
		and is_zero_approx(float(landing_height.get("height_m", INF)))
		and bool(distant_height.get("accepted", false))
		and not is_zero_approx(float(distant_height.get("height_m", 0.0))),
		"the landing region is exactly flattened while the global height field remains varied",
	)

	var north_root_id := committed.get_instance_id()
	var north_collision_shape_id := (
		(committed.get_node(
			^"TerrainCollision/TerrainCollisionSurface"
		) as CollisionShape3D).shape.get_instance_id()
	)
	var equator_focus := Vector3.RIGHT * 120000.0
	var equator := renderer.rebuild(equator_focus, renderer.get_generation())
	var equator_snapshot := renderer.get_snapshot()
	_check(
		bool(equator.get("accepted", false))
		and renderer.get_revision() == 2
		and renderer.get_node(^"CommittedTerrain").get_instance_id() != north_root_id
		and (equator_snapshot.get("focus_radial_up", Vector3.ZERO) as Vector3)
			.is_equal_approx(Vector3.RIGHT)
		and (equator_snapshot.get(
			"collision_focus_radial_up", Vector3.ZERO
		) as Vector3).is_equal_approx(Vector3.UP)
		and bool(equator_snapshot.get("collision_reused", false))
		and int(equator_snapshot.get("render_triangle_count", 0))
			== EXPECTED_FULL_TRIANGLE_COUNT
		and ((renderer.get_node(
			^"CommittedTerrain/TerrainCollision/TerrainCollisionSurface"
		) as CollisionShape3D).shape.get_instance_id()) == north_collision_shape_id,
		"a caller can move the visible clipmap while the authored landing collision remains fixed and cached",
	)
	var tangent_right := equator_snapshot.get("tangent_right", Vector3.ZERO) as Vector3
	var tangent_back := equator_snapshot.get("tangent_back", Vector3.ZERO) as Vector3
	_check(
		is_equal_approx(tangent_right.length(), 1.0)
		and is_equal_approx(tangent_back.length(), 1.0)
		and is_zero_approx(tangent_right.dot(Vector3.RIGHT))
		and is_zero_approx(tangent_back.dot(Vector3.RIGHT))
		and is_zero_approx(tangent_right.dot(tangent_back))
		and bool(renderer.audit().get("valid", false)),
		"equatorial terrain retains an orthonormal tangent frame and a green live audit",
	)

	var detached_root_id := renderer.get_node(^"CommittedTerrain").get_instance_id()
	root.remove_child(renderer)
	var detached_rebuild := renderer.rebuild(LANDING_CENTER, renderer.get_generation())
	root.add_child(renderer)
	await process_frame
	_check(
		not bool(detached_rebuild.get("accepted", true))
		and renderer.get_node(^"CommittedTerrain").get_instance_id()
			== detached_root_id
		and bool(renderer.audit().get("valid", false)),
		"detach rejects hidden rebuilds and re-entry preserves the committed terrain identity",
	)

	var old_generation := renderer.get_generation()
	_check(
		not bool(renderer.retire(old_generation + 1).get("accepted", true))
		and bool(renderer.retire(old_generation).get("accepted", false))
		and renderer.get_generation() == old_generation + 1
		and renderer.get_revision() == 0
		and renderer.get_node_or_null(^"CommittedTerrain") == null,
		"retirement is generation-fenced and atomically clears the committed clipmap",
	)
	_check(
		not bool(renderer.rebuild(LANDING_CENTER, old_generation).get("accepted", true))
		and bool(renderer.rebuild(
			LANDING_CENTER, renderer.get_generation()
		).get("accepted", false))
		and bool(renderer.audit().get("valid", false)),
		"only the advanced generation can rebuild after retirement",
	)

	var detached_snapshot := renderer.get_snapshot()
	(detached_snapshot.get("rings", []) as Array).clear()
	_check(
		(renderer.get_snapshot().get("rings", []) as Array).size()
			== EXPECTED_RING_COUNT,
		"published terrain snapshots are deeply detached from live state",
	)

	renderer.queue_free()
	await process_frame
	_finish()


func _inspect_visual_meshes(visuals: Node3D) -> Dictionary:
	var material_ids := {}
	var renderer_count := 0
	var surface_count := 0
	var triangle_count := 0
	var backward_triangle_count := 0
	for child in visuals.get_children():
		var instance := child as MeshInstance3D
		if instance == null or instance.mesh == null:
			continue
		renderer_count += 1
		surface_count += instance.mesh.get_surface_count()
		if instance.material_override != null:
			material_ids[instance.material_override.get_instance_id()] = true
		for surface_index in instance.mesh.get_surface_count():
			var arrays := instance.mesh.surface_get_arrays(surface_index)
			var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
			var indices := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
			for start in range(0, indices.size(), 3):
				var a := vertices[indices[start]]
				var b := vertices[indices[start + 1]]
				var c := vertices[indices[start + 2]]
				var mathematical_normal := (b - a).cross(c - a)
				var outward := (a + b + c).normalized()
				triangle_count += 1
				if mathematical_normal.dot(outward) >= 0.0:
					backward_triangle_count += 1
	return {
		"renderer_count": renderer_count,
		"surface_count": surface_count,
		"material_count": material_ids.size(),
		"triangle_count": triangle_count,
		"backward_triangle_count": backward_triangle_count,
	}


func _inspect_collision_clearance(body: StaticBody3D) -> Dictionary:
	var shape_count := 0
	var face_count := 0
	var minimum_square_radius := INF
	var maximum_tangent_radius := 0.0
	var backward_triangle_count := 0
	for child in body.get_children():
		var collision := child as CollisionShape3D
		var shape := collision.shape as ConcavePolygonShape3D if collision != null else null
		if shape == null:
			continue
		shape_count += 1
		var faces := shape.get_faces()
		face_count += faces.size() / 3
		for start in range(0, faces.size(), 3):
			var a := faces[start]
			var b := faces[start + 1]
			var c := faces[start + 2]
			var centre := (a + b + c) / 3.0
			minimum_square_radius = minf(
				minimum_square_radius,
				maxf(absf(centre.x), absf(centre.z)),
			)
			for candidate in [a, b, c]:
				var vertex := candidate as Vector3
				var direction := vertex.normalized()
				maximum_tangent_radius = maxf(
					maximum_tangent_radius,
					LANDING_CENTER.length()
						* Vector2(direction.x, direction.z).length()
						/ direction.y,
				)
			if (b - a).cross(c - a).dot(a + b + c) >= 0.0:
				backward_triangle_count += 1
	return {
		"shape_count": shape_count,
		"face_count": face_count,
		"minimum_square_radius_m": minimum_square_radius,
		"maximum_tangent_radius_m": maximum_tangent_radius,
		"backward_triangle_count": backward_triangle_count,
	}


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("PLANETARY_TERRAIN_CLIPMAP_RENDERER_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	push_error(
		"PLANETARY_TERRAIN_CLIPMAP_RENDERER_TEST_FAILED (%d/%d): %s"
		% [_failures.size(), _assertions, _failures]
	)
	quit(1)
