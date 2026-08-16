class_name AftJunctionStack
extends Node3D

## Source-bounded, reusable interpretation of an aft station junction.
##
## Surviving material supports an exposed grey lattice, compact windowed rooms,
## short vertical circulation, and cyan/red access landmarks. It does not prove
## this module's exact plan, dimensions, furniture, adjacency, or name. Those
## details are deliberately identified as modern interpretation in the public
## evidence report rather than being presented as recovered original geometry.

const SCHEMA_VERSION := 1
const MODULE_ID: StringName = &"aft-junction-stack"
const EVIDENCE_STATUS: StringName = &"modern_interpretation"
## Declared station connection slot. `ShipyardWorld` publishes the matching hub
## endpoint; the pair is what `StationRouteRegistry` records as one graph edge.
const HUB_CONNECTION_SLOT: StringName = &"hub-aft-junction"
const WORLD_LAYER := PhysicsLayers.WORLD

const LOWER_FLOOR_ELEVATION := 0.0
const UPPER_FLOOR_ELEVATION := 4.2
const STAIR_STEP_COUNT := 15
const STAIR_RISE := UPPER_FLOOR_ELEVATION / float(STAIR_STEP_COUNT - 1)
const STAIR_RUN := 9.8 / float(STAIR_STEP_COUNT - 1)
const STAIR_CLEAR_WIDTH := 2.8
const STAIR_HEAD_CLEARANCE := 2.7

## The stair-base landing is walked across, not looked at. Its footprint is a
## constant because two separate rail runs have to be kept off it: the approach
## rail must stop at its southern edge, and the eastern stair rail must not begin
## until the ramp has climbed clear of it. MAP-001 was exactly that pair of rails
## closing the only gate between the connection deck and the ramp foot.
const STAIR_BASE_LANDING_CENTRE := Vector3(-4.6, -0.32, 3.25)
const STAIR_BASE_LANDING_SIZE := Vector3(4.4, 0.64, 3.5)

## Physical size of one station panel plate in this module, in metres of world
## space per texture repeat. Frozen; the Fleet Dock comb and the hub match it so
## no plate changes size across a connector seam.
const PANEL_SURFACE_SCALE := 0.30

const OPERATIONS_ROOM_CENTER := Vector3(5.6, 2.4, 13.2)
# Include the floor-contact tolerance of a CharacterBody root. The previous
# 2.35 m half-height began at local Y=0.05 and incorrectly rejected an avatar
# standing exactly on the physical room floor.
const OPERATIONS_ROOM_HALF_EXTENTS := Vector3(5.0, 2.45, 3.6)
const FOOTPRINT_MIN := Vector3(-10.4, -1.5, -2.6)
const FOOTPRINT_MAX := Vector3(11.2, 8.4, 21.0)
const OPEN_WALKABLE_AREA_ESTIMATE := 174.0
const COVERED_WALKABLE_AREA_ESTIMATE := 83.2

const EVIDENCE_REFERENCES := [
	"RESEARCH.md: implementation evidence map / exposed dock lattice",
	"B2@04:55-05:10 / separated nodes, narrow arms, substantial void",
	"B3@00:20-00:52 / exposed junction and short vertical route",
	"B3@02:40-03:00 / compact grey console room with windows and blue access",
	"B4@04:20-04:30 / chair-console banks and broad windows, context uncertain",
]

const CONTENT_NOTE := (
	"The open-lattice hierarchy, vertical transition, compact windowed room, and "
	+ "coloured access landmarks are bounded by surviving observations. The Aft "
	+ "Junction Stack name, exact geometry, measurements, furniture arrangement, "
	+ "service wall, door motion, and adjacency are original modern design. The red "
	+ "VIP door is only a deferred landmark; no unsupported VIP interior is built."
)

@onready var _module_anchor: Marker3D = %ModuleAnchor
@onready var _route_approach: Marker3D = %RouteApproach
@onready var _route_lower_junction: Marker3D = %RouteLowerJunction
@onready var _route_stair_base: Marker3D = %RouteStairBase
@onready var _route_stair_top: Marker3D = %RouteStairTop
@onready var _operations_room_anchor: Marker3D = %OperationsRoomAnchor
@onready var _upper_floor_anchor: Marker3D = %UpperFloorAnchor
@onready var _vip_access_anchor: Marker3D = %VIPAccessAnchor
@onready var _operations_entrance: StationDoor = %OperationsEntrance
@onready var _vip_access: StationDoor = %VIPAccess

var _materials: Dictionary = {}
var _rounded_box_cache: Dictionary = {}
var _chamfered_cylinder_cache: Dictionary = {}
var _route_markers: Dictionary = {}
var _chair_nodes: Array[Node3D] = []
var _console_nodes: Array[Node3D] = []
var _built := false
var _module_enabled := true


func _ready() -> void:
	if not _built:
		_built = true
		_create_materials()
		_index_routes()
		_build_structure()
		_style_access_landmarks()
		_apply_metadata()
	# Reconcile the real node state against `_module_enabled` on every ready, so a
	# scene-authored or externally drifted layer/visibility cannot survive.
	_apply_enabled_state()


func get_module_id() -> StringName:
	return MODULE_ID


func get_module_anchor() -> Marker3D:
	return _module_anchor


func get_operations_entrance() -> StationDoor:
	return _operations_entrance


func get_vip_access() -> StationDoor:
	return _vip_access


func get_operations_room_marker() -> Marker3D:
	return _operations_room_anchor


func get_upper_floor_marker() -> Marker3D:
	return _upper_floor_anchor


func get_vip_access_marker() -> Marker3D:
	return _vip_access_anchor


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
		var marker := _route_markers[route_id] as Marker3D
		result[route_id] = marker.global_transform
	return result


func get_floor_elevations() -> PackedFloat32Array:
	return PackedFloat32Array([LOWER_FLOOR_ELEVATION, UPPER_FLOOR_ELEVATION])


func get_stair_profile() -> Dictionary:
	return {
		"step_count": STAIR_STEP_COUNT,
		"riser_height": STAIR_RISE,
		"tread_run": STAIR_RUN,
		"clear_width": STAIR_CLEAR_WIDTH,
		"minimum_head_clearance": STAIR_HEAD_CLEARANCE,
		"lower_elevation": LOWER_FLOOR_ELEVATION,
		"upper_elevation": UPPER_FLOOR_ELEVATION,
		"collision_solution": &"continuous_ramp_beneath_visible_treads",
	}


## Local-space surface samples down the centre of the continuous stair route.
func get_stair_surface_samples() -> PackedVector3Array:
	var samples := PackedVector3Array()
	for index in STAIR_STEP_COUNT:
		var progress := float(index) / float(STAIR_STEP_COUNT - 1)
		samples.append(Vector3(-5.7, progress * UPPER_FLOOR_ELEVATION + 0.11, 3.0 + progress * 9.8))
	return samples


func get_chair_count() -> int:
	return _chair_nodes.size()


func get_console_bay_count() -> int:
	return _console_nodes.size()


func get_service_wall() -> Node3D:
	return get_node_or_null("Structure/OperationsRoom/ServiceWall") as Node3D


func contains_operations_room(world_position: Vector3) -> bool:
	var local_position := to_local(world_position)
	var relative := local_position - OPERATIONS_ROOM_CENTER
	return absf(relative.x) <= OPERATIONS_ROOM_HALF_EXTENTS.x \
		and absf(relative.y) <= OPERATIONS_ROOM_HALF_EXTENTS.y \
		and absf(relative.z) <= OPERATIONS_ROOM_HALF_EXTENTS.z


func get_operations_room_volume() -> Dictionary:
	return {
		"local_center": OPERATIONS_ROOM_CENTER,
		"half_extents": OPERATIONS_ROOM_HALF_EXTENTS,
		"world_transform": global_transform * Transform3D(Basis.IDENTITY, OPERATIONS_ROOM_CENTER),
	}


func get_open_to_space_ratio() -> float:
	return OPEN_WALKABLE_AREA_ESTIMATE / (OPEN_WALKABLE_AREA_ESTIMATE + COVERED_WALKABLE_AREA_ESTIMATE)


## The root origin is the south connection plane. Integrators can place that
## origin at the end of an existing aft spine without reverse-engineering meshes.
func get_integration_footprint() -> Dictionary:
	return {
		"anchor_transform": _module_anchor.global_transform,
		"local_min": FOOTPRINT_MIN,
		"local_max": FOOTPRINT_MAX,
		"local_size": FOOTPRINT_MAX - FOOTPRINT_MIN,
		"approach_axis_local": Vector3.FORWARD,
		"module_extends_local": Vector3.BACK,
	}


func get_evidence_metadata() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"module_id": MODULE_ID,
		"evidence_status": EVIDENCE_STATUS,
		"source_bounded": true,
		"references": PackedStringArray(EVIDENCE_REFERENCES),
		"content_note": CONTENT_NOTE,
		"supported_invariants": PackedStringArray([
			"exposed modular station lattice with substantial negative space",
			"short vertical circulation near an open junction",
			"compact grey console room with broad windows",
			"cyan operated access and red VIP landmark",
		]),
		"modern_interpretations": PackedStringArray([
			"module name and exact dimensions",
			"asymmetric two-level arrangement",
			"operations furniture and service wall",
			"door mechanics and exact adjacency",
			"the project-original station panel material family mapped across floors, stair ramp, and pressure plates",
		]),
	}


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if _module_anchor == null:
		errors.append("module integration anchor is missing")
	if _operations_entrance == null:
		errors.append("operations entrance StationDoor is missing")
	if _vip_access == null:
		errors.append("VIP access StationDoor is missing")
	elif not _vip_access.deferred_access or not _vip_access.locked:
		errors.append("VIP access must remain locked and explicitly deferred")
	if _route_markers.size() < 7:
		errors.append("the complete lower, stair, room, upper, and VIP route is not exposed")
	if _chair_nodes.size() != 4:
		errors.append("operations room must expose exactly four physical chairs")
	if _console_nodes.size() != 3:
		errors.append("operations room must expose exactly three console bays")
	if get_service_wall() == null:
		errors.append("operations service wall is missing")
	if get_open_to_space_ratio() < 0.5:
		errors.append("less than half of the estimated walkable area is open to space")
	# The collision, performance, and lifecycle contracts are only meaningful if
	# this module rejects on them. Without these checks a drifted collision layer
	# or a blown budget is reported in the contract dictionary and validated
	# clean, so `validate_contract` would call the module valid anyway.
	var collision := get_collision_contract()
	if not bool(collision.all_layers_match_lifecycle):
		errors.append("static body collision layers differ from the current lifecycle state")
	if not bool(collision.all_masks_zero):
		errors.append("station structure must not query collision through a mask")
	if not bool(collision.all_shapes_present_and_enabled):
		errors.append("a walkable surface is missing an enabled collision shape")
	if not bool(get_performance_contract().within_budget):
		errors.append("module component counts exceed the declared quality budget")
	var lifecycle := get_lifecycle_contract()
	if not bool(lifecycle.reversible) \
		or not bool(lifecycle.visible_matches_enabled) \
		or not bool(lifecycle.collision_matches_enabled):
		errors.append("module lifecycle state does not match the enabled flag")
	if not bool(lifecycle.process_matches_lifecycle):
		errors.append("module keeps processing while disabled")
	return errors


func audit() -> Dictionary:
	var errors := get_validation_errors()
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"module_id": MODULE_ID,
		"evidence": get_evidence_metadata(),
		"route_ids": get_route_ids(),
		"floor_elevations": get_floor_elevations(),
		"stair_profile": get_stair_profile(),
		"operations_room": get_operations_room_volume(),
		"chair_count": get_chair_count(),
		"console_bay_count": get_console_bay_count(),
		"open_to_space_ratio": get_open_to_space_ratio(),
		"vip_deferred": _vip_access != null and _vip_access.deferred_access,
		"footprint": get_integration_footprint(),
	}


func get_audit_report() -> Dictionary:
	return audit().duplicate(true)


func get_component_roster() -> Dictionary:
	var roster := StationModuleContract.build_component_roster(self)
	roster["schema_version"] = SCHEMA_VERSION
	roster["module_id"] = MODULE_ID
	roster["chair_count"] = get_chair_count()
	roster["console_bay_count"] = get_console_bay_count()
	return roster


func get_collision_contract() -> Dictionary:
	var contract := StationModuleContract.build_collision_contract(
		self, WORLD_LAYER, _module_enabled
	)
	contract["schema_version"] = SCHEMA_VERSION
	return contract


func get_authority_contract() -> Dictionary:
	var contract := StationModuleContract.build_authority_contract(self)
	contract["schema_version"] = SCHEMA_VERSION
	return contract


func get_performance_contract() -> Dictionary:
	# Budgets are this module's own policy: declared regression ceilings measured
	# against the built module, not representative-hardware performance evidence.
	# The mesh ceiling sits just above the 532 primitives the stair treads,
	# railings, and service detail actually produce; it was previously set to 170,
	# a figure no build ever met.
	var contract := StationModuleContract.build_performance_contract(self, {
		"mesh_instances": 600,
		"static_bodies": 120,
		"collision_shapes": 120,
		"labels": 4,
		"lights": 12,
		"process_loops": 1,
		"physics_process_loops": 1,
	})
	contract["schema_version"] = SCHEMA_VERSION
	return contract


## Applied unconditionally. A no-op guard on the flag made drifted state
## unrepairable: if the nodes lost their layer or visibility while the flag still
## read `true`, the obvious repair call returned immediately and the module
## stayed unwalkable.
func set_module_enabled(enabled: bool) -> void:
	_module_enabled = enabled
	_apply_enabled_state()


func is_module_enabled() -> bool:
	return _module_enabled


func get_lifecycle_contract() -> Dictionary:
	# This module hides in place, so its own node is the visibility root.
	var contract := StationModuleContract.build_lifecycle_contract(
		self, WORLD_LAYER, _module_enabled, self
	)
	contract["schema_version"] = SCHEMA_VERSION
	contract["built"] = _built
	contract["build_generation"] = 1
	return contract


func _apply_enabled_state() -> void:
	StationModuleContract.apply_enabled_state(
		StationModuleContract.collect_static_bodies(self), WORLD_LAYER, _module_enabled, self
	)


func _index_routes() -> void:
	_route_markers = {
		&"approach": _route_approach,
		&"lower-junction": _route_lower_junction,
		&"stair-base": _route_stair_base,
		&"stair-top": _route_stair_top,
		&"operations-room": _operations_room_anchor,
		&"upper-floor": _upper_floor_anchor,
		&"vip-landmark": _vip_access_anchor,
	}
	for route_id: StringName in _route_markers.keys():
		var marker := _route_markers[route_id] as Marker3D
		marker.set_meta("station_route_marker", true)
		marker.set_meta("route_id", route_id)
	# Only the outward approach face is a station connection slot. Every other
	# marker is an internal waypoint, and the VIP landmark is a deliberate dead
	# end, so none of them may join the station adjacency graph.
	_route_approach.set_meta(StationModuleContract.CONNECTION_SLOT_META, HUB_CONNECTION_SLOT)
	_operations_room_anchor.set_meta("station_room_marker", true)
	_operations_room_anchor.set_meta("room_id", &"aft-operations")
	_upper_floor_anchor.set_meta("station_upper_floor_marker", true)
	_vip_access_anchor.set_meta("station_vip_landmark", true)


func _create_materials() -> void:
	# Layered PBR values and a project-original lighting-neutral station panel set
	# keep broad pressure surfaces from reading as uniformly shaded primitives.
	_materials["off_white"] = _material(Color("cbd0ce"), 0.38, 0.34)
	_materials["panel_light"] = _material(Color("aeb8b8"), 0.42, 0.29)
	_materials["warm_grey"] = _material(Color("818b8b"), 0.46, 0.39)
	_materials["mid_grey"] = _material(Color("526166"), 0.58, 0.31)
	_materials["hull_dark"] = _material(Color("29363a"), 0.62, 0.28)
	# Floor-role twins of the structural greys. Both halves of each pair now carry
	# the same panel maps, so hue and relief no longer tell a deck from the wall
	# above it; only the material response can. A walked-on deck is a coated,
	# scuffed, trafficked surface, so each floor twin is deliberately less metallic
	# and markedly rougher than the structural member it meets at the skirting.
	# Before this the twins were byte-identical in every PBR value, which is why
	# two surfaces differing only in hue read as painted plastic.
	_materials["off_white_floor"] = _material(Color("cbd0ce"), 0.26, 0.52)
	_materials["warm_grey_floor"] = _material(Color("818b8b"), 0.30, 0.55)
	_materials["mid_grey_floor"] = _material(Color("526166"), 0.38, 0.50)
	_materials["hull_dark_floor"] = _material(Color("29363a"), 0.40, 0.46)
	_materials["graphite"] = _material(Color("141d21"), 0.48, 0.47)
	_materials["rubber"] = _material(Color("101719"), 0.06, 0.86)
	_materials["cyan"] = _material(Color("55dce2"), 0.12, 0.34, Color("3acbd3"), 1.45)
	_materials["cyan_dim"] = _material(Color("3a7479"), 0.34, 0.42, Color("2aa6ae"), 0.35)
	_materials["gold"] = _material(Color("d0a350"), 0.54, 0.3, Color("8f5f20"), 0.2)
	# Non-emissive structural twin of `gold`. `gold` carries a faint emission and
	# is the module's *cue* colour: route arc tiles, cabinet status, control lamps
	# and signage. It was also carrying the physical brass furniture — handrails,
	# collars, column feet, fasteners — and those were the only unmapped parts left
	# in a plated frame, so a 0.07 m handrail read as a flat yellow stick bolted to
	# a plated post. `brass` takes the furniture into the panel family and leaves
	# every cue on `gold`, unchanged. Rougher and less metallic than `gold` too:
	# handled brass is worn satin, not the lacquered accent of a lit legend.
	_materials["brass"] = _material(Color("d0a350"), 0.46, 0.44)
	_materials["copper"] = _material(Color("9d6844"), 0.78, 0.26)
	_materials["red"] = _material(Color("d84d47"), 0.18, 0.4, Color("b82c2c"), 1.15)
	_materials["screen"] = _material(Color("b9f2ef"), 0.08, 0.24, Color("68dde2"), 1.25)
	_materials["screen_dark"] = _material(Color("16363b"), 0.22, 0.36, Color("2b9aa3"), 0.22)
	_materials["worklight"] = _material(Color("edf8f5"), 0.02, 0.2, Color("d7ffff"), 2.5)
	_materials["amber_light"] = _material(Color("ffdba0"), 0.02, 0.24, Color("f1a84e"), 1.8)
	_materials["glass"] = _transparent_material(Color(0.38, 0.68, 0.72, 0.18), 0.03, 0.08)
	_materials["chair"] = _material(Color("4a5557"), 0.14, 0.7)
	_materials["chair_pad"] = _material(Color("273236"), 0.04, 0.92)
	# One call per key into the published kit recipe, rather than a fourth inline
	# copy of it. The recipe includes `normal_scale = 1.0`, re-frozen from 0.48 by
	# a rendered sweep at 0.48 / 1.0 / 1.4 / 1.9: at 0.48 a plated wall at eye
	# height is nearly featureless, at 1.9 the plate faces dome into embossed
	# plastic. Every module shares the constant so a deck and the wall beside it
	# cannot disagree — which is exactly what an inline copy per module was free to
	# get wrong.
	for key in [
		"off_white",
		"off_white_floor",
		"panel_light",
		"warm_grey",
		"warm_grey_floor",
		"mid_grey_floor",
		"hull_dark_floor",
		# `mid_grey` and `hull_dark` are the same colours as their `_floor`
		# twins and were the module's last flat scalar structural greys, so a
		# wall read as plastic while the plated floor met it at the skirting.
		"mid_grey",
		"hull_dark",
		# Brass furniture. The handrails and collars are the parts a player stands
		# closest to; leaving them scalar put a flat yellow stick on top of a
		# plated post at arm's reach.
		"brass",
	]:
		StationSurfaceKit.apply_panel_triplanar(_materials[key] as StandardMaterial3D, PANEL_SURFACE_SCALE)


func _build_structure() -> void:
	var structure := Node3D.new()
	structure.name = "Structure"
	add_child(structure)

	_build_open_lower_deck(structure)
	_build_stair_and_upper_deck(structure)
	_build_operations_room(structure)
	_build_vip_landmark(structure)
	_build_open_structure_details(structure)


func _build_open_lower_deck(structure: Node3D) -> void:
	var lower := Node3D.new()
	lower.name = "LowerOpenDeck"
	structure.add_child(lower)

	_box(lower, "ConnectionDeck", Vector3(0.0, -0.32, 2.5), Vector3(7.0, 0.64, 5.0), _materials["off_white_floor"])
	_box(lower, "JunctionDeck", Vector3(0.0, -0.32, 7.5), Vector3(11.0, 0.64, 5.0), _materials["warm_grey_floor"])
	# The stair begins west of ConnectionDeck. Its former first tread and ramp
	# floated across a 0.8 m physics gap, so this compact landing gives a
	# straight, level run onto the unchanged ramp. It shares its whole eastern
	# strip with ConnectionDeck: the two are coplanar, and that strip is the gate
	# onto the stair, so no rail may stand in it (MAP-001).
	_box(lower, "StairBaseLanding", STAIR_BASE_LANDING_CENTRE, STAIR_BASE_LANDING_SIZE, _materials["off_white_floor"])
	_box(lower, "JunctionInset", Vector3(0.0, 0.025, 7.35), Vector3(5.8, 0.05, 3.5), _materials["off_white_floor"], false)
	_box(lower, "RouteStripe", Vector3(0.0, 0.06, 4.8), Vector3(0.18, 0.055, 9.1), _materials["cyan"], false)

	# The incomplete ring makes the junction readable without becoming another
	# monumental runway gate. Its open west quadrant points toward the stair.
	for angle in [-70.0, -35.0, 0.0, 35.0, 70.0, 105.0, 140.0, 175.0]:
		var radians := deg_to_rad(angle)
		var ring_position := Vector3(cos(radians) * 3.75, 0.11, 7.45 + sin(radians) * 1.75)
		_box(lower, "JunctionArcTile", ring_position, Vector3(1.25, 0.08, 0.24), _materials["gold"], false, Vector3(0, -angle + 90.0, 0))

	# Sparse rails leave the approach and circulation branches genuinely open.
	# The port rail guards only the stretch of the connection deck's west edge that
	# actually overhangs a drop. It stops at the stair-base landing's southern edge,
	# because beyond that the landing *is* the floor and the rail would fence the
	# only lateral mount onto the stair (MAP-001).
	_add_rail(
		lower,
		Vector3(-3.35, 0.0, 0.25),
		Vector3(-3.35, 0.0, _stair_base_landing_south_edge() - 0.05),
		"ApproachPortRail"
	)
	# Opening the stair gate exposes the landing's own outboard edges, which
	# previously nothing could walk to. Guard them, and leave the whole eastern
	# side of the landing open as the gate itself.
	var landing_south := _stair_base_landing_south_edge()
	var landing_west := STAIR_BASE_LANDING_CENTRE.x - STAIR_BASE_LANDING_SIZE.x * 0.5
	_add_rail(
		lower,
		Vector3(landing_west + 0.06, 0.0, landing_south + 0.06),
		Vector3(-3.4, 0.0, landing_south + 0.06),
		"StairBaseSouthRail"
	)
	_add_rail(
		lower,
		Vector3(landing_west + 0.06, 0.0, landing_south + 0.06),
		Vector3(landing_west + 0.06, 0.0, 2.85),
		"StairBaseWestRail"
	)
	_add_rail(lower, Vector3(3.35, 0.0, 0.25), Vector3(3.35, 0.0, 3.3), "ApproachStarboardRail")
	_add_rail(lower, Vector3(5.35, 0.0, 5.15), Vector3(5.35, 0.0, 8.8), "JunctionEastRail")

	# A separate, non-colliding service envelope breaks up the slab while leaving
	# the tested floor plane and open circulation samples completely unchanged.
	for side in [-1.0, 1.0]:
		var edge_x := float(side) * 3.5
		_beam_between(lower, "ApproachEdgeTube", Vector3(edge_x, -0.38, 0.1), Vector3(edge_x, -0.38, 5.0), 0.105, _materials["mid_grey"], false)
		for z_position in [0.65, 2.5, 4.35]:
			_cylinder(lower, "ApproachEdgeCollar", Vector3(edge_x, -0.38, z_position), 0.115, 0.16, _materials["brass"], false, Vector3(90, 0, 0))
		var junction_edge_x := float(side) * 5.5
		_beam_between(lower, "JunctionEdgeTube", Vector3(junction_edge_x, -0.42, 5.0), Vector3(junction_edge_x, -0.42, 10.0), 0.13, _materials["hull_dark"], false)
		_beam_between(lower, "LowerLongitudinalTruss", Vector3(float(side) * 3.9, -0.86, 5.15), Vector3(float(side) * 4.9, -0.86, 9.85), 0.11, _materials["mid_grey"], false)
		for z_position in [5.3, 7.5, 9.7]:
			_beam_between(
				lower,
				"LowerTrussStrut",
				Vector3(float(side) * 3.75, -0.28, z_position - 0.72),
				Vector3(float(side) * 4.75, -0.9, z_position + 0.72),
				0.085,
				_materials["warm_grey"],
				false
			)

	for z_position in [1.15, 2.65, 4.15, 6.15, 8.55]:
		_box(lower, "DeckExpansionJoint", Vector3(0, 0.072, z_position), Vector3(6.1 if z_position < 5.0 else 9.8, 0.018, 0.045), _materials["graphite"], false)
	for side in [-1.0, 1.0]:
		_box(
			lower,
			"RecessedServiceHatch",
			Vector3(float(side) * 2.65, 0.071, 7.4),
			Vector3(1.55, 0.025, 1.15),
			_materials["hull_dark"],
			false
		)
		for corner_x in [-0.58, 0.58]:
			for corner_z in [-0.39, 0.39]:
				_cylinder(
					lower,
					"HatchFastener",
					Vector3(float(side) * 2.65 + corner_x, 0.09, 7.4 + corner_z),
					0.035,
					0.025,
					_materials["brass"],
					false
				)
	for light_z in [1.0, 4.25, 8.9]:
		_box(lower, "LowRouteLight", Vector3(0, 0.088, light_z), Vector3(0.38, 0.025, 0.12), _materials["cyan"], false)


func _build_stair_and_upper_deck(structure: Node3D) -> void:
	var circulation := Node3D.new()
	circulation.name = "Circulation"
	structure.add_child(circulation)

	var start := Vector3(-5.7, LOWER_FLOOR_ELEVATION, 3.0)
	var finish := Vector3(-5.7, UPPER_FLOOR_ELEVATION, 12.8)
	var direction := finish - start
	var ramp_length := direction.length()
	var ramp_angle := -atan2(direction.y, direction.z)
	var ramp := StaticBody3D.new()
	ramp.name = "ContinuousStairRamp"
	ramp.collision_layer = WORLD_LAYER
	ramp.collision_mask = 0
	ramp.position = (start + finish) * 0.5
	ramp.rotation.x = ramp_angle
	circulation.add_child(ramp)
	var ramp_mesh_instance := MeshInstance3D.new()
	ramp_mesh_instance.name = "RampMesh"
	var ramp_mesh := BoxMesh.new()
	ramp_mesh.size = Vector3(STAIR_CLEAR_WIDTH, 0.22, ramp_length)
	ramp_mesh_instance.mesh = ramp_mesh
	ramp_mesh_instance.material_override = _materials["mid_grey_floor"]
	ramp.add_child(ramp_mesh_instance)
	var ramp_collision := CollisionShape3D.new()
	ramp_collision.name = "RampCollision"
	var ramp_shape := BoxShape3D.new()
	ramp_shape.size = Vector3(STAIR_CLEAR_WIDTH, 0.22, ramp_length)
	ramp_collision.shape = ramp_shape
	ramp.add_child(ramp_collision)

	for index in STAIR_STEP_COUNT:
		var progress := float(index) / float(STAIR_STEP_COUNT - 1)
		var tread_position := Vector3(
			-5.7,
			progress * UPPER_FLOOR_ELEVATION + 0.06,
			3.0 + progress * 9.8
		)
		_box(circulation, "VisibleTread%02d" % index, tread_position, Vector3(2.92, 0.1, 0.72), _materials["off_white_floor"], false)
		_box(
			circulation,
			"TreadNosing%02d" % index,
			tread_position + Vector3(0, 0.075, -0.32),
			Vector3(2.76, 0.045, 0.075),
			_materials["graphite"] if index % 3 else _materials["cyan_dim"],
			false
		)

	# Twin tubular stringers make the climb read as an engineered assembly rather
	# than fifteen floating boxes. They sit beneath the unchanged navigation ramp.
	for stringer_side in [-1.0, 1.0]:
		var stringer_x := -5.7 + float(stringer_side) * 1.28
		_beam_between(
			circulation,
			"StairStringer",
			Vector3(stringer_x, start.y - 0.16, start.z),
			Vector3(stringer_x, finish.y - 0.16, finish.z),
			0.13,
			_materials["hull_dark"],
			false
		)
		for support_progress in [0.0, 0.33, 0.66, 1.0]:
			var route_support: Vector3 = start.lerp(finish, float(support_progress))
			_cylinder(
				circulation,
				"StringerCollar",
				Vector3(stringer_x, route_support.y - 0.16, route_support.z),
				0.145,
				0.16,
				_materials["copper"],
				false,
				Vector3(90, 0, 0)
			)

	for side in [-1.0, 1.0]:
		var rail_x: float = -5.7 + float(side) * 1.7
		# A stair rail that stands on the stair-base landing is a fence across a
		# walking surface, not a guard over a drop. Where the rail line crosses the
		# landing footprint it starts where the ramp has climbed clear of it; the
		# outboard line, which overhangs the void, still runs the full length.
		var rail_start_progress := _stair_rail_start_progress(rail_x, start, finish)
		var rail_start: Vector3 = start.lerp(finish, rail_start_progress)
		for raw_progress in [0.0, 0.25, 0.5, 0.75, 1.0]:
			var progress := float(raw_progress)
			if progress < rail_start_progress:
				continue
			var route_point: Vector3 = start.lerp(finish, progress)
			_cylinder(circulation, "StairRailPost", Vector3(rail_x, route_point.y + 0.7, route_point.z), 0.055, 1.4, _materials["warm_grey"], true)
		_beam_between(
			circulation,
			"StairHandrail",
			Vector3(rail_x, rail_start.y + 1.38, rail_start.z),
			Vector3(rail_x, finish.y + 1.38, finish.z),
			0.075,
			_materials["brass"],
			true
		)
		_beam_between(
			circulation,
			"StairMidRail",
			Vector3(rail_x, rail_start.y + 0.76, rail_start.z),
			Vector3(rail_x, finish.y + 0.76, finish.z),
			0.045,
			_materials["mid_grey"],
			false
		)

	for light_progress in [0.18, 0.5, 0.82]:
		var stair_light_position: Vector3 = start.lerp(finish, float(light_progress))
		_box(
			circulation,
			"StairCourtesyLight",
			stair_light_position + Vector3(-1.47, 0.36, 0),
			Vector3(0.035, 0.22, 0.38),
			_materials["amber_light"],
			false
		)
		_omni_light(
			circulation,
			"StairPoolLight",
			stair_light_position + Vector3(-1.25, 0.55, 0),
			Color("e9b66e"),
			0.32,
			3.2
		)

	var upper := Node3D.new()
	upper.name = "UpperOpenDeck"
	structure.add_child(upper)
	_box(upper, "UpperFloor", Vector3(-5.15, 3.88, 16.55), Vector3(10.3, 0.64, 8.1), _materials["off_white_floor"])
	_box(upper, "UpperFloorInset", Vector3(-5.15, 4.225, 16.4), Vector3(7.7, 0.05, 5.8), _materials["warm_grey_floor"], false)
	_box(upper, "UpperRouteStripe", Vector3(-5.15, 4.26, 16.2), Vector3(0.16, 0.05, 6.5), _materials["red"], false)
	_add_rail(upper, Vector3(-10.1, 4.2, 12.7), Vector3(-10.1, 4.2, 20.25), "UpperWestRail")
	_add_rail(upper, Vector3(-9.8, 4.2, 12.55), Vector3(-7.45, 4.2, 12.55), "UpperSouthRail")
	_add_rail(upper, Vector3(-3.9, 4.2, 12.55), Vector3(-0.25, 4.2, 12.55), "UpperSouthReturnRail")
	for z_position in [13.25, 16.5, 19.75]:
		_box(upper, "UpperDeckSeam", Vector3(-5.15, 4.247, z_position), Vector3(8.8, 0.018, 0.05), _materials["graphite"], false)
		_beam_between(
			upper,
			"UpperUndersideCrossMember",
			Vector3(-9.8, 3.45, z_position),
			Vector3(-0.5, 3.45, z_position),
			0.12,
			_materials["hull_dark"],
			false
		)
	for support_x in [-9.4, -5.15, -0.9]:
		_beam_between(upper, "UpperDiagonalBrace", Vector3(support_x, 3.5, 13.0), Vector3(support_x, 2.35, 15.1), 0.1, _materials["mid_grey"], false)
		_beam_between(upper, "UpperDiagonalBraceReturn", Vector3(support_x, 3.5, 20.0), Vector3(support_x, 2.35, 17.9), 0.1, _materials["mid_grey"], false)


func _build_operations_room(structure: Node3D) -> void:
	var room := Node3D.new()
	room.name = "OperationsRoom"
	structure.add_child(room)

	_box(room, "OperationsFloor", Vector3(5.6, -0.32, 13.2), Vector3(10.4, 0.64, 8.2), _materials["off_white_floor"])
	_box(room, "OperationsCeiling", Vector3(5.6, 4.75, 13.2), Vector3(10.4, 0.48, 8.2), _materials["warm_grey"])
	_box(room, "WestWall", Vector3(0.4, 2.38, 13.25), Vector3(0.38, 4.75, 7.8), _materials["warm_grey"])
	_box(room, "SouthWallLeft", Vector3(0.5, 2.1, 9.1), Vector3(0.6, 4.2, 0.42), _materials["warm_grey"])
	_box(room, "SouthWallDoorPocket", Vector3(7.4, 2.1, 9.1), Vector3(6.6, 4.2, 0.42), _materials["warm_grey"])
	for floor_x in [1.75, 5.6, 9.45]:
		for floor_z in [10.55, 13.15, 15.75]:
			_box(
				room,
				"FloorPressurePlate",
				Vector3(float(floor_x), 0.015, float(floor_z)),
				Vector3(3.45, 0.025, 2.25),
				_materials["hull_dark_floor"] if int(floor_x * 10.0 + floor_z * 10.0) % 2 else _materials["mid_grey_floor"],
				false
			)
		for seam_z in [11.85, 14.45]:
			_box(room, "FloorSeam", Vector3(float(floor_x), 0.042, float(seam_z)), Vector3(3.25, 0.018, 0.035), _materials["rubber"], false)
	# Rounded guards and a tubular roof rail soften the pod silhouette while its
	# dependable box colliders retain a clean, testable room envelope.
	for corner in [
		Vector3(0.4, 2.4, 9.18),
		Vector3(10.8, 2.4, 9.18),
		Vector3(0.4, 2.4, 17.24),
		Vector3(10.8, 2.4, 17.24),
	]:
		_cylinder(room, "RoundedPodCorner", corner, 0.24, 4.8, _materials["mid_grey"], false)
		_torus(room, "PodCornerCollar", corner + Vector3.UP * 2.05, 0.25, 0.34, _materials["brass"], Vector3(90, 0, 0))
	_beam_between(room, "WindowRoofRail", Vector3(0.7, 5.08, 17.15), Vector3(10.5, 5.08, 17.15), 0.11, _materials["off_white"], false)

	# A wide north-facing window dominates the room. Transparent panes remain
	# physical barriers, while narrow structure preserves the sightline.
	_box(room, "WindowSill", Vector3(5.6, 0.38, 17.3), Vector3(10.4, 0.76, 0.42), _materials["warm_grey"])
	_box(room, "WindowHeader", Vector3(5.6, 4.38, 17.3), Vector3(10.4, 0.74, 0.42), _materials["warm_grey"])
	for x_position in [0.55, 4.0, 7.2, 10.65]:
		_box(room, "WindowMullion", Vector3(x_position, 2.4, 17.3), Vector3(0.22, 3.35, 0.44), _materials["mid_grey"])
	for pane_index in 3:
		var pane_x := 2.25 + float(pane_index) * 3.3
		_box(room, "WindowPane%02d" % pane_index, Vector3(pane_x, 2.42, 17.29), Vector3(3.05, 3.25, 0.12), _materials["glass"])
		_box(room, "WindowLowerFrame%02d" % pane_index, Vector3(pane_x, 0.83, 17.08), Vector3(3.0, 0.12, 0.18), _materials["hull_dark"], false)
		_box(room, "WindowUpperFrame%02d" % pane_index, Vector3(pane_x, 4.0, 17.08), Vector3(3.0, 0.12, 0.18), _materials["hull_dark"], false)

	_build_operations_shell_detail(room)

	# Three operator stations face the broad exterior sightline.
	for bay_index in 3:
		var bay := Node3D.new()
		bay.name = "ConsoleBay%02d" % (bay_index + 1)
		bay.position = Vector3(3.15 + float(bay_index) * 2.85, 0.0, 15.7)
		bay.set_meta("station_console_bay", true)
		bay.set_meta("console_index", bay_index)
		room.add_child(bay)
		_console_nodes.append(bay)
		_box(bay, "ConsolePlinth", Vector3(0, 0.66, 0), Vector3(2.25, 1.32, 0.9), _materials["mid_grey"])
		_box(bay, "PlinthKick", Vector3(0, 0.18, -0.47), Vector3(1.82, 0.28, 0.12), _materials["rubber"], false)
		_box(bay, "PlinthInset", Vector3(0, 0.7, -0.47), Vector3(1.72, 0.48, 0.08), _materials["hull_dark"], false)
		for support_x in [-0.86, 0.86]:
			_cylinder(bay, "ConsoleShockMount", Vector3(float(support_x), 0.23, 0.34), 0.085, 0.38, _materials["copper"], false)
			_torus(bay, "ConsoleShockCollar", Vector3(float(support_x), 0.08, 0.34), 0.09, 0.13, _materials["rubber"], Vector3(90, 0, 0))
		_box(bay, "AngledConsole", Vector3(0, 1.26, -0.1), Vector3(2.18, 0.28, 1.0), _materials["graphite"], true, Vector3(-12, 0, 0))
		_box(bay, "ConsoleEdgeRail", Vector3(0, 1.43, -0.56), Vector3(2.18, 0.09, 0.09), _materials["panel_light"], false, Vector3(-12, 0, 0))
		_box(bay, "PrimaryDisplay", Vector3(0, 1.43, -0.18), Vector3(1.55, 0.035, 0.56), _materials["screen"], false, Vector3(-12, 0, 0))
		for display_index in 3:
			_box(
				bay,
				"DisplayDataBand",
				Vector3(0, 1.454 + float(display_index) * 0.005, -0.33 + float(display_index) * 0.16),
				Vector3(1.25 - float(display_index) * 0.15, 0.012, 0.035),
				_materials["screen_dark"],
				false,
				Vector3(-12, 0, 0)
			)
		for lamp_index in 3:
			var accent: Material = _materials["cyan"] if lamp_index < 2 else _materials["gold"]
			_cylinder(bay, "ControlLamp", Vector3(-0.56 + float(lamp_index) * 0.56, 1.5, -0.03), 0.06, 0.04, accent, false, Vector3(90, 0, 0))

	# Three operator chairs plus a side-facing coordinator chair.
	for chair_index in 4:
		var chair_position: Vector3
		var chair_yaw := 0.0
		if chair_index < 3:
			chair_position = Vector3(3.15 + float(chair_index) * 2.85, 0.0, 13.55)
		else:
			chair_position = Vector3(1.7, 0.0, 12.0)
			chair_yaw = -72.0
		_build_chair(room, chair_index, chair_position, chair_yaw)

	_build_service_wall(room)
	_build_operations_lighting(room)
	_text_sign(room, "AFT OPERATIONS", Vector3(7.2, 3.7, 9.31), Vector3(0, 180, 0), 0.29, _materials["cyan"])


func _build_operations_shell_detail(room: Node3D) -> void:
	var envelope := Node3D.new()
	envelope.name = "VisualPressureEnvelope"
	envelope.set_meta("visual_detail_only", true)
	room.add_child(envelope)

	# Narrow roof cassettes and raised ribs replace the single-box silhouette with
	# a pressure-shell rhythm. The underlying roof remains the sole collider.
	for panel_index in 5:
		var panel_x := 1.25 + float(panel_index) * 2.18
		_box(
			envelope,
			"RoofCassette%02d" % panel_index,
			Vector3(panel_x, 5.015 + (0.025 if panel_index % 2 else 0.0), 13.2),
			Vector3(1.82, 0.11, 7.35),
			_materials["panel_light"] if panel_index % 2 else _materials["warm_grey"],
			false
		)
	for rib_index in 5:
		var rib_z := 9.45 + float(rib_index) * 1.88
		_arch_across_x(
			envelope,
			"PressureRib%02d" % rib_index,
			rib_z,
			0.28,
			10.92,
			4.82,
			5.58,
			0.105,
			_materials["off_white"]
		)
	_beam_between(envelope, "RoofServiceSpine", Vector3(5.6, 5.62, 9.25), Vector3(5.6, 5.62, 17.22), 0.15, _materials["hull_dark"], false)
	for spine_z in [9.55, 11.4, 13.25, 15.1, 16.95]:
		_torus(envelope, "SpineClamp", Vector3(5.6, 5.62, float(spine_z)), 0.16, 0.225, _materials["copper"], Vector3(90, 0, 0))

	# Low-profile environmental hardware gives the roof a credible service layer
	# without implying a source-authenticated room function.
	for vent_index in 2:
		var vent_x := 3.05 + float(vent_index) * 5.05
		_cylinder(envelope, "RoofVent", Vector3(vent_x, 5.18, 13.0), 0.42, 0.28, _materials["hull_dark"], false)
		_torus(envelope, "RoofVentCollar", Vector3(vent_x, 5.31, 13.0), 0.34, 0.46, _materials["mid_grey"])
		for louvre_index in 3:
			_box(
				envelope,
				"VentLouvre",
				Vector3(vent_x - 0.24 + float(louvre_index) * 0.24, 5.34, 13.0),
				Vector3(0.09, 0.06, 0.58),
				_materials["graphite"],
				false
			)

	# Layered side cladding is offset just beyond the physical room shell. Dark
	# reveal channels make each plate legible under oblique exterior lighting.
	for wall_x in [0.16, 11.02]:
		for panel_index in 4:
			var panel_z := 10.2 + float(panel_index) * 2.02
			_box(
				envelope,
				"SideCladding",
				Vector3(float(wall_x), 2.42, panel_z),
				Vector3(0.12, 3.7, 1.68),
				_materials["panel_light"] if panel_index % 2 else _materials["mid_grey"],
				false
			)
			_box(
				envelope,
				"SideReveal",
				Vector3(float(wall_x) + (0.065 if wall_x < 1.0 else -0.065), 2.42, panel_z + 0.9),
				Vector3(0.035, 3.5, 0.065),
				_materials["rubber"],
				false
			)
		for rail_y in [0.55, 4.28]:
			_beam_between(
				envelope,
				"SideShellRail",
				Vector3(float(wall_x), float(rail_y), 9.4),
				Vector3(float(wall_x), float(rail_y), 17.02),
				0.085,
				_materials["hull_dark"],
				false
			)

	# The occupied south facade is kept clear of the real doorway at x=2.2.
	for panel_x in [5.0, 7.25, 9.5]:
		_box(
			envelope,
			"EntryFacadePanel",
			Vector3(float(panel_x), 2.42, 8.85),
			Vector3(1.82, 3.55, 0.12),
			_materials["warm_grey"] if panel_x < 7.0 else _materials["panel_light"],
			false
		)
		_box(envelope, "FacadeReveal", Vector3(float(panel_x), 2.42, 8.775), Vector3(1.5, 2.95, 0.035), _materials["hull_dark"], false)
	_beam_between(envelope, "EntryHeaderTube", Vector3(0.25, 4.55, 8.78), Vector3(10.9, 4.55, 8.78), 0.11, _materials["off_white"], false)
	_beam_between(envelope, "WindowEyebrow", Vector3(0.35, 4.72, 17.55), Vector3(10.85, 4.72, 17.55), 0.14, _materials["hull_dark"], false)
	for mullion_x in [0.45, 4.0, 7.2, 10.75]:
		_beam_between(
			envelope,
			"WindowOuterFrame",
			Vector3(float(mullion_x), 0.6, 17.52),
			Vector3(float(mullion_x), 4.45, 17.52),
			0.12,
			_materials["off_white"],
			false
		)

	# Underside keels and diagonal outriggers are deliberately visual-only. They
	# are prominent in the exterior evidence camera and retain the exact floor hit.
	for keel_x in [1.3, 5.6, 9.9]:
		_beam_between(envelope, "UndersideKeel", Vector3(float(keel_x), -0.72, 9.25), Vector3(float(keel_x), -0.72, 17.1), 0.15, _materials["hull_dark"], false)
	for z_position in [9.55, 11.45, 13.35, 15.25, 17.0]:
		_beam_between(envelope, "UnderfloorCrossMember", Vector3(0.45, -0.68, float(z_position)), Vector3(10.75, -0.68, float(z_position)), 0.12, _materials["mid_grey"], false)
		_beam_between(envelope, "UnderfloorBracePort", Vector3(0.55, -0.5, float(z_position) - 0.65), Vector3(3.15, -1.05, float(z_position) + 0.65), 0.085, _materials["warm_grey"], false)
		_beam_between(envelope, "UnderfloorBraceStarboard", Vector3(10.65, -0.5, float(z_position) - 0.65), Vector3(8.05, -1.05, float(z_position) + 0.65), 0.085, _materials["warm_grey"], false)

	# A restrained exterior utility run adds scale and material contrast.
	_beam_between(envelope, "ExteriorCopperFeed", Vector3(11.18, 0.82, 10.0), Vector3(11.18, 0.82, 16.25), 0.06, _materials["copper"], false)
	for pipe_z in [10.2, 12.2, 14.2, 16.2]:
		_torus(envelope, "ExteriorPipeClamp", Vector3(11.18, 0.82, float(pipe_z)), 0.065, 0.1, _materials["graphite"], Vector3(90, 0, 0))
	for lamp_position in [Vector3(0.1, 3.9, 9.45), Vector3(11.1, 3.9, 9.45), Vector3(0.1, 3.9, 16.9), Vector3(11.1, 3.9, 16.9)]:
		_box(envelope, "ExteriorWorklightHousing", lamp_position, Vector3(0.22, 0.4, 0.52), _materials["hull_dark"], false)
		_box(envelope, "ExteriorWorklightLens", lamp_position + Vector3(0, 0, -0.27), Vector3(0.13, 0.22, 0.035), _materials["amber_light"], false)


func _build_operations_lighting(room: Node3D) -> void:
	var lighting := Node3D.new()
	lighting.name = "LocalizedLighting"
	lighting.set_meta("forward_plus_local_lighting", true)
	room.add_child(lighting)
	for z_position in [11.15, 14.15, 16.15]:
		_box(lighting, "CeilingLuminaireBody", Vector3(5.6, 4.47, float(z_position)), Vector3(3.35, 0.11, 0.48), _materials["hull_dark"], false)
		_box(lighting, "CeilingLuminaireLens", Vector3(5.6, 4.405, float(z_position)), Vector3(2.85, 0.035, 0.24), _materials["worklight"], false)
		_omni_light(lighting, "OperationsPoolLight", Vector3(5.6, 4.0, float(z_position)), Color("d9f6f3"), 0.62, 5.6)
	for cove_x in [0.86, 10.34]:
		_beam_between(lighting, "CeilingCoveRail", Vector3(float(cove_x), 4.3, 9.55), Vector3(float(cove_x), 4.3, 16.85), 0.055, _materials["cyan_dim"], false)
	_box(lighting, "DoorThresholdLight", Vector3(2.2, 0.065, 9.36), Vector3(2.35, 0.04, 0.09), _materials["cyan"], false)
	_omni_light(lighting, "DoorPoolLight", Vector3(2.2, 2.6, 10.0), Color("72d9d9"), 0.35, 3.8)


func _build_chair(parent: Node3D, chair_index: int, chair_position: Vector3, yaw: float) -> void:
	var chair := Node3D.new()
	chair.name = "OperationsChair%02d" % (chair_index + 1)
	chair.position = chair_position
	chair.rotation_degrees.y = yaw
	chair.set_meta("station_chair", true)
	chair.set_meta("chair_index", chair_index)
	parent.add_child(chair)
	_chair_nodes.append(chair)
	_cylinder(chair, "Pedestal", Vector3(0, 0.38, 0), 0.18, 0.76, _materials["mid_grey"], true)
	_cylinder(chair, "Foot", Vector3(0, 0.08, 0), 0.52, 0.12, _materials["graphite"], true)
	_torus(chair, "PedestalBearing", Vector3(0, 0.68, 0), 0.18, 0.25, _materials["copper"])
	_box(chair, "SeatShell", Vector3(0, 0.8, 0), Vector3(1.03, 0.19, 0.98), _materials["chair"], true)
	_box(chair, "SeatCushion", Vector3(0, 0.93, -0.06), Vector3(0.83, 0.12, 0.74), _materials["chair_pad"], false, Vector3(-3, 0, 0))
	_box(chair, "BackFrame", Vector3(0, 1.48, 0.43), Vector3(1.0, 1.32, 0.18), _materials["chair"], true, Vector3(-7, 0, 0))
	_box(chair, "BackCushion", Vector3(0, 1.51, 0.3), Vector3(0.78, 0.92, 0.1), _materials["chair_pad"], false, Vector3(-7, 0, 0))
	_box(chair, "Headrest", Vector3(0, 2.12, 0.5), Vector3(0.68, 0.31, 0.16), _materials["warm_grey"], false, Vector3(-7, 0, 0))
	for side in [-1.0, 1.0]:
		var arm_x := float(side) * 0.58
		_beam_between(chair, "ArmSupport", Vector3(arm_x, 0.82, 0.12), Vector3(arm_x, 1.2, 0.12), 0.055, _materials["mid_grey"], false)
		_box(chair, "ArmPad", Vector3(arm_x, 1.24, -0.05), Vector3(0.16, 0.11, 0.62), _materials["chair_pad"], false)
		_beam_between(chair, "BackSideRail", Vector3(arm_x * 0.78, 1.0, 0.45), Vector3(arm_x * 0.78, 2.0, 0.52), 0.055, _materials["mid_grey"], false)


func _build_service_wall(room: Node3D) -> void:
	var service := Node3D.new()
	service.name = "ServiceWall"
	service.position = Vector3(10.65, 0.0, 12.55)
	service.set_meta("station_service_wall", true)
	room.add_child(service)

	_box(service, "ServiceWallBody", Vector3(0, 2.35, 0), Vector3(0.42, 4.7, 6.2), _materials["warm_grey"])
	for cabinet_index in 3:
		var z_position := -2.05 + float(cabinet_index) * 2.05
		_box(service, "ServiceCabinet%02d" % cabinet_index, Vector3(-0.3, 1.72, z_position), Vector3(0.35, 2.75, 1.55), _materials["off_white"], false)
		_box(service, "CabinetRecess", Vector3(-0.5, 1.72, z_position), Vector3(0.035, 2.28, 1.18), _materials["hull_dark"], false)
		_box(service, "CabinetStatus", Vector3(-0.49, 2.38, z_position), Vector3(0.04, 0.18, 0.8), _materials["cyan"] if cabinet_index != 1 else _materials["gold"], false)
		for fastener_y in [0.67, 2.77]:
			for fastener_z in [-0.53, 0.53]:
				_cylinder(service, "CabinetFastener", Vector3(-0.535, float(fastener_y), z_position + float(fastener_z)), 0.035, 0.028, _materials["brass"], false, Vector3(0, 0, 90))
	for pipe_index in 3:
		var pipe_z := -2.05 + float(pipe_index) * 2.05
		_cylinder(service, "ServiceConduit", Vector3(-0.55, 3.65, pipe_z), 0.09, 1.9, _materials["mid_grey"], false)
		_torus(service, "ConduitCollar", Vector3(-0.55, 2.95, pipe_z), 0.1, 0.16, _materials["brass"], Vector3(90, 0, 0))
	_beam_between(service, "ServiceBus", Vector3(-0.66, 4.15, -2.85), Vector3(-0.66, 4.15, 2.85), 0.065, _materials["copper"], false)


func _build_vip_landmark(structure: Node3D) -> void:
	var vip := Node3D.new()
	vip.name = "VIPLandmark"
	structure.add_child(vip)
	# The facade is split around the real door so its red panel remains visible.
	# A shallow backing plate prevents this landmark from implying a VIP room.
	_box(vip, "VIPFacadeLeft", Vector3(-8.9, 6.25, 20.38), Vector3(2.8, 4.1, 0.52), _materials["warm_grey"])
	_box(vip, "VIPFacadeRight", Vector3(-1.45, 6.25, 20.38), Vector3(2.5, 4.1, 0.52), _materials["warm_grey"])
	_box(vip, "VIPFacadeHeader", Vector3(-5.15, 8.12, 20.38), Vector3(10.3, 0.76, 0.52), _materials["warm_grey"])
	_box(vip, "VIPShallowBackstop", Vector3(-5.15, 6.25, 20.52), Vector3(4.4, 3.45, 0.26), _materials["graphite"])
	for side in [-1.0, 1.0]:
		var frame_x := -5.15 + float(side) * 3.85
		_cylinder(vip, "VIPFacadeColumn", Vector3(frame_x, 6.25, 20.02), 0.18, 4.15, _materials["hull_dark"], false)
		_torus(vip, "VIPFacadeColumnFoot", Vector3(frame_x, 4.43, 20.02), 0.19, 0.28, _materials["brass"])
		_torus(vip, "VIPFacadeColumnCrown", Vector3(frame_x, 8.07, 20.02), 0.19, 0.28, _materials["brass"])
	_arch_across_x(vip, "VIPFacadeArch", 20.04, -9.0, -1.3, 8.05, 8.72, 0.12, _materials["hull_dark"])
	_box(vip, "VIPRedCrown", Vector3(-5.15, 8.15, 20.03), Vector3(6.2, 0.18, 0.12), _materials["red"], false)
	for side in [-1.0, 1.0]:
		_box(vip, "VIPRedMarker", Vector3(-5.15 + side * 2.35, 6.25, 20.02), Vector3(0.12, 3.4, 0.12), _materials["red"], false)
	# MAP-004 family. The legend sits at z = 19.96, in front of the facade panels
	# (z = 20.12 …) on the -Z side of the landmark, and was authored with
	# `Vector3.ZERO`, so it read backwards to anyone walking aft towards it. Yawed
	# to the reader; `AFT OPERATIONS` in the same module already does this.
	# MAP-004 family, plus a second defect found only by photographing it. The
	# legend was authored with `Vector3.ZERO`, so it read backwards; and it stood
	# at z = 19.96 while `VIPAccess/FrameVisuals/Header` — the door frame added
	# later — occupies world z = 67.72 … 68.44 at exactly this height, so the sign
	# was buried inside the frame and rendered to nobody from either side. Five
	# camera positions from 1.06 m to 6.0 m photographed blank frame header. It is
	# now yawed to the reader and pulled to z = 19.64 (world 67.64), 0.08 m proud
	# of the frame's front face, where it reads as the header's legend.
	_text_sign(vip, "VIP ACCESS  //  DEFERRED", Vector3(-5.15, 7.75, 19.64), Vector3(0, 180, 0), 0.31, _materials["red"])


func _build_open_structure_details(structure: Node3D) -> void:
	var details := Node3D.new()
	details.name = "OpenStructureDetails"
	structure.add_child(details)
	for side in [-1.0, 1.0]:
		var x_position: float = float(side) * 4.75
		_cylinder(details, "JunctionSupport", Vector3(x_position, -0.95, 7.4), 0.24, 1.9, _materials["mid_grey"], true)
		_torus(details, "SupportCollar", Vector3(x_position, -0.15, 7.4), 0.26, 0.39, _materials["brass"], Vector3(90, 0, 0))
	_beam_between(details, "LowerCrossBrace", Vector3(-4.7, -1.2, 6.1), Vector3(4.7, -1.2, 8.7), 0.16, _materials["mid_grey"], false)
	_beam_between(details, "LowerCrossBraceReturn", Vector3(4.7, -1.2, 6.1), Vector3(-4.7, -1.2, 8.7), 0.16, _materials["mid_grey"], false)
	for side in [-1.0, 1.0]:
		var support_x := float(side) * 4.75
		_beam_between(details, "SupportOutrigger", Vector3(support_x, -1.15, 7.4), Vector3(support_x + float(side) * 2.0, -1.75, 7.4), 0.13, _materials["hull_dark"], false)
		_cylinder(details, "OutriggerEndCap", Vector3(support_x + float(side) * 2.0, -1.75, 7.4), 0.26, 0.24, _materials["brass"], false, Vector3(0, 0, 90))
		for z_position in [5.55, 9.25]:
			_omni_light(details, "ExteriorMarkerLight", Vector3(support_x, -0.05, float(z_position)), Color("66d7dc"), 0.28, 2.4)
	# MAP-004 family. `bugs.md` filed this under "floor decals rendered mirrored";
	# it is not a floor decal, it is a vertical identity plaque, and it genuinely
	# did read backwards. Rendered from the aft connection deck at world
	# `(0, 2.4, 52)` — the only place a player stands to see it — the legend was
	# reversed. Yawed to that reader. It remains deliberately unbacked, like the
	# rest of this open-lattice exterior dressing.
	_text_sign(details, "AFT JUNCTION  //  MODERN INTERPRETATION", Vector3(0, 1.25, 9.82), Vector3(0, 180, 0), 0.2, _materials["gold"])


func _style_access_landmarks() -> void:
	if _operations_entrance != null:
		_apply_door_material(_operations_entrance, _materials["cyan"], _materials["cyan"])
	if _vip_access != null:
		_apply_door_material(_vip_access, _materials["red"], _materials["red"])


func _apply_door_material(door: StationDoor, panel_material: Material, indicator_material: Material) -> void:
	var panel := door.get_node_or_null("SlidingPanel/PanelMesh") as MeshInstance3D
	if panel != null:
		panel.material_override = panel_material
	var left_indicator := door.get_node_or_null("SlidingPanel/LeftIndicator") as MeshInstance3D
	var right_indicator := door.get_node_or_null("SlidingPanel/RightIndicator") as MeshInstance3D
	if left_indicator != null:
		left_indicator.material_override = indicator_material
	if right_indicator != null:
		right_indicator.material_override = indicator_material


func _apply_metadata() -> void:
	set_meta("station_module", true)
	set_meta("module_id", MODULE_ID)
	set_meta("evidence_status", EVIDENCE_STATUS)
	set_meta("source_bounded", true)
	set_meta("content_note", CONTENT_NOTE)
	set_meta("open_to_space_ratio", get_open_to_space_ratio())
	set_meta("integration_footprint_min", FOOTPRINT_MIN)
	set_meta("integration_footprint_max", FOOTPRINT_MAX)
	add_to_group("station_modules")


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
	result.clearcoat_roughness = 0.48
	if emission_energy > 0.0:
		result.emission_enabled = true
		result.emission = emission_color
		result.emission_energy_multiplier = emission_energy
	return result


func _transparent_material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var result := _material(color, metallic, roughness)
	result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	result.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	result.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
	return result


func _box(
		parent: Node3D,
		node_name: String,
		box_position: Vector3,
		size: Vector3,
		material: Material,
		collidable: bool = true,
		box_rotation_degrees: Vector3 = Vector3.ZERO
	) -> Node3D:
	var container: Node3D
	if collidable:
		var body := StaticBody3D.new()
		body.collision_layer = WORLD_LAYER
		body.collision_mask = 0
		container = body
	else:
		container = MeshInstance3D.new()
	container.name = node_name
	container.position = box_position
	container.rotation_degrees = box_rotation_degrees
	parent.add_child(container)

	var mesh := _rounded_box_mesh(size)
	if collidable:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "Mesh"
		mesh_instance.mesh = mesh
		mesh_instance.material_override = material
		container.add_child(mesh_instance)
		var collision := CollisionShape3D.new()
		collision.name = "Collision"
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		container.add_child(collision)
	else:
		var mesh_instance := container as MeshInstance3D
		mesh_instance.mesh = mesh
		mesh_instance.material_override = material
	return container


## Box with softly chamfered edges, at this module's frozen bevel rule.
##
## The rule stays `clamp(shortest_side * 0.22, 0.003, 0.18)` and is *not* the
## kit's own `bevel_for_size`. Measured over every live chamfered box in this
## module, adopting the kit rule would move 23 of 65 distinct sizes by up
## to 0.0058 m, so the shared code is the builder, not the rule. The outer extent
## along each axis is preserved exactly, so `get_aabb()` still returns the
## requested size and no footprint, collider or published envelope moves.
func _rounded_box_mesh(size: Vector3) -> ArrayMesh:
	return StationSurfaceKit.rounded_box_mesh_with_bevel_cached(
		size,
		StationSurfaceKit.proportional_bevel_for_size(size, 0.18),
		_rounded_box_cache,
		StationSurfaceKit.BevelUV.UNIT_PER_QUAD
	)


func _cylinder(
		parent: Node3D,
		node_name: String,
		cylinder_position: Vector3,
		radius: float,
		height: float,
		material: Material,
		collidable: bool,
		rotation_degrees_value: Vector3 = Vector3.ZERO
	) -> Node3D:
	var container: Node3D
	if collidable:
		var body := StaticBody3D.new()
		body.collision_layer = WORLD_LAYER
		body.collision_mask = 0
		container = body
	else:
		container = MeshInstance3D.new()
	container.name = node_name
	container.position = cylinder_position
	container.rotation_degrees = rotation_degrees_value
	parent.add_child(container)
	# Chamfered rims at the module's frozen 32 radial segments. Outer radius and
	# overall height are unchanged, so no footprint moves and the collision
	# cylinder below is built from the same untouched arguments.
	var cylinder_mesh := StationSurfaceKit.chamfered_cylinder_mesh_cached(
		radius, radius, height, 32, _chamfered_cylinder_cache
	)
	if collidable:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = cylinder_mesh
		mesh_instance.material_override = material
		container.add_child(mesh_instance)
		var collision := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		collision.shape = shape
		container.add_child(collision)
	else:
		var mesh_instance := container as MeshInstance3D
		mesh_instance.mesh = cylinder_mesh
		mesh_instance.material_override = material
	return container


func _beam_between(
		parent: Node3D,
		node_name: String,
		from: Vector3,
		to: Vector3,
		radius: float,
		material: Material,
		collidable: bool
	) -> Node3D:
	var direction := to - from
	var beam := _cylinder(parent, node_name, (from + to) * 0.5, radius, direction.length(), material, collidable)
	beam.quaternion = Quaternion(Vector3.UP, direction.normalized())
	return beam


func _arch_across_x(
		parent: Node3D,
		node_name: String,
		z_position: float,
		x_minimum: float,
		x_maximum: float,
		spring_height: float,
		crown_height: float,
		radius: float,
		material: Material
	) -> Node3D:
	var arch := Node3D.new()
	arch.name = node_name
	arch.set_meta("visual_detail_only", true)
	parent.add_child(arch)
	var half_width := (x_maximum - x_minimum) * 0.5
	var center_x := (x_minimum + x_maximum) * 0.5
	var segment_count := 14
	var previous := Vector3(x_minimum, spring_height, z_position)
	for segment_index in segment_count:
		var progress := float(segment_index + 1) / float(segment_count)
		var x_position := lerpf(x_minimum, x_maximum, progress)
		var normalized_x := (x_position - center_x) / half_width
		var curve_height := spring_height + (crown_height - spring_height) * sqrt(maxf(0.0, 1.0 - normalized_x * normalized_x))
		var current := Vector3(x_position, curve_height, z_position)
		_beam_between(arch, "TubeSegment%02d" % segment_index, previous, current, radius, material, false)
		previous = current
	return arch


func _omni_light(
		parent: Node3D,
		node_name: String,
		light_position: Vector3,
		color: Color,
		energy: float,
		range_value: float
	) -> OmniLight3D:
	var result := OmniLight3D.new()
	result.name = node_name
	result.position = light_position
	result.light_color = color
	result.light_energy = energy
	result.omni_range = range_value
	result.omni_attenuation = 1.45
	result.shadow_enabled = false
	result.distance_fade_enabled = true
	result.distance_fade_begin = 28.0
	result.distance_fade_length = 12.0
	result.set_meta("localized_practical_light", true)
	parent.add_child(result)
	return result


func _torus(
		parent: Node3D,
		node_name: String,
		torus_position: Vector3,
		inner_radius: float,
		outer_radius: float,
		material: Material,
		rotation_degrees_value: Vector3 = Vector3.ZERO
	) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = torus_position
	instance.rotation_degrees = rotation_degrees_value
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = 48
	mesh.ring_segments = 16
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)
	return instance


## Module-local Z of the stair-base landing's southern edge.
func _stair_base_landing_south_edge() -> float:
	return STAIR_BASE_LANDING_CENTRE.z - STAIR_BASE_LANDING_SIZE.z * 0.5


## Module-local Z of the stair-base landing's northern edge.
func _stair_base_landing_north_edge() -> float:
	return STAIR_BASE_LANDING_CENTRE.z + STAIR_BASE_LANDING_SIZE.z * 0.5


## Fraction along the ramp at which a stair rail line may begin. A rail line that
## passes over the stair-base landing begins only once the ramp has climbed past
## the landing's northern edge, so the landing stays a continuous walking surface.
func _stair_rail_start_progress(rail_x: float, start: Vector3, finish: Vector3) -> float:
	var west_edge := STAIR_BASE_LANDING_CENTRE.x - STAIR_BASE_LANDING_SIZE.x * 0.5
	var east_edge := STAIR_BASE_LANDING_CENTRE.x + STAIR_BASE_LANDING_SIZE.x * 0.5
	if rail_x <= west_edge or rail_x >= east_edge:
		return 0.0
	var run := finish.z - start.z
	if is_zero_approx(run):
		return 0.0
	return clampf((_stair_base_landing_north_edge() - start.z) / run, 0.0, 1.0)


func _add_rail(parent: Node3D, from: Vector3, to: Vector3, rail_name: String) -> void:
	for endpoint in [from, to]:
		_cylinder(parent, rail_name + "Post", endpoint + Vector3.UP * 0.68, 0.055, 1.36, _materials["warm_grey"], true)
	_beam_between(parent, rail_name, from + Vector3.UP * 1.34, to + Vector3.UP * 1.34, 0.07, _materials["brass"], true)


func _text_sign(
		parent: Node3D,
		text: String,
		text_position: Vector3,
		text_rotation_degrees: Vector3,
		scale_value: float,
		material: Material
	) -> MeshInstance3D:
	var mesh := TextMesh.new()
	mesh.text = text
	mesh.font_size = 64
	mesh.pixel_size = 0.012
	mesh.depth = 0.02
	mesh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mesh.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var instance := MeshInstance3D.new()
	instance.name = "Sign_" + text.replace(" ", "_").replace("/", "-")
	instance.position = text_position
	instance.rotation_degrees = text_rotation_degrees
	instance.scale = Vector3.ONE * scale_value
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)
	return instance
