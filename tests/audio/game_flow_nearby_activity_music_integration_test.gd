extends SceneTree

const GameFlowScript := preload("res://scripts/game/game_flow.gd")
const MusicBedScene := preload("res://scenes/audio/station_music_bed.tscn")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var bed := MusicBedScene.instantiate() as StationMusicBed
	var flow := GameFlowScript.new() as GameFlow
	root.add_child(bed)
	flow.music_bed = bed
	flow._initialize_nearby_activity_audio()
	await process_frame
	bed.set_process(false)
	var snapshot := {
		"activity_id": &"cinder_reach_emberline_convoy",
		"host": {"activity": {"state_id": &"active", "generation": 7}},
	}
	flow._sync_nearby_activity_audio(snapshot)
	var music_adapter: Node = flow.get("nearby_activity_music_adapter")
	var audio_binding: Node = flow.get("nearby_activity_audio_binding")
	_check(bool(music_adapter.get_snapshot().attached), "music adapter is attached")
	_check(bed.get_presentation_state() == &"activity_active", "HUD activity snapshot reaches active music")
	_check(
		int(music_adapter.get_snapshot().last_activity_generation) == 7,
		"activity generation is retained by the music adapter"
	)
	flow._sync_nearby_activity_audio(snapshot)
	_check(
		int(music_adapter.get_snapshot().last_activity_generation) == 7,
		"duplicate detached snapshot does not advance music generation"
	)
	# Stage detached facts at the production observation seam; this is not an
	# ordinary convoy journey. Completion retains the run's generation, and the
	# next normal GameFlow process updates the base phase after snapshot delivery.
	flow._sync_nearby_activity_audio({
		"activity_id": &"cinder_reach_emberline_convoy",
		"host": {"activity": {"state_id": &"complete", "generation": 7}},
	})
	_check(
		bed.get_presentation_state() == &"activity_complete"
		and is_equal_approx(float(bed.get_state_snapshot().layer_targets[&"motif"]), 0.8),
		"same-run completion selects the actual completion music targets"
	)
	flow._sync_nearby_activity_audio({
		"activity_id": &"cinder_reach_emberline_convoy",
		"host": {"activity": {"state_id": &"active", "generation": 8}},
	})
	flow._update_music_bed_state()
	_check(
		bed.get_presentation_state() == &"activity_active"
		and is_equal_approx(float(bed.get_state_snapshot().layer_targets[&"motif"]), 0.15),
		"normal base update preserves the actual active activity music targets"
	)
	_check(bool(bed.notify_music_phase(&"combat")), "combat presentation is accepted")
	flow._sync_nearby_activity_audio({
		"activity_id": &"cinder_reach_emberline_convoy",
		"host": {"activity": {"state_id": &"active", "generation": 8}},
	})
	_check(bed.get_presentation_state() == &"combat", "combat preempts forwarded activity music")
	flow.phase = GameFlow.Phase.INTERCEPTOR_ENGAGEMENT
	flow._update_music_bed_state()
	_sync_convoy(flow, &"complete", 8)
	_check(bed.get_presentation_state() == &"combat", "same-run completion cannot replace the combat profile")
	_sync_convoy(flow, &"active", 8)
	_check(
		music_adapter.get_snapshot().last_snapshot.activity_state == &"complete",
		"terminal replay cannot replace the current suppressed completion fact"
	)
	flow.phase = GameFlow.Phase.FREE_FLIGHT
	flow.set("_piloting", true)
	flow._update_music_bed_state()
	# Advance the real bed's deterministic envelope, including its existing
	# combat recovery hold. Dummy deliberately attaches no playback handles.
	bed._process(4.0)
	_check(
		bed.get_presentation_state() == &"activity_complete"
		and is_equal_approx(float(bed.get_state_snapshot().layer_targets[&"motif"]), 0.8)
		and bed.get_bed_family() == StationMusicBed.FAMILY_FLIGHT,
		"combat release resumes current completion over the actual orbit bed"
	)
	flow.set("_landing_request_active", true)
	flow._update_music_bed_state()
	_sync_convoy(flow, &"active", 9)
	_check(
		bed.get_presentation_state() == &"landing"
		and is_equal_approx(float(bed.get_state_snapshot().layer_targets[&"motif"]), 0.28),
		"landing preempts a newly observed active activity"
	)
	_sync_convoy(flow, &"complete", 9)
	_check(bed.get_presentation_state() == &"landing", "same-run completion also preserves landing precedence")
	flow.set("_landing_request_active", false)
	flow._update_music_bed_state()
	_check(bed.get_presentation_state() == &"activity_complete", "landing release resumes current completion rather than prior active music")
	_sync_convoy(flow, &"reset", 10)
	flow._update_music_bed_state()
	_check(
		bed.get_presentation_state() == &"orbit"
		and is_equal_approx(float(bed.get_state_snapshot().layer_targets[&"motif"]), 0.1),
		"reset releases activity ownership to actual orbit targets"
	)
	_sync_convoy(flow, &"complete", 9)
	_sync_convoy(flow, &"active", 10)
	_check(bed.get_presentation_state() == &"orbit", "stale completion and reset-run active replay cannot revive music")
	_sync_convoy(flow, &"active", 11)
	flow.set("_ember_surface_journey_active", true)
	flow._update_music_bed_state()
	_check(
		bed.get_presentation_state() == &"activity_active"
		and bed.get_bed_family() == StationMusicBed.FAMILY_SURFACE,
		"current activity survives an actual base-family change"
	)
	_sync_convoy(flow, &"idle", 12)
	flow._update_music_bed_state()
	_check(
		bed.get_presentation_state() == &"surface"
		and is_equal_approx(float(bed.get_state_snapshot().layer_targets[&"motif"]), 0.4),
		"idle releases activity ownership to the retained surface context"
	)
	flow.set("_ember_surface_journey_active", false)
	flow.set("_piloting", false)
	flow._update_music_bed_state()
	_sync_convoy(flow, &"active", 13)
	bed._process(4.0)
	bed._process(4.0)
	var stable_snapshot: Dictionary = bed.get_state_snapshot()
	var observations := int(bed.get_music_director().get_snapshot().observation_count)
	for _frame in range(3):
		flow._update_music_bed_state()
		_sync_convoy(flow, &"active", 13)
	_check(
		int(bed.get_music_director().get_snapshot().observation_count) == observations
		and bed.get_state_snapshot().layer_positions == stable_snapshot.layer_positions
		and bed.get_state_snapshot().layer_targets == stable_snapshot.layer_targets,
		"unchanged normal frames and duplicate facts preserve mix and loop position without cue replay"
	)
	_check(float(stable_snapshot.layer_gains[&"motif"]) > 0.0, "real activity gain envelope advances under Dummy")
	var performance: Dictionary = bed.get_performance_report()
	_check(
		int(performance.audio_player_count) == 3
		and int(performance.maximum_simultaneous_voices) == 3
		and int(performance.playing_voice_count) == 0
		and not bool(performance.playback_available),
		"Dummy retains the existing three-player ceiling without live playback handles"
	)
	flow._detach_nearby_activity_audio()
	_check(not bool(music_adapter.get_snapshot().attached), "music adapter detaches")
	_check(not bool(audio_binding.get_snapshot().attached), "activity audio binding detaches")
	_check(
		bed.get_presentation_state() == &"station" and not bed.is_bed_enabled()
		and music_adapter.get_snapshot().last_snapshot.is_empty(),
		"detach clears activity presentation and disables the bed in its actual base context"
	)
	flow._initialize_nearby_activity_audio()
	flow._update_music_bed_state()
	_check(bed.get_presentation_state() == &"station" and bed.is_bed_enabled(), "reentry starts in the current base without reviving prior activity")
	_sync_convoy(flow, &"active", 1)
	flow._update_music_bed_state()
	_check(bed.get_presentation_state() == &"activity_active", "reentry accepts its current activity stream with a fresh generation fence")
	flow._detach_nearby_activity_audio()
	flow.queue_free()
	bed.queue_free()
	await process_frame
	for failure in _failures:
		push_error(failure)
	print("game_flow_nearby_activity_music_integration_test: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _sync_convoy(flow: GameFlow, state: StringName, generation: int) -> void:
	flow._sync_nearby_activity_audio({
		"activity_id": &"cinder_reach_emberline_convoy",
		"host": {"activity": {"state_id": state, "generation": generation}},
	})


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
