class_name CargoDeliveryActivity
extends RefCounted

## Generation-safe objective state composed over CargoTransferAuthority.
##
## Inventory changes only through the supplied transfer authority. Time advances
## only through caller-supplied physics delta, so process frames and wall-clock
## load cannot expire a delivery.

signal started(snapshot: Dictionary)
signal phase_advanced(snapshot: Dictionary)
signal completed(snapshot: Dictionary, receipt: Dictionary)
signal failed(snapshot: Dictionary)
signal expired(snapshot: Dictionary)
signal activity_reset(snapshot: Dictionary)

enum State {
	IDLE,
	ACTIVE,
	COMPLETED,
	FAILED,
	EXPIRED,
}

var _authority: CargoTransferAuthority
var _contract_snapshot: Dictionary = {}
var _contract_configuration_errors := PackedStringArray()
var _state := State.IDLE
var _generation := 0
var _next_phase_index := 0
var _elapsed_seconds := 0.0
var _failure_reason: StringName = &""
var _expected_transfer_id: StringName = &""
var _accepted_receipt: Dictionary = {}
var _signal_dispatch_active := false
var _authority_submission_active := false

static var _reservations_by_authority_instance: Dictionary = {}


func _init(authority: CargoTransferAuthority, contract: CargoDeliveryContract) -> void:
	_authority = authority
	if contract == null:
		_contract_configuration_errors.append("a CargoDeliveryContract is required")
	else:
		_contract_snapshot = contract.get_snapshot().duplicate(true)
		_contract_configuration_errors = contract.get_configuration_errors().duplicate()
	if is_instance_valid(_authority):
		_authority.transfer_committed.connect(_on_transfer_committed)


func is_configuration_valid() -> bool:
	return get_configuration_errors().is_empty()


func get_configuration_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if not is_instance_valid(_authority):
		errors.append("a live CargoTransferAuthority is required")
	for error: String in _contract_configuration_errors:
		errors.append(error)
	errors.sort()
	return errors


func start(expected_generation: int) -> Dictionary:
	if _signal_dispatch_active:
		return _result(false, &"reentrant_call")
	if expected_generation != _generation:
		return _result(false, &"stale_generation")
	if _state == State.ACTIVE:
		return _result(false, &"already_active")
	if _state != State.IDLE:
		return _result(false, &"reset_required")
	if not is_configuration_valid():
		return _result(false, &"invalid_configuration")
	if not _authority.is_inside_tree():
		return _result(false, &"authority_outside_tree")
	if _generation >= CargoTransferAuthority.MAX_SAFE_INTEGER:
		return _result(false, &"generation_exhausted")
	var handle_validation := _validate_bound_handles()
	if not bool(handle_validation.accepted):
		return _result(false, StringName(handle_validation.reason))
	var next_generation := _generation + 1
	var transfer_id := _transfer_id_for_generation(next_generation)
	if transfer_id.is_empty():
		return _result(false, &"invalid_transfer_id")
	if _ledger_has_transfer_id(transfer_id):
		return _result(false, &"transfer_id_already_committed")
	if not _reserve_transfer_id(transfer_id):
		return _result(false, &"transfer_id_reserved")
	_generation = next_generation
	_state = State.ACTIVE
	_next_phase_index = 0
	_elapsed_seconds = 0.0
	_failure_reason = &""
	_expected_transfer_id = transfer_id
	_accepted_receipt.clear()
	_emit_snapshot_signal(started)
	return _result(true, &"started")


func submit_phase(phase_id: StringName, expected_generation: int) -> Dictionary:
	if _signal_dispatch_active:
		return _result(false, &"reentrant_call")
	if expected_generation != _generation:
		return _result(false, &"stale_generation")
	if _state != State.ACTIVE:
		return _result(false, &"not_active")
	var phases := _get_ordered_phases()
	var submitted_index := phases.find(phase_id)
	if submitted_index < 0:
		return _result(false, &"unknown_phase")
	if submitted_index < _next_phase_index:
		return _result(false, &"duplicate_phase")
	if submitted_index != _next_phase_index:
		return _result(false, &"out_of_order")
	_next_phase_index += 1
	_emit_snapshot_signal(phase_advanced)
	return _result(true, &"phase_advanced")


func submit_transfer(expected_generation: int) -> Dictionary:
	if _signal_dispatch_active:
		return _result(false, &"reentrant_call")
	if expected_generation != _generation:
		return _result(false, &"stale_generation")
	if _state != State.ACTIVE:
		return _result(false, &"not_active")
	if _next_phase_index != _get_ordered_phases().size():
		return _result(false, &"phases_incomplete")
	# CargoTransferAuthority emits synchronously before returning its separate
	# detached receipt. Hold the mutation guard across that entire dispatch so an
	# earlier authority-signal observer cannot reset or fail this activity between
	# the cargo commit and receipt validation.
	_signal_dispatch_active = true
	_authority_submission_active = true
	var authority_result := _authority.transfer(
		_expected_transfer_id,
		_get_source_handle(),
		_get_destination_handle(),
		_get_item_id(),
		_get_quantity()
	)
	_authority_submission_active = false
	if not bool(authority_result.get("accepted", false)):
		if (
			StringName(authority_result.get("reason", &"")) == &"duplicate_transfer"
			and _ledger_has_transfer_id(_expected_transfer_id)
		):
			_commit_failure(&"transfer_id_consumed_externally")
		_signal_dispatch_active = false
		var rejected := _result(false, StringName(authority_result.get("reason", &"transfer_rejected")))
		rejected["authority_result"] = authority_result.duplicate(true)
		if authority_result.has("side"):
			rejected["side"] = authority_result.side
		return rejected
	var receipt_validation := _validate_exact_receipt(authority_result)
	if not bool(receipt_validation.accepted):
		_commit_failure(StringName(receipt_validation.reason))
		_signal_dispatch_active = false
		return _result(false, &"receipt_rejected", {"authority_result": authority_result})
	_state = State.COMPLETED
	_failure_reason = &""
	_accepted_receipt = authority_result.duplicate(true)
	_release_transfer_id_reservation()
	_emit_completed_signal()
	_signal_dispatch_active = false
	return _result(true, &"delivered", {"receipt": _accepted_receipt.duplicate(true)})


## Caller must supply its physics delta. A zero delta is a deterministic pause;
## process/render frames never age this deadline.
func advance_physics(delta: float, expected_generation: int) -> Dictionary:
	if _signal_dispatch_active:
		return _result(false, &"reentrant_call")
	if expected_generation != _generation:
		return _result(false, &"stale_generation")
	if _state != State.ACTIVE:
		return _result(false, &"not_active")
	if not is_finite(delta) or delta < 0.0:
		return _result(false, &"invalid_delta")
	if is_zero_approx(delta):
		return _result(true, &"no_delta")
	var candidate_elapsed := _elapsed_seconds + delta
	if not is_finite(candidate_elapsed):
		return _result(false, &"time_overflow")
	_elapsed_seconds = candidate_elapsed
	if _elapsed_seconds >= _get_deadline_seconds():
		_state = State.EXPIRED
		_failure_reason = &"deadline_expired"
		_release_transfer_id_reservation()
		_emit_snapshot_signal(expired)
	return _result(true, &"expired" if _state == State.EXPIRED else &"advanced")


func fail(reason: StringName, expected_generation: int) -> Dictionary:
	if _signal_dispatch_active:
		return _result(false, &"reentrant_call")
	if expected_generation != _generation:
		return _result(false, &"stale_generation")
	if _state != State.ACTIVE:
		return _result(false, &"not_active")
	_commit_failure(reason if CargoItemDefinition.is_stable_id(reason) else &"unspecified_failure")
	return _result(true, &"failed")


func reset(expected_generation: int) -> Dictionary:
	if _signal_dispatch_active:
		return _result(false, &"reentrant_call")
	if expected_generation != _generation:
		return _result(false, &"stale_generation")
	if _state == State.IDLE:
		return _result(false, &"already_idle")
	if _generation >= CargoTransferAuthority.MAX_SAFE_INTEGER:
		return _result(false, &"generation_exhausted")
	_release_transfer_id_reservation()
	_generation += 1
	_state = State.IDLE
	_next_phase_index = 0
	_elapsed_seconds = 0.0
	_failure_reason = &""
	_expected_transfer_id = &""
	_accepted_receipt.clear()
	_emit_snapshot_signal(activity_reset)
	return _result(true, &"reset")


func get_state() -> int:
	return _state


func get_generation() -> int:
	return _generation


func get_snapshot() -> Dictionary:
	var contract_snapshot := _contract_snapshot.duplicate(true)
	var phases: Array = contract_snapshot.get("ordered_phases", []) as Array
	return {
		"contract": contract_snapshot.duplicate(true),
		"contract_id": contract_snapshot.get("contract_id", &""),
		"state": _state,
		"generation": _generation,
		"next_phase_index": _next_phase_index,
		"phase_count": phases.size(),
		"phases_complete": _next_phase_index == phases.size(),
		"elapsed_seconds": _elapsed_seconds,
		"deadline_seconds": float(contract_snapshot.get("deadline_seconds", 0.0)),
		"deadline_remaining_seconds": maxf(
			0.0,
			float(contract_snapshot.get("deadline_seconds", 0.0)) - _elapsed_seconds
		),
		"failure_reason": _failure_reason,
		"expected_transfer_id": _expected_transfer_id,
		"accepted_receipt": _accepted_receipt.duplicate(true),
		"uses_caller_physics_delta": true,
		"uses_cargo_transfer_authority": true,
		"owns_inventory": false,
		"reward_authority": false,
		"ship_authority": false,
		"berth_authority": false,
		"combat_authority": false,
		"network_authority": false,
		"ui_authority": false,
	}


func audit() -> Dictionary:
	var errors := get_configuration_errors()
	if _state == State.ACTIVE and _expected_transfer_id.is_empty():
		errors.append("active delivery is missing its transfer ID")
	if _state == State.COMPLETED and _accepted_receipt.is_empty():
		errors.append("completed delivery is missing its authority receipt")
	if _state != State.COMPLETED and not _accepted_receipt.is_empty():
		errors.append("non-completed delivery retains an authority receipt")
	errors.sort()
	var report := get_snapshot()
	report["valid"] = errors.is_empty()
	report["errors"] = errors
	return report.duplicate(true)


func _get_source_handle() -> Dictionary:
	return (_contract_snapshot.get("source_handle", {}) as Dictionary).duplicate(true)


func _get_destination_handle() -> Dictionary:
	return (_contract_snapshot.get("destination_handle", {}) as Dictionary).duplicate(true)


func _get_item_id() -> StringName:
	return StringName(_contract_snapshot.get("item_id", &""))


func _get_quantity() -> int:
	return int(_contract_snapshot.get("quantity", 0))


func _get_ordered_phases() -> Array[StringName]:
	var phases: Array[StringName] = []
	for raw_phase: Variant in _contract_snapshot.get("ordered_phases", []) as Array:
		phases.append(StringName(raw_phase))
	return phases


func _get_deadline_seconds() -> float:
	return float(_contract_snapshot.get("deadline_seconds", 0.0))


func _transfer_id_for_generation(generation: int) -> StringName:
	if generation <= 0 or generation > CargoTransferAuthority.MAX_SAFE_INTEGER:
		return &""
	var contract_id := StringName(_contract_snapshot.get("contract_id", &""))
	var transfer_id := StringName("%s_g%d" % [contract_id, generation])
	return transfer_id if CargoItemDefinition.is_stable_id(transfer_id) else &""


func _validate_bound_handles() -> Dictionary:
	var source_snapshot := _authority.get_manifest_snapshot(_get_source_handle())
	if source_snapshot.is_empty():
		return {"accepted": false, "reason": &"stale_source_handle"}
	if not bool(source_snapshot.get("attached", false)):
		return {"accepted": false, "reason": &"source_detached"}
	var destination_snapshot := _authority.get_manifest_snapshot(_get_destination_handle())
	if destination_snapshot.is_empty():
		return {"accepted": false, "reason": &"stale_destination_handle"}
	if not bool(destination_snapshot.get("attached", false)):
		return {"accepted": false, "reason": &"destination_detached"}
	return {"accepted": true, "reason": &"current"}


func _on_transfer_committed(receipt: Dictionary) -> void:
	# The mutable public signal is observation/failure evidence only. Completion
	# uses the authority's separate direct return from this activity's guarded
	# submit_transfer() call, so another listener cannot forge a delivery by
	# rewriting the signal Dictionary.
	if _authority_submission_active:
		return
	if _state != State.ACTIVE:
		return
	if StringName(receipt.get("transfer_id", &"")) != _expected_transfer_id:
		return
	var receipt_id := int(receipt.get("receipt_id", 0))
	if receipt_id <= 0 or not _ledger_contains(_expected_transfer_id, receipt_id):
		return
	_commit_failure(
		&"transfer_before_phases"
		if _next_phase_index != _get_ordered_phases().size()
		else &"transfer_id_consumed_externally"
	)


func _validate_exact_receipt(receipt: Dictionary) -> Dictionary:
	if not bool(receipt.get("accepted", false)) or StringName(receipt.get("reason", &"")) != &"committed":
		return {"accepted": false, "reason": &"receipt_not_committed"}
	if StringName(receipt.get("transfer_id", &"")) != _expected_transfer_id:
		return {"accepted": false, "reason": &"receipt_transfer_mismatch"}
	if StringName(receipt.get("item_id", &"")) != _get_item_id():
		return {"accepted": false, "reason": &"receipt_item_mismatch"}
	if int(receipt.get("quantity", 0)) != _get_quantity():
		return {"accepted": false, "reason": &"receipt_quantity_mismatch"}
	if (
		not _handles_equal(receipt.get("source_handle", {}) as Dictionary, _get_source_handle())
		or not _handles_equal(receipt.get("destination_handle", {}) as Dictionary, _get_destination_handle())
	):
		return {"accepted": false, "reason": &"receipt_direction_mismatch"}
	var receipt_id := int(receipt.get("receipt_id", 0))
	if receipt_id <= 0 or not _ledger_contains(_expected_transfer_id, receipt_id):
		return {"accepted": false, "reason": &"receipt_ledger_mismatch"}
	var source_quantity := _authority.get_quantity(_get_source_handle(), _get_item_id())
	var destination_quantity := _authority.get_quantity(
		_get_destination_handle(),
		_get_item_id()
	)
	if (
		source_quantity < 0
		or destination_quantity < 0
		or int(receipt.get("source_quantity_after", -1)) != source_quantity
		or int(receipt.get("destination_quantity_after", -1)) != destination_quantity
	):
		return {"accepted": false, "reason": &"receipt_manifest_mismatch"}
	return {"accepted": true, "reason": &"exact_receipt"}


func _ledger_contains(transfer_id: StringName, receipt_id: int) -> bool:
	var state := _authority.to_dictionary()
	for entry: Dictionary in state.get("committed_transfers", []) as Array:
		if (
			StringName(entry.get("transfer_id", &"")) == transfer_id
			and int(entry.get("receipt_id", 0)) == receipt_id
		):
			return true
	return false


func _ledger_has_transfer_id(transfer_id: StringName) -> bool:
	var state := _authority.to_dictionary()
	for entry: Dictionary in state.get("committed_transfers", []) as Array:
		if StringName(entry.get("transfer_id", &"")) == transfer_id:
			return true
	return false


func _commit_failure(reason: StringName) -> void:
	_state = State.FAILED
	_failure_reason = reason
	_release_transfer_id_reservation()
	_emit_snapshot_signal(failed)


func _emit_snapshot_signal(target_signal: Signal) -> void:
	var previous_dispatch_state := _signal_dispatch_active
	_signal_dispatch_active = true
	target_signal.emit(get_snapshot().duplicate(true))
	_signal_dispatch_active = previous_dispatch_state


func _emit_completed_signal() -> void:
	var previous_dispatch_state := _signal_dispatch_active
	_signal_dispatch_active = true
	completed.emit(get_snapshot().duplicate(true), _accepted_receipt.duplicate(true))
	_signal_dispatch_active = previous_dispatch_state


func _reserve_transfer_id(transfer_id: StringName) -> bool:
	var authority_id := _authority.get_instance_id()
	var reservations: Dictionary = _reservations_by_authority_instance.get(authority_id, {})
	var existing_reference := reservations.get(transfer_id) as WeakRef
	var existing: Object = existing_reference.get_ref() if existing_reference != null else null
	if is_instance_valid(existing) and existing != self:
		return false
	reservations[transfer_id] = weakref(self)
	_reservations_by_authority_instance[authority_id] = reservations
	return true


func _release_transfer_id_reservation() -> void:
	if not is_instance_valid(_authority) or _expected_transfer_id.is_empty():
		return
	var authority_id := _authority.get_instance_id()
	var reservations: Dictionary = _reservations_by_authority_instance.get(authority_id, {})
	var existing_reference := reservations.get(_expected_transfer_id) as WeakRef
	var existing: Object = existing_reference.get_ref() if existing_reference != null else null
	if existing == self:
		reservations.erase(_expected_transfer_id)
	if reservations.is_empty():
		_reservations_by_authority_instance.erase(authority_id)
	else:
		_reservations_by_authority_instance[authority_id] = reservations


func _result(accepted: bool, reason: StringName, fields: Dictionary = {}) -> Dictionary:
	var result := get_snapshot().duplicate(true)
	for key: Variant in fields:
		result[key] = fields[key]
	result["accepted"] = accepted
	result["reason"] = reason
	return result


static func _handles_equal(left: Dictionary, right: Dictionary) -> bool:
	return (
		StringName(left.get("entity_id", &"")) == StringName(right.get("entity_id", &""))
		and int(left.get("entity_generation", 0)) == int(right.get("entity_generation", 0))
		and StringName(left.get("manifest_id", &"")) == StringName(right.get("manifest_id", &""))
		and int(left.get("manifest_generation", 0)) == int(right.get("manifest_generation", 0))
	)
