extends SceneTree

const PresenterType := preload("res://scripts/ui/semantic_audio_cue_presenter.gd")
const CASES := [
	[&"range_defender", preload("res://scenes/ships/range_opponent.tscn")],
	[&"standoff_picket", preload("res://scenes/ships/standoff_picket_opponent.tscn")],
	[&"courier_runner", preload("res://scenes/ships/courier_runner_opponent.tscn")],
	[&"flanking_skirmisher", preload("res://scenes/ships/flanking_skirmisher_opponent.tscn")],
]
const EXPECTED_CAPTIONS := {
	&"opponent_component_impact": "Opponent component impact",
	&"opponent_engine_component_impact": "Opponent engine impact",
	&"opponent_weapon_component_impact": "Opponent weapon impact",
	&"opponent_sensor_component_impact": "Opponent sensor impact",
}

var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := Node3D.new()
	root.add_child(host)
	for index in CASES.size():
		var opponent := (CASES[index][1] as PackedScene).instantiate() as RangeOpponent
		host.add_child(opponent)
		opponent.set_physics_process(false)
		opponent.set_process(false)
		await process_frame
		var activated := opponent.activate_with_result(
			Transform3D(Basis.IDENTITY, Vector3(index * 20.0, 0.0, 0.0))
		)
		var binding := opponent.get_damage_audio_binding()
		var events: Array[Dictionary] = []
		var component_events: Array[Dictionary] = []
		binding.semantic_cue_emitted.connect(func(
			source_id: StringName, cue_id: StringName, intensity: float, position: Vector3
		) -> void:
			events.append({"source": source_id, "cue": cue_id, "intensity": intensity, "position": position})
		)
		binding.semantic_component_impact_emitted.connect(func(
			cue_id: StringName, intensity: float, voice_admitted: bool
		) -> void:
			component_events.append({"cue": cue_id, "intensity": intensity, "voice_admitted": voice_admitted})
		)
		_check(bool(activated.get("accepted", false)), "%s activates" % CASES[index][0])
		opponent.apply_damage(opponent.get_maximum_health() * 0.1, opponent.global_position)
		var found_counts := {}
		var found_captions := {}
		var presenter := PresenterType.new()
		for event in events:
			var cue_id := StringName(event.cue)
			if not EXPECTED_CAPTIONS.has(cue_id):
				continue
			var caption := presenter.present_cue(
				cue_id, StringName(event.source), float(event.intensity), event.position as Vector3,
				{"transition_id": "%s:%s" % [CASES[index][0], cue_id]}
			)
			found_counts[cue_id] = int(found_counts.get(cue_id, 0)) + 1
			found_captions[cue_id] = caption.get("caption", "")
		for cue_id in EXPECTED_CAPTIONS:
			_check(
				int(found_counts.get(cue_id, 0)) == 1
				and found_captions.get(cue_id, "") == EXPECTED_CAPTIONS[cue_id],
				"%s emits readable %s exactly once" % [CASES[index][0], cue_id]
			)
		var snapshot := binding.get_snapshot() as Dictionary
		_check(
			component_events.size() == EXPECTED_CAPTIONS.size()
			and (snapshot.active_cue_slots as Array).size() <= 2
			and int(snapshot.maximum_simultaneous_voices) == 2,
			"%s retains the two-voice ceiling" % CASES[index][0]
		)
		var generation := int(snapshot.generation)
		var sequence := int(snapshot.last_component_sequence)
		var count_before := events.size()
		_check(
			not bool(binding.present_component_impact(&"engine", generation, sequence, 1.0).accepted)
			and not bool(binding.present_component_impact(&"engine", generation - 1, sequence + 1, 1.0).accepted)
			and events.size() == count_before,
			"%s rejects duplicate and stale-generation component cues" % CASES[index][0]
		)
		var reset := opponent.activate_with_result(opponent.global_transform)
		var reset_snapshot := binding.get_snapshot() as Dictionary
		var fallback := binding.present_component_impact(
			&"unmapped_subsystem", int(reset_snapshot.generation), 0, 0.5
		) as Dictionary
		_check(
			bool(reset.get("accepted", false))
			and bool(fallback.accepted)
			and StringName(fallback.cue_id) == &"opponent_component_impact",
			"%s reuse fences the old generation and preserves generic fallback" % CASES[index][0]
		)
		opponent.queue_free()
		await process_frame
	host.queue_free()
	await process_frame
	if _failures.is_empty():
		print("Opponent component impact semantic audio test passed")
		quit(0)
	else:
		push_error("Opponent component impact semantic audio test failed: %s" % [_failures])
		quit(1)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)
