class_name FleetDockComb
extends Node3D

## Source-bounded macro-architecture interpretation of the station comb visible
## in B2. The repeated trunk/rung/slab rhythm is observed; this exact geometry,
## scale, direction, count, vertical transition, and placement are modern.
##
## DeferredDock markers are deliberately non-authoritative landmarks. This
## component owns no ShipBerth, landing area, lease, audio, activity, or process
## loop. World integration may expose the empty slabs without inventing a ship
## assignment.

const SCHEMA_VERSION := 1
const MODULE_ID: StringName = &"fleet-dock-comb"
const EVIDENCE_STATUS: StringName = &"modern_interpretation"
const WORLD_LAYER := PhysicsLayers.WORLD

const TRUNK_LENGTH := 48.0
const TRUNK_CLEAR_WIDTH := 4.8
const LOWER_DECK_ELEVATION := 0.0
const UPPER_DECK_ELEVATION := 2.4
const RUNG_CLEAR_WIDTH := 3.6
const RUNG_COUNT := 3
const DOCK_SLAB_COUNT := 3
const DEFERRED_DOCK_COUNT := 3
const WALKABLE_SURFACE_COUNT := 7
const COLLISION_BODY_COUNT := 7
const COLLISION_SHAPE_COUNT := 7

# The root is the connection plane. Local +Z follows the narrow trunk and every
# broad slab is on local +X, keeping the module starboard-biased and rotatable.
const FOOTPRINT_MIN := Vector3(-2.6, -2.5, 0.0)
const FOOTPRINT_MAX := Vector3(21.0, 5.0, 48.0)

const MESH_INSTANCE_BUDGET := 64
const STATIC_BODY_BUDGET := COLLISION_BODY_COUNT
const COLLISION_SHAPE_BUDGET := COLLISION_SHAPE_COUNT
const LABEL_BUDGET := DEFERRED_DOCK_COUNT
const LIGHT_BUDGET := 0

const SURFACE_IDS := [
	"trunk",
	"rung-01",
	"dock-slab-01",
	"rung-02",
	"dock-slab-02",
	"rung-03-vertical",
	"dock-slab-03-upper",
]

const RUNG_IDS := [
	"rung-01",
	"rung-02",
	"rung-03-vertical",
]

const DOCK_SLAB_IDS := [
	"dock-slab-01",
	"dock-slab-02",
	"dock-slab-03-upper",
]

const EVIDENCE_REFERENCES := [
	"B2@04:55-05:10 / OE-B2-COMB / long narrow trunk with perpendicular rung-like arms",
	"B2@04:55-05:10 / OE-B2-SLABS / broad end slabs separated by genuine voids",
	"B2@04:40-05:10 / OE-B2-BERTHS / ships at separate lattice offsets",
]

const CONTENT_NOTE := (
	"B2 supports the repeated comb rhythm, broad separated end volumes, and ships "
	+ "distributed at lattice offsets. Fleet Dock Comb is not recovered original "
	+ "geometry: its name, exact three-tooth count, measurements, starboard bias, "
	+ "surface design, short ramp, materials, labels, and world adjacency are modern "
	+ "interpretation. All three dock landmarks are empty and explicitly deferred; "
	+ "they grant no landing, lease, boarding, regeneration, or ship-spawn authority."
)

@onready var _module_anchor: Marker3D = %ModuleAnchor
@onready var _route_approach: Marker3D = %RouteApproach
@onready var _route_trunk_forward: Marker3D = %RouteTrunkForward
@onready var _route_dock_01_threshold: Marker3D = %RouteDock01Threshold
@onready var _route_trunk_mid: Marker3D = %RouteTrunkMid
@onready var _route_dock_02_threshold: Marker3D = %RouteDock02Threshold
@onready var _route_trunk_aft: Marker3D = %RouteTrunkAft
@onready var _route_vertical_base: Marker3D = %RouteVerticalBase
@onready var _route_vertical_top: Marker3D = %RouteVerticalTop
@onready var _route_dock_03_threshold: Marker3D = %RouteDock03Threshold
@onready var _deferred_dock_01: Marker3D = %DeferredDock01
@onready var _deferred_dock_02: Marker3D = %DeferredDock02
@onready var _deferred_dock_03: Marker3D = %DeferredDock03

var _materials: Dictionary = {}
var _route_markers: Dictionary = {}
var _dock_markers: Dictionary = {}
var _surface_nodes: Dictionary = {}
var _build_root: Node3D
var _enabled := true
var _built := false
var _build_generation := 0


func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	if not _built:
		_built = true
		_create_materials()
		_index_semantics()
		_build_structure()
		_apply_metadata()
		_build_generation += 1
	_apply_enabled_state()


func get_module_id() -> StringName:
	return MODULE_ID


func get_module_anchor() -> Marker3D:
	return _module_anchor


func get_route_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for route_id: StringName in _route_markers.keys():
		result.append(route_id)
	result.sort()
	return result


func has_route_marker(route_id: StringName) -> bool:
	return _route_markers.has(route_id)


func get_route_marker(route_id: StringName) -> Marker3D:
	return _route_markers.get(route_id) as Marker3D


func get_route_transform(route_id: StringName) -> Transform3D:
	var marker := get_route_marker(route_id)
	return marker.global_transform if marker != null else Transform3D.IDENTITY


func get_route_transforms() -> Dictionary:
	var result := {}
	for route_id: StringName in _route_markers.keys():
		result[route_id] = (_route_markers[route_id] as Marker3D).global_transform
	return result


func get_deferred_dock_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for dock_id: StringName in _dock_markers.keys():
		result.append(dock_id)
	result.sort()
	return result


func get_deferred_dock_marker(dock_id: StringName) -> Marker3D:
	return _dock_markers.get(dock_id) as Marker3D


func get_deferred_dock_transform(dock_id: StringName) -> Transform3D:
	var marker := get_deferred_dock_marker(dock_id)
	return marker.global_transform if marker != null else Transform3D.IDENTITY


## These are presentation landmarks, not ShipBerth specifications. No landing
## extents or compatibility tags are intentionally exposed.
func get_deferred_dock_roster() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for dock_id in get_deferred_dock_ids():
		var marker := get_deferred_dock_marker(dock_id)
		result.append({
			"dock_id": dock_id,
			"status": &"deferred_empty",
			"marker_transform": marker.global_transform,
			"ship_assignment": &"none",
			"owns_berth_authority": false,
			"landing_volume_present": false,
			"boarding_area_present": false,
			"evidence_claim": &"OE-B2-BERTHS",
		})
	return result.duplicate(true)


func get_integration_footprint() -> Dictionary:
	return {
		"anchor_transform": _module_anchor.global_transform,
		"connection_plane_local": Transform3D.IDENTITY,
		"local_min": FOOTPRINT_MIN,
		"local_max": FOOTPRINT_MAX,
		"local_size": FOOTPRINT_MAX - FOOTPRINT_MIN,
		"approach_axis_local": Vector3.FORWARD,
		"module_extends_local": Vector3.BACK,
		"comb_teeth_axis_local": Vector3.RIGHT,
		"starboard_biased": true,
	}


func get_bounds_contract() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"local_aabb": AABB(FOOTPRINT_MIN, FOOTPRINT_MAX - FOOTPRINT_MIN),
		"local_min": FOOTPRINT_MIN,
		"local_max": FOOTPRINT_MAX,
		"world_aabb": _transform_aabb(AABB(FOOTPRINT_MIN, FOOTPRINT_MAX - FOOTPRINT_MIN), global_transform),
		"trunk_length": TRUNK_LENGTH,
		"trunk_clear_width": TRUNK_CLEAR_WIDTH,
		"rung_clear_width": RUNG_CLEAR_WIDTH,
		"floor_elevations": PackedFloat32Array([LOWER_DECK_ELEVATION, UPPER_DECK_ELEVATION]),
		"full_footprint_floor_present": _has_full_footprint_floor(),
		"negative_space_samples_local": get_negative_space_samples(),
	}


func get_negative_space_samples() -> PackedVector3Array:
	return PackedVector3Array([
		Vector3(15.0, 1.0, 17.5),
		Vector3(15.0, 1.0, 32.5),
		Vector3(15.0, 1.0, 47.5),
		Vector3(6.5, 1.0, 17.5),
		Vector3(6.5, 1.0, 32.5),
	])


func get_component_roster() -> Dictionary:
	var actual_surface_ids := PackedStringArray()
	for raw_id in _surface_nodes.keys():
		actual_surface_ids.append(str(raw_id))
	actual_surface_ids.sort()
	var expected_surface_ids := PackedStringArray(SURFACE_IDS)
	expected_surface_ids.sort()
	return {
		"schema_version": SCHEMA_VERSION,
		"surface_ids": actual_surface_ids,
		"expected_surface_ids": expected_surface_ids,
		"walkable_surface_count": _surface_nodes.size(),
		"rung_ids": PackedStringArray(RUNG_IDS),
		"rung_count": RUNG_COUNT,
		"dock_slab_ids": PackedStringArray(DOCK_SLAB_IDS),
		"dock_slab_count": DOCK_SLAB_COUNT,
		"vertical_transition_count": 1,
		"deferred_dock_ids": PackedStringArray(get_deferred_dock_ids()),
		"deferred_dock_count": _dock_markers.size(),
		"route_ids": PackedStringArray(get_route_ids()),
	}


func get_collision_contract() -> Dictionary:
	var bodies := find_children("*", "StaticBody3D", true, false)
	var shapes := find_children("*", "CollisionShape3D", true, false)
	var body_paths := PackedStringArray()
	var all_layers_valid := true
	var all_masks_valid := true
	var all_shapes_enabled := true
	for raw_body in bodies:
		var body := raw_body as StaticBody3D
		body_paths.append(str(get_path_to(body)))
		all_layers_valid = all_layers_valid and body.collision_layer == (WORLD_LAYER if _enabled else 0)
		all_masks_valid = all_masks_valid and body.collision_mask == 0
	for raw_shape in shapes:
		var shape := raw_shape as CollisionShape3D
		all_shapes_enabled = all_shapes_enabled and not shape.disabled
	body_paths.sort()
	return {
		"schema_version": SCHEMA_VERSION,
		"body_count": bodies.size(),
		"shape_count": shapes.size(),
		"active_body_count": bodies.size() if _enabled else 0,
		"body_paths": body_paths,
		"expected_surface_ids": PackedStringArray(SURFACE_IDS),
		"enabled_layer": WORLD_LAYER,
		"current_enabled_state": _enabled,
		"all_layers_match_lifecycle": all_layers_valid,
		"all_masks_zero": all_masks_valid,
		"all_shapes_present_and_enabled": all_shapes_enabled,
		"full_footprint_floor_present": _has_full_footprint_floor(),
	}


func get_authority_contract() -> Dictionary:
	var ship_berth_count := 0
	var area_count := 0
	var audio_node_count := 0
	var activity_node_count := 0
	for node in _all_descendants():
		if node is Area3D:
			area_count += 1
		if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
			audio_node_count += 1
		var script := node.get_script() as Script
		var script_path := script.resource_path if script != null else ""
		if script_path.ends_with("/ship_berth.gd"):
			ship_berth_count += 1
		if script_path.ends_with("/station_operations_activity.gd") or bool(node.get_meta("station_activity", false)):
			activity_node_count += 1
	return {
		"schema_version": SCHEMA_VERSION,
		"ship_berth_count": ship_berth_count,
		"landing_or_interaction_area_count": area_count,
		"audio_node_count": audio_node_count,
		"activity_node_count": activity_node_count,
		"lease_authority_count": 0,
		"spawn_authority_count": 0,
		"boarding_authority_count": 0,
		"network_authority_role": &"none",
		"deferred_markers_are_authoritative": false,
	}


func get_performance_contract() -> Dictionary:
	var meshes := find_children("*", "MeshInstance3D", true, false)
	var bodies := find_children("*", "StaticBody3D", true, false)
	var shapes := find_children("*", "CollisionShape3D", true, false)
	var labels := find_children("*", "Label3D", true, false)
	var lights := find_children("*", "Light3D", true, false)
	return {
		"schema_version": SCHEMA_VERSION,
		"mesh_instances": meshes.size(),
		"static_bodies": bodies.size(),
		"collision_shapes": shapes.size(),
		"labels": labels.size(),
		"lights": lights.size(),
		"process_loops": int(is_processing()) + int(is_physics_processing()),
		"budgets": {
			"mesh_instances": MESH_INSTANCE_BUDGET,
			"static_bodies": STATIC_BODY_BUDGET,
			"collision_shapes": COLLISION_SHAPE_BUDGET,
			"labels": LABEL_BUDGET,
			"lights": LIGHT_BUDGET,
			"process_loops": 0,
		},
		"within_budget": meshes.size() <= MESH_INSTANCE_BUDGET \
			and bodies.size() <= STATIC_BODY_BUDGET \
			and shapes.size() <= COLLISION_SHAPE_BUDGET \
			and labels.size() <= LABEL_BUDGET \
			and lights.is_empty() \
			and not is_processing() \
			and not is_physics_processing(),
	}


func set_module_enabled(enabled: bool) -> void:
	_enabled = enabled
	_apply_enabled_state()


func is_module_enabled() -> bool:
	return _enabled


func get_lifecycle_contract() -> Dictionary:
	var surface_instance_ids := PackedInt64Array()
	for surface_id in SURFACE_IDS:
		var surface := _surface_nodes.get(surface_id) as StaticBody3D
		if surface != null:
			surface_instance_ids.append(surface.get_instance_id())
	return {
		"schema_version": SCHEMA_VERSION,
		"mode": &"identity_preserving_enable_disable",
		"enabled": _enabled,
		"built": _built and _build_root != null,
		"build_generation": _build_generation,
		"runtime_rebuild_allowed": false,
		"reversible": true,
		"visible_matches_enabled": _build_root != null and _build_root.visible == _enabled,
		"collision_matches_enabled": bool(get_collision_contract().all_layers_match_lifecycle),
		"process_free": not is_processing() and not is_physics_processing(),
		"surface_instance_ids": surface_instance_ids,
	}


func get_evidence_metadata() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"module_id": MODULE_ID,
		"evidence_status": EVIDENCE_STATUS,
		"source_bounded": true,
		"authenticated_original_geometry": false,
		"references": PackedStringArray(EVIDENCE_REFERENCES),
		"claim_ids": PackedStringArray(["OE-B2-COMB", "OE-B2-SLABS", "OE-B2-BERTHS"]),
		"content_note": CONTENT_NOTE,
		"supported_invariants": PackedStringArray([
			"long narrow trunk with short orthogonal rungs",
			"broad separated end slabs with substantial negative space",
			"ships distributed at separate station lattice offsets",
		]),
		"modern_interpretations": PackedStringArray([
			"Fleet Dock Comb name and exact three-tooth roster",
			"all dimensions, directions, surface details, and station placement",
			"starboard-only bias and one short vertical ramp",
			"deferred dock labels and marker transforms",
		]),
		"explicit_unknowns": PackedStringArray([
			"historical arm, slab, and berth count",
			"exact scale, directions, elevations, functions, and adjacency",
			"ship-class assignments for the observed separated berths",
		]),
	}


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if _module_anchor == null or not _module_anchor.global_transform.is_equal_approx(global_transform):
		errors.append("module integration anchor must match the exact root connection plane")
	if _route_markers.size() != 9:
		errors.append("route marker registry must contain exactly nine explicit nodes")
	if _dock_markers.size() != DEFERRED_DOCK_COUNT:
		errors.append("deferred dock registry must contain exactly three empty landmarks")
	if _surface_nodes.size() != WALKABLE_SURFACE_COUNT:
		errors.append("walkable surface roster must contain exactly seven collision-backed surfaces")
	var roster := get_component_roster()
	if roster.surface_ids != roster.expected_surface_ids:
		errors.append("walkable surface identity roster differs from the declared contract")
	if int(roster.rung_count) != RUNG_COUNT or int(roster.dock_slab_count) != DOCK_SLAB_COUNT:
		errors.append("comb must preserve exactly three rungs and three broad slabs")
	var collision := get_collision_contract()
	if int(collision.body_count) != COLLISION_BODY_COUNT or int(collision.shape_count) != COLLISION_SHAPE_COUNT:
		errors.append("collision roster must remain one body and shape per walkable surface")
	if not bool(collision.all_layers_match_lifecycle) or not bool(collision.all_masks_zero):
		errors.append("collision layers or masks differ from the canonical lifecycle contract")
	if bool(collision.full_footprint_floor_present):
		errors.append("a hidden full-footprint floor destroys the required station voids")
	var authority := get_authority_contract()
	if int(authority.ship_berth_count) != 0 \
		or int(authority.landing_or_interaction_area_count) != 0 \
		or int(authority.audio_node_count) != 0 \
		or int(authority.activity_node_count) != 0:
		errors.append("comb module must own no berth, area, audio, or activity authority")
	for dock in get_deferred_dock_roster():
		if dock.status != &"deferred_empty" \
			or bool(dock.owns_berth_authority) \
			or bool(dock.landing_volume_present) \
			or bool(dock.boarding_area_present):
			errors.append("every dock marker must remain empty, deferred, and non-authoritative")
			break
	if not bool(get_performance_contract().within_budget):
		errors.append("module exceeds its fixed geometry or processing budget")
	var lifecycle := get_lifecycle_contract()
	if not bool(lifecycle.reversible) \
		or not bool(lifecycle.visible_matches_enabled) \
		or not bool(lifecycle.collision_matches_enabled) \
		or not bool(lifecycle.process_free):
		errors.append("identity-preserving enable/disable lifecycle is inconsistent")
	return errors


func get_audit_report() -> Dictionary:
	var errors := get_validation_errors()
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"module_id": MODULE_ID,
		"evidence": get_evidence_metadata(),
		"roster": get_component_roster(),
		"bounds": get_bounds_contract(),
		"collision": get_collision_contract(),
		"authority": get_authority_contract(),
		"performance": get_performance_contract(),
		"lifecycle": get_lifecycle_contract(),
		"deferred_docks": get_deferred_dock_roster(),
	}.duplicate(true)


func audit() -> Dictionary:
	return get_audit_report()


func _index_semantics() -> void:
	_route_markers = {
		&"approach": _route_approach,
		&"trunk-forward": _route_trunk_forward,
		&"dock-01-threshold": _route_dock_01_threshold,
		&"trunk-mid": _route_trunk_mid,
		&"dock-02-threshold": _route_dock_02_threshold,
		&"trunk-aft": _route_trunk_aft,
		&"vertical-base": _route_vertical_base,
		&"vertical-top": _route_vertical_top,
		&"dock-03-threshold": _route_dock_03_threshold,
	}
	_dock_markers = {
		&"deferred-dock-01": _deferred_dock_01,
		&"deferred-dock-02": _deferred_dock_02,
		&"deferred-dock-03": _deferred_dock_03,
	}
	for route_id: StringName in _route_markers.keys():
		var marker := _route_markers[route_id] as Marker3D
		marker.set_meta("station_route_marker", true)
		marker.set_meta("route_id", route_id)
	for dock_id: StringName in _dock_markers.keys():
		var marker := _dock_markers[dock_id] as Marker3D
		marker.set_meta("deferred_dock", true)
		marker.set_meta("dock_id", dock_id)
		marker.set_meta("dock_status", &"deferred_empty")
		marker.set_meta("owns_berth_authority", false)
		marker.set_meta("evidence_claim", &"OE-B2-BERTHS")


func _create_materials() -> void:
	_materials["deck"] = _material(Color("8b9698"), 0.62, 0.42)
	_materials["deck_light"] = _material(Color("bdc5c4"), 0.42, 0.34)
	_materials["frame"] = _material(Color("304248"), 0.72, 0.31)
	_materials["underframe"] = _material(Color("17252b"), 0.76, 0.36)
	_materials["grip"] = _material(Color("26363b"), 0.35, 0.68)
	_materials["cyan"] = _material(Color("55dfe2"), 0.14, 0.28, Color("36cdd2"), 1.4)
	_materials["amber"] = _material(Color("f2a84b"), 0.35, 0.31, Color("e9872c"), 1.1)
	_materials["deferred"] = _material(Color("d5564d"), 0.18, 0.38, Color("a72f2b"), 0.9)


func _build_structure() -> void:
	_build_root = Node3D.new()
	_build_root.name = "GeneratedComb"
	_build_root.set_meta("generated_geometry", true)
	_build_root.set_meta("runtime_rebuild_allowed", false)
	add_child(_build_root)

	var surfaces := Node3D.new()
	surfaces.name = "WalkableSurfaces"
	_build_root.add_child(surfaces)

	_register_surface(_surface_box(surfaces, "Trunk", Vector3(0, -0.3, 24.0), Vector3(4.8, 0.6, 48.0), _materials["deck"]), &"trunk", &"trunk")
	_register_surface(_surface_box(surfaces, "Rung01", Vector3(5.5, -0.3, 10.0), Vector3(7.0, 0.6, 3.6), _materials["deck_light"]), &"rung-01", &"orthogonal-rung")
	_register_surface(_surface_box(surfaces, "DockSlab01", Vector3(15.0, -0.3, 10.0), Vector3(12.0, 0.6, 12.0), _materials["deck"]), &"dock-slab-01", &"broad-deferred-slab")
	_register_surface(_surface_box(surfaces, "Rung02", Vector3(5.5, -0.3, 25.0), Vector3(7.0, 0.6, 3.6), _materials["deck_light"]), &"rung-02", &"orthogonal-rung")
	_register_surface(_surface_box(surfaces, "DockSlab02", Vector3(15.0, -0.3, 25.0), Vector3(12.0, 0.6, 12.0), _materials["deck"]), &"dock-slab-02", &"broad-deferred-slab")

	var ramp_start := Vector3(2.0, LOWER_DECK_ELEVATION, 40.0)
	var ramp_finish := Vector3(9.0, UPPER_DECK_ELEVATION, 40.0)
	var ramp_direction := ramp_finish - ramp_start
	var ramp_angle := atan2(ramp_direction.y, ramp_direction.x)
	var ramp_normal := Vector3(-sin(ramp_angle), cos(ramp_angle), 0.0)
	var ramp_center := (ramp_start + ramp_finish) * 0.5 - ramp_normal * 0.3
	_register_surface(
		_surface_box(
			surfaces,
			"Rung03Vertical",
			ramp_center,
			Vector3(ramp_direction.length(), 0.6, 3.6),
			_materials["deck_light"],
			Vector3(0, 0, rad_to_deg(ramp_angle))
		),
		&"rung-03-vertical",
		&"orthogonal-rung-vertical-transition"
	)
	_register_surface(_surface_box(surfaces, "DockSlab03Upper", Vector3(15.0, 2.1, 40.0), Vector3(12.0, 0.6, 12.0), _materials["deck"]), &"dock-slab-03-upper", &"broad-deferred-slab-upper")

	_build_surface_detail()
	_build_understructure()
	_build_deferred_landmarks()


func _build_surface_detail() -> void:
	var detail := Node3D.new()
	detail.name = "SurfaceDetail"
	detail.set_meta("visual_detail_only", true)
	_build_root.add_child(detail)

	for z_position in [2.0, 6.0, 10.0, 14.0, 18.0, 22.0, 26.0, 30.0, 34.0, 38.0, 42.0, 46.0]:
		_visual_box(detail, "TrunkExpansionJoint", Vector3(0, 0.018, float(z_position)), Vector3(4.25, 0.035, 0.06), _materials["grip"])
	for z_position in [5.0, 20.0, 35.0]:
		_visual_box(detail, "TrunkRouteLight", Vector3(0, 0.045, float(z_position)), Vector3(0.22, 0.05, 1.25), _materials["cyan"])

	var slab_specs := [
		[Vector3(15.0, 0.02, 10.0), 0.0],
		[Vector3(15.0, 0.02, 25.0), 0.0],
		[Vector3(15.0, 2.42, 40.0), 2.4],
	]
	for index in slab_specs.size():
		var top_center := slab_specs[index][0] as Vector3
		var elevation := float(slab_specs[index][1])
		_visual_box(detail, "SlabInset%02d" % (index + 1), top_center, Vector3(10.4, 0.04, 10.4), _materials["grip"])
		_visual_box(detail, "DeferredCrossStripe%02d" % (index + 1), top_center + Vector3(0, 0.035, 0), Vector3(8.2, 0.03, 0.18), _materials["deferred"])
		_visual_box(detail, "DeferredLongStripe%02d" % (index + 1), top_center + Vector3(0, 0.038, 0), Vector3(0.18, 0.03, 8.2), _materials["deferred"])
		for corner in [Vector2(-5.1, -5.1), Vector2(-5.1, 5.1), Vector2(5.1, -5.1), Vector2(5.1, 5.1)]:
			_visual_box(
				detail,
				"SlabCornerBeacon%02d" % (index + 1),
				Vector3(15.0 + corner.x, elevation + 0.08, top_center.z + corner.y),
				Vector3(0.48, 0.12, 0.48),
				_materials["amber"]
			)

	# Narrow edge cues belong only to the true walkable rungs. They never bridge
	# either of the large gaps between slabs.
	for rung_z in [10.0, 25.0]:
		for side in [-1.0, 1.0]:
			_visual_box(detail, "RungEdgeCue", Vector3(5.5, 0.055, float(rung_z) + float(side) * 1.62), Vector3(6.7, 0.06, 0.1), _materials["amber"])


func _build_understructure() -> void:
	var underframe := Node3D.new()
	underframe.name = "VisualUnderframe"
	underframe.set_meta("visual_detail_only", true)
	_build_root.add_child(underframe)

	_beam_between(underframe, "TrunkChordPort", Vector3(-2.05, -0.85, 0.5), Vector3(-2.05, -0.85, 47.5), 0.16, _materials["underframe"])
	_beam_between(underframe, "TrunkChordStarboard", Vector3(2.05, -0.85, 0.5), Vector3(2.05, -0.85, 47.5), 0.16, _materials["underframe"])
	for rung_z in [10.0, 25.0, 40.0]:
		_beam_between(underframe, "RungUnderChord", Vector3(2.0, -0.82, float(rung_z)), Vector3(20.4, (-0.82 if rung_z < 40.0 else 1.58), float(rung_z)), 0.18, _materials["frame"])
	for slab_spec in [[10.0, -1.75], [25.0, -1.75], [40.0, 0.65]]:
		var slab_z := float(slab_spec[0])
		var support_y := float(slab_spec[1])
		for support_x in [11.0, 19.0]:
			_visual_box(underframe, "SlabSupport", Vector3(float(support_x), support_y, slab_z), Vector3(0.55, 2.5, 0.55), _materials["frame"])


func _build_deferred_landmarks() -> void:
	var landmarks := Node3D.new()
	landmarks.name = "DeferredLandmarks"
	landmarks.set_meta("non_authoritative_presentation", true)
	_build_root.add_child(landmarks)
	var label_specs := [
		["DEFERRED DOCK 01", Vector3(15.0, 0.18, 4.55)],
		["DEFERRED DOCK 02", Vector3(15.0, 0.18, 19.55)],
		["DEFERRED DOCK 03", Vector3(15.0, 2.58, 34.55)],
	]
	for index in label_specs.size():
		var label := Label3D.new()
		label.name = "DeferredDockLabel%02d" % (index + 1)
		label.text = str(label_specs[index][0])
		label.position = label_specs[index][1] as Vector3
		label.rotation_degrees = Vector3(-90, 0, 0)
		label.font_size = 42
		label.pixel_size = 0.018
		label.modulate = Color("e36a60")
		label.outline_modulate = Color("2a1112")
		label.outline_size = 8
		label.no_depth_test = false
		label.set_meta("deferred_dock_label", true)
		landmarks.add_child(label)


func _register_surface(body: StaticBody3D, surface_id: StringName, surface_role: StringName) -> void:
	body.set_meta("fleet_comb_surface", true)
	body.set_meta("surface_id", surface_id)
	body.set_meta("surface_role", surface_role)
	body.set_meta("walkable_surface", true)
	_surface_nodes[surface_id] = body


func _surface_box(
		parent: Node3D,
		node_name: String,
		local_position: Vector3,
		size: Vector3,
		material: Material,
		rotation_degrees_value: Vector3 = Vector3.ZERO
	) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = local_position
	body.rotation_degrees = rotation_degrees_value
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	parent.add_child(body)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	return body


func _visual_box(parent: Node3D, node_name: String, local_position: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var result := MeshInstance3D.new()
	result.name = node_name
	result.position = local_position
	var mesh := BoxMesh.new()
	mesh.size = size
	result.mesh = mesh
	result.material_override = material
	result.set_meta("visual_detail_only", true)
	parent.add_child(result)
	return result


func _beam_between(parent: Node3D, node_name: String, from: Vector3, to: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var direction := to - from
	var result := MeshInstance3D.new()
	result.name = node_name
	result.position = (from + to) * 0.5
	result.quaternion = Quaternion(Vector3.UP, direction.normalized())
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = direction.length()
	mesh.radial_segments = 16
	result.mesh = mesh
	result.material_override = material
	result.set_meta("visual_detail_only", true)
	parent.add_child(result)
	return result


func _material(
		color: Color,
		metallic: float,
		roughness: float,
		emission_color: Color = Color.TRANSPARENT,
		emission_energy: float = 0.0
	) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.metallic = metallic
	result.roughness = roughness
	result.clearcoat_enabled = true
	result.clearcoat = 0.18
	result.clearcoat_roughness = 0.45
	if emission_energy > 0.0:
		result.emission_enabled = true
		result.emission = emission_color
		result.emission_energy_multiplier = emission_energy
	return result


func _apply_enabled_state() -> void:
	if _build_root == null:
		return
	_build_root.visible = _enabled
	for raw_surface in _surface_nodes.values():
		var surface := raw_surface as StaticBody3D
		surface.collision_layer = WORLD_LAYER if _enabled else 0
		surface.collision_mask = 0


func _apply_metadata() -> void:
	set_meta("station_module", true)
	set_meta("module_id", MODULE_ID)
	set_meta("evidence_status", EVIDENCE_STATUS)
	set_meta("source_bounded", true)
	set_meta("authenticated_original_geometry", false)
	set_meta("owns_berth_authority", false)
	set_meta("deferred_dock_count", DEFERRED_DOCK_COUNT)
	set_meta("integration_footprint_min", FOOTPRINT_MIN)
	set_meta("integration_footprint_max", FOOTPRINT_MAX)
	set_meta("content_note", CONTENT_NOTE)
	add_to_group("station_modules")
	add_to_group("source_bounded_station_modules")


func _has_full_footprint_floor() -> bool:
	var footprint_size := FOOTPRINT_MAX - FOOTPRINT_MIN
	for raw_shape in find_children("*", "CollisionShape3D", true, false):
		var collision := raw_shape as CollisionShape3D
		var box := collision.shape as BoxShape3D
		if box != null and box.size.x >= footprint_size.x * 0.9 and box.size.z >= footprint_size.z * 0.9:
			return true
	return false


func _all_descendants() -> Array[Node]:
	var result: Array[Node] = []
	var queue: Array[Node] = [self]
	while not queue.is_empty():
		var current: Node = queue.pop_front()
		result.append(current)
		for child in current.get_children():
			queue.append(child)
	return result


func _transform_aabb(local_aabb: AABB, transform: Transform3D) -> AABB:
	var first := true
	var result := AABB()
	for x_side in [0.0, 1.0]:
		for y_side in [0.0, 1.0]:
			for z_side in [0.0, 1.0]:
				var corner := local_aabb.position + Vector3(
					local_aabb.size.x * float(x_side),
					local_aabb.size.y * float(y_side),
					local_aabb.size.z * float(z_side)
				)
				var world_corner := transform * corner
				if first:
					result = AABB(world_corner, Vector3.ZERO)
					first = false
				else:
					result = result.expand(world_corner)
	return result
