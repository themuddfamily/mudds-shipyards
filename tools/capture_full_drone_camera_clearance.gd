extends SceneTree

## Forward+ regression capture for the service-drone near-plane defect.
## It follows both moving lenses in the production Central FULL and Habitat
## DRONE_PATROL profiles through a complete pulse using their production seeds.
## At each current lens transform it first recreates the pane by disabling the
## cutoff, then restores the production guard and renders the identical frame.

const ACTIVITY_SCENE := preload(
	"res://scenes/world/components/station_operations_activity.tscn"
)
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const OUTPUT_PATH := "/tmp/mudds-full-drone-camera-clearance.png"
const PULSE_PERIOD := 1.35
const FRAME_STEP := 0.025
const DRONE_CAMERA_CLEARANCE_DISTANCE := 0.65
const LENS_HALF_DEPTH := 0.055 * 0.5
const NEAR_PLANE_WITNESS_EPSILON := 0.0025
const FULL_PRODUCTION_SEED := 1103
const ROOF_PATROL_PRODUCTION_SEED := 3301


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

	var full_activity := ACTIVITY_SCENE.instantiate() as StationOperationsActivity
	full_activity.activity_profile = StationOperationsActivity.ActivityProfile.FULL
	full_activity.variation_seed = FULL_PRODUCTION_SEED
	full_activity.starts_paused = true
	full_activity.position = Vector3(-6.0, 0.0, 0.0)
	stage.add_child(full_activity)
	var roof_activity := ACTIVITY_SCENE.instantiate() as StationOperationsActivity
	roof_activity.activity_profile = StationOperationsActivity.ActivityProfile.DRONE_PATROL
	roof_activity.variation_seed = ROOF_PATROL_PRODUCTION_SEED
	roof_activity.starts_paused = true
	roof_activity.position = Vector3(6.0, 0.0, 0.0)
	stage.add_child(roof_activity)
	var player := PLAYER_SCENE.instantiate() as PlayerController
	stage.add_child(player)
	await process_frame
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var camera := player.get_node(
		^"CameraRig/CameraYaw/CameraPitch/SpringArm3D/PlayerCamera"
	) as Camera3D
	camera.top_level = true
	camera.current = true

	var profile_results: Array[Dictionary] = []
	for activity in [full_activity, roof_activity]:
		profile_results.append(await _measure_activity(activity, camera))

	# One inspectable frame from the same invocation: it shows the production
	# geometry at the raised route rather than just proving the legacy near-plane
	# point stays clear.
	full_activity.set_activity_time(0.1)
	camera.global_position = full_activity.global_position + Vector3(8.2, 2.15, 8.6)
	camera.look_at(full_activity.global_position + Vector3(0.0, 3.65, 0.0))
	await process_frame
	await RenderingServer.frame_post_draw
	var capture := root.get_texture().get_image()
	var save_error := capture.save_png(OUTPUT_PATH)

	var passed := save_error == OK
	for result in profile_results:
		passed = passed and bool(result.passed)
		print(
			"DRONE_CAMERA_CLEARANCE_RENDER: profile=%s seed=%d lenses=%d pulse=%.2fs red=%s dim=%s unguarded_red_fraction=%.6f guarded_red_fraction=%.6f unguarded_bright_fraction=%.6f guarded_bright_fraction=%.6f"
			% [
				String(result.profile_id),
				int(result.seed),
				int(result.lens_count),
				PULSE_PERIOD,
				bool(result.saw_red),
				bool(result.saw_dim),
				float(result.maximum_unguarded_red_fraction),
				float(result.maximum_guarded_red_fraction),
				float(result.maximum_unguarded_bright_fraction),
				float(result.maximum_guarded_bright_fraction),
			]
		)
	print("DRONE_CAMERA_CLEARANCE_OUTPUT: %s" % OUTPUT_PATH)
	if not passed:
		push_error("service-drone Forward+ camera-clearance reproduction failed")
	quit(0 if passed else 1)


func _measure_activity(
		activity: StationOperationsActivity,
		camera: Camera3D
	) -> Dictionary:
	var lenses: Array[MeshInstance3D] = []
	for drone_index in 2:
		lenses.append(activity.get_node(
			NodePath(
				"PresentationRoot/AnimatedServiceDrone%02d/NavigationLens"
				% (drone_index + 1)
			)
		) as MeshInstance3D)
	var result := {
		"profile_id": activity.get_activity_profile_id(),
		"seed": activity.variation_seed,
		"lens_count": lenses.size(),
		"saw_red": false,
		"saw_dim": false,
		"maximum_unguarded_red_fraction": 0.0,
		"maximum_guarded_red_fraction": 0.0,
		"maximum_unguarded_bright_fraction": 0.0,
		"maximum_guarded_bright_fraction": 0.0,
	}
	for step in int(round(PULSE_PERIOD / FRAME_STEP)) + 1:
		activity.set_activity_time(float(step) * FRAME_STEP)
		for lens in lenses:
			var material := lens.material_override as StandardMaterial3D
			result.saw_red = (
				bool(result.saw_red)
				or material.albedo_color.is_equal_approx(Color("ff6b60"))
			)
			result.saw_dim = (
				bool(result.saw_dim)
				or material.albedo_color.is_equal_approx(Color("347b80"))
			)
			# Follow the live lens around its current route and place the real
			# player's near plane 2.5 mm in front of each face. The unguarded
			# render must recreate the pane before the guarded render can pass.
			for side in [-1.0, 1.0]:
				var lens_normal: Vector3 = (
					lens.global_basis * Vector3.BACK * float(side)
				).normalized()
				camera.global_position = (
					lens.global_position
					+ lens_normal * (
						camera.near + LENS_HALF_DEPTH + NEAR_PLANE_WITNESS_EPSILON
					)
				)
				camera.look_at(lens.global_position - lens_normal)

				lens.visibility_range_begin = 0.0
				await process_frame
				await RenderingServer.frame_post_draw
				var unguarded_image := root.get_texture().get_image()
				result.maximum_unguarded_red_fraction = maxf(
					float(result.maximum_unguarded_red_fraction),
					_red_pixel_fraction(unguarded_image)
				)
				result.maximum_unguarded_bright_fraction = maxf(
					float(result.maximum_unguarded_bright_fraction),
					_bright_pixel_fraction(unguarded_image)
				)

				lens.visibility_range_begin = DRONE_CAMERA_CLEARANCE_DISTANCE
				await process_frame
				await RenderingServer.frame_post_draw
				var guarded_image := root.get_texture().get_image()
				result.maximum_guarded_red_fraction = maxf(
					float(result.maximum_guarded_red_fraction),
					_red_pixel_fraction(guarded_image)
				)
				result.maximum_guarded_bright_fraction = maxf(
					float(result.maximum_guarded_bright_fraction),
					_bright_pixel_fraction(guarded_image)
				)
	result["passed"] = (
		bool(result.saw_red)
		and bool(result.saw_dim)
		and int(result.lens_count) == 2
		and float(result.maximum_unguarded_red_fraction) >= 0.08
		and float(result.maximum_guarded_red_fraction) < 0.08
	)
	return result


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


func _bright_pixel_fraction(image: Image) -> float:
	if image.is_empty():
		return 1.0
	var bright_pixels := 0
	var sampled_pixels := 0
	for y in range(0, image.get_height(), 3):
		for x in range(0, image.get_width(), 3):
			var color := image.get_pixel(x, y)
			if color.get_luminance() > 0.8:
				bright_pixels += 1
			sampled_pixels += 1
	return float(bright_pixels) / float(maxi(sampled_pixels, 1))
