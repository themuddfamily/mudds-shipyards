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

const SCHEMA_VERSION := 1
const MAX_SAFE_INTEGER := 9_007_199_254_740_991
const DEFAULT_BOOTSTRAP_PATH := NodePath("../EmberMoonStreamingBootstrap")
const DESTINATION_ID: StringName = &"ember_navigation"
const DESTINATION_SOURCE_ID: StringName = &"ember_navigation_body_local"
const DESTINATION_RESOURCE_PATH := "res://assets/world/locations/ember_moon.tres"
const _ControllerType := preload(
	"res://scripts/control/planetary_cruise_physical_controller.gd"
)
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
	set_process(false)
	set_physics_process(false)


## Starts one explicit Ember-navigation cruise request. This records desired
## participation only after the exact live ship and current frame are bound.
## Policy and movement do not begin until the next accepted caller tick.
func request_engage(
		ship: HeroShip,
		expected_coordinate_frame_generation: int,
		production_gate_reason: StringName,
		expected_generation: int,
	) -> Dictionary:
	var preflight := _mutation_preflight(expected_generation)
	if not preflight.is_empty():
		return _result(false, preflight)
	if _engagement_requested:
		return _result(false, &"already_engaged")
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
	if expected_coordinate_frame_generation != _frame.get_generation():
		return _fail_tick_guarded(&"coordinate_frame_generation_mismatch", true)
	var frame_binding := _ensure_current_frame_binding(
		ship, expected_coordinate_frame_generation
	)
	if not bool(frame_binding.get("accepted", false)):
		return _fail_tick_guarded(
			StringName(frame_binding.get("reason", &"frame_rebind_rejected")),
			true,
		)
	var destination := _frame.orbital_to_world_streaming_position(
		_canonical_destination_orbital,
		expected_coordinate_frame_generation,
	)
	if not bool(destination.get("accepted", false)):
		return _fail_tick_guarded(
			StringName(destination.get("reason", &"destination_decode_rejected")),
			true,
		)
	var destination_world := destination.get("position", Vector3.INF) as Vector3
	if not destination_world.is_finite():
		return _fail_tick_guarded(&"destination_nonfinite", true)
	var evaluation := _controller.evaluate_and_submit(
		destination_world,
		combat_active,
		expected_coordinate_frame_generation,
		_controller.get_generation(),
	)
	if not bool(evaluation.get("accepted", false)):
		return _fail_tick_guarded(
			StringName(evaluation.get("reason", &"controller_evaluation_rejected")),
			true,
			evaluation,
		)
	var policy := evaluation.get("policy", {}) as Dictionary
	if not bool(policy.get("desired_cruise_participation", false)):
		return _fail_tick_guarded(
			StringName(policy.get("reason", &"policy_disengaged")),
			true,
			evaluation,
		)
	_accepted_tick_count += 1
	_last_destination_world = destination_world
	_last_reason = &"next_ship_physics_envelope_submitted"
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
			_controller.reconcile_retired_ship_binding(_controller.get_generation())
		return {"accepted": false, "reason": &"ship_attachment_retired"}
	if expected_coordinate_frame_generation != _bound_frame_generation + 1:
		return {"accepted": false, "reason": &"coordinate_frame_generation_jump"}
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
