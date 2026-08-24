class_name EmberSurfaceReturnStatusBinding
extends RefCounted

## Caller-injected bridge from Ember Host/ProductionBinding snapshots to the
## detached return presenter. It owns no travel, landing, or return authority.

const PresenterType := preload("res://scripts/ui/ember_surface_return_status_presenter.gd")

signal presentation_changed(view: Dictionary)

var _production: Object
var _host: Object
var _presenter: Object
var _attached := false
var _generation := 0
var _last_result: Dictionary = {}
var _view: Dictionary = {}
var _reduced_motion := false
var _last_host_generation := -1
var _last_production_generation := -1
var _last_attachment_generation := -1


func attach(production: Object, host: Object, presenter: Object = null, reduced_motion: bool = false) -> Dictionary:
	if _attached:
		detach()
	if production == null or not is_instance_valid(production) \
			or not production.has_signal(&"state_changed") \
			or not production.has_signal(&"completion_handback_ready") \
			or not production.has_method(&"get_snapshot") \
			or not production.has_method(&"get_planetary_relay_survey_return_manifest_snapshot"):
		return _reject(&"production_contract_missing")
	if host == null or not is_instance_valid(host) or not host.has_method(&"get_snapshot"):
		return _reject(&"host_contract_missing")
	_production = production
	_host = host
	_presenter = presenter if presenter != null else PresenterType.new()
	_attached = true
	_generation += 1
	_reduced_motion = reduced_motion
	_last_host_generation = -1
	_last_production_generation = -1
	_last_attachment_generation = -1
	_production.connect(&"state_changed", _on_state_changed)
	_production.connect(&"completion_handback_ready", _on_completion)
	_publish(reduced_motion)
	return {"accepted": true, "reason": &"bound", "generation": _generation, "presentation_only": true}


func detach() -> Dictionary:
	if is_instance_valid(_production):
		if _production.is_connected(&"state_changed", _on_state_changed):
			_production.disconnect(&"state_changed", _on_state_changed)
		if _production.is_connected(&"completion_handback_ready", _on_completion):
			_production.disconnect(&"completion_handback_ready", _on_completion)
	if _presenter != null:
		_presenter.call(&"detach")
	_production = null
	_host = null
	_attached = false
	_generation += 1
	_last_result = {}
	_view = {}
	_reduced_motion = false
	_last_host_generation = -1
	_last_production_generation = -1
	_last_attachment_generation = -1
	return {"accepted": true, "reason": &"detached", "generation": _generation, "presentation_only": true}


func apply_return_manifest_receipt(receipt: Dictionary, reduced_motion: bool = false) -> Dictionary:
	if not _attached:
		return _reject(&"detached")
	if not _receipt_matches_current_source(receipt):
		return _reject(&"stale_receipt_generation")
	_last_result = receipt.duplicate(true)
	return _publish(reduced_motion)


func get_snapshot() -> Dictionary:
	return {"attached": _attached, "generation": _generation, "view": _view.duplicate(true), "last_result": _last_result.duplicate(true), "presentation_only": true, "movement_authority": false, "landing_authority": false, "reward_authority": false}.duplicate(true)


func get_presenter_snapshot() -> Dictionary:
	return _view.duplicate(true)


func _on_state_changed(_snapshot: Dictionary) -> void:
	_publish(_reduced_motion)


func _on_completion(receipt: Dictionary) -> void:
	if _receipt_matches_current_source(receipt):
		_last_result = receipt.duplicate(true)
	_publish(_reduced_motion)


func _publish(reduced_motion: bool) -> Dictionary:
	if not _attached:
		return _reject(&"detached")
	if not is_instance_valid(_production) or not is_instance_valid(_host):
		return _clear_view(&"source_lost", _generation, reduced_motion)
	var production_snapshot := _production.call(&"get_snapshot") as Dictionary
	var host_snapshot := _host.call(&"get_snapshot") as Dictionary
	var host_generation := int(host_snapshot.get("generation", -1))
	var production_generation := int(production_snapshot.get("generation", -1))
	var attachment_generation := int(
		host_snapshot.get("attachment_generation", -1)
	)
	if host_generation < 0 or production_generation < 0 \
			or attachment_generation < 0:
		return _reject(&"invalid_source_generation")
	if (_last_host_generation >= 0 and host_generation < _last_host_generation) \
			or (_last_production_generation >= 0 \
				and production_generation < _last_production_generation) \
			or (_last_attachment_generation >= 0 \
				and attachment_generation < _last_attachment_generation):
		return _reject(&"stale_source_generation")
	var attachment_reused := _last_attachment_generation >= 0 \
		and attachment_generation > _last_attachment_generation
	_last_host_generation = host_generation
	_last_production_generation = production_generation
	_last_attachment_generation = attachment_generation
	if attachment_reused:
		# Receipts describe one exact surface attachment. A reused actor/session
		# gets a clean presenter generation and cannot inherit the prior loop's
		# destination or recovery wording.
		_last_result = {}
		_presenter.call(&"detach")
	elif _last_result_is_return_manifest() \
			and StringName(host_snapshot.get("phase_id", &"")) in [
				&"boarding", &"reboard", &"reboarded", &"takeoff", &"ascent",
				&"orbit_return", &"completed",
			]:
		# Once the Host advances beyond the on-foot survey handoff, its physical
		# phase becomes the clearer status source. The manifest remains available
		# from production without pinning every later row to RETURN MANIFEST.
		_last_result = {}
	var source_generation := maxi(_generation, int(production_snapshot.get("generation", 0)))
	source_generation = maxi(source_generation, int(host_snapshot.get("generation", 0)))
	source_generation = maxi(source_generation, int(host_snapshot.get("attachment_generation", 0)))
	var completed_return := _completed_return_is_current(
		production_snapshot, host_snapshot
	)
	var loss_reason := _source_loss_reason(host_snapshot)
	if not loss_reason.is_empty():
		if not completed_return:
			return _clear_view(loss_reason, source_generation, reduced_motion)
	var manifest_snapshot := _production.call(
		&"get_planetary_relay_survey_return_manifest_snapshot"
	) as Dictionary
	# Runtime ownership retires atomically in the same late tick that publishes
	# its authenticated completion handback. Let the presenter map that exact
	# terminal phase, then retain the truthful detached flag in the final view.
	var presentation_host := host_snapshot
	if completed_return:
		presentation_host = host_snapshot.duplicate(true)
		presentation_host["attached"] = true
	var aggregate := {
		"generation": source_generation,
		"binding": production_snapshot,
		"host": presentation_host,
		"return_manifest": manifest_snapshot,
		"last_result": _last_result.duplicate(true),
	}
	var next: Dictionary = _presenter.call(&"present", aggregate, reduced_motion)
	if bool(next.get("accepted", false)):
		next = _with_return_loop_semantics(
			next, production_snapshot, host_snapshot, manifest_snapshot,
			_last_result
		)
		if completed_return:
			next["attached"] = false
			next["completion_observed"] = true
		if next == _view:
			return {"accepted": true, "reason": &"duplicate", "generation": _generation, "presentation_only": true}
		_view = next.duplicate(true)
		presentation_changed.emit(_view.duplicate(true))
	return next


## Adds one steady text-and-shape-independent contract to the existing HUD row.
## Every cue is derived from the already-authoritative Host/production
## snapshots; the dictionary is deliberately incapable of advancing travel.
func _with_return_loop_semantics(
		view: Dictionary, production_snapshot: Dictionary,
		host_snapshot: Dictionary, manifest_snapshot: Dictionary,
		receipt: Dictionary
	) -> Dictionary:
	var status := _return_loop_status(
		production_snapshot, host_snapshot, manifest_snapshot, receipt
	)
	if status.is_empty():
		return view
	var result := view.duplicate(true)
	var action := {
		"id": status.get("action_id", &"return_status"),
		"label": status.get("next_action", "CHECK RETURN STATUS"),
		"focusable": true,
		"input_authority": false,
		"travel_authority": false,
		"boarding_authority": false,
		"reward_authority": false,
	}.duplicate(true)
	result["next_action"] = action
	result["return_status"] = {
		"stage": status.get("stage", &""),
		"stage_label": status.get("stage_label", ""),
		"step": status.get("step", 0),
		"step_count": 6,
		"next_action": status.get("next_action", ""),
		"recovery": status.get("recovery", ""),
		"steady": true,
		"color_independent": true,
		"reduced_flash_safe": true,
		"snapshot_source": &"authoritative_host_and_production_snapshots",
		"input_authority": false,
		"travel_authority": false,
		"boarding_authority": false,
		"reward_authority": false,
	}.duplicate(true)
	var lines := PackedStringArray()
	for line: String in str(result.get("text", "")).split("\n"):
		if not line.begins_with("NEXT ACTION  //"):
			lines.append(line)
	lines.append("RETURN STEP  //  %d OF 6  //  %s" % [
		int(status.get("step", 0)), str(status.get("stage_label", "")),
	])
	lines.append("NEXT ACTION  //  " + str(status.get("next_action", "")))
	lines.append("RECOVERY  //  " + str(status.get("recovery", "")))
	result["text"] = "\n".join(lines)
	result["color_independent"] = true
	result["reduced_flash_safe"] = true
	result["flash_requested"] = false
	result["input_authority"] = false
	result["travel_authority"] = false
	result["boarding_authority"] = false
	result["reward_authority"] = false
	return result.duplicate(true)


func _return_loop_status(
		production_snapshot: Dictionary, host_snapshot: Dictionary,
		manifest_snapshot: Dictionary, receipt: Dictionary
	) -> Dictionary:
	var phase := StringName(host_snapshot.get("phase_id", &""))
	var planetary := production_snapshot.get("planetary_surface", {}) as Dictionary
	var relay := planetary.get("relay_survey_presentation", {}) as Dictionary
	var survey_state := StringName(relay.get("state", &""))
	var manifest_ready := int(manifest_snapshot.get("issued_generation", -1)) >= 1 \
		or (bool(receipt.get("accepted", false)) \
			and StringName(receipt.get("reason", &"")) == &"return_manifest_ready")
	if phase in [&"surface_outbound", &"on_foot"] \
			and (survey_state in [&"awaiting_reward", &"completed"] \
				or manifest_ready):
		return _status(
			&"survey_complete", "SURVEY COMPLETE", 1, &"return_to_ship",
			"RETURN TO YOUR SHIP", "FOLLOW THE STATIC RETURN ROUTE"
		)
	if phase in [&"boarding", &"reboard", &"reboarded"]:
		return _status(
			&"reboard", "REBOARD", 2,
			&"takeoff" if phase == &"reboarded" else &"complete_reboard",
			"TAKE OFF" if phase == &"reboarded" else "COMPLETE REBOARD",
			"RE-ENTER THE LANDING PAD BOARDING AREA IF INTERRUPTED"
		)
	if phase == &"takeoff":
		return _status(
			&"takeoff", "TAKEOFF", 3, &"begin_ascent", "BEGIN ASCENT",
			"REMAIN SEATED WHILE TAKEOFF STATUS RECOVERS"
		)
	if phase == &"ascent":
		return _status(
			&"ascent", "ASCENT", 4, &"reach_orbit", "REACH ORBIT",
			"CONTINUE THE STEADY CLIMB IF GUIDANCE IS INTERRUPTED"
		)
	if phase == &"orbit_return":
		return _status(
			&"orbit", "ORBIT", 5, &"complete_handoff",
			"COMPLETE RETURN HANDOFF",
			"HOLD ORBIT WHILE THE MUDDS HANDOFF RECOVERS"
		)
	if phase == &"completed":
		return _status(
			&"mudds_return", "MUDDS RETURN", 6, &"return_to_mudds",
			"RETURN TO MUDDS SHIPYARDS",
			"MUDDS SHIPYARDS REMAINS THE MANIFEST DESTINATION"
		)
	return {}


func _status(
		stage: StringName, stage_label: String, step: int,
		action_id: StringName, next_action: String, recovery: String
	) -> Dictionary:
	return {
		"stage": stage,
		"stage_label": stage_label,
		"step": step,
		"action_id": action_id,
		"next_action": next_action,
		"recovery": recovery,
	}.duplicate(true)


func _source_loss_reason(host_snapshot: Dictionary) -> StringName:
	if not bool(host_snapshot.get("attached", false)):
		return &"session_detached"
	var phase := StringName(host_snapshot.get("phase_id", &""))
	if phase == &"failed" or not StringName(
		host_snapshot.get("terminal_reason", &"")
	).is_empty():
		return &"session_lost"
	var identities := host_snapshot.get("identities", {}) as Dictionary
	if identities.has("player_instance_id") \
			and int(identities.get("player_instance_id", 0)) < 1:
		return &"actor_lost"
	if identities.has("ship_instance_id") \
			and int(identities.get("ship_instance_id", 0)) < 1:
		return &"craft_lost"
	return &""


func _completed_return_is_current(
		production_snapshot: Dictionary, host_snapshot: Dictionary
	) -> bool:
	if StringName(host_snapshot.get("phase_id", &"")) != &"completed" \
			or bool(host_snapshot.get("attached", true)) \
			or StringName(production_snapshot.get("state_id", &"")) \
				!= &"handoff_pending" \
			or not bool(production_snapshot.get("completion_handback_pending", false)):
		return false
	var receipt := production_snapshot.get("completion_handback", {}) as Dictionary
	if StringName(receipt.get("reason", &"")) != &"runtime_ownership_returned" \
			or int(receipt.get("generation", -1)) \
				!= int(host_snapshot.get("generation", -2)) \
			or int(receipt.get("current_attachment_generation", -1)) \
				!= int(host_snapshot.get("attachment_generation", -2)):
		return false
	var identities := host_snapshot.get("identities", {}) as Dictionary
	if identities.has("player_instance_id") \
			and int(receipt.get("player_instance_id", 0)) \
				!= int(identities.get("player_instance_id", -1)):
		return false
	if identities.has("ship_instance_id") \
			and int(receipt.get("ship_instance_id", 0)) \
				!= int(identities.get("ship_instance_id", -1)):
		return false
	return true


func _clear_view(
		reason: StringName, source_generation: int, reduced_motion: bool
	) -> Dictionary:
	_presenter.call(&"detach")
	_last_result = {}
	var next := {
		"accepted": true,
		"attached": false,
		"state": &"rejected",
		"text": "\n".join(PackedStringArray([
			"EMBER RETURN  //  STATUS UNAVAILABLE",
			"RECOVERY  //  WAIT FOR CURRENT ACTOR AND SESSION STATUS",
			"REASON  //  " + str(reason).replace("_", " ").to_upper(),
			"TRANSITION  //  STATIC" if reduced_motion else "TRANSITION  //  STANDARD",
		])),
		"generation": maxi(0, source_generation),
		"reduced_motion": reduced_motion,
		"focusable": true,
		"color_independent": true,
		"reduced_flash_safe": true,
		"flash_requested": false,
		"route_guidance": {"available": false, "navigation_authority": false},
		"next_action": {},
		"return_status": {},
		"presentation_only": true,
		"input_authority": false,
		"movement_authority": false,
		"landing_authority": false,
		"boarding_authority": false,
		"session_authority": false,
		"travel_authority": false,
		"reward_authority": false,
	}.duplicate(true)
	if next != _view:
		_view = next.duplicate(true)
		presentation_changed.emit(_view.duplicate(true))
	return next


func _receipt_matches_current_source(receipt: Dictionary) -> bool:
	if not is_instance_valid(_host):
		return false
	var host_snapshot := _host.call(&"get_snapshot") as Dictionary
	var expected_attachment := int(
		host_snapshot.get("attachment_generation", -1)
	)
	if expected_attachment < 0:
		return false
	var receipt_attachment := -1
	var manifest := receipt.get("manifest", {}) as Dictionary
	if manifest.has("attachment_generation"):
		receipt_attachment = int(manifest.get("attachment_generation", -1))
	elif receipt.has("current_attachment_generation"):
		receipt_attachment = int(
			receipt.get("current_attachment_generation", -1)
		)
	elif receipt.has("attachment_generation"):
		receipt_attachment = int(receipt.get("attachment_generation", -1))
	return receipt_attachment < 0 or receipt_attachment == expected_attachment


func _last_result_is_return_manifest() -> bool:
	return bool(_last_result.get("accepted", false)) \
		and StringName(_last_result.get("reason", &"")) == &"return_manifest_ready"


func _reject(reason: StringName) -> Dictionary:
	return {"accepted": false, "reason": reason, "generation": _generation, "presentation_only": true}
