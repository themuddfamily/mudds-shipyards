class_name StationMusicBed
extends Node

const MusicDirectorType := preload("res://scripts/audio/music_director.gd")

## Bounded three-voice music/ambient bed for the non-combat station state.
##
## The three checked-in loops are project-original fixed-seed offline synthesis
## (`tools/audio/generate_station_music_v1.py`). Nothing here is recovered or
## authentic Keth audio, and the component makes no claim that the result sounds
## good: a human listening pass is a separate, outstanding acceptance step.
##
## The bed strictly *observes*. `notify_session_state()` accepts an already
## decided session state and never calls back into gameplay, combat, phases, or
## the flow coordinator. Its only outputs are three non-positional voices on the
## `Music` bus and one read-only audit/state report.

## Announces that a layer's playback state changed. Presentation and captions may
## observe this; nothing in gameplay does. It fires from the component's own
## bookkeeping, so it stays correct under the Dummy driver.
signal layer_state_changed(layer_id: StringName, active: bool)

const SCHEMA_VERSION := 1
const COMPONENT_ID: StringName = &"station-music-bed"
const EVIDENCE_STATUS: StringName = &"modern_interpretation"
const DESIGN_ORIGIN: StringName = &"project_original_offline_music_synthesis"
const AUDIO_BUS: StringName = &"Music"
const SAMPLE_RATE := 22050
const ASSET_DIRECTORY := "res://assets/audio/music"
const MANIFEST_PATH := ASSET_DIRECTORY + "/station_music_v1_asset_manifest.json"

const LAYER_DRONE: StringName = &"drone"
const LAYER_HARMONICS: StringName = &"harmonics"
const LAYER_MOTIF: StringName = &"motif"
## Fixed declaration order. Every roster walk uses this array, so reports and
## audits never depend on Dictionary iteration order.
const LAYER_IDS: Array[StringName] = [LAYER_DRONE, LAYER_HARMONICS, LAYER_MOTIF]

const LAYER_NODE_NAMES := {
	LAYER_DRONE: &"DroneLayer",
	LAYER_HARMONICS: &"HarmonicsLayer",
	LAYER_MOTIF: &"MotifLayer",
}
const LAYER_STREAM_PATHS := {
	LAYER_DRONE: ASSET_DIRECTORY + "/station_bed_drone_v1.wav",
	LAYER_HARMONICS: ASSET_DIRECTORY + "/station_bed_harmonics_v1.wav",
	LAYER_MOTIF: ASSET_DIRECTORY + "/station_bed_motif_v1.wav",
}
## Frozen content identity of the *imported* PCM payloads, hashed once per load
## rather than per frame. A silent re-export, a truncation, or a third-party
## substitution fails the audit instead of quietly changing the mix. The raw
## source-file hashes are separately pinned by `station_music_asset_test.gd`.
const LAYER_STREAM_DATA_SHA256 := {
	LAYER_DRONE: "4e0173cb2fffd4c1efb514d0b9bbbc58456d120a94104980228c391704f242f2",
	LAYER_HARMONICS: "b65a3d4f698f16e393c1d2994447714cbdd9365e45238bca9352943a9bd06ec1",
	LAYER_MOTIF: "b8934dbc1ece958f79006559fd3e0e93a3dffe6d1d541e71eb57a70382fc22ba",
}
const LAYER_FRAME_COUNTS := {
	LAYER_DRONE: 352800,
	LAYER_HARMONICS: 264600,
	LAYER_MOTIF: 441000,
}
const LAYER_LOOP_SECONDS := {
	LAYER_DRONE: 16.0,
	LAYER_HARMONICS: 12.0,
	LAYER_MOTIF: 20.0,
}
## Small authored trim on top of the already conservative asset normalization.
## The `Music` bus carries the -6 dB category offset; these only balance the
## three layers against each other.
const LAYER_VOLUME_DB := {
	LAYER_DRONE: 0.0,
	LAYER_HARMONICS: -1.5,
	LAYER_MOTIF: -2.5,
}
## 16 s, 12 s, and 20 s only realign every 240 s, so the exact three-layer
## combination repeats once every four minutes.
const COMBINED_CYCLE_SECONDS := 240.0

const LOOP_VOICE_COUNT := 3
const MAXIMUM_SIMULTANEOUS_VOICES := LOOP_VOICE_COUNT
const RESIDENT_BYTE_BUDGET := 2_162_688

const STATE_REST: StringName = &"rest"
const STATE_FLIGHT: StringName = &"flight"
const STATE_COMBAT: StringName = &"combat"
const SESSION_STATES: Array[StringName] = [STATE_REST, STATE_FLIGHT, STATE_COMBAT]
const PRESENTATION_STATION: StringName = &"station"
const PRESENTATION_PLANETARY: StringName = &"planetary"
const PRESENTATION_LANDING: StringName = &"landing"
const PRESENTATION_STATES: Array[StringName] = [
	PRESENTATION_STATION,
	PRESENTATION_PLANETARY,
	PRESENTATION_LANDING,
	STATE_COMBAT,
]

## Target layer gains per observed session state. Combat silences the bed
## outright: the score yields to the fight rather than trying to score it.
const STATE_LAYER_TARGETS := {
	STATE_REST: {
		LAYER_DRONE: 1.0,
		LAYER_HARMONICS: 1.0,
		LAYER_MOTIF: 1.0,
	},
	STATE_FLIGHT: {
		LAYER_DRONE: 0.85,
		LAYER_HARMONICS: 0.55,
		LAYER_MOTIF: 0.0,
	},
	STATE_COMBAT: {
		LAYER_DRONE: 0.0,
		LAYER_HARMONICS: 0.0,
		LAYER_MOTIF: 0.0,
	},
}
## Phase-specific target profiles reuse the resident authored loops. Landing is
## intentionally a crossfade profile: it brings back a restrained motif while
## keeping the sustaining bed present, without adding a fourth voice or asset.
const PRESENTATION_LAYER_TARGETS := {
	PRESENTATION_STATION: {
		LAYER_DRONE: 1.0,
		LAYER_HARMONICS: 1.0,
		LAYER_MOTIF: 1.0,
	},
	PRESENTATION_PLANETARY: {
		LAYER_DRONE: 0.85,
		LAYER_HARMONICS: 0.55,
		LAYER_MOTIF: 0.0,
	},
	PRESENTATION_LANDING: {
		LAYER_DRONE: 0.65,
		LAYER_HARMONICS: 0.8,
		LAYER_MOTIF: 0.28,
	},
	STATE_COMBAT: {
		LAYER_DRONE: 0.0,
		LAYER_HARMONICS: 0.0,
		LAYER_MOTIF: 0.0,
	},
}

## Linear gain units per second. Rising is slow so the bed never announces
## itself; the combat duck is quick so an encounter is never scored over.
const FADE_IN_RATE_PER_SECOND := 0.25
const FADE_OUT_RATE_PER_SECOND := 0.5
const COMBAT_DUCK_RATE_PER_SECOND := 1.25
const MAX_COMBAT_MIX_INTENSITY := 1.0
## After combat ends the bed stays out for this long before it starts returning.
const COMBAT_RECOVERY_HOLD_SECONDS := 4.0
## Below this the layer is stopped and detached instead of held at a silent
## volume, so a faded-out bed strands no voice.
const MINIMUM_AUDIBLE_GAIN := 0.0005

const CONTENT_NOTE := (
	"The key, voicing, loop lengths, bell motif, layer levels, and state response are "
	+ "project-original modern composition and sound design. No surviving source "
	+ "authenticates any music for the original Keth Shipyards. Automated checks cover "
	+ "determinism, voice bounds, routing, and lifecycle only; whether the bed actually "
	+ "sounds good remains an outstanding human listening pass."
)

@export var bed_enabled := true

var _players: Dictionary = {}
var _streams: Dictionary = {}
var _stream_ids: Dictionary = {}
var _stream_fingerprints: Dictionary = {}
var _player_ids: Dictionary = {}
var _gains: Dictionary = {}
var _targets: Dictionary = {}
var _positions: Dictionary = {}
var _active: Dictionary = {}
var _session_state: StringName = STATE_REST
var _presentation_state: StringName = PRESENTATION_STATION
var _combat_recovery_remaining := 0.0
var _combat_mix_intensity := 0.0
var _resident_sample_bytes := 0
var _resources_ready := false
var _audio_available := false
var _initialized := false
var _tearing_down := false
var _bed_paused := false
var _elapsed_bed_seconds := 0.0
var _state_change_count := 0
var _layer_start_count := 0
var _layer_stop_count := 0
var _music_director: MusicDirectorType


func _enter_tree() -> void:
	# A whole `Main` subtree can be detached and re-added without `_ready()`
	# running again. Rebuild only the released playback handles, and resume each
	# layer at its retained loop position rather than replaying the bed from bar
	# one every time the scene is streamed back in.
	_tearing_down = false
	if _initialized:
		_audio_available = _backend_supports_playback()
		call_deferred("_restore_after_enter_tree")


func _ready() -> void:
	_tearing_down = false
	if _initialized:
		_restore_after_enter_tree()
		return
	_audio_available = _backend_supports_playback()
	for layer_id in LAYER_IDS:
		var player := get_node_or_null(NodePath(String(LAYER_NODE_NAMES[layer_id]))) as AudioStreamPlayer
		if player != null:
			_players[layer_id] = player
			_player_ids[layer_id] = player.get_instance_id()
		_gains[layer_id] = 0.0
		_targets[layer_id] = 0.0
		_positions[layer_id] = 0.0
		_active[layer_id] = false
	_configure_players()
	_load_streams()
	_set_evidence_metadata()
	_music_director = MusicDirectorType.new()
	_music_director.name = "MusicDirector"
	add_child(_music_director)
	add_to_group(&"station_music_bed", false)
	_initialized = true
	_apply_session_targets()
	_apply_playback_state()


func _process(delta: float) -> void:
	if not _initialized or _tearing_down or not is_inside_tree():
		return
	if not is_finite(delta) or delta <= 0.0:
		return
	if not bed_enabled or _bed_paused:
		return
	_elapsed_bed_seconds += delta
	if _combat_recovery_remaining > 0.0:
		_combat_recovery_remaining = maxf(0.0, _combat_recovery_remaining - delta)
		_apply_session_targets()
	_advance_gains(delta)
	_advance_positions(delta)
	_apply_playback_state()


func _notification(what: int) -> void:
	# The pause panel owns `SceneTree.paused`; the bed only observes the resulting
	# node notification. Nothing here reaches back into the pause menu or the flow.
	if what == NOTIFICATION_PAUSED:
		set_bed_paused(true)
	elif what == NOTIFICATION_UNPAUSED:
		set_bed_paused(false)


func _exit_tree() -> void:
	# Release every playback handle before the subtree leaves, but retain the
	# gain envelope and loop positions so re-entry resumes rather than restarts.
	_tearing_down = true
	for layer_id in LAYER_IDS:
		_stop_and_detach(layer_id)


## Accepts an already decided session state. Returns false for an unknown state
## and changes nothing: the bed never invents or corrects gameplay state.
func notify_session_state(state: StringName) -> bool:
	if not _can_mutate_live_bed():
		return false
	if not SESSION_STATES.has(state):
		return false
	var state_changed := state != _session_state
	if state_changed:
		if _session_state == STATE_COMBAT:
			# Leaving combat starts a hold, so the bed does not swell back in on
			# top of a debris field the moment the last shot lands.
			_combat_recovery_remaining = COMBAT_RECOVERY_HOLD_SECONDS
		else:
			_combat_recovery_remaining = 0.0
		_session_state = state
		_presentation_state = _presentation_for_session_state(state)
		_state_change_count += 1
	if is_instance_valid(_music_director) and state_changed:
		_music_director.observe_session_state(state)
	_apply_session_targets()
	if is_inside_tree() and not _tearing_down:
		_apply_playback_state()
	return true


## Accepts an already-decided broader phase and maps it to this bed's bounded
## rest/flight/combat vocabulary. The director still owns no gameplay state.
func notify_music_phase(phase: StringName) -> bool:
	if not _can_mutate_live_bed() or not is_instance_valid(_music_director):
		return false
	var observation := _music_director.observe_phase(phase)
	if not bool(observation.get("accepted", false)):
		return false
	var accepted := notify_session_state(StringName(observation.get("session_state", &"")))
	if accepted:
		_presentation_state = StringName(observation.get("state", PRESENTATION_STATION))
		# The session compatibility call above may have restated the narrower
		# station/flight vocabulary; restore the phase-level presentation record.
		_music_director.observe_phase(phase)
		_apply_session_targets()
		if is_inside_tree() and not _tearing_down:
			_apply_playback_state()
	return accepted


## Accepts a caller-owned combat presentation intensity. Zero retains the
## original hard yield; nonzero values let a presentation caller keep a quiet
## resident tension bed without granting the bed gameplay authority.
func set_combat_mix_intensity(intensity: float) -> bool:
	if not _can_mutate_live_bed() or not is_finite(intensity) \
			or intensity < 0.0 or intensity > MAX_COMBAT_MIX_INTENSITY:
		return false
	if is_instance_valid(_music_director):
		var observation := _music_director.set_combat_intensity(intensity)
		if not bool(observation.get("accepted", false)):
			return false
	_combat_mix_intensity = intensity
	_apply_session_targets()
	if is_inside_tree() and not _tearing_down:
		_apply_playback_state()
	return true


func get_session_state() -> StringName:
	return _session_state


func get_presentation_state() -> StringName:
	return _presentation_state


func get_music_director() -> MusicDirectorType:
	return _music_director


## Reversibly starts or silences the whole bed. Disabling immediately releases
## every voice; the retained loop positions make re-enabling a resume.
func set_bed_enabled(enabled: bool) -> void:
	if not _can_mutate_live_bed():
		return
	if bed_enabled == enabled:
		return
	bed_enabled = enabled
	if not bed_enabled:
		for layer_id in LAYER_IDS:
			_gains[layer_id] = 0.0
			_stop_and_detach(layer_id)
		_apply_session_targets()
		return
	_apply_session_targets()
	if is_inside_tree() and not _tearing_down:
		_apply_playback_state()


func is_bed_enabled() -> bool:
	return bed_enabled


## Freezes the bed for a paused game: playback and the loop clock both hold, so
## resuming continues the same bar instead of jumping forward or restarting.
func set_bed_paused(paused: bool) -> void:
	if not _can_mutate_live_bed():
		return
	if _bed_paused == paused:
		return
	_bed_paused = paused
	for layer_id in LAYER_IDS:
		var player := _get_player(layer_id)
		if player != null:
			player.stream_paused = paused and player.playing


func is_bed_paused() -> bool:
	return _bed_paused


## Returns the bed to its authored start-of-session condition without freeing or
## reloading resources. This is the explicit reset seam; a plain detach must not
## do this, and does not.
func reset_bed() -> void:
	if not _can_mutate_live_bed():
		return
	for layer_id in LAYER_IDS:
		_stop_and_detach(layer_id)
		_gains[layer_id] = 0.0
		_positions[layer_id] = 0.0
	_session_state = STATE_REST
	_presentation_state = PRESENTATION_STATION
	_combat_recovery_remaining = 0.0
	_combat_mix_intensity = 0.0
	_bed_paused = false
	_elapsed_bed_seconds = 0.0
	_apply_session_targets()
	if is_inside_tree() and not _tearing_down:
		_apply_playback_state()


## Deep cleanup hook for streamed-scene unloads and test teardown. Idempotent.
func release_audio_resources() -> void:
	for layer_id in LAYER_IDS:
		_stop_and_detach(layer_id)
	_streams.clear()
	_stream_ids.clear()
	_stream_fingerprints.clear()
	_resident_sample_bytes = 0
	_resources_ready = false


func _can_mutate_live_bed() -> bool:
	return is_inside_tree() and not _tearing_down and not is_queued_for_deletion()


func get_component_id() -> StringName:
	return COMPONENT_ID


func get_evidence_metadata() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"evidence_status": EVIDENCE_STATUS,
		"design_origin": DESIGN_ORIGIN,
		"historically_supported": false,
		"human_listening_pass": &"outstanding",
		"content_note": CONTENT_NOTE,
		"modern_interpretations": PackedStringArray([
			"D natural minor modal centre and Dm9 voicing",
			"three loop lengths and their 240 s combined cycle",
			"descending bell motif reserved for the station at rest",
			"layer levels, fade rates, and the combat duck",
		]),
	}


func get_music_contract() -> Dictionary:
	var loop_seconds := {}
	var volumes := {}
	for layer_id in LAYER_IDS:
		loop_seconds[layer_id] = float(LAYER_LOOP_SECONDS[layer_id])
		volumes[layer_id] = float(LAYER_VOLUME_DB[layer_id])
	return {
		"schema_version": SCHEMA_VERSION,
		"bus": AUDIO_BUS,
		"positional": false,
		"tuning_a4_hz": 440.0,
		"mode": "D natural minor (Aeolian)",
		"layer_ids": PackedStringArray(LAYER_IDS),
		"layer_loop_seconds": loop_seconds,
		"layer_volume_db": volumes,
		"combined_cycle_seconds": COMBINED_CYCLE_SECONDS,
		"session_states": PackedStringArray(SESSION_STATES),
		"presentation_states": PackedStringArray(PRESENTATION_STATES),
		"fade_in_rate_per_second": FADE_IN_RATE_PER_SECOND,
		"fade_out_rate_per_second": FADE_OUT_RATE_PER_SECOND,
		"combat_duck_rate_per_second": COMBAT_DUCK_RATE_PER_SECOND,
		"combat_recovery_hold_seconds": COMBAT_RECOVERY_HOLD_SECONDS,
		"gameplay_authority": false,
	}


func get_state_snapshot() -> Dictionary:
	var gains := {}
	var targets := {}
	var positions := {}
	var active := PackedStringArray()
	for layer_id in LAYER_IDS:
		gains[layer_id] = float(_gains.get(layer_id, 0.0))
		targets[layer_id] = float(_targets.get(layer_id, 0.0))
		positions[layer_id] = float(_positions.get(layer_id, 0.0))
		if bool(_active.get(layer_id, false)):
			active.append(String(layer_id))
	return {
		"schema_version": SCHEMA_VERSION,
		"session_state": _session_state,
		"presentation_state": _presentation_state,
		"bed_enabled": bed_enabled,
		"bed_paused": _bed_paused,
		"combat_recovery_remaining": _combat_recovery_remaining,
		"combat_mix_intensity": _combat_mix_intensity,
		"elapsed_bed_seconds": _elapsed_bed_seconds,
		"layer_gains": gains,
		"layer_targets": targets,
		"layer_positions": positions,
		"active_layer_ids": active,
		"active_layer_count": active.size(),
		"state_change_count": _state_change_count,
		"layer_start_count": _layer_start_count,
		"layer_stop_count": _layer_stop_count,
	}


func get_performance_report() -> Dictionary:
	var live_player_count := find_children("*", "AudioStreamPlayer", true, false).size()
	var playing_count := 0
	for layer_id in LAYER_IDS:
		var player := _get_player(layer_id)
		if player != null and player.playing:
			playing_count += 1
	return {
		"schema_version": SCHEMA_VERSION,
		"audio_player_count": live_player_count,
		"loop_voice_count": LOOP_VOICE_COUNT,
		"transient_voice_count": 0,
		"maximum_simultaneous_voices": MAXIMUM_SIMULTANEOUS_VOICES,
		"playing_voice_count": playing_count,
		"per_frame_script_processing": true,
		"runtime_wave_synthesis_allowed": false,
		"resident_sample_bytes": _resident_sample_bytes,
		"resident_byte_budget": RESIDENT_BYTE_BUDGET,
		"within_resident_budget": _resident_sample_bytes <= RESIDENT_BYTE_BUDGET,
		"audio_driver": AudioServer.get_driver_name(),
		"playback_available": _audio_available,
		"inside_tree": is_inside_tree(),
		"lifecycle_suspended": _initialized and (not is_inside_tree() or _tearing_down),
	}


func get_audit_report() -> Dictionary:
	var errors := PackedStringArray()
	var lifecycle_active := _initialized and is_inside_tree() and not _tearing_down

	if not _initialized:
		errors.append("music bed has not completed its fixed hierarchy build")
	if not is_in_group(&"station_music_bed"):
		errors.append("missing music-bed discovery group")
	if (
		get_meta(&"evidence_status", &"") != EVIDENCE_STATUS
		or get_meta(&"design_origin", &"") != DESIGN_ORIGIN
		or get_meta(&"historically_supported", true) != false
		or get_meta(&"gameplay_authority", true) != false
	):
		errors.append("music-bed provenance or authority metadata drifted")

	var live_players := find_children("*", "AudioStreamPlayer", true, false)
	if live_players.size() != MAXIMUM_SIMULTANEOUS_VOICES or _players.size() != LAYER_IDS.size():
		errors.append("music bed must own exactly three bounded non-positional voices")
	if not find_children("*", "AudioStreamPlayer3D", true, false).is_empty():
		errors.append("music bed must not introduce positional voices")
	if not find_children("*", "CollisionObject3D", true, false).is_empty():
		errors.append("music bed must not introduce gameplay collision")

	var measured_bytes := 0
	var unique_stream_ids := {}
	for layer_id in LAYER_IDS:
		var player := _get_player(layer_id)
		if player == null:
			errors.append("music bed is missing its %s voice" % layer_id)
		else:
			if (
				player.name != String(LAYER_NODE_NAMES[layer_id])
				or player.bus != AUDIO_BUS
				or player.max_polyphony != 1
				or player.autoplay
				or not is_equal_approx(player.pitch_scale, 1.0)
				or player.get_instance_id() != int(_player_ids.get(layer_id, 0))
			):
				errors.append("music voice %s does not match its bounded routing contract" % layer_id)
			if not _player_state_matches_lifecycle(layer_id, player):
				errors.append("music voice %s playback state does not match its owned gain" % layer_id)

		if _resources_ready:
			var stream := _get_stream(layer_id)
			if stream == null:
				errors.append("resident music bank is missing %s" % layer_id)
				continue
			var instance_id := stream.get_instance_id()
			if unique_stream_ids.has(instance_id):
				errors.append("music layer %s does not own a unique stream resource" % layer_id)
			unique_stream_ids[instance_id] = true
			if instance_id != int(_stream_ids.get(layer_id, 0)):
				errors.append("music layer %s stream identity changed after load" % layer_id)
			if (
				stream.format != AudioStreamWAV.FORMAT_16_BITS
				or stream.mix_rate != SAMPLE_RATE
				or stream.stereo
			):
				errors.append("music layer %s does not match the mono PCM contract" % layer_id)
			# The WAV importer publishes an inclusive final loop frame, so a
			# complete-range forward loop ends at `frame_count - 1`.
			if (
				stream.loop_mode != AudioStreamWAV.LOOP_FORWARD
				or stream.loop_begin != 0
				or stream.loop_end != int(LAYER_FRAME_COUNTS[layer_id]) - 1
			):
				errors.append("music layer %s must loop across its complete sample range" % layer_id)
			if stream.data.size() != int(LAYER_FRAME_COUNTS[layer_id]) * 2:
				errors.append("music layer %s has an unexpected sample length" % layer_id)
			if str(_stream_fingerprints.get(layer_id, "")) != String(LAYER_STREAM_DATA_SHA256[layer_id]):
				errors.append("music layer %s content does not match its frozen authored render" % layer_id)
			if not _stream_is_audible(stream):
				errors.append("music layer %s decoded to silence" % layer_id)
			measured_bytes += stream.data.size()

	if lifecycle_active and bed_enabled and not _resources_ready:
		errors.append("enabled in-tree bed must retain its authored loop bank")
	if _resources_ready and measured_bytes != _resident_sample_bytes:
		errors.append("resident sample byte accounting does not match the live bank")
	if _resident_sample_bytes > RESIDENT_BYTE_BUDGET:
		errors.append("resident music bank exceeds its fixed byte budget")

	if not SESSION_STATES.has(_session_state):
		errors.append("music bed holds an unknown session state")
	if not PRESENTATION_STATES.has(_presentation_state):
		errors.append("music bed holds an unknown presentation state")
	var expected_targets := _resolve_targets()
	for layer_id in LAYER_IDS:
		var gain := float(_gains.get(layer_id, -1.0))
		if not is_finite(gain) or gain < 0.0 or gain > 1.0:
			errors.append("music layer %s gain left the bounded 0..1 envelope" % layer_id)
		if not is_equal_approx(float(_targets.get(layer_id, -1.0)), float(expected_targets[layer_id])):
			errors.append("music layer %s target does not match the observed session state" % layer_id)
		var position := float(_positions.get(layer_id, -1.0))
		if not is_finite(position) or position < 0.0 or position >= float(LAYER_LOOP_SECONDS[layer_id]):
			errors.append("music layer %s loop position left its bounded loop range" % layer_id)
	if _session_state == STATE_COMBAT:
		for layer_id in LAYER_IDS:
			if float(_targets.get(layer_id, 1.0)) != 0.0:
				errors.append("combat must silence every music layer target")
	if not lifecycle_active or not bed_enabled:
		for player_value in live_players:
			var idle_player := player_value as AudioStreamPlayer
			if idle_player.playing or idle_player.stream != null:
				errors.append("suspended music lifecycle must keep every voice stopped and detached")

	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"component_id": COMPONENT_ID,
		"evidence": get_evidence_metadata(),
		"music": get_music_contract(),
		"state": get_state_snapshot(),
		"performance": get_performance_report(),
	}


func _apply_session_targets() -> void:
	var resolved := _resolve_targets()
	for layer_id in LAYER_IDS:
		_targets[layer_id] = float(resolved[layer_id])


func _resolve_targets() -> Dictionary:
	var resolved := {}
	# The recovery hold keeps combat's silence in force after the encounter ends.
	var effective_state := _presentation_state
	if _combat_recovery_remaining > 0.0 and _session_state != STATE_COMBAT:
		effective_state = STATE_COMBAT
	var table := PRESENTATION_LAYER_TARGETS.get(
		effective_state,
		PRESENTATION_LAYER_TARGETS[STATE_COMBAT]
	) as Dictionary
	if effective_state == STATE_COMBAT and _combat_mix_intensity > 0.0:
		table = {
			LAYER_DRONE: 0.12 * _combat_mix_intensity,
			LAYER_HARMONICS: 0.06 * _combat_mix_intensity,
			LAYER_MOTIF: 0.0,
		}
	for layer_id in LAYER_IDS:
		resolved[layer_id] = (
			0.0 if not bed_enabled else float(table.get(layer_id, 0.0))
		)
	return resolved


func _presentation_for_session_state(state: StringName) -> StringName:
	match state:
		STATE_FLIGHT:
			return PRESENTATION_PLANETARY
		STATE_COMBAT:
			return STATE_COMBAT
	return PRESENTATION_STATION


func _advance_gains(delta: float) -> void:
	for layer_id in LAYER_IDS:
		var gain := float(_gains.get(layer_id, 0.0))
		var target := float(_targets.get(layer_id, 0.0))
		if is_equal_approx(gain, target):
			_gains[layer_id] = target
			continue
		var rate := FADE_IN_RATE_PER_SECOND
		if target < gain:
			rate = (
				COMBAT_DUCK_RATE_PER_SECOND
				if _session_state == STATE_COMBAT
				else FADE_OUT_RATE_PER_SECOND
			)
		var step := rate * delta
		if target > gain:
			_gains[layer_id] = minf(target, gain + step)
		else:
			_gains[layer_id] = maxf(target, gain - step)


func _advance_positions(delta: float) -> void:
	# The component owns the loop clock so the resume offset is deterministic and
	# identical under every audio driver, including Dummy.
	for layer_id in LAYER_IDS:
		if float(_gains.get(layer_id, 0.0)) < MINIMUM_AUDIBLE_GAIN:
			continue
		var loop_seconds := float(LAYER_LOOP_SECONDS[layer_id])
		var position := float(_positions.get(layer_id, 0.0)) + delta
		_positions[layer_id] = fposmod(position, loop_seconds)


func _apply_playback_state() -> void:
	if not _initialized or _tearing_down or not is_inside_tree():
		return
	for layer_id in LAYER_IDS:
		var player := _get_player(layer_id)
		if player == null:
			continue
		var gain := float(_gains.get(layer_id, 0.0))
		if gain < MINIMUM_AUDIBLE_GAIN or not bed_enabled:
			_stop_and_detach(layer_id)
			continue
		player.volume_db = float(LAYER_VOLUME_DB[layer_id]) + linear_to_db(gain)
		if bool(_active.get(layer_id, false)) and player.playing:
			continue
		if not _audio_available:
			# Dummy owns the same deterministic envelope and loop clock for stable
			# accounting, but never receives a playback handle: its mixer does not
			# advance, so attaching a stream would pin needless playback state.
			continue
		var stream := _get_stream(layer_id)
		if stream == null:
			continue
		player.stream = stream
		player.play(float(_positions.get(layer_id, 0.0)))
		if not _request_layer_playback(player):
			# A named backend can still reject playback. Fall back to the exact
			# silent lifecycle instead of retaining a handle that never started,
			# and stop asking on later frames.
			player.stream = null
			_audio_available = false
			continue
		player.stream_paused = _bed_paused
		_active[layer_id] = true
		_layer_start_count += 1
		layer_state_changed.emit(layer_id, true)


## Backend capability seam. The Dummy driver used by the headless matrix owns the
## same deterministic envelope and loop clock, but never receives a playback
## handle, so tests must override this to exercise the real attach path instead
## of passing because a silent backend accepted everything.
func _backend_supports_playback() -> bool:
	return AudioServer.get_driver_name() != "Dummy"


## Playback acceptance seam, checked immediately after `play()`.
func _request_layer_playback(player: AudioStreamPlayer) -> bool:
	return player.playing


func _stop_and_detach(layer_id: StringName) -> void:
	var player := _get_player(layer_id)
	if player != null:
		player.stop()
		player.stream_paused = false
		player.stream = null
	if bool(_active.get(layer_id, false)):
		_active[layer_id] = false
		_layer_stop_count += 1
		layer_state_changed.emit(layer_id, false)


func _restore_after_enter_tree() -> void:
	if (
		not _initialized
		or _tearing_down
		or is_queued_for_deletion()
		or not is_inside_tree()
	):
		return
	_configure_players()
	_load_streams()
	_apply_session_targets()
	_apply_playback_state()


func _configure_players() -> void:
	for layer_id in LAYER_IDS:
		var player := _get_player(layer_id)
		if player == null:
			continue
		player.name = String(LAYER_NODE_NAMES[layer_id])
		player.bus = AUDIO_BUS
		player.max_polyphony = 1
		player.autoplay = false
		player.pitch_scale = 1.0
		player.volume_db = float(LAYER_VOLUME_DB[layer_id])
		player.stop()
		player.stream_paused = false
		player.stream = null
		_active[layer_id] = false


func _load_streams() -> void:
	if _resources_ready:
		return
	_resident_sample_bytes = 0
	for layer_id in LAYER_IDS:
		var stream := load(String(LAYER_STREAM_PATHS[layer_id])) as AudioStreamWAV
		if stream == null:
			continue
		_streams[layer_id] = stream
		_stream_ids[layer_id] = stream.get_instance_id()
		_stream_fingerprints[layer_id] = _hash_bytes(stream.data)
		_resident_sample_bytes += stream.data.size()
	_resources_ready = _streams.size() == LAYER_IDS.size()


func _hash_bytes(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	if context.update(bytes) != OK:
		return ""
	return context.finish().hex_encode()


func _get_player(layer_id: StringName) -> AudioStreamPlayer:
	var player := _players.get(layer_id) as AudioStreamPlayer
	return player if is_instance_valid(player) else null


func _get_stream(layer_id: StringName) -> AudioStreamWAV:
	return _streams.get(layer_id) as AudioStreamWAV


func _player_state_matches_lifecycle(layer_id: StringName, player: AudioStreamPlayer) -> bool:
	var should_sound := (
		_initialized
		and is_inside_tree()
		and not _tearing_down
		and bed_enabled
		and _audio_available
		and _resources_ready
		and float(_gains.get(layer_id, 0.0)) >= MINIMUM_AUDIBLE_GAIN
	)
	# Playback truth comes from the component's own start/stop bookkeeping rather
	# than the engine flag, so the audit means the same thing on every backend
	# (including Dummy, where the envelope runs but no voice ever attaches).
	if should_sound:
		return player.stream == _get_stream(layer_id) and bool(_active.get(layer_id, false))
	return player.stream == null and not bool(_active.get(layer_id, false))


## True when the decoded PCM payload carries real signal. A silent or truncated
## import must fail the audit rather than pass as "routed correctly".
func _stream_is_audible(stream: AudioStreamWAV) -> bool:
	var data := stream.data
	var frame_count := data.size() / 2
	if frame_count <= 0:
		return false
	var peak := 0
	# A fixed 4096-frame stride keeps the audit bounded on multi-megabyte loops
	# while still crossing every musical gesture in a 12-20 s file.
	var index := 0
	while index < frame_count:
		var sample := absi(data.decode_s16(index * 2))
		if sample > peak:
			peak = sample
		index += 4096
	return peak >= 256


func _set_evidence_metadata() -> void:
	set_meta(&"station_music_bed", true)
	set_meta(&"evidence_status", EVIDENCE_STATUS)
	set_meta(&"design_origin", DESIGN_ORIGIN)
	set_meta(&"historically_supported", false)
	set_meta(&"gameplay_authority", false)
	set_meta(&"human_listening_pass", &"outstanding")
	set_meta(&"content_note", CONTENT_NOTE)
