class_name NetworkHalyardCrewCommandBridge
extends RefCounted

## Dispatches already-admitted, server-produced crew command receipts into the
## existing Halyard intent seam. This bridge owns no ship mutation or client
## authority; Halyard remains the gameplay consumer.

const POLICY_VERSION: StringName = &"network_halyard_crew_command_bridge_v1"

var _authority_peer_id := 1
var _migration_generation := 1
var _last_sequence: Dictionary = {}
var _dispatch_sequence := 0
var _adapter: Object
var _halyard: Object


func attach(adapter: Object, halyard: Object) -> Dictionary:
	if adapter == null or not is_instance_valid(adapter) or not adapter.has_signal(&"crew_command_result"):
		return _result(false, &"adapter_unavailable")
	if halyard == null or not is_instance_valid(halyard) or not halyard.has_method(&"submit_crew_intent"):
		return _result(false, &"halyard_unavailable")
	if _adapter != null and is_instance_valid(_adapter):
		var callback := Callable(self, &"_on_command_result")
		if _adapter.is_connected(&"crew_command_result", callback):
			_adapter.disconnect(&"crew_command_result", callback)
	_adapter = adapter
	_halyard = halyard
	_adapter.connect(&"crew_command_result", Callable(self, &"_on_command_result"))
	return _result(true, &"attached")


func detach() -> Dictionary:
	if _adapter != null and is_instance_valid(_adapter):
		var callback := Callable(self, &"_on_command_result")
		if _adapter.is_connected(&"crew_command_result", callback):
			_adapter.disconnect(&"crew_command_result", callback)
	_adapter = null
	_halyard = null
	_last_sequence.clear()
	return _result(true, &"detached")


func _init(p_authority_peer_id: int = 1) -> void:
	_authority_peer_id = maxi(1, p_authority_peer_id)


func dispatch(source_peer_id: int, receipt: Dictionary, halyard: Object) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _result(false, &"unauthorized_source")
	if halyard == null or not is_instance_valid(halyard) or not halyard.has_method(&"submit_crew_intent"):
		return _result(false, &"halyard_unavailable")
	if not bool(receipt.get("accepted", false)) or receipt.get("status") != &"command_accepted":
		return _result(false, &"receipt_not_accepted")
	var command := receipt.get("receipt", {}) as Dictionary
	var peer_id := int(command.get("peer_id", 0))
	var peer_generation := int(command.get("peer_generation", 0))
	var seat_generation := int(command.get("seat_generation", 0))
	var request_sequence := int(command.get("request_sequence", 0))
	var migration_generation := int(command.get("migration_generation", 0))
	var avatar_id := StringName(command.get("avatar_id", &""))
	var action := StringName(command.get("action", &""))
	var seat_id := StringName(command.get("seat_id", &""))
	if peer_id <= 0 or peer_generation <= 0 or seat_generation <= 0 or request_sequence <= 0 \
		or migration_generation != _migration_generation or avatar_id.is_empty() \
		or seat_id.is_empty() or action.is_empty():
		return _result(false, &"invalid_receipt_identity")
	var stream_key := "%d:%s:%s" % [peer_id, str(avatar_id), str(action)]
	if request_sequence <= int(_last_sequence.get(stream_key, 0)):
		return _result(false, &"stale_receipt_sequence")
	var payload := command.get("payload", {}) as Dictionary
	var result: Dictionary = halyard.submit_crew_intent(
		_authority_peer_id, peer_id, avatar_id, action, payload, request_sequence
	)
	if not bool(result.get("accepted", false)):
		return _result(false, &"halyard_rejected", {"effect": result.duplicate(true)})
	_last_sequence[stream_key] = request_sequence
	_dispatch_sequence += 1
	return _result(true, &"intent_dispatched", {
		"dispatch_sequence": _dispatch_sequence,
		"peer_id": peer_id,
		"peer_generation": peer_generation,
		"seat_id": seat_id,
		"seat_generation": seat_generation,
		"effect": result.duplicate(true),
	})


func release_peer(source_peer_id: int, peer_id: int, peer_generation: int) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _result(false, &"unauthorized_source")
	if peer_id <= 0 or peer_generation <= 0:
		return _result(false, &"invalid_peer_generation")
	var prefix := "%d:" % peer_id
	for key_variant in _last_sequence.keys():
		if str(key_variant).begins_with(prefix):
			_last_sequence.erase(key_variant)
	return _result(true, &"peer_released")


func reset_migration(source_peer_id: int, migration_generation: int) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _result(false, &"unauthorized_source")
	if migration_generation <= _migration_generation:
		return _result(false, &"stale_migration_generation")
	_migration_generation = migration_generation
	_last_sequence.clear()
	_dispatch_sequence = 0
	return _result(true, &"migration_reset")


func get_snapshot() -> Dictionary:
	return {
		"policy_version": POLICY_VERSION,
		"migration_generation": _migration_generation,
		"tracked_stream_count": _last_sequence.size(),
		"dispatch_sequence": _dispatch_sequence,
	}.duplicate(true)


func _on_command_result(result: Dictionary) -> void:
	if _halyard != null and is_instance_valid(_halyard):
		dispatch(_authority_peer_id, result, _halyard)


func _result(accepted: bool, status: StringName, extra: Dictionary = {}) -> Dictionary:
	var result := {"accepted": accepted, "status": status}
	result.merge(extra)
	return result
