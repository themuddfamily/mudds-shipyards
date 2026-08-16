extends SceneTree

## Front-face winding contract for the fleet's procedural mesh builders.
##
## `tests/station_surface_winding_test.gd` guards the station kit. It was written
## for commit 806d2ff, which fixed `StationSurfaceKit.rounded_box_mesh_with_bevel`
## and `JovianFreightBerth._add_quad` after the player reported that "a lot of
## materials look inside out **again**". That fix never reached
## `HeroShip._rounded_box_mesh`, which is a copy of the same algorithm carrying
## the same `0-1-2 / 0-2-3` emission order, and which every `_box()` on the
## Torrent, the Arrow, the Zenith and the Jovian goes through. Measured against
## the engine's own primitives it scored 108 of 108 triangles backwards on every
## size tried, where the fixed kit box scores 0 of 108. This suite is the missing
## half of that guard: the ship side.
##
## Why winding is not cosmetic: emission order *is* the front-face winding, and
## it has to agree with the outward normal each vertex already carries. When it
## disagrees Godot culls the outward faces and draws the unlit inside of the back
## faces instead — a hull plate becomes a black hole, a landing skid becomes a
## silhouette. Every structural assertion still passes, because the node, the
## mesh, the material and the triangle count are all exactly as expected. That is
## why 97 suites and roughly 8,500 assertions never caught it.
##
## The convention is *calibrated*, never hard-coded. Godot's own primitives are
## the ground truth: on a correctly wound surface `(b - a) x (c - a)` points
## opposite the shading normal, because Godot's front face is the clockwise one
## seen from outside. Deriving the sign from `BoxMesh`, `CylinderMesh` and
## `SphereMesh` at runtime means this suite still holds if the engine ever
## changes that convention.

const ENGINE_CALIBRATION_MESHES := ["BoxMesh", "CylinderMesh", "SphereMesh"]

## Every craft that inherits `HeroShip._box`, plus the Halyard, which shadows it
## onto the kit. All five are swept whole so a craft that grows new geometry is
## covered the moment it is added.
const CRAFT_SCENES := {
	"Torrent (HeroShip)": "res://scenes/ships/torrent_interceptor.tscn",
	"Arrow": "res://scenes/ships/arrow_recon_ship.tscn",
	"Zenith": "res://scenes/ships/zenith_interceptor.tscn",
	"Jovian": "res://scenes/ships/jovian_light_freighter.tscn",
	"Halyard": "res://scenes/ships/halyard_crew_transport.tscn",
}

var _failures: Array[String] = []
var _assertions := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var expected_sign := _calibrate()
	if expected_sign == 0:
		_fail("engine primitives did not agree on a single winding convention")
		_finish()
		return

	_check_hero_builders(expected_sign)
	await _check_craft(expected_sign)
	_check_detects_reversal(expected_sign)
	_finish()


## Derives the correct sign of `dot((b - a) x (c - a), normal)` from meshes the
## engine authors itself. Returns 0 if they disagree.
func _calibrate() -> int:
	var signs: Dictionary = {}
	for mesh_class in ENGINE_CALIBRATION_MESHES:
		var mesh := ClassDB.instantiate(mesh_class) as Mesh
		if mesh == null:
			continue
		var report := _score(mesh)
		var triangles := int(report["triangles"])
		var agreeing := int(report["agreeing"])
		if triangles == 0:
			continue
		if agreeing == 0:
			signs[-1] = true
		elif agreeing == triangles:
			signs[1] = true
		else:
			signs[0] = true
	_assert(
		signs.size() == 1 and not signs.has(0),
		"engine primitives (%s) share one consistent front-face winding" % ", ".join(ENGINE_CALIBRATION_MESHES)
	)
	if signs.size() != 1 or signs.has(0):
		return 0
	return -1 if signs.has(-1) else 1


## The two builders `HeroShip` owns outright, measured directly rather than
## through a craft, so the defect is named at its source.
func _check_hero_builders(expected_sign: int) -> void:
	var hero := HeroShip.new()
	for size: Vector3 in [
		Vector3(2.0, 2.0, 2.0),
		Vector3(4.3, 2.8, 1.6),
		# A cockpit display substrate: thinner than the bevel clamp on one axis.
		Vector3(0.78, 0.27, 0.025),
		# A long thin rail, where the bevel is clamped by the smallest extent.
		Vector3(0.22, 0.22, 1.45),
	]:
		_assert_wound(
			"HeroShip._rounded_box_mesh %v" % size,
			hero.call("_rounded_box_mesh", size, null) as ArrayMesh,
			expected_sign
		)
	_assert_wound(
		"HeroShip._trapezoid_prism_mesh",
		hero.call("_trapezoid_prism_mesh", 1.0, 2.0, 1.5, 0.5, null) as ArrayMesh,
		expected_sign
	)
	hero.free()


## Sweeps every mesh each craft actually builds, not a representative sample, so
## a craft that grows new geometry is covered the moment it is added.
##
## Scope is the geometry this project's own GDScript emits at run time — those
## meshes have an empty `resource_path`. Imported art (`*.glb`, `*.obj`) is
## counted and named but not asserted on: it is authored in `tools/blender/`,
## guarded by `tests/torrent_blender_hero_asset_test.gd` and
## `tests/zenith_authored_asset_test.gd`, and its winding is a property of the
## exporter rather than of any emission order here. The Torrent's hero `.glb`
## carries six triangles whose smoothed vertex normals lie across a chamfer and
## therefore score as disagreeing; reporting the imported tally keeps that
## exclusion visible instead of silent.
##
## The Zenith is entirely authored art and contributes no procedural geometry at
## all. That is asserted explicitly rather than skipped, so if it ever starts
## building meshes in script they land inside this contract instead of outside
## it, and so a silent loss of its imported geometry still trips the suite.
func _check_craft(expected_sign: int) -> void:
	var fleet_triangles := 0
	var procedural_craft := 0
	for label: String in CRAFT_SCENES:
		var packed := load(CRAFT_SCENES[label]) as PackedScene
		if packed == null:
			_fail("%s scene did not load" % label)
			continue
		var craft := packed.instantiate()
		root.add_child(craft)
		await process_frame
		await process_frame

		var triangles := 0
		var backwards := 0
		var meshes := 0
		var imported_meshes := 0
		var worst: Array[String] = []
		for candidate in craft.find_children("*", "MeshInstance3D", true, false):
			var instance := candidate as MeshInstance3D
			if instance == null or instance.mesh == null:
				continue
			if not instance.mesh.resource_path.is_empty():
				imported_meshes += 1
				continue
			meshes += 1
			var report := _score(instance.mesh)
			var mesh_triangles := int(report["triangles"])
			var agreeing := int(report["agreeing"])
			var mesh_backwards := agreeing if expected_sign == -1 else mesh_triangles - agreeing
			triangles += mesh_triangles
			backwards += mesh_backwards
			if mesh_backwards > 0 and worst.size() < 6:
				worst.append("%s (%d/%d)" % [instance.name, mesh_backwards, mesh_triangles])
		if meshes == 0:
			_assert(
				imported_meshes > 0,
				"%s is entirely authored art (0 procedural meshes, %d imported)" % [label, imported_meshes]
			)
		else:
			procedural_craft += 1
			fleet_triangles += triangles
			_assert(
				triangles > 0 and backwards == 0,
				"%s winds all %d procedural triangles across %d meshes outward (%d backwards%s; %d imported meshes out of scope)" % [
					label, triangles, meshes, backwards,
					"" if worst.is_empty() else ": " + ", ".join(worst),
					imported_meshes,
				]
			)
		root.remove_child(craft)
		craft.queue_free()
		await process_frame

	# Vacuity guard: the per-craft assertions above would all pass if every craft
	# quietly stopped building geometry. The Torrent, the Arrow, the Jovian and
	# the Halyard all build theirs in script.
	_assert(
		procedural_craft >= 4 and fleet_triangles > 100000,
		"the fleet sweep scored real geometry (%d procedural triangles across %d craft)"
		% [fleet_triangles, procedural_craft]
	)


## Structured-red control: a deliberately reversed copy of a builder mesh must be
## rejected. Without this the suite could pass by measuring nothing.
func _check_detects_reversal(expected_sign: int) -> void:
	var hero := HeroShip.new()
	var source := hero.call("_rounded_box_mesh", Vector3(2.0, 2.0, 2.0), null) as ArrayMesh
	hero.free()
	var arrays: Array = source.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var reversed_verts := PackedVector3Array()
	var reversed_norms := PackedVector3Array()
	var index := 0
	while index + 2 < verts.size():
		reversed_verts.append(verts[index])
		reversed_verts.append(verts[index + 2])
		reversed_verts.append(verts[index + 1])
		reversed_norms.append(norms[index])
		reversed_norms.append(norms[index + 2])
		reversed_norms.append(norms[index + 1])
		index += 3
	var reversed_arrays: Array = []
	reversed_arrays.resize(Mesh.ARRAY_MAX)
	reversed_arrays[Mesh.ARRAY_VERTEX] = reversed_verts
	reversed_arrays[Mesh.ARRAY_NORMAL] = reversed_norms
	var reversed_mesh := ArrayMesh.new()
	reversed_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, reversed_arrays)

	var report := _score(reversed_mesh)
	var triangles := int(report["triangles"])
	var agreeing := int(report["agreeing"])
	var backwards := agreeing if expected_sign == -1 else triangles - agreeing
	_assert(
		triangles > 0 and backwards == triangles,
		"a deliberately reversed HeroShip box is detected as fully backwards (%d/%d)" % [backwards, triangles]
	)


func _assert_wound(label: String, mesh: Mesh, expected_sign: int) -> void:
	if mesh == null:
		_fail("%s produced no mesh" % label)
		return
	var report := _score(mesh)
	var triangles := int(report["triangles"])
	var agreeing := int(report["agreeing"])
	var backwards := agreeing if expected_sign == -1 else triangles - agreeing
	_assert(
		triangles > 0 and backwards == 0,
		"%s winds every one of its %d triangles to face outward (%d backwards)"
		% [label, triangles, backwards]
	)


## Counts triangles whose CCW geometric normal agrees with the shading normal.
func _score(mesh: Mesh) -> Dictionary:
	var triangles := 0
	var agreeing := 0
	for surface in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(surface)
		if arrays.is_empty() or arrays[Mesh.ARRAY_NORMAL] == null:
			continue
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = (
			arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		)
		var count := idx.size() if idx.size() > 0 else verts.size()
		var cursor := 0
		while cursor + 2 < count:
			var a_i := idx[cursor] if idx.size() > 0 else cursor
			var b_i := idx[cursor + 1] if idx.size() > 0 else cursor + 1
			var c_i := idx[cursor + 2] if idx.size() > 0 else cursor + 2
			cursor += 3
			var geometric := (verts[b_i] - verts[a_i]).cross(verts[c_i] - verts[a_i])
			if geometric.length() < 1e-9:
				continue
			var shading := norms[a_i] + norms[b_i] + norms[c_i]
			if shading.length() < 1e-6:
				continue
			triangles += 1
			if geometric.normalized().dot(shading.normalized()) > 0.0:
				agreeing += 1
	return {"triangles": triangles, "agreeing": agreeing}


func _assert(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_fail(description)


func _fail(description: String) -> void:
	_failures.append(description)
	push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("SHIP_SURFACE_WINDING_TEST_OK")
		quit(0)
	else:
		print("SHIP_SURFACE_WINDING_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
