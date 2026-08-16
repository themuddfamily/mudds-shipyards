class_name CaptionPresentationService
extends RefCounted

## Deterministic, presentation-only caption queue.
##
## Time advances exclusively through caller-supplied physics delta. The active
## caption is non-preemptive; pending captions are ordered by descending
## priority and FIFO sequence within equal priority. At exact capacity, a new
## caption replaces only the newest lowest-priority pending caption and only if
## its priority is strictly higher. The active caption is never an overflow
## victim.

signal state_committed(reason: StringName, snapshot: Dictionary)

const SCHEMA_VERSION := 1
const SERVICE_ID: StringName = &"caption-presentation-service"
const MAX_STORED_CAPTIONS := 8
const MAX_DEDUPE_ID_COUNT := 1024
const MAX_SAFE_SEQUENCE := 9_007_199_254_740_991
const TIME_EPSILON := 0.000000001

var _active: Dictionary = {}
var _pending: Array[Dictionary] = []
var _accepted_ids: Dictionary = {}
var _next_sequence := 1
var _generation := 0
var _revision := 0
var _captions_enabled := true
var _reduced_flash := false
var _accepted_event_count := 0
var _expired_event_count := 0
var _replaced_event_count := 0
var _reset_count := 0
var _signal_dispatch_active := false


func enqueue(event: CaptionPresentationEvent) -> Dictionary:
	if _signal_dispatch_active:
		return _result(false, &"reentrant_call")
	if event == null:
		return _result(false, &"invalid_event", {"validation_errors": PackedStringArray(["event is null"])})
	var validation_errors := event.get_validation_errors()
	if not validation_errors.is_empty():
		return _result(false, &"invalid_event", {"validation_errors": validation_errors})
	var stable_id := event.stable_id
	if _accepted_ids.has(stable_id):
		return _result(false, &"duplicate_event_id", {"stable_id": stable_id})
	if _accepted_ids.size() >= MAX_DEDUPE_ID_COUNT:
		return _result(false, &"dedupe_ledger_full", {"stable_id": stable_id})
	if _next_sequence <= 0 or _next_sequence > MAX_SAFE_SEQUENCE:
		return _result(false, &"sequence_exhausted", {"stable_id": stable_id})

	var replacement_index := -1
	var replaced_id: StringName = &""
	if _stored_count() >= MAX_STORED_CAPTIONS:
		replacement_index = _replacement_index_for(event.priority)
		if replacement_index < 0:
			return _result(false, &"queue_full", {"stable_id": stable_id})
		replaced_id = StringName(_pending[replacement_index].stable_id)

	var record := _record_from_event(event, _next_sequence)
	_next_sequence += 1
	_accepted_ids[stable_id] = int(record.sequence)
	_accepted_event_count += 1
	var reason: StringName = &"queued"
	if _active.is_empty():
		_active = record
		reason = &"presenting"
	elif replacement_index >= 0:
		_pending.remove_at(replacement_index)
		_pending.append(record)
		_sort_pending()
		_replaced_event_count += 1
		reason = &"replaced_lower_priority"
	else:
		_pending.append(record)
		_sort_pending()
	_commit(reason)
	return _result(true, reason, {
		"stable_id": stable_id,
		"replaced_stable_id": replaced_id,
	})


## Advances only against a finite, non-negative caller physics delta. Zero is a
## successful freeze: no remaining time, revision, counters or signal changes.
## A large delta may expire several queued captions deterministically.
func advance_physics(delta: float) -> Dictionary:
	if _signal_dispatch_active:
		return _result(false, &"reentrant_call")
	if not is_finite(delta) or delta < 0.0:
		return _result(false, &"invalid_delta")
	if delta == 0.0:
		return _result(true, &"no_delta")
	if _active.is_empty():
		return _result(true, &"idle")

	var remaining_delta := delta
	var expired_ids := PackedStringArray()
	while not _active.is_empty() and remaining_delta > 0.0:
		var remaining := float(_active.remaining_physics_seconds)
		if remaining_delta < remaining - TIME_EPSILON:
			_active["remaining_physics_seconds"] = remaining - remaining_delta
			remaining_delta = 0.0
		else:
			remaining_delta = maxf(0.0, remaining_delta - remaining)
			expired_ids.append(str(_active.stable_id))
			_expired_event_count += 1
			_promote_next()
	_commit(&"expired" if not expired_ids.is_empty() else &"advanced")
	return _result(true, &"expired" if not expired_ids.is_empty() else &"advanced", {
		"expired_stable_ids": expired_ids,
		"unused_delta_seconds": _rounded_time(remaining_delta),
	})


## Accessibility flags are presentation hints only. Disabling captions hides
## the current presentation but does not pause or replay its physics lifetime.
func set_presentation_flags(captions_enabled: bool, reduced_flash: bool) -> Dictionary:
	if _signal_dispatch_active:
		return _result(false, &"reentrant_call")
	if _captions_enabled == captions_enabled and _reduced_flash == reduced_flash:
		return _result(true, &"unchanged")
	_captions_enabled = captions_enabled
	_reduced_flash = reduced_flash
	_commit(&"presentation_flags_changed")
	return _result(true, &"presentation_flags_changed")


## Starts a new presentation generation. Accessibility flags deliberately
## survive; queued content and the bounded replay ledger do not.
func reset() -> Dictionary:
	if _signal_dispatch_active:
		return _result(false, &"reentrant_call")
	_generation += 1
	_active.clear()
	_pending.clear()
	_accepted_ids.clear()
	_next_sequence = 1
	_accepted_event_count = 0
	_expired_event_count = 0
	_replaced_event_count = 0
	_reset_count += 1
	_commit(&"reset")
	return _result(true, &"reset")


## Full deep-copy state for tests, diagnostics and lifecycle owners. Mutating a
## returned nested event or queue array cannot mutate the live service.
func get_state_snapshot() -> Dictionary:
	var pending_snapshots: Array[Dictionary] = []
	for record in _pending:
		pending_snapshots.append(_public_record(record))
	return {
		"schema_version": SCHEMA_VERSION,
		"service_id": SERVICE_ID,
		"generation": _generation,
		"revision": _revision,
		"captions_enabled": _captions_enabled,
		"reduced_flash": _reduced_flash,
		"active_caption": _public_record(_active),
		"pending_captions": pending_snapshots,
		"stored_caption_count": _stored_count(),
		"pending_caption_count": _pending.size(),
		"dedupe_id_count": _accepted_ids.size(),
		"accepted_event_count": _accepted_event_count,
		"expired_event_count": _expired_event_count,
		"replaced_event_count": _replaced_event_count,
		"reset_count": _reset_count,
	}.duplicate(true)


## Detached consumer-facing view. No Node, Resource, Callable or internal
## collection escapes through this boundary.
func get_presentation_snapshot() -> Dictionary:
	var visible := _captions_enabled and not _active.is_empty()
	return {
		"schema_version": SCHEMA_VERSION,
		"service_id": SERVICE_ID,
		"generation": _generation,
		"revision": _revision,
		"visible": visible,
		"captions_enabled": _captions_enabled,
		"reduced_flash": _reduced_flash,
		"transition_policy": &"steady_no_flash" if _reduced_flash else &"consumer_standard",
		"caption": _public_record(_active) if visible else {},
	}.duplicate(true)


func audit() -> Dictionary:
	var errors := PackedStringArray()
	if _stored_count() > MAX_STORED_CAPTIONS:
		errors.append("stored caption capacity exceeded")
	if _accepted_ids.size() > MAX_DEDUPE_ID_COUNT:
		errors.append("dedupe ledger capacity exceeded")
	if _next_sequence <= 0 or _next_sequence > MAX_SAFE_SEQUENCE + 1:
		errors.append("sequence cursor is outside its frozen bound")
	var stored_ids: Dictionary = {}
	if not _active.is_empty():
		_audit_record(_active, true, stored_ids, errors)
	for index in _pending.size():
		var record := _pending[index]
		_audit_record(record, false, stored_ids, errors)
		if index > 0 and _record_precedes(_pending[index], _pending[index - 1]):
			errors.append("pending priority/FIFO order drifted")
	var accepted_ids := PackedStringArray()
	for stable_id: StringName in _accepted_ids:
		accepted_ids.append(str(stable_id))
	accepted_ids.sort()
	return {
		"schema_version": SCHEMA_VERSION,
		"service_id": SERVICE_ID,
		"valid": errors.is_empty(),
		"errors": errors,
		"state": get_state_snapshot(),
		"accepted_ids": accepted_ids,
		"limits": {
			"maximum_stored_captions": MAX_STORED_CAPTIONS,
			"maximum_dedupe_ids": MAX_DEDUPE_ID_COUNT,
			"maximum_id_characters": CaptionPresentationEvent.MAX_ID_LENGTH,
			"maximum_speaker_characters": CaptionPresentationEvent.MAX_SPEAKER_LENGTH,
			"maximum_text_characters": CaptionPresentationEvent.MAX_TEXT_LENGTH,
			"minimum_duration_physics_seconds": CaptionPresentationEvent.MIN_DURATION_PHYSICS_SECONDS,
			"maximum_duration_physics_seconds": CaptionPresentationEvent.MAX_DURATION_PHYSICS_SECONDS,
			"minimum_priority": CaptionPresentationEvent.MIN_PRIORITY,
			"maximum_priority": CaptionPresentationEvent.MAX_PRIORITY,
		},
		"policies": {
			"active_preemption": false,
			"pending_order": &"priority_descending_then_fifo_sequence",
			"overflow": &"strictly_higher_priority_replaces_newest_lowest_pending",
			"dedupe": &"accepted_ids_retained_until_reset_or_ledger_full",
			"time_source": &"caller_supplied_physics_delta_only",
			"zero_delta_freezes": true,
			"disabled_caption_time_continues": true,
			"snapshots": &"deep_detached_scalar_data",
			"signals": &"post_commit_with_reentrant_mutation_rejected",
		},
		"presentation_only": true,
		"uses_wall_clock": false,
		"audio_authority": false,
		"gameplay_authority": false,
		"activity_authority": false,
		"reward_authority": false,
		"ship_authority": false,
		"berth_authority": false,
		"save_authority": false,
		"network_authority": false,
	}.duplicate(true)


func _record_from_event(event: CaptionPresentationEvent, sequence: int) -> Dictionary:
	var record := event.to_dictionary()
	record["sequence"] = sequence
	record["remaining_physics_seconds"] = event.duration_physics_seconds
	return record.duplicate(true)


func _replacement_index_for(incoming_priority: int) -> int:
	if _pending.is_empty():
		return -1
	var worst_index := 0
	for index in range(1, _pending.size()):
		var candidate := _pending[index]
		var worst := _pending[worst_index]
		if (
			int(candidate.priority) < int(worst.priority)
			or (
				int(candidate.priority) == int(worst.priority)
				and int(candidate.sequence) > int(worst.sequence)
			)
		):
			worst_index = index
	return worst_index if incoming_priority > int(_pending[worst_index].priority) else -1


func _sort_pending() -> void:
	_pending.sort_custom(_record_precedes)


func _record_precedes(a: Dictionary, b: Dictionary) -> bool:
	if int(a.priority) != int(b.priority):
		return int(a.priority) > int(b.priority)
	return int(a.sequence) < int(b.sequence)


func _promote_next() -> void:
	_active = {}
	if not _pending.is_empty():
		_active = _pending.pop_front()


func _stored_count() -> int:
	return _pending.size() + (0 if _active.is_empty() else 1)


func _public_record(record: Dictionary) -> Dictionary:
	if record.is_empty():
		return {}
	var snapshot := record.duplicate(true)
	snapshot["duration_physics_seconds"] = _rounded_time(float(snapshot.duration_physics_seconds))
	snapshot["remaining_physics_seconds"] = _rounded_time(float(snapshot.remaining_physics_seconds))
	return snapshot


func _audit_record(
		record: Dictionary,
		active: bool,
		stored_ids: Dictionary,
		errors: PackedStringArray
	) -> void:
	var event := CaptionPresentationEvent.new(
		StringName(record.get("stable_id", &"")),
		int(record.get("category", -1)) as CaptionPresentationEvent.Category,
		str(record.get("speaker", "")),
		str(record.get("text", "")),
		float(record.get("duration_physics_seconds", -1.0)),
		int(record.get("priority", -1))
	)
	if not event.is_valid():
		errors.append("stored event validation drifted: %s" % str(event.stable_id))
	if stored_ids.has(event.stable_id):
		errors.append("duplicate stored event id: %s" % str(event.stable_id))
	stored_ids[event.stable_id] = true
	if not _accepted_ids.has(event.stable_id):
		errors.append("stored event is missing from replay ledger: %s" % str(event.stable_id))
	if int(record.get("sequence", 0)) <= 0:
		errors.append("stored event has invalid sequence: %s" % str(event.stable_id))
	var remaining := float(record.get("remaining_physics_seconds", -1.0))
	if (
		not is_finite(remaining)
		or remaining <= 0.0
		or remaining > event.duration_physics_seconds + TIME_EPSILON
	):
		errors.append("stored event has invalid remaining duration: %s" % str(event.stable_id))
	if not active and not is_equal_approx(remaining, event.duration_physics_seconds):
		errors.append("pending event timing advanced before presentation: %s" % str(event.stable_id))


func _commit(reason: StringName) -> void:
	_revision += 1
	var snapshot := get_state_snapshot()
	_signal_dispatch_active = true
	state_committed.emit(reason, snapshot.duplicate(true))
	_signal_dispatch_active = false


func _result(accepted: bool, reason: StringName, extra: Dictionary = {}) -> Dictionary:
	var result := {
		"accepted": accepted,
		"reason": reason,
		"generation": _generation,
		"revision": _revision,
	}
	for key: Variant in extra:
		result[key] = extra[key]
	return result.duplicate(true)


static func _rounded_time(value: float) -> float:
	return snappedf(value, TIME_EPSILON)
