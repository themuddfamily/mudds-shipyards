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
	_check(hud.present_semantic_audio_cue(&"boarding_confirmed", &"boarding", 0.3, Vector3.ZERO), "boarding cue reaches captions")
	_check(hud.present_semantic_audio_cue(&"disembark_confirmed", &"boarding", 0.3, Vector3.ZERO), "disembark cue reaches captions")
	_check(_requests.size() == 2, "both confirmation cues produce requests")
	_check(str(_requests[0].text).contains("Boarding confirmed"), "boarding label is concise")
	_check(str(_requests[1].text).contains("Disembark confirmed"), "disembark label is concise")
	hud.set_captions_enabled(false)
	_check(not hud.present_semantic_audio_cue(&"boarding_confirmed", &"boarding", 0.3, Vector3.ZERO), "caption preference gates confirmations")
	hud.queue_free()
	await process_frame
	if _failures.is_empty():
		print("BOARDING_CONFIRMATION_CUES_HUD_TEST_OK (%d assertions)" % _assertions)
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
