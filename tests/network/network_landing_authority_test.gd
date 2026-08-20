extends SceneTree

## Focused detached regression for authoritative landing leases and respawn
## generations. It does not instantiate ships, physics, RPC peers, or spawn
## scenes; production adapters remain responsible for those operations.

const Intent := preload("res://scripts/network/network_landing_intent.gd")
const Authority := preload("res://scripts/network/network_landing_authority.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_wire_contract()
	_test_landing_lease_race_and_commit()
	_test_respawn_generation_and_guards()
	if _failures.is_empty():
		print("OK: network landing authority (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _new_authority() -> Authority:
	var authority := Authority.new(99, 3, 1)
	_check(authority.register_entity(99, 7, &"fighter_a", 4).accepted, "server registers flying entity")
	_check(authority.register_landing_target(99, &"pad_alpha", &"ember_caldera").accepted, "server registers landing target")
	_check(authority.register_respawn_target(99, &"spawn_alpha", &"mudds_shipyards").accepted, "server registers respawn target")
	_check(authority.set_server_tick(99, 10).accepted, "server tick is caller-driven")
	return authority


func _intent(
	action: StringName,
	region_id: StringName,
	target_id: StringName,
	peer_id := 7,
	sequence := 0,
	tick := 10,
	generation := 4
) -> Dictionary:
	return Intent.create(
		peer_id, &"fighter_a", generation, 1, sequence, tick,
		action, region_id, target_id
	).to_dictionary()


func _test_wire_contract() -> void:
	var intent = Intent.create(7, &"fighter_a", 4, 2, 0, 10, Intent.ACTION_LANDING, &"ember_caldera", &"pad_alpha")
	_check(intent.is_valid(), "landing intent accepts the typed transport contract")
	var decoded = Intent.from_dictionary(intent.to_dictionary())
	_check(
		decoded.is_valid()
		and decoded.get_action() == Intent.ACTION_LANDING
		and decoded.get_target_id() == &"pad_alpha",
		"landing intent round-trips as detached data"
	)
	var forged: Dictionary = intent.to_dictionary()
	forged["lease_id"] = &"client_claimed_lease"
	_check(not Intent.from_dictionary(forged).is_valid(), "client cannot add a lease field")
	var malformed: Dictionary = intent.to_dictionary()
	malformed["action"] = &"teleport"
	_check(not Intent.from_dictionary(malformed).is_valid(), "unknown transition action fails closed")


func _test_landing_lease_race_and_commit() -> void:
	var authority := _new_authority()
	var spoofed := authority.accept_intent(8, _intent(Intent.ACTION_LANDING, &"ember_caldera", &"pad_alpha"))
	_check(not spoofed.accepted and spoofed.status == &"spoofed_peer", "transport sender cannot spoof packet peer")
	var reserved := authority.accept_intent(7, _intent(Intent.ACTION_LANDING, &"ember_caldera", &"pad_alpha"))
	_check(reserved.accepted and reserved.status == &"landing_reserved", "server creates one landing lease")
	var lease_id: StringName = reserved.lease_id
	var duplicate := authority.accept_intent(7, _intent(Intent.ACTION_LANDING, &"ember_caldera", &"pad_alpha", 7, 0))
	_check(not duplicate.accepted and duplicate.status == &"stale_sequence", "duplicate landing request cannot replay")
	var second_entity := authority.register_entity(99, 8, &"fighter_b", 1)
	_check(second_entity.accepted, "server registers a second owner for race coverage")
	var second = Intent.create(8, &"fighter_b", 1, 1, 0, 10, Intent.ACTION_LANDING, &"ember_caldera", &"pad_alpha")
	var occupied := authority.accept_intent(8, second.to_dictionary())
	_check(not occupied.accepted and occupied.status == &"landing_target_occupied", "landing target reservation is atomic")
	var committed := authority.commit_landing(99, &"fighter_a", 4, lease_id)
	_check(committed.accepted and committed.status == &"landing_committed", "server adapter commits physical landing lease")
	_check(
		authority.get_entity_snapshot(&"fighter_a").state == Authority.STATE_LANDED,
		"landing commit changes lifecycle state without a client transform"
	)
	var wrong_token := authority.commit_landing(99, &"fighter_a", 4, &"landing_lease_999")
	_check(not wrong_token.accepted and wrong_token.status == &"transition_not_pending", "committed landing cannot be replayed")


func _test_respawn_generation_and_guards() -> void:
	var authority := _new_authority()
	_check(authority.mark_destroyed(99, &"fighter_a", 4).accepted, "server marks destruction for the current generation")
	var wrong_target := authority.accept_intent(7, _intent(Intent.ACTION_RESPAWN, &"ember_caldera", &"spawn_alpha"))
	_check(not wrong_target.accepted and wrong_target.status == &"respawn_region_mismatch", "respawn region must match server target")
	var reserved := authority.accept_intent(7, _intent(Intent.ACTION_RESPAWN, &"mudds_shipyards", &"spawn_alpha", 7, 1))
	_check(reserved.accepted and reserved.status == &"respawn_reserved", "destroyed owner can reserve a server respawn target")
	var token: StringName = reserved.respawn_token
	var forged := authority.commit_respawn(99, &"fighter_a", 99, token)
	_check(not forged.accepted and forged.status == &"stale_entity_generation", "client-era generation cannot commit respawn")
	var committed := authority.commit_respawn(99, &"fighter_a", 4, token)
	_check(committed.accepted and committed.status == &"respawn_committed", "server advances generation on respawn commit")
	_check(
		int(authority.get_entity_snapshot(&"fighter_a").entity_generation) == 5
		and authority.get_entity_snapshot(&"fighter_a").state == Authority.STATE_FLYING,
		"respawn returns a fresh flying lifecycle generation"
	)
	var stale_intent := authority.accept_intent(7, _intent(Intent.ACTION_RESPAWN, &"mudds_shipyards", &"spawn_alpha", 7, 2, 10, 4))
	_check(not stale_intent.accepted and stale_intent.status == &"stale_entity_generation", "old respawn intent cannot target the new generation")
	var audit := authority.audit()
	_check(
		bool(audit.server_owns_landing_leases)
		and bool(audit.server_owns_target_occupancy)
		and bool(audit.server_owns_respawn_generation)
		and not bool(audit.server_owns_transforms)
		and not bool(audit.client_can_mutate_state),
		"audit separates network transition authority from production physics"
	)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
