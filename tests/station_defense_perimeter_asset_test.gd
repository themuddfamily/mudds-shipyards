extends SceneTree

const ASSET_SCENE := preload("res://scenes/activities/station_defense_perimeter_asset.tscn")

var _assertions := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var asset := ASSET_SCENE.instantiate() as StationDefensePerimeterAsset
	root.add_child(asset)
	await process_frame

	var ring := asset.get_node(^"Presentation/SignalRing") as MeshInstance3D
	var core := asset.get_node(^"Presentation/Core") as MeshInstance3D
	var collision := asset.get_node(^"CollisionShape3D") as CollisionShape3D
	var ring_id := ring.get_instance_id()
	var ring_mesh_id := ring.mesh.get_instance_id()
	var collision_id := collision.get_instance_id()
	var collision_shape_id := collision.shape.get_instance_id()
	var initial_child_count := asset.get_node(^"Presentation").get_child_count()
	var initial_collision_layer := asset.collision_layer
	var initial_collision_mask := asset.collision_mask
	var handle := asset.get_asset_handle()

	var toward_starboard := asset.apply_hostile_bearing_presentation_snapshot({
		"asset_handle": handle,
		"activity_generation": int(handle.generation),
		"active": true,
		"bearing_world": Vector3.RIGHT,
	})
	var starboard := asset.get_protected_asset_presentation_snapshot()
	_check(
		bool(toward_starboard.accepted)
		and bool(starboard.hostile_bearing_active)
		and is_equal_approx(float(starboard.ring_yaw), PI * 0.5)
		and ring.basis.y.normalized().is_equal_approx(Vector3.RIGHT)
		and (starboard.core_position as Vector3).is_equal_approx(Vector3(0.85, 2.65, 0.0)),
		"the existing vertical shield ring and core steadily face the supplied hostile approach"
	)

	var cleared := asset.apply_hostile_bearing_presentation_snapshot({
		"asset_handle": handle,
		"activity_generation": int(handle.generation),
		"active": false,
		"bearing_world": Vector3.ZERO,
	})
	var neutral := asset.get_protected_asset_presentation_snapshot()
	_check(
		bool(cleared.accepted)
		and not bool(neutral.hostile_bearing_active)
		and is_zero_approx(float(neutral.ring_yaw))
		and (neutral.core_position as Vector3).is_equal_approx(Vector3(0.0, 2.65, 0.0)),
		"clearing the caller-owned bearing returns the protected-asset beacon to neutral"
	)

	var budget := neutral.budget as Dictionary
	_check(
		ring.get_instance_id() == ring_id
		and ring.mesh.get_instance_id() == ring_mesh_id
		and collision.get_instance_id() == collision_id
		and collision.shape.get_instance_id() == collision_shape_id
		and asset.get_node(^"Presentation").get_child_count() == initial_child_count
		and asset.collision_layer == initial_collision_layer
		and asset.collision_mask == initial_collision_mask
		and int(budget.presentation_nodes) == 4
		and int(budget.mesh_instances) == 2
		and int(budget.lights) == 1
		and int(budget.process_callbacks) == 0
		and not bool(budget.runtime_node_allocation)
		and not bool(budget.runtime_resource_allocation),
		"the approach face reuses fixed presentation geometry without touching collision or authority"
	)

	asset.queue_free()
	await process_frame
	for failure in _failures:
		push_error(failure)
	if _failures.is_empty():
		print("STATION_DEFENSE_PERIMETER_ASSET_TEST_OK: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
