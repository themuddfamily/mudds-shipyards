extends SceneTree

## A bounded Forward+ dorsal view of the production Torrent fallback art. The
## harness first gives the starboard cosmetic service cover an equivalent
## duplicate mesh (the pre-trim allocation), then restores the production
## shared mesh and requires exact pixel parity.

const TORRENT_SCENE := preload("res://scenes/ships/torrent_interceptor.tscn")
const OUTPUT_DIR := "/tmp/mudds-wave32-torrent-service-panels"
const CAPTURE_SIZE := Vector2i(1600, 900)

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = CAPTURE_SIZE
	root.content_scale_size = Vector2i.ZERO
	root.use_taa = false
	root.msaa_3d = Viewport.MSAA_2X
	_check(
		RenderingServer.get_current_rendering_method() == &"forward_plus"
			and not RenderingServer.get_video_adapter_name().is_empty(),
		"capture uses a live Forward+ rendering device"
	)

	var world := Node3D.new()
	world.name = "TorrentServicePanelReviewWorld"
	root.add_child(world)
	_install_environment(world)

	var torrent := TORRENT_SCENE.instantiate() as HeroShip
	_check(torrent != null, "production Torrent instantiates")
	if torrent == null:
		_finish()
		return
	world.add_child(torrent)
	await process_frame
	await physics_frame
	torrent.set_physics_process(false)

	var visual := torrent.get_variant_visual_root()
	var close_art := visual.get_node_or_null("TorrentHeroPresentation") as Node3D
	var fallback := visual.get_node_or_null("LegacyFarPresentation") as Node3D
	_check(close_art != null and fallback != null, "Torrent resolves both presentation roots")
	if close_art != null:
		close_art.visible = false
	if fallback != null:
		fallback.visible = true
	var modern := fallback.get_node_or_null("ModernSystems") as Node3D if fallback != null else null
	var port := modern.get_node_or_null("PortFuselageServicePanel") as MeshInstance3D \
		if modern != null else null
	var starboard := modern.get_node_or_null("StarboardFuselageServicePanel") as MeshInstance3D \
		if modern != null else null
	_check(
		port != null and starboard != null and port.mesh == starboard.mesh,
		"production service covers resolve as two named copies sharing one mesh"
	)
	_check(
		port != null and starboard != null
			and port.position.is_equal_approx(Vector3(-1.62, 1.79, -2.55))
			and starboard.position.is_equal_approx(Vector3(1.62, 1.79, -2.55))
			and port.rotation.is_equal_approx(Vector3(0.0, 0.0, deg_to_rad(5.0)))
			and starboard.rotation.is_equal_approx(Vector3(0.0, 0.0, deg_to_rad(-5.0)))
			and port.cast_shadow == starboard.cast_shadow
			and port.layers == starboard.layers,
		"both service covers retain separate mirrored transforms and renderer state"
	)

	var camera := Camera3D.new()
	camera.name = "TorrentServicePanelCaptureCamera"
	camera.position = Vector3(0.0, 8.2, -11.8)
	camera.near = 0.06
	camera.far = 100.0
	camera.fov = 37.0
	world.add_child(camera)
	camera.look_at(Vector3(0.0, 1.1, -1.5), Vector3.UP)
	camera.current = true
	_check(
		camera.position.distance_to(Vector3(0.0, 1.1, -1.5)) > 12.0
			and camera.position.distance_to(Vector3(0.0, 1.1, -1.5)) < 13.0,
		"fixed dorsal camera remains at gameplay review distance"
	)

	var shared_mesh := port.mesh if port != null else null
	if starboard != null and shared_mesh != null:
		starboard.mesh = shared_mesh.duplicate(true)
		_check(starboard.mesh != shared_mesh, "before witness restores two equivalent mesh allocations")
	var before := await _capture_frame("before_duplicate")
	if starboard != null:
		starboard.mesh = shared_mesh
	var after := await _capture_frame("after_shared")
	_check(
		before != null and after != null
			and not before.is_empty() and not after.is_empty()
			and before.get_size() == CAPTURE_SIZE and after.get_size() == CAPTURE_SIZE
			and before.get_data() == after.get_data(),
		"duplicate-mesh and shared-mesh Forward+ pixels are exactly identical"
	)

	world.queue_free()
	await process_frame
	_finish()


func _capture_frame(variant: String) -> Image:
	for _frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_check(
		image != null and not image.is_empty() and image.get_size() == CAPTURE_SIZE,
		"%s frame renders at 1600x900" % variant
	)
	if image != null and not image.is_empty():
		DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
		var output_path := OUTPUT_DIR.path_join("torrent_service_panels_%s.png" % variant)
		_check(image.save_png(output_path) == OK, "%s capture saves" % variant)
		print("TORRENT_SERVICE_PANEL_CAPTURE: ", output_path)
	return image


func _install_environment(world: Node3D) -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("07111c")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("7895aa")
	environment.ambient_light_energy = 0.42
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.glow_enabled = false
	world_environment.environment = environment
	world.add_child(world_environment)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48.0, -24.0, 0.0)
	key.light_color = Color("ffe1c4")
	key.light_energy = 1.9
	key.shadow_enabled = true
	world.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(28.0, 151.0, 0.0)
	fill.light_color = Color("71bdd0")
	fill.light_energy = 0.68
	fill.shadow_enabled = false
	world.add_child(fill)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	_failures.append(message)
	push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("TORRENT_FUSELAGE_SERVICE_PANEL_CAPTURE_OK")
		quit(0)
		return
	print("TORRENT_FUSELAGE_SERVICE_PANEL_CAPTURE_FAILED: ", "; ".join(_failures))
	quit(1)
