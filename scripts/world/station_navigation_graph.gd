class_name StationNavigationGraph
extends RefCounted

## Non-authoritative navigation graph derived from the station route registry.
##
## This type deliberately owns **no topology of its own**. Every node and every
## edge is read out of the `StationRouteRegistry` report `ShipyardWorld` already
## publishes, so the station keeps exactly one declared graph. A node is one slot
## claim (`<claimant>:<route_id>`); an edge is one connection slot that the
## registry accepted as connected — the station hub on one side and exactly one
## module on the other. Nothing here measures coordinates to invent adjacency,
## and nothing here promotes an internal waypoint, a deferred landmark, or a dock
## threshold into a route.
##
## The graph assigns no gameplay authority. It cannot reserve a berth, grant a
## lease, spawn or regenerate a craft, resolve damage, or open a door, and a
## resolved route is not proof that the player can physically walk it. Physical
## continuity stays with `station_surface_playability_test.gd` and the per-module
## integration suites; this graph only answers "which declared endpoints connect,
## and in what order".
##
## Everything the graph produces is `modern_interpretation`: it authenticates no
## original station logistics, traffic pattern, or service route.

const SCHEMA_VERSION := 1
const EVIDENCE_STATUS: StringName = &"modern_interpretation"

## The registry report schema this consumer understands. A registry that moves
## to a new schema must be re-reviewed here rather than silently reinterpreted.
const SUPPORTED_REGISTRY_SCHEMA_VERSION := 2

## Reserved claimant ID the world publishes its hub endpoints under. Mirrored
## from `StationRouteRegistry` so a caller never has to hard-code the literal.
const HUB_CLAIMANT_ID: StringName = StationRouteRegistry.HUB_ENDPOINT_ID

## Bounded edge geometry. A declared connection slot spans one connector the
## player crosses, so an edge far outside this band means placement drifted and
## the graph refuses to route over it rather than sending an agent across the
## station interior.
const MINIMUM_EDGE_LENGTH := 0.25
const MAXIMUM_EDGE_LENGTH := 24.0

## Guard against a pathological registry. The live station declares four slots;
## this ceiling exists so a malformed report cannot make route search unbounded.
const MAXIMUM_NODES := 256
const MAXIMUM_ROUTE_HOPS := 16

const CONTENT_NOTE := (
	"Station navigation reuses the declared, non-metric route registry rather than "
	+ "a second topology. Which endpoints connect is a modern remake decision recorded "
	+ "by the modules and the world; no original station route, traffic pattern, "
	+ "logistics workflow, or service schedule is authenticated by this graph."
)

var _nodes: Dictionary = {}
var _edges: Dictionary = {}
var _neighbours: Dictionary = {}
var _components: Array = []
var _errors: PackedStringArray = []
var _built := false


## Builds the graph from one `StationRouteRegistry.get_report()` dictionary.
## Returns the same report `get_report()` would return.
func build_from_registry_report(raw_report: Variant) -> Dictionary:
	_reset()
	if not (raw_report is Dictionary):
		_errors.append("station route registry report is missing or not a dictionary")
		return get_report()
	var report := raw_report as Dictionary
	if report.is_empty():
		_errors.append("station route registry report is empty")
		return get_report()
	var registry_schema := int(report.get("schema_version", 0))
	if registry_schema != SUPPORTED_REGISTRY_SCHEMA_VERSION:
		_errors.append(
			"unsupported station route registry schema %d (expected %d)" % [
				registry_schema,
				SUPPORTED_REGISTRY_SCHEMA_VERSION,
			]
		)
		return get_report()
	# A rejected station graph must not become a routable one. Building nodes out
	# of a registry that already recorded dangling, duplicated, or overclaimed
	# slots would let an agent traverse exactly the topology the registry refused.
	if not bool(report.get("valid", false)):
		_errors.append("station route registry report is invalid; navigation refuses to route over a rejected graph")
		return get_report()

	var slots: Variant = report.get("slots", null)
	if not (slots is Dictionary):
		_errors.append("station route registry report does not publish a slot table")
		return get_report()
	var adjacency: Variant = report.get("adjacency", null)
	if not (adjacency is Dictionary):
		_errors.append("station route registry report does not publish an adjacency graph")
		return get_report()

	_build_nodes(slots as Dictionary)
	_build_edges(adjacency as Dictionary)
	_build_module_internal_edges()
	_mirror_rejected_slots(adjacency as Dictionary)
	_components = _build_components()
	_built = _errors.is_empty()
	if not _built:
		# A partially built graph must not answer routes. Keep the recorded errors
		# and drop the derived structure so `find_route` fails closed.
		_nodes.clear()
		_edges.clear()
		_neighbours.clear()
		_components.clear()
	return get_report()


## Pure accessor. Repeated calls never re-run validation or append duplicate
## errors, so a caller may read the report as often as it likes.
func get_report() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": _built and _errors.is_empty(),
		"errors": _errors.duplicate(),
		"node_count": _nodes.size(),
		"edge_count": _edges.size(),
		"component_count": _components.size(),
		"node_ids": get_node_ids(),
		"edge_ids": get_edge_ids(),
		"nodes": _nodes.duplicate(true),
		"edges": _edges.duplicate(true),
		"neighbours": _clone_neighbours(),
		"components": _components.duplicate(true),
		"bounds": {
			"minimum_edge_length": MINIMUM_EDGE_LENGTH,
			"maximum_edge_length": MAXIMUM_EDGE_LENGTH,
			"maximum_nodes": MAXIMUM_NODES,
			"maximum_route_hops": MAXIMUM_ROUTE_HOPS,
		},
		"authority": {
			"owns_berth_authority": false,
			"owns_lease_authority": false,
			"owns_spawn_or_regeneration_authority": false,
			"owns_combat_authority": false,
			"owns_interaction_authority": false,
			"proves_physical_traversability": false,
		},
		"evidence": get_evidence_metadata(),
	}


func get_evidence_metadata() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"evidence_status": EVIDENCE_STATUS,
		"source_bounded": true,
		"derived_from": &"station_route_registry",
		"authenticated_original_routes": false,
		"authenticated_original_logistics": false,
		"authenticated_original_traffic": false,
		"content_note": CONTENT_NOTE,
	}


func is_built() -> bool:
	return _built


func get_errors() -> PackedStringArray:
	return _errors.duplicate()


func get_node_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for node_id: StringName in _nodes.keys():
		ids.append(String(node_id))
	ids.sort()
	return ids


func get_edge_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for edge_id: StringName in _edges.keys():
		ids.append(String(edge_id))
	ids.sort()
	return ids


func has_node_id(node_id: StringName) -> bool:
	return _nodes.has(node_id)


func get_node_record(node_id: StringName) -> Dictionary:
	var record: Variant = _nodes.get(node_id, null)
	return (record as Dictionary).duplicate(true) if record is Dictionary else {}


func get_edge_record(edge_id: StringName) -> Dictionary:
	var record: Variant = _edges.get(edge_id, null)
	return (record as Dictionary).duplicate(true) if record is Dictionary else {}


func get_neighbour_ids(node_id: StringName) -> PackedStringArray:
	var neighbours: Variant = _neighbours.get(node_id, null)
	return (neighbours as PackedStringArray).duplicate() if neighbours is PackedStringArray else PackedStringArray()


## Deterministic breadth-first route between two declared endpoints.
##
## Neighbours are visited in sorted text order, so an identical registry always
## produces an identical route regardless of dictionary iteration order. The
## result is a report, never a mutable reference into graph state.
func find_route(from_node_id: StringName, to_node_id: StringName) -> Dictionary:
	var errors := PackedStringArray()
	if not _built:
		errors.append("navigation graph is not built")
	if from_node_id.is_empty() or to_node_id.is_empty():
		errors.append("route endpoints must both be named")
	elif from_node_id == to_node_id:
		errors.append("route endpoints must be distinct: %s" % from_node_id)
	if _built:
		if not from_node_id.is_empty() and not _nodes.has(from_node_id):
			errors.append("unknown route origin: %s" % from_node_id)
		if not to_node_id.is_empty() and not _nodes.has(to_node_id):
			errors.append("unknown route destination: %s" % to_node_id)
	if not errors.is_empty():
		return _route_report(errors, PackedStringArray(), PackedStringArray())

	var previous: Dictionary = {}
	var visited: Dictionary = {from_node_id: true}
	var queue: Array[StringName] = [from_node_id]
	var cursor := 0
	var found := false
	while cursor < queue.size():
		var current := queue[cursor]
		cursor += 1
		if current == to_node_id:
			found = true
			break
		for raw_neighbour in get_neighbour_ids(current):
			var neighbour := StringName(raw_neighbour)
			if visited.has(neighbour):
				continue
			visited[neighbour] = true
			previous[neighbour] = current
			queue.append(neighbour)
	if not found:
		errors.append("no declared station route connects %s to %s" % [from_node_id, to_node_id])
		return _route_report(errors, PackedStringArray(), PackedStringArray())

	var reversed_ids: Array[StringName] = [to_node_id]
	var walker := to_node_id
	while walker != from_node_id:
		walker = previous[walker] as StringName
		reversed_ids.append(walker)
		if reversed_ids.size() > MAXIMUM_ROUTE_HOPS + 1:
			errors.append("resolved route exceeds the bounded hop ceiling of %d" % MAXIMUM_ROUTE_HOPS)
			return _route_report(errors, PackedStringArray(), PackedStringArray())
	reversed_ids.reverse()
	var node_ids := PackedStringArray()
	for entry in reversed_ids:
		node_ids.append(String(entry))

	var edge_ids := PackedStringArray()
	for index in range(node_ids.size() - 1):
		var edge_id := _find_edge_between(StringName(node_ids[index]), StringName(node_ids[index + 1]))
		if edge_id.is_empty():
			errors.append("resolved route hop %s -> %s has no declared edge" % [node_ids[index], node_ids[index + 1]])
			return _route_report(errors, PackedStringArray(), PackedStringArray())
		edge_ids.append(String(edge_id))
	return _route_report(errors, node_ids, edge_ids)


func _route_report(
		errors: PackedStringArray,
		node_ids: PackedStringArray,
		edge_ids: PackedStringArray
	) -> Dictionary:
	var waypoints := PackedVector3Array()
	var transforms: Array[Transform3D] = []
	var length := 0.0
	if errors.is_empty():
		for node_id in node_ids:
			var record := _nodes.get(StringName(node_id), {}) as Dictionary
			var node_transform := record.get("transform", Transform3D.IDENTITY) as Transform3D
			transforms.append(node_transform)
			waypoints.append(node_transform.origin)
		for index in range(waypoints.size() - 1):
			length += waypoints[index].distance_to(waypoints[index + 1])
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors.duplicate(),
		"node_ids": node_ids.duplicate(),
		"edge_ids": edge_ids.duplicate(),
		"waypoints": waypoints.duplicate(),
		"transforms": transforms.duplicate(),
		"hop_count": maxi(node_ids.size() - 1, 0),
		"length": length,
		"proves_physical_traversability": false,
	}


func _reset() -> void:
	_nodes.clear()
	_edges.clear()
	_neighbours.clear()
	_components.clear()
	_errors.clear()
	_built = false


func _build_nodes(slots: Dictionary) -> void:
	var slot_ids := slots.keys()
	# StringName comparison sorts by interned pointer, which would order the graph
	# by allocation order. Compare the text so the roster is stable.
	slot_ids.sort_custom(func(left, right) -> bool: return str(left) < str(right))
	for raw_slot_id in slot_ids:
		var slot_id := StringName(raw_slot_id)
		var claims: Variant = slots[raw_slot_id]
		if not (claims is Array):
			_errors.append("connection slot %s does not publish a claim list" % slot_id)
			continue
		for raw_claim in (claims as Array):
			if not (raw_claim is Dictionary):
				_errors.append("connection slot %s contains a malformed claim" % slot_id)
				continue
			var claim := raw_claim as Dictionary
			var claimant_id := StringName(claim.get("module_id", &""))
			var route_id := StringName(claim.get("route_id", &""))
			if claimant_id.is_empty() or route_id.is_empty():
				_errors.append("connection slot %s claim is missing a claimant or route id" % slot_id)
				continue
			var claim_transform: Variant = claim.get("transform", null)
			if not _is_finite_transform(claim_transform):
				_errors.append("connection slot %s claim %s has a non-finite transform" % [slot_id, claimant_id])
				continue
			var node_id := StringName("%s:%s" % [claimant_id, route_id])
			if _nodes.has(node_id):
				_errors.append("duplicate navigation node id: %s" % node_id)
				continue
			if _nodes.size() >= MAXIMUM_NODES:
				_errors.append("navigation graph exceeds the bounded node ceiling of %d" % MAXIMUM_NODES)
				return
			_nodes[node_id] = {
				"node_id": node_id,
				"claimant_id": claimant_id,
				"route_id": route_id,
				"slot_id": slot_id,
				"is_hub_endpoint": claimant_id == HUB_CLAIMANT_ID,
				"transform": claim_transform as Transform3D,
			}
			_neighbours[node_id] = PackedStringArray()


func _build_edges(adjacency: Dictionary) -> void:
	var raw_edges: Variant = adjacency.get("edges", null)
	if not (raw_edges is Array):
		_errors.append("station adjacency graph does not publish an edge list")
		return
	for raw_edge in (raw_edges as Array):
		if not (raw_edge is Dictionary):
			_errors.append("station adjacency graph contains a malformed edge")
			continue
		var edge := raw_edge as Dictionary
		var edge_id := StringName(edge.get("slot_id", &""))
		if edge_id.is_empty():
			_errors.append("station adjacency edge is missing its slot id")
			continue
		if _edges.has(edge_id):
			_errors.append("duplicate navigation edge id: %s" % edge_id)
			continue
		var endpoints: Variant = edge.get("endpoints", null)
		var endpoint_ids := PackedStringArray()
		if endpoints is PackedStringArray:
			endpoint_ids = (endpoints as PackedStringArray).duplicate()
		elif endpoints is Array:
			for entry in (endpoints as Array):
				endpoint_ids.append(str(entry))
		if endpoint_ids.size() != 2:
			_errors.append("station adjacency edge %s does not name exactly two endpoints" % edge_id)
			continue
		var first := StringName(endpoint_ids[0])
		var second := StringName(endpoint_ids[1])
		if not _nodes.has(first) or not _nodes.has(second):
			_errors.append("station adjacency edge %s names an endpoint with no navigation node" % edge_id)
			continue
		if first == second:
			_errors.append("station adjacency edge %s connects an endpoint to itself" % edge_id)
			continue
		var first_record := _nodes[first] as Dictionary
		var second_record := _nodes[second] as Dictionary
		var hub_count := int(bool(first_record.is_hub_endpoint)) + int(bool(second_record.is_hub_endpoint))
		if hub_count != 1:
			# The world owns placement and therefore one half of every connection.
			# Two modules or two hub endpoints on one edge would bypass that.
			_errors.append("station adjacency edge %s must join exactly one station hub endpoint to one module" % edge_id)
			continue
		var first_origin := (first_record.transform as Transform3D).origin
		var second_origin := (second_record.transform as Transform3D).origin
		var edge_length := first_origin.distance_to(second_origin)
		if edge_length < MINIMUM_EDGE_LENGTH or edge_length > MAXIMUM_EDGE_LENGTH:
			_errors.append(
				"station adjacency edge %s spans %.3f m, outside the bounded %.2f-%.2f m connector band" % [
					edge_id,
					edge_length,
					MINIMUM_EDGE_LENGTH,
					MAXIMUM_EDGE_LENGTH,
				]
			)
			continue
		var hub_node_id := first if bool(first_record.is_hub_endpoint) else second
		var module_node_id := second if bool(first_record.is_hub_endpoint) else first
		_edges[edge_id] = {
			"edge_id": edge_id,
			"kind": &"connection_slot",
			"slot_id": edge_id,
			"hub_node_id": hub_node_id,
			"module_node_id": module_node_id,
			"node_ids": PackedStringArray([String(first), String(second)]),
			"length": edge_length,
		}
		_link(first, second)
		_link(second, first)


## A module that declares two connection slots links them, because a module is
## one bounded, contiguous, audited footprint and both endpoints are published by
## that same body.
##
## The station hub is deliberately **not** collapsed the same way. It is the
## whole open lattice with intentional voids, so joining its four endpoints would
## manufacture routes straight through the station interior that nothing
## declares. The live station therefore resolves to one component per connection
## slot; that is the honest consequence of the declared topology, not a defect.
func _build_module_internal_edges() -> void:
	var nodes_by_claimant: Dictionary = {}
	for raw_node_id in get_node_ids():
		var node_id := StringName(raw_node_id)
		var record := _nodes[node_id] as Dictionary
		if bool(record.is_hub_endpoint):
			continue
		var claimant := record.claimant_id as StringName
		var members := nodes_by_claimant.get(claimant, PackedStringArray()) as PackedStringArray
		members.append(raw_node_id)
		nodes_by_claimant[claimant] = members
	var claimants := nodes_by_claimant.keys()
	claimants.sort_custom(func(left, right) -> bool: return str(left) < str(right))
	for raw_claimant in claimants:
		var members := nodes_by_claimant[raw_claimant] as PackedStringArray
		if members.size() < 2:
			continue
		for first_index in members.size():
			for second_index in range(first_index + 1, members.size()):
				var first := StringName(members[first_index])
				var second := StringName(members[second_index])
				var first_origin := ((_nodes[first] as Dictionary).transform as Transform3D).origin
				var second_origin := ((_nodes[second] as Dictionary).transform as Transform3D).origin
				var edge_length := first_origin.distance_to(second_origin)
				if edge_length < MINIMUM_EDGE_LENGTH or edge_length > MAXIMUM_EDGE_LENGTH:
					_errors.append(
						"module %s internal link %s spans %.3f m, outside the bounded %.2f-%.2f m band" % [
							raw_claimant,
							"%s|%s" % [members[first_index], members[second_index]],
							edge_length,
							MINIMUM_EDGE_LENGTH,
							MAXIMUM_EDGE_LENGTH,
						]
					)
					continue
				var edge_id := StringName("%s::%s+%s" % [
					raw_claimant,
					(_nodes[first] as Dictionary).route_id,
					(_nodes[second] as Dictionary).route_id,
				])
				if _edges.has(edge_id):
					_errors.append("duplicate navigation edge id: %s" % edge_id)
					continue
				_edges[edge_id] = {
					"edge_id": edge_id,
					"kind": &"module_internal",
					"slot_id": StringName(""),
					"hub_node_id": StringName(""),
					"module_node_id": StringName(raw_claimant),
					"node_ids": PackedStringArray([members[first_index], members[second_index]]),
					"length": edge_length,
				}
				_link(first, second)
				_link(second, first)


func _mirror_rejected_slots(adjacency: Dictionary) -> void:
	for key: String in ["dangling_slots", "overclaimed_slots"]:
		var rejected: Variant = adjacency.get(key, null)
		if rejected is PackedStringArray:
			for slot_id in (rejected as PackedStringArray):
				_errors.append("station adjacency reports a %s connection slot: %s" % [key.trim_suffix("_slots"), slot_id])
		elif rejected is Array:
			for slot_id in (rejected as Array):
				_errors.append("station adjacency reports a %s connection slot: %s" % [key.trim_suffix("_slots"), str(slot_id)])


func _link(from_node_id: StringName, to_node_id: StringName) -> void:
	var neighbours := _neighbours.get(from_node_id, PackedStringArray()) as PackedStringArray
	if neighbours.has(String(to_node_id)):
		return
	neighbours.append(String(to_node_id))
	neighbours.sort()
	_neighbours[from_node_id] = neighbours


func _build_components() -> Array:
	var components: Array = []
	var seen: Dictionary = {}
	for raw_node_id in get_node_ids():
		var node_id := StringName(raw_node_id)
		if seen.has(node_id):
			continue
		var member_ids := PackedStringArray()
		var queue: Array[StringName] = [node_id]
		seen[node_id] = true
		var cursor := 0
		while cursor < queue.size():
			var current := queue[cursor]
			cursor += 1
			member_ids.append(String(current))
			for raw_neighbour in get_neighbour_ids(current):
				var neighbour := StringName(raw_neighbour)
				if seen.has(neighbour):
					continue
				seen[neighbour] = true
				queue.append(neighbour)
		member_ids.sort()
		components.append({
			"component_id": member_ids[0] if not member_ids.is_empty() else "",
			"node_ids": member_ids,
			"node_count": member_ids.size(),
		})
	components.sort_custom(func(left, right) -> bool:
		return str((left as Dictionary).component_id) < str((right as Dictionary).component_id)
	)
	return components


func _find_edge_between(first: StringName, second: StringName) -> StringName:
	for edge_id: StringName in _edges.keys():
		var edge := _edges[edge_id] as Dictionary
		var node_ids := edge.get("node_ids", PackedStringArray()) as PackedStringArray
		if node_ids.has(String(first)) and node_ids.has(String(second)):
			return edge_id
	return StringName("")


func _clone_neighbours() -> Dictionary:
	var copy := {}
	for node_id: StringName in _neighbours.keys():
		copy[node_id] = (_neighbours[node_id] as PackedStringArray).duplicate()
	return copy


## Variant-typed on purpose. A `Transform3D` parameter raises a hard runtime
## error when handed anything else, which aborts the caller mid-validation
## instead of recording a defect.
func _is_finite_transform(value: Variant) -> bool:
	if not (value is Transform3D):
		return false
	var transform := value as Transform3D
	return _is_finite_vector(transform.origin) and _is_finite_vector(transform.basis.get_scale())


func _is_finite_vector(value: Variant) -> bool:
	if not (value is Vector3):
		return false
	var vector := value as Vector3
	return is_finite(vector.x) and is_finite(vector.y) and is_finite(vector.z)
