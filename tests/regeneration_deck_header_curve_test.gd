extends SceneTree

## Focused production contract for the spawn-facing regeneration/registry deck
## header. ShipyardWorld retains every collider and gameplay authority owner.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const PLAYER_RADIUS := 0.38
const PLAYER_HEIGHT := 1.94

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "production Main instantiates for the regeneration deck")
	if game == null:
		_finish()
		return
	root.add_child(game)
	await process_frame
	await physics_frame
	await physics_frame

	var world := game.get_node_or_null(^"ShipyardWorld") as ShipyardWorld
	var registry := game.get_node_or_null(
		^"ShipyardWorld/ModernFleetRegistry"
	) as Node3D
	_check(world != null, "production Main retains ShipyardWorld")
	_check(registry != null, "world retains the ModernFleetRegistry regeneration deck")
	if world != null and registry != null:
		_test_curved_header(world, registry)
		await _test_player_clearance(world, registry)

	game.queue_free()
	for cleanup_frame in 3:
		await process_frame
		await physics_frame
	_finish()


func _test_curved_header(world: ShipyardWorld, registry: Node3D) -> void:
	var header := registry.get_node_or_null(^"RegistryPodFascia") as StaticBody3D
	var visual := header.get_node_or_null(^"Mesh") as MeshInstance3D if header != null else null
	var collision := header.get_node_or_null(^"Collision") as CollisionShape3D if header != null else null
	var shape := collision.shape as BoxShape3D if collision != null else null
	_check(
		header != null and visual != null and visual.mesh != null and shape != null,
		"regeneration deck retains one rendered, collision-backed identity header"
	)
	if header == null or visual == null or visual.mesh == null or shape == null:
		return

	var arrays := visual.mesh.surface_get_arrays(0)
	var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var normals := arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
	_check(
		visual.mesh.resource_name == "modern_registry_capsule_header_v1"
		and visual.mesh.get_surface_count() == 1
		and vertices.size() / 3 == 72,
		"visible registry gate uses one 72-triangle capsule surface instead of the 108-triangle shallow box"
	)
	_check(
		visual.mesh.get_aabb().position.is_equal_approx(
			-ShipyardWorld.MODERN_REGISTRY_HEADER_SIZE * 0.5
		)
		and visual.mesh.get_aabb().size.is_equal_approx(
			ShipyardWorld.MODERN_REGISTRY_HEADER_SIZE
		)
		and shape.size.is_equal_approx(ShipyardWorld.MODERN_REGISTRY_HEADER_SIZE)
		and header.position.is_equal_approx(Vector3(-43.0, 5.35, 23.03)),
		"curved render and box collider preserve the exact 12 x 1 x 0.42 m roof-lapped envelope"
	)
	var terminal := registry.get_node_or_null(^"FleetRegistryTerminal") as StaticBody3D
	var terminal_visual := terminal.get_node_or_null(^"Mesh") as MeshInstance3D if terminal != null else null
	_check(
		terminal_visual != null
		and visual.material_override == terminal_visual.material_override
		and header.get_child_count() == 2
		and header.collision_layer == PhysicsLayers.WORLD
		and header.collision_mask == PhysicsLayers.NONE,
		"header retains navy panel material, two-child body and World-only collision authority"
	)
	_check(
		str(header.get_meta("geometry_profile", "")) == "regeneration_deck_capsule_header"
		and is_equal_approx(float(header.get_meta("end_radius_m", 0.0)), 0.5)
		and int(header.get_meta("curve_segments_per_end", 0)) == 8
		and str(header.get_meta("evidence_status", "")) == "modern_interpretation"
		and not bool(header.get_meta("authenticated_original_geometry", true))
		and not bool(header.get_meta("historical_form_identified", true)),
		"header publishes its curve recipe and honest modern-interpretation evidence boundary"
	)
	_check(
		_all_triangles_face_their_normals(vertices, normals),
		"caps, rim and curved ends retain outward front-face winding"
	)

	var sign := registry.get_node_or_null(
		^"Sign_FLEET_REGISTRY__--__MODERN_INTERFACE"
	) as MeshInstance3D
	var sign_mesh := sign.mesh as TextMesh if sign != null else null
	_check(
		sign != null and sign_mesh != null and sign.visible
		and sign_mesh.text == "FLEET REGISTRY  //  MODERN INTERFACE"
		and sign.position.is_equal_approx(Vector3(-43.0, 5.05, 22.82))
		and sign.rotation_degrees.is_equal_approx(Vector3(0.0, 180.0, 0.0)),
		"spawn-approach registry legend remains at its exact readable fascia transform"
	)

	var render_contract := world.get_modern_fleet_registry_render_contract()
	_check(
		int(render_contract.get("descendant_nodes", -1)) == 63
		and int(render_contract.get("mesh_instances", -1)) == 34
		and int(render_contract.get("multimesh_batches", -1)) == 1
		and int(render_contract.get("drawn_copies", -1)) == 38
		and int(render_contract.get("geometry_submissions", -1)) == 35
		and int(render_contract.get("physics_bodies", -1)) == 12
		and int(render_contract.get("collision_shapes", -1)) == 12
		and int(render_contract.get("lights", -1)) == 2
		and int(render_contract.get("areas", -1)) == 0,
		"registry holds its current 35-submission, 12-body, two-light production budget"
	)
	_check(
		registry.find_children("*", "Area3D", true, false).is_empty()
		and registry.find_children("*", "ShipBerth", true, false).is_empty()
		and registry.find_children("*", "StationDoor", true, false).is_empty(),
		"curved presentation adds no regeneration, berth, interaction or door authority"
	)
	var spawn_marker := world.get_node_or_null(^"%PlayerSpawn") as Marker3D
	var ship_spawn := world.get_node_or_null(^"%ShipSpawn") as Marker3D
	_check(
		spawn_marker != null and ship_spawn != null
		and spawn_marker.position.is_equal_approx(Vector3(-8.5, 0.18, 11.0))
		and ship_spawn.position.is_equal_approx(Vector3(0.0, 1.15, -10.0)),
		"player and ship regeneration/spawn anchors remain untouched"
	)


func _test_player_clearance(world: ShipyardWorld, registry: Node3D) -> void:
	var capsule := CapsuleShape3D.new()
	capsule.radius = PLAYER_RADIUS
	capsule.height = PLAYER_HEIGHT
	var route_samples := PackedVector3Array([
		Vector3(-46.5, 1.46, 22.9),
		Vector3(-46.5, 1.46, 23.4),
		Vector3(-46.5, 1.46, 25.0),
		Vector3(-46.5, 1.46, 27.0),
	])
	var every_capsule_clear := true
	for sample in route_samples:
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = capsule
		query.transform = Transform3D(Basis.IDENTITY, registry.to_global(sample))
		query.collision_mask = PhysicsLayers.WORLD
		query.collide_with_bodies = true
		query.collide_with_areas = false
		await physics_frame
		every_capsule_clear = every_capsule_clear and world.get_world_3d().direct_space_state.intersect_shape(query, 32).is_empty()
	_check(
		every_capsule_clear,
		"production player capsule clears the threshold, curved gate and regeneration deck approach"
	)


func _all_triangles_face_their_normals(
		vertices: PackedVector3Array,
		normals: PackedVector3Array,
	) -> bool:
	if vertices.is_empty() or vertices.size() != normals.size() or vertices.size() % 3 != 0:
		return false
	for index in range(0, vertices.size(), 3):
		var geometric := (vertices[index + 1] - vertices[index]).cross(
			vertices[index + 2] - vertices[index]
		).normalized()
		var declared := (
			normals[index] + normals[index + 1] + normals[index + 2]
		).normalized()
		if geometric.dot(declared) < 0.99:
			return false
	return true


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("REGENERATION_DECK_HEADER_CURVE_TEST_OK")
		quit(0)
	else:
		print("REGENERATION_DECK_HEADER_CURVE_TEST_FAILED: ", "; ".join(_failures))
		quit(1)
