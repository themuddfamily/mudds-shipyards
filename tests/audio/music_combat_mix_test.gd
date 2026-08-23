extends SceneTree

const BedScene := preload("res://scenes/audio/station_music_bed.tscn")
var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var bed := BedScene.instantiate()
	root.add_child(bed)
	await process_frame
	_check(bool(bed.notify_session_state(&"combat")), "combat phase accepts the caller-owned state")
	var silent_targets := bed.get_state_snapshot().layer_targets as Dictionary
	_check(
		is_equal_approx(float(silent_targets.drone), 0.0)
		and is_equal_approx(float(silent_targets.harmonics), 0.0),
		"combat remains silent until a presentation intensity is supplied"
	)
	_check(bed.set_combat_mix_intensity(0.75), "bounded combat mix intensity is accepted")
	_check(
		is_equal_approx(bed.get_music_director().get_combat_intensity(), 0.75),
		"combat intensity is recorded by the presentation music director"
	)
	var tension_targets := bed.get_state_snapshot().layer_targets as Dictionary
	_check(
		is_equal_approx(float(tension_targets.drone), 0.09)
		and is_equal_approx(float(tension_targets.harmonics), 0.045)
		and is_equal_approx(float(tension_targets.motif), 0.0),
		"combat intensity exposes a quiet resident tension mix"
	)
	_check(not bed.set_combat_mix_intensity(1.1), "out-of-range combat intensity fails closed")
	_check(
		int((bed.get_performance_report() as Dictionary).maximum_simultaneous_voices) == 3,
		"combat tension reuses the existing three-voice ceiling"
	)
	for failure in _failures:
		push_error(failure)
	print("music_combat_mix_test: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
