extends SceneTree

## Focused Phase 9 performance contract: the six identical Halyard cabin seat
## legs are one presentation-only MultiMesh batch. Seat roots, anchors and the
## live loadmaster receipt path remain independent gameplay structure.

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

	var render := craft.get_halyard_render_allocation_report()
	_check(
		int(render.get("mesh_instances", -1)) == 116
			and int(render.get("geometry_submissions", -1)) == 119
			and int(render.get("multimesh_batches", -1)) == 3
			and bool(render.get("exact_counts", false)),
		"the exterior renderer budget remains unchanged by the interior seat-leg batch"
	)
	_check(
		int(render.get("drawn_copies", -1)) == 163
			and int(render.get("unique_mesh_resources", -1)) == 65
			and int(render.get("unique_material_resources", -1)) == 14,
		"the seat-leg batch preserves drawn copies, mesh identity and the cumulative budget"
	)

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
