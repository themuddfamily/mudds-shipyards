extends SceneTree

## Bounded Forward+ visual review for the real loading-screen composition.
## Captures one ordinary 16:9 frame and the supported maximum-scale 32:9 case.

const LoadingScreenType := preload("res://scripts/ui/loading_screen.gd")
const CASES := [
	{
		"name": "loading-transition-phase2-1920x1080",
		"size": Vector2i(1920, 1080),
		"ui_scale": 1.0,
	},
	{
		"name": "loading-transition-phase2-5120x1440-scale160",
		"size": Vector2i(5120, 1440),
		"ui_scale": 1.6,
	},
]


func _initialize() -> void:
	_run()


func _run() -> void:
	for capture_case: Dictionary in CASES:
		if not await _capture_case(capture_case):
			quit(1)
			return
	print("LOADING_TRANSITION_FORWARD_REVIEW_OK")
	quit(0)


func _capture_case(capture_case: Dictionary) -> bool:
	var viewport := SubViewport.new()
	viewport.name = str(capture_case.name)
	viewport.size = capture_case.size as Vector2i
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	root.add_child(viewport)

	var screen := LoadingScreenType.new()
	viewport.add_child(screen)
	await process_frame
	screen.configure({
		"ui_scale": float(capture_case.ui_scale),
		"reduced_motion": true,
	})
	screen.set_stage(
		"Preparing encounters",
		0.58,
		"Placing patrols and synchronizing local flight traffic",
		"CINDER REACH",
		"Encounter handoff",
		2,
		3
	)
	for _frame in 3:
		await process_frame
	await RenderingServer.frame_post_draw

	var stack := screen.get_node("LoadingRoot/Stack") as VBoxContainer
	var destination := stack.get_node("Destination") as Label
	var phase := stack.get_node("Phase") as Label
	var phase_track := stack.get_node("PhaseTrack") as HBoxContainer
	var stage_row := stack.get_node("StageRow") as HBoxContainer
	var detail := stack.get_node("Detail") as Label
	var bar_track := stack.get_node("BarTrack") as ColorRect
	var frame := Rect2(Vector2.ZERO, Vector2(viewport.size))
	var regions: Array[Control] = [destination, phase, phase_track, stage_row, detail, bar_track]
	var geometry_ok := frame.encloses(stack.get_global_rect())
	for region: Control in regions:
		geometry_ok = geometry_ok and frame.encloses(region.get_global_rect())
	for index in regions.size() - 1:
		geometry_ok = geometry_ok and not regions[index].get_global_rect().intersects(
			regions[index + 1].get_global_rect()
		)
	var copy_ok := (
		destination.text == "DESTINATION  /  CINDER REACH"
		and phase.text == "PHASE 2 OF 3  /  ENCOUNTER HANDOFF"
		and phase_track.visible
		and phase_track.get_child_count() == 3
		and (stage_row.get_node("Progress") as Label).text == "58%"
		and detail.visible
		and detail.text == "Placing patrols and synchronizing local flight traffic"
	)
	var output_path := "/tmp/%s.png" % str(capture_case.name)
	var image := viewport.get_texture().get_image()
	var saved := image != null and not image.is_empty() and image.save_png(output_path) == OK
	print(
		"LOADING_TRANSITION_CAPTURE renderer=", RenderingServer.get_current_rendering_method(),
		" adapter=", RenderingServer.get_video_adapter_name(),
		" size=", viewport.size,
		" scale=", capture_case.ui_scale,
		" geometry=", geometry_ok,
		" copy=", copy_ok,
		" stack=", stack.get_global_rect(),
		" path=", output_path
	)
	viewport.queue_free()
	await process_frame
	return geometry_ok and copy_ok and saved
