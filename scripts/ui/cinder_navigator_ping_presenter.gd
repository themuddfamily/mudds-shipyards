class_name CinderNavigatorPingPresenter
extends RefCounted

## Presentation-only projection of the Cinder navigator bridge.
## The caller supplies bridge results; this class owns no transport, seat,
## sensor, world-position, session, or HUD-root authority.

const COMPONENT_ID: StringName = &"cinder-navigator-ping-presenter"
const PING_ACTION: StringName = &"passenger_ping"
const CLEAR_ACTION: StringName = &"passenger_ping_clear"
const NAVIGATOR_SEAT_ID: StringName = &"cinder_navigator_station"
const CINDER_SHIP_ID: StringName = &"cinder-cargo-hauler"
const PASSENGER_ROLE: StringName = &"passenger"
const MAX_MARKER_LENGTH := 48
const MAX_STATUS_LENGTH := 64
const MAX_IDENTITY_LENGTH := 64

var _detached := true
var _snapshot: Dictionary = _make_available_snapshot(&"initial")
var _last_identity: Dictionary = {}
var _active_receipt: Dictionary = {}
var _lifecycle_generation := 0
var _migration_generation := 0


func present_bridge_result(result: Dictionary) -> Dictionary:
	var status := _bounded_name(result.get("status", &"unknown"), MAX_STATUS_LENGTH)
	var accepted := bool(result.get("accepted", false))
	if accepted and status == &"attached":
		_detached = false
		_reset_identity()
		_snapshot = _make_available_snapshot(&"attached")
		return _snapshot.duplicate(true)
	if accepted and status == &"detached":
		var tombstones := result.get("tombstones", []) as Array
		if not tombstones.is_empty():
			var cleared := present_tombstones(tombstones)
			if cleared.get("state") == &"cleared":
				cleared["attached"] = false
				cleared["lifecycle"] = &"detached"
				_snapshot = cleared.duplicate(true)
				_detached = true
				_reset_identity()
				return _snapshot.duplicate(true)
		_detached = true
		_reset_identity()
		_snapshot = _make_detached_snapshot(status)
		return _snapshot.duplicate(true)
	if accepted and status == &"peer_released":
		var released_tombstones := result.get("tombstones", []) as Array
		if released_tombstones.is_empty():
			return _present_rejection(&"missing_clear_tombstone")
		return present_tombstones(released_tombstones)
	if accepted:
		var wire_receipt := result.get("wire_receipt", {}) as Dictionary
		return present_wire_receipt(wire_receipt)
	var rejection_state: StringName = &"stale" if str(status).begins_with("stale") else &"rejected"
	return _present_rejection(status, rejection_state)


func present_wire_receipt(receipt: Dictionary) -> Dictionary:
	var invalid_reason := _receipt_validation_reason(receipt, PING_ACTION)
	if not invalid_reason.is_empty():
		return _present_rejection(invalid_reason)
	var peer_id := int(receipt.get("peer_id", 0))
	var peer_generation := int(receipt.get("peer_generation", 0))
	var seat_generation := int(receipt.get("seat_generation", 0))
	var ship_generation := int(receipt.get("ship_generation", 0))
	var request_sequence := int(receipt.get("request_sequence", 0))
	var migration_generation := int(receipt.get("migration_generation", 0))
	var server_tick := int(receipt.get("server_tick", 0))
	var avatar_id := StringName(receipt.get("avatar_id", &""))
	var seat_id := StringName(receipt.get("seat_id", &""))
	var identity_key := "%d:%s" % [peer_id, str(avatar_id)]
	var fence_reason := _receipt_fence_reason(identity_key, receipt)
	if not fence_reason.is_empty():
		return _present_rejection(fence_reason, &"stale")
	_detached = false
	_last_identity = {
		"identity_key": identity_key,
		"peer_id": peer_id,
		"peer_generation": peer_generation,
		"avatar_id": avatar_id,
		"seat_id": seat_id,
		"seat_generation": seat_generation,
		"ship_id": CINDER_SHIP_ID,
		"ship_generation": ship_generation,
		"request_sequence": request_sequence,
		"migration_generation": migration_generation,
		"server_tick": server_tick,
	}
	_active_receipt = receipt.duplicate(true)
	_lifecycle_generation = ship_generation if _lifecycle_generation == 0 else _lifecycle_generation
	_migration_generation = maxi(_migration_generation, migration_generation)
	var payload := receipt.get("payload", {}) as Dictionary
	var channel := _bounded_text(payload.get("channel", &"sensor"), 24).to_upper()
	var marker_id := _bounded_text(payload.get("marker_id", &""), MAX_MARKER_LENGTH)
	var role := _bounded_text(receipt.get("role", &""), 24).to_upper()
	var seat := _bounded_text(seat_id, 40)
	_snapshot = {
		"component_id": COMPONENT_ID,
		"state": &"active",
		"state_marker": &"●",
		"state_label": "ACTIVE",
		"title": "CINDER NAVIGATOR PING",
		"message": "[●] NAVIGATOR PING ACTIVE\nROLE // %s  //  SEAT // %s\nCHANNEL // %s  //  MARKER // %s\nPEER // %d / GEN %d  //  SEAT GEN %d\nMIGRATION // %d  //  SERVER TICK // %d\nREQUEST // %d\nPRESENTATION ONLY  //  NO SENSOR OR WORLD AUTHORITY" % [
			role, seat, channel, marker_id if not marker_id.is_empty() else "UNSPECIFIED",
			peer_id, peer_generation, seat_generation, migration_generation,
			server_tick, request_sequence,
		],
		"role": role,
		"avatar_id": avatar_id,
		"seat_id": seat_id,
		"channel": channel,
		"marker_id": marker_id,
		"peer_id": peer_id,
		"peer_generation": peer_generation,
		"seat_generation": seat_generation,
		"ship_id": CINDER_SHIP_ID,
		"ship_generation": ship_generation,
		"request_sequence": request_sequence,
		"migration_generation": migration_generation,
		"server_tick": server_tick,
		"attached": true,
		"lifecycle": &"active",
		"presentation_only": true,
		"authority": false,
	}.duplicate(true)
	return _snapshot.duplicate(true)


func present_tombstones(tombstones: Array) -> Dictionary:
	if _active_receipt.is_empty():
		return _present_rejection(&"unknown_clear_tombstone", &"stale")
	var best_clear: Dictionary = {}
	for item_variant in tombstones:
		if not item_variant is Dictionary:
			continue
		var item := item_variant as Dictionary
		var receipt := item.get("receipt", {}) as Dictionary
		if not _receipt_validation_reason(receipt, CLEAR_ACTION).is_empty():
			continue
		if not _clear_matches_active(receipt):
			continue
		var fence_reason := _receipt_fence_reason(str(_last_identity.get("identity_key", "")), receipt)
		if not fence_reason.is_empty():
			continue
		if best_clear.is_empty() \
				or int(receipt.get("migration_generation", 0)) > int(best_clear.get("migration_generation", 0)) \
				or (
					int(receipt.get("migration_generation", 0)) == int(best_clear.get("migration_generation", 0))
					and int(receipt.get("server_tick", 0)) > int(best_clear.get("server_tick", 0))
				):
			best_clear = receipt.duplicate(true)
	if best_clear.is_empty():
		return _present_rejection(&"stale_clear_tombstone", &"stale")
	_snapshot = _make_cleared_snapshot(
		_bounded_name((best_clear.get("payload", {}) as Dictionary).get("reason", &"cleared"), MAX_STATUS_LENGTH),
		best_clear,
	)
	_migration_generation = maxi(_migration_generation, int(best_clear.get("migration_generation", 0)))
	_active_receipt.clear()
	return _snapshot.duplicate(true)


func get_snapshot() -> Dictionary:
	return _snapshot.duplicate(true)


func detach() -> Dictionary:
	_detached = true
	_reset_identity()
	_snapshot = _make_detached_snapshot(&"detached")
	return _snapshot.duplicate(true)


func _present_rejection(reason: StringName, state: StringName = &"rejected") -> Dictionary:
	var label := "STALE" if state == &"stale" else "REJECTED"
	var bounded_reason := _bounded_name(reason, MAX_STATUS_LENGTH)
	return {
		"component_id": COMPONENT_ID,
		"state": state,
		"state_marker": &"!" if state == &"stale" else &"×",
		"state_label": label,
		"title": "CINDER NAVIGATOR PING",
		"message": "[%s] NAVIGATOR PING %s\nREASON // %s\nPRESENTATION ONLY  //  NO NETWORK OR SENSOR AUTHORITY" % [
			"!" if state == &"stale" else "×", label, str(bounded_reason).replace("_", " ").to_upper(),
		],
		"reason": bounded_reason,
		"attached": not _detached,
		"lifecycle": state,
		"presentation_only": true,
		"authority": false,
	}.duplicate(true)


func _make_available_snapshot(reason: StringName) -> Dictionary:
	return {
		"component_id": COMPONENT_ID,
		"state": &"available",
		"state_marker": &"○",
		"state_label": "AVAILABLE",
		"title": "CINDER NAVIGATOR PING",
		"message": "[○] NAVIGATOR PING AVAILABLE\nSTATUS // %s\nPRESENTATION ONLY  //  NO SENSOR OR WORLD AUTHORITY" % str(reason).replace("_", " ").to_upper(),
		"attached": not _detached,
		"lifecycle": &"available",
		"presentation_only": true,
		"authority": false,
	}.duplicate(true)


func _make_detached_snapshot(reason: StringName) -> Dictionary:
	var snapshot := _make_cleared_snapshot(reason, {})
	snapshot["state"] = &"detached"
	snapshot["state_marker"] = &"□"
	snapshot["state_label"] = "DETACHED"
	snapshot["attached"] = false
	snapshot["lifecycle"] = &"detached"
	snapshot["message"] = "[□] NAVIGATOR PING DETACHED\nREASON // %s\nPRESENTATION ONLY  //  NO NETWORK OR SENSOR AUTHORITY" % str(reason).replace("_", " ").to_upper()
	return snapshot.duplicate(true)


func _make_cleared_snapshot(reason: StringName, receipt: Dictionary) -> Dictionary:
	var payload := receipt.get("payload", {}) as Dictionary
	return {
		"component_id": COMPONENT_ID,
		"state": &"cleared",
		"state_marker": &"○",
		"state_label": "CLEARED",
		"title": "CINDER NAVIGATOR PING",
		"message": "[○] NAVIGATOR PING CLEARED\nREASON // %s\nMIGRATION // %d  //  SERVER TICK // %d\nPRESENTATION ONLY  //  NO SENSOR OR WORLD AUTHORITY" % [
			str(reason).replace("_", " ").to_upper(),
			int(receipt.get("migration_generation", 0)), int(receipt.get("server_tick", 0)),
		],
		"reason": reason,
		"channel": _bounded_text(payload.get("channel", &""), 24).to_upper(),
		"marker_id": _bounded_text(payload.get("marker_id", &""), MAX_MARKER_LENGTH),
		"role": _bounded_text(receipt.get("role", &""), 24).to_upper(),
		"peer_id": int(receipt.get("peer_id", 0)),
		"peer_generation": int(receipt.get("peer_generation", 0)),
		"avatar_id": StringName(receipt.get("avatar_id", &"")),
		"seat_id": StringName(receipt.get("seat_id", &"")),
		"seat_generation": int(receipt.get("seat_generation", 0)),
		"ship_id": StringName(receipt.get("ship_id", &"")),
		"ship_generation": int(receipt.get("ship_generation", 0)),
		"request_sequence": int(receipt.get("request_sequence", 0)),
		"migration_generation": int(receipt.get("migration_generation", 0)),
		"server_tick": int(receipt.get("server_tick", 0)),
		"attached": true,
		"lifecycle": &"cleared",
		"presentation_only": true,
		"authority": false,
	}.duplicate(true)


func _bounded_text(value: Variant, max_length: int) -> String:
	var text := str(value).strip_edges()
	if text.length() > max_length:
		return text.left(max_length)
	return text


func _bounded_name(value: Variant, max_length: int) -> StringName:
	return StringName(_bounded_text(value, max_length))


func _receipt_validation_reason(receipt: Dictionary, action: StringName) -> StringName:
	if receipt.is_empty() or str(receipt.get("action", "")) != str(action):
		return &"invalid_wire_receipt"
	var avatar_id := str(receipt.get("avatar_id", "")).strip_edges()
	if int(receipt.get("peer_id", 0)) <= 0 \
			or int(receipt.get("peer_generation", 0)) <= 0 \
			or avatar_id.is_empty() or avatar_id.length() > MAX_IDENTITY_LENGTH:
		return &"invalid_navigator_peer_identity"
	if str(receipt.get("seat_id", "")) != str(NAVIGATOR_SEAT_ID) \
			or int(receipt.get("seat_generation", 0)) <= 0 \
			or str(receipt.get("role", "")) != str(PASSENGER_ROLE):
		return &"invalid_navigator_seat_identity"
	if str(receipt.get("ship_id", "")) != str(CINDER_SHIP_ID) \
			or int(receipt.get("ship_generation", 0)) <= 0:
		return &"invalid_cinder_ship_identity"
	if int(receipt.get("request_sequence", 0)) <= 0 \
			or int(receipt.get("migration_generation", 0)) <= 0 \
			or int(receipt.get("server_tick", 0)) <= 0 \
			or not receipt.get("payload", null) is Dictionary:
		return &"invalid_wire_receipt"
	return &""


func _receipt_fence_reason(identity_key: String, receipt: Dictionary) -> StringName:
	var lifecycle_generation := int(receipt.get("ship_generation", 0))
	if _lifecycle_generation > 0 and lifecycle_generation != _lifecycle_generation:
		return &"stale_lifecycle_generation"
	var migration_generation := int(receipt.get("migration_generation", 0))
	if migration_generation < _migration_generation:
		return &"stale_migration_generation"
	if _last_identity.is_empty():
		return &""
	if identity_key != str(_last_identity.get("identity_key", "")):
		if int(receipt.get("seat_generation", 0)) <= int(_last_identity.get("seat_generation", 0)):
			return &"stale_seat_generation"
		return &""
	var prior_migration := int(_last_identity.get("migration_generation", 0))
	if migration_generation > prior_migration:
		return &""
	var peer_generation := int(receipt.get("peer_generation", 0))
	var prior_peer_generation := int(_last_identity.get("peer_generation", 0))
	if peer_generation < prior_peer_generation:
		return &"stale_peer_generation"
	if peer_generation > prior_peer_generation:
		return &""
	var seat_generation := int(receipt.get("seat_generation", 0))
	var prior_seat_generation := int(_last_identity.get("seat_generation", 0))
	if seat_generation < prior_seat_generation:
		return &"stale_seat_generation"
	if seat_generation > prior_seat_generation:
		return &""
	var request_sequence := int(receipt.get("request_sequence", 0))
	var prior_request_sequence := int(_last_identity.get("request_sequence", 0))
	if request_sequence <= prior_request_sequence:
		return &"stale_request_sequence"
	if int(receipt.get("server_tick", 0)) < int(_last_identity.get("server_tick", 0)):
		return &"stale_server_tick"
	return &""


func _clear_matches_active(clear: Dictionary) -> bool:
	if _active_receipt.is_empty():
		return false
	var payload := clear.get("payload", {}) as Dictionary
	return int(clear.get("peer_id", 0)) == int(_active_receipt.get("peer_id", 0)) \
			and StringName(clear.get("avatar_id", &"")) == StringName(_active_receipt.get("avatar_id", &"")) \
			and int(clear.get("peer_generation", 0)) == int(_active_receipt.get("peer_generation", 0)) \
			and StringName(clear.get("seat_id", &"")) == StringName(_active_receipt.get("seat_id", &"")) \
			and int(clear.get("seat_generation", 0)) == int(_active_receipt.get("seat_generation", 0)) \
			and StringName(clear.get("role", &"")) == StringName(_active_receipt.get("role", &"")) \
			and StringName(clear.get("ship_id", &"")) == StringName(_active_receipt.get("ship_id", &"")) \
			and int(clear.get("ship_generation", 0)) == int(_active_receipt.get("ship_generation", 0)) \
			and int(clear.get("migration_generation", 0)) >= int(_active_receipt.get("migration_generation", 0)) \
			and int(payload.get("source_request_sequence", 0)) == int(_active_receipt.get("request_sequence", 0)) \
			and int(clear.get("request_sequence", 0)) > int(_active_receipt.get("request_sequence", 0))


func _reset_identity() -> void:
	_last_identity.clear()
	_active_receipt.clear()
	_lifecycle_generation = 0
	_migration_generation = 0
