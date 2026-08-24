extends SceneTree

const HUD_SCENE := preload("res://scenes/ui/hud.tscn")
const ActivityBindingType := preload("res://scripts/world/nearby_sector_activity_binding.gd")

var _assertions := 0
var _failures: Array[String] = []


func _initialize() -> void:
	_check(
		is_equal_approx(ActivityBindingType.CINDER_RACE_COUNTDOWN_SECONDS, 3.0),
		"the production Cinder race retains a readable three-second authority countdown",
	)
	var hud := HUD_SCENE.instantiate() as GameHUD
	root.add_child(hud)
	await process_frame

	var view := hud.set_nearby_activity_snapshot({"race": _race(&"countdown", 0, 2.4)})
	var row := _race_row(hud)
	var retained_id := row.get_instance_id() if row != null else 0
	_check(
		_race_text(row).contains("COUNTDOWN  //  START IN 2.4s  //  LAP 1/2")
		and str(_race_card(view).get("objective_text", "")) == "HOLD FOR THE START SIGNAL",
		"countdown state is readable before the first gate opens",
	)

	view = hud.set_nearby_activity_snapshot({"race": _race(&"active", 1, 0.0)})
	row = _race_row(hud)
	var feedback := _race_card(view).get("race_feedback", {}) as Dictionary
	_check(
		row != null and row.get_instance_id() == retained_id
		and _race_text(row).contains("LAP 1/2  //  CHECKPOINT 2/4  //  12.5s")
		and int(feedback.get("next_checkpoint_index", -1)) == 1,
		"lap, next checkpoint, and clock update on the same retained row",
	)

	var missed := _race(&"active", 1, 0.0)
	missed.presentation_reason = &"outside_checkpoint"
	view = hud.set_nearby_activity_snapshot({"race": missed})
	_check(
		_race_text(_race_row(hud)).contains("MISSED GATE  //  FLY THROUGH CHECKPOINT 2/4")
		and StringName((_race_card(view).race_feedback as Dictionary).stage_id) == &"missed_gate"
		and str(_race_card(view).get("objective_text", "")).contains("RETURN TO THE MARKED CHECKPOINT"),
		"the retained binding rejection becomes actionable missed-gate feedback",
	)

	var timeout := _race(&"failed", 2, 0.0)
	timeout.failure_reason = &"timeout"
	view = hud.set_nearby_activity_snapshot({"race": timeout})
	_check(
		_race_text(_race_row(hud)).contains("FAILED  //  TIMEOUT  //  RACE ENDED")
		and StringName((_race_card(view).race_feedback as Dictionary).stage_id) == &"timeout",
		"authority timeout is distinct from a generic race failure",
	)

	var complete := _race(&"completed", 4, 0.0)
	complete.last_time_seconds = 38.75
	view = hud.set_nearby_activity_snapshot({"race": complete})
	_check(
		_race_text(_race_row(hud)).contains("COMPLETED  //  FINISH 38.75s  //  TIME RECORDED"),
		"completion retains the authoritative finish time",
	)

	complete.reward_pending = true
	view = hud.set_nearby_activity_snapshot({"race": complete})
	var pending_text := _race_text(_race_row(hud))
	feedback = _race_card(view).get("race_feedback", {}) as Dictionary
	_check(
		pending_text.contains("FINISH 38.75s  //  REWARD PENDING")
		and pending_text.count("REWARD PENDING") == 1
		and bool(_race_card(view).get("reward_pending", false))
		and bool(feedback.get("reward_pending", false))
		and not bool(feedback.get("race_authority", true))
		and not bool(feedback.get("reward_authority", true)),
		"reward pending is readable once without adding race or grant authority",
	)

	var new_best := _race(&"completed", 4, 0.0)
	new_best.last_time_seconds = 34.5
	new_best.best_time_seconds = 34.5
	new_best.best_result_persisted = true
	view = hud.set_nearby_activity_snapshot({"race": new_best})
	feedback = _race_card(view).get("race_feedback", {}) as Dictionary
	_check(
		_race_text(_race_row(hud)).contains("FINISH 34.50s  //  NEW BEST SAVED")
			and StringName(feedback.get("completion_status_id", &"")) == &"new_best_saved"
			and str(_race_card(view).get("objective_text", "")) == "START A NEW RUN TO IMPROVE THE SAVED BEST",
		"a persisted completion that matches the saved best announces the new record and next run",
	)

	var slower := _race(&"completed", 4, 0.0)
	slower.last_time_seconds = 38.75
	slower.best_time_seconds = 34.5
	slower.best_result_persisted = true
	view = hud.set_nearby_activity_snapshot({"race": slower})
	feedback = _race_card(view).get("race_feedback", {}) as Dictionary
	_check(
		_race_text(_race_row(hud)).contains("FINISH 38.75s  //  SAVED BEST 34.50s  //  NO NEW BEST")
			and StringName(feedback.get("completion_status_id", &"")) == &"slower_than_saved_best"
			and str(_race_card(view).get("objective_text", "")) == "START A NEW RUN TO BEAT THE SAVED BEST",
		"a slower completed run names the retained record and a controller-readable next action",
	)

	hud.queue_free()
	await process_frame
	for failure in _failures:
		push_error(failure)
	print("CINDER_RACE_RETAINED_FEEDBACK_TEST_OK: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _race(state_id: StringName, next_checkpoint: int, countdown: float) -> Dictionary:
	return {
		"activity_id": &"cinder_reach_checkpoint_route",
		"state_id": state_id,
		"session_generation": 4,
		"lap_number": 1,
		"lap_count": 2,
		"next_checkpoint_index": next_checkpoint,
		"checkpoint_count": 4,
		"countdown_remaining_seconds": countdown,
		"current_time_seconds": 12.5,
		"last_time_seconds": -1.0,
		"best_time_seconds": -1.0,
		"best_result_persisted": false,
		"failure_reason": &"",
		"reward_pending": false,
	}.duplicate(true)


func _race_card(view: Dictionary) -> Dictionary:
	for candidate in view.get("cards", []) as Array:
		var card := candidate as Dictionary
		if StringName(card.get("activity_id", &"")) == &"cinder_reach_checkpoint_route":
			return card
	return {}


func _race_row(hud: GameHUD) -> Control:
	var rows := hud.get("_nearby_activity_rows") as VBoxContainer
	for candidate in rows.get_children() if rows != null else []:
		if "cinder_reach_checkpoint_route" in str(candidate.name):
			return candidate as Control
	return null


func _race_text(row: Control) -> String:
	return str((row.get_child(0) as Label).text) if row != null else ""


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		return
	_failures.append(message)
