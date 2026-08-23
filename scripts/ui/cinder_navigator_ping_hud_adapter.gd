class_name CinderNavigatorPingHudAdapter
extends RefCounted

## Caller-injected presentation composition for the existing crew-role HUD row.
## It never owns HUD lifecycle, seats, transport, sensors, or ordinary crew
## fallback state; the caller supplies the base crew snapshot and HUD instance.

const PresenterType := preload("res://scripts/ui/cinder_navigator_ping_presenter.gd")
const COMPONENT_ID: StringName = &"cinder-navigator-ping-hud-adapter"
const PRESENTER_COMPONENT_ID: StringName = &"cinder-navigator-ping-presenter"
const PING_STATES := [&"active", &"stale", &"rejected", &"cleared"]
const TRANSIENT_STATES := [&"stale", &"rejected"]
const NAVIGATOR_SEAT_ID: StringName = &"cinder_navigator_station"
const CINDER_SHIP_ID: StringName = &"cinder-cargo-hauler"
const PASSENGER_ROLE := "PASSENGER"

var _presenter: Object
var _hud: Object
var _attached := false
var _generation := 0
var _last_result_key := ""
var _last_view_key := ""
var _last_view: Dictionary = {}
var _last_status_key := ""
var _last_status: Dictionary = {}
var _last_composed: Dictionary = {}


func attach(hud: Object, presenter: Object = null) -> Dictionary:
	if hud == null or not is_instance_valid(hud) or not hud.has_method(&"update_crew_role_status"):
		return _reject(&"hud_contract_missing")
	if presenter != null and (
			not is_instance_valid(presenter)
			or not presenter.has_method(&"present_bridge_result")
			or not presenter.has_method(&"get_snapshot")
	):
		return _reject(&"presenter_contract_missing")
	if _attached:
		detach()
	_hud = hud
	_presenter = presenter if presenter != null else PresenterType.new()
	_attached = true
	_generation += 1
	_last_result_key = ""
	_last_view_key = ""
	_last_view.clear()
	_last_status_key = ""
	_last_status.clear()
	_last_composed.clear()
	return {
		"accepted": true,
		"reason": &"bound",
		"generation": _generation,
		"presentation_only": true,
	}.duplicate(true)


func detach() -> Dictionary:
	_hud = null
	_presenter = null
	_attached = false
	_generation += 1
	_last_result_key = ""
	_last_view_key = ""
	_last_view.clear()
	_last_status_key = ""
	_last_status.clear()
	_last_composed.clear()
	return {
		"accepted": true,
		"reason": &"detached",
		"generation": _generation,
		"presentation_only": true,
	}.duplicate(true)


func apply_bridge_result(result: Dictionary, base_crew_snapshot: Dictionary = {}) -> Dictionary:
	if not _attached or _presenter == null or not is_instance_valid(_presenter):
		return _reject(&"detached")
	var result_key := _bridge_result_key(result)
	if result_key == _last_result_key:
		return {
			"accepted": true,
			"reason": &"duplicate",
			"generation": _generation,
			"presentation_only": true,
		}.duplicate(true)
	var view: Dictionary = _presenter.present_bridge_result(result)
	_last_result_key = result_key
	return apply_view(view, base_crew_snapshot)


func apply_view(view: Dictionary, base_crew_snapshot: Dictionary = {}) -> Dictionary:
	if not _attached or _hud == null or not is_instance_valid(_hud):
		return _reject(&"detached")
	if not bool(view.get("presentation_only", false)):
		return _reject(&"view_not_presentation_only")
	if StringName(view.get("component_id", &"")) != PRESENTER_COMPONENT_ID:
		return _reject(&"presenter_view_required")
	var state := StringName(view.get("state", &"rejected"))
	if not PING_STATES.has(state) and state not in [&"available", &"detached"]:
		return _reject(&"unknown_view_state")
	var view_key := _view_key(view)
	var transient := TRANSIENT_STATES.has(state)
	if (transient and view_key == _last_status_key) \
			or (not transient and view_key == _last_view_key):
		return {
			"accepted": true,
			"reason": &"duplicate",
			"generation": _generation,
			"source_state": state,
			"presentation_only": true,
		}.duplicate(true)
	var composed := _compose_crew_snapshot(view, base_crew_snapshot)
	_hud.call(&"update_crew_role_status", composed)
	if transient:
		_last_status_key = view_key
		_last_status = view.duplicate(true)
	else:
		_last_view_key = view_key
		_last_view = view.duplicate(true)
		_last_status_key = ""
		_last_status.clear()
	_last_composed = composed.duplicate(true)
	return {
		"accepted": true,
		"reason": &"applied",
		"generation": _generation,
		"source_state": state,
		"source_key": view_key,
		"composed": composed.duplicate(true),
		"presentation_only": true,
	}.duplicate(true)


func get_snapshot() -> Dictionary:
	return {
		"component_id": COMPONENT_ID,
		"attached": _attached and _hud != null and is_instance_valid(_hud),
		"generation": _generation,
		"source_view": _last_view.duplicate(true),
		"status_view": _last_status.duplicate(true),
		"composed_crew_snapshot": _last_composed.duplicate(true),
		"presentation_only": true,
		"hud_lifecycle_authority": false,
		"crew_role_authority": false,
	}.duplicate(true)


func _compose_crew_snapshot(view: Dictionary, base: Dictionary) -> Dictionary:
	var composed := base.duplicate(true)
	var roles := composed.get("roles", {}) as Dictionary
	var state := StringName(view.get("state", &"rejected"))
	var stable_view := view
	if TRANSIENT_STATES.has(state) and not _last_view.is_empty():
		stable_view = _last_view
	var stable_state := StringName(stable_view.get("state", &"rejected"))
	var exact_navigator := str(stable_view.get("role", "")) == PASSENGER_ROLE \
			and StringName(stable_view.get("seat_id", &"")) == NAVIGATOR_SEAT_ID \
			and StringName(stable_view.get("ship_id", &"")) == CINDER_SHIP_ID
	if stable_state in [&"active", &"cleared"] and exact_navigator:
		var passenger := roles.get(&"passenger", {}) as Dictionary
		var occupant := str(passenger.get("occupant", "")).strip_edges()
		if occupant.is_empty():
			occupant = "PEER %d" % int(stable_view.get("peer_id", 0)) if int(stable_view.get("peer_id", 0)) > 0 else "NAVIGATOR"
		var label := str(stable_view.get("state_label", stable_state)).to_upper()
		var marker := str(stable_view.get("state_marker", "!"))
		passenger["occupant"] = _bounded_text("%s // PING %s %s" % [occupant, label, marker], 96)
		passenger["available"] = false
		passenger["navigator_ping_state"] = stable_state
		roles[&"passenger"] = passenger
	composed["roles"] = roles
	composed["cinder_navigator_ping"] = stable_view.duplicate(true)
	if TRANSIENT_STATES.has(state):
		composed["cinder_navigator_ping_status"] = view.duplicate(true)
	else:
		composed.erase("cinder_navigator_ping_status")
	composed["presentation_only"] = true
	return composed


func _view_key(view: Dictionary) -> String:
	return "%s|%d|%s|%d|%s|%d|%s|%s|%d|%d|%d|%d|%s" % [
		str(view.get("state", &"unknown")),
		int(view.get("peer_id", 0)),
		str(view.get("avatar_id", &"")),
		int(view.get("peer_generation", 0)),
		str(view.get("seat_id", &"")),
		int(view.get("seat_generation", 0)),
		str(view.get("role", &"")),
		str(view.get("ship_id", &"")),
		int(view.get("ship_generation", 0)),
		int(view.get("migration_generation", 0)),
		int(view.get("server_tick", 0)),
		int(view.get("request_sequence", 0)),
		str(view.get("reason", &"")),
	]


func _bridge_result_key(result: Dictionary) -> String:
	var status := _bounded_text(str(result.get("status", &"unknown")).strip_edges(), 64)
	var envelope_prefix := "%d|%s" % [1 if bool(result.get("accepted", false)) else 0, status]
	var receipt := result.get("wire_receipt", {}) as Dictionary
	if not receipt.is_empty():
		return "%s|wire|%s" % [envelope_prefix, _receipt_key(receipt)]
	var tombstones := result.get("tombstones", []) as Array
	if not tombstones.is_empty():
		var receipt_keys := PackedStringArray()
		for item_variant in tombstones:
			if item_variant is Dictionary:
				var item_receipt := (item_variant as Dictionary).get("receipt", {}) as Dictionary
				receipt_keys.append(_receipt_key(item_receipt))
		return "%s|clear|%s" % [envelope_prefix, ";".join(receipt_keys)]
	return "%s|empty" % envelope_prefix


func _receipt_key(receipt: Dictionary) -> String:
	var payload := receipt.get("payload", {}) as Dictionary
	return "%s|%d|%s|%d|%s|%d|%s|%s|%d|%d|%d|%d|%d" % [
		_bounded_text(str(receipt.get("action", &"")), 64),
		int(receipt.get("peer_id", 0)),
		_bounded_text(str(receipt.get("avatar_id", &"")), 64),
		int(receipt.get("peer_generation", 0)),
		_bounded_text(str(receipt.get("seat_id", &"")), 64),
		int(receipt.get("seat_generation", 0)),
		_bounded_text(str(receipt.get("role", &"")), 64),
		_bounded_text(str(receipt.get("ship_id", &"")), 64),
		int(receipt.get("ship_generation", 0)),
		int(receipt.get("migration_generation", 0)),
		int(receipt.get("server_tick", 0)),
		int(receipt.get("request_sequence", 0)),
		int(payload.get("source_request_sequence", 0)),
	]


func _bounded_text(value: String, max_length: int) -> String:
	return value.left(max_length) if value.length() > max_length else value


func _reject(reason: StringName) -> Dictionary:
	return {
		"accepted": false,
		"reason": reason,
		"generation": _generation,
		"presentation_only": true,
	}.duplicate(true)
