class_name PlanetarySurfaceAudioRouting
extends RefCounted

## Pure routing contract for the first authored planetary surface audio slice.
##
## This component does not load or play samples, own an AudioBus, sample a
## listener, or advance a landing cue clock. It converts one complete caller
## observation into bounded layer and bus hints. Playback remains the
## responsibility of the production audio binding.

const SCHEMA_VERSION := 1
const ROUTING_VERSION: StringName = &"planetary_surface_audio_routing_v1"
const BUS_AMBIENCE: StringName = &"Ambience"
const BUS_WIND: StringName = &"Wind"
const BUS_SURFACE_SFX: StringName = &"SurfaceSFX"
const BUS_IDS: Array[StringName] = [BUS_AMBIENCE, BUS_WIND, BUS_SURFACE_SFX]

const LAYER_EXTERIOR: StringName = &"exterior"
const LAYER_INTERIOR: StringName = &"interior"
const LAYER_WIND: StringName = &"wind"
const LAYER_LANDING: StringName = &"landing"
const LAYER_IDS: Array[StringName] = [
	LAYER_EXTERIOR, LAYER_INTERIOR, LAYER_WIND, LAYER_LANDING,
]
const LISTENER_CONTEXTS: Array[StringName] = [&"exterior", &"interior", &"cabin"]
const LANDING_STATES: Array[StringName] = [&"none", &"approach", &"touchdown"]
const OBSERVATION_KEYS: Array[StringName] = [
	&"listener_context", &"wind_intensity_unitless", &"landing_state",
	&"grounded",
]

## Ceiling is the maximum absolute layer level on each bus. A value below the
## ceiling is intentionally conservative: a caller may still duck it further.
const BUS_CEILINGS_DB := {
	BUS_AMBIENCE: -6.0,
	BUS_WIND: -9.0,
	BUS_SURFACE_SFX: -3.0,
}
const LAYER_BUS := {
	LAYER_EXTERIOR: BUS_AMBIENCE,
	LAYER_INTERIOR: BUS_AMBIENCE,
	LAYER_WIND: BUS_WIND,
	LAYER_LANDING: BUS_SURFACE_SFX,
}
const LAYER_MAXIMUM_VOICES := {
	LAYER_EXTERIOR: 1,
	LAYER_INTERIOR: 1,
	LAYER_WIND: 1,
	LAYER_LANDING: 1,
}
const LAYER_BASE_GAIN_DB := {
	LAYER_EXTERIOR: -6.0,
	LAYER_INTERIOR: -24.0,
	LAYER_WIND: -9.0,
	LAYER_LANDING: -3.0,
}

const AUTHORITY := {
	"renderer": false, "gameplay": false, "streaming": false,
	"save": false, "network": false, "physics": false,
	"weather_simulation": false, "terrain": false, "audio_playback": false,
}
const EVIDENCE := {
	"content_class": &"NEW",
	"status": &"modern_interpretation",
	"source_bounded": false,
	"confidence": &"none",
}


func evaluate(observation: Variant) -> Dictionary:
	var decoded := _decode(observation)
	if not bool(decoded.accepted):
		return _result(false, decoded.reason)
	var input := decoded.input as Dictionary
	var context := input.listener_context as StringName
	var wind := float(input.wind_intensity_unitless)
	var landing := input.landing_state as StringName
	var grounded := bool(input.grounded)
	var interior := context != &"exterior"
	var exterior_gain := float(LAYER_BASE_GAIN_DB[LAYER_EXTERIOR]) if not interior else -INF
	var interior_gain := float(LAYER_BASE_GAIN_DB[LAYER_INTERIOR]) if interior else -INF
	var wind_gain := -INF
	if not interior and wind > 0.0:
		wind_gain = _clamp_db(
			float(LAYER_BASE_GAIN_DB[LAYER_WIND]) + linear_to_db(wind),
			float(BUS_CEILINGS_DB[BUS_WIND])
		)
	var landing_active := landing != &"none"
	var landing_gain := float(LAYER_BASE_GAIN_DB[LAYER_LANDING]) if landing_active else -INF
	# Touchdown is a one-shot hint; this contract does not schedule or replay it.
	var layers := {
		LAYER_EXTERIOR: _layer(LAYER_EXTERIOR, exterior_gain, exterior_gain > -INF),
		LAYER_INTERIOR: _layer(LAYER_INTERIOR, interior_gain, interior_gain > -INF),
		LAYER_WIND: _layer(LAYER_WIND, wind_gain, wind_gain > -INF),
		LAYER_LANDING: _layer(LAYER_LANDING, landing_gain, landing_active),
	}
	return _result(true, &"evaluated", {
		"routing_version": ROUTING_VERSION,
		"listener_context": context,
		"grounded": grounded,
		"landing_state": landing,
		"layers": layers,
		"active_layer_count": _active_count(layers),
		"maximum_simultaneous_voices": 4,
	})


func get_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"routing_version": ROUTING_VERSION,
		"layer_ids": LAYER_IDS.duplicate(),
		"bus_ids": BUS_IDS.duplicate(),
		"bus_ceilings_db": BUS_CEILINGS_DB.duplicate(),
		"layer_bus": LAYER_BUS.duplicate(),
		"layer_maximum_voices": LAYER_MAXIMUM_VOICES.duplicate(),
		"observation_keys": OBSERVATION_KEYS.duplicate(),
		"authority": AUTHORITY.duplicate(),
		"evidence": EVIDENCE.duplicate(),
	}.duplicate(true)


func audit() -> Dictionary:
	var errors := PackedStringArray()
	if BUS_CEILINGS_DB.size() != BUS_IDS.size():
		errors.append("bus ceiling roster drifted")
	for layer_id in LAYER_IDS:
		if not LAYER_BUS.has(layer_id) or not LAYER_MAXIMUM_VOICES.has(layer_id):
			errors.append("layer roster drifted: %s" % layer_id)
	if not _zero_authority(AUTHORITY):
		errors.append("authority roster drifted")
	errors.sort()
	return {"valid": errors.is_empty(), "errors": errors, "snapshot": get_snapshot()}


func _decode(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {"accepted": false, "reason": &"invalid_observation"}
	var input := value as Dictionary
	if input.size() != OBSERVATION_KEYS.size():
		return {"accepted": false, "reason": &"invalid_observation_schema"}
	for key in OBSERVATION_KEYS:
		if not input.has(key):
			return {"accepted": false, "reason": &"invalid_observation_schema"}
	if not input.listener_context is StringName or not LISTENER_CONTEXTS.has(input.listener_context):
		return {"accepted": false, "reason": &"invalid_listener_context"}
	if not input.landing_state is StringName or not LANDING_STATES.has(input.landing_state):
		return {"accepted": false, "reason": &"invalid_landing_state"}
	if not input.grounded is bool:
		return {"accepted": false, "reason": &"invalid_grounded_state"}
	if not input.wind_intensity_unitless is float and not input.wind_intensity_unitless is int:
		return {"accepted": false, "reason": &"invalid_wind_intensity"}
	var wind := float(input.wind_intensity_unitless)
	if not is_finite(wind) or wind < 0.0 or wind > 1.0:
		return {"accepted": false, "reason": &"invalid_wind_intensity"}
	return {"accepted": true, "input": input}


func _layer(layer_id: StringName, gain_db: float, active: bool) -> Dictionary:
	return {
		"layer_id": layer_id, "bus": LAYER_BUS[layer_id], "active": active,
		"gain_db": gain_db if active else -INF,
		"maximum_voices": LAYER_MAXIMUM_VOICES[layer_id],
		"ceiling_db": BUS_CEILINGS_DB[LAYER_BUS[layer_id]],
	}


func _clamp_db(value: float, ceiling: float) -> float:
	return min(value, ceiling)


func _active_count(layers: Dictionary) -> int:
	var count := 0
	for layer_id in LAYER_IDS:
		if bool((layers[layer_id] as Dictionary).active):
			count += 1
	return count


func _result(accepted: bool, reason: StringName, payload: Dictionary = {}) -> Dictionary:
	var result := {"accepted": accepted, "reason": reason}
	result.merge(payload, true)
	return result


static func _zero_authority(value: Dictionary) -> bool:
	if value.size() != AUTHORITY.size():
		return false
	for key in AUTHORITY:
		if not value.has(key) or value[key] is not bool or bool(value[key]):
			return false
	return true


static func linear_to_db(value: float) -> float:
	return -80.0 if value <= 0.00001 else 20.0 * log(value) / log(10.0)
