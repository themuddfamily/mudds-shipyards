class_name BomberPayloadPresenter
extends RefCounted

## Presentation-only bomber payload status. The caller owns payload authority,
## cooldown timing, and release validation; this presenter only formats a
## detached snapshot and returns a release intent.

const SCHEMA_VERSION := 1
var _attached := false
var _generation := 0
var _source_generation := -1
var _snapshot: Dictionary = {}

func attach() -> Dictionary:
	_attached = true
	_generation += 1
	_snapshot = {}
	return get_snapshot()

func detach() -> Dictionary:
	_attached = false
	_generation += 1
	_snapshot = {}
	return get_snapshot()

func present_snapshot(snapshot: Dictionary) -> Dictionary:
	if not _attached:
		return _reject(&"detached")
	if not snapshot.has("generation") or not snapshot.generation is int or int(snapshot.generation) < 0:
		return _reject(&"invalid_generation")
	if int(snapshot.generation) < _source_generation:
		return _reject(&"stale_generation")
	_source_generation = int(snapshot.generation)
	_snapshot = snapshot.duplicate(true)
	return get_snapshot()

func request(action: StringName) -> Dictionary:
	if not _attached:
		return _reject(&"detached")
	if action != &"release_payload":
		return _reject(&"unknown_action")
	var presentation := get_snapshot()
	if not bool(presentation.get("release_allowed", false)):
		return {"accepted": false, "intent": action, "reason": presentation.get("reason", &"not_ready"), "generation": _generation, "snapshot": presentation, "presentation_only": true, "input_authority": false}
	return {"accepted": true, "intent": action, "generation": _generation, "snapshot": presentation, "presentation_only": true, "input_authority": false}

func get_snapshot() -> Dictionary:
	if not _attached:
		return {"schema_version": SCHEMA_VERSION, "attached": false, "generation": _generation, "state": &"detached", "release_allowed": false, "presentation_only": true, "input_authority": false}
	var active := bool(_snapshot.get("active", false))
	var ammo := maxi(0, int(_snapshot.get("ammo", 0)))
	var cooldown := maxf(0.0, float(_snapshot.get("cooldown_remaining", 0.0)))
	var terminal := bool(_snapshot.get("terminal", false))
	var reason := StringName(str(_snapshot.get("denied_reason", &"")))
	var state: StringName = &"inactive"
	var marker := "[OFFLINE]"
	var message := "BOMBER PAYLOAD UNAVAILABLE"
	if terminal:
		state = &"terminal"
		marker = "[ENDED]"
		message = "BOMBER PAYLOAD // SORTIE COMPLETE"
	elif not active:
		state = &"inactive"
	elif not reason.is_empty():
		state = &"denied"
		marker = "[DENIED]"
		message = "BOMBER PAYLOAD // %s" % str(_snapshot.get("denied_message", reason)).to_upper()
	elif ammo <= 0:
		state = &"empty"
		marker = "[EMPTY]"
		message = "BOMBER PAYLOAD // NO PAYLOAD REMAINING"
	elif cooldown > 0.0:
		state = &"cooldown"
		marker = "[WAIT]"
		message = "BOMBER PAYLOAD // COOLDOWN %.1f S" % cooldown
	else:
		state = &"ready"
		marker = "[READY]"
		message = "BOMBER PAYLOAD // READY"
	var action_label := str(_snapshot.get("action_label", "RELEASE PAYLOAD"))
	var action_glyph := str(_snapshot.get("action_glyph", ""))
	if not action_glyph.is_empty():
		action_label = "[%s] %s" % [action_glyph, action_label]
	var release_allowed := state == &"ready" and bool(_snapshot.get("release_allowed", true))
	return {"schema_version": SCHEMA_VERSION, "attached": true, "generation": _generation, "state": state, "marker": marker, "title": "BOMBER PAYLOAD", "message": message, "detail": "AMMO // %d" % ammo, "ammo": ammo, "cooldown_remaining": cooldown, "release_allowed": release_allowed, "reason": reason if not reason.is_empty() else state, "actions": [{"id": &"release_payload", "label": action_label}] if release_allowed else [], "reduced_motion": bool(_snapshot.get("reduced_motion", false)), "presentation_only": true, "input_authority": false}.duplicate(true)

func _reject(reason: StringName) -> Dictionary:
	return {"accepted": false, "reason": reason, "generation": _generation, "presentation_only": true, "input_authority": false}
