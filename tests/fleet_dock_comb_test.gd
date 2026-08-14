extends SceneTree

const MODULE_SCENE := preload("res://scenes/world/modules/fleet_dock_comb.tscn")
const WORLD_LAYER := PhysicsLayers.WORLD

var _failures: Array[String] = []
var _test_root: Node3D


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_root = Node3D.new()
	_test_root.name = "FleetDockCombTestRoot"
	root.add_child(_test_root)
	var module := MODULE_SCENE.instantiate() as FleetDockComb
	_check(module != null, "fleet dock comb scene instantiates with its typed root")
	if module == null:
		_finish()
		return
	module.position = Vector3(31.0, 6.0, -47.0)
	module.rotation_degrees.y = 23.0
	_test_root.add_child(module)
	await process_frame
	await physics_frame
	await physics_frame

	_test_evidence_roster_and_audit(module)
	_test_footprint_routes_and_authority(module)
	await _test_collision_backed_comb_and_voids(module)
	_test_performance_contract(module)
	await _test_reversible_lifecycle(module)
	await _test_cleanup(module)
	_finish()


func _test_evidence_roster_and_audit(module: FleetDockComb) -> void:
	_check(module.get_module_id() == &"fleet-dock-comb", "module publishes its stable fleet-dock-comb identity")
	_check(bool(module.get_meta("station_module", false)) and module.is_in_group("station_modules"), "root participates in station-module discovery")
	_check(str(module.get_meta("evidence_status", "")) == "modern_interpretation", "root rejects an authenticated-original geometry claim")
	var evidence := module.get_evidence_metadata()
	var claim_ids := evidence.claim_ids as PackedStringArray
	_check(claim_ids == PackedStringArray(["OE-B2-COMB", "OE-B2-SLABS", "OE-B2-BERTHS"]), "evidence API names the exact three B2 topology claims")
	_check(not bool(evidence.authenticated_original_geometry) and "not recovered original geometry" in str(evidence.content_note), "evidence boundary states that exact geometry is modern")

	var roster := module.get_component_roster()
	_check(int(roster.walkable_surface_count) == 7, "roster exposes exactly seven collision-backed walkable surfaces")
	_check(int(roster.rung_count) == 3 and int(roster.dock_slab_count) == 3, "roster contains exactly three rungs and three broad end slabs")
	_check(int(roster.vertical_transition_count) == 1, "roster contains exactly one short vertical transition")
	_check(int(roster.deferred_dock_count) == 3, "roster contains exactly three deferred empty docks")
	_check(roster.surface_ids == roster.expected_surface_ids, "actual surface identities exactly match the public roster")
	var audit := module.get_audit_report()
	_check(bool(audit.valid) and (audit.errors as PackedStringArray).is_empty(), "fresh module passes its complete public audit")
	(audit.roster as Dictionary)["walkable_surface_count"] = -1
	_check(int(module.get_audit_report().roster.walkable_surface_count) == 7, "audit snapshots are deeply detached from live module state")


func _test_footprint_routes_and_authority(module: FleetDockComb) -> void:
	var footprint := module.get_integration_footprint()
	_check((footprint.local_min as Vector3).is_equal_approx(Vector3(-2.6, -2.5, 0.0)), "declared footprint begins at the compact root connection plane")
	_check((footprint.local_max as Vector3).is_equal_approx(Vector3(21.0, 5.0, 48.0)), "declared footprint contains the complete starboard-biased comb")
	_check(bool(footprint.starboard_biased) and (footprint.comb_teeth_axis_local as Vector3) == Vector3.RIGHT, "integration contract keeps every tooth on local +X")
	_check(module.get_module_anchor().global_transform.is_equal_approx(module.global_transform), "module anchor is the exact root connection transform")
	_check(module.get_route_ids().size() == 9, "nine explicit approach, trunk, threshold, and vertical route markers are registered")
	for route_id in [&"approach", &"trunk-forward", &"dock-01-threshold", &"trunk-mid", &"dock-02-threshold", &"trunk-aft", &"vertical-base", &"vertical-top", &"dock-03-threshold"]:
		_check(module.has_route_marker(route_id) and module.get_route_marker(route_id) != null, "route marker resolves: %s" % route_id)

	var docks := module.get_deferred_dock_roster()
	_check(docks.size() == 3, "three dock landmarks are exposed without creating a berth specification")
	var every_dock_deferred := true
	for dock in docks:
		every_dock_deferred = every_dock_deferred \
			and dock.status == &"deferred_empty" \
			and dock.ship_assignment == &"none" \
			and not bool(dock.owns_berth_authority) \
			and not bool(dock.landing_volume_present) \
			and not bool(dock.boarding_area_present)
	_check(every_dock_deferred, "every dock remains empty, deferred, unassigned, and non-authoritative")
	var authority := module.get_authority_contract()
	_check(int(authority.ship_berth_count) == 0 and int(authority.landing_or_interaction_area_count) == 0, "module owns no ShipBerth, landing, boarding, or interaction area")
	_check(int(authority.audio_node_count) == 0 and int(authority.activity_node_count) == 0, "module owns no audio or station-activity component")
	_check(int(authority.lease_authority_count) == 0 and int(authority.spawn_authority_count) == 0, "module owns no lease or spawning authority")


func _test_collision_backed_comb_and_voids(module: FleetDockComb) -> void:
	var surface_samples := [
		[Vector3(0, 2.0, 4.0), 0.0, "narrow trunk"],
		[Vector3(6.0, 2.0, 10.0), 0.0, "first orthogonal rung"],
		[Vector3(15.0, 2.0, 10.0), 0.0, "first broad slab"],
		[Vector3(6.0, 2.0, 25.0), 0.0, "second orthogonal rung"],
		[Vector3(15.0, 2.0, 25.0), 0.0, "second broad slab"],
		[Vector3(5.5, 4.0, 40.0), 1.2, "third rising rung"],
		[Vector3(15.0, 5.0, 40.0), 2.4, "upper broad slab"],
	]
	for sample in surface_samples:
		var local_point := sample[0] as Vector3
		var hit := await _ray_local(module, local_point, Vector3(local_point.x, -4.0, local_point.z))
		_check(not hit.is_empty(), "%s has real World collision" % str(sample[2]))
		if not hit.is_empty():
			var local_hit := module.to_local(hit.position)
			_check(absf(local_hit.y - float(sample[1])) < 0.08, "%s collision matches its declared elevation" % str(sample[2]))

	var every_void_empty := true
	for local_void in module.get_negative_space_samples():
		var void_hit := await _ray_local(module, local_void + Vector3.UP * 5.0, local_void + Vector3.DOWN * 5.0)
		every_void_empty = every_void_empty and void_hit.is_empty()
	_check(every_void_empty, "all five published footprint samples remain genuine physics voids")
	var collision := module.get_collision_contract()
	_check(int(collision.body_count) == 7 and int(collision.shape_count) == 7, "collision roster is exactly one body and shape per walkable surface")
	_check(bool(collision.all_layers_match_lifecycle) and bool(collision.all_masks_zero), "all collision uses the canonical World layer with zero static mask")
	_check(not bool(collision.full_footprint_floor_present), "collision audit proves no hidden full-footprint floor exists")


func _test_performance_contract(module: FleetDockComb) -> void:
	var performance := module.get_performance_contract()
	_check(bool(performance.within_budget), "module stays within every fixed geometry and processing budget")
	_check(int(performance.static_bodies) == 7 and int(performance.collision_shapes) == 7, "performance report agrees with the exact collision roster")
	_check(int(performance.labels) == 3 and int(performance.lights) == 0, "presentation contains exactly three labels and no light nodes")
	_check(int(performance.process_loops) == 0, "static module allocates no frame or physics process loop")


func _test_reversible_lifecycle(module: FleetDockComb) -> void:
	var initial := module.get_lifecycle_contract()
	var initial_ids := initial.surface_instance_ids as PackedInt64Array
	_check(bool(initial.enabled) and bool(initial.visible_matches_enabled) and bool(initial.collision_matches_enabled), "fresh lifecycle is visibly and physically enabled")
	module.set_module_enabled(false)
	await physics_frame
	var disabled := module.get_lifecycle_contract()
	_check(not bool(disabled.enabled) and bool(disabled.visible_matches_enabled) and bool(disabled.collision_matches_enabled), "disabled lifecycle hides geometry and clears collision atomically")
	_check(int(module.get_collision_contract().active_body_count) == 0 and bool(module.get_audit_report().valid), "intentional disabled state remains valid with no active bodies")
	var disabled_hit := await _ray_local(module, Vector3(0, 2, 4), Vector3(0, -2, 4))
	_check(disabled_hit.is_empty(), "disabled lifecycle removes the trunk from World collision")

	module.set_module_enabled(true)
	await physics_frame
	var restored := module.get_lifecycle_contract()
	_check(bool(restored.enabled) and restored.surface_instance_ids == initial_ids, "re-enable restores the exact original surfaces without rebuilding")
	_check(int(restored.build_generation) == 1 and not bool(restored.runtime_rebuild_allowed), "lifecycle remains a single-build identity-preserving component")
	var restored_hit := await _ray_local(module, Vector3(0, 2, 4), Vector3(0, -2, 4))
	_check(not restored_hit.is_empty(), "re-enabled lifecycle restores physical trunk collision")

	_test_root.remove_child(module)
	await process_frame
	_test_root.add_child(module)
	await process_frame
	await physics_frame
	_check(module.get_lifecycle_contract().surface_instance_ids == initial_ids and bool(module.get_audit_report().valid), "detach and re-add preserves identities and a valid lifecycle")


func _test_cleanup(module: FleetDockComb) -> void:
	var module_reference: WeakRef = weakref(module)
	var surface_reference: WeakRef = weakref(module.find_child("Trunk", true, false))
	module.queue_free()
	module = null
	await process_frame
	await physics_frame
	await process_frame
	_check(module_reference.get_ref() == null and surface_reference.get_ref() == null, "module and generated surfaces release cleanly without retained lifecycle state")
	_test_root.queue_free()
	await process_frame


func _ray_local(module: FleetDockComb, local_from: Vector3, local_to: Vector3) -> Dictionary:
	await physics_frame
	var query := PhysicsRayQueryParameters3D.create(module.to_global(local_from), module.to_global(local_to), WORLD_LAYER)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return module.get_world_3d().direct_space_state.intersect_ray(query)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("FLEET_DOCK_COMB_TEST_OK")
		quit(0)
	else:
		print("FLEET_DOCK_COMB_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
