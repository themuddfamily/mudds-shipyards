extends SceneTree

const HudType := preload("res://scripts/ui/hud.gd")

var _assertions := 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var hud := HudType.new()
	root.add_child(hud)
	await process_frame
	var controls := hud.get("_settings_controls") as Dictionary
	var ordered_keys: Array[StringName] = [
		&"master_volume", &"ambience_volume", &"music_volume", &"engine_volume",
		&"weapons_volume", &"ui_volume", &"ui_scale", &"colorblind_palette",
		&"high_contrast_hud", &"reticle_style",
		&"reduced_motion", &"reduced_flash", &"reduced_dynamic_range",
		&"payload_visual_intensity", &"captions_enabled", &"show_tutorials",
		&"controller_glyph_family",
	]
	for index in ordered_keys.size():
		var control := controls.get(ordered_keys[index]) as Control
		_check(control != null and control.focus_mode == Control.FOCUS_ALL, "%s is focusable" % ordered_keys[index])
		if control == null:
			continue
		var next_control := controls[ordered_keys[mini(ordered_keys.size() - 1, index + 1)]] as Control
		var previous_control := controls[ordered_keys[maxi(0, index - 1)]] as Control
		_check(control.focus_neighbor_bottom == control.get_path_to(next_control), "%s has deterministic next focus" % ordered_keys[index])
		_check(control.focus_neighbor_top == control.get_path_to(previous_control), "%s has deterministic previous focus" % ordered_keys[index])
	var payload_selector := controls[&"payload_visual_intensity"] as Control
	hud.set_paused(true)
	hud.call("_show_settings_page")
	payload_selector.grab_focus()
	await process_frame
	hud.call("_show_pause_main")
	hud.call("_show_settings_page")
	await process_frame
	_check(root.get_viewport().gui_get_focus_owner() == payload_selector, "settings re-entry restores last focused control")

	var scroll: ScrollContainer = hud.get("_settings_scroll") as ScrollContainer
	var first_control: Control = controls[&"ship_mouse_sensitivity"] as Control
	var graphics_profile: Control = controls[&"graphics_profile"] as Control
	first_control.grab_focus()
	scroll.scroll_vertical = 0
	await process_frame
	var relative: Transform2D = scroll.get_global_transform().affine_inverse() * graphics_profile.get_global_transform()
	var graphics_rect: Rect2 = relative * Rect2(Vector2.ZERO, graphics_profile.size)
	_check(graphics_rect.end.y > scroll.size.y, "obsolete focus target starts outside the visible scroll area")
	# An old request must not scroll away from the control now being edited.
	hud.call("_request_settings_scroll", graphics_profile)
	await process_frame
	_check(scroll.scroll_vertical == 0, "queued obsolete focus request leaves current row visible")
	_check(root.get_viewport().gui_get_focus_owner() == first_control, "queued obsolete focus request preserves current focus")

	graphics_profile.grab_focus()
	await process_frame
	scroll.scroll_vertical = 0
	await process_frame
	# Duplicate focus/capture requests must apply only one correction against
	# the current child geometry, rather than overshooting the focused row.
	hud.call("_request_settings_scroll", graphics_profile)
	hud.call("_request_settings_scroll", graphics_profile)
	await process_frame
	relative = scroll.get_global_transform().affine_inverse() * graphics_profile.get_global_transform()
	graphics_rect = relative * Rect2(Vector2.ZERO, graphics_profile.size)
	_check(graphics_rect.position.y >= 0.0 and graphics_rect.end.y <= scroll.size.y, "duplicate queued requests fully reveal the current row without overshoot")
	_check(root.get_viewport().gui_get_focus_owner() == graphics_profile, "duplicate queued requests preserve current focus")

	hud.call("_request_settings_scroll", graphics_profile)
	hud.call("_show_pause_main")
	var closed_page_scroll: int = scroll.scroll_vertical
	var pause_focus: Control = root.get_viewport().gui_get_focus_owner()
	await process_frame
	_check(scroll.scroll_vertical == closed_page_scroll, "queued request cannot scroll a closed Settings page")
	_check(root.get_viewport().gui_get_focus_owner() == pause_focus, "queued request preserves pause-page focus")

	hud.queue_free()
	await process_frame
	if _failures.is_empty():
		print("SETTINGS_FOCUS_NAVIGATION_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)
