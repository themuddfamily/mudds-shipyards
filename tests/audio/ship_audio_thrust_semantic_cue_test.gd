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
	_check(bool(rig.set_thrust_state(0.5, false)), "thrust load engagement accepts caller state")
	_check(_has_cue(&"thrust_load_engaged"), "thrust load engagement emits a semantic cue")
	var count := _events.size()
	_check(bool(rig.set_thrust_state(0.5, false)), "repeated thrust load state is accepted")
	_check(_events.size() == count, "repeated thrust load state does not spam")
	_check(bool(rig.set_thrust_state(0.0, false)), "thrust load release accepts caller state")
	_check(_has_cue(&"thrust_load_released"), "thrust load release emits a semantic cue")
	_check(
		_events.all(func(event): return event.cue_id is StringName and event.intensity is float),
		"thrust payload remains typed"
	)
	for failure in _failures:
		push_error(failure)
	print("ship_audio_thrust_semantic_cue_test: %d assertions" % _assertions)
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
