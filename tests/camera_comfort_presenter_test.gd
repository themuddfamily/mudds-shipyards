extends SceneTree

const ContractType := preload("res://scripts/control/landing_camera_comfort_contract.gd")
const PresenterType := preload("res://scripts/ui/camera_comfort_presenter.gd")
var _assertions := 0
var _failures: PackedStringArray = []

func _init() -> void:
	call_deferred(&"_run")

func _run() -> void:
	var presenter := PresenterType.new()
	var profile := ContractType.new().default_profile()
	var view := presenter.present(profile, {"reduced_motion": true, "reduced_flash": true})
	_check(bool(view.get("accepted", false)) and bool(view.get("focusable", false)), "valid comfort profile produces a focusable presentation")
	_check(str(view.get("text", "")).contains("CAMERA COMFORT  //  REDUCED MOTION") and str(view.get("text", "")).contains("STEADY CAMERA TRANSITIONS"), "reduced-motion guidance is text-first")
	_check(str(view.get("text", "")).contains("FIELD OF VIEW") and str(view.get("text", "")).contains("LANDING"), "camera and landing comfort bounds are readable")
	_check(str(view.get("text", "")).contains("REDUCED FLASH  //  ON") and not bool(view.get("camera_authority", true)), "reduced flash and authority boundary are explicit")
	var malformed := profile.duplicate(true)
	malformed[&"camera_fov"] = 999.0
	var rejected := presenter.present(malformed)
	_check(not bool(rejected.get("accepted", true)) and not bool(presenter.get_snapshot().get("attached", true)), "malformed profile rejects atomically")
	var detached := presenter.detach()
	_check(not bool(detached.get("attached", true)), "detach clears the presentation")
	var reentered := presenter.present(profile)
	_check(bool(reentered.get("accepted", false)) and reentered.get("mode") == &"standard", "re-entry rebuilds a fresh standard comfort view")
	if _failures.is_empty():
		print("CAMERA_COMFORT_PRESENTER_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)
