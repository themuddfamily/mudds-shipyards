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
		"mining source binds the authored semantic audio route")

	var started := _raw_mining(2, 1, 0.0)
	var normalized := flow._normalize_nearby_activity_audio_snapshot(started)
	_check(normalized.activity_kind == &"mining"
		and normalized.activity_id == &"cinder_platform_mining_run"
		and normalized.generation == 2 and normalized.source_time_seconds == 0.0
		and normalized.mining_elapsed_seconds == 0.0
		and normalized.mining_extraction_seconds == 6.0
		and not normalized.reward_pending,
		"production normalizer preserves only typed authoritative extraction fields")
	var malformed := started.duplicate(true)
	(malformed.mining as Dictionary)["elapsed_seconds"] = "0.0"
	var rejected := flow._normalize_nearby_activity_audio_snapshot(malformed)
	_check(not rejected.has("mining_elapsed_seconds")
		and binding.present_activity_snapshot(rejected).reason == &"invalid_mining_extraction",
		"untyped extraction progress is rejected before ledger mutation")

	flow._sync_nearby_activity_audio(started)
	_check(_count(&"cinder_mining_extraction_started") == 1
		and is_equal_approx(_last_intensity(&"cinder_mining_extraction_started"), 0.8),
		"authoritative active transition emits one extraction-start event")
	flow._sync_nearby_activity_audio(_raw_mining(2, 1, 1.6))
	_check(_count(&"cinder_mining_yield_checkpoint") == 1
		and is_equal_approx(_last_intensity(&"cinder_mining_yield_checkpoint"), 0.4),
		"crossing 25 percent emits one yield checkpoint")
	flow._sync_nearby_activity_audio(_raw_mining(2, 1, 3.1))
	_check(_count(&"cinder_mining_yield_checkpoint") == 2
		and is_equal_approx(_last_intensity(&"cinder_mining_yield_checkpoint"), 0.65),
		"crossing 50 percent emits the next ordered yield checkpoint")
	var after_half := _events.size()
	flow._sync_nearby_activity_audio(_raw_mining(2, 1, 3.1))
	_check(_events.size() == after_half,
		"identical same-generation yield snapshot is deduplicated")
	var stale_time := binding.present_activity_snapshot(
		flow._normalize_nearby_activity_audio_snapshot(_raw_mining(2, 1, 3.0))
	)
	_check(stale_time.reason == &"stale_activity_time" and _events.size() == after_half,
		"same-generation extraction time regression is rejected before output")
	var changed_duration := flow._normalize_nearby_activity_audio_snapshot(
		_raw_mining(2, 1, 3.1, false, 12.0)
	)
	_check(binding.present_activity_snapshot(changed_duration).reason == &"stale_mining_yield",
		"same-time yield regression is rejected even if a retained duration changes")

	director.set_reduced_dynamic_range(true)
	flow._sync_nearby_activity_audio(_raw_mining(2, 1, 4.6))
	_check(_count(&"cinder_mining_yield_checkpoint") == 3
		and is_equal_approx(_last_intensity(&"cinder_mining_yield_checkpoint"), 0.75),
		"75 percent yield checkpoint follows reduced dynamic range")
	var complete := _raw_mining(2, 2, 6.0)
	flow._sync_nearby_activity_audio(complete)
	_check(_count(&"cinder_mining_capacity_ready") == 1
		and _count(&"cinder_mining_extraction_completed") == 1
		and is_equal_approx(_last_intensity(&"cinder_mining_capacity_ready"), 0.75)
		and is_equal_approx(_last_intensity(&"cinder_mining_extraction_completed"), 0.75),
		"100 percent extraction emits distinct capacity-ready and completion events")
	var stale_generation := binding.present_activity_snapshot(
		flow._normalize_nearby_activity_audio_snapshot(_raw_mining(1, 1, 1.0))
	)
	_check(stale_generation.reason == &"stale_activity_generation",
		"older mining generation is rejected before semantic output")

	var before_detach := _events.size()
	_check(bool(binding.detach().accepted) and bool(binding.attach(1).accepted),
		"mining semantic source detaches and re-enters")
	flow._sync_nearby_activity_audio(complete)
	_check(_events.size() == before_detach,
		"re-entry does not replay retained capacity/completion edges")
	flow._sync_nearby_activity_audio(_raw_mining(2, 3, 0.0))
	_check(_count(&"cinder_mining_extraction_interrupted") == 1
		and is_equal_approx(_last_intensity(&"cinder_mining_extraction_interrupted"), 0.75),
		"authoritative reset rewind emits one reduced-range interruption event")
	flow._sync_nearby_activity_audio(_raw_mining(3, 1, 0.0))
	_check(_count(&"cinder_mining_extraction_started") == 2
		and is_equal_approx(_last_intensity(&"cinder_mining_extraction_started"), 0.6),
		"fresh post-reset generation can emit a new reduced-range extraction start")
	var authority := binding.get_snapshot().authority as Dictionary
	_check(not bool(authority.activity) and not bool(authority.reward)
		and not bool(authority.gameplay) and bool(authority.audio_cues),
		"mining composition adds no extraction, inventory, reward, or gameplay authority")

	flow.free()
	host.queue_free()
	await process_frame
	for failure in _failures: push_error(failure)
	if _failures.is_empty():
		print("CINDER_MINING_SEMANTIC_AUDIO_TEST_OK: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)

func _raw_mining(generation: int, state: int, elapsed: float,
		reward_requested: bool = false, duration: float = 6.0) -> Dictionary:
	return {"mining": {
		"activity_id": &"cinder_platform_mining_run", "state": state,
		"generation": generation, "elapsed_seconds": elapsed,
		"extraction_seconds": duration, "reward_requested": reward_requested,
	}}

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
