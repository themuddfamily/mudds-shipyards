extends SceneTree

## Presentation audit for the states the player reaches by leaving the station.
##
## The first half checks the authored mix profile each state selects. The second
## half checks the thing a player actually hears: orbit and surface are scored
## with their own authored beds, the change is a cross-fade rather than a cut,
## and returning to the station restores the original station mix.
##
## Nothing here can establish that the beds sound good. Every check is
## structural; musical acceptance remains an outstanding human listening pass.

const MusicBedScene := preload("res://scenes/audio/station_music_bed.tscn")

const STATION_PATHS := {
	&"drone": "res://assets/audio/music/station_bed_drone_v1.wav",
	&"harmonics": "res://assets/audio/music/station_bed_harmonics_v1.wav",
	&"motif": "res://assets/audio/music/station_bed_motif_v1.wav",
}
const FLIGHT_PATHS := {
	&"drone": "res://assets/audio/music/flight_bed_drift_v1.wav",
	&"harmonics": "res://assets/audio/music/flight_bed_shimmer_v1.wav",
	&"motif": "res://assets/audio/music/flight_bed_signal_v1.wav",
}
const SURFACE_PATHS := {
	&"drone": "res://assets/audio/music/surface_bed_warmth_v1.wav",
	&"harmonics": "res://assets/audio/music/surface_bed_choir_v1.wav",
	&"motif": "res://assets/audio/music/surface_bed_pulse_v1.wav",
}

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await _test_state_profiles()
	await _test_bed_cross_fade()
	for failure in _failures:
		push_error(failure)
	print("music_orbit_surface_presentation_test: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _test_state_profiles() -> void:
	var bed := MusicBedScene.instantiate() as StationMusicBed
	root.add_child(bed)
	await process_frame
	bed.set_process(false)
	_check(bed.notify_music_phase(&"orbit"), "orbit phase is accepted")
	_check(bed.get_presentation_state() == &"orbit", "orbit selects the orbit presentation")
	var orbit_targets: Dictionary = bed.get_state_snapshot().layer_targets
	_check(float(orbit_targets[&"drone"]) == 0.9, "orbit uses the restrained authored drone mix")
	_check(
		bed.get_bed_family() == StationMusicBed.FAMILY_FLIGHT,
		"orbit is scored with the authored flight bed"
	)
	_check(bed.notify_music_phase(&"surface"), "surface phase is accepted")
	_check(bed.get_presentation_state() == &"surface", "surface selects the surface presentation")
	var surface_targets: Dictionary = bed.get_state_snapshot().layer_targets
	_check(float(surface_targets[&"harmonics"]) == 0.9, "surface brings forward the authored harmonic layer")
	_check(orbit_targets != surface_targets, "orbit and surface crossfade to distinct mixes")
	_check(
		bed.get_bed_family() == StationMusicBed.FAMILY_SURFACE,
		"surface is scored with its own authored bed rather than the orbit bed"
	)
	var director := bed.get_music_director()
	_check(
		director.get_bed_family() == StationMusicBed.FAMILY_SURFACE,
		"the director reports the same authored bed as the backend"
	)
	_check(director.advance(37.25), "director loop position advances")
	var position := float(director.get_snapshot().loop_position_seconds)
	root.remove_child(bed)
	root.add_child(bed)
	await process_frame
	_check(bed.get_presentation_state() == &"surface", "re-entry retains the presentation state")
	_check(
		bed.get_bed_family() == StationMusicBed.FAMILY_SURFACE,
		"re-entry retains the selected authored bed"
	)
	_check(
		is_equal_approx(float(director.get_snapshot().loop_position_seconds), position),
		"re-entry retains the bounded music loop position"
	)
	_check(
		int(bed.get_performance_report().maximum_simultaneous_voices) == 3,
		"presentation states preserve the three-voice ceiling"
	)

	# Accessibility mute still silences every layer of the plan in the new
	# states, and does not disturb which bed those states are scored with.
	var muted := director.set_accessibility_muted(true) as Dictionary
	_check(
		bool(muted.accessibility_muted)
		and (muted.layer_gains as Dictionary).values().all(
			func(value): return is_equal_approx(float(value), 0.0)
		),
		"accessibility mute silences the surface plan"
	)
	_check(
		StringName(muted.bed_family) == StationMusicBed.FAMILY_SURFACE,
		"accessibility mute silences the bed without reselecting it"
	)
	director.observe_phase(&"orbit")
	_check(
		(director.get_mix_plan().layer_gains as Dictionary).values().all(
			func(value): return is_equal_approx(float(value), 0.0)
		),
		"accessibility mute survives a state change into orbit"
	)
	director.set_accessibility_muted(false)
	_check(
		float((director.get_mix_plan().layer_gains as Dictionary)[&"bed"]) > 0.0
		and StringName(director.get_mix_plan().bed_family) == StationMusicBed.FAMILY_FLIGHT,
		"unmuting restores the orbit mix on the flight bed"
	)

	_release(bed)
	await process_frame


## Drives the bed one fixed step at a time across station -> orbit -> surface ->
## station and checks what is actually loaded and sounding at each point.
func _test_bed_cross_fade() -> void:
	var bed := MusicBedScene.instantiate() as StationMusicBed
	bed.name = "CrossFadeBed"
	root.add_child(bed)
	await process_frame
	bed.set_process(false)

	_advance(bed, 10.0)
	_check(
		_slot_paths(bed) == STATION_PATHS
		and bed.get_bed_family() == StationMusicBed.FAMILY_STATION,
		"a settled station bed holds the three station loops"
	)
	var station_gains := (bed.get_state_snapshot().layer_gains as Dictionary).duplicate()
	_check(
		float(station_gains[&"drone"]) > 0.99 and float(station_gains[&"motif"]) > 0.99,
		"the station mix settles at its authored full level"
	)

	_check(bed.notify_music_phase(&"orbit"), "leaving the station for orbit is accepted")
	_check(
		bool(bed.get_state_snapshot().bed_family_handoff_active),
		"the orbit change opens a hand-over instead of cutting the bed"
	)
	_advance(bed, 1.5)
	var crossfade := bed.get_state_snapshot() as Dictionary
	var crossfade_gains := crossfade.layer_gains as Dictionary
	var crossfade_paths := _slot_paths(bed)
	_check(
		String(crossfade_paths[&"drone"]) == String(FLIGHT_PATHS[&"drone"])
		and float(crossfade_gains[&"drone"]) > StationMusicBed.MINIMUM_AUDIBLE_GAIN,
		"mid-change the orbit bed's floor is already sounding"
	)
	_check(
		String(crossfade_paths[&"harmonics"]) == String(STATION_PATHS[&"harmonics"])
		and float(crossfade_gains[&"harmonics"]) > StationMusicBed.MINIMUM_AUDIBLE_GAIN
		and float(crossfade_gains[&"harmonics"]) < float(station_gains[&"harmonics"]),
		"the station layers are still audible and fading down, so the change is a cross-fade"
	)
	_check(
		float(crossfade_gains[&"motif"]) < float(station_gains[&"motif"]),
		"the station bell motif is on its way out during the cross-fade"
	)
	_check(bool(bed.get_audit_report().valid), "the bed stays inside its audit mid-cross-fade")

	_advance(bed, 10.0)
	var orbit := bed.get_state_snapshot() as Dictionary
	_check(
		_slot_paths(bed) == FLIGHT_PATHS
		and not bool(orbit.bed_family_handoff_active),
		"orbit settles on the three flight loops"
	)
	_check(
		is_equal_approx(float((orbit.layer_gains as Dictionary)[&"drone"]), 0.9),
		"orbit reaches its authored drift level"
	)
	var orbit_performance := bed.get_performance_report() as Dictionary
	_check(
		int(orbit_performance.resident_stream_count) == 3
		and int(orbit_performance.maximum_simultaneous_voices) == 3
		and bool(orbit_performance.within_resident_budget),
		"the orbit bed costs the same three voices and stays inside the resident budget"
	)
	_check(bool(bed.get_audit_report().valid), "the settled orbit bed passes its audit")

	_check(bed.notify_music_phase(&"surface"), "landing on a surface is accepted")
	_advance(bed, 10.0)
	var surface := bed.get_state_snapshot() as Dictionary
	_check(
		_slot_paths(bed) == SURFACE_PATHS
		and not bool(surface.bed_family_handoff_active),
		"the surface state settles on the three surface loops, including the slow pulse"
	)
	_check(
		is_equal_approx(float((surface.layer_gains as Dictionary)[&"harmonics"]), 0.9)
		and float((surface.layer_gains as Dictionary)[&"motif"]) > StationMusicBed.MINIMUM_AUDIBLE_GAIN,
		"the surface pad and pulse are both audible once settled"
	)
	_check(
		(surface.layer_gains as Dictionary) != (orbit.layer_gains as Dictionary),
		"orbit and surface settle on audibly different mixes"
	)
	_check(bool(bed.get_audit_report().valid), "the settled surface bed passes its audit")

	_check(bed.notify_music_phase(&"station"), "returning to the station is accepted")
	_advance(bed, 14.0)
	var returned := bed.get_state_snapshot() as Dictionary
	_check(
		_slot_paths(bed) == STATION_PATHS
		and not bool(returned.bed_family_handoff_active),
		"returning to the station restores the three station loops"
	)
	_check(
		(returned.layer_gains as Dictionary) == station_gains,
		"returning to the station restores the original station mix"
	)
	_check(
		int(returned.bed_family_handoff_count) == 9,
		"each of the three round-trip changes hands over all three loop slots"
	)
	_check(
		int(bed.get_performance_report().maximum_simultaneous_voices) == 3,
		"the whole round trip never exceeds the three-voice ceiling"
	)
	_check(bool(bed.get_audit_report().valid), "the returned station bed passes its audit")

	_release(bed)
	await process_frame


func _advance(bed: StationMusicBed, seconds: float) -> void:
	var step := 1.0 / 60.0
	for _index in maxi(1, roundi(seconds * 60.0)):
		bed.call("_process", step)


func _slot_paths(bed: StationMusicBed) -> Dictionary:
	var paths := {}
	var streams := bed.get("_streams") as Dictionary
	for layer_id in StationMusicBed.LAYER_IDS:
		var stream := streams.get(layer_id) as AudioStreamWAV
		paths[layer_id] = "" if stream == null else stream.resource_path
	return paths


func _release(bed: StationMusicBed) -> void:
	bed.set_bed_enabled(false)
	bed.release_audio_resources()
	bed.queue_free()


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
