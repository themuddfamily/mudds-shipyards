extends SceneTree

const Hauler := preload("res://scripts/ships/cinder_cargo_hauler.gd")
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
	craft.queue_free()
	await process_frame
	var rebuilt := Hauler.new()
	root.add_child(rebuilt)
	await process_frame
	var rebuilt_seat_backs := rebuilt.get_node_or_null(
		^"WalkableInterior/LoadmasterCabin/CrewSeatBackBatch"
	) as MultiMeshInstance3D
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
	if _failures.is_empty():
		print("PASS cinder_cargo_hauler_test (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


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
