extends SceneTree

## Stable Forward+ gameplay-distance witness of the production Emberline
## tender and its steady rendezvous route feather. The harness changes no route,
## activity, collision, escort, or movement state.

const HostScript := preload("res://scripts/activities/cinder_convoy_escort_host.gd")
const CAPTURE_SIZE := Vector2i(1600, 900)
const OUTPUT_PATH := "/tmp/mudds-wave32-convoy-visual/artifacts/cinder_convoy_rendezvous_cue/forward_plus.png"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = CAPTURE_SIZE
	root.content_scale_size = Vector2i.ZERO
	root.msaa_3d = Viewport.MSAA_2X
	root.use_taa = true
	_check(
		RenderingServer.get_current_rendering_method() == &"forward_plus"
			and not RenderingServer.get_video_adapter_name().is_empty(),
		"capture uses a live Forward+ renderer"
	)

	var stage := Node3D.new()
	stage.name = "CinderConvoyRendezvousCapture"
	root.add_child(stage)
	_install_environment(stage)
	var host := HostScript.new() as CinderConvoyEscortHost
	stage.add_child(host)
	await process_frame
	var started := host.start(0)
	var tender := host.get_node_or_null(^"EmberlineSupplyTender") as Node3D
	var cue := tender.get_node_or_null(^"NavigationBeacon") as MeshInstance3D \
		if tender != null else null
	_check(
		bool(started.get("accepted", false))
			and bool(host.audit().get("valid", false))
			and cue != null and cue.mesh is ArrayMesh
			and cue.mesh.get_surface_count() == 1,
		"production tender audits green with one retained route-cue surface"
	)

	var camera := Camera3D.new()
	camera.name = "RendezvousApproachCamera"
	# Forty-two metres is inside the authored 42 m escort radius and represents
	# a real final rendezvous approach rather than an editor close-up.
	var tender_position := tender.global_position
	camera.position = tender_position + Vector3(18.0, 12.0, 36.0)
	camera.near = 0.08
	camera.far = 180.0
	camera.fov = 52.0
	stage.add_child(camera)
	camera.look_at(tender_position + Vector3(0.0, 0.7, -1.6), Vector3.UP)
	camera.current = true
	var cue_span_pixels := camera.unproject_position(
		cue.to_global(Vector3(1.1, -0.8, 0.0))
	).distance_to(camera.unproject_position(
		cue.to_global(Vector3(-1.1, -0.8, 0.0))
	))
	_check(
		camera.global_position.distance_to(tender_position) >= 41.0
			and camera.global_position.distance_to(tender_position) <= 43.0
			and camera.is_position_in_frustum(cue.global_position)
			and cue_span_pixels >= 30.0,
		"gameplay framing resolves the broad cue from real escort distance"
	)
	print("CINDER_CONVOY_RENDEZVOUS_CUE_SPAN_PIXELS: %.2f" % cue_span_pixels)

	for _frame in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_check(
		image != null and not image.is_empty() and image.get_size() == CAPTURE_SIZE,
		"stable rendezvous frame renders at 1600x900"
	)
	if image != null and not image.is_empty():
		DirAccess.make_dir_recursive_absolute(OUTPUT_PATH.get_base_dir())
		_check(image.save_png(OUTPUT_PATH) == OK, "Forward+ rendezvous capture saves")
		print("CINDER_CONVOY_RENDEZVOUS_CAPTURE: ", OUTPUT_PATH)

	stage.queue_free()
	await process_frame
	_finish()


func _install_environment(stage: Node3D) -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("050810")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("70859a")
	environment.ambient_light_energy = 0.48
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.glow_enabled = true
	environment.glow_intensity = 0.22
	world_environment.environment = environment
	stage.add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
	sun.light_color = Color("ffd1a0")
	sun.light_energy = 1.45
	sun.shadow_enabled = true
	stage.add_child(sun)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("CINDER_CONVOY_RENDEZVOUS_CAPTURE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error("CINDER_CONVOY_RENDEZVOUS_CAPTURE_FAILED: %s" % failure)
	quit(1)
