extends SceneTree

## Focused deterministic fixtures plus a frozen production-Main measurement.

const CENSUS := preload("res://tools/station_light_overlap_census.gd")
const MAIN_SCENE := preload("res://scenes/main.tscn")

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
	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	for _frame in CENSUS.DEFAULT_SETTLE_FRAMES:
		await process_frame
	await physics_frame
	await process_frame
	game.process_mode = Node.PROCESS_MODE_DISABLED
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
	var report := CENSUS.measure_scene(game, roster.points as Array[Dictionary])
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
	var json_second := CENSUS.deterministic_json(CENSUS.measure_scene(game, roster.points as Array[Dictionary]))
	_check(json_first == json_second, "frozen production phase emits byte-identical JSON on repeat measurement")
	var scene_lights := report.scene_lights as Dictionary
	var by_type := scene_lights.by_type as Dictionary
	_check(
		int(scene_lights.total) == 315
		and int(scene_lights.enabled) == 263
		and int(scene_lights.disabled) == 52
		and int(scene_lights.shadow_casting_total) == 19
		and int(scene_lights.enabled_shadow_casting) == 19
		and int((by_type.directional as Dictionary).total) == 3
		and int((by_type.directional as Dictionary).enabled) == 3
		and int((by_type.omni as Dictionary).total) == 300
		and int((by_type.omni as Dictionary).enabled) == 248
		and int((by_type.spot as Dictionary).total) == 12
		and int((by_type.spot as Dictionary).enabled) == 12,
		"production freeze retains 315 total / 263 enabled lights and exact type/shadow splits"
	)
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
		str(report.sample_roster_fingerprint) == "7bfe535a02a8e891ce9c9296d09223aa8dd99276fea14e716ce1db0050e9feca"
		and str(report.measurement_fingerprint) == "d562fe1c2faf37f63ac4694606f634168bb27c784937d1efcb7249d6e360716a",
		"production roster and complete per-point contributor measurement have frozen fingerprints"
	)
	_check(
		not json_first.contains("@OmniLight3D@")
		and not json_first.contains("@SpotLight3D@"),
		"runtime fallback light names are canonicalized to stable sibling ordinals in JSON paths"
	)
	game.queue_free()
	await process_frame
	await physics_frame
	await process_frame


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
