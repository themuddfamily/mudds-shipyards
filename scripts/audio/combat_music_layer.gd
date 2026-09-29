class_name CombatMusicLayer
extends Node

## Adaptive combat music: three sample-locked stems and two stingers on the
## `Music` bus, driven by detached combat observations.
##
## States:
## - `calm`     no encounter is live; the layer is silent and the calm bed
##              (StationMusicBed) plays.
## - `engaged`  an encounter is live; the floor and drive stems cross-fade in
##              while the bed yields, and the lead stem joins against several
##              hostiles.
## - `victory` / `failure`
##              an encounter the layer saw engaged ended with that outcome; the
##              stems drop quickly under a one-shot stinger (the failure one is
##              authored subdued), then the layer holds before returning to
##              `calm`.
## - `release`  an encounter ended without an outcome (withdrawal, abort by
##              reset); the stems fade out slowly with no stinger.
##
## The layer strictly observes. `observe()` takes a CombatMusicObserver
## observation; `observe_sources()` reduces caller-owned snapshots through its
## own observer first. Nothing here reads or writes gameplay, combat, rewards,
## or phases, and the calm bed returns through its own recovery hold once the
## caller stops reporting combat to it.
##
## The checked-in stems and stingers are project-original fixed-seed offline
## synthesis (`tools/audio/generate_combat_music.py`). Whether they sound good
## is an outstanding human listening pass.

signal combat_music_state_changed(previous_state: StringName, state: StringName)
signal stinger_started(stinger_id: StringName)

const ObserverType := preload("res://scripts/audio/combat_music_observer.gd")

const COMPONENT_ID: StringName = &"combat-music-layer"
const AUDIO_BUS: StringName = &"Music"
const ASSET_DIRECTORY := "res://assets/audio/music"
const MANIFEST_PATH := ASSET_DIRECTORY + "/combat_music_v1_asset_manifest.json"

const STATE_CALM: StringName = &"calm"
const STATE_ENGAGED: StringName = &"engaged"
const STATE_VICTORY: StringName = &"victory"
const STATE_FAILURE: StringName = &"failure"
const STATE_RELEASE: StringName = &"release"
const STATES: Array[StringName] = [
	STATE_CALM, STATE_ENGAGED, STATE_VICTORY, STATE_FAILURE, STATE_RELEASE,
]

const STEM_FLOOR: StringName = &"floor"
const STEM_DRIVE: StringName = &"drive"
const STEM_LEAD: StringName = &"lead"
## Fixed declaration order for every roster walk.
const STEM_IDS: Array[StringName] = [STEM_FLOOR, STEM_DRIVE, STEM_LEAD]
const STEM_STREAM_PATHS := {
	STEM_FLOOR: ASSET_DIRECTORY + "/combat_stem_floor_v1.wav",
	STEM_DRIVE: ASSET_DIRECTORY + "/combat_stem_drive_v1.wav",
	STEM_LEAD: ASSET_DIRECTORY + "/combat_stem_lead_v1.wav",
}
const STEM_NODE_NAMES := {
	STEM_FLOOR: "CombatStemFloor",
	STEM_DRIVE: "CombatStemDrive",
	STEM_LEAD: "CombatStemLead",
}
## Per-stem trim on top of the authored asset headroom, matching the calm
## bed's -4..-8 dB layer trims so a cross-fade does not jump in level.
const STEM_VOLUME_DB := {
	STEM_FLOOR: -4.0,
	STEM_DRIVE: -5.0,
	STEM_LEAD: -7.0,
}
const STEM_LOOP_SECONDS := 10.0

const STINGER_VICTORY: StringName = &"victory"
const STINGER_FAILURE: StringName = &"failure"
const STINGER_STREAM_PATHS := {
	STINGER_VICTORY: ASSET_DIRECTORY + "/combat_stinger_victory_v1.wav",
	STINGER_FAILURE: ASSET_DIRECTORY + "/combat_stinger_failure_v1.wav",
}
## Authored one-shot lengths (see the manifest); the layer owns the stinger
## clock so its lifecycle is identical under every audio driver.
const STINGER_SECONDS := {STINGER_VICTORY: 4.5, STINGER_FAILURE: 5.5}
const STINGER_VOLUME_DB := -3.0
const STINGER_NODE_NAME := "CombatStinger"

## Engaged target gains. With nothing currently hostile (a defence lull) only
## a restrained floor and drive remain, so the lull still reads as combat.
const ENGAGED_TARGETS := {STEM_FLOOR: 1.0, STEM_DRIVE: 1.0, STEM_LEAD: 0.0}
const ENGAGED_HEAVY_TARGETS := {STEM_FLOOR: 1.0, STEM_DRIVE: 1.0, STEM_LEAD: 1.0}
const ENGAGED_LULL_TARGETS := {STEM_FLOOR: 0.6, STEM_DRIVE: 0.35, STEM_LEAD: 0.0}
const HEAVY_HOSTILE_COUNT := 2

## Linear gain units per second.
const FADE_IN_RATE_PER_SECOND := 0.6
const RELEASE_FADE_OUT_RATE_PER_SECOND := 0.4
const STINGER_DUCK_RATE_PER_SECOND := 1.4
## How long each ending holds before the layer reports `calm` again. The
## stinger lengths are 4.5 s and 5.5 s; the hold covers them.
const VICTORY_HOLD_SECONDS := 5.0
const FAILURE_HOLD_SECONDS := 6.0
const RELEASE_HOLD_SECONDS := 3.0
## Reduced dynamic range: tame the loudest moments rather than lifting quiet
## ones. The lead stem is capped and the stingers and drums come down.
const REDUCED_RANGE_LEAD_CAP := 0.6
const REDUCED_RANGE_DRIVE_TRIM_DB := -3.0
const REDUCED_RANGE_STINGER_TRIM_DB := -6.0
const MINIMUM_AUDIBLE_GAIN := 0.0005
const SAMPLE_INTERVAL_MSEC := 200

var _observer: CombatMusicObserver = ObserverType.new()
var _music_director: WeakRef
var _state: StringName = STATE_CALM
var _hold_remaining := 0.0
var _hostile_count := 0
var _last_outcome_serial := 0
var _gains: Dictionary = {}
var _targets: Dictionary = {}
var _stem_players: Dictionary = {}
var _stinger_player: AudioStreamPlayer
var _streams: Dictionary = {}
var _stingers: Dictionary = {}
var _stems_playing := false
var _stinger_id: StringName = &""
var _stinger_remaining := 0.0
var _loop_position_seconds := 0.0
var _muted := false
var _reduced_dynamic_range := false
var _audio_available := false
var _tearing_down := false
var _teardown_count := 0
var _state_change_count := 0
var _stinger_count := 0
var _next_sample_msec := 0


func _init() -> void:
	for stem_id in STEM_IDS:
		_gains[stem_id] = 0.0
		_targets[stem_id] = 0.0


func _ready() -> void:
	_ensure_players()


func _enter_tree() -> void:
	_tearing_down = false
	_audio_available = _backend_supports_playback()


func _exit_tree() -> void:
	# Whole-Main re-entry: drop every voice and all transient musical state.
	# The next observation after re-entry re-derives `engaged` from the live
	# snapshots, so nothing stale is resumed and nothing keeps sounding while
	# the subtree is detached.
	_tearing_down = true
	_teardown_count += 1
	_stop_all_players()
	_set_state(STATE_CALM)
	_hold_remaining = 0.0
	_hostile_count = 0
	_loop_position_seconds = 0.0
	for stem_id in STEM_IDS:
		_gains[stem_id] = 0.0
		_targets[stem_id] = 0.0


func _process(delta: float) -> void:
	advance(delta)


## Optional presentation link: the MusicDirector records the outcome cue. Held
## weakly, because the director belongs to the bed and may leave first.
func configure(music_director: Node) -> void:
	_music_director = weakref(music_director) if is_instance_valid(music_director) else null


## True at most every SAMPLE_INTERVAL_MSEC, so a per-frame caller only builds
## its detached snapshots a few times a second.
func is_sample_due() -> bool:
	var now := Time.get_ticks_msec()
	if now < _next_sample_msec:
		return false
	_next_sample_msec = now + SAMPLE_INTERVAL_MSEC
	return true


func observe_sources(sources: Dictionary) -> Dictionary:
	return observe(_observer.observe(sources))


## Applies one detached observation (see CombatMusicObserver.observe()).
func observe(observation: Dictionary) -> Dictionary:
	if _tearing_down or not is_inside_tree():
		return {"accepted": false, "reason": &"not_in_tree", "state": _state}
	var engaged := bool(observation.get("engaged", false))
	var outcome := StringName(observation.get("outcome", &""))
	var serial := int(observation.get("outcome_serial", 0))
	_hostile_count = maxi(0, int(observation.get("hostile_count", 0)))
	if outcome != &"" and serial > _last_outcome_serial:
		_last_outcome_serial = serial
		if outcome == ObserverType.OUTCOME_VICTORY:
			_begin_ending(STATE_VICTORY, STINGER_VICTORY, VICTORY_HOLD_SECONDS)
		elif outcome == ObserverType.OUTCOME_FAILURE:
			_begin_ending(STATE_FAILURE, STINGER_FAILURE, FAILURE_HOLD_SECONDS)
	if engaged:
		if _state != STATE_ENGAGED:
			if _state == STATE_CALM or not _stems_playing:
				_loop_position_seconds = 0.0
			_set_state(STATE_ENGAGED)
			_hold_remaining = 0.0
	elif _state == STATE_ENGAGED:
		_set_state(STATE_RELEASE)
		_hold_remaining = RELEASE_HOLD_SECONDS
	_resolve_targets()
	_apply_playback()
	return {"accepted": true, "state": _state, "presentation_only": true}


## Advances fades, the hold, and the shared stem clock. Public so tests can
## step it deterministically; `_process` calls it with the frame delta.
func advance(delta: float) -> void:
	if _tearing_down or not is_inside_tree() or not is_finite(delta) or delta <= 0.0:
		return
	if _state in [STATE_VICTORY, STATE_FAILURE, STATE_RELEASE]:
		_hold_remaining = maxf(0.0, _hold_remaining - delta)
		if _hold_remaining <= 0.0:
			_set_state(STATE_CALM)
			_resolve_targets()
	for stem_id in STEM_IDS:
		var gain := float(_gains[stem_id])
		var target := float(_targets[stem_id])
		if is_equal_approx(gain, target):
			_gains[stem_id] = target
			continue
		var rate := FADE_IN_RATE_PER_SECOND
		if target < gain:
			rate = STINGER_DUCK_RATE_PER_SECOND \
				if _state in [STATE_VICTORY, STATE_FAILURE] else RELEASE_FADE_OUT_RATE_PER_SECOND
		var step := rate * delta
		_gains[stem_id] = minf(target, gain + step) if target > gain else maxf(target, gain - step)
	if _any_stem_audible():
		_loop_position_seconds = fposmod(_loop_position_seconds + delta, STEM_LOOP_SECONDS)
	if _stinger_id != &"":
		_stinger_remaining = maxf(0.0, _stinger_remaining - delta)
		if _stinger_remaining <= 0.0:
			_release_stinger()
	_apply_playback()


## The calm bed should yield only while the fight is live; after an ending it
## returns through its own recovery hold under the stinger.
func is_holding_bed() -> bool:
	return _state == STATE_ENGAGED


func set_muted(muted: bool) -> void:
	if _muted == muted:
		return
	_muted = muted
	if _muted:
		_release_stinger()
		for stem_id in STEM_IDS:
			_gains[stem_id] = 0.0
	_resolve_targets()
	_apply_playback()


func is_muted() -> bool:
	return _muted


func set_reduced_dynamic_range(enabled: bool) -> void:
	if _reduced_dynamic_range == enabled:
		return
	_reduced_dynamic_range = enabled
	if is_instance_valid(_stinger_player) and _stinger_player.stream != null:
		_stinger_player.volume_db = _stinger_volume_db()
	_resolve_targets()
	_apply_playback()


func get_state() -> StringName:
	return _state


## Deep cleanup for tests and streamed unloads. Idempotent.
func release_audio_resources() -> void:
	_stop_all_players()
	_streams.clear()
	_stingers.clear()


func get_snapshot() -> Dictionary:
	var players := {}
	for stem_id in STEM_IDS:
		var player := _stem_player(stem_id)
		players[stem_id] = {
			"attached": player != null and player.stream != null,
			"volume_db": player.volume_db if player != null else 0.0,
			"bus": player.bus if player != null else &"",
		}
	return {
		"component_id": COMPONENT_ID,
		"state": _state,
		"hold_remaining_seconds": _hold_remaining,
		"hostile_count": _hostile_count,
		"stem_gains": _gains.duplicate(),
		"stem_targets": _targets.duplicate(),
		"stem_players": players,
		"stems_playing": _stems_playing,
		"stinger_id": _stinger_id,
		"stinger_attached": is_instance_valid(_stinger_player) and _stinger_player.stream != null,
		"stinger_volume_db": _stinger_player.volume_db if is_instance_valid(_stinger_player) else 0.0,
		"stinger_count": _stinger_count,
		"loop_position_seconds": _loop_position_seconds,
		"muted": _muted,
		"reduced_dynamic_range": _reduced_dynamic_range,
		"audio_available": _audio_available,
		"teardown_count": _teardown_count,
		"state_change_count": _state_change_count,
		"observer": _observer.get_snapshot(),
		"bus": AUDIO_BUS,
		"gameplay_authority": false,
		"presentation_only": true,
	}.duplicate(true)


# ------------------------------------------------------------- internals ----

func _begin_ending(state: StringName, stinger_id: StringName, hold_seconds: float) -> void:
	_set_state(state)
	_hold_remaining = hold_seconds
	_stinger_count += 1
	var director: Object = _music_director.get_ref() if _music_director != null else null
	if is_instance_valid(director) and director.has_method(&"observe_combat_outcome"):
		director.call(&"observe_combat_outcome", state)
	if _muted:
		return
	_start_stinger(stinger_id)


func _set_state(state: StringName) -> void:
	if state == _state:
		return
	var previous := _state
	_state = state
	_state_change_count += 1
	combat_music_state_changed.emit(previous, state)


func _resolve_targets() -> void:
	var table: Dictionary = {STEM_FLOOR: 0.0, STEM_DRIVE: 0.0, STEM_LEAD: 0.0}
	if _state == STATE_ENGAGED and not _muted:
		if _hostile_count <= 0:
			table = ENGAGED_LULL_TARGETS
		elif _hostile_count >= HEAVY_HOSTILE_COUNT:
			table = ENGAGED_HEAVY_TARGETS
		else:
			table = ENGAGED_TARGETS
	for stem_id in STEM_IDS:
		var target := float(table.get(stem_id, 0.0))
		if _reduced_dynamic_range and stem_id == STEM_LEAD:
			target = minf(target, REDUCED_RANGE_LEAD_CAP)
		_targets[stem_id] = target


func _any_stem_audible() -> bool:
	for stem_id in STEM_IDS:
		if float(_gains[stem_id]) >= MINIMUM_AUDIBLE_GAIN:
			return true
	return false


func _stem_volume_db(stem_id: StringName) -> float:
	var volume := float(STEM_VOLUME_DB[stem_id])
	if _reduced_dynamic_range and stem_id == STEM_DRIVE:
		volume += REDUCED_RANGE_DRIVE_TRIM_DB
	return volume


func _stinger_volume_db() -> float:
	return STINGER_VOLUME_DB + (REDUCED_RANGE_STINGER_TRIM_DB if _reduced_dynamic_range else 0.0)


## Stems start together and stop together so they stay sample-locked; a stem
## whose gain is zero keeps running silently while the others sound.
func _apply_playback() -> void:
	if _tearing_down or not is_inside_tree():
		return
	_ensure_players()
	var audible := _any_stem_audible() and not _muted
	if not audible:
		if _stems_playing:
			_stop_stems()
		return
	for stem_id in STEM_IDS:
		var player := _stem_player(stem_id)
		if player != null:
			player.volume_db = _stem_volume_db(stem_id) + linear_to_db(maxf(float(_gains[stem_id]), 1.0e-6))
	if _stems_playing or not _audio_available:
		# Dummy keeps the same envelope and clock for accounting but never
		# attaches a playback handle, exactly like StationMusicBed.
		_stems_playing = _stems_playing or not _audio_available
		return
	for stem_id in STEM_IDS:
		var player := _stem_player(stem_id)
		var stream := _stream(stem_id)
		if player == null or stream == null:
			continue
		player.stream = stream
		player.play(_loop_position_seconds)
		if not _request_playback(player):
			player.stop()
			player.stream = null
	_stems_playing = true


func _start_stinger(stinger_id: StringName) -> void:
	_ensure_players()
	_release_stinger()
	_stinger_id = stinger_id
	_stinger_remaining = float(STINGER_SECONDS[stinger_id])
	stinger_started.emit(stinger_id)
	if not is_instance_valid(_stinger_player) or not _audio_available:
		return
	var stream := _stinger_stream(stinger_id)
	if stream == null:
		return
	_stinger_player.stream = stream
	_stinger_player.volume_db = _stinger_volume_db()
	_stinger_player.play()
	if not _request_playback(_stinger_player):
		_stinger_player.stop()
		_stinger_player.stream = null


func _release_stinger() -> void:
	_stinger_id = &""
	_stinger_remaining = 0.0
	if is_instance_valid(_stinger_player):
		_stinger_player.stop()
		_stinger_player.stream = null


func _stop_stems() -> void:
	for stem_id in STEM_IDS:
		var player := _stem_player(stem_id)
		if player != null:
			player.stop()
			player.stream = null
	_stems_playing = false


func _stop_all_players() -> void:
	_stop_stems()
	_release_stinger()


func _ensure_players() -> void:
	for stem_id in STEM_IDS:
		if _stem_player(stem_id) == null:
			var player := AudioStreamPlayer.new()
			player.name = String(STEM_NODE_NAMES[stem_id])
			_configure_player(player)
			add_child(player)
			_stem_players[stem_id] = player
	if not is_instance_valid(_stinger_player):
		_stinger_player = AudioStreamPlayer.new()
		_stinger_player.name = STINGER_NODE_NAME
		_configure_player(_stinger_player)
		add_child(_stinger_player)


func _configure_player(player: AudioStreamPlayer) -> void:
	player.bus = AUDIO_BUS
	player.max_polyphony = 1
	player.autoplay = false


func _stem_player(stem_id: StringName) -> AudioStreamPlayer:
	var player := _stem_players.get(stem_id) as AudioStreamPlayer
	return player if is_instance_valid(player) else null


func _stream(stem_id: StringName) -> AudioStreamWAV:
	if not _streams.has(stem_id):
		var stream := load(String(STEM_STREAM_PATHS[stem_id])) as AudioStreamWAV
		if stream == null:
			return null
		_streams[stem_id] = stream
	return _streams[stem_id] as AudioStreamWAV


func _stinger_stream(stinger_id: StringName) -> AudioStreamWAV:
	if not _stingers.has(stinger_id):
		var stream := load(String(STINGER_STREAM_PATHS[stinger_id])) as AudioStreamWAV
		if stream == null:
			return null
		_stingers[stinger_id] = stream
	return _stingers[stinger_id] as AudioStreamWAV


## Backend capability seam, the same one StationMusicBed exposes: Dummy never
## attaches a voice, and tests override this to exercise the attach path.
func _backend_supports_playback() -> bool:
	return AudioServer.get_driver_name() != "Dummy"


func _request_playback(player: AudioStreamPlayer) -> bool:
	return player.playing
