extends SceneTree

const Profile := preload("res://scripts/settings/input_binding_profile.gd")
const Contract := preload("res://scripts/input/runtime_input_remap_contract.gd")
var _failures: Array[String] = []
var _assertions := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var defaults := _profile()
	var contract := Contract.new(defaults)
	_check(contract.is_valid(), "complete defaults create a valid detached remap contract")
	var before := contract.get_profile().to_dictionary()
	var rejected := contract.commit(&"bravo", _key(KEY_F), 0)
	_check(not bool(rejected.accepted) and rejected.reason == &"conflict", "reject policy reports a conflict without committing")
	_check(contract.get_revision() == 0 and contract.get_profile().to_dictionary() == before, "rejected remap leaves revision and profile unchanged")
	var preview := contract.preview(&"bravo", _key(KEY_F), Contract.CONFLICT_REPLACE)
	_check(bool(preview.accepted) and (preview.conflicts as Array).size() == 1 and contract.get_revision() == 0, "replace preview reports one conflict without mutation")
	var committed := contract.commit(&"bravo", _key(KEY_F), 0, Contract.CONFLICT_REPLACE)
	_check(bool(committed.accepted) and contract.get_revision() == 1, "explicit replace commits exactly one revision")
	_check(contract.get_profile().get_bindings(&"alpha").size() == 1 and contract.get_profile().get_bindings(&"bravo").size() == 2, "replace removes the old owner and preserves target bindings")
	var stale := contract.commit(&"alpha", _key(KEY_G), 0)
	_check(not bool(stale.accepted) and stale.reason == &"stale_revision" and contract.get_revision() == 1, "stale menu callback cannot overwrite newer remap")
	var invalid := contract.commit(&"missing", _key(KEY_Z), 1)
	_check(not bool(invalid.accepted) and invalid.reason == &"invalid_request", "unknown action fails closed without mutation")
	var reset := contract.reset(1)
	_check(bool(reset.accepted) and contract.get_revision() == 2 and contract.get_profile().to_dictionary() == defaults.to_dictionary(), "reset restores defaults as one revisioned transaction")
	if _failures.is_empty():
		print("RUNTIME_INPUT_REMAP_CONTRACT_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		for failure: String in _failures: push_error(failure)
		quit(1)

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition: _failures.append("FAIL: " + message)

func _profile() -> InputBindingProfile:
	return Profile.from_dictionary({"schema_version": 1, "bindings": {
		&"alpha": [_key(KEY_F), _joy_button(JOY_BUTTON_A)],
		&"bravo": [_key(KEY_H)]
	}, "action_options": {
		&"alpha": Profile.default_action_options(), &"bravo": Profile.default_action_options()
	}})

func _key(code: int) -> Dictionary:
	return {"device": Profile.DEVICE_KEYBOARD, "type": &"key", "physical_keycode": code}

func _joy_button(index: int) -> Dictionary:
	return {"device": Profile.DEVICE_GAMEPAD, "type": &"joy_button", "button_index": index}
