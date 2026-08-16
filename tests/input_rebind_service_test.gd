extends SceneTree

const Profile := preload("res://scripts/settings/input_binding_profile.gd")
const RebindService := preload("res://scripts/settings/input_rebind_service.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_schema_and_validation()
	_test_action_device_lists_and_copying()
	_test_conflicts_and_resolution()
	_test_defaults_reset_and_input_map_adapter()
	_finish()


func _test_schema_and_validation() -> void:
	var valid := _profile_from({
		&"fire": [_key(KEY_F), _mouse(MOUSE_BUTTON_LEFT), _joy_button(JOY_BUTTON_RIGHT_SHOULDER)],
		&"brake": [_motion(JOY_AXIS_TRIGGER_LEFT, 1.0)],
	}, {
		&"fire": {"deadzone": 0.18, "curve": &"linear", "hold_mode": &"hold"},
		&"brake": {"deadzone": 0.35, "curve": &"squared", "hold_mode": &"toggle"},
	})
	_check(valid != null, "complete version-one input schema is accepted")
	_check(valid.get_bindings(&"fire").size() == 3, "one action carries keyboard mouse and gamepad binding lists")
	_check(valid.get_action_options(&"brake").get("curve") == &"squared", "curve metadata is retained")
	_check(valid.get_action_options(&"brake").get("hold_mode") == &"toggle", "hold-toggle metadata is retained")

	_check(Profile.from_dictionary({}) == null, "incomplete schemas fail closed")
	_check(Profile.from_dictionary({"schema_version": 99, "bindings": {}, "action_options": {}}) == null, "future schemas are rejected")
	_check(Profile.from_dictionary({"schema_version": 0, "bindings": {}, "action_options": {}}) == null, "unsupported legacy schemas are rejected")
	_check(_profile_from({&"fire": [{"device": &"keyboard", "type": &"key", "physical_keycode": 0}]}, {}) == null, "invalid keyboard descriptor is rejected")
	_check(_profile_from({&"fire": [{"device": &"mouse", "type": &"joy_button", "button_index": 1}]}, {}) == null, "device-type mismatch is rejected")
	_check(_profile_from({&"fire": [{"device": &"gamepad", "type": &"joy_motion", "axis": 1, "axis_value": 0.5}]}, {}) == null, "partial gamepad axis direction is rejected")
	_check(_profile_from({&"fire": [_key(KEY_F)]}, {&"fire": {"deadzone": 1.1, "curve": &"linear", "hold_mode": &"hold"}}) == null, "out-of-range deadzone is rejected")
	_check(_profile_from({&"fire": [_key(KEY_F)]}, {&"fire": {"deadzone": 0.2, "curve": &"cubic", "hold_mode": &"hold"}}) == null, "unsupported curves are rejected")
	_check(_profile_from({&"fire": [_key(KEY_F)]}, {&"fire": {"deadzone": 0.2, "curve": &"linear", "hold_mode": &"sticky"}}) == null, "unsupported hold-toggle values are rejected")


func _test_action_device_lists_and_copying() -> void:
	var profile := _profile_from({&"fire": [_key(KEY_F), _mouse(MOUSE_BUTTON_LEFT)]}, {})
	_check(profile != null, "profiles add default options for actions omitted by authored options")
	_check(is_equal_approx(float(profile.get_action_options(&"fire").deadzone), 0.18), "omitted options receive the calibrated deadzone default")
	var bindings := profile.get_bindings(&"fire")
	(bindings[0] as Dictionary)["physical_keycode"] = KEY_G
	var options := profile.get_action_options(&"fire")
	options["deadzone"] = 0.9
	_check((profile.get_bindings(&"fire")[0] as Dictionary).physical_keycode == KEY_F, "binding accessors return deep copies")
	_check(is_equal_approx(float(profile.get_action_options(&"fire").deadzone), 0.18), "option accessors return deep copies")
	var serialized := profile.to_dictionary()
	((serialized.bindings[&"fire"] as Array)[0] as Dictionary)["physical_keycode"] = KEY_H
	_check((profile.get_bindings(&"fire")[0] as Dictionary).physical_keycode == KEY_F, "serialization returns detached deep copies")
	var duplicate := profile.duplicate_profile()
	duplicate.set_bindings(&"fire", [_key(KEY_G)])
	_check((profile.get_bindings(&"fire")[0] as Dictionary).physical_keycode == KEY_F, "profile duplication does not alias mutable binding data")
	_check(not profile.set_bindings(&"", [_key(KEY_G)]), "empty actions cannot be assigned")
	_check(not profile.set_bindings(&"fire", [{"device": &"unknown", "type": &"key", "physical_keycode": KEY_G}]), "invalid assignments do not replace existing bindings")
	_check(profile.set_action_options(&"fire", {"deadzone": 0.4, "curve": &"squared", "hold_mode": &"toggle"}), "valid action options can be replaced")
	_check(not profile.set_action_options(&"fire", {"deadzone": -0.1, "curve": &"linear", "hold_mode": &"hold"}), "invalid action options are rejected")


func _test_conflicts_and_resolution() -> void:
	var profile := _profile_from({&"alpha": [_key(KEY_F), _joy_button(JOY_BUTTON_A)], &"bravo": [_key(KEY_G), _joy_button(JOY_BUTTON_A)], &"charlie": [_key(KEY_H)]}, {})
	var service := RebindService.new(profile)
	var conflicts := service.find_conflicts(profile, &"charlie", _joy_button(JOY_BUTTON_A))
	_check(conflicts.size() == 2, "conflicts find every action sharing a device binding")
	_check(conflicts[0].action == &"alpha" and conflicts[1].action == &"bravo", "conflicts are action-name deterministic")
	_check(int(conflicts[0].binding_index) == 1 and int(conflicts[1].binding_index) == 1, "conflicts retain stable per-action binding indices")
	_check(service.find_conflicts(profile, &"charlie", _key(KEY_F)).size() == 1, "same physical keyboard key conflicts")
	_check(service.find_conflicts(profile, &"charlie", _key(KEY_Z)).is_empty(), "unclaimed keys do not conflict")
	var rejected := service.rebind(profile, &"charlie", _key(KEY_F))
	_check(not bool(rejected.ok) and (rejected.profile as Profile) == profile, "default conflict policy rejects without replacing the profile")
	_check((profile.get_bindings(&"charlie")[0] as Dictionary).physical_keycode == KEY_H, "rejection leaves original action bindings unchanged")
	var replaced := service.rebind(profile, &"charlie", _joy_button(JOY_BUTTON_A), RebindService.CONFLICT_REPLACE)
	_check(bool(replaced.ok) and (replaced.conflicts as Array).size() == 2, "explicit replace policy accepts and reports conflicts")
	var updated := replaced.profile as Profile
	_check(updated.get_bindings(&"alpha").size() == 1 and updated.get_bindings(&"bravo").size() == 1, "replace removes duplicate binding from all prior actions")
	_check(updated.get_bindings(&"charlie").size() == 2, "replace preserves target bindings and appends the new binding")
	_check(profile.get_bindings(&"alpha").size() == 2 and profile.get_bindings(&"bravo").size() == 2, "rebind never mutates its input profile")
	_check(not bool(service.rebind(profile, &"charlie", _key(KEY_Z), &"discard").ok), "unknown conflict resolution is rejected")
	_check(RebindService.binding_signature(_key(KEY_F)) == "keyboard:key:%d" % KEY_F, "binding signatures are stable and device-specific")
	_check(RebindService.binding_signature({"device": &"keyboard", "type": &"key", "physical_keycode": 0}).is_empty(), "invalid bindings have no conflict signature")


func _test_defaults_reset_and_input_map_adapter() -> void:
	var action := &"input_rebind_service_probe"
	if InputMap.has_action(action):
		InputMap.erase_action(action)
	InputMap.add_action(action, 0.23)
	var original := InputEventKey.new()
	original.physical_keycode = KEY_F
	InputMap.action_add_event(action, original)
	var service := RebindService.new()
	var captured := service.capture_input_map(PackedStringArray([action]))
	_check(captured.get_bindings(action).size() == 1, "capture converts selected InputMap action bindings")
	_check(is_equal_approx(float(captured.get_action_options(action).deadzone), 0.23), "capture preserves InputMap deadzone")
	var reset := service.reset_to_defaults()
	_check(reset.to_dictionary() == service.get_defaults().to_dictionary(), "reset returns a detached default profile")
	var remapped := _profile_from({action: [_key(KEY_G), _motion(JOY_AXIS_LEFT_X, -1.0)]}, {action: {"deadzone": 0.41, "curve": &"linear", "hold_mode": &"hold"}})
	_check(service.apply_profile(remapped), "validated profiles can be explicitly applied to InputMap")
	_check(is_equal_approx(InputMap.action_get_deadzone(action), 0.41), "explicit apply updates the selected action deadzone")
	var after := service.capture_input_map(PackedStringArray([action]))
	_check(after.get_bindings(action).size() == 2, "explicit apply writes all device bindings")
	_check(RebindService.event_to_binding(InputMap.action_get_events(action)[0]).type == &"key", "adapter recreates keyboard input events")
	_check(not service.apply_profile(null), "null profiles cannot reach InputMap")
	InputMap.erase_action(action)


func _profile_from(bindings: Dictionary, options: Dictionary) -> Profile:
	return Profile.from_dictionary({"schema_version": Profile.SCHEMA_VERSION, "bindings": bindings, "action_options": options})


func _key(code: int) -> Dictionary:
	return {"device": Profile.DEVICE_KEYBOARD, "type": &"key", "physical_keycode": code}


func _mouse(button: int) -> Dictionary:
	return {"device": Profile.DEVICE_MOUSE, "type": &"mouse_button", "button_index": button}


func _joy_button(button: int) -> Dictionary:
	return {"device": Profile.DEVICE_GAMEPAD, "type": &"joy_button", "button_index": button}


func _motion(axis: int, direction: float) -> Dictionary:
	return {"device": Profile.DEVICE_GAMEPAD, "type": &"joy_motion", "axis": axis, "axis_value": direction}


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("INPUT_REBIND_SERVICE_TEST_OK")
		quit(0)
	else:
		print("INPUT_REBIND_SERVICE_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
