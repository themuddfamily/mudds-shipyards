extends SceneTree

## One native Forward+ comparison at the normal aft chase distance. Both halves
## instantiate the production Torrent; the right craft receives the existing
## critical engine-bay state and the left remains nominal.

const TORRENT_SCENE := preload("res://scenes/ships/torrent_interceptor.tscn")
const ComponentDamage := preload("res://scripts/combat/ship_component_damage.gd")
const RESOLUTION := Vector2i(1280, 720)
const PANEL_SIZE := Vector2i(640, 720)
const OUTPUT_PATH := "res://artifacts/torrent_engine_damage_silhouette/forward_plus_chase_comparison.png"

var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	root.size = RESOLUTION
	root.content_scale_size = Vector2i.ZERO
	root.use_taa = false
	root.msaa_3d = Viewport.MSAA_4X
	_check(
		RenderingServer.get_current_rendering_method() == &"forward_plus"
			and DisplayServer.get_name() == "X11",
		"capture uses native X11 Forward+"
	)

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 0)
	root.add_child(row)
	var nominal := await _build_panel(row, false)
	var critical := await _build_panel(row, true)
	_add_label("NOMINAL // SYMMETRIC CORES", Vector2(24.0, 22.0))
	_add_label("CRITICAL // STARBOARD CORE DROPPED", Vector2(664.0, 22.0))

	for _frame in 16:
		await process_frame
	var nominal_snapshot := (
		(nominal.get("presentation") as TorrentHeroPresentation)
		.get_engine_damage_silhouette_snapshot()
	)
	var critical_snapshot := (
		(critical.get("presentation") as TorrentHeroPresentation)
		.get_engine_damage_silhouette_snapshot()
	)
	_check(
		nominal_snapshot.stage == &"nominal"
			and int(nominal_snapshot.canted_core_count) == 0,
		"left production craft retains the nominal engine silhouette"
	)
	_check(
		critical_snapshot.stage == &"critical"
			and int(critical_snapshot.canted_core_count) == 1,
		"right production craft presents one dropped and canted critical core"
	)

	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_check(
		image != null and not image.is_empty() and image.get_size() == RESOLUTION,
		"capture returns one stable 1280x720 comparison frame"
	)
	if image != null and not image.is_empty():
		var output := ProjectSettings.globalize_path(OUTPUT_PATH)
		DirAccess.make_dir_recursive_absolute(output.get_base_dir())
		_check(image.save_png(output) == OK, "Forward+ comparison saves successfully")
		print("TORRENT_ENGINE_DAMAGE_SILHOUETTE_CAPTURE: ", output)

	row.queue_free()
	await process_frame
	_finish()


func _build_panel(row: HBoxContainer, critical: bool) -> Dictionary:
	var container := SubViewportContainer.new()
	container.custom_minimum_size = PANEL_SIZE
	container.stretch = true
	row.add_child(container)
	var viewport := SubViewport.new()
	viewport.size = PANEL_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	container.add_child(viewport)

	var stage := Node3D.new()
	viewport.add_child(stage)
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("050910")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("8298ad")
	environment.ambient_light_energy = 0.58
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	world_environment.environment = environment
	stage.add_child(world_environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-32.0, -34.0, 0.0)
	key.light_color = Color("fff0d7")
	key.light_energy = 2.2
	key.shadow_enabled = false
	stage.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(20.0, 150.0, 0.0)
	rim.light_color = Color("65bce8")
	rim.light_energy = 1.0
	rim.shadow_enabled = false
	stage.add_child(rim)

	var craft := TORRENT_SCENE.instantiate() as HeroShip
	stage.add_child(craft)
	await process_frame
	await process_frame
	craft.set_physics_process(false)
	craft.set("_landed", false)
	craft.set("_engine_state", HeroShip.ENGINE_ONLINE)
	craft.set("_throttle", 1.0)
	if critical:
		var model := craft.get_component_damage()
		var engine_position := _component_local_position(craft, ComponentDamage.COMPONENT_ENGINE_BAY)
		model.record_damage(craft.maximum_hull * 2.0, engine_position)
		_repair_engine_to(craft, 0.32)
	craft.call("_sync_engine_visuals_immediately")

	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 2.8, 14.5)
	camera.fov = 48.0
	camera.near = 0.05
	camera.far = 80.0
	stage.add_child(camera)
	camera.look_at(Vector3(0.0, 1.0, 1.4), Vector3.UP)
	camera.current = true
	var presentation := craft.get_node_or_null(
		^"TorrentVisual/TorrentHeroPresentation"
	) as TorrentHeroPresentation
	_check(presentation != null, "panel instantiates the production Torrent presentation")
	return {"craft": craft, "presentation": presentation, "viewport": viewport}


func _add_label(text_value: String, at: Vector2) -> void:
	var label := Label.new()
	label.text = text_value
	label.position = at
	label.add_theme_color_override("font_color", Color("dbe9ee"))
	label.add_theme_color_override("font_shadow_color", Color("020609"))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_font_size_override("font_size", 18)
	root.add_child(label)


func _component_local_position(craft: HeroShip, component_id: StringName) -> Vector3:
	for component_variant in craft.get_component_damage_report().get("components", []) as Array:
		var component := component_variant as Dictionary
		if StringName(component.get("id", &"")) == component_id:
			return component.get("local_position", Vector3.ZERO) as Vector3
	return Vector3.ZERO


func _repair_engine_to(craft: HeroShip, target_integrity: float) -> void:
	var model := craft.get_component_damage()
	var before := model.get_component_integrity(ComponentDamage.COMPONENT_ENGINE_BAY)
	var delta := maxf(
		(target_integrity - before) / maxf(model.repair_rate_per_second, 0.001),
		0.001
	)
	model.tick_component_repair(ComponentDamage.COMPONENT_ENGINE_BAY, delta, true)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	_failures.append(message)
	push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("TORRENT_ENGINE_DAMAGE_SILHOUETTE_CAPTURE_OK")
		quit(0)
		return
	print("TORRENT_ENGINE_DAMAGE_SILHOUETTE_CAPTURE_FAILED: %s" % "; ".join(_failures))
	quit(1)
