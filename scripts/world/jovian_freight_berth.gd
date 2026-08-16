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

## Distance fade applied to every light this module builds. Measured, not chosen:
## a fade ending inside the module switched the whole practical pass off in every
## rendered framing of it.
const PRACTICAL_FADE_BEGIN := 60.0
const PRACTICAL_FADE_LENGTH := 25.0

const DECK_ELEVATION := 0.0
const CONNECTION_CLEAR_WIDTH := 5.8
const SERVICE_DOOR_CLEAR_WIDTH := 3.1
const MINIMUM_HEAD_CLEARANCE := 4.1
const CARGO_UNIT_TARGET := 8
const SERVICE_DETAIL_TARGET := 12
## Collision-backed freight-handling fixtures the berth must physically own:
## envelope bollards, staged pallet stacks, rack decking and its stored goods,
## the boarding stair and platform, the stores locker bank, the gas-bottle rack,
## the drum pallet, the skip, the hose reels, the pallet truck, the gantry
## catwalk with its ladder and cab, and the load-check readout. Counted
## separately from `CARGO_UNIT_TARGET`, which stays the eight tagged rack units.
const HANDLING_FIXTURE_TARGET := 60

## The parked craft's protected volume, restated in module-local space so the
## builders below can be read against it without re-deriving it from the berth
## marker. Every collision-backed fixture this module adds is placed outside this
## box: `tests/jovian_freight_berth_test.gd` asserts that the only colliders a
## shape-cast of the envelope can find are the load-bearing apron leaves.
const SHIP_ENVELOPE_LOCAL_MIN := Vector3(-11.5, -0.25, 11.0)
const SHIP_ENVELOPE_LOCAL_MAX := Vector3(11.5, 9.75, 46.0)

## The approach portal. A 26 m freighter berth is entered on foot, and the module
## legend used to hang in open space over the apron threshold with nothing behind
## it. The legend now rides a real gate: two masts standing on `ApronDeck01`, a
## header beam across them and a board hung under the header. Kept at z = 9.7 so
## the whole gate is forward of the protected envelope's z = 11.0 face.
const PORTAL_Z := 9.7
const PORTAL_MAST_HALF_SPAN := 6.5
const PORTAL_HEADER_ELEVATION := 5.95

## Painted handling bays. Both sit on the apron flanks outside the parked hull's
## protected width, which is what makes the wide empty middle of the apron read
## as reserved for the craft rather than as unfinished floor.
## Both bays sit outboard of the x = +/-12.4 bollard line and clear of the stores
## bank on the starboard outbound flank, so no painted zone is drawn under a
## structure that already occupies it.
const STAGING_BAY_PORT_CENTER := Vector3(-14.1, 0.0, 16.3)
const STAGING_BAY_STARBOARD_CENTER := Vector3(14.1, 0.0, 15.5)
const STAGING_BAY_HALF_SIZE := Vector2(1.35, 4.1)

## Gantry maintenance level. The catwalk laps the crane header rather than
## floating beside it, and it clears the animated trolley carriage (top 12.825)
## and the module's declared 14.2 m ceiling with its handrail up.
const CATWALK_DECK_ELEVATION := 13.06
const CATWALK_CENTER_Z := 28.0
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
	+ "explicitly provisional modern interpretation. The same applies to every "
	+ "piece of freight handling infrastructure on the apron: the approach portal, "
	+ "painted staging bays, bollards, lashing points, staged pallets, decked and "
	+ "loaded racking, stores lockers, gas bottles, drums, skip, boarding stair, "
	+ "service reels, dispatch kiosk, load-check plate, and the gantry catwalk, "
	+ "ladder and crane cab. No source authenticates any of it."
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
var _handling_fixtures: Array[Node3D] = []
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
		_build_approach_portal()
		_build_handling_zones()
		_build_freight_stores()
		_build_loading_apparatus()
		_build_gantry_access()
		_build_dispatch_annex()
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


## Collision-backed freight-handling fixtures: everything the berth owns that a
## player can walk into, climb, or stack against, outside the eight tagged rack
## cargo units and the service-room fittings.
func get_handling_fixture_count() -> int:
	return _handling_fixtures.size()


## Handling fixtures grouped by their declared class, sorted, detached. Exposed so
## an audit can tell "sixty fixtures" from "sixty bollards".
func get_handling_fixture_classes() -> Dictionary:
	var result := {}
	for fixture in _handling_fixtures:
		var fixture_class := fixture.get_meta("handling_fixture_class", &"unclassified") as StringName
		result[fixture_class] = int(result.get(fixture_class, 0)) + 1
	return result


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
			"approach portal, painted handling bays, bollards, lashing points, staged freight",
			"stores lockers, gas bottles, drums, skip, boarding stair, reels, gantry catwalk and cab",
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
	if _handling_fixtures.size() < HANDLING_FIXTURE_TARGET:
		errors.append("freight handling infrastructure is below the declared fixture floor")
	# A fixture roster is only worth publishing if every entry carries its class.
	# An unclassified fixture is a fixture that was registered by accident.
	for fixture in _handling_fixtures:
		if not bool(fixture.get_meta("station_handling_fixture", false)) \
			or str(fixture.get_meta("handling_fixture_class", "")).is_empty():
			errors.append("a handling fixture is missing its semantic class")
			break
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
		get_equipment_motion_contract(),
		get_handling_fixture_count(),
		get_handling_fixture_classes()
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
	roster["handling_fixture_count"] = get_handling_fixture_count()
	roster["handling_fixture_classes"] = get_handling_fixture_classes()
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
		# Drawn-mesh ceiling re-frozen in the open, 420 -> 520, for the freight
		# handling pass. The module built 208 against 420 and now builds far more:
		# an approach portal, ten envelope bollards with collars, eight recessed
		# lashing rings, two painted staging bays, two staged pallet stacks, six
		# decked and loaded rack shelves, a five-locker stores bank with a canopy,
		# a gas-bottle frame, a drum pallet, a skip, a boarding stair and platform,
		# two hose reels, a pallet truck, a full gantry catwalk with caged ladder
		# and crane cab, a dispatch kiosk, a load-check plate, and a drawn housing
		# under each of the eighteen guide lenses that used to hover over the deck.
		# Every one of those is static, chamfered, cached geometry sharing this
		# module's existing box and cylinder mesh cache, so most of them cost a
		# draw call and no new mesh at all. Frame cost is unmeasured: this box
		# renders through llvmpipe.
		"mesh_instances": 520,
		# Body and shape ceilings re-frozen in the open with the same pass,
		# 220 -> 260 each. The module built 101 bodies against 220 and now builds
		# 206: the handling pass is deliberately collision-heavy, because the class
		# of defect it exists to avoid is solid-looking apparatus a player or a tow
		# tractor drives straight through. Every bollard, step, rail post, locker,
		# bottle, drum, ladder stringer and catwalk rail is a real body with a real
		# shape rather than a decorative mesh. 206 against a 220 ceiling left no
		# room to add a single further fixture without another re-freeze, which is
		# the wrong reason to stop furnishing a berth.
		"static_bodies": 260,
		"collision_shapes": 260,
		"labels": 30,
		# Light ceiling re-frozen in the open, 24 -> 26. The module built 21 against
		# that 24 and now builds 26: a wash behind each of the four Label3D legends
		# and one warm desk lamp in the control room. Label3D is unlit type on a
		# transparent quad, so those four signs could not light anything at all
		# regardless of modulate; the desk lamp is the control room's second colour
		# temperature. All shadowless, sub-5.5 m range, distance-faded. Frame cost
		# is unmeasured: this box renders through llvmpipe.
		#
		# Re-frozen again in the open, 26 -> 31, by the freight handling pass. The
		# five additions are two more legend washes (the two new painted staging
		# bays, which follow the same rule as the four legends above: a Label3D is
		# an unlit quad and cannot light the plate it is painted on) and three warm
		# task practicals over the three new working positions - the rack aisle, the
		# stores locker bank and the boarding platform. All five are shadowless,
		# under 8.5 m range, steeply attenuated and distance-faded on the same
		# measured 60/25 m curve as every other practical here, so the whole-station
		# overview pays for none of them.
		"lights": 31,
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
			# Bottom on the deck plane, not 0.005 m over it.
			_cylinder(root_node, "RailPost", Vector3(side * 3.45, 0.575, z_position), 0.1, 1.15, _materials["orange"], true)
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
	# BERTH-PAINT-001. Both deck cues were authored as 0.035 m slabs floating at
	# their own top height: the centreline hung 0.068 m clear of the apron and each
	# of the twelve guide strips 0.073 m, so the module's most-walked-past markings
	# were a set of thin plates with daylight under them. Their painted top faces do
	# not move — 0.1025 -> 0.101 and 0.1075 -> 0.105 — the boxes are simply made
	# deep enough to reach the deck they are painted on. Nothing else about the cue
	# palette, angles, spacing or material changes.
	_rounded_box(apron, "DockCentreline", Vector3(0, 0.0505, 29.4), Vector3(0.22, 0.101, 35.5), _materials["cyan"], false)
	for side in [-1.0, 1.0]:
		for z_position in [13.0, 18.0, 23.0, 34.0, 39.0, 44.0]:
			_rounded_box(apron, "DockGuide", Vector3(side * 8.7, 0.0525, z_position), Vector3(1.6, 0.105, 0.22), _materials["orange_glow"], false, Vector3(0, side * 18.0, 0))

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
	# CONTROL-TRUNK-001. Both utility trunks were 3.7 m pipes whose ends reached
	# neither surface: they began 0.100 m above the room floor and stopped 0.540 m
	# under the roof, touching nothing in the module. A service trunk that carries
	# nothing between two places is the same defect as a crate above its shelf, only
	# vertical. They now run floor plate to roof plate (0.000 -> 4.340) at the same
	# x, z and radius, which is also what the room's own geometry implies they are.
	for z_position in [25.2, 32.8]:
		var trunk := _cylinder(room, "UtilityTrunk", Vector3(21.4, 2.17, z_position), 0.18, 4.34, _materials["orange"], true)
		trunk.set_meta("station_service_detail", true)
		_service_details.append(trunk)
	# Bedded into the wall face at x = 16.51 rather than standing exactly on it.
	for y_position in [0.65, 1.15, 1.65]:
		var status := _rounded_box(room, "StatusBar", Vector3(16.50, y_position, 25.15), Vector3(0.08, 0.11, 1.1), _materials["cyan"], false)
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

	# COMB-UNDERFRAME-001 family, found by the same "visible mesh with nothing
	# beneath it" sweep. All eight crates hovered: each lower crate floated
	# 0.045-0.055 m above the `CargoRackShelf` it stands on, and each upper crate
	# floated 0.040-0.070 m above the crate it is stacked on, touching nothing at
	# all in the 0.06 m sense. Every crate now rests with a 0.010 m bearing into
	# the surface below it. Only the y coordinate moved; x, z, every size and every
	# material are unchanged, so the eight tagged units, their bands and the
	# published cargo-unit count are untouched.
	var cargo_layout := [
		[Vector3(-18.2, 0.665, 17.2), Vector3(4.0, 1.35, 3.0), "ceramic"],
		[Vector3(-18.5, 1.905, 17.2), Vector3(3.2, 1.15, 2.6), "orange"],
		[Vector3(-18.1, 0.59, 24.1), Vector3(3.7, 1.2, 2.8), "steel_blue"],
		[Vector3(-18.6, 1.655, 24.1), Vector3(2.8, 0.95, 2.4), "ceramic_warm"],
		[Vector3(-18.3, 0.715, 31.4), Vector3(4.1, 1.45, 3.1), "orange"],
		[Vector3(-18.2, 1.955, 31.4), Vector3(3.1, 1.05, 2.55), "ceramic"],
		[Vector3(-18.5, 0.615, 39.0), Vector3(3.5, 1.25, 2.9), "steel_blue"],
		[Vector3(-18.4, 1.705, 39.0), Vector3(2.9, 0.95, 2.35), "ceramic_warm"],
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
		# The cabinet's front face is x = 12.95; the indicator strip stood 0.005 m
		# clear of it. It is now bedded 0.015 m into the panel it reads from.
		for y_position in [0.75, 1.25, 1.75]:
			var indicator := _rounded_box(cargo_root, "CabinetIndicator", Vector3(12.96, y_position, z_position), Vector3(0.05, 0.13, 1.25), _materials["cyan_dim"], false)
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
		_cylinder(crane, "GantryFoot", Vector3(side * 14.15, 0.275, CRANE_CENTER_Z), 0.7, 0.55, _materials["orange"], true)
		_rounded_box(crane, "GantryKnee", Vector3(side * 13.0, 11.15, CRANE_CENTER_Z), Vector3(3.2, 0.42, 0.7), _materials["ceramic"], false, Vector3(0, 0, side * 34.0))
	_cylinder(crane, "GantryHeader", Vector3(0, 13.0, CRANE_CENTER_Z), 0.42, 28.6, _materials["ceramic"], true, Vector3(0, 0, 90))
	# CRANE-RAIL-001, the same class as the hoist that detached from its beam. Both
	# 27 m trolley rails topped out at y = 12.53 under a header whose underside is
	# 12.58: the rails the trolley runs on were bolted to 0.05 m of nothing. Raised
	# by 0.07 so they bear on the header, which still leaves the carriage wheels
	# (top 12.35) riding under the rail crown. No travel, elevation or motion
	# contract value moves.
	_cylinder(crane, "TrolleyRailA", Vector3(0, 12.47, CRANE_CENTER_Z - 0.5), 0.13, 27.0, _materials["orange"], false, Vector3(0, 0, 90))
	_cylinder(crane, "TrolleyRailB", Vector3(0, 12.47, CRANE_CENTER_Z + 0.5), 0.13, 27.0, _materials["orange"], false, Vector3(0, 0, 90))

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


## The gate a freighter berth is entered through, and the two legend mounts this
## module never had.
##
## Placed at z = 9.7, forward of the protected envelope's z = 11.0 face, so the
## whole gate is legal structure rather than something a parked hull has to miss.
## Both masts stand on `ApronDeck01`, the header bears on both masts and the board
## hangs off the header, so the assembly is a support chain to the deck with no
## link missing.
func _build_approach_portal() -> void:
	var portal := Node3D.new()
	portal.name = "ApproachPortal"
	add_child(portal)

	for side in [-1.0, 1.0]:
		var mast_name := "PortalMastPort" if side < 0.0 else "PortalMastStarboard"
		var mast := _cylinder(
			portal,
			mast_name,
			Vector3(side * PORTAL_MAST_HALF_SPAN, 2.85, PORTAL_Z),
			0.3,
			5.7,
			_materials["steel_blue"]
		)
		_register_handling_fixture(mast, &"approach-portal-mast")
		# Hazard banding at hand and headlamp height, bedded into the mast.
		for band_elevation in [0.72, 1.34]:
			_cylinder(
				portal,
				"PortalMastBand",
				Vector3(side * PORTAL_MAST_HALF_SPAN, band_elevation, PORTAL_Z),
				0.33,
				0.18,
				_materials["orange_glow"],
				false
			)
		_rounded_box(
			portal,
			"PortalMastFoot",
			Vector3(side * PORTAL_MAST_HALF_SPAN, 0.11, PORTAL_Z),
			Vector3(1.0, 0.22, 1.0),
			_materials["orange"],
			false
		)

	var header := _rounded_box(
		portal,
		"PortalHeaderBeam",
		Vector3(0.0, PORTAL_HEADER_ELEVATION, PORTAL_Z),
		Vector3(14.2, 0.5, 0.8),
		_materials["ceramic"]
	)
	_register_handling_fixture(header, &"approach-portal-header")

	# The board the module legend actually reads off. Its top edge is inside the
	# header, so the sign is hung from the beam rather than levitating under it.
	var board := _rounded_box(
		portal,
		"PortalSignBoard",
		Vector3(0.0, 4.92, PORTAL_Z - 0.08),
		Vector3(9.0, 1.6, 0.16),
		_materials["deep_blue"]
	)
	_register_handling_fixture(board, &"approach-portal-board")
	for edge_elevation in [4.2, 5.62]:
		_rounded_box(
			portal,
			"PortalBoardEdge",
			Vector3(0.0, edge_elevation, PORTAL_Z - 0.16),
			Vector3(9.0, 0.12, 0.06),
			_materials["cyan"],
			false
		)
	for chevron_index in 6:
		var chevron_x := lerpf(-4.1, 4.1, float(chevron_index) / 5.0)
		_rounded_box(
			portal,
			"PortalChevron",
			Vector3(chevron_x, 5.95, PORTAL_Z - 0.42),
			Vector3(0.9, 0.24, 0.05),
			_materials["orange_glow"],
			false,
			Vector3(0, 0, 26.0)
		)

	# The freight-control legend's mount. The door-side wall was split around the
	# StationDoor portal and never closed again above it: `InnerWallForward` stops
	# at z = 26.975 and `InnerWallAft` restarts at z = 31.025, leaving a 4.05 m by
	# 4.5 m hole with a 3.1 m door in the middle of it. This is the header that
	# should always have spanned it, and it is what `FREIGHT CONTROL` now reads off.
	var door_header := _rounded_box(
		self,
		"FreightControlDoorHeader",
		Vector3(16.3, 3.85, 29.0),
		Vector3(0.42, 1.3, 4.05),
		_materials["ceramic"]
	)
	_register_handling_fixture(door_header, &"freight-control-door-header")
	_rounded_box(
		self,
		"FreightControlSignFascia",
		Vector3(16.0, 3.95, 29.0),
		Vector3(0.2, 0.7, 3.4),
		_materials["deep_blue"],
		false
	)


## Marked handling zones and securing points: the painted, bollarded ground plane
## a 26 m freighter is worked on.
##
## Every collision-backed piece here stands outside the protected hull envelope in
## x, which is exactly the point — the wide empty middle of the apron is reserved
## floor, and until now nothing on the deck said so.
func _build_handling_zones() -> void:
	var zones := Node3D.new()
	zones.name = "HandlingZones"
	add_child(zones)

	# Envelope bollards. The parked hull's protected width is 23.0 m; these stand
	# at x = +/-12.4 with a 0.19 m radius, so the whole line clears the envelope by
	# 0.71 m and the published 3.4 m cargo-transfer lane at z = 29.0 by 1.3 m.
	var bollard_z := [13.5, 20.0, 26.5, 33.0, 39.5]
	for side in [-1.0, 1.0]:
		var side_tag := "Port" if side < 0.0 else "Starboard"
		for index in bollard_z.size():
			var z_position := float(bollard_z[index])
			# Named per station side and index. Godot renames same-named siblings,
			# so a set built under one shared name can only ever be found as one
			# node by name and an audit that walks by name sees a fraction of it.
			var bollard := _cylinder(
				zones,
				"EnvelopeBollard%s%02d" % [side_tag, index + 1],
				Vector3(side * 12.4, 0.475, z_position),
				0.19,
				0.95,
				_materials["orange"]
			)
			_register_handling_fixture(bollard, &"envelope-bollard")
			_cylinder(
				zones,
				"EnvelopeBollardCollar%s%02d" % [side_tag, index + 1],
				Vector3(side * 12.4, 0.72, z_position),
				0.23,
				0.14,
				_materials["orange_glow"],
				false
			)

	# Securing points. Recessed lashing rings on the hull tie-down line, drawn
	# flush: a ring standing proud of a working apron is a trip hazard, and one
	# hovering over it is the defect this module has been clearing all day.
	for side in [-1.0, 1.0]:
		var side_tag := "Port" if side < 0.0 else "Starboard"
		for index in 4:
			var z_position := 16.0 + float(index) * 8.0
			_rounded_box(
				zones,
				"LashingPlate%s%02d" % [side_tag, index + 1],
				Vector3(side * 10.6, 0.025, z_position),
				Vector3(0.62, 0.05, 0.62),
				_materials["graphite"],
				false
			)
			_torus(
				zones,
				"LashingRing%s%02d" % [side_tag, index + 1],
				Vector3(side * 10.6, 0.075, z_position),
				0.16,
				0.24,
				_materials["ceramic"],
				Vector3.ZERO
			)

	_build_staging_bay(zones, "Port", STAGING_BAY_PORT_CENTER)
	_build_staging_bay(zones, "Starboard", STAGING_BAY_STARBOARD_CENTER)

	# Chocks left where a handling crew would leave them.
	var chock_layout := [
		["Port", Vector3(-12.9, 0.11, 17.5)],
		["Port", Vector3(-12.9, 0.11, 36.0)],
		["Starboard", Vector3(12.9, 0.11, 22.5)],
		["Starboard", Vector3(12.9, 0.11, 35.0)],
	]
	for index in chock_layout.size():
		var entry: Array = chock_layout[index]
		_rounded_box(
			zones,
			"WheelChock%s%02d" % [entry[0] as String, index + 1],
			entry[1] as Vector3,
			Vector3(0.5, 0.22, 0.34),
			_materials["rubber"],
			false
		)


## One painted, hatched handling bay: border strips and diagonal hatching, all of
## it drawn flat against the apron plate it marks rather than hovering over it.
func _build_staging_bay(parent: Node3D, side_tag: String, center: Vector3) -> void:
	var half := STAGING_BAY_HALF_SIZE
	var strip_elevation := 0.026
	var strip_size := 0.052
	for edge in [-1.0, 1.0]:
		_rounded_box(
			parent,
			"StagingBayEdgeX%s%s" % [side_tag, "A" if edge < 0.0 else "B"],
			center + Vector3(edge * half.x, strip_elevation, 0.0),
			Vector3(0.18, strip_size, half.y * 2.0),
			_materials["orange_glow"],
			false
		)
		_rounded_box(
			parent,
			"StagingBayEdgeZ%s%s" % [side_tag, "A" if edge < 0.0 else "B"],
			center + Vector3(0.0, strip_elevation, edge * half.y),
			Vector3(half.x * 2.0, strip_size, 0.18),
			_materials["orange_glow"],
			false
		)
	for hatch_index in 3:
		var hatch_z := lerpf(-half.y * 0.6, half.y * 0.6, float(hatch_index) * 0.5)
		_rounded_box(
			parent,
			"StagingBayHatch%s%02d" % [side_tag, hatch_index + 1],
			center + Vector3(0.0, strip_elevation, hatch_z),
			Vector3(3.4, strip_size, 0.16),
			_materials["orange_glow"],
			false,
			Vector3(0, 42.0, 0)
		)


## Storage: what a freight berth keeps between ships.
##
## Racking that is actually decked and actually loaded, a locker bank with its own
## canopy, a gas-bottle frame, a drum pallet and a skip. Every stacked item is
## seated 0.010 m into whatever carries it, the same bearing rule the eight tagged
## rack crates were repaired to.
func _build_freight_stores() -> void:
	var stores := Node3D.new()
	stores.name = "FreightStores"
	add_child(stores)

	# The three existing rack bays had beams and nothing on them. Decking is laid
	# on the beam crowns (0.96 and 2.41) at x = -21.15, inboard of the module's own
	# under-deck service dressing and outboard of the tagged crates at x = -20.35.
	var rack_bay_z := [18.5, 28.0, 37.5]
	for bay_index in rack_bay_z.size():
		var bay_z := float(rack_bay_z[bay_index])
		var lower_deck := _rounded_box(
			stores,
			"RackDeckLower%02d" % (bay_index + 1),
			Vector3(-21.15, 0.99, bay_z),
			Vector3(1.3, 0.08, 6.2),
			_materials["orange"]
		)
		_register_handling_fixture(lower_deck, &"rack-deck")
		var upper_deck := _rounded_box(
			stores,
			"RackDeckUpper%02d" % (bay_index + 1),
			Vector3(-21.15, 2.44, bay_z),
			Vector3(1.3, 0.08, 6.2),
			_materials["orange"]
		)
		_register_handling_fixture(upper_deck, &"rack-deck")
		_rounded_box(
			stores,
			"RackBayPlaque%02d" % (bay_index + 1),
			# Bedded into the upper rack beam's outboard face. Hung at mid-bay height
			# it read as a plate floating between two beams and touching neither.
			Vector3(-20.99, 2.25, bay_z),
			Vector3(0.05, 0.3, 0.9),
			_materials["cyan"],
			false
		)
		for slot in [-1.0, 1.0]:
			var slot_tag := "A" if slot < 0.0 else "B"
			var stored_crate := _rounded_box(
				stores,
				"RackStoredCrate%02d%s" % [bay_index + 1, slot_tag],
				Vector3(-21.15, 1.33, bay_z + slot * 1.8),
				Vector3(1.1, 0.62, 1.5),
				_materials["ceramic_warm"]
			)
			_register_handling_fixture(stored_crate, &"rack-stored-crate")
			var stored_drum := _cylinder(
				stores,
				"RackStoredDrum%02d%s" % [bay_index + 1, slot_tag],
				Vector3(-21.15, 2.86, bay_z + slot * 1.7),
				0.26,
				0.78,
				_materials["steel_blue"]
			)
			_register_handling_fixture(stored_drum, &"rack-stored-drum")

	# Locker bank on the starboard outbound flank, with a canopy resting on it.
	for locker_index in 5:
		var locker_z := 39.5 + float(locker_index) * 1.3
		var locker := _rounded_box(
			stores,
			"StoresLocker%02d" % (locker_index + 1),
			Vector3(14.2, 1.1, locker_z),
			Vector3(2.6, 2.2, 1.24),
			_materials["ceramic"]
		)
		_register_handling_fixture(locker, &"stores-locker")
		_rounded_box(
			stores,
			"StoresLockerDoor%02d" % (locker_index + 1),
			Vector3(12.92, 1.12, locker_z),
			Vector3(0.05, 1.9, 1.06),
			_materials["steel_blue"],
			false
		)
		_rounded_box(
			stores,
			"StoresLockerHandle%02d" % (locker_index + 1),
			Vector3(12.9, 1.12, locker_z + 0.4),
			Vector3(0.07, 0.34, 0.08),
			_materials["orange"],
			false
		)
	var canopy := _rounded_box(
		stores,
		"StoresCanopy",
		Vector3(14.2, 2.27, 42.1),
		Vector3(3.1, 0.16, 6.6),
		_materials["ceramic_warm"]
	)
	_register_handling_fixture(canopy, &"stores-canopy")

	# Gas-bottle frame on the port outbound flank.
	var bottle_base := _rounded_box(
		stores,
		"GasBottleBase",
		Vector3(-13.6, 0.08, 42.7),
		Vector3(2.6, 0.16, 1.1),
		_materials["graphite"]
	)
	_register_handling_fixture(bottle_base, &"gas-bottle-base")
	for side in [-1.0, 1.0]:
		var upright := _cylinder(
			stores,
			"GasBottleUpright%s" % ("Port" if side < 0.0 else "Starboard"),
			Vector3(-13.6 + side * 1.2, 0.91, 42.95),
			0.08,
			1.5,
			_materials["steel_blue"]
		)
		_register_handling_fixture(upright, &"gas-bottle-upright")
	var bottle_rail := _rounded_box(
		stores,
		"GasBottleRail",
		Vector3(-13.6, 1.2, 42.95),
		Vector3(2.5, 0.1, 0.1),
		_materials["orange"]
	)
	_register_handling_fixture(bottle_rail, &"gas-bottle-rail")
	for bottle_index in 6:
		var bottle := _cylinder(
			stores,
			"GasBottle%02d" % (bottle_index + 1),
			Vector3(-14.6 + float(bottle_index) * 0.4, 0.835, 42.5),
			0.16,
			1.35,
			_materials["cyan_dim"] if bottle_index % 2 == 0 else _materials["red"]
		)
		_register_handling_fixture(bottle, &"gas-bottle")

	# Drum pallet.
	var drum_pallet := _rounded_box(
		stores,
		"DrumPallet",
		Vector3(-13.6, 0.08, 45.2),
		Vector3(2.0, 0.16, 2.0),
		_materials["graphite"]
	)
	_register_handling_fixture(drum_pallet, &"drum-pallet")
	for drum_index in 4:
		var drum_x := -14.1 + float(drum_index % 2) * 1.0
		var drum_z := 44.7 + float(drum_index / 2) * 1.0
		var drum := _cylinder(
			stores,
			"PalletDrum%02d" % (drum_index + 1),
			Vector3(drum_x, 0.58, drum_z),
			0.28,
			0.86,
			_materials["orange"]
		)
		_register_handling_fixture(drum, &"pallet-drum")

	# Skip. Freight berths generate dunnage, and nothing here took it away.
	var skip := _rounded_box(
		stores,
		"DunnageSkip",
		Vector3(-13.7, 0.575, 23.4),
		Vector3(2.4, 1.15, 3.2),
		_materials["steel_blue"]
	)
	_register_handling_fixture(skip, &"dunnage-skip")
	_rounded_box(stores, "DunnageSkipRim", Vector3(-13.7, 1.19, 23.4), Vector3(2.55, 0.12, 3.35), _materials["graphite"], false)
	_rounded_box(stores, "DunnageSkipBand", Vector3(-13.7, 0.85, 23.4), Vector3(2.45, 0.16, 3.25), _materials["orange_glow"], false)


## Loading apparatus: how freight and crew get between the apron and the craft.
##
## The boarding stair is built as seven solid blocks rather than a flight of
## cantilevered treads, which makes each step its own floor-to-tread bearing and
## removes any chance of a tread hanging off nothing.
func _build_loading_apparatus() -> void:
	var apparatus := Node3D.new()
	apparatus.name = "LoadingApparatus"
	add_child(apparatus)

	for step_index in 7:
		var step_height := 2.14 - 0.30 * float(step_index)
		var step := _rounded_box(
			apparatus,
			"BoardingStep%02d" % (step_index + 1),
			Vector3(-13.6, step_height * 0.5, 28.83 - 0.34 * float(step_index)),
			Vector3(2.0, step_height, 0.34),
			_materials["deck_grip"]
		)
		_register_handling_fixture(step, &"boarding-step")

	var platform := _rounded_box(
		apparatus,
		"BoardingPlatformDeck",
		Vector3(-13.6, 2.06, 30.175),
		Vector3(3.4, 0.16, 2.45),
		_materials["deck"]
	)
	_register_handling_fixture(platform, &"boarding-platform")
	for leg_index in 4:
		var leg_x := -15.0 + float(leg_index % 2) * 2.8
		var leg_z := 29.5 + float(leg_index / 2) * 1.5
		var leg := _cylinder(
			apparatus,
			"BoardingLeg%02d" % (leg_index + 1),
			Vector3(leg_x, 0.995, leg_z),
			0.11,
			1.99,
			_materials["steel_blue"]
		)
		_register_handling_fixture(leg, &"boarding-leg")
	# Handrail on the three closed sides; the fourth faces the craft and is the
	# working edge. Collision-backed, because a rail a player walks through is the
	# same lie as a mast a tow tractor drives through.
	for post_index in 4:
		var post_x := -15.0 + float(post_index % 2) * 2.8
		var post_z := 29.15 + float(post_index / 2) * 2.1
		var post := _cylinder(
			apparatus,
			"BoardingRailPost%02d" % (post_index + 1),
			Vector3(post_x, 2.665, post_z),
			0.055,
			1.05,
			_materials["ceramic"]
		)
		_register_handling_fixture(post, &"boarding-rail-post")
	var outer_rail := _rounded_box(
		apparatus,
		"BoardingRailOuter",
		Vector3(-15.0, 3.14, 30.2),
		Vector3(0.09, 0.09, 2.35),
		_materials["ceramic"]
	)
	_register_handling_fixture(outer_rail, &"boarding-rail")
	for rail_index in 2:
		var rail := _rounded_box(
			apparatus,
			"BoardingRailEnd%02d" % (rail_index + 1),
			Vector3(-13.6, 3.14, 29.15 + float(rail_index) * 2.1),
			Vector3(2.8, 0.09, 0.09),
			_materials["ceramic"]
		)
		_register_handling_fixture(rail, &"boarding-rail")
	_rounded_box(apparatus, "BoardingToeBoard", Vector3(-15.15, 2.26, 30.175), Vector3(0.1, 0.24, 2.45), _materials["orange"], false)

	# Service reels on the transfer-lane side, clear of the 3.4 m lane itself.
	for reel_index in 2:
		var reel_z := 24.0 + float(reel_index) * 9.5
		var stand := _rounded_box(
			apparatus,
			"HoseReelStand%02d" % (reel_index + 1),
			Vector3(13.9, 0.45, reel_z),
			Vector3(0.5, 0.9, 1.2),
			_materials["graphite"]
		)
		_register_handling_fixture(stand, &"hose-reel-stand")
		var drum := _cylinder(
			apparatus,
			"HoseReelDrum%02d" % (reel_index + 1),
			Vector3(13.9, 1.05, reel_z),
			0.42,
			0.7,
			_materials["orange"],
			true,
			Vector3(0, 0, 90)
		)
		_register_handling_fixture(drum, &"hose-reel-drum")

	# A hand pallet truck parked against the port flank.
	var truck := _rounded_box(
		apparatus,
		"PalletTruckBody",
		Vector3(-13.2, 0.16, 34.5),
		Vector3(0.55, 0.32, 1.5),
		_materials["orange"]
	)
	_register_handling_fixture(truck, &"pallet-truck")
	var truck_handle := _cylinder(
		apparatus,
		"PalletTruckHandle",
		Vector3(-13.2, 0.78, 33.85),
		0.05,
		1.0,
		_materials["graphite"],
		true,
		Vector3(20, 0, 0)
	)
	_register_handling_fixture(truck_handle, &"pallet-truck-handle")

	# Staged freight in both painted bays: pallet, main crate, top crate. These are
	# deliberately not tagged `station_cargo_unit` - the eight rack units remain the
	# module's cargo roster, and this is the transient staging a working bay holds.
	_build_staged_stack(apparatus, "Port", STAGING_BAY_PORT_CENTER + Vector3(0.0, 0.0, -2.4))
	_build_staged_stack(apparatus, "Starboard", STAGING_BAY_STARBOARD_CENTER + Vector3(0.0, 0.0, 2.4))


## One staged pallet stack. Each item is buried 0.010 m into whatever carries it.
func _build_staged_stack(parent: Node3D, side_tag: String, base: Vector3) -> void:
	var pallet := _rounded_box(
		parent,
		"StagedPallet%s" % side_tag,
		base + Vector3(0.0, 0.08, 0.0),
		Vector3(2.6, 0.16, 2.2),
		_materials["graphite"]
	)
	_register_handling_fixture(pallet, &"staged-pallet")
	var lower := _rounded_box(
		parent,
		"StagedCrateLower%s" % side_tag,
		base + Vector3(0.0, 0.80, 0.0),
		Vector3(2.2, 1.3, 1.9),
		_materials["ceramic"]
	)
	_register_handling_fixture(lower, &"staged-crate")
	var upper := _rounded_box(
		parent,
		"StagedCrateUpper%s" % side_tag,
		base + Vector3(0.1, 1.89, 0.0),
		Vector3(1.6, 0.9, 1.5),
		_materials["orange"]
	)
	_register_handling_fixture(upper, &"staged-crate")
	for strap_side in [-1.0, 1.0]:
		_rounded_box(
			parent,
			"StagedStrap%s%s" % [side_tag, "A" if strap_side < 0.0 else "B"],
			base + Vector3(strap_side * 0.7, 0.8, 0.0),
			Vector3(0.14, 1.32, 1.98),
			_materials["deep_blue"],
			false
		)


## Gantry access. The module's one piece of articulated equipment stood 13 m over
## the apron with no way to reach it and no cab to work it from.
##
## Everything here is above the protected hull envelope's 9.75 m ceiling, so the
## whole level is legal structure over a parked craft. The catwalk laps the crane
## header, the landing laps the catwalk, the ladder reaches the landing and the
## cab is bolted to the port gantry leg - one support chain, no free-floating link.
func _build_gantry_access() -> void:
	var access := Node3D.new()
	access.name = "GantryAccess"
	add_child(access)

	var catwalk := _rounded_box(
		access,
		"GantryCatwalkDeck",
		Vector3(0.0, CATWALK_DECK_ELEVATION, CATWALK_CENTER_Z),
		Vector3(25.4, 0.12, 1.4),
		_materials["deck_grip"]
	)
	_register_handling_fixture(catwalk, &"gantry-catwalk")
	var landing := _rounded_box(
		access,
		"GantryCatwalkLanding",
		Vector3(-13.75, CATWALK_DECK_ELEVATION, CATWALK_CENTER_Z),
		Vector3(2.4, 0.12, 1.4),
		_materials["deck_grip"]
	)
	_register_handling_fixture(landing, &"gantry-catwalk-landing")

	for edge_index in 2:
		var edge_z := CATWALK_CENTER_Z - 0.6 + float(edge_index) * 1.2
		var edge_tag := "Fore" if edge_index == 0 else "Aft"
		for post_index in 5:
			var post_x := lerpf(-11.5, 11.5, float(post_index) * 0.25)
			var post := _cylinder(
				access,
				"CatwalkRailPost%s%02d" % [edge_tag, post_index + 1],
				Vector3(post_x, CATWALK_DECK_ELEVATION + 0.56, edge_z),
				0.05,
				1.0,
				_materials["ceramic"]
			)
			_register_handling_fixture(post, &"catwalk-rail-post")
		var top_rail := _cylinder(
			access,
			"CatwalkTopRail%s" % edge_tag,
			Vector3(0.0, CATWALK_DECK_ELEVATION + 0.99, edge_z),
			0.05,
			25.0,
			_materials["ceramic"],
			true,
			Vector3(0, 0, 90)
		)
		_register_handling_fixture(top_rail, &"catwalk-rail")
		_rounded_box(
			access,
			"CatwalkToeBoard%s" % edge_tag,
			Vector3(0.0, CATWALK_DECK_ELEVATION + 0.13, edge_z + (0.04 if edge_index == 0 else -0.04)),
			Vector3(25.4, 0.14, 0.06),
			_materials["orange"],
			false
		)

	# Caged ladder up the port gantry leg. Stringers run deck to landing.
	for stringer_index in 2:
		var stringer_z := CATWALK_CENTER_Z - 0.4 + float(stringer_index) * 0.9
		var stringer := _cylinder(
			access,
			"CatwalkLadderStringer%02d" % (stringer_index + 1),
			Vector3(-14.62, 6.6, stringer_z),
			0.05,
			13.2,
			_materials["steel_blue"]
		)
		_register_handling_fixture(stringer, &"catwalk-ladder-stringer")
	for rung_index in 12:
		_rounded_box(
			access,
			"CatwalkLadderRung%02d" % (rung_index + 1),
			Vector3(-14.62, 0.6 + float(rung_index) * 1.0, CATWALK_CENTER_Z + 0.05),
			Vector3(0.08, 0.05, 0.9),
			_materials["ceramic"],
			false
		)
	for hoop_index in 4:
		_torus(
			access,
			"CatwalkLadderHoop%02d" % (hoop_index + 1),
			Vector3(-14.62, 3.0 + float(hoop_index) * 3.0, CATWALK_CENTER_Z + 0.05),
			0.42,
			0.52,
			_materials["steel_blue"],
			Vector3(0, 0, 90)
		)

	# Crane cab, bracketed off the outboard face of the port gantry leg. Kept
	# forward of the leg and below the knee brace: the knee runs diagonally from
	# (x -14.33, y 12.04) to (x -11.67, y 10.26) at z 26.65 .. 27.35, so a cab hung
	# on the leg at that z would have the brace passing straight through it. The
	# bracket is what carries it, and it is the only piece that touches the leg.
	var cab := _rounded_box(
		access,
		"CraneControlCab",
		Vector3(-15.0, 10.70, 25.6),
		Vector3(1.7, 1.7, 1.8),
		_materials["ceramic"]
	)
	_register_handling_fixture(cab, &"crane-control-cab")
	var cab_bracket := _rounded_box(
		access,
		"CraneControlCabBracket",
		Vector3(-14.6, 11.30, 26.9),
		Vector3(0.5, 0.35, 1.0),
		_materials["steel_blue"]
	)
	_register_handling_fixture(cab_bracket, &"crane-control-cab-bracket")
	var cab_glass := _rounded_box(
		access,
		"CraneControlCabGlass",
		Vector3(-14.19, 10.90, 25.6),
		Vector3(0.06, 1.0, 1.5),
		_materials["glass"],
		false
	)
	cab_glass.set_meta("station_glazing", true)
	_rounded_box(
		access,
		"CraneControlCabFloorPlate",
		Vector3(-15.0, 9.90, 25.6),
		Vector3(1.9, 0.1, 2.0),
		_materials["orange"],
		false
	)
	_rounded_box(
		access,
		"GantryCableTray",
		Vector3(0.0, 12.86, CRANE_CENTER_Z - 0.45),
		Vector3(25.0, 0.14, 0.24),
		_materials["graphite"],
		false
	)


## Freight-office annex on the apron: the kiosk a manifest is signed at and the
## load-check plate a lift is weighed on.
func _build_dispatch_annex() -> void:
	var annex := Node3D.new()
	annex.name = "FreightDispatchAnnex"
	add_child(annex)

	var kiosk := _rounded_box(
		annex,
		"ManifestKiosk",
		Vector3(12.6, 0.65, 25.6),
		Vector3(0.9, 1.3, 0.75),
		_materials["ceramic"]
	)
	_register_handling_fixture(kiosk, &"manifest-kiosk")
	_rounded_box(
		annex,
		"ManifestKioskScreen",
		Vector3(12.6, 1.42, 25.35),
		Vector3(0.7, 0.5, 0.06),
		_materials["screen"],
		false,
		Vector3(-18, 0, 0)
	)

	_rounded_box(
		annex,
		"LoadCheckPlate",
		Vector3(-13.6, 0.025, 38.6),
		Vector3(3.2, 0.05, 3.2),
		_materials["deck_grip"],
		false
	)
	for corner_index in 4:
		var corner_x := -13.6 + (-1.45 if corner_index % 2 == 0 else 1.45)
		var corner_z := 38.6 + (-1.45 if corner_index / 2 == 0 else 1.45)
		_rounded_box(
			annex,
			"LoadCheckCorner%02d" % (corner_index + 1),
			Vector3(corner_x, 0.045, corner_z),
			Vector3(0.5, 0.09, 0.5),
			_materials["orange_glow"],
			false
		)
	var readout_post := _cylinder(
		annex,
		"LoadCheckReadoutPost",
		Vector3(-15.4, 0.75, 38.6),
		0.09,
		1.5,
		_materials["steel_blue"]
	)
	_register_handling_fixture(readout_post, &"load-check-post")
	_rounded_box(
		annex,
		"LoadCheckReadoutHead",
		Vector3(-15.4, 1.62, 38.6),
		Vector3(0.5, 0.34, 0.12),
		_materials["screen"],
		false
	)


func _register_handling_fixture(fixture: Node3D, fixture_class: StringName) -> void:
	fixture.set_meta("station_handling_fixture", true)
	fixture.set_meta("handling_fixture_class", fixture_class)
	fixture.set_meta("evidence_status", EVIDENCE_STATUS)
	_handling_fixtures.append(fixture)


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

	# The control room's single fill is the same cyan as everything else in it, so
	# the room was one hue. This is a low sodium-temperature desk lamp under the
	# fill: it lands on the console run and the floor, leaves the cool fill
	# dominant overhead, and gives the enclosed volume the two colour temperatures
	# a working room actually has. It is deliberately below the fill in energy —
	# the station stays cool, the warmth is the local, human-scale layer.
	var control_desk_lamp := OmniLight3D.new()
	control_desk_lamp.name = "FreightControlDeskLamp"
	control_desk_lamp.position = Vector3(18.4, 1.35, 29.6)
	control_desk_lamp.light_color = Color("f6c286")
	control_desk_lamp.light_energy = 0.62
	control_desk_lamp.omni_range = 5.0
	control_desk_lamp.omni_attenuation = 2.0
	control_desk_lamp.shadow_enabled = false
	control_desk_lamp.distance_fade_enabled = true
	control_desk_lamp.distance_fade_begin = PRACTICAL_FADE_BEGIN
	control_desk_lamp.distance_fade_length = PRACTICAL_FADE_LENGTH
	control_desk_lamp.set_meta("fixture_practical", true)
	presentation.add_child(control_desk_lamp)

	# Each legend gets the wash its own colour implies. The two amber deck legends
	# are the module's warm cues and now put warm light on the apron plate they
	# are painted on; the two cyan legends wash the structures they are mounted to.
	# Nothing about the legend colours themselves moves — the cue palette and its
	# amber/cyan separation are unchanged, only whether the cue lights anything.
	# REGEN-DECK-002's freight twin. The module legend was authored at z = 7.9,
	# y = 4.6 — 1.0 m past the far edge of `ConnectionDeckC` and 4.6 m above the
	# apron, mounted to nothing at all, which is the same "legend hanging in
	# mid-air" the registry pods were repaired for. It now reads off the physical
	# board of the approach portal built above it, so the glyphs stand on drawn
	# steel. `FREIGHT CONTROL` had the same problem 0.71 m clear of its own wall and
	# is bedded onto the sign fascia the portal builder mounts there. The two deck
	# legends were always painted on the apron and do not move.
	_label(presentation, "MUDDS FREIGHT NODE  //  JOVIAN", Vector3(0, 4.92, PORTAL_Z - 0.20), 0.62, Color("bffff6"), Vector3(0, 180, 0))
	_sign_practical(presentation, "FreightNodeSignWash", Vector3(0.0, 4.35, PORTAL_Z - 0.55), Color("8fe6dd"), 0.5, 5.0)
	_label(presentation, "BERTH F-01", Vector3(0, 0.14, 9.8), 0.46, Color("ffb45b"), Vector3(-90, 0, 0))
	_sign_practical(presentation, "BerthLegendWash", Vector3(0.0, 0.55, 9.8), Color("f7b866"), 0.44, 4.4)
	_label(presentation, "FREIGHT CONTROL", Vector3(16.05, 3.95, 29.0), 0.42, Color("8df2ed"), Vector3(0, -90, 0))
	_sign_practical(presentation, "ControlSignWash", Vector3(15.62, 3.7, 29.0), Color("8df2ed"), 0.4, 3.6)
	_label(presentation, "KEEP TRANSFER LANE CLEAR", Vector3(12.7, 0.13, 29.0), 0.3, Color("ffb45b"), Vector3(-90, 0, 90))
	_sign_practical(presentation, "TransferLaneWash", Vector3(12.7, 0.5, 29.0), Color("f7b866"), 0.36, 3.8)

	# The two new handling bays and the stores bank are legends in their own right.
	# Each keeps the module's rule that a lit cue has to light something: a Label3D
	# is an unlit quad, so each carries the small tinted wash its own colour implies.
	_label(presentation, "STAGING A", STAGING_BAY_PORT_CENTER + Vector3(0.0, 0.14, 0.0), 0.34, Color("ffb45b"), Vector3(-90, 0, 0))
	_sign_practical(presentation, "StagingBayPortWash", STAGING_BAY_PORT_CENTER + Vector3(0.0, 0.55, 0.0), Color("f7b866"), 0.4, 4.2)
	_label(presentation, "STAGING B", STAGING_BAY_STARBOARD_CENTER + Vector3(0.0, 0.14, 0.0), 0.34, Color("ffb45b"), Vector3(-90, 0, 0))
	_sign_practical(presentation, "StagingBayStarboardWash", STAGING_BAY_STARBOARD_CENTER + Vector3(0.0, 0.55, 0.0), Color("f7b866"), 0.4, 4.2)
	_label(presentation, "FREIGHT STORES", Vector3(12.86, 1.78, 42.1), 0.3, Color("8df2ed"), Vector3(0, -90, 0))

	# Two task practicals for the working ends of the yard. Both are warm, both are
	# shadowless, both sit under the module's 5.5 m practical ceiling, and both are
	# mounted on real structure: the rack aisle lamp under the top rack beam, the
	# stores lamp under the locker canopy.
	_task_practical(presentation, "CargoRackAisleLamp", Vector3(-19.7, 2.85, 28.0), Color("ffd7a0"), 1.05, 8.5)
	_task_practical(presentation, "FreightStoresBayLamp", Vector3(13.3, 2.1, 42.1), Color("ffd7a0"), 0.9, 7.0)
	_task_practical(presentation, "BoardingPlatformLamp", Vector3(-13.6, 3.05, 30.2), Color("ffe0b4"), 0.85, 6.5)


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
	# LENS-HOUSING-001. All eighteen guide lenses were bare 0.26 m spheres hung
	# over the apron with nothing under them — 0.220 m of clear air below the twelve
	# edge lenses and 0.120 m below the six centreline ones. They are the module's
	# densest population and the first thing a walking player passes, so eighteen
	# balls hovering at shin height is exactly the reported complaint at its most
	# repeated. Each lens now sits in a drawn housing that runs from the deck plane
	# up into the lens body. Not one light, lens position, colour, energy, range or
	# falloff moves: the fix is the missing fitting, not the fitting's aim.
	var housing_height := maxf(position_value.y - 0.05, 0.05)
	var housing := _cylinder(
		parent,
		"DockGuideHousing",
		Vector3(position_value.x, housing_height * 0.5, position_value.z),
		0.17,
		housing_height,
		_materials["graphite"],
		false
	)
	housing.set_meta("station_fixture_housing", true)

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
	# Distance fade only. An attenuation curve was tried here and reverted: raising
	# it to 1.55 steepened the falloff on all eighteen existing apron guide lights
	# at once and measured as a real loss — `05_jovian_freight_operations` lost
	# 0.25 of structural sigma, which is most of what this module gained elsewhere.
	# The pools these lay on the apron are the module's best-lit feature and their
	# authored falloff stays exactly as it was.
	light.distance_fade_enabled = true
	light.distance_fade_begin = PRACTICAL_FADE_BEGIN
	light.distance_fade_length = PRACTICAL_FADE_LENGTH
	parent.add_child(light, true)


## A sign's spill, as an actual light.
##
## The freight legends are Label3D, which is unlit type on a transparent quad: it
## is the purest case of the defect this pass addresses, because a Label3D
## cannot illuminate anything at all no matter what modulate it carries. These
## small omnis give each legend a wash on the plate behind it, tinted to the
## legend's own colour, so a lit sign reads as a lit sign rather than as decal
## text floating in front of dark steel. Shadowless, steeply attenuated, and
## faded out past the station so the whole-lattice overview pays for none of
## them. The fade distance is measured, not chosen: at the 22 m it was first
## given, these were off in every rendered framing of this module.
func _sign_practical(
		parent: Node3D,
		node_name: String,
		position_value: Vector3,
		color: Color,
		energy: float,
		range_value: float
	) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = node_name
	light.position = position_value
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range_value
	light.omni_attenuation = 2.1
	light.shadow_enabled = false
	light.distance_fade_enabled = true
	light.distance_fade_begin = PRACTICAL_FADE_BEGIN
	light.distance_fade_length = PRACTICAL_FADE_LENGTH
	light.set_meta("fixture_practical", true)
	parent.add_child(light, true)
	return light


## A working light over a working part of the yard.
##
## Same contract as `_sign_practical` - shadowless, steeply attenuated, distance
## faded past the station so a whole-lattice overview pays for none of it - but
## these are task lights rather than sign washes, so they are warmer, wider and
## aimed at a surface a crew actually uses. Each is positioned under real drawn
## structure (the top rack beam, the stores canopy, the boarding platform rail),
## which is what keeps a practical from reading as a glow with no fitting.
func _task_practical(
		parent: Node3D,
		node_name: String,
		position_value: Vector3,
		color: Color,
		energy: float,
		range_value: float
	) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = node_name
	light.position = position_value
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range_value
	light.omni_attenuation = 1.6
	light.shadow_enabled = false
	light.distance_fade_enabled = true
	light.distance_fade_begin = PRACTICAL_FADE_BEGIN
	light.distance_fade_length = PRACTICAL_FADE_LENGTH
	light.set_meta("fixture_practical", true)
	parent.add_child(light, true)
	return light


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
