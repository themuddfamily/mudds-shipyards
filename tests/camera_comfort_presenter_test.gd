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
	var safe_area := Rect2(24.0, 18.0, 30.0, 22.0)
	var view := presenter.present(profile, {
		"settings_revision": 12,
		"reduced_motion": true,
		"reduced_flash": true,
		"on_foot_first_person": true,
		"ui_scale": 1.35,
		"safe_area": safe_area,
		"controller_focus": &"camera_comfort_summary",
	})
	_check(bool(view.get("accepted", false)) and bool(view.get("focusable", false)), "valid comfort profile produces a focusable presentation")
	_check(not str(view.get("text", "")).contains("SHAKE") and str(view.get("text", "")).contains("MOTION  //  STEADY") and str(view.get("text", "")).contains("REDUCED FLASH  //  ON"), "motion and flash settings are confirmed without inventing shake support")
	_check(str(view.get("text", "")).contains("FIELD OF VIEW  72°") and str(view.get("text", "")).contains("CHASE COMFORT") and str(view.get("text", "")).contains("ON-FOOT VIEW  //  FIRST PERSON"), "active chase and view comfort are readable with the legacy field-of-view phrase")
	_check(view.ui_scale == 1.35 and view.safe_area == safe_area, "caller UI scale and safe area survive unchanged")
	_check(view.controller_focus == &"camera_comfort_summary" and not bool(view.focus_requested), "presenter preserves controller focus without stealing it")
	_check(bool(view.color_independent) and not bool(view.get("camera_authority", true)) and not bool(view.get("input_authority", true)), "summary is colour-independent and has no camera or input authority")
	var stale := presenter.present(profile, {"settings_revision": 11, "reduced_motion": false})
	_check(not bool(stale.get("accepted", true)) and stale.reason == &"stale_settings_revision", "stale settings revisions are rejected")
	_check(presenter.get_snapshot().settings_revision == 12 and presenter.get_snapshot().reduced_motion, "stale state cannot overwrite the active confirmation")
	var malformed := profile.duplicate(true)
	malformed[&"camera_fov"] = 999.0
	var rejected := presenter.present(malformed, {"settings_revision": 99})
	_check(not bool(rejected.get("accepted", true)) and presenter.get_snapshot().settings_revision == 12 and presenter.get_snapshot().attached, "invalid future profile leaves the active presentation and revision unchanged")
	var corrected := presenter.present(profile, {"settings_revision": 13, "reduced_motion": false})
	_check(bool(corrected.get("accepted", false)) and corrected.settings_revision == 13, "valid correction after an invalid future profile is not fenced")
	for invalid_safe_area: Rect2 in [Rect2(NAN, 0.0, 0.0, 0.0), Rect2(0.0, 0.0, INF, 0.0)]:
		var invalid_layout := presenter.present(profile, {"settings_revision": 14, "safe_area": invalid_safe_area})
		_check(not bool(invalid_layout.get("accepted", true)) and invalid_layout.reason == &"invalid_safe_area", "nonfinite safe-area geometry is rejected")
	var detached := presenter.detach()
	_check(not bool(detached.get("attached", true)) and not detached.has("text") and not detached.has("safe_area"), "detach clears all player and layout presentation state")
	var reentered := presenter.present(profile, {"settings_revision": 1})
	_check(bool(reentered.get("accepted", false)) and reentered.get("mode") == &"standard" and reentered.settings_revision == 1, "reuse accepts a fresh revision domain without stale state")
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
