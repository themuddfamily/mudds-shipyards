class_name CinderStreamingProductionBinding
extends Node

## Production-only physics driver for [CinderStreamingBootstrap].
##
## Main owns this one binding. Standalone composition injects one callable
## position provider during deferred activation; production Main instead selects
## caller-sample mode before activation so streaming and an activity can consume
## the exact same actor read. This node never chooses a destination, moves an
## actor, starts an activity, grants a reward, or mutates combat/save/network
## state. A missing/invalid actor clears tracking and still advances the existing
## policy exactly once, whose documented no-tracking behavior preserves loaded
## and loading state.

const SCHEMA_VERSION := 1
const DEFAULT_BOOTSTRAP_PATH := NodePath("../CinderStreamingBootstrap")
const DEFAULT_PLAYER_PATH := NodePath("../Player")
const UNLOAD_HOLD_DISTANCE_METERS := 649.5

@export var bootstrap_path: NodePath = DEFAULT_BOOTSTRAP_PATH
@export var player_path: NodePath = DEFAULT_PLAYER_PATH

var _bootstrap: CinderStreamingBootstrap
var _position_provider := Callable()
var _caller_sample_mode := false
var _activated := false
var _configuration_error: StringName = &""
var _tick_active := false
var _provider_generation := 0
var _provider_sample_count := 0
var _caller_sample_count := 0
var _available_sample_count := 0
var _unavailable_sample_count := 0
var _invalid_sample_count := 0
var _physics_tick_count := 0
var _invalid_delta_count := 0
var _reentrant_rejection_count := 0
var _provider_mutation_rejection_count := 0
var _quality_sync_count := 0
var _quality_synced_instance_id := 0
var _deferred_quality_sync_pending := false
var _deferred_quality_sync_generation := 0
var _tree_generation := 0
var _presentation_advance_count := 0
var _presentation_rejection_count := 0
var _presentation_unload_hold_count := 0
var _last_presentation_result: Dictionary = {}
var _initial_policy_update_index := 0
var _last_actor_kind: StringName = &""
var _last_actor_instance_id := 0
var _last_position := Vector3.ZERO
var _last_sample_reason: StringName = &"not_sampled"
var _last_tick_result: Dictionary = {}


func _enter_tree() -> void:
	if _activated:
		set_physics_process(not _caller_sample_mode)
		if _deferred_quality_sync_pending:
			# A deferred completion from the prior tree lifetime is deliberately
			# stale. Requeue this retained work for the current attachment instead.
			_deferred_quality_sync_pending = false
			_queue_deferred_presentation_sync()


func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	# Children ready before Main. Deferring the injection lets both synchronous
	# and staged startup finish GameFlow's ordinary binding/startup tail first.
	call_deferred(&"_activate_scene_binding")


func _exit_tree() -> void:
	_tree_generation += 1
	# The bootstrap and its loaded child remain intact inside the detached Main.
	# Only automatic sampling pauses until this same binding re-enters.
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	_drive_physics_tick(delta)


## Selects the production composition in which a parent supplies the one actor
## sample already captured for its physics tick. Configuration is deliberately
## pre-activation only, so automatic and caller-driven cadence can never overlap.
func configure_caller_sample_mode() -> bool:
	if _tick_active or _activated or _position_provider.is_valid():
		_provider_mutation_rejection_count += 1
		return false
	_caller_sample_mode = true
	set_physics_process(false)
	return true


## Advances streaming from a detached actor sample captured by the production
## parent. The Dictionary uses the same validated shape as the injected provider
## seam; this method never reads an actor or chooses between ship and player.
func physics_tick_from_caller_sample(delta: float, sample: Variant) -> Dictionary:
	if not _caller_sample_mode:
		return {"accepted": false, "reason": &"caller_sample_mode_not_configured"}
	return _drive_physics_tick(delta, sample, true)


## Explicit provider injection seam. A provider returns a detached Dictionary:
##
##     {"available": true, "position": Vector3, "actor_kind": StringName,
##      "actor_instance_id": int}
##
## or `{ "available": false, "reason": StringName }`. Main installs the
## provider once during activation; later replacement and tick-time mutation are
## rejected so the production actor source cannot drift.
func set_position_provider(provider: Callable) -> bool:
	if _tick_active or _activated or _caller_sample_mode:
		_provider_mutation_rejection_count += 1
	if _tick_active:
		_reentrant_rejection_count += 1
	if _tick_active or _activated or _caller_sample_mode:
		return false
	if not provider.is_valid():
		return false
	_position_provider = provider
	_provider_generation += 1
	return true


## Detached production state; no Node, Resource, Callable, or mutable internal
## collection crosses the public boundary.
func get_snapshot() -> Dictionary:
	var bootstrap_snapshot := {}
	var policy_update_index := -1
	if is_instance_valid(_bootstrap):
		bootstrap_snapshot = _bootstrap.get_snapshot()
		var policy_snapshot := bootstrap_snapshot.get("distance_policy", {}) as Dictionary
		policy_update_index = int(policy_snapshot.get("update_index", -1))
	return {
		"schema_version": SCHEMA_VERSION,
		"activated": _activated,
		"configuration_error": _configuration_error,
		"inside_tree": is_inside_tree(),
		"physics_processing": is_physics_processing(),
		"bootstrap_instance_id": _bootstrap.get_instance_id() \
			if is_instance_valid(_bootstrap) else 0,
		"provider_bound": _position_provider.is_valid(),
		"provider_generation": _provider_generation,
		"provider_sample_count": _provider_sample_count,
		"caller_sample_mode": _caller_sample_mode,
		"caller_sample_count": _caller_sample_count,
		"available_sample_count": _available_sample_count,
		"unavailable_sample_count": _unavailable_sample_count,
		"invalid_sample_count": _invalid_sample_count,
		"physics_tick_count": _physics_tick_count,
		"invalid_delta_count": _invalid_delta_count,
		"reentrant_rejection_count": _reentrant_rejection_count,
		"provider_mutation_rejection_count": _provider_mutation_rejection_count,
		"quality_sync_count": _quality_sync_count,
		"quality_synced_instance_id": _quality_synced_instance_id,
		"deferred_quality_sync_pending": _deferred_quality_sync_pending,
		"deferred_quality_sync_generation": _deferred_quality_sync_generation,
		"tree_generation": _tree_generation,
		"presentation_advance_count": _presentation_advance_count,
		"presentation_rejection_count": _presentation_rejection_count,
		"presentation_unload_hold_count": _presentation_unload_hold_count,
		"last_presentation_result": _last_presentation_result.duplicate(true),
		"presentation_unload_hold_distance_meters": UNLOAD_HOLD_DISTANCE_METERS,
		"initial_policy_update_index": _initial_policy_update_index,
		"policy_update_index": policy_update_index,
		"last_actor_kind": _last_actor_kind,
		"last_actor_instance_id": _last_actor_instance_id,
		"last_position": _last_position,
		"last_sample_reason": _last_sample_reason,
		"last_tick_result": _last_tick_result.duplicate(true),
		"bootstrap": bootstrap_snapshot,
	}.duplicate(true)


func audit() -> Dictionary:
	var errors := PackedStringArray()
	var host := get_parent()
	var bootstrap_count := 0
	var binding_count := 0
	var coordinator_count := 0
	var policy_count := 0
	var expected_coordinator := (
		_bootstrap.get_node_or_null(^"WorldStreamingCoordinator")
		if is_instance_valid(_bootstrap)
		else null
	)
	var expected_policy := (
		_bootstrap.get_node_or_null(^"WorldStreamingDistancePolicy")
		if is_instance_valid(_bootstrap)
		else null
	)
	if host != null:
		for candidate in host.find_children("*", "", true, false):
			if candidate is CinderStreamingBootstrap:
				bootstrap_count += 1
			elif candidate is CinderStreamingProductionBinding:
				binding_count += 1
			elif candidate is WorldStreamingCoordinator \
					and candidate == expected_coordinator:
				coordinator_count += 1
			elif candidate is WorldStreamingDistancePolicy \
					and candidate == expected_policy:
				policy_count += 1
	if not _activated:
		errors.append("production streaming binding is not activated: %s" % _configuration_error)
	if not is_instance_valid(_bootstrap) or _bootstrap.get_parent() != host:
		errors.append("one sibling Cinder streaming bootstrap is required")
	elif not bool(_bootstrap.audit().get("valid", false)):
		errors.append("Cinder streaming bootstrap audit is invalid")
	if _caller_sample_mode:
		if _position_provider.is_valid() or _provider_generation != 0:
			errors.append("caller-sampled mode cannot retain an actor provider")
		if _caller_sample_count != _provider_sample_count:
			errors.append("every caller-sampled tick must consume exactly one caller sample")
	else:
		if not _position_provider.is_valid() or _provider_generation != 1:
			errors.append("exactly one production actor provider must be injected")
	if (
		bootstrap_count != 1
		or binding_count != 1
		or coordinator_count != 1
		or policy_count != 1
	):
		errors.append("Main must contain exactly one Cinder binding, bootstrap-owned coordinator, and policy")
	var snapshot := get_snapshot()
	if (
		int(snapshot.get("policy_update_index", -1))
		!= _initial_policy_update_index + _physics_tick_count
	):
		errors.append("distance policy update count differs from the single physics driver")
	if _provider_sample_count != _available_sample_count + _unavailable_sample_count:
		errors.append("provider sample counters are inconsistent")
	if _invalid_sample_count > _unavailable_sample_count:
		errors.append("invalid provider sample counters are inconsistent")
	var loaded_cluster := _bootstrap.get_loaded_instance() as NearbySectorCluster \
		if is_instance_valid(_bootstrap) else null
	if (
		is_instance_valid(loaded_cluster)
		and _quality_synced_instance_id != loaded_cluster.get_instance_id()
	):
		errors.append("loaded Cinder generation has not received the retained visual quality")
	if is_instance_valid(loaded_cluster) \
		and not bool(loaded_cluster.get_streaming_transition_audit().get("valid", false)):
		errors.append("loaded Cinder transition presentation audit is invalid")
	if _presentation_rejection_count > 0:
		errors.append("production transition presentation rejected an internal advance")
	if is_processing():
		errors.append("binding must never own an idle process loop")
	if (
		is_inside_tree()
		and _activated
		and is_physics_processing() == _caller_sample_mode
	):
		errors.append("binding physics processing does not match its configured cadence")
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"snapshot": snapshot,
		"binding_count": binding_count,
		"bootstrap_count": bootstrap_count,
		"coordinator_count": coordinator_count,
		"distance_policy_count": policy_count,
		"position_provider_policy": (
			&"caller_supplied_piloted_active_ship_else_live_player"
			if _caller_sample_mode
			else &"piloted_active_ship_else_live_player"
		),
		"missing_actor_policy": &"clear_tracking_tick_once_preserve_streaming_state",
		"update_authority": (
			&"one_physics_tick_from_caller_sample"
			if _caller_sample_mode
			else &"one_physics_tick_from_injected_provider"
		),
		"automatic_idle_processing": false,
		"activity_authority": false,
		"gameplay_authority": false,
		"combat_authority": false,
		"reward_authority": false,
		"ship_authority": false,
		"berth_authority": false,
		"save_authority": false,
		"network_authority": false,
		"runtime_settings_authority": false,
		"presentation_profile_authority": false,
		"presentation_profile_policy": &"forward_shipyard_quality_and_torus_budget_once_per_loaded_generation",
		"streaming_transition_policy": &"caller_physics_fade_then_confirmed_outside_retirement",
		"streaming_threshold_mutation": false,
		"staged_startup_authority": false,
	}.duplicate(true)


func _activate_scene_binding() -> void:
	if _activated or is_queued_for_deletion() or not is_inside_tree():
		return
	_bootstrap = get_node_or_null(bootstrap_path) as CinderStreamingBootstrap
	if not is_instance_valid(_bootstrap):
		_configuration_error = &"missing_cinder_streaming_bootstrap"
		return
	if not bool(_bootstrap.audit().get("valid", false)):
		_configuration_error = &"invalid_cinder_streaming_bootstrap"
		return
	if not _caller_sample_mode:
		if not set_position_provider(Callable(self, &"_sample_production_actor_position")):
			_configuration_error = &"provider_injection_failed"
			return
	var bootstrap_snapshot := _bootstrap.get_snapshot()
	var policy_snapshot := bootstrap_snapshot.get("distance_policy", {}) as Dictionary
	_initial_policy_update_index = int(policy_snapshot.get("update_index", 0))
	_activated = true
	_configuration_error = &""
	set_physics_process(not _caller_sample_mode)


func _drive_physics_tick(
	delta: float,
	caller_sample: Variant = null,
	caller_supplied: bool = false
	) -> Dictionary:
	if not _activated or is_queued_for_deletion() or not is_inside_tree():
		return {"accepted": false, "reason": &"binding_unavailable"}
	if _tick_active:
		_reentrant_rejection_count += 1
		return {"accepted": false, "reason": &"reentrant_call"}
	if not is_finite(delta) or delta < 0.0:
		_invalid_delta_count += 1
		return {"accepted": false, "reason": &"invalid_delta"}
	if caller_supplied != _caller_sample_mode:
		return {"accepted": false, "reason": &"sampling_mode_mismatch"}
	_tick_active = true
	_provider_sample_count += 1
	if caller_supplied:
		_caller_sample_count += 1
	var sample: Variant = (
		caller_sample
		if caller_supplied
		else (
			_position_provider.call()
			if _position_provider.is_valid()
			else {"available": false, "reason": &"missing_position_provider"}
		)
	)
	var sample_valid := sample is Dictionary
	var sample_dictionary := sample as Dictionary if sample_valid else {}
	var available := sample_valid and bool(sample_dictionary.get("available", false))
	var position_value: Variant = sample_dictionary.get("position")
	if available:
		available = position_value is Vector3 and (position_value as Vector3).is_finite()
	if available:
		var position := position_value as Vector3
		var policy_position := position
		var cluster := _bootstrap.get_loaded_instance() as NearbySectorCluster
		if is_instance_valid(cluster):
			var generation := int(
				cluster.get_meta(&"world_location_generation", -1)
			)
			var distance := position.distance_to(_current_navigation_anchor())
			_last_presentation_result = cluster.advance_streaming_transition(
				delta, distance, generation
			)
			if bool(_last_presentation_result.get("accepted", false)):
				_presentation_advance_count += 1
				if (
					distance > CinderStreamingBootstrap.UNLOAD_RADIUS_METERS
					and not bool(
						_last_presentation_result.get("retire_ready", false)
					)
				):
					policy_position = _position_at_unload_boundary(position)
					_presentation_unload_hold_count += 1
			else:
				_presentation_rejection_count += 1
		if _bootstrap.set_tracked_position(_bootstrap.to_local(policy_position)):
			_available_sample_count += 1
			_last_actor_kind = sample_dictionary.get("actor_kind", &"unknown") as StringName
			_last_actor_instance_id = int(sample_dictionary.get("actor_instance_id", 0))
			_last_position = position
			_last_sample_reason = &"available"
		else:
			available = false
			sample_dictionary = {"reason": &"bootstrap_rejected_tracking_sample"}
	if not available:
		_unavailable_sample_count += 1
		if not sample_valid or bool((sample as Dictionary).get("available", false)):
			_invalid_sample_count += 1
		_last_actor_kind = &""
		_last_actor_instance_id = 0
		_last_sample_reason = sample_dictionary.get(
			"reason", &"invalid_provider_sample"
		) as StringName
		_bootstrap.clear_tracked_position()
	_last_tick_result = _bootstrap.physics_tick(delta)
	_synchronize_loaded_cluster_quality()
	_schedule_deferred_presentation_sync_after_load_request()
	_physics_tick_count += 1
	_tick_active = false
	return _last_tick_result.duplicate(true)


func _schedule_deferred_presentation_sync_after_load_request() -> void:
	if _deferred_quality_sync_pending:
		return
	var transitions := _last_tick_result.get("transitions", []) as Array
	for transition_value in transitions:
		var transition := transition_value as Dictionary
		if (
			transition.get("action") == &"load"
			and bool(transition.get("accepted", false))
		):
			# The production PackedScene loader completes on idle. Queue exactly one
			# idempotent synchronization behind that completion instead of burning a
			# deferred callable on every physics tick.
			_queue_deferred_presentation_sync()
			return


func _queue_deferred_presentation_sync() -> void:
	if _deferred_quality_sync_pending:
		return
	_deferred_quality_sync_pending = true
	_deferred_quality_sync_generation = _tree_generation
	call_deferred(
		&"_complete_deferred_presentation_sync",
		_deferred_quality_sync_generation
	)


func _complete_deferred_presentation_sync(generation: int) -> void:
	if (
		generation != _tree_generation
		or generation != _deferred_quality_sync_generation
		or is_queued_for_deletion()
		or not is_inside_tree()
	):
		return
	_deferred_quality_sync_pending = false
	_synchronize_loaded_cluster_quality()


func _synchronize_loaded_cluster_quality() -> void:
	var cluster := _bootstrap.get_loaded_instance() as NearbySectorCluster
	if not is_instance_valid(cluster):
		_quality_synced_instance_id = 0
		return
	var instance_id := cluster.get_instance_id()
	if _quality_synced_instance_id == instance_id:
		return
	var world := get_node_or_null(^"../ShipyardWorld") as ShipyardWorld
	if not is_instance_valid(world):
		return
	# ShipyardWorld remains the settings consumer. This binding only forwards
	# its already-retained presentation profile and Main's established immutable
	# torus budget to the new streamed generation.
	cluster.set_detail_quality(world.visual_quality_level)
	TorusGeometryBudget.normalise_tree(cluster)
	_quality_synced_instance_id = instance_id
	_quality_sync_count += 1


func _position_at_unload_boundary(actual_position: Vector3) -> Vector3:
	var anchor := _current_navigation_anchor()
	var direction := actual_position - anchor
	if direction.is_zero_approx():
		return anchor
	# Keep a deliberate half-metre guard inside the strict `> 650` policy
	# comparison. Reconstructing a non-axis-aligned Vector3 at exactly 650 can
	# round outward and accidentally retire a still-visible generation.
	return anchor + direction.normalized() * UNLOAD_HOLD_DISTANCE_METERS


func _current_navigation_anchor() -> Vector3:
	return (
		_bootstrap.global_transform * CinderStreamingBootstrap.EXPECTED_NAVIGATION_ANCHOR
		if is_instance_valid(_bootstrap)
		else CinderStreamingBootstrap.EXPECTED_NAVIGATION_ANCHOR
	)


func _sample_production_actor_position() -> Dictionary:
	var host := get_parent()
	if host != null and host.has_method(&"get_active_ship"):
		var active_ship := host.call(&"get_active_ship") as HeroShip
		if (
			is_instance_valid(active_ship)
			and active_ship.is_inside_tree()
			and active_ship.is_piloted()
			and not active_ship.is_destroyed()
			and active_ship.global_position.is_finite()
		):
			return {
				"available": true,
				"position": active_ship.global_position,
				"actor_kind": &"ship",
				"actor_instance_id": active_ship.get_instance_id(),
			}
	var tracked_player := get_node_or_null(player_path) as Node3D
	if (
		is_instance_valid(tracked_player)
		and tracked_player.is_inside_tree()
		and tracked_player.global_position.is_finite()
	):
		return {
			"available": true,
			"position": tracked_player.global_position,
			"actor_kind": &"player",
			"actor_instance_id": tracked_player.get_instance_id(),
		}
	return {
		"available": false,
		"reason": &"no_tracked_production_actor",
	}
