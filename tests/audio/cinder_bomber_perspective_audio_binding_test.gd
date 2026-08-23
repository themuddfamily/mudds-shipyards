extends SceneTree

const Bomber := preload("res://scripts/ships/cinder_long_range_bomber.gd")
const ShipAudioRigScene := preload("res://scenes/audio/ship_audio_rig.tscn")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var bomber := Bomber.new()
	var rig := ShipAudioRigScene.instantiate() as ShipAudioRig
	bomber.add_child(rig)
	root.add_child(bomber)
	await process_frame
	await process_frame
	var production: Dictionary = bomber.get_ship_perspective_audio_snapshot()
	_check(bool(production.attached), "Cinder production bomber retains the perspective binding")
	_check(rig.get_audio_perspective() == ShipAudioRig.PERSPECTIVE_EXTERIOR, "Cinder starts in exterior perspective")
	_check(rig.set_engine_running(true, false), "Cinder engine fixture accepts running state")
	_check(rig.set_thrust_state(0.7, true), "Cinder engine fixture accepts payload-flight thrust")
	bomber.set_cockpit_view(true)
	var cockpit := rig.get_perspective_mix_snapshot()
	_check(
		cockpit.perspective == ShipAudioRig.PERSPECTIVE_COCKPIT
			and float(cockpit.gain_db) < 0.0
			and float(cockpit.filter_cutoff_hz) < ShipAudioRig.ATTENUATION_FILTER_CUTOFF_HZ,
		"Cinder cockpit view attenuates and filters engine/payload-adjacent voices"
	)
	bomber.set_cockpit_view(false)
	_check(rig.get_audio_perspective() == ShipAudioRig.PERSPECTIVE_EXTERIOR, "Cinder chase view restores exterior mix")
	root.remove_child(bomber)
	await process_frame
	root.add_child(bomber)
	await process_frame
	await process_frame
	var reentry: Dictionary = bomber.get_ship_perspective_audio_snapshot()
	_check(bool(reentry.attached), "Cinder perspective binding re-enters")
	_check(int(reentry.generation) == 1, "Cinder detach/re-entry advances perspective generation")
	_check(rig.get_audio_perspective() == ShipAudioRig.PERSPECTIVE_EXTERIOR, "Cinder re-entry resets to exterior")
	_check(int(rig.get_performance_report().maximum_simultaneous_voices) == 6, "Cinder perspective preserves the six-voice ceiling")
	_check(rig.get_audit_report().valid, "Cinder perspective mix remains auditable")
	bomber.queue_free()
	for failure in _failures:
		push_error(failure)
	print("cinder_bomber_perspective_audio_binding_test: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
