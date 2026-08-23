class_name CameraComfortPresenter
extends RefCounted

## Detached player-facing summary for LandingCameraComfortContract profiles.
## This presenter validates and describes caller-provided tuning; it never
## moves a camera, changes a ship, or owns an accessibility setting.

const ContractType := preload("res://scripts/control/landing_camera_comfort_contract.gd")

var _attached := false
var _view: Dictionary = {}


func present(profile: Dictionary, accessibility: Dictionary = {}) -> Dictionary:
	var validation := ContractType.new().validate_profile(profile)
	if not bool(validation.get("accepted", false)):
		_attached = false
		_view = {"accepted": false, "reason": &"invalid_profile", "errors": validation.get("errors", PackedStringArray()), "presentation_only": true}
		return _view.duplicate(true)
	var reduced_motion := bool(accessibility.get("reduced_motion", false))
	var reduced_flash := bool(accessibility.get("reduced_flash", false))
	var mode := "REDUCED MOTION" if reduced_motion else "STANDARD MOTION"
	var transition := "STEADY CAMERA TRANSITIONS" if reduced_motion else "AUTHORED CAMERA TRANSITIONS"
	var lines := PackedStringArray([
		"CAMERA COMFORT  //  %s" % mode,
		"FIELD OF VIEW  %.0f°  //  CHASE LAG ≤ %.1f°  //  BANK ≤ %.1f°" % [
			float(profile.get("camera_fov", 0.0)),
			float(profile.get("maximum_chase_camera_rotation_lag_degrees", 0.0)),
			float(profile.get("maximum_chase_camera_bank_degrees", 0.0)),
		],
		"LANDING  ≤ %.1f m/s  //  TILT ≤ %.1f°" % [
			float(profile.get("landing_capture_maximum_speed", 0.0)),
			float(profile.get("landing_capture_maximum_tilt_degrees", 0.0)),
		],
		transition,
		"REDUCED FLASH  //  %s" % ("ON" if reduced_flash else "OFF"),
	])
	_attached = true
	_view = {
		"accepted": true,
		"mode": StringName("reduced_motion" if reduced_motion else "standard"),
		"text": "\n".join(lines),
		"profile": profile.duplicate(true),
		"reduced_motion": reduced_motion,
		"reduced_flash": reduced_flash,
		"focusable": true,
		"color_independent": true,
		"presentation_only": true,
		"camera_authority": false,
		"input_authority": false,
	}.duplicate(true)
	return _view.duplicate(true)


func detach() -> Dictionary:
	_attached = false
	_view = {"attached": false, "presentation_only": true, "camera_authority": false}
	return _view.duplicate(true)


func get_snapshot() -> Dictionary:
	var result := _view.duplicate(true)
	result["attached"] = _attached
	return result
