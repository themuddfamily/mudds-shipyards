class_name StationModuleContract
extends RefCounted

## Validation helper for station modules that participate in route/authority-aware
## module integration.
##
## The helper captures only deterministic module contracts for compatibility and
## audit tests and does not assign gameplay authority.

const SCHEMA_VERSION := 1

## Meta key a module sets on a route marker to declare it an inter-module or
## hub-facing connection endpoint. The value is the shared slot ID.
const CONNECTION_SLOT_META := &"station_connection_slot"

const REQUIRED_METHODS := [
	"get_module_id",
	"get_module_anchor",
	"get_route_ids",
	"has_route_marker",
	"get_route_marker",
	"get_route_transform",
	"get_integration_footprint",
	"get_evidence_metadata",
	"get_component_roster",
	"get_collision_contract",
	"get_authority_contract",
	"get_performance_contract",
	"set_module_enabled",
	"is_module_enabled",
	"get_lifecycle_contract",
	"get_audit_report",
	"get_validation_errors",
]


func validate_contract(module: Node) -> Dictionary:
	var errors := PackedStringArray()
	if module == null:
		errors.append("module is missing")
		return _report(StringName(""), false, errors)

	var module_id := StringName()
	var route_ids := PackedStringArray()
	var evidence := {}
	var footprint := {}
	var roster := {}
	var collision := {}
	var authority := {}
	var performance := {}
	var lifecycle := {}
	var audit := {}
	var validation := PackedStringArray()

	for method_name in REQUIRED_METHODS:
		if not module.has_method(method_name):
			errors.append("required contract method is missing: %s" % method_name)

	if not errors.is_empty():
		if module.has_method("get_route_ids"):
			route_ids = module.get_route_ids()
		if module.has_method("get_module_id"):
			module_id = module.get_module_id()
		return _report(module_id, false, errors)

	module_id = StringName(module.get_module_id())
	if module_id.is_empty():
		errors.append("module id must be a non-empty StringName")
	# The anchor has to be a Node3D specifically. A plain Node would leave callers
	# silently substituting an identity transform at the world origin.
	var anchor: Variant = module.get_module_anchor()
	if anchor == null or not is_instance_valid(anchor as Object):
		errors.append("module anchor is missing")
	elif not (anchor is Node3D):
		errors.append("module anchor is not a Node3D")
	elif not _is_finite_transform((anchor as Node3D).global_transform):
		errors.append("module anchor transform is not finite")

	route_ids = _route_id_list(module, errors)
	if route_ids.is_empty():
		errors.append("module route registry is empty")
	for route_id in route_ids:
		if not bool(module.has_route_marker(route_id)):
			errors.append("module route marker method reports missing route marker for %s" % route_id)
			continue
		var marker := module.get_route_marker(route_id) as Node
		if marker == null or not marker is Node3D:
			errors.append("route marker is missing or not a Node3D: %s" % route_id)
			continue
		var marker_transform := (marker as Node3D).global_transform
		if not _is_finite_transform(marker_transform):
			errors.append("route transform is not finite: %s" % route_id)
			continue
		# `get_route_transform` is the accessor placement code reads. It must agree
		# with the marker it claims to describe, or integration would be positioned
		# against a transform no marker actually occupies.
		var reported: Variant = module.get_route_transform(StringName(route_id))
		if not (reported is Transform3D) or not (reported as Transform3D).is_equal_approx(marker_transform):
			errors.append("get_route_transform disagrees with the route marker for %s" % route_id)

	evidence = _contract_dictionary(module, &"get_evidence_metadata", errors)
	if evidence.is_empty():
		errors.append("evidence metadata is empty")
	elif not evidence.has("evidence_status") or str(evidence.get("evidence_status", "")) == "":
		errors.append("evidence metadata is missing evidence_status")

	footprint = _contract_dictionary(module, &"get_integration_footprint", errors)
	if footprint.is_empty():
		errors.append("integration footprint is empty")
	elif not _is_finite_vector(footprint.get("local_min", Vector3.INF)):
		errors.append("integration footprint local minimum is not finite")
	elif not _is_finite_transform(footprint.get("anchor_transform", Transform3D())):
		errors.append("integration footprint anchor transform is not finite")

	roster = _contract_dictionary(module, &"get_component_roster", errors)
	if roster.is_empty():
		errors.append("component roster is empty")

	collision = _contract_dictionary(module, &"get_collision_contract", errors)
	if collision.is_empty():
		errors.append("collision contract is empty")
	authority = _contract_dictionary(module, &"get_authority_contract", errors)
	if authority.is_empty():
		errors.append("authority contract is empty")

	performance = _contract_dictionary(module, &"get_performance_contract", errors)
	if performance.is_empty():
		errors.append("performance contract is empty")

	lifecycle = _contract_dictionary(module, &"get_lifecycle_contract", errors)
	if lifecycle.is_empty():
		errors.append("lifecycle contract is empty")
	elif not lifecycle.has("enabled"):
		errors.append("lifecycle contract must expose enabled")
	elif bool(lifecycle.get("enabled", false)) != bool(module.is_module_enabled()):
		errors.append("lifecycle contract enabled flag disagrees with is_module_enabled")

	# The audit report was previously captured but never checked, so a module
	# reporting its own failure still validated clean.
	audit = _contract_dictionary(module, &"get_audit_report", errors)
	if audit.is_empty():
		errors.append("audit report is empty")
	elif audit.has("valid") and not bool(audit.get("valid", false)):
		errors.append("module audit report is not valid")

	validation = _validation_error_list(module, errors)
	if not validation.is_empty():
		errors.append("module has active validation errors")

	return _report(
		module_id,
		errors.is_empty(),
		errors,
		{
			"schema_version": SCHEMA_VERSION,
			"module_id": module_id,
			"module_valid": errors.is_empty(),
			"route_ids": route_ids.duplicate(),
			"component_roster": roster.duplicate(true),
			"collision_contract": collision.duplicate(true),
			"authority_contract": authority.duplicate(true),
			"performance_contract": performance.duplicate(true),
			"lifecycle_contract": lifecycle.duplicate(true),
			"integration_footprint": footprint.duplicate(true),
			"evidence_metadata": evidence.duplicate(true),
			"audit_report": audit.duplicate(true),
			"validation_errors": validation.duplicate(),
		}
	)


## Connection slots are declared, not inferred from coordinates. A module tags
## the route marker that faces another module or the station hub with the meta
## `station_connection_slot`, whose value is the shared slot ID both endpoints
## name. Untagged route markers are internal waypoints and never join the
## adjacency graph. Physical continuity across a slot stays the responsibility of
## the surface-playability and per-module integration suites; this helper only
## reports the declared topology.
func capture_connection_slot(module: Node, route_id: StringName) -> Dictionary:
	if module == null or route_id == &"":
		return {}
	if not module.has_method("get_route_marker"):
		return {}
	var marker := module.get_route_marker(route_id) as Node
	if marker == null or not marker is Node3D:
		return {}
	var slot_id := read_connection_slot_id(marker)
	if slot_id.is_empty():
		return {}
	var marker_transform := (marker as Node3D).global_transform
	if not _is_finite_transform(marker_transform):
		return {}
	return {
		"slot_id": slot_id,
		"transform": marker_transform,
		"route_id": route_id,
		"module_id": module.get_module_id() if module.has_method("get_module_id") else StringName(""),
	}


## Returns the declared connection slot ID for a route marker, or an empty
## StringName when the marker is an internal waypoint. A `true` value is rejected
## deliberately: a slot has to name the endpoint it pairs with.
func read_connection_slot_id(marker: Node) -> StringName:
	if marker == null or not marker.has_meta(CONNECTION_SLOT_META):
		return StringName("")
	var declared: Variant = marker.get_meta(CONNECTION_SLOT_META)
	if declared is StringName:
		return declared as StringName
	if declared is String:
		return StringName(declared as String)
	return StringName("")


# --- shared module contract surface -------------------------------------------
#
# Every station module answers the same structural questions about itself, so the
# counting lives here rather than being copied into each module. The helpers take
# the module node, the layer the module publishes its surfaces on, the module's
# own enabled flag, and - where a number is policy rather than fact - that
# module's budgets. Anything only the module can answer stays in the module: the
# caller stamps its own `schema_version`, `module_id`, and module-specific fields
# onto the returned dictionary.


## Returns every StaticBody3D the module owns. A module reports on its own
## surfaces only, so this never walks outside the module subtree.
static func collect_static_bodies(module: Node) -> Array[Node]:
	if module == null:
		return []
	return module.find_children("*", "StaticBody3D", true, false)


## The collision layer a module's static bodies must carry for the given
## lifecycle state. Disabling a module clears the layer instead of freeing the
## body, which is what keeps enable/disable identity preserving.
static func expected_collision_layer(world_layer: int, module_enabled: bool) -> int:
	return world_layer if module_enabled else 0


## Shared node census for a component roster. Callers add their own module id and
## the counts only they can answer (chairs, bunks, dock slabs, and so on).
static func build_component_roster(module: Node) -> Dictionary:
	var route_ids := PackedStringArray()
	if module.has_method("get_route_ids"):
		route_ids = PackedStringArray(module.get_route_ids())
	return {
		"route_ids": route_ids,
		"route_count": route_ids.size(),
		"mesh_instances": module.find_children("*", "MeshInstance3D", true, false).size(),
		"static_body_count": collect_static_bodies(module).size(),
		"collision_shape_count": module.find_children("*", "CollisionShape3D", true, false).size(),
	}


## Shared collision report for a module and its current lifecycle state.
static func build_collision_contract(
		module: Node,
		world_layer: int,
		module_enabled: bool
	) -> Dictionary:
	var bodies := collect_static_bodies(module)
	var shapes := module.find_children("*", "CollisionShape3D", true, false)
	var expected_layer := expected_collision_layer(world_layer, module_enabled)
	var body_paths := PackedStringArray()
	var all_layers_valid := true
	var all_masks_valid := true
	var all_shapes_enabled := true
	for raw_body in bodies:
		var body := raw_body as StaticBody3D
		body_paths.append(str(module.get_path_to(body)))
		# Compare against the layer this lifecycle state demands rather than
		# against the enabled layer alone. A body that kept the world layer
		# through a disable is exactly the mutation this field exists to catch,
		# and a form that only reports "everything matched == enabled" cannot
		# see it: with the module disabled the conjunction is already false.
		all_layers_valid = all_layers_valid and body.collision_layer == expected_layer
		all_masks_valid = all_masks_valid and body.collision_mask == 0
	# Shapes are checked across the whole module, not per static body, so a
	# disabled shape under an Area3D is reported too - `shape_count` counts them
	# the same way.
	for raw_shape in shapes:
		var shape := raw_shape as CollisionShape3D
		all_shapes_enabled = all_shapes_enabled and not shape.disabled
	body_paths.sort()
	return {
		"body_count": bodies.size(),
		"shape_count": shapes.size(),
		"active_body_count": bodies.size() if module_enabled else 0,
		"body_paths": body_paths,
		"enabled_layer": world_layer,
		"current_enabled_state": module_enabled,
		"all_layers_match_lifecycle": all_layers_valid,
		"all_masks_zero": all_masks_valid,
		"all_shapes_present_and_enabled": all_shapes_enabled,
	}


## Shared authority census. The counts are descriptive: a module never claims
## lease, spawn, or network authority, so those stay pinned at zero here and any
## module that owns extra authority state adds it to the returned dictionary.
static func build_authority_contract(module: Node) -> Dictionary:
	var node_count := 0
	var berth_count := 0
	var landing_or_interaction_area_count := 0
	var audio_node_count := 0
	var activity_node_count := 0
	for node in module.find_children("*", "", true, false):
		node_count += 1
		var script := node.get_script() as Script
		var script_path := script.resource_path if script != null else ""
		if script_path.ends_with("/ship_berth.gd"):
			berth_count += 1
		if script_path.ends_with("/station_operations_activity.gd") \
				or bool(node.get_meta("station_activity", false)):
			activity_node_count += 1
		if node is Area3D:
			landing_or_interaction_area_count += 1
		if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
			audio_node_count += 1
	return {
		# Authority identities are explicit declarations. Evidence records and
		# berth specifications describe a module; they do not grant ownership.
		"authority_ids": PackedStringArray(),
		"ship_berth_count": berth_count,
		"landing_or_interaction_area_count": landing_or_interaction_area_count,
		"audio_node_count": audio_node_count,
		"activity_node_count": activity_node_count,
		"all_nodes_checked": node_count,
		"lease_authority_count": 0,
		"spawn_authority_count": 0,
		"network_authority_role": &"none",
	}


## Shared performance report measured against the module's own budgets.
##
## `budgets` is keyed by the reported count names: mesh_instances, static_bodies,
## collision_shapes, labels, lights, process_loops, physics_process_loops. A key
## the caller omits is read as a budget of zero, so an unbudgeted cost can only
## ever fail `within_budget`, never pass unnoticed.
static func build_performance_contract(module: Node, budgets: Dictionary) -> Dictionary:
	var contract := {
		"mesh_instances": module.find_children("*", "MeshInstance3D", true, false).size(),
		"static_bodies": collect_static_bodies(module).size(),
		"collision_shapes": module.find_children("*", "CollisionShape3D", true, false).size(),
		"labels": module.find_children("*", "Label3D", true, false).size(),
		"lights": module.find_children("*", "Light3D", true, false).size(),
		# Frame and physics callbacks are counted separately: folding physics
		# into the process figure hides which loop a module actually pays for.
		"process_loops": int(module.is_processing()),
		"physics_process_loops": int(module.is_physics_processing()),
	}
	var within_budget := true
	for key: String in contract:
		within_budget = within_budget and int(contract[key]) <= int(budgets.get(key, 0))
	contract["within_budget"] = within_budget
	contract["budgets"] = budgets.duplicate(true)
	return contract


## Shared lifecycle report. `visibility_root` is the node whose visibility tracks
## the enabled flag - the module itself for modules that hide in place, or the
## generated build root for modules that keep their own node visible.
static func build_lifecycle_contract(
		module: Node,
		world_layer: int,
		module_enabled: bool,
		visibility_root: Node3D
	) -> Dictionary:
	var bodies := collect_static_bodies(module)
	var expected_layer := expected_collision_layer(world_layer, module_enabled)
	var surface_ids := PackedInt64Array()
	var collision_matches := true
	# Only the visibility root follows the enabled flag. Individual surfaces keep
	# their own visibility through a disable so re-enabling restores the module as
	# authored, which makes a surface hidden on its own a defect worth reporting
	# here - visibility is a lifecycle property, never a collision-layer one.
	var visible_matches := visibility_root != null and visibility_root.visible == module_enabled
	for raw_body in bodies:
		var body := raw_body as StaticBody3D
		surface_ids.append(body.get_instance_id())
		collision_matches = collision_matches and body.collision_layer == expected_layer
		visible_matches = visible_matches and body.visible
	return {
		"mode": &"identity_preserving_enable_disable",
		"enabled": module_enabled,
		"runtime_rebuild_allowed": false,
		"reversible": true,
		"visible_matches_enabled": visible_matches,
		"collision_matches_enabled": collision_matches,
		"process_free": not module.is_processing() and not module.is_physics_processing(),
		# A module that legitimately animates (the freight crane) can never be
		# `process_free`, but it must still stop burning frames once disabled -
		# otherwise its simulation keeps advancing behind a hidden module and
		# re-enabling snaps it to a jumped pose.
		"process_matches_lifecycle": (
			module_enabled or (not module.is_processing() and not module.is_physics_processing())
		),
		"surface_instance_ids": surface_ids,
	}


## Applies a lifecycle state to already-built module geometry. Callers pass the
## bodies they own so a module with an authoritative surface map stays in control
## of which nodes are toggled; collision masks are deliberately left untouched so
## a stray mask still shows up in the collision contract instead of being healed
## by a lifecycle toggle.
static func apply_enabled_state(
		bodies: Array,
		world_layer: int,
		module_enabled: bool,
		visibility_root: Node3D
	) -> void:
	if visibility_root != null and visibility_root.visible != module_enabled:
		visibility_root.visible = module_enabled
	var layer := expected_collision_layer(world_layer, module_enabled)
	for raw_body in bodies:
		var body := raw_body as StaticBody3D
		if body == null:
			continue
		# Write only on a real change. Reassigning an identical collision layer
		# still re-registers the body with the physics server, which reorders the
		# broadphase and flips which of two intentionally overlapping decks a ray
		# reports first - the freight connection hand-off deck overlaps
		# ConnectionDeckA at the same height by design.
		if body.collision_layer != layer:
			body.collision_layer = layer


func _report(
		module_id: StringName,
		is_valid: bool,
		errors: PackedStringArray,
		raw_contract: Dictionary = {}
	) -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"module_id": module_id,
		"valid": is_valid,
		"errors": errors.duplicate(),
		"contract": raw_contract.duplicate(true),
	}


## Variant-typed on purpose. A `Transform3D` parameter raises a hard runtime
## error when handed anything else, which aborts the caller mid-validation
## instead of recording a defect.
func _is_finite_transform(value: Variant) -> bool:
	if not (value is Transform3D):
		return false
	var transform := value as Transform3D
	return _is_finite_vector(transform.origin) and _is_finite_vector(transform.basis.get_scale())


## Every contract getter is read through here. A wrong-typed return used to be
## cast with `as Dictionary`, which yields `null`, and assigning `null` to a
## typed local aborts the calling function — so `validate_contract` returned
## `null`, the registry dropped the module without recording anything, and the
## report could still come back valid. A mistyped getter must be an error, never
## a disappearance.
func _contract_dictionary(module: Node, method_name: StringName, errors: PackedStringArray) -> Dictionary:
	var value: Variant = module.call(method_name)
	if value is Dictionary:
		return value as Dictionary
	errors.append("%s did not return a Dictionary" % method_name)
	return {}


func _route_id_list(module: Node, errors: PackedStringArray) -> PackedStringArray:
	var value: Variant = module.get_route_ids()
	if not (value is Array or value is PackedStringArray):
		errors.append("get_route_ids did not return an Array")
		return PackedStringArray()
	var result := PackedStringArray()
	for entry in value:
		result.append(str(entry))
	return result


func _validation_error_list(module: Node, errors: PackedStringArray) -> PackedStringArray:
	var value: Variant = module.get_validation_errors()
	if value is PackedStringArray:
		return value as PackedStringArray
	if value is Array:
		var result := PackedStringArray()
		for entry in (value as Array):
			result.append(str(entry))
		return result
	errors.append("get_validation_errors did not return a string array")
	return PackedStringArray()


func _is_finite_vector(value: Variant) -> bool:
	if not (value is Vector3):
		return false
	var vector := value as Vector3
	return is_finite(vector.x) and is_finite(vector.y) and is_finite(vector.z)
