extends SceneTree

## Native Forward+ before/after witness for StationDoor's frame-post renderer
## sharing. Two live production door scenes stay at fixed, differently placed
## gameplay poses. The starboard door also carries an authored post-layout
## override. The first frame restores the two semantic MeshInstance renderers;
## the second uses the production MultiMesh batch. Exact full-frame and bounded
## post-region identity prove the optimization does not change either silhouette.

const DOOR_SCENE := preload("res://scenes/world/components/station_door.tscn")
const RESOLUTION := Vector2i(1440, 900)
const OUTPUT_DIR := "res://artifacts/station_door_frame_post_sharing"
const BEFORE_PATH := OUTPUT_DIR + "/before_authored_post_renderers.png"
const AFTER_PATH := OUTPUT_DIR + "/after_shared_post_buffers.png"
const RENDER_LAYER_A := 1
const RENDER_LAYER_B := 1 << 1

var _failures: Array[String] = []
var _camera: Camera3D


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = RESOLUTION
	root.content_scale_size = Vector2i.ZERO
	root.use_taa = false
	root.msaa_3d = Viewport.MSAA_DISABLED
	root.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	_check(
		RenderingServer.get_current_rendering_method() == &"forward_plus"
			and DisplayServer.get_name() == "X11"
			and not RenderingServer.get_video_adapter_name().is_empty(),
		"capture has a native X11 Forward+ rendering device"
	)

	var stage := Node3D.new()
	stage.name = "StationDoorFramePostReviewStage"
	root.add_child(stage)
	_build_environment(stage)

	var door_a := DOOR_SCENE.instantiate() as StationDoor
	var door_b := DOOR_SCENE.instantiate() as StationDoor
	_check(door_a != null and door_b != null, "two production StationDoor scenes instantiate")
	if door_a == null or door_b == null:
		_finish()
		return

	door_a.name = "ProductionDoorA"
	door_a.position = Vector3(-2.7, 0.0, 0.35)
	door_a.rotation_degrees.y = -8.0
	door_b.name = "CustomLayoutDoorB"
	door_b.position = Vector3(2.65, 0.0, -0.2)
	door_b.rotation_degrees.y = 11.0
	# Production hosts are allowed to alter authored component layout before the
	# node enters the tree. This one local override must never acquire Door A's
	# cached default transforms.
	var overridden_right := door_b.get_node(^"FrameVisuals/RightPost") as MeshInstance3D
	overridden_right.position.x += 0.18
	stage.add_child(door_a)
	stage.add_child(door_b)
	await process_frame
	await process_frame

	_style_door_renderer(door_a, RENDER_LAYER_A, 0.12, false, Color("1a3038"))
	_style_door_renderer(door_b, RENDER_LAYER_B, 0.47, true, Color("433229"))
	_check_batch_contract(door_a, door_b)

	_camera = Camera3D.new()
	_camera.name = "StationDoorFramePostCaptureCamera"
	_camera.position = Vector3(0.0, 3.15, -13.2)
	_camera.near = 0.08
	_camera.far = 80.0
	_camera.fov = 35.0
	_camera.cull_mask = RENDER_LAYER_A | RENDER_LAYER_B
	stage.add_child(_camera)
	_camera.look_at(Vector3(0.0, 1.85, 0.0), Vector3.UP)
	_camera.current = true
	_check(
		_camera.position.distance_to(Vector3(0.0, 1.85, 0.0)) > 12.0,
		"fixed review camera remains at gameplay distance"
	)

	_set_baseline_renderers(door_a, true)
	_set_baseline_renderers(door_b, true)
	var before := await _capture(BEFORE_PATH)
	_set_baseline_renderers(door_a, false)
	_set_baseline_renderers(door_b, false)
	var after := await _capture(AFTER_PATH)

	_check(
		before != null and after != null and before.get_data() == after.get_data(),
		"authored and shared-buffer frames are pixel-identical"
	)
	if before != null and after != null:
		for door in [door_a, door_b]:
			for post_name in [^"FrameVisuals/LeftPost", ^"FrameVisuals/RightPost"]:
				var post := door.get_node(post_name) as MeshInstance3D
				var region := _post_region(post)
				var before_region := before.get_region(region)
				var after_region := after.get_region(region)
				_check(
					before_region.get_data() == after_region.get_data()
						and _region_has_visible_detail(before_region),
					"%s/%s keeps an identical visible bounded post region" % [
						door.name, post.name
					]
				)

	stage.queue_free()
	await process_frame
	_finish()


func _style_door_renderer(
		door: StationDoor,
		layer_mask: int,
		cull_margin: float,
		ignore_occlusion: bool,
		albedo: Color
) -> void:
	var left := door.get_node(^"FrameVisuals/LeftPost") as MeshInstance3D
	var right := door.get_node(^"FrameVisuals/RightPost") as MeshInstance3D
	var batch := door.get_node(^"FrameVisuals/FramePostRenderBatch") as MultiMeshInstance3D
	var material := (batch.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
	material.albedo_color = albedo
	for renderer in [left, right, batch]:
		renderer.material_override = material
		renderer.extra_cull_margin = cull_margin
		renderer.ignore_occlusion_culling = ignore_occlusion
	batch.layers = layer_mask
	left.layers = 0
	right.layers = 0
	batch.set_meta(&"capture_host_layer", layer_mask)


func _check_batch_contract(door_a: StationDoor, door_b: StationDoor) -> void:
	var batch_a := door_a.get_node(^"FrameVisuals/FramePostRenderBatch") as MultiMeshInstance3D
	var batch_b := door_b.get_node(^"FrameVisuals/FramePostRenderBatch") as MultiMeshInstance3D
	var right_b := door_b.get_node(^"FrameVisuals/RightPost") as MeshInstance3D
	var transforms_b := batch_b.multimesh.get_meta(&"authored_instance_transforms", []) as Array
	_check(
		batch_a.multimesh != batch_b.multimesh
			and transforms_b.size() == 2
			and (transforms_b[1] as Transform3D).is_equal_approx(right_b.transform),
		"custom post layout owns a separate exact buffer from the default door"
	)
	_check(
		batch_a.material_override != batch_b.material_override
			and batch_a.layers == RENDER_LAYER_A
			and batch_b.layers == RENDER_LAYER_B
			and is_equal_approx(batch_a.extra_cull_margin, 0.12)
			and is_equal_approx(batch_b.extra_cull_margin, 0.47)
			and not batch_a.ignore_occlusion_culling
			and batch_b.ignore_occlusion_culling,
		"each door retains independent host material, layer, and culling state"
	)


func _set_baseline_renderers(door: StationDoor, baseline: bool) -> void:
	var batch := door.get_node(^"FrameVisuals/FramePostRenderBatch") as MultiMeshInstance3D
	var layer_mask := int(batch.get_meta(&"capture_host_layer", 0))
	var left := door.get_node(^"FrameVisuals/LeftPost") as MeshInstance3D
	var right := door.get_node(^"FrameVisuals/RightPost") as MeshInstance3D
	left.layers = layer_mask if baseline else 0
	right.layers = layer_mask if baseline else 0
	batch.layers = 0 if baseline else layer_mask


func _capture(path: String) -> Image:
	for _frame in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_check(
		image != null and not image.is_empty() and image.get_size() == RESOLUTION,
		"capture returns a stable 1440x900 renderer frame"
	)
	if image == null or image.is_empty():
		return null
	var absolute := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	_check(image.save_png(absolute) == OK, "capture frame saves successfully")
	print("STATION_DOOR_FRAME_POST_CAPTURE: ", absolute)
	return image


func _post_region(post: MeshInstance3D) -> Rect2i:
	var center := _camera.unproject_position(post.global_position)
	var half_size := Vector2i(34, 130)
	var top_left := Vector2i(center.round()) - half_size
	top_left.x = clampi(top_left.x, 0, RESOLUTION.x - half_size.x * 2)
	top_left.y = clampi(top_left.y, 0, RESOLUTION.y - half_size.y * 2)
	return Rect2i(top_left, half_size * 2)


func _region_has_visible_detail(image: Image) -> bool:
	if image == null or image.is_empty():
		return false
	var first := image.get_pixel(0, 0)
	for y in range(0, image.get_height(), 3):
		for x in range(0, image.get_width(), 3):
			var pixel := image.get_pixel(x, y)
			if absf(pixel.r - first.r) + absf(pixel.g - first.g) \
					+ absf(pixel.b - first.b) > 0.06:
				return true
	return false


func _build_environment(stage: Node3D) -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("071019")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("88a0b2")
	environment.ambient_light_energy = 0.58
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.glow_enabled = false
	world_environment.environment = environment
	stage.add_child(world_environment)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-44.0, 28.0, 0.0)
	key.light_color = Color("ffe4c2")
	key.light_energy = 2.0
	key.shadow_enabled = false
	stage.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(18.0, -132.0, 0.0)
	fill.light_color = Color("70c0d2")
	fill.light_energy = 0.72
	fill.shadow_enabled = false
	stage.add_child(fill)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	_failures.append(message)
	push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("STATION_DOOR_FRAME_POST_CAPTURE_OK")
		quit(0)
		return
	print("STATION_DOOR_FRAME_POST_CAPTURE_FAILED: ", "; ".join(_failures))
	quit(1)
