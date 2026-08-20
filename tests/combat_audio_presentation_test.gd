extends SceneTree

const COMBAT_AUDIO_PRESENTATION := preload("res://scenes/audio/combat_audio_presentation.tscn")


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
