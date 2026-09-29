extends SceneTree

## Planet visits are solo exploration. Aurora and Rime already refused to
## launch while a session was up ("SOLO EXPLORATION ONLY"), but the Ember
## cruise and the Ember surface journey did not: a host with clients connected
## could fly to Ember. That cruise commits the common-world origin rebase,
## which translates the host's whole world -- station, fleet, player -- by
## kilometres. No peer shares that frame, so every craft pose and body the
## host kept publishing arrived on its clients displaced by the rebase delta,
## and clients' own ships were carried off the station with it.
##
## The least surprising safe rule is the one Aurora and Rime already follow:
##   A. while a session is up, the Ember cruise and the Ember surface journey
##      are refused with the same public copy, SOLO EXPLORATION ONLY;
##   B. while a cruise is engaged, neither a host nor a join is started;
##   C. once the session closes, the cruise is available again.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const Store := preload("res://scripts/persistence/user_data_store.gd")
const STORE_PATH := "memory://network-planetary-visit-gate-settings.json"

var _assertions := 0
var _failures: Array[String] = []


class MemoryFilesystem extends UserDataFilesystem:
	var files: Dictionary = {}
	func file_exists(path: String) -> bool: return files.has(path)
	func directory_exists(_path: String) -> bool: return false
	func ensure_parent_directory(_path: String) -> Error: return OK
	func read_bytes(path: String, maximum_bytes: int) -> Dictionary:
		if not files.has(path): return {"error": ERR_FILE_NOT_FOUND, "bytes": PackedByteArray()}
		var bytes := (files[path] as PackedByteArray).duplicate()
		return {"error": OK if bytes.size() <= maximum_bytes else ERR_FILE_CORRUPT, "bytes": bytes}
	func write_bytes_and_flush(path: String, bytes: PackedByteArray) -> Error:
		files[path] = bytes.duplicate(); return OK
	func remove_path(path: String) -> Error:
		if not files.has(path): return ERR_FILE_NOT_FOUND
		files.erase(path); return OK
	func rename_path(from_path: String, to_path: String) -> Error:
		if not files.has(from_path): return ERR_FILE_NOT_FOUND
		if files.has(to_path): return ERR_ALREADY_EXISTS
		files[to_path] = (files[from_path] as PackedByteArray).duplicate(); files.erase(from_path); return OK


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "production Main instantiates")
	if game == null:
		_finish(); return
	var store := Store.new(STORE_PATH, MemoryFilesystem.new()) as UserDataStore
	_check(game.configure_runtime_settings_persistence(store, "memory://network-visit-gate-legacy.cfg"),
		"settings persistence is isolated")
	root.add_child(game)
	set_multiplayer(SceneMultiplayer.new(), game.get_path())
	await process_frame
	await physics_frame
	await process_frame
	var binding := game.planetary_cruise_binding
	var ship := game.get_active_ship()
	_check(binding != null and ship != null, "Main resolves its cruise binding and active ship")
	if binding == null or ship == null:
		await _cleanup(game); _finish(); return
	# A pilot seated in free flight, clear of the yard: every solo cruise gate open.
	game.set_physics_process(false)
	for fleet_ship in game.get_flyable_ships():
		fleet_ship.set_physics_process(false)
	ship.global_position = Vector3(0.0, 5_000.0, 0.0)
	ship.velocity = Vector3.ZERO
	ship.set_piloted(true)
	game.set("_piloting", true)
	game.set("_sortie_departed_berth", true)
	game.phase = GameFlow.Phase.FREE_FLIGHT
	_check(game._planetary_cruise_gate_reason() == &"",
		"solo, the seated pilot may cruise to Ember")

	# --- A: a live session refuses the Ember cruise and surface journey ------
	var port := _reserve_loopback_port()
	_check(bool(game.host_network_session(port, 2).get("accepted", false)), "the pilot hosts a session")
	var engaged := game.engage_planetary_cruise()
	_check(not bool(engaged.get("accepted", false)) and engaged.get("reason") == &"network_session_active",
		"a host may not cruise to Ember while the session is up (got %s)" % engaged.get("reason"))
	_check(not bool(binding.get_snapshot().get("engagement_requested", false)),
		"the refused cruise leaves the binding disengaged")
	var journey := game._begin_player_ember_surface_journey(1)
	_check(not bool(journey.get("accepted", false)) and journey.get("reason") == &"network_session_active",
		"a host may not start the Ember surface journey while the session is up (got %s)" % journey.get("reason"))
	var presentation := game._planetary_cruise_presentation()
	_check(not bool(presentation.get("toggle_enabled", true))
			and str(presentation.get("status_text", "")).contains("SOLO EXPLORATION ONLY"),
		"the cruise HUD says why, in Aurora's and Rime's words (got '%s')" % presentation.get("status_text"))
	game.shutdown_network_session(&"test_leave")

	# --- C: closing the session gives the cruise back -------------------------
	_check(game._planetary_cruise_gate_reason() == &"",
		"with the session closed the cruise is available again (got %s)" % game._planetary_cruise_gate_reason())
	engaged = game.engage_planetary_cruise()
	_check(bool(engaged.get("accepted", false)) and bool(binding.get_snapshot().get("engagement_requested", false)),
		"the solo pilot engages the Ember cruise")

	# --- B: an engaged cruise refuses a new host or join ----------------------
	var hosted := game.host_network_session(_reserve_loopback_port(), 2)
	_check(not bool(hosted.get("accepted", false)) and hosted.get("status") == &"planetary_visit_active",
		"hosting is refused while the Ember cruise is engaged (got %s)" % hosted.get("status"))
	_check(game._network_session_mode == &"" and not game._network_session_is_live(),
		"the refused host leaves no session and no role")
	var joined := game.join_network_session("127.0.0.1", _reserve_loopback_port())
	_check(not bool(joined.get("accepted", false)) and joined.get("status") == &"planetary_visit_active",
		"joining is refused while the Ember cruise is engaged (got %s)" % joined.get("status"))
	game._handle_server_browser_intent({"action": &"manual_join", "address": "127.0.0.1", "port": 7777})
	_check(game._network_session_mode == &"" and not game._network_session_is_live(),
		"a browser manual join is refused while the Ember cruise is engaged")
	game.disengage_planetary_cruise(false)
	await _cleanup(game)
	_finish()


func _reserve_loopback_port() -> int:
	var probe := UDPServer.new()
	if probe.listen(0, "127.0.0.1") != OK:
		_check(false, "reserve a loopback UDP port")
		return 0
	var port := probe.get_local_port()
	probe.stop()
	return port


func _cleanup(game: GameFlow) -> void:
	if is_instance_valid(game):
		if game._network_session_is_live():
			game.shutdown_network_session(&"test_complete")
		game.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("NETWORK_PLANETARY_VISIT_SESSION_GATE_TEST_OK: %d assertions" % _assertions)
		quit(0); return
	for failure in _failures:
		push_error("FAIL: %s" % failure)
	quit(1)
