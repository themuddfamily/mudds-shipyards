extends SceneTree

const CLUSTER_SCENE := preload("res://scenes/world/components/nearby_sector_cluster.tscn")
const JOVIAN_DEFINITION := preload("res://assets/ships/jovian_provisional.tres")

class MockJovian:
	extends Node3D

	func get_ship_id() -> StringName:
		return &"jovian_provisional"


var _assertions := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var cluster := CLUSTER_SCENE.instantiate() as NearbySectorCluster
	root.add_child(cluster)
	await process_frame
	var binding := cluster.get_node(^"ActivityBinding") as NearbySectorActivityBinding
	var access := cluster.get_cinder_cargo_access()
	var terminal := cluster.get_cinder_cargo_destination_terminal()
	var access_counts := _presentation_counts(access)
	var terminal_counts := _presentation_counts(terminal)
	_check(
		access.get_cargo_presentation_state().state_id == &"unavailable"
		and terminal.get_cargo_presentation_state().state_id == &"unavailable"
		and float(access.get_cargo_presentation_state().cue_energy) < 0.2,
		"the production route and terminal show unavailable without a correct berth occupant"
	)

	var ship := MockJovian.new()
	ship.name = "FocusedJovianOccupant"
	root.add_child(ship)
	var berth := access.get_berth()
	var lease := berth.try_reserve(ship, JOVIAN_DEFINITION)
	_check(
		not lease.is_empty() and berth.occupy(ship, lease),
		"the production berth accepts the correctly identified Jovian fixture"
	)
	var ready := access.get_cargo_presentation_state()
	_check(
		ready.state_id == &"ready"
		and terminal.get_cargo_presentation_state().state_id == &"ready"
		and bool(ready.source_available),
		"the authority-created Jovian source makes the existing route and terminal ready"
	)

	var actor := Node3D.new()
	actor.name = "FocusedCargoActor"
	root.add_child(actor)
	actor.global_position = access.get_route_marker(&"berth_exit").global_position
	var authorized := access.authorize_disembarked_terminal_actor(
		actor, ship, lease, access.get_attachment_generation()
	)
	var started := binding.start_cargo_run()
	_check(
		bool(authorized.get("accepted", false)) and bool(started.get("accepted", false))
		and access.get_cargo_presentation_state().state_id == &"carrying"
		and terminal.get_cargo_presentation_state().state_id == &"carrying",
		"accepted disembark and cargo start illuminate the physical carrying route"
	)
	for phase_id: StringName in [&"load_crate", &"clear_gate", &"dock_platform"]:
		_check(
			bool(binding.submit_cargo_phase(phase_id).get("accepted", false)),
			"authority accepts cargo phase %s" % phase_id
		)
	var at_terminal := access.get_cargo_presentation_state()
	_check(
		at_terminal.state_id == &"at_terminal"
		and terminal.get_cargo_presentation_state().state_id == &"at_terminal"
		and float(at_terminal.cue_energy) > float(at_terminal.hazard_energy),
		"completed approach phases brighten the terminal handoff without committing inventory"
	)

	root.remove_child(cluster)
	await process_frame
	root.add_child(cluster)
	for _frame in 3:
		await process_frame
	_check(
		access.get_cargo_presentation_state().state_id == &"at_terminal"
		and int(access.get_cargo_presentation_state().attachment_generation) \
			== access.get_attachment_generation(),
		"detach/re-entry republishes the current detached activity state at the new attachment generation"
	)
	actor.global_position = terminal.to_global(CargoTransferTerminal.INTERACTION_ORIGIN)
	var wrong_actor := Node3D.new()
	root.add_child(wrong_actor)
	wrong_actor.global_position = actor.global_position
	var wrong_interaction := terminal.interact(wrong_actor)
	var rejected := access.get_cargo_presentation_state()
	_check(
		wrong_interaction
		and binding.get_last_cargo_terminal_request().reason == &"wrong_terminal_actor"
		and rejected.state_id == &"stale_rejected"
		and terminal.get_cargo_presentation_state().state_id == &"stale_rejected"
		and float(rejected.hazard_energy) > float(rejected.cue_energy),
		"a rejected actor request shows an amber no-commit state without changing cargo"
	)
	wrong_actor.queue_free()
	actor.global_position = access.get_route_marker(&"berth_exit").global_position
	var renewed_actor := access.authorize_disembarked_terminal_actor(
		actor, ship, lease, access.get_attachment_generation()
	)
	actor.global_position = terminal.to_global(CargoTransferTerminal.INTERACTION_ORIGIN)
	var committed_interaction := terminal.interact(actor)
	var committed := access.get_cargo_presentation_state()
	_check(
		bool(renewed_actor.get("accepted", false)) and committed_interaction
		and bool(binding.get_last_cargo_terminal_request().accepted)
		and committed.state_id == &"committed"
		and terminal.get_cargo_presentation_state().state_id == &"committed",
		"the exact committed receipt resolves the existing route and terminal to committed"
	)
	var reset_result := binding.reset_cargo_run()
	var reset := access.get_cargo_presentation_state()
	var terminal_allocation := terminal.get_visual_resource_allocation_audit()
	_check(
		bool(reset_result.get("accepted", false))
		and reset.state_id == &"reset"
		and terminal.get_cargo_presentation_state().state_id == &"reset"
		and _presentation_counts(access) == access_counts
		and _presentation_counts(terminal) == terminal_counts
		and bool(access.audit().valid)
		and int(terminal_allocation.visible_copies) == 4
		and int(terminal_allocation.renderer_submissions) == 4
		and int(terminal_allocation.mesh_resource_allocations) == 4
		and int(terminal_allocation.material_resource_allocations) == 3
		and int(terminal_allocation.collision_nodes) == 3
		and int(reset.node_delta) == 0
		and int(reset.light_delta) == 0
		and int(reset.submission_delta) == 0,
		"reset retains exact renderer, light, collision, interaction, and authority budgets"
	)

	cluster.queue_free()
	ship.queue_free()
	actor.queue_free()
	for _frame in 5:
		await process_frame
	_finish()


func _presentation_counts(node: Node) -> Dictionary:
	return {
		"nodes": node.find_children("*", "", true, false).size(),
		"meshes": node.find_children("*", "MeshInstance3D", true, false).size(),
		"batches": node.find_children("*", "MultiMeshInstance3D", true, false).size(),
		"lights": node.find_children("*", "Light3D", true, false).size(),
		"collisions": node.find_children("*", "CollisionShape3D", true, false).size(),
	}


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: %s" % description)


func _finish() -> void:
	if _failures.is_empty():
		print("CINDER_CARGO_TRANSFER_PRESENTATION_STATE_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		quit(1)
