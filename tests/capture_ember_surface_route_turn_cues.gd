extends SceneTree

## Stable Forward+ on-foot witness of Ember's unchanged pad-egress spine. The
## frame includes the shape-only rack and relay turn chevrons and both physical
## destinations; this harness owns no route, interaction, or objective state.

const EMBER_SCENE := preload("res://scenes/world/planets/ember_moon.tscn")
const OUTPUT_PATH := "/tmp/mudds-wave32-ember-route-capture/ember_surface_route_turn_cues_forward_plus.png"
const CAPTURE_SIZE := Vector2i(1600, 900)
const SURFACE_Y := EmberMoonAuthoredScene.BODY_RADIUS_M

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
		"capture uses a live Forward+ renderer",
	)

	var stage := Node3D.new()
	stage.name = "EmberSurfaceRouteTurnCueCapture"
	root.add_child(stage)
	_install_environment(stage)
	var ember := EMBER_SCENE.instantiate() as EmberMoonAuthoredScene
	stage.add_child(ember)
	await process_frame
	await physics_frame

	var spine := ember.get_node_or_null(
		^"LandingRegion/SurfaceLandmarks/RouteSpineVisuals"
	) as MultiMeshInstance3D
	var transforms := spine.get_meta("authored_transforms", []) as Array \
		if spine != null else []
	var snapshot := ember.get_snapshot()
	_check(bool(ember.audit().valid), "production Ember scene audits green")
	_check(
		spine != null and spine.multimesh != null
			and spine.multimesh.instance_count == 10
			and transforms.size() == 10
			and spine.get_meta("turn_destination_marker_ids", PackedStringArray())
				== PackedStringArray(["ember_sample_rack_access", "ember_staging_relay_access"])
			and int(snapshot.geometry.surface_route_turn_cue_count) == 2,
		"one existing passive batch publishes exactly two access turns",
	)
	if transforms.size() == 10:
		_check(
			(transforms[4] as Transform3D).basis.z.normalized().z < -0.8
				and (transforms[5] as Transform3D).basis.z.normalized().z < -0.8,
			"sample-rack chevron turns from the spine toward the exact negative-Z access",
		)
		_check(
			(transforms[8] as Transform3D).basis.z.normalized().z > 0.8
				and (transforms[9] as Transform3D).basis.z.normalized().z > 0.8,
			"relay chevron turns from the spine toward the exact positive-Z access",
		)
		var all_flush_and_supported := true
		for transform_value in transforms:
			var transform := transform_value as Transform3D
			all_flush_and_supported = all_flush_and_supported \
				and is_equal_approx(transform.origin.y, EmberMoonAuthoredScene.ROUTE_SPINE_Y_M) \
				and absf(transform.origin.x) < 48.0 and absf(transform.origin.z) < 48.0
		_check(all_flush_and_supported, "every cue remains flush over the unchanged walkable support")

	var camera := Camera3D.new()
	camera.name = "OnFootRouteCamera"
	# Third-person on-foot review framing: six metres above the pad threshold and
	# twenty-eight metres from the route midpoint, matching a pulled-back player
	# camera rather than an orbital or editor overview.
	camera.position = Vector3(8.0, SURFACE_Y + 6.0, 18.0)
	camera.near = 0.08
	camera.far = 180.0
	camera.fov = 66.0
	stage.add_child(camera)
	camera.look_at(Vector3(30.0, SURFACE_Y + 0.15, 0.0), Vector3.UP)
	camera.current = true
	var rack := ember.get_node_or_null(
		^"LandingRegion/SurfaceLandmarks/SampleRack"
	) as Node3D
	var relay := ember.get_node_or_null(
		^"LandingRegion/SurfaceLandmarks/StagingRelay"
	) as Node3D
	_check(
		rack != null and relay != null
			and camera.is_position_in_frustum(rack.global_position + Vector3.UP * 1.5)
			and camera.is_position_in_frustum(relay.global_position + Vector3.UP * 1.5),
		"normal on-foot framing includes both physical turn destinations",
	)

	for _frame in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_check(
		image != null and not image.is_empty() and image.get_size() == CAPTURE_SIZE,
		"stable route frame renders at 1600x900",
	)
	if image != null and not image.is_empty():
		DirAccess.make_dir_recursive_absolute(OUTPUT_PATH.get_base_dir())
		_check(image.save_png(OUTPUT_PATH) == OK, "Forward+ route capture saves successfully")
		print("EMBER_SURFACE_ROUTE_TURN_CAPTURE: ", OUTPUT_PATH)

	stage.queue_free()
	await process_frame
	_finish()


func _install_environment(stage: Node3D) -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("060810")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("6d7892")
	environment.ambient_light_energy = 0.5
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.glow_enabled = true
	environment.glow_intensity = 0.35
	world_environment.environment = environment
	stage.add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -34.0, 0.0)
	sun.light_color = Color("ffd2a0")
	sun.light_energy = 1.55
	sun.shadow_enabled = true
	stage.add_child(sun)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("EMBER_SURFACE_ROUTE_TURN_CAPTURE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error("EMBER_SURFACE_ROUTE_TURN_CAPTURE_FAILED: %s" % failure)
	quit(1)
