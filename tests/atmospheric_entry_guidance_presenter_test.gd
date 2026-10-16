extends SceneTree

const Presenter := preload("res://scripts/ui/atmospheric_entry_guidance_presenter.gd")
var _failures: PackedStringArray = []
var _assertions := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var presenter := Presenter.new()
	var critical := presenter.present_snapshot({
		"altitude_m": 412.0,
		"entry_intensity": 0.93,
		"landing_supported": false,
		"recovery_receipt": {"receipt_id": &"support-17"},
	})
	_check(critical.state == &"critical_entry" and critical.intensity_marker == &"!! ENTRY LOAD CRITICAL !!", "critical entry uses text-safe severity guidance")
	_check(critical.actions.size() == 2 and critical.actions[0].focusable and critical.actions[1].focusable, "critical entry exposes controller-focusable support and abort actions")
	_check(presenter.request_support().accepted and presenter.abort_landing().accepted, "landing actions return external intents")
	var nested := presenter.present_snapshot({
		"branch_id": &"atmospheric",
		"entry_intensity": 0.0,
		"entry": {"heat_intensity_unitless": 0.93},
		"envelope": {"weights": {"atmosphere_unitless": 0.5}},
		"landing_supported": true,
		"vertical_speed_mps": -60.0,
		"altitude_m": 900.0,
		"reduced_flash": true,
		"reduced_motion": true,
	})
	_check(nested.state == &"entry_watch" and is_equal_approx(nested.entry_intensity, 0.465)
		and nested.raw_entry_intensity == 0.93 and nested.atmosphere_weight == 0.5,
		"nested transition heat is weighted by the atmosphere envelope")
	_check(nested.intensity_marker == &"[ STEADY ENTRY LOAD RISING ]"
		and nested.descent_advisory_id == &"high_sink_rate"
		and str(nested.guidance).contains("HIGH SINK RATE")
		and nested.transition_policy == &"static",
		"nested input preserves descent and accessibility guidance")
	var ember := presenter.present_snapshot({
		"world_id": &"ember_moon", "branch_id": &"airless",
		"entry": {"heat_intensity_unitless": 1.0},
		"envelope": {"weights": {"atmosphere_unitless": 1.0}},
		"landing_supported": true,
	})
	_check(ember.state == &"airless_descent" and ember.title == "Ember Airless Descent"
		and ember.entry_intensity == 0.0 and ember.atmosphere_weight == 0.0
		and ember.intensity_marker == &"[ AIRLESS // ENTRY HEAT ZERO ]"
		and str(ember.guidance).contains("powered-descent")
		and ember.actions.size() == 1 and not presenter.request_support().accepted
		and ember.attention_cue_policy == &"steady_text_no_flash",
		"airless entry suppresses stale heat and offers powered descent guidance")
	_check(not ember.physics_authority and not ember.movement_authority
		and not ember.damage_authority and not ember.landing_authority,
		"airless guidance retains all external authority boundaries")
	var airless_fallback := presenter.present_snapshot({
		"branch_id": &"unknown", "has_atmosphere": false, "entry_intensity": 1.0,
	})
	_check(airless_fallback.state == &"airless_descent"
		and airless_fallback.title == "Airless Descent"
		and airless_fallback.actions.size() == 2,
		"atmosphere metadata identifies unsupported generic airless approaches")
	var explicit := presenter.present_snapshot({
		"branch_id": &"atmospheric", "has_atmosphere": false,
		"entry_intensity": 1.0,
	})
	_check(explicit.state == &"critical_entry", "explicit valid branch overrides fallback metadata")
	var malformed := presenter.present_snapshot({
		"branch_id": 7, "entry": null, "envelope": {"weights": null},
		"entry_intensity": 0.5,
	})
	_check(malformed.state == &"entry_watch" and malformed.atmosphere_weight == 1.0,
		"unavailable nested dictionaries retain legacy flat atmospheric input")
	var ready := presenter.present_snapshot({"altitude_m": 18.0, "entry_intensity": 0.1, "landing_supported": true})
	_check(ready.state == &"landing_supported" and ready.actions.size() == 1 and not presenter.request_support().accepted, "supported nominal landing only exposes abort")
	var detached := presenter.get_snapshot()
	detached["guidance"] = "forged"
	_check(presenter.get_snapshot().guidance != "forged", "guidance snapshot is detached")
	if _failures.is_empty():
		print("ATMOSPHERIC_ENTRY_GUIDANCE_PRESENTER_TEST_OK: %d assertions" % _assertions)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)
	quit(0)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
