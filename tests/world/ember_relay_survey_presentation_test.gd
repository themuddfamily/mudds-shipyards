extends SceneTree
const BindingScript := preload("res://scripts/world/ember_planetary_surface_production_binding.gd")
const DirectorScript := preload("res://scripts/activities/activity_director.gd")
class FakeHost:
	var generation := 11
	var attachment_generation := 1
	func get_generation() -> int: return generation
	func get_attachment_generation() -> int: return attachment_generation
	func get_phase() -> int: return 8
	func get_snapshot() -> Dictionary: return {"host_id": &"ember_surface_loop", "attached": true, "phase_id": &"on_foot", "identities": {"world_id": &"ember_moon"}}
var _reward_commit_count := 0
func _init() -> void: call_deferred("_run")
func _run() -> void:
	var host := FakeHost.new()
	var director := DirectorScript.new()
	root.add_child(director)
	# Keep calls dynamic so this focused lifecycle witness remains compatible
	# with project builds that do not register the external binding class cache.
	var binding := BindingScript.new() as Node
	root.add_child(binding)
	var configured: Dictionary = binding.call(
		&"configure", host, director, Callable(self, "_reward_sink"), 11
	)
	await process_frame
	var objective := binding.get_node_or_null(^"OwnedRelaySurveyPresentation") as Node3D
	var relay := objective.get_node_or_null(^"OwnedRelaySurveyMarker") as MeshInstance3D if objective != null else null
	var return_marker := objective.get_node_or_null(^"OwnedReturnSurveyMarker") as MeshInstance3D if objective != null else null
	var completion_seal := objective.get_node_or_null(^"OwnedRewardCompletionSeal") as MeshInstance3D if objective != null else null
	var started: Dictionary = binding.call(&"start_relay_survey")
	var active_snapshot: Dictionary = (binding.call(&"get_snapshot") as Dictionary).relay_survey_presentation
	var reached_relay: Dictionary = binding.call(
		&"submit_relay_survey_position", Vector3(180.0, 120009.0, -44.0)
	)
	var reached_return: Dictionary = binding.call(
		&"submit_relay_survey_position", Vector3(540.0, 120030.0, -210.0)
	)
	var awaiting_snapshot: Dictionary = (binding.call(&"get_snapshot") as Dictionary).relay_survey_presentation
	var committed: Dictionary = binding.call(&"commit_relay_survey_reward")
	var completed_snapshot: Dictionary = (binding.call(&"get_snapshot") as Dictionary).relay_survey_presentation
	var invalid_result: Dictionary = objective.call(&"apply_activity_snapshot", {"state": &"forged"})
	var relay_material := relay.material_override as StandardMaterial3D
	var return_material := return_marker.material_override as StandardMaterial3D
	var completion_material := completion_seal.material_override as StandardMaterial3D if completion_seal != null else null
	var completion_mesh := completion_seal.mesh as BoxMesh if completion_seal != null else null
	var route_shape_ok := relay != null and relay.mesh is CylinderMesh \
		and (relay.mesh as CylinderMesh).radial_segments == 4 \
		and relay.scale == Vector3.ONE and relay.rotation == Vector3.ZERO \
		and return_marker != null and return_marker.mesh is TorusMesh
	var completion_shape_ok := completion_mesh != null \
		and completion_mesh.size == Vector3(3.4, 3.4, 0.55) \
		and completion_seal.position == Vector3(540.0, 120030.0, -210.0) \
		and is_equal_approx(completion_seal.rotation.z, PI * 0.25)
	var budget_ok := objective.get_child_count() == 3 \
		and objective.find_children("*", "Light3D", true, false).is_empty() \
		and not objective.is_processing() and not objective.is_physics_processing() \
		and relay_material != null and return_material != null and completion_material != null \
		and relay_material != return_material and completion_material != return_material \
		and is_equal_approx(relay_material.emission_energy_multiplier, 0.55) \
		and is_equal_approx(return_material.emission_energy_multiplier, 0.55) \
		and is_equal_approx(completion_material.emission_energy_multiplier, 0.55)
	var detached: Dictionary = binding.call(&"detach")
	var detached_snapshot: Dictionary = objective.call(&"get_snapshot")
	host.attachment_generation = 2
	var reentered: Dictionary = binding.call(&"reenter")
	var restored: Dictionary = (binding.call(&"get_snapshot") as Dictionary).relay_survey_presentation
	if not configured.accepted or objective == null or relay == null or return_marker == null \
			or completion_seal == null or not started.accepted \
			or active_snapshot.cue_mode != &"active_relay" or not active_snapshot.relay_visible \
			or active_snapshot.return_visible or active_snapshot.completion_visible \
			or not reached_relay.accepted or not reached_return.accepted \
			or not awaiting_snapshot.return_visible or awaiting_snapshot.completion_visible \
			or awaiting_snapshot.cue_mode != &"return" or not committed.accepted \
			or _reward_commit_count != 1 or not completed_snapshot.return_visible \
			or not completed_snapshot.completion_visible \
			or completed_snapshot.cue_mode != &"reward_confirmed" or invalid_result.accepted \
			or not route_shape_ok or not completion_shape_ok or not budget_ok \
			or not detached.accepted or detached_snapshot.return_visible \
			or detached_snapshot.completion_visible or not reentered.accepted \
			or restored.authority.activity or restored.relay_anchor != Vector3(180.0, 120009.0, -44.0) \
			or not restored.return_visible or not restored.completion_visible \
			or restored.cue_mode != &"reward_confirmed" \
			or not restored.reward_confirmation_persistent or not restored.reduced_flash_safe \
			or restored.renderer_budget != {"mesh_instances": 3, "maximum_visible_submissions": 2, "materials": 3, "lights": 0, "runtime_node_allocations_after_ready": 0}:
		push_error("relay survey presentation lifecycle failed")
		quit(1)
		return
	print("EMBER_RELAY_SURVEY_PRESENTATION_TEST_OK: authoritative reward commit leaves a persistent diamond seal")
	quit(0)
func _reward_sink(_receipt: Dictionary) -> Dictionary:
	_reward_commit_count += 1
	return {"accepted": true, "reason": &"test_reward"}
