extends SceneTree

const AdapterType := preload(
	"res://scripts/combat/range_target_damageable_adapter.gd"
)
const BindingType := preload(
	"res://scripts/audio/range_target_component_feedback_binding.gd"
)
const PresenterType := preload("res://scripts/ui/semantic_audio_cue_presenter.gd")

const EXPECTED_CAPTIONS := {
	&"range_target_frame_component_impact": "Range target frame impact",
	&"range_target_core_component_impact": "Range target core impact",
	&"range_target_component_impact": "Range target component impact",
	&"range_target_destroyed": "Range target destroyed",
	&"range_target_regenerated": "Range target regenerated",
}

var _failures := PackedStringArray()
var _assertions := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_production_adapter_feedback()
	_test_fences_fallback_and_caption_contract()
	for failure in _failures:
		push_error(failure)
	print("range_target_component_feedback_test: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _test_production_adapter_feedback() -> void:
	var target := Node3D.new()
	target.name = "ReusableRangeTarget"
	target.set_meta("target_id", &"TARGET_TEST")
	target.set_meta("health", 100.0)
	root.add_child(target)
	var adapter := AdapterType.new() as RangeTargetDamageableAdapter
	adapter.name = "AuthoritativeDamageable"
	target.add_child(adapter)
	await process_frame

	var binding := adapter.get_component_feedback_binding()
	var semantic_events: Array[Dictionary] = []
	var audible_events: Array[Dictionary] = []
	binding.semantic_cue_emitted.connect(func(
		source_id: StringName, cue_id: StringName, intensity: float, position: Vector3
	) -> void:
		semantic_events.append({
			"source": source_id,
			"cue": cue_id,
			"intensity": intensity,
			"position": position,
		})
	)
	binding.semantic_feedback_cue_emitted.connect(func(
		cue_id: StringName, intensity: float, voice_admitted: bool
	) -> void:
		audible_events.append({
			"cue": cue_id,
			"intensity": intensity,
			"voice_admitted": voice_admitted,
		})
	)

	var damage := adapter.apply_damage(10.0, Vector3.ZERO, Vector3.UP)
	_check(
		bool(damage.get("accepted", false))
		and _cue_count(semantic_events, &"range_target_frame_component_impact") == 1
		and _cue_count(semantic_events, &"range_target_core_component_impact") == 1,
		"one accepted hit emits distinct frame and core semantics"
	)
	var lethal := adapter.apply_damage(90.0, Vector3.ZERO, Vector3.UP)
	_check(
		bool(lethal.get("destroyed", false))
		and _cue_count(semantic_events, &"range_target_destroyed") == 1,
		"accepted terminal damage emits one destruction receipt"
	)
	var before_duplicate := semantic_events.size()
	var duplicate := adapter.apply_damage(1.0, Vector3.ZERO, Vector3.UP)
	_check(
		not bool(duplicate.get("accepted", true))
		and semantic_events.size() == before_duplicate,
		"rejected damage emits no duplicate feedback"
	)

	var old_generation := int(adapter.get_component_snapshot().get("generation", -1))
	var reset := adapter.reset_for_reuse(old_generation)
	var feedback_snapshot := binding.get_snapshot() as Dictionary
	_check(
		bool(reset.get("accepted", false))
		and int(feedback_snapshot.generation) == old_generation + 1
		and int(feedback_snapshot.last_sequence) == 0
		and _cue_count(semantic_events, &"range_target_regenerated") == 1,
		"accepted regeneration advances the fence and emits one recovery receipt"
	)
	_check(
		(audible_events as Array).size() == semantic_events.size()
		and (feedback_snapshot.active_cue_slots as Array).size() <= 2
		and int(feedback_snapshot.maximum_simultaneous_voices) == 2,
		"semantic readability survives a bounded two-voice pool"
	)
	var authority := feedback_snapshot.authority as Dictionary
	_check(
		authority.damage == false
		and authority.destruction == false
		and authority.mission == false
		and authority.reward == false
		and authority.regeneration == false,
		"feedback binding owns no combat, lifecycle, mission, or reward authority"
	)
	target.queue_free()
	await process_frame


func _test_fences_fallback_and_caption_contract() -> void:
	var target := Node3D.new()
	target.set_meta("target_id", &"TARGET_FALLBACK")
	var binding := BindingType.new() as RangeTargetComponentFeedbackBinding
	_check(bool(binding.attach(target, 7).accepted), "detached binding accepts a live target generation")
	var fallback := binding.present_component_receipt(&"unmapped", 7, 0, 0.5)
	_check(
		bool(fallback.accepted)
		and fallback.cue_id == &"range_target_component_impact",
		"unmapped localized damage retains the generic semantic fallback"
	)
	var duplicate := binding.present_component_receipt(&"frame", 7, 0, 1.0)
	var stale := binding.present_component_receipt(&"frame", 6, 1, 1.0)
	_check(
		not bool(duplicate.accepted)
		and duplicate.reason == &"duplicate_or_stale_sequence"
		and not bool(stale.accepted)
		and stale.reason == &"stale_generation",
		"duplicate sequences and stale generations cannot replay feedback"
	)
	_check(
		bool(binding.reset_for_reuse(7, 8).accepted)
		and not bool(binding.present_component_receipt(&"core", 7, 1, 1.0).accepted)
		and bool(binding.present_lifecycle_receipt(&"regenerated", 8, 0).accepted),
		"reuse opens only the next generation's ordered receipt stream"
	)

	var presenter := PresenterType.new() as SemanticAudioCuePresenter
	for cue_id in EXPECTED_CAPTIONS:
		var caption := presenter.present_cue(
			cue_id,
			&"TARGET_TEST",
			0.75,
			Vector3.ZERO,
			{"transition_id": str(cue_id)}
		)
		_check(
			bool(caption.get("accepted", false))
			and caption.get("caption", "") == EXPECTED_CAPTIONS[cue_id],
			"%s has a readable production caption" % cue_id
		)
	binding.detach()
	target.free()


func _cue_count(events: Array[Dictionary], cue_id: StringName) -> int:
	var count := 0
	for event in events:
		if event.get("cue", &"") == cue_id:
			count += 1
	return count


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
