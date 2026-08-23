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
	hud.set_accessibility({"reduced_flash": true, "payload_visual_intensity": 0})
	hud.apply_bomber_payload_snapshot({
		"generation": 1,
		"active": true,
		"ammo": 2,
		"cooldown_remaining": 1.5,
		"action_id": "fire",
	})
	var button := hud.get("_bomber_payload_help_button") as Button
	_check(button != null and button.visible and button.focus_mode == Control.FOCUS_ALL, "payload tutorial row is controller-focusable")
	_check(button != null and button.text.contains("PAYLOAD") and button.text.contains("COOLDOWN"), "payload row shows readiness and remapped action context")
	_check(button != null and button.tooltip_text.contains("Remaining: 2") and button.tooltip_text.contains("Cooldown: 1.5 seconds"), "payload row explains remaining and cooldown semantics")
	_check(button != null and button.tooltip_text.contains("Reduced flash: ON") and button.tooltip_text.contains("Visual intensity: LOW"), "payload row explains active accessibility profile")
	hud.apply_bomber_payload_snapshot({"generation": 2, "active": true, "ammo": 0, "cooldown_remaining": 0.0, "denied_reason": "hardpoint_locked"})
	_check(button != null and button.tooltip_text.contains("Unavailable: hardpoint_locked"), "payload row explains unavailable reason")
	hud.clear_bomber_payload_status()
	_check(button != null and not button.visible, "payload row clears on detach")
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
