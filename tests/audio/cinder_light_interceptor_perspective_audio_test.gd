extends SceneTree

const CRAFT := preload("res://scripts/ships/cinder_light_interceptor.gd")
const RIG_SCENE := preload("res://scenes/audio/ship_audio_rig.tscn")

var _assertions := 0
var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var craft := CRAFT.new()
	var rig := RIG_SCENE.instantiate()
	rig.name = "ShipAudioRig"
	craft.add_child(rig)
	root.add_child(craft)
	await process_frame
	var initial := craft.get_ship_perspective_audio_snapshot()
	_check(bool(initial.get("attached", false)), "Cinder light interceptor composes perspective audio")
	var generation := int(initial.get("generation", -1))
	craft.camera_view_changed.emit(craft.CAMERA_VIEW_COCKPIT)
	await process_frame
	var cockpit := craft.get_ship_perspective_audio_snapshot()
	_check(cockpit.get("perspective", &"") == &"cockpit", "cockpit view reaches the existing ShipAudioRig")
	craft.camera_view_changed.emit(craft.CAMERA_VIEW_CHASE)
	await process_frame
	_check(craft.get_ship_perspective_audio_snapshot().get("perspective", &"") == &"exterior", "chase view restores exterior mix")
	_check(int(craft.get_ship_perspective_audio_snapshot().get("generation", -1)) == generation, "perspective updates retain generation")
	craft.queue_free()
	await process_frame
	if _failures.is_empty():
		print("PASS cinder_light_interceptor_perspective_audio_test (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
