class_name EmberSurfaceReturnStatusPresenter
extends RefCounted

## Presentation-only view of detached Ember surface/return evidence.
## It never moves actors, admits landing/reboard, selects berths, or grants rewards.

const STATES := [
	&"descent", &"landed", &"on_foot", &"reboard", &"reboarded",
	&"takeoff", &"ascent", &"orbit_return", &"return_manifest", &"rejected",
]

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
	var host := snapshot.get("host", {}) as Dictionary
	var binding := snapshot.get("binding", {}) as Dictionary
	var receipt := snapshot.get("last_result", {}) as Dictionary
	var manifest := snapshot.get("return_manifest", {}) as Dictionary
	var state := StringName(host.get("phase_id", &""))
	if not bool(host.get("attached", binding.get("attached", false))):
		state = &"rejected"
	if receipt.has("accepted") and not bool(receipt.get("accepted", false)):
		state = &"rejected"
	elif bool(receipt.get("accepted", false)) and StringName(receipt.get("reason", &"")) == &"return_manifest_ready":
		state = &"return_manifest"
	var mapped := _map_state(state)
	if mapped.is_empty():
		return _reject(&"unsupported_phase")
	var lines := PackedStringArray(["EMBER RETURN  //  %s" % str(mapped.get("label", "UNAVAILABLE"))])
	var distance := _finite(host, &"distance_meters")
	var speed := _finite(host, &"speed_meters_per_second")
	if distance >= 0.0:
		lines.append("DISTANCE  %.1f m" % distance)
	if speed >= 0.0:
		lines.append("SPEED  %.1f m/s" % speed)
	if not receipt.is_empty() and receipt.has("reason"):
		lines.append("REASON  " + str(receipt.get("reason", &"")).replace("_", " ").to_upper())
	if not manifest.is_empty() and StringName(manifest.get("destination_id", &"")) != &"":
		lines.append("DESTINATION  " + str(manifest.get("destination_id")))
	lines.append("TRANSITION  //  STATIC" if reduced_motion else "TRANSITION  //  STANDARD")
	_attached = true
	_view = {
		"accepted": true, "attached": true, "state": mapped.get("state"),
		"text": "\n".join(lines), "generation": generation,
		"distance_m": distance, "speed_mps": speed,
		"reduced_motion": reduced_motion, "focusable": true,
		"color_independent": true, "presentation_only": true,
		"movement_authority": false, "landing_authority": false,
		"session_authority": false, "reward_authority": false,
	}.duplicate(true)
	return _view.duplicate(true)


func detach() -> Dictionary:
	_attached = false
	_source_generation = -1
	_view = {"accepted": true, "attached": false, "state": &"rejected", "presentation_only": true}
	return _view.duplicate(true)


func get_snapshot() -> Dictionary:
	var result := _view.duplicate(true)
	result["attached"] = _attached
	return result


func _map_state(state: StringName) -> Dictionary:
	if state == &"surface_approach" or state == &"surface_flight" or state == &"landing_approach":
		state = &"descent"
	if state == &"disembarking" or state == &"surface_outbound" or state == &"boarding":
		state = &"on_foot" if state != &"boarding" else &"reboard"
	if state == &"completed":
		state = &"orbit_return"
	if state not in STATES:
		return {}
	return {"state": state, "label": str(state).replace("_", " ").to_upper()}


func _finite(source: Dictionary, key: StringName) -> float:
	var value: Variant = source.get(key, -1.0)
	if not (value is int or value is float) or not is_finite(float(value)) or float(value) < 0.0:
		return -1.0
	return float(value)


func _reject(reason: StringName) -> Dictionary:
	return {"accepted": false, "reason": reason, "presentation_only": true, "movement_authority": false, "landing_authority": false}
