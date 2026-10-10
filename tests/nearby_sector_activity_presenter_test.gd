extends SceneTree

const Presenter := preload("res://scripts/ui/nearby_sector_activity_presenter.gd")

var _assertions := 0
var _failures: Array[String] = []


func _initialize() -> void:
	var presenter := Presenter.new()
	var view := presenter.present({
		"host": {"activity": {"state_id": "active"}},
		"race": {"state_id": "completed"},
		"mining": {"state": 2, "elapsed_seconds": 6.0, "extraction_seconds": 6.0, "reward_requested": true, "reason": "completed"},
		"structure_scan": {"state": 1, "elapsed_seconds": 1.0, "scan_seconds": 4.0, "reason": "outside_scan_approach"},
		"beacon_traversal": {"state": 1, "next_beacon_index": 1, "beacon_count": 4, "reason": "out_of_order_beacon"},
		"cargo": {"state": CargoDeliveryActivity.State.EXPIRED, "next_phase_index": 1, "phase_count": 3, "deadline_remaining_seconds": 0.0, "failure_reason": "deadline_expired", "contract": {"ordered_phases": [&"load_crate", &"clear_gate", &"dock_platform"]}},
	})
	_check(view.get("focusable", false), "the presenter exposes controller-focusable cards")
	_check(view.get("color_independent", false), "the presenter publishes text that does not depend on color")
	var activity_ids: Array[String] = []
	for card: Dictionary in view.get("cards", []):
		activity_ids.append(str(card.get("activity_id", &"")))
	activity_ids.sort()
	_check(activity_ids == [
		"cinder_asteroid_field_threading_run",
		"cinder_debris_beacon_traversal", "cinder_derelict_structure_scan",
		"cinder_hulk_power_restoration",
		"cinder_platform_mining_run", "cinder_platform_supply_run",
		"cinder_reach_checkpoint_route", "cinder_reach_emberline_convoy",
		"cinder_relay_patrol", "station_defense",
	], "the presenter renders each integrated activity once regardless of priority order")
	var asteroid_id: StringName = &"cinder_asteroid_field_threading_run"
	var idle_asteroid := _card(presenter.present({"asteroid_field_run": {
		"state_id": &"idle", "generation": 0,
	}}), asteroid_id)
	_check(idle_asteroid.title == "ASTEROID THREADING RUN"
		and "FIRST BELT GATE" in str(idle_asteroid.text)
		and bool(idle_asteroid.actions_enabled),
		"the real asteroid snapshot supplies an ordinary discoverable Start and Reset card")
	var active_asteroid := _card(presenter.present({"asteroid_field_run": {
		"state_id": &"active", "generation": 3,
		"next_checkpoint_index": 2, "checkpoint_count": 5,
	}}), asteroid_id)
	_check(active_asteroid.state_id == &"active" and "NEXT GATE 3/5" in str(active_asteroid.text),
		"the asteroid card follows the binding's actual ordered gate cursor")
	var reset_asteroid := presenter.reset_intent(asteroid_id)
	_check(not bool(reset_asteroid.accepted)
		and reset_asteroid.get("reason") == &"reset_confirmation_requested"
		and not bool(reset_asteroid.get("authority", true))
		and bool(presenter.reset_intent(asteroid_id).accepted),
		"active asteroid Reset uses the existing current-generation confirmation and non-authoritative intent")
	# The binding snapshot flag means acknowledged payment, unlike the durable
	# envelope's genuine-terminal reward_requested flag.
	var unpaid_asteroid := _card(presenter.present({"asteroid_field_run": {
		"state_id": &"completed", "generation": 3, "reward_requested": false,
	}}), asteroid_id)
	_check(bool(unpaid_asteroid.reward_pending) and "START TO RETRY REWARD SAVE" in str(unpaid_asteroid.text)
		and bool(presenter.start_intent(asteroid_id).accepted),
		"genuinely completed unpaid asteroid progress exposes ordinary Start to retry")
	var paid_asteroid := _card(presenter.present({"asteroid_field_run": {
		"state_id": &"completed", "generation": 3, "reward_requested": true,
	}}), asteroid_id)
	_check(not bool(paid_asteroid.reward_pending) and "SURVEY RECEIPT SAVED" in str(paid_asteroid.text)
		and not bool(paid_asteroid.reward_authority),
		"the acknowledged asteroid receipt is complete without duplicate reward authority")
	var unavailable_asteroid := _card(presenter.present({"binding_available": false}), asteroid_id)
	_check(not bool(unavailable_asteroid.actions_enabled)
		and "FLY TOWARD CINDER REACH" in str(unavailable_asteroid.text),
		"the asteroid card keeps existing unloaded-sector admission guidance")
	var hulk_id: StringName = &"cinder_hulk_power_restoration"
	var away_hulk := _card(view, hulk_id)
	_check(away_hulk.get("state_id") == &"unavailable"
		and "FLY TOWARD CINDER REACH" in str(away_hulk.get("text", ""))
		and "DESTINATION BOARD" in str(away_hulk.get("text", "")),
		"the unloaded hulk row guides the pilot into sensor range")
	var dock_position := Vector3(-135.0, 24.0, -470.0)
	var loaded_hulk := _card(presenter.present({"binding_available": true,
		"hulk_power": {"state_id": &"idle", "hulk_loaded": true,
			"dock_position": dock_position}}), hulk_id)
	_check(loaded_hulk.get("state_id") == &"available"
		and loaded_hulk.get("dock_position") == dock_position
		and "HULK DOCK MINIMAP MARK" in str(loaded_hulk.get("text", ""))
		and "THROW THE BREAKER" in str(loaded_hulk.get("text", "")),
		"the loaded row points at the real dock and the on-foot breaker")
	var restoring_hulk := _card(presenter.present({"hulk_power": {
		"state_id": &"active", "hulk_loaded": true,
	}}), hulk_id)
	_check(restoring_hulk.get("state_id") == &"active"
		and "HOLD THE REACTOR GALLERY" in str(restoring_hulk.get("text", "")),
		"the board follows the breaker while power is restoring")
	var claimed_hulk := _card(presenter.present({"binding_available": false,
		"hulk_power": {"state_id": &"claimed", "reward_claimed": true,
			"hulk_loaded": false}}), hulk_id)
	_check(claimed_hulk.get("state_id") == &"completed"
		and "POWER CELL SECURED" in str(claimed_hulk.get("text", "")),
		"the durable claim remains complete when the sector unloads")
	_check((claimed_hulk.get("intents", []) as Array).is_empty()
		and not bool(claimed_hulk.get("actions_enabled", true))
		and not bool(presenter.select(hulk_id).get("accepted", true))
		and not bool(presenter.start_intent(hulk_id).get("accepted", true))
		and not bool(presenter.reset_intent(hulk_id).get("accepted", true)),
		"the hulk row has no board path to start, reset or claim salvage")
	var mining_card := _card(view, &"cinder_platform_mining_run")
	_check("COMPLETED" in str(mining_card.get("text", "")) and bool(mining_card.get("reward_pending", false)), "completed mining text includes state and pending reward")
	var scan_card := _card(view, &"cinder_derelict_structure_scan")
	_check(scan_card.get("state_id") == &"wrong_position" and "MOVE TO DERELICT SCAN MARKER" in str(scan_card.get("text", "")) and is_equal_approx(float(scan_card.scan_feedback.progress), 0.25), "scan rejection exposes progress and recovery reason")
	var cargo_card := _card(view, &"cinder_platform_supply_run")
	_check("EXPIRED" in str(cargo_card.get("text", "")) and "RECOVER EXPIRED RUN: RETURN TO THE CINDER BERTH" in str(cargo_card.get("text", "")), "cargo failure exposes state and recovery reason")
	_check(int(cargo_card.cargo_progress.next_phase_index) == 1 and cargo_card.cargo_progress.next_phase_id == &"clear_gate" and "EXPIRED 2/3" in str(cargo_card.get("text", "")), "cargo snapshot exposes ordered phase progress")
	var beacon_card := _card(view, &"cinder_debris_beacon_traversal")
	_check("WRONG ORDER" in str(beacon_card.get("text", "")) and beacon_card.beacon_feedback.objective_text == "RETURN TO EXPECTED BEACON 2", "beacon rejection exposes order-safe recovery")
	_check("EXPECTED BEACON 2/4" in str(beacon_card.get("text", "")) and int(beacon_card.beacon_feedback.next_beacon_index) == 1, "beacon snapshot exposes next target")
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


func _card(view: Dictionary, activity_id: StringName) -> Dictionary:
	for card: Dictionary in view.get("cards", []):
		if StringName(card.get("activity_id", &"")) == activity_id:
			return card
	return {}
