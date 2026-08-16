extends SceneTree

## Focused production contract for the hand-authored nearby sector cluster.
##
## The cluster is the first content the player can fly *to*, and the two things
## that can quietly ruin it are invisible to a node-existence check: geometry
## wound inside out, and a rock scattered into the lane the pilot is being told
## to fly down. Both are measured here against the real world scene, not a
## fixture. So is the boundary the cluster must not cross — it grants nothing,
## adds no range targets, and never reaches back toward the station.

const WORLD_SCENE := preload("res://scenes/world/shipyard_world.tscn")
const ENGINE_CALIBRATION_MESHES := ["BoxMesh", "CylinderMesh", "SphereMesh"]
const EXPECTED_COMPONENT_ID: StringName = &"nearby-sector-cluster"
const EXPECTED_EVIDENCE_STATUS: StringName = &"modern_interpretation"
## Nothing the cluster builds may come nearer the station than this. The launch
## corridor, the landing approach and the whole target range live well inside it;
## the range's furthest drone is 165 m out.
const STATION_EXCLUSION_RADIUS := 200.0

## The cluster's placement contract, frozen here rather than read back off the
## component. Reading `NearbySectorCluster.PLATFORM_KEEP_CLEAR_RADIUS` to check
## the scatter against the keep-clear sphere measures nothing: shrinking the
## constant would move the rule and the ruler together and the suite would stay
## green while rocks filled the approach lane. These numbers are the contract, and
## `_test_frozen_contract` is what notices when the component walks away from it.
const EXPECTED_PLATFORM_ANCHOR := Vector3(60.0, -70.0, -700.0)
const EXPECTED_PLATFORM_KEEP_CLEAR := 105.0
const EXPECTED_LANE_RADIUS := 30.0
const EXPECTED_LANE_LENGTH := 200.0
const EXPECTED_LANE_CENTER_Y := 4.0
const EXPECTED_BEACON_COUNT := 4
const EXPECTED_BOULDER_COUNT := 16
const EXPECTED_DEBRIS_CHIP_COUNT := 520
const EXPECTED_GATE_WIDTH := 28.0
const EXPECTED_GATE_HEIGHT := 23.0
const EXPECTED_GATE_NEAR_Z := 95.0
const EXPECTED_GATE_FAR_Z := 77.0
## The furthest the whole cluster may sit from the station and still be somewhere
## a pilot chooses to go rather than commits an evening to.
const MAXIMUM_TRAVEL_DISTANCE := 760.0

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := WORLD_SCENE.instantiate() as ShipyardWorld
	var twin := WORLD_SCENE.instantiate() as ShipyardWorld
	_check(world != null and twin != null, "two production ShipyardWorld scenes instantiate")
	if world == null or twin == null:
		_finish()
		return
	root.add_child(world)
	root.add_child(twin)
	await process_frame

	var cluster := world.get_nearby_sector_cluster()
	var twin_cluster := twin.get_nearby_sector_cluster()
	_check(
		cluster != null and twin_cluster != null,
		"the production world exposes its nearby sector cluster component"
	)
	if cluster == null or twin_cluster == null:
		world.queue_free()
		twin.queue_free()
		await process_frame
		_finish()
		return

	_test_frozen_contract()
	_test_identity_and_authority(world, cluster)
	_test_placement_envelope(cluster)
	_test_placement_predicate_rejects_the_lane(cluster)
	_test_winding(cluster)
	_test_collision_boundary(cluster)
	_test_determinism(cluster, twin_cluster)
	await _test_lifecycle(world, cluster)

	twin.queue_free()
	world.queue_free()
	await process_frame
	await process_frame
	_finish()


## The published placement rule, held to the numbers this suite measures against.
## Every later scan uses the constants above, so this is the single place a
## deliberate design change has to be declared.
func _test_frozen_contract() -> void:
	_check(
		NearbySectorCluster.PLATFORM_ANCHOR.is_equal_approx(EXPECTED_PLATFORM_ANCHOR),
		"the platform anchor is still the published (60, -70, -700)"
	)
	_check(
		is_equal_approx(NearbySectorCluster.PLATFORM_KEEP_CLEAR_RADIUS, EXPECTED_PLATFORM_KEEP_CLEAR)
		and is_equal_approx(NearbySectorCluster.APPROACH_CORRIDOR_RADIUS, EXPECTED_LANE_RADIUS)
		and is_equal_approx(NearbySectorCluster.APPROACH_CORRIDOR_LENGTH, EXPECTED_LANE_LENGTH)
		and is_equal_approx(NearbySectorCluster.GANTRY_CENTER_Y, EXPECTED_LANE_CENTER_Y),
		"the keep-clear sphere and the approach lane keep their published dimensions"
	)
	_check(
		NearbySectorCluster.ROUTE_BEACON_SPECS.size() == EXPECTED_BEACON_COUNT
		and NearbySectorCluster.BOULDER_COUNT == EXPECTED_BOULDER_COUNT
		and NearbySectorCluster.DEBRIS_CHIP_COUNT == EXPECTED_DEBRIS_CHIP_COUNT,
		"the hand-placed roster is still four beacons, sixteen boulders and one debris shell"
	)
	_check(
		is_equal_approx(NearbySectorCluster.GANTRY_CLEAR_WIDTH, EXPECTED_GATE_WIDTH)
		and is_equal_approx(NearbySectorCluster.GANTRY_CLEAR_HEIGHT, EXPECTED_GATE_HEIGHT)
		and is_equal_approx(NearbySectorCluster.GANTRY_NEAR_Z, EXPECTED_GATE_NEAR_Z)
		and is_equal_approx(NearbySectorCluster.GANTRY_FAR_Z, EXPECTED_GATE_FAR_Z),
		"the dock gate keeps its published aperture and its standoff from the platform"
	)


# --- Identity, evidence and authority ----------------------------------------


func _test_identity_and_authority(world: ShipyardWorld, cluster: NearbySectorCluster) -> void:
	var report := cluster.get_cluster_audit_report()
	_check(
		int(report.get("schema_version", 0)) == 1
		and StringName(report.get("component_id", &"")) == EXPECTED_COMPONENT_ID
		and StringName(report.get("evidence_status", &"")) == EXPECTED_EVIDENCE_STATUS,
		"the cluster publishes its v1 identity as modern interpretation"
	)
	_check(
		bool(report.get("valid", false)) and (report.get("errors", []) as Array).is_empty(),
		"the built cluster reports no placement or budget errors: %s" % [report.get("errors", [])]
	)
	_check(
		not bool(report.get("gameplay_authority", true))
		and not bool(report.get("grants_rewards", true))
		and int(report.get("range_targets_added", -1)) == 0,
		"the cluster declares no gameplay authority and no rewards"
	)
	_check(
		str(report.get("content_note", "")).find("No surviving source") >= 0,
		"the content note states plainly that no source authenticates the sector"
	)

	# The guided mission's objective count is `get_target_count()`. A decorative
	# drone anywhere in the cluster would silently rewrite it, so this is checked
	# against the live world rather than against the component's own claim.
	_check(world.get_target_count() == 4, "the world still owns exactly four range targets")
	var stray_targets := 0
	for candidate in cluster.find_children("*", "Node3D", true, false):
		if bool(candidate.get_meta("is_shipyard_target", false)):
			stray_targets += 1
	_check(stray_targets == 0, "the cluster contributes no range targets of its own")
	_check(
		cluster.find_children("*", "Area3D", true, false).is_empty(),
		"the cluster owns no interaction or trigger volumes"
	)

	# Structured red: the returned report is a deep copy, so a caller mutating it
	# cannot reach the component's record of what it built.
	var mutated := cluster.get_cluster_audit_report()
	mutated["valid"] = false
	mutated["gameplay_authority"] = true
	(mutated["errors"] as Array).append("injected")
	var reread := cluster.get_cluster_audit_report()
	_check(
		bool(reread.get("valid", false))
		and not bool(reread.get("gameplay_authority", true))
		and (reread.get("errors", []) as Array).is_empty(),
		"mutating a returned audit copy leaves the component's own report untouched"
	)


# --- Placement ----------------------------------------------------------------


func _test_placement_envelope(cluster: NearbySectorCluster) -> void:
	var platform_distance := cluster.get_platform_distance()
	_check(
		platform_distance > STATION_EXCLUSION_RADIUS
		and platform_distance < MAXIMUM_TRAVEL_DISTANCE,
		"the platform sits %.0f m out, inside the published travel envelope" % platform_distance
	)
	var cruise_seconds := cluster.get_cruise_travel_seconds()
	_check(
		cruise_seconds > 4.0 and cruise_seconds < 15.0,
		"a cruise transit is %.1f s: a decision to leave, not a chore" % cruise_seconds
	)

	# Nothing may crowd the station. Measured on every live body in the cluster,
	# not on the published anchors, so a stray beacon or boulder is caught.
	var nearest := INF
	var nearest_name := ""
	for candidate in cluster.find_children("*", "Node3D", true, false):
		var node := candidate as Node3D
		if not (node is StaticBody3D or node is MeshInstance3D or node is Light3D):
			continue
		var distance := node.global_position.length()
		if distance < nearest:
			nearest = distance
			nearest_name = str(node.name)
	_check(
		nearest >= STATION_EXCLUSION_RADIUS,
		"the nearest cluster body (%s) is %.0f m out, clear of the corridor and range"
		% [nearest_name, nearest]
	)

	var beacons := cluster.get_route_beacon_positions()
	_check(beacons.size() == EXPECTED_BEACON_COUNT, "the route is exactly four hand-placed beacons")
	var previous_distance := 0.0
	var ordered := true
	var spacing_ok := true
	for beacon in beacons:
		var distance := beacon.length()
		if distance <= previous_distance:
			ordered = false
		if previous_distance > 0.0 and distance - previous_distance > 200.0:
			spacing_ok = false
		previous_distance = distance
	_check(ordered, "the beacon chain runs monotonically outward from the station")
	_check(spacing_ok, "no leg of the chain leaves the pilot without a landmark")

	# The approach lane and the platform keep-clear sphere are what make the
	# destination reachable at speed regardless of the scatter seed.
	var boulders := cluster.get_boulder_offsets()
	var lane_intrusions := 0
	var keep_clear_intrusions := 0
	for offset in boulders:
		if offset.length() < EXPECTED_PLATFORM_KEEP_CLEAR:
			keep_clear_intrusions += 1
		if _is_inside_lane(offset):
			lane_intrusions += 1
	_check(
		boulders.size() == EXPECTED_BOULDER_COUNT,
		"the field placed its full complement of %d boulders" % EXPECTED_BOULDER_COUNT
	)
	_check(keep_clear_intrusions == 0, "no boulder stands inside the platform keep-clear sphere")
	_check(lane_intrusions == 0, "no boulder stands inside the approach lane")

	# The gate the lane leads to has to actually be open, and wide enough that a
	# 7 m interceptor is threading a structure rather than scraping one.
	var gate_center := cluster.get_dock_gate_center()
	_check(
		gate_center.distance_to(EXPECTED_PLATFORM_ANCHOR) < EXPECTED_LANE_LENGTH
		and EXPECTED_GATE_WIDTH >= 20.0
		and EXPECTED_GATE_HEIGHT >= 16.0,
		"the dock gate stands on the lane with a %.0f x %.0f m clear aperture"
		% [EXPECTED_GATE_WIDTH, EXPECTED_GATE_HEIGHT]
	)
	# Nothing solid may sit in the middle of the lane past the gate's far frame.
	# The gate's own members ring the aperture and stay outside this core.
	var lane_blockers := 0
	for candidate in cluster.find_children("*", "StaticBody3D", true, false):
		var body := candidate as StaticBody3D
		var offset := body.global_position - EXPECTED_PLATFORM_ANCHOR
		if offset.z <= EXPECTED_GATE_FAR_Z or offset.z >= EXPECTED_LANE_LENGTH:
			continue
		if Vector2(offset.x, offset.y - EXPECTED_LANE_CENTER_Y).length() < 10.0:
			lane_blockers += 1
	_check(lane_blockers == 0, "nothing solid stands in the middle of the gate aperture or the lane")


## Structured red for the placement rule: the predicate that keeps the lane and
## the platform clear must actively reject offsets inside them, not merely have
## produced a clean scatter by luck of the seed.
func _test_placement_predicate_rejects_the_lane(cluster: NearbySectorCluster) -> void:
	var inside_keep_clear := Vector3(0.0, 0.0, EXPECTED_PLATFORM_KEEP_CLEAR - 5.0)
	var inside_lane := Vector3(
		0.0,
		EXPECTED_LANE_CENTER_Y,
		EXPECTED_PLATFORM_KEEP_CLEAR + 20.0
	)
	var on_a_beacon := (
		(cluster.get_route_beacon_positions()[EXPECTED_BEACON_COUNT - 1]) - EXPECTED_PLATFORM_ANCHOR
	)

	_check(
		not bool(cluster.call("_is_placeable_boulder_offset", inside_keep_clear)),
		"a boulder offset inside the platform keep-clear sphere is rejected"
	)
	_check(
		not bool(cluster.call("_is_placeable_boulder_offset", inside_lane)),
		"a boulder offset inside the approach lane is rejected"
	)
	_check(
		not bool(cluster.call("_is_placeable_boulder_offset", on_a_beacon)),
		"a boulder offset on top of a route beacon is rejected"
	)
	# The predicate has to still say yes somewhere, or "rejects everything" would
	# read as a pass. A ring behind the platform, outside the keep-clear sphere and
	# outside the lane, is scanned rather than one hand-picked point, because a
	# single point can land inside the separation radius of a placed boulder.
	var accepted := 0
	for step in 36:
		var angle := TAU * float(step) / 36.0
		var probe := Vector3(cos(angle), 0.0, sin(angle)) * 150.0
		if bool(cluster.call("_is_placeable_boulder_offset", probe)):
			accepted += 1
	_check(
		accepted > 0,
		"open field outside the lane still accepts boulders (%d of 36 ring probes)" % accepted
	)


## Whether a platform-relative offset lies inside the approach lane, measured
## against this suite's frozen lane dimensions.
func _is_inside_lane(offset: Vector3) -> bool:
	if offset.z <= 0.0 or offset.z >= EXPECTED_LANE_LENGTH:
		return false
	return Vector2(offset.x, offset.y - EXPECTED_LANE_CENTER_Y).length() < EXPECTED_LANE_RADIUS


# --- Winding ------------------------------------------------------------------


## Every surface the cluster builds has to face outward. The kit's box builder is
## already guarded, but this component drives it at a bevel proportion nothing
## else uses (0.30 of the shortest side, on 20-64 m stock), so the built tree is
## measured rather than the builder trusted.
func _test_winding(cluster: NearbySectorCluster) -> void:
	var expected_sign := _calibrate()
	_check(expected_sign != 0, "engine primitives agree on one front-face winding convention")
	if expected_sign == 0:
		return

	var meshes: Dictionary = {}
	for candidate in cluster.find_children("*", "MeshInstance3D", true, false):
		var mesh := (candidate as MeshInstance3D).mesh
		if mesh is ArrayMesh:
			meshes[mesh.get_instance_id()] = mesh
	for candidate in cluster.find_children("*", "MultiMeshInstance3D", true, false):
		var multimesh := (candidate as MultiMeshInstance3D).multimesh
		if multimesh != null and multimesh.mesh is ArrayMesh:
			meshes[multimesh.mesh.get_instance_id()] = multimesh.mesh
	_check(
		meshes.size() >= 12,
		"the cluster's built tree offers %d distinct procedural meshes to measure" % meshes.size()
	)

	var backwards_meshes := 0
	var measured_triangles := 0
	var sample: ArrayMesh = null
	for id: int in meshes:
		var mesh := meshes[id] as ArrayMesh
		if sample == null:
			sample = mesh
		var report := _score(mesh)
		var triangles := int(report["triangles"])
		var agreeing := int(report["agreeing"])
		measured_triangles += triangles
		var backwards := agreeing if expected_sign == -1 else triangles - agreeing
		if triangles == 0 or backwards > 0:
			backwards_meshes += 1
	_check(
		backwards_meshes == 0 and measured_triangles > 0,
		"all %d cluster meshes wind every one of their %d triangles outward"
		% [meshes.size(), measured_triangles]
	)

	# Structured red: a deliberately reversed copy of a real cluster mesh must
	# read as fully backwards, or the measurement above proves nothing.
	if sample != null:
		var reversed_report := _score(_reverse(sample))
		var reversed_triangles := int(reversed_report["triangles"])
		var reversed_agreeing := int(reversed_report["agreeing"])
		var reversed_backwards := (
			reversed_agreeing if expected_sign == -1 else reversed_triangles - reversed_agreeing
		)
		_check(
			reversed_triangles > 0 and reversed_backwards == reversed_triangles,
			"a reversed copy of a cluster mesh is detected as fully backwards (%d/%d)"
			% [reversed_backwards, reversed_triangles]
		)


func _calibrate() -> int:
	var signs: Dictionary = {}
	for mesh_class in ENGINE_CALIBRATION_MESHES:
		var mesh := ClassDB.instantiate(mesh_class) as Mesh
		if mesh == null:
			continue
		var report := _score(mesh)
		var triangles := int(report["triangles"])
		var agreeing := int(report["agreeing"])
		if triangles == 0:
			continue
		if agreeing == 0:
			signs[-1] = true
		elif agreeing == triangles:
			signs[1] = true
		else:
			signs[0] = true
	if signs.size() != 1 or signs.has(0):
		return 0
	return -1 if signs.has(-1) else 1


func _reverse(source: ArrayMesh) -> ArrayMesh:
	var arrays: Array = source.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var reversed_verts := PackedVector3Array()
	var reversed_norms := PackedVector3Array()
	var index := 0
	while index + 2 < verts.size():
		reversed_verts.append(verts[index])
		reversed_verts.append(verts[index + 2])
		reversed_verts.append(verts[index + 1])
		reversed_norms.append(norms[index])
		reversed_norms.append(norms[index + 2])
		reversed_norms.append(norms[index + 1])
		index += 3
	var reversed_arrays: Array = []
	reversed_arrays.resize(Mesh.ARRAY_MAX)
	reversed_arrays[Mesh.ARRAY_VERTEX] = reversed_verts
	reversed_arrays[Mesh.ARRAY_NORMAL] = reversed_norms
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, reversed_arrays)
	return mesh


func _score(mesh: Mesh) -> Dictionary:
	var triangles := 0
	var agreeing := 0
	for surface in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(surface)
		if arrays.is_empty() or arrays[Mesh.ARRAY_NORMAL] == null:
			continue
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = (
			arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		)
		var count := idx.size() if idx.size() > 0 else verts.size()
		var cursor := 0
		while cursor + 2 < count:
			var a_i := idx[cursor] if idx.size() > 0 else cursor
			var b_i := idx[cursor + 1] if idx.size() > 0 else cursor + 1
			var c_i := idx[cursor + 2] if idx.size() > 0 else cursor + 2
			cursor += 3
			var geometric := (verts[b_i] - verts[a_i]).cross(verts[c_i] - verts[a_i])
			if geometric.length() < 1e-9:
				continue
			var shading := norms[a_i] + norms[b_i] + norms[c_i]
			if shading.length() < 1e-6:
				continue
			triangles += 1
			if geometric.normalized().dot(shading.normalized()) > 0.0:
				agreeing += 1
	return {"triangles": triangles, "agreeing": agreeing}


# --- Collision ----------------------------------------------------------------


func _test_collision_boundary(cluster: NearbySectorCluster) -> void:
	var bodies := cluster.find_children("*", "StaticBody3D", true, false)
	_check(bodies.size() > 20, "the cluster's solid structures are real bodies (%d)" % bodies.size())
	var wrong_layer := 0
	var wrong_mask := 0
	var shapeless := 0
	for candidate in bodies:
		var body := candidate as StaticBody3D
		if body.collision_layer != PhysicsLayers.WORLD:
			wrong_layer += 1
		if body.collision_mask != 0:
			wrong_mask += 1
		if body.find_children("*", "CollisionShape3D", false, false).is_empty():
			shapeless += 1
	_check(wrong_layer == 0, "every cluster body sits on the same World layer the station uses")
	_check(wrong_mask == 0, "no cluster body queries other layers")
	_check(shapeless == 0, "every cluster body carries its own collision shape")

	# Structured red: the same predicate must reject a body built on the wrong
	# layer, so a clean scan above is a measurement and not a tautology.
	var rogue := StaticBody3D.new()
	rogue.collision_layer = PhysicsLayers.TARGET
	rogue.collision_mask = PhysicsLayers.WORLD
	_check(
		rogue.collision_layer != PhysicsLayers.WORLD and rogue.collision_mask != 0,
		"a body on the target layer with a live mask is distinguishable from a cluster body"
	)
	rogue.free()

	# The beacon chain is the one thing that must *not* be solid: it stands in the
	# lane the pilot is told to follow.
	var beacon_root := cluster.get_node_or_null(^"RouteBeacons") as Node3D
	_check(
		beacon_root != null
		and beacon_root.find_children("*", "StaticBody3D", true, false).is_empty(),
		"the route beacons are presentation only and cannot be collided with"
	)


# --- Determinism and lifecycle -----------------------------------------------


func _test_determinism(cluster: NearbySectorCluster, twin: NearbySectorCluster) -> void:
	var first := cluster.get_boulder_offsets()
	var second := twin.get_boulder_offsets()
	var identical := first.size() == second.size()
	if identical:
		for index in first.size():
			if not first[index].is_equal_approx(second[index]):
				identical = false
				break
	_check(identical, "two independent builds scatter the same field from the same fixed seed")

	var chips_a := cluster.get_node_or_null(^"DebrisField/DebrisChips") as MultiMeshInstance3D
	var chips_b := twin.get_node_or_null(^"DebrisField/DebrisChips") as MultiMeshInstance3D
	_check(chips_a != null and chips_b != null, "both builds carry the instanced debris shell")
	if chips_a == null or chips_b == null:
		return
	_check(
		chips_a.multimesh.instance_count == EXPECTED_DEBRIS_CHIP_COUNT
		and chips_b.multimesh.instance_count == EXPECTED_DEBRIS_CHIP_COUNT,
		"the debris shell carries its exact declared instance count"
	)
	var transforms_match := true
	var colors_match := true
	for index in [0, 137, 419, EXPECTED_DEBRIS_CHIP_COUNT - 1]:
		if not chips_a.multimesh.get_instance_transform(index).is_equal_approx(
			chips_b.multimesh.get_instance_transform(index)
		):
			transforms_match = false
		if not chips_a.multimesh.get_instance_color(index).is_equal_approx(
			chips_b.multimesh.get_instance_color(index)
		):
			colors_match = false
	_check(transforms_match and colors_match, "the debris shell is instanced identically every build")

	# Determinism is meaningless if the two builds are the same object.
	_check(
		cluster.get_instance_id() != twin.get_instance_id(),
		"the two compared clusters are genuinely separate instances"
	)


func _test_lifecycle(world: ShipyardWorld, cluster: NearbySectorCluster) -> void:
	_check(
		cluster.is_cluster_enabled() and cluster.visible and cluster.is_processing(),
		"the cluster starts enabled, visible and animating"
	)
	var body_count := cluster.find_children("*", "StaticBody3D", true, false).size()
	var shape_count := cluster.find_children("*", "CollisionShape3D", true, false).size()

	cluster.set_cluster_enabled(false)
	await process_frame
	_check(
		not cluster.visible and not cluster.is_processing(),
		"disabling the cluster stops every animated element and hides it"
	)
	cluster.set_cluster_enabled(true)
	await process_frame
	_check(
		cluster.visible and cluster.is_processing(),
		"re-enabling restores visibility and animation without rebuilding"
	)

	for quality in [
		NearbySectorCluster.DetailQuality.LOW,
		NearbySectorCluster.DetailQuality.MEDIUM,
		NearbySectorCluster.DetailQuality.HIGH,
	]:
		cluster.set_detail_quality(quality)
		var chips := cluster.get_node_or_null(^"DebrisField/DebrisChips") as MultiMeshInstance3D
		_check(
			chips != null
			and chips.visible == (quality >= NearbySectorCluster.DetailQuality.MEDIUM),
			"quality %d shows the fine debris shell only above the lowest profile" % quality
		)
		_check(
			cluster.find_children("*", "StaticBody3D", true, false).size() == body_count
			and cluster.find_children("*", "CollisionShape3D", true, false).size() == shape_count,
			"quality %d leaves the flyable shape of the sector untouched" % quality
		)
	cluster.set_detail_quality(NearbySectorCluster.DetailQuality.HIGH)

	# Whole-world detach and re-entry, the way `Main` streams the shipyard.
	var parent := cluster.get_parent()
	var report_before := cluster.get_cluster_audit_report()
	parent.remove_child(cluster)
	await process_frame
	_check(not cluster.is_inside_tree(), "the cluster detaches cleanly from the world")
	parent.add_child(cluster)
	await process_frame
	await process_frame
	_check(
		cluster.is_inside_tree()
		and cluster.visible
		and cluster.is_processing(),
		"re-entry restores the cluster's animation lifecycle"
	)
	_check(
		cluster.get_cluster_audit_report() == report_before
		and cluster.get_boulder_offsets().size() == EXPECTED_BOULDER_COUNT,
		"re-entry keeps the identical built field rather than scattering a second one"
	)
	_check(
		world.get_nearby_sector_cluster() == cluster
		and bool(world.get_nearby_sector_cluster_audit_report().get("valid", false)),
		"the world still resolves the same cluster and its audit after re-entry"
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
	print("NEARBY_SECTOR_CLUSTER_TEST_ASSERTIONS: ", _assertions)
	if _failures.is_empty():
		print("NEARBY_SECTOR_CLUSTER_TEST_OK")
		quit(0)
	else:
		print("NEARBY_SECTOR_CLUSTER_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
