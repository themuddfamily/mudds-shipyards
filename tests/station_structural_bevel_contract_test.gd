extends SceneTree

## Focused geometry-only regression for ROADMAP item 579.  This deliberately
## does not render a frame or instantiate ShipyardWorld: it proves that the
## structural station recipe reaches a chamfered mesh while preserving the
## authored extents.

const StationSurfaceKit = preload("res://scripts/world/station_surface_kit.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var cache := {}
	var sizes := [Vector3(4.0, 0.4, 2.0), Vector3(0.16, 1.24, 21.8), Vector3(0.035, 0.22, 0.92)]
	for size: Vector3 in sizes:
		var bevel := StationSurfaceKit.bevel_for_size(size)
		var mesh := StationSurfaceKit.rounded_box_mesh_cached(size, cache)
		var report := StationSurfaceKit.structural_bevel_contract(mesh, size, bevel)
		_check(bool(report.valid), "structural recipe is valid for %s: %s" % [size, report.errors])
		_check(int(report.vertex_count) == 324, "structural recipe keeps 324 chamfered vertices for %s" % size)
		_check((report.aabb as AABB).is_equal_approx(AABB(-size * 0.5, size)), "bevel preserves authored AABB for %s" % size)
	_check(cache.size() == sizes.size(), "caller cache retains one immutable resource per exact size")

	var raw := BoxMesh.new()
	raw.size = sizes[0]
	var raw_report := StationSurfaceKit.structural_bevel_contract(raw, sizes[0], StationSurfaceKit.bevel_for_size(sizes[0]))
	_check(not bool(raw_report.valid) and "mesh_must_be_array_mesh" in (raw_report.errors as PackedStringArray), "raw BoxMesh cannot satisfy the chamfered structural contract")
	_audit_cylinder_wall_is_free_to_flatten()
	_finish()


## The station builds its cylinders and frustums with no lateral wall
## subdivision (`StationSurfaceKit.CYLINDER_WALL_RINGS`), which is where the
## largest single triangle saving in the 2026-09-14 trim came from. This proves
## it is an edge-free reduction rather than a quality trade, by checking the
## property the reduction rests on directly: a wall quad is planar, so the four
## rings Godot's `CylinderMesh` defaults to add vertices that already lie on the
## surface the two-triangle version interpolates.
##
## The fleet proves the same thing over the ships' own radial-segment counts in
## `tests/fleet_surface_detail_test.gd`. This is the station half, checked at
## every segment count the live station builders pass and on tapers in both
## directions, because a taper is the case where "the rings do nothing" is least
## obvious.
func _audit_cylinder_wall_is_free_to_flatten() -> void:
	_check(
		StationSurfaceKit.CYLINDER_WALL_RINGS == 0,
		"the station builds cylinder and frustum walls with no lateral subdivision"
	)
	# 12: operations-activity beacon bases. 16: freight berth trolley wheels and
	# bollards, dock comb masts, service-dressing conduits. 24: Cinder cluster
	# stock. 32: habitat, Aft Junction and VIP reception stock.
	var live_radial_segments := [12, 16, 24, 32]
	# Straight stock, a disc, thin conduit, and the 0.88/0.94 tapers the station
	# builders author, in both directions.
	var profiles := [
		[0.12, 0.12, 1.00], [1.42, 1.42, 0.16], [0.025, 0.025, 0.90],
		[0.24 * 0.88, 0.24, 0.18], [0.24, 0.24 * 0.88, 0.18],
		[0.23 * 0.94, 0.23, 0.14], [0.23, 0.23 * 0.94, 0.14],
	]
	var dense_rings := StationSurfaceKit.CYLINDER_DEFAULT_RINGS
	_check(dense_rings > 0, "the dense reference tessellation is still a real subdivision")
	for segments: int in live_radial_segments:
		for profile: Array in profiles:
			var top: float = profile[0]
			var bottom: float = profile[1]
			var height: float = profile[2]
			var flat := StationSurfaceKit.chamfered_cylinder_mesh(
				top, bottom, height, segments, StationSurfaceKit.CYLINDER_WALL_RINGS
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
			var dense_vertices: PackedVector3Array = dense.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
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
			# 3. The normal set is identical, so nothing shades differently.
			_check(
				_distinct_normals(flat) == _distinct_normals(dense),
				"wall subdivision adds no distinct normal to %s" % label
			)
			# 4. And the saving is exactly the four rings' worth of wall quads.
			_check(
				_mesh_triangles(dense) - _mesh_triangles(flat) == dense_rings * 2 * segments,
				"flattening %s saves exactly %d triangles" % [label, dense_rings * 2 * segments]
			)


func _distinct_normals(mesh: ArrayMesh) -> int:
	var seen := {}
	var normals: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	for normal in normals:
		seen["%0.4f/%0.4f/%0.4f" % [normal.x, normal.y, normal.z]] = true
	return seen.size()


func _mesh_triangles(mesh: ArrayMesh) -> int:
	var arrays := mesh.surface_get_arrays(0)
	var indices = arrays[Mesh.ARRAY_INDEX]
	if indices != null and (indices as PackedInt32Array).size() > 0:
		return (indices as PackedInt32Array).size() / 3
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	return vertices.size() / 3


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("STATION_STRUCTURAL_BEVEL_CONTRACT_TEST_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("STATION_STRUCTURAL_BEVEL_CONTRACT_TEST_FAIL")
	quit(1)
