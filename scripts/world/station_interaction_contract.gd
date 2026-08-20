class_name StationInteractionContract
extends RefCounted

## Read-only acceptance contract for the station's embodied interaction layer.
##
## `StationRouteRegistry` proves only declared adjacency.  This companion
## contract checks the live marker metadata, deferred presentation landmarks,
## and the geometric relationship between a route marker and a StationDoor's
## interaction volume.  It intentionally owns no topology or gameplay state:
## callers can run it repeatedly against a live world without reindexing or
## mutating that world.

const SCHEMA_VERSION := 1
const PLAYER_INTERACTION_REACH_METRES := 2.35
const _MODULE_CONTRACT := preload("res://scripts/world/station_module_contract.gd")


func audit(world: Node) -> Dictionary:
	var errors := PackedStringArray()
	var module_reports: Dictionary = {}
	var marker_reports: Array[Dictionary] = []
	var door_reports: Array[Dictionary] = []
	var deferred_reports: Array[Dictionary] = []
	if world == null or not is_instance_valid(world):
		errors.append("station world is missing")
		return _report(errors, module_reports, marker_reports, door_reports, deferred_reports)

	var registry := {}
	if world.has_method("get_station_route_registry_report"):
		registry = world.get_station_route_registry_report() as Dictionary
	else:
		errors.append("station world does not publish a route registry report")
	if not bool(registry.get("valid", false)):
		errors.append("station route registry is invalid")

	var modules := _collect_modules(world)
	var registry_modules := registry.get("modules", {}) as Dictionary
	var seen_marker_instances: Dictionary = {}
	for module in modules:
		var module_id := StringName(module.call("get_module_id"))
		var module_errors := PackedStringArray()
		var route_ids := _route_ids(module)
		if module_id.is_empty():
			module_errors.append("module id is empty")
		if not registry_modules.has(module_id):
			module_errors.append("module is absent from the published route registry")
		else:
			var registry_module := registry_modules[module_id] as Dictionary
			var registry_route_ids := PackedStringArray(registry_module.get("route_ids", PackedStringArray()))
			var registry_route_text := PackedStringArray()
			for raw_registry_route in registry_route_ids:
				registry_route_text.append(str(raw_registry_route))
			registry_route_text.sort()
			var live_route_text := PackedStringArray()
			for live_route_id in route_ids:
				live_route_text.append(String(live_route_id))
			live_route_text.sort()
			if registry_route_text != live_route_text:
				module_errors.append("published route roster disagrees with the live module")
			if int(registry_module.get("resolved_route_marker_count", -1)) != route_ids.size():
				module_errors.append("published resolved route-marker count drifted")

		var local_marker_count := 0
		for route_id in route_ids:
			var marker := _route_marker(module, route_id)
			if marker == null:
				module_errors.append("route marker is missing: %s" % route_id)
				continue
			local_marker_count += 1
			var marker_errors := PackedStringArray()
			# Older production modules publish the marker through their typed route
			# API without stamping the optional metadata. If metadata is present it
			# must agree, but the API itself remains the source of identity.
			if marker.has_meta("route_id") and StringName(marker.get_meta("route_id", &"")) != route_id:
				marker_errors.append("route marker id metadata disagrees")
			if not marker.global_transform.is_finite():
				marker_errors.append("route marker transform is not finite")
			var instance_id := marker.get_instance_id()
			if seen_marker_instances.has(instance_id):
				marker_errors.append("route marker instance is published more than once")
			else:
				seen_marker_instances[instance_id] = true
			var slot_id := _MODULE_CONTRACT.new().read_connection_slot_id(marker)
			if bool(marker.get_meta("deferred_connection_route", false)):
				if not slot_id.is_empty():
					marker_errors.append("deferred internal route claims a connection slot")
				if StringName(marker.get_meta("connection_status", &"")) != &"internal_route_only_no_geometry":
					marker_errors.append("deferred internal route status is not explicit")
				deferred_reports.append({
					"kind": &"deferred_connection_route",
					"module_id": module_id,
					"route_id": route_id,
					"marker_path": str(marker.get_path()),
					"transform": marker.global_transform,
					"errors": marker_errors.duplicate(),
				})
			if marker_errors.size() > 0:
				module_errors.append("route %s: %s" % [route_id, "; ".join(marker_errors)])
			marker_reports.append({
				"module_id": module_id,
				"route_id": route_id,
				"marker_path": str(marker.get_path()),
				"transform": marker.global_transform,
				"connection_slot": slot_id,
				"errors": marker_errors.duplicate(),
			})

		module_reports[module_id] = {
			"module_id": module_id,
			"route_count": local_marker_count,
			"errors": module_errors.duplicate(),
			"valid": module_errors.is_empty(),
		}
		if not module_errors.is_empty():
			errors.append("module %s: %s" % [module_id, "; ".join(module_errors)])

	var doors := world.find_children("*", "StationDoor", true, false)
	for raw_door in doors:
		var door := raw_door as StationDoor
		if door == null or not is_instance_valid(door):
			continue
		var owner_id := _owner_module_id(door, world)
		var door_errors := PackedStringArray()
		if owner_id.is_empty() or not module_reports.has(owner_id):
			door_errors.append("door is not owned by a registered route module")
		if door.collision_layer != StationDoor.INTERACTION_LAYER or door.collision_mask != 0:
			door_errors.append("door interaction layer/mask is not passive layer 8 / mask 0")
		if door.monitoring or not door.monitorable:
			door_errors.append("door must be externally detectable and not monitor itself")
		if not door.global_transform.is_finite():
			door_errors.append("door transform is not finite")
		var shape_node := door.get_node_or_null(^"InteractionShape") as CollisionShape3D
		if shape_node == null or shape_node.shape == null:
			door_errors.append("door interaction shape is missing")

		var nearest_route_id := StringName("")
		var nearest_distance := INF
		var reachable := false
		for marker_report in marker_reports:
			if StringName(marker_report.get("module_id", &"")) != owner_id:
				continue
			var route_id := StringName(marker_report.get("route_id", &""))
			var marker := _route_marker_by_id(_module_for_id(modules, owner_id), route_id)
			if marker == null:
				continue
			var distance := _distance_to_interaction_volume(door, shape_node, marker.global_position)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_route_id = route_id
			if distance <= PLAYER_INTERACTION_REACH_METRES + 0.001:
				reachable = true
		if nearest_route_id.is_empty():
			door_errors.append("door has no route marker in its owning module")
		elif not reachable:
			door_errors.append(
				"door interaction volume is outside %.2f m player reach of every route marker (nearest %.3f m)"
				% [PLAYER_INTERACTION_REACH_METRES, nearest_distance]
			)

		var deferred := door.deferred_access
		var prompt := door.get_interaction_prompt()
		if deferred:
			if door.can_interact():
				door_errors.append("deferred door advertises interaction eligibility")
			if prompt.find("DEFERRED") < 0:
				door_errors.append("deferred door prompt does not disclose deferred access")
		elif not door.locked and not door.can_interact():
			door_errors.append("operable door does not advertise interaction eligibility")
		if prompt.is_empty():
			door_errors.append("current door has no interaction prompt")
		if not door_errors.is_empty():
			errors.append("door %s: %s" % [door.get_path(), "; ".join(door_errors)])
		door_reports.append({
			"path": str(door.get_path()),
			"module_id": owner_id,
			"deferred_access": deferred,
			"nearest_route_id": nearest_route_id,
			"nearest_distance_m": nearest_distance,
			"reachable_with_player_sphere": reachable,
			"prompt": prompt,
			"valid": door_errors.is_empty(),
			"errors": door_errors.duplicate(),
		})

	# Deferred dock landmarks are intentionally not doors.  Discover them from
	# their explicit marker metadata so a newly added deferred dock cannot become
	# an accidental registry endpoint or acquire berth/landing authority.
	for marker in world.find_children("*", "Marker3D", true, false):
		if not bool(marker.get_meta("deferred_dock", false)):
			continue
		var marker_errors := PackedStringArray()
		var slot_id := _MODULE_CONTRACT.new().read_connection_slot_id(marker)
		if not slot_id.is_empty():
			marker_errors.append("deferred dock claims a station connection slot")
		if StringName(marker.get_meta("dock_status", &"")) != &"deferred_empty":
			marker_errors.append("deferred dock status is not deferred_empty")
		if StringName(marker.get_meta("ship_assignment", &"")) != &"none":
			marker_errors.append("deferred dock has a ship assignment")
		if bool(marker.get_meta("owns_berth_authority", true)):
			marker_errors.append("deferred dock owns berth authority")
		deferred_reports.append({
			"kind": &"deferred_dock",
			"module_id": _owner_module_id(marker, world),
			"dock_id": StringName(marker.get_meta("dock_id", &"")),
			"marker_path": str(marker.get_path()),
			"transform": marker.global_transform,
			"errors": marker_errors.duplicate(),
		})
		if not marker_errors.is_empty():
			errors.append("deferred dock %s: %s" % [marker.get_path(), "; ".join(marker_errors)])

	return _report(errors, module_reports, marker_reports, door_reports, deferred_reports)


func _report(
	errors: PackedStringArray,
	module_reports: Dictionary,
	marker_reports: Array[Dictionary],
	door_reports: Array[Dictionary],
	deferred_reports: Array[Dictionary]
) -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors.duplicate(),
		"module_count": module_reports.size(),
		"route_marker_count": marker_reports.size(),
		"door_count": door_reports.size(),
		"reachable_door_count": _count_reachable_doors(door_reports),
		"deferred_landmark_count": deferred_reports.size(),
		"modules": module_reports.duplicate(true),
		"route_markers": marker_reports.duplicate(true),
		"doors": door_reports.duplicate(true),
		"deferred_landmarks": deferred_reports.duplicate(true),
		"player_interaction_reach_m": PLAYER_INTERACTION_REACH_METRES,
		"owns_topology": false,
		"owns_interaction_authority": false,
		"derived_from": &"live_station_route_registry_and_station_doors",
	}.duplicate(true)


func _count_reachable_doors(doors: Array[Dictionary]) -> int:
	var result := 0
	for door in doors:
		if bool(door.get("reachable_with_player_sphere", false)):
			result += 1
	return result


func _collect_modules(world: Node) -> Array[Node]:
	var result: Array[Node] = []
	for candidate in world.find_children("*", "", true, false):
		if candidate.has_method("get_module_id") and candidate.has_method("get_route_ids") \
				and candidate.has_method("get_route_marker"):
			result.append(candidate)
	result.sort_custom(func(a: Node, b: Node) -> bool:
		return String(a.call("get_module_id")) < String(b.call("get_module_id"))
	)
	return result


func _module_for_id(modules: Array[Node], module_id: StringName) -> Node:
	for module in modules:
		if StringName(module.call("get_module_id")) == module_id:
			return module
	return null


func _route_ids(module: Node) -> Array[StringName]:
	var result: Array[StringName] = []
	for raw_id in module.call("get_route_ids") as Array:
		var route_id := StringName(raw_id)
		if not route_id.is_empty() and not result.has(route_id):
			result.append(route_id)
	result.sort()
	return result


func _route_marker(module: Node, route_id: StringName) -> Node3D:
	var marker: Variant = module.call("get_route_marker", route_id)
	return marker as Node3D if marker is Node3D else null


func _route_marker_by_id(module: Node, route_id: StringName) -> Node3D:
	return _route_marker(module, route_id) if module != null else null


func _owner_module_id(node: Node, world: Node) -> StringName:
	var cursor := node.get_parent()
	while cursor != null and cursor != world:
		if cursor.has_method("get_module_id"):
			return StringName(cursor.call("get_module_id"))
		cursor = cursor.get_parent()
	return StringName("")


func _distance_to_interaction_volume(
		door: StationDoor,
		shape_node: CollisionShape3D,
		world_point: Vector3
) -> float:
	if shape_node == null or shape_node.shape == null:
		return INF
	var local_point := door.to_local(world_point)
	if shape_node.shape is BoxShape3D:
		var box := shape_node.shape as BoxShape3D
		var half := box.size * 0.5
		var relative := local_point - shape_node.position
		var closest := Vector3(
			clampf(relative.x, -half.x, half.x),
			clampf(relative.y, -half.y, half.y),
			clampf(relative.z, -half.z, half.z)
		)
		return relative.distance_to(closest)
	return door.global_position.distance_to(world_point)
