extends SceneTree

## Focused production-session composition of server ship/seat authorities into
## canonical late-join records. No ENet peer or gameplay node is created.

const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")
const LifecycleAdapter := preload("res://scripts/network/network_snapshot_lifecycle_adapter.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var server := Adapter.new()
	root.add_child(server)
	server._is_server = true
	server._configured = true
	server._peer_generations[2] = 1
	server._peer_generations[3] = 2
	_check(server.register_owned_ship(&"crew_ship", 4).accepted,
		"server registers the authoritative ship generation")
	_check(server.register_crew_seat(&"pilot_seat", &"crew_ship", &"pilot", &"", 3).accepted,
		"server registers the authoritative seat generation")
	var available := server.publish_snapshot(1, [], [], [])
	var available_owner := _ownership_record(available.get("packet", {}), &"crew_ship")
	var available_seat := _boarding_record(available.get("packet", {}), &"pilot_seat")
	_check(
		available.accepted and available_owner.state == &"released"
		and int(available_owner.owner_peer_id) == 0
		and available_seat.state == &"released"
		and int(available_seat.occupant_peer_id) == 0,
		"unoccupied ship and seat publish explicit presentation tombstones"
	)

	var claimed_owner := server.claim_ship_for_peer(2, &"crew_ship", 4, 0)
	var claimed_seat := server.claim_crew_seat(2, &"avatar_a", &"pilot_seat", &"pilot", 0)
	var boarded := server.publish_snapshot(2, [], [], [])
	var boarded_owner := _ownership_record(boarded.get("packet", {}), &"crew_ship")
	var boarded_seat := _boarding_record(boarded.get("packet", {}), &"pilot_seat")
	_check(
		claimed_owner.accepted and claimed_seat.accepted and boarded.accepted
		and boarded_owner.state == &"owned" and int(boarded_owner.owner_peer_id) == 2
		and int(boarded_owner.owner_peer_generation) == 1
		and boarded_seat.state == &"boarded" and int(boarded_seat.occupant_peer_id) == 2
		and int(boarded_seat.occupant_peer_generation) == 1,
		"real ownership and seat claims enter the canonical authority envelope"
	)
	var replica := LifecycleAdapter.new(1, 1, 1, 1)
	_check(
		replica.apply_replica_snapshot(1, boarded.packet).accepted
		and replica.get_authoritative_snapshot().sections.boarding[0].state == &"boarded",
		"fresh replica receives current boarding state without replaying claims"
	)

	var transferred_owner := server.transfer_owned_ship(2, 3, &"crew_ship", 4, 1)
	var transferred_seat := server.transfer_crew_seat(2, 3, &"avatar_a", &"pilot_seat", 1, 3)
	_check(server.publish_snapshot(1, [], [], []).status == &"stale_server_tick",
		"rejected transfer publication does not commit canonical metadata")
	var transferred := server.publish_snapshot(3, [], [], [])
	var transfer_owner_record := _ownership_record(transferred.get("packet", {}), &"crew_ship")
	var transfer_seat_record := _boarding_record(transferred.get("packet", {}), &"pilot_seat")
	_check(
		transferred_owner.accepted and transferred_seat.accepted and transferred.accepted
		and transfer_owner_record.state == &"transferred"
		and int(transfer_owner_record.owner_peer_id) == 3
		and int(transfer_owner_record.owner_peer_generation) == 2
		and transfer_seat_record.state == &"transferred"
		and int(transfer_seat_record.occupant_peer_id) == 3
		and int(transfer_seat_record.occupant_peer_generation) == 2,
		"server transfer advances both canonical owner and occupant records"
	)
	_check(
		replica.apply_replica_snapshot(1, transferred.packet).accepted
		and replica.apply_replica_snapshot(1, boarded.packet).status == &"stale_snapshot",
		"replica rejects reordered pre-transfer authority"
	)

	var released_seat := server.release_crew_seat(3, &"avatar_a", &"pilot_seat", 0, 3)
	var released_owner := server.release_owned_ship(3, &"crew_ship", 4, 0)
	var released := server.publish_snapshot(4, [], [], [])
	var release_owner_record := _ownership_record(released.get("packet", {}), &"crew_ship")
	var release_seat_record := _boarding_record(released.get("packet", {}), &"pilot_seat")
	_check(
		released_seat.accepted and released_owner.accepted and released.accepted
		and release_owner_record.state == &"released"
		and int(release_owner_record.owner_peer_id) == 0
		and int(release_owner_record.owner_peer_generation) == 0
		and release_seat_record.state == &"released"
		and int(release_seat_record.occupant_peer_id) == 0
		and StringName(release_seat_record.avatar_id).is_empty(),
		"release remains explicit for late-join presentation"
	)

	_check(server.claim_ship_for_peer(2, &"crew_ship", 4, 2).accepted
		and server.claim_crew_seat(2, &"avatar_a", &"pilot_seat", &"pilot", 2).accepted,
		"fixture boards the peer again before disconnect")
	_check(server.publish_snapshot(5, [], [], []).accepted,
		"canonical cache observes the re-boarded lifecycle")
	server._on_peer_disconnected(2)
	var disconnected := server.publish_snapshot(6, [], [], [])
	var disconnected_owner := _ownership_record(disconnected.get("packet", {}), &"crew_ship")
	var disconnected_seat := _boarding_record(disconnected.get("packet", {}), &"pilot_seat")
	_check(
		disconnected.accepted and disconnected_owner.state == &"disconnected"
		and int(disconnected_owner.owner_peer_id) == 0
		and disconnected_seat.state == &"disconnected"
		and int(disconnected_seat.occupant_peer_id) == 0,
		"transport disconnect releases both real authorities before canonical publication"
	)
	var late_replica := LifecycleAdapter.new(1, 1, 1, 1)
	_check(
		late_replica.apply_replica_snapshot(1, disconnected.packet).accepted
		and late_replica.get_authoritative_snapshot().sections.ownership[0].state == &"disconnected"
		and late_replica.get_authoritative_snapshot().sections.boarding[0].state == &"disconnected",
		"late replica receives disconnect tombstones without mutating authority"
	)

	var client := Adapter.new()
	root.add_child(client)
	client._configured = true
	_check(
		client.publish_snapshot(7, [], [], []).status == &"authority_required"
		and client.claim_ship_for_peer(3, &"crew_ship", 4, 2).status == &"authority_required"
		and client.claim_crew_seat(3, &"avatar_a", &"pilot_seat", &"pilot", 2).status == &"authority_required",
		"presentation replicas cannot publish or commit ownership/seat authority"
	)
	client._configured = false
	server._configured = false
	client.queue_free()
	server.queue_free()
	await process_frame
	if _failures.is_empty():
		print("NETWORK_ENET_BOARDING_CANONICAL_SNAPSHOT_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _ownership_record(packet: Dictionary, ship_id: StringName) -> Dictionary:
	for record_variant in ((packet.get("sections", {}) as Dictionary).get("ownership", []) as Array):
		var record := record_variant as Dictionary
		if StringName(record.get("ship_id", &"")) == ship_id:
			return record
	return {}


func _boarding_record(packet: Dictionary, seat_id: StringName) -> Dictionary:
	for record_variant in ((packet.get("sections", {}) as Dictionary).get("boarding", []) as Array):
		var record := record_variant as Dictionary
		if StringName(record.get("seat_id", &"")) == seat_id:
			return record
	return {}


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
