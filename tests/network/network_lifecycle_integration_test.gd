extends SceneTree

## Focused integration regression for the first multiplayer lifecycle slice.
## It composes detached ledgers only: no MultiplayerPeer, production scene,
## physics, renderer, audio, native process, or soak is started here.

const Integration := preload("res://scripts/network/network_lifecycle_integration.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_join_replication_and_prediction()
	_test_rotation_rebind_and_disconnect()
	if _failures.is_empty():
		print("OK: network lifecycle integration (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _new_integration() -> Integration:
	var integration := Integration.new(99, 4, 12, 3, 1)
	_check(
		integration.register_seat(&"jovian_pilot", &"jovian", &"pilot", &"flight_frame", 4).accepted,
		"server registers the pilot seat"
	)
	_check(
		integration.register_seat(&"jovian_passenger", &"jovian", &"passenger", &"flight_frame", 2).accepted,
		"server registers the passenger seat"
	)
	_check(integration.register_ship(&"jovian_a", 7).accepted, "server registers the ship generation")
	return integration


func _join(integration: Integration, peer_generation: int = 1) -> Dictionary:
	return integration.join_peer(
		7,
		Integration.create_hello(7, peer_generation, 4, 12, 3),
		&"avatar_a",
		&"jovian_pilot",
		&"pilot",
		&"jovian_a",
		7,
		Vector3.ZERO,
		20.0,
		4,
		&"avatar_a",
		2
	)


func _test_join_replication_and_prediction() -> void:
	var integration := _new_integration()
	var spoofed := _join_with_source(integration, 8, 1)
	_check(not spoofed.accepted and spoofed.status == &"handshake_rejected", "transport source cannot spoof the joining peer")
	var joined := _join(integration)
	_check(joined.accepted and joined.status == &"joined", "matching handshake admits the peer")
	_check(
		joined.has("seat") and bool((joined.seat as Dictionary).get("accepted", false))
		and joined.has("ship") and bool((joined.ship as Dictionary).get("accepted", false))
		and joined.has("interest") and bool((joined.interest as Dictionary).get("accepted", false))
		and joined.has("migration") and bool((joined.migration as Dictionary).get("accepted", false)),
		"join commits seat, ship, interest, and migration attachment receipts"
	)
	_check(
		integration.register_entity(&"avatar_a", 2, 7, Vector3.ZERO, 50.0).accepted,
		"server registers the admitted peer entity and prediction generation"
	)
	_check(
		integration.publish_entity_state(
			&"avatar_a", 2, 4, Vector3(0.0, 0.0, -3.0), {"mode": &"seated"}
		).accepted,
		"server publishes one authoritative entity state"
	)
	var batch := integration.replicate(4)
	_check(batch.accepted and batch.status == &"replicated", "active peer receives a bounded interest batch")
	_check(
		(batch.entities as Array).size() == 1
		and StringName((batch.entities[0] as Dictionary).get("entity_id", &"")) == &"avatar_a",
		"replication interest includes the seated peer entity"
	)
	var prediction := integration.accept_prediction(
		7,
		4,
		{
			"entity_id": &"avatar_a",
			"entity_generation": 2,
			"position": [0.0, 0.0, -3.0],
			"velocity": [0.0, 0.0, 0.0],
		},
		4,
		10,
		Vector3(0.5, 0.0, -3.0),
		Vector3.ZERO
	)
	_check(
		prediction.accepted and prediction.status == &"correction_required"
		and not bool(prediction.get("client_can_mutate_state", true)),
		"server snapshot drives presentation-only prediction correction"
	)
	var audit := integration.audit()
	_check(
		bool(audit.server_owns_join_handshake)
		and bool(audit.server_owns_replication_interest)
		and bool(audit.server_owns_prediction_correction)
		and bool(audit.server_owns_seat_and_ship_ownership)
		and not bool(audit.client_can_mutate_authority),
		"integration audit preserves the server-only authority boundary"
	)


func _test_rotation_rebind_and_disconnect() -> void:
	var integration := _new_integration()
	_check(_join(integration).accepted, "rotation fixture admits the initial peer")
	var rotated := integration.rotate_session(13)
	_check(rotated.accepted and rotated.status == &"rotated", "server rotation advances both lifecycle epochs")
	_check(
		int(rotated.migration.package_generation) == 13
		and int(rotated.migration.session_generation) == 4
		and int(rotated.migration.migration_generation) == 2
		and integration.get_snapshot().phase == &"migration_pending",
		"rotation retains migration metadata while clearing live attachments"
	)
	var stale_rebind := integration.rebind_peer(7, 1)
	_check(not stale_rebind.accepted and stale_rebind.status == &"rebind_handshake_rejected", "old peer generation cannot rejoin after rotation")
	var rebound := integration.rebind_peer(7, 2, Vector3.ZERO, 20.0, 4)
	_check(rebound.accepted and rebound.status == &"rebound", "current handshake and migration receipt restore the peer")
	_check(
		bool((rebound.seat as Dictionary).get("accepted", false))
		and bool((rebound.ship as Dictionary).get("accepted", false))
		and bool((rebound.interest as Dictionary).get("accepted", false))
		and integration.get_snapshot().phase == &"active",
		"rebind restores seat, ship ownership, and interest as one active slice"
	)
	var unauthorized := integration.disconnect_peer(7)
	_check(not unauthorized.accepted and unauthorized.status == &"disconnect_rejected", "client cannot invoke disconnect cleanup")
	var disconnected := integration.disconnect_peer(99)
	_check(disconnected.accepted and disconnected.status == &"disconnected", "server disconnect commits lifecycle cleanup")
	var after := integration.get_snapshot()
	_check(
		after.phase == &"disconnected"
		and not bool(after.migration_attached)
		and (after.lifecycle.peers as Array).is_empty()
		and (after.lifecycle.peer_interest as Dictionary).is_empty()
		and (after.lifecycle.seats.assignments as Array).is_empty()
		and int(after.lifecycle.ships.ships[0].owner_peer_id) == 0
		and (after.migration.peers as Array).is_empty(),
		"disconnect removes peer, interest, seat, ship, and migration ownership state"
	)
	var events: Array = after.events
	_check(
		events.size() == 4
		and events[0].kind == &"joined"
		and events[1].kind == &"rotated"
		and events[2].kind == &"rebound"
		and events[3].kind == &"disconnected",
		"lifecycle receipts preserve deterministic join/rotate/rebind/disconnect order"
	)


func _join_with_source(integration: Integration, source_peer_id: int, peer_generation: int) -> Dictionary:
	return integration.join_peer(
		source_peer_id,
		Integration.create_hello(7, peer_generation, 4, 12, 3),
		&"avatar_a",
		&"jovian_pilot",
		&"pilot",
		&"jovian_a",
		7,
		Vector3.ZERO,
		20.0,
		4,
		&"avatar_a",
		2
	)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
