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
		"cinder_debris_beacon_traversal", "cinder_derelict_structure_scan",
		"cinder_platform_mining_run", "cinder_platform_supply_run",
		"cinder_reach_checkpoint_route", "cinder_reach_emberline_convoy",
		"cinder_relay_patrol", "station_defense",
	], "the presenter renders each integrated activity once regardless of priority order")
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
