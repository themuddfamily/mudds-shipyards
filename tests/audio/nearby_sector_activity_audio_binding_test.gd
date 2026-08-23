extends SceneTree

const BindingScript := preload("res://scripts/audio/nearby_sector_activity_audio_binding.gd")
var _events: Array[Dictionary] = []
var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var binding := BindingScript.new()
	root.add_child(binding)
	binding.semantic_activity_cue_emitted.connect(_on_cue)
	_check(bool(binding.attach().accepted), "activity audio binding attaches")
	var active := _snapshot(&"race_caldera", &"active", 0.25, &"checkpoint_alpha", false, 0)
	_check(bool(binding.present_activity_snapshot(active).accepted), "activity snapshot is accepted")
	var count := _events.size()
	_check(bool(binding.present_activity_snapshot(active).accepted), "repeated activity snapshot is accepted")
	_check(_events.size() == count, "repeated snapshot does not spam cues")
	_check(_has_cue(&"activity_selected") and _has_cue(&"activity_started"), "selection and start cues emit")
	_check(_has_cue(&"activity_checkpoint") and _has_cue(&"activity_progress"), "checkpoint and progress cues emit")
	_check(bool(binding.present_activity_snapshot(_snapshot(&"race_caldera", &"complete", 1.0, &"checkpoint_beta", true, 0)).accepted), "completion snapshot is accepted")
	_check(_has_cue(&"activity_complete") and _has_cue(&"activity_reward_pending"), "completion and reward cues emit")
	_check(bool(binding.present_activity_snapshot(_snapshot(&"race_caldera", &"reset", 0.0, &"", false, 1)).accepted), "reset snapshot is accepted")
	_check(_has_cue(&"activity_reset"), "reset cue emits once")
	_check((binding.get_snapshot().authority as Dictionary).activity == false, "binding owns no activity authority")
	_check(int(binding.get_snapshot().maximum_simultaneous_voices) == 2, "cue stream has a bounded voice ceiling")
	_check(bool(binding.detach().accepted), "detach clears presentation state")
	_check(binding.present_activity_snapshot(active).reason == &"not_attached", "detached binding rejects snapshots")
	for failure in _failures:
		push_error(failure)
	print("nearby_sector_activity_audio_binding_test: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _snapshot(activity_id: StringName, state: StringName, progress: float, checkpoint: StringName, reward: bool, reset_serial: int) -> Dictionary:
	return {
		"activity_id": activity_id,
		"state": state,
		"progress_unitless": progress,
		"checkpoint_id": checkpoint,
		"reward_pending": reward,
		"reset_serial": reset_serial,
	}


func _on_cue(cue_id: StringName, activity_id: StringName, intensity: float) -> void:
	_events.append({"cue_id": cue_id, "activity_id": activity_id, "intensity": intensity})


func _has_cue(cue_id: StringName) -> bool:
	for event in _events:
		if event.cue_id == cue_id:
			return true
	return false


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
