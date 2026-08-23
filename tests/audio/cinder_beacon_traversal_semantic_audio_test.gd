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
		"beacon traversal source binds the authored semantic audio route")

	var active := _raw_beacon(3, 1, 0)
	var normalized := flow._normalize_nearby_activity_audio_snapshot(active)
	_check(normalized.activity_kind == &"beacon"
		and normalized.activity_id == &"cinder_debris_beacon_traversal"
		and normalized.generation == 3 and normalized.next_beacon_index == 0
		and normalized.beacon_count == 4
		and normalized.beacon_interruption_reason == &"",
		"production normalizer preserves typed authoritative beacon cursor fields")
	flow._sync_nearby_activity_audio(active)
	_check(_count(&"activity_selected") == 1 and _count(&"activity_started") == 1,
		"real retained beacon activation enters the existing semantic route")

	flow._sync_nearby_activity_audio(_raw_beacon(3, 1, 1))
	_check(_count(&"beacon_gate_acquired") == 1
		and is_equal_approx(_last_intensity(&"beacon_gate_acquired"), 0.8),
		"ordered beacon advance emits one gate-acquired event")
	var after_gate := _events.size()
	flow._sync_nearby_activity_audio(_raw_beacon(3, 1, 1))
	_check(_events.size() == after_gate,
		"same-generation checkpoint snapshot is deduplicated")
	var stale := binding.present_activity_snapshot(
		flow._normalize_nearby_activity_audio_snapshot(_raw_beacon(3, 1, 0))
	)
	_check(stale.reason == &"stale_beacon_checkpoint" and _events.size() == after_gate,
		"same-generation checkpoint regression is rejected before output")

	flow._sync_nearby_activity_audio(_raw_beacon(3, 1, 1, &"out_of_order_beacon"))
	_check(_count(&"beacon_route_interrupted") == 1
		and is_equal_approx(_last_intensity(&"beacon_route_interrupted"), 1.0),
		"authoritative wrong-order reason emits one route-interrupted event")
	var after_interruption := _events.size()
	flow._sync_nearby_activity_audio(_raw_beacon(3, 1, 1, &"outside_beacon"))
	_check(_events.size() == after_interruption,
		"retained interruption changing to off-course does not replay")
	flow._sync_nearby_activity_audio(_raw_beacon(3, 1, 1))
	_check(_count(&"beacon_route_recovered") == 1
		and is_equal_approx(_last_intensity(&"beacon_route_recovered"), 0.7),
		"cleared interruption emits one recovery event")

	director.set_reduced_dynamic_range(true)
	flow._sync_nearby_activity_audio(_raw_beacon(3, 1, 3))
	_check(_count(&"beacon_gate_acquired") == 2
		and is_equal_approx(_last_intensity(&"beacon_gate_acquired"), 0.6),
		"later ordered gate follows reduced dynamic range")
	flow._sync_nearby_activity_audio(_raw_beacon(3, 2, 4))
	_check(_count(&"beacon_final_gate") == 1
		and _count(&"beacon_route_completed") == 1
		and is_equal_approx(_last_intensity(&"beacon_final_gate"), 0.75)
		and is_equal_approx(_last_intensity(&"beacon_route_completed"), 0.75),
		"final cursor and completion emit distinct reduced-range events")

	var before_detach := _events.size()
	_check(bool(binding.detach().accepted) and bool(binding.attach(1).accepted),
		"beacon semantic source detaches and re-enters")
	flow._sync_nearby_activity_audio(_raw_beacon(3, 2, 4))
	_check(_events.size() == before_detach,
		"re-entry does not replay retained final/completion edges")
	flow._sync_nearby_activity_audio(_raw_beacon(4, 1, 1))
	_check(_count(&"beacon_gate_acquired") == 3
		and is_equal_approx(_last_intensity(&"beacon_gate_acquired"), 0.6),
		"fresh post-reentry generation can emit its ordered gate once")
	var authority := binding.get_snapshot().authority as Dictionary
	_check(not bool(authority.activity) and not bool(authority.reward)
		and not bool(authority.gameplay) and bool(authority.audio_cues),
		"beacon composition adds no traversal, reward, or gameplay authority")

	flow.free()
	host.queue_free()
	await process_frame
	for failure in _failures: push_error(failure)
	if _failures.is_empty():
		print("CINDER_BEACON_TRAVERSAL_SEMANTIC_AUDIO_TEST_OK: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)

func _raw_beacon(generation: int, state: int, next_index: int,
		presentation_reason: StringName = &"") -> Dictionary:
	return {"beacon_traversal": {
		"activity_id": &"cinder_debris_beacon_traversal", "state": state,
		"generation": generation, "next_beacon_index": next_index,
		"beacon_count": 4, "presentation_reason": presentation_reason,
		"reward_pending": false,
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
