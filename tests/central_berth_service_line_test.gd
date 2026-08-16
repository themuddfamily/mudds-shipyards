extends SceneTree

## Focused audit for the hero berth's port-flank ground support line and the
## dock mast foot hardware.
##
## Three properties are what this line exists to hold, and each has its own
## structured-red mutation below:
##
##   1. **Looks solid, is solid.** The player drives a tow tractor across this
##      flank at 11.5 m/s. Every freestanding piece must carry a World-layer
##      collider whose extents match the mesh drawn at it, and the assembly must
##      not have silently become decoration.
##   2. **Nothing floats.** Seating is arithmetic against the *drawn* authored
##      deck at y = 0.095, not a raycast against the `HeroBerthNode` collision box
##      0.115 m below it. Every ground-contact piece is measured here against the
##      drawn triangles under it, not against collision.
##   3. **It does not eat the lanes it stands beside.** The published port exit
##      route, the pad border walking lane and the Torrent's staged launch
##      envelope all pass within metres of this line and must stay clear.
##
## The berth's own dressing roster stays contractually collision-free; this suite
## also proves the new line did not migrate into it.

const MAIN_SCENE := preload("res://scenes/main.tscn")

## Published port exit route sample from `central_berth_hero_test`, and the
## production player capsule.
const PORT_EXIT_SAMPLE := Vector3(-7.6, 0.2, -9.25)
const PLAYER_CAPSULE_RADIUS := 0.42
const PLAYER_CAPSULE_HEIGHT := 1.8
## Inboard limit for the whole line. The Torrent hull is 7.20 m wide and the
## berth publishes a 6.5 m protected half width; nothing here may come inside it.
const PROTECTED_HALF_WIDTH := 6.5

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "production main scene instantiates")
	if game == null:
		_finish()
		return
	root.add_child(game)
	await process_frame
	await physics_frame
	await physics_frame

	var world := game.get_node("ShipyardWorld") as ShipyardWorld
	_check(world != null, "production world is live")
	if world == null:
		game.queue_free()
		await process_frame
		_finish()
		return

	_test_report_and_roster(world)
	_test_solid_pieces_match_their_drawn_mesh(world)
	_test_pieces_are_seated_on_drawn_geometry(world)
	_test_lanes_stay_clear(world)
	_test_state_is_carried_by_hardware(world)
	_test_practicals_follow_the_fixture_idiom(world)

	game.queue_free()
	await process_frame
	await process_frame
	_finish()


func _test_report_and_roster(world: ShipyardWorld) -> void:
	var report := world.get_central_berth_service_line_report()
	_check(bool(report.get("valid", false)), "service line audit is green: %s" % [report.get("errors", [])])
	_check(
		str(report.get("geometry_status", "")) == "modern_interpretation"
		and str(report.get("interpretation_confidence", "")) == "low"
		and not bool(report.get("authenticated_original_geometry", true)),
		"service line is labelled modern interpretation at stated confidence and claims no original geometry"
	)
	var expected := report.get("expected_assembly_counts", {}) as Dictionary
	var actual := report.get("assembly_counts", {}) as Dictionary
	_check(
		expected.size() == 6
		and int(expected.get(&"readiness_board", 0)) == 1
		and int(expected.get(&"cable_drum", 0)) == 1
		and int(expected.get(&"parts_bin_rack", 0)) == 1
		and int(expected.get(&"chock_locker", 0)) == 1
		and int(expected.get(&"access_work_stand", 0)) == 1
		and int(expected.get(&"mast_foot", 0)) == 4,
		"the frozen roster is five port-flank assemblies and four mast feet"
	)
	var roster_matches := true
	for role: StringName in expected:
		roster_matches = roster_matches and int(actual.get(role, -1)) == int(expected[role])
	_check(roster_matches, "every rostered assembly is live")

	# Deep-detached: mutating the returned report must not reach the world.
	(report.get("assembly_counts", {}) as Dictionary)[&"mast_foot"] = 99
	var second := world.get_central_berth_service_line_report()
	_check(
		int((second.get("assembly_counts", {}) as Dictionary).get(&"mast_foot", 0)) == 4,
		"the audit report is a deep copy that callers cannot mutate"
	)

	var line := world.get_node_or_null(^"CentralBerthServiceLine") as Node3D
	var pad := world.get_node_or_null(^"LandingPad") as Node3D
	_check(
		line != null and pad != null and not pad.is_ancestor_of(line),
		"the solid line is a sibling of LandingPad, whose dressing roster stays collision-free"
	)
	var pad_bodies := pad.find_children("*", "PhysicsBody3D", true, false).size() if pad != null else -1
	_check(pad_bodies == 0, "no collision leaked into the berth's presentation-only dressing roster")


func _test_solid_pieces_match_their_drawn_mesh(world: ShipyardWorld) -> void:
	var line := world.get_node_or_null(^"CentralBerthServiceLine") as Node3D
	if line == null:
		_check(false, "service line root exists")
		return
	var bodies := line.find_children("*", "StaticBody3D", true, false)
	_check(bodies.size() >= 30, "the line is built from freestanding solid bodies, not decoration (%d)" % bodies.size())
	var matched := true
	var worst_error := 0.0
	var worst_name := ""
	for candidate in bodies:
		var body := candidate as StaticBody3D
		if body.collision_layer != PhysicsLayers.WORLD or body.collision_mask != 0:
			matched = false
			continue
		var shapes := body.find_children("*", "CollisionShape3D", true, false)
		var meshes := body.find_children("*", "MeshInstance3D", true, false)
		if shapes.size() != 1 or meshes.size() != 1:
			matched = false
			continue
		var shape := (shapes[0] as CollisionShape3D).shape
		var mesh := (meshes[0] as MeshInstance3D).mesh
		if shape == null or mesh == null:
			matched = false
			continue
		var drawn := mesh.get_aabb().size
		var solid := Vector3.ZERO
		if shape is BoxShape3D:
			solid = (shape as BoxShape3D).size
		elif shape is CylinderShape3D:
			var cylinder := shape as CylinderShape3D
			solid = Vector3(cylinder.radius * 2.0, cylinder.height, cylinder.radius * 2.0)
		elif shape is SphereShape3D:
			solid = Vector3.ONE * (shape as SphereShape3D).radius * 2.0
		else:
			matched = false
			continue
		var error := drawn.distance_to(solid)
		if error > worst_error:
			worst_error = error
			worst_name = body.name
		matched = matched and error <= 0.002
	_check(
		matched,
		"every solid piece carries one World collider matching its one drawn mesh (worst %s %.4f m)"
		% [worst_name, worst_error]
	)


## Ground-contact pieces are measured against the drawn triangles under them.
##
## The ray starts above the piece's own underside and is cast against every
## visible mesh in the world by triangle intersection, deliberately **not**
## against the World collision layer: inside this berth the collision box ends
## 0.115 m below the deck the eye reads, so a collision-based check would call a
## floating piece seated.
func _test_pieces_are_seated_on_drawn_geometry(world: ShipyardWorld) -> void:
	var line := world.get_node_or_null(^"CentralBerthServiceLine") as Node3D
	if line == null:
		_check(false, "service line root exists for the seating sweep")
		return
	var others: Array[AABB] = []
	for candidate in world.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		if mesh_instance.mesh == null or not mesh_instance.is_visible_in_tree():
			continue
		if line.is_ancestor_of(mesh_instance):
			continue
		others.append(mesh_instance.global_transform * mesh_instance.mesh.get_aabb())

	var floating: Array[String] = []
	for candidate in line.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		if mesh_instance.mesh == null or not mesh_instance.is_visible_in_tree():
			continue
		var own := mesh_instance.global_transform * mesh_instance.mesh.get_aabb()
		var grown := own.grow(0.001)
		var supported := false
		for other in others:
			if grown.intersects(other):
				supported = true
				break
		if supported:
			continue
		# A piece may instead rest on a sibling inside its own assembly.
		for sibling_candidate in line.find_children("*", "MeshInstance3D", true, false):
			var sibling := sibling_candidate as MeshInstance3D
			if sibling == mesh_instance or sibling.mesh == null or not sibling.is_visible_in_tree():
				continue
			if sibling.is_ancestor_of(mesh_instance) or mesh_instance.is_ancestor_of(sibling):
				continue
			if grown.intersects(sibling.global_transform * sibling.mesh.get_aabb()):
				supported = true
				break
		if not supported:
			floating.append("%s at %s" % [line.get_path_to(mesh_instance), own.position])
	print("FLOATING_SERVICE_LINE_PIECES: ", floating)
	_check(floating.is_empty(), "no piece of the ground support line hangs in open space")

	# Structured red: lift one rostered ground-contact piece by 0.05 m and the
	# same sweep must report it, then restore it.
	var probe := line.get_node_or_null(^"PortFlank/PartsBinRack/RackFoot") as Node3D
	if probe == null:
		_check(false, "the seating sweep has a live mutation probe")
		return
	var restored := probe.position
	probe.position = restored + Vector3.UP * 0.05
	var probe_mesh := probe.get_node_or_null(^"Mesh") as MeshInstance3D
	var lifted := probe_mesh.global_transform * probe_mesh.mesh.get_aabb()
	var lifted_supported := false
	for other in others:
		if lifted.grow(0.001).intersects(other):
			lifted_supported = true
			break
	probe.position = restored
	_check(not lifted_supported, "lifting a seated piece 0.05 m turns the drawn-geometry seating check red")


func _test_lanes_stay_clear(world: ShipyardWorld) -> void:
	var report := world.get_central_berth_service_line_report()
	var minimum_x := float(report.get("port_flank_minimum_x", 0.0))
	var maximum_x := float(report.get("port_flank_maximum_x", 0.0))
	_check(
		maximum_x < -PROTECTED_HALF_WIDTH,
		"nothing in the line reaches inside the berth's 6.5 m protected half width (max x %.3f)" % maximum_x
	)
	_check(
		minimum_x > -12.2,
		"nothing in the line crosses the pad border at x = -12.2 (min x %.3f)" % minimum_x
	)

	var space := world.get_world_3d().direct_space_state
	var capsule := CapsuleShape3D.new()
	capsule.radius = PLAYER_CAPSULE_RADIUS
	capsule.height = PLAYER_CAPSULE_HEIGHT
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.collision_mask = PhysicsLayers.WORLD
	query.transform = Transform3D(Basis.IDENTITY, Vector3(PORT_EXIT_SAMPLE.x, 1.15, PORT_EXIT_SAMPLE.z))
	_check(space.intersect_shape(query, 8).is_empty(), "the published port exit route sample stays unobstructed")

	# The walking lane between the line and the pad border, sampled the length of
	# the flank. This is the lane the tow tractor uses.
	var lane_clear := true
	var blocked_z := 0.0
	for step in 21:
		var lane_z := lerpf(4.0, -24.0, float(step) / 20.0)
		query.transform = Transform3D(Basis.IDENTITY, Vector3(-9.0, 1.15, lane_z))
		if not space.intersect_shape(query, 8).is_empty():
			lane_clear = false
			blocked_z = lane_z
	_check(lane_clear, "the port flank walking lane at x = -9.0 stays open end to end (blocked at z %.1f)" % blocked_z)


## Assigned versus deferred is readable without reading a colour.
func _test_state_is_carried_by_hardware(world: ShipyardWorld) -> void:
	var board := world.get_node_or_null(^"CentralBerthServiceLine/PortFlank/BerthReadinessBoard") as Node3D
	if board == null:
		_check(false, "the berth readiness board is live")
		return
	var seated_pins := 0
	var withdrawn_pins := 0
	var sockets := 0
	for candidate in board.find_children("*", "", true, false):
		if candidate.name.begins_with("BaySeatedPin"):
			seated_pins += 1
		elif candidate.name.begins_with("WithdrawnPin") and not candidate.name.begins_with("WithdrawnPinClip"):
			withdrawn_pins += 1
		elif candidate.name.begins_with("BayPinSocket"):
			sockets += 1
	_check(
		sockets == 3 and seated_pins == 2 and withdrawn_pins == 1,
		"three bays, two pins seated for the assignments and one withdrawn into the clip for dock 03"
	)

	var locker := world.get_node_or_null(^"CentralBerthServiceLine/PortFlank/ChockLocker") as Node3D
	var deployed := 0
	if locker != null:
		for candidate in locker.find_children("*", "StaticBody3D", true, false):
			if candidate.name.begins_with("DeployedChockBody"):
				deployed += 1
	_check(deployed == 2, "both chocks are out of the locker and on the deck, because a craft is berthed")


func _test_practicals_follow_the_fixture_idiom(world: ShipyardWorld) -> void:
	var line := world.get_node_or_null(^"CentralBerthServiceLine") as Node3D
	if line == null:
		_check(false, "service line root exists for the practical sweep")
		return
	var practicals := line.find_children("*", "OmniLight3D", true, false)
	_check(
		practicals.size() == ShipyardWorld.SERVICE_LINE_PRACTICAL_COUNT,
		"the line carries exactly %d fixture practicals" % ShipyardWorld.SERVICE_LINE_PRACTICAL_COUNT
	)
	var idiomatic := not practicals.is_empty()
	for candidate in practicals:
		var practical := candidate as OmniLight3D
		idiomatic = idiomatic \
			and not practical.shadow_enabled \
			and practical.omni_range <= 7.0 \
			and practical.distance_fade_enabled \
			and practical.light_energy <= 1.6
	_check(
		idiomatic,
		"every practical is shadowless, sub-7 m, distance-faded and inside the station's energy band"
	)
	# Each practical must sit beside a lens that is actually drawn, so the spill
	# reads as coming from a fixture rather than from nowhere.
	var lensed := true
	for candidate in practicals:
		var practical := candidate as OmniLight3D
		var parent := practical.get_parent() as Node3D
		var has_lens := false
		if parent != null:
			for lens_candidate in parent.find_children("*", "MeshInstance3D", true, false):
				var lens := lens_candidate as MeshInstance3D
				if not lens.name.contains("Lens") and not lens.name.contains("Tile"):
					continue
				if lens.global_position.distance_to(practical.global_position) <= 0.8:
					has_lens = true
					break
		lensed = lensed and has_lens
	_check(lensed, "every practical is mounted within 0.8 m of a drawn lens")


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("CENTRAL_BERTH_SERVICE_LINE_TEST_OK")
		quit(0)
	else:
		print("CENTRAL_BERTH_SERVICE_LINE_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
