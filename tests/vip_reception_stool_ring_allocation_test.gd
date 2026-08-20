extends SceneTree

const SUITE_SCENE := preload("res://scenes/world/modules/vip_reception_suite.tscn")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var suite := SUITE_SCENE.instantiate() as VipReceptionSuite
	root.add_child(suite)
	await process_frame
	var audit := suite.get_servery_stool_foot_ring_allocation_audit()
	_check(
		bool(audit.valid)
			and int(audit.node_count) == 3
			and int(audit.structural_submission_count) == 3
			and int(audit.mesh_resource_identity_count_before) == 3
			and int(audit.mesh_resource_identity_count_after) == 1
			and int(audit.mesh_resource_identity_delta) == -2
			and int(audit.material_resource_identity_count) == 1
			and int(audit.child_node_count) == 0
			and int(audit.stool_seat_count) == 3
			and int(audit.foot_collision_body_count) == 3
			and not bool(audit.batched)
			and not bool(audit.material_sharing)
			and not bool(audit.seat_authority)
			and not bool(audit.collision_authority),
		"three named servery stool rings share one exact mesh without changing materials or authority"
	)
	var ring := suite.get_node_or_null(^"Structure/Fitout/ServeryStool03/FootRing") as MeshInstance3D
	var shared_mesh := ring.mesh if ring != null else null
	if ring != null:
		ring.mesh = TorusMesh.new()
	var red := suite.get_servery_stool_foot_ring_allocation_audit()
	_check(
		ring != null
			and not bool(red.valid)
			and (red.errors as PackedStringArray).has("servery_stool_foot_ring_mesh_identity_count_drift"),
		"a private stool-ring mesh fails the allocation audit closed"
	)
	if ring != null:
		ring.mesh = shared_mesh
	_check(bool(suite.get_servery_stool_foot_ring_allocation_audit().valid), "restoring the shared stool-ring mesh returns the audit green")
	suite.queue_free()
	await process_frame
	if _failures.is_empty():
		print("VIP_RECEPTION_STOOL_RING_ALLOCATION_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	printerr("VIP_RECEPTION_STOOL_RING_ALLOCATION_TEST_FAILED: ", _failures)
	quit(1)


func _check(condition: bool, label: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", label)
	else:
		_failures.append(label)
		push_error("FAIL: " + label)
