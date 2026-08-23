extends SceneTree

## Focused performance contract: the 20 identical Halyard cabin window panes
## are one presentation-only MultiMesh batch. The test keeps the authored
## transforms, material, collision-free status, seat anchor, and loadmaster
## receipt path visible while measuring the renderer reduction.

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
			and int(render.get("multimesh_batches", -1)) == 3,
		"the pane batch remains intact alongside the later glow batch in the cumulative budget"
	)
	_check(
		int(render.get("drawn_copies", -1)) == 163
			and int(render.get("unique_mesh_resources", -1)) == 65
			and bool(render.get("exact_counts", false)),
		"the optimization preserves drawn copies, mesh identity, and the exact authored budget"
	)
	var pane_batch := craft.get_node_or_null(^"HalyardTransportVisual/CabinWindowPaneBatch") as MultiMeshInstance3D
	var pane_names := pane_batch.get_meta("authored_visual_names", PackedStringArray()) as PackedStringArray \
		if pane_batch != null else PackedStringArray()
	var pane_transforms := pane_batch.get_meta("authored_instance_transforms", []) as Array \
		if pane_batch != null else []
	_check(
		pane_batch != null
			and pane_batch.get_meta("visual_detail_only", false)
			and pane_batch.material_override != null
			and pane_names.size() == 20
			and pane_transforms.size() == 20
			and pane_batch.find_children("*", "CollisionShape3D", true, false).is_empty(),
		"the pane batch retains its glass material and presentation-only collision contract"
	)
	var transforms_match := true
	for index in 20:
		var transform := pane_transforms[index] as Transform3D
		var side := -1.0 if index < 10 else 1.0
		var window_index := index % 10
		var expected := Vector3(
			side * (HalyardCrewTransport.HULL_HALF_WIDTH + 0.13),
			2.35,
			HalyardCrewTransport.CABIN_WINDOW_FIRST_Z
				+ HalyardCrewTransport.CABIN_WINDOW_PITCH * float(window_index)
		)
		if not transform.origin.is_equal_approx(expected) \
				or not transform.basis.is_equal_approx(Basis.IDENTITY):
			transforms_match = false
	_check(transforms_match, "all 20 pane transforms remain exactly at their authored flank positions")
	_check(
		pane_names[0] == "PortWindowPane00"
			and pane_names[9] == "PortWindowPane09"
			and pane_names[10] == "StarboardWindowPane00"
			and pane_names[19] == "StarboardWindowPane09",
		"the batch preserves deterministic authored pane identity for downstream inspection"
	)

	_check(craft.get_loadmaster_station_anchor() != null, "the loadmaster seat anchor survives the presentation optimization")
	var authority := Authority.new(1)
	_check(bool(authority.register_halyard_roster().get("accepted", false)), "the role roster remains available")
	_check(bool(craft.attach_crew_role_authority(authority).get("accepted", false)), "the ship retains its role authority seam")
	_check(
		bool(authority.claim(
			1, 51, &"pane_test_loadmaster", HalyardCrewTransport.LOADMASTER_STATION_SEAT_ID,
			Authority.ROLE_PASSENGER, 1
		).get("accepted", false)),
		"the physical loadmaster seat remains claimable"
	)
	var receipt := craft.submit_crew_intent(
		1,
		51,
		&"pane_test_loadmaster",
		RoleProfile.ACTION_PASSENGER_CARGO_MANIFEST,
		{"manifest_id": &"pane_manifest", "route_id": &"dock_04_cargo", "ready": true},
		2
	)
	_check(
		bool(receipt.get("consumed", false))
			and (receipt.get("effect", {}) as Dictionary).get("receipt", {}).get("route_id", &"") == &"dock_04_cargo",
		"the optimized presentation leaves loadmaster route/readiness receipts functional"
	)

	craft.queue_free()
	await process_frame
	if _failures.is_empty():
		print("HALYARD_WINDOW_MULTIMESH_OPTIMIZATION_TEST_OK: %d checks" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
