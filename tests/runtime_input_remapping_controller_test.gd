extends SceneTree

const Profile := preload("res://scripts/settings/input_binding_profile.gd")
const Controller := preload("res://scripts/settings/runtime_input_remapping_controller.gd")

var _failures: Array[String] = []
var _assertions := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var fire := &"runtime_controller_fire"
	var brake := &"runtime_controller_brake"
	for action: StringName in [fire, brake]:
		if InputMap.has_action(action):
			InputMap.erase_action(action)
		InputMap.add_action(action)
	InputMap.action_add_event(fire, _event_key(KEY_F))
	InputMap.action_add_event(brake, _event_key(KEY_B))
	var defaults := _profile(fire, brake, KEY_F, KEY_B)
	var controller := Controller.new(defaults, null, &"xbox")
	_check(controller.is_valid() and controller.get_controller_family() == &"xbox", "controller retains valid family metadata")
	var before := controller.get_profile().to_dictionary()
	var preview := controller.preview_binding(brake, _key(KEY_F))
	_check(not bool(preview.accepted) and preview.reason == &"conflict", "conflicting preview rejects without mutation")
	_check(controller.get_revision() == 0 and controller.get_profile().to_dictionary() == before and _mapped_key(brake) == KEY_B, "preview leaves revision, profile, and live map unchanged")
	var committed := controller.commit_binding(brake, _key(KEY_F), 0, Controller.CONFLICT_REPLACE)
	_check(bool(committed.accepted) and committed.reason == &"committed" and committed.controller_family == &"xbox", "replace commit reports runtime controller metadata")
	_check(controller.get_revision() == 1 and _mapped_key(fire) == -1 and _has_mapped_key(brake, KEY_F), "replace commit transfers the live binding atomically")
	var stale := controller.commit_binding(fire, _key(KEY_G), 0)
	_check(not bool(stale.accepted) and stale.reason == &"stale_revision" and _mapped_key(fire) == -1, "stale callbacks cannot write the live map")
	var option_preview := controller.preview_options(brake, 0.42, Profile.CURVE_SQUARED, Profile.TOGGLE)
	_check(bool(option_preview.accepted) and controller.get_revision() == 1, "option preview shares the remap revision without mutation")
	var option_commit := controller.commit_options(brake, 0.42, Profile.CURVE_SQUARED, Profile.TOGGLE, 1)
	_check(bool(option_commit.accepted) and controller.get_revision() == 2 and is_equal_approx(float(controller.get_profile().get_action_options(brake).deadzone), 0.42), "option commit retains validated curve and hold-toggle data")
	var reset := controller.reset(2)
	_check(bool(reset.accepted) and controller.get_revision() == 3 and _mapped_key(fire) == KEY_F and _mapped_key(brake) == KEY_B, "reset restores defaults in the live map")
	for action: StringName in [fire, brake]:
		if InputMap.has_action(action):
			InputMap.erase_action(action)
	if _failures.is_empty():
		print("RUNTIME_INPUT_REMAPPING_CONTROLLER_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		for failure: String in _failures:
			push_error(failure)
		quit(1)


func _profile(fire: StringName, brake: StringName, fire_key: int, brake_key: int) -> InputBindingProfile:
	return Profile.from_dictionary({
		"schema_version": Profile.SCHEMA_VERSION,
		"bindings": {fire: [_key(fire_key)], brake: [_key(brake_key)]},
		"action_options": {fire: Profile.default_action_options(), brake: Profile.default_action_options()},
	})


func _key(code: int) -> Dictionary:
	return {"device": Profile.DEVICE_KEYBOARD, "type": &"key", "physical_keycode": code}


func _event_key(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	return event


func _mapped_key(action: StringName) -> int:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			return (event as InputEventKey).physical_keycode
	return -1


func _has_mapped_key(action: StringName, code: int) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == code:
			return true
	return false


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
