class_name NetworkCinderNavigatorPingBridge
extends RefCounted

## Server-side, caller-driven bridge for Cinder's physical navigator role.
## Network transport publishes only the already-authorized detached receipt;
## Cinder owns role admission and the bridge owns no sensing, movement, or
## combat authority.

const RoleProfile := preload("res://scripts/fleet/crew_role_gameplay_profile.gd")
const CinderType := preload("res://scripts/ships/cinder_cargo_hauler.gd")
const POLICY_VERSION: StringName = &"network_cinder_navigator_ping_bridge_v1"

var _adapter: Object
var _cinder: Object
var _last_sequence: Dictionary = {}
var _peer_generations: Dictionary = {}
var _detached := true


func attach(adapter: Object, cinder: Object) -> Dictionary:
	if adapter == null or not is_instance_valid(adapter) \
			or not adapter.has_method(&"publish_crew_snapshot"):
		return _result(false, &"adapter_unavailable")
	if cinder == null or not is_instance_valid(cinder) \
			or not cinder.has_method(&"submit_crew_intent") \
			or not cinder.has_method(&"get_crew_role_authority") \
			or not cinder.has_method(&"get_navigator_ping_snapshot"):
		return _result(false, &"cinder_unavailable")
	_adapter = adapter
	_cinder = cinder
	_last_sequence.clear()
	_peer_generations.clear()
	_detached = false
	return _result(true, &"attached")


func detach(reason: StringName = &"detached") -> Dictionary:
	_adapter = null
	_cinder = null
	_last_sequence.clear()
	_peer_generations.clear()
	_detached = true
	return _result(true, reason)


func release_peer(peer_id: int) -> Dictionary:
	if peer_id <= 0:
		return _result(false, &"invalid_peer")
	for key in _last_sequence.keys():
		if str(key).begins_with("%d:" % peer_id):
			_last_sequence.erase(key)
	for key in _peer_generations.keys():
		if str(key).begins_with("%d:" % peer_id):
			_peer_generations.erase(key)
	return _result(true, &"peer_released")


func submit_ping(
		peer_id: int,
		peer_generation: int,
		avatar_id: StringName,
		seat_generation: int,
		request_sequence: int,
		payload: Dictionary
) -> Dictionary:
	if _detached or _adapter == null or _cinder == null:
		return _result(false, &"detached")
	if peer_id <= 0 or peer_generation <= 0 or seat_generation <= 0 \
			or request_sequence <= 0 or avatar_id.is_empty():
		return _result(false, &"invalid_identity")
	var authority: Object = _cinder.get_crew_role_authority()
	if authority == null or not is_instance_valid(authority):
		return _result(false, &"authority_unavailable")
	var key := "%d:%s" % [peer_id, str(avatar_id)]
	var known_generation := int(_peer_generations.get(key, 0))
	if known_generation > peer_generation:
		return _result(false, &"stale_peer_generation")
	if known_generation < peer_generation:
		_last_sequence.erase(key)
		_peer_generations[key] = peer_generation
	if request_sequence <= int(_last_sequence.get(key, 0)):
		return _result(false, &"stale_request_sequence")
	var assignment: Dictionary = authority.get_assignment(peer_id, avatar_id) as Dictionary
	if assignment.is_empty() \
			or StringName(assignment.get("seat_id", &"")) != CinderType.NAVIGATOR_STATION_SEAT_ID \
			or StringName(assignment.get("role", &"")) != RoleProfile.ROLE_PASSENGER \
			or int(assignment.get("seat_generation", 0)) != seat_generation:
		return _result(false, &"navigator_identity_mismatch")
	var consumed: Dictionary = _cinder.submit_crew_intent(
		1,
		peer_id,
		avatar_id,
		RoleProfile.ACTION_PASSENGER_PING,
		payload,
		request_sequence
	)
	if not bool(consumed.get("consumed", false)):
		return _result(false, &"cinder_rejected", {"effect": consumed.duplicate(true)})
	var effect := consumed.get("effect", {}) as Dictionary
	var receipt := effect.get("receipt", {}) as Dictionary
	if receipt.is_empty() \
			or int(receipt.get("occupant_peer_id", 0)) != peer_id \
			or StringName(receipt.get("avatar_id", &"")) != avatar_id \
			or int(receipt.get("seat_generation", 0)) != seat_generation \
			or int(receipt.get("request_sequence", 0)) != request_sequence:
		return _result(false, &"invalid_cinder_receipt")
	var snapshot: Dictionary = _cinder.get_navigator_ping_snapshot() as Dictionary
	var snapshot_receipt := snapshot.get("receipt", {}) as Dictionary
	if snapshot_receipt.is_empty() \
			or StringName(snapshot.get("station_id", &"")) != CinderType.NAVIGATOR_STATION_SEAT_ID:
		return _result(false, &"invalid_cinder_snapshot")
	var wire_receipt := {
		"peer_id": peer_id,
		"peer_generation": peer_generation,
		"avatar_id": avatar_id,
		"seat_id": CinderType.NAVIGATOR_STATION_SEAT_ID,
		"seat_generation": seat_generation,
		"role": RoleProfile.ROLE_PASSENGER,
		"ship_id": CinderType.COMPONENT_ID,
		"ship_generation": 1,
		"request_sequence": request_sequence,
		"server_tick": 0,
		"migration_generation": 1,
		"action": RoleProfile.ACTION_PASSENGER_PING,
		"payload": snapshot_receipt.duplicate(true),
	}
	var published: Dictionary = _adapter.publish_crew_snapshot([{"receipt": wire_receipt}])
	if not bool(published.get("accepted", false)):
		return _result(false, &"network_publish_failed", {"publication": published.duplicate(true)})
	_last_sequence[key] = request_sequence
	return _result(true, &"navigator_ping_published", {
		"receipt": receipt.duplicate(true),
		"snapshot": snapshot.duplicate(true),
		"wire_receipt": wire_receipt.duplicate(true),
		"publication": published.duplicate(true),
	})


func get_snapshot() -> Dictionary:
	return {
		"policy_version": POLICY_VERSION,
		"attached": not _detached,
		"tracked_actor_count": _last_sequence.size(),
		"peer_generations": _peer_generations.duplicate(true),
	}.duplicate(true)


func _result(accepted: bool, status: StringName, extra: Dictionary = {}) -> Dictionary:
	var result := {"accepted": accepted, "status": status, "policy_version": POLICY_VERSION}
	result.merge(extra)
	return result
