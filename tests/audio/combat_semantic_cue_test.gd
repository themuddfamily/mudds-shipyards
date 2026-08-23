extends SceneTree

const PresentationScene := preload("res://scenes/audio/combat_audio_presentation.tscn")
var _assertions := 0
var _events: Array[Dictionary] = []
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var presentation := PresentationScene.instantiate()
	root.add_child(presentation)
	presentation.semantic_cue_emitted.connect(_on_semantic_cue)
	await process_frame
	_check(presentation.play_player_fire(Vector3(1, 2, 3), 7), "fire cue is accepted")
	_check(presentation.play_impact(Vector3(4, 5, 6), 1.5, 8), "impact cue is accepted")
	_check(presentation.play_explosion(Vector3(7, 8, 9), 9), "explosion cue is accepted")
	_check(_events.size() == 3, "accepted combat cues emit exactly one semantic event each")
	if _events.size() == 3:
		_check(
			_events[0].cue_id == &"player_pulse_fire"
			and _events[1].cue_id == &"hull_impact_heavy"
			and _events[2].cue_id == &"ship_explosion",
			"semantic events retain stable authored cue IDs"
		)
		_check(
			_events[1].position == Vector3(4, 5, 6)
			and is_equal_approx(float(_events[1].intensity), 1.0),
			"semantic impact event carries position and bounded intensity"
		)
	_check(not presentation.play_impact(Vector3.ZERO, -1.0, 10), "rejected cue emits no semantic event")
	_check(
		int((presentation.get_audit_report() as Dictionary).maximum_simultaneous_voices) == 10,
		"semantic emission preserves the fixed combat voice ceiling"
	)
	for failure in _failures:
		push_error(failure)
	print("combat_semantic_cue_test: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _on_semantic_cue(cue_id: StringName, position: Vector3, intensity: float) -> void:
	_events.append({"cue_id": cue_id, "position": position, "intensity": intensity})


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
