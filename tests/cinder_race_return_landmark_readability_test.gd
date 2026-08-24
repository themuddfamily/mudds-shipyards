extends SceneTree

## Focused geometry/lifecycle proof for the Cinder Reach race-return landmark.

const CLUSTER_SCENE := preload("res://scenes/world/components/nearby_sector_cluster.tscn")
const PLATFORM_PATH := ^"ExtractionPlatform/CinderReachPlatform"
const SUPPORTS_PATH := ^"RaceReturnCrownSupports"
const HEADER_PATH := ^"RaceReturnCrownHeader"
const EXPECTED_HEADER_POSITION := Vector3(5.0, 54.0, -22.0)
const EXPECTED_HEADER_SIZE := Vector3(48.0, 4.0, 4.0)

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var cluster := CLUSTER_SCENE.instantiate() as NearbySectorCluster
	root.add_child(cluster)
	await process_frame
	var platform := cluster.get_node(PLATFORM_PATH) as Node3D
	var supports := platform.get_node_or_null(SUPPORTS_PATH) as MultiMeshInstance3D
	var header := platform.get_node_or_null(HEADER_PATH) as MeshInstance3D
	_check(
		supports != null and supports.multimesh != null and header != null,
		"the race endpoint builds one retained support batch and one header"
	)
	if supports == null or supports.multimesh == null or header == null:
		cluster.queue_free()
		await process_frame
		_finish()
		return

	var transforms := supports.get_meta(&"authored_instance_transforms", []) as Array
	_check(
		supports.multimesh.instance_count == 2
		and transforms.size() == 2
		and supports.get_meta(&"visual_batch_family_id", &"")
		== &"cinder-race-return-crown-supports",
		"two raked supports remain one bounded renderer submission"
	)
	var feet_supported := true
	var tops_meet_header := true
	for transform_value: Transform3D in transforms:
		var foot := transform_value.origin - transform_value.basis.y * 0.5
		var top := transform_value.origin + transform_value.basis.y * 0.5
		feet_supported = feet_supported \
			and foot.y <= 4.0 and absf(foot.x) <= 1.0 and is_equal_approx(foot.z, -22.0)
		tops_meet_header = tops_meet_header \
			and top.y >= 52.0 and absf(top.x) <= 20.0 and is_equal_approx(top.z, -22.0)
	_check(
		feet_supported and tops_meet_header,
		"both crown feet bury into the processing spine and meet the overhead header"
	)
	_check(
		header.position.is_equal_approx(EXPECTED_HEADER_POSITION)
		and header.mesh.get_aabb().size.is_equal_approx(EXPECTED_HEADER_SIZE),
		"the 48 m steady orange header stays readable above the low platform mass"
	)
	_check(
		supports.custom_aabb.position.z >= -24.01
		and supports.custom_aabb.end.z <= -19.99
		and header.position.z + header.mesh.get_aabb().end.z <= -19.99,
		"the entire crown stays behind the platform and outside the positive-Z approach lane"
	)
	_check(
		supports.get_meta(&"activity_id", &"") == &"cinder_reach_checkpoint_route"
		and header.get_meta(&"activity_id", &"") == &"cinder_reach_checkpoint_route"
		and bool(supports.get_meta(&"presentation_only", false))
		and bool(header.get_meta(&"presentation_only", false))
		and bool(supports.get_meta(&"physically_supported", false))
		and bool(header.get_meta(&"physically_supported", false)),
		"the crown identifies the existing authored race endpoint without claiming authority"
	)
	_check(
		supports.find_children("*", "CollisionObject3D", true, false).is_empty()
		and supports.find_children("*", "CollisionShape3D", true, false).is_empty()
		and header.find_children("*", "CollisionObject3D", true, false).is_empty()
		and platform.find_children("RaceReturnCrown*", "Light3D", true, false).is_empty()
		and platform.find_children("RaceReturnCrown*", "Timer", true, false).is_empty()
		and platform.find_children("RaceReturnCrown*", "AnimationPlayer", true, false).is_empty(),
		"the landmark adds no collision, light, timer, flashing, or animation path"
	)
	var retained_ids := [supports.get_instance_id(), header.get_instance_id()]
	cluster.set_cluster_enabled(false)
	cluster.set_cluster_enabled(true)
	_check(
		[platform.get_node(SUPPORTS_PATH).get_instance_id(), platform.get_node(HEADER_PATH).get_instance_id()]
		== retained_ids,
		"cluster streaming visibility reuses the exact landmark nodes"
	)
	var report: Dictionary = cluster.get_cluster_audit_report()
	if not bool(report.get("valid", false)):
		print("LANDMARK_AUDIT_ERRORS: ", report.get("errors", []))
	_check(
		bool(report.get("valid", false))
		and not bool(report.get("gameplay_authority", true))
		and not bool(report.get("grants_rewards", true)),
		"the production cluster remains within budget and authority-free"
	)

	cluster.queue_free()
	await process_frame
	_finish()


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", message)
	else:
		_failures.append(message)
		print("FAIL: ", message)


func _finish() -> void:
	print("CINDER_RACE_RETURN_LANDMARK_READABILITY_TEST_ASSERTIONS: ", _assertions)
	if _failures.is_empty():
		print("CINDER_RACE_RETURN_LANDMARK_READABILITY_TEST_OK")
		quit(0)
		return
	for failure in _failures:
		print("CINDER_RACE_RETURN_LANDMARK_READABILITY_TEST_FAILURE: ", failure)
	quit(1)
