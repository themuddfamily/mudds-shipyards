class_name MusicDirector
extends Node

signal semantic_music_cue_emitted(cue_id: StringName, intensity: float)

## Presentation-only bridge for already-decided session and phase signals.
##
## MusicDirector never reads gameplay state, emits gameplay commands, or owns
## audio players. It records the observed context in MusicStateTransition and
## returns a detached mix plan for the StationMusicBed (or another future
## backend) to apply.

const Transition := preload("res://scripts/audio/music_state_transition.gd")

const SCHEMA_VERSION := 1
const COMPONENT_ID: StringName = &"music-director"
const PRESENTATION_STATES: Array[StringName] = [
	Transition.STATE_STATION,
	Transition.STATE_COMBAT,
	Transition.STATE_LANDING,
	Transition.STATE_PLANETARY,
	Transition.STATE_ORBIT,
	Transition.STATE_SURFACE,
]
const OBSERVED_PHASES: Array[StringName] = [
	&"station",
	&"flight",
	&"orbit",
	&"surface",
	&"combat",
	&"landing",
	&"planetary",
]
const OBSERVED_SESSION_STATES: Array[StringName] = [&"rest", &"flight", &"combat"]
const MAX_COMBAT_INTENSITY := 1.0
const SEMANTIC_THRESHOLD := 0.25

var _transition := Transition.new()
var _last_observation: StringName = &"station"
var _observation_count := 0
var _combat_intensity := 0.0


## Records the already-decided station-bed session vocabulary.
func observe_session_state(session_state: StringName) -> Dictionary:
	var mapped_state := _map_session_state(session_state)
	if mapped_state.is_empty():
		return _rejected(&"unknown_session_state")
	return _accept_observation(mapped_state, session_state)


## Records a broader phase vocabulary without deciding whether that phase is
## valid gameplay. The caller supplies the phase after its own authority check.
func observe_phase(phase: StringName) -> Dictionary:
	if not OBSERVED_PHASES.has(phase):
		return _rejected(&"unknown_phase")
	var mapped_state := Transition.STATE_STATION
	match phase:
		&"combat":
			mapped_state = Transition.STATE_COMBAT
		&"landing":
			mapped_state = Transition.STATE_LANDING
		&"planetary", &"flight":
			mapped_state = Transition.STATE_PLANETARY
		&"orbit":
			mapped_state = Transition.STATE_ORBIT
		&"surface":
			mapped_state = Transition.STATE_SURFACE
	return _accept_observation(mapped_state, phase)


func advance(delta_seconds: float) -> bool:
	return _transition.advance(delta_seconds)


## Records a caller-owned presentation intensity; this never selects combat or
## changes gameplay state. StationMusicBed may consume the detached value.
func set_combat_intensity(intensity: float) -> Dictionary:
	if not is_finite(intensity) or intensity < 0.0 or intensity > MAX_COMBAT_INTENSITY:
		return _rejected(&"invalid_combat_intensity")
	var previous_intensity := _combat_intensity
	_combat_intensity = intensity
	if intensity >= SEMANTIC_THRESHOLD and previous_intensity < SEMANTIC_THRESHOLD:
		semantic_music_cue_emitted.emit(&"music_combat_tension", intensity)
	elif intensity < SEMANTIC_THRESHOLD and previous_intensity >= SEMANTIC_THRESHOLD:
		semantic_music_cue_emitted.emit(&"music_combat_tension_end", intensity)
	return {
		"accepted": true,
		"reason": &"combat_intensity_recorded",
		"combat_intensity": _combat_intensity,
		"presentation_only": true,
	}.duplicate(true)


func get_combat_intensity() -> float:
	return _combat_intensity


func set_accessibility_muted(muted: bool) -> Dictionary:
	return _transition.set_accessibility_muted(muted)


func get_mix_plan() -> Dictionary:
	return _transition.get_mix_plan().duplicate(true)


func get_snapshot() -> Dictionary:
	var snapshot := _transition.get_snapshot()
	snapshot["schema_version"] = SCHEMA_VERSION
	snapshot["component_id"] = COMPONENT_ID
	snapshot["last_observation"] = _last_observation
	snapshot["observation_count"] = _observation_count
	snapshot["combat_intensity"] = _combat_intensity
	return snapshot.duplicate(true)


func get_audit_report() -> Dictionary:
	var errors := PackedStringArray()
	var transition_audit := _transition.audit()
	if not bool(transition_audit.get("valid", false)):
		errors.append("music state transition contract is invalid")
	if not PRESENTATION_STATES.has(StringName(_transition.get_snapshot().get("state", &""))):
		errors.append("director holds an unknown presentation state")
	if not OBSERVED_PHASES.has(_last_observation) and not OBSERVED_SESSION_STATES.has(_last_observation):
		errors.append("director observation vocabulary drifted")
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"valid": errors.is_empty(),
		"errors": errors,
		"presentation_only": true,
		"gameplay_authority": false,
		"audio_playback_authority": false,
		"observed_phase_count": OBSERVED_PHASES.size(),
		"observation_count": _observation_count,
	}.duplicate(true)


func _accept_observation(state: StringName, observation: StringName) -> Dictionary:
	var transition := _transition.transition(state)
	if not bool(transition.get("accepted", false)):
		return transition.duplicate(true)
	_last_observation = observation
	_observation_count += 1
	var result := transition.duplicate(true)
	result["observation"] = observation
	result["session_state"] = _session_state_for(state)
	result["presentation_only"] = true
	var previous_state := StringName(transition.get("previous_state", &""))
	if state == Transition.STATE_LANDING and previous_state != state:
		semantic_music_cue_emitted.emit(&"music_landing", 1.0)
	elif state == Transition.STATE_ORBIT and previous_state != state:
		semantic_music_cue_emitted.emit(&"music_orbit", 1.0)
	elif state == Transition.STATE_SURFACE and previous_state != state:
		semantic_music_cue_emitted.emit(&"music_surface", 1.0)
	elif state == Transition.STATE_COMBAT and previous_state != state:
		semantic_music_cue_emitted.emit(&"music_combat", 1.0)
	elif state == Transition.STATE_STATION and previous_state != state:
		semantic_music_cue_emitted.emit(&"music_return_station", 1.0)
	return result


func _rejected(reason: StringName) -> Dictionary:
	return {
		"accepted": false,
		"reason": reason,
		"generation": int(_transition.get_snapshot().get("generation", 0)),
		"presentation_only": true,
	}.duplicate(true)


func _map_session_state(session_state: StringName) -> StringName:
	match session_state:
		&"rest":
			return Transition.STATE_STATION
		&"flight":
			return Transition.STATE_PLANETARY
		&"combat":
			return Transition.STATE_COMBAT
	return &""


func _session_state_for(state: StringName) -> StringName:
	match state:
		Transition.STATE_COMBAT:
			return &"combat"
		Transition.STATE_PLANETARY, Transition.STATE_LANDING, Transition.STATE_ORBIT, Transition.STATE_SURFACE:
			return &"flight"
	return &"rest"
