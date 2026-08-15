extends SceneTree

## Integration audit for the station route registry the production world owns.
##
## The graph is declarative and non-metric: a module tags exactly one route
## marker with `station_connection_slot`, `ShipyardWorld` publishes the matching
## hub endpoint over real lattice geometry, and a slot claimed by exactly two
## endpoints is an edge. This suite drives the real `res://scenes/main.tscn` and
## proves the production station is one connected structure rather than four
## isolated islands, that the registry assigns no gameplay authority, and that
## the audit still turns red when a module stops declaring its slot.

const MAIN_SCENE := preload("res://scenes/main.tscn")

const HUB_ENDPOINT_ID: StringName = &"station-hub"
const CONNECTION_SLOT_META: StringName = &"station_connection_slot"
const APPROACH_ROUTE_ID: StringName = &"approach"

const EXPECTED_MODULE_COUNT := 4
const EXPECTED_HUB_ENDPOINT_COUNT := 4
const EXPECTED_CONNECTION_SLOT_COUNT := 4
const EXPECTED_ROUTE_MARKER_COUNT := 29

const EXPECTED_MODULE_IDS: Array[StringName] = [
	&"aft-junction-stack",
	&"fleet-dock-comb",
	&"habitat-spine",
	&"jovian-freight-berth",
]

## slot id -> the single module that must claim it opposite the station hub.
const EXPECTED_EDGES := {
	&"hub-aft-junction": &"aft-junction-stack",
	&"hub-fleet-dock-comb": &"fleet-dock-comb",
	&"hub-registry-pod-freight": &"jovian-freight-berth",
	&"hub-starboard-habitat": &"habitat-spine",
}

## Deliberate dead ends that must never be promoted into connection slots.
const EXPECTED_DEAD_END_ROUTES := {
	&"aft-junction-stack": [&"vip-landmark"],
	&"habitat-spine": [&"deferred-branch"],
	&"fleet-dock-comb": [&"dock-01-threshold", &"dock-02-threshold", &"dock-03-threshold"],
}

const EXPECTED_BERTH_IDS: Array[StringName] = [
	&"arrow_recon_berth",
	&"central_berth",
	&"jovian_freight_berth",
	&"zenith_fleet_dock_berth",
]
const EXPECTED_BERTH_TRANSFORMS := {
	&"central_berth": Transform3D(Basis.IDENTITY, Vector3(0.0, 1.15, -10.0)),
	&"arrow_recon_berth": Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-43.0, 1.15, 15.5)),
	&"jovian_freight_berth": Transform3D(Basis(Vector3.UP, PI), Vector3(-53.0, 1.63, 57.3)),
	&"zenith_fleet_dock_berth": Transform3D(Basis.IDENTITY, Vector3(22.0, 5.28, 53.3)),
}

## The only berth specification a station module publishes. Every other berth
## identity stays entirely world-owned and must never appear as a module claim.
const EXPECTED_AUTHORITY_CLAIMS := {
	&"jovian_freight_berth": &"jovian-freight-berth",
}

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "production main scene instantiates for the station route registry audit")
	if game == null:
		_finish()
		return
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame

	var world := game.get_node_or_null("ShipyardWorld") as ShipyardWorld
	_check(world != null, "main scene owns the production ShipyardWorld that publishes the route registry")
	if world == null:
		await _cleanup(game)
		_finish()
		return

	_test_production_graph_is_valid(world)
	_test_exact_module_roster(world)
	_test_every_module_reaches_the_hub(world)
	_test_hub_endpoints_resolve_to_world_geometry(world)
	_test_only_approach_markers_are_connection_slots(world)
	_test_no_gameplay_authority_leak(world)
	await _test_detach_and_reentry_identity(game, world)
	_test_report_is_deeply_detached(world)
	_test_structured_red_on_undeclared_slot(world)

	await _cleanup(game)
	_finish()


# 1. The production graph is valid, and any failure prints every error.
func _test_production_graph_is_valid(world: ShipyardWorld) -> void:
	var report := world.get_station_route_registry_report()
	_check(not report.is_empty(), "world publishes a station route registry report")
	var errors := report.get("errors", PackedStringArray()) as PackedStringArray
	if not errors.is_empty():
		for error in errors:
			print("STATION_ROUTE_REGISTRY_ERROR: ", error)
	_check(errors.is_empty(), "production station route registry reports no errors")
	_check(bool(report.get("valid", false)), "production station route graph is valid")
	_check(int(report.get("schema_version", 0)) == StationRouteRegistry.SCHEMA_VERSION, "report carries the current registry schema version")
	_check(
		(report.get("warnings", PackedStringArray()) as PackedStringArray).is_empty(),
		"valid production graph hides nothing behind warnings"
	)


# 2. The roster is exactly the four production modules, with exact counts.
func _test_exact_module_roster(world: ShipyardWorld) -> void:
	var report := world.get_station_route_registry_report()
	_check(int(report.get("module_count", -1)) == EXPECTED_MODULE_COUNT, "registry records exactly four station modules")
	_check(int(report.get("hub_endpoint_count", -1)) == EXPECTED_HUB_ENDPOINT_COUNT, "world publishes exactly four station hub endpoints")
	_check(int(report.get("connection_slot_count", -1)) == EXPECTED_CONNECTION_SLOT_COUNT, "exactly four connection slot ids exist across the station")
	_check(int(report.get("route_marker_count", -1)) == EXPECTED_ROUTE_MARKER_COUNT, "registry accounts for all twenty-nine production route markers")

	var modules := report.get("modules", {}) as Dictionary
	var roster_is_exact := modules.size() == EXPECTED_MODULE_IDS.size()
	for module_id in EXPECTED_MODULE_IDS:
		roster_is_exact = roster_is_exact and modules.has(module_id)
	_check(roster_is_exact, "module id set is exactly the four production station modules")
	_check(not modules.has(HUB_ENDPOINT_ID), "no module registers under the reserved station hub id")

	var every_module_declares_one_slot := true
	var every_contract_valid := true
	for module_id in EXPECTED_MODULE_IDS:
		var entry := modules.get(module_id, {}) as Dictionary
		var slots := entry.get("connection_slots", {}) as Dictionary
		every_module_declares_one_slot = every_module_declares_one_slot \
			and slots.size() == 1 \
			and slots.has(EXPECTED_EDGES.keys()[EXPECTED_EDGES.values().find(module_id)] as StringName)
		every_contract_valid = every_contract_valid \
			and bool(entry.get("has_contract", false)) \
			and (entry.get("contract_errors", PackedStringArray()) as PackedStringArray).is_empty()
	_check(every_module_declares_one_slot, "each module declares exactly one connection slot, and it is the slot the hub publishes for it")
	_check(every_contract_valid, "every registered module passes its station module contract inside the registry")


# 3. Every module is reachable from the station hub: four edges, no orphans.
func _test_every_module_reaches_the_hub(world: ShipyardWorld) -> void:
	var report := world.get_station_route_registry_report()
	var adjacency := report.get("adjacency", {}) as Dictionary
	_check(
		adjacency == world.get_station_route_adjacency_graph(),
		"the adjacency accessor returns the same graph the full report carries"
	)

	var edges := adjacency.get("edges", []) as Array
	_check(edges.size() == EXPECTED_EDGES.size(), "the station graph has exactly four edges")
	_check(int(adjacency.get("connected_slots", -1)) == EXPECTED_EDGES.size(), "every connection slot is a connected edge")
	_check(int(adjacency.get("total_slots", -1)) == EXPECTED_CONNECTION_SLOT_COUNT, "the graph spans exactly the four declared slots")
	_check(int(adjacency.get("dangling_slot_count", -1)) == 0, "no station connection slot is dangling")
	_check(int(adjacency.get("overclaimed_slot_count", -1)) == 0, "no station connection slot is claimed by more than two endpoints")
	_check(
		(adjacency.get("dangling_slots", PackedStringArray()) as PackedStringArray).is_empty()
		and (adjacency.get("overclaimed_slots", PackedStringArray()) as PackedStringArray).is_empty(),
		"the dangling and overclaimed slot rosters are both empty"
	)

	var observed := _edge_module_by_slot(adjacency)
	_check(observed == EXPECTED_EDGES, "every edge joins the station hub to exactly one distinct expected module")

	var module_edge_counts := {}
	for slot_id: StringName in observed.keys():
		var module_id := observed[slot_id] as StringName
		module_edge_counts[module_id] = int(module_edge_counts.get(module_id, 0)) + 1
	var every_module_reachable_once := module_edge_counts.size() == EXPECTED_MODULE_IDS.size()
	for module_id in EXPECTED_MODULE_IDS:
		every_module_reachable_once = every_module_reachable_once and int(module_edge_counts.get(module_id, 0)) == 1
	_check(every_module_reachable_once, "all four modules are reachable from the hub, each through exactly one edge")

	var slot_reports := adjacency.get("slots", {}) as Dictionary
	var every_slot_paired := slot_reports.size() == EXPECTED_CONNECTION_SLOT_COUNT
	for slot_id: StringName in EXPECTED_EDGES.keys():
		var slot_report := slot_reports.get(slot_id, {}) as Dictionary
		every_slot_paired = every_slot_paired \
			and int(slot_report.get("claim_count", -1)) == 2 \
			and not bool(slot_report.get("dangling", true)) \
			and not bool(slot_report.get("overclaimed", true)) \
			and (slot_report.get("claimant_modules", PackedStringArray()) as PackedStringArray).size() == 2
	_check(every_slot_paired, "each slot record shows exactly two claimants and neither a dangling nor an overclaimed flag")


# 4. Each hub endpoint resolves to live world geometry and names the right module.
func _test_hub_endpoints_resolve_to_world_geometry(world: ShipyardWorld) -> void:
	var report := world.get_station_route_registry_report()
	var hub_endpoints := report.get("hub_endpoints", {}) as Dictionary
	var declarations := ShipyardWorld.STATION_HUB_ENDPOINT_DECLARATIONS
	_check(declarations.size() == EXPECTED_HUB_ENDPOINT_COUNT, "the world declares exactly four station hub endpoints")
	_check(hub_endpoints.size() == declarations.size(), "every declared hub endpoint is registered")

	var edge_modules := _edge_module_by_slot(report.get("adjacency", {}) as Dictionary)
	var every_anchor_live := true
	var every_transform_exact := true
	var every_expectation_matches := true
	var every_status_recorded := true
	for declaration in declarations:
		var slot_id := declaration.get("slot_id", &"") as StringName
		var endpoint := hub_endpoints.get(slot_id, {}) as Dictionary
		var anchor := world.get_node_or_null(NodePath(str(declaration.get("anchor_path", "")))) as Node3D
		var recorded_anchor := root.get_node_or_null(NodePath(str(endpoint.get("anchor_path", "")))) as Node3D
		if anchor == null or recorded_anchor == null or recorded_anchor != anchor or not world.is_ancestor_of(anchor):
			every_anchor_live = false
		else:
			var recorded_transform := endpoint.get("anchor_transform", Transform3D()) as Transform3D
			every_transform_exact = every_transform_exact \
				and _is_finite_transform(recorded_transform) \
				and recorded_transform.is_equal_approx(anchor.global_transform)
		var expects_module := endpoint.get("expects_module", &"") as StringName
		every_expectation_matches = every_expectation_matches \
			and expects_module == declaration.get("expects_module", &"") \
			and expects_module == edge_modules.get(slot_id, &"")
		every_status_recorded = every_status_recorded \
			and str(endpoint.get("evidence_status", "")) == "modern_interpretation"
	_check(every_anchor_live, "every hub endpoint anchor path resolves to a live Node3D under the production ShipyardWorld")
	_check(every_transform_exact, "every recorded hub anchor transform is finite and matches the live world geometry")
	_check(every_expectation_matches, "each hub endpoint expects exactly the module that claims its slot")
	_check(every_status_recorded, "each hub endpoint records its modern-interpretation evidence status")


# 5. Only the outward approach marker of each module is a connection slot.
func _test_only_approach_markers_are_connection_slots(world: ShipyardWorld) -> void:
	var modules := _module_nodes(world)
	_check(modules.size() == EXPECTED_MODULE_COUNT, "all four production module nodes are reachable for marker inspection")

	var every_module_tags_only_approach := true
	var total_route_markers := 0
	for module in modules:
		var tagged_routes: Array[StringName] = []
		for route_id in module.get_route_ids():
			total_route_markers += 1
			var marker := module.get_route_marker(route_id) as Node3D
			if marker == null:
				every_module_tags_only_approach = false
				continue
			if marker.has_meta(CONNECTION_SLOT_META):
				tagged_routes.append(route_id)
		every_module_tags_only_approach = every_module_tags_only_approach \
			and tagged_routes.size() == 1 \
			and tagged_routes[0] == APPROACH_ROUTE_ID
	_check(every_module_tags_only_approach, "each module tags exactly one route marker as a connection slot, and it is the approach face")
	_check(total_route_markers == EXPECTED_ROUTE_MARKER_COUNT, "the live modules expose exactly twenty-nine route markers")

	var every_dead_end_untagged := true
	var dead_end_count := 0
	for module in modules:
		var module_id := module.get_module_id() as StringName
		for route_id in (EXPECTED_DEAD_END_ROUTES.get(module_id, []) as Array):
			var marker := module.get_route_marker(route_id as StringName) as Node3D
			dead_end_count += 1
			if marker == null or marker.has_meta(CONNECTION_SLOT_META):
				every_dead_end_untagged = false
	_check(dead_end_count == 5, "all five deliberate dead-end markers are present for inspection")
	_check(
		every_dead_end_untagged,
		"the VIP landmark, the deferred habitat branch and the three comb dock thresholds are never connection slots"
	)

	var slot_ids := (world.get_station_route_registry_report().get("slots", {}) as Dictionary).keys()
	var dead_ends_absent_from_graph := true
	for module_id: StringName in EXPECTED_DEAD_END_ROUTES.keys():
		for route_id in (EXPECTED_DEAD_END_ROUTES[module_id] as Array):
			for slot_id: StringName in slot_ids:
				for claim in ((world.get_station_route_registry_report().get("slots", {}) as Dictionary)[slot_id] as Array):
					var claim_dictionary := claim as Dictionary
					if StringName(claim_dictionary.get("module_id", &"")) == module_id \
						and StringName(claim_dictionary.get("route_id", &"")) == StringName(route_id):
						dead_ends_absent_from_graph = false
	_check(dead_ends_absent_from_graph, "no dead-end route marker ever claims a slot in the station adjacency graph")


# 6. The registry records topology only; it never moves gameplay authority.
func _test_no_gameplay_authority_leak(world: ShipyardWorld) -> void:
	var report := world.get_station_route_registry_report()
	var authority_claims := report.get("authority_claims", {}) as Dictionary
	var claims_are_exact := authority_claims.size() == EXPECTED_AUTHORITY_CLAIMS.size()
	for authority_id: StringName in EXPECTED_AUTHORITY_CLAIMS.keys():
		claims_are_exact = claims_are_exact \
			and StringName(authority_claims.get(authority_id, &"")) == EXPECTED_AUTHORITY_CLAIMS[authority_id]
	_check(claims_are_exact, "only the freight module declares a berth specification, and it claims exactly its own berth id")
	_check(
		not authority_claims.has(&"zenith_fleet_dock_berth")
		and not authority_claims.has(&"central_berth")
		and not authority_claims.has(&"arrow_recon_berth"),
		"no module claims a berth identity the world assigns elsewhere"
	)

	var live_berth_ids := world.get_berth_ids()
	var berth_roster_exact := live_berth_ids.size() == EXPECTED_BERTH_IDS.size()
	var berths_unchanged := true
	for berth_id in EXPECTED_BERTH_IDS:
		berth_roster_exact = berth_roster_exact and live_berth_ids.has(berth_id)
		var berth := world.get_berth_node(berth_id)
		berths_unchanged = berths_unchanged \
			and berth != null \
			and world.get_berth_transform(berth_id).is_equal_approx(EXPECTED_BERTH_TRANSFORMS[berth_id] as Transform3D)
	_check(berth_roster_exact, "the world still owns exactly the four assigned physical berths")
	_check(berths_unchanged, "all four authoritative berth identities and transforms are untouched by the route registry")

	var claimed_berths_stay_world_owned := true
	for authority_id: StringName in authority_claims.keys():
		var berth := world.get_berth_node(authority_id)
		var module := _module_by_id(world, StringName(authority_claims[authority_id]))
		if berth == null or module == null:
			claimed_berths_stay_world_owned = false
			continue
		# A declared claim is bookkeeping only: the real ShipBerth stays a
		# world-owned node, never re-parented under the claiming module.
		if module.is_ancestor_of(berth) or not world.is_ancestor_of(berth):
			claimed_berths_stay_world_owned = false
	_check(claimed_berths_stay_world_owned, "a registry authority claim never takes ownership of the live ShipBerth node")

	var modules := report.get("modules", {}) as Dictionary
	var non_berth_modules_claim_nothing := true
	for module_id: StringName in [&"aft-junction-stack", &"habitat-spine", &"fleet-dock-comb"]:
		var entry := modules.get(module_id, {}) as Dictionary
		non_berth_modules_claim_nothing = non_berth_modules_claim_nothing \
			and (entry.get("authority_ids", PackedStringArray()) as PackedStringArray).is_empty()
	_check(non_berth_modules_claim_nothing, "the aft junction, habitat and comb modules declare no authority ids at all")

	var comb := world.get_fleet_dock_comb()
	var docks_own_no_authority := comb != null and comb.get_dock_roster().size() == 3
	if comb != null:
		for dock in comb.get_dock_roster():
			docks_own_no_authority = docks_own_no_authority \
				and not bool((dock as Dictionary).get("owns_berth_authority", true))
		var comb_authority := comb.get_authority_contract()
		docks_own_no_authority = docks_own_no_authority \
			and int(comb_authority.get("ship_berth_count", -1)) == 0 \
			and int(comb_authority.get("landing_or_interaction_area_count", -1)) == 0
	_check(docks_own_no_authority, "all three comb dock markers still report owns_berth_authority false after registration")


# 7. Detach and re-entry rebuilds an identical graph without accumulating errors.
func _test_detach_and_reentry_identity(game: GameFlow, world: ShipyardWorld) -> void:
	var report_before := world.get_station_route_registry_report()
	var modules_before := (report_before.get("modules", {}) as Dictionary).keys()
	modules_before.sort()
	var edges_before := _edge_module_by_slot(report_before.get("adjacency", {}) as Dictionary)
	var world_id := world.get_instance_id()
	var module_instance_ids := PackedInt64Array()
	for module in _module_nodes(world):
		module_instance_ids.append(module.get_instance_id())

	root.remove_child(game)
	await process_frame
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame

	_check(game.get_node("ShipyardWorld").get_instance_id() == world_id, "whole-scene detach and re-entry preserves the ShipyardWorld identity")
	var module_instance_ids_after := PackedInt64Array()
	for module in _module_nodes(world):
		module_instance_ids_after.append(module.get_instance_id())
	_check(module_instance_ids_after == module_instance_ids, "re-entry rebuilds the registry over the same live module instances")

	var report_after := world.get_station_route_registry_report()
	var errors_after := report_after.get("errors", PackedStringArray()) as PackedStringArray
	if not errors_after.is_empty():
		for error in errors_after:
			print("STATION_ROUTE_REGISTRY_REENTRY_ERROR: ", error)
	_check(bool(report_after.get("valid", false)) and errors_after.is_empty(), "the rebuilt station route graph is still valid with no accumulated errors")
	var modules_after := (report_after.get("modules", {}) as Dictionary).keys()
	modules_after.sort()
	_check(modules_after == modules_before, "re-entry reproduces the identical module roster without duplicates")
	_check(
		int(report_after.get("module_count", -1)) == EXPECTED_MODULE_COUNT
		and int(report_after.get("hub_endpoint_count", -1)) == EXPECTED_HUB_ENDPOINT_COUNT
		and int(report_after.get("connection_slot_count", -1)) == EXPECTED_CONNECTION_SLOT_COUNT
		and int(report_after.get("route_marker_count", -1)) == EXPECTED_ROUTE_MARKER_COUNT,
		"re-entry never duplicates modules, hub endpoints, slots or route markers"
	)
	_check(_edge_module_by_slot(report_after.get("adjacency", {}) as Dictionary) == edges_before, "re-entry reproduces the identical four-edge hub roster")
	var adjacency_after := report_after.get("adjacency", {}) as Dictionary
	_check(
		int(adjacency_after.get("dangling_slot_count", -1)) == 0
		and int(adjacency_after.get("overclaimed_slot_count", -1)) == 0,
		"no slot becomes dangling or overclaimed through the rebuild"
	)


# 8. The published report is deeply detached and the getter is pure.
func _test_report_is_deeply_detached(world: ShipyardWorld) -> void:
	var report := world.get_station_route_registry_report()
	var adjacency := report.get("adjacency", {}) as Dictionary
	(adjacency.get("edges", []) as Array).clear()
	(adjacency.get("slots", {}) as Dictionary).clear()
	adjacency["dangling_slot_count"] = 99
	((report.get("slots", {}) as Dictionary)[&"hub-aft-junction"] as Array).clear()
	((report.get("modules", {}) as Dictionary)[&"habitat-spine"] as Dictionary)["connection_slots"] = {}
	(report.get("hub_endpoints", {}) as Dictionary).clear()
	(report.get("authority_claims", {}) as Dictionary).clear()

	var fresh := world.get_station_route_registry_report()
	var fresh_adjacency := fresh.get("adjacency", {}) as Dictionary
	_check(
		(fresh_adjacency.get("edges", []) as Array).size() == EXPECTED_EDGES.size()
		and (fresh_adjacency.get("slots", {}) as Dictionary).size() == EXPECTED_CONNECTION_SLOT_COUNT
		and int(fresh_adjacency.get("dangling_slot_count", -1)) == 0,
		"mutating a returned adjacency graph cannot damage the world's own report"
	)
	_check(
		((fresh.get("slots", {}) as Dictionary)[&"hub-aft-junction"] as Array).size() == 2
		and (((fresh.get("modules", {}) as Dictionary)[&"habitat-spine"] as Dictionary).get("connection_slots", {}) as Dictionary).size() == 1,
		"slot claims and module connection slots survive caller mutation"
	)
	_check(
		(fresh.get("hub_endpoints", {}) as Dictionary).size() == EXPECTED_HUB_ENDPOINT_COUNT
		and (fresh.get("authority_claims", {}) as Dictionary).size() == EXPECTED_AUTHORITY_CLAIMS.size(),
		"hub endpoints and authority claims survive caller mutation"
	)
	_check(
		_edge_module_by_slot(fresh_adjacency) == EXPECTED_EDGES,
		"the production edge roster is unchanged after a caller mutates its copy"
	)
	_check(
		world.get_station_route_adjacency_graph().get("edges", []).size() == EXPECTED_EDGES.size(),
		"the adjacency accessor is detached from the mutated report as well"
	)

	var first_errors := world.get_station_route_registry_report().get("errors", PackedStringArray()) as PackedStringArray
	var second_errors := world.get_station_route_registry_report().get("errors", PackedStringArray()) as PackedStringArray
	_check(
		first_errors.is_empty() and second_errors.is_empty() and first_errors.size() == second_errors.size(),
		"reading the report repeatedly never re-runs validation or grows the error list"
	)


# 9. A module that stops declaring its slot must turn the audit red.
func _test_structured_red_on_undeclared_slot(world: ShipyardWorld) -> void:
	var modules := _module_nodes(world)
	var hub_endpoints := _hub_endpoints(world)
	var probe := StationRouteRegistry.new()
	var baseline := probe.build_registry(modules, hub_endpoints)
	_check(
		bool(baseline.get("valid", false))
		and _edge_module_by_slot(baseline.get("adjacency", {}) as Dictionary) == EXPECTED_EDGES,
		"an independent registry over the same live modules and hub endpoints reproduces the valid production graph"
	)

	var subject := _module_by_id(world, &"aft-junction-stack")
	_check(subject != null, "the aft junction module is available for the structured-red mutation")
	if subject == null:
		return
	var marker := subject.get_route_marker(APPROACH_ROUTE_ID) as Node3D
	_check(marker != null and marker.has_meta(CONNECTION_SLOT_META), "the aft junction approach marker carries the connection slot meta before mutation")
	if marker == null or not marker.has_meta(CONNECTION_SLOT_META):
		return
	var original_slot_id: Variant = marker.get_meta(CONNECTION_SLOT_META)

	marker.remove_meta(CONNECTION_SLOT_META)
	var red := StationRouteRegistry.new().build_registry(modules, hub_endpoints)
	var red_errors := red.get("errors", PackedStringArray()) as PackedStringArray
	var red_adjacency := red.get("adjacency", {}) as Dictionary
	_check(not bool(red.get("valid", true)), "removing one module's connection slot declaration makes the station route audit fail red")
	var names_module := false
	var reports_dangling := false
	for error in red_errors:
		if "aft-junction-stack" in error:
			names_module = true
		if "hub-aft-junction" in error and "dangling" in error:
			reports_dangling = true
	_check(names_module, "the red report names the module that stopped declaring its slot")
	_check(reports_dangling, "the red report reports the hub-aft-junction slot as dangling")
	_check(
		int(red_adjacency.get("dangling_slot_count", -1)) == 1
		and (red_adjacency.get("dangling_slots", PackedStringArray()) as PackedStringArray).has("hub-aft-junction"),
		"exactly the orphaned hub slot is listed as dangling"
	)
	_check((red_adjacency.get("edges", []) as Array).size() == EXPECTED_EDGES.size() - 1, "the mutated station graph keeps only the three intact edges")
	_check(
		int(red.get("module_count", -1)) == EXPECTED_MODULE_COUNT
		and int(red.get("route_marker_count", -1)) == EXPECTED_ROUTE_MARKER_COUNT,
		"the mutation removes a declaration only, leaving the module and marker roster intact"
	)

	marker.set_meta(CONNECTION_SLOT_META, original_slot_id)
	var restored := StationRouteRegistry.new().build_registry(modules, hub_endpoints)
	_check(
		bool(restored.get("valid", false))
		and (restored.get("errors", PackedStringArray()) as PackedStringArray).is_empty(),
		"restoring the declaration returns the independent station graph to valid"
	)
	_check(
		_edge_module_by_slot(restored.get("adjacency", {}) as Dictionary) == EXPECTED_EDGES,
		"the restored graph reconnects all four modules to the station hub"
	)
	_check(
		bool(world.get_station_route_registry_report().get("valid", false)),
		"the world's own published report was never corrupted by the probe registries"
	)


func _edge_module_by_slot(adjacency: Dictionary) -> Dictionary:
	var result := {}
	for edge in (adjacency.get("edges", []) as Array):
		var edge_dictionary := edge as Dictionary
		var slot_id := StringName(edge_dictionary.get("slot_id", &""))
		var hub_claims := 0
		var module_ids: Array[StringName] = []
		for endpoint in (edge_dictionary.get("endpoints", PackedStringArray()) as PackedStringArray):
			var claimant := StringName(str(endpoint).split(":")[0])
			if claimant == HUB_ENDPOINT_ID:
				hub_claims += 1
			elif not module_ids.has(claimant):
				module_ids.append(claimant)
		if hub_claims == 1 and module_ids.size() == 1:
			result[slot_id] = module_ids[0]
		else:
			result[slot_id] = &"<malformed-edge>"
	return result


func _module_nodes(world: ShipyardWorld) -> Array[Node]:
	var result: Array[Node] = []
	for node_name in ["AftJunctionStack", "FleetDockComb", "HabitatSpine", "JovianFreightBerth"]:
		var module := world.get_node_or_null(NodePath(node_name))
		if module != null:
			result.append(module)
	return result


func _module_by_id(world: ShipyardWorld, module_id: StringName) -> Node:
	for module in _module_nodes(world):
		if StringName(module.get_module_id()) == module_id:
			return module
	return null


## Rebuilds the world-side half of the graph from the production declarations so
## a probe registry sees exactly the endpoints `ShipyardWorld` publishes.
func _hub_endpoints(world: ShipyardWorld) -> Array:
	var endpoints: Array = []
	for declaration in ShipyardWorld.STATION_HUB_ENDPOINT_DECLARATIONS:
		endpoints.append({
			"slot_id": declaration.get("slot_id", &""),
			"expects_module": declaration.get("expects_module", &""),
			"evidence_status": declaration.get("evidence_status", &""),
			"anchor": world.get_node_or_null(NodePath(str(declaration.get("anchor_path", "")))),
		})
	return endpoints


func _is_finite_transform(transform: Transform3D) -> bool:
	return transform.origin.is_finite() and transform.basis.get_scale().is_finite()


func _cleanup(game: GameFlow) -> void:
	game.queue_free()
	await process_frame
	await physics_frame
	await process_frame


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("STATION_ROUTE_REGISTRY_INTEGRATION_TEST_OK")
		quit(0)
	else:
		print("STATION_ROUTE_REGISTRY_INTEGRATION_TEST_FAILED: ", "; ".join(_failures))
		quit(1)
