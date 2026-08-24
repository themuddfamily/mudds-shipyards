extends SceneTree

## Focused presentation contract for Dock Operations' mapped grip-floor inset.
## The inset may improve material and edge hierarchy, but the original pod slab
## remains the sole collision, route, interaction, and lifecycle authority.

const WORLD_SCENE := preload("res://scenes/world/shipyard_world.tscn")
const FLOOR_POSITION := Vector3(43.0, 0.18, 27.0)
const FLOOR_SIZE := Vector3(12.0, 0.4, 8.0)
const INSET_POSITION := Vector3(43.0, 0.3875, 27.0)
const INSET_SIZE := Vector3(11.2, 0.025, 7.2)

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
	var floor := upper.get_node_or_null(^"OperationsPodFloor") as StaticBody3D \
		if upper != null else null
	var floor_mesh := floor.get_node_or_null(^"Mesh") as MeshInstance3D \
		if floor != null else null
	var floor_collision := floor.get_node_or_null(^"Collision") as CollisionShape3D \
		if floor != null else null
	var floor_shape := floor_collision.shape as BoxShape3D \
		if floor_collision != null else null
	var inset := upper.get_node_or_null(^"OperationsPodFloorInset") as MeshInstance3D \
		if upper != null else null
	var materials := world.get("_materials") as Dictionary

	_check(
		floor != null
		and floor.position.is_equal_approx(FLOOR_POSITION)
		and floor_mesh != null
		and floor_mesh.mesh.get_aabb().size.is_equal_approx(FLOOR_SIZE)
		and floor_shape != null
		and floor_shape.size.is_equal_approx(FLOOR_SIZE)
		and floor.collision_layer == PhysicsLayers.WORLD
		and floor.collision_mask == PhysicsLayers.NONE,
		"the original pod slab transform, bounds, and sole world collision remain frozen"
	)
	_check(
		inset != null
		and inset.position.is_equal_approx(INSET_POSITION)
		and inset.mesh is ArrayMesh
		and inset.mesh.resource_name == "operations_pod_floor_inset_v1"
		and inset.mesh.get_aabb().size.is_equal_approx(INSET_SIZE)
		and inset.material_override == materials.get("deck"),
		"one bounded dark grip inset covers the high-area pod floor inside its light edge"
	)
	var inset_material := inset.material_override as StandardMaterial3D \
		if inset != null else null
	_check(
		inset_material != null
		and inset_material.albedo_texture != null
		and inset_material.albedo_texture.resource_path == StationSurfaceKit.PANEL_ALBEDO_PATH
		and inset_material.normal_texture != null
		and inset_material.normal_texture.resource_path == StationSurfaceKit.PANEL_NORMAL_PATH
		and inset_material.roughness_texture != null
		and inset_material.roughness_texture.resource_path == StationSurfaceKit.PANEL_ROUGHNESS_PATH
		and inset_material.uv1_triplanar
		and inset_material.uv1_world_triplanar
		and inset_material.uv1_scale.is_equal_approx(Vector3.ONE * 0.3),
		"the inset uses the established continuous station panel/normal/roughness recipe"
	)
	_check(
		inset != null
		and inset.get_child_count() == 0
		and inset.get_script() == null
		and bool(inset.get_meta("presentation_only", false))
		and StringName(inset.get_meta("surface_role", &"")) == &"mapped_grip_inset"
		and not bool(inset.get_meta("historical_form_identified", true))
		and inset.position.y - INSET_SIZE.y * 0.5 < FLOOR_POSITION.y + FLOOR_SIZE.y * 0.5
		and inset.position.y + INSET_SIZE.y * 0.5 > FLOOR_POSITION.y + FLOOR_SIZE.y * 0.5,
		"the render-only modern inset bears into the unchanged slab without authority"
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
		print("OPERATIONS_POD_FLOOR_MATERIAL_TEST_OK")
		quit(0)
	else:
		push_error("%d operations-pod floor assertion(s) failed" % _failures.size())
		quit(1)
