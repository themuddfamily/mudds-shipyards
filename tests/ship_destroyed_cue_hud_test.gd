extends SceneTree

const HudType := preload("res://scripts/ui/hud.gd")

var _assertions := 0
var _failures: PackedStringArray = []
var _requests: Array[Dictionary] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var hud := HudType.new()
	root.add_child(hud)
	await process_frame
	hud.set_captions_enabled(true)
	hud.bind_caption_event_submitter(Callable(self, &"_capture_request"))
	_check(hud.present_semantic_audio_cue(&"ship_destroyed", &"damage_control", 1.0, Vector3.ZERO), "destruction cue reaches captions")
	_check(_requests.size() == 1, "destruction cue produces one caption request")
	_check(str(_requests[0].text).contains("Ship destroyed"), "destruction message is concise and textual")
	_check(str(_requests[0].text).begins_with("!"), "destruction message has a shape-safe severity marker")
	hud.set_captions_enabled(false)
	_check(not hud.present_semantic_audio_cue(&"ship_destroyed", &"damage_control", 1.0, Vector3.ZERO), "caption preference gates destruction cue")
	hud.queue_free()
	await process_frame
	if _failures.is_empty():
		print("SHIP_DESTROYED_CUE_HUD_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _capture_request(request: Dictionary) -> bool:
	_requests.append(request.duplicate(true))
	return true


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append("FAIL: " + message)
