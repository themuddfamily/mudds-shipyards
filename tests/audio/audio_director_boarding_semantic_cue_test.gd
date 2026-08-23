extends SceneTree

const Director := preload("res://scripts/audio/audio_director.gd")
var _events: Array[Dictionary] = []
var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var director := Director.new()
	root.add_child(director)
	director.semantic_cue_emitted.connect(_on_cue)
	await process_frame
	director.play_canopy(true)
	director.play_canopy(false)
	_check(_has_cue(&"boarding_confirmed"), "canopy opening emits a boarding confirmation cue")
	_check(_has_cue(&"disembark_confirmed"), "canopy closing emits a disembark confirmation cue")
	_check(
		_events_are_typed(),
		"boarding cues preserve the normalized semantic contract"
	)
	_check(_events.size() == 2, "one semantic cue is emitted per accepted traversal transition")
	root.remove_child(director)
	director.free()
	for failure in _failures:
		push_error(failure)
	print("audio_director_boarding_semantic_cue_test: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _on_cue(source_id: StringName, cue_id: StringName, intensity: float, world_position: Vector3) -> void:
	_events.append({
		"source_id": source_id,
		"cue_id": cue_id,
		"intensity": intensity,
		"world_position": world_position,
	})


func _has_cue(cue_id: StringName) -> bool:
	for event in _events:
		if event.cue_id == cue_id:
			return true
	return false


func _events_are_typed() -> bool:
	for event in _events:
		if (
			event.source_id != &"audio_director"
			or not event.cue_id is StringName
			or not event.intensity is float
			or event.world_position != Vector3.ZERO
		):
			return false
	return true


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
