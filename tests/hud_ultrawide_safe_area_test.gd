extends SceneTree

const HudType := preload("res://scripts/ui/hud.gd")
const Contract := preload("res://scripts/ui/ultrawide_safe_area_contract.gd")

var _assertions := 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred(&"_run")


## Presentation variants every case is measured under. The second one turns the
## high-contrast HUD on with the large reticle: opaque panels and a wider
## reticle footprint must not move any card out of the safe band.
const PRESENTATIONS := [
	{"id": "standard", "high_contrast_hud": false, "reticle_style": &"standard"},
	{"id": "high-contrast/large", "high_contrast_hud": true, "reticle_style": &"large"},
]


func _run() -> void:
	for viewport in [Vector2(1920, 1080), Vector2(1920, 1200), Vector2(2560, 1080), Vector2(5120, 1440)]:
		for requested_scale in [0.75, 1.0, 1.6]:
			for presentation: Dictionary in PRESENTATIONS:
				await _exercise_case(viewport, requested_scale, presentation)
	if _failures.is_empty():
		print("HUD_ULTRAWIDE_SAFE_AREA_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _exercise_case(viewport_size: Vector2, requested_scale: float, presentation: Dictionary) -> void:
	# A real SubViewport is required here. Anchored right/bottom controls resolve
	# from their owning viewport, so faking only the layout size would measure a
	# hybrid geometry that production can never display.
	var viewport := SubViewport.new()
	viewport.size = Vector2i(viewport_size)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(viewport)
	var hud := HudType.new()
	viewport.add_child(hud)
	await process_frame
	hud.set("_started", true)
	(hud.get("_intro") as Control).visible = false
	(hud.get("_hud") as Control).visible = true
	hud.set_mode("piloting")
	hud.set_accessibility({
		"high_contrast_hud": bool(presentation["high_contrast_hud"]),
		"reticle_style": StringName(presentation["reticle_style"]),
	})
	var case_label := "%s %s" % [Contract.classify_viewport(viewport_size), presentation["id"]]
	_check(
		hud.is_high_contrast_hud() == bool(presentation["high_contrast_hud"])
		and hud.get_reticle_style() == StringName(presentation["reticle_style"]),
		"the %s case applies its presentation variant before layout" % case_label
	)
	hud.set_objective(
		"Free flight — explore, fight, or return to a compatible registered berth",
		"SANDBOX SORTIE"
	)
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
	_check(hud.apply_first_sortie_tutorial_snapshot({
		"step_id": &"launch", "generation": 8, "revision": 1,
	}), "the dense production tutorial card is available for the layout proof")
	hud.set_captions_enabled(true)
	_check(
		hud.bind_caption_event_submitter(Callable(self, &"_accept_caption_request")),
		"the isolated HUD has a bounded caption request sink for layout seeding"
	)
	var semantic_cues: Array[StringName] = [
		&"combat_alert", &"target_destroyed", &"hull_impact_heavy",
		&"engine_damage_alarm", &"target_lock_acquired", &"weapon_not_ready",
		&"boost_engaged", &"surface_touchdown",
	]
	for index in semantic_cues.size():
		_check(hud.present_semantic_audio_cue(
			semantic_cues[index], StringName("layout_source_%d" % index), 0.8,
			Vector3.ZERO, {"tick": index + 1, "direction": "rear-left"}
		), "dense semantic caption %d is available for the expanded layout proof" % index)
	hud.toggle_semantic_caption_transcript()
	hud.set_ui_scale(requested_scale)
	await process_frame
	await process_frame
	var tutorial_action := (
		(hud.get("_runtime_status_actions") as HBoxContainer).get_child(0) as Button
	)
	tutorial_action.grab_focus()
	await process_frame
	var effective := float(hud.get("_layout_effective_ui_scale"))
	var safe := Contract.safe_rect(viewport_size, effective)
	var rects := hud.get_hud_panel_rects()
	var caption_toggle_control := hud.get("_semantic_transcript_toggle") as Control
	var caption_panel := hud.get("_semantic_transcript_panel") as PanelContainer
	rects[&"caption_log_toggle"] = caption_toggle_control.get_rect()
	rects[&"caption_log_expanded"] = caption_panel.get_rect()
	for key in [
		&"brand", &"objective", &"help", &"telemetry", &"minimap",
		&"runtime_status", &"caption_log_toggle", &"caption_log_expanded",
	]:
		var logical_panel := rects.get(key, Rect2()) as Rect2
		var panel := Rect2(logical_panel.position * effective, logical_panel.size * effective)
		_check(
			safe.grow(0.5).encloses(panel)
			and Rect2(Vector2.ZERO, viewport_size).encloses(panel),
			"%s remains fully inside the readable safe band at %s scale %.2f"
			% [key, case_label, requested_scale]
		)
	# The camera-space reticle is excluded from UI scaling, so it is measured in
	# device pixels: every visible mark and the state label stay inside the safe
	# band, and the label never touches a mark whichever style is selected.
	var reticle := hud.get("_reticle") as Control
	var reticle_snapshot := hud.get_sensor_reticle_component_snapshot()
	var reticle_label := hud.get("_reticle_state_label") as Label
	var reticle_origin := reticle.get_global_position()
	var label_rect := Rect2(reticle_origin + reticle_label.position, reticle_label.size)
	var reticle_clear := true
	var reticle_inside := true
	for mark: Dictionary in reticle_snapshot["marks"] as Array:
		if not bool(mark["visible"]):
			continue
		var mark_rect := Rect2(reticle_origin + (mark["position"] as Vector2), mark["size"] as Vector2)
		if mark_rect.intersects(label_rect):
			reticle_clear = false
		if not safe.grow(0.5).encloses(mark_rect):
			reticle_inside = false
	_check(
		reticle_snapshot["style"] == StringName(presentation["reticle_style"])
		and reticle_clear and reticle_inside and safe.grow(0.5).encloses(label_rect),
		"the %s reticle keeps its marks and state label inside the safe band and apart at %s scale %.2f"
		% [reticle_snapshot["style"], case_label, requested_scale]
	)
	if bool(presentation["high_contrast_hud"]):
		var telemetry_box := (hud.get("_telemetry_panel") as PanelContainer).get_theme_stylebox("panel") as StyleBoxFlat
		_check(
			telemetry_box.bg_color.a == 1.0,
			"the high-contrast telemetry backing is opaque at %s scale %.2f" % [case_label, requested_scale]
		)
	var composed_keys: Array[StringName] = [
		&"brand", &"objective", &"help", &"telemetry", &"minimap",
		&"runtime_status", &"caption_log_toggle", &"caption_log_expanded",
	]
	var collisions: PackedStringArray = []
	for first_index in composed_keys.size():
		for second_index in range(first_index + 1, composed_keys.size()):
			var first_key := composed_keys[first_index]
			var second_key := composed_keys[second_index]
			var first_rect := rects.get(first_key, Rect2()) as Rect2
			var second_rect := rects.get(second_key, Rect2()) as Rect2
			if first_rect.intersects(second_rect):
				collisions.append("%s %s x %s %s" % [
					first_key, first_rect, second_key, second_rect,
				])
	_check(
		collisions.is_empty(),
		"the expanded caption composition is pairwise disjoint at %s scale %.2f%s"
		% [
			Contract.classify_viewport(viewport_size), requested_scale,
			"" if collisions.is_empty() else " (" + "; ".join(collisions) + ")",
		]
	)
	var caption_panel_global := caption_panel.get_global_rect()
	var caption_children: Array[Control] = [
		hud.get("_semantic_transcript_heading") as Control,
		hud.get("_semantic_transcript_body") as Control,
	]
	for button in caption_panel.find_children("*", "Button", true, false):
		caption_children.append(button as Control)
	var content_enclosed := true
	for child in caption_children:
		content_enclosed = (
			content_enclosed
			and child.visible
			and caption_panel_global.grow(0.5).encloses(child.get_global_rect())
		)
	_check(
		content_enclosed
		and caption_children.size() == 5
		and (hud.get("_semantic_transcript_body") as Label).text.split("\n").size() == 8,
		"the expanded caption heading, eight-line body, and three controls stay enclosed at %s scale %.2f"
		% [Contract.classify_viewport(viewport_size), requested_scale]
	)
	_check(
		caption_toggle_control.size.y >= 42.0
		and caption_toggle_control.custom_minimum_size.y >= 42.0,
		"caption-log access retains its minimum focus target at %s scale %.2f"
		% [Contract.classify_viewport(viewport_size), requested_scale]
	)
	_check(
		hud.get_viewport().gui_get_focus_owner() == tutorial_action,
		"safe-area relayout preserves controller focus at %s scale %.2f"
		% [Contract.classify_viewport(viewport_size), requested_scale]
	)
	var objective_panel := hud.get("_objective_panel") as Control
	var objective_label := hud.get("_objective_label") as Label
	var activity_label := hud.get("_activity_objective_label") as Label
	var target_label := hud.get("_target_label") as Label
	_check(
		objective_panel.get_global_rect().encloses(activity_label.get_global_rect())
		and not activity_label.get_global_rect().intersects(objective_label.get_global_rect())
		and not activity_label.get_global_rect().intersects(target_label.get_global_rect()),
		"the activity row remains readable inside the objective card at %s scale %.2f"
		% [Contract.classify_viewport(viewport_size), requested_scale]
	)
	viewport.queue_free()
	await process_frame


func _accept_caption_request(_request: Dictionary) -> bool:
	return true


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)
