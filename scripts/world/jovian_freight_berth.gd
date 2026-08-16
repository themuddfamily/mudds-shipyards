class_name JovianFreightBerth
extends Node3D

## A physically traversable, large-craft freight berth for the provisional
## Jovian-class Light Freighter interpretation.
##
## Creator-authored material supports the exact ship-class name and its light-
## freighter role. It does not authenticate a model, berth, room, cargo system,
## dimensions, or adjacency. This component exposes that boundary through both
## dictionary-compatible evidence metadata and a typed audit snapshot.

const SCHEMA_VERSION := 1
const MODULE_ID: StringName = &"jovian-freight-berth"
## Declared station connection slot. `ShipyardWorld` publishes the matching hub
## endpoint; the pair is what `StationRouteRegistry` records as one graph edge.
const HUB_CONNECTION_SLOT: StringName = &"hub-registry-pod-freight"
const BERTH_ID: StringName = &"jovian_freight_berth"
const SHIP_CLASS_ID: StringName = &"jovian_provisional"
const SHIP_CLASS_NAME := "Jovian-class Light Freighter"
const EVIDENCE_STATUS: StringName = &"creator_roster_supported_modern_interpretation"
const WORLD_LAYER := PhysicsLayers.WORLD

## Physical size of one station panel plate in this module, in metres of world
## space per texture repeat. Frozen. Walked-on deck and room floors use the
## tighter plate so foot-scale surfaces keep a readable tread size.
const PANEL_SURFACE_SCALE := 0.30
const WALKED_PANEL_SURFACE_SCALE := 0.22

const DECK_ELEVATION := 0.0
const CONNECTION_CLEAR_WIDTH := 5.8
const SERVICE_DOOR_CLEAR_WIDTH := 3.1
const MINIMUM_HEAD_CLEARANCE := 4.1
const CARGO_UNIT_TARGET := 8
const SERVICE_DETAIL_TARGET := 12
const RECOMMENDED_WORLD_TRANSFORM := Transform3D(Basis.IDENTITY, Vector3(-53.0, 0.38, 28.8))

# Full authored-module declaration. The root is the connection plane and local
# +Z points away from the station. An integrator can place this box without
# reverse-engineering generated meshes.
const FOOTPRINT_MIN := Vector3(-23.0, -3.4, -4.8)
const FOOTPRINT_MAX := Vector3(23.0, 14.2, 51.5)

# The flight hull is expected to fit about 17.0 x 7.1 x 27.5 m. Its deployed
# port ramp broadens the parked presentation to about 19.2 m. These generous
# protected bounds keep all structural collision outside the parked craft.
const SHIP_ROOT_LOCAL := Vector3(0.0, 1.25, 28.5)
const SHIP_ENVELOPE_CENTER_FROM_ROOT := Vector3(0.0, 3.5, 0.0)
const SHIP_ENVELOPE_HALF_EXTENTS := Vector3(11.5, 5.0, 17.5)
const SHIP_DECLARED_FLIGHT_SIZE := Vector3(17.0, 7.1, 27.5)
const SHIP_DECLARED_DEPLOYED_SIZE := Vector3(19.2, 7.1, 27.5)

const CRANE_TROLLEY_TRAVEL := 7.2
const CRANE_TROLLEY_ELEVATION := 12.5
const CRANE_HOOK_MIN_ELEVATION := 10.75
const CRANE_HOOK_MAX_ELEVATION := 11.25
const CRANE_HOOK_VISUAL_LOW_OFFSET := -0.66
const CRANE_CENTER_Z := 27.0

const EVIDENCE_REFERENCES := [
	"RESEARCH.md:A3@2009-11-12 / creator-authored roster names the Jovian-class Light Freighter",
	"RESEARCH.md:best creator-authored original roster / exact name and light-freighter role",
	"RESEARCH.md:B4 label roster / a regeneration message repeats the class name with no registered frame anchor and no tied craft",
	"RESEARCH.md:shipyard structure / physically parked fleet on separated exposed lattice nodes",
	"RESEARCH.md:implementation evidence map / pale angular fleet language is fleet-wide guidance only",
]

const CONTENT_NOTE := (
	"The exact Jovian-class Light Freighter name, its light-freighter role, and "
	+ "membership in the creator's dated ten-ship roster are supported by A3's "
	+ "page text. The later B4 regeneration message repeats the name but does not "
	+ "identify a model: the ledger registers no frame anchor for that label and "
	+ "ties no visible craft to it, so the Jovian name-to-model mapping is "
	+ "unknown. No source authenticates Jovian "
	+ "geometry, colours, scale, capacity, interior, cargo ramp, controls, berth, or "
	+ "equipment. This module's apron, exposed lattice, dimensions, cargo handling, "
	+ "service room, door, crane, signage, lighting, and station adjacency are all "
	+ "explicitly provisional modern interpretation."
)

@onready var _module_anchor: Marker3D = %ModuleAnchor
@onready var _berth_dock_marker: Marker3D = %BerthDockMarker
@onready var _service_access: StationDoor = %ServiceAccess
@onready var _route_approach: Marker3D = %RouteApproach
@onready var _route_apron_threshold: Marker3D = %RouteApronThreshold
@onready var _route_boarding_staging: Marker3D = %RouteBoardingStaging
@onready var _route_cargo_transfer: Marker3D = %RouteCargoTransfer
@onready var _route_service_threshold: Marker3D = %RouteServiceThreshold
@onready var _route_service_room: Marker3D = %RouteServiceRoom
@onready var _route_cargo_rack: Marker3D = %RouteCargoRack

var _materials: Dictionary = {}
var _rounded_box_cache: Dictionary = {}
var _chamfered_cylinder_cache: Dictionary = {}
var _route_markers: Dictionary = {}
var _cargo_units: Array[Node3D] = []
var _service_details: Array[Node3D] = []
var _animated_equipment: Array[Node3D] = []
var _crane_trolley: Node3D
var _crane_hook: Node3D
var _equipment_elapsed := 0.0
var _equipment_animation_enabled := true
var _module_enabled := true
var _built := false


func _ready() -> void:
	if not _built:
		_built = true
		_create_materials()
		_index_semantics()
		_build_connection_lattice()
		_build_loading_apron()
		_build_service_room()
		_build_cargo_infrastructure()
		_build_crane()
		_build_lighting_and_signage()
		_style_service_access()
		_apply_metadata()
		_update_equipment_transforms()
	# Reconcile the real node state against `_module_enabled` on every ready, so a
	# scene-authored or externally drifted layer/visibility cannot survive.
	_apply_enabled_state()


func _process(delta: float) -> void:
	if _equipment_animation_enabled:
		advance_equipment_simulation(delta)


func get_module_id() -> StringName:
	return MODULE_ID


func get_ship_class_id() -> StringName:
	return SHIP_CLASS_ID


func get_ship_class_name() -> String:
	return SHIP_CLASS_NAME


func get_module_anchor() -> Marker3D:
	return _module_anchor


## Collision-audited starting point for the current exposed station revision.
## Integration remains a world-level decision, so this does not self-place.
func get_recommended_world_transform() -> Transform3D:
	return RECOMMENDED_WORLD_TRANSFORM


func get_berth_id() -> StringName:
	return BERTH_ID


func get_berth_marker() -> Marker3D:
	return _berth_dock_marker


func get_berth_transform() -> Transform3D:
	return _berth_dock_marker.global_transform if _berth_dock_marker != null else global_transform * Transform3D(Basis(Vector3.UP, PI), SHIP_ROOT_LOCAL)


## Declarative contract used by ShipyardWorld to create its required direct
## ShipBerth child. The module intentionally owns no nested lease authority.
func get_berth_specification() -> Dictionary:
	return {
		"schema_version": ShipBerth.SCHEMA_VERSION,
		"berth_id": BERTH_ID,
		"dock_transform": get_berth_transform(),
		"landing_half_extents": Vector3(14.0, 8.0, 21.5),
		"compatibility_tags": PackedStringArray([
			"medium_craft",
			"freighter",
			"cargo",
			"walkable_interior",
			"light_freighter",
			"freight",
		]),
		"required_world_parent": &"ShipyardWorld",
		"must_be_direct_world_child": true,
	}


func get_service_access() -> StationDoor:
	return _service_access


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


func get_clearance_profile() -> Dictionary:
	return {
		"deck_elevation": DECK_ELEVATION,
		"connection_clear_width": CONNECTION_CLEAR_WIDTH,
		"service_door_clear_width": SERVICE_DOOR_CLEAR_WIDTH,
		"minimum_head_clearance": MINIMUM_HEAD_CLEARANCE,
		"player_capsule_reference_diameter": 0.76,
		"player_capsule_reference_height": 1.94,
		"cargo_transfer_clear_width": 3.4,
	}


func get_service_room_volume() -> Dictionary:
	var local_center := Vector3(19.25, 2.2, 29.0)
	var half_extents := Vector3(3.05, 2.2, 4.75)
	return {
		"room_id": &"freight-control",
		"room_class": &"freight-service-room",
		"local_center": local_center,
		"half_extents": half_extents,
		"world_transform": global_transform * Transform3D(Basis.IDENTITY, local_center),
	}


func contains_service_room(world_position: Vector3) -> bool:
	var volume := get_service_room_volume()
	var relative := to_local(world_position) - (volume.local_center as Vector3)
	var half_extents := volume.half_extents as Vector3
	return absf(relative.x) <= half_extents.x \
		and absf(relative.y) <= half_extents.y \
		and absf(relative.z) <= half_extents.z


## The root is the station-side connection plane. Local +Z is the outward axis.
func get_integration_footprint() -> Dictionary:
	return {
		"anchor_transform": _module_anchor.global_transform,
		"local_min": FOOTPRINT_MIN,
		"local_max": FOOTPRINT_MAX,
		"local_size": FOOTPRINT_MAX - FOOTPRINT_MIN,
		"approach_axis_local": Vector3.FORWARD,
		"module_extends_local": Vector3.BACK,
		"outbound_launch_axis_local": Vector3.BACK,
		"connection_overlap_depth": 4.8,
		"recommended_world_transform": RECOMMENDED_WORLD_TRANSFORM,
	}


func get_ship_clearance_envelope() -> Dictionary:
	var berth_transform := get_berth_transform()
	var world_transform := berth_transform * Transform3D(Basis.IDENTITY, SHIP_ENVELOPE_CENTER_FROM_ROOT)
	return {
		"berth_id": BERTH_ID,
		"dock_transform": berth_transform,
		"local_root_origin": SHIP_ROOT_LOCAL,
		"local_center_from_root": SHIP_ENVELOPE_CENTER_FROM_ROOT,
		"world_transform": world_transform,
		"half_extents": SHIP_ENVELOPE_HALF_EXTENTS,
		"full_size": SHIP_ENVELOPE_HALF_EXTENTS * 2.0,
		"declared_flight_size": SHIP_DECLARED_FLIGHT_SIZE,
		"declared_deployed_size": SHIP_DECLARED_DEPLOYED_SIZE,
		"deck_contact_root_offset": -1.25,
		"interior_deck_root_offset": 0.55,
		"authenticated_dimensions": false,
	}


func contains_ship_clearance(world_position: Vector3) -> bool:
	var envelope := get_ship_clearance_envelope()
	var local_point := (envelope.world_transform as Transform3D).affine_inverse() * world_position
	var half_extents := envelope.half_extents as Vector3
	return absf(local_point.x) <= half_extents.x \
		and absf(local_point.y) <= half_extents.y \
		and absf(local_point.z) <= half_extents.z


func get_equipment_motion_contract() -> Dictionary:
	var hook_clearance_above_envelope := (
		SHIP_ROOT_LOCAL.y
		+ SHIP_ENVELOPE_CENTER_FROM_ROOT.y
		+ SHIP_ENVELOPE_HALF_EXTENTS.y
	)
	return {
		"equipment_id": &"freight-gantry-crane",
		"animation_enabled": _equipment_animation_enabled,
		"trolley_axis_local": Vector3.RIGHT,
		"trolley_travel_min": -CRANE_TROLLEY_TRAVEL,
		"trolley_travel_max": CRANE_TROLLEY_TRAVEL,
		"trolley_elevation": CRANE_TROLLEY_ELEVATION,
		"hook_elevation_min": CRANE_HOOK_MIN_ELEVATION,
		"hook_elevation_max": CRANE_HOOK_MAX_ELEVATION,
		"ship_envelope_top_elevation": hook_clearance_above_envelope,
		"minimum_vertical_separation": CRANE_HOOK_MIN_ELEVATION - hook_clearance_above_envelope,
		"motion_is_presentation_only": true,
	}


func set_equipment_animation_enabled(enabled: bool) -> void:
	_equipment_animation_enabled = enabled
	# A disabled module never processes, whatever the animation flag says.
	set_process(enabled and _module_enabled)


func is_equipment_animation_enabled() -> bool:
	return _equipment_animation_enabled


## Deterministic hook for tests, replays, and future multiplayer presentation.
func advance_equipment_simulation(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	_equipment_elapsed += delta
	_update_equipment_transforms()


func get_equipment_state() -> Dictionary:
	return {
		"elapsed": _equipment_elapsed,
		"trolley_local_position": _crane_trolley.position if _crane_trolley != null else Vector3.ZERO,
		"hook_local_position": _crane_hook.position if _crane_hook != null else Vector3.ZERO,
	}


func get_cargo_unit_count() -> int:
	return _cargo_units.size()


func get_service_detail_count() -> int:
	return _service_details.size()


func get_animated_equipment_count() -> int:
	return _animated_equipment.size()


func get_evidence_metadata() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"module_id": MODULE_ID,
		"evidence_status": EVIDENCE_STATUS,
		"source_bounded": true,
		"creator_supported_identity": true,
		"creator_supported_role": true,
		"authenticated_original_geometry": false,
		"authenticated_berth_layout": false,
		"references": PackedStringArray(EVIDENCE_REFERENCES),
		"content_note": CONTENT_NOTE,
		"supported_invariants": PackedStringArray([
			"the exact Jovian-class Light Freighter name",
			"the light-freighter role in the creator-authored 2009-11-12 fleet roster",
			"a physically parked fleet distributed around exposed station lattice nodes",
		]),
		"modern_interpretations": PackedStringArray([
			"module name, exact station adjacency, dimensions, and connection",
			"freight apron, service room, pressure access, and cargo workflow",
			"gantry crane, cargo racks, containers, lighting, signage, and materials",
			"ship envelope, landing volume, compatibility tags, and dock orientation",
		]),
		"explicit_unknowns": PackedStringArray([
			"authoritative Jovian name-to-model mapping",
			"Jovian geometry, colours, dimensions, interior, cargo capacity, ramp, and crew",
			"historical freight-berth existence, shape, equipment, and station position",
		]),
	}


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if _module_anchor == null:
		errors.append("module integration anchor is missing")
	if _berth_dock_marker == null:
		errors.append("stable freight berth dock marker is missing")
	elif not _berth_dock_marker.global_transform.is_equal_approx(get_berth_transform()):
		errors.append("berth marker does not match the exact dock transform")
	var berth_spec := get_berth_specification()
	if berth_spec.berth_id != BERTH_ID \
		or (berth_spec.compatibility_tags as PackedStringArray).size() < 4 \
		or not bool(berth_spec.must_be_direct_world_child):
		errors.append("direct-world ShipBerth specification is invalid")
	if _service_access == null or _service_access.locked or _service_access.deferred_access:
		errors.append("freight control StationDoor must be present and operable")
	if _route_markers.size() != 7:
		errors.append("connection, loading, service, and storage route registry is incomplete")
	if _cargo_units.size() < CARGO_UNIT_TARGET:
		errors.append("cargo infrastructure contains fewer than eight physical units")
	if _service_details.size() < SERVICE_DETAIL_TARGET:
		errors.append("service room and dock systems are under-detailed")
	if _animated_equipment.size() < 2 or _crane_trolley == null or _crane_hook == null:
		errors.append("articulated freight equipment is incomplete")
	var motion := get_equipment_motion_contract()
	if float(motion.minimum_vertical_separation) < 0.55:
		errors.append("gantry motion does not preserve the protected ship envelope")
	var clearance := get_clearance_profile()
	if float(clearance.connection_clear_width) < 3.0 or float(clearance.minimum_head_clearance) < 2.4:
		errors.append("published player circulation clearance is invalid")
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


func get_typed_audit_report() -> JovianFreightBerthAudit:
	var errors := get_validation_errors()
	return JovianFreightBerthAudit.new(
		SCHEMA_VERSION,
		MODULE_ID,
		errors.is_empty(),
		errors,
		EVIDENCE_STATUS,
		true,
		false,
		BERTH_ID,
		_berth_dock_marker != null and (get_berth_specification().landing_half_extents as Vector3).is_finite(),
		get_route_ids(),
		get_cargo_unit_count(),
		get_service_detail_count(),
		get_animated_equipment_count(),
		get_integration_footprint(),
		get_ship_clearance_envelope(),
		get_equipment_motion_contract()
	)


func get_audit_report() -> Dictionary:
	var result := get_typed_audit_report().to_dictionary()
	result["evidence"] = get_evidence_metadata()
	result["clearance"] = get_clearance_profile()
	result["berth_specification"] = get_berth_specification()
	result["service_room"] = get_service_room_volume()
	result["service_door_operable"] = _service_access != null \
		and not _service_access.locked \
		and not _service_access.deferred_access
	return result.duplicate(true)


func get_component_roster() -> Dictionary:
	var roster := StationModuleContract.build_component_roster(self)
	roster["schema_version"] = SCHEMA_VERSION
	roster["module_id"] = MODULE_ID
	roster["cargo_unit_count"] = get_cargo_unit_count()
	roster["service_detail_count"] = get_service_detail_count()
	roster["animated_equipment_count"] = get_animated_equipment_count()
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
	# The berth publishes a ship-facing specification; it still claims no
	# gameplay authority over the ships that use it.
	contract["berth_specification_available"] = true
	return contract


func get_performance_contract() -> Dictionary:
	# Budgets are this module's own policy. The berth is the largest and most
	# heavily lit module, and it is the only one allowed a frame loop, which it
	# spends on the crane animation.
	var contract := StationModuleContract.build_performance_contract(self, {
		"mesh_instances": 420,
		"static_bodies": 220,
		"collision_shapes": 220,
		"labels": 30,
		"lights": 24,
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
	# The crane simulation is the one process loop in the four modules. Disabling
	# the module must stop it rather than leave it advancing behind hidden
	# geometry, which would snap the trolley and hook on re-enable.
	set_process(_module_enabled and _equipment_animation_enabled)


func audit() -> Dictionary:
	return get_audit_report()


func _index_semantics() -> void:
	_route_markers = {
		&"approach": _route_approach,
		&"apron-threshold": _route_apron_threshold,
		&"boarding-staging": _route_boarding_staging,
		&"cargo-transfer": _route_cargo_transfer,
		&"service-threshold": _route_service_threshold,
		&"service-room": _route_service_room,
		&"cargo-rack": _route_cargo_rack,
	}
	for route_id: StringName in _route_markers.keys():
		var marker := _route_markers[route_id] as Marker3D
		marker.set_meta("station_route_marker", true)
		marker.set_meta("route_id", route_id)
	# Only the outward approach face over the connection hand-off deck is a
	# station connection slot; the apron and service thresholds are internal.
	_route_approach.set_meta(StationModuleContract.CONNECTION_SLOT_META, HUB_CONNECTION_SLOT)
	_berth_dock_marker.set_meta("station_berth_marker", true)
	_berth_dock_marker.set_meta("berth_id", BERTH_ID)


func _create_materials() -> void:
	_materials["ceramic"] = _material(Color("d6dedb"), 0.32, 0.34)
	_materials["ceramic_warm"] = _material(Color("b8c2be"), 0.3, 0.39)
	# Floor-role twin of `ceramic_warm`. Both halves carry the same panel maps, so
	# a walked-on room floor and the wall it meets can no longer differ by hue
	# alone; the coated, trafficked half is rougher and less metallic.
	_materials["ceramic_floor"] = _material(Color("b8c2be"), 0.22, 0.54)
	_materials["steel_blue"] = _material(Color("315868"), 0.68, 0.28)
	_materials["deep_blue"] = _material(Color("102d3b"), 0.52, 0.43)
	_materials["graphite"] = _material(Color("172329"), 0.55, 0.48)
	_materials["deck"] = _material(Color("29434d"), 0.62, 0.47)
	_materials["deck_grip"] = _material(Color("1b2c32"), 0.36, 0.73)
	# Painted handling steel: crane rails and feet, rack beams, apron and lattice
	# diagonals, rail posts, the utility trunk, the spreader bar. Rendered at eye
	# height beside the cargo rack this was the single loudest untextured
	# population left in the station — flat plastic slabs bolted between plated
	# `steel_blue` posts and plated cargo units. It joins the panel family, and its
	# response moves away from `steel_blue`'s polished bare structure: rolled steel
	# under a thick coat of paint is matte, not glossy, so the two now differ in
	# material and not only in hue.
	_materials["orange"] = _material(Color("e79338"), 0.24, 0.54)
	_materials["orange_glow"] = _material(Color("ffae48"), 0.12, 0.28, Color("f58a24"), 2.1)
	_materials["cyan"] = _material(Color("5ce5e4"), 0.16, 0.25, Color("32cbd2"), 1.8)
	_materials["cyan_dim"] = _material(Color("347d83"), 0.36, 0.38, Color("2599a1"), 0.38)
	_materials["red"] = _material(Color("db4b43"), 0.22, 0.39, Color("a72b28"), 0.9)
	_materials["rubber"] = _material(Color("0e1518"), 0.04, 0.9)
	_materials["glass"] = _transparent_material(Color(0.2, 0.72, 0.78, 0.22), 0.16, 0.12)
	_materials["screen"] = _material(Color("8debe6"), 0.05, 0.22, Color("49cbd2"), 1.35)

	# One call per key into the published kit recipe rather than an inline copy of
	# it, so this module cannot drift from the shared `normal_scale = 1.0` that
	# keeps one relief depth across every module seam. The walked-on surfaces stay
	# at the berth's tighter 0.22 m plate; everything else stays at 0.30 m.
	for key in [
		"ceramic",
		"ceramic_warm",
		"ceramic_floor",
		"steel_blue",
		"deck",
		# Painted handling steel. Structure, not hazard marking: the striped route
		# and lane cues are `orange_glow` and stay outside the family.
		"orange",
	]:
		var panel := _materials[key] as StandardMaterial3D
		StationSurfaceKit.apply_panel_triplanar(
			panel,
			WALKED_PANEL_SURFACE_SCALE if key in ["deck", "ceramic_floor"] else PANEL_SURFACE_SCALE
		)
		# The berth's own sealed-marine-paint layer over the shared recipe.
		panel.clearcoat_enabled = true
		panel.clearcoat = 0.28
		panel.clearcoat_roughness = 0.38


func _build_connection_lattice() -> void:
	var root_node := Node3D.new()
	root_node.name = "ConnectionLattice"
	add_child(root_node)

	# Three overlapping chamfered deck leaves guarantee physical floor support
	# across the integration seam while leaving the surrounding structure open.
	_rounded_box(root_node, "ConnectionDeckA", Vector3(0, -0.31, -2.25), Vector3(6.8, 0.62, 5.1), _materials["deck"])
	_rounded_box(root_node, "ConnectionDeckB", Vector3(0, -0.31, 2.1), Vector3(7.4, 0.62, 4.2), _materials["deck"])
	_rounded_box(root_node, "ConnectionDeckC", Vector3(0, -0.31, 6.45), Vector3(8.4, 0.62, 5.0), _materials["deck"])
	# A short east-facing leaf lands on the open edge of the existing elevated
	# registry shelf. The main approach remains west of its back wall, so only
	# this explicitly named handoff shares legacy floor collision.
	var handoff := _rounded_box(root_node, "ConnectionHandoffDeck", Vector3(3.5, -0.3, -3.2), Vector3(7.0, 0.6, 3.0), _materials["ceramic_floor"])
	handoff.set_meta("intentional_connection_overlap", true)

	for side in [-1.0, 1.0]:
		# Curved handrail and tapered lattice legs preserve the exposed Keth-like
		# bridge silhouette without turning it into an enclosed corridor.
		for z_position in [-3.7, 0.2, 4.1, 8.1]:
			if side > 0.0 and z_position < -3.0:
				continue
			_cylinder(root_node, "LatticePost", Vector3(side * 3.45, -1.35, z_position), 0.22, 2.7, _materials["steel_blue"], true)
			_cylinder(root_node, "RailPost", Vector3(side * 3.45, 0.58, z_position), 0.1, 1.15, _materials["orange"], true)
		if side < 0.0:
			_cylinder(root_node, "ApproachRail", Vector3(side * 3.45, 1.12, 2.1), 0.1, 12.5, _materials["ceramic"], true, Vector3(90, 0, 0))
		else:
			_cylinder(root_node, "ApproachRail", Vector3(side * 3.45, 1.12, 3.35), 0.1, 9.9, _materials["ceramic"], true, Vector3(90, 0, 0))
		_cylinder(root_node, "LowerChord", Vector3(side * 3.25, -2.6, 2.1), 0.2, 12.8, _materials["steel_blue"], true, Vector3(90, 0, 0))
		for z_position in [-1.7, 5.9]:
			_rounded_box(root_node, "DiagonalBrace", Vector3(side * 3.25, -1.75, z_position), Vector3(0.24, 0.42, 5.0), _materials["orange"], false, Vector3(32, 0, 0))

	for z_position in [-3.8, 0.2, 4.2, 8.2]:
		_cylinder(root_node, "CrossMember", Vector3(0, -2.55, z_position), 0.17, 6.7, _materials["steel_blue"], false, Vector3(0, 0, 90))


func _build_loading_apron() -> void:
	var apron := Node3D.new()
	apron.name = "LoadingApron"
	add_child(apron)

	# Large but segmented load-bearing leaves avoid a single featureless slab.
	for index in 4:
		var z_position := 13.6 + float(index) * 9.75
		_rounded_box(apron, "ApronDeck%02d" % (index + 1), Vector3(0, -0.37, z_position), Vector3(31.6, 0.74, 10.0), _materials["deck"])
		_rounded_box(apron, "CentreGrip%02d" % (index + 1), Vector3(0, 0.025, z_position), Vector3(7.5, 0.045, 9.45), _materials["deck_grip"], false)

	# Side service shelves make the apron asymmetrical and operational.
	_rounded_box(apron, "CargoRackShelf", Vector3(-19.15, -0.31, 28.0), Vector3(6.4, 0.62, 27.0), _materials["deck"])
	_rounded_box(apron, "ServiceRoomShelf", Vector3(19.0, -0.31, 29.0), Vector3(7.8, 0.62, 12.0), _materials["deck"])

	# Soft curved docking graphics and inset guide strips remain visual only.
	_torus(apron, "OuterDockRing", Vector3(0, 0.05, 28.5), 10.1, 10.33, _materials["ceramic"], Vector3.ZERO)
	_torus(apron, "InnerDockRing", Vector3(0, 0.065, 28.5), 7.0, 7.19, _materials["cyan"], Vector3.ZERO)
	_rounded_box(apron, "DockCentreline", Vector3(0, 0.085, 29.4), Vector3(0.22, 0.035, 35.5), _materials["cyan"], false)
	for side in [-1.0, 1.0]:
		for z_position in [13.0, 18.0, 23.0, 34.0, 39.0, 44.0]:
			_rounded_box(apron, "DockGuide", Vector3(side * 8.7, 0.09, z_position), Vector3(1.6, 0.035, 0.22), _materials["orange_glow"], false, Vector3(0, side * 18.0, 0))

	# Under-deck trusses carry the apron while preserving visible negative space.
	for z_position in [10.0, 18.5, 27.0, 35.5, 44.0, 49.0]:
		_cylinder(apron, "ApronCrossChord", Vector3(0, -2.15, z_position), 0.24, 31.0, _materials["steel_blue"], true, Vector3(0, 0, 90))
		for side in [-1.0, 1.0]:
			_cylinder(apron, "ApronPylon", Vector3(side * 14.1, -1.25, z_position), 0.3, 2.5, _materials["steel_blue"], true)
	for side in [-1.0, 1.0]:
		_cylinder(apron, "ApronLongChord", Vector3(side * 14.1, -2.45, 29.2), 0.26, 41.0, _materials["steel_blue"], true, Vector3(90, 0, 0))
		for z_position in [14.2, 23.2, 32.2, 41.2]:
			_rounded_box(apron, "ApronDiagonal", Vector3(side * 14.1, -1.65, z_position), Vector3(0.35, 0.42, 8.4), _materials["orange"], false, Vector3(34, 0, 0))

	# Collision-backed safety rails are outside the protected ship width. The
	# outbound +Z edge deliberately remains open for launch and recovery.
	for side in [-1.0, 1.0]:
		for z_position in [11.0, 16.0, 21.0, 38.0, 43.0]:
			# The service-room side has an intentional freight-transfer opening.
			if side > 0.0 and z_position > 20.0 and z_position < 38.0:
				continue
			_cylinder(apron, "ApronRailPost", Vector3(side * 15.6, 0.6, z_position), 0.11, 1.2, _materials["orange"], true)
		for segment in [[13.5, 5.0], [40.5, 7.0]]:
			var segment_center := float(segment[0])
			var segment_length := float(segment[1])
			_cylinder(apron, "ApronSideRail", Vector3(side * 15.6, 1.14, segment_center), 0.11, segment_length, _materials["ceramic"], true, Vector3(90, 0, 0))


func _build_service_room() -> void:
	var room := Node3D.new()
	room.name = "FreightControlRoom"
	room.set_meta("station_room", true)
	room.set_meta("room_id", &"freight-control")
	room.set_meta("evidence_status", EVIDENCE_STATUS)
	add_child(room)

	_rounded_box(room, "RoomFloor", Vector3(19.25, -0.19, 29.0), Vector3(6.2, 0.38, 10.0), _materials["ceramic_floor"])
	_rounded_box(room, "RoomRoof", Vector3(19.25, 4.55, 29.0), Vector3(6.2, 0.42, 10.0), _materials["ceramic"])
	_rounded_box(room, "OuterWallLower", Vector3(22.2, 1.0, 29.0), Vector3(0.42, 2.0, 10.0), _materials["steel_blue"])
	_rounded_box(room, "OuterWallUpper", Vector3(22.2, 4.0, 29.0), Vector3(0.42, 1.1, 10.0), _materials["ceramic"])
	_rounded_box(room, "ForwardWall", Vector3(19.25, 2.25, 24.2), Vector3(6.2, 4.5, 0.42), _materials["ceramic"])
	_rounded_box(room, "AftWall", Vector3(19.25, 2.25, 33.8), Vector3(6.2, 4.5, 0.42), _materials["ceramic"])
	# Door-side wall is split around the real StationDoor portal.
	_rounded_box(room, "InnerWallForward", Vector3(16.3, 2.25, 25.7), Vector3(0.42, 4.5, 2.55), _materials["steel_blue"])
	_rounded_box(room, "InnerWallAft", Vector3(16.3, 2.25, 32.3), Vector3(0.42, 4.5, 2.55), _materials["steel_blue"])

	# Space-facing glazed band with mullions and physical lower wall.
	for z_position in [25.4, 27.2, 29.0, 30.8, 32.6]:
		var pane := _rounded_box(room, "ObservationPane", Vector3(22.0, 2.72, z_position), Vector3(0.06, 2.05, 1.45), _materials["glass"], false)
		pane.set_meta("station_glazing", true)
		_service_details.append(pane)
		_rounded_box(room, "WindowMullion", Vector3(21.95, 2.72, z_position - 0.83), Vector3(0.16, 2.35, 0.14), _materials["graphite"], false)

	# Physical workbench, dispatch console, and utility trunks make this a room
	# rather than a decorative box.
	var workbench := _rounded_box(room, "DispatchWorkbench", Vector3(20.65, 0.82, 29.0), Vector3(1.65, 1.45, 4.7), _materials["graphite"])
	workbench.set_meta("station_workbench", true)
	_service_details.append(workbench)
	for z_position in [27.6, 29.0, 30.4]:
		var screen := _rounded_box(room, "DispatchScreen", Vector3(19.79, 1.55, z_position), Vector3(0.08, 0.72, 1.05), _materials["screen"], false, Vector3(0, 0, -12))
		screen.set_meta("station_console", true)
		_service_details.append(screen)
	for z_position in [25.2, 32.8]:
		var trunk := _cylinder(room, "UtilityTrunk", Vector3(21.4, 1.95, z_position), 0.18, 3.7, _materials["orange"], true)
		trunk.set_meta("station_service_detail", true)
		_service_details.append(trunk)
	for y_position in [0.65, 1.15, 1.65]:
		var status := _rounded_box(room, "StatusBar", Vector3(16.55, y_position, 25.15), Vector3(0.08, 0.11, 1.1), _materials["cyan"], false)
		_service_details.append(status)


func _build_cargo_infrastructure() -> void:
	var cargo_root := Node3D.new()
	cargo_root.name = "CargoInfrastructure"
	add_child(cargo_root)

	# External racks are deliberately outside the ship's deployed-ramp envelope.
	for z_position in [18.5, 28.0, 37.5]:
		for side_z in [-3.0, 3.0]:
			_cylinder(cargo_root, "RackPost", Vector3(-21.2, 1.55, z_position + side_z), 0.18, 3.1, _materials["steel_blue"], true)
		_rounded_box(cargo_root, "RackBeam", Vector3(-21.2, 0.8, z_position), Vector3(0.45, 0.32, 6.5), _materials["orange"], true)
		_rounded_box(cargo_root, "RackBeam", Vector3(-21.2, 2.25, z_position), Vector3(0.45, 0.32, 6.5), _materials["orange"], true)

	var cargo_layout := [
		[Vector3(-18.2, 0.72, 17.2), Vector3(4.0, 1.35, 3.0), "ceramic"],
		[Vector3(-18.5, 2.02, 17.2), Vector3(3.2, 1.15, 2.6), "orange"],
		[Vector3(-18.1, 0.65, 24.1), Vector3(3.7, 1.2, 2.8), "steel_blue"],
		[Vector3(-18.6, 1.78, 24.1), Vector3(2.8, 0.95, 2.4), "ceramic_warm"],
		[Vector3(-18.3, 0.78, 31.4), Vector3(4.1, 1.45, 3.1), "orange"],
		[Vector3(-18.2, 2.1, 31.4), Vector3(3.1, 1.05, 2.55), "ceramic"],
		[Vector3(-18.5, 0.68, 39.0), Vector3(3.5, 1.25, 2.9), "steel_blue"],
		[Vector3(-18.4, 1.82, 39.0), Vector3(2.9, 0.95, 2.35), "ceramic_warm"],
	]
	for index in cargo_layout.size():
		var entry: Array = cargo_layout[index]
		var cargo := _rounded_box(
			cargo_root,
			"CargoUnit%02d" % (index + 1),
			entry[0] as Vector3,
			entry[1] as Vector3,
			_materials[entry[2] as String]
		)
		cargo.set_meta("station_cargo_unit", true)
		cargo.set_meta("cargo_unit_id", StringName("freight-unit-%02d" % (index + 1)))
		cargo.set_meta("evidence_status", EVIDENCE_STATUS)
		_cargo_units.append(cargo)
		for stripe_side in [-1.0, 1.0]:
			_rounded_box(cargo_root, "CargoBand", (entry[0] as Vector3) + Vector3(stripe_side * (entry[1] as Vector3).x * 0.3, 0.0, -(entry[1] as Vector3).z * 0.505), Vector3(0.16, (entry[1] as Vector3).y * 0.82, 0.05), _materials["deep_blue"], false)

	# Two dock power/fuel cabinets sit near the ramp staging route without
	# obstructing the 3.4 m transfer lane.
	for index in 2:
		var z_position := 21.0 + float(index) * 15.8
		var cabinet := _rounded_box(cargo_root, "ServiceCabinet%02d" % (index + 1), Vector3(13.55, 1.25, z_position), Vector3(1.2, 2.5, 2.0), _materials["ceramic"])
		cabinet.set_meta("station_service_detail", true)
		_service_details.append(cabinet)
		for y_position in [0.75, 1.25, 1.75]:
			var indicator := _rounded_box(cargo_root, "CabinetIndicator", Vector3(12.92, y_position, z_position), Vector3(0.05, 0.13, 1.25), _materials["cyan_dim"], false)
			_service_details.append(indicator)


func _build_crane() -> void:
	var crane := Node3D.new()
	crane.name = "FreightGantryCrane"
	crane.set_meta("animated_station_equipment", true)
	crane.set_meta("equipment_id", &"freight-gantry-crane")
	crane.set_meta("motion_contract", get_equipment_motion_contract())
	add_child(crane)
	_animated_equipment.append(crane)

	for side in [-1.0, 1.0]:
		_cylinder(crane, "GantryLeg", Vector3(side * 14.15, 6.35, CRANE_CENTER_Z), 0.38, 12.7, _materials["steel_blue"], true)
		_cylinder(crane, "GantryFoot", Vector3(side * 14.15, 0.28, CRANE_CENTER_Z), 0.7, 0.55, _materials["orange"], true)
		_rounded_box(crane, "GantryKnee", Vector3(side * 13.0, 11.15, CRANE_CENTER_Z), Vector3(3.2, 0.42, 0.7), _materials["ceramic"], false, Vector3(0, 0, side * 34.0))
	_cylinder(crane, "GantryHeader", Vector3(0, 13.0, CRANE_CENTER_Z), 0.42, 28.6, _materials["ceramic"], true, Vector3(0, 0, 90))
	_cylinder(crane, "TrolleyRailA", Vector3(0, 12.4, CRANE_CENTER_Z - 0.5), 0.13, 27.0, _materials["orange"], false, Vector3(0, 0, 90))
	_cylinder(crane, "TrolleyRailB", Vector3(0, 12.4, CRANE_CENTER_Z + 0.5), 0.13, 27.0, _materials["orange"], false, Vector3(0, 0, 90))

	_crane_trolley = Node3D.new()
	_crane_trolley.name = "AnimatedTrolley"
	_crane_trolley.position = Vector3(0, CRANE_TROLLEY_ELEVATION, CRANE_CENTER_Z)
	_crane_trolley.set_meta("animated_station_equipment", true)
	crane.add_child(_crane_trolley)
	_animated_equipment.append(_crane_trolley)
	_rounded_box(_crane_trolley, "TrolleyCarriage", Vector3.ZERO, Vector3(2.2, 0.65, 1.7), _materials["graphite"], false)
	for z_side in [-1.0, 1.0]:
		for x_side in [-1.0, 1.0]:
			_cylinder(_crane_trolley, "TrolleyWheel", Vector3(x_side * 0.72, -0.35, z_side * 0.52), 0.2, 0.18, _materials["rubber"], false, Vector3(90, 0, 0))

	_crane_hook = Node3D.new()
	_crane_hook.name = "AnimatedHoist"
	_crane_hook.position = Vector3(0, -1.7, 0)
	_crane_hook.set_meta("animated_station_equipment", true)
	_crane_trolley.add_child(_crane_hook)
	_animated_equipment.append(_crane_hook)
	_cylinder(_crane_hook, "HoistCable", Vector3(0, 0.45, 0), 0.045, 1.35, _materials["graphite"], false)
	_torus(_crane_hook, "CargoHook", Vector3(0, -0.28, 0), 0.28, 0.38, _materials["orange_glow"], Vector3(90, 0, 0))
	_rounded_box(_crane_hook, "SpreaderBar", Vector3(0, 0.05, 0), Vector3(1.5, 0.16, 0.24), _materials["orange"], false)


func _build_lighting_and_signage() -> void:
	var presentation := Node3D.new()
	presentation.name = "FreightPresentation"
	add_child(presentation)

	for side in [-1.0, 1.0]:
		for z_position in [10.5, 17.5, 24.5, 32.5, 40.5, 47.5]:
			_guide_light(presentation, Vector3(side * 15.1, 0.35, z_position), Color("4bdce3"), 1.0, 5.5)
	# MAP-006. The last centreline guide lens was authored at z = 49.0, but the
	# apron's outbound leaf (`ApronDeck04`) ends at z = 47.85, so that one lens
	# hung 1.15 m past the edge with a 2.04 m drop to `ApronCrossChord6` below —
	# the only lens of the eighteen not resting on the surface it marks. It is
	# pulled back to z = 47.0, still the outermost cue on the outbound edge and
	# still inboard of the deck lip it now sits on.
	for z_position in [10.0, 18.0, 26.0, 34.0, 42.0, 47.0]:
		_guide_light(presentation, Vector3(0, 0.25, z_position), Color("f6a445"), 0.65, 4.0)

	for side in [-1.0, 1.0]:
		var work_light := SpotLight3D.new()
		work_light.name = "ApronWorkLight"
		work_light.position = Vector3(side * 11.5, 12.2, CRANE_CENTER_Z)
		work_light.rotation_degrees.x = -90.0
		work_light.light_color = Color("d8fffa")
		work_light.light_energy = 2.25
		# Widened from 38 degrees / 23 m after measuring where the pair actually
		# landed. A 38 degree cone from y = 12.2 puts a 9.5 m radius pool under
		# each mast, so the two pools stopped at local x = -2.0 and +2.0 and left
		# a four-metre unlit seam straight down the berth centreline — exactly
		# where a freighter parks. The parked craft sat in the gap between its own
		# two work lights and its lower hull went black. At 47 degrees the pools
		# overlap across the centreline. Still two lights, still both shadowed.
		work_light.spot_range = 30.0
		work_light.spot_angle = 47.0
		work_light.spot_angle_attenuation = 0.55
		work_light.spot_attenuation = 0.75
		work_light.shadow_enabled = true
		presentation.add_child(work_light, true)

	var room_fill := OmniLight3D.new()
	room_fill.name = "FreightControlFill"
	room_fill.position = Vector3(19.2, 3.4, 29.0)
	room_fill.light_color = Color("a8f5ef")
	room_fill.light_energy = 1.2
	room_fill.omni_range = 8.0
	room_fill.shadow_enabled = false
	presentation.add_child(room_fill)

	_label(presentation, "MUDDS FREIGHT NODE  //  JOVIAN", Vector3(0, 4.6, 7.9), 0.62, Color("bffff6"), Vector3(0, 180, 0))
	_label(presentation, "BERTH F-01", Vector3(0, 0.14, 9.8), 0.46, Color("ffb45b"), Vector3(-90, 0, 0))
	_label(presentation, "FREIGHT CONTROL", Vector3(15.38, 3.95, 29.0), 0.42, Color("8df2ed"), Vector3(0, -90, 0))
	_label(presentation, "KEEP TRANSFER LANE CLEAR", Vector3(12.7, 0.13, 29.0), 0.3, Color("ffb45b"), Vector3(-90, 0, 90))


func _style_service_access() -> void:
	if _service_access == null:
		return
	var panel := _service_access.get_node_or_null("SlidingPanel/PanelMesh") as MeshInstance3D
	if panel != null:
		panel.material_override = _materials["deep_blue"]
	for indicator_path in ["SlidingPanel/LeftIndicator", "SlidingPanel/RightIndicator"]:
		var indicator := _service_access.get_node_or_null(indicator_path) as MeshInstance3D
		if indicator != null:
			indicator.material_override = _materials["cyan"]


func _apply_metadata() -> void:
	set_meta("station_module", true)
	set_meta("module_id", MODULE_ID)
	set_meta("module_schema_version", SCHEMA_VERSION)
	set_meta("evidence_status", EVIDENCE_STATUS)
	set_meta("source_bounded", true)
	set_meta("creator_supported_identity", true)
	set_meta("authenticated_original_geometry", false)
	set_meta("target_ship_class_id", SHIP_CLASS_ID)
	set_meta("target_ship_class_name", SHIP_CLASS_NAME)
	add_to_group("station_modules")
	add_to_group("freight_berth_modules")
	if _berth_dock_marker != null:
		_berth_dock_marker.set_meta("required_direct_world_berth", true)
		_berth_dock_marker.set_meta("compatibility_tags", get_berth_specification().compatibility_tags)


func _update_equipment_transforms() -> void:
	if _crane_trolley == null or _crane_hook == null:
		return
	var trolley_x := sin(_equipment_elapsed * 0.34) * CRANE_TROLLEY_TRAVEL
	var hook_lowest_world_y := lerpf(
		CRANE_HOOK_MIN_ELEVATION,
		CRANE_HOOK_MAX_ELEVATION,
		0.5 + 0.5 * sin(_equipment_elapsed * 0.61 + 1.1)
	)
	_crane_trolley.position = Vector3(trolley_x, CRANE_TROLLEY_ELEVATION, CRANE_CENTER_Z)
	var hook_root_world_y := hook_lowest_world_y - CRANE_HOOK_VISUAL_LOW_OFFSET
	_crane_hook.position = Vector3(0, hook_root_world_y - CRANE_TROLLEY_ELEVATION, 0)
	_crane_hook.rotation.y = sin(_equipment_elapsed * 0.43) * 0.12


func _material(
		color: Color,
		metallic: float = 0.0,
		roughness: float = 0.65,
		emission_color: Color = Color.TRANSPARENT,
		emission_energy: float = 0.0
	) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.metallic = metallic
	result.roughness = roughness
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
	return result


func _rounded_box(
		parent: Node3D,
		node_name: String,
		position_value: Vector3,
		size: Vector3,
		material: Material,
		collidable: bool = true,
		rotation_value: Vector3 = Vector3.ZERO
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
	container.position = position_value
	container.rotation_degrees = rotation_value
	parent.add_child(container, true)

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


## Deliberately NOT folded into `StationSurfaceKit`, unlike the five other
## station builders that now share the kit's chamfered-box body.
##
## This is a different algorithm, not a copy of the same one: it emits an inset
## face quad plus four skirt quads with averaged corner normals and calls
## `SurfaceTool.index()`, where the kit emits a nine-quad grid with per-corner
## normals and no index pass. The two produce different vertex counts, different
## normals and different topology for the same box, so moving this module onto
## the kit would rewrite every chamfered surface in the berth rather than
## deduplicate identical code. Its bevel rule differs too — clamped to
## 0.008..0.22 m rather than 0.003..0.20 m — and the kit rule would move 21 of
## this module's 44 distinct box sizes by up to 0.04 m. Rewriting this builder is
## a geometry change with its own evidence, not a consolidation.
func _rounded_box_mesh(size: Vector3) -> ArrayMesh:
	var cache_key := "%0.3f:%0.3f:%0.3f" % [size.x, size.y, size.z]
	if _rounded_box_cache.has(cache_key):
		return _rounded_box_cache[cache_key] as ArrayMesh
	var half := size * 0.5
	# Same published rule as the other modules, at this berth's own caps. Exactly
	# equivalent to the clampf() this replaced.
	var bevel := StationSurfaceKit.proportional_bevel_for_size(size, 0.22, 0.008)
	var inner := Vector3(maxf(0.0, half.x - bevel), maxf(0.0, half.y - bevel), maxf(0.0, half.z - bevel))
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces: Array[Array] = [
		[Vector3.RIGHT, Vector3.UP, Vector3.BACK],
		[Vector3.LEFT, Vector3.BACK, Vector3.UP],
		[Vector3.UP, Vector3.BACK, Vector3.RIGHT],
		[Vector3.DOWN, Vector3.RIGHT, Vector3.BACK],
		[Vector3.BACK, Vector3.RIGHT, Vector3.UP],
		[Vector3.FORWARD, Vector3.UP, Vector3.RIGHT],
	]
	for face in faces:
		_add_bevelled_face(surface, face[0], face[1], face[2], inner, half)
	surface.index()
	# No generate_tangents() here, unlike aft_junction_stack/habitat_spine: this
	# builder's _add_quad never calls set_uv, so the surface carries no UV channel
	# and generate_tangents() would only log "UVs are required to generate
	# tangents." Giving this builder real per-face UVs is the prerequisite, and it
	# buys nothing while the panel material above stays uv1_world_triplanar —
	# measured, that path samples the normal map by world position and ignores the
	# mesh tangent entirely. Add UVs first if triplanar is ever turned off.
	var result := surface.commit()
	_rounded_box_cache[cache_key] = result
	return result


func _add_bevelled_face(surface: SurfaceTool, normal: Vector3, axis_a: Vector3, axis_b: Vector3, inner: Vector3, half: Vector3) -> void:
	var normal_half := absf(normal.x) * half.x + absf(normal.y) * half.y + absf(normal.z) * half.z
	var a_inner := absf(axis_a.x) * inner.x + absf(axis_a.y) * inner.y + absf(axis_a.z) * inner.z
	var b_inner := absf(axis_b.x) * inner.x + absf(axis_b.y) * inner.y + absf(axis_b.z) * inner.z
	var a_half := absf(axis_a.x) * half.x + absf(axis_a.y) * half.y + absf(axis_a.z) * half.z
	var b_half := absf(axis_b.x) * half.x + absf(axis_b.y) * half.y + absf(axis_b.z) * half.z
	var centre := normal * normal_half
	var inner_points: Array[Vector3] = [
		centre - axis_a * a_inner - axis_b * b_inner,
		centre + axis_a * a_inner - axis_b * b_inner,
		centre + axis_a * a_inner + axis_b * b_inner,
		centre - axis_a * a_inner + axis_b * b_inner,
	]
	_add_quad(surface, inner_points[0], inner_points[1], inner_points[2], inner_points[3], normal)
	var corner_points: Array[Vector3] = [
		centre - axis_a * a_half - axis_b * b_half,
		centre + axis_a * a_half - axis_b * b_half,
		centre + axis_a * a_half + axis_b * b_half,
		centre - axis_a * a_half + axis_b * b_half,
	]
	for index in 4:
		var next: int = (index + 1) % 4
		var bevel_normal: Vector3 = (normal + (corner_points[index] - centre).normalized()).normalized()
		_add_quad(surface, inner_points[index], corner_points[index], corner_points[next], inner_points[next], bevel_normal)


## Emission order is the front-face winding. This builder is a different
## algorithm from `StationSurfaceKit`'s chamfered box, but it carried the same
## defect: `a, b, c / a, c, d` against these face axes puts
## `(b - a) x (c - a)` along the outward normal, and Godot's front face is the
## opposite one — measured against `BoxMesh`, `CylinderMesh` and `SphereMesh`,
## which all score zero agreement. Every box this berth built therefore had its
## outward faces culled and rendered the unlit inside of its own back faces.
## Vertices and normals are unchanged; only the emission order is reversed.
func _add_quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3) -> void:
	for vertex in [a, c, b, a, d, c]:
		surface.set_normal(normal)
		surface.add_vertex(vertex)


func _cylinder(
		parent: Node3D,
		node_name: String,
		position_value: Vector3,
		radius: float,
		height: float,
		material: Material,
		collidable: bool = true,
		rotation_value: Vector3 = Vector3.ZERO
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
	container.position = position_value
	container.rotation_degrees = rotation_value
	parent.add_child(container, true)
	# Tapered stock: the wide bottom rim is the sole carrier of this mesh's
	# radial extent, so the kit leaves it sharp and chamfers only the narrow top
	# rim. That is the visible one anyway — these stand on their wide end against
	# the apron. Outer radius and overall height are unchanged, so the collision
	# cylinder below still matches the mesh envelope exactly.
	var mesh := StationSurfaceKit.chamfered_cylinder_mesh_cached(
		radius * 0.94, radius, height, 16, _chamfered_cylinder_cache, 2
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


func _torus(parent: Node3D, node_name: String, position_value: Vector3, inner_radius: float, outer_radius: float, material: Material, rotation_value: Vector3) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = position_value
	mesh_instance.rotation_degrees = rotation_value
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = 48
	mesh.ring_segments = 12
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	parent.add_child(mesh_instance, true)
	return mesh_instance


func _guide_light(parent: Node3D, position_value: Vector3, color: Color, energy: float, range_value: float) -> void:
	var lens_mesh := SphereMesh.new()
	lens_mesh.radius = 0.13
	lens_mesh.height = 0.26
	lens_mesh.radial_segments = 12
	lens_mesh.rings = 6
	var lens := MeshInstance3D.new()
	lens.name = "DockGuideLens"
	lens.position = position_value
	lens.mesh = lens_mesh
	lens.material_override = _material(color, 0.0, 0.2, color, 1.6)
	parent.add_child(lens, true)
	var light := OmniLight3D.new()
	light.name = "DockGuideLight"
	light.position = position_value + Vector3.UP * 0.12
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range_value
	light.shadow_enabled = false
	parent.add_child(light, true)


func _label(parent: Node3D, text: String, position_value: Vector3, physical_height: float, color: Color, rotation_value: Vector3 = Vector3.ZERO) -> Label3D:
	var label := Label3D.new()
	label.name = "FreightSign"
	label.text = text
	label.position = position_value
	label.rotation_degrees = rotation_value
	label.font_size = 32
	# Call sites specify an approximate capital height in metres. Label3D itself
	# expects metres per font pixel, so divide by the chosen raster font size.
	label.pixel_size = physical_height / float(label.font_size)
	label.outline_size = 6
	label.modulate = color
	label.outline_modulate = Color("102026")
	label.shaded = true
	label.no_depth_test = false
	label.double_sided = false
	parent.add_child(label, true)
	return label
