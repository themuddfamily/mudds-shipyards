extends SceneTree

## Focused detached regression for peer disconnect/reconnect lifecycle.
## It covers only server cleanup and generation fences; no MultiplayerPeer,
## production scene, physics, renderer, or extensive network soak is run.

const Lifecycle := preload("res://scripts/network/network_disconnect_lifecycle.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_cleanup_and_rejoin_fence()
	_test_session_rotation_fence()
	if _failures.is_empty():
		print("OK: network disconnect lifecycle (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _new_lifecycle() -> Lifecycle:
	var lifecycle := Lifecycle.new(99, 4, 12, 3, 1)
	_check(
		lifecycle.register_seat(99, &"jovian_pilot", &"jovian", Lifecycle.SeatAuthority.ROLE_PILOT, &"flight_frame", 4).accepted,
		"server registers the pilot seat"
	)
	_check(
		lifecycle.register_seat(99, &"jovian_passenger", &"jovian", Lifecycle.SeatAuthority.ROLE_PASSENGER, &"flight_frame", 2).accepted,
		"server registers the passenger seat"
	)
	_check(lifecycle.register_ship(99, &"jovian_a", 7).accepted, "server registers the ship generation")
	return lifecycle


func _hello(peer_generation: int = 1, session_generation: int = 3) -> Dictionary:
	return Lifecycle.create_hello(7, peer_generation, 4, 12, session_generation)


func _admit_and_seed(lifecycle: Lifecycle, peer_generation: int = 1, include_entity: bool = true) -> void:
	var admitted := lifecycle.admit_peer(7, _hello(peer_generation))
	_check(admitted.accepted and admitted.status == &"admitted", "peer is admitted through the handshake gate")
	_check(
		lifecycle.claim_seat(99, 7, peer_generation, &"avatar_a", &"jovian_pilot", Lifecycle.SeatAuthority.ROLE_PILOT, 1).accepted,
		"current peer claims the pilot seat"
	)
	_check(
		lifecycle.claim_ship(99, 7, peer_generation, &"jovian_a", 7, 1).accepted,
		"current peer claims the ship"
	)
	if include_entity:
		_check(
			lifecycle.register_entity(99, &"avatar_a", 2, 7, Vector3.ZERO, 50.0).accepted,
			"server registers the peer-owned replicated entity"
		)
		_check(
			lifecycle.publish_entity_state(99, &"avatar_a", 2, 4, Vector3(0.0, 0.0, -3.0), {"mode": &"seated"}).accepted,
			"server publishes the peer entity state"
		)
	_check(
		lifecycle.set_interest(99, 7, peer_generation, Vector3.ZERO, 20.0, 4).accepted,
		"current peer receives a bounded interest region"
	)
	var before := lifecycle.get_snapshot()
	_check(
		(before.peers as Array).size() == 1
		and (before.peer_interest as Dictionary).size() == 1
		and (before.seats.assignments as Array).size() == 1
		and int(before.ships.ships[0].owner_peer_id) == 7,
		"snapshot contains one connected peer, interest, seat, and owned ship"
	)


func _test_cleanup_and_rejoin_fence() -> void:
	var lifecycle := _new_lifecycle()
	_admit_and_seed(lifecycle)
	var unauthorized := lifecycle.disconnect_peer(7, 7, 1)
	_check(not unauthorized.accepted and unauthorized.status == &"unauthorized_source", "client cannot invoke disconnect cleanup")
	var stale := lifecycle.disconnect_peer(99, 7, 2)
	_check(not stale.accepted and stale.status == &"stale_peer_generation", "stale disconnect cannot clear a live peer")
	var disconnected := lifecycle.disconnect_peer(99, 7, 1)
	_check(disconnected.accepted and disconnected.status == &"disconnected", "server disconnect commits one lifecycle cleanup")
	_check(
		(disconnected.seat_cleanup.assignments as Array).size() == 1
		and (disconnected.ship_cleanup.ship_ids as Array).size() == 1
		and bool(disconnected.interest_removed),
		"disconnect receipt names seat, ship, and interest cleanup"
	)
	var after := lifecycle.get_snapshot()
	_check(
		(after.peers as Array).is_empty()
		and (after.peer_interest as Dictionary).is_empty()
		and (after.seats.assignments as Array).is_empty()
		and int(after.ships.ships[0].owner_peer_id) == 0
		and int(after.interest.peers.size()) == 0,
		"disconnect removes all peer attachments and interest subscriptions"
	)
	_check(
		int(after.interest.entities[0].owner_peer_id) == 0
		and int(after.interest.entities[0].entity_generation) == 2,
		"peer-owned entity survives as an unowned current generation"
	)
	var old_rejoin := lifecycle.admit_peer(7, _hello(1))
	_check(not old_rejoin.accepted and old_rejoin.status == &"stale_peer_generation", "stale rejoin cannot resurrect the released peer")
	_admit_and_seed(lifecycle, 2, false)
	_check(
		lifecycle.get_peer(7).peer_generation == 2,
		"new peer generation reconnects with fresh seat, ship, and interest state"
	)
	var stale_command := lifecycle.claim_seat(99, 7, 1, &"avatar_old", &"jovian_passenger", Lifecycle.SeatAuthority.ROLE_PASSENGER, 3)
	_check(not stale_command.accepted and stale_command.status == &"stale_peer_generation", "old peer generation cannot claim a seat after reconnect")


func _test_session_rotation_fence() -> void:
	var lifecycle := _new_lifecycle()
	_admit_and_seed(lifecycle)
	var unauthorized := lifecycle.rotate_session(7, 13)
	_check(not unauthorized.accepted and unauthorized.status == &"unauthorized_source", "client cannot rotate the session")
	var rotated := lifecycle.rotate_session(99, 13)
	_check(
		rotated.accepted
		and rotated.status == &"session_rotated"
		and int(rotated.session_generation) == 4
		and int(rotated.package_generation) == 13,
		"server rotation advances session and package generations"
	)
	var old := lifecycle.get_snapshot()
	_check(
		(old.peers as Array).is_empty()
		and (old.peer_interest as Dictionary).is_empty()
		and (old.seats.assignments as Array).is_empty()
		and int(old.ships.ships[0].owner_peer_id) == 0,
		"session rotation clears peer attachments before the next join"
	)
	var old_session := lifecycle.admit_peer(7, Lifecycle.create_hello(7, 2, 4, 13, 3))
	_check(not old_session.accepted and old_session.status == &"stale_session_generation", "old session generation cannot rejoin after rotation")
	var current := lifecycle.admit_peer(7, Lifecycle.create_hello(7, 3, 4, 13, 4))
	_check(current.accepted and current.status == &"admitted", "new peer and session generations can rejoin")
	var audit := lifecycle.audit()
	_check(
		bool(audit.server_owns_disconnect_cleanup)
		and bool(audit.server_owns_session_rotation)
		and bool(audit.server_owns_interest_cleanup)
		and bool(audit.stale_rejoins_rejected),
		"audit exposes the authoritative lifecycle and stale-rejoin boundaries"
	)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
