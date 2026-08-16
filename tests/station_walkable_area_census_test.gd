extends SceneTree

const CENSUS := preload("res://tools/station_walkable_area_census.gd")
const WORLD_SCENE := preload("res://scenes/world/shipyard_world.tscn")
const EXPECTED_GROSS_PROJECTED_M2 := 7103.199985
const EXPECTED_COUNTED_PROJECTED_M2 := 6849.844560
const EXPECTED_TRUE_SURFACE_M2 := 6857.712521

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := WORLD_SCENE.instantiate() as Node3D
	_check(world != null, "production station world instantiates")
	if world == null:
		_finish()
		return
	root.add_child(world)
	await process_frame
	await physics_frame
	await physics_frame

	var report: Dictionary = CENSUS.measure_production(
		world, world.get_world_3d().direct_space_state
	)
	_test_production_baseline(world, report)
	var repeat: Dictionary = CENSUS.measure_production(
		world, world.get_world_3d().direct_space_state
	)
	_check(
		CENSUS.canonical_aggregate_json(report) == CENSUS.canonical_aggregate_json(repeat),
		"a repeated live census emits byte-identical aggregate JSON"
	)

	world.queue_free()
	await process_frame
	await physics_frame
	await _test_invalid_and_extension_fixtures()
	_finish()


func _test_production_baseline(world: Node3D, report: Dictionary) -> void:
	_check(bool(report.valid) and (report.errors as PackedStringArray).is_empty(), "production census is structurally valid")
	_check(int(report.surface_count) == 54 and int(report.ramp_count) == 3, "production roster contains exactly 54 surfaces and three ramps")
	_check(_near(report.gross_projected_horizontal_m2, EXPECTED_GROSS_PROJECTED_M2), "raw declared footprint is frozen at 7103.199985 m2")
	_check(_near(report.total_projected_horizontal_m2, EXPECTED_COUNTED_PROJECTED_M2), "coplanar-unioned walkable baseline is frozen at 6849.844560 m2")
	_check(_near(report.total_true_surface_m2, EXPECTED_TRUE_SURFACE_M2), "true-surface baseline is frozen at 6857.712521 m2")
	_check(
		_near(report.ramp_projected_horizontal_m2, 68.480000)
		and _near(report.ramp_true_surface_m2, 76.347961),
		"ramps separately report exact projected and inclined surface area"
	)
	_check(
		int(report.physics_support_samples) == 270
		and int(report.physics_support_samples_total) == 270,
		"all five representative points on every declared surface have live World support"
	)

	var identities := PackedStringArray()
	var forbidden_selected := false
	for row: Dictionary in report.rows:
		identities.append("%s/%s" % [row.owner, row.surface_id])
		var path := String(row.path)
		for forbidden in ["NearbySectorCluster", "JovianFreightShipBerth", "Vehicle", "Roof", "Ceiling"]:
			forbidden_selected = forbidden_selected or path.contains(forbidden)
	var sorted_identities := identities.duplicate()
	sorted_identities.sort()
	_check(identities == sorted_identities, "per-owner and per-surface rows are stably sorted")
	_check(not forbidden_selected, "ships, vehicles, roofs, ceilings, and nearby-sector geometry select no census row")
	_check(world.has_node(^"NearbySectorCluster") and world.has_node(^"JovianFreightShipBerth"), "exclusions are proven against live excluded production geometry")
	_check(
		String(report.source_sha).length() == 40
		and not String(report.engine).is_empty()
		and report.profile == "production_station_walkable_collision_v1",
		"aggregate records source SHA, engine, and measurement profile"
	)


func _test_invalid_and_extension_fixtures() -> void:
	var fixture := Node3D.new()
	fixture.name = "CensusFixtures"
	root.add_child(fixture)
	var overlap_a := _add_box(fixture, "OverlapA", Vector3(2.0, 0.2, 2.0), Vector3(1000.0, 0.0, 0.0), 1)
	var overlap_b := _add_box(fixture, "OverlapB", Vector3(2.0, 0.2, 2.0), Vector3(1000.5, 0.0, 0.0), 1)
	var unsupported := _add_box(fixture, "Unsupported", Vector3(2.0, 0.2, 2.0), Vector3(2000.0, 0.0, 0.0), 0)
	var tagged := _add_box(fixture, "TaggedExtension", Vector3(3.0, 0.2, 2.0), Vector3(3000.0, 0.0, 0.0), 1)
	tagged.set_meta("walkable_surface", true)
	tagged.set_meta("walkable_surface_id", &"extension-slab")
	tagged.set_meta("walkable_surface_owner", &"later_module")
	tagged.set_meta("walkable_surface_kind", &"level")
	await process_frame
	await physics_frame
	await physics_frame
	var space := fixture.get_world_3d().direct_space_state

	var overlap_declarations: Array[Dictionary] = [
		_declaration(overlap_a, fixture, &"overlap-a"),
		_declaration(overlap_b, fixture, &"overlap-b"),
	]
	var rejected: Dictionary = CENSUS.measure(fixture, overlap_declarations, space)
	_check(_errors_contain(rejected, "coplanar walkable surfaces overlap"), "undeclared coplanar overlap is rejected")
	_check(
		_near(rejected.gross_projected_horizontal_m2, 8.0)
		and _near(rejected.total_projected_horizontal_m2, 5.0),
		"overlapping slabs retain 8 m2 raw audit area but contribute only their 5 m2 union"
	)
	var accepted_union: Dictionary = CENSUS.measure(fixture, overlap_declarations, space, false, true)
	_check(bool(accepted_union.valid) and _near(accepted_union.total_projected_horizontal_m2, 5.0), "explicit handoff-union policy is valid and cannot double-count a slab")

	var missing: Dictionary = CENSUS.measure(fixture, [{
		"owner": &"fixture",
		"surface_id": &"missing",
		"path": NodePath("Absent"),
		"kind": &"level",
	}], space)
	_check(_errors_contain(missing, "missing declared surface"), "missing declared surface is rejected")

	var duplicate_path: Array[Dictionary] = [
		_declaration(overlap_a, fixture, &"first-name"),
		_declaration(overlap_a, fixture, &"second-name"),
	]
	var duplicate: Dictionary = CENSUS.measure(fixture, duplicate_path, space)
	_check(_errors_contain(duplicate, "one collision body declared more than once"), "one collision body cannot be counted under duplicate identities")

	var unsupported_report: Dictionary = CENSUS.measure(
		fixture, [_declaration(unsupported, fixture, &"unsupported")], space
	)
	_check(
		_errors_contain(unsupported_report, "unsupported collision policy")
		and _errors_contain(unsupported_report, "no representative live physics support"),
		"a declared shape without live World support is rejected"
	)

	var discovered: Dictionary = CENSUS.measure(fixture, [], space, true)
	_check(
		bool(discovered.valid)
		and int(discovered.surface_count) == 1
		and discovered.rows[0].owner == "later_module"
		and discovered.rows[0].surface_id == "extension-slab"
		and _near(discovered.total_projected_horizontal_m2, 6.0),
		"later modules join the census through stable live surface metadata"
	)
	fixture.queue_free()
	await process_frame


func _add_box(
		parent: Node3D,
		body_name: String,
		size: Vector3,
		position: Vector3,
		layer: int
	) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = body_name
	body.position = position
	body.collision_layer = layer
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)
	return body


func _declaration(body: StaticBody3D, fixture: Node3D, surface_id: StringName) -> Dictionary:
	return {
		"owner": &"fixture",
		"surface_id": surface_id,
		"path": fixture.get_path_to(body),
		"kind": &"level",
	}


func _errors_contain(report: Dictionary, fragment: String) -> bool:
	for error: String in report.errors:
		if error.contains(fragment):
			return true
	return false


func _near(actual: Variant, expected: float) -> bool:
	return absf(float(actual) - expected) <= 0.0000015


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("STATION_WALKABLE_AREA_CENSUS_TEST_OK")
		quit(0)
	else:
		print("STATION_WALKABLE_AREA_CENSUS_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
