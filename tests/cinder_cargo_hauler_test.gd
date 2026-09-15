extends SceneTree

const Hauler := preload("res://scripts/ships/cinder_cargo_hauler.gd")
const WORLD_SCENE := preload("res://scenes/world/shipyard_world.tscn")
## Sample pitch of the published-lane sweep below, in metres. The hauler's
## thinnest root shape is 0.3 m, so a quarter-metre pitch cannot step over a
## mullion, a header or a comb tooth standing in the lane.
const LANE_SAMPLE_STEP_M := 0.25
const SEAT_BACK_GEOMETRY_SHA256 := "e3c8e385f42692452bca7da77e79ac15862df6335ada6ae682b6ee7c872917e3"
const CABIN_END_WALL_GEOMETRY_SHA256 := "6b79a88d618da841735a40414bbe9016d4dcb9d9f475680400206b9e14e3104f"
const CREW_CONSOLE_GEOMETRY_SHA256 := "9812fe3ed5aa023ab3587d83443f05d1113d9f990c2ddcf9da23164dfd5b8ab2"

var _assertions := 0
var _failures: Array[String] = []


func _initialize() -> void:
	var craft := Hauler.new()
	root.add_child(craft)
	await process_frame
	_test_recessed_exhaust(craft)
	_test_cockpit_fairing(craft)
	_test_fitted_canopy(craft)
	_test_formed_cockpit_walls(craft)
	_test_pressure_endcaps(craft)
	var endcap_stock: Mesh = craft.get_node("CinderCargoVisual/ForwardPressureCap").mesh
	var fairing_stock: Mesh = craft.get_node("CinderCargoVisual/CockpitPressureTransition").mesh
	var original_renderer_count := _visual_renderer_count(craft)
	var original_copy_count := _authored_visual_copy_count(craft)
	var audit := craft.get_audit_report()
	var definition := craft.get_ship_definition()
	_check(bool(audit.get("valid", false)), "the original-modern hauler builds a valid collision and anchor contract")
	_check(
		definition != null
		and definition.is_definition_valid()
		and definition.get_ship_id() == &"cinder_cargo_hauler"
		and is_equal_approx(craft.maximum_speed, definition.maximum_speed)
		and is_equal_approx(craft.engine_start_time, definition.engine_start_time)
		and is_equal_approx(craft.maximum_hull, definition.maximum_hull),
		"the live hauler consumes its authored 64 m/s, 3.8 s startup, and 220-hull profile"
	)
	_check(audit.get("evidence_status", &"") == &"NEW" and not bool(audit.get("historically_supported", true)), "the hauler makes no historical claim")
	_check(craft.get_cockpit_seat_anchor() != null and craft.get_boarding_marker() != null, "the craft exposes physical cockpit and boarding anchors")
	_check(craft.get_cargo_transfer_anchors().size() == 8 and craft.get_cargo_capacity() == 8, "the cargo hold exposes eight stable transfer anchors")
	_check(bool(craft is HeroShip) and bool(audit.get("flight_authority", false)) and not bool(audit.get("cargo_transfer_authority", true)), "HeroShip owns flight while the component adds no duplicate cargo authority")
	var threshold_posts := craft.get_node_or_null(^"CinderCargoVisual/CargoThresholdPostBatch") as MultiMeshInstance3D
	var expected_post_transforms: Array[Transform3D] = [
		Transform3D(Basis.IDENTITY, Vector3(-3.41, 0.15, -2.28)),
		Transform3D(Basis.IDENTITY, Vector3(-3.41, 0.15, 2.28)),
	]
	var authored_post_names := PackedStringArray()
	var authored_post_transforms: Array = []
	var post_material: StandardMaterial3D
	if threshold_posts != null:
		authored_post_names = threshold_posts.get_meta(&"authored_visual_names", PackedStringArray()) as PackedStringArray
		authored_post_transforms = threshold_posts.get_meta(&"authored_instance_transforms", []) as Array
		post_material = threshold_posts.material_override as StandardMaterial3D
	_check(
		threshold_posts != null
			and threshold_posts.multimesh.instance_count == 2
			and threshold_posts.multimesh.visible_instance_count == -1
			and threshold_posts.multimesh.mesh is BoxMesh
			and (threshold_posts.multimesh.mesh as BoxMesh).size == Vector3(0.09, 1.83, 0.08)
			and authored_post_names == PackedStringArray(["CargoThresholdPostPort", "CargoThresholdPostStarboard"])
			and authored_post_transforms == expected_post_transforms
			and threshold_posts.get_meta(&"route_id", &"") == Hauler.CABIN_ROUTE_ID
			and bool(threshold_posts.get_meta(&"presentation_only", false))
			and threshold_posts.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			and threshold_posts.layers == 1
			and is_zero_approx(threshold_posts.extra_cull_margin)
			and is_zero_approx(threshold_posts.visibility_range_begin)
			and is_zero_approx(threshold_posts.visibility_range_end)
			and post_material != null
			and post_material.albedo_color == Color("89938f")
			and is_equal_approx(post_material.metallic, 0.55)
			and is_equal_approx(post_material.roughness, 0.38),
		"two authored threshold-post copies retain exact visual, transform, route, shadow, and semantic identity"
	)
	_check(
		threshold_posts != null
			and threshold_posts.multimesh.mesh.get_surface_count() == 1
			and craft.get_node_or_null(^"CinderCargoVisual/CargoThresholdPostPort") == null
			and craft.get_node_or_null(^"CinderCargoVisual/CargoThresholdPostStarboard") == null,
		"threshold posts reduce renderer submissions from two to one without dropping a visible copy"
	)
	var cabin := craft.get_node_or_null(^"WalkableInterior/LoadmasterCabin")
	var cabin_end_walls := cabin.get_node_or_null(^"CabinEndWallBatch") as MultiMeshInstance3D \
		if cabin != null else null
	var expected_end_wall_transforms: Array[Transform3D] = [
		Transform3D(Basis.IDENTITY, Vector3(0.0, 0.18, -2.55)),
		Transform3D(Basis.IDENTITY, Vector3(0.0, 0.18, 2.55)),
	]
	var end_wall_material := cabin_end_walls.material_override as StandardMaterial3D \
		if cabin_end_walls != null else null
	_check(
		cabin_end_walls != null
			and cabin_end_walls.multimesh.instance_count == 2
			and cabin_end_walls.multimesh.visible_instance_count == -1
			and cabin_end_walls.multimesh.mesh is BoxMesh
			and (cabin_end_walls.multimesh.mesh as BoxMesh).size == Vector3(4.7, 2.0, 0.10)
			and cabin_end_walls.get_meta(&"authored_visual_names", PackedStringArray())
				== PackedStringArray(["CabinForwardWall", "CabinAftWall"])
			and cabin_end_walls.get_meta(&"authored_instance_transforms", [])
				== expected_end_wall_transforms
			and bool(cabin_end_walls.get_meta(&"presentation_only", false))
			and cabin_end_walls.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			and cabin_end_walls.layers == 1
			and is_zero_approx(cabin_end_walls.extra_cull_margin)
			and is_zero_approx(cabin_end_walls.visibility_range_begin)
			and is_zero_approx(cabin_end_walls.visibility_range_end)
			and end_wall_material != null
			and end_wall_material.albedo_color == Hauler.HULL_COLOR
			and is_equal_approx(end_wall_material.metallic, 0.42)
			and is_equal_approx(end_wall_material.roughness, 0.62),
		"cabin end walls retain both authored copies, transforms, silhouette, shadows, and material"
	)
	_check(
		cabin_end_walls != null
			and cabin_end_walls.multimesh.mesh.get_surface_count() == 1
			and cabin.get_node_or_null(^"CabinForwardWall") == null
			and cabin.get_node_or_null(^"CabinAftWall") == null,
		"cabin end walls reduce renderer submissions from two to one without dropping a visible copy"
	)
	var seat_bases := cabin.get_node_or_null(^"CrewSeatBaseBatch") as MultiMeshInstance3D \
		if cabin != null else null
	var expected_seat_base_transforms: Array[Transform3D] = [
		Transform3D(Basis.IDENTITY, Vector3(0.95, -0.55, 1.10)),
		Transform3D(Basis.IDENTITY, Vector3(-0.95, -0.55, 1.10)),
	]
	var seat_base_material := seat_bases.material_override as StandardMaterial3D \
		if seat_bases != null else null
	_check(
		seat_bases != null
			and seat_bases.multimesh.instance_count == 2
			and seat_bases.multimesh.visible_instance_count == -1
			and seat_bases.multimesh.mesh is ArrayMesh
			and seat_bases.multimesh.mesh.get_aabb().size.is_equal_approx(Vector3(0.86, 0.18, 0.82))
			and seat_bases.get_meta(&"authored_visual_names", PackedStringArray())
				== PackedStringArray(["LoadmasterSeatBase", "NavigatorSeatBase"])
			and seat_bases.get_meta(&"authored_instance_transforms", [])
				== expected_seat_base_transforms
			and bool(seat_bases.get_meta(&"presentation_only", false))
			and seat_bases.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			and seat_bases.layers == 1
			and is_zero_approx(seat_bases.extra_cull_margin)
			and is_zero_approx(seat_bases.visibility_range_begin)
			and is_zero_approx(seat_bases.visibility_range_end)
			and seat_base_material != null
			and seat_base_material.albedo_color == Hauler.ACCENT_COLOR
			and is_equal_approx(seat_base_material.metallic, 0.42)
			and is_equal_approx(seat_base_material.roughness, 0.62)
			and cabin.get_node_or_null(^"LoadmasterSeatBase") == null
			and cabin.get_node_or_null(^"NavigatorSeatBase") == null,
		"seat bases share one bounded renderer while preserving both exact authored visuals"
	)
	var seat_backs := cabin.get_node_or_null(^"CrewSeatBackBatch") as MultiMeshInstance3D \
		if cabin != null else null
	var expected_seat_back_transforms: Array[Transform3D] = [
		Transform3D(Basis.IDENTITY, Vector3(0.95, 0.08, 1.42)),
		Transform3D(Basis.IDENTITY, Vector3(-0.95, 0.08, 1.42)),
	]
	var seat_back_material := seat_backs.material_override as StandardMaterial3D \
		if seat_backs != null else null
	_check(
		seat_backs != null
			and seat_backs.multimesh.instance_count == 2
			and seat_backs.multimesh.visible_instance_count == -1
			and seat_backs.multimesh.mesh is ArrayMesh
			and seat_backs.multimesh.mesh.get_aabb().size.is_equal_approx(Vector3(0.86, 1.0, 0.14))
			and seat_backs.get_meta(&"authored_visual_names", PackedStringArray())
				== PackedStringArray(["LoadmasterSeatBack", "NavigatorSeatBack"])
			and seat_backs.get_meta(&"authored_instance_transforms", [])
				== expected_seat_back_transforms
			and bool(seat_backs.get_meta(&"presentation_only", false))
			and seat_backs.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			and seat_back_material != null
			and seat_back_material.albedo_color == Hauler.ACCENT_COLOR
			and is_equal_approx(seat_back_material.metallic, 0.42)
			and is_equal_approx(seat_back_material.roughness, 0.62),
		"seat backs retain both exact authored copies, transforms, silhouette, shadows, and material"
	)
	var crew_consoles := cabin.get_node_or_null(^"CrewConsoleBatch") as MultiMeshInstance3D \
		if cabin != null else null
	var expected_console_transforms: Array[Transform3D] = [
		Transform3D(Basis.IDENTITY, Vector3(0.95, 0.20, 0.42)),
		Transform3D(Basis.IDENTITY, Vector3(-0.95, 0.20, 0.42)),
	]
	var console_material := crew_consoles.material_override as StandardMaterial3D \
		if crew_consoles != null else null
	_check(
		crew_consoles != null
			and crew_consoles.multimesh.instance_count == 2
			and crew_consoles.multimesh.visible_instance_count == -1
			and crew_consoles.multimesh.mesh is ArrayMesh
			and crew_consoles.multimesh.mesh.get_aabb().size.is_equal_approx(Vector3(0.92, 0.58, 0.08))
			and crew_consoles.get_meta(&"authored_visual_names", PackedStringArray())
				== PackedStringArray(["LoadmasterConsole", "NavigatorConsole"])
			and crew_consoles.get_meta(&"authored_instance_transforms", [])
				== expected_console_transforms
			and crew_consoles.get_meta(&"authored_station_ids", PackedStringArray())
				== PackedStringArray([
					Hauler.LOADMASTER_STATION_SEAT_ID,
					Hauler.NAVIGATOR_STATION_SEAT_ID,
				])
			and bool(crew_consoles.get_meta(&"presentation_only", false))
			and crew_consoles.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			and console_material != null
			and console_material.albedo_color == Hauler.ACCENT_COLOR
			and is_equal_approx(console_material.metallic, 0.42)
			and is_equal_approx(console_material.roughness, 0.62)
			and cabin.get_node_or_null(^"LoadmasterConsole") == null
			and cabin.get_node_or_null(^"NavigatorConsole") == null,
		"both station console shells retain exact geometry, transforms, paint, shadows, and station identity"
	)
	_check(
		seat_backs != null
			and seat_backs.multimesh.mesh.get_surface_count() == 1
			and cabin.get_node_or_null(^"LoadmasterSeatBack") == null
			and cabin.get_node_or_null(^"NavigatorSeatBack") == null
			and crew_consoles != null
			and crew_consoles.multimesh.mesh.get_surface_count() == 1
			and _visual_renderer_count(craft) < _authored_visual_copy_count(craft),
		"the fitted exterior and cabin retain fewer renderer submissions than authored copies"
	)
	var geometry_hash := _two_stock_geometry_hash(seat_backs)
	var end_wall_geometry_hash := _two_stock_geometry_hash(cabin_end_walls)
	var console_geometry_hash := _two_stock_geometry_hash(crew_consoles)
	print(
		"CINDER_CARGO_VISUAL_ACTUAL: renderers=%d meshes=%d materials=%d authored_copies=%d collisions=%d"
		% [
			_visual_renderer_count(craft),
			_visual_mesh_resource_count(craft),
			_visual_material_resource_count(craft),
			_authored_visual_copy_count(craft),
			craft.find_children("*", "CollisionShape3D", true, false).size(),
		]
	)
	_check(
		geometry_hash == SEAT_BACK_GEOMETRY_SHA256,
		"the canonical seat-back geometry hash remains %s" % SEAT_BACK_GEOMETRY_SHA256
	)
	_check(
		end_wall_geometry_hash == CABIN_END_WALL_GEOMETRY_SHA256,
		"the canonical cabin-end-wall geometry hash is %s" % CABIN_END_WALL_GEOMETRY_SHA256
	)
	_check(
		console_geometry_hash == CREW_CONSOLE_GEOMETRY_SHA256,
		"the canonical paired-console geometry hash is %s" % CREW_CONSOLE_GEOMETRY_SHA256
	)
	var anchor_snapshot := _anchor_snapshot(craft)
	var collision_count := craft.find_children("*", "CollisionShape3D", true, false).size()
	var authority_snapshot := _authority_snapshot(craft.get_audit_report())
	craft.apply_damage(1.0)
	await process_frame
	_check(
		float(craft.get_telemetry().get("hull", 0.0)) < float(craft.get_telemetry().get("maximum_hull", 0.0))
			and _two_stock_geometry_hash(seat_backs) == geometry_hash
			and _two_stock_geometry_hash(cabin_end_walls) == end_wall_geometry_hash
			and _two_stock_geometry_hash(crew_consoles) == console_geometry_hash
			and _anchor_snapshot(craft) == anchor_snapshot
			and craft.find_children("*", "CollisionShape3D", true, false).size() == collision_count
			and _authority_snapshot(craft.get_audit_report()) == authority_snapshot,
		"damage remains component-owned without mutating batched geometry, anchors, collision, tags, or authority"
	)
	_check_service_cassettes(craft)
	await _test_shared_damage_presentation(craft)
	craft.queue_free()
	await process_frame
	var rebuilt := Hauler.new()
	root.add_child(rebuilt)
	await process_frame
	var rebuilt_seat_backs := rebuilt.get_node_or_null(
		^"WalkableInterior/LoadmasterCabin/CrewSeatBackBatch"
	) as MultiMeshInstance3D
	_check(rebuilt.get_node("CinderCargoVisual/ForwardPressureCap").mesh == endcap_stock,
		"formed cargo endcaps reuse immutable stock after craft replacement")
	_check(rebuilt.get_node("CinderCargoVisual/CockpitPressureTransition").mesh == fairing_stock,
		"rebuilt cargo cockpit reuses its immutable formed fairing stock")
	var rebuilt_consoles := rebuilt.get_node_or_null(
		^"WalkableInterior/LoadmasterCabin/CrewConsoleBatch"
	) as MultiMeshInstance3D
	_check(
		rebuilt_seat_backs != null
			and _two_stock_geometry_hash(rebuilt_seat_backs) == geometry_hash
			and _two_stock_geometry_hash(rebuilt_consoles) == console_geometry_hash
			and _two_stock_geometry_hash(rebuilt.get_node_or_null(
				^"WalkableInterior/LoadmasterCabin/CabinEndWallBatch"
			) as MultiMeshInstance3D) == end_wall_geometry_hash
			and _anchor_snapshot(rebuilt) == anchor_snapshot
			and rebuilt.find_children("*", "CollisionShape3D", true, false).size() == collision_count
			and _authority_snapshot(rebuilt.get_audit_report()) == authority_snapshot
			and _visual_renderer_count(rebuilt) == original_renderer_count
			and _authored_visual_copy_count(rebuilt) == original_copy_count,
		"detach and rebuild retain the exact optimized presentation and gameplay contract"
	)
	print(
		"CINDER_CARGO_CABIN_SHARED_CONSOLES: console_geometry_sha256=%s"
		% console_geometry_hash
	)
	rebuilt.queue_free()
	await process_frame
	await _test_home_berth_approach_lane_is_flyable()
	if _failures.is_empty():
		print("PASS cinder_cargo_hauler_test (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


## This craft's own half of the Dock 04 defect. The long-session soak flew the
## hauler home on Dock 04's published assist-capture lane and the real landing
## assist stalled 1.56 m short, aborting `approach_obstructed` every cycle, so
## the player could never park it. The hull was not the wrong side — these eight
## shell shapes are the exterior silhouette — but the craft is the thing that has
## to fit, so its own suite measures the fit against the live production world.
##
## The whole published line is swept, not just the parked pose: the stall
## happened in final approach, metres before the dock, and a pose-only check
## would have reported the berth as fine.
func _test_home_berth_approach_lane_is_flyable() -> void:
	var world := WORLD_SCENE.instantiate() as ShipyardWorld
	root.add_child(world)
	await process_frame
	await process_frame
	# Dock 04 is a deferred berth child; production re-indexes it at the same
	# boundary that admits this craft, so the registry has to be told first.
	_check(
		world.refresh_deferred_fleet_expansion_berths(),
		"the production world re-indexes Dock 04 into its own berth registry"
	)
	var craft: CinderCargoHauler = null
	for candidate in world.find_children("*", "CinderCargoHauler", true, false):
		craft = candidate as CinderCargoHauler
	var berth := world.get_berth_node(&"dock_04_cargo") if craft != null else null
	_check(
		craft != null and berth != null
		and berth.get_occupant() == craft
		and craft.global_transform.is_equal_approx(berth.get_dock_transform()),
		"the production world parks this craft in Dock 04 at the berth's published pose"
	)
	if craft == null or berth == null:
		world.queue_free()
		await process_frame
		return

	var space := craft.get_world_3d().direct_space_state
	var dock := berth.get_dock_transform()
	var capture := berth.get_assist_capture_transform()
	var samples := maxi(
		2, int(ceil(capture.origin.distance_to(dock.origin) / LANE_SAMPLE_STEP_M))
	)
	var blockers := PackedStringArray()
	for step in range(samples + 1):
		var candidate_transform := Transform3D(
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
			query.transform = candidate_transform * collision.transform
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
	_check(
		blockers.is_empty(),
		"Dock 04's published approach lane is clear for the hauler's real shapes: %s"
			% ", ".join(blockers)
	)
	var report := craft.get_landing_collision_report()
	_check(
		bool(report.get("valid", false))
		and int(report.get("shape_count", 0)) == 8
		and berth.contains_oriented_bounds(
			dock, report.get("local_bounds", AABB()) as AABB, 0.05
		),
		"the hauler's eight-shape flight envelope still fits inside Dock 04's parked volume"
	)
	world.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _visual_nodes(craft: Node) -> Array[Node]:
	var nodes: Array[Node] = []
	for root_name in [^"CinderCargoVisual", ^"WalkableInterior"]:
		var visual_root := craft.get_node_or_null(root_name)
		if visual_root == null:
			continue
		for node in visual_root.find_children("*", "MeshInstance3D", true, false):
			nodes.append(node)
		for node in visual_root.find_children("*", "MultiMeshInstance3D", true, false):
			nodes.append(node)
	return nodes


func _visual_renderer_count(craft: Node) -> int:
	return _visual_nodes(craft).size()


func _visual_mesh_resource_count(craft: Node) -> int:
	var resource_ids: Dictionary = {}
	for node in _visual_nodes(craft):
		var mesh: Mesh = (node as MeshInstance3D).mesh if node is MeshInstance3D \
			else (node as MultiMeshInstance3D).multimesh.mesh
		resource_ids[mesh.get_instance_id()] = true
	return resource_ids.size()


func _visual_material_resource_count(craft: Node) -> int:
	var resource_ids: Dictionary = {}
	for node in _visual_nodes(craft):
		var material := (node as GeometryInstance3D).material_override
		if material != null:
			resource_ids[material.get_instance_id()] = true
	return resource_ids.size()


func _authored_visual_copy_count(craft: Node) -> int:
	var count := 0
	for node in _visual_nodes(craft):
		count += (node as MultiMeshInstance3D).multimesh.instance_count \
			if node is MultiMeshInstance3D else 1
	return count


func _two_stock_geometry_hash(batch: MultiMeshInstance3D) -> String:
	if batch == null or batch.multimesh == null or batch.multimesh.mesh == null:
		return ""
	var names := batch.get_meta(&"authored_visual_names", PackedStringArray()) as PackedStringArray
	var transforms := batch.get_meta(&"authored_instance_transforms", []) as Array
	if names.size() != 2 or transforms.size() != 2:
		return ""
	var size := batch.multimesh.mesh.get_aabb().size
	var material := batch.material_override as StandardMaterial3D
	if material == null:
		return ""
	var canonical := ""
	for index in names.size():
		var transform := transforms[index] as Transform3D
		canonical += "%s|%.6f,%.6f,%.6f|%.6f,%.6f,%.6f|%s|%.6f|%.6f\n" % [
			names[index],
			transform.origin.x, transform.origin.y, transform.origin.z,
			size.x, size.y, size.z,
			material.albedo_color.to_html(), material.metallic, material.roughness,
		]
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(canonical.to_utf8_buffer())
	return hashing.finish().hex_encode()


func _anchor_snapshot(craft: CinderCargoHauler) -> Array[Transform3D]:
	var snapshot: Array[Transform3D] = [
		craft.get_cockpit_seat_anchor().transform,
		craft.get_boarding_marker().transform,
		craft.get_loadmaster_station_anchor().transform,
		craft.get_navigator_station_anchor().transform,
	]
	for anchor in craft.get_cargo_transfer_anchors():
		snapshot.append(anchor.transform)
	return snapshot


func _authority_snapshot(audit: Dictionary) -> Dictionary:
	return {
		"component_id": audit.get("component_id"),
		"evidence_status": audit.get("evidence_status"),
		"historically_supported": audit.get("historically_supported"),
		"cargo_transfer_authority": audit.get("cargo_transfer_authority"),
		"flight_authority": audit.get("flight_authority"),
		"damage_authority": audit.get("damage_authority"),
		"reuse_authority": audit.get("reuse_authority"),
		"game_flow_authority": audit.get("game_flow_authority"),
		"network_authority": audit.get("network_authority"),
	}


func _test_fitted_canopy(craft: HeroShip) -> void:
	var hinge := craft.get_node("CinderCargoVisual/CanopyHinge") as Node3D
	var glass := hinge.get_node("CanopyGlass") as MeshInstance3D
	var arrays := glass.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var no_floor := true
	var outward_winding := true
	var edges: Dictionary = {}
	for index in range(0, vertices.size(), 3):
		var a := vertices[index]
		var b := vertices[index + 1]
		var c := vertices[index + 2]
		var clockwise := (c - a).cross(b - a).normalized()
		outward_winding = outward_winding and clockwise.dot(normals[index] + normals[index + 1] + normals[index + 2]) > 0.0
		no_floor = no_floor and clockwise.y > -0.95
		for pair in [[a, b], [b, c], [c, a]]:
			var start: Vector3 = pair[0]
			var end: Vector3 = pair[1]
			var key := [start, end] if start < end else [end, start]
			edges[key] = int(edges.get(key, 0)) + 1
	var rim_faces := PackedVector3Array()
	for stock_name in ["PortSill", "StarboardSill", "ForwardPressureWall", "RearPressureWall", "PortSidewall", "StarboardSidewall"]:
		var stock := craft.get_node("CinderCargoVisual/CockpitInterior/" + stock_name) as MeshInstance3D
		for vertex: Vector3 in stock.mesh.get_faces():
			rim_faces.append(stock.transform * vertex - hinge.position)
	var perimeter_only := true
	var seated := true
	var maximum_gap := 0.0
	for edge: Array in edges:
		if int(edges[edge]) == 1:
			for step in 5:
				var point: Vector3 = edge[0].lerp(edge[1], float(step) / 4.0)
				perimeter_only = perimeter_only and point.y <= 0.106
				var distance := INF
				for index in range(0, rim_faces.size(), 3):
					distance = minf(distance, _canopy_triangle_distance(point, rim_faces[index], rim_faces[index + 1], rim_faces[index + 2]))
				var frame_radius := 0.045
				if is_equal_approx(point.z, 0.015):
					frame_radius = 0.032
				maximum_gap = maxf(maximum_gap, distance - frame_radius)
				seated = seated and distance <= frame_radius + 0.001
		else:
			perimeter_only = perimeter_only and int(edges[edge]) == 2
	_check(no_floor and perimeter_only and outward_winding,
		"cargo glazing has outward winding and a single open lower perimeter, with no glass floor crossing the hood or opening sweep")
	_check(seated, "every emitted open glass edge seats on retained rim triangles within the frame radius (maximum uncovered gap %.5f m)" % maximum_gap)
	var front := hinge.get_node("PortCanopyNoseFrame") as MeshInstance3D
	var broad_pillar := true
	var sampled_pillar := false
	for vertex: Vector3 in front.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		var point := hinge.position + vertex
		if point.y > 2.90 and point.y < 3.45:
			sampled_pillar = true
			broad_pillar = broad_pillar and absf(point.x) > 1.025
	_check(sampled_pillar and broad_pillar and glass.mesh.get_aabb().end.y > 1.39,
		"broad windscreen keeps its physical pillars outside the forward instrument view and its crown above the pilot")
	var windscreen_point := Vector3.ZERO
	var windscreen_normal := Vector3.ZERO
	for index in range(0, vertices.size(), 3):
		if normals[index].z < -0.9:
			windscreen_point = vertices[index]
			windscreen_normal = normals[index]
			break
	var controls_inside := not windscreen_normal.is_zero_approx()
	var minimum_clearance := INF
	var cockpit := craft.get_node("CinderCargoVisual/CockpitInterior")
	for part: MeshInstance3D in cockpit.find_children("*", "MeshInstance3D", true, false):
		if not part.is_visible_in_tree():
			continue
		var to_hinge := hinge.global_transform.affine_inverse() * part.global_transform
		for vertex: Vector3 in part.mesh.get_faces():
			var point := to_hinge * vertex
			if point.y < 0.12:
				continue
			var clearance := -(point - windscreen_point).dot(windscreen_normal)
			minimum_clearance = minf(minimum_clearance, clearance)
			controls_inside = controls_inside and clearance >= 0.0
	_check(controls_inside, "all emitted upper cockpit stock remains behind the actual raked windscreen plane (minimum %.5f m)" % minimum_clearance)
	print("CINDER_CARGO_CANOPY_FIT: maximum_uncovered_rim_gap=%.5f minimum_windscreen_clearance=%.5f" % [maximum_gap, minimum_clearance])
	var glass_stock := glass.mesh
	var keeper := hinge.get_node("PortCanopyLatchHook") as MeshInstance3D
	var keeper_bounds := keeper.mesh.get_aabb()
	_check(keeper_bounds.position.x < -1.17 and keeper_bounds.end.x > -0.93
		and keeper_bounds.end.y > 0.10,
		"the moving latch keeper reaches from the lower lid rail to the retained striker contact")
	craft.set_canopy_open(true, 0.0)
	_check(hinge.rotation.x > 1.0 and glass.mesh == glass_stock and glass.is_visible_in_tree()
		and keeper.is_visible_in_tree(), "the common hinge opens the complete cargo lid and attached latch keepers")
	craft.set_canopy_open(false, 0.0)


func _canopy_triangle_distance(point: Vector3, a: Vector3, b: Vector3, c: Vector3) -> float:
	var normal := (b - a).cross(c - a)
	var closest := INF
	for edge in [[a, b], [b, c], [c, a]]:
		closest = minf(closest, point.distance_to(Geometry3D.get_closest_point_to_segment(point, edge[0], edge[1])))
	if normal.length_squared() > 0.000000001:
		var projected := point - normal * (point - a).dot(normal) / normal.length_squared()
		if (b - a).cross(projected - a).dot(normal) >= -0.00000001 \
				and (c - b).cross(projected - b).dot(normal) >= -0.00000001 \
				and (a - c).cross(projected - c).dot(normal) >= -0.00000001:
			closest = minf(closest, point.distance_to(projected))
	return closest


func _test_cockpit_fairing(craft: HeroShip) -> void:
	var skin := craft.get_node("CinderCargoVisual/CockpitPressureTransition") as MeshInstance3D
	var bounds := skin.transform * skin.mesh.get_aabb()
	_check(bounds.position.z > -2.60 and bounds.end.z < 1.74
		and is_equal_approx(bounds.end.y, 1.89) and skin.mesh.get_surface_count() == 1,
		"formed cockpit skin retains floor height and clears the forward load band and aft roof panel")
	var seated_caps := true
	var curved_shoulder := false
	for vertex: Vector3 in skin.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		var point := skin.transform * vertex
		if is_equal_approx(point.z, bounds.position.z) or is_equal_approx(point.z, bounds.end.z):
			seated_caps = seated_caps and point.y < 1.60
		if is_equal_approx(point.z, -0.55) and point.x > 1.40 and point.y > 1.68:
			curved_shoulder = true
	_check(seated_caps and curved_shoulder,
		"rolled cockpit shoulders curve outside the old wedge and both ends seat below the freight roof")


func _test_recessed_exhaust(craft: HeroShip) -> void:
	var visual: Node3D = craft.call("get_variant_visual_root")
	var port := visual.get_node("PortGuideVanes") as MultiMeshInstance3D
	var starboard := visual.get_node("StarboardGuideVanes") as MultiMeshInstance3D
	var hub := visual.get_node("PortThrustPlug") as MeshInstance3D
	var lip := visual.get_node("PortNozzleLip") as MeshInstance3D
	var annulus := visual.get_node("PortCombustorAnnulus") as MeshInstance3D
	var bell := visual.get_node("PortFreightExhaust") as MeshInstance3D
	var opposite_bell := visual.get_node("StarboardFreightExhaust") as MeshInstance3D
	_check(port.multimesh.mesh is ArrayMesh and port.multimesh.instance_count == 12
		and port.multimesh.mesh == starboard.multimesh.mesh and bell.mesh == opposite_bell.mesh,
		"formed bells and twelve curved stator vanes retain immutable mesh sharing across paired engines")
	var vane_bounds := port.transform * port.multimesh.mesh.get_aabb()
	var hub_bounds := hub.transform * hub.mesh.get_aabb()
	_check(vane_bounds.end.z < lip.position.z and hub_bounds.end.z < lip.position.z
		and vane_bounds.size.z > port.scale.z * 0.2,
		"thick stator airfoils and the turned hub remain recessed inside the open bell")
	_check(not (annulus.material_override as StandardMaterial3D).emission_enabled
		and not (hub.material_override as StandardMaterial3D).emission_enabled
		and port.get_script() == null and hub.get_script() == null,
		"unpowered machinery has a passive metallic finish and adds no engine-state controller")


func _check_service_cassettes(craft: Node3D) -> void:
	var vanes := craft.find_children("*Vanes", "MeshInstance3D", true, false)
	var stocks := {}
	var seated := vanes.size() == 8
	for blade_node: MeshInstance3D in vanes:
		var frame := blade_node.get_parent().get_node_or_null(String(blade_node.name).trim_suffix("Vanes") + "Frame") as MeshInstance3D
		seated = seated and frame != null and frame.position == blade_node.position
		if frame == null:
			continue
		seated = seated and blade_node.mesh.get_aabb().end.y < frame.mesh.get_aabb().end.y and blade_node.mesh.get_aabb().position.y > 0.0425
		stocks[blade_node.mesh] = true
		stocks[frame.mesh] = true
	_check(seated, "eight service cassettes retain seated vanes below the frame lips and above the recessed backing")
	_check(stocks.size() == 6, "three cassette sizes share six material-free frame and vane stocks across eight assemblies")
	var valid := true
	var closed := true
	for mesh: ArrayMesh in stocks:
		var arrays := mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		valid = valid and mesh.surface_get_material(0) == null and normals.size() == vertices.size() and uvs.size() == vertices.size() and tangents.size() == vertices.size() * 4
		if not valid:
			continue
		for index in vertices.size():
			var tangent := Vector3(tangents[index * 4], tangents[index * 4 + 1], tangents[index * 4 + 2])
			valid = valid and tangent.is_finite() and absf(tangent.length() - 1.0) < 0.001 and absf(normals[index].dot(tangent)) < 0.001
		var edges := {}
		for triangle in range(0, indices.size(), 3):
			var a := indices[triangle]
			var b := indices[triangle + 1]
			var c := indices[triangle + 2]
			valid = valid and (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a]).length_squared() > 1e-14 and absf((uvs[b] - uvs[a]).cross(uvs[c] - uvs[a])) > 1e-10
			for pair in [[a,b],[b,c],[c,a]]:
				var keys := [str(vertices[pair[0]].snapped(Vector3.ONE * 0.00001)), str(vertices[pair[1]].snapped(Vector3.ONE * 0.00001))]
				keys.sort()
				var key: String = keys[0] + ":" + keys[1]
				edges[key] = int(edges.get(key, 0)) + 1
		for count in edges.values():
			closed = closed and count == 2
	_check(valid, "cassette stocks have nondegenerate geometry/UVs and finite orthonormal tangent frames")
	_check(closed, "frames and curved vanes form closed welded solids without missing ends")


func _test_pressure_endcaps(craft: HeroShip) -> void:
	var fore := craft.get_node("CinderCargoVisual/ForwardPressureCap") as MeshInstance3D
	var aft := craft.get_node("CinderCargoVisual/AftPressureCap") as MeshInstance3D
	var bounds := fore.mesh.get_aabb()
	_check(fore.mesh == aft.mesh and fore.mesh.get_surface_count() == 1
		and bounds.position.is_equal_approx(Vector3(-2.25, -0.08, -1.175))
		and bounds.size.is_equal_approx(Vector3(4.50, 0.16, 2.35))
		and fore.position == Vector3(0, 0, -6.03) and aft.position == Vector3(0, 0, 6.03)
		and is_equal_approx(fore.rotation.x, -PI * 0.5) and is_equal_approx(aft.rotation.x, PI * 0.5),
		"both formed endcaps share one surface and retain exact plate bounds and hardware transforms")
	var arrays := fore.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
	var shoulder_heights := {}
	var valid := indices.size() / 3 <= 320 and tangents.size() == vertices.size() * 4
	var rounded_corners := true
	for i in vertices.size():
		var point := vertices[i]
		var tangent := Vector3(tangents[i * 4], tangents[i * 4 + 1], tangents[i * 4 + 2])
		valid = valid and tangent.is_finite() and absf(tangent.length() - 1.0) < 0.001
		valid = valid and absf(normals[i].dot(tangent)) < 0.001
		valid = valid and normals[i].is_finite() and is_equal_approx(normals[i].length(), 1.0)
		valid = valid and absf(point.x) <= 2.125 - 1.5625 * point.y + 0.00001
		if point.y > -0.079 and point.y < 0.079 and point.z > 1.0:
			shoulder_heights[snappedf(point.y, 0.001)] = true
		if absf(point.x) > 2.20:
			rounded_corners = rounded_corners and absf(point.z) < 1.05
	var edges := {}
	for triangle in range(0, indices.size(), 3):
		var a := indices[triangle]
		var b := indices[triangle + 1]
		var c := indices[triangle + 2]
		var outward := (vertices[c] - vertices[a]).cross(vertices[b] - vertices[a])
		valid = valid and outward.length_squared() > 1e-12
		valid = valid and outward.dot(normals[a] + normals[b] + normals[c]) > 0.0
		valid = valid and absf((uvs[b] - uvs[a]).cross(uvs[c] - uvs[a])) > 1e-10
		for pair in [[a, b], [b, c], [c, a]]:
			var keys := [str(vertices[pair[0]].snapped(Vector3.ONE * 0.00001)), str(vertices[pair[1]].snapped(Vector3.ONE * 0.00001))]
			keys.sort()
			var key: String = keys[0] + ":" + keys[1]
			edges[key] = int(edges.get(key, 0)) + 1
	var closed := true
	for count in edges.values():
		closed = closed and count == 2
	_check(shoulder_heights.size() >= 3 and rounded_corners,
		"cargo caps have a broad three-stage rolled return and rounded silhouette corners")
	_check(valid and closed,
		"formed caps are closed outward-wound solids with finite normals, usable UVs and bounded triangle cost")


func _test_formed_cockpit_walls(craft: HeroShip) -> void:
	var visual := craft.get_variant_visual_root()
	var cockpit := visual.get_node("CockpitInterior")
	var fairing := visual.get_node("CockpitPressureTransition") as MeshInstance3D
	var names := ["PortSidewall", "StarboardSidewall", "ForwardPressureWall", "RearPressureWall"]
	var contact_points := [Vector3(-1.44, 0, -0.555), Vector3(1.44, 0, -0.555), Vector3(0, 0, -2.45), Vector3(0, 0, 1.32)]
	var triangles := 0
	for index in names.size():
		var wall := cockpit.get_node(names[index]) as MeshInstance3D
		_check(wall.mesh is ArrayMesh and wall.mesh.get_surface_count() == 1 and wall.mesh.surface_get_material(0) == null,
			"formed cockpit armor keeps one surface per existing owner and no material in shared geometry")
		_check(wall.material_override == fairing.mesh.surface_get_material(0) and wall.get_child_count() == 0,
			"formed cockpit armor uses the owning craft finish with no additional scene or collision nodes")
		var faces := wall.mesh.get_faces()
		triangles += faces.size() / 3
		var levels: Dictionary = {}
		var contact := Vector3.INF
		for vertex in faces:
			var at := wall.transform * vertex
			levels[snappedf(at.y, 0.001)] = true
			if absf(at.x - contact_points[index].x) < 0.001 and absf(at.z - contact_points[index].z) < 0.001:
				if at.y < contact.y: contact = at
		_check(levels.size() >= 9, "armor has a substantial rolled profile below the retained seal land")
		var height := -INF
		var skin_faces := fairing.mesh.get_faces()
		for triangle in range(0, skin_faces.size(), 3):
			var hit = Geometry3D.ray_intersects_triangle(Vector3(contact.x, 8, contact.z), Vector3.DOWN,
				fairing.transform * skin_faces[triangle], fairing.transform * skin_faces[triangle + 1], fairing.transform * skin_faces[triangle + 2])
			if hit != null: height = maxf(height, hit.y)
		_check(is_finite(height) and height - contact.y > 0.025 and height - contact.y < 0.045,
			"the emitted armor toe seats inside actual fairing triangles, including the widest cheek and fore/aft center")
	_check(triangles <= 600, "four formed wall owners stay within 600 triangles and four submissions")


## Phase 6 fleet damage/repair/recovery coverage for the shared presentation.
##
## This craft is composed from script by its production binding rather than
## instanced from a `scenes/ships/*.tscn`, so it used to raise none of the shared
## channels a player sees on every authored craft. It now attaches the same
## `scenes/effects/hero_damage_presentation.tscn`, and this drives the whole
## lifecycle through it: staged hull sparks, engine smoke and engine-failure
## sparks on this hull's own anchors, the damage and engine-failure practicals,
## the localized rig the shared `component_damage_*` seam routes, the degraded
## engine exhaust grade, the reduced-flash impact clamp, a destruction burst
## detached out of the craft, and a regeneration that clears every one of them.
func _test_shared_damage_presentation(craft: CinderCargoHauler) -> void:
	var presentation := craft.get_damage_presentation()
	_check(
		presentation != null,
		"the hauler carries the fleet's shared damage presentation"
	)
	if presentation == null:
		return
	var sparks := presentation.get_node_or_null(^"DamageSparks") as CPUParticles3D
	var engine_sparks := presentation.get_node_or_null(^"EngineFailureSparks") as CPUParticles3D
	var smoke := presentation.get_node_or_null(^"EngineSmoke") as CPUParticles3D
	var warning := presentation.get_node_or_null(^"DamageWarningLight") as OmniLight3D
	var engine_light := presentation.get_node_or_null(^"EngineFailureLight") as OmniLight3D
	_check(
		presentation.get_script() == load("res://scripts/effects/hero_damage_presentation.gd")
		and presentation.spark_anchor.is_equal_approx(CinderCargoHauler.DAMAGE_SPARK_ANCHOR)
		and presentation.smoke_anchor.is_equal_approx(CinderCargoHauler.DAMAGE_SMOKE_ANCHOR)
		and presentation.warning_anchor.is_equal_approx(CinderCargoHauler.DAMAGE_WARNING_ANCHOR)
		and presentation.destruction_debris_count == CinderCargoHauler.DAMAGE_DEBRIS_COUNT
		and sparks != null and engine_sparks != null and smoke != null
		and warning != null and engine_light != null
		and sparks.position.is_equal_approx(CinderCargoHauler.DAMAGE_SPARK_ANCHOR)
		and smoke.position.is_equal_approx(CinderCargoHauler.DAMAGE_SMOKE_ANCHOR)
		and engine_sparks.position.is_equal_approx(CinderCargoHauler.DAMAGE_SMOKE_ANCHOR)
		and warning.position.is_equal_approx(CinderCargoHauler.DAMAGE_WARNING_ANCHOR)
		and engine_light.position.is_equal_approx(CinderCargoHauler.DAMAGE_SMOKE_ANCHOR),
		"the shared rig anchors its spark, smoke, warning and engine channels on this hull's own geometry"
	)
	_check(
		not sparks.emitting and not smoke.emitting and not engine_sparks.emitting
		and is_zero_approx(warning.light_energy)
		and is_zero_approx(engine_light.light_energy)
		and not warning.shadow_enabled and not engine_light.shadow_enabled
		and presentation.get_live_world_effect_count() == 0
		and presentation.get_status() == &"healthy",
		"an undamaged craft draws none of those channels and casts no extra shadow"
	)

	craft.set_physics_process(false)
	craft.set("_landed", false)
	craft.set("_engine_state", HeroShip.ENGINE_ONLINE)
	craft.call("_sync_damage_presentation")

	# Damaged: hull sparks and the amber damage practical, plus one world impact.
	craft.apply_damage(
		craft.maximum_hull * 0.45,
		craft.to_global(CinderCargoHauler.DAMAGE_SPARK_ANCHOR),
		Vector3.UP
	)
	await process_frame
	await process_frame
	_check(
		presentation.get_status() == &"damaged"
		and sparks.emitting and sparks.visible
		and presentation.is_alarm_active()
		and warning.light_energy > 0.0
		and presentation.get_live_world_effect_count() == 1
		and not smoke.emitting,
		"damage raises the hull sparks and the damage warning light with one impact burst"
	)

	# Critical: engine smoke, engine-failure sparks and the cyan failure practical.
	craft.apply_damage(
		craft.maximum_hull * 0.35,
		craft.to_global(CinderCargoHauler.DAMAGE_SMOKE_ANCHOR),
		Vector3.UP
	)
	await process_frame
	await process_frame
	_check(
		presentation.get_status() == &"critical"
		and smoke.emitting and smoke.visible
		and engine_sparks.emitting and engine_sparks.visible
		and presentation.is_engine_failure_active()
		and engine_light.light_energy > 0.0
		and presentation.get_engine_power_multiplier() < 1.0,
		"critical damage raises engine smoke, engine-failure sparks and the degraded engine cue"
	)

	# The already-authoritative component roster drives the localized rig and the
	# static exhaust grade; neither is decided here.
	var model := craft.get_component_damage()
	var engine_anchor := _component_local_position(
		craft, ShipComponentDamage.COMPONENT_ENGINE_BAY
	)
	var guard := 0
	while model.get_component_state(ShipComponentDamage.COMPONENT_ENGINE_BAY) \
			< ShipComponentDamage.ComponentState.FAILED and guard < 4:
		model.record_damage(craft.maximum_hull * 2.0, engine_anchor)
		guard += 1
	craft.call("_sync_component_damage", 0.01)
	craft.call("_sync_engine_visuals_immediately")
	await process_frame
	var rig := presentation.get_node_or_null(
		"ComponentDamage_%s" % String(ShipComponentDamage.COMPONENT_ENGINE_BAY)
	) as Node3D
	var exhaust := craft.get_engine_exhaust_damage_presentation_profile()
	var visible_plumes := 0
	for plume_value in craft.get("_engine_glows") as Array:
		if is_instance_valid(plume_value) and (plume_value as MeshInstance3D).visible:
			visible_plumes += 1
	_check(
		rig != null
		and rig.position.is_equal_approx(engine_anchor)
		and presentation.get_failed_component_effect_ids().has(
			ShipComponentDamage.COMPONENT_ENGINE_BAY
		)
		and exhaust.get("stage") == &"failed"
		and visible_plumes == 0
		and not bool(exhaust.get("flashing", true))
		and not bool(exhaust.get("gameplay_authority", true)),
		"a failed engine bay shows the shared localized rig and puts out this craft's real plumes"
	)

	# Reduced flash: whatever intensity the caller resolved, the impact practical
	# is clamped to 1.6x peak and from there only decays, and the core only ever
	# expands and fades inside its authored band. There is no pulse in it.
	var world_effects_before: Dictionary = {}
	for existing in root.get_children():
		world_effects_before[existing.get_instance_id()] = true
	presentation.present_impact(craft.global_position, Vector3.UP, 4.0)
	var impact := _impact_effect_added_since(world_effects_before)
	var impact_flash := impact.get_node_or_null(^"ImpactFlash") as MeshInstance3D \
		if impact != null else null
	var impact_light := impact.get_node_or_null(^"ImpactLight") as OmniLight3D \
		if impact != null else null
	var peak_energy := impact_light.light_energy if impact_light != null else -1.0
	var previous_energy := peak_energy
	var previous_transparency := impact_flash.transparency if impact_flash != null else 0.0
	var decays_without_pulsing := impact_light != null and impact_flash != null
	for _flash_step in 8:
		await process_frame
		if not is_instance_valid(impact_light) or not is_instance_valid(impact_flash):
			break
		if impact_light.light_energy > previous_energy + 0.0001 \
				or impact_flash.transparency < previous_transparency - 0.0001 \
				or impact_flash.scale.x > HeroDamagePresentation.IMPACT_FLASH_MAXIMUM_SCALE * 1.22 + 0.0001 \
				or impact_light.omni_range > HeroDamagePresentation.IMPACT_LIGHT_MAXIMUM_RANGE + 0.0001:
			decays_without_pulsing = false
		previous_energy = impact_light.light_energy
		previous_transparency = impact_flash.transparency
	_check(
		impact_flash != null and impact_light != null
		and is_equal_approx(peak_energy, 5.2 * 1.6)
		and decays_without_pulsing
		and previous_energy < peak_energy
		and not impact_light.shadow_enabled
		and impact_flash.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
		"the shared impact practical stays inside the reduced-flash clamp and only decays at any intensity"
	)

	# Destruction: the burst and its debris detach out of the craft so a hidden or
	# recycled hull cannot drag them along.
	craft.apply_damage(craft.maximum_hull * 2.0, craft.global_position, Vector3.UP)
	await process_frame
	await process_frame
	var destruction := presentation.get_destruction_effect_root()
	var debris := 0
	if destruction != null:
		for child in destruction.get_children():
			if str(child.name).begins_with("HeroHullDebris"):
				debris += 1
	_check(
		craft.is_destroyed()
		and destruction != null
		and not craft.is_ancestor_of(destruction)
		and debris == CinderCargoHauler.DAMAGE_DEBRIS_COUNT
		and presentation.get_status() == &"destroyed",
		"destruction detaches the shared burst out of the craft with its full debris count"
	)

	# Regeneration: the berth's reuse path clears every channel it raised.
	var reset := craft.reset_for_reuse(craft.global_transform)
	await process_frame
	await process_frame
	_check(
		bool(reset.get("accepted", false))
		and presentation.get_status() == &"healthy"
		and not sparks.emitting and not smoke.emitting and not engine_sparks.emitting
		and is_zero_approx(warning.light_energy)
		and is_zero_approx(engine_light.light_energy)
		and presentation.get_destruction_effect_root() == null
		and presentation.get_live_world_effect_count() == 0
		and presentation.get_active_component_effect_count() == 0
		and presentation.get_node_or_null(
			"ComponentDamage_%s" % String(ShipComponentDamage.COMPONENT_ENGINE_BAY)
		) == null,
		"regeneration clears every damage, component, and destruction channel it raised"
	)


func _component_local_position(ship: HeroShip, component_id: StringName) -> Vector3:
	for component in ship.get_component_damage_report().get("components", []) as Array:
		if StringName((component as Dictionary).get("id", &"")) == component_id:
			return (component as Dictionary).get("local_position", Vector3.ZERO) as Vector3
	return Vector3.ZERO


## The shared presentation detaches its impacts into the scene-tree root by
## design, and a colliding sibling there is renamed by the engine, so the burst
## one call raised is found as the root child that was not there before it.
func _impact_effect_added_since(before: Dictionary) -> Node3D:
	for candidate in root.get_children():
		if before.has(candidate.get_instance_id()):
			continue
		if candidate is Node3D and candidate.get_node_or_null(^"ImpactLight") != null:
			return candidate as Node3D
	return null
