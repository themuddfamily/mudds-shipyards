extends SceneTree

## One bounded review frame of the real Halyard cabin from the centre aisle,
## 4.5 m from its existing optional loadmaster station.

const OUTPUT_PATH := "res://artifacts/halyard_loadmaster_role_readability.png"
const HALYARD_SCENE := preload("res://scenes/ships/halyard_crew_transport.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_2X
	root.add_child(viewport)

	var world := Node3D.new()
	viewport.add_child(world)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("07111d")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("b8c8c3")
	settings.ambient_light_energy = 0.32
	environment.environment = settings
	world.add_child(environment)

	var craft := HALYARD_SCENE.instantiate() as HalyardCrewTransport
	world.add_child(craft)
	await process_frame
	await physics_frame
	await physics_frame

	var anchor := craft.get_loadmaster_station_anchor()
	var panel := craft.get_node_or_null(^"LoadmasterStationWayfindingPanel") as MeshInstance3D
	if anchor == null or panel == null:
		push_error("loadmaster plaque unavailable")
		quit(1)
		return

	var camera := Camera3D.new()
	camera.near = 0.05
	camera.fov = 68.0
	camera.current = true
	world.add_child(camera)
	var plaque_position := panel.global_position
	var aisle_direction := anchor.global_basis.orthonormalized() * Vector3(0.0, 0.0, 1.0)
	camera.global_position = plaque_position + aisle_direction \
			* HalyardCrewTransport.LOADMASTER_WAYFINDING_READABILITY_DISTANCE_M \
			+ Vector3(1.30, -0.48, 0.0)
	camera.look_at(plaque_position, Vector3.UP)

	for _frame in 10:
		await process_frame
		await physics_frame
	var image := viewport.get_texture().get_image()
	var result := image.save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	if result != OK:
		push_error("failed to save loadmaster readability capture: %s" % error_string(result))
		quit(1)
		return
	print("HALYARD_LOADMASTER_ROLE_CAPTURE_OK: %s" % OUTPUT_PATH)
	quit(0)
