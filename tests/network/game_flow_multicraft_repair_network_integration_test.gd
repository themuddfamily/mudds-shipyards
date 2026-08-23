extends SceneTree

## One focused composition harness for the shared Halyard/Jovian/Bulwark
## repair-network contract. Craft-local repair authorities remain mutation
## owners; GameFlow sees only their detached signal/snapshot projection.

const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")
const GameFlow := preload("res://scripts/game/game_flow.gd")
const LifecycleAdapter := preload("res://scripts/network/network_snapshot_lifecycle_adapter.gd")
const Halyard := preload("res://scripts/ships/halyard_crew_transport.gd")
const Jovian := preload("res://scripts/ships/jovian_light_freighter.gd")
const Bulwark := preload("res://scripts/ships/bulwark_heavy_gunship.gd")

const CRAFTS := [
	{&"id": &"halyard_new_design", &"peer_id": 7, &"peer_generation": 3},
	{&"id": &"jovian_provisional", &"peer_id": 8, &"peer_generation": 4},
	{&"id": &"bulwark_heavy_gunship", &"peer_id": 9, &"peer_generation": 5},
]

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var server := Adapter.new()
	root.add_child(server)
	server._is_server = true
	server._configured = true
	for row in CRAFTS:
		server._peer_generations[int(row.peer_id)] = int(row.peer_generation)
		_check(
			server.register_damage_entity(1, row.id, 1, 4).accepted
			and server.publish_damage_respawn_snapshot(
				row.id, 1, 120.0, &"damaged", false, 0, [],
				10 + int(row.peer_id), _component_summary()
			).accepted,
			"%s enters the existing damage lifecycle" % row.id
		)
	var flow := GameFlow.new()
	flow.network_session = server
	flow._network_session_mode = &"server"
	flow._network_damage_server_tick = 20
	var halyard := Halyard.new()
	var jovian := Jovian.new()
	var bulwark := Bulwark.new()
	var ships: Array[HeroShip] = [halyard, jovian, bulwark]
	for index in ships.size():
		var ship := ships[index]
		var row: Dictionary = CRAFTS[index]
		ship.ship_id = row.id
		_configure_owner(ship, int(row.peer_id), index + 2)
		flow._network_damage_entities[row.id] = 1
		flow._connect_flyable_ship_signals(ship)

	_publish_state(halyard, &"repairing", 0.0, 1, &"requested")
	_publish_state(halyard, &"repairing", 0.5, 1, &"requested")
	_publish_state(halyard, &"completed", 1.0, 1, &"committed", 11)
	_publish_state(jovian, &"repairing", 0.0, 1, &"requested")
	_publish_state(jovian, &"repairing", 0.4, 1, &"requested")
	_publish_state(jovian, &"interrupted", 0.4, 1, &"left_berth")
	_publish_state(bulwark, &"repairing", 0.0, 1, &"requested")
	_publish_state(bulwark, &"repairing", 0.75, 1, &"requested")
	_publish_state(bulwark, &"completed", 1.0, 1, &"committed", 13)
	var packet := server.get_authoritative_snapshot()
	var halyard_repair := _repair_record(packet, &"halyard_new_design")
	var jovian_repair := _repair_record(packet, &"jovian_provisional")
	var bulwark_repair := _repair_record(packet, &"bulwark_heavy_gunship")
	_check(
		halyard_repair.state == &"completed" and halyard_repair.terminal
		and int(halyard_repair.owner_peer_id) == 7
		and int(halyard_repair.owner_peer_generation) == 3
		and int(halyard_repair.receipt_operation_sequence) == 11,
		"Halyard remains on the shared completed lifecycle path"
	)
	_check(
		jovian_repair.state == &"aborted" and jovian_repair.terminal
		and int(jovian_repair.owner_peer_id) == 8
		and int(jovian_repair.owner_peer_generation) == 4
		and jovian_repair.receipt_status == &"left_berth",
		"Jovian publishes the authoritative aborted engineer lifecycle"
	)
	_check(
		bulwark_repair.state == &"completed" and bulwark_repair.terminal
		and int(bulwark_repair.owner_peer_id) == 9
		and int(bulwark_repair.owner_peer_generation) == 5
		and int(bulwark_repair.receipt_operation_sequence) == 13,
		"Bulwark publishes the authoritative completed engineer lifecycle"
	)
	_check(
		int(halyard_repair.repair_generation) == 1
		and int(jovian_repair.repair_generation) == 1
		and int(bulwark_repair.repair_generation) == 1
		and int(halyard_repair.repair_sequence) == 3
		and int(jovian_repair.repair_sequence) == 3
		and int(bulwark_repair.repair_sequence) == 3,
		"each craft keeps an independent generation/sequence fence in one damage row"
	)
	_check(
		is_equal_approx(float(_damage_record(packet, &"halyard_new_design").engine_power), 0.6)
		and is_equal_approx(float(_damage_record(packet, &"jovian_provisional").engine_power), 0.6)
		and is_equal_approx(float(_damage_record(packet, &"bulwark_heavy_gunship").engine_power), 0.6),
		"repair publication preserves each craft's existing component-damage summary"
	)
	var late_replica := LifecycleAdapter.new(1, 1, 1, 1)
	_check(
		late_replica.apply_replica_snapshot(1, packet).accepted
		and _repair_record(
			late_replica.get_authoritative_snapshot(), &"jovian_provisional"
		).state == &"aborted"
		and _repair_record(
			late_replica.get_authoritative_snapshot(), &"bulwark_heavy_gunship"
		).state == &"completed",
		"late join receives all current multi-craft repair tombstones"
	)

	var client := Adapter.new()
	root.add_child(client)
	client._configured = true
	var client_flow := GameFlow.new()
	client_flow.network_session = client
	client_flow._network_session_mode = &"client"
	var client_jovian := Jovian.new()
	client_jovian.ship_id = &"jovian_provisional"
	_configure_owner(client_jovian, 8, 3)
	client_flow._connect_flyable_ship_signals(client_jovian)
	_publish_state(client_jovian, &"repairing", 0.0, 1, &"requested")
	_check(
		int(client.get_authoritative_snapshot().get("revision", 0)) == 0,
		"Jovian client callback remains presentation-only"
	)
	var solo_flow := GameFlow.new()
	var solo_bulwark := Bulwark.new()
	solo_bulwark.ship_id = &"bulwark_heavy_gunship"
	_configure_owner(solo_bulwark, 9, 4)
	solo_flow._connect_flyable_ship_signals(solo_bulwark)
	_publish_state(solo_bulwark, &"repairing", 0.25, 1, &"requested")
	_check(
		is_equal_approx(
			float(solo_bulwark.get_engineer_repair_state().get("progress", 0.0)), 0.25
		),
		"Bulwark solo repair state is unchanged by the optional network seam"
	)

	client._configured = false
	server._configured = false
	client.queue_free()
	server.queue_free()
	for ship in ships:
		ship.free()
	client_jovian.free()
	solo_bulwark.free()
	flow.free()
	client_flow.free()
	solo_flow.free()
	await process_frame
	if _failures.is_empty():
		print("GAME_FLOW_MULTICRAFT_REPAIR_NETWORK_INTEGRATION_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _configure_owner(ship: HeroShip, peer_id: int, seat_generation: int) -> void:
	ship.set("_engineer_component_selection", {
		"component_id": &"engine_bay",
		"component_generation": 4,
		"occupant_peer_id": peer_id,
		"avatar_id": StringName("engineer_%d" % peer_id),
		"seat_generation": seat_generation,
		"request_sequence": 1,
	})


func _publish_state(
	ship: HeroShip,
	status: StringName,
	progress: float,
	token: int,
	reason: StringName,
	operation_sequence: int = 0
) -> void:
	var receipt := {
		"accepted": true,
		"reason": reason,
		"token": token,
	}
	if operation_sequence > 0:
		receipt["operation"] = {"generation": 4, "sequence": operation_sequence}
	ship.call("_set_engineer_repair_state", {
		"status": status,
		"reason": reason,
		"component_id": &"engine_bay",
		"component_generation": 4,
		"progress": progress,
		"token": token,
		"receipt": receipt,
	})


func _component_summary() -> Dictionary:
	return {
		"maximum_health": 190.0,
		"engine_power": 0.6,
		"weapon_power": 0.8,
		"targeting_power": 0.9,
		"engine_disabled": false,
		"weapon_disabled": false,
		"targeting_disabled": false,
	}


func _damage_record(packet: Dictionary, entity_id: StringName) -> Dictionary:
	for record_variant in ((packet.get("sections", {}) as Dictionary).get("respawn", []) as Array):
		var record := record_variant as Dictionary
		if StringName(record.get("entity_id", &"")) == entity_id:
			return record
	return {}


func _repair_record(packet: Dictionary, entity_id: StringName) -> Dictionary:
	return (_damage_record(packet, entity_id).get("repair", {}) as Dictionary).duplicate(true)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
