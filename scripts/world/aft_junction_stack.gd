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

## Distance fade applied to every fixture practical in this module. Measured
## rather than chosen — see `_fixture_practical`. A fade that ended at 24 m ended
## inside the subject and switched the whole pass off in every framing but the
## two interiors; this ends at 85 m, past the station, and still spares the
## 140 m-plus lattice overview.
const PRACTICAL_FADE_BEGIN := 60.0
const PRACTICAL_FADE_LENGTH := 25.0
const INTERFACE_COLLAR_KIND_META := "aft_interface_collar_kind"

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
	+ "VIP door is a landmark with no authenticated interior: what stands behind it "
	+ "is `VipReceptionSuite`, an invented modern interpretation at confidence none, "
	+ "and this module claims no original VIP room, adjacency or era."
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
## Content-pass animation state. See `_process` / `_update_operations_content`.
var _content_clock := 0.0
var _sweep_arm: Node3D = null
var _content_lenses: Array[MeshInstance3D] = []
var _content_lens_specs: Array[Dictionary] = []


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
			# The content pass. Surviving material supports "a compact grey console
			# room with windows"; it supports nothing whatever about what is in one.
			# The rack bank, the module status board and its route schematic, the
			# traffic plot table and its tokens, the coordinator's desk, the chart
			# press, the refreshment stand, the crew traces and the stair-head muster
			# locker are all original modern design, and the working state each of
			# them shows — which rack is isolated, which traffic is inbound, which
			# annunciator is up — is invented, not recovered.
			"operations-room apparatus, its indicated working state, and the stair-head muster locker",
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
	elif _vip_access.deferred_access or _vip_access.locked:
		# Reversed on the day the interior was built. The landmark used to be
		# required to stay shut because there was nothing behind it; it is now
		# required to stay openable, because a door that refuses to open in front
		# of a room the player can see through the glazing is a worse lie than an
		# empty facade ever was. The evidence boundary moved from the door to the
		# room, where `VipReceptionSuite` publishes it.
		errors.append("VIP access opens onto a built interior and must not be locked or deferred")
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
		"vip_leads_to_interpretation_interior": _vip_access != null \
			and not _vip_access.locked \
			and not _vip_access.deferred_access,
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
		# Mesh ceiling re-frozen in the open, 170 -> 600 -> 848, and it is now the
		# exact built count rather than the previous ~13% of headroom, for the same
		# reason the light ceiling already was: a ceiling with slack in it lets the
		# next content pass land without declaring itself. 600 -> 852 is the content
		# pass and every one of the 320 is in this file. Measured per assembly
		# against the live tree:
		#
		#   Watch rack bank, 118. Three rack frames, kicks, caps and their cable
		#   drops; a fascia each on the two made-up racks and, on the isolated one,
		#   the removed fascia, its open backplane, three cable looms, a lockout
		#   hasp/chain/tag, two open card cages and fourteen cards; four plug-in
		#   modules per made-up rack with a vent, readout and two knobs each; a
		#   status lens, breaker body and breaker lever per rack; the tray, its four
		#   clamps and the riser into the service wall.
		#   Module status board, 41. Body, chart field, four frame members, five
		#   schematic links, six nodes and six node lenses, six annunciator bodies,
		#   lenses and flags, and the legend.
		#   Traffic plot table, 70. Base, two pedestals, top, apron, chart cradle and
		#   four rolls, plot disc, rim, three graticule rings, four bearings, hub,
		#   five tokens and five pins, four rim posts and two rails, two chart
		#   borders, two sheets, two edge trims, the four-piece sweep assembly, and
		#   the logbook, mug, gloves and dividers left on it.
		#   Coordinator desk, 26. Body, top, kick, two drawer fronts and two pulls,
		#   the lamp's three pieces, the log's four, the handset's three, two manual
		#   stacks, and the headset's four.
		#   Chart press, 32. Body, top, kick, five drawer fronts and five pulls, four
		#   rolls, a strap, the notice board, seven sheets, two pins, the clipboard
		#   hook, board and sheet.
		#   Refreshment stand, 18, plus the waste bin and its rim.
		#   Crew traces, 6, and the coordinator's coverall, 3.
		#   Stair-head muster locker, 25.
		#
		# Frame cost is unmeasured and unmeasurable on this box: it renders through
		# llvmpipe. What is measured is that every one of these is a chamfered kit
		# primitive sharing this module's two mesh caches, so the added *unique*
		# mesh resources are far fewer than the added instances.
		"mesh_instances": 852,
		# Unchanged at 120 against 103 built, up from 87. The content pass added
		# sixteen colliders and every one of them is a piece of furniture a player
		# can walk into: three rack frames, the plot table's base, two pedestals and
		# top, the coordinator desk body and top, the chart press body and top, the
		# refreshment counter and top, the waste bin, and the muster locker's two
		# carcass halves. Anything
		# in this room that looks solid at arm's reach is solid. These two ceilings
		# are deliberately left with their existing headroom rather than pinned to
		# the built figure — the mesh and light ceilings are this module's declared
		# regression gates and two is enough.
		"static_bodies": 120,
		"collision_shapes": 120,
		"labels": 4,
		# Light ceiling re-frozen in the open, 12 -> 32 -> 40. The module built 11
		# lights against that 12; the fixture pass took it to 32, all of them
		# fixture practicals — see `_fixture_practical`. Every one is shadowless,
		# under 9 m range, steeply attenuated and distance-faded, and they exist
		# because emission illuminates nothing in Forward+, so a lens, strip,
		# status light or sign could not light the plate it is bolted to no matter
		# what energy it carried.
		#
		# 32 -> 40 is the interior legibility pass, and all eight are in the
		# operations room: the single centreline row of three ceiling luminaires
		# becomes two rows of three (+3) in a 10.4 m-wide room that had no overhead
		# over either side third, each of the two 7.3 m ceiling coves goes from one
		# lamp at its midpoint to three down its length (+4), and the coordinator
		# chair — the one seat in the room with no fixture within range of it in
		# any direction — gets the same under-console task wash the other two
		# working positions already had (+1). Per-fixture energy comes *down* in
		# both places the count went up, so this is a redistribution of the room's
		# existing luminaires across the room's actual volume and not added gain;
		# see the long note on `_build_operations_lighting`.
		#
		# The ceiling is deliberately set at the exact built count rather than left
		# with headroom, so the next addition has to be declared here too. Frame
		# cost is unmeasured: this box renders through llvmpipe.
		#
		# 40 -> 50 is the content pass, and it is the same trade every fixture in
		# this module has already made: emission is a local surface term in
		# Forward+, so a lens that lights nothing is a decal, and every lit thing
		# this pass added had to either throw light or not be lit. All ten are
		# `_fixture_practical` — shadowless, sub-4 m, steeply attenuated, faded out
		# by 85 m — and each carries its own fixture's hue:
		#
		#   `WatchRackStatusSpill` x2. One per *made-up* rack, and deliberately none
		#   on the isolated one. This is the hardware-state rule doing real work: the
		#   rack that is out throws no light, so which rack is dead is legible with
		#   the room's own colour discarded.
		#   `StatusBoardWash` x2. The south wall is the only wall with no overhead
		#   within 1.8 m, and the board is 5.4 m across; one lamp at its centre was
		#   photographed and left both ends dark.
		#   `PlotTableGlow` and `PlotSweepLamp`. The plot disc and the sweep head are
		#   the two lit surfaces on the table; the second is a child of the moving
		#   arm, so the light travels with the instrument that carries it.
		#   `CoordinatorLampSpill`, `NoticeBoardWash`, `RefreshmentSpill`. One each
		#   for the three pockets of this room the six overheads do not reach: the
		#   coordinator's corner, the west wall, and the north-west counter.
		#   `MusterLockerLamp`. The stair-head locker on the open upper deck, which
		#   has no local light of any kind above the stair's three courtesy pools.
		#
		# Every one of the ten is at or below 0.34 energy and none reaches beyond
		# 3.8 m, so this is ten small pools sited on ten fixtures, not a lift.
		"lights": 50,
		# Now genuinely used, where it was budgeted-but-unspent before. The content
		# pass gave the module one `_process`: it turns the plot table's sweep arm
		# and pulses one annunciator lens, both closed-form in an accumulated clock,
		# and `_apply_enabled_state` switches it off with the module.
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
	# The content pass gave this module a frame loop, so the loop has to follow the
	# lifecycle flag too. `build_lifecycle_contract` reports
	# `process_matches_lifecycle` false for any module that keeps advancing behind
	# a hidden shell, and `get_validation_errors` rejects on it — a disabled module
	# whose plot sweep kept turning would snap to a jumped pose when re-enabled.
	set_process(_module_enabled and _built)


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
	# marker is an internal waypoint, and the VIP landmark stays out of the graph
	# even now that it opens: `VipReceptionSuite` is an interpretation interior,
	# not a registered station module, so it declares no slot and adds no edge.
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
	# Emission 0.2 -> 0.62. `gold` is the module's warm cue colour and it was the
	# one cue that never read as lit: at 0.2 the arc tiles, cabinet status strips
	# and the junction legend sat below the tonemapper's shoulder and returned
	# nothing but their albedo. They are now paired with warm practicals (see
	# `_fixture_practical`), and a cue that throws light has to look like it is on.
	_materials["gold"] = _material(Color("d0a350"), 0.54, 0.3, Color("8f5f20"), 0.62)
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
	# Emission 1.25 -> 1.0, for the same reason as the habitat's twin: the console
	# displays clipped white while the console body under them stayed at structure
	# value. `ConsoleGlow` now lights the console, so the panel does not have to be
	# blown to read as a live display.
	_materials["screen"] = _material(Color("b9f2ef"), 0.08, 0.24, Color("68dde2"), 1.0)
	_materials["screen_dark"] = _material(Color("16363b"), 0.22, 0.36, Color("2b9aa3"), 0.22)
	# Lens emission comes down where a practical now carries the difference. These
	# two were the brightest surfaces in the module and the reason its histogram
	# was bimodal: a 2.5-energy lens clips well past the AgX shoulder, blooms, and
	# still leaves the ceiling plate it is recessed into at structure value,
	# because emission does not illuminate anything. Energy moved out of the lens
	# and into `OperationsPoolLight` / `ExteriorCowlSpill`; the fixture reads
	# slightly less blown and its mount reads lit, which is the trade this pass
	# exists to make. worklight 2.5 -> 1.65, amber_light 1.8 -> 1.2.
	_materials["worklight"] = _material(Color("edf8f5"), 0.02, 0.2, Color("d7ffff"), 1.65)
	_materials["amber_light"] = _material(Color("ffdba0"), 0.02, 0.24, Color("f1a84e"), 1.2)
	# Glazing response re-frozen, metallic 0.03 -> 0.06 and roughness 0.08 -> 0.12,
	# which is the habitat's exact pair. The lighting pass recorded that these panes
	# "read slightly flatter than the habitat's because the room behind the camera
	# is brighter and the glass returns it" and left it for an owner. That reading
	# is real and the cause is here rather than in the room: at roughness 0.08 the
	# specular lobe is narrow enough to return the room as a *sheet*, so a bright
	# interior comes back as one even wash across a 3.05 x 3.25 m pane and buries
	# the star field behind it. The habitat's 0.12 spreads the same return into a
	# gradient that falls off across the pane, which is why its windows read as
	# glass and these read as tinted panels. Only the response moves; the tint,
	# alpha, pane sizes and mullions are untouched, so the aft room keeps its own
	# colour and the two rooms now agree on what glass *is*. Verified by render:
	# the operations panes gain a visible falloff and more of the exterior.
	_materials["glass"] = _transparent_material(Color(0.38, 0.68, 0.72, 0.18), 0.06, 0.12)
	_materials["chair"] = _material(Color("4a5557"), 0.14, 0.7)
	_materials["chair_pad"] = _material(Color("273236"), 0.04, 0.92)
	# Soft goods and paper stock, for the content pass. Both are deliberately
	# outside the world-triplanar plate family for the same reason the module's
	# seating fabric and lit cues are: a duty log, a chart roll, a notice sheet and
	# a coverall draped over a chair are not plate, and stamping a 0.30 m panel
	# field across them would read as printed steel.
	_materials["fabric"] = _material(Color("5d6b63"), 0.0, 0.94)
	_materials["paper"] = _material(Color("d9d7cd"), 0.0, 0.88)
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
	#
	# Two of the eight tiles carry a warm practical. Not eight: the ring is a
	# 7.5 m ellipse of touching tiles, one light per tile would be seven redundant
	# copies of the same pool, and two placed on opposite arcs already put a warm
	# gradient across the whole inset. This is the module's only warm light at
	# deck level and it is what keeps the junction floor from being the same cyan
	# as the wall above it.
	for angle in [-70.0, -35.0, 0.0, 35.0, 70.0, 105.0, 140.0, 175.0]:
		var radians := deg_to_rad(angle)
		var ring_position := Vector3(cos(radians) * 3.75, 0.11, 7.45 + sin(radians) * 1.75)
		_box(lower, "JunctionArcTile", ring_position, Vector3(1.25, 0.08, 0.24), _materials["gold"], false, Vector3(0, -angle + 90.0, 0))
		if is_equal_approx(angle, -35.0) or is_equal_approx(angle, 140.0):
			_fixture_practical(
				lower,
				"JunctionArcSpill",
				ring_position + Vector3(0.0, 0.24, 0.0),
				Color("f0be7c"),
				0.46,
				4.2
			)

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

	_build_stair_head_muster(upper)


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
			_interface_collar(bay, "ConsoleShockCollar", Vector3(float(support_x), 0.08, 0.34), 0.09, 0.13, _materials["rubber"], Vector3(90, 0, 0))
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
		# One practical per bay, not one per lamp. The display, its three data
		# bands and the three control lamps are a single luminaire from any
		# distance a player reads this room from; three lights per bay would be
		# three copies of one pool over a 2.2 m console. Placed just above and in
		# front of the glass so it washes the console top, the edge rail and the
		# operator's chair back rather than the ceiling.
		#
		# Range 2.6 -> 3.4, energy unchanged. This is the only light in the room in
		# front of a seated operator's face, and the face is 1.83 m away, where a
		# 2.6 m range window was cutting 43% of it. Widening the window leaves the
		# console top — 0.4 m away, where the window reads 1.00 either way —
		# exactly as lit as it was, which is why this is a range change and not an
		# energy change: the panel is what an energy raise would have blown first.
		_fixture_practical(
			bay,
			"ConsoleGlow",
			Vector3(0.0, 1.74, -0.36),
			Color("93e4ea"),
			0.42,
			3.4
		)
		# The bay's one warm lamp gets its own tiny pool. It is the only warm
		# source on the console line and it is what stops three identical cyan
		# consoles reading as one extruded strip.
		_fixture_practical(
			bay,
			"ControlLampSpill",
			Vector3(0.56, 1.58, -0.1),
			Color("f2c07f"),
			0.24,
			1.25
		)

	# Three operator chairs plus a side-facing coordinator chair.
	#
	# The three operator chairs are yawed 180, which is a fix rather than a
	# restyle. `_build_chair` puts `BackFrame` at local +Z, so a chair authored at
	# yaw 0 seats its occupant facing local -Z — and the console bay it belongs to
	# stands at z = 15.7 with its display, edge rail and control lamps all on the
	# -Z face, i.e. at +Z of the chair. Every operator was therefore sitting with
	# their back to their own console, facing the door. It read as three armchairs
	# parked in front of some machinery rather than as three working positions, and
	# it also contradicted the lighting that was built for it: `ConsoleGlow` is
	# documented as "the only light in the room in front of a seated operator's
	# face", sited 1.83 m from a face at z = 13.55, which is only true of a chair
	# looking at +Z. Nothing moves; only the chairs turn.
	#
	# The coordinator keeps -72. That chair faces (0.951, 0, -0.309) — out across
	# the room toward the plot table and the status board, which is where a watch
	# coordinator looks — and its own task wash at (2.0, 1.05, 12.4) was sited for
	# exactly that pose.
	for chair_index in 4:
		var chair_position: Vector3
		var chair_yaw := 180.0
		if chair_index < 3:
			chair_position = Vector3(3.15 + float(chair_index) * 2.85, 0.0, 13.55)
		else:
			chair_position = Vector3(1.7, 0.0, 12.0)
			chair_yaw = -72.0
		_build_chair(room, chair_index, chair_position, chair_yaw)

	_build_service_wall(room)
	_build_operations_lighting(room)
	_build_operations_content(room)
	_text_sign(room, "AFT OPERATIONS", Vector3(7.2, 3.7, 9.31), Vector3(0, 180, 0), 0.29, _materials["cyan"])
	# A lit sign that does not light the wall it hangs on is a sticker. This is a
	# wide, weak wash placed a little in front of and below the legend, so the
	# bulkhead behind it carries a gradient the sign sits inside.
	_fixture_practical(room, "OperationsSignWash", Vector3(7.2, 3.45, 9.62), Color("7fe0e6"), 0.34, 3.0)


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
		_interface_collar(envelope, "SpineClamp", Vector3(5.6, 5.62, float(spine_z)), 0.16, 0.225, _materials["copper"], Vector3(90, 0, 0))

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
		_interface_collar(envelope, "ExteriorPipeClamp", Vector3(11.18, 0.82, float(pipe_z)), 0.065, 0.1, _materials["graphite"], Vector3(90, 0, 0))
	# Four cowled amber worklights on the operations envelope. The cowl and lens
	# geometry was already here; what was missing is that none of them lit the
	# plate they are bolted to, so from outside the module read as cool plating
	# with four orange stickers on it. Each now throws a short warm pool onto its
	# own housing and the surrounding wall, and together they are the warm half of
	# the aft module's exterior colour temperature.
	for lamp_position in [Vector3(0.1, 3.9, 9.45), Vector3(11.1, 3.9, 9.45), Vector3(0.1, 3.9, 16.9), Vector3(11.1, 3.9, 16.9)]:
		_box(envelope, "ExteriorWorklightHousing", lamp_position, Vector3(0.22, 0.4, 0.52), _materials["hull_dark"], false)
		_box(envelope, "ExteriorWorklightLens", lamp_position + Vector3(0, 0, -0.27), Vector3(0.13, 0.22, 0.035), _materials["amber_light"], false)
		_fixture_practical(
			envelope,
			"ExteriorCowlSpill",
			lamp_position + Vector3(0.0, -0.1, -0.42),
			Color("f7bb70"),
			0.62,
			3.6
		)


## Operations-room lighting.
##
## This room was the clearest case of the two defects this pass exists to fix.
## Every surface in it — plate, deck, console, cove, sign — returned one cyan
## hue, because the only warm light anywhere in the station is a directional
## bounce aimed up from the open decks, and an enclosed room cannot see it. And
## its three ceiling luminaires were 2.5-energy lenses over a plate that received
## 0.62 of cool omni, so the frame was a pair of spikes with nothing between.
##
## The fix is colour temperature, not level. Real rooms are lit by more than one
## kind of lamp and that is most of what makes them read as built: the overheads
## here stay the station's cool service white and stay dominant, so the cool
## identity is untouched, but the room now also carries warm light from two
## sources that belong to it — an under-console task wash at working height, and
## the warm end of the cove. The overheads lost the emission that was blowing
## out and gained the room brightness that emission was never providing:
## `worklight` 2.5 -> 1.65 in the palette, `OperationsPoolLight` 0.62 -> 0.94.
##
## The functional cue colours are deliberately not touched. Cyan route/status,
## amber gold and red keep their exact hues and their shape channel; the warm
## light added here is a low, broad, sub-1.0-energy wash at knee-to-waist height,
## which lands on floor and plinth and never on a cue face hard enough to shift
## what it reads as.
##
## ## The regrade follow-up: why this room "barely moved"
##
## The colour-temperature work above was right and is kept unchanged in kind. It
## did not make the room legible, and the reason turned out to be arithmetic in
## `omni_range` rather than anything about hue or level.
##
## Godot 4's omni falloff is a *windowed* inverse power, not a plain one:
## `(1 - (d/range)^4)^2 * d^(-attenuation)`. The window term is the trap. A
## luminaire 4.0 m above the deck with `omni_range = 5.6` sits at d/range = 0.71
## for the floor directly beneath it, where the window has already removed 45% of
## what the distance term left — and every wall, every corner and every chair
## back is further away than that, so the pool was being cut off at exactly the
## distances a person occupies. The room was three bright discs on the ceiling
## plate and a deck that received 0.07. That is the "pair of spikes with nothing
## between" the note above describes, and raising energy could not fix it: energy
## scales the ceiling disc and the deck by the same factor, so it moves the
## already-blown end up faster than the dark end.
##
## The fix is to widen the window, not the gain. `OperationsPoolLight` goes
## 5.6 -> 9.0 m of range while its energy comes *down* 0.94 -> 0.82. Widening the
## range does not touch the near field at all — at 0.5 m the window term is
## 1.00 either way — so the bright disc on the ceiling plate does not get
## brighter; only the tail that was being clipped comes back. Measured on the
## deck beneath a luminaire that is 0.069 -> 0.101, and in the room's corners,
## which were receiving a literal zero because they lay outside 5.6 m, it is zero
## -> a small but nonzero value. Corners that are dark are fine; corners that are
## algebraically excluded are a hole.
##
## Second, the ceiling was one row of three luminaires down the middle of a
## 10.4 m-wide room, so the two side thirds had no overhead at all and the side
## walls were lit only by one cove lamp each at the cove's midpoint — a 7.3 m
## linear fixture represented by a single point at its centre. The overheads
## become two rows of three (x = 3.2 and x = 8.0, the rows the console line and
## the chair line actually sit under) and each cove gets three lamps down its
## length instead of one. That is six overheads and six cove lamps where there
## were three and two.
##
## More lights is the opposite of more fill here, and the distinction is the
## whole point: a *uniform* lift is one term added to every surface regardless of
## where it is, which is what the flat ambient the global pass removed used to
## do. Six discrete pools with real falloff between them put a gradient across
## the deck and let a player tell where the light is coming from. The total lens
## area is deliberately held roughly constant while their number doubles — each
## lens goes 2.85 x 0.24 -> 1.85 x 0.20, so 2.05 m^2 becomes 2.22 m^2 — because
## `worklight` emission is what sets the blown top of this room's histogram and
## doubling the emissive area would have paid for the added structure with a
## wider bloom.
##
## Third, faces. An operator sits at z = 13.55 facing the window, so the only
## thing in the room in front of their face is `ConsoleGlow`, and at 1.83 m the
## 2.6 m range window was removing 43% of it — 0.067 arriving at a face. Range
## 2.6 -> 3.4 at unchanged 0.42 energy leaves the console top exactly as lit as
## it was and delivers 0.093 to the face. Range, again, not energy: the console
## panel is 0.4 m from that light and any energy raise lands there first.
func _build_operations_lighting(room: Node3D) -> void:
	var lighting := Node3D.new()
	lighting.name = "LocalizedLighting"
	lighting.set_meta("forward_plus_local_lighting", true)
	room.add_child(lighting)
	for luminaire_x in [3.2, 8.0]:
		for z_position in [11.15, 14.15, 16.15]:
			_box(lighting, "CeilingLuminaireBody", Vector3(float(luminaire_x), 4.47, float(z_position)), Vector3(2.15, 0.11, 0.44), _materials["hull_dark"], false)
			_box(lighting, "CeilingLuminaireLens", Vector3(float(luminaire_x), 4.405, float(z_position)), Vector3(1.85, 0.035, 0.2), _materials["worklight"], false)
			_omni_light(lighting, "OperationsPoolLight", Vector3(float(luminaire_x), 4.0, float(z_position)), Color("d9f6f3"), 0.82, 9.0)
	for cove_x in [0.86, 10.34]:
		_beam_between(lighting, "CeilingCoveRail", Vector3(float(cove_x), 4.3, 9.55), Vector3(float(cove_x), 4.3, 16.85), 0.055, _materials["cyan_dim"], false)
	# The two coves are the room's own fixtures and were lighting nothing. Giving
	# the starboard cove a warm lamp and the port cove a cool one is the cheapest
	# honest way to get two colour temperatures across a room: the walls now
	# gradate from warm on one side to cool on the other instead of sitting at
	# one value, and a viewer reads that as two luminaires rather than as tint.
	#
	# Three lamps per cove rather than one. A cove is a 7.3 m line of light and it
	# was standing in for itself with a single point at its midpoint, so the two
	# ends of both side walls — which is where this room goes to black first —
	# were outside the lamp entirely. Energy per lamp comes down with the count
	# (warm 0.5 -> 0.34, cool 0.42 -> 0.29) so the midpoint is not brighter than
	# it was; what changes is that the fixture now lights its own length.
	for cove_z in [10.7, 13.2, 15.7]:
		_fixture_practical(lighting, "CoveSpillWarm", Vector3(10.1, 4.05, float(cove_z)), Color("f0c48c"), 0.34, 6.4)
		_fixture_practical(lighting, "CoveSpillCool", Vector3(1.1, 4.05, float(cove_z)), Color("bfeef2"), 0.29, 6.4)
	# Under-console task light. Three consoles standing on a deck with nothing
	# below waist height meant the plinths, kick strips and chair bases were the
	# darkest band in the room. This is a tungsten-temperature wash at working
	# height, which is what a real operations floor has and what gives the room a
	# second hue where a player actually stands.
	#
	# The third one is for the coordinator chair. That chair sits alone at
	# (1.7, 12.0), yawed off the console line, and it was the one seat in the room
	# with no fixture within range of it in any direction — the two washes at
	# z = 14.4 start 2.4 m away and the nearest overhead was 4 m up and 3.9 m
	# across. It is the same lamp as the other two, sited at that chair's own
	# working position.
	for task_position in [Vector3(4.1, 1.05, 14.4), Vector3(8.7, 1.05, 14.4), Vector3(2.0, 1.05, 12.4)]:
		_fixture_practical(lighting, "ConsoleTaskWash", task_position, Color("f6c98c"), 0.44, 5.2)
	_box(lighting, "DoorThresholdLight", Vector3(2.2, 0.065, 9.36), Vector3(2.35, 0.04, 0.09), _materials["cyan"], false)
	# Same range correction as the overheads and for the same reason: at 3.8 m
	# range from 2.6 m up, the threshold this lamp exists to light was sitting at
	# 0.68 of the window and receiving 0.053. Range 3.8 -> 5.6, energy unchanged.
	_omni_light(lighting, "DoorPoolLight", Vector3(2.2, 2.6, 10.0), Color("72d9d9"), 0.35, 5.6)


## Operations-room content.
##
## The look pass recorded that this room "barely moved", and the lighting pass
## that followed it fixed the illumination — plated walls read across their full
## height, chair forms are legible, deck plates and floor seams are back. What was
## left is that there is nothing in here to light. Measured on the built room, the
## whole southern third — x = 4.6 … 10.0, z = 9.5 … 12.6, about 17 square metres
## between the door and the chair line — was bare deck, and the west strip and the
## north-west corner were bare with it. Three consoles, four chairs and a service
## wall is the furniture of a room; it is not the apparatus of an operations room,
## and a player walking in read an empty box with some seating in it.
##
## What this adds is the apparatus, sited where the room already had space for it:
##
##   A **watch rack bank** of three floor-standing equipment racks along the south
##   wall, under a cable tray that runs to the service wall — the room's plant.
##   A **module status board** above them, carrying the aft module's own route
##   schematic in relief with an annunciator row under it.
##   A **traffic plot table** in the middle of the cleared third: a chart table
##   with a lit plot disc, a graticule, ship tokens, an indexing sweep arm, chart
##   rolls stowed underneath, and the things people leave on a table.
##   A **coordinator desk** in front of the one chair that had nothing to work at.
##   A **chart press and notice board** down the west wall.
##   A **refreshment stand** in the dead north-west corner.
##   Personal traces on the console line and the coordinator's chair.
##
## Three rules this pass holds itself to, all of them learned elsewhere in the
## station today:
##
##   **Nothing floats.** Every piece either stands on the deck with its lowest
##   drawn face at y = 0.00 … 0.02, or shares volume with the piece it is mounted
##   on. The mounted ones are on the seated roster in
##   `tests/station_presentation_defect_witness_test.gd` so the class cannot come
##   back silently.
##   **Anything solid a player can reach is solid.** Every rack, table, desk,
##   chest, counter and bin carries World collision at its drawn size, so nothing
##   here is a hologram you can walk through — and equally, no collider exists
##   without geometry drawn at it.
##   **Structure is chamfered kit stock on the registered panel recipe.** Nothing
##   below is a raw `BoxMesh` with a flat scalar colour; the plate family carries
##   every structural surface, and only cues, glass, paper and cloth stay out of
##   it, exactly as they already did.
##
## ## State is carried by hardware
##
## The rack bank is the room's worked example of the rule the dock arms
## established: which rack is in service is told by what the hardware is *doing*,
## not by what colour it is painted. Racks 1 and 3 are made up — fascia on,
## breaker lever thrown up, status lens lit, a practical throwing that lens's own
## colour onto the plate around it. Rack 2 is isolated for work: its fascia is
## physically off and leaning against the neighbouring rack where somebody put it,
## its card cages are open to the room, its breaker lever is thrown down, a
## lockout hasp and tag hang off the open bay, its lens is dead and it throws no
## light at all. Turn every material in the room to greyscale and you can still
## tell at a glance which rack is out. The same idea runs the annunciator row on
## the status board — flags stand up or hang down — and the plot tokens, whose
## pins stand proud for inbound traffic and sit flush for a berthed hull.
func _build_operations_content(room: Node3D) -> void:
	var content := Node3D.new()
	content.name = "OperationsContent"
	room.add_child(content)
	_build_watch_rack_bank(content)
	_build_module_status_board(content)
	_build_traffic_plot_table(content)
	_build_coordinator_desk(content)
	_build_chart_press(content)
	_build_refreshment_stand(content)
	_build_console_line_traces(content)


## Three equipment racks on the south wall, and the tray that feeds them.
##
## The bank stands from the deck to 2.10 m against the wall face at z = 9.31, so
## it is a solid mass a player walks around rather than a decal on the bulkhead.
## Each rack is four plug-in modules behind a fascia; the middle one is opened up
## for work. See the hardware-state note on `_build_operations_content`.
func _build_watch_rack_bank(content: Node3D) -> void:
	var bank := Node3D.new()
	bank.name = "WatchRackBank"
	content.add_child(bank)

	# The tray is what makes three boxes read as installed plant rather than as
	# three boxes. It runs the length of the bank and turns east into the service
	# wall, which is where this room's cabling already goes.
	_beam_between(bank, "RackCableTray", Vector3(4.05, 2.44, 9.58), Vector3(10.15, 2.44, 9.58), 0.085, _materials["hull_dark"], false)
	_beam_between(bank, "RackCableTrayRiser", Vector3(10.15, 2.44, 9.58), Vector3(10.15, 2.44, 10.35), 0.075, _materials["hull_dark"], false)
	for clamp_x in [4.35, 6.05, 7.75, 9.45]:
		_interface_collar(bank, "RackCableTrayClamp", Vector3(float(clamp_x), 2.44, 9.58), 0.09, 0.135, _materials["brass"], Vector3(0, 0, 90))

	for rack_index in 3:
		var rack_x := 5.15 + float(rack_index) * 1.75
		var in_service := rack_index != 1
		_box(bank, "WatchRackFrame%02d" % rack_index, Vector3(rack_x, 1.05, 9.61), Vector3(1.62, 2.10, 0.60), _materials["mid_grey"])
		_box(bank, "WatchRackKick%02d" % rack_index, Vector3(rack_x, 0.06, 9.90), Vector3(1.50, 0.12, 0.05), _materials["rubber"], false)
		_box(bank, "WatchRackCap%02d" % rack_index, Vector3(rack_x, 2.13, 9.61), Vector3(1.70, 0.06, 0.66), _materials["hull_dark"], false)
		# Cable drops from the tray into each rack head.
		_beam_between(
			bank,
			"RackCableDrop%02d" % rack_index,
			Vector3(rack_x - 0.34, 2.40, 9.58),
			Vector3(rack_x - 0.34, 2.16, 9.62),
			0.035,
			_materials["copper"],
			false
		)
		_beam_between(
			bank,
			"RackCableDropReturn%02d" % rack_index,
			Vector3(rack_x + 0.34, 2.40, 9.58),
			Vector3(rack_x + 0.34, 2.16, 9.62),
			0.035,
			_materials["copper"],
			false
		)

		if in_service:
			_box(bank, "RackFascia%02d" % rack_index, Vector3(rack_x, 1.12, 9.915), Vector3(1.44, 1.90, 0.05), _materials["hull_dark"], false)
		else:
			# The opened rack. Its fascia is not hidden, it is somewhere: leaned
			# against the next rack along, bottom edge on the deck, top edge resting
			# on that rack's front face.
			_box(bank, "RackRemovedFascia", Vector3(rack_x + 1.75, 0.925, 10.135), Vector3(1.44, 1.90, 0.05), _materials["hull_dark"], false, Vector3(13, 0, 0))
			# The opened rack shows its card cages standing at the face the fascia came
			# off, not sunk inside a solid box. Built inside first, where every one of
			# them was buried in the 0.60 m frame and the "open" rack read as a plain
			# grey slab with a red tag hanging on it.
			_box(bank, "RackOpenBackplane", Vector3(rack_x, 1.12, 9.925), Vector3(1.44, 1.90, 0.03), _materials["graphite"], false)
			for loom_index in 3:
				_beam_between(
					bank,
					"RackOpenLoom%02d" % loom_index,
					Vector3(rack_x - 0.55 + float(loom_index) * 0.55, 1.94, 9.945),
					Vector3(rack_x - 0.40 + float(loom_index) * 0.55, 0.34, 9.945),
					0.028,
					_materials["copper"],
					false
				)
			# Lockout hasp and its tag, hung off the open bay's edge.
			_torus(bank, "RackLockoutHasp", Vector3(rack_x - 0.66, 1.62, 9.955), 0.035, 0.055, _materials["brass"], Vector3(0, 0, 90))
			# Chain radius 0.008 -> 0.018. Photographed first at 0.008, where it was
			# thinner than a pixel at any distance a player reads this bank from and
			# the tag under it read as a red card floating in front of the rack —
			# which is the exact defect class this module is under orders to keep out.
			_beam_between(bank, "RackLockoutChain", Vector3(rack_x - 0.66, 1.60, 9.955), Vector3(rack_x - 0.66, 1.47, 9.955), 0.018, _materials["brass"], false)
			_box(bank, "RackLockoutTag", Vector3(rack_x - 0.66, 1.38, 9.955), Vector3(0.15, 0.23, 0.008), _materials["red"], false, Vector3(0, 0, -6))

		for module_index in 4:
			var module_y := 0.46 + float(module_index) * 0.44
			# The opened rack keeps its card cages but loses the two modules that
			# were pulled; that empty pair is what the fascia came off for.
			if not in_service and module_index != 0 and module_index != 3:
				_box(bank, "RackCardCage%02d" % module_index, Vector3(rack_x, module_y, 9.955), Vector3(1.24, 0.30, 0.05), _materials["graphite"], false)
				for card_index in 7:
					_box(
						bank,
						"RackCard%02d%02d" % [module_index, card_index],
						Vector3(rack_x - 0.54 + float(card_index) * 0.18, module_y, 10.000),
						Vector3(0.02, 0.24, 0.10),
						_materials["panel_light"],
						false
					)
				continue
			_box(
				bank,
				"RackModule%02d%02d" % [rack_index, module_index],
				Vector3(rack_x, module_y, 9.945),
				Vector3(1.30, 0.32, 0.07),
				_materials["panel_light"] if module_index % 2 else _materials["off_white"],
				false
			)
			_box(bank, "RackModuleVent", Vector3(rack_x - 0.36, module_y, 9.985), Vector3(0.46, 0.17, 0.02), _materials["graphite"], false)
			_box(bank, "RackModuleReadout", Vector3(rack_x + 0.30, module_y + 0.03, 9.985), Vector3(0.40, 0.10, 0.015), _materials["screen_dark"], false)
			for knob_index in 2:
				_cylinder(
					bank,
					"RackModuleKnob",
					Vector3(rack_x + 0.16 + float(knob_index) * 0.20, module_y - 0.08, 9.995),
					0.032,
					0.03,
					_materials["brass"],
					false,
					Vector3(90, 0, 0)
				)

		# Status lens and breaker. Both read the same state two different ways, and
		# neither of them is a repaint: the lit lens throws a real practical, the
		# dead one throws nothing, and the lever is physically in a different place.
		_box(
			bank,
			"RackStatusLens%02d" % rack_index,
			Vector3(rack_x - 0.30, 2.02, 9.985),
			Vector3(0.52, 0.07, 0.02),
			_materials["cyan"] if in_service else _materials["screen_dark"],
			false
		)
		if in_service:
			_fixture_practical(
				bank,
				"WatchRackStatusSpill",
				Vector3(rack_x - 0.30, 1.94, 10.12),
				Color("7fe0e6"),
				0.30,
				2.0
			)
		_box(bank, "RackBreakerBody%02d" % rack_index, Vector3(rack_x + 0.56, 2.02, 9.965), Vector3(0.26, 0.30, 0.10), _materials["hull_dark"], false)
		_box(
			bank,
			"RackBreakerLever%02d" % rack_index,
			Vector3(rack_x + 0.56, 2.11 if in_service else 1.93, 10.005),
			Vector3(0.06, 0.20, 0.06),
			_materials["brass"],
			false,
			Vector3(-26 if in_service else 26, 0, 0)
		)


## The room's own status board, above the rack bank.
##
## Deliberately not a copy of the registry pod's dispatch board: that one is a
## berth register and lights one tile per registered berth. This is the *aft
## module's* board, and what it draws is this module's route graph — approach,
## junction, stair, upper deck, operations, and the deferred VIP branch that dead
## ends. It is the one place in the station where a player can see the shape of
## the building they are standing in.
func _build_module_status_board(content: Node3D) -> void:
	var board := Node3D.new()
	board.name = "ModuleStatusBoard"
	content.add_child(board)

	# Every z below is measured off the board's *room-facing* face at z = 9.41, not
	# off the wall at 9.31. The first build had the whole board authored on the
	# wrong side of that plane — schematic, annunciators, frame and legend all at
	# z < 9.31 — so the board was buried inside the bulkhead and rendered to nobody.
	# Photographed as a bare plated wall with a brass rectangle drawn on it before
	# this was found, which is exactly the way that class of mistake hides: the one
	# piece thick enough to poke through was the frame.
	#
	# The body is `mid_grey` plate standing 0.10 m proud of the wall, and the chart
	# field on it is `graphite`, which is the module's matte non-plate trim. A board
	# built from the wall's own plate at the wall's own depth is invisible under
	# world triplanar, because the panel field runs straight through it.
	_box(board, "StatusBoardBody", Vector3(6.90, 3.20, 9.36), Vector3(5.40, 1.30, 0.10), _materials["mid_grey"], false)
	_box(board, "StatusBoardField", Vector3(6.90, 3.20, 9.425), Vector3(5.08, 1.02, 0.03), _materials["graphite"], false)
	for rail_y in [2.53, 3.87]:
		_beam_between(board, "StatusBoardRail", Vector3(4.16, float(rail_y), 9.43), Vector3(9.64, float(rail_y), 9.43), 0.042, _materials["brass"], false)
	for rail_x in [4.16, 9.64]:
		_beam_between(board, "StatusBoardStile", Vector3(float(rail_x), 2.53, 9.43), Vector3(float(rail_x), 3.87, 9.43), 0.042, _materials["brass"], false)

	# Route schematic in relief: approach, junction, stair, upper deck, operations,
	# and the deferred branch that dead ends. Board-space X/Y, then the links.
	var schematic_nodes := [
		[4.95, 3.36, "cyan"],
		[6.05, 3.36, "cyan"],
		[7.15, 3.36, "cyan"],
		[7.15, 2.98, "cyan"],
		[8.35, 3.36, "gold"],
		[8.90, 2.98, "screen_dark"],
	]
	var schematic_links := [[0, 1], [1, 2], [2, 3], [2, 4], [4, 5]]
	for link in schematic_links:
		var from_node: Array = schematic_nodes[int(link[0])]
		var to_node: Array = schematic_nodes[int(link[1])]
		var from_point := Vector2(float(from_node[0]), float(from_node[1]))
		var to_point := Vector2(float(to_node[0]), float(to_node[1]))
		var span := to_point - from_point
		var midpoint := (from_point + to_point) * 0.5
		_box(
			board,
			"StatusBoardLink",
			Vector3(midpoint.x, midpoint.y, 9.448),
			Vector3(span.length(), 0.055, 0.018),
			_materials["off_white"],
			false,
			Vector3(0, 0, rad_to_deg(atan2(span.y, span.x)))
		)
	for node_index in schematic_nodes.size():
		var schematic_node: Array = schematic_nodes[node_index]
		var node_x := float(schematic_node[0])
		var node_y := float(schematic_node[1])
		_box(board, "StatusBoardNode%02d" % node_index, Vector3(node_x, node_y, 9.452), Vector3(0.30, 0.30, 0.03), _materials["off_white"], false)
		_box(
			board,
			"StatusBoardNodeLens%02d" % node_index,
			Vector3(node_x, node_y, 9.472),
			Vector3(0.18, 0.18, 0.014),
			_materials[str(schematic_node[2])],
			false
		)

	# Annunciator row. Six units; four made up and lit, one warm and pulsing for
	# working traffic, one dropped and dark. The flag position is the state: a
	# dropped flag hangs clear of the board's bottom edge, so the row still reads
	# as five up and one down with every lamp in the room switched off.
	var annunciator_states := ["up", "up", "pulse", "up", "up", "down"]
	for annunciator_index in annunciator_states.size():
		var annunciator_x := 4.75 + float(annunciator_index) * 0.86
		var state := str(annunciator_states[annunciator_index])
		_box(board, "AnnunciatorBody%02d" % annunciator_index, Vector3(annunciator_x, 2.72, 9.46), Vector3(0.62, 0.24, 0.06), _materials["mid_grey"], false)
		var lens_material: Material = _materials["screen_dark"]
		if state == "up":
			lens_material = _materials["cyan"]
		elif state == "pulse":
			lens_material = _materials["gold"]
		var lens := _box(
			board,
			"AnnunciatorLens%02d" % annunciator_index,
			Vector3(annunciator_x, 2.72, 9.494),
			Vector3(0.48, 0.14, 0.014),
			lens_material,
			false
		) as MeshInstance3D
		if state == "pulse":
			_register_content_lens(lens, "screen_dark", "gold", 2.4, 1.5, 0.0)
		_box(
			board,
			"AnnunciatorFlag%02d" % annunciator_index,
			Vector3(annunciator_x, 2.89 if state != "down" else 2.55, 9.47),
			Vector3(0.46, 0.10, 0.04),
			_materials["off_white"] if state != "down" else _materials["graphite"],
			false
		)

	_text_sign(board, "AFT MODULE STATUS", Vector3(6.90, 3.78, 9.42), Vector3.ZERO, 0.16, _materials["cyan"])
	# Two washes rather than one, for the same reason the coves went from one lamp
	# to three: this board is 5.4 m wide and a single point at its centre lit the
	# middle metre and left both ends outside the range that matters. Sited at the
	# two schematic clusters, 0.42 m proud of the board face, angled at nothing —
	# they are omnis, so what they do is put a gradient across the panel rather than
	# a disc in the middle of it. Photographed dark first at one 0.34 lamp; this is
	# the fix, and it is placement rather than gain, since per-lamp energy is
	# unchanged.
	for wash_x in [5.45, 8.35]:
		_fixture_practical(content, "StatusBoardWash", Vector3(float(wash_x), 3.05, 9.78), Color("9fe6ea"), 0.34, 3.8)


## The room's centrepiece: a traffic plot table in the cleared southern third.
##
## Sited at (6.90, 11.60) so it stands between the rack bank behind it and the
## chair line in front, with 1.0 m of walkway either side. The table is solid at
## its drawn size — base, both pedestals and the top all carry World collision —
## because a chart table a player walks through is worse than no chart table.
func _build_traffic_plot_table(content: Node3D) -> void:
	var table := Node3D.new()
	table.name = "TrafficPlotTable"
	content.add_child(table)

	_box(table, "PlotTableBase", Vector3(6.90, 0.05, 11.60), Vector3(2.10, 0.10, 1.10), _materials["graphite"])
	for pedestal_side in [-1.0, 1.0]:
		_box(table, "PlotTablePedestal", Vector3(6.90 + float(pedestal_side) * 0.72, 0.50, 11.60), Vector3(0.34, 0.80, 0.94), _materials["hull_dark"])
	_box(table, "PlotTableTop", Vector3(6.90, 0.95, 11.60), Vector3(2.50, 0.10, 1.45), _materials["panel_light"])
	_box(table, "PlotTableApron", Vector3(6.90, 0.84, 11.60), Vector3(2.36, 0.12, 1.32), _materials["mid_grey"], false)
	# Working surface either side of the plot: a bordered chart laid out flat under
	# a dark edge trim. Photographed first without them, where the 2.5 x 1.45 m top
	# read as one unbroken white slab with a lit disc dropped into it.
	for chart_side in [-1.0, 1.0]:
		var chart_x := 6.90 + float(chart_side) * 0.98
		_box(table, "PlotChartBorder", Vector3(chart_x, 1.003, 11.60), Vector3(0.54, 0.008, 1.12), _materials["graphite"], false)
		_box(table, "PlotChartSheet", Vector3(chart_x, 1.010, 11.60), Vector3(0.48, 0.008, 1.04), _materials["paper"], false, Vector3(0, float(chart_side) * 1.5, 0))
		_box(table, "PlotTableEdgeTrim", Vector3(6.90, 0.999, 11.60 + float(chart_side) * 0.695), Vector3(2.48, 0.014, 0.055), _materials["graphite"], false)

	# Stowage in the knee space between the pedestals: rolled charts in a cradle.
	_box(table, "ChartCradle", Vector3(6.90, 0.34, 11.60), Vector3(1.00, 0.32, 0.90), _materials["hull_dark"], false)
	for roll_index in 4:
		_cylinder(
			table,
			"StowedChartRoll%02d" % roll_index,
			Vector3(6.62 + float(roll_index % 3) * 0.28, 0.38 + (0.10 if roll_index == 3 else 0.0), 11.60),
			0.046,
			0.84,
			_materials["paper"],
			false,
			Vector3(90, 0, 0)
		)

	# The plot itself. A recessed disc with a lit graticule, ringed in brass.
	_cylinder(table, "PlotDisc", Vector3(6.90, 1.012, 11.60), 0.60, 0.03, _materials["screen_dark"], false)
	_torus(table, "PlotDiscRim", Vector3(6.90, 1.015, 11.60), 0.60, 0.665, _materials["brass"])
	for ring_radius in [0.20, 0.38, 0.56]:
		_torus(table, "PlotGraticuleRing", Vector3(6.90, 1.030, 11.60), float(ring_radius), float(ring_radius) + 0.011, _materials["cyan_dim"])
	for bearing in [0.0, 45.0, 90.0, 135.0]:
		_box(table, "PlotGraticuleBearing", Vector3(6.90, 1.029, 11.60), Vector3(0.012, 0.006, 1.14), _materials["cyan_dim"], false, Vector3(0, float(bearing), 0))
	_cylinder(table, "PlotHub", Vector3(6.90, 1.055, 11.60), 0.075, 0.09, _materials["hull_dark"], false)

	# Traffic tokens. Bearing/range on the plot is where the hull is; the pin is
	# whether it is still inbound. Berthed hulls sit flush, inbound stand proud.
	var tokens := [
		[18.0, 0.50, true],
		[104.0, 0.34, false],
		[168.0, 0.52, false],
		[238.0, 0.26, false],
		[302.0, 0.47, true],
	]
	for token_index in tokens.size():
		var token: Array = tokens[token_index]
		var bearing_radians := deg_to_rad(float(token[0]))
		var token_range := float(token[1])
		var inbound := bool(token[2])
		var token_position := Vector3(
			6.90 + cos(bearing_radians) * token_range,
			1.039,
			11.60 + sin(bearing_radians) * token_range
		)
		_cylinder(table, "PlotToken%02d" % token_index, token_position, 0.055, 0.028, _materials["panel_light"], false)
		_cylinder(
			table,
			"PlotTokenPin%02d" % token_index,
			token_position + Vector3(0.0, 0.09 if inbound else 0.018, 0.0),
			0.011 if inbound else 0.03,
			0.16 if inbound else 0.014,
			_materials["gold"] if inbound else _materials["cyan"],
			false
		)

	# Rim rail. A chart table on a station gets one, and it gives the top an edge
	# that catches the ceiling rows instead of reading as a flat slab.
	for rail_side in [-1.0, 1.0]:
		var rail_z := 11.60 + float(rail_side) * 0.70
		for post_x in [5.78, 8.02]:
			_cylinder(table, "PlotRimPost", Vector3(float(post_x), 1.06, rail_z), 0.022, 0.20, _materials["brass"], false)
		_beam_between(table, "PlotRimRail", Vector3(5.78, 1.15, rail_z), Vector3(8.02, 1.15, rail_z), 0.024, _materials["brass"], false)

	# The indexing sweep. One assembly, driven from `_process`; see
	# `_update_operations_content`.
	var sweep := Node3D.new()
	sweep.name = "PlotSweepArm"
	sweep.position = Vector3(6.90, 1.075, 11.60)
	table.add_child(sweep)
	_sweep_arm = sweep
	_box(sweep, "SweepBeam", Vector3(0.0, 0.0, 0.30), Vector3(0.045, 0.022, 0.60), _materials["brass"], false)
	_box(sweep, "SweepHead", Vector3(0.0, -0.005, 0.575), Vector3(0.11, 0.05, 0.11), _materials["hull_dark"], false)
	_box(sweep, "SweepLens", Vector3(0.0, -0.032, 0.575), Vector3(0.06, 0.014, 0.06), _materials["worklight"], false)
	_fixture_practical(sweep, "PlotSweepLamp", Vector3(0.0, -0.07, 0.575), Color("bfeef2"), 0.22, 1.5)

	# What a working table has on it.
	_box(table, "PlotLogbookCover", Vector3(5.98, 1.012, 12.06), Vector3(0.32, 0.024, 0.24), _materials["graphite"], false, Vector3(0, 14, 0))
	_box(table, "PlotLogbookPages", Vector3(5.98, 1.031, 12.06), Vector3(0.29, 0.016, 0.21), _materials["paper"], false, Vector3(0, 14, 0))
	_cylinder(table, "PlotDutyMug", Vector3(7.92, 1.052, 12.12), 0.045, 0.105, _materials["off_white"], false)
	_torus(table, "PlotDutyMugHandle", Vector3(7.985, 1.055, 12.12), 0.022, 0.042, _materials["off_white"], Vector3(0, 0, 90))
	_box(table, "PlotGlove", Vector3(6.06, 1.022, 11.12), Vector3(0.10, 0.044, 0.23), _materials["fabric"], false, Vector3(0, -24, 0))
	_box(table, "PlotGloveSecond", Vector3(6.22, 1.021, 11.02), Vector3(0.10, 0.042, 0.23), _materials["fabric"], false, Vector3(0, -6, 0))
	_box(table, "PlotDividers", Vector3(7.72, 1.008, 11.10), Vector3(0.20, 0.016, 0.03), _materials["brass"], false, Vector3(0, 32, 0))
	# The plot glass is the only lit surface on the table, and in this renderer a
	# lit surface illuminates nothing, so without this the table's own light landed
	# on nobody's face and it read as a printed disc. Sited above the plot so it
	# washes the rim, the tokens and whoever is leaning over them.
	_fixture_practical(table, "PlotTableGlow", Vector3(6.90, 1.24, 11.60), Color("93e4ea"), 0.30, 2.6)


## The coordinator's working position.
##
## The fourth chair sat alone at (1.7, 12.0), yawed off the console line, with
## nothing in front of it — a chair facing a bare deck. The desk goes exactly
## where that chair is already looking, 1.09 m out along its own facing, and is
## kept east of x = 2.54 so it never stands in the doorway walk line at x = 2.2.
func _build_coordinator_desk(content: Node3D) -> void:
	var desk := Node3D.new()
	desk.name = "CoordinatorDesk"
	desk.position = Vector3(3.10, 0.0, 11.65)
	desk.rotation_degrees.y = -72.0
	content.add_child(desk)

	_box(desk, "CoordinatorDeskBody", Vector3(0.0, 0.36, 0.0), Vector3(1.50, 0.72, 0.68), _materials["mid_grey"])
	_box(desk, "CoordinatorDeskTop", Vector3(0.0, 0.76, 0.0), Vector3(1.66, 0.08, 0.82), _materials["panel_light"])
	_box(desk, "CoordinatorDeskKick", Vector3(0.0, 0.06, -0.35), Vector3(1.32, 0.11, 0.05), _materials["rubber"], false)
	for drawer_side in [-1.0, 1.0]:
		var drawer_x := float(drawer_side) * 0.36
		_box(desk, "CoordinatorDeskDrawer", Vector3(drawer_x, 0.52, -0.35), Vector3(0.62, 0.22, 0.04), _materials["off_white"], false)
		_beam_between(desk, "CoordinatorDeskPull", Vector3(drawer_x - 0.19, 0.52, -0.38), Vector3(drawer_x + 0.19, 0.52, -0.38), 0.018, _materials["brass"], false)

	# Task lamp. The room's overheads are 4 m up and 3 m away from this corner.
	_cylinder(desk, "CoordinatorLampStalk", Vector3(-0.62, 1.02, 0.16), 0.022, 0.44, _materials["hull_dark"], false)
	_box(desk, "CoordinatorLampHead", Vector3(-0.62, 1.255, 0.055), Vector3(0.20, 0.09, 0.15), _materials["hull_dark"], false, Vector3(24, 0, 0))
	_box(desk, "CoordinatorLampLens", Vector3(-0.62, 1.208, 0.038), Vector3(0.15, 0.02, 0.10), _materials["amber_light"], false, Vector3(24, 0, 0))
	_fixture_practical(desk, "CoordinatorLampSpill", Vector3(-0.62, 1.10, -0.02), Color("f6c98c"), 0.34, 2.2)

	# The duty log, open, because somebody is on watch.
	_box(desk, "DutyLogCover", Vector3(-0.08, 0.812, -0.02), Vector3(0.54, 0.026, 0.34), _materials["graphite"], false, Vector3(0, 6, 0))
	_box(desk, "DutyLogLeaf", Vector3(-0.21, 0.831, -0.02), Vector3(0.26, 0.014, 0.31), _materials["paper"], false, Vector3(0, 6, -3))
	_box(desk, "DutyLogLeafFacing", Vector3(0.05, 0.831, -0.02), Vector3(0.26, 0.014, 0.31), _materials["paper"], false, Vector3(0, 6, 3))
	_cylinder(desk, "DutyLogPen", Vector3(-0.06, 0.846, 0.14), 0.008, 0.16, _materials["brass"], false, Vector3(0, 74, 90))

	# Handset and its cord, which is what an operations desk actually is.
	_box(desk, "DeskHandsetCradle", Vector3(0.52, 0.834, 0.12), Vector3(0.17, 0.07, 0.24), _materials["hull_dark"], false)
	_box(desk, "DeskHandset", Vector3(0.52, 0.897, 0.12), Vector3(0.10, 0.07, 0.25), _materials["graphite"], false)
	_beam_between(desk, "DeskHandsetCord", Vector3(0.52, 0.83, 0.24), Vector3(0.62, 0.60, 0.34), 0.012, _materials["copper"], false)
	_box(desk, "DeskManualStack", Vector3(0.34, 0.826, -0.22), Vector3(0.24, 0.05, 0.32), _materials["paper"], false, Vector3(0, -9, 0))
	_box(desk, "DeskManualStackUpper", Vector3(0.33, 0.868, -0.21), Vector3(0.23, 0.04, 0.30), _materials["graphite"], false, Vector3(0, 4, 0))

	# Headset on a hook on the desk end, where a watch-keeper leaves it.
	_cylinder(desk, "DeskHeadsetHook", Vector3(0.83, 0.70, 0.02), 0.016, 0.09, _materials["brass"], false, Vector3(0, 0, 90))
	_torus(desk, "DeskHeadsetBand", Vector3(0.855, 0.605, 0.02), 0.065, 0.095, _materials["graphite"], Vector3(0, 0, 90))
	for cup_side in [-1.0, 1.0]:
		_cylinder(desk, "DeskHeadsetCup", Vector3(0.855, 0.545, 0.02 + float(cup_side) * 0.078), 0.036, 0.03, _materials["fabric"], false, Vector3(90, 0, 0))


## Chart press and notice board down the bare west wall.
func _build_chart_press(content: Node3D) -> void:
	var press := Node3D.new()
	press.name = "ChartPress"
	press.position = Vector3(0.95, 0.0, 14.60)
	content.add_child(press)

	_box(press, "ChartPressBody", Vector3(0.0, 0.47, 0.0), Vector3(0.68, 0.94, 1.76), _materials["mid_grey"])
	_box(press, "ChartPressTop", Vector3(0.0, 0.975, 0.0), Vector3(0.76, 0.07, 1.86), _materials["panel_light"])
	_box(press, "ChartPressKick", Vector3(0.05, 0.06, 0.0), Vector3(0.60, 0.12, 1.80), _materials["rubber"], false)
	for drawer_index in 5:
		var drawer_y := 0.17 + float(drawer_index) * 0.16
		_box(press, "ChartPressDrawer%02d" % drawer_index, Vector3(-0.345, drawer_y, 0.0), Vector3(0.04, 0.13, 1.62), _materials["off_white"], false)
		_beam_between(
			press,
			"ChartPressPull%02d" % drawer_index,
			Vector3(-0.375, drawer_y, -0.30),
			Vector3(-0.375, drawer_y, 0.30),
			0.017,
			_materials["brass"],
			false
		)
	# Rolls stacked on the press top, in a shallow pyramid so they read as stock.
	for roll_index in 4:
		var roll_offset := [-0.24, -0.12, 0.0, -0.18][roll_index] as float
		_cylinder(
			press,
			"ChartPressRoll%02d" % roll_index,
			Vector3(roll_offset, 1.055 if roll_index < 3 else 1.142, 0.0),
			0.05,
			1.46,
			_materials["paper"],
			false,
			Vector3(90, 0, 0)
		)
	_box(press, "ChartPressStrap", Vector3(-0.12, 1.10, 0.44), Vector3(0.40, 0.11, 0.05), _materials["fabric"], false)

	# Notice board, bolted flat to the west wall face at x = 0.59.
	_box(press, "NoticeBoard", Vector3(-0.335, 2.35, 0.0), Vector3(0.05, 1.05, 1.50), _materials["graphite"], false)
	for sheet_index in 7:
		var sheet_row := int(sheet_index / 4)
		var sheet_column := sheet_index % 4
		_box(
			press,
			"NoticeSheet%02d" % sheet_index,
			Vector3(-0.306, 2.62 - float(sheet_row) * 0.44, -0.54 + float(sheet_column) * 0.36),
			Vector3(0.012, 0.28, 0.21),
			_materials["paper"],
			false,
			Vector3(float(sheet_index % 3) * 2.5 - 2.5, 0, 0)
		)
	for pin_index in 2:
		_cylinder(
			press,
			"NoticePin%02d" % pin_index,
			Vector3(-0.292, 2.72, -0.54 + float(pin_index) * 1.08),
			0.012,
			0.02,
			_materials["gold"],
			false,
			Vector3(0, 0, 90)
		)
	_cylinder(press, "ClipboardHook", Vector3(-0.315, 1.615, -0.65), 0.02, 0.11, _materials["brass"], false, Vector3(0, 0, 90))
	_box(press, "Clipboard", Vector3(-0.295, 1.43, -0.65), Vector3(0.02, 0.36, 0.25), _materials["graphite"], false, Vector3(0, 0, -4))
	_box(press, "ClipboardSheet", Vector3(-0.283, 1.44, -0.65), Vector3(0.008, 0.30, 0.21), _materials["paper"], false, Vector3(0, 0, -4))
	_fixture_practical(press, "NoticeBoardWash", Vector3(0.12, 2.30, 0.0), Color("f0c48c"), 0.28, 2.4)


## Hot drinks in the dead north-west corner.
##
## Every crewed watch room has one and this corner had nothing in it: the console
## line stops at x = 2.03 and the window sill starts at z = 17.09, leaving a
## 1.4 x 0.9 m pocket that no fixture, route or piece of furniture used.
func _build_refreshment_stand(content: Node3D) -> void:
	var stand := Node3D.new()
	stand.name = "RefreshmentStand"
	stand.position = Vector3(1.32, 0.0, 16.52)
	content.add_child(stand)

	_box(stand, "RefreshmentCounter", Vector3(0.0, 0.44, 0.0), Vector3(1.34, 0.88, 0.60), _materials["mid_grey"])
	_box(stand, "RefreshmentTop", Vector3(0.0, 0.92, 0.0), Vector3(1.48, 0.08, 0.70), _materials["panel_light"])
	_box(stand, "RefreshmentKick", Vector3(0.0, 0.06, -0.31), Vector3(1.22, 0.11, 0.05), _materials["rubber"], false)
	for door_side in [-1.0, 1.0]:
		_box(stand, "RefreshmentDoor", Vector3(float(door_side) * 0.32, 0.50, -0.315), Vector3(0.58, 0.62, 0.04), _materials["off_white"], false)
		_beam_between(
			stand,
			"RefreshmentDoorPull",
			Vector3(float(door_side) * 0.32, 0.74, -0.345),
			Vector3(float(door_side) * 0.32, 0.60, -0.345),
			0.016,
			_materials["brass"],
			false
		)

	_cylinder(stand, "WaterUrn", Vector3(-0.36, 1.175, 0.0), 0.155, 0.44, _materials["off_white"], false)
	_torus(stand, "WaterUrnCollar", Vector3(-0.36, 0.985, 0.0), 0.155, 0.19, _materials["brass"])
	_cylinder(stand, "WaterUrnLid", Vector3(-0.36, 1.425, 0.0), 0.17, 0.05, _materials["mid_grey"], false)
	_box(stand, "WaterUrnSightGlass", Vector3(-0.235, 1.16, -0.10), Vector3(0.03, 0.24, 0.03), _materials["cyan_dim"], false)
	_beam_between(stand, "WaterUrnTap", Vector3(-0.36, 1.03, -0.14), Vector3(-0.36, 1.03, -0.25), 0.018, _materials["brass"], false)
	_cylinder(stand, "WaterUrnTapHandle", Vector3(-0.36, 1.10, -0.24), 0.012, 0.10, _materials["brass"], false)
	_box(stand, "MugTray", Vector3(0.28, 0.975, 0.0), Vector3(0.48, 0.03, 0.32), _materials["graphite"], false)
	for mug_index in 4:
		_cylinder(
			stand,
			"StowedMug%02d" % mug_index,
			Vector3(0.16 + float(mug_index / 2) * 0.24, 1.035, -0.08 + float(mug_index % 2) * 0.16),
			0.045,
			0.10,
			_materials["off_white"],
			false
		)
	_fixture_practical(stand, "RefreshmentSpill", Vector3(0.0, 1.52, -0.14), Color("f6c98c"), 0.26, 2.0)

	_cylinder(content, "WasteBin", Vector3(1.75, 0.26, 15.75), 0.185, 0.52, _materials["hull_dark"], true)
	_torus(content, "WasteBinRim", Vector3(1.75, 0.51, 15.75), 0.185, 0.215, _materials["rubber"])


## The traces that say people work here rather than that a room was furnished.
func _build_console_line_traces(content: Node3D) -> void:
	var traces := Node3D.new()
	traces.name = "CrewTraces"
	content.add_child(traces)

	# A headset hung over the middle console's edge rail, which is at world
	# (6.0, 1.43, 15.14) with a 2.18 m span, so this hangs on real geometry.
	_torus(traces, "ConsoleHeadsetBand", Vector3(6.78, 1.33, 15.14), 0.065, 0.098, _materials["graphite"], Vector3(0, 0, 90))
	for cup_side in [-1.0, 1.0]:
		_cylinder(traces, "ConsoleHeadsetCup", Vector3(6.78 + float(cup_side) * 0.078, 1.29, 15.14), 0.036, 0.03, _materials["fabric"], false, Vector3(0, 0, 90))
	# A stack of manuals left on the deck behind the third console plinth.
	_box(traces, "StowedManualBase", Vector3(9.62, 0.035, 16.42), Vector3(0.30, 0.07, 0.40), _materials["graphite"], false, Vector3(0, 8, 0))
	_box(traces, "StowedManualUpper", Vector3(9.60, 0.095, 16.44), Vector3(0.29, 0.05, 0.38), _materials["paper"], false, Vector3(0, -5, 0))
	_box(traces, "StowedManualTop", Vector3(9.63, 0.142, 16.40), Vector3(0.28, 0.04, 0.37), _materials["paper"], false, Vector3(0, 14, 0))


## Aft-module content at the head of its own stair.
##
## The upper landing carries a crew workpost, but that post is a
## `StationOperationsActivity` placement the hub drops onto this deck — it is not
## the aft module's own content, and the module contributed nothing at the point
## where a player finishes the climb. This is the module's piece: the muster
## locker every pressurised station puts at the top of its only vertical route,
## with the aft route board on its head so the climb ends at something that tells
## you where you are.
##
## Sited at (-2.55, 13.55) on the east half of the upper deck — inboard of
## `UpperSouthReturnRail`, 4.5 m clear of the workpost, and well off the stair
## mouth at x = -5.7, so nothing here narrows the route the traversal sweep walks.
func _build_stair_head_muster(upper: Node3D) -> void:
	var muster := Node3D.new()
	muster.name = "StairHeadMuster"
	muster.position = Vector3(-2.55, 4.2, 13.55)
	upper.add_child(muster)

	# The carcass is deliberately two bodies rather than one solid block, because a
	# locker with an open door has to have something behind that door. Built solid
	# first: the door swung wide onto the flat face of a 0.58 m box, and the reel
	# and kit cases authored "inside" it were buried in it and rendered to nobody.
	# `MusterLockerBody` is the rear 0.30 m across the full width;
	# `MusterLockerRightBay` fills the front 0.28 m of the sealed half only. What is
	# left is a real 0.28 m recess behind the open door, with its own side, top and
	# floor, and the collision follows that shape — a player can step into the open
	# bay exactly as far as the drawn recess goes.
	#
	# `warm_grey` rather than the rack bank's `mid_grey`. Photographed both: this
	# locker stands on the open upper deck, which is the module's brightest
	# `off_white_floor` plate under a directional key, and the darker structural
	# grey read as a black monolith dropped on a white deck. The rack bank keeps
	# `mid_grey` because it is indoors under six cool overheads.
	_box(muster, "MusterLockerBody", Vector3(0.0, 0.975, 0.14), Vector3(1.50, 1.95, 0.30), _materials["warm_grey"])
	_box(muster, "MusterLockerRightBay", Vector3(0.37, 0.975, -0.15), Vector3(0.74, 1.95, 0.28), _materials["warm_grey"])
	_box(muster, "MusterLockerBaySide", Vector3(-0.7225, 0.975, -0.15), Vector3(0.055, 1.95, 0.28), _materials["warm_grey"], false)
	_box(muster, "MusterLockerBayTop", Vector3(-0.37, 1.925, -0.15), Vector3(0.75, 0.05, 0.28), _materials["warm_grey"], false)
	_box(muster, "MusterLockerBayFloor", Vector3(-0.37, 0.025, -0.15), Vector3(0.75, 0.05, 0.28), _materials["graphite"], false)
	_box(muster, "MusterLockerCap", Vector3(0.0, 1.98, 0.0), Vector3(1.58, 0.06, 0.64), _materials["hull_dark"], false)
	# Right-hand door closed and sealed; left-hand door standing open, because a
	# muster locker that has never been opened is a painted box.
	_box(muster, "MusterDoorClosed", Vector3(0.36, 1.02, -0.30), Vector3(0.70, 1.72, 0.05), _materials["panel_light"], false)
	_cylinder(muster, "MusterDoorLatch", Vector3(0.68, 1.02, -0.34), 0.028, 0.16, _materials["brass"], false)
	_box(muster, "MusterSealTag", Vector3(0.68, 0.88, -0.35), Vector3(0.10, 0.16, 0.008), _materials["red"], false, Vector3(0, 0, -8))
	var open_door := Node3D.new()
	open_door.name = "MusterDoorOpenHinge"
	open_door.position = Vector3(-0.72, 1.02, -0.29)
	open_door.rotation_degrees.y = -46.0
	muster.add_child(open_door)
	_box(open_door, "MusterDoorOpen", Vector3(0.35, 0.0, 0.0), Vector3(0.70, 1.72, 0.05), _materials["panel_light"], false)
	_cylinder(open_door, "MusterDoorOpenPull", Vector3(0.64, 0.0, -0.05), 0.022, 0.16, _materials["brass"], false)
	# What is in the open bay. A hose reel bracketed to the carcass back, and three
	# kit cases stacked off the bay floor.
	_box(muster, "MusterLockerBayBack", Vector3(-0.37, 1.00, -0.008), Vector3(0.73, 1.85, 0.03), _materials["graphite"], false)
	_torus(muster, "MusterHoseReel", Vector3(-0.37, 1.32, -0.14), 0.12, 0.24, _materials["copper"], Vector3(90, 0, 0))
	_cylinder(muster, "MusterHoseHub", Vector3(-0.37, 1.32, -0.13), 0.07, 0.26, _materials["hull_dark"], false, Vector3(90, 0, 0))
	for kit_index in 3:
		_box(
			muster,
			"MusterKitCase%02d" % kit_index,
			Vector3(-0.37, 0.16 + float(kit_index) * 0.19, -0.14),
			Vector3(0.58, 0.18, 0.24),
			_materials["off_white"] if kit_index % 2 else _materials["panel_light"],
			false
		)
	# Route headboard, on two posts standing on the locker cap. Mounting it on the
	# locker's own front face was tried first and there is no room there — the
	# doors run to within 0.07 m of the top — so it would have been a panel hanging
	# in front of a door with nothing behind it. Posts stand on the cap at
	# y = 2.01 and the board bears on the posts, so the whole assembly is carried.
	for post_side in [-1.0, 1.0]:
		_cylinder(muster, "MusterHeadboardPost", Vector3(float(post_side) * 0.50, 2.11, -0.20), 0.03, 0.20, _materials["mid_grey"], false)
	_box(muster, "MusterRouteBoard", Vector3(0.0, 2.36, -0.20), Vector3(1.34, 0.42, 0.06), _materials["hull_dark"], false)
	for bar_index in 3:
		_box(
			muster,
			"MusterRouteBar%02d" % bar_index,
			Vector3(-0.36 + float(bar_index) * 0.36, 2.28, -0.238),
			Vector3(0.30, 0.026, 0.014),
			_materials["cyan"],
			false
		)
	_box(muster, "MusterRouteHere", Vector3(0.36, 2.28, -0.240), Vector3(0.07, 0.07, 0.014), _materials["gold"], false)
	_text_sign(muster, "MUSTER POINT", Vector3(0.0, 2.47, -0.240), Vector3(0, 180, 0), 0.15, _materials["gold"])
	_box(muster, "MusterLampLens", Vector3(0.0, 2.59, -0.20), Vector3(0.34, 0.05, 0.07), _materials["amber_light"], false)
	_fixture_practical(muster, "MusterLockerLamp", Vector3(0.0, 2.46, -0.40), Color("f0c48c"), 0.30, 2.4)


## Register a lens that alternates between two of this module's materials.
##
## The same mechanism the station-life pass uses on the workpost's weld arc, and
## for the same reason: a swap between two pre-built materials is a closed-form
## function of the clock, so a 120 Hz frame and one 30 Hz step land on the same
## state and nothing accumulates across frames.
func _register_content_lens(
		lens: MeshInstance3D,
		dim_key: String,
		lit_key: String,
		period: float,
		duty: float,
		offset: float
	) -> void:
	_content_lenses.append(lens)
	_content_lens_specs.append({
		"dim": dim_key,
		"lit": lit_key,
		"period": period,
		"duty": duty,
		"offset": offset,
	})


## The module's one frame loop.
##
## Two things move and one blinks, all of them closed-form in `_content_clock`:
## the plot table's sweep arm indexes round its disc, the annunciator that stands
## for working traffic pulses, and that is the whole loop. It is budgeted as the
## module's single `process_loops` and it stops with the module — see
## `_apply_enabled_state`, which is what keeps `process_matches_lifecycle` true.
func _process(delta: float) -> void:
	# Wrapped rather than free-running so a long session cannot walk the float
	# into a range where `fmod` on the lens period starts to quantise.
	_content_clock = fmod(_content_clock + delta, 3600.0)
	_update_operations_content()


func _update_operations_content() -> void:
	if _sweep_arm != null:
		# 0.42 rad/s: about fifteen seconds a revolution, slow enough to read as an
		# instrument sweeping rather than a fan.
		_sweep_arm.rotation.y = fmod(_content_clock * 0.42, TAU)
	for lens_index in _content_lenses.size():
		var spec: Dictionary = _content_lens_specs[lens_index]
		var pulse := fmod(_content_clock + float(spec["offset"]), float(spec["period"]))
		_content_lenses[lens_index].material_override = (
			_materials[str(spec["lit"])] if pulse < float(spec["duty"]) else _materials[str(spec["dim"])]
		)


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
	_interface_collar(chair, "PedestalBearing", Vector3(0, 0.68, 0), 0.18, 0.25, _materials["copper"])
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
	# The coordinator's coverall, left over the back of their own chair. One trace,
	# on the one seat the room is arranged around, draped across the back frame it
	# hangs on so it is bearing on drawn geometry rather than hovering behind it.
	if chair_index == 3:
		_box(chair, "StowedCoverall", Vector3(0.0, 1.66, 0.50), Vector3(0.84, 0.62, 0.11), _materials["fabric"], false, Vector3(-9, 0, 0))
		_box(chair, "StowedCoverallCollar", Vector3(0.0, 1.98, 0.47), Vector3(0.52, 0.14, 0.15), _materials["fabric"], false, Vector3(-9, 0, 0))
		_box(chair, "StowedCoverallSleeve", Vector3(-0.40, 1.34, 0.46), Vector3(0.16, 0.52, 0.12), _materials["fabric"], false, Vector3(-6, 0, 7))


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
		_interface_collar(service, "ConduitCollar", Vector3(-0.55, 2.95, pipe_z), 0.1, 0.16, _materials["brass"], Vector3(90, 0, 0))
	_beam_between(service, "ServiceBus", Vector3(-0.66, 4.15, -2.85), Vector3(-0.66, 4.15, 2.85), 0.065, _materials["copper"], false)
	# Three status strips in a recessed cabinet face, none of which lit the recess
	# they sit in — the exact "glowing decal" reading. One practical per strip,
	# tinted to that strip's own cue colour, so the middle cabinet's warm strip and
	# the two flanking cool ones are told apart by the light they throw as well as
	# by the strip itself. Range is 1.4 m: this washes the cabinet recess and
	# stops, rather than spilling across the room and diluting the cue.
	for cabinet_index in 3:
		var status_z := -2.05 + float(cabinet_index) * 2.05
		_fixture_practical(
			service,
			"CabinetStatusSpill",
			Vector3(-0.72, 2.38, status_z),
			Color("f2c07f") if cabinet_index == 1 else Color("7fe0e6"),
			0.3,
			1.4
		)


func _build_vip_landmark(structure: Node3D) -> void:
	var vip := Node3D.new()
	vip.name = "VIPLandmark"
	structure.add_child(vip)
	# The facade is split around the real door so its red panel remains visible.
	#
	# `VIPShallowBackstop` used to close the opening 0.14 m behind the leaf: a
	# solid plate that made "no unsupported VIP interior" true in geometry rather
	# than only in a label. It is deliberately gone. The doorway now opens into
	# `VipReceptionSuite`, whose threshold shell laps this facade, and the evidence
	# statement it used to carry has moved to that module's own metadata and to the
	# legend on the plinth two metres beyond this frame — which says the same thing
	# to a player standing in the room rather than to a reader of this file.
	_box(vip, "VIPFacadeLeft", Vector3(-8.9, 6.25, 20.38), Vector3(2.8, 4.1, 0.52), _materials["warm_grey"])
	_box(vip, "VIPFacadeRight", Vector3(-1.45, 6.25, 20.38), Vector3(2.5, 4.1, 0.52), _materials["warm_grey"])
	_box(vip, "VIPFacadeHeader", Vector3(-5.15, 8.12, 20.38), Vector3(10.3, 0.76, 0.52), _materials["warm_grey"])
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
	#
	# Retitled with the interior. `DEFERRED` was the honest word while the doorway
	# was a plate; it is a false one now that a player can walk through it, and the
	# legend that replaces it says exactly what is on the other side.
	_text_sign(vip, "VIP RECEPTION  //  MODERN INTERPRETATION", Vector3(-5.15, 7.75, 19.64), Vector3(0, 180, 0), 0.22, _materials["red"])


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
	# Warm wash on the identity plaque, matching its gold legend. The plaque is
	# deliberately unbacked, so this lights the envelope wall a metre behind it and
	# the plaque reads as standing off a lit surface rather than floating.
	_fixture_practical(details, "JunctionLegendWash", Vector3(0.0, 1.05, 10.1), Color("f0be7c"), 0.32, 2.8)


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


## A luminaire's spill, as an actual light.
##
## Every lit fixture in this module previously read as a painted decal, and the
## reason is mechanical rather than a matter of degree. `emission` is a purely
## local surface term in Forward+: it changes what the emitting fragment returns
## and nothing else. The glow pass then convolves the finished *image*, so a
## bright lens grows a halo in screen space but still contributes zero radiance
## to the plate it is bolted to. Raising emission therefore cannot make a sign
## light its own backing panel — it only pushes the lens further past the
## tonemapper's shoulder and widens the bloom, which is precisely the bimodal
## frame this pass was asked to fix. The only mechanism in this renderer that
## lights a mount is a Light3D, so that is what these are.
##
## They are deliberately small, and every property here is a restraint:
## shadowless, sub-7 m range, steeper attenuation than the room fills, and faded
## out by 85 m so the whole-lattice overview pays for none of them. Each carries
## its own fixture's hue, so the spill identifies the source rather than adding
## an anonymous lift. Where one is added the lens emission comes down by roughly
## what the practical now carries: the change moves energy out of the blown top
## of the histogram into the 20-40 structural band instead of adding gain. Frame
## cost is unmeasured and unmeasurable here — this box renders through llvmpipe.
##
## The fade distance is measured, not chosen. It was first set at 16 m begin /
## 8 m length, and every one of these lights was then off in every rendered
## framing except the two interiors: measured across the six station-operations
## frames and `aft_junction`/`station`/`fleet_overview`, structural sigma moved
## by -0.9% to +0.1% — the emission that came out of the lenses was real and the
## spill that was supposed to replace it never arrived. The station is a 10-50 m
## structure normally read from 30-70 m, so a fade that ends at 24 m ends inside
## the subject. 60 m begin / 25 m length keeps the practicals present at every
## distance the station is actually looked at and still switches them off for the
## 140 m-plus lattice overview.
func _fixture_practical(
		parent: Node3D,
		node_name: String,
		light_position: Vector3,
		color: Color,
		energy: float,
		range_value: float
	) -> OmniLight3D:
	var light := _omni_light(parent, node_name, light_position, color, energy, range_value)
	light.omni_attenuation = 2.1
	light.distance_fade_begin = PRACTICAL_FADE_BEGIN
	light.distance_fade_length = PRACTICAL_FADE_LENGTH
	light.set_meta("fixture_practical", true)
	return light


## Marks only the small, visual-only collars wrapped around an existing solid
## support or service run. The wrapped mesh/body remains the collision and
## semantic authority; this TorusMesh is presentation trim with no children.
func _interface_collar(
		parent: Node3D,
		node_name: String,
		torus_position: Vector3,
		inner_radius: float,
		outer_radius: float,
		material: Material,
		rotation_degrees_value: Vector3 = Vector3.ZERO
	) -> MeshInstance3D:
	var instance := _torus(
		parent,
		node_name,
		torus_position,
		inner_radius,
		outer_radius,
		material,
		rotation_degrees_value
	)
	instance.set_meta(
		TorusGeometryBudget.PROFILE_META,
		TorusGeometryBudget.PROFILE_AFT_INTERFACE_COLLAR
	)
	instance.set_meta(INTERFACE_COLLAR_KIND_META, StringName(node_name))
	return instance


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
