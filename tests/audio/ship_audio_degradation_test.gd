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
	_check(rig.set_engine_running(true, false), "engine accepts the caller-owned running state")
	_check(rig.set_thrust_state(0.5), "engine accepts a neutral throttle fixture")
	var idle := rig.get_node("ThrustIdle") as AudioStreamPlayer3D
	var baseline_pitch := idle.pitch_scale
	var baseline_volume := idle.volume_db
	_check(rig.set_engine_degradation(0.75), "bounded engine degradation is accepted")
	_check(
		rig.get_engine_degradation() == 0.75
		and idle.pitch_scale < baseline_pitch
		and idle.volume_db < baseline_volume,
		"degradation lowers engine pitch and gain through the existing loop mix"
	)
	_check(not rig.set_engine_degradation(1.1), "out-of-range degradation fails closed")
	_check(
		int((rig.get_performance_report() as Dictionary).maximum_simultaneous_voices) == 6,
		"degradation preserves the fixed six-voice rig ceiling"
	)
	for failure in _failures:
		push_error(failure)
	print("ship_audio_degradation_test: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
