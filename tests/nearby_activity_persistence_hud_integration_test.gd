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
	(hud.find_child("NearbyActivitySaveButton", true, false) as Button).pressed.emit()
	_check(_intents.size() == 1 and _intents[0].reason == &"save_requested", "Save Progress forwards caller-owned intent")
	hud.apply_nearby_activity_persistence_result({"accepted": true, "status": &"saved"})
	_check((hud.get("_nearby_activity_feedback") as Label).text == "Progress saved.", "saved receipt is rendered in the nearby activity page")
	(hud.find_child("NearbyActivityLoadButton", true, false) as Button).pressed.emit()
	_check(_intents.size() == 2 and _intents[1].reason == &"load_requested", "Load Progress forwards caller-owned intent")
	hud.apply_nearby_activity_persistence_result({"accepted": false, "reason": &"newer_schema"})
	_check((hud.get("_nearby_activity_feedback") as Label).text.contains("newer version"), "newer-schema feedback remains readable")
	var save := hud.find_child("NearbyActivitySaveButton", true, false) as Button
	var load := hud.find_child("NearbyActivityLoadButton", true, false) as Button
	hud.set_nearby_activity_snapshot({"binding_available": false})
	_check(save.disabled and load.disabled, "out-of-range Cinder keeps its ordinary persistence unavailable")
	var context := {"world_id": &"ember_moon", "host_instance_id": 17,
		"host_generation": 3, "attachment_generation": 4, "player_instance_id": 23}
	hud.set_nearby_activity_snapshot({"binding_available": false, "ember_save_context": context})
	_check(not save.disabled and load.disabled, "current Ember context enables only ordinary Save outside Cinder range")
	_check(not (hud.get("_nearby_activity_feedback") as Label).text.contains("OUT OF STREAMING RANGE"),
		"Ember save context replaces Cinder's unavailable-save feedback")
	save.pressed.emit()
	_check(_intents.size() == 3 and _intents[2].get("ember_save_context", {}) == context,
		"actual Save button forwards the exact caller-owned Ember context")
	hud.set_nearby_activity_snapshot({"binding_available": false})
	_check(save.disabled and load.disabled, "retiring Ember context disables Save again")
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
