extends SceneTree

## One Xvfb Vulkan Forward+ gameplay-distance witness of the production
## perimeter asset's three truthful retained-geometry states plus a renewed
## generation that must be visually identical to intact.

const ASSET_SCENE := preload("res://scenes/activities/station_defense_perimeter_asset.tscn")
const CAPTURE_SIZE := Vector2i(1600, 900)
const OUTPUT_PATH := "/tmp/mudds-wave33-defense-asset-visual/artifacts/station_defense_perimeter_state_shape/all_states_forward_plus.png"
const STATE_POSITIONS := [Vector3(-9.0, 0.0, 0.0), Vector3(-3.0, 0.0, 0.0), Vector3(3.0, 0.0, 0.0), Vector3(9.0, 0.0, 0.0)]

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = CAPTURE_SIZE
	root.content_scale_size = Vector2i.ZERO
	root.msaa_3d = Viewport.MSAA_4X
	root.use_taa = true
	_check(
		RenderingServer.get_current_rendering_method() == &"forward_plus"
			and RenderingServer.get_rendering_device() != null,
		"capture uses Xvfb Vulkan Forward+"
	)
	if not _failures.is_empty():
		_finish()
		return
	var world := Node3D.new()
	root.add_child(world)
	_add_environment(world)
	_add_floor(world)
	var intact := _add_asset(world, 0, &"intact")
	var attack := _add_asset(world, 1, &"attack")
	var failed := _add_asset(world, 2, &"failed")
	var renewed := _add_asset(world, 3, &"renewed")
	var intact_presentation := intact.get_protected_asset_presentation_snapshot()
	var renewed_presentation := renewed.get_protected_asset_presentation_snapshot()
	_check(
		intact_presentation.silhouette_id == &"full_ring_intact"
			and attack.get_protected_asset_presentation_snapshot().silhouette_id == &"broad_shield_attack"
			and failed.get_protected_asset_presentation_snapshot().silhouette_id == &"mast_only_failed"
			and renewed_presentation == intact_presentation
			and int(renewed.get_asset_handle().generation) == 2,
		"three truthful silhouettes and exact renewed-to-intact parity are composed before capture"
	)
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 7.5, 27.0)
	camera.fov = 52.0
	camera.near = 0.08
	camera.far = 100.0
	world.add_child(camera)
	camera.look_at(Vector3(0.0, 2.5, 0.0), Vector3.UP)
	camera.current = true
	for _frame in 24:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_check(
		image != null and not image.is_empty() and image.get_size() == CAPTURE_SIZE
			and image.get_used_rect().size != Vector2i.ZERO,
		"Forward+ all-state frame contains the gameplay-distance perimeter roster"
	)
	if _failures.is_empty():
		DirAccess.make_dir_recursive_absolute(OUTPUT_PATH.get_base_dir())
		_check(image.save_png(OUTPUT_PATH) == OK, "Forward+ all-state frame saves")
	world.queue_free()
	await process_frame
	_finish()


func _add_asset(
	world: Node3D, index: int, state: StringName
) -> StationDefensePerimeterAsset:
	var asset := ASSET_SCENE.instantiate() as StationDefensePerimeterAsset
	asset.position = STATE_POSITIONS[index]
	world.add_child(asset)
	if state == &"attack":
		var activity := asset.apply_activity_presentation_snapshot({
			"state_id": &"active",
			"current_wave_index": 1,
			"wave_count": 3,
			"wave_active": true,
			"wave_delay_remaining_seconds": 0.0,
		})
		_check(bool(activity.get("accepted", false)), "attack uses a reachable active-wave snapshot")
	elif state in [&"failed", &"renewed"]:
		var old_generation := int(asset.get_asset_handle().generation)
		var damageable := asset.get_damageable_component()
		var destruction := damageable.apply_damage(
			damageable.get_maximum_health(), asset.global_position, Vector3.UP,
			{"source": &"state_shape_capture"}
		)
		var authority := asset.apply_authority_presentation_snapshot(asset.get_snapshot())
		_check(
			bool(destruction.get("accepted", false))
				and bool(destruction.get("destroyed", false))
				and bool(authority.get("accepted", false)),
			"state %d reaches failure through the production Damageable" % index
		)
		if state == &"renewed":
			var renewal := asset.renew(old_generation)
			_check(
				bool(renewal.get("accepted", false))
					and int(asset.get_asset_handle().generation) == old_generation + 1,
				"renewed panel advances the physical asset generation"
			)
	return asset


func _add_environment(world: Node3D) -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("050a11")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("8da3b9")
	environment.ambient_light_energy = 0.42
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.glow_enabled = true
	environment.glow_intensity = 0.3
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	world.add_child(world_environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
	key.light_color = Color("ffe0bd")
	key.light_energy = 1.5
	key.shadow_enabled = true
	world.add_child(key)


func _add_floor(world: Node3D) -> void:
	var floor := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(30.0, 16.0)
	floor.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("1c2633")
	material.metallic = 0.45
	material.roughness = 0.7
	floor.material_override = material
	world.add_child(floor)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("STATION_DEFENSE_PERIMETER_STATE_SHAPE_CAPTURE_OK: ", OUTPUT_PATH)
		quit(0)
		return
	for failure in _failures:
		push_error("STATION_DEFENSE_PERIMETER_STATE_SHAPE_CAPTURE_FAILED: %s" % failure)
	quit(1)
