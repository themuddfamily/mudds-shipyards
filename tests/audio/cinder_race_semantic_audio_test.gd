extends SceneTree

const AudioDirectorScript := preload("res://scripts/audio/audio_director.gd")
const ActivityAudioScript := preload("res://scripts/audio/nearby_sector_activity_audio_binding.gd")
const GameFlowScript := preload("res://scripts/game/game_flow.gd")
const RaceSessionScript := preload("res://scripts/activities/cinder_timed_race_session.gd")
const RaceRoute: ActivityDefinition = preload("res://assets/activities/cinder_reach_checkpoint_route.tres")

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
	var activity_director := ActivityDirector.new()
	host.add_child(activity_director)
	_check(bool(activity_director.register_definition(RaceRoute)),
		"real ActivityDirector registers the authored Cinder race route")
	var race := RaceSessionScript.new(1, 3.0, 120.0) as RefCounted
	_check(bool(race.call("attach", activity_director, 0).accepted),
		"real race session attaches to the route authority")
	var flow := GameFlowScript.new()
	flow.set("nearby_activity_audio_binding", binding)
	director.semantic_cue_emitted.connect(func(source_id: StringName, cue_id: StringName,
			intensity: float, _position: Vector3) -> void:
		_events.append({"source_id": source_id, "cue_id": cue_id, "intensity": intensity}))
	await process_frame
	_check(bool(binding.attach().accepted) and bool(binding.get_snapshot().semantic_output_bound),
		"race source binds the authored semantic audio route")

	_check(bool(race.call("start", 0).accepted), "real race authority starts generation one")
	var countdown_raw := _production_snapshot(race)
	var normalized := flow._normalize_nearby_activity_audio_snapshot(countdown_raw)
	_check(normalized.activity_kind == &"race"
		and normalized.activity_id == &"cinder_reach_checkpoint_route"
		and normalized.generation == 1 and normalized.state == &"countdown"
		and normalized.progress_unitless == 0.0 and normalized.checkpoint_id == &"",
		"production normalizer retains the authoritative countdown state")
	flow._sync_nearby_activity_audio(countdown_raw)
	_check(_count(&"cinder_race_countdown_started") == 1
		and is_equal_approx(_last_intensity(&"cinder_race_countdown_started"), 0.8),
		"countdown transition emits one race countdown event")
	var after_countdown := _events.size()
	flow._sync_nearby_activity_audio(countdown_raw)
	_check(_events.size() == after_countdown, "retained countdown is deduplicated")

	_check(bool(race.call("advance_physics", 3.0, 1).accepted),
		"caller physics advances the real race into active state")
	flow._sync_nearby_activity_audio(_production_snapshot(race))
	var missed := race.call("submit_position", Vector3.ZERO, 1) as Dictionary
	_check(not bool(missed.accepted) and missed.reason == &"outside_checkpoint"
		and missed.presentation_reason == &"outside_checkpoint",
		"race authority retains its missed-gate rejection")
	var missed_raw := _production_snapshot(race)
	flow._sync_nearby_activity_audio(missed_raw)
	_check(_count(&"cinder_race_missed_gate") == 1
		and is_equal_approx(_last_intensity(&"cinder_race_missed_gate"), 1.0),
		"authoritative outside-checkpoint transition emits one missed-gate event")
	var after_missed := _events.size()
	flow._sync_nearby_activity_audio(missed_raw)
	_check(_events.size() == after_missed, "retained missed gate does not replay")

	_check(bool(race.call("submit_position", RaceRoute.get_checkpoint_position(0), 1).accepted),
		"race authority accepts gate one in order")
	var gate_one_raw := _production_snapshot(race)
	flow._sync_nearby_activity_audio(gate_one_raw)
	_check(_count(&"cinder_race_gate_acquired") == 1
		and is_equal_approx(_last_intensity(&"cinder_race_gate_acquired"), 0.56),
		"gate one recovery emits one ordered gate-acquired event")
	_check(bool(race.call("submit_position", RaceRoute.get_checkpoint_position(1), 1).accepted),
		"race authority accepts gate two in order")
	flow._sync_nearby_activity_audio(_production_snapshot(race))
	_check(_count(&"cinder_race_gate_acquired") == 2
		and is_equal_approx(_last_intensity(&"cinder_race_gate_acquired"), 0.67),
		"gate two emits the next distinct ordered event")
	var stale_gate := binding.present_activity_snapshot(
		flow._normalize_nearby_activity_audio_snapshot(gate_one_raw)
	)
	_check(stale_gate.reason == &"stale_race_gate",
		"late same-generation gate snapshot cannot rewind race order")

	director.set_reduced_dynamic_range(true)
	for gate_index in [2, 3]:
		_check(bool(race.call(
			"submit_position", RaceRoute.get_checkpoint_position(gate_index), 1
		).accepted), "race authority accepts gate %d in order" % (gate_index + 1))
		flow._sync_nearby_activity_audio(_production_snapshot(race))
	_check(_count(&"cinder_race_gate_acquired") == 4
		and is_equal_approx(_last_intensity(&"cinder_race_gate_acquired"), 0.6675),
		"later ordered gates remain distinct under reduced dynamic range")
	_check(bool(race.call("submit_position", RaceRoute.get_checkpoint_position(4), 1).accepted),
		"race authority accepts the final gate and completes")
	var completed_raw := _production_snapshot(race)
	flow._sync_nearby_activity_audio(completed_raw)
	_check(_count(&"cinder_race_gate_acquired") == 5
		and is_equal_approx(_last_intensity(&"cinder_race_gate_acquired"), 0.75)
		and _count(&"cinder_race_completed") == 1
		and is_equal_approx(_last_intensity(&"cinder_race_completed"), 0.75),
		"final gate and authoritative completion emit distinct reduced-range events")

	var before_detach := _events.size()
	_check(bool(binding.detach().accepted) and bool(binding.attach(1).accepted),
		"race semantic source detaches and re-enters")
	flow._sync_nearby_activity_audio(completed_raw)
	_check(_events.size() == before_detach,
		"re-entry does not replay retained gates or completion")
	_check(bool(race.call("reset", 1).accepted) and bool(race.call("start", 2).accepted),
		"real race authority resets and starts a fresh generation")
	flow._sync_nearby_activity_audio(_production_snapshot(race))
	_check(_count(&"cinder_race_countdown_started") == 2
		and is_equal_approx(_last_intensity(&"cinder_race_countdown_started"), 0.6),
		"fresh generation emits one new reduced-range countdown")
	var stale_generation := binding.present_activity_snapshot(
		flow._normalize_nearby_activity_audio_snapshot(gate_one_raw)
	)
	_check(stale_generation.reason == &"stale_activity_generation",
		"older race generation is rejected before semantic output")
	var authority := binding.get_snapshot().authority as Dictionary
	var race_snapshot := race.call("get_presentation_snapshot") as Dictionary
	_check(not bool(authority.activity) and not bool(authority.reward)
		and not bool(authority.gameplay) and bool(authority.audio_cues)
		and not bool(race_snapshot.grants_rewards)
		and not bool(race_snapshot.ship_authority),
		"race audio adds no checkpoint, ship, reward, or gameplay authority")

	flow.free()
	host.queue_free()
	await process_frame
	for failure in _failures: push_error(failure)
	if _failures.is_empty():
		print("CINDER_RACE_SEMANTIC_AUDIO_TEST_OK: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)

func _production_snapshot(race: RefCounted) -> Dictionary:
	return {"race": race.call("get_presentation_snapshot") as Dictionary}

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
