extends SceneTree

const SettingsType := preload("res://scripts/settings/runtime_settings.gd")
const PresenterType := preload("res://scripts/ui/camera_comfort_presenter.gd")
const BindingType := preload("res://scripts/ui/camera_comfort_settings_binding.gd")
var _assertions := 0
var _failures: PackedStringArray = []

func _init() -> void:
	call_deferred(&"_run")

func _run() -> void:
	var settings := SettingsType.new("memory://camera-comfort-binding.cfg")
	var presenter := PresenterType.new()
	var binding := BindingType.new()
	_check(bool(binding.attach(settings, presenter).get("accepted", false)), "binding attaches to read-only RuntimeSettings signal seam")
	_check(binding.get_snapshot().attached and not bool(binding.get_snapshot().get("settings_authority", true)), "binding is attached without settings authority")
	var initial := presenter.get_snapshot()
	_check(initial.mode == &"standard" and str(initial.text).contains("FIELD OF VIEW  72°"), "initial settings become the default comfort profile")
	settings.camera_fov = 90.0
	settings.reduced_motion = true
	settings.reduced_flash = true
	var changed := presenter.get_snapshot()
	_check(changed.mode == &"reduced_motion" and str(changed.text).contains("FIELD OF VIEW  90°"), "accepted setting changes refresh the presenter")
	_check(str(changed.text).contains("REDUCED FLASH  //  ON") and binding.get_snapshot().generation == 1, "accessibility flags and binding generation remain deterministic")
	binding.detach()
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
