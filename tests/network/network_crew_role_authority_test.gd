extends SceneTree

const SeatAuthority := preload("res://scripts/network/network_seat_authority.gd")
const CrewAuthority := preload("res://scripts/network/network_crew_role_authority.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var seats := SeatAuthority.new(1)
	_check(seats.register_seat(&"pilot_seat", &"ship_7", &"pilot", &"frame_7", 2).accepted, "seat authority registers the pilot seat")
	_check(seats.claim(1, 7, &"avatar_7", &"pilot_seat", &"pilot", 1).accepted, "seat authority establishes occupancy")
	var crew := CrewAuthority.new(seats, 1)
	_check(crew.admit_peer(1, 7, 4).accepted, "crew authority admits the peer generation")
	var accepted := crew.accept_role_intent(1, 7, 4, &"avatar_7", &"pilot", 1)
	_check(accepted.accepted and accepted.role.role == &"pilot", "seated peer can claim its assigned role")
	_check(crew.accept_role_intent(1, 7, 4, &"avatar_7", &"pilot", 1).status == &"stale_request_sequence", "role replay is rejected")
	_check(crew.accept_role_intent(1, 7, 4, &"avatar_7", &"gunner", 2).status == &"role_escalation_rejected", "cross-seat role escalation is rejected")
	_check(crew.accept_role_intent(1, 7, 4, &"avatar_7", &"pilot", 2, &"other_ship", 1).status == &"ship_identity_mismatch", "cross-ship role identity is rejected")
	_check(crew.release_peer(1, 7, 4).accepted and crew.get_snapshot().role_count == 0, "disconnect cleanup releases crew roles")
	_check(crew.admit_peer(1, 7, 5).accepted and crew.reset_migration(1, 2).accepted
		and crew.get_snapshot().admitted_peer_count == 1 and crew.get_snapshot().role_count == 0,
		"migration reset clears roles while retaining fresh admission")
	if _failures.is_empty():
		print("OK: crew role authority (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
