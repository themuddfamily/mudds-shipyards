extends SceneTree

const ActivityAudioScript := preload(
	"res://scripts/audio/nearby_sector_activity_audio_binding.gd"
)
const GameFlowScript := preload("res://scripts/game/game_flow.gd")

const TERMINAL_CASES := [
	[&"mining", &"active", &"failed", &"", &"failed", &"cinder_mining_extraction_failed"],
	[&"salvage", &"active", &"failed", &"", &"failed", &"cinder_scan_failed"],
	[&"salvage", &"active", &"aborted", &"", &"aborted", &"cinder_scan_aborted"],
	[&"race", &"failed", &"", &"timeout", &"timed_out", &"cinder_race_timed_out"],
	[&"race", &"failed", &"", &"route_desynchronized", &"failed", &"cinder_race_failed"],
	[&"race", &"aborted", &"", &"pilot_recalled", &"aborted", &"cinder_race_aborted"],
	[&"patrol", &"failed", &"", &"craft_unavailable", &"failed", &"cinder_patrol_failed"],
	[&"patrol", &"aborted", &"", &"pilot_recalled", &"aborted", &"cinder_patrol_aborted"],
]

var _assertions := 0
var _failures: Array[String] = []
var _events: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var binding := ActivityAudioScript.new()
	root.add_child(binding)
	binding.semantic_activity_cue_emitted.connect(func(
		cue_id: StringName, activity_id: StringName, intensity: float
	) -> void:
		_events.append({
			"cue_id": cue_id,
			"activity_id": activity_id,
			"intensity": intensity,
		})
	)
	_check(bool(binding.attach().accepted), "production activity audio binding attaches")
	var flow := GameFlowScript.new()
	flow.set("nearby_activity_audio_binding", binding)
	var generation := 1
	for case: Array in TERMINAL_CASES:
		var baseline := _source_snapshot(case[0], &"active", generation, &"", &"")
		flow._sync_nearby_activity_audio(baseline)
		var terminal := _source_snapshot(case[0], case[1], generation, case[2], case[3])
		var normalized := flow._normalize_nearby_activity_audio_snapshot(terminal)
		_check(
			normalized.terminal_outcome == case[4],
			"%s production snapshot publishes %s" % [case[0], case[4]]
		)
		var before := _count(case[5])
		flow._sync_nearby_activity_audio(terminal)
		_check(
			_count(case[5]) == before + 1
			and _events[-1].cue_id == case[5]
			and is_equal_approx(float(_events[-1].intensity), 1.0),
			"%s production terminal transition emits %s once" % [case[0], case[5]]
		)
		flow._sync_nearby_activity_audio(terminal)
		_check(
			_count(case[5]) == before + 1,
			"%s retained production terminal transition is deduplicated" % case[0]
		)
		_check(
			bool(binding.detach().accepted)
			and bool(binding.attach(int(binding.get_snapshot().generation)).accepted),
			"%s terminal voice retires before the next activity session" % case[0]
		)
		generation += 1

	var reset_with_stale_outcome := _source_snapshot(
		&"salvage", &"reset", generation, &"failed", &""
	)
	var active_with_stale_reason := _source_snapshot(
		&"race", &"active", generation + 1, &"", &"timeout"
	)
	var complete_patrol := _source_snapshot(
		&"patrol", &"completed", generation + 2, &"", &"pilot_recalled"
	)
	_check(
		flow._normalize_nearby_activity_audio_snapshot(
			reset_with_stale_outcome
		).terminal_outcome == &""
		and flow._normalize_nearby_activity_audio_snapshot(
			active_with_stale_reason
		).terminal_outcome == &""
		and flow._normalize_nearby_activity_audio_snapshot(
			complete_patrol
		).terminal_outcome == &"",
		"reset and nonterminal production states publish an empty terminal outcome"
	)
	var authority := binding.get_snapshot().authority as Dictionary
	_check(
		not bool(authority.activity)
		and not bool(authority.reward)
		and not bool(authority.gameplay)
		and bool(authority.audio_cues),
		"production wiring preserves presentation-only audio authority"
	)

	flow.free()
	binding.queue_free()
	await process_frame
	for failure in _failures:
		push_error(failure)
	if _failures.is_empty():
		print("GAME_FLOW_ACTIVITY_TERMINAL_AUDIO_WIRING_TEST_OK: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _source_snapshot(
	kind: StringName,
	state: StringName,
	generation: int,
	typed_terminal_outcome: StringName,
	failure_reason: StringName
) -> Dictionary:
	var activity_id: StringName = {
		&"mining": &"cinder_platform_mining_run",
		&"salvage": &"cinder_derelict_structure_scan",
		&"race": &"cinder_reach_checkpoint_route",
		&"patrol": &"cinder_relay_patrol",
	}.get(kind, &"nearby_activity")
	var activity := {
		"activity_id": activity_id,
		"state_id": state,
		"generation": generation,
		"progress_unitless": 0.0 if kind == &"patrol" else 0.5,
		"checkpoint_id": &"race_failed" if kind == &"race" and state == &"failed" else &"",
		"reward_pending": false,
		"reset_serial": generation if state == &"reset" else 0,
		"terminal_outcome": typed_terminal_outcome,
		"failure_reason": failure_reason,
	}.duplicate(true)
	if kind == &"mining":
		activity.erase("state_id")
		activity["state"] = {
			&"idle": 0,
			&"active": 1,
			&"complete": 2,
			&"completed": 2,
			&"reset": 3,
		}.get(state, 0)
		activity["elapsed_seconds"] = 3.0
		activity["extraction_seconds"] = 6.0
		activity["reward_requested"] = false
	return {
		&"mining": {"mining": activity},
		&"salvage": {"structure_scan": activity},
		&"race": {"race": activity},
		&"patrol": {"patrol": activity},
	}.get(kind, {}) as Dictionary


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _count(cue_id: StringName) -> int:
	var count := 0
	for event in _events:
		if event.cue_id == cue_id:
			count += 1
	return count
