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
func _init() -> void: call_deferred("_run")
func _run() -> void:
	var host := FakeHost.new()
	var director := DirectorScript.new()
	root.add_child(director)
	var binding := BindingScript.new()
	root.add_child(binding)
	var configured := binding.configure(host, director, Callable(self, "_reward_sink"), 11)
	await process_frame
	var objective := binding.get_node_or_null(^"OwnedRelaySurveyPresentation") as Node3D
	var relay := objective.get_node_or_null(^"OwnedRelaySurveyMarker") as MeshInstance3D if objective != null else null
	var return_marker := objective.get_node_or_null(^"OwnedReturnSurveyMarker") as MeshInstance3D if objective != null else null
	var ready_result: Dictionary = objective.call(&"apply_activity_snapshot", {"state": &"ready"}) if objective != null else {}
	var ready_snapshot: Dictionary = objective.call(&"get_snapshot") if objective != null else {}
	var ready_shape_ok := relay != null and relay.mesh is CylinderMesh \
		and (relay.mesh as CylinderMesh).radial_segments == 4 \
		and relay.scale == Vector3(1.35, 0.55, 1.35) \
		and is_equal_approx(relay.rotation.z, PI) \
		and return_marker != null and return_marker.mesh is TorusMesh
	var started := binding.start_relay_survey()
	var presentation: Dictionary = binding.get_snapshot().relay_survey_presentation
	var active_shape_ok := relay.scale == Vector3.ONE and relay.rotation == Vector3.ZERO
	var return_result: Dictionary = objective.call(&"apply_activity_snapshot", {"state": &"awaiting_reward"})
	var return_snapshot: Dictionary = objective.call(&"get_snapshot")
	var completed_result: Dictionary = objective.call(&"apply_activity_snapshot", {"state": &"completed"})
	var completed_snapshot: Dictionary = objective.call(&"get_snapshot")
	var invalid_result: Dictionary = objective.call(&"apply_activity_snapshot", {"state": &"forged"})
	var relay_material := relay.material_override as StandardMaterial3D
	var return_material := return_marker.material_override as StandardMaterial3D
	var budget_ok := objective.get_child_count() == 2 \
		and objective.find_children("*", "Light3D", true, false).is_empty() \
		and not objective.is_processing() and not objective.is_physics_processing() \
		and relay_material != null and return_material != null \
		and relay_material != return_material \
		and is_equal_approx(relay_material.emission_energy_multiplier, 0.55) \
		and is_equal_approx(return_material.emission_energy_multiplier, 0.55)
	var detached := binding.detach()
	host.attachment_generation = 2
	var reentered := binding.reenter()
	var restored: Dictionary = binding.get_snapshot().relay_survey_presentation
	if not configured.accepted or objective == null or not ready_result.accepted \
			or ready_snapshot.cue_mode != &"approach_relay" or not ready_snapshot.relay_visible \
			or ready_snapshot.return_visible or not ready_shape_ok \
			or not started.accepted or not presentation.relay_visible \
			or presentation.cue_mode != &"active_relay" or not active_shape_ok \
			or presentation.return_visible or not detached.accepted or not reentered.accepted \
			or not return_result.accepted or return_snapshot.relay_visible \
			or not return_snapshot.return_visible or return_snapshot.cue_mode != &"return" \
			or not completed_result.accepted or not completed_snapshot.return_visible \
			or completed_snapshot.cue_mode != &"return" or invalid_result.accepted \
			or not budget_ok \
			or restored.authority.activity or restored.relay_anchor != Vector3(180.0, 120009.0, -44.0) \
			or not restored.reduced_flash_safe \
			or restored.renderer_budget != {"mesh_instances": 2, "maximum_visible_submissions": 1, "materials": 2, "lights": 0, "runtime_node_allocations_after_ready": 0}:
		push_error("relay survey presentation lifecycle failed")
		quit(1)
		return
	print("EMBER_RELAY_SURVEY_PRESENTATION_TEST_OK: shape-readable route states within 2-mesh/0-light budget")
	quit(0)
func _reward_sink(_receipt: Dictionary) -> Dictionary: return {"accepted": true, "reason": &"test_reward"}
