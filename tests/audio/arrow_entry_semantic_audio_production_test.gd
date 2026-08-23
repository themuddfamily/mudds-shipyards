extends SceneTree

const ProductionOwner := preload(
	"res://scripts/world/ember_surface_loop_production_binding.gd"
)
const AudioBinding := preload(
	"res://scripts/audio/ember_surface_loop_audio_production_binding.gd"
)

var _failures := PackedStringArray()
var _assertions := 0
var _entry_events: Array[Dictionary] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var owner := ProductionOwner.new()
	var audio := AudioBinding.new()
	root.add_child(owner)
	root.add_child(audio)
	audio.semantic_surface_cue_emitted.connect(_on_cue)
	_check(bool(audio.attach(owner, &"interior").accepted),
		"the real Ember production owner attaches to planetary semantic audio")
	_check(bool(audio.set_reduced_dynamic_range(true).accepted),
		"reduced dynamic range is accepted")

	owner.state_changed.emit(_entry_snapshot(
		1, 1, 1, &"airless_descent", &"safe_descent"
	))
	_check(_entry_events.is_empty(),
		"initial safe descent does not manufacture a recovery cue")
	owner.state_changed.emit(_entry_snapshot(
		1, 1, 2, &"entry_watch", &"safe_descent"
	))
	_check(
		_entry_events.size() == 1
		and _entry_events[0].cue_id == &"planetary_atmospheric_entry"
		and is_equal_approx(float(_entry_events[0].intensity), 0.4875),
		"rising atmospheric heat emits one reduced-range transition cue",
	)
	owner.state_changed.emit(_entry_snapshot(
		1, 1, 3, &"entry_watch", &"safe_descent"
	))
	owner.state_changed.emit(_entry_snapshot(
		1, 1, 3, &"entry_watch", &"safe_descent"
	))
	owner.state_changed.emit(_entry_snapshot(
		1, 1, 2, &"critical_entry", &"high_sink_rate"
	))
	_check(_entry_events.size() == 1,
		"unchanged, duplicate, and stale observations emit no cue spam")

	owner.state_changed.emit(_entry_snapshot(
		1, 1, 4, &"critical_entry", &"high_sink_rate"
	))
	owner.state_changed.emit(_entry_snapshot(
		1, 1, 5, &"landing_supported", &"safe_descent"
	))
	_check(
		_entry_events.size() == 3
		and _entry_events[1] == {
			"cue_id": &"surface_entry_severe", "intensity": 0.75,
		}
		and _entry_events[2] == {
			"cue_id": &"surface_entry_clear", "intensity": 0.1875,
		},
		"critical heat and its recovery each emit one fenced cue",
	)

	owner.state_changed.emit(_entry_snapshot(
		1, 1, 6, &"airless_descent", &"high_sink_rate"
	))
	owner.state_changed.emit(_entry_snapshot(
		1, 1, 7, &"airless_descent", &"climb_exit"
	))
	_check(
		_entry_events.size() == 5
		and _entry_events[3] == {
			"cue_id": &"surface_entry_severe", "intensity": 0.675,
		}
		and _entry_events[4] == {
			"cue_id": &"surface_entry_clear", "intensity": 0.1875,
		},
		"airless high sink and climb exit emit alert then clear exactly once",
	)
	var active := audio.get_snapshot()
	_check(
		active.entry_transition.emitted_cue_count == 5
		and active.entry_transition.last_owner_generation == 1
		and active.entry_transition.last_binding_generation == 1
		and active.entry_transition.last_observation_count == 7
		and active.reduced_dynamic_range == true,
		"snapshot retains the exact generation fence and accessibility policy",
	)

	_check(bool(audio.detach().accepted), "audio detaches cleanly")
	owner.state_changed.emit(_entry_snapshot(
		1, 1, 8, &"critical_entry", &"high_sink_rate"
	))
	var detached := audio.get_snapshot()
	_check(
		_entry_events.size() == 5
		and detached.entry_transition.last_owner_generation == -1
		and detached.entry_transition.last_binding_generation == -1
		and detached.entry_transition.last_observation_count == -1,
		"detach disconnects the owner and clears every entry fence",
	)

	_check(bool(audio.attach(owner, &"interior").accepted),
		"audio re-enters with a fresh lifecycle")
	owner.state_changed.emit(_entry_snapshot(
		2, 1, 1, &"critical_entry", &"high_sink_rate"
	))
	owner.state_changed.emit(_entry_snapshot(
		2, 1, 2, &"critical_entry", &"high_sink_rate"
	))
	_check(
		_entry_events.size() == 6
		and _entry_events.back() == {
			"cue_id": &"surface_entry_severe", "intensity": 0.75,
		}
		and audio.get_snapshot().entry_transition.emitted_cue_count == 6,
		"re-entry admits one fresh critical edge and deduplicates its repeat",
	)
	_check(
		audio.get_snapshot().authority.host == false
		and audio.get_snapshot().authority.travel == false
		and audio.get_snapshot().authority.movement == false
		and audio.get_snapshot().authority.landing == false,
		"entry semantic audio owns no gameplay authority",
	)

	audio.detach()
	audio.queue_free()
	owner.queue_free()
	await process_frame
	for failure in _failures:
		push_error(failure)
	print("ARROW_ENTRY_SEMANTIC_AUDIO_PRODUCTION_TEST_OK: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _entry_snapshot(
		owner_generation: int, binding_generation: int, observation_count: int,
		state_id: StringName, advisory_id: StringName
	) -> Dictionary:
	var source := {
		"branch_id": &"atmospheric",
		"altitude_m": 10_000.0,
		"vertical_speed_mps": -12.0,
		"entry_intensity": 0.1,
		"landing_supported": false,
	}.duplicate(true)
	match state_id:
		&"entry_watch":
			source["entry_intensity"] = 0.55
		&"critical_entry":
			source["entry_intensity"] = 0.95
		&"landing_supported":
			source["landing_supported"] = true
		&"airless_descent":
			source["branch_id"] = &"airless"
			source["altitude_m"] = 100.0
			source["entry_intensity"] = 0.0
			source["vertical_speed_mps"] = (
				-60.0 if advisory_id == &"high_sink_rate" \
				else (15.0 if advisory_id == &"climb_exit" else -12.0)
			)
	var retained := {
		"accepted": true,
		"source": source,
	}.duplicate(true)
	return {
		"generation": owner_generation,
		"state_id": &"running",
		"entry_presentation": {
			"generation": binding_generation,
			"observation_count": observation_count,
			"last_result": retained.duplicate(true),
		}.duplicate(true),
		"last_entry_presentation_result": retained.duplicate(true),
	}.duplicate(true)


func _on_cue(cue_id: StringName, intensity: float) -> void:
	if cue_id in [
		&"planetary_atmospheric_entry", &"surface_entry_severe",
		&"surface_entry_clear",
	]:
		_entry_events.append({
			"cue_id": cue_id, "intensity": intensity,
		}.duplicate(true))


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
