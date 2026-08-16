extends SceneTree

## Exactly one normal-resolution Forward+ frame of the production Main/HUD
## caption seam. Visual evidence only; this is not a performance benchmark.

const OUTPUT_PATH := "/tmp/caption-production-forward-plus.png"
const MAIN_SCENE := preload("res://scenes/main.tscn")


func _initialize() -> void:
	_run()


func _run() -> void:
	var game := await _find_production_main()
	if game == null:
		game = MAIN_SCENE.instantiate() as GameFlow
		root.add_child(game)
		await process_frame
		await physics_frame
		await process_frame
	var hud := game.get_node_or_null(^"HUD") as GameHUD
	var audio := game.get_node_or_null(^"AudioDirector") as AudioDirector
	if hud == null or audio == null:
		push_error("CAPTION_PRODUCTION_FORWARD_RENDER_FAILED: HUD/audio unavailable")
		quit(1)
		return

	# Force a deterministic empty caption queue before start_shift's UI-confirm
	# audio. The visual cue below is then the first and active service event.
	hud.setting_change_requested.emit(&"captions_enabled", false)
	hud.setting_change_requested.emit(&"reduced_motion", false)
	game.start_shift()
	(hud.get("_intro") as Control).visible = false
	(hud.get("_hud") as Control).visible = true
	hud.set("_started", true)
	hud.set_ship_identity("Torrent-class Interceptor", "Interceptor")
	hud.set_mode("piloting")
	hud.set_objective("Destroy the 3 marked range drones outside the yard")
	hud.set_target_count(1, 3)
	hud.set_interaction("Hold course through the launch aperture", true)
	hud.set_enemy_status("Mudds range defence interceptor", 68.0, 100.0, true)
	hud.update_ship_telemetry({
		"speed": 118.0,
		"altitude": 142.0,
		"throttle": 0.72,
		"hull": 84.0,
		"maximum_hull": 100.0,
		"damage_status": "light damage",
		"engine_power": 0.86,
		"engine_state": "ONLINE",
	})
	hud.setting_change_requested.emit(&"ui_scale", 1.15)
	hud.setting_change_requested.emit(&"reduced_motion", true)
	hud.setting_change_requested.emit(&"captions_enabled", true)
	hud.toast("Hostile contact", "Range defence interceptor is engaging", 20.0)
	audio.play_combat_alert()
	for _frame in 10:
		await process_frame
		await physics_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(OUTPUT_PATH) != OK:
		push_error("CAPTION_PRODUCTION_FORWARD_RENDER_FAILED: image save")
		quit(1)
		return
	print(
		"CAPTION_PRODUCTION_FORWARD_RENDER_OK renderer=", RenderingServer.get_current_rendering_method(),
		" adapter=", RenderingServer.get_video_adapter_name(),
		" size=", image.get_size(),
		" caption=", hud.get_caption_presentation_report(),
		" panels=", hud.get_hud_panel_rects(),
		" path=", OUTPUT_PATH
	)
	quit(0)


func _find_production_main() -> GameFlow:
	for _attempt in 3:
		for child in root.get_children():
			if child is GameFlow:
				return child as GameFlow
		await process_frame
	return null
