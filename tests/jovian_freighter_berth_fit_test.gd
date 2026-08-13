extends SceneTree

## Cross-component fit test: the actual provisional Jovian presentation and
## collision must remain inside the freight module's published ship envelope,
## align its landing contact to the apron, and put the deployed port ramp beside
## the cargo-transfer/service staging lane.

const MODULE_SCENE := preload("res://scenes/world/modules/jovian_freight_berth.tscn")
const JOVIAN_SCENE := preload("res://scenes/ships/jovian_light_freighter.tscn")
const WORLD_LAYER := PhysicsLayers.WORLD
const RAMP_COLLISION_NAME := &"PortCargoRampCollision"
const CARGO_DECK_COLLISION_NAME := &"CargoDeckCollision"
const SURFACE_SEAM_TOLERANCE := 0.035

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var stage := Node3D.new()
	stage.name = "JovianFreighterBerthFitStage"
	root.add_child(stage)
	var module := MODULE_SCENE.instantiate() as JovianFreightBerth
	stage.add_child(module)
	var ship := JOVIAN_SCENE.instantiate() as JovianLightFreighter
	stage.add_child(ship)
	await process_frame
	await physics_frame
	await physics_frame
	ship.global_transform = module.get_berth_transform()
	await physics_frame

	_check(ship.global_transform.is_equal_approx(module.get_berth_transform()), "actual Jovian root aligns to the exact dock marker")
	var envelope := module.get_ship_clearance_envelope()
	var envelope_transform := envelope.world_transform as Transform3D
	var envelope_half := envelope.half_extents as Vector3
	var all_render_inside := true
	var render_count := 0
	var render_offenders := PackedStringArray()
	var render_min := Vector3(INF, INF, INF)
	var render_max := Vector3(-INF, -INF, -INF)
	for candidate in ship.find_children("*", "MeshInstance3D", true, false):
		var visual := candidate as MeshInstance3D
		if not visual.visible or visual.mesh == null:
			continue
		render_count += 1
		var local_aabb := visual.get_aabb()
		for corner in _aabb_corners(local_aabb):
			var world_corner := visual.global_transform * corner
			var envelope_point := envelope_transform.affine_inverse() * world_corner
			render_min = Vector3(minf(render_min.x, envelope_point.x), minf(render_min.y, envelope_point.y), minf(render_min.z, envelope_point.z))
			render_max = Vector3(maxf(render_max.x, envelope_point.x), maxf(render_max.y, envelope_point.y), maxf(render_max.z, envelope_point.z))
			if absf(envelope_point.x) > envelope_half.x + 0.03 \
				or absf(envelope_point.y) > envelope_half.y + 0.03 \
				or absf(envelope_point.z) > envelope_half.z + 0.03:
				all_render_inside = false
				if not render_offenders.has(str(visual.get_path())):
					render_offenders.append(str(visual.get_path()))
	print("JOVIAN_RENDER_ENVELOPE_BOUNDS: min=", render_min, " max=", render_max, " offenders=", render_offenders)
	_check(render_count >= 80, "fit audit samples the complete high-detail Jovian presentation")
	_check(all_render_inside, "every actual Jovian render bound fits the protected berth envelope")

	var all_collision_inside := true
	var collision_count := 0
	var collision_offenders := PackedStringArray()
	var collision_min := Vector3(INF, INF, INF)
	var collision_max := Vector3(-INF, -INF, -INF)
	for candidate in ship.find_children("*", "CollisionShape3D", true, false):
		var collision := candidate as CollisionShape3D
		if collision.disabled or collision.shape == null or collision.get_parent() is Area3D:
			continue
		collision_count += 1
		var debug_mesh := collision.shape.get_debug_mesh()
		if debug_mesh == null:
			continue
		for surface_index in debug_mesh.get_surface_count():
			var arrays := debug_mesh.surface_get_arrays(surface_index)
			var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
			for vertex in vertices:
				var world_vertex := collision.global_transform * vertex
				var envelope_point := envelope_transform.affine_inverse() * world_vertex
				collision_min = Vector3(minf(collision_min.x, envelope_point.x), minf(collision_min.y, envelope_point.y), minf(collision_min.z, envelope_point.z))
				collision_max = Vector3(maxf(collision_max.x, envelope_point.x), maxf(collision_max.y, envelope_point.y), maxf(collision_max.z, envelope_point.z))
				if absf(envelope_point.x) > envelope_half.x + 0.03 \
					or absf(envelope_point.y) > envelope_half.y + 0.03 \
					or absf(envelope_point.z) > envelope_half.z + 0.03:
					all_collision_inside = false
					if not collision_offenders.has(str(collision.get_path())):
						collision_offenders.append(str(collision.get_path()))
	print("JOVIAN_COLLISION_ENVELOPE_BOUNDS: min=", collision_min, " max=", collision_max, " offenders=", collision_offenders)
	_check(collision_count >= 3, "fit audit samples actual Jovian hull and interior collision")
	_check(all_collision_inside, "every actual Jovian collision shape fits the protected berth envelope")

	var landing_contact := ship.to_global(Vector3(0.0, -1.25, 0.0))
	_check(absf(module.to_local(landing_contact).y) <= 0.025, "actual Jovian landing contact rests on the apron surface")
	var ramp_collision := ship.find_child(String(RAMP_COLLISION_NAME), true, false) as CollisionShape3D
	var cargo_deck_collision := ship.find_child(String(CARGO_DECK_COLLISION_NAME), true, false) as CollisionShape3D
	_check(
		ramp_collision != null and ramp_collision.shape is ConvexPolygonShape3D,
		"deployed port ramp exposes its true convex wedge collider"
	)
	_check(cargo_deck_collision != null and cargo_deck_collision.shape is BoxShape3D, "cargo deck exposes the physical threshold used by the ramp")
	if ramp_collision != null and ramp_collision.shape is ConvexPolygonShape3D \
		and cargo_deck_collision != null and cargo_deck_collision.shape is BoxShape3D:
		var ramp_shape := ramp_collision.shape as ConvexPolygonShape3D
		var ramp_points_ship := PackedVector3Array()
		var outer_x := INF
		var inner_x := -INF
		var lowest_y := INF
		for point in ramp_shape.points:
			var ship_point := ship.to_local(ramp_collision.to_global(point))
			ramp_points_ship.append(ship_point)
			outer_x = minf(outer_x, ship_point.x)
			inner_x = maxf(inner_x, ship_point.x)
			lowest_y = minf(lowest_y, ship_point.y)
		var apron_endpoint_ship := _average_top_at_x(ramp_points_ship, outer_x)
		var cargo_endpoint_ship := _average_top_at_x(ramp_points_ship, inner_x)
		var apron_endpoint := ship.to_global(apron_endpoint_ship)
		var cargo_endpoint := ship.to_global(cargo_endpoint_ship)
		var cargo_shape := cargo_deck_collision.shape as BoxShape3D
		var cargo_top := cargo_deck_collision.to_global(Vector3(0.0, cargo_shape.size.y * 0.5, 0.0))
		var apron_step := absf(apron_endpoint.y - landing_contact.y)
		var cargo_step := absf(cargo_endpoint.y - cargo_top.y)
		print(
			"JOVIAN_RAMP_TOP_SEAMS: apron_step=", apron_step,
			" cargo_step=", cargo_step,
			" apron_top=", ship.to_local(apron_endpoint),
			" cargo_top=", ship.to_local(cargo_endpoint)
		)
		_check(apron_step <= SURFACE_SEAM_TOLERANCE, "ramp upper face meets the apron without a player-blocking vertical step")
		_check(cargo_step <= SURFACE_SEAM_TOLERANCE, "ramp upper face meets the cargo deck without a player-blocking vertical step")
		_check(lowest_y >= -1.25 - SURFACE_SEAM_TOLERANCE, "convex ramp wedge has no collider below the declared landing contact")
		_check(
			apron_endpoint_ship.x < cargo_endpoint_ship.x and apron_endpoint_ship.y < cargo_endpoint_ship.y,
			"ramp upper face rises continuously from the port apron into the cargo bay"
		)
	var clearance_report := ship.get_berth_clearance_report()
	_check(
		bool(clearance_report.get("deployed_ramp_may_overlap_apron", false)),
		"ship clearance contract explicitly permits only the deployed ramp's apron contact"
	)
	var ramp_exit := ship.get_interior_exit_transform().origin
	var transfer_marker := module.get_route_transform(&"cargo-transfer").origin
	_check(ramp_exit.distance_to(transfer_marker) <= 7.0, "actual deployed ramp exits beside the freight transfer staging lane")
	_check(module.to_local(ramp_exit).x > 9.5, "yaw-180 docking turns the ship's port ramp toward module service infrastructure")

	# With the parked ship included, structural World collision must still not
	# intersect any direct ship collision shape.
	var module_rids: Array[RID] = []
	var module_rid_names: Dictionary = {}
	for body in module.find_children("*", "StaticBody3D", true, false):
		var module_body := body as StaticBody3D
		module_rids.append(module_body.get_rid())
		module_rid_names[module_body.get_rid()] = str(module_body.get_path())
	var structure_penetration := false
	var structure_hits := PackedStringArray()
	var ramp_support_hits := PackedStringArray()
	var ramp_unexpected_hits := PackedStringArray()
	for candidate in ship.find_children("*", "CollisionShape3D", true, false):
		var collision := candidate as CollisionShape3D
		if collision.disabled or collision.shape == null or collision.get_parent() is Area3D:
			continue
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = collision.shape
		query.transform = collision.global_transform
		query.margin = 0.002
		query.collision_mask = WORLD_LAYER
		query.collide_with_areas = false
		query.collide_with_bodies = true
		var hits := ship.get_world_3d().direct_space_state.intersect_shape(query, 64)
		for hit in hits:
			var collider := hit.get("collider") as CollisionObject3D
			if collider != null and module_rids.has(collider.get_rid()):
				if collision.name == RAMP_COLLISION_NAME:
					var support_name := String(collider.name)
					if support_name.begins_with("ApronDeck"):
						if not ramp_support_hits.has(support_name):
							ramp_support_hits.append(support_name)
					elif not ramp_unexpected_hits.has(support_name):
						ramp_unexpected_hits.append(support_name)
					continue
				structure_penetration = true
				var pair_name := "%s -> %s" % [collision.get_path(), module_rid_names.get(collider.get_rid(), collider.get_path())]
				if not structure_hits.has(pair_name):
					structure_hits.append(pair_name)
	print("JOVIAN_MODULE_COLLISION_HITS: ", structure_hits)
	print("JOVIAN_RAMP_SUPPORT_HITS: expected=", ramp_support_hits, " unexpected=", ramp_unexpected_hits)
	_check(not structure_penetration, "actual parked Jovian hull collision does not penetrate freight-module structure")
	_check(not ramp_support_hits.is_empty(), "deployed wedge has deliberate contact with a load-bearing apron leaf")
	_check(ramp_unexpected_hits.is_empty(), "deployed wedge touches no module structure beyond its apron support")

	ship.queue_free()
	module.queue_free()
	stage.queue_free()
	await process_frame
	await process_frame
	if _failures.is_empty():
		print("JOVIAN_FREIGHTER_BERTH_FIT_TEST_OK")
		quit(0)
	else:
		print("JOVIAN_FREIGHTER_BERTH_FIT_TEST_FAILED: ", "; ".join(_failures))
		quit(1)


func _aabb_corners(aabb: AABB) -> PackedVector3Array:
	return PackedVector3Array([
		aabb.position,
		aabb.position + Vector3(aabb.size.x, 0, 0),
		aabb.position + Vector3(0, aabb.size.y, 0),
		aabb.position + Vector3(0, 0, aabb.size.z),
		aabb.position + Vector3(aabb.size.x, aabb.size.y, 0),
		aabb.position + Vector3(aabb.size.x, 0, aabb.size.z),
		aabb.position + Vector3(0, aabb.size.y, aabb.size.z),
		aabb.end,
	])


func _average_top_at_x(points: PackedVector3Array, target_x: float) -> Vector3:
	var top_y := -INF
	for point in points:
		if is_equal_approx(point.x, target_x):
			top_y = maxf(top_y, point.y)
	var result := Vector3.ZERO
	var count := 0
	for point in points:
		if is_equal_approx(point.x, target_x) and is_equal_approx(point.y, top_y):
			result += point
			count += 1
	return result / float(maxi(count, 1))


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)
