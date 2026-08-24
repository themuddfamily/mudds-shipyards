class_name CameraComfortPresenter
extends RefCounted

## Detached player-facing summary for LandingCameraComfortContract profiles.
## This presenter validates and describes caller-provided tuning; it never
## moves a camera, changes a ship, or owns an accessibility setting.

const ContractType := preload("res://scripts/control/landing_camera_comfort_contract.gd")

var _attached := false
var _settings_revision := -1
var _view: Dictionary = {}


func present(profile: Dictionary, accessibility: Dictionary = {}) -> Dictionary:
	var revision_value: Variant = accessibility.get("settings_revision", 0)
	if not revision_value is int or int(revision_value) < 0:
		return _reject(&"invalid_settings_revision")
	var settings_revision := int(revision_value)
	if _settings_revision >= 0 and settings_revision < _settings_revision:
		return _reject(&"stale_settings_revision")
	var state_error := _validate_settings_state(accessibility)
	if not state_error.is_empty():
		return _reject(state_error)
	var validation := ContractType.new().validate_profile(profile)
	if not bool(validation.get("accepted", false)):
		_attached = false
		_settings_revision = settings_revision
		_view = {
			"accepted": false,
			"reason": &"invalid_profile",
			"errors": validation.get("errors", PackedStringArray()),
			"settings_revision": _settings_revision,
			"presentation_only": true,
			"camera_authority": false,
			"input_authority": false,
		}
		return _view.duplicate(true)
	var reduced_motion := bool(accessibility.get("reduced_motion", false))
	var reduced_flash := bool(accessibility.get("reduced_flash", false))
	var on_foot_first_person := bool(accessibility.get("on_foot_first_person", false))
	var ui_scale := float(accessibility.get("ui_scale", 1.0))
	var safe_area := accessibility.get("safe_area", Rect2()) as Rect2
	var controller_focus := StringName(accessibility.get("controller_focus", &""))
	var mode := "REDUCED MOTION" if reduced_motion else "STANDARD MOTION"
	var shake := "REDUCED" if reduced_motion else "STANDARD"
	var flash := "REDUCED" if reduced_flash else "STANDARD"
	var transition := "STEADY" if reduced_motion else "STANDARD"
	var lines := PackedStringArray([
		"CAMERA COMFORT  //  %s" % mode,
		"SHAKE  //  %s  ·  MOTION  //  %s  ·  FLASH  //  %s" % [shake, transition, flash],
		"CHASE COMFORT  //  %.0f° FOV  ·  FOLLOW LAG ≤ %.1f°  ·  BANK ≤ %.1f°" % [
			float(profile.get("camera_fov", 0.0)),
			float(profile.get("maximum_chase_camera_rotation_lag_degrees", 0.0)),
			float(profile.get("maximum_chase_camera_bank_degrees", 0.0)),
		],
		"ON-FOOT VIEW  //  %s" % ("FIRST PERSON" if on_foot_first_person else "CHASE"),
		"LANDING  ≤ %.1f m/s  //  TILT ≤ %.1f°" % [
			float(profile.get("landing_capture_maximum_speed", 0.0)),
			float(profile.get("landing_capture_maximum_tilt_degrees", 0.0)),
		],
	])
	_attached = true
	_settings_revision = settings_revision
	_view = {
		"accepted": true,
		"mode": StringName("reduced_motion" if reduced_motion else "standard"),
		"text": "\n".join(lines),
		"profile": profile.duplicate(true),
		"settings_revision": settings_revision,
		"reduced_motion": reduced_motion,
		"reduced_flash": reduced_flash,
		"on_foot_first_person": on_foot_first_person,
		"ui_scale": ui_scale,
		"safe_area": safe_area,
		"controller_focus": controller_focus,
		"focus_order": [&"camera_comfort_summary"],
		"focus_requested": false,
		"focusable": true,
		"color_independent": true,
		"presentation_only": true,
		"camera_authority": false,
		"input_authority": false,
	}.duplicate(true)
	return _view.duplicate(true)


func detach() -> Dictionary:
	_attached = false
	_settings_revision = -1
	_view = {"accepted": true, "attached": false, "presentation_only": true, "camera_authority": false, "input_authority": false}
	return _view.duplicate(true)


func get_snapshot() -> Dictionary:
	var result := _view.duplicate(true)
	result["attached"] = _attached
	return result


func _validate_settings_state(state: Dictionary) -> StringName:
	for key: StringName in [&"reduced_motion", &"reduced_flash", &"on_foot_first_person"]:
		if state.has(key) and not state.get(key) is bool:
			return &"invalid_settings_state"
	var ui_scale_value: Variant = state.get("ui_scale", 1.0)
	if not (ui_scale_value is int or ui_scale_value is float) \
		or not is_finite(float(ui_scale_value)) or float(ui_scale_value) <= 0.0:
		return &"invalid_ui_scale"
	var safe_area_value: Variant = state.get("safe_area", Rect2())
	if not safe_area_value is Rect2:
		return &"invalid_safe_area"
	var safe_area := safe_area_value as Rect2
	if safe_area.position.x < 0.0 or safe_area.position.y < 0.0 \
		or safe_area.size.x < 0.0 or safe_area.size.y < 0.0:
		return &"invalid_safe_area"
	var focus_value: Variant = state.get("controller_focus", &"")
	if not (focus_value is String or focus_value is StringName):
		return &"invalid_controller_focus"
	return &""


func _reject(reason: StringName) -> Dictionary:
	return {
		"accepted": false,
		"reason": reason,
		"settings_revision": _settings_revision,
		"presentation_only": true,
		"camera_authority": false,
		"input_authority": false,
	}
