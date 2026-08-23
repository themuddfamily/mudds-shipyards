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
var _last_receipts: Dictionary = {}
var _last_server_ticks: Dictionary = {}
var _last_migration_generations: Dictionary = {}
var _detached := true


func attach(adapter: Object, cinder: Object) -> Dictionary:
	if adapter == null or not is_instance_valid(adapter) \
			or not adapter.has_method(&"publish_crew_snapshot") \
			or not adapter.has_method(&"get_migration_snapshot"):
		return _result(false, &"adapter_unavailable")
	if cinder == null or not is_instance_valid(cinder) \
			or not cinder.has_method(&"submit_crew_intent") \
			or not cinder.has_method(&"get_crew_role_authority") \
			or not cinder.has_method(&"get_navigator_ping_snapshot"):
		return _result(false, &"cinder_unavailable")
	if not _detached:
		detach(&"reattached")
	_adapter = adapter
	_cinder = cinder
	_last_sequence.clear()
	_peer_generations.clear()
	_last_receipts.clear()
	_last_server_ticks.clear()
	_last_migration_generations.clear()
	_detached = false
	return _result(true, &"attached")


func detach(reason: StringName = &"detached") -> Dictionary:
	var publication := _publish_tombstones(_last_receipts.keys(), reason)
	_adapter = null
	_cinder = null
	_last_sequence.clear()
	_peer_generations.clear()
	_last_receipts.clear()
	_last_server_ticks.clear()
	_last_migration_generations.clear()
	_detached = true
	var result := _result(true, reason)
	result["tombstone_count"] = int(publication.get("count", 0))
	result["tombstone_publication"] = publication.get("publication", {})
	result["tombstones"] = publication.get("tombstones", [])
	return result


func release_peer(peer_id: int) -> Dictionary:
	if peer_id <= 0:
		return _result(false, &"invalid_peer")
	var keys := _keys_for_peer(peer_id)
	var publication := _publish_tombstones(keys, &"peer_released")
	for key in keys:
		_last_sequence.erase(key)
		_peer_generations.erase(key)
		_last_receipts.erase(key)
		_last_server_ticks.erase(key)
		_last_migration_generations.erase(key)
	var result := _result(true, &"peer_released")
	result["tombstone_count"] = int(publication.get("count", 0))
	result["tombstone_publication"] = publication.get("publication", {})
	result["tombstones"] = publication.get("tombstones", [])
	return result


func submit_ping(
		peer_id: int,
		peer_generation: int,
		avatar_id: StringName,
		seat_generation: int,
		request_sequence: int,
		payload: Dictionary,
		server_tick: int,
		migration_generation: int
) -> Dictionary:
	if _detached or _adapter == null or _cinder == null:
		return _result(false, &"detached")
	if peer_id <= 0 or peer_generation <= 0 or seat_generation <= 0 \
			or request_sequence <= 0 or server_tick <= 0 \
			or migration_generation <= 0 or avatar_id.is_empty():
		return _result(false, &"invalid_identity")
	var adapter_migration := _adapter.get_migration_snapshot() as Dictionary
	var current_migration := int(adapter_migration.get("migration_generation", 0))
	if current_migration <= 0 or migration_generation != current_migration:
		return _result(false, &"stale_migration_generation")
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
	if server_tick < int(_last_server_ticks.get(key, 0)):
		return _result(false, &"stale_server_tick")
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
		"server_tick": server_tick,
		"migration_generation": migration_generation,
		"action": RoleProfile.ACTION_PASSENGER_PING,
		"payload": snapshot_receipt.duplicate(true),
	}
	var published: Dictionary = _adapter.publish_crew_snapshot([{"receipt": wire_receipt}])
	if not bool(published.get("accepted", false)):
		return _result(false, &"network_publish_failed", {"publication": published.duplicate(true)})
	_last_sequence[key] = request_sequence
	_last_receipts[key] = wire_receipt.duplicate(true)
	_last_server_ticks[key] = server_tick
	_last_migration_generations[key] = migration_generation
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
		"last_receipt_count": _last_receipts.size(),
	}.duplicate(true)


func _keys_for_peer(peer_id: int) -> Array[String]:
	var keys: Array[String] = []
	for key_variant in _last_receipts.keys():
		if str(key_variant).begins_with("%d:" % peer_id):
			keys.append(str(key_variant))
	return keys


func _publish_tombstones(keys: Array, reason: StringName) -> Dictionary:
	if _adapter == null or not is_instance_valid(_adapter) or keys.is_empty():
		return {"count": 0, "publication": {"accepted": true, "status": &"no_tombstones"}, "tombstones": []}
	var current_snapshot := _adapter.get_migration_snapshot() as Dictionary
	var current_migration := int(current_snapshot.get("migration_generation", 0))
	if current_migration <= 0:
		return {"count": 0, "publication": {"accepted": false, "status": &"migration_unavailable"}, "tombstones": []}
	var tombstones: Array = []
	for key_variant in keys:
		var key := str(key_variant)
		var prior := _last_receipts.get(key, {}) as Dictionary
		if prior.is_empty():
			continue
		var clear_receipt := prior.duplicate(true)
		clear_receipt["action"] = &"passenger_ping_clear"
		clear_receipt["request_sequence"] = int(prior.get("request_sequence", 0)) + 1
		clear_receipt["server_tick"] = int(prior.get("server_tick", 0)) + 1
		clear_receipt["migration_generation"] = current_migration
		clear_receipt["payload"] = {
			"channel": StringName((prior.get("payload", {}) as Dictionary).get("channel", &"sensor")),
			"marker_id": StringName((prior.get("payload", {}) as Dictionary).get("marker_id", &"")),
			"clear": true,
			"reason": reason,
			"source_request_sequence": int(prior.get("request_sequence", 0)),
		}.duplicate(true)
		tombstones.append({"receipt": clear_receipt})
	var published: Dictionary = _adapter.publish_crew_snapshot(tombstones)
	return {
		"count": tombstones.size(),
		"publication": published.duplicate(true),
		"tombstones": tombstones.duplicate(true),
	}


func _result(accepted: bool, status: StringName, extra: Dictionary = {}) -> Dictionary:
	var result := {"accepted": accepted, "status": status, "policy_version": POLICY_VERSION}
	result.merge(extra)
	return result
