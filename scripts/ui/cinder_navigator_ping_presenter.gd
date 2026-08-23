class_name CinderNavigatorPingPresenter
extends RefCounted

## Presentation-only projection of the Cinder navigator bridge.
## The caller supplies bridge results; this class owns no transport, seat,
## sensor, world-position, session, or HUD-root authority.

const COMPONENT_ID: StringName = &"cinder-navigator-ping-presenter"
const PING_ACTION: StringName = &"passenger_ping"
const CLEAR_ACTION: StringName = &"passenger_ping_clear"
const MAX_MARKER_LENGTH := 48

var _detached := true
var _snapshot: Dictionary = _make_available_snapshot(&"initial")
var _last_identity: Dictionary = {}


func present_bridge_result(result: Dictionary) -> Dictionary:
	var status := StringName(result.get("status", &"unknown"))
	if status == &"attached":
		_detached = false
		_last_identity.clear()
		_snapshot = _make_available_snapshot(&"attached")
		return _snapshot.duplicate(true)
	if status == &"detached":
		var tombstones := result.get("tombstones", []) as Array
		if not tombstones.is_empty():
			var cleared := present_tombstones(tombstones)
			cleared["attached"] = false
			cleared["lifecycle"] = &"detached"
			_snapshot = cleared.duplicate(true)
			_detached = true
			return _snapshot.duplicate(true)
		_detached = true
		_last_identity.clear()
		_snapshot = _make_detached_snapshot(status)
		return _snapshot.duplicate(true)
	if status == &"peer_released":
		var released_tombstones := result.get("tombstones", []) as Array
		if released_tombstones.is_empty():
			_snapshot = _make_cleared_snapshot(&"peer_released", {})
		else:
			_snapshot = present_tombstones(released_tombstones)
		return _snapshot.duplicate(true)
	if bool(result.get("accepted", false)):
		var wire_receipt := result.get("wire_receipt", {}) as Dictionary
		return present_wire_receipt(wire_receipt)
	var rejection_state: StringName = &"stale" if str(status).begins_with("stale") else &"rejected"
	return _present_rejection(status, rejection_state)


func present_wire_receipt(receipt: Dictionary) -> Dictionary:
	if receipt.is_empty() or StringName(receipt.get("action", &"")) != PING_ACTION:
		return _present_rejection(&"invalid_wire_receipt")
	var peer_id := int(receipt.get("peer_id", 0))
	var peer_generation := int(receipt.get("peer_generation", 0))
	var seat_generation := int(receipt.get("seat_generation", 0))
	var request_sequence := int(receipt.get("request_sequence", 0))
	var migration_generation := int(receipt.get("migration_generation", 0))
	var server_tick := int(receipt.get("server_tick", 0))
	var avatar_id := StringName(receipt.get("avatar_id", &""))
	var seat_id := StringName(receipt.get("seat_id", &""))
	if peer_id <= 0 or peer_generation <= 0 or seat_generation <= 0 \
			or request_sequence <= 0 or migration_generation <= 0 \
			or server_tick <= 0 or avatar_id.is_empty() or seat_id.is_empty():
		return _present_rejection(&"invalid_wire_receipt")
	var identity_key := "%d:%s:%d" % [peer_id, str(avatar_id), seat_generation]
	var prior_migration := int(_last_identity.get("migration_generation", 0))
	var prior_peer_generation := int(_last_identity.get("peer_generation", 0))
	var prior_sequence := int(_last_identity.get("request_sequence", 0))
	if not _last_identity.is_empty():
		if migration_generation < prior_migration:
			return _present_rejection(&"stale_migration_generation", &"stale")
		if migration_generation == prior_migration \
				and peer_generation < prior_peer_generation:
			return _present_rejection(&"stale_peer_generation", &"stale")
		if migration_generation == prior_migration \
				and peer_generation == prior_peer_generation \
				and request_sequence <= prior_sequence:
			return _present_rejection(&"stale_request_sequence", &"stale")
	_detached = false
	_last_identity = {
		"identity_key": identity_key,
		"peer_id": peer_id,
		"peer_generation": peer_generation,
		"avatar_id": avatar_id,
		"seat_id": seat_id,
		"seat_generation": seat_generation,
		"request_sequence": request_sequence,
		"migration_generation": migration_generation,
		"server_tick": server_tick,
	}
	var payload := receipt.get("payload", {}) as Dictionary
	var channel := _bounded_text(payload.get("channel", &"sensor"), 24).to_upper()
	var marker_id := _bounded_text(payload.get("marker_id", &""), MAX_MARKER_LENGTH)
	var role := _bounded_text(receipt.get("role", &"passenger"), 24).to_upper()
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
		"seat_id": seat_id,
		"channel": channel,
		"marker_id": marker_id,
		"peer_id": peer_id,
		"peer_generation": peer_generation,
		"seat_generation": seat_generation,
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
	var best_clear: Dictionary = {}
	for item_variant in tombstones:
		var item := item_variant as Dictionary
		var receipt := item.get("receipt", {}) as Dictionary
		if StringName(receipt.get("action", &"")) != CLEAR_ACTION:
			continue
		var migration_generation := int(receipt.get("migration_generation", 0))
		var request_sequence := int(receipt.get("request_sequence", 0))
		if migration_generation <= 0 or request_sequence <= 0:
			continue
		if migration_generation < int(_last_identity.get("migration_generation", 0)):
			continue
		if request_sequence < int(_last_identity.get("request_sequence", 0)):
			continue
		if best_clear.is_empty() or request_sequence > int(best_clear.get("request_sequence", 0)):
			best_clear = receipt.duplicate(true)
	if best_clear.is_empty():
		return _present_rejection(&"stale_clear_tombstone", &"stale")
	_snapshot = _make_cleared_snapshot(
		StringName((best_clear.get("payload", {}) as Dictionary).get("reason", &"cleared")),
		best_clear,
	)
	_last_identity["request_sequence"] = int(best_clear.get("request_sequence", 0))
	_last_identity["migration_generation"] = int(best_clear.get("migration_generation", 0))
	return _snapshot.duplicate(true)


func get_snapshot() -> Dictionary:
	return _snapshot.duplicate(true)


func detach() -> Dictionary:
	_detached = true
	_last_identity.clear()
	_snapshot = _make_detached_snapshot(&"detached")
	return _snapshot.duplicate(true)


func _present_rejection(reason: StringName, state: StringName = &"rejected") -> Dictionary:
	var label := "STALE" if state == &"stale" else "REJECTED"
	_snapshot = {
		"component_id": COMPONENT_ID,
		"state": state,
		"state_marker": &"!" if state == &"stale" else &"×",
		"state_label": label,
		"title": "CINDER NAVIGATOR PING",
		"message": "[%s] NAVIGATOR PING %s\nREASON // %s\nPRESENTATION ONLY  //  NO NETWORK OR SENSOR AUTHORITY" % [
			"!" if state == &"stale" else "×", label, str(reason).replace("_", " ").to_upper(),
		],
		"reason": reason,
		"attached": not _detached,
		"lifecycle": state,
		"presentation_only": true,
		"authority": false,
	}.duplicate(true)
	return _snapshot.duplicate(true)


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
