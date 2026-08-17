extends SceneTree

## Focused deterministic fixtures plus a frozen production-Main measurement.

const CENSUS := preload("res://tools/station_light_overlap_census.gd")
const MAIN_SCENE := preload("res://scenes/main.tscn")
const ROSTER_FINGERPRINT := "7bfe535a02a8e891ce9c9296d09223aa8dd99276fea14e716ce1db0050e9feca"
const STATION_RESIDENT_MEASUREMENT_FINGERPRINT := "afd8e8759c35890c6d0ab87cfdc9aac9fa7552dc1a5edf54a631e9e754ec31d6"
const CINDER_LOADED_MEASUREMENT_FINGERPRINT := "395cd89305818b0e6eed681b7a8d70338c4add777fab82ac245c0e05fc801cdf"
const FABRICATION_LIGHT_PATHS := [
	"ShipyardWorld/FabricationAnnex/GeneratedAnnex/PracticalLight",
	"ShipyardWorld/FabricationAnnex/GeneratedAnnex/PracticalLight01",
	"ShipyardWorld/FabricationAnnex/GeneratedAnnex/PracticalLight02",
	"ShipyardWorld/FabricationAnnex/GeneratedAnnex/PracticalLight03",
	"ShipyardWorld/FabricationAnnex/GeneratedAnnex/PracticalLight04",
	"ShipyardWorld/FabricationAnnex/GeneratedAnnex/PracticalLight05",
]
const OBSERVATION_LIGHT_PATHS := [
	"ShipyardWorld/ObservationLogisticsSpur/Structure/Dressing/Practical01",
	"ShipyardWorld/ObservationLogisticsSpur/Structure/Dressing/Practical02",
	"ShipyardWorld/ObservationLogisticsSpur/Structure/Dressing/Practical03",
	"ShipyardWorld/ObservationLogisticsSpur/Structure/Dressing/Practical04",
	"ShipyardWorld/ObservationLogisticsSpur/Structure/Dressing/Practical05",
	"ShipyardWorld/ObservationLogisticsSpur/Structure/Dressing/Practical06",
]

var _assertions := 0
var _failures := PackedStringArray()


func _initialize() -> void:
	_run()


func _run() -> void:
	await _test_type_range_cone_shadow_and_visibility_fixture()
	await _test_production_main_roster_and_measurement()
	_finish()


func _test_type_range_cone_shadow_and_visibility_fixture() -> void:
	var fixture := Node3D.new()
	fixture.name = "LightInfluenceFixture"
	root.add_child(fixture)
	var directional := DirectionalLight3D.new()
	directional.name = "DirectionalAll"
	directional.shadow_enabled = true
	fixture.add_child(directional)
	var omni := OmniLight3D.new()
	omni.name = "OmniNear"
	omni.omni_range = 20.0
	omni.distance_fade_enabled = true
	omni.distance_fade_begin = 2.0
	omni.distance_fade_length = 3.0
	fixture.add_child(omni)
	var spot := SpotLight3D.new()
	spot.name = "SpotForward"
	spot.spot_range = 10.0
	spot.spot_angle = 20.0
	spot.shadow_enabled = true
	spot.distance_fade_enabled = true
	spot.distance_fade_begin = 20.0
	spot.distance_fade_length = 2.0
	spot.distance_fade_shadow = 8.0
	fixture.add_child(spot)
	var hidden := OmniLight3D.new()
	hidden.name = "HiddenOmni"
	hidden.omni_range = 100.0
	hidden.visible = false
	fixture.add_child(hidden)
	var zero_energy := OmniLight3D.new()
	zero_energy.name = "ZeroEnergyOmni"
	zero_energy.omni_range = 100.0
	zero_energy.light_energy = 0.0
	fixture.add_child(zero_energy)
	var wrong_layer := OmniLight3D.new()
	wrong_layer.name = "WrongLayerOmni"
	wrong_layer.omni_range = 100.0
	wrong_layer.light_cull_mask = 2
	fixture.add_child(wrong_layer)
	await process_frame

	var samples: Array[Dictionary] = [
		_fixture_sample(&"inside-cone", Vector3(0, 0, -4)),
		_fixture_sample(&"side-of-cone", Vector3(4, 0, 0)),
		_fixture_sample(&"far-inside-cone", Vector3(0, 0, -8)),
	]
	var baseline := CENSUS.measure_scene(fixture, samples)
	var inside := _point(baseline, &"inside-cone")
	var side := _point(baseline, &"side-of-cone")
	var far := _point(baseline, &"far-inside-cone")
	_check(
		int((baseline.scene_lights as Dictionary).total) == 6
		and int((baseline.scene_lights as Dictionary).enabled) == 4
		and int((baseline.scene_lights as Dictionary).enabled_shadow_casting) == 2,
		"fixture distinguishes total, actually enabled, and enabled shadow-casting lights"
	)
	_check(
		int(inside.influence_count) == 3 and int(inside.shadow_caster_count) == 2
		and int(side.influence_count) == 2 and int(side.shadow_caster_count) == 1
		and int(far.influence_count) == 2 and int(far.shadow_caster_count) == 2,
		"directional reach, omni range and spot cone produce the expected three point overlaps"
	)
	_check(
		(inside.contributing_node_paths as PackedStringArray) == PackedStringArray([
			"DirectionalAll", "OmniNear", "SpotForward",
		]),
		"contributing node paths are complete and deterministically sorted"
	)
	var inside_omni := _contributor(inside, "OmniNear")
	var inside_spot := _contributor(inside, "SpotForward")
	var far_spot := _contributor(far, "SpotForward")
	_check(
		bool((inside_omni.distance_fade as Dictionary).enabled)
		and float((inside_omni.distance_fade as Dictionary).begin_m) == 2.0
		and float((inside_omni.distance_fade as Dictionary).length_m) == 3.0
		and float((inside_omni.distance_fade as Dictionary).light_endpoint_m) == 5.0
		and str((inside_omni.distance_fade as Dictionary).light_inclusion_reason) == "within_light_fade_endpoint"
		and float((inside_spot.distance_fade as Dictionary).shadow_endpoint_m) == 8.0
		and str((far_spot.distance_fade as Dictionary).shadow_inclusion_reason) == "within_shadow_fade_endpoint",
		"contributors serialize exact local-light fade fields, endpoints and inclusion reasons"
	)
	_check(
		not (inside.contributing_node_paths as PackedStringArray).has("HiddenOmni")
		and not (inside.contributing_node_paths as PackedStringArray).has("ZeroEnergyOmni")
		and not (inside.contributing_node_paths as PackedStringArray).has("WrongLayerOmni"),
		"hidden, zero-energy and cull-mask-mismatched lights do not influence a point"
	)
	var first_json := CENSUS.deterministic_json(baseline)
	var second_json := CENSUS.deterministic_json(CENSUS.measure_scene(fixture, samples))
	_check(first_json == second_json and first_json.sha256_text() == second_json.sha256_text(), "identical fixture state emits byte-identical deterministic JSON")
	var resident_identity_fingerprint := CENSUS.build_measurement_fingerprint(
		baseline.points as Array[Dictionary],
		baseline.scene_lights as Dictionary,
		CENSUS.SCENARIO_STATION_RESIDENT,
		0
	)
	var loaded_identity_fingerprint := CENSUS.build_measurement_fingerprint(
		baseline.points as Array[Dictionary],
		baseline.scene_lights as Dictionary,
		CENSUS.SCENARIO_CINDER_LOADED,
		1
	)
	_check(
		resident_identity_fingerprint != loaded_identity_fingerprint
		and resident_identity_fingerprint != baseline.measurement_fingerprint
		and loaded_identity_fingerprint != baseline.measurement_fingerprint,
		"MUTATION: identical rows and counts hash differently under each residency identity"
	)

	omni.distance_fade_enabled = false
	var fade_disabled := CENSUS.measure_scene(fixture, samples)
	_check(
		int(_point(fade_disabled, &"far-inside-cone").influence_count) == 3
		and fade_disabled.measurement_fingerprint != baseline.measurement_fingerprint,
		"MUTATION: disabling distance fade restores an in-range local light beyond its former fade endpoint"
	)
	omni.distance_fade_enabled = true
	omni.distance_fade_begin = 5.0
	var fade_begins_later := CENSUS.measure_scene(fixture, samples)
	_check(
		int(_point(fade_begins_later, &"far-inside-cone").influence_count) == 3
		and fade_begins_later.measurement_fingerprint != baseline.measurement_fingerprint,
		"MUTATION: moving distance-fade begin moves the light endpoint and changes overlap"
	)
	omni.distance_fade_begin = 2.0
	omni.distance_fade_length = 6.0
	var fade_is_longer := CENSUS.measure_scene(fixture, samples)
	_check(
		int(_point(fade_is_longer, &"far-inside-cone").influence_count) == 3
		and fade_is_longer.measurement_fingerprint != baseline.measurement_fingerprint,
		"MUTATION: extending distance-fade length moves the light endpoint and changes overlap"
	)
	omni.distance_fade_length = 3.0
	spot.distance_fade_shadow = 7.9
	var shadow_endpoint_short := CENSUS.measure_scene(fixture, samples)
	_check(
		int(_point(shadow_endpoint_short, &"far-inside-cone").influence_count) == 2
		and int(_point(shadow_endpoint_short, &"far-inside-cone").shadow_caster_count) == 1
		and str((_contributor(_point(shadow_endpoint_short, &"far-inside-cone"), "SpotForward").distance_fade as Dictionary).shadow_inclusion_reason) == "beyond_shadow_fade_endpoint"
		and shadow_endpoint_short.measurement_fingerprint != baseline.measurement_fingerprint,
		"MUTATION: moving the shadow-fade endpoint just inside the camera distance removes only the shadow"
	)
	spot.distance_fade_shadow = 8.0

	zero_energy.light_energy = 1.0
	var energized := CENSUS.measure_scene(fixture, samples)
	_check(int(_point(energized, &"inside-cone").influence_count) == 4, "MUTATION: positive energy activates an otherwise in-range light")
	zero_energy.light_energy = 0.0
	wrong_layer.light_cull_mask = 1
	var recategorized := CENSUS.measure_scene(fixture, samples)
	_check(int(_point(recategorized, &"inside-cone").influence_count) == 4, "MUTATION: matching the point's visual layer activates an otherwise in-range light")
	wrong_layer.light_cull_mask = 2
	omni.omni_range = 3.0
	var shrunk := CENSUS.measure_scene(fixture, samples)
	_check(int(_point(shrunk, &"inside-cone").influence_count) == 2, "MUTATION: shrinking actual omni range removes its formerly influenced point")
	omni.omni_range = 20.0
	spot.rotation.y = PI
	var turned := CENSUS.measure_scene(fixture, samples)
	_check(int(_point(turned, &"inside-cone").influence_count) == 2, "MUTATION: turning the spot cone removes a point still inside its range")
	spot.rotation.y = 0.0
	spot.shadow_enabled = false
	var shadowless := CENSUS.measure_scene(fixture, samples)
	_check(
		int(_point(shadowless, &"inside-cone").influence_count) == 3
		and int(_point(shadowless, &"inside-cone").shadow_caster_count) == 1,
		"MUTATION: disabling one shadow keeps influence but changes the separate shadow count"
	)
	spot.shadow_enabled = true
	directional.visible = false
	var hidden_directional := CENSUS.measure_scene(fixture, samples)
	_check(int(_point(hidden_directional, &"far-inside-cone").influence_count) == 1, "MUTATION: inherited visibility removes a globally ranged directional light")
	directional.visible = true
	_check(CENSUS.deterministic_json(CENSUS.measure_scene(fixture, samples)) == first_json, "restoring every mutation returns the fixture to its exact JSON baseline")
	fixture.queue_free()
	await process_frame


func _test_production_main_roster_and_measurement() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame
	_check(
		CENSUS.force_high_visual_quality(game),
		"production census explicitly freezes HIGH quality independent of saved local settings"
	)
	for _frame in CENSUS.DEFAULT_SETTLE_FRAMES:
		await process_frame
	await physics_frame
	await process_frame
	game.process_mode = Node.PROCESS_MODE_DISABLED
	var scenario_contract := CENSUS.inspect_production_scenario(
		game, CENSUS.SCENARIO_STATION_RESIDENT
	)
	_check(
		bool(scenario_contract.get("valid", false))
		and int(scenario_contract.get("loaded_instance_count", -1)) == 0,
		"default station-resident production scenario requires zero streamed Cinder instances"
	)
	var roster := CENSUS.build_frozen_production_roster(game)
	_check(bool(roster.valid) and (roster.errors as PackedStringArray).is_empty(), "all frozen production sample paths and published Cinder positions resolve exactly")
	var category_counts := {&"walking": 0, &"boarding": 0, &"operations": 0, &"flight_route": 0}
	var sample_ids := PackedStringArray()
	for point in roster.points as Array[Dictionary]:
		category_counts[point.category] = int(category_counts[point.category]) + 1
		sample_ids.append(str(point.point_id))
	var sorted_ids := sample_ids.duplicate()
	sorted_ids.sort()
	_check(
		int(roster.sample_count) == 22
		and category_counts == {&"walking": 6, &"boarding": 5, &"operations": 4, &"flight_route": 7}
		and sample_ids.size() == sorted_ids.size(),
		"frozen roster spans six walking, five boarding, four operations and seven flight-route points"
	)
	var report := CENSUS.measure_scene(
		game,
		roster.points as Array[Dictionary],
		CENSUS.SCENARIO_STATION_RESIDENT,
		int(scenario_contract.get("loaded_instance_count", -1))
	)
	print("STATION_LIGHT_OVERLAP_PRODUCTION_RESULT: ", {
		"roster_fingerprint": report.sample_roster_fingerprint,
		"measurement_fingerprint": report.measurement_fingerprint,
		"scene_lights": report.scene_lights,
		"maximum_influence_count": report.maximum_influence_count,
		"maximum_shadow_caster_count": report.maximum_shadow_caster_count,
		"top_worst_points": report.top_worst_points,
	})
	_check(
		report.method.performance_claim == false
		and report.method.llvmpipe_benchmark == false
		and str(report.method.includes).contains("distance-fade endpoint")
		and str(report.method.includes).contains("sample as the camera point")
		and str(report.method.excludes).contains("GPU time"),
		"production report is a camera-point geometric proxy and explicitly rejects GPU-time, draw-cost and frame-time claims"
	)
	_check(
		int((report.scene_lights as Dictionary).total) > 0
		and int((report.scene_lights as Dictionary).enabled) > 0
		and int(report.maximum_influence_count) > 0
		and (report.points as Array).size() == int(roster.sample_count),
		"live Main report measures every frozen point and publishes whole-scene totals"
	)
	var json_first := CENSUS.deterministic_json(report)
	var json_second := CENSUS.deterministic_json(CENSUS.measure_scene(
		game,
		roster.points as Array[Dictionary],
		CENSUS.SCENARIO_STATION_RESIDENT,
		0
	))
	_check(json_first == json_second, "frozen production phase emits byte-identical JSON on repeat measurement")
	var scene_lights := report.scene_lights as Dictionary
	var by_type := scene_lights.by_type as Dictionary
	_check(
		int(report.schema_version) == CENSUS.SCHEMA_VERSION
		and report.scenario == CENSUS.SCENARIO_STATION_RESIDENT
		and int(report.loaded_instance_count) == 0
		and int(scene_lights.total) == 297
		and int(scene_lights.enabled) == 245
		and int(scene_lights.disabled) == 52
		and int(scene_lights.shadow_casting_total) == 19
		and int(scene_lights.enabled_shadow_casting) == 19
		and int((by_type.directional as Dictionary).total) == 3
		and int((by_type.directional as Dictionary).enabled) == 3
		and int((by_type.omni as Dictionary).total) == 283
		and int((by_type.omni as Dictionary).enabled) == 231
		and int((by_type.spot as Dictionary).total) == 11
		and int((by_type.spot as Dictionary).enabled) == 11,
		"station-resident HIGH freezes 297 total / 245 enabled lights and exact type/shadow splits"
	)
	_test_expansion_light_provenance(game, report)
	var expected_worst := [
		[&"operate-aft-service-arm", 15, 1],
		[&"walk-habitat-common", 11, 1],
		[&"walk-aft-lower-junction", 10, 1],
		[&"board-halyard-berth", 7, 3],
		[&"walk-vip-reception", 7, 1],
	]
	var worst_exact := (report.top_worst_points as Array).size() == expected_worst.size()
	for index in expected_worst.size():
		var observed := (report.top_worst_points as Array)[index] as Dictionary
		var expected := expected_worst[index] as Array
		worst_exact = worst_exact \
			and StringName(observed.point_id) == expected[0] \
			and int(observed.influence_count) == int(expected[1]) \
			and int(observed.shadow_caster_count) == int(expected[2])
	_check(
		worst_exact
		and int(report.maximum_influence_count) == 15
		and int(report.maximum_shadow_caster_count) == 3,
		"production freeze retains the sorted five worst overlap points and separate maxima"
	)
	_check(
		str(report.sample_roster_fingerprint) == ROSTER_FINGERPRINT
		and str(report.measurement_fingerprint)
			== STATION_RESIDENT_MEASUREMENT_FINGERPRINT,
		"station-resident roster and complete per-point contributor measurement have frozen fingerprints"
	)
	_check(
		not json_first.contains("@OmniLight3D@")
		and not json_first.contains("@SpotLight3D@"),
		"runtime fallback light names are canonicalized to stable sibling ordinals in JSON paths"
	)
	await _test_cinder_loaded_production_scenario(game, roster, report)
	game.queue_free()
	await process_frame
	await physics_frame
	await process_frame


func _test_expansion_light_provenance(game: Node, report: Dictionary) -> void:
	var light_roster := CENSUS.build_scene_light_roster(game)
	var fabrication := _light_records_under(light_roster, "ShipyardWorld/FabricationAnnex/")
	var observation := _light_records_under(light_roster, "ShipyardWorld/ObservationLogisticsSpur/")
	var salvage := _light_records_under(light_roster, "ShipyardWorld/SalvageTerrace/")
	_check(
		_light_paths(fabrication) == FABRICATION_LIGHT_PATHS
		and _all_enabled_shadowless_omni(fabrication),
		"the prior baseline's six Fabrication practicals remain exact enabled shadowless omnis"
	)
	_check(
		_light_paths(observation) == OBSERVATION_LIGHT_PATHS
		and _all_enabled_shadowless_omni(observation),
		"Observation retains its six intended enabled shadowless practicals in the resident station"
	)
	_check(
		salvage.is_empty(),
		"Salvage Terrace contributes no dynamic lights, matching its zero-light module contract"
	)

	var expansion_reaches_sample := false
	for point in report.points as Array[Dictionary]:
		for path in point.contributing_node_paths as PackedStringArray:
			if (
				path.begins_with("ShipyardWorld/FabricationAnnex/")
				or path.begins_with("ShipyardWorld/ObservationLogisticsSpur/")
				or path.begins_with("ShipyardWorld/SalvageTerrace/")
			):
				expansion_reaches_sample = true
	_check(
		not expansion_reaches_sample,
		"Fabrication, Observation and Salvage add no contributor to any of the 22 frozen samples"
	)


func _test_cinder_loaded_production_scenario(
		game: GameFlow,
		roster: Dictionary,
		resident_report: Dictionary
	) -> void:
	game.process_mode = Node.PROCESS_MODE_INHERIT
	var prepared := await CENSUS.prepare_cinder_loaded_scenario(game)
	_check(
		bool(prepared.get("accepted", false))
		and prepared.get("reason") == &"loaded"
		and int(prepared.get("generation", -1)) == 1
		and int(prepared.get("loaded_instance_count", -1)) == 1,
		"loaded scenario commits exactly one real Cinder generation through the production binding"
	)
	for _frame in CENSUS.DEFAULT_SETTLE_FRAMES:
		await process_frame
	await physics_frame
	await process_frame
	game.process_mode = Node.PROCESS_MODE_DISABLED
	var loaded_contract := CENSUS.inspect_production_scenario(
		game, CENSUS.SCENARIO_CINDER_LOADED
	)
	_check(
		bool(loaded_contract.get("valid", false))
		and int(loaded_contract.get("loaded_instance_count", -1)) == 1,
		"Cinder-loaded production scenario recognizes the sole coordinator-owned generation"
	)
	var resident_mismatch := CENSUS.inspect_production_scenario(
		game, CENSUS.SCENARIO_STATION_RESIDENT
	)
	_check(
		not bool(resident_mismatch.get("valid", true))
		and int(resident_mismatch.get("loaded_instance_count", -1)) == 1
		and str((resident_mismatch.get("errors", PackedStringArray()) as PackedStringArray)[0]).contains(
			"requires zero"
		),
		"MUTATION: a loaded Cinder generation makes the default resident scenario fail closed"
	)
	var report := CENSUS.measure_scene(
		game,
		roster.points as Array[Dictionary],
		CENSUS.SCENARIO_CINDER_LOADED,
		1
	)
	var lights := report.scene_lights as Dictionary
	var by_type := lights.by_type as Dictionary
	var resident_lights := resident_report.scene_lights as Dictionary
	var resident_by_type := resident_lights.by_type as Dictionary
	print("STATION_LIGHT_OVERLAP_CINDER_LOADED_RESULT: ", {
		"scenario": report.scenario,
		"loaded_instance_count": report.loaded_instance_count,
		"measurement_fingerprint": report.measurement_fingerprint,
		"scene_lights": lights,
	})
	_check(
		report.scenario == CENSUS.SCENARIO_CINDER_LOADED
		and int(report.loaded_instance_count) == 1
		and int(lights.total) == 320
		and int(lights.enabled) == 268
		and int(lights.disabled) == 52
		and int(lights.shadow_casting_total) == 19
		and int(lights.enabled_shadow_casting) == 19
		and int((by_type.directional as Dictionary).total) == 3
		and int((by_type.directional as Dictionary).enabled) == 3
		and int((by_type.omni as Dictionary).total) == 305
		and int((by_type.omni as Dictionary).enabled) == 253
		and int((by_type.spot as Dictionary).total) == 12
		and int((by_type.spot as Dictionary).enabled) == 12,
		"Cinder-loaded HIGH freezes 320 total / 268 enabled lights and exact type/shadow splits"
	)
	_check(
		int(lights.total) - int(resident_lights.total) == 23
		and int(lights.enabled) - int(resident_lights.enabled) == 23
		and int(lights.disabled) - int(resident_lights.disabled) == 0
		and int(lights.shadow_casting_total)
			- int(resident_lights.shadow_casting_total) == 0
		and int((by_type.omni as Dictionary).total)
			- int((resident_by_type.omni as Dictionary).total) == 22
		and int((by_type.spot as Dictionary).total)
			- int((resident_by_type.spot as Dictionary).total) == 1
		and int((by_type.directional as Dictionary).total)
			- int((resident_by_type.directional as Dictionary).total) == 0,
		"streaming delta is exactly +22 omni and +1 spot with no disabled, directional, or shadow change"
	)
	_check(
		str(report.sample_roster_fingerprint) == ROSTER_FINGERPRINT
		and str(report.measurement_fingerprint)
			== CINDER_LOADED_MEASUREMENT_FINGERPRINT,
		"Cinder-loaded roster and complete contributor measurement retain their separate fingerprint"
	)
	var json_first := CENSUS.deterministic_json(report)
	var json_second := CENSUS.deterministic_json(CENSUS.measure_scene(
		game,
		roster.points as Array[Dictionary],
		CENSUS.SCENARIO_CINDER_LOADED,
		1
	))
	_check(
		json_first == json_second
		and json_first.contains("\"scenario\": \"cinder_loaded\"")
		and json_first.contains("\"loaded_instance_count\": 1"),
		"loaded scenario emits deterministic JSON with explicit residency identity"
	)


func _light_records_under(roster: Array[Dictionary], prefix: String) -> Array[Dictionary]:
	var matches: Array[Dictionary] = []
	for record in roster:
		if str(record.path).begins_with(prefix):
			matches.append(record)
	return matches


func _light_paths(records: Array[Dictionary]) -> Array[String]:
	var paths: Array[String] = []
	for record in records:
		paths.append(str(record.path))
	return paths


func _all_enabled_shadowless_omni(records: Array[Dictionary]) -> bool:
	for record in records:
		if (
			str(record.type) != "omni"
			or not bool(record.enabled)
			or bool(record.shadow_enabled)
		):
			return false
	return not records.is_empty()


func _fixture_sample(point_id: StringName, position: Vector3) -> Dictionary:
	return {
		"point_id": point_id,
		"category": &"fixture",
		"position": position,
		"source_kind": &"fixture",
		"source_path": "fixture/%s" % point_id,
		"visual_layer_mask": 1,
	}


func _contributor(point: Dictionary, path: String) -> Dictionary:
	for contributor in point.contributors as Array:
		if str((contributor as Dictionary).path) == path:
			return contributor as Dictionary
	return {}


func _point(report: Dictionary, point_id: StringName) -> Dictionary:
	for point in report.points as Array[Dictionary]:
		if StringName(point.point_id) == point_id:
			return point
	return {}


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("STATION_LIGHT_OVERLAP_CENSUS_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		print("STATION_LIGHT_OVERLAP_CENSUS_TEST_FAILED: ", "; ".join(_failures))
		quit(1)
