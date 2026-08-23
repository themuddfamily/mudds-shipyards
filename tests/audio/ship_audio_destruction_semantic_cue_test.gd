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
	var playback_result: bool = rig.play_destruction(0.9)
	_check(_has_cue(&"ship_destroyed"), "accepted destruction state emits a semantic cue")
	_check(
		_events.size() == 1
		and _events[0].cue_id is StringName
		and is_equal_approx(float(_events[0].intensity), 0.9),
		"destruction cue carries a typed bounded intensity"
	)
	_check(
		int((rig.get_performance_report() as Dictionary).maximum_simultaneous_voices) == 6,
		"destruction cue preserves the fixed six-voice ceiling"
	)
	_check(playback_result is bool, "destruction playback result remains caller-owned")
	for failure in _failures:
		push_error(failure)
	print("ship_audio_destruction_semantic_cue_test: %d assertions" % _assertions)
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
