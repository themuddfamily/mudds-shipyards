extends SceneTree

const Presenter := preload("res://scripts/ui/nearby_sector_activity_presenter.gd")

var _assertions := 0
var _failures: Array[String] = []


func _initialize() -> void:
	var presenter := Presenter.new()
	var view := presenter.present({
		"host": {"activity": {"state_id": "active"}},
		"race": {"state_id": "completed"},
		"mining": {"state": 2, "elapsed_seconds": 6.0, "extraction_seconds": 6.0, "reward_requested": true},
		"beacon_traversal": {"state": 1, "next_beacon_index": 1, "beacon_count": 4, "reason": "out_of_order_beacon"},
		"cargo": {"state": 3, "next_phase_index": 1, "phase_count": 3, "deadline_remaining_seconds": 0.0, "failure_reason": "deadline_expired"},
	})
	_check(view.get("focusable", false), "the presenter exposes controller-focusable cards")
	_check(view.get("color_independent", false), "the presenter publishes text that does not depend on color")
	_check((view.get("cards", []) as Array).size() == 7, "the presenter renders all integrated activity slots")
	var mining_card := (view.get("cards", []) as Array)[2] as Dictionary
	_check("COMPLETED" in str(mining_card.get("text", "")) and bool(mining_card.get("reward_pending", false)), "completed mining text includes state and pending reward")
	var cargo_card := (view.get("cards", []) as Array)[5] as Dictionary
	_check("FAILED" in str(cargo_card.get("text", "")) and "RECOVER: DEADLINE EXPIRED" in str(cargo_card.get("text", "")), "cargo failure exposes state and recovery reason")
	_check("PHASE 1/3" in str(cargo_card.get("text", "")), "cargo snapshot exposes ordered phase progress")
	var beacon_card := (view.get("cards", []) as Array)[4] as Dictionary
	_check("WRONG ORDER" in str(beacon_card.get("text", "")) and "RECOVER: FOLLOW BEACON ORDER" in str(beacon_card.get("text", "")), "beacon rejection exposes order-safe recovery")
	_check("NEXT BEACON 2/4" in str(beacon_card.get("text", "")), "beacon snapshot exposes next target")
	var selected := presenter.select(&"cinder_debris_beacon_traversal")
	_check(bool(selected.get("accepted", false)), "known activity selection is accepted")
	var intent := presenter.start_intent()
	_check(bool(intent.get("accepted", false)) and not bool(intent.get("authority", true)), "start returns a non-authoritative intent")
	var rejected := presenter.select(&"unknown")
	_check(not bool(rejected.get("accepted", true)), "unknown activity selection is rejected")
	if _failures.is_empty():
		print("PASS nearby_sector_activity_presenter_test (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
