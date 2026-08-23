extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const Settings := preload("res://scripts/settings/runtime_settings.gd")
const Store := preload("res://scripts/persistence/user_data_store.gd")
const Adapter := preload("res://scripts/settings/runtime_settings_store_adapter.gd")


class IsolatedFilesystem extends UserDataFilesystem:
	var files: Dictionary = {}

	func file_exists(path: String) -> bool:
		return files.has(path)

	func directory_exists(_path: String) -> bool:
		return false

	func ensure_parent_directory(_path: String) -> Error:
		return OK

	func read_bytes(path: String, maximum_bytes: int) -> Dictionary:
		if not files.has(path):
			return {"error": ERR_FILE_NOT_FOUND, "bytes": PackedByteArray()}
		var bytes := (files[path] as PackedByteArray).duplicate()
		return {
			"error": OK if bytes.size() <= maximum_bytes else ERR_FILE_CORRUPT,
			"bytes": bytes,
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
		if not files.has(from_path) or files.has(to_path):
			return ERR_FILE_NOT_FOUND if not files.has(from_path) else ERR_ALREADY_EXISTS
		files[to_path] = (files[from_path] as PackedByteArray).duplicate()
		files.erase(from_path)
		return OK

var _assertions := 0
var _failures: Array[String] = []


func _initialize() -> void:
	var flow := MAIN_SCENE.instantiate() as GameFlow
	var filesystem := IsolatedFilesystem.new()
	var store := Store.new("memory://game-flow-fleet-expansion.json", filesystem)
	var settings := Settings.new("memory://game-flow-fleet-expansion.cfg")
	_check(bool(store.load().get("accepted", false)), "isolated settings store opens empty")
	_check(
		bool(store.commit({Adapter.SETTINGS_PAYLOAD_KEY: settings.to_user_data_payload()}, 0, "fixture").get("accepted", false)),
		"isolated settings fixture publishes a validated payload"
	)
	_check(
		flow.configure_runtime_settings_persistence(store, "memory://game-flow-fleet-expansion.cfg"),
		"GameFlow accepts the isolated settings fixture before startup"
	)
	root.add_child(flow)
	# ShipyardWorld assembles its production binding deferred by one frame.
	await process_frame
	await process_frame
	await process_frame
	var startup_registered := flow.get_flyable_ships()
	_check(startup_registered.any(func(candidate: HeroShip) -> bool:
		return candidate.get_ship_id() == &"cinder-cargo-hauler"
	), "startup refresh discovers nested production craft")
	flow._resolve_scene_bindings()
	flow._register_flyable_ships()
	var registered := flow.get_flyable_ships()
	var ids := {}
	var berths := {}
	var expansion_count := 0
	for candidate in registered:
		ids[candidate.get_ship_id()] = true
		berths[candidate.get_home_berth_id()] = true
		if candidate.get_ship_id() in [
			&"cinder-cargo-hauler",
			&"cinder-long-range-bomber",
			&"cinder-light-interceptor",
		]:
			expansion_count += 1
	_check(expansion_count == 3, "all three production craft enter the flyable registry")
	_check(ids.size() == registered.size(), "registered ship IDs remain unique")
	_check(berths.size() == registered.size(), "registered home berth IDs remain unique")
	_check(registered.any(func(candidate: HeroShip) -> bool:
		return candidate.get_ship_id() == &"cinder-cargo-hauler"
	), "cargo hauler is available as a switch target")
	flow.queue_free()
	await process_frame
	if _failures.is_empty():
		print("PASS game_flow_fleet_expansion_registration_test (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
