extends SceneTree

## Focused contract for the render-only approach keyline on UpperOperations'
## observation landing. It may improve the ramp-to-console read, but it must not
## acquire collision, interaction, scripting, lifecycle, or route authority.

const WORLD_SCENE := preload("res://scenes/world/shipyard_world.tscn")
const KEYLINE_POSITION := Vector3(-11.5, 3.356, 3.62)
const KEYLINE_SIZE := Vector3(0.16, 0.016, 2.44)

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := WORLD_SCENE.instantiate() as ShipyardWorld
	_check(world != null, "production ShipyardWorld instantiates")
	if world == null:
		_finish()
		return
	root.add_child(world)
	await process_frame

	var upper := world.get_node_or_null(^"UpperOperations") as Node3D
	var keyline := upper.get_node_or_null(^"LandingApproachKeyline") as MeshInstance3D \
		if upper != null else null
	var orange_reference := upper.get_node_or_null(^"JunctionStairRail/Mesh") as MeshInstance3D \
		if upper != null else null
	var inset := upper.get_node_or_null(^"LandingDeckInset") as MeshInstance3D \
		if upper != null else null
	_check(
		keyline != null
		and keyline.position.is_equal_approx(KEYLINE_POSITION)
		and keyline.mesh is ArrayMesh
		and keyline.mesh.resource_name == "upper_operations_landing_approach_keyline_v1"
		and keyline.mesh.get_aabb().size.is_equal_approx(KEYLINE_SIZE)
		and orange_reference != null
		and keyline.material_override == orange_reference.material_override,
		"one bounded orange keyline continues the ramp centreline toward the console"
	)
	var keyline_bounds := _local_mesh_bounds(keyline)
	var inset_bounds := _local_mesh_bounds(inset)
	var support_audit := _mesh_support_audit(inset, keyline)
	_check(
		keyline != null
		and inset != null
		and keyline_bounds.position.x >= inset_bounds.position.x - 0.0001
		and keyline_bounds.end.x <= inset_bounds.end.x + 0.0001
		and keyline_bounds.position.z >= inset_bounds.position.z - 0.0001
		and keyline_bounds.end.z <= inset_bounds.end.z - 0.0099
		and int(support_audit.sample_count) > 0
		and int(support_audit.unsupported_count) == 0
		and float(support_audit.maximum_air_gap) <= 0.0001
		and float(support_audit.maximum_bearing) <= 0.0021,
		"every downward keyline vertex bears into the inset's actual rounded surface"
	)
	_check(
		keyline != null
		and keyline.get_child_count() == 0
		and keyline.get_script() == null
		and bool(keyline.get_meta("presentation_only", false))
		and StringName(keyline.get_meta("wayfinding_role", &"")) == &"ramp_to_observation_console"
		and not bool(keyline.get_meta("historical_form_identified", true)),
		"the keyline is childless, unscripted presentation with an honest modern role"
	)

	var landing := upper.get_node_or_null(^"ObservationLanding") as StaticBody3D \
		if upper != null else null
	var landing_collision := landing.get_node_or_null(^"Collision") as CollisionShape3D \
		if landing != null else null
	var landing_shape := landing_collision.shape as BoxShape3D \
		if landing_collision != null else null
	var ramp := upper.get_node_or_null(^"JunctionAccessRamp") as StaticBody3D \
		if upper != null else null
	_check(
		landing != null
		and landing.position.is_equal_approx(Vector3(-11.5, 3.05, 3.0))
		and landing_shape != null
		and landing_shape.size.is_equal_approx(Vector3(4.6, 0.55, 4.4))
		and landing.collision_layer == PhysicsLayers.WORLD
		and landing.collision_mask == PhysicsLayers.NONE
		and ramp != null
		and bool(ramp.get_meta("continuous_player_stair", false))
		and ramp.collision_layer == PhysicsLayers.WORLD
		and ramp.collision_mask == PhysicsLayers.NONE,
		"the landing collider and continuous access-ramp authority remain unchanged"
	)

	world.queue_free()
	for frame in 3:
		await process_frame
		await physics_frame
	_finish()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("UPPER_OPERATIONS_LANDING_WAYFINDING_TEST_OK")
		quit(0)
	else:
		push_error("%d upper-operations landing assertion(s) failed" % _failures.size())
		quit(1)


func _local_mesh_bounds(instance: MeshInstance3D) -> AABB:
	if instance == null or instance.mesh == null:
		return AABB()
	return AABB(instance.position + instance.mesh.get_aabb().position, instance.mesh.get_aabb().size)


func _mesh_support_audit(support: MeshInstance3D, mounted: MeshInstance3D) -> Dictionary:
	var report := {
		"sample_count": 0,
		"unsupported_count": 0,
		"maximum_air_gap": 0.0,
		"maximum_bearing": 0.0,
	}
	if support == null or support.mesh == null or mounted == null or mounted.mesh == null:
		report.unsupported_count = 1
		return report
	var arrays := mounted.mesh.surface_get_arrays(0)
	var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var normals := arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
	for index in vertices.size():
		if normals[index].y >= -0.05:
			continue
		report.sample_count += 1
		var point := mounted.transform * vertices[index]
		var support_y := _highest_mesh_y_at(support, Vector2(point.x, point.z))
		if is_nan(support_y):
			report.unsupported_count += 1
			continue
		report.maximum_air_gap = maxf(
			float(report.maximum_air_gap), point.y - support_y
		)
		report.maximum_bearing = maxf(
			float(report.maximum_bearing), support_y - point.y
		)
	return report


func _highest_mesh_y_at(instance: MeshInstance3D, point: Vector2) -> float:
	var faces := instance.mesh.get_faces()
	var highest := NAN
	for index in range(0, faces.size(), 3):
		var a := instance.transform * faces[index]
		var b := instance.transform * faces[index + 1]
		var c := instance.transform * faces[index + 2]
		var ab := Vector2(b.x - a.x, b.z - a.z)
		var ac := Vector2(c.x - a.x, c.z - a.z)
		var ap := point - Vector2(a.x, a.z)
		var denominator := ab.x * ac.y - ac.x * ab.y
		if absf(denominator) <= 0.0000001:
			continue
		var u := (ap.x * ac.y - ac.x * ap.y) / denominator
		var v := (ab.x * ap.y - ap.x * ab.y) / denominator
		if u < -0.0001 or v < -0.0001 or u + v > 1.0001:
			continue
		var candidate_y := a.y + u * (b.y - a.y) + v * (c.y - a.y)
		if is_nan(highest) or candidate_y > highest:
			highest = candidate_y
	return highest
