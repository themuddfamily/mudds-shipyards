extends SceneTree

const Presenter := preload("res://scripts/ui/runtime_input_rebind_presenter.gd")
const Service := preload("res://scripts/settings/input_rebind_service.gd")

var _assertions := 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var service := Service.new()
	var presenter := Presenter.new(service)
	var profile := service.get_defaults()
	var attached := presenter.attach(profile)
	_check(bool(attached.attached) and not attached.rows.is_empty(), "attach lists the caller profile actions")
	var generation := int(attached.generation)
	var interact := presenter.begin_capture(&"interact", generation)
	_check(bool(interact.accepted) and interact.intent == &"capture_requested", "known action starts a capture generation")
	var jump_bindings := profile.get_bindings(&"jump")
	var candidate: Dictionary = jump_bindings[0] if not jump_bindings.is_empty() else {}
	var conflict := presenter.capture_replacement(&"interact", candidate, generation)
	_check(not bool(conflict.accepted) and not conflict.has("reason") and conflict.intent == &"conflict", "conflicting capture remains pending")
	_check((conflict.choices as Array).size() == 2, "conflict exposes replace and cancel choices")
	var replaced := presenter.resolve_conflict(&"replace", generation)
	_check(bool(replaced.accepted) and replaced.intent == &"profile_changed", "replace applies through a detached profile intent")
	_check((presenter.get_snapshot().rows as Array).size() == attached.rows.size(), "applied profile refreshes all glyph rows")
	var stale := presenter.begin_capture(&"interact", generation - 1)
	_check(not bool(stale.accepted) and stale.reason == &"stale_generation", "stale capture generations are rejected")
	var malformed := presenter.begin_capture(&"interact", generation)
	var invalid := presenter.capture_replacement(&"interact", {}, generation)
	_check(bool(malformed.accepted) and not bool(invalid.accepted) and invalid.reason == &"invalid_binding", "malformed bindings are rejected")
	var unknown := presenter.begin_capture(&"not_an_action", generation)
	_check(not bool(unknown.accepted) and unknown.reason == &"unknown_action", "unknown actions are rejected")
	var reset := presenter.reset_action(&"interact", generation)
	_check(bool(reset.accepted) and reset.intent == &"profile_changed", "reset returns a caller-owned profile intent")
	presenter.detach()
	var detached := presenter.capture_replacement(&"interact", candidate, generation)
	_check(not bool(detached.accepted) and detached.reason == &"detached", "detached presenter rejects stale input")
	var reentered := presenter.attach(profile)
	_check(bool(reentered.attached) and int(reentered.generation) != generation, "re-entry fences the previous generation")
	_check(bool(reentered.presentation_only) and bool(reentered.persistence_owned_by_caller), "snapshot advertises authority boundaries")
	if _failures.is_empty():
		print("RUNTIME_INPUT_REBIND_PRESENTER_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)
