extends SceneTree

const PresenterType := preload("res://scripts/ui/final_approach_status_presenter.gd")
var _assertions := 0
var _failures: PackedStringArray = []

func _init() -> void:
	call_deferred(&"_run")

func _run() -> void:
	var presenter := PresenterType.new()
	var approaching := presenter.present({
		"generation": 4, "engagement_requested": true, "last_reason": &"final_approach_envelope_submitted",
		"controller": {"final_approach": {"state_id": &"final_approach"}},
		"last_result": {"accepted": true, "controller": {"distance_to_destination_meters": 42.5, "ship_speed_meters_per_second": 8.0, "alignment_dot": 0.98}},
	}, true)
	_check(bool(approaching.get("accepted", false)) and approaching.state == &"approaching", "approach receipt maps to approaching state")
	_check(str(approaching.text).contains("DISTANCE  42.5 m") and str(approaching.text).contains("SPEED  8.0 m/s") and str(approaching.text).contains("ALIGNMENT  0.98"), "distance speed alignment remain readable")
	_check(str(approaching.text).contains("TRANSITION  //  STATIC") and not bool(approaching.get("movement_authority", true)), "reduced-motion output is static and non-authoritative")
	var handoff := presenter.present({"generation": 5, "last_reason": &"final_approach_handoff_ready", "controller": {"final_approach": {"state_id": &"completed"}}, "last_result": {"accepted": true}})
	_check(handoff.state == &"handoff" and str(handoff.text).contains("HANDOFF"), "completion receipt maps to handoff")
	var rejected := presenter.present({"generation": 6, "last_result": {"accepted": false, "reason": &"final_approach_generation_mismatch"}})
	_check(rejected.state == &"rejected" and str(rejected.text).contains("REJECTED"), "rejected receipt is explicit")
	var stale := presenter.present({"generation": 5})
	_check(not bool(stale.get("accepted", true)) and stale.reason == &"stale_generation", "stale generation cannot overwrite presentation")
	var malformed := presenter.present({"generation": 7, "last_result": {"accepted": true, "controller": {"speed_mps": INF}}})
	_check(bool(malformed.get("accepted", false)) and not str(malformed.text).contains("inf"), "nonfinite measurements fail closed")
	presenter.detach()
	var reentered := presenter.present({"generation": 1, "controller": {"final_approach": {"state_id": &"armed"}}, "engagement_requested": true})
	_check(reentered.state == &"armed" and bool(reentered.get("attached", false)), "detach permits clean re-entry")
	if _failures.is_empty():
		print("FINAL_APPROACH_STATUS_PRESENTER_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)
