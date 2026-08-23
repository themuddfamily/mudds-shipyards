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
	var position := Vector3(1.0, 0.0, 2.0)
	_check(hud.present_semantic_audio_cue(&"engine_damage_alarm", &"engine", 1.0, position), "damage alarm reaches caption path")
	_check(hud.present_semantic_audio_cue(&"engine_damage_alarm_cleared", &"engine", 0.2, position), "cleared alarm reaches caption path")
	_check(hud.present_semantic_audio_cue(&"ship_landing_contact", &"landing", 0.6, position), "landing contact reaches caption path")
	_check(_requests.size() == 3, "registered cues produce exactly three caption requests")
	_check(str(_requests[0].text).contains("Engine damage alarm"), "alarm caption is concise and readable")
	_check(str(_requests[2].text).contains("Landing contact"), "landing caption is concise and readable")
	hud.set_captions_enabled(false)
	_check(not hud.present_semantic_audio_cue(&"engine_damage_alarm", &"engine", 1.0, position), "caption preference still gates new cues")
	hud.queue_free()
	await process_frame
	if _failures.is_empty():
		print("SEMANTIC_AUDIO_NEW_CUES_HUD_TEST_OK (%d assertions)" % _assertions)
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
