extends SceneTree

## Focused detached regression for server-owned ship claims and transfers.
## It does not start MultiplayerPeer, instantiate a ship, or mutate command or
## physics state; those remain production adapter responsibilities.

const Authority := preload("res://scripts/network/network_ship_ownership_authority.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_registration_and_server_only_claims()
	_test_generation_and_sequence_guards()
	_test_transfer_and_disconnect_cleanup()
	if _failures.is_empty():
		print("OK: network ship ownership authority (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_registration_and_server_only_claims() -> void:
	var authority := Authority.new(99)
	_check(
		authority.register_ship(99, &"zenith_a", 4).accepted,
		"server registers an unowned ship generation"
	)
	_check(
		authority.register_ship(7, &"zenith_b", 1).status == &"unauthorized_source",
		"clients cannot register ship ownership records"
	)
	var spoofed := authority.claim(7, 7, &"zenith_a", 4, 0)
	_check(not spoofed.accepted and spoofed.status == &"unauthorized_source", "clients cannot mutate ship claims directly")
	var claim := authority.claim(99, 7, &"zenith_a", 4, 0)
	_check(claim.accepted and claim.status == &"claimed", "server commits one ship claim for the requested peer")
	_check(
		int(authority.get_ship_snapshot(&"zenith_a").owner_peer_id) == 7
		and int(authority.get_ship_snapshot(&"zenith_a").ownership_generation) == 1,
		"claim snapshot exposes the authoritative owner and ownership generation"
	)
	var race := authority.claim(99, 8, &"zenith_a", 4, 0)
	_check(not race.accepted and race.status == &"ship_already_owned", "simultaneous claims resolve atomically to one owner")
	var audit := authority.audit()
	_check(
		bool(audit.server_owns_ship_claims)
		and bool(audit.server_owns_ship_transfers)
		and not bool(audit.client_can_mutate_ownership),
		"audit states the server-only ownership boundary"
	)


func _test_generation_and_sequence_guards() -> void:
	var authority := Authority.new(99)
	authority.register_ship(99, &"arrow_a", 12)
	var stale_generation := authority.claim(99, 7, &"arrow_a", 11, 0)
	_check(not stale_generation.accepted and stale_generation.status == &"stale_ship_generation", "stale lifecycle generation cannot claim a ship")
	var first := authority.claim(99, 7, &"arrow_a", 12, 4)
	_check(first.accepted, "current generation accepts the first claim sequence")
	var reordered := authority.transfer(99, 7, 8, &"arrow_a", 12, 3)
	_check(not reordered.accepted and reordered.status == &"stale_request_sequence", "out-of-order transfer sequence cannot replay")
	var stale_transfer_generation := authority.transfer(99, 7, 8, &"arrow_a", 11, 5)
	_check(not stale_transfer_generation.accepted and stale_transfer_generation.status == &"stale_ship_generation", "late transfer cannot target an old ship generation")
	var same_owner := authority.transfer(99, 7, 7, &"arrow_a", 12, 5)
	_check(not same_owner.accepted and same_owner.status == &"same_owner", "transfer to the current owner is rejected")
	var invalid_sequence := authority.release(99, 7, &"arrow_a", 12, -1)
	_check(not invalid_sequence.accepted and invalid_sequence.status == &"invalid_request_sequence", "negative request sequence fails closed")


func _test_transfer_and_disconnect_cleanup() -> void:
	var authority := Authority.new(99)
	authority.register_ship(99, &"jovian_a", 3)
	authority.register_ship(99, &"torrent_a", 8, 8)
	authority.claim(99, 7, &"jovian_a", 3, 1)
	var transferred := authority.transfer(99, 7, 8, &"jovian_a", 3, 2)
	_check(
		transferred.accepted
		and transferred.status == &"transferred"
		and int(authority.get_ship_snapshot(&"jovian_a").owner_peer_id) == 8,
		"server transfers ownership only from the current owner"
	)
	var wrong_owner := authority.transfer(99, 7, 6, &"jovian_a", 3, 3)
	_check(not wrong_owner.accepted and wrong_owner.status == &"owner_mismatch", "a late old owner cannot steal a transferred ship")
	var unauthorized_cleanup := authority.release_peer(7, 8)
	_check(not unauthorized_cleanup.accepted and unauthorized_cleanup.status == &"unauthorized_source", "disconnect cleanup cannot be invoked by a client")
	var cleanup := authority.release_peer(99, 8)
	_check(
		cleanup.accepted
		and (cleanup.ship_ids as Array).size() == 2
		and int(authority.get_ship_snapshot(&"jovian_a").owner_peer_id) == 0,
		"server disconnect cleanup releases every owned ship"
	)
	_check(int(authority.get_ship_snapshot(&"torrent_a").owner_peer_id) == 0, "disconnect cleanup also releases initially owned ships")
	var reconnect_claim := authority.claim(99, 8, &"jovian_a", 3, 0)
	_check(reconnect_claim.accepted, "a reused peer ID starts a fresh request stream after cleanup")
	var detached := authority.get_snapshot()
	(detached.ships as Array).clear()
	_check((authority.get_snapshot().ships as Array).size() == 2, "replicated ownership snapshots are detached from the ledger")
	var stale_retire := authority.retire_ship(99, &"jovian_a", 2)
	_check(not stale_retire.accepted and stale_retire.status == &"stale_ship_generation", "retirement also checks the lifecycle generation")
	_check(
		int(authority.get_snapshot().event_sequence) >= 5
		and bool(authority.audit().server_owns_disconnect_cleanup),
		"ownership events and disconnect ownership are server-auditable"
	)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
