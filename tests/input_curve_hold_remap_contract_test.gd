extends SceneTree

const Profile := preload("res://scripts/settings/input_binding_profile.gd")
const Contract := preload("res://scripts/input/input_curve_hold_remap_contract.gd")

var _failures: Array[String] = []
var _assertions := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var defaults := _profile()
	var contract := Contract.new(defaults)
	_check(contract.is_valid() and contract.get_revision() == 0, "complete defaults create a revision-zero contract")
	var preview := contract.preview_options(&"fire", 0.25, Profile.CURVE_SQUARED, Profile.TOGGLE)
	_check(bool(preview.accepted) and contract.get_revision() == 0, "valid deadzone, curve, and hold-toggle options preview without mutation")
	_check(preview.options.deadzone == 0.25 and preview.options.curve == Profile.CURVE_SQUARED and preview.options.hold_mode == Profile.TOGGLE, "preview preserves the exact validated option vocabulary")
	var committed := contract.commit_options(&"fire", 0.25, Profile.CURVE_SQUARED, Profile.TOGGLE, 0)
	_check(bool(committed.accepted) and contract.get_revision() == 1, "option commit advances one shared revision")
	_check(contract.get_profile().get_action_options(&"fire") == preview.options, "committed options are retained in the detached profile")
	var invalid_deadzone := contract.commit_options(&"fire", -0.01, Profile.CURVE_LINEAR, Profile.HOLD, 1)
	var invalid_curve := contract.commit_options(&"fire", 0.2, &"cubic", Profile.HOLD, 1)
	var invalid_mode := contract.commit_options(&"fire", 0.2, Profile.CURVE_LINEAR, &"pulse", 1)
	_check(not bool(invalid_deadzone.accepted) and invalid_deadzone.reason == &"invalid_options", "negative deadzones fail closed")
	_check(not bool(invalid_curve.accepted) and not bool(invalid_mode.accepted) and contract.get_revision() == 1, "unsupported curves and hold modes fail closed without revision changes")
	var stale := contract.commit_options(&"fire", 0.3, Profile.CURVE_LINEAR, Profile.HOLD, 0)
	_check(not bool(stale.accepted) and stale.reason == &"stale_revision" and contract.get_revision() == 1, "stale option callbacks cannot overwrite a newer profile")
	var reject := contract.commit_binding(&"brake", _key(KEY_F), 1)
	_check(not bool(reject.accepted) and reject.reason == &"conflict" and contract.get_revision() == 1, "binding conflicts share the option revision and reject atomically")
	var replace_preview := contract.preview_binding(&"brake", _key(KEY_F), Contract.CONFLICT_REPLACE)
	_check(bool(replace_preview.accepted) and (replace_preview.conflicts as Array).size() == 1 and contract.get_revision() == 1, "binding replacement previews its conflict without mutation")
	var replace := contract.commit_binding(&"brake", _key(KEY_F), 1, Contract.CONFLICT_REPLACE)
	_check(bool(replace.accepted) and contract.get_revision() == 2, "binding replacement commits as one shared revision")
	_check(contract.get_profile().get_bindings(&"fire").is_empty() and contract.get_profile().get_bindings(&"brake").size() == 2, "replacement removes the prior owner while retaining the target roster")
	var reset_stale := contract.reset(1)
	var reset := contract.reset(2)
	_check(not bool(reset_stale.accepted) and reset_stale.reason == &"stale_revision" and bool(reset.accepted) and contract.get_revision() == 3, "reset uses the same revision guard and restores defaults")
	_check(contract.get_profile().to_dictionary() == defaults.to_dictionary(), "reset restores both bindings and curve/hold options together")
	if _failures.is_empty():
		print("INPUT_CURVE_HOLD_REMAP_CONTRACT_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		for failure: String in _failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)


func _profile() -> InputBindingProfile:
	return Profile.from_dictionary({
		"schema_version": Profile.SCHEMA_VERSION,
		"bindings": {
			&"fire": [_key(KEY_F)],
			&"brake": [_key(KEY_B)],
		},
		"action_options": {
			&"fire": Profile.default_action_options(),
			&"brake": Profile.default_action_options(),
		},
	})


func _key(code: int) -> Dictionary:
	return {"device": Profile.DEVICE_KEYBOARD, "type": &"key", "physical_keycode": code}
