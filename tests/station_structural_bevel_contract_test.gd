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
	_finish()


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
