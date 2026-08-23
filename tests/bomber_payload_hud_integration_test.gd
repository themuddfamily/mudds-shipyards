extends SceneTree

const HudType := preload("res://scripts/ui/hud.gd")
var _assertions := 0
var _failures: PackedStringArray = []
var _intents: Array[Dictionary] = []

func _init() -> void:
	call_deferred(&"_run")

func _run() -> void:
	var hud := HudType.new()
	hud.presentation_intent_requested.connect(_on_intent)
	root.add_child(hud)
	await process_frame
	_check(hud.apply_bomber_payload_snapshot({"generation": 1, "active": true, "ammo": 2, "cooldown_remaining": 0.0, "action_glyph": "A"}), "ready bomber snapshot renders")
	var panel := hud.get("_runtime_status_panel") as PanelContainer
	_check(panel.visible and (hud.get("_runtime_status_title") as Label).text == "BOMBER PAYLOAD", "bomber status uses the retained runtime panel")
	var action_button := (hud.get("_runtime_status_actions") as HBoxContainer).get_child(0) as Button
	var ready_detail := (hud.get("_runtime_status_detail") as Label).text
	_check(ready_detail.contains("[READY]") and ready_detail.contains("PAYLOADS REMAINING // 2") and action_button.text.contains("RELEASE PAYLOAD") and action_button.focus_mode == Control.FOCUS_ALL, "ready state shows remaining payloads with a mapped glyph action")
	var release := hud.request_bomber_payload_release()
	_check(bool(release.accepted) and _intents.size() == 1 and _intents[0].kind == &"bomber", "release emits a caller-owned presentation intent")
	action_button.pressed.emit()
	_check(_intents.size() == 2 and _intents[1].kind == &"bomber", "focused action row routes through the same release intent")
	hud.apply_bomber_payload_snapshot({"generation": 2, "active": true, "ammo": 1, "cooldown_remaining": 1.5, "action_glyph": "Cross", "reduced_motion": true})
	await process_frame
	var cooldown_detail := (hud.get("_runtime_status_detail") as Label).text
	_check(cooldown_detail.contains("[WAIT]") and cooldown_detail.contains("PAYLOADS REMAINING // 1") and cooldown_detail.contains("COOLDOWN // 1.5 S") and (hud.get("_runtime_status_actions") as HBoxContainer).get_child_count() == 0, "cooldown state shows remaining payloads and seconds")
	hud.apply_bomber_payload_snapshot({"generation": 3, "active": true, "ammo": 0, "cooldown_remaining": 0.0, "denied_reason": "hardpoint_locked"})
	await process_frame
	var denied_detail := (hud.get("_runtime_status_detail") as Label).text
	_check(denied_detail.contains("[DENIED]") and denied_detail.contains("UNAVAILABLE // HARDPOINT_LOCKED"), "denied state shows an explicit unavailable reason")
	hud.clear_bomber_payload_status()
	_check(not panel.visible, "detach clears bomber presentation")
	hud.queue_free()
	await process_frame
	if _failures.is_empty():
		print("BOMBER_PAYLOAD_HUD_INTEGRATION_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)

func _on_intent(kind: StringName, payload: Dictionary) -> void:
	_intents.append({"kind": kind, "payload": payload.duplicate(true)})

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)
