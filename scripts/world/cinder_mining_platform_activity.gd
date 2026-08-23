class_name CinderMiningPlatformActivity
extends RefCounted

## Original-modern extraction activity for the authored Cinder platform.
##
## This is a small caller-driven state machine: it validates the fixed approach
## and platform anchors, advances only supplied physics time, and emits a
## detached reward request. It never grants inventory, chooses a ship, or
## creates interaction geometry.

const SCHEMA_VERSION := 1
const ACTIVITY_ID: StringName = &"cinder_platform_mining_run"
const CONTENT_CLASS: StringName = &"NEW"
const EVIDENCE_STATUS: StringName = &"modern_interpretation"
const PLATFORM_ANCHOR := Vector3(60.0, -70.0, -700.0)
const APPROACH_ANCHOR := Vector3(60.0, -66.0, -605.0)
const INTERACTION_RADIUS := 30.0
const EXTRACTION_SECONDS := 6.0
const REWARD_ID: StringName = &"cinder_raw_ore_sample"

enum State { IDLE, ACTIVE, COMPLETE, RESET }

var _state := State.IDLE
var _generation := 0
var _elapsed := 0.0
var _reward_requested := false


func start(caller_position: Vector3) -> Dictionary:
	if _state == State.ACTIVE:
		return _result(false, &"already_active")
	if not caller_position.is_finite() or caller_position.distance_to(APPROACH_ANCHOR) > INTERACTION_RADIUS:
		return _result(false, &"outside_approach_anchor")
	_generation += 1
	_state = State.ACTIVE
	_elapsed = 0.0
	_reward_requested = false
	return _result(true, &"started")


func advance_physics(delta: float) -> Dictionary:
	if _state != State.ACTIVE:
		return _result(false, &"not_active")
	if not is_finite(delta) or delta < 0.0:
		return _result(false, &"invalid_delta")
	_elapsed = minf(EXTRACTION_SECONDS, _elapsed + delta)
	if is_equal_approx(_elapsed, EXTRACTION_SECONDS):
		_state = State.COMPLETE
	return _result(true, &"complete" if _state == State.COMPLETE else &"advanced")


func request_reward() -> Dictionary:
	if _state != State.COMPLETE:
		return _result(false, &"not_complete")
	if _reward_requested:
		return _result(false, &"reward_already_requested")
	_reward_requested = true
	var result := _result(true, &"reward_request_ready")
	result["reward_request"] = {
		"reward_id": REWARD_ID,
		"activity_id": ACTIVITY_ID,
		"generation": _generation,
		"granted": false,
	}
	return result


func reset() -> Dictionary:
	if _state == State.IDLE:
		return _result(false, &"already_idle")
	_state = State.RESET
	_elapsed = 0.0
	_reward_requested = false
	return _result(true, &"reset")


func get_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"activity_id": ACTIVITY_ID,
		"content_class": CONTENT_CLASS,
		"evidence_status": EVIDENCE_STATUS,
		"state": _state,
		"generation": _generation,
		"elapsed_seconds": _elapsed,
		"extraction_seconds": EXTRACTION_SECONDS,
		"platform_anchor": PLATFORM_ANCHOR,
		"approach_anchor": APPROACH_ANCHOR,
		"reward_requested": _reward_requested,
		"reward_authority": false,
		"gameplay_authority": false,
		"network_authority": false,
	}.duplicate(true)


func audit() -> Dictionary:
	var errors := PackedStringArray()
	if PLATFORM_ANCHOR.distance_to(NearbySectorCluster.PLATFORM_ANCHOR) > 0.001:
		errors.append("platform anchor diverged from NearbySectorCluster")
	if PLATFORM_ANCHOR.distance_to(Vector3.ZERO) > NearbySectorCluster.MAXIMUM_CONTENT_DISTANCE:
		errors.append("platform anchor leaves authored cluster envelope")
	if APPROACH_ANCHOR.distance_to(PLATFORM_ANCHOR) > NearbySectorCluster.MAXIMUM_CONTENT_DISTANCE:
		errors.append("approach anchor leaves authored platform envelope")
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"content_class": CONTENT_CLASS,
		"evidence_status": EVIDENCE_STATUS,
		"fixed_anchor_policy": &"authored_platform_and_gate_only",
		"reward_authority": false,
	}.duplicate(true)


func _result(accepted: bool, reason: StringName) -> Dictionary:
	var result := get_snapshot()
	result["accepted"] = accepted
	result["reason"] = reason
	return result
