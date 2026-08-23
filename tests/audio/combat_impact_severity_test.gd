extends SceneTree

const PresentationScene := preload("res://scenes/audio/combat_audio_presentation.tscn")
var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var presentation := PresentationScene.instantiate()
	root.add_child(presentation)
	await process_frame
	_check(presentation.play_impact(Vector3.ZERO, 0.0, 7), "light impact accepts zero severity")
	var light := presentation.get_state_snapshot() as Dictionary
	_check(
		light.last_cue_id == &"hull_impact_light"
		and is_equal_approx(float(light.last_cue_pitch_scale), 1.08)
		and is_equal_approx(float(light.last_cue_volume_db), -5.0),
		"light impact selects the quiet high-pitch authored mix"
	)
	_check(presentation.play_impact(Vector3.ZERO, 1.5, 8), "heavy impact accepts capped severity")
	var heavy := presentation.get_state_snapshot() as Dictionary
	_check(
		heavy.last_cue_id == &"hull_impact_heavy"
		and is_equal_approx(float(heavy.last_cue_pitch_scale), 0.88)
		and is_equal_approx(float(heavy.last_cue_volume_db), -1.0),
		"heavy impact selects the bounded low-pitch louder authored mix"
	)
	_check(not presentation.play_impact(Vector3.ZERO, -0.1, 9), "negative severity fails closed")
	_check(
		int((presentation.get_audit_report() as Dictionary).maximum_simultaneous_voices) == 10,
		"severity variation preserves the fixed combat voice ceiling"
	)
	for failure in _failures:
		push_error(failure)
	print("combat_impact_severity_test: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
