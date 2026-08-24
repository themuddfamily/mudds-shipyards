extends SceneTree

## One-frame Forward+ review of the production-composed Cinder cargo terminal
## handoff. The camera sits at on-foot gameplay distance from the batched rail
## pair so both copies, their spacing, and the destination terminal stay visible.

const CLUSTER_SCENE := preload("res://scenes/world/components/nearby_sector_cluster.tscn")
const OUTPUT_PATH := "res://artifacts/cinder_cargo_access_handoff_rails_forward_plus.png"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if RenderingServer.get_current_rendering_method() != &"forward_plus":
		push_error("CINDER CARGO HANDOFF CAPTURE FAILED: Forward+ is required")
		quit(1)
		return
	root.size = Vector2i(1600, 900)
	root.msaa_3d = Viewport.MSAA_2X
	root.use_taa = false
	var stage := Node3D.new()
	stage.name = "CinderCargoHandoffCapture"
	root.add_child(stage)
	var cluster := CLUSTER_SCENE.instantiate() as NearbySectorCluster
	stage.add_child(cluster)
	await process_frame
	await physics_frame
	var access := cluster.get_cinder_cargo_access()
	var terminal := cluster.get_cinder_cargo_destination_terminal()
	if access == null or terminal == null or not bool(access.audit().valid):
		push_error("CINDER CARGO HANDOFF CAPTURE FAILED: production composition invalid")
		quit(1)
		return
	var rail_audit := access.get_handoff_rail_visual_audit()
	if not bool(rail_audit.valid) or int(rail_audit.visible_copy_count) != 2:
		push_error("CINDER CARGO HANDOFF CAPTURE FAILED: handoff rail batch invalid")
		quit(1)
		return
	# Keep the exact production-composed access and destination terminal while
	# hiding unrelated platform machinery that blocks this bounded review angle.
	var platform := access.get_parent() as Node3D
	for sibling in platform.get_children():
		if sibling != access and sibling != terminal and sibling is Node3D:
			(sibling as Node3D).visible = false
	for clutter_path in [^"RouteBeacons", ^"Landmarks", ^"DebrisField"]:
		var clutter := cluster.get_node_or_null(clutter_path) as Node3D
		if clutter != null:
			clutter.visible = false
	_build_environment(stage)
	_build_lighting(stage)
	var platform_origin := NearbySectorCluster.PLATFORM_ANCHOR
	var camera := Camera3D.new()
	camera.name = "CargoHandoffGameplayCamera"
	camera.position = platform_origin + Vector3(-9.0, 6.2, 19.0)
	camera.fov = 52.0
	camera.near = 0.08
	camera.far = 180.0
	camera.current = true
	stage.add_child(camera)
	camera.look_at(platform_origin + Vector3(-1.8, 4.45, 15.2), Vector3.UP)
	for _frame in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("CINDER CARGO HANDOFF CAPTURE FAILED: empty viewport")
		quit(1)
		return
	var absolute := ProjectSettings.globalize_path(OUTPUT_PATH)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		push_error("CINDER CARGO HANDOFF CAPTURE FAILED: output directory")
		quit(1)
		return
	var save_error := image.save_png(absolute)
	if save_error != OK:
		push_error("CINDER CARGO HANDOFF CAPTURE FAILED: save error %d" % save_error)
		quit(1)
		return
	print(
		"CINDER CARGO HANDOFF CAPTURE OK: %s %dx%d"
		% [absolute, image.get_width(), image.get_height()]
	)
	stage.queue_free()
	await process_frame
	quit(0)


func _build_environment(stage: Node3D) -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("071219")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("72adb5")
	environment.ambient_light_energy = 0.46
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.30
	environment.glow_bloom = 0.04
	environment.ssao_enabled = true
	environment.ssao_radius = 2.0
	environment.ssao_intensity = 1.5
	world_environment.environment = environment
	stage.add_child(world_environment)


func _build_lighting(stage: Node3D) -> void:
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-52.0, -34.0, 0.0)
	key.light_color = Color("d8f1ef")
	key.light_energy = 1.25
	key.shadow_enabled = true
	stage.add_child(key)
	var fill := OmniLight3D.new()
	fill.position = NearbySectorCluster.PLATFORM_ANCHOR + Vector3(-1.5, 8.0, 18.0)
	fill.light_color = Color("66d5dc")
	fill.light_energy = 1.0
	fill.omni_range = 28.0
	fill.shadow_enabled = false
	stage.add_child(fill)
