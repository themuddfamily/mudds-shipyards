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
const EntryGuidancePresenterScript := preload(
	"res://scripts/ui/atmospheric_entry_guidance_presenter.gd"
)
const ALTITUDE_LOOP_NAME: StringName = &"AirlessAltitudeHullResonance"
const ALTITUDE_TRANSITION_CEILING_M := 20_000.0
const ALTITUDE_FADE_SECONDS := 0.35
const ALTITUDE_LOOP_SAMPLE_RATE := 22_050
const ALTITUDE_LOOP_SECONDS := 1.0
const ALTITUDE_LOOP_GAIN_DB := -9.0
const MIN_AUDIBLE_INTENSITY := 0.0001
const ENTRY_BED_FADE_SECONDS := 0.35
const ENTRY_BED_EXTERIOR_GAIN := 0.82
const ENTRY_BED_INTERIOR_GAIN := 0.42
const ENTRY_BED_REDUCED_RANGE_GAIN := 0.58
const ENTRY_BED_MIN_PITCH := 1.08
const ENTRY_BED_MAX_PITCH := 1.34
const ENTRY_ALERT_STATES := [
	&"atmospheric_rising", &"atmospheric_critical", &"airless_high_sink",
]
const ENTRY_CUE_BY_STATE := {
	&"atmospheric_rising": &"planetary_atmospheric_entry",
	&"atmospheric_critical": &"surface_entry_severe",
	&"airless_high_sink": &"surface_entry_severe",
	&"clear": &"surface_entry_clear",
}
const ENTRY_CUE_INTENSITY := {
	&"atmospheric_rising": 0.65,
	&"atmospheric_critical": 1.0,
	&"airless_high_sink": 0.9,
	&"clear": 0.25,
}

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
var _continuous_playback_requested := false
var _last_altitude_input: Dictionary = {}
var _reduced_dynamic_range := false
var _last_entry_owner_generation := -1
var _last_entry_binding_generation := -1
var _last_entry_observation_count := -1
var _last_entry_state: StringName = &""
var _last_entry_cue: StringName = &""
var _entry_cue_count := 0
var _last_entry_result: Dictionary = {}
var _last_entry_observation: Dictionary = {}
var _entry_bed_branch: StringName = &"unavailable"
var _entry_bed_craft_id: StringName = &""
var _entry_bed_accepted_intensity_unitless := 0.0
var _entry_bed_target_intensity_unitless := 0.0
var _entry_bed_intensity_unitless := 0.0
var _entry_bed_phase_is_active := false
var _entry_guidance_presenter := EntryGuidancePresenterScript.new() as RefCounted


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
	_reset_entry_transition()
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
	if _entry_bed_phase_is_active and not _last_entry_observation.is_empty():
		_configure_entry_bed_target(_last_entry_observation)
		_entry_bed_intensity_unitless = _entry_bed_target_intensity_unitless
	_apply_altitude_voice()
	return _result(true, &"perspective_updated")


func set_reduced_dynamic_range(enabled: bool) -> Dictionary:
	_reduced_dynamic_range = enabled
	if _entry_bed_phase_is_active and not _last_entry_observation.is_empty():
		_configure_entry_bed_target(_last_entry_observation)
		_entry_bed_intensity_unitless = minf(
			_entry_bed_intensity_unitless,
			_entry_bed_target_intensity_unitless,
		)
	_apply_altitude_voice()
	return _result(true, &"dynamic_range_updated")

func present_snapshot(snapshot: Dictionary) -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	var owner_generation: Variant = snapshot.get("generation", -1)
	if not owner_generation is int or int(owner_generation) < 0 \
			or int(owner_generation) > MAX_SAFE_GENERATION:
		return _result(false, &"invalid_generation")
	if int(owner_generation) < _last_owner_generation:
		return _result(false, &"stale_generation")
	_last_entry_result = _present_entry_transition(snapshot, int(owner_generation))
	_apply_altitude_transition(snapshot, _phase_delta(snapshot))
	_apply_entry_bed(snapshot, _phase_delta(snapshot))
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
	_reset_entry_transition()
	_reset_altitude_transition()
	return _result(true, &"detached")

func get_snapshot() -> Dictionary:
	return {"attached": _attached, "generation": _generation, "perspective": _perspective,
		"last_owner_generation": _last_owner_generation, "last_key": _last_key,
		"emitted_cue_count": _emitted_count, "active_cue_slots": _slots.duplicate(),
		"maximum_simultaneous_voices": MAXIMUM_SIMULTANEOUS_VOICES,
		"reduced_dynamic_range": _reduced_dynamic_range,
		"entry_transition": {
			"last_owner_generation": _last_entry_owner_generation,
			"last_binding_generation": _last_entry_binding_generation,
			"last_observation_count": _last_entry_observation_count,
			"last_state": _last_entry_state,
			"last_cue": _last_entry_cue,
			"emitted_cue_count": _entry_cue_count,
			"last_result": _last_entry_result.duplicate(true),
		}.duplicate(true),
		"entry_bed": {
			"branch_id": _entry_bed_branch,
			"craft_id": _entry_bed_craft_id,
			"accepted_entry_intensity_unitless": (
				_entry_bed_accepted_intensity_unitless
			),
			"target_intensity_unitless": _entry_bed_target_intensity_unitless,
			"intensity_unitless": _entry_bed_intensity_unitless,
			"playback_requested": _attached \
				and _entry_bed_intensity_unitless > MIN_AUDIBLE_INTENSITY,
			"perspective_gain": ENTRY_BED_INTERIOR_GAIN \
				if _perspective == &"interior" else ENTRY_BED_EXTERIOR_GAIN,
			"reduced_dynamic_range": _reduced_dynamic_range,
			"reduced_range_gain_cap": ENTRY_BED_REDUCED_RANGE_GAIN,
			"airless_exact_silence": _entry_bed_branch == &"airless" \
				and is_zero_approx(_entry_bed_target_intensity_unitless) \
				and is_zero_approx(_entry_bed_intensity_unitless),
			"voice_instance_id": _altitude_voice.get_instance_id() \
				if is_instance_valid(_altitude_voice) else 0,
			"stream_instance_id": _altitude_stream.get_instance_id() \
				if is_instance_valid(_altitude_stream) else 0,
			"reuses_surface_transition_voice": true,
			"continuous_intensity_response": true,
			"entry_phase_active": _entry_bed_phase_is_active,
			"presentation_only": true,
		}.duplicate(true),
		"continuous_voice": {
			"voice_ceiling": 1,
			"active_mode": _continuous_voice_mode(),
			"combined_intensity_unitless": maxf(
				_altitude_intensity_unitless, _entry_bed_intensity_unitless
			),
			"playback_requested": _continuous_playback_requested,
			"volume_db": _altitude_voice.volume_db \
				if is_instance_valid(_altitude_voice) else -80.0,
			"pitch_scale": _altitude_voice.pitch_scale \
				if is_instance_valid(_altitude_voice) else 1.0,
			"minimum_entry_pitch": ENTRY_BED_MIN_PITCH,
			"maximum_entry_pitch": ENTRY_BED_MAX_PITCH,
			"node_count": 1,
			"stream_count": 1 if _altitude_stream != null else 0,
		}.duplicate(true),
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
		"authority": {"host": false, "travel": false, "movement": false,
			"landing": false, "flight": false, "atmosphere": false,
			"heat": false, "audio_cues": true}}.duplicate(true)

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

func _emit(cue_id: StringName, intensity: float = 1.0) -> void:
	if _slots.size() >= MAXIMUM_SIMULTANEOUS_VOICES:
		_slots.pop_front()
	_slots.append(cue_id)
	_emitted_count += 1
	semantic_surface_cue_emitted.emit(cue_id, clampf(intensity, 0.0, 1.0))


## Consumes only the retained entry presentation result already accepted by the
## production owner. It never samples a ship or changes entry/landing state.
func _present_entry_transition(
		snapshot: Dictionary, owner_generation: int
	) -> Dictionary:
	var decoded := _decode_accepted_entry_observation(snapshot)
	if not bool(decoded.get("available", false)):
		_last_entry_observation.clear()
		return _entry_result(true, &"entry_observation_unavailable")
	if not bool(decoded.get("accepted", false)):
		return _entry_result(
			false, StringName(decoded.get("reason", &"invalid_entry_observation"))
		)
	var source := decoded.get("source", {}) as Dictionary
	var binding_generation: Variant = decoded.get("binding_generation", -1)
	var observation_count: Variant = decoded.get("observation_count", -1)
	if not binding_generation is int or int(binding_generation) < 0 \
			or int(binding_generation) > MAX_SAFE_GENERATION \
			or not observation_count is int or int(observation_count) < 1 \
			or int(observation_count) > MAX_SAFE_GENERATION:
		return _entry_result(false, &"invalid_entry_generation")
	if owner_generation < _last_entry_owner_generation:
		return _entry_result(false, &"stale_entry_owner_generation")
	var lifecycle_changed := owner_generation > _last_entry_owner_generation
	if not lifecycle_changed:
		if int(binding_generation) < _last_entry_binding_generation:
			return _entry_result(false, &"stale_entry_binding_generation")
		lifecycle_changed = int(binding_generation) > _last_entry_binding_generation
	if not lifecycle_changed and int(observation_count) <= _last_entry_observation_count:
		return _entry_result(
			false, &"duplicate_entry_observation" \
				if int(observation_count) == _last_entry_observation_count \
				else &"stale_entry_observation"
		)
	if lifecycle_changed:
		_last_entry_state = &""
		_last_entry_observation_count = -1
	_last_entry_owner_generation = owner_generation
	_last_entry_binding_generation = int(binding_generation)
	_last_entry_observation_count = int(observation_count)
	_last_entry_observation = source.duplicate(true)
	var state := _entry_semantic_state(source)
	if state == _last_entry_state:
		return _entry_result(true, &"entry_state_unchanged")
	var previous := _last_entry_state
	_last_entry_state = state
	var cue_state := state
	if state == &"clear" and previous not in ENTRY_ALERT_STATES:
		return _entry_result(true, &"entry_clear_without_alert")
	var cue_id: StringName = ENTRY_CUE_BY_STATE.get(cue_state, &"")
	if cue_id.is_empty():
		return _entry_result(true, &"entry_state_presented")
	var intensity := float(ENTRY_CUE_INTENSITY.get(cue_state, 1.0))
	if _reduced_dynamic_range:
		intensity *= 0.75
	_emit(cue_id, intensity)
	_entry_cue_count += 1
	_last_entry_cue = cue_id
	return _entry_result(true, &"entry_transition_cue_emitted", {
		"cue_id": cue_id, "intensity": intensity,
	})


## Normalizes Arrow's cockpit-owned result and the shared non-Arrow envelope
## result into one accepted audio observation. Both originate in the production
## entry presenter; no atmosphere or kinematics are sampled again here.
func _decode_accepted_entry_observation(snapshot: Dictionary) -> Dictionary:
	var arrow_bridge := snapshot.get("entry_presentation", {}) as Dictionary
	var arrow_retained := snapshot.get(
		"last_entry_presentation_result", {}
	) as Dictionary
	if arrow_retained.is_empty():
		arrow_retained = arrow_bridge.get("last_result", {}) as Dictionary
	var arrow_source := arrow_retained.get("source", {}) as Dictionary
	if not arrow_bridge.is_empty() and not arrow_source.is_empty():
		if not bool(arrow_retained.get("accepted", false)):
			return {
				"available": true,
				"accepted": false,
				"reason": &"entry_presentation_not_accepted",
			}
		return {
			"available": true,
			"accepted": true,
			"binding_generation": arrow_bridge.get("generation", -1),
			"observation_count": arrow_bridge.get("observation_count", -1),
			"source": arrow_source.duplicate(true),
		}.duplicate(true)

	var fleet_bridge := snapshot.get(
		"fleet_entry_envelope_presentation", {}
	) as Dictionary
	if fleet_bridge.is_empty() or not bool(fleet_bridge.get("attached", false)):
		return {"available": false, "accepted": true}
	var envelope := fleet_bridge.get("envelope", {}) as Dictionary
	var sample := fleet_bridge.get(
		"accepted_atmosphere_sample", {}
	) as Dictionary
	var branch_id := StringName(envelope.get("branch_id", &""))
	var sample_intensity: Variant = sample.get("entry_effect_intensity", 0.0)
	var sample_inputs := sample.get("inputs", {}) as Dictionary
	if not bool(sample.get("accepted", false)) \
			or branch_id not in [&"atmospheric", &"airless"] \
			or not (sample_intensity is float or sample_intensity is int) \
			or not is_finite(float(sample_intensity)) \
			or float(sample_intensity) < 0.0 or float(sample_intensity) > 1.0:
		return {
			"available": true,
			"accepted": false,
			"reason": &"invalid_fleet_entry_observation",
		}
	var source := {
		"branch_id": branch_id,
		"altitude_m": float(sample_inputs.get("altitude_m", 0.0)),
		"vertical_speed_mps": 0.0,
		"entry_intensity": float(sample_intensity),
		"landing_supported": false,
		"craft_id": StringName(fleet_bridge.get("craft_id", &"")),
	}.duplicate(true)
	return {
		"available": true,
		"accepted": true,
		"binding_generation": fleet_bridge.get("generation", -1),
		"observation_count": fleet_bridge.get("observation_serial", -1),
		"source": source,
	}.duplicate(true)


func _entry_semantic_state(source: Dictionary) -> StringName:
	var guidance := _entry_guidance_presenter.call(
		&"present_snapshot", source
	) as Dictionary
	var state := StringName(guidance.get("state", &""))
	if state == &"critical_entry":
		return &"atmospheric_critical"
	if state == &"entry_watch":
		return &"atmospheric_rising"
	if state == &"airless_descent" and StringName(guidance.get(
		"descent_advisory_id", &""
	)) == &"high_sink_rate":
		return &"airless_high_sink"
	return &"clear"


func _reset_entry_transition() -> void:
	_last_entry_owner_generation = -1
	_last_entry_binding_generation = -1
	_last_entry_observation_count = -1
	_last_entry_state = &""
	_last_entry_cue = &""
	_last_entry_result = {}
	_last_entry_observation = {}
	_entry_bed_branch = &"unavailable"
	_entry_bed_craft_id = &""
	_entry_bed_accepted_intensity_unitless = 0.0
	_entry_bed_target_intensity_unitless = 0.0
	_entry_bed_intensity_unitless = 0.0
	_entry_bed_phase_is_active = false


func _entry_result(
		accepted: bool, reason: StringName, extra: Dictionary = {}
	) -> Dictionary:
	var result := {"accepted": accepted, "reason": reason}
	for key: Variant in extra:
		result[key] = extra[key]
	return result.duplicate(true)


func _apply_entry_bed(snapshot: Dictionary, caller_delta: float) -> void:
	_entry_bed_phase_is_active = _entry_bed_phase_active(snapshot)
	if _last_entry_observation.is_empty() or not _entry_bed_phase_is_active:
		_entry_bed_branch = &"unavailable"
		_entry_bed_craft_id = &""
		_entry_bed_accepted_intensity_unitless = 0.0
		_entry_bed_target_intensity_unitless = 0.0
		var unavailable_step := clampf(
			caller_delta / ENTRY_BED_FADE_SECONDS, 0.0, 1.0
		)
		if caller_delta <= 0.0:
			unavailable_step = 1.0
		_entry_bed_intensity_unitless = move_toward(
			_entry_bed_intensity_unitless, 0.0, unavailable_step
		)
		_apply_altitude_voice()
		return
	_configure_entry_bed_target(_last_entry_observation)
	# Entering an explicitly airless world is a semantic boundary, not an audio
	# crossfade: atmospheric wind/heat must be absent from the first Ember sample.
	if _entry_bed_branch == &"airless":
		_entry_bed_intensity_unitless = 0.0
		_apply_altitude_voice()
		return
	var step := clampf(caller_delta / ENTRY_BED_FADE_SECONDS, 0.0, 1.0)
	if caller_delta <= 0.0:
		step = 1.0
	_entry_bed_intensity_unitless = move_toward(
		_entry_bed_intensity_unitless,
		_entry_bed_target_intensity_unitless,
		step,
	)
	_apply_altitude_voice()


func _entry_bed_phase_active(snapshot: Dictionary) -> bool:
	var phase_id := StringName(snapshot.get(
		"phase_id", snapshot.get("state_id", &"")
	))
	if _owner != null and _owner.has_method(&"get_host_phase"):
		var host_phase := int(_owner.get_host_phase())
		phase_id = _host_altitude_phase_id(host_phase) \
			if host_phase >= 0 else phase_id
	phase_id = StringName(PRODUCTION_STATE_ALIASES.get(phase_id, phase_id))
	return phase_id in [
		&"orbit_approach", &"descent", &"surface_approach", &"landing_approach",
	]


func _configure_entry_bed_target(source: Dictionary) -> void:
	_entry_bed_branch = StringName(source.get("branch_id", &"unavailable"))
	_entry_bed_craft_id = StringName(source.get("craft_id", &"arrow"))
	_entry_bed_accepted_intensity_unitless = clampf(
		float(source.get("entry_intensity", 0.0)), 0.0, 1.0
	)
	if _entry_bed_branch != &"atmospheric":
		_entry_bed_target_intensity_unitless = 0.0
		return
	var perspective_gain := ENTRY_BED_INTERIOR_GAIN \
		if _perspective == &"interior" else ENTRY_BED_EXTERIOR_GAIN
	var range_gain := minf(
		perspective_gain, ENTRY_BED_REDUCED_RANGE_GAIN
	) if _reduced_dynamic_range else perspective_gain
	_entry_bed_target_intensity_unitless = clampf(
		_entry_bed_accepted_intensity_unitless * range_gain, 0.0, 1.0
	)


func _continuous_voice_mode() -> StringName:
	if _entry_bed_intensity_unitless > MIN_AUDIBLE_INTENSITY:
		return &"atmospheric_entry_wind_heat"
	if _altitude_intensity_unitless > MIN_AUDIBLE_INTENSITY:
		return &"airless_hull_resonance"
	return &"silence"


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
	var combined_intensity := maxf(
		_altitude_intensity_unitless, _entry_bed_intensity_unitless
	)
	_altitude_playback_requested = _attached \
		and _altitude_intensity_unitless > MIN_AUDIBLE_INTENSITY
	_continuous_playback_requested = _attached \
		and combined_intensity > MIN_AUDIBLE_INTENSITY
	_altitude_voice.volume_db = (
		linear_to_db(maxf(combined_intensity, MIN_AUDIBLE_INTENSITY))
		+ ALTITUDE_LOOP_GAIN_DB
	)
	_altitude_voice.pitch_scale = lerpf(
		ENTRY_BED_MIN_PITCH,
		ENTRY_BED_MAX_PITCH,
		_entry_bed_accepted_intensity_unitless,
	) if _continuous_voice_mode() == &"atmospheric_entry_wind_heat" else 1.0
	# Dummy has no output sink and may retain a synthetic WAV playback handle
	# through process shutdown. Keep the same requested mix evidence without
	# asking that backend to manufacture a voice it cannot render.
	if _continuous_playback_requested and AudioServer.get_driver_name() != "Dummy":
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
	_continuous_playback_requested = false
	if is_instance_valid(_altitude_voice):
		_altitude_voice.stop()
		_altitude_voice.volume_db = -80.0
		_altitude_voice.pitch_scale = 1.0
		_altitude_voice.stream = null
	_altitude_stream = null

func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {"accepted": accepted, "reason": reason, "generation": _generation}.duplicate(true)

func _exit_tree() -> void:
	detach()
