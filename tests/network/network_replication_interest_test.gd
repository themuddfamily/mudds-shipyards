extends SceneTree

## Focused detached regression for server interest filtering and replication
## ownership. No MultiplayerPeer, nodes, physics, or client RPCs are created.

const Authority := preload("res://scripts/network/network_replication_interest.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_server_only_and_generation_fences()
	_test_interest_filter_and_detached_state()
	_test_rate_budget_and_ownership()
	if _failures.is_empty():
		print("OK: network replication interest (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _new_authority() -> Authority:
	var authority := Authority.new(99, 1)
	_check(authority.register_peer(99, 7).accepted, "server registers replication peer")
	_check(authority.set_peer_interest(99, 7, Vector3.ZERO, 20.0, 1).accepted, "server sets bounded interest region")
	_check(
		authority.register_entity(99, &"near", 3, 7, Vector3(0.0, 0.0, -5.0), 20.0).accepted,
		"server registers near entity and owner"
	)
	_check(
		authority.register_entity(99, &"far", 4, 8, Vector3(100.0, 0.0, 0.0), 20.0).accepted,
		"server registers far entity"
	)
	return authority


func _test_server_only_and_generation_fences() -> void:
	var authority := _new_authority()
	_check(not authority.register_peer(7, 8).accepted, "client cannot register a replication peer")
	_check(
		not authority.publish_state(7, &"near", 3, 1, Vector3.ZERO, {"hp": 1}).accepted,
		"client cannot publish entity state"
	)
	_check(
		authority.publish_state(99, &"near", 3, 1, Vector3(0.0, 0.0, -5.0), {"hp": 90}).accepted,
		"server publishes entity state"
	)
	var stale := authority.publish_state(99, &"near", 2, 1, Vector3.ZERO, {"hp": 1})
	_check(not stale.accepted and stale.status == &"stale_entity_generation", "stale generation cannot publish")
	var transfer := authority.transfer_ownership(99, &"near", 2, 7, 8)
	_check(not transfer.accepted and transfer.status == &"stale_entity_generation", "stale generation cannot transfer ownership")
	_check(
		not authority.transfer_ownership(7, &"near", 3, 7, 8).accepted,
		"client cannot transfer server ownership"
	)


func _test_interest_filter_and_detached_state() -> void:
	var authority := _new_authority()
	_check(authority.publish_state(99, &"near", 3, 1, Vector3(0.0, 0.0, -5.0), {"hp": 90, "tag": &"visible"}).accepted, "server publishes near state")
	_check(authority.publish_state(99, &"far", 4, 1, Vector3(100.0, 0.0, 0.0), {"hp": 50}).accepted, "server publishes far state")
	var batch := authority.replicate(99, 7, 1)
	_check(batch.accepted and batch.status == &"replicated", "server emits a replication batch")
	var entries: Array = batch.entities
	_check(entries.size() == 1 and entries[0].entity_id == &"near", "interest filters out distant entity")
	_check(entries[0].state.hp == 90 and entries[0].owner_peer_id == 7, "batch carries detached state and owner")
	entries[0].state.hp = 0
	_check(int(authority.get_entity_snapshot(&"near").state.hp) == 90, "replication state is detached from authority")
	var unchanged := authority.replicate(99, 7, 1)
	_check(unchanged.accepted and unchanged.status == &"no_changes", "unchanged revision is not resent")


func _test_rate_budget_and_ownership() -> void:
	var authority := Authority.new(99, 1)
	_check(authority.register_peer(99, 7).accepted, "budget test registers peer")
	_check(authority.set_peer_interest(99, 7, Vector3.ZERO, 100.0, 10).accepted, "budget test sets interest")
	for id in [&"a", &"b"]:
		_check(authority.register_entity(99, id, 1, 0, Vector3.ZERO, 100.0).accepted, "budget test registers entity")
		_check(authority.publish_state(99, id, 1, 1, Vector3.ZERO, {"id": id}).accepted, "budget test publishes entity")
	var first := authority.replicate(99, 7, 1)
	_check(first.entities.size() == 1 and first.deferred_entity_ids.size() == 1, "per-tick budget defers excess entity")
	var second := authority.replicate(99, 7, 1)
	_check(second.status == &"rate_limited" and second.entities.is_empty(), "same tick cannot exceed budget")
	_check(authority.transfer_ownership(99, &"a", 1, 0, 7).accepted, "server transfers entity ownership")
	var next := authority.replicate(99, 7, 2)
	_check(next.entities.size() == 1 and next.entities[0].owner_peer_id == 7, "ownership change is replicated")
	var audit := authority.audit()
	_check(bool(audit.server_owns_interest) and bool(audit.server_owns_replication_budget) and not bool(audit.client_can_mutate_state) and not bool(audit.client_can_transfer_ownership), "audit records server-only replication authority")


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
