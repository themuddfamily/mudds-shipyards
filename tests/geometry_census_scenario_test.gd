extends SceneTree

## Focused production proof that the geometry/material census cannot mix the
## resident station baseline with one streamed Cinder generation.

const CENSUS := preload("res://tools/geometry_census.gd")
const MAIN_SCENE := preload("res://scenes/main.tscn")

const RESIDENT_FINGERPRINT := "345d518d2b9d13130f35d849a7ed0994f1bea96a00aa8bae41dab994c0d514f9"
const CINDER_LOADED_FINGERPRINT := "c8c2ca8c180e865b5eb83a4d9be3894e1bcdbf4913900cae49d3e40d4cb730ff"

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame
	_check(
		CENSUS.force_high_visual_quality(game),
		"production HIGH geometry profile is explicit and independent of saved settings"
	)
	await _settle()
	game.process_mode = Node.PROCESS_MODE_DISABLED

	var resident_contract := CENSUS.inspect_production_scenario(
		game,
		CENSUS.SCENARIO_STATION_RESIDENT
	)
	_check(
		bool(resident_contract.get("valid", false))
			and int(resident_contract.get("loaded_instance_count", -1)) == 0,
		"station-resident census requires zero loaded Cinder generations"
	)
	var resident_census := CENSUS.new()
	var resident := resident_census.measure_frozen_scene(
		game,
		CENSUS.SCENARIO_STATION_RESIDENT,
		0
	) as Dictionary
	print(
		"GEOMETRY_CENSUS_RESIDENT_FINGERPRINT: ",
		resident.get("measurement_fingerprint", "")
	)
	_check(
		int(resident.get("schema_version", 0)) == 2
			and resident.get("scenario") == CENSUS.SCENARIO_STATION_RESIDENT
			and int(resident.get("loaded_instance_count", -1)) == 0,
		"resident report freezes schema, scenario identity, and exact loaded count"
	)
	_check(
		int(resident.get("total_triangles", -1)) == 1683905
			and int(resident.get("total_mesh_instances", -1)) == 5691
			and int(resident.get("total_surfaces", -1)) == 5698
			and int(resident.get("unique_meshes", -1)) == 2578,
		"resident geometry freezes 1,683,905 triangles / 5,691 meshes / 5,698 surfaces / 2,578 unique meshes"
	)
	_check(
		int(resident.get("bound_phase_unique_materials", -1)) == 450
			and int(resident.get("retained_reachable_unique_materials", -1)) == 631
			and int(resident.get("lights", -1)) == 294
			and int(resident.get("nodes", -1)) == 9329,
		"resident resource roster freezes 450 bound / 631 retained materials, 294 lights, and 9,329 nodes"
	)
	_check(
		str(resident.get("measurement_fingerprint", "")) == RESIDENT_FINGERPRINT,
		"resident measurement fingerprint freezes the complete deterministic count contract"
	)
	resident_census.free()

	game.process_mode = Node.PROCESS_MODE_INHERIT
	var prepared := await CENSUS.prepare_cinder_loaded_scenario(game)
	_check(
		bool(prepared.get("accepted", false))
			and int(prepared.get("generation", -1)) == 1
			and int(prepared.get("loaded_instance_count", -1)) == 1,
		"loaded scenario commits exactly one real Cinder generation through production streaming"
	)
	await _settle()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	var loaded_contract := CENSUS.inspect_production_scenario(
		game,
		CENSUS.SCENARIO_CINDER_LOADED
	)
	_check(
		bool(loaded_contract.get("valid", false))
			and int(loaded_contract.get("loaded_instance_count", -1)) == 1,
		"Cinder-loaded census recognizes only the coordinator-owned generation"
	)
	var resident_mismatch := CENSUS.inspect_production_scenario(
		game,
		CENSUS.SCENARIO_STATION_RESIDENT
	)
	_check(
		not bool(resident_mismatch.get("valid", true))
			and str(
				(resident_mismatch.get("errors") as PackedStringArray)[0]
			).contains("requires zero"),
		"MUTATION: a live destination generation makes the resident scenario fail closed"
	)

	var loaded_census := CENSUS.new()
	var loaded := loaded_census.measure_frozen_scene(
		game,
		CENSUS.SCENARIO_CINDER_LOADED,
		1
	) as Dictionary
	print(
		"GEOMETRY_CENSUS_LOADED_FINGERPRINT: ",
		loaded.get("measurement_fingerprint", "")
	)
	_check(
		loaded.get("scenario") == CENSUS.SCENARIO_CINDER_LOADED
			and int(loaded.get("loaded_instance_count", -1)) == 1,
		"loaded report freezes destination identity and one committed generation"
	)
	_check(
		int(loaded.get("total_triangles", -1)) == 1801362
			and int(loaded.get("total_mesh_instances", -1)) == 5857
			and int(loaded.get("total_surfaces", -1)) == 5864
			and int(loaded.get("unique_meshes", -1)) == 2708,
		"loaded geometry freezes 1,801,362 triangles / 5,857 meshes / 5,864 surfaces / 2,708 unique meshes"
	)
	_check(
		int(loaded.get("bound_phase_unique_materials", -1)) == 469
			and int(loaded.get("retained_reachable_unique_materials", -1)) == 650
			and int(loaded.get("lights", -1)) == 317
			and int(loaded.get("nodes", -1)) == 9630,
		"loaded resource roster freezes 469 bound / 650 retained materials, 317 lights, and 9,630 nodes"
	)
	var cinder_bucket := (loaded.get("buckets", {}) as Dictionary).get(
		"CinderStreamingBootstrap", {}
	) as Dictionary
	_check(
		int(cinder_bucket.get("triangles", -1)) == 117457
			and int(cinder_bucket.get("instances", -1)) == 166
			and int(cinder_bucket.get("surfaces", -1)) == 166
			and int(cinder_bucket.get("multimesh_instances", -1)) == 524
			and int(cinder_bucket.get("lights", -1)) == 23
			and int(cinder_bucket.get("nodes", -1)) == 304,
		"the streamed Cinder bucket independently accounts for its exact renderer and node roster"
	)
	_check(
		int(loaded.get("total_triangles", 0)) - int(resident.get("total_triangles", 0)) == 117457
			and int(loaded.get("total_mesh_instances", 0)) - int(resident.get("total_mesh_instances", 0)) == 166
			and int(loaded.get("unique_meshes", 0)) - int(resident.get("unique_meshes", 0)) == 130
			and int(loaded.get("retained_reachable_unique_materials", 0)) - int(resident.get("retained_reachable_unique_materials", 0)) == 19
			and int(loaded.get("lights", 0)) - int(resident.get("lights", 0)) == 23
			and int(loaded.get("nodes", 0)) - int(resident.get("nodes", 0)) == 301,
		"loaded-minus-resident delta is exact across geometry, retained resources, lights, and nodes"
	)
	_check(
		str(loaded.get("measurement_fingerprint", "")) == CINDER_LOADED_FINGERPRINT
			and str(loaded.get("measurement_fingerprint", ""))
				!= str(resident.get("measurement_fingerprint", "")),
		"loaded measurement has its own exact scenario-sensitive fingerprint"
	)
	loaded_census.free()

	game.queue_free()
	await process_frame
	_finish()


func _settle() -> void:
	for _frame in CENSUS.DEFAULT_SETTLE_FRAMES:
		await process_frame
	await physics_frame
	await process_frame


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("GEOMETRY_CENSUS_SCENARIO_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	print("GEOMETRY_CENSUS_SCENARIO_TEST_FAILED: %d of %d assertions failed" % [
		_failures.size(), _assertions,
	])
	for failure in _failures:
		print(" - ", failure)
	quit(1)
