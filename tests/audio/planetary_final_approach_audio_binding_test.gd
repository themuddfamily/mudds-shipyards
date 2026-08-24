extends SceneTree

const Binding := preload("res://scripts/audio/planetary_final_approach_audio_binding.gd")

var _assertions := 0
var _failures := PackedStringArray()
var _events: Array[Dictionary] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var audio := Binding.new()
	audio.semantic_cue_emitted.connect(_on_cue)
	_check(bool(audio.attach().accepted), "final approach audio attaches")
	_check(bool(audio.present_snapshot({"final_approach": {"target_generation": 1, "state_id": &"armed", "reason": &"final_approach_armed"}}).accepted), "armed snapshot presents")
	_check(bool(audio.present_snapshot({"final_approach": {"target_generation": 1, "state_id": &"final_approach", "reason": &"final_approach_activated"}}).accepted), "alignment snapshot presents")
	_check(bool(audio.present_receipt({"target_generation": 1, "reason": &"final_approach_handoff_ready", "caller_tick": 9}).accepted), "handoff receipt presents")
	_check(_has(&"planetary_final_approach_armed") and _has(&"planetary_final_approach_alignment_ready") and _has(&"planetary_final_approach_handoff_ready"), "approach cues emit")
	var transition_snapshot := audio.get_snapshot()
	_check(
		int(transition_snapshot.maximum_simultaneous_voices) == 1
			and transition_snapshot.active_cue_slots == [&"planetary_final_approach_handoff_ready"]
			and _events.size() == 3,
		"one reusable voice retains the latest cue without merging rapid distinct transitions"
	)
	var duplicate := audio.present_snapshot({"final_approach": {"target_generation": 1, "state_id": &"armed", "reason": &"final_approach_armed"}})
	_check(duplicate.reason == &"duplicate_snapshot" and _events.size() == 3, "duplicate state does not spam")
	_check(audio.present_snapshot({"final_approach": {"target_generation": 0, "state_id": &"armed"}}).reason == &"stale_generation", "stale generation is rejected")
	_check(bool(audio.present_snapshot({"final_approach": {"target_generation": 2, "state_id": &"aborted", "reason": &"final_approach_aborted"}}).accepted), "abort presents rejection cue")
	_check(_has(&"planetary_final_approach_rejected"), "rejection cue emits")
	var rejection_snapshot := audio.get_snapshot()
	_check(
		int(rejection_snapshot.maximum_simultaneous_voices) == 1
			and rejection_snapshot.active_cue_slots == [&"planetary_final_approach_rejected"],
		"final approach reuses one bounded voice for the rejection identity"
	)
	_check(
		not bool(rejection_snapshot.authority.cruise)
			and not bool(rejection_snapshot.authority.travel)
			and not bool(rejection_snapshot.authority.landing)
			and bool(rejection_snapshot.authority.audio_cues),
		"voice reuse retains presentation-only authority"
	)
	_check(bool(audio.detach().accepted), "final approach audio detaches")
	_check((audio.get_snapshot().active_cue_slots as Array).is_empty(), "detach releases the reusable voice slot")
	_check(bool(audio.attach(1).accepted), "final approach audio re-enters")
	_check(bool(audio.present_receipt({"target_generation": 1, "reason": &"final_approach_handoff_ready", "caller_tick": 10}).accepted), "re-entry accepts a new receipt")
	_check(audio.get_snapshot().active_cue_slots == [&"planetary_final_approach_handoff_ready"], "re-entry reuses the single slot for a fresh cue")
	for failure in _failures:
		push_error(failure)
	print("PLANETARY_FINAL_APPROACH_AUDIO_BINDING_TEST: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)

func _on_cue(source_id: StringName, cue_id: StringName, intensity: float, position: Vector3) -> void:
	_events.append({"source_id": source_id, "cue_id": cue_id, "intensity": intensity, "position": position})

func _has(cue_id: StringName) -> bool:
	for event in _events:
		if event.cue_id == cue_id:
			return true
	return false

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
