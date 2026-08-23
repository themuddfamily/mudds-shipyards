extends SceneTree

const Presenter := preload("res://scripts/ui/surface_route_hazard_presenter.gd")
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var presenter := Presenter.new()
	var snapshot := presenter.present_snapshot({
		"weather": "Ashfall front",
		"waypoints": [{"id": &"relay", "label": "North Relay", "distance_m": 148.5}],
		"hazard": {"state": &"storm", "exposure": 0.91, "recovery_available": true},
	})
	_check(snapshot.next_landmark == "North Relay" and is_equal_approx(snapshot.distance_m, 148.5), "next surface landmark and distance remain readable")
	_check(snapshot.exposure_marker == &"!! HIGH EXPOSURE !!" and snapshot.weather == "Ashfall front", "hazard and weather use text markers independent of colour")
	_check(snapshot.actions.size() == 3 and snapshot.actions[2].focusable, "recovery-enabled hazard state exposes controller-focusable actions")
	_check(presenter.request_resume().accepted and presenter.request_abort().accepted and presenter.request_recovery().accepted, "route actions return external presentation intents")
	var safe := presenter.present_snapshot({"waypoints": [], "hazard": {"state": &"clear", "exposure": 0.0, "recovery_available": false}})
	_check(safe.next_landmark == "No waypoint queued" and safe.exposure_marker == &"[ SAFE WINDOW ]" and not presenter.request_recovery().accepted, "empty safe route fails closed without recovery authority")
	var detached := presenter.get_snapshot()
	detached["next_landmark"] = "forged"
	_check(presenter.get_snapshot().next_landmark == "No waypoint queued", "route presentation snapshot is detached")
	if _failures.is_empty():
		print("SURFACE_ROUTE_HAZARD_PRESENTER_TEST_OK: 6 assertions")
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)
	quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
