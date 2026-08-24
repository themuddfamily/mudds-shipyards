extends SceneTree

const AudioDirectorScript := preload("res://scripts/audio/audio_director.gd")
const ActivityAudioScript := preload("res://scripts/audio/nearby_sector_activity_audio_binding.gd")
const CuePresenterScript := preload("res://scripts/ui/semantic_audio_cue_presenter.gd")

var _assertions := 0
var _failures: Array[String] = []
var _events: Array[Dictionary] = []

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var host := Node.new()
	root.add_child(host)
	var director := AudioDirectorScript.new()
	director.name = "AudioDirector"
	host.add_child(director)
	var binding := ActivityAudioScript.new()
	host.add_child(binding)
	director.semantic_cue_emitted.connect(func(source_id: StringName, cue_id: StringName,
			intensity: float, _position: Vector3) -> void:
		_events.append({"source_id": source_id, "cue_id": cue_id, "intensity": intensity}))
	await process_frame
	_check(bool(binding.attach().accepted)
		and bool(binding.get_snapshot().semantic_output_bound),
		"production activity source auto-attaches to the authored semantic AudioDirector route")

	var active := _patrol(7, &"active", false)
	_check(bool(binding.present_activity_snapshot(active).accepted)
		and _has(&"activity", &"activity_selected")
		and _has(&"activity", &"activity_started"),
		"real retained patrol activation reaches semantic audio/accessibility output")
	var after_active := _events.size()
	_check(bool(binding.present_activity_snapshot(active).accepted) and _events.size() == after_active,
		"identical patrol state in one activity generation emits no duplicate cues")
	_check(binding.present_activity_snapshot(_patrol(6, &"complete", false)).reason \
		== &"stale_activity_generation" and _events.size() == after_active,
		"stale patrol generation is rejected before semantic output")

	_check(bool(binding.present_activity_snapshot(_patrol(7, &"complete", false)).accepted)
		and _count(&"cinder_patrol_completed") == 1
		and _has(&"activity", &"cinder_patrol_completed")
		and is_equal_approx(_last_intensity(&"cinder_patrol_completed"), 1.0)
		and _count(&"activity_complete") == 0,
		"patrol completion produces one distinct full-intensity semantic event")
	var completion_event := _events[-1] as Dictionary
	var presentation := CuePresenterScript.new().present_cue(
		completion_event.cue_id, completion_event.source_id, completion_event.intensity,
		Vector3.ZERO, {"transition_id": "patrol-7-complete"}
	)
	_check(bool(presentation.accepted) and presentation.caption == "Patrol complete"
		and bool(presentation.presentation_only),
		"routed patrol completion is accepted by the HUD semantic cue presenter")
	var after_complete := _events.size()
	_check(bool(binding.present_activity_snapshot(_patrol(7, &"complete", false)).accepted)
		and _events.size() == after_complete,
		"retained patrol completion does not replay its audible semantic event")
	_check(bool(binding.present_activity_snapshot(_patrol(7, &"complete", true)).accepted)
		and _count(&"activity_reward_pending") == 1,
		"generation-matched reward pending produces one existing reward semantic event")

	director.set_reduced_dynamic_range(true)
	var before_reduced := _events.size()
	binding.present_activity_snapshot(_patrol(8, &"active", false))
	var reduced_events := _events.slice(before_reduced)
	_check(reduced_events.size() == 2 and reduced_events.all(func(event: Dictionary) -> bool:
		return is_equal_approx(float(event.intensity), 0.75)),
		"fresh-generation patrol cues follow the live reduced-dynamic-range policy")

	var before_detach := _events.size()
	_check(bool(binding.detach().accepted)
		and binding.present_activity_snapshot(_patrol(8, &"active", false)).reason == &"not_attached",
		"detached presentation rejects activity state")
	_check(bool(binding.attach(1).accepted)
		and bool(binding.present_activity_snapshot(_patrol(8, &"active", false)).accepted)
		and _events.size() == before_detach,
		"re-entry rebinds semantic output without replaying the retained generation")
	binding.present_activity_snapshot(_patrol(9, &"active", false))
	_check(_events.size() == before_detach + 2
		and bool(binding.get_snapshot().semantic_output_bound)
		and int(binding.get_snapshot().tracked_activity_count) == 1,
		"a fresh post-reentry activity generation emits once through the restored route")
	var authority := binding.get_snapshot().authority as Dictionary
	_check(not bool(authority.activity) and not bool(authority.reward)
		and not bool(authority.gameplay) and bool(authority.audio_cues),
		"composition adds semantic cue ownership only")

	host.queue_free()
	await process_frame
	for failure in _failures: push_error(failure)
	if _failures.is_empty():
		print("NEARBY_PATROL_SEMANTIC_AUDIO_PRODUCTION_TEST_OK: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)

func _patrol(generation: int, state: StringName, reward_pending: bool) -> Dictionary:
	return {"generation": generation, "activity_kind": &"patrol",
		"activity_id": &"cinder_relay_patrol", "state": state,
		"progress_unitless": 1.0 if state == &"complete" else 0.0,
		"checkpoint_id": &"", "reward_pending": reward_pending, "reset_serial": 0}

func _has(source_id: StringName, cue_id: StringName) -> bool:
	return _events.any(func(event: Dictionary) -> bool:
		return event.source_id == source_id and event.cue_id == cue_id)

func _count(cue_id: StringName) -> int:
	var count := 0
	for event in _events:
		if event.cue_id == cue_id: count += 1
	return count

func _last_intensity(cue_id: StringName) -> float:
	for index in range(_events.size() - 1, -1, -1):
		if _events[index].cue_id == cue_id: return float(_events[index].intensity)
	return -1.0

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition: _failures.append(message)
