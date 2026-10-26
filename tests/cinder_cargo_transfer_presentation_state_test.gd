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
	cluster.set_reduced_flash_enabled(true)
	root.add_child(cluster)
	await process_frame
	var binding := cluster.get_node(^"ActivityBinding") as NearbySectorActivityBinding
	var access := cluster.get_cinder_cargo_access()
	var terminal := cluster.get_cinder_cargo_destination_terminal()
	var access_counts := _presentation_counts(access)
	var terminal_counts := _presentation_counts(terminal)
	_check(
		bool(terminal.get_cargo_presentation_state().get("reduced_flash", false))
		and is_equal_approx(_screen_energy(terminal), 0.18),
		"a preference selected before construction reaches the first terminal publication without brightening it"
	)
	cluster.set_reduced_flash_enabled(false)
	_check(
		access.get_cargo_presentation_state().state_id == &"unavailable"
		and terminal.get_cargo_presentation_state().state_id == &"unavailable"
		and float(access.get_cargo_presentation_state().cue_energy) < 0.2,
		"the production route and terminal show unavailable without a correct berth occupant"
	)
	_check_flash_policy(cluster, binding, access, terminal, &"unavailable", 0.18)

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
	_check_flash_policy(cluster, binding, access, terminal, &"ready", 1.15)

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
	_check_flash_policy(cluster, binding, access, terminal, &"carrying", 2.2)
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
	_check_flash_policy(cluster, binding, access, terminal, &"at_terminal", 3.0)

	cluster.set_reduced_flash_enabled(true)
	root.remove_child(cluster)
	await process_frame
	_check(
		access.get_supply_phase_target_position(&"dock_platform") == Vector3.INF
		and not (binding.get_snapshot().cargo as Dictionary).has("minimap_target_position"),
		"detached cargo access withdraws world guidance without reading a detached berth transform"
	)
	root.add_child(cluster)
	for _frame in 3:
		await process_frame
	_check(
		access.get_cargo_presentation_state().state_id == &"at_terminal"
		and access.get_supply_phase_target_position(&"dock_platform").is_equal_approx(
			berth.get_dock_transform().origin
		)
		and int(access.get_cargo_presentation_state().attachment_generation) \
			== access.get_attachment_generation()
		and bool(terminal.get_cargo_presentation_state().reduced_flash)
		and is_equal_approx(_screen_energy(terminal), 1.15),
		"detach/re-entry republishes the current detached activity state at the new attachment generation"
	)
	cluster.set_reduced_flash_enabled(false)
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
	_check_flash_policy(cluster, binding, access, terminal, &"stale_rejected", 3.2)
	cluster.set_reduced_flash_enabled(true)
	var rejected_authority := terminal.get_cargo_presentation_state().authority_record as Dictionary
	cluster.set_cluster_enabled(false)
	cluster.set_cluster_enabled(true)
	_check(
		terminal.get_cargo_presentation_state().authority_record == rejected_authority
		and terminal.get_cargo_presentation_state().state_id == &"stale_rejected"
		and is_equal_approx(_screen_energy(terminal), 1.15),
		"stream visibility changes retain the selected cap and exact terminal refusal"
	)
	cluster.set_reduced_flash_enabled(false)
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
	_check_flash_policy(cluster, binding, access, terminal, &"committed", 2.7)
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
	_check_flash_policy(cluster, binding, access, terminal, &"reset", 0.25)

	cluster.queue_free()
	ship.queue_free()
	actor.queue_free()
	for _frame in 5:
		await process_frame
	_finish()


func _check_flash_policy(
		cluster: NearbySectorCluster,
		binding: NearbySectorActivityBinding,
		access: CinderCargoAccess,
		terminal: CargoTransferTerminal,
		state_id: StringName,
		authored_energy: float
	) -> void:
	var original := terminal.get_cargo_presentation_state()
	var original_access := access.get_cargo_presentation_state()
	var protected := _cargo_authority_state(binding, access, terminal)
	var screen := terminal.get_node(^"StatusScreen") as MeshInstance3D
	var material := screen.material_override as StandardMaterial3D
	_check(
		original.state_id == state_id
		and is_equal_approx(_screen_energy(terminal), authored_energy),
		"%s starts at its authored OFF material energy" % state_id
	)
	cluster.set_reduced_flash_enabled(true)
	var reduced := terminal.get_cargo_presentation_state()
	var reduced_access := access.get_cargo_presentation_state()
	var expected := original.duplicate(true)
	expected["reduced_flash"] = true
	expected["emission_energy"] = minf(authored_energy, 1.15)
	var expected_access := original_access.duplicate(true)
	expected_access["reduced_flash"] = true
	_check(
		reduced == expected and reduced_access == expected_access
		and screen.material_override == material
		and is_equal_approx(_screen_energy(terminal), minf(authored_energy, 1.15))
		and _cargo_authority_state(binding, access, terminal) == protected,
		"%s ON immediately caps the existing material while preserving exact text, data and authority" % state_id
	)
	cluster.set_reduced_flash_enabled(false)
	_check(
		terminal.get_cargo_presentation_state() == original
		and access.get_cargo_presentation_state() == original_access
		and screen.material_override == material
		and is_equal_approx(_screen_energy(terminal), authored_energy)
		and _cargo_authority_state(binding, access, terminal) == protected,
		"%s OFF restores its current authored policy without changing cargo or presentation identity" % state_id
	)


func _cargo_authority_state(
		binding: NearbySectorActivityBinding,
		access: CinderCargoAccess,
		terminal: CargoTransferTerminal
	) -> Dictionary:
	var authority := binding.get_cargo_transfer_authority()
	var source_handle := binding.get_cargo_source_handle()
	var destination_handle := binding.get_cargo_destination_handle()
	return {
		"authority_id": authority.get_instance_id(),
		"authority": authority.audit(),
		"source_handle": source_handle,
		"source_manifest": authority.get_manifest_snapshot(source_handle) if not source_handle.is_empty() else {},
		"destination_handle": destination_handle,
		"destination_manifest": authority.get_manifest_snapshot(destination_handle),
		"binding": binding.get_snapshot(),
		"last_request": binding.get_last_cargo_terminal_request(),
		"terminal": terminal.get_state_snapshot(),
		"allocation": terminal.get_visual_resource_allocation_audit(),
		"access_counts": _presentation_counts(access),
		"terminal_counts": _presentation_counts(terminal),
	}.duplicate(true)


func _screen_energy(terminal: CargoTransferTerminal) -> float:
	var screen := terminal.get_node(^"StatusScreen") as MeshInstance3D
	return (screen.material_override as StandardMaterial3D).emission_energy_multiplier


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
