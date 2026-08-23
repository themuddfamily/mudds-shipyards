extends SceneTree

const GameFlowType := preload("res://scripts/game/game_flow.gd")
const HudType := preload("res://scripts/ui/hud.gd")
const SettingsType := preload("res://scripts/settings/runtime_settings.gd")
const RebindServiceType := preload("res://scripts/settings/input_rebind_service.gd")
const StoreType := preload("res://scripts/persistence/user_data_store.gd")
const AdapterType := preload("res://scripts/settings/runtime_settings_store_adapter.gd")


class FakeFilesystem extends UserDataFilesystem:
	var files: Dictionary = {}

	func file_exists(path: String) -> bool:
		return files.has(path)

	func directory_exists(_path: String) -> bool:
		return false

	func ensure_parent_directory(_path: String) -> Error:
		return OK

	func read_bytes(path: String, _maximum_bytes: int) -> Dictionary:
		return {"error": OK, "bytes": (files[path] as PackedByteArray).duplicate()} if files.has(path) else {"error": ERR_FILE_NOT_FOUND, "bytes": PackedByteArray()}

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
var _path := "user://game_flow_runtime_input_rebind_round_trip_%d.cfg" % Time.get_ticks_usec()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var filesystem := FakeFilesystem.new()
	var store := StoreType.new("memory://runtime-input-rebind.json", filesystem)
	var settings := SettingsType.new("memory://runtime-input-rebind-legacy.cfg")
	var flow := GameFlowType.new()
	var hud := HudType.new()
	flow.runtime_settings = settings
	flow.hud = hud
	flow._runtime_settings_user_data_store = store
	flow._runtime_settings_store_adapter = AdapterType.new(settings, store, "memory://runtime-input-rebind-legacy.cfg")
	flow._runtime_settings_persistence_injected = true
	root.add_child(hud)
	await process_frame
	settings.setting_changed.connect(flow._on_runtime_setting_changed)
	hud.setting_change_requested.connect(flow._on_setting_change_requested)
	hud.call("_show_settings_page")

	_check(hud.begin_input_binding_capture(&"fire"), "HUD starts the remap transaction")
	var remap := InputEventKey.new()
	remap.physical_keycode = KEY_F13
	remap.pressed = true
	hud._unhandled_input(remap)
	_check(_profile_has_key(settings.get_input_binding_profile(), &"fire", KEY_F13), "HUD intent reaches RuntimeSettings")
	_check(_input_map_has_key(&"fire", KEY_F13), "accepted remap reaches InputMap immediately")

	_check(hud.begin_input_binding_capture(&"barrel_roll"), "HUD starts a conflict transaction")
	var conflict := InputEventKey.new()
	conflict.physical_keycode = KEY_H
	conflict.pressed = true
	hud._unhandled_input(conflict)
	_check((hud.get("_binding_conflict_panel") as Control).visible, "conflict is presented before mutation")
	(hud.get("_binding_conflict_replace_button") as Button).pressed.emit()
	_check(
		_profile_has_key(settings.get_input_binding_profile(), &"barrel_roll", KEY_H)
		and not _profile_has_key(settings.get_input_binding_profile(), &"hover", KEY_H),
		"replace choice transfers the binding transactionally"
	)

	var restored := SettingsType.new("memory://runtime-input-rebind-legacy.cfg")
	var restored_flow := GameFlowType.new()
	var restored_hud := HudType.new()
	restored_flow.runtime_settings = restored
	restored_flow.hud = restored_hud
	restored_flow._runtime_settings_user_data_store = store
	restored_flow._runtime_settings_store_adapter = AdapterType.new(restored, store, "memory://runtime-input-rebind-legacy.cfg")
	restored_flow._runtime_settings_persistence_injected = true
	restored_flow._initialize_runtime_settings()
	var restored_status := restored_flow._runtime_settings_store_adapter.load()
	_check(bool(restored_status.get("accepted", false)), "new GameFlow loads the accepted settings envelope")
	_check(
		_profile_has_key(restored.get_input_binding_profile(), &"fire", KEY_F13)
		and _profile_has_key(restored.get_input_binding_profile(), &"barrel_roll", KEY_H),
		"reload retains remap and conflict replacement"
	)
	root.add_child(restored_hud)
	await process_frame
	restored_flow._sync_runtime_settings_hud()
	_check(
		str(restored_hud.call("_action_bindings_text", &"fire")) == "F13"
		and _profile_has_key(restored_hud.get("_input_binding_profile"), &"barrel_roll", KEY_H),
		"fresh GameFlow/HUD restores profile and visible glyph row"
	)

	var defaults := RebindServiceType.new().get_defaults()
	restored_flow._on_setting_change_requested(&"input_binding_profile", defaults)
	var reset_disk := SettingsType.new("memory://runtime-input-rebind-legacy.cfg")
	var reset_adapter := AdapterType.new(reset_disk, store, "memory://runtime-input-rebind-legacy.cfg")
	var reset_status := reset_adapter.load()
	_check(bool(reset_status.get("accepted", false)), "reset profile reloads from isolated store")
	_check(
		reset_disk.get_input_binding_profile().to_dictionary() == defaults.to_dictionary(),
		"reset persists the complete authored profile"
	)

	settings.setting_changed.disconnect(flow._on_runtime_setting_changed)
	hud.setting_change_requested.disconnect(flow._on_setting_change_requested)
	hud.queue_free()
	restored_hud.queue_free()
	flow.free()
	restored_flow.free()
	await process_frame
	if _failures.is_empty():
		print("GAME_FLOW_RUNTIME_INPUT_REBIND_PERSISTENCE_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _profile_has_key(profile: InputBindingProfile, action: StringName, keycode: Key) -> bool:
	for binding: Dictionary in profile.get_bindings(action):
		if binding.get("type", &"") == &"key" and int(binding.get("physical_keycode", -1)) == keycode:
			return true
	return false


func _input_map_has_key(action: StringName, keycode: Key) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == keycode:
			return true
	return false


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)
