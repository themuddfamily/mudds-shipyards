class_name CombatAudioPresentation
extends Node3D

## Fixed, presentation-only world-space voice pool for authored combat cues.
## Combat authority remains entirely in LiveCombatAuthority/CombatResolver.

signal cue_started(
	cue_id: StringName,
	voice_name: StringName,
	world_position: Vector3,
	source_instance_id: int
)
signal semantic_cue_emitted(cue_id: StringName, world_position: Vector3, intensity: float)

const SCHEMA_VERSION := 1
const COMPONENT_ID: StringName = &"combat-audio-presentation"
const CUE_PLAYER_FIRE: StringName = &"player_pulse_fire"
const CUE_DEFENDER_FIRE: StringName = &"defender_pulse_fire"
const CUE_DRY_FIRE: StringName = &"dry_fire_click"
const CUE_IMPACT_LIGHT: StringName = &"hull_impact_light"
const CUE_IMPACT_MEDIUM: StringName = &"hull_impact_medium"
const CUE_IMPACT_HEAVY: StringName = &"hull_impact_heavy"
const CUE_EXPLOSION: StringName = &"ship_explosion"

const STREAM_PATHS := {
	CUE_PLAYER_FIRE: "res://assets/audio/combat/player_pulse_fire_v1.wav",
	CUE_DEFENDER_FIRE: "res://assets/audio/combat/defender_pulse_fire_v1.wav",
	CUE_DRY_FIRE: "res://assets/audio/combat/dry_fire_click_v1.wav",
	CUE_IMPACT_LIGHT: "res://assets/audio/combat/hull_impact_light_v1.wav",
	CUE_IMPACT_MEDIUM: "res://assets/audio/combat/hull_impact_medium_v1.wav",
	CUE_IMPACT_HEAVY: "res://assets/audio/combat/hull_impact_heavy_v1.wav",
	CUE_EXPLOSION: "res://assets/audio/combat/ship_explosion_v1.wav",
}
const STREAM_DATA_SHA256 := {
	CUE_PLAYER_FIRE: "9f60152d7818ee93ff2891242f6c85613e33e1b118ec42bdc8ef345bee6fa604",
	CUE_DEFENDER_FIRE: "649b9541991493acb291af759cc91585272157c2c1f771fe22cded29939a8293",
	CUE_DRY_FIRE: "f0088282a085f7f4cf00ce60f400e25237400bd505144f22a81a2eb2fd7ff379",
	CUE_IMPACT_LIGHT: "603a6690fd6c626fc50c6b6feb185fe825a34994bc3d6bc90b83c24e31fca6be",
	CUE_IMPACT_MEDIUM: "97426964c26a944ecfe4560fae77ef48249bd67a822e818be1d2f462f2bb964d",
	CUE_IMPACT_HEAVY: "a1f8a7086dbcdd0a8b50bb5dc3a57087ff443a19e8778359c53da22d61329abe",
	CUE_EXPLOSION: "781ce35adde174e6160d4555083446c6821431d8ec132ed57ce595c556f4eb03",
}
const POOL_PATHS := {
	&"fire": [^"FireVoice0", ^"FireVoice1", ^"FireVoice2"],
	&"impact": [^"ImpactVoice0", ^"ImpactVoice1", ^"ImpactVoice2", ^"ImpactVoice3"],
	&"explosion": [^"ExplosionVoice0", ^"ExplosionVoice1"],
	&"dry": [^"DryFireVoice"],
}
const POOL_COUNTS := {&"fire": 3, &"impact": 4, &"explosion": 2, &"dry": 1}
const EXPECTED_VOICE_COUNT := 10
const MAXIMUM_DISTANCE := 220.0
const REFERENCE_DISTANCE := 5.0

var _streams: Dictionary = {}
var _stream_ids: Dictionary = {}
var _pools: Dictionary = {}
var _pool_cursors: Dictionary = {&"fire": 0, &"impact": 0, &"explosion": 0, &"dry": 0}
var _voice_ids: Dictionary = {}
var _cue_count := 0
var _cue_counts: Dictionary = {}
var _last_cue_id: StringName = &""
var _last_world_position := Vector3.ZERO
var _last_source_instance_id := 0
var _last_cue_pitch_scale := 1.0
var _last_cue_volume_db := -80.0
var _occlusion := 0.0
var _last_semantic_intensity := 0.0
var _target_lock_active := false
var _target_lock_position := Vector3.ZERO
var _weapon_ready_announced := true
var _initialized := false
var _audio_available := true


func _enter_tree() -> void:
	_audio_available = AudioServer.get_driver_name() != "Dummy"
	if _initialized:
		call_deferred("_restore_players_after_reentry")


func _ready() -> void:
	if _initialized:
		_restore_players_after_reentry()
		return
	_initialized = true
	_audio_available = AudioServer.get_driver_name() != "Dummy"
	for cue_id in STREAM_PATHS:
		var stream := load(STREAM_PATHS[cue_id]) as AudioStreamWAV
		_streams[cue_id] = stream
		if stream != null:
			_stream_ids[cue_id] = stream.get_instance_id()
	for pool_id in POOL_PATHS:
		var voices: Array[AudioStreamPlayer3D] = []
		for path: NodePath in POOL_PATHS[pool_id]:
			var player := get_node_or_null(path) as AudioStreamPlayer3D
			if player != null:
				_configure_player(player)
				voices.append(player)
				_voice_ids[player.name] = player.get_instance_id()
		_pools[pool_id] = voices
	set_meta(&"presentation_only", true)
	set_meta(&"gameplay_authority", false)
	set_meta(&"authorship", &"project_original_authored_audio")
	add_to_group(&"combat_audio_presentation", false)


func _exit_tree() -> void:
	_stop_all_players()


func play_player_fire(world_position: Vector3, source_instance_id: int) -> bool:
	var accepted := _play(CUE_PLAYER_FIRE, &"fire", world_position, source_instance_id, 0.0, 1.0)
	if not _weapon_ready_announced:
		semantic_cue_emitted.emit(&"weapon_ready", world_position, 1.0)
		_weapon_ready_announced = true
	return accepted


func play_defender_fire(world_position: Vector3, source_instance_id: int) -> bool:
	return _play(CUE_DEFENDER_FIRE, &"fire", world_position, source_instance_id, -1.0, 1.0)


func play_dry_fire(world_position: Vector3, source_instance_id: int) -> bool:
	var accepted := _play(CUE_DRY_FIRE, &"dry", world_position, source_instance_id, -7.0)
	if _weapon_ready_announced:
		semantic_cue_emitted.emit(&"weapon_not_ready", world_position, 1.0)
		_weapon_ready_announced = false
	return accepted


func play_impact(world_position: Vector3, intensity: float, source_instance_id: int) -> bool:
	if not is_finite(intensity) or intensity < 0.0:
		return false
	var severity := clampf(intensity, 0.0, 1.5) / 1.5
	var cue_id := CUE_IMPACT_LIGHT
	if intensity >= 1.2:
		cue_id = CUE_IMPACT_HEAVY
	elif intensity >= 0.65:
		cue_id = CUE_IMPACT_MEDIUM
	var volume_db := lerpf(-5.0, -1.0, severity)
	var pitch_scale := lerpf(1.08, 0.88, severity)
	return _play(cue_id, &"impact", world_position, source_instance_id, volume_db, pitch_scale, severity)


func play_explosion(world_position: Vector3, source_instance_id: int) -> bool:
	return _play(CUE_EXPLOSION, &"explosion", world_position, source_instance_id, 1.0, 1.0, 1.0)


## Records caller-owned interior occlusion. Zero is exterior; one is fully
## occluded. This presentation control never samples geometry or owns routing.
func set_occlusion(occlusion: float) -> bool:
	if is_queued_for_deletion() or not is_finite(occlusion) \
			or occlusion < 0.0 or occlusion > 1.0:
		return false
	_occlusion = occlusion
	return true


func get_occlusion() -> float:
	return _occlusion


## Records caller-owned target-lock presentation state without selecting a target
## or reading combat authority. Semantic edges are emitted once per transition.
func set_target_lock(active: bool, world_position: Vector3 = Vector3.ZERO) -> bool:
	if is_queued_for_deletion() or not world_position.is_finite():
		return false
	if _target_lock_active == active:
		_target_lock_position = world_position
		return true
	_target_lock_active = active
	_target_lock_position = world_position
	semantic_cue_emitted.emit(
		&"target_lock_acquired" if active else &"target_lock_lost",
		world_position,
		1.0 if active else 0.0
	)
	return true


func is_target_lock_active() -> bool:
	return _target_lock_active


func get_component_id() -> StringName:
	return COMPONENT_ID


func get_state_snapshot() -> Dictionary:
	var active_voices := PackedStringArray()
	for pool_value in _pools.values():
		for player: AudioStreamPlayer3D in pool_value:
			if is_instance_valid(player) and player.playing:
				active_voices.append(String(player.name))
	return {
		"schema_version": SCHEMA_VERSION,
		"cue_count": _cue_count,
		"cue_counts": _cue_counts.duplicate(true),
		"last_cue_id": _last_cue_id,
		"last_world_position": _last_world_position,
		"last_source_instance_id": _last_source_instance_id,
		"last_cue_pitch_scale": _last_cue_pitch_scale,
		"last_cue_volume_db": _last_cue_volume_db,
		"occlusion": _occlusion,
		"last_semantic_intensity": _last_semantic_intensity,
		"active_voice_names": active_voices,
		"voice_count": _voice_ids.size(),
	}.duplicate(true)


func get_audit_report() -> Dictionary:
	var errors := PackedStringArray()
	if not is_in_group(&"combat_audio_presentation"):
		errors.append("missing combat-audio discovery group")
	if get_meta(&"presentation_only", false) != true or get_meta(&"gameplay_authority", true) != false:
		errors.append("presentation authority metadata drifted")
	if get_meta(&"authorship", &"") != &"project_original_authored_audio":
		errors.append("authored-audio provenance drifted")
	if _streams.size() != STREAM_PATHS.size():
		errors.append("authored stream roster is incomplete")
	var descendants := find_children("*", "Node", true, false)
	if descendants.size() != EXPECTED_VOICE_COUNT:
		errors.append("combat audio descendant roster drifted")
	for cue_id in STREAM_PATHS:
		var stream := _streams.get(cue_id) as AudioStreamWAV
		if (
			stream == null
			or stream.get_instance_id() != int(_stream_ids.get(cue_id, 0))
			or stream.resource_path != STREAM_PATHS[cue_id]
			or stream.mix_rate != 48_000
			or stream.stereo
			or stream.format != AudioStreamWAV.FORMAT_16_BITS
			or stream.loop_mode != AudioStreamWAV.LOOP_DISABLED
			or _hash_bytes(stream.data) != String(STREAM_DATA_SHA256.get(cue_id, ""))
		):
			errors.append("authored stream contract drifted: %s" % String(cue_id))
	var live_voice_count := find_children("*", "AudioStreamPlayer3D", true, false).size()
	if live_voice_count != EXPECTED_VOICE_COUNT or _voice_ids.size() != EXPECTED_VOICE_COUNT:
		errors.append("fixed voice roster drifted")
	for pool_id in POOL_COUNTS:
		var pool := _get_pool(pool_id)
		if pool.size() != int(POOL_COUNTS[pool_id]):
			errors.append("voice-pool count drifted: %s" % String(pool_id))
		for player in pool:
			if (
				not is_instance_valid(player)
				or player.get_parent() != self
				or player.get_instance_id() != int(_voice_ids.get(player.name, 0))
				or player.get_script() != null
				or player.process_mode != Node.PROCESS_MODE_INHERIT
				or player.bus != &"Weapons"
				or not player.top_level
				or not is_equal_approx(player.max_distance, MAXIMUM_DISTANCE)
				or not is_equal_approx(player.unit_size, REFERENCE_DISTANCE)
				or player.max_polyphony != 1
			):
				errors.append("voice identity or spatial mix drifted: %s" % String(player.name))
	if not find_children("*", "CollisionObject3D", true, false).is_empty():
		errors.append("combat audio presentation contains gameplay collision")
	if not find_children("*", "AudioStreamPlayer", true, false).is_empty():
		errors.append("combat audio must remain world-space positional")
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"component_id": COMPONENT_ID,
		"authorship": &"project_original_authored_audio",
		"historically_supported": false,
		"presentation_only": true,
		"gameplay_authority": false,
		"sample_rate_hz": 48_000,
		"stream_count": _streams.size(),
		"voice_count": live_voice_count,
		"pool_counts": POOL_COUNTS.duplicate(true),
		"maximum_simultaneous_voices": EXPECTED_VOICE_COUNT,
		"maximum_distance": MAXIMUM_DISTANCE,
		"reference_distance": REFERENCE_DISTANCE,
	}.duplicate(true)


func _play(
		cue_id: StringName,
		pool_id: StringName,
		world_position: Vector3,
		source_instance_id: int,
		volume_db: float
		, pitch_scale: float = 1.0, semantic_intensity: float = 1.0
	) -> bool:
	if is_queued_for_deletion() or not is_inside_tree() \
			or not world_position.is_finite() or source_instance_id < 0:
		return false
	var stream := _streams.get(cue_id) as AudioStreamWAV
	var pool := _get_pool(pool_id)
	if (
		stream == null
		or pool.is_empty()
		or _hash_bytes(stream.data) != String(STREAM_DATA_SHA256.get(cue_id, ""))
	):
		return false
	var cursor := int(_pool_cursors.get(pool_id, 0)) % pool.size()
	var player := pool[cursor] as AudioStreamPlayer3D
	if (
		not is_instance_valid(player)
		or player.get_parent() != self
		or player.get_instance_id() != int(_voice_ids.get(player.name, 0))
		or player.get_script() != null
		or player.bus != &"Weapons"
		or not player.top_level
		or not is_equal_approx(player.max_distance, MAXIMUM_DISTANCE)
		or not is_equal_approx(player.unit_size, REFERENCE_DISTANCE)
	):
		return false
	player.stop()
	player.global_position = world_position
	player.stream = stream
	var occluded_volume_db := volume_db - 12.0 * _occlusion
	var occluded_pitch_scale := pitch_scale * lerpf(1.0, 0.96, _occlusion)
	player.volume_db = occluded_volume_db
	player.pitch_scale = occluded_pitch_scale
	player.play()
	if not _request_player_playback(player):
		_stop_and_detach_player(player)
		return false
	_pool_cursors[pool_id] = (cursor + 1) % pool.size()
	_cue_count += 1
	_cue_counts[cue_id] = int(_cue_counts.get(cue_id, 0)) + 1
	_last_cue_id = cue_id
	_last_world_position = world_position
	_last_source_instance_id = source_instance_id
	_last_cue_pitch_scale = occluded_pitch_scale
	_last_cue_volume_db = occluded_volume_db
	_last_semantic_intensity = clampf(semantic_intensity, 0.0, 1.0)
	cue_started.emit(cue_id, StringName(player.name), world_position, source_instance_id)
	semantic_cue_emitted.emit(cue_id, world_position, _last_semantic_intensity)
	return true


func _get_pool(pool_id: StringName) -> Array[AudioStreamPlayer3D]:
	var typed_pool: Array[AudioStreamPlayer3D] = []
	var raw_pool: Variant = _pools.get(pool_id, null)
	if raw_pool == null:
		return typed_pool
	if raw_pool is Array:
		for candidate in raw_pool:
			if candidate is AudioStreamPlayer3D:
				typed_pool.append(candidate)
	return typed_pool


func _request_player_playback(player: AudioStreamPlayer3D) -> bool:
	if not _audio_available:
		return true
	return player.playing


func _stop_and_detach_player(player: AudioStreamPlayer3D) -> void:
	if is_instance_valid(player):
		player.stop()
		player.stream = null
		player.pitch_scale = 1.0


func _configure_player(player: AudioStreamPlayer3D) -> void:
	player.top_level = true
	player.bus = &"Weapons"
	player.max_polyphony = 1
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	player.unit_size = REFERENCE_DISTANCE
	player.max_distance = MAXIMUM_DISTANCE
	player.max_db = -1.0
	player.area_mask = 0
	player.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
	if not player.finished.is_connected(_on_player_finished.bind(player)):
		player.finished.connect(_on_player_finished.bind(player))


func _on_player_finished(player: AudioStreamPlayer3D) -> void:
	if is_instance_valid(player) and not player.playing:
		player.stream = null


func _stop_all_players() -> void:
	for pool_value in _pools.values():
		for player: AudioStreamPlayer3D in pool_value:
			if is_instance_valid(player):
				_stop_and_detach_player(player)


func _restore_players_after_reentry() -> void:
	if is_queued_for_deletion() or not is_inside_tree():
		return
	for pool_value in _pools.values():
		for player: AudioStreamPlayer3D in pool_value:
			if is_instance_valid(player):
				_configure_player(player)
	_stop_all_players()


func _hash_bytes(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	context.update(bytes)
	return context.finish().hex_encode()
