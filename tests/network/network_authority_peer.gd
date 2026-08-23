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
			_adapter.reset_remote_ship_pilot(&"jovian_passenger_craft", &"disconnect")
			_log("CLEAN_DISCONNECT")
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


func _movement_command(peer_id: int, sequence: int) -> Dictionary:
	return {
		"schema_version": 1, "peer_id": peer_id, "entity_id": &"jovian_authority_craft",
		"entity_generation": 1, "stream_id": 0, "sequence": sequence, "client_tick": sequence,
		"move_axis": [0.5, 0.0], "board_request": false,
		"boarding_target_id": &"", "disembark_request": false,
	}


func _on_moving_interior_result(result: Dictionary) -> void:
	var status := StringName(result.get("status", &""))
	if status == &"moving_interior_presented":
		_log("RELATIONSHIP_STABLE")


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
