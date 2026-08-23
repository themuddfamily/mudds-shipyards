extends SceneTree

const AudioDirectorScript := preload("res://scripts/audio/audio_director.gd")
const ActivityAudioScript := preload("res://scripts/audio/nearby_sector_activity_audio_binding.gd")
const GameFlowScript := preload("res://scripts/game/game_flow.gd")

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
	director.semantic_cue_emitted.connect(func(source_id: StringName, cue_id: StringName,
			intensity: float, _position: Vector3) -> void:
		_events.append({"source_id": source_id, "cue_id": cue_id, "intensity": intensity}))
	await process_frame
	_check(bool(binding.attach().accepted) and bool(binding.get_snapshot().semantic_output_bound),
		"cargo urgency source binds the authored semantic audio route")

	var normal_raw := _raw_cargo(4, 1, 0.0, 120.0)
	var normalized := flow._normalize_nearby_activity_audio_snapshot(normal_raw)
	_check(normalized.activity_kind == &"cargo"
		and normalized.activity_id == &"cinder_platform_supply_run"
		and normalized.generation == 4 and normalized.source_time_seconds is float
		and normalized.deadline_seconds == 120.0
		and normalized.deadline_remaining_seconds == 120.0,
		"production normalizer preserves only typed authoritative cargo deadline fields")
	flow._sync_nearby_activity_audio(normal_raw)
	_check(_count(&"activity_selected") == 1 and _count(&"activity_started") == 1,
		"real retained cargo activation enters the existing semantic route")

	flow._sync_nearby_activity_audio(_raw_cargo(4, 1, 90.0, 30.0))
	_check(_count(&"cargo_deadline_warning") == 1
		and is_equal_approx(_last_intensity(&"cargo_deadline_warning"), 0.8),
		"25 percent deadline edge emits one distinct warning event")
	var after_warning := _events.size()
	flow._sync_nearby_activity_audio(_raw_cargo(4, 1, 90.0, 30.0))
	_check(_events.size() == after_warning,
		"same-generation, same-time warning snapshot is deduplicated")
	var stale := binding.present_activity_snapshot(
		flow._normalize_nearby_activity_audio_snapshot(_raw_cargo(4, 1, 89.0, 31.0))
	)
	_check(stale.reason == &"stale_activity_time" and _events.size() == after_warning,
		"same-generation cargo time regression is rejected before output")

	director.set_reduced_dynamic_range(true)
	flow._sync_nearby_activity_audio(_raw_cargo(4, 1, 108.0, 12.0))
	_check(_count(&"cargo_deadline_critical") == 1
		and is_equal_approx(_last_intensity(&"cargo_deadline_critical"), 0.75),
		"10 percent edge emits one critical event using reduced dynamic range")
	flow._sync_nearby_activity_audio(_raw_cargo(5, 1, 0.0, 120.0))
	_check(_count(&"cargo_deadline_recovered") == 1
		and is_equal_approx(_last_intensity(&"cargo_deadline_recovered"), 0.5625),
		"fresh reset generation returning to normal emits one recovered edge")

	flow._sync_nearby_activity_audio(_raw_cargo(5, 2, 10.0, 110.0))
	_check(_count(&"cargo_delivery_completed") == 1
		and is_equal_approx(_last_intensity(&"cargo_delivery_completed"), 0.75),
		"authoritative delivered terminal emits one completed cargo event")
	var before_detach := _events.size()
	_check(bool(binding.detach().accepted) and bool(binding.attach(1).accepted),
		"cargo semantic source detaches and re-enters")
	flow._sync_nearby_activity_audio(_raw_cargo(5, 2, 10.0, 110.0))
	_check(_events.size() == before_detach,
		"re-entry does not replay the retained completion generation")
	flow._sync_nearby_activity_audio(_raw_cargo(6, 1, 90.0, 30.0))
	_check(_count(&"cargo_deadline_warning") == 2
		and is_equal_approx(_last_intensity(&"cargo_deadline_warning"), 0.6),
		"fresh post-reentry generation can emit one new reduced-range warning")
	var authority := binding.get_snapshot().authority as Dictionary
	_check(not bool(authority.activity) and not bool(authority.reward)
		and not bool(authority.gameplay) and bool(authority.audio_cues),
		"urgency presentation adds no cargo, reward, timer, or gameplay authority")

	flow.free()
	host.queue_free()
	await process_frame
	for failure in _failures: push_error(failure)
	if _failures.is_empty():
		print("CINDER_CARGO_URGENCY_SEMANTIC_AUDIO_TEST_OK: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)

func _raw_cargo(generation: int, state: int, elapsed: float, remaining: float) -> Dictionary:
	return {"cargo": {"state": state, "generation": generation,
		"contract_id": &"cinder_platform_supply_run", "elapsed_seconds": elapsed,
		"deadline_seconds": 120.0, "deadline_remaining_seconds": remaining,
		"next_phase_index": 1, "phase_count": 3, "reward_pending": false,
		"contract": {"contract_id": &"cinder_platform_supply_run"}}}

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
