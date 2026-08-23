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
	_check((hud.get("_runtime_status_detail") as Label).text.contains("[READY]") and (hud.get("_runtime_status_actions") as HBoxContainer).get_child_count() == 1, "ready state is readable with a glyph action")
	var release := hud.request_bomber_payload_release()
	_check(bool(release.accepted) and _intents.size() == 1 and _intents[0].kind == &"bomber", "release emits a caller-owned presentation intent")
	hud.apply_bomber_payload_snapshot({"generation": 2, "active": true, "ammo": 1, "cooldown_remaining": 1.5, "action_glyph": "Cross", "reduced_motion": true})
	await process_frame
	_check((hud.get("_runtime_status_detail") as Label).text.contains("[WAIT]") and (hud.get("_runtime_status_actions") as HBoxContainer).get_child_count() == 0, "cooldown state removes release action")
	hud.apply_bomber_payload_snapshot({"generation": 3, "active": true, "ammo": 0, "cooldown_remaining": 0.0, "denied_reason": "hardpoint_locked"})
	await process_frame
	_check((hud.get("_runtime_status_detail") as Label).text.contains("[DENIED]"), "denied state is explicit and color-independent")
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
