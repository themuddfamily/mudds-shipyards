extends SceneTree

## Focused suite for the station module contract and the non-metric route
## registry. Production integration lives in
## `tests/station_route_registry_integration_test.gd`; this file freezes the
## contract surface and every rejection path with synthetic probe modules.

const StationModuleContract := preload("res://scripts/world/station_module_contract.gd")
const StationRouteRegistry := preload("res://scripts/world/station_route_registry.gd")

var _failures: Array[String] = []
var _scene_nodes: Array[Node] = []


class ProbeModule extends Node:
	var _module_id: StringName = &""
	var _module_anchor: Node3D
	var _module_enabled := true
	var _evidence_metadata: Dictionary = {}
	var _validation_errors: PackedStringArray = []
	var _route_ids: Array[StringName] = []
	var _route_markers: Dictionary = {}
	var _route_markers_present: Dictionary = {}
	var _berth_id: StringName = &""
	var _component_roster: Dictionary = {}

	func _init(module_id: StringName = &"probe") -> void:
		_module_id = module_id
		_module_anchor = Marker3D.new()

	func get_module_id() -> StringName:
		return _module_id

	func get_module_anchor() -> Node:
		return _module_anchor

	func get_route_ids() -> Array[StringName]:
		return _route_ids.duplicate()

	func has_route_marker(route_id: StringName) -> bool:
		return bool(_route_markers_present.get(route_id, false))

	func get_route_marker(route_id: StringName) -> Node:
		if not has_route_marker(route_id):
			return null
		return _route_markers.get(route_id, null) as Node

	func get_route_transform(route_id: StringName) -> Transform3D:
		var marker: Node3D = _route_markers.get(route_id, null)
		if marker != null:
			return marker.global_transform
		return _module_anchor.global_transform

	func get_integration_footprint() -> Dictionary:
		return {
			"local_min": Vector3(-0.5, 0.0, -0.5),
			"anchor_transform": _module_anchor.global_transform,
		}

	func get_evidence_metadata() -> Dictionary:
		return _evidence_metadata.duplicate(true)

	## Deliberately returned by reference. The deep-copy suite needs one getter
	## that does NOT pre-detach, otherwise it would pass even if the contract
	## dropped its own copying.
	func get_component_roster() -> Dictionary:
		_component_roster["components"] = _route_ids.size()
		return _component_roster

	func get_collision_contract() -> Dictionary:
		return {"solid_shapes": 0}

	func get_authority_contract() -> Dictionary:
		return {"module_authority": _module_id}

	func get_performance_contract() -> Dictionary:
		return {"within_budget": true}

	func set_module_enabled(enabled: bool) -> void:
		_module_enabled = enabled

	func is_module_enabled() -> bool:
		return _module_enabled

	func get_lifecycle_contract() -> Dictionary:
		return {"enabled": _module_enabled}

	func get_audit_report() -> Dictionary:
		return {
			"valid": _validation_errors.is_empty(),
			"errors": _validation_errors.duplicate(),
			"evidence": get_evidence_metadata(),
		}

	func get_validation_errors() -> PackedStringArray:
		return _validation_errors.duplicate()

	func get_berth_specification() -> Dictionary:
		if _berth_id.is_empty():
			return {}
		return {"berth_id": _berth_id}

	func set_berth_id(berth_id: StringName) -> void:
		_berth_id = berth_id

	func set_evidence_metadata(value: Dictionary) -> void:
		_evidence_metadata = value

	func set_route_marker(route_id: StringName, marker: Marker3D, present: bool = true) -> void:
		if not _route_ids.has(route_id):
			_route_ids.append(route_id)
		_route_markers[route_id] = marker
		_route_markers_present[route_id] = present

	func set_route_marker_present(route_id: StringName, present: bool) -> void:
		_route_markers_present[route_id] = present

	func tag_connection_slot(route_id: StringName, slot_id: StringName) -> void:
		var marker := _route_markers.get(route_id, null) as Node3D
		if marker == null:
			return
		if slot_id.is_empty():
			marker.remove_meta(StationModuleContract.CONNECTION_SLOT_META)
			return
		marker.set_meta(StationModuleContract.CONNECTION_SLOT_META, slot_id)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var contract := StationModuleContract.new() as StationModuleContract
	var registry := StationRouteRegistry.new() as StationRouteRegistry

	_test_valid_contract(contract)
	_test_missing_evidence(contract)
	_test_nonfinite_marker(contract)
	_test_connection_slot_declaration(contract)

	_test_missing_route_marker(registry)
	_test_duplicate_module_id(registry)
	_test_untagged_markers_stay_internal(registry)
	_test_module_without_connection_slot(registry)
	_test_duplicate_slot_on_one_module(registry)
	_test_overclaimed_connection_slot(registry)
	_test_dangling_connection_slot(registry)

	_test_hub_endpoint_pairs_with_module(registry)
	_test_hub_endpoint_expectation_mismatch(registry)
	_test_hub_endpoint_invalid_anchor(registry)
	_test_duplicate_hub_endpoint_slot(registry)
	_test_reserved_hub_id_rejected(registry)

	_test_authority_overlap_between_modules(registry)
	_test_self_authority_overlap_ignored(registry)
	_test_report_is_pure(registry)
	_test_deep_copy_report_invariance(registry)
	await _test_production_reentry_world_refresh(registry)
	_test_audit_deep_copy_invariance(contract)

	_finish()


# --- contract surface -------------------------------------------------------


func _test_valid_contract(contract: StationModuleContract) -> void:
	var module := _probe_module(&"valid-contract", Vector3.ZERO, true)
	var report := contract.validate_contract(module)
	_check(
		bool(report.get("valid", false)),
		"fully populated probe module passes station_module_contract validation"
	)


func _test_missing_evidence(contract: StationModuleContract) -> void:
	var module := _probe_module(&"missing-evidence", Vector3.ZERO, false)
	var report := contract.validate_contract(module)
	_check(
		not bool(report.get("valid", false))
		and _errors_include(report.get("errors", PackedStringArray()), "evidence metadata is empty"),
		"missing evidence metadata fails contract validation"
	)


func _test_nonfinite_marker(contract: StationModuleContract) -> void:
	var module := _probe_module(&"nonfinite-marker", Vector3.INF, true)
	var report := contract.validate_contract(module)
	_check(
		not bool(report.get("valid", false))
		and _errors_include(report.get("errors", PackedStringArray()), "route transform is not finite"),
		"nonfinite route marker transform fails station_module_contract validation"
	)


## A connection slot has to name the endpoint it pairs with. A bare `true` is
## rejected so a marker can never be promoted into the graph by accident.
func _test_connection_slot_declaration(contract: StationModuleContract) -> void:
	var module := _probe_module(&"slot-declaration", Vector3.ZERO, true, &"route", true, &"")
	var marker := module.get_route_marker(&"route") as Node3D

	_check(
		contract.read_connection_slot_id(marker).is_empty(),
		"untagged route marker declares no connection slot"
	)

	marker.set_meta(StationModuleContract.CONNECTION_SLOT_META, true)
	_check(
		contract.read_connection_slot_id(marker).is_empty()
		and contract.capture_connection_slot(module, &"route").is_empty(),
		"boolean connection slot meta is rejected because it names no slot id"
	)

	marker.set_meta(StationModuleContract.CONNECTION_SLOT_META, &"declared-slot")
	var slot := contract.capture_connection_slot(module, &"route")
	_check(
		contract.read_connection_slot_id(marker) == &"declared-slot"
		and StringName(slot.get("slot_id", &"")) == &"declared-slot"
		and StringName(slot.get("route_id", &"")) == &"route"
		and StringName(slot.get("module_id", &"")) == &"slot-declaration",
		"declared connection slot captures slot id, route id and owning module"
	)


# --- registry rejection paths -----------------------------------------------


func _test_missing_route_marker(registry: StationRouteRegistry) -> void:
	var module := _probe_module(&"missing-route-marker", Vector3.ZERO, true, &"missing-route")
	module.set_route_marker_present(&"missing-route", false)
	var report := registry.build_registry([module])
	_check(
		not bool(report.get("valid", false))
		and _errors_include(report.get("errors", PackedStringArray()), "has missing route marker"),
		"missing route marker fails station_route_registry validation"
	)


func _test_duplicate_module_id(registry: StationRouteRegistry) -> void:
	var first := _probe_module(&"duplicate-id", Vector3.ZERO, true)
	var duplicate := _probe_module(&"duplicate-id", Vector3(12.0, 0.0, 0.0), true)
	var report := registry.build_registry([first, duplicate])
	_check(
		not bool(report.get("valid", false))
		and int(report.get("module_count", 0)) == 1
		and _errors_include(report.get("errors", PackedStringArray()), "duplicate module id"),
		"duplicate module id is rejected and only the first instance is retained"
	)


## Internal waypoints — stair treads, room anchors, deferred dead ends — stay in
## the module roster but must never become graph endpoints.
func _test_untagged_markers_stay_internal(registry: StationRouteRegistry) -> void:
	var module := _probe_module(&"internal-waypoints", Vector3.ZERO, true, &"approach", true, &"internal-slot")
	var waypoint := Marker3D.new()
	waypoint.position = Vector3(3.0, 0.0, 0.0)
	module.add_child(waypoint)
	module.set_route_marker(&"stair-top", waypoint)
	var dead_end := Marker3D.new()
	dead_end.position = Vector3(6.0, 0.0, 0.0)
	module.add_child(dead_end)
	module.set_route_marker(&"deferred-branch", dead_end)

	var report := registry.build_registry([module])
	var roster := (report.get("modules", {}) as Dictionary).get(&"internal-waypoints", {}) as Dictionary
	var slots := roster.get("connection_slots", {}) as Dictionary
	_check(
		int(report.get("route_marker_count", 0)) == 3
		and int(report.get("connection_slot_count", 0)) == 1
		and slots.size() == 1
		and slots.has(&"internal-slot")
		and StringName((slots[&"internal-slot"] as Dictionary).get("route_id", &"")) == &"approach",
		"untagged route markers stay internal and only the declared slot joins the graph"
	)


func _test_module_without_connection_slot(registry: StationRouteRegistry) -> void:
	var module := _probe_module(&"no-slot", Vector3.ZERO, true, &"route", true, &"")
	var report := registry.build_registry([module])
	_check(
		not bool(report.get("valid", false))
		and _errors_include(report.get("errors", PackedStringArray()), "declares no station connection slot"),
		"module that declares no connection slot is rejected"
	)


func _test_duplicate_slot_on_one_module(registry: StationRouteRegistry) -> void:
	var module := _probe_module(&"double-slot", Vector3.ZERO, true, &"approach", true, &"shared-slot")
	var second := Marker3D.new()
	second.position = Vector3(2.0, 0.0, 0.0)
	module.add_child(second)
	module.set_route_marker(&"second-approach", second)
	module.tag_connection_slot(&"second-approach", &"shared-slot")

	var report := registry.build_registry([module])
	_check(
		not bool(report.get("valid", false))
		and _errors_include(
			report.get("errors", PackedStringArray()), "declares slot shared-slot on more than one route marker"
		),
		"one module may not declare the same connection slot on two route markers"
	)


func _test_overclaimed_connection_slot(registry: StationRouteRegistry) -> void:
	var first := _probe_module(&"claim-a", Vector3(4.0, 0.0, 0.0), true, &"approach", true, &"contested-slot")
	var second := _probe_module(&"claim-b", Vector3(4.0, 0.0, 0.0), true, &"approach", true, &"contested-slot")
	var third := _probe_module(&"claim-c", Vector3(4.0, 0.0, 0.0), true, &"approach", true, &"contested-slot")
	var report := registry.build_registry([first, second, third])
	var slots := ((report.get("adjacency", {}) as Dictionary).get("slots", {}) as Dictionary)
	var contested := slots.get(&"contested-slot", {}) as Dictionary

	_check(
		not bool(report.get("valid", false))
		and _errors_include(report.get("errors", PackedStringArray()), "claimed by more than two modules"),
		"three modules sharing one connection slot is rejected"
	)
	_check(
		bool(contested.get("overclaimed", false))
		and int(contested.get("claim_count", 0)) == 3
		and int((report.get("adjacency", {}) as Dictionary).get("overclaimed_slot_count", 0)) == 1,
		"overclaimed connection slot is surfaced in the adjacency report"
	)


func _test_dangling_connection_slot(registry: StationRouteRegistry) -> void:
	var module := _probe_module(&"lonely", Vector3.ZERO, true, &"approach", true, &"unpaired-slot")
	var report := registry.build_registry([module])
	var adjacency := report.get("adjacency", {}) as Dictionary
	_check(
		not bool(report.get("valid", false))
		and _errors_include(report.get("errors", PackedStringArray()), "connection slot unpaired-slot is dangling")
		and int(adjacency.get("dangling_slot_count", 0)) == 1
		and int(adjacency.get("connected_slots", -1)) == 0,
		"a connection slot with a single claimant is reported as dangling"
	)


# --- station hub endpoints --------------------------------------------------


func _test_hub_endpoint_pairs_with_module(registry: StationRouteRegistry) -> void:
	var module := _probe_module(&"hub-paired", Vector3.ZERO, true, &"approach", true, &"hub-slot")
	var report := registry.build_registry([module], [_hub_endpoint(&"hub-slot", &"hub-paired")])
	var adjacency := report.get("adjacency", {}) as Dictionary
	var edges := adjacency.get("edges", []) as Array
	var endpoints := PackedStringArray()
	if not edges.is_empty():
		endpoints = (edges[0] as Dictionary).get("endpoints", PackedStringArray())

	_check(
		bool(report.get("valid", false))
		and int(report.get("hub_endpoint_count", 0)) == 1
		and edges.size() == 1
		and int(adjacency.get("dangling_slot_count", -1)) == 0
		and endpoints.has("station-hub:hub-slot")
		and endpoints.has("hub-paired:approach"),
		"a hub endpoint and a module claiming the same slot form one valid edge"
	)


func _test_hub_endpoint_expectation_mismatch(registry: StationRouteRegistry) -> void:
	var module := _probe_module(&"actual-module", Vector3.ZERO, true, &"approach", true, &"hub-slot")
	var report := registry.build_registry([module], [_hub_endpoint(&"hub-slot", &"expected-module")])
	_check(
		not bool(report.get("valid", false))
		and _errors_include(
			report.get("errors", PackedStringArray()),
			"expects module expected-module but was claimed by [actual-module]"
		),
		"a module tagged with another module's hub slot is reported as mis-wiring"
	)


func _test_hub_endpoint_invalid_anchor(registry: StationRouteRegistry) -> void:
	var module := _probe_module(&"anchorless", Vector3.ZERO, true, &"approach", true, &"hub-slot")
	var endpoint := _hub_endpoint(&"hub-slot", &"anchorless")
	endpoint["anchor"] = null
	var report := registry.build_registry([module], [endpoint])
	_check(
		not bool(report.get("valid", false))
		and _errors_include(
			report.get("errors", PackedStringArray()), "does not resolve to a Node3D anchor"
		),
		"a hub endpoint without real world geometry is rejected"
	)


func _test_duplicate_hub_endpoint_slot(registry: StationRouteRegistry) -> void:
	var module := _probe_module(&"twice-served", Vector3.ZERO, true, &"approach", true, &"hub-slot")
	var report := registry.build_registry(
		[module],
		[_hub_endpoint(&"hub-slot", &"twice-served"), _hub_endpoint(&"hub-slot", &"twice-served")]
	)
	_check(
		not bool(report.get("valid", false))
		and _errors_include(
			report.get("errors", PackedStringArray()), "duplicate station hub endpoint slot id"
		)
		and int(report.get("hub_endpoint_count", 0)) == 1,
		"two hub endpoints may not declare the same connection slot"
	)


func _test_reserved_hub_id_rejected(registry: StationRouteRegistry) -> void:
	var module := _probe_module(
		StationRouteRegistry.HUB_ENDPOINT_ID, Vector3.ZERO, true, &"approach", true, &"hub-slot"
	)
	var report := registry.build_registry([module])
	_check(
		not bool(report.get("valid", false))
		and int(report.get("module_count", 0)) == 0
		and _errors_include(
			report.get("errors", PackedStringArray()), "may not register under the reserved station hub id"
		),
		"a module may not impersonate the station hub endpoint id"
	)


# --- authority --------------------------------------------------------------


func _test_authority_overlap_between_modules(registry: StationRouteRegistry) -> void:
	var first := _probe_module(&"berth-owner", Vector3.ZERO, true, &"approach", true, &"slot-one")
	first.set_berth_id(&"contested_berth")
	var second := _probe_module(&"berth-thief", Vector3(9.0, 0.0, 0.0), true, &"approach", true, &"slot-two")
	second.set_berth_id(&"contested_berth")

	var report := registry.build_registry([first, second])
	_check(
		not bool(report.get("valid", false))
		and _errors_include(
			report.get("errors", PackedStringArray()), "authority id contested_berth overlaps between module"
		),
		"two modules claiming one berth authority id is rejected"
	)


func _test_self_authority_overlap_ignored(registry: StationRouteRegistry) -> void:
	var module := _probe_module(&"authority-self", Vector3(6.0, 0.0, 0.0), true, &"route-one", true, &"slot-one")
	module.set_berth_id(&"own_berth")
	var second_marker := Marker3D.new()
	second_marker.position = Vector3(7.5, 0.0, 0.0)
	module.add_child(second_marker)
	module.set_route_marker(&"route-two", second_marker)
	module.tag_connection_slot(&"route-two", &"slot-two")

	var report := registry.build_registry([module])
	_check(
		not _errors_include(report.get("errors", PackedStringArray()), "authority id")
		and int(report.get("module_count", 0)) == 1
		and int(report.get("connection_slot_count", 0)) == 2,
		"a single module with two connection slots does not self-overlap on authority claims"
	)


# --- report isolation -------------------------------------------------------


## `get_report()` is a pure accessor. Reading it must never re-run validation,
## which previously appended a second copy of every error on each call.
func _test_report_is_pure(registry: StationRouteRegistry) -> void:
	var module := _probe_module(&"pure-report", Vector3.ZERO, true, &"approach", true, &"unpaired")
	var first := registry.build_registry([module])
	var first_errors := (first.get("errors", PackedStringArray()) as PackedStringArray).size()
	registry.get_report()
	var third := registry.get_report()
	_check(
		first_errors > 0
		and (third.get("errors", PackedStringArray()) as PackedStringArray).size() == first_errors
		and int(third.get("connection_slot_count", -1)) == int(first.get("connection_slot_count", -2)),
		"repeated get_report calls do not re-run validation or duplicate errors"
	)


func _test_deep_copy_report_invariance(registry: StationRouteRegistry) -> void:
	var first := _probe_module(&"copy-a", Vector3.ZERO, true, &"approach", true, &"shared-copy-slot")
	var second := _probe_module(&"copy-b", Vector3(5.0, 0.0, 0.0), true, &"approach", true, &"shared-copy-slot")
	var baseline := registry.build_registry([first, second])

	var baseline_slots := (baseline.get("modules", {}) as Dictionary).get(&"copy-a", {}) as Dictionary
	var baseline_route_id := StringName(
		((baseline_slots.get("connection_slots", {}) as Dictionary).get(&"shared-copy-slot", {}) as Dictionary)
			.get("route_id", &"")
	)
	(baseline_slots.get("connection_slots", {}) as Dictionary)[&"shared-copy-slot"] = {"route_id": &"tampered"}

	var baseline_adjacency := (baseline.get("adjacency", {}) as Dictionary).get("slots", {}) as Dictionary
	var tampered_slot := baseline_adjacency.get(&"shared-copy-slot", {}) as Dictionary
	tampered_slot["claim_count"] = 0
	tampered_slot["claims"] = []
	(baseline.get("adjacency", {}) as Dictionary)["edges"] = []

	var refresh := registry.get_report()
	var refresh_route_id := StringName(
		(((refresh.get("modules", {}) as Dictionary).get(&"copy-a", {}) as Dictionary)
			.get("connection_slots", {}) as Dictionary)
			.get(&"shared-copy-slot", {}).get("route_id", &"")
	)
	var refresh_slots := (refresh.get("adjacency", {}) as Dictionary).get("slots", {}) as Dictionary
	var refresh_slot := refresh_slots.get(&"shared-copy-slot", {}) as Dictionary

	_check(
		baseline_route_id == &"approach" and refresh_route_id == &"approach",
		"connection slot records in deep copies do not leak back into roster state"
	)
	_check(
		int(refresh_slot.get("claim_count", -1)) == 2
		and (refresh_slot.get("claims", []) as Array).size() == 2
		and ((refresh.get("adjacency", {}) as Dictionary).get("edges", []) as Array).size() == 1,
		"adjacency metadata in deep copies remains isolated from caller mutation"
	)


func _test_production_reentry_world_refresh(registry: StationRouteRegistry) -> void:
	var stale_world := Node3D.new()
	var broken_module := _probe_module(&"world-refresh", Vector3.ZERO, false, &"approach", false, &"refresh-slot")
	stale_world.add_child(broken_module)
	root.add_child(stale_world)
	await process_frame

	var stale_report := registry.build_registry([broken_module], [_hub_endpoint(&"refresh-slot", &"world-refresh")])
	_check(
		not bool(stale_report.get("valid", false))
		and _errors_include(stale_report.get("errors", PackedStringArray()), "evidence metadata is empty"),
		"pre-refresh build catches module-level evidence defects"
	)

	root.remove_child(stale_world)

	var refreshed_world := Node3D.new()
	var fresh_module := _probe_module(
		&"world-refresh", Vector3(8.0, 0.0, 0.0), true, &"approach", false, &"refresh-slot"
	)
	refreshed_world.add_child(fresh_module)
	root.add_child(refreshed_world)
	await process_frame

	var reentered := registry.build_registry([fresh_module], [_hub_endpoint(&"refresh-slot", &"world-refresh")])
	_check(
		bool(reentered.get("valid", false))
		and (reentered.get("errors", PackedStringArray()) as PackedStringArray).is_empty(),
		"world refresh rebuild does not carry stale defects from the previous build"
	)
	_check(
		int(reentered.get("module_count", 0)) == 1
		and int(reentered.get("connection_slot_count", 0)) == 1
		and ((reentered.get("adjacency", {}) as Dictionary).get("edges", []) as Array).size() == 1,
		"world refresh rebuild preserves the rebuilt roster and its hub edge"
	)

	root.remove_child(refreshed_world)
	refreshed_world.queue_free()
	stale_world.queue_free()


## `get_component_roster()` is the one probe getter that hands out its live
## dictionary, so tampering with the reported copy proves the contract's own
## deep copy is what protects module state — not the module's defensiveness.
func _test_audit_deep_copy_invariance(contract: StationModuleContract) -> void:
	var module := _probe_module(&"audit-copy", Vector3.ZERO, true)
	var baseline := contract.validate_contract(module).get("contract", {}) as Dictionary
	var reported_roster := baseline.get("component_roster", {}) as Dictionary
	reported_roster["components"] = -999
	reported_roster["tampered"] = true
	(baseline.get("evidence_metadata", {}) as Dictionary)["evidence_status"] = &"tampered"

	_check(
		not module._component_roster.has("tampered")
		and int(module._component_roster.get("components", -1)) == 1,
		"mutating the reported component roster cannot reach the module's live dictionary"
	)

	var fresh_contract := contract.validate_contract(module).get("contract", {}) as Dictionary
	_check(
		str((fresh_contract.get("evidence_metadata", {}) as Dictionary).get("evidence_status", "")) == "modern_interpretation"
		and not bool((fresh_contract.get("component_roster", {}) as Dictionary).get("tampered", false)),
		"a fresh contract report is unaffected by tampering with an earlier one"
	)


# --- helpers ----------------------------------------------------------------


func _probe_module(
		module_name: StringName,
		marker_position: Vector3,
		valid_evidence: bool,
		route_id: StringName = &"route",
		attach_to_scene: bool = true,
		slot_id: StringName = &"probe-slot",
) -> ProbeModule:
	var module := ProbeModule.new(module_name)
	var marker := Marker3D.new()
	marker.position = marker_position
	module.set_route_marker(route_id, marker)
	module.add_child(module._module_anchor)
	module.add_child(marker)
	if valid_evidence:
		module.set_evidence_metadata({
			"schema_version": 1,
			"evidence_status": &"modern_interpretation",
		})
	else:
		module.set_evidence_metadata({})
	if not slot_id.is_empty():
		module.tag_connection_slot(route_id, slot_id)
	if attach_to_scene:
		root.add_child(module)
	_scene_nodes.append(module)
	return module


func _hub_endpoint(slot_id: StringName, expects_module: StringName) -> Dictionary:
	var anchor := Marker3D.new()
	root.add_child(anchor)
	_scene_nodes.append(anchor)
	return {
		"slot_id": slot_id,
		"expects_module": expects_module,
		"evidence_status": &"modern_interpretation",
		"anchor": anchor,
	}


func _errors_include(errors: Variant, fragment: String) -> bool:
	for candidate in (errors as PackedStringArray):
		if fragment in str(candidate):
			return true
	return false


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_push_failure(description)


func _push_failure(description: String) -> void:
	_failures.append(description)
	push_error("FAIL: " + description)


func _finish() -> void:
	for node in _scene_nodes:
		if not is_instance_valid(node):
			continue
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		node.queue_free()

	if _failures.is_empty():
		print("STATION_MODULE_CONTRACT_TEST_OK")
		quit(0)
	else:
		print("STATION_MODULE_CONTRACT_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
