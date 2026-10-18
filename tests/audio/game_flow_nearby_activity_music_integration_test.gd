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
	flow._detach_nearby_activity_audio()
	_check(not bool(music_adapter.get_snapshot().attached), "music adapter detaches")
	_check(not bool(audio_binding.get_snapshot().attached), "activity audio binding detaches")
	flow.queue_free()
	bed.queue_free()
	await process_frame
	for failure in _failures:
		push_error(failure)
	print("game_flow_nearby_activity_music_integration_test: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
