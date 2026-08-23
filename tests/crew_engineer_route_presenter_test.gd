extends SceneTree

const Presenter := preload("res://scripts/ui/crew_role_seat_presenter.gd")

var _assertions := 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var presenter := Presenter.new()
	var attached := presenter.present_snapshot({
		"roles": {
			&"engineer": {
				"occupant": "eng-2",
				"power_route": &"primary",
				"mobility": &"limited",
				"fire": &"restricted",
				"targeting": &"available",
			},
		},
	})
	var route := attached.engineer_route as Dictionary
	_check(attached.engineer_route_attached, "attached snapshot exposes engineer route")
	_check(route.power_route == &"primary" and route.power_marker == "●", "power route has bounded text and shape")
	_check(route.mobility == &"limited" and route.fire == &"restricted" and route.targeting == &"available", "mobility fire and targeting states are preserved")
	var malformed := presenter.present_snapshot({"roles": {&"engineer": {"power_route": &"forged", "mobility": &"forged"}}})
	_check(malformed.engineer_route.power_route == &"offline" and malformed.engineer_route.mobility == &"immobile", "unknown engineer states fail closed")
	var detached := presenter.present_snapshot({"detached": true, "roles": {&"engineer": {"power_route": &"primary"}}})
	_check(not detached.engineer_route_attached and detached.engineer_route.is_empty(), "detach clears route and capability outputs")
	var handoff := presenter.present_snapshot({"handoff": true, "roles": {&"engineer": {"power_route": &"primary"}}})
	_check(not handoff.engineer_route_attached and handoff.engineer_route.is_empty(), "handoff clears route and capability outputs")
	if _failures.is_empty():
		print("CREW_ENGINEER_ROUTE_PRESENTER_TEST_OK (%d assertions)" % _assertions)
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
