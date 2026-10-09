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
	if not _authority.is_inside_tree() or _authority.is_queued_for_deletion():
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


func capture_persistence_state() -> Dictionary:
	return {"contract": _contract_snapshot.duplicate(true), "state": _state, "generation": _generation,
		"next_phase_index": _next_phase_index, "elapsed_seconds": _elapsed_seconds,
		"failure_reason": String(_failure_reason), "expected_transfer_id": String(_expected_transfer_id),
		"accepted_receipt": _accepted_receipt.duplicate(true)}


func validate_persistence_state(candidate: Variant, authority_state: Dictionary) -> Dictionary:
	if not candidate is Dictionary or (candidate as Dictionary).size() != 8 or not is_configuration_valid():
		return {"accepted": false, "reason": &"invalid_delivery_state"}
	var saved := candidate as Dictionary
	if not saved.get("contract") is Dictionary or _canonical(saved.contract) != _canonical(_contract_snapshot) \
			or not _persisted_integer(saved.get("state")) or int(saved.state) not in [State.IDLE, State.ACTIVE, State.COMPLETED, State.FAILED, State.EXPIRED] \
			or not _persisted_integer(saved.get("generation")) or int(saved.generation) < 1 \
			or not _persisted_integer(saved.get("next_phase_index")) or int(saved.next_phase_index) < 0 \
			or int(saved.next_phase_index) > _get_ordered_phases().size() \
			or not (saved.get("elapsed_seconds") is int or saved.get("elapsed_seconds") is float) \
			or not is_finite(float(saved.elapsed_seconds)) or float(saved.elapsed_seconds) < 0.0 \
			or saved.get("failure_reason") is not String or saved.get("expected_transfer_id") is not String \
			or not saved.get("accepted_receipt") is Dictionary:
		return {"accepted": false, "reason": &"invalid_delivery_state"}
	var state := int(saved.state)
	if state == State.IDLE:
		if int(saved.next_phase_index) != 0 or not is_zero_approx(float(saved.elapsed_seconds)) \
				or not str(saved.failure_reason).is_empty() or not str(saved.expected_transfer_id).is_empty() \
				or not (saved.accepted_receipt as Dictionary).is_empty():
			return {"accepted": false, "reason": &"invalid_delivery_idle_state"}
	else:
		if str(saved.expected_transfer_id) != str(_transfer_id_for_generation(int(saved.generation))) \
				or (state != State.EXPIRED and float(saved.elapsed_seconds) >= _get_deadline_seconds()) \
				or (state == State.EXPIRED and (float(saved.elapsed_seconds) < _get_deadline_seconds() or str(saved.failure_reason) != "deadline_expired")) \
				or (state in [State.ACTIVE, State.COMPLETED] and not str(saved.failure_reason).is_empty()) \
				or (state == State.FAILED and not CargoItemDefinition.is_stable_id(StringName(saved.failure_reason))) \
				or (state != State.COMPLETED and not (saved.accepted_receipt as Dictionary).is_empty()):
			return {"accepted": false, "reason": &"invalid_delivery_progress"}
	var transfers := authority_state.get("committed_transfers", []) as Array
	var matching_receipt := -1
	for entry: Dictionary in transfers:
		var text := str(entry.get("transfer_id", ""))
		if text.begins_with(str(_contract_snapshot.contract_id) + "_g"):
			if int(text.trim_prefix(str(_contract_snapshot.contract_id) + "_g")) > int(saved.generation):
				return {"accepted": false, "reason": &"delivery_generation_behind_transfer"}
		if text == str(saved.expected_transfer_id):
			matching_receipt = int(entry.receipt_id)
	if state == State.ACTIVE and matching_receipt >= 0:
		return {"accepted": false, "reason": &"delivery_transfer_already_committed"}
	if state == State.COMPLETED:
		var receipt := saved.accepted_receipt as Dictionary
		if int(saved.next_phase_index) != _get_ordered_phases().size() or receipt.size() != 12 \
				or receipt.get("accepted") != true or str(receipt.get("reason", "")) != "committed" \
				or str(receipt.get("transfer_id", "")) != str(saved.expected_transfer_id) \
				or not _persisted_integer(receipt.get("receipt_id")) or int(receipt.receipt_id) != matching_receipt \
				or str(receipt.get("item_id", "")) != str(_get_item_id()) \
				or not _persisted_integer(receipt.get("quantity")) or int(receipt.quantity) != _get_quantity() \
				or _canonical(receipt.get("source_handle")) != _canonical(_get_source_handle()) \
				or _canonical(receipt.get("destination_handle")) != _canonical(_get_destination_handle()):
			return {"accepted": false, "reason": &"invalid_delivery_receipt"}
		for raw_manifest: Variant in authority_state.get("manifests", []):
			if not raw_manifest is Dictionary or str(raw_manifest.get("manifest_id", "")) not in [str(_get_source_handle().manifest_id), str(_get_destination_handle().manifest_id)]:
				continue
			var manifest := raw_manifest as Dictionary
			var prefix := "source" if str(manifest.manifest_id) == str(_get_source_handle().manifest_id) else "destination"
			var amount := 0
			for entry: Dictionary in manifest.entries:
				if str(entry.item_id) == str(_get_item_id()):
					amount = int(entry.quantity)
			if not _persisted_integer(receipt.get(prefix + "_quantity_after")) or int(receipt[prefix + "_quantity_after"]) != amount \
					or not _persisted_integer(receipt.get(prefix + "_used_capacity_after")) or int(receipt[prefix + "_used_capacity_after"]) != int(manifest.used_capacity):
				return {"accepted": false, "reason": &"invalid_delivery_receipt"}
	return {"accepted": true, "reason": &"delivery_state_valid"}


## Startup-only adoption. Both owners have been prevalidated before inventory
## publication, and no historical lifecycle signal is replayed.
func restore_persistence_state(candidate: Variant, expected_generation: int) -> Dictionary:
	if _signal_dispatch_active or expected_generation != _generation or _generation != 0 or _state != State.IDLE:
		return {"accepted": false, "reason": &"delivery_already_live"}
	var validated := validate_restore_persistence_state(candidate, _authority.to_dictionary())
	if not bool(validated.accepted):
		return validated
	if int(candidate.state) == State.ACTIVE and not _reserve_transfer_id(StringName(candidate.expected_transfer_id)):
		return {"accepted": false, "reason": &"transfer_id_reserved"}
	_adopt_validated_fields(candidate as Dictionary)
	return {"accepted": true, "reason": &"delivery_state_restored"}


func validate_restore_persistence_state(candidate: Variant, authority_state: Dictionary) -> Dictionary:
	if _signal_dispatch_active or _generation != 0 or _state != State.IDLE:
		return {"accepted": false, "reason": &"delivery_already_live"}
	var validated := validate_persistence_state(candidate, authority_state)
	if not bool(validated.accepted):
		return validated
	if int(candidate.state) == State.ACTIVE:
		var reservations := _reservations_by_authority_instance.get(_authority.get_instance_id(), {}) as Dictionary
		var reference := reservations.get(StringName(candidate.expected_transfer_id)) as WeakRef
		if reference != null and is_instance_valid(reference.get_ref()) and reference.get_ref() != self:
			return {"accepted": false, "reason": &"transfer_id_reserved"}
	return validated


func reset_with_persistence(expected_generation: int, persist_reset: Callable) -> Dictionary:
	if _signal_dispatch_active or expected_generation != _generation or _state == State.IDLE or not persist_reset.is_valid():
		return {"accepted": false, "reason": &"delivery_reset_unavailable"}
	var validated := validate_persistence_state(capture_persistence_state(), _authority.to_dictionary())
	if not bool(validated.accepted):
		return validated
	_signal_dispatch_active = true
	var contract := CargoDeliveryContract.new(StringName(_contract_snapshot.contract_id), _get_source_handle(),
		_get_destination_handle(), _get_item_id(), _get_quantity(), _get_ordered_phases(), _get_deadline_seconds())
	var scratch := CargoDeliveryActivity.new(_authority, contract)
	_authority.transfer_committed.disconnect(scratch._on_transfer_committed)
	scratch._adopt_validated_fields(capture_persistence_state())
	var staged := scratch.reset(expected_generation)
	var saved: Variant = persist_reset.call(scratch) if bool(staged.accepted) else staged
	_signal_dispatch_active = false
	if not saved is Dictionary or not bool(saved.get("accepted", false)):
		return {"accepted": false, "reason": &"delivery_reset_save_rejected", "store_result": saved}
	return reset(expected_generation)


func _adopt_validated_fields(saved: Dictionary) -> void:
	_state = int(saved.state)
	_generation = int(saved.generation)
	_next_phase_index = int(saved.next_phase_index)
	_elapsed_seconds = float(saved.elapsed_seconds)
	_failure_reason = StringName(saved.failure_reason)
	_expected_transfer_id = StringName(saved.expected_transfer_id)
	_accepted_receipt = (saved.accepted_receipt as Dictionary).duplicate(true)


func _canonical(value: Variant) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(value)))


func _persisted_integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) \
		and float(value) == floor(float(value)) and absf(float(value)) <= CargoTransferAuthority.MAX_SAFE_INTEGER


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
