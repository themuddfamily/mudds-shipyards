extends SceneTree

## Adversarial contract for the declared station navigation graph and the
## presentation service couriers that consume it.
##
## The graph owns no topology: every node and edge is read out of the
## `StationRouteRegistry` report `ShipyardWorld` already publishes. This suite
## proves that reuse (an independent registry over the live modules reproduces
## the world's graph), that the graph fails closed on every malformed or rejected
## registry report, that a courier is deterministic at 30/60/120 Hz, that it can
## never leave its published envelope or intersect station structure, that it
## owns no berth/collision/interaction authority, and that the production audit
## turns red for a mutated courier and for a module that stops declaring its
## connection slot.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const AGENT_SCENE := preload("res://scenes/world/components/station_service_agent.tscn")

const CONNECTION_SLOT_META: StringName = &"station_connection_slot"
const APPROACH_ROUTE_ID: StringName = &"approach"
const HUB_CLAIMANT_ID: StringName = &"station-hub"
const REGISTRY_SCHEMA_VERSION := 2

const MOTION_EPSILON := 0.0002
const SAMPLE_SECONDS := 6.0
const PLAYER_CAPSULE_HEIGHT := 1.94
const REQUIRED_DECK_CLEARANCE := 2.3
const MINIMUM_BERTH_GAP := 0.15

## The protected launch volume the operational-lattice suite already freezes.
const PROTECTED_LAUNCH_VOLUME := AABB(Vector3(-10.75, 0.0, -68.0), Vector3(21.5, 12.0, 40.0))

const EXPECTED_AGENT_SPECS := {
	&"aft-junction-courier": {
		"node_name": &"AftJunctionServiceCourier",
		"slot_id": &"hub-aft-junction",
		"from": &"station-hub:hub-aft-junction",
		"to": &"aft-junction-stack:approach",
		"seed": 5501, "speed": 0.85, "lift": 3.7,
	},
	&"fleet-dock-courier": {
		"node_name": &"FleetDockServiceCourier",
		"slot_id": &"hub-fleet-dock-comb",
		"from": &"station-hub:hub-fleet-dock-comb",
		"to": &"fleet-dock-comb:approach",
		"seed": 7703, "speed": 1.2, "lift": 3.4,
	},
	&"freight-branch-courier": {
		"node_name": &"FreightBranchServiceCourier",
		"slot_id": &"hub-registry-pod-freight",
		"from": &"station-hub:hub-registry-pod-freight",
		"to": &"jovian-freight-berth:approach",
		"seed": 8821, "speed": 1.5, "lift": 9.1,
	},
	&"habitat-spine-courier": {
		"node_name": &"HabitatSpineServiceCourier",
		"slot_id": &"hub-starboard-habitat",
		"from": &"station-hub:hub-starboard-habitat",
		"to": &"habitat-spine:approach",
		"seed": 6607, "speed": 0.9, "lift": 3.7,
	},
	&"fabrication-annex-courier": {
		"node_name": &"FabricationAnnexServiceCourier",
		"slot_id": &"fabrication_annex_inbound",
		"from": &"station-hub:fabrication_annex_inbound",
		"to": &"fabrication_annex:annex_inbound",
		"seed": 11807, "speed": 0.95, "lift": 3.7,
	},
	&"observation-logistics-courier": {
		"node_name": &"ObservationLogisticsServiceCourier",
		"slot_id": &"observation-logistics-spur-origin",
		"from": &"station-hub:observation-logistics-spur-origin",
		"to": &"observation-logistics-spur:origin",
		"seed": 12847, "speed": 0.9, "lift": 3.7,
	},
	&"salvage-terrace-courier": {
		"node_name": &"SalvageTerraceServiceCourier",
		"slot_id": &"hub-salvage-terrace",
		"from": &"station-hub:hub-salvage-terrace",
		"to": &"salvage-terrace:connector",
		"seed": 13861, "speed": 0.85, "lift": 3.7,
	},
}

const EXPECTED_BERTH_TRANSFORMS := {
	&"central_berth": Transform3D(Basis.IDENTITY, Vector3(0.0, 1.15, -10.0)),
	&"arrow_recon_berth": Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-43.0, 1.15, 15.5)),
	&"jovian_freight_berth": Transform3D(Basis(Vector3.UP, PI), Vector3(-53.0, 1.63, 57.3)),
	&"zenith_fleet_dock_berth": Transform3D(Basis.IDENTITY, Vector3(22.0, 5.28, 53.3)),
	&"halyard_fleet_dock_berth": Transform3D(Basis.IDENTITY, Vector3(37.0, 5.28, 53.3)),
}

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_graph_normal_case()
	_test_graph_multi_hop_and_module_internal_links()
	_test_graph_rejects_malformed_reports()
	_test_graph_rejects_broken_topology()
	_test_graph_edge_length_boundaries()
	_test_route_search_invalid_and_unreachable()
	await _test_agent_route_configuration_boundaries()
	await _test_agent_determinism_and_lifecycle()
	await _test_agent_envelope_and_presentation_only()
	await _test_agent_mutations_turn_audit_red()
	await _test_agent_detach_readd_identity()

	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "complete production main scene instantiates")
	if game == null:
		_finish()
		return
	root.add_child(game)
	await process_frame
	await physics_frame
	await physics_frame
	var world := game.get_node_or_null("ShipyardWorld") as ShipyardWorld
	_check(world != null, "production main scene owns the shared ShipyardWorld")
	if world == null:
		await _cleanup(game)
		_finish()
		return

	_test_production_graph_reuses_the_route_registry(world)
	_test_production_courier_roster(world)
	_test_production_determinism(world)
	await _test_production_clearance_and_authority(world)
	_test_production_audit_detachment(world)
	_test_production_audit_detects_courier_mutation(world)
	_test_structured_red_on_undeclared_slot(world)
	await _test_production_duplicate_courier_is_rejected(world)
	await _test_production_activity_switch_reaches_couriers(world)
	await _test_main_detach_reentry(game, world)

	await _cleanup(game)
	_finish()


# --- 1. isolated graph -------------------------------------------------------


func _test_graph_normal_case() -> void:
	var graph := StationNavigationGraph.new()
	var report := graph.build_from_registry_report(_two_slot_report())
	_check(bool(report.valid) and (report.errors as PackedStringArray).is_empty(), "a valid registry report builds a valid navigation graph")
	_check(int(report.node_count) == 4 and int(report.edge_count) == 2, "each slot claim becomes one node and each accepted slot becomes one edge")
	_check(
		(report.node_ids as PackedStringArray) == PackedStringArray([
			"mod-a:approach", "mod-b:approach", "station-hub:hub-a", "station-hub:hub-b",
		]),
		"node ids are `<claimant>:<route>` and are published in stable sorted text order"
	)
	_check((report.edge_ids as PackedStringArray) == PackedStringArray(["hub-a", "hub-b"]), "edge ids are exactly the declared connection slot ids")
	var edge := graph.get_edge_record(&"hub-a")
	_check(
		edge.get("kind", &"") == &"connection_slot"
		and edge.get("hub_node_id", &"") == &"station-hub:hub-a"
		and edge.get("module_node_id", &"") == &"mod-a:approach"
		and is_equal_approx(float(edge.get("length", -1.0)), 3.0),
		"each connection-slot edge records its hub side, module side, kind, and exact declared span"
	)
	_check(int(report.component_count) == 2, "the station hub is deliberately not collapsed, so unrelated slots stay separate components")
	_check(
		not bool((report.authority as Dictionary).owns_berth_authority)
		and not bool((report.authority as Dictionary).owns_spawn_or_regeneration_authority)
		and not bool((report.authority as Dictionary).proves_physical_traversability),
		"the graph declares no berth, regeneration, or traversability authority"
	)
	_check(
		(report.evidence as Dictionary).evidence_status == &"modern_interpretation"
		and (report.evidence as Dictionary).derived_from == &"station_route_registry"
		and not bool((report.evidence as Dictionary).authenticated_original_logistics),
		"the graph is tagged modern_interpretation and names the registry it derives from"
	)

	var detached := graph.get_report()
	(detached.nodes as Dictionary).clear()
	_check(not (graph.get_report().nodes as Dictionary).is_empty(), "the graph report is deeply detached from callers")
	var first_errors := graph.get_report().errors as PackedStringArray
	var second_errors := graph.get_report().errors as PackedStringArray
	_check(first_errors.size() == second_errors.size(), "reading the report repeatedly never re-runs validation or grows the error list")

	var repeat := StationNavigationGraph.new().build_from_registry_report(_two_slot_report())
	_check(
		(repeat.node_ids as PackedStringArray) == (report.node_ids as PackedStringArray)
		and (repeat.edge_ids as PackedStringArray) == (report.edge_ids as PackedStringArray),
		"rebuilding from the same registry report is deterministic"
	)


func _test_graph_multi_hop_and_module_internal_links() -> void:
	var slots := {
		&"hub-a": [_claim(HUB_CLAIMANT_ID, &"hub-a", Vector3.ZERO), _claim(&"mod-x", &"north", Vector3(3, 0, 0))],
		&"hub-b": [_claim(HUB_CLAIMANT_ID, &"hub-b", Vector3(0, 0, 20)), _claim(&"mod-x", &"south", Vector3(3, 0, 20))],
	}
	var edges := [_edge(&"hub-a", "station-hub:hub-a", "mod-x:north"), _edge(&"hub-b", "station-hub:hub-b", "mod-x:south")]
	var graph := StationNavigationGraph.new()
	var report := graph.build_from_registry_report(_registry_report(slots, edges))
	_check(bool(report.valid) and int(report.edge_count) == 3, "a module that declares two slots contributes one bounded internal link")
	var internal := graph.get_edge_record(&"mod-x::north+south")
	_check(internal.get("kind", &"") == &"module_internal" and is_equal_approx(float(internal.get("length", -1.0)), 20.0), "the module-internal link records its kind and exact declared span")
	_check(int(report.component_count) == 1, "two slots served by one module resolve to a single connected component")

	var route := graph.find_route(&"station-hub:hub-a", &"station-hub:hub-b")
	_check(bool(route.valid) and int(route.hop_count) == 3, "route search resolves a genuine multi-hop path across the declared graph")
	_check(
		(route.node_ids as PackedStringArray) == PackedStringArray([
			"station-hub:hub-a", "mod-x:north", "mod-x:south", "station-hub:hub-b",
		]),
		"the resolved path visits exactly the declared endpoints in order"
	)
	_check((route.edge_ids as PackedStringArray).size() == 3, "every resolved hop names the declared edge it crossed")
	_check(is_equal_approx(float(route.length), 26.0), "the resolved route length is the sum of its declared spans")
	_check(not bool(route.proves_physical_traversability), "a resolved route explicitly does not claim the player can walk it")
	var waypoints := route.waypoints as PackedVector3Array
	_check(
		waypoints.size() == 4 and waypoints[0].is_equal_approx(Vector3.ZERO) and waypoints[3].is_equal_approx(Vector3(0, 0, 20)),
		"waypoints are the declared marker origins, not interpolated positions"
	)


func _test_graph_rejects_malformed_reports() -> void:
	var cases := {
		"a missing report": null,
		"a non-dictionary report": 17,
		"an empty report": {},
	}
	for description: String in cases:
		var graph := StationNavigationGraph.new()
		var report := graph.build_from_registry_report(cases[description])
		_check(
			not bool(report.valid) and int(report.node_count) == 0 and not (report.errors as PackedStringArray).is_empty(),
			"the navigation graph fails closed on %s" % description
		)

	var wrong_schema := _two_slot_report()
	wrong_schema["schema_version"] = REGISTRY_SCHEMA_VERSION + 1
	var schema_report := StationNavigationGraph.new().build_from_registry_report(wrong_schema)
	_check(
		not bool(schema_report.valid) and _errors_mention(schema_report, "unsupported station route registry schema"),
		"an unreviewed registry schema is rejected instead of silently reinterpreted"
	)

	var no_slots := _two_slot_report()
	no_slots.erase("slots")
	_check(not bool(StationNavigationGraph.new().build_from_registry_report(no_slots).valid), "a report without a slot table is rejected")
	var no_adjacency := _two_slot_report()
	no_adjacency.erase("adjacency")
	_check(not bool(StationNavigationGraph.new().build_from_registry_report(no_adjacency).valid), "a report without an adjacency graph is rejected")

	var invalid_registry := _two_slot_report()
	invalid_registry["valid"] = false
	invalid_registry["errors"] = PackedStringArray(["module aft-junction-stack declares no station connection slot"])
	var invalid_report := StationNavigationGraph.new().build_from_registry_report(invalid_registry)
	_check(
		not bool(invalid_report.valid)
		and int(invalid_report.node_count) == 0
		and _errors_mention(invalid_report, "refuses to route over a rejected graph"),
		"a registry that already rejected the station graph produces no routable nodes at all"
	)


func _test_graph_rejects_broken_topology() -> void:
	var malformed_claim := _two_slot_report()
	(malformed_claim.slots as Dictionary)[&"hub-a"] = [17, _claim(&"mod-a", &"approach", Vector3(3, 0, 0))]
	_check(_rejects(malformed_claim, "malformed claim"), "a malformed slot claim is rejected")

	var missing_ids := _two_slot_report()
	(missing_ids.slots as Dictionary)[&"hub-a"] = [
		{"module_id": &"", "route_id": &"hub-a", "transform": Transform3D.IDENTITY},
		_claim(&"mod-a", &"approach", Vector3(3, 0, 0)),
	]
	_check(_rejects(missing_ids, "missing a claimant"), "a claim without a claimant id is rejected")

	var non_finite := _two_slot_report()
	(non_finite.slots as Dictionary)[&"hub-a"] = [
		{"module_id": HUB_CLAIMANT_ID, "route_id": &"hub-a", "transform": Transform3D(Basis.IDENTITY, Vector3(NAN, 0, 0))},
		_claim(&"mod-a", &"approach", Vector3(3, 0, 0)),
	]
	_check(_rejects(non_finite, "non-finite transform"), "a non-finite claim transform is rejected")

	var duplicate := _two_slot_report()
	(duplicate.slots as Dictionary)[&"hub-b"] = [
		_claim(HUB_CLAIMANT_ID, &"hub-a", Vector3(0, 0, 20)),
		_claim(&"mod-b", &"approach", Vector3(3, 0, 20)),
	]
	_check(_rejects(duplicate, "duplicate navigation node id"), "two claims resolving to the same node id are rejected")

	var unknown_endpoint := _two_slot_report()
	(unknown_endpoint.adjacency as Dictionary)["edges"] = [_edge(&"hub-a", "station-hub:hub-a", "ghost:approach")]
	_check(_rejects(unknown_endpoint, "no navigation node"), "an edge naming an endpoint with no node is rejected")

	var wrong_arity := _two_slot_report()
	(wrong_arity.adjacency as Dictionary)["edges"] = [{"slot_id": &"hub-a", "endpoints": PackedStringArray(["station-hub:hub-a"])}]
	_check(_rejects(wrong_arity, "exactly two endpoints"), "an edge that does not name exactly two endpoints is rejected")

	var self_edge := _two_slot_report()
	(self_edge.adjacency as Dictionary)["edges"] = [_edge(&"hub-a", "station-hub:hub-a", "station-hub:hub-a")]
	_check(_rejects(self_edge, "connects an endpoint to itself"), "a self edge is rejected")

	var two_modules := _registry_report(
		{&"hub-a": [_claim(&"mod-a", &"approach", Vector3.ZERO), _claim(&"mod-b", &"approach", Vector3(3, 0, 0))]},
		[_edge(&"hub-a", "mod-a:approach", "mod-b:approach")]
	)
	_check(_rejects(two_modules, "exactly one station hub endpoint"), "two modules pairing directly without the world hub is rejected")

	var two_hubs := _registry_report(
		{&"hub-a": [_claim(HUB_CLAIMANT_ID, &"hub-a", Vector3.ZERO), _claim(HUB_CLAIMANT_ID, &"hub-b", Vector3(3, 0, 0))]},
		[_edge(&"hub-a", "station-hub:hub-a", "station-hub:hub-b")]
	)
	_check(_rejects(two_hubs, "exactly one station hub endpoint"), "two hub endpoints pairing with no module is rejected")

	var dangling := _two_slot_report()
	(dangling.adjacency as Dictionary)["dangling_slots"] = PackedStringArray(["hub-b"])
	_check(_rejects(dangling, "dangling connection slot"), "a dangling slot reported by the registry is mirrored as a navigation error")

	var overclaimed := _two_slot_report()
	(overclaimed.adjacency as Dictionary)["overclaimed_slots"] = PackedStringArray(["hub-a"])
	_check(_rejects(overclaimed, "overclaimed connection slot"), "an overclaimed slot reported by the registry is mirrored as a navigation error")


func _test_graph_edge_length_boundaries() -> void:
	var minimum := StationNavigationGraph.MINIMUM_EDGE_LENGTH
	var maximum := StationNavigationGraph.MAXIMUM_EDGE_LENGTH
	_check(bool(_single_edge_report(minimum).valid), "an edge exactly at the minimum bounded span is accepted")
	_check(bool(_single_edge_report(maximum).valid), "an edge exactly at the maximum bounded span is accepted")
	_check(not bool(_single_edge_report(minimum - 0.01).valid), "an edge just under the minimum bounded span is rejected")
	_check(not bool(_single_edge_report(maximum + 0.01).valid), "an edge just over the maximum bounded span is rejected")
	var over := _single_edge_report(maximum + 0.01)
	_check(_errors_mention(over, "outside the bounded"), "the out-of-band rejection names the bounded connector band")


func _test_route_search_invalid_and_unreachable() -> void:
	var unbuilt := StationNavigationGraph.new()
	var unbuilt_route := unbuilt.find_route(&"station-hub:hub-a", &"mod-a:approach")
	_check(not bool(unbuilt_route.valid) and _errors_mention(unbuilt_route, "not built"), "route search on an unbuilt graph fails closed")

	var graph := StationNavigationGraph.new()
	graph.build_from_registry_report(_two_slot_report())
	_check(not bool(graph.find_route(&"", &"mod-a:approach").valid), "an unnamed route origin is rejected")
	_check(not bool(graph.find_route(&"station-hub:hub-a", &"").valid), "an unnamed route destination is rejected")
	_check(
		_errors_mention(graph.find_route(&"station-hub:hub-a", &"station-hub:hub-a"), "must be distinct"),
		"a route whose endpoints are the same node is rejected"
	)
	_check(_errors_mention(graph.find_route(&"ghost:approach", &"mod-a:approach"), "unknown route origin"), "an unknown route origin is rejected by name")
	_check(_errors_mention(graph.find_route(&"station-hub:hub-a", &"ghost:approach"), "unknown route destination"), "an unknown route destination is rejected by name")
	_check(
		_errors_mention(graph.find_route(&"station-hub:hub-a", &"mod-b:approach"), "no declared station route connects"),
		"two endpoints in different components are reported unreachable rather than joined by invention"
	)
	var valid_route := graph.find_route(&"station-hub:hub-a", &"mod-a:approach")
	_check(bool(valid_route.valid) and int(valid_route.hop_count) == 1 and (valid_route.waypoints as PackedVector3Array).size() == 2, "a declared single-hop route resolves with both waypoints")


# --- 2. isolated component ---------------------------------------------------


func _test_agent_route_configuration_boundaries() -> void:
	var agent := AGENT_SCENE.instantiate() as StationServiceAgent
	_check(agent != null, "the station service agent scene instantiates")
	if agent == null:
		return
	var straight := PackedVector3Array([Vector3.ZERO, Vector3(0, 0, 4)])
	var ids := PackedStringArray(["a", "b"])
	_check(not agent.configure_service_route(&"", ids, straight), "an unnamed route id is rejected")
	_check(not agent.configure_service_route(&"slot", PackedStringArray(["a"]), straight), "route node ids that do not match the waypoint count are rejected")
	_check(not agent.configure_service_route(&"slot", PackedStringArray(["a", ""]), straight), "an empty route node id is rejected")
	_check(not agent.configure_service_route(&"slot", PackedStringArray(["a"]), PackedVector3Array([Vector3.ZERO])), "a single-waypoint route is rejected")
	_check(
		not agent.configure_service_route(&"slot", ids, PackedVector3Array([Vector3.ZERO, Vector3(0, 0, NAN)])),
		"a non-finite waypoint is rejected"
	)
	_check(
		not agent.configure_service_route(&"slot", ids, PackedVector3Array([Vector3(1, 0, 0), Vector3(1, 0, 4)])),
		"a route whose first waypoint is not the component mount is rejected"
	)
	_check(
		not agent.configure_service_route(&"slot", ids, PackedVector3Array([Vector3.ZERO, Vector3(0, 0, 0.1)])),
		"a segment shorter than the bounded minimum is rejected"
	)
	_check(
		not agent.configure_service_route(&"slot", ids, PackedVector3Array([Vector3.ZERO, Vector3(0, 0, StationServiceAgent.MINIMUM_ROUTE_LENGTH - 0.05)])),
		"a route just under the bounded minimum length is rejected"
	)
	_check(
		not agent.configure_service_route(&"slot", ids, PackedVector3Array([Vector3.ZERO, Vector3(0, 0, StationServiceAgent.MAXIMUM_ROUTE_LENGTH + 0.05)])),
		"a route just over the bounded maximum length is rejected"
	)
	_check(
		agent.configure_service_route(&"slot", ids, PackedVector3Array([Vector3.ZERO, Vector3(0, 0, StationServiceAgent.MINIMUM_ROUTE_LENGTH)])),
		"a route exactly at the bounded minimum length is accepted"
	)
	var too_many := PackedVector3Array()
	var too_many_ids := PackedStringArray()
	for index in StationServiceAgent.MAXIMUM_WAYPOINTS + 1:
		too_many.append(Vector3(0, 0, float(index) * 1.5))
		too_many_ids.append("n%d" % index)
	_check(not agent.configure_service_route(&"slot", too_many_ids, too_many), "a route above the bounded waypoint ceiling is rejected")

	agent.agent_id = &"probe-courier"
	_check(agent.configure_service_route(&"slot", ids, straight), "a bounded valid route is accepted before the component builds")
	root.add_child(agent)
	await process_frame
	_check(
		not agent.configure_service_route(&"slot", ids, PackedVector3Array([Vector3.ZERO, Vector3(0, 0, 6)])),
		"a built courier can never be re-aimed at a different route"
	)
	_check(bool(agent.get_audit_report().valid), "a configured courier passes its complete component audit")
	agent.queue_free()
	await process_frame
	await process_frame


func _test_agent_determinism_and_lifecycle() -> void:
	var agent := await _spawn_probe_agent()
	if agent == null:
		return
	var reference_states := {}
	for rate in [30, 60, 120]:
		agent.reset_agent_time()
		agent.set_agent_paused(false)
		for _step in roundi(SAMPLE_SECONDS * float(rate)):
			agent.advance_agent_simulation(1.0 / float(rate))
		agent.set_agent_paused(true)
		reference_states[rate] = agent.get_agent_state()
	agent.set_agent_time(SAMPLE_SECONDS)
	var absolute := agent.get_agent_state()
	var subdivisions_match := true
	for rate in [30, 60, 120]:
		subdivisions_match = subdivisions_match and _agent_states_match(reference_states[rate], absolute)
	_check(subdivisions_match, "courier motion is identical at deterministic 30/60/120 Hz and at absolute time")

	var fingerprint := agent.get_determinism_fingerprint()
	agent.set_agent_time(0.0)
	_check(agent.get_determinism_fingerprint() == fingerprint, "the determinism fingerprint depends on the route and seed, not the clock")

	agent.set_agent_time(SAMPLE_SECONDS)
	var stable := agent.get_agent_state()
	_check(not agent.advance_agent_simulation(1.0) and _agent_states_match(stable, agent.get_agent_state()), "pause blocks manual and process advancement")
	agent.set_agent_enabled(false)
	agent.set_agent_paused(false)
	_check(not agent.advance_agent_simulation(1.0) and not agent.is_processing(), "disable blocks advancement even when unpaused")
	agent.set_agent_time(4.0)
	agent.reset_agent_time()
	_check(
		is_zero_approx(agent.get_agent_time())
		and not bool(agent.get_agent_state().visible)
		and not agent.is_processing(),
		"reset while disabled restores the exact zero-time pose without presentation work"
	)
	_check(
		not agent.set_agent_time(-0.01) and not agent.set_agent_time(NAN) and not agent.set_agent_time(INF),
		"the courier rejects negative and non-finite absolute time"
	)
	_check(
		not agent.advance_agent_simulation(-0.01) and not agent.advance_agent_simulation(NAN) and not agent.advance_agent_simulation(0.0),
		"the courier rejects invalid simulation deltas"
	)
	agent.set_agent_enabled(true)
	_check(agent.is_processing() and bool(agent.get_agent_state().visible), "re-enabling restores processing and presentation visibility")
	_check(bool(agent.get_audit_report().valid), "the courier audit stays green across the complete lifecycle sweep")
	agent.queue_free()
	await process_frame
	await process_frame


func _test_agent_envelope_and_presentation_only() -> void:
	var agent := await _spawn_probe_agent()
	if agent == null:
		return
	var envelope := agent.get_service_envelope()
	var local_min := envelope.local_min as Vector3
	var local_max := envelope.local_max as Vector3
	var outside := 0
	var samples := 512
	var cycle := 2.0 * agent.get_route_length() / agent.traversal_speed
	for index in samples:
		agent.set_agent_time(cycle * float(index) / float(samples))
		var position := agent.get_agent_state().carriage_position as Vector3
		var body := StationServiceAgent.BODY_HALF_EXTENTS
		if (
			position.x - body.x < local_min.x - 0.001 or position.x + body.x > local_max.x + 0.001
			or position.y - body.y < local_min.y - 0.001 or position.y + body.y > local_max.y + 0.001
			or position.z - body.z < local_min.z - 0.001 or position.z + body.z > local_max.z + 0.001
		):
			outside += 1
	_check(outside == 0, "the courier body stays inside the published service envelope across 512 samples of a complete cycle")
	_check(
		float((agent.get_integration_contract() as Dictionary).minimum_ground_clearance) > PLAYER_CAPSULE_HEIGHT,
		"the published minimum ground clearance keeps the courier above the production player capsule"
	)
	agent.set_agent_time(0.0)
	var travelled := PackedFloat32Array()
	for index in 5:
		agent.set_agent_time(cycle * float(index) / 4.0)
		travelled.append(float(agent.get_agent_state().route_distance))
	_check(
		is_zero_approx(travelled[0]) and is_equal_approx(travelled[2], agent.get_route_length())
		and absf(travelled[4] - travelled[0]) < 0.001,
		"the courier reaches each declared endpoint exactly once and returns to its origin every cycle"
	)

	_check(
		agent.find_children("*", "CollisionObject3D", true, false).is_empty()
		and agent.find_children("*", "CollisionShape3D", true, false).is_empty()
		and agent.find_children("*", "Area3D", true, false).is_empty(),
		"the courier subtree contains no collider, body, or interaction area"
	)
	_check(
		agent.find_children("*", "Light3D", true, false).is_empty()
		and agent.find_children("*", "GPUParticles3D", true, false).is_empty()
		and agent.find_children("*", "AudioStreamPlayer3D", true, false).is_empty(),
		"the courier subtree adds no lights, particles, or audio voices"
	)
	var authority := agent.get_authority_contract()
	_check(
		not bool(authority.owns_berth_authority) and not bool(authority.owns_lease_authority)
		and not bool(authority.owns_spawn_or_regeneration_authority)
		and not bool(authority.owns_combat_or_damage_authority)
		and not bool(authority.owns_interaction_authority)
		and int(authority.ship_berth_count) == 0,
		"the courier declares explicitly zero berth, lease, regeneration, combat, and interaction authority"
	)
	_check(
		bool(agent.get_meta("presentation_only", false)) and bool(agent.get_meta("nonblocking_collision", false)),
		"the courier root carries the shared presentation-only/nonblocking discovery tags"
	)
	var evidence := agent.get_evidence_metadata()
	_check(
		evidence.evidence_status == &"modern_interpretation"
		and not bool(evidence.authenticated_original_routes)
		and not bool(evidence.authenticated_original_logistics),
		"the courier authenticates no original station route or logistics"
	)
	agent.queue_free()
	await process_frame
	await process_frame


func _test_agent_mutations_turn_audit_red() -> void:
	var unconfigured := AGENT_SCENE.instantiate() as StationServiceAgent
	unconfigured.agent_id = &"unconfigured-courier"
	root.add_child(unconfigured)
	await process_frame
	_check(
		not bool(unconfigured.get_audit_report().valid)
		and _has_error(unconfigured.get_validation_errors(), "no configured navigation route"),
		"a courier with no resolved route fails its own audit instead of flying an invented line"
	)
	unconfigured.queue_free()
	await process_frame

	var nameless := AGENT_SCENE.instantiate() as StationServiceAgent
	nameless.configure_service_route(&"slot", PackedStringArray(["a", "b"]), PackedVector3Array([Vector3.ZERO, Vector3(0, 0, 4)]))
	root.add_child(nameless)
	await process_frame
	_check(
		_has_error(nameless.get_validation_errors(), "stable non-empty agent id"),
		"a courier without a stable agent id fails its own audit"
	)
	nameless.queue_free()
	await process_frame

	var agent := await _spawn_probe_agent()
	if agent == null:
		return
	_check(bool(agent.get_audit_report().valid), "the mutation subject starts green")

	var carriage := agent.get_node_or_null(^"PresentationRoot/ServiceCarriage") as Node3D
	_check(carriage != null, "the deterministic courier carriage is reachable at its stable path")
	if carriage != null:
		var original := carriage.position
		carriage.position += Vector3(0.0, 0.35, 0.0)
		_check(
			_has_error(agent.get_validation_errors(), "diverged from its deterministic clock"),
			"MUTATION: moving the carriage by hand turns the courier audit red"
		)
		carriage.position = original
		_check(bool(agent.get_audit_report().valid), "restoring the carriage pose returns the courier audit to green")

	var hull := agent.get_node_or_null(^"PresentationRoot/ServiceCarriage/Hull") as MeshInstance3D
	_check(hull != null, "the courier hull material is reachable at its stable path")
	if hull != null:
		var shared_hull_material := hull.material_override as StandardMaterial3D
		var original_roughness := shared_hull_material.roughness
		shared_hull_material.roughness = 0.01
		_check(
			not bool(agent.get_material_catalog_audit().valid)
			and _has_error(agent.get_validation_errors(), "material catalog diverged"),
			"MUTATION: changing a shared immutable courier material turns its visible-parameter audit red"
		)
		shared_hull_material.roughness = original_roughness
		_check(bool(agent.get_audit_report().valid), "restoring the shared material returns the courier audit to green")

	agent.hover_lift = StationServiceAgent.MINIMUM_HOVER_LIFT
	_check(
		_has_error(agent.get_validation_errors(), "hover_lift cannot be changed"),
		"MUTATION: retuning the hover band after build turns the courier audit red"
	)
	agent.hover_lift = agent.get_integration_contract().hover_lift
	_check(bool(agent.get_audit_report().valid), "restoring the built hover band returns the courier audit to green")

	var intruder := Area3D.new()
	intruder.name = "IntruderVolume"
	agent.get_node(^"PresentationRoot").add_child(intruder)
	await process_frame
	var intruder_errors := agent.get_validation_errors()
	_check(
		_has_error(intruder_errors, "collision or interaction volumes")
		or _has_error(intruder_errors, "built courier hierarchy identities changed"),
		"MUTATION: adding an interaction volume under the courier turns the audit red"
	)
	intruder.queue_free()
	await process_frame
	_check(bool(agent.get_audit_report().valid), "removing the intruding volume returns the courier audit to green")

	var extra_mesh := MeshInstance3D.new()
	extra_mesh.name = "ExtraMesh"
	extra_mesh.mesh = BoxMesh.new()
	agent.get_node(^"PresentationRoot").add_child(extra_mesh)
	await process_frame
	_check(
		not bool(agent.get_audit_report().valid),
		"MUTATION: an extra mesh past the immutable component budget turns the audit red"
	)
	extra_mesh.queue_free()
	await process_frame
	_check(bool(agent.get_audit_report().valid), "removing the extra mesh returns the courier audit to green")

	agent.queue_free()
	await process_frame
	await process_frame


func _test_agent_detach_readd_identity() -> void:
	var agent := await _spawn_probe_agent()
	if agent == null:
		return
	var instance_id := agent.get_instance_id()
	var descendants := _descendant_instance_ids(agent)

	agent.set_agent_paused(false)
	root.remove_child(agent)
	await process_frame
	_check(not agent.is_processing(), "a detached courier stops burning frames")
	var detached_state := agent.get_agent_state()
	var detached_processing := agent.is_processing()
	var detached_advance := agent.advance_agent_simulation(1.0)
	var detached_seek := agent.set_agent_time(float(detached_state.elapsed) + 3.0)
	agent.reset_agent_time()
	agent.set_agent_enabled(false)
	agent.set_agent_paused(true)
	_check(
		not detached_advance
		and not detached_seek
		and agent.get_agent_state() == detached_state
		and agent.is_processing() == detached_processing,
		"a detached courier rejects all lifecycle and clock mutators without retained-state drift"
	)
	root.add_child(agent)
	await process_frame
	_check(agent.get_instance_id() == instance_id and _descendant_instance_ids(agent) == descendants, "re-entry preserves every courier node identity and creates no duplicate")
	_check(agent.is_processing() and bool(agent.get_agent_state().visible), "re-entry restores the courier process and presentation lifecycle")
	var reentered_time := agent.get_agent_time()
	_check(
		agent.advance_agent_simulation(0.25)
		and is_equal_approx(agent.get_agent_time(), reentered_time + 0.25),
		"a re-added courier accepts a fresh direct advancement"
	)

	# Paused re-entry must not advance the clock or resume processing on its own,
	# so the exact deterministic pose has to survive the round trip untouched.
	agent.set_agent_paused(true)
	agent.set_agent_time(3.25)
	var state := agent.get_agent_state()
	root.remove_child(agent)
	await process_frame
	root.add_child(agent)
	await process_frame
	await process_frame
	_check(_agent_states_match(state, agent.get_agent_state()), "re-entry preserves the exact deterministic courier pose")
	_check(not agent.is_processing() and agent.is_agent_paused(), "re-entry restores the paused lifecycle rather than silently resuming it")
	_check(agent.get_instance_id() == instance_id and _descendant_instance_ids(agent) == descendants, "a second detach and re-entry still creates no duplicate courier node")
	_check(bool(agent.get_audit_report().valid), "the courier audit stays green across detach and re-entry")
	agent.set_agent_paused(false)
	var queued_state := agent.get_agent_state()
	var queued_processing := agent.is_processing()
	agent.queue_free()
	var queued_advance := agent.advance_agent_simulation(1.0)
	var queued_seek := agent.set_agent_time(float(queued_state.elapsed) + 3.0)
	agent.reset_agent_time()
	agent.set_agent_enabled(false)
	agent.set_agent_paused(true)
	_check(
		agent.is_inside_tree()
		and agent.is_queued_for_deletion()
		and not queued_advance
		and not queued_seek
		and agent.get_agent_state() == queued_state
		and agent.is_processing() == queued_processing,
		"a queued courier rejects all lifecycle and clock mutators without retained-state drift"
	)
	agent.queue_free()
	await process_frame
	await process_frame


# --- 3. production integration ------------------------------------------------


func _test_production_graph_reuses_the_route_registry(world: ShipyardWorld) -> void:
	var graph_report := world.get_station_navigation_graph_report()
	var registry_report := world.get_station_route_registry_report()
	_check(bool(graph_report.valid) and (graph_report.errors as PackedStringArray).is_empty(), "the production navigation graph is valid")
	_check(
		int(graph_report.node_count) == int(registry_report.connection_slot_count) * 2
		and int(graph_report.edge_count) == int(registry_report.connection_slot_count),
		"the production graph has exactly two nodes and one edge per declared connection slot"
	)
	_check(int(graph_report.edge_count) == 7 and int(graph_report.node_count) == 14, "the live station resolves to seven declared edges over fourteen declared endpoints")
	_check(int(graph_report.component_count) == 7, "the world hub is not collapsed, so each declared slot stays its own component")
	var slot_ids := PackedStringArray()
	for slot_id: StringName in (registry_report.slots as Dictionary).keys():
		slot_ids.append(String(slot_id))
	slot_ids.sort()
	_check((graph_report.edge_ids as PackedStringArray) == slot_ids, "the graph's edge ids are exactly the registry's declared slot ids")

	# An independent graph over an independent registry built from the same live
	# modules must reproduce the world's graph. That is the reuse contract: the
	# world is not caching a second, private topology.
	var probe_registry := StationRouteRegistry.new().build_registry(_module_nodes(world), _hub_endpoints(world))
	var probe_graph := StationNavigationGraph.new().build_from_registry_report(probe_registry)
	_check(
		bool(probe_graph.valid)
		and (probe_graph.node_ids as PackedStringArray) == (graph_report.node_ids as PackedStringArray)
		and (probe_graph.edge_ids as PackedStringArray) == (graph_report.edge_ids as PackedStringArray),
		"an independent registry over the same live modules reproduces the world's navigation graph exactly"
	)
	for raw_node_id in graph_report.node_ids as PackedStringArray:
		var node_record := (graph_report.nodes as Dictionary).get(StringName(raw_node_id), {}) as Dictionary
		var claim_transform := node_record.get("transform", Transform3D.IDENTITY) as Transform3D
		var claimant := node_record.get("claimant_id", &"") as StringName
		var expected := Transform3D.IDENTITY
		if claimant == HUB_CLAIMANT_ID:
			expected = _hub_anchor_transform(world, node_record.get("slot_id", &"") as StringName)
		else:
			var module := _module_by_id(world, claimant)
			expected = (module.get_route_marker(node_record.get("route_id", &"") as StringName) as Node3D).global_transform
		_check(claim_transform.is_equal_approx(expected), "navigation node %s reads its transform from live station geometry" % raw_node_id)


func _test_production_courier_roster(world: ShipyardWorld) -> void:
	var agents := world.get_station_service_agents()
	_check(agents.size() == 7, "the production station integrates exactly seven declared-slot couriers")
	var material_roster_nodes: Array[Node] = []
	for agent in agents:
		material_roster_nodes.append(agent)
	var material_roster := StationServiceAgent.audit_material_catalog_roster(material_roster_nodes)
	var material_counts := material_roster.counts as Dictionary
	print("STATION_SERVICE_MATERIAL_ROSTER: ", material_roster)
	_check(
		bool(material_roster.valid)
		and bool(material_roster.catalog_shared)
		and int(material_counts.instance_count) == 7
		and int(material_counts.catalog_entries) == 6
		and int(material_counts.retained_unique_materials) == 6,
		"seven production couriers retain one six-entry material catalog instead of 42 duplicate resources"
	)
	_check(
		int(material_counts.bound_material_references) == 49,
		"catalog sharing preserves all seven visible material bindings on each of seven couriers"
	)
	var pod_mesh_roster := StationServiceAgent.audit_pod_mesh_roster(material_roster_nodes)
	var pod_mesh_counts := pod_mesh_roster.counts as Dictionary
	print("STATION_SERVICE_POD_MESH_ROSTER: ", pod_mesh_roster)
	_check(
		bool(pod_mesh_roster.valid)
		and bool(pod_mesh_roster.mesh_shared)
		and bool(pod_mesh_roster.recipe_matches)
		and int(pod_mesh_counts.instance_count) == 7
		and int(pod_mesh_counts.pod_copy_count) == 14
		and int(pod_mesh_counts.retained_unique_meshes) == 1,
		"seven couriers retain one immutable PortPod/StarboardPod mesh across fourteen stable presentation nodes"
	)
	var hull_mesh_ids := {}
	var hulls_preserve_presentation_contract := true
	for agent in agents:
		var hull := agent.get_node_or_null(^"PresentationRoot/ServiceCarriage/Hull") as MeshInstance3D
		if hull == null or hull.mesh == null:
			hulls_preserve_presentation_contract = false
			continue
		hull_mesh_ids[hull.mesh.get_instance_id()] = true
		var material_ids := (agent.get_material_catalog_audit().identity_by_key as Dictionary)
		hulls_preserve_presentation_contract = hulls_preserve_presentation_contract \
			and hull.position.is_equal_approx(Vector3.ZERO) \
			and hull.basis.is_equal_approx(Basis.IDENTITY) \
			and hull.material_override != null \
			and hull.material_override.get_instance_id() == int(material_ids.get("hull", 0))
	_check(
		hulls_preserve_presentation_contract
		and hull_mesh_ids.size() == 1
		and agents.size() == 7,
		"seven couriers retain one immutable Hull mesh across their stable presentation nodes"
	)
	if agents.size() >= 2:
		var mutated_pod := agents[1].get_node_or_null(^"PresentationRoot/ServiceCarriage/PortPod") as MeshInstance3D
		_check(mutated_pod != null, "a second production courier exposes PortPod at its stable presentation path")
		if mutated_pod != null:
			var original_pod_mesh := mutated_pod.mesh
			mutated_pod.mesh = original_pod_mesh.duplicate()
			var mutated_pod_roster := StationServiceAgent.audit_pod_mesh_roster(material_roster_nodes)
			_check(
				not bool(mutated_pod_roster.valid)
				and int((mutated_pod_roster.counts as Dictionary).retained_unique_meshes) == 2,
				"MUTATION: replacing one PortPod mesh turns the cross-instance sharing audit red"
			)
			mutated_pod.mesh = original_pod_mesh
			_check(
				bool(StationServiceAgent.audit_pod_mesh_roster(material_roster_nodes).valid),
				"restoring the session-shared PortPod mesh returns the production roster audit to green"
			)
	if not agents.is_empty():
		var catalog := agents[0].get_material_catalog_audit()
		var visible_parameters := catalog.visible_parameters_by_key as Dictionary
		var hull_parameters := visible_parameters.hull as Dictionary
		var lens_parameters := visible_parameters.cyan_lit as Dictionary
		_check(
			(catalog.catalog_keys as PackedStringArray) == PackedStringArray([
				"cyan_dim", "cyan_lit", "graphite", "hull", "hull_edge", "orange",
			])
			and (hull_parameters.albedo_color as Color).is_equal_approx(Color("2b4753"))
			and is_equal_approx(float(hull_parameters.metallic), 0.66)
			and is_equal_approx(float(hull_parameters.roughness), 0.34)
			and (lens_parameters.albedo_color as Color).is_equal_approx(Color("78f1ec"))
			and is_equal_approx(float(lens_parameters.emission_energy), 1.5),
			"shared courier catalog preserves its exact key roster and visible hull/lens parameters"
		)
		var all_dynamic_bindings_valid := true
		for agent in agents:
			all_dynamic_bindings_valid = (
				all_dynamic_bindings_valid
				and bool(agent.get_material_catalog_audit().dynamic_lens_bindings_valid)
			)
		_check(
			all_dynamic_bindings_valid,
			"each courier keeps its own clock-driven status-lens reference while sharing catalog values"
		)
	var by_id := {}
	for agent in agents:
		by_id[agent.get_agent_id()] = agent
	for agent_id: StringName in EXPECTED_AGENT_SPECS:
		var spec := EXPECTED_AGENT_SPECS[agent_id] as Dictionary
		var agent := by_id.get(agent_id) as StationServiceAgent
		_check(agent != null, "exact integrated courier exists: %s" % agent_id)
		if agent == null:
			continue
		_check(
			StringName(agent.name) == StringName(spec.node_name)
			and agent.get_parent().name == "ServiceAgents"
			and agent.get_parent().get_parent().name == "OperationalLattice",
			"%s is world-owned by the stable OperationalLattice/ServiceAgents hierarchy" % agent_id
		)
		_check(
			agent.variation_seed == int(spec.seed)
			and is_equal_approx(agent.traversal_speed, float(spec.speed))
			and is_equal_approx(agent.hover_lift, float(spec.lift)),
			"%s locks its deterministic seed, cadence, and hover band" % agent_id
		)
		_check(agent.get_route_id() == StringName(spec.slot_id), "%s serves its exact declared connection slot" % agent_id)
		var route := world.find_station_route(spec.from as StringName, spec.to as StringName)
		_check(bool(route.valid), "the live graph still resolves the declared route for %s" % agent_id)
		_check(
			agent.get_route_node_ids() == (route.get("node_ids", PackedStringArray()) as PackedStringArray),
			"%s installed the route endpoints the navigation graph resolved, not authored coordinates" % agent_id
		)
		var graph_waypoints := route.get("waypoints", PackedVector3Array()) as PackedVector3Array
		var agent_waypoints := agent.get_world_route_points()
		var waypoints_match := agent_waypoints.size() == graph_waypoints.size()
		for index in graph_waypoints.size():
			waypoints_match = waypoints_match and agent_waypoints[index].is_equal_approx(graph_waypoints[index])
		_check(waypoints_match, "%s world-space waypoints match the live navigation graph exactly" % agent_id)
		_check(agent.global_transform.origin.is_equal_approx(graph_waypoints[0]), "%s is mounted at its declared route origin" % agent_id)
		_check(agent.global_basis.is_equal_approx(Basis.IDENTITY), "%s mount stays unrotated so its hover lift remains world-up" % agent_id)
		_check(bool(agent.get_audit_report().valid), "%s passes its complete reusable component audit" % agent_id)

	var report := world.get_station_navigation_audit_report()
	_check(bool(report.valid) and (report.errors as PackedStringArray).is_empty(), "the integrated station navigation audit is valid without suppressed errors")
	_check(
		report.evidence_status == &"modern_interpretation"
		and not bool((report.evidence as Dictionary).authenticated_original_routes)
		and not bool((report.evidence as Dictionary).authenticated_original_logistics),
		"the navigation audit keeps the pass explicitly modern interpretation"
	)
	_check(
		not bool((report.authority as Dictionary).owns_berth_authority)
		and not bool((report.authority as Dictionary).owns_spawn_or_regeneration_authority)
		and not bool((report.authority as Dictionary).proves_physical_traversability),
		"the navigation audit declares no berth, regeneration, or traversability authority"
	)
	_check((report.placements as Dictionary).size() == 7, "the audit publishes every exact courier placement instead of only aggregate counts")


func _test_production_determinism(world: ShipyardWorld) -> void:
	for agent in world.get_station_service_agents():
		agent.set_agent_enabled(true)
		agent.set_agent_paused(true)
		var reference_states := {}
		for rate in [30, 60, 120]:
			agent.reset_agent_time()
			agent.set_agent_paused(false)
			for _step in roundi(SAMPLE_SECONDS * float(rate)):
				agent.advance_agent_simulation(1.0 / float(rate))
			agent.set_agent_paused(true)
			reference_states[rate] = agent.get_agent_state()
		agent.set_agent_time(SAMPLE_SECONDS)
		var absolute := agent.get_agent_state()
		var matches := true
		for rate in [30, 60, 120]:
			matches = matches and _agent_states_match(reference_states[rate], absolute)
		_check(matches, "%s motion is identical at deterministic 30/60/120 Hz and absolute time" % agent.get_agent_id())
		agent.reset_agent_time()
		agent.set_agent_paused(true)


func _test_production_clearance_and_authority(world: ShipyardWorld) -> void:
	var space := world.get_world_3d().direct_space_state
	var berth_volumes: Array[AABB] = []
	for berth_id in world.get_berth_ids():
		var berth := world.get_berth_node(berth_id)
		var half := berth.get_landing_half_extents()
		berth_volumes.append(_world_aabb(berth.get_dock_transform(), -half, half))

	var smallest_gap := INF
	var smallest_clearance := INF
	for agent in world.get_station_service_agents():
		var contract := agent.get_integration_contract()
		var envelope := _world_aabb(agent.global_transform, contract.local_min as Vector3, contract.local_max as Vector3)

		var box := BoxShape3D.new()
		box.size = envelope.size
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = box
		query.transform = Transform3D(Basis.IDENTITY, envelope.position + envelope.size * 0.5)
		query.collision_mask = 0xFFFFFFFF
		query.collide_with_areas = true
		query.collide_with_bodies = true
		var hits := space.intersect_shape(query, 32)
		var hit_names := PackedStringArray()
		for hit in hits:
			var collider := hit.get("collider") as Node
			if collider != null and not hit_names.has(str(collider.name)):
				hit_names.append(str(collider.name))
		_check(hits.is_empty(), "%s complete service envelope intersects no station collider or volume: %s" % [agent.get_agent_id(), hit_names])

		var route_points := agent.get_world_route_points()
		var deck_supported := true
		var agent_clearance := INF
		for step in 9:
			var sample: Vector3 = route_points[0].lerp(route_points[route_points.size() - 1], float(step) / 8.0)
			var ray := PhysicsRayQueryParameters3D.create(
				Vector3(sample.x, envelope.position.y, sample.z),
				Vector3(sample.x, envelope.position.y - 12.0, sample.z),
				PhysicsLayers.WORLD
			)
			ray.collide_with_areas = false
			var hit := space.intersect_ray(ray)
			if hit.is_empty():
				deck_supported = false
				continue
			agent_clearance = minf(agent_clearance, envelope.position.y - float((hit.position as Vector3).y))
		_check(deck_supported, "%s hovers over a continuously supported connector deck" % agent.get_agent_id())
		_check(
			agent_clearance >= REQUIRED_DECK_CLEARANCE,
			"%s keeps at least %.2f m between the deck surface and its lowest presentation body (%.3f m)" % [
				agent.get_agent_id(), REQUIRED_DECK_CLEARANCE, agent_clearance
			]
		)
		smallest_clearance = minf(smallest_clearance, agent_clearance)

		for berth_volume in berth_volumes:
			_check(not _aabbs_overlap(envelope, berth_volume), "%s service envelope leaves every live berth volume clear" % agent.get_agent_id())
			smallest_gap = minf(smallest_gap, _aabb_separation(envelope, berth_volume))
		_check(not _aabbs_overlap(envelope, PROTECTED_LAUNCH_VOLUME), "%s service envelope stays out of the protected launch volume" % agent.get_agent_id())
	_check(smallest_gap >= MINIMUM_BERTH_GAP, "every courier envelope clears every berth volume by at least 0.15 m (minimum %.3f m)" % smallest_gap)
	_check(smallest_clearance > PLAYER_CAPSULE_HEIGHT, "no courier ever occupies the production player capsule's headroom (minimum %.3f m)" % smallest_clearance)

	var agent_root := world.get_node_or_null(^"OperationalLattice/ServiceAgents")
	_check(agent_root != null, "the world owns a stable ServiceAgents root")
	if agent_root != null:
		_check(agent_root.find_children("*", "ShipBerth", true, false).is_empty(), "the courier roster owns no ShipBerth authority")
		_check(
			agent_root.find_children("*", "Area3D", true, false).is_empty()
			and agent_root.find_children("*", "CollisionObject3D", true, false).is_empty()
			and agent_root.find_children("*", "CollisionShape3D", true, false).is_empty(),
			"the courier roster adds no interaction volume, body, or collider to the production station"
		)

	for berth_id: StringName in EXPECTED_BERTH_TRANSFORMS:
		var berth := world.get_berth_node(berth_id)
		_check(
			berth != null and berth.get_dock_transform().is_equal_approx(EXPECTED_BERTH_TRANSFORMS[berth_id] as Transform3D),
			"adjacent berth authority is untouched: %s keeps its exact dock transform" % berth_id
		)


func _test_production_audit_detachment(world: ShipyardWorld) -> void:
	var detached := world.get_station_navigation_audit_report()
	(detached.placements as Dictionary).clear()
	(detached.graph as Dictionary).clear()
	_check(
		not (world.get_station_navigation_audit_report().placements as Dictionary).is_empty()
		and not (world.get_station_navigation_audit_report().graph as Dictionary).is_empty(),
		"the navigation audit is deeply detached from callers"
	)
	var graph_copy := world.get_station_navigation_graph_report()
	(graph_copy.nodes as Dictionary).clear()
	_check(not (world.get_station_navigation_graph_report().nodes as Dictionary).is_empty(), "the world's graph accessor is deeply detached from callers")
	var first := world.get_station_navigation_audit_report().errors as PackedStringArray
	var second := world.get_station_navigation_audit_report().errors as PackedStringArray
	_check(first.is_empty() and second.is_empty(), "reading the navigation audit repeatedly never grows the error list")


func _test_production_audit_detects_courier_mutation(world: ShipyardWorld) -> void:
	var agents := world.get_station_service_agents()
	if agents.is_empty():
		return
	var subject := agents[0]

	var original_name := subject.name
	subject.name = "RenamedCourier"
	_check(
		not bool(world.get_station_navigation_audit_report().valid),
		"MUTATION: renaming a production courier turns the station navigation audit red"
	)
	subject.name = original_name
	_check(bool(world.get_station_navigation_audit_report().valid), "restoring the courier name returns the navigation audit to green")

	var original_seed := subject.variation_seed
	subject.variation_seed = original_seed + 1
	var seeded := world.get_station_navigation_audit_report()
	_check(
		not bool(seeded.valid) and _errors_mention(seeded, "diverged from its audited placement/seed/cadence"),
		"MUTATION: re-seeding a production courier turns the station navigation audit red"
	)
	subject.variation_seed = original_seed
	_check(bool(world.get_station_navigation_audit_report().valid), "restoring the courier seed returns the navigation audit to green")

	var original_transform := subject.transform
	subject.transform = Transform3D(Basis.IDENTITY, original_transform.origin + Vector3(0.0, 1.5, 0.0))
	var moved := world.get_station_navigation_audit_report()
	_check(
		not bool(moved.valid) and _errors_mention(moved, "diverged from the live navigation graph"),
		"MUTATION: moving a production courier off its declared route origin turns the navigation audit red"
	)
	subject.transform = original_transform
	_check(bool(world.get_station_navigation_audit_report().valid), "restoring the courier mount returns the navigation audit to green")


func _test_structured_red_on_undeclared_slot(world: ShipyardWorld) -> void:
	var modules := _module_nodes(world)
	var hub_endpoints := _hub_endpoints(world)
	var baseline := StationNavigationGraph.new().build_from_registry_report(
		StationRouteRegistry.new().build_registry(modules, hub_endpoints)
	)
	_check(bool(baseline.valid) and int(baseline.edge_count) == 7, "an independent probe reproduces the valid seven-edge production graph")

	var subject := _module_by_id(world, &"aft-junction-stack")
	var marker := subject.get_route_marker(APPROACH_ROUTE_ID) as Node3D if subject != null else null
	_check(marker != null and marker.has_meta(CONNECTION_SLOT_META), "the aft junction approach marker declares its connection slot before mutation")
	if marker == null or not marker.has_meta(CONNECTION_SLOT_META):
		return
	var original_slot_id: Variant = marker.get_meta(CONNECTION_SLOT_META)

	marker.remove_meta(CONNECTION_SLOT_META)
	var red_registry := StationRouteRegistry.new().build_registry(modules, hub_endpoints)
	var red_graph := StationNavigationGraph.new()
	var red := red_graph.build_from_registry_report(red_registry)
	_check(
		not bool(red.valid) and _errors_mention(red, "refuses to route over a rejected graph"),
		"MUTATION: a module that stops declaring its connection slot turns the navigation graph red"
	)
	_check(
		int(red.node_count) == 0 and int(red.edge_count) == 0,
		"the rejected station graph exposes no routable node at all, so nothing can be flown over it"
	)
	_check(
		not bool(red_graph.find_route(&"station-hub:hub-starboard-habitat", &"habitat-spine:approach").valid),
		"a rejected station graph refuses even the routes whose own slots were untouched"
	)

	marker.set_meta(CONNECTION_SLOT_META, original_slot_id)
	var restored := StationNavigationGraph.new().build_from_registry_report(
		StationRouteRegistry.new().build_registry(modules, hub_endpoints)
	)
	_check(
		bool(restored.valid) and int(restored.edge_count) == 7,
		"restoring the declaration returns the independent navigation graph to valid"
	)
	_check(bool(world.get_station_navigation_audit_report().valid), "the live production navigation audit is unaffected by the isolated probe mutation")


func _test_production_duplicate_courier_is_rejected(world: ShipyardWorld) -> void:
	var agent_root := world.get_node_or_null(^"OperationalLattice/ServiceAgents") as Node3D
	if agent_root == null:
		return
	var duplicate := AGENT_SCENE.instantiate() as StationServiceAgent
	duplicate.name = "DuplicateCourier"
	duplicate.agent_id = &"aft-junction-courier"
	duplicate.configure_service_route(
		&"hub-aft-junction",
		PackedStringArray(["station-hub:hub-aft-junction", "aft-junction-stack:approach"]),
		PackedVector3Array([Vector3.ZERO, Vector3(0, 0, 4)])
	)
	agent_root.add_child(duplicate)
	await process_frame
	var report := world.get_station_navigation_audit_report()
	_check(
		not bool(report.valid) and _errors_mention(report, "does not match the live world hierarchy"),
		"MUTATION: a duplicate courier added to the live hierarchy turns the navigation audit red"
	)
	duplicate.queue_free()
	await process_frame
	await process_frame
	_check(bool(world.get_station_navigation_audit_report().valid), "removing the duplicate courier returns the navigation audit to green")


func _test_production_activity_switch_reaches_couriers(world: ShipyardWorld) -> void:
	# The determinism sweep above deliberately parks every courier paused. Restore
	# the live production lifecycle before auditing the world-level switch.
	for agent in world.get_station_service_agents():
		agent.set_agent_paused(false)
	await process_frame
	world.set_station_activity_enabled(false)
	await process_frame
	var all_disabled := true
	for agent in world.get_station_service_agents():
		all_disabled = all_disabled and not agent.is_agent_enabled() and not agent.is_processing() and not bool(agent.get_agent_state().visible)
	_check(all_disabled, "the world station-activity switch disables every courier's process and presentation")
	_check(bool(world.get_station_navigation_audit_report().valid), "a disabled courier roster still passes the navigation audit")
	world.set_station_activity_enabled(true)
	await process_frame
	var all_enabled := true
	for agent in world.get_station_service_agents():
		all_enabled = all_enabled and agent.is_agent_enabled() and agent.is_processing() and bool(agent.get_agent_state().visible)
	_check(all_enabled, "re-enabling the world station-activity switch restores every courier")


func _test_main_detach_reentry(game: GameFlow, world: ShipyardWorld) -> void:
	var before_ids := PackedInt64Array()
	var before_descendants := PackedInt64Array()
	for agent in world.get_station_service_agents():
		before_ids.append(agent.get_instance_id())
		before_descendants.append_array(_descendant_instance_ids(agent))
	before_ids.sort()
	before_descendants.sort()

	root.remove_child(game)
	await process_frame
	await physics_frame
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame

	var after_ids := PackedInt64Array()
	var after_descendants := PackedInt64Array()
	var agents := world.get_station_service_agents()
	for agent in agents:
		after_ids.append(agent.get_instance_id())
		after_descendants.append_array(_descendant_instance_ids(agent))
	after_ids.sort()
	after_descendants.sort()

	_check(agents.size() == 7, "whole-Main re-entry keeps exactly seven couriers without duplicating or stranding one")
	_check(after_ids == before_ids and after_descendants == before_descendants, "whole-Main re-entry preserves every courier node identity")
	var all_live := true
	for agent in agents:
		all_live = all_live and agent.is_agent_enabled() and agent.is_processing() and bool(agent.get_audit_report().valid)
	_check(all_live, "whole-Main re-entry restores every courier lifecycle and audit")
	_check(bool(world.get_station_navigation_audit_report().valid), "the station navigation audit is valid again after whole-Main re-entry")
	_check(bool(world.get_station_navigation_graph_report().valid), "the navigation graph is rebuilt from the registry on whole-Main re-entry")
	_check(bool(world.get_operational_lattice_audit_report().valid), "the adjacent operational-lattice audit stays valid across the same re-entry")


# --- helpers ------------------------------------------------------------------


func _spawn_probe_agent() -> StationServiceAgent:
	var agent := AGENT_SCENE.instantiate() as StationServiceAgent
	if agent == null:
		_check(false, "the station service agent scene instantiates for the probe")
		return null
	agent.agent_id = &"probe-courier"
	agent.variation_seed = 6607
	agent.traversal_speed = 1.0
	agent.hover_lift = 3.0
	agent.configure_service_route(
		&"probe-slot",
		PackedStringArray(["probe:start", "probe:end"]),
		PackedVector3Array([Vector3.ZERO, Vector3(0.0, 0.0, 4.0)])
	)
	root.add_child(agent)
	await process_frame
	agent.set_agent_paused(true)
	return agent


func _claim(module_id: StringName, route_id: StringName, origin: Vector3) -> Dictionary:
	return {
		"module_id": module_id,
		"route_id": route_id,
		"transform": Transform3D(Basis.IDENTITY, origin),
	}


func _edge(slot_id: StringName, first: String, second: String) -> Dictionary:
	return {"slot_id": slot_id, "endpoints": PackedStringArray([first, second])}


func _registry_report(slots: Dictionary, edges: Array) -> Dictionary:
	return {
		"schema_version": REGISTRY_SCHEMA_VERSION,
		"valid": true,
		"errors": PackedStringArray(),
		"slots": slots,
		"adjacency": {
			"edges": edges,
			"dangling_slots": PackedStringArray(),
			"overclaimed_slots": PackedStringArray(),
			"total_slots": slots.size(),
			"connected_slots": edges.size(),
			"dangling_slot_count": 0,
			"overclaimed_slot_count": 0,
		},
	}


func _two_slot_report() -> Dictionary:
	return _registry_report(
		{
			&"hub-a": [_claim(HUB_CLAIMANT_ID, &"hub-a", Vector3.ZERO), _claim(&"mod-a", &"approach", Vector3(3, 0, 0))],
			&"hub-b": [_claim(HUB_CLAIMANT_ID, &"hub-b", Vector3(0, 0, 20)), _claim(&"mod-b", &"approach", Vector3(3, 0, 20))],
		},
		[_edge(&"hub-a", "station-hub:hub-a", "mod-a:approach"), _edge(&"hub-b", "station-hub:hub-b", "mod-b:approach")]
	)


func _single_edge_report(length: float) -> Dictionary:
	return StationNavigationGraph.new().build_from_registry_report(_registry_report(
		{&"hub-a": [_claim(HUB_CLAIMANT_ID, &"hub-a", Vector3.ZERO), _claim(&"mod-a", &"approach", Vector3(length, 0, 0))]},
		[_edge(&"hub-a", "station-hub:hub-a", "mod-a:approach")]
	))


func _rejects(report: Dictionary, fragment: String) -> bool:
	var built := StationNavigationGraph.new().build_from_registry_report(report)
	return not bool(built.valid) and _errors_mention(built, fragment)


func _errors_mention(report: Dictionary, fragment: String) -> bool:
	return _has_error(report.get("errors", PackedStringArray()) as PackedStringArray, fragment)


func _has_error(errors: PackedStringArray, fragment: String) -> bool:
	for error in errors:
		if fragment in error:
			return true
	return false


func _agent_states_match(first: Dictionary, second: Dictionary) -> bool:
	return (
		(first.carriage_position as Vector3).distance_to(second.carriage_position as Vector3) <= MOTION_EPSILON
		and absf(float(first.carriage_yaw) - float(second.carriage_yaw)) <= MOTION_EPSILON
		and absf(float(first.route_distance) - float(second.route_distance)) <= MOTION_EPSILON
		and bool(first.outbound) == bool(second.outbound)
		and bool(first.status_lens_lit) == bool(second.status_lens_lit)
	)


func _descendant_instance_ids(search_root: Node) -> PackedInt64Array:
	var ids := PackedInt64Array()
	for node in search_root.find_children("*", "", true, false):
		ids.append(node.get_instance_id())
	ids.sort()
	return ids


func _world_aabb(world_transform: Transform3D, local_min: Vector3, local_max: Vector3) -> AABB:
	var bounds := AABB(world_transform * local_min, Vector3.ZERO)
	for corner_index in range(1, 8):
		var corner := Vector3(
			local_max.x if corner_index & 1 else local_min.x,
			local_max.y if corner_index & 2 else local_min.y,
			local_max.z if corner_index & 4 else local_min.z
		)
		bounds = bounds.expand(world_transform * corner)
	return bounds


func _aabbs_overlap(first: AABB, second: AABB) -> bool:
	return (
		first.position.x < second.end.x and second.position.x < first.end.x
		and first.position.y < second.end.y and second.position.y < first.end.y
		and first.position.z < second.end.z and second.position.z < first.end.z
	)


func _aabb_separation(first: AABB, second: AABB) -> float:
	var gap := Vector3(
		maxf(first.position.x - second.end.x, second.position.x - first.end.x),
		maxf(first.position.y - second.end.y, second.position.y - first.end.y),
		maxf(first.position.z - second.end.z, second.position.z - first.end.z)
	)
	return maxf(maxf(gap.x, gap.y), gap.z)


func _module_nodes(world: ShipyardWorld) -> Array[Node]:
	var result: Array[Node] = []
	for node_name in ["AftJunctionStack", "FabricationAnnex", "FleetDockComb", "HabitatSpine", "JovianFreightBerth", "ObservationLogisticsSpur", "SalvageTerrace"]:
		var module := world.get_node_or_null(NodePath(node_name))
		if module != null:
			result.append(module)
	return result


func _module_by_id(world: ShipyardWorld, module_id: StringName) -> Node:
	for module in _module_nodes(world):
		if StringName(module.get_module_id()) == module_id:
			return module
	return null


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


func _hub_anchor_transform(world: ShipyardWorld, slot_id: StringName) -> Transform3D:
	for declaration in ShipyardWorld.STATION_HUB_ENDPOINT_DECLARATIONS:
		if StringName(declaration.get("slot_id", &"")) != slot_id:
			continue
		var anchor := world.get_node_or_null(NodePath(str(declaration.get("anchor_path", "")))) as Node3D
		return anchor.global_transform if anchor != null else Transform3D.IDENTITY
	return Transform3D.IDENTITY


func _cleanup(game: GameFlow) -> void:
	game.queue_free()
	await process_frame
	await physics_frame
	await process_frame


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("STATION_NAVIGATION_GRAPH_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		print("STATION_NAVIGATION_GRAPH_TEST_FAILED: %d/%d assertions failed: %s" % [_failures.size(), _assertions, "; ".join(_failures)])
		quit(1)
