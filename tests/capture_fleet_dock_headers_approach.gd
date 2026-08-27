extends SceneTree

## One real Forward+ contact-sheet capture of the three final on-foot approach
## headers. Production contributes the berths and their existing PadSign nodes;
## this harness owns only neutral review lighting and the three camera poses.

const Berths := preload("res://scripts/world/fleet_expansion_berths.gd")
const OUTPUT_PATH := "/tmp/mudds-fleet-dock-headers-approach.png"
const CAPTURE_RESOLUTION := Vector2i(1600, 900)
const HEADER_APPROACHES := {
	&"dock_04_cargo": {
		"camera": Vector3(-19.8, 1.65, -3.0),
		"target": Vector3(-19.8, 1.25, -8.535),
		"normal": Vector3.BACK,
	},
	&"dock_05_bomber": {
		"camera": Vector3(30.2, 1.65, -23.0),
		"target": Vector3(30.2, 1.25, -17.965),
		"normal": Vector3.FORWARD,
	},
	&"dock_06_interceptor": {
		"camera": Vector3(0.5, 1.65, 34.0),
		"target": Vector3(-3.035, 1.25, 34.0),
		"normal": Vector3.RIGHT,
	},
}

var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = CAPTURE_RESOLUTION
	root.content_scale_size = Vector2i.ZERO
	root.msaa_3d = Viewport.MSAA_2X
	root.use_taa = true
	_check(
		RenderingServer.get_current_rendering_method() == &"forward_plus"
			and not RenderingServer.get_video_adapter_name().is_empty(),
		"the header witness uses a live Forward+ rendering device"
	)

	var stage := Node3D.new()
	stage.name = "FleetDockHeaderApproachWitness"
	root.add_child(stage)
	_build_environment(stage)
	_build_lighting(stage)
	var berths := Berths.new()
	stage.add_child(berths)
	await process_frame

	var audit := berths.get_audit_report()
	_check(
		bool(audit.get("valid", false))
			and int(audit.get("renderer_nodes", -1)) == 24
			and int(audit.get("guide_lights", -1)) == 5
			and int(audit.get("collision_shapes", -1)) == 6,
		"the capture preserves the production renderer, light, and collision budgets"
	)

	var camera := Camera3D.new()
	camera.near = 0.08
	camera.far = 120.0
	camera.fov = 55.0
	stage.add_child(camera)
	var sheet := Image.create(CAPTURE_RESOLUTION.x * HEADER_APPROACHES.size(), CAPTURE_RESOLUTION.y, false, Image.FORMAT_RGBA8)
	for index in HEADER_APPROACHES.size():
		var pad_id := HEADER_APPROACHES.keys()[index] as StringName
		var approach := HEADER_APPROACHES[pad_id] as Dictionary
		var sign := berths.get_node_or_null(NodePath("%s/PadSign" % String(pad_id))) as Label3D
		var camera_position := approach.get("camera", Vector3.INF) as Vector3
		var expected_normal := approach.get("normal", Vector3.ZERO) as Vector3
		var to_camera := (camera_position - sign.global_position).normalized() if sign != null else Vector3.ZERO
		var dock_number := Berths.PAD_IDS.find(pad_id) + 4
		_check(
			sign != null and sign.text.begins_with("DOCK %02d" % dock_number)
				and sign.global_basis.z.normalized().dot(expected_normal) > 0.999
				and sign.global_basis.z.normalized().dot(to_camera) > 0.80,
			"%s header faces its real connector walking approach" % String(pad_id)
		)
		camera.position = camera_position
		camera.look_at_from_position(
			camera.position, approach.get("target", Vector3.ZERO) as Vector3, Vector3.UP
		)
		camera.current = true
		for _frame in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		var frame := root.get_texture().get_image()
		_check(
			frame != null and not frame.is_empty() and frame.get_size() == CAPTURE_RESOLUTION,
			"%s normal approach frame renders" % String(pad_id)
		)
		if frame != null and not frame.is_empty():
			frame.convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(frame, Rect2i(Vector2i.ZERO, CAPTURE_RESOLUTION), Vector2i(index * CAPTURE_RESOLUTION.x, 0))
	_check(sheet.save_png(OUTPUT_PATH) == OK, "the three-header Forward+ contact sheet saves")
	print("FLEET_DOCK_HEADERS_APPROACH_CAPTURE: ", OUTPUT_PATH)

	stage.queue_free()
	await process_frame
	if _failures.is_empty():
		print("PASS capture_fleet_dock_headers_approach")
		quit(0)
		return
	for failure in _failures:
		push_error("FAIL: %s" % failure)
	quit(1)


func _build_environment(stage: Node3D) -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("061018")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("7595a4")
	environment.ambient_light_energy = 0.54
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.24
	environment.glow_bloom = 0.03
	environment.ssao_enabled = true
	environment.ssao_radius = 1.6
	environment.ssao_intensity = 1.3
	world_environment.environment = environment
	stage.add_child(world_environment)


func _build_lighting(stage: Node3D) -> void:
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-52.0, -38.0, 0.0)
	key.light_color = Color("ffe0b8")
	key.light_energy = 1.35
	key.shadow_enabled = true
	stage.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-26.0, 142.0, 0.0)
	fill.light_color = Color("69d8e1")
	fill.light_energy = 0.62
	fill.shadow_enabled = false
	stage.add_child(fill)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	_failures.append(message)
