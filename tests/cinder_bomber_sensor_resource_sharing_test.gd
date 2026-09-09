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

	var first_report: Dictionary = first.get_sensor_resource_sharing_audit()
	var second_report: Dictionary = second.get_sensor_resource_sharing_audit()
	_check(
		bool(first_report.get("valid", false)) and bool(second_report.get("valid", false)),
		"both production bomber copies retain the exact immutable sensor recipe"
	)
	_check(
		int(first_report.get("mesh_resource_id", 0)) \
				== int(second_report.get("mesh_resource_id", -1))
			and int(first_report.get("material_resource_id", 0)) \
				== int(second_report.get("material_resource_id", -1)),
		"two bomber copies share one sensor mesh and one optical material identity"
	)
	var legacy := first_report.get("legacy_two_copy", {}) as Dictionary
	var current := first_report.get("current_two_copy", {}) as Dictionary
	_check(
		int(legacy.get("unique_mesh_resources", -1)) == 2
			and int(current.get("unique_mesh_resources", -1)) == 1
			and int(legacy.get("unique_material_resources", -1)) == 2
			and int(current.get("unique_material_resources", -1)) == 1
			and int(legacy.get("renderer_nodes", -1)) == 2
			and int(current.get("renderer_nodes", -1)) == 2
			and int(legacy.get("geometry_submissions", -1)) == 2
			and int(current.get("geometry_submissions", -1)) == 2,
		"sensor sharing halves two-copy resource allocations without changing submissions"
	)

	var first_sensor := first.get_variant_visual_root().get_node(^"LongRangeSensor") \
			as MeshInstance3D
	var second_sensor := second.get_variant_visual_root().get_node(^"LongRangeSensor") \
			as MeshInstance3D
	var sensor_mesh := first_sensor.mesh as ArrayMesh
	var sensor_material := first_sensor.material_override as StandardMaterial3D
	_check(
		first_sensor.position.is_equal_approx(Bomber.SENSOR_POSITION)
			and second_sensor.position.is_equal_approx(Bomber.SENSOR_POSITION)
			and first_sensor.scale.is_equal_approx(Bomber.SENSOR_SCALE)
			and second_sensor.scale.is_equal_approx(Bomber.SENSOR_SCALE)
			and sensor_mesh.get_surface_count() == 1
			and sensor_material.albedo_color.is_equal_approx(Bomber.SENSOR_COLOR)
			and not sensor_material.emission_enabled
			and is_equal_approx(sensor_material.metallic, 0.35),
		"sharing preserves recessed sensor placement, color and nonemissive finish"
	)
	var first_cowl := first.get_variant_visual_root().get_node(^"SensorProtectiveCowl") as MeshInstance3D
	var second_cowl := second.get_variant_visual_root().get_node(^"SensorProtectiveCowl") as MeshInstance3D
	_check(first_cowl.mesh == second_cowl.mesh and first_cowl.mesh.get_surface_count() == 3,
		"formed mounting, gaskets and hardware use three shared material surfaces")
	_check(first_cowl.layers == Bomber.EXTERIOR_SENSOR_VISUAL_LAYER
		and first_cowl.position.is_equal_approx(Bomber.SENSOR_POSITION)
		and first_cowl.get_child_count() == 0 and first_cowl.get_script() == null,
		"the fitted cowl retains exterior-only presentation without gameplay children")
	for stock: ArrayMesh in [sensor_mesh, first_cowl.mesh]:
		for surface in stock.get_surface_count():
			var arrays := stock.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
			_check(normals.size() == vertices.size() and uv.size() == vertices.size()
				and tangents.size() == vertices.size() * 4,
				"each new construction surface retains normals, UVs and tangent frames")

	var first_cockpit := first.find_child("CockpitCamera", true, false) as Camera3D
	var first_chase := first.find_child("ShipCamera", true, false) as Camera3D
	_check(
		first_sensor.layers == Bomber.EXTERIOR_SENSOR_VISUAL_LAYER
			and first_cockpit != null
			and (first_cockpit.cull_mask & Bomber.EXTERIOR_SENSOR_VISUAL_LAYER) == 0
			and first_chase != null
			and (first_chase.cull_mask & Bomber.EXTERIOR_SENSOR_VISUAL_LAYER) != 0
			and bool(first_report.get("cockpit_omits_sensor", false))
			and bool(first_report.get("chase_retains_sensor", false)),
		"the recessed dorsal sensor remains in exterior views but no longer blocks the cockpit"
	)
	_check(
		bool(first.get_landing_collision_report().get("valid", false))
			and bool(second.get_landing_collision_report().get("valid", false))
			and first.get_payload_hardpoints().size() == 4
			and second.get_payload_hardpoints().size() == 4
			and first.get_boarding_marker() != null
			and second.get_boarding_marker() != null
			and first.get_cockpit_seat_anchor() != null
			and second.get_cockpit_seat_anchor() != null,
		"sharing leaves collision, payload hardpoints, cockpit and boarding anchors intact"
	)
	_check(
		bool(first.get_audit_report().get("valid", false))
			and bool(second.get_audit_report().get("valid", false))
			and not bool(first.get_audit_report().get("network_authority", true))
			and not bool(second.get_audit_report().get("combat_authority", true)),
		"sharing preserves component validity and adds no network or combat authority"
	)

	first.queue_free()
	second.queue_free()
	await process_frame
	_check(
		not is_instance_valid(first) and not is_instance_valid(second),
		"both bomber copies cleanly leave the lifecycle while cached sensor stock remains process-owned"
	)

	if _failures.is_empty():
		print("CINDER_BOMBER_SENSOR_SHARING: meshes 2->1 materials 2->1 nodes 2->2 submissions 2->2")
		print("PASS cinder_bomber_sensor_resource_sharing_test (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
