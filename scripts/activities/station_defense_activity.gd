class_name StationDefenseActivity
extends RefCounted

## Generation-safe objective authority for a caller-driven station defense.
##
## Callers own physics time and submit destruction/damage observations using
## exact handles from StationDefenseContract. This class never spawns, resolves
## combat, applies damage, or touches protected objects.

signal activity_started(snapshot: Dictionary)
signal wave_started(snapshot: Dictionary)
signal hostile_destruction_accepted(snapshot: Dictionary, hostile_handle: Dictionary)
signal wave_completed(snapshot: Dictionary)
signal protected_asset_damage_accepted(
	snapshot: Dictionary,
	asset_handle: Dictionary,
	event_handle: Dictionary
)
signal protected_asset_destruction_accepted(
	snapshot: Dictionary,
	asset_handle: Dictionary,
	event_handle: Dictionary
)
signal protected_asset_renewed(
	snapshot: Dictionary,
	old_handle: Dictionary,
	new_handle: Dictionary
)
signal activity_completed(snapshot: Dictionary)
signal activity_failed(snapshot: Dictionary)
signal activity_aborted(snapshot: Dictionary)
signal activity_reset(snapshot: Dictionary)

enum State {
	IDLE,
	ACTIVE,
	COMPLETED,
	FAILED,
	ABORTED,
	TIMED_OUT,
}

const MAX_ACCEPTED_ASSET_EVENTS := 1024
const _STATE_IDS := ["idle", "active", "completed", "failed", "aborted", "timed_out"]
const _WAVE_MODE_IDS := ["ordered", "simultaneous"]

var _contract_snapshot: Dictionary = {}
var _configuration_errors := PackedStringArray()
var _state := State.IDLE
var _generation := 0
var _attached := true
var _current_wave_index := 0
var _wave_active := false
var _wave_delay_remaining_seconds := 0.0
var _elapsed_seconds := 0.0
var _failure_reason: StringName = &""
var _destroyed_hostile_keys: Dictionary = {}
var _accepted_asset_event_keys: Dictionary = {}
var _protected_asset_states: Array[Dictionary] = []
var _completion_emission_count := 0
var _mutation_active := false


func _init(contract: StationDefenseContract) -> void:
	if contract == null:
		_configuration_errors.append("a StationDefenseContract is required")
		return
	_contract_snapshot = contract.get_snapshot().duplicate(true)
	_configuration_errors = contract.get_configuration_errors().duplicate()
	for handle: Dictionary in _get_protected_handles():
		_protected_asset_states.append({
			"handle": handle.duplicate(true),
			"damage_event_count": 0,
			"destroyed": false,
		})


func is_configuration_valid() -> bool:
	return _configuration_errors.is_empty()


func get_configuration_errors() -> PackedStringArray:
	return _configuration_errors.duplicate()


func start(expected_generation: int) -> Dictionary:
	if _mutation_active:
		return _result(false, &"reentrant_call")
	if expected_generation != _generation:
		return _result(false, &"stale_generation")
	if not _attached:
		return _result(false, &"detached")
	if _state == State.ACTIVE:
		return _result(false, &"already_active")
	if _state != State.IDLE:
		return _result(false, &"reset_required")
	if not is_configuration_valid():
		return _result(false, &"invalid_configuration")
	if _generation >= StationDefenseContract.MAX_SAFE_INTEGER:
		return _result(false, &"generation_exhausted")
	_mutation_active = true
	_generation += 1
	_state = State.ACTIVE
	_current_wave_index = 0
	_elapsed_seconds = 0.0
	_failure_reason = &""
	_destroyed_hostile_keys.clear()
	_accepted_asset_event_keys.clear()
	_completion_emission_count = 0
	_reset_asset_states()
	_prepare_current_wave()
	_emit_snapshot(activity_started)
	if _wave_active:
		_emit_snapshot(wave_started)
	return _finish_mutation(true, &"started")


## Advances only caller-supplied physics time. Large deltas may finish the
## current wave countdown, but never destroy or skip a hostile.
func advance(delta: float, expected_generation: int) -> Dictionary:
	if _mutation_active:
		return _result(false, &"reentrant_call")
	var gate := _active_gate(expected_generation)
	if not bool(gate.accepted):
		return gate
	if not is_finite(delta) or delta < 0.0:
		return _result(false, &"invalid_delta")
	if is_zero_approx(delta):
		return _result(true, &"no_delta")
	var candidate_elapsed := _elapsed_seconds + delta
	if not is_finite(candidate_elapsed):
		return _result(false, &"time_overflow")
	_mutation_active = true
	_elapsed_seconds = candidate_elapsed
	if _elapsed_seconds >= _get_timeout_seconds():
		_state = State.TIMED_OUT
		_failure_reason = &"timeout"
		_emit_snapshot(activity_failed)
		return _finish_mutation(true, &"timed_out")
	if not _wave_active:
		_wave_delay_remaining_seconds = maxf(0.0, _wave_delay_remaining_seconds - delta)
		if is_zero_approx(_wave_delay_remaining_seconds):
			_wave_delay_remaining_seconds = 0.0
			_wave_active = true
			_emit_snapshot(wave_started)
	return _finish_mutation(true, &"advanced")


func hostile_destroyed(hostile_handle: Dictionary, expected_generation: int) -> Dictionary:
	if _mutation_active:
		return _result(false, &"reentrant_call")
	if expected_generation != _generation:
		return _result(false, &"stale_generation")
	var lookup := _find_hostile(hostile_handle)
	if not bool(lookup.accepted):
		return _result(false, StringName(lookup.reason))
	var canonical := lookup.handle as Dictionary
	var key := StationDefenseContract.handle_key(canonical, "hostile_id")
	if _destroyed_hostile_keys.has(key):
		return _result(false, &"duplicate_hostile_event")
	var gate := _active_gate(expected_generation)
	if not bool(gate.accepted):
		return gate
	if not _wave_active:
		return _result(false, &"wave_not_active")
	var hostile_wave_index := int(lookup.wave_index)
	if hostile_wave_index < _current_wave_index:
		return _result(false, &"retired_wave")
	if hostile_wave_index > _current_wave_index:
		return _result(false, &"future_wave")
	var wave := _get_current_wave()
	if int(wave.mode) == StationDefenseContract.WaveMode.ORDERED:
		var expected := _first_remaining_hostile(wave)
		if not _handles_equal(canonical, expected, "hostile_id"):
			return _result(false, &"out_of_order")

	_mutation_active = true
	_destroyed_hostile_keys[key] = true
	_emit_snapshot_with_handle(hostile_destruction_accepted, canonical)
	if _current_wave_is_complete():
		_emit_snapshot(wave_completed)
		_current_wave_index += 1
		if _current_wave_index == _get_wave_count():
			_state = State.COMPLETED
			_wave_active = false
			_wave_delay_remaining_seconds = 0.0
			_completion_emission_count += 1
			_emit_snapshot(activity_completed)
		else:
			_prepare_current_wave()
			if _wave_active:
				_emit_snapshot(wave_started)
	return _finish_mutation(true, &"completed" if _state == State.COMPLETED else &"hostile_destroyed")


func protected_asset_damaged(
	asset_handle: Dictionary,
	event_handle: Dictionary,
	expected_generation: int
	) -> Dictionary:
	return _submit_asset_event(asset_handle, event_handle, expected_generation, false)


func protected_asset_destroyed(
	asset_handle: Dictionary,
	event_handle: Dictionary,
	expected_generation: int
	) -> Dictionary:
	return _submit_asset_event(asset_handle, event_handle, expected_generation, true)


func fail(reason: StringName, expected_generation: int) -> Dictionary:
	if _mutation_active:
		return _result(false, &"reentrant_call")
	var gate := _active_gate(expected_generation)
	if not bool(gate.accepted):
		return gate
	_mutation_active = true
	_state = State.FAILED
	_failure_reason = reason if StationDefenseContract.is_stable_id(reason) else &"unspecified_failure"
	_emit_snapshot(activity_failed)
	return _finish_mutation(true, &"failed")


func abort(expected_generation: int) -> Dictionary:
	if _mutation_active:
		return _result(false, &"reentrant_call")
	var gate := _active_gate(expected_generation)
	if not bool(gate.accepted):
		return gate
	_mutation_active = true
	_state = State.ABORTED
	_failure_reason = &"aborted"
	_emit_snapshot(activity_aborted)
	return _finish_mutation(true, &"aborted")


func reset(expected_generation: int) -> Dictionary:
	if _mutation_active:
		return _result(false, &"reentrant_call")
	if expected_generation != _generation:
		return _result(false, &"stale_generation")
	if _state == State.IDLE:
		return _result(false, &"already_idle")
	if _generation >= StationDefenseContract.MAX_SAFE_INTEGER:
		return _result(false, &"generation_exhausted")
	_mutation_active = true
	_generation += 1
	_state = State.IDLE
	_current_wave_index = 0
	_wave_active = false
	_wave_delay_remaining_seconds = 0.0
	_elapsed_seconds = 0.0
	_failure_reason = &""
	_destroyed_hostile_keys.clear()
	_accepted_asset_event_keys.clear()
	_completion_emission_count = 0
	_reset_asset_states()
	_emit_snapshot(activity_reset)
	return _finish_mutation(true, &"reset")


## Adopts only a persisted generation floor into a pristine IDLE activity.
## No active wave, damage, reward, clock, or hostile ledger is restored.
func restore_idle_generation(
		target_generation: int,
		protected_asset_handle: Dictionary
	) -> Dictionary:
	if _mutation_active:
		return _result(false, &"reentrant_call")
	if (
		_state != State.IDLE
		or _generation != 0
		or target_generation < 1
		or target_generation > StationDefenseContract.MAX_SAFE_INTEGER
		or _protected_asset_states.size() != 1
		or not _valid_input_handle(protected_asset_handle, "asset_id")
		or int(protected_asset_handle.get("generation", -1)) != target_generation
	):
		return _result(false, &"pristine_idle_restore_required")
	_mutation_active = true
	_generation = target_generation
	_protected_asset_states[0] = {
		"handle": StationDefenseContract.canonical_asset_handle(protected_asset_handle),
		"damage_event_count": 0,
		"destroyed": false,
	}
	return _finish_mutation(true, &"idle_generation_restored")


## Rebinds one protected object to its next exact physical generation. This is
## permitted only in the post-reset IDLE state, never during an encounter, and
## changes no activity generation or clock. Signal observers see the committed
## handle while the ordinary mutation guard still rejects synchronous reentry.
func renew_protected_asset_handle(
	old_handle: Dictionary,
	new_handle: Dictionary,
	expected_generation: int
	) -> Dictionary:
	if _mutation_active:
		return _result(false, &"reentrant_call")
	if expected_generation != _generation:
		return _result(false, &"stale_generation")
	if not _attached:
		return _result(false, &"detached")
	if _state != State.IDLE:
		return _result(false, &"protected_asset_renewal_requires_idle")
	if not _valid_input_handle(old_handle, "asset_id") \
		or not _valid_input_handle(new_handle, "asset_id"):
		return _result(false, &"invalid_protected_asset_handle")
	var canonical_old := StationDefenseContract.canonical_asset_handle(old_handle)
	var canonical_new := StationDefenseContract.canonical_asset_handle(new_handle)
	if StringName(canonical_new.asset_id) != StringName(canonical_old.asset_id) \
		or int(canonical_old.generation) >= StationDefenseContract.MAX_SAFE_INTEGER \
		or int(canonical_new.generation) != int(canonical_old.generation) + 1:
		return _result(false, &"invalid_protected_asset_renewal")
	var lookup := _find_protected_asset(canonical_old)
	if not bool(lookup.accepted):
		return _result(false, StringName(lookup.reason))
	for state in _protected_asset_states:
		var retained := state.handle as Dictionary
		if StringName(retained.asset_id) == StringName(canonical_new.asset_id) \
			and int(retained.generation) == int(canonical_new.generation):
			return _result(false, &"duplicate_protected_asset_handle")

	_mutation_active = true
	var asset_index := int(lookup.asset_index)
	_protected_asset_states[asset_index]["handle"] = canonical_new.duplicate(true)
	_protected_asset_states[asset_index]["damage_event_count"] = 0
	_protected_asset_states[asset_index]["destroyed"] = false
	var contract_handles := _get_protected_handles()
	for index in contract_handles.size():
		var retained := contract_handles[index] as Dictionary
		if _handles_equal(retained, canonical_old, "asset_id"):
			contract_handles[index] = canonical_new.duplicate(true)
			break
	_contract_snapshot["protected_asset_handles"] = contract_handles
	protected_asset_renewed.emit(
		get_snapshot().duplicate(true),
		canonical_old.duplicate(true),
		canonical_new.duplicate(true)
	)
	return _finish_mutation(true, &"protected_asset_renewed")


## Detachment is an observation-lifecycle gate only. It does not change the
## objective state or advance its caller-owned clock.
func detach(expected_generation: int) -> Dictionary:
	if _mutation_active:
		return _result(false, &"reentrant_call")
	if expected_generation != _generation:
		return _result(false, &"stale_generation")
	if not _attached:
		return _result(false, &"already_detached")
	_attached = false
	return _result(true, &"detached")


func reattach(expected_generation: int) -> Dictionary:
	if _mutation_active:
		return _result(false, &"reentrant_call")
	if expected_generation != _generation:
		return _result(false, &"stale_generation")
	if _attached:
		return _result(false, &"already_attached")
	_attached = true
	return _result(true, &"reattached")


func get_generation() -> int:
	return _generation


func get_state() -> int:
	return _state


func get_snapshot() -> Dictionary:
	var wave := _get_current_wave() if _state != State.IDLE else {}
	var active_handles: Array[Dictionary] = []
	if _state == State.ACTIVE and _wave_active and not wave.is_empty():
		if int(wave.mode) == StationDefenseContract.WaveMode.ORDERED:
			var expected := _first_remaining_hostile(wave)
			if not expected.is_empty():
				active_handles.append(expected)
		else:
			for handle: Dictionary in wave.hostile_handles as Array:
				if not _destroyed_hostile_keys.has(StationDefenseContract.handle_key(handle, "hostile_id")):
					active_handles.append(handle.duplicate(true))
	var asset_states: Array[Dictionary] = []
	for asset_state in _protected_asset_states:
		asset_states.append(asset_state.duplicate(true))
	var mode := int(wave.get("mode", -1))
	return {
		"activity_id": _contract_snapshot.get("activity_id", &""),
		"state": _state,
		"state_id": _STATE_IDS[_state],
		"generation": _generation,
		"attached": _attached,
		"current_wave_index": _current_wave_index,
		"wave_number": (
			_current_wave_index + 1
			if _state == State.ACTIVE and _current_wave_index < _get_wave_count()
			else _get_wave_count() if _state == State.COMPLETED else 0
		),
		"wave_count": _get_wave_count(),
		"wave_id": wave.get("wave_id", &""),
		"wave_mode": mode,
		"wave_mode_id": _WAVE_MODE_IDS[mode] if mode >= 0 and mode < _WAVE_MODE_IDS.size() else "none",
		"wave_active": _state == State.ACTIVE and _wave_active,
		"wave_delay_remaining_seconds": _wave_delay_remaining_seconds,
		"current_wave_hostile_count": (wave.get("hostile_handles", []) as Array).size(),
		"current_wave_destroyed_count": _destroyed_count_for_wave(wave),
		"active_hostile_handles": active_handles,
		"remaining_hostile_count": _remaining_hostile_count(),
		"elapsed_seconds": _elapsed_seconds,
		"timeout_seconds": _get_timeout_seconds(),
		"timeout_remaining_seconds": maxf(0.0, _get_timeout_seconds() - _elapsed_seconds),
		"protected_assets": asset_states,
		"accepted_asset_event_count": _accepted_asset_event_keys.size(),
		"failure_reason": _failure_reason,
		"uses_caller_physics_delta": true,
	}


func audit() -> Dictionary:
	var errors := get_configuration_errors()
	if _current_wave_index < 0 or _current_wave_index > _get_wave_count():
		errors.append("current wave index is outside the contract")
	if _destroyed_hostile_keys.size() > _total_hostile_count():
		errors.append("destroyed hostile ledger exceeds the contract")
	if _accepted_asset_event_keys.size() > MAX_ACCEPTED_ASSET_EVENTS:
		errors.append("protected asset event ledger exceeds its bound")
	if _state == State.COMPLETED:
		if _remaining_hostile_count() != 0:
			errors.append("completed defense retains hostiles")
		if _completion_emission_count != 1:
			errors.append("completion was not committed exactly once")
	elif _completion_emission_count != 0:
		errors.append("non-completed defense retains a completion emission")
	errors.sort()
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"limits": {
			"maximum_accepted_asset_events": MAX_ACCEPTED_ASSET_EVENTS,
			"maximum_waves": StationDefenseContract.MAX_WAVES,
			"maximum_total_hostiles": StationDefenseContract.MAX_TOTAL_HOSTILES,
		},
		"authority": StationDefenseContract._authority_exclusions(),
		"snapshot": get_snapshot(),
	}.duplicate(true)


func _submit_asset_event(
	asset_handle: Dictionary,
	event_handle: Dictionary,
	expected_generation: int,
	destroyed: bool
	) -> Dictionary:
	if _mutation_active:
		return _result(false, &"reentrant_call")
	if expected_generation != _generation:
		return _result(false, &"stale_generation")
	var asset_lookup := _find_protected_asset(asset_handle)
	if not bool(asset_lookup.accepted):
		return _result(false, StringName(asset_lookup.reason))
	if not StationDefenseContract.validate_event_handle(event_handle):
		return _result(false, &"invalid_event_handle")
	var canonical_event := StationDefenseContract.canonical_event_handle(event_handle)
	var event_key := StationDefenseContract.handle_key(canonical_event, "event_id")
	if _accepted_asset_event_keys.has(event_key):
		return _result(false, &"duplicate_protected_asset_event")
	var asset_index := int(asset_lookup.asset_index)
	if bool(_protected_asset_states[asset_index].destroyed):
		return _result(false, &"protected_asset_already_destroyed")
	var gate := _active_gate(expected_generation)
	if not bool(gate.accepted):
		return gate
	# Keep one bounded ledger slot available for the first destruction event so
	# noisy damage observations cannot hide loss of a protected station asset.
	var event_limit := MAX_ACCEPTED_ASSET_EVENTS if destroyed else MAX_ACCEPTED_ASSET_EVENTS - 1
	if _accepted_asset_event_keys.size() >= event_limit:
		return _result(false, &"asset_event_limit_reached")

	_mutation_active = true
	_accepted_asset_event_keys[event_key] = true
	_protected_asset_states[asset_index]["damage_event_count"] = (
		int(_protected_asset_states[asset_index].damage_event_count) + 1
	)
	var canonical_asset := asset_lookup.handle as Dictionary
	if destroyed:
		_protected_asset_states[asset_index]["destroyed"] = true
		_emit_asset_signal(
			protected_asset_destruction_accepted,
			canonical_asset,
			canonical_event
		)
		_state = State.FAILED
		_failure_reason = &"protected_asset_destroyed"
		_emit_snapshot(activity_failed)
		return _finish_mutation(true, &"protected_asset_destroyed")
	_emit_asset_signal(protected_asset_damage_accepted, canonical_asset, canonical_event)
	return _finish_mutation(true, &"protected_asset_damaged")


func _active_gate(expected_generation: int) -> Dictionary:
	if expected_generation != _generation:
		return _result(false, &"stale_generation")
	if not _attached:
		return _result(false, &"detached")
	if _state != State.ACTIVE:
		return _result(false, &"not_active")
	return {"accepted": true}


func _find_hostile(input_handle: Dictionary) -> Dictionary:
	if not _valid_input_handle(input_handle, "hostile_id"):
		return {"accepted": false, "reason": &"invalid_hostile_handle"}
	var canonical := StationDefenseContract.canonical_hostile_handle(input_handle)
	for wave_index in _get_wave_count():
		var wave := _get_wave(wave_index)
		for handle: Dictionary in wave.hostile_handles as Array:
			if StringName(handle.hostile_id) != StringName(canonical.hostile_id):
				continue
			if int(handle.generation) != int(canonical.generation):
				return {"accepted": false, "reason": &"stale_hostile_generation"}
			return {
				"accepted": true,
				"wave_index": wave_index,
				"handle": handle.duplicate(true),
			}
	return {"accepted": false, "reason": &"unknown_hostile"}


func _find_protected_asset(input_handle: Dictionary) -> Dictionary:
	if not _valid_input_handle(input_handle, "asset_id"):
		return {"accepted": false, "reason": &"invalid_protected_asset_handle"}
	var canonical := StationDefenseContract.canonical_asset_handle(input_handle)
	for index in _protected_asset_states.size():
		var handle := _protected_asset_states[index].handle as Dictionary
		if StringName(handle.asset_id) != StringName(canonical.asset_id):
			continue
		if int(handle.generation) != int(canonical.generation):
			return {"accepted": false, "reason": &"stale_protected_asset_generation"}
		return {"accepted": true, "asset_index": index, "handle": handle.duplicate(true)}
	return {"accepted": false, "reason": &"unknown_protected_asset"}


func _prepare_current_wave() -> void:
	var wave := _get_current_wave()
	_wave_delay_remaining_seconds = float(wave.get("delay_seconds", 0.0))
	_wave_active = is_zero_approx(_wave_delay_remaining_seconds)
	if _wave_active:
		_wave_delay_remaining_seconds = 0.0


func _current_wave_is_complete() -> bool:
	var wave := _get_current_wave()
	return not wave.is_empty() \
		and _destroyed_count_for_wave(wave) == (wave.hostile_handles as Array).size()


func _first_remaining_hostile(wave: Dictionary) -> Dictionary:
	for handle: Dictionary in wave.get("hostile_handles", []) as Array:
		if not _destroyed_hostile_keys.has(StationDefenseContract.handle_key(handle, "hostile_id")):
			return handle.duplicate(true)
	return {}


func _destroyed_count_for_wave(wave: Dictionary) -> int:
	var count := 0
	for handle: Dictionary in wave.get("hostile_handles", []) as Array:
		if _destroyed_hostile_keys.has(StationDefenseContract.handle_key(handle, "hostile_id")):
			count += 1
	return count


func _remaining_hostile_count() -> int:
	return maxi(0, _total_hostile_count() - _destroyed_hostile_keys.size())


func _total_hostile_count() -> int:
	var count := 0
	for wave: Dictionary in _get_waves():
		count += (wave.hostile_handles as Array).size()
	return count


func _reset_asset_states() -> void:
	for index in _protected_asset_states.size():
		_protected_asset_states[index]["damage_event_count"] = 0
		_protected_asset_states[index]["destroyed"] = false


func _get_waves() -> Array:
	return _contract_snapshot.get("waves", []) as Array


func _get_wave_count() -> int:
	return _get_waves().size()


func _get_wave(index: int) -> Dictionary:
	if index < 0 or index >= _get_wave_count():
		return {}
	return (_get_waves()[index] as Dictionary).duplicate(true)


func _get_current_wave() -> Dictionary:
	return _get_wave(_current_wave_index)


func _get_protected_handles() -> Array:
	return _contract_snapshot.get("protected_asset_handles", []) as Array


func _get_timeout_seconds() -> float:
	return float(_contract_snapshot.get("timeout_seconds", 0.0))


func _emit_snapshot(target_signal: Signal) -> void:
	target_signal.emit(get_snapshot().duplicate(true))


func _emit_snapshot_with_handle(target_signal: Signal, handle: Dictionary) -> void:
	target_signal.emit(get_snapshot().duplicate(true), handle.duplicate(true))


func _emit_asset_signal(
	target_signal: Signal,
	asset_handle: Dictionary,
	event_handle: Dictionary
	) -> void:
	target_signal.emit(
		get_snapshot().duplicate(true),
		asset_handle.duplicate(true),
		event_handle.duplicate(true)
	)


func _finish_mutation(accepted: bool, reason: StringName) -> Dictionary:
	_mutation_active = false
	return _result(accepted, reason)


func _result(accepted: bool, reason: StringName) -> Dictionary:
	var result := get_snapshot().duplicate(true)
	result["accepted"] = accepted
	result["reason"] = reason
	return result


static func _valid_input_handle(handle: Dictionary, id_field: String) -> bool:
	var expected := [id_field, "generation"]
	if not StationDefenseContract._has_exact_keys(handle, expected):
		return false
	return StationDefenseContract.is_stable_id(
		StationDefenseContract._field(handle, id_field, &"")
	) and StationDefenseContract._valid_generation(
		StationDefenseContract._field(handle, "generation", 0)
	)


static func _handles_equal(left: Dictionary, right: Dictionary, id_field: String) -> bool:
	return StringName(left.get(id_field, &"")) == StringName(right.get(id_field, &"")) \
		and int(left.get("generation", 0)) == int(right.get("generation", 0))
