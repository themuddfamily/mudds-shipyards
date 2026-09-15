extends SceneTree

const WORLD_SCENE := preload("res://scenes/world/shipyard_world.tscn")

## Sample pitch of the published-lane sweep below, in metres. The hauler's
## shortest root shape is 0.3 m thick, so a quarter-metre pitch cannot step over
## a mullion, a header or a comb tooth standing in the lane.
const LANE_SAMPLE_STEP_M := 0.25

var _assertions := 0
var _failures: Array[String] = []


func _initialize() -> void:
	var world := WORLD_SCENE.instantiate() as ShipyardWorld
	root.add_child(world)
	await process_frame
	await process_frame
	var binding := world.get_fleet_expansion_production_binding()
	_check(binding != null and binding.get_parent() == world, "ShipyardWorld owns the fleet expansion production binding")
	var audit := world.get_fleet_expansion_production_audit_report()
	_check(bool(audit.get("valid", false)), "ShipyardWorld publishes a valid Dock 04/05/06 production audit")
	var snapshot := audit.get("snapshot", {}) as Dictionary
	var craft := snapshot.get("craft", []) as Array
	_check(craft.size() == 3, "production integration publishes cargo, bomber, and interceptor")
	var expected := [&"dock_04_cargo", &"dock_05_bomber", &"dock_06_interceptor"]
	for index in craft.size():
		var row := craft[index] as Dictionary
		_check(row.get("pad_id", &"") == expected[index] and bool(row.get("attached", false)), "Dock %s remains attached" % expected[index])
	_test_access_geometry_clearance(world)
	_test_published_approach_lanes_are_flyable(world)
	_test_service_dressing_stands_in_no_other_module(world)
	world.queue_free()
	await process_frame
	if _failures.is_empty():
		print("PASS fleet_expansion_shipyard_integration_test (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


## Six declared Cinder route boxes join existing deck edges, but must not
## double-author any positive area or intrude into a live berth volume. This
## runs against the instantiated production world so module transforms are part
## of the contract, rather than comparing unrelated local coordinates.
func _test_access_geometry_clearance(world: ShipyardWorld) -> void:
	var circulation := world.get_node_or_null(
		^"FleetExpansionProductionBinding/FleetExpansionBerths/AccessCirculation"
	) as Node3D
	var existing_roots: Array[Node] = [
		world.get_node_or_null(^"FleetDockComb/GeneratedComb/WalkableSurfaces"),
		world.get_node_or_null(^"ExposedDockLattice/FleetDockCombConnector"),
		world.get_node_or_null(^"ExposedDockLattice/HalyardBerthApron"),
		world.get_node_or_null(^"AftJunctionStack"),
	]
	var resolved := circulation != null
	for existing_root in existing_roots:
		resolved = resolved and existing_root != null
	_check(resolved, "Cinder circulation and all four adjoining production-geometry owners resolve")
	if not resolved:
		return

	var access_bodies: Array[StaticBody3D] = []
	for candidate in circulation.find_children("*", "StaticBody3D", true, false):
		access_bodies.append(candidate as StaticBody3D)
	_check(access_bodies.size() == 6, "Cinder circulation exposes exactly six collision-backed route boxes")
	var broad_pad_surfaces := world.find_children("ServicePadSurface*", "MeshInstance3D", true, false)
	var broad_pad_bodies := world.find_children("WalkablePadCollision", "StaticBody3D", true, false)
	_check(
		broad_pad_surfaces.is_empty() and broad_pad_bodies.is_empty(),
		"logical Dock 04/05/06 owners expose no broad pad render or collision"
	)

	var existing_bodies: Array[StaticBody3D] = []
	for existing_root in existing_roots:
		if existing_root is StaticBody3D:
			existing_bodies.append(existing_root as StaticBody3D)
		for candidate in existing_root.find_children("*", "StaticBody3D", true, false):
			existing_bodies.append(candidate as StaticBody3D)
	var surface_overlaps := PackedStringArray()
	for access_body in access_bodies:
		var access_box := _collision_body_box(access_body)
		for existing_body in existing_bodies:
			var overlap := _aabb_overlap_depth(access_box, _collision_body_box(existing_body))
			if overlap.x > 0.001 and overlap.y > 0.001 and overlap.z > 0.001:
				surface_overlaps.append("%s x %s depth=%s" % [
					access_body.name, existing_body.name, overlap,
				])
	_check(
		surface_overlaps.is_empty(),
		"Cinder access surfaces only meet existing production decks at boundaries: %s" % surface_overlaps
	)

	var berth_overlaps := PackedStringArray()
	for access_body in access_bodies:
		var access_box := _collision_body_box(access_body)
		for berth_id in world.get_berth_ids():
			var berth := world.get_berth_node(berth_id)
			var half := berth.get_landing_half_extents()
			var berth_box := (berth.get_dock_transform() * AABB(-half, half * 2.0)).abs()
			var overlap := _aabb_overlap_depth(access_box, berth_box)
			if overlap.x > 0.001 and overlap.y > 0.001 and overlap.z > 0.001:
				berth_overlaps.append("%s x %s depth=%s" % [access_body.name, berth_id, overlap])
	_check(
		berth_overlaps.is_empty(),
		"every Cinder access surface clears every authoritative production berth volume: %s" % berth_overlaps
	)


## Reproduction this exists for: the long-session soak flew the Cinder cargo
## hauler home on Dock 04's own published assist-capture lane, and the real
## landing assist stalled 1.56 m short of the berth and aborted
## `approach_obstructed` on every cycle. The lane was accepted and unflyable:
## `VipReceptionSuite` — a cantilevered pod a week older than this module —
## stands at world x = -0.45, and Dock 04's published parked pose put the
## hauler's nose at x = -2.0, so the last 1.55 m of the lane ran through the
## reception's aft wall, ceiling and outboard glazing.
##
## What is measured here, against the live production world with each craft's
## real root collision shapes rather than an authored hull table: every
## expansion berth's published lane, sampled from the assist-capture pose to the
## dock pose at the berth's own docked attitude, is clear of every World-layer
## body. A berth that publishes a lane it cannot be flown down is the defect,
## whichever side moved into it.
func _test_published_approach_lanes_are_flyable(world: ShipyardWorld) -> void:
	# The expansion berths are deferred children: production re-indexes them at
	# the same boundary that admits their craft, and the lane is only publishable
	# once the world's own berth registry can resolve them.
	_check(
		world.refresh_deferred_fleet_expansion_berths(),
		"the world re-indexes the three deferred expansion berths into its registry"
	)
	var binding := world.get_fleet_expansion_production_binding()
	# Pair each pad with its craft through the binding's own published fleet
	# snapshot rather than a second table here: the pairing under test is the
	# production one. `home_berth_id` is deliberately not used — GameFlow assigns
	# that at boot and this suite drives the world without it.
	var craft_by_id := {}
	for candidate in (binding.find_children("*", "HeroShip", true, false) if binding != null else []):
		var hero := candidate as HeroShip
		craft_by_id[hero.get_ship_id()] = hero
	var craft_by_pad := {}
	for row_variant: Variant in (binding.get_fleet_snapshot().get("craft", []) as Array):
		var row := row_variant as Dictionary
		var attached_craft := craft_by_id.get(StringName(row.get("craft_id", &""))) as HeroShip
		if attached_craft != null:
			craft_by_pad[StringName(row.get("pad_id", &""))] = attached_craft
	_check(
		craft_by_pad.size() == 3
		and craft_by_pad.has(&"dock_04_cargo")
		and craft_by_pad[&"dock_04_cargo"] is CinderCargoHauler,
		"all three expansion craft resolve, and Dock 04's is the real cargo hauler"
	)
	if not craft_by_pad.has(&"dock_04_cargo"):
		return
	for pad_id: StringName in [&"dock_04_cargo", &"dock_05_bomber", &"dock_06_interceptor"]:
		var craft := craft_by_pad.get(pad_id) as HeroShip
		var berth := world.get_berth_node(pad_id)
		if craft == null or berth == null:
			_check(false, "%s publishes a berth and an attached craft to measure" % pad_id)
			continue
		var blockers := _lane_blockers(craft, berth)
		_check(
			blockers.is_empty(),
			"%s's published approach lane is clear for %s's real collision shapes: %s" % [
				pad_id, craft.get_ship_id(), ", ".join(blockers),
			]
		)


## Every sample is the craft's own enabled root collision shapes at the berth's
## docked attitude, swept along the published line at `LANE_SAMPLE_STEP_M`. The
## craft itself is excluded; nothing else is.
func _lane_blockers(craft: HeroShip, berth: ShipBerth) -> PackedStringArray:
	var blockers := PackedStringArray()
	var space := craft.get_world_3d().direct_space_state
	var dock := berth.get_dock_transform()
	var capture := berth.get_assist_capture_transform()
	var samples := maxi(2, int(ceil(capture.origin.distance_to(dock.origin) / LANE_SAMPLE_STEP_M)))
	for step in range(samples + 1):
		var candidate := Transform3D(
			dock.basis, capture.origin.lerp(dock.origin, float(step) / float(samples))
		)
		for child in craft.get_children():
			if child is not CollisionShape3D:
				continue
			var collision := child as CollisionShape3D
			if collision.disabled or collision.shape == null:
				continue
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = collision.shape
			query.transform = candidate * collision.transform
			query.collision_mask = craft.collision_mask
			query.collide_with_bodies = true
			query.collide_with_areas = false
			query.exclude = [craft.get_rid()]
			for hit in space.intersect_shape(query, 4):
				var collider := hit.get("collider") as Node
				if collider == null:
					continue
				var described := "%s (%s)" % [collider.get_path(), collision.name]
				if not blockers.has(described):
					blockers.append(described)
	return blockers


func _collision_body_box(body: StaticBody3D) -> AABB:
	var merged := AABB()
	var found := false
	for candidate in body.find_children("*", "CollisionShape3D", true, false):
		var collision := candidate as CollisionShape3D
		if collision.shape == null or collision.disabled:
			continue
		var local_box: AABB
		if collision.shape is BoxShape3D:
			var size := (collision.shape as BoxShape3D).size
			local_box = AABB(-size * 0.5, size)
		else:
			local_box = collision.shape.get_debug_mesh().get_aabb()
		var world_box := (collision.global_transform * local_box).abs()
		merged = merged.merge(world_box) if found else world_box
		found = true
	return merged


func _aabb_overlap_depth(first: AABB, second: AABB) -> Vector3:
	return Vector3(
		minf(first.end.x, second.end.x) - maxf(first.position.x, second.position.x),
		minf(first.end.y, second.end.y) - maxf(first.position.y, second.position.y),
		minf(first.end.z, second.end.z) - maxf(first.position.z, second.position.z)
	)


## CAMERA-LANE. Nothing this module draws may stand inside another module's
## solid geometry.
##
## Reproduction this exists for: the ship-perspective camera audit
## (`tools/camera_intrusion_audit.gd`, `docs/CAMERA_INTRUSION_AUDIT.md`) found
## the player's chase near plane 0.615 m inside Dock 04's `CargoContainerBatch`
## and 0.737 m inside Dock 06's `LaunchFramePort`. Neither was really a camera
## defect. The container row — three 7 m boxes at pad-local x = 18 on a pad whose
## own half-width is 14 m — stood inside `VipReceptionSuite`'s reception and
## threshold, inside `AftJunctionStack`'s operations room and upper deck, through
## the fleet-dock comb connector deck and both its rails, and on top of the
## comb's trunk walking plate; two of the three were entirely buried inside other
## modules' interiors. The launch frame stood inside Dock 04's own published
## approach lane, which `_test_published_approach_lanes_are_flyable()` above
## could not see because the post carried no collision.
##
## The same class of defect as 55d7d3e5 and for the same reason: this module
## checks its dressing against its own pad-local clearance volumes and against
## nothing else. What is measured here is the live world — every piece this
## module draws, shape-queried against every other module's real World-layer
## collision, with its own bodies excluded.
func _test_service_dressing_stands_in_no_other_module(world: ShipyardWorld) -> void:
	var berths := world.get_node_or_null(
		^"FleetExpansionProductionBinding/FleetExpansionBerths"
	) as Node3D
	_check(berths != null, "the production world exposes the expansion berths to sweep")
	if berths == null:
		return
	var space := world.get_world_3d().direct_space_state
	var own_bodies: Array[RID] = []
	for raw_body in berths.find_children("*", "StaticBody3D", true, false):
		own_bodies.append((raw_body as StaticBody3D).get_rid())
	var intrusions := PackedStringArray()
	for pad_id: StringName in [&"dock_04_cargo", &"dock_05_bomber", &"dock_06_interceptor"]:
		var service := berths.get_node_or_null(
			NodePath("%s/ServicePresentation" % pad_id)
		) as Node3D
		if service == null:
			continue
		for raw in service.find_children("*", "GeometryInstance3D", true, false):
			for entry: Dictionary in _drawn_boxes(raw as GeometryInstance3D):
				var query := PhysicsShapeQueryParameters3D.new()
				var box := BoxShape3D.new()
				# Shrunk by a millimetre so a piece that merely touches a deck it
				# is bolted to is not reported as standing inside it.
				box.size = (entry["size"] as Vector3) - Vector3.ONE * 0.002
				query.shape = box
				query.transform = Transform3D(
					entry["basis"] as Basis, entry["origin"] as Vector3
				)
				query.collision_mask = PhysicsLayers.WORLD
				query.exclude = own_bodies
				for hit in space.intersect_shape(query, 8):
					var collider := hit.get("collider") as Node
					if collider == null:
						continue
					var described := "%s in %s" % [raw.name, world.get_path_to(collider)]
					if not intrusions.has(described):
						intrusions.append(described)
	_check(
		intrusions.is_empty(),
		"no Dock 04/05/06 service dressing stands inside another module's solid geometry: %s"
			% ", ".join(intrusions)
	)


## Every world-space box a service renderer actually draws, decoding `MultiMesh`
## copies from the authored roster the module retains for exactly this reason.
func _drawn_boxes(instance: GeometryInstance3D) -> Array[Dictionary]:
	var boxes: Array[Dictionary] = []
	if instance is MeshInstance3D:
		var mesh_instance := instance as MeshInstance3D
		var box := mesh_instance.mesh as BoxMesh
		if box == null:
			return boxes
		boxes.append({
			"basis": mesh_instance.global_transform.basis,
			"origin": mesh_instance.global_position,
			"size": box.size,
		})
		return boxes
	var batch := instance as MultiMeshInstance3D
	if batch == null or batch.multimesh == null:
		return boxes
	var batch_box := batch.multimesh.mesh as BoxMesh
	if batch_box == null:
		return boxes
	for authored: Variant in (batch.get_meta(&"authored_instance_transforms", []) as Array):
		var placed := batch.global_transform * (authored as Transform3D)
		# The apron and lane kits draw one shared unit box at a per-instance
		# scale, so the drawn size lives in the basis. Decompose it rather than
		# handing a scaled basis to the query, which would scale the millimetre
		# tolerance below with it and quietly blunt this sweep on long pieces.
		boxes.append({
			"basis": placed.basis.orthonormalized(),
			"origin": placed.origin,
			"size": batch_box.size * placed.basis.get_scale(),
		})
	return boxes
