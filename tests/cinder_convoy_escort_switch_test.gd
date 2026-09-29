extends SceneTree

## A restored Emberline escort waits, frozen, for the craft it was saved with.
## The player reaches that craft by walking to it and boarding it, which is a
## fleet switch away from Main's default Torrent. That switch must rebind the
## saved escort, not fail it as "active ship replaced". A legacy hyphenated
## escort id in the save must name the same craft.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const Store := preload("res://scripts/persistence/user_data_store.gd")
const Filesystem := preload("res://scripts/persistence/user_data_filesystem.gd")

const STORE_PATH := "memory://convoy-escort-switch.json"
const SLOT: StringName = &"cinder_convoy_session"
const ESCORT_ID: StringName = &"cinder_long_range_bomber"
const LEGACY_ESCORT_ID := "cinder-long-range-bomber"


class MemoryFilesystem extends Filesystem:
	var files: Dictionary = {}

	func file_exists(path: String) -> bool:
		return files.has(path)

	func directory_exists(_path: String) -> bool:
		return false

	func ensure_parent_directory(_path: String) -> Error:
		return OK

	func sync_directory(_path: String) -> Error:
		return OK

	func read_bytes(path: String, maximum_bytes: int) -> Dictionary:
		if not files.has(path):
			return {"error": ERR_FILE_NOT_FOUND, "bytes": PackedByteArray()}
		var bytes := (files[path] as PackedByteArray).duplicate()
		return {
			"error": OK if bytes.size() <= maximum_bytes else ERR_FILE_CORRUPT,
			"bytes": bytes if bytes.size() <= maximum_bytes else PackedByteArray(),
		}

	func write_bytes_and_flush(path: String, bytes: PackedByteArray) -> Error:
		files[path] = bytes.duplicate()
		return OK

	func remove_path(path: String) -> Error:
		if not files.has(path):
			return ERR_FILE_NOT_FOUND
		files.erase(path)
		return OK

	func rename_path(from_path: String, to_path: String) -> Error:
		if not files.has(from_path):
			return ERR_FILE_NOT_FOUND
		if files.has(to_path):
			return ERR_ALREADY_EXISTS
		files[to_path] = (files[from_path] as PackedByteArray).duplicate()
		files.erase(from_path)
		return OK


var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var filesystem := MemoryFilesystem.new()
	var store := Store.new(STORE_PATH, filesystem) as UserDataStore
	store.load()
	var first := await _make_game(store)
	if first == null:
		_finish()
		return
	first.set_physics_process(false)
	first.select_activity_kind(GameFlow.ACTIVITY_KIND_CONVOY_ESCORT)
	var craft := _find_craft(first, ESCORT_ID)
	_check(craft != null and craft != first.ship, "the bomber is a registered non-Torrent escort craft")
	if craft == null:
		_finish()
		return
	craft.set_piloted(true)
	first.active_ship = craft
	first.set("_piloting", true)
	first.set("_sortie_departed_berth", true)
	first.phase = GameFlow.Phase.FREE_FLIGHT
	craft.global_position = GameFlow.CINDER_CONVOY_ACTIVATION_CENTER + Vector3(4.01, 0.0, 0.0)
	first.call("_physics_process", 0.1)
	await _wait_until(func() -> bool:
		return is_instance_valid(
			(first.get("cinder_streaming_bootstrap") as CinderStreamingBootstrap).get_loaded_instance()
		), 20)
	craft.global_position = GameFlow.CINDER_CONVOY_ACTIVATION_CENTER
	first.call("_physics_process", 0.25)
	var host := first.get("cinder_convoy_host") as CinderConvoyEscortHost
	for _step in 4:
		craft.global_position = (host.get_snapshot().entity_position as Vector3) \
			+ GameFlow.CINDER_CONVOY_ESCORT_LANE_OFFSET
		first.call("_physics_process", 0.25)
	var saved := first.save_cinder_convoy_session()
	_check(bool(saved.get("accepted", false)), "the bomber escort session saves (%s)" % saved)
	await _retire_game(first)

	await _restore_and_board(filesystem, "current escort id", "")
	await _restore_and_board(filesystem, "legacy hyphenated escort id", LEGACY_ESCORT_ID)
	_finish()


func _restore_and_board(filesystem: MemoryFilesystem, label: String, rewrite_escort_id: String) -> void:
	var store := Store.new(STORE_PATH, filesystem) as UserDataStore
	store.load()
	if not rewrite_escort_id.is_empty():
		var payload := store.get_snapshot().duplicate(true)
		_rewrite_escort_id(payload, rewrite_escort_id)
		store.commit(payload, store.get_generation(), "legacy-escort-id-fixture")
	var game := await _make_game(store)
	if game == null:
		return
	game.set_physics_process(false)
	var report := game.get_cinder_convoy_session_persistence_report()
	_check(
		bool((report.restore_status as Dictionary).get("accepted", false))
		and bool(report.runtime_rebind_pending)
		and report.get("restored_ship_id", &"") == ESCORT_ID,
		"%s: startup restores the escort frozen for the bomber (%s)" % [label, report]
	)
	var escort := _find_craft(game, ESCORT_ID)
	_check(game.get_active_ship() != escort, "%s: Main starts in a different craft than the saved escort" % label)
	game.call(&"_board_ship", escort)
	for _frame in 30:
		await process_frame
	var after := game.get_active_activity_snapshot()
	_check(
		game.get_active_ship() == escort
		and after.get("state_id", &"") == &"active"
		and bool(game.get_cinder_convoy_session_persistence_report().runtime_rebind_pending),
		"%s: boarding the saved escort keeps the restored convoy active and waiting to rebind (state=%s)"
			% [label, after.get("state_id", &"")]
	)
	await _retire_game(game)


func _rewrite_escort_id(value: Variant, escort_id: String) -> void:
	if value is Dictionary:
		for key: Variant in (value as Dictionary).keys():
			if String(key) == "escort_ship_id":
				(value as Dictionary)[key] = escort_id
			else:
				_rewrite_escort_id((value as Dictionary)[key], escort_id)
	elif value is Array:
		for item: Variant in value as Array:
			_rewrite_escort_id(item, escort_id)


func _find_craft(game: GameFlow, ship_id: StringName) -> HeroShip:
	for candidate: HeroShip in game.get_flyable_ships():
		if candidate.get_ship_id() == ship_id:
			return candidate
	return null


func _make_game(store: UserDataStore) -> GameFlow:
	var game := MAIN_SCENE.instantiate() as GameFlow
	if game == null or not game.configure_runtime_settings_persistence(store):
		_check(false, "the isolated GameFlow accepts its one injected atomic store")
		return null
	root.add_child(game)
	for _frame in 6:
		await process_frame
		await physics_frame
	return game


func _retire_game(game: GameFlow) -> void:
	game.set("_piloting", false)
	game.queue_free()
	for _frame in 3:
		await process_frame


func _wait_until(predicate: Callable, maximum_frames: int) -> bool:
	for _frame in maximum_frames:
		if bool(predicate.call()):
			return true
		await process_frame
	return bool(predicate.call())


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
		push_error("FAIL: " + message)


func _finish() -> void:
	for failure in _failures:
		push_error(failure)
	if _failures.is_empty():
		print("CINDER_CONVOY_ESCORT_SWITCH_TEST_OK: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)
