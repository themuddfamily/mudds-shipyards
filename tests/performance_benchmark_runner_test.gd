extends SceneTree

const RUNNER := preload("res://tools/performance/benchmark_runner.gd")

var _failures: Array[String] = []
var _assertions := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if OS.get_environment("KETH_BENCHMARK_TEST_AURORA_SURFACE") == "1":
		await _test_live_surface(true)
		_finish()
		return
	if OS.get_environment("KETH_BENCHMARK_TEST_EMBER_SURFACE") == "1":
		await _test_live_surface()
		_finish()
		return
	# Keep the original multi-Main fixture inside its existing 300-second cap.
	# Run this independent route with KETH_BENCHMARK_TEST_COMBAT=1.
	if OS.get_environment("KETH_BENCHMARK_TEST_COMBAT") == "1":
		await _test_live_range_combat()
		_finish()
		return
	_test_percentile_contract()
	_test_duration_contract()
	_test_metadata_and_representativeness_contract()
	_test_schema_mutations()
	await _test_emergency_input_guard()
	await _test_invalid_selection()
	await _test_live_abort()
	await _test_live_smoke()
	for selection: StringName in [&"station_embodied_route", &"nearby_sector_ship_flight_route", &"halyard_cabin_walk_route"]:
		await _test_live_abort(String(selection))
		if selection != &"halyard_cabin_walk_route":
			await _test_live_smoke(String(selection))
	await _test_live_cabin_shuttle()
	await _test_live_flight_shuttle()
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


func _test_duration_contract() -> void:
	_check(RUNNER.required_phase_frames(1, 3, false) == {"warmup": 3600, "sample": 18000},
		"full runs enforce both original frame floors even with shorter caller overrides")
	_check(RUNNER.required_phase_frames(4000, 20000, false) == {"warmup": 4000, "sample": 20000},
		"longer requested frame quotas are retained")
	_check(RUNNER.required_phase_frames(1, 3, true) == {"warmup": 1, "sample": 3},
		"diagnostic smoke preserves its short frame quotas")
	_check(RUNNER.phase_incomplete(18000, 18000, 300.0, 600.0), "fast frame quota cannot end a short sample")
	_check(RUNNER.phase_incomplete(9000, 18000, 600.0, 600.0), "duration quota cannot bypass minimum sample frames")
	_check(not RUNNER.phase_incomplete(18000, 18000, 600.0, 600.0), "both duration and frame minima complete the phase")
	_check(RUNNER.required_phase_seconds({"budgets": {"warmup_seconds": 90, "sample_seconds": 900}}, false)
		== {"warmup": 90.0, "sample": 900.0}, "longer reviewed duration budgets are retained")
	_check(RUNNER.required_phase_seconds({"budgets": {"sample_seconds": 1}}, false).sample == 600.0,
		"a short target cannot lower the production duration floor")
	_check(RUNNER.required_phase_seconds({}, true) == {"warmup": 0.0, "sample": 0.0}, "smoke remains frame bounded")
	_check(is_equal_approx(RUNNER.phase_progress(18000, 18000, 300.0, 600.0), 0.5),
		"fast frames stretch route progression over the full measured window")


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
			"warmup_frames_per_scenario": 3600,
			"sample_frames_per_scenario": 18000,
			"scenario_order": PackedStringArray(RUNNER.DEFAULT_SCENARIO_ORDER),
			"resolution": [1920, 1080],
			"quality_level": 2,
			"smoke_run": false,
		}
	)
	_check(RUNNER.validate_report(report).is_empty(), "complete schema fixture validates")

	for scenario_name: StringName in RUNNER.DEFAULT_SCENARIO_ORDER:
		var selected := report.duplicate(true)
		selected.scenarios = [(report.scenarios[0] if scenario_name == RUNNER.SCENARIO_NAMES[0] else report.scenarios[1]).duplicate(true)]
		selected.configuration.scenario_order = PackedStringArray([scenario_name])
		_check(not RUNNER.validate_report(selected).is_empty(), "strict full validation rejects a selected-only report")
		_check(_contains_fragment(RUNNER.validate_selected_diagnostic_report(selected, String(scenario_name)), "representative_pass is forbidden"),
			"selected report cannot claim representative pass even on matching clean hardware")
		selected.representativeness.representative_pass = false
		_check(RUNNER.validate_selected_diagnostic_report(selected, String(scenario_name)).is_empty(),
			"selected diagnostic validation retains a valid full-duration route")
		selected.scenarios[0].sample_elapsed_seconds = 300.0
		_check(_contains_fragment(RUNNER.validate_selected_diagnostic_report(selected, String(scenario_name)), "sample elapsed duration"),
			"selected diagnostic validation preserves per-route duration checks")
	var cabin := report.duplicate(true)
	cabin.scenarios = [_scenario_fixture("halyard_cabin_walk_route")]
	cabin.configuration.scenario_order = PackedStringArray(["halyard_cabin_walk_route"])
	cabin.representativeness.representative_pass = false
	_check(RUNNER.validate_selected_diagnostic_report(cabin, "halyard_cabin_walk_route").is_empty(), "full-duration cabin diagnostic fixture validates")
	_check(not RUNNER.validate_report(cabin).is_empty(), "cabin diagnostic cannot replace original full protocol")
	for field in ["local_path_distance_m", "maximum_local_displacement_m", "sample_local_path_distance_m", "support_throughout", "occupancy_throughout", "control_throughout", "inside_throughout", "stationary_throughout", "healthy_throughout", "outbound_reached", "return_reached"]:
		var broken := cabin.duplicate(true)
		broken.scenarios[0].scenario_progress[field] = 0
		_check(not RUNNER.validate_selected_diagnostic_report(broken, "halyard_cabin_walk_route").is_empty(), "cabin rejects missing actual route condition: " + field)
	var jitter_only := cabin.duplicate(true)
	jitter_only.scenarios[0].scenario_progress.sample_local_path_distance_m = 0.01
	_check(_contains_fragment(RUNNER.validate_selected_diagnostic_report(jitter_only, "halyard_cabin_walk_route"), "one aisle length"), "full cabin rejects jitter-only sampling after warm-up traversal")
	cabin.scenarios[0].sample_elapsed_seconds = 300.0
	_check(_contains_fragment(RUNNER.validate_selected_diagnostic_report(cabin, "halyard_cabin_walk_route"), "sample elapsed duration"), "full selected cabin retains ten-minute sample floor")
	var duplicate_scenario := report.duplicate(true)
	duplicate_scenario.scenarios[1] = duplicate_scenario.scenarios[0].duplicate(true)
	_check(_contains_fragment(RUNNER.validate_report(duplicate_scenario), "required protocol"),
		"two copies of one scenario cannot qualify the full protocol")
	for phase in ["warmup_frames", "sample_count"]:
		var short_frames := report.duplicate(true)
		short_frames.scenarios[0][phase] = 2
		_check(_contains_fragment(RUNNER.validate_report(short_frames), "warm-up/sample counts"),
			"full report cannot lower the original frame floor")
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
	var resized := report.duplicate(true)
	resized.scenarios[0].resolution_after.framebuffer = [1280, 720]
	_check(_contains_fragment(RUNNER.validate_report(resized), "requested framebuffer"),
		"a window resized below the requested render resolution cannot qualify")
	var short_sample := report.duplicate(true)
	short_sample.scenarios[0].sample_elapsed_seconds = 300.0
	_check(_contains_fragment(RUNNER.validate_report(short_sample), "sample elapsed duration"),
		"a claimed full record with only five sampled minutes fails qualification")
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
	var idle_sample := report.duplicate(true)
	idle_sample.scenarios[1].scenario_progress.sample_path_distance_m = 0.0
	_check(_contains_fragment(RUNNER.validate_report(idle_sample), "did not move during sampling"),
		"warm-up-only flight motion cannot qualify a full benchmark sample")
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


func _test_emergency_input_guard() -> void:
	var guard := RUNNER.BenchmarkInputGuard.new()
	root.add_child(guard)
	var was_paused := paused
	paused = true
	Input.action_press(&"move_forward")
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape)
	_check(guard.aborted and guard.reason == "Escape pressed", "physical Escape aborts before GUI handling even while the tree is paused")
	_check(not Input.is_action_pressed(&"move_forward") and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,
		"emergency abort releases injected movement and the cursor")
	paused = was_paused
	guard.free()
	guard = RUNNER.BenchmarkInputGuard.new()
	root.add_child(guard)
	root.window_input.connect(guard._input)
	escape.pressed = true
	root.window_input.emit(escape)
	escape.pressed = false
	root.window_input.emit(escape)
	_check(guard.aborted, "raw window input catches an Escape tap before scene or GUI consumption")
	guard.free()
	guard = RUNNER.BenchmarkInputGuard.new()
	root.add_child(guard)
	guard.on_close_requested()
	_check(guard.aborted and guard.reason == "window close requested", "window close uses the same explicit abort path")
	guard.free()
	guard = RUNNER.BenchmarkInputGuard.new()
	root.add_child(guard)
	guard.on_focus_exited()
	_check(guard.aborted and guard.reason == "benchmark window lost focus", "focus loss aborts instead of continuing a hidden benchmark")
	guard.free()
	if DisplayServer.get_name() != "headless":
		guard = RUNNER.BenchmarkInputGuard.new()
		root.add_child(guard)
		var rendering_was_enabled := RenderingServer.render_loop_enabled
		RenderingServer.render_loop_enabled = false
		guard.call_deferred("request_abort", "hidden-window abort")
		var resolution := await RUNNER.capture_resolution(self, Vector2i(640, 360), guard)
		_check(guard.aborted and resolution.is_empty(), "disabled-render-loop framebuffer wait exits on abort without manufacturing capture evidence")
		guard.free()
		RenderingServer.render_loop_enabled = rendering_was_enabled


func _test_invalid_selection() -> void:
	var main_launches := [0]
	var observe_launch := func(node: Node) -> void:
		if node is GameFlow:
			main_launches[0] += 1
	node_added.connect(observe_launch)
	var children_before := root.get_child_count()
	var size_before := root.size
	var result := await RUNNER.run_benchmark(self, 1, 3, Vector2i(640, 360), 0, {}, true, "unknown_route")
	node_added.disconnect(observe_launch)
	_check(result.has("selection_error") and not result.has("scenarios"), "unknown scenario is rejected without a report")
	_check(main_launches[0] == 0 and root.get_child_count() == children_before and root.size == size_before,
		"unknown selection rejects before Main instantiation or window mutation")


func _test_live_abort(selection: String = "") -> void:
	var children_before := root.get_child_count()
	var original_auto_quit := auto_accept_quit
	call_deferred("_abort_next_benchmark", selection == "halyard_cabin_walk_route")
	var result := await RUNNER.run_benchmark(self, 1, 3, Vector2i(640, 360), 0, {}, true, selection)
	_check(bool(result.get("aborted", false)) and not result.has("scenarios") \
		and not result.has("representativeness"), "aborted production startup produces no completed or qualifying report")
	_check(root.get_child_count() == children_before and auto_accept_quit == original_auto_quit,
		"abort frees Main and its input guard and restores window-close policy")
	_check(not Input.is_action_pressed(&"move_forward") and not Input.is_action_pressed(&"move_back")
		and not Input.is_action_pressed(&"brake") and not Input.is_action_pressed(&"sprint_boost")
		and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "aborted selection releases movement and cursor")


func _abort_next_benchmark(wait_for_cabin_walk: bool = false) -> void:
	await process_frame
	if wait_for_cabin_walk:
		var originating_guard: RUNNER.BenchmarkInputGuard
		for child in root.get_children():
			if child is RUNNER.BenchmarkInputGuard:
				originating_guard = child
		_check(originating_guard != null, "cabin abort observer binds the originating input guard")
		if originating_guard == null:
			return
		var walking := false
		var deadline := Time.get_ticks_msec() + RUNNER.BEGIN_SHIFT_READY_TIMEOUT_MS + 30_000
		while not walking and Time.get_ticks_msec() < deadline:
			# A failed staging run must never leave an observer that can Escape
			# a subsequent Main instance after its own benchmark has ended.
			if not is_instance_valid(originating_guard):
				_check(false, "cabin abort reaches its walker before the originating benchmark ends")
				return
			var game := root.get_node_or_null("Main")
			if game != null:
				for child in game.get_children():
					if child is RUNNER.BenchmarkCabinWalker and child.guard == originating_guard and Input.is_action_pressed(&"move_forward"):
						walking = true
			if not walking:
				await process_frame
		_check(walking, "cabin abort reaches an active walker before its startup deadline")
		if not walking:
			if is_instance_valid(originating_guard):
				originating_guard.request_abort("cabin abort observer startup deadline")
			return
	paused = true
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	root.window_input.emit(escape)


func _test_live_smoke(selection: String = "") -> void:
	var visibility := {"station": 0, "flight": 0, "valid": true, "flight_ownership": true}
	var observe_gameplay := func() -> void:
		if not Input.is_action_pressed(&"move_forward"):
			return
		var game := root.get_node_or_null("Main")
		if game == null:
			return
		var hud := game.get_node("HUD") as GameHUD
		visibility.valid = bool(visibility.valid) and not hud._intro.visible and hud._hud.visible
		var scenario := "station"
		for child in game.get_children():
			if child is RUNNER.BenchmarkFlightPilot:
				scenario = "flight"
				var player := game.get_node("Player") as PlayerController
				visibility.flight_ownership = bool(visibility.flight_ownership) and (
					game._piloting and game.phase == GameFlow.Phase.FREE_FLIGHT
					and not player.is_control_enabled() and not player.get_camera().current
					and child.ship.get_camera().current and hud._state_mode == GameHUD.MODE_PILOTING
					and hud._hero_component_hud_binding._ship_reference.get_ref() == child.ship
				)
		visibility[scenario] = int(visibility[scenario]) + 1
	process_frame.connect(observe_gameplay)
	var report := await RUNNER.run_benchmark(self, 1, 3, Vector2i(640, 360), 0, {}, true, selection)
	process_frame.disconnect(observe_gameplay)
	_check(bool(visibility.valid)
		and (int(visibility.station) > 0) == (selection != "nearby_sector_ship_flight_route")
		and (int(visibility.flight) > 0) == (selection != "station_embodied_route"),
		"only requested scenarios run with the intro hidden and gameplay HUD displayed")
	_check(bool(visibility.flight_ownership) and (selection == "station_embodied_route" or int(visibility.flight) > 0),
		"flight stages piloting flow, ship camera and component HUD with on-foot controls disabled")
	var errors := RUNNER.validate_report(report) if selection.is_empty() else RUNNER.validate_selected_diagnostic_report(report, selection)
	_check(errors.is_empty(), "short production-Main smoke emits a valid report: %s" % "; ".join(errors))
	var expected_names := PackedStringArray(RUNNER.DEFAULT_SCENARIO_ORDER) if selection.is_empty() else PackedStringArray([selection])
	_check(report.scenarios.size() == expected_names.size() and report.configuration.scenario_order == expected_names,
		"live smoke executes the requested scenario order")
	if not selection.is_empty():
		_check(not RUNNER.validate_report(report).is_empty()
			and _contains_fragment(report.representativeness.reasons, "diagnostic-only"),
			"selected live report is explicitly partial and fails full-protocol validation")
	_check(root.get_node_or_null("Main") == null and not Input.is_action_pressed(&"move_forward")
		and not Input.is_action_pressed(&"move_back") and not Input.is_action_pressed(&"brake")
		and not Input.is_action_pressed(&"sprint_boost") and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,
		"completed selection frees Main and releases synthetic inputs and cursor")
	for scenario_variant in report.scenarios:
		var scenario := scenario_variant as Dictionary
		_check(bool(scenario.completed), "%s live smoke completes" % scenario.name)
		_check(float(scenario.warmup_elapsed_seconds) >= 0.0 and float(scenario.sample_elapsed_seconds) > 0.0,
			"%s records monotonic elapsed warmup and sampling" % scenario.name)
		_check(scenario.resolution_before.viewport == [640, 360] and scenario.resolution_after.viewport == [640, 360],
			"%s reapplies the requested viewport after Main startup" % scenario.name)
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
			var inputs := scenario.deterministic_inputs as Dictionary
			_check(
				inputs.get("route_source")
					== "coordinator_owned_cinder_streaming_generation"
				and inputs.get("streamed_location_id") == "cinder_reach"
				and int(inputs.get("streamed_generation", -1)) > 0
				and inputs.get("streaming_owner")
					== "CinderStreamingBootstrap/WorldStreamingCoordinator",
				"flight smoke resolves its route from one real streamed Cinder generation"
			)
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
	for scenario: Dictionary in report.scenarios:
		print("PERFORMANCE_BENCHMARK_SMOKE_PROGRESS: ", scenario.name, " ", JSON.stringify(scenario.scenario_progress))


func _test_live_flight_shuttle() -> void:
	var guard := RUNNER.BenchmarkInputGuard.new()
	root.add_child(guard)
	# Exercise endpoint-required progress without a ten-minute hardware timing
	# run. This outlasts the old pilot's terminal collision and station respawn.
	var report := await RUNNER._run_scenario(
		self, &"nearby_sector_ship_flight_route", 60, 240, 0, false,
		{"warmup": 3.0, "sample": 20.0}, Vector2i(640, 360), guard
	)
	var progress := report.scenario_progress as Dictionary
	_check(bool(report.completed), "sustained flight completes its endpoint-required route: %s" % report.error)
	_check(bool(progress.endpoint_required) and bool(progress.accepted_propulsion_observed)
		and bool(progress.engine_online_observed), "sustained route retains full endpoint and production propulsion requirements")
	_check(float(progress.minimum_hull) == float(progress.start_hull)
		and bool(progress.healthy_throughout), "sustained flight shuttles without collision damage or respawn")
	_check(float(progress.minimum_target_distance_m) <= RUNNER.FLIGHT_ENDPOINT_RADIUS_METERS
		and float(progress.sample_path_distance_m) > float(progress.start_target_distance_m),
		"sustained flight travels during sampling and visits its endpoint")
	_check(not Input.is_action_pressed(&"move_forward") and not Input.is_action_pressed(&"move_back")
		and not Input.is_action_pressed(&"brake") and not Input.is_action_pressed(&"sprint_boost"), "completed flight releases thrust, brake and boost")
	print("PERFORMANCE_BENCHMARK_FLIGHT_SHUTTLE_PROGRESS: ", JSON.stringify(progress))
	guard.free()


func _test_live_cabin_shuttle() -> void:
	# Short selected smoke checks the public selection and report path.
	var smoke := await RUNNER.run_benchmark(self, 1, 3, Vector2i(640, 360), 0, {}, true, "halyard_cabin_walk_route")
	var errors := RUNNER.validate_selected_diagnostic_report(smoke, "halyard_cabin_walk_route")
	_check(errors.is_empty(), "selected cabin smoke validates: " + "; ".join(errors))
	_check(not RUNNER.validate_report(smoke).is_empty() and not smoke.representativeness.representative_pass and smoke.representativeness.performance_budget_pass == null, "cabin remains partial and cannot grant performance acceptance")
	var guard := RUNNER.BenchmarkInputGuard.new()
	root.add_child(guard)
	# Exercise physical out-and-back and measured motion inside the existing
	# suite cap, without claiming full hardware benchmark durations.
	var report := await RUNNER._run_scenario(self, &"halyard_cabin_walk_route", 15, 180, 0, false,
		{"warmup": 0.5, "sample": 8.0}, Vector2i(640, 360), guard)
	var progress := report.get("scenario_progress", {}) as Dictionary
	_check(bool(report.get("completed", false)), "cabin completes physical aisle out-and-back: " + str(report.get("error", "")))
	_check(bool(progress.get("outbound_reached", false)) and bool(progress.get("return_reached", false)) and float(progress.get("sample_local_path_distance_m", 0.0)) > 5.0, "cabin walks both endpoints and moves during sampling")
	_check(root.get_node_or_null("Main") == null and not Input.is_action_pressed(&"move_forward") and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "cabin success frees walker and releases movement/cursor")
	print("PERFORMANCE_BENCHMARK_CABIN_SHUTTLE_PROGRESS: ", JSON.stringify(progress))
	guard.free()


func _test_live_surface(aurora: bool = false) -> void:
	var label := "Aurora" if aurora else "Ember"
	var selection := "aurora_surface_walk_route" if aurora else "ember_surface_walk_route"
	var smoke := await RUNNER.run_benchmark(self, 1, 3, Vector2i(640, 360), 0, {}, true, selection)
	var errors := RUNNER.validate_selected_diagnostic_report(smoke, selection)
	_check(errors.is_empty(), "selected " + label + " surface smoke validates: " + "; ".join(errors))
	if not smoke.has("scenarios"):
		return
	var scenario := smoke.scenarios[0] as Dictionary
	var progress := scenario.get("scenario_progress", {}) as Dictionary
	print("PERFORMANCE_BENCHMARK_%s_SURFACE_STAGING: " % label.to_upper(), JSON.stringify(scenario.get("deterministic_inputs", {})))
	print("PERFORMANCE_BENCHMARK_%s_SURFACE_SMOKE_PROGRESS: " % label.to_upper(), JSON.stringify(progress))
	if progress.is_empty():
		return
	var round_trip := JSON.parse_string(JSON.stringify(smoke)) as Dictionary
	_check(RUNNER.validate_selected_diagnostic_report(round_trip, selection).is_empty(),
		"saved " + label + " surface JSON round trip validates")
	_check(not RUNNER.validate_report(smoke).is_empty() and not smoke.representativeness.representative_pass \
		and smoke.representativeness.performance_budget_pass == null,
		label + " selection cannot qualify the default protocol or performance")
	var staged := scenario.deterministic_inputs as Dictionary
	_check(staged.get("streamed_location_id") == ("aurora_temperate_world" if aurora else "ember_moon") \
		and int(staged.get("streamed_generation", 0)) > 0 \
		and int(staged.get("coordinate_frame_generation", 0)) > int(staged.get("initial_coordinate_frame_generation", 0)) \
		and int(staged.get("initial_player_placements", 0)) == 1,
		label + " stages one Player placement with a real streamed generation and committed origin rebase")
	_check(float(progress.get("sample_local_path_distance_m", 0.0)) > RUNNER.MINIMUM_SMOKE_MOVEMENT_METERS,
		"short " + label + " smoke walks physically during sampling")
	for mutation in ["idle", "warmup_only", "unsupported", "disabled", "wrong_world", "wrong_scene", "wrong_gravity", "no_input", "teleport", "fake_progress", "warmup_endpoints"]:
		var changed := progress.duplicate(true)
		match mutation:
			"idle": changed.local_path_distance_m = 0.0
			"warmup_only": changed.sample_local_path_distance_m = 0.0
			"unsupported": changed.support_throughout = false
			"disabled": changed.control_throughout = false
			"wrong_world": changed.world_id = "station"
			"wrong_scene": changed.world_identity_throughout = false
			"wrong_gravity": changed.minimum_gravity_mps2 = 1.62 if aurora else 9.8
			"no_input": changed.held_input_throughout = false
			"teleport": changed.maximum_physics_step_m = 5.0
			"fake_progress":
				changed.policy = "full_route"
				changed.sample_outbound_visits = 1
				changed.sample_return_visits = 1
				changed.sample_local_path_distance_m = 0.0
			"warmup_endpoints":
				changed.policy = "full_route"
				changed.outbound_visits = 1
				changed.return_visits = 1
				changed.sample_outbound_visits = 0
				changed.sample_return_visits = 0
		_check(not RUNNER.validate_scenario_progress(StringName(selection), changed).is_empty(), label + " rejects " + mutation)
	_check(root.get_node_or_null("Main") == null and not _surface_movement_pressed() \
		and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, label + " smoke frees Main and releases movement/cursor")
	var guard := RUNNER.BenchmarkInputGuard.new()
	root.add_child(guard)
	# Focused full-path primitive; never bypasses the public full benchmark's
	# 3,600/60-second and 18,000/600-second timing floors.
	var route := await RUNNER._run_scenario(self, StringName(selection), 15, 180, 0, false,
		{"warmup": 0.5, "sample": 45.0}, Vector2i(640, 360), guard)
	var route_progress := route.get("scenario_progress", {}) as Dictionary
	_check(bool(route.get("completed", false)), label + " completes the physical authored out-and-back: " + str(route.get("error", "")))
	_check(int(route_progress.get("sample_outbound_visits", 0)) > 0 \
		and int(route_progress.get("sample_return_visits", 0)) > 0 \
		and float(route_progress.get("sample_local_path_distance_m", 0.0)) >= 100.0,
		"focused " + label + " sample visits both endpoints through actual walking")
	if aurora:
		_check(int(route_progress.get("sample_terrain_support_observations", 0)) > 0 \
			and int(route_progress.get("sample_lookout_floor_support_observations", 0)) > 0 \
			and bool(route_progress.get("support_throughout", false)),
			"Aurora sample reaches actual generated terrain and the authored lookout floor")
		var terrain_mutation := route_progress.duplicate(true)
		terrain_mutation.sample_terrain_support_observations = 0
		_check(not RUNNER.validate_scenario_progress(StringName(selection), terrain_mutation).is_empty(),
			"Aurora full route rejects missing sampled generated terrain support")
		var route_round_trip := JSON.parse_string(JSON.stringify(route_progress)) as Dictionary
		_check(RUNNER.validate_scenario_progress(StringName(selection), route_round_trip).is_empty(),
			"Aurora physical endpoint/terrain record survives JSON round trip")
	_check(root.get_node_or_null("Main") == null and not _surface_movement_pressed(),
		label + " full-path success frees Main and releases movement")
	print("PERFORMANCE_BENCHMARK_%s_SURFACE_ROUTE_PROGRESS: " % label.to_upper(), JSON.stringify(route_progress))
	guard.free()
	call_deferred("_abort_live_surface_walk", aurora)
	var aborted := await RUNNER.run_benchmark(self, 1, 300, Vector2i(640, 360), 0, {}, true, selection)
	_check(bool(aborted.get("aborted", false)) and not aborted.has("scenarios") \
		and not aborted.has("representativeness"), "active " + label + " Escape emits no qualifying report")
	_check(root.get_node_or_null("Main") == null and not _surface_movement_pressed() \
		and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "active " + label + " abort frees Main and releases movement/cursor")


func _surface_movement_pressed() -> bool:
	for action in [&"move_forward", &"move_back", &"move_left", &"move_right"]:
		if Input.is_action_pressed(action):
			return true
	return false


func _abort_live_surface_walk(aurora: bool = false) -> void:
	var label := "Aurora" if aurora else "Ember"
	await process_frame
	var originating_guard: RUNNER.BenchmarkInputGuard
	for child in root.get_children():
		if child is RUNNER.BenchmarkInputGuard:
			originating_guard = child
	if originating_guard == null:
		_check(false, label + " abort binds its own guard")
		return
	var deadline := Time.get_ticks_msec() + RUNNER.BEGIN_SHIFT_READY_TIMEOUT_MS + 30_000
	while is_instance_valid(originating_guard) and Time.get_ticks_msec() < deadline:
		var game := root.get_node_or_null("Main")
		if game != null:
			for child in game.get_children():
				if child is RUNNER.BenchmarkEmberWalker and child.guard == originating_guard \
						and (not aurora or child is RUNNER.BenchmarkAuroraWalker) \
						and float(child.sampled_path) > 0.02 and _surface_movement_pressed():
					var body := child.player as PlayerController
					var original_multiplier := float(child.original_gravity)
					body.tree_exiting.connect(func() -> void:
						_check(is_equal_approx(body.gravity_multiplier, original_multiplier),
							label + " abort restores original gravity before Player exits"), CONNECT_ONE_SHOT)
					paused = true
					var escape := InputEventKey.new()
					escape.physical_keycode = KEY_ESCAPE
					escape.pressed = true
					root.window_input.emit(escape)
					_check(true, label + " Escape reaches active sampled walking independently of game pause")
					return
		await process_frame
	_check(false, label + " abort reaches sampled walking before startup deadline")
	if is_instance_valid(originating_guard):
		originating_guard.request_abort(label + " abort observer deadline")


func _test_live_range_combat() -> void:
	var selection := "torrent_range_combat_reuse_route"
	var report := await RUNNER.run_benchmark(self, 1, 3, Vector2i(640, 360), 0, {}, true, selection)
	var errors := RUNNER.validate_selected_diagnostic_report(report, selection)
	_check(errors.is_empty(), "real range combat smoke validates: " + "; ".join(errors))
	if not report.has("scenarios"):
		return
	var round_trip := JSON.parse_string(JSON.stringify(report)) as Dictionary
	var round_trip_errors := RUNNER.validate_selected_diagnostic_report(round_trip, selection)
	_check(round_trip_errors.is_empty(), "saved combat JSON round trip validates: " + "; ".join(round_trip_errors))
	var progress := (report.scenarios[0] as Dictionary).get("scenario_progress", {}) as Dictionary
	var staged := (report.scenarios[0] as Dictionary).get("deterministic_inputs", {}) as Dictionary
	print("PERFORMANCE_BENCHMARK_RANGE_COMBAT_STAGING: ", JSON.stringify(staged))
	_check(bool((staged.get("staging_reticle", {}) as Dictionary).get("target_intersection", false)),
		"combat stages an unobstructed production reticle ray onto the real target")
	print("PERFORMANCE_BENCHMARK_RANGE_COMBAT_PROGRESS: ", JSON.stringify(progress))
	_check(not RUNNER.validate_report(report).is_empty() and not report.representativeness.representative_pass and report.representativeness.performance_budget_pass == null,
		"combat selection cannot grant full-protocol or performance acceptance")
	_check(float(report.scenarios[0].sample_elapsed_seconds) >= 8.0, "combat smoke offers eight seconds of real sampled fire/reuse")
	for mutation in ["idle", "warmup_only", "unregistered", "direct_damage", "stalled_tail", "wrong_target", "fractional_counter", "string_counter", "boolean_counter", "unsafe_identity"]:
		var changed := progress.duplicate(true)
		match mutation:
			"idle":
				for field in changed.get("totals", {}):
					changed.totals[field] = 0
			"warmup_only":
				for field in changed.get("sampling", {}):
					changed.sampling[field] = 0
			"unregistered": changed.source_id = 0
			"direct_damage": changed.totals.damage_events = int(changed.totals.damage_events) + 1
			"stalled_tail": changed.maximum_sample_hit_gap_seconds = 11.0
			"wrong_target": changed.target_id = "DRONE-02"
			"fractional_counter": changed.sampling.shots = float(changed.sampling.shots) + 0.5
			"string_counter": changed.sampling.shots = str(changed.sampling.shots)
			"boolean_counter": changed.sampling.shots = true
			"unsafe_identity": changed.target_instance_id = 9007199254740992.0
		_check(not RUNNER.validate_scenario_progress(StringName(selection), changed).is_empty(), "combat rejects " + mutation)
	_check(root.get_node_or_null("Main") == null and not Input.is_action_pressed(&"fire") and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,
		"combat completion frees Main and releases fire/cursor")
	call_deferred("_abort_live_range_fire")
	var aborted := await RUNNER.run_benchmark(self, 1, 3, Vector2i(640, 360), 0, {}, true, selection)
	_check(bool(aborted.get("aborted", false)) and not aborted.has("scenarios") and not aborted.has("representativeness"),
		"active combat Escape produces no successful report")
	_check(root.get_node_or_null("Main") == null and not Input.is_action_pressed(&"fire") and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,
		"active combat abort frees Main and releases fire/cursor")


func _abort_live_range_fire() -> void:
	await process_frame
	var originating_guard: RUNNER.BenchmarkInputGuard
	for child in root.get_children():
		if child is RUNNER.BenchmarkInputGuard:
			originating_guard = child
	if originating_guard == null:
		_check(false, "combat abort binds its own guard")
		return
	var deadline := Time.get_ticks_msec() + RUNNER.BEGIN_SHIFT_READY_TIMEOUT_MS + 30_000
	while is_instance_valid(originating_guard) and Time.get_ticks_msec() < deadline:
		var game := root.get_node_or_null("Main")
		if game != null:
			for child in game.get_children():
				if child is RUNNER.BenchmarkRangeCombat and child.guard == originating_guard and int(child.totals.shots) > 0 and Input.is_action_pressed(&"fire"):
					paused = true
					var escape := InputEventKey.new()
					escape.physical_keycode = KEY_ESCAPE
					escape.pressed = true
					root.window_input.emit(escape)
					_check(true, "combat Escape reaches active production fire")
					return
		await process_frame
	_check(false, "combat abort reaches live fire before its startup deadline")
	if is_instance_valid(originating_guard):
		originating_guard.request_abort("combat abort observer deadline")


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
		"resolution_before": {"requested": [1920, 1080], "viewport": [1920, 1080], "window": [1920, 1080], "framebuffer_available": true, "framebuffer": [1920, 1080]},
		"resolution_after": {"requested": [1920, 1080], "viewport": [1920, 1080], "window": [1920, 1080], "framebuffer_available": true, "framebuffer": [1920, 1080]},
		"warmup_elapsed_seconds": 60.0,
		"sample_elapsed_seconds": 600.0,
		"warmup_frames": 3600,
		"sample_count": 18000,
		"frame_delta_ms": {"count": 18000, "p50": 8.0, "p95": 12.0, "p99": 12.0, "max": 12.0},
		"monitors": {"cpu_process_ms": {"available": true, "summary": {"count": 18000, "p50": 1.0, "p95": 2.0, "p99": 2.0, "max": 2.0}}},
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
	if name == "halyard_cabin_walk_route":
		common.merge({"actor_type": "PlayerController", "local_path_distance_m": 10.0, "maximum_local_displacement_m": 5.0, "sample_local_path_distance_m": 5.0, "aisle_length_m": 5.0,
			"support_throughout": true, "occupancy_throughout": true, "control_throughout": true, "inside_throughout": true, "stationary_throughout": true, "healthy_throughout": true,
			"outbound_reached": true, "return_reached": true})
		return common
	if name == "station_embodied_route":
		common.merge({"actor_type": "PlayerController", "control_enabled_end": true})
		return common
	common.merge({
		"actor_type": "HeroShip",
		"sample_path_distance_m": 2.0,
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
