extends SceneTree

## Focused Phase 9 performance contract: the second exact-repeat cabin family,
## the 20 lit window glows, uses one presentation-only MultiMesh. The glass
## pane batch is intentionally separate and remains unchanged.

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
	# Exterior census refreshed for the shipped formed-geometry checkpoints
	# ending at 46b205086 (Account for Halyard formed jamb mesh and lining
	# surfaces). HalyardCrewTransport.RENDER_* holds the same frozen roster.
	_check(
		int(render.get("mesh_instances", -1)) == 115
			and int(render.get("geometry_submissions", -1)) == 130
			and int(render.get("multimesh_batches", -1)) == 9,
		"the glow batch remains one of nine exterior batches in the current authored budget"
	)
	_check(
		int(render.get("drawn_copies", -1)) == 201
			and int(render.get("unique_mesh_resources", -1)) == 92
			and bool(render.get("exact_counts", false)),
		"the glow batch preserves drawn copies, mesh identity, and the optimized budget"
	)
	var glow_batch := craft.get_node_or_null(^"HalyardTransportVisual/CabinWindowGlowBatch") as MultiMeshInstance3D
	var glow_names := glow_batch.get_meta("authored_visual_names", PackedStringArray()) as PackedStringArray \
		if glow_batch != null else PackedStringArray()
	var glow_transforms := glow_batch.get_meta("authored_instance_transforms", []) as Array \
		if glow_batch != null else []
	_check(
		glow_batch != null
			and glow_batch.get_meta("visual_detail_only", false)
			and glow_batch.material_override != null
			and glow_names.size() == 20
			and glow_transforms.size() == 20
			and glow_batch.find_children("*", "CollisionShape3D", true, false).is_empty(),
		"the glow batch retains its emissive material and presentation-only collision contract"
	)
	var transforms_match := true
	for index in 20:
		var transform := glow_transforms[index] as Transform3D
		var side := -1.0 if index < 10 else 1.0
		var window_index := index % 10
		var expected := Vector3(
			side * (HalyardCrewTransport.HULL_HALF_WIDTH + 0.09),
			2.35,
			HalyardCrewTransport.CABIN_WINDOW_FIRST_Z
				+ HalyardCrewTransport.CABIN_WINDOW_PITCH * float(window_index)
		)
		# Port window 02 clears the physical airstair doorway, and the port
		# seals aft of it step 0.55 forward of the starboard cadence so no
		# full pressure seal crosses the open aperture (4ad633d65, Refine
		# inhabited craft with muted paint, pressure glazing and cast
		# structure).
		if side < 0.0 and window_index == 2:
			expected.z = -9.55
		elif side < 0.0 and window_index >= 3:
			expected.z += 0.55
		if not transform.origin.is_equal_approx(expected) \
				or not transform.basis.is_equal_approx(Basis.IDENTITY):
			transforms_match = false
	_check(transforms_match, "all 20 glow transforms remain at their authored flank positions")
	_check(
		glow_names[0] == "PortWindowGlow00"
			and glow_names[9] == "PortWindowGlow09"
			and glow_names[10] == "StarboardWindowGlow00"
			and glow_names[19] == "StarboardWindowGlow09",
		"the glow batch preserves deterministic authored identity for inspection"
	)

	_check(craft.get_loadmaster_station_anchor() != null, "the loadmaster seat anchor survives the second batch")
	var authority := Authority.new(1)
	_check(bool(authority.register_halyard_roster().get("accepted", false)), "the role roster remains available")
	_check(bool(craft.attach_crew_role_authority(authority).get("accepted", false)), "the role authority seam remains attached")
	_check(
		bool(authority.claim(
			1, 52, &"glow_test_loadmaster", HalyardCrewTransport.LOADMASTER_STATION_SEAT_ID,
			Authority.ROLE_PASSENGER, 1
		).get("accepted", false)),
		"the physical loadmaster seat remains claimable"
	)
	var receipt := craft.submit_crew_intent(
		1,
		52,
		&"glow_test_loadmaster",
		RoleProfile.ACTION_PASSENGER_CARGO_MANIFEST,
		{"manifest_id": &"glow_manifest", "route_id": &"dock_04_cargo", "ready": true},
		2
	)
	_check(
		bool(receipt.get("consumed", false))
			and (receipt.get("effect", {}) as Dictionary).get("receipt", {}).get("manifest_id", &"") == &"glow_manifest",
		"the second presentation batch leaves loadmaster manifest behavior functional"
	)

	craft.queue_free()
	await process_frame
	if _failures.is_empty():
		print("HALYARD_WINDOW_GLOW_MULTIMESH_OPTIMIZATION_TEST_OK: %d checks" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
