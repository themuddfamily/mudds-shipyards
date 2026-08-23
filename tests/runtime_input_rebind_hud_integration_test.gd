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
	hud.queue_free()
	await process_frame
	if _failures.is_empty():
		print("RUNTIME_INPUT_REBIND_HUD_INTEGRATION_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)
