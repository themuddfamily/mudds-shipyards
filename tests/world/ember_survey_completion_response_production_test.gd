extends SceneTree

const BindingScript := preload(
	"res://scripts/world/ember_planetary_surface_production_binding.gd"
)
const DirectorScript := preload("res://scripts/activities/activity_director.gd")
const RELAY_ANCHOR := Vector3(180.0, 120009.0, -44.0)
const RETURN_ANCHOR := Vector3(540.0, 120030.0, -210.0)

class FakeHost:
	var generation := 32
	var attachment_generation := 1
	func get_generation() -> int: return generation
	func get_attachment_generation() -> int: return attachment_generation
	func get_phase() -> int: return 8
	func get_snapshot() -> Dictionary:
		return {
			"host_id": &"ember_surface_loop", "attached": true,
			"phase_id": &"on_foot",
			"identities": {"world_id": &"ember_moon"},
		}

var _assertions := 0
var _failures := PackedStringArray()
var _reward_calls := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := FakeHost.new()
	var director := DirectorScript.new()
	root.add_child(director)
	var binding := BindingScript.new() as Node
	root.add_child(binding)
	await process_frame
	var configured: Dictionary = binding.call(
		&"configure", host, director, Callable(self, "_reward_sink"), 32
	)
	var objective := binding.get_node("OwnedRelaySurveyPresentation") as Node3D
	var return_ring := objective.get_node("OwnedReturnSurveyMarker") as MeshInstance3D
	var reward_seal := objective.get_node("OwnedRewardCompletionSeal") as MeshInstance3D
	var started: Dictionary = binding.call(&"start_relay_survey")
	var reached_relay: Dictionary = binding.call(
		&"submit_relay_survey_position", RELAY_ANCHOR
	)
	var reached_return: Dictionary = binding.call(
		&"submit_relay_survey_position", RETURN_ANCHOR
	)
	var awaiting := binding.call(&"get_snapshot") as Dictionary
	var route_response := (
		awaiting.relay_survey_presentation.completion_response as Dictionary
	)
	_check(
		bool(configured.accepted) and bool(started.accepted)
			and bool(reached_relay.accepted) and bool(reached_return.accepted)
			and bool(route_response.visible)
			and route_response.state == &"route_complete_pending_reward"
			and route_response.status_text == "Survey route locked — return data ready"
			and route_response.anchor == RETURN_ANCHOR
			and bool(route_response.route_complete)
			and not bool(route_response.reward_committed)
			and route_response.silhouette == &"expanded_return_ring"
			and return_ring.visible
			and return_ring.scale == Vector3(1.35, 1.35, 1.35)
			and not reward_seal.visible and _reward_calls == 0,
		"mandatory route completion expands the existing return ring before reward"
	)

	var detached: Dictionary = binding.call(&"detach")
	var detached_snapshot := binding.call(&"get_snapshot") as Dictionary
	var hidden_while_detached := not return_ring.visible and not reward_seal.visible
	host.attachment_generation = 2
	var reentered: Dictionary = binding.call(&"reenter")
	var retained := binding.call(&"get_snapshot") as Dictionary
	_check(
		bool(detached.accepted) and hidden_while_detached
			and not bool(detached_snapshot.relay_survey_presentation.completion_response.visible)
			and bool(detached_snapshot.relay_survey_presentation.completion_response.route_complete)
			and bool(reentered.accepted)
			and bool(retained.relay_survey_presentation.completion_response.visible)
			and retained.relay_survey_presentation.completion_response.state \
				== &"route_complete_pending_reward"
			and return_ring.scale == Vector3(1.35, 1.35, 1.35),
		"same-generation re-entry restores the pending route-complete response"
	)

	var committed: Dictionary = binding.call(&"commit_relay_survey_reward")
	var duplicate: Dictionary = binding.call(&"commit_relay_survey_reward")
	var completed := binding.call(&"get_snapshot") as Dictionary
	var reward_response := (
		completed.relay_survey_presentation.completion_response as Dictionary
	)
	_check(
		bool(committed.accepted) and not bool(duplicate.accepted)
			and _reward_calls == 1
			and bool(reward_response.visible)
			and reward_response.state == &"reward_confirmed"
			and reward_response.status_text == "Survey data accepted"
			and bool(reward_response.reward_committed)
			and reward_response.silhouette == &"ring_and_expanded_diamond"
			and return_ring.scale == Vector3(1.08, 1.08, 1.08)
			and reward_seal.visible
			and reward_seal.scale == Vector3(1.18, 1.18, 1.18),
		"the existing reward commit expands the diamond exactly once"
	)

	var detached_completed: Dictionary = binding.call(&"detach")
	host.attachment_generation = 3
	var reentered_completed: Dictionary = binding.call(&"reenter")
	var restored_completed := binding.call(&"get_snapshot") as Dictionary
	_check(
		bool(detached_completed.accepted) and bool(reentered_completed.accepted)
			and restored_completed.relay_survey_presentation.completion_response.state \
				== &"reward_confirmed"
			and reward_seal.visible
			and reward_seal.scale == Vector3(1.18, 1.18, 1.18),
		"same-generation re-entry restores the committed reward response"
	)

	var next_run: Dictionary = binding.call(&"start_relay_survey")
	var reset := binding.call(&"get_snapshot") as Dictionary
	var reset_response := (
		reset.relay_survey_presentation.completion_response as Dictionary
	)
	_check(
		bool(next_run.accepted)
			and int(reset_response.activity_generation) == 2
			and not bool(reset_response.visible)
			and not bool(reset_response.route_complete)
			and not bool(reset_response.reward_committed)
			and reset_response.state == &"hidden"
			and not return_ring.visible and not reward_seal.visible
			and return_ring.scale == Vector3.ONE
			and reward_seal.scale == Vector3.ONE
			and _reward_calls == 1,
		"a new activity generation clears geometry and reward confirmation"
	)

	var budget := reset.relay_survey_presentation.renderer_budget as Dictionary
	var incremental := reset_response.incremental_budget as Dictionary
	_check(
		objective.get_child_count() == 3
			and int(budget.mesh_instances) == 3
			and int(budget.maximum_visible_submissions) == 2
			and incremental == {
				"nodes": 0, "mesh_instances": 0, "materials": 0,
				"triangles": 0, "lights": 0,
			}
			and not bool(reset_response.authority.activity)
			and not bool(reset_response.authority.reward)
			and not bool(reset_response.authority.movement)
			and not bool(reset_response.authority.navigation),
		"the response reuses the three-node presentation with zero new authority"
	)

	for failure in _failures:
		push_error(failure)
	print(
		"EMBER_SURVEY_COMPLETION_RESPONSE_PRODUCTION_TEST_OK: %d assertions"
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
