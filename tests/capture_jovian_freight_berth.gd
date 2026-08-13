extends SceneTree

## Forward+ rendered-evidence harness for the standalone freight module.
## Outputs are intentionally written to ignored `artifacts/` rather than being
## treated as source assets.

const MODULE_SCENE := preload("res://scenes/world/modules/jovian_freight_berth.tscn")
const OUTPUT_DIR := "res://artifacts"
const CAPTURES := [
	"freight_berth_overview.png",
	"freight_control_room.png",
]

var _failures: Array[String] = []
var _images: Array[Image] = []
var _camera: Camera3D


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1400, 900)
	var renderer := RenderingServer.get_current_rendering_method()
	_check(renderer == &"forward_plus", "capture uses the real Forward+ renderer")
	var output_absolute := ProjectSettings.globalize_path(OUTPUT_DIR)
	var directory_error := DirAccess.make_dir_recursive_absolute(output_absolute)
	_check(directory_error == OK or directory_error == ERR_ALREADY_EXISTS, "capture output directory is available")

	var stage := Node3D.new()
	stage.name = "JovianFreightBerthForwardCapture"
	root.add_child(stage)
	var module := MODULE_SCENE.instantiate() as JovianFreightBerth
	stage.add_child(module)
	await process_frame
	await physics_frame

	_build_environment(stage)
	_build_lighting(stage)
	_camera = Camera3D.new()
	_camera.name = "FreightEvidenceCamera"
	_camera.fov = 52.0
	_camera.near = 0.08
	_camera.far = 700.0
	_camera.current = true
	stage.add_child(_camera)

	module.set_equipment_animation_enabled(false)
	module.advance_equipment_simulation(4.1)
	_frame(Vector3(40.0, 25.0, -12.0), Vector3(0.0, 2.4, 27.0), 52.0)
	await _wait_frames(10)
	await _capture(CAPTURES[0])

	var door := module.get_service_access()
	_check(door.interact(module), "interior evidence opens the real production StationDoor")
	await _wait_for_door_state(door, StationDoor.DoorState.OPEN, 1.5)
	_check(door.is_open() and not door.is_portal_blocked(), "interior capture uses a physically clear service portal")
	_frame(Vector3(8.8, 2.8, 34.5), Vector3(19.0, 1.8, 29.0), 55.0)
	await _wait_frames(8)
	await _capture(CAPTURES[1])
	_validate_images()

	stage.queue_free()
	await process_frame
	if _failures.is_empty():
		print("JOVIAN_FREIGHT_BERTH_CAPTURE_OK: %d Forward+ frames" % _images.size())
		quit(0)
	else:
		push_error("JOVIAN_FREIGHT_BERTH_CAPTURE_FAILED: " + "; ".join(_failures))
		quit(1)


func _build_environment(stage: Node3D) -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "FreightCaptureEnvironment"
	var environment := Environment.new()
	var sky := Sky.new()
	var sky_material := PanoramaSkyMaterial.new()
	sky_material.panorama = load("res://assets/keth-nebula.png") as Texture2D
	sky_material.filter = true
	sky_material.energy_multiplier = 0.58
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.background_energy_multiplier = 0.55
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("7bb6bd")
	environment.ambient_light_energy = 0.36
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.02
	environment.glow_enabled = true
	environment.glow_intensity = 0.42
	environment.glow_bloom = 0.07
	environment.ssao_enabled = true
	environment.ssao_radius = 2.4
	environment.ssao_intensity = 2.0
	environment.ssil_enabled = true
	environment.ssil_radius = 3.0
	environment.ssil_intensity = 0.8
	environment.fog_enabled = true
	environment.fog_light_color = Color("173843")
	environment.fog_light_energy = 0.32
	environment.fog_density = 0.0008
	environment.fog_sky_affect = 0.08
	world_environment.environment = environment
	stage.add_child(world_environment)
	root.use_taa = true
	root.msaa_3d = Viewport.MSAA_2X


func _build_lighting(stage: Node3D) -> void:
	var key := DirectionalLight3D.new()
	key.name = "FreightKeyLight"
	key.rotation_degrees = Vector3(-43.0, -34.0, 0.0)
	key.light_color = Color("d8f2f0")
	key.light_energy = 1.0
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 150.0
	stage.add_child(key)

	var rim := DirectionalLight3D.new()
	rim.name = "FreightRimLight"
	rim.rotation_degrees = Vector3(-18.0, 141.0, 0.0)
	rim.light_color = Color("4f91ad")
	rim.light_energy = 0.62
	stage.add_child(rim)

	var apron_fill := OmniLight3D.new()
	apron_fill.name = "ApronFill"
	apron_fill.position = Vector3(-5.0, 7.5, 31.0)
	apron_fill.light_color = Color("64dce2")
	apron_fill.light_energy = 1.3
	apron_fill.omni_range = 32.0
	apron_fill.shadow_enabled = false
	stage.add_child(apron_fill)


func _frame(position_value: Vector3, focus: Vector3, fov_value: float) -> void:
	_camera.position = position_value
	_camera.fov = fov_value
	_camera.look_at(focus, Vector3.UP)


func _capture(file_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		_fail("empty viewport image: " + file_name)
		return
	_check(image.get_width() >= 1280 and image.get_height() >= 720, "%s has desktop evidence resolution" % file_name)
	var range_value := _sample_luminance_range(image)
	_check(range_value >= 0.14, "%s has useful luminance range" % file_name)
	var path := "%s/%s" % [OUTPUT_DIR, file_name]
	var save_error := image.save_png(path)
	_check(save_error == OK, "%s saves successfully" % file_name)
	if save_error == OK:
		var file := FileAccess.open(path, FileAccess.READ)
		var byte_count := file.get_length() if file != null else 0
		_check(byte_count >= 140000, "%s contains substantial rendered detail" % file_name)
		print("CAPTURED: %s  %dx%d  %d bytes" % [path, image.get_width(), image.get_height(), byte_count])
	_images.append(image)


func _validate_images() -> void:
	_check(_images.size() == CAPTURES.size(), "all required freight captures were produced")
	if _images.size() != 2:
		return
	var first := _images[0]
	var second := _images[1]
	var total_difference := 0.0
	var changed := 0
	var samples := 0
	for sample_y in 24:
		var y := roundi(float(sample_y) / 23.0 * float(first.get_height() - 1))
		for sample_x in 40:
			var x := roundi(float(sample_x) / 39.0 * float(first.get_width() - 1))
			var a := first.get_pixel(x, y)
			var b := second.get_pixel(x, y)
			var difference := (absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)) / 3.0
			total_difference += difference
			if difference >= 0.035:
				changed += 1
			samples += 1
	var mean_difference := total_difference / float(samples)
	var changed_fraction := float(changed) / float(samples)
	_check(mean_difference >= 0.025 and changed_fraction >= 0.12, "overview and service-room evidence are visually distinct")
	print("CAPTURE_VARIATION: mean=%.5f changed=%.3f" % [mean_difference, changed_fraction])


func _sample_luminance_range(image: Image) -> float:
	var darkest := 1.0
	var brightest := 0.0
	for sample_y in 18:
		var y := roundi(float(sample_y) / 17.0 * float(image.get_height() - 1))
		for sample_x in 32:
			var x := roundi(float(sample_x) / 31.0 * float(image.get_width() - 1))
			var luminance := image.get_pixel(x, y).get_luminance()
			darkest = minf(darkest, luminance)
			brightest = maxf(brightest, luminance)
	return brightest - darkest


func _wait_frames(count: int) -> void:
	for _index in count:
		await process_frame


func _wait_for_door_state(door: StationDoor, expected_state: int, timeout_seconds: float) -> void:
	var timeout := create_timer(timeout_seconds)
	while is_instance_valid(door) and door.get_state() != expected_state and timeout.time_left > 0.0:
		await physics_frame
	await process_frame


func _check(condition: bool, description: String) -> void:
	if condition:
		print("CAPTURE_PASS: ", description)
	else:
		_fail(description)


func _fail(description: String) -> void:
	_failures.append(description)
	push_error("CAPTURE_FAIL: " + description)
