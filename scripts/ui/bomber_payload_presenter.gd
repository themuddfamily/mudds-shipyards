class_name BomberPayloadPresenter
extends RefCounted

## Presentation-only bomber payload status. The caller owns payload authority,
## cooldown timing, and release validation; this presenter only formats a
## detached snapshot and returns a release intent.

const SCHEMA_VERSION := 1
const MAX_SAFE_INTEGER := 9_007_199_254_740_991

var _attached := false
var _generation := 0
var _source_generation := -1
var _source_release_sequence := -1
var _source_request_sequence := -1
var _source_phase_rank := -1
var _source_progress_sequence := -1
var _source_elapsed_lifetime := -1.0
var _source_projectile_count := -1
var _source_ammo := -1
var _source_cooldown := -1.0
var _snapshot: Dictionary = {}
var _receipt: Dictionary = {}


func attach() -> Dictionary:
	_attached = true
	_generation += 1
	_clear_source()
	return get_snapshot()


func detach() -> Dictionary:
	_attached = false
	_generation += 1
	_clear_source()
	return get_snapshot()


func present_snapshot(snapshot: Dictionary) -> Dictionary:
	if not _attached:
		return _reject(&"detached")
	if not snapshot.has("generation") or not snapshot.generation is int \
			or int(snapshot.generation) < 0:
		return _reject(&"invalid_generation")
	var source_generation := int(snapshot.generation)
	if source_generation < _source_generation:
		return _reject(&"stale_generation")
	var parsed := _parse_receipt(snapshot, source_generation)
	if not bool(parsed.get("accepted", false)):
		return _reject(StringName(parsed.get("reason", &"invalid_receipt")))
	if source_generation == _source_generation:
		var fence_reason := _fence_reason(parsed, snapshot)
		if not fence_reason.is_empty():
			return _reject(fence_reason)
	_snapshot = snapshot.duplicate(true)
	_receipt = parsed.duplicate(true)
	_commit_source_cursor(source_generation, parsed, snapshot)
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
	var ammo := maxi(0, int(_snapshot.get("ammo", _snapshot.get("ammunition_remaining", 0))))
	var cooldown := maxf(0.0, float(_snapshot.get("cooldown_remaining", 0.0)))
	var terminal := bool(_snapshot.get("terminal", false))
	var denied_reason := StringName(str(_snapshot.get("denied_reason", &"")))
	var payload_phase := StringName(_receipt.get("payload_phase", &"armed"))
	var projectile_count := maxi(0, int(_receipt.get("projectile_count", 0)))
	var state: StringName = &"inactive"
	var marker := "[OFFLINE]"
	var message := "BOMBER PAYLOAD UNAVAILABLE"
	var reason: StringName = denied_reason
	var upstream_allowed := bool(_snapshot.get("release_allowed", true))
	var release_allowed := active and not terminal and denied_reason.is_empty() \
			and ammo > 0 and cooldown <= 0.0 and upstream_allowed
	if terminal:
		state = &"terminal"
		marker = "[ENDED]"
		message = "BOMBER PAYLOAD // SORTIE COMPLETE // NEXT // STAND BY"
	elif payload_phase == &"aborted":
		state = &"aborted"
		marker = "[ABORTED]"
		message = "BOMBER PAYLOAD // RELEASE ABORTED // NEXT // STAND BY"
		reason = &"release_aborted"
		release_allowed = false
	elif not active:
		state = &"inactive"
	elif not denied_reason.is_empty():
		state = &"denied"
		marker = "[DENIED]"
		message = "BOMBER PAYLOAD // %s // NEXT // CHECK PAYLOAD SYSTEM" % str(_snapshot.get("denied_message", denied_reason)).to_upper()
	elif payload_phase == &"impact":
		state = &"impact"
		marker = "[IMPACT]"
		message = _terminal_message("IMPACT CONFIRMED", ammo, cooldown, release_allowed)
	elif payload_phase == &"expiry":
		state = &"expired"
		marker = "[EXPIRED]"
		message = _terminal_message("PAYLOAD EXPIRED", ammo, cooldown, release_allowed)
	elif ammo <= 0:
		state = &"empty"
		marker = "[EMPTY]"
		if payload_phase == &"flying":
			message = "BOMBER PAYLOAD // BAY EMPTY // %s // NEXT // TRACK IMPACT" % _flight_text(projectile_count)
		else:
			message = "BOMBER PAYLOAD // NO PAYLOAD REMAINING // NEXT // NO FURTHER RELEASE AVAILABLE"
	elif cooldown > 0.0:
		state = &"cooldown"
		marker = "[IN FLIGHT]" if payload_phase == &"flying" else "[WAIT]"
		if payload_phase == &"flying":
			message = "BOMBER PAYLOAD // %s // NEXT // HOLD %.1f S TO RELEASE" % [_flight_text(projectile_count), cooldown]
		else:
			message = "BOMBER PAYLOAD // REARMING // NEXT // HOLD %.1f S TO RELEASE" % cooldown
	elif payload_phase == &"flying":
		state = &"in_flight"
		marker = "[IN FLIGHT]"
		message = "BOMBER PAYLOAD // %s // NEXT // %s" % [
			_flight_text(projectile_count),
			"RELEASE ANOTHER PAYLOAD" if release_allowed else "TRACK IMPACT",
		]
	elif payload_phase == &"released":
		state = &"released"
		marker = "[RELEASED]"
		message = "BOMBER PAYLOAD // RELEASE CONFIRMED // NEXT // TRACK PAYLOAD"
	else:
		state = &"ready"
		marker = "[ARMED]"
		message = "BOMBER PAYLOAD // ARMED // NEXT // RELEASE PAYLOAD"
	if not release_allowed and reason.is_empty():
		if cooldown > 0.0:
			reason = &"cooldown"
		elif ammo <= 0:
			reason = &"empty"
		elif not upstream_allowed:
			reason = &"payload_limit"
		else:
			reason = state
	var action_label := str(_snapshot.get("action_label", "RELEASE PAYLOAD"))
	var action_glyph := str(_snapshot.get("action_glyph", ""))
	if not action_glyph.is_empty():
		action_label = "[%s] %s" % [action_glyph, action_label]
	return {"schema_version": SCHEMA_VERSION, "attached": true, "generation": _generation, "source_generation": _source_generation, "source_release_sequence": maxi(0, _source_release_sequence), "state": state, "payload_phase": payload_phase, "marker": marker, "title": "BOMBER PAYLOAD", "message": message, "detail": "AMMO // %d" % ammo, "ammo": ammo, "cooldown_remaining": cooldown, "release_allowed": release_allowed, "reason": reason, "actions": [{"id": &"release_payload", "label": action_label}] if release_allowed else [], "reduced_motion": bool(_snapshot.get("reduced_motion", false)), "presentation_only": true, "input_authority": false}.duplicate(true)


func _parse_receipt(snapshot: Dictionary, generation: int) -> Dictionary:
	var receipt := {
		"accepted": true,
		"release_sequence": 0,
		"request_sequence": 0,
		"phase_rank": 0,
		"progress_sequence": 0,
		"elapsed_lifetime": 0.0,
		"projectile_count": 0,
		"payload_phase": &"armed",
	}
	var raw_projectiles: Variant = snapshot.get("projectiles", [])
	if not raw_projectiles is Array:
		return {"accepted": false, "reason": &"invalid_projectile_receipt"}
	for raw_projectile: Variant in raw_projectiles:
		if not raw_projectile is Dictionary:
			return {"accepted": false, "reason": &"invalid_projectile_receipt"}
		var projectile := raw_projectile as Dictionary
		var parsed_projectile := _parse_projectile(projectile, generation)
		if not bool(parsed_projectile.get("accepted", false)):
			return parsed_projectile
		receipt.projectile_count = int(receipt.projectile_count) + 1
		if int(parsed_projectile.release_sequence) > int(receipt.release_sequence) \
				or (int(parsed_projectile.release_sequence) == int(receipt.release_sequence) \
				and int(parsed_projectile.phase_rank) > int(receipt.phase_rank)):
			_copy_latest_receipt(receipt, parsed_projectile)
	var raw_records: Variant = snapshot.get("release_records", [])
	if not raw_records is Array:
		return {"accepted": false, "reason": &"invalid_release_receipt"}
	for raw_record: Variant in raw_records:
		if not raw_record is Dictionary:
			return {"accepted": false, "reason": &"invalid_release_receipt"}
		var record := raw_record as Dictionary
		var record_generation: Variant = record.get("generation", null)
		var release_sequence: Variant = record.get("release_sequence", null)
		var request_sequence: Variant = record.get("request_sequence", null)
		if not record_generation is int or int(record_generation) != generation \
				or not _valid_sequence(release_sequence) or not _valid_sequence(request_sequence):
			return {"accepted": false, "reason": &"invalid_release_receipt"}
		if int(release_sequence) > int(receipt.release_sequence):
			receipt.release_sequence = int(release_sequence)
			receipt.request_sequence = int(request_sequence)
			receipt.phase_rank = 1
			receipt.payload_phase = &"released"
	var adapter: Variant = snapshot.get("adapter", {})
	if not adapter is Dictionary:
		return {"accepted": false, "reason": &"invalid_adapter_receipt"}
	if not (adapter as Dictionary).is_empty():
		var adapter_generation: Variant = (adapter as Dictionary).get("generation", null)
		var resolved_sequence: Variant = (adapter as Dictionary).get("last_release_sequence", null)
		if not adapter_generation is int or int(adapter_generation) != generation \
				or not resolved_sequence is int or int(resolved_sequence) < 0 \
				or int(resolved_sequence) > MAX_SAFE_INTEGER:
			return {"accepted": false, "reason": &"invalid_adapter_receipt"}
		if int(resolved_sequence) > int(receipt.release_sequence):
			receipt.release_sequence = int(resolved_sequence)
			receipt.request_sequence = 0
			receipt.phase_rank = 3
			receipt.payload_phase = &"resolved"
		elif int(resolved_sequence) == int(receipt.release_sequence) \
				and int(resolved_sequence) > 0 and int(receipt.projectile_count) == 0:
			receipt.phase_rank = 3
			receipt.payload_phase = &"resolved"
	return receipt


func _parse_projectile(projectile: Dictionary, generation: int) -> Dictionary:
	var record: Variant = projectile.get("release_record", {})
	if not record is Dictionary or (record as Dictionary).is_empty():
		return {"accepted": false, "reason": &"invalid_release_receipt"}
	var release_record := record as Dictionary
	var projectile_generation: Variant = projectile.get("generation", projectile.get("projectile_generation", null))
	var record_generation: Variant = release_record.get("generation", null)
	var release_sequence: Variant = projectile.get("release_sequence", release_record.get("release_sequence", null))
	var request_sequence: Variant = projectile.get("request_sequence", release_record.get("request_sequence", null))
	if not projectile_generation is int or int(projectile_generation) != generation \
			or not record_generation is int or int(record_generation) != generation \
			or not _valid_sequence(release_sequence) or not _valid_sequence(request_sequence) \
			or int(release_record.get("release_sequence", -1)) != int(release_sequence) \
			or int(release_record.get("request_sequence", -1)) != int(request_sequence):
		return {"accepted": false, "reason": &"invalid_release_receipt"}
	var state := StringName(projectile.get("state", &"flying"))
	var terminal: Variant = projectile.get("terminal_intent", {})
	if not terminal is Dictionary:
		return {"accepted": false, "reason": &"invalid_terminal_receipt"}
	var phase_rank := 1
	var payload_phase: StringName = &"flying" if state == &"flying" else &"released"
	var progress_sequence := int(projectile.get("last_update_tick", 0))
	if progress_sequence < 0 or progress_sequence > MAX_SAFE_INTEGER:
		return {"accepted": false, "reason": &"invalid_projectile_receipt"}
	if state == &"terminal":
		phase_rank = 2
		if (terminal as Dictionary).is_empty():
			payload_phase = &"aborted"
		else:
			var terminal_receipt := terminal as Dictionary
			var terminal_sequence: Variant = terminal_receipt.get("terminal_sequence", null)
			if not _valid_sequence(terminal_sequence) \
					or int(terminal_receipt.get("generation", -1)) != generation \
					or int(terminal_receipt.get("release_sequence", -1)) != int(release_sequence) \
					or int(terminal_receipt.get("request_sequence", -1)) != int(request_sequence):
				return {"accepted": false, "reason": &"invalid_terminal_receipt"}
			progress_sequence = maxi(progress_sequence, int(terminal_sequence))
			var kind := StringName(terminal_receipt.get("kind", &""))
			if kind != &"impact" and kind != &"expiry":
				return {"accepted": false, "reason": &"invalid_terminal_receipt"}
			payload_phase = kind
	elif state != &"flying":
		return {"accepted": false, "reason": &"invalid_projectile_receipt"}
	var elapsed := float(projectile.get("elapsed_lifetime", 0.0))
	if not is_finite(elapsed) or elapsed < 0.0:
		return {"accepted": false, "reason": &"invalid_projectile_receipt"}
	return {
		"accepted": true,
		"release_sequence": int(release_sequence),
		"request_sequence": int(request_sequence),
		"phase_rank": phase_rank,
		"progress_sequence": progress_sequence,
		"elapsed_lifetime": elapsed,
		"payload_phase": payload_phase,
	}


func _fence_reason(receipt: Dictionary, snapshot: Dictionary) -> StringName:
	var release_sequence := int(receipt.release_sequence)
	var request_sequence := int(receipt.request_sequence)
	var phase_rank := int(receipt.phase_rank)
	var progress_sequence := int(receipt.progress_sequence)
	var elapsed_lifetime := float(receipt.elapsed_lifetime)
	var projectile_count := int(receipt.projectile_count)
	var ammo := maxi(0, int(snapshot.get("ammo", snapshot.get("ammunition_remaining", 0))))
	var cooldown := maxf(0.0, float(snapshot.get("cooldown_remaining", 0.0)))
	if release_sequence < _source_release_sequence:
		return &"stale_release_sequence"
	if release_sequence > _source_release_sequence:
		return &""
	if request_sequence > 0 and _source_request_sequence > 0 \
			and request_sequence != _source_request_sequence:
		return &"release_sequence_mismatch"
	if phase_rank < _source_phase_rank:
		return &"stale_phase_sequence"
	if phase_rank > _source_phase_rank:
		return &""
	if progress_sequence < _source_progress_sequence \
			or (progress_sequence == _source_progress_sequence \
			and elapsed_lifetime < _source_elapsed_lifetime):
		return &"stale_progress_sequence"
	if progress_sequence > _source_progress_sequence \
			or elapsed_lifetime > _source_elapsed_lifetime:
		return &""
	if projectile_count > _source_projectile_count or ammo > _source_ammo \
			or cooldown > _source_cooldown + 0.000001:
		return &"stale_authority_snapshot"
	if projectile_count < _source_projectile_count or ammo < _source_ammo \
			or cooldown < _source_cooldown - 0.000001:
		return &""
	return &"duplicate_receipt"


func _copy_latest_receipt(receipt: Dictionary, latest: Dictionary) -> void:
	receipt.release_sequence = int(latest.release_sequence)
	receipt.request_sequence = int(latest.request_sequence)
	receipt.phase_rank = int(latest.phase_rank)
	receipt.progress_sequence = int(latest.progress_sequence)
	receipt.elapsed_lifetime = float(latest.elapsed_lifetime)
	receipt.payload_phase = StringName(latest.payload_phase)


func _commit_source_cursor(generation: int, receipt: Dictionary, snapshot: Dictionary) -> void:
	_source_generation = generation
	_source_release_sequence = int(receipt.release_sequence)
	_source_request_sequence = int(receipt.request_sequence)
	_source_phase_rank = int(receipt.phase_rank)
	_source_progress_sequence = int(receipt.progress_sequence)
	_source_elapsed_lifetime = float(receipt.elapsed_lifetime)
	_source_projectile_count = int(receipt.projectile_count)
	_source_ammo = maxi(0, int(snapshot.get("ammo", snapshot.get("ammunition_remaining", 0))))
	_source_cooldown = maxf(0.0, float(snapshot.get("cooldown_remaining", 0.0)))


func _clear_source() -> void:
	_source_generation = -1
	_source_release_sequence = -1
	_source_request_sequence = -1
	_source_phase_rank = -1
	_source_progress_sequence = -1
	_source_elapsed_lifetime = -1.0
	_source_projectile_count = -1
	_source_ammo = -1
	_source_cooldown = -1.0
	_snapshot.clear()
	_receipt.clear()


func _terminal_message(result: String, ammo: int, cooldown: float, release_allowed: bool) -> String:
	if release_allowed:
		return "BOMBER PAYLOAD // %s // NEXT // RELEASE NEXT PAYLOAD" % result
	if cooldown > 0.0 and ammo > 0:
		return "BOMBER PAYLOAD // %s // NEXT // HOLD %.1f S TO RELEASE" % [result, cooldown]
	return "BOMBER PAYLOAD // %s // NEXT // NO FURTHER RELEASE AVAILABLE" % result


func _flight_text(projectile_count: int) -> String:
	if projectile_count == 1:
		return "PAYLOAD IN FLIGHT"
	return "%d PAYLOADS IN FLIGHT" % maxi(2, projectile_count)


func _valid_sequence(value: Variant) -> bool:
	return value is int and int(value) > 0 and int(value) <= MAX_SAFE_INTEGER


func _reject(reason: StringName) -> Dictionary:
	return {"accepted": false, "reason": reason, "generation": _generation, "presentation_only": true, "input_authority": false}
