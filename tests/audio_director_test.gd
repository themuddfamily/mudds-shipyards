extends SceneTree

## Extra simulated frames granted on top of the frames a wait's nominal duration
## implies. This is a frame count, never a wall-clock grace. See
## [method _wait_until].
const FRAME_BUDGET_GRACE := 30

## Nominal simulated seconds every legacy delayed sequence tail is given to fire.
const SEQUENCE_TAIL_SECONDS := 0.45

var _failures: Array[String] = []
var _assertions := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check(AudioServer.get_driver_name() == "Dummy", "focused allocation test runs against the Dummy audio driver")
	if AudioServer.get_driver_name() != "Dummy":
		_finish()
		return

	var director := AudioDirector.new()
	director.name = "AudioDirectorProbe"
	root.add_child(director)
	await process_frame

	_test_fixed_hierarchy(director)
	_test_resident_bank(director)
	await _test_request_churn(director)
	await _test_detach_reentry_cycles(director)
	await _test_clean_lifecycle(director)
	_finish()


func _test_fixed_hierarchy(director: AudioDirector) -> void:
	var players := director.find_children("*", "AudioStreamPlayer", true, false)
	var player_names := PackedStringArray()
	for candidate in players:
		player_names.append(str((candidate as AudioStreamPlayer).name))
	player_names.sort()
	_check(
		player_names == PackedStringArray(["Ambience", "Effect0", "Effect1", "Effect2", "Effect3"]),
		"director owns one ambience player and exactly four fixed effect voices"
	)
	var effects_are_bounded := true
	for index in AudioDirector.EFFECT_VOICE_COUNT:
		var effect := director.get_node_or_null("Effect%d" % index) as AudioStreamPlayer
		effects_are_bounded = effects_are_bounded and effect != null and effect.max_polyphony == 1
	_check(effects_are_bounded, "all four effect players retain one-voice replacement semantics")

	var timers := director.find_children("*", "Timer", true, false)
	var timer_names := PackedStringArray()
	var timers_are_fixed := timers.size() == AudioDirector.SEQUENCE_TIMER_COUNT
	for candidate in timers:
		var timer := candidate as Timer
		timer_names.append(str(timer.name))
		timers_are_fixed = timers_are_fixed \
			and timer.one_shot \
			and not timer.autostart \
			and timer.process_mode == Node.PROCESS_MODE_ALWAYS \
			and timer.process_callback == Timer.TIMER_PROCESS_IDLE \
			and timer.is_stopped()
	timer_names.sort()
	_check(
		timers_are_fixed and timer_names == PackedStringArray([
			"CombatAlertTailTimer",
			"EnemyDestroyedTailTimer",
			"TargetDestroyedTailTimer",
		]),
		"three reusable stopped timers bound every delayed mission-stinger tail"
	)


func _test_resident_bank(director: AudioDirector) -> void:
	var synthesis := director.get_synthesis_report()
	_check(
		bool(synthesis.resources_ready)
		and int(synthesis.resident_stream_count) == AudioDirector.RESIDENT_STREAM_IDS.size()
		and int(synthesis.generation_count) == 1
		and int(synthesis.wave_synthesis_call_count) == AudioDirector.RESIDENT_STREAM_IDS.size(),
		"Dummy ready builds the complete fixed WAV bank exactly once"
	)
	_check(
		int(synthesis.resident_sample_bytes) == AudioDirector.EXPECTED_RESIDENT_SAMPLE_BYTES
		and int(synthesis.expected_resident_sample_bytes) == AudioDirector.EXPECTED_RESIDENT_SAMPLE_BYTES,
		"resident PCM accounting matches the exact deterministic byte total"
	)

	var bank := director.get("_stream_bank") as Dictionary
	var unique_ids := {}
	var measured_bytes := 0
	var every_stream_valid := bank.size() == AudioDirector.RESIDENT_STREAM_IDS.size()
	for stream_id_value in AudioDirector.RESIDENT_STREAM_IDS:
		var stream_id := stream_id_value as StringName
		var stream := bank.get(stream_id) as AudioStreamWAV
		every_stream_valid = every_stream_valid \
			and stream != null \
			and stream.format == AudioStreamWAV.FORMAT_16_BITS \
			and stream.mix_rate == AudioDirector.SAMPLE_RATE \
			and not stream.stereo
		if stream == null:
			continue
		unique_ids[stream.get_instance_id()] = true
		measured_bytes += stream.data.size()
		if stream_id == AudioDirector.STREAM_AMBIENCE:
			every_stream_valid = every_stream_valid \
				and stream.loop_mode == AudioStreamWAV.LOOP_FORWARD \
				and stream.loop_begin == 0 \
				and stream.loop_end == stream.data.size() / 2
		else:
			every_stream_valid = every_stream_valid \
				and stream.loop_mode == AudioStreamWAV.LOOP_DISABLED
	_check(
		every_stream_valid
		and unique_ids.size() == AudioDirector.RESIDENT_STREAM_IDS.size()
		and measured_bytes == AudioDirector.EXPECTED_RESIDENT_SAMPLE_BYTES,
		"all resident entries are unique bounded 22.05 kHz mono WAV resources"
	)
	var performance := director.get_performance_report()
	_check(
		int(performance.effect_voice_count) == 4
		and int(performance.sequence_timer_count) == 3
		and bool(performance.fixed_sequence_scheduling)
		and not bool(performance.runtime_wave_synthesis_allowed),
		"performance report exposes the fixed four-effect/three-scheduler ceiling"
	)
	_check(
		bool(performance.within_resident_budget)
		and int(performance.resident_sample_bytes) == AudioDirector.EXPECTED_RESIDENT_SAMPLE_BYTES
		and int(performance.resident_byte_budget) == AudioDirector.RESIDENT_BYTE_BUDGET,
		"complete resident bank stays within its explicit raw-PCM budget"
	)
	_check(bool(director.get_audit_report().valid), "fresh Dummy director passes its complete allocation and lifecycle audit")


func _test_request_churn(director: AudioDirector) -> void:
	var before_synthesis := director.get_synthesis_report()
	var before_resource_ids := (before_synthesis.resource_instance_ids as Dictionary).duplicate(true)
	var before_player_ids := _instance_ids_by_name(
		director.find_children("*", "AudioStreamPlayer", true, false)
	)
	var before_timer_ids := _instance_ids_by_name(director.find_children("*", "Timer", true, false))
	for iteration in 24:
		director.play_ui_confirm()
		director.play_impact()
		director.play_target_destroyed()
		director.play_combat_alert()
		director.play_canopy(iteration % 2 == 0)
		director.play_canopy(iteration % 2 != 0)
		director.play_enemy_destroyed()
		for footstep_bin in AudioDirector.FOOTSTEP_STREAM_IDS.size():
			director.call("_process", 1.0)
			director.play_footstep(
				float(footstep_bin) / float(AudioDirector.FOOTSTEP_STREAM_IDS.size() - 1)
			)
	# Every legacy delayed tail must have resumed before the report below is
	# taken; this catches synthesis hidden after an await, not only allocation in
	# the first half of a public sequence method. The tails are `Timer` nodes on
	# `TIMER_PROCESS_IDLE`, so wait for the tails themselves to be stopped rather
	# than sleeping on a `SceneTree` timer and hoping the two clocks agree.
	var tails_resumed := await _wait_until(
		func() -> bool:
			for candidate in director.find_children("*", "Timer", true, false):
				if not (candidate as Timer).is_stopped():
					return false
			return true,
		SEQUENCE_TAIL_SECONDS
	)
	await process_frame
	_check(tails_resumed, "every delayed sequence tail resumes inside its bounded budget")

	var after_synthesis := director.get_synthesis_report()
	_check(
		int(after_synthesis.generation_count) == int(before_synthesis.generation_count)
		and int(after_synthesis.wave_synthesis_call_count) == int(before_synthesis.wave_synthesis_call_count),
		"repeated public calls and sequence-tail timeouts perform no new WAV synthesis"
	)
	_check(
		(after_synthesis.resource_instance_ids as Dictionary) == before_resource_ids
		and int(after_synthesis.resident_sample_bytes) == int(before_synthesis.resident_sample_bytes),
		"cue churn preserves every resident resource identity and the byte budget"
	)
	_check(
		_instance_ids_by_name(director.find_children("*", "AudioStreamPlayer", true, false)) == before_player_ids
		and _instance_ids_by_name(director.find_children("*", "Timer", true, false)) == before_timer_ids,
		"cue churn allocates neither effect voices nor sequence schedulers"
	)

	var dummy_state_clean := int(director.get("_effect_cursor")) == 0
	for candidate in director.find_children("*", "AudioStreamPlayer", true, false):
		var player := candidate as AudioStreamPlayer
		dummy_state_clean = dummy_state_clean and not player.playing and player.stream == null
	for candidate in director.find_children("*", "Timer", true, false):
		dummy_state_clean = dummy_state_clean and (candidate as Timer).is_stopped()
	_check(
		dummy_state_clean,
		"Dummy requests never attach/discard a stream, advance a voice, or schedule a tail"
	)
	_check(bool(director.get_audit_report().valid), "high-churn Dummy director remains fully auditable")


func _test_clean_lifecycle(director: AudioDirector) -> void:
	var director_ref: WeakRef = weakref(director)
	var player_refs: Array[WeakRef] = []
	var timer_refs: Array[WeakRef] = []
	var stream_refs: Array[WeakRef] = []
	var players := director.find_children("*", "AudioStreamPlayer", true, false)
	var timers := director.find_children("*", "Timer", true, false)
	for player in players:
		player_refs.append(weakref(player))
	for timer in timers:
		timer_refs.append(weakref(timer))
	var bank := director.get("_stream_bank") as Dictionary
	for stream in bank.values():
		stream_refs.append(weakref(stream))
	players.clear()
	timers.clear()
	bank = {}

	director.queue_free()
	director = null
	await process_frame
	await process_frame
	var everything_released := director_ref.get_ref() == null
	for reference in player_refs:
		everything_released = everything_released and reference.get_ref() == null
	for reference in timer_refs:
		everything_released = everything_released and reference.get_ref() == null
	for reference in stream_refs:
		everything_released = everything_released and reference.get_ref() == null
	_check(
		everything_released,
		"teardown releases the director, all fixed nodes, and every resident WAV resource"
	)


func _test_detach_reentry_cycles(director: AudioDirector) -> void:
	var parent := director.get_parent()
	var fixed_player_ids := _instance_ids_by_name(
		director.find_children("*", "AudioStreamPlayer", true, false)
	)
	var fixed_timer_ids := _instance_ids_by_name(
		director.find_children("*", "Timer", true, false)
	)
	var initial_generation := int(director.get_synthesis_report().generation_count)
	var initial_wave_calls := int(director.get_synthesis_report().wave_synthesis_call_count)
	for cycle in 3:
		var expected_on_foot := cycle % 2 == 0
		var expected_ambience_volume := -10.0 if expected_on_foot else -18.0
		director.set_on_foot(expected_on_foot)
		var bank := director.get("_stream_bank") as Dictionary
		var released_stream_refs := _weak_refs_for_resources(bank.values())
		bank = {}

		parent.remove_child(director)
		await process_frame
		# A detached backend handle may carry stale mixer state. Re-entry must
		# restore the last gameplay-selected mix rather than a fixed default.
		var ambience := director.get_node_or_null("Ambience") as AudioStreamPlayer
		if ambience != null:
			ambience.volume_db = -42.0
		var detached := director.get_synthesis_report()
		var detached_performance := director.get_performance_report()
		_check(
			not bool(detached.resources_ready)
			and int(detached.resident_stream_count) == 0
			and (detached.resource_instance_ids as Dictionary).is_empty()
			and int(detached.resident_sample_bytes) == 0,
			"detach cycle %d releases the complete resident bank" % (cycle + 1)
		)
		_check(
			not bool(detached_performance.playback_enabled)
			and bool(detached_performance.lifecycle_suspended)
			and _all_players_stopped_and_detached(director)
			and _all_timers_stopped(director),
			"detach cycle %d leaves an exact silent backend state" % (cycle + 1)
		)
		_check(
			_instance_ids_by_name(
				director.find_children("*", "AudioStreamPlayer", true, false)
			) == fixed_player_ids
			and _instance_ids_by_name(
				director.find_children("*", "Timer", true, false)
			) == fixed_timer_ids
			and bool(director.get_audit_report().valid),
			"detach cycle %d preserves the exact five-player/three-timer hierarchy and audit" % (cycle + 1)
		)
		var old_resources_released := true
		for reference in released_stream_refs:
			old_resources_released = old_resources_released and reference.get_ref() == null
		_check(old_resources_released, "detach cycle %d leaks no prior WAV resources" % (cycle + 1))

		parent.add_child(director)
		await process_frame
		await process_frame
		var restored := director.get_synthesis_report()
		var resource_ids := restored.resource_instance_ids as Dictionary
		var unique_resource_ids := {}
		for instance_id in resource_ids.values():
			unique_resource_ids[int(instance_id)] = true
		_check(
			bool(restored.resources_ready)
			and int(restored.resident_stream_count) == AudioDirector.RESIDENT_STREAM_IDS.size()
			and resource_ids.size() == AudioDirector.RESIDENT_STREAM_IDS.size()
			and unique_resource_ids.size() == AudioDirector.RESIDENT_STREAM_IDS.size()
			and int(restored.resident_sample_bytes) == AudioDirector.EXPECTED_RESIDENT_SAMPLE_BYTES,
			"re-entry cycle %d restores exactly fifteen unique resident WAV resources" % (cycle + 1)
		)
		_check(
			int(restored.generation_count) == initial_generation + cycle + 1
			and int(restored.wave_synthesis_call_count)
				== initial_wave_calls + (cycle + 1) * AudioDirector.RESIDENT_STREAM_IDS.size(),
			"re-entry cycle %d performs exactly one complete bounded synthesis generation" % (cycle + 1)
		)
		_check(
			_instance_ids_by_name(
				director.find_children("*", "AudioStreamPlayer", true, false)
			) == fixed_player_ids
			and _instance_ids_by_name(
				director.find_children("*", "Timer", true, false)
			) == fixed_timer_ids
			and bool(director.get_audit_report().valid),
			"re-entry cycle %d reuses the exact fixed hierarchy with a green audit" % (cycle + 1)
		)
		var restored_ambience := director.get_node_or_null("Ambience") as AudioStreamPlayer
		_check(
			restored_ambience != null
			and is_equal_approx(restored_ambience.volume_db, expected_ambience_volume)
			and is_equal_approx(
				float(director.get("_desired_ambience_volume_db")),
				expected_ambience_volume
			),
			"re-entry cycle %d restores the selected on-foot or piloting ambience mix" % (cycle + 1)
		)


func _all_players_stopped_and_detached(director: AudioDirector) -> bool:
	var players := director.find_children("*", "AudioStreamPlayer", true, false)
	if players.size() != 1 + AudioDirector.EFFECT_VOICE_COUNT:
		return false
	for candidate in players:
		var player := candidate as AudioStreamPlayer
		if player.playing or player.stream != null:
			return false
	return true


func _all_timers_stopped(director: AudioDirector) -> bool:
	var timers := director.find_children("*", "Timer", true, false)
	if timers.size() != AudioDirector.SEQUENCE_TIMER_COUNT:
		return false
	for candidate in timers:
		if not (candidate as Timer).is_stopped():
			return false
	return true


func _weak_refs_for_resources(resources: Array) -> Array[WeakRef]:
	var references: Array[WeakRef] = []
	for resource in resources:
		references.append(weakref(resource))
	return references


func _instance_ids_by_name(nodes: Array[Node]) -> Dictionary:
	var result := {}
	for node in nodes:
		result[StringName(node.name)] = node.get_instance_id()
	return result


## Waits for `predicate` on both the simulation clock and the monotonic clock,
## giving up only once both budgets are spent.
##
## The sequence tails this suite waits on are `Timer` nodes configured for
## `TIMER_PROCESS_IDLE`, so they advance only when idle frames actually run. A
## `SceneTree` timer counts Godot's smoothed engine delta, which is a different
## clock again and was observed running both ahead of and behind the monotonic
## one on a busy box, so a sleep could return with a tail still pending and the
## churn report taken too early. `nominal_seconds` is kept as the duration the
## wait is *expected* to take and becomes both a frame budget and a wall-clock
## deadline; both stay finite, so a tail that genuinely never fires still fails
## the suite.
func _wait_until(predicate: Callable, nominal_seconds: float) -> bool:
	var frame_budget := (
		int(ceil(maxf(nominal_seconds, 0.0) * float(Engine.physics_ticks_per_second)))
		+ FRAME_BUDGET_GRACE
	)
	var deadline := Time.get_ticks_msec() + int(ceil(maxf(nominal_seconds, 0.0) * 1000.0))
	var frames := 0
	while not bool(predicate.call()):
		if frames >= frame_budget and Time.get_ticks_msec() >= deadline:
			return false
		await physics_frame
		await process_frame
		frames += 1
	return true


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("AUDIO_DIRECTOR_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		print("AUDIO_DIRECTOR_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
