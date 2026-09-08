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
const MINIMUM_WARMUP_SECONDS := 60.0
const MINIMUM_SAMPLE_SECONDS := 600.0
const SMOKE_WARMUP_FRAMES := 2
const SMOKE_SAMPLE_FRAMES := 4
const SCENARIO_NAMES := [&"station_embodied_route", &"nearby_sector_ship_flight_route"]
const MINIMUM_SMOKE_MOVEMENT_METERS := 0.001
const MINIMUM_FULL_STATION_PATH_METERS := 1.0
const FLIGHT_ENDPOINT_RADIUS_METERS := 20.0
const STREAMING_READY_FRAME_BUDGET := 24
# Software-rendered startup may advance the production fade slowly. This wait
# remains outside measurement and keeps the independent abort guard active.
const BEGIN_SHIFT_READY_TIMEOUT_MS := 60_000

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


class BenchmarkInputGuard extends Node:
	var aborted := false
	var reason := ""

	func _init() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _input(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed and not event.echo \
				and (event.physical_keycode == KEY_ESCAPE or event.keycode == KEY_ESCAPE):
			request_abort("Escape pressed")
			get_viewport().set_input_as_handled()

	func request_abort(abort_reason: String) -> void:
		if aborted:
			return
		aborted = true
		reason = abort_reason
		release_inputs()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().paused = false

	func on_close_requested() -> void:
		request_abort("window close requested")

	func on_focus_exited() -> void:
		request_abort("benchmark window lost focus")


	static func release_inputs() -> void:
		for action in [
			&"move_forward", &"move_back", &"move_left", &"move_right",
			&"pitch_up", &"pitch_down", &"roll_left", &"roll_right",
			&"sprint_boost", &"brake", &"hover", &"fire", &"barrel_roll",
			&"landing_assist", &"interact",
		]:
			Input.action_release(action)

## Refresh before the ship's physics authority, including physics catch-up ticks
## between rendered frames. Only normal local Input actions drive the craft.
class BenchmarkFlightPilot extends Node:
	var ship: HeroShip
	var guard: BenchmarkInputGuard
	var target := Vector3.ZERO
	var start := Vector3.ZERO
	var returning := false
	var direction := Vector3.FORWARD
	var route_frame := 0
	var total_frames := 1

	func _physics_process(_delta: float) -> void:
		apply_input()

	func apply_input() -> void:
		BenchmarkInputGuard.release_inputs()
		if guard.aborted or not is_instance_valid(ship) or ship.is_destroyed():
			return
		var destination := start if returning else target
		var leg_direction := -direction if returning else direction
		var remaining := (destination - ship.global_position).dot(leg_direction)
		var speed := ship.velocity.dot(leg_direction)
		if ship.velocity.length() < 1.0 and remaining <= FLIGHT_ENDPOINT_RADIUS_METERS:
			returning = not returning
			Input.action_press(&"brake")
			return
		# Allow for the production throttle response after releasing thrust, plus
		# a small stand-off inside the endpoint aperture's accepted radius.
		var stopping_distance := speed * speed / (2.0 * maxf(ship.brake_acceleration, 1.0)) + absf(speed) * 0.3 + 3.0
		if speed < -0.5 or remaining <= stopping_distance:
			Input.action_press(&"brake")
			return
		Input.action_press(&"move_back" if returning else &"move_forward")
		if not returning and route_frame >= total_frames / 4 and route_frame < total_frames * 3 / 4:
			Input.action_press(&"sprint_boost")


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
	if bool(report.get("aborted", false)):
		printerr("PERFORMANCE_BENCHMARK_ABORTED: ", report.get("reason", "operator abort"))
		quit(130)
		return
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
	# Keep physical Escape available through startup and deterministic staging,
	# independently of gameplay pause/input.
	var input_guard := BenchmarkInputGuard.new()
	tree.root.add_child(input_guard)
	var original_paused := tree.paused
	var original_auto_quit := tree.auto_accept_quit
	tree.auto_accept_quit = false
	tree.root.window_input.connect(input_guard._input)
	tree.root.close_requested.connect(input_guard.on_close_requested)
	tree.root.focus_exited.connect(input_guard.on_focus_exited)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var original_root_size := tree.root.size
	var original_content_mode := tree.root.content_scale_mode
	var original_content_size := tree.root.content_scale_size
	var original_content_factor := tree.root.content_scale_factor
	var original_window_mode := tree.root.mode
	var requested_resolution := Vector2i(maxi(resolution.x, 1), maxi(resolution.y, 1))
	tree.root.size = requested_resolution
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(requested_resolution)
	var durations := required_phase_seconds(target_profile, smoke_run)
	var scenarios: Array[Dictionary] = []
	for scenario_name: StringName in SCENARIO_NAMES:
		scenarios.append(await _run_scenario(
			tree,
			scenario_name,
			maxi(warmup_frames, 1),
			maxi(sample_frames, 2),
			quality_level,
			smoke_run,
			durations,
			requested_resolution,
			input_guard
		))
		if input_guard.aborted:
			break
	_release_inputs()
	# Capture the live viewport before restoring the caller's display.
	var observed := capture_environment(Vector2i(tree.root.get_visible_rect().size), quality_level)
	tree.root.content_scale_mode = original_content_mode
	tree.root.content_scale_size = original_content_size
	tree.root.content_scale_factor = original_content_factor
	tree.root.mode = original_window_mode
	tree.root.size = original_root_size
	var abort_reason := input_guard.reason
	var aborted := input_guard.aborted
	input_guard.free()
	tree.auto_accept_quit = original_auto_quit
	tree.paused = original_paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if aborted:
		return {"aborted": true, "reason": abort_reason}
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
			"minimum_warmup_seconds": durations.warmup,
			"minimum_sample_seconds": durations.sample,
		}
	)


static func _run_scenario(
		tree: SceneTree,
		scenario_name: StringName,
		warmup_frames: int,
		sample_frames: int,
		quality_level: int,
		smoke_run: bool,
		durations: Dictionary,
		requested_resolution: Vector2i,
		input_guard: BenchmarkInputGuard
	) -> Dictionary:
	_release_inputs()
	seed(_scenario_seed(scenario_name))
	var instantiate_started := Time.get_ticks_usec()
	var game := MAIN_SCENE.instantiate() as GameFlow
	var instantiated_ms := float(Time.get_ticks_usec() - instantiate_started) / 1000.0
	if game == null:
		return {"name": String(scenario_name), "completed": false, "error": "Main failed to instantiate"}
	var startup_world := game.get_node_or_null("ShipyardWorld") as ShipyardWorld
	if startup_world != null:
		startup_world.visual_quality_level = quality_level
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
	if input_guard.aborted:
		game.queue_free()
		await tree.process_frame
		return {"completed": false}
	var quality_report := world.apply_visual_quality(quality_level)
	# Main startup applies persisted display settings; benchmark sizing must win
	# after that startup, with one render pixel per requested viewport pixel.
	tree.root.mode = Window.MODE_WINDOWED
	tree.root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	tree.root.content_scale_size = Vector2i.ZERO
	tree.root.content_scale_factor = 1.0
	tree.root.size = requested_resolution
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(requested_resolution)
	await tree.process_frame
	await tree.process_frame
	if input_guard.aborted:
		game.queue_free()
		await tree.process_frame
		return {"completed": false}
	var inputs := await _stage_scenario(tree, game, world, player, ship, scenario_name, input_guard)
	if input_guard.aborted or not bool(inputs.get("staging_valid", false)):
		_release_inputs()
		if is_instance_valid(ship):
			ship.set_piloted(false)
		game.queue_free()
		await tree.process_frame
		await tree.process_frame
		return {
			"name": String(scenario_name),
			"completed": false,
			"error": str(inputs.get("staging_error", "scenario staging failed")),
			"deterministic_inputs": inputs,
		}
	var resolution_before := await capture_resolution(tree, requested_resolution, input_guard)
	var progress_tracker := _begin_scenario_progress(player, ship, scenario_name, inputs, smoke_run)
	var flight_pilot: BenchmarkFlightPilot
	if scenario_name == &"nearby_sector_ship_flight_route":
		flight_pilot = BenchmarkFlightPilot.new()
		flight_pilot.ship = ship
		flight_pilot.guard = input_guard
		flight_pilot.target = progress_tracker.route_target as Vector3
		flight_pilot.start = ship.global_position
		flight_pilot.direction = (flight_pilot.target - ship.global_position).normalized()
		flight_pilot.total_frames = warmup_frames + sample_frames
		flight_pilot.process_physics_priority = ship.process_physics_priority - 1
		game.add_child(flight_pilot)
	# One declared activation tick guarantees that a short smoke actually offers
	# its input to the production physics authority before timing continues.
	if not input_guard.aborted:
		_apply_scenario_input(scenario_name, 0, warmup_frames + sample_frames, flight_pilot)
	await tree.physics_frame
	await tree.process_frame
	_update_scenario_progress(progress_tracker, player, ship, scenario_name)

	var total_frames := warmup_frames + sample_frames
	var previous_tick := Time.get_ticks_usec()
	var warmup_started := Time.get_ticks_usec()
	var actual_warmup_frames := 0
	while not input_guard.aborted and phase_incomplete(actual_warmup_frames, warmup_frames,
			float(Time.get_ticks_usec() - warmup_started) / 1_000_000.0, durations.warmup):
		var route_frame := int(warmup_frames * phase_progress(actual_warmup_frames, warmup_frames,
			float(Time.get_ticks_usec() - warmup_started) / 1_000_000.0, durations.warmup))
		_apply_scenario_input(scenario_name, route_frame, total_frames, flight_pilot)
		await tree.process_frame
		_update_scenario_progress(progress_tracker, player, ship, scenario_name)
		previous_tick = Time.get_ticks_usec()
		actual_warmup_frames += 1
	var warmup_elapsed := float(Time.get_ticks_usec() - warmup_started) / 1_000_000.0

	var frame_deltas: Array[float] = []
	var monitor_samples: Dictionary = {}
	for monitor_name in MONITORS:
		monitor_samples[monitor_name] = [] as Array[float]
	var sample_path_start := float(progress_tracker.path_distance_m)
	var sample_started := Time.get_ticks_usec()
	previous_tick = sample_started
	while not input_guard.aborted and phase_incomplete(frame_deltas.size(), sample_frames,
			float(Time.get_ticks_usec() - sample_started) / 1_000_000.0, durations.sample):
		var route_frame := warmup_frames + int(sample_frames * phase_progress(frame_deltas.size(), sample_frames,
			float(Time.get_ticks_usec() - sample_started) / 1_000_000.0, durations.sample))
		_apply_scenario_input(scenario_name, route_frame, total_frames, flight_pilot)
		await tree.process_frame
		_update_scenario_progress(progress_tracker, player, ship, scenario_name)
		var now := Time.get_ticks_usec()
		frame_deltas.append(float(now - previous_tick) / 1000.0)
		previous_tick = now
		_capture_monitor_sample(monitor_samples)

	var sample_elapsed := float(Time.get_ticks_usec() - sample_started) / 1_000_000.0
	if flight_pilot != null:
		flight_pilot.set_physics_process(false)
		_release_inputs()
	if input_guard.aborted:
		_release_inputs()
		ship.set_piloted(false)
		game.queue_free()
		await tree.process_frame
		await tree.process_frame
		return {"completed": false}
	var resolution_after := await capture_resolution(tree, requested_resolution, input_guard)
	var progress := _finish_scenario_progress(progress_tracker, player, ship, scenario_name)
	if flight_pilot != null:
		progress["sample_path_distance_m"] = float(progress_tracker.path_distance_m) - sample_path_start
	var progress_errors := validate_scenario_progress(scenario_name, progress)
	_release_inputs()
	var result := {
		"resolution_before": resolution_before,
		"resolution_after": resolution_after,
		"name": String(scenario_name),
		"completed": progress_errors.is_empty(),
		"error": "; ".join(progress_errors),
		"deterministic_inputs": inputs,
		"scenario_progress": progress,
		"warmup_frames": actual_warmup_frames,
		"warmup_elapsed_seconds": warmup_elapsed,
		"sample_elapsed_seconds": sample_elapsed,
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
	if bool(progress.get("endpoint_required", false)) and (
		not _finite_number(progress.get("sample_path_distance_m"))
		or float(progress.get("sample_path_distance_m", 0.0)) <= MINIMUM_SMOKE_MOVEMENT_METERS
	):
		errors.append("flight did not move during sampling")
	if bool(progress.get("endpoint_required", false)) \
		and (
			not _finite_number(progress.get("minimum_target_distance_m"))
			or float(progress.get("minimum_target_distance_m", INF)) > FLIGHT_ENDPOINT_RADIUS_METERS
		):
		errors.append("full flight never entered the route endpoint radius")
	return errors


static func _stage_scenario(
		tree: SceneTree,
		game: GameFlow,
		world: ShipyardWorld,
		player: PlayerController,
		ship: HeroShip,
		scenario_name: StringName,
		input_guard: BenchmarkInputGuard
	) -> Dictionary:
	# Use the production Begin Shift transition: calling GameFlow directly leaves
	# the opaque intro over the world and never reveals the gameplay HUD.
	var hud := game.get_node_or_null("HUD") as GameHUD
	if hud == null:
		return {"staging_valid": false, "staging_error": "production HUD unavailable"}
	var began := [false]
	var on_begin := func() -> void: began[0] = true
	hud.start_requested.connect(on_begin, CONNECT_ONE_SHOT)
	hud._begin()
	var begin_started := Time.get_ticks_msec()
	while not began[0] and not input_guard.aborted and Time.get_ticks_msec() - begin_started < BEGIN_SHIFT_READY_TIMEOUT_MS:
		await tree.process_frame
	if hud.start_requested.is_connected(on_begin):
		hud.start_requested.disconnect(on_begin)
	if input_guard.aborted or not began[0]:
		return {"staging_valid": false, "staging_error": "benchmark aborted" if input_guard.aborted else "Begin Shift transition did not complete"}
	if scenario_name == &"station_embodied_route":
		player.teleport_to(world.get_player_spawn())
		player.set_control_enabled(true)
		return {
			"staging_valid": true,
			"actor": "production PlayerController",
			"global_rng_seed": _scenario_seed(scenario_name),
			"start_transform": _transform_record(world.get_player_spawn()),
			"sequence": "forward, forward+right, forward, forward+left in four equal frame segments",
		}
	var binding := game.get_node_or_null(
		^"CinderStreamingProductionBinding"
	) as CinderStreamingProductionBinding
	var bootstrap := game.get_node_or_null(
		^"CinderStreamingBootstrap"
	) as CinderStreamingBootstrap
	if binding == null or bootstrap == null:
		return {
			"staging_valid": false,
			"staging_error": "production Cinder streaming composition unavailable",
		}
	var bootstrap_snapshot := bootstrap.get_snapshot()
	var anchor_value: Variant = bootstrap_snapshot.get("navigation_anchor_position")
	if not anchor_value is Vector3 or not (anchor_value as Vector3).is_finite():
		return {
			"staging_valid": false,
			"staging_error": "production Cinder navigation anchor unavailable",
		}
	# The nearby-sector benchmark is a production streaming consumer. Stage its
	# already-selected production ship at the registered navigation anchor and
	# let the one production physics binding request/commit the real generation
	# before resolving geometry-owned route markers. There is deliberately no
	# unrelated coordinate fallback.
	game.active_ship = ship
	ship.velocity = Vector3.ZERO
	ship.global_position = anchor_value as Vector3
	ship.set_piloted(true)
	var cluster: NearbySectorCluster
	for frame_index in STREAMING_READY_FRAME_BUDGET:
		await tree.physics_frame
		if input_guard.aborted:
			return {"staging_valid": false, "staging_error": "benchmark aborted"}
		await tree.process_frame
		if input_guard.aborted:
			return {"staging_valid": false, "staging_error": "benchmark aborted"}
		cluster = bootstrap.get_loaded_instance() as NearbySectorCluster
		if is_instance_valid(cluster):
			break
	if not is_instance_valid(cluster) or world.get_nearby_sector_cluster() != cluster:
		return {
			"staging_valid": false,
			"staging_error": "coordinator-owned Cinder generation did not become available",
		}
	var route_start := cluster.get_approach_lane_point(170.0)
	var route_target := cluster.get_dock_gate_center()
	if not route_start.is_finite() or not route_target.is_finite() \
		or route_start.is_equal_approx(route_target):
		return {
			"staging_valid": false,
			"staging_error": "streamed Cinder route markers are invalid",
		}
	var direction := (route_target - route_start).normalized()
	if direction.is_zero_approx():
		direction = Vector3.FORWARD
	ship.global_transform = Transform3D(Basis.looking_at(direction, Vector3.UP), route_start)
	ship.velocity = Vector3.ZERO
	# Match the completed boarding ownership before offering flight input.
	player.set_control_enabled(false)
	player.set_camera_active(false)
	game._piloting = true
	game.phase = GameFlow.Phase.FREE_FLIGHT
	ship.set_piloted(true)
	ship.get_camera().current = true
	hud.set_mode("piloting")
	hud.bind_hero_component_ship(ship)
	game.audio.set_on_foot(false)
	return {
		"staging_valid": true,
		"actor": "production TorrentInterceptor and LocalShipInputSource",
		"route_source": "coordinator_owned_cinder_streaming_generation",
		"streamed_location_id": String(CinderStreamingBootstrap.LOCATION_ID),
		"streamed_generation": int(cluster.get_meta(&"world_location_generation", -1)),
		"streaming_owner": "CinderStreamingBootstrap/WorldStreamingCoordinator",
		"global_rng_seed": _scenario_seed(scenario_name),
		"start_transform": _transform_record(ship.global_transform),
		"route_target": [route_target.x, route_target.y, route_target.z],
		"sequence": "continuous forward/reverse approach-lane shuttle with velocity-based braking at both endpoints",
	}


static func capture_resolution(
		tree: SceneTree, requested: Vector2i, input_guard: BenchmarkInputGuard = null
	) -> Dictionary:
	var native_display := DisplayServer.get_name() != "headless"
	var framebuffer := Vector2i.ZERO
	if native_display:
		# A hidden/minimized window may stop drawing. Keep operator abort live
		# while waiting for the real framebuffer required by a successful report.
		var drawn := [false]
		var on_draw := func() -> void: drawn[0] = true
		RenderingServer.frame_post_draw.connect(on_draw, CONNECT_ONE_SHOT)
		while not drawn[0] and (input_guard == null or not input_guard.aborted):
			await tree.process_frame
		if RenderingServer.frame_post_draw.is_connected(on_draw):
			RenderingServer.frame_post_draw.disconnect(on_draw)
		if input_guard != null and input_guard.aborted:
			return {}
		var pixels := tree.root.get_texture().get_image()
		if pixels != null:
			framebuffer = pixels.get_size()
	var viewport := Vector2i(tree.root.get_visible_rect().size)
	var window := DisplayServer.window_get_size() if native_display else viewport
	return {
		"requested": [requested.x, requested.y],
		"viewport": [viewport.x, viewport.y],
		"window": [window.x, window.y],
		"framebuffer_available": native_display,
		"framebuffer": [framebuffer.x, framebuffer.y] if native_display else null,
		"matches_requested": viewport == requested and window == requested
			and (not native_display or framebuffer == requested),
	}


static func required_phase_seconds(target: Dictionary, smoke_run: bool) -> Dictionary:
	if smoke_run:
		return {"warmup": 0.0, "sample": 0.0}
	var budgets := target.get("budgets", {}) as Dictionary
	var result := {"warmup": MINIMUM_WARMUP_SECONDS, "sample": MINIMUM_SAMPLE_SECONDS}
	for phase: String in result:
		var value: Variant = budgets.get(phase + "_seconds", result[phase])
		if (value is int or value is float) and is_finite(float(value)):
			result[phase] = maxf(result[phase], float(value))
	return result


static func phase_incomplete(frames: int, minimum_frames: int, elapsed: float, minimum_seconds: float) -> bool:
	return frames < minimum_frames or elapsed < minimum_seconds


static func phase_progress(frames: int, minimum_frames: int, elapsed: float, minimum_seconds: float) -> float:
	var frame_progress := float(frames) / maxi(minimum_frames, 1)
	var time_progress := elapsed / minimum_seconds if minimum_seconds > 0.0 else 1.0
	return clampf(minf(frame_progress, time_progress), 0.0, 1.0)


static func _apply_scenario_input(
		scenario_name: StringName, frame: int, total_frames: int,
		flight_pilot: BenchmarkFlightPilot = null
	) -> void:
	if flight_pilot != null:
		flight_pilot.route_frame = frame
		flight_pilot.apply_input()
		return
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
	BenchmarkInputGuard.release_inputs()

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
		for observation in ["resolution_before", "resolution_after"]:
			var evidence := scenario.get(observation, {}) as Dictionary
			var expected_resolution: Variant = configuration.get("resolution", [])
			if evidence.get("requested") != expected_resolution \
					or evidence.get("viewport") != expected_resolution \
					or evidence.get("window") != expected_resolution \
					or (bool(evidence.get("framebuffer_available", false)) and evidence.get("framebuffer") != expected_resolution):
				errors.append("scenario %s %s does not match requested framebuffer" % [scenario_name, observation])
			if not smoke_run and not bool(evidence.get("framebuffer_available", false)):
				errors.append("full scenario requires observed framebuffer dimensions")
		var required := required_phase_seconds(report.get("target_profile", {}) as Dictionary, smoke_run)
		for phase: String in required:
			var elapsed := float(scenario.get(phase + "_elapsed_seconds", -1.0))
			if not is_finite(elapsed) or elapsed < float(required[phase]):
				errors.append("scenario %s %s elapsed duration is below required minimum" % [scenario_name, phase])
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
