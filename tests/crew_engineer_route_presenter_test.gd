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
	var gunner_view := presenter.present_snapshot({
		"roles": {&"gunner": {"occupant": "bulwark-gunner", "available": true}},
		"gunner_weapon": {
			"weapon_id": &"bulwark_siege_lance", "charge_progress": 0.625,
			"ammunition_remaining": 2, "cooldown_remaining": 0.4,
			"weapon_ready": false, "unavailable_reason": &"cooldown",
			"fire_action": &"fire", "aim_action": &"aim",
		},
	})
	var weapon := gunner_view.gunner_weapon as Dictionary
	_check(weapon.get("status") == "GUNNER UNAVAILABLE", "gunner status is text-first when weapon is unavailable")
	_check(is_equal_approx(float(weapon.get("charge_progress", 0.0)), 0.625) and int(weapon.get("ammunition", 0)) == 2, "siege-lance charge and ammunition are preserved")
	_check(float(weapon.get("cooldown_remaining", 0.0)) == 0.4 and weapon.get("unavailable_reason") == &"cooldown", "cooldown and unavailable reason are readable")
	_check(weapon.get("fire_action") == &"fire" and weapon.get("aim_action") == &"aim", "caller supplies mapped fire and aim actions")
	var disconnected := presenter.present_snapshot({"detached": true, "roles": {&"gunner": {"occupant": "bulwark-gunner"}}, "gunner_weapon": {"ammunition": 2}})
	_check((disconnected.gunner_weapon as Dictionary).get("status") == "GUNNER DISCONNECTED", "detach exposes disconnected gunner state")
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
