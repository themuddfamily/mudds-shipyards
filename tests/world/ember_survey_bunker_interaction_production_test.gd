extends SceneTree

const BindingScript := preload("res://scripts/world/ember_planetary_surface_production_binding.gd")
const DirectorScript := preload("res://scripts/activities/activity_director.gd")

class FakeHost:
	var generation := 18
	var attachment_generation := 1
	var player_instance_id := 0
	func get_generation() -> int: return generation
	func get_attachment_generation() -> int: return attachment_generation
	func get_phase() -> int: return 8
	func get_snapshot() -> Dictionary:
		return {
			"host_id": &"ember_surface_loop", "attached": true,
			"phase_id": &"on_foot",
			"identities": {
				"world_id": &"ember_moon",
				"player_instance_id": player_instance_id,
			},
		}

var _assertions := 0
var _failures := PackedStringArray()
var _reward_calls := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var actor := Node3D.new()
	root.add_child(actor)
	var host := FakeHost.new()
	host.player_instance_id = actor.get_instance_id()
	var director := DirectorScript.new()
	root.add_child(director)
	var binding := BindingScript.new()
	root.add_child(binding)
	await process_frame
	var configured := binding.configure(host, director, Callable(self, "_reward_sink"), 18)
	var interaction := binding.get_node("OwnedSurveyBunkerInteraction")
	var ready := binding.get_snapshot().survey_interaction as Dictionary
	_check(
		bool(configured.accepted)
			and ready.position_body_local_m == Vector3(-17.5, 120000.0, -17.5)
			and ready.prompt == "[ E ]  LOG BUNKER / GANTRY SURVEY"
			and int(ready.physical.collision_layer) == 8
			and bool(ready.physical.marker_visible),
		"the production composition exposes a physical authored bunker approach point"
	)
	var stale: Dictionary = interaction.call(&"submit_interaction", actor, 17, 1)
	var completed: Dictionary = interaction.call(&"submit_interaction", actor, 18, 1)
	var duplicate: Dictionary = interaction.call(&"submit_interaction", actor, 18, 1)
	var completed_snapshot := binding.get_snapshot().survey_interaction as Dictionary
	_check(
		not bool(stale.accepted) and bool(completed.accepted) and not bool(duplicate.accepted)
			and duplicate.reason == &"survey_interaction_already_completed"
			and bool(completed_snapshot.completed)
			and completed_snapshot.prompt == "[ COMPLETE ]  BUNKER / GANTRY SURVEY LOGGED"
			and not bool(completed_snapshot.last_receipt.activity_started)
			and not bool(completed_snapshot.last_receipt.reward_granted)
			and not bool(completed_snapshot.last_receipt.historical_claim)
			and _reward_calls == 0,
		"current actor evidence completes the modern site survey exactly once without reward"
	)
	var saved := binding.get_session_snapshot()
	_check(
		bool(saved.survey_interaction.completed)
			and int(saved.survey_interaction.attachment_generation) == 1,
		"the existing planetary session seam retains the completed survey"
	)
	var detached := binding.detach()
	host.attachment_generation = 2
	var reentered := binding.reenter()
	var retained := binding.get_snapshot().survey_interaction as Dictionary
	_check(
		bool(detached.accepted) and bool(reentered.accepted)
			and bool(retained.completed) and int(retained.physical.collision_layer) == 8
			and not bool(interaction.interact(actor)),
		"new attachment restores the retained completed prompt without replaying completion"
	)
	var restored := binding.restore_session_snapshot(saved)
	var after_restore := binding.get_snapshot().survey_interaction as Dictionary
	_check(
		bool(restored.accepted) and bool(after_restore.completed)
			and int(after_restore.completion_attachment_generation) == 1
			and not bool(after_restore.authority.movement)
			and not bool(after_restore.authority.activity)
			and not bool(after_restore.authority.reward)
			and not bool(after_restore.authority.save),
		"newer generation admits the saved completion without gaining adjacent authority"
	)
	binding.queue_free()
	director.queue_free()
	actor.queue_free()
	await process_frame
	for failure in _failures:
		push_error(failure)
	print("EMBER_SURVEY_BUNKER_INTERACTION_PRODUCTION_TEST_OK: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _reward_sink(_receipt: Dictionary) -> Dictionary:
	_reward_calls += 1
	return {"accepted": true, "reason": &"test_reward"}


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
