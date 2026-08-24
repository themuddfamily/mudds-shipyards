extends SceneTree

## Focused contract for the range drone's approach-facing acquisition frame.
## The polish is presentation beneath DroneVisual; the authoritative bodies,
## hit volumes, positions, IDs, and established shared mesh families stay exact.

const WORLD_SCENE := preload("res://scenes/world/shipyard_world.tscn")
const EXPECTED_TARGET_POSITIONS: Array[Vector3] = [
	Vector3(-13.0, 7.0, -95.0),
	Vector3(14.0, 11.0, -116.0),
	Vector3(-2.0, 1.5, -142.0),
	Vector3(22.0, -4.0, -165.0),
]
const EXPECTED_FRAME_NAMES: Array[StringName] = [
	&"ApproachFrameNorthEast",
	&"ApproachFrameSouthEast",
	&"ApproachFrameSouthWest",
	&"ApproachFrameNorthWest",
]
const EXPECTED_FRAME_POSITIONS: Array[Vector3] = [
	Vector3(2.0, 2.0, 0.32),
	Vector3(2.0, -2.0, 0.32),
	Vector3(-2.0, -2.0, 0.32),
	Vector3(-2.0, 2.0, 0.32),
]
const EXPECTED_FRAME_ROTATIONS: Array[float] = [-45.0, 45.0, -45.0, 45.0]
const EXPECTED_FRAME_SIZE := Vector3(5.656854, 0.14, 0.28)

var _assertions := 0
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

	var frame_mesh: Mesh = null
	var core_mesh: Mesh = null
	var lamp_mesh: Mesh = null
	for target_index in 4:
		var target := world.get_node_or_null(
			"ExteriorTargetRange/TargetDrone%02d" % (target_index + 1)
		) as StaticBody3D
		_check(target != null, "range target %02d remains present" % (target_index + 1))
		if target == null:
			continue
		_check_target_authority(target, target_index)

		var visual := target.get_node_or_null(^"DroneVisual") as Node3D
		_check(visual != null, "range target %02d retains DroneVisual" % (target_index + 1))
		if visual == null:
			continue
		var core := visual.get_node_or_null(^"Core") as MeshInstance3D
		_check(core != null, "range target %02d retains its core" % (target_index + 1))
		if core != null:
			core_mesh = _check_shared_mesh(core.mesh, core_mesh, "core", target_index)

		var target_lamps: Array[MeshInstance3D] = []
		for child in visual.get_children():
			if child is MeshInstance3D:
				var candidate := child as MeshInstance3D
				var sphere := candidate.mesh as SphereMesh
				if sphere != null \
						and is_equal_approx(sphere.radius, 0.22) \
						and is_equal_approx(sphere.height, 0.44):
					target_lamps.append(candidate)
		_check(target_lamps.size() == 4, "range target %02d retains four lamps" % (target_index + 1))
		for lamp in target_lamps:
			lamp_mesh = _check_shared_mesh(lamp.mesh, lamp_mesh, "lamp", target_index)

		for frame_index in EXPECTED_FRAME_NAMES.size():
			var frame_name := EXPECTED_FRAME_NAMES[frame_index]
			var frame := visual.get_node_or_null(NodePath(frame_name)) as MeshInstance3D
			_check(frame != null, "%s exists on range target %02d" % [frame_name, target_index + 1])
			if frame == null:
				continue
			frame_mesh = _check_shared_mesh(frame.mesh, frame_mesh, "approach frame", target_index)
			var frame_material := frame.material_override as StandardMaterial3D
			_check(
				bool(frame.get_meta(&"presentation_only", false))
				and not bool(frame.get_meta(&"gameplay_authority", true))
				and frame.get_child_count() == 0
				and frame.position.is_equal_approx(EXPECTED_FRAME_POSITIONS[frame_index])
				and is_equal_approx(frame.rotation_degrees.z, EXPECTED_FRAME_ROTATIONS[frame_index])
				and frame.mesh.get_aabb().size.is_equal_approx(EXPECTED_FRAME_SIZE)
				and frame_material != null
				and frame_material.emission_enabled
				and frame.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				and frame.gi_mode == GeometryInstance3D.GI_MODE_DISABLED,
				"%s is an exact childless emissive presentation bar" % frame_name
			)

	world.queue_free()
	await process_frame
	_finish()


func _check_target_authority(target: StaticBody3D, target_index: int) -> void:
	var collision_shapes := 0
	var hit_radius := -1.0
	for child in target.get_children():
		if child is CollisionShape3D:
			collision_shapes += 1
			var sphere := (child as CollisionShape3D).shape as SphereShape3D
			if sphere != null:
				hit_radius = sphere.radius
	_check(
		target.position.is_equal_approx(EXPECTED_TARGET_POSITIONS[target_index])
		and target.collision_layer == PhysicsLayers.TARGET
		and target.collision_mask == 0
		and target.get_meta(&"target_id", &"") == StringName("DRONE-%02d" % (target_index + 1))
		and target.is_in_group(&"shipyard_targets")
		and collision_shapes == 1
		and is_equal_approx(hit_radius, 2.35),
		"range target %02d keeps position, identity, group, and exact hit volume" % (target_index + 1)
	)


func _check_shared_mesh(candidate: Mesh, established: Mesh, family: String, target_index: int) -> Mesh:
	_check(candidate != null, "%s mesh exists on target %02d" % [family, target_index + 1])
	if established != null and candidate != null:
		_check(candidate == established, "%s mesh remains shared" % family)
	return candidate if established == null else established


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Exterior target range readability test passed: %d assertions" % _assertions)
		quit(0)
	else:
		print("Exterior target range readability test failed: %d failures / %d assertions" % [_failures.size(), _assertions])
		quit(1)
