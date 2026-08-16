class_name HabitatSpine
extends Node3D

## Reusable, physically explorable habitat insertion for the station lattice.
##
## The later secondary C1 walkthrough visibly contains a habitat entry, bunks,
## and a chair-lined corridor. Its exact build provenance is not independently
## established, and the 2009 A3 comments describe bunks as requested/planned at
## that snapshot. Consequently this module is a fixed-era-inspired modern
## interpretation, never a claim of recovered launch-era or original geometry.

const SCHEMA_VERSION := 1
const MODULE_ID: StringName = &"habitat-spine"
const EVIDENCE_STATUS: StringName = &"fixed_era_inspired_modern_interpretation"
## Declared station connection slot. `ShipyardWorld` publishes the matching hub
## endpoint; the pair is what `StationRouteRegistry` records as one graph edge.
const HUB_CONNECTION_SLOT: StringName = &"hub-starboard-habitat"
const WORLD_LAYER := PhysicsLayers.WORLD

## Physical size of one station panel plate in this module, in metres of world
## space per texture repeat. Frozen.
const PANEL_SURFACE_SCALE := 0.28

## Distance fade applied to every fixture practical in this module. Measured, not
## chosen — see `_fixture_practical`.
const PRACTICAL_FADE_BEGIN := 60.0
const PRACTICAL_FADE_LENGTH := 25.0

const FLOOR_ELEVATION := 0.0
const CONNECTOR_CLEAR_WIDTH := 4.45
const DOOR_CLEAR_WIDTH := 3.1
const CORRIDOR_CLEAR_WIDTH := 4.6
const MINIMUM_HEAD_CLEARANCE := 4.0
const BUNK_ALCOVE_COUNT := 6
const COMMON_CHAIR_COUNT := 8

## Which of the six berths are currently taken, in alcove order.
##
## Read by both the alcove dressing and the common room's berth roster board, so
## a berth cannot say "taken" on the board and stand stripped in the corridor.
## Four of six is a deliberate number: a full habitat has nothing to say, and an
## empty one is the state the module was already in.
##
## This is a *hardware* state in the sense `fleet_dock_comb.gd` means it. A taken
## berth has its curtain half drawn, a blanket on the mattress, boots and a kit
## bag on the deck, a coverall on the hook, a closed locker and a name card in
## its slot. A free berth has the curtain bunched clear, folded linen where the
## blanket was, a bare hook, the locker shutter rolled up on empty shelves and an
## empty card slot. Only the mouth plate and the board tile change colour; every
## other difference is a different object in a different place, which is what
## makes the state legible from the corridor rather than needing a legend.
const BUNK_BERTH_OCCUPANCY := [true, true, false, true, false, true]

## Local z of the inner faces of the two alcove partitions that bound each row.
##
## Derived from the `boundary_z` list in `_build_habitat_corridor`
## (`2.35, 7.3, 7.9, 12.3, 12.9, 17.95`) minus the partitions' 0.12 m half
## thickness, expressed relative to each row's bunk centre (`5.1, 10.1, 15.1`).
## The mouth jambs are sized from these so both ends bury into real plate instead
## of stopping in air; the rows are not symmetric, so one shared number would
## have left a 0.55 m gap at the end of rows 1 and 3.
const BUNK_MOUTH_AFT_FACE := [-2.63, -2.08, -2.08]
const BUNK_MOUTH_FORWARD_FACE := [2.08, 2.08, 2.73]

const CONNECTOR_CENTER := Vector3(0.0, 1.85, -1.7)
const CONNECTOR_HALF_EXTENTS := Vector3(2.55, 1.95, 2.3)
const CORRIDOR_CENTER := Vector3(0.0, 2.25, 10.15)
const CORRIDOR_HALF_EXTENTS := Vector3(2.3, 2.3, 7.55)
const COMMON_CENTER := Vector3(0.0, 2.35, 23.2)
const COMMON_HALF_EXTENTS := Vector3(7.25, 2.4, 5.15)
const BUNK_ROOM_HALF_EXTENTS := Vector3(1.72, 2.3, 1.82)

const FOOTPRINT_MIN := Vector3(-9.0, -1.6, -4.25)
const FOOTPRINT_MAX := Vector3(9.0, 6.8, 29.25)

const EVIDENCE_REFERENCES := [
	"RESEARCH.md:C1@01:20-02:30 / later secondary habitat entry, bunks, chair-lined corridor, and consoles",
	"RESEARCH.md:Tier C caveat / exact fixed-build provenance is not independently established",
	"RESEARCH.md:A3@2009-11-12 comments / bunks were requested or planned at that snapshot",
	"RESEARCH.md:shipyard structure / compact enclosed insertions remain secondary to the open lattice",
	"RESEARCH.md:B2@07:04-07:22 and B4@04:20-04:30 / chairs, consoles, and broad windows with uncertain station-versus-ship context",
]

const CONTENT_NOTE := (
	"Bunks and a chair-lined habitat route are visible in later secondary material, "
	+ "but the recording's exact build provenance and adjacency are not proven. The "
	+ "Habitat Spine name, dimensions, six-alcove plan, observation/common function, "
	+ "furniture arrangement, service systems, doors, and connector are modern design. "
	+ "No part of this module is represented as recovered original geometry. The sealed "
	+ "side branch is explicitly deferred instead of inventing an unsupported room."
)

@onready var _module_anchor: Marker3D = %ModuleAnchor
@onready var _route_approach: Marker3D = %RouteApproach
@onready var _route_threshold: Marker3D = %RouteThreshold
@onready var _route_corridor: Marker3D = %RouteCorridor
@onready var _route_common_entry: Marker3D = %RouteCommonEntry
@onready var _route_observation: Marker3D = %RouteObservation
@onready var _route_deferred_branch: Marker3D = %RouteDeferredBranch
@onready var _main_access: StationDoor = %MainAccess
@onready var _deferred_branch_access: StationDoor = %DeferredBranchAccess

var _materials: Dictionary = {}
var _rounded_box_cache: Dictionary = {}
var _chamfered_cylinder_cache: Dictionary = {}
var _route_markers: Dictionary = {}
var _bunk_markers: Array[Marker3D] = []
var _bunk_nodes: Array[Node3D] = []
var _chair_nodes: Array[Node3D] = []
var _service_nodes: Array[Node3D] = []
var _window_panes: Array[Node3D] = []
var _built := false
var _module_enabled := true


func _ready() -> void:
	if not _built:
		_built = true
		_create_materials()
		_index_semantics()
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


func get_main_access() -> StationDoor:
	return _main_access


func get_deferred_branch_access() -> StationDoor:
	return _deferred_branch_access


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


func get_clearance_profile() -> Dictionary:
	return {
		"floor_elevation": FLOOR_ELEVATION,
		"connector_clear_width": CONNECTOR_CLEAR_WIDTH,
		"door_clear_width": DOOR_CLEAR_WIDTH,
		"corridor_clear_width": CORRIDOR_CLEAR_WIDTH,
		"minimum_head_clearance": MINIMUM_HEAD_CLEARANCE,
		"player_capsule_reference_diameter": 0.76,
		"player_capsule_reference_height": 1.94,
	}


func get_room_ids() -> Array[StringName]:
	var result: Array[StringName] = [
		&"connector",
		&"habitat-corridor",
		&"observation-common",
	]
	result.append_array(get_bunk_room_ids())
	result.sort()
	return result


func get_bunk_room_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for index in BUNK_ALCOVE_COUNT:
		result.append(StringName("bunk-alcove-%02d" % (index + 1)))
	return result


func has_room(room_id: StringName) -> bool:
	return get_room_ids().has(room_id)


func get_room_volume(room_id: StringName) -> Dictionary:
	var local_center := Vector3.ZERO
	var half_extents := Vector3.ZERO
	var room_class: StringName = &"unknown"
	match room_id:
		&"connector":
			local_center = CONNECTOR_CENTER
			half_extents = CONNECTOR_HALF_EXTENTS
			room_class = &"connector"
		&"habitat-corridor":
			local_center = CORRIDOR_CENTER
			half_extents = CORRIDOR_HALF_EXTENTS
			room_class = &"pressurized-corridor"
		&"observation-common":
			local_center = COMMON_CENTER
			half_extents = COMMON_HALF_EXTENTS
			room_class = &"observation-common"
		_:
			var bunk_index := get_bunk_room_ids().find(room_id)
			if bunk_index >= 0:
				local_center = _get_bunk_local_center(bunk_index)
				half_extents = BUNK_ROOM_HALF_EXTENTS
				room_class = &"bunk-alcove"
	if room_class == &"unknown":
		return {}
	return {
		"room_id": room_id,
		"room_class": room_class,
		"local_center": local_center,
		"half_extents": half_extents,
		"world_transform": global_transform * Transform3D(Basis.IDENTITY, local_center),
	}


func get_room_volumes() -> Dictionary:
	var result := {}
	for room_id in get_room_ids():
		result[room_id] = get_room_volume(room_id)
	return result


func contains_room(room_id: StringName, world_position: Vector3) -> bool:
	var volume := get_room_volume(room_id)
	if volume.is_empty():
		return false
	var relative := to_local(world_position) - (volume.local_center as Vector3)
	var half_extents := volume.half_extents as Vector3
	return absf(relative.x) <= half_extents.x \
		and absf(relative.y) <= half_extents.y \
		and absf(relative.z) <= half_extents.z


func get_bunk_count() -> int:
	return _bunk_nodes.size()


func get_bunk_markers() -> Array[Marker3D]:
	return _bunk_markers.duplicate()


func get_chair_count() -> int:
	return _chair_nodes.size()


func get_service_detail_count() -> int:
	return _service_nodes.size()


func get_window_pane_count() -> int:
	return _window_panes.size()


func get_negative_space_samples() -> PackedVector3Array:
	return PackedVector3Array([
		Vector3(-8.1, 1.0, 8.0),
		Vector3(8.1, 1.0, 8.0),
		Vector3(-4.1, 1.0, -2.2),
		Vector3(4.1, 1.0, -2.2),
	])


## The origin is the forward connector plane. The built volume extends toward
## local +Z so it can attach to a narrow station arm without mesh inspection.
func get_integration_footprint() -> Dictionary:
	return {
		"anchor_transform": _module_anchor.global_transform,
		"local_min": FOOTPRINT_MIN,
		"local_max": FOOTPRINT_MAX,
		"local_size": FOOTPRINT_MAX - FOOTPRINT_MIN,
		"approach_axis_local": Vector3.FORWARD,
		"module_extends_local": Vector3.BACK,
		"connector_center_local": Vector3(0.0, 0.0, -1.7),
	}


func get_evidence_metadata() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"module_id": MODULE_ID,
		"evidence_status": EVIDENCE_STATUS,
		"source_bounded": true,
		"authenticated_original_geometry": false,
		"fixed_era_provenance_verified": false,
		"references": PackedStringArray(EVIDENCE_REFERENCES),
		"content_note": CONTENT_NOTE,
		"supported_invariants": PackedStringArray([
			"later secondary material visibly contains bunks and a chair-lined habitat route",
			"compact enclosed rooms can sit within the exposed station lattice",
			"chairs, consoles, and broad windows appear in surviving material, with context caveats",
		]),
		"modern_interpretations": PackedStringArray([
			"Habitat Spine name, dimensions, and exact adjacency",
			"six-alcove arrangement and observation/common room function",
			"service systems, furniture layout, pressure shell, connector, and door mechanics",
			"the existence and location of the sealed deferred branch",
			"the project-original station panel material family mapped across floors, walls, and walking lanes",
		]),
		"explicit_unknowns": PackedStringArray([
			"recording date and exact fixed-build revision",
			"launch-era habitat contents",
			"authoritative floor plan and adjacency",
			"whether every observed chair/window space belongs to the station or a large ship",
		]),
	}


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if _module_anchor == null:
		errors.append("module integration anchor is missing")
	if _main_access == null:
		errors.append("main reusable StationDoor is missing")
	if _deferred_branch_access == null:
		errors.append("deferred branch StationDoor is missing")
	elif not _deferred_branch_access.locked or not _deferred_branch_access.deferred_access:
		errors.append("unsupported side branch must remain locked and explicitly deferred")
	if _route_markers.size() != 6:
		errors.append("connector-to-observation route registry is incomplete")
	if _bunk_markers.size() != BUNK_ALCOVE_COUNT or _bunk_nodes.size() != BUNK_ALCOVE_COUNT:
		errors.append("exactly six independently addressable bunk alcoves are required")
	if _chair_nodes.size() != COMMON_CHAIR_COUNT:
		errors.append("observation/common area must expose exactly eight chairs")
	if _window_panes.size() < 9:
		errors.append("broad physical glazing requires at least nine independently addressable panes")
	if _service_nodes.size() < 8:
		errors.append("maintenance/service layer is too sparse")
	var clearance := get_clearance_profile()
	if float(clearance.connector_clear_width) < 3.0 or float(clearance.corridor_clear_width) < 3.0:
		errors.append("published circulation width is not player-clear")
	if float(clearance.minimum_head_clearance) < 2.4:
		errors.append("published circulation head clearance is below avatar height")
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
		"room_ids": get_room_ids(),
		"room_volumes": get_room_volumes(),
		"clearance": get_clearance_profile(),
		"bunk_count": get_bunk_count(),
		"chair_count": get_chair_count(),
		"window_pane_count": get_window_pane_count(),
		"service_detail_count": get_service_detail_count(),
		"deferred_branch_closed": _deferred_branch_access != null \
			and _deferred_branch_access.locked \
			and _deferred_branch_access.deferred_access,
		"footprint": get_integration_footprint(),
	}


func get_audit_report() -> Dictionary:
	return audit().duplicate(true)


func get_component_roster() -> Dictionary:
	var roster := StationModuleContract.build_component_roster(self)
	roster["schema_version"] = SCHEMA_VERSION
	roster["module_id"] = MODULE_ID
	roster["room_count"] = get_room_ids().size()
	roster["bunk_count"] = get_bunk_count()
	roster["chair_count"] = get_chair_count()
	roster["window_pane_count"] = get_window_pane_count()
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
	# The spine carries the living quarters, so its 663 glazing, bunk, chair, and
	# service primitives need the loosest mesh ceiling of the four; it was
	# previously set to 260, a figure no build ever met.
	#
	# Re-frozen in the open for the habitat rooms pass, measured on the built
	# module rather than estimated:
	#
	#   mesh_instances    740 -> 1100 (built 670 -> 1074, +404)
	#   static_bodies     180 ->  165 (built 125 ->  149, +24)
	#   collision_shapes  220 ->  175 (built 131 ->  155, +24)
	#
	# The mesh delta is where the living quarters went from a fit-out to a place
	# people are in: 6 bunk mouths with jambs, heads, curtains, grab handles and
	# name plates plus the berth dressing behind them (~152), a galley run with a
	# worktop, sink, urn, dispenser, stores and a hanging rail (~72), a mess table
	# with benches and what was left on it (~35), the berth roster board (~28), the
	# window ledge, floor mat and table display content (~46), and the vestibule
	# notice wall (~30). Every one of those is a small object; the module's
	# structural mesh count did not move.
	#
	# The two collision ceilings come *down* even though the built counts went up,
	# because 740/180/220 had never been measured against a build and the two body
	# ceilings had 44% and 68% of unexplained slack in them. Almost none of this
	# pass is collidable: a mug, a name card, a hung coverall and a folded blanket
	# are not things a player can walk into, and giving each one a StaticBody3D
	# would have spent the collision budget on objects nobody can touch. What did
	# get collision is what a player would otherwise walk through — the 12 mouth
	# jambs, the galley carcass, worktop and bin, the mess trestles, table top and
	# two benches, and the four kit bags on the deck.
	var contract := StationModuleContract.build_performance_contract(self, {
		"mesh_instances": 1100,
		"static_bodies": 165,
		"collision_shapes": 175,
		"labels": 25,
		# Light ceiling re-frozen in the open, 12 -> 15 -> 21. The module built 6
		# lights against that 12; the fixture pass took it to 15 — one warm
		# practical inside each of the six bunk alcoves, one cool one over the
		# common-room table display, and a wash behind each of the two room
		# legends. All shadowless and distance-faded.
		#
		# 15 -> 21 is the interior legibility pass and all six are in the
		# observation common room: the single row of three ceiling luminaires
		# becomes two rows of three (+3) in a room 10.6 m deep whose front and rear
		# thirds were outside the lamps' range entirely, and the rear glazing gets
		# a sill cove with three lamps (+3) so the window surround is lit and the
		# panes read as openings rather than as panels. Per-lamp energy comes down
		# with the overhead count (0.76 -> 0.66), so the added lights redistribute
		# this room's luminaires across its actual volume rather than adding gain;
		# see the long note in `_build_observation_common`.
		#
		# The ceiling is set at the exact built count rather than left with
		# headroom. Frame cost is unmeasured: this box renders through llvmpipe.
		#
		# 21 -> 28, and the delta is +7 for the rooms, all of them a fixture that
		# has a housing and a lens drawn at it:
		#   +1 GalleyTaskLight   — the galley worktop, 3.7 m below the ceiling row
		#                          and the only working surface in the habitat.
		#   +1 MessPendantLight  — a pendant on a real 2.04 m drop over the mess
		#                          table, in the room's starboard forward quadrant,
		#                          which both ceiling rows sit on the centreline of
		#                          and reach only with their tails.
		#   +1 RosterBoardLamp   — the berth roster board, same treatment the two
		#                          existing room legends already get.
		#   +1 NoticeBoardLamp   — the vestibule notice wall, likewise.
		#   +3 CabinetStatusWash — one per service cabinet. Found by standing in a
		#                          bunk and looking outboard: the three cabinets sit
		#                          on the port wall 5.5 m off the centreline and the
		#                          corridor pool lights reach 5.4 m from x = 0, so
		#                          the outboard wall of all three port alcoves was
		#                          outside every light in the module. Their emissive
		#                          status lens was lighting nothing, which is the
		#                          exact case the helper below was written for.
		# Still exact, still shadowless, still distance-faded, and all seven are
		# `_fixture_practical` so they carry their own fixture's hue and fall off
		# steeply. None of them raises the room's overall level; each one lights an
		# object that previously had a lit-looking fixture above it casting nothing.
		"lights": 28,
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


func _index_semantics() -> void:
	_route_markers = {
		&"approach": _route_approach,
		&"threshold": _route_threshold,
		&"habitat-corridor": _route_corridor,
		&"common-entry": _route_common_entry,
		&"observation": _route_observation,
		&"deferred-branch": _route_deferred_branch,
	}
	for route_id: StringName in _route_markers.keys():
		var marker := _route_markers[route_id] as Marker3D
		marker.set_meta("station_route_marker", true)
		marker.set_meta("route_id", route_id)
	for index in BUNK_ALCOVE_COUNT:
		var marker := get_node_or_null("BunkAlcoveMarker%02d" % (index + 1)) as Marker3D
		if marker == null:
			continue
		marker.set_meta("station_room_marker", true)
		marker.set_meta("room_id", StringName("bunk-alcove-%02d" % (index + 1)))
		_bunk_markers.append(marker)
	# The outward approach face is the only station connection slot. `threshold`
	# sits inside the pressure door and the sealed deferred branch is a
	# deliberate closed endpoint, so neither may join the adjacency graph.
	_route_approach.set_meta(StationModuleContract.CONNECTION_SLOT_META, HUB_CONNECTION_SLOT)
	_route_corridor.set_meta("station_room_marker", true)
	_route_corridor.set_meta("room_id", &"habitat-corridor")
	_route_observation.set_meta("station_room_marker", true)
	_route_observation.set_meta("room_id", &"observation-common")


func _get_bunk_local_center(index: int) -> Vector3:
	var side := -1.0 if index < 3 else 1.0
	var row := index if index < 3 else index - 3
	return Vector3(side * 4.25, 2.25, 5.1 + float(row) * 5.0)


func _create_materials() -> void:
	_materials["shell_light"] = _material(Color("cbd2d0"), 0.34, 0.32)
	# Floor-role twin of `shell_light`. Both halves carry the same panel maps, so a
	# deck and the wall above it can no longer differ by hue alone; a walked-on
	# coated deck is markedly rougher and less metallic than the pressed shell.
	_materials["shell_light_floor"] = _material(Color("cbd2d0"), 0.24, 0.50)
	_materials["shell_mid"] = _material(Color("8d9999"), 0.44, 0.38)
	# The module's primary structural grey: pressure ribs, service rails, bunk
	# plinths, window mullions and chair pedestals — the parts an occupant stands
	# and sleeps within arm's reach of. Rendered at eye height in the bunk bay it
	# was the loudest remaining defect: metallic 0.58 at roughness 0.34 under
	# clearcoat made every rib and plinth read as wet black plastic beside a
	# plated wall. Joined to the panel family and pulled back to a machined
	# satin response so it reads as painted structural steel.
	_materials["structural"] = _material(Color("35464a"), 0.52, 0.44)
	_materials["graphite"] = _material(Color("172226"), 0.48, 0.46)
	_materials["rubber"] = _material(Color("101719"), 0.04, 0.88)
	# `floor` is used only by the connector inset, the corridor walking lane and
	# the observation-common inset. Those are the surfaces the player actually
	# walks on, so they belong to the station panel family rather than reading as
	# one flat unmapped plane inside a mapped floor.
	_materials["floor"] = _material(Color("667579"), 0.35, 0.48)
	_materials["teal"] = _material(Color("55d8dc"), 0.14, 0.3, Color("2ab8c0"), 1.4)
	_materials["teal_dim"] = _material(Color("326a70"), 0.32, 0.42, Color("258f96"), 0.35)
	_materials["amber"] = _material(Color("e2b45f"), 0.44, 0.31, Color("d98a2c"), 1.1)
	# Non-emissive structural twin of `amber`, matching the Aft module's `brass`.
	# `amber` is a lit cue — signage, reading lights, cabinet status — and it was
	# also carrying the corridor handrails and hatch fasteners, so a 0.07 m rail
	# read as a flat yellow stick between two plated posts.
	_materials["brass"] = _material(Color("e2b45f"), 0.40, 0.44)
	_materials["red"] = _material(Color("d84d47"), 0.2, 0.39, Color("a9252c"), 1.25)
	_materials["copper"] = _material(Color("9b6848"), 0.76, 0.28)
	_materials["fabric"] = _material(Color("2f5960"), 0.03, 0.91)
	# Albedo #21363c -> #2c5158, roughness 0.95 -> 0.86.
	#
	# The interior lighting pass fixed this room's illumination and then recorded
	# that the remaining darkness on the observation chairs' backrests "is now a
	# material choice rather than a lighting hole — if it still reads badly the fix
	# is the albedo, not another lamp." Rendered from inside the room it still read
	# badly, and the render says exactly why: in the same frame, under the same two
	# lamps, a `fabric` seat cushion reads as pale blue-grey while the `fabric_dark`
	# backrest directly above it reads as flat black — not dark, black, with no
	# form in it at all. That is not a tonal step between two upholstery parts of
	# one chair, it is a hole where the chair back should be, and it is the single
	# loudest thing in the habitat's only glazed room.
	#
	# The arithmetic behind it: #21363c is linear (0.014, 0.037, 0.045) against
	# `fabric`'s (0.028, 0.102, 0.127), so the back was reflecting roughly a third
	# of what the seat did while facing away from both overhead rows. #2c5158 is
	# linear (0.025, 0.084, 0.101), about 80% of the seat — dark enough to stay
	# the chair's shadowed member and read as a different piece of trim, bright
	# enough to hold a gradient across its width so the backrest has a shape. The
	# roughness comes with it: 0.95 was a chalk response that killed the last of
	# the specular term on a vertical face, and 0.86 matches the `fabric` family it
	# is supposed to belong to.
	#
	# Not a lighting change: no lamp moved, no energy changed. `fabric_dark` is
	# also the bunk pillows and the chair arm pads, which rendered as the same
	# black slabs, so all three are fixed by the one albedo.
	_materials["fabric_dark"] = _material(Color("2c5158"), 0.02, 0.86)
	# Emission 1.35 -> 1.05. Measured off `habitat_common_room.png`: the common
	# table display rendered as a solid 255 white rectangle on a table that
	# received nothing from it — the single clearest instance of the bimodal frame
	# in the project. Its practical (`TableDisplayGlow`) now carries the table, so
	# the panel itself no longer has to be clipped white to read as on.
	_materials["screen"] = _material(Color("b4efec"), 0.08, 0.24, Color("51cdd2"), 1.05)
	# Emission 2.3 -> 1.7. This lens was the brightest thing in the habitat and it
	# was lighting nothing: at 2.3 it clips past the AgX shoulder, blooms, and the
	# ceiling plate it is recessed into still sat at structure value. The energy
	# taken out here goes into the pool lights below, which is the trade that
	# turns a bloomed strip into a luminaire.
	_materials["warm_light"] = _material(Color("f4ede0"), 0.02, 0.2, Color("ffe6bd"), 1.7)
	_materials["glass"] = _transparent_material(Color(0.33, 0.67, 0.73, 0.2), 0.06, 0.12)
	_create_habitat_life_materials()
	# One call per key into the published kit recipe rather than an inline copy of
	# it, so this module cannot drift from the shared `normal_scale = 1.0` that
	# keeps one relief depth across every module seam.
	for key in [
		"shell_light",
		"shell_light_floor",
		"shell_mid",
		"floor",
		"structural",
		"brass",
		"steel_bright",
	]:
		StationSurfaceKit.apply_panel_triplanar(_materials[key] as StandardMaterial3D, PANEL_SURFACE_SCALE)


## The soft-goods and small-object palette the living quarters need.
##
## Deliberately split from `_create_materials`, and deliberately *not* panel
## mapped except for `steel_bright`. The station panel family is the right
## surface for pressed shell, decks, ribs, carcasses and worktops — it is the
## wrong surface for a blanket, a boot or a paper card, where a plate-and-rivet
## normal map at 0.28 m per repeat would print rivets across a 0.3 m object. This
## is the same split `station_operations_activity.gd` makes when it maps its six
## structural keys and leaves its painted accents and lenses unmapped.
##
## The colours are the other half of the point. Before this pass every surface a
## crew member touched in this module was one of six greys or one of two teals,
## which is why the rooms read as equipment bays rather than as quarters. Linen,
## blanket russet, coverall green, leather, planting green and the rug's warm
## brown are the only saturated non-signal colours in the habitat, and they are
## all on things people own rather than on things the station owns.
func _create_habitat_life_materials() -> void:
	_materials["linen"] = _material(Color("d8cfc0"), 0.02, 0.90)
	_materials["blanket"] = _material(Color("9c5f3e"), 0.02, 0.88)
	_materials["coverall"] = _material(Color("3f6f5c"), 0.03, 0.86)
	_materials["leather"] = _material(Color("4a3a30"), 0.06, 0.72)
	_materials["plastic_pale"] = _material(Color("d3dbd8"), 0.05, 0.52)
	_materials["greenery"] = _material(Color("4f9350"), 0.0, 0.76)
	_materials["paper"] = _material(Color("e4e0d4"), 0.0, 0.92)
	_materials["rug"] = _material(Color("6e4a38"), 0.02, 0.93)
	# #1b2a2e -> #63706e. The first value was chosen as "dark webbing" and rendered
	# inside a bunk as a 1.18 x 0.44 m black rectangle on a lit wall — the same
	# untextured-void failure as the service cabinet inset, at the same eye height,
	# two objects apart. Webbing seen against a plated wall is a light thing with
	# holes in it, not a dark thing.
	_materials["netting"] = _material(Color("63706e"), 0.05, 0.90)
	# Mapped with the rest of the structure: a galley worktop is a 4 m plate at
	# waist height directly under a task light, which is precisely the case the
	# rendered reviews caught twice — a large flat scalar surface close to the eye
	# reads as an untextured primitive no matter how good its metallic response is.
	_materials["steel_bright"] = _material(Color("a8b3b5"), 0.70, 0.26)


func _build_structure() -> void:
	var structure := Node3D.new()
	structure.name = "Structure"
	add_child(structure)
	_build_connector(structure)
	_build_habitat_corridor(structure)
	_build_observation_common(structure)
	_build_service_detail(structure)
	_build_deferred_branch(structure)
	_build_habitat_life(structure)


func _build_connector(structure: Node3D) -> void:
	var connector := Node3D.new()
	connector.name = "PlayerClearConnector"
	connector.set_meta("station_connector", true)
	connector.set_meta("clear_width", CONNECTOR_CLEAR_WIDTH)
	structure.add_child(connector)

	_box(connector, "ConnectorFloor", Vector3(0, -0.25, -1.7), Vector3(5.4, 0.5, 4.8), _materials["shell_light_floor"])
	_box(connector, "ConnectorInset", Vector3(0, 0.018, -1.65), Vector3(4.5, 0.035, 4.25), _materials["floor"], false)
	for side in [-1.0, 1.0]:
		var rail_x := float(side) * 2.63
		_add_rail(connector, Vector3(rail_x, 0, -4.0), Vector3(rail_x, 0, -0.2), "ConnectorRail")
		_beam_between(connector, "ConnectorUnderRail", Vector3(rail_x, -0.55, -4.0), Vector3(rail_x, -0.55, 0.55), 0.11, _materials["structural"], false)
	var connector_rib_positions := PackedFloat32Array([-3.65, -1.7, 0.2])
	for rib_index in connector_rib_positions.size():
		_arch_across_x(
			connector,
			"ConnectorPressureRib%02d" % rib_index,
			connector_rib_positions[rib_index],
			-2.75,
			2.75,
			3.65,
			4.35,
			0.1,
			_materials["shell_mid"]
		)
	for route_z in [-3.15, -1.7, -0.25]:
		_box(connector, "ConnectorRouteLight", Vector3(0, 0.055, float(route_z)), Vector3(0.72, 0.04, 0.12), _materials["teal"], false)

	# The pressure facade is split around the real StationDoor portal.
	_box(connector, "EntryFacadeLeft", Vector3(-4.15, 2.3, 0.72), Vector3(4.1, 4.6, 0.48), _materials["shell_mid"])
	_box(connector, "EntryFacadeRight", Vector3(4.15, 2.3, 0.72), Vector3(4.1, 4.6, 0.48), _materials["shell_mid"])
	_box(connector, "EntryFacadeHeader", Vector3(0, 4.48, 0.72), Vector3(4.2, 0.72, 0.48), _materials["shell_light"])
	_beam_between(connector, "EntryCrownTube", Vector3(-6.15, 4.85, 0.42), Vector3(6.15, 4.85, 0.42), 0.13, _materials["structural"], false)
	# MAP-004 family. The legend sits at z = 0.43, in front of `EntryFacadeRight`
	# (z = 0.48 …) on the approach side of the connector, and was authored with
	# `Vector3.ZERO`, so it read backwards to anyone walking in from the station.
	# `OBSERVATION COMMON` in the same module already yaws 180 for its reader.
	_text_sign(connector, "HABITAT SPINE  //  FIXED-ERA-INSPIRED", Vector3(4.0, 3.85, 0.43), Vector3(0, 180, 0), 0.22, _materials["amber"])
	# Warm wash on the connector legend, matching its amber type. This is the
	# first habitat fixture a player walking in from the station sees, and it is
	# where the module's warmer colour temperature announces itself.
	_fixture_practical(connector, "ConnectorSignWash", Vector3(4.0, 3.6, 0.78), Color("f3c076"), 0.34, 3.0)


func _build_habitat_corridor(structure: Node3D) -> void:
	var habitat := Node3D.new()
	habitat.name = "PressurizedHabitatCorridor"
	habitat.set_meta("station_room", true)
	habitat.set_meta("room_id", &"habitat-corridor")
	habitat.set_meta("clear_width", CORRIDOR_CLEAR_WIDTH)
	structure.add_child(habitat)

	_box(habitat, "HabitatFloor", Vector3(0, -0.25, 10.15), Vector3(12.4, 0.5, 15.7), _materials["shell_light_floor"])
	_box(habitat, "EntryVestibuleFloor", Vector3(0, -0.25, 1.5), Vector3(5.35, 0.5, 1.6), _materials["shell_light_floor"])
	_box(habitat, "HabitatCeiling", Vector3(0, 4.65, 10.15), Vector3(12.4, 0.46, 15.7), _materials["shell_mid"])
	_box(habitat, "CorridorLane", Vector3(0, 0.022, 10.15), Vector3(4.6, 0.04, 15.15), _materials["floor"], false)
	for edge_x in [-2.26, 2.26]:
		_box(habitat, "LaneEdge", Vector3(float(edge_x), 0.052, 10.15), Vector3(0.08, 0.035, 15.0), _materials["teal_dim"], false)
	for seam_z in [3.15, 5.1, 7.1, 8.15, 10.1, 12.1, 13.15, 15.1, 17.1]:
		_box(habitat, "DeckSeam", Vector3(0, 0.055, float(seam_z)), Vector3(4.2, 0.02, 0.045), _materials["graphite"], false)

	# Solid outer pressure walls. Alcoves open inward onto the unobstructed lane.
	for side in [-1.0, 1.0]:
		var wall_x := float(side) * 6.2
		_box(habitat, "OuterPressureWall", Vector3(wall_x, 2.25, 10.15), Vector3(0.48, 4.5, 15.7), _materials["shell_mid"])
		_beam_between(habitat, "OuterServiceRail", Vector3(wall_x - float(side) * 0.32, 4.22, 2.6), Vector3(wall_x - float(side) * 0.32, 4.22, 17.7), 0.09, _materials["structural"], false)
		# Six side-zone partitions create three real alcoves per side while the
		# central corridor remains continuously player-clear.
		for boundary_z in [2.35, 7.3, 7.9, 12.3, 12.9, 17.95]:
			_box(
				habitat,
				"AlcovePartition",
				Vector3(float(side) * 4.25, 2.25, float(boundary_z)),
				Vector3(3.45, 4.5, 0.24),
				_materials["shell_mid"]
			)

	# Repeating curved ribs and luminous cove strips produce a pressure-shell
	# rhythm while keeping collision as simple stable boxes.
	for rib_index in 7:
		var rib_z := 2.65 + float(rib_index) * 2.48
		_arch_across_x(habitat, "HabitatPressureRib%02d" % rib_index, rib_z, -6.35, 6.35, 4.65, 5.55, 0.12, _materials["shell_light"])
		for side in [-1.0, 1.0]:
			_cylinder(habitat, "RibFoot", Vector3(float(side) * 6.37, 2.25, rib_z), 0.14, 4.5, _materials["structural"], false)
	# The cove strips are `warm_light` — an authored #ffe6bd lens — but the pools
	# beneath them were #e5eee9, a cool near-white. The fixture looked like one
	# kind of lamp and cast another, which is a specific "not real" cue: a viewer
	# does not need to name it to feel the room is tinted rather than lit. The
	# pool now carries the lens colour, so the corridor is warm because its own
	# fixtures are warm. This is the habitat's hue separation from the station and
	# it costs no lights: #e5eee9 -> #ffdfb0, energy 0.44 -> 0.6 to cover the
	# emission taken out of the lens.
	for cove_x in [-2.0, 2.0]:
		_beam_between(habitat, "CorridorCoveLight", Vector3(float(cove_x), 4.35, 2.7), Vector3(float(cove_x), 4.35, 17.6), 0.055, _materials["warm_light"], false)
	for light_z in [4.4, 9.9, 15.4]:
		_omni_light(habitat, "CorridorPoolLight", Vector3(0, 3.8, float(light_z)), Color("ffdfb0"), 0.6, 5.4)

	for index in BUNK_ALCOVE_COUNT:
		_build_bunk_alcove(habitat, index, _get_bunk_local_center(index))


func _build_bunk_alcove(parent: Node3D, index: int, center: Vector3) -> void:
	var side := -1.0 if center.x < 0.0 else 1.0
	var bunk := Node3D.new()
	bunk.name = "BunkAlcove%02d" % (index + 1)
	bunk.position = Vector3(center.x, 0, center.z)
	bunk.set_meta("station_bunk_alcove", true)
	bunk.set_meta("room_id", StringName("bunk-alcove-%02d" % (index + 1)))
	bunk.set_meta("evidence_status", EVIDENCE_STATUS)
	parent.add_child(bunk)
	_bunk_nodes.append(bunk)

	var outer_x := float(side) * 1.02
	_box(bunk, "BunkPlinth", Vector3(outer_x, 0.32, 0), Vector3(1.65, 0.64, 2.75), _materials["structural"])
	_box(bunk, "Mattress", Vector3(outer_x - float(side) * 0.04, 0.72, 0), Vector3(1.42, 0.18, 2.45), _materials["fabric"], true)
	_box(bunk, "Pillow", Vector3(outer_x - float(side) * 0.08, 0.88, 0.88), Vector3(1.0, 0.16, 0.52), _materials["fabric_dark"], false, Vector3(0, 0, float(side) * 3.0))
	_box(bunk, "HeadServiceUnit", Vector3(outer_x, 1.42, 1.42), Vector3(1.7, 1.65, 0.22), _materials["shell_light"], true)
	_box(bunk, "ReadingLight", Vector3(outer_x - float(side) * 0.1, 1.85, 1.29), Vector3(0.55, 0.1, 0.06), _materials["amber"], false)
	# Six alcoves, each with an amber reading lamp that lit nothing — six warm
	# stickers on a cool wall. A reading lamp is the most obviously *personal*
	# fixture on the station, and giving each one a genuine 1.7 m pool turns the
	# corridor from a uniformly lit tube into a row of warm pockets with cool
	# structure between them. That rhythm is worth more to the corridor than any
	# further lift of its overall level, and it is a small light: 1.7 m range,
	# steep falloff, faded out well inside the module.
	_fixture_practical(
		bunk,
		"ReadingLightSpill",
		Vector3(outer_x - float(side) * 0.16, 1.7, 1.12),
		Color("ffc98a"),
		0.5,
		1.7
	)
	_box(bunk, "BunkIdentifier", Vector3(-float(side) * 0.7, 1.95, 1.42), Vector3(0.38, 0.16, 0.045), _materials["teal"], false)
	for arch_z in [-1.25, 1.25]:
		_arch_across_x(
			bunk,
			"PrivacyArch",
			float(arch_z),
			-1.55,
			1.55,
			2.55,
			3.0,
			0.06,
			_materials["structural"]
		)
	_box(bunk, "PersonalLocker", Vector3(-float(side) * 1.25, 1.05, -1.25), Vector3(0.72, 2.1, 0.72), _materials["shell_light"], true)
	# `graphite` -> `structural`, same finding and same reason as `CabinetInset`:
	# a 1.72 x 0.48 m panel of #172226 at arm's length inside a bunk reads as a
	# void, not as a recessed door face.
	_box(bunk, "LockerInset", Vector3(-float(side) * 1.25 + float(side) * 0.38, 1.05, -1.25), Vector3(0.035, 1.72, 0.48), _materials["structural"], false)


func _build_observation_common(structure: Node3D) -> void:
	var common := Node3D.new()
	common.name = "ObservationCommon"
	common.set_meta("station_room", true)
	common.set_meta("room_id", &"observation-common")
	common.set_meta("evidence_status", EVIDENCE_STATUS)
	structure.add_child(common)

	_box(common, "CommonFloor", Vector3(0, -0.25, 23.2), Vector3(15.0, 0.5, 10.6), _materials["shell_light_floor"])
	_box(common, "CommonCeiling", Vector3(0, 4.85, 23.2), Vector3(15.0, 0.46, 10.6), _materials["shell_mid"])
	_box(common, "CommonFloorInset", Vector3(0, 0.025, 23.2), Vector3(13.8, 0.045, 9.45), _materials["floor"], false)
	# Front partitions retain the compact spine entrance instead of turning the
	# entire habitat band into one undifferentiated room.
	_box(common, "CommonFrontLeft", Vector3(-5.0, 2.35, 17.92), Vector3(5.0, 4.7, 0.38), _materials["shell_mid"])
	_box(common, "CommonFrontRight", Vector3(5.0, 2.35, 17.92), Vector3(5.0, 4.7, 0.38), _materials["shell_mid"])

	# Broad rear glazing: opaque sill/header and four independent physical panes.
	_box(common, "RearWindowSill", Vector3(0, 0.48, 28.5), Vector3(15.0, 0.96, 0.42), _materials["shell_mid"])
	_box(common, "RearWindowHeader", Vector3(0, 4.43, 28.5), Vector3(15.0, 0.84, 0.42), _materials["shell_mid"])
	for mullion_x in [-7.35, -3.72, 0.0, 3.72, 7.35]:
		_box(common, "RearWindowMullion", Vector3(float(mullion_x), 2.48, 28.5), Vector3(0.22, 3.25, 0.44), _materials["structural"])
	for pane_index in 4:
		var pane_x := -5.55 + float(pane_index) * 3.7
		_register_window(_box(common, "RearWindowPane%02d" % (pane_index + 1), Vector3(pane_x, 2.5, 28.48), Vector3(3.42, 3.18, 0.12), _materials["glass"]))

	# Side glazing continues the exterior sightline. The east-front bay remains
	# solid for the explicitly deferred StationDoor landmark.
	_build_side_window_wall(common, -1.0, [19.7, 23.25, 26.75])
	_build_side_window_wall(common, 1.0, [23.25, 26.75])
	_box(common, "DeferredFacadeHeader", Vector3(7.5, 4.45, 20.0), Vector3(0.42, 0.72, 3.65), _materials["shell_mid"])

	# Six chairs make a calm, readable observation line. Two transverse chairs
	# and a shared table support a common-room use without asserting provenance.
	for chair_index in 6:
		_build_common_chair(common, chair_index, Vector3(-5.0 + float(chair_index) * 2.0, 0, 25.45), 0.0)
	_build_common_chair(common, 6, Vector3(-3.2, 0, 21.45), -88.0)
	_build_common_chair(common, 7, Vector3(3.2, 0, 21.45), 88.0)
	_cylinder(common, "CommonTablePedestal", Vector3(0, 0.62, 21.45), 0.25, 1.24, _materials["structural"], true)
	_cylinder(common, "CommonTableTop", Vector3(0, 1.26, 21.45), 1.42, 0.16, _materials["shell_light"], true)
	_torus(common, "CommonTableEdge", Vector3(0, 1.34, 21.45), 1.25, 1.45, _materials["copper"])
	_box(common, "TableDisplay", Vector3(0, 1.36, 21.45), Vector3(1.25, 0.035, 0.62), _materials["screen"], false)

	var common_rib_positions := PackedFloat32Array([18.25, 20.75, 23.25, 25.75, 28.25])
	for rib_index in common_rib_positions.size():
		_arch_across_x(
			common,
			"CommonPressureRib%02d" % rib_index,
			common_rib_positions[rib_index],
			-7.65,
			7.65,
			4.85,
			5.8,
			0.13,
			_materials["shell_light"]
		)
	# Same correction as the corridor: a warm #ffe6bd lens over a cool #e6f2ec
	# pool. The common room is the module a crew lives in, and warm overheads are
	# both what such a room actually has and the single strongest thing available
	# for breaking the station's monochrome. It also reads from outside — this is
	# the only glazed volume on the station, and warm light through those panes
	# against the cool lattice is what makes the habitat look inhabited in the wide
	# shots. #e6f2ec -> #ffe0b4, energy 0.56 -> 0.76.
	#
	# The regrade follow-up. The hue correction above was right and its warm/cool
	# split is kept exactly as it is — warm overheads with the cool table display
	# as counterpoint is this room's deliberate inversion of the operations room,
	# because a crew lounge is warm and because that is what reads through the
	# station's only glazed wall from outside. What was wrong was reach, and it is
	# the same arithmetic as the operations room: Godot's omni falloff is a
	# windowed inverse power, `(1 - (d/range)^4)^2 * d^(-attenuation)`, and this
	# room is 10.6 m deep and was lit by one row of three lamps at its middle with
	# `omni_range = 5.6`. The rear window sill is 6.2 m from the nearest of them
	# and the front partition 6.2 m from the nearest of them, so both ends of the
	# room lay *outside the lights entirely* — a literal zero, not a dim value —
	# and the chair line at z = 25.45 sat at d/range = 0.70 where the window term
	# has already removed 42%. That is why the chairs went to silhouette when the
	# uniform ambient fill came out: they were never being lit by the room's own
	# fixtures, they were being lit by the fill.
	#
	# Two corrections, neither of them a level raise. The range goes 5.6 -> 9.0,
	# which changes nothing in the near field — at 0.5 m below the lens the window
	# term is 1.00 at either range, so the bright disc on the ceiling plate is
	# untouched — and restores the clipped tail: the deck beneath a lamp goes
	# 0.050 -> 0.078 and the seat of a chair on the observation line goes
	# 0.060 -> 0.118. And the single row of three becomes two rows of three, at
	# z = 20.5 over the shared table and z = 24.3 just in front of the observation
	# line, which are the two places people in this room actually are. Energy comes
	# down 0.76 -> 0.66 with the doubled count.
	#
	# The rear row's z is the single most load-bearing number in this room and it
	# was got wrong once. At z = 25.6 it sat *behind* the observation chairs, whose
	# backrests are at z = 25.07 and lean 6 degrees back. Rendered from the room's
	# doorway — the framing the committed harness uses, and the one the "chairs go
	# to silhouette" complaint was made about — the camera sees the -z face of
	# those backrests, and the surface normal against a lamp behind them gives
	# `n · l = -0.185`. Negative. That face was receiving *nothing*, and no amount
	# of range or energy on a lamp in that position could have changed it, because
	# the geometry was wrong rather than the level. Moved to z = 24.3 the same lamp
	# gives `n · l = +0.402` on the same face. This is the difference between the
	# chairs reading as furniture and reading as cut-outs, and it cost no light and
	# no energy.
	#
	# Neither row is put near the rear glazing: a ceiling lamp within a metre or so
	# of a window lays a sheet of light across the pane and turns the opening back
	# into a panel, which is the defect the sill cove below exists to fix, so the
	# window wall is lit from its own sill instead. The occupants' faces are lit by
	# that sill cove rather than by the ceiling, which is correct for a room whose
	# seating faces the view.
	#
	# Six discrete pools with falloff between them is the opposite of the uniform
	# fill the global pass removed: a fill adds one value to every surface however
	# it faces and wherever it sits, while these put a gradient down the room and
	# let a viewer see where the light comes from. Total lens area is held roughly
	# constant while the count doubles (2.35 x 0.25 -> 1.55 x 0.20, so 1.76 m^2 ->
	# 1.86 m^2) because `warm_light` is shared with the corridor cove strips: its
	# emission cannot be reduced to pay for more lenses here without dimming a
	# corridor that was not the problem, so the lenses are made smaller instead.
	for light_z in [20.5, 24.3]:
		for light_x in [-4.7, 0.0, 4.7]:
			_box(common, "CeilingLightBody", Vector3(float(light_x), 4.58, float(light_z) - 0.2), Vector3(1.95, 0.12, 0.46), _materials["graphite"], false)
			_box(common, "CeilingLightLens", Vector3(float(light_x), 4.5, float(light_z) - 0.2), Vector3(1.55, 0.035, 0.2), _materials["warm_light"], false)
			_omni_light(common, "CommonPoolLight", Vector3(float(light_x), 4.1, float(light_z)), Color("ffe0b4"), 0.66, 9.0)
	# The rear glazing, as a fixture.
	#
	# This room's back wall is four 3.4 m panes onto space and they were reading as
	# flat panels, because nothing distinguished a pane from the plate beside it:
	# the sill, header and mullions in front of them were the least-lit structure
	# in the module, so the frame that should tell a viewer this is an opening had
	# no more light on it than the glass. A window reads as a hole when its
	# surround is lit and the hole is not.
	#
	# So the sill gets a real fixture — a shallow cool cove along its top, the same
	# `teal_dim` strip the corridor uses at floor level — and three lamps that
	# carry the strip's own hue. They are sited 0.65 m inboard of the glass and
	# below its lower edge, so the panes see them at a grazing angle rather than
	# face-on: a lamp closer than that puts a specular sheet across the glass and
	# turns the window into a lit panel, which is precisely the defect being fixed
	# here and the same mistake `TableDisplayGlow` was first tuned into. This is
	# also the room's second colour temperature at working height, arriving from
	# the room's own most prominent feature and opposing the warm ceiling.
	_box(common, "RearSillCoveLens", Vector3(0.0, 0.99, 28.24), Vector3(14.2, 0.045, 0.16), _materials["teal_dim"], false)
	for glazing_x in [-5.2, 0.0, 5.2]:
		_fixture_practical(common, "RearGlazingSpill", Vector3(float(glazing_x), 1.18, 27.85), Color("86d2dc"), 0.3, 4.2)
	# The table display was a lit rectangle lying on an unlit table. Its practical
	# is cool: it is the room's cool counterpoint against the warm overheads, and
	# it puts a gradient on the chair backs and the copper table edge so the
	# seating group reads as a group. Sited 0.8 m above the panel rather than the
	# 0.19 m it was first given — that close, a 0.34 omni made a blown specular
	# hotspot on the deck past the table edge and put the frame's near-blown
	# fraction up 0.43 points, which is the same defect this pass exists to remove.
	# Higher and weaker lights the table and stops there.
	_fixture_practical(common, "TableDisplayGlow", Vector3(0.0, 2.15, 21.45), Color("8fe6ea"), 0.26, 3.0)
	# MAP-004 family, second instance in this module. Yaw 180 -> 0.
	#
	# The connector legend was fixed by yawing it 180 so it faces the approach, and
	# the note left behind said "`OBSERVATION COMMON` in the same module already
	# yaws 180 for its reader." It does yaw 180, but its reader stands on the other
	# side of it, so the same number is the wrong one here.
	#
	# The two numbers that decide it: `TextMesh` renders its readable face toward
	# local +Z, and this legend hangs at z = 18.16 on the room side of
	# `CommonFrontLeft`, whose rear face is z = 18.11. Everyone who can see it is
	# at z > 18.16 looking back toward -z, so the glyph face has to point +z, which
	# is yaw 0. At yaw 180 it pointed -z, into the 0.05 m gap between itself and a
	# solid 5.0 m partition that no player can get behind — the room's own name
	# plate was legible from nowhere in the room. The connector legend keeps its
	# 180 because its reader really does walk in from -z; these are opposite cases
	# that happened to be given the same rotation.
	_text_sign(common, "OBSERVATION COMMON  //  MODERN INTERPRETATION", Vector3(-3.8, 3.95, 18.16), Vector3.ZERO, 0.2, _materials["teal"])
	# Wash behind the room legend, so the bulkhead it hangs on carries the sign's
	# own colour rather than the sign floating on flat plate.
	_fixture_practical(common, "CommonSignWash", Vector3(-3.8, 3.7, 18.5), Color("7fd8dc"), 0.3, 2.6)


func _build_side_window_wall(parent: Node3D, side: float, pane_centers: Array) -> void:
	var wall_x := side * 7.5
	_box(parent, "SideWindowSill", Vector3(wall_x, 0.48, 23.25), Vector3(0.42, 0.96, 10.1), _materials["shell_mid"])
	_box(parent, "SideWindowHeader", Vector3(wall_x, 4.43, 23.25), Vector3(0.42, 0.84, 10.1), _materials["shell_mid"])
	for pane_z_variant in pane_centers:
		var pane_z := float(pane_z_variant)
		_register_window(_box(parent, "SideWindowPane", Vector3(wall_x, 2.5, pane_z), Vector3(0.12, 3.18, 3.08), _materials["glass"]))
		_box(parent, "SideWindowFrameA", Vector3(wall_x, 2.5, pane_z - 1.65), Vector3(0.44, 3.25, 0.18), _materials["structural"])
		_box(parent, "SideWindowFrameB", Vector3(wall_x, 2.5, pane_z + 1.65), Vector3(0.44, 3.25, 0.18), _materials["structural"])


func _register_window(pane: Node3D) -> void:
	pane.set_meta("station_glazing", true)
	pane.set_meta("physical_pressure_barrier", true)
	_window_panes.append(pane)


func _build_common_chair(parent: Node3D, index: int, chair_position: Vector3, yaw: float) -> void:
	var chair := Node3D.new()
	chair.name = "CommonChair%02d" % (index + 1)
	chair.position = chair_position
	chair.rotation_degrees.y = yaw
	chair.set_meta("station_chair", true)
	chair.set_meta("chair_index", index)
	chair.set_meta("evidence_status", EVIDENCE_STATUS)
	parent.add_child(chair)
	_chair_nodes.append(chair)
	_cylinder(chair, "Pedestal", Vector3(0, 0.42, 0), 0.16, 0.84, _materials["structural"], true)
	_cylinder(chair, "Foot", Vector3(0, 0.08, 0), 0.46, 0.14, _materials["graphite"], true)
	_torus(chair, "Bearing", Vector3(0, 0.72, 0), 0.16, 0.24, _materials["copper"])
	_box(chair, "Seat", Vector3(0, 0.84, 0), Vector3(0.94, 0.2, 0.9), _materials["fabric"], true)
	_box(chair, "Back", Vector3(0, 1.43, -0.38), Vector3(0.92, 1.28, 0.2), _materials["fabric_dark"], true, Vector3(-6, 0, 0))
	for side in [-1.0, 1.0]:
		var arm_x := float(side) * 0.54
		_beam_between(chair, "ArmSupport", Vector3(arm_x, 0.83, -0.05), Vector3(arm_x, 1.17, -0.05), 0.045, _materials["structural"], false)
		_box(chair, "ArmPad", Vector3(arm_x, 1.2, 0), Vector3(0.14, 0.1, 0.58), _materials["fabric_dark"], false)


func _build_service_detail(structure: Node3D) -> void:
	var service := Node3D.new()
	service.name = "MaintenanceServiceLayer"
	service.set_meta("station_service_layer", true)
	service.set_meta("evidence_status", EVIDENCE_STATUS)
	structure.add_child(service)

	# A high-mounted service run keeps every route clear while adding the pipes,
	# cabinets, valves, and maintenance access expected of a modernised facility.
	for side in [-1.0, 1.0]:
		var pipe_x := float(side) * 5.75
		var main_pipe := _beam_between(service, "EnvironmentalMain", Vector3(pipe_x, 3.6, 2.8), Vector3(pipe_x, 3.6, 17.45), 0.12, _materials["copper"], false)
		_register_service(main_pipe, &"environmental-main")
		for valve_z in [4.6, 9.9, 15.2]:
			var collar := _torus(service, "PipeCollar", Vector3(pipe_x, 3.6, float(valve_z)), 0.12, 0.19, _materials["graphite"], Vector3(90, 0, 0))
			_register_service(collar, &"pipe-collar")
			var valve := _torus(service, "IsolationValve", Vector3(pipe_x - float(side) * 0.18, 3.25, float(valve_z)), 0.15, 0.23, _materials["red"], Vector3(0, 90, 0))
			_register_service(valve, &"isolation-valve")
	for cabinet_index in 3:
		var cabinet_z := 4.35 + float(cabinet_index) * 5.05
		var cabinet := _box(service, "ServiceCabinet%02d" % (cabinet_index + 1), Vector3(-5.78, 2.05, cabinet_z), Vector3(0.48, 2.25, 1.35), _materials["shell_light"], false)
		_register_service(cabinet, &"service-cabinet")
		# `graphite` -> `structural`, plus a door seam, three louvres and a handle.
		#
		# Found by standing in a bunk alcove and looking at the wall. These three
		# cabinets are on the port outer wall *inside* alcoves 1, 2 and 3, and at
		# 1.76 x 0.98 m of #172226 the inset was not reading as a recessed door, it
		# was reading as a hole punched in the wall of somebody's bedroom — the
		# largest black shape in the habitat and the first thing the eye went to
		# from the bunk. `structural` is the module's painted-steel grey and it
		# carries the panel family, so the recess now reads as a door set back in
		# its frame, which is what it always was.
		_box(service, "CabinetInset", Vector3(-5.52, 2.05, cabinet_z), Vector3(0.035, 1.76, 0.98), _materials["structural"], false)
		_box(service, "CabinetDoorSeam", Vector3(-5.5, 2.05, cabinet_z), Vector3(0.025, 1.72, 0.03), _materials["graphite"], false)
		for louvre_index in 3:
			_box(service, "CabinetLouvre", Vector3(-5.5, 1.42 + float(louvre_index) * 0.16, cabinet_z), Vector3(0.03, 0.05, 0.62), _materials["graphite"], false)
		_box(service, "CabinetHandle", Vector3(-5.48, 2.05, cabinet_z + 0.34), Vector3(0.05, 0.30, 0.05), _materials["brass"], false)
		var status_lit := cabinet_index != 1
		_box(service, "CabinetStatus", Vector3(-5.5, 2.55, cabinet_z), Vector3(0.03, 0.16, 0.55), _materials["teal"] if status_lit else _materials["amber"], false)
		# The status lens was emissive and lit nothing, which is the case this
		# module's own `_fixture_practical` note exists for. These three cabinets
		# stand on the port outer wall 5.5 m off the centreline, and the corridor's
		# pool lights have a 5.4 m range from x = 0, so the entire outboard wall of
		# the three port alcoves was outside every light in the module — a literal
		# zero. That is why the inset read black whatever albedo it was given.
		_fixture_practical(
			service,
			"CabinetStatusWash",
			Vector3(-5.18, 2.35, cabinet_z),
			Color("7fd8dc") if status_lit else Color("f3c076"),
			0.26,
			2.4
		)
	for hatch_z in [5.1, 10.15, 15.2]:
		var hatch := _box(service, "FloorServiceHatch", Vector3(0, 0.058, float(hatch_z)), Vector3(1.35, 0.025, 0.92), _materials["graphite"], false)
		_register_service(hatch, &"service-hatch")
		for fastener_x in [-0.52, 0.52]:
			for fastener_z in [-0.31, 0.31]:
				_cylinder(service, "HatchFastener", Vector3(float(fastener_x), 0.08, float(hatch_z) + float(fastener_z)), 0.03, 0.025, _materials["brass"], false)


func _register_service(node: Node3D, service_class: StringName) -> void:
	node.set_meta("station_service_detail", true)
	node.set_meta("service_class", service_class)
	_service_nodes.append(node)


func _build_deferred_branch(structure: Node3D) -> void:
	var branch := Node3D.new()
	branch.name = "DeferredBranchLandmark"
	branch.set_meta("station_deferred_branch", true)
	branch.set_meta("content_status", &"closed_no_interior")
	structure.add_child(branch)
	# A shallow physical backstop makes the absence of unsupported content true
	# in geometry, not just in a label. No floor or room exists beyond it.
	_box(branch, "DeferredBackstop", Vector3(7.78, 2.3, 20.0), Vector3(0.32, 3.55, 3.35), _materials["graphite"])
	_beam_between(branch, "DeferredCrown", Vector3(7.72, 4.45, 18.2), Vector3(7.72, 4.45, 21.8), 0.12, _materials["red"], false)
	_text_sign(branch, "BRANCH DEFERRED  //  NO AUTHENTICATED INTERIOR", Vector3(7.2, 3.75, 22.0), Vector3(0, -90, 0), 0.18, _materials["red"])


## Everything in the habitat that belongs to a person rather than to the station.
##
## This module was the thinnest part of a station that has a crew workpost with a
## nodding weld jig, a dispatch board with one lit tile per registered berth, and
## dock arms whose assigned-versus-deferred state is carried by where the boom is
## stowed. Rendered at eye height, the habitat had six bunk alcoves that were a
## plinth, a slab and a black panel; a 13.8 x 9.45 m common room furnished with
## eight identical chairs in a row, one table, and nothing else on 130 m^2 of
## deck; and a corridor whose whole content was floor markings. It read as a
## fit-out that had been delivered but not moved into.
##
## Three groups, one per room, built after the shell so they can measure it:
## the alcove mouths and their berth dressing, the common room's galley, mess and
## berth roster, and the vestibule's notice wall. Split into their own builders
## rather than grown into the shell functions so the structure of the module and
## the life in it stay separately readable and separately deletable.
func _build_habitat_life(structure: Node3D) -> void:
	var corridor := structure.get_node_or_null("PressurizedHabitatCorridor") as Node3D
	var common := structure.get_node_or_null("ObservationCommon") as Node3D
	if corridor == null or common == null:
		return
	for index in _bunk_nodes.size():
		_build_bunk_berth_life(_bunk_nodes[index], index)
	_build_entry_vestibule_life(corridor)
	_build_common_galley(common)
	_build_common_mess(common)
	_build_common_berth_roster(common)
	_build_common_soft_goods(common)


## One bunk alcove, dressed as somebody's berth.
##
## Two problems, and the first one is architectural. An alcove opens onto the
## lane across its whole 4.16 m width, so from the corridor a bunk was a hole in
## a wall with furniture at the back of it, and the corridor was a row of holes.
## Real quarters have a doorway. The jambs below bring the visual aperture to
## 2.0 m, which is what gives the mouth a head, two cheeks, somewhere to hang a
## curtain, somewhere to bolt a grab handle, and somewhere to put the berth's
## name — none of which had any surface to attach to before.
##
## Seating. The jambs stand on the deck at y = 0 and are sized in z from
## `BUNK_MOUTH_AFT_FACE` / `BUNK_MOUTH_FORWARD_FACE` so each buries 0.04 m into
## the alcove partition beside it. The head spans between the two jambs and sits
## inside them. The curtain rail's ends bury 0.03 m into the jambs, the curtain
## hangs from the rail, the shelf reaches the outer wall's 5.96 m inner face, its
## brackets bury into both the wall and the shelf, the coverall's rail is carried
## on two wall brackets and the coverall's shoulders reach the rail. The blanket's
## underside is the mattress top at 0.81 exactly; boots and kit bag stand on the
## deck.
##
## The jambs are at local x = -side * 1.60 with a 0.30 m section, so their
## innermost face is 2.65 m off the module centreline and the published 4.6 m
## corridor clear width is untouched. Nothing in here enters the lane.
func _build_bunk_berth_life(bunk: Node3D, index: int) -> void:
	var side := 1.0 if index >= 3 else -1.0
	# Inboard, i.e. toward the lane. The alcoves face each other across it, so
	# every offset below is signed off this rather than off `side`.
	var inboard := -side
	var outer_x := side * 1.02
	var wall_x := side * 1.71
	var row := index % 3
	var aft_face := float(BUNK_MOUTH_AFT_FACE[row])
	var forward_face := float(BUNK_MOUTH_FORWARD_FACE[row])
	var occupied := bool(BUNK_BERTH_OCCUPANCY[index])

	var berth := Node3D.new()
	berth.name = "BerthLife"
	berth.set_meta("station_bunk_dressing", true)
	berth.set_meta("berth_occupied", occupied)
	berth.set_meta("evidence_status", EVIDENCE_STATUS)
	bunk.add_child(berth)

	# --- mouth surround -------------------------------------------------------
	var jamb_x := inboard * 1.60
	var aft_jamb_end := aft_face - 0.04
	var forward_jamb_end := forward_face + 0.04
	_box(
		berth,
		"MouthJambAft",
		Vector3(jamb_x, 2.25, (aft_jamb_end - 1.0) * 0.5),
		Vector3(0.30, 4.5, absf(-1.0 - aft_jamb_end)),
		_materials["shell_mid"]
	)
	_box(
		berth,
		"MouthJambForward",
		Vector3(jamb_x, 2.25, (forward_jamb_end + 1.0) * 0.5),
		Vector3(0.30, 4.5, absf(forward_jamb_end - 1.0)),
		_materials["shell_mid"]
	)
	_box(
		berth,
		"MouthHead",
		Vector3(jamb_x, 2.62, (aft_face + forward_face) * 0.5),
		Vector3(0.30, 0.64, forward_face - aft_face + 0.08),
		_materials["shell_light"],
		false
	)
	_box(berth, "MouthHeadLip", Vector3(inboard * 1.76, 2.30, (aft_face + forward_face) * 0.5), Vector3(0.05, 0.09, forward_face - aft_face), _materials["brass"], false)

	# --- curtain --------------------------------------------------------------
	var curtain_x := inboard * 1.50
	_beam_between(berth, "CurtainRail", Vector3(curtain_x, 2.22, -1.03), Vector3(curtain_x, 2.22, 1.03), 0.035, _materials["brass"], false)
	# `linen`, and 0.62 m rather than the 1.00 m this was first built at. Rendered
	# from the lane, a 1.00 m `fabric` panel was the largest single surface in the
	# alcove and the darkest thing in the corridor: it filled most of the aperture
	# the jambs had just been added to create, and it turned six berths back into
	# six dark rectangles. Warm off-white at 0.62 m does the opposite of both — it
	# is the brightest thing at eye height in a blue-grey corridor, and the berth
	# behind it stays visible, which is the point of dressing it.
	if occupied:
		_box(berth, "BerthCurtain", Vector3(curtain_x, 1.21, 0.69), Vector3(0.07, 2.02, 0.62), _materials["linen"], false)
		_cylinder(berth, "CurtainLeadEdge", Vector3(curtain_x, 1.21, 0.40), 0.05, 2.02, _materials["linen"], false)
	else:
		_box(berth, "BerthCurtain", Vector3(curtain_x, 1.21, 0.86), Vector3(0.22, 2.02, 0.30), _materials["linen"], false)

	# --- mouth furniture ------------------------------------------------------
	var face_x := inboard * 1.75
	_beam_between(berth, "MouthGrabHandle", Vector3(inboard * 1.80, 0.80, 1.35), Vector3(inboard * 1.80, 1.70, 1.35), 0.028, _materials["brass"], false)
	for stud_y in [0.86, 1.64]:
		_beam_between(berth, "GrabHandleStud", Vector3(face_x, float(stud_y), 1.35), Vector3(inboard * 1.80, float(stud_y), 1.35), 0.022, _materials["brass"], false)
	_box(berth, "BerthPlateBacking", Vector3(inboard * 1.768, 1.98, 1.35), Vector3(0.045, 0.30, 0.50), _materials["graphite"], false)
	_box(
		berth,
		"BerthPlateTile",
		Vector3(inboard * 1.788, 2.06, 1.35),
		Vector3(0.02, 0.11, 0.42),
		_materials["teal"] if occupied else _materials["teal_dim"],
		false
	)
	if occupied:
		_box(berth, "BerthNameCard", Vector3(inboard * 1.792, 1.90, 1.35), Vector3(0.014, 0.13, 0.40), _materials["paper"], false)

	# --- shelf over the bunk --------------------------------------------------
	# 0.60 m deep rather than the 0.72 the alcove would take, so the shelf stays
	# under the 0.65 m minor-axis threshold the walkable-surface discovery sweep
	# uses to find broad flat upward faces. A 1.3 m high shelf inside a bunk is
	# not a floor and should not be presented to that sweep as a candidate.
	_box(berth, "BerthShelf", Vector3(side * 1.41, 1.30, 0.10), Vector3(0.60, 0.055, 1.55), _materials["shell_light"], false)
	for bracket_z in [-0.55, 0.55]:
		_beam_between(berth, "BerthShelfBracket", Vector3(side * 1.68, 1.04, float(bracket_z)), Vector3(side * 1.16, 1.27, float(bracket_z)), 0.025, _materials["structural"], false)
	if occupied:
		_cylinder(berth, "BerthMug", Vector3(side * 1.35, 1.380, 0.55), 0.045, 0.105, _materials["plastic_pale"], false)
		_box(berth, "BerthReader", Vector3(side * 1.32, 1.339, 0.10), Vector3(0.30, 0.022, 0.21), _materials["graphite"], false)
		_box(berth, "BerthReaderScreen", Vector3(side * 1.32, 1.3512, 0.10), Vector3(0.25, 0.006, 0.17), _materials["teal_dim"], false)
		_box(berth, "BerthPhoto", Vector3(side * 1.52, 1.406, -0.36), Vector3(0.016, 0.157, 0.118), _materials["paper"], false, Vector3(0, 0, 0))
		_box(berth, "BerthPhotoFrame", Vector3(side * 1.535, 1.406, -0.36), Vector3(0.014, 0.175, 0.136), _materials["brass"], false)
	else:
		_box(berth, "BerthEmptyTray", Vector3(side * 1.38, 1.3555, 0.10), Vector3(0.44, 0.056, 0.30), _materials["plastic_pale"], false)

	# --- stowage net ----------------------------------------------------------
	for net_rail_y in [1.60, 2.06]:
		_beam_between(berth, "BerthNetRail", Vector3(side * 1.64, float(net_rail_y), -0.60), Vector3(side * 1.64, float(net_rail_y), 0.60), 0.022, _materials["structural"], false)
	# The panel is what reaches the 1.71 wall face, and the two rails sit inside
	# its span. At the 0.11 m width this was first given, the rails cleared the
	# wall by 0.028 m and the whole assembly hung on nothing.
	_box(berth, "BerthStowageNet", Vector3(side * 1.635, 1.83, 0.0), Vector3(0.15, 0.44, 1.18), _materials["netting"], false)
	# Cross straps, so the panel reads as webbing rather than as a filled board.
	for strap_z in [-0.42, 0.0, 0.42]:
		_beam_between(berth, "BerthNetStrap", Vector3(side * 1.555, 1.60, float(strap_z)), Vector3(side * 1.555, 2.06, float(strap_z)), 0.018, _materials["structural"], false)
	if occupied:
		_box(berth, "BerthNetBundle", Vector3(side * 1.62, 1.80, 0.30), Vector3(0.13, 0.28, 0.34), _materials["linen"], false)
		_box(berth, "BerthNetBundleB", Vector3(side * 1.63, 1.74, -0.24), Vector3(0.11, 0.22, 0.30), _materials["coverall"], false)

	# --- bedding --------------------------------------------------------------
	if occupied:
		# Underside 0.810, which is the `Mattress` top exactly (0.72 + 0.18/2).
		_box(berth, "BerthBlanket", Vector3(outer_x - side * 0.04, 0.880, -0.62), Vector3(1.36, 0.14, 1.15), _materials["blanket"], false)
		_box(berth, "BerthBlanketFold", Vector3(outer_x - side * 0.04, 0.955, -0.06), Vector3(1.32, 0.11, 0.30), _materials["blanket"], false)
	else:
		_box(berth, "BerthFoldedLinen", Vector3(outer_x, 0.875, 0.10), Vector3(0.78, 0.13, 0.52), _materials["linen"], false)
		_box(berth, "BerthFoldedLinenB", Vector3(outer_x, 0.985, 0.10), Vector3(0.70, 0.09, 0.46), _materials["linen"], false)

	# --- coverall hook --------------------------------------------------------
	var hook_rail_z := -1.20
	for bracket_z in [-1.50, -0.90]:
		_beam_between(berth, "CoverallBracket", Vector3(wall_x, 2.10, float(bracket_z)), Vector3(side * 1.62, 2.10, float(bracket_z)), 0.024, _materials["structural"], false)
	_beam_between(berth, "CoverallRail", Vector3(side * 1.62, 2.10, -1.55), Vector3(side * 1.62, 2.10, -0.85), 0.026, _materials["brass"], false)
	if occupied:
		_beam_between(berth, "CoverallHanger", Vector3(side * 1.62, 2.09, hook_rail_z - 0.22), Vector3(side * 1.62, 2.09, hook_rail_z + 0.22), 0.018, _materials["brass"], false)
		# Shoulders at 2.095 against a rail whose underside is 2.074, so the
		# garment hangs off the rail instead of hovering under it.
		_box(berth, "BerthCoverall", Vector3(side * 1.55, 1.57, hook_rail_z), Vector3(0.20, 1.05, 0.46), _materials["coverall"], false)
	else:
		for hook_z in [-1.42, -0.98]:
			_beam_between(berth, "BareHook", Vector3(side * 1.62, 2.10, float(hook_z)), Vector3(side * 1.62, 1.92, float(hook_z)), 0.016, _materials["brass"], false)

	# --- personal locker state ------------------------------------------------
	# A roller shutter rather than a swinging door. A hinged 0.70 m leaf on the
	# lane-facing face of this locker sweeps to x = 1.96 local at 30 degrees,
	# which is 2.29 m off the centreline — right on the published lane edge — so
	# the open state would have been built out of a fault. A shutter stows
	# upward into the head of the locker and takes no floor at all.
	var locker_x := inboard * 1.25
	if occupied:
		_box(berth, "LockerShutter", Vector3(inboard * 1.635, 1.02, -1.25), Vector3(0.05, 1.86, 0.66), _materials["shell_light"], false)
		_box(berth, "LockerShutterPull", Vector3(inboard * 1.668, 1.10, -1.05), Vector3(0.05, 0.09, 0.22), _materials["brass"], false)
		_box(berth, "LockerNameCard", Vector3(inboard * 1.655, 1.72, -1.25), Vector3(0.014, 0.11, 0.34), _materials["paper"], false)
	else:
		_box(berth, "LockerShutter", Vector3(inboard * 1.635, 1.86, -1.25), Vector3(0.05, 0.20, 0.66), _materials["shell_light"], false)
		_box(berth, "LockerVoid", Vector3(inboard * 1.585, 0.96, -1.25), Vector3(0.04, 1.66, 0.60), _materials["graphite"], false)
		for shelf_y in [0.72, 1.35]:
			_box(berth, "LockerShelf", Vector3(locker_x, float(shelf_y), -1.25), Vector3(0.60, 0.035, 0.60), _materials["shell_light"], false)

	# --- deck ------------------------------------------------------------------
	if occupied:
		for boot_z in [-0.16, 0.16]:
			_box(berth, "BerthBoot", Vector3(inboard * 0.42, 0.0775, float(boot_z)), Vector3(0.14, 0.155, 0.32), _materials["leather"], false, Vector3(0, inboard * 7.0, 0))
		_box(berth, "BerthKitBag", Vector3(inboard * 0.62, 0.23, -1.05), Vector3(0.44, 0.46, 0.88), _materials["leather"])
		_beam_between(berth, "BerthKitStrap", Vector3(inboard * 0.62, 0.47, -1.42), Vector3(inboard * 0.62, 0.47, -0.68), 0.026, _materials["coverall"], false)
	else:
		for crate_index in 2:
			_box(
				berth,
				"BerthStowedCrate",
				Vector3(inboard * 0.52, 0.135 + float(crate_index) * 0.27, -1.10),
				Vector3(0.46, 0.27, 0.62),
				_materials["shell_mid"],
				false
			)


## The vestibule inside the pressure door, treated as the place people arrive.
##
## Kept small on purpose, and the reason is worth recording because it looks like
## an omission: this corridor has almost no wall. The six alcoves occupy the
## entire length of both sides between z = 2.35 and z = 17.95, so the only
## surfaces a player in the lane can see are the deck, the ceiling, the alcove
## mouths and the 0.24 m partition end faces — and the mouths are where this
## pass put its work. The 1.6 m vestibule between the door and the first
## partition is the one stretch of real corridor wall in the module, and the
## entry facade at z = 0.96 is what the notice wall bolts to.
func _build_entry_vestibule_life(corridor: Node3D) -> void:
	var vestibule := Node3D.new()
	vestibule.name = "EntryVestibuleLife"
	vestibule.set_meta("station_room_dressing", true)
	vestibule.set_meta("evidence_status", EVIDENCE_STATUS)
	corridor.add_child(vestibule)

	# Bolted to the inner face of `EntryFacadeLeft`, which ends at z = 0.96; the
	# board's back face is 0.955 so it shares volume with the facade plate.
	_box(vestibule, "NoticeBoardFrame", Vector3(-2.46, 1.86, 1.015), Vector3(0.62, 1.24, 0.11), _materials["brass"], false)
	_box(vestibule, "NoticeBoardFace", Vector3(-2.46, 1.86, 1.055), Vector3(0.55, 1.14, 0.05), _materials["graphite"], false)
	var notice_layout := [
		[0.16, 2.24, 0.20, 0.26],
		[-0.14, 2.20, 0.24, 0.30],
		[0.13, 1.84, 0.26, 0.22],
		[-0.16, 1.78, 0.22, 0.28],
		[0.02, 1.42, 0.30, 0.20],
	]
	for card_index in notice_layout.size():
		var card: Array = notice_layout[card_index]
		_box(
			vestibule,
			"NoticeCard%02d" % (card_index + 1),
			Vector3(-2.46 + float(card[0]), float(card[1]), 1.083),
			Vector3(float(card[2]), float(card[3]), 0.014),
			_materials["paper"],
			false,
			Vector3(0, 0, float(card_index - 2) * 2.5)
		)
	_fixture_practical(vestibule, "NoticeBoardLamp", Vector3(-2.46, 2.62, 1.30), Color("f3c076"), 0.30, 2.6)
	# Housing z 1.10 -> 1.00 with a 0.24 m section, so its back face is 0.88 and it
	# shares volume with the entry facade it is bolted to. At 1.10 it cleared the
	# facade by 0.03 m and sat 0.075 m above the board, carried by neither.
	_box(vestibule, "NoticeBoardLampHousing", Vector3(-2.46, 2.60, 1.00), Vector3(0.44, 0.09, 0.24), _materials["graphite"], false)
	_box(vestibule, "NoticeBoardLampLens", Vector3(-2.46, 2.545, 1.10), Vector3(0.34, 0.03, 0.15), _materials["warm_light"], false)

	# The arrival shelf on the opposite facade: caps, gloves and a clipped manifest
	# where a crew coming off shift would drop them.
	_box(vestibule, "ArrivalShelf", Vector3(2.46, 1.06, 1.16), Vector3(0.60, 0.055, 0.40), _materials["shell_light"], false)
	for bracket_x in [2.26, 2.66]:
		_beam_between(vestibule, "ArrivalShelfBracket", Vector3(float(bracket_x), 0.82, 0.99), Vector3(float(bracket_x), 1.04, 1.30), 0.022, _materials["structural"], false)
	_box(vestibule, "ArrivalCap", Vector3(2.36, 1.135, 1.16), Vector3(0.22, 0.10, 0.26), _materials["coverall"], false)
	_box(vestibule, "ArrivalGloves", Vector3(2.60, 1.122, 1.16), Vector3(0.19, 0.075, 0.24), _materials["leather"], false)
	# z 1.00 -> 0.98: at 1.00 the rail's 0.024 m radius stopped 0.016 m short of the
	# facade face at 0.96 and the coat rail floated off the wall.
	_beam_between(vestibule, "ArrivalHookRail", Vector3(2.16, 1.72, 0.98), Vector3(2.76, 1.72, 0.98), 0.024, _materials["brass"], false)
	for hook_x in [2.28, 2.64]:
		_beam_between(vestibule, "ArrivalHook", Vector3(float(hook_x), 1.72, 0.98), Vector3(float(hook_x), 1.56, 1.06), 0.016, _materials["brass"], false)
	_box(vestibule, "ArrivalJacket", Vector3(2.28, 1.22, 1.10), Vector3(0.19, 0.72, 0.42), _materials["coverall"], false)


## The common room's galley, along the port wall of its forward half.
##
## The room had 130 m^2 of deck and one round table on it, and the rendered
## framings put an entirely empty 4 m wall and an entirely empty quadrant in the
## middle of the frame. A galley is the right thing there because it is what a
## crew room is actually organised around, and because the port wall's window
## sill is 0.96 m high — a worktop at 0.92 backs straight onto it, so the run
## needs no wall of its own and the crew working at it are silhouetted against
## the glazing.
##
## Seating: the carcass stands on the deck at y = 0 and butts the 18.11 m rear
## face of `CommonFrontLeft`; the worktop's underside is the carcass top at 0.86;
## everything on the run has its underside at the worktop's 0.92; the hanging rail
## is carried on two posts standing on that worktop and the pans reach up to it.
## The carcass back is at x = -7.28 against the sill's -7.29 inner face.
func _build_common_galley(common: Node3D) -> void:
	var galley := Node3D.new()
	galley.name = "CommonGalley"
	galley.set_meta("station_room_dressing", true)
	galley.set_meta("evidence_status", EVIDENCE_STATUS)
	common.add_child(galley)

	var run_center_z := 20.255
	var run_length := 4.29
	_box(galley, "GalleyCarcass", Vector3(-6.94, 0.43, run_center_z), Vector3(0.68, 0.86, run_length), _materials["shell_mid"])
	_box(galley, "GalleyToeRecess", Vector3(-6.66, 0.06, run_center_z), Vector3(0.12, 0.12, run_length), _materials["graphite"], false)
	_box(galley, "GalleyWorktop", Vector3(-6.92, 0.89, run_center_z), Vector3(0.74, 0.06, run_length + 0.04), _materials["steel_bright"])
	_box(galley, "GalleySplashback", Vector3(-7.255, 1.09, run_center_z), Vector3(0.06, 0.34, run_length + 0.04), _materials["steel_bright"], false)
	for door_index in 4:
		var door_z := 18.62 + float(door_index) * 1.06
		_box(galley, "GalleyDoor%02d" % (door_index + 1), Vector3(-6.582, 0.47, door_z), Vector3(0.045, 0.70, 0.96), _materials["shell_light"], false)
		_box(galley, "GalleyDoorPull", Vector3(-6.556, 0.72, door_z), Vector3(0.045, 0.045, 0.34), _materials["brass"], false)

	# Sink, drawn as an inset rim on the worktop rather than a hole through it, so
	# the collidable top stays one unbroken box.
	_box(galley, "GalleySinkRim", Vector3(-6.94, 0.945, 19.30), Vector3(0.56, 0.05, 0.64), _materials["steel_bright"], false)
	_box(galley, "GalleySinkWell", Vector3(-6.94, 0.938, 19.30), Vector3(0.47, 0.036, 0.55), _materials["graphite"], false)
	_beam_between(galley, "GalleyTapRiser", Vector3(-7.20, 0.92, 19.30), Vector3(-7.20, 1.32, 19.30), 0.028, _materials["steel_bright"], false)
	_beam_between(galley, "GalleyTapSpout", Vector3(-7.20, 1.30, 19.30), Vector3(-6.99, 1.23, 19.30), 0.024, _materials["steel_bright"], false)
	_beam_between(galley, "GalleyTapLever", Vector3(-7.22, 1.34, 19.30), Vector3(-7.22, 1.34, 19.13), 0.02, _materials["brass"], false)

	# Hot water urn.
	_cylinder(galley, "GalleyUrnBody", Vector3(-6.90, 1.21, 20.94), 0.17, 0.58, _materials["steel_bright"], false)
	_cylinder(galley, "GalleyUrnCap", Vector3(-6.90, 1.525, 20.94), 0.13, 0.07, _materials["graphite"], false)
	_beam_between(galley, "GalleyUrnTap", Vector3(-6.74, 1.06, 20.94), Vector3(-6.62, 1.02, 20.94), 0.022, _materials["brass"], false)
	_box(galley, "GalleyUrnStatus", Vector3(-6.74, 1.32, 20.94), Vector3(0.03, 0.07, 0.16), _materials["amber"], false)

	# Beverage dispenser.
	_box(galley, "GalleyDispenser", Vector3(-6.96, 1.23, 21.74), Vector3(0.46, 0.62, 0.54), _materials["graphite"], false)
	for tap_z in [21.60, 21.88]:
		_beam_between(galley, "GalleyDispenserTap", Vector3(-6.74, 1.10, float(tap_z)), Vector3(-6.66, 1.02, float(tap_z)), 0.02, _materials["brass"], false)
		_box(galley, "GalleyDispenserLens", Vector3(-6.735, 1.40, float(tap_z)), Vector3(0.03, 0.10, 0.16), _materials["teal"], false)

	# Mugs, trays and stores.
	for stack_index in 2:
		var stack_z := 21.16 + float(stack_index) * 0.19
		for mug_index in 3:
			_cylinder(galley, "GalleyMug", Vector3(-6.76, 0.972 + float(mug_index) * 0.104, stack_z), 0.05, 0.104, _materials["plastic_pale"], false)
	_box(galley, "GalleyTray", Vector3(-6.86, 0.9425, 18.55), Vector3(0.44, 0.045, 0.62), _materials["plastic_pale"], false)
	_box(galley, "GalleyBoard", Vector3(-6.88, 0.9425, 22.05), Vector3(0.40, 0.045, 0.56), _materials["blanket"], false)
	for carton_index in 3:
		_box(
			galley,
			"GalleyRationCarton%02d" % (carton_index + 1),
			Vector3(-6.94 + float(carton_index % 2) * 0.16, 1.02, 18.34 + float(carton_index) * 0.31),
			Vector3(0.26, 0.20, 0.28),
			_materials["copper"] if carton_index == 1 else _materials["plastic_pale"],
			false
		)

	# Hanging rail on two posts standing on the worktop.
	for post_z in [18.92, 21.92]:
		_cylinder(galley, "GalleyRailPost", Vector3(-7.20, 1.23, float(post_z)), 0.026, 0.62, _materials["structural"], false)
	_beam_between(galley, "GalleyHangRail", Vector3(-7.20, 1.53, 18.92), Vector3(-7.20, 1.53, 21.92), 0.022, _materials["brass"], false)
	for pan_index in 3:
		var pan_z := 19.45 + float(pan_index) * 0.62
		_beam_between(galley, "GalleyPanHook", Vector3(-7.20, 1.53, pan_z), Vector3(-7.13, 1.44, pan_z), 0.014, _materials["brass"], false)
		# y 1.30 -> 1.34: the smallest pan is 0.115 m in radius, so at 1.30 its rim
		# topped out 0.011 m below the hook it was supposed to be hanging from.
		_cylinder(galley, "GalleyPan", Vector3(-7.13, 1.34, pan_z), 0.115 + float(pan_index) * 0.018, 0.13, _materials["steel_bright"], false, Vector3(90, 0, 0))

	# Task light. The worktop is the one working surface in the habitat and it sits
	# 3.7 m below the ceiling row, so it gets its own fixture rather than being lit
	# from across the room; the housing hangs off the rail posts, not off nothing.
	_box(galley, "GalleyTaskHousing", Vector3(-7.19, 1.58, 20.42), Vector3(0.13, 0.10, 2.95), _materials["graphite"], false)
	_box(galley, "GalleyTaskLens", Vector3(-7.15, 1.545, 20.42), Vector3(0.09, 0.03, 2.60), _materials["warm_light"], false)
	_fixture_practical(galley, "GalleyTaskLight", Vector3(-6.92, 1.46, 20.42), Color("ffd9a4"), 0.40, 3.4)

	_box(galley, "GalleyBin", Vector3(-6.26, 0.34, 22.86), Vector3(0.44, 0.68, 0.44), _materials["graphite"])
	_box(galley, "GalleyBinLid", Vector3(-6.26, 0.70, 22.86), Vector3(0.46, 0.04, 0.46), _materials["structural"], false)
	_beam_between(galley, "GalleyBinPedal", Vector3(-6.46, 0.09, 22.86), Vector3(-6.06, 0.09, 22.86), 0.022, _materials["brass"], false)


## The mess table, in the starboard half of the room's forward quadrant.
##
## Placed at z = 23.3 rather than further forward because the starboard wall from
## z = 18.33 to 21.67 is the deferred branch bay, and nothing in this pass gets
## to crowd a deliberately closed landmark. Everything here stands on the deck:
## two trestles at y = 0 carrying a top whose underside is their 0.72 head, two
## benches on their own four legs, and the objects left on the table with their
## undersides on its 0.79 surface.
func _build_common_mess(common: Node3D) -> void:
	var mess := Node3D.new()
	mess.name = "CommonMess"
	mess.set_meta("station_room_dressing", true)
	mess.set_meta("evidence_status", EVIDENCE_STATUS)
	common.add_child(mess)

	var table_x := 5.55
	var table_z := 23.30
	for trestle_z in [22.45, 24.15]:
		_box(mess, "MessTrestle", Vector3(table_x, 0.36, float(trestle_z)), Vector3(0.74, 0.72, 0.13), _materials["structural"])
		_box(mess, "MessTrestleFoot", Vector3(table_x, 0.035, float(trestle_z)), Vector3(0.92, 0.07, 0.20), _materials["graphite"], false)
	_beam_between(mess, "MessTrestleTie", Vector3(table_x, 0.58, 22.45), Vector3(table_x, 0.58, 24.15), 0.042, _materials["structural"], false)
	_box(mess, "MessTableTop", Vector3(table_x, 0.755, table_z), Vector3(1.12, 0.07, 2.32), _materials["shell_light"])
	_box(mess, "MessTableEdge", Vector3(table_x, 0.755, table_z), Vector3(1.18, 0.045, 2.38), _materials["copper"], false)

	for bench_side in [-1.0, 1.0]:
		var bench_x := table_x + float(bench_side) * 0.83
		_box(mess, "MessBench", Vector3(bench_x, 0.435, table_z), Vector3(0.44, 0.09, 2.12), _materials["shell_light"])
		for leg_z in [22.52, 24.08]:
			_box(mess, "MessBenchLeg", Vector3(bench_x, 0.195, float(leg_z)), Vector3(0.38, 0.39, 0.10), _materials["structural"], false)

	# Left on the table.
	_box(mess, "MessTray", Vector3(table_x - 0.10, 0.812, 22.76), Vector3(0.46, 0.045, 0.62), _materials["plastic_pale"], false)
	_cylinder(mess, "MessBowl", Vector3(table_x - 0.18, 0.879, 22.76), 0.13, 0.09, _materials["plastic_pale"], false)
	for mug_offset in [Vector2(-0.19, 0.26), Vector2(0.08, 0.44), Vector2(0.24, 0.12)]:
		_cylinder(mess, "MessMug", Vector3(table_x + mug_offset.x, 0.8425, table_z + mug_offset.y), 0.048, 0.105, _materials["plastic_pale"], false)
	_cylinder(mess, "MessThermos", Vector3(table_x + 0.30, 0.930, 22.92), 0.062, 0.28, _materials["steel_bright"], false)
	_box(mess, "MessCloth", Vector3(table_x - 0.25, 0.8075, 24.05), Vector3(0.30, 0.035, 0.24), _materials["linen"], false)
	_box(mess, "MessCardDeck", Vector3(table_x + 0.17, 0.800, 24.12), Vector3(0.10, 0.025, 0.14), _materials["paper"], false, Vector3(0, 14, 0))

	# Left around it.
	_box(mess, "MessJacket", Vector3(table_x - 0.83, 0.60, 22.52), Vector3(0.26, 0.44, 0.36), _materials["coverall"], false)
	for boot_z in [23.02, 23.36]:
		_box(mess, "MessBoot", Vector3(table_x + 0.83, 0.0775, float(boot_z)), Vector3(0.14, 0.155, 0.32), _materials["leather"], false, Vector3(0, -9, 0))

	# A pendant over the table, hung on a real drop from the 4.62 m ceiling
	# underside. The room's ceiling rows are at z = 20.5 and 24.3 and both are on
	# the centreline, so this corner was lit only by their tails.
	# Drop ends at 2.40, inside the shade, not at 2.58 where it stopped 0.01 m above
	# it. Top end is the 4.62 m ceiling underside.
	_beam_between(mess, "MessPendantDrop", Vector3(table_x, 4.62, table_z), Vector3(table_x, 2.40, table_z), 0.026, _materials["structural"], false)
	_cylinder(mess, "MessPendantShade", Vector3(table_x, 2.44, table_z), 0.34, 0.26, _materials["copper"], false)
	_box(mess, "MessPendantLens", Vector3(table_x, 2.32, table_z), Vector3(0.44, 0.03, 0.44), _materials["warm_light"], false)
	_fixture_practical(mess, "MessPendantLight", Vector3(table_x, 2.20, table_z), Color("ffd2a0"), 0.42, 3.8)


## The berth roster board, on the rear face of `CommonFrontRight`.
##
## The same idea as the registry's dispatch board — one tile per registered
## thing, driven off the same list the real thing is built from — applied to the
## only registry this module has, which is who is in which bunk. The tile count
## is `BUNK_ALCOVE_COUNT` and the state is `BUNK_BERTH_OCCUPANCY`, so a board that
## disagrees with the corridor is a code change rather than silent drift.
##
## State is hardware first: a taken berth's tile stands proud of the board with a
## name card slotted into it and a coverall on the peg below; a free berth's tile
## is recessed into the board with the slot empty and the peg bare. The lit/unlit
## lens is the confirmation, not the message.
func _build_common_berth_roster(common: Node3D) -> void:
	var roster := Node3D.new()
	roster.name = "CrewBerthRoster"
	roster.set_meta("station_room_dressing", true)
	roster.set_meta("evidence_status", EVIDENCE_STATUS)
	common.add_child(roster)

	var board_x := 5.10
	_box(roster, "RosterBoardFrame", Vector3(board_x, 1.98, 18.145), Vector3(2.78, 1.46, 0.08), _materials["brass"], false)
	_box(roster, "RosterBoardFace", Vector3(board_x, 1.98, 18.190), Vector3(2.62, 1.32, 0.05), _materials["graphite"], false)
	for tile_index in BUNK_ALCOVE_COUNT:
		var occupied := bool(BUNK_BERTH_OCCUPANCY[tile_index])
		var tile_x := board_x + (float(tile_index) - 2.5) * 0.42
		_box(
			roster,
			"RosterTile%02d" % (tile_index + 1),
			Vector3(tile_x, 2.20, 18.222 if occupied else 18.186),
			Vector3(0.34, 0.24, 0.040 if occupied else 0.030),
			_materials["teal"] if occupied else _materials["graphite"],
			false
		)
		if occupied:
			_box(roster, "RosterNameCard%02d" % (tile_index + 1), Vector3(tile_x, 1.90, 18.226), Vector3(0.30, 0.20, 0.016), _materials["paper"], false)
		else:
			_box(roster, "RosterEmptySlot%02d" % (tile_index + 1), Vector3(tile_x, 1.90, 18.186), Vector3(0.30, 0.20, 0.028), _materials["graphite"], false)
	_beam_between(roster, "RosterPegRail", Vector3(board_x - 1.24, 1.50, 18.20), Vector3(board_x + 1.24, 1.50, 18.20), 0.024, _materials["brass"], false)
	for peg_index in BUNK_ALCOVE_COUNT:
		var peg_x := board_x + (float(peg_index) - 2.5) * 0.42
		_beam_between(roster, "RosterPeg", Vector3(peg_x, 1.50, 18.20), Vector3(peg_x, 1.44, 18.34), 0.016, _materials["brass"], false)
	_box(roster, "RosterHungCoverall", Vector3(board_x - 1.05, 1.02, 18.34), Vector3(0.44, 0.86, 0.18), _materials["coverall"], false)
	_box(roster, "RosterHungCap", Vector3(board_x + 0.21, 1.40, 18.34), Vector3(0.24, 0.11, 0.26), _materials["coverall"], false)
	# Reader stands in the room at z > 18.2 looking back toward -z, so the glyph
	# face has to point +z: yaw 0, the same correction made to the room legend.
	_text_sign(roster, "BERTH ROSTER", Vector3(board_x, 2.56, 18.212), Vector3.ZERO, 0.15, _materials["amber"])
	_fixture_practical(roster, "RosterBoardLamp", Vector3(board_x, 2.74, 18.66), Color("f3c076"), 0.30, 2.8)
	# Housing z 18.42 -> 18.22, so it overlaps the 18.11 m partition face it is
	# bolted to. At 18.42 it shared volume with nothing at all: 0.24 m clear of the
	# wall and 0.04 m above the top of the board.
	_box(roster, "RosterLampHousing", Vector3(board_x, 2.80, 18.22), Vector3(1.30, 0.10, 0.26), _materials["graphite"], false)
	_box(roster, "RosterLampLens", Vector3(board_x, 2.74, 18.26), Vector3(1.05, 0.03, 0.17), _materials["warm_light"], false)


## The last of it: what the room's seating group and its glazing wall carry.
##
## The mat is the only large warm surface in the module and it exists because the
## deck is 13.8 x 9.45 m of the same plate as every other deck on the station,
## and because a seating group with nothing under it reads as chairs parked on a
## floor rather than as a place to sit. It lies on the collidable `CommonFloor`,
## so the walkable-surface sweep finds World collision 0.06 m under it.
##
## The window ledge items are on the 0.96 m top of `RearWindowSill`. That ledge
## is the one horizontal surface in the habitat with the view behind it, and it
## was bare.
func _build_common_soft_goods(common: Node3D) -> void:
	var goods := Node3D.new()
	goods.name = "CommonSoftGoods"
	goods.set_meta("station_room_dressing", true)
	goods.set_meta("evidence_status", EVIDENCE_STATUS)
	common.add_child(goods)

	_box(goods, "CommonFloorMat", Vector3(0.0, 0.058, 22.60), Vector3(4.60, 0.026, 4.20), _materials["rug"], false)
	_box(goods, "CommonFloorMatBorder", Vector3(0.0, 0.054, 22.60), Vector3(4.90, 0.020, 4.50), _materials["copper"], false)

	# The table display was a lit white rectangle with nothing drawn on it. Three
	# panels and a border cost four meshes and stop it reading as a blown highlight
	# lying on a table.
	_box(goods, "TableDisplayBezel", Vector3(0.0, 1.352, 21.45), Vector3(1.36, 0.030, 0.72), _materials["structural"], false)
	for panel_index in 2:
		_box(
			goods,
			"TableDisplayPanel%02d" % (panel_index + 1),
			Vector3(-0.42 + float(panel_index) * 0.84, 1.3775, 21.45),
			Vector3(0.34, 0.007, 0.44),
			_materials["teal_dim"],
			false
		)
	_box(goods, "TableDisplayCursor", Vector3(0.0, 1.3775, 21.32), Vector3(0.52, 0.007, 0.06), _materials["teal"], false)

	# Window ledge. Underside 0.96, which is the sill top exactly.
	for planter_x in [-6.20, 6.20]:
		_box(goods, "LedgePlanter", Vector3(float(planter_x), 1.07, 28.48), Vector3(0.46, 0.22, 0.38), _materials["copper"], false)
		_box(goods, "LedgePlanterSoil", Vector3(float(planter_x), 1.165, 28.48), Vector3(0.40, 0.04, 0.32), _materials["graphite"], false)
		for frond_index in 5:
			var frond_lean := (float(frond_index) - 2.0) * 11.0
			_box(
				goods,
				"LedgeFrond",
				Vector3(
					float(planter_x) + (float(frond_index) - 2.0) * 0.075,
					1.30 + absf(float(frond_index) - 2.0) * -0.035,
					28.48 + (float(frond_index) - 2.0) * 0.045
				),
				Vector3(0.055, 0.34, 0.13),
				_materials["greenery"],
				false,
				Vector3(frond_lean * 0.5, float(frond_index) * 31.0, frond_lean)
			)
	for mug_z in [28.44, 28.54]:
		_cylinder(goods, "LedgeMug", Vector3(-3.95 + (float(mug_z) - 28.44) * 3.0, 1.0125, float(mug_z)), 0.048, 0.105, _materials["plastic_pale"], false)
	_box(goods, "LedgeReader", Vector3(2.60, 0.9725, 28.48), Vector3(0.32, 0.025, 0.24), _materials["graphite"], false)
	_box(goods, "LedgeReaderScreen", Vector3(2.60, 0.987, 28.48), Vector3(0.27, 0.006, 0.19), _materials["teal_dim"], false)
	# Centre 1.015, not 1.028: laid on its side this cylinder is 0.11 m tall, so at
	# 1.028 its underside was 0.013 m above the 0.96 m sill top.
	_cylinder(goods, "LedgeScopeBody", Vector3(0.95, 1.015, 28.48), 0.055, 0.136, _materials["steel_bright"], false, Vector3(90, 0, 0))
	_cylinder(goods, "LedgeScopeEye", Vector3(0.95, 1.015, 28.56), 0.035, 0.06, _materials["graphite"], false, Vector3(90, 0, 0))

	# A blanket left over the end of the observation line, which is the cheapest
	# possible statement that people sit here.
	_box(goods, "ObservationThrow", Vector3(5.0, 1.14, 25.20), Vector3(0.86, 0.62, 0.30), _materials["blanket"], false, Vector3(-6, 0, 0))


func _style_access_landmarks() -> void:
	if _main_access != null:
		_apply_door_material(_main_access, _materials["teal"], _materials["teal"])
	if _deferred_branch_access != null:
		_apply_door_material(_deferred_branch_access, _materials["red"], _materials["red"])


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
	set_meta("authenticated_original_geometry", false)
	set_meta("fixed_era_provenance_verified", false)
	set_meta("content_note", CONTENT_NOTE)
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
	result.clearcoat = 0.2
	result.clearcoat_roughness = 0.42
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
## module, adopting the kit rule would move 13 of 45 distinct sizes by up
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
	var mesh := StationSurfaceKit.chamfered_cylinder_mesh_cached(
		radius, radius, height, 32, _chamfered_cylinder_cache
	)
	if collidable:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "Mesh"
		mesh_instance.mesh = mesh
		mesh_instance.material_override = material
		container.add_child(mesh_instance)
		var collision := CollisionShape3D.new()
		collision.name = "Collision"
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		collision.shape = shape
		container.add_child(collision)
	else:
		var mesh_instance := container as MeshInstance3D
		mesh_instance.mesh = mesh
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


func _add_rail(parent: Node3D, from: Vector3, to: Vector3, rail_name: String) -> void:
	for endpoint in [from, to]:
		_cylinder(parent, rail_name + "Post", endpoint + Vector3.UP * 0.68, 0.055, 1.36, _materials["shell_mid"], true)
	_beam_between(parent, rail_name, from + Vector3.UP * 1.34, to + Vector3.UP * 1.34, 0.07, _materials["brass"], true)


func _omni_light(
		parent: Node3D,
		node_name: String,
		light_position: Vector3,
		color: Color,
		energy: float,
		range_value: float
	) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = node_name
	light.position = light_position
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range_value
	light.omni_attenuation = 1.45
	light.shadow_enabled = false
	light.distance_fade_enabled = true
	light.distance_fade_begin = 28.0
	light.distance_fade_length = 12.0
	light.set_meta("localized_practical_light", true)
	parent.add_child(light)
	return light


## A luminaire's spill, as an actual light. See the long note on the identical
## helper in `aft_junction_stack.gd`: `emission` is a local surface term and glow
## is a screen-space convolution of the finished image, so no amount of emission
## makes a fixture light the plate it is bolted to. Only a Light3D does. These
## are small, shadowless and steeply attenuated, and each carries its own
## fixture's hue so the spill identifies the source. The fade distance is
## measured — at the 16 m/8 m it was first given, every one of these was off in
## every framing except the two room interiors and the pass measured as a net
## loss on structural sigma.
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


func _text_sign(
		parent: Node3D,
		text_value: String,
		text_position: Vector3,
		text_rotation_degrees: Vector3,
		scale_value: float,
		material: Material
	) -> MeshInstance3D:
	var mesh := TextMesh.new()
	mesh.text = text_value
	mesh.font_size = 64
	mesh.pixel_size = 0.012
	mesh.depth = 0.02
	mesh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mesh.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var instance := MeshInstance3D.new()
	instance.name = "Sign_%s" % text_value.replace(" ", "_").replace("/", "")
	instance.position = text_position
	instance.rotation_degrees = text_rotation_degrees
	instance.scale = Vector3.ONE * scale_value
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)
	return instance
