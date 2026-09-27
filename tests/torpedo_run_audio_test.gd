extends SceneTree

## Torpedo Run audio: launch, lock pips, flight loop, hit, intercept and the
## board's armed/cleared/failed tones.
##
## Runs under the Dummy driver (as every automated run must), so this proves the
## cue edges, the generation fences, the bounded voice bank and lifecycle
## cleanup; it does not claim anything about how the cues sound.

const TorpedoPoolScript := preload("res://scripts/combat/seeker_torpedo_projectile.gd")
const BoardAudioBinding := preload("res://scripts/audio/heavy_breach_activity_board_audio_binding.gd")
const BoardScript := preload("res://scripts/activities/heavy_breach_activity_board.gd")
const Layers := preload("res://scripts/core/physics_layers.gd")

const LAUNCHER_ID := 9701
const GUN_ID := 9702
const LAUNCHER_FACTION: StringName = &"range_defence"
const PLAYER_FACTION: StringName = &"shipyard_flight_test"
const WEAPON_ID: StringName = &"torpedo_boat_seeker"
const GUN_WEAPON_ID: StringName = &"test_fleet_gun"
const TORPEDO_PROFILE := {
	WEAPON_ID: {
		"range": 250.0,
		"damage": 34.0,
		"origin_tolerance": 14.0,
		"projectile_speed": 34.0,
		"projectile_lifetime": 7.5,
		"projectile_radius": 0.6,
	},
}
const GUN_PROFILE := {GUN_WEAPON_ID: {"range": 400.0, "damage": 18.0, "origin_tolerance": 6.0}}

var _assertions := 0
var _failures: PackedStringArray = []
var _semantic: Array[StringName] = []
var _board_cues: Array[StringName] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var host := Node3D.new()
	host.name = "TorpedoRunAudioHost"
	root.add_child(host)
	var authority := LiveCombatAuthority.new()
	authority.name = "CombatAuthority"
	host.add_child(authority)
	var launcher := _make_body(host, "Launcher", Vector3.ZERO, Vector3(3.0, 2.0, 6.0))
	var pool := TorpedoPoolScript.new() as SeekerTorpedoProjectile
	pool.name = "SeekerTorpedoes"
	pool.pool_capacity = 2
	launcher.add_child(pool)
	pool.bind_authority(authority)
	var target := _make_body(host, "Target", Vector3(0.0, 0.0, -60.0), Vector3(4.0, 3.0, 8.0))
	var target_health := Damageable.new()
	target_health.name = "Damageable"
	target_health.maximum_health = 200.0
	target_health.faction_id = PLAYER_FACTION
	target.add_child(target_health)
	var gun := _make_body(host, "PlayerGun", Vector3(30.0, 0.0, -30.0), Vector3.ONE)
	await process_frame
	await physics_frame
	await physics_frame
	authority.register_source(launcher, LAUNCHER_ID, LAUNCHER_FACTION, TORPEDO_PROFILE)
	authority.register_source(gun, GUN_ID, PLAYER_FACTION, GUN_PROFILE)

	var audio := pool.get_audio()
	_check(audio != null and audio.get_parent() == pool, "the torpedo pool composes its own audio bank")
	audio.semantic_cue_emitted.connect(
		func(cue_id: StringName, _position: Vector3, _intensity: float) -> void: _semantic.append(cue_id)
	)
	var snapshot := audio.get_snapshot()
	_check(
		int(snapshot.flight_voice_count) == pool.get_pool_capacity()
			and int(snapshot.voice_count) <= int(snapshot.maximum_voices)
			and not bool(snapshot.audio_available),
		"one flight voice per pool slot, a bounded bank, and no native playback under Dummy"
	)
	var voices := audio.find_children("*", "AudioStreamPlayer3D", false, false)
	var routed := not voices.is_empty()
	for voice: AudioStreamPlayer3D in voices:
		routed = routed and voice.bus == TorpedoRunAudio.BUS and voice.top_level \
			and not voice.playing
	_check(routed, "every torpedo voice is world-space on the Weapons bus and silent under Dummy")
	for cue_id in TorpedoRunAudio.STREAM_PATHS:
		_check(
			load(TorpedoRunAudio.STREAM_PATHS[cue_id]) is AudioStreamWAV,
			"the %s cue loads its authored WAV" % String(cue_id)
		)
	var loop := load(TorpedoRunAudio.STREAM_PATHS[TorpedoRunAudio.CUE_FLIGHT]) as AudioStreamWAV
	_check(loop.loop_mode == AudioStreamWAV.LOOP_FORWARD, "the flight drone imports as a forward loop")

	# Lock pips: one per closing step, rising, re-armed by any other posture.
	pool.present_lock_cue(&"stalking", -1, launcher.global_position, 1)
	pool.present_lock_cue(&"locking", 0, launcher.global_position, 1)
	var first_pitch := float(audio.get_snapshot().last_cue_pitch)
	pool.present_lock_cue(&"locking", 1, launcher.global_position, 1)
	pool.present_lock_cue(&"locking", 2, launcher.global_position, 1)
	var last_pitch := float(audio.get_snapshot().last_cue_pitch)
	pool.present_lock_cue(&"locking", 2, launcher.global_position, 1)
	_check(
		_count(audio, TorpedoRunAudio.CUE_LOCK) == 3 and last_pitch > first_pitch,
		"the lock telegraph pips once per bracket step, rising, and never repeats a step"
	)
	pool.present_lock_cue(&"tracking", -1, launcher.global_position, 1)
	pool.present_lock_cue(&"locking", 0, launcher.global_position, 1)
	_check(_count(audio, TorpedoRunAudio.CUE_LOCK) == 4, "the next lock cycle is voiced from its first step")

	# Launch and hit.
	target.global_position = Vector3(0.0, 0.0, -60.0)
	await physics_frame
	var origin := launcher.global_position + Vector3(0.0, 0.0, -5.0)
	var launch := pool.launch(launcher, WEAPON_ID, origin, Vector3.FORWARD, target)
	var record := launch.get("record", {}) as Dictionary
	_check(
		bool(launch.get("accepted", false))
			and _count(audio, TorpedoRunAudio.CUE_LAUNCH) == 1
			and _count(audio, TorpedoRunAudio.CUE_FLIGHT) == 1
			and int(audio.get_snapshot().active_flight_loops) == 1,
		"a launch plays the ignition cue and starts one flight loop"
	)
	_check(not audio.present_launch(record), "a repeated launch edge cannot replay the cue")
	for _index in 600:
		if pool.get_active_torpedo_count() == 0:
			break
		await physics_frame
	_check(
		_count(audio, TorpedoRunAudio.CUE_DETONATION) == 1
			and int(audio.get_snapshot().active_flight_loops) == 0,
		"a torpedo that hits detonates once and its flight loop stops"
	)

	# Shoot-down.
	target.global_position = Vector3(0.0, 0.0, -120.0)
	await physics_frame
	var shot_launch := pool.launch(launcher, WEAPON_ID, origin, Vector3.FORWARD, target)
	var slot_index := int(shot_launch.get("slot_index", -1))
	for _index in 20:
		await physics_frame
	var hurtbox := pool.get_torpedo_hurtbox(slot_index)
	authority.submit_hitscan(gun, GUN_WEAPON_ID, gun.global_position, hurtbox.global_position - gun.global_position)
	_check(
		_count(audio, TorpedoRunAudio.CUE_INTERCEPT) == 1
			and _count(audio, TorpedoRunAudio.CUE_DETONATION) == 1
			and int(audio.get_snapshot().active_flight_loops) == 0,
		"shooting a torpedo down plays the intercept cue, not a detonation"
	)
	_check(
		_semantic.has(TorpedoRunAudio.CUE_LAUNCH) and _semantic.has(TorpedoRunAudio.CUE_INTERCEPT)
			and _semantic.has(TorpedoRunAudio.CUE_LOCK),
		"every audible edge is also routed as a semantic cue"
	)

	# Abandonment silences loops without inventing a cue; tree exit fences.
	pool.launch(launcher, WEAPON_ID, origin, Vector3.FORWARD, target)
	pool.launch(launcher, WEAPON_ID, origin + Vector3(2.0, 0.0, 0.0), Vector3.FORWARD, target)
	_check(int(audio.get_snapshot().active_flight_loops) == 2, "the loop voices are bounded by the two-slot pool")
	var terminal_cues := _count(audio, TorpedoRunAudio.CUE_INTERCEPT) + _count(audio, TorpedoRunAudio.CUE_DETONATION)
	pool.abandon_source_torpedoes(launcher, &"launcher_destroyed")
	_check(
		int(audio.get_snapshot().active_flight_loops) == 0
			and _count(audio, TorpedoRunAudio.CUE_INTERCEPT) + _count(audio, TorpedoRunAudio.CUE_DETONATION)
				== terminal_cues,
		"an abandoned torpedo stops its loop and plays no terminal cue"
	)
	var generation := int(audio.get_snapshot().generation)
	pool.launch(launcher, WEAPON_ID, origin, Vector3.FORWARD, target)
	launcher.remove_child(pool)
	_check(
		int(audio.get_snapshot().generation) == generation + 1
			and int(audio.get_snapshot().active_flight_loops) == 0,
		"leaving the tree stops every voice and advances the audio generation"
	)
	pool.free()

	_test_board_binding()
	await _test_board_voice()
	host.queue_free()
	await process_frame
	_finish()


func _test_board_binding() -> void:
	var binding := BoardAudioBinding.new()
	binding.semantic_board_cue_emitted.connect(
		func(cue_id: StringName, _intensity: float) -> void: _board_cues.append(cue_id)
	)
	binding.attach()
	binding.present_interaction({
		"accepted": true, "generation": 1, "reason": &"sortie_armed", "sortie_generation": 1,
		"snapshot": {"offered_scenario": &"torpedo_run"},
	})
	binding.present_interaction({
		"accepted": true, "generation": 1, "reason": &"sortie_armed", "sortie_generation": 2,
		"snapshot": {"offered_scenario": &"torpedo_run"},
	})
	binding.present_terminal(&"torpedo_run", &"cleared", 4)
	binding.present_terminal(&"torpedo_run", &"cleared", 4)
	binding.present_terminal(&"torpedo_run", &"withdrawn", 5)
	binding.present_interaction({
		"accepted": true, "generation": 1, "reason": &"heavy_breach_started", "scenario": &"heavy_breach",
		"director_generation": 6,
	})
	_check(
		_board_cues.count(BoardAudioBinding.CUE_TORPEDO_RUN_ARMED) == 2,
		"arming the Torpedo Run sounds its own armed tone, again on a later sortie"
	)
	_check(
		_board_cues.count(BoardAudioBinding.CUE_TORPEDO_RUN_CLEARED) == 1
			and _board_cues.count(BoardAudioBinding.CUE_TORPEDO_RUN_FAILED) == 1,
		"a cleared and a failed Torpedo Run each get one board terminal cue"
	)
	_check(_board_cues.has(&"heavy_breach_board_admitted"), "Heavy Breach keeps its own admission cue")
	for cue_id in [
		BoardAudioBinding.CUE_TORPEDO_RUN_ARMED,
		BoardAudioBinding.CUE_TORPEDO_RUN_CLEARED,
		BoardAudioBinding.CUE_TORPEDO_RUN_FAILED,
	]:
		var entry := binding.get_cue_stream(cue_id)
		_check(entry.size() == 2 and load(str(entry[0])) is AudioStreamWAV, "%s has an authored board tone" % cue_id)
	_check(binding.get_cue_stream(&"heavy_breach_board_rejected").is_empty(), "a rejected press stays semantic-only")


func _test_board_voice() -> void:
	var board := BoardScript.new() as HeavyBreachActivityBoard
	root.add_child(board)
	await process_frame
	var voice := board.get_board_voice_snapshot()
	_check(bool(voice.voice_present) and voice.bus == &"UI", "the board carries its own positional cue voice")
	board.call(&"_on_board_cue_emitted", BoardAudioBinding.CUE_TORPEDO_RUN_CLEARED, 1.0)
	voice = board.get_board_voice_snapshot()
	_check(
		int(voice.voiced_cue_count) == 1 and voice.last_cue_id == BoardAudioBinding.CUE_TORPEDO_RUN_CLEARED
			and not bool(voice.audio_available),
		"the board voices a Torpedo Run terminal tone through the Dummy-safe path"
	)
	root.remove_child(board)
	root.add_child(board)
	await process_frame
	_check(
		bool(board.get_audio_binding_snapshot().get("attached", false)),
		"a streamed re-entry re-attaches the board audio binding"
	)
	board.queue_free()
	await process_frame


func _count(audio: TorpedoRunAudio, cue_id: StringName) -> int:
	return int((audio.get_snapshot().cue_counts as Dictionary).get(cue_id, 0))


func _make_body(host: Node3D, body_name: String, position: Vector3, size: Vector3) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.name = body_name
	body.collision_layer = Layers.SHIP
	body.collision_mask = 0
	host.add_child(body)
	body.global_position = position
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	return body


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("TORPEDO_RUN_AUDIO_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		print("TORPEDO_RUN_AUDIO_TEST_FAILED: ", "; ".join(_failures))
		quit(1)
