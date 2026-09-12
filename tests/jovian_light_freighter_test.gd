extends SceneTree

# Resolve the concrete subtype before shared HeroShip references to avoid retained script resources.
const ArrowShipType := preload("res://scripts/ships/arrow_recon_ship.gd")

const JOVIAN_SCENE := preload("res://scenes/ships/jovian_light_freighter.tscn")
const TORRENT_SCENE := preload("res://scenes/ships/torrent_interceptor.tscn")
const ARROW_SCENE := preload("res://scenes/ships/arrow_recon_ship.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

var _failures: Array[String] = []
var _test_root: Node3D


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_root = Node3D.new()
	_test_root.name = "JovianLightFreighterTestRoot"
	root.add_child(_test_root)
	var jovian := JOVIAN_SCENE.instantiate() as JovianLightFreighter
	_check(jovian != null, "Jovian scene instantiates as JovianLightFreighter")
	if jovian == null:
		_finish()
		return
	_test_root.add_child(jovian)
	await process_frame
	await physics_frame
	await physics_frame

	_test_fitout_cpu_surface_parity(jovian)
	_test_formed_roof(jovian)
	_test_formed_forward_shell(jovian)
	await _test_freighter_windscreen(jovian)
	_test_formed_aft_machinery_housing(jovian)
	_test_open_engine_module_sharing(jovian)
	_test_definition_and_evidence(jovian)
	_test_defensive_weapon_visual(jovian)
	_test_load_mark_render_allocation(jovian)
	_test_service_panel_render_allocation(jovian)
	_test_cargo_deck_lane_render_allocation(jovian)
	_test_dorsal_cargo_rib_joint_allocation(jovian)
	_test_shoulder_rail_joint_allocation(jovian)
	_test_cargo_frame_joint_allocation(jovian)
	_test_cargo_restraint_mesh_allocation(jovian)
	_test_passenger_seat_mesh_allocation(jovian)
	_test_passenger_cabin_light_strip_allocation(jovian)
	_test_landing_bogie_foot_batch(jovian)
	await _test_scale_handling_and_presentation(jovian)
	_test_connected_interior_contract(jovian)
	_test_collision_access_and_cameras(jovian)
	_test_secured_freight_is_solid(jovian)
	await _test_physical_player_traversal(jovian)
	await _test_engine_weapon_damage_and_reuse(jovian)
	await _test_interior_furnishing_ranges(jovian)
	await _test_cleanup(jovian)
	_finish()


func _test_roof_service_construction(jovian: JovianLightFreighter, lid: MeshInstance3D) -> void:
	var cabin := lid.name == "FlightDeckAvionicsBonnet"
	_check(lid.mesh.get_surface_count() == (4 if cabin else 5), "%s batches construction by finish" % lid.name)
	var seated_vertices := 0
	var outside_pressure_skin := true
	var valid_tangent_space := true
	var outward_winding := true
	for surface in lid.mesh.get_surface_count():
		var arrays := lid.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		valid_tangent_space = valid_tangent_space and tangents.size() == vertices.size() * 4
		for index in vertices.size():
			var point := vertices[index]
			var clearance := point.y - jovian._roof_service_height(point.x, point.z, cabin)
			outside_pressure_skin = outside_pressure_skin and clearance >= -0.0001 and clearance <= 0.181
			if absf(clearance) < 0.0001:
				seated_vertices += 1
		for triangle in range(0, vertices.size(), 3):
			var a := vertices[triangle]
			var b := vertices[triangle + 1]
			var c := vertices[triangle + 2]
			outward_winding = outward_winding and (b - a).cross(c - a).dot(normals[triangle]) < -0.00000001
			var uv_area := (uvs[triangle + 1] - uvs[triangle]).cross(uvs[triangle + 2] - uvs[triangle])
			valid_tangent_space = valid_tangent_space and absf(uv_area) > 0.00000001
		for tangent in tangents:
			valid_tangent_space = valid_tangent_space and is_finite(tangent)
	_check(outside_pressure_skin and seated_vertices > 100,
		"%s seats perimeter folds on the curved roof without occupying the cabin" % lid.name)
	_check(outward_winding, "%s has outward clockwise faces" % lid.name)
	_check(valid_tangent_space, "%s has nondegenerate UVs and finite generated tangents" % lid.name)


func _test_formed_aft_machinery_housing(jovian: JovianLightFreighter) -> void:
	var housing := jovian.get_jovian_visual_root().get_node("AftMachinerySpine") as MeshInstance3D
	_check(housing.mesh.get_surface_count() == 1 and housing.position == Vector3(0, 2.25, 0),
		"formed aft casing retains one material surface and the original machinery transform")
	var arrays := housing.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
	var edges := {}
	var valid_faces := true
	var valid_uvs := uvs.size() == vertices.size() and tangents.size() == vertices.size() * 4
	var nose_seated := 0
	var cover_seated := 0
	var split_seated := 0
	for triangle in range(0, vertices.size(), 3):
		var a := vertices[triangle]
		var b := vertices[triangle + 1]
		var c := vertices[triangle + 2]
		valid_faces = valid_faces and (b - a).cross(c - a).dot(normals[triangle]) < -0.00000001
		valid_uvs = valid_uvs and absf((uvs[triangle + 1] - uvs[triangle]).cross(uvs[triangle + 2] - uvs[triangle])) > 0.00000001
		for corner in 3:
			var point := vertices[triangle + corner]
			var next := vertices[triangle + (corner + 1) % 3]
			var key_a := str(Vector3i((point * 10000.0).round()))
			var key_b := str(Vector3i((next * 10000.0).round()))
			var key := key_a + ":" + key_b if key_a < key_b else key_b + ":" + key_a
			edges[key] = edges.get(key, 0) + 1
			if is_equal_approx(point.z, 8.4):
				nose_seated += 1
			if is_equal_approx(point.z, 13.32) and absf(point.x) <= 2.0801 and absf(point.y) <= 0.6001:
				cover_seated += 1
			if is_equal_approx(point.z, 11.75) or is_equal_approx(point.z, 11.83):
				split_seated += 1
	for tangent in tangents:
		valid_uvs = valid_uvs and is_finite(tangent)
	var closed := true
	for count in edges.values():
		closed = closed and count == 2
	_check(closed and valid_faces, "formed aft casing is watertight with nondegenerate outward clockwise faces")
	_check(valid_uvs, "formed aft casing has usable UV area and finite tangents across its folds and cover")
	_check(nose_seated > 100 and cover_seated > 100 and split_seated > 100,
		"aft casing keeps its forward body overlap and physically seated rear cover and service rebate")
	_check(vertices.size() == 6480, "formed aft casing stays at 2160 triangles in its existing renderer")
	var bounds := housing.mesh.get_aabb()
	_check(bounds.position.is_equal_approx(Vector3(-4.85, -1.42, 8.4))
		and bounds.end.is_equal_approx(Vector3(4.85, 1.42, 13.35)),
		"aft casing retains the authored machinery envelope clear of the freight room")


func _test_open_engine_module_sharing(jovian: JovianLightFreighter) -> void:
	var housings := jovian.find_children("*EngineHousing", "MeshInstance3D", true, false)
	_check(housings.size() == 4, "four replaceable propulsion housings remain present")
	var shared: Mesh
	for housing: MeshInstance3D in housings:
		if shared == null:
			shared = housing.mesh
		_check(housing.mesh == shared and housing.get_meta("visual_only", false),
			"propulsion cowls share their immutable visual mesh")
	_check(shared != null and shared.get_surface_count() == 2,
		"engine module retains separate armour cowl and dark cartridge surfaces")
	if shared == null:
		return
	var aperture_open := true
	for surface in shared.get_surface_count():
		var vertices: PackedVector3Array = shared.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		for triangle in range(0, vertices.size(), 3):
			var centre := (vertices[triangle] + vertices[triangle + 1] + vertices[triangle + 2]) / 3.0
			aperture_open = aperture_open and Vector2(centre.x, centre.y).length() > 0.50
	_check(aperture_open, "engine cowl and cartridge remain open along the live exhaust axis")


func _test_fitout_cpu_surface_parity(jovian: JovianLightFreighter) -> void:
	var cache: Dictionary = jovian.get("_fitout_mesh_cache")
	_check(cache.is_empty(), "construction releases decoded fitout surfaces after their final consumer")
	var materials: Dictionary = jovian.get("_jovian_materials")
	var actual: Dictionary = {}
	var expected: Dictionary = {}
	var old_cache: Dictionary = {}
	# Rotated textile padding uses a different bevel recipe. The solid batch
	# interleaves stock and deindexed rings, including repeated cache hits.
	for finish in ["cabin_cloth", "structure"]:
		var reference := SurfaceTool.new()
		reference.begin(Mesh.PRIMITIVE_TRIANGLES)
		reference.set_material(materials[finish])
		expected[finish] = reference
		for index in 3:
			var size := Vector3(0.72, 0.18, 0.63)
			var at := Vector3(index * 1.2, 0.7, -2.3)
			var rotation_value := Vector3(0.15 * index, -0.37, 0.21)
			jovian._fitout_stock(actual, finish, at, size, rotation_value)
			var stock := StationSurfaceKit.rounded_box_mesh_with_bevel(size,
				minf(0.045, minf(size.x, minf(size.y, size.z)) * 0.35)) \
				if finish == "cabin_cloth" else StationSurfaceKit.rounded_box_mesh_cached(size, old_cache)
			reference.append_from(stock, 0, Transform3D(Basis.from_euler(rotation_value), at))
			if finish == "structure":
				jovian._fitout_ring(actual, finish, at, 0.32, 0.45)
				var ring := TorusMesh.new()
				ring.inner_radius = 0.32
				ring.outer_radius = 0.45
				ring.rings = 48
				ring.ring_segments = 8
				var ring_stock := SurfaceTool.new()
				ring_stock.create_from(ring, 0)
				ring_stock.deindex()
				reference.append_from(ring_stock.commit(), 0,
					Transform3D(Basis(Vector3.RIGHT, PI * 0.5), at))
	_check(cache.size() == 3, "repeated fitout recipes share three CPU surface snapshots")
	for finish: String in expected:
		var result := (actual[finish] as SurfaceTool).commit()
		var reference := (expected[finish] as SurfaceTool).commit()
		var result_arrays := result.surface_get_arrays(0)
		var reference_arrays := reference.surface_get_arrays(0)
		var arrays_match := result_arrays.size() == reference_arrays.size()
		for channel in reference_arrays.size():
			arrays_match = arrays_match and result_arrays[channel] == reference_arrays[channel]
		_check(arrays_match,
			"cached %s fitout retains exact decoded vertices, normals, tangents, UVs and index order" % finish)
		_check(result.surface_get_material(0) == materials[finish]
			and result.get_aabb() == reference.get_aabb(),
			"cached %s fitout retains material ownership and bounds" % finish)
		_check(result_arrays[Mesh.ARRAY_INDEX] == null,
			"mixed %s fitout remains entirely unindexed" % finish)
		# Passenger fittings commit locally, then append into the cabin batch.
		# Preserve this second packing boundary and the real sideways seat pose.
		var cabin := jovian.get("_passenger_cabin") as Node3D
		var seat := cabin.get_node("PortPassengerSeat00") as Node3D
		var room_result := SurfaceTool.new()
		room_result.begin(Mesh.PRIMITIVE_TRIANGLES)
		room_result.set_material(materials[finish])
		room_result.append_from(result, 0, seat.transform)
		var room_reference := SurfaceTool.new()
		room_reference.begin(Mesh.PRIMITIVE_TRIANGLES)
		room_reference.set_material(materials[finish])
		room_reference.append_from(reference, 0, seat.transform)
		var room_mesh := room_result.commit()
		var room_expected := room_reference.commit()
		_check(room_mesh.surface_get_arrays(0) == room_expected.surface_get_arrays(0)
			and room_mesh.surface_get_material(0) == materials[finish],
			"cached %s fitout retains exact channels through the passenger room transform" % finish)
	cache.clear()


func _test_landing_bogie_foot_batch(jovian: JovianLightFreighter) -> void:
	var visual := jovian.get_jovian_visual_root()
	var batch := visual.get_node_or_null("LandingBogieFootBatch") as MultiMeshInstance3D
	var multi := batch.multimesh if batch != null else null
	var expected_transforms: Array[Transform3D] = [
		Transform3D(Basis.IDENTITY, Vector3(-5.05, -1.14, -5.8)),
		Transform3D(Basis.IDENTITY, Vector3(-5.05, -1.14, 7.3)),
		Transform3D(Basis.IDENTITY, Vector3(5.05, -1.14, -5.8)),
		Transform3D(Basis.IDENTITY, Vector3(5.05, -1.14, 7.3)),
	]
	var authored_transforms := batch.get_meta("authored_instance_transforms", []) as Array \
		if batch != null else []
	var transforms_match := authored_transforms.size() == expected_transforms.size()
	for index in mini(authored_transforms.size(), expected_transforms.size()):
		transforms_match = transforms_match and (authored_transforms[index] as Transform3D) \
			.is_equal_approx(expected_transforms[index])
	var expected_bounds := AABB()
	var foot_bounds := multi.mesh.get_aabb() if multi != null and multi.mesh != null else AABB()
	for index in expected_transforms.size():
		var transformed := expected_transforms[index] * foot_bounds
		expected_bounds = transformed if index == 0 else expected_bounds.merge(transformed)
	_check(
		batch != null
		and multi != null
		and multi.mesh is ArrayMesh
		and multi.mesh.get_aabb().size.is_equal_approx(
			JovianLightFreighter.LANDING_BOGIE_FOOT_SIZE
		)
		and multi.mesh.surface_get_material(0) == jovian.get("_jovian_materials").structure
		and multi.transform_format == MultiMesh.TRANSFORM_3D
		and not multi.use_colors
		and not multi.use_custom_data
		and multi.instance_count == JovianLightFreighter.LANDING_BOGIE_FOOT_COPY_COUNT
		and multi.visible_instance_count == -1
		and transforms_match
		and multi.buffer == jovian.call(
			"_encode_load_mark_transforms", expected_transforms
		)
		and multi.custom_aabb.is_equal_approx(expected_bounds)
		and batch.transform.is_equal_approx(Transform3D.IDENTITY)
		and batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		and batch.layers == 1
		and batch.material_override == null
		and batch.material_overlay == null
		and batch.get_child_count() == 0
		and batch.get_script() == null
		and bool(batch.get_meta("visual_detail_only", false)),
		"four visual-only landing-bogie feet retain formed geometry, material, transforms, bounds and shadow state in one batch"
	)
	_check(
		visual.find_children("LandingBogieFoot", "MeshInstance3D", true, false).is_empty()
		and batch.get_meta("authored_visual_names", PackedStringArray()) \
			== PackedStringArray([
				"LandingBogieFoot", "LandingBogieFoot",
				"LandingBogieFoot", "LandingBogieFoot",
			])
		and batch.find_children("*", "CollisionObject3D", true, false).is_empty()
		and batch.find_children("*", "Light3D", true, false).is_empty(),
		"landing-foot allocation falls from four renderer nodes, submissions and meshes to one without gaining gameplay authority"
	)

	# Godot assigns generated sibling names; identify remaining shared copies by mesh.
	var strut := visual.get_node("LandingBogieStrut") as MeshInstance3D
	var damper := visual.get_node("LandingDamper") as MeshInstance3D
	var strut_copies := 0
	var damper_copies := 0
	var fitted := true
	for child in visual.get_children():
		if not child is MeshInstance3D:
			continue
		if child.mesh == strut.mesh:
			strut_copies += 1
			var foot_origin := Vector3(signf(child.position.x) * 5.05, -1.14, child.position.z)
			# At shoe height the leg's lower shaft is enclosed by the casting;
			# its bottom also remains above the sole's original contact plane.
			var lower_tip: Vector3 = child.transform * Vector3(0, -0.75, 0)
			var entry: Vector3 = child.transform * Vector3(0, -0.34, 0) - foot_origin
			fitted = fitted and absf(entry.x) + 0.17 < 0.46 and absf(entry.z) < 0.01 \
				and lower_tip.y > -1.23 and entry.y > 0.37 and entry.y < 0.40
		elif child.mesh == damper.mesh:
			damper_copies += 1
	var formed_profile := true
	var sole_vertices := 0
	var rim_vertices := 0
	var shoe_vertices := 0
	var vertices: PackedVector3Array = multi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for point in vertices:
		formed_profile = formed_profile and point.y >= -0.09001 \
			and absf(point.x) <= 0.82501 and absf(point.z) <= 1.10001
		if absf(point.y + 0.09) < 0.0001:
			sole_vertices += 1
		if absf(point.y - 0.025) < 0.0001:
			rim_vertices += 1
		if point.y >= 0.3399:
			shoe_vertices += 1
	var pin_end_indices := 0
	var indices: PackedInt32Array = multi.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX]
	for index in indices:
		if absf(absf(vertices[index].x) - 0.61) < 0.0001 and vertices[index].y > 0.16:
			pin_end_indices += 1
	_check(pin_end_indices >= 48, "transverse shoe pin caps have submitted triangles outside both casting cheeks")
	_check(formed_profile and sole_vertices >= 24 and rim_vertices >= 24 and shoe_vertices >= 24,
		"formed landing soles retain their contact plane and footprint while supporting a rolled rim and raised shoe")
	_check(fitted and strut_copies == 4 and damper_copies == 4 \
		and multi.mesh.get_surface_count() == 1,
		"all four mirrored leg shafts fit the shared foot shoe; struts and dampers each reuse one static mesh")


func _test_definition_and_evidence(jovian: JovianLightFreighter) -> void:
	var definition := jovian.get_ship_definition()
	_check(definition != null and definition.is_definition_valid(), "Jovian owns a valid ShipDefinition")
	if definition == null:
		return
	_check(definition.get_ship_id() == &"jovian_provisional", "definition exposes stable candidate ID")
	_check(definition.get_display_name() == "Jovian-class Light Freighter candidate", "display name cannot imply authenticated geometry")
	_check(definition.get_role() == "Light freighter", "creator-supported role is preserved")
	_check(definition.get_evidence_status_id() == &"provisional" and not definition.is_authenticated(), "definition explicitly remains provisional")
	_check(definition.evidence_references.size() >= 3, "definition cites roster, register, and regeneration label")
	_check("name and light-freighter role" in definition.evidence_notes, "definition limits supported facts to name and role")
	_check("no historical name-to-model mapping" in definition.evidence_notes, "definition denies unsupported visual mapping")
	for tag in ["medium_craft", "light_freighter", "freight", "cargo"]:
		_check(definition.compatibility_tags.has(tag), "definition declares %s berth compatibility" % tag)
	_check(jovian.get_home_berth_id() == &"jovian_freight_berth", "ship publishes the freight berth ID")
	_check(jovian.get_combat_source_id() == 1103, "ship publishes the stable Jovian combat source ID")
	var clearance := jovian.get_berth_clearance_report()
	_check(str(clearance.home_berth_id) == "jovian_freight_berth" and bool(clearance.provisional), "berth clearance report is stable and explicitly provisional")
	_check((clearance.ramp_local_direction as Vector3) == Vector3.LEFT, "berth contract exposes the port-ramp approach direction")
	var evidence := jovian.get_jovian_evidence_report()
	_check(str(evidence.evidence_scope) == "name_and_role_only", "craft audit narrowly scopes its evidence")
	_check(not bool(evidence.authenticated_geometry), "craft audit denies authenticated geometry")
	_check((evidence.creator_supported as PackedStringArray).size() == 2, "audit lists exactly two creator-supported fact categories")
	_check((evidence.modern_provisional as PackedStringArray).size() >= 5, "audit inventories provisional design categories")
	var audit := jovian.get_jovian_audit_report()
	_check(bool(audit.valid) and (audit.errors as PackedStringArray).is_empty(), "constructed Jovian passes its public audit")
	_check(str(audit.weapon_class) == "freighter_defensive_pulse" and int(audit.engine_count) == 4, "audit exposes restrained weapons and quad-engine layout")
	_check(bool(jovian.get_meta("jovian_light_freighter_candidate", false)), "root metadata identifies a candidate")
	_check(not bool(jovian.get_meta("authenticated_historical_silhouette", true)), "root metadata cannot imply historical silhouette authentication")
	_check(str(jovian.get_meta("weapon_visual_status", "")) == "modern_provisional", "root metadata explicitly scopes the weapon visual as modern provisional")
	_check(not bool(jovian.get_meta("authenticated_historical_weapon", true)), "root metadata denies an authenticated historical weapon claim")


func _test_defensive_weapon_visual(jovian: JovianLightFreighter) -> void:
	var report := jovian.get_defensive_weapon_visual_report()
	var paths := report.get("component_paths", PackedStringArray()) as PackedStringArray
	_check(
		bool(report.get("valid", false))
		and str(report.get("interpretation_status", "")) == "modern_provisional"
		and str(report.get("weapon_role", "")) == "freighter_defensive"
		and not bool(report.get("authenticated_historical_weapon", true))
		and bool(report.get("visual_only", false)),
		"twin defensive fit is explicitly modern provisional, unauthenticated, and visual-only"
	)
	_check(
		int(report.get("turret_count", 0)) == 2
		and int(report.get("components_per_turret", 0)) == 7
		and paths.size() == 14,
		"defensive weapon roster contains two complete seven-part mounts"
	)
	var visual := jovian.get_jovian_visual_root()
	var expected_suffixes := PackedStringArray([
		"DefensiveTurretBase",
		"DefensiveTurretRotationCollar",
		"DefensiveTurretReceiver",
		"DefensiveTurretBarrelShroud",
		"DefensivePulseBarrel",
		"DefensiveTurretMuzzleCollar",
		"DefensiveTurretMuzzleLens",
	])
	for prefix in ["Port", "Starboard"]:
		for suffix in expected_suffixes:
			var component := visual.get_node_or_null(NodePath(prefix + suffix)) as MeshInstance3D
			_check(
				component != null
				and str(component.get_meta("interpretation_status", "")) == "modern_provisional"
				and str(component.get_meta("weapon_role", "")) == "freighter_defensive"
				and not bool(component.get_meta("authenticated_historical_weapon", true))
				and bool(component.get_meta("visual_only", false))
				and component.get_child_count() == 0,
				"%s %s is a metadata-scoped presentation-only detail" % [prefix, suffix]
			)
	for suffix in expected_suffixes:
		var port := visual.get_node(NodePath("Port" + suffix)) as MeshInstance3D
		var starboard := visual.get_node(NodePath("Starboard" + suffix)) as MeshInstance3D
		_check(port.mesh is ArrayMesh and port.mesh == starboard.mesh
			and port.mesh.get_surface_count() == 1,
			"paired %s uses one shared formed mesh and one surface per owner" % suffix)
	var receiver := visual.get_node(^"PortDefensiveTurretReceiver") as MeshInstance3D
	var bearing := visual.get_node(^"PortDefensiveTurretRotationCollar") as MeshInstance3D
	_check(bearing.position.y < receiver.position.y
		and bearing.position.y + bearing.mesh.get_aabb().end.y > receiver.position.y - 0.24,
		"the crown bearing supports and overlaps the receiver underneath the cartridge")
	var bore := visual.get_node(^"PortDefensivePulseBarrel") as MeshInstance3D
	var bore_vertices: PackedVector3Array = bore.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var front_is_open := true
	for vertex in bore_vertices:
		if is_equal_approx(vertex.y, -0.775) and Vector2(vertex.x, vertex.z).length() < 0.174:
			front_is_open = false
	_check(front_is_open, "open barrel mouth leaves the fixed teal lens firing plane free of a coplanar cap")
	var left_muzzle := jovian.get_node(^"LeftMuzzle") as Marker3D
	var right_muzzle := jovian.get_node(^"RightMuzzle") as Marker3D
	var port_lens := visual.get_node(^"PortDefensiveTurretMuzzleLens") as MeshInstance3D
	var starboard_lens := visual.get_node(^"StarboardDefensiveTurretMuzzleLens") as MeshInstance3D
	_check(
		left_muzzle.position.is_equal_approx(Vector3(-5.15, 3.76, -6.95))
		and right_muzzle.position.is_equal_approx(Vector3(5.15, 3.76, -6.95))
		and left_muzzle.get_parent() == jovian and right_muzzle.get_parent() == jovian,
		"fixed inherited muzzle markers retain their ship-root positions and authority"
	)
	_check(
		port_lens.position.x == left_muzzle.position.x
		and port_lens.position.y == left_muzzle.position.y
		and is_equal_approx(port_lens.position.z - 0.03, left_muzzle.position.z)
		and starboard_lens.position.x == right_muzzle.position.x
		and starboard_lens.position.y == right_muzzle.position.y
		and is_equal_approx(starboard_lens.position.z - 0.03, right_muzzle.position.z),
		"both muzzle-lens forward faces align exactly with the unchanged firing plane"
	)
	for prefix in ["Port", "Starboard"]:
		var base_mesh := (visual.get_node(NodePath(prefix + "DefensiveTurretBase")) as MeshInstance3D).mesh
		var barrel_mesh := (visual.get_node(NodePath(prefix + "DefensivePulseBarrel")) as MeshInstance3D).mesh
		var receiver_mesh := (visual.get_node(NodePath(prefix + "DefensiveTurretReceiver")) as MeshInstance3D).mesh
		var shroud_mesh := (visual.get_node(NodePath(prefix + "DefensiveTurretBarrelShroud")) as MeshInstance3D).mesh
		_check(
			base_mesh.get_aabb().size.is_equal_approx(Vector3(1.36, 0.38, 1.36))
			and barrel_mesh.get_aabb().size.is_equal_approx(Vector3(0.38, 1.55, 0.38))
			and receiver_mesh.get_aabb().size.is_equal_approx(Vector3(0.76, 0.48, 0.7))
			and shroud_mesh.get_aabb().size.is_equal_approx(Vector3(0.56, 0.46, 0.72)),
			"%s defensive mount keeps the frozen freighter-scale base, barrel, receiver, and shroud dimensions" % prefix
		)


func _test_load_mark_render_allocation(jovian: JovianLightFreighter) -> void:
	var audit := jovian.get_load_mark_render_audit()
	var current := audit.get("current", {}) as Dictionary
	var legacy := audit.get("legacy", {}) as Dictionary
	var delta := audit.get("delta", {}) as Dictionary
	var visual := jovian.get_node_or_null(^"JovianFreighterVisual") as Node3D
	var batch := visual.get_node_or_null(^"LoadMarkBatch") as MultiMeshInstance3D if visual != null else null
	_check(
		bool(audit.get("valid", false))
			and int(legacy.get("renderer_nodes", 0)) == 6
			and int(legacy.get("submissions", 0)) == 6
			and int(current.get("renderer_nodes", 0)) == 1
			and int(current.get("submissions", 0)) == 1
			and int(current.get("copies", 0)) == 6
			and int(delta.get("renderer_nodes", 0)) == -5
			and int(delta.get("submissions", 0)) == -5,
		"six exterior amber load marks batch from six renderer nodes/submissions to one without losing a visible copy"
	)
	_check(
		batch != null and batch.multimesh != null
			and batch.multimesh.instance_count == JovianLightFreighter.LOAD_MARK_COPY_COUNT
			and batch.get_child_count() == 0
			and bool(batch.get_meta("visual_detail_only", false)),
		"load-mark batch remains childless visual-only presentation"
	)
	if batch == null or batch.multimesh == null:
		return
	var transforms := audit.get("authored_transforms", []) as Array
	_check(
		transforms.size() == 6
			and (transforms[0] as Transform3D).origin.is_equal_approx(Vector3(-7.88, 1.15, -1.3))
			and (transforms[5] as Transform3D).origin.is_equal_approx(Vector3(7.88, 1.15, 0.9)),
		"batched load marks retain the frozen port-to-starboard authored transform roster"
	)
	var original_buffer := batch.multimesh.buffer.duplicate()
	var mutated_buffer := original_buffer.duplicate()
	mutated_buffer[3] += 0.1
	batch.multimesh.buffer = mutated_buffer
	_check(
		not bool(jovian.get_load_mark_render_audit().get("valid", true)),
		"RED: mutating a live load-mark transform buffer fails the render allocation audit"
	)
	batch.multimesh.buffer = original_buffer
	_check(
		bool(jovian.get_load_mark_render_audit().get("valid", false)),
		"restoring the load-mark transform buffer returns the render allocation audit green"
	)


func _test_service_panel_render_allocation(jovian: JovianLightFreighter) -> void:
	var audit := jovian.get_service_panel_render_audit()
	var current := audit.get("current", {}) as Dictionary
	var legacy := audit.get("legacy", {}) as Dictionary
	var delta := audit.get("delta", {}) as Dictionary
	var visual := jovian.get_node_or_null(^"JovianFreighterVisual") as Node3D
	var batch := visual.get_node_or_null(^"ServicePanelBatch") as MultiMeshInstance3D \
		if visual != null else null
	var transforms := audit.get("authored_transforms", []) as Array
	_check(
		bool(audit.get("valid", false))
			and int(legacy.get("renderer_nodes", 0)) == 7
			and int(legacy.get("submissions", 0)) == 7
			and int(current.get("renderer_nodes", 0)) == 1
			and int(current.get("submissions", 0)) == 1
			and int(current.get("copies", 0)) == 7
			and int(delta.get("renderer_nodes", 0)) == -6
			and int(delta.get("submissions", 0)) == -6,
		"seven visual-only shoulder service panels batch to one renderer/submission"
	)
	_check(
		batch != null and batch.multimesh != null
			and batch.get_child_count() == 0
			and bool(batch.get_meta("visual_detail_only", false))
			and transforms.size() == 7
			and (transforms[0] as Transform3D).origin.is_equal_approx(
				Vector3(-8.04, 2.12, -4.1)
			)
			and (transforms[2] as Transform3D).origin.is_equal_approx(
				Vector3(-8.04, 2.12, 7.15)
			)
			and (transforms[6] as Transform3D).origin.is_equal_approx(
				Vector3(8.04, 2.12, 7.15)
			),
		"service-panel batch preserves the exact authored transforms and no authority"
	)
	if batch == null or batch.multimesh == null:
		return
	var original_buffer := batch.multimesh.buffer.duplicate()
	var mutated_buffer := original_buffer.duplicate()
	mutated_buffer[3] += 0.1
	batch.multimesh.buffer = mutated_buffer
	_check(
		not bool(jovian.get_service_panel_render_audit().get("valid", true)),
		"RED: mutating a live service-panel transform fails its focused audit"
	)
	batch.multimesh.buffer = original_buffer


func _test_cargo_deck_lane_render_allocation(jovian: JovianLightFreighter) -> void:
	var audit := jovian.get_cargo_deck_lane_render_audit()
	var current := audit.get("current", {}) as Dictionary
	var delta := audit.get("delta", {}) as Dictionary
	var cargo_bay := jovian.get_node_or_null(^"WalkableInterior/CargoBay") as Node3D
	var batch := cargo_bay.get_node_or_null(^"CargoDeckLaneBatch") as MultiMeshInstance3D \
		if cargo_bay != null else null
	_check(
		bool(audit.get("valid", false))
			and int(current.get("renderer_nodes", 0)) == 1
			and int(current.get("submissions", 0)) == 1
			and int(current.get("copies", 0)) == 3
			and int(delta.get("renderer_nodes", 0)) == -2
			and int(delta.get("submissions", 0)) == -2,
		"three cargo-deck lane inlays batch to one renderer/submission without losing a copy"
	)
	_check(
		batch != null and batch.multimesh != null
			and batch.get_child_count() == 0
			and bool(batch.get_meta("visual_detail_only", false))
			and (audit.get("authored_transforms", []) as Array) == [
				Transform3D(Basis.IDENTITY, Vector3(-2.15, 0.61, 3.15)),
				Transform3D(Basis.IDENTITY, Vector3(0.0, 0.61, 3.15)),
				Transform3D(Basis.IDENTITY, Vector3(2.15, 0.61, 3.15)),
			],
		"cargo-deck lane batch preserves its exact moving-interior transforms and visual-only authority"
	)
	if batch == null or batch.multimesh == null:
		return
	var original_buffer := batch.multimesh.buffer.duplicate()
	var mutated_buffer := original_buffer.duplicate()
	mutated_buffer[3] += 0.1
	batch.multimesh.buffer = mutated_buffer
	_check(
		not bool(jovian.get_cargo_deck_lane_render_audit().get("valid", true)),
		"RED: mutating one live cargo-deck lane transform fails its focused audit"
	)
	batch.multimesh.buffer = original_buffer


func _test_cargo_restraint_mesh_allocation(jovian: JovianLightFreighter) -> void:
	var audit := jovian.get_cargo_restraint_mesh_allocation_audit()
	var current := audit.get("current", {}) as Dictionary
	var legacy := audit.get("legacy", {}) as Dictionary
	var delta := audit.get("delta", {}) as Dictionary
	_check(
		bool(audit.get("valid", false))
			and legacy == {
				"geometry_nodes": 8,
				"named_nodes": 8,
				"drawn_copies": 8,
				"geometry_submissions": 8,
				"mesh_resource_allocations": 8,
				"material_resource_allocations": 1,
				"multimesh_batches": 0,
			}
			and current == {
				"geometry_nodes": 8,
				"named_nodes": 8,
				"drawn_copies": 8,
				"geometry_submissions": 8,
				"mesh_resource_allocations": 1,
				"material_resource_allocations": 1,
				"multimesh_batches": 0,
			}
			and delta == {
				"geometry_nodes": 0,
				"drawn_copies": 0,
				"geometry_submissions": 0,
				"mesh_resource_allocations": -7,
				"material_resource_allocations": 0,
			}
			and not bool(audit.get("batched", true))
			and not bool(audit.get("collision_authority", true))
			and not bool(audit.get("crew_authority", true))
			and not bool(audit.get("cargo_authority", true))
			and not bool(audit.get("flight_authority", true))
			and not bool(audit.get("lifecycle_authority", true)),
		"eight named cargo restraints retain eight submissions while exact mesh allocations fall 8 -> 1"
	)
	var cargo_bay := jovian.get_node(^"WalkableInterior/CargoBay") as Node3D
	var first := cargo_bay.get_node(^"CargoRestraintPort0000") as MeshInstance3D
	var last := cargo_bay.get_node(^"CargoRestraintStarboard0101") as MeshInstance3D
	_check(
		first.mesh == last.mesh
			and first.mesh is ArrayMesh
			and first.position.is_equal_approx(Vector3(-3.75, 2.26, -0.39))
			and last.position.is_equal_approx(Vector3(3.75, 2.26, 6.19))
			and jovian.get_node_or_null(^"CargoContainerCollisionPort00")
				is CollisionShape3D
			and jovian.get_node_or_null(^"CargoContainerCollisionStarboard01")
				is CollisionShape3D,
		"restraint sharing preserves exact endpoint names/transforms and separate secured-freight collision"
	)
	var retained := last.mesh
	last.mesh = (retained as ArrayMesh).duplicate() as ArrayMesh
	_check(
		not bool(jovian.get_cargo_restraint_mesh_allocation_audit().get("valid", true))
			and _has_error(
				jovian.get_cargo_restraint_mesh_allocation_audit(),
				"cargo_restraint_recipe_or_authority_drift:CargoRestraintStarboard0101"
			),
		"RED: one private cargo-restraint mesh fails the exact shared-resource audit"
	)
	last.mesh = retained
	_check(
		bool(jovian.get_cargo_restraint_mesh_allocation_audit().get("valid", false))
			and bool(jovian.get_jovian_audit_report().get("valid", false)),
		"restoring the shared cargo-restraint mesh returns the Jovian audit green"
	)


func _test_passenger_seat_mesh_allocation(jovian: JovianLightFreighter) -> void:
	var audit := jovian.get_passenger_seat_mesh_allocation_audit()
	var current := audit.get("current", {}) as Dictionary
	var legacy := audit.get("legacy", {}) as Dictionary
	var delta := audit.get("delta", {}) as Dictionary
	_check(
		bool(audit.get("valid", false))
		and int(current.get("nodes", 0)) == 18
		and int(current.get("copies", 0)) == 18
		and int(current.get("submissions", 0)) == 18
		and int(current.get("mesh_resource_allocations", 0)) == 3
		and int(legacy.get("mesh_resource_allocations", 0)) == 18
		and int(delta.get("mesh_resource_allocations", 0)) == -15
		and not bool(audit.get("batched", true))
		and not bool(audit.get("collision_authority", true)),
		"six fitted passenger seats retain 18 shared visual copies/submissions while exact mesh allocations fall 18 -> 3"
	)


	var cabin := jovian.get_node(^"WalkableInterior/PassengerCabin") as Node3D
	var port_base := cabin.get_node(^"PortPassengerSeat00/SeatBase") as MeshInstance3D
	var starboard_base := cabin.get_node(^"StarboardPassengerSeat02/SeatBase") as MeshInstance3D
	var port_back := cabin.get_node(^"PortPassengerSeat00/SeatBack") as MeshInstance3D
	var starboard_back := cabin.get_node(^"StarboardPassengerSeat02/SeatBack") as MeshInstance3D
	var port_harness := cabin.get_node(^"PortPassengerSeat00/Harness") as MeshInstance3D
	var starboard_harness := cabin.get_node(^"StarboardPassengerSeat02/Harness") as MeshInstance3D
	_check(
		port_base.mesh == starboard_base.mesh
		and port_back.mesh == starboard_back.mesh
		and port_harness.mesh == starboard_harness.mesh
		and port_base.mesh != port_back.mesh and port_back.mesh != port_harness.mesh
		and cabin.get_node(^"PortPassengerSeat00/PassengerAnchor") is Marker3D
		and cabin.get_node(^"StarboardPassengerSeat02/PassengerAnchor") is Marker3D,
		"seat family sharing preserves exact named visual paths and independent passenger anchors"
	)
	for anchor in jovian.get_passenger_seat_anchors():
		var station := anchor.get_parent() as Node3D
		var local_at := jovian.to_local(anchor.global_position)
		var facing := jovian.global_basis.inverse() * -anchor.global_basis.z
		_check(facing.dot(Vector3(-signf(local_at.x), 0, 0)) > 0.99
			and is_equal_approx(absf(local_at.x), 2.64),
			"passenger station faces the aisle and retains its ship-local centre: " + String(station.name))
		for part in ["SeatBase", "SeatBack"]:
			var visual := station.get_node(part) as MeshInstance3D
			var shape_node := jovian.get_node(String(station.name) + part + "Collision") as CollisionShape3D
			var shape := shape_node.shape as BoxShape3D
			var bounds := visual.mesh.get_aabb()
			_check(shape.size.is_equal_approx(bounds.size)
				and shape_node.global_transform.is_equal_approx(visual.global_transform * Transform3D(Basis.IDENTITY, bounds.get_center())),
				"passenger furniture collider follows the fitted cushion/back: " + String(station.name) + part)
		var ray := PhysicsRayQueryParameters3D.create(
			jovian.to_global(Vector3(0, 1.42, local_at.z)),
			jovian.to_global(Vector3(signf(local_at.x) * 3.16, 1.42, local_at.z)),
			PhysicsLayers.SHIP_BODY_LAYER)
		var hit := jovian.get_world_3d().direct_space_state.intersect_ray(ray)
		_check(not hit.is_empty() and hit.get("collider") == jovian
			and absf(jovian.to_local(hit.get("position", Vector3.ZERO)).x) < 3.1,
			"physical aisle probe meets the passenger back before the pressure wall: " + String(station.name))
	var retained := starboard_base.mesh
	starboard_base.mesh = (retained as ArrayMesh).duplicate() as ArrayMesh
	_check(
		not bool(jovian.get_passenger_seat_mesh_allocation_audit().get("valid", true))
		and _has_error(jovian.get_passenger_seat_mesh_allocation_audit(), "passenger_seat_recipe_or_authority_drift:StarboardPassengerSeat02/SeatBase"),
		"RED: one private passenger-seat mesh fails the exact shared-resource audit"
	)
	starboard_base.mesh = retained
	_check(
		bool(jovian.get_passenger_seat_mesh_allocation_audit().get("valid", false)),
		"restoring the shared passenger-seat mesh returns the Jovian audit green"
	)


func _test_passenger_cabin_light_strip_allocation(jovian: JovianLightFreighter) -> void:
	var audit := jovian.get_passenger_cabin_light_strip_allocation_audit()
	var current := audit.get("current", {}) as Dictionary
	var legacy := audit.get("legacy", {}) as Dictionary
	var delta := audit.get("delta", {}) as Dictionary
	_check(
		bool(audit.get("valid", false))
		and int(current.get("nodes", 0)) == 2
		and int(current.get("copies", 0)) == 2
		and int(current.get("submissions", 0)) == 2
		and int(current.get("mesh_resource_allocations", 0)) == 1
		and int(legacy.get("mesh_resource_allocations", 0)) == 2
		and int(delta.get("mesh_resource_allocations", 0)) == -1
		and not bool(audit.get("batched", true))
		and not bool(audit.get("collision_authority", true)),
		"two passenger-cabin light strips retain their nodes/copies/submissions while one rounded mesh replaces two"
	)
	var cabin := jovian.get_node(^"WalkableInterior/PassengerCabin") as Node3D
	var port_strip := _passenger_cabin_light_strip_at(cabin, -3.23)
	var starboard_strip := _passenger_cabin_light_strip_at(cabin, 3.23)
	_check(
		port_strip != null and starboard_strip != null,
		"the frozen port/starboard direct-child transforms resolve both cabin light strips"
	)
	if port_strip == null or starboard_strip == null:
		return
	_check(
		port_strip.mesh == starboard_strip.mesh
		and port_strip.mesh is ArrayMesh
		and (port_strip.mesh as ArrayMesh).surface_get_material(0) != null
		and port_strip.position.is_equal_approx(Vector3(-3.23, 3.46, -5.25))
		and starboard_strip.position.is_equal_approx(Vector3(3.23, 3.46, -5.25))
		and port_strip.get_child_count() == 0 and starboard_strip.get_child_count() == 0,
		"cabin light-strip sharing preserves the inherited rounded recipe and both authored paths/transforms"
	)
	var retained := starboard_strip.mesh
	starboard_strip.mesh = (retained as ArrayMesh).duplicate() as ArrayMesh
	_check(
		not bool(jovian.get_passenger_cabin_light_strip_allocation_audit().get("valid", true))
		and _has_error(jovian.get_passenger_cabin_light_strip_allocation_audit(), "passenger_cabin_light_strip_recipe_or_authority_drift:Starboard"),
		"RED: a private passenger-cabin light-strip mesh fails the exact shared-resource audit"
	)
	starboard_strip.mesh = retained
	_check(
		bool(jovian.get_passenger_cabin_light_strip_allocation_audit().get("valid", false)),
		"restoring the shared passenger-cabin light-strip mesh returns the Jovian audit green"
	)


func _passenger_cabin_light_strip_at(cabin: Node3D, x: float) -> MeshInstance3D:
	for child in cabin.get_children():
		if (
			child is MeshInstance3D
			and is_equal_approx((child as MeshInstance3D).position.x, x)
			and is_equal_approx((child as MeshInstance3D).position.y, 3.46)
			and is_equal_approx((child as MeshInstance3D).position.z, -5.25)
		):
			return child as MeshInstance3D
	return null


func _test_dorsal_cargo_rib_joint_allocation(jovian: JovianLightFreighter) -> void:
	var audit := jovian.get_dorsal_cargo_rib_joint_allocation_audit()
	if not bool(audit.get("valid", false)):
		print("JOVIAN_DORSAL_RIB_ALLOCATION_ERRORS: ", audit.get("errors", PackedStringArray()))
	_check(
		bool(audit.get("valid", false)),
		"Jovian dorsal-rib joint allocation audit is green"
	)
	var current := audit.get("current", {}) as Dictionary
	var legacy := audit.get("legacy", {}) as Dictionary
	var delta := audit.get("delta", {}) as Dictionary
	_check(
		legacy == {
			"geometry_nodes": 25,
			"named_nodes": 25,
			"drawn_copies": 25,
			"geometry_submissions": 25,
			"mesh_resource_allocations": 25,
			"material_resource_allocations": 1,
			"multimesh_batches": 0,
		}
		and current == {
			"geometry_nodes": 25,
			"named_nodes": 25,
			"drawn_copies": 25,
			"geometry_submissions": 25,
			"mesh_resource_allocations": 1,
			"material_resource_allocations": 1,
			"multimesh_batches": 0,
		}
		and delta == {
			"geometry_nodes": 0,
			"drawn_copies": 0,
			"geometry_submissions": 0,
			"mesh_resource_allocations": -24,
			"material_resource_allocations": 0,
		},
		"25 named nodes/copies/submissions retain one mesh instead of 25"
	)
	_check(
		int(audit.get("descendant_node_count", -1)) == 0
		and int(audit.get("collision_object_count", -1)) == 0
		and int(audit.get("collision_shape_count", -1)) == 0
		and int(audit.get("interaction_area_count", -1)) == 0
		and int(audit.get("marker_count", -1)) == 0
		and int(audit.get("metadata_entry_count", -1)) == 0
		and int(audit.get("scripted_node_count", -1)) == 0
		and int(audit.get("grouped_node_count", -1)) == 0
		and int(audit.get("processing_node_count", -1)) == 0
		and not bool(audit.get("batched", true))
		and not bool(audit.get("driver_draw_call_claimed", true))
		and not bool(audit.get("frame_time_claimed", true))
		and not bool(audit.get("vram_claimed", true)),
		"shared joints retain renderer submissions and zero semantic, collision, interaction, evidence, or lifecycle authority"
	)

	(current as Dictionary)["geometry_nodes"] = -1
	(audit.get("behavior_rows", []) as Array).clear()
	(audit.get("errors", PackedStringArray()) as PackedStringArray).append("caller_mutation")
	var detached := jovian.get_dorsal_cargo_rib_joint_allocation_audit()
	_check(
		int((detached.get("current", {}) as Dictionary).get("geometry_nodes", 0)) == 25
		and (detached.get("behavior_rows", []) as Array).size() == 25
		and not (detached.get("errors", PackedStringArray()) as PackedStringArray).has(
			"caller_mutation"
		),
		"dorsal-rib allocation evidence is deeply detached"
	)

	var visual := jovian.get_jovian_visual_root()
	var first_rib := visual.get_node(^"DorsalCargoRib00") as Node3D
	var last_rib := visual.get_node(^"DorsalCargoRib04") as Node3D
	var first_joint := first_rib.get_node(^"CurveJoint") as MeshInstance3D
	var last_joint: MeshInstance3D = null
	for child in last_rib.get_children():
		var candidate := child as MeshInstance3D
		if candidate != null and candidate.mesh is SphereMesh:
			last_joint = candidate
	var shared_mesh := first_joint.mesh as SphereMesh
	_check(
		shared_mesh != null and last_joint != null and last_joint.mesh == shared_mesh,
		"all five ribs resolve their 25 joints through one exact SphereMesh"
	)

	last_joint.mesh = shared_mesh.duplicate() as SphereMesh
	var identity_red := jovian.get_dorsal_cargo_rib_joint_allocation_audit()
	_check(
		not bool(identity_red.get("valid", true))
		and int((identity_red.get("current", {}) as Dictionary).get(
			"mesh_resource_allocations", 0
		)) == 2
		and _has_error_prefix(identity_red, "dorsal_rib_joint_mesh_identity_drift:")
		and _has_error(identity_red, "dorsal_rib_joint_mesh_resource_count_drift"),
		"structured red: one private exact-looking joint mesh invalidates shared identity"
	)
	last_joint.mesh = shared_mesh

	var original_rings := shared_mesh.rings
	shared_mesh.rings = original_rings - 1
	var recipe_red := jovian.get_dorsal_cargo_rib_joint_allocation_audit()
	_check(
		not bool(recipe_red.get("valid", true))
		and _has_error_prefix(recipe_red, "dorsal_rib_joint_mesh_recipe_drift:"),
		"structured red: shared sphere recipe drift is visible through the live family"
	)
	shared_mesh.rings = original_rings

	var rogue_area := Area3D.new()
	rogue_area.name = "RogueRibInteractionAuthority"
	rogue_area.set_meta(&"evidence_status", &"unregistered")
	var rogue_shape := CollisionShape3D.new()
	rogue_shape.name = "RogueRibCollision"
	rogue_shape.shape = SphereShape3D.new()
	rogue_area.add_child(rogue_shape)
	last_joint.add_child(rogue_area)
	var authority_red := jovian.get_dorsal_cargo_rib_joint_allocation_audit()
	_check(
		not bool(authority_red.get("valid", true))
		and int(authority_red.get("descendant_node_count", 0)) == 2
		and int(authority_red.get("collision_object_count", 0)) == 1
		and int(authority_red.get("collision_shape_count", 0)) == 1
		and int(authority_red.get("interaction_area_count", 0)) == 1
		and int(authority_red.get("metadata_entry_count", 0)) == 1
		and _has_error(authority_red, "dorsal_rib_joint_gained_children")
		and _has_error(
			authority_red,
			"dorsal_rib_joint_gained_collision_or_interaction_authority"
		)
		and _has_error(authority_red, "dorsal_rib_joint_gained_evidence_metadata"),
		"structured red: collision, interaction, or evidence authority cannot hide under a shared joint"
	)
	last_joint.remove_child(rogue_area)
	rogue_area.free()
	_check(
		bool(jovian.get_dorsal_cargo_rib_joint_allocation_audit().get("valid", false))
		and bool(jovian.get_jovian_audit_report().get("valid", false)),
		"identity, recipe, and authority mutations restore the component audit to green"
	)


func _test_shoulder_rail_joint_allocation(jovian: JovianLightFreighter) -> void:
	var audit := jovian.get_shoulder_rail_joint_allocation_audit()
	if not bool(audit.get("valid", false)):
		print("JOVIAN_SHOULDER_RAIL_ALLOCATION_ERRORS: ", audit.get(
			"errors", PackedStringArray()
		))
	_check(bool(audit.get("valid", false)), "Jovian shoulder-rail joint allocation audit is green")
	var current := audit.get("current", {}) as Dictionary
	var legacy := audit.get("legacy", {}) as Dictionary
	var delta := audit.get("delta", {}) as Dictionary
	_check(
		legacy == {
			"geometry_nodes": 7,
			"named_nodes": 7,
			"drawn_copies": 7,
			"geometry_submissions": 7,
			"mesh_resource_allocations": 7,
			"material_resource_allocations": 1,
			"multimesh_batches": 0,
		}
		and current == {
			"geometry_nodes": 7,
			"named_nodes": 7,
			"drawn_copies": 7,
			"geometry_submissions": 7,
			"mesh_resource_allocations": 1,
			"material_resource_allocations": 1,
			"multimesh_batches": 0,
		}
		and delta == {
			"geometry_nodes": 0,
			"drawn_copies": 0,
			"geometry_submissions": 0,
			"mesh_resource_allocations": -6,
			"material_resource_allocations": 0,
		},
		"seven named nodes/copies/submissions retain one mesh instead of seven"
	)
	_check(
		int(audit.get("descendant_node_count", -1)) == 0
		and int(audit.get("collision_object_count", -1)) == 0
		and int(audit.get("collision_shape_count", -1)) == 0
		and int(audit.get("interaction_area_count", -1)) == 0
		and int(audit.get("marker_count", -1)) == 0
		and int(audit.get("metadata_entry_count", -1)) == 0
		and int(audit.get("scripted_node_count", -1)) == 0
		and int(audit.get("grouped_node_count", -1)) == 0
		and int(audit.get("processing_node_count", -1)) == 0
		and not bool(audit.get("batched", true))
		and not bool(audit.get("driver_draw_call_claimed", true))
		and not bool(audit.get("frame_time_claimed", true))
		and not bool(audit.get("vram_claimed", true)),
		"shared shoulder joints retain renderer submissions and zero authority"
	)

	(current as Dictionary)["geometry_nodes"] = -1
	(audit.get("behavior_rows", []) as Array).clear()
	(audit.get("errors", PackedStringArray()) as PackedStringArray).append("caller_mutation")
	var detached := jovian.get_shoulder_rail_joint_allocation_audit()
	_check(
		int((detached.get("current", {}) as Dictionary).get("geometry_nodes", 0)) == 7
		and (detached.get("behavior_rows", []) as Array).size() == 7
		and not (detached.get("errors", PackedStringArray()) as PackedStringArray).has(
			"caller_mutation"
		),
		"shoulder-rail allocation evidence is deeply detached"
	)

	var visual := jovian.get_jovian_visual_root()
	var first_rail := visual.get_node(^"PortForwardShoulderRail") as Node3D
	var last_rail := visual.get_node(^"StarboardShoulderRail") as Node3D
	var first_joint := first_rail.get_node(^"CurveJoint") as MeshInstance3D
	var last_joint: MeshInstance3D = null
	for child in last_rail.get_children():
		var candidate := child as MeshInstance3D
		if candidate != null and candidate.mesh is SphereMesh:
			last_joint = candidate
	var shared_mesh := first_joint.mesh as SphereMesh
	_check(
		shared_mesh != null and last_joint != null and last_joint.mesh == shared_mesh,
		"all three shoulder rails resolve seven joints through one exact SphereMesh"
	)

	last_joint.mesh = shared_mesh.duplicate() as SphereMesh
	var identity_red := jovian.get_shoulder_rail_joint_allocation_audit()
	_check(
		not bool(identity_red.get("valid", true))
		and int((identity_red.get("current", {}) as Dictionary).get(
			"mesh_resource_allocations", 0
		)) == 2
		and _has_error_prefix(identity_red, "shoulder_rail_joint_mesh_identity_drift:")
		and _has_error(identity_red, "shoulder_rail_joint_mesh_resource_count_drift"),
		"structured red: one private exact-looking shoulder mesh invalidates shared identity"
	)
	last_joint.mesh = shared_mesh

	var original_rings := shared_mesh.rings
	shared_mesh.rings = original_rings - 1
	var recipe_red := jovian.get_shoulder_rail_joint_allocation_audit()
	_check(
		not bool(recipe_red.get("valid", true))
		and _has_error_prefix(recipe_red, "shoulder_rail_joint_mesh_recipe_drift:"),
		"structured red: shared shoulder sphere recipe drift is visible"
	)
	shared_mesh.rings = original_rings

	var original_layers := last_joint.layers
	last_joint.layers = 2
	var renderer_red := jovian.get_shoulder_rail_joint_allocation_audit()
	_check(
		not bool(renderer_red.get("valid", true))
		and _has_error_prefix(renderer_red, "shoulder_rail_joint_renderer_recipe_drift:"),
		"structured red: shoulder renderer-state drift is visible"
	)
	last_joint.layers = original_layers

	var rogue_area := Area3D.new()
	rogue_area.name = "RogueShoulderRailInteractionAuthority"
	rogue_area.set_meta(&"evidence_status", &"unregistered")
	var rogue_shape := CollisionShape3D.new()
	rogue_shape.name = "RogueShoulderRailCollision"
	rogue_shape.shape = SphereShape3D.new()
	rogue_area.add_child(rogue_shape)
	last_joint.add_child(rogue_area)
	var authority_red := jovian.get_shoulder_rail_joint_allocation_audit()
	_check(
		not bool(authority_red.get("valid", true))
		and int(authority_red.get("descendant_node_count", 0)) == 2
		and int(authority_red.get("collision_object_count", 0)) == 1
		and int(authority_red.get("collision_shape_count", 0)) == 1
		and int(authority_red.get("interaction_area_count", 0)) == 1
		and int(authority_red.get("metadata_entry_count", 0)) == 1
		and _has_error(authority_red, "shoulder_rail_joint_gained_children")
		and _has_error(
			authority_red,
			"shoulder_rail_joint_gained_collision_or_interaction_authority"
		)
		and _has_error(authority_red, "shoulder_rail_joint_gained_evidence_metadata"),
		"structured red: authority cannot hide under a shared shoulder joint"
	)
	last_joint.remove_child(rogue_area)
	rogue_area.free()
	_check(
		bool(jovian.get_shoulder_rail_joint_allocation_audit().get("valid", false))
		and bool(jovian.get_jovian_audit_report().get("valid", false)),
		"shoulder identity, recipe, renderer, and authority mutations restore to green"
	)


func _test_cargo_frame_joint_allocation(jovian: JovianLightFreighter) -> void:
	var audit := jovian.get_cargo_frame_joint_allocation_audit()
	if not bool(audit.get("valid", false)):
		print("JOVIAN_CARGO_FRAME_ALLOCATION_ERRORS: ", audit.get(
			"errors", PackedStringArray()
		))
	_check(bool(audit.get("valid", false)), "Jovian cargo-frame joint allocation audit is green")
	var current := audit.get("current", {}) as Dictionary
	var legacy := audit.get("legacy", {}) as Dictionary
	var delta := audit.get("delta", {}) as Dictionary
	_check(
		legacy == {
			"geometry_nodes": 20,
			"named_nodes": 20,
			"drawn_copies": 20,
			"geometry_submissions": 20,
			"mesh_resource_allocations": 20,
			"material_resource_allocations": 1,
			"multimesh_batches": 0,
		}
		and current == {
			"geometry_nodes": 20,
			"named_nodes": 20,
			"drawn_copies": 20,
			"geometry_submissions": 20,
			"mesh_resource_allocations": 1,
			"material_resource_allocations": 1,
			"multimesh_batches": 0,
		}
		and delta == {
			"geometry_nodes": 0,
			"drawn_copies": 0,
			"geometry_submissions": 0,
			"mesh_resource_allocations": -19,
			"material_resource_allocations": 0,
		},
		"20 named moving-interior joints retain one mesh instead of 20"
	)
	_check(
		bool(audit.get("moving_interior_attached", false))
		and int(audit.get("descendant_node_count", -1)) == 0
		and int(audit.get("collision_object_count", -1)) == 0
		and int(audit.get("collision_shape_count", -1)) == 0
		and int(audit.get("interaction_area_count", -1)) == 0
		and int(audit.get("marker_count", -1)) == 0
		and int(audit.get("metadata_entry_count", -1)) == 0
		and int(audit.get("scripted_node_count", -1)) == 0
		and int(audit.get("grouped_node_count", -1)) == 0
		and int(audit.get("processing_node_count", -1)) == 0
		and not bool(audit.get("batched", true))
		and not bool(audit.get("driver_draw_call_claimed", true))
		and not bool(audit.get("frame_time_claimed", true))
		and not bool(audit.get("vram_claimed", true)),
		"shared cargo-frame joints stay attached to the moving interior with unchanged submissions and zero authority"
	)

	(current as Dictionary)["geometry_nodes"] = -1
	(audit.get("behavior_rows", []) as Array).clear()
	(audit.get("errors", PackedStringArray()) as PackedStringArray).append("caller_mutation")
	var detached := jovian.get_cargo_frame_joint_allocation_audit()
	_check(
		int((detached.get("current", {}) as Dictionary).get("geometry_nodes", 0)) == 20
		and (detached.get("behavior_rows", []) as Array).size() == 20
		and not (detached.get("errors", PackedStringArray()) as PackedStringArray).has(
			"caller_mutation"
		),
		"cargo-frame allocation evidence is deeply detached"
	)

	var cargo_bay := jovian.get_node(^"WalkableInterior/CargoBay") as Node3D
	var first_frame := cargo_bay.get_node(^"CargoFrame00") as Node3D
	var last_frame := cargo_bay.get_node(^"CargoFrame03") as Node3D
	var first_joint := first_frame.get_node(^"CurveJoint") as MeshInstance3D
	var last_joint: MeshInstance3D = null
	for child in last_frame.get_children():
		var candidate := child as MeshInstance3D
		if candidate != null and candidate.mesh is SphereMesh:
			last_joint = candidate
	var shared_mesh := first_joint.mesh as SphereMesh
	_check(
		shared_mesh != null and last_joint != null and last_joint.mesh == shared_mesh,
		"all four cargo frames resolve their 20 joints through one exact SphereMesh"
	)

	last_joint.mesh = shared_mesh.duplicate() as SphereMesh
	var identity_red := jovian.get_cargo_frame_joint_allocation_audit()
	_check(
		not bool(identity_red.get("valid", true))
		and int((identity_red.get("current", {}) as Dictionary).get(
			"mesh_resource_allocations", 0
		)) == 2
		and _has_error_prefix(identity_red, "cargo_frame_joint_mesh_identity_drift:")
		and _has_error(identity_red, "cargo_frame_joint_mesh_resource_count_drift"),
		"structured red: one private exact-looking cargo-frame mesh invalidates shared identity"
	)
	last_joint.mesh = shared_mesh

	var original_rings := shared_mesh.rings
	shared_mesh.rings = original_rings - 1
	var recipe_red := jovian.get_cargo_frame_joint_allocation_audit()
	_check(
		not bool(recipe_red.get("valid", true))
		and _has_error_prefix(recipe_red, "cargo_frame_joint_mesh_recipe_drift:"),
		"structured red: shared cargo-frame sphere recipe drift is visible"
	)
	shared_mesh.rings = original_rings

	var original_layers := last_joint.layers
	last_joint.layers = 2
	var renderer_red := jovian.get_cargo_frame_joint_allocation_audit()
	_check(
		not bool(renderer_red.get("valid", true))
		and _has_error_prefix(renderer_red, "cargo_frame_joint_renderer_recipe_drift:"),
		"structured red: cargo-frame renderer-state drift is visible"
	)
	last_joint.layers = original_layers

	var interior := jovian.get_interior_root()
	cargo_bay.reparent(jovian, false)
	var moving_interior_red := jovian.get_cargo_frame_joint_allocation_audit()
	_check(
		not bool(moving_interior_red.get("valid", true))
		and not bool(moving_interior_red.get("moving_interior_attached", true))
		and _has_error(
			moving_interior_red,
			"cargo_frame_moving_interior_attachment_drift"
		),
		"structured red: cargo frames cannot detach from the physical moving interior"
	)
	cargo_bay.reparent(interior, false)

	var rogue_area := Area3D.new()
	rogue_area.name = "RogueCargoFrameInteractionAuthority"
	rogue_area.set_meta(&"evidence_status", &"unregistered")
	var rogue_shape := CollisionShape3D.new()
	rogue_shape.name = "RogueCargoFrameCollision"
	rogue_shape.shape = SphereShape3D.new()
	rogue_area.add_child(rogue_shape)
	last_joint.add_child(rogue_area)
	var authority_red := jovian.get_cargo_frame_joint_allocation_audit()
	_check(
		not bool(authority_red.get("valid", true))
		and int(authority_red.get("descendant_node_count", 0)) == 2
		and int(authority_red.get("collision_object_count", 0)) == 1
		and int(authority_red.get("collision_shape_count", 0)) == 1
		and int(authority_red.get("interaction_area_count", 0)) == 1
		and int(authority_red.get("metadata_entry_count", 0)) == 1
		and _has_error(authority_red, "cargo_frame_joint_gained_children")
		and _has_error(
			authority_red,
			"cargo_frame_joint_gained_collision_or_interaction_authority"
		)
		and _has_error(authority_red, "cargo_frame_joint_gained_evidence_metadata"),
		"structured red: authority cannot hide under a shared cargo-frame joint"
	)
	last_joint.remove_child(rogue_area)
	rogue_area.free()
	_check(
		bool(jovian.get_cargo_frame_joint_allocation_audit().get("valid", false))
		and bool(jovian.get_jovian_audit_report().get("valid", false)),
		"cargo-frame identity, recipe, renderer, and authority mutations restore to green"
	)


func _test_scale_handling_and_presentation(jovian: JovianLightFreighter) -> void:
	# Mixing indexed torus stock once dropped the earlier unindexed fittings.
	# Retain both their intended finish and actually drawn forward triangles.
	for finish in ["dark", "structure"]:
		var fitted := jovian.get_jovian_visual_root().get_node_or_null(
			"FreighterServiceFittings" + finish.capitalize()) as MeshInstance3D
		_check(fitted != null and fitted.get_active_material(0) == jovian.get_variant_materials()[finish],
			"merged engine and service fittings retain their %s finish" % finish)
		var has_forward_fittings := false
		if fitted != null:
			for vertex in fitted.mesh.get_faces():
				if vertex.z < 0.0:
					has_forward_fittings = true
					break
		_check(has_forward_fittings, "appending engine rings preserves drawn forward %s fittings" % finish)
	var torrent := TORRENT_SCENE.instantiate() as HeroShip
	var arrow := ARROW_SCENE.instantiate() as ArrowReconShip
	_test_root.add_child(torrent)
	_test_root.add_child(arrow)
	await process_frame
	var visual := jovian.get_jovian_visual_root()
	_check(visual != null and visual.name == "JovianFreighterVisual", "variant owns a dedicated Jovian visual root")
	_check(jovian.get_node_or_null("TorrentVisual") == null, "no inherited Torrent exterior hierarchy remains")
	_check(str(visual.get_meta("geometry_status", "")) == "provisional", "visual root publishes provisional geometry status")
	var flight_deck := visual.get_node_or_null("ForwardFlightDeck") as MeshInstance3D
	var shoulder := visual.get_node_or_null("PortCargoShoulder") as MeshInstance3D
	_check(flight_deck != null and flight_deck.mesh is ArrayMesh and bool(flight_deck.get_meta("closed_loft_hull", false)), "flight deck is a closed rolled bow apron")
	_check(shoulder != null and shoulder.mesh is ArrayMesh and bool(shoulder.get_meta("closed_loft_hull", false)) and shoulder.mesh.get_surface_count() == 3, "split port cargo shoulder retains its three authored finishes over the curved pressure skin")
	# Service construction remains an open overlay on the pressure skin and
	# batches repeated lids, louvers and hardware into two assemblies.
	var service_lids: Array[Node] = [visual.get_node("RoofServiceAssembly"), visual.get_node("FlightDeckAvionicsBonnet")]
	var open_lids := 0
	for candidate in service_lids:
		var lid := candidate as MeshInstance3D
		if lid != null and not lid.has_meta("closed_loft_hull") and _mesh_open_boundary_edges(lid.mesh) > 0:
			open_lids += 1
		if lid != null:
			_test_roof_service_construction(jovian, lid)
	_check(open_lids == 2, "batched thermal-service carriers and avionics bonnet have real open undersides")
	_check(visual.find_children("*RoofThermalCover*", "MeshInstance3D", false, false).is_empty(),
		"service frames replace the isolated roof tiles")
	if flight_deck != null and flight_deck.mesh != null:
		var faces := flight_deck.mesh.get_faces()
		var first_side_normal := (faces[1] - faces[0]).cross(faces[2] - faces[0]).normalized()
		var first_side_center := (faces[0] + faces[1] + faces[2]) / 3.0
		_check(
			first_side_normal.dot(Vector3(first_side_center.x, first_side_center.y, 0.0)) < 0.0,
			"flight-deck loft uses Godot's clockwise outward front face instead of exposing a hollow shell"
		)
	_check(visual.get_node_or_null("PortRadiator") is MeshInstance3D and visual.get_node_or_null("StarboardRadiator") is MeshInstance3D, "paired radiator planforms distinguish the utility silhouette")
	var canopy := visual.get_node_or_null("CanopyHinge") as Node3D
	var port_hinge_mount := visual.get_node_or_null("PortCanopyHingeMount") as MeshInstance3D
	var starboard_hinge_mount := visual.get_node_or_null("StarboardCanopyHingeMount") as MeshInstance3D
	_check(
		canopy != null and port_hinge_mount != null and starboard_hinge_mount != null
		and port_hinge_mount.position.x < starboard_hinge_mount.position.x,
		"freighter retains both explicitly named inherited canopy hinge mounts"
	)
	_check(
		canopy != null
		and canopy.get_node_or_null("PortCanopyLowerRail") is MeshInstance3D
		and canopy.get_node_or_null("StarboardCanopyLowerRail") is MeshInstance3D
		and canopy.get_node_or_null("PortCanopyNoseFrame") is MeshInstance3D
		and canopy.get_node_or_null("StarboardCanopyNoseFrame") is MeshInstance3D,
		"freighter retains the retired canopy nodes for common lifecycle references"
	)

	var maximum_x := 0.0
	var maximum_z := 0.0
	for child in jovian.get_children():
		if child is CollisionShape3D and (child as CollisionShape3D).shape is BoxShape3D:
			var collision := child as CollisionShape3D
			var size := (collision.shape as BoxShape3D).size
			maximum_x = maxf(maximum_x, absf(collision.position.x) + size.x * 0.5)
			maximum_z = maxf(maximum_z, absf(collision.position.z) + size.z * 0.5)
	_check(maximum_x * 2.0 > 15.0 and maximum_z * 2.0 > 27.0, "collision envelope is materially larger than both small craft")
	_check(jovian.maximum_speed < torrent.maximum_speed and jovian.maximum_speed < arrow.maximum_speed, "freighter top speed is lower than both small craft")
	_check(jovian.thrust_acceleration < torrent.thrust_acceleration and jovian.thrust_acceleration < arrow.thrust_acceleration, "freighter acceleration is lower than both small craft")
	_check(jovian.yaw_speed_degrees < torrent.yaw_speed_degrees and jovian.yaw_speed_degrees < arrow.yaw_speed_degrees, "freighter yaw is slower than both small craft")
	_check(jovian.roll_speed_degrees < torrent.roll_speed_degrees and jovian.roll_speed_degrees < arrow.roll_speed_degrees, "freighter roll is slower than both small craft")
	_check(jovian.maximum_hull > torrent.maximum_hull * 2.0 and jovian.maximum_hull > arrow.maximum_hull * 2.0, "freighter has substantially greater hull durability")
	torrent.queue_free()
	arrow.queue_free()
	await process_frame


func _test_connected_interior_contract(jovian: JovianLightFreighter) -> void:
	var interior := jovian.get_interior_root()
	var cargo := jovian.get_cargo_bay_root()
	var passenger := jovian.get_passenger_cabin_root()
	_check(interior != null and interior.get_parent() == jovian, "interior is a direct child of the unbanked physical ship frame")
	_check(cargo != null and cargo.get_parent() == interior, "cargo bay is part of the physical interior")
	_check(passenger != null and passenger.get_parent() == interior, "passenger cabin is part of the same interior")
	_check(jovian.get_pilot_seat_anchor().get_parent().get_parent() == interior, "pilot cockpit is part of the same unbanked interior frame")
	_check(cargo.get_node_or_null("CargoDeck") is MeshInstance3D, "cargo bay exposes a visible deck")
	_check(passenger.get_node_or_null("PassengerDeck") is MeshInstance3D, "passenger cabin exposes a visible deck")
	_check(jovian.get_node_or_null("WalkableInterior/CockpitConnectorDeck") is MeshInstance3D, "same-level connector reaches the cockpit")
	_check(jovian.get_cargo_hardpoints().size() == 4, "four stable cargo hardpoints are exposed")
	_check(jovian.get_passenger_seat_anchors().size() == 6, "six stable passenger anchors are exposed")
	for hardpoint in jovian.get_cargo_hardpoints():
		_check(hardpoint.is_ancestor_of(hardpoint) == false and jovian.is_ancestor_of(hardpoint), "%s remains ship-owned" % hardpoint.name)
	for anchor in jovian.get_passenger_seat_anchors():
		_check(jovian.is_ancestor_of(anchor) and anchor.has_meta("seat_id"), "%s is a typed ship-owned seat anchor" % anchor.get_parent().name)

	var access := jovian.get_interior_access_marker()
	var deck := jovian.get_interior_deck_marker()
	_check(access != null and deck != null and jovian.is_ancestor_of(access) and jovian.is_ancestor_of(deck), "entry markers remain attached to the ship")
	_check(access.position.x < deck.position.x - 4.5 and absf(access.position.z - deck.position.z) < 0.01, "ramp threshold connects directly to the cargo deck")
	_check(jovian.get_interior_exit_transform().origin.distance_to(jovian.global_position) > 10.4, "interior exit clears the large hull")
	var bounds := jovian.get_interior_bounds()
	_check(bounds.size.x > 11.0 and bounds.size.y > 4.0 and bounds.size.z > 17.0, "ship publishes a useful local interior AABB")
	_check(bounds.has_point(deck.position) and bounds.has_point(Vector3.ZERO + Vector3(0, 1, -5)), "bounds include cargo and passenger walkable positions")
	_check(jovian.get_interior_frame() == jovian, "rigid interior frame is the physical ship root")
	var coordinator := jovian.get_moving_interior_component()
	_check(coordinator != null and coordinator.get_parent() == jovian, "typed moving-interior coordinator is a direct child")
	_check(coordinator.get_moving_frame() == jovian and coordinator.get_interior_bounds() == bounds, "coordinator uses the exact ship frame and bounds")
	var report := jovian.get_walkable_interior_report()
	_check(not bool(report.detached_interior) and bool(report.physical_deck_collision), "interior report rejects a detached set and confirms deck collision")
	_check(bool(report.moving_occupant_compensation), "interior report confirms moving-occupant compensation")
	_check((report.connected_spaces as PackedStringArray) == PackedStringArray(["exterior_ramp", "cargo_bay", "passenger_cabin", "pilot_cockpit"]), "interior report exposes the complete route in order")
	_check(not bool(report.historically_authenticated_layout), "interior report cannot authenticate the invented layout")


func _test_collision_access_and_cameras(jovian: JovianLightFreighter) -> void:
	_check(jovian.collision_layer == PhysicsLayers.SHIP_BODY_LAYER and jovian.collision_mask == PhysicsLayers.SHIP_BODY_MASK, "Jovian uses canonical ship collision")
	for collision_name in ["CargoDeckCollision", "PassengerDeckCollision", "CockpitDeckCollision", "PortCargoRampCollision"]:
		_check(jovian.get_node_or_null(collision_name) is CollisionShape3D, "%s is a physical collider" % collision_name)
	# There must be no monolithic port collision across the ramp aperture.
	_check(jovian.get_node_or_null("PortShoulderCollision") == null, "port shoulder collision is split around the cargo opening")
	var ray_parameters := PhysicsRayQueryParameters3D.create(
		jovian.to_global(Vector3(-5.25, 2.0, 3.2)),
		jovian.to_global(Vector3(0.0, 2.0, 3.2)),
		PhysicsLayers.SHIP_BODY_LAYER
	)
	var clear_route := jovian.get_world_3d().direct_space_state.intersect_ray(ray_parameters)
	_check(clear_route.is_empty(), "cargo aperture to central aisle is not blocked by another body")
	var boarding_area := jovian.get_node_or_null("ShipBoardingArea") as ShipBoardingArea
	_check(boarding_area != null and boarding_area.get_ship() == jovian and boarding_area.is_available(), "pilot boarding area resolves the freighter generically")
	_check("FLIGHT DECK" in boarding_area.get_prompt(), "pilot prompt is distinct from cargo-ramp access")
	_check(jovian.get_boarding_position().distance_to(jovian.get_interior_access_marker().global_position) > 7.0, "pilot hatch and cargo entrance are separate physical routes")
	var seat := jovian.get_pilot_seat_anchor()
	_check(seat != null and seat.global_position.distance_to(jovian.get_boarding_entry_transform().origin) < 3.0, "pilot hatch retains a short physical seat transition")
	_check(seat.global_position.z < jovian.get_passenger_cabin_root().global_position.z - 6.0, "pilot seat is forward of the passenger cabin")
	var cockpit := jovian.get_interior_root().get_node_or_null(^"CockpitInterior") as Node3D
	for visual_name: StringName in [&"SeatPan", &"SeatBack"]:
		var visual := cockpit.get_node_or_null(NodePath(visual_name)) as MeshInstance3D \
			if cockpit != null else null
		var collision := jovian.get_node_or_null(
			NodePath("Pilot%sCollision" % visual_name)
		) as CollisionShape3D
		var visual_bounds := visual.mesh.get_aabb() if visual != null and visual.mesh != null \
			else AABB()
		var expected_transform := (
			jovian.global_transform.affine_inverse() * visual.global_transform
			* Transform3D(Basis.IDENTITY, visual_bounds.get_center())
		) if visual != null else Transform3D.IDENTITY
		_check(
			collision != null
			and collision.shape is BoxShape3D
			and (collision.shape as BoxShape3D).size.is_equal_approx(visual_bounds.size)
			and collision.transform.is_equal_approx(expected_transform),
			"visible pilot %s has an exact ship-owned collision counterpart" % visual_name
		)
	jovian.set_piloted(true)
	_check(jovian.get_camera() != null and jovian.get_camera().name == "ShipCamera", "large craft activates chase camera")
	jovian.set_cockpit_view(true)
	_check(
		jovian.get_camera().name == "CockpitCamera"
		and jovian.get_camera().get_parent().name == "CockpitInterior"
		and is_equal_approx(jovian.get_camera().near, 0.04),
		"cockpit view remains inside the physical flight deck with an interior-scale near plane"
	)
	jovian.set_cockpit_view(false)
	jovian.set_piloted(false)


## The hold's secured freight is solid.
##
## It was presentation-only for as long as the cargo bay was scenery a chase
## camera flew past. Once a crew member could leave the seat and walk it, a crate
## you walk through — and a chase boom pushed inside a container, which is what
## `artifacts/cabin_04_walking_the_hold.png` shows — became the same
## "solid-looking volume with no collision" defect the station sweep closed
## everywhere else.
##
## Measured both ways on purpose. Freight that is solid but has swallowed the
## aisle is a worse defect than freight you can walk through, because it strands a
## crew member in a pressurised hull: the same probe that requires the crates to
## stop a capsule requires the central lane and the ramp-to-cabin diagonal to
## stay open. `_test_physical_player_traversal` below then walks that lane for
## real.
const CARGO_AISLE_PROBE_POINTS: Array[Vector3] = [
	Vector3(0.0, 1.4, -1.5),
	Vector3(0.0, 1.4, 1.0),
	Vector3(0.0, 1.4, 3.2),
	Vector3(0.0, 1.4, 5.5),
	Vector3(0.0, 1.4, 8.0),
	# The ramp aperture and the diagonal from it to the forward passage.
	Vector3(-4.6, 1.4, 3.2),
	Vector3(-2.6, 1.4, 3.2),
	Vector3(-1.4, 1.4, 0.0),
]


func _test_secured_freight_is_solid(jovian: JovianLightFreighter) -> void:
	var space := jovian.get_world_3d().direct_space_state
	var drawn_units: Array[MeshInstance3D] = []
	for candidate in jovian.find_children("CargoContainer*", "MeshInstance3D", true, false):
		drawn_units.append(candidate as MeshInstance3D)
	for candidate in jovian.find_children("CargoPallet*", "MeshInstance3D", true, false):
		drawn_units.append(candidate as MeshInstance3D)
	_check(
		drawn_units.size() == JovianLightFreighter.CARGO_UNIT_ANCHORS.size() * 2,
		"the hold draws a pallet and a container at each of its %d tie-down stations (%d meshes)"
			% [JovianLightFreighter.CARGO_UNIT_ANCHORS.size(), drawn_units.size()]
	)

	# Every drawn crate volume must stop a probe placed inside it. The probe is a
	# box at half the drawn unit's own size, centred on the drawn mesh: half-size
	# so a 0.22 m pallet is tested without the probe reaching down through it into
	# the cargo deck 0.28 m below, which is what a fixed-size capsule does and is
	# why the first version of the structured red below could not go red.
	var query := PhysicsShapeQueryParameters3D.new()
	query.collision_mask = PhysicsLayers.SHIP_BODY_LAYER
	var permeable := PackedStringArray()
	for unit in drawn_units:
		var bounds := (unit.global_transform * unit.get_aabb()).abs()
		query.shape = _inner_probe(bounds)
		query.transform = Transform3D(Basis.IDENTITY, bounds.get_center())
		var hit := false
		for result in space.intersect_shape(query, 4):
			if (result["collider"] as Node) == jovian:
				hit = true
		if not hit:
			permeable.append("%s at %s" % [unit.name, str(bounds.get_center())])
	print("PERMEABLE_FREIGHT: ", permeable)
	_check(
		permeable.is_empty(),
		"every drawn cargo unit in the hold is solid to the ship's own collision"
	)

	var blocked_aisle := PackedStringArray()
	# The production avatar's own capsule, standing on the cargo deck.
	var aisle_capsule := CapsuleShape3D.new()
	aisle_capsule.radius = 0.38
	aisle_capsule.height = 1.8
	query.shape = aisle_capsule
	for point in CARGO_AISLE_PROBE_POINTS:
		query.transform = Transform3D(Basis.IDENTITY, jovian.to_global(point))
		for result in space.intersect_shape(query, 4):
			if (result["collider"] as Node) == jovian:
				blocked_aisle.append(str(point))
				break
	print("BLOCKED_CARGO_AISLE: ", blocked_aisle)
	_check(
		blocked_aisle.is_empty(),
		"making the freight solid left the central lane and the ramp-to-cabin diagonal open"
	)

	# Structured red: drop the colliders and the permeability check must fire.
	var disabled: Array[CollisionShape3D] = []
	for child in jovian.get_children():
		var shape := child as CollisionShape3D
		if shape == null or not shape.name.begins_with("Cargo"):
			continue
		if not (shape.name.contains("Pallet") or shape.name.contains("Container")):
			continue
		shape.disabled = true
		disabled.append(shape)
	_check(disabled.size() == drawn_units.size(), "each drawn cargo unit has its own named collider")
	var still_solid := 0
	for unit in drawn_units:
		var bounds := (unit.global_transform * unit.get_aabb()).abs()
		query.shape = _inner_probe(bounds)
		query.transform = Transform3D(Basis.IDENTITY, bounds.get_center())
		for result in space.intersect_shape(query, 4):
			if (result["collider"] as Node) == jovian:
				still_solid += 1
				break
	_check(
		still_solid == 0,
		"disabling the freight colliders returns the hold to walk-through crates (%d still solid)"
			% still_solid
	)
	for shape in disabled:
		shape.disabled = false


## A box at half the given volume's size, centred in it: entirely inside the
## drawn unit, so a hit can only come from that unit's own collider.
func _inner_probe(bounds: AABB) -> BoxShape3D:
	var shape := BoxShape3D.new()
	shape.size = bounds.size * 0.5
	return shape


func _test_physical_player_traversal(jovian: JovianLightFreighter) -> void:
	# A real PlayerController follows the complete public route from the exterior
	# ramp to the pilot seat, leaves that seat into the in-flight cabin pose,
	# retakes it, and exits through the pilot hatch. The one staging teleport below
	# is the only direct pose write in the route.
	var landing_deck := StaticBody3D.new()
	landing_deck.name = "JovianTraversalLandingDeck"
	landing_deck.collision_layer = PhysicsLayers.WORLD_BODY_LAYER
	landing_deck.collision_mask = PhysicsLayers.NONE
	_test_root.add_child(landing_deck)
	var deck_collision := CollisionShape3D.new()
	deck_collision.position = Vector3(0.0, -1.35, 0.0)
	var deck_shape := BoxShape3D.new()
	deck_shape.size = Vector3(45.0, 0.2, 45.0)
	deck_collision.shape = deck_shape
	landing_deck.add_child(deck_collision)
	var player := PLAYER_SCENE.instantiate() as PlayerController
	_test_root.add_child(player)
	player.set_camera_active(false)
	var camera_yaw := player.get_node("CameraRig/CameraYaw") as Node3D
	player.teleport_to(Transform3D(Basis.IDENTITY, jovian.to_global(Vector3(-10.7, -1.24, 3.2))))
	camera_yaw.rotation.y = 0.0
	for index in 10:
		await physics_frame
	_check(player.is_on_floor(), "real player begins grounded beside the deployed ramp")

	Input.action_press("move_right")
	for index in 118:
		await physics_frame
	Input.action_release("move_right")
	var cargo_local := jovian.to_local(player.global_position)
	_check(cargo_local.x > -3.2 and absf(cargo_local.z - 3.2) < 1.2, "real player walks up the ramp and through its collision-clear aperture")
	_check(player.is_on_floor(), "real player remains grounded on the ship-owned cargo deck")
	_check(jovian.get_moving_interior_component().is_occupant_registered(player), "cargo entry registers the real player with the moving frame")

	Input.action_press("move_forward")
	for index in 90:
		await physics_frame
	Input.action_release("move_forward")
	var cabin_local := jovian.to_local(player.global_position)
	_check(cabin_local.z < -3.35 and absf(cabin_local.x) < 1.45, "real player follows the central aisle into the connected passenger cabin")
	_check(player.is_on_floor(), "real player stays grounded across the cargo-to-passenger threshold")
	_check(jovian.get_interior_bounds().has_point(cabin_local), "passenger traversal remains within published ship-local bounds")

	# Keep walking toward the visible pilot chair. Its solid seat back, rather than
	# the forward pressure wall behind it, must stop the production capsule.
	Input.action_press("move_forward")
	for index in 55:
		await physics_frame
	Input.action_release("move_forward")
	var cockpit_local := jovian.to_local(player.global_position)
	_check(
		cockpit_local.z > -7.4 and cockpit_local.z < -6.8
		and absf(cockpit_local.x) < 0.45,
		"visible pilot chair physically closes the central aisle at its reachable seat approach"
	)
	_check(
		player.is_on_floor()
		and jovian.get_in_flight_cabin_report().get("local_bounds", AABB()).has_point(
			cockpit_local
		),
		"real player remains supported and contained at the cockpit seat approach"
	)

	var pilot_seat := jovian.get_pilot_seat_anchor()
	_check(
		player.begin_boarding(
			jovian.get_boarding_entry_transform(), pilot_seat, 0.0, jovian
		) and player.is_seated(),
		"public boarding transition takes the embodied ramp-route player into the pilot seat"
	)
	jovian.set_piloted(true)
	_check(
		is_equal_approx(player.get_camera().near, 0.08)
		and is_equal_approx(jovian.get_camera().near, 0.15),
		"on-foot and piloting cameras retain short finite near planes at interior scale"
	)

	# Exercise the same moving-frame transition used by the production cabin
	# release. Collision is restored at the published stand pose, so this also
	# catches a marker hidden inside the visible seat.
	jovian.set_piloted(false)
	var cabin_release_started := player.begin_disembark(
		jovian.get_cabin_stand_transform(), 0.04, jovian
	)
	_check(
		cabin_release_started,
		"public in-flight disembark transition releases the pilot into the cabin"
	)
	if cabin_release_started:
		await player.disembarking_completed
	var frame := jovian.get_moving_interior_component()
	var registration := frame.register_occupant(player, {
		"require_inside_bounds": false,
		"registration_source": &"jovian_route_regression",
	})
	_check(bool(registration.get("registered", false)), "released pilot is carried by the Jovian moving frame")
	_check(
		player.set_cabin_containment(
			jovian,
			jovian.get_in_flight_cabin_report().get("local_bounds", AABB()),
			jovian.get_cabin_stand_transform()
		),
		"released pilot receives the production Jovian anti-stranding envelope"
	)
	player.set_control_enabled(true)
	for index in 8:
		await physics_frame
	var released_local := jovian.to_local(player.global_position)
	_check(
		player.is_on_floor()
		and released_local.distance_to(JovianLightFreighter.CABIN_STAND_LOCAL_ORIGIN) < 0.08,
		"in-flight release pose is grounded and collision-clear behind the pilot chair"
	)
	var boarding_area := jovian.get_node_or_null(^"ShipBoardingArea") as ShipBoardingArea
	_check(
		boarding_area != null
		and player.get_nearby_interactables().has(boarding_area)
		and boarding_area.is_available_for(player)
		and boarding_area.get_prompt().contains("FLIGHT DECK"),
		"released pilot discovers the readable flight-deck prompt at gameplay distance"
	)

	player.clear_cabin_containment()
	frame.unregister_occupant(player, false, &"jovian_route_reboard")
	_check(
		player.begin_boarding(
			jovian.get_cabin_stand_transform(), pilot_seat, 0.0, jovian
		) and player.is_seated(),
		"released pilot can retake the same seat without a teleport"
	)
	_check(
		player.begin_disembark(jovian.get_exit_transform(), 0.0, jovian),
		"public landed exit transition returns the reboarded pilot to the exterior hatch"
	)
	player.set_control_enabled(true)
	for index in 8:
		await physics_frame
	var hatch_exit_local := jovian.to_local(player.global_position)
	var hatch_marker_local := jovian.to_local(jovian.get_exit_transform().origin)
	_check(
		player.is_on_floor()
		and Vector2(hatch_exit_local.x, hatch_exit_local.z).distance_to(
			Vector2(hatch_marker_local.x, hatch_marker_local.z)
		) < 0.08,
		"pilot hatch exit is supported and clear of the hull"
	)
	Input.action_press("move_left")
	for index in 20:
		await physics_frame
	Input.action_release("move_left")
	_check(
		jovian.to_local(player.global_position).z < hatch_exit_local.z - 0.8,
		"exited pilot can walk away from the Jovian without an invisible blocker"
	)

	player.queue_free()
	landing_deck.queue_free()
	await process_frame
	await physics_frame
	Input.action_release("move_right")
	Input.action_release("move_forward")
	Input.action_release("move_left")


func _test_engine_weapon_damage_and_reuse(jovian: JovianLightFreighter) -> void:
	var fired: Array[Dictionary] = []
	jovian.projectile_fired.connect(func(origin: Vector3, direction: Vector3) -> void:
		fired.append({"origin": origin, "direction": direction})
	)
	var engine_cores := jovian.get_jovian_visual_root().find_children("*EngineCore", "MeshInstance3D", true, false)
	_check(engine_cores.size() == 4, "freighter retains all four authored engine cores")
	_check(_visible_mesh_count(engine_cores) == 0, "all four engine cores are dark while initially offline")
	jovian.engine_start_time = 0.03
	jovian.weapon_cooldown = 0.03
	jovian.set_piloted(true)
	jovian.request_engine_start()
	_check(str(jovian.get_telemetry().engine_state) == "STARTING", "freighter enters inherited engine startup")
	_check(_visible_mesh_count(engine_cores) == 4, "all four engine cores activate during startup")
	for index in 7:
		await physics_frame
	_check(str(jovian.get_telemetry().engine_state) == "ONLINE", "freighter completes inherited engine startup")
	var engine_plumes := jovian.get_jovian_visual_root().find_children("*EnginePlume", "MeshInstance3D", true, false)
	_check(_visible_mesh_count(engine_cores) == 4, "all four engine cores activate online")
	_check(_visible_mesh_count(engine_plumes) == 4, "all four engine plumes activate online")
	_test_root.remove_child(jovian)
	_check(_visible_mesh_count(engine_cores) == 0, "detaching immediately darkens all four engine cores")
	_check(_visible_mesh_count(engine_plumes) == 0, "detaching immediately hides all four engine plumes")
	_test_root.add_child(jovian)
	await process_frame
	await physics_frame
	_check(str(jovian.get_telemetry().engine_state) == "ONLINE", "re-entry preserves authoritative online engine state")
	_check(_visible_mesh_count(engine_cores) == 4, "online cores reactivate from authoritative telemetry after re-entry")
	var component_damage := jovian.get_component_damage()
	var engine_position := Vector3.ZERO
	for component in jovian.get_component_damage_report().get("components", []) as Array:
		if StringName((component as Dictionary).get("id", &"")) == ShipComponentDamage.COMPONENT_ENGINE_BAY:
			engine_position = (component as Dictionary).get("local_position", Vector3.ZERO) as Vector3
			break
	var damage_guard := 0
	while component_damage.get_component_state(ShipComponentDamage.COMPONENT_ENGINE_BAY) \
			< ShipComponentDamage.ComponentState.FAILED and damage_guard < 4:
		component_damage.record_damage(jovian.maximum_hull * 2.0, engine_position)
		damage_guard += 1
	jovian.call("_sync_engine_visuals_immediately")
	_check(
		jovian.get_engine_exhaust_damage_presentation_profile().get("stage") == &"failed"
			and str(jovian.get_telemetry().engine_state) == "ONLINE"
			and _visible_mesh_count(engine_cores) == 4,
		"failed engine-bay exhaust does not override authoritative online core state"
	)
	_check(
		_visible_mesh_count(engine_plumes) == 0,
		"failed engine bay retains inherited online exhaust suppression"
	)
	var engine_integrity := component_damage.get_component_integrity(
		ShipComponentDamage.COMPONENT_ENGINE_BAY
	)
	component_damage.tick_component_repair(
		ShipComponentDamage.COMPONENT_ENGINE_BAY,
		(1.0 - engine_integrity) / maxf(component_damage.repair_rate_per_second, 0.001) + 0.001,
		true
	)
	jovian.call("_sync_engine_visuals_immediately")
	_check(
		jovian.get_engine_exhaust_damage_presentation_profile().get("stage") == &"nominal"
			and _visible_mesh_count(engine_cores) == 4
			and _visible_mesh_count(engine_plumes) == 4,
		"engine-bay repair restores nominal exhaust without changing online core state"
	)
	Input.action_press("fire")
	await physics_frame
	Input.action_release("fire")
	_check(fired.size() == 1, "defensive pulse fires through inherited weapon lifecycle")
	if not fired.is_empty():
		_check((fired[0].direction as Vector3).dot(-jovian.global_basis.z) > 0.8, "pulse follows visible nose direction")

	var coordinator := jovian.get_moving_interior_component()
	var occupant := CharacterBody3D.new()
	occupant.name = "InteriorLifecycleOccupant"
	_test_root.add_child(occupant)
	occupant.global_position = jovian.to_global(Vector3.ZERO + Vector3(0.0, 1.0, 2.0))
	var registration := coordinator.register_occupant(occupant, {"require_inside_bounds": true})
	_check(bool(registration.registered), "physical occupant registers inside the ship-local bounds")
	jovian.set_piloted(false)
	jovian.request_engine_stop()
	_check(str(jovian.get_telemetry().engine_state) == "OFFLINE", "freighter accepts inherited engine shutdown")
	_check(_visible_mesh_count(engine_cores) == 0, "shutdown immediately darkens all four engine cores")
	_check(_visible_mesh_count(engine_plumes) == 0, "shutdown immediately hides all four engine plumes")
	jovian.set_piloted(true)
	jovian.request_engine_start()
	for index in 7:
		await physics_frame
	_check(_visible_mesh_count(engine_cores) == 4, "all four engine cores reactivate after a real restart")
	jovian.apply_damage(jovian.maximum_hull + 1.0, jovian.global_position, Vector3.UP)
	await physics_frame
	_check(jovian.is_destroyed() and coordinator.get_occupant_count() == 0, "destruction releases moving-interior occupants")
	_check(_visible_mesh_count(engine_cores) == 0, "destruction darkens all four engine cores")
	_check(_visible_mesh_count(engine_plumes) == 0, "destruction hides all four engine plumes")
	var volume := jovian.get_node_or_null("WalkableInterior/InteriorOccupantVolume") as Area3D
	_check(volume != null and not volume.monitoring, "destroyed ship disables automatic interior registration")
	var reset_transform := Transform3D(Basis(Vector3.UP, deg_to_rad(-18.0)), Vector3(20.0, 4.0, 16.0))
	jovian.reset_for_reuse(reset_transform)
	await physics_frame
	await physics_frame
	_check(not jovian.is_destroyed() and jovian.is_boardable(), "same freighter instance resets for reuse")
	_check(jovian.global_transform.origin.is_equal_approx(reset_transform.origin), "reuse snaps to requested berth transform")
	_check(volume.monitoring and coordinator.get_moving_frame() == jovian, "reuse restores interior registration volume and frame")
	_check(jovian.get_interior_root().visible and jovian.get_cargo_hardpoints().size() == 4, "connected interior survives reuse")
	_check(str(jovian.get_telemetry().engine_state) == "OFFLINE", "reuse restores authoritative offline engine state")
	_check(_visible_mesh_count(engine_cores) == 0, "reused offline freighter keeps all four engine cores dark")
	_test_root.remove_child(jovian)
	_test_root.add_child(jovian)
	await process_frame
	await physics_frame
	_check(_visible_mesh_count(engine_cores) == 0, "offline detach and re-entry keeps all four engine cores dark")
	occupant.queue_free()
	await process_frame


func _visible_mesh_count(nodes: Array[Node]) -> int:
	var visible_count := 0
	for node in nodes:
		if is_instance_valid(node) and (node as MeshInstance3D).visible:
			visible_count += 1
	return visible_count


func _test_cleanup(jovian: JovianLightFreighter) -> void:
	var ship_reference: WeakRef = weakref(jovian)
	var interior_reference: WeakRef = weakref(jovian.get_interior_root())
	var coordinator_reference: WeakRef = weakref(jovian.get_moving_interior_component())
	jovian.queue_free()
	jovian = null
	await process_frame
	await physics_frame
	await process_frame
	_check(ship_reference.get_ref() == null, "Jovian root cleans up")
	_check(interior_reference.get_ref() == null, "connected interior cleans up with ship")
	_check(coordinator_reference.get_ref() == null, "moving-interior coordinator cleans up with ship")
	_test_root.queue_free()
	await process_frame


func _has_error(audit: Dictionary, expected: String) -> bool:
	return (audit.get("errors", PackedStringArray()) as PackedStringArray).has(expected)


func _has_error_prefix(audit: Dictionary, expected_prefix: String) -> bool:
	for error in audit.get("errors", PackedStringArray()) as PackedStringArray:
		if error.begins_with(expected_prefix):
			return true
	return false


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	Input.action_release("fire")
	if _failures.is_empty():
		print("JOVIAN_LIGHT_FREIGHTER_TEST_OK")
		quit(0)
	else:
		print("JOVIAN_LIGHT_FREIGHTER_TEST_FAILED: ", ", ".join(_failures))
		quit(1)


func _mesh_open_boundary_edges(mesh: Mesh) -> int:
	var edges := {}
	var faces := mesh.get_faces()
	for triangle in range(0, faces.size(), 3):
		for corner in 3:
			var a := str(faces[triangle + corner])
			var b := str(faces[triangle + (corner + 1) % 3])
			var key := a + ":" + b if a < b else b + ":" + a
			edges[key] = int(edges.get(key, 0)) + 1
	var boundary_edges := 0
	for count: int in edges.values():
		if count == 1:
			boundary_edges += 1
	return boundary_edges


func _test_interior_furnishing_ranges(craft: HeroShip) -> void:
	for enclosure_name in ["CargoDeck", "StarboardInnerWall", "AftPressureWall", "ForwardBulkheadHeader", "PassengerDeck", "PassengerRoof", "CargoContainerPort00", "CargoPalletPort00"]:
		var enclosure := craft.find_child(enclosure_name, true, false) as GeometryInstance3D
		_check(enclosure != null and enclosure.visibility_range_end == 0.0,
			"opaque enclosure, windows and portal geometry stay unbounded: " + enclosure_name)
	var retained := {}
	var protected_enclosure_count := 0
	for candidate in craft.find_children("*", "GeometryInstance3D", true, false):
		var geometry := candidate as GeometryInstance3D
		if geometry.visibility_range_end == 0.0:
			protected_enclosure_count += 1
			continue
		_check(geometry.visibility_range_begin == 0.0
			and geometry.visibility_range_end == 100.0
			and geometry.visibility_range_end_margin == 10.0
			and geometry.visibility_range_fade_mode == GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED,
			"interior furniture uses native 100 m range with 10 m hysteresis and no close limit")
		var path := String(craft.get_path_to(geometry))
		_check(path.contains("/CrewCabin/") or path.contains("/AftSystemsBay/")
			or path.contains("/PassengerCabin/") or path.contains("/CargoBay/"),
			"distance culling stays inside selected interior furnishing families")
		retained[geometry] = [geometry.transform, geometry.visible, geometry.layers,
			geometry.material_override, geometry.cast_shadow]
	_check(retained.size() == 68, "explicit interior furnishing allocation")
	_check(protected_enclosure_count > retained.size(), "shell and remaining presentation stay unbounded")
	var parent := craft.get_parent()
	parent.remove_child(craft)
	parent.add_child(craft)
	await process_frame
	var bounded_count := 0
	for candidate in craft.find_children("*", "GeometryInstance3D", true, false):
		if (candidate as GeometryInstance3D).visibility_range_end > 0.0:
			bounded_count += 1
	_check(bounded_count == retained.size(), "reentry does not accumulate or lose bounded furniture")
	for geometry: GeometryInstance3D in retained:
		_check(is_instance_valid(geometry) and geometry.is_inside_tree()
			and retained[geometry] == [geometry.transform, geometry.visible, geometry.layers,
				geometry.material_override, geometry.cast_shadow]
			and geometry.visibility_range_end == 100.0,
			"reentry retains authored furniture identity, pose, material and visibility authority")


func _test_formed_roof(ship: JovianLightFreighter) -> void:
	var bounded := true
	var continuous := true
	for authored in [JovianLightFreighter.CARGO_ROOF_SECTIONS, JovianLightFreighter.CABIN_ROOF_SECTIONS]:
		var sections := PackedVector3Array(authored)
		for station in sections.size():
			bounded = bounded and ship._roof_profile(sections, sections[station].z)[0].is_equal_approx(sections[station])
			if station > 0 and station < sections.size() - 1:
				var left := ship._roof_profile(sections, sections[station].z - 0.0001)[1]
				var right := ship._roof_profile(sections, sections[station].z + 0.0001)[1]
				continuous = continuous and left.distance_to(right) < 0.001
		for station in sections.size() - 1:
			for step in 41:
				var point := ship._roof_profile(sections, lerpf(sections[station].z, sections[station + 1].z, float(step) / 40.0))[0]
				for axis in [0, 1]:
					bounded = bounded and point[axis] >= minf(sections[station][axis], sections[station + 1][axis]) - 0.00001 and point[axis] <= maxf(sections[station][axis], sections[station + 1][axis]) + 0.00001
	_check(bounded, "formed roof retains authored stations without width or height overshoot")
	_check(continuous, "formed roof derivatives remain continuous at the former highlight breaks")
	var valid_frames := true
	var valid_triangles := true
	for label in ["CargoRoofShell", "ForwardCabinCrown"]:
		var node := ship.find_child(label, true, false) as MeshInstance3D
		if node == null:
			valid_frames = false
			continue
		var arrays := node.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
		valid_frames = valid_frames and normals.size() == vertices.size() and uvs.size() == vertices.size() and tangents.size() == vertices.size() * 4
		if not valid_frames:
			continue
		for index in vertices.size():
			var tangent := Vector3(tangents[index * 4], tangents[index * 4 + 1], tangents[index * 4 + 2])
			valid_frames = valid_frames and tangent.is_finite() and absf(tangent.length() - 1.0) < 0.001 and absf(normals[index].dot(tangent)) < 0.001
		for index in range(0, vertices.size(), 3):
			valid_triangles = valid_triangles and (vertices[index + 1] - vertices[index]).cross(vertices[index + 2] - vertices[index]).length_squared() > 1e-12
			valid_triangles = valid_triangles and absf((uvs[index + 1] - uvs[index]).cross(uvs[index + 2] - uvs[index])) > 1e-8
	_check(valid_frames, "both formed skins have complete finite orthonormal tangent frames")
	_check(valid_triangles, "roof faces and perimeter returns have nondegenerate triangles and UVs")


func _test_formed_forward_shell(ship: JovianLightFreighter) -> void:
	var visual := ship.get_jovian_visual_root()
	for label in ["ForwardFlightDeck", "PortCargoShoulder", "PortAftCargoShoulder",
			"StarboardCargoShoulder", "PortCabinTransition", "StarboardCabinTransition"]:
		var member := visual.get_node(NodePath(label)) as MeshInstance3D
		var valid_faces := true
		var longitudinal_stations := {}
		for surface in member.mesh.get_surface_count():
			var arrays := member.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			for index in range(0, vertices.size(), 3):
				var cross_product := (vertices[index + 1] - vertices[index]).cross(vertices[index + 2] - vertices[index])
				valid_faces = valid_faces and cross_product.length_squared() > 1e-14
				for corner in 3:
					valid_faces = valid_faces and normals[index + corner].is_finite() \
						and absf(normals[index + corner].length() - 1.0) < 0.001 \
						and cross_product.dot(normals[index + corner]) < 0.0
					longitudinal_stations[snappedf(vertices[index + corner].z, 0.0001)] = true
		_check(valid_faces and _mesh_open_boundary_edges(member.mesh) == 0,
			"%s is closed with finite smooth normals, nondegenerate triangles and outward clockwise winding" % label)
		_check(longitudinal_stations.size() > 10,
			"%s contains actual longitudinal curvature beyond the former station facets" % label)
	# The original bearing is seated over the actual triangles, including its
	# full bottom-flange circumference. No collision proxy substitutes for skin.
	for side in [-1.0, 1.0]:
		var prefix := "Port" if side < 0.0 else "Starboard"
		var cheek := visual.get_node(NodePath(prefix + "CabinTransition")) as MeshInstance3D
		var base := visual.get_node(NodePath(prefix + "DefensiveTurretBase")) as MeshInstance3D
		var faces := cheek.mesh.get_faces()
		var seated := true
		var skin_min := INF
		var skin_max := -INF
		for sample in 33:
			var angle := TAU * float(sample) / 32.0
			var radius := 0.0 if sample == 32 else 0.60
			var origin := base.position + Vector3(cos(angle) * radius, 3.0, sin(angle) * radius)
			var skin_y := -INF
			for triangle in range(0, faces.size(), 3):
				var hit: Variant = Geometry3D.ray_intersects_triangle(origin, Vector3.DOWN,
					faces[triangle], faces[triangle + 1], faces[triangle + 2])
				if hit != null:
					skin_y = maxf(skin_y, (hit as Vector3).y)
			skin_min = minf(skin_min, skin_y)
			skin_max = maxf(skin_max, skin_y)
			seated = seated and skin_y >= base.position.y - 0.19 and skin_y <= base.position.y - 0.14
		_check(seated, "%s bearing bottom seats into the integral cheek landing without reaching its moving collar" % prefix)
		print("JOVIAN_FORWARD_BEARING_CONTACT ", prefix, " skin_y=", skin_min, "..", skin_max)
		var bounds := cheek.mesh.get_aabb()
		var inner_x := absf(bounds.end.x) if side < 0.0 else bounds.position.x
		_check(is_equal_approx(inner_x, 3.46) and is_equal_approx(bounds.position.y, 0.42)
			and bounds.position.z >= -7.601 and bounds.end.z <= -2.879,
			"%s cheek retains cabin wall, floor and portal clearance boundaries" % prefix)
		# Front shoulder stops before the unchanged cargo-ramp opening.
		if side < 0.0:
			var front := visual.get_node(^"PortCargoShoulder") as MeshInstance3D
			var aft := visual.get_node(^"PortAftCargoShoulder") as MeshInstance3D
			_check(front.mesh.get_aabb().end.z < 1.121 and aft.mesh.get_aabb().position.z > 5.279,
				"curved port shoulders retain the full boarding aperture")


func _flight_deck_ray_hits(faces: PackedVector3Array, origin: Vector3, direction: Vector3) -> bool:
	for triangle in range(0, faces.size(), 3):
		if Geometry3D.ray_intersects_triangle(origin, direction,
				faces[triangle], faces[triangle + 1], faces[triangle + 2]) != null:
			return true
	return false


func _test_freighter_windscreen(ship: JovianLightFreighter) -> void:
	var visual := ship.get_jovian_visual_root()
	var hinge := visual.get_node("CanopyHinge") as Node3D
	var cockpit := ship.get_interior_root().get_node("CockpitInterior") as Node3D
	var retired: Array[Node3D] = [hinge, visual.get_node("CanopyHingeBar"),
		visual.get_node("PortCanopyHingeMount"), visual.get_node("StarboardCanopyHingeMount"),
		cockpit.get_node("PortCanopyLatchStriker"), cockpit.get_node("StarboardCanopyLatchStriker")]
	var hidden := true
	for member in retired:
		hidden = hidden and not member.is_visible_in_tree()
	for member in hinge.find_children("*", "MeshInstance3D", true, false):
		hidden = hidden and not (member as MeshInstance3D).is_visible_in_tree()
	_check(hidden, "nested fighter glass, frames, hinge hardware and latch strikers are retired inside the freighter flight deck")
	var retained := {}
	var enclosure_faces := PackedVector3Array()
	for member_name in ["FreighterPressureWindscreen", "FlightDeckWindscreenSeal", "FlightDeckWindscreenCentrePost",
			"ForwardCabinCrown", "FlightDeckWindscreenCowl", "FlightDeckQuarterlightSeal"]:
		var member := visual.get_node(member_name) as Node3D
		_check(member.is_visible_in_tree(), "freighter retains its actual pressure enclosure: " + member_name)
		retained[member] = member.transform
		if member is MeshInstance3D:
			retained[member] = [member.mesh, member.transform, member.material_override]
		if member_name in ["FreighterPressureWindscreen", "ForwardCabinCrown"]:
			for vertex: Vector3 in (member as MeshInstance3D).mesh.get_faces():
				enclosure_faces.append(ship.to_local(member.to_global(vertex)))
	var enclosed := true
	var samples := 0
	for member_name in ["InstrumentCluster/InstrumentHood", "PortSideConsole", "StarboardSideConsole"]:
		var member := cockpit.get_node(member_name) as MeshInstance3D
		var unique := {}
		for vertex: Vector3 in member.mesh.get_faces():
			var point := ship.to_local(member.to_global(vertex))
			if point.y < 1.17 or unique.has(point):
				continue
			unique[point] = true
			samples += 1
			for direction in [Vector3.UP, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD]:
				enclosed = enclosed and _flight_deck_ray_hits(enclosure_faces, point, direction)
	_check(enclosed and samples > 30, "actual freighter windshield and roof enclose the upper instrument hood and consoles")
	_check(not cockpit.get_node("RearPressureWall").visible,
		"retiring the inner canopy preserves the open passenger connection")
	# External boarding/exit still waits for the inherited timed completion.
	# Cabin-to-seat entry already bypasses that hatch transaction in GameFlow.
	var completed: Array[bool] = []
	var listener := func(open: bool) -> void: completed.append(open)
	ship.canopy_motion_finished.connect(listener)
	ship.set_canopy_open(true, 0.03)
	await ship.canopy_motion_finished
	ship.set_canopy_open(false, 0.03)
	await ship.canopy_motion_finished
	ship.canopy_motion_finished.disconnect(listener)
	_check(completed == [true, false] and not ship.is_canopy_open() and not hinge.visible,
		"hidden common pivot completes both timed boarding hatch transactions without reviving the nested canopy")
	for member: Node3D in retained:
		var state: Variant = member.transform
		if member is MeshInstance3D:
			state = [member.mesh, member.transform, member.material_override]
		_check(member.is_visible_in_tree() and retained[member] == state,
			"common hatch motion leaves the real fixed pressure enclosure intact")
