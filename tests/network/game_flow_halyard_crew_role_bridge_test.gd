extends SceneTree

const Halyard := preload("res://scripts/ships/halyard_crew_transport.gd")
const CrewAuthority := preload("res://scripts/ships/crew_seat_role_authority.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var authority := CrewAuthority.new(1)
	_check(authority.register_halyard_roster().accepted, "Halyard authority seals its physical roster")
	var halyard := Halyard.new()
	_check(halyard.attach_crew_role_authority(authority).accepted, "Halyard accepts the server role authority")
	var admitted := halyard.admit_network_crew_role(
		7, 4, &"avatar_7", &"pilot_station", &"pilot", 1, 1
	)
	_check(admitted.accepted, "server-admitted network role reaches Halyard seat authority")
	_check(authority.get_assignment(7, &"avatar_7").role == &"pilot", "Halyard exposes the admitted role assignment")
	var mismatch := halyard.admit_network_crew_role(
		7, 4, &"avatar_7", &"co_pilot_station", &"gunner", 1, 2
	)
	_check(not mismatch.accepted and mismatch.status == &"network_seat_mismatch", "cross-seat network escalation is rejected")
	var released := halyard.release_network_crew_role(7, 4, &"avatar_7", &"pilot_station", 1, 2)
	_check(released.accepted and authority.get_assignment(7, &"avatar_7").is_empty(), "detach/release clears the physical role assignment")
	halyard.free()
	if _failures.is_empty():
		print("OK: GameFlow/Halyard crew role bridge (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
