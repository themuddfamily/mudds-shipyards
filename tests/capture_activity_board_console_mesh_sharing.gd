extends SceneTree

## Same-camera Forward+ proof that sharing ActivityBoardConsole's two immutable
## readability meshes changes resource identity only. "Before" duplicates the
## production recipes per console; "after" restores the class-shared resources.

const CONSOLE_SCRIPT := preload("res://scripts/interaction/activity_board_console.gd")
const OUTPUT_DIR := "/tmp/mudds-wave32-activity-board-console-capture"
const CAPTURE_SIZE := Vector2i(1600, 900)

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = CAPTURE_SIZE
	root.content_scale_size = Vector2i.ZERO
	root.msaa_3d = Viewport.MSAA_4X
	root.use_taa = false
	_check(
		RenderingServer.get_current_rendering_method() == &"forward_plus"
			and DisplayServer.get_name() != &"headless",
		"capture uses a display-backed Forward+ renderer",
	)

	var stage := Node3D.new()
	stage.name = "ActivityBoardConsoleMeshSharingCapture"
	root.add_child(stage)
	_install_environment(stage)
	var consoles: Array[ActivityBoardConsole] = []
	for index in 3:
		var console := CONSOLE_SCRIPT.new() as ActivityBoardConsole
		console.name = "ActivityBoardConsole%d" % (index + 1)
		console.position = Vector3((index - 1) * 2.7, 0.0, 0.0)
		stage.add_child(console)
		consoles.append(console)
		_add_console_backplate(stage, console.position.x)
	await process_frame
	await physics_frame

	var headers: Array[MeshInstance3D] = []
	var underlines: Array[MeshInstance3D] = []
	for console in consoles:
		headers.append(console.get_node(
			^"ActivityBoardReadability/ActivityBoardHeader"
		) as MeshInstance3D)
		underlines.append(console.get_node(
			^"ActivityBoardReadability/ActivityBoardLocatorUnderline"
		) as MeshInstance3D)
	var shared_header_mesh := headers[0].mesh
	var shared_underline_mesh := underlines[0].mesh
	var node_ids := _node_ids(headers, underlines)
	var transforms := _transforms(headers, underlines)
	var material_ids := _material_ids(headers, underlines)

	_check(
		_unique_mesh_count(headers) == 1
			and _unique_mesh_count(underlines) == 1,
		"production after frame boots with two class-shared meshes",
	)
	var after := await _capture("after_shared_meshes.png")
	var after_pixels := after.get_data().duplicate() if after != null else PackedByteArray()

	# Reconstruct the old allocation topology on the same retained nodes.
	for header in headers:
		header.mesh = shared_header_mesh.duplicate() as TextMesh
	for underline in underlines:
		underline.mesh = shared_underline_mesh.duplicate() as BoxMesh
	_check(_unique_mesh_count(headers) == 3 and _unique_mesh_count(underlines) == 3,
		"before frame owns six per-console mesh resources")
	var before := await _capture("before_per_console_meshes.png")
	var before_pixels := before.get_data().duplicate() if before != null else PackedByteArray()
	_check(
		_node_ids(headers, underlines) == node_ids
			and _transforms(headers, underlines) == transforms
			and _material_ids(headers, underlines) == material_ids,
		"before and after retain the same six nodes, transforms, materials and copies",
	)
	_check(
		before != null and after != null
			and before.get_size() == CAPTURE_SIZE
			and after.get_size() == CAPTURE_SIZE
			and before_pixels == after_pixels,
		"same-camera Forward+ before and after pixels are exactly identical",
	)

	stage.queue_free()
	await process_frame
	_finish()


func _install_environment(stage: Node3D) -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("050a12")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("7890a7")
	environment.ambient_light_energy = 0.7
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.glow_enabled = true
	environment.glow_intensity = 0.2
	world_environment.environment = environment
	stage.add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38.0, 18.0, 0.0)
	sun.light_color = Color("ffe0bd")
	sun.light_energy = 2.1
	stage.add_child(sun)


func _add_console_backplate(stage: Node3D, x_position: float) -> void:
	var plate := MeshInstance3D.new()
	plate.position = Vector3(x_position, 1.0, -0.06)
	plate.rotation_degrees = Vector3(-12.0, 0.0, 0.0)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(2.15, 1.65, 0.16)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("162635")
	material.metallic = 0.58
	material.roughness = 0.34
	mesh.material = material
	plate.mesh = mesh
	stage.add_child(plate)


func _capture(file_name: String) -> Image:
	var camera := root.get_node_or_null(^"EvidenceCamera") as Camera3D
	if camera == null:
		camera = Camera3D.new()
		camera.name = "EvidenceCamera"
		camera.position = Vector3(0.0, 2.5, -9.0)
		camera.fov = 45.0
		camera.near = 0.08
		camera.far = 80.0
		root.add_child(camera)
		camera.look_at(Vector3(0.0, 1.15, 0.0), Vector3.UP)
		camera.current = true
	for _frame in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		_failures.append("capture image is empty")
		return null
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	_check(image.save_png(OUTPUT_DIR.path_join(file_name)) == OK,
		"%s saves" % file_name)
	return image


func _unique_mesh_count(instances: Array[MeshInstance3D]) -> int:
	var ids := {}
	for instance in instances:
		ids[instance.mesh.get_instance_id()] = true
	return ids.size()


func _node_ids(headers: Array[MeshInstance3D], underlines: Array[MeshInstance3D]) -> Array[int]:
	var ids: Array[int] = []
	for instance in headers + underlines:
		ids.append(instance.get_instance_id())
	return ids


func _transforms(headers: Array[MeshInstance3D], underlines: Array[MeshInstance3D]) -> Array[Transform3D]:
	var values: Array[Transform3D] = []
	for instance in headers + underlines:
		values.append(instance.transform)
	return values


func _material_ids(headers: Array[MeshInstance3D], underlines: Array[MeshInstance3D]) -> Array[int]:
	var ids: Array[int] = []
	for instance in headers + underlines:
		ids.append(instance.material_override.get_instance_id())
	return ids


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("ACTIVITY_BOARD_CONSOLE_MESH_SHARING_CAPTURE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error("ACTIVITY_BOARD_CONSOLE_MESH_SHARING_CAPTURE_FAILED: %s" % failure)
	quit(1)
