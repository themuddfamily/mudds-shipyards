extends SceneTree

## One normal-resolution Forward+ human-review frame for the reusable caption
## presenter. This script saves exactly one PNG and is never a matrix capture.

const PRESENTER_SCENE := preload("res://scenes/ui/caption_presenter.tscn")
const OUTPUT_PATH := "/tmp/caption-presenter-forward-plus.png"


func _initialize() -> void:
	_run()


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.name = "CaptionPresenterForwardReview"
	viewport.size = Vector2i(1600, 900)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	root.add_child(viewport)
	var backdrop := ColorRect.new()
	backdrop.color = Color("06101c")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport.add_child(backdrop)
	_add_station_silhouette(viewport)
	var presenter := PRESENTER_SCENE.instantiate() as CaptionPresenter
	viewport.add_child(presenter)
	await process_frame
	presenter.set_ui_scale(1.15)
	presenter.apply_presentation_snapshot({
		"schema_version": 1,
		"service_id": &"caption-presentation-service",
		"generation": 4,
		"revision": 18,
		"visible": true,
		"captions_enabled": true,
		"reduced_flash": true,
		"transition_policy": &"steady_no_flash",
		"caption": {
			"stable_id": &"radio.fabrication-approach",
			"category": CaptionPresentationEvent.Category.RADIO,
			"category_id": &"radio",
			"speaker": "Mudds Traffic Control",
			"text": "Fabrication traffic is crossing the central aisle. Hold outside the amber gantry, maintain visual separation, and proceed only when the route marker returns steady.",
			"duration_physics_seconds": 12.0,
			"remaining_physics_seconds": 9.25,
			"priority": 75,
			"sequence": 11,
		},
	})
	for _frame in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(OUTPUT_PATH) != OK:
		push_error("CAPTION_PRESENTER_FORWARD_RENDER_FAILED")
		quit(1)
		return
	print(
		"CAPTION_PRESENTER_FORWARD_RENDER_OK renderer=", RenderingServer.get_current_rendering_method(),
		" adapter=", RenderingServer.get_video_adapter_name(),
		" size=", image.get_size(),
		" report=", presenter.get_layout_report(),
		" path=", OUTPUT_PATH
	)
	quit(0)


func _add_station_silhouette(viewport: SubViewport) -> void:
	var title := Label.new()
	title.position = Vector2(56, 46)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("6f8797"))
	title.text = "FORWARD+ REVIEW  //  REDUCED-FLASH SNAPSHOT"
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport.add_child(title)
	for rect_spec in [
		Rect2(80, 190, 520, 18),
		Rect2(280, 118, 18, 330),
		Rect2(690, 245, 820, 22),
		Rect2(1080, 120, 20, 360),
		Rect2(460, 430, 710, 16),
	]:
		var beam := ColorRect.new()
		beam.position = rect_spec.position
		beam.size = rect_spec.size
		beam.color = Color("173247")
		beam.mouse_filter = Control.MOUSE_FILTER_IGNORE
		viewport.add_child(beam)
