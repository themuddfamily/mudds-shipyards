extends SceneTree

## Rendered review pass for the Halyard Crew Transport.
##
## Assertions do not tell you whether a craft looks right at player eye height,
## so this harness renders the states a reviewer actually needs: the silhouette
## at distance from three attitudes, the on-foot approach, the boarding point,
## the two-station flight deck through the craft's own production cockpit camera,
## the crew cabin, the aft systems bay, and the craft parked at its live berth in
## the production station.
##
## Run headlessly with a real rasteriser:
##     godot --headless --path . --script res://tests/capture_halyard_transport.gd
##
## `modern_interpretation`. These frames are evidence about this implementation
## and about nothing historical.

const OUTPUT_DIR := "res://artifacts"
const HALYARD_SCENE := preload("res://scenes/ships/halyard_crew_transport.tscn")
const MAIN_SCENE := preload("res://scenes/main.tscn")

var _failures: Array[String] = []
var _captured := 0
var _viewport: SubViewport
var _camera: Camera3D


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_viewport = SubViewport.new()
	_viewport.name = "HalyardReviewViewport"
	_viewport.size = Vector2i(1280, 720)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.msaa_3d = Viewport.MSAA_2X
	root.add_child(_viewport)

	await _capture_staged_craft()
	await _capture_production_berth()

	_viewport.queue_free()
	_viewport = null
	await process_frame
	if _failures.is_empty():
		print("HALYARD_TRANSPORT_CAPTURES_OK: %d rendered states" % _captured)
		quit(0)
	else:
		print("HALYARD_TRANSPORT_CAPTURES_FAILED: ", ", ".join(_failures))
		quit(1)


func _capture_staged_craft() -> void:
	var world := _build_review_world()
	_viewport.add_child(world)

	var craft := HALYARD_SCENE.instantiate() as HeroShip
	world.add_child(craft)
	await process_frame
	await physics_frame
	await physics_frame
	craft.global_position = Vector3.ZERO
	# Engines running, so the four tail plumes and their lights are in frame.
	craft.request_engine_start()
	await _frames(6)

	_camera = Camera3D.new()
	_camera.name = "ReviewCamera"
	_camera.near = 0.05
	_camera.far = 2000.0
	_camera.current = true
	world.add_child(_camera)

	# 1. The at-distance read. Three-quarter from forward-port, high enough to
	#    show the bow collar, the window band and the tail yoke together.
	_frame_camera(Vector3(-34.0, 12.0, -34.0), Vector3(0.0, 2.0, -1.0), 42.0)
	await _frames(8)
	await _capture("halyard_silhouette_three_quarter.png")

	# 2. Beam-on, level, at range: the pure planform read.
	_frame_camera(Vector3(-48.0, 2.4, 0.0), Vector3(0.0, 2.0, -0.5), 34.0)
	await _frames(6)
	await _capture("halyard_silhouette_beam.png")

	# 3. Plan from above: proportion and the dorsal spine.
	_frame_camera(Vector3(0.0, 40.0, 2.0), Vector3(0.0, 1.5, -1.0), 42.0)
	await _frames(6)
	await _capture("halyard_silhouette_plan.png")

	# 4. Nose-on, low: the bow docking collar standing proud on its struts.
	_frame_camera(Vector3(-2.0, 3.0, -26.0), Vector3(0.0, 2.0, -12.0), 46.0)
	await _frames(6)
	await _capture("halyard_bow_collar.png")

	# 5. The approach, at walking eye height on the port side, from beyond the
	#    production boarding reach.
	var boarding := craft.get_boarding_position()
	_frame_camera(boarding + Vector3(0.0, 1.62, 9.6), boarding + Vector3(0.0, 1.2, 0.0), 62.0)
	await _frames(6)
	await _capture("halyard_approach_port.png")

	# 6. Standing at the boarding point itself, looking at the hatch.
	_frame_camera(boarding + Vector3(-1.9, 1.62, 3.4), craft.to_global(Vector3(-2.5, 1.5, -4.8)), 68.0)
	await _frames(6)
	await _capture("halyard_boarding_point.png")

	# 7. The port airstair and the flank window band at eye height.
	_frame_camera(craft.to_global(Vector3(-9.0, 1.7, 2.5)), craft.to_global(Vector3(-2.4, 1.6, -4.8)), 62.0)
	await _frames(6)
	await _capture("halyard_airstair_and_windows.png")

	# 8. The tail yoke and its four engines, running.
	_frame_camera(craft.to_global(Vector3(-9.0, 4.5, 21.0)), craft.to_global(Vector3(0.0, 1.6, 11.0)), 48.0)
	await _frames(6)
	await _capture("halyard_tail_yoke.png")

	# 9. The flight deck through the craft's own production cockpit camera, so
	#    what is rendered is the seated pilot's real view and not a staged one.
	var cockpit_camera := _find_cockpit_camera(craft)
	_check(cockpit_camera != null, "the transport exposes its production cockpit camera")
	if cockpit_camera != null:
		_camera.current = false
		cockpit_camera.current = true
		await _frames(6)
		await _capture("halyard_cockpit_pilot_view.png")
		cockpit_camera.current = false
		_camera.current = true

	# 10. The flight deck from behind, showing both crew stations on one deck.
	_frame_camera(craft.to_global(Vector3(0.0, 1.95, -8.8)), craft.to_global(Vector3(0.0, 1.5, -13.0)), 74.0)
	await _frames(6)
	await _capture("halyard_flight_deck_two_stations.png")

	# 11. The crew cabin, looking forward down the aisle from the aft portal.
	_frame_camera(craft.to_global(Vector3(0.0, 2.12, 2.0)), craft.to_global(Vector3(0.0, 1.7, -9.0)), 72.0)
	await _frames(6)
	await _capture("halyard_crew_cabin_forward.png")

	# 12. The crew cabin looking aft, so the seat rows and window band read from
	#     the pose the pilot arrives at when they leave the seat under way.
	var cabin := craft.get_in_flight_cabin_report()
	var stand := (cabin.get("stand_transform", Transform3D.IDENTITY) as Transform3D).origin
	_frame_camera(stand + Vector3(0.0, 1.62, 0.0), craft.to_global(Vector3(0.0, 1.6, 4.0)), 74.0)
	await _frames(6)
	await _capture("halyard_cabin_stand_pose.png")

	# 13. The aft systems bay: bunks, racks and the systems wall.
	_frame_camera(craft.to_global(Vector3(0.0, 2.1, 2.9)), craft.to_global(Vector3(-0.6, 1.5, 7.4)), 74.0)
	await _frames(6)
	await _capture("halyard_aft_systems_bay.png")

	await _dispose(world)


func _capture_production_berth() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "production Main instantiates for the berth review")
	if game == null:
		return
	_viewport.add_child(game)
	await process_frame
	for _settle in 8:
		await physics_frame
		await process_frame
	# The production HUD is a CanvasLayer and draws over the whole viewport, so
	# without this the berth frames render the title screen rather than the dock.
	for hud_name: String in ["HUD", "PauseMenu"]:
		var overlay := game.get_node_or_null(NodePath(hud_name)) as CanvasItem
		if overlay != null:
			overlay.visible = false
	for layer in game.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	await process_frame

	var transport: HeroShip = null
	for candidate in game.get_flyable_ships():
		if candidate.get_ship_id() == &"halyard_new_design":
			transport = candidate
	_check(transport != null, "the transport is parked in the production station")
	if transport == null:
		await _dispose(game)
		return

	_camera = Camera3D.new()
	_camera.name = "BerthReviewCamera"
	_camera.near = 0.1
	_camera.far = 3000.0
	_camera.current = true
	_viewport.add_child(_camera)
	await _frames(4)

	# 14. The transport on Fleet Dock 02, with the Zenith on Dock 01 beside it,
	#     which is the frame that shows whether two craft read apart at a glance.
	_frame_camera(
		transport.global_position + Vector3(-6.0, 26.0, -44.0),
		transport.global_position + Vector3(-7.0, 2.0, 2.0),
		48.0
	)
	await _frames(8)
	await _capture("halyard_fleet_dock_02_context.png")

	# 15. Deck level on the dock, the way a pilot walking out to it sees it.
	_frame_camera(
		transport.global_position + Vector3(-11.0, 1.7, -12.0),
		transport.global_position + Vector3(-1.0, 2.2, -6.0),
		62.0
	)
	await _frames(6)
	await _capture("halyard_fleet_dock_02_walk_up.png")

	await _dispose(game)


func _build_review_world() -> Node3D:
	var world := Node3D.new()
	world.name = "HalyardReviewWorld"

	var environment := WorldEnvironment.new()
	var resource := Environment.new()
	resource.background_mode = Environment.BG_COLOR
	resource.background_color = Color("05101a")
	resource.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	resource.ambient_light_color = Color("8fa9bd")
	resource.ambient_light_energy = 0.32
	resource.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	resource.tonemap_mode = Environment.TONE_MAPPER_AGX
	resource.glow_enabled = true
	resource.glow_intensity = 0.26
	environment.environment = resource
	world.add_child(environment)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38.0, -42.0, 0.0)
	key.light_color = Color("f6e8cd")
	key.light_energy = 2.0
	key.shadow_enabled = true
	world.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(18.0, 138.0, 0.0)
	fill.light_color = Color("6aa9c9")
	fill.light_energy = 0.66
	world.add_child(fill)

	var deck := StaticBody3D.new()
	deck.name = "ReviewLandingDeck"
	deck.collision_layer = PhysicsLayers.WORLD_BODY_LAYER
	world.add_child(deck)
	var deck_mesh := MeshInstance3D.new()
	var deck_box := BoxMesh.new()
	deck_box.size = Vector3(80.0, 0.3, 70.0)
	var deck_material := StandardMaterial3D.new()
	deck_material.albedo_color = Color("16242e")
	deck_material.metallic = 0.5
	deck_material.roughness = 0.46
	deck_box.material = deck_material
	deck_mesh.mesh = deck_box
	deck_mesh.position.y = -1.46
	deck.add_child(deck_mesh)
	var deck_collision := CollisionShape3D.new()
	var deck_shape := BoxShape3D.new()
	deck_shape.size = Vector3(80.0, 0.3, 70.0)
	deck_collision.shape = deck_shape
	deck_collision.position.y = -1.46
	deck.add_child(deck_collision)
	return world


func _find_cockpit_camera(craft: HeroShip) -> Camera3D:
	for node in craft.find_children("CockpitCamera", "Camera3D", true, false):
		return node as Camera3D
	return null


func _frame_camera(camera_position: Vector3, target: Vector3, field_of_view: float) -> void:
	_camera.global_position = camera_position
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
	_check(
		image.get_width() == 1280 and image.get_height() == 720,
		"%s has target dimensions" % file_name
	)
	_check(size > 16384, "%s contains substantive rendered evidence" % file_name)
	_captured += 1
	print("CAPTURED: ", absolute, " (", size, " bytes)")


func _frames(count: int) -> void:
	for _index in count:
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
