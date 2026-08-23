extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const Settings := preload("res://scripts/settings/runtime_settings.gd")
const Profile := preload("res://scripts/settings/input_binding_profile.gd")
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


class MutableInputProvider extends RefCounted:
	var strength := 0.0
	var pressed := false

	func get_action_strength(action: StringName) -> float:
		return strength if action == &"sprint_boost" else 0.0

	func is_action_pressed(action: StringName) -> bool:
		return pressed if action == &"sprint_boost" else false

	func set_boost(is_pressed: bool) -> void:
		pressed = is_pressed
		strength = 1.0 if is_pressed else 0.0


var _assertions := 0
var _failures: PackedStringArray = []


func _initialize() -> void:
	_run()


func _run() -> void:
	var filesystem := FakeFilesystem.new()
	var store := Store.new("memory://sprint-toggle-reentry.json", filesystem)
	var seeded := Settings.new("memory://sprint-toggle-reentry-legacy.cfg")
	var profile := seeded.get_input_binding_profile()
	_check(
		profile.set_action_options(&"sprint_boost", {
			"deadzone": 0.0,
			"curve": Profile.CURVE_LINEAR,
			"hold_mode": Profile.TOGGLE,
		}) and seeded.set_input_binding_profile(profile),
		"fixture authors a valid persisted sprint toggle",
	)
	_check(bool(store.load().accepted), "isolated settings store opens")
	_check(
		bool(store.commit({
			Adapter.SETTINGS_PAYLOAD_KEY: seeded.to_user_data_payload(),
		}, 0, "sprint-toggle-fixture").accepted),
		"toggle profile is persisted before production startup",
	)

	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(
		game.configure_runtime_settings_persistence(
			store,
			"memory://sprint-toggle-reentry-legacy.cfg",
		),
		"production GameFlow accepts the isolated settings authority",
	)
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame

	var source := game.get_flyable_ships()[0].get_local_input_source()
	var source_id := source.get_instance_id()
	var provider := MutableInputProvider.new()
	source.set_input_provider(provider)
	source.next_command(1000)

	var parent := game.get_parent()
	parent.remove_child(game)
	await process_frame
	parent.add_child(game)
	await process_frame
	await physics_frame
	await process_frame

	_check(
		game.get_flyable_ships()[0].get_local_input_source().get_instance_id() == source_id
		and source.get_input_binding_profile().get_action_options(&"sprint_boost").hold_mode
		== Profile.TOGGLE,
		"retained GameFlow re-entry keeps the production source and persisted toggle profile",
	)
	provider.set_boost(false)
	source.next_command(1001)
	provider.set_boost(true)
	var toggled_on := source.next_command(1002)
	provider.set_boost(false)
	var released := source.next_command(1003)
	provider.set_boost(true)
	var toggled_off := source.next_command(1004)
	_check(
		toggled_on.boost and released.boost and not toggled_off.boost,
		"after re-entry sprint boost latches across release and unlatches on the second press",
	)

	game.queue_free()
	await process_frame
	await process_frame
	if _failures.is_empty():
		print("GAME_FLOW_SPRINT_TOGGLE_REENTRY_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)
