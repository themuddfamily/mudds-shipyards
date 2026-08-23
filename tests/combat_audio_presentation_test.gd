extends SceneTree

const COMBAT_AUDIO_PRESENTATION := preload("res://scenes/audio/combat_audio_presentation.tscn")
const COURIER_SCENE := preload("res://scenes/ships/courier_runner_opponent.tscn")
const SKIRMISHER_SCENE := preload("res://scenes/ships/flanking_skirmisher_opponent.tscn")
const PICKET_SCENE := preload("res://scenes/ships/standoff_picket_opponent.tscn")


class RejectingCombatAudioPresentation extends CombatAudioPresentation:
	func _request_player_playback(_player: AudioStreamPlayer3D) -> bool:
		return false


class FailThenAcceptCombatAudioPresentation extends CombatAudioPresentation:
	var _first_attempt := true

	func _request_player_playback(_player: AudioStreamPlayer3D) -> bool:
		if _first_attempt:
			_first_attempt = false
			return false
		return true


var _failures: Array[String] = []
var _assertions := 0
var _test_root: Node3D


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_root = Node3D.new()
	_test_root.name = "CombatAudioPresentationTestRoot"
	root.add_child(_test_root)

	await _test_default_playback_accepts_and_counts()
	await _test_rejection_is_atomic_and_detached()
	await _test_first_reject_then_accept_keeps_pool()
	await _test_derived_opponent_weapon_profiles()
	await _test_queued_reentry_restore_is_inert()

	_test_root.queue_free()
	await process_frame
	await process_frame
	_finish()


func _make_presentation(custom_script: Script = null) -> CombatAudioPresentation:
	var presentation := COMBAT_AUDIO_PRESENTATION.instantiate() as CombatAudioPresentation
	if presentation == null:
		_check(false, "combat audio scene instantiates as CombatAudioPresentation")
		return null
	presentation.name = "CombatAudioPresentationUnderTest"
	if custom_script != null:
		presentation.set_script(custom_script)
	_test_root.add_child(presentation)
	await process_frame
	return presentation


func _test_default_playback_accepts_and_counts() -> void:
	var presentation := await _make_presentation()
	if presentation == null:
		return
	var before := presentation.get_state_snapshot()
	var accepted := presentation.play_player_fire(Vector3(1.25, 0.75, -2.5), 101)
	_check(
		accepted,
		"default combat audio playback reports acceptance when backend accepts"
	)
	var after := presentation.get_state_snapshot()
	_check(
		int(after.get("cue_count", -1)) == int(before.get("cue_count", -2)) + 1,
		"accepted combat playback increments cue_count exactly once"
	)
	_check(
		after.get("last_world_position") == Vector3(1.25, 0.75, -2.5),
		"accepted combat playback snapshots the last world position"
	)
	presentation.queue_free()
	await process_frame


func _test_rejection_is_atomic_and_detached() -> void:
	var presentation := await _make_presentation(RejectingCombatAudioPresentation)
	if presentation == null:
		return
	var before := presentation.get_state_snapshot()
	var accepted := presentation.play_player_fire(Vector3(-4.0, 0.0, 8.0), 202)
	_check(
		not accepted,
		"simulated backend rejection reports playback not accepted"
	)
	var after := presentation.get_state_snapshot()
	_check(
		int(after.get("cue_count", -1)) == int(before.get("cue_count", -1)),
		"simulated backend rejection does not mutate cue counters"
	)
	_check(
		(after.get("active_voice_names") as PackedStringArray).is_empty(),
		"simulated backend rejection leaves voice graph detached and silent"
	)
	_check(
		int((after.get("voice_count", -1))) == int(before.get("voice_count", -1)),
		"simulated backend rejection does not mutate fixed voice identity"
	)
	presentation.queue_free()
	await process_frame


func _test_first_reject_then_accept_keeps_pool() -> void:
	var presentation := await _make_presentation(FailThenAcceptCombatAudioPresentation)
	if presentation == null:
		return
	var before := presentation.get_state_snapshot()
	var first := presentation.play_player_fire(Vector3(3.0, 2.0, 1.0), 303)
	var mid := presentation.get_state_snapshot()
	_check(
		not first,
		"simulated first playback rejection remains rejected"
	)
	_check(
		int(mid.get("cue_count", -1)) == int(before.get("cue_count", -1)),
		"first rejected playback keeps cue_count unchanged"
	)

	var second := presentation.play_player_fire(Vector3(2.0, 3.0, 4.0), 303)
	var after := presentation.get_state_snapshot()
	_check(
		second,
		"second playback attempt succeeds once rejection condition clears"
	)
	_check(
		int(after.get("cue_count", -1)) == int(before.get("cue_count", -1)) + 1,
		"recovered backend playback reclaims the next pool slot once"
	)
	_check(
		int(after.get("last_source_instance_id", -1)) == 303,
		"recovered playback records source instance id"
	)
	presentation.queue_free()
	await process_frame


func _test_derived_opponent_weapon_profiles() -> void:
	var presentation := await _make_presentation()
	if presentation == null:
		return
	var courier := COURIER_SCENE.instantiate() as CourierRunnerOpponent
	var skirmisher := SKIRMISHER_SCENE.instantiate() as FlankingSkirmisherOpponent
	var picket := PICKET_SCENE.instantiate() as StandoffPicketOpponent
	for craft in [courier, skirmisher, picket]:
		craft.set("combat_audio_path", NodePath("../CombatAudioPresentationUnderTest"))
		_test_root.add_child(craft)
	await process_frame

	var resolved_miss := {
		"accepted": true,
		"resolved": true,
		"hit": false,
		"damaged": false,
	}
	picket.call("_present_lance_shot", Vector3(-12.0, 3.0, 8.0), Vector3.FORWARD, 1, resolved_miss)
	var lance_fire := presentation.get_state_snapshot()
	courier.call("_present_resolved_shot", Vector3.ZERO, Vector3.FORWARD, 2, resolved_miss)
	var turret_fire := presentation.get_state_snapshot()
	skirmisher.call("_present_resolved_shot", Vector3(12.0, 3.0, 8.0), Vector3.FORWARD, 3, resolved_miss)
	var repeater_fire := presentation.get_state_snapshot()
	_check(
		lance_fire.last_cue_id == CombatAudioPresentation.CUE_DEFENDER_FIRE
		and lance_fire.last_weapon_profile_id
			== CombatAudioPresentation.WEAPON_PROFILE_SIEGE_LANCE
		and lance_fire.last_semantic_cue_id
			== CombatAudioPresentation.SEMANTIC_SIEGE_LANCE_FIRE
		and is_equal_approx(float(lance_fire.last_cue_pitch_scale), 0.78)
		and turret_fire.last_weapon_profile_id
			== CombatAudioPresentation.WEAPON_PROFILE_TAIL_TURRET
		and turret_fire.last_semantic_cue_id
			== CombatAudioPresentation.SEMANTIC_TAIL_TURRET_FIRE
		and is_equal_approx(float(turret_fire.last_cue_pitch_scale), 0.93)
		and repeater_fire.last_weapon_profile_id
			== CombatAudioPresentation.WEAPON_PROFILE_REPEATER
		and repeater_fire.last_semantic_cue_id
			== CombatAudioPresentation.SEMANTIC_REPEATER_FIRE
		and is_equal_approx(float(repeater_fire.last_cue_pitch_scale), 1.20),
		"live lance, tail turret, and repeater dispatches select low, broad, and fast fire profiles"
	)
	_check(
		int(repeater_fire.profiled_source_count) == 3
		and int(repeater_fire.voice_count) == 10
		and int((presentation.get_audit_report() as Dictionary).maximum_simultaneous_voices) == 10,
		"profile association adds no voices and stays inside the existing ten-voice bank"
	)

	presentation.play_impact(Vector3(-12.0, 3.0, -30.0), 0.9, picket.get_instance_id())
	var lance_impact := presentation.get_state_snapshot()
	presentation.play_impact(Vector3(0.0, 3.0, -30.0), 0.9, courier.get_instance_id())
	var turret_impact := presentation.get_state_snapshot()
	presentation.play_impact(Vector3(12.0, 3.0, -30.0), 0.9, skirmisher.get_instance_id())
	var repeater_impact := presentation.get_state_snapshot()
	_check(
		lance_impact.last_cue_id == CombatAudioPresentation.CUE_IMPACT_HEAVY
		and lance_impact.last_semantic_cue_id
			== CombatAudioPresentation.SEMANTIC_SIEGE_LANCE_IMPACT
		and is_equal_approx(float(lance_impact.last_cue_pitch_scale), 0.80)
		and turret_impact.last_cue_id == CombatAudioPresentation.CUE_IMPACT_MEDIUM
		and turret_impact.last_semantic_cue_id
			== CombatAudioPresentation.SEMANTIC_TAIL_TURRET_IMPACT
		and is_equal_approx(float(turret_impact.last_cue_pitch_scale), 0.95)
		and repeater_impact.last_cue_id == CombatAudioPresentation.CUE_IMPACT_LIGHT
		and repeater_impact.last_semantic_cue_id
			== CombatAudioPresentation.SEMANTIC_REPEATER_IMPACT
		and is_equal_approx(float(repeater_impact.last_cue_pitch_scale), 1.16),
		"the unchanged source-ID arrival seam resolves heavy, broad, and light impact profiles"
	)
	_check(
		float(lance_impact.last_cue_volume_db) <= -1.0
		and float(turret_impact.last_cue_volume_db) <= -1.0
		and float(repeater_impact.last_cue_volume_db) <= -1.0
		and float(lance_impact.last_semantic_intensity)
			> float(turret_impact.last_semantic_intensity)
		and float(turret_impact.last_semantic_intensity)
			> float(repeater_impact.last_semantic_intensity),
		"profile levels remain bounded for the shared reduced-range Weapons mix while retaining semantic weight"
	)

	_test_root.remove_child(presentation)
	await process_frame
	_test_root.add_child(presentation)
	await process_frame
	var reentered := presentation.get_state_snapshot()
	presentation.play_impact(Vector3.ZERO, 0.9, picket.get_instance_id())
	var unmapped_impact := presentation.get_state_snapshot()
	_check(
		int(reentered.profiled_source_count) == 0
		and unmapped_impact.last_cue_id == CombatAudioPresentation.CUE_IMPACT_MEDIUM
		and unmapped_impact.last_weapon_profile_id
			== CombatAudioPresentation.WEAPON_PROFILE_STANDARD,
		"audio-bank re-entry clears stale source profiles and cannot replay a pre-detach heavy impact"
	)
	picket.call("_present_lance_shot", Vector3.ZERO, Vector3.FORWARD, 4, resolved_miss)
	_check(
		presentation.get_state_snapshot().last_weapon_profile_id
			== CombatAudioPresentation.WEAPON_PROFILE_SIEGE_LANCE,
		"one fresh post-reentry lance dispatch restores only its current source profile"
	)

	for craft in [courier, skirmisher, picket]:
		craft.queue_free()
	presentation.queue_free()
	await process_frame


func _test_queued_reentry_restore_is_inert() -> void:
	var presentation := await _make_presentation()
	if presentation == null:
		return
	_test_root.remove_child(presentation)
	await process_frame
	_test_root.add_child(presentation)
	await process_frame
	_check(
		presentation.play_player_fire(Vector3(6.0, 1.0, -3.0), 404),
		"a reentered combat-audio presentation accepts one fresh live playback"
	)
	var voice := presentation.get_node_or_null(^"FireVoice0") as AudioStreamPlayer3D
	if voice == null:
		_check(false, "queued re-entry fixture retains the first fixed fire voice")
		presentation.queue_free()
		await process_frame
		return
	var cue_events: Array[StringName] = []
	presentation.cue_started.connect(
		func(cue_id: StringName, _voice_name: StringName, _world_position: Vector3, _source_id: int) -> void:
			cue_events.append(cue_id)
	)
	presentation.queue_free()
	var playback_before := presentation.get_state_snapshot()
	var queued_playback := presentation.play_player_fire(Vector3(-8.0, 2.0, 5.0), 405)
	_check(
		presentation.is_queued_for_deletion()
		and not queued_playback
		and presentation.get_state_snapshot() == playback_before
		and cue_events.is_empty(),
		"a queued combat-audio presentation rejects live playback without voice, state, or signal mutation"
	)
	# The ordinary re-entry callback is still queued. Freeze deliberately
	# noncanonical values after playback has proven the queue gate, so this
	# independently detects any post-disposal player configuration work.
	voice.top_level = false
	voice.max_distance = 17.0
	var restore_before := presentation.get_state_snapshot()
	presentation.call("_restore_players_after_reentry")
	_check(
		presentation.is_queued_for_deletion()
		and presentation.get_state_snapshot() == restore_before
		and not voice.top_level
		and is_equal_approx(voice.max_distance, 17.0),
		"a queued post-reentry combat-audio presentation cannot reconfigure its fixed voices"
	)
	await process_frame
	_check(not is_instance_valid(presentation), "the queued combat-audio fixture frees normally")


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
		return
	_failures.append(description)
	push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("COMBAT_AUDIO_PRESENTATION_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	print("COMBAT_AUDIO_PRESENTATION_TEST_FAILED: " + ", ".join(_failures))
	quit(1)
