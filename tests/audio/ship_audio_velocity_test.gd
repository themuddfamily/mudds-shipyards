extends SceneTree

const RigScene := preload("res://scenes/audio/ship_audio_rig.tscn")
var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var rig := RigScene.instantiate()
	root.add_child(rig)
	await process_frame
	_check(rig.set_engine_running(true, false), "engine accepts the running fixture")
	_check(rig.set_thrust_state(0.5), "throttle fixture is accepted")
	var idle := rig.get_node("ThrustIdle") as AudioStreamPlayer3D
	var baseline_pitch := idle.pitch_scale
	var baseline_volume := idle.volume_db
	_check(rig.set_engine_velocity(1.0), "caller velocity envelope is accepted")
	_check(
		rig.get_engine_velocity() == 1.0
		and idle.pitch_scale > baseline_pitch
		and idle.volume_db > baseline_volume,
		"velocity raises existing engine-loop pitch and gain"
	)
	_check(not rig.set_engine_velocity(1.1), "out-of-range velocity fails closed")
	_check(
		int((rig.get_performance_report() as Dictionary).maximum_simultaneous_voices) == 6,
		"velocity response preserves the fixed rig voice ceiling"
	)
	for failure in _failures:
		push_error(failure)
	print("ship_audio_velocity_test: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
