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
	_check(hud.present_semantic_audio_cue(&"boost_engaged", &"flight", 0.6, Vector3.ZERO), "boost-engaged cue reaches captions")
	_check(hud.present_semantic_audio_cue(&"boost_released", &"flight", 0.2, Vector3.ZERO), "boost-released cue reaches captions")
	_check(_requests.size() == 2, "both boost states produce requests")
	_check(str(_requests[0].text).contains("Boost engaged"), "engaged state is concise")
	_check(str(_requests[1].text).contains("Boost released"), "released state is concise")
	_check(str(_requests[0].text).begins_with("△"), "engaged state uses shape-safe marker")
	hud.set_captions_enabled(false)
	_check(not hud.present_semantic_audio_cue(&"boost_released", &"flight", 0.2, Vector3.ZERO), "caption preference gates boost state")
	hud.queue_free()
	await process_frame
	if _failures.is_empty():
		print("BOOST_STATE_CUES_HUD_TEST_OK (%d assertions)" % _assertions)
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
