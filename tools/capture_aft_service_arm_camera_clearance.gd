extends SceneTree

## Short Forward+ regression capture for the Aft articulated service-arm
## near-plane slice. The camera and arm remain at one exact production pose;
## only the renderer-native whole-assembly dependency is removed/restored.

const ACTIVITY_SCENE := preload(
	"res://scenes/world/components/station_operations_activity.tscn"
)
const UNGUARDED_OUTPUT := "/tmp/mudds-aft-service-arm-unguarded.png"
const GUARDED_OUTPUT := "/tmp/mudds-aft-service-arm-guarded.png"
const PRODUCTION_SEED := 2207
const MAXIMUM_SPAN_TIME := 196.25409
const PRODUCTION_CAMERA_NEAR := 0.08
const NEAR_PLANE_WITNESS_EPSILON := 0.0025
const FORK_HALF_HEIGHT := 0.62 * 0.5
const BACKGROUND := Color("071119")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(960, 540)
	var stage := Node3D.new()
	root.add_child(stage)

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

	var activity := ACTIVITY_SCENE.instantiate() as StationOperationsActivity
	activity.activity_profile = StationOperationsActivity.ActivityProfile.SERVICE_ARM
	activity.variation_seed = PRODUCTION_SEED
	activity.starts_paused = true
	stage.add_child(activity)
	await process_frame
	activity.set_activity_time(MAXIMUM_SPAN_TIME)

	var shoulder := activity.get_node(
		^"PresentationRoot/ArticulatedServiceArm/AnimatedShoulder"
	) as Node3D
	var guard := shoulder.get_node(^"WholeAssemblyCameraGuard") as MeshInstance3D
	var fork := shoulder.get_node(
		^"AnimatedElbow/AnimatedToolHead/DiagnosticFork2"
	) as MeshInstance3D
	var dependents: Array[MeshInstance3D] = []
	for candidate in shoulder.find_children("*", "MeshInstance3D", true, false):
		var arm_mesh := candidate as MeshInstance3D
		if arm_mesh != guard:
			dependents.append(arm_mesh)

	var camera := Camera3D.new()
	camera.near = PRODUCTION_CAMERA_NEAR
	camera.current = true
	stage.add_child(camera)
	var face_center := fork.global_transform * Vector3(0.0, FORK_HALF_HEIGHT, 0.0)
	var face_normal := (fork.global_basis * Vector3.UP).normalized()
	camera.global_position = face_center + face_normal * (
		PRODUCTION_CAMERA_NEAR + NEAR_PLANE_WITNESS_EPSILON
	)
	camera.look_at(face_center - face_normal)

	for arm_mesh in dependents:
		arm_mesh.visibility_parent = NodePath()
	await process_frame
	await RenderingServer.frame_post_draw
	var unguarded := root.get_texture().get_image()
	var unguarded_error := unguarded.save_png(UNGUARDED_OUTPUT)

	for arm_mesh in dependents:
		arm_mesh.visibility_parent = arm_mesh.get_path_to(guard)
	await process_frame
	await RenderingServer.frame_post_draw
	var guarded := root.get_texture().get_image()
	var guarded_error := guarded.save_png(GUARDED_OUTPUT)

	var unguarded_foreground := _foreground_fraction(unguarded)
	var guarded_foreground := _foreground_fraction(guarded)
	var passed := (
		unguarded_error == OK
		and guarded_error == OK
		and dependents.size() == 9
		and unguarded_foreground >= 0.20
		and guarded_foreground < 0.02
	)
	print(
		(
			"SERVICE_ARM_CAMERA_CLEARANCE_RENDER: seed=%d time=%.5f dependents=%d "
			+ "unguarded_foreground=%.6f guarded_foreground=%.6f passed=%s"
		)
		% [
			PRODUCTION_SEED,
			MAXIMUM_SPAN_TIME,
			dependents.size(),
			unguarded_foreground,
			guarded_foreground,
			passed,
		]
	)
	print("SERVICE_ARM_CAMERA_CLEARANCE_UNGUARDED: %s" % UNGUARDED_OUTPUT)
	print("SERVICE_ARM_CAMERA_CLEARANCE_GUARDED: %s" % GUARDED_OUTPUT)
	if not passed:
		push_error("Aft service-arm Forward+ camera-clearance reproduction failed")
	quit(0 if passed else 1)


func _foreground_fraction(image: Image) -> float:
	if image.is_empty():
		return 1.0
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
