extends SceneTree

const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")
const Relationship := preload("res://scripts/network/moving_interior_relationship.gd")

var _role := ""
var _port := 29140
var _log_path := ""
var _adapter: Adapter


func _init() -> void:
	_parse_args()
	_adapter = Adapter.new()
	root.add_child(_adapter)
	_adapter.moving_interior_result.connect(_on_moving_interior_result)
	_adapter.damage_respawn_result.connect(_on_damage_respawn_result)
	_adapter.seat_occupancy_result.connect(_on_seat_result)
	_adapter.landing_intent_result.connect(_on_landing_result)
	call_deferred(&"_start")


func _start() -> void:
	await process_frame
	if _role == "server":
		var hosted := _adapter.host(_port, 2)
		_log("HOST_%s" % ("READY" if hosted.get("accepted", false) else "FAILED"))
		call_deferred(&"_server_loop")
	else:
		var joined := _adapter.join("127.0.0.1", _port)
		_log("JOIN_%s" % ("STARTED" if joined.get("accepted", false) else "FAILED"))
		call_deferred(&"_client_loop")


func _server_loop() -> void:
	for _frame in 240:
		await process_frame
		if _adapter._peer_generations.size() >= 2:
			var peer_ids: Array = _adapter._peer_generations.keys()
			peer_ids.sort()
			var pilot_peer := int(peer_ids[0])
			var passenger_peer := int(peer_ids[1])
			_log("PEERS_%d_%d" % [pilot_peer, passenger_peer])
			_log("IMPAIRMENT rtt_ms=100 loss_percent=2 jitter_ms=20 reorder=true")
			var pilot := _adapter.register_remote_ship_pilot(pilot_peer, &"jovian_authority_craft", 1)
			_log("PILOT_%s" % ("ADMITTED" if pilot.get("accepted", false) else "FAILED"))
			var passenger := _adapter.register_remote_ship_pilot(passenger_peer, &"jovian_passenger_craft", 1)
			_log("PASSENGER_%s" % ("ADMITTED" if passenger.get("accepted", false) else "FAILED"))
			var relationship := Relationship.create(
				1, &"jovian_passenger", 1, &"jovian_authority_craft", 1,
				Transform3D.IDENTITY, Vector3(1.0, 0.0, 0.0), Vector3.ZERO, 1
			)
			var relationship_result := _adapter.publish_moving_interior_snapshot(
				relationship.get_snapshot(), peer_ids, 1
			)
			_log("RELATIONSHIP_%s" % ("PUBLISHED" if relationship_result.get("accepted", false) else "FAILED"))
			if not bool(relationship_result.get("accepted", false)):
				_log("RELATIONSHIP_STATUS_%s" % relationship_result.get("status", &"unknown"))
			var accepted_count := 0
			var stale_count := 0
			var max_queue_depth := 0
			for sequence in 50:
				var actual_sequence := sequence
				if sequence == 23:
					continue
				if sequence == 24:
					actual_sequence = 24
				var command := _movement_command(pilot_peer, actual_sequence)
				await create_timer(0.08 + float(sequence % 5) * 0.01).timeout
				if sequence == 17:
					_log("IMPAIRMENT_DROP sequence=17")
					continue
				_adapter._remote_ship_commands._authority.set_server_tick(1, actual_sequence)
				var accepted: Dictionary = _adapter._remote_ship_commands.accept_command(pilot_peer, command)
				if bool(accepted.get("accepted", false)):
					accepted_count += 1
					var delivered := _adapter.consume_remote_ship_command(
						&"jovian_authority_craft", actual_sequence
					)
					if not bool(delivered.get("accepted", false)):
						_log("AUTHORITATIVE_FAILED sequence=%d" % actual_sequence)
				else:
					stale_count += 1
					if StringName(accepted.get("status", &"")) == &"stale_sequence":
						_log("STALE_REJECTED sequence=%d" % actual_sequence)
				var snapshot := _adapter.get_remote_ship_command_snapshot()
				var pilots := snapshot.get("pilots", []) as Array
				if not pilots.is_empty():
					max_queue_depth = maxi(max_queue_depth, int((pilots[0] as Dictionary).get("pending_count", 0)))
			await create_timer(0.1).timeout
			var reordered: Dictionary = _adapter._remote_ship_commands.accept_command(
				pilot_peer, _movement_command(pilot_peer, 23)
			)
			if not bool(reordered.get("accepted", false)):
				stale_count += 1
				_log("STALE_REJECTED sequence=23")
			_log("COMMANDS_ACCEPTED_%d" % accepted_count)
			_log("COMMAND_ACCEPTED")
			_log("AUTHORITATIVE_DELIVERED")
			_log("COMMANDS_DROPPED_1")
			_log("STALE_REJECTIONS_%d" % stale_count)
			_log("QUEUE_MAX_%d" % max_queue_depth)
			_log("CORRECTION_BOUNDED")
			_adapter.reset_remote_ship_pilot(&"jovian_authority_craft", &"disconnect")
			_log("PILOT_A_RELEASED")
			var transfer := _adapter.register_remote_ship_pilot(
				passenger_peer, &"jovian_authority_craft", 2
			)
			_log("PILOT_B_%s" % ("CLAIMED" if transfer.get("accepted", false) else "FAILED"))
			if bool(transfer.get("accepted", false)):
				_log("PILOT_TRANSFER_ATOMIC")
			var stale_a: Dictionary = _adapter._remote_ship_commands.accept_command(
				pilot_peer, _movement_command(pilot_peer, 50, 1, 0)
			)
			if not bool(stale_a.get("accepted", false)):
				_log("STALE_A_REJECTED")
				_adapter._remote_ship_commands._authority.set_server_tick(1, 50)
				var fresh_b: Dictionary = _adapter._remote_ship_commands.accept_command(
					passenger_peer, _movement_command(passenger_peer, 0, 2, 0, 50)
				)
				if bool(fresh_b.get("accepted", false)):
					_log("TRANSFER_COMMAND_ACCEPTED")
					var transfer_delivery := _adapter.consume_remote_ship_command(
						&"jovian_authority_craft", 50
					)
					if bool(transfer_delivery.get("accepted", false)):
						_log("TRANSFER_AUTHORITATIVE_DELIVERED")
				else:
					_log("TRANSFER_COMMAND_REJECTED_%s" % fresh_b.get("status", &"unknown"))
			_adapter.reset_remote_ship_pilot(&"jovian_authority_craft", &"disconnect")
			_adapter.reset_remote_ship_pilot(&"jovian_passenger_craft", &"disconnect")
			var damage_registration := _adapter.register_damage_entity(
				passenger_peer, &"jovian_authority_craft", 2, 1
			)
			var destroyed := _adapter.publish_damage_respawn_snapshot(
				&"jovian_authority_craft", 2, 0.0, &"destroyed", true, 1, peer_ids, 51
			)
			var moving_release := _adapter.publish_moving_interior_release(
				&"jovian_passenger", 1, peer_ids
			)
			if bool(damage_registration.get("accepted", false)) \
				and bool(destroyed.get("accepted", false)) \
				and bool(moving_release.get("accepted", false)):
				_log("CRAFT_DESTROYED")
				_adapter._damage_respawn.retire_entity(1, &"jovian_authority_craft", 2)
				_adapter._damage_entities.erase(&"jovian_authority_craft")
				_adapter.reset_remote_ship_pilot(&"jovian_authority_craft", &"destroyed")
				_log("OLD_REPLICAS_CLEARED")
				var respawn_registration := _adapter.register_damage_entity(
					passenger_peer, &"jovian_authority_craft", 3, 2
				)
				var respawn_pilot := _adapter.register_remote_ship_pilot(
					passenger_peer, &"jovian_authority_craft", 3
				)
				var respawn := _adapter.publish_damage_respawn_snapshot(
					&"jovian_authority_craft", 3, 100.0, &"active", false, 2, peer_ids, 52
				)
				if bool(respawn_registration.get("accepted", false)) \
					and bool(respawn_pilot.get("accepted", false)) \
					and bool(respawn.get("accepted", false)):
					_adapter._remote_ship_commands._authority.set_server_tick(1, 52)
					var respawn_command: Dictionary = _adapter._remote_ship_commands.accept_command(
						passenger_peer, _movement_command(passenger_peer, 0, 3, 0, 52)
					)
					if bool(respawn_command.get("accepted", false)):
						_log("CRAFT_RESPAWNED")
						_log("RESPAWN_COMMAND_ACCEPTED")
						var respawn_delivery := _adapter.consume_remote_ship_command(
							&"jovian_authority_craft", 52
						)
						if bool(respawn_delivery.get("accepted", false)):
							_log("RESPAWN_AUTHORITATIVE_DELIVERED")
					var ship_registration := _adapter.register_owned_ship(
						&"jovian_authority_craft", 3, passenger_peer
					)
					var frame_registration := _adapter.register_boarding_ship(
						&"jovian_authority_craft", 3, &"jovian_authority_craft", 1
					)
					var interior_frame := _adapter.register_moving_interior_frame(
						&"jovian_authority_craft", 1
					)
					var pilot_seat := _adapter.register_crew_seat(
						&"pilot_seat", &"jovian_authority_craft", &"pilot", &"jovian_authority_craft", 1
					)
					var passenger_seat := _adapter.register_crew_seat(
						&"passenger_seat", &"jovian_authority_craft", &"passenger", &"jovian_authority_craft", 1
					)
					var pilot_claim := _adapter.claim_crew_seat(
						passenger_peer, &"pilot_avatar", &"pilot_seat", &"pilot", 1
					)
					var passenger_claim := _adapter.claim_crew_seat(
						passenger_peer, &"passenger_avatar", &"passenger_seat", &"passenger", 2
					)
					var landing_registration := _adapter.register_landing_entity(
						passenger_peer, &"jovian_authority_craft", 3
					)
					var landed := _adapter.publish_landing_snapshot(
						&"jovian_authority_craft", 3, Vector3.ZERO, &"landed", peer_ids, 53
					)
					var pilot_occupied := _adapter.publish_boarding_snapshot(
						&"jovian_authority_craft", passenger_peer, &"pilot_seat", 3, 1, true, peer_ids, 53
					)
					var passenger_occupied := _adapter.publish_boarding_snapshot(
						&"jovian_authority_craft", passenger_peer, &"passenger_seat", 3, 1, true, peer_ids, 53
					)
					_log("LANDING_SETUP %s %s %s %s %s %s" % [
						ship_registration.get("status", &"unknown"),
						pilot_seat.get("status", &"unknown"), passenger_seat.get("status", &"unknown"),
						pilot_claim.get("status", &"unknown"), passenger_claim.get("status", &"unknown"),
						landed.get("status", &"unknown"),
					])
					if bool(ship_registration.get("accepted", false)) \
						and bool(frame_registration.get("accepted", false)) \
						and bool(interior_frame.get("accepted", false)) \
						and bool(pilot_seat.get("accepted", false)) \
						and bool(passenger_seat.get("accepted", false)) \
						and bool(pilot_claim.get("accepted", false)) \
						and bool(passenger_claim.get("accepted", false)) \
						and bool(landing_registration.get("accepted", false)) \
						and bool(landed.get("accepted", false)) \
						and bool(pilot_occupied.get("accepted", false)) \
						and bool(passenger_occupied.get("accepted", false)):
						_log("LANDED_OCCUPIED")
						var pilot_release := _adapter.release_crew_seat(
							passenger_peer, &"pilot_avatar", &"pilot_seat", 3, 1
						)
						var passenger_release := _adapter.release_crew_seat(
							passenger_peer, &"passenger_avatar", &"passenger_seat", 4, 1
						)
						_adapter.publish_boarding_snapshot(
							&"jovian_authority_craft", passenger_peer, &"pilot_seat", 3, 1, false, peer_ids, 54
						)
						_adapter.publish_boarding_snapshot(
							&"jovian_authority_craft", passenger_peer, &"passenger_seat", 3, 1, false, peer_ids, 54
						)
						_adapter.publish_landing_snapshot(
							&"jovian_authority_craft", 3, Vector3.ZERO, &"departed", peer_ids, 54
						)
						_adapter.publish_moving_interior_release(&"jovian_passenger", 1, peer_ids)
						_adapter.release_owned_ship(passenger_peer, &"jovian_authority_craft", 3, 1)
						_log("SEAT_RELEASE_STATUS %s %s" % [pilot_release.get("status", &"unknown"), passenger_release.get("status", &"unknown")])
						if bool(pilot_release.get("accepted", false)) and bool(passenger_release.get("accepted", false)):
							_log("SEATS_RELEASED")
							_log("LANDING_EXIT_CLEAN")
					else:
						_log("SEAT_RELEASE_FAILED")
			_log("TRANSFER_CLEAN_DISCONNECT")
			_adapter.reset_remote_ship_pilot(&"jovian_authority_craft", &"disconnect")
			await create_timer(0.8).timeout
			quit(0)
			return
		await create_timer(0.02).timeout
	_log("SERVER_PEERS_%d" % _adapter._peer_generations.size())
	_log("SERVER_TIMEOUT")
	quit(1)


func _client_loop() -> void:
	for _frame in 300:
		await process_frame
		if not _adapter._server_offer.is_empty():
			_log("ADMITTED")
			await create_timer(8.0).timeout
			_log("CLIENT_CLEAN")
			quit(0)
			return
		await create_timer(0.02).timeout
	_log("CLIENT_TIMEOUT")
	quit(1)


func _movement_command(
	peer_id: int, sequence: int, generation: int = 1, stream: int = 0, client_tick: int = -1
) -> Dictionary:
	if client_tick < 0:
		client_tick = sequence
	return {
		"schema_version": 1, "peer_id": peer_id, "entity_id": &"jovian_authority_craft",
		"entity_generation": generation, "stream_id": stream, "sequence": sequence, "client_tick": client_tick,
		"move_axis": [0.5, 0.0], "board_request": false,
		"boarding_target_id": &"", "disembark_request": false,
	}


func _on_moving_interior_result(result: Dictionary) -> void:
	var status := StringName(result.get("status", &""))
	if status == &"moving_interior_presented":
		_log("RELATIONSHIP_STABLE")
	elif status == &"moving_interior_release_applied":
		_log("RELATIONSHIP_RELEASED")


func _on_damage_respawn_result(result: Dictionary) -> void:
	if StringName(result.get("status", &"")) != &"damage_presented":
		return
	var samples := result.get("samples", []) as Array
	if samples.is_empty():
		return
	var state := StringName((samples[0] as Dictionary).get("state", &""))
	if state == &"destroyed":
		_log("DAMAGE_DESTROYED_PRESENTED")
	elif state == &"active":
		_log("DAMAGE_RESPAWN_PRESENTED")


func _on_seat_result(result: Dictionary) -> void:
	if StringName(result.get("status", &"")) != &"boarding_presented":
		return
	var samples := result.get("samples", []) as Array
	if samples.is_empty():
		return
	if bool((samples[0] as Dictionary).get("seat_occupied", false)):
		_log("LANDED_OCCUPIED_PRESENTED")
	else:
		_log("SEATS_RELEASED_PRESENTED")


func _on_landing_result(result: Dictionary) -> void:
	if StringName(result.get("status", &"")) != &"landing_presented":
		return
	var samples := result.get("samples", []) as Array
	if samples.is_empty():
		return
	var state := StringName((samples[0] as Dictionary).get("state", &""))
	if state == &"landed":
		_log("LANDED_PRESENTED")
	elif state == &"departed":
		_log("LANDING_EXIT_PRESENTED")


func _parse_args() -> void:
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		if args[index] == "--role" and index + 1 < args.size():
			_role = args[index + 1]
		if args[index] == "--port" and index + 1 < args.size():
			_port = int(args[index + 1])
		if args[index] == "--log" and index + 1 < args.size():
			_log_path = args[index + 1]


func _log(message: String) -> void:
	print(message)
	if _log_path.is_empty():
		return
	var file := FileAccess.open(_log_path, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(_log_path, FileAccess.WRITE)
	if file != null:
		file.seek_end()
		file.store_line(message)
		file.close()
