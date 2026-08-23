extends SceneTree

const HudType := preload("res://scripts/ui/hud.gd")

var _assertions := 0
var _failures: PackedStringArray = []
var _intents: Array[Dictionary] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var hud := HudType.new()
	root.add_child(hud)
	await process_frame
	hud.nearby_activity_intent_requested.connect(_on_intent)
	hud.set_nearby_activity_snapshot({"race": {"state_id": &"active"}})
	hud.show_nearby_activity_page()
	hud._forward_nearby_activity_intent(&"save", &"")
	_check(_intents.size() == 1 and _intents[0].reason == &"save_requested", "Save Progress forwards caller-owned intent")
	hud.apply_nearby_activity_persistence_result({"accepted": true, "status": &"saved"})
	_check((hud.get("_nearby_activity_feedback") as Label).text == "Progress saved.", "saved receipt is rendered in the nearby activity page")
	hud._forward_nearby_activity_intent(&"load", &"")
	_check(_intents.size() == 2 and _intents[1].reason == &"load_requested", "Load Progress forwards caller-owned intent")
	hud.apply_nearby_activity_persistence_result({"accepted": false, "reason": &"newer_schema"})
	_check((hud.get("_nearby_activity_feedback") as Label).text.contains("newer version"), "newer-schema feedback remains readable")
	hud.queue_free()
	await process_frame
	if _failures.is_empty():
		print("NEARBY_ACTIVITY_PERSISTENCE_HUD_INTEGRATION_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _on_intent(intent: Dictionary) -> void:
	_intents.append(intent.duplicate(true))


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)
