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
const CORRIDOR_FOCUS_DISTANCE_M := 3_000.0
const EXPECTED_CORRIDOR_VERTEX_COUNT := 2_880
const EXPECTED_CORRIDOR_TRIANGLE_COUNT := 5_544

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

	await _test_live_character_support(renderer)

	var north_root_id := committed.get_instance_id()
	var north_collision_shape_id := (
		(committed.get_node(
			^"TerrainCollision/TerrainCollisionSurface"
		) as CollisionShape3D).shape.get_instance_id()
	)
	var prefetch_rebuild := renderer.rebuild(
		Vector3(EXPECTED_COLLISION_DISTANCE_M, LANDING_CENTER.y, 0.0),
		renderer.get_generation(),
	)
	var prefetch_snapshot := renderer.get_snapshot()
	_check(
		bool(prefetch_rebuild.get("accepted", false))
		and bool(prefetch_snapshot.get("dynamic_collision_active", false))
		and int(prefetch_snapshot.get("dynamic_collision_triangle_count", 0))
			== 8_320
		and int(prefetch_snapshot.get("collision_triangle_count", 0))
			== 41_088
		and ((renderer.get_node(
			^"CommittedTerrain/TerrainCollision/TerrainCollisionSurface"
		) as CollisionShape3D).shape.get_instance_id()) == north_collision_shape_id,
		"the widest prefetch corridor fits its exact hard budget at the fixed-surface boundary",
	)
	var corridor_focus := Vector3(
		CORRIDOR_FOCUS_DISTANCE_M,
		LANDING_CENTER.y,
		0.0,
	)
	var corridor_rebuild := renderer.rebuild(
		corridor_focus,
		renderer.get_generation(),
	)
	await physics_frame
	var corridor_snapshot := renderer.get_snapshot()
	var corridor_collision_body := renderer.get_node(
		^"CommittedTerrain/TerrainCollision"
	) as StaticBody3D
	var current_fixed_collision := corridor_collision_body.get_node(
		^"TerrainCollisionSurface"
	) as CollisionShape3D
	var focus_corridor_collision := corridor_collision_body.get_node_or_null(
		^"TerrainFocusCollisionCorridor"
	) as CollisionShape3D
	_check(
		bool(corridor_rebuild.get("accepted", false))
		and bool(corridor_snapshot.get("dynamic_collision_active", false))
		and corridor_snapshot.get("dynamic_collision_reason")
			== &"focus_collision_corridor_built"
		and int(corridor_snapshot.get("collision_ring_count", 0)) == 2
		and int(corridor_snapshot.get("fixed_collision_triangle_count", 0))
			== EXPECTED_COLLISION_TRIANGLE_COUNT
		and int(corridor_snapshot.get("dynamic_collision_triangle_count", 0))
			== EXPECTED_CORRIDOR_TRIANGLE_COUNT
		and int(corridor_snapshot.get("dynamic_collision_vertex_count", 0))
			== EXPECTED_CORRIDOR_VERTEX_COUNT
		and int(corridor_snapshot.get("collision_triangle_count", 0))
			== EXPECTED_COLLISION_TRIANGLE_COUNT
				+ EXPECTED_CORRIDOR_TRIANGLE_COUNT
		and is_equal_approx(
			float(corridor_snapshot.get("dynamic_collision_inner_distance_m", 0.0)),
			EXPECTED_COLLISION_DISTANCE_M,
		)
		and is_equal_approx(
			float(corridor_snapshot.get("dynamic_collision_outer_distance_m", 0.0)),
			CORRIDOR_FOCUS_DISTANCE_M + EXPECTED_COLLISION_DISTANCE_M,
		)
		and current_fixed_collision.shape.get_instance_id()
			== north_collision_shape_id
		and focus_corridor_collision != null,
		"a 3 km focus keeps the cached landing surface and adds one exact bounded collision corridor",
	)
	var corridor_geometry := _inspect_focus_collision_corridor(
		current_fixed_collision,
		focus_corridor_collision,
	)
	_check(
		int(corridor_geometry.get("face_count", 0))
			== EXPECTED_CORRIDOR_TRIANGLE_COUNT
		and int(corridor_geometry.get("backward_triangle_count", -1)) == 0
		and int(corridor_geometry.get("seam_vertex_count", 0)) == 45
		and int(corridor_geometry.get("seam_mismatch_count", -1)) == 0
		and float(corridor_geometry.get("maximum_seam_gap_m", INF))
			<= 0.001
		and absf(
			float(corridor_geometry.get("minimum_tangent_radius_m", 0.0))
				- EXPECTED_COLLISION_DISTANCE_M
		) <= 0.02
		and absf(
			float(corridor_geometry.get("maximum_tangent_radius_m", 0.0))
				- (
					CORRIDOR_FOCUS_DISTANCE_M
					+ EXPECTED_COLLISION_DISTANCE_M
				)
		) <= 0.02,
		"the corridor is outward-facing and shares every inner vertex with the fixed 1.5 km seam",
	)
	var terrain_space := root.get_world_3d().direct_space_state
	_check(
		_ray_hit_at_tangent(renderer, terrain_space, Vector2(2_000.0, 0.0))
			.get("collider") == corridor_collision_body
		and _ray_hit_at_tangent(
			renderer,
			terrain_space,
			Vector2(CORRIDOR_FOCUS_DISTANCE_M, 0.0),
		).get("collider") == corridor_collision_body
		and _ray_hit_at_tangent(
			renderer,
			terrain_space,
			Vector2(CORRIDOR_FOCUS_DISTANCE_M + 1_501.0, 0.0),
		).is_empty()
		and _ray_hit_at_tangent(
			renderer,
			terrain_space,
			Vector2.from_angle(deg_to_rad(40.0))
				* CORRIDOR_FOCUS_DISTANCE_M,
		).is_empty(),
		"physical rays find the actor path and focus while remaining bounded beyond the corridor edges",
	)
	var equator_focus := Vector3.RIGHT * 120000.0
	var equator := renderer.rebuild(equator_focus, renderer.get_generation())
	var equator_snapshot := renderer.get_snapshot()
	_check(
		bool(equator.get("accepted", false))
		and renderer.get_revision() == 4
		and renderer.get_node(^"CommittedTerrain").get_instance_id() != north_root_id
		and (equator_snapshot.get("focus_radial_up", Vector3.ZERO) as Vector3)
			.is_equal_approx(Vector3.RIGHT)
		and (equator_snapshot.get(
			"collision_focus_radial_up", Vector3.ZERO
		) as Vector3).is_equal_approx(Vector3.UP)
		and bool(equator_snapshot.get("collision_reused", false))
		and not bool(equator_snapshot.get("dynamic_collision_active", true))
		and equator_snapshot.get("dynamic_collision_reason")
			== &"focus_outside_collision_streaming_envelope"
		and int(equator_snapshot.get("collision_ring_count", 0)) == 1
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
		for index in faces.size():
			faces[index] = body.transform * (collision.transform * faces[index])
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


func _test_live_character_support(renderer: PlanetaryTerrainClipmapRenderer) -> void:
	# Reproduce the production body-to-world offset while using real capsule
	# narrow-phase contact, which ray hits alone cannot establish.
	renderer.position = -LANDING_CENTER
	var actor := CharacterBody3D.new()
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	collision.shape = capsule
	collision.position.y = 0.9
	actor.add_child(collision)
	root.add_child(actor)
	actor.global_position = Vector3(72.0, 1.0, 0.0)
	var grounded_samples := 0
	for tick in 180:
		await physics_frame
		actor.velocity.y -= 1.62 / float(Engine.physics_ticks_per_second)
		actor.move_and_slide()
		if tick >= 120 and actor.is_on_floor():
			grounded_samples += 1
	_check(
		grounded_samples == 60 and actor.global_position.y > -0.1,
		"a real CharacterBody capsule remains grounded on rebased terrain for sixty consecutive ticks",
	)
	actor.free()
	renderer.position = Vector3.ZERO
	await physics_frame


func _body_local_collision_faces(collision: CollisionShape3D) -> PackedVector3Array:
	var faces := (collision.shape as ConcavePolygonShape3D).get_faces()
	var transform := (collision.get_parent() as Node3D).transform * collision.transform
	for index in faces.size():
		faces[index] = transform * faces[index]
	return faces


func _inspect_focus_collision_corridor(
	fixed_collision: CollisionShape3D,
	corridor_collision: CollisionShape3D,
) -> Dictionary:
	var fixed_seam := {}
	for vertex in _body_local_collision_faces(fixed_collision):
		var offset := _landing_tangent_offset(vertex)
		if absf(offset.length() - EXPECTED_COLLISION_DISTANCE_M) <= 0.02:
			fixed_seam[_quantized_tangent_key(offset)] = offset
	var corridor_faces := _body_local_collision_faces(corridor_collision)
	var corridor_seam := {}
	var minimum_tangent_radius_m := INF
	var maximum_tangent_radius_m := 0.0
	var maximum_seam_gap_m := 0.0
	var backward_triangle_count := 0
	for start in range(0, corridor_faces.size(), 3):
		var a := corridor_faces[start]
		var b := corridor_faces[start + 1]
		var c := corridor_faces[start + 2]
		for vertex in [a, b, c]:
			var offset := _landing_tangent_offset(vertex)
			var radius_m := offset.length()
			minimum_tangent_radius_m = minf(
				minimum_tangent_radius_m,
				radius_m,
			)
			maximum_tangent_radius_m = maxf(
				maximum_tangent_radius_m,
				radius_m,
			)
			if absf(radius_m - EXPECTED_COLLISION_DISTANCE_M) <= 0.02:
				corridor_seam[_quantized_tangent_key(offset)] = offset
		if (b - a).cross(c - a).dot(a + b + c) >= 0.0:
			backward_triangle_count += 1
	var seam_mismatch_count := 0
	for key in corridor_seam:
		if not fixed_seam.has(key):
			seam_mismatch_count += 1
			continue
		maximum_seam_gap_m = maxf(
			maximum_seam_gap_m,
			(corridor_seam[key] as Vector2).distance_to(
				fixed_seam[key] as Vector2
			),
		)
	return {
		"face_count": corridor_faces.size() / 3,
		"minimum_tangent_radius_m": minimum_tangent_radius_m,
		"maximum_tangent_radius_m": maximum_tangent_radius_m,
		"seam_vertex_count": corridor_seam.size(),
		"seam_mismatch_count": seam_mismatch_count,
		"maximum_seam_gap_m": maximum_seam_gap_m,
		"backward_triangle_count": backward_triangle_count,
	}


func _ray_hit_at_tangent(
	renderer: PlanetaryTerrainClipmapRenderer,
	space: PhysicsDirectSpaceState3D,
	tangent_offset_m: Vector2,
) -> Dictionary:
	var tangent_point := Vector3(
		tangent_offset_m.x,
		LANDING_CENTER.length(),
		tangent_offset_m.y,
	)
	var direction := tangent_point.normalized()
	var sampled := renderer.sample_height(direction)
	var surface_point := direction * (
		LANDING_CENTER.length() + float(sampled.get("height_m", 0.0))
	)
	var query := PhysicsRayQueryParameters3D.create(
		surface_point + direction * 20.0,
		surface_point - direction * 20.0,
		1,
	)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return space.intersect_ray(query)


func _landing_tangent_offset(vertex: Vector3) -> Vector2:
	var direction := vertex.normalized()
	return Vector2(direction.x, direction.z) * (
		LANDING_CENTER.length() / direction.y
	)


func _quantized_tangent_key(offset: Vector2) -> Vector2i:
	return Vector2i(roundi(offset.x * 10.0), roundi(offset.y * 10.0))


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
