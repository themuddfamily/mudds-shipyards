extends SceneTree

## Focused renderer regression for the Halyard's four visual landing pads.
## Collision and boarding authority remain separate production nodes; this
## verifies only the immutable batch, exact silhouette transforms, and measured
## component-local allocation delta.

const HALYARD_SCENE := preload("res://scenes/ships/halyard_crew_transport.tscn")

var _failures: Array[String] = []
var _assertions := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var craft := HALYARD_SCENE.instantiate() as HalyardCrewTransport
	root.add_child(craft)
	await process_frame
	await physics_frame

	var visual := craft.get_halyard_visual_root()
	var batch := visual.get_node_or_null(^"LandingGearFootBatch") as MultiMeshInstance3D \
		if visual != null else null
	_check(batch != null and batch.multimesh != null, "one renderer owns all four Halyard landing pads")
	if batch != null and batch.multimesh != null:
		var expected_transforms: Array[Transform3D] = []
		var expected_names := PackedStringArray()
		for side in [-1.0, 1.0]:
			for leg_z in [-5.20, 4.80]:
				var leg_name := ("Port" if side < 0.0 else "Starboard") \
					+ ("Forward" if leg_z < 0.0 else "Aft")
				expected_transforms.append(Transform3D(
					Basis.IDENTITY,
					Vector3(side * 2.08, -0.98, leg_z)
				))
				expected_names.append(leg_name + "GearFoot")
		var authored := batch.get_meta("authored_instance_transforms", []) as Array
		var transforms_match := authored.size() == expected_transforms.size()
		for index in mini(authored.size(), expected_transforms.size()):
			transforms_match = transforms_match \
				and (authored[index] as Transform3D).is_equal_approx(expected_transforms[index])
		_check(
			batch.multimesh.instance_count == HalyardCrewTransport.LANDING_GEAR_FOOT_COPY_COUNT
				and batch.multimesh.visible_instance_count == -1
				and batch.multimesh.mesh.get_aabb().size.is_equal_approx(
					HalyardCrewTransport.LANDING_GEAR_FOOT_SIZE
				)
				and batch.get_meta("authored_visual_names", PackedStringArray()) == expected_names
				and transforms_match
				and batch.material_override == craft.get_variant_materials().get("structure"),
			"the batch preserves the four named pad silhouettes at their authored transforms"
		)
		_check(
			visual.find_children("*GearFoot", "MeshInstance3D", true, false).is_empty()
				and batch.find_children("*", "CollisionObject3D", true, false).is_empty()
				and craft.get_node_or_null(^"LandingGearCollision") is CollisionShape3D,
			"the visual batch is collision-free while the production gear collider remains authoritative"
		)

	var report := craft.get_halyard_render_allocation_report()
	_check(
		int(report.get("descendant_nodes", -1)) == 115
			and int(report.get("mesh_instances", -1)) == 102
			and int(report.get("multimesh_batches", -1)) == 8
			and int(report.get("drawn_copies", -1)) == 168
			and int(report.get("geometry_submissions", -1)) == 110
			and int(report.get("unique_mesh_resources", -1)) == 67
			and bool(report.get("exact_counts", false)),
		"four visible pads remain while the frozen Halyard budget drops by three nodes and submissions"
	)

	craft.queue_free()
	await process_frame
	_finish()


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("HALYARD_LANDING_GEAR_FOOT_BATCH_TEST_PASSED: %d assertions" % _assertions)
		quit(0)
	else:
		push_error("HALYARD_LANDING_GEAR_FOOT_BATCH_TEST_FAILED: %d/%d assertions failed: %s" % [
			_failures.size(), _assertions, "; ".join(_failures)
		])
		quit(1)
