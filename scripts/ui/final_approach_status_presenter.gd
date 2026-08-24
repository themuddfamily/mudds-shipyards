class_name FinalApproachStatusPresenter
extends RefCounted

## Presentation-only view of PlanetaryCruiseProductionBinding receipts.
## It never evaluates cruise policy, moves a craft, or owns landing/handoff.

var _source_generation := -1
var _attached := false
var _view: Dictionary = {}


func present(snapshot: Dictionary, reduced_motion: bool = false) -> Dictionary:
	var generation_variant: Variant = snapshot.get("generation", null)
	if not generation_variant is int or int(generation_variant) < 0:
		return _reject(&"invalid_generation")
	var generation := int(generation_variant)
	if _source_generation >= 0 and generation < _source_generation:
		return _reject(&"stale_generation")
	_source_generation = generation
	var controller := snapshot.get("controller", {}) as Dictionary
	var final := controller.get("final_approach", {}) as Dictionary
	var last_result := snapshot.get("last_result", {}) as Dictionary
	var evaluation := last_result.get("controller", {}) as Dictionary
	var observation := evaluation.get("observation", {}) as Dictionary
	var approach_data := _validated_approach_data(evaluation, final)
	var state_id := StringName(final.get("state_id", &"none"))
	var reason := StringName(snapshot.get("last_reason", last_result.get("reason", &"")))
	if last_result.has("accepted") and not bool(last_result.get("accepted", false)):
		state_id = &"rejected"
	elif state_id == &"completed" or reason in [&"final_approach_handoff_ready", &"final_approach_completed"]:
		state_id = &"handoff"
	elif state_id == &"final_approach":
		state_id = &"approaching"
	elif state_id == &"none" and not bool(snapshot.get("engagement_requested", false)):
		state_id = &"unavailable"
	elif state_id == &"none":
		state_id = &"unavailable"
	var distance := _finite_number(observation, "distance_to_destination_meters", -1.0)
	var speed := _finite_number(observation, "ship_speed_meters_per_second", -1.0)
	if bool(approach_data.get("valid", false)):
		speed = float(approach_data.get("speed_mps", speed))
	var attitude := float(approach_data.get("attitude_degrees", -1.0))
	var state_text := str(state_id).replace("_", " ").to_upper()
	var lines := PackedStringArray(["FINAL APPROACH  //  %s" % state_text])
	if distance >= 0.0:
		lines.append("DISTANCE  %.1f m" % distance)
	if speed >= 0.0:
		lines.append("SPEED  %.1f m/s" % speed)
	if attitude >= 0.0:
		lines.append("ATTITUDE  %.1f deg" % attitude)
	if not reason.is_empty():
		lines.append("REASON  " + str(reason).replace("_", " ").to_upper())
	lines.append("TRANSITION  //  STATIC" if reduced_motion else "TRANSITION  //  STANDARD")
	_attached = true
	_view = {
		"accepted": true,
		"attached": true,
		"state": state_id,
		"text": "\n".join(lines),
		"generation": generation,
		"distance_m": distance,
		"speed_mps": speed,
		"approach_measurement_valid": bool(approach_data.get("valid", false)),
		"position_offset_entry_local_m": approach_data.get(
			"position_offset_entry_local_m", Vector3.INF
		),
		"attitude_degrees": attitude,
		"entry_position_half_extents_m": approach_data.get(
			"entry_position_half_extents_m", Vector3.ZERO
		),
		"maximum_attitude_degrees": float(approach_data.get(
			"maximum_attitude_degrees", -1.0
		)),
		"reduced_motion": reduced_motion,
		"focusable": true,
		"color_independent": true,
		"presentation_only": true,
		"movement_authority": false,
		"landing_authority": false,
		"handoff_authority": false,
	}.duplicate(true)
	return _view.duplicate(true)


func detach() -> Dictionary:
	_attached = false
	_source_generation = -1
	_view = {"accepted": true, "attached": false, "state": &"unavailable", "presentation_only": true}
	return _view.duplicate(true)


func get_snapshot() -> Dictionary:
	var result := _view.duplicate(true)
	result["attached"] = _attached
	return result


func _finite_number(source: Dictionary, key: StringName, fallback: float) -> float:
	var value: Variant = source.get(key, fallback)
	if not (value is int or value is float) or not is_finite(float(value)):
		return fallback
	return float(value)


func _validated_approach_data(evaluation: Dictionary, final: Dictionary) -> Dictionary:
	var measurement := evaluation.get("final_approach_measurement", {}) as Dictionary
	var target := final.get("target", {}) as Dictionary
	var offset_variant: Variant = measurement.get(
		"position_offset_entry_local_m", null
	)
	var extents_variant: Variant = target.get("entry_position_half_extents_m", null)
	var attitude_variant: Variant = measurement.get("attitude_degrees", null)
	var speed_variant: Variant = measurement.get("speed_mps", null)
	var maximum_attitude_variant: Variant = target.get(
		"maximum_attitude_degrees", null
	)
	if not offset_variant is Vector3 or not extents_variant is Vector3:
		return {}
	if not (attitude_variant is int or attitude_variant is float) \
			or not (speed_variant is int or speed_variant is float) \
			or not (maximum_attitude_variant is int or maximum_attitude_variant is float):
		return {}
	var offset := offset_variant as Vector3
	var extents := extents_variant as Vector3
	var attitude := float(attitude_variant)
	var speed := float(speed_variant)
	var maximum_attitude := float(maximum_attitude_variant)
	if not offset.is_finite() or not extents.is_finite() \
			or extents.x <= 0.0 or extents.y <= 0.0 or extents.z <= 0.0 \
			or not is_finite(attitude) or attitude < 0.0 \
			or not is_finite(speed) or speed < 0.0 \
			or not is_finite(maximum_attitude) or maximum_attitude <= 0.0:
		return {}
	return {
		"valid": true,
		"position_offset_entry_local_m": offset,
		"attitude_degrees": attitude,
		"speed_mps": speed,
		"entry_position_half_extents_m": extents,
		"maximum_attitude_degrees": maximum_attitude,
	}.duplicate(true)


func _reject(reason: StringName) -> Dictionary:
	return {"accepted": false, "reason": reason, "presentation_only": true, "movement_authority": false, "landing_authority": false}
