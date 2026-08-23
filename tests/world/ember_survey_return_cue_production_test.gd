extends SceneTree

const BindingScript := preload(
	"res://scripts/world/ember_planetary_surface_production_binding.gd"
)
const DirectorScript := preload("res://scripts/activities/activity_director.gd")
const RELAY_ANCHOR := Vector3(180.0, 120009.0, -44.0)
const RETURN_ANCHOR := Vector3(540.0, 120030.0, -210.0)

class FakeHost:
	var generation := 30
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
		&"configure", host, director, Callable(self, "_reward_sink"), 30
	)
	var started: Dictionary = binding.call(&"start_relay_survey")
	var objective := binding.get_node("OwnedRelaySurveyPresentation") as Node3D
	var marker := objective.get_node("OwnedRelaySurveyMarker") as MeshInstance3D
	var before_log := binding.call(&"get_snapshot") as Dictionary
	_check(
		bool(configured.accepted) and bool(started.accepted)
			and not bool(before_log.relay_survey_presentation.route_direction.active)
			and before_log.relay_survey_presentation.cue_mode == &"active_relay"
			and marker.position == RELAY_ANCHOR,
		"the directional return cue stays off before the optional log"
	)

	var interaction := binding.get_node("OwnedSurveyBunkerInteraction")
	var logged: Dictionary = interaction.call(
		&"submit_interaction", actor, 30, 1
	)
	var toward_relay := binding.call(&"get_snapshot") as Dictionary
	var relay_direction := (
		toward_relay.relay_survey_presentation.route_direction as Dictionary
	)
	_check(
		bool(logged.accepted) and bool(relay_direction.active)
			and relay_direction.mode == &"bunker_return_to_relay"
			and relay_direction.target_id == &"ember_relay_tower"
			and relay_direction.target_anchor == RELAY_ANCHOR
			and relay_direction.silhouette == &"broad_downward_pyramid"
			and bool(relay_direction.color_independent)
			and marker.position == RELAY_ANCHOR
			and marker.scale == Vector3(1.35, 0.55, 1.35)
			and is_equal_approx(marker.rotation.z, PI)
			and not bool(relay_direction.authority.navigation)
			and not bool(relay_direction.authority.movement),
		"logging points the reused broad pyramid back to the mandatory relay"
	)

	var detached: Dictionary = binding.call(&"detach")
	var while_detached := binding.call(&"get_snapshot") as Dictionary
	var marker_hidden_while_detached := not marker.visible
	host.attachment_generation = 2
	var reentered: Dictionary = binding.call(&"reenter")
	var after_reentry := binding.call(&"get_snapshot") as Dictionary
	_check(
		bool(detached.accepted)
			and not bool(while_detached.relay_survey_presentation.route_direction.active)
			and marker_hidden_while_detached
			and bool(reentered.accepted)
			and bool(after_reentry.relay_survey_presentation.route_direction.active)
			and after_reentry.relay_survey_presentation.route_direction.target_id \
				== &"ember_relay_tower"
			and bool(marker.visible),
		"same-run detach hides and re-entry restores the relay direction"
	)

	var reached_relay: Dictionary = binding.call(
		&"submit_relay_survey_position", RELAY_ANCHOR
	)
	var toward_return := binding.call(&"get_snapshot") as Dictionary
	var return_direction := (
		toward_return.relay_survey_presentation.route_direction as Dictionary
	)
	_check(
		bool(reached_relay.accepted) and bool(return_direction.active)
			and return_direction.mode == &"bunker_return_to_return"
			and return_direction.target_id == &"ember_return_beacon"
			and return_direction.target_anchor == RETURN_ANCHOR
			and int(return_direction.next_checkpoint_index) == 1
			and marker.position == RETURN_ANCHOR,
		"authoritative checkpoint zero retargets the same pyramid to return"
	)

	var reached_return: Dictionary = binding.call(
		&"submit_relay_survey_position", RETURN_ANCHOR
	)
	var awaiting := binding.call(&"get_snapshot") as Dictionary
	var committed: Dictionary = binding.call(&"commit_relay_survey_reward")
	var completed := binding.call(&"get_snapshot") as Dictionary
	_check(
		bool(reached_return.accepted)
			and not bool(awaiting.relay_survey_presentation.route_direction.active)
			and awaiting.relay_survey_presentation.route_direction.target_id == &""
			and not bool(marker.visible)
			and bool(awaiting.relay_survey_presentation.return_visible)
			and bool(committed.accepted) and _reward_calls == 1
			and not bool(completed.relay_survey_presentation.route_direction.active),
		"final mandatory progress clears the pointer before existing reward commit"
	)

	var detached_complete: Dictionary = binding.call(&"detach")
	host.attachment_generation = 3
	var reentered_complete: Dictionary = binding.call(&"reenter")
	var next_run: Dictionary = binding.call(&"start_relay_survey")
	var generation_two := binding.call(&"get_snapshot") as Dictionary
	_check(
		bool(detached_complete.accepted) and bool(reentered_complete.accepted)
			and bool(next_run.accepted)
			and int(generation_two.relay_survey.mandatory_route.activity_generation) == 2
			and int(generation_two.relay_survey.mandatory_route.next_checkpoint_index) == 0
			and not bool(generation_two.relay_survey.optional_checkpoint.completed)
			and not bool(generation_two.relay_survey_presentation.route_direction.active)
			and generation_two.relay_survey_presentation.cue_mode == &"active_relay"
			and marker.position == RELAY_ANCHOR,
		"a newer activity generation resets optional direction state"
	)

	var budget := generation_two.relay_survey_presentation.renderer_budget as Dictionary
	var incremental := generation_two.relay_survey_presentation.route_direction.incremental_budget as Dictionary
	_check(
		objective.get_child_count() == 3
			and int(budget.mesh_instances) == 3
			and int(budget.maximum_visible_submissions) == 2
			and incremental == {
				"nodes": 0, "mesh_instances": 0, "materials": 0,
				"triangles": 0, "maximum_visible_submissions": 1,
			}
			and not objective.is_processing()
			and not objective.is_physics_processing(),
		"the cue reuses the existing bounded presentation without runtime allocation"
	)

	for failure in _failures:
		push_error(failure)
	print(
		"EMBER_SURVEY_RETURN_CUE_PRODUCTION_TEST_OK: %d assertions" % _assertions
	)
	quit(0 if _failures.is_empty() else 1)


func _reward_sink(_receipt: Dictionary) -> Dictionary:
	_reward_calls += 1
	return {"accepted": true, "reason": &"test_reward"}


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
