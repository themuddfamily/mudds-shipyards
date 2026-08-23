class_name EmberSurfaceLoopAudioProductionBinding
extends Node

## Presentation-only consumer for detached Ember surface-loop snapshots.
## Host, travel session, movement, landing, reward, and playback authority stay
## with the injected owner.

signal semantic_surface_cue_emitted(cue_id: StringName, intensity: float)

const PHASE_CUES := {
	&"descent": &"ember_surface_descent",
	&"landed": &"ember_surface_landed",
	&"on_foot": &"ember_surface_on_foot",
	&"reboarded": &"ember_surface_reboard",
	&"takeoff": &"ember_surface_takeoff",
	&"ascent": &"ember_surface_ascent",
	&"orbit_return": &"ember_surface_orbit_return",
	&"failed": &"ember_surface_abort",
}
const PRODUCTION_STATE_ALIASES := {
	&"start_pending": &"descent",
	&"running": &"descent",
	&"handoff_pending": &"orbit_return",
}
const PERSPECTIVES := [&"interior", &"exterior"]
const MAXIMUM_SIMULTANEOUS_VOICES := 2
const MAX_SAFE_GENERATION := 9_007_199_254_740_991
const EMBER_WORLD := preload("res://assets/world/planets/ember_moon_world.tres")
const ALTITUDE_LOOP_NAME: StringName = &"AirlessAltitudeHullResonance"
const ALTITUDE_TRANSITION_CEILING_M := 20_000.0
const ALTITUDE_FADE_SECONDS := 0.35
const ALTITUDE_LOOP_SAMPLE_RATE := 22_050
const ALTITUDE_LOOP_SECONDS := 1.0
const ALTITUDE_LOOP_GAIN_DB := -9.0
const MIN_AUDIBLE_INTENSITY := 0.0001

var _owner: Node
var _attached := false
var _generation := 0
var _last_owner_generation := -1
var _last_key := ""
var _perspective: StringName = &"exterior"
var _seen: Dictionary = {}
var _slots: Array[StringName] = []
var _emitted_count := 0
var _altitude_voice: AudioStreamPlayer
var _altitude_stream: AudioStreamWAV
var _altitude_m := ALTITUDE_TRANSITION_CEILING_M
var _altitude_proximity_unitless := 0.0
var _altitude_target_intensity_unitless := 0.0
var _altitude_intensity_unitless := 0.0
var _altitude_playback_requested := false
var _last_altitude_input: Dictionary = {}


func _ready() -> void:
	_ensure_altitude_voice()

func attach(owner: Node, perspective: StringName = &"exterior") -> Dictionary:
	if _attached:
		return _result(false, &"already_attached")
	if owner == null or not is_instance_valid(owner) or not owner.has_method(&"get_snapshot"):
		return _result(false, &"owner_contract_missing")
	if perspective not in PERSPECTIVES:
		return _result(false, &"invalid_perspective")
	_owner = owner
	_perspective = perspective
	_ensure_altitude_voice()
	if owner.has_signal(&"state_changed"):
		owner.connect(&"state_changed", _on_owner_snapshot)
	_attached = true
	_seen.clear()
	_slots.clear()
	_last_owner_generation = -1
	_last_key = ""
	present_snapshot(owner.get_snapshot())
	return _result(true, &"attached")

func set_perspective(perspective: StringName) -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	if perspective not in PERSPECTIVES:
		return _result(false, &"invalid_perspective")
	_perspective = perspective
	if not _last_altitude_input.is_empty():
		_apply_decoded_altitude_transition(_last_altitude_input, 0.0)
	return _result(true, &"perspective_updated")

func present_snapshot(snapshot: Dictionary) -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	var owner_generation: Variant = snapshot.get("generation", -1)
	if not owner_generation is int or int(owner_generation) < 0 \
			or int(owner_generation) > MAX_SAFE_GENERATION:
		return _result(false, &"invalid_generation")
	if int(owner_generation) < _last_owner_generation:
		return _result(false, &"stale_generation")
	_apply_altitude_transition(snapshot, _phase_delta(snapshot))
	var phase_id := StringName(snapshot.get("phase_id", snapshot.get("state_id", &"")))
	if _owner != null and _owner.has_method(&"get_host_phase"):
		var host_phase := int(_owner.get_host_phase())
		phase_id = _host_phase_id(host_phase) if host_phase >= 0 else phase_id
	phase_id = StringName(PRODUCTION_STATE_ALIASES.get(phase_id, phase_id))
	if phase_id.is_empty():
		return _result(false, &"invalid_phase")
	var terminal_reason := StringName(snapshot.get("terminal_reason", &""))
	if not terminal_reason.is_empty() and phase_id not in PHASE_CUES:
		phase_id = &"failed"
	var cue: StringName = PHASE_CUES.get(phase_id, &"")
	if cue.is_empty():
		_last_owner_generation = int(owner_generation)
		return _result(true, &"snapshot_accepted")
	var key := "%d:%s:%s" % [int(owner_generation), phase_id, _perspective]
	if _seen.has(key):
		return _result(true, &"duplicate_snapshot")
	_seen[key] = true
	_last_owner_generation = int(owner_generation)
	_last_key = key
	var perspective_cue := StringName("%s_%s" % [String(cue), String(_perspective)])
	_emit(perspective_cue)
	return _result(true, &"snapshot_presented")

func detach() -> Dictionary:
	if not _attached:
		return _result(true, &"already_detached")
	if is_instance_valid(_owner) and _owner.is_connected(&"state_changed", _on_owner_snapshot):
		_owner.disconnect(&"state_changed", _on_owner_snapshot)
	_owner = null
	_attached = false
	_generation += 1
	_last_owner_generation = -1
	_last_key = ""
	_seen.clear()
	_slots.clear()
	_last_altitude_input.clear()
	_reset_altitude_transition()
	return _result(true, &"detached")

func get_snapshot() -> Dictionary:
	return {"attached": _attached, "generation": _generation, "perspective": _perspective,
		"last_owner_generation": _last_owner_generation, "last_key": _last_key,
		"emitted_cue_count": _emitted_count, "active_cue_slots": _slots.duplicate(),
		"maximum_simultaneous_voices": MAXIMUM_SIMULTANEOUS_VOICES,
		"altitude_transition": {
			"world_id": EMBER_WORLD.world_id,
			"has_atmosphere": EMBER_WORLD.has_atmosphere,
			"altitude_m": _altitude_m,
			"transition_ceiling_m": ALTITUDE_TRANSITION_CEILING_M,
			"surface_proximity_unitless": _altitude_proximity_unitless,
			"target_intensity_unitless": _altitude_target_intensity_unitless,
			"intensity_unitless": _altitude_intensity_unitless,
			"playback_requested": _altitude_playback_requested,
			"voice_instance_id": _altitude_voice.get_instance_id() \
				if is_instance_valid(_altitude_voice) else 0,
			"stream_instance_id": _altitude_stream.get_instance_id() \
				if is_instance_valid(_altitude_stream) else 0,
			"fog_factor_unitless": 0.0,
			"cloud_factor_unitless": 0.0,
			"wind_gain_unitless": 0.0,
			"presentation_kind": &"airless_hull_resonance",
		}.duplicate(true),
		"authority": {"host": false, "travel": false, "movement": false, "landing": false, "audio_cues": true}}.duplicate(true)

func _on_owner_snapshot(snapshot: Dictionary) -> void:
	present_snapshot(snapshot)

func _host_phase_id(host_phase: int) -> StringName:
	match host_phase:
		2: return &"descent"
		5: return &"landed"
		8: return &"on_foot"
		10: return &"reboarded"
		11: return &"takeoff"
		12: return &"ascent"
		13: return &"orbit_return"
		15: return &"failed"
		_: return &""

func _emit(cue_id: StringName) -> void:
	if _slots.size() >= MAXIMUM_SIMULTANEOUS_VOICES:
		_slots.pop_front()
	_slots.append(cue_id)
	_emitted_count += 1
	semantic_surface_cue_emitted.emit(cue_id, 1.0)


## Consumes the production scheduler's already-adjusted actor sample. The
## streamed Ember root remains the body-centre datum; this presentation never
## samples or moves an actor and never fabricates atmospheric wind on an
## explicitly airless world. Only ship-borne descent/ascent vibration is mixed.
func _apply_altitude_transition(snapshot: Dictionary, caller_delta: float) -> void:
	var decoded := _decode_altitude_input(snapshot)
	if not bool(decoded.get("accepted", false)):
		# Actor/root evidence can disappear before the binding itself detaches.
		# Fail the continuous layer toward silence instead of retaining a ghost
		# hull loop from the last valid ship sample.
		_last_altitude_input.clear()
		_altitude_target_intensity_unitless = 0.0
		var silence_step := clampf(caller_delta / ALTITUDE_FADE_SECONDS, 0.0, 1.0)
		if caller_delta <= 0.0:
			silence_step = 1.0
		_altitude_intensity_unitless = move_toward(
			_altitude_intensity_unitless, 0.0, silence_step
		)
		_apply_altitude_voice()
		return
	_last_altitude_input = decoded.duplicate(true)
	_apply_decoded_altitude_transition(decoded, caller_delta)


func _apply_decoded_altitude_transition(
		decoded: Dictionary, caller_delta: float
	) -> void:
	_altitude_m = float(decoded.altitude_m)
	var coordinate := clampf(
		(ALTITUDE_TRANSITION_CEILING_M - _altitude_m)
			/ ALTITUDE_TRANSITION_CEILING_M,
		0.0,
		1.0,
	)
	_altitude_proximity_unitless = smoothstep(0.0, 1.0, coordinate)
	var phase_id := StringName(decoded.phase_id)
	var ship_borne := StringName(decoded.actor_kind) == &"ship" and phase_id in [
		&"orbit_approach", &"descent", &"surface_approach", &"landing_approach",
		&"takeoff", &"ascent", &"orbit_return",
	]
	var speed_weight := clampf(float(decoded.speed_mps) / 12.0, 0.0, 1.0)
	var perspective_weight := 1.0 if _perspective == &"interior" else 0.45
	_altitude_target_intensity_unitless = (
		_altitude_proximity_unitless
		* lerpf(0.2, 1.0, speed_weight)
		* perspective_weight
		if ship_borne else 0.0
	)
	var step := clampf(caller_delta / ALTITUDE_FADE_SECONDS, 0.0, 1.0)
	if caller_delta <= 0.0:
		step = 1.0
	_altitude_intensity_unitless = move_toward(
		_altitude_intensity_unitless,
		_altitude_target_intensity_unitless,
		step,
	)
	_apply_altitude_voice()


func _decode_altitude_input(snapshot: Dictionary) -> Dictionary:
	var evidence := snapshot.get("last_prepared_evidence", {}) as Dictionary
	var sample := evidence.get("actor_sample", {}) as Dictionary
	var position: Variant = sample.get("position", Vector3.INF)
	var actor_kind := StringName(sample.get("actor_kind", &""))
	var identities := snapshot.get("identities", {}) as Dictionary
	var loaded_root_id: Variant = identities.get("loaded_scene_instance_id", 0)
	if not position is Vector3 or not (position as Vector3).is_finite() \
			or actor_kind not in [&"ship", &"player"] \
			or not loaded_root_id is int or int(loaded_root_id) <= 0:
		return {"accepted": false, "reason": &"altitude_observation_unavailable"}
	var loaded_root := instance_from_id(int(loaded_root_id)) as Node3D
	if loaded_root == null or not is_instance_valid(loaded_root) \
			or not loaded_root.has_method(&"get_world_id") \
			or StringName(loaded_root.call(&"get_world_id")) != EMBER_WORLD.world_id:
		return {"accepted": false, "reason": &"ember_root_unavailable"}
	var kinematics := evidence.get("caller_kinematics", {}) as Dictionary
	var velocity: Variant = kinematics.get("velocity_mps", Vector3.ZERO)
	if not velocity is Vector3 or not (velocity as Vector3).is_finite():
		return {"accepted": false, "reason": &"altitude_velocity_invalid"}
	var phase_id := StringName(snapshot.get("phase_id", snapshot.get("state_id", &"")))
	if _owner != null and _owner.has_method(&"get_host_phase"):
		var host_phase := int(_owner.get_host_phase())
		phase_id = _host_altitude_phase_id(host_phase) if host_phase >= 0 else phase_id
	phase_id = StringName(PRODUCTION_STATE_ALIASES.get(phase_id, phase_id))
	var altitude: float = (position as Vector3).distance_to(loaded_root.global_position) \
		- float(EMBER_WORLD.get_body_radius_meters())
	if not is_finite(altitude):
		return {"accepted": false, "reason": &"altitude_nonfinite"}
	return {
		"accepted": true,
		"altitude_m": altitude,
		"actor_kind": actor_kind,
		"speed_mps": (velocity as Vector3).length(),
		"phase_id": phase_id,
	}.duplicate(true)


func _host_altitude_phase_id(host_phase: int) -> StringName:
	match host_phase:
		1: return &"orbit_approach"
		2: return &"descent"
		3: return &"surface_approach"
		4: return &"landing_approach"
		5: return &"landed"
		8: return &"on_foot"
		10: return &"reboarded"
		11: return &"takeoff"
		12: return &"ascent"
		13: return &"orbit_return"
		_: return &""


func _phase_delta(snapshot: Dictionary) -> float:
	var evidence := snapshot.get("last_prepared_evidence", {}) as Dictionary
	var value: Variant = evidence.get("delta", 0.0)
	return clampf(float(value), 0.0, 1.0) \
		if (value is float or value is int) and is_finite(float(value)) else 0.0


func _ensure_altitude_voice() -> void:
	if is_instance_valid(_altitude_voice):
		if _altitude_stream == null:
			_altitude_stream = _build_altitude_stream()
		if _altitude_voice.stream == null:
			_altitude_voice.stream = _altitude_stream
		return
	_altitude_stream = _build_altitude_stream()
	_altitude_voice = AudioStreamPlayer.new()
	_altitude_voice.name = ALTITUDE_LOOP_NAME
	_altitude_voice.bus = &"Ambience"
	_altitude_voice.volume_db = -80.0
	_altitude_voice.stream = _altitude_stream
	add_child(_altitude_voice)


func _build_altitude_stream() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = ALTITUDE_LOOP_SAMPLE_RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	var sample_count := int(ALTITUDE_LOOP_SAMPLE_RATE * ALTITUDE_LOOP_SECONDS)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for sample_index in sample_count:
		var time_seconds := float(sample_index) / float(ALTITUDE_LOOP_SAMPLE_RATE)
		var envelope := 0.72 + 0.28 * sin(TAU * 1.0 * time_seconds)
		var sample := (
			sin(TAU * 46.0 * time_seconds) * 0.52
			+ sin(TAU * 73.0 * time_seconds) * 0.23
			+ sin(TAU * 109.0 * time_seconds) * 0.08
		) * envelope
		data.encode_s16(sample_index * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
	stream.data = data
	stream.loop_begin = 0
	stream.loop_end = sample_count
	return stream


func _apply_altitude_voice() -> void:
	if not is_instance_valid(_altitude_voice):
		return
	_altitude_playback_requested = _attached \
		and _altitude_intensity_unitless > MIN_AUDIBLE_INTENSITY
	_altitude_voice.volume_db = (
		linear_to_db(maxf(_altitude_intensity_unitless, MIN_AUDIBLE_INTENSITY))
		+ ALTITUDE_LOOP_GAIN_DB
	)
	# Dummy has no output sink and may retain a synthetic WAV playback handle
	# through process shutdown. Keep the same requested mix evidence without
	# asking that backend to manufacture a voice it cannot render.
	if _altitude_playback_requested and AudioServer.get_driver_name() != "Dummy":
		if not _altitude_voice.playing:
			_altitude_voice.play()
	elif _altitude_voice.playing:
		_altitude_voice.stop()


func _reset_altitude_transition() -> void:
	_altitude_m = ALTITUDE_TRANSITION_CEILING_M
	_altitude_proximity_unitless = 0.0
	_altitude_target_intensity_unitless = 0.0
	_altitude_intensity_unitless = 0.0
	_altitude_playback_requested = false
	if is_instance_valid(_altitude_voice):
		_altitude_voice.stop()
		_altitude_voice.volume_db = -80.0
		_altitude_voice.stream = null
	_altitude_stream = null

func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {"accepted": accepted, "reason": reason, "generation": _generation}.duplicate(true)

func _exit_tree() -> void:
	detach()
