extends SceneTree

const OUTPUT_DIR := "res://artifacts"
const FREIGHTER_SCENE := preload("res://scenes/ships/jovian_light_freighter.tscn")

var _failures: Array[String] = []
var _viewport: SubViewport
var _camera: Camera3D


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_viewport = SubViewport.new()
	_viewport.name = "JovianForwardEvidenceViewport"
	_viewport.size = Vector2i(1280, 720)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.msaa_3d = Viewport.MSAA_2X
	root.add_child(_viewport)
	var world := Node3D.new()
	world.name = "JovianEvidenceWorld"
	_viewport.add_child(world)

	var environment := WorldEnvironment.new()
	var resource := Environment.new()
	resource.background_mode = Environment.BG_COLOR
	resource.background_color = Color("071522")
	resource.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	resource.ambient_light_color = Color("90adc0")
	resource.ambient_light_energy = 0.34
	resource.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	resource.tonemap_mode = Environment.TONE_MAPPER_AGX
	resource.glow_enabled = true
	resource.glow_intensity = 0.28
	environment.environment = resource
	world.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-36.0, -38.0, 0.0)
	key.light_color = Color("f5e6c9")
	key.light_energy = 1.9
	key.shadow_enabled = true
	world.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(20.0, 145.0, 0.0)
	fill.light_color = Color("68a9c8")
	fill.light_energy = 0.7
	world.add_child(fill)

	var floor := StaticBody3D.new()
	floor.name = "EvidenceLandingDeck"
	floor.collision_layer = PhysicsLayers.WORLD_BODY_LAYER
	world.add_child(floor)
	var floor_mesh := MeshInstance3D.new()
	var deck_mesh := BoxMesh.new()
	deck_mesh.size = Vector3(70, 0.25, 60)
	var deck_material := StandardMaterial3D.new()
	deck_material.albedo_color = Color("182b35")
	deck_material.metallic = 0.62
	deck_material.roughness = 0.4
	deck_mesh.material = deck_material
	floor_mesh.mesh = deck_mesh
	floor_mesh.position.y = -1.43
	floor.add_child(floor_mesh)
	var floor_collision := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(70, 0.25, 60)
	floor_collision.shape = floor_box
	floor_collision.position.y = -1.43
	floor.add_child(floor_collision)
	for line_x in [-22.0, -11.0, 0.0, 11.0, 22.0]:
		var line := MeshInstance3D.new()
		var line_mesh := BoxMesh.new()
		line_mesh.size = Vector3(0.15, 0.04, 55.0)
		var line_material := StandardMaterial3D.new()
		line_material.albedo_color = Color("3bc9c1")
		line_material.emission_enabled = true
		line_material.emission = Color("1a7775")
		line_material.emission_energy_multiplier = 1.1
		line_mesh.material = line_material
		line.mesh = line_mesh
		line.position = Vector3(line_x, -1.28, 0.0)
		world.add_child(line)

	var jovian := FREIGHTER_SCENE.instantiate() as JovianLightFreighter
	world.add_child(jovian)
	await _frames(8)
	_check(jovian.get_jovian_audit_report().valid, "evidence scene uses an audited Jovian candidate")
	_camera = Camera3D.new()
	_camera.name = "EvidenceCamera"
	_camera.near = 0.08
	_camera.far = 1000.0
	world.add_child(_camera)
	_camera.current = true

	_frame_camera(Vector3(24.5, 13.5, -25.0), Vector3(0.0, 1.35, -0.5), 48.0)
	await _frames(8)
	await _capture("jovian_freighter_exterior.png")

	_frame_camera(Vector3(-18.0, 5.5, 10.0), Vector3(-4.8, 1.25, 3.0), 52.0)
	await _frames(8)
	await _capture("jovian_cargo_ramp.png")

	_frame_camera(jovian.to_global(Vector3(0.0, 2.05, 8.05)), jovian.to_global(Vector3(0.0, 1.45, -2.65)), 67.0)
	await _frames(8)
	await _capture("jovian_cargo_interior.png")

	_frame_camera(jovian.to_global(Vector3(0.0, 1.85, -6.9)), jovian.to_global(Vector3(0.0, 1.5, -2.55)), 68.0)
	await _frames(8)
	await _capture("jovian_passenger_cabin.png")

	await _dispose(world)
	if _failures.is_empty():
		print("JOVIAN_FORWARD_CAPTURES_OK: 4 rendered states")
		quit(0)
	else:
		print("JOVIAN_FORWARD_CAPTURES_FAILED: ", ", ".join(_failures))
		quit(1)


func _frame_camera(position: Vector3, target: Vector3, field_of_view: float) -> void:
	_camera.global_position = position
	_camera.look_at(target, Vector3.UP)
	_camera.fov = field_of_view


func _capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := _viewport.get_texture().get_image()
	if image == null or image.is_empty():
		_fail("%s produced no image" % file_name)
		return
	var path := "%s/%s" % [OUTPUT_DIR, file_name]
	var error := image.save_png(path)
	if error != OK:
		_fail("%s could not be saved" % file_name)
		return
	var absolute := ProjectSettings.globalize_path(path)
	var size := FileAccess.get_file_as_bytes(absolute).size()
	_check(image.get_width() == 1280 and image.get_height() == 720, "%s has target dimensions" % file_name)
	_check(size > 16384, "%s contains substantive rendered evidence" % file_name)
	print("CAPTURED: ", absolute, " (", size, " bytes)")


func _frames(count: int) -> void:
	for index in count:
		await process_frame


func _dispose(node: Node) -> void:
	node.queue_free()
	await process_frame
	await physics_frame
	await process_frame


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_fail(description)


func _fail(description: String) -> void:
	_failures.append(description)
	push_error("FAIL: " + description)
