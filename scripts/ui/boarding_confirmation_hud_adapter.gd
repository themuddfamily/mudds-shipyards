class_name BoardingConfirmationHudAdapter
extends RefCounted

## Keeps boarding confirmation inside GameHUD's existing source-keyed retained
## card.  No HUD nodes, bounds, focus targets, or interaction handling are
## created or changed here.

const CARD_SOURCE := &"boarding_confirmation"

var _hud: Object
var _attached := false
var _last_view: Dictionary = {}


func attach(hud: Object) -> Dictionary:
	if hud == null or not is_instance_valid(hud) \
			or not hud.has_method(&"set_runtime_status_card") \
			or not hud.has_method(&"clear_runtime_status_card"):
		return {"accepted": false, "reason": &"hud_contract_missing", "presentation_only": true}
	_hud = hud
	_attached = true
	_last_view.clear()
	return {"accepted": true, "reason": &"bound", "presentation_only": true}


func detach() -> Dictionary:
	if is_instance_valid(_hud):
		_hud.call(&"clear_runtime_status_card", CARD_SOURCE)
	_hud = null
	_attached = false
	_last_view.clear()
	return {"accepted": true, "reason": &"detached", "presentation_only": true}


func apply_view(view: Dictionary) -> Dictionary:
	if not _attached or not is_instance_valid(_hud):
		return {"accepted": false, "reason": &"detached", "presentation_only": true}
	if not bool(view.get("accepted", false)) or not bool(view.get("presentation_only", false)):
		return {"accepted": false, "reason": &"invalid_presentation_view", "presentation_only": true}
	if view == _last_view:
		return {"accepted": true, "reason": &"duplicate", "presentation_only": true}
	var card := {
		"title": str(view.get("title", "[?] BOARDING STATUS")),
		"message": str(view.get("message", "")),
		"state": str(view.get("shape", "[?]")) + " " + str(view.get("state", "unknown")).to_upper(),
		"presentation_only": true,
	}
	if not bool(_hud.call(&"set_runtime_status_card", CARD_SOURCE, card, true)):
		return {"accepted": false, "reason": &"hud_rejected_card", "presentation_only": true}
	_last_view = view.duplicate(true)
	return {"accepted": true, "reason": &"applied", "state": view.get("state", &""), "presentation_only": true}


func get_snapshot() -> Dictionary:
	return {"attached": _attached and is_instance_valid(_hud), "view": _last_view.duplicate(true), "presentation_only": true}.duplicate(true)
