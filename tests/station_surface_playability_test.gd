extends SceneTree

## Production-capsule coverage for every authored station stair/ramp and the
## collision-backed floor roster used by reachable station routes. Movement
## probes use continuous real InputMap actions and never press jump.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const WORLD_LAYER := PhysicsLayers.WORLD

const WORLD_SURFACE_PATHS := [
	"ExposedDockLattice/CentralJunction",
	"ExposedDockLattice/HeroBerthNode",
	"ExposedDockLattice/JunctionLink",
	"ExposedDockLattice/PortBranchArm",
	"ExposedDockLattice/PortBerthNode",
	"ExposedDockLattice/StarboardBranchArm",
	"ExposedDockLattice/StarboardBerthNode",
	"ExposedDockLattice/AftSpine",
	"ExposedDockLattice/AftModuleConnector",
	"ExposedDockLattice/FleetDockCombConnector/FleetDockCombConnectorDeck",
	"OpenLaunchSpine/LaunchArmDeck",
	"UpperOperations/ObservationLanding",
	"UpperOperations/OperationsPodFloor",
	"ModernFleetRegistry/RegistryPodDeck",
]

const AFT_SURFACE_PATHS := [
	"Structure/LowerOpenDeck/ConnectionDeck",
	"Structure/LowerOpenDeck/JunctionDeck",
	"Structure/LowerOpenDeck/StairBaseLanding",
	"Structure/Circulation/ContinuousStairRamp",
	"Structure/UpperOpenDeck/UpperFloor",
	"Structure/OperationsRoom/OperationsFloor",
]

const HABITAT_SURFACE_PATHS := [
	"Structure/PlayerClearConnector/ConnectorFloor",
	"Structure/PressurizedHabitatCorridor/EntryVestibuleFloor",
	"Structure/PressurizedHabitatCorridor/HabitatFloor",
	"Structure/ObservationCommon/CommonFloor",
]

const FREIGHT_SURFACE_PATHS := [
	"ConnectionLattice/ConnectionDeckA",
	"ConnectionLattice/ConnectionDeckB",
	"ConnectionLattice/ConnectionDeckC",
	"ConnectionLattice/ConnectionHandoffDeck",
	"LoadingApron/ApronDeck01",
	"LoadingApron/ApronDeck02",
	"LoadingApron/ApronDeck03",
	"LoadingApron/ApronDeck04",
	"LoadingApron/CargoRackShelf",
	"LoadingApron/ServiceRoomShelf",
	"FreightControlRoom/RoomFloor",
]

const COMB_SURFACE_PATHS := [
	"GeneratedComb/WalkableSurfaces/Trunk",
	"GeneratedComb/WalkableSurfaces/Rung01",
	"GeneratedComb/WalkableSurfaces/DockSlab01",
	"GeneratedComb/WalkableSurfaces/Rung02",
	"GeneratedComb/WalkableSurfaces/DockSlab02",
	"GeneratedComb/WalkableSurfaces/Rung03Vertical",
	"GeneratedComb/WalkableSurfaces/DockSlab03Upper",
]

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "production Main instantiates for station surface playability")
	if game == null:
		_finish()
		return
	root.add_child(game)
	await process_frame
	await physics_frame
	game.start_shift()
	for _settle in 6:
		await physics_frame

	var world := game.get_node_or_null(^"ShipyardWorld") as ShipyardWorld
	var player := game.get_node_or_null(^"Player") as PlayerController
	_check(world != null and player != null, "production world and player capsule are live")
	if world == null or player == null:
		game.queue_free()
		await process_frame
		_finish()
		return

	_test_collision_backed_surface_roster(world)
	_test_station_panel_material_bindings(world)
	await _test_discovered_walkable_surface_support(world)
	await _test_spawn_adjacent_stair(world, player)
	await _test_aft_stair_mount_and_climb(world, player)
	await _test_fleet_comb_ramp(world, player)

	_release_actions()
	game.queue_free()
	await process_frame
	await physics_frame
	await process_frame
	_finish()


func _test_collision_backed_surface_roster(world: ShipyardWorld) -> void:
	var aft := world.get_node_or_null(^"AftJunctionStack") as AftJunctionStack
	var habitat := world.get_node_or_null(^"HabitatSpine") as HabitatSpine
	var freight := world.get_node_or_null(^"JovianFreightBerth") as JovianFreightBerth
	var comb := world.get_node_or_null(^"FleetDockComb") as FleetDockComb
	_check(aft != null and habitat != null and freight != null and comb != null, "all reachable station modules resolve for surface coverage")

	var every_surface_exact := _surface_roster_matches(world, WORLD_SURFACE_PATHS)
	if aft != null:
		every_surface_exact = _surface_roster_matches(aft, AFT_SURFACE_PATHS) and every_surface_exact
	if habitat != null:
		every_surface_exact = _surface_roster_matches(habitat, HABITAT_SURFACE_PATHS) and every_surface_exact
	if freight != null:
		every_surface_exact = _surface_roster_matches(freight, FREIGHT_SURFACE_PATHS) and every_surface_exact
	if comb != null:
		every_surface_exact = _surface_roster_matches(comb, COMB_SURFACE_PATHS) and every_surface_exact
	_check(every_surface_exact, "all 42 visible route floors, decks, shelves, slabs, rungs, and ramps own matching World collision")


func _surface_roster_matches(owner: Node3D, paths: Array) -> bool:
	var valid := true
	for raw_path in paths:
		var path := NodePath(raw_path)
		var body := owner.get_node_or_null(path) as StaticBody3D
		if body == null or body.collision_layer != WORLD_LAYER or body.collision_mask != 0:
			print("SURFACE_ROSTER_INVALID_BODY: ", owner.name, "/", raw_path, " -> ", body)
			valid = false
			continue
		var mesh_instance := body.get_node_or_null(^"Mesh") as MeshInstance3D
		if mesh_instance == null:
			mesh_instance = body.get_node_or_null(^"RampMesh") as MeshInstance3D
		var collision := body.get_node_or_null(^"Collision") as CollisionShape3D
		if collision == null:
			collision = body.get_node_or_null(^"RampCollision") as CollisionShape3D
		if mesh_instance == null or mesh_instance.mesh == null or collision == null or collision.shape == null or collision.disabled:
			print("SURFACE_ROSTER_INVALID_CHILDREN: ", owner.name, "/", raw_path)
			valid = false
			continue
		var box := collision.shape as BoxShape3D
		if box != null and mesh_instance.mesh.get_aabb().size.distance_to(box.size) > 0.035:
			print("SURFACE_ROSTER_SIZE_DRIFT: ", owner.name, "/", raw_path, " mesh=", mesh_instance.mesh.get_aabb().size, " collision=", box.size)
			valid = false
	return valid


func _test_station_panel_material_bindings(world: ShipyardWorld) -> void:
	var specs := [
		[world.get_node_or_null(^"AftJunctionStack"), ["off_white", "off_white_floor", "panel_light", "warm_grey", "warm_grey_floor", "mid_grey_floor", "hull_dark_floor"], 0.30],
		[world.get_node_or_null(^"HabitatSpine"), ["shell_light", "shell_light_floor", "shell_mid", "floor"], 0.28],
		[world.get_node_or_null(^"JovianFreightBerth"), ["ceramic", "ceramic_warm", "steel_blue"], 0.30],
		[world.get_node_or_null(^"JovianFreightBerth"), ["ceramic_floor", "deck"], 0.22],
	]
	var every_binding_exact := true
	for spec in specs:
		var owner := spec[0] as Node3D
		if owner == null:
			every_binding_exact = false
			continue
		var materials := owner.get("_materials") as Dictionary
		for key in spec[1] as Array:
			var material := materials.get(key) as StandardMaterial3D
			every_binding_exact = every_binding_exact and material != null
			if material == null:
				continue
			every_binding_exact = every_binding_exact \
				and material.albedo_texture != null \
				and material.albedo_texture.resource_path == "res://assets/materials/procedural-panel-triplanar-albedo-v2.png" \
				and material.normal_enabled \
				and material.normal_texture != null \
				and material.normal_texture.resource_path == "res://assets/materials/procedural-panel-triplanar-normal-v2.png" \
				and is_equal_approx(material.normal_scale, 0.48) \
				and material.roughness_texture != null \
				and material.roughness_texture.resource_path == "res://assets/materials/procedural-panel-triplanar-roughness-v2.png" \
				and material.roughness_texture_channel == BaseMaterial3D.TEXTURE_CHANNEL_RED \
				and material.uv1_triplanar \
				and material.uv1_world_triplanar \
				and material.texture_repeat \
				and material.uv1_scale.is_equal_approx(Vector3.ONE * float(spec[2]))
	_check(every_binding_exact, "Aft, Habitat, and Freight station roles use the exact neutral world-triplanar PBR recipe and frozen scales")

	var aft := world.get_node_or_null(^"AftJunctionStack") as AftJunctionStack
	var habitat := world.get_node_or_null(^"HabitatSpine") as HabitatSpine
	var freight := world.get_node_or_null(^"JovianFreightBerth") as JovianFreightBerth
	var no_arrow_station_materials := true
	var audited_station_meshes := 0
	var skipped_live_ship_meshes := 0
	var forbidden_station_paths := PackedStringArray()
	for candidate in world.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		if _is_live_ship_mesh(mesh_instance, world):
			skipped_live_ship_meshes += 1
			continue
		audited_station_meshes += 1
		for surface_index in mesh_instance.mesh.get_surface_count() if mesh_instance.mesh != null else 0:
			var material := mesh_instance.get_active_material(surface_index) as StandardMaterial3D
			if material == null:
				continue
			for texture in [material.albedo_texture, material.normal_texture, material.roughness_texture]:
				if texture == null:
					continue
				var texture_path := (texture as Texture2D).resource_path
				if "arrow-hull-" in texture_path or "jovian-hull-" in texture_path:
					no_arrow_station_materials = false
					forbidden_station_paths.append("%s -> %s" % [mesh_instance.get_path(), texture_path])
	forbidden_station_paths.sort()
	print(
		"STATION_TEXTURE_TRAVERSAL: station_meshes=", audited_station_meshes,
		" skipped_live_ship_meshes=", skipped_live_ship_meshes,
		" forbidden=", forbidden_station_paths
	)
	_check(audited_station_meshes >= 450, "texture traversal audits the complete live ShipyardWorld station subtree")
	_check(no_arrow_station_materials, "no live station MeshInstance3D uses the directional Arrow or Jovian hull atlases")

	var treads := aft.find_children("VisibleTread*", "MeshInstance3D", true, false) if aft != null else []
	var tread_world_phase := treads.size() == AftJunctionStack.STAIR_STEP_COUNT
	var tread_origins := {}
	for candidate in treads:
		var tread := candidate as MeshInstance3D
		var material := tread.material_override as StandardMaterial3D
		tread_world_phase = tread_world_phase \
			and material != null \
			and material.uv1_world_triplanar \
			and material.uv1_scale.is_equal_approx(Vector3.ONE * 0.30)
		tread_origins[tread.global_position] = true
	_check(tread_world_phase and tread_origins.size() == AftJunctionStack.STAIR_STEP_COUNT, "all fifteen Aft treads sample one world-space panel field instead of cloning local-origin patches")

	# Same-role coplanar pieces must share the same resource. Combined with
	# world-space triplanar coordinates, this guarantees one metric phase at
	# seams instead of restarting the panel field at each MeshInstance origin.
	var phase_groups := [
		[aft, "off_white_floor", [
			"Structure/LowerOpenDeck/ConnectionDeck",
			"Structure/LowerOpenDeck/StairBaseLanding",
			"Structure/UpperOpenDeck/UpperFloor",
			"Structure/OperationsRoom/OperationsFloor",
		]],
		[habitat, "shell_light_floor", [
			"Structure/PlayerClearConnector/ConnectorFloor",
			"Structure/PressurizedHabitatCorridor/EntryVestibuleFloor",
			"Structure/PressurizedHabitatCorridor/HabitatFloor",
			"Structure/ObservationCommon/CommonFloor",
		]],
		[freight, "deck", [
			"ConnectionLattice/ConnectionDeckA",
			"ConnectionLattice/ConnectionDeckB",
			"ConnectionLattice/ConnectionDeckC",
			"LoadingApron/ApronDeck01",
			"LoadingApron/ApronDeck02",
			"LoadingApron/ApronDeck03",
			"LoadingApron/ApronDeck04",
		]],
		[freight, "ceramic_floor", [
			"ConnectionLattice/ConnectionHandoffDeck",
			"FreightControlRoom/RoomFloor",
		]],
	]
	var coplanar_phase_exact := true
	for phase_group in phase_groups:
		var owner := phase_group[0] as Node3D
		if owner == null:
			coplanar_phase_exact = false
			continue
		var reference := (owner.get("_materials") as Dictionary).get(phase_group[1]) as StandardMaterial3D
		coplanar_phase_exact = coplanar_phase_exact and reference != null and reference.uv1_world_triplanar
		for raw_path in phase_group[2] as Array:
			coplanar_phase_exact = coplanar_phase_exact and _surface_material(owner, NodePath(raw_path)) == reference
	_check(coplanar_phase_exact, "coplanar station floor segments share one material resource, scale, and world-metric triplanar phase across seams")

	# Overlay pieces the player physically walks on used to sit unmapped on top of
	# mapped floors: the Aft continuous stair ramp, the Aft operations pressure
	# plates, and the Habitat connector/corridor/common insets. They must carry the
	# same station family as the floor they interrupt.
	var walked_overlays_mapped := true
	for overlay_spec in [
		[aft, "Structure/Circulation/ContinuousStairRamp/RampMesh"],
		[habitat, "Structure/PlayerClearConnector/ConnectorInset"],
		[habitat, "Structure/PressurizedHabitatCorridor/CorridorLane"],
		[habitat, "Structure/ObservationCommon/CommonFloorInset"],
	]:
		var overlay_owner := overlay_spec[0] as Node3D
		var overlay: MeshInstance3D
		if overlay_owner != null:
			overlay = overlay_owner.get_node_or_null(NodePath(overlay_spec[1] as String)) as MeshInstance3D
		var overlay_material: StandardMaterial3D
		if overlay != null and overlay.mesh != null and overlay.mesh.get_surface_count() > 0:
			overlay_material = overlay.get_active_material(0) as StandardMaterial3D
		walked_overlays_mapped = walked_overlays_mapped \
			and overlay_material != null \
			and overlay_material.albedo_texture != null \
			and overlay_material.albedo_texture.resource_path == "res://assets/materials/procedural-panel-triplanar-albedo-v2.png" \
			and overlay_material.uv1_world_triplanar
	_check(walked_overlays_mapped, "the Aft stair ramp and the Habitat connector/corridor/common floor overlays carry the station panel family")

	var mapped_pressure_plates := 0
	if aft != null:
		var aft_materials := aft.get("_materials") as Dictionary
		var plate_materials := [aft_materials.get("hull_dark_floor"), aft_materials.get("mid_grey_floor")]
		for candidate in aft.get_node(^"Structure/OperationsRoom").find_children("*", "MeshInstance3D", true, false):
			var plate := candidate as MeshInstance3D
			if plate.mesh == null or plate.mesh.get_surface_count() == 0:
				continue
			var plate_material := plate.get_active_material(0) as StandardMaterial3D
			if plate_material == null or not plate_materials.has(plate_material):
				continue
			if plate_material.albedo_texture != null \
					and plate_material.albedo_texture.resource_path == "res://assets/materials/procedural-panel-triplanar-albedo-v2.png" \
					and plate_material.uv1_world_triplanar:
				mapped_pressure_plates += 1
	_check(mapped_pressure_plates == 9, "all nine Aft operations-room floor pressure plates read as mapped station floor, not unmapped voids")


func _surface_material(owner: Node3D, path: NodePath) -> Material:
	var body := owner.get_node_or_null(path) as StaticBody3D
	if body == null:
		return null
	var mesh_instance := body.get_node_or_null(^"Mesh") as MeshInstance3D
	if mesh_instance == null:
		mesh_instance = body.get_node_or_null(^"RampMesh") as MeshInstance3D
	if mesh_instance == null or mesh_instance.mesh == null or mesh_instance.mesh.get_surface_count() == 0:
		return null
	return mesh_instance.get_active_material(0)


func _is_live_ship_mesh(mesh_instance: MeshInstance3D, world: ShipyardWorld) -> bool:
	var cursor := mesh_instance.get_parent()
	while cursor != null and cursor != world:
		if cursor is HeroShip:
			return true
		cursor = cursor.get_parent()
	return false


func _test_discovered_walkable_surface_support(world: ShipyardWorld) -> void:
	# This intentionally supplements the curated ownership roster. It discovers
	# every broad, thin, upward-facing mesh whose top centre lies in a reachable
	# route envelope, including visual-only tread and floor-detail overlays.
	var route_envelopes := [
		AABB(Vector3(-60.0, -0.2, -69.0), Vector3(120.0, 1.0, 129.0)),
		AABB(Vector3(-14.0, -0.1, 4.3), Vector3(5.0, 3.7, 6.8)),
		AABB(Vector3(-8.0, -0.1, 49.0), Vector3(4.7, 4.7, 12.5)),
		AABB(Vector3(-12.0, 3.9, 60.0), Vector3(67.0, 1.2, 63.0)),
		AABB(Vector3(49.5, 4.0, 57.0), Vector3(5.0, 3.2, 13.0)),
	]
	var candidates := 0
	var supported := 0
	var explicitly_tagged_decorations := 0
	var unsupported_paths := PackedStringArray()
	var unreasoned_visual_paths := PackedStringArray()
	var space := world.get_world_3d().direct_space_state
	for candidate in world.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		if mesh_instance.mesh == null or not mesh_instance.is_visible_in_tree():
			continue
		var exclusion_reason := _intentional_non_walkable_reason(mesh_instance, world)
		if not exclusion_reason.is_empty():
			explicitly_tagged_decorations += 1
			continue
		var local_aabb := mesh_instance.mesh.get_aabb()
		var local_size := local_aabb.size
		var world_up := mesh_instance.global_basis.y.normalized()
		var top_local := local_aabb.position + Vector3(local_size.x * 0.5, local_size.y, local_size.z * 0.5)
		var top_world := mesh_instance.global_transform * top_local
		var in_route_envelope := false
		for envelope: AABB in route_envelopes:
			if envelope.has_point(top_world):
				in_route_envelope = true
				break
		var broad_thin_upward := local_size.x >= 0.65 \
			and local_size.z >= 0.65 \
			and local_size.y <= 0.82 \
			and world_up.dot(Vector3.UP) >= 0.72
		if not broad_thin_upward or not in_route_envelope:
			if bool(mesh_instance.get_meta("non_authoritative_visual", false)):
				if str(mesh_instance.get_meta("non_walkable_reason", "")).is_empty():
					unreasoned_visual_paths.append(str(mesh_instance.get_path()))
				else:
					explicitly_tagged_decorations += 1
			continue

		candidates += 1
		var ray := PhysicsRayQueryParameters3D.create(
			top_world + Vector3.UP * 0.08,
			top_world + Vector3.DOWN * 0.55,
			WORLD_LAYER
		)
		ray.collide_with_areas = false
		ray.collide_with_bodies = true
		var hit := space.intersect_ray(ray)
		if hit.is_empty():
			unsupported_paths.append(str(mesh_instance.get_path()))
		else:
			supported += 1
	unsupported_paths.sort()
	unreasoned_visual_paths.sort()
	print(
		"DISCOVERED_STATION_SURFACES: candidates=", candidates,
		" supported=", supported,
		" tagged_decorations=", explicitly_tagged_decorations,
		" unsupported=", unsupported_paths
	)
	_check(candidates >= 42, "discovery independently finds at least the complete curated route-surface count")
	_check(unsupported_paths.is_empty(), "every discovered broad/thin upward route mesh has immediate World collision support below")
	_check(unreasoned_visual_paths.is_empty(), "every intentionally non-authoritative station visual carries an explicit non-walkable reason")
	_check(explicitly_tagged_decorations > 0, "discovery explicitly excludes tagged nonblocking presentation with a stable reason")


func _intentional_non_walkable_reason(mesh_instance: MeshInstance3D, world: ShipyardWorld) -> String:
	if bool(mesh_instance.get_meta("non_authoritative_visual", false)):
		return str(mesh_instance.get_meta("non_walkable_reason", ""))
	var cursor := mesh_instance.get_parent()
	while cursor != null and cursor != world:
		if bool(cursor.get_meta("presentation_only", false)) and bool(cursor.get_meta("nonblocking_collision", false)):
			return "tagged presentation-only component with collision_policy=presentation_only_nonblocking"
		cursor = cursor.get_parent()
	return ""


func _test_spawn_adjacent_stair(world: ShipyardWorld, player: PlayerController) -> void:
	var start := Vector3(-11.5, 0.18, 10.8)
	var ramp := world.get_node_or_null(^"UpperOperations/JunctionAccessRamp") as StaticBody3D
	var rendered_ramp := ramp.get_node_or_null(^"Mesh") as MeshInstance3D if ramp != null else null
	var result := await _walk_forward_until(
		player,
		Transform3D(Basis.looking_at(Vector3(0, 0, -1), Vector3.UP), start),
		func() -> bool:
			return player.global_position.y >= 2.9 and player.global_position.z <= 5.3,
		180,
		false,
		func(player_position: Vector3) -> float:
			return _vertical_distance_to_rendered_ramp(ramp, rendered_ramp, player_position)
	)
	print("CENTRAL_STAIR_TRAVERSAL: ", result)
	_check(bool(result.reached), "continuous W reaches the spawn-adjacent observation landing without jumping")
	_check(float(result.maximum_y) >= 2.9, "spawn-adjacent stair raises the production capsule to the landing")
	_check(not bool(result.fell), "spawn-adjacent stair remains continuously supported")
	_check(int(result.visible_surface_samples) >= 20, "central traversal samples the rendered walking surface throughout the climb")
	_check(float(result.maximum_visible_surface_distance) <= 0.10, "production capsule feet stay within 0.10 m of the rendered central ramp plane during continuous W")

	_check(ramp != null and ramp.collision_layer == WORLD_LAYER and ramp.collision_mask == 0, "spawn-adjacent visible treads use one snag-free World collision ramp")
	if ramp != null:
		var ramp_shapes := ramp.find_children("*", "CollisionShape3D", true, false)
		_check(ramp_shapes.size() == 1, "spawn-adjacent stair owns exactly one continuous collision shape")
		var mesh_instance := ramp.get_node_or_null(^"Mesh") as MeshInstance3D
		var collision := ramp.get_node_or_null(^"Collision") as CollisionShape3D
		var shape := collision.shape as BoxShape3D if collision != null else null
		_check(
			mesh_instance != null and mesh_instance.mesh != null and shape != null \
				and mesh_instance.mesh.get_aabb().size.distance_to(shape.size) <= 0.001,
			"central ramp renders the exact same bounds as its authoritative collision"
		)

	var treads := world.get_node(^"UpperOperations").find_children("JunctionAccessTread*", "MeshInstance3D", false, false)
	var exact_tread_roster := treads.size() == 7
	var maximum_tread_edge_delta := 0.0
	for tread_index in 7:
		var tread := world.get_node_or_null(NodePath("UpperOperations/JunctionAccessTread%02d" % (tread_index + 1))) as MeshInstance3D
		exact_tread_roster = exact_tread_roster and tread != null
		if tread == null or tread.mesh == null:
			continue
		var half_size := tread.mesh.get_aabb().size * 0.5
		var tread_top := tread.global_position.y + half_size.y
		for edge_z in [tread.global_position.z - half_size.z, tread.global_position.z + half_size.z]:
			var tread_edge := Vector3(tread.global_position.x, tread_top, float(edge_z))
			maximum_tread_edge_delta = maxf(
				maximum_tread_edge_delta,
				_vertical_distance_to_rendered_ramp(ramp, rendered_ramp, tread_edge)
			)
	_check(exact_tread_roster, "central stair exposes seven uniquely named tread overlays with no duplicate fallback names")
	_check(maximum_tread_edge_delta <= 0.08, "every visible tread edge stays within 0.08 m of the rendered/colliding ramp surface")

	var relocated_mast: StaticBody3D = null
	for candidate in world.get_node(^"ExposedDockLattice").find_children("DockMast*", "StaticBody3D", false, false):
		var mast := candidate as StaticBody3D
		if mast.global_position.is_equal_approx(Vector3(-11.0, 5.2, 14.0)):
			relocated_mast = mast
			break
	var mast_supported := false
	if relocated_mast != null:
		var mast_ray := PhysicsRayQueryParameters3D.create(Vector3(-11.0, 0.08, 14.0), Vector3(-11.0, -0.20, 14.0), WORLD_LAYER)
		mast_ray.exclude = [relocated_mast.get_rid()]
		mast_ray.collide_with_areas = false
		var mast_hit := world.get_world_3d().direct_space_state.intersect_ray(mast_ray)
		mast_supported = not mast_hit.is_empty() and mast_hit.collider is StaticBody3D
	_check(mast_supported, "relocated port mast remains collision-supported by the CentralJunction deck")


func _vertical_distance_to_rendered_ramp(
		ramp: StaticBody3D,
		rendered_ramp: MeshInstance3D,
		world_point: Vector3
	) -> float:
	if ramp == null or rendered_ramp == null or rendered_ramp.mesh == null:
		return NAN
	var half_size := rendered_ramp.mesh.get_aabb().size * 0.5
	var plane_point := ramp.global_transform * Vector3(0.0, half_size.y, 0.0)
	var plane_normal := ramp.global_basis.y.normalized()
	var vertical_denominator := plane_normal.dot(Vector3.UP)
	if absf(vertical_denominator) < 0.001:
		return NAN
	var vertical_delta := plane_normal.dot(world_point - plane_point) / vertical_denominator
	var projected_local := ramp.to_local(world_point - Vector3.UP * vertical_delta)
	if absf(projected_local.x) > half_size.x + 0.001 or absf(projected_local.z) > half_size.z + 0.001:
		return NAN
	return absf(vertical_delta)


func _test_aft_stair_mount_and_climb(world: ShipyardWorld, player: PlayerController) -> void:
	var aft := world.get_node_or_null(^"AftJunctionStack") as AftJunctionStack
	if aft == null:
		_check(false, "Aft stair module resolves for physical traversal")
		return
	var local_start := Vector3(-5.7, 0.18, 1.75)
	var world_direction := (aft.global_basis * Vector3.BACK).normalized()
	var result := await _walk_forward_until(
		player,
		Transform3D(Basis.looking_at(world_direction, Vector3.UP), aft.to_global(local_start)),
		func() -> bool:
			var local := aft.to_local(player.global_position)
			return local.y >= 3.85 and local.z >= 12.0,
		190,
		true
	)
	print("AFT_STAIR_TRAVERSAL: ", result)
	_check(bool(result.reached), "continuous W mounts the Aft first tread from its lower deck and reaches the upper floor")
	_check(not bool(result.fell), "Aft stair approach and ramp remain continuously supported")
	var landing := aft.get_node_or_null(^"Structure/LowerOpenDeck/StairBaseLanding") as StaticBody3D
	_check(landing != null and landing.collision_layer == WORLD_LAYER and landing.collision_mask == 0, "Aft first tread has a collision-backed lower-deck landing")


func _test_fleet_comb_ramp(world: ShipyardWorld, player: PlayerController) -> void:
	var comb := world.get_node_or_null(^"FleetDockComb") as FleetDockComb
	if comb == null:
		_check(false, "Fleet Dock Comb resolves for physical ramp traversal")
		return
	var local_start := Vector3(0.6, 0.18, 40.0)
	var world_direction := (comb.global_basis * Vector3.RIGHT).normalized()
	var result := await _walk_forward_until(
		player,
		Transform3D(Basis.looking_at(world_direction, Vector3.UP), comb.to_global(local_start)),
		func() -> bool:
			var local := comb.to_local(player.global_position)
			return local.x >= 9.1 and local.y >= 2.2,
		150,
		true
	)
	print("FLEET_COMB_RAMP_TRAVERSAL: ", result)
	_check(bool(result.reached), "continuous W climbs the Fleet Dock Comb ramp without jumping")
	_check(not bool(result.fell), "Fleet Dock Comb ramp remains continuously supported")


func _walk_forward_until(
		player: PlayerController,
		start: Transform3D,
		reached_predicate: Callable,
		maximum_frames: int,
		sprint: bool = false,
		visible_surface_distance: Callable = Callable()
	) -> Dictionary:
	_release_actions()
	player.teleport_to(start)
	for _settle in 8:
		await physics_frame
	var initial := player.global_position
	var maximum_y := initial.y
	var minimum_y := initial.y
	var grounded_frames := 0
	var reached := false
	var visible_surface_samples := 0
	var maximum_visible_surface_distance := 0.0
	var maximum_visible_surface_distance_position := Vector3.ZERO
	Input.action_press(&"move_forward")
	if sprint:
		Input.action_press(&"sprint_boost")
	for _frame in maximum_frames:
		await physics_frame
		maximum_y = maxf(maximum_y, player.global_position.y)
		minimum_y = minf(minimum_y, player.global_position.y)
		if player.is_on_floor():
			grounded_frames += 1
		if visible_surface_distance.is_valid():
			var surface_distance := float(visible_surface_distance.call(player.global_position))
			if is_finite(surface_distance):
				visible_surface_samples += 1
				if surface_distance > maximum_visible_surface_distance:
					maximum_visible_surface_distance = surface_distance
					maximum_visible_surface_distance_position = player.global_position
		if reached_predicate.call():
			reached = true
			break
	Input.action_release(&"move_forward")
	Input.action_release(&"sprint_boost")
	await physics_frame
	return {
		"reached": reached,
		"initial": initial,
		"final": player.global_position,
		"maximum_y": maximum_y,
		"minimum_y": minimum_y,
		"grounded_frames": grounded_frames,
		"fell": minimum_y < initial.y - 0.65,
		"visible_surface_samples": visible_surface_samples,
		"maximum_visible_surface_distance": maximum_visible_surface_distance,
		"maximum_visible_surface_distance_position": maximum_visible_surface_distance_position,
	}


func _release_actions() -> void:
	for action in [&"move_forward", &"move_back", &"move_left", &"move_right", &"sprint_boost", &"jump"]:
		Input.action_release(action)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	_release_actions()
	if _failures.is_empty():
		print("STATION_SURFACE_PLAYABILITY_TEST_OK")
		quit(0)
	else:
		print("STATION_SURFACE_PLAYABILITY_TEST_FAILED: ", "; ".join(_failures))
		quit(1)
