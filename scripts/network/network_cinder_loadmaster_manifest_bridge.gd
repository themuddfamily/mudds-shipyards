class_name NetworkCinderLoadmasterManifestBridge
extends RefCounted

## Server-only, caller-driven bridge for Cinder's physical loadmaster role.
## Cinder remains the owner of manifest/readiness semantics; this bridge only
## validates network identity and publishes the detached receipt.

const RoleProfile := preload("res://scripts/fleet/crew_role_gameplay_profile.gd")
const CinderType := preload("res://scripts/ships/cinder_cargo_hauler.gd")
const POLICY_VERSION: StringName = &"network_cinder_loadmaster_manifest_bridge_v1"

var _adapter: Object
var _cinder: Object
var _last_sequence: Dictionary = {}
var _detached := true

func attach(adapter: Object, cinder: Object) -> Dictionary:
	if adapter == null or not is_instance_valid(adapter) or not adapter.has_method(&"publish_cargo_manifest_snapshot"):
		return _result(false, &"adapter_unavailable")
	if cinder == null or not is_instance_valid(cinder) or not cinder.has_method(&"submit_crew_intent") \
			or not cinder.has_method(&"get_crew_role_authority"):
		return _result(false, &"cinder_unavailable")
	_adapter = adapter
	_cinder = cinder
	_detached = false
	return _result(true, &"attached")

func detach(reason: StringName = &"detached") -> Dictionary:
	_adapter = null
	_cinder = null
	_last_sequence.clear()
	_detached = true
	return _result(true, reason)

func release_peer(peer_id: int) -> Dictionary:
	if peer_id <= 0:
		return _result(false, &"invalid_peer")
	for key in _last_sequence.keys():
		if str(key).begins_with("%d:" % peer_id):
			_last_sequence.erase(key)
	return _result(true, &"peer_released")

func submit_manifest(peer_id: int, peer_generation: int, avatar_id: StringName, seat_generation: int, request_sequence: int, payload: Dictionary) -> Dictionary:
	if _detached or _adapter == null or _cinder == null:
		return _result(false, &"detached")
	if peer_id <= 0 or peer_generation <= 0 or seat_generation <= 0 or request_sequence <= 0 or avatar_id.is_empty():
		return _result(false, &"invalid_identity")
	var action: StringName = RoleProfile.ACTION_PASSENGER_CARGO_MANIFEST
	var assignment: Dictionary = _cinder.get_crew_role_authority().get_assignment(peer_id, avatar_id) as Dictionary
	if assignment.is_empty() or StringName(assignment.get("seat_id", &"")) != CinderType.LOADMASTER_STATION_SEAT_ID \
			or StringName(assignment.get("role", &"")) != RoleProfile.ROLE_PASSENGER \
			or int(assignment.get("seat_generation", 0)) != seat_generation:
		return _result(false, &"loadmaster_identity_mismatch")
	var key := "%d:%s" % [peer_id, str(avatar_id)]
	if request_sequence <= int(_last_sequence.get(key, 0)):
		return _result(false, &"stale_request_sequence")
	var consumed: Dictionary = _cinder.submit_crew_intent(1, peer_id, avatar_id, action, payload, request_sequence)
	if not bool(consumed.get("consumed", false)):
		return _result(false, &"cinder_rejected", {"effect": consumed.duplicate(true)})
	var receipt := (consumed.get("effect", {}) as Dictionary).get("receipt", {}) as Dictionary
	if receipt.is_empty() or int(receipt.get("manifest_generation", 0)) <= 0:
		return _result(false, &"invalid_cinder_receipt")
	_last_sequence[key] = request_sequence
	var manifest := {
		"manifest_generation": int(receipt.get("manifest_generation", 0)), "terminal_generation": 1,
		"state": &"ready" if bool(receipt.get("ready", false)) else &"blocked",
		"source_id": &"cinder_loadmaster_manifest", "destination_id": &"cinder_freight_berth",
		"berth_id": &"cinder_loadmaster_station", "quantity": 1, "role": &"loadmaster",
		"seat_id": receipt.get("seat_id", &""), "occupant_peer_id": peer_id,
		"occupant_avatar_id": avatar_id, "manifest_id": receipt.get("manifest_id", &""),
		"route_id": receipt.get("route_id", &""), "ready": bool(receipt.get("ready", false)),
		"inventory_mutation_authority": false, "reward_authority": false, "helm_authority": false,
	}
	var published: Dictionary = _adapter.publish_cargo_manifest_snapshot(manifest)
	return _result(bool(published.get("accepted", false)), StringName(published.get("status", &"publish_failed")), {"receipt": receipt, "manifest": manifest})

func _result(accepted: bool, status: StringName, extra: Dictionary = {}) -> Dictionary:
	var result := {"accepted": accepted, "status": status, "policy_version": POLICY_VERSION}
	result.merge(extra)
	return result
