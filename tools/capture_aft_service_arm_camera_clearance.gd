extends SceneTree

## Bounded Forward+ regression capture for both collision-free station-operation
## assemblies that can cross the live walking-camera near plane. Each three-panel
## sheet is ordinary production view | deliberately unguarded contact | guarded
## contact. The ordinary view is also rendered once without the guard and must be
## pixel-identical, proving the supported near range does not hide normal views.

const ACTIVITY_SCENE := preload(
	"res://scenes/world/components/station_operations_activity.tscn"
)
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const ARM_OUTPUT := "/tmp/mudds-aft-service-arm-camera-clearance.png"
const BEACON_OUTPUT := "/tmp/mudds-freight-beacon-camera-clearance.png"
const SERVICE_ARM_CAMERA_CLEARANCE_DISTANCE := 5.1
const SAFETY_BEACON_CAMERA_CLEARANCE_DISTANCE := 0.61
const ARM_PRODUCTION_SEED := 2207
const ARM_PAIRWISE_SPAN_TIME := 6.13477
const FREIGHT_PRODUCTION_SEED := 8821
const FREIGHT_PRODUCTION_TRANSFORM := Transform3D(
	Basis(Vector3.UP, deg_to_rad(-90.0)), Vector3(-41.0, 6.18, 29.0)
)
const NEAR_PLANE_WITNESS_EPSILON := 0.0025
const BACKGROUND := Color("071119")
const MAXIMUM_GUARDED_BASELINE_DIFFERENCE := 0.002
const MAXIMUM_ORDINARY_GUARD_DIFFERENCE := 0.002
const MINIMUM_NEAR_INTRUSION := 0.12
const MINIMUM_ORDINARY_FOREGROUND := 0.004


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(960, 540)
	var stage := Node3D.new()
	root.add_child(stage)
	_build_lighting(stage)

	var player := PLAYER_SCENE.instantiate() as PlayerController
	stage.add_child(player)
	await process_frame
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var camera := player.get_node(
		^"CameraRig/CameraYaw/CameraPitch/SpringArm3D/PlayerCamera"
	) as Camera3D
	camera.top_level = true
	camera.current = true

	var arm_activity := ACTIVITY_SCENE.instantiate() as StationOperationsActivity
	arm_activity.activity_profile = StationOperationsActivity.ActivityProfile.SERVICE_ARM
	arm_activity.variation_seed = ARM_PRODUCTION_SEED
	arm_activity.starts_paused = true
	stage.add_child(arm_activity)
	await process_frame
	arm_activity.set_activity_time(ARM_PAIRWISE_SPAN_TIME)
	var arm_result := await _capture_arm(arm_activity, camera)

	arm_activity.visible = false
	var freight_activity := ACTIVITY_SCENE.instantiate() as StationOperationsActivity
	freight_activity.name = "FreightApproachSignage"
	freight_activity.activity_profile = StationOperationsActivity.ActivityProfile.SIGNAGE_PYLON
	freight_activity.variation_seed = FREIGHT_PRODUCTION_SEED
	freight_activity.starts_paused = true
	freight_activity.transform = FREIGHT_PRODUCTION_TRANSFORM
	stage.add_child(freight_activity)
	await process_frame
	_set_first_beacon_lit(freight_activity)
	var beacon_result := await _capture_beacon(freight_activity, camera)

	var arm_save_error := _save_sheet(arm_result.images as Array, ARM_OUTPUT)
	var beacon_save_error := _save_sheet(
		beacon_result.images as Array, BEACON_OUTPUT
	)
	var passed := (
		arm_save_error == OK
		and beacon_save_error == OK
		and bool(arm_result.passed)
		and bool(beacon_result.passed)
	)
	print(
		(
			"SERVICE_ARM_CAMERA_CLEARANCE_RENDER: seed=%d time=%.3f near=%.3f "
			+ "meshes=%d production_guard=%s ordinary_foreground=%.6f "
			+ "ordinary_guard_difference=%.6f near_intrusion=%.6f "
			+ "guarded_baseline_difference=%.6f passed=%s"
		) % [
			ARM_PRODUCTION_SEED,
			ARM_PAIRWISE_SPAN_TIME,
			camera.near,
			int(arm_result.mesh_count),
			bool(arm_result.production_guard_complete),
			float(arm_result.ordinary_foreground),
			float(arm_result.ordinary_guard_difference),
			float(arm_result.near_intrusion),
			float(arm_result.guarded_baseline_difference),
			bool(arm_result.passed),
		]
	)
	print(
		(
			"FREIGHT_BEACON_CAMERA_CLEARANCE_RENDER: profile=%s seed=%d near=%.3f "
			+ "meshes=%d production_guard=%s amber_lit=%s ordinary_foreground=%.6f "
			+ "ordinary_guard_difference=%.6f near_intrusion=%.6f "
			+ "guarded_baseline_difference=%.6f passed=%s"
		) % [
			freight_activity.get_activity_profile_id(),
			FREIGHT_PRODUCTION_SEED,
			camera.near,
			int(beacon_result.mesh_count),
			bool(beacon_result.production_guard_complete),
			bool(beacon_result.amber_lit),
			float(beacon_result.ordinary_foreground),
			float(beacon_result.ordinary_guard_difference),
			float(beacon_result.near_intrusion),
			float(beacon_result.guarded_baseline_difference),
			bool(beacon_result.passed),
		]
	)
	print("SERVICE_ARM_CAMERA_CLEARANCE_OUTPUT: %s" % ARM_OUTPUT)
	print("FREIGHT_BEACON_CAMERA_CLEARANCE_OUTPUT: %s" % BEACON_OUTPUT)
	if not passed:
		push_error("station operations Forward+ camera-clearance capture failed")
	quit(0 if passed else 1)


func _build_lighting(stage: Node3D) -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = BACKGROUND
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b5d4dc")
	environment.ambient_light_energy = 1.2
	world_environment.environment = environment
	stage.add_child(world_environment)
	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-52.0, -38.0, 0.0)
	key_light.light_energy = 1.5
	stage.add_child(key_light)


func _capture_arm(
		activity: StationOperationsActivity,
		camera: Camera3D
	) -> Dictionary:
	var shoulder := activity.get_node(
		^"PresentationRoot/ArticulatedServiceArm/AnimatedShoulder"
	) as Node3D
	var meshes: Array[MeshInstance3D] = []
	var production_guard_complete := true
	for candidate in shoulder.find_children("*", "MeshInstance3D", true, false):
		var mesh := candidate as MeshInstance3D
		meshes.append(mesh)
		production_guard_complete = (
			production_guard_complete
			and _has_hard_guard(mesh, SERVICE_ARM_CAMERA_CLEARANCE_DISTANCE)
		)

	camera.global_position = shoulder.global_position + Vector3(6.5, 3.8, 6.5)
	camera.look_at(shoulder.global_position + Vector3(0.0, 1.7, 0.0))
	var ordinary_guarded := await _render_current_frame()
	_set_clearance(meshes, 0.0)
	var ordinary_unguarded := await _render_current_frame()
	_set_clearance(meshes, SERVICE_ARM_CAMERA_CLEARANCE_DISTANCE)

	var witness := shoulder.get_node(^"ShoulderJoint") as MeshInstance3D
	var face_center := witness.global_transform * Vector3(0.42, 0.0, 0.0)
	var face_normal := (witness.global_basis * Vector3.RIGHT).normalized()
	camera.global_position = face_center + face_normal * (
		camera.near + NEAR_PLANE_WITNESS_EPSILON
	)
	camera.look_at(face_center - face_normal, Vector3.FORWARD)
	_set_clearance(meshes, 0.0)
	var near_unguarded := await _render_current_frame()
	_set_clearance(meshes, SERVICE_ARM_CAMERA_CLEARANCE_DISTANCE)
	var near_guarded := await _render_current_frame()
	shoulder.visible = false
	var hidden_baseline := await _render_current_frame()
	shoulder.visible = true

	var ordinary_guard_difference := _image_difference_fraction(
		ordinary_guarded, ordinary_unguarded
	)
	var near_intrusion := _image_difference_fraction(near_unguarded, near_guarded)
	var guarded_baseline_difference := _image_difference_fraction(
		near_guarded, hidden_baseline
	)
	var ordinary_foreground := _foreground_fraction(ordinary_guarded)
	return {
		"images": [ordinary_guarded, near_unguarded, near_guarded],
		"mesh_count": meshes.size(),
		"production_guard_complete": production_guard_complete,
		"ordinary_foreground": ordinary_foreground,
		"ordinary_guard_difference": ordinary_guard_difference,
		"near_intrusion": near_intrusion,
		"guarded_baseline_difference": guarded_baseline_difference,
		"passed": (
			meshes.size() == 9
			and production_guard_complete
			and ordinary_foreground >= MINIMUM_ORDINARY_FOREGROUND
			and ordinary_guard_difference <= MAXIMUM_ORDINARY_GUARD_DIFFERENCE
			and near_intrusion >= MINIMUM_NEAR_INTRUSION
			and guarded_baseline_difference <= MAXIMUM_GUARDED_BASELINE_DIFFERENCE
		),
	}


func _capture_beacon(
		activity: StationOperationsActivity,
		camera: Camera3D
	) -> Dictionary:
	var beacon := activity.get_node(^"PresentationRoot/SafetyBeacon01") as Node3D
	var base := beacon.get_node(^"Base") as MeshInstance3D
	var lens := beacon.get_node(^"Lens") as MeshInstance3D
	var meshes: Array[MeshInstance3D] = [base, lens]
	var production_guard_complete := true
	for mesh in meshes:
		production_guard_complete = (
			production_guard_complete
			and _has_hard_guard(mesh, SAFETY_BEACON_CAMERA_CLEARANCE_DISTANCE)
		)
	var material := lens.material_override as StandardMaterial3D
	var amber_lit := material != null and material.albedo_color.is_equal_approx(
		Color("ffc069")
	)

	camera.global_position = beacon.global_position + Vector3(1.7, 1.15, 2.1)
	camera.look_at(beacon.global_position + Vector3(0.0, 0.12, 0.0))
	var ordinary_guarded := await _render_current_frame()
	_set_clearance(meshes, 0.0)
	var ordinary_unguarded := await _render_current_frame()
	_set_clearance(meshes, SAFETY_BEACON_CAMERA_CLEARANCE_DISTANCE)

	var face_center := lens.global_transform * Vector3(0.0, 0.12, 0.0)
	var face_normal := (lens.global_basis * Vector3.UP).normalized()
	camera.global_position = face_center + face_normal * (
		camera.near + NEAR_PLANE_WITNESS_EPSILON
	)
	camera.look_at(face_center - face_normal, Vector3.FORWARD)
	_set_clearance(meshes, 0.0)
	var near_unguarded := await _render_current_frame()
	_set_clearance(meshes, SAFETY_BEACON_CAMERA_CLEARANCE_DISTANCE)
	var near_guarded := await _render_current_frame()
	beacon.visible = false
	var hidden_baseline := await _render_current_frame()
	beacon.visible = true

	var ordinary_guard_difference := _image_difference_fraction(
		ordinary_guarded, ordinary_unguarded
	)
	var near_intrusion := _image_difference_fraction(near_unguarded, near_guarded)
	var guarded_baseline_difference := _image_difference_fraction(
		near_guarded, hidden_baseline
	)
	var ordinary_foreground := _foreground_fraction(ordinary_guarded)
	return {
		"images": [ordinary_guarded, near_unguarded, near_guarded],
		"mesh_count": meshes.size(),
		"production_guard_complete": production_guard_complete,
		"amber_lit": amber_lit,
		"ordinary_foreground": ordinary_foreground,
		"ordinary_guard_difference": ordinary_guard_difference,
		"near_intrusion": near_intrusion,
		"guarded_baseline_difference": guarded_baseline_difference,
		"passed": (
			meshes.size() == 2
			and production_guard_complete
			and amber_lit
			and ordinary_foreground >= MINIMUM_ORDINARY_FOREGROUND
			and ordinary_guard_difference <= MAXIMUM_ORDINARY_GUARD_DIFFERENCE
			and near_intrusion >= MINIMUM_NEAR_INTRUSION
			and guarded_baseline_difference <= MAXIMUM_GUARDED_BASELINE_DIFFERENCE
		),
	}


func _set_first_beacon_lit(activity: StationOperationsActivity) -> void:
	for step in 81:
		activity.set_activity_time(float(step) * 0.025)
		var lens := activity.get_node(
			^"PresentationRoot/SafetyBeacon01/Lens"
		) as MeshInstance3D
		var material := lens.material_override as StandardMaterial3D
		if material != null and material.albedo_color.is_equal_approx(Color("ffc069")):
			return


func _has_hard_guard(mesh: MeshInstance3D, distance: float) -> bool:
	return (
		is_equal_approx(mesh.visibility_range_begin, distance)
		and is_zero_approx(mesh.visibility_range_begin_margin)
		and is_zero_approx(mesh.visibility_range_end)
		and is_zero_approx(mesh.visibility_range_end_margin)
		and mesh.visibility_range_fade_mode
			== GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		and mesh.visibility_parent == NodePath()
	)


func _set_clearance(meshes: Array[MeshInstance3D], distance: float) -> void:
	for mesh in meshes:
		mesh.visibility_range_begin = distance


func _render_current_frame() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _save_sheet(images: Array, output_path: String) -> Error:
	var first := images[0] as Image if not images.is_empty() else null
	if images.size() != 3 or first == null or first.is_empty():
		return ERR_INVALID_DATA
	var size := first.get_size()
	var sheet := Image.create_empty(size.x * 3, size.y, false, first.get_format())
	for index in images.size():
		var image := images[index] as Image
		if image == null or image.get_size() != size:
			return ERR_INVALID_DATA
		sheet.blit_rect(image, Rect2i(Vector2i.ZERO, size), Vector2i(index * size.x, 0))
	return sheet.save_png(output_path)


func _foreground_fraction(image: Image) -> float:
	if image == null or image.is_empty():
		return 0.0
	var foreground_pixels := 0
	var sampled_pixels := 0
	for y in range(0, image.get_height(), 3):
		for x in range(0, image.get_width(), 3):
			var color := image.get_pixel(x, y)
			if Vector3(color.r, color.g, color.b).distance_to(
				Vector3(BACKGROUND.r, BACKGROUND.g, BACKGROUND.b)
			) > 0.08:
				foreground_pixels += 1
			sampled_pixels += 1
	return float(foreground_pixels) / float(maxi(sampled_pixels, 1))


func _image_difference_fraction(first: Image, second: Image) -> float:
	if (
		first == null
		or second == null
		or first.is_empty()
		or second.is_empty()
		or first.get_size() != second.get_size()
	):
		return 1.0
	var different_pixels := 0
	var sampled_pixels := 0
	for y in range(0, first.get_height(), 2):
		for x in range(0, first.get_width(), 2):
			var a := first.get_pixel(x, y)
			var b := second.get_pixel(x, y)
			if Vector3(a.r, a.g, a.b).distance_to(Vector3(b.r, b.g, b.b)) > 0.03:
				different_pixels += 1
			sampled_pixels += 1
	return float(different_pixels) / float(maxi(sampled_pixels, 1))
