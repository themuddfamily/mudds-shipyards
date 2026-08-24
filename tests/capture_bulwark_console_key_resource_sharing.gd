extends SceneTree

## Native Forward+ capture of two production Bulwarks at one identical cockpit
## pose. Both craft remain alive so the second frame exercises the shared mesh;
## only their capture-stage positions swap. Pixel identity proves that the static
## material-free geometry does not leak either craft's cyan/amber overrides.

const Ship := preload("res://scripts/ships/bulwark_heavy_gunship.gd")
const RESOLUTION := Vector2i(1280, 720)
const OUTPUT_DIR := "res://artifacts/bulwark_console_key_resource_sharing"
const FIRST_PATH := OUTPUT_DIR + "/craft_a_console.png"
const SECOND_PATH := OUTPUT_DIR + "/craft_b_console.png"
const KEY_NAMES := [
	"PortConsoleKey00",
	"PortConsoleKey01",
	"PortConsoleKey02",
	"StarboardConsoleKey00",
	"StarboardConsoleKey01",
	"StarboardConsoleKey02",
]
const OFFSTAGE_POSITION := Vector3(80.0, 0.0, 0.0)

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = RESOLUTION
	root.content_scale_size = Vector2i.ZERO
	root.use_taa = false
	root.msaa_3d = Viewport.MSAA_DISABLED
	_check(
		RenderingServer.get_current_rendering_method() == &"forward_plus"
		and DisplayServer.get_name() == "X11"
		and not RenderingServer.get_video_adapter_name().is_empty(),
		"capture has a native X11 Forward+ rendering device"
	)

	var stage := Node3D.new()
	stage.name = "BulwarkConsoleKeyCaptureStage"
	root.add_child(stage)
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("05090e")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("8ea0b2")
	environment.ambient_light_energy = 0.48
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	world_environment.environment = environment
	stage.add_child(world_environment)

	var key_light := DirectionalLight3D.new()
	key_light.light_color = Color("fff3df")
	key_light.light_energy = 1.7
	key_light.shadow_enabled = false
	key_light.rotation_degrees = Vector3(-52.0, 22.0, 0.0)
	stage.add_child(key_light)

	var craft_a := Ship.new() as HeroShip
	var craft_b := Ship.new() as HeroShip
	craft_a.name = "CaptureBulwarkA"
	craft_b.name = "CaptureBulwarkB"
	craft_b.position = OFFSTAGE_POSITION
	stage.add_child(craft_a)
	stage.add_child(craft_b)
	await process_frame
	craft_a.set_canopy_open(true, 0.0)
	craft_b.set_canopy_open(true, 0.0)
	_isolate_cockpit(craft_a)
	_isolate_cockpit(craft_b)
	craft_a.set_process(false)
	craft_a.set_physics_process(false)
	craft_b.set_process(false)
	craft_b.set_physics_process(false)

	var camera := Camera3D.new()
	camera.name = "BulwarkConsoleKeyCaptureCamera"
	camera.position = Vector3(0.0, 4.2, -0.56)
	camera.fov = 45.0
	camera.near = 0.05
	camera.far = 140.0
	stage.add_child(camera)
	camera.look_at(Vector3(0.0, 2.4, -0.56), Vector3.FORWARD)
	camera.current = true

	_check_key_resources(craft_a, craft_b)
	var first := await _capture(FIRST_PATH)
	craft_a.position = -OFFSTAGE_POSITION
	craft_b.position = Vector3.ZERO
	var second := await _capture(SECOND_PATH)
	_check(
		first != null and second != null and first.get_data() == second.get_data(),
		"two live Bulwarks produce pixel-identical cockpit frames at the same pose"
	)
	if first != null:
		var colors := _count_identity_pixels(first)
		_check(
			int(colors.cyan) >= 20 and int(colors.amber) >= 20,
			"captured console retains visible cyan and amber identity pixels"
		)
		print(
			"BULWARK_CONSOLE_KEY_CAPTURE_PIXELS cyan=%d amber=%d" % [
				int(colors.cyan), int(colors.amber)
			]
		)

	stage.queue_free()
	await process_frame
	_finish()


func _check_key_resources(craft_a: HeroShip, craft_b: HeroShip) -> void:
	var shared_mesh: Mesh
	var valid := true
	for craft in [craft_a, craft_b]:
		var cockpit := craft.get_node_or_null(
			^"BulwarkHeavyGunshipVisual/CockpitInterior"
		) as Node3D
		valid = valid and cockpit != null
		if cockpit == null:
			continue
		for index in KEY_NAMES.size():
			var key := cockpit.get_node_or_null(NodePath(KEY_NAMES[index])) as MeshInstance3D
			valid = valid and key != null
			if key == null:
				continue
			shared_mesh = key.mesh if shared_mesh == null else shared_mesh
			var material := key.material_override as StandardMaterial3D
			var amber := index == 1 or index == 4
			valid = valid and key.mesh == shared_mesh \
				and material != null and material.emission_enabled \
				and material.emission.is_equal_approx(
					Color("e2a63c") if amber else Color("48dbe2")
				)
	_check(
		valid and shared_mesh != null and shared_mesh.surface_get_material(0) == null,
		"both craft share only material-free console geometry and retain six overrides"
	)


func _isolate_cockpit(craft: HeroShip) -> void:
	# Bulwark's armored slab correctly encloses the inherited cockpit. The capture
	# stage hides only exterior presentation siblings so the unchanged production
	# console can be inspected without altering its renderers or materials.
	var visual := craft.get_node_or_null(^"BulwarkHeavyGunshipVisual") as Node3D
	var cockpit := visual.get_node_or_null(^"CockpitInterior") as Node3D \
		if visual != null else null
	if visual == null or cockpit == null:
		return
	for child in visual.get_children():
		if child is Node3D and child != cockpit:
			(child as Node3D).visible = false


func _capture(path: String) -> Image:
	for _frame in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_check(
		image != null and not image.is_empty() and image.get_size() == RESOLUTION,
		"capture returns a stable 1280x720 renderer frame"
	)
	if image == null or image.is_empty():
		return null
	var absolute := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	_check(image.save_png(absolute) == OK, "capture frame saves successfully")
	print("BULWARK_CONSOLE_KEY_CAPTURE: ", absolute)
	return image


func _count_identity_pixels(image: Image) -> Dictionary:
	var counts := {"cyan": 0, "amber": 0}
	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			if pixel.g > 0.42 and pixel.b > 0.42 and pixel.r < pixel.g * 0.82:
				counts.cyan = int(counts.cyan) + 1
			if pixel.r > 0.52 and pixel.g > 0.28 and pixel.b < pixel.r * 0.58:
				counts.amber = int(counts.amber) + 1
	return counts


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	_failures.append(message)
	push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("BULWARK_CONSOLE_KEY_RESOURCE_SHARING_CAPTURE_OK")
		quit(0)
		return
	print("BULWARK_CONSOLE_KEY_RESOURCE_SHARING_CAPTURE_FAILED: ", "; ".join(_failures))
	quit(1)
