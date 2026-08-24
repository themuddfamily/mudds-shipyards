extends SceneTree

const PRESENTATION_BUILDER := preload(
	"res://scripts/world/station_operations_activity_presentation_builder.gd"
)
const PRODUCTION_PROFILES: Array[StringName] = [
	&"full",
	&"gantry",
	&"service_arm",
	&"drone_patrol",
	&"cargo_line",
	&"signage_pylon",
	&"observatory",
	&"crew_workpost",
	&"cargo_line_long",
	&"cargo_line_long",
]

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var shared_materials: Dictionary = {}
	var visible_copy_count := 0
	var unique_mesh_ids: Dictionary = {}
	var copies_exact := true
	var authority_clean := true
	for profile_id in PRODUCTION_PROFILES:
		var presentation_root := Node3D.new()
		root.add_child(presentation_root)
		var builder := PRESENTATION_BUILDER.new()
		builder.build(presentation_root, profile_id, 2, 0.09, shared_materials)
		if shared_materials.is_empty():
			shared_materials = builder.get_materials()
		var beacons := presentation_root.find_children(
			"SafetyBeacon*", "Node3D", false, false
		)
		copies_exact = copies_exact and beacons.size() == 4
		for beacon_candidate in beacons:
			var beacon := beacon_candidate as Node3D
			var base := beacon.get_node_or_null("Base") as MeshInstance3D
			copies_exact = copies_exact and (
				base != null
				and base.position.is_equal_approx(Vector3.ZERO)
				and base.rotation_degrees.is_equal_approx(Vector3.ZERO)
				and base.mesh != null
				and base.mesh.get_aabb().size.is_equal_approx(Vector3(0.48, 0.18, 0.48))
				and base.material_override == shared_materials["graphite"]
				and base.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				and base.layers == 1
			)
			if base == null:
				continue
			visible_copy_count += 1
			authority_clean = authority_clean and (
				base.get_child_count() == 0
				and base.get_script() == null
				and base.get_groups().is_empty()
				and base.find_children("*", "CollisionObject3D", true, false).is_empty()
				and base.find_children("*", "Area3D", true, false).is_empty()
			)
			unique_mesh_ids[base.mesh.get_instance_id()] = true
		presentation_root.queue_free()

	_check(
		visible_copy_count == 40 and copies_exact,
		"all forty named production-roster bases retain their transforms, dimensions, material and render settings"
	)
	_check(
		authority_clean,
		"beacon bases remain childless visual leaves with no collision or activity authority"
	)
	_check(
		unique_mesh_ids.size() == 1,
		"ten production builders share one immutable beacon-base mesh allocation"
	)
	if _failures.is_empty():
		print("STATION_OPERATIONS_BEACON_BASE_MESH_SHARING_TEST_OK")
		quit(0)
	else:
		quit(1)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)
