extends SceneTree

## Live import/material audit for the station-only symmetry-safe PBR tile and
## the CentralBerth authored UV0 correction. Ship-specific material identities
## remain deliberately outside the station material family.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const ALBEDO_PATH := "res://assets/materials/procedural-panel-triplanar-albedo-v2.png"
const NORMAL_PATH := "res://assets/materials/procedural-panel-triplanar-normal-v2.png"
const ROUGHNESS_PATH := "res://assets/materials/procedural-panel-triplanar-roughness-v2.png"
const TORRENT_HULL_PATH := "res://assets/materials/torrent-hull-albedo-v1.png"

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_imported_normal_direction()
	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "production Main scene instantiates for live texture audit")
	if game == null:
		_finish()
		return
	root.add_child(game)
	await process_frame
	await physics_frame
	var world := game.get_node_or_null(^"ShipyardWorld") as ShipyardWorld
	_check(world != null, "production ShipyardWorld is present")
	if world != null:
		_test_live_station_coverage(world)
		_test_live_central_deck_uv0(world)
	_test_four_ship_material_identity(game)
	game.queue_free()
	await process_frame
	_finish()


func _test_imported_normal_direction() -> void:
	var source := Image.load_from_file(ProjectSettings.globalize_path(NORMAL_PATH))
	var imported_texture := load(NORMAL_PATH) as Texture2D
	var imported := imported_texture.get_image() if imported_texture != null else null
	_check(
		source != null and not source.is_empty()
		and imported != null and not imported.is_empty()
		and source.get_size() == Vector2i(512, 512)
		and imported.get_size() == source.get_size(),
		"normal source and live imported texture are pixel-registered at 512 square"
	)
	if source == null or imported == null or source.is_empty() or imported.is_empty():
		return
	var directional_samples := 0
	var maximum_red_blue_error := 0.0
	var maximum_inverted_green_error := 0.0
	for y in range(0, source.get_height(), 3):
		for x in range(0, source.get_width(), 3):
			var encoded := source.get_pixel(x, y)
			if absf(encoded.g - 0.5) < 0.02:
				continue
			var live := imported.get_pixel(x, y)
			directional_samples += 1
			maximum_red_blue_error = maxf(
				maximum_red_blue_error,
				maxf(absf(live.r - encoded.r), absf(live.b - encoded.b))
			)
			maximum_inverted_green_error = maxf(
				maximum_inverted_green_error,
				absf(live.g - (1.0 - encoded.g))
			)
	_check(
		directional_samples >= 1000
		and maximum_red_blue_error <= 1.1 / 255.0
		and maximum_inverted_green_error <= 2.1 / 255.0,
		"live imported normal preserves X/Z and performs the exact effective tangent-Y inversion"
	)


func _test_live_station_coverage(world: ShipyardWorld) -> void:
	var mapped_surface_count := 0
	var scale_022_count := 0
	var scale_028_count := 0
	var scale_030_count := 0
	var exact_recipe := true
	var forbidden_ship_atlas_count := 0
	for candidate in world.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface_index in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.get_active_material(surface_index) as StandardMaterial3D
			if material == null:
				continue
			var albedo_path := _texture_path(material.albedo_texture)
			if "arrow-hull-" in albedo_path or "jovian-hull-" in albedo_path:
				forbidden_ship_atlas_count += 1
			if albedo_path != ALBEDO_PATH:
				continue
			mapped_surface_count += 1
			exact_recipe = (
				exact_recipe
				and material.normal_enabled
				and _texture_path(material.normal_texture) == NORMAL_PATH
				# Re-frozen from 0.48 by a rendered sweep at 0.48 / 1.0 / 1.4 / 1.9.
				# 0.48 left plated walls nearly featureless at eye height; 1.9 domed
				# the plate faces into embossed plastic on bright surfaces. 1.0 is the
				# highest sampled value with no doming in any frame. This stays an
				# exact equality on purpose: the whole point is that every module
				# shares one relief depth.
				and is_equal_approx(material.normal_scale, 1.0)
				and _texture_path(material.roughness_texture) == ROUGHNESS_PATH
				and material.roughness_texture_channel == BaseMaterial3D.TEXTURE_CHANNEL_RED
				and material.uv1_triplanar
				and material.uv1_world_triplanar
				and material.texture_repeat
			)
			if material.uv1_scale.is_equal_approx(Vector3.ONE * 0.22):
				scale_022_count += 1
			elif material.uv1_scale.is_equal_approx(Vector3.ONE * 0.28):
				scale_028_count += 1
			elif material.uv1_scale.is_equal_approx(Vector3.ONE * 0.30):
				scale_030_count += 1
			else:
				exact_recipe = false
	print(
		"LIVE_STATION_TRIPLANAR_COVERAGE: mapped=", mapped_surface_count,
		" scale_0.22=", scale_022_count,
		" scale_0.28=", scale_028_count,
		" scale_0.30=", scale_030_count
	)
	# Re-frozen from 507/11/262/234 when the walked-on overlays joined the family:
	# the Aft continuous stair ramp plus nine operations pressure plates (+10 at
	# 0.30) and the three Habitat connector/corridor/common floor insets (+3 at
	# 0.28). No previously mapped surface was removed and no scale changed.
	#
	# Re-frozen again from 520/11/265/244 by the MAP-001 stair-gate fix: the
	# stair-base landing gained a south and a west guard rail (+4 `warm_grey`
	# posts) and the eastern stair rail line no longer starts on the landing
	# (-1 post), a net +3 at the Aft module's 0.30 scale. The two new pod
	# threshold aprons use `deck_light`, which is not in this family, so they do
	# not appear here. No previously mapped surface was removed and no scale
	# changed.
	#
	# Re-frozen again from 523/11/265/247 when the last three unmapped station
	# populations joined the family, all at the Aft module's existing 0.30 scale
	# and all with the recipe copied verbatim:
	#
	#   `StationOperationsActivity` bound its four structural greys (`frame`,
	#   `frame_edge`, `graphite`, `ceramic`), adding 106 surfaces across the four
	#   production placements (FULL, GANTRY, SERVICE_ARM, DRONE_PATROL).
	#   `FleetDockComb` bound `deck`, `deck_light`, `frame`, `underframe` and
	#   `grip`, adding 33.
	#   `ShipyardWorld` bound `deck`, `deck_light`, `navy`, `blue`, `steel_blue`,
	#   `ivory` and `black`, adding 247. This was by far the largest gap: the hub
	#   owns roughly 6.6 thousand square metres of walkable deck plus keels,
	#   braces and pods, and `_material()` had produced pure scalar colour with no
	#   albedo, normal, roughness or triplanar at all.
	#
	#   `AftJunctionStack` additionally bound `mid_grey` and `hull_dark`, adding
	#   121. Those are the same two colours as its already-mapped `mid_grey_floor`
	#   and `hull_dark_floor`, so a wall was reading as plastic while the plated
	#   floor met it at the skirting.
	#
	# Net +368 mapped surfaces, 662 -> 1030. The 0.28 bucket returns to 265 because
	# the Fleet Dock comb moved from 0.28 to 0.30 to match the hub it bolts onto,
	# so no plate size changes across the connector seam; that is a move between
	# frozen buckets, not a new scale. 0.30 goes 353 -> 633. 0.22 is untouched.
	# Painted hazard bands, tyre rubber, transparent glass and every emissive
	# legend, route cue and beacon lens deliberately stay outside the family in
	# every module, so signage and lit cues keep their flat readable identity. No
	# previously mapped surface was removed and no new scale was introduced.
	#
	# Re-frozen again from 1154/115/285/754 by the structural-and-painted closing
	# pass, measured per key against the live scene:
	#
	#   `HabitatSpine.structural` +233 at 0.28. The module's primary structural
	#   grey: pressure ribs, service rails, bunk plinths, window mullions, chair
	#   pedestals. At eye height in a bunk bay it read as wet black plastic beside
	#   a plated wall, and it is by far the largest single population here.
	#   `AftJunctionStack.brass` +51 at 0.30 and `HabitatSpine.brass` +14 at 0.28.
	#   New non-emissive structural twins of the `gold` / `amber` cue colours. The
	#   cue colours keep every route arc tile, control lamp, cabinet status and
	#   sign; the twins take only the physical brass furniture — handrails,
	#   collars, column feet, fasteners — which were flat yellow sticks bolted to
	#   plated posts at arm's reach.
	#   `JovianFreightBerth.orange` +43 at 0.30. Painted handling steel: crane
	#   rails and feet, rack beams, apron and lattice diagonals, rail posts. It was
	#   the loudest untextured population left in the station.
	#
	# Net +341, 1154 -> 1495. 0.22 is untouched at 115; 0.28 goes 285 -> 532 and
	# 0.30 goes 754 -> 848. No previously mapped surface was removed and no new
	# scale was introduced. Deliberately still outside the family everywhere:
	# every emissive cue (`cyan`, `red`, `teal`, `amber`, `gold`, `*_glow`,
	# `worklight`), the `orange_glow` hazard and lane striping, transparent
	# `glass`, `rubber`, seating fabric, screens, the dark `graphite` seam and
	# reveal trim whose whole job is to read as a clean unbroken line, and the
	# `copper` pipe runs, which are drawn tube stock rather than panel.
	_check(
		mapped_surface_count == 1495
		and scale_022_count == 115
		and scale_028_count == 532
		and scale_030_count == 848,
		"live station binds exactly 1495 surfaces at the frozen 0.22/0.28/0.30 physical scales"
	)
	_check(exact_recipe, "every mapped station surface uses the matched world-triplanar albedo/normal/roughness recipe")
	_check(forbidden_ship_atlas_count == 0, "no live station surface reuses the Arrow or Jovian directional ship atlases")


func _test_four_ship_material_identity(game: GameFlow) -> void:
	var ship_specs := {
		"ArrowReconShip": "res://assets/materials/arrow-hull-albedo-v1.png",
		"JovianLightFreighter": "res://assets/materials/jovian-hull-albedo-v1.png",
		"TorrentInterceptor": TORRENT_HULL_PATH,
		"ZenithInterceptor": TORRENT_HULL_PATH,
	}
	for ship_name: String in ship_specs:
		var ship := game.get_node_or_null(NodePath(ship_name)) as Node3D
		var expected_path := str(ship_specs[ship_name])
		var expected_surface_count := 0
		var station_surface_count := 0
		if ship != null:
			for candidate in ship.find_children("*", "MeshInstance3D", true, false):
				var mesh_instance := candidate as MeshInstance3D
				if mesh_instance.mesh == null:
					continue
				for surface_index in mesh_instance.mesh.get_surface_count():
					var material := mesh_instance.get_active_material(surface_index) as StandardMaterial3D
					if material == null:
						continue
					var albedo_path := _texture_path(material.albedo_texture)
					expected_surface_count += 1 if albedo_path == expected_path else 0
					station_surface_count += 1 if albedo_path == ALBEDO_PATH else 0
		_check(
			ship != null and expected_surface_count > 0 and station_surface_count == 0,
			"%s retains its registered ship material identity and never binds the station tile" % ship_name
		)
	_test_torrent_zenith_uv0_tangent_handedness(game)


func _test_torrent_zenith_uv0_tangent_handedness(game: GameFlow) -> void:
	var mapped_surface_count := 0
	var positive_tangent_vertices := 0
	var negative_tangent_vertices := 0
	var complete_arrays := true
	for ship_name in ["TorrentInterceptor", "ZenithInterceptor"]:
		var ship := game.get_node_or_null(NodePath(ship_name)) as Node3D
		if ship == null:
			complete_arrays = false
			continue
		for candidate in ship.find_children("*", "MeshInstance3D", true, false):
			var mesh_instance := candidate as MeshInstance3D
			if mesh_instance.mesh == null:
				continue
			for surface_index in mesh_instance.mesh.get_surface_count():
				var material := mesh_instance.get_active_material(surface_index) as StandardMaterial3D
				if material == null or _texture_path(material.albedo_texture) != TORRENT_HULL_PATH:
					continue
				mapped_surface_count += 1
				complete_arrays = complete_arrays and not material.uv1_triplanar
				var arrays := mesh_instance.mesh.surface_get_arrays(surface_index)
				var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
				var uvs := arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array
				var tangents := arrays[Mesh.ARRAY_TANGENT] as PackedFloat32Array
				complete_arrays = (
					complete_arrays
					and not vertices.is_empty()
					and uvs.size() == vertices.size()
					and tangents.size() == vertices.size() * 4
				)
				for vertex_index in vertices.size():
					var tangent_w := tangents[vertex_index * 4 + 3]
					complete_arrays = complete_arrays and is_equal_approx(absf(tangent_w), 1.0)
					positive_tangent_vertices += 1 if tangent_w > 0.0 else 0
					negative_tangent_vertices += 1 if tangent_w < 0.0 else 0
	_check(
		mapped_surface_count == 9
		and complete_arrays
		and positive_tangent_vertices > 8000
		and negative_tangent_vertices > 29000,
		"Torrent/Zenith keep explicit UV0 and valid ±1 tangent handedness across mirrored authored islands"
	)


func _test_live_central_deck_uv0(world: ShipyardWorld) -> void:
	var presentation := world.get_central_berth_hero_presentation()
	var deck_root := presentation.get_semantic_root(&"deck_panels") if presentation != null else null
	var mesh_instance: MeshInstance3D
	if deck_root != null:
		for candidate in deck_root.find_children("*", "MeshInstance3D", true, false):
			if StringName(candidate.get_meta("central_berth_material_role", &"")) == &"DeckComposite":
				mesh_instance = candidate as MeshInstance3D
				break
	_check(mesh_instance != null, "live imported CentralBerth DeckComposite mesh is present")
	if mesh_instance == null:
		return
	var anisotropy_values: Array[float] = []
	var density_values: Array[float] = []
	var degenerate_count := 0
	var canonical_axis_count := 0
	for surface_index in mesh_instance.mesh.get_surface_count():
		var arrays := mesh_instance.mesh.surface_get_arrays(surface_index)
		var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var normals := arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
		var uvs := arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array
		var indices := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
		for triangle_index in indices.size() / 3:
			var i0 := indices[triangle_index * 3]
			var i1 := indices[triangle_index * 3 + 1]
			var i2 := indices[triangle_index * 3 + 2]
			var normal := (normals[i0] + normals[i1] + normals[i2]).normalized()
			if normal.y < 0.9:
				continue
			var duv1 := uvs[i1] - uvs[i0]
			var duv2 := uvs[i2] - uvs[i0]
			var uv_determinant := duv1.cross(duv2)
			if absf(uv_determinant) <= 0.000001:
				degenerate_count += 1
				continue
			var p1 := Vector2(vertices[i1].x - vertices[i0].x, vertices[i1].z - vertices[i0].z)
			var p2 := Vector2(vertices[i2].x - vertices[i0].x, vertices[i2].z - vertices[i0].z)
			var dp_du := (p1 * duv2.y - p2 * duv1.y) / uv_determinant
			var dp_dv := (-p1 * duv2.x + p2 * duv1.x) / uv_determinant
			var gram_a := dp_du.dot(dp_du)
			var gram_b := dp_du.dot(dp_dv)
			var gram_c := dp_dv.dot(dp_dv)
			var discriminant := sqrt(maxf((gram_a - gram_c) * (gram_a - gram_c) + 4.0 * gram_b * gram_b, 0.0))
			var lambda_max := maxf((gram_a + gram_c + discriminant) * 0.5, 0.0)
			var lambda_min := maxf((gram_a + gram_c - discriminant) * 0.5, 0.0)
			if lambda_min <= 0.000001:
				degenerate_count += 1
				continue
			anisotropy_values.append(sqrt(lambda_max / lambda_min))
			var jacobian_determinant := dp_du.cross(dp_dv)
			density_values.append(sqrt(absf(jacobian_determinant)))
			if (
				jacobian_determinant < 0.0
				and dp_du.normalized().dot(Vector2.RIGHT) >= 0.99
				and dp_dv.normalized().dot(Vector2(0.0, -1.0)) >= 0.99
			):
				canonical_axis_count += 1
	anisotropy_values.sort()
	density_values.sort()
	var sample_count := anisotropy_values.size()
	var median_density := density_values[sample_count / 2] if sample_count > 0 else 0.0
	var maximum_density_deviation := 99.0
	if sample_count > 0 and median_density > 0.0:
		maximum_density_deviation = 0.0
		for density in density_values:
			maximum_density_deviation = maxf(maximum_density_deviation, absf(density - median_density) / median_density)
	var p95_anisotropy := anisotropy_values[mini(int(sample_count * 0.95), sample_count - 1)] if sample_count > 0 else 99.0
	var maximum_anisotropy := anisotropy_values[-1] if sample_count > 0 else 99.0
	_check(
		sample_count == 190
		and degenerate_count == 0
		and maximum_anisotropy <= 2.0
		and p95_anisotropy <= 1.25
		and maximum_density_deviation <= 0.25,
		"live imported CentralBerth top UV0 has uniform singular-value density with no degenerates"
	)
	_check(
		canonical_axis_count == sample_count,
		"all live CentralBerth top triangles use canonical non-mirrored +U→+X, +V→−Z axes"
	)


func _texture_path(texture: Texture2D) -> String:
	return texture.resource_path if texture != null else ""


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("STATION_TRIPLANAR_MATERIAL_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		print("STATION_TRIPLANAR_MATERIAL_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
