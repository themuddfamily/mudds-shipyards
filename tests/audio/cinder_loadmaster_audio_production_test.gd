extends SceneTree

const Adapter := preload("res://scripts/audio/cinder_loadmaster_audio_production_binding.gd")
const Cinder := preload("res://scripts/ships/cinder_cargo_hauler.gd")

var _assertions := 0
var _failures := PackedStringArray()
var _events: Array[Dictionary] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var craft := Cinder.new()
	root.add_child(craft)
	await process_frame
	var adapter := Adapter.new()
	root.add_child(adapter)
	adapter.semantic_cue_emitted.connect(_on_cue)
	_check(bool(adapter.attach(craft).get("accepted", false)), "production adapter attaches to real Cinder")
	var receipt := {"seat_id": &"cinder_loadmaster_station", "manifest_generation": 1,
		"request_sequence": 4, "manifest_id": &"cinder_manifest", "route_id": &"cinder_route", "ready": true}
	craft.loadmaster_manifest_intent_accepted.emit(receipt)
	_check(_has(&"cinder_loadmaster_seat_occupied") and _has(&"cinder_loadmaster_manifest_ready"), "accepted receipt routes semantic cues")
	craft.loadmaster_manifest_intent_accepted.emit(receipt)
	_check(_events.size() == 2, "duplicate receipt does not spam")
	_check(bool(adapter.present_rejected({"reason": &"stale_sequence", "request_sequence": 5}).get("accepted", false)), "caller rejection routes to audio")
	_check(_has(&"cinder_loadmaster_rejected"), "rejection cue reaches router-compatible signal")
	craft.loadmaster_manifest_cleared.emit(2, &"role_released")
	_check(_has(&"cinder_loadmaster_released"), "clear/release routes semantic cue")
	_check(int(adapter.get_snapshot().audio.maximum_simultaneous_voices) == 2, "two-voice ceiling is retained")
	_check(bool(adapter.detach().get("accepted", false)), "adapter detaches")
	_check(bool(adapter.attach(craft).get("accepted", false)), "adapter re-enters with new generation")
	craft.loadmaster_manifest_intent_accepted.emit(receipt)
	_check(_events.size() == 6, "re-entry accepts the receipt once")
	craft.queue_free()
	adapter.queue_free()
	await process_frame
	for failure in _failures:
		push_error(failure)
	print("CINDER_LOADMASTER_AUDIO_PRODUCTION_TEST: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)

func _on_cue(source_id: StringName, cue_id: StringName, intensity: float, position: Vector3) -> void:
	_events.append({"source_id": source_id, "cue_id": cue_id, "intensity": intensity, "position": position})

func _has(cue_id: StringName) -> bool:
	for event in _events:
		if event.cue_id == cue_id:
			return true
	return false

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
