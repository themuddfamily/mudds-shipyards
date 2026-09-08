extends SceneTree

const BindingScript := preload("res://scripts/world/ember_planetary_surface_production_binding.gd")
const DirectorScript := preload("res://scripts/activities/activity_director.gd")

class FakeHost:
	var generation := 18
	var attachment_generation := 1
	var player_instance_id := 0
	var snapshot_count := 0
	var observation_count := 0
	var phase_id := &"on_foot"
	func get_generation() -> int: return generation
	func get_attachment_generation() -> int: return attachment_generation
	func get_phase() -> int: return 8
	func get_snapshot() -> Dictionary:
		snapshot_count += 1
		return _observation()
	func _observation() -> Dictionary:
		return {
			"host_id": &"ember_surface_loop", "attached": true,
			"phase_id": phase_id,
			"identities": {
				"world_id": &"ember_moon",
				"player_instance_id": player_instance_id,
			},
		}

class ObservedHost:
	extends FakeHost
	func get_return_status_snapshot() -> Dictionary:
		observation_count += 1
		return _observation()

var _assertions := 0
var _failures := PackedStringArray()
var _reward_calls := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var legacy_views := await _exercise(FakeHost.new())
	var narrow_views := await _exercise(ObservedHost.new())
	_check(legacy_views == narrow_views, "focused Host reports preserve bunker presentation and persistence")
	for failure in _failures:
		push_error(failure)
	print("EMBER_SURVEY_BUNKER_INTERACTION_PRODUCTION_TEST_OK: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _exercise(host: FakeHost) -> Array:
	var views: Array = []
	var actor := Node3D.new()
	root.add_child(actor)
	host.player_instance_id = actor.get_instance_id()
	var director := DirectorScript.new()
	root.add_child(director)
	var binding := BindingScript.new()
	root.add_child(binding)
	await process_frame
	var configured := binding.configure(host, director, Callable(self, "_reward_sink"), 18)
	var interaction := binding.get_node("OwnedSurveyBunkerInteraction")
	var ready := binding.get_snapshot().survey_interaction as Dictionary
	_check_observation(interaction, host, ready, views)
	var concealed_response := ready.completion_response as Dictionary
	_check(
		bool(configured.accepted)
			and ready.position_body_local_m == Vector3(-17.5, 120000.0, -17.5)
			and ready.prompt == "[ E ]  LOG BUNKER / GANTRY SURVEY"
			and int(ready.physical.collision_layer) == 8
			and bool(ready.physical.marker_visible)
			and not bool(concealed_response.revealed)
			and not bool(concealed_response.collision_enabled),
		"the production composition exposes a physical authored bunker approach point"
	)
	var stale: Dictionary = interaction.call(&"submit_interaction", actor, 17, 1)
	var completed: Dictionary = interaction.call(&"submit_interaction", actor, 18, 1)
	var duplicate: Dictionary = interaction.call(&"submit_interaction", actor, 18, 1)
	var completed_snapshot := binding.get_snapshot().survey_interaction as Dictionary
	_check_observation(interaction, host, completed_snapshot, views)
	var deployed_response := completed_snapshot.completion_response as Dictionary
	var alcove := interaction.get_node("OwnedBunkerServiceAlcove") as StaticBody3D
	var alcove_meshes := alcove.find_children("*Visual", "MeshInstance3D", false, false)
	var alcove_shapes := alcove.find_children("*Collision", "CollisionShape3D", false, false)
	_check(
		not bool(stale.accepted) and bool(completed.accepted) and not bool(duplicate.accepted)
			and duplicate.reason == &"survey_interaction_already_completed"
			and bool(completed_snapshot.completed)
			and completed_snapshot.prompt == "[ COMPLETE ]  BUNKER / GANTRY SURVEY LOGGED"
			and not bool(completed_snapshot.last_receipt.activity_started)
			and not bool(completed_snapshot.last_receipt.reward_granted)
			and not bool(completed_snapshot.last_receipt.historical_claim)
			and _reward_calls == 0
			and bool(deployed_response.revealed)
			and bool(deployed_response.collision_enabled)
			and bool(deployed_response.open_route)
			and float(deployed_response.corridor_width_m) == 2.4
			and float(deployed_response.headroom_m) == 2.6
			and int(deployed_response.runtime_nodes) == 7
			and int(deployed_response.triangles) == 36
			and alcove.collision_layer == 1
			and alcove_meshes.size() == 3 and alcove_shapes.size() == 3,
		"completion deploys one collision-backed open service alcove without reward"
	)
	var saved := binding.get_session_snapshot()
	_check(
		bool(saved.survey_interaction.completed)
			and int(saved.survey_interaction.attachment_generation) == 1,
		"the existing planetary session seam retains the completed survey"
	)
	var detached := binding.detach()
	var while_detached := binding.get_snapshot().survey_interaction as Dictionary
	_check_observation(interaction, host, while_detached, views)
	var detached_response := while_detached.completion_response as Dictionary
	host.attachment_generation = 2
	var reentered := binding.reenter()
	var retained := binding.get_snapshot().survey_interaction as Dictionary
	_check_observation(interaction, host, retained, views)
	var retained_response := retained.completion_response as Dictionary
	_check(
		bool(detached.accepted) and bool(reentered.accepted)
			and not bool(detached_response.revealed)
			and not bool(detached_response.collision_enabled)
			and bool(retained.completed) and int(retained.physical.collision_layer) == 8
			and bool(retained_response.revealed)
			and bool(retained_response.collision_enabled)
			and not bool(interaction.interact(actor)),
		"detach removes the alcove collision and re-entry restores it without replay"
	)
	var restored := binding.restore_session_snapshot(saved)
	var after_restore := binding.get_snapshot().survey_interaction as Dictionary
	_check_observation(interaction, host, after_restore, views)
	var restored_response := after_restore.completion_response as Dictionary
	_check(
		bool(restored.accepted) and bool(after_restore.completed)
			and int(after_restore.completion_attachment_generation) == 1
			and bool(restored_response.revealed)
			and bool(restored_response.collision_enabled)
			and not bool(after_restore.authority.movement)
			and not bool(after_restore.authority.activity)
			and not bool(after_restore.authority.reward)
			and not bool(after_restore.authority.save),
		"newer generation admits the saved completion without gaining adjacent authority"
	)
	host.phase_id = &"reboarded"
	var hidden: Dictionary = interaction.get_snapshot()
	_check_observation(interaction, host, hidden, views)
	_check(hidden.prompt.is_empty() and hidden.physical.collision_layer == 0
		and not hidden.physical.marker_visible and not hidden.completion_response.revealed
		and not hidden.completion_response.collision_enabled and not hidden.service_terminal.available,
		"fresh off-foot phase hides prompt, marker, alcove collision and service availability")
	host.phase_id = &"on_foot"
	var current: Dictionary = interaction.get_snapshot()
	_check(current == after_restore, "returning to the same current phase restores the physical presentation")
	binding.queue_free()
	director.queue_free()
	actor.queue_free()
	await process_frame
	return views


func _check_observation(interaction: Object, host: FakeHost, expected: Dictionary, views: Array) -> void:
	var full_before := host.snapshot_count
	var narrow_before := host.observation_count
	var snapshot: Dictionary = interaction.get_snapshot()
	var expected_reads := 1 if snapshot.attached else 0
	_check(host.snapshot_count - full_before + host.observation_count - narrow_before == expected_reads,
		"bunker report samples current Host once for prompt, marker, collision and service")
	if host is ObservedHost:
		_check(host.snapshot_count == full_before, "focused bunker report builds no Host diagnostics")
	_check(snapshot == expected, "direct interaction report preserves the production-composed report")
	views.append(snapshot.duplicate(true))


func _reward_sink(_receipt: Dictionary) -> Dictionary:
	_reward_calls += 1
	return {"accepted": true, "reason": &"test_reward"}


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
