extends SceneTree

const JovianScene := preload("res://scenes/ships/jovian_light_freighter.tscn")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var jovian := JovianScene.instantiate() as Node
	root.add_child(jovian)
	await process_frame
	await process_frame
	var rig := jovian.get_node("ShipAudioRig") as ShipAudioRig
	var production: Dictionary = jovian.get_ship_perspective_audio_snapshot()
	_check(bool(production.attached), "Jovian production owner retains the perspective binding")
	_check(rig.get_audio_perspective() == ShipAudioRig.PERSPECTIVE_EXTERIOR, "Jovian starts in exterior perspective")
	jovian.set_cockpit_view(true)
	var cockpit := rig.get_perspective_mix_snapshot()
	_check(
		cockpit.perspective == ShipAudioRig.PERSPECTIVE_COCKPIT
			and float(cockpit.gain_db) < 0.0
			and float(cockpit.filter_cutoff_hz) < ShipAudioRig.ATTENUATION_FILTER_CUTOFF_HZ,
		"Jovian cockpit view attenuates and filters the resident rig"
	)
	jovian.set_cockpit_view(false)
	_check(rig.get_audio_perspective() == ShipAudioRig.PERSPECTIVE_EXTERIOR, "Jovian chase view restores exterior mix")
	root.remove_child(jovian)
	await process_frame
	root.add_child(jovian)
	await process_frame
	await process_frame
	var reentry: Dictionary = jovian.get_ship_perspective_audio_snapshot()
	_check(bool(reentry.attached), "Jovian perspective binding re-enters")
	_check(int(reentry.generation) == 1, "Jovian detach/re-entry advances perspective generation")
	_check(rig.get_audio_perspective() == ShipAudioRig.PERSPECTIVE_EXTERIOR, "Jovian re-entry resets to exterior")
	_check(int(rig.get_performance_report().maximum_simultaneous_voices) == 6, "Jovian perspective preserves the six-voice ceiling")
	_check(rig.get_audit_report().valid, "Jovian perspective mix remains auditable")
	jovian.queue_free()
	for failure in _failures:
		push_error(failure)
	print("jovian_perspective_audio_binding_test: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
