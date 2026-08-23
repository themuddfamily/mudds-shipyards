class_name StationMachineryAmbience
extends Node3D

signal semantic_maintenance_cue_emitted(cue_id: StringName, intensity: float)

## Reusable positional station machinery bed with one bounded transient voice.
##
## Every sample is synthesized by this project from deterministic oscillator
## layers. The component carries no recovered recording and makes no claim about
## the historical shipyard's sound. Place the root at a compact solid station
## node; its global position is the omnidirectional acoustic origin.

const SCHEMA_VERSION := 1
const COMPONENT_ID: StringName = &"station-machinery-ambience"
const EVIDENCE_STATUS: StringName = &"modern_interpretation"
const DESIGN_ORIGIN: StringName = &"project_original_procedural_audio"
const AUDIO_BUS: StringName = &"Ambience"
const SAMPLE_RATE := 16000
const LOOP_DURATION_SECONDS := 2.0
const SERVO_DURATION_SECONDS := 0.42
const LATCH_DURATION_SECONDS := 0.20
const LOOP_VOICE_COUNT := 1
const TRANSIENT_VOICE_COUNT := 1
const MAXIMUM_SIMULTANEOUS_VOICES := LOOP_VOICE_COUNT + TRANSIENT_VOICE_COUNT
const RESIDENT_BYTE_BUDGET := 131072
const ATTENUATION_FILTER_CUTOFF_HZ := 5000.0
const ATTENUATION_FILTER_DB := -24.0
const CUE_SERVO: StringName = &"servo"
const CUE_LATCH: StringName = &"latch"
const CONTENT_NOTE := (
	"The machinery hum, servo sweep, latch cue, spatial range, and placement are "
	+ "project-original modern sound design. No surviving source authenticates the "
	+ "original station's ambience or machinery recordings."
)

@export_category("Identity")
@export var emitter_id: StringName = &"station-machinery"
@export_range(1, 2147483647, 1) var synthesis_seed := 26032011

@export_category("Synthesis")
@export_range(24.0, 90.0, 0.5) var base_frequency_hz := 46.0

@export_category("Spatial mix")
@export_range(4.0, 120.0, 1.0) var maximum_distance := 32.0
@export_range(0.5, 20.0, 0.25) var reference_distance := 4.0
@export_range(-40.0, 0.0, 0.5) var loop_volume_db := -17.0
@export_range(-40.0, 0.0, 0.5) var cue_volume_db := -10.0
@export var ambience_enabled := true

var _loop_player: AudioStreamPlayer3D
var _cue_player: AudioStreamPlayer3D
var _loop_stream: AudioStreamWAV
var _cue_streams: Dictionary = {}
var _fingerprints: Dictionary = {}
var _resident_sample_bytes := 0
var _synthesis_generation_count := 0
var _resources_ready := false
var _audio_available := false
var _tearing_down := false
var _initialized := false
var _has_synthesis_build_snapshot := false
var _built_synthesis_seed := 0
var _built_base_frequency_hz := 0.0
var _has_player_configuration_snapshot := false
var _built_maximum_distance := 0.0
var _built_reference_distance := 0.0
var _built_loop_volume_db := 0.0
var _built_cue_volume_db := 0.0
var _expected_cue_volume_db := 0.0
var _caller_distance := 0.0
var _room_exposure := 0.0


func _enter_tree() -> void:
	# A detached component may be re-added without `_ready` running again. Rebuild
	# from its retained desired state, then defer playback until both child voices
	# have re-entered the tree.
	_tearing_down = false
	if is_instance_valid(_loop_player) and is_instance_valid(_cue_player):
		_audio_available = AudioServer.get_driver_name() != "Dummy"
		_configure_players()
		if ambience_enabled:
			_ensure_synthesized()
		call_deferred("_restore_after_enter_tree")


func _ready() -> void:
	_tearing_down = false
	_loop_player = get_node_or_null(^"MachineryLoop") as AudioStreamPlayer3D
	_cue_player = get_node_or_null(^"CueVoice") as AudioStreamPlayer3D
	_audio_available = AudioServer.get_driver_name() != "Dummy"
	_configure_players()
	if is_instance_valid(_cue_player) and not _cue_player.finished.is_connected(_on_cue_finished):
		_cue_player.finished.connect(_on_cue_finished)
	_set_evidence_metadata()
	add_to_group(&"station_machinery_ambience")
	_ensure_synthesized()
	_apply_enabled_state()
	_initialized = true


func _exit_tree() -> void:
	_tearing_down = true
	_discard_audio_resources(true)


func get_component_id() -> StringName:
	return COMPONENT_ID


func get_emitter_id() -> StringName:
	return emitter_id


## Reversibly starts or silences this emitter. Disabling stops both voices and
## detaches their streams, while retaining the small deterministic templates for
## a cheap restart. The Dummy driver never receives a playback request.
func set_ambience_enabled(enabled: bool) -> void:
	# A fresh scene may receive authored/pre-tree configuration. Once this emitter
	# has completed a live lifecycle, a detached or queued caller must not rewrite
	# the retained desired state that its next entry will restore.
	if _initialized and (_tearing_down or is_queued_for_deletion() or not is_inside_tree()):
		return
	var changed := ambience_enabled != enabled
	ambience_enabled = enabled
	if changed:
		semantic_maintenance_cue_emitted.emit(
			&"station_machinery_available" if enabled else &"station_machinery_offline",
			1.0 if enabled else 0.0
		)
	if not is_inside_tree():
		return
	_apply_enabled_state()


func is_ambience_enabled() -> bool:
	return ambience_enabled


## Caller-owned normalized distance and room exposure. Zero distance is near;
## one is at the authored range edge. Exposure zero is fully occluded.
func set_room_mix(distance: float, exposure: float) -> bool:
	if not is_finite(distance) or not is_finite(exposure) \
			or distance < 0.0 or distance > 1.0 or exposure < 0.0 or exposure > 1.0:
		return false
	_caller_distance = distance
	_room_exposure = exposure
	_apply_room_mix()
	return true


func get_room_mix_snapshot() -> Dictionary:
	return {
		"caller_distance": _caller_distance,
		"room_exposure": _room_exposure,
		"presentation_only": true,
	}.duplicate(true)


## Plays one bounded machinery cue through the component's single transient
## voice. A new cue deliberately replaces an older one. Returns true only when a
## real audio driver accepted playback; deterministic/headless calls return false.
func play_cue(cue_id: StringName = CUE_SERVO, intensity: float = 1.0) -> bool:
	if (
		_tearing_down
		or not ambience_enabled
		or not _audio_available
		or not is_inside_tree()
		or is_queued_for_deletion()
		or not is_instance_valid(_cue_player)
		or not is_finite(intensity)
		or intensity <= 0.0
	):
		return false
	_ensure_synthesized()
	var stream := _cue_streams.get(cue_id) as AudioStreamWAV
	if stream == null:
		return false
	var safe_intensity := clampf(intensity, 0.1, 1.5)
	_stop_and_detach(_cue_player)
	var built_cue_volume := _built_cue_volume_db if _has_player_configuration_snapshot else cue_volume_db
	var requested_cue_volume_db := built_cue_volume + linear_to_db(safe_intensity)
	_cue_player.volume_db = requested_cue_volume_db
	_cue_player.stream = stream
	_cue_player.play()
	if not _request_cue_playback(_cue_player):
		_stop_and_detach(_cue_player)
		return false
	_expected_cue_volume_db = requested_cue_volume_db
	_apply_room_mix()
	semantic_maintenance_cue_emitted.emit(
		&"station_service_servo" if cue_id == CUE_SERVO else &"station_service_latch",
		safe_intensity
	)
	return true


func _request_cue_playback(player: AudioStreamPlayer3D) -> bool:
	return player.playing


func get_supported_cues() -> PackedStringArray:
	return PackedStringArray([str(CUE_SERVO), str(CUE_LATCH)])


## Deep cleanup hook for streamed-scene unloads and test teardown. It is safe and
## idempotent. Re-enabling later regenerates byte-identical resources from the
## configured seed and frequency.
func release_audio_resources() -> void:
	ambience_enabled = false
	_discard_audio_resources()


func _discard_audio_resources(preserve_build_configuration: bool = false) -> void:
	_stop_and_detach(_loop_player)
	_stop_and_detach(_cue_player)
	_loop_stream = null
	_cue_streams.clear()
	_fingerprints.clear()
	_resident_sample_bytes = 0
	_resources_ready = false
	if not preserve_build_configuration:
		_has_synthesis_build_snapshot = false
		_built_synthesis_seed = 0
		_built_base_frequency_hz = 0.0


func get_evidence_metadata() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"evidence_status": EVIDENCE_STATUS,
		"design_origin": DESIGN_ORIGIN,
		"historically_supported": false,
		"content_note": CONTENT_NOTE,
		"modern_interpretations": PackedStringArray([
			"layered station machinery loop",
			"servo and latch cue timbres",
			"positional attenuation and audible range",
			"emitter placement and mix levels",
		]),
	}


func get_spatial_contract() -> Dictionary:
	var requested_configuration := {
		"maximum_distance": _safe_maximum_distance(),
		"reference_distance": _safe_reference_distance(),
		"loop_volume_db": loop_volume_db,
		"cue_volume_db": cue_volume_db,
	}
	var built_configuration := requested_configuration.duplicate(true)
	if _has_player_configuration_snapshot:
		built_configuration = {
			"maximum_distance": _built_maximum_distance,
			"reference_distance": _built_reference_distance,
			"loop_volume_db": _built_loop_volume_db,
			"cue_volume_db": _built_cue_volume_db,
		}
	var configuration_matches_players := _spatial_configuration_matches_players()
	return {
		"schema_version": SCHEMA_VERSION,
		"origin": &"component_global_position",
		"orientation": &"omnidirectional_rotation_independent",
		"bus": AUDIO_BUS,
		"attenuation_model": &"inverse_distance",
		"maximum_distance": float(built_configuration.maximum_distance),
		"reference_distance": float(built_configuration.reference_distance),
		"loop_volume_db": float(built_configuration.loop_volume_db),
		"cue_volume_db": float(built_configuration.cue_volume_db),
		"current_cue_volume_db": _expected_cue_volume_db,
		"panning_strength": 1.0,
		"doppler_tracking": &"disabled",
		"built_configuration_available": _has_player_configuration_snapshot,
		"configuration_matches_players": configuration_matches_players,
		"configuration_current": configuration_matches_players,
		"requested_configuration": requested_configuration,
		"built_configuration": built_configuration if _has_player_configuration_snapshot else {},
	}


func get_synthesis_report() -> Dictionary:
	var requested_seed := synthesis_seed
	var requested_base_frequency := _safe_base_frequency()
	var reported_seed := _built_synthesis_seed if _has_synthesis_build_snapshot else requested_seed
	var reported_base_frequency := (
		_built_base_frequency_hz if _has_synthesis_build_snapshot else requested_base_frequency
	)
	var configuration_matches_resources := _synthesis_configuration_matches_resources()
	return {
		"schema_version": SCHEMA_VERSION,
		"sample_rate": SAMPLE_RATE,
		"channel_count": 1,
		"sample_format": &"signed_pcm_16_bit",
		"loop_duration_seconds": LOOP_DURATION_SECONDS,
		"loop_mode": &"forward",
		"cue_count": 2,
		"seed": reported_seed,
		"base_frequency_hz": reported_base_frequency,
		"requested_seed": requested_seed,
		"requested_base_frequency_hz": requested_base_frequency,
		"built_configuration_available": _has_synthesis_build_snapshot,
		"configuration_matches_resources": configuration_matches_resources,
		"configuration_current": configuration_matches_resources,
		"requested_configuration": {
			"seed": requested_seed,
			"base_frequency_hz": requested_base_frequency,
		},
		"built_configuration": {
			"seed": _built_synthesis_seed,
			"base_frequency_hz": _built_base_frequency_hz,
		} if _has_synthesis_build_snapshot else {},
		"resources_ready": _resources_ready,
		"resident_sample_bytes": _resident_sample_bytes,
		"fingerprints_sha256": _fingerprints.duplicate(true),
		"generation_count": _synthesis_generation_count,
	}


func get_performance_report() -> Dictionary:
	var live_player_count := find_children("*", "AudioStreamPlayer3D", true, false).size()
	return {
		"schema_version": SCHEMA_VERSION,
		"audio_player_count": live_player_count,
		"loop_voice_count": LOOP_VOICE_COUNT,
		"transient_voice_count": TRANSIENT_VOICE_COUNT,
		"maximum_simultaneous_voices": MAXIMUM_SIMULTANEOUS_VOICES,
		"per_frame_script_processing": false,
		"resident_sample_bytes": _resident_sample_bytes,
		"resident_byte_budget": RESIDENT_BYTE_BUDGET,
		"within_resident_budget": _resident_sample_bytes <= RESIDENT_BYTE_BUDGET,
		"audio_driver": AudioServer.get_driver_name(),
		"playback_available": _audio_available,
	}


func get_audit_report() -> Dictionary:
	var errors := PackedStringArray()
	if emitter_id.is_empty():
		errors.append("emitter_id must not be empty")
	if not is_instance_valid(_loop_player) or not is_instance_valid(_cue_player):
		errors.append("scene must contain MachineryLoop and CueVoice AudioStreamPlayer3D nodes")
	if not _live_player_hierarchy_matches_cache():
		errors.append("live positional voice hierarchy must match the two cached component voices exactly")
	if is_instance_valid(_loop_player):
		_append_player_errors(_loop_player, &"MachineryLoop", errors)
	if is_instance_valid(_cue_player):
		_append_player_errors(_cue_player, &"CueVoice", errors)
	if ambience_enabled and is_inside_tree() and not _tearing_down and not _resources_ready:
		errors.append("enabled emitter must retain its deterministic synthesis templates")
	if _resident_sample_bytes > RESIDENT_BYTE_BUDGET:
		errors.append("resident procedural sample data exceeds the component budget")
	if _resources_ready:
		if not _has_synthesis_build_snapshot:
			errors.append("synthesized resources are missing their immutable build configuration")
		else:
			if synthesis_seed != _built_synthesis_seed:
				errors.append("synthesis seed changed after the current resources were built")
			if not is_equal_approx(_safe_base_frequency(), _built_base_frequency_hz):
				errors.append("base frequency changed after the current resources were built")
		_append_resource_errors(errors)
	elif (
		_loop_stream != null
		or not _cue_streams.is_empty()
		or not _fingerprints.is_empty()
		or _resident_sample_bytes != 0
	):
		errors.append("released synthesis state must not retain stale resources or build metadata")
	if not _resources_ready and _has_synthesis_build_snapshot and is_inside_tree() and ambience_enabled and not _tearing_down:
		errors.append("enabled in-tree emitter cannot retain only a build snapshot without resources")
	if _has_player_configuration_snapshot:
		if not is_equal_approx(_safe_maximum_distance(), _built_maximum_distance):
			errors.append("maximum distance changed after the audio players were configured")
		if not is_equal_approx(_safe_reference_distance(), _built_reference_distance):
			errors.append("reference distance changed after the audio players were configured")
		if not is_equal_approx(loop_volume_db, _built_loop_volume_db):
			errors.append("loop volume changed after the audio players were configured")
		if not is_equal_approx(cue_volume_db, _built_cue_volume_db):
			errors.append("cue volume changed after the audio players were configured")
	var players := find_children("*", "AudioStreamPlayer3D", true, false)
	var live_player_ids := {}
	for candidate in players:
		live_player_ids[(candidate as AudioStreamPlayer3D).get_instance_id()] = true
	var expected_player_ids := {}
	if is_instance_valid(_loop_player):
		expected_player_ids[_loop_player.get_instance_id()] = true
	if is_instance_valid(_cue_player):
		expected_player_ids[_cue_player.get_instance_id()] = true
	if players.size() != MAXIMUM_SIMULTANEOUS_VOICES or live_player_ids != expected_player_ids:
		errors.append("component must own exactly two bounded 3D audio voices")
	if not find_children("*", "CollisionObject3D", true, false).is_empty():
		errors.append("audio component must not alter station collision")
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"component_id": COMPONENT_ID,
		"emitter_id": emitter_id,
		"evidence": get_evidence_metadata(),
		"spatial": get_spatial_contract(),
		"synthesis": get_synthesis_report(),
		"performance": get_performance_report(),
		"enabled": ambience_enabled,
		"loop_playing": is_instance_valid(_loop_player) and _loop_player.playing,
		"cue_playing": is_instance_valid(_cue_player) and _cue_player.playing,
		"caller_distance": _caller_distance,
		"room_exposure": _room_exposure,
	}


func _apply_enabled_state() -> void:
	if not ambience_enabled or _tearing_down:
		_stop_and_detach(_loop_player)
		_stop_and_detach(_cue_player)
		return
	_ensure_synthesized()
	if not _audio_available or not is_instance_valid(_loop_player) or _loop_stream == null:
		return
	if _loop_player.stream != _loop_stream:
		_stop_and_detach(_loop_player)
		_loop_player.stream = _loop_stream
	if not _loop_player.playing:
		_loop_player.play()
	_apply_room_mix()


func _apply_room_mix() -> void:
	if not is_instance_valid(_loop_player) or not is_instance_valid(_cue_player):
		return
	var distance_db := lerpf(0.0, -12.0, _caller_distance)
	var occlusion_db := lerpf(-18.0, 0.0, _room_exposure)
	var loop_base := _built_loop_volume_db if _has_player_configuration_snapshot else loop_volume_db
	var cue_base := _built_cue_volume_db if _has_player_configuration_snapshot else cue_volume_db
	_loop_player.volume_db = loop_base + distance_db + occlusion_db
	if _cue_player.playing:
		_cue_player.volume_db = _expected_cue_volume_db + distance_db + occlusion_db


func _restore_after_enter_tree() -> void:
	if _tearing_down or is_queued_for_deletion() or not is_inside_tree():
		return
	_apply_enabled_state()


func _configure_players() -> void:
	var taking_initial_snapshot := not _has_player_configuration_snapshot
	var built_maximum_distance := (
		_safe_maximum_distance() if taking_initial_snapshot else _built_maximum_distance
	)
	var built_reference_distance := (
		_safe_reference_distance() if taking_initial_snapshot else _built_reference_distance
	)
	var built_loop_volume := loop_volume_db if taking_initial_snapshot else _built_loop_volume_db
	var built_cue_volume := cue_volume_db if taking_initial_snapshot else _built_cue_volume_db
	_configure_player(_loop_player, built_loop_volume, built_maximum_distance, built_reference_distance)
	_configure_player(_cue_player, built_cue_volume, built_maximum_distance, built_reference_distance)
	if taking_initial_snapshot and is_instance_valid(_loop_player) and is_instance_valid(_cue_player):
		_built_maximum_distance = built_maximum_distance
		_built_reference_distance = built_reference_distance
		_built_loop_volume_db = built_loop_volume
		_built_cue_volume_db = built_cue_volume
		_has_player_configuration_snapshot = true
	_expected_cue_volume_db = built_cue_volume


func _configure_player(
		player: AudioStreamPlayer3D,
		authored_volume_db: float,
		built_maximum_distance: float,
		built_reference_distance: float
	) -> void:
	if not is_instance_valid(player):
		return
	player.autoplay = false
	player.bus = AUDIO_BUS
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	player.max_distance = built_maximum_distance
	player.unit_size = built_reference_distance
	player.max_db = -3.0
	player.panning_strength = 1.0
	player.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
	player.emission_angle_enabled = false
	player.area_mask = 0
	player.max_polyphony = 1
	player.volume_db = authored_volume_db
	player.pitch_scale = 1.0
	player.position = Vector3.ZERO
	player.attenuation_filter_cutoff_hz = ATTENUATION_FILTER_CUTOFF_HZ
	player.attenuation_filter_db = ATTENUATION_FILTER_DB
	player.stream_paused = false


func _stop_and_detach(player_value: Variant) -> void:
	if not is_instance_valid(player_value) or not player_value is AudioStreamPlayer3D:
		return
	var player := player_value as AudioStreamPlayer3D
	player.stop()
	player.stream_paused = false
	player.stream = null
	if player == _cue_player:
		_expected_cue_volume_db = (
			_built_cue_volume_db if _has_player_configuration_snapshot else cue_volume_db
		)
		player.volume_db = _expected_cue_volume_db


func _on_cue_finished() -> void:
	# A completed one-shot must not pin its generated waveform until the next cue
	# or teardown. The cached template remains available for a zero-allocation replay.
	if not _tearing_down and is_instance_valid(_cue_player) and not _cue_player.playing:
		_expected_cue_volume_db = (
			_built_cue_volume_db if _has_player_configuration_snapshot else cue_volume_db
		)
		_cue_player.volume_db = _expected_cue_volume_db
		_cue_player.stream = null


func _ensure_synthesized() -> void:
	if _resources_ready:
		return
	var built_seed := _built_synthesis_seed if _has_synthesis_build_snapshot else synthesis_seed
	var built_base_frequency := (
		_built_base_frequency_hz if _has_synthesis_build_snapshot else _safe_base_frequency()
	)
	var loop_bytes := _synthesize_loop(built_seed, built_base_frequency)
	var servo_bytes := _synthesize_servo(built_seed)
	var latch_bytes := _synthesize_latch(built_seed)
	_loop_stream = _wave_from_bytes(loop_bytes, true)
	_cue_streams = {
		CUE_SERVO: _wave_from_bytes(servo_bytes, false),
		CUE_LATCH: _wave_from_bytes(latch_bytes, false),
	}
	_fingerprints = {
		&"loop": _sha256(loop_bytes),
		CUE_SERVO: _sha256(servo_bytes),
		CUE_LATCH: _sha256(latch_bytes),
	}
	_resident_sample_bytes = loop_bytes.size() + servo_bytes.size() + latch_bytes.size()
	_built_synthesis_seed = built_seed
	_built_base_frequency_hz = built_base_frequency
	_has_synthesis_build_snapshot = true
	_synthesis_generation_count += 1
	_resources_ready = true


func _synthesize_loop(built_seed: int, built_base_frequency: float) -> PackedByteArray:
	var sample_count := roundi(LOOP_DURATION_SECONDS * SAMPLE_RATE)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	var base := built_base_frequency
	var sub_motor_frequency := roundf((base * 0.5 + 7.0) * 2.0) * 0.5
	var phase_a := _seed_phase(built_seed, 17)
	var phase_b := _seed_phase(built_seed, 53)
	var phase_c := _seed_phase(built_seed, 97)
	for index in sample_count:
		var time := float(index) / float(SAMPLE_RATE)
		var machinery_pulse := 0.88 + 0.12 * sin(TAU * 1.0 * time + phase_c)
		var low_layer := (
			sin(TAU * base * time) * 0.54
			+ sin(TAU * base * 2.0 * time + phase_a) * 0.20
			+ sin(TAU * base * 3.0 * time + phase_b) * 0.07
		)
		var motor_layer := (
			sin(TAU * (base + 13.0) * time + phase_b) * 0.11
			+ sin(TAU * sub_motor_frequency * time + phase_c) * 0.08
		)
		var ventilation_texture := (
			sin(TAU * 173.0 * time + phase_a) * 0.036
			+ sin(TAU * 239.0 * time + phase_b) * 0.025
			+ sin(TAU * 307.0 * time + phase_c) * 0.018
		)
		var sample := clampf(
			(low_layer * 0.23 + motor_layer * machinery_pulse + ventilation_texture) * 0.72,
			-1.0,
			1.0
		)
		bytes.encode_s16(index * 2, roundi(sample * 32767.0))
	return bytes


func _synthesize_servo(built_seed: int) -> PackedByteArray:
	var sample_count := roundi(SERVO_DURATION_SECONDS * SAMPLE_RATE)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	var phase := _seed_phase(built_seed, 131)
	for index in sample_count:
		var time := float(index) / float(SAMPLE_RATE)
		var progress := float(index) / float(maxi(sample_count - 1, 1))
		var envelope := pow(sin(PI * progress), 1.35)
		var swept_phase := TAU * (108.0 * time + 0.5 * 310.0 * time * time) + phase
		var drive := sin(swept_phase) * 0.62 + sin(swept_phase * 2.0 + 0.4) * 0.16
		var sample := clampf(drive * envelope * 0.42, -1.0, 1.0)
		bytes.encode_s16(index * 2, roundi(sample * 32767.0))
	return bytes


func _synthesize_latch(built_seed: int) -> PackedByteArray:
	var sample_count := roundi(LATCH_DURATION_SECONDS * SAMPLE_RATE)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	var phase := _seed_phase(built_seed, 211)
	for index in sample_count:
		var time := float(index) / float(SAMPLE_RATE)
		var progress := float(index) / float(maxi(sample_count - 1, 1))
		var attack := minf(progress / 0.035, 1.0)
		var envelope := attack * exp(-7.5 * progress)
		var body := sin(TAU * 71.0 * time + phase) * 0.72 + sin(TAU * 142.0 * time) * 0.19
		var transient := sin(TAU * 977.0 * time + phase * 0.5) * exp(-30.0 * progress) * 0.12
		var sample := clampf((body * envelope + transient) * 0.58, -1.0, 1.0)
		bytes.encode_s16(index * 2, roundi(sample * 32767.0))
	return bytes


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


func _safe_base_frequency() -> float:
	var candidate := base_frequency_hz if is_finite(base_frequency_hz) else 46.0
	return roundf(clampf(candidate, 24.0, 90.0) * 2.0) * 0.5


func _safe_maximum_distance() -> float:
	return clampf(maximum_distance, 1.0, 120.0) if is_finite(maximum_distance) else 32.0


func _safe_reference_distance() -> float:
	return clampf(reference_distance, 0.1, 20.0) if is_finite(reference_distance) else 4.0


func _seed_phase(built_seed: int, salt: int) -> float:
	var phase_degrees := posmod(built_seed * 104729 + salt * 7919, 3600)
	return TAU * float(phase_degrees) / 3600.0


func _synthesis_configuration_matches_resources() -> bool:
	if not _resources_ready:
		return (
			not _has_synthesis_build_snapshot
			or (
				synthesis_seed == _built_synthesis_seed
				and is_equal_approx(_safe_base_frequency(), _built_base_frequency_hz)
			)
		)
	return (
		_has_synthesis_build_snapshot
		and synthesis_seed == _built_synthesis_seed
		and is_equal_approx(_safe_base_frequency(), _built_base_frequency_hz)
	)


func _spatial_configuration_matches_players() -> bool:
	if (
		not _has_player_configuration_snapshot
		or not _live_player_hierarchy_matches_cache()
	):
		return false
	if (
		not is_equal_approx(_safe_maximum_distance(), _built_maximum_distance)
		or not is_equal_approx(_safe_reference_distance(), _built_reference_distance)
		or not is_equal_approx(loop_volume_db, _built_loop_volume_db)
		or not is_equal_approx(cue_volume_db, _built_cue_volume_db)
	):
		return false
	return (
		_player_matches_spatial_contract(_loop_player, _built_loop_volume_db)
		and _player_matches_spatial_contract(_cue_player, _expected_cue_volume_db)
	)


func _player_matches_spatial_contract(
	player: AudioStreamPlayer3D,
	expected_volume_db: float
) -> bool:
	return (
		player.bus == AUDIO_BUS
		and player.attenuation_model == AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		and is_equal_approx(player.max_distance, _built_maximum_distance)
		and is_equal_approx(player.unit_size, _built_reference_distance)
		and is_equal_approx(player.max_db, -3.0)
		and is_equal_approx(player.panning_strength, 1.0)
		and player.doppler_tracking == AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		and not player.emission_angle_enabled
		and player.area_mask == 0
		and player.max_polyphony == 1
		and not player.autoplay
		and is_equal_approx(player.volume_db, expected_volume_db)
		and is_equal_approx(player.pitch_scale, 1.0)
		and player.position.is_equal_approx(Vector3.ZERO)
		and is_equal_approx(player.attenuation_filter_cutoff_hz, ATTENUATION_FILTER_CUTOFF_HZ)
		and is_equal_approx(player.attenuation_filter_db, ATTENUATION_FILTER_DB)
		and not player.stream_paused
		and _player_stream_matches_lifecycle(player)
	)


func _live_player_hierarchy_matches_cache() -> bool:
	if not is_instance_valid(_loop_player) or not is_instance_valid(_cue_player):
		return false
	if (
		get_node_or_null(^"MachineryLoop") != _loop_player
		or get_node_or_null(^"CueVoice") != _cue_player
		or not is_ancestor_of(_loop_player)
		or not is_ancestor_of(_cue_player)
	):
		return false
	var live_players := find_children("*", "AudioStreamPlayer3D", true, false)
	if live_players.size() != MAXIMUM_SIMULTANEOUS_VOICES:
		return false
	var live_ids := {}
	for player_value in live_players:
		live_ids[(player_value as AudioStreamPlayer3D).get_instance_id()] = true
	return (
		live_ids.size() == 2
		and live_ids.has(_loop_player.get_instance_id())
		and live_ids.has(_cue_player.get_instance_id())
	)


func _player_stream_matches_lifecycle(player: AudioStreamPlayer3D) -> bool:
	if player == _loop_player:
		if player.stream != null and player.stream != _loop_stream:
			return false
		if ambience_enabled and is_inside_tree() and not _tearing_down and _audio_available:
			return _resources_ready and player.stream == _loop_stream and player.playing
		return player.stream == null and not player.playing
	if player == _cue_player:
		if player.stream == null:
			return not player.playing
		var owns_stream := false
		for candidate in _cue_streams.values():
			if player.stream == candidate:
				owns_stream = true
				break
		return (
			owns_stream
			and ambience_enabled
			and is_inside_tree()
			and not _tearing_down
			and _audio_available
			and player.playing
		)
	return false


func _append_resource_errors(errors: PackedStringArray) -> void:
	var streams := {
		&"loop": _loop_stream,
		CUE_SERVO: _cue_streams.get(CUE_SERVO) as AudioStreamWAV,
		CUE_LATCH: _cue_streams.get(CUE_LATCH) as AudioStreamWAV,
	}
	if _cue_streams.size() != 2:
		errors.append("ready synthesis must contain exactly the servo and latch templates")
	var measured_resident_bytes := 0
	for resource_id: StringName in [&"loop", CUE_SERVO, CUE_LATCH]:
		var stream := streams.get(resource_id) as AudioStreamWAV
		if stream == null:
			errors.append("ready synthesis is missing its %s template" % resource_id)
			continue
		if (
			stream.format != AudioStreamWAV.FORMAT_16_BITS
			or stream.mix_rate != SAMPLE_RATE
			or stream.stereo
		):
			errors.append("%s template does not match the declared PCM format" % resource_id)
		if resource_id == &"loop" and stream.loop_mode != AudioStreamWAV.LOOP_FORWARD:
			errors.append("loop template must retain forward looping")
		if resource_id == &"loop" and (
			stream.loop_begin != 0 or stream.loop_end != stream.data.size() / 2
		):
			errors.append("loop template must retain its complete deterministic sample bounds")
		if resource_id != &"loop" and stream.loop_mode != AudioStreamWAV.LOOP_DISABLED:
			errors.append("%s cue template must remain a bounded one-shot" % resource_id)
		var sample_bytes := stream.data
		measured_resident_bytes += sample_bytes.size()
		var fingerprint := str(_fingerprints.get(resource_id, ""))
		if fingerprint.length() != 64:
			errors.append("%s synthesis fingerprint is missing" % resource_id)
		elif fingerprint != _sha256(sample_bytes):
			errors.append("%s synthesis fingerprint does not match its resident template" % resource_id)
	if measured_resident_bytes != _resident_sample_bytes:
		errors.append("resident sample byte report does not match the built templates")


func _sha256(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	if context.update(bytes) != OK:
		return ""
	return context.finish().hex_encode()


func _append_player_errors(
		player: AudioStreamPlayer3D,
		player_name: StringName,
		errors: PackedStringArray
	) -> void:
	if player.bus != AUDIO_BUS:
		errors.append("%s must route through the Ambience bus" % player_name)
	if player.attenuation_model != AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE:
		errors.append("%s must use inverse-distance attenuation" % player_name)
	var expected_maximum_distance := (
		_built_maximum_distance if _has_player_configuration_snapshot else _safe_maximum_distance()
	)
	var expected_reference_distance := (
		_built_reference_distance if _has_player_configuration_snapshot else _safe_reference_distance()
	)
	var expected_volume_db := (
		(_built_loop_volume_db if player_name == &"MachineryLoop" else _expected_cue_volume_db)
		if _has_player_configuration_snapshot
		else (loop_volume_db if player_name == &"MachineryLoop" else cue_volume_db)
	)
	if not is_equal_approx(player.max_distance, expected_maximum_distance):
		errors.append("%s maximum distance does not match the component contract" % player_name)
	if not is_equal_approx(player.unit_size, expected_reference_distance):
		errors.append("%s reference distance does not match the component contract" % player_name)
	if player.doppler_tracking != AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED:
		errors.append("%s must not pitch-shift stationary station machinery" % player_name)
	if player.emission_angle_enabled or not is_equal_approx(player.panning_strength, 1.0):
		errors.append("%s must remain a fully spatial omnidirectional source" % player_name)
	if player.max_polyphony != 1:
		errors.append("%s must remain bounded to one voice" % player_name)
	if not is_equal_approx(player.max_db, -3.0):
		errors.append("%s must retain the bounded maximum output level" % player_name)
	if player.area_mask != 0:
		errors.append("%s must not use area-based audio bus overrides" % player_name)
	if player.autoplay:
		errors.append("%s playback must remain under component lifecycle control" % player_name)
	if not is_equal_approx(player.volume_db, expected_volume_db):
		errors.append("%s volume does not match the current bounded spatial mix" % player_name)
	if not is_equal_approx(player.pitch_scale, 1.0):
		errors.append("%s pitch must remain at the authored deterministic rate" % player_name)
	if not player.position.is_equal_approx(Vector3.ZERO):
		errors.append("%s must remain at the component acoustic origin" % player_name)
	if (
		not is_equal_approx(player.attenuation_filter_cutoff_hz, ATTENUATION_FILTER_CUTOFF_HZ)
		or not is_equal_approx(player.attenuation_filter_db, ATTENUATION_FILTER_DB)
	):
		errors.append("%s attenuation filter must retain the authored spatial mix" % player_name)
	if player.stream_paused:
		errors.append("%s cannot attest active playback while its stream is paused" % player_name)
	if not _player_stream_matches_lifecycle(player):
		errors.append("%s stream/playback state does not match owned component resources" % player_name)


func _set_evidence_metadata() -> void:
	set_meta(&"station_ambience", true)
	set_meta(&"evidence_status", EVIDENCE_STATUS)
	set_meta(&"design_origin", DESIGN_ORIGIN)
	set_meta(&"historically_supported", false)
	set_meta(&"content_note", CONTENT_NOTE)
