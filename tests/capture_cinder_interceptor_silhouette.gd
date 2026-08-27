extends SceneTree

## Stable gameplay-distance presentation capture for the NEW Cinder light
## interceptor. It compares nominal and existing failed engine-bay state through
## the production damage entry; the harness owns only its evidence camera and
## lighting, not flight, collision, boarding, weapons, handling, or berth fit.

const Interceptor := preload("res://scripts/ships/cinder_light_interceptor.gd")
const ShipComponentDamageType := preload("res://scripts/combat/ship_component_damage.gd")
const RESOLUTION := Vector2i(1600, 900)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var label := OS.get_environment("MUDDS_CINDER_INTERCEPTOR_CAPTURE_LABEL")
	if label.is_empty():
		label = "current"
	var output_dir := "res://artifacts/cinder_interceptor_silhouette/%s" % label
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))

	root.size = RESOLUTION
	var stage := Node3D.new()
	stage.name = "CinderInterceptorCaptureStage"
	root.add_child(stage)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("071018")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("718ba3")
	environment.ambient_light_energy = 0.48
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	stage.add_child(world_environment)

	var key := DirectionalLight3D.new()
	key.light_color = Color("fff0d5")
	key.light_energy = 2.4
	key.rotation_degrees = Vector3(-38.0, -32.0, 0.0)
	stage.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color("6fc8ff")
	rim.light_energy = 0.72
	rim.rotation_degrees = Vector3(-10.0, 150.0, 0.0)
	stage.add_child(rim)

	var nominal := Interceptor.new() as CinderLightInterceptor
	nominal.name = "NominalCinderLightInterceptor"
	nominal.position = Vector3(-4.4, 0.0, 0.0)
	stage.add_child(nominal)
	nominal.set_process(false)
	nominal.set_physics_process(false)
	var failed := Interceptor.new() as CinderLightInterceptor
	failed.name = "FailedEngineBayCinderLightInterceptor"
	failed.position = Vector3(4.4, 0.0, 0.0)
	stage.add_child(failed)
	failed.set_process(false)
	failed.set_physics_process(false)

	var camera := Camera3D.new()
	camera.name = "GameplayDistanceChaseCamera"
	camera.fov = 42.0
	camera.near = 0.1
	camera.far = 160.0
	camera.position = Vector3(14.5, 8.5, 27.0)
	camera.look_at_from_position(camera.position, Vector3(0.0, 0.35, 0.8), Vector3.UP)
	camera.current = true
	stage.add_child(camera)

	for _frame in 4:
		await process_frame
	var engine_position := _component_local_position(failed, ShipComponentDamageType.COMPONENT_ENGINE_BAY)
	var damage_per_hit := failed.maximum_hull * 0.1
	failed.apply_damage(damage_per_hit, failed.to_global(engine_position), failed.global_basis.z)
	failed.apply_damage(damage_per_hit, failed.to_global(engine_position), failed.global_basis.z)
	for _frame in 4:
		await process_frame
	var image := root.get_texture().get_image()
	var path := "%s/gameplay_distance_nominal_vs_failed_engine_bay.png" % output_dir
	var save_error := image.save_png(ProjectSettings.globalize_path(path))
	if save_error != OK:
		push_error("Cinder interceptor silhouette capture failed to save: %s" % error_string(save_error))
		quit(1)
		return
	print("CINDER_INTERCEPTOR_SILHOUETTE_CAPTURE %s" % path)
	quit(0)


func _component_local_position(ship: HeroShip, component_id: StringName) -> Vector3:
	for component in ship.get_component_damage_report().get("components", []) as Array:
		if StringName((component as Dictionary).get("id", &"")) == component_id:
			return (component as Dictionary).get("local_position", Vector3.ZERO) as Vector3
	return Vector3.ZERO
