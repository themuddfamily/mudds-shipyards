class_name PlanetaryCruiseProductionBinding
extends Node

## Main-owned, caller-driven production adapter for one Ember cruise request.
##
## GameFlow supplies its already adjusted actor sample after Ember streaming and
## any common-origin transaction. This component decodes the one retained
## absolute Ember navigation anchor in the exact current coordinate frame, then
## delegates proof, policy evaluation, and detached intent delivery to its one
## PlanetaryCruisePhysicalController. HeroShip remains the only mover.

signal engagement_changed(snapshot: Dictionary)
signal tick_committed(receipt: Dictionary)
signal final_approach_completed(receipt: Dictionary)
signal return_approach_completed(receipt: Dictionary)

const SCHEMA_VERSION := 1
const MAX_SAFE_INTEGER := 9_007_199_254_740_991
const DEFAULT_BOOTSTRAP_PATH := NodePath("../EmberMoonStreamingBootstrap")
const DESTINATION_ID: StringName = &"ember_navigation"
const DESTINATION_SOURCE_ID: StringName = &"ember_navigation_body_local"
const DESTINATION_RESOURCE_PATH := "res://assets/world/locations/ember_moon.tres"
const _ControllerType := preload(
	"res://scripts/control/planetary_cruise_physical_controller.gd"
)
const _PolicyType := preload("res://scripts/world/planetary_cruise_policy.gd")
## The transit leg this binding can carry under the cruise controller's
## authority: `ember_outbound` cruises to the canonical anchor and flies the
## armed final approach into the caldera corridor. An empty leg is the
## historical behaviour (the Mudds return approach still uses it).
const TRANSIT_LEG_EMBER_OUTBOUND: StringName = &"ember_outbound"
const TRANSIT_LEGS := [TRANSIT_LEG_EMBER_OUTBOUND]
const _EMBER_LOCATION := preload(DESTINATION_RESOURCE_PATH)
const _SAMPLE_KEYS := [
	"actor_instance_id",
	"actor_kind",
	"available",
	"position",
]
const _COMMON_AUTHORITY_KEYS := [
	"renderer", "gameplay", "streaming", "save", "network", "physics",
	"world_generation", "terrain_generation", "collision_generation",
	"origin_shift", "weather_clock", "audio",
]

@export var bootstrap_path: NodePath = DEFAULT_BOOTSTRAP_PATH

var _controller: PlanetaryCruisePhysicalController
var _bootstrap: EmberMoonStreamingBootstrap
var _frame: PlanetaryCoordinateFrame
var _activated := false
var _configuration_error: StringName = &""
var _bootstrap_instance_id := 0
var _frame_instance_id := 0
var _controller_instance_id := 0
var _canonical_destination_orbital: Dictionary = {}
var _generation := 1
var _engagement_requested := false
var _engaged_ship_ref: WeakRef
var _engaged_ship_instance_id := 0
var _bound_frame_generation := 0
var _last_caller_tick := 0
var _accepted_tick_count := 0
var _rejected_tick_count := 0
var _rebind_count := 0
var _retirement_count := 0
var _reentrant_rejection_count := 0
var _last_reason: StringName = &"not_activated"
var _last_destination_world := Vector3.ZERO
var _last_result: Dictionary = {}
var _final_approach_target_generation := 0
var _final_approach_location_generation := 0
var _final_approach_host_generation := -1
var _final_approach_host_attachment_generation := 0
var _final_approach_host_ref: WeakRef
var _final_approach_host_instance_id := 0
var _final_approach_landing_root_ref: WeakRef
var _final_approach_landing_root_instance_id := 0
var _final_approach_landing_root_transform := Transform3D.IDENTITY
var _final_approach_completion_receipt: Dictionary = {}
var _final_approach_completion_consumed := false
var _final_approach_completion_count := 0
var _approach_kind: StringName = &""
var _return_approach_home_target_transform := Transform3D.IDENTITY
var _transit_leg: StringName = &""
var _transit_progress: Dictionary = {}
var _translated_frame_generation := 0
var _mutation_active := false
var _signal_dispatch_active := false


func _init() -> void:
	set_process(false)
	set_physics_process(false)
	_controller = _ControllerType.new() as PlanetaryCruisePhysicalController
	_controller.name = "PlanetaryCruisePhysicalController"
	add_child(_controller)


func _enter_tree() -> void:
	set_process(false)
	set_physics_process(false)


func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	call_deferred(&"_activate_scene_binding")


func _exit_tree() -> void:
	if _engagement_requested:
		_mutation_active = true
		_retire_engagement_guarded(&"binding_detached", true)
		_mutation_active = false
	_final_approach_target_generation = 0
	_final_approach_location_generation = 0
	_final_approach_host_generation = -1
	_final_approach_host_attachment_generation = 0
	_final_approach_host_ref = null
	_final_approach_host_instance_id = 0
	_final_approach_landing_root_ref = null
	_final_approach_landing_root_instance_id = 0
	_final_approach_completion_receipt.clear()
	_final_approach_completion_consumed = false
	_approach_kind = &""
	_return_approach_home_target_transform = Transform3D.IDENTITY
	_transit_leg = &""
	_transit_progress.clear()
	_translated_frame_generation = 0
	set_process(false)
	set_physics_process(false)


## Starts one explicit Ember-navigation cruise request. This records desired
## participation only after the exact live ship and current frame are bound.
## Policy and movement do not begin until the next accepted caller tick.
## `transit_leg` (one of `TRANSIT_LEGS`, or empty) makes the binding carry the
## whole leg under the controller's authority: per-tick guidance, attitude, the
## standoff brake and the approach profile.
func request_engage(
		ship: HeroShip,
		expected_coordinate_frame_generation: int,
		production_gate_reason: StringName,
		expected_generation: int,
		transit_leg: StringName = &"",
	) -> Dictionary:
	var preflight := _mutation_preflight(expected_generation)
	if not preflight.is_empty():
		return _result(false, preflight)
	if _engagement_requested:
		return _result(false, &"already_engaged")
	if not transit_leg.is_empty() and not TRANSIT_LEGS.has(transit_leg):
		return _result(false, &"transit_leg_invalid")
	# One further generation is reserved for the retirement of every accepted
	# engagement. Accepting at MAX-1 would bind a live controller at MAX and make
	# every later fail-closed release unrepresentable.
	if _generation >= MAX_SAFE_INTEGER - 1:
		return _result(false, &"generation_exhausted")
	if not production_gate_reason.is_empty():
		return _result(false, production_gate_reason)
	var identity_reason := _identity_preflight()
	if not identity_reason.is_empty():
		return _result(false, identity_reason)
	var ship_reason := _validate_live_ship(ship)
	if not ship_reason.is_empty():
		return _result(false, ship_reason)
	if expected_coordinate_frame_generation != _frame.get_generation():
		return _result(false, &"coordinate_frame_generation_mismatch")
	if _final_approach_target_generation > 0:
		if not _final_approach_completion_consumed:
			return _result(false, &"final_approach_completion_unconsumed")
		_final_approach_target_generation = 0
		_final_approach_location_generation = 0
		_final_approach_host_generation = -1
		_final_approach_host_attachment_generation = 0
		_final_approach_host_ref = null
		_final_approach_host_instance_id = 0
		_final_approach_landing_root_ref = null
		_final_approach_landing_root_instance_id = 0
		_final_approach_landing_root_transform = Transform3D.IDENTITY
		_approach_kind = &""
		_return_approach_home_target_transform = Transform3D.IDENTITY
	_mutation_active = true
	var bind := _controller.bind_ship(
		ship,
		expected_coordinate_frame_generation,
		_controller.get_generation()
	)
	if not bool(bind.get("accepted", false)):
		_mutation_active = false
		return _result(
			false,
			StringName(bind.get("reason", &"controller_bind_rejected")),
		)
	_engagement_requested = true
	_engaged_ship_ref = weakref(ship)
	_engaged_ship_instance_id = ship.get_instance_id()
	_bound_frame_generation = expected_coordinate_frame_generation
	_transit_leg = transit_leg
	_transit_progress.clear()
	_translated_frame_generation = 0
	_last_reason = &"engaged_for_next_physics_tick"
	_generation = _next_generation(_generation)
	_last_result = _result(true, _last_reason)
	_mutation_active = false
	_emit_engagement_changed()
	return _last_result.duplicate(true)


## Ends the request and asks HeroShip to perform its already bounded brake. A
## stale controller/ship attachment is reconciled locally rather than retried.
func request_disengage(
		expected_generation: int,
		brake_to_stop: bool = true,
	) -> Dictionary:
	var preflight := _mutation_preflight(expected_generation)
	if not preflight.is_empty():
		return _result(false, preflight)
	if not _engagement_requested:
		return _result(true, &"already_disengaged")
	_mutation_active = true
	var retired := _retire_engagement_guarded(
		&"explicit_disengage", brake_to_stop
	)
	_mutation_active = false
	if bool(retired.get("accepted", false)):
		_emit_engagement_changed()
	return retired.duplicate(true)


func request_final_approach(
		host: EmberSurfaceLoopHost,
		landing_root: Node3D,
		approach_envelope: Dictionary,
	expected_coordinate_frame_generation: int,
	expected_location_generation: int,
	expected_host_generation: int,
	expected_host_attachment_generation: int,
	expected_generation: int,
	) -> Dictionary:
	var preflight := _mutation_preflight(expected_generation)
	if not preflight.is_empty():
		return _result(false, preflight)
	if not _engagement_requested:
		return _result(false, &"not_engaged")
	if _final_approach_target_generation > 0:
		return _result(false, &"final_approach_already_requested")
	if expected_coordinate_frame_generation != _bound_frame_generation:
		return _result(false, &"coordinate_frame_generation_mismatch")
	if expected_location_generation < 1 \
			or expected_location_generation > MAX_SAFE_INTEGER:
		return _result(false, &"location_generation_out_of_bounds")
	if expected_host_generation < 0 \
			or expected_host_generation > MAX_SAFE_INTEGER \
			or expected_host_attachment_generation < 1 \
			or expected_host_attachment_generation > MAX_SAFE_INTEGER:
		return _result(false, &"host_generation_out_of_bounds")
	if host == null or not is_instance_valid(host) \
			or host.is_queued_for_deletion() or not host.is_inside_tree():
		return _result(false, &"final_approach_host_unavailable")
	var host_snapshot := host.get_snapshot()
	if not bool(host_snapshot.get("attached", false)) \
			or int(host_snapshot.get("phase", -1)) != EmberSurfaceLoopHost.Phase.IDLE \
			or int(host_snapshot.get("generation", -1)) != expected_host_generation \
			or int(host_snapshot.get("attachment_generation", -1)) \
				!= expected_host_attachment_generation \
			or int(host_snapshot.get("coordinate_frame_generation", -1)) \
				!= expected_coordinate_frame_generation \
			or int(host_snapshot.get("location_generation", -1)) \
				!= expected_location_generation:
		return _result(false, &"final_approach_host_generation_mismatch")
	if landing_root == null or not is_instance_valid(landing_root) \
			or landing_root.is_queued_for_deletion() \
			or not landing_root.is_inside_tree():
		return _result(false, &"landing_root_unavailable")
	var envelope_reason := _validate_final_approach_envelope(approach_envelope)
	if not envelope_reason.is_empty():
		return _result(false, envelope_reason)
	if _final_approach_completion_count >= MAX_SAFE_INTEGER:
		return _result(false, &"final_approach_generation_exhausted")
	var target := _ControllerType.FinalApproachTarget.new()
	target.target_generation = _final_approach_completion_count + 1
	target.coordinate_frame_generation = expected_coordinate_frame_generation
	target.location_generation = expected_location_generation
	target.landing_root_instance_id = landing_root.get_instance_id()
	target.corridor_id = approach_envelope.get("corridor_id", &"") as StringName
	target.target_pad_id = approach_envelope.get("target_pad_id", &"") as StringName
	var corridor_local := approach_envelope.get(
		"corridor_transform_region_local_m", Transform3D.IDENTITY
	) as Transform3D
	target.target_world_transform = landing_root.global_transform * corridor_local
	target.corridor_half_extents_m = approach_envelope.get(
		"corridor_half_extents_m", Vector3.ZERO
	) as Vector3
	target.entry_position_half_extents_m = approach_envelope.get(
		"entry_position_half_extents_m", Vector3.ZERO
	) as Vector3
	target.maximum_speed_mps = float(
		approach_envelope.get("maximum_speed_mps", 0.0)
	)
	target.maximum_attitude_degrees = float(
		approach_envelope.get("maximum_attitude_degrees", 0.0)
	)
	target.hull_margin_m = float(approach_envelope.get("hull_margin_m", -1.0))
	target.collision_bounds = approach_envelope.get("collision_bounds", AABB()) as AABB
	_mutation_active = true
	var armed := _controller.arm_final_approach(
		target, expected_coordinate_frame_generation, _controller.get_generation()
	)
	if not bool(armed.get("accepted", false)):
		_mutation_active = false
		return _result(false, StringName(
			armed.get("reason", &"controller_final_approach_rejected")
		))
	_final_approach_target_generation = target.target_generation
	_approach_kind = _ControllerType.FINAL_APPROACH_KIND
	_final_approach_location_generation = expected_location_generation
	_final_approach_host_generation = expected_host_generation
	_final_approach_host_attachment_generation = expected_host_attachment_generation
	_final_approach_host_ref = weakref(host)
	_final_approach_host_instance_id = host.get_instance_id()
	_final_approach_landing_root_ref = weakref(landing_root)
	_final_approach_landing_root_instance_id = landing_root.get_instance_id()
	_final_approach_landing_root_transform = landing_root.global_transform
	_final_approach_completion_receipt.clear()
	_final_approach_completion_consumed = false
	_last_reason = &"final_approach_armed"
	_last_result = _result(true, _last_reason, {
		"final_approach": armed.get("final_approach", {}).duplicate(true),
	})
	_mutation_active = false
	_emit_engagement_changed()
	return _last_result.duplicate(true)


func request_return_approach(
		return_target: Dictionary,
		expected_coordinate_frame_generation: int,
		expected_generation: int,
	) -> Dictionary:
	var preflight := _mutation_preflight(expected_generation)
	if not preflight.is_empty():
		return _result(false, preflight)
	if not _engagement_requested:
		return _result(false, &"not_engaged")
	if _final_approach_target_generation > 0:
		return _result(false, &"approach_already_requested")
	if expected_coordinate_frame_generation != _bound_frame_generation:
		return _result(false, &"coordinate_frame_generation_mismatch")
	if _frame == null \
			or expected_coordinate_frame_generation != _frame.get_generation():
		return _result(false, &"coordinate_frame_generation_mismatch")
	var target_reason := _validate_return_approach_target(return_target)
	if not target_reason.is_empty():
		return _result(false, target_reason)
	if _final_approach_completion_count >= MAX_SAFE_INTEGER:
		return _result(false, &"return_approach_generation_exhausted")
	var ship := _resolve_engaged_ship_even_if_detached()
	if ship == null:
		return _result(false, &"ship_unavailable")
	var active_ship_id := ship.get_ship_id()
	var fleet_bounds := return_target.get("fleet_collision_bounds", {}) as Dictionary
	if not fleet_bounds.has(active_ship_id) or not fleet_bounds[active_ship_id] is AABB:
		return _result(false, &"return_approach_active_hull_missing")
	var collision_report := ship.get_landing_collision_report()
	var live_bounds := collision_report.get("local_bounds", AABB()) as AABB
	if not bool(collision_report.get("valid", false)) \
			or live_bounds != (fleet_bounds[active_ship_id] as AABB):
		return _result(false, &"return_approach_active_hull_mismatch")
	var target := _ControllerType.ReturnApproachTarget.new()
	target.target_generation = _final_approach_completion_count + 1
	target.coordinate_frame_generation = expected_coordinate_frame_generation
	target.home_target_id = return_target.get("home_target_id", &"") as StringName
	target.home_target_world_transform = return_target.get(
		"home_target_world_transform", Transform3D.IDENTITY
	) as Transform3D
	target.corridor_half_extents_m = return_target.get(
		"corridor_half_extents_m", Vector3.ZERO
	) as Vector3
	target.brake_shell_min_distance_m = float(
		return_target.get("brake_shell_min_distance_m", 0.0)
	)
	target.brake_shell_max_distance_m = float(
		return_target.get("brake_shell_max_distance_m", 0.0)
	)
	target.maximum_speed_mps = float(
		return_target.get("maximum_speed_mps", 0.0)
	)
	target.maximum_attitude_degrees = float(
		return_target.get("maximum_attitude_degrees", 0.0)
	)
	target.hull_margin_m = float(return_target.get("hull_margin_m", -1.0))
	target.active_ship_id = active_ship_id
	target.collision_bounds = live_bounds
	target.fleet_collision_bounds = fleet_bounds.duplicate(true)
	_mutation_active = true
	var armed := _controller.arm_return_approach(
		target, expected_coordinate_frame_generation, _controller.get_generation()
	)
	if not bool(armed.get("accepted", false)):
		_mutation_active = false
		return _result(false, StringName(
			armed.get("reason", &"controller_return_approach_rejected")
		))
	_final_approach_target_generation = target.target_generation
	_approach_kind = _ControllerType.RETURN_APPROACH_KIND
	_return_approach_home_target_transform = target.home_target_world_transform
	_final_approach_completion_receipt.clear()
	_final_approach_completion_consumed = false
	_last_reason = &"return_approach_armed"
	_last_result = _result(true, _last_reason, {
		"return_approach": armed.get("final_approach", {}).duplicate(true),
	})
	_mutation_active = false
	_emit_engagement_changed()
	return _last_result.duplicate(true)


func consume_final_approach_completion(
		expected_target_generation: int,
		expected_generation: int,
	) -> Dictionary:
	var preflight := _mutation_preflight(expected_generation)
	if not preflight.is_empty():
		return _result(false, preflight)
	if _approach_kind != _ControllerType.FINAL_APPROACH_KIND:
		return _result(false, &"final_approach_completion_unavailable")
	if _final_approach_completion_receipt.is_empty():
		return _result(false, &"final_approach_completion_unavailable")
	if expected_target_generation != int(
		_final_approach_completion_receipt.get("target_generation", 0)
	):
		return _result(false, &"final_approach_generation_mismatch")
	if _final_approach_completion_consumed:
		return _result(false, &"final_approach_completion_replayed")
	_mutation_active = true
	_final_approach_completion_consumed = true
	var receipt := _final_approach_completion_receipt.duplicate(true)
	_mutation_active = false
	return receipt


func consume_return_approach_completion(
		expected_target_generation: int,
		expected_generation: int,
	) -> Dictionary:
	var preflight := _mutation_preflight(expected_generation)
	if not preflight.is_empty():
		return _result(false, preflight)
	if _approach_kind != _ControllerType.RETURN_APPROACH_KIND \
			or _final_approach_completion_receipt.is_empty():
		return _result(false, &"return_approach_completion_unavailable")
	if expected_target_generation != int(
		_final_approach_completion_receipt.get("target_generation", 0)
	):
		return _result(false, &"return_approach_generation_mismatch")
	if _final_approach_completion_consumed:
		return _result(false, &"return_approach_completion_replayed")
	_mutation_active = true
	_final_approach_completion_consumed = true
	var receipt := _final_approach_completion_receipt.duplicate(true)
	_mutation_active = false
	return receipt


func discard_final_approach_completion(
		expected_target_generation: int,
		expected_generation: int,
		reason: StringName,
	) -> Dictionary:
	var preflight := _mutation_preflight(expected_generation)
	if not preflight.is_empty():
		return _result(false, preflight)
	if _approach_kind != _ControllerType.FINAL_APPROACH_KIND:
		return _result(false, &"final_approach_completion_unavailable")
	if _final_approach_completion_receipt.is_empty():
		return _result(false, &"final_approach_completion_unavailable")
	if expected_target_generation != int(
		_final_approach_completion_receipt.get("target_generation", 0)
	):
		return _result(false, &"final_approach_generation_mismatch")
	_mutation_active = true
	_final_approach_completion_receipt.clear()
	_final_approach_completion_consumed = true
	_final_approach_target_generation = 0
	_final_approach_location_generation = 0
	_final_approach_host_generation = -1
	_final_approach_host_attachment_generation = 0
	_final_approach_host_ref = null
	_final_approach_host_instance_id = 0
	_final_approach_landing_root_ref = null
	_final_approach_landing_root_instance_id = 0
	_final_approach_landing_root_transform = Transform3D.IDENTITY
	_approach_kind = &""
	_return_approach_home_target_transform = Transform3D.IDENTITY
	_last_reason = reason
	_last_result = _result(true, reason)
	_mutation_active = false
	_emit_engagement_changed()
	return _last_result.duplicate(true)


func discard_return_approach_completion(
		expected_target_generation: int,
		expected_generation: int,
		reason: StringName,
	) -> Dictionary:
	var preflight := _mutation_preflight(expected_generation)
	if not preflight.is_empty():
		return _result(false, preflight)
	if _approach_kind != _ControllerType.RETURN_APPROACH_KIND \
			or _final_approach_completion_receipt.is_empty():
		return _result(false, &"return_approach_completion_unavailable")
	if expected_target_generation != int(
		_final_approach_completion_receipt.get("target_generation", 0)
	):
		return _result(false, &"return_approach_generation_mismatch")
	_mutation_active = true
	_final_approach_completion_receipt.clear()
	_final_approach_completion_consumed = true
	_final_approach_target_generation = 0
	_approach_kind = &""
	_return_approach_home_target_transform = Transform3D.IDENTITY
	_last_reason = reason
	_last_result = _result(true, reason)
	_mutation_active = false
	_emit_engagement_changed()
	return _last_result.duplicate(true)


## Fixed-reason terminal seam used only when GameFlow's safe physics serial can
## no longer advance. It cannot counterfeit a wrapped caller identity.
func request_caller_tick_exhausted(expected_generation: int) -> Dictionary:
	var preflight := _mutation_preflight(expected_generation)
	if not preflight.is_empty():
		return _result(false, preflight)
	if not _engagement_requested:
		return _result(false, &"caller_tick_exhausted")
	_mutation_active = true
	var retired := _retire_engagement_guarded(
		&"caller_tick_exhausted", true
	)
	_mutation_active = false
	if bool(retired.get("accepted", false)):
		_emit_engagement_changed()
	return retired.duplicate(true)


## Routes one post-rebase GameFlow observation into at most one controller
## envelope. `caller_tick` is a process-lifetime monotonic GameFlow physics
## serial; duplicate or replayed calls cannot mint a second command.
func physics_tick_from_caller_sample(
		caller_tick: int,
		sample: Variant,
		ship: HeroShip,
		expected_coordinate_frame_generation: int,
		combat_active: bool,
		production_gate_reason: StringName,
		expected_location_generation: int = 0,
	) -> Dictionary:
	if _mutation_active or _signal_dispatch_active:
		_reentrant_rejection_count += 1
		return _result(false, &"reentrant_call")
	if not _binding_is_live():
		return _result(false, &"binding_unavailable")
	_mutation_active = true
	var identity_reason := _identity_preflight()
	if not identity_reason.is_empty():
		return _fail_tick_guarded(identity_reason, true)
	if caller_tick < 1 or caller_tick > MAX_SAFE_INTEGER:
		return _fail_tick_guarded(&"caller_tick_out_of_bounds", true)
	if caller_tick <= _last_caller_tick:
		_mutation_active = false
		return _result(false, &"caller_tick_replay")
	# Claim the cadence before interpreting input. A malformed newest observation
	# cannot be retried under the same physics identity.
	_last_caller_tick = caller_tick
	if not _engagement_requested:
		_last_reason = &"not_engaged"
		_last_result = _result(true, _last_reason)
		_mutation_active = false
		return _last_result.duplicate(true)
	var sample_reason := _validate_sample(sample, ship)
	if not sample_reason.is_empty():
		return _fail_tick_guarded(sample_reason, true)
	if not production_gate_reason.is_empty():
		return _fail_tick_guarded(production_gate_reason, true)
	var ship_reason := _validate_engaged_ship(ship)
	if not ship_reason.is_empty():
		return _fail_tick_guarded(ship_reason, true)
	if _final_approach_target_generation > 0 \
			and expected_coordinate_frame_generation != _bound_frame_generation \
			and _translated_frame_generation != expected_coordinate_frame_generation:
		# A frame that moved under an armed target without the owning rebase
		# transaction announcing its translation here still fails closed.
		return _fail_tick_guarded(
			&"return_approach_rebase_aborted" \
				if _approach_kind == _ControllerType.RETURN_APPROACH_KIND \
				else &"final_approach_rebase_aborted",
			true,
		)
	if expected_coordinate_frame_generation != _frame.get_generation():
		return _fail_tick_guarded(&"coordinate_frame_generation_mismatch", true)
	var frame_binding := _ensure_current_frame_binding(
		ship, expected_coordinate_frame_generation
	)
	if not bool(frame_binding.get("accepted", false)):
		# A braking approach reaches zero speed and `HeroShip` retires its own
		# cruise attachment on that same tick — which, for an approach, is
		# exactly the tick the craft comes to rest inside the authored entry
		# volume. Retiring here would discard a target whose arrival has already
		# physically happened, leaving the craft parked in the corridor with no
		# handoff. Take that one arrival measurement from the current public ship
		# state first; only a rejected measurement retires.
		if bool(frame_binding.get("reconcile_pending", false)):
			var settled := _settle_retired_approach_arrival_guarded(caller_tick)
			if not settled.is_empty():
				return settled
			_controller.reconcile_retired_ship_binding(_controller.get_generation())
		return _fail_tick_guarded(
			StringName(frame_binding.get("reason", &"frame_rebind_rejected")),
			true,
		)
	if _final_approach_target_generation > 0 \
			and _approach_kind == _ControllerType.FINAL_APPROACH_KIND:
		if expected_location_generation != _final_approach_location_generation:
			return _fail_tick_guarded(&"location_generation_mismatch", true)
		var target_source_reason := _final_approach_source_rejection()
		if not target_source_reason.is_empty():
			return _fail_tick_guarded(target_source_reason, true)
	var destination_world := _return_approach_home_target_transform.origin \
		if _approach_kind == _ControllerType.RETURN_APPROACH_KIND \
		else Vector3.INF
	if _approach_kind != _ControllerType.RETURN_APPROACH_KIND:
		var destination := _frame.orbital_to_world_streaming_position(
			_canonical_destination_orbital,
			expected_coordinate_frame_generation,
		)
		if not bool(destination.get("accepted", false)):
			return _fail_tick_guarded(
				StringName(destination.get("reason", &"destination_decode_rejected")),
				true,
			)
		destination_world = destination.get("position", Vector3.INF) as Vector3
	if not destination_world.is_finite():
		return _fail_tick_guarded(&"destination_nonfinite", true)
	var guidance := _transit_guidance(ship, destination_world)
	var evaluation := _controller.evaluate_and_submit(
		destination_world,
		combat_active,
		expected_coordinate_frame_generation,
		_controller.get_generation(),
		guidance,
	)
	if not bool(evaluation.get("accepted", false)):
		return _fail_tick_guarded(
			StringName(evaluation.get("reason", &"controller_evaluation_rejected")),
			true,
			evaluation,
		)
	if evaluation.get("reason") in [
		&"final_approach_completed", &"return_approach_completed",
	]:
		return _complete_final_approach_guarded(evaluation, caller_tick)
	var policy := evaluation.get("policy", {}) as Dictionary
	var final_state := StringName(
		((_controller.get_snapshot().get("final_approach", {}) as Dictionary)
			.get("state_id", &"none"))
	)
	var standoff_braking := false
	if not bool(policy.get("desired_cruise_participation", false)) \
			and final_state not in [&"final_approach", &"return_approach"]:
		# On the outbound transit the long leg's brake-shell decision is the
		# planned standoff stop short of the anchor, flown attached: the
		# approach target arms behind the streamed moon and takes over from
		# there. Every other refusal still releases the craft to its pilot.
		# The stop arrives as `insufficient_verified_clearance` when the sweep is
		# capped at the destination distance, or as `destination_braking_envelope`
		# when it is not; both are the same brake-shell decision.
		standoff_braking = _transit_leg == TRANSIT_LEG_EMBER_OUTBOUND \
			and _final_approach_target_generation == 0 \
			and StringName(policy.get("reason", &"")) in [
				&"destination_braking_envelope", &"insufficient_verified_clearance",
			] \
			and bool(policy.get("braking_requested", false))
		if not standoff_braking:
			return _fail_tick_guarded(
				StringName(policy.get("reason", &"policy_disengaged")),
				true,
				evaluation,
			)
	_accepted_tick_count += 1
	_last_destination_world = destination_world
	_record_transit_progress(evaluation, policy, final_state, standoff_braking)
	_last_reason = &"transit_standoff_braking_submitted" if standoff_braking \
		else (&"return_approach_braking_envelope_submitted" \
		if final_state == &"return_approach" \
		else (&"final_approach_envelope_submitted" \
			if final_state == &"final_approach" \
			else &"next_ship_physics_envelope_submitted"))
	_last_result = _result(true, _last_reason, {
		"caller_tick": caller_tick,
		"coordinate_frame_generation": expected_coordinate_frame_generation,
		"ship_instance_id": _engaged_ship_instance_id,
		"destination_id": DESTINATION_ID,
		"destination_orbital": _canonical_destination_orbital.duplicate(true),
		"destination_world": destination_world,
		"controller": evaluation.duplicate(true),
	})
	_mutation_active = false
	_emit_tick_committed()
	return _last_result.duplicate(true)


func get_generation() -> int:
	return _generation


func get_controller() -> PlanetaryCruisePhysicalController:
	return _controller


## Announces one committed common-world origin rebase to a live engagement,
## before the caller tick that carries the exact target generation. Every
## frozen world-space transform this binding or its controller holds (the
## landing root drift snapshot, the return home target, the armed approach
## target) is re-expressed by the same delta the owner
## applied to the world; nothing here moves an actor or changes the frame.
func accept_committed_origin_rebase(
		receipt: Dictionary,
		expected_generation: int,
	) -> Dictionary:
	var preflight := _mutation_preflight(expected_generation)
	if not preflight.is_empty():
		return _result(false, preflight)
	if not _engagement_requested:
		return _result(false, &"not_engaged")
	if receipt.get("reason", &"") != &"rebase_committed" \
			or not receipt.get("source_generation") is int \
			or not receipt.get("target_generation") is int \
			or not receipt.get("world_translation_delta") is Vector3:
		return _result(false, &"origin_receipt_invalid")
	var source_generation := int(receipt.source_generation)
	var target_generation := int(receipt.target_generation)
	var delta := receipt.world_translation_delta as Vector3
	if not delta.is_finite():
		return _result(false, &"origin_translation_nonfinite")
	if source_generation != _bound_frame_generation \
			or target_generation != source_generation + 1:
		return _result(false, &"origin_receipt_generation_mismatch")
	if _translated_frame_generation == target_generation:
		return _result(true, &"origin_translation_already_accepted")
	_mutation_active = true
	if _final_approach_target_generation > 0 and _controller_is_valid():
		var translated := _controller.translate_approach_target(
			delta, _final_approach_target_generation, _controller.get_generation()
		)
		if not bool(translated.get("accepted", false)):
			_mutation_active = false
			return _result(false, StringName(
				translated.get("reason", &"approach_target_translation_rejected")
			))
	_final_approach_landing_root_transform.origin += delta
	_return_approach_home_target_transform.origin += delta
	_translated_frame_generation = target_generation
	_mutation_active = false
	return _result(true, &"origin_translation_accepted", {
		"target_generation": target_generation,
		"world_translation_delta": delta,
	})


func get_transit_progress() -> Dictionary:
	return _transit_progress.duplicate(true)


## The approach profile can bring the craft to rest from its current speed in
## this distance, plus the activation lead; an armed target inside it takes
## over from the long leg. A craft that is not participating in the long leg
## (at rest at the standoff, or braking) cannot engage the long leg inside its
## minimum engage distance, so the approach takes over there unconditionally.
static func _approach_activation_distance(
		speed: float, participating: bool
	) -> float:
	var stopping := speed * speed \
		/ (2.0 * _PolicyType.APPROACH_PROFILE_DECELERATION_METERS_PER_SECOND_SQUARED) \
		+ speed * _PolicyType.APPROACH_ACTIVATION_LEAD_SECONDS
	if participating:
		return stopping
	var target_envelope := _PolicyType.TARGET_CRUISE_SPEED_METERS_PER_SECOND \
		* _PolicyType.TARGET_CRUISE_SPEED_METERS_PER_SECOND \
		/ (2.0 * _PolicyType.BRAKING_HINT_METERS_PER_SECOND_SQUARED) \
		+ _PolicyType.TARGET_CRUISE_SPEED_METERS_PER_SECOND \
			* _PolicyType.BRAKE_RESPONSE_SECONDS \
		+ _PolicyType.BRAKE_FIXED_MARGIN_METERS
	var acceleration_distance := _PolicyType.TARGET_CRUISE_SPEED_METERS_PER_SECOND \
		* _PolicyType.TARGET_CRUISE_SPEED_METERS_PER_SECOND \
		/ (2.0 * _PolicyType.ACCELERATION_HINT_METERS_PER_SECOND_SQUARED)
	return maxf(stopping, target_envelope + acceleration_distance)


static func _heading_basis(direction: Vector3, current: Basis) -> Basis:
	if not direction.is_finite() or direction.is_zero_approx():
		return current.orthonormalized()
	var forward := direction.normalized()
	var up := current.y.normalized()
	if absf(forward.dot(up)) > 0.98:
		up = Vector3.UP if absf(forward.dot(Vector3.UP)) <= 0.98 else Vector3.RIGHT
	return Basis.looking_at(forward, up)


## One tick of transit guidance for the controller, from the leg this binding
## carries and the controller's current approach state. Legacy engagements (no
## leg) receive none and behave exactly as before.
func _transit_guidance(ship: HeroShip, destination_world: Vector3) -> Dictionary:
	if _transit_leg.is_empty():
		return {}
	var controller_snapshot := _safe_controller_snapshot()
	var approach := controller_snapshot.get("final_approach", {}) as Dictionary
	var state_id := StringName(approach.get("state_id", &"none"))
	var target := approach.get("target", {}) as Dictionary
	var ship_report := ship.get_planetary_cruise_attachment_report()
	var participating := StringName(ship_report.get("state", &"")) in [
		HeroShip.PLANETARY_CRUISE_STATE_ACCELERATING,
		HeroShip.PLANETARY_CRUISE_STATE_CRUISING,
		HeroShip.PLANETARY_CRUISE_STATE_BRAKING_TO_SPEED,
	]
	var speed := ship.velocity.length()
	var position := ship.global_position
	var guidance := {"attitude_authority": true}
	match _transit_leg:
		TRANSIT_LEG_EMBER_OUTBOUND:
			if state_id in [&"armed", &"final_approach"] and not target.is_empty():
				var entry := target.get("target_world_transform", Transform3D.IDENTITY) as Transform3D
				var distance := position.distance_to(entry.origin)
				if state_id == &"final_approach" or distance \
						<= _approach_activation_distance(speed, participating):
					guidance["approach_point_world"] = entry.origin
					guidance["approach_speed_limit_meters_per_second"] = (
						_PolicyType.APPROACH_SPEED_LIMIT_METERS_PER_SECOND
					)
					guidance["attitude_basis_world"] = entry.basis.orthonormalized()
					guidance["activate_approach"] = state_id == &"armed"
					return guidance
			guidance["attitude_basis_world"] = _heading_basis(
				destination_world - position, ship.global_basis
			)
			return guidance
	return {}


func _record_transit_progress(
		evaluation: Dictionary,
		policy: Dictionary,
		final_state: StringName,
		standoff_braking: bool,
	) -> void:
	if _transit_leg.is_empty():
		_transit_progress.clear()
		return
	var guidance := evaluation.get("guidance", {}) as Dictionary
	_transit_progress = {
		"leg": _transit_leg,
		"mode": &"approach" if guidance.has("approach_point_world") else &"cruise",
		"approach_state": final_state,
		"standoff_braking": standoff_braking,
		"policy_state": StringName(policy.get("state", &"")),
		"policy_reason": StringName(policy.get("reason", &"")),
		"distance_to_point_meters": float(
			evaluation.get("distance_to_destination_meters", 0.0)
		),
		"speed_meters_per_second": float(
			(policy.get("observation", {}) as Dictionary).get(
				"ship_speed_meters_per_second", 0.0
			)
		),
		"desired_speed_meters_per_second": float(
			policy.get("desired_speed_meters_per_second", 0.0)
		),
	}.duplicate(true)


func get_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"activated": _activated,
		"configuration_error": _configuration_error,
		"inside_tree": is_inside_tree(),
		"automatic_process": is_processing(),
		"automatic_physics_process": is_physics_processing(),
		"bootstrap_instance_id": _bootstrap_instance_id,
		"coordinate_frame_instance_id": _frame_instance_id,
		"controller_instance_id": _controller_instance_id,
		"generation": _generation,
		"engagement_requested": _engagement_requested,
		"engaged_ship_instance_id": _engaged_ship_instance_id,
		"bound_coordinate_frame_generation": _bound_frame_generation,
		"current_coordinate_frame_generation": (
			_frame.get_generation() if _frame != null else 0
		),
		"destination_id": DESTINATION_ID,
		"destination_source_id": DESTINATION_SOURCE_ID,
		"canonical_destination_orbital": (
			_canonical_destination_orbital.duplicate(true)
		),
		"last_destination_world": _last_destination_world,
		"last_caller_tick": _last_caller_tick,
		"accepted_tick_count": _accepted_tick_count,
		"rejected_tick_count": _rejected_tick_count,
		"rebind_count": _rebind_count,
		"retirement_count": _retirement_count,
		"reentrant_rejection_count": _reentrant_rejection_count,
		"last_reason": _last_reason,
		"last_result": _last_result.duplicate(true),
		"controller": _safe_controller_snapshot(),
		"final_approach": {
			"approach_kind": _approach_kind,
			"target_generation": _final_approach_target_generation,
			"location_generation": _final_approach_location_generation,
			"host_generation": _final_approach_host_generation,
			"host_attachment_generation": _final_approach_host_attachment_generation,
			"host_instance_id": _final_approach_host_instance_id,
			"landing_root_instance_id": _final_approach_landing_root_instance_id,
			"completion_count": _final_approach_completion_count,
			"completion_consumed": _final_approach_completion_consumed,
			"completion_receipt": _final_approach_completion_receipt.duplicate(true),
		}.duplicate(true),
		"transit": {
			"leg": _transit_leg,
			"progress": _transit_progress.duplicate(true),
			"translated_frame_generation": _translated_frame_generation,
		}.duplicate(true),
		"return_approach": {
			"active": _approach_kind == _ControllerType.RETURN_APPROACH_KIND,
			"target_generation": _final_approach_target_generation \
				if _approach_kind == _ControllerType.RETURN_APPROACH_KIND else 0,
			"home_target_world_transform": _return_approach_home_target_transform,
			"completion_count": _final_approach_completion_count,
			"completion_consumed": _final_approach_completion_consumed,
			"completion_receipt": _final_approach_completion_receipt.duplicate(true) \
				if _approach_kind == _ControllerType.RETURN_APPROACH_KIND else {},
		}.duplicate(true),
	}.duplicate(true)


func audit() -> Dictionary:
	var errors := PackedStringArray()
	var identity_reason := _identity_preflight()
	if not _activated:
		errors.append("production binding is not activated: %s" % _configuration_error)
	elif not identity_reason.is_empty():
		errors.append("bound identity invalid: %s" % identity_reason)
	if is_processing() or is_physics_processing():
		errors.append("production binding must remain caller-driven")
	var host := get_parent()
	var binding_count := 0
	var controller_count := 0
	if host != null:
		for candidate in host.find_children(
			"*", "PlanetaryCruiseProductionBinding", true, false
		):
			if candidate is PlanetaryCruiseProductionBinding:
				binding_count += 1
	for candidate in find_children(
		"*", "PlanetaryCruisePhysicalController", true, false
	):
		if candidate is PlanetaryCruisePhysicalController:
			controller_count += 1
	var controller_audit := _safe_controller_audit()
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": (
			errors.is_empty()
			and binding_count == 1
			and controller_count == 1
			and bool(controller_audit.get("valid", false))
		),
		"errors": errors,
		"binding_count": binding_count,
		"controller_count": controller_count,
		"snapshot": get_snapshot(),
		"destination_policy": &"canonical_absolute_ember_navigation_anchor_decode_each_current_generation",
		"physics_order_policy": &"gameflow_actor_then_ember_then_optional_rebase_then_cruise_then_hero",
		"command_delivery": &"one_fresh_envelope_for_next_hero_physics_tick",
		"controller_audit": controller_audit.duplicate(true),
		"common_authority": _zero_authority(),
		"adjacent_capabilities": {
			"engagement_request_lifecycle": true,
			"absolute_destination_decode": true,
			"controller_binding": true,
			"controller_cadence": true,
			"typed_final_approach_lifecycle": true,
			"typed_return_approach_lifecycle": true,
			"caller_supplied_return_target": true,
			"full_flyable_fleet_return_corridor_proof": true,
			"completion_receipt_relay": true,
			"input_sampling": false,
			"actor_sampling": false,
			"policy_implementation": false,
			"collision_query": false,
			"velocity_write": false,
			"move_and_slide": false,
			"transform_write": false,
			"teleport": false,
			"origin_rebase_request": false,
			"origin_rebase_commit": false,
			"streaming_request": false,
			"landing_decision": false,
			"combat_decision": false,
		}.duplicate(true),
	}.duplicate(true)


func _activate_scene_binding() -> void:
	if _activated or not is_inside_tree() or is_queued_for_deletion():
		return
	_bootstrap = get_node_or_null(bootstrap_path) as EmberMoonStreamingBootstrap
	if _bootstrap == null or _bootstrap.is_queued_for_deletion():
		_configuration_error = &"bootstrap_unavailable"
		return
	_frame = _bootstrap.get_coordinate_frame_for_session()
	if _frame == null or not _frame.is_configured():
		_configuration_error = &"coordinate_frame_unavailable"
		return
	if (
		_controller == null
		or not is_instance_valid(_controller)
		or _controller.is_queued_for_deletion()
		or _controller.get_parent() != self
	):
		_configuration_error = &"controller_unavailable"
		return
	if (
		_EMBER_LOCATION.location_id != EmberMoonStreamingBootstrap.LOCATION_ID
		or _EMBER_LOCATION.anchor_source_id != DESTINATION_SOURCE_ID
		or not _EMBER_LOCATION.anchor_position.is_finite()
		or not _EMBER_LOCATION.get_validation_errors().is_empty()
	):
		_configuration_error = &"ember_destination_contract_invalid"
		return
	var encoded := _frame.body_local_to_orbital_position(
		_EMBER_LOCATION.anchor_position,
		_frame.get_generation(),
	)
	if not bool(encoded.get("accepted", false)):
		_configuration_error = &"ember_destination_encoding_rejected"
		return
	_canonical_destination_orbital = (
		encoded.get("coordinate", {}) as Dictionary
	).duplicate(true)
	_bootstrap_instance_id = _bootstrap.get_instance_id()
	_frame_instance_id = _frame.get_instance_id()
	_controller_instance_id = _controller.get_instance_id()
	_configuration_error = &""
	_activated = true
	_last_reason = &"activated"


## Takes the one arrival measurement an active approach is owed when the ship
## retired its own cruise attachment on the tick its braking completed. Returns
## an empty dictionary when there is nothing to settle, so the caller falls
## through to its ordinary retirement. The public transaction guard is already
## held; the controller measures only the live ship transform and velocity and
## writes no actor state.
func _settle_retired_approach_arrival_guarded(caller_tick: int) -> Dictionary:
	if not _mutation_active or _final_approach_target_generation < 1:
		return {}
	var state_id := StringName(
		(_safe_controller_snapshot().get("final_approach", {}) as Dictionary)
			.get("state_id", &"none")
	)
	if state_id not in [&"final_approach", &"return_approach"]:
		return {}
	var settled := _controller.settle_arrival_on_retired_attachment(
		_controller.get_generation()
	)
	if not bool(settled.get("accepted", false)):
		return {}
	return _complete_final_approach_guarded(settled, caller_tick)


func _complete_final_approach_guarded(
		controller_evaluation: Dictionary,
		caller_tick: int,
	) -> Dictionary:
	if not _mutation_active:
		return _result(false, &"mutation_guard_required")
	var controller_receipt := controller_evaluation.get(
		"completion_receipt", {}
	) as Dictionary
	var return_approach := _approach_kind == _ControllerType.RETURN_APPROACH_KIND
	var expected_target_id := _ControllerType.RETURN_APPROACH_TARGET_ID \
		if return_approach else _ControllerType.FINAL_APPROACH_TARGET_ID
	if not bool(controller_receipt.get("accepted", false)) \
			or controller_receipt.get("target_id", &"") != expected_target_id \
			or int(controller_receipt.get("target_generation", 0)) \
				!= _final_approach_target_generation:
		return _fail_tick_guarded(
			&"return_approach_completion_invalid" if return_approach \
				else &"final_approach_completion_invalid",
			true,
		)
	if _generation >= MAX_SAFE_INTEGER:
		return _fail_tick_guarded(&"generation_exhausted", true)
	var release := _release_controller(false)
	if not bool(release.get("accepted", false)):
		return _fail_tick_guarded(&"controller_release_rejected", false, release)
	var released_ship := _resolve_engaged_ship_even_if_detached()
	var released_ship_report := released_ship.get_planetary_cruise_attachment_report() \
		if released_ship != null else {}
	if released_ship == null \
			or int(released_ship_report.get("controller_instance_id", -1)) != 0:
		return _fail_tick_guarded(
			&"return_approach_ship_release_unconfirmed" if return_approach \
				else &"final_approach_ship_release_unconfirmed",
			false,
			released_ship_report
		)
	_engagement_requested = false
	_engaged_ship_ref = null
	_engaged_ship_instance_id = 0
	_bound_frame_generation = 0
	_transit_leg = &""
	_transit_progress.clear()
	_translated_frame_generation = 0
	_retirement_count += 1
	_final_approach_completion_count += 1
	_generation = _next_generation(_generation)
	var handoff_reason: StringName = &"return_approach_handoff_ready" \
		if return_approach else &"final_approach_handoff_ready"
	_final_approach_completion_receipt = {
		"accepted": true,
		"reason": handoff_reason,
		"schema_version": SCHEMA_VERSION,
		"generation": _generation,
		"target_generation": _final_approach_target_generation,
		"coordinate_frame_generation": int(
			controller_receipt.get("coordinate_frame_generation", 0)
		),
		"ship_instance_id": int(controller_receipt.get("ship_instance_id", 0)),
		"released_ship_attachment_generation": int(
			released_ship_report.get("ship_attachment_generation", 0)
		),
		"caller_tick": caller_tick,
		"controller_completion": controller_receipt.duplicate(true),
		"controller_release": release.duplicate(true),
	}.duplicate(true)
	if return_approach:
		_final_approach_completion_receipt["home_target_id"] = (
			(controller_receipt.get("target", {}) as Dictionary)
				.get("home_target_id", &"")
		)
	else:
		_final_approach_completion_receipt["location_generation"] = (
			_final_approach_location_generation
		)
		_final_approach_completion_receipt["host_generation"] = (
			_final_approach_host_generation
		)
		_final_approach_completion_receipt["host_attachment_generation"] = (
			_final_approach_host_attachment_generation
		)
		_final_approach_completion_receipt["host_instance_id"] = (
			_final_approach_host_instance_id
		)
	_final_approach_completion_receipt = (
		_final_approach_completion_receipt.duplicate(true)
	)
	_final_approach_completion_consumed = false
	_last_reason = handoff_reason
	_last_result = _final_approach_completion_receipt.duplicate(true)
	_mutation_active = false
	_emit_engagement_changed()
	if return_approach:
		_emit_return_approach_completed()
	else:
		_emit_final_approach_completed()
	return _last_result.duplicate(true)


func _validate_final_approach_envelope(envelope: Dictionary) -> StringName:
	for key in [
		"corridor_id", "target_pad_id",
		"corridor_transform_region_local_m", "corridor_half_extents_m",
		"entry_position_half_extents_m", "maximum_speed_mps",
		"maximum_attitude_degrees", "hull_margin_m", "collision_bounds",
	]:
		if not envelope.has(key):
			return &"final_approach_envelope_schema_mismatch"
	if not envelope.corridor_id is StringName \
			or not envelope.target_pad_id is StringName \
			or not envelope.corridor_transform_region_local_m is Transform3D \
			or not envelope.corridor_half_extents_m is Vector3 \
			or not envelope.entry_position_half_extents_m is Vector3 \
			or not envelope.maximum_speed_mps is float \
			or not envelope.maximum_attitude_degrees is float \
			or not envelope.hull_margin_m is float \
			or not envelope.collision_bounds is AABB:
		return &"final_approach_envelope_type_mismatch"
	return &""


func _validate_return_approach_target(target: Dictionary) -> StringName:
	for key in [
		"home_target_id", "home_target_world_transform",
		"corridor_half_extents_m", "brake_shell_min_distance_m",
		"brake_shell_max_distance_m", "maximum_speed_mps",
		"maximum_attitude_degrees", "hull_margin_m",
		"fleet_collision_bounds",
	]:
		if not target.has(key):
			return &"return_approach_target_schema_mismatch"
	if not target.home_target_id is StringName \
			or not target.home_target_world_transform is Transform3D \
			or not target.corridor_half_extents_m is Vector3 \
			or not target.brake_shell_min_distance_m is float \
			or not target.brake_shell_max_distance_m is float \
			or not target.maximum_speed_mps is float \
			or not target.maximum_attitude_degrees is float \
			or not target.hull_margin_m is float \
			or not target.fleet_collision_bounds is Dictionary:
		return &"return_approach_target_type_mismatch"
	return &""


func _final_approach_source_rejection() -> StringName:
	if _final_approach_host_ref == null:
		return &"final_approach_host_lost"
	var host_candidate: Variant = _final_approach_host_ref.get_ref()
	if not host_candidate is EmberSurfaceLoopHost \
			or not is_instance_valid(host_candidate) \
			or (host_candidate as EmberSurfaceLoopHost).is_queued_for_deletion() \
			or not (host_candidate as EmberSurfaceLoopHost).is_inside_tree() \
			or (host_candidate as EmberSurfaceLoopHost).get_instance_id() \
				!= _final_approach_host_instance_id:
		return &"final_approach_host_lost"
	var host_snapshot := (host_candidate as EmberSurfaceLoopHost).get_snapshot()
	if not bool(host_snapshot.get("attached", false)) \
			or int(host_snapshot.get("phase", -1)) != EmberSurfaceLoopHost.Phase.IDLE \
			or int(host_snapshot.get("generation", -1)) \
				!= _final_approach_host_generation \
			or int(host_snapshot.get("attachment_generation", -1)) \
				!= _final_approach_host_attachment_generation \
			or int(host_snapshot.get("coordinate_frame_generation", -1)) \
				!= _bound_frame_generation \
			or int(host_snapshot.get("location_generation", -1)) \
				!= _final_approach_location_generation:
		return &"final_approach_host_generation_drift"
	if _final_approach_landing_root_ref == null:
		return &"final_approach_landing_root_lost"
	var candidate: Variant = _final_approach_landing_root_ref.get_ref()
	if not candidate is Node3D \
			or not is_instance_valid(candidate) \
			or (candidate as Node3D).is_queued_for_deletion() \
			or not (candidate as Node3D).is_inside_tree() \
			or (candidate as Node3D).get_instance_id() \
				!= _final_approach_landing_root_instance_id:
		return &"final_approach_landing_root_lost"
	if not (candidate as Node3D).global_transform.is_equal_approx(
		_final_approach_landing_root_transform
	):
		return &"final_approach_landing_root_transform_drift"
	return &""


func _ensure_current_frame_binding(
		ship: HeroShip,
		expected_coordinate_frame_generation: int,
	) -> Dictionary:
	var controller_snapshot := _controller.get_snapshot()
	if expected_coordinate_frame_generation == _bound_frame_generation:
		if (
			bool(controller_snapshot.get("attached", false))
			and int(controller_snapshot.get("ship_instance_id", 0))
				== _engaged_ship_instance_id
			and int(controller_snapshot.get("coordinate_frame_generation", 0))
				== _bound_frame_generation
		):
			var ship_report := ship.get_planetary_cruise_attachment_report()
			if (
				int(ship_report.get("controller_instance_id", 0))
					== _controller_instance_id
				and int(ship_report.get("ship_attachment_generation", 0))
					== int(controller_snapshot.get("ship_attachment_generation", -1))
			):
				return {"accepted": true, "reason": &"binding_current"}
			# Reconciliation clears the controller's approach target, so the
			# caller is given the chance to settle an already physical arrival
			# first. `_settle_retired_approach_arrival_guarded()` reconciles when
			# there is nothing to settle.
			return {
				"accepted": false,
				"reason": &"ship_attachment_retired",
				"reconcile_pending": true,
			}
		return {"accepted": false, "reason": &"ship_attachment_retired"}
	if expected_coordinate_frame_generation != _bound_frame_generation + 1:
		return {"accepted": false, "reason": &"coordinate_frame_generation_jump"}
	# A committed rebase is a coordinate change, not a disengage: the attached
	# controller and its armed target are carried into the new frame with the
	# hull's cruise state intact, so an 8,000 km leg crosses its eight hundred
	# 10 km rebases without ever losing participation. Only when the ship cannot
	# be carried (no live attachment to retarget) does the historical
	# release-and-rebind run, which starts the long leg's engagement afresh.
	if bool(controller_snapshot.get("attached", false)):
		var carried := _controller.rebind_coordinate_frame(
			ship, expected_coordinate_frame_generation, _controller.get_generation()
		)
		if bool(carried.get("accepted", false)):
			_bound_frame_generation = expected_coordinate_frame_generation
			_rebind_count += 1
			return {"accepted": true, "reason": &"frame_carried"}
	var release := _release_controller(false)
	if not bool(release.get("accepted", false)):
		return release
	var bind := _controller.bind_ship(
		ship,
		expected_coordinate_frame_generation,
		_controller.get_generation(),
	)
	if not bool(bind.get("accepted", false)):
		return bind
	_bound_frame_generation = expected_coordinate_frame_generation
	_rebind_count += 1
	return {"accepted": true, "reason": &"frame_rebound"}


## Internal atomic retirement. The public transaction guard must already be
## held. State and generation commit only after the controller is proven
## detached/reconciled; a rejected release preserves the complete binding.
func _retire_engagement_guarded(
		reason: StringName,
		brake_to_stop: bool,
	) -> Dictionary:
	if not _mutation_active:
		return _result(false, &"mutation_guard_required")
	if _generation >= MAX_SAFE_INTEGER:
		return _result(false, &"generation_exhausted")
	if _controller_is_valid() and _final_approach_target_generation > 0:
		var final_state := StringName(
			((_controller.get_snapshot().get("final_approach", {}) as Dictionary)
				.get("state_id", &"none"))
		)
		if final_state in [&"armed", &"final_approach", &"return_approach"]:
			if _approach_kind == _ControllerType.RETURN_APPROACH_KIND:
				_controller.abort_return_approach(
					reason, _final_approach_target_generation,
					_controller.get_generation()
				)
			else:
				_controller.abort_final_approach(
					reason, _final_approach_target_generation,
					_controller.get_generation()
				)
	var release := _release_controller(brake_to_stop)
	if not bool(release.get("accepted", false)):
		return _result(false, &"controller_release_rejected", {
			"requested_reason": reason,
			"controller_release": release.duplicate(true),
		})
	_engagement_requested = false
	_engaged_ship_ref = null
	_engaged_ship_instance_id = 0
	_bound_frame_generation = 0
	_final_approach_landing_root_ref = null
	_final_approach_landing_root_instance_id = 0
	_final_approach_landing_root_transform = Transform3D.IDENTITY
	_final_approach_location_generation = 0
	_final_approach_host_generation = -1
	_final_approach_host_attachment_generation = 0
	_final_approach_host_ref = null
	_final_approach_host_instance_id = 0
	_final_approach_target_generation = 0
	_approach_kind = &""
	_return_approach_home_target_transform = Transform3D.IDENTITY
	_transit_leg = &""
	_transit_progress.clear()
	_translated_frame_generation = 0
	_retirement_count += 1
	_last_reason = reason
	_generation = _next_generation(_generation)
	_last_result = _result(true, reason, {
		"controller_release": release.duplicate(true),
	})
	return _last_result.duplicate(true)


func _release_controller(brake_to_stop: bool) -> Dictionary:
	if not _controller_is_valid():
		var ship := _resolve_engaged_ship_even_if_detached()
		if ship != null:
			var ship_report := ship.get_planetary_cruise_attachment_report()
			if int(ship_report.get("controller_instance_id", 0)) \
				== _controller_instance_id:
				return {
					"accepted": false,
					"reason": &"controller_lost_with_live_ship_attachment",
				}.duplicate(true)
		return {
			"accepted": true,
			"reason": &"controller_loss_reconciled",
		}.duplicate(true)
	var snapshot := _controller.get_snapshot()
	if not bool(snapshot.get("attached", false)):
		return {"accepted": true, "reason": &"controller_already_detached"}
	var controller_generation := _controller.get_generation()
	var release := _controller.disengage(controller_generation, brake_to_stop)
	if bool(release.get("accepted", false)):
		return release.duplicate(true)
	var reconcile := _controller.reconcile_retired_ship_binding(
		controller_generation
	)
	if bool(reconcile.get("accepted", false)):
		return reconcile.duplicate(true)
	return {
		"accepted": false,
		"reason": &"controller_release_rejected",
		"disengage": release.duplicate(true),
		"reconcile": reconcile.duplicate(true),
	}.duplicate(true)


## Completes a rejected public tick while its transaction guard is held. If
## retirement succeeds, engagement_changed is emitted only after unlocking. A
## failed release leaves ownership intact and emits only the rejected tick.
func _fail_tick_guarded(
		reason: StringName,
		retire: bool,
		evidence: Dictionary = {},
	) -> Dictionary:
	_rejected_tick_count += 1
	var engagement_changed_now := false
	if retire and _engagement_requested:
		var retired := _retire_engagement_guarded(reason, true)
		if bool(retired.get("accepted", false)):
			engagement_changed_now = true
			retired["accepted"] = false
			retired["evidence"] = evidence.duplicate(true)
			_last_result = retired.duplicate(true)
		else:
			_last_reason = reason
			_last_result = _result(false, reason, {
				"evidence": evidence.duplicate(true),
				"retirement": retired.duplicate(true),
			})
	else:
		_last_reason = reason
		_last_result = _result(false, reason, {
			"evidence": evidence.duplicate(true),
		})
	_mutation_active = false
	if engagement_changed_now:
		_emit_engagement_changed()
	else:
		_emit_tick_committed()
	return _last_result.duplicate(true)


func _mutation_preflight(expected_generation: int) -> StringName:
	if _mutation_active or _signal_dispatch_active:
		_reentrant_rejection_count += 1
		return &"reentrant_call"
	if expected_generation != _generation:
		return &"generation_mismatch"
	if not _binding_is_live():
		return &"binding_unavailable"
	return &""


func _identity_preflight() -> StringName:
	if not _activated:
		return _configuration_error if not _configuration_error.is_empty() else &"not_activated"
	if (
		_bootstrap == null
		or not is_instance_valid(_bootstrap)
		or _bootstrap.is_queued_for_deletion()
		or _bootstrap.get_instance_id() != _bootstrap_instance_id
		or _bootstrap.get_parent() != get_parent()
	):
		return &"bootstrap_identity_drift"
	if (
		_frame == null
		or _frame.get_instance_id() != _frame_instance_id
		or _bootstrap.get_coordinate_frame_for_session() != _frame
	):
		return &"coordinate_frame_identity_drift"
	if not _controller_is_valid():
		return &"controller_identity_drift"
	if _canonical_destination_orbital.is_empty():
		return &"canonical_destination_unavailable"
	return &""


func _validate_sample(sample: Variant, ship: HeroShip) -> StringName:
	if not sample is Dictionary:
		return &"actor_sample_not_dictionary"
	var value := sample as Dictionary
	if not _has_exact_string_keys(value, _SAMPLE_KEYS):
		return &"actor_sample_schema_mismatch"
	if not value.available is bool or not bool(value.available):
		return &"actor_unavailable"
	if not value.actor_kind is StringName or value.actor_kind != &"ship":
		return &"actor_not_ship"
	if not value.actor_instance_id is int \
		or int(value.actor_instance_id) != ship.get_instance_id():
		return &"actor_ship_identity_mismatch"
	if not value.position is Vector3 or not (value.position as Vector3).is_finite():
		return &"actor_position_invalid"
	return &""


func _validate_live_ship(ship: HeroShip) -> StringName:
	if (
		ship == null
		or not is_instance_valid(ship)
		or ship.is_queued_for_deletion()
		or not ship.is_inside_tree()
	):
		return &"ship_unavailable"
	if ship.is_destroyed():
		return &"ship_destroyed"
	if not ship.is_piloted():
		return &"pilot_unseated"
	if ship.is_landing_active():
		return &"landing_active"
	return &""


func _validate_engaged_ship(ship: HeroShip) -> StringName:
	var live_reason := _validate_live_ship(ship)
	if not live_reason.is_empty():
		return live_reason
	if ship.get_instance_id() != _engaged_ship_instance_id:
		return &"active_ship_replaced"
	if _engaged_ship_ref == null or _engaged_ship_ref.get_ref() != ship:
		return &"engaged_ship_identity_drift"
	return &""


func _controller_is_valid() -> bool:
	return (
		_controller != null
		and is_instance_valid(_controller)
		and not _controller.is_queued_for_deletion()
		and _controller.get_instance_id() == _controller_instance_id
		and _controller.get_parent() == self
		and _controller.is_inside_tree()
	)


func _resolve_engaged_ship_even_if_detached() -> HeroShip:
	if _engaged_ship_ref == null:
		return null
	var candidate: Variant = _engaged_ship_ref.get_ref()
	if (
		not candidate is HeroShip
		or not is_instance_valid(candidate)
		or (candidate as HeroShip).get_instance_id() != _engaged_ship_instance_id
	):
		return null
	return candidate as HeroShip


func _safe_controller_snapshot() -> Dictionary:
	if not _controller_is_valid():
		return {
			"available": false,
			"reason": &"controller_identity_drift",
			"expected_controller_instance_id": _controller_instance_id,
		}.duplicate(true)
	var snapshot := _controller.get_snapshot().duplicate(true)
	snapshot["available"] = true
	return snapshot


func _safe_controller_audit() -> Dictionary:
	if not _controller_is_valid():
		return {
			"valid": false,
			"reason": &"controller_identity_drift",
		}.duplicate(true)
	return _controller.audit().duplicate(true)


func _binding_is_live() -> bool:
	return (
		_activated
		and is_inside_tree()
		and not is_queued_for_deletion()
		and get_parent() != null
		and not get_parent().is_queued_for_deletion()
	)


func _emit_engagement_changed() -> void:
	if _signal_dispatch_active:
		return
	_signal_dispatch_active = true
	engagement_changed.emit(get_snapshot().duplicate(true))
	_signal_dispatch_active = false


func _emit_tick_committed() -> void:
	if _signal_dispatch_active:
		return
	_signal_dispatch_active = true
	tick_committed.emit(_last_result.duplicate(true))
	_signal_dispatch_active = false


func _emit_final_approach_completed() -> void:
	if _signal_dispatch_active:
		return
	_signal_dispatch_active = true
	final_approach_completed.emit(_final_approach_completion_receipt.duplicate(true))
	_signal_dispatch_active = false


func _emit_return_approach_completed() -> void:
	if _signal_dispatch_active:
		return
	_signal_dispatch_active = true
	return_approach_completed.emit(
		_final_approach_completion_receipt.duplicate(true)
	)
	_signal_dispatch_active = false


func _result(
		accepted: bool,
		reason: StringName,
		extra: Dictionary = {},
	) -> Dictionary:
	var result := {
		"accepted": accepted,
		"reason": reason,
		"schema_version": SCHEMA_VERSION,
		"generation": _generation,
		"engagement_requested": _engagement_requested,
		"ship_instance_id": _engaged_ship_instance_id,
		"coordinate_frame_generation": _bound_frame_generation,
	}
	for key: Variant in extra:
		result[key] = extra[key]
	return result.duplicate(true)


static func _next_generation(current: int) -> int:
	return current + 1


static func _has_exact_string_keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for key: Variant in value:
		if not key is String or not expected.has(key):
			return false
	return true


static func _zero_authority() -> Dictionary:
	var result := {}
	for key in _COMMON_AUTHORITY_KEYS:
		result[key] = false
	return result.duplicate(true)
