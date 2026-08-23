extends SceneTree

const AudioBinding := preload("res://scripts/audio/cinder_field_activity_audio_binding.gd")
const ActivityBinding := preload("res://scripts/world/nearby_sector_activity_binding.gd")

var _events: Array[StringName] = []
var _assertions := 0
var _failures := PackedStringArray()

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var audio := AudioBinding.new()
	audio.semantic_activity_cue_emitted.connect(_on_cue)
	_check(bool(audio.attach().accepted), "route audio attaches")
	_check(bool(audio.present_activity_snapshot(_snapshot(&"cinder_reach_checkpoint_route", 1, &"countdown", 0)).accepted), "race countdown is accepted")
	_check(bool(audio.present_activity_snapshot(_snapshot(&"cinder_reach_checkpoint_route", 1, &"active", 1)).accepted), "race active snapshot is accepted")
	_check(bool(audio.present_activity_snapshot(_snapshot(&"cinder_reach_checkpoint_route", 1, &"completed", 2)).accepted), "race completion is accepted")
	_check(_events.has(&"cinder_race_started") and _events.has(&"cinder_race_progress") and _events.has(&"cinder_race_complete"), "race start/progress/completion cues emit")
	_check(bool(audio.present_activity_snapshot(_patrol_snapshot(2, &"active", 1)).accepted), "patrol snapshot is accepted")
	_check(_events.has(&"cinder_patrol_started"), "patrol start cue emits")
	_check(bool(audio.detach().accepted), "route audio detaches")
	_check(audio.present_activity_snapshot(_patrol_snapshot(2, &"completed", 2)).reason == &"not_attached", "detached route audio rejects snapshots")

	var production := ActivityBinding.new()
	production.add_child(Node3D.new())
	root.add_child(production)
	await process_frame
	var production_audio: Dictionary = production.get_cinder_field_audio_binding_snapshot()
	_check(bool(production_audio.get("attached", false)), "NearbySectorActivityBinding composes route audio")
	_check(int(production_audio.get("maximum_simultaneous_voices", 0)) == 2, "route audio keeps two-voice ceiling")
	production.queue_free()
	await process_frame
	for failure in _failures:
		push_error(failure)
	print("cinder_route_activity_audio_integration_test: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)

func _snapshot(activity_id: StringName, generation: int, state_id: StringName, checkpoint: int) -> Dictionary:
	return {"activity_id": activity_id, "session_generation": generation, "activity_generation": generation,
		"state_id": state_id, "next_checkpoint_index": checkpoint, "checkpoint_count": 2}

func _patrol_snapshot(generation: int, state_id: StringName, checkpoint: int) -> Dictionary:
	return {"activity_id": &"cinder_relay_patrol", "generation": generation,
		"state_id": state_id, "phase_id": state_id, "next_checkpoint_index": checkpoint, "checkpoint_count": 2}

func _on_cue(cue_id: StringName, _activity_id: StringName, _intensity: float) -> void:
	_events.append(cue_id)

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
