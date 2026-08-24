extends SceneTree

const BindingScript := preload(
	"res://scripts/world/ember_planetary_surface_production_binding.gd"
)
const DirectorScript := preload("res://scripts/activities/activity_director.gd")

class FakeHost:
	var generation := 28
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
	var binding := BindingScript.new() as Node
	root.add_child(binding)
	await process_frame
	var configured: Dictionary = binding.call(
		&"configure", host, director, Callable(self, "_reward_sink"), 28
	)
	var interaction := binding.get_node("OwnedSurveyBunkerInteraction")
	var sample_rack := binding.get_node("OwnedSampleRackInteraction")
	var started: Dictionary = binding.call(&"start_relay_survey")
	var available := binding.call(&"get_snapshot") as Dictionary
	var available_sample := available.relay_survey.optional_checkpoints.get(
		&"ember_sample_rack_analysis_log", {}
	) as Dictionary
	_check(
		bool(configured.accepted) and bool(started.accepted)
			and bool(available.relay_survey.optional_checkpoint.eligible)
			and not bool(available.relay_survey.optional_checkpoint.completed)
			and bool(available_sample.eligible)
			and not bool(available_sample.completed)
			and bool(available.sample_rack_interaction.active)
			and available.sample_rack_interaction.prompt \
				== "[ E ]  ANALYSE SAMPLE RACK"
			and bool(available.relay_survey_presentation.hud.visible)
			and available.relay_survey_presentation.hud.progress_text \
				== "OPTIONAL BUNKER LOG  0 / 1",
		"an active relay survey presents the authored optional bunker checkpoint"
	)
	var stale: Dictionary = interaction.call(&"submit_interaction", actor, 27, 1)
	var completed: Dictionary = interaction.call(&"submit_interaction", actor, 28, 1)
	var duplicate: Dictionary = interaction.call(&"submit_interaction", actor, 28, 1)
	var rack_stale: Dictionary = sample_rack.call(
		&"submit_interaction", actor, 28, 1, 0
	)
	var rack_completed: Dictionary = sample_rack.call(
		&"submit_interaction", actor, 28, 1, 1
	)
	var rack_duplicate: Dictionary = sample_rack.call(
		&"submit_interaction", actor, 28, 1, 1
	)
	var checkpointed := binding.call(&"get_snapshot") as Dictionary
	var sample_checkpoint := checkpointed.relay_survey.optional_checkpoints.get(
		&"ember_sample_rack_analysis_log", {}
	) as Dictionary
	var director_progress := director.get_activity_snapshot(&"ember_beacon_survey")
	_check(
		not bool(stale.accepted) and bool(completed.accepted)
			and not bool(duplicate.accepted)
			and not bool(rack_stale.accepted) and bool(rack_completed.accepted)
			and not bool(rack_duplicate.accepted)
			and bool(checkpointed.relay_survey.optional_checkpoint.completed)
			and checkpointed.relay_survey.optional_checkpoint.status == &"completed"
			and int(checkpointed.relay_survey.optional_checkpoint.activity_generation) == 1
			and bool(checkpointed.relay_survey_presentation.hud.completed)
			and checkpointed.relay_survey_presentation.hud.progress_text \
				== "OPTIONAL BUNKER LOG  1 / 1"
			and bool(sample_checkpoint.completed)
			and sample_checkpoint.status == &"completed"
			and int(sample_checkpoint.activity_generation) == 1
			and int(checkpointed.relay_survey.optional_progress.completed_count) == 2
			and int(checkpointed.relay_survey.optional_progress.checkpoint_count) == 2
			and checkpointed.sample_rack_interaction.prompt \
				== "[ COMPLETE ]  SAMPLE RACK ANALYSED"
			and int(director_progress.next_checkpoint_index) == 0
			and int(director_progress.checkpoint_count) == 2
			and _reward_calls == 0,
		"current completion records 1/1 without advancing or completing the route"
	)
	var reached_relay: Dictionary = binding.call(
		&"submit_relay_survey_position", Vector3(180.0, 120009.0, -44.0)
	)
	var reached_return: Dictionary = binding.call(
		&"submit_relay_survey_position", Vector3(540.0, 120030.0, -210.0)
	)
	var committed: Dictionary = binding.call(&"commit_relay_survey_reward")
	var duplicate_reward: Dictionary = binding.call(&"commit_relay_survey_reward")
	_check(
		bool(reached_relay.accepted) and bool(reached_return.accepted)
			and bool(committed.accepted) and not bool(duplicate_reward.accepted)
			and _reward_calls == 1,
		"only the existing mandatory route completion can commit one reward"
	)
	var saved := binding.call(&"get_session_snapshot") as Dictionary
	var session_keys := saved.keys()
	session_keys.sort()
	var expected_session_keys := [
		"attachment_generation",
		"authority",
		"composition_generation",
		"host_generation",
		"relay_survey_optional_checkpoint",
		"schema_version",
		"surface",
		"survey_interaction",
	]
	var checkpoint_keys := (
		saved.relay_survey_optional_checkpoint as Dictionary
	).keys()
	checkpoint_keys.sort()
	var expected_checkpoint_keys := [
		"activity_generation",
		"activity_id",
		"attachment_generation",
		"checkpoint_id",
		"completed",
		"receipt",
		"run_generation",
		"schema_version",
		"session_attachment_generation",
		"session_run_generation",
		"status",
	]
	var detached: Dictionary = binding.call(&"detach")
	var detached_presentation: Dictionary = (
		binding.call(&"get_snapshot") as Dictionary
	).relay_survey_presentation
	host.attachment_generation = 2
	var reentered: Dictionary = binding.call(&"reenter")
	var retained := binding.call(&"get_snapshot") as Dictionary
	_check(
		bool(saved.relay_survey_optional_checkpoint.completed)
			and session_keys == expected_session_keys
			and checkpoint_keys == expected_checkpoint_keys
			and not saved.has("sample_rack_interaction")
			and not saved.has("relay_survey_sample_rack_checkpoint")
			and bool(detached.accepted)
			and not bool(detached_presentation.hud.visible)
			and bool(reentered.accepted)
			and bool(retained.relay_survey.optional_checkpoint.completed)
			and bool(retained.relay_survey.optional_checkpoints.get(
				&"ember_sample_rack_analysis_log", {}
			).completed)
			and bool(retained.sample_rack_interaction.completed)
			and bool(retained.relay_survey_presentation.hud.visible),
		"detach and re-entry retain runtime progress without changing session schema"
	)
	var restored: Dictionary = binding.call(&"restore_session_snapshot", saved)
	var after_restore := binding.call(&"get_snapshot") as Dictionary
	_check(
		bool(restored.accepted)
			and bool(after_restore.relay_survey.optional_checkpoint.completed)
			and after_restore.relay_survey.optional_checkpoint.content_class == &"NEW"
			and after_restore.relay_survey.optional_checkpoint.interpretation_status \
				== &"modern_interpretation"
			and not bool(after_restore.relay_survey.optional_checkpoint.authority.route)
			and not bool(after_restore.relay_survey.optional_checkpoint.authority.reward)
			and bool(after_restore.relay_survey.optional_checkpoints.get(
				&"ember_sample_rack_analysis_log", {}
			).completed),
		"the saved optional checkpoint restores without gaining route or reward authority"
	)
	var next_run: Dictionary = binding.call(&"start_relay_survey")
	var next_run_snapshot := binding.call(&"get_snapshot") as Dictionary
	_check(
		bool(next_run.accepted)
			and int(next_run_snapshot.relay_survey.optional_checkpoint.current_activity_generation) == 2
			and not bool(next_run_snapshot.relay_survey.optional_checkpoint.completed)
			and next_run_snapshot.relay_survey.optional_checkpoint.status == &"available"
			and next_run_snapshot.relay_survey_presentation.hud.progress_text \
				== "OPTIONAL BUNKER LOG  0 / 1"
			and not bool(next_run_snapshot.relay_survey.optional_checkpoints.get(
				&"ember_sample_rack_analysis_log", {}
			).completed)
			and not bool(next_run_snapshot.sample_rack_interaction.completed)
			and int(next_run_snapshot.sample_rack_interaction.activity_generation) == 2
			and bool(next_run_snapshot.survey_interaction.completed)
			and _reward_calls == 1,
		"a genuinely newer relay-survey generation clears run N optional progress"
	)
	var second_relay: Dictionary = binding.call(
		&"submit_relay_survey_position", Vector3(180.0, 120009.0, -44.0)
	)
	var second_return: Dictionary = binding.call(
		&"submit_relay_survey_position", Vector3(540.0, 120030.0, -210.0)
	)
	var second_committed: Dictionary = binding.call(&"commit_relay_survey_reward")
	var terminal_complete_layer := int(sample_rack.collision_layer)
	var terminal_complete_marker_visible := bool(
		sample_rack.get_node("SampleRackAnalysisMarker").visible
	)
	var terminal_complete := binding.call(&"get_snapshot") as Dictionary
	var late_after_complete: Dictionary = sample_rack.call(
		&"submit_interaction", actor, 28, 2, 2
	)
	var after_complete := binding.call(&"get_snapshot") as Dictionary
	var after_complete_sample := after_complete.relay_survey.optional_checkpoints.get(
		&"ember_sample_rack_analysis_log", {}
	) as Dictionary
	_check(
		bool(second_relay.accepted) and bool(second_return.accepted)
			and bool(second_committed.accepted)
			and not bool(terminal_complete.sample_rack_interaction.active)
			and terminal_complete_layer == 0
			and not terminal_complete_marker_visible
			and not bool(late_after_complete.accepted)
			and not bool(after_complete.sample_rack_interaction.active)
			and not bool(after_complete.sample_rack_interaction.completed)
			and not bool(after_complete_sample.eligible)
			and not bool(after_complete_sample.completed)
			and after_complete_sample.status == &"inactive"
			and _reward_calls == 2,
		"a completed survey hides the rack before a late press can diverge progress"
	)

	var standalone_actor := Node3D.new()
	root.add_child(standalone_actor)
	var standalone_host := FakeHost.new()
	standalone_host.generation = 29
	standalone_host.player_instance_id = standalone_actor.get_instance_id()
	var standalone_director := DirectorScript.new()
	root.add_child(standalone_director)
	var standalone_binding := BindingScript.new() as Node
	root.add_child(standalone_binding)
	await process_frame
	var standalone_configured: Dictionary = standalone_binding.call(
		&"configure", standalone_host, standalone_director,
		Callable(self, "_reward_sink"), 29
	)
	var standalone_interaction := standalone_binding.get_node(
		"OwnedSurveyBunkerInteraction"
	)
	var standalone_completed: Dictionary = standalone_interaction.call(
		&"submit_interaction", standalone_actor, 29, 1
	)
	var before_start := standalone_binding.call(&"get_snapshot") as Dictionary
	var standalone_saved := standalone_binding.call(&"get_session_snapshot") as Dictionary
	var standalone_detached: Dictionary = standalone_binding.call(&"detach")
	standalone_host.attachment_generation = 2
	var standalone_reentered: Dictionary = standalone_binding.call(&"reenter")
	var standalone_restored: Dictionary = standalone_binding.call(
		&"restore_session_snapshot", standalone_saved
	)
	var standalone_started: Dictionary = standalone_binding.call(&"start_relay_survey")
	var after_start := standalone_binding.call(&"get_snapshot") as Dictionary
	var standalone_sample := standalone_binding.get_node("OwnedSampleRackInteraction")
	var standalone_aborted: Dictionary = standalone_binding.call(
		&"abort_relay_survey", &"test_activity_failure"
	)
	var terminal_failure_layer := int(standalone_sample.collision_layer)
	var terminal_failure_marker_visible := bool(
		standalone_sample.get_node("SampleRackAnalysisMarker").visible
	)
	var terminal_failure := standalone_binding.call(&"get_snapshot") as Dictionary
	var late_after_failure: Dictionary = standalone_sample.call(
		&"submit_interaction", standalone_actor, 29, 2, 1
	)
	var after_failure := standalone_binding.call(&"get_snapshot") as Dictionary
	var failed_sample := after_failure.relay_survey.optional_checkpoints.get(
		&"ember_sample_rack_analysis_log", {}
	) as Dictionary
	_check(
		bool(standalone_configured.accepted) and bool(standalone_completed.accepted)
			and before_start.adapter.state == &"ready"
			and not bool(before_start.relay_survey.optional_checkpoint.completed)
			and bool(before_start.survey_interaction.completed)
			and bool(standalone_detached.accepted)
			and bool(standalone_reentered.accepted)
			and bool(standalone_restored.accepted)
			and bool(standalone_started.accepted)
			and bool(after_start.relay_survey.optional_checkpoint.eligible)
			and not bool(after_start.relay_survey.optional_checkpoint.completed)
			and bool(standalone_aborted.accepted)
			and not bool(terminal_failure.sample_rack_interaction.active)
			and terminal_failure_layer == 0
			and not terminal_failure_marker_visible
			and not bool(late_after_failure.accepted)
			and not bool(after_failure.sample_rack_interaction.active)
			and not bool(after_failure.sample_rack_interaction.completed)
			and not bool(failed_sample.eligible)
			and not bool(failed_sample.completed)
			and _reward_calls == 2,
		"standalone logging never starts activity and a failed survey hides its rack"
	)

	for failure in _failures:
		push_error(failure)
	print(
		"EMBER_SURVEY_OPTIONAL_CHECKPOINT_PRODUCTION_TEST_OK: %d assertions"
		% _assertions
	)
	quit(0 if _failures.is_empty() else 1)


func _reward_sink(_receipt: Dictionary) -> Dictionary:
	_reward_calls += 1
	return {"accepted": true, "reason": &"test_reward"}


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
