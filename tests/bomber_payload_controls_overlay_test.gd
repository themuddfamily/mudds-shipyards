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
	hud.set_mode("piloting")
	hud.set_ship_identity("Cinder long-range bomber", "Long-range bomber")
	var cinder_rows := hud.call("_help_rows_for_mode", HudType.MODE_PILOTING) as Array
	_check(
		_has_control_label(cinder_rows, "RELEASE PAYLOAD")
		and not _has_control_label(cinder_rows, "FIRE"),
		"Cinder replaces the generic piloting FIRE row with RELEASE PAYLOAD",
	)
	hud.set_ship_identity("Torrent-class Interceptor", "Interceptor")
	var ordinary_rows := hud.call("_help_rows_for_mode", HudType.MODE_PILOTING) as Array
	_check(
		_has_control_label(ordinary_rows, "FIRE")
		and not _has_control_label(ordinary_rows, "RELEASE PAYLOAD"),
		"ordinary craft retain the established piloting FIRE row",
	)
	hud.set_ship_identity("Another long-range bomber", "Long-range bomber")
	_check(
		_has_control_label(
			hud.call("_help_rows_for_mode", HudType.MODE_PILOTING) as Array,
			"FIRE",
		),
		"the bomber role alone cannot replace another craft's FIRE row",
	)
	hud.set_ship_identity("Cinder long-range bomber", "Interceptor")
	_check(
		_has_control_label(
			hud.call("_help_rows_for_mode", HudType.MODE_PILOTING) as Array,
			"FIRE",
		),
		"the Cinder display name alone cannot replace another role's FIRE row",
	)
	hud.set_ship_identity("Cinder long-range bomber", "Long-range bomber")
	hud.set_accessibility({"reduced_flash": true, "payload_visual_intensity": 0})
	hud.set_runtime_status_card(&"surface", {"title": "SURFACE ROUTE", "message": "Retained"})
	hud.apply_bomber_payload_snapshot({
		"generation": 1,
		"active": true,
		"ammo": 2,
		"cooldown_remaining": 0.0,
		"action_id": "fire",
	})
	var button := hud.get("_bomber_payload_help_button") as Button
	_check(button != null and button.visible and button.focus_mode == Control.FOCUS_ALL, "payload tutorial row is controller-focusable")
	_check(button != null and button.text.contains("PAYLOAD") and button.text.contains("READY"), "payload row shows readiness and remapped action context")
	_check(button != null and button.tooltip_text.contains("Remaining: 2"), "payload row explains remaining ammunition semantics")
	_check(button != null and button.tooltip_text.contains("Reduced flash: ON") and button.tooltip_text.contains("Visual intensity: LOW"), "payload row explains active accessibility profile")
	var action_band := hud.get("_bomber_status_actions") as HBoxContainer
	var action_button := action_band.get_child(0) as Button
	var cards := hud.get("_runtime_status_cards") as Dictionary
	var bomber_serial := int((cards[&"bomber"] as Dictionary).get("serial", -1))
	var surface_serial := int((cards[&"surface"] as Dictionary).get("serial", -1))
	action_button.grab_focus()
	await process_frame
	_check(
		action_button.text.contains("[F]") and button.text.contains("[F]"),
		"keyboard fire binding labels both retained Cinder payload surfaces",
	)
	var presenter: Variant = hud.get("_runtime_input_glyph_presenter")
	presenter.set_device_family(&"gamepad_xbox")
	hud.call("_refresh_input_prompts")
	await process_frame
	_check(
		action_band.get_child(0) == action_button
		and hud.get_viewport().gui_get_focus_owner() == action_button
		and action_button.text.contains("[RT]")
		and button.text.contains("[RT]"),
		"Xbox refresh updates both payload glyphs in place without losing action focus",
	)
	presenter.set_device_family(&"gamepad_playstation")
	hud.call("_refresh_input_prompts")
	await process_frame
	cards = hud.get("_runtime_status_cards") as Dictionary
	_check(
		action_band.get_child(0) == action_button
		and hud.get_viewport().gui_get_focus_owner() == action_button
		and action_button.text.contains("[R2]")
		and button.text.contains("[R2]")
		and int((cards[&"bomber"] as Dictionary).get("serial", -1)) == bomber_serial
		and int((cards[&"surface"] as Dictionary).get("serial", -1)) == surface_serial
		and StringName(str(((cards[&"bomber"] as Dictionary).get("snapshot", {}) as Dictionary).get("action_id", &""))) == &"fire"
		and StringName(str((hud.get("_bomber_payload_help_snapshot") as Dictionary).get("action_id", &""))) == &"fire"
		and str(((cards[&"surface"] as Dictionary).get("snapshot", {}) as Dictionary).get("message", "")) == "Retained",
		"PlayStation refresh preserves button identity, focus, keyed serials, and background content",
	)
	var emitted_intents := [0]
	hud.presentation_intent_requested.connect(
		func(kind: StringName, _payload: Dictionary) -> void:
			if kind == &"bomber":
				emitted_intents[0] += 1
	)
	action_button.pressed.emit()
	_check(emitted_intents[0] == 1, "in-place glyph refresh preserves the bomber action signal route")
	hud.apply_bomber_payload_snapshot({"generation": 2, "active": true, "ammo": 1, "cooldown_remaining": 1.5, "action_id": "fire"})
	_check(button != null and button.tooltip_text.contains("Cooldown: 1.5 seconds"), "payload row explains cooldown semantics")
	hud.apply_bomber_payload_snapshot({"generation": 3, "active": true, "ammo": 0, "cooldown_remaining": 0.0, "denied_reason": "hardpoint_locked"})
	_check(button != null and button.tooltip_text.contains("Unavailable: hardpoint_locked"), "payload row explains unavailable reason")
	hud.clear_bomber_payload_status()
	_check(
		button != null and not button.visible
		and (hud.get("_runtime_status_panel") as Control).visible
		and (hud.get("_runtime_status_title") as Label).text == "SURFACE ROUTE",
		"payload detach clears its row and restores the unchanged background card",
	)
	hud.queue_free()
	await process_frame
	if _failures.is_empty():
		print("BOMBER_PAYLOAD_CONTROLS_OVERLAY_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)


func _has_control_label(rows: Array, expected: String) -> bool:
	for row_value: Variant in rows:
		var row := row_value as Array
		if row.size() >= 2 and str(row[1]) == expected:
			return true
	return false
