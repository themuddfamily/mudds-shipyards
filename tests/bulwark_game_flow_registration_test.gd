extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const BULWARK_SCENE := preload("res://scenes/ships/bulwark_heavy_gunship.tscn")
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
	var bulwark := BULWARK_SCENE.instantiate() as HeroShip
	flow.add_child(bulwark)
	var filesystem := IsolatedFilesystem.new()
	var store := Store.new("memory://bulwark-game-flow-registration.json", filesystem)
	var settings := Settings.new("memory://bulwark-game-flow-registration.cfg")
	_check(bool(store.load().get("accepted", false)), "isolated settings store opens empty")
	_check(
		bool(store.commit({Adapter.SETTINGS_PAYLOAD_KEY: settings.to_user_data_payload()}, 0, "fixture").get("accepted", false)),
		"isolated settings fixture publishes a validated payload"
	)
	_check(
		flow.configure_runtime_settings_persistence(
			store, "memory://bulwark-game-flow-registration.cfg"
		),
		"GameFlow accepts isolated settings before startup"
	)
	root.add_child(flow)
	await process_frame
	await process_frame
	await process_frame

	var definition := bulwark.get_ship_definition()
	var rig := bulwark.get_ship_audio_rig()
	var registered := flow.get_flyable_ships()
	_check(definition != null and definition.is_definition_valid(), "exact Bulwark production scene exposes a valid ShipDefinition")
	_check(definition != null and definition.audio_profile_id == &"bulwark_heavy_gunship", "Bulwark definition retains its exact audio profile identity")
	_check(rig != null and rig.get_profile_id() == &"bulwark_heavy_gunship", "Bulwark rig builds the definition's exact audio profile")
	_check(rig != null and bool(rig.get_audit_report().get("valid", false)), "Bulwark ship-local audio rig passes its public audit")
	_check(registered.has(bulwark), "public GameFlow flyable roster accepts the exact Bulwark production scene")
	_check(registered.count(bulwark) == 1, "public GameFlow flyable roster registers Bulwark exactly once")

	flow.queue_free()
	for _cleanup_frame in 10:
		await process_frame
	if _failures.is_empty():
		print("BULWARK_GAME_FLOW_REGISTRATION_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
