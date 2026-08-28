class_name CinderNavigatorPingAudioBinding
extends Node

## Presentation-only consumer for already-authorized navigator ping receipts.
## The network bridge remains the sole owner of validation and publication.
signal semantic_navigator_ping_cue_emitted(cue_id: StringName, intensity: float)

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


func attach(lifecycle_generation: int = 0) -> Dictionary:
	if _attached:
		return _result(false, &"already_attached")
	if lifecycle_generation < 0:
		return _result(false, &"invalid_generation")
	_attached = true
	_lifecycle_generation = lifecycle_generation
	_reset_presentation_state()
	return _result(true, &"attached")


func present_bridge_result(result: Dictionary) -> Dictionary:
	if not _attached:
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
	if not _attached:
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
	if not _attached:
		return _result(false, &"detached")
	for previous in _seen_rejections:
		if previous == result:
			return _result(false, &"duplicate")
	_seen_rejections.append(result.duplicate(true))
	_emit(REJECTED, 0.8)
	return _result(true, &"rejected")


## Accepts either the bridge's complete release/detach result or its tombstone array.
func present_tombstones(value: Variant) -> Dictionary:
	if not _attached:
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
	if not _attached:
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
	_attached = false
	_lifecycle_generation = 0
	_reset_presentation_state()
	return _result(true, &"detached")


func get_snapshot() -> Dictionary:
	return {
		"attached": _attached,
		"lifecycle_generation": _lifecycle_generation,
		"migration_generation": _migration_generation,
		"active": _active.size(),
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
