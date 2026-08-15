class_name StationRouteRegistry
extends RefCounted

## Non-authoritative route registry for static station modules.
##
## The registry records declared module route slots so tests and UI can reason
## about one station graph. Adjacency is deliberately **non-metric**: endpoints
## pair by a shared slot ID that both sides name, not by comparing coordinates,
## so the graph stays stable when placement is retuned and a matching pair can
## never be manufactured by two markers drifting onto the same position.
##
## A slot ID is claimed by exactly two endpoints — either a module and a station
## hub endpoint published by `ShipyardWorld`, or two modules. One claimant is a
## dangling connection; three or more is an overclaimed slot. Both are rejected.
##
## The registry intentionally assigns no gameplay authority, and it does not
## prove the player can physically walk a slot. Physical continuity remains the
## responsibility of `station_surface_playability_test.gd` and the per-module
## integration suites.

const SCHEMA_VERSION := 2
const _CONTRACT := preload("res://scripts/world/station_module_contract.gd")

## Reserved claimant ID used for the station hub endpoints the world publishes.
## No module may register under this ID.
const HUB_ENDPOINT_ID := &"station-hub"

var _modules: Dictionary = {}
var _hub_endpoints: Dictionary = {}
var _slots: Dictionary = {}
var _authority_claims: Dictionary = {}
var _adjacency: Dictionary = {}
var _errors: PackedStringArray = []
var _contract_builder := _CONTRACT.new() as StationModuleContract


## `hub_endpoints` entries are dictionaries of `slot_id`, `anchor` (a `Node3D`
## resolved from real world geometry), `expects_module`, and `evidence_status`.
func build_registry(modules: Array[Node], hub_endpoints: Array = []) -> Dictionary:
	_modules.clear()
	_hub_endpoints.clear()
	_slots.clear()
	_authority_claims.clear()
	_adjacency.clear()
	_errors.clear()

	for endpoint in hub_endpoints:
		_register_hub_endpoint(endpoint)

	var module_order: Array[Node] = modules.duplicate()
	module_order.sort_custom(_sort_modules_by_id)
	for module in module_order:
		if module == null or not is_instance_valid(module):
			_errors.append("missing module in registry input")
			continue
		_register_module(module)

	_verify_hub_endpoint_expectations()
	_adjacency = _build_adjacency_graph()
	return get_report()


## Pure accessor. Repeated calls never re-run validation or append duplicate
## errors, so a caller may read the report as often as it likes.
func get_report() -> Dictionary:
	# `route_marker_count` is what the modules *declare*; `resolved` is what
	# actually resolved to a live Node3D. A gap means a marker went missing, which
	# is also recorded as an error, so the two must be reported separately rather
	# than letting the declared figure imply every marker was found.
	var route_marker_count := 0
	var resolved_route_marker_count := 0
	for module_id: StringName in _modules.keys():
		var module_report := _modules[module_id] as Dictionary
		route_marker_count += (module_report.get("route_ids", PackedStringArray()) as PackedStringArray).size()
		resolved_route_marker_count += int(module_report.get("resolved_route_marker_count", 0))

	return {
		"schema_version": SCHEMA_VERSION,
		"valid": _errors.is_empty(),
		"errors": _errors.duplicate(),
		"warnings": PackedStringArray(),
		"module_count": _modules.size(),
		"hub_endpoint_count": _hub_endpoints.size(),
		"connection_slot_count": _slots.size(),
		"route_marker_count": route_marker_count,
		"resolved_route_marker_count": resolved_route_marker_count,
		"modules": _clone_module_roster(),
		"hub_endpoints": _clone_hub_endpoints(),
		"slots": _clone_slots(),
		"authority_claims": _clone_authority_claims(),
		"adjacency": _adjacency.duplicate(true),
	}


func get_adjacency_graph() -> Dictionary:
	return _adjacency.duplicate(true)


func _register_hub_endpoint(raw_endpoint: Variant) -> void:
	if not (raw_endpoint is Dictionary):
		_errors.append("station hub endpoint declaration is not a dictionary")
		return
	var endpoint := raw_endpoint as Dictionary
	var slot_id := StringName(endpoint.get("slot_id", &""))
	if slot_id.is_empty():
		_errors.append("station hub endpoint is missing slot_id")
		return
	if _hub_endpoints.has(slot_id):
		_errors.append("duplicate station hub endpoint slot id: %s" % slot_id)
		return

	var expects_module := StringName(endpoint.get("expects_module", &""))
	if expects_module.is_empty():
		_errors.append("station hub endpoint %s does not name the module it expects" % slot_id)
	var evidence_status := StringName(endpoint.get("evidence_status", &""))
	if evidence_status.is_empty():
		_errors.append("station hub endpoint %s is missing evidence_status" % slot_id)

	var anchor := endpoint.get("anchor", null) as Node
	var anchor_transform := Transform3D.IDENTITY
	var anchor_path := ""
	if anchor == null or not is_instance_valid(anchor) or not (anchor is Node3D):
		_errors.append("station hub endpoint %s does not resolve to a Node3D anchor" % slot_id)
	else:
		anchor_transform = (anchor as Node3D).global_transform
		anchor_path = str((anchor as Node3D).get_path())
		if not _is_finite_transform(anchor_transform):
			_errors.append("station hub endpoint %s anchor transform is not finite" % slot_id)

	_hub_endpoints[slot_id] = {
		"slot_id": slot_id,
		"expects_module": expects_module,
		"evidence_status": evidence_status,
		"anchor_path": anchor_path,
		"anchor_transform": anchor_transform,
	}
	_claim_slot(slot_id, HUB_ENDPOINT_ID, slot_id, anchor_transform)


func _register_module(module: Node) -> void:
	var contract := _contract_builder.validate_contract(module)
	var module_id := contract.get("module_id", StringName("")) as StringName
	if contract.get("valid", false) == false:
		_errors.append(
			"%s module contract invalid for registry: %s" % [module_id, _to_sentence(contract.get("errors", PackedStringArray()))]
		)
	if module_id.is_empty():
		_errors.append("module without a valid module_id cannot be registered")
		return
	if module_id == HUB_ENDPOINT_ID:
		_errors.append("module may not register under the reserved station hub id: %s" % HUB_ENDPOINT_ID)
		return
	if _modules.has(module_id):
		_errors.append("duplicate module id: %s" % module_id)
		return

	var evidence := module.get_evidence_metadata() as Dictionary
	var evidence_status := StringName(evidence.get("evidence_status", ""))
	if evidence_status == &"":
		_errors.append("module %s is missing evidence_status" % module_id)

	var connection_plane := _get_node_transform(module, &"get_module_anchor")
	if not _is_finite_transform(connection_plane):
		_errors.append("module %s connection plane is not finite" % module_id)

	var authority_ids := _extract_authority_ids(module)
	for authority_id in authority_ids:
		var authority := StringName(authority_id)
		if _authority_claims.has(authority):
			var existing_module := _authority_claims[authority] as StringName
			if existing_module != module_id:
				_errors.append(
					"authority id %s overlaps between module %s and %s" % [authority, existing_module, module_id]
				)
		else:
			_authority_claims[authority] = module_id

	var route_ids := _get_route_ids(module)
	var connection_slots := {}
	var resolved_marker_count := 0
	for route_id: StringName in route_ids:
		var marker := _get_route_marker(module, route_id)
		if marker == null:
			_errors.append("module %s route %s has missing route marker" % [module_id, route_id])
			continue
		resolved_marker_count += 1
		var declared_slot_id := _contract_builder.read_connection_slot_id(marker)
		if declared_slot_id.is_empty():
			# An untagged route marker is an internal waypoint by design. It stays
			# in the module roster but never joins the adjacency graph.
			continue
		var slot := _contract_builder.capture_connection_slot(module, route_id)
		if slot.is_empty():
			_errors.append("module %s route %s has an invalid connection slot transform" % [module_id, route_id])
			continue
		if connection_slots.has(declared_slot_id):
			_errors.append(
				"module %s declares slot %s on more than one route marker" % [module_id, declared_slot_id]
			)
			continue
		connection_slots[declared_slot_id] = {
			"route_id": route_id,
			"transform": slot.get("transform", Transform3D.IDENTITY),
		}
		_claim_slot(declared_slot_id, module_id, route_id, slot.get("transform", Transform3D.IDENTITY))

	if connection_slots.is_empty():
		_errors.append("module %s declares no station connection slot" % module_id)

	_modules[module_id] = {
		"module_id": module_id,
		"connection_plane": connection_plane,
		"evidence_status": evidence_status,
		"route_ids": PackedStringArray(route_ids),
		"resolved_route_marker_count": resolved_marker_count,
		"connection_slots": connection_slots,
		"authority_ids": authority_ids,
		"contract": contract,
	}


func _claim_slot(slot_id: StringName, claimant_id: StringName, route_id: StringName, claim_transform: Transform3D) -> void:
	var claim := {
		"module_id": claimant_id,
		"route_id": route_id,
		"transform": claim_transform,
	}
	if _slots.has(slot_id):
		var claims := _slots[slot_id] as Array
		claims.append(claim)
		_slots[slot_id] = claims
	else:
		_slots[slot_id] = [claim]


## A hub endpoint names the module it serves, so a module tagged with the wrong
## slot ID is reported as mis-wiring rather than silently forming a valid edge.
func _verify_hub_endpoint_expectations() -> void:
	for slot_id: StringName in _hub_endpoints.keys():
		var endpoint := _hub_endpoints[slot_id] as Dictionary
		var expects_module := endpoint.get("expects_module", &"") as StringName
		if expects_module.is_empty():
			continue
		var claimed_by := PackedStringArray()
		for claim in (_slots.get(slot_id, []) as Array):
			var claimant := StringName((claim as Dictionary).get("module_id", &""))
			if claimant != HUB_ENDPOINT_ID:
				claimed_by.append(String(claimant))
		if not claimed_by.has(String(expects_module)):
			_errors.append(
				"station hub endpoint %s expects module %s but was claimed by [%s]" % [
					slot_id,
					expects_module,
					", ".join(claimed_by),
				]
			)


func _build_adjacency_graph() -> Dictionary:
	var slot_reports: Dictionary = {}
	var edges: Array = []
	var dangling_slots := PackedStringArray()
	var overclaimed_slots := PackedStringArray()

	# `Array.sort()` on StringName keys compares interned pointers, not text, so
	# it would order the graph by allocation order and shuffle it whenever an
	# unrelated script interns a slot id earlier. Compare the text explicitly.
	var slot_ids := _slots.keys()
	slot_ids.sort_custom(func(left: StringName, right: StringName) -> bool: return String(left) < String(right))
	for slot_id: StringName in slot_ids:
		var claims := _slots[slot_id] as Array
		var claim_count := claims.size()
		var endpoint_summaries := PackedStringArray()
		var claimant_modules := PackedStringArray()
		for claim in claims:
			var claimant_id := String((claim as Dictionary).get("module_id", &""))
			endpoint_summaries.append("%s:%s" % [claimant_id, String((claim as Dictionary).get("route_id", &""))])
			if not claimant_modules.has(claimant_id):
				claimant_modules.append(claimant_id)
		slot_reports[slot_id] = {
			"slot_id": slot_id,
			"claim_count": claim_count,
			"claimant_modules": claimant_modules,
			"claims": claims.duplicate(true),
			"overclaimed": false,
			"dangling": false,
		}
		if claim_count == 1:
			(slot_reports[slot_id] as Dictionary)["dangling"] = true
			dangling_slots.append(String(slot_id))
			_errors.append(
				"connection slot %s is dangling; only %s claims it" % [slot_id, endpoint_summaries[0]]
			)
		elif claim_count == 2:
			edges.append({"slot_id": slot_id, "endpoints": endpoint_summaries})
		else:
			# An overclaimed slot is a rejected state, not a usable edge. It stays
			# out of `edges` so `connected_slots` never counts a contested slot as
			# a proven connection.
			(slot_reports[slot_id] as Dictionary)["overclaimed"] = true
			overclaimed_slots.append(String(slot_id))
			_errors.append(
				"connection slot %s is claimed by more than two modules: %s" % [slot_id, endpoint_summaries]
			)

	return {
		"edges": edges,
		"slots": slot_reports,
		"dangling_slots": dangling_slots,
		"overclaimed_slots": overclaimed_slots,
		"total_slots": _slots.size(),
		"connected_slots": edges.size(),
		"dangling_slot_count": dangling_slots.size(),
		"overclaimed_slot_count": overclaimed_slots.size(),
	}


func _extract_authority_ids(module: Node) -> PackedStringArray:
	var authority_ids := PackedStringArray()
	var spec: Variant = _safe_variant(module, &"get_berth_specification")
	if spec is Dictionary and (spec as Dictionary).has("berth_id"):
		var spec_id := StringName((spec as Dictionary).get("berth_id", &""))
		if not spec_id.is_empty() and not authority_ids.has(String(spec_id)):
			authority_ids.append(String(spec_id))
	var berth_id: Variant = _safe_variant(module, &"get_berth_id")
	if berth_id is StringName and not (berth_id as StringName).is_empty():
		if not authority_ids.has(String(berth_id)):
			authority_ids.append(String(berth_id))
	return authority_ids


func _safe_variant(module: Node, method: StringName) -> Variant:
	if not module.has_method(method):
		return null
	return module.call(method)


func _get_node_transform(module: Node, method_name: StringName) -> Transform3D:
	if not module.has_method(method_name):
		return Transform3D.IDENTITY
	var anchor := module.call(method_name) as Node
	if anchor is Node3D:
		return (anchor as Node3D).global_transform
	return Transform3D.IDENTITY


func _get_route_marker(module: Node, route_id: StringName) -> Node3D:
	if not module.has_method(&"has_route_marker") or not module.has_method(&"get_route_marker"):
		return null
	if not bool(module.call(&"has_route_marker", route_id)):
		return null
	var marker: Variant = module.call(&"get_route_marker", route_id)
	if marker is Node3D:
		return marker as Node3D
	return null


func _get_route_ids(module: Node) -> Array[StringName]:
	var route_ids: Array[StringName] = []
	var values: Variant = _safe_variant(module, &"get_route_ids")
	if not (values is Array):
		return route_ids
	for value in (values as Array):
		route_ids.append(StringName(value))
	return route_ids


func _to_sentence(value: Variant) -> String:
	if value is PackedStringArray:
		return "; ".join(value as PackedStringArray)
	if value is Array:
		var parts := PackedStringArray()
		for entry in (value as Array):
			parts.append(str(entry))
		return "; ".join(parts)
	return str(value)


func _clone_slots() -> Dictionary:
	var copy := {}
	for slot_id: StringName in _slots.keys():
		copy[slot_id] = (_slots[slot_id] as Array).duplicate(true)
	return copy


func _clone_hub_endpoints() -> Dictionary:
	var copy := {}
	for slot_id: StringName in _hub_endpoints.keys():
		copy[slot_id] = (_hub_endpoints[slot_id] as Dictionary).duplicate(true)
	return copy


func _clone_authority_claims() -> Dictionary:
	var copy := {}
	for authority: StringName in _authority_claims.keys():
		copy[authority] = _authority_claims[authority]
	return copy


func _clone_module_roster() -> Dictionary:
	var roster := {}
	for module_id: StringName in _modules.keys():
		var module_data := _modules[module_id] as Dictionary
		var contract := module_data.get("contract", {}) as Dictionary
		roster[module_id] = {
			"module_id": module_id,
			"connection_plane": module_data.get("connection_plane", Transform3D.IDENTITY),
			"evidence_status": module_data.get("evidence_status", &""),
			"route_ids": (module_data.get("route_ids", PackedStringArray()) as PackedStringArray).duplicate(),
			"resolved_route_marker_count": module_data.get("resolved_route_marker_count", 0),
			"connection_slots": (module_data.get("connection_slots", {}) as Dictionary).duplicate(true),
			"authority_ids": (module_data.get("authority_ids", PackedStringArray()) as PackedStringArray).duplicate(),
			"has_contract": contract.get("valid", false),
			"contract_errors": (contract.get("errors", PackedStringArray()) as PackedStringArray).duplicate(),
		}
	return roster


func _is_finite_vector(value: Variant) -> bool:
	if not (value is Vector3):
		return false
	var vector := value as Vector3
	return is_finite(vector.x) and is_finite(vector.y) and is_finite(vector.z)


func _is_finite_transform(value: Variant) -> bool:
	if not (value is Transform3D):
		return false
	var transform := value as Transform3D
	return _is_finite_vector(transform.origin) and _is_finite_vector(transform.basis.get_scale())


func _sort_modules_by_id(left: Node, right: Node) -> bool:
	var left_has := left != null and left.has_method(&"get_module_id")
	var right_has := right != null and right.has_method(&"get_module_id")
	if not left_has and not right_has:
		return false
	if not left_has:
		return true
	if not right_has:
		return false
	return str(left.get_module_id()) < str(right.get_module_id())
