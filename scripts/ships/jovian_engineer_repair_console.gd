class_name JovianEngineerRepairConsole
extends RefCounted

## Presentation-only lifecycle consumer for the physical Jovian engineer panel.
## Repair, component, seat, and network authority remain with the supplied
## detached snapshot. This object only fences and formats that snapshot.

const MAX_SAFE_GENERATION := 9_007_199_254_740_991
const MAX_SAFE_SEQUENCE := 9_007_199_254_740_991

var _readout: Label3D
var _attached := false
var _generation := 0
var _last_sequence := -1
var _last_state: StringName = &"idle"
var _last_snapshot: Dictionary = {}
var _recovery_status: Dictionary = {}


func bind(readout: Label3D, expected_generation: int = 0) -> Dictionary:
	if readout == null or not is_instance_valid(readout):
		return _result(false, &"readout_unavailable")
	if expected_generation != _generation:
		return _result(false, &"stale_generation")
	_readout = readout
	_attached = true
	_clear_presented_state()
	_render_idle()
	return _result(true, &"bound")


func present_snapshot(envelope: Dictionary) -> Dictionary:
	if not _attached or _readout == null or not is_instance_valid(_readout):
		return _result(false, &"not_attached")
	var decoded := _decode(envelope)
	if not bool(decoded.get("accepted", false)):
		var decode_reason := StringName(decoded.get("reason", &"invalid_snapshot"))
		_present_stale_receipt_recovery(decode_reason)
		return _result(false, decode_reason)
	var sequence := int(decoded.get("sequence", -1))
	if sequence <= _last_sequence:
		var sequence_reason := (
			&"duplicate_sequence" if sequence == _last_sequence else &"stale_sequence"
		)
		_present_stale_receipt_recovery(sequence_reason)
		return _result(false, sequence_reason)
	_last_sequence = sequence
	_last_state = StringName(decoded.get("state", &"idle"))
	_last_snapshot = envelope.duplicate(true)
	_recovery_status.clear()
	_readout.text = _format_text(decoded)
	return _result(true, &"snapshot_presented")


## Starts a clean presentation lifecycle when the role is released, handed
## off, or the pooled craft is reused. It cannot mutate the supplied authority.
func begin_generation(generation: int) -> Dictionary:
	if generation <= _generation or generation > MAX_SAFE_GENERATION:
		return _result(false, &"stale_generation")
	_generation = generation
	_clear_presented_state()
	if _attached and _readout != null and is_instance_valid(_readout):
		_render_idle()
	return _result(true, &"generation_started")


func detach() -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	_attached = false
	_generation += 1
	_clear_presented_state()
	if _readout != null and is_instance_valid(_readout):
		_render_idle()
	_readout = null
	return _result(true, &"detached")


func get_snapshot() -> Dictionary:
	return {
		"attached": _attached,
		"generation": _generation,
		"last_sequence": _last_sequence,
		"state": _last_state,
		"text": _readout.text if _readout != null and is_instance_valid(_readout) else "",
		"last_snapshot": _last_snapshot.duplicate(true),
		"recovery_status": _recovery_status.duplicate(true),
		"authority": {
			"repair": false,
			"components": false,
			"seats": false,
			"network": false,
			"presentation": true,
		},
	}.duplicate(true)


func _decode(envelope: Dictionary) -> Dictionary:
	var raw_generation: Variant = envelope.get("generation", -1)
	var raw_sequence: Variant = envelope.get("sequence", -1)
	var raw_snapshot: Variant = envelope.get("repair_snapshot", null)
	if not raw_generation is int or int(raw_generation) != _generation:
		return _result(false, &"stale_generation")
	if not raw_sequence is int or int(raw_sequence) < 0 \
			or int(raw_sequence) > MAX_SAFE_SEQUENCE:
		return _result(false, &"invalid_sequence")
	if not raw_snapshot is Dictionary:
		return _result(false, &"invalid_repair_snapshot")
	var network_snapshot := raw_snapshot as Dictionary
	var repair_variant: Variant = network_snapshot.get("repair", null)
	var owner_variant: Variant = network_snapshot.get("owner", null)
	if not repair_variant is Dictionary or not owner_variant is Dictionary \
			or not bool(network_snapshot.get("presentation_only", false)):
		return _result(false, &"invalid_repair_snapshot")
	var repair := repair_variant as Dictionary
	var owner := owner_variant as Dictionary
	var authority_status := StringName(repair.get("status", &"idle"))
	var state: StringName
	match authority_status:
		&"repairing":
			state = &"repairing"
		&"completed":
			state = &"completed"
		&"interrupted":
			state = &"aborted"
		&"idle":
			state = &"idle"
		_:
			return _result(false, &"invalid_repair_state")
	var raw_progress: Variant = repair.get("progress", 0.0)
	if not (raw_progress is int or raw_progress is float) \
			or not is_finite(float(raw_progress)) \
			or float(raw_progress) < 0.0 or float(raw_progress) > 1.0:
		return _result(false, &"invalid_progress")
	var component_id := StringName(repair.get("component_id", &""))
	var component_generation := int(repair.get("component_generation", 0))
	if state != &"idle" and (component_id.is_empty() or component_generation <= 0):
		return _result(false, &"invalid_component_fence")
	if not owner.is_empty() and (
		StringName(owner.get("seat_id", &"")) != &"passenger_port_01"
		or component_id.is_empty()
	):
		return _result(false, &"owner_mismatch")
	return {
		"accepted": true,
		"sequence": int(raw_sequence),
		"state": state,
		"component_id": component_id,
		"component_generation": component_generation,
		"progress": float(raw_progress),
		"reason": StringName(repair.get("reason", &"")),
		"cooldown_remaining": maxf(float(repair.get("cooldown_remaining", 0.0)), 0.0),
	}


func _format_text(decoded: Dictionary) -> String:
	var state := StringName(decoded.get("state", &"idle"))
	var component := _readable_id(StringName(decoded.get("component_id", &"")))
	var percent := int(round(clampf(float(decoded.get("progress", 0.0)), 0.0, 1.0) * 100.0))
	match state:
		&"repairing":
			return "REPAIRING // %s\nPROGRESS // %d%%" % [component, percent]
		&"completed":
			var cooldown := float(decoded.get("cooldown_remaining", 0.0))
			return "COMPLETED // %s\nPROGRESS // 100%%%s" % [
				component,
				" // %.1fs" % cooldown if cooldown > 0.0 else "",
			]
		&"aborted":
			return "ABORTED // %s\n%s // %d%%" % [
				_readable_id(StringName(decoded.get("reason", &"interrupted"))),
				component,
				percent,
			]
		_:
			return "IDLE // REPAIR READY"


func _readable_id(value: StringName) -> String:
	if value.is_empty():
		return "NO TARGET"
	return String(value).replace("_", " ").to_upper()


func _render_idle() -> void:
	_readout.text = "IDLE // REPAIR READY"


func _clear_presented_state() -> void:
	_last_sequence = -1
	_last_state = &"idle"
	_last_snapshot.clear()
	_recovery_status.clear()


## Publishes a controller-readable recovery cue without accepting the stale
## receipt, replacing the current readout, or gaining input/repair authority.
func _present_stale_receipt_recovery(reason: StringName) -> void:
	if reason not in [&"stale_generation", &"stale_sequence"]:
		return
	_recovery_status = {
		"status": &"stale_receipt",
		"reason": reason,
		"action": &"request_fresh_station_snapshot",
		"expected_generation": _generation,
		"after_sequence": _last_sequence,
		"retryable": true,
		"input_authority": false,
		"repair_authority": false,
	}.duplicate(true)


func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {
		"accepted": accepted,
		"reason": reason,
		"generation": _generation,
	}.duplicate(true)
