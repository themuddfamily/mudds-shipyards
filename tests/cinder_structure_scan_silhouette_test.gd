extends SceneTree

## Focused shape-only proof for Cinder's retained abandoned-structure scanner.
## The production approach looks down -Z, so X/Y extents are the gameplay
## silhouette rather than a colour, lamp, HUD, or scan-authority signal.

const CLUSTER_SCENE := preload("res://scenes/world/components/nearby_sector_cluster.tscn")

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var cluster := CLUSTER_SCENE.instantiate() as NearbySectorCluster
	root.add_child(cluster)
	await process_frame
	var binding := cluster.get_node(^"ActivityBinding")
	var presentation := cluster.get_node(
		^"ExtractionPlatform/CinderReachPlatform/AbandonedStructureScanPresentation"
	) as Node3D
	var receiver := presentation.get_node(^"DeadArrayReceiver") as MeshInstance3D
	var collar := presentation.get_node(^"DeadArrayCollar") as MeshInstance3D
	var initial_nodes := presentation.find_children("*", "", true, false).size()
	var initial_meshes := presentation.find_children("*", "MeshInstance3D", true, false).size()
	var initial_receiver_id := receiver.get_instance_id()
	var initial_collar_id := collar.get_instance_id()

	var available := cluster.get_structure_scan_presentation_state()
	var available_extent := _approach_extent(receiver)
	_check(
		available.state_shape_id == &"compact_aperture"
			and is_equal_approx(available_extent.x, available_extent.y),
		"available reads as the compact circular aperture from the gameplay approach"
	)

	var started: Dictionary = binding.call(
		"start_structure_scan", CinderAbandonedStructureScanActivity.APPROACH_ANCHOR
	)
	var scanning := cluster.get_structure_scan_presentation_state()
	var scanning_extent := _approach_extent(receiver)
	_check(
		bool(started.get("accepted", false))
			and scanning.state_shape_id == &"broad_sweep_plate"
			and scanning_extent.x > available_extent.x * 2.0
			and scanning_extent.y < available_extent.y * 0.65
			and receiver.scale.is_equal_approx(NearbySectorCluster.STRUCTURE_SCAN_ACTIVE_RECEIVER_SCALE)
			and collar.scale.is_equal_approx(NearbySectorCluster.STRUCTURE_SCAN_ACTIVE_COLLAR_SCALE),
		"scanning widens into a flattened horizontal sweep plate without relying on lamp hue"
	)

	var completed: Dictionary = binding.call("advance_structure_scan", 4.0)
	var resolved := cluster.get_structure_scan_presentation_state()
	var resolved_extent := _approach_extent(receiver)
	_check(
		bool(completed.get("accepted", false))
			and resolved.state_shape_id == &"settled_resolved_datum"
			and resolved_extent.x > available_extent.x * 1.15
			and resolved_extent.y < available_extent.y * 0.6
			and scanning_extent.x > resolved_extent.x * 1.75
			and receiver.rotation_degrees.is_equal_approx(Vector3.ZERO),
		"completion settles into a resolved datum distinct from both compact and sweep silhouettes"
	)
	_check(
		receiver.get_instance_id() == initial_receiver_id
			and collar.get_instance_id() == initial_collar_id
			and presentation.find_children("*", "", true, false).size() == initial_nodes
			and presentation.find_children("*", "MeshInstance3D", true, false).size() == initial_meshes
			and bool(cluster.get_structure_scan_presentation_audit().valid),
		"all three silhouette reads reuse the existing visual roster with no authority or renderer growth"
	)
	cluster.queue_free()
	await process_frame
	_finish()


func _approach_extent(instance: MeshInstance3D) -> Vector2:
	var bounds := (instance.global_transform * instance.mesh.get_aabb()).abs()
	return Vector2(bounds.size.x, bounds.size.y)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
		push_error("CINDER_STRUCTURE_SCAN_SILHOUETTE_TEST_FAILED: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("CINDER_STRUCTURE_SCAN_SILHOUETTE_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	quit(1)
