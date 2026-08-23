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
	_check(rig.set_damage_alarm_active(true), "damage alarm accepts activation")
	_check(_has_cue(&"engine_damage_alarm"), "alarm activation emits a semantic cue")
	var first_count := _events.size()
	_check(not rig.set_damage_alarm_active(true), "repeated alarm activation is ignored")
	_check(_events.size() == first_count, "repeated alarm state does not spam")
	_check(rig.set_damage_alarm_active(false), "damage alarm accepts recovery")
	_check(_has_cue(&"engine_damage_alarm_cleared"), "alarm recovery emits a semantic cue")
	_check(
		_events.all(func(event): return event.cue_id is StringName and event.intensity is float),
		"alarm cues remain typed and numeric"
	)
	for failure in _failures:
		push_error(failure)
	print("ship_audio_alarm_semantic_cue_test: %d assertions" % _assertions)
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
