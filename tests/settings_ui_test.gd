extends SceneTree

var _failures: Array[String] = []
var _change_events: Array[Dictionary] = []
var _save_events := 0
var _reset_events := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
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
		&"engine_volume",
		&"weapons_volume",
		&"ui_volume",
		&"graphics_profile",
		&"window_mode",
		&"control_preset",
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
		"engine_volume": 0.8,
		"weapons_volume": 0.7,
		"ui_volume": 0.65,
		"graphics_profile": 1,
		"window_mode": 2,
		"control_preset": 1,
	}
	hud.set_settings_snapshot(snapshot)
	_check(_change_events.is_empty(), "programmatic snapshot population never produces feedback events")
	_check(is_equal_approx((controls[&"ship_mouse_sensitivity"] as HSlider).value, 0.0044), "ship sensitivity snapshot reaches its slider")
	_check((controls[&"invert_ship_y"] as CheckButton).button_pressed, "ship inversion snapshot reaches its toggle")
	_check(is_equal_approx((controls[&"camera_fov"] as HSlider).value, 88.0), "camera FOV snapshot reaches its slider")
	_check((controls[&"graphics_profile"] as OptionButton).selected == 1, "graphics profile snapshot reaches its selector")
	_check((controls[&"window_mode"] as OptionButton).selected == 2, "window mode snapshot reaches its selector")
	_check((controls[&"control_preset"] as OptionButton).selected == 1, "control-hint descriptor snapshot reaches its selector")
	var value_labels := hud.get("_settings_value_labels") as Dictionary
	_check((value_labels[&"ship_mouse_sensitivity"] as Label).text == "200%", "sensitivity is presented as a friendly relative percentage")
	_check((value_labels[&"camera_fov"] as Label).text == "88°", "field of view is presented in degrees")
	_check((value_labels[&"master_volume"] as Label).text == "55%", "volume is presented as a friendly percentage")

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

	hud.set("_started", true)
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

	var save_button := settings_page.find_child("SettingsSaveButton", true, false) as Button
	var reset_button := settings_page.find_child("SettingsResetButton", true, false) as Button
	var back_button := settings_page.find_child("SettingsBackButton", true, false) as Button
	save_button.pressed.emit()
	reset_button.pressed.emit()
	_check(_save_events == 1, "Apply and Save emits one persistence request")
	_check(_reset_events == 1, "Reset Defaults emits one reset request")
	back_button.pressed.emit()
	_check(main_page.visible and not settings_page.visible, "Back returns to the main pause page")

	open_button.pressed.emit()
	var pause_event := InputEventAction.new()
	pause_event.action = &"pause"
	pause_event.pressed = true
	hud._unhandled_input(pause_event)
	_check(paused and main_page.visible and not settings_page.visible, "Escape from settings returns one level without unpausing")

	var gameplay_hud := hud.get("_hud") as Control
	_check(_all_controls_passthrough(gameplay_hud), "gameplay HUD remains fully transparent to look and fire input")
	hud.set_paused(false)
	hud.queue_free()
	await process_frame
	await process_frame
	_finish()


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
