extends SceneTree

## Focused detached regression for authoritative boarding and moving-interior
## occupancy. No MultiplayerPeer, production scene, physics, or renderer is
## started; those remain adapter and packaged-playtest responsibilities.

const Intent := preload("res://scripts/network/network_boarding_intent.gd")
const Authority := preload("res://scripts/network/network_boarding_authority.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_intent_schema_and_registration()
	_test_atomic_occupancy_and_generations()
	_test_disembark_disconnect_and_detachment()
	if _failures.is_empty():
		print("OK: network boarding occupancy authority (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _register_standard(authority: Authority) -> void:
	authority.register_ship(99, &"jovian_a", 4, &"flight_frame", 7)
	authority.register_seat(99, &"jovian_pilot", &"jovian_a", 3, Intent.ROLE_PILOT)
	authority.register_seat(99, &"jovian_passenger_01", &"jovian_a", 2, Intent.ROLE_PASSENGER)


func _wire(
	peer_id: int,
	avatar_id: StringName,
	seat_id: StringName,
	seat_generation: int,
	role: StringName,
	sequence: int,
	action: StringName,
	ship_generation: int = 4,
	frame_generation: int = 7
) -> Dictionary:
	return Intent.create(
		peer_id, avatar_id, &"jovian_a", ship_generation, &"flight_frame",
		frame_generation, seat_id, seat_generation, role, sequence, 0, action
	).to_dictionary()


func _test_intent_schema_and_registration() -> void:
	var intent = Intent.create(
		7, &"avatar_a", &"jovian_a", 4, &"flight_frame", 7,
		&"jovian_pilot", 3, Intent.ROLE_PILOT, 1, 0, Intent.ACTION_BOARD
	)
	_check(intent.is_valid(), "boarding packet accepts the exact typed wire schema")
	var extra: Dictionary = intent.to_dictionary()
	extra["client_transform"] = Vector3.ZERO
	_check(not Intent.from_dictionary(extra).is_valid(), "boarding packet cannot smuggle a client transform")
	var authority := Authority.new(99)
	_check(
		authority.register_ship(7, &"jovian_a", 4, &"flight_frame", 7).status == &"unauthorized_source",
		"clients cannot register ship/frame occupancy records"
	)
	_register_standard(authority)
	_check(
		authority.register_seat(99, &"jovian_pilot", &"jovian_a", 3, Intent.ROLE_PILOT).status == &"duplicate_seat",
		"stable seat IDs cannot be registered twice"
	)
	_check(
		int(authority.get_snapshot().get("schema_version", 0)) == Authority.SCHEMA_VERSION
		and authority.get_snapshot().seats.size() == 2,
		"snapshot exposes the registered ship-bound seat roster"
	)


func _test_atomic_occupancy_and_generations() -> void:
	var authority := Authority.new(99)
	_register_standard(authority)
	var spoofed := authority.accept_intent(8, _wire(7, &"avatar_a", &"jovian_pilot", 3, Intent.ROLE_PILOT, 1, Intent.ACTION_BOARD))
	_check(not spoofed.accepted and spoofed.status == &"spoofed_peer", "spoofed peer IDs cannot board")
	var pilot := authority.accept_intent(7, _wire(7, &"avatar_a", &"jovian_pilot", 3, Intent.ROLE_PILOT, 1, Intent.ACTION_BOARD))
	_check(pilot.accepted and pilot.status == &"boarded", "server commits a valid pilot boarding claim")
	var seat_race := authority.accept_intent(8, _wire(8, &"avatar_b", &"jovian_pilot", 3, Intent.ROLE_PILOT, 1, Intent.ACTION_BOARD))
	_check(not seat_race.accepted and seat_race.status == &"seat_occupied", "simultaneous claims resolve to one occupant")
	var avatar_race := authority.accept_intent(7, _wire(7, &"avatar_a", &"jovian_passenger_01", 2, Intent.ROLE_PASSENGER, 2, Intent.ACTION_BOARD))
	_check(not avatar_race.accepted and avatar_race.status == &"avatar_already_occupied", "one avatar cannot occupy two seats")
	var stale_ship := authority.accept_intent(8, _wire(8, &"avatar_b", &"jovian_passenger_01", 2, Intent.ROLE_PASSENGER, 2, Intent.ACTION_BOARD, 3, 7))
	_check(not stale_ship.accepted and stale_ship.status == &"stale_ship_generation", "late ship generation cannot claim occupancy")
	var stale_frame := authority.accept_intent(8, _wire(8, &"avatar_b", &"jovian_passenger_01", 2, Intent.ROLE_PASSENGER, 3, Intent.ACTION_BOARD, 4, 6))
	_check(not stale_frame.accepted and stale_frame.status == &"stale_frame_generation", "late moving-frame generation cannot claim occupancy")
	var role_mismatch := authority.accept_intent(8, _wire(8, &"avatar_b", &"jovian_passenger_01", 2, Intent.ROLE_PILOT, 4, Intent.ACTION_BOARD))
	_check(not role_mismatch.accepted and role_mismatch.status == &"role_mismatch", "client cannot relabel a passenger role")
	var passenger := authority.accept_intent(8, _wire(8, &"avatar_b", &"jovian_passenger_01", 2, Intent.ROLE_PASSENGER, 5, Intent.ACTION_BOARD))
	_check(passenger.accepted, "current ship/frame generation accepts the passenger claim")
	var replay := authority.accept_intent(8, _wire(8, &"avatar_b", &"jovian_passenger_01", 2, Intent.ROLE_PASSENGER, 5, Intent.ACTION_BOARD))
	_check(not replay.accepted and replay.status == &"stale_sequence", "replayed boarding intent is rejected")
	_check(authority.audit().occupied_seat_count == 2, "audit counts occupancy records rather than requests")


func _test_disembark_disconnect_and_detachment() -> void:
	var authority := Authority.new(99)
	_register_standard(authority)
	authority.accept_intent(7, _wire(7, &"avatar_a", &"jovian_pilot", 3, Intent.ROLE_PILOT, 1, Intent.ACTION_BOARD))
	var stale_exit := authority.accept_intent(7, _wire(7, &"avatar_a", &"jovian_pilot", 2, Intent.ROLE_PILOT, 2, Intent.ACTION_DISEMBARK))
	_check(not stale_exit.accepted and stale_exit.status == &"stale_seat_generation", "late disembark cannot clear a reused seat generation")
	var exit := authority.accept_intent(7, _wire(7, &"avatar_a", &"jovian_pilot", 3, Intent.ROLE_PILOT, 3, Intent.ACTION_DISEMBARK))
	_check(exit.accepted and authority.get_occupancy(7, &"avatar_a").is_empty(), "matching disembark clears the current occupancy")
	authority.accept_intent(8, _wire(8, &"avatar_b", &"jovian_passenger_01", 2, Intent.ROLE_PASSENGER, 1, Intent.ACTION_BOARD))
	var unauthorized := authority.release_peer(8, 8)
	_check(not unauthorized.accepted and unauthorized.status == &"unauthorized_source", "disconnect cleanup is server-only")
	var released := authority.release_peer(99, 8)
	_check(released.accepted and released.occupancies.size() == 1, "server disconnect cleanup frees occupancy")
	var detached := authority.get_snapshot()
	detached.occupancies.clear()
	_check(authority.get_snapshot().occupancies.size() == 0, "detached snapshot does not mutate retained occupancy")
	_check(
		authority.audit().server_owns_boarding
		and authority.audit().server_owns_seat_occupancy
		and not authority.audit().client_can_mutate_occupancy
		and authority.audit().one_seat_per_avatar
		and authority.audit().one_avatar_per_seat,
		"audit states the multiplayer boarding ownership boundary"
	)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
