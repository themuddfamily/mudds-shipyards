extends SceneTree

## Stable gameplay-distance presentation capture for the NEW Cinder bomber.
## The harness owns only its evidence camera and lighting; it does not exercise
## flight, collision, payload, berth, or gameplay authority.

const Bomber := preload("res://scripts/ships/cinder_long_range_bomber.gd")
const RESOLUTION := Vector2i(1600, 900)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var label := OS.get_environment("MUDDS_CINDER_BOMBER_CAPTURE_LABEL")
	if label.is_empty():
		label = "current"
	var output_dir := "res://artifacts/cinder_bomber_silhouette/%s" % label
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))

	root.size = RESOLUTION
	var stage := Node3D.new()
	stage.name = "CinderBomberCaptureStage"
	root.add_child(stage)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("071018")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("718ba3")
	environment.ambient_light_energy = 0.48
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	stage.add_child(world_environment)

	var key := DirectionalLight3D.new()
	key.light_color = Color("fff0d5")
	key.light_energy = 2.4
	key.rotation_degrees = Vector3(-38.0, -32.0, 0.0)
	stage.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color("6fc8ff")
	rim.light_energy = 0.72
	rim.rotation_degrees = Vector3(-10.0, 150.0, 0.0)
	stage.add_child(rim)

	var bomber := Bomber.new() as CinderLongRangeBomber
	bomber.name = "CaptureCinderLongRangeBomber"
	stage.add_child(bomber)
	bomber.set_process(false)
	bomber.set_physics_process(false)

	var camera := Camera3D.new()
	camera.name = "GameplayDistanceChaseCamera"
	camera.fov = 42.0
	camera.near = 0.1
	camera.far = 160.0
	camera.position = Vector3(17.5, 10.5, 32.0)
	camera.look_at_from_position(camera.position, Vector3(0.0, 0.45, 1.5), Vector3.UP)
	camera.current = true
	stage.add_child(camera)

	for _frame in 8:
		await process_frame
	var image := root.get_texture().get_image()
	var path := "%s/gameplay_distance_chase.png" % output_dir
	var save_error := image.save_png(ProjectSettings.globalize_path(path))
	if save_error != OK:
		push_error("Cinder bomber silhouette capture failed to save: %s" % error_string(save_error))
		quit(1)
		return
	print("CINDER_BOMBER_SILHOUETTE_CAPTURE %s" % path)
	quit(0)
