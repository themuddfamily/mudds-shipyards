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
	_check(hud.present_semantic_audio_cue(&"station_service_servo", &"maintenance", 0.2, Vector3.ZERO), "servo cue reaches captions")
	_check(hud.present_semantic_audio_cue(&"station_service_latch", &"maintenance", 0.5, Vector3.ZERO), "latch cue reaches captions")
	_check(_requests.size() == 2, "both station-service cues produce requests")
	_check(str(_requests[0].text).contains("Station service servo"), "servo label is concise")
	_check(str(_requests[1].text).contains("Station service latch"), "latch label is concise")
	hud.set_captions_enabled(false)
	_check(not hud.present_semantic_audio_cue(&"station_service_latch", &"maintenance", 0.5, Vector3.ZERO), "caption preference gates maintenance cue")
	hud.queue_free()
	await process_frame
	if _failures.is_empty():
		print("STATION_SERVICE_CUES_HUD_TEST_OK (%d assertions)" % _assertions)
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
