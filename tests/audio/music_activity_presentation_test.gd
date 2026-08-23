extends SceneTree

const MusicBedScene := preload("res://scenes/audio/station_music_bed.tscn")
var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var bed := MusicBedScene.instantiate() as StationMusicBed
	root.add_child(bed)
	await process_frame
	bed.set_process(false)
	_check(bed.notify_music_phase(&"orbit"), "orbit baseline is accepted")
	var director := bed.get_music_director()
	_check(director.advance(41.0), "retained orbit position advances")
	var position := float(director.get_snapshot().loop_position_seconds)
	_check(bed.notify_activity_state(&"race", &"active"), "race activity state is accepted")
	_check(bed.get_presentation_state() == &"activity_active", "activity active selects its bounded profile")
	_check(bed.notify_activity_state(&"race", &"complete"), "race completion is accepted")
	_check(bed.get_presentation_state() == &"activity_complete", "activity completion selects its bounded profile")
	_check(bed.notify_music_phase(&"orbit"), "completion returns to orbit presentation")
	_check(
		is_equal_approx(float(director.get_snapshot().loop_position_seconds), position),
		"completion and return retain the orbit loop position"
	)
	_check(bed.notify_music_phase(&"combat"), "combat phase is accepted")
	_check(not bed.notify_activity_state(&"patrol", &"active"), "combat preempts activity presentation")
	_check(bed.get_presentation_state() == &"combat", "combat remains the active presentation")
	_check(bool(director.get_audit_report().valid), "activity music director remains auditable")
	_check(int(bed.get_performance_report().maximum_simultaneous_voices) == 3, "activity profiles preserve three voices")
	for failure in _failures:
		push_error(failure)
	print("music_activity_presentation_test: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
