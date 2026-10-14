extends RefCounted

## Opt-in Forward+ image capture, separate from ordinary input/physics acceptance.
## The original suite dispatches --capture and --capture-close here so existing
## graphical harness commands retain the same image paths and readback checks.

const MODULE_SCENE := preload("res://scenes/world/modules/salvage_terrace.tscn")
const CAPTURE_PATH := "/tmp/salvage-terrace-forward-plus.png"
const CLOSE_CAPTURE_PATH := "/tmp/salvage-terrace-bevel-close.png"


func run(tree: SceneTree) -> void:
	var root := tree.root
	root.size = Vector2i(1280, 720)
	var stage := Node3D.new()
	stage.name = "SalvageTerraceForwardPlusCapture"
	root.add_child(stage)
	var module := MODULE_SCENE.instantiate() as SalvageTerrace
	stage.add_child(module)

	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("111820")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("6d8290")
	environment.ambient_light_energy = 0.48
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = environment
	stage.add_child(world_environment)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-52.0, -34.0, 0.0)
	key_light.light_energy = 1.25
	key_light.shadow_enabled = true
	stage.add_child(key_light)
	var camera := Camera3D.new()
	var close_capture := OS.get_cmdline_user_args().has("--capture-close")
	camera.position = Vector3(7.0, 1.6, -1.8) if close_capture else Vector3(45.0, 27.0, -30.0)
	camera.look_at_from_position(
		camera.position,
		Vector3(5.3, -0.15, 1.2) if close_capture else Vector3(5.0, 2.0, 9.0),
		Vector3.UP
	)
	camera.fov = 56.0
	camera.current = true
	stage.add_child(camera)

	for _frame in 10:
		await tree.process_frame
		await tree.physics_frame
	await RenderingServer.frame_post_draw
	var renderer := RenderingServer.get_current_rendering_method()
	var image := root.get_texture().get_image()
	var capture_path := CLOSE_CAPTURE_PATH if close_capture else CAPTURE_PATH
	var save_error := image.save_png(capture_path) if image != null and not image.is_empty() else ERR_CANT_CREATE
	var valid := (
		renderer == &"forward_plus"
		and image != null
		and image.get_size() == Vector2i(1280, 720)
		and save_error == OK
	)
	print("SALVAGE_TERRACE_FORWARD_PLUS_CAPTURE: ", {
		"renderer": renderer,
		"size": image.get_size() if image != null else Vector2i.ZERO,
		"path": capture_path,
		"save_error": save_error,
	})
	stage.queue_free()
	await tree.process_frame
	tree.quit(0 if valid else 1)
