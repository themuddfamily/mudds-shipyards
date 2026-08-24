extends SceneTree

const AudioBindingScript := preload(
	"res://scripts/audio/ember_surface_loop_audio_production_binding.gd"
)
const PresenterScript := preload("res://scripts/ui/semantic_audio_cue_presenter.gd")

class FakeOwner extends Node:
	signal state_changed(snapshot: Dictionary)
	signal service_terminal_repair_feedback(feedback: Dictionary)
	var generation := 4
	func get_snapshot() -> Dictionary:
		return {"generation": generation, "state_id": &"idle"}
	func publish(feedback: Dictionary) -> void:
		service_terminal_repair_feedback.emit(feedback)

var _assertions := 0
var _failures := PackedStringArray()
var _cues: Array[StringName] = []
var _captions: Array[String] = []
var _presenter := PresenterScript.new() as RefCounted


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var owner := FakeOwner.new()
	root.add_child(owner)
	var audio := AudioBindingScript.new() as Node
	root.add_child(audio)
	audio.connect(&"semantic_surface_cue_emitted", _on_cue)
	var attached := audio.call(&"attach", owner, &"exterior") as Dictionary
	_check(bool(attached.accepted), "the retained Ember audio source attaches")

	owner.publish(_feedback(4, 1, 1, &"completed"))
	owner.publish(_feedback(4, 1, 1, &"completed"))
	owner.publish(_feedback(4, 1, 0, &"rejected"))
	owner.publish(_feedback(3, 1, 2, &"rejected"))
	_check(
		_cues == [&"ember_service_repair_completed"]
			and _captions == ["Component service complete"],
		"success emits one concise caption while duplicate, stale, and wrong-owner events are fenced"
	)

	owner.publish(_feedback(4, 1, 2, &"unavailable"))
	owner.publish(_feedback(4, 2, 1, &"rejected"))
	owner.publish(_feedback(4, 1, 3, &"completed"))
	var snapshot := audio.call(&"get_snapshot") as Dictionary
	var service := snapshot.service_repair_feedback as Dictionary
	_check(
		_cues == [
			&"ember_service_repair_completed",
			&"ember_service_repair_unavailable",
			&"ember_service_repair_rejected",
		]
			and _captions == [
				"Component service complete",
				"Component service unavailable",
				"Component service rejected",
			]
			and int(service.last_feedback_generation) == 2
			and int(service.last_feedback_sequence) == 1
			and int(service.emitted_cue_count) == 3,
		"unavailable and rejected outcomes advance only within the current feedback generation"
	)
	_check(
		not bool(service.authority.repair)
			and not bool(service.authority.components)
			and not bool(service.authority.game_flow)
			and not bool(service.authority.network)
			and not bool(service.authority.persistence),
		"repair feedback remains presentation-only"
	)

	var detached := audio.call(&"detach") as Dictionary
	owner.publish(_feedback(4, 3, 1, &"completed"))
	_check(
		bool(detached.accepted) and _cues.size() == 3,
		"detach removes the terminal feedback route"
	)
	audio.queue_free()
	owner.queue_free()
	await process_frame
	_finish()


func _feedback(
	owner_generation: int, feedback_generation: int,
	feedback_sequence: int, outcome: StringName
	) -> Dictionary:
	return {
		"owner_generation": owner_generation,
		"feedback_generation": feedback_generation,
		"feedback_sequence": feedback_sequence,
		"outcome": outcome,
		"world_position": Vector3(12.0, 3.0, -7.0),
	}.duplicate(true)


func _on_cue(cue_id: StringName, intensity: float) -> void:
	_cues.append(cue_id)
	var presented := _presenter.call(
		&"present_cue", cue_id, &"planetary", intensity,
		Vector3(12.0, 3.0, -7.0), {"transition_id": "service-%d" % _cues.size()}
	) as Dictionary
	_captions.append(str(presented.get("caption", "")))


func _finish() -> void:
	for failure in _failures:
		push_error(failure)
	print(
		"EMBER_SERVICE_TERMINAL_REPAIR_FEEDBACK_TEST_OK: %d assertions"
		% _assertions
	)
	quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
