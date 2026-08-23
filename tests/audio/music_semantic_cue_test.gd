extends SceneTree

const BedScene := preload("res://scenes/audio/station_music_bed.tscn")
var _events: Array[Dictionary] = []
var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var bed := BedScene.instantiate()
	root.add_child(bed)
	bed.semantic_music_cue_emitted.connect(_on_cue)
	await process_frame
	_check(bed.notify_music_phase(&"landing"), "landing phase is accepted")
	_check(_has_cue(&"music_landing"), "landing emits a typed semantic music cue")
	var first_count := _events.size()
	_check(bed.notify_music_phase(&"landing"), "repeated landing phase is accepted")
	_check(_events.size() == first_count, "repeated phase emits no semantic spam")
	_check(bed.notify_music_phase(&"combat"), "combat phase is accepted")
	_check(bed.set_combat_mix_intensity(0.75), "combat tension is accepted")
	_check(_has_cue(&"music_combat") and _has_cue(&"music_combat_tension"), "combat and tension cues are emitted")
	_check(bed.set_combat_mix_intensity(0.75), "repeated tension is accepted")
	_check(_count_cue(&"music_combat_tension") == 1, "steady tension emits once")
	_check(bed.notify_music_phase(&"station"), "station return phase is accepted")
	_check(_has_cue(&"music_return_station"), "station return emits a typed semantic cue")
	_check(_events.all(func(event): return event.cue_id is StringName and event.intensity is float), "semantic payload contains no free text")
	for failure in _failures:
		push_error(failure)
	print("music_semantic_cue_test: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _on_cue(cue_id: StringName, intensity: float) -> void:
	_events.append({"cue_id": cue_id, "intensity": intensity})


func _has_cue(cue_id: StringName) -> bool:
	return _count_cue(cue_id) > 0


func _count_cue(cue_id: StringName) -> int:
	var count := 0
	for event in _events:
		if event.cue_id == cue_id:
			count += 1
	return count


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
