extends SceneTree

## Focused observer contract only: no flight, landing or journey qualification.
const MAIN_SCENE := preload("res://scenes/main.tscn")
const Observer := preload("res://scripts/diagnostics/native_sortie_observer.gd")
const Store := preload("res://scripts/persistence/user_data_store.gd")


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
		files[path] = bytes.duplicate()
		return OK
	func remove_path(path: String) -> Error:
		if not files.has(path): return ERR_FILE_NOT_FOUND
		files.erase(path)
		return OK
	func rename_path(from_path: String, to_path: String) -> Error:
		if not files.has(from_path): return ERR_FILE_NOT_FOUND
		if files.has(to_path): return ERR_ALREADY_EXISTS
		files[to_path] = files[from_path]
		files.erase(from_path)
		return OK


class BootOwner extends Node:
	var main: Node
	func get_main() -> Node: return main
	func get_loading_screen() -> Node: return null


var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var filesystem := MemoryFilesystem.new()
	var store := Store.new("memory://native-ember-observer.json", filesystem)
	var game := MAIN_SCENE.instantiate() as GameFlow
	game.configure_runtime_settings_persistence(store, "memory://native-ember-legacy.cfg")
	var owner := BootOwner.new()
	owner.main = game
	root.add_child(owner)
	owner.add_child(game)
	for _frame in 240:
		await process_frame
		await physics_frame
		if bool(game.get("_initialized")):
			break
	_check(bool(game.get("_initialized")), "production Main genuinely initializes")
	if not bool(game.get("_initialized")):
		owner.free()
		_finish()
		return
	game.process_mode = Node.PROCESS_MODE_DISABLED
	var observer := Observer.new()
	observer.set("_ember", true)
	observer.process_mode = Node.PROCESS_MODE_DISABLED
	owner.add_child(observer)
	observer.on_startup_completed(game)
	_check(observer.get("_ship") == null and observer.get("_player") == null,
		"Ember startup skips legacy Torrent and retained player setup")
	var before := _observed_state(game, store, filesystem)
	var observed: Dictionary = observer.call("_ember_observation")
	_check(observed.mode == "ember" and observed.main_current and observed.world_available and observed.actors_available,
		"Ember emits the current production Main and live actors")
	_check(observed.ship.instance_id == game.active_ship.get_instance_id()
		and observed.ship.definition_id == str(game.active_ship.get_ship_id())
		and observed.player.instance_id == game.player.get_instance_id()
		and observed.ship.position == _v(game.active_ship.global_position)
		and observed.player.position == _v(game.player.global_position),
		"identity and common-world poses come from the actual current actors")
	_check(observed.world_origin_transaction_count == game.common_world_origin_rebase_owner.get_snapshot().transaction_count
		and observed.ember.abandon == game.ember_surface_loop_host.get_abandon_snapshot()
		and observed.ember.host.phase_id == str(game.ember_surface_loop_host.get_return_status_snapshot().phase_id),
		"origin, Host and abandon use existing production snapshot values")
	_check(not observed.ember.loaded and observed.ember.loaded_instance_id == 0,
		"distant Ember safely reports unloaded without creating a world")
	_check(not observed.home.is_empty() and observed.home.berth_id == str(game.active_ship.get_home_berth_id()),
		"home observations use this active craft's physical berth")
	for _sample in 3:
		observer.call("_ember_observation")
	_check(_observed_state(game, store, filesystem) == before,
		"repeated observation preserves poses, owners, leases, Host, origin, nodes, inputs and save state")
	var original := game.active_ship
	var alternate: HeroShip
	for craft: HeroShip in game.get_flyable_ships():
		if craft != original and craft.name != &"TorrentInterceptor":
			alternate = craft
			break
	_check(is_instance_valid(alternate), "production fleet supplies a second non-Torrent craft")
	if is_instance_valid(alternate):
		game.active_ship = alternate
		before = _observed_state(game, store, filesystem)
		observed = observer.call("_ember_observation")
		_check(observed.ship.instance_id == alternate.get_instance_id()
			and observed.ship.definition_id == str(alternate.get_ship_id())
			and observed.ship.position == _v(alternate.global_position)
			and observed.home.berth_id == str(alternate.get_home_berth_id()),
			"craft switch immediately follows the actual craft, pose and home lease")
		_check(_observed_state(game, store, filesystem) == before, "switch observation does not alter either craft")
	# Deliberately stale fixture claims expose getters that silently reconcile
	# authority. Only this fixture writes them; observer samples must preserve all.
	var stale_owner := Node.new()
	var stale_reference: WeakRef = weakref(stale_owner)
	var stale_berth := game.world.call("get_berth_node", game.active_ship.get_home_berth_id()) as ShipBerth
	stale_berth.set("_reservation_owner", stale_reference)
	stale_berth.set("_occupant", stale_reference)
	stale_berth.set("_reservation_token", &"observer_stale_fixture")
	stale_berth.set("_reserved_ship_id", game.active_ship.get_ship_id())
	var boarding := game.active_ship.get_node(^"ShipBoardingArea") as ShipBoardingArea
	boarding.set("_has_reservation", true)
	boarding.set("_reservation_token", stale_owner)
	stale_owner.free()
	before = _observed_state(game, store, filesystem)
	observed = observer.call("_ember_observation")
	_check(not observed.home.lease and not observed.home.lease_free and not observed.player.boarding_reserved,
		"stale claims do not masquerade as current home or pilot authority")
	_check(_observed_state(game, store, filesystem) == before
		and stale_berth.get("_reservation_owner") == stale_reference
		and stale_berth.get("_reservation_token") == &"observer_stale_fixture",
		"observer preserves stale berth and boarding claims instead of cleaning them")
	# A committed live record is observed; a retained detached root is not
	# reconciled or unloaded by an observer. This tests the bootstrap getter trap.
	var coordinator := game.ember_streaming_bootstrap.get("_coordinator") as WorldStreamingCoordinator
	var records := coordinator.get("_loaded") as Dictionary
	var generations := coordinator.get("_generation_by_id") as Dictionary
	var loaded_fixture := Node3D.new()
	coordinator.add_child(loaded_fixture)
	records[EmberMoonStreamingBootstrap.LOCATION_ID] = {"instance": loaded_fixture, "generation": 17}
	generations[EmberMoonStreamingBootstrap.LOCATION_ID] = 17
	before = _observed_state(game, store, filesystem)
	observed = observer.call("_ember_observation")
	_check(observed.ember.loaded and observed.ember.loaded_instance_id == loaded_fixture.get_instance_id()
		and observed.ember.location_generation == 17 and _observed_state(game, store, filesystem) == before,
		"live Ember record identity is observed without streaming writes")
	coordinator.remove_child(loaded_fixture)
	before = _observed_state(game, store, filesystem)
	observed = observer.call("_ember_observation")
	_check(not observed.ember.loaded and observed.ember.loaded_instance_id == 0
		and _observed_state(game, store, filesystem) == before and records.has(EmberMoonStreamingBootstrap.LOCATION_ID),
		"detached loaded record stays untouched and reports unavailable")
	records.erase(EmberMoonStreamingBootstrap.LOCATION_ID)
	loaded_fixture.free()
	game.active_ship = null
	observed = observer.call("_ember_observation")
	_check(not observed.actors_available and observed.ship.is_empty() and is_instance_valid(original),
		"absent active craft never falls back to the still-live Torrent")
	game.active_ship = original
	var world := game.world
	game.world = null
	observed = observer.call("_ember_observation")
	_check(observed.main_current and not observed.world_available and not observed.actors_available
		and observed.ship.is_empty() and observed.world_origin_transaction_count == -1,
		"absent world reports unavailable without stale poses or invented origin counts")
	game.world = world
	owner.main = null
	observed = observer.call("_ember_observation")
	_check(not observed.main_current and observed.ship.is_empty(), "retired owned Main is rejected even while still alive")
	owner.main = game
	owner.remove_child(game)
	observed = observer.call("_ember_observation")
	_check(not observed.main_current and not observed.world_available and observed.player.is_empty(),
		"detached Main is unavailable before any world or actor getter")
	game.free()
	observed = observer.call("_ember_observation")
	_check(not observed.main_current and observed.ship.is_empty(), "freed Main is safe to observe")
	owner.main = null
	owner.free()
	_finish()


func _observed_state(game: GameFlow, store: UserDataStore, filesystem: MemoryFilesystem) -> Dictionary:
	var fleet: Array = []
	for craft: HeroShip in game.get_flyable_ships():
		var berth := game.world.call("get_berth_node", craft.get_home_berth_id()) as ShipBerth
		fleet.append({"id": craft.get_instance_id(), "pose": craft.global_transform, "velocity": craft.velocity,
			"piloted": craft.is_piloted(), "source": craft.get("_command_source"),
			"default_source": craft.get("_default_local_command_source"), "seat": craft.get("_pilot_seat_anchor"),
			"contract": (craft.get("_landing_contract") as Dictionary).duplicate(true), "telemetry": craft.get_telemetry(),
			"boarding_reserved": craft.get_node(^"ShipBoardingArea").get("_has_reservation"),
			"boarding_token": craft.get_node(^"ShipBoardingArea").get("_reservation_token"),
			"berth_occupant": berth.get_occupant(), "berth_owner": berth.get_reservation_owner(),
			"berth_token": berth.get("_reservation_token"), "berth_ship": berth.get("_reserved_ship_id"),
			"berth_owner_reference": berth.get("_reservation_owner"), "berth_occupant_reference": berth.get("_occupant")})
	var actions: Dictionary = {}
	for action: StringName in InputMap.get_actions():
		actions[action] = Input.is_action_pressed(action)
	var node_ids: Array[int] = [game.get_instance_id()]
	for node: Node in game.find_children("*", "", true, false):
		node_ids.append(node.get_instance_id())
	var coordinator := game.ember_streaming_bootstrap.get("_coordinator") as WorldStreamingCoordinator
	return {"fleet": fleet, "active": game.active_ship, "nodes": node_ids,
		"loaded": (coordinator.get("_loaded") as Dictionary).duplicate(true),
		"generations": (coordinator.get("_generation_by_id") as Dictionary).duplicate(true),
		"unloads": coordinator.get("_unload_count"),
		"player": game.player.global_transform, "velocity": game.player.velocity,
		"seat": game.player.get("_seat_anchor"), "control": game.player.is_control_enabled(),
		"host": game.ember_surface_loop_host.get_return_status_snapshot(),
		"abandon": game.ember_surface_loop_host.get_abandon_snapshot(),
		"host_advances": game.ember_surface_loop_host.get("_physics_advance_count"),
		"origin": game.common_world_origin_rebase_owner.get_snapshot(),
		"frame": game.ember_streaming_bootstrap.get_coordinate_frame_for_session().get_snapshot(),
		"pending": (game.get("_pending_ember_surface_request") as Dictionary).duplicate(true),
		"return": (game.get("_last_mudds_return_approach_result") as Dictionary).duplicate(true),
		"phase": game.phase, "actions": actions, "mouse": Input.mouse_mode,
		"store": store.get_snapshot(), "generation": store.get_generation(), "files": filesystem.files.duplicate(true)}


func _v(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


func _finish() -> void:
	if _failures.is_empty():
		print("NATIVE_EMBER_OBSERVER_TEST_OK")
		quit(0)
	else:
		print("NATIVE_EMBER_OBSERVER_TEST_FAILED: ", "; ".join(_failures))
		quit(1)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)
