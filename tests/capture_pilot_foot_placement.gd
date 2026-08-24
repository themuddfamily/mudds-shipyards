extends SceneTree

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const OUTPUT_PATH := "/tmp/pilot-foot-placement-review.png"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var stage := Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	var environment_resource := Environment.new()
	environment_resource.background_mode = Environment.BG_COLOR
	environment_resource.background_color = Color("18222e")
	environment_resource.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment_resource.ambient_light_color = Color("a8c3d9")
	environment_resource.ambient_light_energy = 0.72
	environment.environment = environment_resource
	stage.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
	light.light_energy = 1.8
	light.shadow_enabled = true
	stage.add_child(light)

	var ramp := StaticBody3D.new()
	ramp.rotation.z = deg_to_rad(6.0)
	var ramp_collision := CollisionShape3D.new()
	var ramp_shape := BoxShape3D.new()
	ramp_shape.size = Vector3(7.0, 0.2, 5.0)
	ramp_collision.shape = ramp_shape
	ramp.add_child(ramp_collision)
	var ramp_mesh := MeshInstance3D.new()
	var ramp_box := BoxMesh.new()
	ramp_box.size = ramp_shape.size
	ramp_mesh.mesh = ramp_box
	var ramp_material := StandardMaterial3D.new()
	ramp_material.albedo_color = Color("3e5262")
	ramp_material.metallic = 0.35
	ramp_material.roughness = 0.62
	ramp_mesh.material_override = ramp_material
	ramp.add_child(ramp_mesh)
	stage.add_child(ramp)

	var player := PLAYER_SCENE.instantiate() as PlayerController
	stage.add_child(player)
	player.set_control_enabled(false)
	player.set_camera_active(false)
	player.teleport_to(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.55, 0.0)))
	for _frame in 50:
		await physics_frame
	var snapshot := player.get_grounded_foot_placement_snapshot()
	if not bool(snapshot.get("active", false)):
		push_error("Foot placement did not activate for native capture")
		quit(1)
		return
	for side: StringName in [&"l", &"r"]:
		var foot: Dictionary = (snapshot.get("feet", {}) as Dictionary).get(side, {})
		if not bool(foot.get("active", false)) or float(foot.get("sole_error_m", INF)) > 0.02:
			push_error("Foot placement capture sole contract failed for %s" % side)
			quit(1)
			return

	var camera := Camera3D.new()
	camera.fov = 48.0
	camera.near = 0.05
	camera.position = Vector3(3.9, 2.25, 4.8)
	stage.add_child(camera)
	camera.look_at(Vector3(0.0, 0.95, 0.0), Vector3.UP)
	camera.current = true
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	var error := image.save_png(OUTPUT_PATH)
	if error != OK:
		push_error("Unable to save pilot foot-placement capture: %s" % error_string(error))
		quit(1)
		return
	print("PILOT_FOOT_PLACEMENT_CAPTURE_OK: ", OUTPUT_PATH)
	quit(0)
