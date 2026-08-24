extends SceneTree

## Exact geometry/lifecycle proof for Cinder Reach's port-side ore-lift landmark.

const CLUSTER_SCENE := preload("res://scenes/world/components/nearby_sector_cluster.tscn")
const LANDMARK_PATH := (
	^"ExtractionPlatform/CinderReachPlatform/MiningActivityPresentation/MiningOreLiftPick"
)
const EXPECTED_FAMILY_ID: StringName = &"cinder-mining-ore-lift-pick"
const EXPECTED_PLATFORM_RETURN_Z := 77.0

var _assertions := 0
var _failures: Array[String] = []
var _expected_transforms: Array[Transform3D] = [
	Transform3D(
		Basis.from_euler(Vector3(0.0, 0.0, deg_to_rad(23.749494)))
			* Basis.from_scale(Vector3(3.6, 54.626, 4.0)),
		Vector3(-14.0, 27.0, -6.0)
	),
	Transform3D(
		Basis.from_euler(Vector3(0.0, 0.0, deg_to_rad(26.565052)))
			* Basis.from_scale(Vector3(3.6, 46.957, 4.0)),
		Vector3(-7.5, 23.0, -6.0)
	),
	Transform3D(Basis.from_scale(Vector3(38.0, 3.6, 4.0)), Vector3(-29.0, 50.0, -6.0)),
	Transform3D(Basis.from_scale(Vector3(3.6, 28.0, 4.0)), Vector3(-45.0, 36.0, -6.0)),
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var cluster := CLUSTER_SCENE.instantiate() as NearbySectorCluster
	root.add_child(cluster)
	await process_frame
	var landmark := cluster.get_node_or_null(LANDMARK_PATH) as MultiMeshInstance3D
	_check(
		landmark != null and landmark.multimesh != null,
		"the production mining family builds one retained ore-lift batch"
	)
	if landmark == null or landmark.multimesh == null:
		cluster.queue_free()
		await process_frame
		_finish()
		return

	var transforms := landmark.get_meta(&"authored_instance_transforms", []) as Array
	print("CINDER_MINING_ORE_LIFT_BOUNDS: ", landmark.custom_aabb)
	_check(
		landmark.multimesh.instance_count == 4
		and landmark.multimesh.visible_instance_count in [-1, 4]
		and transforms == _expected_transforms
		and landmark.multimesh.buffer == _encode_transforms(_expected_transforms),
		"four authored members remain one exact renderer submission"
	)
	_check(
		landmark.custom_aabb.position.x <= -47.0
		and landmark.custom_aabb.end.y >= 52.0
		and landmark.custom_aabb.size.y >= 50.0,
		"the fixed pick silhouette rises above and outboard of the low platform mass"
	)
	var primary_stay := transforms[0] as Transform3D
	var secondary_stay := transforms[1] as Transform3D
	var primary_foot := primary_stay.origin - primary_stay.basis.y * 0.5
	var secondary_foot := secondary_stay.origin - secondary_stay.basis.y * 0.5
	_check(
		primary_foot.y <= 2.1 and absf(primary_foot.x + 3.0) <= 0.1
		and secondary_foot.y <= 2.1 and absf(secondary_foot.x - 3.0) <= 0.1
		and is_equal_approx(primary_foot.z, -6.0)
		and is_equal_approx(secondary_foot.z, -6.0),
		"both raked stays bury into the existing processing-spine footing"
	)
	_check(
		landmark.custom_aabb.end.z < 0.0
		and landmark.custom_aabb.end.z < EXPECTED_PLATFORM_RETURN_Z,
		"the entire mining pick stays aft of the positive-Z ship and activity lane"
	)
	_check(
		StringName(landmark.get_meta(&"visual_batch_family_id", &"")) == EXPECTED_FAMILY_ID
		and StringName(landmark.get_meta(&"activity_id", &""))
			== &"cinder_platform_mining_run"
		and bool(landmark.get_meta(&"presentation_only", false))
		and bool(landmark.get_meta(&"physically_supported", false))
		and bool(landmark.get_meta(&"approach_landmark", false)),
		"the supported landmark identifies the existing mining activity without owning it"
	)
	_check(
		landmark.find_children("*", "CollisionObject3D", true, false).is_empty()
		and landmark.find_children("*", "CollisionShape3D", true, false).is_empty()
		and landmark.find_children("*", "Area3D", true, false).is_empty()
		and landmark.find_children("*", "Light3D", true, false).is_empty()
		and landmark.find_children("*", "Timer", true, false).is_empty()
		and landmark.find_children("*", "AnimationPlayer", true, false).is_empty()
		and not landmark.is_processing()
		and not landmark.is_physics_processing(),
		"the steady landmark adds no collision, interaction, light, timer, animation, or process path"
	)
	var mining_state_before := cluster.get_mining_activity_presentation_state()
	var retained_id := landmark.get_instance_id()
	cluster.set_cluster_enabled(false)
	cluster.set_cluster_enabled(true)
	var retained := cluster.get_node_or_null(LANDMARK_PATH) as MultiMeshInstance3D
	_check(
		retained != null and retained.get_instance_id() == retained_id
		and cluster.get_mining_activity_presentation_state() == mining_state_before,
		"streaming visibility reuses the landmark and does not advance mining state"
	)
	var audit := cluster.get_mining_platform_presentation_audit()
	_check(
		bool(audit.get("valid", false))
		and not bool(audit.get("activity_authority", true))
		and not bool(audit.get("collision_authority", true))
		and not bool(audit.get("reward_authority", true))
		and int((audit.get("counts", {}) as Dictionary).get("surface_submissions", -1)) == 12,
		"the production mining audit stays authority-free at twelve total submissions"
	)

	cluster.queue_free()
	await process_frame
	_finish()


func _encode_transforms(transforms: Array[Transform3D]) -> PackedFloat32Array:
	var buffer := PackedFloat32Array()
	buffer.resize(transforms.size() * 12)
	for index in transforms.size():
		var value := transforms[index]
		var offset := index * 12
		buffer[offset + 0] = value.basis.x.x
		buffer[offset + 1] = value.basis.y.x
		buffer[offset + 2] = value.basis.z.x
		buffer[offset + 3] = value.origin.x
		buffer[offset + 4] = value.basis.x.y
		buffer[offset + 5] = value.basis.y.y
		buffer[offset + 6] = value.basis.z.y
		buffer[offset + 7] = value.origin.y
		buffer[offset + 8] = value.basis.x.z
		buffer[offset + 9] = value.basis.y.z
		buffer[offset + 10] = value.basis.z.z
		buffer[offset + 11] = value.origin.z
	return buffer


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", message)
	else:
		_failures.append(message)
		print("FAIL: ", message)


func _finish() -> void:
	print("CINDER_MINING_LANDMARK_READABILITY_TEST_ASSERTIONS: ", _assertions)
	if _failures.is_empty():
		print("CINDER_MINING_LANDMARK_READABILITY_TEST_OK")
		quit(0)
		return
	for failure in _failures:
		print("CINDER_MINING_LANDMARK_READABILITY_TEST_FAILURE: ", failure)
	quit(1)
