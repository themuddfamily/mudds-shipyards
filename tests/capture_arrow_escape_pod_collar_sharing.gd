extends SceneTree

## One HUD-free Forward+ gameplay-distance witness for the Arrow's paired
## escape-pod separation collars. The fixed rear-starboard flank keeps both pod
## modules readable while the harness proves that immutable mesh sharing did not
## merge their transforms, parents, culling state, or spatial envelopes.

const ARROW_SCENE := preload("res://scenes/ships/arrow_recon_ship.tscn")
const OUTPUT_PATH := (
	"res://artifacts/arrow_escape_pod_collar_sharing/gameplay_distance.png"
)
const CAPTURE_RESOLUTION := Vector2i(1600, 900)
const CAMERA_POSITION := Vector3(4.8, 9.0, 16.4)
const CAMERA_TARGET := Vector3(0.0, -1.0, 3.25)

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = CAPTURE_RESOLUTION
	root.content_scale_size = Vector2i.ZERO
	root.use_taa = true
	root.msaa_3d = Viewport.MSAA_2X
	_check(
		RenderingServer.get_current_rendering_method() == &"forward_plus"
			and not RenderingServer.get_video_adapter_name().is_empty(),
		"capture has a live Forward+ rendering device"
	)

	var world := Node3D.new()
	world.name = "ArrowEscapePodCollarReviewWorld"
	root.add_child(world)
	_build_environment(world)

	var arrow := ARROW_SCENE.instantiate() as ArrowReconShip
	_check(arrow != null, "production Arrow instantiates")
	if arrow == null:
		_finish()
		return
	world.add_child(arrow)
	await process_frame
	await physics_frame
	arrow.set_physics_process(false)

	var sharing := (
		arrow.get_arrow_visual_performance_report()
			.pod_separation_collar_mesh_sharing as Dictionary
	)
	var paths := sharing.get("node_paths", PackedStringArray()) as PackedStringArray
	var visual := arrow.get_arrow_visual_root()
	var port := visual.get_node_or_null(NodePath(paths[0])) as MeshInstance3D \
		if visual != null and paths.size() == 2 else null
	var starboard := visual.get_node_or_null(NodePath(paths[1])) as MeshInstance3D \
		if visual != null and paths.size() == 2 else null
	var shared_mesh := port.mesh as TorusMesh if port != null else null
	_check(
		bool(sharing.get("valid", false)) and port != null and starboard != null
			and paths == PackedStringArray([
				"PortEscapePod/PodSeparationCollar",
				"StarboardEscapePod/PodSeparationCollar",
			])
			and port.mesh == starboard.mesh
			and int(sharing.get("primitive_mesh_allocations", -1)) == 1
			and int(sharing.get("visible_geometry_copies", -1)) == 2,
		"both named collars resolve as two visible copies sharing one mesh"
	)
	_check(
		shared_mesh != null
			and shared_mesh.material == arrow.get_variant_materials().graphite
			and not shared_mesh.resource_local_to_scene
			and is_equal_approx(
				shared_mesh.inner_radius,
				ArrowReconShip.POD_SEPARATION_COLLAR_INNER_RADIUS
			)
			and is_equal_approx(
				shared_mesh.outer_radius,
				ArrowReconShip.POD_SEPARATION_COLLAR_OUTER_RADIUS
			),
		"shared collar geometry retains the authored graphite material and radii"
	)
	var authored_transform := sharing.get(
		"authored_local_transform", Transform3D()
	) as Transform3D
	_check(
		port != null and starboard != null
			and port.transform.is_equal_approx(authored_transform)
			and starboard.transform.is_equal_approx(authored_transform)
			and port.get_parent() == arrow.get_escape_pod(&"port")
			and starboard.get_parent() == arrow.get_escape_pod(&"starboard")
			and port.get_parent() != starboard.get_parent(),
		"each exact local transform remains owned by its distinct named pod"
	)
	_check(
		_renderer_culling_is_unbounded(port)
			and _renderer_culling_is_unbounded(starboard),
		"both collars retain visible unranged culling and ordinary shadow state"
	)
	if port != null and starboard != null and shared_mesh != null:
		var port_bounds := (port.global_transform * shared_mesh.get_aabb()).abs()
		var starboard_bounds := (
			starboard.global_transform * shared_mesh.get_aabb()
		).abs()
		_check(
			port.global_position.x < 0.0 and starboard.global_position.x > 0.0
				and not port_bounds.intersects(starboard_bounds),
			"shared geometry produces separate port/starboard culling envelopes with no cross-pod leakage"
		)

	var camera := Camera3D.new()
	camera.name = "ArrowEscapePodCollarCaptureCamera"
	camera.near = 0.06
	camera.far = 180.0
	camera.fov = 30.0
	camera.position = CAMERA_POSITION
	world.add_child(camera)
	camera.look_at(CAMERA_TARGET, Vector3.UP)
	camera.current = true
	_check(
		camera.position.distance_to(CAMERA_TARGET) > 14.0
			and camera.position.distance_to(CAMERA_TARGET) < 18.0,
		"fixed rear-flank camera remains at gameplay review distance"
	)

	for _frame in 18:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_check(
		image != null and not image.is_empty()
			and image.get_size() == CAPTURE_RESOLUTION,
		"collar review frame renders at the requested resolution"
	)
	if image != null and not image.is_empty():
		var absolute := ProjectSettings.globalize_path(OUTPUT_PATH)
		DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
		_check(image.save_png(absolute) == OK, "capture saves successfully")
		print("ARROW_ESCAPE_POD_COLLAR_CAPTURE: ", absolute)

	world.queue_free()
	await process_frame
	_finish()


func _renderer_culling_is_unbounded(renderer: MeshInstance3D) -> bool:
	return renderer != null and renderer.visible \
		and is_zero_approx(renderer.visibility_range_begin) \
		and is_zero_approx(renderer.visibility_range_end) \
		and is_zero_approx(renderer.extra_cull_margin) \
		and renderer.visibility_parent == NodePath() \
		and renderer.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON \
		and renderer.material_override == null \
		and renderer.material_overlay == null


func _build_environment(world: Node3D) -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("06101a")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("7793a8")
	environment.ambient_light_energy = 0.44
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.glow_enabled = false
	world_environment.environment = environment
	world.add_child(world_environment)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38.0, -42.0, 0.0)
	key.light_color = Color("ffe0bd")
	key.light_energy = 2.1
	key.shadow_enabled = true
	world.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(22.0, 136.0, 0.0)
	fill.light_color = Color("69b6c9")
	fill.light_energy = 0.76
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
		print("ARROW_ESCAPE_POD_COLLAR_CAPTURE_OK")
		quit(0)
		return
	print("ARROW_ESCAPE_POD_COLLAR_CAPTURE_FAILED: ", "; ".join(_failures))
	quit(1)
