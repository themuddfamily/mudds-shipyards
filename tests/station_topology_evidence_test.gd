extends SceneTree

## Drift guard between the documented `LIVE` station graph and the real one.
##
## `docs/research/STATION_TOPOLOGY.md` is the confidence-graded floor plan. Its
## `LIVE` section used to be prose that nothing verified, and this repository has
## already been bitten twice by documentation that quietly stopped matching the
## code. This suite removes that failure mode: it drives the production
## `res://scenes/main.tscn`, reads the real `StationRouteRegistry` report and the
## real module nodes, parses the marker-delimited tables out of the document, and
## fails when the two disagree in either direction.
##
## The document is the subject under test, not an oracle: a wrong document turns
## this red exactly as loudly as wrong code does. The suite deliberately proves
## that with two structured-red mutations, one on each side of the comparison.
##
## Scope boundary: this checks *declared* topology and the evidence labels the
## document publishes. It does not prove any slot is physically walkable — that
## stays with `station_surface_playability_test.gd` and the per-module suites —
## and it authenticates no historical geometry.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const TOPOLOGY_PATH := "res://docs/research/STATION_TOPOLOGY.md"
const CONNECTION_SLOT_META: StringName = &"station_connection_slot"
const HUB_ENDPOINT_ID: StringName = &"station-hub"
const ORIGIN_TOLERANCE := 0.02

const MODULE_NODE_NAMES := [
	"AftJunctionStack", "FleetDockComb", "HabitatSpine", "JovianFreightBerth",
]

## Evidence statuses a station module is allowed to publish. Every entry either
## is `modern_interpretation` or carries it as a suffix, so no module can quietly
## start claiming a stronger Phase-1 status through this table.
const PERMITTED_MODULE_EVIDENCE_STATUSES := [
	"modern_interpretation",
	"fixed_era_inspired_modern_interpretation",
	"creator_roster_supported_modern_interpretation",
]

## Wording that would turn the graded floor plan into a recovered-original claim.
## The Phase 2 roadmap item names this boundary explicitly.
const PROHIBITED_TOPOLOGY_WORDING := [
	"recovered original segment",
	"recovered original geometry of this station",
	"authenticated station topology",
	"authenticated floor plan",
	"canonical floor plan is established",
	"reconstructed original station",
]

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var document := FileAccess.get_file_as_string(TOPOLOGY_PATH)
	_check(not document.is_empty(), "station topology document loads")

	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "production main scene instantiates for the topology evidence audit")
	if game == null or document.is_empty():
		_finish()
		return
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame

	var world := game.get_node_or_null("ShipyardWorld") as ShipyardWorld
	_check(world != null, "main scene owns the production ShipyardWorld")
	if world == null:
		await _cleanup(game)
		_finish()
		return

	var documented := _parse_document(document)
	_test_document_tables_parse(documented)
	_test_documented_graph_matches_live(documented, world)
	_test_documented_evidence_labels_stay_bounded(documented, document)
	_test_structured_red_on_documentation_drift(documented, world)
	await _test_structured_red_on_implementation_drift(documented, world)

	await _cleanup(game)
	_finish()


# 1. Every machine-checked table is present and populated. A silently emptied
#    table would otherwise let the comparison pass by comparing nothing.
func _test_document_tables_parse(documented: Dictionary) -> void:
	var totals := documented.get("totals", {}) as Dictionary
	var edges := documented.get("edges", []) as Array
	var routes := documented.get("routes", []) as Array
	var deferred := documented.get("deferred", []) as Array
	var berths := documented.get("berths", []) as Array
	_check(totals.size() == 11, "the documented totals table publishes all eleven live registry quantities")
	_check(edges.size() == 4, "the documented edge table publishes four station edges")
	_check(routes.size() == 4, "the documented route roster table publishes four modules")
	_check(deferred.size() == 5, "the documented deferred-landmark table publishes five landmarks")
	_check(berths.size() == 5, "the documented berth table publishes five production berths")


# 2. The core comparison. Any divergence is printed in full, then fails.
func _test_documented_graph_matches_live(documented: Dictionary, world: ShipyardWorld) -> void:
	var report := world.get_station_route_registry_report()
	_check(bool(report.get("valid", false)), "the live station route registry is valid before it is compared to the document")

	var divergences := _compare(documented, world, report)
	for divergence in divergences:
		print("STATION_TOPOLOGY_DRIFT: ", divergence)
	_check(
		divergences.is_empty(),
		"the documented LIVE graph matches the running station registry exactly (%d divergences)" % divergences.size()
	)


# 3. The document may record only bounded evidence labels, and may never call
#    this revision a recovered original segment.
func _test_documented_evidence_labels_stay_bounded(documented: Dictionary, document: String) -> void:
	var every_status_bounded := true
	var offending_status := ""
	for row in (documented.get("edges", []) as Array):
		var status := str((row as Dictionary).get("evidence_status", ""))
		if not PERMITTED_MODULE_EVIDENCE_STATUSES.has(status):
			every_status_bounded = false
			offending_status = status
		elif not status.ends_with("modern_interpretation"):
			every_status_bounded = false
			offending_status = status
	_check(
		every_status_bounded,
		"every documented module evidence status resolves to modern_interpretation (%s)" % offending_status
	)

	var no_prohibited_wording := true
	var offending_phrase := ""
	for phrase: String in PROHIBITED_TOPOLOGY_WORDING:
		# The document is allowed to *forbid* the phrase, which is how the roadmap
		# boundary is written down. Only an affirmative claim is a defect, so the
		# negated forms that appear in the boundary prose are excluded first.
		if not document.contains(phrase):
			continue
		if _phrase_is_only_negated(document, phrase):
			continue
		no_prohibited_wording = false
		offending_phrase = phrase
	_check(
		no_prohibited_wording,
		"the topology document never calls the present revision a recovered original segment (%s)" % offending_phrase
	)

	_check(
		document.contains("## What remains ungraded or unknown"),
		"the document keeps an explicit ungraded/unknown boundary rather than implying complete grading"
	)
	_check(
		document.contains("Adjacency in the running world is **declared, not metric**"),
		"the document states that live adjacency is declared rather than inferred from coordinates"
	)


# 4. Structured red, documentation side: a wrong document must fail.
func _test_structured_red_on_documentation_drift(documented: Dictionary, world: ShipyardWorld) -> void:
	var report := world.get_station_route_registry_report()
	_check(_compare(documented, world, report).is_empty(), "the unmutated comparison is clean before the documentation mutation")

	var mutated := _deep_copy_documented(documented)
	var edges := mutated.get("edges", []) as Array
	# Claim the fleet dock comb hangs off the aft junction slot. This is exactly
	# the drift this suite exists to catch: a plausible-looking module-to-module
	# reading that the registry never records.
	(edges[1] as Dictionary)["module_id"] = "aft-junction-stack"
	var module_drift := _compare(mutated, world, report)
	_check(not module_drift.is_empty(), "mis-documenting which module claims a slot turns the audit red")
	_check(_any_contains(module_drift, "hub-fleet-dock-comb"), "the red report names the mis-documented slot")

	mutated = _deep_copy_documented(documented)
	(mutated.get("totals", {}) as Dictionary)["route_marker_count"] = 28
	var totals_drift := _compare(mutated, world, report)
	_check(not totals_drift.is_empty(), "a stale documented route-marker total turns the audit red")
	_check(_any_contains(totals_drift, "route_marker_count"), "the red report names the stale total")

	mutated = _deep_copy_documented(documented)
	(mutated.get("edges", [])[3] as Dictionary)["evidence_status"] = "modern_interpretation"
	var status_drift := _compare(mutated, world, report)
	_check(not status_drift.is_empty(), "flattening a module's compound evidence status in the document turns the audit red")
	_check(_any_contains(status_drift, "habitat-spine"), "the red report names the module whose status was flattened")

	mutated = _deep_copy_documented(documented)
	((mutated.get("deferred", [])[0] as Dictionary))["origin"] = Vector3(-5.15, 4.35, 60.0)
	var landmark_drift := _compare(mutated, world, report)
	_check(not landmark_drift.is_empty(), "a drifted deferred-landmark coordinate turns the audit red")
	_check(_any_contains(landmark_drift, "vip-landmark"), "the red report names the drifted deferred landmark")

	mutated = _deep_copy_documented(documented)
	(mutated.get("berths", [])[3] as Dictionary)["origin"] = Vector3(22.0, 5.28, 50.0)
	var berth_drift := _compare(mutated, world, report)
	_check(not berth_drift.is_empty(), "a drifted documented berth origin turns the audit red")
	_check(_any_contains(berth_drift, "zenith_fleet_dock_berth"), "the red report names the drifted berth")

	_check(
		_compare(documented, world, report).is_empty(),
		"the unmutated documentation still compares clean after every documentation mutation"
	)


# 5. Structured red, implementation side: correct documentation plus drifted code
#    must fail too, and the world must survive the probe unharmed.
func _test_structured_red_on_implementation_drift(documented: Dictionary, world: ShipyardWorld) -> void:
	var subject := _module_by_id(world, &"habitat-spine")
	_check(subject != null, "the habitat module is available for the implementation mutation")
	if subject == null:
		return
	var marker := subject.get_route_marker(&"approach") as Node3D
	_check(
		marker != null and marker.has_meta(CONNECTION_SLOT_META),
		"the habitat approach marker declares its connection slot before mutation"
	)
	if marker == null or not marker.has_meta(CONNECTION_SLOT_META):
		return
	var original_slot: Variant = marker.get_meta(CONNECTION_SLOT_META)

	marker.remove_meta(CONNECTION_SLOT_META)
	var red_report := StationRouteRegistry.new().build_registry(_module_nodes(world), _hub_endpoints(world))
	_check(not bool(red_report.get("valid", true)), "the probe registry rejects the mutated station")
	var red_drift := _compare(documented, world, red_report)
	_check(not red_drift.is_empty(), "an implementation that stops matching the documented graph turns the audit red")
	_check(_any_contains(red_drift, "hub-starboard-habitat"), "the red report names the slot the implementation stopped claiming")

	marker.set_meta(CONNECTION_SLOT_META, original_slot)
	await process_frame
	var restored := StationRouteRegistry.new().build_registry(_module_nodes(world), _hub_endpoints(world))
	_check(bool(restored.get("valid", false)), "restoring the declaration returns the probe registry to valid")
	_check(_compare(documented, world, restored).is_empty(), "the restored station matches the document again")
	_check(
		_compare(documented, world, world.get_station_route_registry_report()).is_empty(),
		"the world's own published report was never damaged by the probe registries"
	)


# --- comparison ---------------------------------------------------------------


## Returns one line per disagreement between the documented graph and `report`.
## Empty means the document is an accurate description of the running station.
func _compare(documented: Dictionary, world: ShipyardWorld, report: Dictionary) -> PackedStringArray:
	var divergences := PackedStringArray()
	_compare_totals(documented, world, report, divergences)
	_compare_edges(documented, world, report, divergences)
	_compare_routes(documented, report, divergences)
	_compare_deferred(documented, world, divergences)
	_compare_berths(documented, world, divergences)
	return divergences


func _compare_totals(
		documented: Dictionary,
		world: ShipyardWorld,
		report: Dictionary,
		divergences: PackedStringArray
	) -> void:
	var adjacency := report.get("adjacency", {}) as Dictionary
	var documented_routes := documented.get("routes", []) as Array
	var dead_end_total := 0
	for row in documented_routes:
		dead_end_total += ((row as Dictionary).get("dead_ends", PackedStringArray()) as PackedStringArray).size()

	var live := {
		"module_count": int(report.get("module_count", -1)),
		"hub_endpoint_count": int(report.get("hub_endpoint_count", -1)),
		"connection_slot_count": int(report.get("connection_slot_count", -1)),
		"edge_count": (adjacency.get("edges", []) as Array).size(),
		"route_marker_count": int(report.get("route_marker_count", -1)),
		"resolved_route_marker_count": int(report.get("resolved_route_marker_count", -1)),
		"dangling_slot_count": int(adjacency.get("dangling_slot_count", -1)),
		"overclaimed_slot_count": int(adjacency.get("overclaimed_slot_count", -1)),
		"authority_claim_count": (report.get("authority_claims", {}) as Dictionary).size(),
		"production_berth_count": world.get_berth_ids().size(),
		"deferred_or_dead_end_route_marker_count": dead_end_total,
	}
	var totals := documented.get("totals", {}) as Dictionary
	for key: String in live:
		if not totals.has(key):
			divergences.append("totals table does not document %s" % key)
			continue
		if int(totals[key]) != int(live[key]):
			divergences.append(
				"totals table documents %s = %d but the live station reports %d" % [key, int(totals[key]), int(live[key])]
			)
	for key: String in totals:
		if not live.has(key):
			divergences.append("totals table documents unknown quantity %s" % key)


func _compare_edges(
		documented: Dictionary,
		world: ShipyardWorld,
		report: Dictionary,
		divergences: PackedStringArray
	) -> void:
	var live_edges := _live_edges(world, report)
	var documented_edges := {}
	for row_variant in (documented.get("edges", []) as Array):
		var row := row_variant as Dictionary
		var slot_id := str(row.get("slot_id", ""))
		if documented_edges.has(slot_id):
			divergences.append("edge table documents slot %s twice" % slot_id)
			continue
		documented_edges[slot_id] = row

	for slot_id: String in documented_edges:
		if not live_edges.has(slot_id):
			divergences.append("edge table documents slot %s, which the live station does not connect" % slot_id)
	for slot_id: String in live_edges:
		if not documented_edges.has(slot_id):
			divergences.append("the live station connects slot %s, which the edge table does not document" % slot_id)
			continue
		var documented_row := documented_edges[slot_id] as Dictionary
		var live_row := live_edges[slot_id] as Dictionary
		for field: String in ["hub_anchor", "module_id", "route_id", "evidence_status"]:
			var documented_value := str(documented_row.get(field, ""))
			var live_value := str(live_row.get(field, ""))
			if documented_value != live_value:
				# Name the live module as well as the slot. A field mismatch is
				# almost always investigated from the module side, and a message
				# that only names the slot sends the reader to the wrong file.
				divergences.append(
					"slot %s (live module %s) documents %s '%s' but the live station reports '%s'" % [
						slot_id, str(live_row.get("module_id", "")), field, documented_value, live_value,
					]
				)


func _compare_routes(documented: Dictionary, report: Dictionary, divergences: PackedStringArray) -> void:
	var modules := report.get("modules", {}) as Dictionary
	var documented_ids := PackedStringArray()
	for row_variant in (documented.get("routes", []) as Array):
		var row := row_variant as Dictionary
		var module_id := str(row.get("module_id", ""))
		documented_ids.append(module_id)
		var entry := modules.get(StringName(module_id), {}) as Dictionary
		if entry.is_empty():
			divergences.append("route roster documents module %s, which is not registered live" % module_id)
			continue

		var live_routes := (entry.get("route_ids", PackedStringArray()) as PackedStringArray).duplicate()
		live_routes.sort()
		var documented_routes := (row.get("routes", PackedStringArray()) as PackedStringArray).duplicate()
		documented_routes.sort()
		if documented_routes != live_routes:
			divergences.append(
				"module %s documents route markers [%s] but exposes [%s]" % [
					module_id, ", ".join(documented_routes), ", ".join(live_routes),
				]
			)

		var live_slots := entry.get("connection_slots", {}) as Dictionary
		if live_slots.size() != 1:
			divergences.append("module %s declares %d connection slots; exactly one is documented" % [module_id, live_slots.size()])
		else:
			var live_slot_route := str((live_slots.values()[0] as Dictionary).get("route_id", ""))
			if str(row.get("connection_route", "")) != live_slot_route:
				divergences.append(
					"module %s documents connection marker '%s' but declares '%s'" % [
						module_id, str(row.get("connection_route", "")), live_slot_route,
					]
				)

		for dead_end in (row.get("dead_ends", PackedStringArray()) as PackedStringArray):
			if not live_routes.has(dead_end):
				divergences.append("module %s documents dead-end marker %s, which does not exist live" % [module_id, dead_end])
	for module_id: StringName in modules.keys():
		if not documented_ids.has(String(module_id)):
			divergences.append("live module %s is not documented in the route roster" % module_id)


func _compare_deferred(documented: Dictionary, world: ShipyardWorld, divergences: PackedStringArray) -> void:
	# The route roster names the dead ends and the deferred table describes them.
	# Without this cross-check a landmark could be dropped from the deferred table
	# and silently lose its origin and gate assertions while still looking listed.
	var described := PackedStringArray()
	for row_variant in (documented.get("deferred", []) as Array):
		var row := row_variant as Dictionary
		described.append("%s/%s" % [str(row.get("module_id", "")), str(row.get("route_id", ""))])
	for row_variant in (documented.get("routes", []) as Array):
		var row := row_variant as Dictionary
		var module_id := str(row.get("module_id", ""))
		for dead_end in (row.get("dead_ends", PackedStringArray()) as PackedStringArray):
			var key := "%s/%s" % [module_id, dead_end]
			if not described.has(key):
				divergences.append("dead-end marker %s is not described in the deferred-landmark table" % key)

	for row_variant in (documented.get("deferred", []) as Array):
		var row := row_variant as Dictionary
		var module_id := StringName(str(row.get("module_id", "")))
		var route_id := StringName(str(row.get("route_id", "")))
		var module := _module_by_id(world, module_id)
		if module == null:
			divergences.append("deferred landmark documents unknown module %s" % module_id)
			continue
		var marker := module.get_route_marker(route_id) as Node3D
		if marker == null:
			divergences.append("deferred landmark %s/%s has no live route marker" % [module_id, route_id])
			continue
		if marker.has_meta(CONNECTION_SLOT_META):
			divergences.append("deferred landmark %s/%s is a live connection slot; it must stay a dead end" % [module_id, route_id])
		var documented_origin := row.get("origin", Vector3.INF) as Vector3
		if not marker.global_transform.origin.is_equal_approx(documented_origin) \
				and marker.global_transform.origin.distance_to(documented_origin) > ORIGIN_TOLERANCE:
			divergences.append(
				"deferred landmark %s/%s documents origin %s but sits at %s" % [
					module_id, route_id, documented_origin, marker.global_transform.origin,
				]
			)
		_compare_deferred_gate(row, world, divergences)


## The document names the live gate on each landmark, and the comparison runs in
## both directions. A landmark that quietly became openable is a topology change;
## so is one that quietly closed. The document therefore has to state which it is,
## and `open` is the word it states it with — that is what makes the Aft VIP row
## checkable now that `VipReceptionSuite` stands behind it.
func _compare_deferred_gate(row: Dictionary, world: ShipyardWorld, divergences: PackedStringArray) -> void:
	var gate := str(row.get("gate", ""))
	var route_id := str(row.get("route_id", ""))
	for door_path: String in ["AftJunctionStack/VIPAccess", "HabitatSpine/DeferredBranchAccess"]:
		if not gate.contains(door_path.get_file()):
			continue
		var door := world.get_node_or_null(NodePath(door_path)) as StationDoor
		if door == null:
			divergences.append("deferred landmark %s names door %s, which does not exist" % [route_id, door_path])
			continue
		var documented_open := gate.contains("door, open")
		if documented_open:
			if door.locked or door.deferred_access:
				divergences.append("landmark door %s is documented open but is locked or deferred" % door_path)
		elif not door.locked or not door.deferred_access:
			divergences.append("deferred landmark door %s is no longer locked and deferred" % door_path)

	var comb := world.get_fleet_dock_comb()
	if comb == null:
		return
	for dock_variant in comb.get_dock_roster():
		var dock := dock_variant as Dictionary
		var dock_id := str(dock.get("dock_id", ""))
		if not gate.contains(dock_id):
			continue
		var status := str(dock.get("status", ""))
		if not gate.contains(status):
			divergences.append("deferred landmark %s documents a status the live dock %s does not report (%s)" % [route_id, dock_id, status])
		if bool(dock.get("owns_berth_authority", true)):
			divergences.append("dock marker %s claims berth authority" % dock_id)
		var berth_id := str(dock.get("berth_id", ""))
		if not berth_id.is_empty() and not gate.contains(berth_id):
			divergences.append("deferred landmark %s omits the live external berth assignment %s" % [route_id, berth_id])


func _compare_berths(documented: Dictionary, world: ShipyardWorld, divergences: PackedStringArray) -> void:
	var live_ids := world.get_berth_ids()
	var documented_ids := PackedStringArray()
	for row_variant in (documented.get("berths", []) as Array):
		var row := row_variant as Dictionary
		var berth_id := StringName(str(row.get("berth_id", "")))
		documented_ids.append(String(berth_id))
		if not live_ids.has(berth_id):
			divergences.append("berth table documents %s, which the world does not own" % berth_id)
			continue
		var transform := world.get_berth_transform(berth_id)
		var documented_origin := row.get("origin", Vector3.INF) as Vector3
		if transform.origin.distance_to(documented_origin) > ORIGIN_TOLERANCE:
			divergences.append(
				"berth %s documents origin %s but sits at %s" % [berth_id, documented_origin, transform.origin]
			)
		var live_yaw := _normalized_yaw_degrees(transform)
		var documented_yaw := _normalize_degrees(float(row.get("yaw", -1.0)))
		if absf(live_yaw - documented_yaw) > 0.5:
			divergences.append(
				"berth %s documents yaw %d° but is rotated %d°" % [berth_id, int(documented_yaw), int(live_yaw)]
			)
	for berth_id in live_ids:
		if not documented_ids.has(String(berth_id)):
			divergences.append("the world owns berth %s, which the berth table does not document" % berth_id)


## Rebuilds the documented edge shape from the live report. The hub anchor is
## resolved back to a live node and re-expressed relative to `ShipyardWorld`, so
## the document is compared against real geometry rather than against the
## world's own declaration constant.
func _live_edges(world: ShipyardWorld, report: Dictionary) -> Dictionary:
	var result := {}
	var hub_endpoints := report.get("hub_endpoints", {}) as Dictionary
	var modules := report.get("modules", {}) as Dictionary
	for edge_variant in ((report.get("adjacency", {}) as Dictionary).get("edges", []) as Array):
		var edge := edge_variant as Dictionary
		var slot_id := str(edge.get("slot_id", ""))
		var module_id := ""
		var route_id := ""
		for endpoint in (edge.get("endpoints", PackedStringArray()) as PackedStringArray):
			var parts := str(endpoint).split(":")
			if parts.size() != 2 or StringName(parts[0]) == HUB_ENDPOINT_ID:
				continue
			module_id = parts[0]
			route_id = parts[1]
		var anchor_path := str((hub_endpoints.get(StringName(slot_id), {}) as Dictionary).get("anchor_path", ""))
		var anchor := root.get_node_or_null(NodePath(anchor_path)) as Node3D
		var relative_anchor := str(world.get_path_to(anchor)) if anchor != null and world.is_ancestor_of(anchor) else ""
		result[slot_id] = {
			"hub_anchor": relative_anchor,
			"module_id": module_id,
			"route_id": route_id,
			"evidence_status": str((modules.get(StringName(module_id), {}) as Dictionary).get("evidence_status", "")),
		}
	return result


# --- document parsing ---------------------------------------------------------


func _parse_document(document: String) -> Dictionary:
	var parsed := {
		"totals": {},
		"edges": [],
		"routes": [],
		"deferred": [],
		"berths": [],
	}
	for row in _table_rows(document, "LIVE-GRAPH-TOTALS"):
		if row.size() >= 2:
			(parsed["totals"] as Dictionary)[row[0]] = int(row[1])
	for row in _table_rows(document, "LIVE-GRAPH-EDGES"):
		if row.size() >= 5:
			(parsed["edges"] as Array).append({
				"slot_id": row[0],
				"hub_anchor": row[1],
				"module_id": row[2],
				"route_id": row[3],
				"evidence_status": row[4],
			})
	for row in _table_rows(document, "LIVE-GRAPH-ROUTES"):
		if row.size() >= 4:
			(parsed["routes"] as Array).append({
				"module_id": row[0],
				"routes": _split_list(row[1]),
				"connection_route": row[2],
				"dead_ends": _split_list(row[3]),
			})
	for row in _table_rows(document, "LIVE-GRAPH-DEFERRED"):
		if row.size() >= 5:
			(parsed["deferred"] as Array).append({
				"landmark": row[0],
				"module_id": row[1],
				"route_id": row[2],
				"origin": _parse_vector(row[3]),
				"gate": row[4],
			})
	for row in _table_rows(document, "LIVE-GRAPH-BERTHS"):
		if row.size() >= 3:
			(parsed["berths"] as Array).append({
				"berth_id": row[0],
				"origin": _parse_vector(row[1]),
				"yaw": float(row[2]),
			})
	return parsed


## Returns the data rows of the marker-delimited table as arrays of unwrapped
## cells. The header row and its separator are dropped; backticks are stripped so
## the document can stay readable markdown while the values stay comparable.
func _table_rows(document: String, marker: String) -> Array:
	var begin_token := "<!-- %s:BEGIN -->" % marker
	var end_token := "<!-- %s:END -->" % marker
	var begin := document.find(begin_token)
	var end := document.find(end_token)
	if begin < 0 or end <= begin:
		return []
	var block := document.substr(begin + begin_token.length(), end - begin - begin_token.length())
	var rows: Array = []
	for raw_line in block.split("\n"):
		var line := str(raw_line).strip_edges()
		if not line.begins_with("|"):
			continue
		var cells := PackedStringArray()
		var is_separator := true
		for raw_cell in line.split("|"):
			var cell := str(raw_cell).strip_edges()
			if cell.is_empty():
				continue
			cells.append(cell.replace("`", ""))
			if cell.replace("-", "").strip_edges() != "":
				is_separator = false
		if cells.is_empty() or is_separator:
			continue
		rows.append(cells)
	# The first surviving row is the column header, which is prose, not data.
	if not rows.is_empty():
		rows.remove_at(0)
	return rows


## An em dash marks a deliberately empty list, which must not become a single
## entry named "—".
func _split_list(cell: String) -> PackedStringArray:
	var result := PackedStringArray()
	if cell.strip_edges() == "—" or cell.strip_edges().is_empty():
		return result
	for entry in cell.split(","):
		var value := str(entry).strip_edges()
		if not value.is_empty():
			result.append(value)
	return result


func _parse_vector(cell: String) -> Vector3:
	var trimmed := cell.strip_edges().trim_prefix("(").trim_suffix(")")
	var parts := trimmed.split(",")
	if parts.size() != 3:
		return Vector3.INF
	return Vector3(float(parts[0]), float(parts[1]), float(parts[2]))


func _normalized_yaw_degrees(transform: Transform3D) -> float:
	return _normalize_degrees(rad_to_deg(transform.basis.get_euler().y))


func _normalize_degrees(value: float) -> float:
	var wrapped := fposmod(value, 360.0)
	# 360° and 0° are the same rotation; keep the wrap from reporting a 360°
	# difference for a berth that is simply unrotated.
	return 0.0 if is_equal_approx(wrapped, 360.0) else wrapped


# --- helpers ------------------------------------------------------------------


func _deep_copy_documented(documented: Dictionary) -> Dictionary:
	return documented.duplicate(true)


func _any_contains(values: PackedStringArray, needle: String) -> bool:
	for value in values:
		if value.contains(needle):
			return true
	return false


## True when every occurrence of `phrase` is negated by text that precedes it in
## the same clause, which is how the roadmap boundary is written down in prose.
##
## The negation has to come *before* the phrase, so a sentence that asserts the
## claim and only later contains the word "no" cannot pass. The document is
## whitespace-normalised first: this prose is hard-wrapped, and a phrase that
## straddles a line break must not escape the check.
func _phrase_is_only_negated(document: String, phrase: String) -> bool:
	var normalized := " ".join(document.split("\n", false))
	while normalized.contains("  "):
		normalized = normalized.replace("  ", " ")
	var search_from := 0
	while true:
		var found := normalized.find(phrase, search_from)
		if found < 0:
			return true
		# Clause boundaries, including the markdown cell separator so a table cell
		# cannot borrow a negation from the cell before it.
		var clause_start := 0
		for terminator: String in [".", ";", ":", "|"]:
			clause_start = maxi(clause_start, normalized.rfind(terminator, found) + 1)
		var preceding := normalized.substr(clause_start, found - clause_start).to_lower()
		var negated := false
		for negation: String in ["not ", "never ", "no ", "nor ", "cannot "]:
			if preceding.contains(negation):
				negated = true
		if not negated:
			return false
		search_from = found + phrase.length()
	return true


func _module_nodes(world: ShipyardWorld) -> Array[Node]:
	var result: Array[Node] = []
	for node_name in MODULE_NODE_NAMES:
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


func _cleanup(game: GameFlow) -> void:
	game.queue_free()
	await process_frame
	await physics_frame
	await process_frame


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("STATION_TOPOLOGY_EVIDENCE_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	print("STATION_TOPOLOGY_EVIDENCE_TEST_FAILED: %d of %d assertions failed" % [_failures.size(), _assertions])
	for failure in _failures:
		print(" - ", failure)
	quit(1)
