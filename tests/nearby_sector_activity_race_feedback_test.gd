extends SceneTree

const Presenter := preload("res://scripts/ui/nearby_sector_activity_presenter.gd")

var _assertions := 0
var _failures: Array[String] = []


func _initialize() -> void:
	var presenter := Presenter.new()
	var view := presenter.present({
		"race": {
			"state_id": &"countdown",
			"countdown_in_progress": true,
			"countdown_remaining_seconds": 2.5,
			"lap_number": 1,
			"lap_count": 2,
			"next_checkpoint_index": 0,
			"checkpoint_count": 5,
			"presentation_reason": &"outside_checkpoint",
		},
	})
	var card := _race_card(view)
	var feedback := card.get("race_feedback", {}) as Dictionary
	_check(
		StringName(card.get("state_id", &"")) == &"countdown"
			and StringName(feedback.get("stage_id", &"")) == &"countdown",
		"a pre-start gate attempt remains a countdown instead of looking like a missed gate"
	)
	_check(
		"HOLD POSITION" in str(card.get("text", ""))
			and "START IN 2.5s" in str(card.get("text", ""))
			and "HOLD POSITION" in str(card.get("objective_text", "")),
		"countdown feedback gives a color-independent hold and start instruction"
	)
	_check(bool(feedback.get("countdown_in_progress", false)), "race feedback retains the session countdown state")
	if _failures.is_empty():
		print("NEARBY_SECTOR_ACTIVITY_RACE_FEEDBACK_TEST_OK (%d assertions)" % _assertions)
		quit(0)
	for failure in _failures:
		push_error(failure)
	quit(1)


func _race_card(view: Dictionary) -> Dictionary:
	for card_value in view.get("cards", []) as Array:
		var card := card_value as Dictionary
		if StringName(card.get("activity_id", &"")) == &"cinder_reach_checkpoint_route":
			return card
	return {}


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
