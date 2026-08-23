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
		"convoy source binds the authored semantic audio route")

	var stable := _raw_convoy(5, &"active", 0.0, true, 54.0, 8.0)
	var normalized := flow._normalize_nearby_activity_audio_snapshot(stable)
	_check(normalized.activity_kind == &"convoy"
		and normalized.activity_id == &"cinder_reach_emberline_convoy"
		and normalized.generation == 5 and normalized.source_time_seconds == 0.0
		and normalized.convoy_has_sample and normalized.convoy_within_proximity
		and normalized.convoy_separation_remaining_seconds == 8.0,
		"production normalizer unwraps the real host activity and preserves typed separation fields")
	var malformed := stable.duplicate(true)
	(malformed.host.activity as Dictionary)["separation_remaining_seconds"] = "8.0"
	var rejected := flow._normalize_nearby_activity_audio_snapshot(malformed)
	_check(not rejected.has("convoy_separation_remaining_seconds")
		and binding.present_activity_snapshot(rejected).reason == &"invalid_convoy_separation",
		"untyped retained separation data is rejected without mutating the audio ledger")
	flow._sync_nearby_activity_audio(stable)
	_check(_count(&"activity_selected") == 1 and _count(&"activity_started") == 1
		and _count(&"convoy_escort_secure") == 1
		and is_equal_approx(_last_intensity(&"convoy_escort_secure"), 0.65),
		"sampled formation stability enters the existing semantic route")

	var warning := _raw_convoy(5, &"active", 2.0, false, 136.0, 6.0)
	flow._sync_nearby_activity_audio(warning)
	_check(_count(&"convoy_escort_separation_warning") == 1
		and is_equal_approx(_last_intensity(&"convoy_escort_separation_warning"), 0.8),
		"leaving formation emits one separation warning")
	var after_warning := _events.size()
	flow._sync_nearby_activity_audio(warning)
	_check(_events.size() == after_warning,
		"identical same-generation warning is deduplicated")
	var stale_time := binding.present_activity_snapshot(
		flow._normalize_nearby_activity_audio_snapshot(
			_raw_convoy(5, &"active", 1.0, false, 134.0, 7.0)
		)
	)
	_check(stale_time.reason == &"stale_activity_time" and _events.size() == after_warning,
		"same-generation host time regression is rejected before output")

	flow._sync_nearby_activity_audio(_raw_convoy(5, &"active", 6.5, false, 148.0, 1.5))
	_check(_count(&"convoy_escort_separation_critical") == 1
		and is_equal_approx(_last_intensity(&"convoy_escort_separation_critical"), 1.0),
		"final quarter of separation grace emits one critical split cue")
	flow._sync_nearby_activity_audio(_raw_convoy(5, &"active", 7.0, true, 72.0, 8.0))
	_check(_count(&"convoy_escort_recovered") == 1
		and is_equal_approx(_last_intensity(&"convoy_escort_recovered"), 0.8),
		"returning to proximity emits one recovered edge")

	director.set_reduced_dynamic_range(true)
	flow._sync_nearby_activity_audio(_raw_convoy(5, &"active", 8.0, false, 138.0, 5.0))
	_check(_count(&"convoy_escort_separation_warning") == 2
		and is_equal_approx(_last_intensity(&"convoy_escort_separation_warning"), 0.6),
		"renewed separation follows reduced dynamic range")
	var failed := _raw_convoy(
		5, &"failed", 9.0, false, 150.0, 0.0, &"destroyed", &"convoy_destroyed"
	)
	flow._sync_nearby_activity_audio(failed)
	_check(_count(&"convoy_escort_lost") == 1
		and is_equal_approx(_last_intensity(&"convoy_escort_lost"), 0.75),
		"authoritative destroyed failure emits one reduced-range convoy-lost event")
	var stale_generation := binding.present_activity_snapshot(
		flow._normalize_nearby_activity_audio_snapshot(
			_raw_convoy(4, &"active", 1.0, true, 50.0, 8.0)
		)
	)
	_check(stale_generation.reason == &"stale_activity_generation",
		"older host generation is rejected before semantic output")

	var before_detach := _events.size()
	_check(bool(binding.detach().accepted) and bool(binding.attach(1).accepted),
		"convoy semantic source detaches and re-enters")
	flow._sync_nearby_activity_audio(failed)
	_check(_events.size() == before_detach,
		"re-entry does not replay retained threat or failure edges")

	flow._sync_nearby_activity_audio(_raw_convoy(6, &"active", 0.0, true, 48.0, 8.0))
	_check(_count(&"convoy_escort_secure") == 2
		and is_equal_approx(_last_intensity(&"convoy_escort_secure"), 0.4875),
		"fresh post-reentry generation can emit a reduced-range stable formation cue")
	flow._sync_nearby_activity_audio(_raw_convoy(6, &"completed", 4.0, true, 44.0, 8.0))
	_check(_count(&"convoy_escort_arrived") == 1
		and is_equal_approx(_last_intensity(&"convoy_escort_arrived"), 0.75),
		"authoritative safe arrival emits one distinct convoy-complete event")
	var authority := binding.get_snapshot().authority as Dictionary
	_check(not bool(authority.activity) and not bool(authority.reward)
		and not bool(authority.gameplay) and bool(authority.audio_cues),
		"convoy composition adds no movement, combat, reward, or gameplay authority")

	flow.free()
	host.queue_free()
	await process_frame
	for failure in _failures: push_error(failure)
	if _failures.is_empty():
		print("CINDER_CONVOY_THREAT_SEMANTIC_AUDIO_TEST_OK: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)

func _raw_convoy(generation: int, state_id: StringName, elapsed: float,
		within_proximity: bool, distance: float, separation_remaining: float,
		convoy_status: StringName = &"active", terminal_reason: StringName = &"") -> Dictionary:
	return {"host": {"activity": {
		"activity_id": &"cinder_reach_emberline_convoy", "state_id": state_id,
		"generation": generation, "elapsed_seconds": elapsed,
		"has_entity_sample": true, "escort_distance": distance,
		"escort_proximity_radius": 120.0,
		"escort_within_proximity": within_proximity,
		"maximum_separation_seconds": 8.0,
		"separation_remaining_seconds": separation_remaining,
		"convoy_status_id": convoy_status, "terminal_reason": terminal_reason,
	}}}

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
