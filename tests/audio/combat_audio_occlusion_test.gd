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
	_check(presentation.set_occlusion(0.0), "exterior occlusion baseline is accepted")
	_check(presentation.play_impact(Vector3.ZERO, 0.0, 7), "exterior impact plays")
	var exterior := presentation.get_state_snapshot() as Dictionary
	_check(
		is_equal_approx(float(exterior.last_cue_volume_db), -5.0)
		and is_equal_approx(float(exterior.last_cue_pitch_scale), 1.08),
		"exterior combat playback remains unchanged"
	)
	_check(presentation.set_occlusion(1.0), "fully occluded presentation is accepted")
	_check(presentation.play_impact(Vector3.ZERO, 0.0, 8), "occluded impact plays")
	var interior := presentation.get_state_snapshot() as Dictionary
	_check(
		is_equal_approx(float(interior.last_cue_volume_db), -17.0)
		and is_equal_approx(float(interior.last_cue_pitch_scale), 1.0368)
		and is_equal_approx(float(interior.occlusion), 1.0),
		"interior combat playback applies bounded attenuation and muffling"
	)
	_check(not presentation.set_occlusion(1.1), "out-of-range occlusion fails closed")
	_check(
		int((presentation.get_audit_report() as Dictionary).maximum_simultaneous_voices) == 10,
		"occlusion preserves the fixed combat voice ceiling"
	)
	for failure in _failures:
		push_error(failure)
	print("combat_audio_occlusion_test: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
