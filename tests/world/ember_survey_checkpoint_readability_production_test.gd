extends SceneTree

const BindingScript := preload(
	"res://scripts/world/ember_planetary_surface_production_binding.gd"
)
const DirectorScript := preload("res://scripts/activities/activity_director.gd")
const RELAY_ANCHOR := Vector3(180.0, 120009.0, -44.0)
const RETURN_ANCHOR := Vector3(540.0, 120030.0, -210.0)

class FakeHost:
	var generation := 34
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
		&"configure", host, director, Callable(self, "_reward_sink"), 34
	)
	var started: Dictionary = binding.call(&"start_relay_survey")
	var objective := binding.get_node("OwnedRelaySurveyPresentation") as Node3D
	var relay_marker := objective.get_node("OwnedRelaySurveyMarker") as MeshInstance3D
	var return_marker := objective.get_node("OwnedReturnSurveyMarker") as MeshInstance3D
	var interaction := binding.get_node("OwnedSurveyBunkerInteraction")
	var initial := binding.call(&"get_snapshot") as Dictionary
	var zero_progress := (
		initial.relay_survey_presentation.mandatory_checkpoint_progress as Dictionary
	)
	_check(
		bool(configured.accepted) and bool(started.accepted)
			and bool(zero_progress.visible)
			and zero_progress.state == &"relay_checkpoint_pending"
			and zero_progress.progress_text == "0 / 2 MANDATORY"
			and zero_progress.silhouette == &"single_directional_pyramid"
			and relay_marker.visible and not return_marker.visible
			and relay_marker.position == RELAY_ANCHOR
			and relay_marker.scale == Vector3.ONE,
		"checkpoint 0/2 is readable as the single relay pyramid"
	)

	var reached_relay: Dictionary = binding.call(
		&"submit_relay_survey_position", RELAY_ANCHOR
	)
	var after_relay := binding.call(&"get_snapshot") as Dictionary
	var one_progress := (
		after_relay.relay_survey_presentation.mandatory_checkpoint_progress as Dictionary
	)
	_check(
		bool(reached_relay.accepted) and bool(one_progress.visible)
			and one_progress.state == &"relay_reached_return_pending"
			and one_progress.progress_text == "1 / 2 MANDATORY"
			and one_progress.silhouette == &"vertical_oval_return_ring"
			and not relay_marker.visible and return_marker.visible
			and return_marker.position == RETURN_ANCHOR
			and return_marker.scale == Vector3(0.82, 1.28, 0.82)
			and after_relay.relay_survey_presentation.cue_mode \
				== &"mandatory_return_checkpoint",
		"accepted checkpoint 0 switches to a distinct oval return ring"
	)

	var detached: Dictionary = binding.call(&"detach")
	var while_detached := binding.call(&"get_snapshot") as Dictionary
	var hidden_while_detached := not relay_marker.visible and not return_marker.visible
	host.attachment_generation = 2
	var reentered: Dictionary = binding.call(&"reenter")
	var retained := binding.call(&"get_snapshot") as Dictionary
	_check(
		bool(detached.accepted) and hidden_while_detached
			and not bool(while_detached.relay_survey_presentation.mandatory_checkpoint_progress.visible)
			and bool(reentered.accepted)
			and retained.relay_survey_presentation.mandatory_checkpoint_progress.state \
				== &"relay_reached_return_pending"
			and retained.relay_survey_presentation.mandatory_checkpoint_progress.progress_text \
				== "1 / 2 MANDATORY"
			and return_marker.visible
			and return_marker.scale == Vector3(0.82, 1.28, 0.82),
		"same-generation re-entry restores the accepted 1/2 geometry state"
	)

	var logged: Dictionary = interaction.call(
		&"submit_interaction", actor, 34, 2
	)
	var with_optional := binding.call(&"get_snapshot") as Dictionary
	_check(
		bool(logged.accepted)
			and bool(with_optional.relay_survey_presentation.route_direction.active)
			and with_optional.relay_survey_presentation.route_direction.target_id \
				== &"ember_return_beacon"
			and bool(with_optional.relay_survey_presentation.mandatory_checkpoint_progress.optional_pointer_preserved)
			and relay_marker.visible and return_marker.visible
			and relay_marker.position == RETURN_ANCHOR
			and return_marker.scale == Vector3(0.82, 1.28, 0.82),
		"the optional return pyramid remains over the mandatory 1/2 ring"
	)

	var reached_return: Dictionary = binding.call(
		&"submit_relay_survey_position", RETURN_ANCHOR
	)
	var route_complete := binding.call(&"get_snapshot") as Dictionary
	var two_progress := (
		route_complete.relay_survey_presentation.mandatory_checkpoint_progress as Dictionary
	)
	var committed: Dictionary = binding.call(&"commit_relay_survey_reward")
	var rewarded := binding.call(&"get_snapshot") as Dictionary
	_check(
		bool(reached_return.accepted)
			and two_progress.state == &"mandatory_route_complete"
			and two_progress.progress_text == "2 / 2 MANDATORY"
			and two_progress.silhouette == &"expanded_return_ring"
			and two_progress.return_marker_scale == Vector3(1.35, 1.35, 1.35)
			and not bool(route_complete.relay_survey_presentation.route_direction.active)
			and return_marker.scale == Vector3(1.08, 1.08, 1.08)
			and bool(committed.accepted) and _reward_calls == 1
			and rewarded.relay_survey_presentation.mandatory_checkpoint_progress.state \
				== &"reward_confirmed"
			and rewarded.relay_survey_presentation.completion_response.state \
				== &"reward_confirmed",
		"2/2 hands off unchanged to route completion and reward geometry"
	)

	var detached_complete: Dictionary = binding.call(&"detach")
	host.attachment_generation = 3
	var reentered_complete: Dictionary = binding.call(&"reenter")
	var next_run: Dictionary = binding.call(&"start_relay_survey")
	var reset := binding.call(&"get_snapshot") as Dictionary
	var reset_progress := (
		reset.relay_survey_presentation.mandatory_checkpoint_progress as Dictionary
	)
	_check(
		bool(detached_complete.accepted) and bool(reentered_complete.accepted)
			and bool(next_run.accepted)
			and int(reset_progress.activity_generation) == 2
			and reset_progress.state == &"relay_checkpoint_pending"
			and reset_progress.progress_text == "0 / 2 MANDATORY"
			and relay_marker.visible and not return_marker.visible
			and relay_marker.position == RELAY_ANCHOR
			and relay_marker.scale == Vector3.ONE
			and not bool(reset.relay_survey_presentation.route_direction.active)
			and not bool(reset.relay_survey_presentation.completion_response.visible)
			and _reward_calls == 1,
		"generation 2 resets mandatory, optional-pointer, and completion geometry"
	)

	var incremental := reset_progress.incremental_budget as Dictionary
	var budget := reset.relay_survey_presentation.renderer_budget as Dictionary
	_check(
		objective.get_child_count() == 3
			and incremental == {
				"nodes": 0, "mesh_instances": 0, "materials": 0,
				"triangles": 0, "maximum_visible_submissions": 2,
			}
			and int(budget.mesh_instances) == 3
			and int(budget.maximum_visible_submissions) == 2
			and bool(reset_progress.color_independent)
			and not bool(reset_progress.authority.activity)
			and not bool(reset_progress.authority.checkpoint)
			and not bool(reset_progress.authority.navigation)
			and not bool(reset_progress.authority.movement),
		"checkpoint readability reuses the bounded zero-authority presentation"
	)

	for failure in _failures:
		push_error(failure)
	print(
		"EMBER_SURVEY_CHECKPOINT_READABILITY_PRODUCTION_TEST_OK: %d assertions"
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
