class_name CinderNavigatorPingAudioBinding
extends Node

## Presentation-only consumer for already-authorized navigator ping receipts.
## The network bridge remains the sole owner of validation and publication.
signal semantic_navigator_ping_cue_emitted(cue_id: StringName, intensity: float)

const BRIDGE_POLICY_VERSION: StringName = &"network_cinder_navigator_ping_bridge_v1"
const PING_ACTION: StringName = &"passenger_ping"
const CLEAR_ACTION: StringName = &"passenger_ping_clear"
const NAVIGATOR_SEAT_ID: StringName = &"cinder_navigator_station"
const CINDER_SHIP_ID: StringName = &"cinder_cargo_hauler"
const PASSENGER_ROLE: StringName = &"passenger"
const ACCEPTED: StringName = &"cinder_navigator_ping_accepted"
const REJECTED: StringName = &"cinder_navigator_ping_rejected"
const CLEARED: StringName = &"cinder_navigator_ping_cleared"

var _attached := false
var _lifecycle_generation := 0
var _migration_generation := 0
var _seen_receipts: Dictionary = {}
var _seen_rejections: Array[Dictionary] = []
var _active: Dictionary = {}
var _actor_fences: Dictionary = {}
var _local_claim: Dictionary = {}
var _local_sequence := 0
var _local_active: Dictionary = {}


func attach(lifecycle_generation: int = 0) -> Dictionary:
	if _attached:
		return _result(false, &"already_attached")
	if lifecycle_generation < 0:
		return _result(false, &"invalid_generation")
	_attached = true
	_lifecycle_generation = lifecycle_generation
	_reset_presentation_state()
	return _result(true, &"attached")


## Standalone receipts keep their real local identity; no wire envelope is invented.
func attach_local(claim: Dictionary) -> Dictionary:
	if _attached:
		return _result(false, &"already_attached")
	_local_claim = claim.duplicate()
	if not local_claim_is_current():
		_local_claim.clear()
		return _result(false, &"invalid_local_claim")
	_attached = true
	var craft: CinderCargoHauler = _local_claim.craft
	var historical: Dictionary = craft.get_navigator_ping_snapshot().get("receipt", {})
	_local_sequence = int(historical.get("request_sequence", 0)) if _local_receipt_matches(historical) else 0
	return _result(true, &"local_attached")


func local_claim_is_current() -> bool:
	var craft: Variant = _local_claim.get("craft")
	var authority: Variant = _local_claim.get("authority")
	if not is_instance_valid(craft) or not craft is CinderCargoHauler \
			or not is_instance_valid(authority) or not authority is CrewSeatRoleAuthority \
			or not craft.is_inside_tree() or craft.is_queued_for_deletion() or craft.is_destroyed() \
			or craft.get_crew_role_authority() != authority:
		return false
	var assignment: Dictionary = authority.get_assignment(1, StringName(_local_claim.get("avatar_id", &"")))
	return assignment.get("seat_id") == NAVIGATOR_SEAT_ID \
		and assignment.get("role") == PASSENGER_ROLE \
		and assignment.get("vessel_id") == CINDER_SHIP_ID \
		and int(_local_claim.get("seat_generation", 0)) > 0 \
		and int(assignment.get("seat_generation", 0)) == int(_local_claim.get("seat_generation", 0)) \
		and int(_local_claim.get("claim_sequence", 0)) > 0 \
		and int(assignment.get("claim_sequence", 0)) == int(_local_claim.get("claim_sequence", 0))


func present_local_result(result: Dictionary, claim: Dictionary, request_sequence: int) -> Dictionary:
	if not _attached or _local_claim.is_empty() or claim != _local_claim or not local_claim_is_current():
		return _result(false, &"stale_local_claim")
	if request_sequence <= _local_sequence:
		return _result(false, &"stale_local_request")
	var status: Variant = result.get("status")
	if not result.get("accepted") is bool or not (status is String or status is StringName) or str(status).is_empty():
		return _result(false, &"invalid_local_result")
	if result.accepted == false:
		_local_sequence = request_sequence
		_emit(REJECTED, 0.8)
		return _result(true, &"rejected")
	if result.get("consumed") != true or not result.get("effect") is Dictionary:
		return _result(false, &"unconsumed_local_result")
	var effect: Dictionary = result.effect
	if effect.get("accepted") != true or not effect.get("receipt") is Dictionary:
		return _result(false, &"invalid_local_effect")
	var receipt: Dictionary = effect.receipt
	var craft: CinderCargoHauler = _local_claim.craft
	if not _local_receipt_matches(receipt) or int(receipt.get("request_sequence", 0)) != request_sequence \
			or receipt != craft.get_navigator_ping_snapshot().get("receipt", {}):
		return _result(false, &"invalid_local_receipt")
	_local_sequence = request_sequence
	_local_active = receipt.duplicate(true)
	_emit(ACCEPTED, 0.7)
	return _result(true, &"accepted")


func present_local_clear(previous_receipt: Dictionary, claim: Dictionary) -> Dictionary:
	# The role ledger and GameFlow seat fields may already be empty on stand.
	# Ownership is the captured authority object and exact active receipt instead.
	if not _attached or _local_claim.is_empty() or claim != _local_claim \
			or _local_active.is_empty() or previous_receipt != _local_active:
		return _result(false, &"stale_local_clear")
	_local_active.clear()
	_emit(CLEARED, 0.6)
	return _result(true, &"cleared")


func _local_receipt_matches(receipt: Dictionary) -> bool:
	return int(receipt.get("occupant_peer_id", 0)) == 1 \
		and not StringName(_local_claim.get("avatar_id", &"")).is_empty() \
		and receipt.get("avatar_id") == _local_claim.get("avatar_id") \
		and int(receipt.get("seat_generation", 0)) == int(_local_claim.get("seat_generation", 0)) \
		and int(receipt.get("request_sequence", 0)) > 0 \
		and int(receipt.get("ping_generation", 0)) > 0 \
		and receipt.get("channel") == &"sensor" \
		and receipt.get("marker_id") == CinderCargoHauler.NAVIGATOR_ROUTE_ID


func present_bridge_result(result: Dictionary) -> Dictionary:
	if not _attached or not _local_claim.is_empty():
		return _result(false, &"detached")
	if result.has("wire_receipt"):
		if not bool(result.get("accepted", false)):
			return present_rejected(result)
		return present_receipt(result.get("wire_receipt", {}) as Dictionary)
	if result.has("tombstones"):
		return present_tombstones(result)
	if not bool(result.get("accepted", false)):
		return present_rejected(result)
	return _result(false, &"unsupported_bridge_result")


func present_receipt(receipt: Dictionary) -> Dictionary:
	if not _attached or not _local_claim.is_empty():
		return _result(false, &"detached")
	if not _valid_receipt(receipt, PING_ACTION):
		return _result(false, &"invalid_receipt")
	var replay_key := _receipt_key(receipt)
	if _seen_receipts.has(replay_key):
		return _result(false, &"duplicate")
	var actor_key := _actor_key(receipt)
	var fence_reason := _receipt_fence_reason(actor_key, receipt)
	if not fence_reason.is_empty():
		return _result(false, fence_reason)
	_seen_receipts[replay_key] = true
	_record_fence(actor_key, receipt)
	_active[actor_key] = receipt.duplicate(true)
	_emit(ACCEPTED, 0.7)
	return _result(true, &"accepted")


func present_rejected(result: Dictionary) -> Dictionary:
	if not _attached or not _local_claim.is_empty():
		return _result(false, &"detached")
	# Rejections have no receipt identity. Accept only the bridge's existing
	# result envelope; missing fields and truthy substitutes must stay silent.
	var status: Variant = result.get("status")
	var policy: Variant = result.get("policy_version")
	if not result.get("accepted") is bool or result.get("accepted") != false \
			or not (status is String or status is StringName) \
			or str(status).is_empty() \
			or not (policy is String or policy is StringName) \
			or StringName(policy) != BRIDGE_POLICY_VERSION:
		return _result(false, &"invalid_bridge_result")
	for previous in _seen_rejections:
		if previous == result:
			return _result(false, &"duplicate")
	_seen_rejections.append(result.duplicate(true))
	_emit(REJECTED, 0.8)
	return _result(true, &"rejected")


## Accepts either the bridge's complete release/detach result or its tombstone array.
func present_tombstones(value: Variant) -> Dictionary:
	if not _attached or not _local_claim.is_empty():
		return _result(false, &"detached")
	var tombstones: Array = []
	if value is Dictionary:
		tombstones = (value as Dictionary).get("tombstones", []) as Array
	elif value is Array:
		tombstones = value as Array
	else:
		return _result(false, &"invalid_tombstones")
	var emitted := 0
	for item_variant in tombstones:
		if not item_variant is Dictionary:
			continue
		var receipt := (item_variant as Dictionary).get("receipt", {}) as Dictionary
		var result := present_receipt_clear(receipt)
		if bool(result.get("accepted", false)):
			emitted += 1
	return {"accepted": true, "reason": &"tombstones_presented", "emitted": emitted}


func present_receipt_clear(receipt: Dictionary) -> Dictionary:
	if not _attached or not _local_claim.is_empty():
		return _result(false, &"detached")
	if not _valid_receipt(receipt, CLEAR_ACTION):
		return _result(false, &"invalid_tombstone")
	var replay_key := _receipt_key(receipt)
	if _seen_receipts.has(replay_key):
		return _result(false, &"duplicate")
	var actor_key := _actor_key(receipt)
	var active_receipt := _active.get(actor_key, {}) as Dictionary
	if active_receipt.is_empty():
		return _result(false, &"unknown_tombstone")
	if not _clear_matches_active(receipt, active_receipt):
		return _result(false, &"stale_tombstone")
	var fence_reason := _receipt_fence_reason(actor_key, receipt)
	if not fence_reason.is_empty():
		return _result(false, fence_reason)
	_seen_receipts[replay_key] = true
	_record_fence(actor_key, receipt)
	_active.erase(actor_key)
	_emit(CLEARED, 0.6)
	return _result(true, &"cleared")


func detach() -> Dictionary:
	_local_claim.clear()
	_local_sequence = 0
	_local_active.clear()
	_attached = false
	_lifecycle_generation = 0
	_reset_presentation_state()
	return _result(true, &"detached")


func get_snapshot() -> Dictionary:
	return {
		"attached": _attached,
		"lifecycle_generation": _lifecycle_generation,
		"migration_generation": _migration_generation,
		"active": _active.size() + (0 if _local_active.is_empty() else 1),
		"local": not _local_claim.is_empty(),
		"presentation_only": true,
		"authority": {"network": false, "sensor": false, "playback": false},
	}


func _exit_tree() -> void:
	detach()


func _emit(cue_id: StringName, intensity: float) -> void:
	semantic_navigator_ping_cue_emitted.emit(cue_id, intensity)


func _valid_receipt(receipt: Dictionary, action: StringName) -> bool:
	return StringName(receipt.get("action", &"")) == action \
			and int(receipt.get("peer_id", 0)) > 0 \
			and int(receipt.get("peer_generation", 0)) > 0 \
			and not StringName(receipt.get("avatar_id", &"")).is_empty() \
			and StringName(receipt.get("seat_id", &"")) == NAVIGATOR_SEAT_ID \
			and int(receipt.get("seat_generation", 0)) > 0 \
			and StringName(receipt.get("role", &"")) == PASSENGER_ROLE \
			and StringName(receipt.get("ship_id", &"")) == CINDER_SHIP_ID \
			and int(receipt.get("ship_generation", 0)) > 0 \
			and int(receipt.get("request_sequence", 0)) > 0 \
			and int(receipt.get("server_tick", 0)) > 0 \
			and int(receipt.get("migration_generation", 0)) > 0 \
			and receipt.get("payload", null) is Dictionary


func _receipt_key(receipt: Dictionary) -> String:
	return "%s:%d:%d:%s:%d:%s:%d:%d:%d:%d" % [
		str(receipt.get("action", &"")),
		int(receipt.get("migration_generation", 0)),
		int(receipt.get("peer_id", 0)),
		str(receipt.get("avatar_id", &"")),
		int(receipt.get("peer_generation", 0)),
		str(receipt.get("seat_id", &"")),
		int(receipt.get("seat_generation", 0)),
		int(receipt.get("ship_generation", 0)),
		int(receipt.get("request_sequence", 0)),
		int(receipt.get("server_tick", 0)),
	]


func _actor_key(receipt: Dictionary) -> String:
	return "%d:%s" % [int(receipt.get("peer_id", 0)), str(receipt.get("avatar_id", &""))]


func _receipt_fence_reason(actor_key: String, receipt: Dictionary) -> StringName:
	var lifecycle := int(receipt.get("ship_generation", 0))
	if _lifecycle_generation > 0 and lifecycle != _lifecycle_generation:
		return &"stale_lifecycle_generation"
	var migration := int(receipt.get("migration_generation", 0))
	if migration < _migration_generation:
		return &"stale_migration_generation"
	var previous := _actor_fences.get(actor_key, {}) as Dictionary
	if previous.is_empty() or migration > int(previous.get("migration_generation", 0)):
		return &""
	var peer_generation := int(receipt.get("peer_generation", 0))
	var prior_peer_generation := int(previous.get("peer_generation", 0))
	if peer_generation < prior_peer_generation:
		return &"stale_peer_generation"
	if peer_generation > prior_peer_generation:
		return &""
	var seat_generation := int(receipt.get("seat_generation", 0))
	var prior_seat_generation := int(previous.get("seat_generation", 0))
	if seat_generation < prior_seat_generation:
		return &"stale_seat_generation"
	if seat_generation > prior_seat_generation:
		return &""
	if int(receipt.get("request_sequence", 0)) <= int(previous.get("request_sequence", 0)):
		return &"stale_request_sequence"
	if int(receipt.get("server_tick", 0)) < int(previous.get("server_tick", 0)):
		return &"stale_server_tick"
	return &""


func _record_fence(actor_key: String, receipt: Dictionary) -> void:
	var migration := int(receipt.get("migration_generation", 0))
	_migration_generation = maxi(_migration_generation, migration)
	if _lifecycle_generation == 0:
		_lifecycle_generation = int(receipt.get("ship_generation", 0))
	_actor_fences[actor_key] = {
		"migration_generation": migration,
		"peer_generation": int(receipt.get("peer_generation", 0)),
		"seat_generation": int(receipt.get("seat_generation", 0)),
		"request_sequence": int(receipt.get("request_sequence", 0)),
		"server_tick": int(receipt.get("server_tick", 0)),
	}


func _clear_matches_active(clear: Dictionary, active_receipt: Dictionary) -> bool:
	var payload := clear.get("payload", {}) as Dictionary
	return int(clear.get("peer_generation", 0)) == int(active_receipt.get("peer_generation", 0)) \
			and StringName(clear.get("seat_id", &"")) == StringName(active_receipt.get("seat_id", &"")) \
			and int(clear.get("seat_generation", 0)) == int(active_receipt.get("seat_generation", 0)) \
			and StringName(clear.get("ship_id", &"")) == StringName(active_receipt.get("ship_id", &"")) \
			and int(clear.get("ship_generation", 0)) == int(active_receipt.get("ship_generation", 0)) \
			and int(clear.get("migration_generation", 0)) >= int(active_receipt.get("migration_generation", 0)) \
			and int(payload.get("source_request_sequence", 0)) == int(active_receipt.get("request_sequence", 0)) \
			and int(clear.get("request_sequence", 0)) > int(active_receipt.get("request_sequence", 0))


func _reset_presentation_state() -> void:
	_migration_generation = 0
	_seen_receipts.clear()
	_seen_rejections.clear()
	_active.clear()
	_actor_fences.clear()


func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {"accepted": accepted, "reason": reason}
