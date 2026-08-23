extends SceneTree

## The outbound route out of the launch corridor clears the exterior range gate.
##
## Reproduction this exists for: `tests/nearby_sector_flight_review.gd` flew the
## production Torrent out of the central berth on real command-source input and
## hit the target range's own header beam at **46 m/s**, 51 m past the launch
## gate. Nothing was wrong with the range. Two other things were:
##
## 1. The station's published outbound aim, the `LaunchGate` marker, sat at
##    y = 8.0 — *inside* the band of altitude that beam blocks. The one waypoint
##    the station publishes for leaving it pointed at a girder.
## 2. The beam carried no lamp, no marking and no legend anywhere along its 63 m.
##    The gate's only lamps were six on the trusses, 31 m off the centreline and
##    *above* the beam.
##
## The map is confirmed correct by the player and is not the fix. Nothing in the
## range moved: this suite freezes the header, the trusses and the four drones at
## their recorded positions, and would fail if a later pass "fixed" the clearance
## by shifting them.
##
## What is measured here, from the live production tree with the real production
## hulls and the real World collision layer, rather than asserted from constants:
## the vertical clear band under the gate for each of the five craft; that the
## published clearance band and the launch gate aim sit inside the fleet-worst
## one with margin; that the whole outbound polyline — launch gate, then the four
## Cinder Reach route beacons, then the platform approach lane — is flyable by the
## largest hull in the fleet; and that the beam now carries a visible cue on two
## independent channels.
##
## Deliberately not asserted: that a pilot stays inside the band. Nothing forces
## them to, which is exactly why the cue half of the fix is not optional.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const ROUTE := preload("res://assets/activities/cinder_reach_checkpoint_route.tres")
const PLATFORM_APPROACH_OFFSET := Vector3(0.0, 4.0, 170.0)

const CRAFT_PATHS := {
	&"torrent": "TorrentInterceptor",
	&"arrow": "ArrowReconShip",
	&"jovian": "JovianLightFreighter",
	&"zenith": "ZenithInterceptor",
	&"halyard": "HalyardCrewTransport",
}

## The range gate, frozen. These are the recorded positions of the geometry this
## fix is forbidden to move, held here rather than read off `ShipyardWorld` so
## that relocating the range cannot relocate the ruler with it.
const EXPECTED_HEADER_MIN := Vector3(-31.5, 8.5, -120.5)
const EXPECTED_HEADER_MAX := Vector3(31.5, 9.5, -119.5)
const EXPECTED_TRUSS_X := 31.0
const EXPECTED_TRUSS_Y := 9.0
const EXPECTED_TARGET_POSITIONS: Array[Vector3] = [
	Vector3(-13.0, 7.0, -95.0),
	Vector3(14.0, 11.0, -116.0),
	Vector3(-2.0, 1.5, -142.0),
	Vector3(22.0, -4.0, -165.0),
]

## Where the outbound line starts, on the launch centreline at the corridor mouth.
const LAUNCH_CENTRELINE_X := 0.0
const LAUNCH_GATE_Z := -64.0
const GATE_PLANE_Z := -120.0
## The gate is 63 m wide. Sampling only the centreline would miss a beam that had
## been re-cut into an arch, so the aperture is measured right across it.
const APERTURE_SAMPLE_X: Array[float] = [-30.0, -20.0, -10.0, 0.0, 10.0, 20.0, 30.0]
## Vertical resolution of every band scan below, in metres.
const BAND_STEP := 0.1
const BAND_MINIMUM := -6.0
const BAND_MAXIMUM := 16.0
## Every band scan below reports the *contiguous* clear run that contains this
## altitude, seeded on the launch arm deck's own surface. Taking the extremes of
## all clear samples instead reports the void underneath the deck as part of the
## outbound lane, which is true of the physics and useless as a route.
const LANE_SEED_Y := 2.5
## The clear lane must be worth aiming at, not a slot. A craft holding the
## published aim gets at least this much room above and below it before it meets
## either the launch arm deck or the beam.
const MINIMUM_AIM_MARGIN := 1.0
## Sample spacing when walking the outbound polyline. Half the shortest hull
## dimension in the fleet (the Arrow is 1.65 m deep), so no leg can step over a
## 1 m girder.
const ROUTE_SAMPLE_STEP := 0.8

## The clearance cue on the header beam. Counts are frozen because the failure
## mode is a cue that quietly thins out, not one that vanishes.
const EXPECTED_CUE_LAMP_COUNT := 9
const EXPECTED_CUE_CHEVRON_COUNT := 16

var _assertions := 0
var _failures: Array[String] = []
var _space: PhysicsDirectSpaceState3D


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	await physics_frame

	var world := game.get_node_or_null("ShipyardWorld") as ShipyardWorld
	_check(world != null, "production Main exposes its ShipyardWorld")
	if world == null:
		game.queue_free()
		await process_frame
		_finish()
		return
	_space = game.get_viewport().world_3d.direct_space_state

	var hulls := _collect_hulls(game)
	_test_range_geometry_did_not_move(world)
	_test_published_band_matches_the_measured_fleet_worst_lane(world, hulls)
	_test_launch_gate_aims_into_the_clear_lane(world, hulls)
	_test_the_blocked_band_is_real(hulls)
	_test_aperture_is_uniform_across_the_gate(hulls)
	_test_whole_outbound_route_is_flyable(world, hulls)
	_test_header_beam_carries_a_clearance_cue(world)
	_test_the_cue_adds_no_collision(world, hulls)
	_test_dock_mast_collar_allocation(world)
	_test_target_core_allocation(world)
	_test_target_lamp_mesh_sharing(world)
	await _test_target_core_detach_reentry(world)

	game.queue_free()
	await process_frame
	await physics_frame
	_finish()


# ------------------------------------------------------------- geometry ----

## The range is the thing this fix is not allowed to touch. If a later pass makes
## the route safe by moving the beam, this is what says so.
func _test_range_geometry_did_not_move(world: ShipyardWorld) -> void:
	var exterior := world.get_node_or_null("ExteriorTargetRange") as Node3D
	_check(exterior != null, "the world still builds its exterior target range")
	if exterior == null:
		return

	var header := _named_collider_bounds(exterior, "RangeHeader")
	_check(
		header.position.is_equal_approx(EXPECTED_HEADER_MIN)
		and header.end.is_equal_approx(EXPECTED_HEADER_MAX),
		"the range header beam is exactly where it was: %s .. %s"
			% [str(header.position), str(header.end)]
	)

	var truss_bounds: Array[AABB] = _all_collider_bounds(exterior, "RangeTruss")
	_check(truss_bounds.size() == 2, "the gate still stands on exactly two trusses")
	for bounds in truss_bounds:
		var centre := bounds.get_center()
		_check(
			is_equal_approx(absf(centre.x), EXPECTED_TRUSS_X)
			and is_equal_approx(centre.y, EXPECTED_TRUSS_Y),
			"range truss stands unmoved at |x| %.2f, y %.2f" % [absf(centre.x), centre.y]
		)

	# The drones patrol a small closed-form orbit around an authored anchor, so the
	# live position is never the authored one. The anchor is what must not move.
	var drone_positions: Array[Vector3] = []
	for index in EXPECTED_TARGET_POSITIONS.size():
		var drone := exterior.get_node_or_null("TargetDrone%02d" % (index + 1)) as Node3D
		if drone == null:
			continue
		drone_positions.append(drone.get_meta("base_position", drone.position) as Vector3)
	_check(
		drone_positions.size() == EXPECTED_TARGET_POSITIONS.size(),
		"all four range drones are present"
	)
	var drones_unmoved := true
	for index in drone_positions.size():
		drones_unmoved = (
			drones_unmoved
			and drone_positions[index].is_equal_approx(EXPECTED_TARGET_POSITIONS[index])
		)
	_check(drones_unmoved, "all four range drones are exactly where they were")
	_check(
		world.get_target_count() == EXPECTED_TARGET_POSITIONS.size(),
		"the guided mission's objective count is unchanged at %d" % world.get_target_count()
	)


# --------------------------------------------------------- clear lanes ----

## The published band must be the measured one. Publishing a number that is not
## what the physics says is how the marker got to y = 8.0 in the first place.
func _test_published_band_matches_the_measured_fleet_worst_lane(
		world: ShipyardWorld,
		hulls: Dictionary
	) -> void:
	var published: Dictionary = world.get_outbound_clearance_band()
	var worst_ceiling := 1e9
	var worst_ceiling_craft: StringName = &""
	var worst_floor := -1e9
	var worst_floor_craft: StringName = &""
	for craft_id: StringName in hulls:
		var hull: AABB = hulls[craft_id]
		var gate_band := _clear_run(hull, LAUNCH_CENTRELINE_X, GATE_PLANE_Z, LANE_SEED_Y)
		var corridor_band := _clear_run(hull, LAUNCH_CENTRELINE_X, LAUNCH_GATE_Z, LANE_SEED_Y)
		print(
			"OUTBOUND_BAND %-8s hull=%s  gate ceiling=%.2f  corridor floor=%.2f"
			% [craft_id, str(hull.size.snapped(Vector3.ONE * 0.01)), gate_band["under_hi"], corridor_band["under_lo"]]
		)
		_check(
			gate_band["under_hi"] > gate_band["under_lo"],
			"%s has a measurable clear lane under the range gate" % craft_id
		)
		if float(gate_band["under_hi"]) < worst_ceiling:
			worst_ceiling = float(gate_band["under_hi"])
			worst_ceiling_craft = craft_id
		if float(corridor_band["under_lo"]) > worst_floor:
			worst_floor = float(corridor_band["under_lo"])
			worst_floor_craft = craft_id
	print(
		"OUTBOUND_FLEET_WORST: ceiling %.2f (%s)  floor %.2f (%s)"
		% [worst_ceiling, worst_ceiling_craft, worst_floor, worst_floor_craft]
	)
	_check(
		absf(float(published["ceiling"]) - worst_ceiling) <= BAND_STEP + 0.001,
		"the published clearance ceiling %.2f is the measured fleet-worst %.2f"
			% [float(published["ceiling"]), worst_ceiling]
	)
	_check(
		absf(float(published["floor"]) - worst_floor) <= BAND_STEP + 0.001,
		"the published clearance floor %.2f is the measured fleet-worst %.2f"
			% [float(published["floor"]), worst_floor]
	)
	_check(
		float(published["ceiling"]) - float(published["floor"]) >= 2.0 * MINIMUM_AIM_MARGIN,
		"the fleet-wide lane is %.2f m deep, wide enough to aim at"
			% [float(published["ceiling"]) - float(published["floor"])]
	)


func _test_launch_gate_aims_into_the_clear_lane(world: ShipyardWorld, hulls: Dictionary) -> void:
	var gate := world.get_launch_gate_transform()
	var published: Dictionary = world.get_outbound_clearance_band()
	_check(
		is_equal_approx(gate.origin.y, float(published["aim_y"])),
		"the LaunchGate marker sits at the published aim altitude %.2f (marker %.2f)"
			% [float(published["aim_y"]), gate.origin.y]
	)
	_check(
		gate.origin.y - float(published["floor"]) >= MINIMUM_AIM_MARGIN
		and float(published["ceiling"]) - gate.origin.y >= MINIMUM_AIM_MARGIN,
		"the launch gate aim keeps at least %.2f m over the deck and under the beam (%.2f / %.2f)"
			% [
				MINIMUM_AIM_MARGIN,
				gate.origin.y - float(published["floor"]),
				float(published["ceiling"]) - gate.origin.y,
			]
	)
	for craft_id: StringName in hulls:
		var hull: AABB = hulls[craft_id]
		var from := Vector3(gate.origin.x, gate.origin.y, LAUNCH_GATE_Z)
		var to := Vector3(gate.origin.x, gate.origin.y, GATE_PLANE_Z - 40.0)
		_check(
			_line_is_clear(hull, from, to),
			"%s holding the published aim out of the launch gate reaches the range unobstructed"
				% craft_id
		)


## Structured red for the whole fix: the altitude the marker used to carry must
## still be blocked. If this ever passes, either the beam moved or the reproduction
## stopped being real, and both need a person.
func _test_the_blocked_band_is_real(hulls: Dictionary) -> void:
	var hull: AABB = hulls[&"torrent"]
	var previous_aim := 8.0
	_check(
		not _line_is_clear(
			hull,
			Vector3(LAUNCH_CENTRELINE_X, previous_aim, LAUNCH_GATE_Z),
			Vector3(LAUNCH_CENTRELINE_X, previous_aim, GATE_PLANE_Z - 40.0)
		),
		"the recorded defect is still reproducible: a Torrent holding the old y = 8.0 aim is stopped by the gate"
	)
	var blocked_from := 1e9
	var blocked_to := -1e9
	var steps := int(round((BAND_MAXIMUM - BAND_MINIMUM) / BAND_STEP))
	for index in steps + 1:
		var y := BAND_MINIMUM + float(index) * BAND_STEP
		if _line_is_clear(
			hull,
			Vector3(LAUNCH_CENTRELINE_X, y, LAUNCH_GATE_Z),
			Vector3(LAUNCH_CENTRELINE_X, y, GATE_PLANE_Z - 40.0)
		):
			continue
		if y < 5.0:
			continue
		blocked_from = minf(blocked_from, y)
		blocked_to = maxf(blocked_to, y)
	print("OUTBOUND_BLOCKED_BAND: Torrent %.2f .. %.2f" % [blocked_from, blocked_to])
	_check(
		blocked_from < previous_aim and blocked_to > previous_aim,
		"the old aim was inside the blocked band %.2f .. %.2f, not merely near it"
			% [blocked_from, blocked_to]
	)


## There is no way round the beam inside the gate. Recorded because "just fly to
## one side" is the first thing a reader assumes and it is not true.
func _test_aperture_is_uniform_across_the_gate(hulls: Dictionary) -> void:
	var hull: AABB = hulls[&"torrent"]
	var ceilings: Array[float] = []
	for x in APERTURE_SAMPLE_X:
		var band := _clear_run(hull, x, GATE_PLANE_Z, LANE_SEED_Y)
		ceilings.append(float(band["under_hi"]))
	var lowest := ceilings[0]
	var highest := ceilings[0]
	for value in ceilings:
		lowest = minf(lowest, value)
		highest = maxf(highest, value)
	print("OUTBOUND_APERTURE_CEILINGS: ", ceilings)
	_check(
		highest - lowest <= BAND_STEP + 0.001,
		"the gate aperture is the same height right across its span (%.2f .. %.2f)"
			% [lowest, highest]
	)


func _test_whole_outbound_route_is_flyable(world: ShipyardWorld, hulls: Dictionary) -> void:
	_check(
		world.get_nearby_sector_cluster() == null and ROUTE.is_definition_valid(),
		"the station-owned route remains available while streamed Cinder geometry is absent"
	)
	var gate := world.get_launch_gate_transform()
	var route: Array[Vector3] = [
		Vector3(0.0, gate.origin.y, -30.0),
		gate.origin,
	]
	# The last resource checkpoint is the activity anchor itself. Clearance ends
	# at the authored approach point because flying through the platform anchor
	# would intentionally intersect destination structure.
	for checkpoint_index in ROUTE.get_checkpoint_count() - 1:
		route.append(ROUTE.get_checkpoint_position(checkpoint_index))
	route.append(
		ROUTE.get_checkpoint_position(ROUTE.get_checkpoint_count() - 1)
		+ PLATFORM_APPROACH_OFFSET
	)

	# The Jovian is the widest and tallest hull; the Halyard is the deepest. Sweep
	# both independent envelope extremes, plus the Torrent that reproduced the
	# original strike, so this route claim cannot silently remain four-craft-era.
	for craft_id: StringName in [&"torrent", &"jovian", &"halyard"]:
		var hull: AABB = hulls[craft_id]
		var blocked_at := _first_route_block(hull, route)
		_check(
			blocked_at.is_empty(),
			"a %s-sized hull flies the whole published outbound route unobstructed%s"
				% [craft_id, "" if blocked_at.is_empty() else " (blocked by %s at %s)" % [blocked_at.get("collider", "?"), str(blocked_at.get("at", Vector3.ZERO))]]
		)


# ---------------------------------------------------------------- cue ----

func _test_header_beam_carries_a_clearance_cue(world: ShipyardWorld) -> void:
	var exterior := world.get_node_or_null("ExteriorTargetRange") as Node3D
	if exterior == null:
		return
	var header := _named_collider_bounds(exterior, "RangeHeader")

	# Matched by position, not by name: `_add_guide_light` names every lamp
	# `GuideLight`, so the engine renames all but the first.
	var lamps := 0
	for light in exterior.find_children("*", "OmniLight3D", true, false):
		var position := (light as Node3D).global_position
		if position.z > header.position.z - 1.5 and position.z < header.end.z + 1.5 \
				and absf(position.y - header.position.y) < 1.2:
			lamps += 1
	_check(
		lamps == EXPECTED_CUE_LAMP_COUNT,
		"the header beam carries %d obstruction lamps along its span (found %d); it carried none"
			% [EXPECTED_CUE_LAMP_COUNT, lamps]
	)

	var stripe := exterior.get_node_or_null("RangeHeaderClearanceStripe") as MeshInstance3D
	_check(stripe != null, "the header beam carries a continuous lit clearance stripe")
	if stripe != null:
		var stripe_bounds := stripe.global_transform * stripe.get_aabb()
		_check(
			stripe_bounds.size.x > (EXPECTED_HEADER_MAX.x - EXPECTED_HEADER_MIN.x) * 0.95,
			"the stripe runs the beam's whole %.1f m span (%.1f m)"
				% [EXPECTED_HEADER_MAX.x - EXPECTED_HEADER_MIN.x, stripe_bounds.size.x]
		)
		_check(
			stripe_bounds.position.y >= header.position.y - 0.01
			and stripe_bounds.end.y <= header.end.y + 0.01,
			"the stripe is on the beam's own face, not hung in open space"
		)

	var chevrons := exterior.find_children("RangeHeaderClearanceChevron*", "MeshInstance3D", true, false)
	_check(
		chevrons.size() == EXPECTED_CUE_CHEVRON_COUNT,
		"the beam carries %d clearance chevron arms (found %d)"
			% [EXPECTED_CUE_CHEVRON_COUNT, chevrons.size()]
	)
	# The second channel has to be shape, not another colour: a chevron arm is
	# rotated out of the beam's own axis, which is what makes it read when the
	# frame is desaturated.
	var rotated := 0
	for candidate in chevrons:
		if absf((candidate as MeshInstance3D).rotation_degrees.z) > 10.0:
			rotated += 1
	_check(
		rotated == EXPECTED_CUE_CHEVRON_COUNT,
		"every chevron arm is angled, so the cue survives a fully desaturated frame"
	)

	# Every drawn cue piece must sit inside the beam's own 8.5 .. 9.5 m band. A cue
	# hung below the beam would be drawn geometry standing in the clear lane, which
	# a craft flying the top of that lane would pass through - the ghost-geometry
	# defect this whole pass exists to avoid making worse.
	var cue_pieces: Array[Node] = [stripe]
	cue_pieces.append_array(chevrons)
	cue_pieces.append_array(exterior.find_children("Sign_CLEARANCE*", "MeshInstance3D", true, false))
	var inside_the_beam := 0
	var lowest := 1e9
	for candidate in cue_pieces:
		var piece := candidate as MeshInstance3D
		if piece == null:
			continue
		var bounds := piece.global_transform * piece.get_aabb()
		lowest = minf(lowest, bounds.position.y)
		if bounds.position.y >= header.position.y - 0.01 and bounds.end.y <= header.end.y + 0.01:
			inside_the_beam += 1
	_check(
		inside_the_beam == cue_pieces.size(),
		"all %d drawn cue pieces sit inside the beam's own 8.50 .. 9.50 band (lowest %.3f)"
			% [cue_pieces.size(), lowest]
	)

	# ...and in front of the beam's station-facing face rather than inside the
	# girder. This exists because it happened: z runs *away* from the station, so
	# an offset written as "0.09 m toward the viewer" put the CLEARANCE BELOW
	# legend 0.04 m inside solid steel. Every check above still passed — the sign
	# existed, it was in the right height band, it was not a collider — and a
	# rendered close-up of the beam face is what showed there was no legend on it.
	var buried := PackedStringArray()
	for candidate in cue_pieces:
		var piece := candidate as MeshInstance3D
		if piece == null:
			continue
		var bounds := (piece.global_transform * piece.get_aabb()).abs()
		if bounds.position.z < header.end.z - 0.001:
			buried.append("%s reaches z %.3f behind the face at %.3f" % [piece.name, bounds.position.z, header.end.z])
	print("BURIED_CUE_PIECES: ", buried)
	_check(
		buried.is_empty(),
		"every drawn cue piece stands in front of the beam's station-facing face, not inside the girder"
	)

	var legend_found := false
	for candidate in exterior.find_children("Sign_*", "MeshInstance3D", true, false):
		var sign_mesh := (candidate as MeshInstance3D).mesh as TextMesh
		if sign_mesh != null and "CLEARANCE" in sign_mesh.text:
			legend_found = true
	_check(legend_found, "the beam states its clearance in words as well as in cues")


## The cue is presentation. If any of it acquired collision it would narrow the
## very aperture it exists to advertise, so this is measured, not assumed.
func _test_the_cue_adds_no_collision(world: ShipyardWorld, hulls: Dictionary) -> void:
	var exterior := world.get_node_or_null("ExteriorTargetRange") as Node3D
	if exterior == null:
		return
	var cue_names := [
		"RangeHeaderClearanceStripe",
		"RangeHeaderClearanceChevron",
	]
	var solid_cue_pieces := 0
	for body in exterior.find_children("*", "StaticBody3D", true, false):
		for prefix: String in cue_names:
			if (body as Node).name.begins_with(prefix):
				solid_cue_pieces += 1
	_check(
		solid_cue_pieces == 0,
		"no clearance cue piece is a collider (%d found)" % solid_cue_pieces
	)
	# And the proof that matters: the aperture is the same height it was measured
	# at before the cue existed.
	var band := _clear_run(hulls[&"torrent"], LAUNCH_CENTRELINE_X, GATE_PLANE_Z, LANE_SEED_Y)
	_check(
		float(band["under_hi"]) >= float(world.get_outbound_clearance_band()["ceiling"]),
		"adding the cue did not lower the aperture a Torrent can fly (%.2f)" % band["under_hi"]
	)


# ----------------------------------------------------- core allocation ----

func _test_dock_mast_collar_allocation(world: ShipyardWorld) -> void:
	var audit := world.get_dock_mast_collar_allocation_audit()
	var recipe := audit.get("mesh_recipe", {}) as Dictionary
	var collars: Array[MeshInstance3D] = []
	for raw_node in world.find_children("*", "MeshInstance3D", true, false):
		var candidate := raw_node as MeshInstance3D
		for position in ShipyardWorld.DOCK_MAST_COLLAR_POSITIONS:
			if candidate.position.is_equal_approx(position as Vector3):
				collars.append(candidate)
				break
	var shared_mesh := (collars[0] as MeshInstance3D).mesh as TorusMesh if collars.size() == 3 else null
	var exact_roster := collars.size() == ShipyardWorld.DOCK_MAST_COLLAR_COPY_COUNT
	for index in collars.size():
		var collar := collars[index] as MeshInstance3D
		exact_roster = exact_roster \
			and collar.mesh == shared_mesh \
			and collar.position.is_equal_approx(
				ShipyardWorld.DOCK_MAST_COLLAR_POSITIONS[index] as Vector3
			) \
			and collar.material_override != null \
			and collar.get_child_count() == 0
	_check(
		bool(audit.get("valid", false))
		and audit.get("legacy", {}) == {"visual_nodes": 3, "drawn_copies": 3, "surface_submissions": 3, "mesh_resource_allocations": 3, "material_resource_allocations": 1}
		and int((audit.get("current", {}) as Dictionary).get("mesh_resource_allocations", 0)) == 1
		and int((audit.get("reductions", {}) as Dictionary).get("mesh_resource_allocations", 0)) == 2
		and int(audit.get("collision_authority_count", -1)) == 0
		and is_equal_approx(float(recipe.get("inner_radius", 0.0)), ShipyardWorld.DOCK_MAST_COLLAR_INNER_RADIUS)
		and is_equal_approx(float(recipe.get("outer_radius", 0.0)), ShipyardWorld.DOCK_MAST_COLLAR_OUTER_RADIUS)
		and audit.get("authored_tessellation", Vector2i.ZERO) == Vector2i(ShipyardWorld.DOCK_MAST_COLLAR_RINGS, ShipyardWorld.DOCK_MAST_COLLAR_RING_SEGMENTS)
		and audit.get("live_tessellation", Vector2i.ZERO) == Vector2i(ShipyardWorld.DOCK_MAST_COLLAR_BUDGETED_RINGS, ShipyardWorld.DOCK_MAST_COLLAR_BUDGETED_RING_SEGMENTS)
		and exact_roster,
		"three visual-only dock-mast collars retain named poses, orange material and the exact 48x16 recipe while immutable mesh allocations fall 3 -> 1"
	)
	if shared_mesh == null:
		return
	var original_second_mesh := (collars[1] as MeshInstance3D).mesh
	(collars[1] as MeshInstance3D).mesh = shared_mesh.duplicate() as TorusMesh
	var identity_red := world.get_dock_mast_collar_allocation_audit()
	_check(
		not bool(identity_red.get("valid", true))
		and (identity_red.get("errors", PackedStringArray()) as PackedStringArray).has(
			"dock_mast_collar_mesh_identity_not_shared"
		),
		"an exact-looking private dock-mast collar mesh turns the allocation audit red"
	)
	(collars[1] as MeshInstance3D).mesh = original_second_mesh
	var original_rings := shared_mesh.rings
	shared_mesh.rings += 1
	var recipe_red := world.get_dock_mast_collar_allocation_audit()
	_check(
		not bool(recipe_red.get("valid", true))
		and (recipe_red.get("errors", PackedStringArray()) as PackedStringArray).has(
			"dock_mast_collar_mesh_recipe_drift"
		),
		"a dock-mast collar tessellation mutation turns the exact recipe audit red"
	)
	shared_mesh.rings = original_rings


func _test_target_core_allocation(world: ShipyardWorld) -> void:
	_check(
		world.has_method("get_exterior_target_core_allocation_audit"),
		"world exposes the bounded ExteriorTargetRange core allocation audit"
	)
	var audit := world.get_exterior_target_core_allocation_audit()
	_check(
		bool(audit.get("valid", false)),
		"target-core allocation audit starts green: %s" % [audit.get("errors", [])]
	)
	_check(
		int(audit.get("node_count", 0)) == 4
		and int(audit.get("discovered_core_count", 0)) == 4
		and int(audit.get("baseline_node_count", 0)) == 4
		and int(audit.get("node_delta", 99)) == 0
		and int(audit.get("drawn_copy_count", 0)) == 4,
		"all four named target-core nodes and visible copies remain"
	)
	_check(
		int(audit.get("structural_submission_count", 0)) == 4
		and int(audit.get("baseline_structural_submission_count", 0)) == 4
		and int(audit.get("submission_delta", 99)) == 0,
		"four one-surface structural submissions remain; the trim is not batching"
	)
	_check(
		int(audit.get("mesh_resource_identity_count", 0)) == 1
		and int(audit.get("baseline_mesh_resource_identity_count", 0)) == 4
		and int(audit.get("mesh_resource_identity_delta", 0)) == -3
		and int(audit.get("material_resource_identity_count", 0)) == 1
		and int(audit.get("material_resource_identity_delta", 99)) == 0
		and int(audit.get("retained_visual_resource_identity_count", 0)) == 2
		and int(audit.get("baseline_retained_visual_resource_identity_count", 0)) == 5
		and int(audit.get("retained_visual_resource_identity_delta", 0)) == -3,
		"only the core meshes change allocation: four meshes plus one material become one plus one (5 -> 2)"
	)
	var recipe := audit.get("mesh_recipe", {}) as Dictionary
	_check(
		is_equal_approx(float(recipe.get("radius", -1.0)), 1.4)
		and is_equal_approx(float(recipe.get("height", -1.0)), 2.8)
		and int(recipe.get("radial_segments", 0)) == 24
		and int(recipe.get("rings", 0)) == 12
		and int(recipe.get("surface_count", 0)) == 1,
		"shared target-core mesh retains the exact former SphereMesh recipe"
	)
	var exclusions := audit.get("authority_exclusions", {}) as Dictionary
	_check(
		int(audit.get("authority_node_count", -1)) == 0
		and int(audit.get("scripted_node_count", -1)) == 0
		and int(audit.get("child_node_count", -1)) == 0
		and int(audit.get("metadata_entry_count", -1)) == 0
		and int(audit.get("processing_node_count", -1)) == 0
		and exclusions == {
			"owns_target_registration": false,
			"owns_collision": false,
			"owns_combat_or_damage": false,
			"owns_movement": false,
			"owns_lifecycle": false,
			"owns_launch_clearance_or_cues": false,
			"owns_evidence": false,
		}
		and not bool(audit.get("batched", true))
		and not bool(audit.get("frame_time_claimed", true))
		and not bool(audit.get("gpu_draw_call_claimed", true))
		and not bool(audit.get("vram_claimed", true))
		and not bool(audit.get("whole_scene_budget_claimed", true)),
		"core stock remains childless presentation with the exact authority and performance exclusions"
	)

	var cores := _target_cores(world)
	var shared_mesh := cores[0].mesh as SphereMesh if cores.size() == 4 else null
	var resource_and_path_contract := shared_mesh != null
	for index in cores.size():
		var core := cores[index]
		var visual := core.get_parent() as Node3D
		var target := visual.get_parent() as StaticBody3D if visual != null else null
		resource_and_path_contract = (
			resource_and_path_contract
			and core.mesh == shared_mesh
			and core.position.is_equal_approx(Vector3.ZERO)
			and visual != null and visual.name == &"DroneVisual"
			and target != null
			and target.name == StringName("TargetDrone%02d" % (index + 1))
			and target.get_meta("target_id", &"") == StringName("DRONE-%02d" % (index + 1))
			and bool(target.get_meta("is_shipyard_target", false))
			and target.is_in_group("shipyard_targets")
			and _target_collision_shape_count(target) == 1
		)
	_check(
		resource_and_path_contract,
		"sharing retains every target path, target identity, group, collider, and independent StaticBody3D parent"
	)

	var rows := audit.get("behavior_rows", []) as Array
	(rows[0] as Dictionary)["material"] = "caller mutation"
	(audit.get("errors", PackedStringArray()) as PackedStringArray).append("caller mutation")
	var detached := world.get_exterior_target_core_allocation_audit()
	_check(
		bool(detached.get("valid", false))
		and str(((detached.get("behavior_rows", []) as Array)[0] as Dictionary).get("material", "")) == "orange_glow"
		and not (detached.get("errors", PackedStringArray()) as PackedStringArray).has("caller mutation"),
		"target-core allocation snapshots are deeply detached"
	)

	if shared_mesh == null:
		return
	var original_radius := shared_mesh.radius
	shared_mesh.radius = 1.5
	var recipe_mutation := world.get_exterior_target_core_allocation_audit()
	var mutation_reached_all := true
	for core in cores:
		mutation_reached_all = mutation_reached_all \
			and is_equal_approx((core.mesh as SphereMesh).radius, 1.5)
	_check(
		not bool(recipe_mutation.get("valid", true))
		and (recipe_mutation.get("errors", PackedStringArray()) as PackedStringArray).has("target_core_mesh_recipe_drift")
		and mutation_reached_all,
		"shared core-mesh mutation reaches all four copies and turns the audit red"
	)
	shared_mesh.radius = original_radius

	var original_second_mesh := cores[1].mesh
	cores[1].mesh = shared_mesh.duplicate() as SphereMesh
	var identity_mutation := world.get_exterior_target_core_allocation_audit()
	_check(
		not bool(identity_mutation.get("valid", true))
		and (identity_mutation.get("errors", PackedStringArray()) as PackedStringArray).has("target_core_mesh_identity_not_shared"),
		"an exact-looking private core mesh turns the identity audit red"
	)
	cores[1].mesh = original_second_mesh

	var rogue_authority := Area3D.new()
	cores[0].add_child(rogue_authority)
	var authority_mutation := world.get_exterior_target_core_allocation_audit()
	_check(
		not bool(authority_mutation.get("valid", true))
		and (authority_mutation.get("errors", PackedStringArray()) as PackedStringArray).has("target_core_stock_gained_authority_or_lifecycle_children"),
		"authority added beneath target-core presentation turns the audit red"
	)
	cores[0].remove_child(rogue_authority)
	rogue_authority.free()
	_check(
		bool(world.get_exterior_target_core_allocation_audit().get("valid", false)),
		"restoring core recipe, identity, and authority returns the audit green"
	)


func _test_target_lamp_mesh_sharing(world: ShipyardWorld) -> void:
	var lamps: Array[MeshInstance3D] = []
	var target_contract_preserved := true
	for target_index in 4:
		var target := world.get_node_or_null(
			"ExteriorTargetRange/TargetDrone%02d" % (target_index + 1)
		) as StaticBody3D
		var visual := target.get_node_or_null(^"DroneVisual") as Node3D if target != null else null
		if target == null or visual == null:
			target_contract_preserved = false
			continue
		target_contract_preserved = target_contract_preserved \
			and target.get_meta("target_id", &"") \
				== StringName("DRONE-%02d" % (target_index + 1)) \
			and target.is_in_group("shipyard_targets") \
			and _target_collision_shape_count(target) == 1
		var stable_named_lamps := 0
		for child in visual.get_children():
			if not child is MeshInstance3D:
				continue
			var candidate := child as MeshInstance3D
			var candidate_mesh := candidate.mesh as SphereMesh
			if candidate_mesh != null \
					and is_equal_approx(candidate_mesh.radius, 0.22) \
					and is_equal_approx(candidate_mesh.height, 0.44):
				lamps.append(candidate)
				if candidate.name == &"TargetLamp":
					stable_named_lamps += 1
		target_contract_preserved = target_contract_preserved \
			and stable_named_lamps == 1
	_check(
		lamps.size() == 16 and target_contract_preserved,
		"all 16 authored target lamps and each stable TargetLamp sibling remain on the four authoritative bodies"
	)
	if lamps.size() != 16:
		return
	var mesh_ids := {}
	var material_ids := {}
	var submissions := 0
	var visual_contract_preserved := true
	var expected_positions := [
		Vector3(3.172, 0.0, 0.0),
		Vector3(0.0, 3.172, 0.0),
		Vector3(-3.172, 0.0, 0.0),
		Vector3(0.0, -3.172, 0.0),
	]
	for lamp_index in lamps.size():
		var lamp := lamps[lamp_index]
		if lamp.mesh != null:
			mesh_ids[lamp.mesh.get_instance_id()] = true
			submissions += lamp.mesh.get_surface_count()
		if lamp.material_override != null:
			material_ids[lamp.material_override.get_instance_id()] = true
		visual_contract_preserved = visual_contract_preserved \
			and lamp.position.is_equal_approx(expected_positions[lamp_index % 4]) \
			and lamp.rotation.is_equal_approx(Vector3.ZERO) \
			and lamp.scale.is_equal_approx(Vector3.ONE) \
			and lamp.visible and lamp.layers == 1 \
			and lamp.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON \
			and lamp.material_override == lamps[0].material_override \
			and lamp.get_script() == null and lamp.get_child_count() == 0 \
			and lamp.get_meta_list().is_empty() \
			and not lamp.is_processing() and not lamp.is_physics_processing()
	var mesh := lamps[0].mesh as SphereMesh
	_check(
		mesh != null
		and is_equal_approx(mesh.radius, 0.22)
		and is_equal_approx(mesh.height, 0.44)
		and mesh.radial_segments == 24 and mesh.rings == 12
		and mesh.get_surface_count() == 1
		and visual_contract_preserved,
		"sharing preserves every lamp transform, material, name, visibility, and childless visual-only lifecycle"
	)
	_check(
		mesh_ids.size() == 1
		and material_ids.size() == 1
		and submissions == 16,
		"target lamps trim exact mesh allocations 16 -> 1 while structural submissions remain 16 -> 16"
	)


func _test_target_core_detach_reentry(world: ShipyardWorld) -> void:
	var exterior := world.get_node_or_null(^"ExteriorTargetRange") as Node3D
	if exterior == null:
		_check(false, "ExteriorTargetRange exists for detach/re-entry coverage")
		return
	var original_index := exterior.get_index()
	var original_core_ids: Array[int] = []
	var original_collision_ids: Array[int] = []
	for core in _target_cores(world):
		original_core_ids.append(core.get_instance_id())
		var target := core.get_parent().get_parent() as StaticBody3D
		for child in target.get_children():
			if child is CollisionShape3D:
				original_collision_ids.append(child.get_instance_id())

	world.remove_child(exterior)
	await process_frame
	_check(
		world.get_node_or_null(^"ExteriorTargetRange") == null
		and is_instance_valid(exterior)
		and not exterior.is_inside_tree()
		and world.get_target_count() == 4,
		"detaching presentation preserves the four authoritative target records without rebuilding"
	)
	world.add_child(exterior)
	world.move_child(exterior, original_index)
	await process_frame
	await physics_frame

	var reentered_core_ids: Array[int] = []
	var reentered_collision_ids: Array[int] = []
	for core in _target_cores(world):
		reentered_core_ids.append(core.get_instance_id())
		var target := core.get_parent().get_parent() as StaticBody3D
		for child in target.get_children():
			if child is CollisionShape3D:
				reentered_collision_ids.append(child.get_instance_id())
	_check(
		reentered_core_ids == original_core_ids
		and reentered_collision_ids == original_collision_ids
		and bool(world.get_exterior_target_core_allocation_audit().get("valid", false)),
		"ExteriorTargetRange re-entry retains core paths/resources and every target collider identity"
	)


func _target_cores(world: ShipyardWorld) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for index in 4:
		var path := NodePath(
			"ExteriorTargetRange/TargetDrone%02d/DroneVisual/Core" % (index + 1)
		)
		var core := world.get_node_or_null(path) as MeshInstance3D
		if core != null:
			result.append(core)
	return result


func _target_collision_shape_count(target: StaticBody3D) -> int:
	var result := 0
	for child in target.get_children():
		if child is CollisionShape3D:
			result += 1
	return result


# ------------------------------------------------------------ measuring ----

func _collect_hulls(game: Node) -> Dictionary:
	var hulls := {}
	for craft_id: StringName in CRAFT_PATHS:
		var craft := game.get_node_or_null(CRAFT_PATHS[craft_id]) as CollisionObject3D
		_check(craft != null, "production Main exposes the %s" % craft_id)
		if craft == null:
			continue
		var bounds := AABB()
		var first := true
		for child in craft.get_children():
			var shape := child as CollisionShape3D
			if shape == null or shape.shape == null or shape.disabled:
				continue
			var box: AABB = shape.transform * shape.shape.get_debug_mesh().get_aabb()
			if first:
				bounds = box
				first = false
			else:
				bounds = bounds.merge(box)
		_check(not first, "the %s exposes production collision to measure clearance with" % craft_id)
		hulls[craft_id] = bounds
	return hulls


## A box query the size of the craft's own collision envelope, placed so that
## `origin` is the ship's origin rather than the box's centre. Every altitude
## printed or asserted anywhere in this suite is a ship-origin altitude.
func _query(hull: AABB) -> PhysicsShapeQueryParameters3D:
	var shape := BoxShape3D.new()
	shape.size = hull.size
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.collision_mask = 1
	params.collide_with_areas = false
	params.collide_with_bodies = true
	return params


func _occupied(params: PhysicsShapeQueryParameters3D, hull: AABB, origin: Vector3) -> Array[Dictionary]:
	params.transform = Transform3D(Basis.IDENTITY, origin + hull.get_center())
	return _space.intersect_shape(params, 1)


## The *contiguous* clear run of ship-origin altitude that contains `seed_y`.
##
## Contiguous matters. Taking the extremes of every clear sample instead reports
## the void underneath the launch arm deck as part of the outbound lane, which is
## true of the physics and useless as a route: a lane a craft cannot climb into
## from the corridor is not a lane. The run stops at the first blocked sample in
## each direction.
func _clear_run(hull: AABB, x: float, z: float, seed_y: float) -> Dictionary:
	var params := _query(hull)
	if not _occupied(params, hull, Vector3(x, seed_y, z)).is_empty():
		return {"under_lo": seed_y, "under_hi": seed_y, "valid": false}
	var low := seed_y
	while low - BAND_STEP >= BAND_MINIMUM:
		if not _occupied(params, hull, Vector3(x, low - BAND_STEP, z)).is_empty():
			break
		low -= BAND_STEP
	var high := seed_y
	while high + BAND_STEP <= BAND_MAXIMUM:
		if not _occupied(params, hull, Vector3(x, high + BAND_STEP, z)).is_empty():
			break
		high += BAND_STEP
	return {"under_lo": low, "under_hi": high, "valid": true}


func _line_is_clear(hull: AABB, from: Vector3, to: Vector3) -> bool:
	return _first_route_block(hull, [from, to] as Array[Vector3]).is_empty()


func _first_route_block(hull: AABB, route: Array[Vector3]) -> Dictionary:
	var params := _query(hull)
	for index in route.size() - 1:
		var from := route[index]
		var to := route[index + 1]
		var steps := maxi(1, int(ceil(from.distance_to(to) / ROUTE_SAMPLE_STEP)))
		for sub in steps + 1:
			var point := from.lerp(to, float(sub) / float(steps))
			var hits := _occupied(params, hull, point)
			if hits.is_empty():
				continue
			return {
				"collider": str((hits[0]["collider"] as Node).name),
				"at": point.snapped(Vector3.ONE * 0.1),
			}
	return {}


func _named_collider_bounds(root_node: Node, node_name: String) -> AABB:
	var found := _all_collider_bounds(root_node, node_name)
	return found[0] if not found.is_empty() else AABB()


## Collects world-space collision bounds for every `StaticBody3D` built under
## `node_name`. `_box()` gives the second body of a same-named pair an engine
## identifier, so bodies are matched by their own name *or* by their mesh child's,
## which keeps the two trusses findable.
func _all_collider_bounds(root_node: Node, node_name: String) -> Array[AABB]:
	var results: Array[AABB] = []
	for candidate in root_node.find_children("*", "StaticBody3D", true, false):
		var body := candidate as StaticBody3D
		var matches := body.name.begins_with(node_name)
		if not matches:
			var mesh := body.get_node_or_null("Mesh") as MeshInstance3D
			var shape_child := body.get_node_or_null("Collision") as CollisionShape3D
			matches = (
				mesh != null
				and shape_child != null
				and body.get_parent() == root_node
				and _looks_like(body, node_name)
			)
		if not matches:
			continue
		var shape := body.get_node_or_null("Collision") as CollisionShape3D
		if shape == null or shape.shape == null:
			continue
		results.append(shape.global_transform * shape.shape.get_debug_mesh().get_aabb())
	return results


## The engine-named twin of a `_box()` pair carries the same shape size as the
## piece it was built beside, which is enough to identify it without depending on
## a generated name.
func _looks_like(body: StaticBody3D, node_name: String) -> bool:
	var sibling_size := Vector3.ZERO
	for candidate in body.get_parent().get_children():
		if (candidate as Node).name != node_name:
			continue
		var reference := (candidate as Node).get_node_or_null("Collision") as CollisionShape3D
		if reference != null and reference.shape is BoxShape3D:
			sibling_size = (reference.shape as BoxShape3D).size
	if sibling_size == Vector3.ZERO:
		return false
	var own := body.get_node_or_null("Collision") as CollisionShape3D
	return (
		own != null
		and own.shape is BoxShape3D
		and (own.shape as BoxShape3D).size.is_equal_approx(sibling_size)
	)


func _check(condition: bool, description: String) -> bool:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)
	return condition


func _finish() -> void:
	print("OUTBOUND_ROUTE_CLEARANCE_TEST_ASSERTIONS: ", _assertions)
	if _failures.is_empty():
		print("OUTBOUND_ROUTE_CLEARANCE_TEST_OK")
		quit(0)
	else:
		print("OUTBOUND_ROUTE_CLEARANCE_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
