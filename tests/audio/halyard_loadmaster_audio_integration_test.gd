extends SceneTree

const AudioBinding := preload("res://scripts/audio/halyard_loadmaster_audio_binding.gd")
const HalyardScene := preload("res://scenes/ships/halyard_crew_transport.tscn")

var _events: Array[Dictionary] = []
var _assertions := 0
var _failures := PackedStringArray()

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var audio := AudioBinding.new()
	audio.semantic_loadmaster_cue_emitted.connect(_on_cue)
	_check(bool(audio.attach().accepted), "loadmaster audio binding attaches")
	_check(bool(audio.present_perspective(&"cabin").accepted), "cabin perspective is accepted")
	var receipt := {"seat_id": &"crew_port_00", "manifest_generation": 1, "request_sequence": 3,
		"manifest_id": &"halyard_manifest", "route_id": &"ember_surface" , "ready": true}
	_check(bool(audio.present_accepted_receipt(receipt).accepted), "accepted loadmaster receipt is presented")
	_check(_has(&"loadmaster_route_confirmed") and _has(&"loadmaster_manifest_ready"), "route and readiness cues emit")
	_check(bool(audio.present_accepted_receipt(receipt).accepted), "duplicate receipt is safely accepted")
	_check(_events.size() == 2, "duplicate receipt does not spam")
	_check(bool(audio.present_rejected_result({"reason": &"stale_sequence"}).accepted), "stale occupant result is presented")
	_check(_has(&"loadmaster_navigation_rejected"), "stale occupant cue emits")
	_check(bool(audio.present_cleared(2, &"role_handoff").accepted), "handoff reset is presented")
	_check(_has(&"loadmaster_manifest_reset"), "handoff/reset cue emits")
	_check(int(audio.get_snapshot().maximum_simultaneous_voices) == 2, "loadmaster audio keeps two-voice ceiling")

	var craft := HalyardScene.instantiate()
	root.add_child(craft)
	await process_frame
	await physics_frame
	_check(bool(craft.get_loadmaster_audio_snapshot().get("attached", false)), "production Halyard composes loadmaster audio")
	craft.queue_free()
	await process_frame
	for failure in _failures:
		push_error(failure)
	print("halyard_loadmaster_audio_integration_test: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)

func _on_cue(cue_id: StringName, intensity: float, perspective: StringName) -> void:
	_events.append({"cue_id": cue_id, "intensity": intensity, "perspective": perspective})

func _has(cue_id: StringName) -> bool:
	for event in _events:
		if event.cue_id == cue_id:
			return true
	return false

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
