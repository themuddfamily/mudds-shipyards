extends SceneTree

const AmbienceScene := preload("res://scenes/audio/station_machinery_ambience.tscn")
var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var ambience := AmbienceScene.instantiate()
	root.add_child(ambience)
	await process_frame
	var loop := ambience.get_node("MachineryLoop") as AudioStreamPlayer3D
	var baseline := loop.volume_db
	_check(ambience.set_room_mix(0.0, 1.0), "near open-room mix is accepted")
	_check(is_equal_approx(loop.volume_db, baseline), "near open-room machinery stays at authored gain")
	_check(ambience.set_room_mix(1.0, 0.0), "far occluded mix is accepted")
	_check(loop.volume_db < baseline - 29.9, "distance and room occlusion attenuate machinery locally")
	var snapshot := ambience.get_room_mix_snapshot() as Dictionary
	_check(
		is_equal_approx(float(snapshot.caller_distance), 1.0)
		and is_equal_approx(float(snapshot.room_exposure), 0.0),
		"caller room mix state is detached and inspectable"
	)
	_check(not ambience.set_room_mix(1.1, 0.5), "out-of-range room mix fails closed")
	_check(
		int((ambience.get_performance_report() as Dictionary).maximum_simultaneous_voices) == 2,
		"room mix preserves the fixed two-voice ceiling"
	)
	for failure in _failures:
		push_error(failure)
	print("station_machinery_room_mix_test: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
