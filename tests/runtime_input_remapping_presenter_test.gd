extends SceneTree

const Profile := preload("res://scripts/settings/input_binding_profile.gd")
const Controller := preload("res://scripts/settings/runtime_input_remapping_controller.gd")
const Presenter := preload("res://scripts/ui/runtime_input_remapping_presenter.gd")

var _failures: Array[String] = []
var _assertions := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var fire := &"runtime_presenter_fire"
	var brake := &"runtime_presenter_brake"
	for action: StringName in [fire, brake]:
		if InputMap.has_action(action):
			InputMap.erase_action(action)
		InputMap.add_action(action)
	InputMap.action_add_event(fire, _event_key(KEY_F))
	InputMap.action_add_event(brake, _event_key(KEY_B))
	var defaults := Profile.from_dictionary({
		"schema_version": Profile.SCHEMA_VERSION,
		"bindings": {fire: [_key(KEY_F)], brake: [_key(KEY_B)]},
		"action_options": {fire: Profile.default_action_options(), brake: Profile.default_action_options()},
	})
	var presenter := Presenter.new(Controller.new(defaults, null, &"xbox"))
	var initial := presenter.get_snapshot()
	_check(bool(initial.valid) and initial.controller_family == &"xbox" and (initial.rows as Array).size() == 2, "presenter exposes valid controller-family state and deterministic action rows")
	var conflict := presenter.submit_binding(brake, _key(KEY_F))
	_check(conflict.status == &"conflict" and not (conflict.pending_conflict as Dictionary).is_empty() and conflict.revision == 0, "conflicting capture is visible as pending player choice")
	var cancelled := presenter.cancel_pending_conflict()
	_check(cancelled.status == &"idle" and (cancelled.pending_conflict as Dictionary).is_empty() and _mapped_key(brake) == KEY_B, "cancel clears the conflict without changing the live binding")
	presenter.submit_binding(brake, _key(KEY_F))
	var replaced := presenter.replace_pending_conflict()
	_check(replaced.status == &"committed" and (replaced.pending_conflict as Dictionary).is_empty() and replaced.revision == 1, "explicit replace commits and clears the pending conflict")
	_check(_has_mapped_key(brake, KEY_F) and _mapped_key(fire) == -1, "presenter replacement is reflected in the player-facing live map")
	var options := presenter.commit_options(brake, 0.4, Profile.CURVE_SQUARED, Profile.TOGGLE)
	_check(options.status == &"committed" and options.revision == 2 and options.rows[0].options.curve == Profile.CURVE_SQUARED, "presenter exposes committed curve and hold-toggle options")
	var reset := presenter.reset()
	_check(reset.status == &"committed" and reset.revision == 3 and _mapped_key(fire) == KEY_F and _mapped_key(brake) == KEY_B, "reset returns the visible rows and live bindings to defaults")
	for action: StringName in [fire, brake]:
		if InputMap.has_action(action):
			InputMap.erase_action(action)
	if _failures.is_empty():
		print("RUNTIME_INPUT_REMAPPING_PRESENTER_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		for failure: String in _failures:
			push_error(failure)
		quit(1)


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
