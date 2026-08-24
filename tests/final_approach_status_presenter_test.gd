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
		"controller": {"final_approach": {"state_id": &"final_approach", "target": {"entry_position_half_extents_m": Vector3(20.0, 12.0, 60.0), "maximum_attitude_degrees": 12.0}}},
		"last_result": {"accepted": true, "controller": {
			"observation": {"distance_to_destination_meters": 42.5, "ship_speed_meters_per_second": 8.0},
			"final_approach_aligned": true,
			"final_approach_measurement": {"position_offset_entry_local_m": Vector3(-3.0, 2.0, 18.0), "speed_mps": 7.5, "attitude_degrees": 4.0},
		}},
	}, true)
	_check(bool(approaching.get("accepted", false)) and approaching.state == &"approaching", "approach receipt maps to approaching state")
	_check(str(approaching.text).contains("DISTANCE  42.5 m") and str(approaching.text).contains("SPEED  7.5 m/s") and str(approaching.text).contains("ATTITUDE  4.0 deg"), "production observation and measured speed and attitude remain readable")
	_check(bool(approaching.approach_measurement_valid) and (approaching.position_offset_entry_local_m as Vector3).is_equal_approx(Vector3(-3.0, 2.0, 18.0)) and (approaching.entry_position_half_extents_m as Vector3).is_equal_approx(Vector3(20.0, 12.0, 60.0)) and float(approaching.maximum_attitude_degrees) == 12.0, "validated authoritative measurement and envelope fields are forwarded exactly")
	_check(approaching.state != &"aligned", "presenter never fabricates alignment from a boolean hint")
	_check(str(approaching.text).contains("TRANSITION  //  STATIC") and not bool(approaching.get("movement_authority", true)), "reduced-motion output is static and non-authoritative")
	var handoff := presenter.present({"generation": 5, "last_reason": &"final_approach_handoff_ready", "controller": {"final_approach": {"state_id": &"completed"}}, "last_result": {"accepted": true}})
	_check(handoff.state == &"handoff" and str(handoff.text).contains("HANDOFF"), "completion receipt maps to handoff")
	var rejected := presenter.present({"generation": 6, "last_result": {"accepted": false, "reason": &"final_approach_generation_mismatch"}})
	_check(rejected.state == &"rejected" and str(rejected.text).contains("REJECTED"), "rejected receipt is explicit")
	var stale := presenter.present({"generation": 5})
	_check(not bool(stale.get("accepted", true)) and stale.reason == &"stale_generation", "stale generation cannot overwrite presentation")
	var malformed := presenter.present({"generation": 7, "controller": {"final_approach": {"state_id": &"final_approach", "target": {"entry_position_half_extents_m": Vector3.ONE, "maximum_attitude_degrees": 12.0}}}, "last_result": {"accepted": true, "controller": {"final_approach_measurement": {"position_offset_entry_local_m": Vector3.INF, "speed_mps": INF, "attitude_degrees": INF}}}})
	_check(bool(malformed.get("accepted", false)) and not bool(malformed.approach_measurement_valid) and not str(malformed.text).contains("inf"), "nonfinite production measurements fail closed")
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
