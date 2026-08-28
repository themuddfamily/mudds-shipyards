extends SceneTree

## Focused player-visible contract for the Halyard's amber airstair nosing.
## The four strips are immutable render dressing; boarding remains on the
## existing route markers and aggregate ramp collider.

const HALYARD_SCENE := preload("res://scenes/ships/halyard_crew_transport.tscn")

var _failures: Array[String] = []
var _assertion_count := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var fixture := Node3D.new()
	root.add_child(fixture)
	var craft := HALYARD_SCENE.instantiate() as HalyardCrewTransport
	fixture.add_child(craft)
	await process_frame
	await physics_frame

	var visual := craft.get_halyard_visual_root()
	var batch := visual.get_node_or_null(^"AirstairNosingBatch") as MultiMeshInstance3D \
		if visual != null else null
	_check(batch != null and batch.multimesh != null, "the production Halyard exposes one amber airstair-nosing batch")
	if batch != null and batch.multimesh != null:
		var nosing_material := batch.material_override as StandardMaterial3D
		var expected_transforms: Array[Transform3D] = []
		var expected_names := PackedStringArray()
		for tread_index in HalyardCrewTransport.AIRSTAIR_NOSING_COPY_COUNT:
			expected_transforms.append(Transform3D(
				Basis.IDENTITY,
				Vector3(
					-3.06 - float(tread_index) * 0.42,
					0.325 - float(tread_index) * 0.44,
					HalyardCrewTransport.AIRSTAIR_Z
				)
			))
			expected_names.append("AirstairNosing%02d" % tread_index)
		var authored := batch.get_meta("authored_instance_transforms", []) as Array
		var transforms_exact := authored.size() == expected_transforms.size()
		for index in mini(authored.size(), expected_transforms.size()):
			transforms_exact = transforms_exact \
				and (authored[index] as Transform3D).is_equal_approx(expected_transforms[index])
		_check(
			batch.multimesh.instance_count == HalyardCrewTransport.AIRSTAIR_NOSING_COPY_COUNT
				and batch.multimesh.visible_instance_count == -1
				and batch.multimesh.mesh.get_aabb().size.is_equal_approx(HalyardCrewTransport.AIRSTAIR_NOSING_SIZE)
				and transforms_exact
				and batch.get_meta("authored_visual_names", PackedStringArray()) == expected_names
				and nosing_material == craft.get_variant_materials().get("instrument_low")
				and nosing_material.emission_enabled
				and is_equal_approx(nosing_material.emission_energy_multiplier, 0.42)
				and nosing_material.emission_energy_multiplier <= 0.5
				and bool(batch.get_meta("visual_detail_only", false)),
			"four luminous strips preserve their positions and use the bounded low-energy amber material"
		)
		_check(
			batch.get_child_count() == 0
				and batch.find_children("*", "CollisionObject3D", true, false).is_empty()
				and visual.find_children("AirstairNosing*", "MeshInstance3D", true, false).is_empty()
				and craft.get_node_or_null(^"PortAirstairCollision") is CollisionShape3D,
			"the readability trim is childless and collision-free while the boarding ramp collider remains"
		)

	var cabin := craft.get_in_flight_cabin_report()
	var interior := craft.get_walkable_interior_report()
	var audit := craft.get_halyard_audit_report()
	var allocation := craft.get_halyard_render_allocation_report()
	_check(
		craft.get_interior_access_marker() != null
			and craft.get_interior_deck_marker() != null
			and bool(cabin.get("supported", false))
			and int(interior.get("passenger_seat_count", 0)) == 6,
		"boarding markers, moving cabin support, and all six crew seats remain available"
	)
	_check(
		bool(audit.get("valid", false))
			and bool(allocation.get("exact_counts", false))
			and int(allocation.get("drawn_copies", -1)) == 168
			and int(allocation.get("multimesh_batches", -1)) == 8,
		"the complete Halyard audit accepts the visual-only four-copy addition"
	)

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
		print("HALYARD_AIRSTAIR_NOSING_READABILITY_TEST_PASSED: %d assertions" % _assertion_count)
		quit(0)
	else:
		push_error("HALYARD_AIRSTAIR_NOSING_READABILITY_TEST_FAILED: %d/%d assertions failed: %s" % [_failures.size(), _assertion_count, "; ".join(_failures)])
		quit(1)
