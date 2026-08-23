extends SceneTree

const Interceptor := preload("res://scripts/ships/cinder_light_interceptor.gd")

var _assertions := 0
var _failures: Array[String] = []


func _initialize() -> void:
	var craft := Interceptor.new()
	root.add_child(craft)
	await process_frame
	var audit := craft.get_audit_report()
	_check(bool(audit.get("valid", false)), "the interceptor builds a valid collision and lifecycle contract")
	_check(audit.get("evidence_status", &"") == &"NEW" and not bool(audit.get("historically_supported", true)), "the interceptor makes no historical claim")
	_check(craft.get_cockpit_seat_anchor() != null and craft.get_boarding_marker() != null, "the interceptor exposes physical cockpit and boarding anchors")
	_check(bool(craft is HeroShip) and bool(audit.get("flight_authority", false)) and not bool(audit.get("combat_authority", true)) and not bool(audit.get("weapon_authority", true)), "HeroShip owns flight while the component adds no duplicate combat or weapon authority")
	craft.queue_free()
	await process_frame
	if _failures.is_empty():
		print("PASS cinder_light_interceptor_test (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
