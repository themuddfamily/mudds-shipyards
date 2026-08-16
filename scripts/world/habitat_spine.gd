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

const FLOOR_ELEVATION := 0.0
const CONNECTOR_CLEAR_WIDTH := 4.45
const DOOR_CLEAR_WIDTH := 3.1
const CORRIDOR_CLEAR_WIDTH := 4.6
const MINIMUM_HEAD_CLEARANCE := 4.0
const BUNK_ALCOVE_COUNT := 6
const COMMON_CHAIR_COUNT := 8

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
	var contract := StationModuleContract.build_performance_contract(self, {
		"mesh_instances": 740,
		"static_bodies": 180,
		"collision_shapes": 220,
		"labels": 25,
		# Light ceiling re-frozen in the open, 12 -> 15. The module built 6 lights
		# against that 12 and now builds 15: one warm practical inside each of the
		# six bunk alcoves, one cool one over the common-room table display, and a
		# wash behind each of the two room legends. All shadowless, sub-3 m range
		# except the table's 2.4 m, and distance-faded out at 16 m. The ceiling is
		# set at the exact built count rather than left with headroom. Frame cost
		# is unmeasured: this box renders through llvmpipe.
		"lights": 15,
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
	_materials["fabric_dark"] = _material(Color("21363c"), 0.02, 0.95)
	_materials["screen"] = _material(Color("b4efec"), 0.08, 0.24, Color("51cdd2"), 1.35)
	# Emission 2.3 -> 1.7. This lens was the brightest thing in the habitat and it
	# was lighting nothing: at 2.3 it clips past the AgX shoulder, blooms, and the
	# ceiling plate it is recessed into still sat at structure value. The energy
	# taken out here goes into the pool lights below, which is the trade that
	# turns a bloomed strip into a luminaire.
	_materials["warm_light"] = _material(Color("f4ede0"), 0.02, 0.2, Color("ffe6bd"), 1.7)
	_materials["glass"] = _transparent_material(Color(0.33, 0.67, 0.73, 0.2), 0.06, 0.12)
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
	]:
		StationSurfaceKit.apply_panel_triplanar(_materials[key] as StandardMaterial3D, PANEL_SURFACE_SCALE)


func _build_structure() -> void:
	var structure := Node3D.new()
	structure.name = "Structure"
	add_child(structure)
	_build_connector(structure)
	_build_habitat_corridor(structure)
	_build_observation_common(structure)
	_build_service_detail(structure)
	_build_deferred_branch(structure)


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
	_box(bunk, "LockerInset", Vector3(-float(side) * 1.25 + float(side) * 0.38, 1.05, -1.25), Vector3(0.035, 1.72, 0.48), _materials["graphite"], false)


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
	for light_x in [-4.7, 0.0, 4.7]:
		_box(common, "CeilingLightBody", Vector3(float(light_x), 4.58, 23.0), Vector3(2.8, 0.12, 0.52), _materials["graphite"], false)
		_box(common, "CeilingLightLens", Vector3(float(light_x), 4.5, 23.0), Vector3(2.35, 0.035, 0.25), _materials["warm_light"], false)
		_omni_light(common, "CommonPoolLight", Vector3(float(light_x), 4.1, 23.2), Color("ffe0b4"), 0.76, 5.6)
	# The table display was a lit rectangle lying on an unlit table. Its practical
	# is cool and short-ranged: it is the room's cool counterpoint against the warm
	# overheads, and it puts an upward gradient on the chair backs and the copper
	# table edge so the seating group reads as a group.
	_fixture_practical(common, "TableDisplayGlow", Vector3(0.0, 1.55, 21.45), Color("8fe6ea"), 0.34, 2.4)
	_text_sign(common, "OBSERVATION COMMON  //  MODERN INTERPRETATION", Vector3(-3.8, 3.95, 18.16), Vector3(0, 180, 0), 0.2, _materials["teal"])
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
		_box(service, "CabinetInset", Vector3(-5.52, 2.05, cabinet_z), Vector3(0.035, 1.76, 0.98), _materials["graphite"], false)
		_box(service, "CabinetStatus", Vector3(-5.5, 2.55, cabinet_z), Vector3(0.03, 0.16, 0.55), _materials["teal"] if cabinet_index != 1 else _materials["amber"], false)
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
## are small, shadowless, steeply attenuated and faded out at 16 m, and each
## carries its own fixture's hue so the spill identifies the source.
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
	light.distance_fade_begin = 16.0
	light.distance_fade_length = 8.0
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
