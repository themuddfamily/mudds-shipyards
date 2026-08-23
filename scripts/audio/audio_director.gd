class_name AudioDirector
extends Node

const SemanticCueRouter := preload("res://scripts/audio/semantic_audio_cue_router.gd")

## Global non-positional audio used by the legacy game-flow cues.
##
## Every procedural waveform is generated once into a fixed resident bank when
## this node becomes ready. Cue requests only select a resident template and one
## of four replacement-style effect voices; no request creates an AudioStreamWAV.

## Announces that a named cue event occurred. This describes the *event*, not the
## backend: it fires even when audio is unavailable, so the caption channel stays
## correct under a Dummy driver or a muted mix. Footsteps deliberately have no
## cue ID; they are far too frequent to caption.
signal cue_started(cue_id: StringName)
signal semantic_cue_emitted(
	source_id: StringName,
	cue_id: StringName,
	intensity: float,
	world_position: Vector3
)

const CUE_UI_CONFIRM: StringName = &"ui_confirm"
const CUE_IMPACT: StringName = &"impact"
const CUE_TARGET_DESTROYED: StringName = &"target_destroyed"
const CUE_COMBAT_ALERT: StringName = &"combat_alert"
const CUE_CANOPY_OPEN: StringName = &"canopy_open"
const CUE_CANOPY_CLOSE: StringName = &"canopy_close"
const CUE_ENEMY_DESTROYED: StringName = &"enemy_destroyed"

const SAMPLE_RATE := 22050
const EFFECT_VOICE_COUNT := 4
const SEQUENCE_TIMER_COUNT := 3
const RESIDENT_BYTE_BUDGET := 360448
# `ceili()` deliberately preserves the synthesis function's historical sample
# counts. Binary float representation rounds the 0.28 s and 0.34 s cues up by
# one sample each, yielding this exact deterministic total.
const EXPECTED_RESIDENT_SAMPLE_BYTES := 340020

const STREAM_AMBIENCE: StringName = &"ambience"
const STREAM_UI_CONFIRM: StringName = &"ui_confirm"
const STREAM_IMPACT: StringName = &"impact"
const STREAM_TARGET_DESTROYED_PRIMARY: StringName = &"target_destroyed_primary"
const STREAM_TARGET_DESTROYED_TAIL: StringName = &"target_destroyed_tail"
const STREAM_COMBAT_ALERT_PRIMARY: StringName = &"combat_alert_primary"
const STREAM_COMBAT_ALERT_TAIL: StringName = &"combat_alert_tail"
const STREAM_CANOPY_OPEN: StringName = &"canopy_open"
const STREAM_CANOPY_CLOSE: StringName = &"canopy_close"
const STREAM_ENEMY_DESTROYED_PRIMARY: StringName = &"enemy_destroyed_primary"
const STREAM_ENEMY_DESTROYED_TAIL: StringName = &"enemy_destroyed_tail"
const STREAM_FOOTSTEP_QUIET: StringName = &"footstep_quiet"
const STREAM_FOOTSTEP_LOW: StringName = &"footstep_low"
const STREAM_FOOTSTEP_HIGH: StringName = &"footstep_high"
const STREAM_FOOTSTEP_FULL: StringName = &"footstep_full"

const RESIDENT_STREAM_IDS := [
	STREAM_AMBIENCE,
	STREAM_UI_CONFIRM,
	STREAM_IMPACT,
	STREAM_TARGET_DESTROYED_PRIMARY,
	STREAM_TARGET_DESTROYED_TAIL,
	STREAM_COMBAT_ALERT_PRIMARY,
	STREAM_COMBAT_ALERT_TAIL,
	STREAM_CANOPY_OPEN,
	STREAM_CANOPY_CLOSE,
	STREAM_ENEMY_DESTROYED_PRIMARY,
	STREAM_ENEMY_DESTROYED_TAIL,
	STREAM_FOOTSTEP_QUIET,
	STREAM_FOOTSTEP_LOW,
	STREAM_FOOTSTEP_HIGH,
	STREAM_FOOTSTEP_FULL,
]
const FOOTSTEP_STREAM_IDS := [
	STREAM_FOOTSTEP_QUIET,
	STREAM_FOOTSTEP_LOW,
	STREAM_FOOTSTEP_HIGH,
	STREAM_FOOTSTEP_FULL,
]
const STREAM_DURATIONS := {
	STREAM_AMBIENCE: 2.4,
	STREAM_UI_CONFIRM: 0.16,
	STREAM_IMPACT: 0.32,
	STREAM_TARGET_DESTROYED_PRIMARY: 0.8,
	STREAM_TARGET_DESTROYED_TAIL: 0.42,
	STREAM_COMBAT_ALERT_PRIMARY: 0.28,
	STREAM_COMBAT_ALERT_TAIL: 0.34,
	STREAM_CANOPY_OPEN: 0.48,
	STREAM_CANOPY_CLOSE: 0.48,
	STREAM_ENEMY_DESTROYED_PRIMARY: 1.05,
	STREAM_ENEMY_DESTROYED_TAIL: 0.62,
	STREAM_FOOTSTEP_QUIET: 0.09,
	STREAM_FOOTSTEP_LOW: 0.09,
	STREAM_FOOTSTEP_HIGH: 0.09,
	STREAM_FOOTSTEP_FULL: 0.09,
}

var _ambience: AudioStreamPlayer
var _effects: Array[AudioStreamPlayer] = []
var _target_destroyed_timer: Timer
var _combat_alert_timer: Timer
var _enemy_destroyed_timer: Timer
var _stream_bank: Dictionary = {}
var _stream_instance_ids: Dictionary = {}
var _player_instance_ids: Dictionary = {}
var _timer_instance_ids: Dictionary = {}
var _resident_sample_bytes := 0
var _bank_generation_count := 0
var _wave_synthesis_call_count := 0
var _resources_ready := false
var _effect_cursor := 0
var _footstep_cooldown := 0.0
var _audio_enabled := true
var _shutting_down := false
var _initialized := false
# The flow owns the ambient mix mode (on-foot, piloting, or the pre-shift
# default), while this director owns backend recovery. Keep the requested
# volume separate from the transient AudioStreamPlayer so a detached Main
# scene cannot silently revert the mode on re-entry.
var _desired_ambience_volume_db := -13.0
var _semantic_router


func _enter_tree() -> void:
	# `_ready()` runs only once for an ordinary remove/re-add cycle. Rebuild only
	# the released resident bank and backend handles; the fixed child hierarchy
	# remains the same set of nodes for the lifetime of this director.
	if _initialized:
		_shutting_down = false
		call_deferred("_restore_after_enter_tree")


func _ready() -> void:
	if not is_instance_valid(_semantic_router):
		_semantic_router = SemanticCueRouter.new()
		_semantic_router.name = "SemanticAudioCueRouter"
		add_child(_semantic_router)
		_semantic_router.semantic_cue_emitted.connect(_on_semantic_cue)
	if _initialized:
		_restore_after_enter_tree()
		return
	_shutting_down = false
	_build_stream_bank()

	_ambience = _make_player("Ambience", &"Ambience")
	_player_instance_ids[&"Ambience"] = _ambience.get_instance_id()
	for index in EFFECT_VOICE_COUNT:
		var effect := _make_player("Effect%d" % index, &"UI")
		effect.finished.connect(_release_finished_stream.bind(effect))
		_effects.append(effect)
		_player_instance_ids[StringName(effect.name)] = effect.get_instance_id()

	_target_destroyed_timer = _make_sequence_timer(
		"TargetDestroyedTailTimer",
		0.16,
		_play_target_destroyed_tail
	)
	_combat_alert_timer = _make_sequence_timer(
		"CombatAlertTailTimer",
		0.34,
		_play_combat_alert_tail
	)
	_enemy_destroyed_timer = _make_sequence_timer(
		"EnemyDestroyedTailTimer",
		0.18,
		_play_enemy_destroyed_tail
	)
	_initialized = true

	_restore_backend_state()


func _process(delta: float) -> void:
	_footstep_cooldown = maxf(0.0, _footstep_cooldown - delta)


## Binds a caller-owned semantic audio source without taking gameplay authority.
func bind_semantic_audio_source(source: Node, source_id: StringName) -> Dictionary:
	if not is_instance_valid(_semantic_router):
		return {"accepted": false, "reason": &"router_unavailable"}
	return _semantic_router.bind_source(source, source_id)


## Clears semantic source bindings for detach/re-entry without changing playback.
func detach_semantic_audio_sources() -> Dictionary:
	if not is_instance_valid(_semantic_router):
		return {"accepted": true, "reason": &"already_detached"}
	return _semantic_router.detach()


func get_semantic_audio_binding_count() -> int:
	return _semantic_router.get_binding_count() if is_instance_valid(_semantic_router) else 0


func _exit_tree() -> void:
	_shutting_down = true
	if is_instance_valid(_semantic_router):
		_semantic_router.detach()
	for timer in _get_sequence_timers():
		if is_instance_valid(timer):
			timer.stop()

	# Stop and detach playback handles before dropping the only resident bank.
	# This order keeps teardown safe for both real mixers and the Dummy driver.
	var players: Array[AudioStreamPlayer] = []
	if is_instance_valid(_ambience):
		players.append(_ambience)
	players.append_array(_effects)
	for player in players:
		if is_instance_valid(player):
			player.stop()
			player.stream = null

	_stream_bank.clear()
	_stream_instance_ids.clear()
	_resident_sample_bytes = 0
	_resources_ready = false
	_effect_cursor = 0
	_footstep_cooldown = 0.0
	_audio_enabled = false


func play_ui_confirm() -> void:
	if not _can_mutate_runtime_state():
		return
	cue_started.emit(CUE_UI_CONFIRM)
	_play_resident(STREAM_UI_CONFIRM, &"UI", -7.0)


func play_impact() -> void:
	if not _can_mutate_runtime_state():
		return
	cue_started.emit(CUE_IMPACT)
	_play_resident(STREAM_IMPACT, &"Weapons", -1.0)


func play_target_destroyed() -> void:
	if not _can_mutate_runtime_state():
		return
	cue_started.emit(CUE_TARGET_DESTROYED)
	if _play_resident(STREAM_TARGET_DESTROYED_PRIMARY, &"Weapons", -1.0):
		_restart_sequence_timer(_target_destroyed_timer)


func play_combat_alert() -> void:
	if not _can_mutate_runtime_state():
		return
	cue_started.emit(CUE_COMBAT_ALERT)
	if _play_resident(STREAM_COMBAT_ALERT_PRIMARY, &"UI", -4.0):
		_restart_sequence_timer(_combat_alert_timer)


func play_canopy(opening: bool) -> void:
	if not _can_mutate_runtime_state():
		return
	cue_started.emit(CUE_CANOPY_OPEN if opening else CUE_CANOPY_CLOSE)
	_play_resident(
		STREAM_CANOPY_OPEN if opening else STREAM_CANOPY_CLOSE,
		&"Ambience",
		-6.0
	)


func play_enemy_destroyed() -> void:
	if not _can_mutate_runtime_state():
		return
	cue_started.emit(CUE_ENEMY_DESTROYED)
	if _play_resident(STREAM_ENEMY_DESTROYED_PRIMARY, &"Weapons", 0.0):
		_restart_sequence_timer(_enemy_destroyed_timer)


func play_footstep(intensity: float = 1.0) -> void:
	if not _can_mutate_runtime_state():
		return
	if _footstep_cooldown > 0.0:
		return
	var safe_intensity := clampf(intensity, 0.0, 1.0) if is_finite(intensity) else 1.0
	_footstep_cooldown = lerpf(0.4, 0.27, safe_intensity)
	var bin_index := clampi(
		roundi(safe_intensity * float(FOOTSTEP_STREAM_IDS.size() - 1)),
		0,
		FOOTSTEP_STREAM_IDS.size() - 1
	)
	_play_resident(FOOTSTEP_STREAM_IDS[bin_index], &"Ambience", -10.0)


func set_on_foot(on_foot: bool) -> void:
	if not _can_mutate_runtime_state():
		return
	_desired_ambience_volume_db = -10.0 if on_foot else -18.0
	if is_instance_valid(_ambience):
		_ambience.volume_db = _desired_ambience_volume_db


func get_resident_stream_ids() -> PackedStringArray:
	return PackedStringArray(RESIDENT_STREAM_IDS)


func get_synthesis_report() -> Dictionary:
	return {
		"sample_rate": SAMPLE_RATE,
		"channel_count": 1,
		"sample_format": &"signed_pcm_16_bit",
		"resources_ready": _resources_ready,
		"resident_stream_count": _stream_bank.size(),
		"resident_stream_ids": get_resident_stream_ids(),
		"resource_instance_ids": _stream_instance_ids.duplicate(true),
		"resident_sample_bytes": _resident_sample_bytes,
		"expected_resident_sample_bytes": EXPECTED_RESIDENT_SAMPLE_BYTES,
		"generation_count": _bank_generation_count,
		"wave_synthesis_call_count": _wave_synthesis_call_count,
	}


func get_performance_report() -> Dictionary:
	return {
		"audio_player_count": 1 + _effects.size(),
		"ambience_voice_count": 1,
		"effect_voice_count": _effects.size(),
		"maximum_simultaneous_voices": 1 + EFFECT_VOICE_COUNT,
		"sequence_timer_count": _get_sequence_timers().size(),
		"fixed_sequence_scheduling": true,
		"runtime_wave_synthesis_allowed": false,
		"resident_sample_bytes": _resident_sample_bytes,
		"resident_byte_budget": RESIDENT_BYTE_BUDGET,
		"within_resident_budget": _resident_sample_bytes <= RESIDENT_BYTE_BUDGET,
		"per_frame_script_processing": true,
		"audio_driver": AudioServer.get_driver_name(),
		"playback_enabled": _audio_enabled,
		"inside_tree": is_inside_tree(),
		"lifecycle_suspended": _initialized and (not is_inside_tree() or _shutting_down),
	}


func get_audit_report() -> Dictionary:
	var errors := PackedStringArray()
	var lifecycle_active := _initialized and is_inside_tree() and not _shutting_down
	if not _initialized:
		errors.append("audio director has not completed its fixed hierarchy build")
	if _bank_generation_count < 1:
		errors.append("resident stream bank has never completed a synthesis generation")
	if _wave_synthesis_call_count != _bank_generation_count * RESIDENT_STREAM_IDS.size():
		errors.append("each synthesis generation must build every declared resident stream exactly once")
	if lifecycle_active:
		if not _resources_ready:
			errors.append("in-tree resident stream bank is not ready")
		if _stream_bank.size() != RESIDENT_STREAM_IDS.size():
			errors.append("resident stream bank must contain the exact declared roster")
	elif _resources_ready or not _stream_bank.is_empty() or not _stream_instance_ids.is_empty():
		errors.append("detached lifecycle must release every resident stream")

	var measured_bytes := 0
	var unique_instance_ids := {}
	if lifecycle_active:
		for stream_id in RESIDENT_STREAM_IDS:
			var stream := _get_stream(stream_id)
			if stream == null:
				errors.append("resident stream bank is missing %s" % stream_id)
				continue
			var instance_id := stream.get_instance_id()
			if unique_instance_ids.has(instance_id):
				errors.append("resident stream %s does not own a unique WAV resource" % stream_id)
			unique_instance_ids[instance_id] = true
			if instance_id != int(_stream_instance_ids.get(stream_id, 0)):
				errors.append("resident stream %s identity changed after synthesis" % stream_id)
			if (
				stream.format != AudioStreamWAV.FORMAT_16_BITS
				or stream.mix_rate != SAMPLE_RATE
				or stream.stereo
			):
				errors.append("resident stream %s does not match the mono PCM contract" % stream_id)
			var expected_bytes := ceili(float(STREAM_DURATIONS[stream_id]) * SAMPLE_RATE) * 2
			if stream.data.size() != expected_bytes:
				errors.append("resident stream %s has an unexpected sample length" % stream_id)
			if stream_id == STREAM_AMBIENCE:
				if (
					stream.loop_mode != AudioStreamWAV.LOOP_FORWARD
					or stream.loop_begin != 0
					or stream.loop_end != stream.data.size() / 2
				):
					errors.append("resident ambience must loop across its complete sample range")
			elif stream.loop_mode != AudioStreamWAV.LOOP_DISABLED:
				errors.append("resident cue %s must remain a bounded one-shot" % stream_id)
			measured_bytes += stream.data.size()
	if measured_bytes != _resident_sample_bytes:
		errors.append("resident sample byte accounting does not match the live bank")
	if lifecycle_active and _resident_sample_bytes != EXPECTED_RESIDENT_SAMPLE_BYTES:
		errors.append("resident stream bank does not match its deterministic byte total")
	if _resident_sample_bytes > RESIDENT_BYTE_BUDGET:
		errors.append("resident stream bank exceeds its fixed byte budget")

	var live_players := find_children("*", "AudioStreamPlayer", true, false)
	if live_players.size() != 1 + EFFECT_VOICE_COUNT or _effects.size() != EFFECT_VOICE_COUNT:
		errors.append("audio director must own one ambience and exactly four effect voices")
	if (
		not is_instance_valid(_ambience)
		or _ambience.bus != &"Ambience"
		or (lifecycle_active and not is_equal_approx(_ambience.pitch_scale, 1.0))
		or int(_player_instance_ids.get(&"Ambience", 0)) != _ambience.get_instance_id()
	):
		errors.append("ambience voice must retain its fixed routing and pitch")
	for index in _effects.size():
		var effect := _effects[index]
		if (
			not is_instance_valid(effect)
			or effect.name != "Effect%d" % index
			or effect.max_polyphony != 1
			or effect.bus not in [&"UI", &"Weapons", &"Ambience"]
			or int(_player_instance_ids.get(StringName(effect.name), 0)) != effect.get_instance_id()
		):
			errors.append("effect voice %d does not match its bounded routing contract" % index)

	var timers := _get_sequence_timers()
	if timers.size() != SEQUENCE_TIMER_COUNT:
		errors.append("audio director must own exactly three fixed sequence timers")
	for timer in timers:
		if (
			not is_instance_valid(timer)
			or not timer.one_shot
			or timer.autostart
			or timer.process_mode != Node.PROCESS_MODE_ALWAYS
			or timer.process_callback != Timer.TIMER_PROCESS_IDLE
			or int(_timer_instance_ids.get(StringName(timer.name), 0)) != timer.get_instance_id()
		):
			errors.append("sequence timer does not match its fixed scheduling contract")

	if not lifecycle_active or not _audio_enabled:
		if _effect_cursor != 0:
			errors.append("silent playback lifecycle must not advance the effect cursor")
		for player in live_players:
			if (player as AudioStreamPlayer).playing or (player as AudioStreamPlayer).stream != null:
				errors.append("silent playback lifecycle must keep every player stopped and detached")
		for timer in timers:
			if not timer.is_stopped():
				errors.append("silent playback lifecycle must not schedule sequence tails")
	elif _ambience.stream != _get_stream(STREAM_AMBIENCE):
		errors.append("active backend ambience handle must reference the resident loop")

	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"synthesis": get_synthesis_report(),
		"performance": get_performance_report(),
	}


func _on_semantic_cue(
	source_id: StringName,
	cue_id: StringName,
	intensity: float,
	world_position: Vector3
) -> void:
	semantic_cue_emitted.emit(source_id, cue_id, intensity, world_position)


func _play_resident(stream_id: StringName, bus: StringName, volume_db: float) -> bool:
	# Check the backend before even looking up a resource. In particular, Dummy
	# calls neither attach nor discard bank entries and leave the cursor stable.
	if not _can_mutate_runtime_state() or not _audio_enabled or _effects.is_empty():
		return false
	var stream := _get_stream(stream_id)
	if stream == null:
		return false
	var player := _effects[_effect_cursor]
	_effect_cursor = (_effect_cursor + 1) % _effects.size()
	player.stop()
	player.bus = bus
	player.volume_db = volume_db
	player.pitch_scale = 1.0
	player.stream = stream
	player.play()
	if not player.playing:
		player.stream = null
		return false
	return true


func _play_target_destroyed_tail() -> void:
	_play_resident(STREAM_TARGET_DESTROYED_TAIL, &"UI", -5.0)


func _play_combat_alert_tail() -> void:
	_play_resident(STREAM_COMBAT_ALERT_TAIL, &"UI", -4.0)


func _play_enemy_destroyed_tail() -> void:
	_play_resident(STREAM_ENEMY_DESTROYED_TAIL, &"Weapons", -2.0)


func _restart_sequence_timer(timer: Timer) -> void:
	if not _can_mutate_runtime_state() or not _audio_enabled or not is_instance_valid(timer):
		return
	timer.start()


func _release_finished_stream(player: AudioStreamPlayer) -> void:
	if not _shutting_down and is_instance_valid(player) and not player.playing:
		player.stream = null


func _restore_after_enter_tree() -> void:
	if not _initialized or is_queued_for_deletion() or not is_inside_tree():
		return
	_shutting_down = false
	_restore_fixed_hierarchy_configuration()
	_build_stream_bank()
	_restore_backend_state()


func _can_mutate_runtime_state() -> bool:
	return (
		_initialized
		and is_inside_tree()
		and not is_queued_for_deletion()
		and not _shutting_down
	)


func _restore_fixed_hierarchy_configuration() -> void:
	if is_instance_valid(_ambience):
		_ambience.name = "Ambience"
		_ambience.bus = &"Ambience"
		_ambience.max_polyphony = 1
		_ambience.pitch_scale = 1.0
		_ambience.stop()
		_ambience.stream = null
	for index in _effects.size():
		var effect := _effects[index]
		if not is_instance_valid(effect):
			continue
		effect.name = "Effect%d" % index
		effect.bus = &"UI"
		effect.max_polyphony = 1
		effect.pitch_scale = 1.0
		effect.stop()
		effect.stream = null
		var finished_callback := _release_finished_stream.bind(effect)
		if not effect.finished.is_connected(finished_callback):
			effect.finished.connect(finished_callback)
	_configure_sequence_timer(_target_destroyed_timer, 0.16, _play_target_destroyed_tail)
	_configure_sequence_timer(_combat_alert_timer, 0.34, _play_combat_alert_tail)
	_configure_sequence_timer(_enemy_destroyed_timer, 0.18, _play_enemy_destroyed_tail)
	_effect_cursor = 0
	_footstep_cooldown = 0.0


func _restore_backend_state() -> void:
	# Dummy owns the same deterministic resident bank for stable tests and
	# accounting, but it never receives a playback handle. Its mixer does not
	# advance, so attaching streams would pin needless playback state at exit.
	_audio_enabled = AudioServer.get_driver_name() != "Dummy"
	if not is_instance_valid(_ambience):
		return
	# Restore the requested gameplay mix before deciding whether the current
	# backend can play. This keeps detach/re-entry deterministic even under the
	# Dummy driver and prevents a real backend from reverting to the default
	# -13 dB while the player remains on foot or in a cockpit.
	_ambience.volume_db = _desired_ambience_volume_db
	if not _audio_enabled:
		return
	_ambience.stream = _get_stream(STREAM_AMBIENCE)
	_ambience.play()
	if not _ambience.playing:
		# A named backend can still reject playback. Fall back to the exact silent
		# lifecycle instead of retaining a stream handle that never became active.
		_audio_enabled = false
		_ambience.stream = null


func _configure_sequence_timer(timer: Timer, wait_time: float, callback: Callable) -> void:
	if not is_instance_valid(timer):
		return
	timer.stop()
	timer.process_mode = Node.PROCESS_MODE_ALWAYS
	timer.one_shot = true
	timer.autostart = false
	timer.process_callback = Timer.TIMER_PROCESS_IDLE
	timer.wait_time = wait_time
	if not timer.timeout.is_connected(callback):
		timer.timeout.connect(callback)


func _make_player(node_name: String, bus_name: StringName) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = node_name
	player.bus = bus_name
	player.max_polyphony = 1
	add_child(player)
	return player


func _make_sequence_timer(node_name: String, wait_time: float, callback: Callable) -> Timer:
	var timer := Timer.new()
	timer.name = node_name
	add_child(timer)
	_configure_sequence_timer(timer, wait_time, callback)
	_timer_instance_ids[StringName(node_name)] = timer.get_instance_id()
	return timer


func _get_sequence_timers() -> Array[Timer]:
	var timers: Array[Timer] = []
	if is_instance_valid(_target_destroyed_timer):
		timers.append(_target_destroyed_timer)
	if is_instance_valid(_combat_alert_timer):
		timers.append(_combat_alert_timer)
	if is_instance_valid(_enemy_destroyed_timer):
		timers.append(_enemy_destroyed_timer)
	return timers


func _get_stream(stream_id: StringName) -> AudioStreamWAV:
	return _stream_bank.get(stream_id) as AudioStreamWAV


func _build_stream_bank() -> void:
	if _resources_ready:
		return
	_add_stream(STREAM_AMBIENCE, _make_wave(2.4, 42.0, 0.12, 0.025, 2.0, true))
	_add_stream(STREAM_UI_CONFIRM, _make_wave(0.16, 430.0, 0.24, 0.0, 420.0))
	_add_stream(STREAM_IMPACT, _make_wave(0.32, 92.0, 0.38, 0.19, -48.0))
	_add_stream(
		STREAM_TARGET_DESTROYED_PRIMARY,
		_make_wave(0.8, 130.0, 0.33, 0.12, -95.0)
	)
	_add_stream(STREAM_TARGET_DESTROYED_TAIL, _make_wave(0.42, 610.0, 0.18, 0.0, 320.0))
	_add_stream(STREAM_COMBAT_ALERT_PRIMARY, _make_wave(0.28, 330.0, 0.22, 0.0, 120.0))
	_add_stream(STREAM_COMBAT_ALERT_TAIL, _make_wave(0.34, 510.0, 0.2, 0.0, -80.0))
	_add_stream(STREAM_CANOPY_OPEN, _make_wave(0.48, 118.0, 0.18, 0.06, 92.0))
	_add_stream(STREAM_CANOPY_CLOSE, _make_wave(0.48, 168.0, 0.18, 0.06, -96.0))
	_add_stream(
		STREAM_ENEMY_DESTROYED_PRIMARY,
		_make_wave(1.05, 82.0, 0.44, 0.34, -58.0)
	)
	_add_stream(STREAM_ENEMY_DESTROYED_TAIL, _make_wave(0.62, 245.0, 0.25, 0.18, -180.0))
	for index in FOOTSTEP_STREAM_IDS.size():
		var intensity := float(index) / float(FOOTSTEP_STREAM_IDS.size() - 1)
		_add_stream(
			FOOTSTEP_STREAM_IDS[index],
			_make_wave(0.09, 76.0, 0.14 + intensity * 0.05, 0.08, -22.0)
		)
	_bank_generation_count += 1
	_resources_ready = true


func _add_stream(stream_id: StringName, stream: AudioStreamWAV) -> void:
	_stream_bank[stream_id] = stream
	_stream_instance_ids[stream_id] = stream.get_instance_id()
	_resident_sample_bytes += stream.data.size()


func _make_wave(
	duration: float,
	frequency: float,
	volume: float,
	noise_amount: float = 0.0,
	sweep: float = 0.0,
	looped: bool = false
) -> AudioStreamWAV:
	_wave_synthesis_call_count += 1
	var sample_count := maxi(1, ceili(duration * SAMPLE_RATE))
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	var random := RandomNumberGenerator.new()
	random.seed = 19032009 + sample_count
	for index in sample_count:
		var time := float(index) / float(SAMPLE_RATE)
		var progress := time / maxf(duration, 0.001)
		var phase := TAU * (frequency * time + 0.5 * sweep * time * time)
		var harmonics := sin(phase) * 0.72 + sin(phase * 2.01) * 0.2 + sin(phase * 0.49) * 0.08
		var envelope := 1.0 if looped else sin(PI * clampf(progress, 0.0, 1.0))
		var noise := random.randf_range(-1.0, 1.0) * noise_amount
		var sample := clampf((harmonics * volume + noise) * envelope, -1.0, 1.0)
		bytes.encode_s16(index * 2, roundi(sample * 32767.0))

	var wave := AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	wave.mix_rate = SAMPLE_RATE
	wave.stereo = false
	wave.data = bytes
	if looped:
		wave.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wave.loop_begin = 0
		wave.loop_end = sample_count
	return wave
