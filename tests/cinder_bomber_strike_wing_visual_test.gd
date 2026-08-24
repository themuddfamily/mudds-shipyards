extends SceneTree

const Bomber := preload("res://scripts/ships/cinder_long_range_bomber.gd")

var _assertions := 0
var _failures: Array[String] = []


func _initialize() -> void:
	var first := Bomber.new()
	var second := Bomber.new()
	root.add_child(first)
	root.add_child(second)
	await process_frame

	var first_audit: Dictionary = first.get_strike_wing_visual_audit()
	var second_audit: Dictionary = second.get_strike_wing_visual_audit()
	_check(
		bool(first_audit.get("valid", false)) and bool(second_audit.get("valid", false)),
		"both bombers build the mirrored swept strike-wing silhouette"
	)
	_check(
		int(first_audit.get("renderer_nodes_per_copy", 0)) == 2
			and int(first_audit.get("geometry_submissions_per_copy", 0)) == 2,
		"the silhouette uses exactly two presentation-only renderers and submissions"
	)
	_check(
		int(first_audit.get("shared_mesh_resource_id", 0))
				== int(second_audit.get("shared_mesh_resource_id", -1))
			and int(first_audit.get("shared_hull_material_resource_id", 0))
				== int(second_audit.get("shared_hull_material_resource_id", -1)),
		"the wing pair and both bomber copies reuse one immutable mesh and the hull material"
	)

	var visual := first.get_variant_visual_root()
	var port := visual.get_node(^"PortStrikeWing") as MeshInstance3D
	var starboard := visual.get_node(^"StarboardStrikeWing") as MeshInstance3D
	_check(
		port.position.is_equal_approx(Vector3(-5.15, -0.45, 0.65))
			and starboard.position.is_equal_approx(Vector3(5.15, -0.45, 0.65))
			and is_equal_approx(port.rotation_degrees.y, -12.0)
			and is_equal_approx(starboard.rotation_degrees.y, 12.0),
		"the port and starboard wings retain their readable mirrored sweep"
	)
	_check(
		port.get_child_count() == 0 and starboard.get_child_count() == 0
			and port.get_script() == null and starboard.get_script() == null
			and first.get_payload_hardpoints().size() == 4
			and bool(first.get_landing_collision_report().get("valid", false))
			and first.get_boarding_marker() != null,
		"the visual-only wings add no authority and preserve hardpoints, collision and boarding"
	)

	first.queue_free()
	second.queue_free()
	await process_frame
	if _failures.is_empty():
		print("PASS cinder_bomber_strike_wing_visual_test (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
