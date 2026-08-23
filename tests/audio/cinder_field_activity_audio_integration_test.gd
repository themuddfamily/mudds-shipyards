extends SceneTree

const AudioBinding := preload("res://scripts/audio/cinder_field_activity_audio_binding.gd")
const ActivityBinding := preload("res://scripts/world/nearby_sector_activity_binding.gd")

var _events: Array[Dictionary] = []
var _assertions := 0
var _failures := PackedStringArray()

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var audio := AudioBinding.new()
	audio.semantic_activity_cue_emitted.connect(_on_cue)
	_check(bool(audio.attach().accepted), "Cinder field audio attaches")
	_check(bool(audio.present_activity_snapshot(_snapshot(&"cinder_platform_mining_run", 1, 0.0, 6.0)).accepted), "mining start snapshot accepted")
	_check(bool(audio.present_activity_snapshot(_snapshot(&"cinder_platform_mining_run", 1, 3.0, 6.0)).accepted), "mining progress snapshot accepted")
	_check(bool(audio.present_activity_snapshot(_snapshot(&"cinder_platform_mining_run", 2, 6.0, 6.0)).accepted), "mining completion snapshot accepted")
	_check(_has(&"cinder_activity_started") and _has(&"cinder_activity_progress") and _has(&"cinder_activity_complete"), "mining start/progress/completion cues emit")
	_check(bool(audio.present_beacon_result({"activity_id": &"cinder_debris_beacon_traversal", "generation": 1, "reason": &"out_of_order_beacon"}).accepted), "wrong-order beacon result accepted")
	_check(_has(&"cinder_beacon_wrong_order"), "wrong-order beacon cue emits")
	_check(bool(audio.present_reward_result({"accepted": true, "reason": &"reward_request_ready", "activity_id": &"cinder_derelict_structure_scan", "reward_request": {"generation": 1}}).accepted), "scan reward-ready receipt is accepted")
	_check(_has(&"cinder_activity_reward_pending"), "reward-ready cue emits")
	_check(bool(audio.detach().accepted), "Cinder field audio detaches")

	var production := ActivityBinding.new()
	production.add_child(Node3D.new())
	root.add_child(production)
	await process_frame
	var production_audio := production.get_cinder_field_audio_binding_snapshot()
	_check(bool(production_audio.get("attached", false)), "NearbySectorActivityBinding composes Cinder field audio")
	_check(int(production_audio.get("maximum_simultaneous_voices", 0)) == 2, "production Cinder field audio keeps two-voice ceiling")
	production.queue_free()
	await process_frame
	for failure in _failures:
		push_error(failure)
	print("cinder_field_activity_audio_integration_test: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)

func _snapshot(activity_id: StringName, state: int, elapsed: float, duration: float) -> Dictionary:
	return {"activity_id": activity_id, "generation": 1, "state": state, "elapsed_seconds": elapsed, "extraction_seconds": duration}

func _on_cue(cue_id: StringName, activity_id: StringName, intensity: float) -> void:
	_events.append({"cue_id": cue_id, "activity_id": activity_id, "intensity": intensity})

func _has(cue_id: StringName) -> bool:
	for event in _events:
		if event.cue_id == cue_id:
			return true
	return false

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
