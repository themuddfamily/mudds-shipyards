extends SceneTree

## Native, evidence-only renderer witness for the standalone Aurora authored scene.
##
## This never instantiates Main, GameFlow, a Player, or a streaming owner. It adds
## exactly one temporary Camera3D, explicitly configures Aurora's own standalone
## atmosphere composition, and photographs one immutable body-local observation.
## The two frames differ only by the existing HIGH/LOW renderer profile.

const AuroraScene := preload("res://scenes/world/planets/aurora_temperate_world.tscn")
const VisualQuality := preload("res://scripts/rendering/visual_quality_controller.gd")

const OUTPUT_DIR := "res://artifacts/aurora_temperate_visuals"
const CAPTURE_ROOT := OUTPUT_DIR + "/captures"
const STAGED_DIR := CAPTURE_ROOT + "/.capture_transaction"
const CURRENT_POINTER_PATH := OUTPUT_DIR + "/evidence_manifest.json"
const STAGED_EVIDENCE_MANIFEST_FILE := "evidence_manifest.json"
const STAGED_SOURCE_MANIFEST_FILE := "source_manifest.sha256"
const STAGED_CAPTURE_LOG_FILE := "capture_forward_plus_1920x1080.log"
const PARSE_ONLY_ENVIRONMENT_VARIABLE := "MUDDS_CAPTURE_AURORA_TEMPERATE_VISUALS_PARSE_ONLY"

const CAPTURE_RESOLUTION := Vector2i(1920, 1080)
const CAMERA_POSITION := Vector3(0.0, 120_060.0, 300.0)
const CAMERA_TARGET := Vector3(0.0, 120_000.0, 0.0)
const CAMERA_FOV_DEGREES := 52.0
const CAMERA_NEAR_M := 0.1
const CAMERA_FAR_M := 400_000.0
const SETTLE_DRAWS := 16
var _fixed_observation: Dictionary = {
	"body_local_observer_m": CAMERA_POSITION,
	"view_direction_body_local": Vector3(0.0, -60.0, -300.0).normalized(),
	"fog_path_distance_m": 12_000.0,
	"speed_mps": 0.0,
	"weather_scalar": 1.0,
	"cloud_scalar": 1.0,
	"caller_time_seconds": 0.0,
}
const CAPTURE_FILES := [
	"01_surface_horizon_high.png",
	"02_surface_horizon_low.png",
]
const CAPTURE_QUALITYS := [
	VisualQuality.QualityLevel.HIGH,
	VisualQuality.QualityLevel.LOW,
]
const CAPTURE_LABELS := [&"high", &"low"]
var _source_paths: PackedStringArray = PackedStringArray([
	"res://project.godot",
	"res://tests/capture_aurora_temperate_visuals.gd",
	"res://scenes/world/planets/aurora_temperate_world.tscn",
	"res://scenes/world/components/aurora_temperate_atmosphere_composition.tscn",
	"res://assets/world/planets/aurora_temperate_world.tres",
	"res://assets/world/planets/aurora_temperate_atmosphere.tres",
	"res://assets/world/planets/aurora_temperate_terrain.tres",
	"res://assets/world/planets/aurora_foundation_landing.tres",
	"res://scripts/world/aurora_temperate_authored_scene.gd",
	"res://scripts/world/planetary_terrain_clipmap_renderer.gd",
	"res://scripts/world/planetary_atmosphere_composition.gd",
	"res://scripts/world/planetary_atmosphere_world_rig.gd",
	"res://scripts/world/planetary_atmosphere_presentation.gd",
	"res://scripts/world/planetary_sky_presentation.gd",
	"res://scripts/world/planetary_cloud_presentation.gd",
	"res://scripts/world/planetary_sun_presentation.gd",
	"res://scripts/rendering/planetary_cloud_shell.gdshader",
	"res://scripts/rendering/visual_quality_controller.gd",
	"res://docs/AURORA_TEMPERATE_AUTHORED_SCENE.md",
])

var _failures := PackedStringArray()
var _scene: AuroraTemperateAuthoredScene
var _composition: PlanetaryAtmosphereComposition
var _camera: Camera3D
var _scene_transform: Transform3D
var _landing_transform: Transform3D
var _camera_contract: Dictionary = {}
var _source_snapshot: Dictionary = {}
var _source_aggregate_sha256 := ""
var _frames: Array[Dictionary] = []
var _captured_images: Array[Image] = []
var _prior_pointer_sha256 := ""
var _capture_directory := ""


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	if OS.get_environment(PARSE_ONLY_ENVIRONMENT_VARIABLE) == "1":
		print("MUDDS_CAPTURE_AURORA_TEMPERATE_VISUALS_PARSE_OK")
		quit(0)
		return
	if not _native_forward_plus_available():
		print(
			"AURORA_TEMPERATE_VISUALS_NATIVE_BLOCKED: renderer=%s display=%s (requires Forward+ on X11; no artifacts published)"
			% [RenderingServer.get_current_rendering_method(), DisplayServer.get_name()]
		)
		quit(2)
		return

	_configure_native_viewport()
	_source_snapshot = _snapshot_sources()
	_source_aggregate_sha256 = _source_snapshot_hash(_source_snapshot)
	if _source_snapshot.size() != _source_paths.size() or _source_aggregate_sha256.is_empty():
		_finish()
		return

	_scene = AuroraScene.instantiate() as AuroraTemperateAuthoredScene
	_check(_scene != null, "Aurora standalone authored scene instantiates")
	if _scene == null:
		_finish()
		return
	root.add_child(_scene)
	await process_frame
	_prepare_standalone_scene()
	if not _failures.is_empty():
		await _dispose_scene()
		_finish()
		return

	_prepare_transaction()
	if not _failures.is_empty():
		await _dispose_scene()
		_finish()
		return
	for index in CAPTURE_FILES.size():
		await _capture_profile(index)
		if not _failures.is_empty():
			break
	if _failures.is_empty():
		_validate_capture_pair()
		_validate_source_frozen()
	if _failures.is_empty():
		_write_capture_log()
		_write_source_manifest()
		_write_evidence_manifest()
		if _failures.is_empty():
			_publish_transaction()
	if not _failures.is_empty():
		_remove_transaction_tree(STAGED_DIR)
	await _dispose_scene()
	_finish()


func _native_forward_plus_available() -> bool:
	return RenderingServer.get_current_rendering_method() == &"forward_plus" \
		and DisplayServer.get_name() == "X11"


func _configure_native_viewport() -> void:
	root.size = CAPTURE_RESOLUTION
	root.content_scale_size = Vector2i.ZERO
	root.msaa_3d = Viewport.MSAA_2X
	_check(DisplayServer.window_get_size() == CAPTURE_RESOLUTION, "native window is exactly 1920x1080")
	print(
		"AURORA_TEMPERATE_VISUAL_RENDERER: method=%s adapter=%s display=%s window=%s"
		% [
			RenderingServer.get_current_rendering_method(), RenderingServer.get_video_adapter_name(),
			DisplayServer.get_name(), str(DisplayServer.window_get_size()),
		]
	)


func _prepare_standalone_scene() -> void:
	_check(root.get_node_or_null("Main") == null, "capture root has no production Main")
	_check(_scene.audit().get("valid", false), "Aurora standalone authored-scene audit is valid")
	_check(_scene.find_children("*", "Camera3D", true, false).is_empty(), "authored Aurora scene owns no camera")
	_scene_transform = _scene.global_transform
	var landing := _scene.get_node_or_null(^"LandingRegion") as Node3D
	_check(landing != null, "Aurora authored landing region exists")
	if landing == null:
		return
	_landing_transform = landing.global_transform
	_composition = _scene.get_node_or_null(^"AuroraAtmosphereComposition") as PlanetaryAtmosphereComposition
	_check(_composition != null, "Aurora scene resolves its standalone atmosphere composition")
	if _composition == null:
		return
	_check(
		_composition.get_world_environment().environment == null,
		"Aurora atmosphere Environment is inactive before the evidence-only configure call"
	)
	var configured := _composition.configure()
	_check(bool(configured.get("accepted", false)) and int(configured.get("generation", 0)) == 1,
		"evidence-only composition configure succeeds once")
	var environment := _composition.get_world_environment().environment
	_check(environment == _composition.get_atmosphere_rig().get_scene_environment(),
		"configured composition installs only the rig-owned Environment")
	if environment == null:
		return
	var presented := _composition.present_observation(_fixed_observation, 1)
	_check(bool(presented.get("accepted", false)), "one fixed body-local Aurora observation is accepted")
	_install_camera()


func _install_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "AuroraRendererWitnessCamera"
	_camera.fov = CAMERA_FOV_DEGREES
	_camera.near = CAMERA_NEAR_M
	_camera.far = CAMERA_FAR_M
	root.add_child(_camera)
	_camera.global_position = CAMERA_POSITION
	_camera.look_at(CAMERA_TARGET, Vector3.UP)
	_camera.current = true
	_camera_contract = {
		"instance_id": _camera.get_instance_id(),
		"transform": _camera.global_transform,
		"fov": _camera.fov,
		"near": _camera.near,
		"far": _camera.far,
		"projection": _camera.projection,
		"cull_mask": _camera.cull_mask,
	}.duplicate(true)
	_check(root.get_camera_3d() == _camera, "capture-only camera is active")
	_check(_camera.global_position == CAMERA_POSITION and _camera.fov == CAMERA_FOV_DEGREES,
		"capture camera uses the frozen ApproachEntry pose and projection")
	var target_direction := (CAMERA_TARGET - CAMERA_POSITION).normalized()
	var camera_forward := -_camera.global_transform.basis.z.normalized()
	_check(camera_forward.dot(target_direction) > 0.99999,
		"recorded evidence-camera basis faces the frozen Aurora target")


func _capture_profile(index: int) -> void:
	var environment := _composition.get_world_environment().environment
	var quality: int = CAPTURE_QUALITYS[index]
	var label: StringName = CAPTURE_LABELS[index]
	var applied := VisualQuality.apply_profile(environment, root, quality)
	_check(bool(applied.get("applied", false)), "%s profile applies on native Forward+" % label)
	_check(_fixed_scene_contract_current(), "%s profile leaves authored scene transforms untouched" % label)
	if label == &"high":
		_check(environment.volumetric_fog_enabled and environment.ssil_enabled and root.use_taa,
			"HIGH captures Forward+ volumetric, SSIL and TAA")
	else:
		_check(not environment.volumetric_fog_enabled and not environment.ssil_enabled and not root.use_taa,
			"LOW disables the Forward+-only passes and TAA")
	if not _failures.is_empty():
		return
	await _settle_renderer(SETTLE_DRAWS)
	_check(_fixed_scene_contract_current(), "%s settle keeps authored scene transforms untouched" % label)
	_check(_fixed_camera_contract_current(), "%s settle keeps the evidence camera immutable" % label)
	if not _failures.is_empty():
		return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_check(image != null and not image.is_empty(), "%s native capture image is non-empty" % label)
	if image == null or image.is_empty():
		return
	image.convert(Image.FORMAT_RGB8)
	_check(image.get_size() == CAPTURE_RESOLUTION, "%s capture has exact 1920x1080 dimensions" % label)
	if image.get_size() != CAPTURE_RESOLUTION:
		return
	var statistics := _image_statistics(image)
	_check(float(statistics.get("luminance_range", 0.0)) > 0.0
		and float(statistics.get("luminance_variance", 0.0)) > 0.0,
		"%s capture is not a uniform blank frame" % label)
	if not _failures.is_empty():
		return
	var staged_path := STAGED_DIR.path_join(CAPTURE_FILES[index])
	var save_error := image.save_png(staged_path)
	_check(save_error == OK, "%s capture writes its staged PNG" % label)
	if save_error != OK:
		return
	_frames.append({
		"file": CAPTURE_FILES[index],
		"profile": label,
		"sha256": FileAccess.get_sha256(staged_path),
		"png_bytes": FileAccess.get_size(staged_path),
		"resolution": [CAPTURE_RESOLUTION.x, CAPTURE_RESOLUTION.y],
		"luminance_range": snappedf(float(statistics.get("luminance_range", 0.0)), 0.000001),
		"luminance_variance": snappedf(float(statistics.get("luminance_variance", 0.0)), 0.000001),
		"camera_transform": _transform_dictionary(_camera.global_transform),
		"camera_fov_degrees": _camera.fov,
		"observation": _observation_manifest(),
	}.duplicate(true))
	_captured_images.append(image)
	print("AURORA_TEMPERATE_VISUAL_CAPTURED: profile=%s path=%s" % [label, ProjectSettings.globalize_path(staged_path)])


func _validate_capture_pair() -> void:
	_check(_frames.size() == 2 and _captured_images.size() == 2,
		"exact HIGH and LOW Aurora frame inventory was captured")
	if _captured_images.size() != 2:
		return
	var changed_fraction := _changed_fraction(_captured_images[0], _captured_images[1])
	_check(changed_fraction > 0.0, "HIGH and LOW captures are visibly non-identical")
	if _frames.size() == 2:
		_frames[0]["high_low_changed_fraction"] = snappedf(changed_fraction, 0.000001)
		_frames[1]["high_low_changed_fraction"] = snappedf(changed_fraction, 0.000001)


func _fixed_scene_contract_current() -> bool:
	var landing := _scene.get_node_or_null(^"LandingRegion") as Node3D
	return _scene.global_transform == _scene_transform \
		and landing != null and landing.global_transform == _landing_transform \
		and _composition.get_world_environment().environment == _composition.get_atmosphere_rig().get_scene_environment()


func _fixed_camera_contract_current() -> bool:
	return root.get_camera_3d() == _camera \
		and _camera.get_instance_id() == int(_camera_contract.get("instance_id", 0)) \
		and _camera.global_transform == _camera_contract.get("transform", Transform3D.IDENTITY) \
		and is_equal_approx(_camera.fov, float(_camera_contract.get("fov", 0.0))) \
		and is_equal_approx(_camera.near, float(_camera_contract.get("near", 0.0))) \
		and is_equal_approx(_camera.far, float(_camera_contract.get("far", 0.0))) \
		and _camera.projection == int(_camera_contract.get("projection", -1)) \
		and _camera.cull_mask == int(_camera_contract.get("cull_mask", -1))


func _settle_renderer(draw_count: int) -> void:
	for _draw in draw_count:
		await process_frame
		await RenderingServer.frame_post_draw


func _image_statistics(image: Image) -> Dictionary:
	var count := 0
	var mean := 0.0
	var mean_square := 0.0
	var minimum := 1.0
	var maximum := 0.0
	for y in range(0, image.get_height(), 4):
		for x in range(0, image.get_width(), 4):
			var colour := image.get_pixel(x, y)
			var luminance := colour.r * 0.2126 + colour.g * 0.7152 + colour.b * 0.0722
			count += 1
			mean += luminance
			mean_square += luminance * luminance
			minimum = minf(minimum, luminance)
			maximum = maxf(maximum, luminance)
	mean /= maxf(float(count), 1.0)
	return {
		"luminance_range": maximum - minimum,
		"luminance_variance": maxf(0.0, mean_square / maxf(float(count), 1.0) - mean * mean),
	}.duplicate(true)


func _changed_fraction(left: Image, right: Image) -> float:
	if left.get_size() != right.get_size():
		return 0.0
	var changed := 0
	var count := 0
	for y in range(0, left.get_height(), 4):
		for x in range(0, left.get_width(), 4):
			var difference := left.get_pixel(x, y) - right.get_pixel(x, y)
			if absf(difference.r) + absf(difference.g) + absf(difference.b) > 0.0001:
				changed += 1
			count += 1
	return float(changed) / maxf(float(count), 1.0)


func _prepare_transaction() -> void:
	var output_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_check(output_error == OK or output_error == ERR_ALREADY_EXISTS, "Aurora visual output directory is available")
	var capture_root_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_ROOT))
	_check(capture_root_error == OK or capture_root_error == ERR_ALREADY_EXISTS,
		"Aurora versioned capture root is available")
	_prior_pointer_sha256 = FileAccess.get_sha256(CURRENT_POINTER_PATH) \
		if FileAccess.file_exists(CURRENT_POINTER_PATH) else ""
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(STAGED_DIR)):
		_remove_transaction_tree(STAGED_DIR)
	var transaction_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(STAGED_DIR))
	_check(transaction_error == OK or transaction_error == ERR_ALREADY_EXISTS,
		"fresh bounded Aurora staged capture directory is available")


func _write_capture_log() -> void:
	var path := STAGED_DIR.path_join(STAGED_CAPTURE_LOG_FILE)
	var file := FileAccess.open(path, FileAccess.WRITE)
	_check(file != null, "staged Aurora capture log opens")
	if file == null:
		return
	file.store_line("renderer=%s" % RenderingServer.get_current_rendering_method())
	file.store_line("adapter=%s" % RenderingServer.get_video_adapter_name())
	file.store_line("display=%s" % DisplayServer.get_name())
	file.store_line("window=%s" % str(DisplayServer.window_get_size()))
	file.store_line("camera_position=%s" % str(CAMERA_POSITION))
	file.store_line("camera_target=%s" % str(CAMERA_TARGET))
	file.store_line("observation=%s" % JSON.stringify(_observation_manifest(), "", false))
	file.flush()
	var error := file.get_error()
	file.close()
	_check(error == OK, "staged Aurora capture log flushes")


func _write_source_manifest() -> void:
	var file := FileAccess.open(STAGED_DIR.path_join(STAGED_SOURCE_MANIFEST_FILE), FileAccess.WRITE)
	_check(file != null, "staged Aurora source manifest opens")
	if file == null:
		return
	for path in _source_paths:
		file.store_line("%s  %s" % [_source_snapshot.get(path, ""), path])
	file.flush()
	var error := file.get_error()
	file.close()
	_check(error == OK, "staged Aurora source manifest flushes")


func _write_evidence_manifest() -> void:
	var manifest := {
		"schema": "mudds_aurora_temperate_renderer_witness_v1",
		"capture_resolution": [CAPTURE_RESOLUTION.x, CAPTURE_RESOLUTION.y],
		"renderer": String(RenderingServer.get_current_rendering_method()),
		"adapter": RenderingServer.get_video_adapter_name(),
		"display": DisplayServer.get_name(),
		"native_window_size": [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y],
		"frame_inventory": CAPTURE_FILES,
		"profiles": ["high", "low"],
		"camera": {
			"evidence_only": true,
			"position_body_local_m": _vector_array(CAMERA_POSITION),
			"target_body_local_m": _vector_array(CAMERA_TARGET),
			"fov_degrees": CAMERA_FOV_DEGREES,
			"near_m": CAMERA_NEAR_M,
			"far_m": CAMERA_FAR_M,
		},
		"observation": _observation_manifest(),
		"frames": _frames.duplicate(true),
		"source_manifest_file": STAGED_SOURCE_MANIFEST_FILE,
		"source_manifest_sha256": FileAccess.get_sha256(STAGED_DIR.path_join(STAGED_SOURCE_MANIFEST_FILE)),
		"source_aggregate_sha256": _source_aggregate_sha256,
		"source_files": _source_snapshot.duplicate(true),
		"source_unchanged_during_capture": _source_snapshot == _snapshot_sources(),
		"capture_log_file": STAGED_CAPTURE_LOG_FILE,
		"authority": {
			"content_class": "NEW",
			"status": "modern_interpretation",
			"source_bounded": false,
			"confidence": "none",
			"evidence_scope": "aurora_standalone_renderer_witness",
			"production_witness": false,
		},
		"proves_only": [
			"The standalone Aurora authored scene configured its own atmosphere composition and presented the one recorded body-local observation.",
			"The named native Forward+ renderer produced nonblank HIGH and LOW frames from the same immutable evidence camera.",
		],
		"does_not_prove": [
			"Main or GameFlow integration.", "streaming, loading, unloading, or visitability.",
			"Player or production-camera ownership, input, movement, or landing eligibility.",
			"Production focus updates or collision beyond the generated 1.5 km terrain boundary.",
			"Weather, time-of-day, audio, save, networking, or native-GPU performance.",
			"Production visual quality, fidelity, or craftsmanship.",
		],
	}.duplicate(true)
	var file := FileAccess.open(STAGED_DIR.path_join(STAGED_EVIDENCE_MANIFEST_FILE), FileAccess.WRITE)
	_check(file != null, "staged Aurora evidence manifest opens")
	if file == null:
		return
	file.store_string(JSON.stringify(manifest, "  ", false) + "\n")
	file.flush()
	var error := file.get_error()
	file.close()
	_check(error == OK, "staged Aurora evidence manifest flushes")


func _publish_transaction() -> void:
	_check(_complete_capture_directory(STAGED_DIR), "staged Aurora capture set is complete before publication")
	_check(_pointer_sha256_current(), "prior current manifest remains unchanged before version publish")
	if not _failures.is_empty():
		return
	var capture_id := "%d_%s" % [Time.get_ticks_msec(), _source_aggregate_sha256.left(12)]
	_capture_directory = CAPTURE_ROOT.path_join("capture_" + capture_id)
	_check(not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(_capture_directory)),
		"new Aurora capture directory is unique")
	if not _failures.is_empty():
		return
	var version_error := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(STAGED_DIR), ProjectSettings.globalize_path(_capture_directory)
	)
	_check(version_error == OK, "complete Aurora capture directory commits before current-manifest switch")
	if version_error != OK:
		_check(_pointer_sha256_current(), "failed version publish preserves the prior current manifest")
		return
	_check(_complete_capture_directory(_capture_directory), "committed Aurora capture directory remains complete")
	_check(_pointer_sha256_current(), "version-directory publish leaves the prior current manifest intact")
	if not _failures.is_empty():
		return
	_write_current_pointer()
	if not _failures.is_empty():
		return
	_check(_current_pointer_targets_complete_capture(),
		"atomic current-manifest switch targets one complete Aurora capture set")


func _write_current_pointer() -> void:
	var temporary_path := OUTPUT_DIR.path_join(".aurora_current_%s.json" % _capture_directory.get_file())
	var pointer := {
		"schema": "mudds_aurora_temperate_renderer_witness_current_v1",
		"capture_directory": _capture_directory,
		"evidence_manifest": _capture_directory.path_join(STAGED_EVIDENCE_MANIFEST_FILE),
		"source_manifest": _capture_directory.path_join(STAGED_SOURCE_MANIFEST_FILE),
		"capture_log": _capture_directory.path_join(STAGED_CAPTURE_LOG_FILE),
		"frame_paths": [
			_capture_directory.path_join(CAPTURE_FILES[0]),
			_capture_directory.path_join(CAPTURE_FILES[1]),
		],
	}.duplicate(true)
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	_check(file != null, "next Aurora current-manifest pointer opens")
	if file == null:
		return
	file.store_string(JSON.stringify(pointer, "  ", false) + "\n")
	file.flush()
	var write_error := file.get_error()
	file.close()
	_check(write_error == OK, "next Aurora current-manifest pointer flushes")
	if write_error != OK:
		return
	# The harness permits only native X11 publication. On this POSIX target rename
	# atomically replaces the pointer file, so a failure leaves the prior complete
	# pointer in place; the committed version directory remains recoverable.
	var switch_error := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(temporary_path), ProjectSettings.globalize_path(CURRENT_POINTER_PATH)
	)
	_check(switch_error == OK, "current Aurora manifest pointer switches atomically")
	if switch_error != OK:
		_check(_pointer_sha256_current(), "failed current-manifest switch preserves the prior pointer")
		if FileAccess.file_exists(temporary_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary_path))


func _complete_capture_directory(path: String) -> bool:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)):
		return false
	for file_name in CAPTURE_FILES:
		if not FileAccess.file_exists(path.path_join(file_name)):
			return false
	for file_name in [STAGED_CAPTURE_LOG_FILE, STAGED_SOURCE_MANIFEST_FILE, STAGED_EVIDENCE_MANIFEST_FILE]:
		if not FileAccess.file_exists(path.path_join(file_name)):
			return false
	return true


func _pointer_sha256_current() -> bool:
	var current := FileAccess.get_sha256(CURRENT_POINTER_PATH) \
		if FileAccess.file_exists(CURRENT_POINTER_PATH) else ""
	return current == _prior_pointer_sha256


func _current_pointer_targets_complete_capture() -> bool:
	if not FileAccess.file_exists(CURRENT_POINTER_PATH):
		return false
	var file := FileAccess.open(CURRENT_POINTER_PATH, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return false
	var pointer := parsed as Dictionary
	return pointer.get("capture_directory", "") == _capture_directory \
		and _complete_capture_directory(_capture_directory)


func _remove_transaction_tree(path: String) -> void:
	if path != STAGED_DIR and not path.begins_with(STAGED_DIR + "/"):
		_fail("refusing cleanup outside bounded Aurora transaction: %s" % path)
		return
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)):
		return
	var directory := DirAccess.open(path)
	if directory == null:
		_fail("Aurora transaction directory cannot open: %s" % path)
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		var child_path := path.path_join(entry)
		if directory.current_is_dir():
			_remove_transaction_tree(child_path)
		else:
			var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(child_path))
			_check(error == OK, "staged Aurora transaction file clears: %s" % child_path)
		entry = directory.get_next()
	directory.list_dir_end()
	var remove_error := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_check(remove_error == OK, "Aurora transaction directory clears")


func _snapshot_sources() -> Dictionary:
	var snapshot := {}
	for path in _source_paths:
		var digest := FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""
		_check(not digest.is_empty(), "Aurora source manifest path exists and hashes: %s" % path)
		if not digest.is_empty():
			snapshot[path] = digest
	return snapshot


func _source_snapshot_hash(snapshot: Dictionary) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	for path in _source_paths:
		context.update(("%s  %s\n" % [snapshot.get(path, ""), path]).to_utf8_buffer())
	return context.finish().hex_encode()


func _validate_source_frozen() -> void:
	_check(_source_snapshot == _snapshot_sources(), "Aurora renderer-witness sources stay frozen through capture")


func _observation_manifest() -> Dictionary:
	return {
		"body_local_observer_m": _vector_array(CAMERA_POSITION),
		"view_direction_body_local": _vector_array(_fixed_observation.view_direction_body_local),
		"fog_path_distance_m": _fixed_observation.fog_path_distance_m,
		"speed_mps": _fixed_observation.speed_mps,
		"weather_scalar": _fixed_observation.weather_scalar,
		"cloud_scalar": _fixed_observation.cloud_scalar,
		"caller_time_seconds": _fixed_observation.caller_time_seconds,
	}.duplicate(true)


func _vector_array(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]


func _transform_dictionary(value: Transform3D) -> Dictionary:
	return {
		"origin": _vector_array(value.origin),
		"basis_x": _vector_array(value.basis.x),
		"basis_y": _vector_array(value.basis.y),
		"basis_z": _vector_array(value.basis.z),
	}.duplicate(true)


func _dispose_scene() -> void:
	if _camera != null and is_instance_valid(_camera):
		_camera.queue_free()
	if _scene != null and is_instance_valid(_scene):
		_scene.queue_free()
	await process_frame


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
	else:
		_fail(label)


func _fail(label: String) -> void:
	if not _failures.has(label):
		_failures.append(label)
	push_error("FAIL: %s" % label)


func _finish() -> void:
	if _failures.is_empty():
		print("AURORA_TEMPERATE_VISUALS_TEST_OK frames=%d" % _frames.size())
		quit(0)
	else:
		print("AURORA_TEMPERATE_VISUALS_TEST_FAILED: %s" % ", ".join(_failures))
		quit(1)
