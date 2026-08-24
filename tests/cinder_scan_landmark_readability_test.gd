extends SceneTree

## Exact geometry/lifecycle proof for Cinder Reach's starboard survey landmark.

const CLUSTER_SCENE := preload("res://scenes/world/components/nearby_sector_cluster.tscn")
const LANDMARK_PATH := (
	^"ExtractionPlatform/CinderReachPlatform/AbandonedStructureScanPresentation/StructureScanSurveyFork"
)
const APPROACH_PATH := (
	^"ExtractionPlatform/CinderReachPlatform/AbandonedStructureScanPresentation/StructureScanApproachAnchor"
)
const EXPECTED_FAMILY_ID: StringName = &"cinder-structure-scan-survey-fork"
const EXPECTED_ACTIVITY_ID: StringName = &"cinder_derelict_structure_scan"
const EXPECTED_APPROACH_Z := 20.0

var _assertions := 0
var _failures: Array[String] = []
var _expected_transforms: Array[Transform3D] = [
	Transform3D(
		Basis.from_euler(Vector3(0.0, 0.0, deg_to_rad(-45.0)))
			* Basis.from_scale(Vector3(3.6, 35.35534, 4.0)),
		Vector3(22.5, 14.5, -10.0)
	),
	Transform3D(Basis.from_scale(Vector3(3.6, 22.0, 4.0)), Vector3(35.0, 38.0, -10.0)),
	Transform3D(
		Basis.from_euler(Vector3(0.0, 0.0, deg_to_rad(39.80557)))
			* Basis.from_scale(Vector3(3.6, 15.6205, 4.0)),
		Vector3(30.0, 46.0, -10.0)
	),
	Transform3D(
		Basis.from_euler(Vector3(0.0, 0.0, deg_to_rad(-47.48955)))
			* Basis.from_scale(Vector3(3.6, 16.27882, 4.0)),
		Vector3(41.0, 45.5, -10.0)
	),
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var cluster := CLUSTER_SCENE.instantiate() as NearbySectorCluster
	root.add_child(cluster)
	await process_frame
	var landmark := cluster.get_node_or_null(LANDMARK_PATH) as MeshInstance3D
	var approach := cluster.get_node_or_null(APPROACH_PATH) as Marker3D
	_check(
		landmark != null and landmark.mesh != null and approach != null,
		"the production scan site builds one retained survey-fork renderer"
	)
	if landmark == null or landmark.mesh == null or approach == null:
		cluster.queue_free()
		await process_frame
		_finish()
		return

	var transforms := landmark.get_meta(&"authored_instance_transforms", []) as Array
	var bounds := landmark.mesh.get_aabb()
	print("CINDER_SCAN_SURVEY_FORK_BOUNDS: ", bounds)
	_check(
		transforms == _expected_transforms and landmark.mesh.get_surface_count() == 1,
		"four exact authored members remain one batched renderer submission"
	)
	var heel := transforms[0] as Transform3D
	var mast := transforms[1] as Transform3D
	var heel_foot := heel.origin - heel.basis.y * 0.5
	var heel_top := heel.origin + heel.basis.y * 0.5
	var mast_foot := mast.origin - mast.basis.y * 0.5
	var mast_top := mast.origin + mast.basis.y * 0.5
	_check(
		heel_foot.is_equal_approx(Vector3(10.0, 2.0, -10.0))
		and heel_top.is_equal_approx(Vector3(35.0, 27.0, -10.0))
		and mast_foot.is_equal_approx(heel_top)
		and mast_top.is_equal_approx(Vector3(35.0, 49.0, -10.0)),
		"the raked heel buries in the processing spine and carries the upright mast"
	)
	var fork_port := transforms[2] as Transform3D
	var fork_starboard := transforms[3] as Transform3D
	_check(
		(fork_port.origin - fork_port.basis.y * 0.5).distance_to(
			Vector3(35.0, 40.0, -10.0)
		) < 0.001
		and (fork_starboard.origin - fork_starboard.basis.y * 0.5).distance_to(
			Vector3(35.0, 40.0, -10.0)
		) < 0.001
		and bounds.size.x >= 38.0 and bounds.size.y >= 51.0,
		"the split receiver crown makes a tall asymmetric scan silhouette at gameplay distance"
	)
	_check(
		bounds.end.z < 0.0 and bounds.end.z < approach.position.z
		and is_equal_approx(approach.position.z, EXPECTED_APPROACH_Z),
		"the entire landmark stays aft of the positive-Z ship and scan approach lanes"
	)
	var material := landmark.material_override as StandardMaterial3D
	_check(
		material == cluster._materials["scan_landmark_teal"]
		and material.albedo_color.is_equal_approx(Color("3f8f7a"))
		and not material.emission_enabled,
		"a steady non-emissive teal finish separates scan identity from orange race and mining crowns"
	)
	_check(
		StringName(landmark.get_meta(&"visual_batch_family_id", &"")) == EXPECTED_FAMILY_ID
		and StringName(landmark.get_meta(&"activity_id", &"")) == EXPECTED_ACTIVITY_ID
		and bool(landmark.get_meta(&"presentation_only", false))
		and bool(landmark.get_meta(&"physically_supported", false))
		and bool(landmark.get_meta(&"approach_landmark", false)),
		"the supported fork identifies the existing scan activity without owning it"
	)
	_check(
		landmark.find_children("*", "CollisionObject3D", true, false).is_empty()
		and landmark.find_children("*", "CollisionShape3D", true, false).is_empty()
		and landmark.find_children("*", "Area3D", true, false).is_empty()
		and landmark.find_children("*", "Light3D", true, false).is_empty()
		and landmark.find_children("*", "Timer", true, false).is_empty()
		and landmark.find_children("*", "AnimationPlayer", true, false).is_empty()
		and not landmark.is_processing() and not landmark.is_physics_processing(),
		"the steady fork adds no collision, interaction, light, timer, animation, or process path"
	)
	var scan_state_before := cluster.get_structure_scan_presentation_state()
	var retained_id := landmark.get_instance_id()
	cluster.set_cluster_enabled(false)
	cluster.set_cluster_enabled(true)
	var retained := cluster.get_node_or_null(LANDMARK_PATH) as MeshInstance3D
	_check(
		retained != null and retained.get_instance_id() == retained_id
		and cluster.get_structure_scan_presentation_state() == scan_state_before,
		"streaming visibility reuses the landmark and does not advance scan state"
	)
	var audit := cluster.get_structure_scan_presentation_audit()
	_check(
		bool(audit.get("valid", false))
		and not bool(audit.get("scan_authority", true))
		and not bool(audit.get("interaction_authority", true))
		and not bool(audit.get("collision_authority", true))
		and not bool(audit.get("reward_authority", true)),
		"the production scan audit remains lifecycle- and authority-free"
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
	print("CINDER_SCAN_LANDMARK_READABILITY_TEST_ASSERTIONS: ", _assertions)
	if _failures.is_empty():
		print("CINDER_SCAN_LANDMARK_READABILITY_TEST_OK")
		quit(0)
		return
	for failure in _failures:
		print("CINDER_SCAN_LANDMARK_READABILITY_TEST_FAILURE: ", failure)
	quit(1)
