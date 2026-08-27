extends SceneTree

## Bounded visual review for the production gameplay HUD at an ordinary 16:9
## window and the supported 32:9/UI-scale ceiling. The frame deliberately keeps
## the objective activity row, full piloting controls, and tutorial status card
## visible together because those are the densest persistent information bands.

const HUD_SCENE := preload("res://scenes/ui/hud.tscn")
const CASES := [
	{"name": "hud-composition-1920x1080-scale100", "size": Vector2i(1920, 1080), "scale": 1.0},
	{"name": "hud-composition-5120x1440-scale160", "size": Vector2i(5120, 1440), "scale": 1.6},
]


func _initialize() -> void:
	_run()


func _run() -> void:
	for capture_case: Dictionary in CASES:
		if not await _capture_case(capture_case):
			quit(1)
			return
	print("HUD_ULTRAWIDE_COMPOSITION_CAPTURE_OK")
	quit(0)


func _capture_case(capture_case: Dictionary) -> bool:
	var viewport := SubViewport.new()
	viewport.name = str(capture_case.name)
	viewport.size = capture_case.size as Vector2i
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	root.add_child(viewport)
	var background := ColorRect.new()
	background.color = Color("07111d")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(background)
	var hud := HUD_SCENE.instantiate() as GameHUD
	viewport.add_child(hud)
	await process_frame
	hud.set("_started", true)
	(hud.get("_intro") as Control).visible = false
	(hud.get("_hud") as Control).visible = true
	hud.set_mode("piloting")
	hud.set_ship_identity("Cinder long-range bomber", "Long-range bomber")
	hud.set_objective(
		"Free flight — explore, fight, or return to a compatible registered berth",
		"SANDBOX SORTIE"
	)
	hud.set_target_count(2, 3)
	hud.set_activity_objective("Cinder Reach beacon route", {
		"activity_id": &"cinder_reach_checkpoint_route",
		"activity_kind": &"patrol",
		"state_id": &"active",
		"phase_id": &"active",
		"generation": 8,
		"session_generation": 8,
		"activity_generation": 8,
		"next_checkpoint_index": 4,
		"checkpoint_count": 5,
		"completed_checkpoint_count": 3,
		"current_time_seconds": 58.4,
	})
	if not hud.apply_first_sortie_tutorial_snapshot({
		"step_id": &"launch", "generation": 8, "revision": 1,
	}):
		push_error("HUD_ULTRAWIDE_COMPOSITION_CAPTURE_FAILED: tutorial rejected")
		return false
	hud.set_captions_enabled(true)
	if not hud.bind_caption_event_submitter(Callable(self, &"_accept_caption_request")):
		push_error("HUD_ULTRAWIDE_COMPOSITION_CAPTURE_FAILED: caption sink rejected")
		return false
	var semantic_cues: Array[StringName] = [
		&"combat_alert", &"target_destroyed", &"hull_impact_heavy",
		&"engine_damage_alarm", &"target_lock_acquired", &"weapon_not_ready",
		&"boost_engaged", &"surface_touchdown",
	]
	for index in semantic_cues.size():
		if not hud.present_semantic_audio_cue(
			semantic_cues[index], StringName("capture_source_%d" % index), 0.8,
			Vector3.ZERO, {"tick": index + 1, "direction": "rear-left"}
		):
			push_error("HUD_ULTRAWIDE_COMPOSITION_CAPTURE_FAILED: semantic cue rejected")
			return false
	hud.toggle_semantic_caption_transcript()
	hud.set_ui_scale(float(capture_case.scale))
	hud.layout_for_viewport(Vector2(viewport.size))
	for _frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	var output_path := "/tmp/%s.png" % str(capture_case.name)
	var saved := image != null and not image.is_empty() and image.save_png(output_path) == OK
	var rects := hud.get_hud_panel_rects()
	print(
		"HUD_ULTRAWIDE_CAPTURE size=", viewport.size,
		" requested_scale=", capture_case.scale,
		" effective_scale=", hud.get("_layout_effective_ui_scale"),
		" objective=", rects.get("objective", Rect2()),
		" help=", rects.get("help", Rect2()),
		" runtime_status=", rects.get("runtime_status", Rect2()),
		" caption_log_expanded=", (hud.get("_semantic_transcript_panel") as Control).get_rect(),
		" path=", output_path
	)
	viewport.queue_free()
	await process_frame
	return saved


func _accept_caption_request(_request: Dictionary) -> bool:
	return true
