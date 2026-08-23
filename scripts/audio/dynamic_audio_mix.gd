class_name DynamicAudioMix
extends RefCounted

## Detached mix-plan contract for authored station, planetary, and combat audio.
##
## This object only computes values for a presentation backend.  It never
## creates/starts players, touches AudioServer, advances gameplay, or owns
## an encounter/landing/state transition.  A caller supplies the current
## presentation context and applies the returned plan if appropriate.

const SCHEMA_VERSION := 1
const COMPONENT_ID: StringName = &"dynamic-audio-mix"
const LAYERS: Array[StringName] = [&"station", &"planetary", &"combat"]
const LAYER_BUSES := {
	&"station": &"Ambience",
	&"planetary": &"Ambience",
	&"combat": &"Weapons",
}
const BUSES: Array[StringName] = [&"Master", &"Ambience", &"Engines", &"Weapons", &"UI", &"Music"]
const DEFAULT_BUS_CEILINGS_DB := {
	&"Master": 0.0, &"Ambience": 0.0, &"Engines": 0.0,
	&"Weapons": 0.0, &"UI": 0.0, &"Music": 0.0,
}
const MAX_VOICES := {&"station": 8, &"planetary": 8, &"combat": 10}
const REDUCED_RANGE_ATTENUATION_DB := {
	&"station": -6.0, &"planetary": -6.0, &"combat": -12.0,
}

var _gains := {&"station": 1.0, &"planetary": 0.0, &"combat": 0.0}
var _ducking := {&"station": 0.0, &"planetary": 0.0, &"combat": 0.0}
var _ceilings_db: Dictionary = DEFAULT_BUS_CEILINGS_DB.duplicate()
var _muted := false
var _reduced_dynamic_range := false
var _generation := 0


func configure_layers(gains: Dictionary) -> Dictionary:
	var next := _gains.duplicate()
	for key in gains.keys():
		var layer := StringName(key)
		if not LAYERS.has(layer):
			return _reject(&"unknown_layer", layer)
		var value: Variant = gains[key]
		if not (value is float or value is int) or not is_finite(float(value)) or float(value) < 0.0 or float(value) > 1.0:
			return _reject(&"invalid_layer_gain", layer)
		next[layer] = float(value)
	_gains = next
	_generation += 1
	return _accepted()


## `attenuation` is 0 for no ducking and 1 for fully ducked.  It is a
## presentation-only envelope; callers decide which gameplay event warrants it.
func set_ducking(layer: StringName, attenuation: float) -> Dictionary:
	if not LAYERS.has(layer):
		return _reject(&"unknown_layer", layer)
	if not is_finite(attenuation) or attenuation < 0.0 or attenuation > 1.0:
		return _reject(&"invalid_ducking", layer)
	_ducking[layer] = attenuation
	_generation += 1
	return _accepted()


func configure_bus_ceilings(ceilings_db: Dictionary) -> Dictionary:
	var next := _ceilings_db.duplicate()
	for key in ceilings_db.keys():
		var bus := StringName(key)
		if not BUSES.has(bus):
			return _reject(&"unknown_bus", bus)
		var value: Variant = ceilings_db[key]
		if not (value is float or value is int) or not is_finite(float(value)) or float(value) < -80.0 or float(value) > 0.0:
			return _reject(&"invalid_bus_ceiling", bus)
		next[bus] = float(value)
	_ceilings_db = next
	_generation += 1
	return _accepted()


func set_accessibility_muted(muted: bool) -> Dictionary:
	_muted = muted
	_generation += 1
	return _accepted()


## Caller-driven accessibility mix mode. It changes only authored layer gains;
## bus ownership, voice ceilings, and gameplay authority remain untouched.
func set_reduced_dynamic_range(enabled: bool) -> Dictionary:
	_reduced_dynamic_range = enabled
	_generation += 1
	return _accepted()


func get_mix_plan() -> Dictionary:
	var layers: Dictionary = {}
	var total_voices := 0
	for layer in LAYERS:
		var bus: StringName = LAYER_BUSES[layer]
		var range_linear := db_to_linear(
			float(REDUCED_RANGE_ATTENUATION_DB[layer])
		) if _reduced_dynamic_range else 1.0
		var raw := float(_gains[layer]) * (1.0 - float(_ducking[layer])) * range_linear
		var ceiling_linear := db_to_linear(float(_ceilings_db[bus]))
		var effective := 0.0 if _muted else minf(raw, ceiling_linear)
		layers[layer] = {
			"bus": bus,
			"gain": effective,
			"gain_db": -80.0 if effective <= 0.0001 else linear_to_db(effective),
			"ducking": float(_ducking[layer]),
			"voice_ceiling": int(MAX_VOICES[layer]),
		}
		total_voices += int(MAX_VOICES[layer]) if effective > 0.0 else 0
	return {
		"layers": layers,
		"bus_ceilings_db": _ceilings_db.duplicate(),
		"total_voice_ceiling": total_voices,
		"accessibility_muted": _muted,
		"reduced_dynamic_range": _reduced_dynamic_range,
		"generation": _generation,
		"presentation_only": true,
		"playback_authority": false,
	}


func get_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"gains": _gains.duplicate(),
		"ducking": _ducking.duplicate(),
		"ceilings_db": _ceilings_db.duplicate(),
		"accessibility_muted": _muted,
		"reduced_dynamic_range": _reduced_dynamic_range,
		"generation": _generation,
	}


func restore(snapshot: Dictionary) -> bool:
	if not snapshot.has("gains") or not snapshot.has("ducking") or not snapshot.has("ceilings_db"):
		return false
	var old_gains := _gains
	var old_ducking := _ducking
	var old_ceilings := _ceilings_db
	var result := configure_layers(snapshot["gains"] as Dictionary)
	if not bool(result["accepted"]):
		_gains = old_gains
		_ducking = old_ducking
		_ceilings_db = old_ceilings
		return false
	for layer in LAYERS:
		var value := float((snapshot["ducking"] as Dictionary).get(layer, 0.0))
		if not is_finite(value) or value < 0.0 or value > 1.0:
			_gains = old_gains; _ducking = old_ducking; _ceilings_db = old_ceilings
			return false
		_ducking[layer] = value
	if not bool(configure_bus_ceilings(snapshot["ceilings_db"] as Dictionary)["accepted"]):
		_gains = old_gains; _ducking = old_ducking; _ceilings_db = old_ceilings
		return false
	_muted = bool(snapshot.get("accessibility_muted", false))
	_reduced_dynamic_range = bool(snapshot.get("reduced_dynamic_range", false))
	_generation = maxi(_generation, int(snapshot.get("generation", _generation)))
	return true


func audit() -> Dictionary:
	return {
		"valid": LAYERS.size() == 3 and BUSES.size() == 6 and MAX_VOICES.size() == 3,
		"layers": LAYERS.duplicate(),
		"buses": BUSES.duplicate(),
		"presentation_only": true,
		"playback_authority": false,
		"gameplay_authority": false,
	}


func _accepted() -> Dictionary:
	return {"accepted": true, "generation": _generation}


func _reject(reason: StringName, subject: StringName) -> Dictionary:
	return {"accepted": false, "reason": reason, "subject": subject, "generation": _generation}
