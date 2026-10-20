extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const Settings := preload("res://scripts/settings/runtime_settings.gd")
const Store := preload("res://scripts/persistence/user_data_store.gd")
const Adapter := preload("res://scripts/settings/runtime_settings_store_adapter.gd")


class FakeFilesystem extends UserDataFilesystem:
	var files: Dictionary = {}

	func file_exists(path: String) -> bool:
		return files.has(path)

	func directory_exists(_path: String) -> bool:
		return false

	func ensure_parent_directory(_path: String) -> Error:
		return OK

	func read_bytes(path: String, _maximum_bytes: int) -> Dictionary:
		return {
			"error": OK,
			"bytes": (files[path] as PackedByteArray).duplicate(),
		} if files.has(path) else {
			"error": ERR_FILE_NOT_FOUND,
			"bytes": PackedByteArray(),
		}

	func write_bytes_and_flush(path: String, bytes: PackedByteArray) -> Error:
		files[path] = bytes.duplicate()
		return OK

	func remove_path(path: String) -> Error:
		files.erase(path)
		return OK

	func rename_path(from_path: String, to_path: String) -> Error:
		if not files.has(from_path):
			return ERR_FILE_NOT_FOUND
		files[to_path] = (files[from_path] as PackedByteArray).duplicate()
		files.erase(from_path)
		return OK


var _assertions := 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var store := Store.new("memory://tractor-look-settings.json", FakeFilesystem.new())
	var seeded := Settings.new("memory://tractor-look-settings-legacy.cfg")
	seeded.invert_on_foot_y = true
	seeded.on_foot_mouse_sensitivity = 0.004
	_check(bool(store.load().accepted), "isolated settings store opens")
	_check(bool(store.commit({
		Adapter.SETTINGS_PAYLOAD_KEY: seeded.to_user_data_payload(),
	}, 0, "tractor-look-settings-fixture").accepted), "inverted on-foot preference is persisted before startup")

	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game.configure_runtime_settings_persistence(
		store, "memory://tractor-look-settings-legacy.cfg"
	), "production Main accepts the isolated settings store")
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame

	var tractor := game.tow_tractor
	var player := game.player
	_check(is_instance_valid(tractor), "production Main owns the drivable tractor")
	if is_instance_valid(tractor):
		_check(game.runtime_settings.invert_on_foot_y and player.invert_mouse_y and tractor.invert_mouse_y,
			"production startup applies saved on-foot inversion to both Player and tractor")
		_check(is_equal_approx(player.mouse_sensitivity, 0.004)
			and is_equal_approx(tractor.mouse_sensitivity, 0.004),
			"startup retains the shared on-foot sensitivity")
		for inverted: bool in [false, true]:
			game.runtime_settings.invert_on_foot_y = inverted
			_check(player.invert_mouse_y == inverted and tractor.invert_mouse_y == inverted,
				"live RuntimeSettings signal applies on-foot inversion=%s to both consumers" % inverted)
			_check(not game.runtime_settings.invert_ship_y,
				"on-foot inversion leaves the independent flight preference unchanged")
		# Missing optional tractor must not block the on-foot settings consumer.
		game.tow_tractor = null
		game.runtime_settings.invert_on_foot_y = false
		_check(not player.invert_mouse_y, "live inversion remains safe without an optional tractor")
		game.tow_tractor = tractor
	game.queue_free()
	await process_frame
	await process_frame
	if _failures.is_empty():
		print("GAME_FLOW_TRACTOR_LOOK_SETTINGS_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)
