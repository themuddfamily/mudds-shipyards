extends SceneTree

## Focused production composition test: Halyard's existing repair-state signal
## drives GameFlow, the server adapter projects its receipts into the canonical
## damage row, and replicas retain presentation only.

const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")
const GameFlow := preload("res://scripts/game/game_flow.gd")
const LifecycleAdapter := preload("res://scripts/network/network_snapshot_lifecycle_adapter.gd")


class RepairHero:
	extends HeroShip

	signal engineer_repair_state_changed(snapshot: Dictionary)

	var crew_snapshot: Dictionary = {}


	func get_crew_role_gameplay_snapshot() -> Dictionary:
		return crew_snapshot.duplicate(true)


var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var server := Adapter.new()
	root.add_child(server)
	server._is_server = true
	server._configured = true
	server._peer_generations[7] = 3
	_check(
		server.register_damage_entity(1, &"halyard_new_design", 1, 4).accepted
		and server.publish_damage_respawn_snapshot(
			&"halyard_new_design", 1, 140.0, &"damaged", false, 0, [], 10,
			_component_summary()
		).accepted,
		"server establishes the Halyard damage/component generation"
	)
	var ship := RepairHero.new()
	ship.ship_id = &"halyard_new_design"
	ship.crew_snapshot = _crew_snapshot()
	var flow := GameFlow.new()
	flow.network_session = server
	flow._network_session_mode = &"server"
	flow._network_damage_entities[&"halyard_new_design"] = 1
	flow._network_damage_server_tick = 10
	flow._connect_flyable_ship_signals(ship)

	ship.engineer_repair_state_changed.emit(_repair_state(
		&"repairing", 0.0, 1, {"accepted": true, "reason": &"requested", "token": 1}
	))
	var started_packet := server.get_authoritative_snapshot()
	var started := _repair_record(started_packet)
	_check(
		started.get("state") == &"started"
		and int(started.get("repair_generation", 0)) == 1
		and int(started.get("repair_sequence", 0)) == 1
		and int(started.get("owner_peer_id", 0)) == 7
		and int(started.get("owner_peer_generation", 0)) == 3
		and int(started.get("receipt_token", -1)) == 1,
		"the real GameFlow signal caller publishes the authority-issued start receipt"
	)

	ship.engineer_repair_state_changed.emit(_repair_state(
		&"repairing", 0.5, 1, {"accepted": true, "reason": &"requested", "token": 1}
	))
	var progress_packet := server.get_authoritative_snapshot()
	var progress := _repair_record(progress_packet)
	_check(
		progress.get("state") == &"progress"
		and is_equal_approx(float(progress.get("progress", 0.0)), 0.5)
		and int(progress.get("repair_generation", 0)) == 1
		and int(progress.get("repair_sequence", 0)) == 2,
		"repair progress advances one sequence without creating another lifecycle"
	)
	var replica := LifecycleAdapter.new(1, 1, 1, 1)
	_check(
		replica.apply_replica_snapshot(1, started_packet).accepted
		and replica.apply_replica_snapshot(1, progress_packet).accepted,
		"replica accepts ordered canonical repair presentation"
	)
	var forged_stale := started_packet.duplicate(true)
	forged_stale["server_tick"] = int(progress_packet.get("server_tick", 0))
	forged_stale["event_sequence"] = int(progress_packet.get("event_sequence", 0)) + 1
	forged_stale["revision"] = int(progress_packet.get("revision", 0)) + 1
	var stale_damage := _damage_record(forged_stale)
	var current_damage := _damage_record(progress_packet)
	stale_damage["damage_revision"] = int(current_damage.get("damage_revision", 0)) + 1
	stale_damage["damage_server_tick"] = int(current_damage.get("damage_server_tick", 0))
	_check(
		replica.apply_replica_snapshot(1, forged_stale).status == &"stale_repair_sequence",
		"a newer envelope cannot reorder an older repair sequence"
	)

	ship.engineer_repair_state_changed.emit(_repair_state(
		&"completed", 1.0, 1,
		{
			"accepted": true,
			"reason": &"committed",
			"token": 1,
			"operation": {"generation": 4, "sequence": 6},
		}
	))
	var completed_packet := server.get_authoritative_snapshot()
	var completed := _repair_record(completed_packet)
	_check(
		completed.get("state") == &"completed" and bool(completed.get("terminal", false))
		and int(completed.get("receipt_operation_generation", 0)) == 4
		and int(completed.get("receipt_operation_sequence", 0)) == 6,
		"completion publishes bounded fields from the committed repair receipt"
	)

	ship.engineer_repair_state_changed.emit(_repair_state(
		&"repairing", 0.0, 2, {"accepted": true, "reason": &"requested", "token": 2}
	))
	ship.engineer_repair_state_changed.emit(_repair_state(
		&"repairing", 0.3, 2, {"accepted": true, "reason": &"requested", "token": 2}
	))
	ship.engineer_repair_state_changed.emit(_repair_state(
		&"interrupted", 0.3, 2, {"accepted": true, "reason": &"left_berth"}
	))
	var aborted_packet := server.get_authoritative_snapshot()
	var aborted := _repair_record(aborted_packet)
	_check(
		aborted.get("state") == &"aborted" and bool(aborted.get("terminal", false))
		and int(aborted.get("repair_generation", 0)) == 2
		and aborted.get("receipt_status") == &"left_berth"
		and (_damage_record(aborted_packet).get("repair", {}) as Dictionary).size() > 0,
		"abort retires the second lifecycle in the same single bounded damage row"
	)
	var late_replica := LifecycleAdapter.new(1, 1, 1, 1)
	_check(
		late_replica.apply_replica_snapshot(1, aborted_packet).accepted
		and _repair_record(late_replica.get_authoritative_snapshot()).get("state") == &"aborted",
		"late join receives the current terminal repair lifecycle without replaying repair"
	)

	var client := Adapter.new()
	root.add_child(client)
	client._configured = true
	var client_flow := GameFlow.new()
	var client_ship := RepairHero.new()
	client_ship.ship_id = &"halyard_new_design"
	client_ship.crew_snapshot = _crew_snapshot()
	client_flow.network_session = client
	client_flow._network_session_mode = &"client"
	client_flow._connect_flyable_ship_signals(client_ship)
	client_ship.engineer_repair_state_changed.emit(_repair_state(
		&"repairing", 0.0, 1, {"accepted": true, "reason": &"requested", "token": 1}
	))
	var client_authoritative := client.get_authoritative_snapshot()
	_check(
		int(client_authoritative.get("revision", 0)) == 0
		and ((client_authoritative.get("sections", {}) as Dictionary).get(
			&"respawn", []
		) as Array).is_empty()
		and client.publish_repair_lifecycle_snapshot(
			&"halyard_new_design", 1, {}, 1
		).status == &"authority_required",
		"client presentation cannot publish or commit repair authority"
	)
	var solo_flow := GameFlow.new()
	var solo_ship := RepairHero.new()
	solo_ship.ship_id = &"halyard_new_design"
	solo_flow._connect_flyable_ship_signals(solo_ship)
	var solo_state := _repair_state(
		&"repairing", 0.25, 3, {"accepted": true, "reason": &"requested", "token": 3}
	)
	solo_ship.engineer_repair_state_changed.emit(solo_state)
	_check(
		is_equal_approx(float(solo_state.get("progress", 0.0)), 0.25),
		"solo repair presentation remains a no-op at the network seam"
	)

	client._configured = false
	server._configured = false
	client.queue_free()
	server.queue_free()
	ship.free()
	client_ship.free()
	solo_ship.free()
	flow.free()
	client_flow.free()
	solo_flow.free()
	await process_frame
	if _failures.is_empty():
		print("GAME_FLOW_HALYARD_REPAIR_NETWORK_INTEGRATION_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _crew_snapshot() -> Dictionary:
	return {
		"selected_targets": {
			"engineer": {
				"component_id": &"engine_bay",
				"component_generation": 1,
				"occupant_peer_id": 7,
				"avatar_id": &"engineer_7",
			},
		},
		"occupants": [{
			"occupant_peer_id": 7,
			"avatar_id": &"engineer_7",
			"seat_id": &"crew_port_01",
			"seat_generation": 2,
			"role": &"engineer",
		}],
	}


func _repair_state(
	status: StringName,
	progress: float,
	token: int,
	receipt: Dictionary
) -> Dictionary:
	return {
		"status": status,
		"reason": receipt.get("reason", &""),
		"component_id": &"engine_bay",
		"component_generation": 4,
		"progress": progress,
		"token": token,
		"receipt": receipt.duplicate(true),
	}


func _component_summary() -> Dictionary:
	return {
		"maximum_health": 190.0,
		"engine_power": 0.65,
		"weapon_power": 1.0,
		"targeting_power": 1.0,
		"engine_disabled": false,
		"weapon_disabled": false,
		"targeting_disabled": false,
	}


func _damage_record(packet: Dictionary) -> Dictionary:
	for record_variant in ((packet.get("sections", {}) as Dictionary).get("respawn", []) as Array):
		var record := record_variant as Dictionary
		if StringName(record.get("entity_id", &"")) == &"halyard_new_design":
			return record
	return {}


func _repair_record(packet: Dictionary) -> Dictionary:
	return (_damage_record(packet).get("repair", {}) as Dictionary).duplicate(true)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
