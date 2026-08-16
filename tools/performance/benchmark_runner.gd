extends SceneTree

## Production-scene benchmark runner. This records measurements; it does not
## turn a software renderer or an undeclared machine into performance evidence.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const SCHEMA_VERSION := 1
const REPORT_KIND := "keths_performance_benchmark"
const DEFAULT_RESOLUTION := Vector2i(1920, 1080)
const DEFAULT_QUALITY_LEVEL := 2
const DEFAULT_WARMUP_FRAMES := 3600
const DEFAULT_SAMPLE_FRAMES := 18000
const SMOKE_WARMUP_FRAMES := 2
const SMOKE_SAMPLE_FRAMES := 4
const SCENARIO_NAMES := [&"station_embodied_route", &"nearby_sector_ship_flight_route"]
const MINIMUM_SMOKE_MOVEMENT_METERS := 0.001
const MINIMUM_FULL_STATION_PATH_METERS := 1.0
const FLIGHT_ENDPOINT_RADIUS_METERS := 20.0

const MONITORS := {
	"engine_fps": Performance.TIME_FPS,
	"cpu_process_ms": Performance.TIME_PROCESS,
	"cpu_physics_ms": Performance.TIME_PHYSICS_PROCESS,
	"navigation_ms": Performance.TIME_NAVIGATION_PROCESS,
	"render_objects": Performance.RENDER_TOTAL_OBJECTS_IN_FRAME,
	"render_primitives": Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME,
	"render_draw_calls": Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME,
	"scene_nodes": Performance.OBJECT_NODE_COUNT,
	"resources": Performance.OBJECT_RESOURCE_COUNT,
	"static_memory_bytes": Performance.MEMORY_STATIC,
}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var smoke := _environment_bool("KETH_BENCHMARK_SMOKE", false)
	var warmup_frames := _environment_int(
		"KETH_BENCHMARK_WARMUP_FRAMES",
		SMOKE_WARMUP_FRAMES if smoke else DEFAULT_WARMUP_FRAMES,
		1
	)
	var sample_frames := _environment_int(
		"KETH_BENCHMARK_SAMPLE_FRAMES",
		SMOKE_SAMPLE_FRAMES if smoke else DEFAULT_SAMPLE_FRAMES,
		2
	)
	var resolution := _environment_resolution("KETH_BENCHMARK_RESOLUTION", DEFAULT_RESOLUTION)
	var quality_level := clampi(
		_environment_int("KETH_BENCHMARK_QUALITY_LEVEL", DEFAULT_QUALITY_LEVEL, 0),
		0,
		2
	)
	var target := load_target_profile(OS.get_environment("KETH_BENCHMARK_TARGET_PROFILE"))
	var report := await run_benchmark(
		self, warmup_frames, sample_frames, resolution, quality_level, target, smoke
	)
	var errors := validate_report(report)
	if not errors.is_empty():
		printerr("PERFORMANCE_BENCHMARK_SCHEMA_FAILED: ", "; ".join(errors))
		quit(1)
		return
	var output_path := OS.get_environment("KETH_BENCHMARK_JSON")
	if output_path.is_empty():
		output_path = "user://performance_benchmark.json"
	var absolute_path := ProjectSettings.globalize_path(output_path)
	var output_directory := absolute_path.get_base_dir()
	if not output_directory.is_empty():
		DirAccess.make_dir_recursive_absolute(output_directory)
	var file := FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		printerr("PERFORMANCE_BENCHMARK_WRITE_FAILED: ", absolute_path)
		quit(1)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("PERFORMANCE_BENCHMARK_OK: ", absolute_path)
	print("representative_pass=", report.representativeness.representative_pass)
	quit(0)


static func run_benchmark(
		tree: SceneTree,
		warmup_frames: int,
		sample_frames: int,
		resolution: Vector2i,
		quality_level: int,
		target_profile: Dictionary = {},
		smoke_run: bool = false
	) -> Dictionary:
	var original_root_size := tree.root.size
	var requested_resolution := Vector2i(maxi(resolution.x, 1), maxi(resolution.y, 1))
	tree.root.size = requested_resolution
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(requested_resolution)
	var scenarios: Array[Dictionary] = []
	for scenario_name: StringName in SCENARIO_NAMES:
		scenarios.append(await _run_scenario(
			tree,
			scenario_name,
			maxi(warmup_frames, 1),
			maxi(sample_frames, 2),
			quality_level,
			smoke_run
		))
	_release_inputs()
	tree.root.size = original_root_size
	var observed := capture_environment(requested_resolution, quality_level)
	var source := capture_source_state()
	var representativeness := classify_representativeness(observed, target_profile)
	var representativeness_reasons := (
		representativeness.get("reasons", PackedStringArray()) as PackedStringArray
	)
	var completed := true
	for scenario in scenarios:
		completed = completed and bool(scenario.get("completed", false))
	if bool(source.get("git_dirty", true)):
		representativeness_reasons.append("source tree is dirty")
	if smoke_run:
		representativeness_reasons.append("smoke protocol is bounded-progress-only")
	representativeness["reasons"] = representativeness_reasons
	representativeness["representative_pass"] = (
		bool(representativeness.get("hardware_match", false))
		and not bool(source.get("git_dirty", true))
		and completed
		and not smoke_run
	)
	representativeness["performance_budget_pass"] = null
	return build_report(
		source,
		observed,
		target_profile,
		representativeness,
		scenarios,
		{
			"warmup_frames_per_scenario": maxi(warmup_frames, 1),
			"sample_frames_per_scenario": maxi(sample_frames, 2),
			"scenario_order": PackedStringArray(SCENARIO_NAMES),
			"frame_delta_clock": "Time.get_ticks_usec wall interval between consecutive process_frame signals",
			"quality_level": quality_level,
			"resolution": [requested_resolution.x, requested_resolution.y],
			"physics_ticks_per_second": Engine.physics_ticks_per_second,
			"engine_max_fps": Engine.max_fps,
			"smoke_run": smoke_run,
		}
	)


static func _run_scenario(
		tree: SceneTree,
		scenario_name: StringName,
		warmup_frames: int,
		sample_frames: int,
		quality_level: int,
		smoke_run: bool
	) -> Dictionary:
	_release_inputs()
	seed(_scenario_seed(scenario_name))
	var instantiate_started := Time.get_ticks_usec()
	var game := MAIN_SCENE.instantiate() as GameFlow
	var instantiated_ms := float(Time.get_ticks_usec() - instantiate_started) / 1000.0
	if game == null:
		return {"name": String(scenario_name), "completed": false, "error": "Main failed to instantiate"}
	var ready_started := Time.get_ticks_usec()
	tree.root.add_child(game)
	await tree.process_frame
	await tree.physics_frame
	await tree.process_frame
	var ready_ms := float(Time.get_ticks_usec() - ready_started) / 1000.0
	var world := game.get_node_or_null("ShipyardWorld") as ShipyardWorld
	var player := game.get_node_or_null("Player") as PlayerController
	var ship := game.get_node_or_null("TorrentInterceptor") as HeroShip
	if world == null or player == null or ship == null:
		game.queue_free()
		await tree.process_frame
		return {"name": String(scenario_name), "completed": false, "error": "production actors unavailable"}
	var quality_report := world.apply_visual_quality(quality_level)
	var inputs := _stage_scenario(game, world, player, ship, scenario_name)
	var progress_tracker := _begin_scenario_progress(player, ship, scenario_name, inputs, smoke_run)
	# One declared activation tick guarantees that a short smoke actually offers
	# its input to the production physics authority before timing continues.
	_apply_scenario_input(scenario_name, 0, warmup_frames + sample_frames)
	await tree.physics_frame
	await tree.process_frame
	_update_scenario_progress(progress_tracker, player, ship, scenario_name)

	var total_frames := warmup_frames + sample_frames
	var previous_tick := Time.get_ticks_usec()
	for frame in warmup_frames:
		_apply_scenario_input(scenario_name, frame, total_frames)
		await tree.process_frame
		_update_scenario_progress(progress_tracker, player, ship, scenario_name)
		previous_tick = Time.get_ticks_usec()

	var frame_deltas: Array[float] = []
	var monitor_samples: Dictionary = {}
	for monitor_name in MONITORS:
		monitor_samples[monitor_name] = [] as Array[float]
	for sample_index in sample_frames:
		_apply_scenario_input(scenario_name, warmup_frames + sample_index, total_frames)
		await tree.process_frame
		_update_scenario_progress(progress_tracker, player, ship, scenario_name)
		var now := Time.get_ticks_usec()
		frame_deltas.append(float(now - previous_tick) / 1000.0)
		previous_tick = now
		_capture_monitor_sample(monitor_samples)

	var progress := _finish_scenario_progress(progress_tracker, player, ship, scenario_name)
	var progress_errors := validate_scenario_progress(scenario_name, progress)
	_release_inputs()
	var result := {
		"name": String(scenario_name),
		"completed": progress_errors.is_empty(),
		"error": "; ".join(progress_errors),
		"deterministic_inputs": inputs,
		"scenario_progress": progress,
		"warmup_frames": warmup_frames,
		"sample_count": frame_deltas.size(),
		"frame_delta_ms": summarize_samples(frame_deltas),
		"monitors": _summarize_monitors(monitor_samples),
		"ram": {
			"static_bytes_after_sample": OS.get_static_memory_usage(),
			"static_peak_bytes": OS.get_static_memory_peak_usage(),
		},
		"scene_counts": capture_scene_counts(game),
		"startup": {
			"main_instantiate_ms": instantiated_ms,
			"main_first_ready_frames_ms": ready_ms,
		},
		"quality_report": quality_report,
	}
	if is_instance_valid(ship):
		ship.set_piloted(false)
	game.queue_free()
	await tree.process_frame
	await tree.process_frame
	return result


static func _begin_scenario_progress(
		player: PlayerController,
		ship: HeroShip,
		scenario_name: StringName,
		inputs: Dictionary,
		smoke_run: bool
	) -> Dictionary:
	var actor := player as Node3D if scenario_name == &"station_embodied_route" else ship as Node3D
	var start_position := actor.global_position
	var target_array := inputs.get("route_target", []) as Array
	var target := Vector3.ZERO
	if target_array.size() == 3:
		target = Vector3(float(target_array[0]), float(target_array[1]), float(target_array[2]))
	var start_hull := float(ship.get_telemetry().get("hull", -1.0))
	return {
		"smoke_run": smoke_run,
		"start_transform_value": actor.global_transform,
		"previous_position": start_position,
		"path_distance_m": 0.0,
		"horizontal_path_distance_m": 0.0,
		"maximum_displacement_m": 0.0,
		"maximum_horizontal_displacement_m": 0.0,
		"route_target": target,
		"start_target_distance_m": start_position.distance_to(target),
		"minimum_target_distance_m": start_position.distance_to(target),
		"engine_online_observed": false,
		"accepted_propulsion_observed": false,
		"start_hull": start_hull,
		"minimum_hull": start_hull,
		"healthy_throughout": start_hull > 0.0 and not ship.is_destroyed(),
	}


static func _update_scenario_progress(
		tracker: Dictionary,
		player: PlayerController,
		ship: HeroShip,
		scenario_name: StringName
	) -> void:
	var actor := player as Node3D if scenario_name == &"station_embodied_route" else ship as Node3D
	var position := actor.global_position
	var previous := tracker.previous_position as Vector3
	var start := (tracker.start_transform_value as Transform3D).origin
	tracker.path_distance_m = float(tracker.path_distance_m) + position.distance_to(previous)
	tracker.horizontal_path_distance_m = float(tracker.horizontal_path_distance_m) + Vector2(
		position.x - previous.x, position.z - previous.z
	).length()
	tracker.maximum_displacement_m = maxf(
		float(tracker.maximum_displacement_m), position.distance_to(start)
	)
	tracker.maximum_horizontal_displacement_m = maxf(
		float(tracker.maximum_horizontal_displacement_m),
		Vector2(position.x - start.x, position.z - start.z).length()
	)
	tracker.previous_position = position
	if scenario_name != &"nearby_sector_ship_flight_route":
		return
	var telemetry := ship.get_telemetry()
	var engine_online := StringName(telemetry.get("engine_state", &"")) == HeroShip.ENGINE_ONLINE
	var command := ship.get_last_ship_command()
	tracker.engine_online_observed = bool(tracker.engine_online_observed) or engine_online
	tracker.accepted_propulsion_observed = (
		bool(tracker.accepted_propulsion_observed)
		or (engine_online and command != null and command.throttle > 0.0)
	)
	var hull := float(telemetry.get("hull", -1.0))
	tracker.minimum_hull = minf(float(tracker.minimum_hull), hull)
	tracker.healthy_throughout = (
		bool(tracker.healthy_throughout)
		and hull > 0.0
		and not ship.is_destroyed()
	)
	var target := tracker.route_target as Vector3
	tracker.minimum_target_distance_m = minf(
		float(tracker.minimum_target_distance_m), position.distance_to(target)
	)


static func _finish_scenario_progress(
		tracker: Dictionary,
		player: PlayerController,
		ship: HeroShip,
		scenario_name: StringName
	) -> Dictionary:
	var actor := player as Node3D if scenario_name == &"station_embodied_route" else ship as Node3D
	var start_transform := tracker.start_transform_value as Transform3D
	var end_transform := actor.global_transform
	var result := {
		"policy": "bounded_progress_smoke" if bool(tracker.smoke_run) else "full_route",
		"endpoint_required": not bool(tracker.smoke_run) and scenario_name == &"nearby_sector_ship_flight_route",
		"start_transform": _transform_record(start_transform),
		"end_transform": _transform_record(end_transform),
		"path_distance_m": float(tracker.path_distance_m),
		"horizontal_path_distance_m": float(tracker.horizontal_path_distance_m),
		"displacement_m": end_transform.origin.distance_to(start_transform.origin),
		"horizontal_displacement_m": Vector2(
			end_transform.origin.x - start_transform.origin.x,
			end_transform.origin.z - start_transform.origin.z
		).length(),
		"maximum_displacement_m": float(tracker.maximum_displacement_m),
		"maximum_horizontal_displacement_m": float(tracker.maximum_horizontal_displacement_m),
	}
	if scenario_name == &"station_embodied_route":
		result["actor_type"] = "PlayerController"
		result["control_enabled_end"] = player.is_control_enabled()
		return result
	var target := tracker.route_target as Vector3
	var end_hull := float(ship.get_telemetry().get("hull", -1.0))
	result.merge({
		"actor_type": "HeroShip",
		"route_target": [target.x, target.y, target.z],
		"start_target_distance_m": float(tracker.start_target_distance_m),
		"end_target_distance_m": end_transform.origin.distance_to(target),
		"minimum_target_distance_m": float(tracker.minimum_target_distance_m),
		"maximum_target_progress_m": (
			float(tracker.start_target_distance_m) - float(tracker.minimum_target_distance_m)
		),
		"engine_online_observed": bool(tracker.engine_online_observed),
		"accepted_propulsion_observed": bool(tracker.accepted_propulsion_observed),
		"start_hull": float(tracker.start_hull),
		"end_hull": end_hull,
		"minimum_hull": float(tracker.minimum_hull),
		"healthy_throughout": bool(tracker.healthy_throughout) and end_hull > 0.0 and not ship.is_destroyed(),
		"destroyed_end": ship.is_destroyed(),
	})
	return result


static func validate_scenario_progress(
		scenario_name: StringName,
		progress: Dictionary
	) -> PackedStringArray:
	var errors := PackedStringArray()
	if progress.is_empty():
		return PackedStringArray(["scenario_progress is required"])
	for field in ["start_transform", "end_transform", "path_distance_m", "maximum_displacement_m"]:
		if not progress.has(field):
			errors.append("scenario_progress.%s is required" % field)
	if not errors.is_empty():
		return errors
	if not _finite_number(progress.get("path_distance_m")) \
		or float(progress.get("path_distance_m", 0.0)) <= MINIMUM_SMOKE_MOVEMENT_METERS:
		errors.append("actor path did not advance")
	if not _finite_number(progress.get("maximum_displacement_m")) \
		or float(progress.get("maximum_displacement_m", 0.0)) <= MINIMUM_SMOKE_MOVEMENT_METERS:
		errors.append("actor transform did not move")
	if scenario_name == &"station_embodied_route":
		if str(progress.get("actor_type", "")) != "PlayerController":
			errors.append("station actor is not PlayerController")
		if not _finite_number(progress.get("horizontal_path_distance_m")) \
			or float(progress.get("horizontal_path_distance_m", 0.0)) <= MINIMUM_SMOKE_MOVEMENT_METERS:
			errors.append("PlayerController horizontal route did not advance")
		if not bool(progress.get("control_enabled_end", false)):
			errors.append("PlayerController control was not enabled")
		if str(progress.get("policy", "")) == "full_route" \
			and float(progress.get("path_distance_m", 0.0)) < MINIMUM_FULL_STATION_PATH_METERS:
			errors.append("full station route did not cover its minimum path")
		return errors
	if scenario_name != &"nearby_sector_ship_flight_route":
		errors.append("unknown scenario progress contract")
		return errors
	if not bool(progress.get("engine_online_observed", false)):
		errors.append("flight never observed ONLINE propulsion")
	if not bool(progress.get("accepted_propulsion_observed", false)):
		errors.append("flight never observed accepted propulsion demand")
	if not _finite_number(progress.get("maximum_target_progress_m")) \
		or float(progress.get("maximum_target_progress_m", 0.0)) <= MINIMUM_SMOKE_MOVEMENT_METERS:
		errors.append("ship made no progress toward the route target")
	if not _finite_number(progress.get("minimum_hull")) \
		or not bool(progress.get("healthy_throughout", false)) \
		or bool(progress.get("destroyed_end", true)) \
		or float(progress.get("minimum_hull", 0.0)) <= 0.0:
		errors.append("ship did not remain healthy")
	if bool(progress.get("endpoint_required", false)) \
		and (
			not _finite_number(progress.get("minimum_target_distance_m"))
			or float(progress.get("minimum_target_distance_m", INF)) > FLIGHT_ENDPOINT_RADIUS_METERS
		):
		errors.append("full flight never entered the route endpoint radius")
	return errors


static func _stage_scenario(
		game: GameFlow,
		world: ShipyardWorld,
		player: PlayerController,
		ship: HeroShip,
		scenario_name: StringName
	) -> Dictionary:
	if scenario_name == &"station_embodied_route":
		game.start_shift()
		player.teleport_to(world.get_player_spawn())
		player.set_control_enabled(true)
		return {
			"actor": "production PlayerController",
			"global_rng_seed": _scenario_seed(scenario_name),
			"start_transform": _transform_record(world.get_player_spawn()),
			"sequence": "forward, forward+right, forward, forward+left in four equal frame segments",
		}
	var cluster := world.get_nearby_sector_cluster()
	var route_start := Vector3(8.0, 12.0, -180.0)
	var route_target := Vector3(8.0, 12.0, -900.0)
	if cluster != null:
		route_start = cluster.get_approach_lane_point(170.0)
		route_target = cluster.get_dock_gate_center()
	var direction := (route_target - route_start).normalized()
	if direction.is_zero_approx():
		direction = Vector3.FORWARD
	ship.global_transform = Transform3D(Basis.looking_at(direction, Vector3.UP), route_start)
	ship.velocity = Vector3.ZERO
	ship.set_piloted(true)
	return {
		"actor": "production TorrentInterceptor and LocalShipInputSource",
		"global_rng_seed": _scenario_seed(scenario_name),
		"start_transform": _transform_record(ship.global_transform),
		"route_target": [route_target.x, route_target.y, route_target.z],
		"sequence": "forward thrust throughout; boost during middle half",
	}


static func _apply_scenario_input(scenario_name: StringName, frame: int, total_frames: int) -> void:
	_release_inputs()
	Input.action_press(&"move_forward")
	if scenario_name == &"station_embodied_route":
		var quarter := maxi(total_frames / 4, 1)
		if frame >= quarter and frame < quarter * 2:
			Input.action_press(&"move_right")
		elif frame >= quarter * 3:
			Input.action_press(&"move_left")
	elif frame >= total_frames / 4 and frame < total_frames * 3 / 4:
		Input.action_press(&"sprint_boost")


static func _release_inputs() -> void:
	for action in [
		&"move_forward", &"move_back", &"move_left", &"move_right",
		&"pitch_up", &"pitch_down", &"roll_left", &"roll_right",
		&"sprint_boost", &"brake", &"hover", &"fire", &"barrel_roll",
		&"landing_assist", &"interact",
	]:
		Input.action_release(action)


static func _scenario_seed(scenario_name: StringName) -> int:
	return 9001 if scenario_name == &"station_embodied_route" else 9002


static func percentile(samples: Array[float], fraction: float) -> float:
	if samples.is_empty():
		return -1.0
	var ordered := samples.duplicate()
	ordered.sort()
	var rank := ceili(clampf(fraction, 0.0, 1.0) * float(ordered.size()))
	return float(ordered[clampi(rank - 1, 0, ordered.size() - 1)])


static func summarize_samples(samples: Array[float]) -> Dictionary:
	return {
		"count": samples.size(),
		"p50": percentile(samples, 0.50),
		"p95": percentile(samples, 0.95),
		"p99": percentile(samples, 0.99),
		"max": percentile(samples, 1.0),
	}


static func _capture_monitor_sample(samples: Dictionary) -> void:
	for monitor_name in MONITORS:
		var value := float(Performance.get_monitor(int(MONITORS[monitor_name])))
		if String(monitor_name).ends_with("_ms"):
			value *= 1000.0
		(samples[monitor_name] as Array[float]).append(value)


static func _summarize_monitors(samples: Dictionary) -> Dictionary:
	var result := {}
	var names := samples.keys()
	names.sort()
	for monitor_name in names:
		result[monitor_name] = {
			"available": true,
			"summary": summarize_samples(samples[monitor_name] as Array[float]),
		}
	return result


static func capture_scene_counts(root_node: Node) -> Dictionary:
	var counts := {
		"nodes": 0,
		"mesh_instances": 0,
		"multimesh_nodes": 0,
		"multimesh_visible_copies": 0,
		"lights": 0,
		"particle_systems": 0,
	}
	var pending: Array[Node] = [root_node]
	while not pending.is_empty():
		var node := pending.pop_back() as Node
		counts.nodes = int(counts.nodes) + 1
		if node is MultiMeshInstance3D:
			counts.multimesh_nodes = int(counts.multimesh_nodes) + 1
			var multimesh := (node as MultiMeshInstance3D).multimesh
			if multimesh != null:
				var visible := multimesh.visible_instance_count
				counts.multimesh_visible_copies = int(counts.multimesh_visible_copies) + (
					multimesh.instance_count if visible < 0 else visible
				)
		elif node is MeshInstance3D:
			counts.mesh_instances = int(counts.mesh_instances) + 1
		if node is Light3D:
			counts.lights = int(counts.lights) + 1
		if node is GPUParticles3D or node is CPUParticles3D:
			counts.particle_systems = int(counts.particle_systems) + 1
		for child in node.get_children():
			pending.append(child as Node)
	return counts


static func capture_source_state() -> Dictionary:
	var revision_output: Array = []
	var revision_exit := OS.execute("git", ["rev-parse", "HEAD"], revision_output, true)
	var status_output: Array = []
	var status_exit := OS.execute("git", ["status", "--porcelain=v1"], status_output, true)
	return {
		"git_sha": str(revision_output[0]).strip_edges() if revision_exit == 0 and not revision_output.is_empty() else "unknown",
		"git_dirty": status_exit != 0 or (not status_output.is_empty() and not str(status_output[0]).strip_edges().is_empty()),
	}


static func capture_environment(resolution: Vector2i, quality_level: int) -> Dictionary:
	var driver_info: Variant = PackedStringArray()
	if RenderingServer.has_method("get_video_adapter_driver_info"):
		driver_info = RenderingServer.call("get_video_adapter_driver_info")
	var api_version := "unavailable"
	if RenderingServer.has_method("get_video_adapter_api_version"):
		api_version = str(RenderingServer.call("get_video_adapter_api_version"))
	return {
		"godot_version": str(Engine.get_version_info().get("string", "unknown")),
		"os": {
			"name": OS.get_name(),
			"version": OS.get_version(),
			"distribution": OS.get_distribution_name(),
		},
		"cpu": {
			"name": OS.get_processor_name(),
			"logical_processors": OS.get_processor_count(),
		},
		"gpu": {
			"adapter": RenderingServer.get_video_adapter_name(),
			"vendor": RenderingServer.get_video_adapter_vendor(),
			"driver": driver_info,
			"api_version": api_version,
		},
		"render": {
			"method": RenderingServer.get_current_rendering_method(),
			"project_method": str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "unknown")),
			"display_server": DisplayServer.get_name(),
			"resolution": [resolution.x, resolution.y],
			"vsync_mode": DisplayServer.window_get_vsync_mode(),
		},
		"profile": {
			"quality_level": quality_level,
			"quality_name": ["Low", "Medium", "High"][clampi(quality_level, 0, 2)],
		},
	}


static func classify_representativeness(observed: Dictionary, target: Dictionary) -> Dictionary:
	var reasons := PackedStringArray()
	var adapter := str((observed.get("gpu", {}) as Dictionary).get("adapter", "")).to_lower()
	var display := str((observed.get("render", {}) as Dictionary).get("display_server", "")).to_lower()
	for software_name in ["llvmpipe", "softpipe", "software", "swiftshader"]:
		if adapter.contains(software_name):
			reasons.append("software renderer detected: %s" % adapter)
	if display == "headless":
		reasons.append("headless display server is not representative")
	if target.is_empty():
		reasons.append("no separately declared target profile supplied")
	else:
		for key_path in [
			"os.name", "cpu.name", "gpu.adapter", "gpu.driver",
			"render.method", "render.display_server", "render.resolution",
			"profile.quality_name",
		]:
			var expected: Variant = _dictionary_path(target, key_path)
			var actual: Variant = _dictionary_path(observed, key_path)
			if expected == null:
				reasons.append("target profile missing required field %s" % key_path)
			elif JSON.stringify(expected) != JSON.stringify(actual):
				reasons.append("target mismatch %s: expected %s, observed %s" % [key_path, str(expected), str(actual)])
	return {
		"target_declared": not target.is_empty(),
		"hardware_match": reasons.is_empty(),
		"representative_pass": false,
		"performance_budget_pass": null,
		"reasons": reasons,
	}


static func build_report(
		source: Dictionary,
		environment: Dictionary,
		target: Dictionary,
		representativeness: Dictionary,
		scenarios: Array[Dictionary],
		configuration: Dictionary
	) -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"report_kind": REPORT_KIND,
		"generated_utc": Time.get_datetime_string_from_system(true, true),
		"source": source.duplicate(true),
		"environment": environment.duplicate(true),
		"target_profile": target.duplicate(true),
		"configuration": configuration.duplicate(true),
		"representativeness": representativeness.duplicate(true),
		"unavailable_metrics": {
			"gpu_frame_time_ms": {
				"available": false,
				"value": null,
				"reason": "no reliable per-frame GPU timer is exposed by this harness",
			},
			"vram_bytes": {
				"available": false,
				"value": null,
				"reason": "renderer memory counters are not portable enough for an acceptance claim",
			},
		},
		"scenarios": scenarios.duplicate(true),
	}


static func validate_report(report: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	if int(report.get("schema_version", -1)) != SCHEMA_VERSION:
		errors.append("schema_version must be %d" % SCHEMA_VERSION)
	if str(report.get("report_kind", "")) != REPORT_KIND:
		errors.append("report_kind is invalid")
	var source := report.get("source", {}) as Dictionary
	for field in ["git_sha", "git_dirty"]:
		if not source.has(field):
			errors.append("source.%s is required" % field)
	var environment := report.get("environment", {}) as Dictionary
	for path in [
		"godot_version", "os.name", "cpu.name", "gpu.adapter", "gpu.driver",
		"render.method", "render.display_server", "render.resolution",
		"profile.quality_name",
	]:
		if _dictionary_path(environment, path) == null:
			errors.append("environment.%s is required" % path)
	var unavailable := report.get("unavailable_metrics", {}) as Dictionary
	for metric in ["gpu_frame_time_ms", "vram_bytes"]:
		var entry := unavailable.get(metric, {}) as Dictionary
		if entry.is_empty() or bool(entry.get("available", true)) or entry.get("value", 0) != null:
			errors.append("%s must be explicitly unavailable with a null value" % metric)
	var configuration := report.get("configuration", {}) as Dictionary
	if not configuration.has("smoke_run") or not configuration.smoke_run is bool:
		errors.append("configuration.smoke_run boolean is required")
	var smoke_run := bool(configuration.get("smoke_run", false))
	var scenarios := report.get("scenarios", []) as Array
	if scenarios.size() != SCENARIO_NAMES.size():
		errors.append("exactly two named scenarios are required")
	for scenario_variant in scenarios:
		var scenario := scenario_variant as Dictionary
		var scenario_name := StringName(scenario.get("name", ""))
		if not SCENARIO_NAMES.has(scenario_name):
			errors.append("unknown scenario name")
		if not bool(scenario.get("completed", false)):
			errors.append("scenario %s did not complete: %s" % [scenario_name, str(scenario.get("error", ""))])
		for progress_error in validate_scenario_progress(
			scenario_name, scenario.get("scenario_progress", {}) as Dictionary
		):
			errors.append("scenario %s: %s" % [scenario_name, progress_error])
		var progress := scenario.get("scenario_progress", {}) as Dictionary
		var expected_policy := "bounded_progress_smoke" if smoke_run else "full_route"
		if str(progress.get("policy", "")) != expected_policy:
			errors.append("scenario %s progress policy does not match configuration" % scenario_name)
		var endpoint_expected := not smoke_run and scenario_name == &"nearby_sector_ship_flight_route"
		if bool(progress.get("endpoint_required", false)) != endpoint_expected:
			errors.append("scenario %s endpoint requirement does not match configuration" % scenario_name)
		var frame_delta := scenario.get("frame_delta_ms", {}) as Dictionary
		if not _valid_summary(frame_delta):
			errors.append("scenario frame_delta_ms summary is invalid")
		if int(scenario.get("warmup_frames", 0)) < 1 or int(scenario.get("sample_count", 0)) < 2:
			errors.append("scenario warm-up/sample counts are invalid")
	var representative := report.get("representativeness", {}) as Dictionary
	if bool(representative.get("representative_pass", false)) and not bool(representative.get("hardware_match", false)):
		errors.append("representative_pass requires an exact target hardware match")
	if bool(representative.get("representative_pass", false)) and bool(source.get("git_dirty", true)):
		errors.append("representative_pass requires a clean source tree")
	if bool(representative.get("representative_pass", false)) and smoke_run:
		errors.append("representative_pass is forbidden for smoke protocol")
	return errors


static func _valid_summary(summary: Dictionary) -> bool:
	if int(summary.get("count", 0)) < 2:
		return false
	var p50 := float(summary.get("p50", -1.0))
	var p95 := float(summary.get("p95", -1.0))
	var p99 := float(summary.get("p99", -1.0))
	var maximum := float(summary.get("max", -1.0))
	return p50 >= 0.0 and p50 <= p95 and p95 <= p99 and p99 <= maximum


static func _finite_number(value: Variant) -> bool:
	if not value is int and not value is float:
		return false
	var number := float(value)
	return not is_nan(number) and not is_inf(number)


static func load_target_profile(path: String) -> Dictionary:
	if path.is_empty():
		return {}
	var absolute := ProjectSettings.globalize_path(path)
	var file := FileAccess.open(absolute, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed as Dictionary if parsed is Dictionary else {}


static func _dictionary_path(dictionary: Dictionary, path: String) -> Variant:
	var cursor: Variant = dictionary
	for component in path.split("."):
		if not (cursor is Dictionary) or not (cursor as Dictionary).has(component):
			return null
		cursor = (cursor as Dictionary)[component]
	return cursor


static func _transform_record(transform: Transform3D) -> Dictionary:
	return {
		"origin": [transform.origin.x, transform.origin.y, transform.origin.z],
		"basis_x": [transform.basis.x.x, transform.basis.x.y, transform.basis.x.z],
		"basis_y": [transform.basis.y.x, transform.basis.y.y, transform.basis.y.z],
		"basis_z": [transform.basis.z.x, transform.basis.z.y, transform.basis.z.z],
	}


func _environment_int(name: String, fallback: int, minimum: int) -> int:
	var value := OS.get_environment(name)
	return maxi(value.to_int(), minimum) if value.is_valid_int() else fallback


func _environment_bool(name: String, fallback: bool) -> bool:
	var value := OS.get_environment(name).strip_edges().to_lower()
	if value in ["1", "true", "yes", "on"]:
		return true
	if value in ["0", "false", "no", "off"]:
		return false
	return fallback


func _environment_resolution(name: String, fallback: Vector2i) -> Vector2i:
	var value := OS.get_environment(name).to_lower().split("x")
	if value.size() != 2 or not value[0].is_valid_int() or not value[1].is_valid_int():
		return fallback
	return Vector2i(maxi(value[0].to_int(), 1), maxi(value[1].to_int(), 1))
