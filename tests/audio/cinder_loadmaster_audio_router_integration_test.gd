extends SceneTree

const Director := preload("res://scripts/audio/audio_director.gd")
const Adapter := preload("res://scripts/audio/cinder_loadmaster_audio_production_binding.gd")

class MockCinderLoadmasterCraft:
	extends Node
	signal loadmaster_manifest_intent_accepted(receipt: Dictionary)
	signal loadmaster_manifest_cleared(generation: int, reason: StringName)

var _assertions := 0
var _failures := PackedStringArray()
var _events: Array[Dictionary] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var director := Director.new()
	root.add_child(director)
	await process_frame
	var craft := MockCinderLoadmasterCraft.new()
	root.add_child(craft)
	var adapter := Adapter.new()
	root.add_child(adapter)
	director.semantic_cue_emitted.connect(_on_cue)
	_check(bool(adapter.attach(craft).get("accepted", false)), "production adapter attaches")
	_check(bool(director.bind_semantic_audio_source(adapter, &"crew").get("accepted", false)), "AudioDirector binds Cinder as crew source")
	var receipt := {"seat_id": &"cinder_loadmaster_station", "manifest_generation": 1,
		"request_sequence": 4, "manifest_id": &"cinder_manifest", "route_id": &"cinder_route", "ready": true}
	craft.loadmaster_manifest_intent_accepted.emit(receipt)
	_check(_count(&"cinder_loadmaster_seat_occupied") == 1 and _count(&"cinder_loadmaster_manifest_ready") == 1, "accepted receipt routes once through AudioDirector")
	_check(bool(adapter.present_rejected({"reason": &"stale_sequence", "request_sequence": 5}).get("accepted", false)), "rejected result is forwarded")
	craft.loadmaster_manifest_cleared.emit(2, &"role_released")
	_check(_count(&"cinder_loadmaster_rejected") == 1 and _count(&"cinder_loadmaster_released") == 1, "rejected and released cues route once")
	craft.loadmaster_manifest_intent_accepted.emit(receipt)
	_check(_count(&"cinder_loadmaster_manifest_ready") == 1, "duplicate accepted receipt remains deduped")
	director.detach_semantic_audio_sources()
	craft.loadmaster_manifest_cleared.emit(3, &"ship_detached")
	_check(_events.size() == 4, "detached AudioDirector receives no stale cues")
	for failure in _failures:
		push_error(failure)
	print("CINDER_LOADMASTER_AUDIO_ROUTER_INTEGRATION_TEST: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)

func _on_cue(source_id: StringName, cue_id: StringName, intensity: float, position: Vector3) -> void:
	_events.append({"source_id": source_id, "cue_id": cue_id, "intensity": intensity, "position": position})

func _count(cue_id: StringName) -> int:
	var count := 0
	for event in _events:
		if event.cue_id == cue_id:
			count += 1
	return count

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
