class_name JovianLightFreighter
extends HeroShip

## Evidence-bounded Jovian-class Light Freighter candidate.
##
## Creator-authored material (A3, page archived 2009-11-12) supports the class
## name and light-freighter role. No registered source shows a craft identified
## as Jovian: B4 records the label string alone, with no ledger frame anchor and
## no tied craft, so the Jovian name-to-model mapping is `unknown`.
## Every visible dimension, colour, access route, interior, system, hardpoint,
## and handling value in this component is a revisable modern interpretation.
## The cargo deck, passenger cabin, cockpit, and exterior ramp are one physical
## ship-local hierarchy; no detached or teleported interior is involved.

const SCHEMA_VERSION := 1
const CrewSeatRoleAuthorityType := preload("res://scripts/ships/crew_seat_role_authority.gd")
const CrewRoleGameplayProfileType := preload("res://scripts/fleet/crew_role_gameplay_profile.gd")
const ShipPerspectiveAudioBindingType := preload("res://scripts/audio/ship_perspective_audio_binding.gd")
const JovianCopilotNavigationAudioBindingType := preload("res://scripts/audio/jovian_copilot_navigation_audio_binding.gd")
const EVIDENCE_STATUS: StringName = &"provisional"
const EVIDENCE_SCOPE: StringName = &"name_and_role_only"
const NAME_TO_MODEL_STATUS: StringName = &"unknown"
const COMBAT_SOURCE_ID := 1103
const INTERIOR_SCHEMA_VERSION := 1
const PILOT_SEAT_ID: StringName = &"pilot_station"
const ENGINEER_SEAT_ID: StringName = &"passenger_port_01"
const COPILOT_SEAT_ID: StringName = &"co_pilot_station"
const COPILOT_ROLE_ID: StringName = &"copilot_navigation_support"
const COPILOT_NAVIGATION_CHANNEL: StringName = &"navigation_route"
const MAX_ENGINEER_COMPONENT_GENERATION := 1_000_000
const INTERIOR_BOUNDS := AABB(Vector3(-5.72, 0.0, -8.0), Vector3(11.44, 4.6, 17.25))
## Ship-local envelope a crew member may occupy while the freighter is under way.
##
## `modern_interpretation`. This is deliberately *not* `INTERIOR_BOUNDS`: the
## pressurised occupancy volume stops at the forward cabin bulkhead, while the
## physical cockpit deck runs on to z = -10.375, and a pilot who has just left
## the seat is standing on that deck. The box is the tight bounding box of the
## craft's walkable deck collision footprints — `tests/in_flight_cabin_test.gd`
## samples those colliders and asserts every one is enclosed — so nothing outside
## it is hull interior. Real walls do the room-by-room work; this is the outer
## anti-stranding envelope, and `PlayerController` confines the occupant to it,
## so the only way out of a flying Jovian is the pilot seat.
const CABIN_MOVEMENT_BOUNDS := AABB(Vector3(-5.75, 0.30, -10.4), Vector3(11.5, 4.5, 19.65))
## Standing pose just aft of the cockpit portal, on the shared passenger/cockpit
## deck plate. Facing aft, into the cabin the pilot has just been given.
const CABIN_STAND_LOCAL_ORIGIN := Vector3(0.0, 0.52, -7.35)
const CABIN_STAND_LOCAL_YAW := PI
## Secured freight in the hold: four tie-down stations, each carrying a pallet
## with a container strapped to it.
##
## Published as one roster because the drawn crate and the collider that stops a
## crew member walking through it are built from it in two different places, and
## the whole point of making the freight solid is that those two cannot disagree.
## Every value is ship-local; `WalkableInterior` and `CargoBay` are both identity
## children of the physical ship, so cargo-bay local coordinates are ship-local.
const CARGO_UNIT_ANCHORS: Array[Vector3] = [
	Vector3(-3.75, 0.64, 0.25),
	Vector3(3.75, 0.64, 0.25),
	Vector3(-3.75, 0.64, 5.55),
	Vector3(3.75, 0.64, 5.55),
]
const CARGO_PALLET_OFFSET_Y := 0.12
const CARGO_PALLET_SIZE := Vector3(2.25, 0.22, 2.5)
const CARGO_CONTAINER_OFFSET_Y := 0.9
const CARGO_CONTAINER_SIZE := Vector3(1.95, 1.3, 2.15)
const CARGO_RESTRAINT_OFFSET_Y := 1.62
const CARGO_RESTRAINT_BAND_Z: Array[float] = [-0.64, 0.64]
const CARGO_RESTRAINT_SIZE := Vector3(2.02, 0.08, 0.1)
const PASSENGER_SEAT_COUNT := 6
const PASSENGER_SEAT_BASE_SIZE := Vector3(0.72, 0.2, 0.82)
const PASSENGER_SEAT_BACK_SIZE := Vector3(0.72, 0.95, 0.16)
const PASSENGER_SEAT_HARNESS_SIZE := Vector3(0.13, 0.72, 0.04)
const PASSENGER_CABIN_LIGHT_STRIP_SIZE := Vector3(0.04, 0.12, 3.55)

# Phase 9 allocation boundary. The five dorsal ribs each retain five ordinary
# MeshInstance3D curve joints and therefore all 25 authored draw submissions.
# Their geometry recipe and structure material are exact, so those nodes share
# one immutable SphereMesh instead of retaining 25 indistinguishable resources.
const DORSAL_CARGO_RIB_COUNT := 5
const DORSAL_CARGO_RIB_JOINTS_PER_RIB := 5
const DORSAL_CARGO_RIB_JOINT_COPY_COUNT := (
	DORSAL_CARGO_RIB_COUNT * DORSAL_CARGO_RIB_JOINTS_PER_RIB
)
const DORSAL_CARGO_RIB_JOINT_RADIUS := 0.095
const DORSAL_CARGO_RIB_JOINT_RADIAL_SEGMENTS := 24
const DORSAL_CARGO_RIB_JOINT_RINGS := 12
const DORSAL_CARGO_RIB_JOINT_XY: Array[Vector2] = [
	Vector2(-5.55, 4.28),
	Vector2(-3.7, 4.72),
	Vector2(0.0, 4.9),
	Vector2(3.7, 4.72),
	Vector2(5.55, 4.28),
]

# The three shoulder service rails retain their exact Node3D roots, seven
# ordinary MeshInstance3D joints, and seven surface submissions. The joint
# recipe and teal material are identical, so only the immutable SphereMesh
# resource is shared.
const SHOULDER_RAIL_JOINT_COPY_COUNT := 7
const SHOULDER_RAIL_JOINT_RADIUS := 0.13
const SHOULDER_RAIL_JOINT_RADIAL_SEGMENTS := 24
const SHOULDER_RAIL_JOINT_RINGS := 12
const SHOULDER_RAIL_NAMES: Array[StringName] = [
	&"PortForwardShoulderRail",
	&"PortAftShoulderRail",
	&"StarboardShoulderRail",
]
const SHOULDER_RAIL_JOINT_POSITIONS: Array[Array] = [
	[Vector3(-7.55, 3.2, -4.8), Vector3(-7.8, 3.34, 0.95)],
	[Vector3(-7.78, 3.3, 5.48), Vector3(-7.5, 3.1, 8.7)],
	[
		Vector3(7.55, 3.2, -4.8),
		Vector3(7.82, 3.35, 1.0),
		Vector3(7.5, 3.1, 8.7),
	],
]

# Four interior cargo frames retain their exact roots, 20 ordinary named joint
# nodes, and 20 surface submissions inside the moving ship hierarchy. Their
# hull-cool geometry recipe is identical, so the immutable SphereMesh resource
# is shared without batching or moving any authored renderer node.
const CARGO_FRAME_COUNT := 4
const CARGO_FRAME_JOINTS_PER_FRAME := 5
const CARGO_FRAME_JOINT_COPY_COUNT := CARGO_FRAME_COUNT * CARGO_FRAME_JOINTS_PER_FRAME
const CARGO_FRAME_JOINT_RADIUS := 0.085
const CARGO_FRAME_JOINT_RADIAL_SEGMENTS := 24
const CARGO_FRAME_JOINT_RINGS := 12
const CARGO_FRAME_START_Z := -1.7
const CARGO_FRAME_Z_STEP := 3.25
const CARGO_FRAME_JOINT_XY: Array[Vector2] = [
	Vector2(-5.35, 0.72),
	Vector2(-5.35, 4.15),
	Vector2(0.0, 4.48),
	Vector2(5.35, 4.15),
	Vector2(5.35, 0.72),
]

const PARKED_RENDER_BOUNDS := AABB(Vector3(-10.6, -1.36, -14.1), Vector3(19.1, 6.31, 28.55))
const FLIGHT_COLLISION_BOUNDS := AABB(Vector3(-10.45, -1.45, -13.9), Vector3(18.55, 6.2, 26.2))
const PROVISIONAL_NOTE := (
	"Creator-supported facts (A3 page text): Jovian-class Light Freighter name "
	+ "and light-freighter role. No registered source ties any visible craft to "
	+ "the Jovian name, so the name-to-model mapping is unknown. "
	+ "The displayed geometry, dimensions, colours, cargo and "
	+ "passenger interior, ramp, cockpit access, capacity, systems, weapons, "
	+ "materials, and handling are modern provisional interpretation; no "
	+ "authenticated historical silhouette mapping is claimed."
)

# Fleet readability palette. The Jovian's name-to-model mapping is unknown and
# its palette is listed among its unknowns in docs/research/ship_evidence_matrix.json,
# so these are freely chosen modern hull tints picked to separate the freighter
# from the rest of the fleet under normal and dichromatic vision. See
# tests/fleet_role_differentiation_test.gd for the frozen separation floors.
# HULL_COOL keeps its name because `hull_cool` is the craft's stable public
# material-family key, asserted by tests/fleet_pbr_test.gd; it now carries the
# subordinate shade of the same warm clay family rather than a cool grey.
const HULL_WARM := Color("e0ab74")
const HULL_COOL := Color("bd9270")
const JOVIAN_STRUCTURE := Color("283c42")
const JOVIAN_STRUCTURE_DARK := Color("0e2026")
const FREIGHT_TEAL := Color("35bbb5")
const FREIGHT_AMBER := Color("e9a844")
const CARGO_BLUE := Color("39798d")
const CABIN_CLOTH := Color("365259")
const DECK_GREY := Color("718084")
const ENGINE_AQUA := Color("70eee7")
const JOVIAN_NAV_RED := Color("ff635d")
const JOVIAN_NAV_GREEN := Color("70e995")

# Modern-provisional civilian defensive fit. These dimensions deliberately sit
# between the Arrow's light nose guns and gunship-scale hardware: broad mounts
# carry the visual load, while the short barrels end at the inherited firing
# markers and remain subordinate to the freighter hull.
const DEFENSIVE_TURRET_STATUS: StringName = &"modern_provisional"
const DEFENSIVE_TURRET_ROLE: StringName = &"freighter_defensive"
const DEFENSIVE_TURRET_MUZZLE_Z := -6.95
const DEFENSIVE_TURRET_BASE_RADIUS := 0.68
const DEFENSIVE_TURRET_BASE_HEIGHT := 0.38
const DEFENSIVE_TURRET_BARREL_RADIUS := 0.19
const DEFENSIVE_TURRET_BARREL_LENGTH := 1.55
const DEFENSIVE_TURRET_PART_SUFFIXES: Array[StringName] = [
	&"DefensiveTurretBase",
	&"DefensiveTurretRotationCollar",
	&"DefensiveTurretReceiver",
	&"DefensiveTurretBarrelShroud",
	&"DefensivePulseBarrel",
	&"DefensiveTurretMuzzleCollar",
	&"DefensiveTurretMuzzleLens",
]

var _jovian_built := false
var _jovian_visual: Node3D
var _jovian_materials: Dictionary = {}
var _walkable_interior: Node3D
var _cargo_bay: Node3D
var _passenger_cabin: Node3D
var _moving_interior_component: MovingInteriorFrame
var _occupant_volume: Area3D
var _interior_access_marker: Marker3D
var _interior_deck_marker: Marker3D
var _interior_exit_marker: Marker3D
var _cabin_stand_marker: Marker3D
var _interior_occupant_count := 0
var _cargo_hardpoints: Array[Marker3D] = []
var _passenger_seat_anchors: Array[Marker3D] = []
var _engine_plumes: Array[MeshInstance3D] = []
var _jovian_engine_lights: Array[OmniLight3D] = []
var _dorsal_cargo_rib_joint_mesh: SphereMesh
var _shoulder_rail_joint_mesh: SphereMesh
var _cargo_frame_joint_mesh: SphereMesh
var _passenger_seat_base_mesh: ArrayMesh
var _passenger_seat_back_mesh: ArrayMesh
var _passenger_seat_harness_mesh: ArrayMesh
var _passenger_cabin_light_strip_mesh: ArrayMesh
var _elapsed_jovian := 0.0
var _crew_role_authority: CrewSeatRoleAuthority
var _engineer_component_selection: Dictionary = {}
var _engineer_component_generation := 1
var _copilot_navigation_receipt: Dictionary = {}
var _copilot_navigation_generation := 1
var _ship_perspective_audio_binding: RefCounted
var _copilot_navigation_audio_binding: RefCounted

signal engineer_component_selected(component_id: StringName, component_generation: int, receipt: Dictionary)
signal engineer_component_cleared(component_id: StringName, component_generation: int, reason: StringName)
signal copilot_navigation_intent_accepted(receipt: Dictionary)
signal copilot_navigation_intent_cleared(generation: int, reason: StringName)


func _uses_torrent_reconstruction_presentation() -> bool:
	return false


func _enter_tree() -> void:
	super._enter_tree()
	if _ship_perspective_audio_binding != null:
		call_deferred("_rebind_jovian_perspective_audio")
	if _copilot_navigation_audio_binding != null:
		call_deferred("_rebind_copilot_navigation_audio")


func _ready() -> void:
	super._ready()
	_ship_perspective_audio_binding = ShipPerspectiveAudioBindingType.new()
	_copilot_navigation_audio_binding = JovianCopilotNavigationAudioBindingType.new()
	_copilot_navigation_audio_binding.attach()
	var perspective_result: Dictionary = _ship_perspective_audio_binding.bind(_ship_audio_rig)
	if bool(perspective_result.get("accepted", false)):
		camera_view_changed.connect(_on_jovian_camera_view_changed)
	else:
		_ship_perspective_audio_binding = null
	if not copilot_navigation_intent_cleared.is_connected(_on_copilot_navigation_audio_cleared):
		copilot_navigation_intent_cleared.connect(_on_copilot_navigation_audio_cleared)
	if not _jovian_built:
		_jovian_built = rebuild_variant_presentation(_build_jovian_variant)
	if _jovian_built:
		_jovian_built = _reconfigure_component_damage_from_final_root_collision()
	_apply_jovian_metadata()
	_sync_jovian_engine_presentation_immediately()


func _exit_tree() -> void:
	_clear_copilot_navigation_state(&"ship_detached")
	if _ship_perspective_audio_binding != null:
		if camera_view_changed.is_connected(_on_jovian_camera_view_changed):
			camera_view_changed.disconnect(_on_jovian_camera_view_changed)
		_ship_perspective_audio_binding.detach()
	if _copilot_navigation_audio_binding != null:
		if copilot_navigation_intent_cleared.is_connected(_on_copilot_navigation_audio_cleared):
			copilot_navigation_intent_cleared.disconnect(_on_copilot_navigation_audio_cleared)
		_copilot_navigation_audio_binding.detach()
	super._exit_tree()


func _rebind_jovian_perspective_audio() -> void:
	if not is_inside_tree() or _ship_perspective_audio_binding == null \
			or _ship_audio_rig == null or not is_instance_valid(_ship_audio_rig):
		return
	var snapshot: Dictionary = _ship_perspective_audio_binding.get_snapshot()
	if bool(snapshot.get("attached", false)):
		return
	var result: Dictionary = _ship_perspective_audio_binding.bind(_ship_audio_rig)
	if bool(result.get("accepted", false)) \
		and not camera_view_changed.is_connected(_on_jovian_camera_view_changed):
		camera_view_changed.connect(_on_jovian_camera_view_changed)


func _rebind_copilot_navigation_audio() -> void:
	if not is_inside_tree() or _copilot_navigation_audio_binding == null:
		return
	var snapshot: Dictionary = _copilot_navigation_audio_binding.get_snapshot()
	if not bool(snapshot.get("attached", false)):
		_copilot_navigation_audio_binding.attach(int(snapshot.get("generation", 0)))
	if camera_view_changed.is_connected(_on_jovian_camera_view_changed):
		_on_jovian_camera_view_changed(get_camera_view())


func _on_jovian_camera_view_changed(view: StringName) -> void:
	if _ship_perspective_audio_binding == null:
		return
	var perspective: StringName = &"cockpit" if view == CAMERA_VIEW_COCKPIT else &"exterior"
	var generation := int(_ship_perspective_audio_binding.get_snapshot().get("generation", -1))
	_ship_perspective_audio_binding.present_perspective(perspective, generation)
	if _copilot_navigation_audio_binding != null:
		_copilot_navigation_audio_binding.present_perspective(perspective)


func _on_copilot_navigation_audio_cleared(generation: int, reason: StringName) -> void:
	if _copilot_navigation_audio_binding != null:
		_copilot_navigation_audio_binding.present_cleared(generation, reason)


func get_copilot_navigation_audio_snapshot() -> Dictionary:
	return _copilot_navigation_audio_binding.get_snapshot() \
		if _copilot_navigation_audio_binding != null else {"attached": false}


func _present_copilot_navigation_result(result: Dictionary) -> void:
	if _copilot_navigation_audio_binding == null:
		return
	if bool(result.get("accepted", false)):
		var effect := result.get("effect", {}) as Dictionary
		var receipt := effect.get("receipt", {}) as Dictionary
		if not receipt.is_empty():
			_copilot_navigation_audio_binding.present_accepted_receipt(receipt)
	else:
		_copilot_navigation_audio_binding.present_rejected_result(result)


func get_ship_perspective_audio_snapshot() -> Dictionary:
	return _ship_perspective_audio_binding.get_snapshot() \
		if _ship_perspective_audio_binding != null else {"attached": false}


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _reset_for_reuse_mutation_blocked():
		return
	_cleanup_detached_engineer_state()
	_elapsed_jovian += delta
	_update_jovian_presentation(delta)


func apply_damage(
		amount: float,
		world_hit_position: Vector3 = Vector3.INF,
		world_hit_normal: Vector3 = Vector3.ZERO,
		presentation_receipt_id: int = -1,
		defer_presentation: bool = false
	) -> void:
	super.apply_damage(
		amount,
		world_hit_position,
		world_hit_normal,
		presentation_receipt_id,
		defer_presentation
	)
	if is_destroyed():
		_clear_engineer_component_selection(&"ship_destroyed")
		_clear_copilot_navigation_state(&"ship_destroyed")
		_set_interior_operational(false)


func _preflight_variant_reset_for_reuse(spawn_transform: Transform3D) -> Dictionary:
	return super._preflight_variant_reset_for_reuse(spawn_transform)


func _commit_variant_reset_for_reuse(context: Dictionary) -> void:
	super._commit_variant_reset_for_reuse(context)
	_clear_engineer_component_selection(&"ship_reused", false)
	_engineer_component_generation = 1
	_clear_copilot_navigation_state(&"ship_reused")
	_copilot_navigation_generation = 1
	_set_interior_operational(true)
	if _moving_interior_component != null:
		_moving_interior_component.configure(self, INTERIOR_BOUNDS, _occupant_volume)
		_moving_interior_component.reset_frame_tracking(true)


## The complete visible freighter hierarchy used by the common presentation
## lifecycle. Its `WalkableInterior` child stays attached while the ship moves.
func get_jovian_visual_root() -> Node3D:
	return _jovian_visual


## Stable local combat registry identity reserved for this physical candidate.
## The shared combat authority remains the owner of actual registration.
func get_combat_source_id() -> int:
	return COMBAT_SOURCE_ID


## Stable ship-local hierarchy containing the deck, rooms, lights, fixtures,
## access aperture, and semantic markers of the connected interior.
func get_interior_root() -> Node3D:
	return _walkable_interior


## Registration frame for moving-interior occupant stabilisation. This returns
## a Node3D rather than a concrete component type so the ship contract remains
## usable before or without multiplayer motion compensation.
func get_interior_frame() -> Node3D:
	return self


## Typed coordinator for occupant registration, frame-delta compensation, and
## inertial exit velocity. It is separate from the spatial frame by design.
func get_moving_interior_component() -> MovingInteriorFrame:
	return _moving_interior_component


func get_cargo_bay_root() -> Node3D:
	return _cargo_bay


func get_passenger_cabin_root() -> Node3D:
	return _passenger_cabin


func get_interior_access_marker() -> Marker3D:
	return _interior_access_marker


func get_interior_deck_marker() -> Marker3D:
	return _interior_deck_marker


## World-space safe transform beyond the deployed ramp. This is intentionally
## distinct from HeroShip.get_exit_transform(), which serves the pilot seat.
func get_interior_exit_transform() -> Transform3D:
	if _interior_exit_marker == null:
		return Transform3D(global_basis.orthonormalized(), global_position)
	return _interior_exit_marker.global_transform


## Pressurised/walkable cabin envelope in ship-local coordinates. The deployed
## exterior ramp is deliberately outside this box.
func get_interior_bounds() -> AABB:
	return INTERIOR_BOUNDS


## World-space standing pose a pilot arrives at when leaving the seat under way.
func get_cabin_stand_transform() -> Transform3D:
	if _cabin_stand_marker == null:
		return global_transform.translated_local(CABIN_STAND_LOCAL_ORIGIN)
	return Transform3D(
		_cabin_stand_marker.global_basis.orthonormalized(),
		_cabin_stand_marker.global_position
	)


## `modern_interpretation`. The freighter is the one craft in the fleet with a
## connected, bounded, physically walkable cabin, so it is the one craft whose
## pilot may stand up while it is away from a berth. A destroyed or
## un-instantiated interior withdraws the offer rather than opening a hatch onto
## nothing.
func get_in_flight_cabin_report() -> Dictionary:
	var ready := (
		not is_destroyed()
		and is_instance_valid(_walkable_interior)
		and is_instance_valid(_moving_interior_component)
		and _moving_interior_component.get_moving_frame() == self
	)
	return {
		"supported": ready,
		"status": &"walkable_cabin" if ready else &"interior_unavailable",
		"frame": _moving_interior_component,
		"stand_transform": get_cabin_stand_transform(),
		"local_bounds": CABIN_MOVEMENT_BOUNDS,
	}


## Number of occupants the interior coordinator is currently carrying. Exposed
## for tests and for the multi-occupant work that comes later; the hull's own
## collision response reads it rather than assuming a single crew member.
func get_interior_occupant_count() -> int:
	return _interior_occupant_count


## Typed clearance contract for a berth or landing planner. These are bounds of
## this provisional implementation, not evidence about the historical Jovian.
func get_berth_clearance_report() -> Dictionary:
	return {
		"schema_version": 1,
		"home_berth_id": get_home_berth_id(),
		"parked_render_bounds": PARKED_RENDER_BOUNDS,
		"flight_collision_bounds": FLIGHT_COLLISION_BOUNDS,
		"ramp_side": &"port",
		"ramp_local_direction": Vector3.LEFT,
		"landing_contact_y": -1.25,
		"deployed_ramp_may_overlap_apron": true,
		"provisional": true,
	}


func get_cargo_hardpoints() -> Array[Marker3D]:
	return _cargo_hardpoints.duplicate()


func get_passenger_seat_anchors() -> Array[Marker3D]:
	return _passenger_seat_anchors.duplicate()


## The port passenger seat is the optional physical systems station for this
## freighter. It remains a normal ship-owned anchor; role admission is still
## delegated to the injected CrewSeatRoleAuthority.
func get_engineer_seat_anchor() -> Marker3D:
	for anchor in _passenger_seat_anchors:
		if StringName(anchor.get_meta("seat_id", &"")) == ENGINEER_SEAT_ID:
			return anchor
	return null


## Physical cockpit-side station for the freighter's optional navigation
## support role. The role ledger remains caller-owned; this anchor only names
## the seat that may submit navigation-route receipts.
func get_copilot_seat_anchor() -> Marker3D:
	var cockpit := _walkable_interior.get_node_or_null(^"CockpitInterior") as Node3D \
		if _walkable_interior != null else null
	return cockpit.get_node_or_null(^"CopilotSeatAnchor") as Marker3D \
		if cockpit != null else null


## Binds the injected role ledger. Jovian consumes only its pilot and engineer
## entries; it never creates a second occupancy or repair ledger.
func attach_crew_role_authority(authority: CrewSeatRoleAuthority) -> Dictionary:
	if authority == null:
		return _crew_role_result(false, &"authority_unavailable")
	if _crew_role_authority != null and _crew_role_authority != authority:
		return _crew_role_result(false, &"authority_already_attached")
	var snapshot := authority.get_snapshot()
	if not bool(snapshot.get("roster_sealed", false)):
		return _crew_role_result(false, &"roster_not_sealed")
	var has_pilot := false
	var has_engineer := false
	var has_copilot := false
	for seat_variant in snapshot.get("seats", []) as Array:
		if not seat_variant is Dictionary:
			continue
		var seat := seat_variant as Dictionary
		if StringName(seat.get("vessel_id", &"")) != get_ship_id():
			continue
		if StringName(seat.get("seat_id", &"")) == PILOT_SEAT_ID \
				and StringName(seat.get("role", &"")) == CrewRoleGameplayProfileType.ROLE_PILOT:
			has_pilot = true
		if StringName(seat.get("seat_id", &"")) == ENGINEER_SEAT_ID \
				and StringName(seat.get("role", &"")) == CrewRoleGameplayProfileType.ROLE_ENGINEER:
			has_engineer = true
		if StringName(seat.get("seat_id", &"")) == COPILOT_SEAT_ID \
				and StringName(seat.get("role", &"")) == CrewRoleGameplayProfileType.ROLE_PASSENGER:
			has_copilot = true
	if not has_pilot or not has_engineer or not has_copilot \
			or get_copilot_seat_anchor() == null:
		return _crew_role_result(false, &"jovian_roster_mismatch")
	_crew_role_authority = authority
	var result := _crew_role_result(true, &"authority_attached")
	result["role_count"] = (snapshot.get("seats", []) as Array).size()
	return result


func get_crew_role_authority() -> CrewSeatRoleAuthority:
	return _crew_role_authority


## Admits one engineer receipt and routes it to ShipComponentDamage's existing
## owner-controlled repair pulse. The role consumer owns no health dictionary,
## movement, combat, or lifecycle authority.
func submit_crew_intent(
		source_peer_id: int,
		occupant_peer_id: int,
		avatar_id: StringName,
		action: StringName,
		payload: Dictionary,
		request_sequence: int
) -> Dictionary:
	if _crew_role_authority == null:
		return _crew_role_result(false, &"authority_unavailable")
	var assignment := _crew_role_authority.get_assignment(occupant_peer_id, avatar_id)
	if assignment.is_empty():
		return _crew_role_result(false, &"assignment_not_found")
	if StringName(assignment.get("vessel_id", &"")) != get_ship_id():
		return _crew_role_result(false, &"foreign_vessel")
	if StringName(assignment.get("role", &"")) != CrewRoleGameplayProfileType.ROLE_ENGINEER \
			or StringName(assignment.get("seat_id", &"")) != ENGINEER_SEAT_ID \
			or action != CrewRoleGameplayProfileType.ACTION_ENGINEER_REPAIR:
		if StringName(assignment.get("role", &"")) == CrewRoleGameplayProfileType.ROLE_PASSENGER \
				and StringName(assignment.get("seat_id", &"")) == COPILOT_SEAT_ID \
				and action == CrewRoleGameplayProfileType.ACTION_PASSENGER_PING:
			var navigation_admission := _crew_role_authority.submit_intent(
				source_peer_id,
				occupant_peer_id,
				avatar_id,
				action,
				payload,
				request_sequence
			)
			if not bool(navigation_admission.get("accepted", false)):
				_present_copilot_navigation_result(navigation_admission)
				return navigation_admission
			var navigation_effect := _consume_copilot_navigation_intent(
				navigation_admission.get("intent", {}) as Dictionary
			)
			var navigation_result := navigation_admission.duplicate(true)
			navigation_result["status"] = (
				&"intent_consumed" if bool(navigation_effect.get("accepted", false))
				else &"intent_effect_rejected"
			)
			navigation_result["consumed"] = bool(navigation_effect.get("accepted", false))
			navigation_result["effect"] = navigation_effect
			_present_copilot_navigation_result(navigation_result)
			return navigation_result
		return _crew_role_result(false, &"unsupported_jovian_role_action")
	var admission := _crew_role_authority.submit_intent(
		source_peer_id,
		occupant_peer_id,
		avatar_id,
		action,
		payload,
		request_sequence
	)
	if not bool(admission.get("accepted", false)):
		return admission
	var effect := _consume_engineer_repair_intent(admission.get("intent", {}) as Dictionary)
	var result := admission.duplicate(true)
	result["status"] = &"intent_consumed" if bool(effect.get("accepted", false)) else &"intent_effect_rejected"
	result["consumed"] = bool(effect.get("accepted", false))
	result["effect"] = effect
	return result


func release_crew_role(
		source_peer_id: int,
		occupant_peer_id: int,
		avatar_id: StringName,
		seat_id: StringName,
		request_sequence: int,
		seat_generation: int = 0
) -> Dictionary:
	if _crew_role_authority == null:
		return _crew_role_result(false, &"authority_unavailable")
	var result := _crew_role_authority.release(
		source_peer_id,
		occupant_peer_id,
		avatar_id,
		seat_id,
		request_sequence,
		seat_generation
	)
	if bool(result.get("accepted", false)):
		_clear_engineer_component_state(occupant_peer_id, avatar_id, &"role_released")
		_clear_copilot_navigation_state_for_actor(occupant_peer_id, avatar_id, &"role_released")
	return result


func handoff_crew_role(
		source_peer_id: int,
		previous_occupant_peer_id: int,
		previous_avatar_id: StringName,
		seat_id: StringName,
		release_request_sequence: int,
		new_occupant_peer_id: int,
		new_avatar_id: StringName,
		requested_role: StringName,
		claim_request_sequence: int,
		seat_generation: int = 0
) -> Dictionary:
	if _crew_role_authority == null:
		return _crew_role_result(false, &"authority_unavailable")
	var result := _crew_role_authority.handoff(
		source_peer_id,
		previous_occupant_peer_id,
		previous_avatar_id,
		seat_id,
		release_request_sequence,
		new_occupant_peer_id,
		new_avatar_id,
		requested_role,
		claim_request_sequence,
		seat_generation
	)
	if bool(result.get("accepted", false)):
		_clear_engineer_component_state(previous_occupant_peer_id, previous_avatar_id, &"role_handoff")
		_clear_copilot_navigation_state_for_actor(previous_occupant_peer_id, previous_avatar_id, &"role_handoff")
	return result


func get_engineer_gameplay_state() -> Dictionary:
	return {
		"schema_version": 1,
		"authority_attached": _crew_role_authority != null,
		"component_generation": _engineer_component_generation,
		"selection": _engineer_component_selection.duplicate(true),
		"repair_ready": not is_destroyed()
			and bool(get_telemetry().get("landed", false))
			and not bool(get_telemetry().get("landing_active", false))
			and not _engineer_component_selection.is_empty(),
	}.duplicate(true)


## Detached navigation-support state. Cargo and berth values are read-only
## observations; this role never steers, throttles, fires, mutates cargo, or
## claims a helm/landing lease.
func get_copilot_navigation_state() -> Dictionary:
	var telemetry := get_telemetry()
	return {
		"schema_version": 1,
		"role": COPILOT_ROLE_ID,
		"seat_id": COPILOT_SEAT_ID,
		"authority_attached": _crew_role_authority != null,
		"navigation_generation": _copilot_navigation_generation,
		"receipt": _copilot_navigation_receipt.duplicate(true),
		"cargo_status": {
			"hardpoint_count": _cargo_hardpoints.size(),
			"secured": _cargo_hardpoints.size() == CARGO_UNIT_ANCHORS.size(),
			"mutation_authority": false,
		},
		"berth_status": {
			"home_berth_id": get_home_berth_id(),
			"landed": bool(telemetry.get("landed", false)),
			"landing_active": bool(telemetry.get("landing_active", false)),
			"lease_authority": false,
		},
		"authority": {
			"navigation": false,
			"movement": false,
			"throttle": false,
			"fire": false,
			"cargo": false,
			"helm": false,
		},
	}.duplicate(true)


func _consume_copilot_navigation_intent(intent: Dictionary) -> Dictionary:
	var payload := intent.get("payload", {}) as Dictionary
	if StringName(payload.get("channel", &"")) != COPILOT_NAVIGATION_CHANNEL:
		return _crew_role_result(false, &"unsupported_navigation_channel")
	if is_destroyed():
		return _crew_role_result(false, &"ship_destroyed")
	var receipt := {
		"role": COPILOT_ROLE_ID,
		"seat_id": COPILOT_SEAT_ID,
		"occupant_peer_id": int(intent.get("occupant_peer_id", 0)),
		"avatar_id": StringName(intent.get("avatar_id", &"")),
		"seat_generation": int(intent.get("seat_generation", 0)),
		"request_sequence": int(intent.get("request_sequence", -1)),
		"navigation_generation": _copilot_navigation_generation,
		"route_id": StringName(payload.get("marker_id", &"")),
		"target_id": StringName(payload.get("marker_id", &"")),
		"cargo_status": get_copilot_navigation_state().get("cargo_status", {}).duplicate(true),
		"berth_status": get_copilot_navigation_state().get("berth_status", {}).duplicate(true),
	}.duplicate(true)
	_copilot_navigation_receipt = receipt
	copilot_navigation_intent_accepted.emit(receipt.duplicate(true))
	var result := _crew_role_result(true, &"navigation_receipt_accepted")
	result["receipt"] = receipt.duplicate(true)
	return result


func _clear_copilot_navigation_state_for_actor(
	occupant_peer_id: int,
	avatar_id: StringName,
	reason: StringName
) -> void:
	if not _copilot_navigation_receipt.is_empty() \
			and int(_copilot_navigation_receipt.get("occupant_peer_id", 0)) == occupant_peer_id \
			and StringName(_copilot_navigation_receipt.get("avatar_id", &"")) == avatar_id:
		_clear_copilot_navigation_state(reason)


func _clear_copilot_navigation_state(reason: StringName) -> void:
	_copilot_navigation_receipt.clear()
	_copilot_navigation_generation = mini(_copilot_navigation_generation + 1, 1_000_000)
	copilot_navigation_intent_cleared.emit(_copilot_navigation_generation, reason)


func _consume_engineer_repair_intent(intent: Dictionary) -> Dictionary:
	var payload := intent.get("payload", {}) as Dictionary
	var component_id := StringName(payload.get("system_id", &""))
	var requested_repair := float(payload.get("repair", 0.0))
	var component_generation := int(payload.get("system_generation", 0))
	var model := get_component_damage()
	if model == null or not model.is_configured():
		return _crew_role_result(false, &"component_damage_unavailable")
	var telemetry := get_telemetry()
	if bool(telemetry.get("destroyed", false)):
		return _crew_role_result(false, &"ship_destroyed")
	if not bool(telemetry.get("landed", false)) or bool(telemetry.get("landing_active", false)):
		return _crew_role_result(false, &"repair_requires_berthed_ship")
	var report := model.get_component_report()
	var order: Array = report.get("component_order", []) as Array
	if not order.has(component_id):
		return _crew_role_result(false, &"foreign_component")
	if component_generation != _engineer_component_generation:
		return _crew_role_result(false, &"stale_component_generation")
	var before := model.get_component_integrity(component_id)
	if before < 0.0:
		return _crew_role_result(false, &"foreign_component")
	if before >= 1.0:
		return _crew_role_result(false, &"healthy_component")
	var selection := _select_engineer_component(intent, component_id, component_generation)
	if not bool(selection.get("accepted", false)):
		return selection
	if requested_repair <= 0.0:
		return selection
	var rate := maxf(float(report.get("repair_rate_per_second", 0.0)), 0.05)
	var repair_result := model.tick_repair(requested_repair / rate, true)
	var after := model.get_component_integrity(component_id)
	if not bool(repair_result.get("accepted", false)) or after <= before:
		var rejected := _crew_role_result(false, StringName(repair_result.get("reason", &"system_not_repaired")))
		rejected["repair"] = repair_result
		rejected["selection"] = selection
		return rejected
	var result := _crew_role_result(true, &"repair_applied")
	result["component_id"] = component_id
	result["integrity_before"] = before
	result["integrity_after"] = after
	result["repair"] = repair_result
	result["selection"] = selection
	return result


func _select_engineer_component(
		intent: Dictionary,
		component_id: StringName,
		component_generation: int
) -> Dictionary:
	var selection := {
		"component_id": component_id,
		"component_generation": component_generation,
		"occupant_peer_id": int(intent.get("occupant_peer_id", 0)),
		"avatar_id": StringName(intent.get("avatar_id", &"")),
		"seat_generation": int(intent.get("seat_generation", 0)),
		"request_sequence": int(intent.get("request_sequence", -1)),
	}
	_engineer_component_selection = selection
	engineer_component_selected.emit(
		component_id,
		component_generation,
		selection.duplicate(true)
	)
	var result := _crew_role_result(true, &"component_selected")
	result["selection"] = selection.duplicate(true)
	return result


func _cleanup_detached_engineer_state() -> void:
	if _engineer_component_selection.is_empty():
		return
	if _crew_role_authority == null:
		_clear_engineer_component_selection(&"authority_detached")
		return
	var assignment := _crew_role_authority.get_assignment(
		int(_engineer_component_selection.get("occupant_peer_id", 0)),
		StringName(_engineer_component_selection.get("avatar_id", &""))
	)
	if assignment.is_empty():
		_clear_engineer_component_state(
			int(_engineer_component_selection.get("occupant_peer_id", 0)),
			StringName(_engineer_component_selection.get("avatar_id", &"")),
			&"role_detached"
		)


func _clear_engineer_component_state(
		occupant_peer_id: int,
		avatar_id: StringName,
		reason: StringName
) -> void:
	if not _engineer_component_selection.is_empty() \
			and int(_engineer_component_selection.get("occupant_peer_id", 0)) == occupant_peer_id \
			and StringName(_engineer_component_selection.get("avatar_id", &"")) == avatar_id:
		_clear_engineer_component_selection(reason)


func _clear_engineer_component_selection(reason: StringName, advance_generation: bool = true) -> void:
	if _engineer_component_selection.is_empty():
		if advance_generation:
			_engineer_component_generation = mini(
				_engineer_component_generation + 1,
				MAX_ENGINEER_COMPONENT_GENERATION
			)
		return
	var component_id := StringName(_engineer_component_selection.get("component_id", &""))
	var component_generation := int(_engineer_component_selection.get("component_generation", 0))
	_engineer_component_selection.clear()
	engineer_component_cleared.emit(component_id, component_generation, reason)
	if advance_generation:
		_engineer_component_generation = mini(
			_engineer_component_generation + 1,
			MAX_ENGINEER_COMPONENT_GENERATION
		)


static func _crew_role_result(accepted: bool, status: StringName) -> Dictionary:
	return {"accepted": accepted, "status": status}


func get_walkable_interior_report() -> Dictionary:
	return {
		"schema_version": INTERIOR_SCHEMA_VERSION,
		"frame": self,
		"moving_interior_component": _moving_interior_component,
		"root": _walkable_interior,
		"ship_local_bounds": INTERIOR_BOUNDS,
		"access_marker": _interior_access_marker,
		"deck_marker": _interior_deck_marker,
		"exit_transform": get_interior_exit_transform(),
		"cargo_bay": _cargo_bay,
		"passenger_cabin": _passenger_cabin,
		"pilot_cockpit": get_pilot_seat_anchor().get_parent() if get_pilot_seat_anchor() != null else null,
		"connected_spaces": PackedStringArray(["exterior_ramp", "cargo_bay", "passenger_cabin", "pilot_cockpit"]),
		"cargo_hardpoint_count": _cargo_hardpoints.size(),
		"passenger_seat_count": _passenger_seat_anchors.size(),
		"detached_interior": false,
		"physical_deck_collision": true,
		"moving_occupant_compensation": _moving_interior_component != null,
		"historically_authenticated_layout": false,
		"content_note": PROVISIONAL_NOTE,
	}


func get_jovian_evidence_report() -> Dictionary:
	var definition := get_ship_definition()
	return {
		"schema_version": SCHEMA_VERSION,
		"evidence_status": EVIDENCE_STATUS,
		"evidence_scope": EVIDENCE_SCOPE,
		"name_to_model_status": NAME_TO_MODEL_STATUS,
		"authenticated_geometry": false,
		"creator_supported": PackedStringArray([
			"Jovian-class Light Freighter name (A3 page text)",
			"light-freighter role (A3 page text)",
		]),
		"modern_provisional": PackedStringArray([
			"silhouette, dimensions, proportions, and colours",
			"cargo ramp, walkable interior, room layout, fixtures, and capacity",
			"cockpit, pilot hatch, seat, access side, and cameras",
			"quad engines, defensive weapons, landing gear, and cargo hardware",
			"materials, handling, durability, audio profile, and all mechanics",
		]),
		"content_note": PROVISIONAL_NOTE,
		"ship_definition": definition.get_audit_report() if definition != null else {},
	}


## Visual-only audit for the restrained twin defensive fit. Actual projectile
## authority remains on HeroShip and its two root muzzle markers.
func get_defensive_weapon_visual_report() -> Dictionary:
	var errors := PackedStringArray()
	var component_paths := PackedStringArray()
	var visual_only := true
	for side_index in 2:
		var prefix := "Port" if side_index == 0 else "Starboard"
		var expected_x := -5.15 if side_index == 0 else 5.15
		for suffix in DEFENSIVE_TURRET_PART_SUFFIXES:
			var path := prefix + String(suffix)
			var component := _jovian_visual.get_node_or_null(NodePath(path)) as MeshInstance3D \
				if _jovian_visual != null else null
			component_paths.append(path)
			if component == null:
				errors.append("defensive_turret_component_missing:%s" % path)
				continue
			if (
				StringName(component.get_meta("interpretation_status", &"")) != DEFENSIVE_TURRET_STATUS
				or StringName(component.get_meta("weapon_role", &"")) != DEFENSIVE_TURRET_ROLE
				or bool(component.get_meta("authenticated_historical_weapon", true))
				or not bool(component.get_meta("visual_only", false))
			):
				errors.append("defensive_turret_metadata_drift:%s" % path)
			visual_only = visual_only and component.get_child_count() == 0
		var muzzle := get_node_or_null(NodePath("LeftMuzzle" if side_index == 0 else "RightMuzzle")) as Marker3D
		if muzzle == null or not muzzle.position.is_equal_approx(Vector3(expected_x, 3.76, DEFENSIVE_TURRET_MUZZLE_Z)):
			errors.append("defensive_turret_muzzle_alignment_drift:%s" % prefix)
	var port_base := _jovian_visual.get_node_or_null(^"PortDefensiveTurretBase") as MeshInstance3D \
		if _jovian_visual != null else null
	var port_barrel := _jovian_visual.get_node_or_null(^"PortDefensivePulseBarrel") as MeshInstance3D \
		if _jovian_visual != null else null
	var base_size := port_base.mesh.get_aabb().size if port_base != null and port_base.mesh != null else Vector3.ZERO
	var barrel_size := port_barrel.mesh.get_aabb().size if port_barrel != null and port_barrel.mesh != null else Vector3.ZERO
	if (
		not base_size.is_equal_approx(Vector3(
			DEFENSIVE_TURRET_BASE_RADIUS * 2.0,
			DEFENSIVE_TURRET_BASE_HEIGHT,
			DEFENSIVE_TURRET_BASE_RADIUS * 2.0
		))
	):
		errors.append("defensive_turret_base_dimensions_drift")
	if (
		not barrel_size.is_equal_approx(Vector3(
			DEFENSIVE_TURRET_BARREL_RADIUS * 2.0,
			DEFENSIVE_TURRET_BARREL_LENGTH,
			DEFENSIVE_TURRET_BARREL_RADIUS * 2.0
		))
	):
		errors.append("defensive_turret_barrel_dimensions_drift")
	if not visual_only:
		errors.append("defensive_turret_visual_gained_children")
	return {
		"schema_version": 1,
		"valid": errors.is_empty(),
		"errors": errors,
		"interpretation_status": DEFENSIVE_TURRET_STATUS,
		"weapon_role": DEFENSIVE_TURRET_ROLE,
		"authenticated_historical_weapon": false,
		"visual_only": visual_only,
		"turret_count": 2,
		"components_per_turret": DEFENSIVE_TURRET_PART_SUFFIXES.size(),
		"component_paths": component_paths,
		"muzzle_positions": [Vector3(-5.15, 3.76, DEFENSIVE_TURRET_MUZZLE_Z), Vector3(5.15, 3.76, DEFENSIVE_TURRET_MUZZLE_Z)],
		"base_radius": DEFENSIVE_TURRET_BASE_RADIUS,
		"base_height": DEFENSIVE_TURRET_BASE_HEIGHT,
		"barrel_radius": DEFENSIVE_TURRET_BARREL_RADIUS,
		"barrel_length": DEFENSIVE_TURRET_BARREL_LENGTH,
	}


func get_jovian_audit_report() -> Dictionary:
	var errors := PackedStringArray()
	var defensive_weapon_visual := get_defensive_weapon_visual_report()
	var dorsal_rib_allocation := get_dorsal_cargo_rib_joint_allocation_audit()
	var shoulder_rail_allocation := get_shoulder_rail_joint_allocation_audit()
	var cargo_frame_allocation := get_cargo_frame_joint_allocation_audit()
	var passenger_seat_allocation := get_passenger_seat_mesh_allocation_audit()
	var passenger_cabin_light_strip_allocation := get_passenger_cabin_light_strip_allocation_audit()
	var definition := get_ship_definition()
	if definition == null or not definition.is_definition_valid():
		errors.append("valid provisional ShipDefinition is missing")
	elif definition.get_evidence_status_id() != &"provisional":
		errors.append("Jovian definition must remain provisional")
	if _jovian_visual == null:
		errors.append("dedicated Jovian visual root is missing")
	if _walkable_interior == null or _cargo_bay == null or _passenger_cabin == null:
		errors.append("connected cargo and passenger interior hierarchy is incomplete")
	if _interior_access_marker == null or _interior_deck_marker == null or _interior_exit_marker == null:
		errors.append("interior route markers are incomplete")
	if _cabin_stand_marker == null:
		errors.append("in-flight cabin standing marker is missing")
	elif not CABIN_MOVEMENT_BOUNDS.has_point(CABIN_STAND_LOCAL_ORIGIN):
		errors.append("in-flight cabin standing pose falls outside the confined cabin envelope")
	if _moving_interior_component == null or _moving_interior_component.get_moving_frame() != self:
		errors.append("typed moving-interior component is not configured against the ship frame")
	if _cargo_hardpoints.size() < 4:
		errors.append("cargo bay requires at least four stable cargo hardpoints")
	if _passenger_seat_anchors.size() < 4:
		errors.append("passenger cabin requires at least four seat anchors")
	if _engine_plumes.size() != 4:
		errors.append("provisional quad-engine presentation is incomplete")
	if get_node_or_null("LeftMuzzle") == null or get_node_or_null("RightMuzzle") == null:
		errors.append("defensive muzzle markers are missing")
	if not bool(defensive_weapon_visual.get("valid", false)):
		errors.append("modern provisional defensive weapon visual drifted")
	if not bool(dorsal_rib_allocation.get("valid", false)):
		errors.append("dorsal cargo rib joint allocation contract drifted")
	if not bool(shoulder_rail_allocation.get("valid", false)):
		errors.append("shoulder rail joint allocation contract drifted")
	if not bool(cargo_frame_allocation.get("valid", false)):
		errors.append("cargo frame joint allocation contract drifted")
	if not bool(passenger_seat_allocation.get("valid", false)):
		errors.append("passenger seat mesh allocation contract drifted")
	if not bool(passenger_cabin_light_strip_allocation.get("valid", false)):
		errors.append("passenger cabin light-strip allocation contract drifted")
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"ship_id": get_ship_id(),
		"display_name": get_display_name(),
		"role": get_role(),
		"engine_count": _engine_plumes.size(),
		"weapon_class": &"freighter_defensive_pulse",
		"defensive_weapon_visual": defensive_weapon_visual,
		"combat_source_id": COMBAT_SOURCE_ID,
		"interior": get_walkable_interior_report(),
		"evidence": get_jovian_evidence_report(),
		"dorsal_cargo_rib_joint_allocation": dorsal_rib_allocation,
		"shoulder_rail_joint_allocation": shoulder_rail_allocation,
		"cargo_frame_joint_allocation": cargo_frame_allocation,
		"passenger_seat_mesh_allocation": passenger_seat_allocation,
		"passenger_cabin_light_strip_allocation": passenger_cabin_light_strip_allocation,
	}


## Six passenger seats retain all 18 visible parts and submissions, while their
## three exact rounded-box visual recipes share one immutable ArrayMesh each. Seat anchors and
## collision remain separately owned; this changes no authority or batching.
func get_passenger_seat_mesh_allocation_audit() -> Dictionary:
	var errors := PackedStringArray()
	var mesh_ids: Dictionary = {}
	var node_ids: Dictionary = {}
	var surface_count := 0
	var family_counts := {&"SeatBase": 0, &"SeatBack": 0, &"Harness": 0}
	var expected_meshes := {
		&"SeatBase": _passenger_seat_base_mesh,
		&"SeatBack": _passenger_seat_back_mesh,
		&"Harness": _passenger_seat_harness_mesh,
	}
	var expected_materials := {
		&"SeatBase": _jovian_materials.get("cabin_cloth"),
		&"SeatBack": _jovian_materials.get("cabin_cloth"),
		&"Harness": _jovian_materials.get("amber"),
	}
	var expected_positions := {
		&"SeatBase": Vector3(0.0, 0.88, 0.0),
		&"SeatBack": Vector3(0.0, 1.42, 0.36),
		&"Harness": Vector3(0.0, 1.42, 0.25),
	}
	var expected_rotations := {
		&"SeatBase": Vector3.ZERO,
		&"SeatBack": Vector3(deg_to_rad(8.0), 0.0, 0.0),
		&"Harness": Vector3.ZERO,
	}
	if not is_instance_valid(_passenger_cabin):
		errors.append("passenger_seat_cabin_unavailable")
	else:
		for side_name in [&"Port", &"Starboard"]:
			for seat_index in 3:
				var root_name := "%sPassengerSeat%02d" % [side_name, seat_index]
				var seat_root := _passenger_cabin.get_node_or_null(NodePath(root_name)) as Node3D
				if not is_instance_valid(seat_root):
					errors.append("passenger_seat_root_missing:%s" % root_name)
					continue
				if seat_root.get_node_or_null(^"PassengerAnchor") == null:
					errors.append("passenger_seat_anchor_missing:%s" % root_name)
				for family_name: StringName in expected_meshes:
					var visual := seat_root.get_node_or_null(NodePath(family_name)) as MeshInstance3D
					if not is_instance_valid(visual):
						errors.append("passenger_seat_visual_missing:%s/%s" % [root_name, family_name])
						continue
					family_counts[family_name] = int(family_counts[family_name]) + 1
					node_ids[visual.get_instance_id()] = true
					var mesh := visual.mesh as ArrayMesh
					if mesh == null:
						errors.append("passenger_seat_mesh_type_drift:%s/%s" % [root_name, family_name])
						continue
					mesh_ids[mesh.get_instance_id()] = true
					surface_count += mesh.get_surface_count()
					if (
						mesh != expected_meshes[family_name]
						or mesh.surface_get_material(0) != expected_materials[family_name]
						or mesh.get_surface_count() != 1
						or visual.get_child_count() != 0
						or not visual.position.is_equal_approx(expected_positions[family_name] as Vector3)
						or not visual.rotation.is_equal_approx(expected_rotations[family_name] as Vector3)
						or not visual.scale.is_equal_approx(Vector3.ONE)
						or not visual.visible
						or visual.material_override != null
						or visual.material_overlay != null
					):
						errors.append("passenger_seat_recipe_or_authority_drift:%s/%s" % [root_name, family_name])
	for family_name: StringName in family_counts:
		if int(family_counts[family_name]) != PASSENGER_SEAT_COUNT:
			errors.append("passenger_seat_family_count_drift:%s" % family_name)
	if node_ids.size() != PASSENGER_SEAT_COUNT * 3:
		errors.append("passenger_seat_node_count_drift")
	if mesh_ids.size() != 3:
		errors.append("passenger_seat_mesh_resource_count_drift")
	if surface_count != PASSENGER_SEAT_COUNT * 3:
		errors.append("passenger_seat_submission_count_drift")
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"scope": &"jovian_passenger_seat_visuals",
		"current": {"nodes": node_ids.size(), "copies": PASSENGER_SEAT_COUNT * 3, "submissions": surface_count, "mesh_resource_allocations": mesh_ids.size()},
		"legacy": {"nodes": PASSENGER_SEAT_COUNT * 3, "copies": PASSENGER_SEAT_COUNT * 3, "submissions": PASSENGER_SEAT_COUNT * 3, "mesh_resource_allocations": PASSENGER_SEAT_COUNT * 3},
		"delta": {"mesh_resource_allocations": mesh_ids.size() - PASSENGER_SEAT_COUNT * 3},
		"batched": false,
		"collision_authority": false,
	}.duplicate(true)


## The port and starboard cabin light strips retain their independent authored
## nodes and transforms, but one exact rounded ArrayMesh supplies their shared
## visual-only recipe. No collision, material override, batching, or authority
## is introduced by this allocation reduction.
func get_passenger_cabin_light_strip_allocation_audit() -> Dictionary:
	var errors := PackedStringArray()
	var mesh_ids: Dictionary = {}
	var node_ids: Dictionary = {}
	var surface_count := 0
	var expected_positions := {
		&"Port": Vector3(-3.23, 3.46, -5.25),
		&"Starboard": Vector3(3.23, 3.46, -5.25),
	}
	if not is_instance_valid(_passenger_cabin):
		errors.append("passenger_cabin_light_strip_cabin_unavailable")
	else:
		for side_name: StringName in expected_positions:
			var expected_position := expected_positions[side_name] as Vector3
			var strip: MeshInstance3D
			for candidate in _passenger_cabin.get_children():
				if (
					candidate is MeshInstance3D
					and (candidate as MeshInstance3D).position.is_equal_approx(expected_position)
				):
					if is_instance_valid(strip):
						errors.append("passenger_cabin_light_strip_duplicate:%s" % side_name)
					else:
						strip = candidate as MeshInstance3D
			if not is_instance_valid(strip):
				errors.append("passenger_cabin_light_strip_missing:%s" % side_name)
				continue
			node_ids[strip.get_instance_id()] = true
			var mesh := strip.mesh as ArrayMesh
			if mesh == null:
				errors.append("passenger_cabin_light_strip_mesh_type_drift:%s" % side_name)
				continue
			mesh_ids[mesh.get_instance_id()] = true
			surface_count += mesh.get_surface_count()
			if (
				mesh != _passenger_cabin_light_strip_mesh
				or mesh.surface_get_material(0) != _jovian_materials.get("interior_light")
				or mesh.get_surface_count() != 1
				or strip.get_child_count() != 0
				or not strip.position.is_equal_approx(expected_position)
				or not strip.rotation.is_equal_approx(Vector3.ZERO)
				or not strip.scale.is_equal_approx(Vector3.ONE)
				or not strip.visible
				or strip.material_override != null
				or strip.material_overlay != null
			):
				errors.append("passenger_cabin_light_strip_recipe_or_authority_drift:%s" % side_name)
	if node_ids.size() != 2:
		errors.append("passenger_cabin_light_strip_node_count_drift")
	if mesh_ids.size() != 1:
		errors.append("passenger_cabin_light_strip_mesh_resource_count_drift")
	if surface_count != 2:
		errors.append("passenger_cabin_light_strip_submission_count_drift")
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"scope": &"jovian_passenger_cabin_light_strips",
		"current": {"nodes": node_ids.size(), "copies": 2, "submissions": surface_count, "mesh_resource_allocations": mesh_ids.size()},
		"legacy": {"nodes": 2, "copies": 2, "submissions": 2, "mesh_resource_allocations": 2},
		"delta": {"mesh_resource_allocations": mesh_ids.size() - 2},
		"batched": false,
		"collision_authority": false,
	}.duplicate(true)


## Renderer-independent component evidence for one bounded repeated family.
##
## The report deliberately makes no driver draw-call, timing, or VRAM claim:
## resource identity is the only changed currency. Every named MeshInstance3D,
## drawn copy, surface submission, transform, renderer value, and semantic
## boundary remains independently present in the live Jovian hierarchy.
func get_dorsal_cargo_rib_joint_allocation_audit() -> Dictionary:
	var errors := PackedStringArray()
	var mesh_resource_ids: Dictionary = {}
	var material_resource_ids: Dictionary = {}
	var node_instance_ids: Dictionary = {}
	var family_node_count := 0
	var named_node_count := 0
	var drawn_copy_count := 0
	var structural_surface_submission_count := 0
	var multimesh_batch_count := 0
	var descendant_node_count := 0
	var collision_object_count := 0
	var collision_shape_count := 0
	var interaction_area_count := 0
	var marker_count := 0
	var metadata_entry_count := 0
	var scripted_node_count := 0
	var grouped_node_count := 0
	var processing_node_count := 0
	var behavior_rows: Array[Dictionary] = []

	if _jovian_visual == null or not is_instance_valid(_jovian_visual):
		errors.append("dorsal_rib_visual_root_unavailable")
	else:
		for rib_index in DORSAL_CARGO_RIB_COUNT:
			var rib_name := "DorsalCargoRib%02d" % rib_index
			var rib := _jovian_visual.get_node_or_null(NodePath(rib_name)) as Node3D
			if rib == null:
				errors.append("dorsal_rib_root_missing:%s" % rib_name)
				continue
			if (
				not rib.position.is_equal_approx(Vector3.ZERO)
				or not rib.rotation.is_equal_approx(Vector3.ZERO)
				or not rib.scale.is_equal_approx(Vector3.ONE)
				or not rib.visible
			):
				errors.append("dorsal_rib_root_transform_drift:%s" % rib_name)

			var rib_joints: Array[MeshInstance3D] = []
			var rib_segment_count := 0
			var rib_node_names: Dictionary = {}
			for child in rib.get_children():
				var mesh_instance := child as MeshInstance3D
				if mesh_instance == null:
					continue
				if mesh_instance.mesh is SphereMesh:
					rib_joints.append(mesh_instance)
					rib_node_names[String(mesh_instance.name)] = true
				elif String(mesh_instance.name).begins_with("Segment"):
					rib_segment_count += 1
			if (
				rib.get_child_count() != 9
				or rib_segment_count != 4
				or rib_joints.size() != DORSAL_CARGO_RIB_JOINTS_PER_RIB
			):
				errors.append("dorsal_rib_child_roster_drift:%s" % rib_name)
			if rib_node_names.size() != rib_joints.size():
				errors.append("dorsal_rib_joint_name_roster_drift:%s" % rib_name)
			if (
				rib_joints.is_empty()
				or rib.get_node_or_null(^"CurveJoint") != rib_joints[0]
			):
				errors.append("dorsal_rib_primary_joint_path_drift:%s" % rib_name)
			multimesh_batch_count += rib.find_children(
				"*", "MultiMeshInstance3D", true, false
			).size()

			for joint_index in rib_joints.size():
				var joint := rib_joints[joint_index]
				var sphere := joint.mesh as SphereMesh
				family_node_count += 1
				drawn_copy_count += 1
				node_instance_ids[joint.get_instance_id()] = true
				if not String(joint.name).is_empty():
					named_node_count += 1
				if sphere == null:
					errors.append(
						"dorsal_rib_joint_mesh_type_drift:%s/%s" % [rib_name, joint.name]
					)
					continue
				mesh_resource_ids[sphere.get_instance_id()] = true
				structural_surface_submission_count += sphere.get_surface_count()
				for surface_index in sphere.get_surface_count():
					var material := sphere.surface_get_material(surface_index)
					if material != null:
						material_resource_ids[material.get_instance_id()] = true
				if sphere != _dorsal_cargo_rib_joint_mesh:
					errors.append(
						"dorsal_rib_joint_mesh_identity_drift:%s/%s" % [rib_name, joint.name]
					)
				if (
					not is_equal_approx(sphere.radius, DORSAL_CARGO_RIB_JOINT_RADIUS)
					or not is_equal_approx(
						sphere.height, DORSAL_CARGO_RIB_JOINT_RADIUS * 2.0
					)
					or sphere.radial_segments != DORSAL_CARGO_RIB_JOINT_RADIAL_SEGMENTS
					or sphere.rings != DORSAL_CARGO_RIB_JOINT_RINGS
					or sphere.material != _jovian_materials.get("structure")
					or sphere.get_surface_count() != 1
				):
					errors.append(
						"dorsal_rib_joint_mesh_recipe_drift:%s/%s" % [rib_name, joint.name]
					)

				var expected_xy := DORSAL_CARGO_RIB_JOINT_XY[joint_index]
				var expected_position := Vector3(
					expected_xy.x,
					expected_xy.y,
					-2.4 + float(rib_index) * 2.72
				)
				if (
					not joint.position.is_equal_approx(expected_position)
					or not joint.rotation.is_equal_approx(Vector3.ZERO)
					or not joint.scale.is_equal_approx(Vector3.ONE)
					or not joint.visible
					or joint.layers != 1
					or joint.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON
					or joint.material_override != null
					or joint.material_overlay != null
					or not is_zero_approx(joint.transparency)
					or not is_zero_approx(joint.extra_cull_margin)
					or joint.custom_aabb != AABB()
				):
					errors.append(
						"dorsal_rib_joint_renderer_recipe_drift:%s/%s" % [rib_name, joint.name]
					)

				var authority_state := {
					"descendants": 0,
					"collision_objects": 0,
					"collision_shapes": 0,
					"interaction_areas": 0,
					"markers": 0,
					"metadata_entries": 0,
					"scripted_nodes": 0,
					"grouped_nodes": 0,
					"processing_nodes": 0,
				}
				_accumulate_visual_family_authority(joint, joint, authority_state)
				descendant_node_count += int(authority_state["descendants"])
				collision_object_count += int(authority_state["collision_objects"])
				collision_shape_count += int(authority_state["collision_shapes"])
				interaction_area_count += int(authority_state["interaction_areas"])
				marker_count += int(authority_state["markers"])
				metadata_entry_count += int(authority_state["metadata_entries"])
				scripted_node_count += int(authority_state["scripted_nodes"])
				grouped_node_count += int(authority_state["grouped_nodes"])
				processing_node_count += int(authority_state["processing_nodes"])
				behavior_rows.append({
					"rib_index": rib_index,
					"joint_index": joint_index,
					"node_name": String(joint.name),
					"position": [joint.position.x, joint.position.y, joint.position.z],
					"rotation": [joint.rotation.x, joint.rotation.y, joint.rotation.z],
					"scale": [joint.scale.x, joint.scale.y, joint.scale.z],
				})

	if family_node_count != DORSAL_CARGO_RIB_JOINT_COPY_COUNT:
		errors.append("dorsal_rib_joint_node_count_drift")
	if named_node_count != DORSAL_CARGO_RIB_JOINT_COPY_COUNT:
		errors.append("dorsal_rib_joint_named_node_count_drift")
	if node_instance_ids.size() != DORSAL_CARGO_RIB_JOINT_COPY_COUNT:
		errors.append("dorsal_rib_joint_node_identity_count_drift")
	if mesh_resource_ids.size() != 1:
		errors.append("dorsal_rib_joint_mesh_resource_count_drift")
	if material_resource_ids.size() != 1:
		errors.append("dorsal_rib_joint_material_resource_count_drift")
	if structural_surface_submission_count != DORSAL_CARGO_RIB_JOINT_COPY_COUNT:
		errors.append("dorsal_rib_joint_submission_count_drift")
	if multimesh_batch_count != 0:
		errors.append("dorsal_rib_joint_unexpected_batch")
	if descendant_node_count != 0:
		errors.append("dorsal_rib_joint_gained_children")
	if collision_object_count != 0 or collision_shape_count != 0 or interaction_area_count != 0:
		errors.append("dorsal_rib_joint_gained_collision_or_interaction_authority")
	if metadata_entry_count != 0:
		errors.append("dorsal_rib_joint_gained_evidence_metadata")
	if (
		marker_count != 0
		or scripted_node_count != 0
		or grouped_node_count != 0
		or processing_node_count != 0
	):
		errors.append("dorsal_rib_joint_gained_lifecycle_or_semantic_authority")

	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"scope": &"jovian_dorsal_cargo_rib_curve_joints",
		"current": {
			"geometry_nodes": family_node_count,
			"named_nodes": named_node_count,
			"drawn_copies": drawn_copy_count,
			"geometry_submissions": structural_surface_submission_count,
			"mesh_resource_allocations": mesh_resource_ids.size(),
			"material_resource_allocations": material_resource_ids.size(),
			"multimesh_batches": multimesh_batch_count,
		},
		"legacy": {
			"geometry_nodes": DORSAL_CARGO_RIB_JOINT_COPY_COUNT,
			"named_nodes": DORSAL_CARGO_RIB_JOINT_COPY_COUNT,
			"drawn_copies": DORSAL_CARGO_RIB_JOINT_COPY_COUNT,
			"geometry_submissions": DORSAL_CARGO_RIB_JOINT_COPY_COUNT,
			"mesh_resource_allocations": DORSAL_CARGO_RIB_JOINT_COPY_COUNT,
			"material_resource_allocations": 1,
			"multimesh_batches": 0,
		},
		"delta": {
			"geometry_nodes": family_node_count - DORSAL_CARGO_RIB_JOINT_COPY_COUNT,
			"drawn_copies": drawn_copy_count - DORSAL_CARGO_RIB_JOINT_COPY_COUNT,
			"geometry_submissions": (
				structural_surface_submission_count - DORSAL_CARGO_RIB_JOINT_COPY_COUNT
			),
			"mesh_resource_allocations": (
				mesh_resource_ids.size() - DORSAL_CARGO_RIB_JOINT_COPY_COUNT
			),
			"material_resource_allocations": material_resource_ids.size() - 1,
		},
		"descendant_node_count": descendant_node_count,
		"collision_object_count": collision_object_count,
		"collision_shape_count": collision_shape_count,
		"interaction_area_count": interaction_area_count,
		"marker_count": marker_count,
		"metadata_entry_count": metadata_entry_count,
		"scripted_node_count": scripted_node_count,
		"grouped_node_count": grouped_node_count,
		"processing_node_count": processing_node_count,
		"batched": false,
		"driver_draw_call_claimed": false,
		"frame_time_claimed": false,
		"vram_claimed": false,
		"behavior_rows": behavior_rows,
	}.duplicate(true)


## Renderer-independent allocation evidence for the seven shoulder-rail joints.
##
## This freezes resource identity without claiming a batch or draw-call saving:
## the three rail roots, seven renderer nodes, visible copies, and submissions
## remain independently live.
func get_shoulder_rail_joint_allocation_audit() -> Dictionary:
	var errors := PackedStringArray()
	var mesh_resource_ids: Dictionary = {}
	var material_resource_ids: Dictionary = {}
	var node_instance_ids: Dictionary = {}
	var family_node_count := 0
	var named_node_count := 0
	var drawn_copy_count := 0
	var structural_surface_submission_count := 0
	var multimesh_batch_count := 0
	var descendant_node_count := 0
	var collision_object_count := 0
	var collision_shape_count := 0
	var interaction_area_count := 0
	var marker_count := 0
	var metadata_entry_count := 0
	var scripted_node_count := 0
	var grouped_node_count := 0
	var processing_node_count := 0
	var behavior_rows: Array[Dictionary] = []

	if _jovian_visual == null or not is_instance_valid(_jovian_visual):
		errors.append("shoulder_rail_visual_root_unavailable")
	else:
		for rail_index in SHOULDER_RAIL_NAMES.size():
			var rail_name := SHOULDER_RAIL_NAMES[rail_index]
			var rail := _jovian_visual.get_node_or_null(NodePath(rail_name)) as Node3D
			var expected_positions := SHOULDER_RAIL_JOINT_POSITIONS[rail_index] as Array
			if rail == null:
				errors.append("shoulder_rail_root_missing:%s" % rail_name)
				continue
			if (
				not rail.position.is_equal_approx(Vector3.ZERO)
				or not rail.rotation.is_equal_approx(Vector3.ZERO)
				or not rail.scale.is_equal_approx(Vector3.ONE)
				or not rail.visible
			):
				errors.append("shoulder_rail_root_transform_drift:%s" % rail_name)

			var rail_joints: Array[MeshInstance3D] = []
			var rail_segment_count := 0
			for child in rail.get_children():
				var mesh_instance := child as MeshInstance3D
				if mesh_instance == null:
					continue
				if mesh_instance.mesh is SphereMesh:
					rail_joints.append(mesh_instance)
				elif String(mesh_instance.name).begins_with("Segment"):
					rail_segment_count += 1
			if (
				rail.get_child_count() != expected_positions.size() * 2 - 1
				or rail_segment_count != expected_positions.size() - 1
				or rail_joints.size() != expected_positions.size()
			):
				errors.append("shoulder_rail_child_roster_drift:%s" % rail_name)
			if rail_joints.is_empty() or rail.get_node_or_null(^"CurveJoint") != rail_joints[0]:
				errors.append("shoulder_rail_primary_joint_path_drift:%s" % rail_name)
			multimesh_batch_count += rail.find_children(
				"*", "MultiMeshInstance3D", true, false
			).size()

			for joint_index in rail_joints.size():
				var joint := rail_joints[joint_index]
				var sphere := joint.mesh as SphereMesh
				family_node_count += 1
				drawn_copy_count += 1
				node_instance_ids[joint.get_instance_id()] = true
				if not String(joint.name).is_empty():
					named_node_count += 1
				if sphere == null:
					errors.append("shoulder_rail_joint_mesh_type_drift:%s/%s" % [
					rail_name, joint.name,
				])
					continue
				mesh_resource_ids[sphere.get_instance_id()] = true
				structural_surface_submission_count += sphere.get_surface_count()
				for surface_index in sphere.get_surface_count():
					var material := sphere.surface_get_material(surface_index)
					if material != null:
						material_resource_ids[material.get_instance_id()] = true
				if sphere != _shoulder_rail_joint_mesh:
					errors.append("shoulder_rail_joint_mesh_identity_drift:%s/%s" % [
					rail_name, joint.name,
				])
				if (
					not is_equal_approx(sphere.radius, SHOULDER_RAIL_JOINT_RADIUS)
					or not is_equal_approx(sphere.height, SHOULDER_RAIL_JOINT_RADIUS * 2.0)
					or sphere.radial_segments != SHOULDER_RAIL_JOINT_RADIAL_SEGMENTS
					or sphere.rings != SHOULDER_RAIL_JOINT_RINGS
					or sphere.material != _jovian_materials.get("teal")
					or sphere.get_surface_count() != 1
				):
					errors.append("shoulder_rail_joint_mesh_recipe_drift:%s/%s" % [
					rail_name, joint.name,
				])
				var expected_position := expected_positions[joint_index] as Vector3
				if (
					not joint.position.is_equal_approx(expected_position)
					or not joint.rotation.is_equal_approx(Vector3.ZERO)
					or not joint.scale.is_equal_approx(Vector3.ONE)
					or not joint.visible
					or joint.layers != 1
					or joint.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON
					or joint.material_override != null
					or joint.material_overlay != null
					or not is_zero_approx(joint.transparency)
					or not is_zero_approx(joint.extra_cull_margin)
					or joint.custom_aabb != AABB()
				):
					errors.append("shoulder_rail_joint_renderer_recipe_drift:%s/%s" % [
					rail_name, joint.name,
				])

				var authority_state := {
					"descendants": 0,
					"collision_objects": 0,
					"collision_shapes": 0,
					"interaction_areas": 0,
					"markers": 0,
					"metadata_entries": 0,
					"scripted_nodes": 0,
					"grouped_nodes": 0,
					"processing_nodes": 0,
				}
				_accumulate_visual_family_authority(joint, joint, authority_state)
				descendant_node_count += int(authority_state["descendants"])
				collision_object_count += int(authority_state["collision_objects"])
				collision_shape_count += int(authority_state["collision_shapes"])
				interaction_area_count += int(authority_state["interaction_areas"])
				marker_count += int(authority_state["markers"])
				metadata_entry_count += int(authority_state["metadata_entries"])
				scripted_node_count += int(authority_state["scripted_nodes"])
				grouped_node_count += int(authority_state["grouped_nodes"])
				processing_node_count += int(authority_state["processing_nodes"])
				behavior_rows.append({
					"rail_name": String(rail_name),
					"joint_index": joint_index,
					"node_name": String(joint.name),
					"position": [joint.position.x, joint.position.y, joint.position.z],
					"rotation": [joint.rotation.x, joint.rotation.y, joint.rotation.z],
					"scale": [joint.scale.x, joint.scale.y, joint.scale.z],
				})

	if family_node_count != SHOULDER_RAIL_JOINT_COPY_COUNT:
		errors.append("shoulder_rail_joint_node_count_drift")
	if named_node_count != SHOULDER_RAIL_JOINT_COPY_COUNT:
		errors.append("shoulder_rail_joint_named_node_count_drift")
	if node_instance_ids.size() != SHOULDER_RAIL_JOINT_COPY_COUNT:
		errors.append("shoulder_rail_joint_node_identity_count_drift")
	if mesh_resource_ids.size() != 1:
		errors.append("shoulder_rail_joint_mesh_resource_count_drift")
	if material_resource_ids.size() != 1:
		errors.append("shoulder_rail_joint_material_resource_count_drift")
	if structural_surface_submission_count != SHOULDER_RAIL_JOINT_COPY_COUNT:
		errors.append("shoulder_rail_joint_submission_count_drift")
	if multimesh_batch_count != 0:
		errors.append("shoulder_rail_joint_unexpected_batch")
	if descendant_node_count != 0:
		errors.append("shoulder_rail_joint_gained_children")
	if collision_object_count != 0 or collision_shape_count != 0 or interaction_area_count != 0:
		errors.append("shoulder_rail_joint_gained_collision_or_interaction_authority")
	if metadata_entry_count != 0:
		errors.append("shoulder_rail_joint_gained_evidence_metadata")
	if (
		marker_count != 0
		or scripted_node_count != 0
		or grouped_node_count != 0
		or processing_node_count != 0
	):
		errors.append("shoulder_rail_joint_gained_lifecycle_or_semantic_authority")

	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"scope": &"jovian_exterior_shoulder_rail_curve_joints",
		"current": {
			"geometry_nodes": family_node_count,
			"named_nodes": named_node_count,
			"drawn_copies": drawn_copy_count,
			"geometry_submissions": structural_surface_submission_count,
			"mesh_resource_allocations": mesh_resource_ids.size(),
			"material_resource_allocations": material_resource_ids.size(),
			"multimesh_batches": multimesh_batch_count,
		},
		"legacy": {
			"geometry_nodes": SHOULDER_RAIL_JOINT_COPY_COUNT,
			"named_nodes": SHOULDER_RAIL_JOINT_COPY_COUNT,
			"drawn_copies": SHOULDER_RAIL_JOINT_COPY_COUNT,
			"geometry_submissions": SHOULDER_RAIL_JOINT_COPY_COUNT,
			"mesh_resource_allocations": SHOULDER_RAIL_JOINT_COPY_COUNT,
			"material_resource_allocations": 1,
			"multimesh_batches": 0,
		},
		"delta": {
			"geometry_nodes": family_node_count - SHOULDER_RAIL_JOINT_COPY_COUNT,
			"drawn_copies": drawn_copy_count - SHOULDER_RAIL_JOINT_COPY_COUNT,
			"geometry_submissions": (
				structural_surface_submission_count - SHOULDER_RAIL_JOINT_COPY_COUNT
			),
			"mesh_resource_allocations": (
				mesh_resource_ids.size() - SHOULDER_RAIL_JOINT_COPY_COUNT
			),
			"material_resource_allocations": material_resource_ids.size() - 1,
		},
		"descendant_node_count": descendant_node_count,
		"collision_object_count": collision_object_count,
		"collision_shape_count": collision_shape_count,
		"interaction_area_count": interaction_area_count,
		"marker_count": marker_count,
		"metadata_entry_count": metadata_entry_count,
		"scripted_node_count": scripted_node_count,
		"grouped_node_count": grouped_node_count,
		"processing_node_count": processing_node_count,
		"batched": false,
		"driver_draw_call_claimed": false,
		"frame_time_claimed": false,
		"vram_claimed": false,
		"behavior_rows": behavior_rows,
	}.duplicate(true)


## Renderer-independent allocation evidence for the 20 moving-interior cargo
## frame joints. Resource identity is the only changed currency: every frame
## root, joint node, visible copy, transform, renderer value, and submission
## remains live under the same connected CargoBay hierarchy.
func get_cargo_frame_joint_allocation_audit() -> Dictionary:
	var errors := PackedStringArray()
	var mesh_resource_ids: Dictionary = {}
	var material_resource_ids: Dictionary = {}
	var node_instance_ids: Dictionary = {}
	var family_node_count := 0
	var named_node_count := 0
	var drawn_copy_count := 0
	var structural_surface_submission_count := 0
	var multimesh_batch_count := 0
	var descendant_node_count := 0
	var collision_object_count := 0
	var collision_shape_count := 0
	var interaction_area_count := 0
	var marker_count := 0
	var metadata_entry_count := 0
	var scripted_node_count := 0
	var grouped_node_count := 0
	var processing_node_count := 0
	var behavior_rows: Array[Dictionary] = []
	var moving_interior_attached := (
		_cargo_bay != null
		and is_instance_valid(_cargo_bay)
		and _walkable_interior != null
		and is_instance_valid(_walkable_interior)
		and _cargo_bay.get_parent() == _walkable_interior
		and _walkable_interior.get_parent() == self
		and _moving_interior_component != null
		and _moving_interior_component.get_moving_frame() == self
	)

	if not moving_interior_attached:
		errors.append("cargo_frame_moving_interior_attachment_drift")
	if _cargo_bay == null or not is_instance_valid(_cargo_bay):
		errors.append("cargo_frame_visual_root_unavailable")
	else:
		for frame_index in CARGO_FRAME_COUNT:
			var frame_name := "CargoFrame%02d" % frame_index
			var frame := _cargo_bay.get_node_or_null(NodePath(frame_name)) as Node3D
			if frame == null:
				errors.append("cargo_frame_root_missing:%s" % frame_name)
				continue
			if (
				not frame.position.is_equal_approx(Vector3.ZERO)
				or not frame.rotation.is_equal_approx(Vector3.ZERO)
				or not frame.scale.is_equal_approx(Vector3.ONE)
				or not frame.visible
			):
				errors.append("cargo_frame_root_transform_drift:%s" % frame_name)

			var frame_joints: Array[MeshInstance3D] = []
			var frame_segment_count := 0
			var frame_node_names: Dictionary = {}
			for child in frame.get_children():
				var mesh_instance := child as MeshInstance3D
				if mesh_instance == null:
					continue
				if mesh_instance.mesh is SphereMesh:
					frame_joints.append(mesh_instance)
					frame_node_names[String(mesh_instance.name)] = true
				elif String(mesh_instance.name).begins_with("Segment"):
					frame_segment_count += 1
			if (
				frame.get_child_count() != 9
				or frame_segment_count != 4
				or frame_joints.size() != CARGO_FRAME_JOINTS_PER_FRAME
			):
				errors.append("cargo_frame_child_roster_drift:%s" % frame_name)
			if frame_node_names.size() != frame_joints.size():
				errors.append("cargo_frame_joint_name_roster_drift:%s" % frame_name)
			if frame_joints.is_empty() or frame.get_node_or_null(^"CurveJoint") != frame_joints[0]:
				errors.append("cargo_frame_primary_joint_path_drift:%s" % frame_name)
			multimesh_batch_count += frame.find_children(
				"*", "MultiMeshInstance3D", true, false
			).size()

			for joint_index in frame_joints.size():
				var joint := frame_joints[joint_index]
				var sphere := joint.mesh as SphereMesh
				family_node_count += 1
				drawn_copy_count += 1
				node_instance_ids[joint.get_instance_id()] = true
				if not String(joint.name).is_empty():
					named_node_count += 1
				if sphere == null:
					errors.append("cargo_frame_joint_mesh_type_drift:%s/%s" % [
						frame_name, joint.name,
					])
					continue
				mesh_resource_ids[sphere.get_instance_id()] = true
				structural_surface_submission_count += sphere.get_surface_count()
				for surface_index in sphere.get_surface_count():
					var material := sphere.surface_get_material(surface_index)
					if material != null:
						material_resource_ids[material.get_instance_id()] = true
				if sphere != _cargo_frame_joint_mesh:
					errors.append("cargo_frame_joint_mesh_identity_drift:%s/%s" % [
						frame_name, joint.name,
					])
				if (
					not is_equal_approx(sphere.radius, CARGO_FRAME_JOINT_RADIUS)
					or not is_equal_approx(sphere.height, CARGO_FRAME_JOINT_RADIUS * 2.0)
					or sphere.radial_segments != CARGO_FRAME_JOINT_RADIAL_SEGMENTS
					or sphere.rings != CARGO_FRAME_JOINT_RINGS
					or sphere.material != _jovian_materials.get("hull_cool")
					or sphere.get_surface_count() != 1
				):
					errors.append("cargo_frame_joint_mesh_recipe_drift:%s/%s" % [
						frame_name, joint.name,
					])

				var expected_xy := CARGO_FRAME_JOINT_XY[joint_index]
				var expected_position := Vector3(
					expected_xy.x,
					expected_xy.y,
					CARGO_FRAME_START_Z + float(frame_index) * CARGO_FRAME_Z_STEP
				)
				if (
					not joint.position.is_equal_approx(expected_position)
					or not joint.rotation.is_equal_approx(Vector3.ZERO)
					or not joint.scale.is_equal_approx(Vector3.ONE)
					or not joint.visible
					or joint.layers != 1
					or joint.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON
					or joint.material_override != null
					or joint.material_overlay != null
					or not is_zero_approx(joint.transparency)
					or not is_zero_approx(joint.extra_cull_margin)
					or joint.custom_aabb != AABB()
				):
					errors.append("cargo_frame_joint_renderer_recipe_drift:%s/%s" % [
						frame_name, joint.name,
					])

				var authority_state := {
					"descendants": 0,
					"collision_objects": 0,
					"collision_shapes": 0,
					"interaction_areas": 0,
					"markers": 0,
					"metadata_entries": 0,
					"scripted_nodes": 0,
					"grouped_nodes": 0,
					"processing_nodes": 0,
				}
				_accumulate_visual_family_authority(joint, joint, authority_state)
				descendant_node_count += int(authority_state["descendants"])
				collision_object_count += int(authority_state["collision_objects"])
				collision_shape_count += int(authority_state["collision_shapes"])
				interaction_area_count += int(authority_state["interaction_areas"])
				marker_count += int(authority_state["markers"])
				metadata_entry_count += int(authority_state["metadata_entries"])
				scripted_node_count += int(authority_state["scripted_nodes"])
				grouped_node_count += int(authority_state["grouped_nodes"])
				processing_node_count += int(authority_state["processing_nodes"])
				behavior_rows.append({
					"frame_index": frame_index,
					"joint_index": joint_index,
					"node_name": String(joint.name),
					"position": [joint.position.x, joint.position.y, joint.position.z],
					"rotation": [joint.rotation.x, joint.rotation.y, joint.rotation.z],
					"scale": [joint.scale.x, joint.scale.y, joint.scale.z],
				})

	if family_node_count != CARGO_FRAME_JOINT_COPY_COUNT:
		errors.append("cargo_frame_joint_node_count_drift")
	if named_node_count != CARGO_FRAME_JOINT_COPY_COUNT:
		errors.append("cargo_frame_joint_named_node_count_drift")
	if node_instance_ids.size() != CARGO_FRAME_JOINT_COPY_COUNT:
		errors.append("cargo_frame_joint_node_identity_count_drift")
	if mesh_resource_ids.size() != 1:
		errors.append("cargo_frame_joint_mesh_resource_count_drift")
	if material_resource_ids.size() != 1:
		errors.append("cargo_frame_joint_material_resource_count_drift")
	if structural_surface_submission_count != CARGO_FRAME_JOINT_COPY_COUNT:
		errors.append("cargo_frame_joint_submission_count_drift")
	if multimesh_batch_count != 0:
		errors.append("cargo_frame_joint_unexpected_batch")
	if descendant_node_count != 0:
		errors.append("cargo_frame_joint_gained_children")
	if collision_object_count != 0 or collision_shape_count != 0 or interaction_area_count != 0:
		errors.append("cargo_frame_joint_gained_collision_or_interaction_authority")
	if metadata_entry_count != 0:
		errors.append("cargo_frame_joint_gained_evidence_metadata")
	if (
		marker_count != 0
		or scripted_node_count != 0
		or grouped_node_count != 0
		or processing_node_count != 0
	):
		errors.append("cargo_frame_joint_gained_lifecycle_or_semantic_authority")

	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"scope": &"jovian_moving_interior_cargo_frame_curve_joints",
		"current": {
			"geometry_nodes": family_node_count,
			"named_nodes": named_node_count,
			"drawn_copies": drawn_copy_count,
			"geometry_submissions": structural_surface_submission_count,
			"mesh_resource_allocations": mesh_resource_ids.size(),
			"material_resource_allocations": material_resource_ids.size(),
			"multimesh_batches": multimesh_batch_count,
		},
		"legacy": {
			"geometry_nodes": CARGO_FRAME_JOINT_COPY_COUNT,
			"named_nodes": CARGO_FRAME_JOINT_COPY_COUNT,
			"drawn_copies": CARGO_FRAME_JOINT_COPY_COUNT,
			"geometry_submissions": CARGO_FRAME_JOINT_COPY_COUNT,
			"mesh_resource_allocations": CARGO_FRAME_JOINT_COPY_COUNT,
			"material_resource_allocations": 1,
			"multimesh_batches": 0,
		},
		"delta": {
			"geometry_nodes": family_node_count - CARGO_FRAME_JOINT_COPY_COUNT,
			"drawn_copies": drawn_copy_count - CARGO_FRAME_JOINT_COPY_COUNT,
			"geometry_submissions": (
				structural_surface_submission_count - CARGO_FRAME_JOINT_COPY_COUNT
			),
			"mesh_resource_allocations": (
				mesh_resource_ids.size() - CARGO_FRAME_JOINT_COPY_COUNT
			),
			"material_resource_allocations": material_resource_ids.size() - 1,
		},
		"moving_interior_attached": moving_interior_attached,
		"descendant_node_count": descendant_node_count,
		"collision_object_count": collision_object_count,
		"collision_shape_count": collision_shape_count,
		"interaction_area_count": interaction_area_count,
		"marker_count": marker_count,
		"metadata_entry_count": metadata_entry_count,
		"scripted_node_count": scripted_node_count,
		"grouped_node_count": grouped_node_count,
		"processing_node_count": processing_node_count,
		"batched": false,
		"driver_draw_call_claimed": false,
		"frame_time_claimed": false,
		"vram_claimed": false,
		"behavior_rows": behavior_rows,
	}.duplicate(true)


func _accumulate_visual_family_authority(
	root_joint: MeshInstance3D,
	node: Node,
	state: Dictionary
	) -> void:
	if node != root_joint:
		state["descendants"] = int(state["descendants"]) + 1
	if node is CollisionObject3D:
		state["collision_objects"] = int(state["collision_objects"]) + 1
	if node is CollisionShape3D:
		state["collision_shapes"] = int(state["collision_shapes"]) + 1
	if node is Area3D:
		state["interaction_areas"] = int(state["interaction_areas"]) + 1
	if node is Marker3D:
		state["markers"] = int(state["markers"]) + 1
	state["metadata_entries"] = int(state["metadata_entries"]) + node.get_meta_list().size()
	if node.get_script() != null:
		state["scripted_nodes"] = int(state["scripted_nodes"]) + 1
	if not node.get_groups().is_empty():
		state["grouped_nodes"] = int(state["grouped_nodes"]) + 1
	if (
		node.is_processing()
		or node.is_physics_processing()
		or node.is_processing_input()
		or node.is_processing_unhandled_input()
	):
		state["processing_nodes"] = int(state["processing_nodes"]) + 1
	for child in node.get_children():
		_accumulate_visual_family_authority(root_joint, child, state)


func _build_jovian_variant(_controller: HeroShip) -> bool:
	var inherited_visual := get_variant_visual_root()
	if inherited_visual == null:
		return false
	# Keep common-controller cockpit objects and their private references intact,
	# but relocate the entire cabin into the freighter's forward flight deck.
	var cockpit := inherited_visual.get_node_or_null("CockpitInterior") as Node3D
	var canopy := inherited_visual.get_node_or_null("CanopyHinge") as Node3D
	var hinge_bar := inherited_visual.get_node_or_null("CanopyHingeBar") as Node3D
	var hinge_mounts := inherited_visual.find_children("*CanopyHingeMount", "Node3D", false, false)
	for preserved in [cockpit, canopy, hinge_bar]:
		if preserved != null:
			preserved.reparent(self, true)
	for mount in hinge_mounts:
		(mount as Node3D).reparent(self, true)
	if inherited_visual.get_parent() != null:
		inherited_visual.get_parent().remove_child(inherited_visual)
	inherited_visual.queue_free()

	_jovian_visual = Node3D.new()
	_jovian_visual.name = "JovianFreighterVisual"
	_jovian_visual.set_meta("geometry_status", EVIDENCE_STATUS)
	_jovian_visual.set_meta("authenticated_historical_silhouette", false)
	_jovian_visual.set_meta("content_note", PROVISIONAL_NOTE)
	add_child(_jovian_visual)
	for preserved in [cockpit, canopy, hinge_bar]:
		if preserved != null:
			preserved.reparent(_jovian_visual, true)
	for mount in hinge_mounts:
		(mount as Node3D).reparent(_jovian_visual, true)

	_create_jovian_materials()
	_relocate_and_restyle_cockpit(cockpit, canopy, hinge_bar, hinge_mounts)
	_build_exterior()
	_build_connected_interior()
	_build_propulsion_and_gear()
	_replace_collision_and_markers()
	_bind_optional_interior_frame()
	if not replace_variant_visual_root(_jovian_visual):
		return false
	return true


func _create_jovian_materials() -> void:
	_jovian_materials.hull_warm = _jovian_material(HULL_WARM, 0.16, 0.3)
	_jovian_materials.hull_cool = _jovian_material(HULL_COOL, 0.22, 0.38)
	# Freighter secondary structure. Before this pass structure/dark/amber sat at
	# roughness 0.36/0.30/0.35 and cargo_blue/deck at 0.47/0.52 — the whole
	# working half of the ship inside a 0.22 band, so the painted bulkheads, the
	# oiled load rails and the yellow cargo-aperture frame all returned the same
	# highlight and separated only by hue. They are now painted plate, oiled
	# steel, matte industrial paint, a painted crate and worn deck tread.
	# Colours are unchanged.
	_jovian_materials.structure = _jovian_material(JOVIAN_STRUCTURE, 0.34, 0.66)
	_jovian_materials.dark = _jovian_material(JOVIAN_STRUCTURE_DARK, 0.72, 0.22)
	_jovian_materials.teal = _jovian_material(FREIGHT_TEAL, 0.28, 0.3, FREIGHT_TEAL, 0.75)
	_jovian_materials.amber = _jovian_material(FREIGHT_AMBER, 0.14, 0.62)
	_jovian_materials.cargo_blue = _jovian_material(CARGO_BLUE, 0.10, 0.70)
	_jovian_materials.cabin_cloth = _jovian_material(CABIN_CLOTH, 0.08, 0.78)
	_jovian_materials.deck = _jovian_material(DECK_GREY, 0.40, 0.74)
	_jovian_materials.engine = _jovian_material(ENGINE_AQUA, 0.1, 0.16, ENGINE_AQUA, 3.2)
	_jovian_materials.nav_red = _jovian_material(JOVIAN_NAV_RED, 0.08, 0.2, JOVIAN_NAV_RED, 2.4)
	_jovian_materials.nav_green = _jovian_material(JOVIAN_NAV_GREEN, 0.08, 0.2, JOVIAN_NAV_GREEN, 2.4)
	_jovian_materials.interior_light = _jovian_material(Color("d5f9ee"), 0.0, 0.24, Color("b7fff0"), 2.5)
	_jovian_materials.display = _jovian_material(Color("183b40"), 0.18, 0.22, FREIGHT_TEAL, 2.8)
	_jovian_materials.glass = _jovian_glass(Color(0.12, 0.48, 0.52, 0.2))
	# The freighter has its own larger-scale civilian service-panel finish. Reusing
	# the Arrow's small ceramic pattern made two intentionally different classes
	# read as the same procedural prop at normal viewing distance.
	var hull_albedo := load("res://assets/materials/jovian-hull-albedo-v1.png") as Texture2D
	var hull_normal := load("res://assets/materials/jovian-hull-normal-v1.png") as Texture2D
	var hull_roughness := load("res://assets/materials/jovian-hull-roughness-v1.png") as Texture2D
	for hull_material: StandardMaterial3D in [_jovian_materials.hull_warm, _jovian_materials.hull_cool]:
		if hull_albedo != null:
			hull_material.albedo_texture = hull_albedo
		if hull_normal != null:
			hull_material.normal_enabled = true
			hull_material.normal_texture = hull_normal
			hull_material.normal_scale = 0.68
		if hull_roughness != null:
			hull_material.roughness_texture = hull_roughness
			hull_material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		hull_material.uv1_triplanar = true
		hull_material.uv1_triplanar_sharpness = 4.5
		hull_material.uv1_scale = Vector3.ONE * 0.24
		hull_material.clearcoat_enabled = true
		hull_material.clearcoat = 0.42
		hull_material.clearcoat_roughness = 0.25
	# The cargo-aperture uprights, header, load rails and restraints were the
	# most primitive-looking objects on the freighter: full-height flat yellow
	# bars standing against a fully panelled hull in the baseline walk-up frame.
	# The freighter's own registered normal map is reused on the working
	# structure through triplanar projection at 8-20x the hull's frequency, so a
	# bulkhead, a load rail and a deck plate each carry relief at their own
	# scale. The 0.32 m aperture uprights need the highest frequency in the
	# fleet precisely because they are narrow: at hull frequency less than one
	# panel feature crosses the bar. See the honesty note on the Arrow about how
	# small the relief contribution measures under current lighting. No albedo
	# texture is bound anywhere here, so the hull, accent and cargo tints the
	# fleet colour floors measure are exactly as authored.
	ShipSurfaceDetail.bind_structural_detail(_jovian_materials.structure, hull_normal, 2.0, 1.20)
	ShipSurfaceDetail.bind_structural_detail(_jovian_materials.dark, hull_normal, 4.0, 0.90)
	ShipSurfaceDetail.bind_structural_detail(_jovian_materials.amber, hull_normal, 5.0, 1.30)
	ShipSurfaceDetail.bind_structural_detail(_jovian_materials.cargo_blue, hull_normal, 2.0, 1.20)
	ShipSurfaceDetail.bind_structural_detail(_jovian_materials.deck, hull_normal, 2.2, 1.00)


func get_variant_materials() -> Dictionary:
	return _jovian_materials


func _relocate_and_restyle_cockpit(
		cockpit: Node3D,
		canopy: Node3D,
		hinge_bar: Node3D,
		hinge_mounts: Array[Node]
	) -> void:
	const COCKPIT_SHIFT := Vector3(0.0, -1.38, -8.15)
	if cockpit != null:
		cockpit.position += COCKPIT_SHIFT
		cockpit.set_meta("space_id", &"pilot_cockpit")
		var rear_wall := cockpit.get_node_or_null("RearPressureWall") as MeshInstance3D
		if rear_wall != null:
			# The freighter connects this former fighter rear bulkhead to a real
			# passenger passage. A new open pressure frame replaces the solid panel.
			rear_wall.visible = false
		for surface in cockpit.find_children("*Sidewall", "MeshInstance3D", true, false):
			(surface as MeshInstance3D).material_override = _jovian_materials.structure
		for surface in cockpit.find_children("*Sill", "MeshInstance3D", true, false):
			(surface as MeshInstance3D).material_override = _jovian_materials.amber
		for display in cockpit.find_children("*Display", "MeshInstance3D", true, false):
			(display as MeshInstance3D).material_override = _jovian_materials.display
	if canopy != null:
		canopy.position += COCKPIT_SHIFT
		for glass in canopy.find_children("CanopyGlass", "MeshInstance3D", true, false):
			(glass as MeshInstance3D).material_override = _jovian_materials.glass
		for frame in canopy.find_children("*Canopy*Frame", "MeshInstance3D", true, false):
			(frame as MeshInstance3D).material_override = _jovian_materials.structure
		for rail in canopy.find_children("*Canopy*Rail", "MeshInstance3D", true, false):
			(rail as MeshInstance3D).material_override = _jovian_materials.amber
	if hinge_bar != null:
		hinge_bar.position += COCKPIT_SHIFT
		(hinge_bar as MeshInstance3D).material_override = _jovian_materials.structure
	for mount in hinge_mounts:
		var mount_3d := mount as Node3D
		mount_3d.position += COCKPIT_SHIFT
		if mount_3d is MeshInstance3D:
			(mount_3d as MeshInstance3D).material_override = _jovian_materials.amber


func _build_exterior() -> void:
	# The flight deck is a smooth low nose supporting the retained physical
	# cockpit. It does not enclose the cabin with a solid collision primitive.
	_loft_hull(
		_jovian_visual,
		"ForwardFlightDeck",
		Vector3(0.0, -0.02, 0.0),
		PackedVector3Array([
			Vector3(0.18, 0.08, -14.0),
			Vector3(2.1, 0.3, -12.4),
			Vector3(3.35, 0.43, -10.25),
			Vector3(4.15, 0.54, -7.2),
			Vector3(4.5, 0.48, -4.4),
		]),
		_jovian_materials.hull_warm,
		28
	)
	_shoulder_rail_joint_mesh = SphereMesh.new()
	_shoulder_rail_joint_mesh.radius = SHOULDER_RAIL_JOINT_RADIUS
	_shoulder_rail_joint_mesh.height = SHOULDER_RAIL_JOINT_RADIUS * 2.0
	_shoulder_rail_joint_mesh.radial_segments = SHOULDER_RAIL_JOINT_RADIAL_SEGMENTS
	_shoulder_rail_joint_mesh.rings = SHOULDER_RAIL_JOINT_RINGS
	_shoulder_rail_joint_mesh.material = _jovian_materials.teal
	# Long shoulder volumes carry load and engines outside the open central
	# interior. Their dense lofts provide a materially larger, non-box silhouette.
	for side_index in 2:
		var side := -1.0 if side_index == 0 else 1.0
		var side_name := "Port" if side < 0.0 else "Starboard"
		if side < 0.0:
			# Two pressure-shell sections leave a true four-metre port aperture.
			# The visual opening matches the split collision volumes below.
			_loft_hull(
				_jovian_visual,
				"PortCargoShoulder",
				Vector3(side * 6.25, 2.05, 0.0),
				PackedVector3Array([
					Vector3(0.62, 0.52, -7.8),
					Vector3(1.62, 1.72, -5.5),
					Vector3(1.82, 2.02, 0.8),
					Vector3(1.78, 1.98, 1.12),
				]),
				_jovian_materials.hull_cool,
				24
			)
			_loft_hull(
				_jovian_visual,
				"PortAftCargoShoulder",
				Vector3(side * 6.25, 2.05, 0.0),
				PackedVector3Array([
					Vector3(1.78, 1.98, 5.28),
					Vector3(1.8, 2.0, 5.62),
					Vector3(1.75, 1.92, 8.7),
					Vector3(1.32, 1.52, 11.2),
				]),
				_jovian_materials.hull_cool,
				24
			)
		else:
			_loft_hull(
				_jovian_visual,
				"StarboardCargoShoulder",
				Vector3(side * 6.25, 2.05, 0.0),
				PackedVector3Array([
					Vector3(0.62, 0.52, -7.8),
					Vector3(1.62, 1.72, -5.5),
					Vector3(1.82, 2.02, 1.5),
					Vector3(1.75, 1.92, 8.7),
					Vector3(1.32, 1.52, 11.2),
				]),
				_jovian_materials.hull_cool,
				24
			)
		# Recessed service spine and panel strips break the broad fairing without
		# covering the cargo aperture on the port side.
		if side < 0.0:
			_curve_tube(_jovian_visual, "PortForwardShoulderRail", PackedVector3Array([
				Vector3(-7.55, 3.2, -4.8), Vector3(-7.8, 3.34, 0.95),
			]), 0.13, _jovian_materials.teal, _shoulder_rail_joint_mesh)
			_curve_tube(_jovian_visual, "PortAftShoulderRail", PackedVector3Array([
				Vector3(-7.78, 3.3, 5.48), Vector3(-7.5, 3.1, 8.7),
			]), 0.13, _jovian_materials.teal, _shoulder_rail_joint_mesh)
		else:
			_curve_tube(
				_jovian_visual,
				"StarboardShoulderRail",
				PackedVector3Array([
					Vector3(side * 7.55, 3.2, -4.8),
					Vector3(side * 7.82, 3.35, 1.0),
					Vector3(side * 7.5, 3.1, 8.7),
				]),
				0.13,
				_jovian_materials.teal,
				_shoulder_rail_joint_mesh
			)
		for panel_index in 4:
			if side < 0.0 and panel_index == 2:
				continue
			var panel_z := -4.1 + float(panel_index) * 3.75
			_box(
				_jovian_visual,
				side_name + "ServicePanel%02d" % panel_index,
				Vector3(side * 7.83, 2.12, panel_z),
				Vector3(0.1, 1.48, 2.45),
				_jovian_materials.structure
			)
		_sphere(
			_jovian_visual,
			side_name + "NavigationLight",
			Vector3(side * 8.02, 3.7, 8.4),
			0.16,
			_jovian_materials.nav_red if side < 0.0 else _jovian_materials.nav_green
		)

	# Arched roof and keel members visually unify the load-bearing shoulders.
	_planform_surface(
		_jovian_visual,
		"CargoRoofShell",
		PackedVector3Array([
			Vector3(-5.72, 4.55, -3.0),
			Vector3(5.72, 4.55, -3.0),
			Vector3(5.72, 4.48, 9.3),
			Vector3(-5.72, 4.48, 9.3),
		]),
		0.24,
		_jovian_materials.hull_warm
	)
	_dorsal_cargo_rib_joint_mesh = SphereMesh.new()
	_dorsal_cargo_rib_joint_mesh.radius = DORSAL_CARGO_RIB_JOINT_RADIUS
	_dorsal_cargo_rib_joint_mesh.height = DORSAL_CARGO_RIB_JOINT_RADIUS * 2.0
	_dorsal_cargo_rib_joint_mesh.radial_segments = DORSAL_CARGO_RIB_JOINT_RADIAL_SEGMENTS
	_dorsal_cargo_rib_joint_mesh.rings = DORSAL_CARGO_RIB_JOINT_RINGS
	_dorsal_cargo_rib_joint_mesh.material = _jovian_materials.structure
	for rib_index in DORSAL_CARGO_RIB_COUNT:
		var rib_z := -2.4 + float(rib_index) * 2.72
		_curve_tube(
			_jovian_visual,
			"DorsalCargoRib%02d" % rib_index,
			PackedVector3Array([
				Vector3(-5.55, 4.28, rib_z),
				Vector3(-3.7, 4.72, rib_z),
				Vector3(0.0, 4.9, rib_z),
				Vector3(3.7, 4.72, rib_z),
				Vector3(5.55, 4.28, rib_z),
			]),
			DORSAL_CARGO_RIB_JOINT_RADIUS,
			_jovian_materials.structure,
			_dorsal_cargo_rib_joint_mesh
		)
	_box(_jovian_visual, "VentralKeel", Vector3(0.0, 0.02, 3.25), Vector3(2.2, 0.42, 19.4), _jovian_materials.structure)
	for side in [-1.0, 1.0]:
		_box(_jovian_visual, "VentralLoadRail", Vector3(side * 3.9, 0.15, 2.9), Vector3(0.42, 0.48, 18.5), _jovian_materials.dark)

	# Aft machinery deck, tapered tail bridge, radiators, and restrained colour
	# blocks make the class readable as a utility vessel rather than a fighter.
	_loft_hull(
		_jovian_visual,
		"AftMachinerySpine",
		Vector3(0.0, 2.25, 0.0),
		PackedVector3Array([
			Vector3(4.5, 1.35, 8.4),
			Vector3(4.85, 1.42, 10.5),
			Vector3(3.9, 1.15, 12.25),
			Vector3(2.2, 0.72, 13.35),
		]),
		_jovian_materials.hull_cool,
		24
	)
	for side in [-1.0, 1.0]:
		_planform_surface(
			_jovian_visual,
			"PortRadiator" if side < 0.0 else "StarboardRadiator",
			PackedVector3Array([
				Vector3(side * 4.6, 3.15, 8.9),
				Vector3(side * 8.2, 2.85, 9.45),
				Vector3(side * 8.45, 2.55, 12.0),
				Vector3(side * 4.05, 2.85, 11.55),
			]),
			0.15,
			_jovian_materials.structure
		)
		for stripe_index in 3:
			_box(
				_jovian_visual,
				"PortLoadMark" if side < 0.0 else "StarboardLoadMark",
				Vector3(side * 7.88, 1.15, -1.3 + stripe_index * 1.1),
				Vector3(0.12, 0.42, 0.72),
				_jovian_materials.amber,
				Vector3(0.0, 0.0, side * deg_to_rad(18.0))
			)

	# The deployed ramp and frame are deliberately obvious from the berth. The
	# opening remains geometrically clear all the way to the cargo deck.
	# A 20-degree rise gives the wedge's walkable upper surface y=-1.25 at
	# x=-10.45 and y=+0.48 at the cargo-deck threshold x=-5.725. Unlike a
	# rotated box, its flat underside never extends below the landing plane.
	var ramp_angle := deg_to_rad(20.0)
	_ramp_wedge(
		_jovian_visual,
		"PortCargoRamp",
		-10.45,
		-5.725,
		-1.25,
		-1.25,
		0.48,
		3.2,
		1.7,
		_jovian_materials.deck
	)
	for rail_z in [1.62, 4.78]:
		_box(
			_jovian_visual,
			"CargoRampEdgeRail",
			Vector3(-7.9, -0.22, rail_z),
			Vector3(5.15, 0.24, 0.16),
			_jovian_materials.amber,
			Vector3(0.0, 0.0, ramp_angle)
		)
	for vertical_z in [1.25, 5.15]:
		_box(_jovian_visual, "CargoApertureUpright", Vector3(-5.78, 2.38, vertical_z), Vector3(0.32, 3.75, 0.3), _jovian_materials.amber)
	_box(_jovian_visual, "CargoApertureHeader", Vector3(-5.78, 4.22, 3.2), Vector3(0.34, 0.3, 4.2), _jovian_materials.amber)
	_box(_jovian_visual, "CargoRampActuator", Vector3(-6.1, 0.12, 1.3), Vector3(0.24, 0.24, 1.35), _jovian_materials.structure, Vector3(0.0, 0.0, ramp_angle))
	_box(_jovian_visual, "CargoRampActuator", Vector3(-6.1, 0.12, 5.1), Vector3(0.24, 0.24, 1.35), _jovian_materials.structure, Vector3(0.0, 0.0, ramp_angle))


func _build_connected_interior() -> void:
	_walkable_interior = Node3D.new()
	_walkable_interior.name = "WalkableInterior"
	_walkable_interior.set_meta("space_id", &"jovian_connected_interior")
	_walkable_interior.set_meta("geometry_status", EVIDENCE_STATUS)
	_walkable_interior.set_meta("detached_interior", false)
	_walkable_interior.set_meta("historically_authenticated_layout", false)
	# This must be a direct child of the physical ship, not the banked exterior
	# visual root. Its deck meshes, direct hull colliders, occupancy volume, and
	# MovingInteriorFrame therefore share one authoritative rigid transform.
	add_child(_walkable_interior)
	var cockpit := _jovian_visual.get_node_or_null("CockpitInterior") as Node3D
	if cockpit != null:
		cockpit.reparent(_walkable_interior, true)

	_build_cargo_bay()
	_build_passenger_cabin()
	_build_interior_route_and_markers()


## Stable per-station suffix shared by a cargo unit's drawn meshes and its
## colliders, so `CargoContainerPort00` and `CargoContainerCollisionPort00` name
## the same crate.
static func cargo_unit_suffix(index: int) -> String:
	var anchor := CARGO_UNIT_ANCHORS[index]
	return "%s%02d" % ["Port" if anchor.x < 0.0 else "Starboard", index / 2]


func _build_cargo_bay() -> void:
	_cargo_bay = Node3D.new()
	_cargo_bay.name = "CargoBay"
	_cargo_bay.set_meta("space_id", &"cargo_bay")
	_cargo_bay.set_meta("capacity_status", &"provisional")
	_walkable_interior.add_child(_cargo_bay)
	_box(_cargo_bay, "CargoDeck", Vector3(0.0, 0.5, 3.15), Vector3(11.3, 0.18, 12.1), _jovian_materials.deck)
	# Slim inlaid lanes leave an unobstructed route from ramp to forward cabin.
	for lane_x in [-2.15, 0.0, 2.15]:
		_box(_cargo_bay, "CargoDeckLane", Vector3(lane_x, 0.61, 3.15), Vector3(0.11, 0.025, 11.4), _jovian_materials.teal)
	# Starboard wall is continuous. The port wall is split around the open ramp.
	_box(_cargo_bay, "StarboardInnerWall", Vector3(5.64, 2.5, 3.15), Vector3(0.18, 3.86, 12.0), _jovian_materials.structure)
	_box(_cargo_bay, "PortInnerWallForward", Vector3(-5.64, 2.5, -0.9), Vector3(0.18, 3.86, 3.65), _jovian_materials.structure)
	_box(_cargo_bay, "PortInnerWallAft", Vector3(-5.64, 2.5, 7.15), Vector3(0.18, 3.86, 4.05), _jovian_materials.structure)
	_box(_cargo_bay, "AftPressureWall", Vector3(0.0, 2.5, 9.17), Vector3(11.3, 3.86, 0.18), _jovian_materials.structure)
	# Forward bulkhead wraps a 2.8 m passage to the passenger cabin.
	for side in [-1.0, 1.0]:
		_box(_cargo_bay, "ForwardBulkheadWing", Vector3(side * 3.55, 2.5, -2.88), Vector3(4.2, 3.86, 0.18), _jovian_materials.structure)
	_box(_cargo_bay, "ForwardBulkheadHeader", Vector3(0.0, 4.12, -2.88), Vector3(2.95, 0.62, 0.18), _jovian_materials.amber)
	# Curved interior frames expose the true structural scale without closing the
	# route. All fixtures are children of the moving ship.
	_cargo_frame_joint_mesh = SphereMesh.new()
	_cargo_frame_joint_mesh.radius = CARGO_FRAME_JOINT_RADIUS
	_cargo_frame_joint_mesh.height = CARGO_FRAME_JOINT_RADIUS * 2.0
	_cargo_frame_joint_mesh.radial_segments = CARGO_FRAME_JOINT_RADIAL_SEGMENTS
	_cargo_frame_joint_mesh.rings = CARGO_FRAME_JOINT_RINGS
	_cargo_frame_joint_mesh.material = _jovian_materials.hull_cool
	for frame_index in CARGO_FRAME_COUNT:
		var frame_z := CARGO_FRAME_START_Z + float(frame_index) * CARGO_FRAME_Z_STEP
		_curve_tube(
			_cargo_bay,
			"CargoFrame%02d" % frame_index,
			PackedVector3Array([
				Vector3(-5.35, 0.72, frame_z),
				Vector3(-5.35, 4.15, frame_z),
				Vector3(0.0, 4.48, frame_z),
				Vector3(5.35, 4.15, frame_z),
				Vector3(5.35, 0.72, frame_z),
			]),
			CARGO_FRAME_JOINT_RADIUS,
			_jovian_materials.hull_cool,
			_cargo_frame_joint_mesh
		)
	# Four stable tie-down hardpoints and their secured cargo units. The central
	# lane and door-to-cabin diagonal remain at least 2 m wide. Positions come from
	# `CARGO_UNIT_ANCHORS`, which `_build_collision` also builds the freight's
	# colliders from, so the drawn crate and the solid crate cannot drift apart.
	for index in CARGO_UNIT_ANCHORS.size():
		var position := CARGO_UNIT_ANCHORS[index]
		var side := signf(position.x)
		var row := index / 2
		var suffix := cargo_unit_suffix(index)
		var hardpoint := Marker3D.new()
		hardpoint.name = ("Port" if side < 0.0 else "Starboard") + "CargoHardpoint%02d" % row
		hardpoint.position = position
		hardpoint.set_meta("hardpoint_id", StringName("cargo_%s_%02d" % ["port" if side < 0.0 else "starboard", row]))
		_cargo_bay.add_child(hardpoint)
		_cargo_hardpoints.append(hardpoint)
		# Named per station rather than four times over. Godot renames same-named
		# siblings to generated identifiers, which is how four crates could only
		# ever be found as two by name — and an audit that can only see half a
		# roster is how they stayed permeable this long.
		_box(_cargo_bay, "CargoPallet" + suffix, position + Vector3(0.0, CARGO_PALLET_OFFSET_Y, 0.0), CARGO_PALLET_SIZE, _jovian_materials.structure)
		_box(_cargo_bay, "CargoContainer" + suffix, position + Vector3(0.0, CARGO_CONTAINER_OFFSET_Y, 0.0), CARGO_CONTAINER_SIZE, _jovian_materials.cargo_blue)
		for band_index in CARGO_RESTRAINT_BAND_Z.size():
			_box(
				_cargo_bay,
				"CargoRestraint%s%02d" % [suffix, band_index],
				position + Vector3(0.0, CARGO_RESTRAINT_OFFSET_Y, CARGO_RESTRAINT_BAND_Z[band_index]),
				CARGO_RESTRAINT_SIZE,
				_jovian_materials.amber
			)
	# Rear corner lockers add believable stowage without obstructing egress.
	for side in [-1.0, 1.0]:
		_box(_cargo_bay, "ServiceLocker", Vector3(side * 4.75, 1.52, 8.25), Vector3(1.25, 1.9, 1.15), _jovian_materials.hull_cool)
		_box(_cargo_bay, "LockerDisplay", Vector3(side * 4.1, 1.62, 8.25), Vector3(0.03, 0.38, 0.52), _jovian_materials.display)
	# Warm-neutral practicals illuminate the actual interior, not a detached set.
	for light_z in [-1.25, 2.85, 6.95]:
		_box(_cargo_bay, "CargoCeilingLight", Vector3(0.0, 4.36, light_z), Vector3(2.1, 0.05, 0.18), _jovian_materials.interior_light)
		var cargo_light := OmniLight3D.new()
		cargo_light.name = "CargoPracticalLight"
		cargo_light.position = Vector3(0.0, 4.12, light_z)
		cargo_light.light_color = Color("d7fff2")
		cargo_light.light_energy = 1.1
		cargo_light.omni_range = 6.8
		cargo_light.shadow_enabled = true
		_cargo_bay.add_child(cargo_light)


func _rounded_box_from_mesh(
	parent: Node3D,
	node_name: String,
	position_value: Vector3,
	mesh: ArrayMesh,
	rotation_value := Vector3.ZERO
	) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = position_value
	instance.rotation = rotation_value
	instance.mesh = mesh
	parent.add_child(instance)
	return instance


func _build_passenger_cabin() -> void:
	_passenger_cabin = Node3D.new()
	_passenger_cabin.name = "PassengerCabin"
	_passenger_cabin.set_meta("space_id", &"passenger_cabin")
	_passenger_cabin.set_meta("capacity_status", &"provisional")
	_walkable_interior.add_child(_passenger_cabin)
	_passenger_seat_base_mesh = _rounded_box_mesh(PASSENGER_SEAT_BASE_SIZE, _jovian_materials.cabin_cloth)
	_passenger_seat_back_mesh = _rounded_box_mesh(PASSENGER_SEAT_BACK_SIZE, _jovian_materials.cabin_cloth)
	_passenger_seat_harness_mesh = _rounded_box_mesh(PASSENGER_SEAT_HARNESS_SIZE, _jovian_materials.amber)
	_passenger_cabin_light_strip_mesh = _rounded_box_mesh(
		PASSENGER_CABIN_LIGHT_STRIP_SIZE, _jovian_materials.interior_light
	)
	_box(_passenger_cabin, "PassengerDeck", Vector3(0.0, 0.5, -5.25), Vector3(6.9, 0.18, 4.65), _jovian_materials.deck)
	_box(_passenger_cabin, "PassengerRoof", Vector3(0.0, 3.82, -5.25), Vector3(6.9, 0.16, 4.65), _jovian_materials.hull_cool)
	for side in [-1.0, 1.0]:
		_box(_passenger_cabin, "CabinSidewall", Vector3(side * 3.36, 2.15, -5.25), Vector3(0.18, 3.35, 4.6), _jovian_materials.structure)
		_rounded_box_from_mesh(
			_passenger_cabin,
			"CabinLightStrip",
			Vector3(side * 3.23, 3.46, -5.25),
			_passenger_cabin_light_strip_mesh
		)
		# Three side-facing seats per side keep a clear central passage to the
		# inherited cockpit. Their anchors are explicit future passenger contracts.
		for seat_index in 3:
			var seat_z := -6.55 + float(seat_index) * 1.3
			var seat_root := Node3D.new()
			seat_root.name = ("Port" if side < 0.0 else "Starboard") + "PassengerSeat%02d" % seat_index
			seat_root.position = Vector3(side * 2.62, 0.0, seat_z)
			seat_root.rotation.y = -side * PI * 0.5
			_passenger_cabin.add_child(seat_root)
			_rounded_box_from_mesh(seat_root, "SeatBase", Vector3(0.0, 0.88, 0.0), _passenger_seat_base_mesh)
			_rounded_box_from_mesh(seat_root, "SeatBack", Vector3(0.0, 1.42, 0.36), _passenger_seat_back_mesh, Vector3(deg_to_rad(8.0), 0.0, 0.0))
			_rounded_box_from_mesh(seat_root, "Harness", Vector3(0.0, 1.42, 0.25), _passenger_seat_harness_mesh)
			var anchor := Marker3D.new()
			anchor.name = "PassengerAnchor"
			anchor.position = Vector3(0.0, 0.24, -0.02)
			anchor.set_meta("seat_id", StringName("passenger_%s_%02d" % ["port" if side < 0.0 else "starboard", seat_index]))
			seat_root.add_child(anchor)
			_passenger_seat_anchors.append(anchor)
	# Open frames make both forward and aft connections visually explicit.
	for bulkhead_z in [-7.48, -3.0]:
		for side in [-1.0, 1.0]:
			_box(_passenger_cabin, "CabinPortalUpright", Vector3(side * 1.45, 2.1, bulkhead_z), Vector3(0.18, 3.25, 0.2), _jovian_materials.amber)
		_box(_passenger_cabin, "CabinPortalHeader", Vector3(0.0, 3.68, bulkhead_z), Vector3(3.05, 0.18, 0.2), _jovian_materials.amber)
	_box(_passenger_cabin, "CabinStatusPanel", Vector3(0.0, 2.5, -3.13), Vector3(1.05, 0.58, 0.04), _jovian_materials.display)
	var cabin_light := OmniLight3D.new()
	cabin_light.name = "PassengerPracticalLight"
	cabin_light.position = Vector3(0.0, 3.52, -5.25)
	cabin_light.light_color = Color("e8fff6")
	cabin_light.light_energy = 0.95
	cabin_light.omni_range = 5.2
	cabin_light.shadow_enabled = true
	_passenger_cabin.add_child(cabin_light)


func _build_interior_route_and_markers() -> void:
	# A short same-level bridge joins the passenger room to the flight deck.
	_box(_walkable_interior, "CockpitConnectorDeck", Vector3(0.0, 0.5, -8.0), Vector3(2.75, 0.18, 1.45), _jovian_materials.deck)
	for side in [-1.0, 1.0]:
		_box(_walkable_interior, "CockpitConnectorRail", Vector3(side * 1.42, 1.75, -8.0), Vector3(0.12, 2.4, 1.42), _jovian_materials.structure)
	var cockpit := _walkable_interior.get_node_or_null(^"CockpitInterior") as Node3D
	if cockpit != null:
		_box(cockpit, "CopilotSeatBase", Vector3(1.05, 1.18, -0.02), Vector3(0.78, 0.18, 0.82), _jovian_materials.cabin_cloth)
		_box(cockpit, "CopilotSeatBack", Vector3(1.05, 1.72, 0.34), Vector3(0.78, 0.96, 0.16), _jovian_materials.cabin_cloth, Vector3(deg_to_rad(8.0), 0.0, 0.0))
		var copilot_anchor := Marker3D.new()
		copilot_anchor.name = "CopilotSeatAnchor"
		copilot_anchor.position = Vector3(1.05, 1.44, -0.02)
		copilot_anchor.set_meta("seat_id", COPILOT_SEAT_ID)
		copilot_anchor.set_meta("role_id", COPILOT_ROLE_ID)
		copilot_anchor.set_meta("route_id", &"pilot_cockpit")
		cockpit.add_child(copilot_anchor)

	_interior_access_marker = Marker3D.new()
	_interior_access_marker.name = "InteriorAccessMarker"
	_interior_access_marker.position = Vector3(-10.05, -1.08, 3.2)
	_interior_access_marker.rotation.y = PI * 0.5
	_interior_access_marker.set_meta("route_id", &"port_cargo_ramp")
	_walkable_interior.add_child(_interior_access_marker)
	_interior_deck_marker = Marker3D.new()
	_interior_deck_marker.name = "InteriorDeckMarker"
	_interior_deck_marker.position = Vector3(-5.05, 0.64, 3.2)
	_interior_deck_marker.rotation.y = PI * 0.5
	_interior_deck_marker.set_meta("space_id", &"cargo_bay")
	_walkable_interior.add_child(_interior_deck_marker)
	_interior_exit_marker = Marker3D.new()
	_interior_exit_marker.name = "InteriorExitMarker"
	_interior_exit_marker.position = Vector3(-10.7, -1.08, 3.2)
	_interior_exit_marker.rotation.y = PI * 0.5
	_walkable_interior.add_child(_interior_exit_marker)
	# Standing pose used when the pilot leaves the seat away from a berth. It is
	# a real ship-local marker rather than a computed offset so the cabin route,
	# the containment recall, and the re-boarding prompt all name one place.
	_cabin_stand_marker = Marker3D.new()
	_cabin_stand_marker.name = "CabinStandMarker"
	_cabin_stand_marker.position = CABIN_STAND_LOCAL_ORIGIN
	_cabin_stand_marker.rotation.y = CABIN_STAND_LOCAL_YAW
	_cabin_stand_marker.set_meta("space_id", &"cabin_stand")
	_walkable_interior.add_child(_cabin_stand_marker)

	# Direct CharacterBody collision shapes below make the interior physically
	# walkable; this volume drives production MovingInteriorFrame occupancy while
	# keeping every occupant in the same world-space scene.
	_occupant_volume = Area3D.new()
	_occupant_volume.name = "InteriorOccupantVolume"
	_occupant_volume.collision_layer = PhysicsLayers.INTERACTABLE_AREA_LAYER
	_occupant_volume.collision_mask = PhysicsLayers.PLAYER_BODY_LAYER
	_occupant_volume.monitoring = true
	_occupant_volume.monitorable = false
	_occupant_volume.set_meta("ship_local_bounds", INTERIOR_BOUNDS)
	_walkable_interior.add_child(_occupant_volume)
	var volume_shape := CollisionShape3D.new()
	volume_shape.name = "InteriorBoundsShape"
	volume_shape.position = INTERIOR_BOUNDS.get_center()
	var box := BoxShape3D.new()
	box.size = INTERIOR_BOUNDS.size
	volume_shape.shape = box
	_occupant_volume.add_child(volume_shape)


func _build_propulsion_and_gear() -> void:
	for side_index in 2:
		var side := -1.0 if side_index == 0 else 1.0
		var side_name := "Port" if side < 0.0 else "Starboard"
		for vertical_index in 2:
			var engine_y := 1.15 + float(vertical_index) * 2.25
			var engine_x := side * (5.05 + float(vertical_index) * 1.35)
			var prefix := side_name + ("Lower" if vertical_index == 0 else "Upper")
			_cylinder(_jovian_visual, prefix + "EngineHousing", Vector3(engine_x, engine_y, 11.65), 0.84, 3.0, _jovian_materials.structure, Vector3(90.0, 0.0, 0.0))
			_cylinder(_jovian_visual, prefix + "EngineCollar", Vector3(engine_x, engine_y, 13.05), 1.02, 0.42, _jovian_materials.hull_cool, Vector3(90.0, 0.0, 0.0))
			_cylinder(_jovian_visual, prefix + "EngineCore", Vector3(engine_x, engine_y, 13.31), 0.57, 0.2, _jovian_materials.engine, Vector3(90.0, 0.0, 0.0))
			var plume := _cylinder(_jovian_visual, prefix + "EnginePlume", Vector3(engine_x, engine_y, 13.8), 0.38, 1.1, _jovian_materials.engine, Vector3(90.0, 0.0, 0.0))
			_engine_plumes.append(plume)
			var light := OmniLight3D.new()
			light.name = prefix + "EngineLight"
			light.position = Vector3(engine_x, engine_y, 13.45)
			light.light_color = ENGINE_AQUA
			light.light_energy = 0.0
			light.omni_range = 8.0
			light.shadow_enabled = false
			_jovian_visual.add_child(light)
			_jovian_engine_lights.append(light)

	# Four wide landing bogies support the heavier visual mass and establish a
	# stable parked contact plane at y=-1.25 relative to the ship root.
	for side in [-1.0, 1.0]:
		for z_position in [-5.8, 7.3]:
			_box(_jovian_visual, "LandingBogieStrut", Vector3(side * 4.85, -0.42, z_position), Vector3(0.34, 1.5, 0.34), _jovian_materials.dark, Vector3(0.0, 0.0, side * deg_to_rad(-7.0)))
			_box(_jovian_visual, "LandingBogieFoot", Vector3(side * 5.05, -1.14, z_position), Vector3(1.65, 0.18, 2.2), _jovian_materials.structure)
			_cylinder(_jovian_visual, "LandingDamper", Vector3(side * 4.64, -0.22, z_position), 0.13, 1.25, _jovian_materials.amber)

	# Twin defensive pulse mounts communicate capability without turning the
	# freighter into a gunship. Their broad bases and compact receivers read as
	# ship-scale defensive hardware, while the barrels stop exactly at the fixed
	# muzzle plane. The common weapon lifecycle continues to use root markers.
	for side in [-1.0, 1.0]:
		var prefix := "Port" if side < 0.0 else "Starboard"
		_mark_defensive_weapon_detail(_cylinder(
			_jovian_visual, prefix + "DefensiveTurretBase",
			Vector3(side * 5.15, 3.72, -5.55),
			DEFENSIVE_TURRET_BASE_RADIUS, DEFENSIVE_TURRET_BASE_HEIGHT,
			_jovian_materials.structure
		), &"mount_base")
		_mark_defensive_weapon_detail(_cylinder(
			_jovian_visual, prefix + "DefensiveTurretRotationCollar",
			Vector3(side * 5.15, 3.96, -5.55), 0.5, 0.16,
			_jovian_materials.hull_cool
		), &"rotation_collar")
		_mark_defensive_weapon_detail(_box(
			_jovian_visual, prefix + "DefensiveTurretReceiver",
			Vector3(side * 5.15, 3.78, -5.72), Vector3(0.76, 0.48, 0.7),
			_jovian_materials.structure
		), &"receiver")
		_mark_defensive_weapon_detail(_box(
			_jovian_visual, prefix + "DefensiveTurretBarrelShroud",
			Vector3(side * 5.15, 3.76, -6.02), Vector3(0.56, 0.46, 0.72),
			_jovian_materials.hull_cool
		), &"barrel_shroud")
		_mark_defensive_weapon_detail(_cylinder(
			_jovian_visual, prefix + "DefensivePulseBarrel",
			Vector3(side * 5.15, 3.76, -6.175),
			DEFENSIVE_TURRET_BARREL_RADIUS, DEFENSIVE_TURRET_BARREL_LENGTH,
			_jovian_materials.dark, Vector3(90.0, 0.0, 0.0)
		), &"pulse_barrel")
		_mark_defensive_weapon_detail(_cylinder(
			_jovian_visual, prefix + "DefensiveTurretMuzzleCollar",
			Vector3(side * 5.15, 3.76, -6.79), 0.27, 0.2,
			_jovian_materials.structure, Vector3(90.0, 0.0, 0.0)
		), &"muzzle_collar")
		# Its forward face, not its centre, coincides with the firing marker so
		# the new detail does not extend the weapon's visible firing profile.
		_mark_defensive_weapon_detail(_cylinder(
			_jovian_visual, prefix + "DefensiveTurretMuzzleLens",
			Vector3(side * 5.15, 3.76, -6.92), 0.17, 0.06,
			_jovian_materials.teal, Vector3(90.0, 0.0, 0.0)
		), &"muzzle_lens")


func _mark_defensive_weapon_detail(component: MeshInstance3D, component_role: StringName) -> void:
	component.set_meta("interpretation_status", DEFENSIVE_TURRET_STATUS)
	component.set_meta("weapon_role", DEFENSIVE_TURRET_ROLE)
	component.set_meta("component_role", component_role)
	component.set_meta("authenticated_historical_weapon", false)
	component.set_meta("visual_only", true)


func _replace_collision_and_markers() -> void:
	for child in get_children():
		if child is CollisionShape3D:
			remove_child(child)
			child.queue_free()
	# Physical decks form the lower hull and support walking while landed.
	_add_box_collision("CargoDeckCollision", Vector3(0.0, 0.36, 3.15), Vector3(11.45, 0.24, 12.15))
	_add_box_collision("PassengerDeckCollision", Vector3(0.0, 0.36, -5.25), Vector3(7.0, 0.24, 4.72))
	_add_box_collision("CockpitDeckCollision", Vector3(0.0, 0.36, -8.75), Vector3(3.1, 0.24, 3.25))
	_add_box_collision("VentralHullCollision", Vector3(0.0, -0.05, -10.9), Vector3(6.25, 0.65, 6.0))
	# The port shoulder is split around the 3.9 m cargo aperture. No collision
	# volume crosses the exterior-ramp-to-deck path.
	_add_box_collision("StarboardShoulderCollision", Vector3(6.65, 2.0, 1.8), Vector3(2.85, 4.15, 19.0))
	_add_box_collision("PortForwardShoulderCollision", Vector3(-6.65, 2.0, -3.5), Vector3(2.85, 4.15, 8.45))
	_add_box_collision("PortAftShoulderCollision", Vector3(-6.65, 2.0, 7.25), Vector3(2.85, 4.15, 4.15))
	_add_box_collision("CargoRoofCollision", Vector3(0.0, 4.54, 3.15), Vector3(11.6, 0.3, 12.3))
	_add_box_collision("AftHullCollision", Vector3(0.0, 2.0, 10.75), Vector3(10.2, 3.8, 3.0))
	# Interior walls and portal wings preserve a connected central route.
	_add_box_collision("StarboardInteriorWallCollision", Vector3(5.64, 2.5, 3.15), Vector3(0.22, 3.9, 12.0))
	_add_box_collision("PortInteriorWallForwardCollision", Vector3(-5.64, 2.5, -0.9), Vector3(0.22, 3.9, 3.65))
	_add_box_collision("PortInteriorWallAftCollision", Vector3(-5.64, 2.5, 7.15), Vector3(0.22, 3.9, 4.05))
	_add_box_collision("AftPressureWallCollision", Vector3(0.0, 2.5, 9.17), Vector3(11.3, 3.9, 0.22))
	for side in [-1.0, 1.0]:
		_add_box_collision("ForwardBulkheadWingCollision", Vector3(side * 3.55, 2.5, -2.88), Vector3(4.2, 3.9, 0.22))
		_add_box_collision("PassengerSidewallCollision", Vector3(side * 3.36, 2.15, -5.25), Vector3(0.22, 3.4, 4.65))
		# The flight deck had a floor but no sides. That was invisible while the
		# only way onto it was the seat transition; it is load-bearing now that a
		# crew member can walk on to it, because an unenclosed deck edge is a way
		# out of a pressurised hull.
		_add_box_collision(
			("Port" if side < 0.0 else "Starboard") + "CockpitSidewallCollision",
			Vector3(side * 1.66, 1.75, -8.75),
			Vector3(0.22, 2.6, 3.4)
		)
	_add_box_collision("CockpitForwardWallCollision", Vector3(0.0, 1.75, -10.46), Vector3(3.55, 2.6, 0.22))
	# Secured freight is solid. It was presentation-only for as long as the hold
	# was scenery a chase camera flew past; once a crew member could leave the seat
	# and walk it, a crate you walk through — and a chase boom pushed inside a
	# container, which is what `artifacts/cabin_04_walking_the_hold.png` shows — is
	# the same "solid-looking thing with no collision" defect the station sweep
	# closed everywhere else.
	#
	# This was written and reverted once, because it jammed
	# `tests/fleet_role_differentiation_test.gd`, which staged its Jovian approach
	# inside the hull and walked a straight line through the port crates. That
	# suite's approach has been restaged onto the berth apron outside the hull,
	# where its subject — role differentiation and boarding through the exterior
	# pilot hatch — actually lives. The two halves went in together.
	#
	# Built from `CARGO_UNIT_ANCHORS`, the same roster `_build_cargo_bay` draws
	# from, so the collider and the crate cannot drift apart. Sizes are the drawn
	# sizes exactly; the restraint bands are inside the container's own volume and
	# need nothing of their own.
	for index in CARGO_UNIT_ANCHORS.size():
		var anchor := CARGO_UNIT_ANCHORS[index]
		var suffix := cargo_unit_suffix(index)
		_add_box_collision(
			"CargoPalletCollision" + suffix,
			anchor + Vector3(0.0, CARGO_PALLET_OFFSET_Y, 0.0),
			CARGO_PALLET_SIZE
		)
		_add_box_collision(
			"CargoContainerCollision" + suffix,
			anchor + Vector3(0.0, CARGO_CONTAINER_OFFSET_Y, 0.0),
			CARGO_CONTAINER_SIZE
		)
	# The ramp is a real sloped ship-owned collider, aligned with its visual.
	_add_ramp_wedge_collision(
		"PortCargoRampCollision",
		-10.45,
		-5.725,
		-1.25,
		-1.25,
		0.48,
		3.2,
		1.7
	)

	var boarding := get_node_or_null("BoardingPoint") as Marker3D
	var exit := get_node_or_null("ExitPoint") as Marker3D
	var left_muzzle := get_node_or_null("LeftMuzzle") as Marker3D
	var right_muzzle := get_node_or_null("RightMuzzle") as Marker3D
	if boarding != null:
		boarding.position = Vector3(-3.4, -0.52, -8.15)
	if exit != null:
		exit.position = Vector3(-4.7, -1.05, -8.2)
		exit.rotation.y = -PI * 0.5
	if left_muzzle != null:
		left_muzzle.position = Vector3(-5.15, 3.76, -6.95)
	if right_muzzle != null:
		right_muzzle.position = Vector3(5.15, 3.76, -6.95)
	var boarding_area := get_node_or_null("ShipBoardingArea") as Area3D
	if boarding_area != null:
		boarding_area.position = Vector3(-3.4, -0.02, -8.15)
	var camera_rig := get_node_or_null("CameraRig") as Node3D
	if camera_rig != null:
		camera_rig.position = Vector3(0.0, 4.0, 6.5)


func _add_box_collision(
		node_name: String,
		collision_position: Vector3,
		size: Vector3,
		rotation := Vector3.ZERO
	) -> CollisionShape3D:
	var collision := CollisionShape3D.new()
	collision.name = node_name
	collision.position = collision_position
	collision.rotation = rotation
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	add_child(collision)
	return collision


func _add_ramp_wedge_collision(
		node_name: String,
		outer_x: float,
		inner_x: float,
		bottom_y: float,
		outer_top_y: float,
		inner_top_y: float,
		center_z: float,
		half_width_z: float
	) -> CollisionShape3D:
	var collision := CollisionShape3D.new()
	collision.name = node_name
	var shape := ConvexPolygonShape3D.new()
	shape.points = PackedVector3Array([
		Vector3(outer_x, bottom_y, center_z - half_width_z),
		Vector3(outer_x, outer_top_y, center_z - half_width_z),
		Vector3(inner_x, bottom_y, center_z - half_width_z),
		Vector3(inner_x, inner_top_y, center_z - half_width_z),
		Vector3(outer_x, bottom_y, center_z + half_width_z),
		Vector3(outer_x, outer_top_y, center_z + half_width_z),
		Vector3(inner_x, bottom_y, center_z + half_width_z),
		Vector3(inner_x, inner_top_y, center_z + half_width_z),
	])
	collision.shape = shape
	add_child(collision)
	return collision


func _bind_optional_interior_frame() -> void:
	_moving_interior_component = get_node_or_null("MovingInteriorFrame") as MovingInteriorFrame
	if _moving_interior_component == null:
		_moving_interior_component = MovingInteriorFrame.new()
		_moving_interior_component.name = "MovingInteriorFrame"
		add_child(_moving_interior_component)
	_moving_interior_component.set_meta("frame_id", &"jovian_walkable_interior")
	# Ship scenes build their volume after the pre-authored coordinator has run
	# `_ready`; enable automatic monitoring before configure so signal wiring and
	# existing-overlap registration are both active immediately.
	_moving_interior_component.auto_register_from_volume = true
	# PlayerController consumes MovingInteriorFrame.get_frame_gravity directly,
	# so the component's default registration options avoid double correction.
	_moving_interior_component.configure(self, INTERIOR_BOUNDS, _occupant_volume)
	# Occupancy stays owned by the coordinator. The hull only observes it, so a
	# crew member standing on this ship's own deck stops being an obstacle to
	# this ship's own `move_and_slide()` while it is under way. Counting rather
	# than latching keeps the behaviour correct for more than one occupant.
	if not _moving_interior_component.occupant_registered.is_connected(_on_interior_occupant_registered):
		_moving_interior_component.occupant_registered.connect(_on_interior_occupant_registered)
	if not _moving_interior_component.occupant_unregistered.is_connected(_on_interior_occupant_unregistered):
		_moving_interior_component.occupant_unregistered.connect(_on_interior_occupant_unregistered)
	_sync_interior_occupant_collision()
	_moving_interior_component.call_deferred("_register_existing_overlaps")


func _on_interior_occupant_registered(_occupant: Node3D) -> void:
	_sync_interior_occupant_collision()


func _on_interior_occupant_unregistered(
		_occupant: Node3D,
		_exit_velocity: Vector3,
		_reason: StringName
	) -> void:
	_sync_interior_occupant_collision()


func _sync_interior_occupant_collision() -> void:
	_interior_occupant_count = (
		_moving_interior_component.get_occupant_count()
		if _moving_interior_component != null
		else 0
	)
	if is_destroyed():
		# A destroyed hull owns layer 0 / mask 0. Never re-arm it from here.
		return
	collision_mask = (
		PhysicsLayers.SHIP_BODY_MASK & ~PhysicsLayers.PLAYER
		if _interior_occupant_count > 0
		else PhysicsLayers.SHIP_BODY_MASK
	)


func _set_interior_operational(enabled: bool) -> void:
	if _walkable_interior != null:
		_walkable_interior.visible = enabled
	if _occupant_volume != null:
		_occupant_volume.set_deferred(&"monitoring", enabled)
		for child in _occupant_volume.get_children():
			if child is CollisionShape3D:
				(child as CollisionShape3D).set_deferred(&"disabled", not enabled)
	if not enabled and _moving_interior_component != null:
		_moving_interior_component.clear_occupants(true, &"ship_destroyed")
	_sync_interior_occupant_collision()


func _update_jovian_presentation(delta: float) -> void:
	var telemetry := get_telemetry()
	var engine_state := StringName(telemetry.get("engine_state", &"OFFLINE"))
	var engine_level := 0.0
	if engine_state == ENGINE_STARTING:
		engine_level = 0.22 + 0.08 * sin(_elapsed_jovian * 10.0)
	elif engine_state == ENGINE_ONLINE:
		engine_level = 0.46 + clampf(velocity.length() / maxf(maximum_speed, 1.0), 0.0, 1.0) * 0.54
	var damage_presentation := get_damage_presentation()
	if is_instance_valid(damage_presentation):
		engine_level *= clampf(damage_presentation.get_engine_power_multiplier(), 0.0, 1.0)
	for plume in _engine_plumes:
		plume.visible = engine_level > 0.01
		plume.scale.z = lerpf(plume.scale.z, 0.5 + engine_level * 1.25, 1.0 - exp(-6.0 * delta))
	for light in _jovian_engine_lights:
		light.light_energy = engine_level * 2.6


func _sync_jovian_engine_presentation_immediately() -> void:
	var telemetry := get_telemetry()
	var state := StringName(telemetry.get("engine_state", ENGINE_OFFLINE))
	var active := not is_destroyed() and state in [ENGINE_STARTING, ENGINE_ONLINE]
	for plume in _engine_plumes:
		if is_instance_valid(plume):
			plume.visible = active
			if not active:
				plume.scale.z = 0.5
	for light in _jovian_engine_lights:
		if is_instance_valid(light):
			light.light_energy = 0.6 if active and state == ENGINE_STARTING else (1.2 if active else 0.0)


func _sync_variant_engine_presentation_immediately() -> void:
	_sync_jovian_engine_presentation_immediately()


func _apply_jovian_metadata() -> void:
	set_meta("jovian_light_freighter_candidate", true)
	set_meta("evidence_status", EVIDENCE_STATUS)
	set_meta("evidence_scope", EVIDENCE_SCOPE)
	set_meta("name_to_model_status", NAME_TO_MODEL_STATUS)
	set_meta("authenticated_historical_silhouette", false)
	set_meta("connected_walkable_interior", true)
	set_meta("content_note", PROVISIONAL_NOTE)
	set_meta("weapon_class", &"freighter_defensive_pulse")
	set_meta("weapon_visual_status", DEFENSIVE_TURRET_STATUS)
	set_meta("authenticated_historical_weapon", false)
	set_meta("engine_profile", &"heavy_quad_freighter")


func _jovian_material(
		color: Color,
		metallic: float,
		roughness: float,
		emission := Color.BLACK,
		energy := 0.0
	) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = clampf(metallic, 0.0, 1.0)
	material.roughness = clampf(roughness, 0.04, 1.0)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	if energy > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = energy
	return material


func _jovian_glass(color: Color) -> StandardMaterial3D:
	var material := _jovian_material(color, 0.1, 0.09, Color("17464c"), 0.16)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_BACK
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.render_priority = 1
	return material


func _loft_hull(
		parent: Node3D,
		node_name: String,
		origin: Vector3,
		sections: PackedVector3Array,
		material: Material,
		ring_count := 24
	) -> MeshInstance3D:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_material(material)
	for section_index in sections.size():
		var section := sections[section_index]
		for ring_index in ring_count:
			var angle := TAU * float(ring_index) / float(ring_count)
			var cosine := cos(angle)
			var sine := sin(angle)
			var rounded_x := signf(cosine) * pow(absf(cosine), 0.7)
			var rounded_y := signf(sine) * pow(absf(sine), 0.7)
			tool.set_uv(Vector2(float(ring_index) / float(ring_count), float(section_index) / float(maxi(1, sections.size() - 1))))
			tool.add_vertex(Vector3(section.x * rounded_x, section.y * rounded_y, section.z))
	for section_index in sections.size() - 1:
		for ring_index in ring_count:
			var next_ring := (ring_index + 1) % ring_count
			var current := section_index * ring_count + ring_index
			var current_next := section_index * ring_count + next_ring
			var following := (section_index + 1) * ring_count + ring_index
			var following_next := (section_index + 1) * ring_count + next_ring
			# Keep the radial side facing outward. Reversing these triangles makes
			# back-face culling hide the near hull and expose the far inner shell.
			tool.add_index(current)
			tool.add_index(following_next)
			tool.add_index(following)
			tool.add_index(current)
			tool.add_index(current_next)
			tool.add_index(following_next)
	var front_center := sections.size() * ring_count
	tool.add_vertex(Vector3(0.0, 0.0, sections[0].z))
	var rear_center := front_center + 1
	tool.add_vertex(Vector3(0.0, 0.0, sections[sections.size() - 1].z))
	for ring_index in ring_count:
		var next_ring := (ring_index + 1) % ring_count
		tool.add_index(front_center)
		tool.add_index(next_ring)
		tool.add_index(ring_index)
		var rear_base := (sections.size() - 1) * ring_count
		tool.add_index(rear_center)
		tool.add_index(rear_base + ring_index)
		tool.add_index(rear_base + next_ring)
	tool.generate_normals()
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = origin
	instance.mesh = tool.commit()
	parent.add_child(instance)
	return instance


func _planform_surface(
		parent: Node3D,
		node_name: String,
		outline: PackedVector3Array,
		thickness: float,
		material: Material
	) -> MeshInstance3D:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_material(material)
	var half_thickness := thickness * 0.5
	for point in outline:
		tool.add_vertex(point + Vector3.UP * half_thickness)
	for point in outline:
		tool.add_vertex(point - Vector3.UP * half_thickness)
	for triangle in [[0, 1, 2], [0, 2, 3]]:
		tool.add_index(triangle[0])
		tool.add_index(triangle[1])
		tool.add_index(triangle[2])
		tool.add_index(outline.size() + triangle[0])
		tool.add_index(outline.size() + triangle[2])
		tool.add_index(outline.size() + triangle[1])
	for index in outline.size():
		var next := (index + 1) % outline.size()
		tool.add_index(index)
		tool.add_index(outline.size() + index)
		tool.add_index(outline.size() + next)
		tool.add_index(index)
		tool.add_index(outline.size() + next)
		tool.add_index(next)
	tool.generate_normals()
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = tool.commit()
	parent.add_child(instance)
	return instance


func _curve_tube(
		parent: Node3D,
		node_name: String,
		points: PackedVector3Array,
		radius: float,
		material: Material,
		joint_mesh: SphereMesh = null
	) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	parent.add_child(root)
	for index in points.size() - 1:
		var direction := points[index + 1] - points[index]
		var segment := _cylinder(root, "Segment%02d" % index, (points[index] + points[index + 1]) * 0.5, radius, direction.length(), material)
		segment.quaternion = Quaternion(Vector3.UP, direction.normalized())
	for point in points:
		if joint_mesh == null:
			_sphere(root, "CurveJoint", point, radius, material)
		else:
			var joint := MeshInstance3D.new()
			joint.name = "CurveJoint"
			joint.position = point
			joint.mesh = joint_mesh
			root.add_child(joint)
	return root


func _ramp_wedge(
		parent: Node3D,
		node_name: String,
		outer_x: float,
		inner_x: float,
		bottom_y: float,
		outer_top_y: float,
		inner_top_y: float,
		center_z: float,
		half_width_z: float,
		material: Material
	) -> MeshInstance3D:
	var points := PackedVector3Array([
		Vector3(outer_x, bottom_y, center_z - half_width_z),
		Vector3(outer_x, outer_top_y, center_z - half_width_z),
		Vector3(inner_x, bottom_y, center_z - half_width_z),
		Vector3(inner_x, inner_top_y, center_z - half_width_z),
		Vector3(outer_x, bottom_y, center_z + half_width_z),
		Vector3(outer_x, outer_top_y, center_z + half_width_z),
		Vector3(inner_x, bottom_y, center_z + half_width_z),
		Vector3(inner_x, inner_top_y, center_z + half_width_z),
	])
	# Each face is wound outward. The cross-section retains a slim outer lip, so
	# the convex shape remains numerically stable while meeting the apron cleanly.
	var triangles := PackedInt32Array([
		1, 3, 7, 1, 7, 5, # walkable slope
		0, 4, 6, 0, 6, 2, # flat underside
		0, 1, 5, 0, 5, 4, # outer lip
		2, 6, 7, 2, 7, 3, # inner riser
		0, 2, 3, 0, 3, 1, # forward edge
		4, 5, 7, 4, 7, 6, # aft edge
	])
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_material(material)
	for index in triangles:
		var point := points[index]
		tool.set_uv(Vector2(
			inverse_lerp(outer_x, inner_x, point.x),
			inverse_lerp(center_z - half_width_z, center_z + half_width_z, point.z)
		))
		tool.add_vertex(point)
	tool.generate_normals()
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = tool.commit()
	parent.add_child(instance)
	return instance
