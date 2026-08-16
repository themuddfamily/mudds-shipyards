extends SceneTree

## Focused persistence and lifecycle proof for RuntimeSettings input profiles.
##
## This does not claim settings UI, controller glyph, or physical-controller
## coverage. It proves the data boundary and the explicit process-global
## InputMap application seam that GameFlow invokes on startup and re-entry.

const Settings := preload("res://scripts/settings/runtime_settings.gd")
const Profile := preload("res://scripts/settings/input_binding_profile.gd")
const Service := preload("res://scripts/settings/input_rebind_service.gd")

const ACTION_ALPHA := &"engine_start"
const ACTION_BETA := &"engine_stop"

var _failures := PackedStringArray()
var _assertions := 0
var _temp_path := ""


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_temp_path = "user://input_binding_persistence_%d.cfg" % Time.get_ticks_usec()
	_cleanup_files()
	_test_round_trip_explicit_apply_and_reentry()
	_test_invalid_saved_profiles_fall_back_as_one_unit()
	_test_legacy_settings_migrate_to_captured_defaults()
	_cleanup_files()
	_finish()


func _test_round_trip_explicit_apply_and_reentry() -> void:
	var original := Settings.new(_temp_path)
	var project_defaults := original.get_input_binding_profile()
	_check(
		_has_key(project_defaults, ACTION_ALPHA, KEY_Y)
		and _has_joy_button(project_defaults, ACTION_ALPHA, JOY_BUTTON_DPAD_UP),
		"the first settings owner captures the live project keyboard and controller bindings"
	)
	_check(
		is_equal_approx(float(project_defaults.get_action_options(ACTION_ALPHA).deadzone), 0.18),
		"captured project controller deadzone becomes the factory-reset baseline"
	)
	_check(
		not project_defaults.bindings.has(&"ui_accept"),
		"the persisted inventory excludes engine-owned UI fallbacks that remapping must not erase"
	)

	var custom := project_defaults.duplicate_profile()
	_check(
		custom.set_bindings(ACTION_ALPHA, [_key(KEY_F13), _joy_button(15)]),
		"a complete settings profile accepts a detached remap"
	)
	_check(
		custom.set_action_options(ACTION_ALPHA, {
			"deadzone": 0.43,
			"curve": Profile.CURVE_SQUARED,
			"hold_mode": Profile.TOGGLE,
		}),
		"controller deadzone curve and hold-toggle metadata can be customized"
	)
	_check(original.set_input_binding_profile(custom), "RuntimeSettings accepts a valid conflict-free complete profile")
	var detached := original.get_input_binding_profile()
	detached.set_bindings(ACTION_ALPHA, [_key(KEY_F14)])
	_check(
		_has_key(original.get_input_binding_profile(), ACTION_ALPHA, KEY_F13),
		"RuntimeSettings profile reads are deep detached copies"
	)

	var map_before_save := _capture_actions()
	_check(original.save_to_file() == OK, "version-four settings save the input profile transactionally")
	_check(_capture_actions() == map_before_save, "saving a remap has no implicit InputMap side effect")
	var stored := ConfigFile.new()
	_check(stored.load(_temp_path) == OK, "the remap settings file parses as ConfigFile data")
	_check(
		int(stored.get_value("meta", "schema_version", -1)) == Settings.SCHEMA_VERSION,
		"the containing settings document carries the current version"
	)
	var stored_profile: Variant = stored.get_value("input_bindings", "profile", null)
	_check(
		stored_profile is Dictionary
		and int((stored_profile as Dictionary).get("schema_version", -1)) == Profile.SCHEMA_VERSION,
		"the nested input profile retains its independent schema version"
	)

	var restored := Settings.new(_temp_path)
	_check(restored.load_from_file() == OK, "a fresh RuntimeSettings instance loads saved bindings")
	_check(
		restored.get_input_binding_profile().to_dictionary() == custom.to_dictionary(),
		"keyboard gamepad and action-option metadata round-trip exactly"
	)
	_check(_capture_actions() == map_before_save, "loading remains side-effect free until startup explicitly applies")
	var apply_report := restored.apply_input_bindings()
	_check(
		bool(apply_report.applied)
		and bool(apply_report.complete)
		and int(apply_report.action_count) == custom.bindings.size()
		and int(apply_report.profile_schema_version) == Profile.SCHEMA_VERSION,
		"explicit startup application reports the complete deterministic profile"
	)
	_check(
		_has_input_map_key(ACTION_ALPHA, KEY_F13)
		and _has_input_map_joy_button(ACTION_ALPHA, 15)
		and not _has_input_map_key(ACTION_ALPHA, KEY_Y),
		"explicit application replaces events on an existing authored action"
	)
	_check(
		is_equal_approx(InputMap.action_get_deadzone(ACTION_ALPHA), 0.43),
		"explicit application carries controller deadzone metadata into InputMap"
	)
	var loaded_options := restored.get_input_binding_profile().get_action_options(ACTION_ALPHA)
	_check(
		loaded_options.curve == Profile.CURVE_SQUARED
		and loaded_options.hold_mode == Profile.TOGGLE,
		"curve and hold-toggle metadata survive serialization even though InputMap has no such fields"
	)

	# Another streamed scene may legitimately own the process InputMap while Main
	# is detached. Re-entry must reapply the retained validated settings snapshot.
	_replace_input_map_action(ACTION_ALPHA, KEY_F14, 0.07)
	_check(_has_input_map_key(ACTION_ALPHA, KEY_F14), "the re-entry witness first disturbs process-global bindings")
	var reentry_report := restored.apply_input_bindings()
	_check(
		bool(reentry_report.applied)
		and _has_input_map_key(ACTION_ALPHA, KEY_F13)
		and _has_input_map_joy_button(ACTION_ALPHA, 15)
		and is_equal_approx(InputMap.action_get_deadzone(ACTION_ALPHA), 0.43),
		"the explicit Main re-entry seam deterministically reclaims saved bindings"
	)

	# This instance is created after the custom profile reached InputMap. It must
	# still remember the first captured project baseline rather than recapturing
	# the now-custom live map.
	var later_instance := Settings.new(_temp_path)
	later_instance.reset_to_defaults()
	_check(
		_has_key(later_instance.get_input_binding_profile(), ACTION_ALPHA, KEY_Y)
		and _has_joy_button(later_instance.get_input_binding_profile(), ACTION_ALPHA, JOY_BUTTON_DPAD_UP),
		"a fresh post-remap instance resets to captured project bindings"
	)
	_check(bool(later_instance.apply_input_bindings().applied), "factory defaults apply through the same explicit seam")
	_check(
		_has_input_map_key(ACTION_ALPHA, KEY_Y)
		and _has_input_map_joy_button(ACTION_ALPHA, JOY_BUTTON_DPAD_UP)
		and not _has_input_map_key(ACTION_ALPHA, KEY_F13)
		and is_equal_approx(InputMap.action_get_deadzone(ACTION_ALPHA), 0.18),
		"factory reset plus explicit apply restores the captured project map"
	)


func _test_invalid_saved_profiles_fall_back_as_one_unit() -> void:
	var defaults := Settings.new(_temp_path).get_input_binding_profile()
	var custom := defaults.duplicate_profile()
	custom.set_bindings(ACTION_ALPHA, [_key(KEY_F13), _joy_button(15)])
	custom.set_action_options(ACTION_ALPHA, {
		"deadzone": 0.43,
		"curve": Profile.CURVE_SQUARED,
		"hold_mode": Profile.TOGGLE,
	})

	var malformed := custom.to_dictionary()
	malformed.erase("action_options")
	_write_profile_fixture(malformed, 0.0061)
	_replace_input_map_action(ACTION_ALPHA, KEY_F14, 0.07)
	var malformed_settings := Settings.new(_temp_path)
	_check(malformed_settings.load_from_file() == OK, "a valid settings document containing a malformed nested profile loads safely")
	_check(
		malformed_settings.get_input_binding_profile().to_dictionary() == defaults.to_dictionary(),
		"a structurally malformed saved profile falls back as one unit to project defaults"
	)
	_check(
		is_equal_approx(malformed_settings.ship_mouse_sensitivity, 0.0061),
		"one malformed profile does not discard unrelated validated settings"
	)
	_check(_has_input_map_key(ACTION_ALPHA, KEY_F14), "malformed-profile fallback is still side-effect free on load")
	malformed_settings.apply_input_bindings()
	_check(_has_input_map_key(ACTION_ALPHA, KEY_Y), "explicit apply after malformed data reaches only safe defaults")

	var conflict := custom.duplicate_profile()
	conflict.set_bindings(ACTION_ALPHA, [_key(KEY_X), _joy_button(15)])
	_write_profile_fixture(conflict.to_dictionary(), 0.0062)
	var conflicting_settings := Settings.new(_temp_path)
	_check(conflicting_settings.load_from_file() == OK, "a newly conflicting saved profile does not invalidate the outer settings file")
	_check(
		conflicting_settings.get_input_binding_profile().to_dictionary() == defaults.to_dictionary(),
		"a non-authored cross-action conflict fails closed to captured defaults"
	)
	_check(
		is_equal_approx(conflicting_settings.ship_mouse_sensitivity, 0.0062),
		"conflict fallback leaves unrelated settings independently loadable"
	)

	var duplicate := custom.to_dictionary()
	var duplicate_bindings := (duplicate.bindings as Dictionary)[ACTION_ALPHA] as Array
	duplicate_bindings.append(duplicate_bindings[0])
	_write_profile_fixture(duplicate, 0.0063)
	var duplicate_settings := Settings.new(_temp_path)
	_check(duplicate_settings.load_from_file() == OK, "duplicate descriptors are contained within the nested profile boundary")
	_check(
		duplicate_settings.get_input_binding_profile().to_dictionary() == defaults.to_dictionary(),
		"a duplicate binding within one action falls back to project defaults"
	)

	var future := custom.to_dictionary()
	future.schema_version = Profile.SCHEMA_VERSION + 1
	_write_profile_fixture(future, 0.0064)
	var future_settings := Settings.new(_temp_path)
	_check(future_settings.load_from_file() == OK, "an unsupported newer nested profile is safely contained")
	_check(
		future_settings.get_input_binding_profile().to_dictionary() == defaults.to_dictionary(),
		"an unsupported newer input schema is never interpreted or applied"
	)

	# Direct setter rejection is transactional too.
	var live := Settings.new(_temp_path)
	_check(live.set_input_binding_profile(custom), "valid live profile fixture installs before rejection proof")
	var before_rejection := live.get_input_binding_profile().to_dictionary()
	_check(not live.set_input_binding_profile(conflict), "the RuntimeSettings setter rejects conflicting live data")
	_check(
		live.get_input_binding_profile().to_dictionary() == before_rejection,
		"rejected live data cannot partially replace the canonical profile"
	)


func _test_legacy_settings_migrate_to_captured_defaults() -> void:
	var legacy := ConfigFile.new()
	legacy.set_value("meta", "schema_version", Settings.SCHEMA_VERSION - 1)
	legacy.set_value("controls", "ship_mouse_sensitivity", 0.0057)
	_check(legacy.save(_temp_path) == OK, "legacy settings fixture without input bindings saves")
	var migrated := Settings.new(_temp_path)
	_check(migrated.load_from_file() == OK, "the prior supported settings schema still loads")
	_check(
		_has_key(migrated.get_input_binding_profile(), ACTION_ALPHA, KEY_Y),
		"legacy settings migrate in memory to captured project bindings"
	)
	_check(
		is_equal_approx(migrated.ship_mouse_sensitivity, 0.0057),
		"legacy migration preserves its unrelated stored setting"
	)


func _write_profile_fixture(profile_data: Variant, sensitivity: float) -> void:
	var config := ConfigFile.new()
	config.set_value("meta", "schema_version", Settings.SCHEMA_VERSION)
	config.set_value("controls", "ship_mouse_sensitivity", sensitivity)
	config.set_value("input_bindings", "profile", profile_data)
	_check(config.save(_temp_path) == OK, "invalid-profile fixture writes for fail-safe loading")


func _replace_input_map_action(action: StringName, code: Key, deadzone: float) -> void:
	InputMap.action_erase_events(action)
	InputMap.action_set_deadzone(action, deadzone)
	InputMap.action_add_event(action, _key_event(code))


func _capture_actions() -> Dictionary:
	var service := Service.new()
	return service.capture_input_map(PackedStringArray([ACTION_ALPHA, ACTION_BETA])).to_dictionary()


func _has_key(profile: Profile, action: StringName, code: Key) -> bool:
	for binding: Dictionary in profile.get_bindings(action):
		if binding.type == &"key" and int(binding.physical_keycode) == code:
			return true
	return false


func _has_joy_button(profile: Profile, action: StringName, button: int) -> bool:
	for binding: Dictionary in profile.get_bindings(action):
		if binding.type == &"joy_button" and int(binding.button_index) == button:
			return true
	return false


func _has_input_map_key(action: StringName, code: Key) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == code:
			return true
	return false


func _has_input_map_joy_button(action: StringName, button: int) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == button:
			return true
	return false


func _key(code: Key) -> Dictionary:
	return {"device": Profile.DEVICE_KEYBOARD, "type": &"key", "physical_keycode": code}


func _joy_button(button: int) -> Dictionary:
	return {"device": Profile.DEVICE_GAMEPAD, "type": &"joy_button", "button_index": button}


func _key_event(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	return event


func _joy_button_event(button: int) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	return event


func _cleanup_files() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		var path := _temp_path + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("INPUT_BINDING_PERSISTENCE_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		print("INPUT_BINDING_PERSISTENCE_TEST_FAILED: %d/%d failed" % [_failures.size(), _assertions])
		quit(1)
