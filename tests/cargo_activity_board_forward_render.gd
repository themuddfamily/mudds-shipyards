extends SceneTree

## Exactly one normal-resolution Forward+ review frame for the player-reachable
## Activity Board and cargo objective copy. This is not a matrix capture.

const HUD_SCENE := preload("res://scenes/ui/hud.tscn")
const OUTPUT_PATH := "/tmp/cargo-activity-board-forward-plus.png"


func _initialize() -> void:
	_run()


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.name = "CargoActivityBoardForwardReview"
	viewport.size = Vector2i(1600, 900)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	root.add_child(viewport)
	var backdrop := ColorRect.new()
	backdrop.color = Color("07111d")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(backdrop)
	_add_station_silhouette(viewport)
	var hud := HUD_SCENE.instantiate() as GameHUD
	viewport.add_child(hud)
	await process_frame
	hud.set_reduced_motion(true)
	hud.call("_begin")
	hud.set_mode("piloting")
	hud.set_objective(
		"Free flight — return fabrication kits to the registered freight berth",
		"SANDBOX SORTIE"
	)
	hud.set_target_count(0, 3)
	hud.set_activity_objective("Jovian fabrication kit delivery", {
		"activity_id": &"jovian_fabrication_kit_delivery",
		"activity_kind": &"cargo_delivery",
		"state_id": &"active",
		"phase_id": &"return",
		"generation": 1,
		"session_generation": 1,
		"activity_generation": 1,
		"next_checkpoint_index": 1,
		"checkpoint_count": 2,
		"completed_checkpoint_count": 1,
		"elapsed_seconds": 38.4,
		"deadline_remaining_seconds": 141.6,
		"quantity": 2,
		"item_id": &"fabrication_kits",
		"item_display_name": "Fabrication kits",
	})
	hud.set_activity_selection_state(&"cargo_delivery", false, &"selected")
	hud.set_paused(true)
	var pause_overlay := hud.get("_pause") as Control
	var board_open := pause_overlay.find_child(
		"ActivityBoardButton", true, false
	) as Button
	board_open.emit_signal("pressed")
	for _frame in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var report := hud.get_activity_selection_report()
	var page := report.get("page_rect", Rect2()) as Rect2
	var frame_rect := Rect2(Vector2.ZERO, Vector2(viewport.size))
	var regions: Array[Rect2] = []
	for activity_kind: StringName in [
		&"timed_race", &"patrol", &"cargo_delivery"
	]:
		var row := (report.get("row_rects", {}) as Dictionary).get(
			activity_kind, Rect2()
		) as Rect2
		regions.append(row)
	regions.append(report.get("status_rect", Rect2()) as Rect2)
	regions.append(report.get("back_rect", Rect2()) as Rect2)
	var geometry_valid := frame_rect.encloses(page)
	for region: Rect2 in regions:
		geometry_valid = geometry_valid and page.encloses(region)
	for index in regions.size():
		for other_index in range(index + 1, regions.size()):
			geometry_valid = (
				geometry_valid
				and not regions[index].intersects(regions[other_index])
			)
	var buttons := report.get("buttons", {}) as Dictionary
	var copy_valid := (
		str((buttons.get(&"timed_race", {}) as Dictionary).get("text", ""))
		== "TIMED CINDER RACE"
		and str((buttons.get(&"patrol", {}) as Dictionary).get("text", ""))
		== "CINDER PATROL"
		and str((buttons.get(&"cargo_delivery", {}) as Dictionary).get("text", ""))
		== "SELECTED  //  JOVIAN KIT DELIVERY"
		and "READY" in str(report.get("status", ""))
		and hud.get_viewport().gui_get_focus_owner()
		== pause_overlay.find_child("CargoDeliveryActivityButton", true, false)
	)
	var image := viewport.get_texture().get_image()
	paused = false
	if (
		image == null
		or image.is_empty()
		or not geometry_valid
		or not copy_valid
		or image.save_png(OUTPUT_PATH) != OK
	):
		push_error(
			"CARGO_ACTIVITY_BOARD_FORWARD_RENDER_FAILED geometry=%s copy=%s"
			% [geometry_valid, copy_valid]
		)
		quit(1)
		return
	print(
		"CARGO_ACTIVITY_BOARD_FORWARD_RENDER_OK renderer=",
		RenderingServer.get_current_rendering_method(),
		" adapter=", RenderingServer.get_video_adapter_name(),
		" size=", image.get_size(),
		" page=", page,
		" path=", OUTPUT_PATH
	)
	quit(0)


func _add_station_silhouette(viewport: SubViewport) -> void:
	var title := Label.new()
	title.position = Vector2(42.0, 30.0)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color("577181"))
	title.text = "MUDDS SHIPYARDS  //  ACTIVITY BOARD REVIEW"
	viewport.add_child(title)
	for rect_spec in [
		Rect2(60, 150, 530, 18),
		Rect2(250, 90, 18, 360),
		Rect2(690, 220, 850, 22),
		Rect2(1110, 80, 20, 420),
		Rect2(430, 470, 760, 16),
	]:
		var beam := ColorRect.new()
		beam.position = rect_spec.position
		beam.size = rect_spec.size
		beam.color = Color("173247")
		viewport.add_child(beam)
