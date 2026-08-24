class_name CameraComfortSettingsBinding
extends RefCounted

## Caller-injected bridge from RuntimeSettings snapshots to
## CameraComfortPresenter. It owns neither settings nor camera behavior.

const PresenterType := preload("res://scripts/ui/camera_comfort_presenter.gd")
const ContractType := preload("res://scripts/control/landing_camera_comfort_contract.gd")
const REFRESH_SETTINGS: Array[StringName] = [
	&"camera_fov",
	&"reduced_motion",
	&"reduced_flash",
	&"on_foot_first_person",
	&"ui_scale",
]

var _settings: Object
var _presenter: RefCounted
var _generation := 0
var _settings_revision := 0
var _attached := false
var _view: Dictionary = {}


func attach(settings: Object, presenter: RefCounted = null) -> Dictionary:
	if settings == null or not is_instance_valid(settings) \
			or not settings.has_signal(&"setting_changed") \
			or not settings.has_method(&"to_dictionary"):
		return _reject(&"settings_contract_missing")
	var selected_presenter: RefCounted = presenter if presenter != null else PresenterType.new()
	if not selected_presenter.has_method(&"present") or not selected_presenter.has_method(&"detach"):
		return _reject(&"presenter_contract_missing")
	# Validate the complete replacement contract before disconnecting the live
	# settings owner or clearing its presenter. A rejected replacement is a
	# no-op, so the current summary and signal subscription remain usable.
	if _attached:
		detach()
	_settings = settings
	_presenter = selected_presenter
	_generation += 1
	_settings_revision = 0
	_attached = true
	_settings.connect(&"setting_changed", _on_setting_changed)
	_refresh()
	return {"accepted": true, "reason": &"bound", "generation": _generation, "presentation_only": true}


func detach() -> Dictionary:
	if is_instance_valid(_settings) and _settings.is_connected(&"setting_changed", _on_setting_changed):
		_settings.disconnect(&"setting_changed", _on_setting_changed)
	if _presenter != null:
		_presenter.detach()
	_settings = null
	_attached = false
	_generation += 1
	_settings_revision = 0
	_view = {"attached": false, "generation": _generation, "presentation_only": true, "settings_authority": false}
	return _view.duplicate(true)


func get_snapshot() -> Dictionary:
	var result := _view.duplicate(true)
	result["attached"] = _attached
	result["generation"] = _generation
	result["settings_revision"] = _settings_revision
	result["presentation_only"] = true
	result["settings_authority"] = false
	return result


func get_presenter() -> RefCounted:
	return _presenter


func _on_setting_changed(setting: StringName, _value: Variant) -> void:
	if not _attached or setting not in REFRESH_SETTINGS:
		return
	_refresh()


func _refresh() -> void:
	if not _attached or not is_instance_valid(_settings):
		return
	var source := _settings.call(&"to_dictionary") as Dictionary
	_settings_revision += 1
	var profile := ContractType.new().default_profile()
	profile[&"camera_fov"] = source.get(&"camera_fov", profile.camera_fov)
	var accessibility := {
		"settings_revision": _settings_revision,
		"reduced_motion": bool(source.get(&"reduced_motion", false)),
		"reduced_flash": bool(source.get(&"reduced_flash", false)),
		"on_foot_first_person": bool(source.get(&"on_foot_first_person", false)),
		"ui_scale": float(source.get(&"ui_scale", 1.0)),
	}
	var next_view: Dictionary = _presenter.call(&"present", profile, accessibility)
	if bool(next_view.get("accepted", false)):
		_view = next_view.duplicate(true)
		_view["generation"] = _generation
		_view["settings_authority"] = false


func _reject(reason: StringName) -> Dictionary:
	return {"accepted": false, "reason": reason, "generation": _generation, "presentation_only": true, "settings_authority": false}
