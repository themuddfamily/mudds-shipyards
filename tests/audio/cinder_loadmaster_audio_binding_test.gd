extends SceneTree

const Binding := preload("res://scripts/audio/cinder_loadmaster_audio_binding.gd")
const Cinder := preload("res://scripts/ships/cinder_cargo_hauler.gd")

var _assertions := 0
var _failures := PackedStringArray()
var _cues: Array[StringName] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var craft := Cinder.new()
	root.add_child(craft)
	await process_frame
	_check(is_instance_valid(craft), "real Cinder cargo craft instantiates")
	var audio := Binding.new()
	audio.semantic_loadmaster_cue_emitted.connect(func(cue_id: StringName, _intensity: float, _perspective: StringName) -> void: _cues.append(cue_id))
	_check(bool(audio.attach().accepted), "Cinder loadmaster audio attaches")
	_check(bool(audio.present_perspective(&"cabin").accepted), "Cinder cabin perspective is accepted")
	var receipt := {"seat_id": &"cinder_loadmaster_station", "manifest_generation": 1, "request_sequence": 4, "manifest_id": &"cinder_manifest", "route_id": &"cinder_route", "ready": true}
	_check(bool(audio.present_manifest_receipt(receipt).accepted), "Cinder manifest receipt is presented")
	_check(_cues.has(&"cinder_loadmaster_seat_occupied") and _cues.has(&"cinder_loadmaster_manifest_ready"), "seat and manifest cues emit")
	_check(audio.present_manifest_receipt(receipt).reason == &"duplicate_receipt", "duplicate manifest receipt is deduplicated")
	_check(bool(audio.present_rejected(&"stale_sequence", 5).accepted), "stale loadmaster result is presented")
	_check(bool(audio.present_released(&"role_released").accepted), "loadmaster release is presented")
	_check(int(audio.get_snapshot().maximum_simultaneous_voices) == 2, "Cinder loadmaster keeps two-voice ceiling")
	_check(bool(audio.detach().accepted), "Cinder loadmaster audio detaches")
	_check(bool(audio.attach(1).accepted), "Cinder loadmaster audio re-enters")
	_check(audio.present_manifest_receipt(receipt).reason == &"receipt_presented", "re-entry accepts retained receipt once")
	craft.queue_free()
	await process_frame
	for failure in _failures:
		push_error(failure)
	print("cinder_loadmaster_audio_binding_test: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
