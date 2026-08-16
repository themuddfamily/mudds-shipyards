extends SceneTree

## Forward+ regression capture for the Central FULL drone near-plane defect.
## It uses the production PlayerCamera resource at the exact point occupied by
## the old red navigation lens, renders one complete 1.35 s pulse, then writes
## an overview showing the rerouted drones above the pedestrian lane.

const ACTIVITY_SCENE := preload(
	"res://scenes/world/components/station_operations_activity.tscn"
)
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const OUTPUT_PATH := "/tmp/mudds-full-drone-camera-clearance.png"
const PULSE_PERIOD := 1.35
const FRAME_STEP := 0.025


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(960, 540)
	var stage := Node3D.new()
	root.add_child(stage)

	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("071119")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("7090a0")
	settings.ambient_light_energy = 0.62
	environment.environment = settings
	stage.add_child(environment)
	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-52.0, -38.0, 0.0)
	key_light.light_energy = 1.4
	stage.add_child(key_light)

	var deck := MeshInstance3D.new()
	var deck_mesh := BoxMesh.new()
	deck_mesh.size = Vector3(18.0, 0.18, 18.0)
	deck.mesh = deck_mesh
	deck.position.y = -0.09
	stage.add_child(deck)

	var activity := ACTIVITY_SCENE.instantiate() as StationOperationsActivity
	activity.activity_profile = StationOperationsActivity.ActivityProfile.FULL
	activity.variation_seed = 0
	activity.starts_paused = true
	stage.add_child(activity)
	var player := PLAYER_SCENE.instantiate() as PlayerController
	stage.add_child(player)
	await process_frame
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var camera := player.get_node(
		^"CameraRig/CameraYaw/CameraPitch/SpringArm3D/PlayerCamera"
	) as Camera3D
	camera.top_level = true
	camera.current = true

	# At t=0 and seed=0 this is the precise world transform of drone one's old
	# lens. Put the real 0.08 m-near PlayerCamera 0.04 m in front of it: the old
	# build deterministically painted the near plane red here.
	var legacy_drone_basis := Basis.from_euler(Vector3(0.0, PI * 0.5, 0.08))
	var legacy_lens_center := (
		Vector3(3.55, 1.48, 0.0)
		+ legacy_drone_basis * Vector3(0.0, 0.03, -0.39)
	)
	var lens_normal := (legacy_drone_basis * Vector3.BACK).normalized()
	camera.global_position = legacy_lens_center + lens_normal * 0.04
	camera.look_at(legacy_lens_center - lens_normal)

	var lens := activity.get_node(
		^"PresentationRoot/AnimatedServiceDrone01/NavigationLens"
	) as MeshInstance3D
	var saw_red := false
	var saw_dim := false
	var maximum_red_fraction := 0.0
	for step in int(round(PULSE_PERIOD / FRAME_STEP)) + 1:
		activity.set_activity_time(float(step) * FRAME_STEP)
		var material := lens.material_override as StandardMaterial3D
		saw_red = saw_red or material.albedo_color.is_equal_approx(Color("ff6b60"))
		saw_dim = saw_dim or material.albedo_color.is_equal_approx(Color("347b80"))
		await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		maximum_red_fraction = maxf(maximum_red_fraction, _red_pixel_fraction(image))

	# One inspectable frame from the same invocation: it shows the production
	# geometry at the raised route rather than just proving the legacy near-plane
	# point stays clear.
	activity.set_activity_time(0.1)
	camera.global_position = Vector3(8.2, 2.15, 8.6)
	camera.look_at(Vector3(0.0, 3.65, 0.0))
	await process_frame
	await RenderingServer.frame_post_draw
	var capture := root.get_texture().get_image()
	var save_error := capture.save_png(OUTPUT_PATH)

	var passed := (
		saw_red
		and saw_dim
		and maximum_red_fraction < 0.08
		and save_error == OK
	)
	print(
		"FULL_DRONE_CAMERA_CLEARANCE_RENDER: pulse=%.2fs red=%s dim=%s max_red_fraction=%.6f output=%s"
		% [PULSE_PERIOD, saw_red, saw_dim, maximum_red_fraction, OUTPUT_PATH]
	)
	if not passed:
		push_error("FULL drone Forward+ camera-clearance reproduction failed")
	quit(0 if passed else 1)


func _red_pixel_fraction(image: Image) -> float:
	if image.is_empty():
		return 1.0
	var red_pixels := 0
	var sampled_pixels := 0
	for y in range(0, image.get_height(), 3):
		for x in range(0, image.get_width(), 3):
			var color := image.get_pixel(x, y)
			if color.r > 0.42 and color.r > color.g * 1.45 and color.r > color.b * 1.25:
				red_pixels += 1
			sampled_pixels += 1
	return float(red_pixels) / float(maxi(sampled_pixels, 1))
