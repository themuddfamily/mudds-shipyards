extends SceneTree

const BindingScript := preload("res://scripts/audio/nearby_sector_activity_audio_binding.gd")
const PresenterScript := preload("res://scripts/ui/semantic_audio_cue_presenter.gd")

const CASES := [
	[&"mining", &"cinder_platform_mining_run", &"failed", &"cinder_mining_extraction_failed", "Mining extraction failed"],
	[&"salvage", &"cinder_derelict_structure_scan", &"failed", &"cinder_scan_failed", "Structure scan failed"],
	[&"salvage", &"cinder_derelict_structure_scan", &"aborted", &"cinder_scan_aborted", "Structure scan aborted"],
	[&"race", &"cinder_reach_checkpoint_route", &"timed_out", &"cinder_race_timed_out", "Race timed out"],
	[&"race", &"cinder_reach_checkpoint_route", &"failed", &"cinder_race_failed", "Race failed"],
	[&"race", &"cinder_reach_checkpoint_route", &"aborted", &"cinder_race_aborted", "Race aborted"],
	[&"patrol", &"cinder_relay_patrol", &"failed", &"cinder_patrol_failed", "Patrol failed"],
	[&"patrol", &"cinder_relay_patrol", &"aborted", &"cinder_patrol_aborted", "Patrol aborted"],
]

var _assertions := 0
var _failures: Array[String] = []
var _events: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var binding := BindingScript.new()
	root.add_child(binding)
	binding.semantic_activity_cue_emitted.connect(func(
		cue_id: StringName, activity_id: StringName, intensity: float
	) -> void:
		_events.append({"cue_id": cue_id, "activity_id": activity_id, "intensity": intensity})
	)
	_check(bool(binding.attach().accepted), "failure feedback binding attaches")
	var presenter := PresenterScript.new()
	var generation := 1
	for case: Array in CASES:
		var active := _snapshot(case[0], case[1], generation, &"")
		_check(bool(binding.present_activity_snapshot(active).accepted), "%s baseline is accepted" % case[3])
		var terminal := _snapshot(case[0], case[1], generation, case[2])
		var before := _events.size()
		_check(bool(binding.present_activity_snapshot(terminal).accepted), "%s terminal snapshot is accepted" % case[3])
		_check(_events.size() == before + 1 and _events[-1].cue_id == case[3]
			and is_equal_approx(float(_events[-1].intensity), 1.0),
			"%s emits its distinct full-intensity cue once" % case[3])
		_check(bool(binding.present_activity_snapshot(terminal).accepted)
			and _events.size() == before + 1,
			"%s retained terminal snapshot is deduplicated" % case[3])
		var caption := presenter.present_cue(case[3], case[1], 1.0, Vector3.ZERO, {
			"transition_id": "%s-%d" % [case[2], generation], "tick": generation,
		})
		_check(bool(caption.accepted) and caption.caption == case[4]
			and caption.severity == &"high",
			"%s has a concise high-severity caption" % case[3])
		generation += 1

	var malformed := _snapshot(&"race", &"cinder_reach_checkpoint_route", generation, &"destroyed")
	_check(binding.present_activity_snapshot(malformed).reason == &"invalid_terminal_outcome",
		"unknown terminal silhouettes are rejected before cue emission")
	var before_reentry := _events.size()
	var retained_abort := _snapshot(
		&"patrol", &"cinder_relay_patrol", generation - 1, &"aborted"
	)
	_check(bool(binding.detach().accepted) and bool(binding.attach(1).accepted)
		and bool(binding.present_activity_snapshot(retained_abort).accepted)
		and _events.size() == before_reentry,
		"detach and re-entry do not replay a retained terminal generation")
	var cleanup_terminal := _snapshot(
		&"patrol", &"cinder_relay_patrol", generation, &"failed"
	)
	_check(bool(binding.present_activity_snapshot(cleanup_terminal).accepted)
		and (binding.get_snapshot().active_cue_slots as Array).any(func(slot: Dictionary) -> bool:
			return slot.cue_id == &"cinder_patrol_failed"),
		"fresh terminal generation occupies one bounded cue slot")
	var reset := _snapshot(&"patrol", &"cinder_relay_patrol", generation, &"")
	reset.state = &"reset"
	reset.reset_serial = 1
	_check(bool(binding.present_activity_snapshot(reset).accepted)
		and not (binding.get_snapshot().active_cue_slots as Array).any(func(slot: Dictionary) -> bool:
			return slot.cue_id in [&"cinder_patrol_failed", &"cinder_patrol_aborted"]),
		"reset retires terminal cue slots from the bounded voice allocator")
	_check(int(binding.get_snapshot().maximum_simultaneous_voices) == 2,
		"failure feedback retains the existing two-voice ceiling")
	_check(presenter.get_transcript(generation).size() == PresenterScript.MAX_TRANSCRIPT_ENTRIES,
		"all distinct failure captions fit the bounded transcript")
	var authority := binding.get_snapshot().authority as Dictionary
	_check(not bool(authority.activity) and not bool(authority.reward)
		and not bool(authority.gameplay) and bool(authority.audio_cues),
		"failure feedback owns presentation only")

	binding.queue_free()
	await process_frame
	for failure in _failures:
		push_error(failure)
	if _failures.is_empty():
		print("CINDER_ACTIVITY_FAILURE_SEMANTIC_AUDIO_TEST_OK: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _snapshot(
	kind: StringName, activity_id: StringName, generation: int, terminal_outcome: StringName
) -> Dictionary:
	var snapshot := {
		"generation": generation,
		"activity_kind": kind,
		"activity_id": activity_id,
		"state": &"active",
		"progress_unitless": 0.5,
		"checkpoint_id": &"",
		"reward_pending": false,
		"reset_serial": 0,
		"source_time_seconds": 1.0,
		"terminal_outcome": terminal_outcome,
	}
	if kind == &"mining":
		snapshot["mining_elapsed_seconds"] = 3.0
		snapshot["mining_extraction_seconds"] = 6.0
	return snapshot


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
