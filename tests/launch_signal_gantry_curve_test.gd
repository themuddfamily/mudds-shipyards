extends SceneTree

## Focused production contract for the curved signal crossbeam over the central
## berth's launch approach. Existing berth, launch marker and physics own gameplay.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const PLAYER_RADIUS := 0.38
const PLAYER_HEIGHT := 1.94

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "production Main instantiates for the central launch approach")
	if game == null:
		_finish()
		return
	root.add_child(game)
	await process_frame
	await physics_frame
	await physics_frame

	var world := game.get_node_or_null(^"ShipyardWorld") as ShipyardWorld
	var launch := game.get_node_or_null(^"ShipyardWorld/OpenLaunchSpine") as Node3D
	_check(world != null and launch != null, "production central launch spine resolves under ShipyardWorld")
	if world != null and launch != null:
		_test_curved_signal_gantry(world, launch)
		await _test_retained_clearance(world, launch)

	game.queue_free()
	for cleanup_frame in 3:
		await process_frame
		await physics_frame
	_finish()


func _test_curved_signal_gantry(world: ShipyardWorld, launch: Node3D) -> void:
	var gantry := launch.get_node_or_null(^"SignalGantry") as MeshInstance3D
	_check(
		gantry != null and gantry.mesh != null,
		"central launch approach retains its one rendered signal crossbeam"
	)
	if gantry == null or gantry.mesh == null:
		return

	var arrays := gantry.mesh.surface_get_arrays(0)
	var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var normals := arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
	_check(
		gantry.mesh.resource_name == "central_launch_signal_capsule_gantry_v1"
		and gantry.mesh.get_surface_count() == 1
		and vertices.size() / 3 == 72,
		"visible signal gantry uses one 72-triangle capsule surface instead of the 108-triangle shallow box"
	)
	_check(
		gantry.mesh.get_aabb().position.is_equal_approx(
			-ShipyardWorld.SIGNAL_GANTRY_SIZE * 0.5
		)
		and gantry.mesh.get_aabb().size.is_equal_approx(ShipyardWorld.SIGNAL_GANTRY_SIZE)
		and gantry.position.is_equal_approx(Vector3(0.0, 12.2, -66.0)),
		"curved mesh preserves the exact 27 x 0.8 x 0.8 m crossbeam envelope and 11.8 m underside"
	)

	var mast := launch.get_node_or_null(^"SignalMast") as StaticBody3D
	var mast_visual: MeshInstance3D
	if mast != null:
		for child in mast.get_children():
			if child is MeshInstance3D:
				mast_visual = child as MeshInstance3D
				break
	_check(
		mast_visual != null
		and gantry.material_override == mast_visual.material_override
		and gantry.get_child_count() == 0
		and gantry.find_children("*", "CollisionObject3D", true, false).is_empty()
		and launch.find_children("SignalGantry", "MeshInstance3D", false, false).size() == 1,
		"gantry retains steel-blue material, one node/submission and zero collision authority"
	)
	_check(
		str(gantry.get_meta("geometry_profile", "")) == "central_launch_capsule_crossbeam"
		and is_equal_approx(float(gantry.get_meta("end_radius_m", 0.0)), 0.4)
		and int(gantry.get_meta("curve_segments_per_end", 0)) == 8
		and str(gantry.get_meta("evidence_status", "")) == "modern_interpretation"
		and not bool(gantry.get_meta("historical_form_identified", true))
		and not bool(gantry.get_meta("authenticated_original_geometry", true)),
		"crossbeam publishes its curve recipe and honest modern-interpretation boundary"
	)
	_check(
		_all_triangles_face_their_normals(vertices, normals),
		"caps, rim and curved ends retain outward front-face winding"
	)

	var vector_sign := launch.get_node_or_null(
		^"Sign_OPEN_DOCK__--__FLIGHT_VECTOR"
	) as MeshInstance3D
	var clearance_sign := launch.get_node_or_null(^"Sign_CLEAR_OF_BERTH") as MeshInstance3D
	var vector_mesh := vector_sign.mesh as TextMesh if vector_sign != null else null
	var clearance_mesh := clearance_sign.mesh as TextMesh if clearance_sign != null else null
	_check(
		vector_mesh != null and clearance_mesh != null
		and vector_mesh.text == "OPEN DOCK  //  FLIGHT VECTOR"
		and clearance_mesh.text == "CLEAR OF BERTH"
		and vector_sign.position.is_equal_approx(Vector3(0.0, 12.2, -65.42))
		and clearance_sign.position.is_equal_approx(Vector3(0.0, 11.35, -65.4)),
		"launch-vector and berth-clear signage retain their exact readable transforms"
	)

	var launch_gate := world.get_node_or_null(^"%LaunchGate") as Marker3D
	var central_berth := world.get_node_or_null(^"CentralBerth") as ShipBerth
	var band := world.get_outbound_clearance_band()
	_check(
		launch_gate != null and central_berth != null
		and launch_gate.position.is_equal_approx(Vector3(0.0, 2.7, -64.0))
		and world.get_ship_spawn().is_equal_approx(central_berth.get_dock_transform())
		and is_equal_approx(float(band.get("aim_y", -1.0)), 2.7),
		"central berth and published launch-gate authority remain at their exact retained transforms"
	)
	var evidence := world.get_central_berth_evidence_metadata()
	_check(
		str(evidence.get("evidence_status", "")) == "creator_roster_supported_modern_interpretation"
		and not bool(evidence.get("authenticated_original_geometry", true))
		and not bool(evidence.get("authenticated_berth_layout", true)),
		"central berth continues to reject authenticated geometry and layout claims"
	)


func _test_retained_clearance(world: ShipyardWorld, launch: Node3D) -> void:
	var capsule := CapsuleShape3D.new()
	capsule.radius = PLAYER_RADIUS
	capsule.height = PLAYER_HEIGHT
	var every_capsule_clear := true
	for sample in PackedVector3Array([
		Vector3(0.0, 1.08, -62.0),
		Vector3(0.0, 1.08, -64.0),
		Vector3(0.0, 1.08, -66.0),
		Vector3(0.0, 1.08, -67.0),
	]):
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = capsule
		query.transform = Transform3D(Basis.IDENTITY, launch.to_global(sample))
		query.collision_mask = PhysicsLayers.WORLD
		query.collide_with_bodies = true
		query.collide_with_areas = false
		await physics_frame
		every_capsule_clear = every_capsule_clear and world.get_world_3d().direct_space_state.intersect_shape(query, 32).is_empty()
	_check(
		every_capsule_clear,
		"production player capsule clears the complete central-deck launch threshold"
	)

	var flight_ray := PhysicsRayQueryParameters3D.create(
		launch.to_global(Vector3(0.0, 2.5, -62.0)),
		launch.to_global(Vector3(0.0, 2.5, -69.0)),
		PhysicsLayers.WORLD
	)
	flight_ray.collide_with_bodies = true
	flight_ray.collide_with_areas = false
	await physics_frame
	_check(
		world.get_world_3d().direct_space_state.intersect_ray(flight_ray).is_empty(),
		"published launch aim remains physically unobstructed beneath the presentation-only gantry"
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
		print("LAUNCH_SIGNAL_GANTRY_CURVE_TEST_OK")
		quit(0)
	else:
		print("LAUNCH_SIGNAL_GANTRY_CURVE_TEST_FAILED: ", "; ".join(_failures))
		quit(1)
