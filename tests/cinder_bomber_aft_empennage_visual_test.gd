extends SceneTree

const Bomber := preload("res://scripts/ships/cinder_long_range_bomber.gd")

var _assertions := 0
var _failures: Array[String] = []


func _initialize() -> void:
	var first := Bomber.new() as CinderLongRangeBomber
	var second := Bomber.new() as CinderLongRangeBomber
	root.add_child(first)
	root.add_child(second)
	await process_frame

	var first_audit := first.get_aft_empennage_visual_audit()
	var second_audit := second.get_aft_empennage_visual_audit()
	_check(
		bool(first_audit.get("valid", false)) and bool(second_audit.get("valid", false)),
		"both Cinder bombers build the bounded twin-fin aft silhouette"
	)
	_check(
		int(first_audit.get("renderer_nodes_per_copy", 0)) == 3
			and int(first_audit.get("geometry_submissions_per_copy", 0)) == 3,
		"the empennage uses exactly three presentation renderers and submissions"
	)
	_check(
		int(first_audit.get("tailplane_mesh_resource_id", 0))
				== int(second_audit.get("tailplane_mesh_resource_id", -1))
			and int(first_audit.get("fin_mesh_resource_id", 0))
				== int(second_audit.get("fin_mesh_resource_id", -1)),
		"multiple bombers reuse the two immutable empennage meshes"
	)

	var visual := first.get_variant_visual_root()
	var tailplane := visual.get_node(^"LongRangeTailplane") as MeshInstance3D
	var port_fin := visual.get_node(^"PortBomberFin") as MeshInstance3D
	var starboard_fin := visual.get_node(^"StarboardBomberFin") as MeshInstance3D
	_check(
		port_fin.position.is_equal_approx(Vector3(-2.3, 1.25, 5.35))
			and starboard_fin.position.is_equal_approx(Vector3(2.3, 1.25, 5.35))
			and is_equal_approx(port_fin.rotation_degrees.z, 12.0)
			and is_equal_approx(starboard_fin.rotation_degrees.z, -12.0),
		"the warm twin fins retain their mirrored outward cant in the aft chase view"
	)
	var fin_mesh := port_fin.mesh as BoxMesh
	var tailplane_mesh := tailplane.mesh as BoxMesh
	var fin_outer_x := absf(port_fin.position.x) \
			+ absf(cos(deg_to_rad(port_fin.rotation_degrees.z))) * fin_mesh.size.x * 0.5 \
			+ absf(sin(deg_to_rad(port_fin.rotation_degrees.z))) * fin_mesh.size.y * 0.5
	var baseline_bounds := _merged_renderer_bounds(
		visual,
		[&"LongRangeTailplane", &"PortBomberFin", &"StarboardBomberFin"]
	)
	var empennage_bounds := _merged_renderer_bounds(
		visual,
		[],
		[&"LongRangeTailplane", &"PortBomberFin", &"StarboardBomberFin"]
	)
	_check(
		tailplane_mesh.size.x * 0.5 <= 4.3 + 0.001
			and fin_outer_x < 2.7
			and tailplane.position.z + tailplane_mesh.size.z * 0.5 < 7.75
			and port_fin.position.z + fin_mesh.size.z * 0.5 < 7.75
			and baseline_bounds.encloses(empennage_bounds),
		"the new recognition cue remains inside the bomber's existing visual footprint: %s encloses %s" % [
			baseline_bounds,
			empennage_bounds,
		]
	)
	_check(
		first.get_payload_hardpoints().size() == 4
			and bool(first.get_landing_collision_report().get("valid", false))
			and first.get_boarding_marker() != null
			and first.get_meta(&"evidence_status") == &"NEW",
		"the presentation slice preserves hardpoints, landing, boarding, and NEW status"
	)
	_check(
		int(first_audit.get("lights", -1)) == 0
			and int(first_audit.get("collision_shapes", -1)) == 0
			and int(first_audit.get("payload_hardpoints", -1)) == 0
			and not bool(first_audit.get("gameplay_authority", true))
			and tailplane.get_child_count() == 0
			and port_fin.get_child_count() == 0
			and starboard_fin.get_child_count() == 0,
		"the empennage adds no lights, collision, hardpoints, scripts, or authority"
	)

	first.queue_free()
	second.queue_free()
	await process_frame
	if _failures.is_empty():
		print("PASS cinder_bomber_aft_empennage_visual_test (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _merged_renderer_bounds(
		visual: Node3D,
		excluded_names: Array[StringName],
		included_names: Array[StringName] = []
	) -> AABB:
	var merged := AABB()
	var seeded := false
	var visual_inverse := visual.global_transform.affine_inverse()
	for child in visual.find_children("*", "Node3D", true, false):
		var renderer := child as Node3D
		if renderer == null:
			continue
		if excluded_names.has(renderer.name):
			continue
		if not included_names.is_empty() and not included_names.has(renderer.name):
			continue
		var local_transform := visual_inverse * renderer.global_transform
		if renderer is MeshInstance3D:
			var mesh_renderer := renderer as MeshInstance3D
			if mesh_renderer.mesh == null:
				continue
			var renderer_bounds := local_transform * mesh_renderer.mesh.get_aabb()
			merged = renderer_bounds if not seeded else merged.merge(renderer_bounds)
			seeded = true
		elif renderer is MultiMeshInstance3D:
			var batch := renderer as MultiMeshInstance3D
			var multimesh := batch.multimesh
			if multimesh == null or multimesh.mesh == null:
				continue
			# Headless does not expose the rendering-server buffer through
			# `get_instance_transform()`. The batch records the same transforms
			# used to encode that buffer, so merge each authored mesh AABB instead
			# of trusting the deliberately broader culling `custom_aabb`.
			var authored_transforms := \
					batch.get_meta(&"authored_instance_transforms", []) as Array
			var visible_count := multimesh.visible_instance_count
			var instance_count := authored_transforms.size() \
					if visible_count < 0 else mini(visible_count, authored_transforms.size())
			instance_count = mini(instance_count, multimesh.instance_count)
			for instance_index in instance_count:
				var instance_bounds := local_transform \
						* (authored_transforms[instance_index] as Transform3D) \
						* multimesh.mesh.get_aabb()
				merged = instance_bounds if not seeded else merged.merge(instance_bounds)
				seeded = true
	return merged
