extends SceneTree

const ArrowScene := preload("res://scenes/ships/arrow_recon_ship.tscn")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var arrow := ArrowScene.instantiate() as Node
	root.add_child(arrow)
	await process_frame
	await process_frame
	var rig := arrow.get_node("ShipAudioRig") as ShipAudioRig
	var adapter := arrow.get_node("ShipPerspectiveAudioAdapter")
	_check(bool(adapter.get_snapshot().attached), "Arrow scene composes the perspective audio adapter")
	_check(rig.get_audio_perspective() == ShipAudioRig.PERSPECTIVE_EXTERIOR, "Arrow starts in exterior perspective")
	arrow.set_cockpit_view(true)
	var cockpit := rig.get_perspective_mix_snapshot()
	_check(
		cockpit.perspective == ShipAudioRig.PERSPECTIVE_COCKPIT
			and float(cockpit.gain_db) < 0.0
			and float(cockpit.filter_cutoff_hz) < ShipAudioRig.ATTENUATION_FILTER_CUTOFF_HZ,
		"Arrow cockpit view reaches the resident rig mix/filter"
	)
	arrow.set_cockpit_view(false)
	_check(rig.get_audio_perspective() == ShipAudioRig.PERSPECTIVE_EXTERIOR, "Arrow chase view restores exterior mix")
	root.remove_child(arrow)
	await process_frame
	root.add_child(arrow)
	await process_frame
	await process_frame
	var reentry: Dictionary = arrow.get_node("ShipPerspectiveAudioAdapter").get_snapshot()
	_check(bool(reentry.attached), "Arrow perspective adapter re-enters")
	_check(int(reentry.generation) == 1, "Arrow detach/re-entry advances perspective generation")
	_check(rig.get_audio_perspective() == ShipAudioRig.PERSPECTIVE_EXTERIOR, "Arrow re-entry resets to exterior")
	_check(int(rig.get_performance_report().maximum_simultaneous_voices) == 6, "Arrow perspective preserves the six-voice ceiling")
	_check(rig.get_audit_report().valid, "Arrow perspective mix remains auditable")
	arrow.queue_free()
	for failure in _failures:
		push_error(failure)
	print("arrow_perspective_audio_scene_adapter_test: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
