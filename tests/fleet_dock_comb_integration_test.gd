extends SceneTree

const WORLD_SCENE := preload("res://scenes/world/shipyard_world.tscn")
const EXPECTED_BERTH_IDS: Array[StringName] = [
	&"arrow_recon_berth",
	&"central_berth",
	&"halyard_fleet_dock_berth",
	&"bulwark_fleet_dock_berth",
	&"jovian_freight_berth",
	&"zenith_fleet_dock_berth",
]

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := WORLD_SCENE.instantiate() as ShipyardWorld
	_check(world != null, "production ShipyardWorld instantiates with the fleet dock comb")
	if world == null:
		_finish()
		return
	root.add_child(world)
	await process_frame
	await physics_frame
	await physics_frame

	var module := world.get_fleet_dock_comb()
	_check(module != null and module == world.get_node_or_null(^"FleetDockComb"), "world accessor resolves the exact production comb instance")
	if module == null:
		world.queue_free()
		await process_frame
		_finish()
		return

	_test_integration_audit(world, module)
	await _test_continuous_physical_route(world, module)
	await _test_integrated_negative_space(world, module)
	_test_landing_and_berth_authority_unchanged(world, module)
	await _test_fail_red_and_reentry(world, module)

	world.queue_free()
	await process_frame
	await physics_frame
	await process_frame
	_finish()


func _test_integration_audit(world: ShipyardWorld, module: FleetDockComb) -> void:
	var report := world.get_fleet_dock_comb_integration_audit_report()
	_check(int(report.schema_version) == 3 and bool(report.valid), "production comb placement, assignment and connector pass the delegated v3 integration audit")
	_check((report.errors as PackedStringArray).is_empty(), "valid integration reports no hidden placement or authority errors")
	_check(str(report.evidence_status) == "modern_interpretation" and str(report.source_claim) == "OE-B2-COMB", "world keeps the exact placement modern while naming the bounded B2 claim")
	_check(
		int(report.external_assignment_count) == 3
		and int(report.deferred_empty_dock_count) == 0
		and not bool(report.historical_class_to_berth_mapping)
		and bool(report.placement_authored),
		"integration separates three modern external assignments from no deferred dock"
	)
	_check(bool((report.component as Dictionary).valid), "world delegates to the complete live component audit")
	var expected_transform := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(12.0, 4.2, 68.3))
	_check(module.transform.is_equal_approx(expected_transform), "starboard-biased module uses the exact audited Aft-upper placement")
	_check((report.module_transform as Transform3D).is_equal_approx(module.global_transform), "integration report exposes the live composed module transform")
	var returned_component := report.component as Dictionary
	returned_component["valid"] = false
	_check(bool((world.get_fleet_dock_comb_integration_audit_report().component as Dictionary).valid), "integration report is deeply detached from callers")

	var connector := world.get_node_or_null(^"ExposedDockLattice/FleetDockCombConnector") as Node3D
	_check(connector != null and str(connector.get_meta("connects_station_module", "")) == "fleet-dock-comb", "one visible semantic connector joins the Aft deck to the comb")
	if connector != null:
		var connector_bodies := connector.find_children("*", "StaticBody3D", true, false)
		var connector_meshes := connector.find_children("*", "MeshInstance3D", true, false)
		_check(connector_bodies.size() == 3 and connector_meshes.size() == 3, "connector has one visible collision-backed deck and exactly two visible rails")


func _test_continuous_physical_route(world: ShipyardWorld, module: FleetDockComb) -> void:
	# Aft upper floor -> explicit bridge -> module approach/trunk. Every sample is
	# intentionally on the narrow route; no broad hidden catch floor is accepted.
	var route_samples := PackedVector3Array([
		Vector3(-0.15, 4.2, 68.3),
		Vector3(0.1, 4.2, 68.3),
		Vector3(3.0, 4.2, 68.3),
		Vector3(6.0, 4.2, 68.3),
		Vector3(9.0, 4.2, 68.3),
		Vector3(11.8, 4.2, 68.3),
		module.to_global(Vector3(0.0, 0.0, 0.35)),
		module.to_global(Vector3(0.0, 0.0, 4.0)),
	])
	var route_supported := true
	var surface_error := 0.0
	for sample in route_samples:
		var hit := await _ray(world, sample + Vector3.UP * 2.5, sample + Vector3.DOWN * 2.5)
		if hit.is_empty():
			route_supported = false
		else:
			surface_error = maxf(surface_error, absf((hit.position as Vector3).y - 4.2))
	_check(route_supported, "Aft upper floor, visible connector and comb trunk form one continuous World-collision route")
	_check(surface_error <= 0.02, "the complete integration route is flush at the 4.2 metre upper elevation")
	# Zenith's authored ExitPoint is local (-7.85,-0.55,0.85) at the exact
	# world berth transform. Its horizontal projection must be supported rather
	# than depositing the disembarking player into the void beside dock 01.
	var zenith_exit_projection := Vector3(14.15, 4.2, 54.15)
	var exit_support := await _ray(
		world,
		zenith_exit_projection + Vector3.UP * 2.5,
		zenith_exit_projection + Vector3.DOWN * 2.5
	)
	_check(
		not exit_support.is_empty()
		and absf((exit_support.position as Vector3).y - 4.2) <= 0.02,
		"dock 01 physically supports the exact Zenith disembark projection"
	)

	var route_transforms := module.get_route_transforms()
	_check(route_transforms.size() == 9, "all nine component route markers survive the production transform")
	_check((route_transforms[&"approach"] as Transform3D).origin.x > 12.5, "local +Z becomes a starboard outbound production route")
	_check((route_transforms[&"vertical-top"] as Transform3D).origin.y > 6.6, "the sole short ramp preserves its distinct upper landing after integration")


func _test_integrated_negative_space(world: ShipyardWorld, module: FleetDockComb) -> void:
	var every_void_empty := true
	for local_void in module.get_negative_space_samples():
		var world_void := module.to_global(local_void)
		var hit := await _ray(world, world_void + Vector3.UP * 6.0, world_void + Vector3.DOWN * 6.0)
		every_void_empty = every_void_empty and hit.is_empty()
	_check(every_void_empty, "all five published comb gaps remain genuine space in the full production world")
	_check(not bool(module.get_bounds_contract().full_footprint_floor_present), "integrated module still exposes no hidden full-footprint collision floor")


func _test_landing_and_berth_authority_unchanged(world: ShipyardWorld, module: FleetDockComb) -> void:
	var live_berth_ids := world.get_berth_ids()
	var exact_berth_roster := live_berth_ids.size() == EXPECTED_BERTH_IDS.size()
	for berth_id in EXPECTED_BERTH_IDS:
		exact_berth_roster = exact_berth_roster and live_berth_ids.has(berth_id)
	_check(exact_berth_roster, "production berth registry contains the exact six assigned physical berths")
	var expected_transforms := {
		&"central_berth": Transform3D(Basis.IDENTITY, Vector3(0.0, 1.15, -10.0)),
		&"arrow_recon_berth": Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-43.0, 1.15, 15.5)),
		&"jovian_freight_berth": Transform3D(Basis(Vector3.UP, PI), Vector3(-53.0, 1.63, 57.3)),
		&"zenith_fleet_dock_berth": Transform3D(Basis.IDENTITY, Vector3(22.0, 5.28, 53.3)),
		&"halyard_fleet_dock_berth": Transform3D(Basis.IDENTITY, Vector3(37.0, 5.28, 53.3)),
		&"bulwark_fleet_dock_berth": Transform3D(Basis.IDENTITY, Vector3(52.0, 5.28, 53.3)),
	}
	var all_transforms_exact := true
	var all_live := true
	for berth_id in EXPECTED_BERTH_IDS:
		all_live = all_live and world.get_berth_node(berth_id) != null
		all_transforms_exact = all_transforms_exact and world.get_berth_transform(berth_id).is_equal_approx(expected_transforms[berth_id] as Transform3D)
	_check(all_live and all_transforms_exact, "all six authoritative berth identities and transforms remain exact")

	var authority := module.get_authority_contract()
	_check(int(authority.ship_berth_count) == 0 and int(authority.landing_or_interaction_area_count) == 0, "deferred comb markers add no landing, boarding or interaction authority")
	_check(
		module.get_assigned_dock_roster().size() == 3
		and module.get_deferred_dock_roster().is_empty(),
		"three assigned dock landmarks remain independently visible and non-authoritative"
	)
	var assigned := _find_assigned_dock(module.get_assigned_dock_roster(), &"assigned-dock-01")
	var zenith_berth := world.get_berth_node(&"zenith_fleet_dock_berth")
	_check(
		zenith_berth != null
		and zenith_berth.global_transform.origin.is_equal_approx(
			(assigned.marker_transform as Transform3D).origin + Vector3.UP * 0.93
		),
		"world-owned Zenith berth aligns exactly above comb dock 01"
	)

	var module_aabb := module.get_bounds_contract().world_aabb as AABB
	var legacy_capture_overlap := false
	for berth_id in [&"central_berth", &"arrow_recon_berth", &"jovian_freight_berth"]:
		var berth := world.get_berth_node(berth_id)
		var capture_transform := berth.global_transform * Transform3D(Basis.IDENTITY, berth.get_assist_capture_center())
		var capture_aabb := _oriented_box_aabb(capture_transform, berth.get_assist_capture_half_extents())
		legacy_capture_overlap = legacy_capture_overlap or module_aabb.intersects(capture_aabb)
	_check(not legacy_capture_overlap, "comb footprint stays outside every pre-existing landing-assist capture volume")
	var zenith_capture := _oriented_box_aabb(
		zenith_berth.get_assist_capture_transform(),
		zenith_berth.get_assist_capture_half_extents()
	)
	_check(module_aabb.intersects(zenith_capture), "Zenith assist capture intentionally approaches its assigned fleet-dock slab")


func _test_fail_red_and_reentry(world: ShipyardWorld, module: FleetDockComb) -> void:
	var original_transform := module.transform
	module.position += Vector3(0.5, 0.0, 0.0)
	_check(not bool(world.get_fleet_dock_comb_integration_audit_report().valid), "integration audit rejects direct module placement drift")
	module.transform = original_transform
	_check(bool(world.get_fleet_dock_comb_integration_audit_report().valid), "restoring exact placement restores the integration audit")

	var rogue_berth := ShipBerth.new()
	rogue_berth.name = "ForbiddenDeferredDockAuthority"
	module.add_child(rogue_berth)
	await process_frame
	_check(not bool(world.get_fleet_dock_comb_integration_audit_report().valid), "integration fails red if an empty landmark gains ShipBerth authority")
	module.remove_child(rogue_berth)
	rogue_berth.free()
	_check(bool(world.get_fleet_dock_comb_integration_audit_report().valid), "removing forbidden authority restores the exact assigned-landmark contract")

	var module_id := module.get_instance_id()
	var connector := world.get_node(^"ExposedDockLattice/FleetDockCombConnector")
	var connector_id := connector.get_instance_id()
	var berth_ids := PackedInt64Array()
	for berth_id in EXPECTED_BERTH_IDS:
		berth_ids.append(world.get_berth_node(berth_id).get_instance_id())
	root.remove_child(world)
	await process_frame
	root.add_child(world)
	await process_frame
	await physics_frame
	_check(world.get_fleet_dock_comb().get_instance_id() == module_id and world.get_node(^"ExposedDockLattice/FleetDockCombConnector").get_instance_id() == connector_id, "whole-world detach/re-entry preserves comb and connector identities")
	var berth_ids_after := PackedInt64Array()
	for berth_id in EXPECTED_BERTH_IDS:
		berth_ids_after.append(world.get_berth_node(berth_id).get_instance_id())
	_check(berth_ids_after == berth_ids, "comb lifecycle cannot rebuild or replace any berth authority")
	_check(bool(world.get_fleet_dock_comb_integration_audit_report().valid), "integration audit remains green after whole-world re-entry")


## More than one dock is assigned now, so rows are selected by their stable dock
## id instead of by roster position.
func _find_assigned_dock(assigned: Array[Dictionary], dock_id: StringName) -> Dictionary:
	for entry in assigned:
		if entry.get("dock_id", &"") == dock_id:
			return entry
	return {}


func _oriented_box_aabb(box_transform: Transform3D, half_extents: Vector3) -> AABB:
	var first := true
	var result := AABB()
	for x_sign in [-1.0, 1.0]:
		for y_sign in [-1.0, 1.0]:
			for z_sign in [-1.0, 1.0]:
				var corner := box_transform * Vector3(
					half_extents.x * x_sign,
					half_extents.y * y_sign,
					half_extents.z * z_sign
				)
				if first:
					result = AABB(corner, Vector3.ZERO)
					first = false
				else:
					result = result.expand(corner)
	return result


func _ray(world: Node3D, from: Vector3, to: Vector3) -> Dictionary:
	await physics_frame
	var query := PhysicsRayQueryParameters3D.create(from, to, PhysicsLayers.WORLD)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return world.get_world_3d().direct_space_state.intersect_ray(query)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("FLEET_DOCK_COMB_INTEGRATION_TEST_OK")
		quit(0)
	else:
		print("FLEET_DOCK_COMB_INTEGRATION_TEST_FAILED: ", "; ".join(_failures))
		quit(1)
