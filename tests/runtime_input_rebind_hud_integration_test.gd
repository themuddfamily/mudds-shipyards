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
	hud.call("_show_settings_page")
	var presenter: Variant = hud.get("_runtime_input_rebind_presenter")
	_check(presenter != null, "settings HUD retains the detached rebind presenter")
	var fire_button := (hud.get("_binding_buttons") as Dictionary).get(&"fire") as Button
	_check(fire_button != null and fire_button.focus_mode == Control.FOCUS_ALL, "binding rows remain controller-focusable")
	_check(hud.begin_input_binding_capture(&"fire"), "visible settings row starts presenter capture")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_F13
	key.pressed = true
	hud._unhandled_input(key)
	_check(
		bool((hud.get("_input_binding_profile") as InputBindingProfile).get_bindings(&"fire").any(func(binding: Dictionary) -> bool: return int(binding.get("physical_keycode", -1)) == KEY_F13)),
		"accepted capture updates the caller-owned profile and row"
	)
	_check(fire_button.text == "F13", "accepted capture refreshes the visible glyph label")
	var old_generation := int(presenter.get_snapshot().get("generation", -1))
	_check(not bool(presenter.begin_capture(&"fire", old_generation - 1).get("accepted", false)), "stale HUD presenter generations are rejected")
	_check(hud.begin_input_binding_capture(&"barrel_roll"), "conflict probe starts from a controller-focusable row")
	var conflict_key := InputEventKey.new()
	conflict_key.physical_keycode = KEY_H
	conflict_key.pressed = true
	hud._unhandled_input(conflict_key)
	var panel := hud.get("_binding_conflict_panel") as Control
	_check(panel.visible, "conflicting capture exposes the HUD conflict panel")
	_check((hud.get("_binding_conflict_replace_button") as Button).focus_mode == Control.FOCUS_ALL and (hud.get("_binding_conflict_cancel_button") as Button).focus_mode == Control.FOCUS_ALL, "conflict choices remain controller-focusable")
	(hud.get("_binding_conflict_cancel_button") as Button).pressed.emit()
	_check(not panel.visible and not bool(hud.get_input_binding_report().has_pending_conflict), "cancel clears the pending presenter conflict")
	var reset_button := (hud.get("_binding_reset_buttons") as Dictionary).get(&"fire") as Button
	reset_button.pressed.emit()
	_check(fire_button.text != "F13", "reset refreshes the row through the presenter profile intent")
	_check(
		_has_binding(
			(hud.get("_input_binding_profile") as InputBindingProfile).get_bindings(&"barrel_roll"),
			&"key",
			KEY_G
		),
		"a cancelled conflict does not leak its stripped draft into a later per-action reset"
	)
	_check(hud.begin_input_binding_capture(&"fire"), "reserved-key probe listens on Fire")
	hud._unhandled_input(_key(KEY_F2, true))
	var replace_button := hud.get("_binding_conflict_replace_button") as Button
	if (hud.get("_binding_conflict_panel") as Control).visible:
		replace_button.pressed.emit()
	var guarded := hud.get("_input_binding_profile") as InputBindingProfile
	_check(
		_has_binding(guarded.get_bindings(&"capture_screenshot"), &"key", KEY_F2)
		and not _has_binding(guarded.get_bindings(&"fire"), &"key", KEY_F2)
		and StringName(hud.get_input_binding_report().capturing_action).is_empty(),
		"the screenshot key, which has no settings row, cannot be stolen through conflict Replace"
	)
	await _test_gui_routed_capture(hud)
	hud.queue_free()
	await process_frame
	if _failures.is_empty():
		print("RUNTIME_INPUT_REBIND_HUD_INTEGRATION_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


## Real players reach capture through the focused row, so these events travel
## the viewport's GUI route (root.push_input) rather than a direct callback.
func _test_gui_routed_capture(hud: Node) -> void:
	root.content_scale_size = Vector2i(1280, 720)
	hud.set_paused(true)
	var main_page := hud.get("_pause_main_page") as Control
	(main_page.find_child("SettingsOpenButton", true, false) as Button).pressed.emit()
	await process_frame
	var interact_button := (hud.get("_binding_buttons") as Dictionary).get(&"interact") as Button
	interact_button.grab_focus()
	await process_frame
	await _press_and_release(_key(KEY_ENTER, true), _key(KEY_ENTER, false))
	_check(
		StringName(hud.get_input_binding_report().capturing_action) == &"interact",
		"Enter on a focused binding row arms capture through the GUI route"
	)
	await _press_and_release(_key(KEY_KP_ENTER, true), _key(KEY_KP_ENTER, false))
	var report: Dictionary = hud.get_input_binding_report()
	_check(
		StringName(report.capturing_action).is_empty()
		and _has_binding(report.bindings[&"interact"], &"key", KEY_KP_ENTER),
		"binding a menu-accept key completes capture instead of re-arming the row on release"
	)
	interact_button.grab_focus()
	await process_frame
	await _press_and_release(_joy(JOY_BUTTON_A, true), _joy(JOY_BUTTON_A, false))
	_check(
		StringName(hud.get_input_binding_report().capturing_action) == &"interact",
		"pad A on a focused binding row arms capture"
	)
	await _press_and_release(_joy(JOY_BUTTON_DPAD_DOWN, true), _joy(JOY_BUTTON_DPAD_DOWN, false))
	report = hud.get_input_binding_report()
	_check(
		StringName(report.capturing_action).is_empty()
		and _has_binding(report.bindings[&"interact"], &"joy_button", JOY_BUTTON_DPAD_DOWN)
		and interact_button.has_focus(),
		"a D-pad press is captured as the binding instead of moving focus off an armed row"
	)
	(hud.get("_binding_reset_buttons") as Dictionary)[&"interact"].pressed.emit()
	hud.set_paused(false)


func _press_and_release(pressed: InputEvent, released: InputEvent) -> void:
	root.push_input(pressed)
	await process_frame
	root.push_input(released)
	await process_frame


func _key(code: Key, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	return event


func _joy(button: JoyButton, pressed: bool) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = pressed
	return event


func _has_binding(bindings: Array, type: StringName, code: int) -> bool:
	for binding: Dictionary in bindings:
		if StringName(binding.get("type", &"")) != type:
			continue
		if int(binding.get("physical_keycode", binding.get("button_index", -1))) == code:
			return true
	return false


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)
