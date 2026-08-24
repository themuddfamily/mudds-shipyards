extends SceneTree

## Forward+ regression capture for the service-drone near-plane defect.
## It follows both production drones in the Central FULL and Habitat
## DRONE_PATROL profiles through a complete pulse using their production seeds.
## At representative ceramic, graphite and emissive surfaces it first recreates
## the composite pane by disabling all ten renderers, then restores the common
## production cutoff on all ten and renders the identical frame. A third render
## with the whole drone hidden proves the guarded result contains no residual
## child rather than merely replacing one near-plane slice with another.

const ACTIVITY_SCENE := preload(
	"res://scenes/world/components/station_operations_activity.tscn"
)
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const OUTPUT_PATH := "/tmp/mudds-full-drone-camera-clearance.png"
const PULSE_PERIOD := 1.35
const FRAME_STEP := 0.025
const DRONE_CAMERA_CLEARANCE_DISTANCE := 1.85
const NEAR_PLANE_WITNESS_EPSILON := 0.0025
const FULL_PRODUCTION_SEED := 1103
const ROOF_PATROL_PRODUCTION_SEED := 3301
const MINIMUM_COMPOSITE_INTRUSION_FRACTION := 0.18
const MAXIMUM_GUARDED_BASELINE_DIFFERENCE := 0.002
const MAXIMUM_GUARDED_RED_FRACTION := 0.08
const WITNESS_SPECS := [
	{"path": ^"Body", "role": &"ceramic_body", "outward": Vector3.BACK},
	{"path": ^"CargoPod", "role": &"graphite_cargo", "outward": Vector3.DOWN},
	{"path": ^"Thruster", "role": &"graphite_port_thruster", "outward": Vector3.LEFT},
	{"path": ^"Thruster2", "role": &"graphite_starboard_thruster", "outward": Vector3.RIGHT},
	{"path": ^"ThrusterGlow", "role": &"emissive_port_thruster", "outward": Vector3.LEFT},
	{"path": ^"ThrusterGlow2", "role": &"emissive_starboard_thruster", "outward": Vector3.RIGHT},
	{"path": ^"NavigationLens", "role": &"emissive_navigation", "outward": Vector3.FORWARD},
]


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

	# The inspectable output is a two-row witness sheet: FULL then DRONE_PATROL,
	# unguarded on the left and the identical guarded frame on the right.
	var save_error := _save_witness_sheet(profile_results)

	var passed := save_error == OK
	for result in profile_results:
		passed = passed and bool(result.passed)
		print(
			"DRONE_CAMERA_CLEARANCE_RENDER: profile=%s seed=%d drones=%d meshes=%d witnesses=%d production_guard=%s pulse=%.2fs red=%s dim=%s minimum_intrusion=%.6f maximum_guarded_baseline_difference=%.6f maximum_unguarded_red=%.6f maximum_guarded_red=%.6f"
			% [
				String(result.profile_id),
				int(result.seed),
				int(result.drone_count),
				int(result.mesh_count),
				int(result.witness_count),
				bool(result.production_guard_complete),
				PULSE_PERIOD,
				bool(result.saw_red),
				bool(result.saw_dim),
				float(result.minimum_composite_intrusion_fraction),
				float(result.maximum_guarded_baseline_difference),
				float(result.maximum_unguarded_red_fraction),
				float(result.maximum_guarded_red_fraction),
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
	var drones: Array[Node3D] = []
	var red_times := PackedFloat32Array([-1.0, -1.0])
	var saw_red := false
	var saw_dim := false
	for drone_index in 2:
		drones.append(activity.get_node(
			NodePath(
				"PresentationRoot/AnimatedServiceDrone%02d"
				% (drone_index + 1)
			)
		) as Node3D)
	# Scan the complete production pulse without rendering. Each drone must expose
	# both material states, and its red time becomes the fixed transform used for
	# every composite surface witness below.
	for step in int(round(PULSE_PERIOD / FRAME_STEP)) + 1:
		var seconds := float(step) * FRAME_STEP
		activity.set_activity_time(seconds)
		for drone_index in drones.size():
			var lens := drones[drone_index].get_node(^"NavigationLens") as MeshInstance3D
			var material := lens.material_override as StandardMaterial3D
			var is_red := material.albedo_color.is_equal_approx(Color("ff6b60"))
			var is_dim := material.albedo_color.is_equal_approx(Color("347b80"))
			saw_red = saw_red or is_red
			saw_dim = saw_dim or is_dim
			if is_red and red_times[drone_index] < 0.0:
				red_times[drone_index] = seconds
	var result := {
		"profile_id": activity.get_activity_profile_id(),
		"seed": activity.variation_seed,
		"drone_count": drones.size(),
		"mesh_count": 0,
		"witness_count": 0,
		"production_guard_complete": true,
		"saw_red": saw_red,
		"saw_dim": saw_dim,
		"minimum_composite_intrusion_fraction": 1.0,
		"maximum_guarded_baseline_difference": 0.0,
		"maximum_unguarded_red_fraction": 0.0,
		"maximum_guarded_red_fraction": 0.0,
		"best_intrusion_fraction": -1.0,
		"best_unguarded_image": null,
		"best_guarded_image": null,
	}
	for drone_index in drones.size():
		var drone := drones[drone_index]
		var drone_meshes: Array[MeshInstance3D] = []
		for candidate in drone.find_children("*", "MeshInstance3D", true, false):
			var drone_mesh := candidate as MeshInstance3D
			drone_meshes.append(drone_mesh)
			result.production_guard_complete = (
				bool(result.production_guard_complete)
				and is_equal_approx(
					drone_mesh.visibility_range_begin,
					DRONE_CAMERA_CLEARANCE_DISTANCE
				)
				and is_zero_approx(drone_mesh.visibility_range_begin_margin)
				and is_zero_approx(drone_mesh.visibility_range_end)
				and is_zero_approx(drone_mesh.visibility_range_end_margin)
				and drone_mesh.visibility_range_fade_mode
					== GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
			)
		result.mesh_count = int(result.mesh_count) + drone_meshes.size()
		if red_times[drone_index] < 0.0:
			continue
		activity.set_activity_time(red_times[drone_index])
		for spec_value in WITNESS_SPECS:
			var spec := spec_value as Dictionary
			var witness := drone.get_node(spec.path as NodePath) as MeshInstance3D
			var outward := spec.outward as Vector3
			var aabb := witness.get_aabb()
			var local_face := aabb.get_center() + Vector3(
				outward.x * aabb.size.x * 0.5,
				outward.y * aabb.size.y * 0.5,
				outward.z * aabb.size.z * 0.5
			)
			var face_center := witness.global_transform * local_face
			var face_normal := (witness.global_basis * outward).normalized()
			camera.global_position = face_center + face_normal * (
				camera.near + NEAR_PLANE_WITNESS_EPSILON
			)
			camera.look_at(face_center - face_normal)

			_set_drone_clearance(drone_meshes, 0.0)
			var unguarded_image := await _render_current_frame()
			_set_drone_clearance(drone_meshes, DRONE_CAMERA_CLEARANCE_DISTANCE)
			var guarded_image := await _render_current_frame()
			drone.visible = false
			var hidden_baseline := await _render_current_frame()
			drone.visible = true

			var intrusion_fraction := _image_difference_fraction(
				unguarded_image, guarded_image
			)
			var guarded_baseline_difference := _image_difference_fraction(
				guarded_image, hidden_baseline
			)
			result.witness_count = int(result.witness_count) + 1
			result.minimum_composite_intrusion_fraction = minf(
				float(result.minimum_composite_intrusion_fraction), intrusion_fraction
			)
			result.maximum_guarded_baseline_difference = maxf(
				float(result.maximum_guarded_baseline_difference),
				guarded_baseline_difference
			)
			result.maximum_unguarded_red_fraction = maxf(
				float(result.maximum_unguarded_red_fraction),
				_red_pixel_fraction(unguarded_image)
			)
			result.maximum_guarded_red_fraction = maxf(
				float(result.maximum_guarded_red_fraction),
				_red_pixel_fraction(guarded_image)
			)
			if intrusion_fraction > float(result.best_intrusion_fraction):
				result.best_intrusion_fraction = intrusion_fraction
				result.best_unguarded_image = unguarded_image
				result.best_guarded_image = guarded_image
			print(
				"DRONE_COMPOSITE_WITNESS: profile=%s drone=%d role=%s intrusion=%.6f guarded_baseline_difference=%.6f"
				% [
					String(result.profile_id),
					drone_index + 1,
					String(spec.role),
					intrusion_fraction,
					guarded_baseline_difference,
				]
			)
	result["passed"] = (
		bool(result.saw_red)
		and bool(result.saw_dim)
		and int(result.drone_count) == 2
		and int(result.mesh_count) == 20
		and int(result.witness_count) == WITNESS_SPECS.size() * 2
		and bool(result.production_guard_complete)
		and float(result.minimum_composite_intrusion_fraction)
			>= MINIMUM_COMPOSITE_INTRUSION_FRACTION
		and float(result.maximum_guarded_baseline_difference)
			<= MAXIMUM_GUARDED_BASELINE_DIFFERENCE
		and float(result.maximum_unguarded_red_fraction) >= 0.08
		and float(result.maximum_guarded_red_fraction) < MAXIMUM_GUARDED_RED_FRACTION
	)
	return result


func _set_drone_clearance(meshes: Array[MeshInstance3D], distance: float) -> void:
	for mesh_instance in meshes:
		mesh_instance.visibility_range_begin = distance


func _render_current_frame() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _save_witness_sheet(results: Array[Dictionary]) -> Error:
	if results.size() != 2:
		return ERR_INVALID_DATA
	var first := results[0].best_unguarded_image as Image
	if first == null or first.is_empty():
		return ERR_INVALID_DATA
	var sheet := Image.create(
		first.get_width() * 2,
		first.get_height() * results.size(),
		false,
		first.get_format()
	)
	for row in results.size():
		var unguarded := results[row].best_unguarded_image as Image
		var guarded := results[row].best_guarded_image as Image
		if unguarded == null or guarded == null:
			return ERR_INVALID_DATA
		var source_rect := Rect2i(Vector2i.ZERO, unguarded.get_size())
		sheet.blit_rect(unguarded, source_rect, Vector2i(0, row * first.get_height()))
		sheet.blit_rect(
			guarded,
			source_rect,
			Vector2i(first.get_width(), row * first.get_height())
		)
	return sheet.save_png(OUTPUT_PATH)


func _image_difference_fraction(first: Image, second: Image) -> float:
	if first.is_empty() or second.is_empty() or first.get_size() != second.get_size():
		return 1.0
	var different_pixels := 0
	var sampled_pixels := 0
	for y in range(0, first.get_height(), 3):
		for x in range(0, first.get_width(), 3):
			var first_color := first.get_pixel(x, y)
			var second_color := second.get_pixel(x, y)
			if Vector3(first_color.r, first_color.g, first_color.b).distance_to(
				Vector3(second_color.r, second_color.g, second_color.b)
			) > 0.08:
				different_pixels += 1
			sampled_pixels += 1
	return float(different_pixels) / float(maxi(sampled_pixels, 1))


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
