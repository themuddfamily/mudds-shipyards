extends SceneTree

const ACTIVITY_SCENE := preload(
	"res://scenes/world/components/station_operations_activity.tscn"
)

const EXPECTED_SIZE := Vector3(0.26, 0.5, 0.03)
const EXPECTED_TRANSFORMS: Array[Transform3D] = [
	Transform3D(Basis.IDENTITY, Vector3(-0.32, 1.5, -0.325)),
	Transform3D(Basis.IDENTITY, Vector3(0.0, 1.5, -0.325)),
	Transform3D(Basis.IDENTITY, Vector3(0.32, 1.5, -0.325)),
]

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var activity := ACTIVITY_SCENE.instantiate() as StationOperationsActivity
	activity.activity_profile = StationOperationsActivity.ActivityProfile.SIGNAGE_PYLON
	root.add_child(activity)
	await process_frame

	var pylon := activity.get_node_or_null(
		^"PresentationRoot/WayfindingPylon"
	) as Node3D
	var sheets := activity.get_node_or_null(
		^"PresentationRoot/WayfindingPylon/NoticeSheets"
	) as MeshInstance3D
	_check(pylon != null and sheets != null, "signage pylon builds one notice-sheet renderer")
	if pylon == null or sheets == null or sheets.mesh == null:
		_finish()
		return

	var expected_bounds := AABB()
	var source_bounds := AABB(-EXPECTED_SIZE * 0.5, EXPECTED_SIZE)
	for index in EXPECTED_TRANSFORMS.size():
		var part_bounds := (EXPECTED_TRANSFORMS[index] * source_bounds).abs()
		expected_bounds = part_bounds if index == 0 else expected_bounds.merge(part_bounds)
	var authored := sheets.get_meta("authored_part_transforms", []) as Array
	var transforms_exact := authored.size() == EXPECTED_TRANSFORMS.size()
	for index in mini(authored.size(), EXPECTED_TRANSFORMS.size()):
		transforms_exact = transforms_exact and (
			authored[index] as Transform3D
		).is_equal_approx(EXPECTED_TRANSFORMS[index])
	_check(
		sheets.mesh.get_aabb().is_equal_approx(expected_bounds)
		and sheets.transform.is_equal_approx(Transform3D.IDENTITY)
		and sheets.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		and sheets.layers == 1
		and transforms_exact
		and int(sheets.get_meta("authored_visible_copy_count", 0)) == 3
		and sheets.get_meta("authored_visual_names", PackedStringArray())
			== PackedStringArray(["NoticeSheet", "NoticeSheet2", "NoticeSheet3"]),
		"composite preserves all three exact printed-sheet transforms, bounds, shadows and layer"
	)
	var ceramic_peer := pylon.get_node_or_null(
		"AnimatedIdentifierDrum/DrumBody"
	) as MeshInstance3D
	var material_ids := activity.get_material_catalog_audit().identity_by_key as Dictionary
	_check(
		sheets.material_override != null
		and sheets.material_override.get_instance_id() == int(material_ids.ceramic)
		and ceramic_peer != null
		and sheets.material_override == ceramic_peer.material_override,
		"notice sheets retain the shared ceramic presentation material"
	)
	_check(
		pylon.find_children("NoticeSheet*", "MeshInstance3D", false, false).size() == 1
		and sheets.get_child_count() == 0
		and sheets.get_script() == null
		and sheets.get_groups().is_empty()
		and sheets.find_children("*", "CollisionObject3D", true, false).is_empty()
		and sheets.find_children("*", "Area3D", true, false).is_empty(),
		"only three static visual leaves retire; the composite owns no authority or collision"
	)
	var counts := activity.get_performance_audit().counts as Dictionary
	_check(
		bool(activity.get_audit_report().valid)
		and int(counts.node_count) == 44
		and int(counts.mesh_instances) == 32
		and int(counts.multimesh_batches) == 0
		and int(counts.multimesh_instances) == 0
		and int(counts.geometry_submissions) == 32
		and int(counts.drawn_copies) == 33,
		"three notice-sheet nodes/submissions become one while all authored visible copies remain counted"
	)

	_finish()


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("STATION_OPERATIONS_NOTICE_SHEET_COMPOSITE_TEST_OK")
		quit(0)
	else:
		quit(1)
