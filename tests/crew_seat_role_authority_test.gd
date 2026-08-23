extends SceneTree

## Focused runtime coverage for the production Halyard seat/role authority.
## This does not boot Main, create a MultiplayerPeer, move an avatar, mutate
## MovingInteriorFrame, or resolve ship/combat/landing state.

const Authority := preload("res://scripts/ships/crew_seat_role_authority.gd")

var _checks := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_halyard_roster_and_single_seal()
	_test_server_claims_and_role_capabilities()
	_test_generation_release_and_exactly_once_cleanup()
	if _failures.is_empty():
		print("OK: crew seat role authority (%d assertions)" % _checks)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_halyard_roster_and_single_seal() -> void:
	var authority := Authority.new(77)
	var roster := Authority.get_halyard_roster()
	_check(roster.size() == 8, "Halyard publishes eight physical crew seat records")
	var roles := {}
	for record_variant in roster:
		var record := record_variant as Dictionary
		roles[record.role] = int(roles.get(record.role, 0)) + 1
	_check(
		roles.has(Authority.ROLE_PILOT)
		and roles.has(Authority.ROLE_GUNNER)
		and roles.has(Authority.ROLE_PASSENGER)
		and roles.has(Authority.ROLE_ENGINEER),
		"Halyard roster includes pilot, gunner, passenger, and engineer semantics"
	)
	var registered := authority.register_halyard_roster()
	_check(registered.accepted and registered.status == &"roster_sealed", "published Halyard roster seals once")
	_check(authority.get_snapshot().roster_sealed, "claims cannot begin against an unsealed marker roster")
	var duplicate_seal := authority.seal_roster()
	_check(not duplicate_seal.accepted and duplicate_seal.status == &"roster_already_sealed", "roster sealing is exactly once")
	var late_marker := authority.register_seat(&"late_seat", &"halyard_new_design", Authority.ROLE_PASSENGER)
	_check(not late_marker.accepted and late_marker.status == &"roster_sealed", "late markers cannot enter authority after sealing")
	var audit := authority.audit()
	_check(
		bool(audit.server_owns_seat_reservation)
		and bool(audit.server_owns_role_assignment)
		and not bool(audit.client_can_mutate_ledger)
		and not bool(audit.owns_occupancy),
		"seat authority leaves movement-interior occupancy with its existing owner"
	)


func _test_server_claims_and_role_capabilities() -> void:
	var authority := Authority.new(77)
	authority.register_halyard_roster()
	var spoofed := authority.claim(9, 9, &"avatar_a", &"pilot_station", Authority.ROLE_PILOT, 1)
	_check(not spoofed.accepted and spoofed.status == &"unauthorized_source", "clients cannot commit a seat claim")
	var pilot := authority.claim(77, 9, &"avatar_a", &"pilot_station", Authority.ROLE_PILOT, 1)
	_check(pilot.accepted and pilot.status == &"claimed", "server commits the pilot role atomically")
	var gunner := authority.claim(77, 10, &"avatar_b", &"co_pilot_station", Authority.ROLE_GUNNER, 1)
	_check(gunner.accepted, "gunner role can coexist with the pilot")
	var passenger := authority.claim(77, 11, &"avatar_c", &"crew_port_00", Authority.ROLE_PASSENGER, 1)
	_check(passenger.accepted, "passenger role can coexist with flight-deck roles")
	var engineer := authority.claim(77, 12, &"avatar_d", &"crew_port_01", Authority.ROLE_ENGINEER, 1)
	_check(engineer.accepted, "engineer role can coexist with passenger occupancy")
	var race := authority.claim(77, 13, &"avatar_e", &"pilot_station", Authority.ROLE_PILOT, 1)
	_check(not race.accepted and race.status == &"seat_occupied", "simultaneous pilot claims resolve to one winner")
	var mismatch := authority.claim(77, 13, &"avatar_e", &"crew_starboard_00", Authority.ROLE_GUNNER, 2)
	_check(not mismatch.accepted and mismatch.status == &"role_mismatch", "a client cannot relabel a physical passenger seat")
	var pilot_command := authority.authorize_action(9, &"avatar_a", Authority.CAPABILITY_SHIP_COMMAND)
	_check(pilot_command.accepted, "pilot receives ship-command capability")
	var gunner_command := authority.authorize_action(10, &"avatar_b", Authority.CAPABILITY_SHIP_COMMAND)
	_check(not gunner_command.accepted and gunner_command.status == &"capability_denied", "gunner cannot take pilot movement authority")
	var gunner_weapons := authority.authorize_action(10, &"avatar_b", Authority.CAPABILITY_WEAPON_CONTROL)
	_check(gunner_weapons.accepted, "gunner receives weapon-control capability")
	var passenger_systems := authority.authorize_action(11, &"avatar_c", Authority.CAPABILITY_SYSTEMS_CONTROL)
	_check(not passenger_systems.accepted, "passenger cannot take engineer systems authority")
	var engineer_systems := authority.authorize_action(12, &"avatar_d", Authority.CAPABILITY_SYSTEMS_CONTROL)
	_check(engineer_systems.accepted, "engineer receives systems-control capability")
	_check(
		int(authority.get_snapshot().event_sequence) == 5,
		"only the four claims and one roster seal advance the lifecycle sequence"
	)


func _test_generation_release_and_exactly_once_cleanup() -> void:
	var authority := Authority.new(77)
	authority.register_halyard_roster(&"halyard_new_design", &"halyard_walkable_interior", 4)
	authority.claim(77, 21, &"avatar_a", &"pilot_station", Authority.ROLE_PILOT, 1)
	var stale := authority.release(77, 21, &"avatar_a", &"pilot_station", 2, 3)
	_check(not stale.accepted and stale.status == &"stale_seat_generation", "late release cannot clear a newer seat generation")
	var released := authority.release(77, 21, &"avatar_a", &"pilot_station", 2, 4)
	_check(released.accepted and authority.get_assignment(21, &"avatar_a").is_empty(), "matching generation release clears the pilot exactly once")
	var duplicate_release := authority.release(77, 21, &"avatar_a", &"pilot_station", 3, 4)
	_check(not duplicate_release.accepted and duplicate_release.status == &"assignment_not_found", "duplicate release does not emit a second lifecycle event")
	authority.claim(77, 22, &"avatar_b", &"crew_port_00", Authority.ROLE_PASSENGER, 1)
	authority.claim(77, 22, &"avatar_b2", &"crew_starboard_00", Authority.ROLE_PASSENGER, 2)
	var before_cleanup := int(authority.get_snapshot().event_sequence)
	var disconnected := authority.release_peer(77, 22)
	_check(disconnected.accepted and (disconnected.assignments as Array).size() == 2, "server disconnect cleanup releases every role for a peer")
	_check(
		int(authority.get_snapshot().event_sequence) == before_cleanup + 1,
		"multi-seat disconnect cleanup emits one exactly-once lifecycle event"
	)
	var duplicate_cleanup := authority.release_peer(77, 22)
	_check(duplicate_cleanup.accepted and (duplicate_cleanup.assignments as Array).is_empty(), "repeated disconnect cleanup is harmless and detached")
	_check(
		int(authority.get_snapshot().event_sequence) == before_cleanup + 1,
		"repeated disconnect cleanup does not advance lifecycle"
	)
	var detached := authority.get_snapshot()
	(detached.assignments as Array).clear()
	_check((authority.get_snapshot().assignments as Array).is_empty(), "snapshot detachment preserves cleared authoritative state")


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("FAIL: " + description)
