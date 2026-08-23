extends SceneTree

## Proves the player-owned first/third-person preference survives a completely
## fresh Main without sharing authority with the ship cockpit/chase camera.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const Settings := preload("res://scripts/settings/runtime_settings.gd")
const Store := preload("res://scripts/persistence/user_data_store.gd")
const Adapter := preload("res://scripts/settings/runtime_settings_store_adapter.gd")

const STORE_PATH := "memory://on-foot-camera-mode-persistence.json"
const LEGACY_PATH := "memory://on-foot-camera-mode-persistence-legacy.cfg"

var _assertions := 0
var _failures: PackedStringArray = []
var _player_signal_count := 0


class FakeFilesystem extends UserDataFilesystem:
	var files: Dictionary = {}

	func file_exists(path: String) -> bool:
		return files.has(path)

	func directory_exists(_path: String) -> bool:
		return false

	func ensure_parent_directory(_path: String) -> Error:
		return OK

	func read_bytes(path: String, _maximum_bytes: int) -> Dictionary:
		return (
			{"error": OK, "bytes": (files[path] as PackedByteArray).duplicate()}
			if files.has(path)
			else {"error": ERR_FILE_NOT_FOUND, "bytes": PackedByteArray()}
		)

	func write_bytes_and_flush(path: String, bytes: PackedByteArray) -> Error:
		files[path] = bytes.duplicate()
		return OK

	func remove_path(path: String) -> Error:
		files.erase(path)
		return OK

	func rename_path(from_path: String, to_path: String) -> Error:
		if not files.has(from_path) or files.has(to_path):
			return ERR_FILE_NOT_FOUND if not files.has(from_path) else ERR_ALREADY_EXISTS
		files[to_path] = (files[from_path] as PackedByteArray).duplicate()
		files.erase(from_path)
		return OK


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var store := Store.new(STORE_PATH, FakeFilesystem.new())
	var legacy_settings := Settings.new(LEGACY_PATH)
	var schema_eight_payload := legacy_settings.to_user_data_payload()
	schema_eight_payload.schema_version = 8
	(schema_eight_payload.values as Dictionary).erase("on_foot_first_person")
	_check(bool(store.load().accepted), "fixture opens an empty atomic store")
	_check(
		bool(store.commit({Adapter.SETTINGS_PAYLOAD_KEY: schema_eight_payload}, 0, "schema-eight").accepted),
		"fixture writes a schema-eight settings payload without on-foot camera preference"
	)

	var first := await _instantiate_with_store(store)
	var first_player := first.get_node(^"Player") as PlayerController
	var first_ship := first.active_ship as HeroShip
	_check(
		first_player.get_camera_view_mode() == PlayerController.CameraViewMode.THIRD_PERSON
		and not first.get_runtime_settings().on_foot_first_person
		and first_ship.get_camera_view() == HeroShip.CAMERA_VIEW_CHASE,
		"schema-eight payload migrates to third-person default without changing ship camera authority"
	)

	first_player.camera_view_mode_changed.connect(_on_player_camera_view_mode_changed)
	first_player.set_camera_view_mode(PlayerController.CameraViewMode.THIRD_PERSON)
	first_player.set_camera_view_mode(PlayerController.CameraViewMode.FIRST_PERSON)
	_check(
		_player_signal_count == 1
		and first.get_runtime_settings().on_foot_first_person
		and first_ship.get_camera_view() == HeroShip.CAMERA_VIEW_CHASE,
		"one changed-only Player preference persists without synthesizing a ship camera change"
	)
	var persisted := store.get_snapshot().get(Adapter.SETTINGS_PAYLOAD_KEY, {}) as Dictionary
	_check(
		int(persisted.get("schema_version", -1)) == Settings.USER_DATA_PAYLOAD_SCHEMA_VERSION
		and bool((persisted.get("values", {}) as Dictionary).get("on_foot_first_person", false)),
		"changed on-foot preference upgrades and commits the typed atomic payload"
	)

	first.queue_free()
	await process_frame
	var restarted := await _instantiate_with_store(store)
	var restarted_player := restarted.get_node(^"Player") as PlayerController
	var restarted_ship := restarted.active_ship as HeroShip
	_check(
		restarted_player.get_camera_view_mode() == PlayerController.CameraViewMode.FIRST_PERSON
		and restarted_player.is_first_person_active()
		and restarted.get_runtime_settings().on_foot_first_person
		and restarted_ship.get_camera_view() == HeroShip.CAMERA_VIEW_CHASE,
		"fresh Main restores the selected on-foot first-person camera while ship chase remains independent"
	)

	restarted.queue_free()
	await process_frame
	_finish()


func _instantiate_with_store(store: UserDataStore) -> GameFlow:
	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game.configure_runtime_settings_persistence(store, LEGACY_PATH), "Main accepts injected store before startup")
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame
	return game


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _on_player_camera_view_mode_changed(_mode: PlayerController.CameraViewMode) -> void:
	_player_signal_count += 1


func _finish() -> void:
	if _failures.is_empty():
		print("ON_FOOT_CAMERA_MODE_PERSISTENCE_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	printerr("ON_FOOT_CAMERA_MODE_PERSISTENCE_TEST_FAILED: %s" % "; ".join(_failures))
	quit(1)
