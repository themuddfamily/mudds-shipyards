class_name DerelictPowerRestorationActivity
extends RefCounted

## The one reason to go inside the abandoned station hulk.
##
## The pilot flies out, parks against the hulk's dock shelf, climbs out of the
## seat, walks the vestibule, the spine corridor and the reactor gallery, and
## throws the auxiliary breaker at the far end. The bus takes a few seconds to
## come up; when it does, the run is complete and the salvaged power cell is
## worth exactly one receipt.
##
## **This is deliberately one-shot.** A derelict has one auxiliary bus and it is
## either dead or it is not. `reset()` exists for presentation and for a failed
## attempt that never completed; it cannot un-claim a claimed cell, and a
## claimed activity stays claimed through a save and a whole-`Main` re-entry
## because the durable record is the reward ledger, not a flag in here.
##
## **It owns no authority.** No store, no wallet, no ship, no berth, no
## geometry, no HUD, no network. It accepts caller-sampled actor positions and
## caller physics deltas, and it publishes one detached snapshot that
## `NearbyActivityRewardAdapter` and `GameFlowRewardAuthority` — the existing
## reward plumbing — turn into exactly one persisted receipt.
##
## `NEW`/`modern_interpretation`: no source authenticates this station, this
## activity, or its salvage.

const SCHEMA_VERSION := 1
const ACTIVITY_ID: StringName = &"cinder_hulk_power_restoration"
const REWARD_ID: StringName = &"hulk_auxiliary_power_cell"
const CONTENT_CLASS: StringName = &"NEW"
const EVIDENCE_STATUS: StringName = &"modern_interpretation"
const REPEATABLE := false

## Where the breaker physically is, in world coordinates. It matches
## `AbandonedStationHulk.HULK_ANCHOR + AbandonedStationHulk.BREAKER_LOCAL_POSITION`
## and the audit below refuses to let the two drift apart.
const BREAKER_ANCHOR := Vector3(-146.0, 23.8, -467.0)
## On foot, at the panel. This is deliberately far tighter than the 24 m flyby
## radius the derelict scan uses, because this activity is reached by walking.
const INTERACTION_RADIUS := 4.0
const RESTORE_SECONDS := 3.0

enum State { IDLE, RESTORING, COMPLETE, CLAIMED, RESET }

var _state := State.IDLE
var _generation := 0
var _elapsed := 0.0
var _reward_requested := false
var _claimed_receipts := 0


## Thrown by the on-foot pilot at the physical breaker. The caller supplies the
## actor's world position; this class never reads the scene.
func engage(actor_position: Vector3) -> Dictionary:
	if _state == State.CLAIMED:
		return _result(false, &"power_already_restored")
	if _state == State.RESTORING:
		return _result(false, &"already_restoring")
	if _state == State.COMPLETE:
		return _result(false, &"restoration_complete")
	if not actor_position.is_finite() \
			or actor_position.distance_to(BREAKER_ANCHOR) > INTERACTION_RADIUS:
		return _result(false, &"outside_breaker_reach")
	_generation += 1
	_state = State.RESTORING
	_elapsed = 0.0
	_reward_requested = false
	return _result(true, &"engaged")


## Caller physics delta only. Nothing here reads a wall clock, so two runs
## stepped with the same deltas produce the same completion frame.
func advance_physics(delta: float) -> Dictionary:
	if _state != State.RESTORING:
		return _result(false, &"not_restoring")
	if not is_finite(delta) or delta < 0.0:
		return _result(false, &"invalid_delta")
	_elapsed = minf(RESTORE_SECONDS, _elapsed + delta)
	if is_equal_approx(_elapsed, RESTORE_SECONDS):
		_state = State.COMPLETE
	return _result(true, &"complete" if _state == State.COMPLETE else &"advanced")


## Marks the single reward request this generation may produce. The adapter and
## the authority fence the same generation independently; this is only the
## activity's own half of the exactly-once contract.
func request_reward() -> Dictionary:
	if _state == State.CLAIMED:
		return _result(false, &"reward_already_claimed")
	if _state != State.COMPLETE:
		return _result(false, &"not_complete")
	if _reward_requested:
		return _result(false, &"reward_already_requested")
	_reward_requested = true
	var result := _result(true, &"reward_request_ready")
	result["reward_request"] = {
		"activity_id": ACTIVITY_ID,
		"activity_generation": _generation,
		"reward_id": REWARD_ID,
		"reward_authority": false,
		"granted": false,
	}
	return result


## Called with the authority's own committed receipt. Only a committed receipt
## closes the activity; a rejected commit leaves it complete and retryable so a
## transient store failure cannot silently eat the cell.
func commit_reward_receipt(receipt: Dictionary) -> Dictionary:
	if _state != State.COMPLETE:
		return _result(false, &"not_complete")
	if StringName(receipt.get("activity_id", &"")) != ACTIVITY_ID \
			or StringName(receipt.get("reward_id", &"")) != REWARD_ID \
			or not bool(receipt.get("granted", false)):
		return _result(false, &"receipt_not_committed")
	_state = State.CLAIMED
	_claimed_receipts = maxi(_claimed_receipts, 1)
	return _result(true, &"reward_claimed")


## Restores the terminal state from the persisted reward ledger after a save or
## a whole-`Main` re-entry. The ledger is the durable record: if it already
## counts this reward, the bus is up and the cell is gone, whatever this
## in-memory object last believed.
func restore_from_reward_ledger(reward_counts: Dictionary) -> Dictionary:
	var counted := int(reward_counts.get(String(REWARD_ID), 0))
	if counted <= 0:
		return _result(false, &"no_persisted_receipt")
	_claimed_receipts = counted
	_state = State.CLAIMED
	_elapsed = RESTORE_SECONDS
	_reward_requested = true
	_generation = maxi(_generation, 1)
	return _result(true, &"restored_claimed_from_ledger")


## Abandons an attempt that never completed. It deliberately cannot reopen a
## claimed activity: this run is one-shot by design, not by accident.
func reset() -> Dictionary:
	if _state == State.CLAIMED:
		return _result(false, &"reward_already_claimed")
	if _state == State.IDLE:
		return _result(false, &"already_idle")
	_state = State.RESET
	_elapsed = 0.0
	_reward_requested = false
	return _result(true, &"reset")


func get_snapshot() -> Dictionary:
	var progress := clampf(_elapsed / RESTORE_SECONDS, 0.0, 1.0)
	var terminal := _state == State.COMPLETE or _state == State.CLAIMED
	return {
		"schema_version": SCHEMA_VERSION,
		"activity_id": ACTIVITY_ID,
		"content_class": CONTENT_CLASS,
		"evidence_status": EVIDENCE_STATUS,
		"state": _state,
		"state_id": _state_id(_state),
		# The reward adapter admits only a cleared terminal snapshot. Publishing
		# the outcome here keeps that gate on the existing shared adapter rather
		# than adding a second reward path for this one activity.
		"outcome": &"cleared" if terminal else &"pending",
		"generation": _generation,
		"elapsed_seconds": _elapsed,
		"restore_seconds": RESTORE_SECONDS,
		"progress_unitless": progress,
		"repeatable": REPEATABLE,
		"breaker_anchor": BREAKER_ANCHOR,
		"interaction_radius": INTERACTION_RADIUS,
		"reward_id": REWARD_ID,
		"reward_requested": _reward_requested,
		"reward_pending": _reward_requested and _state == State.COMPLETE,
		"reward_claimed": _state == State.CLAIMED,
		"claimed_receipts": _claimed_receipts,
		"reward_authority": false,
		"gameplay_authority": false,
		"network_authority": false,
	}.duplicate(true)


func get_generation() -> int:
	return _generation


func is_claimed() -> bool:
	return _state == State.CLAIMED


static func _state_id(state: int) -> StringName:
	return [
		&"idle", &"active", &"complete", &"claimed", &"reset"
	][clampi(state, State.IDLE, State.RESET)]


func audit() -> Dictionary:
	var errors := PackedStringArray()
	var authored := AbandonedStationHulk.HULK_ANCHOR \
		+ AbandonedStationHulk.BREAKER_LOCAL_POSITION
	if not BREAKER_ANCHOR.is_equal_approx(authored):
		errors.append("breaker anchor diverged from the authored hulk panel")
	if BREAKER_ANCHOR.length() > NearbySectorCluster.MAXIMUM_CONTENT_DISTANCE:
		errors.append("breaker anchor leaves the authored cluster envelope")
	if BREAKER_ANCHOR.length() < NearbySectorCluster.MINIMUM_ANCHOR_DISTANCE:
		errors.append("breaker anchor crowds the station")
	if INTERACTION_RADIUS <= 0.0 or INTERACTION_RADIUS > 8.0:
		errors.append("breaker reach is not an on-foot radius")
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"activity_id": ACTIVITY_ID,
		"reward_id": REWARD_ID,
		"content_class": CONTENT_CLASS,
		"evidence_status": EVIDENCE_STATUS,
		"repeatable": REPEATABLE,
		"one_shot_policy": &"single_auxiliary_bus_claimed_once",
		"fixed_anchor_policy": &"authored_hulk_reactor_gallery_only",
		"reward_authority": false,
	}.duplicate(true)


func _result(accepted: bool, reason: StringName) -> Dictionary:
	var result := get_snapshot()
	result["accepted"] = accepted
	result["reason"] = reason
	return result
