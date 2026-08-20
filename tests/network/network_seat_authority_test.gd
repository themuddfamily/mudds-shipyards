extends SceneTree

## Focused contract coverage for the server-owned multi-crew seat ledger.
## No MultiplayerPeer, scene, physics body, renderer, or production ship is
## started here; network adapters and moving-interior integration remain open.

const SeatAuthority := preload("res://scripts/network/network_seat_authority.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_registration_and_roles()
	_test_atomic_claims_and_replay_guards()
	_test_release_disconnect_and_detachment()
	if _failures.is_empty():
		print("OK: network seat role authority (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_registration_and_roles() -> void:
	var authority := SeatAuthority.new(99)
	_check(
		authority.register_seat(&"jovian_pilot", &"jovian", SeatAuthority.ROLE_PILOT, &"flight_frame").accepted,
		"server registers a stable pilot seat"
	)
	_check(
		authority.register_seat(&"jovian_passenger_01", &"jovian", SeatAuthority.ROLE_PASSENGER, &"flight_frame").accepted,
		"server registers a passenger seat on the same moving frame"
	)
	_check(
		authority.register_seat(&"jovian_engineer", &"jovian", SeatAuthority.ROLE_ENGINEER, &"flight_frame").accepted,
		"server registers an optional engineer role"
	)
	_check(
		authority.register_seat(&"jovian_bad", &"jovian", &"captain").status == &"invalid_role",
		"unknown roles fail closed instead of becoming implicit authority"
	)
	_check(
		authority.register_seat(&"jovian_pilot", &"jovian", SeatAuthority.ROLE_PILOT).status == &"duplicate_seat",
		"stable seat IDs cannot be registered twice"
	)
	var snapshot := authority.get_snapshot()
	_check(
		(snapshot.seats as Array).size() == 3
		and int(snapshot.get("schema_version", 0)) == SeatAuthority.SCHEMA_VERSION,
		"snapshot contains the typed seat roster and schema version"
	)


func _test_atomic_claims_and_replay_guards() -> void:
	var authority := SeatAuthority.new(99)
	authority.register_seat(&"jovian_pilot", &"jovian", SeatAuthority.ROLE_PILOT, &"flight_frame")
	authority.register_seat(&"jovian_passenger_01", &"jovian", SeatAuthority.ROLE_PASSENGER, &"flight_frame")
	var spoofed := authority.claim(7, 7, &"avatar_a", &"jovian_pilot", SeatAuthority.ROLE_PILOT, 1)
	_check(not spoofed.accepted and spoofed.status == &"unauthorized_source", "clients cannot mutate seat authority directly")
	var pilot := authority.claim(99, 7, &"avatar_a", &"jovian_pilot", SeatAuthority.ROLE_PILOT, 1)
	_check(pilot.accepted and pilot.status == &"claimed", "authoritative pilot claim is committed")
	var race := authority.claim(99, 8, &"avatar_b", &"jovian_pilot", SeatAuthority.ROLE_PILOT, 1)
	_check(not race.accepted and race.status == &"seat_occupied", "simultaneous pilot race resolves atomically to one winner")
	var mismatch := authority.claim(99, 8, &"avatar_b", &"jovian_passenger_01", SeatAuthority.ROLE_PILOT, 2)
	_check(not mismatch.accepted and mismatch.status == &"role_mismatch", "client cannot relabel a passenger seat as pilot")
	var passenger := authority.claim(99, 8, &"avatar_b", &"jovian_passenger_01", SeatAuthority.ROLE_PASSENGER, 3)
	_check(passenger.accepted, "passenger claim can coexist with the pilot claim")
	var duplicate := authority.claim(99, 8, &"avatar_b", &"jovian_passenger_01", SeatAuthority.ROLE_PASSENGER, 4)
	_check(not duplicate.accepted and duplicate.status == &"avatar_already_seated", "one avatar cannot occupy two seats")
	var reordered := authority.claim(99, 8, &"avatar_c", &"jovian_pilot", SeatAuthority.ROLE_PILOT, 2)
	_check(not reordered.accepted and reordered.status == &"stale_request_sequence", "out-of-order intent cannot replay after a newer sequence")
	_check(authority.audit().occupied_seat_count == 2, "audit counts authoritative occupancy rather than requests")


func _test_release_disconnect_and_detachment() -> void:
	var authority := SeatAuthority.new(99)
	authority.register_seat(&"jovian_pilot", &"jovian", SeatAuthority.ROLE_PILOT, &"flight_frame", 4)
	authority.register_seat(&"jovian_passenger_01", &"jovian", SeatAuthority.ROLE_PASSENGER, &"flight_frame", 2)
	authority.claim(99, 7, &"avatar_a", &"jovian_pilot", SeatAuthority.ROLE_PILOT, 1)
	authority.claim(99, 8, &"avatar_b", &"jovian_passenger_01", SeatAuthority.ROLE_PASSENGER, 1)
	var stale_release := authority.release(99, 7, &"avatar_a", &"jovian_pilot", 2, 3)
	_check(not stale_release.accepted and stale_release.status == &"stale_seat_generation", "late release cannot clear a reused seat generation")
	var release := authority.release(99, 7, &"avatar_a", &"jovian_pilot", 2, 4)
	_check(release.accepted and authority.get_assignment(7, &"avatar_a").is_empty(), "matching release removes the current assignment")
	var unauthorized_disconnect := authority.release_peer(7, 8)
	_check(not unauthorized_disconnect.accepted and unauthorized_disconnect.status == &"unauthorized_source", "disconnect cleanup is server lifecycle authority")
	var disconnected := authority.release_peer(99, 8)
	_check(disconnected.accepted and (disconnected.assignments as Array).size() == 1, "server disconnect cleanup frees every seat for a peer")
	var detached := authority.get_snapshot()
	(detached.assignments as Array).clear()
	_check((authority.get_snapshot().assignments as Array).size() == 0, "snapshot arrays are detached from the retained ledger")
	_check(
		authority.audit().server_owns_seat_reservation
		and authority.audit().server_owns_role_assignment
		and not authority.audit().client_can_mutate_ledger
		and not authority.audit().owns_movement,
		"audit states the multiplayer authority boundary explicitly"
	)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
