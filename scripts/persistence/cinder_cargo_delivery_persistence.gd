class_name CinderCargoDeliveryPersistence
extends RefCounted

## Namespaced atomic-store bridge for one authenticated terminal Cinder cargo
## delivery. It never stores manifests, handles, inventory, or active progress.

const SCHEMA_VERSION := 2
const SLOT_ID: StringName = &"cinder_cargo_delivery"
const ITEM_ID := "cinder_supply_crates"
const PHASES := ["load_crate", "clear_gate", "dock_platform"]
const PAYLOAD_KIND := "cinder_cargo_delivery_receipt"
const CONTRACT_ID := "cinder_platform_supply_run"
const REWARD_ACTIVITY_ID := "cinder_kit_cargo_run"
const REWARD_ID := "return_fabrication_kits_to_shipyard"

var _store: RefCounted
var _slot_id: StringName = &""
var _publication_active := false


func configure(store: RefCounted, slot_id: StringName) -> Dictionary:
	if _store != null or store == null or str(slot_id).strip_edges().is_empty() \
			or not store.has_method(&"load") or not store.has_method(&"commit") \
			or not store.has_method(&"get_snapshot") \
			or not store.has_method(&"get_generation"):
		return _result(false, &"cargo_delivery_persistence_configuration_invalid")
	_store = store
	_slot_id = slot_id
	return _result(true, &"cargo_delivery_persistence_configured")


func save(activity: CargoDeliveryActivity, authority: CargoTransferAuthority, commit_id: String) -> Dictionary:
	if not _configured() or _publication_active or commit_id.strip_edges().is_empty():
		return _result(false, &"cargo_delivery_save_invalid")
	var captured: Dictionary = capture(activity, authority)
	if not bool(captured.get("accepted", false)):
		return captured
	var loaded: Dictionary = _store.call(&"load")
	if not bool(loaded.get("accepted", false)):
		return loaded
	if not _store.has_method(&"get_loaded_source") or _store.call(&"get_loaded_source") not in [&"primary", &"empty"]:
		return _result(false, &"cargo_delivery_recovery_required")
	var payload: Dictionary = _store.call(&"get_snapshot")
	var record: Dictionary = captured.record
	if payload.has(String(_slot_id)):
		var previous: Variant = payload[String(_slot_id)]
		if not bool(validate_record(previous).accepted):
			return _result(false, &"cargo_delivery_payload_corrupt")
		if int(previous.schema_version) == SCHEMA_VERSION:
			var prior: Dictionary = previous.delivery
			var intended: Dictionary = record.delivery
			if int(prior.generation) == int(intended.generation):
				var comparable: Dictionary = previous.duplicate(true)
				comparable.delivery.reward_receipt.granted = false
				if comparable != record:
					return _result(false, &"cargo_delivery_terminal_changed")
				return _result(true, &"cargo_delivery_already_saved")
			if not bool(prior.reward_receipt.granted) or int(prior.generation) >= int(intended.generation):
				return _result(false, &"cargo_delivery_unpaid_or_stale")
	payload[String(_slot_id)] = record
	_publication_active = true
	var committed: Dictionary = _store.call(&"commit", payload, int(_store.call(&"get_generation")), commit_id)
	_publication_active = false
	# A refused return may still have published this exact primary record. Do not
	# infer success from a backup or a different/currently paid completion.
	if not bool(committed.get("accepted", false)):
		var reconciled: Dictionary = self.load()
		if bool(reconciled.get("accepted", false)) and reconciled.get("record", {}) == record:
			return _result(true, &"cargo_delivery_publication_recovered")
	return committed


func load() -> Dictionary:
	if not _configured():
		return _result(false, &"cargo_delivery_persistence_unavailable")
	var loaded := _store.call(&"load") as Dictionary
	if not bool(loaded.get("accepted", false)):
		return loaded
	var payload := loaded.get("payload", {}) as Dictionary
	var key := String(_slot_id)
	if not payload.has(key):
		return _result(false, &"cargo_delivery_not_found")
	var validation := validate_record(payload.get(key))
	if not bool(validation.get("accepted", false)):
		return validation
	if int((payload[key] as Dictionary).schema_version) == SCHEMA_VERSION and (not _store.has_method(&"get_loaded_source") or _store.call(&"get_loaded_source") != &"primary"):
		return _result(false, &"cargo_delivery_recovery_required")
	return {
		"accepted": true,
		"reason": &"cargo_delivery_loaded",
		"store_generation": int(loaded.get("generation", -1)),
		"delivery": (payload[key] as Dictionary).delivery.duplicate(true),
		"record": (payload[key] as Dictionary).duplicate(true),
	}.duplicate(true)


func capture(activity: CargoDeliveryActivity, authority: CargoTransferAuthority) -> Dictionary:
	if activity == null or not is_instance_valid(authority):
		return _result(false, &"cargo_delivery_receipts_not_committed")
	var cargo: Dictionary = activity.get_snapshot()
	var contract: Dictionary = cargo.get("contract", {})
	var transfer: Dictionary = cargo.get("accepted_receipt", {})
	var generation: int = int(cargo.get("generation", 0))
	var inventory: Dictionary = authority.to_dictionary()
	var checked: Dictionary = activity.validate_terminal_transfer(authority)
	if not bool(checked.get("accepted", false)) or int(cargo.state) != CargoDeliveryActivity.State.COMPLETED \
			or str(contract.get("contract_id", "")) != CONTRACT_ID \
			or str(contract.get("item_id", "")) != ITEM_ID or int(contract.get("quantity", 0)) != 1 \
			or float(contract.get("deadline_seconds", 0.0)) != 120.0 \
			or JSON.stringify(contract.get("ordered_phases", [])) != JSON.stringify(PHASES):
		return _result(false, &"cargo_delivery_receipts_not_committed")
	var ledger: Dictionary = {}
	for entry: Dictionary in inventory.get("committed_transfers", []):
		if str(entry.get("transfer_id", "")) == str(transfer.get("transfer_id", "")) and int(entry.get("receipt_id", 0)) == int(transfer.get("receipt_id", -1)):
			ledger = {"transfer_id": String(entry.get("transfer_id", "")), "receipt_id": int(entry.get("receipt_id", 0))}
	var proof: Dictionary = {"ledger": ledger}
	for key: String in ["source_quantity_after", "destination_quantity_after", "source_used_capacity_after", "destination_used_capacity_after"]:
		proof[key] = transfer.get(key)
	var delivery: Dictionary = {
		"contract_id": CONTRACT_ID, "item_id": ITEM_ID, "quantity": 1,
		"phase_count": 3, "ordered_phases": PHASES.duplicate(), "elapsed_seconds": float(cargo.elapsed_seconds),
		"generation": generation, "deadline_seconds": 120.0, "transfer_proof": proof,
		"transfer_receipt": {"transfer_id": String(transfer.transfer_id), "receipt_id": int(transfer.receipt_id), "replay_allowed": false},
		"reward_receipt": {"activity_id": REWARD_ACTIVITY_ID, "reward_id": REWARD_ID, "granted": false, "replay_allowed": false},
	}
	var record: Dictionary = {"schema_version": SCHEMA_VERSION, "payload_kind": PAYLOAD_KIND, "slot_id": String(_slot_id), "delivery": delivery}
	var validation: Dictionary = validate_record(record)
	return {"accepted": bool(validation.accepted), "reason": validation.reason, "record": record if validation.accepted else {}}


func validate_record(candidate: Variant) -> Dictionary:
	if candidate is Dictionary and candidate.get("schema_version") == 1:
		return _validate_legacy_record(candidate)
	return validate_terminal_record(candidate, _slot_id)


static func validate_terminal_record(candidate: Variant, slot_id: StringName = SLOT_ID) -> Dictionary:
	var invalid: Dictionary = {"accepted": false, "reason": &"cargo_delivery_payload_corrupt"}
	if not candidate is Dictionary:
		return invalid
	var record: Dictionary = candidate
	if record.size() != 4 or record.get("schema_version") != SCHEMA_VERSION or str(record.get("payload_kind", "")) != PAYLOAD_KIND or str(record.get("slot_id", "")) != String(slot_id) or not record.get("delivery") is Dictionary:
		return invalid
	var delivery: Dictionary = record.delivery
	var transfer: Variant = delivery.get("transfer_receipt")
	var reward: Variant = delivery.get("reward_receipt")
	var proof: Variant = delivery.get("transfer_proof")
	var elapsed: Variant = delivery.get("elapsed_seconds")
	if delivery.size() != 11 or str(delivery.get("contract_id", "")) != CONTRACT_ID or str(delivery.get("item_id", "")) != ITEM_ID or not _integral(delivery.get("quantity")) or delivery.get("quantity") != 1 or not _integral(delivery.get("phase_count")) or delivery.get("phase_count") != 3 or JSON.stringify(delivery.get("ordered_phases", [])) != JSON.stringify(PHASES) or not (delivery.get("deadline_seconds") is int or delivery.get("deadline_seconds") is float) or delivery.get("deadline_seconds") != 120.0 \
			or not _integral(delivery.get("generation")) or int(delivery.generation) < 1 or int(delivery.generation) > CargoTransferAuthority.MAX_SAFE_INTEGER \
			or not (elapsed is float or elapsed is int) or not is_finite(float(elapsed)) or float(elapsed) < 0.0 or float(elapsed) >= 120.0 \
			or not transfer is Dictionary or not reward is Dictionary or not proof is Dictionary:
		return invalid
	if transfer.size() != 3 or str(transfer.get("transfer_id", "")) != "%s_g%d" % [CONTRACT_ID, int(delivery.generation)] or not _integral(transfer.get("receipt_id")) or int(transfer.receipt_id) < 1 or int(transfer.receipt_id) > CargoTransferAuthority.MAX_SAFE_INTEGER or transfer.get("replay_allowed") is not bool or transfer.get("replay_allowed") != false \
			or reward.size() != 4 or str(reward.get("activity_id", "")) != REWARD_ACTIVITY_ID or str(reward.get("reward_id", "")) != REWARD_ID or reward.get("granted") is not bool or reward.get("replay_allowed") is not bool or reward.get("replay_allowed") != false \
			or proof.size() != 5 or not proof.get("ledger") is Dictionary:
		return invalid
	var ledger: Dictionary = proof.ledger
	if ledger.size() != 2 or str(ledger.get("transfer_id", "")) != str(transfer.transfer_id) or not _integral(ledger.get("receipt_id")) or int(ledger.receipt_id) != int(transfer.receipt_id):
		return invalid
	for key: String in ["source_quantity_after", "destination_quantity_after", "source_used_capacity_after", "destination_used_capacity_after"]:
		if not _integral(proof.get(key)) or int(proof[key]) < 0 or int(proof[key]) > CargoManifest.MAX_CAPACITY:
			return invalid
	if int(proof.destination_quantity_after) < 1 or int(proof.source_used_capacity_after) < int(proof.source_quantity_after) or int(proof.destination_used_capacity_after) < int(proof.destination_quantity_after):
		return invalid
	return {"accepted": true, "reason": &"cargo_delivery_payload_valid"}


func _validate_legacy_record(candidate: Variant) -> Dictionary:
	if not candidate is Dictionary:
		return _result(false, &"cargo_delivery_payload_corrupt")
	var record := candidate as Dictionary
	if record.size() != 4 or not _integral(record.get("schema_version")) \
			or int(record.get("schema_version", 0)) != 1 \
			or str(record.get("payload_kind", "")) != PAYLOAD_KIND \
			or StringName(record.get("slot_id", &"")) != _slot_id \
			or not record.get("delivery") is Dictionary:
		return _result(false, &"cargo_delivery_payload_corrupt")
	var delivery := record.delivery as Dictionary
	var transfer := delivery.get("transfer_receipt", {}) as Dictionary
	var reward := delivery.get("reward_receipt", {}) as Dictionary
	var elapsed: Variant = delivery.get("elapsed_seconds", null)
	if delivery.size() != 7 or str(delivery.get("contract_id", "")) != CONTRACT_ID \
			or not CargoItemDefinition.is_stable_id(StringName(delivery.get("item_id", &""))) \
			or not _integral(delivery.get("quantity")) or int(delivery.get("quantity", 0)) < 1 \
			or not _integral(delivery.get("phase_count")) \
			or int(delivery.get("phase_count", 0)) < 1 \
			or not (elapsed is float or elapsed is int) or not is_finite(float(elapsed)) \
			or float(elapsed) < 0.0 or float(elapsed) > 86_400.0 \
			or transfer.size() != 3 \
			or not CargoItemDefinition.is_stable_id(StringName(transfer.get("transfer_id", &""))) \
			or not _integral(transfer.get("receipt_id")) \
			or int(transfer.get("receipt_id", 0)) < 1 \
			or transfer.get("replay_allowed") is not bool \
			or bool(transfer.get("replay_allowed", true)) \
			or reward.size() != 4 or str(reward.get("activity_id", "")) != REWARD_ACTIVITY_ID \
			or str(reward.get("reward_id", "")) != REWARD_ID \
			or reward.get("granted") is not bool or bool(reward.get("granted", true)) \
			or reward.get("replay_allowed") is not bool \
			or bool(reward.get("replay_allowed", true)):
		return _result(false, &"cargo_delivery_payload_corrupt")
	return _result(true, &"cargo_delivery_payload_valid")


func get_store_generation() -> int:
	return int(_store.call(&"get_generation")) if _configured() else -1


func _configured() -> bool:
	return _store != null and is_instance_valid(_store) and not _slot_id.is_empty()


static func _integral(value: Variant) -> bool:
	return value is int or (value is float and is_finite(value) and value == floor(value))


func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {"accepted": accepted, "reason": reason}
