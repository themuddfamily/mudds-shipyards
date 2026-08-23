extends SceneTree

const HudType := preload("res://scripts/ui/hud.gd")

var _assertions := 0
var _failures: PackedStringArray = []
var _requests: Array[Dictionary] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var hud := HudType.new()
	hud.set_captions_enabled(true)
	hud.bind_caption_event_submitter(Callable(self, &"_capture_request"))
	var cues := [&"activity_selected", &"activity_started", &"activity_checkpoint", &"activity_progress", &"activity_complete", &"activity_reward_pending", &"activity_reset"]
	for cue in cues:
		_check(hud.caption_activity_cue(cue, "Beacon Race"), "%s reaches the caption ingress" % cue)
	_check(_requests.size() == cues.size(), "each activity cue produces one caption request")
	_check(str(_requests[0].text) == "[ Beacon Race selected ]", "activity label is rendered in concise textual form")
	_check(str(_requests[4].text) == "[ Beacon Race complete ]", "completion remains color-independent text")
	hud.set_captions_enabled(false)
	_check(not hud.caption_activity_cue(&"activity_started", "Beacon Race"), "caption preference gates activity cues")
	hud.free()
	if _failures.is_empty():
		print("ACTIVITY_CUE_HUD_TEST_OK (%d assertions)" % _assertions)
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
	if not condition:
		_failures.append("FAIL: " + message)
