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

	var first_report: Dictionary = first.get_hull_resource_sharing_audit()
	var second_report: Dictionary = second.get_hull_resource_sharing_audit()
	_check(bool(first_report.get("valid", false)) and bool(second_report.get("valid", false)), "both production bomber copies retain the exact immutable hull recipe")
	_check(
		int(first_report.get("mesh_resource_id", 0)) == int(second_report.get("mesh_resource_id", -1))
			and int(first_report.get("material_resource_id", 0)) == int(second_report.get("material_resource_id", -1)),
		"two bomber copies share one hull mesh and one hull material identity"
	)
	var legacy := first_report.get("legacy_two_copy", {}) as Dictionary
	var current := first_report.get("current_two_copy", {}) as Dictionary
	_check(
		int(legacy.get("unique_mesh_resources", -1)) == 2
			and int(current.get("unique_mesh_resources", -1)) == 1
			and int(legacy.get("unique_material_resources", -1)) == 2
			and int(current.get("unique_material_resources", -1)) == 1,
		"two-copy hull resources fall from two meshes/materials to one mesh/material"
	)
	_check(
		int(legacy.get("renderer_nodes", -1)) == 2
			and int(current.get("renderer_nodes", -1)) == 2
			and int(legacy.get("geometry_submissions", -1)) == 2
			and int(current.get("geometry_submissions", -1)) == 2,
		"resource sharing preserves both visible renderer nodes and structural submissions"
	)
	var first_ordnance := first_report.get("ordnance_spine", {}) as Dictionary
	var second_ordnance := second_report.get("ordnance_spine", {}) as Dictionary
	var legacy_ordnance := first_ordnance.get("legacy_two_copy", {}) as Dictionary
	var current_ordnance := first_ordnance.get("current_two_copy", {}) as Dictionary
	_check(
		int(first_ordnance.get("mesh_resource_id", 0)) \
				== int(second_ordnance.get("mesh_resource_id", -1))
			and int(first_ordnance.get("material_resource_id", 0)) \
				== int(second_ordnance.get("material_resource_id", -1)),
		"two bomber copies share one immutable ordnance-spine mesh and material identity"
	)
	_check(
		int(legacy_ordnance.get("unique_mesh_resources", -1)) == 2
			and int(current_ordnance.get("unique_mesh_resources", -1)) == 1
			and int(legacy_ordnance.get("unique_material_resources", -1)) == 2
			and int(current_ordnance.get("unique_material_resources", -1)) == 1
			and int(legacy_ordnance.get("renderer_nodes", -1)) == 2
			and int(current_ordnance.get("renderer_nodes", -1)) == 2
			and int(legacy_ordnance.get("geometry_submissions", -1)) == 2
			and int(current_ordnance.get("geometry_submissions", -1)) == 2,
		"ordnance-spine sharing cuts two-copy resource allocations in half without changing visible submissions"
	)
	var first_spine := first.get_variant_visual_root().get_node(^"OrdnanceSpine") as MeshInstance3D
	var second_spine := second.get_variant_visual_root().get_node(^"OrdnanceSpine") as MeshInstance3D
	_check(
		first_spine.position.is_equal_approx(Vector3(0.0, -0.15, 1.5))
			and second_spine.position.is_equal_approx(Vector3(0.0, -0.15, 1.5))
			and (first_spine.mesh as BoxMesh).size.is_equal_approx(Vector3(2.2, 1.25, 8.4))
			and first_spine.visible and second_spine.visible,
		"resource sharing preserves the bomber's exact visible ordnance-spine silhouette and placement"
	)
	_check(
		bool(first.get_landing_collision_report().get("valid", false))
			and bool(second.get_landing_collision_report().get("valid", false))
			and first.get_payload_hardpoints().size() == 4
			and second.get_payload_hardpoints().size() == 4
			and first.get_boarding_marker() != null
			and second.get_boarding_marker() != null,
		"sharing leaves collision, payload hardpoints and boarding anchors intact"
	)
	var first_audit: Dictionary = first.get_audit_report()
	var second_audit: Dictionary = second.get_audit_report()
	_check(
		bool(first_audit.get("valid", false)) and bool(second_audit.get("valid", false))
			and first_audit.get("evidence_status", &"") == &"NEW"
			and second_audit.get("evidence_status", &"") == &"NEW"
			and not bool(first_audit.get("network_authority", true))
			and not bool(second_audit.get("combat_authority", true)),
		"sharing preserves evidence tags and adds no network or combat authority"
	)

	first.queue_free()
	second.queue_free()
	await process_frame
	_check(not is_instance_valid(first) and not is_instance_valid(second), "both bomber copies cleanly leave the lifecycle while cached immutable resources remain process-owned")

	if _failures.is_empty():
		print("CINDER_BOMBER_RESOURCE_SHARING: hull/spine meshes 4->2 materials 4->2 nodes 4->4 submissions 4->4")
		print("PASS cinder_bomber_hull_resource_sharing_test (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
