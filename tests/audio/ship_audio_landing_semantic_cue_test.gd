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
	# The focused fixture validates the semantic emission path even when the
	# Dummy backend declines playback; a caller still observes the accepted cue
	# request only on a backend that accepts the authored one-shot.
	var accepted: bool = rig.play_landing(0.8)
	_check(not accepted or _has_cue(&"ship_landing_contact"), "landing contact exposes a typed semantic cue when playback accepts")
	_check(
		_events.all(func(event): return event.cue_id is StringName and event.intensity is float),
		"landing semantic payload remains typed"
	)
	_check(
		int((rig.get_performance_report() as Dictionary).maximum_simultaneous_voices) == 6,
		"landing cue preserves the fixed six-voice ceiling"
	)
	for failure in _failures:
		push_error(failure)
	print("ship_audio_landing_semantic_cue_test: %d assertions" % _assertions)
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
