extends SceneTree

const PresenterType := preload("res://scripts/ui/semantic_audio_cue_presenter.gd")

var _assertions := 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var presenter := PresenterType.new()
	var position := Vector3(4.0, 2.0, -8.0)
	var accepted := presenter.present_cue(&"hull_impact_heavy", &"defender", 0.9, position)
	_check(bool(accepted.get("accepted", false)), "registered cue is accepted")
	_check(accepted.get("caption") == "Heavy hull impact", "cue maps to concise caption")
	_check(accepted.get("severity_marker") == "!", "severity has a non-colour shape marker")
	_check(accepted.get("world_position") == position, "world position is preserved for caller layout")
	var duplicate := presenter.present_cue(&"hull_impact_heavy", &"defender", 0.9, position)
	_check(duplicate.get("reason") == &"duplicate_cue", "identical cue is deduplicated")
	var unknown := presenter.present_cue(&"untrusted_cue", &"defender", 1.0, position)
	_check(unknown.get("reason") == &"unregistered_cue", "unregistered cue is rejected")
	if _failures.is_empty():
		print("SEMANTIC_AUDIO_CUE_PRESENTER_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append("FAIL: " + message)
