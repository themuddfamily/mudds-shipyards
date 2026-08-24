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
		"both bombers build the mirrored swept strike-wing silhouette: %s / %s" % [
			first_audit.get("errors", PackedStringArray()),
			second_audit.get("errors", PackedStringArray()),
		]
	)
	_check(
		int(first_audit.get("renderer_nodes_per_copy", 0)) == 1
			and int(first_audit.get("geometry_submissions_per_copy", 0)) == 1
			and int(first_audit.get("visible_instances_per_copy", 0)) == 2,
		"one presentation-only batch retains both visible wings in one renderer/submission"
	)
	_check(
		int(first_audit.get("shared_mesh_resource_id", 0))
				== int(second_audit.get("shared_mesh_resource_id", -1))
			and int(first_audit.get("shared_multimesh_resource_id", 0))
				== int(second_audit.get("shared_multimesh_resource_id", -1))
			and int(first_audit.get("shared_hull_material_resource_id", 0))
				== int(second_audit.get("shared_hull_material_resource_id", -1)),
		"both bomber copies reuse one immutable wing batch, mesh and hull material"
	)

	var visual := first.get_variant_visual_root()
	var batch := visual.get_node(^"StrikeWingBatch") as MultiMeshInstance3D
	var transforms := batch.get_meta(&"authored_instance_transforms", []) as Array
	var port := transforms[0] as Transform3D
	var starboard := transforms[1] as Transform3D
	_check(
		port.origin.is_equal_approx(Vector3(-5.15, -0.45, 0.65))
			and starboard.origin.is_equal_approx(Vector3(5.15, -0.45, 0.65))
			and port.basis.is_equal_approx(Basis(Vector3.UP, deg_to_rad(-12.0)))
			and starboard.basis.is_equal_approx(Basis(Vector3.UP, deg_to_rad(12.0))),
		"the port and starboard wings retain their readable mirrored sweep: %s / %s" % [
			port,
			starboard,
		]
	)
	_check(
		batch.get_child_count() == 0 and batch.get_script() == null
			and first.get_payload_hardpoints().size() == 4
			and bool(first.get_landing_collision_report().get("valid", false))
			and first.get_boarding_marker() != null,
		"the visual-only wings add no authority and preserve hardpoints, collision and boarding"
	)
	var legacy := first_audit.get("legacy_per_copy", {}) as Dictionary
	var current := first_audit.get("current_per_copy", {}) as Dictionary
	_check(
		int(legacy.get("renderer_nodes", -1)) == 2
			and int(current.get("renderer_nodes", -1)) == 1
			and int(legacy.get("geometry_submissions", -1)) == 2
			and int(current.get("geometry_submissions", -1)) == 1
			and int(legacy.get("visible_instances", -1)) == 2
			and int(current.get("visible_instances", -1)) == 2,
		"the measured trim is 2->1 renderer nodes and submissions with 2->2 visible wings"
	)

	first.queue_free()
	second.queue_free()
	await process_frame
	if _failures.is_empty():
		print("CINDER_BOMBER_STRIKE_WING_BATCH: nodes 2->1 submissions 2->1 visible wings 2->2")
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
