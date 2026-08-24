extends SceneTree

## Two bounded Forward+ review frames for the Arrow's modern provisional recon
## crown. These are stable gameplay-distance views, not an evidence harness:
## one rear chase composition and one starboard flank composition.

const ARROW_SCENE := preload("res://scenes/ships/arrow_recon_ship.tscn")
const OUTPUT_DIR := "res://artifacts/arrow_recon_crown"
const CAPTURE_RESOLUTION := Vector2i(1600, 900)
const SHIP_TARGET := Vector3(0.0, 1.25, 0.15)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	root.size = CAPTURE_RESOLUTION
	root.content_scale_size = Vector2i.ZERO
	root.use_taa = true
	root.msaa_3d = Viewport.MSAA_2X

	var world := Node3D.new()
	world.name = "ArrowReconCrownCaptureWorld"
	root.add_child(world)
	_install_environment(world)

	var arrow := ARROW_SCENE.instantiate() as ArrowReconShip
	world.add_child(arrow)
	await process_frame
	await physics_frame
	await physics_frame
	arrow.set_physics_process(false)

	var camera := Camera3D.new()
	camera.name = "ReviewCamera"
	camera.near = 0.05
	camera.far = 180.0
	camera.fov = 54.0
	camera.current = true
	world.add_child(camera)

	# Rear three-quarter chase framing: 25.6 m from the hull centre, within the
	# production Arrow's 11–28 m chase-camera range.
	camera.position = Vector3(9.0, 7.0, 23.0)
	camera.look_at(SHIP_TARGET, Vector3.UP)
	await _settle(10)
	if not _save_frame("01_chase_gameplay_distance.png"):
		quit(1)
		return

	# Starboard flank framing: 23.1 m from the hull centre. A slight aft bias
	# keeps both orthogonal apertures visible against the dark background.
	camera.position = Vector3(22.0, 5.8, 6.2)
	camera.look_at(Vector3(0.0, 1.65, 0.65), Vector3.UP)
	await _settle(8)
	if not _save_frame("02_flank_gameplay_distance.png"):
		quit(1)
		return

	print("ARROW_RECON_CROWN_CAPTURE_OK: %s" % OUTPUT_DIR)
	quit(0)


func _install_environment(world: Node3D) -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("06101b")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("8fa9c0")
	settings.ambient_light_energy = 0.34
	settings.tonemap_mode = Environment.TONE_MAPPER_AGX
	settings.glow_enabled = true
	settings.glow_intensity = 0.55
	settings.glow_bloom = 0.08
	environment.environment = settings
	world.add_child(environment)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-42.0, -32.0, 0.0)
	key.light_color = Color("d8eaff")
	key.light_energy = 1.25
	key.shadow_enabled = true
	world.add_child(key)

	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(28.0, 142.0, 0.0)
	rim.light_color = Color("75dce5")
	rim.light_energy = 0.58
	rim.shadow_enabled = false
	world.add_child(rim)


func _settle(frame_count: int) -> void:
	for _frame in frame_count:
		await process_frame
		await physics_frame


func _save_frame(file_name: String) -> bool:
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("Arrow crown capture returned an empty image: %s" % file_name)
		return false
	var output_path := "%s/%s" % [OUTPUT_DIR, file_name]
	var result := image.save_png(ProjectSettings.globalize_path(output_path))
	if result != OK:
		push_error("Unable to save Arrow crown capture %s: %s" % [
			file_name, error_string(result),
		])
		return false
	print("CAPTURED: %s" % output_path)
	return true
