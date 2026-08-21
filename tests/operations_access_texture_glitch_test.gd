extends SceneTree

const ACTIVITY_SCENE := preload(
	"res://scenes/world/components/station_operations_activity.tscn"
)
const AFT_SCENE := preload("res://scenes/world/modules/aft_junction_stack.tscn")
const SERVICE_ARM_CAMERA_CLEARANCE_DISTANCE := 1.4
const PRODUCTION_CAMERA_NEAR := 0.08
const MINIMUM_CAMERA_SURFACE_CLEARANCE := 0.15
const WORLD_LAYER := PhysicsLayers.WORLD

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var activity := ACTIVITY_SCENE.instantiate() as StationOperationsActivity
	root.add_child(activity)
	await process_frame
	_test_service_arm_camera_clearance(activity)
	activity.queue_free()
	await process_frame

	var aft := AFT_SCENE.instantiate() as AftJunctionStack
	root.add_child(aft)
	await process_frame
	await physics_frame
	await physics_frame
	await _test_operations_access_floor_seam(aft)
	aft.queue_free()
	await process_frame

	if _failures.is_empty():
		print("OPERATIONS_ACCESS_TEXTURE_GLITCH_TEST_OK")
		quit(0)
	else:
		push_error(
			"OPERATIONS_ACCESS_TEXTURE_GLITCH_TEST_FAILED: %s"
			% ", ".join(_failures)
		)
		quit(1)


func _test_service_arm_camera_clearance(activity: StationOperationsActivity) -> void:
	var shoulder := activity.get_node(
		^"PresentationRoot/ArticulatedServiceArm/AnimatedShoulder"
	) as Node3D
	var guarded_mesh_count := 0
	var guard_complete := true
	var minimum_surface_clearance := INF
	for candidate in shoulder.find_children("*", "MeshInstance3D", true, false):
		var arm_mesh := candidate as MeshInstance3D
		guarded_mesh_count += 1
		var bounding_radius := 0.0
		for surface_index in arm_mesh.mesh.get_surface_count():
			var surface_arrays := arm_mesh.mesh.surface_get_arrays(surface_index)
			var vertices := surface_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
			for vertex in vertices:
				bounding_radius = maxf(
					bounding_radius,
					(arm_mesh.basis * vertex).length()
				)
		minimum_surface_clearance = minf(
			minimum_surface_clearance,
			SERVICE_ARM_CAMERA_CLEARANCE_DISTANCE
				- bounding_radius
				- PRODUCTION_CAMERA_NEAR
		)
		guard_complete = (
			guard_complete
			and is_equal_approx(
				arm_mesh.visibility_range_begin,
				SERVICE_ARM_CAMERA_CLEARANCE_DISTANCE
			)
			and is_zero_approx(arm_mesh.visibility_range_begin_margin)
			and arm_mesh.visibility_range_fade_mode
				== GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		)
	_check(
		guarded_mesh_count == 9 and guard_complete,
		"all nine animated service-arm meshes hard-cut before entering the camera"
	)
	_check(
		minimum_surface_clearance >= MINIMUM_CAMERA_SURFACE_CLEARANCE,
		"the guarded arm keeps at least 0.15 m beyond its radius and camera near plane"
	)
	var base_plate := activity.get_node(
		^"PresentationRoot/ArticulatedServiceArm/BasePlate"
	) as MeshInstance3D
	var rotary_base := activity.get_node(
		^"PresentationRoot/ArticulatedServiceArm/RotaryBase"
	) as MeshInstance3D
	_check(
		is_zero_approx(base_plate.visibility_range_begin)
		and is_zero_approx(rotary_base.visibility_range_begin),
		"both collision-backed pedestal meshes remain continuously visible"
	)
	var upper_arm := activity.get_node(
		^"PresentationRoot/ArticulatedServiceArm/AnimatedShoulder/UpperArm"
	) as MeshInstance3D
	upper_arm.visibility_range_begin = 0.0
	_check(
		not bool(activity.get_audit_report().valid),
		"the activity audit rejects removal of the service-arm camera guard"
	)
	upper_arm.visibility_range_begin = SERVICE_ARM_CAMERA_CLEARANCE_DISTANCE
	_check(
		bool(activity.get_audit_report().valid),
		"restoring the service-arm camera guard restores the activity audit"
	)


func _test_operations_access_floor_seam(aft: AftJunctionStack) -> void:
	var junction := aft.get_node(
		^"Structure/LowerOpenDeck/JunctionDeck"
	) as StaticBody3D
	var operations := aft.get_node(
		^"Structure/OperationsRoom/OperationsFloor"
	) as StaticBody3D
	var apron := aft.get_node(
		^"Structure/LowerOpenDeck/JunctionDeckWestApron"
	) as StaticBody3D
	var junction_box := (
		(junction.get_node(^"Collision") as CollisionShape3D).shape as BoxShape3D
	)
	var operations_box := (
		(operations.get_node(^"Collision") as CollisionShape3D).shape as BoxShape3D
	)
	var apron_box := (
		(apron.get_node(^"Collision") as CollisionShape3D).shape as BoxShape3D
	)
	var junction_north := junction.position.z + junction_box.size.z * 0.5
	var operations_south := operations.position.z - operations_box.size.z * 0.5
	_check(
		is_equal_approx(junction_north, 9.1)
		and is_equal_approx(operations_south, 9.1)
		and is_equal_approx(junction_north, operations_south)
		and is_equal_approx(apron.position.x - apron_box.size.x * 0.5, -5.5)
		and is_equal_approx(apron.position.x + apron_box.size.x * 0.5, 0.4)
		and is_equal_approx(apron.position.z - apron_box.size.z * 0.5, 9.1)
		and is_equal_approx(apron.position.z + apron_box.size.z * 0.5, 10.0)
		and is_equal_approx(apron.position.y + apron_box.size.y * 0.5, 0.0),
		"the junction, apron, and operations floor form exact non-overlapping bounds"
	)
	var junction_hit := await _ray_down(aft, Vector3(2.2, 2.0, 9.09))
	var operations_hit := await _ray_down(aft, Vector3(2.2, 2.0, 9.11))
	var apron_hit := await _ray_down(aft, Vector3(-2.0, 2.0, 9.5))
	_check(
		junction_hit.get("collider") == junction
		and operations_hit.get("collider") == operations
		and apron_hit.get("collider") == apron,
		"both sides of the seam and the retained west apron have physical support"
	)


func _ray_down(aft: AftJunctionStack, local_origin: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(
		aft.to_global(local_origin),
		aft.to_global(Vector3(local_origin.x, -1.0, local_origin.z)),
		WORLD_LAYER
	)
	return aft.get_world_3d().direct_space_state.intersect_ray(query)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		_failures.append(label)
		push_error("FAIL: " + label)
