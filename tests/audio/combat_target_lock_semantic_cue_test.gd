extends SceneTree

const PresentationScene := preload("res://scenes/audio/combat_audio_presentation.tscn")
var _events: Array[Dictionary] = []
var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var presentation := PresentationScene.instantiate()
	root.add_child(presentation)
	presentation.semantic_cue_emitted.connect(_on_cue)
	await process_frame
	var position := Vector3(4.0, 2.0, -3.0)
	_check(bool(presentation.set_target_lock(true, position)), "caller-owned target lock accepts acquisition")
	_check(_has_cue(&"target_lock_acquired"), "target lock acquisition emits a semantic cue")
	var count := _events.size()
	_check(bool(presentation.set_target_lock(true, position)), "repeated target lock is accepted")
	_check(_events.size() == count, "repeated target lock does not spam")
	_check(bool(presentation.set_target_lock(false, position)), "caller-owned target lock accepts loss")
	_check(_has_cue(&"target_lock_lost"), "target lock loss emits a semantic cue")
	_check(
		_events.all(func(event): return event.cue_id is StringName and event.world_position == position and event.intensity is float),
		"target-lock semantic payload remains typed"
	)
	presentation.free()
	for failure in _failures:
		push_error(failure)
	print("combat_target_lock_semantic_cue_test: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _on_cue(cue_id: StringName, world_position: Vector3, intensity: float) -> void:
	_events.append({"cue_id": cue_id, "world_position": world_position, "intensity": intensity})


func _has_cue(cue_id: StringName) -> bool:
	for event in _events:
		if event.cue_id == cue_id:
			return true
	return false


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
