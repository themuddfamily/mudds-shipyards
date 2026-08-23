extends SceneTree

const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")

var _role := ""
var _port := 29140
var _log_path := ""
var _adapter: Adapter


func _init() -> void:
	_parse_args()
	_adapter = Adapter.new()
	root.add_child(_adapter)
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
			var pilot := _adapter.register_remote_ship_pilot(2, &"jovian_authority_craft", 1)
			_log("PILOT_%s" % ("ADMITTED" if pilot.get("accepted", false) else "FAILED"))
			var passenger := _adapter.register_remote_ship_pilot(3, &"jovian_passenger_craft", 1)
			_log("PASSENGER_%s" % ("ADMITTED" if passenger.get("accepted", false) else "FAILED"))
			var command := {
				"schema_version": 1, "peer_id": 2, "entity_id": &"jovian_authority_craft",
				"entity_generation": 1, "stream_id": 0, "sequence": 0, "client_tick": 1,
				"move_axis": [0.5, 0.0], "board_request": false,
				"boarding_target_id": &"", "disembark_request": false,
			}
			var accepted: Dictionary = _adapter._remote_ship_commands.accept_command(2, command)
			_log("COMMAND_%s" % ("ACCEPTED" if accepted.get("accepted", false) else "FAILED"))
			var delivered := _adapter.consume_remote_ship_command(&"jovian_authority_craft", 1)
			_log("AUTHORITATIVE_%s" % ("DELIVERED" if delivered.get("accepted", false) else "FAILED"))
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
			await create_timer(3.0).timeout
			_log("CLIENT_CLEAN")
			quit(0)
			return
		await create_timer(0.02).timeout
	_log("CLIENT_TIMEOUT")
	quit(1)


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
