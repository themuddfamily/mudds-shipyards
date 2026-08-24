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
	var route_guidance := _route_guidance(
		host, binding, mapped.get("state", &"rejected") as StringName
	)
	var lines := PackedStringArray(["EMBER RETURN  //  %s" % str(mapped.get("label", "UNAVAILABLE"))])
	var distance := _finite(host, &"distance_meters")
	var speed := _finite(host, &"speed_meters_per_second")
	if bool(route_guidance.get("available", false)):
		distance = float(route_guidance.get("distance_m", distance))
		lines.append(
			"NEXT  %s  //  %.1f m" % [
				route_guidance.get("target_label", "ROUTE"), distance,
			]
		)
	if distance >= 0.0:
		lines.append("DISTANCE  %.1f m" % distance)
	if speed >= 0.0:
		lines.append("SPEED  %.1f m/s" % speed)
	if not receipt.is_empty() and receipt.has("reason"):
		lines.append("REASON  " + str(receipt.get("reason", &"")).replace("_", " ").to_upper())
	if not manifest.is_empty() and StringName(manifest.get("destination_id", &"")) != &"":
		lines.append("DESTINATION  " + str(manifest.get("destination_id")))
	var next_action := _next_action_cue(mapped.get("state", &"rejected") as StringName)
	if not next_action.is_empty():
		lines.append("NEXT ACTION  //  " + str(next_action.get("label", "")))
	lines.append("TRANSITION  //  STATIC" if reduced_motion else "TRANSITION  //  STANDARD")
	_attached = true
	_view = {
		"accepted": true, "attached": true, "state": mapped.get("state"),
		"text": "\n".join(lines), "generation": generation,
		"distance_m": distance, "speed_mps": speed,
		"reduced_motion": reduced_motion, "focusable": true,
		"color_independent": true, "reduced_flash_safe": true,
		"flash_requested": false, "route_guidance": route_guidance,
		"next_action": next_action,
		"presentation_only": true,
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


## Reboarding leaves the craft landed and waiting for the already-authenticated
## take-off transition. This is a readable state cue only: it neither exposes
## an input binding nor requests travel from the host.
func _next_action_cue(state: StringName) -> Dictionary:
	if state == &"reboarded":
		return {
			"id": &"takeoff",
			"label": "TAKE OFF",
			"focusable": true,
			"input_authority": false,
			"travel_authority": false,
		}.duplicate(true)
	return {}


## Derives one display-only route vector from the Host's detached actor/route
## observations and the retained planetary presentation's authored landmarks.
## It never samples a node, chooses a path, or mutates either source.
func _route_guidance(
		host: Dictionary, binding: Dictionary, state: StringName
	) -> Dictionary:
	var actor_state := host.get("actor_state", {}) as Dictionary
	var surface_route := host.get("surface_route", {}) as Dictionary
	var planetary := binding.get("planetary_surface", {}) as Dictionary
	var relay_presentation := planetary.get(
		"relay_survey_presentation", {}
	) as Dictionary
	var actor_key := &"player_position" if state in [
		&"on_foot", &"reboard",
	] else &"ship_position"
	var actor: Variant = actor_state.get(actor_key)
	if actor is not Vector3 or not (actor as Vector3).is_finite():
		return _unavailable_route_guidance()
	var target: Variant
	var target_id: StringName
	var target_label: String
	var route_kind: StringName
	if state in [&"descent", &"landed"]:
		target = surface_route.get("egress_anchor")
		target_id = &"ember_landing_pad"
		target_label = "LANDING PAD"
		route_kind = &"landing"
	elif state == &"on_foot":
		var cue_mode := StringName(relay_presentation.get("cue_mode", &""))
		if cue_mode in [&"approach_relay", &"active_relay"]:
			target = relay_presentation.get("relay_anchor")
			target_id = &"ember_relay_tower"
			target_label = "RELAY"
		else:
			target = relay_presentation.get(
				"return_anchor", surface_route.get("staging_anchor")
			)
			target_id = &"ember_return_route"
			target_label = "RETURN ROUTE"
		route_kind = &"surface_route"
	elif state == &"reboard":
		target = surface_route.get("egress_anchor")
		target_id = &"ember_landing_pad"
		target_label = "LANDING PAD"
		route_kind = &"surface_route"
	else:
		return _unavailable_route_guidance()
	if target is not Vector3 or not (target as Vector3).is_finite():
		return _unavailable_route_guidance()
	var actor_position := actor as Vector3
	var target_position := target as Vector3
	var displacement := target_position - actor_position
	var map_direction := Vector2(displacement.x, displacement.z)
	return {
		"available": true,
		"target_id": target_id,
		"target_label": target_label,
		"actor_position": actor_position,
		"target_position": target_position,
		"distance_m": displacement.length(),
		"offscreen_direction": map_direction.normalized() \
			if not map_direction.is_zero_approx() else Vector2.ZERO,
		"route_kind": route_kind,
		"coordinate_source": &"authoritative_detached_actor_and_landmark_snapshots",
		"reduced_flash_safe": true,
		"navigation_authority": false,
	}.duplicate(true)


func _unavailable_route_guidance() -> Dictionary:
	return {
		"available": false,
		"reduced_flash_safe": true,
		"navigation_authority": false,
	}.duplicate(true)


func _reject(reason: StringName) -> Dictionary:
	return {"accepted": false, "reason": reason, "presentation_only": true, "movement_authority": false, "landing_authority": false}
