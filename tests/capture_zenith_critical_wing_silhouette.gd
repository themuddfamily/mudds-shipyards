extends SceneTree

## One native Forward+ gameplay-distance comparison of the production Zenith's
## retained nominal and failed starboard-wing silhouettes.

const ZENITH_SCENE := preload("res://scenes/ships/zenith_interceptor.tscn")
const ComponentDamage := preload("res://scripts/combat/ship_component_damage.gd")
const RESOLUTION := Vector2i(1280, 720)
const PANEL_SIZE := Vector2i(640, 720)
const OUTPUT_PATH := "res://artifacts/zenith_critical_wing_silhouette/forward_plus_chase_comparison.png"

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
	var failed := await _build_panel(row, true)
	_add_label("NOMINAL // UPRIGHT WING SPAR", Vector2(24.0, 22.0))
	_add_label("FAILED // CANTED WING SPAR", Vector2(664.0, 22.0))
	for _frame in 16:
		await process_frame
	var nominal_snapshot := (nominal as ZenithInterceptor).get_starboard_wing_damage_cue_snapshot()
	var failed_snapshot := (failed as ZenithInterceptor).get_starboard_wing_damage_cue_snapshot()
	_check(
		nominal_snapshot.get("stage", &"") == &"nominal"
			and failed_snapshot.get("stage", &"") == &"failed"
			and failed_snapshot.get("silhouette_pose", &"") == &"failed_canted",
		"production panels retain nominal and failed local wing states"
	)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_check(image != null and not image.is_empty() and image.get_size() == RESOLUTION, "capture returns one stable comparison frame")
	if image != null and not image.is_empty():
		var output := ProjectSettings.globalize_path(OUTPUT_PATH)
		DirAccess.make_dir_recursive_absolute(output.get_base_dir())
		_check(image.save_png(output) == OK, "Forward+ comparison saves successfully")
		print("ZENITH_CRITICAL_WING_SILHOUETTE_CAPTURE: ", output)

	# Exercise the exact cameras used during normal play. The original evidence
	# camera only proves the external aft silhouette and cannot expose self-hull
	# intrusion at either production eye point.
	for craft in [nominal as ZenithInterceptor, failed as ZenithInterceptor]:
		craft.set_piloted(true)
		craft.set_cockpit_view(false)
	await _settle_physics(12)
	_check(
		(nominal as ZenithInterceptor).get_camera().current
			and (failed as ZenithInterceptor).get_camera().current
			and (nominal as ZenithInterceptor).get_camera().get_cull_mask_value(
				ZenithInterceptor.COCKPIT_FRAME_EXTERIOR_VISUAL_LAYER
			)
			and ZenithInterceptor.COCKPIT_FRAME_EXTERIOR_VISUAL_LAYER
				!= PilotSkinnedPresentation.LOCAL_OBSERVER_CULL_LAYER
			and (
				((1 << 20) - 1) & ~PilotSkinnedPresentation.LOCAL_OBSERVER_CULL_MASK
				& ZenithInterceptor.COCKPIT_FRAME_EXTERIOR_VISUAL_MASK
			) != 0,
		"both production chase cameras become authoritative"
	)
	await _save_audit_frame(
		"res://artifacts/zenith_critical_wing_silhouette/production_chase_comparison.png",
		"production chase"
	)

	for craft in [nominal as ZenithInterceptor, failed as ZenithInterceptor]:
		craft.set_cockpit_view(true)
	await _settle_physics(12)
	_check(
		(nominal as ZenithInterceptor).get_camera().current
			and (failed as ZenithInterceptor).get_camera().current
			and not (nominal as ZenithInterceptor).get_camera().get_cull_mask_value(
				ZenithInterceptor.COCKPIT_FRAME_EXTERIOR_VISUAL_LAYER
			),
		"both production cockpit cameras become authoritative"
	)
	var cockpit_frame := (nominal as ZenithInterceptor).find_child(
		"ModernSystemsCanopyPivotStaticBatch_GraphitePanel", true, false
	) as MeshInstance3D
	_check(
		cockpit_frame != null
			and cockpit_frame.layers
				== ZenithInterceptor.COCKPIT_FRAME_EXTERIOR_VISUAL_MASK
			and bool((nominal as ZenithInterceptor).get_zenith_audit_report().valid),
		"cockpit omits only the dedicated exterior frame layer while runtime audit stays green"
	)
	await _save_audit_frame(
		"res://artifacts/zenith_critical_wing_silhouette/production_cockpit_comparison.png",
		"production cockpit"
	)

	for craft in [nominal as ZenithInterceptor, failed as ZenithInterceptor]:
		craft.set_canopy_open(true, 0.0)
	await _settle_physics(6)
	_check(
		(nominal as ZenithInterceptor).is_canopy_open()
			and (failed as ZenithInterceptor).is_canopy_open()
			and not (nominal as ZenithInterceptor).get_camera().get_cull_mask_value(
				ZenithInterceptor.COCKPIT_FRAME_EXTERIOR_VISUAL_LAYER
			)
			and bool((nominal as ZenithInterceptor).get_zenith_audit_report().valid)
			and bool((failed as ZenithInterceptor).get_zenith_audit_report().valid),
		"nominal and damaged open-canopy cockpit lifecycle preserves the clear-view contract"
	)
	await _save_audit_frame(
		"res://artifacts/zenith_critical_wing_silhouette/production_cockpit_canopy_open_comparison.png",
		"production cockpit with canopy open"
	)

	for craft in [nominal as ZenithInterceptor, failed as ZenithInterceptor]:
		craft.set_cockpit_view(false)
	await _settle_physics(6)
	_check(
		(nominal as ZenithInterceptor).get_camera().get_cull_mask_value(
			ZenithInterceptor.COCKPIT_FRAME_EXTERIOR_VISUAL_LAYER
		)
			and (failed as ZenithInterceptor).get_camera().get_cull_mask_value(
				ZenithInterceptor.COCKPIT_FRAME_EXTERIOR_VISUAL_LAYER
			),
		"nominal and damaged chase cameras retain the complete open canopy"
	)
	await _save_audit_frame(
		"res://artifacts/zenith_critical_wing_silhouette/production_chase_canopy_open_comparison.png",
		"production chase with canopy open"
	)
	for craft in [nominal as ZenithInterceptor, failed as ZenithInterceptor]:
		craft.set_canopy_open(false, 0.0)
	await _settle_physics(6)
	_check(
		not (nominal as ZenithInterceptor).is_canopy_open()
			and not (failed as ZenithInterceptor).is_canopy_open()
			and bool((nominal as ZenithInterceptor).get_zenith_audit_report().valid)
			and bool((failed as ZenithInterceptor).get_zenith_audit_report().valid),
		"nominal and damaged canopy lifecycle reseals with both runtime audits green"
	)
	for craft in [nominal as ZenithInterceptor, failed as ZenithInterceptor]:
		craft.set_piloted(false)
	row.queue_free()
	await process_frame
	_finish()


func _build_panel(row: HBoxContainer, is_failed: bool) -> ZenithInterceptor:
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
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("050910")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("8298ad")
	environment.ambient_light_energy = 0.58
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	stage.add_child(world_environment)
	for light_rotation in [Vector3(-32.0, -34.0, 0.0), Vector3(20.0, 150.0, 0.0)]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = light_rotation
		light.light_energy = 1.6
		stage.add_child(light)
	var craft := ZENITH_SCENE.instantiate() as ZenithInterceptor
	stage.add_child(craft)
	await process_frame
	await physics_frame
	# This is a chase-view witness, not a landed repair simulation. Preserve the
	# ledger state while the renderer settles the frame.
	craft.set("_landed", false)
	if is_failed:
		var model := craft.get_component_damage()
		model.record_damage(craft.maximum_hull * 2.0, _component_local_position(craft, ComponentDamage.COMPONENT_STARBOARD_WING))
		# The production observer receives its ledger signal during the frame
		# boundary; wait before returning this panel to the comparison assertion.
		await process_frame
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 4.2, 18.5)
	camera.fov = 48.0
	camera.near = 0.05
	camera.far = 80.0
	stage.add_child(camera)
	camera.look_at(Vector3(0.0, 0.5, 0.9), Vector3.UP)
	camera.current = true
	return craft


func _add_label(value: String, position: Vector2) -> void:
	var label := Label.new()
	label.text = value
	label.position = position
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


func _settle_physics(count: int) -> void:
	for _frame in count:
		await physics_frame
		await process_frame


func _save_audit_frame(path: String, label: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_check(
		image != null and not image.is_empty() and image.get_size() == RESOLUTION,
		"%s capture returns one stable frame" % label
	)
	if image == null or image.is_empty():
		return
	var output := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	_check(image.save_png(output) == OK, "%s capture saves successfully" % label)
	print("ZENITH_CAMERA_AUDIT_CAPTURE: ", output)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	_failures.append(message)
	push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("ZENITH_CRITICAL_WING_SILHOUETTE_CAPTURE_OK")
		quit(0)
		return
	print("ZENITH_CRITICAL_WING_SILHOUETTE_CAPTURE_FAILED: %s" % "; ".join(_failures))
	quit(1)
