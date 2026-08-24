extends SceneTree

const PresenterType := preload("res://scripts/ui/camera_comfort_presenter.gd")
const BindingType := preload("res://scripts/ui/camera_comfort_settings_binding.gd")
var _assertions := 0
var _failures: PackedStringArray = []

class RuntimeSettingsFixture extends RefCounted:
	signal setting_changed(setting: StringName, value: Variant)

	var camera_fov := 72.0:
		set(value):
			camera_fov = value
			setting_changed.emit(&"camera_fov", value)
	var reduced_motion := false:
		set(value):
			reduced_motion = value
			setting_changed.emit(&"reduced_motion", value)
	var reduced_flash := false:
		set(value):
			reduced_flash = value
			setting_changed.emit(&"reduced_flash", value)
	var on_foot_first_person := false:
		set(value):
			on_foot_first_person = value
			setting_changed.emit(&"on_foot_first_person", value)
	var ui_scale := 1.0:
		set(value):
			ui_scale = value
			setting_changed.emit(&"ui_scale", value)

	func to_dictionary() -> Dictionary:
		return {
			"camera_fov": camera_fov,
			"reduced_motion": reduced_motion,
			"reduced_flash": reduced_flash,
			"on_foot_first_person": on_foot_first_person,
			"ui_scale": ui_scale,
		}

class PresentOnlyFixture extends RefCounted:
	var present_calls := 0

	func present(_profile: Dictionary, _accessibility: Dictionary = {}) -> Dictionary:
		present_calls += 1
		return {"accepted": true}

func _init() -> void:
	call_deferred(&"_run")

func _run() -> void:
	var settings := RuntimeSettingsFixture.new()
	var incomplete_presenter := PresentOnlyFixture.new()
	var rejected_binding := BindingType.new()
	var incomplete := rejected_binding.attach(settings, incomplete_presenter)
	_check(not bool(incomplete.get("accepted", true)) and incomplete.reason == &"presenter_contract_missing", "present-only presenter is rejected before attachment")
	settings.camera_fov = 74.0
	_check(incomplete_presenter.present_calls == 0 and not rejected_binding.get_snapshot().attached, "rejected presenter receives no refresh or later invalid lifecycle call")
	var presenter := PresenterType.new()
	var binding := BindingType.new()
	_check(bool(binding.attach(settings, presenter).get("accepted", false)), "binding attaches to read-only RuntimeSettings signal seam")
	_check(binding.get_snapshot().attached and not bool(binding.get_snapshot().get("settings_authority", true)), "binding is attached without settings authority")
	var initial := presenter.get_snapshot()
	_check(initial.mode == &"standard" and str(initial.text).contains("FIELD OF VIEW  74°"), "current settings become the initial comfort profile")
	settings.camera_fov = 90.0
	settings.reduced_motion = true
	settings.reduced_flash = true
	settings.on_foot_first_person = true
	settings.ui_scale = 1.35
	var changed := presenter.get_snapshot()
	_check(changed.mode == &"reduced_motion" and str(changed.text).contains("FIELD OF VIEW  90°"), "accepted setting changes refresh the presenter")
	_check(str(changed.text).contains("REDUCED FLASH  //  ON") and binding.get_snapshot().generation == 1, "accessibility flags and binding generation remain deterministic")
	_check(changed.on_foot_first_person and str(changed.text).contains("ON-FOOT VIEW  //  FIRST PERSON"), "real first-person setting changes refresh the visible summary")
	_check(changed.ui_scale == 1.35 and binding.get_snapshot().settings_revision == changed.settings_revision, "real UI scale changes are forwarded with the binding settings revision")
	var retained_generation := int(binding.get_snapshot().generation)
	var invalid_replacement := binding.attach(RefCounted.new(), presenter)
	_check(
		not bool(invalid_replacement.get("accepted", true))
			and invalid_replacement.reason == &"settings_contract_missing"
			and binding.get_snapshot().attached
			and int(binding.get_snapshot().generation) == retained_generation
			and presenter.get_snapshot().attached,
		"invalid replacement settings preserve the live binding and presenter atomically"
	)
	var incomplete_replacement := binding.attach(settings, incomplete_presenter)
	_check(
		not bool(incomplete_replacement.get("accepted", true))
			and incomplete_replacement.reason == &"presenter_contract_missing"
			and binding.get_snapshot().attached
			and int(binding.get_snapshot().generation) == retained_generation
			and incomplete_presenter.present_calls == 0,
		"invalid replacement presenter preserves the live subscription without receiving a refresh"
	)
	settings.camera_fov = 91.0
	_check(
		str(presenter.get_snapshot().text).contains("FIELD OF VIEW  91°")
			and binding.get_snapshot().settings_revision == presenter.get_snapshot().settings_revision,
		"the original settings owner still refreshes after rejected replacement attempts"
	)
	binding.detach()
	_check(not presenter.get_snapshot().attached, "valid presenter receives its complete detach lifecycle")
	settings.camera_fov = 60.0
	_check(not bool(presenter.get_snapshot().get("attached", true)), "detach prevents later settings signals from refreshing")
	_check(bool(binding.attach(settings, presenter).get("accepted", false)), "re-entry rebinds the same presenter cleanly")
	_check(str(presenter.get_snapshot().text).contains("FIELD OF VIEW  60°"), "re-entry reads a fresh detached settings snapshot")
	var invalid := BindingType.new().attach(RefCounted.new(), presenter)
	_check(not bool(invalid.get("accepted", true)) and invalid.reason == &"settings_contract_missing", "invalid settings owner fails closed")
	binding.detach()
	presenter.detach()
	settings = null
	presenter = null
	binding = null
	await process_frame
	if _failures.is_empty():
		print("CAMERA_COMFORT_SETTINGS_BINDING_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)
