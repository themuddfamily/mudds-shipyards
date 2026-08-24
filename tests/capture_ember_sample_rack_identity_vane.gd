extends SceneTree

## Focused gameplay-distance review frame for the passive Ember sample-rack
## identity vane. The harness owns its camera/environment only; none is added
## to the production landmark.

const EmberScene := preload("res://scenes/world/planets/ember_moon.tscn")
const OUTPUT_PATH := "user://screenshots/ember_sample_rack_identity_vane.png"


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(1600, 900)
	var world := Node3D.new()
	root.add_child(world)
	var ember := EmberScene.instantiate() as Node3D
	world.add_child(ember)

	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("08090d")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("535a66")
	settings.ambient_light_energy = 0.32
	environment.environment = settings
	world.add_child(environment)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color("ffd1a6")
	sun.light_energy = 1.65
	sun.shadow_enabled = true
	sun.rotation = Vector3(-0.82, -0.58, 0.0)
	world.add_child(sun)

	var camera := Camera3D.new()
	camera.position = Vector3(3.0, 120_004.0, 13.0)
	camera.fov = 62.0
	camera.current = true
	world.add_child(camera)
	camera.look_at(Vector3(28.0, 120_002.2, -7.0), Vector3.UP)

	for _frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("user://screenshots")
	)
	var image := root.get_texture().get_image()
	var error := image.save_png(OUTPUT_PATH)
	print(
		"EMBER_SAMPLE_RACK_IDENTITY_VANE_CAPTURE_%s: %s"
		% ["OK" if error == OK else "FAILED", ProjectSettings.globalize_path(OUTPUT_PATH)]
	)
	quit(0 if error == OK else 1)
