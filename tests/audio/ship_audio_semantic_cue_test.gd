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
	_check(rig.set_engine_degradation(0.25), "degraded threshold is accepted")
	_check(_events.size() == 1 and _has_cue(&"engine_degraded"), "degraded crossing emits a typed cue")
	_check(rig.set_engine_degradation(0.25), "repeated degradation is accepted")
	_check(_events.size() == 1, "repeated degradation does not spam cues")
	_check(rig.set_engine_degradation(0.75), "critical threshold is accepted")
	_check(_has_cue(&"engine_critical"), "critical crossing emits a typed cue")
	_check(rig.set_engine_degradation(0.1), "recovery threshold is accepted")
	_check(_has_cue(&"engine_recovered"), "recovery crossing emits a typed cue")
	_check(rig.set_engine_velocity(0.75), "high-load threshold is accepted")
	_check(_has_cue(&"engine_load_high"), "high-load crossing emits a typed cue")
	var count_after_high := _events.size()
	_check(rig.set_engine_velocity(0.75), "repeated high-load state is accepted")
	_check(_events.size() == count_after_high, "repeated high-load state does not spam cues")
	_check(rig.set_engine_velocity(0.2), "normal-load threshold is accepted")
	_check(_has_cue(&"engine_load_normal"), "normal-load crossing emits a typed cue")
	_check(
		_events.all(func(event): return event.cue_id is StringName and event.intensity is float),
		"semantic payloads use typed IDs and numeric intensity only"
	)
	_check(
		int((rig.get_performance_report() as Dictionary).maximum_simultaneous_voices) == 6,
		"semantic cues preserve the fixed six-voice rig ceiling"
	)
	for failure in _failures:
		push_error(failure)
	print("ship_audio_semantic_cue_test: %d assertions" % _assertions)
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
