extends SceneTree

## Front-face winding contract for the station's procedural mesh builders.
##
## Nothing in the matrix checked winding, which is why a builder that emitted
## every quad backwards survived 97 suites and roughly 8,500 assertions. A
## backwards-wound surface is not a subtle defect: Godot culls its outward faces
## and draws the unlit inside of its back faces instead, so a chamfered box
## renders as a black shell and a deck renders as a hole with its underside
## showing through. That is what "the materials look inside out" means, and it is
## invisible to every structural assertion because the node, the mesh, the
## material and the triangle count are all exactly as expected.
##
## The convention is *calibrated*, never hard-coded. Godot's own primitives are
## the ground truth: for a correctly wound surface `(b - a) x (c - a)` points
## opposite the shading normal, because Godot's front face is the clockwise one
## seen from outside. Deriving the expected sign from `BoxMesh` at runtime means
## this suite still holds if the engine ever changes that convention, instead of
## freezing today's sign as a magic number.

const ENGINE_CALIBRATION_MESHES := ["BoxMesh", "CylinderMesh", "SphereMesh"]
const STATION_ACTIVITY_SCENE := preload("res://scenes/world/components/station_operations_activity.tscn")

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

	_check_builders(expected_sign)
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
		# An engine primitive is expected to be internally consistent.
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


func _check_builders(expected_sign: int) -> void:
	var cases: Array = [
		["StationSurfaceKit.rounded_box_mesh (2 m cube)", StationSurfaceKit.rounded_box_mesh(Vector3(2.0, 2.0, 2.0))],
		["StationSurfaceKit.rounded_box_mesh (deck slab)", StationSurfaceKit.rounded_box_mesh(Vector3(27.0, 1.2, 30.0))],
		["StationSurfaceKit.rounded_box_mesh (thin strip)", StationSurfaceKit.rounded_box_mesh(Vector3(0.22, 0.035, 35.5))],
		[
			"StationSurfaceKit.rounded_box_mesh_with_bevel (FACE_GRID)",
			StationSurfaceKit.rounded_box_mesh_with_bevel(
				Vector3(4.0, 0.4, 4.0), 0.08, StationSurfaceKit.BevelUV.FACE_GRID
			),
		],
		["StationSurfaceKit.chamfered_cylinder_mesh", StationSurfaceKit.chamfered_cylinder_mesh(0.5, 0.5, 2.0, 16)],
		["StationSurfaceKit.chamfered_cylinder_mesh (frustum)", StationSurfaceKit.chamfered_cylinder_mesh(0.3, 0.8, 2.0, 16)],
	]
	for case: Array in cases:
		_assert_wound(str(case[0]), case[1] as Mesh, expected_sign)

	# The Jovian freight berth keeps its own chamfered-box algorithm on purpose,
	# so it needs its own coverage rather than inheriting the kit's.
	var berth := JovianFreightBerth.new()
	var berth_mesh := berth.call("_rounded_box_mesh", Vector3(6.8, 0.62, 5.1)) as ArrayMesh
	_assert_wound("JovianFreightBerth._rounded_box_mesh", berth_mesh, expected_sign)
	berth.free()

	_check_station_life_profiles(expected_sign)


## Every mesh the four station-life activity profiles actually emit, not a
## representative sample of the builders they call. A profile that grows a new
## piece of geometry is covered the moment it is added.
func _check_station_life_profiles(expected_sign: int) -> void:
	for profile in [
		StationOperationsActivity.ActivityProfile.CARGO_LINE,
		StationOperationsActivity.ActivityProfile.SIGNAGE_PYLON,
		StationOperationsActivity.ActivityProfile.OBSERVATORY,
		StationOperationsActivity.ActivityProfile.CREW_WORKPOST,
	]:
		var activity := STATION_ACTIVITY_SCENE.instantiate() as StationOperationsActivity
		activity.activity_profile = profile
		root.add_child(activity)
		var profile_id := activity.get_activity_profile_id()
		var triangles := 0
		var backwards := 0
		var checked_meshes := 0
		for candidate in activity.find_children("*", "MeshInstance3D", true, false):
			var mesh := (candidate as MeshInstance3D).mesh
			if mesh == null:
				continue
			checked_meshes += 1
			var report := _score(mesh)
			triangles += int(report["triangles"])
			backwards += int(report["triangles"]) - int(report["agreeing"]) if expected_sign == 1 else int(report["agreeing"])
		_assert(
			checked_meshes > 0 and triangles > 0 and backwards == 0,
			"%s profile winds all %d triangles across %d meshes to face outward (%d backwards)" % [
				profile_id, triangles, checked_meshes, backwards
			]
		)
		activity.queue_free()
		root.remove_child(activity)


## Structured-red control: a deliberately reversed copy of a builder mesh must be
## rejected. Without this the suite could pass by measuring nothing.
func _check_detects_reversal(expected_sign: int) -> void:
	var source := StationSurfaceKit.rounded_box_mesh(Vector3(2.0, 2.0, 2.0))
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
		"a deliberately reversed mesh is detected as fully backwards (%d/%d)" % [backwards, triangles]
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
		print("STATION_SURFACE_WINDING_TEST_OK")
		quit(0)
	else:
		print("STATION_SURFACE_WINDING_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
