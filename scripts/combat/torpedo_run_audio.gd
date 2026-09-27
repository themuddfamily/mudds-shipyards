class_name TorpedoRunAudio
extends Node3D

## Presentation-only positional voice bank for seeker torpedoes.
##
## Owned by one SeekerTorpedoProjectile pool (and so by one launcher). The pool
## reports launch, flight, intercept, detonation, expiry and abandonment; the
## launcher reports its lock posture. This bank turns those edges into
## the Torpedo Run's own cues from the authored bank in
## `assets/audio/combat/torpedo_run/`:
##
##   * launch       - rising ignition hiss at the tube
##   * seeker lock  - one lime pip per closing lock-bracket step, rising in pitch
##   * flight loop  - a motor drone that rides each live torpedo (one voice per
##                    pool slot, so the voice count is bounded by the pool)
##   * intercept    - bright crackling pop where a torpedo was shot down
##   * detonation   - heavy warhead boom where a torpedo hit or fused
##
## It layers over the shared CombatAudioPresentation tube-kick and hull-impact
## cues the launcher already plays; it decides nothing about fire, damage or
## lock. Every edge is fenced by a (bank generation, flight id) key so a
## repeated signal cannot replay a cue, and leaving the tree stops every voice
## and advances the generation. Under the Dummy driver the cues are counted and
## emitted semantically but no stream is handed to the audio server.
##
## Evidence status: modern_interpretation.

signal cue_started(cue_id: StringName, world_position: Vector3, flight_id: int)
signal semantic_cue_emitted(cue_id: StringName, world_position: Vector3, intensity: float)

const COMPONENT_ID: StringName = &"torpedo-run-audio"
const CUE_LAUNCH: StringName = &"torpedo_launch"
const CUE_LOCK: StringName = &"torpedo_seeker_lock"
const CUE_FLIGHT: StringName = &"torpedo_flight_loop"
const CUE_INTERCEPT: StringName = &"torpedo_intercept"
const CUE_DETONATION: StringName = &"torpedo_detonation"
## Semantic-only: a torpedo that ran out of fuel or range without hitting.
const CUE_EXPIRED: StringName = &"torpedo_expired"

const STREAM_DIRECTORY := "res://assets/audio/combat/torpedo_run/"
const STREAM_PATHS := {
	CUE_LAUNCH: STREAM_DIRECTORY + "torpedo_launch_v1.wav",
	CUE_LOCK: STREAM_DIRECTORY + "torpedo_seeker_lock_v1.wav",
	CUE_FLIGHT: STREAM_DIRECTORY + "torpedo_flight_loop_v1.wav",
	CUE_INTERCEPT: STREAM_DIRECTORY + "torpedo_intercept_v1.wav",
	CUE_DETONATION: STREAM_DIRECTORY + "torpedo_detonation_v1.wav",
}
const CUE_VOLUME_DB := {
	CUE_LAUNCH: -2.0,
	CUE_LOCK: -3.0,
	CUE_FLIGHT: -9.0,
	CUE_INTERCEPT: -1.0,
	CUE_DETONATION: 0.0,
}
## Pitch per lock-bracket step (three steps, rising a major third each).
const LOCK_STEP_PITCH := [1.0, 1.26, 1.59]
const POSTURE_LOCKING: StringName = &"locking"

const MAX_FLIGHT_VOICES := 4
const ONE_SHOT_VOICES := 3
const MAXIMUM_DISTANCE := 220.0
const REFERENCE_DISTANCE := 6.0
const BUS: StringName = &"Weapons"
const MAX_SEEN_KEYS := 48

## Set by the owning pool before the bank enters the tree.
var flight_voice_count := 2

var _built := false
var _audio_available := false
var _generation := 1
var _streams: Dictionary = {}
var _flight_voices: Array[AudioStreamPlayer3D] = []
var _one_shot_voices: Array[AudioStreamPlayer3D] = []
var _lock_voice: AudioStreamPlayer3D
var _one_shot_cursor := 0
## flight id -> flight voice index, for the flights currently carrying a loop.
var _flight_voice_by_flight: Dictionary = {}
var _seen: Dictionary = {}
var _seen_order: Array[String] = []
var _cue_counts: Dictionary = {}
var _last_cue_id: StringName = &""
var _last_cue_pitch := 1.0
var _lock_activation_generation := -1
var _lock_posture: StringName = &""
var _lock_step := -1


func _enter_tree() -> void:
	_audio_available = AudioServer.get_driver_name() != "Dummy"


func _ready() -> void:
	_build()


func _exit_tree() -> void:
	stop_all()
	_generation += 1
	_reset_lock_state()


# ------------------------------------------------------------ pool edges ----

## A torpedo left the tube: ignition one-shot at its origin, then a flight loop
## on a free slot voice that [method follow_flight] keeps on the torpedo.
func present_launch(record: Dictionary) -> bool:
	var flight_id := int(record.get("flight_id", 0))
	var origin := record.get("origin", Vector3.INF) as Vector3
	if flight_id <= 0 or not origin.is_finite() or not _can_present():
		return false
	if not _claim("%d:%d:launch" % [_generation, flight_id]):
		return false
	_play_one_shot(CUE_LAUNCH, origin, 1.0, flight_id)
	_start_flight_loop(flight_id, origin)
	return true


func follow_flight(flight_id: int, world_position: Vector3) -> void:
	if not _flight_voice_by_flight.has(flight_id) or not world_position.is_finite():
		return
	var voice := _flight_voices[int(_flight_voice_by_flight[flight_id])]
	if is_instance_valid(voice):
		voice.global_position = world_position


## A player shot destroyed the torpedo in flight.
func present_intercept(record: Dictionary) -> bool:
	return _present_terminal(record, CUE_INTERCEPT, record.get("position", Vector3.INF) as Vector3)


## The warhead committed an arrival: a hit or a proximity fuse detonates, a
## flown-out torpedo only goes quiet.
func present_resolved(record: Dictionary, result: Dictionary) -> bool:
	var reason := StringName(record.get("terminal_reason", &""))
	var detonated := bool(result.get("damaged", false)) or reason == &"proximity_fuse"
	return _present_terminal(
		record,
		CUE_DETONATION if detonated else CUE_EXPIRED,
		record.get("terminal_position", record.get("position", Vector3.INF)) as Vector3
	)


## The flight was dropped without an arrival (stand-down, launcher lost, tree
## exit): its loop stops and nothing else plays; the launcher's own
## destruction cue covers a killed boat.
func present_abandoned(record: Dictionary) -> void:
	_stop_flight_loop(int(record.get("flight_id", 0)))


# ------------------------------------------------------------ lock edges ----

## One pip per lock step while the launcher's brackets close. Any other posture
## re-arms the sequence so the next lock is voiced from its first step; a new
## activation generation re-arms it too.
func present_lock_posture(
		posture: StringName,
		step: int,
		world_position: Vector3,
		activation_generation: int
	) -> bool:
	if activation_generation != _lock_activation_generation:
		_reset_lock_state()
		_lock_activation_generation = activation_generation
	if posture != POSTURE_LOCKING:
		_lock_posture = posture
		_lock_step = -1
		return false
	if _lock_posture == POSTURE_LOCKING and step == _lock_step:
		return false
	_lock_posture = posture
	_lock_step = step
	if step < 0 or not world_position.is_finite() or not _can_present():
		return false
	var pitch := float(LOCK_STEP_PITCH[clampi(step, 0, LOCK_STEP_PITCH.size() - 1)])
	_play_on(_lock_voice, CUE_LOCK, world_position, pitch, 0)
	return true


# ------------------------------------------------------------- lifecycle ----

func stop_all() -> void:
	for voice in _flight_voices:
		_silence(voice)
	for voice in _one_shot_voices:
		_silence(voice)
	_silence(_lock_voice)
	_flight_voice_by_flight.clear()


func get_component_id() -> StringName:
	return COMPONENT_ID


func get_snapshot() -> Dictionary:
	var playing := PackedStringArray()
	for voice in _all_voices():
		if is_instance_valid(voice) and voice.playing:
			playing.append(String(voice.name))
	return {
		"component_id": COMPONENT_ID,
		"generation": _generation,
		"audio_available": _audio_available,
		"flight_voice_count": _flight_voices.size(),
		"one_shot_voice_count": _one_shot_voices.size(),
		"voice_count": _all_voices().size(),
		"maximum_voices": MAX_FLIGHT_VOICES + ONE_SHOT_VOICES + 1,
		"active_flight_loops": _flight_voice_by_flight.size(),
		"cue_counts": _cue_counts.duplicate(true),
		"last_cue_id": _last_cue_id,
		"last_cue_pitch": _last_cue_pitch,
		"playing_voices": playing,
		"presentation_only": true,
		"fire_authority": false,
		"damage_authority": false,
	}.duplicate(true)


# -------------------------------------------------------------- internals ----

func _can_present() -> bool:
	return _built and is_inside_tree() and not is_queued_for_deletion()


func _present_terminal(record: Dictionary, cue_id: StringName, world_position: Vector3) -> bool:
	var flight_id := int(record.get("flight_id", 0))
	if flight_id <= 0:
		return false
	_stop_flight_loop(flight_id)
	if not world_position.is_finite() or not _can_present():
		return false
	if not _claim("%d:%d:terminal" % [_generation, flight_id]):
		return false
	if cue_id == CUE_EXPIRED:
		_count(cue_id, 1.0)
		semantic_cue_emitted.emit(cue_id, world_position, 0.2)
		return true
	_play_one_shot(cue_id, world_position, 1.0, flight_id)
	return true


func _start_flight_loop(flight_id: int, world_position: Vector3) -> void:
	for index in _flight_voices.size():
		if _flight_voice_by_flight.values().has(index):
			continue
		_flight_voice_by_flight[flight_id] = index
		_play_on(_flight_voices[index], CUE_FLIGHT, world_position, 1.0, flight_id)
		return


func _stop_flight_loop(flight_id: int) -> void:
	if not _flight_voice_by_flight.has(flight_id):
		return
	var index := int(_flight_voice_by_flight[flight_id])
	_flight_voice_by_flight.erase(flight_id)
	if index >= 0 and index < _flight_voices.size():
		_silence(_flight_voices[index])


func _play_one_shot(cue_id: StringName, world_position: Vector3, pitch: float, flight_id: int) -> void:
	if _one_shot_voices.is_empty():
		return
	var voice := _one_shot_voices[_one_shot_cursor % _one_shot_voices.size()]
	_one_shot_cursor = (_one_shot_cursor + 1) % _one_shot_voices.size()
	_play_on(voice, cue_id, world_position, pitch, flight_id)


func _play_on(
		voice: AudioStreamPlayer3D,
		cue_id: StringName,
		world_position: Vector3,
		pitch: float,
		flight_id: int
	) -> void:
	if not is_instance_valid(voice):
		return
	var stream := _streams.get(cue_id) as AudioStream
	if stream == null:
		return
	_count(cue_id, pitch)
	# Dummy has no output device: keep the cue edge, skip the native queue.
	if _audio_available:
		voice.stop()
		voice.global_position = world_position
		voice.stream = stream
		voice.volume_db = float(CUE_VOLUME_DB.get(cue_id, -3.0))
		voice.pitch_scale = pitch
		voice.play()
	cue_started.emit(cue_id, world_position, flight_id)
	semantic_cue_emitted.emit(cue_id, world_position, 1.0)


func _count(cue_id: StringName, pitch: float) -> void:
	_cue_counts[cue_id] = int(_cue_counts.get(cue_id, 0)) + 1
	_last_cue_id = cue_id
	_last_cue_pitch = pitch


func _claim(key: String) -> bool:
	if _seen.has(key):
		return false
	_seen[key] = true
	_seen_order.append(key)
	while _seen_order.size() > MAX_SEEN_KEYS:
		_seen.erase(_seen_order.pop_front())
	return true


func _silence(voice: AudioStreamPlayer3D) -> void:
	if is_instance_valid(voice):
		voice.stop()
		voice.stream = null


func _reset_lock_state() -> void:
	_lock_activation_generation = -1
	_lock_posture = &""
	_lock_step = -1


func _all_voices() -> Array[AudioStreamPlayer3D]:
	var voices: Array[AudioStreamPlayer3D] = []
	voices.append_array(_flight_voices)
	voices.append_array(_one_shot_voices)
	if is_instance_valid(_lock_voice):
		voices.append(_lock_voice)
	return voices


func _build() -> void:
	if _built:
		return
	_built = true
	for cue_id in STREAM_PATHS:
		_streams[cue_id] = load(STREAM_PATHS[cue_id]) as AudioStream
	for index in clampi(flight_voice_count, 1, MAX_FLIGHT_VOICES):
		_flight_voices.append(_make_voice("FlightVoice%d" % index))
	for index in ONE_SHOT_VOICES:
		_one_shot_voices.append(_make_voice("CueVoice%d" % index))
	_lock_voice = _make_voice("LockVoice")
	set_meta(&"presentation_only", true)
	set_meta(&"gameplay_authority", false)


func _make_voice(voice_name: String) -> AudioStreamPlayer3D:
	var voice := AudioStreamPlayer3D.new()
	voice.name = voice_name
	# World-space: a torpedo in flight is not attached to its launcher.
	voice.top_level = true
	voice.bus = BUS
	voice.max_polyphony = 1
	voice.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	voice.unit_size = REFERENCE_DISTANCE
	voice.max_distance = MAXIMUM_DISTANCE
	voice.area_mask = 0
	voice.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
	add_child(voice)
	return voice
