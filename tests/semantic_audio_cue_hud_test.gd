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
	hud.set_reduced_motion(true)
	hud.bind_caption_event_submitter(Callable(self, &"_capture_request"))
	var position := Vector3(2.0, 1.0, -4.0)
	_check(
		hud.present_semantic_audio_cue(&"combat_alert", &"ship_audio", 1.0, position, {"tick": 10}),
		"semantic cue submits through caption ingress"
	)
	_check(_requests.size() == 1, "exactly one caption request is emitted")
	_check(str(_requests[0].get("text", "")).begins_with("! Combat alert"), "caption includes shape-safe severity")
	var transcript := hud._semantic_audio_cue_presenter.get_transcript(12)
	_check(transcript.size() == 1 and int(transcript[0].get("age_ticks", -1)) == 2, "transcript retains redacted cue metadata and relative age")
	_check(hud.is_reduced_motion(), "existing reduced-motion policy remains enabled")
	_check(
		not hud.present_semantic_audio_cue(&"combat_alert", &"ship_audio", 1.0, position),
		"duplicate semantic cue is suppressed"
	)
	for index in range(10):
		hud.present_semantic_audio_cue(&"target_destroyed", StringName("range_%d" % index), 0.5, position, {"tick": 20 + index})
	transcript = hud._semantic_audio_cue_presenter.get_transcript(30)
	_check(transcript.size() == 8, "transcript is bounded to eight entries")
	hud.toggle_semantic_caption_transcript()
	_check(bool(hud._semantic_transcript_panel.visible), "caption transcript opens through a focusable HUD control")
	hud.clear_semantic_caption_transcript()
	_check(hud._semantic_audio_cue_presenter.get_transcript().is_empty(), "transcript clears on explicit session reset")
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
