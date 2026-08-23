extends SceneTree

## Focused regression for the Halyard's four visual-only landing-gear dampers.
## Their aggregate collision remains ship authority; this checks only renderer
## allocation, authored presentation transforms, and collision exclusion.

const HALYARD_SCENE := preload("res://scenes/ships/halyard_crew_transport.tscn")

var _failures: Array[String] = []
var _assertion_count := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var fixture := Node3D.new()
	root.add_child(fixture)
	var craft := HALYARD_SCENE.instantiate() as HeroShip
	fixture.add_child(craft)
	await process_frame
	await physics_frame

	var visual := craft.call("get_halyard_visual_root") as Node3D
	var batch := visual.get_node_or_null(^"LandingGearDamperBatch") as MultiMeshInstance3D if visual != null else null
	_check(batch != null and batch.multimesh != null, "the production Halyard resolves four gear dampers through one batch")
	if batch != null and batch.multimesh != null:
		var expected_transforms: Array[Transform3D] = []
		var expected_names := PackedStringArray()
		for side in [-1.0, 1.0]:
			for leg_z in [-5.20, 4.80]:
				var leg_name := ("Port" if side < 0.0 else "Starboard") + ("Forward" if leg_z < 0.0 else "Aft")
				expected_transforms.append(Transform3D(Basis.IDENTITY, Vector3(side * 1.78, -0.19, leg_z)))
				expected_names.append(leg_name + "GearDamper")
		var authored := batch.get_meta("authored_instance_transforms", []) as Array
		var transforms_exact := authored.size() == expected_transforms.size()
		for index in mini(authored.size(), expected_transforms.size()):
			transforms_exact = transforms_exact and (authored[index] as Transform3D).is_equal_approx(expected_transforms[index])
		_check(
			batch.multimesh.instance_count == HalyardCrewTransport.GEAR_DAMPER_COPY_COUNT
			and batch.multimesh.visible_instance_count == -1
			and transforms_exact
			and batch.get_meta("authored_visual_names", PackedStringArray()) == expected_names
			and batch.material_override == craft.get_variant_materials().get("accent"),
			"the batch preserves all four named damper copies at their authored transforms"
		)
		_check(
			batch.find_children("*", "CollisionObject3D", true, false).is_empty()
			and visual.find_children("*GearDamper", "MeshInstance3D", true, false).is_empty()
			and craft.get_node_or_null(^"LandingGearCollision") is CollisionShape3D,
			"the batch is collision-free while the Halyard keeps its separate landing-gear collider"
		)
		var report := craft.call("get_halyard_render_allocation_report") as Dictionary
		_check(
			int(report.drawn_copies) == 163
			and int(report.geometry_submissions) == 116
			and int(report.multimesh_batches) == 4
			and bool(report.exact_counts),
			"the production allocation retains 163 visible copies in 116 geometry submissions"
		)
		var original_visible_count := batch.multimesh.visible_instance_count
		batch.multimesh.visible_instance_count = HalyardCrewTransport.GEAR_DAMPER_COPY_COUNT - 1
		var mutated_report := craft.call("get_halyard_render_allocation_report") as Dictionary
		_check(
			int(mutated_report.drawn_copies) == 162 and not bool(mutated_report.exact_counts),
			"RED: hiding one damper copy is rejected by the frozen render allocation"
		)
		batch.multimesh.visible_instance_count = original_visible_count

	craft.queue_free()
	await process_frame
	fixture.queue_free()
	await process_frame
	_finish()


func _check(condition: bool, message: String) -> void:
	_assertion_count += 1
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("HALYARD_LANDING_GEAR_DAMPER_BATCH_TEST_PASSED: %d assertions" % _assertion_count)
		quit(0)
	else:
		push_error("HALYARD_LANDING_GEAR_DAMPER_BATCH_TEST_FAILED: %d/%d assertions failed: %s" % [_failures.size(), _assertion_count, "; ".join(_failures)])
		quit(1)
