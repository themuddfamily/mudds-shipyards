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
	hud.presentation_intent_requested.connect(_on_intent)
	_check(hud.apply_first_sortie_tutorial_snapshot({"step_id": &"board", "input_family": &"controller", "glyphs": {&"interact": "X"}}), "HUD accepts tutorial snapshot")
	var title := hud.get("_runtime_status_title") as Label
	var detail := hud.get("_runtime_status_detail") as Label
	_check(title.text == "Board" and detail.text.contains("X"), "HUD renders controller-readable tutorial prompt")
	var dismiss := hud.request_first_sortie_tutorial_action(&"dismiss")
	_check(dismiss.accepted, "dismiss action is accepted through HUD seam")
	_check(_intents.size() == 1 and _intents[0].kind == &"tutorial", "tutorial action forwards presentation intent")
	_check(_intents[0].payload.completion_intent.persist, "completion intent remains caller-owned")
	var invalid := hud.apply_first_sortie_tutorial_snapshot({"step_id": &"unknown"})
	_check(not invalid, "invalid tutorial snapshot is rejected")
	hud.queue_free()
	await process_frame
	if _failures.is_empty():
		print("FIRST_SORTIE_TUTORIAL_HUD_INTEGRATION_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _on_intent(kind: StringName, payload: Dictionary) -> void:
	_intents.append({"kind": kind, "payload": payload})


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append("FAIL: " + message)
