class_name CinderNavigatorPingAudioBinding
extends Node

## Presentation-only consumer for already-authorized navigator ping receipts.
## The network bridge remains the sole owner of validation and publication.
signal semantic_crew_cue_emitted(cue_id: StringName, role: StringName, intensity: float)
signal semantic_navigator_ping_cue_emitted(cue_id: StringName, intensity: float)

const ROLE_PASSENGER: StringName = &"passenger"
const MAX_VOICES := 2
const ACCEPTED := &"cinder_navigator_ping_accepted"
const REJECTED := &"cinder_navigator_ping_rejected"
const CLEARED := &"cinder_navigator_ping_cleared"

var _attached := false
var _generation := 0
var _seen: Dictionary = {}
var _active: Dictionary = {}
var _fences: Dictionary = {}

func attach(generation: int = 0) -> Dictionary:
	if _attached:
		return _result(false, &"already_attached")
	if generation < 0:
		return _result(false, &"invalid_generation")
	_attached = true
	_generation = generation
	_seen.clear()
	_active.clear()
	_fences.clear()
	return _result(true, &"attached")

func present_bridge_result(result: Dictionary) -> Dictionary:
	if not _attached:
		return _result(false, &"detached")
	if bool(result.get("accepted", false)):
		return present_receipt(result.get("wire_receipt", {}) as Dictionary)
	return present_rejected(result)

func present_receipt(receipt: Dictionary) -> Dictionary:
	if not _attached:
		return _result(false, &"detached")
	if not _valid_receipt(receipt, &"passenger_ping"):
		return _result(false, &"invalid_receipt")
	var identity := _identity_key(receipt)
	if not _accept_fence(identity, receipt):
		return _result(false, &"stale_receipt")
	var key := _key(receipt)
	if _seen.has(key):
		return _result(false, &"duplicate")
	_seen[key] = true
	_active[identity] = true
	_emit(ACCEPTED, 0.7)
	return _result(true, &"accepted")

func present_rejected(result: Dictionary) -> Dictionary:
	if not _attached:
		return _result(false, &"detached")
	var status := StringName(result.get("status", result.get("reason", &"rejected")))
	if status.is_empty():
		status = &"rejected"
	var key := "reject:%s:%s" % [str(_generation), str(status)]
	if _seen.has(key):
		return _result(false, &"duplicate")
	_seen[key] = true
	_emit(REJECTED, 0.8)
	return _result(true, &"rejected")

func present_tombstones(tombstones: Array) -> Dictionary:
	var emitted := 0
	for item in tombstones:
		var receipt := (item as Dictionary).get("receipt", {}) as Dictionary
		var result := present_receipt_clear(receipt)
		if bool(result.get("accepted", false)):
			emitted += 1
	return {"accepted": true, "emitted": emitted}

func present_receipt_clear(receipt: Dictionary) -> Dictionary:
	if not _attached:
		return _result(false, &"detached")
	if not _valid_receipt(receipt, &"passenger_ping_clear"):
		return _result(false, &"invalid_tombstone")
	var key := _key(receipt)
	var source_key := _identity_key(receipt)
	if not _accept_fence(source_key, receipt):
		return _result(false, &"stale_tombstone")
	if _seen.has(key) or not _active.has(source_key):
		return _result(false, &"duplicate_or_unknown")
	_seen[key] = true
	_active.erase(source_key)
	_emit(CLEARED, 0.6)
	return _result(true, &"cleared")

func detach() -> Dictionary:
	_attached = false
	_generation = 0
	_seen.clear()
	_active.clear()
	_fences.clear()
	return _result(true, &"detached")

func get_snapshot() -> Dictionary:
	return {"attached": _attached, "generation": _generation, "active": _active.size(), "max_voices": MAX_VOICES, "authority": {"network": false, "sensor": false, "playback": false}}

func _emit(cue_id: StringName, intensity: float) -> void:
	semantic_navigator_ping_cue_emitted.emit(cue_id, intensity)
	# The router intentionally receives its established passenger vocabulary;
	# the typed signal above preserves the navigator-specific cue identity.
	var router_cue := &"crew_role_joined" if cue_id == ACCEPTED else (&"crew_role_left")
	semantic_crew_cue_emitted.emit(router_cue, ROLE_PASSENGER, intensity)

func _valid_receipt(receipt: Dictionary, action: StringName) -> bool:
	return StringName(receipt.get("action", &"")) == action \
			and int(receipt.get("peer_id", 0)) > 0 \
			and int(receipt.get("peer_generation", 0)) > 0 \
			and not StringName(receipt.get("avatar_id", &"")).is_empty() \
			and int(receipt.get("seat_generation", 0)) > 0 \
			and int(receipt.get("request_sequence", 0)) > 0 \
			and int(receipt.get("server_tick", 0)) > 0 \
			and int(receipt.get("migration_generation", 0)) > 0

func _key(receipt: Dictionary) -> String:
	return "%d:%s:%d:%d:%d:%d" % [int(receipt.get("peer_id", 0)), str(receipt.get("avatar_id", &"")), int(receipt.get("seat_generation", 0)), int(receipt.get("migration_generation", 0)), int(receipt.get("request_sequence", 0)), int(receipt.get("server_tick", 0))]

func _identity_key(receipt: Dictionary) -> String:
	return "%d:%s:%d:%d" % [int(receipt.get("peer_id", 0)), str(receipt.get("avatar_id", &"")), int(receipt.get("seat_generation", 0)), int(receipt.get("migration_generation", 0))]

func _accept_fence(identity: String, receipt: Dictionary) -> bool:
	var previous: Dictionary = _fences.get(identity, {}) as Dictionary
	if not previous.is_empty() and (int(receipt.get("request_sequence", 0)) <= int(previous.get("request_sequence", 0)) or int(receipt.get("server_tick", 0)) < int(previous.get("server_tick", 0)) or int(receipt.get("migration_generation", 0)) < int(previous.get("migration_generation", 0))):
		return false
	_fences[identity] = {"request_sequence": int(receipt.get("request_sequence", 0)), "server_tick": int(receipt.get("server_tick", 0)), "migration_generation": int(receipt.get("migration_generation", 0))}
	return true

func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {"accepted": accepted, "reason": reason}
