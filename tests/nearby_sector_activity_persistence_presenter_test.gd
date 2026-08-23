extends SceneTree

const Presenter := preload("res://scripts/ui/nearby_sector_activity_presenter.gd")

var _assertions := 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var presenter := Presenter.new()
	presenter.present({"race": {"state_id": &"active"}})
	var view := presenter.present_persistence_result({"accepted": true, "status": &"saved"})
	_check((view.actions as Array).size() == 2, "save and load actions are exposed")
	_check((view.actions as Array)[0].focusable and (view.actions as Array)[1].focusable, "persistence actions are controller-focusable")
	_check(view.persistence_feedback.status == &"saved" and view.persistence_feedback.text == "Progress saved.", "saved receipt is readable")
	_check(presenter.save_progress_intent().reason == &"save_requested" and not presenter.save_progress_intent().authority, "save emits a caller-owned intent")
	_check(presenter.load_progress_intent().reason == &"load_requested", "load emits a caller-owned intent")
	_check(presenter.present_persistence_result({"accepted": true, "status": &"restored"}).persistence_feedback.status == &"restored", "restored receipt is readable")
	_check(presenter.present_persistence_result({"accepted": false, "reason": &"invalid_payload"}).persistence_feedback.status == &"invalid", "invalid receipt is explicit")
	_check(presenter.present_persistence_result({"accepted": false, "reason": &"newer_schema"}).persistence_feedback.status == &"newer_schema", "newer-schema receipt is explicit")
	_check(presenter.present_persistence_result({"accepted": false, "reason": &"failed_write"}).persistence_feedback.status == &"failed_write", "failed-write receipt is explicit")
	_check(not bool(view.get("activity_authority", true)) and not bool(view.get("reward_authority", true)), "persistence view remains non-authoritative")
	if _failures.is_empty():
		print("NEARBY_SECTOR_ACTIVITY_PERSISTENCE_PRESENTER_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)
