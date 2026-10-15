extends SceneTree

## Isolated Forward+ before/after witness for Habitat trestle feet or common chairs.
## The fixed common-room camera first draws two ordinary MeshInstance3D copies,
## then the production MultiMesh. Optional --common-chairs reconstructs the
## original primitive renderers from retained source meshes in the authored index.
## Chair full frames allow the explicit one-code RGB output budget below; both
## bounded regions and default trestle frames remain byte-exact. This isolated
## renderer witness does not qualify native GPU performance.

const MODULE_SCENE := preload("res://scenes/world/modules/habitat_spine.tscn")
const RESOLUTION := Vector2i(1600, 900)
const OUTPUT_DIR := "res://artifacts/habitat_mess_trestle_foot_batch"
const BEFORE_PATH := OUTPUT_DIR + "/before_individual_feet.png"
const AFTER_PATH := OUTPUT_DIR + "/after_batched_feet.png"
const OUTPUT_ENV := "MUDDS_HABITAT_CAPTURE_OUTPUT_DIR"
const COMMON_CHAIR_VIEWS := [
	{ "name": "wide", "position": Vector3(0.0, 2.2, 17.5),
		"target": Vector3(0.0, 0.8, 24.0), "fov": 72.0, "detail_chair": 3 },
	{ "name": "transverse", "position": Vector3(-5.45, 1.55, 20.0),
		"target": Vector3(-3.2, 0.85, 21.45), "fov": 54.0, "detail_chair": 6 },
]
const CAMERA_POSITION := Vector3(3.0, 0.72, 18.20)
const CAMERA_TARGET := Vector3(5.55, 0.22, 23.30)

var _failures: Array[String] = []
var _camera: Camera3D
var _common_chairs := false
var _output_dir := OUTPUT_DIR


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_common_chairs = OS.get_cmdline_user_args().has("--common-chairs")
	var external_output := OS.get_environment(OUTPUT_ENV)
	if not external_output.is_empty():
		_check(external_output.is_absolute_path()
			and DirAccess.dir_exists_absolute(external_output)
			and FileAccess.get_unix_permissions(external_output) == 448,
			"external capture output is an existing private0700 absolute directory")
		if not _failures.is_empty():
			_finish()
			return
		var output_access := DirAccess.open(external_output)
		if output_access != null:
			output_access.include_hidden = true
		_check(output_access != null and output_access.get_files().is_empty()
			and output_access.get_directories().is_empty(),
			"external capture output is empty, including hidden entries")
		if not _failures.is_empty():
			_finish()
			return
		_output_dir = external_output
	root.size = RESOLUTION
	root.content_scale_size = Vector2i.ZERO
	root.use_taa = false
	root.msaa_3d = Viewport.MSAA_DISABLED
	root.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	_check(
		RenderingServer.get_current_rendering_method() == &"forward_plus"
			and DisplayServer.get_name() == "X11"
			and not RenderingServer.get_video_adapter_name().is_empty(),
		"capture has an X11 Forward+ rendering device; native GPU qualification is separate"
	)

	var stage := Node3D.new()
	stage.name = "HabitatMessTrestleReviewStage"
	root.add_child(stage)
	_build_environment(stage)
	var habitat := MODULE_SCENE.instantiate() as HabitatSpine
	_check(habitat != null, "production Habitat Spine instantiates")
	if habitat == null:
		_finish()
		return
	stage.add_child(habitat)
	await process_frame
	await physics_frame

	if _common_chairs:
		_check_chair_frame_budget()
		if not _failures.is_empty():
			stage.queue_free()
			await process_frame
			_finish()
			return
		await _capture_common_chairs(stage, habitat)
		stage.queue_free()
		await process_frame
		_finish()
		return

	var mess := habitat.get_node_or_null(
		^"Structure/ObservationCommon/CommonMess"
	) as Node3D
	var batch := mess.get_node_or_null(^"MessTrestleFeet") as MultiMeshInstance3D \
		if mess != null else null
	_check(
		batch != null and batch.multimesh != null
			and batch.multimesh.instance_count
				== HabitatSpine.MESS_TRESTLE_FOOT_COPY_COUNT,
		"production mess owns the exact two-copy trestle-foot batch"
	)
	if batch == null or batch.multimesh == null:
		_finish()
		return

	var baseline := Node3D.new()
	baseline.name = "BeforeIndividualTrestleFeet"
	mess.add_child(baseline)
	var authored := batch.get_meta(&"authored_instance_transforms", []) as Array
	for index in authored.size():
		var renderer := MeshInstance3D.new()
		renderer.name = "BeforeMessTrestleFoot%02d" % (index + 1)
		renderer.mesh = batch.multimesh.mesh
		renderer.material_override = batch.material_override
		renderer.transform = authored[index] as Transform3D
		renderer.cast_shadow = batch.cast_shadow
		renderer.layers = batch.layers
		baseline.add_child(renderer)

	_camera = Camera3D.new()
	_camera.name = "HabitatMessTrestleCaptureCamera"
	_camera.position = CAMERA_POSITION
	_camera.near = 0.06
	_camera.far = 80.0
	_camera.fov = 38.0
	stage.add_child(_camera)
	_camera.look_at(CAMERA_TARGET, Vector3.UP)
	_camera.current = true
	_check(
		_camera.position.distance_to(CAMERA_TARGET) > 5.5
			and _camera.position.distance_to(CAMERA_TARGET) < 6.0,
		"fixed common-room camera remains at gameplay review distance"
	)

	batch.visible = false
	baseline.visible = true
	var before := await _capture(_output_dir.path_join(BEFORE_PATH.get_file()))
	baseline.visible = false
	batch.visible = true
	var after := await _capture(_output_dir.path_join(AFTER_PATH.get_file()))
	_check(
		before != null and after != null and before.get_data() == after.get_data(),
		"individual and batched trestle-foot frames are pixel-identical"
	)
	if before != null and after != null:
		var region := _foot_region()
		var before_region := before.get_region(region)
		var after_region := after.get_region(region)
		_check(
			before_region.get_data() == after_region.get_data()
				and _region_has_visible_detail(before_region),
			"bounded mess-table foot region remains visible and pixel-identical"
		)

	stage.queue_free()
	await process_frame
	_finish()


## Reconstruct the eight merged source renderers from the authored-piece index.
## The original Back/Mesh remains visible and unchanged in both states. These source Mesh references are independent of the baked ArrayMesh;
## drawing the baked mesh twice would hide a geometry/normal/UV bake error.
func _capture_common_chairs(stage: Node3D, habitat: HabitatSpine) -> void:
	var common := habitat.get_node_or_null(^"Structure/ObservationCommon") as Node3D
	_check(common != null, "production observation common room exists")
	if common == null:
		return
	var chairs: Array[Node3D] = []
	var baselines: Array[Node3D] = []
	var renderers: Array[MeshInstance3D] = []
	var retained_backs: Array[MeshInstance3D] = []
	var back_pose := Node3D.new()
	back_pose.position = Vector3(0.0, 1.43, -0.38)
	back_pose.rotation_degrees = Vector3(-6.0, 0.0, 0.0)
	var original_back_transform := back_pose.transform
	back_pose.free()
	var back_size := Vector3(0.92, 1.28, 0.2)
	var original_back_cache: Dictionary = {}
	var original_back_mesh := StationSurfaceKit.rounded_box_mesh_with_bevel_cached(
		back_size, StationSurfaceKit.proportional_bevel_for_size(back_size, 0.18),
		original_back_cache, StationSurfaceKit.BevelUV.UNIT_PER_QUAD
	)
	var palette := habitat.get("_materials") as Dictionary
	var back_material := palette.get("observation_backrest") as Material
	var shared_mesh: Mesh
	for index in 8:
		var chair := common.get_node_or_null(NodePath("CommonChair%02d" % (index + 1))) as Node3D
		_check(chair != null, "common chair %02d retains its authored root" % (index + 1))
		if chair == null:
			return
		chairs.append(chair)
		var indexed: Array[MeshInstance3D] = []
		for child in chair.get_children():
			if child is MeshInstance3D \
					and StationDressingBatch.authored_piece_index(child).size() == 8:
				indexed.append(child as MeshInstance3D)
		_check(indexed.size() == 1
			and chair.find_children("*", "MeshInstance3D", true, false).size() == 2,
			"common chair %02d has one eight-piece indexed renderer and its retained Back mesh" % (index + 1))
		if indexed.size() != 1:
			return
		var visual := indexed[0]
		_check(visual.mesh is ArrayMesh and visual.mesh.get_surface_count() == 5,
			"common chair %02d draws the five-surface production mesh" % (index + 1))
		if index == 0:
			shared_mesh = visual.mesh
		else:
			_check(visual.mesh == shared_mesh, "common chairs share one module-local mesh")
		renderers.append(visual)
		var back_body := chair.get_node_or_null(^"Back") as StaticBody3D
		var back_visual := chair.get_node_or_null(^"Back/Mesh") as MeshInstance3D
		_check(back_body != null and back_visual != null and back_visual.mesh != null,
			"common chair %02d retains the original Back StaticBody/Mesh path" % (index + 1))
		if back_body == null or back_visual == null or back_visual.mesh == null:
			return
		var back_mesh := back_visual.mesh as ArrayMesh
		_check(back_mesh != null, "retained Back keeps its original rounded ArrayMesh")
		if back_mesh == null:
			return
		_check(back_body.transform == original_back_transform
			and back_visual.transform == Transform3D.IDENTITY
			and back_mesh.get_surface_count() == 1
			and back_mesh.surface_get_primitive_type(0) == Mesh.PRIMITIVE_TRIANGLES
			and back_mesh.surface_get_arrays(0) == original_back_mesh.surface_get_arrays(0)
			and back_material != null and back_visual.material_override == back_material
			and back_visual.get_active_material(0) == back_material
			and back_visual.is_visible_in_tree(),
			"common chair %02d keeps the original backrest geometry, material and local pose" % (index + 1))
		retained_backs.append(back_visual)
		var baseline := Node3D.new()
		baseline.name = "BeforeIndividualChairPieces"
		chair.add_child(baseline)
		baselines.append(baseline)
		for record_variant in StationDressingBatch.authored_piece_index(visual):
			var record := record_variant as Dictionary
			_check(String(record.get("name", "")) != "Back", "indexed pieces exclude the retained Back")
			var source_mesh := record.get("mesh") as Mesh
			var materials := record.get("materials", []) as Array
			_check(source_mesh != null and source_mesh != visual.mesh
				and materials.size() == source_mesh.get_surface_count()
				and record.get("transform") is Transform3D,
				"indexed chair piece retains its independent source mesh, materials and chair-local placement")
			if source_mesh == null or source_mesh == visual.mesh \
					or materials.size() != source_mesh.get_surface_count() \
					or not record.get("transform") is Transform3D:
				return
			var before_piece := MeshInstance3D.new()
			before_piece.name = "Before" + String(record.get("name", "ChairPiece"))
			before_piece.mesh = source_mesh
			before_piece.transform = record["transform"] as Transform3D
			before_piece.visible = bool(record.get("visible", true))
			before_piece.cast_shadow = int(record.get("cast_shadow", visual.cast_shadow))
			before_piece.gi_mode = int(record.get("gi_mode", visual.gi_mode))
			before_piece.layers = visual.layers
			for surface in materials.size():
				before_piece.set_surface_override_material(surface, materials[surface] as Material)
			baseline.add_child(before_piece)
	_check(chairs.size() == 8 and baselines.size() == 8 and renderers.size() == 8
		and retained_backs.size() == 8,
		"capture compares64 original pieces with8 batches, retaining the same8 Back meshes")
	if not _failures.is_empty():
		return
	_camera = Camera3D.new()
	_camera.name = "HabitatCommonChairCaptureCamera"
	_camera.near = 0.06
	_camera.far = 80.0
	stage.add_child(_camera)
	_camera.current = true
	for view: Dictionary in COMMON_CHAIR_VIEWS:
		_camera.position = view["position"] as Vector3
		_camera.fov = float(view["fov"])
		_camera.look_at(view["target"] as Vector3, Vector3.UP)
		for visual in renderers:
			visual.visible = false
		for baseline in baselines:
			baseline.visible = true
		var view_name := String(view["name"])
		for back_visual in retained_backs:
			_check(back_visual.is_visible_in_tree(), "retained Back stays visible in the original-piece frame")
		var before := await _capture(_output_dir.path_join("before_individual_chairs_%s.png" % view_name))
		for baseline in baselines:
			baseline.visible = false
		for visual in renderers:
			visual.visible = true
		for back_visual in retained_backs:
			_check(back_visual.is_visible_in_tree(), "retained Back stays visible in the batched frame")
		var after := await _capture(_output_dir.path_join("after_batched_chairs_%s.png" % view_name))
		_check(_chair_frames_match(before, after),
			"original primitive and per-chair batched %s full frames meet the one-code RGB budget" % view_name)
		if before != null and after != null:
			var detail_chair := chairs[int(view["detail_chair"])]
			var center_world := detail_chair.to_global(Vector3(0.0, 0.9, 0.0))
			var center := _camera.unproject_position(center_world)
			_check(not _camera.is_position_behind(center_world)
				and Rect2(Vector2.ZERO, Vector2(RESOLUTION)).has_point(center),
				"fixed %s view includes its actual chair detail region" % view_name)
			var region := _chair_region(center)
			var before_region := before.get_region(region)
			var after_region := after.get_region(region)
			_check(before_region.get_data() == after_region.get_data()
				and _region_has_visible_detail(before_region),
				"bounded %s chair region is visible and pixel-identical" % view_name)


## This is an explicit output-quantization budget, not proof that quantization
## uniquely caused the earlier strict mismatch. Every RGB8/RGBA8 pixel/channel
## is checked as stored: no conversion, percentage or spatial exemption. Alpha
## stays exact. Bounded chair details and all trestle comparisons stay byte-exact;
## this budget does not establish native-GPU or human visual qualification.
func _chair_frames_match(before: Image, after: Image, report: bool = true) -> bool:
	if before == null or after == null or before.get_size() != after.get_size() \
			or before.get_format() != after.get_format() \
			or before.get_format() not in [Image.FORMAT_RGB8, Image.FORMAT_RGBA8]:
		if report:
			print("HABITAT_COMMON_CHAIRS_FRAME_BUDGET: rejected size/format/null")
		return false
	var channels := 3 if before.get_format() == Image.FORMAT_RGB8 else 4
	var left := before.get_data()
	var right := after.get_data()
	var expected_bytes := before.get_width() * before.get_height() * channels
	if left.size() != expected_bytes or right.size() != expected_bytes:
		if report:
			print("HABITAT_COMMON_CHAIRS_FRAME_BUDGET: rejected byte layout")
		return false
	var changed_pixels := 0
	var maximum_rgb_delta := 0
	var alpha_exact := true
	for offset in range(0, expected_bytes, channels):
		var changed := false
		for channel in 3:
			var difference := absi(int(left[offset + channel]) - int(right[offset + channel]))
			maximum_rgb_delta = maxi(maximum_rgb_delta, difference)
			changed = changed or difference != 0
		if channels == 4 and left[offset + 3] != right[offset + 3]:
			alpha_exact = false
			changed = true
		if changed:
			changed_pixels += 1
	if report:
		print("HABITAT_COMMON_CHAIRS_FRAME_BUDGET: changed_pixels=", changed_pixels,
			" max_rgb_code_delta=", maximum_rgb_delta, " alpha_exact=", alpha_exact)
	return maximum_rgb_delta <= 1 and alpha_exact


func _check_chair_frame_budget() -> void:
	for format in [Image.FORMAT_RGB8, Image.FORMAT_RGBA8]:
		var channels := 3 if format == Image.FORMAT_RGB8 else 4
		var pixels := PackedByteArray()
		pixels.resize(4 * channels)
		pixels.fill(64)
		var original := Image.create_from_data(2, 2, false, format, pixels)
		_check(_chair_frames_match(original, original, false),
			"chair RGB/RGBA budget accepts synthetic2x2 identity")
		var one_code := pixels.duplicate()
		for offset in range(0, one_code.size(), channels):
			one_code[offset] += 1
			one_code[offset + 1] -= 1
			one_code[offset + 2] += 1
		_check(_chair_frames_match(original,
			Image.create_from_data(2, 2, false, format, one_code), false),
			"chair RGB/RGBA budget accepts one code per RGB channel at every pixel")
		var two_codes := pixels.duplicate()
		two_codes[two_codes.size() - channels + 2] += 2
		_check(not _chair_frames_match(original,
			Image.create_from_data(2, 2, false, format, two_codes), false),
			"chair RGB/RGBA budget rejects a two-code RGB delta even at the last pixel")
		if format == Image.FORMAT_RGBA8:
			var changed_alpha := pixels.duplicate()
			changed_alpha[3] += 1
			_check(not _chair_frames_match(original,
				Image.create_from_data(2, 2, false, format, changed_alpha), false),
				"chair RGBA budget rejects a one-code alpha delta")
		var other_size := PackedByteArray()
		other_size.resize(2 * channels)
		other_size.fill(64)
		_check(not _chair_frames_match(original,
			Image.create_from_data(1, 2, false, format, other_size), false),
			"chair RGB/RGBA budget rejects a dimension mismatch")
	var rgb := Image.create(2, 2, false, Image.FORMAT_RGB8)
	var rgba := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	_check(not _chair_frames_match(rgb, rgba, false),
		"chair budget rejects a RGB/RGBA format mismatch")
	var unsupported := Image.create(2, 2, false, Image.FORMAT_RGBF)
	_check(not _chair_frames_match(unsupported, unsupported, false),
		"chair budget rejects unsupported formats even with identical pixels")


func _chair_region(center: Vector2) -> Rect2i:
	var top_left := Vector2i((center - Vector2(70.0, 110.0)).floor())
	var bottom_right := Vector2i((center + Vector2(70.0, 110.0)).ceil())
	top_left.x = clampi(top_left.x, 0, RESOLUTION.x - 1)
	top_left.y = clampi(top_left.y, 0, RESOLUTION.y - 1)
	bottom_right.x = clampi(bottom_right.x, top_left.x + 1, RESOLUTION.x)
	bottom_right.y = clampi(bottom_right.y, top_left.y + 1, RESOLUTION.y)
	return Rect2i(top_left, bottom_right - top_left)


func _capture(path: String) -> Image:
	for _frame in 16:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_check(
		image != null and not image.is_empty() and image.get_size() == RESOLUTION,
		"capture returns a stable 1600x900 renderer frame"
	)
	if image == null or image.is_empty():
		return null
	var absolute := ProjectSettings.globalize_path(path)
	if _output_dir != OUTPUT_DIR and FileAccess.file_exists(absolute):
		_check(false, "external capture refuses to overwrite an existing image")
		return null
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	_check(image.save_png(absolute) == OK, "capture frame saves successfully")
	print("HABITAT_MESS_TRESTLE_CAPTURE: ", absolute)
	return image


func _foot_region() -> Rect2i:
	var centers := [
		_camera.unproject_position(Vector3(5.55, 0.035, 22.45)),
		_camera.unproject_position(Vector3(5.55, 0.035, 24.15)),
	]
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for center in centers:
		minimum = minimum.min(center - Vector2(55.0, 44.0))
		maximum = maximum.max(center + Vector2(55.0, 44.0))
	var top_left := Vector2i(minimum.floor())
	var bottom_right := Vector2i(maximum.ceil())
	top_left.x = clampi(top_left.x, 0, RESOLUTION.x - 1)
	top_left.y = clampi(top_left.y, 0, RESOLUTION.y - 1)
	bottom_right.x = clampi(bottom_right.x, top_left.x + 1, RESOLUTION.x)
	bottom_right.y = clampi(bottom_right.y, top_left.y + 1, RESOLUTION.y)
	return Rect2i(top_left, bottom_right - top_left)


func _region_has_visible_detail(image: Image) -> bool:
	if image == null or image.is_empty():
		return false
	var minimum := Vector3(INF, INF, INF)
	var maximum := Vector3(-INF, -INF, -INF)
	for y in range(0, image.get_height(), 3):
		for x in range(0, image.get_width(), 3):
			var pixel := image.get_pixel(x, y)
			minimum = minimum.min(Vector3(pixel.r, pixel.g, pixel.b))
			maximum = maximum.max(Vector3(pixel.r, pixel.g, pixel.b))
	return (maximum - minimum).length() > 0.10


func _build_environment(stage: Node3D) -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("061019")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("7894a5")
	environment.ambient_light_energy = 0.38
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.glow_enabled = false
	world_environment.environment = environment
	stage.add_child(world_environment)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-47.0, -36.0, 0.0)
	key.light_color = Color("ffe1bb")
	key.light_energy = 1.55
	key.shadow_enabled = true
	stage.add_child(key)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	_failures.append(message)
	push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		if _common_chairs:
			print("HABITAT_COMMON_CHAIRS_CAPTURE_OK")
		else:
			print("HABITAT_MESS_TRESTLE_CAPTURE_OK")
		quit(0)
		return
	print("HABITAT_MESS_TRESTLE_CAPTURE_FAILED: ", "; ".join(_failures))
	quit(1)
