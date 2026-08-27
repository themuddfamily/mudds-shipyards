extends SceneTree

## Two native Forward+ frames at the same normal chase composition: nominal,
## then the existing failed core-systems ledger cants the retained recon head.

const ARROW_SCENE := preload("res://scenes/ships/arrow_recon_ship.tscn")
const ShipComponentDamageType := preload("res://scripts/combat/ship_component_damage.gd")
const OUTPUT_DIR := "res://artifacts/arrow_core_systems_damage_silhouette"
const CAPTURE_SIZE := Vector2i(1600, 900)

var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = CAPTURE_SIZE
	root.content_scale_size = Vector2i.ZERO
	root.use_taa = true
	root.msaa_3d = Viewport.MSAA_2X
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))

	var world := Node3D.new()
	world.name = "ArrowCoreSystemsDamageCaptureWorld"
	root.add_child(world)
	_install_environment(world)
	var arrow := ARROW_SCENE.instantiate() as ArrowReconShip
	world.add_child(arrow)
	await process_frame
	await physics_frame

	var camera := Camera3D.new()
	camera.position = Vector3(8.8, 6.6, 23.5)
	camera.near = 0.05
	camera.far = 180.0
	camera.fov = 54.0
	world.add_child(camera)
	camera.look_at(Vector3(0.0, 1.55, 1.25), Vector3.UP)
	camera.current = true
	await _settle(8)
	_check(await _save_frame("01_nominal_chase.png"), "the nominal chase frame saves")

	var core_position := _component_local_position(
		arrow, ShipComponentDamageType.COMPONENT_CORE_SYSTEMS
	)
	for _hit in 2:
		arrow.apply_damage(arrow.maximum_hull * 0.16, arrow.to_global(core_position), Vector3.UP)
	var failed := arrow.get_core_systems_damage_silhouette_snapshot()
	_check(
		failed.get("stage", &"") == &"failed" and bool(failed.get("active", false)),
		"the capture uses the production failed core-systems state"
	)
	_check(await _save_frame("02_failed_chase.png"), "the failed chase comparison frame saves")

	world.queue_free()
	await process_frame
	if _failures.is_empty():
		print("ARROW_CORE_SYSTEMS_DAMAGE_SILHOUETTE_CAPTURE_OK: %s" % OUTPUT_DIR)
		quit(0)
		return
	quit(1)


func _install_environment(world: Node3D) -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("06101b")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("8fa9c0")
	settings.ambient_light_energy = 0.34
	settings.tonemap_mode = Environment.TONE_MAPPER_AGX
	settings.glow_enabled = true
	settings.glow_intensity = 0.55
	settings.glow_bloom = 0.08
	environment.environment = settings
	world.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-42.0, -32.0, 0.0)
	key.light_color = Color("d8eaff")
	key.light_energy = 1.25
	key.shadow_enabled = true
	world.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(28.0, 142.0, 0.0)
	rim.light_color = Color("75dce5")
	rim.light_energy = 0.58
	world.add_child(rim)


func _component_local_position(ship: HeroShip, component_id: StringName) -> Vector3:
	for component in ship.get_component_damage_report().get("components", []) as Array:
		if StringName((component as Dictionary).get("id", &"")) == component_id:
			return (component as Dictionary).get("local_position", Vector3.INF) as Vector3
	return Vector3.INF


func _settle(frame_count: int) -> void:
	for _frame in frame_count:
		await process_frame
		await physics_frame


func _save_frame(file_name: String) -> bool:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.is_empty() or image.get_size() != CAPTURE_SIZE:
		return false
	var output_path := "%s/%s" % [OUTPUT_DIR, file_name]
	if image.save_png(ProjectSettings.globalize_path(output_path)) != OK:
		return false
	print("CAPTURED: %s" % output_path)
	return true


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	_failures.append(message)
	push_error("FAIL: %s" % message)
