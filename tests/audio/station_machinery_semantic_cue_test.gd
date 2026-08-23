extends SceneTree

const AmbienceScene := preload("res://scenes/audio/station_machinery_ambience.tscn")
var _events: Array[Dictionary] = []
var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var ambience := AmbienceScene.instantiate()
	root.add_child(ambience)
	ambience.semantic_maintenance_cue_emitted.connect(_on_cue)
	await process_frame
	ambience.set_ambience_enabled(false)
	_check(_has_cue(&"station_machinery_offline"), "maintenance-offline state emits a semantic cue")
	ambience.set_ambience_enabled(true)
	_check(_has_cue(&"station_machinery_available"), "maintenance-available state emits a semantic cue")
	var count := _events.size()
	ambience.set_ambience_enabled(true)
	_check(_events.size() == count, "repeated maintenance state does not spam")
	_check(
		_events.all(func(event): return event.cue_id is StringName and event.intensity is float),
		"maintenance semantic payload remains typed"
	)
	for failure in _failures:
		push_error(failure)
	print("station_machinery_semantic_cue_test: %d assertions" % _assertions)
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
