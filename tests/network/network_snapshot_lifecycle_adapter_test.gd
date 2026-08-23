extends SceneTree

## Focused production-session integration for the NetworkDisconnectLifecycle ->
## NetworkAuthoritativeSnapshot seam. It does not open ENet or instantiate the
## station; those remain the RPC/scene gates.

const Adapter := preload("res://scripts/network/network_snapshot_lifecycle_adapter.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_lifecycle_records_feed_snapshot()
	_test_disconnect_requires_refresh()
	_test_replica_boundary()
	if _failures.is_empty():
		print("OK: network snapshot lifecycle adapter (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_lifecycle_records_feed_snapshot() -> void:
	var adapter := Adapter.new(99, 1, 2, 3)
	var hello := Adapter.create_hello(7, 4, 1, 2, 3)
	_check(adapter.admit_peer(7, hello).accepted, "session coordinator admits the peer generation")
	_check(adapter.register_ship(99, &"jovian_a", 4).accepted, "adapter registers the server-owned ship")
	_check(adapter.register_seat(99, &"jovian_pilot", &"jovian_a", &"pilot", &"flight_frame", 7).accepted, "adapter registers the server-owned pilot seat")
	_check(adapter.claim_ship(99, 7, 4, &"jovian_a", 4, 0).accepted, "session claim commits ship ownership")
	_check(adapter.claim_seat(99, 7, 4, &"avatar_a", &"jovian_pilot", &"pilot", 1).accepted, "session claim commits boarding occupancy")
	var result := adapter.publish_authority_snapshot(
		99, 20, _movement(), _projectiles(), _respawn(), _landing()
	)
	_check(
		result.accepted
		and result.status == &"published"
		and int(result.session_generation) == 3,
		"adapter publishes one snapshot using the lifecycle session generation"
	)
	var authoritative: Dictionary = adapter.get_authoritative_snapshot()
	_check(
		(authoritative.sections.ownership as Array).size() == 1
		and int(authoritative.sections.ownership[0].owner_peer_id) == 7
		and (authoritative.sections.boarding as Array).size() == 1
		and (authoritative.sections.landing as Array).size() == 1
		and authoritative.sections.landing[0].state == &"landing_pending",
		"session ownership and committed landing records feed the synchronized sections"
	)
	var audit := adapter.audit()
	_check(
		bool(audit.server_owns_peer_lifecycle)
		and bool(audit.server_owns_snapshot_publication)
		and audit.session_coordinator_policy == &"network_disconnect_lifecycle_v1",
		"audit names the existing coordinator and the new snapshot publication boundary"
	)


func _test_disconnect_requires_refresh() -> void:
	var adapter := Adapter.new(99, 1, 2, 3)
	_check(adapter.admit_peer(7, Adapter.create_hello(7, 4, 1, 2, 3)).accepted, "disconnect fixture admits the same peer generation")
	adapter.register_ship(99, &"jovian_a", 4, 7)
	adapter.register_seat(99, &"jovian_pilot", &"jovian_a", &"pilot", &"flight_frame", 7)
	_check(adapter.claim_seat(99, 7, 4, &"avatar_a", &"jovian_pilot", &"pilot", 1).accepted, "disconnect fixture owns a seat before cleanup")
	var pre_cleanup := adapter.publish_authority_snapshot(99, 20, _movement(), _projectiles(), _respawn())
	_check(pre_cleanup.accepted, "disconnect fixture publishes pre-cleanup state")
	var disconnected := adapter.disconnect_peer(99, 7, 4)
	_check(
		disconnected.accepted
		and bool(disconnected.snapshot_requires_publish)
		and adapter.audit().snapshot_needs_publish,
		"coordinator disconnect marks the snapshot stale until the next server publication"
	)
	var refreshed := adapter.publish_authority_snapshot(99, 21, _movement(), _projectiles(), _respawn())
	_check(refreshed.accepted, "server refreshes synchronized state after disconnect cleanup")
	var ownership: Array = adapter.get_authoritative_snapshot().sections.ownership
	var boarding: Array = adapter.get_authoritative_snapshot().sections.boarding
	_check(
		ownership.size() == 1 and int(ownership[0].owner_peer_id) == 0
		and ownership[0].state == &"disconnected"
		and boarding.size() == 1 and int(boarding[0].occupant_peer_id) == 0
		and boarding[0].state == &"disconnected",
		"refreshed snapshot retains presentation-only disconnect tombstones"
	)


func _test_replica_boundary() -> void:
	var server := Adapter.new(99, 1, 2, 3)
	server.admit_peer(7, Adapter.create_hello(7, 4, 1, 2, 3))
	server.register_ship(99, &"jovian_a", 4, 7)
	server.register_seat(99, &"jovian_pilot", &"jovian_a", &"pilot", &"flight_frame", 7)
	server.claim_seat(99, 7, 4, &"avatar_a", &"jovian_pilot", &"pilot", 1)
	var server_packet_result := server.publish_authority_snapshot(
		99, 20, _movement(), _projectiles(), _respawn(), _landing()
	)
	_check(server_packet_result.accepted, "server produces the replica packet")
	var packet := server.get_authoritative_snapshot()
	var replica := Adapter.new(99, 1, 2, 3)
	_check(
		replica.apply_replica_snapshot(7, packet).status == &"unauthorized_source",
		"client cannot inject the server snapshot through the adapter"
	)
	_check(
		replica.apply_replica_snapshot(99, packet).accepted
		and replica.get_authoritative_snapshot().sections.movement.size() == 1
		and replica.get_authoritative_snapshot().sections.landing[0].state == &"landing_pending",
		"replica adapter applies the server-owned synchronized landing packet"
	)


func _movement() -> Array:
	return [{"entity_id": &"avatar_a", "entity_generation": 2, "owner_peer_id": 7, "mode": &"on_foot"}]


func _projectiles() -> Array:
	return [{
		"projectile_id": &"projectile_1",
		"projectile_generation": 1,
		"source_entity_id": &"jovian_a",
		"source_generation": 4,
		"owner_peer_id": 7,
		"projectile_revision": 2,
		"projectile_server_tick": 20,
		"position": Vector3(2.0, 1.0, 0.0),
		"terminal": false,
		"state": &"active",
	}]


func _respawn() -> Array:
	return [{
		"entity_id": &"jovian_a",
		"entity_generation": 4,
		"component_generation": 1,
		"damage_revision": 2,
		"damage_server_tick": 20,
		"health": 100.0,
		"maximum_health": 100.0,
		"destroyed": false,
		"recovery_generation": 0,
		"damage_event_count": 0,
		"state": &"active",
	}]


func _landing() -> Array:
	return [{
		"entity_id": &"jovian_a",
		"entity_generation": 4,
		"landing_revision": 3,
		"landing_server_tick": 20,
		"position": Vector3(12.0, 0.0, -4.0),
		"state": &"landing_pending",
	}]


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
