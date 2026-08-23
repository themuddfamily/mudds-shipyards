extends SceneTree

const RigScene := preload("res://scenes/audio/ship_audio_rig.tscn")
var _events: Array[Dictionary] = []
var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var rig := RigScene.instantiate()
	root.add_child(rig)
	rig.semantic_engine_cue_emitted.connect(_on_cue)
	await process_frame
	rig.set_rig_enabled(false)
	_check(_events.is_empty(), "disabling the rig emits no recovery cue")
	rig.set_rig_enabled(true)
	_check(_has_cue(&"ship_audio_recovery_ready"), "re-enabling the rig emits a recovery-ready cue")
	var count := _events.size()
	rig.set_rig_enabled(true)
	_check(_events.size() == count, "repeated recovery-ready state does not spam")
	_check(
		_events.all(func(event): return event.cue_id is StringName and event.intensity is float),
		"recovery cue remains typed"
	)
	_check(
		int((rig.get_performance_report() as Dictionary).maximum_simultaneous_voices) == 6,
		"recovery cue preserves the fixed six-voice ceiling"
	)
	for failure in _failures:
		push_error(failure)
	print("ship_audio_recovery_semantic_cue_test: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _on_cue(cue_id: StringName, intensity: float) -> void:
	_events.append({"cue_id": cue_id, "intensity": intensity})


func _has_cue(cue_id: StringName) -> bool:
	for event in _events:
		if event.cue_id == cue_id:
			return true
	return false


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
