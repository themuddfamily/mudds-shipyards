extends SceneTree

const BindingScript := preload(
	"res://scripts/world/ember_planetary_surface_production_binding.gd"
)
const DirectorScript := preload("res://scripts/activities/activity_director.gd")
const EXPECTED_DIRECTION := Vector3(-0.70710678, 0.0, -0.70710678)

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
	var binding := BindingScript.new() as Node
	root.add_child(binding)
	await process_frame
	var configured: Dictionary = binding.call(
		&"configure", host, director, Callable(self, "_reward_sink"), 18
	)
	var interaction := binding.get_node("OwnedSurveyBunkerInteraction") as Area3D
	var marker := interaction.get_node("SurveyLogPedestal") as MeshInstance3D
	var lintel_mesh := marker.mesh as PrismMesh
	var interaction_shape := interaction.get_node("SurveyInteractionShape") as CollisionShape3D
	var ready := binding.call(&"get_snapshot") as Dictionary
	var ready_wayfinding := ready.survey_interaction.wayfinding as Dictionary
	_check(
		bool(configured.accepted) and bool(ready_wayfinding.visible)
			and ready_wayfinding.state == &"survey_access_blade"
			and ready_wayfinding.silhouette == &"elongated_directional_blade"
			and bool(ready_wayfinding.color_independent)
			and float(ready_wayfinding.gameplay_readability_distance_m) == 24.0
			and (ready_wayfinding.direction_body_local as Vector3).is_equal_approx(
				EXPECTED_DIRECTION
			)
			and (-marker.basis.z).normalized().is_equal_approx(EXPECTED_DIRECTION)
			and marker.scale == Vector3(0.48, 1.9, 2.2)
			and marker.position == Vector3(0.0, 1.1, 0.0)
			and lintel_mesh != null
			and lintel_mesh.size == Vector3(0.72, 1.15, 0.72)
			and interaction_shape.shape is SphereShape3D
			and is_equal_approx(
				(interaction_shape.shape as SphereShape3D).radius, 0.65
			),
		"the bevelled retained mesh remains a tall directional access blade"
	)

	var completed: Dictionary = interaction.call(
		&"submit_interaction", actor, 18, 1
	)
	var deployed := binding.call(&"get_snapshot") as Dictionary
	var entry_wayfinding := deployed.survey_interaction.wayfinding as Dictionary
	var alcove := interaction.get_node("OwnedBunkerServiceAlcove") as StaticBody3D
	var structural_profile := entry_wayfinding.structural_profile as Dictionary
	var roof_collision := alcove.get_node("RoofCollision") as CollisionShape3D
	var port_collision := alcove.get_node("PortWallCollision") as CollisionShape3D
	var starboard_collision := alcove.get_node("StarboardWallCollision") as CollisionShape3D
	var response_length := float(
		deployed.survey_interaction.completion_response.length_m
	)
	_check(
		bool(completed.accepted) and bool(entry_wayfinding.visible)
			and entry_wayfinding.state == &"service_entry_lintel"
			and entry_wayfinding.silhouette \
				== &"bevelled_overhead_service_entry_lintel"
			and structural_profile.shape == &"prism_bevelled_lintel"
			and structural_profile.bounds_m == Vector3(0.72, 1.15, 0.72)
			and bool(structural_profile.bevelled_profile)
			and not bool(structural_profile.collision_changed)
			and int(structural_profile.triangle_count) > 0
			and int(structural_profile.triangle_count) <= 12
			and marker.scale == Vector3(2.2, 0.22, 0.7)
			and is_equal_approx(marker.position.y, 2.35)
			and marker.position.x < 0.0 and marker.position.z < 0.0
			and alcove.collision_layer == 1
			and (roof_collision.shape as BoxShape3D).size \
				== Vector3(2.76, 0.18, response_length)
			and (port_collision.shape as BoxShape3D).size \
				== Vector3(0.18, 2.6, response_length)
			and (starboard_collision.shape as BoxShape3D).size \
				== Vector3(0.18, 2.6, response_length)
			and not bool(entry_wayfinding.authority.collision)
			and not bool(entry_wayfinding.authority.navigation)
			and _reward_calls == 0,
		"completion lowers a bevelled lintel above the unchanged walkable alcove"
	)

	var detached: Dictionary = binding.call(&"detach")
	var while_detached := binding.call(&"get_snapshot") as Dictionary
	host.attachment_generation = 2
	var reentered: Dictionary = binding.call(&"reenter")
	var retained := binding.call(&"get_snapshot") as Dictionary
	_check(
		bool(detached.accepted)
			and not bool(while_detached.survey_interaction.wayfinding.visible)
			and not bool(while_detached.survey_interaction.completion_response.revealed)
			and bool(reentered.accepted)
			and bool(retained.survey_interaction.wayfinding.visible)
			and retained.survey_interaction.wayfinding.state == &"service_entry_lintel"
			and bool(retained.survey_interaction.completion_response.revealed)
			and marker.scale == Vector3(2.2, 0.22, 0.7)
			and retained.survey_interaction.wayfinding.silhouette \
				== &"bevelled_overhead_service_entry_lintel",
		"detach hides and same-generation re-entry restores the completed wayfinding"
	)

	host.generation = 19
	var stale := binding.call(&"get_snapshot") as Dictionary
	_check(
		not bool(stale.survey_interaction.wayfinding.visible)
			and not bool(stale.survey_interaction.physical.marker_visible)
			and not bool(stale.survey_interaction.completion_response.revealed)
			and not bool(stale.survey_interaction.completion_response.collision_enabled)
			and alcove.collision_layer == 0,
		"host generation drift clears stale wayfinding and alcove collision"
	)

	var next_host := FakeHost.new()
	next_host.generation = 19
	next_host.player_instance_id = actor.get_instance_id()
	var next_director := DirectorScript.new()
	root.add_child(next_director)
	var next_binding := BindingScript.new() as Node
	root.add_child(next_binding)
	await process_frame
	var next_configured: Dictionary = next_binding.call(
		&"configure", next_host, next_director,
		Callable(self, "_reward_sink"), 19
	)
	var reset := next_binding.call(&"get_snapshot") as Dictionary
	_check(
		bool(next_configured.accepted)
			and int(reset.survey_interaction.wayfinding.host_generation) == 19
			and reset.survey_interaction.wayfinding.state == &"survey_access_blade"
			and bool(reset.survey_interaction.wayfinding.visible)
			and not bool(reset.survey_interaction.completed)
			and not bool(reset.survey_interaction.completion_response.revealed)
			and reset.survey_interaction.wayfinding.marker_scale \
				== Vector3(0.48, 1.9, 2.2)
			and _reward_calls == 0,
		"a new Host generation starts with fresh access wayfinding only"
	)

	var incremental := reset.survey_interaction.wayfinding.incremental_budget as Dictionary
	var reset_profile := reset.survey_interaction.wayfinding.structural_profile as Dictionary
	_check(
		incremental == {
			"nodes": 0, "mesh_instances": 0, "materials": 0,
			"triangles": 0, "collision_shapes": 0,
		}
			and reset.survey_interaction.wayfinding.reused_node \
				== &"SurveyLogPedestal"
			and int(reset_profile.triangle_count) \
				== int(entry_wayfinding.structural_profile.triangle_count)
			and int(reset_profile.triangle_count) == 8
			and int(deployed.survey_interaction.completion_response.runtime_nodes) == 7
			and int(deployed.survey_interaction.completion_response.mesh_instances) == 3
			and int(deployed.survey_interaction.completion_response.collision_shapes) == 3
			and int(deployed.survey_interaction.completion_response.triangles) == 36
			and reset.survey_interaction.evidence.content_class == &"NEW"
			and reset.survey_interaction.evidence.status == &"modern_interpretation"
			and not bool(reset.survey_interaction.evidence.historical_claim)
			and not bool(reset.survey_interaction.wayfinding.authority.movement)
			and not bool(reset.survey_interaction.wayfinding.authority.activity)
			and not bool(reset.survey_interaction.wayfinding.authority.reward),
		"wayfinding adds no nodes, triangles, collision, or adjacent authority"
	)

	for failure in _failures:
		push_error(failure)
	print("EMBER_BUNKER_WAYFINDING_PRODUCTION_TEST_OK: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _reward_sink(_receipt: Dictionary) -> Dictionary:
	_reward_calls += 1
	return {"accepted": true, "reason": &"test_reward"}


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
