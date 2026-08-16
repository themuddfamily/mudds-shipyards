class_name StationWalkableAreaCensus
extends SceneTree

## Deterministic usable-area census for the production station.
##
## Area comes only from explicitly declared, enabled BoxShape3D walking
## collision. Level surfaces report their horizontal top-face area. Ramps report
## both horizontal projection and true inclined top-face area. Fixtures do not
## subtract from the gross circulation envelope, while roofs, ceilings, ships,
## vehicles, nearby-sector geometry, decorative tops, and void are absent from
## the declaration roster and therefore contribute zero. Coplanar handoff laps
## are geometrically unioned in the production profile so no footprint is
## counted twice; raw per-surface areas remain visible for audit.

const SCHEMA_VERSION := 1
const PROFILE_ID := &"production_station_walkable_collision_v1"
const WORLD_LAYER := 1
const SUPPORT_SAMPLE_INSET := 0.32
const SUPPORT_RAY_ABOVE := 0.12
const SUPPORT_RAY_BELOW := 0.24
const MINIMUM_UP_DOT := 0.55
const LEVEL_UP_DOT := 0.999
const OVERLAP_ELEVATION_TOLERANCE := 0.04
const OVERLAP_AXIS_TOLERANCE := 0.0001

const WORLD_SCENE := preload("res://scenes/world/shipyard_world.tscn")

## Current production declarations. Dynamically tagged surfaces are merged into
## this roster, allowing later station modules to participate without this tool
## learning their implementation paths. FleetDockComb already publishes
## `walkable_surface` metadata and is intentionally discovered that way.
const PRODUCTION_SURFACES := [
	# ShipyardWorld-owned lattice, berths, launch deck and operations floors.
	[&"shipyard_world", &"central-junction", "ExposedDockLattice/CentralJunction", &"level"],
	[&"shipyard_world", &"hero-berth-node", "ExposedDockLattice/HeroBerthNode", &"level"],
	[&"shipyard_world", &"junction-link", "ExposedDockLattice/JunctionLink", &"level"],
	[&"shipyard_world", &"port-branch-arm", "ExposedDockLattice/PortBranchArm", &"level"],
	[&"shipyard_world", &"port-berth-node", "ExposedDockLattice/PortBerthNode", &"level"],
	[&"shipyard_world", &"starboard-branch-arm", "ExposedDockLattice/StarboardBranchArm", &"level"],
	[&"shipyard_world", &"starboard-berth-node", "ExposedDockLattice/StarboardBerthNode", &"level"],
	[&"shipyard_world", &"aft-spine", "ExposedDockLattice/AftSpine", &"level"],
	[&"shipyard_world", &"aft-module-connector", "ExposedDockLattice/AftModuleConnector", &"level"],
	[&"shipyard_world", &"fleet-comb-connector", "ExposedDockLattice/FleetDockCombConnector/FleetDockCombConnectorDeck", &"level"],
	[&"shipyard_world", &"halyard-apron-nose", "ExposedDockLattice/HalyardBerthApron/HalyardApronNose", &"level"],
	[&"shipyard_world", &"halyard-apron-tail-port", "ExposedDockLattice/HalyardBerthApron/HalyardApronTailPort", &"level"],
	[&"shipyard_world", &"halyard-apron-tail-starboard", "ExposedDockLattice/HalyardBerthApron/HalyardApronTailStarboard", &"level"],
	[&"shipyard_world", &"launch-arm-deck", "OpenLaunchSpine/LaunchArmDeck", &"level"],
	[&"shipyard_world", &"observation-landing", "UpperOperations/ObservationLanding", &"level"],
	[&"shipyard_world", &"junction-access-ramp", "UpperOperations/JunctionAccessRamp", &"ramp"],
	[&"shipyard_world", &"operations-pod-floor", "UpperOperations/OperationsPodFloor", &"level"],
	[&"shipyard_world", &"registry-pod-deck", "ModernFleetRegistry/RegistryPodDeck", &"level"],

	# Aft Junction Stack.
	[&"aft_junction_stack", &"connection-deck", "AftJunctionStack/Structure/LowerOpenDeck/ConnectionDeck", &"level"],
	[&"aft_junction_stack", &"junction-deck", "AftJunctionStack/Structure/LowerOpenDeck/JunctionDeck", &"level"],
	[&"aft_junction_stack", &"stair-base-landing", "AftJunctionStack/Structure/LowerOpenDeck/StairBaseLanding", &"level"],
	[&"aft_junction_stack", &"continuous-stair-ramp", "AftJunctionStack/Structure/Circulation/ContinuousStairRamp", &"ramp"],
	[&"aft_junction_stack", &"upper-floor", "AftJunctionStack/Structure/UpperOpenDeck/UpperFloor", &"level"],
	[&"aft_junction_stack", &"operations-floor", "AftJunctionStack/Structure/OperationsRoom/OperationsFloor", &"level"],

	# Habitat Spine.
	[&"habitat_spine", &"connector-floor", "HabitatSpine/Structure/PlayerClearConnector/ConnectorFloor", &"level"],
	[&"habitat_spine", &"entry-vestibule-floor", "HabitatSpine/Structure/PressurizedHabitatCorridor/EntryVestibuleFloor", &"level"],
	[&"habitat_spine", &"habitat-floor", "HabitatSpine/Structure/PressurizedHabitatCorridor/HabitatFloor", &"level"],
	[&"habitat_spine", &"common-floor", "HabitatSpine/Structure/ObservationCommon/CommonFloor", &"level"],
	[&"habitat_spine", &"garden-link-floor", "HabitatSpine/Structure/SideBranchGarden/BranchLink/LinkFloor", &"level"],
	[&"habitat_spine", &"garden-floor", "HabitatSpine/Structure/SideBranchGarden/GardenShell/GardenFloor", &"level"],

	# Jovian freight station module (the parked ship and its interior are not
	# descendants of these paths and are excluded).
	[&"jovian_freight_berth", &"connection-deck-a", "JovianFreightBerth/ConnectionLattice/ConnectionDeckA", &"level"],
	[&"jovian_freight_berth", &"connection-deck-b", "JovianFreightBerth/ConnectionLattice/ConnectionDeckB", &"level"],
	[&"jovian_freight_berth", &"connection-deck-c", "JovianFreightBerth/ConnectionLattice/ConnectionDeckC", &"level"],
	[&"jovian_freight_berth", &"connection-handoff-deck", "JovianFreightBerth/ConnectionLattice/ConnectionHandoffDeck", &"level"],
	[&"jovian_freight_berth", &"apron-deck-01", "JovianFreightBerth/LoadingApron/ApronDeck01", &"level"],
	[&"jovian_freight_berth", &"apron-deck-02", "JovianFreightBerth/LoadingApron/ApronDeck02", &"level"],
	[&"jovian_freight_berth", &"apron-deck-03", "JovianFreightBerth/LoadingApron/ApronDeck03", &"level"],
	[&"jovian_freight_berth", &"apron-deck-04", "JovianFreightBerth/LoadingApron/ApronDeck04", &"level"],
	[&"jovian_freight_berth", &"cargo-rack-shelf", "JovianFreightBerth/LoadingApron/CargoRackShelf", &"level"],
	[&"jovian_freight_berth", &"service-room-shelf", "JovianFreightBerth/LoadingApron/ServiceRoomShelf", &"level"],
	[&"jovian_freight_berth", &"room-floor", "JovianFreightBerth/FreightControlRoom/RoomFloor", &"level"],

	# VIP Reception. The two well-entry boxes occupy projection already owned by
	# WellPan, so they are circulation fixtures, not extra square metres.
	[&"vip_reception_suite", &"threshold-floor", "VipReceptionSuite/Structure/Threshold/ThresholdFloor", &"level"],
	[&"vip_reception_suite", &"floor-plate-front", "VipReceptionSuite/Structure/Reception/FloorPlateFront", &"level"],
	[&"vip_reception_suite", &"floor-plate-rear", "VipReceptionSuite/Structure/Reception/FloorPlateRear", &"level"],
	[&"vip_reception_suite", &"floor-plate-port", "VipReceptionSuite/Structure/Reception/FloorPlatePort", &"level"],
	[&"vip_reception_suite", &"floor-plate-starboard", "VipReceptionSuite/Structure/Reception/FloorPlateStarboard", &"level"],
	[&"vip_reception_suite", &"well-pan", "VipReceptionSuite/Structure/Reception/WellPan", &"level"],
]


func _init() -> void:
	call_deferred("_run_cli")


func _run_cli() -> void:
	var world := WORLD_SCENE.instantiate() as Node3D
	if world == null:
		push_error("STATION_WALKABLE_AREA_CENSUS_FAILED: production world did not instantiate")
		quit(1)
		return
	root.add_child(world)
	await process_frame
	await physics_frame
	await physics_frame
	var report := measure_production(world, world.get_world_3d().direct_space_state)
	for row: Dictionary in report.rows:
		print(format_row(row))
	print("STATION_WALKABLE_AREA_AGGREGATE_JSON=", canonical_aggregate_json(report))
	world.queue_free()
	await process_frame
	if bool(report.valid):
		print("STATION_WALKABLE_AREA_CENSUS_OK")
		quit(0)
	else:
		for error: String in report.errors:
			push_error(error)
		print("STATION_WALKABLE_AREA_CENSUS_FAILED")
		quit(1)


static func measure_production(
		world: Node3D,
		space: PhysicsDirectSpaceState3D = null
	) -> Dictionary:
	var declarations: Array[Dictionary] = []
	for spec: Array in PRODUCTION_SURFACES:
		declarations.append({
			"owner": spec[0],
			"surface_id": spec[1],
			"path": NodePath(spec[2]),
			"kind": spec[3],
			"source": &"baseline_roster",
		})
	return measure(world, declarations, space, true, true)


static func measure(
		root_node: Node3D,
		declarations: Array[Dictionary],
		space: PhysicsDirectSpaceState3D = null,
		include_tagged: bool = false,
		union_coplanar_handoffs: bool = false
	) -> Dictionary:
	var errors := PackedStringArray()
	var merged := declarations.duplicate(true)
	if include_tagged:
		_merge_tagged_surfaces(root_node, merged, errors)

	var seen_ids := {}
	var seen_paths := {}
	var rows: Array[Dictionary] = []
	for declaration: Dictionary in merged:
		var owner := StringName(str(declaration.get("owner", "")))
		var surface_id := StringName(str(declaration.get("surface_id", "")))
		var path := NodePath(str(declaration.get("path", "")))
		var kind := StringName(str(declaration.get("kind", "")))
		var identity := "%s/%s" % [owner, surface_id]
		if owner.is_empty() or surface_id.is_empty() or path.is_empty():
			errors.append("invalid declaration requires owner, surface_id, and path")
			continue
		if seen_ids.has(identity):
			errors.append("duplicate surface identity: %s" % identity)
			continue
		seen_ids[identity] = true
		var path_text := String(path)
		if seen_paths.has(path_text):
			errors.append("one collision body declared more than once: %s" % path_text)
			continue
		seen_paths[path_text] = true

		var body := root_node.get_node_or_null(path) as StaticBody3D
		if body == null:
			errors.append("missing declared surface: %s -> %s" % [identity, path])
			continue
		var collision := _single_enabled_box_collision(body, errors, identity)
		if collision == null:
			continue
		if body.collision_layer & WORLD_LAYER == 0 or body.collision_mask != 0:
			errors.append("unsupported collision policy: %s" % identity)

		var geometry := _measure_box_top(collision)
		var up_dot := float(geometry.up_dot)
		if up_dot < MINIMUM_UP_DOT:
			errors.append("declared surface is too steep to stand on: %s" % identity)
			continue
		var inferred_kind := &"level" if up_dot >= LEVEL_UP_DOT else &"ramp"
		if kind.is_empty():
			kind = inferred_kind
		if kind not in [&"level", &"ramp"]:
			errors.append("unknown surface kind for %s: %s" % [identity, kind])
			continue
		if kind != inferred_kind:
			errors.append("surface kind disagrees with live collision normal: %s" % identity)

		var supported_samples := _physics_support_count(geometry.sample_points, space)
		if space != null and supported_samples == 0:
			errors.append("no representative live physics support: %s" % identity)
		rows.append({
			"owner": String(owner),
			"surface_id": String(surface_id),
			"path": path_text,
			"kind": String(kind),
			"projected_horizontal_m2": _rounded(float(geometry.projected_horizontal_m2)),
			"true_surface_m2": _rounded(float(geometry.true_surface_m2)),
			"top_center": _rounded_vector3(geometry.top_center),
			"up_dot": _rounded(up_dot),
			"support_samples": supported_samples,
			"support_samples_total": (geometry.sample_points as Array).size(),
			"polygon_xz": geometry.polygon_xz,
		})

	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var left := "%s/%s" % [a.owner, a.surface_id]
		var right := "%s/%s" % [b.owner, b.surface_id]
		return left < right
	)
	_find_overlaps(rows, errors, union_coplanar_handoffs)
	_assign_counted_projected_areas(rows)
	errors.sort()
	return _build_report(rows, errors)


static func _merge_tagged_surfaces(
		root_node: Node3D,
		declarations: Array[Dictionary],
		errors: PackedStringArray
	) -> void:
	var declared_paths := {}
	for declaration: Dictionary in declarations:
		declared_paths[str(declaration.get("path", ""))] = true
	for candidate in root_node.find_children("*", "StaticBody3D", true, false):
		var body := candidate as StaticBody3D
		if not bool(body.get_meta("walkable_surface", false)):
			continue
		var path := root_node.get_path_to(body)
		if declared_paths.has(String(path)):
			continue
		var surface_id := StringName(str(body.get_meta(
			"walkable_surface_id", body.get_meta("surface_id", &"")
		)))
		if surface_id.is_empty():
			errors.append("tagged walkable surface has no stable id: %s" % path)
			continue
		var owner := StringName(str(body.get_meta("walkable_surface_owner", &"")))
		if owner.is_empty():
			var names := String(path).split("/", false)
			owner = StringName(_snake_case(names[0] if not names.is_empty() else root_node.name))
		declarations.append({
			"owner": owner,
			"surface_id": surface_id,
			"path": path,
			"kind": StringName(str(body.get_meta("walkable_surface_kind", &""))),
			"source": &"live_metadata",
		})


static func _single_enabled_box_collision(
		body: StaticBody3D,
		errors: PackedStringArray,
		identity: String
	) -> CollisionShape3D:
	var enabled: Array[CollisionShape3D] = []
	for candidate in body.find_children("*", "CollisionShape3D", true, false):
		var collision := candidate as CollisionShape3D
		if not collision.disabled and collision.shape != null:
			enabled.append(collision)
	if enabled.size() != 1:
		errors.append("declared surface must own exactly one enabled shape: %s" % identity)
		return null
	if not enabled[0].shape is BoxShape3D:
		errors.append("declared surface is not a BoxShape3D: %s" % identity)
		return null
	return enabled[0]


static func _measure_box_top(collision: CollisionShape3D) -> Dictionary:
	var shape := collision.shape as BoxShape3D
	var half := shape.size * 0.5
	var transform := collision.global_transform
	var axis_x := transform.basis.x * shape.size.x
	var axis_z := transform.basis.z * shape.size.z
	var normal := axis_z.cross(axis_x).normalized()
	if normal.dot(Vector3.UP) < 0.0:
		normal = -normal
	var true_area := axis_x.cross(axis_z).length()
	var projected := true_area * absf(normal.dot(Vector3.UP))
	var top_center := transform * Vector3(0.0, half.y, 0.0)
	var half_x := axis_x * 0.5
	var half_z := axis_z * 0.5
	var corners: Array[Vector3] = [
		top_center - half_x - half_z,
		top_center + half_x - half_z,
		top_center + half_x + half_z,
		top_center - half_x + half_z,
	]
	var polygon: Array[Vector2] = []
	for corner: Vector3 in corners:
		polygon.append(Vector2(corner.x, corner.z))
	var samples: Array[Vector3] = [top_center]
	for sx in [-SUPPORT_SAMPLE_INSET, SUPPORT_SAMPLE_INSET]:
		for sz in [-SUPPORT_SAMPLE_INSET, SUPPORT_SAMPLE_INSET]:
			samples.append(top_center + axis_x * float(sx) + axis_z * float(sz))
	return {
		"projected_horizontal_m2": projected,
		"true_surface_m2": true_area,
		"top_center": top_center,
		"up_dot": normal.dot(Vector3.UP),
		"polygon_xz": polygon,
		"sample_points": samples,
	}


static func _physics_support_count(
		samples: Array,
		space: PhysicsDirectSpaceState3D
	) -> int:
	if space == null:
		return 0
	var supported := 0
	for raw_sample: Variant in samples:
		var sample := raw_sample as Vector3
		var query := PhysicsRayQueryParameters3D.create(
			sample + Vector3.UP * SUPPORT_RAY_ABOVE,
			sample - Vector3.UP * SUPPORT_RAY_BELOW,
			WORLD_LAYER
		)
		query.collide_with_areas = false
		query.collide_with_bodies = true
		var hit := space.intersect_ray(query)
		if (
			not hit.is_empty()
			and absf(float((hit.position as Vector3).y) - sample.y) <= SUPPORT_RAY_ABOVE
			and (hit.normal as Vector3).dot(Vector3.UP) >= MINIMUM_UP_DOT
		):
			supported += 1
	return supported


static func _find_overlaps(
		rows: Array[Dictionary],
		errors: PackedStringArray,
		allow_union: bool
	) -> void:
	if allow_union:
		return
	for left_index in rows.size():
		var left := rows[left_index]
		for right_index in range(left_index + 1, rows.size()):
			var right := rows[right_index]
			if absf(float((left.top_center as Vector3).y) - float((right.top_center as Vector3).y)) > OVERLAP_ELEVATION_TOLERANCE:
				continue
			if _convex_polygons_overlap(left.polygon_xz as Array, right.polygon_xz as Array):
				errors.append("coplanar walkable surfaces overlap: %s/%s and %s/%s" % [
					left.owner, left.surface_id, right.owner, right.surface_id
				])


static func _convex_polygons_overlap(left: Array, right: Array) -> bool:
	for polygon: Array in [left, right]:
		for index in polygon.size():
			var start := polygon[index] as Vector2
			var finish := polygon[(index + 1) % polygon.size()] as Vector2
			var edge := finish - start
			if edge.length_squared() <= 0.0000001:
				continue
			var axis := Vector2(-edge.y, edge.x).normalized()
			var left_range := _projection_range(left, axis)
			var right_range := _projection_range(right, axis)
			var overlap := minf(float(left_range.y), float(right_range.y)) - maxf(float(left_range.x), float(right_range.x))
			if overlap <= OVERLAP_AXIS_TOLERANCE:
				return false
	return true


static func _projection_range(polygon: Array, axis: Vector2) -> Vector2:
	var minimum := INF
	var maximum := -INF
	for raw_point: Variant in polygon:
		var value := (raw_point as Vector2).dot(axis)
		minimum = minf(minimum, value)
		maximum = maxf(maximum, value)
	return Vector2(minimum, maximum)


## Assigns each level surface the deterministic incremental area it contributes
## to the coplanar union. Ramps are distinct inclined planes and contribute
## their full horizontal projection. Stable row ordering makes ownership of a
## handoff lap reproducible while the aggregate is order-independent.
static func _assign_counted_projected_areas(rows: Array[Dictionary]) -> void:
	var unions_by_elevation := {}
	for row: Dictionary in rows:
		var raw_projected := float(row.projected_horizontal_m2)
		if row.kind == "ramp":
			row.counted_projected_horizontal_m2 = raw_projected
			continue
		var elevation_key := roundi(float((row.top_center as Vector3).y) * 100.0)
		if not unions_by_elevation.has(elevation_key):
			unions_by_elevation[elevation_key] = []
		var union_polygons := unions_by_elevation[elevation_key] as Array
		var before_micro := _polygon_set_area_micro(union_polygons)
		_add_polygon_to_union(union_polygons, PackedVector2Array(row.polygon_xz))
		var after_micro := _polygon_set_area_micro(union_polygons)
		var contributed_micro := clampi(
			after_micro - before_micro,
			0,
			_to_micro(raw_projected)
		)
		row.counted_projected_horizontal_m2 = _from_micro(contributed_micro)


static func _add_polygon_to_union(union_polygons: Array, polygon: PackedVector2Array) -> void:
	var pending := polygon
	var index := 0
	while index < union_polygons.size():
		var existing := union_polygons[index] as PackedVector2Array
		var merged := Geometry2D.merge_polygons(existing, pending)
		if merged.size() == 1:
			pending = merged[0] as PackedVector2Array
			union_polygons.remove_at(index)
			index = 0
		else:
			index += 1
	union_polygons.append(pending)


static func _polygon_set_area_micro(polygons: Array) -> int:
	var total := 0
	for polygon: PackedVector2Array in polygons:
		total += _polygon_area_micro(polygon)
	return total


static func _polygon_area_micro(polygon: PackedVector2Array) -> int:
	var twice_area := 0.0
	for index in polygon.size():
		var current := polygon[index]
		var next := polygon[(index + 1) % polygon.size()]
		twice_area += current.x * next.y - next.x * current.y
	return roundi(absf(twice_area) * 500000.0)


static func _build_report(rows: Array[Dictionary], errors: PackedStringArray) -> Dictionary:
	var level_projected_micro := 0
	var ramp_projected_micro := 0
	var ramp_true_micro := 0
	var gross_projected_micro := 0
	var owners := {}
	var support_samples := 0
	var support_total := 0
	for row: Dictionary in rows:
		var projected := float(row.projected_horizontal_m2)
		var counted_projected := float(row.counted_projected_horizontal_m2)
		var true_area := float(row.true_surface_m2)
		gross_projected_micro += _to_micro(projected)
		if row.kind == "ramp":
			ramp_projected_micro += _to_micro(counted_projected)
			ramp_true_micro += _to_micro(true_area)
		else:
			level_projected_micro += _to_micro(counted_projected)
		var owner := String(row.owner)
		if not owners.has(owner):
			owners[owner] = {
				"gross_projected_micro": 0,
				"counted_projected_micro": 0,
				"counted_true_micro": 0,
				"surface_count": 0,
			}
		var owner_total := owners[owner] as Dictionary
		owner_total.gross_projected_micro = int(owner_total.gross_projected_micro) + _to_micro(projected)
		owner_total.counted_projected_micro = int(owner_total.counted_projected_micro) + _to_micro(counted_projected)
		owner_total.counted_true_micro = int(owner_total.counted_true_micro) + _to_micro(
			true_area if row.kind == "ramp" else counted_projected
		)
		owner_total.surface_count = int(owner_total.surface_count) + 1
		support_samples += int(row.support_samples)
		support_total += int(row.support_samples_total)
	var owner_rows: Array[Dictionary] = []
	var owner_names := PackedStringArray()
	for owner: String in owners:
		owner_names.append(owner)
	owner_names.sort()
	for owner: String in owner_names:
		var totals := owners[owner] as Dictionary
		owner_rows.append({
			"owner": owner,
			"gross_projected_horizontal_m2": _from_micro(int(totals.gross_projected_micro)),
			"projected_horizontal_m2": _from_micro(int(totals.counted_projected_micro)),
			"true_surface_m2": _from_micro(int(totals.counted_true_micro)),
			"surface_count": int(totals.surface_count),
		})
	var level_projected := _from_micro(level_projected_micro)
	var ramp_projected := _from_micro(ramp_projected_micro)
	var ramp_true := _from_micro(ramp_true_micro)
	return {
		"schema_version": SCHEMA_VERSION,
		"profile": String(PROFILE_ID),
		"source_sha": source_sha(),
		"engine": Engine.get_version_info().get("string", "unknown"),
		"valid": errors.is_empty(),
		"errors": errors,
		"rows": rows,
		"owner_totals": owner_rows,
		"surface_count": rows.size(),
		"ramp_count": rows.filter(func(row: Dictionary) -> bool: return row.kind == "ramp").size(),
		"gross_projected_horizontal_m2": _from_micro(gross_projected_micro),
		"level_projected_horizontal_m2": level_projected,
		"ramp_projected_horizontal_m2": ramp_projected,
		"ramp_true_surface_m2": ramp_true,
		"total_projected_horizontal_m2": _from_micro(level_projected_micro + ramp_projected_micro),
		"total_true_surface_m2": _from_micro(level_projected_micro + ramp_true_micro),
		"physics_support_samples": support_samples,
		"physics_support_samples_total": support_total,
	}


static func aggregate(report: Dictionary) -> Dictionary:
	return {
		"engine": report.engine,
		"errors": report.errors,
		"gross_projected_horizontal_m2": report.gross_projected_horizontal_m2,
		"level_projected_horizontal_m2": report.level_projected_horizontal_m2,
		"owner_totals": report.owner_totals,
		"physics_support_samples": report.physics_support_samples,
		"physics_support_samples_total": report.physics_support_samples_total,
		"profile": report.profile,
		"ramp_count": report.ramp_count,
		"ramp_projected_horizontal_m2": report.ramp_projected_horizontal_m2,
		"ramp_true_surface_m2": report.ramp_true_surface_m2,
		"schema_version": report.schema_version,
		"source_sha": report.source_sha,
		"surface_count": report.surface_count,
		"total_projected_horizontal_m2": report.total_projected_horizontal_m2,
		"total_true_surface_m2": report.total_true_surface_m2,
		"valid": report.valid,
	}


static func canonical_aggregate_json(report: Dictionary) -> String:
	return JSON.stringify(aggregate(report), "", true, false)


static func format_row(row: Dictionary) -> String:
	return "STATION_WALKABLE_AREA_ROW\t%s\t%s\t%s\t%s\t%.6f\t%.6f\t%.6f\t%d/%d" % [
		row.owner,
		row.surface_id,
		row.kind,
		row.path,
		float(row.projected_horizontal_m2),
		float(row.counted_projected_horizontal_m2),
		float(row.true_surface_m2),
		int(row.support_samples),
		int(row.support_samples_total),
	]


static func source_sha() -> String:
	var output: Array = []
	var code := OS.execute("git", PackedStringArray(["rev-parse", "HEAD"]), output, true)
	if code != 0 or output.is_empty():
		return "unavailable"
	return str(output[0]).strip_edges()


static func _rounded(value: float) -> float:
	return snappedf(value, 0.000001)


static func _to_micro(value: float) -> int:
	return roundi(value * 1000000.0)


static func _from_micro(value: int) -> float:
	return float(value) / 1000000.0


static func _rounded_vector3(value: Vector3) -> Vector3:
	return Vector3(_rounded(value.x), _rounded(value.y), _rounded(value.z))


static func _snake_case(value: String) -> String:
	var result := ""
	for index in value.length():
		var character := value[index]
		if character == character.to_upper() and character != character.to_lower() and index > 0:
			result += "_"
		result += character.to_lower()
	return result
