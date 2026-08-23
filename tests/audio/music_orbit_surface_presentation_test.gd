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
	_check(bed.notify_music_phase(&"orbit"), "orbit phase is accepted")
	_check(bed.get_presentation_state() == &"orbit", "orbit selects the orbit presentation")
	var orbit_targets: Dictionary = bed.get_state_snapshot().layer_targets
	_check(float(orbit_targets[&"drone"]) == 0.9, "orbit uses the restrained authored drone mix")
	_check(bed.notify_music_phase(&"surface"), "surface phase is accepted")
	_check(bed.get_presentation_state() == &"surface", "surface selects the surface presentation")
	var surface_targets: Dictionary = bed.get_state_snapshot().layer_targets
	_check(float(surface_targets[&"harmonics"]) == 0.9, "surface brings forward the authored harmonic layer")
	_check(orbit_targets != surface_targets, "orbit and surface crossfade to distinct mixes")
	var director := bed.get_music_director()
	_check(director.advance(37.25), "director loop position advances")
	var position := float(director.get_snapshot().loop_position_seconds)
	root.remove_child(bed)
	root.add_child(bed)
	await process_frame
	_check(bed.get_presentation_state() == &"surface", "re-entry retains the presentation state")
	_check(
		is_equal_approx(float(director.get_snapshot().loop_position_seconds), position),
		"re-entry retains the bounded music loop position"
	)
	_check(
		int(bed.get_performance_report().maximum_simultaneous_voices) == 3,
		"presentation states preserve the three-voice ceiling"
	)
	for failure in _failures:
		push_error(failure)
	print("music_orbit_surface_presentation_test: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
