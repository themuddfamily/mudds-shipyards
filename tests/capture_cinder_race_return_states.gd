extends SceneTree

## Forward+ gameplay-distance contact sheet for the retained Cinder race crown.

const CLUSTER_SCENE := preload("res://scenes/world/components/nearby_sector_cluster.tscn")
const OUTPUT := "res://artifacts/cinder_race_return_states/gameplay_distance_forward_plus.png"
const RESOLUTION := Vector2i(1600, 900)
const CAMERA_POSITION := Vector3(80.0, -45.0, -615.0)
const CAMERA_TARGET := Vector3(65.0, -42.0, -722.0)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if RenderingServer.get_current_rendering_method() != &"forward_plus" \
			or RenderingServer.get_rendering_device() == null:
		push_error("CINDER_RACE_RETURN_CAPTURE_FAILED: Forward+ is required")
		quit(1)
		return
	DisplayServer.window_set_size(RESOLUTION)
	root.size = RESOLUTION
	var stage := Node3D.new()
	root.add_child(stage)
	_add_environment(stage)
	var cluster := CLUSTER_SCENE.instantiate() as NearbySectorCluster
	stage.add_child(cluster)
	var camera := Camera3D.new()
	camera.position = CAMERA_POSITION
	camera.fov = 52.0
	camera.near = 0.1
	camera.far = 1000.0
	camera.current = true
	stage.add_child(camera)
	camera.look_at(CAMERA_TARGET, Vector3.UP)
	for _frame in 10:
		await process_frame
	var panels: Array[Image] = []
	for sample in [
		[&"idle", 0], [&"active", 1], [&"active", 4], [&"completed", 5],
	]:
		var result := cluster.call("_apply_race_gate_presentation", _snapshot_for(sample[0], sample[1])) as Dictionary
		if not bool(result.get("accepted", false)):
			push_error("CINDER_RACE_RETURN_CAPTURE_FAILED: %s rejected" % sample[0])
			quit(1)
			return
		for _frame in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		panels.append(root.get_texture().get_image())
	var sheet := _contact_sheet(panels)
	var absolute_output := ProjectSettings.globalize_path(OUTPUT)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_output.get_base_dir())
	var save_error := sheet.save_png(absolute_output)
	if (directory_error != OK and directory_error != ERR_ALREADY_EXISTS) or save_error != OK:
		push_error("CINDER_RACE_RETURN_CAPTURE_FAILED: could not save contact sheet")
		quit(1)
		return
	print("CINDER_RACE_RETURN_CAPTURE_OK output=%s" % OUTPUT)
	quit(0)


func _snapshot_for(state_id: StringName, next_checkpoint: int) -> Dictionary:
	return {
		"activity_id": &"cinder_reach_checkpoint_route",
		"session_generation": 1,
		"state_id": state_id,
		"next_checkpoint_index": next_checkpoint,
		"checkpoint_count": 5,
	}


func _contact_sheet(panels: Array[Image]) -> Image:
	var sheet := Image.create(RESOLUTION.x, RESOLUTION.y, false, Image.FORMAT_RGB8)
	sheet.fill(Color("050b12"))
	for index in panels.size():
		var panel := panels[index].duplicate()
		panel.convert(Image.FORMAT_RGB8)
		panel.resize(RESOLUTION.x / 4, RESOLUTION.y, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(panel, Rect2i(Vector2i.ZERO, panel.get_size()), Vector2i(index * (RESOLUTION.x / 4), 0))
	return sheet


func _add_environment(stage: Node3D) -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("050b12")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("7894aa")
	environment.ambient_light_energy = 0.46
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	stage.add_child(world_environment)
	var key := DirectionalLight3D.new()
	key.light_color = Color("ffe0bc")
	key.light_energy = 1.45
	key.rotation_degrees = Vector3(-36.0, -30.0, 0.0)
	stage.add_child(key)
