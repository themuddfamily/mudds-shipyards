extends SceneTree

## One stable HUD-free Forward+ flight-distance witness for the protected
## perimeter asset's steady hostile-approach chevron. The production asset is
## unchanged except for its presentation hierarchy; the deck and camera exist
## only to make scale and direction legible in this review frame.

const ASSET_SCENE := preload("res://scenes/activities/station_defense_perimeter_asset.tscn")
const OUTPUT_PATH := "/tmp/shipyard-branch-review/station_defense_approach_lane_forward_plus.png"
const CAPTURE_SIZE := Vector2i(1600, 900)

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
			and DisplayServer.get_name() != &"headless"
			and not RenderingServer.get_video_adapter_name().is_empty(),
		"capture uses a live display-backed Forward+ renderer",
	)

	var stage := Node3D.new()
	stage.name = "StationDefenseApproachLaneCapture"
	root.add_child(stage)
	_install_environment(stage)
	_add_review_deck(stage)

	var asset := ASSET_SCENE.instantiate() as StationDefensePerimeterAsset
	stage.add_child(asset)
	await process_frame
	await physics_frame
	var handle := asset.get_asset_handle()
	var bearing_result := asset.apply_hostile_bearing_presentation_snapshot({
		"asset_handle": handle,
		"activity_generation": int(handle.generation),
		"active": true,
		"bearing_world": Vector3.LEFT,
	})
	var wave_result := asset.apply_activity_presentation_snapshot({
		"state_id": &"active",
		"current_wave_index": 1,
		"wave_count": 3,
		"wave_active": true,
		"wave_delay_remaining_seconds": 0.0,
	})
	var cue := asset.get_node_or_null(^"Presentation/ApproachLaneCue") as MeshInstance3D
	var snapshot := asset.get_protected_asset_presentation_snapshot()
	_check(
		bool(bearing_result.accepted)
			and bool(wave_result.accepted)
			and cue != null
			and cue.visible
			and cue.mesh is PrismMesh
			and cue.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			and is_equal_approx(float(snapshot.approach_lane_cue_yaw), -PI * 0.5),
		"the active production asset exposes one triangular wedge toward the port approach",
	)
	_check(
		asset.find_children("*", "CollisionShape3D", true, false).size() == 1
			and asset.find_children("*", "Light3D", true, false).size() == 1,
		"the cue adds no collision shape or light",
	)

	var camera := Camera3D.new()
	camera.name = "GameplayDistanceReviewCamera"
	camera.position = Vector3(0.0, 18.0, 28.0)
	camera.near = 0.08
	camera.far = 180.0
	camera.fov = 42.0
	stage.add_child(camera)
	camera.look_at(Vector3(0.0, 2.2, 0.0), Vector3.UP)
	camera.current = true
	_check(
		camera.global_position.distance_to(asset.global_position) > 30.0
			and camera.is_position_in_frustum(asset.global_position + Vector3.UP * 3.5),
		"the cue is framed from more than thirty metres at ordinary flight distance",
	)

	var steady_transform := cue.transform if cue != null else Transform3D.IDENTITY
	for _frame in 12:
		await process_frame
	_check(
		cue != null and cue.visible and cue.transform.is_equal_approx(steady_transform),
		"the reduced-flash cue remains geometrically steady through the capture settle",
	)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_check(
		image != null and not image.is_empty() and image.get_size() == CAPTURE_SIZE,
		"stable gameplay-distance frame renders at 1600x900",
	)
	if image != null and not image.is_empty():
		DirAccess.make_dir_recursive_absolute(OUTPUT_PATH.get_base_dir())
		_check(image.save_png(OUTPUT_PATH) == OK, "Forward+ review frame saves successfully")
		print("STATION_DEFENSE_APPROACH_LANE_CAPTURE: ", OUTPUT_PATH)

	stage.queue_free()
	await process_frame
	_finish()


func _install_environment(stage: Node3D) -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("030812")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("879bb3")
	environment.ambient_light_energy = 0.72
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.glow_enabled = true
	environment.glow_intensity = 0.18
	world_environment.environment = environment
	stage.add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	sun.light_color = Color("fff0dc")
	sun.light_energy = 3.2
	sun.shadow_enabled = true
	stage.add_child(sun)


func _add_review_deck(stage: Node3D) -> void:
	var deck := MeshInstance3D.new()
	deck.name = "ScaleReferenceDeck"
	deck.position = Vector3(0.0, -3.05, 0.0)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(22.0, 0.45, 18.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("182532")
	material.metallic = 0.7
	material.roughness = 0.34
	mesh.material = material
	deck.mesh = mesh
	stage.add_child(deck)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("STATION_DEFENSE_APPROACH_LANE_CAPTURE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error("STATION_DEFENSE_APPROACH_LANE_CAPTURE_FAILED: %s" % failure)
	quit(1)
