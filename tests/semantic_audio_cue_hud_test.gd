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
	hud.set_reduced_motion(true)
	hud.bind_caption_event_submitter(Callable(self, &"_capture_request"))
	var position := Vector3(2.0, 1.0, -4.0)
	_check(
		hud.present_semantic_audio_cue(&"combat_alert", &"ship_audio", 1.0, position),
		"semantic cue submits through caption ingress"
	)
	_check(_requests.size() == 1, "exactly one caption request is emitted")
	_check(str(_requests[0].get("text", "")).begins_with("! Combat alert"), "caption includes shape-safe severity")
	_check(hud.is_reduced_motion(), "existing reduced-motion policy remains enabled")
	_check(
		not hud.present_semantic_audio_cue(&"combat_alert", &"ship_audio", 1.0, position),
		"duplicate semantic cue is suppressed"
	)
	hud.set_captions_enabled(false)
	_check(
		not hud.present_semantic_audio_cue(&"target_destroyed", &"range", 0.5, position),
		"caption toggle suppresses semantic cue"
	)
	hud.free()
	if _failures.is_empty():
		print("SEMANTIC_AUDIO_CUE_HUD_TEST_OK (%d assertions)" % _assertions)
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
