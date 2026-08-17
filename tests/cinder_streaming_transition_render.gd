extends SceneTree

## Production-Main graphical evidence for Cinder's exact streaming thresholds.
##
## A capture-only camera remains at one immutable transform while the real
## guided ship supplies the production binding's tracked position. Each quality
## and reduced-motion combination records the same six transition states. The
## harness changes no production lighting, geometry, thresholds, or fades.
##
## Contract-only:
##   godot --headless --path . --script \
##     res://tests/cinder_streaming_transition_render.gd -- --check-only
##
## Forward+ evidence:
##   xvfb-run -a -s "-screen 0 2560x1440x24" godot --path . \
##     --display-driver x11 --rendering-driver vulkan --audio-driver Dummy \
##     --script tests/cinder_streaming_transition_render.gd

signal deferred_quality_fence_reached

const MAIN_SCENE := preload("res://scenes/main.tscn")
const LOCATION := preload("res://assets/world/locations/cinder_reach.tres")
const ROUTE := preload("res://assets/activities/cinder_reach_checkpoint_route.tres")
const Store := preload("res://scripts/persistence/user_data_store.gd")

const HARNESS_ID := "cinder-streaming-transition-render"
const CHECK_ONLY_FLAG := "--check-only"
const OUTPUT_ENV := "KETH_CINDER_TRANSITION_CAPTURE_DIR"
const DEFAULT_OUTPUT_DIR := "/tmp/cinder-streaming-transition-evidence"
const MANIFEST_FILE := "evidence_manifest.json"
const CAPTURE_RESOLUTION := Vector2i(2560, 1440)
const LOAD_RADIUS_M := 500.0
const UNLOAD_RADIUS_M := 650.0
const PRE_LOAD_DISTANCE_M := 500.1
const LOAD_DISTANCE_M := 499.9
const PRE_UNLOAD_DISTANCE_M := 649.9
const UNLOAD_DISTANCE_M := 650.1
const SETTLE_DRAWS := 60
const CAMERA_FOV := 60.0
const CAMERA_NEAR_M := 0.15
const CAMERA_FAR_M := 1800.0
const LUMINANCE_SAMPLE_STRIDE := 4
const ROI := Rect2i(640, 288, 1280, 864)
const ISOLATED_STORE_PATH := "memory://cinder-transition-render-settings.json"

const SCENARIOS := [
	{"id": "high_normal", "quality": 2, "quality_name": "high", "reduced_motion": false},
	{"id": "high_reduced", "quality": 2, "quality_name": "high", "reduced_motion": true},
	{"id": "low_normal", "quality": 0, "quality_name": "low", "reduced_motion": false},
	{"id": "low_reduced", "quality": 0, "quality_name": "low", "reduced_motion": true},
]
const STATES := [
	{"id": "pre_load", "loaded": false, "distance_m": PRE_LOAD_DISTANCE_M},
	{"id": "first_committed", "loaded": true, "distance_m": LOAD_DISTANCE_M},
	{"id": "load_settled", "loaded": true, "distance_m": LOAD_DISTANCE_M},
	{"id": "pre_unload", "loaded": true, "distance_m": PRE_UNLOAD_DISTANCE_M},
	{"id": "first_unloaded", "loaded": false, "distance_m": UNLOAD_DISTANCE_M},
	{"id": "unload_settled", "loaded": false, "distance_m": UNLOAD_DISTANCE_M},
]

var _failures := PackedStringArray()
var _frames: Array[Dictionary] = []
var _scenario_records: Array[Dictionary] = []
var _output_dir := DEFAULT_OUTPUT_DIR
var _rendered_frame_count := 0
var _camera: Camera3D
var _game: GameFlow
var _world: ShipyardWorld
var _binding: CinderStreamingProductionBinding
var _bootstrap: CinderStreamingBootstrap
var _coordinator: WorldStreamingCoordinator
var _ship: HeroShip
var _hud: GameHUD
var _environment: Environment
var _environment_instance_id := 0
var _camera_transform := Transform3D.IDENTITY
var _camera_target := Vector3.ZERO


class MemoryFilesystem extends UserDataFilesystem:
	var files: Dictionary = {}

	func file_exists(path: String) -> bool:
		return files.has(path)

	func directory_exists(_path: String) -> bool:
		return false

	func ensure_parent_directory(_path: String) -> Error:
		return OK

	func read_bytes(path: String, maximum_bytes: int) -> Dictionary:
		if not files.has(path):
			return {"error": ERR_FILE_NOT_FOUND, "bytes": PackedByteArray()}
		var bytes := (files[path] as PackedByteArray).duplicate()
		return {
			"error": OK if bytes.size() <= maximum_bytes else ERR_FILE_CORRUPT,
			"bytes": bytes if bytes.size() <= maximum_bytes else PackedByteArray(),
		}

	func write_bytes_and_flush(path: String, bytes: PackedByteArray) -> Error:
		files[path] = bytes.duplicate()
		return OK

	func remove_path(path: String) -> Error:
		if not files.has(path):
			return ERR_FILE_NOT_FOUND
		files.erase(path)
		return OK

	func rename_path(from_path: String, to_path: String) -> Error:
		if not files.has(from_path):
			return ERR_FILE_NOT_FOUND
		if files.has(to_path):
			return ERR_ALREADY_EXISTS
		files[to_path] = (files[from_path] as PackedByteArray).duplicate()
		files.erase(from_path)
		return OK


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	if CHECK_ONLY_FLAG in OS.get_cmdline_user_args():
		_validate_static_contract()
		_finish()
		return

	RenderingServer.frame_post_draw.connect(Callable(self, &"_on_frame_post_draw"))
	_configure_forward_plus_capture()
	_prepare_output_directory()
	if not _failures.is_empty():
		_finish()
		return

	var filesystem := MemoryFilesystem.new()
	var store := Store.new(ISOLATED_STORE_PATH, filesystem)
	_game = MAIN_SCENE.instantiate() as GameFlow
	_check(_game != null, "production Main instantiates as GameFlow")
	if _game == null:
		_finish()
		return
	_check(
		_game.configure_runtime_settings_persistence(
			store, "memory://cinder-transition-render-legacy.cfg"
		),
		"capture injects isolated settings persistence before startup"
	)
	if not _failures.is_empty():
		_game.free()
		_game = null
		_finish()
		return
	root.add_child(_game)
	await process_frame
	await physics_frame
	await process_frame

	_resolve_production_nodes()
	if not _failures.is_empty():
		await _cleanup()
		_finish()
		return
	_prepare_capture_scene()
	_validate_static_contract()
	if not _failures.is_empty():
		await _cleanup()
		_finish()
		return

	var previous_retirement_generation := 0
	for scenario_variant in SCENARIOS:
		var scenario := scenario_variant as Dictionary
		var scenario_record := await _capture_scenario(
			scenario, previous_retirement_generation
		)
		_scenario_records.append(scenario_record)
		previous_retirement_generation = int(
			scenario_record.get("unload_generation", previous_retirement_generation)
		)
		if not _failures.is_empty():
			break

	_validate_complete_evidence()
	if _failures.is_empty():
		_write_manifest()
	await _cleanup()
	_finish()


func _configure_forward_plus_capture() -> void:
	DisplayServer.window_set_size(CAPTURE_RESOLUTION)
	root.size = CAPTURE_RESOLUTION
	root.content_scale_size = Vector2i.ZERO
	root.msaa_3d = Viewport.MSAA_2X
	var renderer := StringName(RenderingServer.get_current_rendering_method())
	var display := DisplayServer.get_name()
	_check(renderer == &"forward_plus", "capture uses Forward+")
	_check(display == "X11", "capture uses a native X11 display")
	_check(root.size == CAPTURE_RESOLUTION, "viewport is exactly 2560x1440")


func _prepare_output_directory() -> void:
	var override := OS.get_environment(OUTPUT_ENV).strip_edges()
	_output_dir = override if not override.is_empty() else DEFAULT_OUTPUT_DIR
	var error := DirAccess.make_dir_recursive_absolute(_output_dir)
	_check(
		error == OK or error == ERR_ALREADY_EXISTS,
		"dedicated transition evidence directory is available"
	)
	if error != OK and error != ERR_ALREADY_EXISTS:
		return
	for file_name in _expected_files():
		_remove_stale_file(_output_dir.path_join(file_name))
	_remove_stale_file(_output_dir.path_join(MANIFEST_FILE))


func _remove_stale_file(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	_check(DirAccess.remove_absolute(path) == OK, "stale evidence file clears: %s" % path)


func _resolve_production_nodes() -> void:
	_world = _game.get_node_or_null(^"ShipyardWorld") as ShipyardWorld
	_binding = _game.get_node_or_null(
		^"CinderStreamingProductionBinding"
	) as CinderStreamingProductionBinding
	_bootstrap = _game.get_node_or_null(
		^"CinderStreamingBootstrap"
	) as CinderStreamingBootstrap
	_coordinator = _bootstrap.get_node_or_null(
		^"WorldStreamingCoordinator"
	) as WorldStreamingCoordinator if _bootstrap != null else null
	_ship = _game.get_guided_ship()
	_hud = _game.get_node_or_null(^"HUD") as GameHUD
	var environment_node := _world.get_node_or_null(
		^"ShipyardEnvironment"
	) as WorldEnvironment if _world != null else null
	_environment = environment_node.environment if environment_node != null else null
	_check(
		_world != null
		and _binding != null
		and _bootstrap != null
		and _coordinator != null
		and _ship != null
		and _hud != null
		and _environment != null,
		"production Main exposes the world, streaming chain, guided ship, HUD, and environment"
	)
	if _environment != null:
		_environment_instance_id = _environment.get_instance_id()
	_check(
		_binding != null
		and bool(_binding.get_snapshot().get("caller_sample_mode", false))
		and bool(_binding.get_snapshot().get("activated", false)),
		"production binding is active in caller-sampled mode"
	)
	_check(
		_bootstrap != null and _bootstrap.get_loaded_instance() == null,
		"station start has no loaded Cinder generation"
	)


func _prepare_capture_scene() -> void:
	for candidate in _game.find_children("*", "CanvasLayer", true, false):
		var layer := candidate as CanvasLayer
		layer.visible = false
		layer.process_mode = Node.PROCESS_MODE_DISABLED
	_ship.visible = false
	_ship.velocity = Vector3.ZERO
	_ship.set_process(false)
	_ship.set_physics_process(false)
	_ship.set_piloted(true)
	_game.active_ship = _ship

	_camera_target = ROUTE.get_checkpoint_position(0) + Vector3(0.0, 4.0, 0.0)
	_camera = Camera3D.new()
	_camera.name = "CinderTransitionEvidenceCamera"
	_camera.fov = CAMERA_FOV
	_camera.near = CAMERA_NEAR_M
	_camera.far = CAMERA_FAR_M
	_game.add_child(_camera)
	var station_direction := (
		Vector3.ZERO - LOCATION.get_anchor_position()
	).normalized()
	_camera.global_position = (
		_position_at_distance(LOAD_RADIUS_M)
		+ station_direction * 10.0
		+ Vector3.UP * 4.0
	)
	_camera.look_at(_camera_target, Vector3.UP)
	_camera.current = true
	_camera_transform = _camera.global_transform


func _capture_scenario(scenario: Dictionary, previous_retirement_generation: int) -> Dictionary:
	await _apply_scenario_settings(scenario)
	_ship.global_position = _position_at_distance(PRE_LOAD_DISTANCE_M)
	_ship.velocity = Vector3.ZERO
	await _renderer_draws(SETTLE_DRAWS)
	_check(_bootstrap.get_loaded_instance() == null, "%s begins unloaded" % scenario.id)
	await _capture_frame(scenario, STATES[0] as Dictionary, previous_retirement_generation, 0)

	var render_count_before_commit := _rendered_frame_count
	_ship.global_position = _position_at_distance(LOAD_DISTANCE_M)
	var loaded_event: Array = await _coordinator.location_loaded
	var load_generation := int(loaded_event[1]) if loaded_event.size() >= 2 else -1
	var cluster := loaded_event[2] as NearbySectorCluster if loaded_event.size() >= 3 else null
	var cluster_ref: WeakRef = weakref(cluster)
	var rendered_at_commit := _rendered_frame_count - render_count_before_commit
	call_deferred(&"_emit_deferred_quality_fence")
	await deferred_quality_fence_reached
	var rendered_before_quality_sync := _rendered_frame_count - render_count_before_commit
	_check(
		cluster != null
		and _bootstrap.get_loaded_instance() == cluster
		and int(_binding.get_snapshot().get("quality_synced_instance_id", 0))
			== cluster.get_instance_id()
		and cluster.get_detail_quality() == int(scenario.quality),
		"%s first committed frame is quality-synchronized" % scenario.id
	)
	_check(
		rendered_before_quality_sync == rendered_at_commit,
		"%s performs no renderer frame between commit and quality synchronization"
			% scenario.id
	)
	if cluster != null:
		cluster.set_process(false)
	await _capture_frame(
		scenario, STATES[1] as Dictionary, load_generation, rendered_before_quality_sync
	)
	await _renderer_draws(SETTLE_DRAWS - 1)
	await _capture_frame(scenario, STATES[2] as Dictionary, load_generation, 0)

	_ship.global_position = _position_at_distance(PRE_UNLOAD_DISTANCE_M)
	_ship.velocity = Vector3.ZERO
	await physics_frame
	_check(_bootstrap.get_loaded_instance() == cluster, "%s remains loaded inside hysteresis" % scenario.id)
	await _capture_frame(scenario, STATES[3] as Dictionary, load_generation, 0)

	_ship.global_position = _position_at_distance(UNLOAD_DISTANCE_M)
	var unloaded_event: Array = await _coordinator.location_unloaded
	var unload_generation := int(unloaded_event[1]) if unloaded_event.size() >= 2 else -1
	_check(
		_bootstrap.get_loaded_instance() == null
		and _game.find_children("*", "NearbySectorCluster", true, false).is_empty(),
		"%s first unloaded state is synchronously detached" % scenario.id
	)
	await _capture_frame(scenario, STATES[4] as Dictionary, unload_generation, 0)
	await _renderer_draws(SETTLE_DRAWS - 1)
	_check(cluster_ref.get_ref() == null, "%s settled unload frees the retired generation" % scenario.id)
	await _capture_frame(scenario, STATES[5] as Dictionary, unload_generation, 0)

	_check(
		load_generation == previous_retirement_generation + 1
		and unload_generation == load_generation + 1,
		"%s advances one load and one retirement generation" % scenario.id
	)
	return {
		"scenario_id": str(scenario.id),
		"quality_level": int(scenario.quality),
		"quality_name": str(scenario.quality_name),
		"reduced_motion": bool(scenario.reduced_motion),
		"load_generation": load_generation,
		"unload_generation": unload_generation,
		"one_loaded_instance": true,
		"rendered_frames_before_quality_sync": rendered_before_quality_sync,
	}


func _apply_scenario_settings(scenario: Dictionary) -> void:
	_hud.setting_change_requested.emit(&"graphics_profile", int(scenario.quality))
	_hud.setting_change_requested.emit(&"reduced_motion", bool(scenario.reduced_motion))
	await process_frame
	var settings := _game.get_runtime_settings()
	var report := _world.get_visual_quality_report()
	var profile := VisualQualityController.get_profile(int(scenario.quality))
	_check(
		settings != null
		and settings.graphics_profile == int(scenario.quality)
		and settings.reduced_motion == bool(scenario.reduced_motion)
		and _world.visual_quality_level == int(scenario.quality)
		and bool(report.get("applied", false))
		and str(report.get("quality_name", "")) == str(scenario.quality_name),
		"%s applies the exact production quality and reduced-motion settings" % scenario.id
	)
	_check(
		_environment.get_instance_id() == _environment_instance_id
		and _environment.tonemap_mode == int(profile.tonemap_mode)
		and is_equal_approx(_environment.tonemap_exposure, float(profile.tonemap_exposure))
		and _environment.fog_enabled == bool(profile.fog_enabled)
		and _environment.volumetric_fog_enabled == bool(profile.volumetric_fog_enabled)
		and root.use_taa == bool(profile.taa_enabled),
		"%s retains one environment with its exact renderer profile" % scenario.id
	)
	_check(
		is_zero_approx(_ship.maximum_chase_camera_rotation_lag_degrees)
			== bool(scenario.reduced_motion),
		"%s applies reduced motion only to the production chase lag" % scenario.id
	)


func _capture_frame(
	scenario: Dictionary,
	state: Dictionary,
	transition_generation: int,
	rendered_frames_before_quality_sync: int
	) -> void:
	_check(
		_camera.global_transform.is_equal_approx(_camera_transform),
		"%s/%s uses the immutable evidence camera" % [scenario.id, state.id]
	)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		_fail("%s/%s returned an empty viewport image" % [scenario.id, state.id])
		return
	if image.get_format() != Image.FORMAT_RGB8:
		image.convert(Image.FORMAT_RGB8)
	var file_name := _frame_file_name(scenario, state)
	var path := _output_dir.path_join(file_name)
	if image.save_png(path) != OK:
		_fail("could not write %s" % path)
		return
	var record := _frame_metadata(
		scenario,
		state,
		transition_generation,
		rendered_frames_before_quality_sync
	)
	record["file_name"] = file_name
	record["png_sha256"] = FileAccess.get_sha256(path)
	record["image_size"] = [image.get_width(), image.get_height()]
	record["image_format"] = "RGB8"
	record["whole_frame"] = _image_statistics(
		image,
		Rect2i(Vector2i.ZERO, image.get_size()),
		LUMINANCE_SAMPLE_STRIDE
	)
	record["readability_roi"] = _image_statistics(
		image, ROI, LUMINANCE_SAMPLE_STRIDE
	)
	_frames.append(record)
	print(
		"CINDER_TRANSITION_FRAME: %02d %s state=%s distance=%.1f loaded=%s generation=%d sha256=%s"
		% [
			_frames.size(),
			scenario.id,
			state.id,
			float(record.tracked_distance_m),
			str(record.loaded),
			int(record.coordinator_generation),
			str(record.png_sha256),
		]
	)


func _frame_metadata(
	scenario: Dictionary,
	state: Dictionary,
	transition_generation: int,
	rendered_frames_before_quality_sync: int
	) -> Dictionary:
	var loaded_cluster := _bootstrap.get_loaded_instance() as NearbySectorCluster
	var loaded := is_instance_valid(loaded_cluster)
	var snapshot := _bootstrap.get_snapshot()
	var coordinator := snapshot.get("coordinator", {}) as Dictionary
	var generation_by_id := coordinator.get("generation_by_id", {}) as Dictionary
	var lights := _light_counts()
	var beacon := loaded_cluster.get_node_or_null(
		^"RouteBeacons/RouteBeaconAlpha"
	) as Node3D if loaded else null
	var settings := _game.get_runtime_settings()
	return {
		"index": _frames.size() + 1,
		"scenario_id": str(scenario.id),
		"state_id": str(state.id),
		"quality_level": int(scenario.quality),
		"quality_name": str(scenario.quality_name),
		"reduced_motion": bool(scenario.reduced_motion),
		"tracked_position": _vector3_array(_ship.global_position),
		"tracked_distance_m": _ship.global_position.distance_to(
			LOCATION.get_anchor_position()
		),
		"camera_transform": _transform_dictionary(_camera.global_transform),
		"camera_target": _vector3_array(_camera_target),
		"camera_fov_degrees": _camera.fov,
		"camera_distance_to_anchor_m": _camera.global_position.distance_to(
			LOCATION.get_anchor_position()
		),
		"loaded": loaded,
		"loaded_instance_count": _game.find_children(
			"*", "NearbySectorCluster", true, false
		).size(),
		"one_loaded_instance": (
			loaded
			and int(coordinator.get("owned_instance_count", 0)) == 1
		),
		"loaded_generation": int(snapshot.get("loaded_generation", -1)),
		"transition_generation": transition_generation,
		"coordinator_generation": int(generation_by_id.get(&"cinder_reach", 0)),
		"quality_synchronized": (
			loaded
			and int(_binding.get_snapshot().get("quality_synced_instance_id", 0))
				== loaded_cluster.get_instance_id()
		),
		"cluster_quality_level": loaded_cluster.get_detail_quality() if loaded else -1,
		"runtime_settings_graphics_profile": settings.graphics_profile,
		"runtime_settings_reduced_motion": settings.reduced_motion,
		"chase_camera_rotation_lag_degrees": _ship.maximum_chase_camera_rotation_lag_degrees,
		"rendered_frames_before_quality_sync": rendered_frames_before_quality_sync,
		"environment": _environment_snapshot(),
		"lights": lights,
		"beacon_alpha_available": beacon != null,
		"beacon_alpha_screen_position": _vector2_array(
			_camera.unproject_position(beacon.global_position + Vector3(0.0, 4.0, 0.0))
			if beacon != null else Vector2(-1.0, -1.0)
		),
	}.duplicate(true)


func _environment_snapshot() -> Dictionary:
	return {
		"same_production_environment": (
			_environment.get_instance_id() == _environment_instance_id
		),
		"tonemap_mode": _environment.tonemap_mode,
		"tonemap_exposure": _environment.tonemap_exposure,
		"tonemap_white": _environment.tonemap_white,
		"tonemap_agx_white": _environment.tonemap_agx_white,
		"tonemap_agx_contrast": _environment.tonemap_agx_contrast,
		"adjustment_enabled": _environment.adjustment_enabled,
		"adjustment_brightness": _environment.adjustment_brightness,
		"adjustment_contrast": _environment.adjustment_contrast,
		"adjustment_saturation": _environment.adjustment_saturation,
		"glow_enabled": _environment.glow_enabled,
		"glow_intensity": _environment.glow_intensity,
		"fog_enabled": _environment.fog_enabled,
		"fog_mode": _environment.fog_mode,
		"fog_depth_begin": _environment.fog_depth_begin,
		"fog_depth_end": _environment.fog_depth_end,
		"fog_density": _environment.fog_density,
		"fog_aerial_perspective": _environment.fog_aerial_perspective,
		"volumetric_fog_enabled": _environment.volumetric_fog_enabled,
		"volumetric_fog_density": _environment.volumetric_fog_density,
		"volumetric_fog_length": _environment.volumetric_fog_length,
		"taa_enabled": root.use_taa,
	}.duplicate(true)


func _light_counts() -> Dictionary:
	var total := 0
	var enabled := 0
	var shadow := 0
	for candidate in _game.find_children("*", "Light3D", true, false):
		var light := candidate as Light3D
		total += 1
		if light.is_visible_in_tree() and light.light_energy > 0.0:
			enabled += 1
		if light.shadow_enabled:
			shadow += 1
	return {"total": total, "enabled": enabled, "shadow_casting": shadow}


func _image_statistics(image: Image, rect: Rect2i, stride: int) -> Dictionary:
	var bounded := rect.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	var samples := 0
	var sum := 0.0
	var sum_squared := 0.0
	var minimum := INF
	var maximum := -INF
	var near_black := 0
	for y in range(bounded.position.y, bounded.end.y, stride):
		for x in range(bounded.position.x, bounded.end.x, stride):
			samples += 1
			var color := image.get_pixel(x, y)
			var luminance := color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
			sum += luminance
			sum_squared += luminance * luminance
			minimum = minf(minimum, luminance)
			maximum = maxf(maximum, luminance)
			if luminance < 0.02:
				near_black += 1
	var mean := sum / float(samples) if samples > 0 else 0.0
	var variance := maxf(sum_squared / float(samples) - mean * mean, 0.0) \
		if samples > 0 else 0.0
	return {
		"rect": [bounded.position.x, bounded.position.y, bounded.size.x, bounded.size.y],
		"sample_stride": stride,
		"sample_count": samples,
		"mean_luminance": mean,
		"luminance_standard_deviation": sqrt(variance),
		"minimum_luminance": minimum if samples > 0 else 0.0,
		"maximum_luminance": maximum if samples > 0 else 0.0,
		"near_black_fraction": float(near_black) / float(samples) if samples > 0 else 0.0,
	}


func _validate_static_contract() -> void:
	var scenario_ids := PackedStringArray()
	var combinations := {}
	for scenario_variant in SCENARIOS:
		var scenario := scenario_variant as Dictionary
		scenario_ids.append(str(scenario.id))
		combinations["%d:%s" % [int(scenario.quality), str(scenario.reduced_motion)]] = true
	var state_ids := PackedStringArray()
	for state_variant in STATES:
		state_ids.append(str((state_variant as Dictionary).id))
	var files := _expected_files()
	var unique_files := {}
	for file_name in files:
		unique_files[file_name] = true
	_check(
		SCENARIOS.size() == 4
		and scenario_ids == PackedStringArray([
			"high_normal", "high_reduced", "low_normal", "low_reduced"
		])
		and combinations.size() == 4,
		"contract freezes HIGH/LOW by normal/reduced-motion combinations"
	)
	_check(
		STATES.size() == 6
		and state_ids == PackedStringArray([
			"pre_load", "first_committed", "load_settled",
			"pre_unload", "first_unloaded", "unload_settled"
		]),
		"contract freezes the six ordered transition states"
	)
	_check(
		files.size() == 24 and unique_files.size() == 24,
		"contract freezes exactly 24 unique PNG names"
	)
	_check(
		is_equal_approx(
			_position_at_distance(PRE_LOAD_DISTANCE_M).distance_to(
				LOCATION.get_anchor_position()
			), PRE_LOAD_DISTANCE_M
		)
		and is_equal_approx(
			_position_at_distance(LOAD_DISTANCE_M).distance_to(
				LOCATION.get_anchor_position()
			), LOAD_DISTANCE_M
		)
		and is_equal_approx(
			_position_at_distance(PRE_UNLOAD_DISTANCE_M).distance_to(
				LOCATION.get_anchor_position()
			), PRE_UNLOAD_DISTANCE_M
		)
		and is_equal_approx(
			_position_at_distance(UNLOAD_DISTANCE_M).distance_to(
				LOCATION.get_anchor_position()
			), UNLOAD_DISTANCE_M
		),
		"contract positions straddle the exact 500m/650m thresholds"
	)


func _validate_complete_evidence() -> void:
	var expected_files := _expected_files()
	var actual_files := PackedStringArray()
	var directory := DirAccess.open(_output_dir)
	if directory != null:
		for file_name in directory.get_files():
			if file_name.ends_with(".png"):
				actual_files.append(file_name)
	actual_files.sort()
	var sorted_expected := expected_files.duplicate()
	sorted_expected.sort()
	_check(_frames.size() == 24, "capture records exactly 24 frames")
	_check(_scenario_records.size() == 4, "capture records exactly four scenarios")
	_check(actual_files == sorted_expected, "output contains exactly the declared 24 PNGs")
	for index in mini(_frames.size(), 24):
		var frame := _frames[index]
		var expected_state := STATES[index % STATES.size()] as Dictionary
		var scenario_index := index / STATES.size()
		var expected_load_generation := scenario_index * 2 + 1
		var expected_generation := (
			expected_load_generation
			if bool(expected_state.loaded)
			else scenario_index * 2 + (0 if index % STATES.size() == 0 else 2)
		)
		_check(
			int(frame.index) == index + 1
			and str(frame.file_name) == expected_files[index]
			and str(frame.state_id) == str(expected_state.id)
			and bool(frame.loaded) == bool(expected_state.loaded)
			and is_equal_approx(
				float(frame.tracked_distance_m), float(expected_state.distance_m)
			)
			and (frame.camera_transform as Dictionary)
				== _transform_dictionary(_camera_transform)
			and bool(
				(frame.environment as Dictionary).same_production_environment
			)
			and int(frame.coordinator_generation) == expected_generation
			and int(frame.transition_generation) == expected_generation
			and int(frame.loaded_generation) == (
				expected_load_generation if bool(expected_state.loaded) else -1
			)
			and bool(frame.one_loaded_instance) == bool(expected_state.loaded)
			and bool(frame.quality_synchronized) == bool(expected_state.loaded)
			and int(frame.cluster_quality_level) == (
				int(SCENARIOS[scenario_index].quality)
				if bool(expected_state.loaded) else -1
			)
			and float((frame.whole_frame as Dictionary).maximum_luminance)
				> float((frame.whole_frame as Dictionary).minimum_luminance),
			"frame %02d preserves exact ordering, state, distance, camera, and environment"
				% (index + 1)
		)
	for scenario_index in SCENARIOS.size():
		var base := scenario_index * STATES.size()
		_check(
			str(_frames[base].png_sha256) != str(_frames[base + 1].png_sha256)
			and str(_frames[base + 3].png_sha256)
				!= str(_frames[base + 4].png_sha256),
			"%s load and unload transition pairs change rendered pixels"
				% str(SCENARIOS[scenario_index].id)
		)


func _write_manifest() -> void:
	var hashes := PackedStringArray()
	for frame in _frames:
		hashes.append(str(frame.png_sha256))
	var manifest := {
		"schema_version": 1,
		"harness_id": HARNESS_ID,
		"source_freeze_status": "pending",
		"image_inventory_status": "pending",
		"human_review_performed": false,
		"source_inputs": _source_input_hashes(),
		"renderer": {
			"method": str(RenderingServer.get_current_rendering_method()),
			"adapter": RenderingServer.get_video_adapter_name(),
			"display": DisplayServer.get_name(),
			"viewport_size": [root.size.x, root.size.y],
			"msaa_3d": root.msaa_3d,
		},
		"contract": {
			"location_id": "cinder_reach",
			"navigation_anchor": _vector3_array(LOCATION.get_anchor_position()),
			"load_radius_m": LOAD_RADIUS_M,
			"unload_radius_m": UNLOAD_RADIUS_M,
			"tracked_distances_m": [
				PRE_LOAD_DISTANCE_M, LOAD_DISTANCE_M,
				PRE_UNLOAD_DISTANCE_M, UNLOAD_DISTANCE_M,
			],
			"camera_transform": _transform_dictionary(_camera_transform),
			"camera_target": _vector3_array(_camera_target),
			"camera_policy": "one immutable capture camera for all 24 frames",
			"camera_fov_degrees": CAMERA_FOV,
			"camera_near_m": CAMERA_NEAR_M,
			"camera_far_m": CAMERA_FAR_M,
			"tracked_actor_policy": "hidden production guided ship sampled by GameFlow",
			"settle_renderer_draws": SETTLE_DRAWS,
			"luminance_sample_stride": LUMINANCE_SAMPLE_STRIDE,
			"readability_roi": [ROI.position.x, ROI.position.y, ROI.size.x, ROI.size.y],
			"state_ids": _state_id_strings(),
			"scenario_ids": _scenario_id_strings(),
		},
		"image_inventory": {
			"expected_png_count": 24,
			"actual_png_count": _frames.size(),
			"ordered_files": _expected_files(),
			"aggregate_png_sha256": "|".join(hashes).sha256_text(),
		},
		"pair_metrics": _build_pair_metrics(),
		"scenarios": _scenario_records.duplicate(true),
		"frames": _frames.duplicate(true),
	}.duplicate(true)
	var file := FileAccess.open(_output_dir.path_join(MANIFEST_FILE), FileAccess.WRITE)
	if file == null:
		_fail("could not open evidence manifest for writing")
		return
	file.store_string(JSON.stringify(manifest, "\t", true) + "\n")
	file.close()
	_check(
		FileAccess.file_exists(_output_dir.path_join(MANIFEST_FILE)),
		"exact transition evidence manifest is written"
	)


func _source_input_hashes() -> Array[Dictionary]:
	var paths := PackedStringArray([
		"res://tests/cinder_streaming_transition_render.gd",
		"res://scenes/main.tscn",
		"res://scripts/world/cinder_streaming_production_binding.gd",
		"res://scripts/world/cinder_streaming_bootstrap.gd",
		"res://scripts/world/world_streaming_coordinator.gd",
		"res://scripts/world/world_streaming_distance_policy.gd",
		"res://scenes/world/nearby_sector_cluster.tscn",
		"res://assets/world/locations/cinder_reach.tres",
	])
	var result: Array[Dictionary] = []
	for path in paths:
		result.append({"path": path, "sha256": FileAccess.get_sha256(path)})
	return result


func _build_pair_metrics() -> Array[Dictionary]:
	var metrics: Array[Dictionary] = []
	var pair_indices := [
		[0, 1, "pre_load_to_first_committed"],
		[1, 2, "first_committed_to_load_settled"],
		[3, 4, "pre_unload_to_first_unloaded"],
		[4, 5, "first_unloaded_to_unload_settled"],
	]
	for scenario_index in SCENARIOS.size():
		var base := scenario_index * STATES.size()
		for pair_variant in pair_indices:
			var pair := pair_variant as Array
			var before := _frames[base + int(pair[0])]
			var after := _frames[base + int(pair[1])]
			metrics.append({
				"scenario_id": str(before.scenario_id),
				"pair_id": str(pair[2]),
				"before_file": str(before.file_name),
				"after_file": str(after.file_name),
				"whole_frame": _statistics_delta(
					before.whole_frame as Dictionary,
					after.whole_frame as Dictionary
				),
				"readability_roi": _statistics_delta(
					before.readability_roi as Dictionary,
					after.readability_roi as Dictionary
				),
			})
	return metrics


func _statistics_delta(before: Dictionary, after: Dictionary) -> Dictionary:
	return {
		"mean_luminance_before": float(before.mean_luminance),
		"mean_luminance_after": float(after.mean_luminance),
		"mean_luminance_delta": (
			float(after.mean_luminance) - float(before.mean_luminance)
		),
		"standard_deviation_before": float(before.luminance_standard_deviation),
		"standard_deviation_after": float(after.luminance_standard_deviation),
		"standard_deviation_delta": (
			float(after.luminance_standard_deviation)
			- float(before.luminance_standard_deviation)
		),
		"near_black_fraction_before": float(before.near_black_fraction),
		"near_black_fraction_after": float(after.near_black_fraction),
		"near_black_fraction_delta": (
			float(after.near_black_fraction) - float(before.near_black_fraction)
		),
	}


func _expected_files() -> PackedStringArray:
	var files := PackedStringArray()
	var index := 1
	for scenario_variant in SCENARIOS:
		var scenario := scenario_variant as Dictionary
		for state_variant in STATES:
			files.append(
				_frame_file_name(scenario, state_variant as Dictionary, index)
			)
			index += 1
	return files


func _frame_file_name(
	scenario: Dictionary, state: Dictionary, index: int = -1
	) -> String:
	var ordinal := index if index > 0 else _frames.size() + 1
	return "%02d_%s_%s.png" % [ordinal, str(scenario.id), str(state.id)]


func _state_id_strings() -> PackedStringArray:
	var ids := PackedStringArray()
	for state_variant in STATES:
		ids.append(str((state_variant as Dictionary).id))
	return ids


func _scenario_id_strings() -> PackedStringArray:
	var ids := PackedStringArray()
	for scenario_variant in SCENARIOS:
		ids.append(str((scenario_variant as Dictionary).id))
	return ids


func _position_at_distance(distance_m: float) -> Vector3:
	var anchor := LOCATION.get_anchor_position()
	return anchor + (Vector3.ZERO - anchor).normalized() * distance_m


func _transform_dictionary(value: Transform3D) -> Dictionary:
	return {
		"origin": _vector3_array(value.origin),
		"basis_x": _vector3_array(value.basis.x),
		"basis_y": _vector3_array(value.basis.y),
		"basis_z": _vector3_array(value.basis.z),
	}


func _vector3_array(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]


func _vector2_array(value: Vector2) -> Array[float]:
	return [value.x, value.y]


func _renderer_draws(count: int) -> void:
	for _index in count:
		await RenderingServer.frame_post_draw


func _emit_deferred_quality_fence() -> void:
	deferred_quality_fence_reached.emit()


func _on_frame_post_draw() -> void:
	_rendered_frame_count += 1


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_fail(description)


func _fail(description: String) -> void:
	_failures.append(description)
	push_error("CINDER TRANSITION EVIDENCE: " + description)


func _cleanup() -> void:
	if is_instance_valid(_game):
		_game.queue_free()
		await process_frame
		await physics_frame
		await process_frame


func _finish() -> void:
	var callback := Callable(self, &"_on_frame_post_draw")
	if RenderingServer.frame_post_draw.is_connected(callback):
		RenderingServer.frame_post_draw.disconnect(callback)
	if _failures.is_empty():
		if CHECK_ONLY_FLAG in OS.get_cmdline_user_args():
			print("CINDER_STREAMING_TRANSITION_RENDER_CONTRACT_OK: 24 frames")
		else:
			print(
				"CINDER_STREAMING_TRANSITION_RENDER_OK: 24 images manifest=%s"
				% _output_dir.path_join(MANIFEST_FILE)
			)
		quit(0)
	else:
		push_error(
			"CINDER_STREAMING_TRANSITION_RENDER_FAILED: %s"
			% "; ".join(_failures)
		)
		quit(1)
