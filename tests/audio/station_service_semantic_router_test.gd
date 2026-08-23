extends SceneTree

class MockStation:
	extends Node
	signal semantic_maintenance_cue_emitted(cue_id: StringName, intensity: float)

	func emit_service(cue_id: StringName, intensity: float) -> void:
		semantic_maintenance_cue_emitted.emit(cue_id, intensity)


const Router := preload("res://scripts/audio/semantic_audio_cue_router.gd")
var _events: Array[Dictionary] = []
var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var router := Router.new()
	var station := MockStation.new()
	root.add_child(router)
	root.add_child(station)
	router.semantic_cue_emitted.connect(_on_cue)
	_check(bool(router.bind_source(station, &"station").accepted), "station source binds to the maintenance signal")
	station.emit_service(&"station_service_servo", 1.0)
	station.emit_service(&"station_service_servo", 1.0)
	station.emit_service(&"station_service_latch", 0.75)
	_check(_events.size() == 2, "duplicate station service cues are deduplicated")
	_check(
		_events[0].source_id == &"station"
		and _events[0].cue_id == &"station_service_servo"
		and _events[1].cue_id == &"station_service_latch",
		"station service cues retain source and typed IDs"
	)
	_check(
		_events.all(func(event): return event.intensity is float and event.world_position == Vector3.ZERO),
		"station service payloads are bounded scalar events"
	)
	_check(bool(router.detach().accepted), "router detaches station source")
	station.emit_service(&"station_service_servo", 1.0)
	_check(_events.size() == 2 and router.get_binding_count() == 0, "detach clears station forwarding")
	station.free()
	router.free()
	for failure in _failures:
		push_error(failure)
	print("station_service_semantic_router_test: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _on_cue(source_id: StringName, cue_id: StringName, intensity: float, world_position: Vector3) -> void:
	_events.append({
		"source_id": source_id,
		"cue_id": cue_id,
		"intensity": intensity,
		"world_position": world_position,
	})


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
