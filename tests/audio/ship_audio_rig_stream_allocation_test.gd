extends SceneTree

const RigScene := preload("res://scenes/audio/ship_audio_rig.tscn")
const PLAYBACK_TEARDOWN_DRAIN_SECONDS := 0.05


class QueueCandidateRig extends ShipAudioRig:
	func _detect_playback_queue_candidate() -> bool:
		return ShipAudioRig._is_playback_queue_candidate("AllocationTest", 0.0)


var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var fixture_root := Node3D.new()
	root.add_child(fixture_root)
	var rig := RigScene.instantiate() as ShipAudioRig
	rig.set_script(QueueCandidateRig)
	fixture_root.add_child(rig)
	await process_frame

	_assert_stream_allocation(rig, "initial synthesis")
	var initial_generation := int(rig.get_synthesis_report().generation_count)
	_check(rig.set_audio_perspective(ShipAudioRig.PERSPECTIVE_COCKPIT), "cockpit perspective remains available")
	_check(rig.set_reduced_dynamic_range(true), "damage accessibility attenuation remains available")
	_check(rig.set_engine_running(true, false), "engine loop state is accepted")
	_check(rig.set_thrust_state(0.82, true), "load and boost loop state is accepted")
	_check(rig.set_damage_alarm_active(true), "damage alarm remains an independent requested loop")
	_check(rig.play_cue(ShipAudioRig.CUE_STARTUP), "engine transient queues on its replacement voice")
	_check(rig.play_cue(ShipAudioRig.CUE_FIRE), "combat transient queues simultaneously on its replacement voice")

	var resource_ids := rig.get_synthesis_report().resource_instance_ids as Dictionary
	var engine_player := rig.get_node("EngineCueVoice") as AudioStreamPlayer3D
	var combat_player := rig.get_node("CombatCueVoice") as AudioStreamPlayer3D
	var alarm_player := rig.get_node("DamageAlarm") as AudioStreamPlayer3D
	_check(
		engine_player.playing
		and combat_player.playing
		and alarm_player.playing
		and engine_player.stream.get_instance_id() == int(resource_ids[ShipAudioRig.CUE_STARTUP])
		and combat_player.stream.get_instance_id() == int(resource_ids[ShipAudioRig.CUE_FIRE])
		and alarm_player.stream.get_instance_id() == int(resource_ids[ShipAudioRig.LOOP_DAMAGE_ALARM]),
		"engine cue, combat cue, and damage alarm retain three distinct simultaneous resources"
	)
	_check(
		(rig.get_state_snapshot().queued_voice_ids as PackedStringArray).size() == 6,
		"all four propulsion/alarm loops and both transient channels retain the six-voice ceiling"
	)
	paused = true
	await process_frame
	_check(
		engine_player.playing
		and combat_player.playing
		and not engine_player.stream_paused
		and not combat_player.stream_paused
		and int(rig.get_synthesis_report().audio_stream_resource_allocation_count) == 6,
		"scene pause preserves both transient handles without allocating or mutating stream pause state"
	)
	paused = false
	await process_frame
	_check(
		rig.play_cue(ShipAudioRig.CUE_DOCKING)
		and rig.play_cue(ShipAudioRig.CUE_IMPACT)
		and engine_player.stream.get_instance_id() == int(resource_ids[ShipAudioRig.CUE_STARTUP])
		and combat_player.stream.get_instance_id() == int(resource_ids[ShipAudioRig.CUE_FIRE]),
		"replacement cues reuse their own channel wrapper without crossing channels"
	)
	_check(bool(rig.get_audit_report().valid), "simultaneous replacement reuse remains deeply auditable")

	rig.set_rig_enabled(false)
	_check(_all_players_detached(rig), "disable detaches every playback handle")
	_assert_stream_allocation(rig, "ordinary disable")
	rig.set_rig_enabled(true)
	_check(
		int(rig.get_synthesis_report().generation_count) == initial_generation,
		"ordinary re-enable reuses the same bounded allocation generation"
	)

	fixture_root.remove_child(rig)
	await process_frame
	_check(
		int(rig.get_synthesis_report().audio_stream_resource_allocation_count) == 0,
		"detach releases every owned stream resource"
	)
	fixture_root.add_child(rig)
	await process_frame
	await process_frame
	_assert_stream_allocation(rig, "re-entry regeneration")
	var state := rig.get_state_snapshot()
	_check(
		state.audio_perspective == ShipAudioRig.PERSPECTIVE_COCKPIT
		and bool(state.reduced_dynamic_range)
		and (state.desired_loop_layers as PackedStringArray).size() == 4,
		"re-entry retains perspective, accessibility, and all independent desired loops"
	)

	rig.set_rig_enabled(false)
	await process_frame
	engine_player = null
	combat_player = null
	alarm_player = null
	rig.queue_free()
	await process_frame
	await process_frame
	# QueueCandidateRig intentionally exercises accepted playback on the Dummy
	# backend. Let its audio-thread playback handles observe the rig's detach
	# before the SceneTree exits, just as a streamed-scene unload does at runtime.
	await create_timer(PLAYBACK_TEARDOWN_DRAIN_SECONDS).timeout
	fixture_root.queue_free()
	await process_frame
	await process_frame
	for failure in _failures:
		push_error(failure)
	print("ship_audio_rig_stream_allocation_test: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _assert_stream_allocation(rig: ShipAudioRig, phase: String) -> void:
	var synthesis := rig.get_synthesis_report()
	var resource_ids := synthesis.resource_instance_ids as Dictionary
	var unique_ids := {}
	for instance_id in resource_ids.values():
		unique_ids[int(instance_id)] = true
	var engine_id := int(resource_ids[ShipAudioRig.CUE_STARTUP])
	var combat_id := int(resource_ids[ShipAudioRig.CUE_FIRE])
	var routes_are_voice_scoped := true
	for cue_id in ShipAudioRig.CUE_IDS:
		var expected_id := engine_id if ShipAudioRig.CUE_TO_VOICE[cue_id] == ShipAudioRig.VOICE_ENGINE_CUE else combat_id
		routes_are_voice_scoped = routes_are_voice_scoped and int(resource_ids[cue_id]) == expected_id
	_check(
		bool(synthesis.resources_ready)
		and int(synthesis.loop_template_count) == 4
		and int(synthesis.cue_template_count) == 8
		and int(synthesis.resident_sample_bytes) == ShipAudioRig.EXPECTED_RESIDENT_SAMPLE_BYTES,
		"%s preserves all twelve deterministic PCM templates" % phase
	)
	_check(
		unique_ids.size() == 6
		and int(synthesis.audio_stream_resource_allocation_count) == 6
		and int(synthesis.legacy_audio_stream_resource_allocation_count) == 12
		and int(synthesis.audio_stream_resource_allocation_reduction) == 6,
		"%s reduces AudioStreamWAV allocations from twelve to six" % phase
	)
	_check(
		routes_are_voice_scoped and engine_id != combat_id,
		"%s shares cue wrappers only within each replacement voice" % phase
	)
	_check(
		rig.find_children("*", "AudioStreamPlayer3D", true, false).size() == 6
		and int(rig.get_performance_report().maximum_simultaneous_voices) == 6,
		"%s preserves the six independent positional voices" % phase
	)


func _all_players_detached(rig: ShipAudioRig) -> bool:
	for candidate in rig.find_children("*", "AudioStreamPlayer3D", true, false):
		var player := candidate as AudioStreamPlayer3D
		if player.playing or player.stream != null:
			return false
	return true


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
