extends SceneTree

## Freezes the fleet-wide surface treatment applied to secondary structure.
##
## The audited defect. Every craft rendered as two visual populations. Hull
## lofts and authored hull shells carried a registered albedo/normal/roughness
## family and read as manufactured plate; everything else — engine housings,
## landing gear, collars, escape pods, cargo hardware, deck plate, thermal
## panels, livery — carried a flat scalar `albedo_color` and no map of any
## kind. On top of that, each craft's structural roughness sat inside a narrow
## band, so two structural surfaces differed in hue and in nothing else.
##
## Measured over exactly the material sets listed below, the structural
## roughness spread before this pass was Arrow 0.12, Jovian 0.22, Zenith 0.28
## and Torrent 0.44 — and the Torrent figure is carried entirely by its seat
## and heat panels, with its four exterior structural surfaces sitting inside
## 0.22 of each other. After the pass: Arrow 0.44, Zenith 0.50, Jovian 0.52,
## Torrent 0.68.
##
## What this suite asserts.
##
## 1. Every named structural material on all four craft carries the shared
##    treatment from `ShipSurfaceDetail`: relief from its own craft's
##    registered normal map, projected triplanar so no UV is authored.
## 2. No structural material binds an albedo texture. The scalar colours are
##    what `tests/fleet_role_differentiation_test.gd` measures for the frozen
##    CIEDE2000 body and accent floors, and this suite is the guard that a
##    later surface pass cannot quietly start painting over them.
## 3. No structural material binds a roughness texture, so its `roughness`
##    property is the roughness the player sees and the spread below is a real
##    measurement rather than a scalar that has to be multiplied by a map mean.
## 4. Each craft's structural roughness spread clears a floor of 0.40. This is
##    a non-regression floor in the sense used elsewhere in this project: it is
##    set below every measured value so a later feel pass can only widen it.
## 5. Hull materials keep their existing texture-coordinate policy. The Torrent
##    and Zenith presentations both publish `hull_triplanar: false` alongside
##    an authored-UV0 claim, and the treatment must not spill onto them.
##
## No colour, geometry, collision, handling or authority value is read or
## modified anywhere in this suite.

const TORRENT_SCENE := preload("res://scenes/ships/torrent_interceptor.tscn")
const ARROW_SCENE := preload("res://scenes/ships/arrow_recon_ship.tscn")
const JOVIAN_SCENE := preload("res://scenes/ships/jovian_light_freighter.tscn")
const ZENITH_SCENE := preload("res://scenes/ships/zenith_interceptor.tscn")
const RANGE_OPPONENT_SCENE := preload("res://scenes/ships/range_opponent.tscn")
const STANDOFF_PICKET_SCENE := preload("res://scenes/ships/standoff_picket_opponent.tscn")

# Structural material keys per craft. These are the parts a player reported as
# "strange looking objects": the flat-shaded population beside a textured hull.
const ARROW_STRUCTURAL_KEYS := ["titanium", "graphite", "pod"]
const JOVIAN_STRUCTURAL_KEYS := ["structure", "dark", "amber", "cargo_blue", "deck"]
const TORRENT_STRUCTURAL_ROLES := [
	&"GraphiteMachinery", &"ExposedAlloy", &"CrimsonSeat", &"CrimsonLivery",
	&"ThermalCeramic",
]
const ZENITH_STRUCTURAL_ROLES := [&"GraphitePanel", &"EngineGraphite", &"ExposedAlloy"]

# Hull material keys, which must keep the mapping policy their craft declares.
const ARROW_HULL_KEYS := ["pearl", "ceramic"]
const JOVIAN_HULL_KEYS := ["hull_warm", "hull_cool"]
const TORRENT_HULL_ROLES := [&"WarmIvoryHull", &"IvorySecondary"]
const ZENITH_HULL_ROLES := [&"PaleCeramicHull", &"PaleFacetSecondary"]

# Minimum difference between a craft's most matte and most glossy structural
# surface. Measured after the pass: Arrow 0.44, Zenith 0.50, Jovian 0.52,
# Torrent 0.68. Frozen below all four so this can only be improved.
const STRUCTURAL_ROUGHNESS_SPREAD_FLOOR := 0.40

## Live chamfered-cylinder population per craft: `[surfaces, triangles]`.
##
## Frozen in the open, old -> new, after dropping the four lateral wall rings
## every craft inherited from `CylinderMesh.rings`:
##
##   Torrent          51 surfaces  25,600 -> 12,544 tris
##   Arrow            39 surfaces  22,464 -> 11,232 tris
##   Jovian           85 surfaces  43,520 -> 21,760 tris
##   RangeOpponent    12 surfaces   5,376 ->  2,688 tris
##   StandoffPicket   12 surfaces   5,376 ->  2,688 tris
##   Zenith            0 surfaces       0 ->      0 tris  (authored .glb)
##
## Whole-craft totals moved by exactly the same amounts: Torrent 152,556 ->
## 139,500, Arrow 77,244 -> 66,012, Jovian 98,268 -> 76,508, RangeOpponent
## 6,796 -> 4,108, StandoffPicket 7,432 -> 4,744, Zenith 52,686 unchanged. In
## the live `scenes/main.tscn` the fleet's share of the change is 199 surfaces
## and 1,374,466 -> 1,323,042 triangles, i.e. -51,424 (-3.74%).
##
## This freezes the population this pass touched rather than each craft's whole
## triangle budget, so an unrelated ship edit is not forced through this suite;
## a wall-subdivision regression still lands on it exactly.
const CHAMFERED_CYLINDER_POPULATION := {
	"Torrent": [51, 12_544],
	"Arrow": [39, 11_232],
	"Jovian": [85, 21_760],
	"RangeOpponent": [12, 2_688],
	"StandoffPicket": [12, 2_688],
	"Zenith": [0, 0],
}

## Radial-segment counts the fleet's `_cylinder`/`_frustum` builders pass.
const LIVE_RADIAL_SEGMENTS := [28, 32, 36]

var _assertions := 0
var _failures: Array[String] = []
var _evidence: Array[String] = []
var _test_root: Node3D


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_root = Node3D.new()
	_test_root.name = "FleetSurfaceDetailTestRoot"
	root.add_child(_test_root)

	await _audit_procedural_craft(ARROW_SCENE, "Arrow", ARROW_STRUCTURAL_KEYS, ARROW_HULL_KEYS, true)
	await _audit_procedural_craft(
		JOVIAN_SCENE, "Jovian", JOVIAN_STRUCTURAL_KEYS, JOVIAN_HULL_KEYS, true
	)
	await _audit_torrent()
	await _audit_zenith()
	_audit_helper_contract()
	_audit_cylinder_wall_is_free_to_flatten()
	await _audit_cylinder_wall_population()

	_test_root.queue_free()
	await process_frame
	_finish()


## Arrow and Jovian build their own materials in-script and publish them
## through the shared `get_variant_materials()` API.
func _audit_procedural_craft(
		scene: PackedScene,
		label: String,
		structural_keys: Array,
		hull_keys: Array,
		hull_is_triplanar: bool
	) -> void:
	var craft := scene.instantiate() as HeroShip
	_check(craft != null, "%s scene instantiates as a HeroShip" % label)
	if craft == null:
		return
	_test_root.add_child(craft)
	await process_frame
	await physics_frame
	var materials := craft.get_variant_materials()
	var structural: Array[StandardMaterial3D] = []
	for key: String in structural_keys:
		var material := materials.get(key) as StandardMaterial3D
		_check(material != null, "%s publishes its %s structural material" % [label, key])
		if material == null:
			continue
		structural.append(material)
		_audit_structural_material(material, "%s %s" % [label, key])
	_audit_roughness_spread(structural, label)
	for key: String in hull_keys:
		var hull := materials.get(key) as StandardMaterial3D
		_check(
			hull != null and hull.albedo_texture != null,
			"%s %s keeps its registered hull base-colour map" % [label, key]
		)
		_check(
			hull != null and hull.uv1_triplanar == hull_is_triplanar,
			"%s %s keeps its declared hull texture-coordinate policy" % [label, key]
		)
	craft.queue_free()
	await process_frame


## The visible Torrent is the Blender hero presentation; the procedural
## macroform is a hidden fallback. Read the live `material_override` on the
## imported meshes so this proves the treatment actually reached geometry.
func _audit_torrent() -> void:
	var torrent := TORRENT_SCENE.instantiate() as HeroShip
	_check(torrent != null, "Torrent scene instantiates as a HeroShip")
	if torrent == null:
		return
	_test_root.add_child(torrent)
	await process_frame
	await physics_frame
	var presentation := torrent.find_child("TorrentHeroPresentation", true, false)
	_check(presentation != null, "Torrent installs its hero presentation")
	var by_role := _collect_live_role_materials(presentation, "torrent_material_role")
	var structural: Array[StandardMaterial3D] = []
	for role: StringName in TORRENT_STRUCTURAL_ROLES:
		var material := by_role.get(role) as StandardMaterial3D
		_check(material != null, "Torrent renders geometry in its %s role" % role)
		if material == null:
			continue
		structural.append(material)
		_audit_structural_material(material, "Torrent %s" % role)
	_audit_roughness_spread(structural, "Torrent")
	for role: StringName in TORRENT_HULL_ROLES:
		var hull := by_role.get(role) as StandardMaterial3D
		_check(
			hull != null and hull.albedo_texture != null and not hull.uv1_triplanar,
			"Torrent %s keeps its authored UV0 hull mapping" % role
		)
	torrent.queue_free()
	await process_frame


func _audit_zenith() -> void:
	var zenith := ZENITH_SCENE.instantiate() as ZenithInterceptor
	_check(zenith != null, "Zenith scene instantiates as a ZenithInterceptor")
	if zenith == null:
		return
	_test_root.add_child(zenith)
	await process_frame
	await physics_frame
	var presentation := zenith.get_zenith_authored_presentation()
	_check(presentation != null, "Zenith installs its authored presentation")
	var by_role := _collect_live_role_materials(presentation, "zenith_material_role")
	var structural: Array[StandardMaterial3D] = []
	for role: StringName in ZENITH_STRUCTURAL_ROLES:
		var material := by_role.get(role) as StandardMaterial3D
		_check(material != null, "Zenith renders geometry in its %s role" % role)
		if material == null:
			continue
		structural.append(material)
		_audit_structural_material(material, "Zenith %s" % role)
	_audit_roughness_spread(structural, "Zenith")
	for role: StringName in ZENITH_HULL_ROLES:
		var hull := by_role.get(role) as StandardMaterial3D
		_check(
			hull != null and hull.albedo_texture != null and not hull.uv1_triplanar,
			"Zenith %s keeps its authored UV0 hull mapping" % role
		)
	# The SourceCore subtree is the B7-observed macroform. Its finish is free,
	# but nothing in this pass may have introduced an albedo texture there that
	# would start making colour claims the source does not support.
	var source_core := presentation.find_child("SourceCore", true, false) if presentation != null else null
	var source_core_albedo_textures := 0
	if source_core != null:
		for candidate in source_core.find_children("*", "MeshInstance3D", true, false):
			var material := (candidate as MeshInstance3D).material_override as StandardMaterial3D
			if material != null and material.albedo_texture != null:
				source_core_albedo_textures += 1
	_check(
		source_core != null and source_core_albedo_textures > 0,
		"Zenith SourceCore still renders through its registered hull maps"
	)
	zenith.queue_free()
	await process_frame


func _collect_live_role_materials(presentation: Node, meta_key: String) -> Dictionary:
	var by_role: Dictionary = {}
	if presentation == null:
		return by_role
	for candidate in presentation.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		var role := StringName(mesh_instance.get_meta(meta_key, &""))
		if role.is_empty():
			continue
		var material := mesh_instance.material_override as StandardMaterial3D
		if material != null:
			by_role[role] = material
	return by_role


func _audit_structural_material(material: StandardMaterial3D, label: String) -> void:
	_check(
		ShipSurfaceDetail.has_structural_detail(material),
		"%s carries the shared structural surface treatment" % label
	)
	_check(
		material.albedo_texture == null,
		"%s keeps its scalar colour authority and binds no albedo texture" % label
	)
	_check(
		material.roughness_texture == null,
		"%s keeps its roughness scalar honest and binds no roughness map" % label
	)
	_check(
		material.normal_scale > 0.0,
		"%s applies a non-zero relief strength" % label
	)


func _audit_roughness_spread(structural: Array[StandardMaterial3D], label: String) -> void:
	if structural.is_empty():
		_check(false, "%s exposes structural materials to measure" % label)
		return
	var minimum := 2.0
	var maximum := -1.0
	for material in structural:
		minimum = minf(minimum, material.roughness)
		maximum = maxf(maximum, material.roughness)
	var spread := maximum - minimum
	_evidence.append("%s structural roughness %.2f-%.2f spread %.2f" % [label, minimum, maximum, spread])
	_check(
		spread >= STRUCTURAL_ROUGHNESS_SPREAD_FLOOR,
		"%s structural surfaces differ in material response, not only in hue (spread %.2f >= %.2f)"
			% [label, spread, STRUCTURAL_ROUGHNESS_SPREAD_FLOOR]
	)


## Boundary and structured-red cases for the shared helper itself. Each of
## these must make the audit predicate go false, so the suite cannot pass on a
## craft whose treatment silently fell off.
func _audit_helper_contract() -> void:
	var normal_map := load("res://assets/materials/torrent-hull-normal-v1.png") as Texture2D
	_check(normal_map != null, "a registered normal map loads for the helper boundary cases")
	_check(
		not ShipSurfaceDetail.bind_structural_detail(null, normal_map, 1.0, 0.5),
		"binding refuses a null material instead of silently succeeding"
	)
	var untreated := StandardMaterial3D.new()
	_check(
		not ShipSurfaceDetail.bind_structural_detail(untreated, null, 1.0, 0.5),
		"binding refuses a missing normal map instead of leaving a half-treated material"
	)
	_check(
		not ShipSurfaceDetail.has_structural_detail(untreated),
		"a refused binding leaves the material detectably untreated"
	)
	var treated := StandardMaterial3D.new()
	_check(
		ShipSurfaceDetail.bind_structural_detail(treated, normal_map, 1.25, 0.6)
		and ShipSurfaceDetail.has_structural_detail(treated)
		and treated.uv1_triplanar
		and is_equal_approx(treated.uv1_scale.x, 1.25)
		and is_equal_approx(treated.normal_scale, 0.6),
		"binding applies exactly the requested triplanar scale and relief strength"
	)
	# Structured red: each of the three properties the audit depends on must be
	# load-bearing on its own.
	var mutated := StandardMaterial3D.new()
	ShipSurfaceDetail.bind_structural_detail(mutated, normal_map, 1.0, 0.5)
	mutated.normal_enabled = false
	_check(
		not ShipSurfaceDetail.has_structural_detail(mutated),
		"disabling normal mapping turns the treatment audit red"
	)
	mutated.normal_enabled = true
	mutated.uv1_triplanar = false
	_check(
		not ShipSurfaceDetail.has_structural_detail(mutated),
		"dropping triplanar projection turns the treatment audit red"
	)
	mutated.uv1_triplanar = true
	mutated.albedo_texture = normal_map
	_check(
		not ShipSurfaceDetail.has_structural_detail(mutated),
		"painting an albedo texture over a structural colour turns the treatment audit red"
	)
	mutated.albedo_texture = null
	mutated.roughness_texture = normal_map
	_check(
		not ShipSurfaceDetail.has_structural_detail(mutated),
		"binding a roughness map over an honest roughness scalar turns the treatment audit red"
	)


## The fleet builds its cylinders and frustums with no lateral wall
## subdivision. This proves that is an edge-free reduction rather than a quality
## trade, by checking the property the reduction rests on directly: a wall quad
## is planar, so the four rings Godot's primitive defaults to add vertices that
## are already on the surface the two-triangle version interpolates.
##
## Checked at every radial-segment count the live builders pass, on a straight
## cylinder and on a taper in both directions, because the taper is the case
## where "the rings do nothing" is least obvious.
func _audit_cylinder_wall_is_free_to_flatten() -> void:
	_check(
		ShipSurfaceDetail.CYLINDER_WALL_RINGS == 0,
		"the fleet builds cylinder and frustum walls with no lateral subdivision"
	)
	var profiles := [
		[0.42, 0.42, 1.60], [0.84, 0.84, 0.30], [0.025, 0.025, 0.90],
		[0.30, 0.62, 1.10], [0.62, 0.30, 1.10],
	]
	var dense_rings := StationSurfaceKit.CYLINDER_DEFAULT_RINGS
	for segments: int in LIVE_RADIAL_SEGMENTS:
		for profile: Array in profiles:
			var top: float = profile[0]
			var bottom: float = profile[1]
			var height: float = profile[2]
			var flat := StationSurfaceKit.chamfered_cylinder_mesh(
				top, bottom, height, segments, ShipSurfaceDetail.CYLINDER_WALL_RINGS
			)
			var dense := StationSurfaceKit.chamfered_cylinder_mesh(
				top, bottom, height, segments, dense_rings
			)
			var label := "%0.3f/%0.3f x %0.3f at %d segments" % [top, bottom, height, segments]
			# 1. The bounding box is the silhouette's outer bound. If subdivision
			#    were resolving anything, removing it would pull this in.
			var flat_box := flat.get_aabb()
			var dense_box := dense.get_aabb()
			_check(
				flat_box.position.is_equal_approx(dense_box.position)
				and flat_box.size.is_equal_approx(dense_box.size),
				"wall subdivision does not move the AABB of %s" % label
			)
			# 2. Every vertex the dense build adds lies exactly on the profile
			#    line the flat build spans, so no ring is inside or outside the
			#    silhouette. This is the whole claim, stated as a measurement.
			var half_height := height * 0.5
			var worst_offset := 0.0
			var dense_arrays := dense.surface_get_arrays(0)
			var dense_vertices: PackedVector3Array = dense_arrays[Mesh.ARRAY_VERTEX]
			for vertex in dense_vertices:
				var expected := StationSurfaceKit._radius_at(top, bottom, half_height, vertex.y)
				var actual := Vector2(vertex.x, vertex.z).length()
				# Cap and chamfer vertices sit inside the profile by design; only
				# the wall is under audit here.
				if actual <= expected - 0.0001:
					continue
				worst_offset = maxf(worst_offset, absf(actual - expected))
			_check(
				worst_offset <= 0.0001,
				"no subdivided wall vertex leaves the profile line on %s (worst %.7f m)"
					% [label, worst_offset]
			)
			# 3. The normal set is identical, so nothing shades differently. A
			#    wall's profile is one straight segment, so every sub-band is
			#    handed the same normal the single band gets.
			_check(
				_distinct_normals(flat) == _distinct_normals(dense),
				"wall subdivision adds no distinct normal to %s" % label
			)
			# 4. And the saving is exactly the four rings' worth of wall quads.
			_check(
				_mesh_triangles(dense) - _mesh_triangles(flat) == dense_rings * 2 * segments,
				"flattening %s saves exactly %d triangles" % [label, dense_rings * 2 * segments]
			)


## Exact live population freeze. See `CHAMFERED_CYLINDER_POPULATION`.
func _audit_cylinder_wall_population() -> void:
	var scenes := {
		"Torrent": TORRENT_SCENE, "Arrow": ARROW_SCENE, "Jovian": JOVIAN_SCENE,
		"Zenith": ZENITH_SCENE, "RangeOpponent": RANGE_OPPONENT_SCENE,
		"StandoffPicket": STANDOFF_PICKET_SCENE,
	}
	for label: String in scenes:
		var craft: Node = (scenes[label] as PackedScene).instantiate()
		_test_root.add_child(craft)
		await process_frame
		await physics_frame
		var surfaces := 0
		var triangles := 0
		for candidate in craft.find_children("*", "MeshInstance3D", true, false):
			var mesh := (candidate as MeshInstance3D).mesh
			if mesh == null or not (mesh is ArrayMesh):
				continue
			if mesh.resource_name != StationSurfaceKit.CHAMFERED_CYLINDER_RESOURCE_NAME:
				continue
			surfaces += mesh.get_surface_count()
			triangles += _mesh_triangles(mesh)
		var frozen: Array = CHAMFERED_CYLINDER_POPULATION[label]
		_evidence.append(
			"%s chamfered cylinders: %d surfaces, %d triangles" % [label, surfaces, triangles]
		)
		_check(
			surfaces == int(frozen[0]) and triangles == int(frozen[1]),
			"%s renders exactly %d chamfered-cylinder surfaces at %d triangles (got %d/%d)"
				% [label, int(frozen[0]), int(frozen[1]), surfaces, triangles]
		)
		craft.queue_free()
		await process_frame


func _distinct_normals(mesh: ArrayMesh) -> Array:
	var seen := {}
	var normals: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	for normal in normals:
		seen["%0.5f,%0.5f,%0.5f" % [normal.x, normal.y, normal.z]] = true
	var keys := seen.keys()
	keys.sort()
	return keys


func _mesh_triangles(mesh: Mesh) -> int:
	var total := 0
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		if arrays.is_empty():
			continue
		var indices = arrays[Mesh.ARRAY_INDEX]
		if indices != null and indices.size() > 0:
			total += indices.size() / 3
		else:
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			total += vertices.size() / 3
	return total


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	for line in _evidence:
		print("MEASURED: ", line)
	if _failures.is_empty():
		print("FLEET_SURFACE_DETAIL_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		print("FLEET_SURFACE_DETAIL_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
