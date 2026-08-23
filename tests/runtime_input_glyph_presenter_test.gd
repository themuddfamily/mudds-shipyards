extends SceneTree

const Presenter := preload("res://scripts/ui/runtime_input_glyph_presenter.gd")
const Resolver := preload("res://scripts/ui/input_glyph_resolver.gd")
const RebindService := preload("res://scripts/settings/input_rebind_service.gd")

var _assertions := 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var presenter := Presenter.new(Resolver.new())
	var profile := RebindService.new().get_defaults()
	var attached := presenter.attach(profile)
	_check(bool(attached.attached) and attached.rows.size() == Presenter.CORE_ACTIONS.size(), "core-loop glyph rows attach from caller profile")
	var keyboard := attached.rows[1] as Dictionary
	_check(keyboard.action == &"interact" and keyboard.valid and keyboard.device_family == &"keyboard", "keyboard bindings resolve to readable labels")
	_check(bool(presenter.set_device_family(&"gamepad_xbox").attached), "Xbox family selection is presentation-only")
	var xbox := presenter.get_snapshot().rows[1] as Dictionary
	_check(xbox.device_family == &"gamepad_xbox" and xbox.text != "Unbound Input", "Xbox-style controller glyph labels resolve")
	var remapped := profile.duplicate_profile()
	var replacement := {"device": &"keyboard", "type": &"key", "physical_keycode": KEY_TAB}
	_check(remapped.set_bindings(&"interact", [replacement]), "caller remap profile is accepted")
	presenter.set_device_family(&"keyboard")
	var refreshed := presenter.refresh(remapped)
	_check((refreshed.rows[1] as Dictionary).text == "Tab", "remapped bindings refresh the visible glyph")
	var known := presenter.get_snapshot().rows[0] as Dictionary
	_check(known.valid, "known core actions remain valid after refresh")
	var unknown := presenter.resolve_action(&"not_a_core_action")
	_check(not bool(unknown.get("valid", true)) and unknown.get("text") == "Unbound Input", "unknown actions use the readable fallback")
	presenter.detach()
	_check(not bool(presenter.get_snapshot().attached) and presenter.get_snapshot().rows.is_empty(), "detach removes retained glyph rows")
	var reentered := presenter.attach(remapped)
	_check(bool(reentered.attached) and reentered.rows.size() == Presenter.CORE_ACTIONS.size(), "re-entry rebuilds detached glyph presentation")
	var invalid := presenter.set_device_family(&"not-a-device")
	_check(not bool(invalid.get("accepted", true)) and bool(presenter.get_snapshot().presentation_only), "unknown family rejects without input authority")
	if _failures.is_empty():
		print("RUNTIME_INPUT_GLYPH_PRESENTER_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)
