extends SceneTree

const Router := preload("res://scripts/audio/semantic_audio_cue_router.gd")
const Adapter := preload("res://scripts/audio/planetary_final_approach_audio_production_binding.gd")

class MockCruise:
	extends Node
	signal engagement_changed(snapshot: Dictionary)
	signal tick_committed(receipt: Dictionary)
	signal final_approach_completed(receipt: Dictionary)

var _assertions := 0
var _failures := PackedStringArray()
var _events: Array[Dictionary] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var cruise := MockCruise.new()
	var adapter := Adapter.new()
	var router := Router.new()
	root.add_child(cruise)
	root.add_child(adapter)
	root.add_child(router)
	router.semantic_cue_emitted.connect(_on_cue)
	_check(bool(adapter.attach(cruise).get("accepted", false)), "final approach production adapter attaches")
	_check(bool(router.bind_source(adapter, &"planetary").get("accepted", false)), "router binds planetary final approach source")
	cruise.engagement_changed.emit({"final_approach": {"target_generation": 1, "state_id": &"armed", "reason": &"final_approach_armed"}})
	cruise.engagement_changed.emit({"final_approach": {"target_generation": 1, "state_id": &"final_approach", "reason": &"final_approach_activated"}})
	cruise.final_approach_completed.emit({"target_generation": 1, "reason": &"final_approach_handoff_ready", "caller_tick": 9})
	_check(_has(&"planetary_final_approach_armed") and _has(&"planetary_final_approach_alignment_ready") and _has(&"planetary_final_approach_handoff_ready"), "engagement and completion cues route through planetary router")
	cruise.final_approach_completed.emit({"target_generation": 1, "reason": &"final_approach_handoff_ready", "caller_tick": 9})
	_check(_events.size() == 3, "duplicate completion is suppressed")
	cruise.tick_committed.emit({"accepted": false, "reason": &"location_generation_mismatch", "generation": 20})
	cruise.engagement_changed.emit({"final_approach": {"target_generation": 1, "state_id": &"armed", "reason": &"final_approach_armed_v2"}})
	_check(_events.size() == 4 and _has(&"planetary_final_approach_armed"), "generic rejection does not poison a later target generation")
	cruise.tick_committed.emit({"accepted": false, "reason": &"final_approach_aborted", "generation": 1, "target_generation": 1})
	_check(_has(&"planetary_final_approach_rejected"), "rejection receipt routes through planetary router")
	_check(int(adapter.get_snapshot().audio.maximum_simultaneous_voices) == 1, "production adapter retains the one-voice reuse ceiling")
	_check(bool(router.detach().accepted), "router detaches")
	_check(bool(adapter.detach().accepted), "adapter detaches")
	_check(bool(adapter.attach(cruise).accepted), "adapter re-enters")
	for failure in _failures:
		push_error(failure)
	print("PLANETARY_FINAL_APPROACH_AUDIO_PRODUCTION_TEST: %d assertions" % _assertions)
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
