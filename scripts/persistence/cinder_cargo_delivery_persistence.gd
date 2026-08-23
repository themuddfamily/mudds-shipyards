class_name CinderCargoDeliveryPersistence
extends RefCounted

## Namespaced atomic-store bridge for one authenticated terminal Cinder cargo
## delivery. It never stores manifests, handles, inventory, or active progress.

const SCHEMA_VERSION := 1
const PAYLOAD_KIND := "cinder_cargo_delivery_receipt"
const CONTRACT_ID := "cinder_platform_supply_run"
const REWARD_ACTIVITY_ID := "cinder_kit_cargo_run"
const REWARD_ID := "return_fabrication_kits_to_shipyard"

var _store: RefCounted
var _slot_id: StringName = &""


func configure(store: RefCounted, slot_id: StringName) -> Dictionary:
	if _store != null or store == null or str(slot_id).strip_edges().is_empty() \
			or not store.has_method(&"load") or not store.has_method(&"commit") \
			or not store.has_method(&"get_snapshot") \
			or not store.has_method(&"get_generation"):
		return _result(false, &"cargo_delivery_persistence_configuration_invalid")
	_store = store
	_slot_id = slot_id
	return _result(true, &"cargo_delivery_persistence_configured")


func save(cargo: Dictionary, handoff: Dictionary, commit_id: String) -> Dictionary:
	if not _configured() or commit_id.strip_edges().is_empty():
		return _result(false, &"cargo_delivery_save_invalid")
	var captured := capture(cargo, handoff)
	if not bool(captured.get("accepted", false)):
		return captured
	var loaded := _store.call(&"load") as Dictionary
	if not bool(loaded.get("accepted", false)):
		return loaded
	var payload := _store.call(&"get_snapshot") as Dictionary
	payload[String(_slot_id)] = captured.record
	var committed := _store.call(
		&"commit", payload, int(_store.call(&"get_generation")), commit_id
	) as Dictionary
	committed["binding_reason"] = (
		&"cargo_delivery_saved" if bool(committed.get("accepted", false)) \
		else &"store_rejected"
	)
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
	return {
		"accepted": true,
		"reason": &"cargo_delivery_loaded",
		"store_generation": int(loaded.get("generation", -1)),
		"delivery": (payload[key] as Dictionary).delivery.duplicate(true),
	}.duplicate(true)


func capture(cargo: Dictionary, handoff: Dictionary) -> Dictionary:
	var contract := cargo.get("contract", {}) as Dictionary
	var transfer := cargo.get("accepted_receipt", {}) as Dictionary
	var reward := handoff.get("reward_request", {}) as Dictionary
	var generation := int(cargo.get("generation", 0))
	if int(cargo.get("state", -1)) != CargoDeliveryActivity.State.COMPLETED \
			or generation < 1 or StringName(cargo.get("contract_id", &"")) != CONTRACT_ID \
			or not bool(transfer.get("accepted", false)) \
			or StringName(transfer.get("reason", &"")) != &"committed" \
			or StringName(transfer.get("transfer_id", &"")) \
				!= StringName(cargo.get("expected_transfer_id", &"")) \
			or StringName(transfer.get("item_id", &"")) \
				!= StringName(contract.get("item_id", &"")) \
			or int(transfer.get("quantity", 0)) != int(contract.get("quantity", -1)) \
			or int(transfer.get("receipt_id", 0)) < 1 \
			or not bool(handoff.get("accepted", false)) \
			or StringName(handoff.get("reason", &"")) != &"reward_request_committed" \
			or StringName(reward.get("activity_id", &"")) != REWARD_ACTIVITY_ID \
			or StringName(reward.get("reward_id", &"")) != REWARD_ID \
			or int(reward.get("activity_generation", -1)) != generation \
			or bool(reward.get("granted", true)):
		return _result(false, &"cargo_delivery_receipts_not_committed")
	var delivery := {
		"contract_id": CONTRACT_ID,
		"item_id": String(transfer.get("item_id", &"")),
		"quantity": int(transfer.get("quantity", 0)),
		"phase_count": int(cargo.get("phase_count", 0)),
		"elapsed_seconds": float(cargo.get("elapsed_seconds", 0.0)),
		"transfer_receipt": {
			"transfer_id": String(transfer.get("transfer_id", &"")),
			"receipt_id": int(transfer.get("receipt_id", 0)),
			"replay_allowed": false,
		},
		"reward_receipt": {
			"activity_id": REWARD_ACTIVITY_ID,
			"reward_id": REWARD_ID,
			"granted": false,
			"replay_allowed": false,
		},
	}.duplicate(true)
	var record := {
		"schema_version": SCHEMA_VERSION,
		"payload_kind": PAYLOAD_KIND,
		"slot_id": String(_slot_id),
		"delivery": delivery,
	}.duplicate(true)
	var validation := validate_record(record)
	return {
		"accepted": bool(validation.get("accepted", false)),
		"reason": &"cargo_delivery_captured" if bool(validation.get("accepted", false)) \
			else validation.get("reason", &"cargo_delivery_payload_corrupt"),
		"record": record if bool(validation.get("accepted", false)) else {},
	}.duplicate(true)


func validate_record(candidate: Variant) -> Dictionary:
	if not candidate is Dictionary:
		return _result(false, &"cargo_delivery_payload_corrupt")
	var record := candidate as Dictionary
	if record.size() != 4 or not _integral(record.get("schema_version")) \
			or int(record.get("schema_version", 0)) != SCHEMA_VERSION \
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


func _integral(value: Variant) -> bool:
	return value is int or (value is float and is_finite(value) and value == floor(value))


func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {"accepted": accepted, "reason": reason}
