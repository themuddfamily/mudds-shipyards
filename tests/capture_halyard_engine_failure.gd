extends SceneTree

## Rendered comparison for Halyard's engine isolation vane. This is deliberately
## not a test: it drives damage only through HeroShip.apply_damage, photographs
## the production scene, and writes disposable review frames outside the repo.

const HALYARD_SCENE := preload("res://scenes/ships/halyard_crew_transport.tscn")
const ComponentDamage := preload("res://scripts/combat/ship_component_damage.gd")
const OUTPUT_DIR := "/tmp/mudds-wave31-halyard-engine-failure"

var _viewport: SubViewport
var _camera: Camera3D


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 720)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.msaa_3d = Viewport.MSAA_2X
	root.add_child(_viewport)

	var world := Node3D.new()
	_viewport.add_child(world)
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("07121d")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("82a7ba")
	environment.ambient_light_energy = 0.42
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.glow_enabled = false
	world_environment.environment = environment
	world.add_child(world_environment)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-32.0, -28.0, 0.0)
	key.light_color = Color("ffe2ba")
	key.light_energy = 1.7
	key.shadow_enabled = true
	world.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(18.0, 150.0, 0.0)
	fill.light_color = Color("69aaca")
	fill.light_energy = 0.8
	world.add_child(fill)

	var craft := HALYARD_SCENE.instantiate() as HalyardCrewTransport
	world.add_child(craft)
	craft.set("_landed", false)
	_camera = Camera3D.new()
	world.add_child(_camera)
	_camera.position = Vector3(14.5, 8.8, 31.0)
	_camera.look_at(Vector3(0.0, 2.2, 10.4), Vector3.UP)
	_camera.fov = 43.0
	_camera.current = true
	await _frames(6)

	var engine_position := _component_local_position(craft)
	craft.apply_damage(
		craft.maximum_hull * 0.10,
		craft.to_global(engine_position),
		craft.global_basis.z
	)
	await _frames(4)
	await _capture("halyard_engine_impaired.png")

	craft.apply_damage(
		craft.maximum_hull * 0.10,
		craft.to_global(engine_position),
		craft.global_basis.z
	)
	await _frames(4)
	await _capture("halyard_engine_failed.png")

	print("CAPTURE_HALYARD_ENGINE_FAILURE_OK: ", OUTPUT_DIR)
	quit(0)


func _component_local_position(craft: HalyardCrewTransport) -> Vector3:
	for component_variant in craft.get_component_damage_report().get("components", []) as Array:
		var component := component_variant as Dictionary
		if StringName(component.get("id", &"")) == ComponentDamage.COMPONENT_ENGINE_BAY:
			return component.get("local_position", Vector3.ZERO) as Vector3
	return Vector3.ZERO


func _capture(file_name: String) -> void:
	# SubViewport is already UPDATE_ALWAYS and the harness settles four process
	# frames before each read. Avoid waiting on frame_post_draw: that signal is
	# not emitted by every CI/headless display backend.
	var image := _viewport.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("capture produced no image: " + file_name)
		quit(1)
		return
	var output_path := OUTPUT_DIR.path_join(file_name)
	var error := image.save_png(output_path)
	if error != OK:
		push_error("capture save failed: " + output_path)
		quit(1)
		return
	print("CAPTURED: ", output_path)


func _frames(count: int) -> void:
	for _index in count:
		await process_frame
