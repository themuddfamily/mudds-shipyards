class_name CinderLoadmasterHudBinding
extends RefCounted

## Caller-injected bridge from the Cinder Hauler's detached role/manifest
## signals to HUD presentation. It owns no role, cargo, or polling authority.

var _craft: Node
var _hud: Node
var _role: StringName = &"loadmaster"
var _generation := 0
var _attached := false


func attach(craft: Node, hud: Node, role: StringName = &"loadmaster") -> Dictionary:
	if _attached:
		detach()
	if craft == null or hud == null or not is_instance_valid(craft) or not is_instance_valid(hud):
		return {"accepted": false, "reason": &"invalid_owner"}
	if not craft.has_method(&"get_loadmaster_status_snapshot") \
			or not craft.has_method(&"get_loadmaster_manifest_snapshot") \
			or not hud.has_method(&"update_cinder_loadmaster_telemetry"):
		return {"accepted": false, "reason": &"binding_contract_missing"}
	if not craft.has_signal(&"loadmaster_manifest_intent_accepted") \
			or not craft.has_signal(&"loadmaster_manifest_cleared"):
		return {"accepted": false, "reason": &"signal_contract_missing"}
	_craft = craft
	_hud = hud
	_role = role
	_attached = true
	_craft.connect(&"loadmaster_manifest_intent_accepted", _on_manifest_accepted)
	_craft.connect(&"loadmaster_manifest_cleared", _on_manifest_cleared)
	_publish_current()
	return {"accepted": true, "reason": &"bound", "generation": _generation, "presentation_only": true}


func detach() -> Dictionary:
	if not _attached:
		return {"accepted": true, "reason": &"already_detached", "presentation_only": true}
	if is_instance_valid(_craft):
		if _craft.is_connected(&"loadmaster_manifest_intent_accepted", _on_manifest_accepted):
			_craft.disconnect(&"loadmaster_manifest_intent_accepted", _on_manifest_accepted)
		if _craft.is_connected(&"loadmaster_manifest_cleared", _on_manifest_cleared):
			_craft.disconnect(&"loadmaster_manifest_cleared", _on_manifest_cleared)
	if is_instance_valid(_hud) and _hud.has_method(&"clear_loadmaster_telemetry"):
		_hud.call(&"clear_loadmaster_telemetry")
	_craft = null
	_hud = null
	_attached = false
	_generation = 0
	return {"accepted": true, "reason": &"detached", "presentation_only": true}


func is_attached() -> bool:
	return _attached and is_instance_valid(_craft) and is_instance_valid(_hud)


func get_snapshot() -> Dictionary:
	return {"attached": is_attached(), "generation": _generation, "role": _role, "presentation_only": true}


func _publish_current() -> void:
	if not is_attached():
		return
	var manifest := _craft.call(&"get_loadmaster_manifest_snapshot") as Dictionary
	_generation = int(manifest.get("manifest_generation", 0))
	_publish(
		_craft.call(&"get_loadmaster_status_snapshot") as Dictionary,
		manifest
	)


func _on_manifest_accepted(receipt: Dictionary) -> void:
	if not is_attached():
		return
	var receipt_generation := int(receipt.get("manifest_generation", 0))
	if receipt_generation < _generation:
		return
	_generation = receipt_generation
	var status := _craft.call(&"get_loadmaster_status_snapshot") as Dictionary
	status["state"] = &"manifest_ready" if bool(receipt.get("ready", false)) else &"occupied"
	status["generation"] = receipt_generation
	_publish(status, _craft.call(&"get_loadmaster_manifest_snapshot") as Dictionary)


func _on_manifest_cleared(generation: int, _reason: StringName) -> void:
	if not is_attached() or generation < _generation:
		return
	_generation = generation
	var status := _craft.call(&"get_loadmaster_status_snapshot") as Dictionary
	status["state"] = &"released" if _reason in [&"role_released", &"role_detached"] else &"available"
	status["generation"] = generation
	_publish(status, _craft.call(&"get_loadmaster_manifest_snapshot") as Dictionary)


func _publish(status: Dictionary, manifest: Dictionary) -> void:
	if is_attached():
		# The binding only adds a text-and-shape roster reading to the detached
		# presentation record.  It never changes the receipt, roster, or authority.
		var presentation_status := status.duplicate(true)
		var roster_reading := _roster_reading(
			StringName(presentation_status.get("state", &"")),
			manifest.get("receipt", {}) as Dictionary
		)
		presentation_status["roster_status"] = roster_reading["status"]
		presentation_status["roster_shape"] = roster_reading["shape"]
		presentation_status["presentation_only"] = true
		_hud.call(&"update_cinder_loadmaster_telemetry", _craft.get_ship_id(), _role, presentation_status, manifest)


func _roster_reading(state: StringName, receipt: Dictionary) -> Dictionary:
	if not receipt.is_empty():
		return {"shape": "[=]", "status": "SECURED // MANIFEST READY"} \
			if bool(receipt.get("ready", false)) \
			else {"shape": "[!]", "status": "BLOCKED // MANIFEST REVIEW"}
	match state:
		&"occupied":
			return {"shape": "[>]", "status": "LOADING // MANIFEST PENDING"}
		&"available", &"released":
			return {"shape": "[/]", "status": "DETACHED // STATION OPEN"}
		_:
			return {"shape": "[X]", "status": "FAULT // STATUS UNAVAILABLE"}
