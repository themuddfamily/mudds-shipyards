class_name MusicStateTransition
extends RefCounted

## Pure state machine for authored music presentation.
##
## This component does not create players, load assets, call AudioServer, or
## decide gameplay state. A caller supplies the already-decided context and
## consumes the detached mix plan. The loop clock is retained across state
## changes and whole-scene detach/re-entry when the caller restores the
## snapshot.

const SCHEMA_VERSION := 1
const COMPONENT_ID: StringName = &"music-state-transition"
const AUDIO_BUS: StringName = &"Music"
const VOICE_CEILING := 3

const STATE_STATION: StringName = &"station"
const STATE_COMBAT: StringName = &"combat"
const STATE_LANDING: StringName = &"landing"
const STATE_PLANETARY: StringName = &"planetary"
const STATE_ORBIT: StringName = &"orbit"
const STATE_SURFACE: StringName = &"surface"
const STATE_ACTIVITY_ACTIVE: StringName = &"activity_active"
const STATE_ACTIVITY_COMPLETE: StringName = &"activity_complete"
const STATES: Array[StringName] = [
	STATE_STATION, STATE_COMBAT, STATE_LANDING, STATE_PLANETARY, STATE_ORBIT, STATE_SURFACE,
	STATE_ACTIVITY_ACTIVE, STATE_ACTIVITY_COMPLETE,
]

## The names are authored mix layers, not player nodes. A runtime backend may
## map them to the existing StationMusicBed or a future music bank.
const STATE_LAYER_GAINS := {
	STATE_STATION: {&"bed": 1.0, &"motif": 1.0, &"stinger": 0.0},
	STATE_COMBAT: {&"bed": 0.0, &"motif": 0.0, &"stinger": 1.0},
	STATE_LANDING: {&"bed": 0.45, &"motif": 0.0, &"stinger": 0.8},
	STATE_PLANETARY: {&"bed": 0.75, &"motif": 0.35, &"stinger": 0.0},
	STATE_ORBIT: {&"bed": 0.9, &"motif": 0.2, &"stinger": 0.0},
	STATE_SURFACE: {&"bed": 0.6, &"motif": 0.55, &"stinger": 0.0},
	STATE_ACTIVITY_ACTIVE: {&"bed": 0.5, &"motif": 0.35, &"stinger": 0.15},
	STATE_ACTIVITY_COMPLETE: {&"bed": 0.7, &"motif": 0.35, &"stinger": 0.8},
}

var _state: StringName = STATE_STATION
var _loop_position_seconds := 0.0
var _muted := false
var _generation := 0


func transition(next_state: StringName, retained_position_seconds: float = -1.0) -> Dictionary:
	if not STATES.has(next_state):
		return {"accepted": false, "reason": &"unknown_state", "generation": _generation}
	if retained_position_seconds >= 0.0:
		if not is_finite(retained_position_seconds):
			return {"accepted": false, "reason": &"invalid_position", "generation": _generation}
		_loop_position_seconds = fmod(retained_position_seconds, 240.0)
		if _loop_position_seconds < 0.0:
			_loop_position_seconds += 240.0
	var previous := _state
	_state = next_state
	_generation += 1
	return {
		"accepted": true,
		"previous_state": previous,
		"state": _state,
		"retained_position_seconds": _loop_position_seconds,
		"mix_plan": get_mix_plan(),
		"generation": _generation,
	}


func advance(delta_seconds: float) -> bool:
	if not is_finite(delta_seconds) or delta_seconds < 0.0:
		return false
	_loop_position_seconds = fmod(_loop_position_seconds + delta_seconds, 240.0)
	return true


func set_accessibility_muted(muted: bool) -> Dictionary:
	_muted = muted
	return get_mix_plan()


func restore(snapshot: Dictionary) -> bool:
	if not snapshot.has("state") or not STATES.has(StringName(snapshot["state"])):
		return false
	var position := float(snapshot.get("loop_position_seconds", -1.0))
	if not is_finite(position) or position < 0.0:
		return false
	_state = StringName(snapshot["state"])
	_loop_position_seconds = fmod(position, 240.0)
	if _loop_position_seconds < 0.0:
		_loop_position_seconds += 240.0
	_muted = bool(snapshot.get("accessibility_muted", false))
	_generation = maxi(0, int(snapshot.get("generation", _generation)))
	return true


func get_mix_plan() -> Dictionary:
	var gains: Dictionary = (STATE_LAYER_GAINS[_state] as Dictionary).duplicate()
	if _muted:
		for layer in gains.keys():
			gains[layer] = 0.0
	return {
		"state": _state,
		"bus": AUDIO_BUS,
		"layer_gains": gains,
		"voice_count": VOICE_CEILING,
		"accessibility_muted": _muted,
		"presentation_only": true,
	}


func get_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"state": _state,
		"loop_position_seconds": _loop_position_seconds,
		"accessibility_muted": _muted,
		"generation": _generation,
	}


func audit() -> Dictionary:
	return {
		"valid": STATES.size() == 8 and VOICE_CEILING == 3 and AUDIO_BUS == &"Music",
		"states": STATES.duplicate(),
		"voice_ceiling": VOICE_CEILING,
		"presentation_only": true,
		"gameplay_authority": false,
	}
