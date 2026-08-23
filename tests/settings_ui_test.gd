extends SceneTree

const Settings := preload("res://scripts/settings/runtime_settings.gd")
const Profile := preload("res://scripts/settings/input_binding_profile.gd")
const InputGlyphResolver := preload("res://scripts/ui/input_glyph_resolver.gd")

var _failures: Array[String] = []
var _change_events: Array[Dictionary] = []
var _save_events := 0
var _reset_events := 0
var _temp_settings_path := ""


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.content_scale_size = Vector2i(1280, 720)
	_temp_settings_path = "user://settings_ui_binding_%d.cfg" % Time.get_ticks_usec()
	_cleanup_settings_files()
	var settings_owner := Settings.new(_temp_settings_path)
	var hud := GameHUD.new()
	hud.name = "SettingsHUDTest"
	hud.setting_change_requested.connect(_on_setting_change_requested)
	hud.settings_save_requested.connect(func() -> void: _save_events += 1)
	hud.settings_reset_requested.connect(func() -> void: _reset_events += 1)
	root.add_child(hud)
	await process_frame
	_test_product_branding(hud)

	_check(hud.process_mode == Node.PROCESS_MODE_ALWAYS, "HUD remains active while the gameplay tree is paused")
	_check(hud.has_method("set_settings_snapshot"), "HUD exposes guarded settings snapshot population")
	_check(hud.has_signal("setting_change_requested"), "HUD exposes typed live setting change requests")
	_check(hud.has_signal("settings_save_requested"), "HUD exposes an explicit save request")
	_check(hud.has_signal("settings_reset_requested"), "HUD exposes an explicit reset request")

	var expected_keys: Array[StringName] = [
		&"ship_mouse_sensitivity",
		&"on_foot_mouse_sensitivity",
		&"invert_ship_y",
		&"invert_on_foot_y",
		&"camera_fov",
		&"master_volume",
		&"ambience_volume",
		&"music_volume",
		&"engine_volume",
		&"weapons_volume",
		&"ui_volume",
		&"graphics_profile",
		&"window_mode",
		&"control_preset",
		&"ui_scale",
		&"colorblind_palette",
		&"reduced_motion",
		&"captions_enabled",
		&"controller_glyph_family",
	]
	var controls := hud.get("_settings_controls") as Dictionary
	_check(controls.size() == expected_keys.size(), "settings page builds one real control for every runtime preference")
	for key in expected_keys:
		_check(controls.has(key), "settings page contains %s" % key)
		if controls.has(key):
			_check((controls[key] as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE, "%s accepts pointer input" % key)

	var snapshot := {
		"ship_mouse_sensitivity": 0.0044,
		"on_foot_mouse_sensitivity": 0.005,
		"invert_ship_y": true,
		"invert_on_foot_y": true,
		"camera_fov": 88.0,
		"master_volume": 0.55,
		"ambience_volume": 0.45,
		"music_volume": 0.35,
		"engine_volume": 0.8,
		"weapons_volume": 0.7,
		"ui_volume": 0.65,
		"graphics_profile": 1,
		"window_mode": 2,
		"control_preset": 1,
		"ui_scale": 1.25,
		"colorblind_palette": 2,
		"reduced_motion": true,
		"captions_enabled": true,
		"input_binding_profile": settings_owner.get_input_binding_profile().to_dictionary(),
	}
	hud.set_settings_snapshot(snapshot)
	_check(_change_events.is_empty(), "programmatic snapshot population never produces feedback events")
	_check(is_equal_approx((controls[&"ship_mouse_sensitivity"] as HSlider).value, 0.0044), "ship sensitivity snapshot reaches its slider")
	_check((controls[&"invert_ship_y"] as CheckButton).button_pressed, "ship inversion snapshot reaches its toggle")
	_check(is_equal_approx((controls[&"camera_fov"] as HSlider).value, 88.0), "camera FOV snapshot reaches its slider")
	_check((controls[&"graphics_profile"] as OptionButton).selected == 1, "graphics profile snapshot reaches its selector")
	_check((controls[&"window_mode"] as OptionButton).selected == 2, "window mode snapshot reaches its selector")
	_check((controls[&"control_preset"] as OptionButton).selected == 1, "control-hint descriptor snapshot reaches its selector")
	_check(is_equal_approx((controls[&"music_volume"] as HSlider).value, 0.35), "Music snapshot reaches its dedicated slider")
	_check(is_equal_approx((controls[&"ui_scale"] as HSlider).value, 1.25), "UI scale snapshot reaches its slider")
	_check(is_equal_approx(hud.get_ui_scale(), 1.25), "UI scale snapshot applies the accessibility preview immediately")
	hud.update_ship_telemetry({"hull": 18.0, "maximum_hull": 100.0, "damage_status": "critical", "engine_power": 0.42})
	var damage_status := hud.get("_damage_status_label") as Label
	_check(
		damage_status.text.begins_with("HULL  //  !! CRITICAL !!")
		and damage_status.text.contains("ENGINE OUTPUT  042%"),
		"critical hull state remains textually legible without relying on colour"
	)
	hud.update_ship_telemetry({"hull": 76.0, "maximum_hull": 100.0, "damage_status": "healthy", "engine_power": 1.0})
	_check((hud.get("_damage_status_label") as Label).text.begins_with("HULL  //  OK"), "healthy hull state uses a stable text marker")
	_check((controls[&"colorblind_palette"] as OptionButton).selected == 2, "colour-vision preset snapshot reaches its selector")
	_check((controls[&"reduced_motion"] as CheckButton).button_pressed, "reduced motion snapshot reaches its toggle")
	hud.set_reduced_motion(true)
	hud.toast("REDUCED MOTION", "Readable toast stays steady.", 0.2)
	var reduced_toast := hud.get("_toast_panel") as Control
	_check(
		reduced_toast.visible
		and is_equal_approx(reduced_toast.modulate.a, 1.0)
		and hud.get("_toast_tween") == null,
		"reduced-motion toast is immediately readable without an animation tween"
	)
	hud.set_reduced_motion(false)
	_check((controls[&"captions_enabled"] as CheckButton).button_pressed, "caption snapshot reaches its toggle")
	_check(hud.has_signal("presentation_intent_requested"), "HUD exposes presentation-only runtime status intents")
	hud.update_network_session_status({"state": &"failed", "detail": "Admission refused.", "retryable": true})
	var runtime_status := hud.get("_runtime_status_panel") as Control
	var runtime_actions := hud.get("_runtime_status_actions") as HBoxContainer
	_check(runtime_status.visible and runtime_actions.get_child_count() == 2, "network status renders focusable retry and cancel actions")
	hud.update_surface_route_status({"waypoints": [{"label": "North Relay", "distance_m": 50.0}], "hazard": {"state": &"storm", "exposure": 0.9, "recovery_available": true}})
	_check((hud.get("_runtime_status_detail") as Label).text.contains("!! HIGH EXPOSURE !!"), "surface hazard status remains textually readable")
	hud.clear_runtime_status()
	_check(hud.are_captions_enabled(), "caption snapshot enables the HUD caption gate")
	var caption_preview := (hud.get("_settings_page") as Control).find_child("CaptionPreviewButton", true, false) as Button
	_check(caption_preview != null and caption_preview.focus_mode == Control.FOCUS_ALL, "settings exposes a controller-focusable caption preview")
	caption_preview.pressed.emit()
	var caption_report := hud.get_caption_presentation_report()
	_check(
		bool(caption_report.get("visible", false))
		and caption_report.get("rendered_text", "") == "Preview: docking corridor is clear.",
		"caption preview renders a readable audio-cue alternative without audio"
	)
	var glyph_layout := controls[&"controller_glyph_family"] as OptionButton
	_check(glyph_layout.selected == 0, "controller glyph layout starts in automatic mode")
	var value_labels := hud.get("_settings_value_labels") as Dictionary
	_check((value_labels[&"ship_mouse_sensitivity"] as Label).text == "200%", "sensitivity is presented as a friendly relative percentage")
	_check((value_labels[&"camera_fov"] as Label).text == "88°", "field of view is presented in degrees")
	_check((value_labels[&"master_volume"] as Label).text == "55%", "volume is presented as a friendly percentage")
	_check((value_labels[&"music_volume"] as Label).text == "35%", "Music volume exposes readable percentage feedback")
	var music_slider := controls[&"music_volume"] as HSlider
	var music_copy := music_slider.get_parent().get_child(0) as HBoxContainer
	_check(
		music_slider.name == &"MusicVolumeControl"
		and music_slider.focus_mode == Control.FOCUS_ALL
		and music_slider.get_parent().name == &"MusicVolumeRow",
		"Music owns a labelled controller-focusable row in the audio mix"
	)
	_check(
		music_copy != null
		and music_copy.get_child_count() > 0
		and (music_copy.get_child(0) as Label).text == "Music",
		"Music exposes unambiguous readable text beside its control"
	)
	_test_input_prompt_family_switching(hud)
	glyph_layout.select(2)
	glyph_layout.item_selected.emit(2)
	_check(
		hud.get_input_binding_report().preferred_device_family == InputGlyphResolver.FAMILY_GAMEPAD_XBOX
		and (controls[&"controller_glyph_family"] as OptionButton).selected == 2
		and _change_events.size() == 0,
		"controller glyph layout switches live prompts without creating a persisted settings event"
	)
	glyph_layout.select(0)
	glyph_layout.item_selected.emit(0)
	_check(
		hud.get_input_binding_report().preferred_device_family == InputGlyphResolver.FAMILY_KEYBOARD,
		"automatic controller glyph layout returns to the observed device family"
	)

	(controls[&"camera_fov"] as HSlider).value = 91.0
	_check(_change_events.size() == 1, "a player slider edit emits exactly one live change request")
	if not _change_events.is_empty():
		_check(_change_events[0].key == &"camera_fov" and is_equal_approx(float(_change_events[0].value), 91.0), "slider request preserves its typed key and float value")
	(controls[&"invert_ship_y"] as CheckButton).button_pressed = false
	_check(_change_events.size() == 2 and _change_events[1].key == &"invert_ship_y" and _change_events[1].value == false, "toggle edit emits its boolean value")
	var quality := controls[&"graphics_profile"] as OptionButton
	quality.select(2)
	quality.item_selected.emit(2)
	_check(_change_events.size() == 3 and _change_events[2].key == &"graphics_profile" and int(_change_events[2].value) == 2, "selector edit emits its integer profile")
	var hints := controls[&"control_preset"] as OptionButton
	hints.select(0)
	hints.item_selected.emit(0)
	_check(_change_events.size() == 4 and _change_events[3].key == &"control_preset" and int(_change_events[3].value) == 0, "control-hint edit emits its integer descriptor")
	(controls[&"music_volume"] as HSlider).value = 0.3
	_check(
		_change_events.size() == 5
		and _change_events[4].key == &"music_volume"
		and is_equal_approx(float(_change_events[4].value), 0.3),
		"a player Music edit emits its typed live volume request"
	)
	var ui_scale := controls[&"ui_scale"] as HSlider
	ui_scale.value = 1.4
	_check(is_equal_approx(hud.get_ui_scale(), 1.4), "a live text-scale edit applies immediately to the HUD preview")

	hud.set("_started", true)
	var help_panel := hud.get("_help_panel") as Control
	var help_initially_visible := help_panel.visible
	var help_press := InputEventKey.new()
	help_press.physical_keycode = KEY_F1
	help_press.pressed = true
	hud._unhandled_input(help_press)
	_check(
		help_panel.visible != help_initially_visible,
		"an initial F1 key press toggles the help panel"
	)
	var help_repeat := InputEventKey.new()
	help_repeat.physical_keycode = KEY_F1
	help_repeat.pressed = true
	help_repeat.echo = true
	hud._unhandled_input(help_repeat)
	_check(
		help_panel.visible != help_initially_visible,
		"F1 key-repeat events do not toggle help repeatedly"
	)
	hud.set_paused(true)
	var pause := hud.get("_pause") as Control
	var main_page := hud.get("_pause_main_page") as Control
	var settings_page := hud.get("_settings_page") as Control
	_check(paused and pause.visible, "opening the pause menu pauses the gameplay tree")
	_check(pause.mouse_filter == Control.MOUSE_FILTER_STOP, "pause backdrop captures mouse input")
	_check(main_page.visible and not settings_page.visible, "pause opens on the main action page")
	var open_button := main_page.find_child("SettingsOpenButton", true, false) as Button
	open_button.pressed.emit()
	_check(settings_page.visible and not main_page.visible, "Settings switches to a dedicated second page")
	_check(settings_page.size.x <= 1280.0 and settings_page.size.y <= 720.0, "settings panel fits a 1280 by 720 window")
	await _test_ultrawide_settings_layout(hud, settings_page)
	hud.set_safe_area_insets(Rect2(24.0, 18.0, 30.0, 22.0))
	var safe_effective := hud.layout_for_viewport(Vector2(3440.0, 1440.0))
	await process_frame
	await process_frame
	var safe_rects := hud.get_hud_panel_rects()
	var safe_minimap := safe_rects.get("minimap", Rect2()) as Rect2
	var safe_telemetry := safe_rects.get("telemetry", Rect2()) as Rect2
	var safe_brand := safe_rects.get("brand", Rect2()) as Rect2
	var safe_logical := Vector2(3440.0, 1440.0) / safe_effective
	_check(
		safe_brand.position.x + 0.1 >= 30.0 + 24.0 / safe_effective
		and safe_minimap.position.x + 0.1 >= 28.0 + 24.0 / safe_effective
		and safe_telemetry.end.x <= safe_logical.x - 30.0 / safe_effective + 0.1
		and safe_minimap.end.y <= safe_logical.y - 22.0 / safe_effective + 0.1,
		"gameplay HUD edge panels honor physical safe-area insets at 32:9"
	)
	hud.set_safe_area_insets(Rect2())
	hud.layout_for_viewport(Vector2(1280.0, 720.0))
	await _test_input_binding_editor(hud, settings_owner)
	await _test_deferred_settings_scroll_currentness()

	var save_button := settings_page.find_child("SettingsSaveButton", true, false) as Button
	var reset_button := settings_page.find_child("SettingsResetButton", true, false) as Button
	var back_button := settings_page.find_child("SettingsBackButton", true, false) as Button
	save_button.pressed.emit()
	reset_button.pressed.emit()
	_check(_save_events == 1, "Apply and Save emits one persistence request")
	_check(_reset_events == 1, "Reset Defaults emits one reset request")
	back_button.pressed.emit()
	_check(main_page.visible and not settings_page.visible, "Back returns to the main pause page")
	var events_before_closed_input := _change_events.size()
	_check(
		not hud.begin_input_binding_capture(&"fire"),
		"binding capture cannot remain active after the settings page closes"
	)
	var closed_page_key := InputEventKey.new()
	closed_page_key.physical_keycode = KEY_F15
	closed_page_key.pressed = true
	hud._unhandled_input(closed_page_key)
	_check(
		_change_events.size() == events_before_closed_input,
		"raw gameplay input passes through without changing bindings while settings is closed"
	)

	open_button.pressed.emit()
	var pause_event := InputEventAction.new()
	pause_event.action = &"pause"
	pause_event.pressed = true
	hud._unhandled_input(pause_event)
	_check(paused and main_page.visible and not settings_page.visible, "Escape from settings returns one level without unpausing")

	var gameplay_hud := hud.get("_hud") as Control
	_check(_all_controls_passthrough(gameplay_hud), "gameplay HUD remains fully transparent to look and fire input")
	settings_owner.reset_to_defaults()
	settings_owner.apply_input_bindings()
	hud.set_paused(false)
	hud.queue_free()
	await process_frame
	await process_frame
	_cleanup_settings_files()
	_finish()


## The settings page is a real player-facing pause surface, not just a 16:9
## fixture. Keep its fixed authored width centred and its long binding list
## vertically reachable when a wide monitor supplies substantially more
## horizontal room. Rendered ultrawide appearance still requires human review.
func _test_ultrawide_settings_layout(hud: GameHUD, settings_page: Control) -> void:
	var scroll := settings_page.find_child("SettingsScroll", true, false) as ScrollContainer
	var binding_buttons := hud.get("_binding_buttons") as Dictionary
	var viewport_cases := [Vector2(2560.0, 1080.0), Vector2(3440.0, 1440.0)]
	var dirty: Array[String] = []
	for viewport: Vector2 in viewport_cases:
		hud.layout_for_viewport(viewport)
		await process_frame
		await process_frame
		var viewport_rect := Rect2(Vector2.ZERO, viewport)
		var page_rect := settings_page.get_global_rect()
		if not viewport_rect.encloses(page_rect):
			dirty.append("%.0fx%.0f page=%s" % [viewport.x, viewport.y, str(page_rect)])
		if scroll == null or scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
			dirty.append("%.0fx%.0f horizontal scroll enabled" % [viewport.x, viewport.y])
		var final_row := binding_buttons.get(&"toggle_ship_camera_view") as Control
		if final_row != null:
			final_row.grab_focus()
			await process_frame
			if not final_row.has_focus() or scroll.scroll_vertical <= 0 or not page_rect.grow(0.5).encloses(final_row.get_global_rect()):
				dirty.append("%.0fx%.0f final binding is not focus-reachable" % [viewport.x, viewport.y])
	_check(
		dirty.is_empty(),
		"settings page remains enclosed, horizontal-scroll-free, and controller-reachable at 21:9/32:9 (%d cases)%s"
		% [viewport_cases.size(), " -- " + "; ".join(dirty) if not dirty.is_empty() else ""],
	)


func _test_input_binding_editor(hud: GameHUD, settings_owner: RuntimeSettings) -> void:
	var settings_flow := GameFlow.new()
	settings_flow.runtime_settings = settings_owner
	settings_owner.setting_changed.connect(settings_flow._on_runtime_setting_changed)
	hud.setting_change_requested.connect(settings_flow._on_setting_change_requested)
	var expected_actions := PackedStringArray([
		"barrel_roll", "brake", "camera_distance_in", "camera_distance_out", "fire",
		"hover", "interact", "jump", "landing_assist", "move_back", "move_forward",
		"move_left", "move_right", "pause", "pitch_down", "pitch_up", "roll_left",
		"roll_right", "sprint_boost", "toggle_controls_overlay", "toggle_first_person",
		"toggle_ship_camera_view",
	])
	var report := hud.get_input_binding_report()
	_check(report.actions == expected_actions, "settings builds the exact validated 22-action gameplay binding roster")
	_check(int(report.action_count) == 22, "every validated gameplay action owns one real binding row")
	var binding_buttons := hud.get("_binding_buttons") as Dictionary
	var reset_buttons := hud.get("_binding_reset_buttons") as Dictionary
	_check(
		binding_buttons.size() == 22 and reset_buttons.size() == 22,
		"each action exposes capture and per-action reset controls"
	)
	for action: StringName in binding_buttons:
		_check(
			(binding_buttons[action] as Button).focus_mode == Control.FOCUS_ALL
			and (reset_buttons[action] as Button).focus_mode == Control.FOCUS_ALL,
			"%s capture and reset controls participate in controller focus navigation" % action
		)
	var scroll := (hud.get("_settings_page") as Control).find_child("SettingsScroll", true, false) as ScrollContainer
	_check(scroll != null and scroll.follow_focus, "binding focus automatically follows the scroll viewport")
	var last_binding_button := binding_buttons[&"toggle_ship_camera_view"] as Button
	last_binding_button.grab_focus()
	await process_frame
	await process_frame
	_check(
		scroll.scroll_vertical > 0
		and last_binding_button.has_focus()
		and scroll.get_global_rect().intersects(last_binding_button.get_global_rect()),
		"the final binding row remains controller-reachable through focus scrolling at 1280 by 720"
	)
	var focus_before_navigation := root.gui_get_focus_owner()
	var controller_focus := InputEventJoypadButton.new()
	controller_focus.button_index = JOY_BUTTON_DPAD_RIGHT
	controller_focus.pressed = true
	root.push_input(controller_focus)
	await process_frame
	var focus_after_navigation := root.gui_get_focus_owner()
	_check(
		focus_before_navigation == last_binding_button
		and focus_after_navigation != null
		and focus_after_navigation != focus_before_navigation
		and hud.get_input_binding_report().preferred_device_family
		== InputGlyphResolver.FAMILY_GAMEPAD_GENERIC,
		"a handled UI gamepad-navigation event reaches raw observation, switches prompts, and advances controller focus"
	)
	var restore_keyboard := InputEventKey.new()
	restore_keyboard.physical_keycode = KEY_F
	restore_keyboard.pressed = true
	root.push_input(restore_keyboard)
	_check(
		GameFlow.RUNTIME_SETTING_KEYS.has(&"input_binding_profile"),
		"GameFlow accepts the validated input profile emitted by the real HUD"
	)

	var events_before_bindings := _change_events.size()
	_check(hud.begin_input_binding_capture(&"fire"), "keyboard capture starts from the visible Fire row")
	var keyboard := InputEventKey.new()
	keyboard.physical_keycode = KEY_F13
	keyboard.pressed = true
	hud._unhandled_input(keyboard)
	_check(
		_change_events.size() == events_before_bindings + 1
		and _profile_has_key(settings_owner.get_input_binding_profile(), &"fire", KEY_F13)
		and not _profile_has_key(settings_owner.get_input_binding_profile(), &"fire", KEY_F)
		and not _profile_has_mouse(settings_owner.get_input_binding_profile(), &"fire", MOUSE_BUTTON_LEFT),
		"keyboard capture replaces Fire's desktop-family bindings in RuntimeSettings"
	)
	_check(
		_input_map_has_key(&"fire", KEY_F13)
		and not _input_map_has_key(&"fire", KEY_F)
		and not _input_map_has_mouse(&"fire", MOUSE_BUTTON_LEFT),
		"accepted keyboard replacement changes the live InputMap immediately"
	)

	_check(hud.begin_input_binding_capture(&"brake"), "mouse capture starts from the visible Brake row")
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_MIDDLE
	mouse.pressed = true
	hud._unhandled_input(mouse)
	_check(
		_profile_has_mouse(settings_owner.get_input_binding_profile(), &"brake", MOUSE_BUTTON_MIDDLE),
		"mouse-button capture reaches the canonical RuntimeSettings profile"
	)

	_check(hud.begin_input_binding_capture(&"landing_assist"), "gamepad capture starts from the visible Landing row")
	var gamepad := InputEventJoypadButton.new()
	gamepad.button_index = 15
	gamepad.pressed = true
	hud._unhandled_input(gamepad)
	_check(
		_profile_has_joy_button(settings_owner.get_input_binding_profile(), &"landing_assist", 15),
		"gamepad-button capture reaches the canonical RuntimeSettings profile"
	)
	_check(hud.begin_input_binding_capture(&"landing_assist"), "gamepad-axis capture reuses the visible Landing row")
	var gamepad_axis := InputEventJoypadMotion.new()
	gamepad_axis.axis = JOY_AXIS_TRIGGER_LEFT
	gamepad_axis.axis_value = -0.82
	hud._unhandled_input(gamepad_axis)
	_check(
		_profile_has_joy_motion(
			settings_owner.get_input_binding_profile(),
			&"landing_assist",
			JOY_AXIS_TRIGGER_LEFT,
			-1.0
		)
		and not _profile_has_joy_button(
			settings_owner.get_input_binding_profile(), &"landing_assist", 15
		),
		"gamepad-axis capture crosses its noise threshold and replaces the gamepad family"
	)

	var events_before_conflict := _change_events.size()
	_check(hud.begin_input_binding_capture(&"barrel_roll"), "conflict probe listens on Barrel Roll")
	var conflicting_key := InputEventKey.new()
	conflicting_key.physical_keycode = KEY_H
	conflicting_key.pressed = true
	hud._unhandled_input(conflicting_key)
	var conflict_panel := hud.get("_binding_conflict_panel") as Control
	_check(
		conflict_panel.visible
		and bool(hud.get_input_binding_report().has_pending_conflict)
		and _change_events.size() == events_before_conflict,
		"a conflicting capture is rejected transactionally and presents an explicit choice"
	)
	var replace_button := hud.get("_binding_conflict_replace_button") as Button
	var cancel_button := hud.get("_binding_conflict_cancel_button") as Button
	_check(
		replace_button.focus_mode == Control.FOCUS_ALL
		and cancel_button.focus_mode == Control.FOCUS_ALL
		and replace_button.has_focus(),
		"conflict resolution moves controller focus to explicit Replace and Cancel actions"
	)
	replace_button.pressed.emit()
	_check(
		_profile_has_key(settings_owner.get_input_binding_profile(), &"barrel_roll", KEY_H)
		and not _profile_has_key(settings_owner.get_input_binding_profile(), &"hover", KEY_H)
		and not conflict_panel.visible
		and (binding_buttons[&"barrel_roll"] as Button).has_focus(),
		"explicit Replace transfers the conflict and returns controller focus to its row"
	)

	var fire_reset := reset_buttons[&"fire"] as Button
	fire_reset.pressed.emit()
	_check(
		_profile_has_key(settings_owner.get_input_binding_profile(), &"fire", KEY_F)
		and _profile_has_mouse(settings_owner.get_input_binding_profile(), &"fire", MOUSE_BUTTON_LEFT)
		and not _profile_has_key(settings_owner.get_input_binding_profile(), &"fire", KEY_F13),
		"per-action reset restores all authored Fire bindings after family replacement"
	)

	var reset_all := (hud.get("_settings_page") as Control).find_child("InputBindingsResetAllButton", true, false) as Button
	reset_all.pressed.emit()
	_check(
		settings_owner.get_input_binding_profile().to_dictionary()
		== InputRebindService.new().get_defaults().to_dictionary(),
		"Reset All Bindings restores the complete captured project profile"
	)

	_check(hud.begin_input_binding_capture(&"toggle_first_person"), "persistence witness starts one final keyboard capture")
	var persisted_key := InputEventKey.new()
	persisted_key.physical_keycode = KEY_F14
	persisted_key.pressed = true
	hud._unhandled_input(persisted_key)
	_check(hud.begin_input_binding_capture(&"landing_assist"), "re-entry witness starts one final gamepad capture")
	var persisted_gamepad := InputEventJoypadButton.new()
	persisted_gamepad.button_index = 15
	persisted_gamepad.pressed = true
	hud._unhandled_input(persisted_gamepad)
	_check(settings_owner.save_to_file() == OK, "HUD-produced binding profile persists through RuntimeSettings")
	var restored := Settings.new(_temp_settings_path)
	_check(restored.load_from_file() == OK, "a fresh RuntimeSettings owner loads the HUD-produced profile")
	_check(
		_profile_has_key(restored.get_input_binding_profile(), &"toggle_first_person", KEY_F14)
		and not _profile_has_key(restored.get_input_binding_profile(), &"toggle_first_person", KEY_C)
		and _profile_has_joy_button(restored.get_input_binding_profile(), &"landing_assist", 15),
		"saved desktop and gamepad replacements round-trip from the real settings UI"
	)
	await _test_recreated_hud_uses_project_defaults(settings_owner)
	hud.setting_change_requested.disconnect(settings_flow._on_setting_change_requested)
	settings_owner.setting_changed.disconnect(settings_flow._on_runtime_setting_changed)
	settings_flow.free()


func _test_recreated_hud_uses_project_defaults(settings_owner: RuntimeSettings) -> void:
	var project_defaults := settings_owner.get_project_input_binding_defaults()
	var detached_probe := project_defaults.duplicate_profile()
	detached_probe.set_bindings(&"fire", [])
	_check(
		not settings_owner.get_project_input_binding_defaults().get_bindings(&"fire").is_empty(),
		"RuntimeSettings exposes authored defaults as a detached process-stable profile"
	)

	# InputMap is intentionally still custom when this replacement HUD enters the
	# tree, reproducing whole-Main re-entry without recapturing live bindings.
	var second_hud := GameHUD.new()
	second_hud.name = "ReenteredSettingsHUDTest"
	root.add_child(second_hud)
	await process_frame
	var reentered_flow := GameFlow.new()
	reentered_flow.runtime_settings = settings_owner
	reentered_flow.hud = second_hud
	settings_owner.setting_changed.connect(reentered_flow._on_runtime_setting_changed)
	second_hud.setting_change_requested.connect(reentered_flow._on_setting_change_requested)
	reentered_flow._sync_runtime_settings_hud()
	second_hud.set("_started", true)
	second_hud.set_paused(true)
	var main_page := second_hud.get("_pause_main_page") as Control
	var open_button := main_page.find_child("SettingsOpenButton", true, false) as Button
	open_button.pressed.emit()

	var reset_buttons := second_hud.get("_binding_reset_buttons") as Dictionary
	(reset_buttons[&"toggle_first_person"] as Button).pressed.emit()
	_check(
		settings_owner.get_input_binding_profile().get_bindings(&"toggle_first_person")
		== project_defaults.get_bindings(&"toggle_first_person")
		and _input_map_has_key(&"toggle_first_person", KEY_C)
		and not _input_map_has_key(&"toggle_first_person", KEY_F14),
		"a per-action reset on the recreated HUD restores authored desktop defaults"
	)
	_check(
		_profile_has_joy_button(settings_owner.get_input_binding_profile(), &"landing_assist", 15),
		"the per-action reset leaves the separate custom gamepad action intact"
	)
	var reset_all := second_hud.find_child("InputBindingsResetAllButton", true, false) as Button
	reset_all.pressed.emit()
	_check(
		settings_owner.get_input_binding_profile().to_dictionary() == project_defaults.to_dictionary()
		and not _profile_has_joy_button(
			settings_owner.get_input_binding_profile(), &"landing_assist", 15
		),
		"Reset All on the recreated HUD restores the original project profile, not the live custom map"
	)
	_check(
		second_hud.get_input_binding_report().preferred_device_family
		== InputGlyphResolver.FAMILY_KEYBOARD,
		"a recreated HUD starts from deterministic keyboard prompts and resets do not inherit stale device state"
	)

	second_hud.setting_change_requested.disconnect(reentered_flow._on_setting_change_requested)
	settings_owner.setting_changed.disconnect(reentered_flow._on_runtime_setting_changed)
	reentered_flow.free()
	second_hud.queue_free()
	await process_frame


func _test_deferred_settings_scroll_currentness() -> void:
	var probe := GameHUD.new()
	probe.name = "DeferredSettingsScrollHUDTest"
	root.add_child(probe)
	await process_frame
	probe.set_paused(true)
	var main_page := probe.get("_pause_main_page") as Control
	var open_button := main_page.find_child("SettingsOpenButton", true, false) as Button
	open_button.pressed.emit()
	var settings_page := probe.get("_settings_page") as Control
	var scroll := settings_page.find_child("SettingsScroll", true, false) as ScrollContainer
	var binding_buttons := probe.get("_binding_buttons") as Dictionary
	var target := binding_buttons[&"toggle_ship_camera_view"] as Control
	await process_frame
	await process_frame
	scroll.scroll_vertical = 0
	var detached_before := _scroll_snapshot(scroll)
	probe.call("_scroll_to_input_binding", target)
	root.remove_child(probe)
	await process_frame
	_check(
		_scroll_snapshot(scroll) == detached_before,
		"a detached HUD discards its queued Settings scroll without mutating retained layout"
	)

	root.add_child(probe)
	await process_frame
	scroll.scroll_vertical = 0
	probe.call("_scroll_to_input_binding", target)
	await process_frame
	_check(
		scroll.scroll_vertical > 0
		and target.is_inside_tree()
		and settings_page.is_ancestor_of(target),
		"a reentered HUD accepts a fresh Settings scroll for its current binding row"
	)

	scroll.scroll_vertical = 0
	var pause := probe.get("_pause") as Control
	var hidden_ancestor_before := _scroll_snapshot(scroll)
	probe.call("_scroll_to_input_binding", target)
	pause.visible = false
	await process_frame
	_check(
		settings_page.visible
		and not settings_page.is_visible_in_tree()
		and _scroll_snapshot(scroll) == hidden_ancestor_before,
		"a hidden pause ancestor discards pending Settings scroll without retaining an offset"
	)
	pause.visible = true

	var queued_before := _scroll_snapshot(scroll)
	probe.call("_scroll_to_input_binding", target)
	probe.queue_free()
	probe.call("_ensure_settings_control_visible", target)
	_check(
		_scroll_snapshot(scroll) == queued_before,
		"a queued in-tree HUD rejects both direct and pending Settings-scroll layout mutation"
	)
	await process_frame


func _scroll_snapshot(scroll: ScrollContainer) -> Dictionary:
	return {
		"horizontal": scroll.scroll_horizontal,
		"vertical": scroll.scroll_vertical,
		"rect": scroll.get_global_rect(),
	}.duplicate(true)


func _test_input_prompt_family_switching(hud: GameHUD) -> void:
	var buttons := hud.get("_binding_buttons") as Dictionary
	var fire := buttons[&"fire"] as Button
	_check(
		hud.get_input_binding_report().preferred_device_family
		== InputGlyphResolver.FAMILY_KEYBOARD
		and fire.text == "F",
		"HUD begins with the resolver's deterministic physical-keyboard binding text"
	)

	var release := InputEventJoypadButton.new()
	release.button_index = JOY_BUTTON_DPAD_RIGHT
	release.pressed = false
	root.push_input(release)
	var echo := InputEventKey.new()
	echo.physical_keycode = KEY_G
	echo.pressed = true
	echo.echo = true
	root.push_input(echo)
	var noise := InputEventJoypadMotion.new()
	noise.axis = JOY_AXIS_LEFT_X
	noise.axis_value = 0.18
	root.push_input(noise)
	var unbound_axis := InputEventJoypadMotion.new()
	unbound_axis.axis = JOY_AXIS_TRIGGER_LEFT
	unbound_axis.axis_value = -1.0
	root.push_input(unbound_axis)
	_check(
		hud.get_input_binding_report().preferred_device_family
		== InputGlyphResolver.FAMILY_KEYBOARD
		and fire.text == "F",
		"released buttons, key echo, at-deadzone motion, and unbound axes cannot switch prompt family"
	)

	var controller := InputEventJoypadButton.new()
	controller.button_index = JOY_BUTTON_DPAD_RIGHT
	controller.pressed = true
	root.push_input(controller)
	var controller_rows := hud._help_rows_for_mode(GameHUD.MODE_ON_FOOT) as Array
	_check(
		hud.get_input_binding_report().preferred_device_family
		== InputGlyphResolver.FAMILY_GAMEPAD_GENERIC
		and fire.text == "Right Trigger"
		and _prompt_for_detail(controller_rows, "INTERACT / BOARD") == "Left Face Button"
		and _prompt_for_detail(controller_rows, "CONTROLS") == "Back",
		"accepted controller activity selects generic accessible gamepad text in settings and help prompts"
	)

	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	root.push_input(mouse)
	_check(
		hud.get_input_binding_report().preferred_device_family
		== InputGlyphResolver.FAMILY_MOUSE
		and fire.text == "Left Mouse",
		"accepted mouse activity selects the desktop mouse binding when one exists"
	)
	var keyboard := InputEventKey.new()
	keyboard.physical_keycode = KEY_F
	keyboard.pressed = true
	root.push_input(keyboard)
	_check(
		hud.get_input_binding_report().preferred_device_family
		== InputGlyphResolver.FAMILY_KEYBOARD
		and fire.text == "F"
		and _prompt_for_detail(hud._help_rows_for_mode(GameHUD.MODE_ON_FOOT), "INTERACT / BOARD") == "E",
		"accepted keyboard activity restores physical-key desktop text throughout the HUD"
	)


func _prompt_for_detail(rows: Array, detail: String) -> String:
	for row: Array in rows:
		if str(row[1]) == detail:
			return str(row[0])
	return ""


func _test_product_branding(hud: GameHUD) -> void:
	_check(
		str(ProjectSettings.get_setting("application/config/name", "")) == "Mudds Shipyards",
		"the runtime window uses the Mudds Shipyards product name"
	)
	var labels: Array[String] = []
	_collect_label_text(hud, labels)
	_check("MUDDS" in labels and "SHIPYARDS" in labels, "the title screen carries the Mudds Shipyards brand")
	_check("MUDDS  /  SHIPYARDS" in labels, "the live HUD carries the Mudds Shipyards brand")
	var export_config := ConfigFile.new()
	var load_error := export_config.load("res://export_presets.cfg")
	_check(load_error == OK, "the Windows export metadata is readable")
	if load_error == OK:
		_check(
			str(export_config.get_value("preset.0", "export_path", "")) == "builds/windows/MuddsShipyards.exe",
			"the Windows export uses the branded executable name"
		)
		_check(
			str(export_config.get_value("preset.0.options", "application/product_name", "")) == "Mudds Shipyards",
			"the Windows executable embeds the Mudds Shipyards product name"
		)
		_check(
			str(export_config.get_value("preset.0.options", "application/file_version", "")) == "0.12.0.0",
			"the branded Windows file metadata advances to v0.12"
		)
		_check(
			str(export_config.get_value("preset.0.options", "application/product_version", "")) == "0.12.0.0",
			"the branded Windows product metadata advances to v0.12"
		)


func _collect_label_text(node: Node, output: Array[String]) -> void:
	if node is Label:
		output.append((node as Label).text)
	for child in node.get_children():
		_collect_label_text(child as Node, output)


func _all_controls_passthrough(control: Control) -> bool:
	if control.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return false
	for child in control.get_children():
		if child is Control and not _all_controls_passthrough(child as Control):
			return false
	return true


func _on_setting_change_requested(key: StringName, value: Variant) -> void:
	_change_events.append({"key": key, "value": value})


func _profile_has_key(
	profile: InputBindingProfile,
	action: StringName,
	physical_keycode: Key
) -> bool:
	for binding: Dictionary in profile.get_bindings(action):
		if (
			StringName(binding.get("type", &"")) == &"key"
			and int(binding.get("physical_keycode", 0)) == physical_keycode
		):
			return true
	return false


func _profile_has_mouse(
	profile: InputBindingProfile,
	action: StringName,
	button_index: MouseButton
) -> bool:
	for binding: Dictionary in profile.get_bindings(action):
		if (
			StringName(binding.get("type", &"")) == &"mouse_button"
			and int(binding.get("button_index", 0)) == button_index
		):
			return true
	return false


func _profile_has_joy_button(
	profile: InputBindingProfile,
	action: StringName,
	button_index: int
) -> bool:
	for binding: Dictionary in profile.get_bindings(action):
		if (
			StringName(binding.get("type", &"")) == &"joy_button"
			and int(binding.get("button_index", -1)) == button_index
		):
			return true
	return false


func _profile_has_joy_motion(
	profile: InputBindingProfile,
	action: StringName,
	axis: JoyAxis,
	direction: float
) -> bool:
	for binding: Dictionary in profile.get_bindings(action):
		if (
			StringName(binding.get("type", &"")) == &"joy_motion"
			and int(binding.get("axis", -1)) == axis
			and is_equal_approx(float(binding.get("axis_value", 0.0)), direction)
		):
			return true
	return false


func _input_map_has_key(action: StringName, physical_keycode: Key) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if (
			event is InputEventKey
			and (event as InputEventKey).physical_keycode == physical_keycode
		):
			return true
	return false


func _input_map_has_mouse(action: StringName, button_index: MouseButton) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if (
			event is InputEventMouseButton
			and (event as InputEventMouseButton).button_index == button_index
		):
			return true
	return false


func _cleanup_settings_files() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		var path := _temp_settings_path + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("SETTINGS_UI_TEST_OK")
		quit(0)
	else:
		print("SETTINGS_UI_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
