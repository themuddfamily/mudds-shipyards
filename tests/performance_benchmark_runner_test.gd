extends SceneTree

const RUNNER := preload("res://tools/performance/benchmark_runner.gd")

var _failures: Array[String] = []
var _assertions := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_percentile_contract()
	_test_metadata_and_representativeness_contract()
	_test_schema_mutations()
	await _test_live_smoke()
	_finish()


func _test_percentile_contract() -> void:
	var samples: Array[float] = []
	for value in 100:
		samples.append(float(value + 1))
	var summary := RUNNER.summarize_samples(samples)
	_check(
		summary == {"count": 100, "p50": 50.0, "p95": 95.0, "p99": 99.0, "max": 100.0},
		"nearest-rank p50/p95/p99/max fixture is exact"
	)
	var mutated := samples.duplicate()
	mutated[98] = 999.0
	var mutated_summary := RUNNER.summarize_samples(mutated)
	_check(
		float(mutated_summary.p99) == 100.0
		and float(mutated_summary.max) == 999.0
		and mutated_summary != summary,
		"tail mutation changes both the percentile fingerprint and maximum"
	)
	_check(RUNNER.percentile([] as Array[float], 0.95) == -1.0, "empty samples cannot manufacture a percentile")


func _test_metadata_and_representativeness_contract() -> void:
	var observed := _environment_fixture("NVIDIA GeForce RTX Target", "Windows", "windows", [1920, 1080])
	var target := observed.duplicate(true)
	var matched := RUNNER.classify_representativeness(observed, target)
	_check(bool(matched.hardware_match), "an exact separately declared hardware profile is eligible to be representative")
	var mismatched_target := target.duplicate(true)
	mismatched_target.gpu.adapter = "Different GPU"
	var mismatched := RUNNER.classify_representativeness(observed, mismatched_target)
	_check(
		not bool(mismatched.hardware_match)
		and _contains_fragment(mismatched.reasons, "target mismatch gpu.adapter"),
		"one hardware metadata mutation makes the run nonrepresentative"
	)
	var software := _environment_fixture("llvmpipe (LLVM 19.1.7, 256 bits)", "Linux", "x11", [1920, 1080])
	var software_classification := RUNNER.classify_representativeness(software, software.duplicate(true))
	_check(
		not bool(software_classification.hardware_match)
		and _contains_fragment(software_classification.reasons, "software renderer detected"),
		"llvmpipe self-labels nonrepresentative even when a target copies its metadata"
	)
	var undeclared := RUNNER.classify_representativeness(observed, {})
	_check(
		not bool(undeclared.hardware_match)
		and _contains_fragment(undeclared.reasons, "no separately declared target profile"),
		"missing target declaration can never become a representative pass"
	)


func _test_schema_mutations() -> void:
	var environment := _environment_fixture("Target GPU", "Windows", "windows", [1920, 1080])
	var scenarios: Array[Dictionary] = [
		_scenario_fixture("station_embodied_route"),
		_scenario_fixture("nearby_sector_ship_flight_route"),
	]
	var classification := RUNNER.classify_representativeness(environment, environment.duplicate(true))
	classification.representative_pass = true
	var report := RUNNER.build_report(
		{"git_sha": "0123456789abcdef", "git_dirty": false},
		environment,
		environment.duplicate(true),
		classification,
		scenarios,
		{
			"warmup_frames_per_scenario": 2,
			"sample_frames_per_scenario": 4,
			"scenario_order": PackedStringArray(RUNNER.SCENARIO_NAMES),
			"resolution": [1920, 1080],
			"quality_level": 2,
			"smoke_run": false,
		}
	)
	_check(RUNNER.validate_report(report).is_empty(), "complete schema fixture validates")

	var missing_driver := report.duplicate(true)
	missing_driver.environment.gpu.erase("driver")
	_check(
		_contains_fragment(RUNNER.validate_report(missing_driver), "environment.gpu.driver is required"),
		"removing driver provenance makes the schema fixture fail"
	)
	var invented_vram := report.duplicate(true)
	invented_vram.unavailable_metrics.vram_bytes.available = true
	invented_vram.unavailable_metrics.vram_bytes.value = 1234
	_check(
		_contains_fragment(RUNNER.validate_report(invented_vram), "vram_bytes must be explicitly unavailable"),
		"inventing a VRAM metric makes the schema fixture fail"
	)
	var invalid_percentiles := report.duplicate(true)
	invalid_percentiles.scenarios[0].frame_delta_ms.p99 = 1.0
	_check(
		_contains_fragment(RUNNER.validate_report(invalid_percentiles), "frame_delta_ms summary is invalid"),
		"non-monotonic percentile mutation makes the schema fixture fail"
	)
	var false_pass := report.duplicate(true)
	false_pass.representativeness.hardware_match = false
	_check(
		_contains_fragment(RUNNER.validate_report(false_pass), "representative_pass requires"),
		"a representative-pass without a hardware match is rejected"
	)
	var dirty_pass := report.duplicate(true)
	dirty_pass.source.git_dirty = true
	_check(
		_contains_fragment(RUNNER.validate_report(dirty_pass), "representative_pass requires a clean source tree"),
		"a dirty source tree cannot claim representative-pass"
	)
	var idle_station := report.duplicate(true)
	idle_station.scenarios[0].scenario_progress.path_distance_m = 0.0
	idle_station.scenarios[0].scenario_progress.maximum_displacement_m = 0.0
	_check(
		_contains_fragment(RUNNER.validate_report(idle_station), "actor path did not advance"),
		"a station scenario that silently benchmarks idle fails schema validation"
	)
	var idle_flight := report.duplicate(true)
	idle_flight.scenarios[1].scenario_progress.accepted_propulsion_observed = false
	idle_flight.scenarios[1].scenario_progress.maximum_target_progress_m = 0.0
	_check(
		_contains_fragment(RUNNER.validate_report(idle_flight), "accepted propulsion demand")
		and _contains_fragment(RUNNER.validate_report(idle_flight), "no progress toward"),
		"a flight with no accepted propulsion or target progress fails closed"
	)
	var unhealthy_flight := report.duplicate(true)
	unhealthy_flight.scenarios[1].scenario_progress.healthy_throughout = false
	_check(
		_contains_fragment(RUNNER.validate_report(unhealthy_flight), "did not remain healthy"),
		"an unhealthy production flight cannot validate as a benchmark scenario"
	)
	var missed_endpoint := report.duplicate(true)
	missed_endpoint.scenarios[1].scenario_progress.minimum_target_distance_m = 21.0
	_check(
		_contains_fragment(RUNNER.validate_report(missed_endpoint), "never entered the route endpoint radius"),
		"a full flight must reach the bounded endpoint radius"
	)
	var relabelled_smoke := report.duplicate(true)
	relabelled_smoke.scenarios[1].scenario_progress.policy = "bounded_progress_smoke"
	relabelled_smoke.scenarios[1].scenario_progress.endpoint_required = false
	_check(
		_contains_fragment(RUNNER.validate_report(relabelled_smoke), "progress policy does not match")
		and _contains_fragment(RUNNER.validate_report(relabelled_smoke), "endpoint requirement does not match"),
		"a full report cannot relabel one scenario as smoke to bypass its endpoint"
	)
	var nonfinite_progress := report.duplicate(true)
	nonfinite_progress.scenarios[0].scenario_progress.path_distance_m = NAN
	_check(
		_contains_fragment(RUNNER.validate_report(nonfinite_progress), "actor path did not advance"),
		"non-finite progress fails closed instead of satisfying movement"
	)


func _test_live_smoke() -> void:
	var report := await RUNNER.run_benchmark(self, 1, 3, Vector2i(640, 360), 0, {}, true)
	var errors := RUNNER.validate_report(report)
	_check(errors.is_empty(), "short production-Main smoke emits a valid report: %s" % "; ".join(errors))
	_check(report.scenarios.size() == 2, "live smoke executes both named scenarios")
	for scenario_variant in report.scenarios:
		var scenario := scenario_variant as Dictionary
		_check(bool(scenario.completed), "%s live smoke completes" % scenario.name)
		_check(int(scenario.sample_count) == 3, "%s records the exact smoke sample count" % scenario.name)
		_check(not (scenario.scene_counts as Dictionary).is_empty(), "%s records scene counts" % scenario.name)
		_check(not (scenario.monitors as Dictionary).is_empty(), "%s records engine monitors" % scenario.name)
		var progress := scenario.scenario_progress as Dictionary
		_check(progress.policy == "bounded_progress_smoke", "%s records the smoke progress policy" % scenario.name)
		_check(
			(progress.start_transform as Dictionary) != (progress.end_transform as Dictionary)
			and float(progress.path_distance_m) > RUNNER.MINIMUM_SMOKE_MOVEMENT_METERS,
			"%s records distinct transforms and real bounded movement" % scenario.name
		)
		if StringName(scenario.name) == &"station_embodied_route":
			_check(
				progress.actor_type == "PlayerController"
				and float(progress.horizontal_path_distance_m) > RUNNER.MINIMUM_SMOKE_MOVEMENT_METERS,
				"station smoke proves horizontal production PlayerController movement"
			)
		else:
			_check(
				bool(progress.engine_online_observed)
				and bool(progress.accepted_propulsion_observed)
				and float(progress.maximum_target_progress_m) > RUNNER.MINIMUM_SMOKE_MOVEMENT_METERS,
				"flight smoke proves accepted ONLINE propulsion and real target progress"
			)
			_check(
				bool(progress.healthy_throughout)
				and not bool(progress.destroyed_end)
				and float(progress.minimum_hull) > 0.0,
				"flight smoke records a healthy production craft throughout"
			)
	_check(
		not bool(report.representativeness.representative_pass)
		and _contains_fragment(report.representativeness.reasons, "no separately declared target profile")
		and _contains_fragment(report.representativeness.reasons, "smoke protocol is bounded-progress-only"),
		"smoke output refuses representative-pass by hardware and protocol policy"
	)
	_check(
		not bool(report.unavailable_metrics.gpu_frame_time_ms.available)
		and report.unavailable_metrics.gpu_frame_time_ms.value == null
		and not bool(report.unavailable_metrics.vram_bytes.available)
		and report.unavailable_metrics.vram_bytes.value == null,
		"live smoke labels GPU time and VRAM unavailable"
	)
	print("PERFORMANCE_BENCHMARK_SMOKE_PROGRESS: ", JSON.stringify([
		(report.scenarios[0] as Dictionary).scenario_progress,
		(report.scenarios[1] as Dictionary).scenario_progress,
	]))


func _environment_fixture(adapter: String, os_name: String, display: String, resolution: Array) -> Dictionary:
	return {
		"godot_version": "4.7.1.stable.official",
		"os": {"name": os_name, "version": "fixture", "distribution": "fixture"},
		"cpu": {"name": "Fixture CPU", "logical_processors": 8},
		"gpu": {
			"adapter": adapter,
			"vendor": "Fixture Vendor",
			"driver": PackedStringArray(["fixture-driver"]),
			"api_version": "fixture-api",
		},
		"render": {
			"method": "gl_compatibility",
			"project_method": "gl_compatibility",
			"display_server": display,
			"resolution": resolution,
		},
		"profile": {"quality_level": 2, "quality_name": "High"},
	}


func _scenario_fixture(name: String) -> Dictionary:
	return {
		"name": name,
		"completed": true,
		"error": "",
		"deterministic_inputs": {"fixture": true},
		"scenario_progress": _progress_fixture(name),
		"warmup_frames": 2,
		"sample_count": 4,
		"frame_delta_ms": {"count": 4, "p50": 8.0, "p95": 12.0, "p99": 12.0, "max": 12.0},
		"monitors": {"cpu_process_ms": {"available": true, "summary": {"count": 4, "p50": 1.0, "p95": 2.0, "p99": 2.0, "max": 2.0}}},
		"ram": {"static_bytes_after_sample": 100, "static_peak_bytes": 120},
		"scene_counts": {"nodes": 10},
		"startup": {"main_instantiate_ms": 1.0, "main_first_ready_frames_ms": 2.0},
		"quality_report": {"applied": true},
	}


func _progress_fixture(name: String) -> Dictionary:
	var common := {
		"policy": "full_route",
		"endpoint_required": false,
		"start_transform": _transform_fixture(0.0),
		"end_transform": _transform_fixture(2.0),
		"path_distance_m": 2.0,
		"horizontal_path_distance_m": 2.0,
		"displacement_m": 2.0,
		"horizontal_displacement_m": 2.0,
		"maximum_displacement_m": 2.0,
		"maximum_horizontal_displacement_m": 2.0,
	}
	if name == "station_embodied_route":
		common.merge({"actor_type": "PlayerController", "control_enabled_end": true})
		return common
	common.merge({
		"actor_type": "HeroShip",
		"endpoint_required": true,
		"route_target": [0.0, 0.0, -100.0],
		"start_target_distance_m": 100.0,
		"end_target_distance_m": 8.0,
		"minimum_target_distance_m": 8.0,
		"maximum_target_progress_m": 92.0,
		"engine_online_observed": true,
		"accepted_propulsion_observed": true,
		"start_hull": 100.0,
		"end_hull": 100.0,
		"minimum_hull": 100.0,
		"healthy_throughout": true,
		"destroyed_end": false,
	}, true)
	return common


func _transform_fixture(z: float) -> Dictionary:
	return {
		"origin": [0.0, 0.0, z],
		"basis_x": [1.0, 0.0, 0.0],
		"basis_y": [0.0, 1.0, 0.0],
		"basis_z": [0.0, 0.0, 1.0],
	}


func _contains_fragment(values: Variant, fragment: String) -> bool:
	for value in values:
		if str(value).contains(fragment):
			return true
	return false


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty() and _assertions > 0:
		print("PERFORMANCE_BENCHMARK_RUNNER_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		if _assertions == 0:
			_failures.append("no assertions executed")
		print("PERFORMANCE_BENCHMARK_RUNNER_TEST_FAILED: ", "; ".join(_failures))
		quit(1)
