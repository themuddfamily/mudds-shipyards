extends SceneTree

const ACTIVITY_SCENE := preload(
	"res://scenes/world/components/station_operations_activity.tscn"
)
const AFT_SCENE := preload("res://scenes/world/modules/aft_junction_stack.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const SERVICE_ARM_CAMERA_CLEARANCE_DISTANCE := 5.1
const SERVICE_ARM_MAXIMUM_PAIRWISE_SURFACE_ORIGIN_SPAN := 4.835124
const SERVICE_ARM_MAXIMUM_PAIRWISE_SPAN_TIME := 6.13477
const SAFETY_BEACON_CAMERA_CLEARANCE_DISTANCE := 0.61
const SAFETY_BEACON_MAXIMUM_PAIRWISE_SURFACE_ORIGIN_SPAN := 0.376431
const MINIMUM_CAMERA_SURFACE_CLEARANCE := 0.15
const WORLD_LAYER := PhysicsLayers.WORLD

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var player := PLAYER_SCENE.instantiate() as PlayerController
	var production_camera := player.get_node(
		^"CameraRig/CameraYaw/CameraPitch/SpringArm3D/PlayerCamera"
	) as Camera3D
	var production_camera_near := production_camera.near
	player.free()

	var activity := ACTIVITY_SCENE.instantiate() as StationOperationsActivity
	activity.activity_profile = StationOperationsActivity.ActivityProfile.SERVICE_ARM
	activity.variation_seed = 2207
	activity.starts_paused = true
	root.add_child(activity)
	await process_frame
	await _test_service_arm_camera_clearance(activity, production_camera_near)
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


func _test_service_arm_camera_clearance(
		activity: StationOperationsActivity,
		production_camera_near: float
	) -> void:
	var shoulder := activity.get_node(
		^"PresentationRoot/ArticulatedServiceArm/AnimatedShoulder"
	) as Node3D
	var arm_meshes: Array[MeshInstance3D] = []
	var hard_guard_complete := true
	for candidate in shoulder.find_children("*", "MeshInstance3D", true, false):
		var arm_mesh := candidate as MeshInstance3D
		arm_meshes.append(arm_mesh)
		hard_guard_complete = (
			hard_guard_complete
			and is_equal_approx(
				arm_mesh.visibility_range_begin,
				SERVICE_ARM_CAMERA_CLEARANCE_DISTANCE
			)
			and is_zero_approx(arm_mesh.visibility_range_begin_margin)
			and is_zero_approx(arm_mesh.visibility_range_end)
			and is_zero_approx(arm_mesh.visibility_range_end_margin)
			and arm_mesh.visibility_range_fade_mode
				== GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
			and arm_mesh.visibility_parent == NodePath()
		)
	_check(
		arm_meshes.size() == 9
		and hard_guard_complete
		and shoulder.get_node_or_null(^"WholeAssemblyCameraGuard") == null,
		"all nine animated service-arm renderers use the supported direct hard "
		+ "near-distance guard with no broken HLOD proxy"
	)
	activity.set_activity_time(SERVICE_ARM_MAXIMUM_PAIRWISE_SPAN_TIME)
	var maximum_pairwise_span := _maximum_pairwise_surface_origin_span(arm_meshes)
	_check(
		is_equal_approx(
			maximum_pairwise_span,
			SERVICE_ARM_MAXIMUM_PAIRWISE_SURFACE_ORIGIN_SPAN
		)
		and SERVICE_ARM_CAMERA_CLEARANCE_DISTANCE
			- maximum_pairwise_span
			- production_camera_near
			>= MINIMUM_CAMERA_SURFACE_CLEARANCE,
		"the direct arm guard covers the exact worst animated surface-to-remote-origin "
		+ "span with at least 0.15 m beyond the live production near plane "
		+ "(span %.6f m, near %.3f m)" % [maximum_pairwise_span, production_camera_near]
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
		"the activity audit rejects removing one renderer's direct arm guard"
	)
	upper_arm.visibility_range_begin = SERVICE_ARM_CAMERA_CLEARANCE_DISTANCE
	_check(bool(activity.get_audit_report().valid), "restoring the direct arm guard restores the activity audit")

	_test_safety_beacon_camera_clearance(activity, production_camera_near)

	root.remove_child(activity)
	root.add_child(activity)
	await process_frame
	var guards_survived_reentry := true
	for arm_mesh in arm_meshes:
		guards_survived_reentry = (
			guards_survived_reentry
			and is_equal_approx(
				arm_mesh.visibility_range_begin,
				SERVICE_ARM_CAMERA_CLEARANCE_DISTANCE
			)
			and arm_mesh.visibility_parent == NodePath()
		)
	_check(
		bool(activity.get_audit_report().valid)
		and guards_survived_reentry,
		"detach and re-entry preserve all nine supported direct arm guards"
	)


func _test_safety_beacon_camera_clearance(
		activity: StationOperationsActivity,
		production_camera_near: float
	) -> void:
	var guard_complete := true
	var guarded_mesh_count := 0
	var maximum_pairwise_span := 0.0
	for beacon_index in 4:
		var beacon := activity.get_node(
			NodePath("PresentationRoot/SafetyBeacon%02d" % (beacon_index + 1))
		) as Node3D
		var beacon_meshes: Array[MeshInstance3D] = [
			beacon.get_node(^"Base") as MeshInstance3D,
			beacon.get_node(^"Lens") as MeshInstance3D,
		]
		for beacon_mesh in beacon_meshes:
			guarded_mesh_count += 1
			guard_complete = (
				guard_complete
				and is_equal_approx(
					beacon_mesh.visibility_range_begin,
					SAFETY_BEACON_CAMERA_CLEARANCE_DISTANCE
				)
				and is_zero_approx(beacon_mesh.visibility_range_begin_margin)
				and is_zero_approx(beacon_mesh.visibility_range_end)
				and is_zero_approx(beacon_mesh.visibility_range_end_margin)
				and beacon_mesh.visibility_range_fade_mode
					== GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
				and beacon_mesh.visibility_parent == NodePath()
			)
		maximum_pairwise_span = maxf(
			maximum_pairwise_span,
			_maximum_pairwise_surface_origin_span(beacon_meshes)
		)
	_check(
		guarded_mesh_count == 8
		and guard_complete
		and is_equal_approx(
			maximum_pairwise_span,
			SAFETY_BEACON_MAXIMUM_PAIRWISE_SURFACE_ORIGIN_SPAN
		)
		and SAFETY_BEACON_CAMERA_CLEARANCE_DISTANCE
			- maximum_pairwise_span
			- production_camera_near
			>= MINIMUM_CAMERA_SURFACE_CLEARANCE,
		"all four collision-free Base+Lens assemblies hard-cut before the live "
		+ "production near plane with at least 0.15 m reserve "
		+ "(span %.6f m, near %.3f m)" % [maximum_pairwise_span, production_camera_near]
	)
	var lens := activity.get_node(
		^"PresentationRoot/SafetyBeacon01/Lens"
	) as MeshInstance3D
	lens.visibility_range_begin = 0.0
	_check(
		not bool(activity.get_audit_report().valid),
		"the activity audit rejects removing a beacon Lens guard"
	)
	lens.visibility_range_begin = SAFETY_BEACON_CAMERA_CLEARANCE_DISTANCE
	_check(
		bool(activity.get_audit_report().valid),
		"restoring the beacon Lens guard restores the activity audit"
	)


func _maximum_pairwise_surface_origin_span(
		meshes: Array[MeshInstance3D]
	) -> float:
	var maximum := 0.0
	for source_mesh in meshes:
		for surface_index in source_mesh.mesh.get_surface_count():
			var surface_arrays := source_mesh.mesh.surface_get_arrays(surface_index)
			for vertex in surface_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array:
				var surface_point := source_mesh.global_transform * vertex
				for target_mesh in meshes:
					maximum = maxf(
						maximum,
						surface_point.distance_to(target_mesh.global_position)
					)
	return maximum


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
