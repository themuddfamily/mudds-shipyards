extends SceneTree

## Current-world placement audit for the freight module. The selected transform
## extends the port fleet-registry node toward +Z while routing around its back
## wall; only the deliberately shared connection-floor seam may overlap legacy
## collision. The entire berth, landing volume, and protected hull volume remain
## isolated from the two existing live berths and authored station modules.

const WORLD_SCENE := preload("res://scenes/world/shipyard_world.tscn")
const MODULE_SCENE := preload("res://scenes/world/modules/jovian_freight_berth.tscn")
const JOVIAN_SCENE := preload("res://scenes/ships/jovian_light_freighter.tscn")
const RECOMMENDED_TRANSFORM := Transform3D(Basis.IDENTITY, Vector3(-53.0, 0.38, 28.8))
const WORLD_LAYER := PhysicsLayers.WORLD

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := WORLD_SCENE.instantiate() as ShipyardWorld
	root.add_child(world)
	await process_frame
	await physics_frame
	await physics_frame
	var module := _find_integrated_module(world)
	var module_was_integrated := module != null
	var original_bodies: Array[StaticBody3D] = []
	for candidate in world.find_children("*", "StaticBody3D", true, false):
		if module == null or not module.is_ancestor_of(candidate):
			original_bodies.append(candidate as StaticBody3D)
	if module == null:
		module = MODULE_SCENE.instantiate() as JovianFreightBerth
		module.name = "CandidateJovianFreightBerth"
		module.transform = RECOMMENDED_TRANSFORM
		world.add_child(module)
		await process_frame
		await physics_frame
		await physics_frame

	_check(module.global_transform.is_equal_approx(RECOMMENDED_TRANSFORM), "recommended transform is stable under ShipyardWorld")
	_check(not module_was_integrated or module.get_parent() == world, "production module remains a direct ShipyardWorld child")
	_test_module_and_berth_footprints(world, module)
	await _test_protected_ship_volume(world, module, original_bodies)
	await _test_connection_overlap_is_bounded(world, module, original_bodies)
	await _test_walkable_handoff(world, module)
	await _test_approach_board_direction_truth(world, module)

	if not module_was_integrated:
		module.queue_free()
	world.queue_free()
	await process_frame
	await process_frame
	if _failures.is_empty():
		print("JOVIAN_FREIGHT_BERTH_TRANSFORM_TEST_OK")
		quit(0)
	else:
		print("JOVIAN_FREIGHT_BERTH_TRANSFORM_TEST_FAILED: ", "; ".join(_failures))
		quit(1)


func _find_integrated_module(world: ShipyardWorld) -> JovianFreightBerth:
	for candidate in world.find_children("*", "JovianFreightBerth", true, false):
		if candidate is JovianFreightBerth:
			return candidate as JovianFreightBerth
	return null


func _test_module_and_berth_footprints(world: ShipyardWorld, module: JovianFreightBerth) -> void:
	var module_footprint := module.get_integration_footprint()
	var module_aabb := _transformed_local_aabb(module.global_transform, module_footprint.local_min, module_footprint.local_max)
	_check(module_aabb.position.is_equal_approx(Vector3(-76.0, -3.02, 24.0)), "recommended footprint minimum is exact")
	_check(module_aabb.end.is_equal_approx(Vector3(-30.0, 14.58, 80.3)), "recommended footprint maximum is exact")

	var aft := world.get_node_or_null("AftJunctionStack") as AftJunctionStack
	var aft_spec := aft.get_integration_footprint()
	var aft_aabb := _transformed_local_aabb(aft.global_transform, aft_spec.local_min, aft_spec.local_max)
	_check(not _aabbs_overlap(module_aabb, aft_aabb, 0.01), "freight footprint is isolated from Aft Junction")
	var habitat := world.get_node_or_null("HabitatSpine") as HabitatSpine
	var habitat_spec := habitat.get_integration_footprint()
	var habitat_aabb := _transformed_local_aabb(habitat.global_transform, habitat_spec.local_min, habitat_spec.local_max)
	_check(not _aabbs_overlap(module_aabb, habitat_aabb, 0.01), "freight footprint is isolated from Habitat Spine")

	var spec := module.get_berth_specification()
	var new_half := spec.landing_half_extents as Vector3
	var new_aabb := _transformed_local_aabb(spec.dock_transform, -new_half, new_half)
	var all_live_berths_clear := true
	for berth_id in world.get_berth_ids():
		if berth_id == module.get_berth_id():
			continue
		var berth := world.get_berth_node(berth_id)
		if berth == null:
			all_live_berths_clear = false
			continue
		var existing_half := berth.get_landing_half_extents()
		var existing_aabb := _transformed_local_aabb(berth.get_dock_transform(), -existing_half, existing_half)
		all_live_berths_clear = all_live_berths_clear and not _aabbs_overlap(new_aabb, existing_aabb, 0.2)
	_check(all_live_berths_clear, "Jovian landing volume does not touch either existing live berth")
	_check(new_aabb.position.z >= 35.79, "freight landing volume begins well beyond the Arrow landing volume")
	_check(new_aabb.position.x <= -66.9 and new_aabb.end.x >= -39.1, "freight landing volume has the declared medium-craft width")


func _test_protected_ship_volume(world: ShipyardWorld, module: JovianFreightBerth, original_bodies: Array[StaticBody3D]) -> void:
	var envelope := module.get_ship_clearance_envelope()
	var shape := BoxShape3D.new()
	shape.size = (envelope.half_extents as Vector3) * 2.0
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = envelope.world_transform
	query.collision_mask = WORLD_LAYER
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var module_rids: Array[RID] = []
	for body in module.find_children("*", "StaticBody3D", true, false):
		module_rids.append((body as StaticBody3D).get_rid())
	query.exclude = module_rids
	await physics_frame
	var hits := world.get_world_3d().direct_space_state.intersect_shape(query, 128)
	var existing_hits: Array[Node] = []
	for hit in hits:
		var collider := hit.get("collider") as Node
		if collider != null and original_bodies.has(collider as StaticBody3D):
			existing_hits.append(collider)
	_check(existing_hits.is_empty(), "protected full-hull volume is clear of every existing world collider")


func _test_connection_overlap_is_bounded(world: ShipyardWorld, module: JovianFreightBerth, original_bodies: Array[StaticBody3D]) -> void:
	var module_bodies: Array[StaticBody3D] = []
	var module_rids: Array[RID] = []
	for candidate in module.find_children("*", "StaticBody3D", true, false):
		var body := candidate as StaticBody3D
		module_bodies.append(body)
		module_rids.append(body.get_rid())
	var overlap_names := PackedStringArray()
	for body in module_bodies:
		for candidate in body.find_children("*", "CollisionShape3D", true, false):
			var collision := candidate as CollisionShape3D
			if collision.disabled or collision.shape == null:
				continue
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = collision.shape
			query.transform = collision.global_transform
			query.margin = 0.002
			query.collision_mask = WORLD_LAYER
			query.collide_with_areas = false
			query.collide_with_bodies = true
			query.exclude = module_rids
			var hits := world.get_world_3d().direct_space_state.intersect_shape(query, 128)
			for hit in hits:
				var collider := hit.get("collider") as StaticBody3D
				if collider == null or not original_bodies.has(collider):
					continue
				var pair_name := "%s -> %s" % [body.name, collider.name]
				if not overlap_names.has(pair_name):
					overlap_names.append(pair_name)
	overlap_names.sort()
	print("FREIGHT_CONNECTION_OVERLAPS: ", overlap_names)
	# Deck A butts both neighbouring decks at their edges. The query reports both
	# contacts because its 0.002 m margin inflates the touching shapes, but all
	# connections are required to have zero shared volume.
	var expected_overlaps := PackedStringArray([
		"ConnectionDeckA -> PortBerthNode",
		"ConnectionDeckA -> RegistryPodDeck",
	])
	_check(
		overlap_names == expected_overlaps,
		"the freight module only touches its declared edge seams"
	)
	_check(
		_shared_volume(module, "ConnectionLattice/ConnectionDeckA", world, "ExposedDockLattice/PortBerthNode") <= 0.0,
		"the widened port berth node butts the freight connection lattice instead of interpenetrating it"
	)
	_check(
		_shared_volume(module, "ConnectionLattice/ConnectionDeckA", world, "ModernFleetRegistry/RegistryPodDeck") <= 0.0,
		"the freight connection deck meets the registry shelf without overlapping it"
	)


## Shared collision volume in cubic metres between two named box-collider bodies.
## Zero means they touch or are apart; positive means they interpenetrate.
func _shared_volume(
		first_owner: Node3D,
		first_path: String,
		second_owner: Node3D,
		second_path: String
	) -> float:
	var first := _body_collision_box(first_owner.get_node_or_null(NodePath(first_path)) as Node3D)
	var second := _body_collision_box(second_owner.get_node_or_null(NodePath(second_path)) as Node3D)
	if first.size == Vector3.ZERO or second.size == Vector3.ZERO:
		return -1.0
	var overlap := Vector3(
		minf(first.end.x, second.end.x) - maxf(first.position.x, second.position.x),
		minf(first.end.y, second.end.y) - maxf(first.position.y, second.position.y),
		minf(first.end.z, second.end.z) - maxf(first.position.z, second.position.z)
	)
	if overlap.x <= 0.0 or overlap.y <= 0.0 or overlap.z <= 0.0:
		return 0.0
	return overlap.x * overlap.y * overlap.z


func _body_collision_box(body: Node3D) -> AABB:
	if body == null:
		return AABB()
	var box := AABB()
	var first := true
	for candidate in body.find_children("*", "CollisionShape3D", true, false):
		var collision := candidate as CollisionShape3D
		if collision.disabled or collision.shape is not BoxShape3D:
			continue
		var half := (collision.shape as BoxShape3D).size * 0.5
		var world_box := (collision.global_transform * AABB(-half, half * 2.0)).abs()
		if first:
			box = world_box
			first = false
		else:
			box = box.merge(world_box)
	return box


func _test_walkable_handoff(world: ShipyardWorld, module: JovianFreightBerth) -> void:
	# Samples follow the usable path around the registry back wall: existing port
	# deck -> elevated gallery shelf -> west bypass -> module approach centreline.
	var samples := PackedVector3Array([
		Vector3(-48.0, 1.8, 22.0),
		Vector3(-48.0, 1.8, 24.0),
		Vector3(-49.0, 1.8, 26.0),
		Vector3(-51.5, 1.8, 26.0),
		Vector3(-53.0, 1.8, 27.5),
		Vector3(-53.0, 1.8, 30.5),
		Vector3(-53.0, 1.8, 33.5),
		Vector3(-53.0, 1.8, 37.0),
		Vector3(-53.0, 1.8, 40.0),
	])
	var every_supported := true
	var maximum_step := 0.0
	var previous_y := NAN
	for sample in samples:
		var query := PhysicsRayQueryParameters3D.create(sample, sample + Vector3.DOWN * 3.0, WORLD_LAYER)
		query.collide_with_areas = false
		query.collide_with_bodies = true
		await physics_frame
		var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			every_supported = false
			continue
		var y := float(hit.position.y)
		if is_finite(previous_y):
			maximum_step = maxf(maximum_step, absf(y - previous_y))
		previous_y = y
	_check(every_supported, "port deck, registry bypass, and freight approach have continuous physical support")
	_check(maximum_step <= 0.41, "connection route contains no step higher than the existing registry shelf")


## Resolve the actual ship-owned access points only after applying the live
## 180-degree dock transform. The approach-facing board derives its right vector
## from its own pose, so a future ship, berth, or board transform change cannot
## silently turn the printed arrow into a false instruction.
func _test_approach_board_direction_truth(
		world: ShipyardWorld,
		module: JovianFreightBerth
	) -> void:
	var board: Label3D
	for candidate in module.find_children("FreightSign*", "Label3D", true, false):
		var label := candidate as Label3D
		if label.text == JovianFreightBerth.APPROACH_LEGEND:
			board = label
			break
	var ship := JOVIAN_SCENE.instantiate() as JovianLightFreighter
	world.add_child(ship)
	await process_frame
	ship.global_transform = module.get_berth_transform()
	await physics_frame

	var boarding_area := ship.get_node_or_null(^"ShipBoardingArea") as ShipBoardingArea
	var terminal := module.get_service_access()
	var finite_geometry := board != null and boarding_area != null and terminal != null
	_check(finite_geometry, "real docked access geometry and the approach board all resolve")
	if finite_geometry:
		var boarding_local := module.to_local(boarding_area.global_position)
		var pilot_exit_local := module.to_local(ship.get_exit_transform().origin)
		var cargo_exit_local := module.to_local(ship.get_interior_exit_transform().origin)
		var terminal_local := module.to_local(terminal.global_position)
		var approach_forward := -board.global_basis.z.normalized()
		var approach_right := board.global_basis.y.normalized().cross(approach_forward).normalized()
		var right_offsets := PackedFloat32Array([
			(boarding_area.global_position - board.global_position).dot(approach_right),
			(ship.get_exit_transform().origin - board.global_position).dot(approach_right),
			(ship.get_interior_exit_transform().origin - board.global_position).dot(approach_right),
			(terminal.global_position - board.global_position).dot(approach_right),
		])
		_check(
			is_equal_approx(boarding_local.x, 3.4)
			and is_equal_approx(pilot_exit_local.x, 4.7)
			and cargo_exit_local.x > 9.5
			and is_equal_approx(terminal_local.x, 15.75),
			"the 180-degree dock yaw resolves boarding, pilot exit, cargo-ramp exit and Freight Control to their real module-right positions"
		)
		_check(
			right_offsets[0] > 0.0
			and right_offsets[1] > right_offsets[0]
			and right_offsets[2] > right_offsets[1]
			and right_offsets[3] > right_offsets[2],
			"boarding, both exits and Freight Control are successively farther approach-right, matching the board arrow"
		)

	ship.queue_free()
	await process_frame


func _transformed_local_aabb(transform_value: Transform3D, local_min: Vector3, local_max: Vector3) -> AABB:
	var first := true
	var result := AABB()
	for x in [local_min.x, local_max.x]:
		for y in [local_min.y, local_max.y]:
			for z in [local_min.z, local_max.z]:
				var point := transform_value * Vector3(x, y, z)
				if first:
					result = AABB(point, Vector3.ZERO)
					first = false
				else:
					result = result.expand(point)
	return result


func _aabbs_overlap(a: AABB, b: AABB, tolerance: float) -> bool:
	return a.position.x < b.end.x - tolerance and a.end.x > b.position.x + tolerance \
		and a.position.y < b.end.y - tolerance and a.end.y > b.position.y + tolerance \
		and a.position.z < b.end.z - tolerance and a.end.z > b.position.z + tolerance


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)
