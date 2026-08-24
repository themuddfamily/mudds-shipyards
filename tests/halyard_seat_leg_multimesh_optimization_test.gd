extends SceneTree

## Focused Halyard cabin trim contract: the identical seat legs and backs are
## presentation-only MultiMesh batches. Seat roots, anchors and the live
## loadmaster receipt path remain independent gameplay structure.

const HALYARD_SCENE := preload("res://scenes/ships/halyard_crew_transport.tscn")
const Authority := preload("res://scripts/ships/crew_seat_role_authority.gd")
const RoleProfile := preload("res://scripts/fleet/crew_role_gameplay_profile.gd")

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var craft := HALYARD_SCENE.instantiate() as HalyardCrewTransport
	root.add_child(craft)
	await process_frame
	await physics_frame
	await physics_frame

	var cabin := craft.get_node_or_null(^"WalkableInterior/CrewCabin") as Node3D
	var leg_meshes := cabin.find_children("SeatLeg", "MeshInstance3D", true, false) \
		if cabin != null else []
	var leg_batch := craft.get_node_or_null(^"WalkableInterior/CrewCabin/CrewSeatLegBatch") as MultiMeshInstance3D
	var leg_names := leg_batch.get_meta("authored_visual_names", PackedStringArray()) as PackedStringArray \
		if leg_batch != null else PackedStringArray()
	var leg_transforms := leg_batch.get_meta("authored_instance_transforms", []) as Array \
		if leg_batch != null else []
	_check(
		leg_batch != null
			and leg_batch.get_meta("visual_detail_only", false)
			and leg_batch.material_override != null
			and leg_names.size() == 6
			and leg_transforms.size() == 6
			and leg_meshes.is_empty()
			and leg_batch.multimesh != null
			and leg_batch.multimesh.instance_count == 6
			and leg_batch.multimesh.mesh.get_surface_count() == 1
			and leg_batch.find_children("*", "CollisionShape3D", true, false).is_empty(),
		"six one-surface seat-leg submissions collapse to one presentation-only batch"
	)
	var transforms_match := true
	for index in 6:
		var transform := leg_transforms[index] as Transform3D
		var side := -1.0 if index < 3 else 1.0
		var row_index := index % 3
		var expected := Vector3(
			side * HalyardCrewTransport.CREW_SEAT_HALF_SPACING,
			0.70,
			HalyardCrewTransport.CREW_SEAT_ROWS[row_index] + 0.10
		)
		if not transform.origin.is_equal_approx(expected) \
			or not transform.basis.is_equal_approx(Basis.IDENTITY):
			transforms_match = false
	_check(transforms_match, "all six seat-leg transforms remain at their authored seat-root positions")
	_check(
		leg_names[0] == "PortCrewSeat00/SeatLeg"
			and leg_names[2] == "PortCrewSeat02/SeatLeg"
			and leg_names[3] == "StarboardCrewSeat00/SeatLeg"
			and leg_names[5] == "StarboardCrewSeat02/SeatLeg",
		"the batch preserves deterministic seat-leg identities for inspection"
	)
	var back_meshes := cabin.find_children("SeatBack", "MeshInstance3D", true, false) \
		if cabin != null else []
	var back_batch := craft.get_node_or_null(^"WalkableInterior/CrewCabin/CrewSeatBackBatch") as MultiMeshInstance3D
	var back_names := back_batch.get_meta("authored_visual_names", PackedStringArray()) as PackedStringArray \
		if back_batch != null else PackedStringArray()
	var back_transforms := back_batch.get_meta("authored_instance_transforms", []) as Array \
		if back_batch != null else []
	_check(
		back_batch != null
			and back_batch.get_parent() == cabin
			and back_batch.get_meta("visual_detail_only", false)
			and back_batch.material_override == craft.get_variant_materials().get("cloth")
			and back_names.size() == HalyardCrewTransport.CREW_SEAT_BACK_COPY_COUNT
			and back_transforms.size() == HalyardCrewTransport.CREW_SEAT_BACK_COPY_COUNT
			and back_meshes.is_empty()
			and back_batch.multimesh != null
			and back_batch.multimesh.instance_count == HalyardCrewTransport.CREW_SEAT_BACK_COPY_COUNT
			and back_batch.multimesh.mesh.get_surface_count() == 1
			and back_batch.get_child_count() == 0
			and back_batch.find_children("*", "CollisionObject3D", true, false).is_empty(),
		"six one-surface seat-back submissions collapse to one collision-free cabin batch"
	)
	var back_transforms_match := true
	for index in HalyardCrewTransport.CREW_SEAT_BACK_COPY_COUNT:
		var transform := back_transforms[index] as Transform3D
		var side := -1.0 if index < 3 else 1.0
		var row_index := index % 3
		var expected := Transform3D(
			Basis.from_euler(Vector3(deg_to_rad(8.0), 0.0, 0.0)),
			Vector3(
				side * HalyardCrewTransport.CREW_SEAT_HALF_SPACING,
				1.46,
				HalyardCrewTransport.CREW_SEAT_ROWS[row_index] + 0.40
			)
		)
		if not transform.is_equal_approx(expected):
			back_transforms_match = false
	_check(back_transforms_match, "seat-back batch preserves every authored local transform and tilt")
	_check(
		back_names[0] == "PortCrewSeat00/SeatBack"
			and back_names[2] == "PortCrewSeat02/SeatBack"
			and back_names[3] == "StarboardCrewSeat00/SeatBack"
			and back_names[5] == "StarboardCrewSeat02/SeatBack",
		"the batch preserves deterministic seat-back identities for inspection"
	)
	var all_seat_roots_and_anchors_remain := true
	for side_name in ["Port", "Starboard"]:
		for row_index in 3:
			var seat_root := cabin.get_node_or_null("%sCrewSeat%02d" % [side_name, row_index]) as Node3D
			if seat_root == null or seat_root.get_node_or_null(^"CrewSeatAnchor") == null:
				all_seat_roots_and_anchors_remain = false
	_check(
		back_batch != null
			and back_batch.multimesh != null
			and back_batch.multimesh.buffer == _encode_multimesh_transforms(back_transforms)
			and all_seat_roots_and_anchors_remain,
		"the renderer buffer is exact while every seat root and anchor remains available"
	)

	_check(craft.get_loadmaster_station_anchor() != null, "the loadmaster seat anchor survives the seat-leg batch")
	var authority := Authority.new(1)
	_check(bool(authority.register_halyard_roster().get("accepted", false)), "the role roster remains available")
	_check(bool(craft.attach_crew_role_authority(authority).get("accepted", false)), "the role authority seam remains attached")
	_check(
		bool(authority.claim(
			1, 53, &"leg_test_loadmaster", HalyardCrewTransport.LOADMASTER_STATION_SEAT_ID,
			Authority.ROLE_PASSENGER, 1
		).get("accepted", false)),
		"the physical loadmaster seat remains claimable"
	)
	var receipt := craft.submit_crew_intent(
		1,
		53,
		&"leg_test_loadmaster",
		RoleProfile.ACTION_PASSENGER_CARGO_MANIFEST,
		{"manifest_id": &"leg_manifest", "route_id": &"dock_04_cargo", "ready": true},
		2
	)
	_check(
		bool(receipt.get("consumed", false))
			and (receipt.get("effect", {}) as Dictionary).get("receipt", {}).get("manifest_id", &"") == &"leg_manifest",
		"the seat-leg optimization leaves loadmaster manifest receipts functional"
	)
	var allocation_report := craft.get_halyard_render_allocation_report()
	var audit_report := craft.get_halyard_audit_report()
	_check(
		bool(allocation_report.get("exact_counts", false))
			and bool(audit_report.get("valid", false)),
		"the complete Halyard render census and component audit remain green"
	)

	craft.queue_free()
	await process_frame
	if _failures.is_empty():
		print("HALYARD_SEAT_LEG_MULTIMESH_OPTIMIZATION_TEST_OK: %d checks" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _encode_multimesh_transforms(transforms: Array) -> PackedFloat32Array:
	var buffer := PackedFloat32Array()
	buffer.resize(transforms.size() * 12)
	for index in transforms.size():
		var value := transforms[index] as Transform3D
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
