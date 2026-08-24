class_name SurfaceRouteHazardPresenter
extends RefCounted

## Presentation-only surface navigation state. World movement, hazard
## authority, weather simulation, and recovery execution remain external.

const COMPONENT_ID: StringName = &"surface-route-hazard-presenter"
const CURSOR_KEYS := [
	"host_instance_id", "actor_instance_id", "session_instance_id",
	"attachment_generation", "generation", "revision",
]

var _snapshot: Dictionary = {}
var _host_instance_id := 0
var _actor_instance_id := 0
var _session_instance_id := 0
var _attachment_generation := -1
var _source_generation := -1
var _source_revision := -1
var _retired_host_instance_id := 0
var _retired_attachment_generation := -1


func present_snapshot(source: Dictionary) -> Dictionary:
	var cursor := _source_cursor(source)
	if bool(cursor.get("fenced", false)):
		if not bool(cursor.get("valid", false)):
			return _clear_unavailable(cursor.get("reason", &"invalid_source_cursor") as StringName)
		var cursor_result := _accept_cursor(cursor)
		if not bool(cursor_result.get("accepted", false)):
			if bool(cursor_result.get("clear", false)):
				return _clear_unavailable(cursor_result.get("reason", &"source_identity_mismatch") as StringName)
			return _snapshot.duplicate(true) if not _snapshot.is_empty() \
				else _unavailable_snapshot(cursor_result.get("reason", &"stale_source_cursor") as StringName)
	var waypoints: Array = source.get("waypoints", []) as Array
	var next := waypoints[0] as Dictionary if not waypoints.is_empty() and waypoints[0] is Dictionary else {}
	var hazard := source.get("hazard", {}) as Dictionary
	var exposure := _finite_exposure(hazard.get("exposure", hazard.get("exposure_unitless", 0.0)))
	var hazard_state := StringName(str(hazard.get("state", &"clear")))
	var recovery_request := hazard.get("recovery_request", {}) as Dictionary
	var recovery_required := hazard_state in [&"recovery_required", &"recovery_requested"] \
		or bool(recovery_request.get("requested", false))
	# A latched Ember recovery request is already in flight. Only an explicitly
	# authored availability flag may expose a request intent; otherwise the HUD
	# gives the player the recovery destination without promising a no-op action.
	var recovery_ready := bool(hazard.get("recovery_available", false)) \
		and not recovery_required
	var marker := _exposure_marker(exposure, hazard_state)
	var guidance := _hazard_guidance(hazard, hazard_state, exposure, recovery_required, next)
	var actions: Array = [
		_action(&"resume", "Resume Route"),
		_action(&"abort", "Abort Route"),
	]
	if recovery_ready:
		actions.append(_action(&"request_recovery", "Request Recovery"))
	var message := str(source.get("message", "")).strip_edges()
	var guidance_lines := PackedStringArray([
		"HAZARD // %s" % str(guidance.get("status", "STATUS UNAVAILABLE")),
		"NEXT ACTION // %s" % str(guidance.get("next_action", "AWAIT CURRENT STATUS")),
	])
	message = "%s\n%s" % [message, "\n".join(guidance_lines)] \
		if not message.is_empty() else "\n".join(guidance_lines)
	_snapshot = {
		"component_id": COMPONENT_ID,
		"accepted": true,
		"attached": true,
		"title": str(source.get("title", "SURFACE ROUTE")),
		"message": message,
		"next_landmark": str(next.get("label", "No waypoint queued")),
		"waypoint_id": StringName(str(next.get("id", &""))),
		"distance_m": maxf(0.0, _finite_number(next.get("distance_m", 0.0))),
		"weather": str(source.get("weather", "Unknown conditions")),
		"hazard_id": StringName(str(hazard.get("hazard_id", hazard.get("id", &"")))),
		"hazard_state": hazard_state,
		"hazard_status": str(guidance.get("status", "STATUS UNAVAILABLE")),
		"exposure": exposure,
		"exposure_marker": marker,
		"recovery_id": StringName(str(hazard.get("recovery_id", &""))),
		"recovery_available": recovery_ready,
		"next_action": str(guidance.get("next_action", "AWAIT CURRENT STATUS")),
		"next_action_text": "NEXT ACTION // %s" % str(guidance.get("next_action", "AWAIT CURRENT STATUS")),
		"actions": actions,
		"color_independent": true,
		"steady": true,
		"flash_requested": false,
		"presentation_only": true,
		"hazard_authority": false,
		"recovery_authority": false,
		"movement_authority": false,
		"boarding_authority": false,
		"reward_authority": false,
		"input_authority": false,
	}
	if bool(cursor.get("fenced", false)):
		_snapshot.merge({
			"host_instance_id": _host_instance_id,
			"actor_instance_id": _actor_instance_id,
			"session_instance_id": _session_instance_id,
			"attachment_generation": _attachment_generation,
			"generation": _source_generation,
			"revision": _source_revision,
		}, true)
	return _snapshot.duplicate(true)


func get_snapshot() -> Dictionary:
	return _snapshot.duplicate(true)


func detach() -> Dictionary:
	_retire_cursor()
	_clear_cursor()
	_snapshot = _unavailable_snapshot(&"detached")
	return _snapshot.duplicate(true)


func request_resume() -> Dictionary:
	return _intent(&"resume", &"resume_requested")


func request_abort() -> Dictionary:
	return _intent(&"abort", &"abort_requested")


func request_recovery() -> Dictionary:
	return _intent(&"request_recovery", &"recovery_requested")


func _intent(action: StringName, reason: StringName) -> Dictionary:
	for candidate in _snapshot.get("actions", []) as Array:
		if StringName(candidate.get("id", &"")) == action:
			return {
				"accepted": true, "reason": reason, "action": action,
				"presentation_only": true, "input_authority": false,
				"hazard_authority": false, "recovery_authority": false,
			}
	return {
		"accepted": false, "reason": &"action_unavailable", "action": action,
		"presentation_only": true, "input_authority": false,
		"hazard_authority": false, "recovery_authority": false,
	}


func _action(action_id: StringName, label: String) -> Dictionary:
	return {
		"id": action_id, "label": label, "focusable": true,
		"input_authority": false, "hazard_authority": false,
		"recovery_authority": false, "movement_authority": false,
	}.duplicate(true)


func _hazard_guidance(
		hazard: Dictionary, hazard_state: StringName, exposure: float,
		recovery_required: bool, next: Dictionary
	) -> Dictionary:
	if recovery_required:
		var authored_recovery := str(hazard.get("status_text", "")).strip_edges()
		var recovery_id := StringName(hazard.get("recovery_id", &""))
		return {
			"status": "RECOVERY REQUIRED",
			"next_action": authored_recovery.to_upper() \
				if not authored_recovery.is_empty() \
				else ("RETURN TO RECOVERY LANDMARK" \
					if not recovery_id.is_empty() else "AWAIT RECOVERY GUIDANCE"),
		}
	if hazard_state in [&"storm", &"blocked"] or exposure >= 0.8:
		return {"status": "HIGH EXPOSURE", "next_action": "LEAVE HAZARD ZONE"}
	if hazard_state in [&"warning", &"watch", &"warming"] or exposure >= 0.4:
		return {"status": "EXPOSURE RISING", "next_action": "MOVE CLEAR OF HAZARD"}
	var landmark := str(next.get("label", "")).strip_edges()
	return {
		"status": "SAFE WINDOW",
		"next_action": "CONTINUE TO %s" % landmark.to_upper() \
			if not landmark.is_empty() else "AWAIT NEXT WAYPOINT",
	}


func _exposure_marker(exposure: float, hazard_state: StringName) -> StringName:
	if hazard_state in [&"recovery_required", &"recovery_requested", &"storm", &"blocked"] \
			or exposure >= 0.8:
		return &"!! HIGH EXPOSURE !!"
	if hazard_state in [&"warning", &"watch", &"warming"] or exposure >= 0.4:
		return &"! EXPOSURE RISING !"
	return &"[ SAFE WINDOW ]"


func _source_cursor(source: Dictionary) -> Dictionary:
	var fenced := false
	for key in CURSOR_KEYS:
		if source.has(key):
			fenced = true
			break
	if not fenced:
		return {"fenced": false, "valid": true}
	var attached_variant: Variant = source.get("attached", null)
	var values := {}
	for key in CURSOR_KEYS:
		var value: Variant = source.get(key, null)
		var identity_key: bool = key in [
			"host_instance_id", "actor_instance_id", "session_instance_id",
		]
		if not value is int or (int(value) == 0 if identity_key else int(value) <= 0):
			return {
				"fenced": true, "valid": false,
				"reason": &"source_identity_lost" if key in ["actor_instance_id", "session_instance_id"] \
					else &"invalid_source_cursor",
			}
		values[key] = int(value)
	if not attached_variant is bool or not bool(attached_variant):
		return {"fenced": true, "valid": false, "reason": &"source_detached"}
	values["fenced"] = true
	values["valid"] = true
	return values


func _accept_cursor(cursor: Dictionary) -> Dictionary:
	var host_id := int(cursor.host_instance_id)
	var actor_id := int(cursor.actor_instance_id)
	var session_id := int(cursor.session_instance_id)
	var attachment := int(cursor.attachment_generation)
	var generation := int(cursor.generation)
	var revision := int(cursor.revision)
	if _host_instance_id == 0:
		if host_id == _retired_host_instance_id \
				and attachment <= _retired_attachment_generation:
			return {"accepted": false, "reason": &"retired_attachment"}
		_set_cursor(host_id, actor_id, session_id, attachment, generation, revision)
		return {"accepted": true}
	if host_id != _host_instance_id:
		return {"accepted": false, "clear": true, "reason": &"host_identity_mismatch"}
	if attachment < _attachment_generation:
		return {"accepted": false, "reason": &"stale_attachment_generation"}
	if attachment > _attachment_generation:
		_retire_cursor()
		_clear_cursor()
		_snapshot.clear()
		_set_cursor(host_id, actor_id, session_id, attachment, generation, revision)
		return {"accepted": true}
	if actor_id != _actor_instance_id or session_id != _session_instance_id:
		return {"accepted": false, "clear": true, "reason": &"source_identity_mismatch"}
	if generation < _source_generation \
			or (generation == _source_generation and revision <= _source_revision):
		return {"accepted": false, "reason": &"stale_source_revision"}
	if generation > _source_generation:
		_snapshot.clear()
	_source_generation = generation
	_source_revision = revision
	return {"accepted": true}


func _set_cursor(
		host_id: int, actor_id: int, session_id: int, attachment: int,
		generation: int, revision: int
	) -> void:
	_host_instance_id = host_id
	_actor_instance_id = actor_id
	_session_instance_id = session_id
	_attachment_generation = attachment
	_source_generation = generation
	_source_revision = revision


func _retire_cursor() -> void:
	if _host_instance_id == 0:
		return
	_retired_host_instance_id = _host_instance_id
	_retired_attachment_generation = _attachment_generation


func _clear_cursor() -> void:
	_host_instance_id = 0
	_actor_instance_id = 0
	_session_instance_id = 0
	_attachment_generation = -1
	_source_generation = -1
	_source_revision = -1


func _clear_unavailable(reason: StringName) -> Dictionary:
	_retire_cursor()
	_clear_cursor()
	_snapshot = _unavailable_snapshot(reason)
	return _snapshot.duplicate(true)


func _unavailable_snapshot(reason: StringName) -> Dictionary:
	return {
		"component_id": COMPONENT_ID,
		"accepted": false,
		"attached": false,
		"title": "SURFACE ROUTE",
		"message": "HAZARD // STATUS UNAVAILABLE\nNEXT ACTION // AWAIT CURRENT SURFACE STATUS",
		"hazard_state": &"unavailable",
		"hazard_status": "STATUS UNAVAILABLE",
		"next_action": "AWAIT CURRENT SURFACE STATUS",
		"actions": [],
		"reason": reason,
		"color_independent": true,
		"steady": true,
		"flash_requested": false,
		"presentation_only": true,
		"hazard_authority": false,
		"recovery_authority": false,
		"movement_authority": false,
		"boarding_authority": false,
		"reward_authority": false,
		"input_authority": false,
	}.duplicate(true)


func _finite_exposure(value: Variant) -> float:
	return clampf(_finite_number(value), 0.0, 1.0)


func _finite_number(value: Variant) -> float:
	if not (value is int or value is float) or not is_finite(float(value)):
		return 0.0
	return float(value)
