extends SceneTree

const AudioDirectorScript := preload("res://scripts/audio/audio_director.gd")
const ActivityAudioScript := preload("res://scripts/audio/nearby_sector_activity_audio_binding.gd")
const GameFlowScript := preload("res://scripts/game/game_flow.gd")
const ScanActivityScript := preload("res://scripts/world/cinder_abandoned_structure_scan_activity.gd")

var _assertions := 0
var _failures: Array[String] = []
var _events: Array[Dictionary] = []

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var host := Node.new()
	root.add_child(host)
	var director := AudioDirectorScript.new()
	director.name = "AudioDirector"
	host.add_child(director)
	var binding := ActivityAudioScript.new()
	host.add_child(binding)
	var flow := GameFlowScript.new()
	flow.set("nearby_activity_audio_binding", binding)
	var scan := ScanActivityScript.new() as RefCounted
	director.semantic_cue_emitted.connect(func(source_id: StringName, cue_id: StringName,
			intensity: float, _position: Vector3) -> void:
		_events.append({"source_id": source_id, "cue_id": cue_id, "intensity": intensity}))
	await process_frame
	_check(bool(binding.attach().accepted) and bool(binding.get_snapshot().semantic_output_bound),
		"structure scan source binds the authored semantic audio route")

	_check(bool(scan.start(ScanActivityScript.APPROACH_ANCHOR).accepted),
		"real scan authority accepts its authored approach")
	var started_raw := _production_snapshot(scan)
	var normalized := flow._normalize_nearby_activity_audio_snapshot(started_raw)
	_check(normalized.activity_kind == &"salvage"
		and normalized.activity_id == &"cinder_derelict_structure_scan"
		and normalized.generation == 1 and normalized.state == &"active"
		and normalized.progress_unitless == 0.0 and normalized.reset_serial == 0,
		"production caller carries the scan authority's standard retained fields")
	flow._sync_nearby_activity_audio(started_raw)
	_check(_count(&"cinder_scan_started") == 1
		and is_equal_approx(_last_intensity(&"cinder_scan_started"), 0.8),
		"authoritative scanning transition emits one scan-start event")

	_check(bool(scan.advance_physics(1.0).accepted), "scan authority advances to 25 percent")
	var quarter_raw := _production_snapshot(scan)
	flow._sync_nearby_activity_audio(quarter_raw)
	_check(_count(&"cinder_scan_progress_checkpoint") == 1
		and is_equal_approx(_last_intensity(&"cinder_scan_progress_checkpoint"), 0.4),
		"25 percent scan progress emits the first checkpoint")
	_check(bool(scan.advance_physics(1.0).accepted), "scan authority advances to 50 percent")
	var half_raw := _production_snapshot(scan)
	flow._sync_nearby_activity_audio(half_raw)
	_check(_count(&"cinder_scan_progress_checkpoint") == 2
		and is_equal_approx(_last_intensity(&"cinder_scan_progress_checkpoint"), 0.65),
		"50 percent scan progress emits the next ordered checkpoint")
	var after_half := _events.size()
	flow._sync_nearby_activity_audio(half_raw)
	_check(_events.size() == after_half,
		"identical retained scan progress is deduplicated")
	var stale_progress := binding.present_activity_snapshot(
		flow._normalize_nearby_activity_audio_snapshot(quarter_raw)
	)
	_check(stale_progress.reason == &"stale_scan_progress" and _events.size() == after_half,
		"late same-generation authority snapshot cannot rewind scan progress")

	director.set_reduced_dynamic_range(true)
	_check(bool(scan.advance_physics(1.0).accepted), "scan authority advances to 75 percent")
	flow._sync_nearby_activity_audio(_production_snapshot(scan))
	_check(_count(&"cinder_scan_progress_checkpoint") == 3
		and is_equal_approx(_last_intensity(&"cinder_scan_progress_checkpoint"), 0.75),
		"75 percent checkpoint follows reduced dynamic range")
	_check(bool(scan.advance_physics(1.0).accepted), "scan authority completes at 100 percent")
	var completed_raw := _production_snapshot(scan)
	flow._sync_nearby_activity_audio(completed_raw)
	_check(_count(&"cinder_scan_completed") == 1
		and is_equal_approx(_last_intensity(&"cinder_scan_completed"), 0.75),
		"authoritative completion emits one reduced-range scan-completed event")

	var before_detach := _events.size()
	_check(bool(binding.detach().accepted) and bool(binding.attach(1).accepted),
		"scan semantic source detaches and re-enters")
	flow._sync_nearby_activity_audio(completed_raw)
	_check(_events.size() == before_detach,
		"re-entry does not replay retained progress or completion")
	_check(bool(scan.reset().accepted), "real scan authority publishes its reset interruption")
	flow._sync_nearby_activity_audio(_production_snapshot(scan))
	_check(_count(&"cinder_scan_interrupted") == 1
		and is_equal_approx(_last_intensity(&"cinder_scan_interrupted"), 0.75),
		"authoritative reset emits one reduced-range interruption event")

	_check(bool(scan.start(ScanActivityScript.APPROACH_ANCHOR).accepted),
		"scan authority starts a fresh generation after reset")
	flow._sync_nearby_activity_audio(_production_snapshot(scan))
	_check(_count(&"cinder_scan_started") == 2
		and is_equal_approx(_last_intensity(&"cinder_scan_started"), 0.6),
		"fresh generation can emit a new reduced-range scan start")
	var stale_generation := binding.present_activity_snapshot(
		flow._normalize_nearby_activity_audio_snapshot(quarter_raw)
	)
	_check(stale_generation.reason == &"stale_activity_generation",
		"older scan generation is rejected before semantic output")
	var authority := binding.get_snapshot().authority as Dictionary
	var scan_snapshot := scan.get_snapshot() as Dictionary
	_check(not bool(authority.activity) and not bool(authority.reward)
		and not bool(authority.gameplay) and bool(authority.audio_cues)
		and not bool(scan_snapshot.reward_authority)
		and not bool(scan_snapshot.gameplay_authority),
		"scan audio adds no scan, salvage, reward, or gameplay authority")

	flow.free()
	host.queue_free()
	await process_frame
	for failure in _failures: push_error(failure)
	if _failures.is_empty():
		print("CINDER_STRUCTURE_SCAN_SEMANTIC_AUDIO_TEST_OK: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)

func _production_snapshot(scan: RefCounted) -> Dictionary:
	return {"structure_scan": scan.call("get_snapshot") as Dictionary}

func _count(cue_id: StringName) -> int:
	var count := 0
	for event in _events:
		if event.cue_id == cue_id: count += 1
	return count

func _last_intensity(cue_id: StringName) -> float:
	for index in range(_events.size() - 1, -1, -1):
		if _events[index].cue_id == cue_id: return float(_events[index].intensity)
	return -1.0

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition: _failures.append(message)
