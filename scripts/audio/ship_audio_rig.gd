class_name ShipAudioRig
extends Node3D

signal semantic_engine_cue_emitted(cue_id: StringName, intensity: float)

## Reusable ship-local, profile-driven positional audio component.
##
## The rig owns a fixed six-voice hierarchy: four independently gated loop
## layers and two replacement-style transient voices. All resident samples are
## deterministic project-original PCM; no historical Keth audio is claimed.

signal state_changed(snapshot: Dictionary)
signal cue_requested(cue_id: StringName, intensity: float, playback_queued: bool)

const SCHEMA_VERSION := 1
const COMPONENT_ID: StringName = &"ship-audio-rig"
const EVIDENCE_STATUS: StringName = &"modern_interpretation"
const DESIGN_ORIGIN: StringName = &"project_original_procedural_audio"

const PROFILE_STANDARD_FIGHTER: StringName = &"standard_fighter"
const PROFILE_EFFICIENT_TWIN_RECON: StringName = &"efficient_twin_recon"
const PROFILE_HEAVY_QUAD_FREIGHTER: StringName = &"heavy_quad_freighter"
const DECLARED_PROFILE_IDS := [
	PROFILE_STANDARD_FIGHTER,
	PROFILE_EFFICIENT_TWIN_RECON,
	PROFILE_HEAVY_QUAD_FREIGHTER,
]

const LOOP_IDLE: StringName = &"thrust_idle"
const LOOP_LOAD: StringName = &"thrust_load"
const LOOP_BOOST: StringName = &"thrust_boost"
const LOOP_DAMAGE_ALARM: StringName = &"damage_alarm"
const LOOP_IDS := [LOOP_IDLE, LOOP_LOAD, LOOP_BOOST, LOOP_DAMAGE_ALARM]

const CUE_STARTUP: StringName = &"engine_startup"
const CUE_STOP: StringName = &"engine_stop"
const CUE_FIRE: StringName = &"weapon_fire"
const CUE_IMPACT: StringName = &"impact"
const CUE_HULL_HIT: StringName = &"hull_hit"
const CUE_DESTRUCTION: StringName = &"destruction"
const CUE_LANDING: StringName = &"landing"
const CUE_DOCKING: StringName = &"docking"
const CUE_IDS := [
	CUE_STARTUP,
	CUE_STOP,
	CUE_FIRE,
	CUE_IMPACT,
	CUE_HULL_HIT,
	CUE_DESTRUCTION,
	CUE_LANDING,
	CUE_DOCKING,
]

const VOICE_IDLE: StringName = &"idle_voice"
const VOICE_LOAD: StringName = &"load_voice"
const VOICE_BOOST: StringName = &"boost_voice"
const VOICE_ALARM: StringName = &"alarm_voice"
const VOICE_ENGINE_CUE: StringName = &"engine_cue_voice"
const VOICE_COMBAT_CUE: StringName = &"combat_cue_voice"
const LOOP_VOICE_IDS := [VOICE_IDLE, VOICE_LOAD, VOICE_BOOST, VOICE_ALARM]
const TRANSIENT_VOICE_IDS := [VOICE_ENGINE_CUE, VOICE_COMBAT_CUE]
const ALL_VOICE_IDS := [
	VOICE_IDLE,
	VOICE_LOAD,
	VOICE_BOOST,
	VOICE_ALARM,
	VOICE_ENGINE_CUE,
	VOICE_COMBAT_CUE,
]

const VOICE_PATHS := {
	VOICE_IDLE: NodePath("ThrustIdle"),
	VOICE_LOAD: NodePath("ThrustLoad"),
	VOICE_BOOST: NodePath("ThrustBoost"),
	VOICE_ALARM: NodePath("DamageAlarm"),
	VOICE_ENGINE_CUE: NodePath("EngineCueVoice"),
	VOICE_COMBAT_CUE: NodePath("CombatCueVoice"),
}
const CUE_TIMER_PATHS := {
	VOICE_ENGINE_CUE: NodePath("EngineCueExpiry"),
	VOICE_COMBAT_CUE: NodePath("CombatCueExpiry"),
}
const VOICE_BUSES := {
	VOICE_IDLE: &"Engines",
	VOICE_LOAD: &"Engines",
	VOICE_BOOST: &"Engines",
	VOICE_ALARM: &"UI",
	VOICE_ENGINE_CUE: &"Engines",
	VOICE_COMBAT_CUE: &"Weapons",
}
const LOOP_TO_VOICE := {
	LOOP_IDLE: VOICE_IDLE,
	LOOP_LOAD: VOICE_LOAD,
	LOOP_BOOST: VOICE_BOOST,
	LOOP_DAMAGE_ALARM: VOICE_ALARM,
}
const CUE_TO_VOICE := {
	CUE_STARTUP: VOICE_ENGINE_CUE,
	CUE_STOP: VOICE_ENGINE_CUE,
	CUE_FIRE: VOICE_COMBAT_CUE,
	CUE_IMPACT: VOICE_COMBAT_CUE,
	CUE_HULL_HIT: VOICE_COMBAT_CUE,
	CUE_DESTRUCTION: VOICE_COMBAT_CUE,
	CUE_LANDING: VOICE_ENGINE_CUE,
	CUE_DOCKING: VOICE_ENGINE_CUE,
}

const PROFILE_SPECS := {
	PROFILE_STANDARD_FIGHTER: {
		"display_name": "Standard fighter",
		"synthesis_seed": 1101,
		"base_frequency_hz": 72.0,
		"harmonic_blend": 0.24,
		"mechanical_texture": 0.032,
		"engine_pitch_scale": 1.0,
		"cue_pitch_scale": 1.0,
		"idle_volume_db": -15.0,
		"load_volume_db": -10.5,
		"boost_volume_db": -7.0,
		"alarm_volume_db": -8.5,
		"engine_cue_volume_db": -5.0,
		"combat_cue_volume_db": -3.0,
	},
	PROFILE_EFFICIENT_TWIN_RECON: {
		"display_name": "Efficient twin recon",
		"synthesis_seed": 1102,
		"base_frequency_hz": 96.0,
		"harmonic_blend": 0.14,
		"mechanical_texture": 0.016,
		"engine_pitch_scale": 1.1,
		"cue_pitch_scale": 1.17,
		"idle_volume_db": -18.0,
		"load_volume_db": -13.0,
		"boost_volume_db": -8.5,
		"alarm_volume_db": -9.5,
		"engine_cue_volume_db": -7.0,
		"combat_cue_volume_db": -4.5,
	},
	PROFILE_HEAVY_QUAD_FREIGHTER: {
		"display_name": "Heavy quad freighter",
		"synthesis_seed": 1103,
		"base_frequency_hz": 42.0,
		"harmonic_blend": 0.36,
		"mechanical_texture": 0.052,
		"engine_pitch_scale": 0.84,
		"cue_pitch_scale": 0.78,
		"idle_volume_db": -12.5,
		"load_volume_db": -8.0,
		"boost_volume_db": -5.0,
		"alarm_volume_db": -7.0,
		"engine_cue_volume_db": -3.5,
		"combat_cue_volume_db": -1.5,
	},
}

const SAMPLE_RATE := 12000
const LOOP_DURATIONS := {
	LOOP_IDLE: 0.80,
	LOOP_LOAD: 0.80,
	LOOP_BOOST: 0.60,
	LOOP_DAMAGE_ALARM: 0.50,
}
const CUE_DURATIONS := {
	CUE_STARTUP: 0.70,
	CUE_STOP: 0.45,
	CUE_FIRE: 0.16,
	CUE_IMPACT: 0.26,
	CUE_HULL_HIT: 0.32,
	CUE_DESTRUCTION: 0.90,
	CUE_LANDING: 0.30,
	CUE_DOCKING: 0.28,
}
const EXPECTED_RESIDENT_SAMPLE_BYTES := 145680
const RESIDENT_BYTE_BUDGET := 163840
const LOOP_VOICE_COUNT := 4
const TRANSIENT_VOICE_COUNT := 2
const MAXIMUM_SIMULTANEOUS_VOICES := 6
const ATTENUATION_FILTER_CUTOFF_HZ := 7000.0
const ATTENUATION_FILTER_DB := -18.0
const MINIMUM_LOAD_THROTTLE := 0.02
const MINIMUM_BOOST_THROTTLE := 0.10
const CUE_CLEANUP_MARGIN_SECONDS := 0.12
const CONTENT_NOTE := (
	"Every ship profile, waveform, mix level, audible range, and cue association "
	+ "is project-original modern sound design. No surviving source authenticates "
	+ "the original ships' engine, weapon, impact, alarm, destruction, or docking audio."
)

@export_category("Identity")
@export var rig_id: StringName = &"ship_audio"
@export var profile_id: StringName = PROFILE_STANDARD_FIGHTER

@export_category("Spatial mix")
@export_range(8.0, 300.0, 1.0) var maximum_distance := 180.0
@export_range(0.5, 30.0, 0.25) var reference_distance := 5.0
@export var rig_enabled := true

var _players: Dictionary = {}
var _player_instance_ids: Dictionary = {}
var _cue_expiry_timers: Dictionary = {}
var _timer_instance_ids: Dictionary = {}
var _loop_streams: Dictionary = {}
var _cue_streams: Dictionary = {}
var _resource_instance_ids: Dictionary = {}
var _fingerprints: Dictionary = {}
var _resident_sample_bytes := 0
var _synthesis_generation_count := 0
var _resources_ready := false
var _playback_queue_allowed := false
var _tearing_down := false
var _initialized := false

var _has_build_snapshot := false
var _built_profile_id: StringName = &""
var _built_maximum_distance := 0.0
var _built_reference_distance := 0.0

var _engine_running := false
var _throttle := 0.0
var _engine_degradation := 0.0
var _engine_velocity := 0.0
var _last_degradation_band := 0
var _last_velocity_high := false
var _boost_requested := false
var _damage_alarm_active := false
var _last_cue_id: StringName = &""
var _cue_request_count := 0
var _expected_volumes: Dictionary = {}
var _expected_pitches: Dictionary = {}
var _active_cues_by_voice: Dictionary = {}


func _enter_tree() -> void:
	_tearing_down = false
	if _initialized:
		_playback_queue_allowed = _detect_playback_queue_candidate()
		_configure_players_from_snapshot()
		if rig_enabled:
			_ensure_synthesized()
		call_deferred("_restore_after_enter_tree")


func _ready() -> void:
	_tearing_down = false
	_playback_queue_allowed = _detect_playback_queue_candidate()
	_cache_players()
	_capture_build_snapshot()
	_configure_players_from_snapshot()
	_connect_transient_completion()
	_apply_metadata()
	add_to_group(&"ship_audio_rig", false)
	_initialized = true
	if rig_enabled:
		_ensure_synthesized()
	_apply_runtime_state()


func _exit_tree() -> void:
	_tearing_down = true
	_discard_audio_resources(true)


func get_component_id() -> StringName:
	return COMPONENT_ID


func get_rig_id() -> StringName:
	return rig_id


func get_profile_id() -> StringName:
	return _built_profile_id if _has_build_snapshot else profile_id


static func get_declared_profile_ids() -> PackedStringArray:
	return PackedStringArray(DECLARED_PROFILE_IDS)


static func is_declared_profile_id(candidate: StringName) -> bool:
	return PROFILE_SPECS.has(candidate)


func get_supported_cues() -> PackedStringArray:
	return PackedStringArray(CUE_IDS)


func set_rig_enabled(enabled: bool) -> void:
	if not _can_mutate_runtime_state():
		return
	if rig_enabled == enabled:
		if is_inside_tree():
			if enabled:
				_playback_queue_allowed = _detect_playback_queue_candidate()
			_apply_runtime_state()
		return
	rig_enabled = enabled
	if is_inside_tree():
		if enabled:
			_playback_queue_allowed = _detect_playback_queue_candidate()
			_ensure_synthesized()
		_apply_runtime_state()
	_emit_state_changed()


func is_rig_enabled() -> bool:
	return rig_enabled


## Changes the desired engine state. The return value reports a state change,
## not whether a real audio driver played the optional transition cue.
func set_engine_running(running: bool, play_transition: bool = true) -> bool:
	if not _can_mutate_runtime_state():
		return false
	if _engine_running == running:
		return false
	_engine_running = running
	if not running:
		_boost_requested = false
	_apply_runtime_state()
	if play_transition:
		play_cue(CUE_STARTUP if running else CUE_STOP)
	_emit_state_changed()
	return true


## Applies caller-owned presentation degradation to engine loops. Zero is the
## authored baseline; this never reads health or owns damage authority.
func set_engine_degradation(degradation: float) -> bool:
	if not _can_mutate_runtime_state() or not is_finite(degradation) \
			or degradation < 0.0 or degradation > 1.0:
		return false
	_engine_degradation = degradation
	_update_expected_mix(_get_built_profile_spec())
	var band := 2 if degradation >= 0.75 else (1 if degradation >= 0.25 else 0)
	if band != _last_degradation_band:
		if band == 2:
			semantic_engine_cue_emitted.emit(&"engine_critical", degradation)
		elif band == 1:
			semantic_engine_cue_emitted.emit(&"engine_degraded", degradation)
		elif _last_degradation_band > 0:
			semantic_engine_cue_emitted.emit(&"engine_recovered", degradation)
		_last_degradation_band = band
	return true


func get_engine_degradation() -> float:
	return _engine_degradation


## Applies caller-owned velocity/load response independently of flight state.
func set_engine_velocity(velocity: float) -> bool:
	if not _can_mutate_runtime_state() or not is_finite(velocity) \
			or velocity < 0.0 or velocity > 1.0:
		return false
	_engine_velocity = velocity
	_update_expected_mix(_get_built_profile_spec())
	var high_load := velocity >= 0.75
	if high_load != _last_velocity_high:
		semantic_engine_cue_emitted.emit(
			&"engine_load_high" if high_load else &"engine_load_normal",
			velocity
		)
		_last_velocity_high = high_load
	return true


func get_engine_velocity() -> float:
	return _engine_velocity


func is_engine_running() -> bool:
	return _engine_running


## Updates continuous thrust layers without adding a per-frame callback. Invalid
## non-finite input is rejected; ordinary finite input is clamped to [0, 1].
func set_thrust_state(throttle: float, boosting: bool = false) -> bool:
	if not _can_mutate_runtime_state():
		return false
	if not is_finite(throttle):
		return false
	var safe_throttle := clampf(throttle, 0.0, 1.0)
	var changed := not is_equal_approx(_throttle, safe_throttle) or _boost_requested != boosting
	_throttle = safe_throttle
	_boost_requested = boosting
	_apply_runtime_state()
	if changed:
		_emit_state_changed()
	return true


func set_damage_alarm_active(active: bool) -> bool:
	if not _can_mutate_runtime_state():
		return false
	if _damage_alarm_active == active:
		return false
	_damage_alarm_active = active
	_apply_runtime_state()
	semantic_engine_cue_emitted.emit(
		&"engine_damage_alarm" if active else &"engine_damage_alarm_cleared",
		1.0 if active else 0.0
	)
	_emit_state_changed()
	return true


func is_damage_alarm_active() -> bool:
	return _damage_alarm_active


## Plays a supported one-shot through one of two fixed replacement voices. An
## accepted cue on one channel replaces the older cue on that channel. The
## return value is false under Dummy or when a named backend rejects the playback
## handle. On a queue-candidate backend, true means `play()` was queued; it does
## not claim that a mixer callback or audible device output has occurred.
func play_cue(cue_id: StringName, intensity: float = 1.0) -> bool:
	if (
		not CUE_TO_VOICE.has(cue_id)
		or not is_finite(intensity)
		or intensity <= 0.0
		or not rig_enabled
		or not _can_mutate_runtime_state()
		or not is_inside_tree()
	):
		return false
	_ensure_synthesized()
	var stream := _cue_streams.get(cue_id) as AudioStreamWAV
	var voice_id := CUE_TO_VOICE.get(cue_id, &"") as StringName
	var player := _players.get(voice_id) as AudioStreamPlayer3D
	if stream == null or not is_instance_valid(player):
		return false
	var safe_intensity := clampf(intensity, 0.1, 1.5)
	_last_cue_id = cue_id
	_cue_request_count += 1
	_active_cues_by_voice.erase(voice_id)
	_stop_cue_timer(voice_id)
	_stop_and_detach(player)
	var profile := _get_built_profile_spec()
	_expected_volumes[voice_id] = _base_volume_for_voice(voice_id, profile) + linear_to_db(safe_intensity)
	_expected_pitches[voice_id] = _base_pitch_for_voice(voice_id, profile) * _cue_pitch_multiplier(cue_id)
	player.volume_db = float(_expected_volumes[voice_id])
	player.pitch_scale = float(_expected_pitches[voice_id])
	var playback_queued := false
	if _playback_queue_allowed:
		player.stream = stream
		if _request_player_playback(player):
			_active_cues_by_voice[voice_id] = cue_id
			_start_cue_timer(voice_id, cue_id)
			playback_queued = true
		else:
			# A named backend can still fail to accept a playback handle. Degrade to
			# the same detached state as Dummy rather than pinning a stale stream.
			_reject_playback_queue()
	cue_requested.emit(cue_id, safe_intensity, playback_queued)
	return playback_queued


func play_weapon_fire(intensity: float = 1.0) -> bool:
	return play_cue(CUE_FIRE, intensity)


func play_impact(intensity: float = 1.0) -> bool:
	return play_cue(CUE_IMPACT, intensity)


func play_hull_hit(intensity: float = 1.0) -> bool:
	return play_cue(CUE_HULL_HIT, intensity)


func play_destruction(intensity: float = 1.0) -> bool:
	if not _can_mutate_runtime_state():
		return false
	_engine_running = false
	_boost_requested = false
	_damage_alarm_active = false
	_apply_runtime_state()
	_emit_state_changed()
	semantic_engine_cue_emitted.emit(&"ship_destroyed", clampf(intensity, 0.0, 1.0))
	return play_cue(CUE_DESTRUCTION, intensity)


func play_landing(intensity: float = 1.0) -> bool:
	var accepted := play_cue(CUE_LANDING, intensity)
	if accepted:
		semantic_engine_cue_emitted.emit(&"ship_landing_contact", clampf(intensity, 0.0, 1.0))
	return accepted


func play_docking(intensity: float = 1.0) -> bool:
	return play_cue(CUE_DOCKING, intensity)


## Idempotent deep cleanup. Desired engine/thrust/alarm state and the immutable
## profile/spatial/player identity snapshot are retained, while the rig is
## disabled and every resident waveform and playback handle is freed.
func release_audio_resources() -> void:
	rig_enabled = false
	_discard_audio_resources(true)


## Public desired-state setters remain useful for scene-authored pre-tree setup,
## but an initialized detached or terminal rig cannot accept runtime intent.
func _can_mutate_runtime_state() -> bool:
	return not _tearing_down and not is_queued_for_deletion() \
		and (not _initialized or is_inside_tree())


func get_profile_report() -> Dictionary:
	var requested_supported := is_declared_profile_id(profile_id)
	var active_profile := get_profile_id()
	var spec: Dictionary = PROFILE_SPECS.get(active_profile, {})
	return {
		"schema_version": SCHEMA_VERSION,
		"requested_profile_id": profile_id,
		"built_profile_id": _built_profile_id,
		"active_profile_id": active_profile,
		"declared_profile_ids": get_declared_profile_ids(),
		"requested_profile_supported": requested_supported,
		"configuration_current": _has_build_snapshot and profile_id == _built_profile_id,
		"display_name": str(spec.get("display_name", "Invalid profile")),
		"synthesis_seed": int(spec.get("synthesis_seed", 0)),
		"base_frequency_hz": float(spec.get("base_frequency_hz", 0.0)),
		"harmonic_blend": float(spec.get("harmonic_blend", 0.0)),
		"mechanical_texture": float(spec.get("mechanical_texture", 0.0)),
		"engine_pitch_scale": float(spec.get("engine_pitch_scale", 0.0)),
		"cue_pitch_scale": float(spec.get("cue_pitch_scale", 0.0)),
	}


func get_state_snapshot() -> Dictionary:
	var desired_layers := PackedStringArray()
	for loop_id in LOOP_IDS:
		if _is_loop_desired(loop_id):
			desired_layers.append(str(loop_id))
	var queued_voices := PackedStringArray()
	for voice_id in ALL_VOICE_IDS:
		var player := _players.get(voice_id) as AudioStreamPlayer3D
		if is_instance_valid(player) and player.playing and player.stream != null:
			queued_voices.append(str(voice_id))
	return {
		"schema_version": SCHEMA_VERSION,
		"rig_enabled": rig_enabled,
		"engine_running": _engine_running,
		"throttle": _throttle,
		"engine_degradation": _engine_degradation,
		"engine_velocity": _engine_velocity,
		"boost_requested": _boost_requested,
		"boost_active": _engine_running and _boost_requested and _throttle >= MINIMUM_BOOST_THROTTLE,
		"damage_alarm_active": _damage_alarm_active,
		"desired_loop_layers": desired_layers,
		"queued_voice_ids": queued_voices,
		"active_cues_by_voice": _active_cues_by_voice.duplicate(true),
		"last_cue_id": _last_cue_id,
		"cue_request_count": _cue_request_count,
		"inside_tree": is_inside_tree(),
		"tearing_down": _tearing_down,
		"audio_driver": AudioServer.get_driver_name(),
		"playback_queue_allowed": _playback_queue_allowed,
		"output_audibility_verified": false,
		"output_claim_scope": &"engine_queue_state_not_audibility",
		"audio_output_latency_seconds": AudioServer.get_output_latency(),
	}


func get_cue_contract() -> Dictionary:
	var routes := {}
	var profile := _get_built_profile_spec()
	for cue_id in CUE_IDS:
		var voice_id := CUE_TO_VOICE[cue_id] as StringName
		var effective_pitch := _base_pitch_for_voice(voice_id, profile) * _cue_pitch_multiplier(cue_id)
		var effective_duration := float(CUE_DURATIONS[cue_id]) / maxf(effective_pitch, 0.01)
		routes[cue_id] = {
			"voice_id": voice_id,
			"bus": VOICE_BUSES[voice_id],
			"duration_seconds": float(CUE_DURATIONS[cue_id]),
			"effective_pitch_scale": effective_pitch,
			"effective_duration_seconds": effective_duration,
			"cleanup_timeout_seconds": effective_duration + CUE_CLEANUP_MARGIN_SECONDS,
			"replacement_channel": true,
		}
	return {
		"schema_version": SCHEMA_VERSION,
		"supported_cue_ids": get_supported_cues(),
		"routes": routes,
		"engine_channel_voice_id": VOICE_ENGINE_CUE,
		"combat_channel_voice_id": VOICE_COMBAT_CUE,
		"maximum_simultaneous_transients": TRANSIENT_VOICE_COUNT,
		"cleanup_margin_seconds": CUE_CLEANUP_MARGIN_SECONDS,
	}


func get_spatial_contract() -> Dictionary:
	var voice_buses := {}
	for voice_id in ALL_VOICE_IDS:
		voice_buses[voice_id] = VOICE_BUSES[voice_id]
	return {
		"schema_version": SCHEMA_VERSION,
		"origin": &"ship_local_component_position",
		"orientation": &"omnidirectional_rotation_independent",
		"attenuation_model": &"inverse_distance",
		"maximum_distance": _built_maximum_distance if _has_build_snapshot else _safe_maximum_distance(),
		"reference_distance": _built_reference_distance if _has_build_snapshot else _safe_reference_distance(),
		"requested_maximum_distance": maximum_distance,
		"requested_reference_distance": reference_distance,
		"voice_buses": voice_buses,
		"configuration_current": _spatial_configuration_current(),
		"panning_strength": 1.0,
		"doppler_tracking": &"disabled",
	}


func get_synthesis_report() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"sample_rate": SAMPLE_RATE,
		"channel_count": 1,
		"sample_format": &"signed_pcm_16_bit",
		"loop_template_count": _loop_streams.size(),
		"cue_template_count": _cue_streams.size(),
		"expected_loop_template_count": LOOP_IDS.size(),
		"expected_cue_template_count": CUE_IDS.size(),
		"resources_ready": _resources_ready,
		"resident_sample_bytes": _resident_sample_bytes,
		"expected_resident_sample_bytes": EXPECTED_RESIDENT_SAMPLE_BYTES,
		"resident_byte_budget": RESIDENT_BYTE_BUDGET,
		"resident_byte_budget_scope": &"component_owned_raw_pcm_data",
		"fingerprints_sha256": _fingerprints.duplicate(true),
		"resource_instance_ids": _resource_instance_ids.duplicate(true),
		"loop_seams_pcm": _get_loop_seam_report(),
		"generation_count": _synthesis_generation_count,
		"built_profile_id": _built_profile_id,
		"requested_profile_id": profile_id,
		"configuration_current": _has_build_snapshot and profile_id == _built_profile_id,
	}


func get_performance_report() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"audio_player_count": find_children("*", "AudioStreamPlayer3D", true, false).size(),
		"loop_voice_count": LOOP_VOICE_COUNT,
		"transient_voice_count": TRANSIENT_VOICE_COUNT,
		"maximum_simultaneous_voices": MAXIMUM_SIMULTANEOUS_VOICES,
		"maximum_simultaneous_transients": TRANSIENT_VOICE_COUNT,
		"cue_expiry_timer_count": _cue_expiry_timers.size(),
		"per_frame_script_processing": is_processing(),
		"per_physics_frame_script_processing": is_physics_processing(),
		"resident_sample_bytes": _resident_sample_bytes,
		"resident_byte_budget": RESIDENT_BYTE_BUDGET,
		"resident_byte_budget_scope": &"component_owned_raw_pcm_data",
		"within_resident_budget": _resident_sample_bytes <= RESIDENT_BYTE_BUDGET,
		"audio_driver": AudioServer.get_driver_name(),
		"playback_queue_allowed": _playback_queue_allowed,
		"output_audibility_verified": false,
		"output_claim_scope": &"engine_queue_state_not_audibility",
		"audio_output_latency_seconds": AudioServer.get_output_latency(),
	}


func get_evidence_metadata() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"evidence_status": EVIDENCE_STATUS,
		"design_origin": DESIGN_ORIGIN,
		"historically_supported": false,
		"content_note": CONTENT_NOTE,
		"modern_interpretations": PackedStringArray([
			"profile-specific engine timbres",
			"startup and stop cues",
			"idle, load, and boost thrust layers",
			"weapon, impact, hull-hit, alarm, and destruction cues",
			"landing and docking cues",
			"spatial attenuation and mix levels",
		]),
	}


func get_audit_report() -> Dictionary:
	var errors := PackedStringArray()
	_append_identity_errors(errors)
	_append_hierarchy_errors(errors)
	_append_configuration_errors(errors)
	_append_resource_errors(errors)
	_append_lifecycle_errors(errors)
	var report := {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"component_id": COMPONENT_ID,
		"rig_id": rig_id,
		"profile": get_profile_report(),
		"state": get_state_snapshot(),
		"cues": get_cue_contract(),
		"spatial": get_spatial_contract(),
		"synthesis": get_synthesis_report(),
		"performance": get_performance_report(),
		"evidence": get_evidence_metadata(),
		"player_instance_ids": _player_instance_ids.duplicate(true),
	}
	return report.duplicate(true)


func _cache_players() -> void:
	_players.clear()
	_cue_expiry_timers.clear()
	for voice_id in ALL_VOICE_IDS:
		_players[voice_id] = get_node_or_null(VOICE_PATHS[voice_id]) as AudioStreamPlayer3D
	for voice_id in TRANSIENT_VOICE_IDS:
		_cue_expiry_timers[voice_id] = get_node_or_null(CUE_TIMER_PATHS[voice_id]) as Timer


func _capture_build_snapshot() -> void:
	if _has_build_snapshot:
		return
	_built_profile_id = profile_id
	_built_maximum_distance = _safe_maximum_distance()
	_built_reference_distance = _safe_reference_distance()
	_player_instance_ids.clear()
	_timer_instance_ids.clear()
	for voice_id in ALL_VOICE_IDS:
		var player := _players.get(voice_id) as AudioStreamPlayer3D
		if is_instance_valid(player):
			_player_instance_ids[voice_id] = player.get_instance_id()
	for voice_id in TRANSIENT_VOICE_IDS:
		var timer := _cue_expiry_timers.get(voice_id) as Timer
		if is_instance_valid(timer):
			_timer_instance_ids[voice_id] = timer.get_instance_id()
	_has_build_snapshot = true


func _configure_players_from_snapshot() -> void:
	if not _has_build_snapshot:
		return
	var profile := _get_built_profile_spec()
	_update_expected_mix(profile)
	for voice_id in ALL_VOICE_IDS:
		var player := _players.get(voice_id) as AudioStreamPlayer3D
		if not is_instance_valid(player):
			continue
		player.autoplay = false
		player.bus = VOICE_BUSES[voice_id]
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		player.max_distance = _built_maximum_distance
		player.unit_size = _built_reference_distance
		player.max_db = -2.0
		player.panning_strength = 1.0
		player.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		player.emission_angle_enabled = false
		player.area_mask = 0
		player.max_polyphony = 1
		player.volume_db = float(_expected_volumes.get(voice_id, -12.0))
		player.pitch_scale = float(_expected_pitches.get(voice_id, 1.0))
		player.position = Vector3.ZERO
		player.attenuation_filter_cutoff_hz = ATTENUATION_FILTER_CUTOFF_HZ
		player.attenuation_filter_db = ATTENUATION_FILTER_DB
		player.stream_paused = false
	set_process(false)
	set_physics_process(false)
	_configure_cue_timers()


func _connect_transient_completion() -> void:
	for voice_id in TRANSIENT_VOICE_IDS:
		var player := _players.get(voice_id) as AudioStreamPlayer3D
		if not is_instance_valid(player):
			continue
		var callback := Callable(self, "_on_transient_finished").bind(voice_id)
		if not player.finished.is_connected(callback):
			player.finished.connect(callback)
		var timer := _cue_expiry_timers.get(voice_id) as Timer
		if is_instance_valid(timer):
			var timer_callback := Callable(self, "_on_cue_expiry_timeout").bind(voice_id)
			if not timer.timeout.is_connected(timer_callback):
				timer.timeout.connect(timer_callback)


func _configure_cue_timers() -> void:
	for voice_id in TRANSIENT_VOICE_IDS:
		var timer := _cue_expiry_timers.get(voice_id) as Timer
		if not is_instance_valid(timer):
			continue
		timer.one_shot = true
		timer.autostart = false
		timer.process_callback = Timer.TIMER_PROCESS_IDLE
		if timer.is_stopped():
			timer.wait_time = 1.0


func _restore_after_enter_tree() -> void:
	if _tearing_down or is_queued_for_deletion() or not is_inside_tree():
		return
	_apply_runtime_state()


func _apply_runtime_state() -> void:
	if not _initialized and not is_inside_tree():
		return
	var profile := _get_built_profile_spec()
	_update_expected_mix(profile)
	if not rig_enabled or _tearing_down or not is_inside_tree():
		_stop_all_players()
		return
	_ensure_synthesized()
	if not _resources_ready or not _playback_queue_allowed:
		_stop_all_players()
		return
	for loop_id in LOOP_IDS:
		var voice_id := LOOP_TO_VOICE[loop_id] as StringName
		var player := _players.get(voice_id) as AudioStreamPlayer3D
		var stream := _loop_streams.get(loop_id) as AudioStreamWAV
		_sync_loop_player(player, stream, _is_loop_desired(loop_id), voice_id)
		if not _playback_queue_allowed:
			break


func _sync_loop_player(
	player: AudioStreamPlayer3D,
	stream: AudioStreamWAV,
	active: bool,
	voice_id: StringName
	) -> void:
	if not is_instance_valid(player):
		return
	player.volume_db = float(_expected_volumes.get(voice_id, -12.0))
	player.pitch_scale = float(_expected_pitches.get(voice_id, 1.0))
	if not active or stream == null:
		_stop_and_detach(player)
		player.volume_db = float(_expected_volumes.get(voice_id, -12.0))
		player.pitch_scale = float(_expected_pitches.get(voice_id, 1.0))
		return
	if player.stream != stream:
		_stop_and_detach(player)
		player.stream = stream
	if not player.playing:
		if not _request_player_playback(player):
			_reject_playback_queue()


## Single playback-attempt seam. A named backend is only a queue candidate until
## the engine confirms that this exact player accepted its playback handle.
func _request_player_playback(player: AudioStreamPlayer3D) -> bool:
	player.play()
	return player.playing


func _reject_playback_queue() -> void:
	_playback_queue_allowed = false
	_stop_all_players()


func _is_loop_desired(loop_id: StringName) -> bool:
	match loop_id:
		LOOP_IDLE:
			return _engine_running
		LOOP_LOAD:
			return _engine_running and _throttle >= MINIMUM_LOAD_THROTTLE
		LOOP_BOOST:
			return _engine_running and _boost_requested and _throttle >= MINIMUM_BOOST_THROTTLE
		LOOP_DAMAGE_ALARM:
			return _damage_alarm_active
		_:
			return false


func _update_expected_mix(profile: Dictionary) -> void:
	var engine_pitch := float(profile.get("engine_pitch_scale", 1.0))
	var degradation_gain_db := -6.0 * _engine_degradation
	var degradation_pitch := lerpf(1.0, 0.86, _engine_degradation)
	var velocity_gain_db := lerpf(0.0, 3.0, _engine_velocity)
	var velocity_pitch := lerpf(1.0, 1.12, _engine_velocity)
	_expected_volumes[VOICE_IDLE] = float(profile.get("idle_volume_db", -15.0)) + lerpf(-1.0, 1.0, _throttle) + degradation_gain_db + velocity_gain_db
	_expected_volumes[VOICE_LOAD] = float(profile.get("load_volume_db", -10.5)) + linear_to_db(maxf(_throttle, 0.05)) + degradation_gain_db + velocity_gain_db
	_expected_volumes[VOICE_BOOST] = float(profile.get("boost_volume_db", -7.0)) + degradation_gain_db + velocity_gain_db
	_expected_volumes[VOICE_ALARM] = float(profile.get("alarm_volume_db", -8.5))
	_expected_pitches[VOICE_IDLE] = engine_pitch * lerpf(0.92, 1.06, _throttle) * degradation_pitch * velocity_pitch
	_expected_pitches[VOICE_LOAD] = engine_pitch * lerpf(0.84, 1.22, _throttle) * degradation_pitch * velocity_pitch
	_expected_pitches[VOICE_BOOST] = engine_pitch * lerpf(1.08, 1.18, _throttle) * degradation_pitch * velocity_pitch
	_expected_pitches[VOICE_ALARM] = float(profile.get("cue_pitch_scale", 1.0))
	for voice_id in LOOP_VOICE_IDS:
		var player := _players.get(voice_id) as AudioStreamPlayer3D
		if is_instance_valid(player):
			player.volume_db = float(_expected_volumes[voice_id])
			player.pitch_scale = float(_expected_pitches[voice_id])
	for voice_id in TRANSIENT_VOICE_IDS:
		if _active_cues_by_voice.has(voice_id):
			continue
		_expected_volumes[voice_id] = _base_volume_for_voice(voice_id, profile)
		_expected_pitches[voice_id] = _base_pitch_for_voice(voice_id, profile)
		var player := _players.get(voice_id) as AudioStreamPlayer3D
		if is_instance_valid(player):
			player.volume_db = float(_expected_volumes[voice_id])
			player.pitch_scale = float(_expected_pitches[voice_id])


func _base_volume_for_voice(voice_id: StringName, profile: Dictionary) -> float:
	return (
		float(profile.get("engine_cue_volume_db", -5.0))
		if voice_id == VOICE_ENGINE_CUE
		else float(profile.get("combat_cue_volume_db", -3.0))
	)


func _base_pitch_for_voice(_voice_id: StringName, profile: Dictionary) -> float:
	return float(profile.get("cue_pitch_scale", 1.0))


func _cue_pitch_multiplier(cue_id: StringName) -> float:
	match cue_id:
		CUE_STARTUP:
			return 1.0
		CUE_STOP:
			return 0.92
		CUE_FIRE:
			return 1.12
		CUE_IMPACT:
			return 0.86
		CUE_HULL_HIT:
			return 0.72
		CUE_DESTRUCTION:
			return 0.68
		CUE_LANDING:
			return 0.9
		CUE_DOCKING:
			return 1.04
		_:
			return 1.0


func _on_transient_finished(voice_id: StringName) -> void:
	if _tearing_down:
		return
	var player := _players.get(voice_id) as AudioStreamPlayer3D
	if not is_instance_valid(player) or player.playing:
		return
	_complete_transient(voice_id)


func _on_cue_expiry_timeout(voice_id: StringName) -> void:
	# This bounded fallback is independent of mixer callbacks. It prevents an
	# unavailable or suspended backend from retaining an attached one-shot.
	_complete_transient(voice_id)


func _complete_transient(voice_id: StringName) -> void:
	var player := _players.get(voice_id) as AudioStreamPlayer3D
	if not is_instance_valid(player):
		return
	_stop_cue_timer(voice_id)
	_active_cues_by_voice.erase(voice_id)
	_stop_and_detach(player)
	var profile := _get_built_profile_spec()
	_expected_volumes[voice_id] = _base_volume_for_voice(voice_id, profile)
	_expected_pitches[voice_id] = _base_pitch_for_voice(voice_id, profile)
	player.volume_db = float(_expected_volumes[voice_id])
	player.pitch_scale = float(_expected_pitches[voice_id])


func _start_cue_timer(voice_id: StringName, cue_id: StringName) -> void:
	var timer := _cue_expiry_timers.get(voice_id) as Timer
	if not is_instance_valid(timer):
		return
	var pitch := maxf(0.01, float(_expected_pitches.get(voice_id, 1.0)))
	timer.wait_time = float(CUE_DURATIONS[cue_id]) / pitch + CUE_CLEANUP_MARGIN_SECONDS
	timer.start()


func _stop_cue_timer(voice_id: StringName) -> void:
	var timer := _cue_expiry_timers.get(voice_id) as Timer
	if is_instance_valid(timer):
		timer.stop()


func _stop_all_players() -> void:
	for voice_id in TRANSIENT_VOICE_IDS:
		_stop_cue_timer(voice_id)
	for voice_id in ALL_VOICE_IDS:
		_stop_and_detach(_players.get(voice_id))
	_active_cues_by_voice.clear()
	var profile := _get_built_profile_spec()
	_update_expected_mix(profile)


func _stop_and_detach(player_value: Variant) -> void:
	if not is_instance_valid(player_value) or not player_value is AudioStreamPlayer3D:
		return
	var player := player_value as AudioStreamPlayer3D
	player.stop()
	player.stream_paused = false
	player.stream = null


func _discard_audio_resources(preserve_build_snapshot: bool) -> void:
	_stop_all_players()
	_loop_streams.clear()
	_cue_streams.clear()
	_resource_instance_ids.clear()
	_fingerprints.clear()
	_resident_sample_bytes = 0
	_resources_ready = false
	if not preserve_build_snapshot:
		_has_build_snapshot = false
		_built_profile_id = &""
		_built_maximum_distance = 0.0
		_built_reference_distance = 0.0


func _ensure_synthesized() -> void:
	if _resources_ready:
		return
	if not _has_build_snapshot:
		_capture_build_snapshot()
	if not is_declared_profile_id(_built_profile_id):
		return
	var profile := _get_built_profile_spec()
	_loop_streams.clear()
	_cue_streams.clear()
	_resource_instance_ids.clear()
	_fingerprints.clear()
	_resident_sample_bytes = 0
	for loop_id in LOOP_IDS:
		var loop_bytes := _synthesize_loop(loop_id, profile)
		var loop_stream := _wave_from_bytes(loop_bytes, true)
		_loop_streams[loop_id] = loop_stream
		_resource_instance_ids[loop_id] = loop_stream.get_instance_id()
		_fingerprints[loop_id] = _sha256(loop_bytes)
		_resident_sample_bytes += loop_bytes.size()
	for cue_id in CUE_IDS:
		var cue_bytes := _synthesize_cue(cue_id, profile)
		var cue_stream := _wave_from_bytes(cue_bytes, false)
		_cue_streams[cue_id] = cue_stream
		_resource_instance_ids[cue_id] = cue_stream.get_instance_id()
		_fingerprints[cue_id] = _sha256(cue_bytes)
		_resident_sample_bytes += cue_bytes.size()
	_resources_ready = true
	_synthesis_generation_count += 1


func _synthesize_loop(loop_id: StringName, profile: Dictionary) -> PackedByteArray:
	var duration := float(LOOP_DURATIONS[loop_id])
	var sample_count := roundi(duration * SAMPLE_RATE)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	var seed := int(profile.get("synthesis_seed", 1101))
	var base := float(profile.get("base_frequency_hz", 72.0))
	var harmonic_blend := float(profile.get("harmonic_blend", 0.24))
	var texture := float(profile.get("mechanical_texture", 0.032))
	var salt := 0
	var frequency_multiplier := 1.0
	match loop_id:
		LOOP_IDLE:
			salt = 17
			frequency_multiplier = 1.0
		LOOP_LOAD:
			salt = 41
			frequency_multiplier = 1.65
		LOOP_BOOST:
			salt = 73
			frequency_multiplier = 2.75
		LOOP_DAMAGE_ALARM:
			salt = 109
			frequency_multiplier = 5.2
	var phase_a := _seed_phase(seed, salt)
	var phase_b := _seed_phase(seed, salt + 31)
	# Every fundamental uses an even whole-cycle count. This also makes the 0.5x
	# subharmonic and the alarm's 1.5x partial complete whole cycles, preventing
	# phase inversion at the forward-loop boundary.
	var fundamental := _periodic_frequency(base * frequency_multiplier, duration, true)
	var modulation := _periodic_frequency(2.0 if loop_id != LOOP_BOOST else 5.0, duration)
	for index in sample_count:
		var time := float(index) / float(SAMPLE_RATE)
		var sample := 0.0
		if loop_id == LOOP_DAMAGE_ALARM:
			# Cosine gating is periodic at both ends; a hard duty-cycle gate would
			# jump from its quiet tail directly into its loud attack every 0.5 s.
			var pulse := 0.08 + 0.92 * pow(0.5 + 0.5 * cos(TAU * time / duration), 5.0)
			var alarm_tone := sin(TAU * fundamental * time + phase_a) * 0.7
			alarm_tone += sin(TAU * fundamental * 1.5 * time + phase_b) * 0.22
			sample = alarm_tone * pulse * 0.34
		else:
			var pulse := 0.88 + 0.12 * sin(TAU * modulation * time + phase_b)
			var body := sin(TAU * fundamental * time + phase_a) * (0.62 - harmonic_blend * 0.2)
			body += sin(TAU * fundamental * 2.0 * time + phase_b) * harmonic_blend
			body += sin(TAU * fundamental * 0.5 * time + phase_a * 0.5) * 0.13
			var mechanical := sin(TAU * _periodic_frequency(base * 4.1 + float(salt), duration) * time + phase_b) * texture
			var amplitude := 0.30 if loop_id == LOOP_IDLE else (0.34 if loop_id == LOOP_LOAD else 0.28)
			sample = (body * pulse + mechanical) * amplitude
		bytes.encode_s16(index * 2, roundi(clampf(sample, -1.0, 1.0) * 32767.0))
	return bytes


func _synthesize_cue(cue_id: StringName, profile: Dictionary) -> PackedByteArray:
	var duration := float(CUE_DURATIONS[cue_id])
	var sample_count := roundi(duration * SAMPLE_RATE)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	var seed := int(profile.get("synthesis_seed", 1101))
	var base := float(profile.get("base_frequency_hz", 72.0))
	var texture := float(profile.get("mechanical_texture", 0.032))
	var salt := 151 + CUE_IDS.find(cue_id) * 37
	var phase := _seed_phase(seed, salt)
	var start_frequency := base
	var sweep := 0.0
	var noise_amount := texture
	match cue_id:
		CUE_STARTUP:
			start_frequency = base * 0.55
			sweep = base * 2.4
		CUE_STOP:
			start_frequency = base * 2.0
			sweep = -base * 2.3
		CUE_FIRE:
			start_frequency = base * 8.0
			sweep = -base * 12.0
			noise_amount *= 0.45
		CUE_IMPACT:
			start_frequency = base * 1.6
			sweep = -base * 1.4
			noise_amount *= 4.0
		CUE_HULL_HIT:
			start_frequency = base * 0.8
			sweep = -base * 0.45
			noise_amount *= 5.5
		CUE_DESTRUCTION:
			start_frequency = base * 1.35
			sweep = -base * 1.1
			noise_amount *= 7.0
		CUE_LANDING:
			start_frequency = base * 1.15
			sweep = -base * 0.35
			noise_amount *= 2.0
		CUE_DOCKING:
			start_frequency = base * 2.2
			sweep = -base * 0.8
			noise_amount *= 1.3
	for index in sample_count:
		var time := float(index) / float(SAMPLE_RATE)
		var progress := float(index) / float(maxi(sample_count - 1, 1))
		var envelope := _cue_envelope(cue_id, progress)
		var swept_phase := TAU * (start_frequency * time + 0.5 * sweep * time * time) + phase
		var tone := sin(swept_phase) * 0.68 + sin(swept_phase * 2.01 + phase * 0.3) * 0.19
		var transient := _deterministic_noise(index, seed, salt) * noise_amount
		if cue_id == CUE_DESTRUCTION:
			transient += sin(TAU * (base * 0.42) * time + phase) * (1.0 - progress) * 0.24
		elif cue_id == CUE_DOCKING:
			transient += sin(TAU * base * 11.0 * time) * exp(-32.0 * progress) * 0.12
		var sample := (tone * 0.42 + transient) * envelope
		bytes.encode_s16(index * 2, roundi(clampf(sample, -1.0, 1.0) * 32767.0))
	return bytes


func _cue_envelope(cue_id: StringName, progress: float) -> float:
	var attack := minf(progress / 0.035, 1.0)
	match cue_id:
		CUE_STARTUP:
			return pow(sin(PI * progress), 0.72)
		CUE_STOP:
			return attack * pow(1.0 - progress, 0.72)
		CUE_FIRE:
			return attack * exp(-7.0 * progress)
		CUE_IMPACT, CUE_HULL_HIT:
			return attack * exp(-4.8 * progress)
		CUE_DESTRUCTION:
			return attack * pow(1.0 - progress, 0.48)
		CUE_LANDING, CUE_DOCKING:
			return attack * exp(-5.5 * progress)
		_:
			return sin(PI * progress)


func _wave_from_bytes(bytes: PackedByteArray, looped: bool) -> AudioStreamWAV:
	var wave := AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	wave.mix_rate = SAMPLE_RATE
	wave.stereo = false
	wave.data = bytes
	if looped:
		wave.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wave.loop_begin = 0
		wave.loop_end = bytes.size() / 2
	return wave


func _periodic_frequency(frequency: float, duration: float, require_even_cycles: bool = false) -> float:
	var cycle_count := maxi(1, roundi(frequency * duration))
	if require_even_cycles and cycle_count % 2 != 0:
		cycle_count += 1
	return float(cycle_count) / duration


func _seed_phase(seed: int, salt: int) -> float:
	var phase_steps := posmod(seed * 104729 + salt * 7919, 3600)
	return TAU * float(phase_steps) / 3600.0


func _deterministic_noise(index: int, seed: int, salt: int) -> float:
	var value := posmod((index + 1) * 1103515245 + seed * 12345 + salt * 2654435761, 2147483647)
	return float(value) / 1073741823.5 - 1.0


func _get_loop_seam_report() -> Dictionary:
	var report := {}
	for loop_id in LOOP_IDS:
		var stream := _loop_streams.get(loop_id) as AudioStreamWAV
		if stream == null or stream.data.size() < 4:
			report[loop_id] = {
				"available": false,
				"seam_delta": -1,
				"maximum_adjacent_delta": -1,
				"bounded": false,
			}
			continue
		var metrics := _measure_loop_seam(stream.data)
		metrics["available"] = true
		report[loop_id] = metrics
	return report


func _loop_seam_is_bounded(stream: AudioStreamWAV) -> bool:
	if stream == null or stream.data.size() < 4:
		return false
	return bool(_measure_loop_seam(stream.data).bounded)


func _measure_loop_seam(data: PackedByteArray) -> Dictionary:
	var sample_count := data.size() / 2
	var first_sample := data.decode_s16(0)
	var previous_sample := first_sample
	var maximum_adjacent_delta := 0
	for sample_index in range(1, sample_count):
		var sample := data.decode_s16(sample_index * 2)
		maximum_adjacent_delta = maxi(maximum_adjacent_delta, absi(sample - previous_sample))
		previous_sample = sample
	var seam_delta := absi(first_sample - previous_sample)
	# The wrap step should be no harsher than an ordinary single-sample step in
	# the same buffer. A small PCM tolerance covers integer quantization near a
	# stationary point without masking a click-scale discontinuity.
	var bounded := seam_delta <= maxi(32, ceili(float(maximum_adjacent_delta) * 1.05))
	return {
		"first_sample": first_sample,
		"last_sample": previous_sample,
		"seam_delta": seam_delta,
		"maximum_adjacent_delta": maximum_adjacent_delta,
		"bounded": bounded,
	}


func _sha256(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	if context.update(bytes) != OK:
		return ""
	return context.finish().hex_encode()


func _get_built_profile_spec() -> Dictionary:
	return PROFILE_SPECS.get(
		_built_profile_id if _has_build_snapshot else profile_id,
		PROFILE_SPECS[PROFILE_STANDARD_FIGHTER]
	) as Dictionary


func _safe_maximum_distance() -> float:
	return clampf(maximum_distance, 8.0, 300.0) if is_finite(maximum_distance) else 180.0


func _safe_reference_distance() -> float:
	return clampf(reference_distance, 0.5, 30.0) if is_finite(reference_distance) else 5.0


## Driver selection decides whether playback may be attempted. Reported output
## latency remains telemetry: several valid Godot backends return zero because
## they do not implement a latency query. Actual `play()` acceptance remains the
## fail-closed authority through `_request_player_playback()`.
static func _is_playback_queue_candidate(
	driver_name: String,
	_reported_output_latency_seconds: float
	) -> bool:
	return not driver_name.is_empty() and driver_name != "Dummy"


func _detect_playback_queue_candidate() -> bool:
	return _is_playback_queue_candidate(
		AudioServer.get_driver_name(),
		AudioServer.get_output_latency()
	)


func _spatial_configuration_current() -> bool:
	return (
		_has_build_snapshot
		and is_equal_approx(maximum_distance, _built_maximum_distance)
		and is_equal_approx(reference_distance, _built_reference_distance)
		and is_finite(maximum_distance)
		and is_finite(reference_distance)
	)


func _append_identity_errors(errors: PackedStringArray) -> void:
	if rig_id.is_empty():
		errors.append("rig_id must not be empty")
	if not is_declared_profile_id(profile_id):
		errors.append("profile_id must exactly match one declared ship audio profile")
	if not _has_build_snapshot and (rig_enabled or _resources_ready):
		errors.append("enabled or resource-owning component is missing its immutable build snapshot")
	elif _has_build_snapshot and profile_id != _built_profile_id:
		errors.append("profile_id changed after the rig was built")
	if get_meta(&"ship_audio_rig", false) != true:
		errors.append("root ship-audio metadata is missing")
	if not is_in_group(&"ship_audio_rig"):
		errors.append("component is missing its ship_audio_rig discovery group")
	var expected_metadata_profile := _built_profile_id if _has_build_snapshot else profile_id
	if str(get_meta(&"profile_id", &"")) != str(expected_metadata_profile):
		errors.append("root profile metadata does not match the immutable built profile")
	if str(get_meta(&"evidence_status", &"")) != str(EVIDENCE_STATUS):
		errors.append("root evidence_status metadata contradicts the public evidence report")
	if str(get_meta(&"design_origin", &"")) != str(DESIGN_ORIGIN):
		errors.append("root design_origin metadata contradicts the public evidence report")
	if bool(get_meta(&"historically_supported", true)):
		errors.append("root metadata cannot claim historically authenticated ship audio")
	if str(get_meta(&"content_note", "")) != CONTENT_NOTE:
		errors.append("root content_note metadata contradicts the public evidence boundary")


func _append_hierarchy_errors(errors: PackedStringArray) -> void:
	if not _live_player_hierarchy_matches_cache():
		errors.append("live positional voice hierarchy or immutable player identity changed")
	var live_players := find_children("*", "AudioStreamPlayer3D", true, false)
	if live_players.size() != MAXIMUM_SIMULTANEOUS_VOICES:
		errors.append("component must own exactly six bounded AudioStreamPlayer3D voices")
	if not find_children("*", "AudioStreamPlayer", true, false).is_empty():
		errors.append("component must not contain non-positional audio players")
	if not find_children("*", "CollisionObject3D", true, false).is_empty():
		errors.append("audio component must not alter ship collision")
	if not _live_timer_hierarchy_matches_cache():
		errors.append("live cue-expiry timer hierarchy or immutable timer identity changed")
	for voice_id in ALL_VOICE_IDS:
		var player := _players.get(voice_id) as AudioStreamPlayer3D
		if is_instance_valid(player):
			_append_player_errors(voice_id, player, errors)
	for voice_id in TRANSIENT_VOICE_IDS:
		var timer := _cue_expiry_timers.get(voice_id) as Timer
		if not is_instance_valid(timer):
			continue
		if not timer.one_shot or timer.autostart or timer.process_callback != Timer.TIMER_PROCESS_IDLE:
			errors.append("%s cue-expiry timer lost its bounded one-shot lifecycle configuration" % voice_id)
		if not is_finite(timer.wait_time) or timer.wait_time <= 0.0:
			errors.append("%s cue-expiry timer has an invalid timeout" % voice_id)


func _append_configuration_errors(errors: PackedStringArray) -> void:
	if not is_finite(maximum_distance) or maximum_distance < 8.0 or maximum_distance > 300.0:
		errors.append("maximum_distance must be finite and inside the declared 8-300 metre range")
	if not is_finite(reference_distance) or reference_distance < 0.5 or reference_distance > 30.0:
		errors.append("reference_distance must be finite and inside the declared 0.5-30 metre range")
	if is_finite(maximum_distance) and is_finite(reference_distance) and maximum_distance <= reference_distance:
		errors.append("maximum_distance must be greater than reference_distance")
	if _has_build_snapshot:
		if not is_equal_approx(maximum_distance, _built_maximum_distance):
			errors.append("maximum_distance changed after player configuration")
		if not is_equal_approx(reference_distance, _built_reference_distance):
			errors.append("reference_distance changed after player configuration")
	if not is_finite(_throttle) or _throttle < 0.0 or _throttle > 1.0:
		errors.append("runtime throttle escaped its finite normalized range")
	if is_processing() or is_physics_processing():
		errors.append("ship audio rig must remain event-driven with no per-frame callback")


func _append_resource_errors(errors: PackedStringArray) -> void:
	if _resident_sample_bytes > RESIDENT_BYTE_BUDGET:
		errors.append("resident procedural sample data exceeds the strict component budget")
	if _resources_ready:
		if _loop_streams.size() != LOOP_IDS.size() or _cue_streams.size() != CUE_IDS.size():
			errors.append("ready synthesis must retain exactly four loops and eight cues")
		if _resident_sample_bytes != EXPECTED_RESIDENT_SAMPLE_BYTES:
			errors.append("resident sample byte count differs from the bounded declared build")
		var measured_bytes := 0
		for resource_id in LOOP_IDS + CUE_IDS:
			var is_loop := LOOP_IDS.has(resource_id)
			var stream := (
				_loop_streams.get(resource_id) as AudioStreamWAV
				if is_loop
				else _cue_streams.get(resource_id) as AudioStreamWAV
			)
			if stream == null:
				errors.append("ready synthesis is missing the %s template" % resource_id)
				continue
			if int(_resource_instance_ids.get(resource_id, 0)) != stream.get_instance_id():
				errors.append("%s resource identity changed after synthesis" % resource_id)
			if stream.format != AudioStreamWAV.FORMAT_16_BITS or stream.mix_rate != SAMPLE_RATE or stream.stereo:
				errors.append("%s template does not match the declared mono PCM format" % resource_id)
			if is_loop:
				if stream.loop_mode != AudioStreamWAV.LOOP_FORWARD or stream.loop_begin != 0 or stream.loop_end != stream.data.size() / 2:
					errors.append("%s loop lost its complete forward-loop sample bounds" % resource_id)
				if not _loop_seam_is_bounded(stream):
					errors.append("%s loop boundary exceeds its ordinary adjacent-sample step" % resource_id)
			elif stream.loop_mode != AudioStreamWAV.LOOP_DISABLED:
				errors.append("%s cue must remain a bounded one-shot" % resource_id)
			var expected_duration := float(LOOP_DURATIONS[resource_id] if is_loop else CUE_DURATIONS[resource_id])
			var expected_bytes := roundi(expected_duration * SAMPLE_RATE) * 2
			if stream.data.size() != expected_bytes:
				errors.append("%s template byte length changed" % resource_id)
			measured_bytes += stream.data.size()
			var fingerprint := str(_fingerprints.get(resource_id, ""))
			if fingerprint.length() != 64 or fingerprint != _sha256(stream.data):
				errors.append("%s fingerprint does not match its resident template" % resource_id)
		if measured_bytes != _resident_sample_bytes:
			errors.append("resident sample byte report does not match live templates")
	elif (
		not _loop_streams.is_empty()
		or not _cue_streams.is_empty()
		or not _resource_instance_ids.is_empty()
		or not _fingerprints.is_empty()
		or _resident_sample_bytes != 0
	):
		errors.append("released synthesis state retained stale resources or identity metadata")


func _append_lifecycle_errors(errors: PackedStringArray) -> void:
	if rig_enabled and is_inside_tree() and not _tearing_down and not _resources_ready:
		errors.append("enabled in-tree rig must retain its deterministic resources")
	for voice_id in ALL_VOICE_IDS:
		var player := _players.get(voice_id) as AudioStreamPlayer3D
		if is_instance_valid(player) and not _player_stream_matches_lifecycle(voice_id, player):
			errors.append("%s playback state does not match owned resources and runtime state" % voice_id)
	for voice_id in TRANSIENT_VOICE_IDS:
		var timer := _cue_expiry_timers.get(voice_id) as Timer
		if not is_instance_valid(timer):
			continue
		var should_run := (
			_active_cues_by_voice.has(voice_id)
			and rig_enabled
			and is_inside_tree()
			and not _tearing_down
			and _playback_queue_allowed
		)
		if should_run == timer.is_stopped():
			errors.append("%s cue-expiry timer does not match transient ownership" % voice_id)
	if not rig_enabled or not is_inside_tree() or _tearing_down or not _playback_queue_allowed:
		if not _active_cues_by_voice.is_empty():
			errors.append("silent lifecycle state retained active transient ownership")


func _live_player_hierarchy_matches_cache() -> bool:
	if _players.size() != ALL_VOICE_IDS.size() or _player_instance_ids.size() != ALL_VOICE_IDS.size():
		return false
	var live_players := find_children("*", "AudioStreamPlayer3D", true, false)
	if live_players.size() != ALL_VOICE_IDS.size():
		return false
	var live_ids := {}
	for candidate in live_players:
		live_ids[(candidate as AudioStreamPlayer3D).get_instance_id()] = true
	for voice_id in ALL_VOICE_IDS:
		var player := _players.get(voice_id) as AudioStreamPlayer3D
		if (
			not is_instance_valid(player)
			or get_node_or_null(VOICE_PATHS[voice_id]) != player
			or not is_ancestor_of(player)
			or int(_player_instance_ids.get(voice_id, 0)) != player.get_instance_id()
			or not live_ids.has(player.get_instance_id())
		):
			return false
	return true


func _live_timer_hierarchy_matches_cache() -> bool:
	if _cue_expiry_timers.size() != TRANSIENT_VOICE_IDS.size() or _timer_instance_ids.size() != TRANSIENT_VOICE_IDS.size():
		return false
	var live_timers := find_children("*", "Timer", true, false)
	if live_timers.size() != TRANSIENT_VOICE_IDS.size():
		return false
	var live_ids := {}
	for candidate in live_timers:
		live_ids[(candidate as Timer).get_instance_id()] = true
	for voice_id in TRANSIENT_VOICE_IDS:
		var timer := _cue_expiry_timers.get(voice_id) as Timer
		if (
			not is_instance_valid(timer)
			or get_node_or_null(CUE_TIMER_PATHS[voice_id]) != timer
			or not is_ancestor_of(timer)
			or int(_timer_instance_ids.get(voice_id, 0)) != timer.get_instance_id()
			or not live_ids.has(timer.get_instance_id())
		):
			return false
	return true


func _append_player_errors(
	voice_id: StringName,
	player: AudioStreamPlayer3D,
	errors: PackedStringArray
	) -> void:
	if player.bus != VOICE_BUSES[voice_id]:
		errors.append("%s must route through the declared %s bus" % [voice_id, VOICE_BUSES[voice_id]])
	if AudioServer.get_bus_index(VOICE_BUSES[voice_id]) < 0:
		errors.append("%s declared bus does not exist in the active AudioServer layout" % voice_id)
	if player.attenuation_model != AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE:
		errors.append("%s must use inverse-distance attenuation" % voice_id)
	var expected_maximum_distance := _built_maximum_distance if _has_build_snapshot else _safe_maximum_distance()
	var expected_reference_distance := _built_reference_distance if _has_build_snapshot else _safe_reference_distance()
	if not is_equal_approx(player.max_distance, expected_maximum_distance) or not is_finite(player.max_distance):
		errors.append("%s maximum distance changed or became non-finite" % voice_id)
	if not is_equal_approx(player.unit_size, expected_reference_distance) or not is_finite(player.unit_size):
		errors.append("%s reference distance changed or became non-finite" % voice_id)
	if player.max_polyphony != 1:
		errors.append("%s must remain bounded to one voice" % voice_id)
	if player.autoplay or player.area_mask != 0:
		errors.append("%s must remain under direct lifecycle and bus control" % voice_id)
	if player.doppler_tracking != AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED:
		errors.append("%s must not apply a second pitch model through Doppler tracking" % voice_id)
	if player.emission_angle_enabled or not is_equal_approx(player.panning_strength, 1.0):
		errors.append("%s must remain an omnidirectional positional source" % voice_id)
	if not is_equal_approx(player.max_db, -2.0):
		errors.append("%s maximum output level changed" % voice_id)
	if not player.position.is_equal_approx(Vector3.ZERO):
		errors.append("%s moved away from the ship-local acoustic origin" % voice_id)
	if not is_equal_approx(player.attenuation_filter_cutoff_hz, ATTENUATION_FILTER_CUTOFF_HZ) or not is_equal_approx(player.attenuation_filter_db, ATTENUATION_FILTER_DB):
		errors.append("%s attenuation filter changed" % voice_id)
	if player.stream_paused:
		errors.append("%s cannot claim active playback while paused" % voice_id)
	var expected_volume := float(_expected_volumes.get(voice_id, player.volume_db))
	var expected_pitch := float(_expected_pitches.get(voice_id, player.pitch_scale))
	if not is_finite(player.volume_db) or not is_equal_approx(player.volume_db, expected_volume):
		errors.append("%s volume differs from the current profile/state mix" % voice_id)
	if not is_finite(player.pitch_scale) or not is_equal_approx(player.pitch_scale, expected_pitch):
		errors.append("%s pitch differs from the current profile/state mix" % voice_id)


func _player_stream_matches_lifecycle(voice_id: StringName, player: AudioStreamPlayer3D) -> bool:
	if LOOP_VOICE_IDS.has(voice_id):
		var loop_id := LOOP_TO_VOICE.find_key(voice_id) as StringName
		var owned_stream := _loop_streams.get(loop_id) as AudioStreamWAV
		var should_play := (
			rig_enabled
			and is_inside_tree()
			and not _tearing_down
			and _playback_queue_allowed
			and _resources_ready
			and _is_loop_desired(loop_id)
		)
		if should_play:
			return player.stream == owned_stream and player.playing
		return player.stream == null and not player.playing
	if TRANSIENT_VOICE_IDS.has(voice_id):
		if player.stream == null:
			return not player.playing and not _active_cues_by_voice.has(voice_id)
		if not _active_cues_by_voice.has(voice_id):
			return false
		var cue_id := _active_cues_by_voice[voice_id] as StringName
		return (
			CUE_TO_VOICE.get(cue_id, &"") == voice_id
			and player.stream == _cue_streams.get(cue_id)
			and player.playing
			and rig_enabled
			and is_inside_tree()
			and not _tearing_down
			and _playback_queue_allowed
		)
	return false


func _apply_metadata() -> void:
	set_meta(&"ship_audio_rig", true)
	set_meta(&"profile_id", _built_profile_id)
	set_meta(&"evidence_status", EVIDENCE_STATUS)
	set_meta(&"design_origin", DESIGN_ORIGIN)
	set_meta(&"historically_supported", false)
	set_meta(&"content_note", CONTENT_NOTE)


func _emit_state_changed() -> void:
	# Production currently polls state only on demand. Avoid allocating the deep
	# snapshot dictionaries and packed arrays on every throttle change when no
	# observer is connected; tests/tools that subscribe retain the full contract.
	if not get_signal_connection_list(&"state_changed").is_empty():
		state_changed.emit(get_state_snapshot())
