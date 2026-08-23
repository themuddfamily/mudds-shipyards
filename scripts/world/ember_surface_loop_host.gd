class_name EmberSurfaceLoopHost
extends Node3D

## Standalone production-actor composition for one complete Ember visit.
##
## The host has no automatic callback. A caller supplies the physics delta after
## each real physics tick. Existing HeroShip, PlayerController, ShipBerth, and
## ShipBoardingArea APIs own all actor movement and embodiment; this host only
## validates current identities, selects a bounded ShipCommand mode, samples the
## existing planetary contracts, and advances PlanetaryTravelSession.

enum Phase {
	IDLE,
	ORBIT_APPROACH,
	DESCENT,
	SURFACE_APPROACH,
	LANDING_APPROACH,
	LANDED,
	DISEMBARKING,
	SURFACE_OUTBOUND,
	ON_FOOT,
	BOARDING,
	REBOARDED,
	TAKEOFF,
	ASCENT,
	ORBIT_RETURN,
	COMPLETED,
	FAILED,
}

const SCHEMA_VERSION := 1
const HOST_ID: StringName = &"ember_surface_loop"
const WORLD_ID: StringName = &"ember_moon"
const BODY_ID: StringName = &"ember_body"
const REGION_ID: StringName = &"ember_caldera"
const TERRAIN_PROFILE_ID: StringName = &"ember_basalt_terrain"
const ORBITAL_FRAME_ID: StringName = &"nearby_sector_orbital"
const LOCATION_GENERATION_META: StringName = &"world_location_generation"
const LOCATION_ID_META: StringName = &"world_location_id"

const WORLD_PATH := "res://assets/world/planets/ember_moon_world.tres"
const TERRAIN_PATH := "res://assets/world/planets/ember_basalt_terrain.tres"
const REGION_PATH := "res://assets/world/planets/ember_caldera_landing_region.tres"
const AUTHORED_SCENE_PATH := "res://scenes/world/planets/ember_moon.tscn"
const ARROW_SCENE_PATH := "res://scenes/ships/arrow_recon_ship.tscn"
const PLAYER_SCENE_PATH := "res://scenes/player/player.tscn"
const EVIDENCE_PATH := "res://docs/EMBER_SURFACE_LOOP_HOST.md"

const APPROACH_ENTRY_REGION_LOCAL_M := Vector3(0.0, 60.0, 300.0)
const APPROACH_ENTRY_POSITION_HALF_EXTENTS_M := Vector3(42.0, 25.0, 75.0)
const APPROACH_ENTRY_MAXIMUM_SPEED_MPS := 12.0
const APPROACH_ENTRY_MAXIMUM_ATTITUDE_DEGREES := 12.0
const APPROACH_CORRIDOR_HULL_MARGIN_M := 0.05
const SURFACE_CLEAR_ALTITUDE_M := 15.0
const ORBIT_RETURN_ALTITUDE_M := 20_000.0
const APPROACH_BRAKE_Z_M := 45.0
const APPROACH_HANDOFF_MAXIMUM_SPEED_MPS := 1.0
const ROUTE_ANCHOR_RADIUS_M := 1.35
const APPROACH_READY_PROBE_SCHEMA_VERSION := 1
const MAX_CALLER_DELTA_SECONDS := PlanetaryTravelSession.MAX_CALLER_PHYSICS_DELTA_SECONDS
const MAX_SAFE_INTEGER := 9_007_199_254_740_991
const ORIGIN_REBASE_RECEIPT_KEYS := [
	"absolute_coordinate",
	"actor_instance_id",
	"actor_kind",
	"adjusted_actor_sample",
	"covered_instance_ids",
	"covered_node_count",
	"ember_streaming",
	"reason",
	"request_id",
	"root_roster",
	"schema_version",
	"source_generation",
	"target_generation",
	"transaction_index",
	"world_translation_delta",
]
const ORIGIN_REBASE_ROOT_RECORD_KEYS := ["instance_id", "mode", "path"]
const ORIGIN_REBASE_SAMPLE_KEYS := [
	"actor_instance_id", "actor_kind", "available", "position",
]


## Immutable, typed declaration and evaluator for the production-reachable
## approach handoff. It freezes the authored corridor rather than inventing a
## second route volume, and only measures caller-owned actor state.
class ApproachEntryEnvelope:
	extends RefCounted

	const SCHEMA_VERSION := 1

	var corridor_id: StringName
	var target_pad_id: StringName
	var corridor_transform_region_local_m: Transform3D
	var corridor_half_extents_m: Vector3
	var entry_position_half_extents_m: Vector3
	var maximum_speed_mps: float
	var maximum_attitude_degrees: float
	var hull_margin_m: float
	var collision_bounds: AABB
	var composition_root_instance_id: int
	var loaded_scene_instance_id: int
	var coordinate_frame_instance_id: int
	var coordinate_frame_generation: int
	var location_generation: int
	var configuration_error: StringName = &""


	func _init(
		p_corridor_id: StringName,
		p_target_pad_id: StringName,
		p_corridor_transform_region_local_m: Transform3D,
		p_corridor_half_extents_m: Vector3,
		p_entry_position_half_extents_m: Vector3,
		p_maximum_speed_mps: float,
		p_maximum_attitude_degrees: float,
		p_hull_margin_m: float,
		p_collision_bounds: AABB,
		p_composition_root_instance_id: int,
		p_loaded_scene_instance_id: int,
		p_coordinate_frame_instance_id: int,
		p_coordinate_frame_generation: int,
		p_location_generation: int
	) -> void:
		corridor_id = p_corridor_id
		target_pad_id = p_target_pad_id
		corridor_transform_region_local_m = p_corridor_transform_region_local_m
		corridor_half_extents_m = p_corridor_half_extents_m
		entry_position_half_extents_m = p_entry_position_half_extents_m
		maximum_speed_mps = p_maximum_speed_mps
		maximum_attitude_degrees = p_maximum_attitude_degrees
		hull_margin_m = p_hull_margin_m
		collision_bounds = p_collision_bounds
		composition_root_instance_id = p_composition_root_instance_id
		loaded_scene_instance_id = p_loaded_scene_instance_id
		coordinate_frame_instance_id = p_coordinate_frame_instance_id
		coordinate_frame_generation = p_coordinate_frame_generation
		location_generation = p_location_generation
		configuration_error = _configuration_rejection()


	func get_snapshot() -> Dictionary:
		return {
			"schema_version": SCHEMA_VERSION,
			"valid": configuration_error.is_empty(),
			"configuration_error": configuration_error,
			"corridor_id": corridor_id,
			"target_pad_id": target_pad_id,
			"corridor_transform_region_local_m": corridor_transform_region_local_m,
			"corridor_half_extents_m": corridor_half_extents_m,
			"entry_position_half_extents_m": entry_position_half_extents_m,
			"maximum_speed_mps": maximum_speed_mps,
			"maximum_attitude_degrees": maximum_attitude_degrees,
			"hull_margin_m": hull_margin_m,
			"collision_bounds": collision_bounds,
			"composition_root_instance_id": composition_root_instance_id,
			"loaded_scene_instance_id": loaded_scene_instance_id,
			"coordinate_frame_instance_id": coordinate_frame_instance_id,
			"coordinate_frame_generation": coordinate_frame_generation,
			"location_generation": location_generation,
			"measurement_only": true,
			"transform_writes": 0,
			"velocity_writes": 0,
		}.duplicate(true)


	func measure(
		landing_root_transform: Transform3D,
		ship_transform: Transform3D,
		ship_velocity: Vector3,
		current_composition_root_instance_id: int,
		composition_topology_current: bool,
		current_loaded_scene_instance_id: int,
		coordinate_frame_identity_current: bool,
		current_coordinate_frame_instance_id: int,
		current_coordinate_frame_generation: int,
		current_scene_location_generation: int,
		current_bootstrap_location_generation: int,
		actor_contract_current: bool
	) -> Dictionary:
		var result := get_snapshot()
		result["accepted"] = false
		result["reason"] = configuration_error
		result["current"] = {
			"composition_root_instance_id": current_composition_root_instance_id,
			"composition_topology_current": composition_topology_current,
			"loaded_scene_instance_id": current_loaded_scene_instance_id,
			"coordinate_frame_identity_current": coordinate_frame_identity_current,
			"coordinate_frame_instance_id": current_coordinate_frame_instance_id,
			"coordinate_frame_generation": current_coordinate_frame_generation,
			"scene_location_generation": current_scene_location_generation,
			"bootstrap_location_generation": current_bootstrap_location_generation,
			"actor_contract_current": actor_contract_current,
		}
		if not configuration_error.is_empty():
			return result.duplicate(true)
		if current_composition_root_instance_id != composition_root_instance_id \
				or not composition_topology_current:
			result.reason = &"approach_entry_composition_root_mismatch"
			return result.duplicate(true)
		if current_loaded_scene_instance_id != loaded_scene_instance_id:
			result.reason = &"approach_entry_loaded_root_mismatch"
			return result.duplicate(true)
		if not coordinate_frame_identity_current \
				or (coordinate_frame_instance_id > 0 \
					and current_coordinate_frame_instance_id \
						!= coordinate_frame_instance_id):
			result.reason = &"approach_entry_frame_identity_mismatch"
			return result.duplicate(true)
		if current_coordinate_frame_generation != coordinate_frame_generation:
			result.reason = &"approach_entry_frame_generation_mismatch"
			return result.duplicate(true)
		if current_scene_location_generation != location_generation \
				or current_bootstrap_location_generation != location_generation:
			result.reason = &"approach_entry_location_generation_mismatch"
			return result.duplicate(true)
		if not actor_contract_current:
			result.reason = &"approach_entry_actor_state_mismatch"
			return result.duplicate(true)
		if not _transform_is_finite(landing_root_transform) \
				or not _transform_is_finite(ship_transform) \
				or not ship_velocity.is_finite():
			result.reason = &"approach_entry_nonfinite_measurement"
			return result.duplicate(true)
		var ship_scale := ship_transform.basis.get_scale()
		if not ship_scale.is_equal_approx(Vector3.ONE) \
				or ship_transform.basis.determinant() <= 0.0:
			result.reason = &"approach_entry_ship_basis_invalid"
			return result.duplicate(true)

		var corridor_world := landing_root_transform \
			* corridor_transform_region_local_m
		var entry_position := corridor_world.affine_inverse() * ship_transform.origin
		var speed := ship_velocity.length()
		var attitude := rad_to_deg(
			Quaternion(corridor_world.basis.orthonormalized()).angle_to(
				Quaternion(ship_transform.basis.orthonormalized())
			)
		)
		var root_inside_entry := _point_inside(
			entry_position, entry_position_half_extents_m, 0.0
		)
		var full_hull_inside_corridor := _oriented_bounds_inside(
			corridor_world, corridor_half_extents_m,
			ship_transform, collision_bounds, hull_margin_m
		)
		result["measurement"] = {
			"position_offset_entry_local_m": entry_position,
			"speed_mps": speed,
			"attitude_degrees": attitude,
			"root_inside_entry_volume": root_inside_entry,
			"full_hull_inside_authored_corridor": full_hull_inside_corridor,
		}
		if not root_inside_entry:
			result.reason = &"approach_entry_position_out_of_bounds"
			return result.duplicate(true)
		if not full_hull_inside_corridor:
			result.reason = &"approach_entry_hull_outside_corridor"
			return result.duplicate(true)
		if speed > maximum_speed_mps:
			result.reason = &"approach_entry_speed_out_of_bounds"
			return result.duplicate(true)
		if attitude > maximum_attitude_degrees:
			result.reason = &"approach_entry_attitude_out_of_bounds"
			return result.duplicate(true)
		result.accepted = true
		result.reason = &"approach_entry_accepted"
		return result.duplicate(true)


	func _configuration_rejection() -> StringName:
		if corridor_id.is_empty() or target_pad_id.is_empty():
			return &"approach_entry_identity_invalid"
		if not _transform_is_finite(corridor_transform_region_local_m) \
				or not corridor_half_extents_m.is_finite() \
				or not entry_position_half_extents_m.is_finite() \
				or not collision_bounds.position.is_finite() \
				or not collision_bounds.size.is_finite():
			return &"approach_entry_declaration_nonfinite"
		if corridor_half_extents_m.x <= 0.0 or corridor_half_extents_m.y <= 0.0 \
				or corridor_half_extents_m.z <= 0.0 \
				or entry_position_half_extents_m.x <= 0.0 \
				or entry_position_half_extents_m.y <= 0.0 \
				or entry_position_half_extents_m.z <= 0.0 \
				or entry_position_half_extents_m.x > corridor_half_extents_m.x \
				or entry_position_half_extents_m.y > corridor_half_extents_m.y \
				or entry_position_half_extents_m.z > corridor_half_extents_m.z:
			return &"approach_entry_extents_invalid"
		if not is_finite(maximum_speed_mps) or maximum_speed_mps <= 0.0 \
				or not is_finite(maximum_attitude_degrees) \
				or maximum_attitude_degrees <= 0.0 \
				or maximum_attitude_degrees > 90.0 \
				or not is_finite(hull_margin_m) or hull_margin_m < 0.0:
			return &"approach_entry_limits_invalid"
		if collision_bounds.size.x <= 0.0 or collision_bounds.size.y <= 0.0 \
				or collision_bounds.size.z <= 0.0:
			return &"approach_entry_collision_bounds_invalid"
		if composition_root_instance_id <= 0:
			return &"approach_entry_composition_root_identity_invalid"
		if loaded_scene_instance_id <= 0:
			return &"approach_entry_loaded_root_identity_invalid"
		if coordinate_frame_generation < 1:
			return &"approach_entry_frame_generation_invalid"
		if location_generation < 1:
			return &"approach_entry_location_generation_invalid"
		return &""


	static func _point_inside(
		point: Vector3, half_extents: Vector3, margin: float
	) -> bool:
		return absf(point.x) <= half_extents.x - margin \
			and absf(point.y) <= half_extents.y - margin \
			and absf(point.z) <= half_extents.z - margin


	static func _oriented_bounds_inside(
		volume_transform: Transform3D,
		half_extents: Vector3,
		body_transform: Transform3D,
		bounds: AABB,
		margin: float
	) -> bool:
		var inverse := volume_transform.affine_inverse()
		for x: float in [bounds.position.x, bounds.end.x]:
			for y: float in [bounds.position.y, bounds.end.y]:
				for z: float in [bounds.position.z, bounds.end.z]:
					var corner := inverse * (body_transform * Vector3(x, y, z))
					if not _point_inside(corner, half_extents, margin):
						return false
		return true


	static func _transform_is_finite(value: Transform3D) -> bool:
		return value.origin.is_finite() and value.basis.x.is_finite() \
			and value.basis.y.is_finite() and value.basis.z.is_finite() \
			and not is_zero_approx(value.basis.determinant())

const OWNED_CAPABILITY_KEYS := [
	"caller_physics_session_clock",
	"travel_session_composition",
	"landing_composition_validation",
	"surface_gravity_multiplier_composition",
	"bounded_ship_command_transport",
	"berth_lease_orchestration",
	"boarding_lifecycle_orchestration",
	"committed_origin_receipt_validation",
	"coordinate_frame_generation_adoption",
	"runtime_command_reservation_return",
	"dependency_failure",
]
const ADJACENT_AUTHORITY_KEYS := [
	"main", "game_flow", "production_streaming_cadence", "input_map",
	"ship_physics", "ship_collision", "player_physics", "player_collision",
	"combat_damage", "reward", "save", "network", "global_terrain",
	"terrain_generation", "collision_generation", "origin_shift", "activity",
	"hud", "audio",
]

const _WORLD: PlanetaryWorldDefinition = preload(WORLD_PATH)
const _TERRAIN: PlanetaryTerrainProfile = preload(TERRAIN_PATH)
const _REGION: PlanetaryLandingRegionDefinition = preload(REGION_PATH)

var _phase := Phase.IDLE
var _generation := 0
var _attachment_generation := 0
var _attached := false
var _bound_once := false
var _mutation_active := false
var _pending_failure_reason: StringName = &""
var _configuration_error: StringName = &""
var _terminal_reason: StringName = &""
var _location_generation := 0
var _coordinate_frame_generation := 0
var _elapsed_seconds := 0.0
var _phase_elapsed_seconds := 0.0
var _transition_count := 0
var _physics_advance_count := 0
var _gravity_sample_count := 0
var _gravity_application_count := 0
var _surface_route_outbound_complete := false
var _surface_route_return_complete := false
var _return_departed_staging := false
var _disembark_requested := false
var _takeoff_requested := false
var _landing_completed_observed := false
var _landing_aborted_reason: StringName = &""
var _disembarking_completed_observed := false
var _boarding_completed_observed := false
var _surface_clear_submitted := false
var _last_gravity_sample: Dictionary = {}
var _last_result: Dictionary = {}
var _berth_token: StringName = &""
var _source_generation := 0
var _composition_root_instance_id := 0
var _loaded_scene_instance_id := 0
var _origin_owner_instance_id := 0
var _origin_binding_instance_id := 0
var _ship_instance_id := 0
var _player_instance_id := 0

var _composition_root: Node
var _bootstrap: EmberMoonStreamingBootstrap
var _origin_owner: CommonWorldOriginRebaseOwner
var _origin_binding: EmberMoonStreamingProductionBinding
var _scene: EmberMoonAuthoredScene
var _berth: EmberSurfaceBerth
var _ship: HeroShip
var _player: PlayerController
var _boarding_area: ShipBoardingArea
var _walkable_body: StaticBody3D
var _landing_root: Node3D
var _frame: PlanetaryCoordinateFrame
var _session: PlanetaryTravelSession
var _gravity_policy: PlanetarySurfaceGravityPolicy
var _command_source: EmberSurfaceLoopCommandSource
var _approach_entry_envelope: ApproachEntryEnvelope
var _original_command_source: ShipCommandSource
var _world_report: Dictionary = {}
var _landing_report: Dictionary = {}
var _landing_identity: Dictionary = {}
var _ship_collision_bounds := AABB()
var _accepted_approach_entry_measurement: Dictionary = {}
var _origin_adoption_count := 0
var _last_origin_adoption_receipt: Dictionary = {}
var _runtime_ownership_returned := false
var _last_runtime_ownership_return_receipt: Dictionary = {}
var _original_ship_piloted := false
var _original_player_control_enabled := false
var _original_player_gravity_multiplier := 1.0
var _original_player_camera_current := false
var _reference_tangent_basis_body := Basis.IDENTITY
var _host_acquired_boarding_reservation := false
var _runtime_bindings_restored := false
var _connections: Array[Dictionary] = []


func _ready() -> void:
	set_process(false)
	set_physics_process(false)


func bind_dependencies(
	bootstrap: EmberMoonStreamingBootstrap,
	berth: EmberSurfaceBerth,
	ship: HeroShip,
	player: PlayerController,
	reference_surface_gravity_mps2: float,
	location_generation: int,
	expected_generation: int = 0,
	expected_attachment_generation: int = 0,
	composition_root: Node = null,
	origin_owner: CommonWorldOriginRebaseOwner = null
) -> Dictionary:
	if _mutation_active:
		return _result(false, &"reentrant_call")
	_mutation_active = true
	if expected_generation != _generation:
		return _finish(false, &"stale_generation")
	if expected_attachment_generation != _attachment_generation:
		return _finish(false, &"stale_attachment_generation")
	if _bound_once:
		return _finish(false, &"single_use_host")
	var resolved_composition_root := composition_root \
		if composition_root != null else self
	var validation := _validate_dependencies(
		bootstrap, berth, ship, player,
		reference_surface_gravity_mps2, location_generation,
		resolved_composition_root, origin_owner
	)
	if not bool(validation.get("accepted", false)):
		_configuration_error = validation.get("reason", &"invalid_configuration") as StringName
		return _finish(false, _configuration_error)

	_composition_root = validation.composition_root as Node
	_composition_root_instance_id = _composition_root.get_instance_id()
	_bootstrap = bootstrap
	_origin_owner = validation.origin_owner as CommonWorldOriginRebaseOwner
	_origin_binding = validation.origin_binding as EmberMoonStreamingProductionBinding
	_scene = validation.scene as EmberMoonAuthoredScene
	_berth = berth
	_ship = ship
	_player = player
	_boarding_area = validation.boarding_area as ShipBoardingArea
	_landing_root = validation.landing_root as Node3D
	_walkable_body = validation.walkable_body as StaticBody3D
	_frame = validation.frame as PlanetaryCoordinateFrame
	_location_generation = location_generation
	_coordinate_frame_generation = _frame.get_generation()
	_loaded_scene_instance_id = _scene.get_instance_id()
	_origin_owner_instance_id = _origin_owner.get_instance_id() \
		if is_instance_valid(_origin_owner) else 0
	_origin_binding_instance_id = _origin_binding.get_instance_id() \
		if is_instance_valid(_origin_binding) else 0
	_ship_instance_id = _ship.get_instance_id()
	_player_instance_id = _player.get_instance_id()
	_world_report = (validation.world_report as Dictionary).duplicate(true)
	_landing_report = (validation.landing_report as Dictionary).duplicate(true)
	_landing_identity = {
		"world_id": WORLD_ID,
		"body_id": BODY_ID,
		"region_id": REGION_ID,
		"terrain_profile_id": TERRAIN_PROFILE_ID,
	}.duplicate(true)
	_gravity_policy = validation.gravity_policy as PlanetarySurfaceGravityPolicy
	_reference_tangent_basis_body = validation.reference_tangent_basis_body as Basis
	_ship_collision_bounds = validation.ship_collision_bounds as AABB
	_approach_entry_envelope = ApproachEntryEnvelope.new(
		StringName(_REGION.approach_corridor_ids[0]),
		StringName(_REGION.approach_corridor_target_pad_ids[0]),
		_REGION.approach_corridor_transforms_region_local_m[0],
		_REGION.approach_corridor_half_extents_m[0],
		APPROACH_ENTRY_POSITION_HALF_EXTENTS_M,
		APPROACH_ENTRY_MAXIMUM_SPEED_MPS,
		APPROACH_ENTRY_MAXIMUM_ATTITUDE_DEGREES,
		APPROACH_CORRIDOR_HULL_MARGIN_M,
		_ship_collision_bounds,
		_composition_root_instance_id,
		_loaded_scene_instance_id,
		_frame.get_instance_id(),
		_coordinate_frame_generation,
		_location_generation
	)
	if not _approach_entry_envelope.configuration_error.is_empty():
		_configuration_error = _approach_entry_envelope.configuration_error
		return _finish(false, _configuration_error)
	_original_command_source = _ship.get_command_source()
	_original_ship_piloted = _ship.is_piloted()
	_original_player_control_enabled = _player.is_control_enabled()
	_original_player_gravity_multiplier = _player.gravity_multiplier
	_original_player_camera_current = _player.get_camera().current

	# Construct the bounded producer while it is still detached from the ship.
	# Installing it, and accepting logical cleanup ownership of the Player's
	# existing reservation, are part of start's measured transaction. A caller may
	# therefore bind early and retry an out-of-envelope start without losing its
	# command source or boarding token.
	_command_source = EmberSurfaceLoopCommandSource.new()
	_command_source.name = "EmberSurfaceLoopCommandSource"
	add_child(_command_source)
	var source_attach := _command_source.attach(0)
	if not bool(source_attach.get("accepted", false)):
		_configuration_error = &"command_source_attach_failed"
		_release_leases()
		_restore_runtime_bindings()
		return _finish(false, _configuration_error)
	_source_generation = _command_source.get_generation()

	_session = PlanetaryTravelSession.new(
		HOST_ID,
		_WORLD.duplicate(true) as PlanetaryWorldDefinition,
		_frame,
		_world_report
	)
	if not _session.is_configuration_valid():
		_configuration_error = &"travel_session_configuration_failed"
		_release_leases()
		_restore_runtime_bindings()
		return _finish(false, _configuration_error)
	var session_attach := _session.attach(
		WORLD_ID, _frame, _coordinate_frame_generation, 0, 0
	)
	if not bool(session_attach.get("accepted", false)):
		_configuration_error = &"travel_session_attach_failed"
		_release_leases()
		_restore_runtime_bindings()
		return _finish(false, _configuration_error)

	_connect_dependency_signals()
	_attachment_generation = _session.get_attachment_generation()
	_attached = true
	_bound_once = true
	_configuration_error = &""
	return _finish(true, &"bound")


func start(
	expected_generation: int,
	expected_attachment_generation: int,
	expected_coordinate_frame_generation: int
) -> Dictionary:
	if _mutation_active:
		return _result(false, &"reentrant_call")
	_mutation_active = true
	var rejection := _token_rejection(
		expected_generation,
		expected_attachment_generation,
		expected_coordinate_frame_generation
	)
	if not rejection.is_empty():
		return _finish(false, rejection)
	if _phase != Phase.IDLE:
		return _finish(false, &"already_started")
	var approach_entry := _measure_approach_entry()
	if not bool(approach_entry.get("accepted", false)):
		var entry_rejection := approach_entry.get(
			"reason", &"approach_entry_rejected"
		) as StringName
		var rejected := _finish(false, entry_rejection)
		rejected["approach_entry"] = approach_entry.duplicate(true)
		_last_result = rejected.duplicate(true)
		return rejected
	var ownership_rejection := _start_ownership_preflight()
	if not ownership_rejection.is_empty():
		return _finish(false, ownership_rejection)
	_accepted_approach_entry_measurement = approach_entry.duplicate(true)
	var bound := _session.bind_landing_composition_report(
		_landing_report, 0, _attachment_generation
	)
	if not bool(bound.get("accepted", false)):
		return _commit_failure(&"landing_composition_bind_failed")
	var started := _session.start(0, _attachment_generation)
	if not bool(started.get("accepted", false)):
		return _commit_failure(&"travel_session_start_failed")
	# All entry/session checks are committed before either external lifecycle
	# capability changes hands. The reservation already belongs to this exact
	# Player; this flag transfers only cleanup responsibility. Installing the
	# command source is verified synchronously before the running phase is visible.
	_host_acquired_boarding_reservation = true
	_ship.set_command_source(_command_source)
	if _ship.get_command_source() != _command_source \
			or _boarding_area.get_reservation_token() != _player:
		_host_acquired_boarding_reservation = false
		return _commit_failure(&"runtime_ownership_commit_failed")
	_generation = _session.get_generation()
	_command_source.set_mode(
		EmberSurfaceLoopCommandSource.Mode.APPROACH, _source_generation
	)
	_set_phase(Phase.ORBIT_APPROACH)
	return _finish(true, &"started")


## Reads the exact authored approach-entry envelope without beginning the
## surface loop. This is deliberately a preflight observation: it neither
## records accepted entry evidence nor acquires a berth lease, boarding cleanup,
## command source, actor transform, velocity, or physics authority.
##
## The caller supplies the current lifecycle tokens and streamed-location
## generation it already owns. The returned measurement is detached, together
## with a point-in-time Host snapshot and audit, so it cannot become a capability
## for `start()` or a mutable view of this Host.
func probe_approach_ready(
		expected_generation: int,
		expected_attachment_generation: int,
		expected_coordinate_frame_generation: int,
		expected_location_generation: int
	) -> Dictionary:
	var reason: StringName = &""
	var measurement: Dictionary = {}
	if _mutation_active:
		reason = &"reentrant_call"
	else:
		reason = _token_rejection(
			expected_generation,
			expected_attachment_generation,
			expected_coordinate_frame_generation
		)
		if reason.is_empty() and expected_location_generation != _location_generation:
			reason = &"stale_location_generation"
		if reason.is_empty() and _phase != Phase.IDLE:
			reason = &"approach_ready_phase_not_idle"
		if reason.is_empty():
			measurement = _measure_approach_entry()
			reason = measurement.get("reason", &"approach_entry_rejected") as StringName
	var snapshot := get_snapshot()
	var audit_snapshot := audit()
	return {
		"schema_version": APPROACH_READY_PROBE_SCHEMA_VERSION,
		"accepted": reason == &"approach_entry_accepted",
		"reason": reason,
		"measurement": measurement.duplicate(true),
		"snapshot": snapshot.duplicate(true),
		"audit": audit_snapshot.duplicate(true),
		"authority": {
			"measurement_only": true,
			"actor_transform_writes": 0,
			"actor_velocity_writes": 0,
			"actor_reparent_calls": 0,
			"command_source_changes": 0,
			"boarding_reservation_mutations": 0,
			"berth_lease_mutations": 0,
		}.duplicate(true),
	}.duplicate(true)


## Call exactly once after each real physics tick with that tick's delta.
func advance_physics(
	delta: float,
	expected_generation: int,
	expected_attachment_generation: int,
	expected_coordinate_frame_generation: int,
	expected_location_generation: int
) -> Dictionary:
	if _mutation_active:
		return _result(false, &"reentrant_call")
	_mutation_active = true
	var rejection := _token_rejection(
		expected_generation,
		expected_attachment_generation,
		expected_coordinate_frame_generation
	)
	if not rejection.is_empty():
		return _finish(false, rejection)
	if expected_location_generation != _location_generation:
		return _finish(false, &"stale_location_generation")
	if _phase in [Phase.IDLE, Phase.COMPLETED, Phase.FAILED]:
		return _finish(false, &"not_running")
	if not is_finite(delta) or delta < 0.0 or delta > MAX_CALLER_DELTA_SECONDS:
		return _finish(false, &"invalid_delta")
	var dependency_failure := _dependency_failure_reason()
	if not dependency_failure.is_empty():
		return _commit_failure(dependency_failure)
	if not _pending_failure_reason.is_empty():
		var pending := _pending_failure_reason
		_pending_failure_reason = &""
		return _commit_failure(pending)
	if is_zero_approx(delta):
		return _finish(true, &"no_delta")
	var clock := _session.advance_physics(delta, _generation, _session.get_attachment_generation())
	if not bool(clock.get("accepted", false)):
		return _commit_failure(&"travel_clock_desynchronized")
	_elapsed_seconds += delta
	_phase_elapsed_seconds += delta
	_physics_advance_count += 1
	var gravity := _sample_and_compose_gravity()
	if not bool(gravity.get("accepted", false)):
		return _commit_failure(gravity.get("reason", &"gravity_sample_rejected") as StringName)
	var phase_result := _advance_phase()
	if not _pending_failure_reason.is_empty():
		var pending_after_phase := _pending_failure_reason
		_pending_failure_reason = &""
		return _commit_failure(pending_after_phase)
	if not bool(phase_result.get("accepted", false)):
		return _commit_failure(phase_result.get("reason", &"phase_advance_failed") as StringName)
	return _finish(true, phase_result.get("reason", &"advanced") as StringName)


func request_disembark(
	expected_generation: int,
	expected_attachment_generation: int
) -> Dictionary:
	return _queue_intent(
		&"disembark", Phase.LANDED,
		expected_generation, expected_attachment_generation
	)


func request_reboard(
	expected_generation: int,
	expected_attachment_generation: int
) -> Dictionary:
	if _mutation_active:
		return _result(false, &"reentrant_call")
	_mutation_active = true
	var rejection := _simple_token_rejection(
		expected_generation, expected_attachment_generation
	)
	if not rejection.is_empty():
		return _finish(false, rejection)
	if _phase != Phase.ON_FOOT or not _surface_route_return_complete:
		return _finish(false, &"return_route_incomplete")
	if not _player_near_boarding_area():
		return _finish(false, &"boarding_area_not_reached")
	if not _boarding_area.try_reserve(_player):
		return _finish(false, &"boarding_reservation_unavailable")
	_host_acquired_boarding_reservation = true
	_player.set_control_enabled(false)
	_ship.set_canopy_open(true, 0.0)
	if not _player.begin_boarding(
		_ship.get_boarding_entry_transform(),
		_ship.get_pilot_seat_anchor(),
		0.6,
		_ship
	):
		_boarding_area.release_reservation(_player)
		_host_acquired_boarding_reservation = false
		_player.set_control_enabled(true)
		return _finish(false, &"boarding_rejected")
	_boarding_completed_observed = false
	_set_phase(Phase.BOARDING)
	return _finish(true, &"boarding_started")


func request_takeoff(
	expected_generation: int,
	expected_attachment_generation: int
) -> Dictionary:
	return _queue_intent(
		&"takeoff", Phase.REBOARDED,
		expected_generation, expected_attachment_generation
	)


## Admits the caller-authorized homebound intent into this Host's retained
## session. The Host owns the session reference; callers never receive it.
## Admission does not move an actor or change phase.
func admit_return_travel_intent(
		intent: Variant, actor_instance_id: int, craft_instance_id: int,
		expected_generation: int, expected_attachment_generation: int
	) -> Dictionary:
	if _mutation_active:
		return _result(false, &"reentrant_call")
	_mutation_active = true
	var rejection := _simple_token_rejection(
		expected_generation, expected_attachment_generation
	)
	if not rejection.is_empty():
		return _finish(false, rejection)
	if actor_instance_id != _player_instance_id \
			or craft_instance_id != _ship_instance_id:
		return _finish(false, &"return_travel_bound_actor_mismatch")
	if _session == null or _phase not in [Phase.ON_FOOT, Phase.BOARDING, Phase.REBOARDED]:
		return _finish(false, &"return_travel_out_of_order")
	var admitted := _session.admit_return_travel_intent(
		intent, actor_instance_id, craft_instance_id,
		_generation, _session.get_attachment_generation()
	)
	return _finish(
		bool(admitted.get("accepted", false)),
		admitted.get("reason", &"return_travel_intent_rejected") as StringName
	)


## Atomically joins one caller-observed physical return fact to both the Host
## phase and its retained travel session. It never moves/reparents actors,
## changes a berth, or grants a reward. The normal Host cadence uses the same
## private commit path after observing its live Player/HeroShip dependencies.
func submit_return_travel_evidence(
		kind: StringName, actor_instance_id: int, craft_instance_id: int,
		evidence: Variant, expected_generation: int,
		expected_attachment_generation: int
	) -> Dictionary:
	if _mutation_active:
		return _result(false, &"reentrant_call")
	_mutation_active = true
	var rejection := _simple_token_rejection(
		expected_generation, expected_attachment_generation
	)
	if not rejection.is_empty():
		return _finish(false, rejection)
	if actor_instance_id != _player_instance_id \
			or craft_instance_id != _ship_instance_id:
		return _finish(false, &"return_travel_bound_actor_mismatch")
	if not evidence is Dictionary:
		return _finish(false, &"invalid_return_travel_evidence")
	var committed := _commit_return_travel_evidence(
		kind, actor_instance_id, craft_instance_id, evidence as Dictionary, true
	)
	return _finish(
		bool(committed.get("accepted", false)),
		committed.get("reason", &"return_travel_evidence_rejected") as StringName
	)


## Validates the retained orbit-return sample for the existing Mudds approach
## contract. This only marks approach readiness in the retained session; Host
## phase, actor transforms, movement ownership, and berth ownership are unchanged.
func prepare_return_approach(
		landing_return_contract: Object,
		actor_instance_id: int,
		craft_instance_id: int,
		expected_generation: int,
		expected_attachment_generation: int
	) -> Dictionary:
	if _mutation_active:
		return _result(false, &"reentrant_call")
	_mutation_active = true
	var rejection := _simple_token_rejection(
		expected_generation, expected_attachment_generation
	)
	if not rejection.is_empty():
		return _finish(false, rejection)
	if actor_instance_id != _player_instance_id \
			or craft_instance_id != _ship_instance_id:
		return _finish(false, &"return_travel_bound_actor_mismatch")
	if _session == null:
		return _finish(false, &"return_travel_session_unavailable")
	var session_snapshot := _session.get_presentation_snapshot()
	if _phase != Phase.ORBIT_RETURN \
			or StringName(session_snapshot.get("state_id", &"")) != &"orbit_return":
		return _finish(false, &"return_approach_host_session_mismatch")
	var prepared := _session.prepare_return_approach(
		landing_return_contract, actor_instance_id, craft_instance_id,
		_generation, _session.get_attachment_generation()
	)
	return _finish(
		bool(prepared.get("accepted", false)),
		prepared.get("reason", &"return_approach_rejected") as StringName
	)


## Admits the already prepared Mudds approach intent into the caller-owned
## landing-return contract while this Host retains the travel session. It does
## not confirm arrival, complete the Host, move the craft, or reserve a berth.
func admit_return_contract_approach(
		landing_return_contract: Object,
		actor_instance_id: int,
		craft_instance_id: int,
		expected_generation: int,
		expected_attachment_generation: int
	) -> Dictionary:
	if _mutation_active:
		return _result(false, &"reentrant_call")
	_mutation_active = true
	var rejection := _simple_token_rejection(
		expected_generation, expected_attachment_generation
	)
	if not rejection.is_empty():
		return _finish(false, rejection)
	if actor_instance_id != _player_instance_id \
			or craft_instance_id != _ship_instance_id:
		return _finish(false, &"return_travel_bound_actor_mismatch")
	if _session == null:
		return _finish(false, &"return_travel_session_unavailable")
	var session_snapshot := _session.get_presentation_snapshot()
	if _phase != Phase.ORBIT_RETURN \
			or StringName(session_snapshot.get("state_id", &"")) != &"orbit_return":
		return _finish(false, &"return_approach_host_session_mismatch")
	var admitted := _session.admit_return_contract_approach(
		landing_return_contract, actor_instance_id, craft_instance_id,
		_generation, _session.get_attachment_generation()
	)
	var result := _finish(
		bool(admitted.get("accepted", false)),
		admitted.get("reason", &"return_contract_approach_rejected") as StringName
	)
	if bool(result.get("accepted", false)):
		result["return_target_id"] = admitted.get("return_target_id", &"")
		result["next_caller_state"] = admitted.get("next_caller_state", &"")
	return result


## Confirms caller-observed Mudds arrival readiness through the retained travel
## session after approach admission. The receipt is evidence-only: Host/session
## remain in orbit return and no movement, berth, or reward authority is gained.
func confirm_return_arrival_ready(
		landing_return_contract: Object,
		actor_instance_id: int,
		craft_instance_id: int,
		observation: Variant,
		expected_generation: int,
		expected_attachment_generation: int
	) -> Dictionary:
	if _mutation_active:
		return _result(false, &"reentrant_call")
	_mutation_active = true
	var rejection := _simple_token_rejection(
		expected_generation, expected_attachment_generation
	)
	if not rejection.is_empty():
		return _finish(false, rejection)
	if actor_instance_id != _player_instance_id \
			or craft_instance_id != _ship_instance_id:
		return _finish(false, &"return_travel_bound_actor_mismatch")
	if not observation is Dictionary:
		return _finish(false, &"invalid_return_arrival_observation")
	if _session == null:
		return _finish(false, &"return_travel_session_unavailable")
	var session_snapshot := _session.get_presentation_snapshot()
	if _phase != Phase.ORBIT_RETURN \
			or StringName(session_snapshot.get("state_id", &"")) != &"orbit_return":
		return _finish(false, &"return_arrival_host_session_mismatch")
	var confirmed := _session.confirm_return_arrival_ready(
		landing_return_contract, actor_instance_id, craft_instance_id,
		(observation as Dictionary).duplicate(true),
		_generation, _session.get_attachment_generation()
	)
	var result := _finish(
		bool(confirmed.get("accepted", false)),
		confirmed.get("reason", &"return_arrival_rejected") as StringName
	)
	if bool(result.get("accepted", false)):
		result["return_target_id"] = confirmed.get("return_target_id", &"")
		result["next_caller_state"] = confirmed.get("next_caller_state", &"")
	return result


## Adopts one already committed common-origin transaction. This method cannot
## request, apply, defer, cancel, or commit a rebase. It accepts only the exact
## detached receipt produced after the shared root roster was translated, proves
## that every frozen dependency and the tracked actor's absolute observation are
## unchanged, then advances only this host's frame-generation fence.
func adopt_committed_origin_rebase(
	receipt: Variant,
	expected_generation: int,
	expected_attachment_generation: int,
	expected_location_generation: int
) -> Dictionary:
	if _mutation_active:
		return _result(false, &"reentrant_call")
	_mutation_active = true
	var rejection := _simple_token_rejection(
		expected_generation, expected_attachment_generation
	)
	if not rejection.is_empty():
		return _finish(false, rejection)
	if expected_location_generation != _location_generation:
		return _finish(false, &"stale_location_generation")
	if _phase < Phase.ORBIT_APPROACH or _phase > Phase.ORBIT_RETURN:
		return _finish(false, &"origin_adoption_out_of_order")
	var validation := _validate_committed_origin_receipt(receipt)
	if not bool(validation.get("accepted", false)):
		return _finish(
			false,
			validation.get("reason", &"invalid_origin_rebase_receipt") as StringName,
		)
	_coordinate_frame_generation = int(validation.get("target_generation", 0))
	_origin_adoption_count += 1
	_last_origin_adoption_receipt = (receipt as Dictionary).duplicate(true)
	return _finish(true, &"committed_origin_adopted")


## Completion-only handback for a later production GameFlow owner. The original
## command source is restored and the host attachment is retired in one guarded
## transaction, while the exact seated Player reservation remains continuously
## held. The receipt contains only detached primitive identity evidence; it
## grants no caller authority and never reparents or moves either actor.
func return_runtime_ownership(
	expected_generation: int,
	expected_attachment_generation: int
) -> Dictionary:
	if _mutation_active:
		return _result(false, &"reentrant_call")
	_mutation_active = true
	var rejection := _simple_token_rejection(
		expected_generation, expected_attachment_generation
	)
	if not rejection.is_empty():
		return _finish(false, rejection)
	if _phase != Phase.COMPLETED:
		return _finish(false, &"runtime_ownership_return_out_of_order")
	if _attachment_generation >= MAX_SAFE_INTEGER:
		return _finish(false, &"attachment_generation_exhausted")
	var return_rejection := _runtime_ownership_return_preflight()
	if not return_rejection.is_empty():
		return _finish(false, return_rejection)

	var retired_attachment_generation := _attachment_generation
	var host_source_instance_id := _command_source.get_instance_id()
	var original_source_instance_id := _original_command_source.get_instance_id()
	_ship.set_command_source(_original_command_source)
	if _ship.get_command_source() != _original_command_source:
		_ship.set_command_source(_command_source)
		return _finish(false, &"command_source_return_rejected")
	var session_detach := _session.detach(
		_generation, _session.get_attachment_generation()
	)
	if not bool(session_detach.get("accepted", false)):
		_ship.set_command_source(_command_source)
		if _ship.get_command_source() != _command_source:
			return _commit_failure(&"runtime_ownership_return_rollback_failed")
		return _finish(false, &"travel_session_return_rejected")

	# Logical reservation cleanup ownership transfers to the caller without
	# dropping the Player token, so no synchronous availability observer can
	# steal a seat whose embodied Player never left it.
	_host_acquired_boarding_reservation = false
	_disconnect_dependency_signals()
	if _command_source.get_snapshot().attached:
		_command_source.detach(_source_generation)
	_command_source.queue_free()
	_runtime_bindings_restored = true
	_attached = false
	_attachment_generation += 1
	_runtime_ownership_returned = true
	_last_runtime_ownership_return_receipt = {
		"schema_version": SCHEMA_VERSION,
		"reason": &"runtime_ownership_returned",
		"host_id": HOST_ID,
		"generation": _generation,
		"retired_attachment_generation": retired_attachment_generation,
		"current_attachment_generation": _attachment_generation,
		"ship_instance_id": _ship_instance_id,
		"player_instance_id": _player_instance_id,
		"boarding_area_instance_id": _boarding_area.get_instance_id(),
		"boarding_reservation_token_instance_id": _player.get_instance_id(),
		"boarding_reservation_retained": true,
		"host_command_source_instance_id": host_source_instance_id,
		"restored_command_source_instance_id": original_source_instance_id,
		"command_source_restored": true,
		"ship_piloted": _ship.is_piloted(),
		"player_seated": _player.is_seated(),
		"host_attached": false,
	}.duplicate(true)
	var result := _finish(true, &"runtime_ownership_returned")
	result["runtime_ownership_return"] = (
		_last_runtime_ownership_return_receipt.duplicate(true)
	)
	_last_result = result.duplicate(true)
	return result


func detach(
	expected_generation: int,
	expected_attachment_generation: int
) -> Dictionary:
	if _mutation_active:
		return _result(false, &"reentrant_call")
	_mutation_active = true
	if expected_generation != _generation:
		return _finish(false, &"stale_generation")
	if expected_attachment_generation != _attachment_generation:
		return _finish(false, &"stale_attachment_generation")
	if not _attached:
		return _finish(false, &"not_attached")
	var recover_embodiment := _phase in [Phase.DISEMBARKING, Phase.BOARDING]
	if _phase not in [Phase.IDLE, Phase.COMPLETED, Phase.FAILED] and _session != null:
		_terminal_reason = &"host_detached"
		_set_phase(Phase.FAILED)
		_session.fail(&"host_detached", _generation, _session.get_attachment_generation())
	_release_leases()
	_disconnect_dependency_signals()
	_restore_runtime_bindings(recover_embodiment)
	_session.detach(_generation, _session.get_attachment_generation())
	_attached = false
	_attachment_generation += 1
	return _finish(true, &"detached")


func get_generation() -> int:
	return _generation


func get_attachment_generation() -> int:
	return _attachment_generation


func get_phase() -> int:
	return _phase


## Read-only observer source for presentation bindings. Travel mutations must
## use the Host-owned intent/evidence APIs instead of this signal source.
func get_travel_session_observation_source() -> Object:
	return _session


func get_snapshot() -> Dictionary:
	var bootstrap_snapshot := _bootstrap.get_snapshot() \
		if _node_is_current(_bootstrap) and _node_is_current(_scene) else {}
	var ship_position := _ship.global_position if is_instance_valid(_ship) else Vector3.ZERO
	var player_position := _player.global_position if is_instance_valid(_player) else Vector3.ZERO
	return {
		"schema_version": SCHEMA_VERSION,
		"host_id": HOST_ID,
		"attached": _attached,
		"phase": _phase,
		"phase_id": _phase_id(_phase),
		"generation": _generation,
		"attachment_generation": _attachment_generation,
		"coordinate_frame_generation": _coordinate_frame_generation,
		"location_generation": _location_generation,
		"elapsed_seconds": _elapsed_seconds,
		"phase_elapsed_seconds": _phase_elapsed_seconds,
		"transition_count": _transition_count,
		"physics_advance_count": _physics_advance_count,
		"configuration_error": _configuration_error,
		"terminal_reason": _terminal_reason,
		"identities": {
			"world_id": WORLD_ID,
			"body_id": BODY_ID,
			"region_id": REGION_ID,
			"terrain_profile_id": TERRAIN_PROFILE_ID,
			"orbital_frame_id": ORBITAL_FRAME_ID,
			"ship_definition_id": _ship.get_ship_definition().ship_id \
				if is_instance_valid(_ship) and _ship.get_ship_definition() != null else &"",
			"composition_root_instance_id": _composition_root_instance_id,
			"loaded_scene_instance_id": _loaded_scene_instance_id,
			"ship_instance_id": _ship_instance_id,
			"player_instance_id": _player_instance_id,
			"bootstrap_instance_id": _bootstrap.get_instance_id() if is_instance_valid(_bootstrap) else 0,
			"origin_owner_instance_id": _origin_owner_instance_id,
			"origin_binding_instance_id": _origin_binding_instance_id,
		},
		"resources": {
			"world": WORLD_PATH,
			"terrain": TERRAIN_PATH,
			"landing_region": REGION_PATH,
			"authored_scene": AUTHORED_SCENE_PATH,
			"ship_scene": ARROW_SCENE_PATH,
			"player_scene": PLAYER_SCENE_PATH,
		},
		"composition": {
			"root_instance_id": _composition_root_instance_id,
			"standalone_root_is_host": _composition_root == self,
			"topology_current": _composition_topology_current() \
				if _composition_root != null else false,
			"host_direct_child_or_root": _composition_root == self \
				or (_node_is_current(_composition_root) and get_parent() == _composition_root),
			"dependencies_are_direct_children": _composition_topology_current() \
				if _composition_root != null else false,
			"host_reparent_calls": 0,
			"dependency_reparent_calls": 0,
		},
		"approach_entry": {
			"envelope": _approach_entry_envelope.get_snapshot() \
				if _approach_entry_envelope != null else {},
			"accepted_measurement": _accepted_approach_entry_measurement.duplicate(true),
			"command_source_installed": _node_is_current(_ship) \
				and _ship.get_command_source() == _command_source,
			"boarding_cleanup_owned": _host_acquired_boarding_reservation,
		},
		"origin_rebase": {
			"adoption_count": _origin_adoption_count,
			"last_adopted_receipt": _last_origin_adoption_receipt.duplicate(true),
			"requests": 0,
			"applications": 0,
			"commits": 0,
			"deferrals": 0,
		},
		"runtime_ownership_return": {
			"returned": _runtime_ownership_returned,
			"last_receipt": _last_runtime_ownership_return_receipt.duplicate(true),
		},
		"actor_state": {
			"ship_position": ship_position,
			"player_position": player_position,
			"ship_telemetry": _ship.get_telemetry() if is_instance_valid(_ship) else {},
			"player_seated": _player.is_seated() if is_instance_valid(_player) else false,
			"player_control_enabled": _player.is_control_enabled() if is_instance_valid(_player) else false,
			"host_transform_writes": 0,
			"host_velocity_writes": 0,
			"host_move_and_collide_calls": 0,
			"host_reparent_calls": 0,
		},
		"surface_route": {
			"outbound_complete": _surface_route_outbound_complete,
			"return_complete": _surface_route_return_complete,
			"coordinate_space": &"gravity_policy_reference_tangent",
			"reference_tangent_basis_body_local": _reference_tangent_basis_body,
			"live_landing_basis_world": _landing_root.global_basis \
				if _node_is_current(_landing_root) else Basis.IDENTITY,
			"walkable_body_instance_id": _walkable_body.get_instance_id() \
				if _node_is_current(_walkable_body) else 0,
			"egress_anchor": _region_local_to_world(_REGION.surface_route_anchor_positions_region_local_m[0]),
			"staging_anchor": _region_local_to_world(_REGION.surface_route_anchor_positions_region_local_m[1]),
		},
		"gravity": {
			"sample_count": _gravity_sample_count,
			"application_count": _gravity_application_count,
			"last_sample": _last_gravity_sample.duplicate(true),
			"policy": _gravity_policy.get_snapshot() if _gravity_policy != null else {},
			"application": &"player_public_gravity_multiplier_tangent_projection",
		},
		"berth": _berth.audit() if is_instance_valid(_berth) else {},
		"boarding_reserved_for_player": _boarding_area.get_reservation_token() == _player \
			if is_instance_valid(_boarding_area) and is_instance_valid(_player) else false,
		"command_source": _command_source.get_snapshot() if is_instance_valid(_command_source) else {},
		"travel_session": _session.get_presentation_snapshot() if _session != null else {},
		"world_composition": _world_report.duplicate(true),
		"landing_composition": _landing_report.duplicate(true),
		"bootstrap": bootstrap_snapshot,
		"owned_capabilities": _owned_capabilities(),
		"adjacent_authority": _adjacent_authority(),
	}.duplicate(true)


func audit() -> Dictionary:
	var errors := PackedStringArray()
	if not _configuration_error.is_empty():
		errors.append("configuration failed: %s" % _configuration_error)
	if _attached and _phase not in [Phase.COMPLETED, Phase.FAILED] \
			and not _dependency_failure_reason().is_empty():
		errors.append("an attached dependency is no longer current")
	if _attached and (_composition_root == null \
			or _composition_root_instance_id <= 0 \
			or not _composition_topology_current()):
		errors.append("the frozen shared composition root is no longer exact")
	if _attached and (_approach_entry_envelope == null \
			or not _approach_entry_envelope.configuration_error.is_empty()):
		errors.append("the typed approach-entry envelope is invalid")
	if _phase not in [Phase.IDLE, Phase.FAILED] \
			and _accepted_approach_entry_measurement.is_empty():
		errors.append("a started loop lacks accepted approach-entry evidence")
	if _session != null and not bool(_session.audit().get("valid", false)):
		errors.append("travel session contract is invalid")
	if _gravity_policy != null and not bool(_gravity_policy.audit().get("valid", false)):
		errors.append("surface gravity policy is invalid")
	if _origin_adoption_count < 0 \
			or (_origin_adoption_count == 0 and not _last_origin_adoption_receipt.is_empty()) \
			or (_origin_adoption_count > 0 and (
				_last_origin_adoption_receipt.is_empty()
				or int(_last_origin_adoption_receipt.get("target_generation", 0))
					!= _coordinate_frame_generation
			)):
		errors.append("committed-origin adoption evidence is incoherent")
	if _attached and _phase == Phase.IDLE and (
		_host_acquired_boarding_reservation
		or (_node_is_current(_ship) and _ship.get_command_source() == _command_source)
	):
		errors.append("idle preflight acquired runtime ownership before start")
	if _runtime_ownership_returned and (
		_attached or _last_runtime_ownership_return_receipt.is_empty()
	):
		errors.append("runtime ownership return evidence is incoherent")
	if is_processing() or is_physics_processing():
		errors.append("host gained an automatic callback")
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"snapshot": get_snapshot(),
		"clock": {
			"source": &"caller_physics_delta_after_real_actor_tick",
			"maximum_delta_seconds": MAX_CALLER_DELTA_SECONDS,
			"automatic_host_process": false,
		},
		"evidence": {
			"content_class": &"NEW",
			"status": &"modern_interpretation",
			"scope": &"standalone_ember_surface_loop",
			"references": PackedStringArray([EVIDENCE_PATH]),
			"notes": "Public production actors and existing Ember contracts; no historical behavior claim.",
		},
		"owned_capabilities": _owned_capabilities(),
		"adjacent_authority": _adjacent_authority(),
	}.duplicate(true)


func _advance_phase() -> Dictionary:
	match _phase:
		Phase.ORBIT_APPROACH:
			return _advance_orbit_approach()
		Phase.DESCENT:
			return _advance_descent()
		Phase.SURFACE_APPROACH:
			return _advance_surface_approach()
		Phase.LANDING_APPROACH:
			return _advance_landing_approach()
		Phase.LANDED:
			return _begin_disembark_if_ready()
		Phase.DISEMBARKING:
			return _advance_disembarking()
		Phase.SURFACE_OUTBOUND:
			return _advance_surface_outbound()
		Phase.ON_FOOT:
			return _advance_surface_return_observation()
		Phase.BOARDING:
			return _advance_boarding()
		Phase.REBOARDED:
			return _begin_takeoff_if_requested()
		Phase.TAKEOFF:
			return _advance_takeoff()
		Phase.ASCENT:
			return _advance_ascent()
		Phase.ORBIT_RETURN:
			return _complete_orbit_return()
		_:
			return {"accepted": false, "reason": &"invalid_phase"}


func _advance_orbit_approach() -> Dictionary:
	if bool(_ship.get_telemetry().get("landed", true)):
		return {"accepted": true, "reason": &"awaiting_production_departure"}
	var observation := _travel_observation()
	if not bool(observation.get("accepted", false)):
		return {"accepted": false, "reason": &"orbit_observation_rejected"}
	var result := _session.submit_orbit_approach_sample(
		true,
		observation.orbital_coordinate as Dictionary,
		float(observation.speed_meters_per_second),
		_coordinate_frame_generation,
		_generation,
		_session.get_attachment_generation()
	)
	if not bool(result.get("accepted", false)) or result.get("state_id") != &"descent":
		return {"accepted": false, "reason": &"orbit_approach_desynchronized"}
	_set_phase(Phase.DESCENT)
	return {"accepted": true, "reason": &"orbit_approach_complete"}


func _advance_descent() -> Dictionary:
	var observation := _travel_observation()
	if not bool(observation.get("accepted", false)):
		return {"accepted": false, "reason": &"descent_observation_rejected"}
	var result := _session.submit_descent_sample(
		observation.orbital_coordinate as Dictionary,
		float(observation.speed_meters_per_second),
		_coordinate_frame_generation,
		_generation,
		_session.get_attachment_generation()
	)
	if not bool(result.get("accepted", false)) or result.get("state_id") != &"surface_flight":
		return {"accepted": false, "reason": &"descent_desynchronized"}
	_command_source.set_mode(EmberSurfaceLoopCommandSource.Mode.APPROACH, _source_generation)
	_set_phase(Phase.SURFACE_APPROACH)
	return {"accepted": true, "reason": &"surface_approach_started"}


func _advance_surface_approach() -> Dictionary:
	var relative := _ship.global_position - _berth.global_position
	if relative.z > APPROACH_BRAKE_Z_M:
		return {"accepted": true, "reason": &"production_approach_in_progress"}
	_command_source.set_mode(EmberSurfaceLoopCommandSource.Mode.BRAKE, _source_generation)
	if _ship.velocity.length() > APPROACH_HANDOFF_MAXIMUM_SPEED_MPS:
		return {"accepted": true, "reason": &"production_approach_braking"}
	var definition := _ship.get_ship_definition()
	_berth_token = _berth.try_reserve(_ship, definition)
	if _berth_token.is_empty() \
			or not _berth.has_valid_lease(_ship, _berth_token, definition.ship_id):
		return {"accepted": false, "reason": &"berth_reservation_rejected"}
	if not _ship.request_berth_landing(_berth):
		return {"accepted": false, "reason": &"production_landing_rejected"}
	_command_source.set_mode(EmberSurfaceLoopCommandSource.Mode.NEUTRAL, _source_generation)
	_landing_completed_observed = false
	_landing_aborted_reason = &""
	_set_phase(Phase.LANDING_APPROACH)
	return {"accepted": true, "reason": &"production_landing_started"}


func _advance_landing_approach() -> Dictionary:
	if not _landing_aborted_reason.is_empty():
		return {"accepted": false, "reason": StringName("landing_%s" % _landing_aborted_reason)}
	if not _landing_completed_observed:
		if not _ship.is_landing_active() and not bool(_ship.get_telemetry().get("landed", false)):
			return {"accepted": false, "reason": &"landing_ended_without_completion"}
		return {"accepted": true, "reason": &"production_landing_in_progress"}
	if not _landed_public_state_is_exact():
		return {"accepted": false, "reason": &"landed_public_state_mismatch"}
	var result := _session.submit_landing_sample(
		true, _landing_identity, _generation, _session.get_attachment_generation()
	)
	if not bool(result.get("accepted", false)) or result.get("state_id") != &"landed":
		return {"accepted": false, "reason": &"landing_desynchronized"}
	_set_phase(Phase.LANDED)
	return {"accepted": true, "reason": &"landed"}


func _begin_disembark_if_ready() -> Dictionary:
	if not _disembark_requested:
		return {"accepted": true, "reason": &"awaiting_disembark_request"}
	if str(_ship.get_telemetry().get("engine_state", "ONLINE")) != "OFFLINE":
		return {"accepted": true, "reason": &"awaiting_engine_offline"}
	if not _landed_public_state_is_exact() or not _player.is_seated() \
			or _boarding_area.get_reservation_token() != _player:
		return {"accepted": false, "reason": &"disembark_public_state_mismatch"}
	_disembark_requested = false
	_ship.set_canopy_open(true, 0.0)
	_ship.set_piloted(false)
	_player.set_camera_active(true)
	if not _player.begin_disembark(_ship.get_exit_transform(), 0.6, _ship):
		return {"accepted": false, "reason": &"disembark_rejected"}
	_disembarking_completed_observed = false
	_set_phase(Phase.DISEMBARKING)
	return {"accepted": true, "reason": &"disembark_started"}


func _advance_disembarking() -> Dictionary:
	if not _disembarking_completed_observed:
		return {"accepted": true, "reason": &"disembark_in_progress"}
	if _player.is_seated() or _player.collision_layer == 0 \
			or not bool(_ship.get_telemetry().get("landed", false)):
		return {"accepted": false, "reason": &"disembark_public_state_mismatch"}
	if not _boarding_area.release_reservation(_player):
		return {"accepted": false, "reason": &"boarding_reservation_release_failed"}
	_host_acquired_boarding_reservation = false
	_ship.set_canopy_open(false, 0.0)
	_player.set_control_enabled(true)
	var result := _session.submit_disembark_sample(
		true, true, _generation, _session.get_attachment_generation()
	)
	if not bool(result.get("accepted", false)) or result.get("state_id") != &"on_foot":
		return {"accepted": false, "reason": &"disembark_desynchronized"}
	_set_phase(Phase.SURFACE_OUTBOUND)
	return {"accepted": true, "reason": &"surface_traverse_started"}


func _advance_surface_outbound() -> Dictionary:
	if not _surface_actor_supported():
		return {"accepted": false, "reason": &"surface_support_lost"}
	var player_tangent := _world_to_reference_tangent(_player.global_position)
	var egress := _REGION.surface_route_anchor_positions_region_local_m[0]
	var staging := _REGION.surface_route_anchor_positions_region_local_m[1]
	if not _surface_route_outbound_complete \
			and _tangent_distance(player_tangent, egress) <= ROUTE_ANCHOR_RADIUS_M:
		_surface_route_outbound_complete = true
	if not _surface_route_outbound_complete:
		return {"accepted": true, "reason": &"awaiting_egress_anchor"}
	if _tangent_distance(player_tangent, staging) > ROUTE_ANCHOR_RADIUS_M:
		return {"accepted": true, "reason": &"awaiting_staging_anchor"}
	_set_phase(Phase.ON_FOOT)
	return {"accepted": true, "reason": &"surface_outbound_complete"}


func _advance_surface_return_observation() -> Dictionary:
	if not _surface_actor_supported():
		return {"accepted": false, "reason": &"surface_support_lost"}
	var player_tangent := _world_to_reference_tangent(_player.global_position)
	var egress := _REGION.surface_route_anchor_positions_region_local_m[0]
	var staging := _REGION.surface_route_anchor_positions_region_local_m[1]
	if _tangent_distance(player_tangent, staging) > ROUTE_ANCHOR_RADIUS_M * 2.0:
		_return_departed_staging = true
	if _return_departed_staging \
			and _tangent_distance(player_tangent, egress) <= ROUTE_ANCHOR_RADIUS_M:
		_surface_route_return_complete = true
	return {
		"accepted": true,
		"reason": &"surface_return_complete" if _surface_route_return_complete else &"on_foot",
	}


func _advance_boarding() -> Dictionary:
	if not _boarding_completed_observed:
		return {"accepted": true, "reason": &"boarding_in_progress"}
	if not _player.is_seated() or _boarding_area.get_reservation_token() != _player \
			or not bool(_ship.get_telemetry().get("landed", false)):
		return {"accepted": false, "reason": &"boarding_public_state_mismatch"}
	_ship.set_canopy_open(false, 0.0)
	_player.set_camera_active(false)
	_player.gravity_multiplier = _original_player_gravity_multiplier
	_ship.set_piloted(true)
	var result := _commit_return_travel_evidence(
		&"reboard", _player_instance_id, _ship_instance_id,
		{"player_reboarded": true, "ship_still_landed": true}
	)
	if not bool(result.get("accepted", false)):
		return {"accepted": false, "reason": &"reboard_desynchronized"}
	return {"accepted": true, "reason": &"reboarded"}


func _begin_takeoff_if_requested() -> Dictionary:
	if not _takeoff_requested:
		return {"accepted": true, "reason": &"awaiting_takeoff_request"}
	_takeoff_requested = false
	_command_source.set_mode(
		EmberSurfaceLoopCommandSource.Mode.TAKEOFF_ROTATE, _source_generation
	)
	_set_phase(Phase.TAKEOFF)
	return {"accepted": true, "reason": &"takeoff_commanded"}


func _advance_takeoff() -> Dictionary:
	var surface_up := _berth.global_basis.y.normalized()
	var flight_forward := -_ship.global_basis.z.normalized()
	if flight_forward.dot(surface_up) >= 0.94:
		_command_source.set_mode(
			EmberSurfaceLoopCommandSource.Mode.ASCENT, _source_generation
		)
	if bool(_ship.get_telemetry().get("landed", true)):
		return {"accepted": true, "reason": &"production_takeoff_in_progress"}
	if _berth_token.is_empty() or not _berth.release(_ship, _berth_token):
		return {"accepted": false, "reason": &"departure_lease_release_failed"}
	_berth_token = &""
	var result := _commit_return_travel_evidence(
		&"takeoff", _player_instance_id, _ship_instance_id,
		{"takeoff_started": true, "ship_still_landed": false}
	)
	if not bool(result.get("accepted", false)):
		return {"accepted": false, "reason": &"takeoff_desynchronized"}
	return {"accepted": true, "reason": &"departed_surface"}


func _advance_ascent() -> Dictionary:
	var surface_up := _berth.global_basis.y.normalized()
	var flight_forward := -_ship.global_basis.z.normalized()
	if flight_forward.dot(surface_up) >= 0.94:
		_command_source.set_mode(
			EmberSurfaceLoopCommandSource.Mode.ASCENT, _source_generation
		)
	var altitude := (_ship.global_position - _berth.global_position).dot(surface_up)
	var observation := _travel_observation()
	if not bool(observation.get("accepted", false)):
		return {"accepted": false, "reason": &"ascent_observation_rejected"}
	if not _surface_clear_submitted and altitude >= SURFACE_CLEAR_ALTITUDE_M:
		var ascent := _commit_return_travel_evidence(
			&"ascent", _player_instance_id, _ship_instance_id,
			{
				"surface_clear_confirmed": true,
				"orbital_coordinate": observation.orbital_coordinate,
				"speed_meters_per_second": observation.speed_meters_per_second,
				"coordinate_frame_generation": _coordinate_frame_generation,
			}
		)
		if not bool(ascent.get("accepted", false)):
			return {"accepted": false, "reason": &"ascent_desynchronized"}
		_surface_clear_submitted = true
	if altitude < ORBIT_RETURN_ALTITUDE_M:
		return {"accepted": true, "reason": &"production_ascent_in_progress"}
	var returned := _commit_return_travel_evidence(
		&"orbit", _player_instance_id, _ship_instance_id,
		{
			"orbital_coordinate": observation.orbital_coordinate,
			"speed_meters_per_second": observation.speed_meters_per_second,
			"coordinate_frame_generation": _coordinate_frame_generation,
		}
	)
	if not bool(returned.get("accepted", false)):
		return {"accepted": false, "reason": &"orbit_return_desynchronized"}
	return {"accepted": true, "reason": &"orbit_return_reached"}


func _commit_return_travel_evidence(
		kind: StringName, actor_instance_id: int, craft_instance_id: int,
		evidence: Dictionary, require_return_intent: bool = false
	) -> Dictionary:
	if _session == null:
		return {"accepted": false, "reason": &"return_travel_session_unavailable"}
	var session_snapshot := _session.get_presentation_snapshot()
	var session_state := StringName(session_snapshot.get("state_id", &""))
	var has_return_intent := not (
		session_snapshot.get("last_return_intent", {}) as Dictionary
	).is_empty()
	if require_return_intent and not has_return_intent:
		return {"accepted": false, "reason": &"return_travel_intent_required"}
	var result: Dictionary
	match kind:
		&"reboard":
			if _phase not in [Phase.ON_FOOT, Phase.BOARDING] \
					or session_state != &"on_foot":
				return {"accepted": false, "reason": &"return_reboard_evidence_replayed"}
			if evidence.size() != 2 \
					or evidence.get("player_reboarded") is not bool \
					or evidence.get("ship_still_landed") is not bool:
				return {"accepted": false, "reason": &"invalid_return_travel_evidence"}
			if has_return_intent:
				result = _session.submit_authorized_return_reboard(
					actor_instance_id, craft_instance_id,
					bool(evidence.player_reboarded), bool(evidence.ship_still_landed),
					_generation, _session.get_attachment_generation()
				)
			else:
				result = _session.submit_reboard_sample(
					bool(evidence.player_reboarded), bool(evidence.ship_still_landed),
					_generation, _session.get_attachment_generation()
				)
			if bool(result.get("accepted", false)):
				_set_phase(Phase.REBOARDED)
		&"takeoff":
			if _phase not in [Phase.REBOARDED, Phase.TAKEOFF] \
					or session_state != &"reboarded":
				return {"accepted": false, "reason": &"return_takeoff_evidence_replayed"}
			if evidence.size() != 2 \
					or evidence.get("takeoff_started") is not bool \
					or evidence.get("ship_still_landed") is not bool:
				return {"accepted": false, "reason": &"invalid_return_travel_evidence"}
			if has_return_intent:
				result = _session.submit_authorized_return_takeoff(
					actor_instance_id, craft_instance_id,
					bool(evidence.takeoff_started), bool(evidence.ship_still_landed),
					_generation, _session.get_attachment_generation()
				)
			else:
				result = _session.submit_takeoff_sample(
					bool(evidence.takeoff_started), bool(evidence.ship_still_landed),
					_generation, _session.get_attachment_generation()
				)
			if bool(result.get("accepted", false)):
				_set_phase(Phase.ASCENT)
		&"ascent":
			if _phase != Phase.ASCENT or session_state != &"takeoff":
				return {"accepted": false, "reason": &"return_ascent_evidence_replayed"}
			if evidence.size() != 4 \
					or evidence.get("surface_clear_confirmed") is not bool \
					or evidence.get("orbital_coordinate") is not Dictionary \
					or evidence.get("speed_meters_per_second") is not float \
					or evidence.get("coordinate_frame_generation") is not int:
				return {"accepted": false, "reason": &"invalid_return_travel_evidence"}
			if has_return_intent:
				result = _session.submit_authorized_return_ascent(
					actor_instance_id, craft_instance_id,
					bool(evidence.surface_clear_confirmed), evidence.orbital_coordinate,
					float(evidence.speed_meters_per_second),
					int(evidence.coordinate_frame_generation), _generation,
					_session.get_attachment_generation()
				)
			else:
				result = _session.submit_ascent_sample(
					bool(evidence.surface_clear_confirmed), evidence.orbital_coordinate,
					float(evidence.speed_meters_per_second),
					int(evidence.coordinate_frame_generation), _generation,
					_session.get_attachment_generation()
				)
		&"orbit":
			if _phase != Phase.ASCENT or session_state != &"ascent":
				return {"accepted": false, "reason": &"return_orbit_evidence_replayed"}
			if evidence.size() != 3 \
					or evidence.get("orbital_coordinate") is not Dictionary \
					or evidence.get("speed_meters_per_second") is not float \
					or evidence.get("coordinate_frame_generation") is not int:
				return {"accepted": false, "reason": &"invalid_return_travel_evidence"}
			if has_return_intent:
				result = _session.submit_authorized_return_orbit(
					actor_instance_id, craft_instance_id, evidence.orbital_coordinate,
					float(evidence.speed_meters_per_second),
					int(evidence.coordinate_frame_generation), _generation,
					_session.get_attachment_generation()
				)
			else:
				result = _session.submit_orbit_return_sample(
					evidence.orbital_coordinate,
					float(evidence.speed_meters_per_second),
					int(evidence.coordinate_frame_generation), _generation,
					_session.get_attachment_generation()
				)
			if bool(result.get("accepted", false)):
				_set_phase(Phase.ORBIT_RETURN)
		_:
			return {"accepted": false, "reason": &"unknown_return_travel_evidence"}
	return {
		"accepted": bool(result.get("accepted", false)),
		"reason": result.get("reason", &"return_travel_evidence_rejected"),
	}.duplicate(true)


func _complete_orbit_return() -> Dictionary:
	var observation := _travel_observation()
	if not bool(observation.get("accepted", false)):
		return {"accepted": false, "reason": &"completion_observation_rejected"}
	var result := _session.submit_completion_sample(
		true,
		observation.orbital_coordinate as Dictionary,
		float(observation.speed_meters_per_second),
		_coordinate_frame_generation,
		_generation,
		_session.get_attachment_generation()
	)
	if not bool(result.get("accepted", false)) or result.get("state_id") != &"completed":
		return {"accepted": false, "reason": &"completion_desynchronized"}
	_command_source.set_mode(EmberSurfaceLoopCommandSource.Mode.NEUTRAL, _source_generation)
	_set_phase(Phase.COMPLETED)
	return {"accepted": true, "reason": &"completed"}


func _sample_and_compose_gravity() -> Dictionary:
	var actor_position := _player.global_position if is_instance_valid(_player) \
		else _ship.global_position
	var body_local := actor_position - _bootstrap.global_position
	var sample := _gravity_policy.sample(body_local)
	if not bool(sample.get("accepted", false)):
		return sample
	_last_gravity_sample = sample.duplicate(true)
	_gravity_sample_count += 1
	if _phase in [
		Phase.DISEMBARKING, Phase.SURFACE_OUTBOUND, Phase.ON_FOOT, Phase.BOARDING,
	]:
		var project_gravity := float(ProjectSettings.get_setting(
			"physics/3d/default_gravity", 9.8
		))
		if not is_finite(project_gravity) or project_gravity <= 0.0:
			return {"accepted": false, "reason": &"project_gravity_invalid"}
		var tangent_gravity := _reference_tangent_basis_body.transposed() \
			* (sample.gravity_vector_mps2 as Vector3)
		var multiplier := -tangent_gravity.y / project_gravity
		if not is_finite(multiplier) or multiplier <= 0.0:
			return {"accepted": false, "reason": &"gravity_projection_invalid"}
		_player.gravity_multiplier = multiplier
		_gravity_application_count += 1
	return {"accepted": true, "reason": &"gravity_composed"}


func _travel_observation() -> Dictionary:
	return _bootstrap.create_travel_observation(
		_ship.global_position,
		_ship.velocity.length(),
		_coordinate_frame_generation,
		_location_generation
	)


func _validate_dependencies(
	bootstrap: EmberMoonStreamingBootstrap,
	berth: EmberSurfaceBerth,
	ship: HeroShip,
	player: PlayerController,
	reference_surface_gravity_mps2: float,
	location_generation: int,
	composition_root: Node,
	origin_owner: CommonWorldOriginRebaseOwner
) -> Dictionary:
	if not is_inside_tree() or transform != Transform3D.IDENTITY:
		return {"accepted": false, "reason": &"host_frame_mismatch"}
	if not _node_is_current(composition_root) \
			or (composition_root != self and get_parent() != composition_root):
		return {"accepted": false, "reason": &"composition_root_mismatch"}
	if not _node_is_current(bootstrap) or bootstrap.get_parent() != composition_root \
			or not bool(bootstrap.audit().get("valid", false)):
		return {"accepted": false, "reason": &"bootstrap_mismatch"}
	var bootstrap_snapshot := bootstrap.get_snapshot()
	var scene := bootstrap.get_loaded_instance() as EmberMoonAuthoredScene
	if not _node_is_current(scene) or not bool(scene.audit().get("valid", false)) \
			or scene.get_meta(LOCATION_ID_META, &"") != WORLD_ID \
			or location_generation < 1 \
			or int(scene.get_meta(LOCATION_GENERATION_META, 0)) != location_generation \
			or int(bootstrap_snapshot.get("location_generation", -1)) != location_generation \
			or int(bootstrap_snapshot.get("loaded_instance_id", 0)) != scene.get_instance_id():
		return {"accepted": false, "reason": &"loaded_scene_generation_mismatch"}
	var frame := bootstrap.get_coordinate_frame_for_session()
	if frame == null or not frame.is_configured() \
			or not bool(frame.audit().get("valid", false)):
		return {"accepted": false, "reason": &"coordinate_frame_mismatch"}
	var frame_snapshot := frame.get_snapshot()
	if frame_snapshot.get("body_id") != BODY_ID \
			or frame_snapshot.get("orbital_frame_id") != ORBITAL_FRAME_ID:
		return {"accepted": false, "reason": &"coordinate_frame_identity_mismatch"}
	var origin_binding: EmberMoonStreamingProductionBinding
	if composition_root == self:
		if origin_owner != null:
			return {"accepted": false, "reason": &"standalone_origin_owner_unexpected"}
	else:
		if not _node_is_current(origin_owner) \
				or origin_owner.get_parent() != composition_root \
				or not bool(origin_owner.audit().get("valid", false)):
			return {"accepted": false, "reason": &"origin_owner_mismatch"}
		var owner_snapshot := origin_owner.get_snapshot()
		if int(owner_snapshot.get("bootstrap_instance_id", 0)) \
				!= bootstrap.get_instance_id() \
				or int(owner_snapshot.get("coordinate_frame_instance_id", 0)) \
					!= frame.get_instance_id():
			return {"accepted": false, "reason": &"origin_owner_binding_mismatch"}
		origin_binding = instance_from_id(
			int(owner_snapshot.get("binding_instance_id", 0))
		) as EmberMoonStreamingProductionBinding
		if not _node_is_current(origin_binding) \
				or origin_binding.get_parent() != composition_root \
				or not bool(origin_binding.audit().get("valid", false)):
			return {"accepted": false, "reason": &"origin_binding_mismatch"}
		var binding_snapshot := origin_binding.get_snapshot()
		if int(binding_snapshot.get("bootstrap_instance_id", 0)) \
				!= bootstrap.get_instance_id() \
				or int(binding_snapshot.get("coordinate_frame_instance_id", 0)) \
					!= frame.get_instance_id() \
				or int(binding_snapshot.get("bound_coordinate_frame_generation", 0)) \
					!= frame.get_generation():
			return {"accepted": false, "reason": &"origin_binding_frame_mismatch"}
	if not _node_is_current(berth) or berth.get_parent() != composition_root:
		return {"accepted": false, "reason": &"berth_mismatch"}
	var ship_definition := ship.get_ship_definition() if _node_is_current(ship) else null
	if not _node_is_current(ship) or ship.get_parent() != composition_root \
			or ship.is_destroyed() or ship_definition == null \
			or not ship_definition.is_definition_valid():
		return {"accepted": false, "reason": &"ship_mismatch"}
	if not berth.is_configured_for(ship):
		var configured := berth.configure_for_ship(ship)
		if not bool(configured.get("accepted", false)):
			return {"accepted": false, "reason": &"berth_configuration_failed"}
	if not bool(berth.audit().get("valid", false)):
		return {"accepted": false, "reason": &"berth_contract_invalid"}
	if not _node_is_current(player) or player.get_parent() != composition_root:
		return {"accepted": false, "reason": &"player_mismatch"}
	var boarding_area := ship.get_node_or_null(^"ShipBoardingArea") as ShipBoardingArea
	if not _node_is_current(boarding_area) or boarding_area.get_ship() != ship \
			or boarding_area.get_reservation_token() != player:
		return {"accepted": false, "reason": &"boarding_contract_mismatch"}
	var collision_report := ship.get_landing_collision_report()
	if not bool(collision_report.get("valid", false)):
		return {"accepted": false, "reason": &"ship_collision_invalid"}
	var world_report := PlanetaryWorldCompositionValidator.new().validate_composition(
		_WORLD, null, _TERRAIN
	)
	if not bool(world_report.get("valid", false)):
		return {"accepted": false, "reason": &"world_composition_invalid"}
	var landing_report := PlanetaryLandingCompositionValidator.new().validate_composition(
		_WORLD, _TERRAIN, frame_snapshot, _REGION
	)
	if not bool(landing_report.get("valid", false)):
		return {"accepted": false, "reason": &"landing_composition_invalid"}
	var gravity_policy := PlanetarySurfaceGravityPolicy.new()
	var gravity_configuration := gravity_policy.configure(
		_WORLD, _TERRAIN, frame, reference_surface_gravity_mps2
	)
	if not bool(gravity_configuration.get("accepted", false)):
		return {"accepted": false, "reason": &"gravity_configuration_invalid"}
	var reference_gravity := gravity_policy.sample(_REGION.body_local_center_m)
	if not bool(reference_gravity.get("accepted", false)):
		return {"accepted": false, "reason": &"reference_tangent_unavailable"}
	var reference_tangent_basis := reference_gravity.get(
		"tangent_basis_body_local", Basis.IDENTITY
	) as Basis
	if not reference_tangent_basis.is_equal_approx(_REGION.body_local_basis):
		return {"accepted": false, "reason": &"landing_tangent_basis_mismatch"}
	var landing_root := scene.get_node_or_null(^"LandingRegion") as Node3D
	var walkable_body := scene.get_node_or_null(
		^"LandingRegion/WalkablePatch"
	) as StaticBody3D
	if not _node_is_current(landing_root) or landing_root.get_parent() != scene \
			or not _node_is_current(walkable_body) \
			or walkable_body.get_parent() != landing_root:
		return {"accepted": false, "reason": &"landing_surface_dependency_mismatch"}
	if not berth.global_transform.is_equal_approx(landing_root.global_transform):
		return {"accepted": false, "reason": &"berth_surface_frame_mismatch"}
	if not landing_root.global_basis.is_equal_approx(reference_tangent_basis) \
			or not landing_root.global_position.is_equal_approx(
				bootstrap.global_position + _REGION.body_local_center_m
			):
		return {"accepted": false, "reason": &"landing_surface_frame_mismatch"}
	return {
		"accepted": true,
		"reason": &"valid_dependencies",
		"composition_root": composition_root,
		"origin_owner": origin_owner,
		"origin_binding": origin_binding,
		"scene": scene,
		"frame": frame,
		"boarding_area": boarding_area,
		"landing_root": landing_root,
		"walkable_body": walkable_body,
		"world_report": world_report.duplicate(true),
		"landing_report": landing_report.duplicate(true),
		"gravity_policy": gravity_policy,
		"reference_tangent_basis_body": reference_tangent_basis,
		"ship_collision_bounds": collision_report.local_bounds as AABB,
	}


func _measure_approach_entry() -> Dictionary:
	if _approach_entry_envelope == null:
		return {
			"accepted": false,
			"reason": &"approach_entry_envelope_unavailable",
		}.duplicate(true)
	var current_root_id := _composition_root.get_instance_id() \
		if _node_is_current(_composition_root) else 0
	var current_loaded_scene: Node = _bootstrap.get_loaded_instance() \
		if _node_is_current(_bootstrap) else null
	var bootstrap_snapshot := _bootstrap.get_snapshot() \
		if _node_is_current(_bootstrap) else {}
	var current_frame := _bootstrap.get_coordinate_frame_for_session() \
		if _node_is_current(_bootstrap) else null
	var actor_contract_current: bool = _node_is_current(_ship) \
		and _node_is_current(_player) and _node_is_current(_boarding_area) \
		and not _ship.is_destroyed() and _player.is_seated() \
		and _ship.is_piloted() \
		and _boarding_area.get_reservation_token() == _player
	return _approach_entry_envelope.measure(
		_landing_root.global_transform \
			if _node_is_current(_landing_root) else Transform3D.IDENTITY,
		_ship.global_transform if _node_is_current(_ship) else Transform3D.IDENTITY,
		_ship.velocity if _node_is_current(_ship) else Vector3.INF,
		current_root_id,
		_composition_topology_current(),
		current_loaded_scene.get_instance_id() \
			if _node_is_current(current_loaded_scene) else 0,
		current_frame == _frame,
		current_frame.get_instance_id() if is_instance_valid(current_frame) else 0,
		current_frame.get_generation() if is_instance_valid(current_frame) else -1,
		int(_scene.get_meta(LOCATION_GENERATION_META, -1)) \
			if _node_is_current(_scene) else -1,
		int(bootstrap_snapshot.get("location_generation", -1)),
		actor_contract_current
	)


func _start_ownership_preflight() -> StringName:
	if not _node_is_current(_ship) or not _node_is_current(_player) \
			or not _node_is_current(_boarding_area):
		return &"runtime_ownership_dependency_detached"
	if not is_instance_valid(_original_command_source) \
			or _original_command_source.is_queued_for_deletion() \
			or _ship.get_command_source() != _original_command_source:
		return &"command_source_ownership_changed"
	if _boarding_area.get_reservation_token() != _player:
		return &"boarding_reservation_changed"
	if not _player.is_seated() or not _ship.is_piloted():
		return &"pilot_ownership_changed"
	return &""


func _validate_committed_origin_receipt(receipt: Variant) -> Dictionary:
	if not receipt is Dictionary:
		return {"accepted": false, "reason": &"origin_receipt_not_dictionary"}
	var value := receipt as Dictionary
	if not _has_exact_string_keys(value, ORIGIN_REBASE_RECEIPT_KEYS) \
			or not _detached_value_is_safe(value):
		return {"accepted": false, "reason": &"origin_receipt_schema_mismatch"}
	if not value.schema_version is int or int(value.schema_version) != 1 \
			or not value.reason is StringName or value.reason != &"rebase_committed":
		return {"accepted": false, "reason": &"origin_receipt_identity_mismatch"}
	if not value.actor_kind is StringName \
			or not _is_safe_positive_integer(value.actor_instance_id) \
			or not value.absolute_coordinate is Dictionary \
			or not value.world_translation_delta is Vector3:
		return {"accepted": false, "reason": &"origin_receipt_identity_mismatch"}
	for key in ["transaction_index", "request_id", "source_generation", "target_generation"]:
		if not _is_safe_positive_integer(value.get(key)):
			return {"accepted": false, "reason": &"origin_receipt_serial_invalid"}
	var source_generation := int(value.source_generation)
	var target_generation := int(value.target_generation)
	if source_generation != _coordinate_frame_generation \
			or source_generation >= PlanetaryCoordinateFrame.MAX_GENERATION \
			or target_generation != source_generation + 1:
		return {"accepted": false, "reason": &"origin_receipt_generation_mismatch"}
	var owner_rejection := _origin_owner_receipt_rejection(
		value, source_generation, target_generation
	)
	if not owner_rejection.is_empty():
		return {"accepted": false, "reason": owner_rejection}
	if not _node_is_current(_composition_root) or not _node_is_current(_bootstrap) \
			or not _node_is_current(_scene) or not _node_is_current(_berth) \
			or not _node_is_current(_ship) or not _node_is_current(_player) \
			or not _node_is_current(_boarding_area) \
			or not _node_is_current(_landing_root) \
			or not _node_is_current(_walkable_body):
		return {"accepted": false, "reason": &"origin_receipt_dependency_detached"}
	if _frame == null or _bootstrap.get_coordinate_frame_for_session() != _frame:
		return {"accepted": false, "reason": &"origin_receipt_frame_identity_mismatch"}
	var frame_snapshot := _frame.get_snapshot()
	if int(frame_snapshot.get("generation", 0)) != target_generation \
			or not (frame_snapshot.get("pending_rebase", {}) as Dictionary).is_empty():
		return {"accepted": false, "reason": &"origin_receipt_frame_not_committed"}
	var delta := value.world_translation_delta as Vector3 \
			if value.world_translation_delta is Vector3 else Vector3.INF
	if not delta.is_finite() or delta.is_zero_approx():
		return {"accepted": false, "reason": &"origin_receipt_translation_invalid"}
	var committed := frame_snapshot.get("last_rebase_result", {}) as Dictionary
	if int(committed.get("request_id", 0)) != int(value.request_id) \
			or int(committed.get("source_generation", 0)) != source_generation \
			or int(committed.get("target_generation", 0)) != target_generation \
			or committed.get("world_translation_delta", Vector3.INF) != delta:
		return {"accepted": false, "reason": &"origin_receipt_frame_commit_mismatch"}

	var roster_rejection := _origin_receipt_roster_rejection(value)
	if not roster_rejection.is_empty():
		return {"accepted": false, "reason": roster_rejection}
	if not _composition_topology_current() \
			or _bootstrap.get_loaded_instance() != _scene \
			or _scene.get_instance_id() != _loaded_scene_instance_id \
			or int(_scene.get_meta(LOCATION_GENERATION_META, -1)) != _location_generation:
		return {"accepted": false, "reason": &"origin_receipt_live_identity_mismatch"}
	var bootstrap_snapshot := _bootstrap.get_snapshot()
	if int(bootstrap_snapshot.get("location_generation", -1)) != _location_generation \
			or int(bootstrap_snapshot.get("loaded_instance_id", 0)) \
				!= _loaded_scene_instance_id:
		return {"accepted": false, "reason": &"origin_receipt_stream_generation_mismatch"}
	var streaming := value.ember_streaming as Dictionary \
			if value.ember_streaming is Dictionary else {}
	if not bool(streaming.get("accepted", false)) \
			or int(streaming.get("coordinate_frame_generation", 0)) != target_generation \
			or int(streaming.get("location_generation", -1)) != _location_generation:
		return {"accepted": false, "reason": &"origin_receipt_streaming_mismatch"}
	if not _berth.global_transform.is_equal_approx(_landing_root.global_transform) \
			or not _landing_root.global_basis.is_equal_approx(_reference_tangent_basis_body) \
			or not _landing_root.global_position.is_equal_approx(
				_bootstrap.global_position + _REGION.body_local_center_m
			):
		return {"accepted": false, "reason": &"origin_receipt_surface_frame_drift"}

	var sample := value.adjusted_actor_sample as Dictionary \
			if value.adjusted_actor_sample is Dictionary else {}
	if not _has_exact_string_keys(sample, ORIGIN_REBASE_SAMPLE_KEYS) \
			or not sample.available is bool or not bool(sample.available) \
			or not sample.actor_kind is StringName \
			or not sample.actor_instance_id is int \
			or not sample.position is Vector3 \
			or not (sample.position as Vector3).is_finite():
		return {"accepted": false, "reason": &"origin_receipt_actor_sample_invalid"}
	if value.actor_kind != sample.actor_kind \
			or int(value.actor_instance_id) != int(sample.actor_instance_id):
		return {"accepted": false, "reason": &"origin_receipt_actor_identity_mismatch"}
	var actor: Node3D
	var actor_speed := 0.0
	if sample.actor_kind == &"ship" \
			and int(sample.actor_instance_id) == _ship_instance_id:
		actor = _ship
		actor_speed = _ship.velocity.length()
	elif sample.actor_kind == &"player" \
			and int(sample.actor_instance_id) == _player_instance_id:
		actor = _player
		actor_speed = _player.velocity.length()
	else:
		return {"accepted": false, "reason": &"origin_receipt_actor_identity_mismatch"}
	if not actor.global_position.is_equal_approx(sample.position as Vector3):
		return {"accepted": false, "reason": &"origin_receipt_actor_position_mismatch"}
	var converted := _frame.world_streaming_to_orbital_position(
		actor.global_position, target_generation
	)
	if not bool(converted.get("accepted", false)) \
			or converted.get("coordinate", {}) != value.absolute_coordinate:
		return {"accepted": false, "reason": &"origin_receipt_absolute_coordinate_drift"}
	var observation := _bootstrap.create_travel_observation(
		actor.global_position, actor_speed, target_generation, _location_generation
	)
	if not bool(observation.get("accepted", false)) \
			or observation.get("orbital_coordinate", {}) != value.absolute_coordinate:
		return {"accepted": false, "reason": &"origin_receipt_absolute_observation_drift"}
	return {
		"accepted": true,
		"reason": &"origin_receipt_valid",
		"target_generation": target_generation,
	}


func _origin_owner_receipt_rejection(
	receipt: Dictionary,
	source_generation: int,
	target_generation: int
) -> StringName:
	if _composition_root == self:
		return &"origin_adoption_requires_shared_root"
	if not _node_is_current(_origin_owner) \
			or _origin_owner.get_instance_id() != _origin_owner_instance_id \
			or _origin_owner.get_parent() != _composition_root \
			or not _node_is_current(_origin_binding) \
			or _origin_binding.get_instance_id() != _origin_binding_instance_id \
			or _origin_binding.get_parent() != _composition_root:
		return &"origin_owner_identity_mismatch"
	var owner_audit := _origin_owner.audit()
	var owner_snapshot := _origin_owner.get_snapshot()
	if not bool(owner_audit.get("valid", false)) \
			or int(owner_audit.get("owner_count", 0)) != 1 \
			or int(owner_snapshot.get("bootstrap_instance_id", 0)) \
				!= _bootstrap.get_instance_id() \
			or int(owner_snapshot.get("binding_instance_id", 0)) \
				!= _origin_binding_instance_id \
			or int(owner_snapshot.get("coordinate_frame_instance_id", 0)) \
				!= _frame.get_instance_id():
		return &"origin_owner_identity_mismatch"
	if int(owner_snapshot.get("last_source_generation", 0)) != source_generation \
			or int(owner_snapshot.get("last_target_generation", 0)) \
				!= target_generation \
			or int(owner_snapshot.get("transaction_count", 0)) \
				!= int(receipt.transaction_index) \
			or owner_snapshot.get("last_receipt", {}) != receipt:
		return &"origin_owner_receipt_mismatch"
	var binding_audit := _origin_binding.audit()
	var binding_snapshot := _origin_binding.get_snapshot()
	if not bool(binding_audit.get("valid", false)) \
			or int(binding_snapshot.get("bootstrap_instance_id", 0)) \
				!= _bootstrap.get_instance_id() \
			or int(binding_snapshot.get("coordinate_frame_instance_id", 0)) \
				!= _frame.get_instance_id() \
			or int(binding_snapshot.get("bound_coordinate_frame_generation", 0)) \
				!= target_generation \
			or int(binding_snapshot.get("current_coordinate_frame_generation", 0)) \
				!= target_generation:
		return &"origin_binding_receipt_mismatch"
	return &""


func _origin_receipt_roster_rejection(receipt: Dictionary) -> StringName:
	if _composition_root == self:
		return &"origin_adoption_requires_shared_root"
	if not receipt.root_roster is Array \
			or not receipt.covered_instance_ids is PackedInt64Array \
			or not receipt.covered_node_count is int:
		return &"origin_receipt_roster_schema_mismatch"
	var roots := receipt.root_roster as Array
	var expected_covered_nodes: Array[Node3D] = []
	for candidate in _composition_root.find_children("*", "Node3D", true, false):
		var node := candidate as Node3D
		if not _node_is_current(node):
			return &"origin_receipt_live_roster_detached"
		expected_covered_nodes.append(node)
	expected_covered_nodes.sort_custom(func(left: Node3D, right: Node3D) -> bool:
		return str(_composition_root.get_path_to(left)) \
			< str(_composition_root.get_path_to(right))
	)
	var expected_roots: Array[Node3D] = []
	for node in expected_covered_nodes:
		if (node.get_parent() == _composition_root or node.top_level) \
				and not node is EmberSurfaceLoopHost:
			expected_roots.append(node)
	if roots.size() != expected_roots.size():
		return &"origin_receipt_roster_count_mismatch"
	var previous_path := ""
	for index in roots.size():
		var root_value: Variant = roots[index]
		if not root_value is Dictionary:
			return &"origin_receipt_roster_schema_mismatch"
		var record := root_value as Dictionary
		if not _has_exact_string_keys(record, ORIGIN_REBASE_ROOT_RECORD_KEYS) \
				or not record.path is String or str(record.path).is_empty() \
				or not _is_safe_positive_integer(record.instance_id) \
				or not record.mode is StringName \
				or record.mode not in [&"direct", &"top_level"]:
			return &"origin_receipt_roster_schema_mismatch"
		var path := str(record.path)
		if not previous_path.is_empty() and path <= previous_path:
			return &"origin_receipt_roster_order_mismatch"
		previous_path = path
		var expected_root := expected_roots[index]
		var expected_mode: StringName = &"top_level" \
			if expected_root.top_level else &"direct"
		if path != str(_composition_root.get_path_to(expected_root)) \
				or int(record.instance_id) != expected_root.get_instance_id() \
				or record.mode != expected_mode:
			return &"origin_receipt_roster_identity_mismatch"

	var covered := receipt.covered_instance_ids as PackedInt64Array
	if int(receipt.covered_node_count) != covered.size() \
			or covered.size() != expected_covered_nodes.size():
		return &"origin_receipt_covered_count_mismatch"
	for index in covered.size():
		if covered[index] != expected_covered_nodes[index].get_instance_id():
			return &"origin_receipt_covered_roster_mismatch"
	return &""


func _runtime_ownership_return_preflight() -> StringName:
	if _runtime_ownership_returned or _runtime_bindings_restored:
		return &"runtime_ownership_already_returned"
	if not _node_is_current(_ship) or not _node_is_current(_player) \
			or not _node_is_current(_boarding_area) \
			or not _node_is_current(_berth) \
			or not is_instance_valid(_command_source) \
			or _command_source.is_queued_for_deletion() \
			or not is_instance_valid(_original_command_source) \
			or _original_command_source.is_queued_for_deletion():
		return &"runtime_ownership_dependency_detached"
	if not _host_acquired_boarding_reservation \
			or _boarding_area.get_reservation_token() != _player:
		return &"runtime_ownership_reservation_mismatch"
	if _ship.get_command_source() != _command_source:
		return &"runtime_ownership_command_source_mismatch"
	if not _player.is_seated() or not _ship.is_piloted() \
			or _ship.is_piloted() != _original_ship_piloted \
			or _player.is_control_enabled() != _original_player_control_enabled \
			or _player.get_camera().current != _original_player_camera_current \
			or not is_equal_approx(
				_player.gravity_multiplier, _original_player_gravity_multiplier
			):
		return &"runtime_ownership_actor_state_mismatch"
	if not _berth_token.is_empty() or _berth.get_occupant() != null:
		return &"runtime_ownership_berth_lease_active"
	if _session == null \
			or not bool(_session.get_presentation_snapshot().get("attached", false)):
		return &"runtime_ownership_session_mismatch"
	return &""


func _landed_public_state_is_exact() -> bool:
	if not bool(_ship.get_telemetry().get("landed", false)) \
			or _ship.is_landing_active() or _berth.get_occupant() != _ship \
			or not _berth.has_valid_lease(
				_ship, _berth_token, _ship.get_ship_definition().ship_id
			):
		return false
	var report := _ship.get_landing_contract_report()
	return bool(report.get("contract_accepted", false)) \
		and bool(report.get("strict_dock_acceptance", false)) \
		and report.get("berth_id") == EmberSurfaceBerth.BERTH_ID \
		and _berth.contains_oriented_bounds(
			_ship.global_transform, _ship_collision_bounds, 0.05
		) and _ship_has_current_surface_support()


func _ship_has_current_surface_support() -> bool:
	if not _dependencies_current():
		return false
	var surface_up := _landing_root.global_basis.y.normalized()
	var minimum_projection := INF
	var lowest_corners: Array[Vector3] = []
	for x: float in [_ship_collision_bounds.position.x, _ship_collision_bounds.end.x]:
		for y: float in [_ship_collision_bounds.position.y, _ship_collision_bounds.end.y]:
			for z: float in [_ship_collision_bounds.position.z, _ship_collision_bounds.end.z]:
				var corner := _ship.global_transform * Vector3(x, y, z)
				var projection := corner.dot(surface_up)
				if projection < minimum_projection - 0.001:
					minimum_projection = projection
					lowest_corners.assign([corner])
				elif absf(projection - minimum_projection) <= 0.001:
					lowest_corners.append(corner)
	if lowest_corners.is_empty():
		return false
	var support_centroid := Vector3.ZERO
	for corner: Vector3 in lowest_corners:
		support_centroid += corner
	support_centroid /= float(lowest_corners.size())
	var query := PhysicsRayQueryParameters3D.create(
		support_centroid + surface_up * 0.08,
		support_centroid - surface_up * 0.18,
		PhysicsLayers.WORLD_BODY_LAYER
	)
	query.exclude = [_ship.get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.get("collider") != _walkable_body \
			or (hit.get("normal", Vector3.ZERO) as Vector3).dot(surface_up) < 0.9:
		return false
	var contact_gap := absf(
		((hit.get("position", Vector3.INF) as Vector3) - support_centroid).dot(surface_up)
	)
	return is_finite(contact_gap) and contact_gap <= 0.12


func _token_rejection(
	expected_generation: int,
	expected_attachment_generation: int,
	expected_coordinate_frame_generation: int
) -> StringName:
	var simple := _simple_token_rejection(
		expected_generation, expected_attachment_generation
	)
	if not simple.is_empty():
		return simple
	if expected_coordinate_frame_generation != _coordinate_frame_generation:
		return &"stale_coordinate_frame_generation"
	return &""


func _simple_token_rejection(
	expected_generation: int,
	expected_attachment_generation: int
) -> StringName:
	if not is_inside_tree() or is_queued_for_deletion():
		return &"host_detached"
	if expected_generation != _generation:
		return &"stale_generation"
	if expected_attachment_generation != _attachment_generation:
		return &"stale_attachment_generation"
	if not _attached:
		return &"not_attached"
	return &""


func _dependency_failure_reason() -> StringName:
	if not _node_is_current(_composition_root) \
			or _composition_root.get_instance_id() != _composition_root_instance_id \
			or not _composition_topology_current():
		return &"composition_root_detached"
	if not _node_is_current(_bootstrap):
		return &"dependency_detached"
	if _bootstrap.get_coordinate_frame_for_session() != _frame:
		return &"coordinate_frame_identity_changed"
	if is_instance_valid(_frame) \
			and _frame.get_generation() != _coordinate_frame_generation:
		return &"stale_coordinate_frame_generation"
	var bootstrap_snapshot := _bootstrap.get_snapshot()
	if int(bootstrap_snapshot.get("location_generation", -1)) \
			!= _location_generation \
			or int(bootstrap_snapshot.get("loaded_instance_id", 0)) \
			!= _loaded_scene_instance_id \
			or not _node_is_current(_scene) \
			or _bootstrap.get_loaded_instance() != _scene \
			or int(_scene.get_meta(LOCATION_GENERATION_META, -1)) \
			!= _location_generation:
		return &"stale_loaded_scene_generation"
	if _phase >= Phase.ORBIT_APPROACH and _phase <= Phase.ORBIT_RETURN \
			and _ship.get_command_source() != _command_source:
		return &"command_source_replaced"
	if not _dependencies_current():
		return &"dependency_detached"
	if not _landing_root.global_basis.is_equal_approx(
			_reference_tangent_basis_body
		) or not _landing_root.global_position.is_equal_approx(
			_bootstrap.global_position + _REGION.body_local_center_m
		):
		return &"landing_surface_frame_drift"
	if _ship.is_destroyed():
		return &"ship_destroyed"
	if _phase in [
		Phase.LANDING_APPROACH, Phase.LANDED, Phase.DISEMBARKING,
		Phase.SURFACE_OUTBOUND, Phase.ON_FOOT, Phase.BOARDING,
		Phase.REBOARDED, Phase.TAKEOFF,
	] and (_berth_token.is_empty() or not _berth.has_valid_lease(
		_ship, _berth_token, _ship.get_ship_definition().ship_id
	)):
		return &"berth_lease_lost"
	var reservation: Variant = _boarding_area.get_reservation_token()
	if _phase in [
		Phase.ORBIT_APPROACH, Phase.DESCENT, Phase.SURFACE_APPROACH,
		Phase.LANDING_APPROACH, Phase.LANDED, Phase.DISEMBARKING,
		Phase.BOARDING, Phase.REBOARDED, Phase.TAKEOFF, Phase.ASCENT,
		Phase.ORBIT_RETURN,
	] and reservation != _player:
		return &"boarding_reservation_lost"
	if _phase in [Phase.SURFACE_OUTBOUND, Phase.ON_FOOT] \
			and reservation != null:
		return &"boarding_reservation_unexpected"
	return &""


func _dependencies_current() -> bool:
	return _composition_topology_current() and _node_is_current(_scene) \
		and _node_is_current(_landing_root) and _landing_root.get_parent() == _scene \
		and _node_is_current(_walkable_body) \
		and _walkable_body.get_parent() == _landing_root \
		and _node_is_current(_boarding_area) and _boarding_area.get_parent() == _ship \
		and is_instance_valid(_frame) \
		and _bootstrap.get_coordinate_frame_for_session() == _frame


func _composition_topology_current() -> bool:
	if not _node_is_current(_composition_root) \
			or _composition_root.get_instance_id() != _composition_root_instance_id:
		return false
	if _composition_root != self and get_parent() != _composition_root:
		return false
	if _composition_root != self and (
		not _node_is_current(_origin_owner)
		or _origin_owner.get_instance_id() != _origin_owner_instance_id
		or _origin_owner.get_parent() != _composition_root
		or not _node_is_current(_origin_binding)
		or _origin_binding.get_instance_id() != _origin_binding_instance_id
		or _origin_binding.get_parent() != _composition_root
	):
		return false
	return _node_is_current(_bootstrap) \
		and _bootstrap.get_parent() == _composition_root \
		and _node_is_current(_berth) and _berth.get_parent() == _composition_root \
		and _node_is_current(_ship) and _ship.get_parent() == _composition_root \
		and _node_is_current(_player) and _player.get_parent() == _composition_root


func _player_near_boarding_area() -> bool:
	for nearby in _player.get_nearby_interactables():
		if nearby == _boarding_area:
			return true
	return false


func _queue_intent(
	intent: StringName,
	expected_phase: int,
	expected_generation: int,
	expected_attachment_generation: int
) -> Dictionary:
	if _mutation_active:
		return _result(false, &"reentrant_call")
	_mutation_active = true
	var rejection := _simple_token_rejection(
		expected_generation, expected_attachment_generation
	)
	if not rejection.is_empty():
		return _finish(false, rejection)
	if _phase != expected_phase:
		return _finish(false, &"out_of_order")
	match intent:
		&"disembark": _disembark_requested = true
		&"takeoff": _takeoff_requested = true
		_: return _finish(false, &"unknown_intent")
	return _finish(true, StringName("%s_queued" % intent))


func _region_local_to_world(region_local: Vector3) -> Vector3:
	return _landing_root.to_global(region_local) \
		if _node_is_current(_landing_root) else Vector3.ZERO


func _world_to_reference_tangent(world_position: Vector3) -> Vector3:
	var body_local := world_position - _bootstrap.global_position
	return _reference_tangent_basis_body.transposed() \
		* (body_local - _REGION.body_local_center_m)


func _tangent_distance(first: Vector3, second: Vector3) -> float:
	return Vector2(first.x - second.x, first.z - second.z).length()


func _surface_actor_supported() -> bool:
	if not _dependencies_current() or not _player.is_on_floor():
		return false
	var player_tangent := _world_to_reference_tangent(_player.global_position)
	var live_surface_local := _landing_root.to_local(_player.global_position)
	if player_tangent.distance_to(live_surface_local) > 0.02 \
			or live_surface_local.y < -0.1 or live_surface_local.y > 2.5:
		return false
	var surface_up := _landing_root.global_basis.y.normalized()
	var query := PhysicsRayQueryParameters3D.create(
		_player.global_position + surface_up * 0.25,
		_player.global_position - surface_up * 2.5,
		PhysicsLayers.WORLD_BODY_LAYER
	)
	query.exclude = [_player.get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.get("collider") == _walkable_body \
		and (hit.get("normal", Vector3.ZERO) as Vector3).dot(surface_up) >= 0.9


func _connect_dependency_signals() -> void:
	_connect_signal(_ship.destroyed, _on_ship_destroyed)
	_connect_signal(_ship.landing_completed, _on_landing_completed)
	_connect_signal(_ship.landing_aborted, _on_landing_aborted)
	_connect_signal(_player.disembarking_completed, _on_disembarking_completed)
	_connect_signal(_player.boarding_completed, _on_boarding_completed)
	for record in [
		{"node": _bootstrap, "reason": &"bootstrap_detached"},
		{"node": _scene, "reason": &"loaded_scene_detached"},
		{"node": _berth, "reason": &"berth_detached"},
		{"node": _ship, "reason": &"ship_detached"},
		{"node": _player, "reason": &"player_detached"},
	]:
		var node := record.node as Node
		_connect_signal(node.tree_exiting, _on_dependency_tree_exiting.bind(record.reason))


func _connect_signal(signal_value: Signal, callback: Callable) -> void:
	signal_value.connect(callback)
	_connections.append({"signal": signal_value, "callback": callback})


func _disconnect_dependency_signals() -> void:
	for record in _connections:
		var signal_value := record.signal as Signal
		var callback := record.callback as Callable
		var signal_owner := signal_value.get_object()
		if is_instance_valid(signal_owner) and signal_value.is_connected(callback):
			signal_value.disconnect(callback)
	_connections.clear()


func _restore_runtime_bindings(recover_embodiment: bool = false) -> void:
	if _runtime_bindings_restored:
		return
	_runtime_bindings_restored = true
	var composition_current := _node_is_current(_composition_root)
	var recovered_on_foot := recover_embodiment and composition_current \
		and _node_is_current(_player)
	var recovery := _surface_recovery_transform() if recovered_on_foot else {}
	var safe_surface_recovery := bool(recovery.get("accepted", false))
	if recovered_on_foot:
		var recovery_transform := recovery.get(
			"transform", _player.global_transform
		) as Transform3D
		_player.force_recovery_to_on_foot(recovery_transform)
	if composition_current and _node_is_current(_ship):
		_ship.set_canopy_open(false, 0.0)
		# Restore only the capability still owned by this host. A later production
		# owner may synchronously replace the source to stop the loop; cleanup must
		# terminalize without overwriting that foreign live authority.
		if _ship.get_command_source() == _command_source:
			_ship.set_command_source(_original_command_source)
		_ship.set_piloted(
			false if recovered_on_foot or _ship.is_destroyed() \
			else _original_ship_piloted
		)
	if composition_current and _node_is_current(_player):
		_player.gravity_multiplier = _original_player_gravity_multiplier
		_player.set_camera_active(
			true if recovered_on_foot else _original_player_camera_current
		)
		_player.set_control_enabled(
			true if safe_surface_recovery else _original_player_control_enabled
		)
	if is_instance_valid(_command_source):
		if _command_source.get_snapshot().attached:
			_command_source.detach(_source_generation)
		_command_source.queue_free()


func _surface_recovery_transform() -> Dictionary:
	if not _dependencies_current() or _ship.is_destroyed() \
			or not bool(_ship.get_telemetry().get("landed", false)):
		return {"accepted": false}
	var recovery := _ship.get_exit_transform()
	var recovery_tangent := _world_to_reference_tangent(recovery.origin)
	if absf(recovery_tangent.x) > 47.5 or absf(recovery_tangent.z) > 47.5:
		return {"accepted": false}
	var surface_up := _landing_root.global_basis.y.normalized()
	var query := PhysicsRayQueryParameters3D.create(
		recovery.origin + surface_up * 4.0,
		recovery.origin - surface_up * 4.0,
		PhysicsLayers.WORLD_BODY_LAYER
	)
	query.exclude = [_ship.get_rid(), _player.get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.get("collider") != _walkable_body \
			or (hit.get("normal", Vector3.ZERO) as Vector3).dot(surface_up) < 0.9:
		return {"accepted": false}
	var surface_position := hit.get("position", Vector3.INF) as Vector3
	if not surface_position.is_finite():
		return {"accepted": false}
	return {
		"accepted": true,
		"transform": Transform3D(
			recovery.basis.orthonormalized(), surface_position + surface_up * 0.02
		),
	}


func _release_leases() -> void:
	if _node_is_current(_berth) and _node_is_current(_ship) \
			and not _berth_token.is_empty():
		_berth.release(_ship, _berth_token)
	_berth_token = &""
	if _host_acquired_boarding_reservation \
			and _node_is_current(_boarding_area) and _node_is_current(_player):
		_boarding_area.release_reservation(_player)
	_host_acquired_boarding_reservation = false


func _commit_failure(reason: StringName) -> Dictionary:
	if _phase == Phase.FAILED:
		return _finish(false, _terminal_reason)
	var recover_embodiment := _phase in [Phase.DISEMBARKING, Phase.BOARDING]
	var should_fail_session := _phase not in [Phase.IDLE, Phase.COMPLETED]
	_terminal_reason = reason
	_pending_failure_reason = &""
	_set_phase(Phase.FAILED)
	if should_fail_session and _session != null:
		_session.fail(reason, _generation, _session.get_attachment_generation())
	if is_instance_valid(_command_source):
		_command_source.set_mode(EmberSurfaceLoopCommandSource.Mode.NEUTRAL, _source_generation)
	_release_leases()
	_disconnect_dependency_signals()
	_restore_runtime_bindings(recover_embodiment)
	return _finish(false, reason)


func _on_ship_destroyed(_world_position: Vector3, _inherited_velocity: Vector3) -> void:
	_queue_terminal(&"ship_destroyed")


func _on_dependency_tree_exiting(reason: StringName) -> void:
	_queue_terminal(reason)


func _queue_terminal(reason: StringName) -> void:
	if _phase in [Phase.IDLE, Phase.COMPLETED, Phase.FAILED]:
		return
	if _pending_failure_reason.is_empty():
		_pending_failure_reason = reason
	if not _mutation_active:
		_mutation_active = true
		var pending := _pending_failure_reason
		_pending_failure_reason = &""
		_commit_failure(pending)


func _on_landing_completed() -> void:
	_landing_completed_observed = true


func _on_landing_aborted(reason: StringName) -> void:
	_landing_aborted_reason = reason


func _on_disembarking_completed() -> void:
	_disembarking_completed_observed = true


func _on_boarding_completed() -> void:
	_boarding_completed_observed = true


func _exit_tree() -> void:
	if _attached:
		var recover_embodiment := _phase in [Phase.DISEMBARKING, Phase.BOARDING]
		if _phase not in [Phase.IDLE, Phase.COMPLETED, Phase.FAILED] \
				and _session != null:
			_terminal_reason = &"host_detached"
			_set_phase(Phase.FAILED)
			_session.fail(
				&"host_detached", _generation, _session.get_attachment_generation()
			)
		if _session != null:
			_session.detach(_generation, _session.get_attachment_generation())
		_disconnect_dependency_signals()
		_release_leases()
		_restore_runtime_bindings(recover_embodiment)
		_attached = false
		_attachment_generation += 1


func _set_phase(next_phase: int) -> void:
	if _phase == next_phase:
		return
	_phase = next_phase
	_phase_elapsed_seconds = 0.0
	_transition_count += 1


func _finish(accepted: bool, reason: StringName) -> Dictionary:
	if not _pending_failure_reason.is_empty() \
			and _phase not in [Phase.IDLE, Phase.COMPLETED, Phase.FAILED]:
		var pending := _pending_failure_reason
		_pending_failure_reason = &""
		return _commit_failure(pending)
	_mutation_active = false
	_last_result = _result(accepted, reason)
	return _last_result.duplicate(true)


func _result(accepted: bool, reason: StringName) -> Dictionary:
	var result := get_snapshot()
	result["accepted"] = accepted
	result["reason"] = reason
	return result.duplicate(true)


func _owned_capabilities() -> Dictionary:
	var result := {}
	for key in OWNED_CAPABILITY_KEYS:
		result[key] = true
	return result.duplicate(true)


func _adjacent_authority() -> Dictionary:
	var result := {}
	for key in ADJACENT_AUTHORITY_KEYS:
		result[key] = false
	return result.duplicate(true)


static func _node_is_current(node: Variant) -> bool:
	return is_instance_valid(node) and node is Node \
		and (node as Node).is_inside_tree() \
		and not (node as Node).is_queued_for_deletion()


static func _has_exact_string_keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for key: Variant in value:
		if not key is String or not expected.has(key):
			return false
	return true


static func _is_safe_positive_integer(value: Variant) -> bool:
	return value is int and int(value) >= 1 and int(value) <= MAX_SAFE_INTEGER


static func _detached_value_is_safe(value: Variant) -> bool:
	match typeof(value):
		TYPE_OBJECT, TYPE_CALLABLE, TYPE_SIGNAL:
			return false
		TYPE_DICTIONARY:
			for key: Variant in (value as Dictionary):
				if not _detached_value_is_safe(key) \
						or not _detached_value_is_safe((value as Dictionary)[key]):
					return false
		TYPE_ARRAY:
			for item: Variant in (value as Array):
				if not _detached_value_is_safe(item):
					return false
	return true


static func _phase_id(value: int) -> StringName:
	match value:
		Phase.IDLE: return &"idle"
		Phase.ORBIT_APPROACH: return &"orbit_approach"
		Phase.DESCENT: return &"descent"
		Phase.SURFACE_APPROACH: return &"surface_approach"
		Phase.LANDING_APPROACH: return &"landing_approach"
		Phase.LANDED: return &"landed"
		Phase.DISEMBARKING: return &"disembarking"
		Phase.SURFACE_OUTBOUND: return &"surface_outbound"
		Phase.ON_FOOT: return &"on_foot"
		Phase.BOARDING: return &"boarding"
		Phase.REBOARDED: return &"reboarded"
		Phase.TAKEOFF: return &"takeoff"
		Phase.ASCENT: return &"ascent"
		Phase.ORBIT_RETURN: return &"orbit_return"
		Phase.COMPLETED: return &"completed"
		Phase.FAILED: return &"failed"
		_: return &"unknown"
