class_name GameFlowRewardAuthority
extends RefCounted

## The production reward authority for the four GameFlow-owned Cinder
## activities. It turns the existing non-authoritative completion handoff into
## one persisted Shipyard return-incentive receipt. It owns no activity,
## inventory, currency, ship, berth, combat, or network state.

const SCHEMA_VERSION := 1
const PAYLOAD_KIND := "game_flow_reward_store"
const SLOT_ID: StringName = &"game_flow_reward_store"
const AUTHORITY_ID: StringName = &"game_flow_reward_authority"
const MAX_SAFE_GENERATION := 9_007_199_254_740_991
const COMMIT_PREFIX := "game-flow-reward-"

const RACE_ACTIVITY_ID: StringName = &"cinder_reach_checkpoint_route"
const PATROL_ACTIVITY_ID: StringName = &"cinder_relay_patrol"
const CONVOY_ACTIVITY_ID: StringName = &"cinder_reach_emberline_convoy"
const CARGO_ACTIVITY_ID: StringName = &"jovian_fabrication_kit_delivery"

const RACE_REWARD_ID: StringName = &"return_race_record_to_shipyard"
const PATROL_REWARD_ID: StringName = &"return_patrol_log_to_shipyard"
const CONVOY_REWARD_ID: StringName = &"return_convoy_credit_to_shipyard"
const CARGO_REWARD_ID: StringName = &"return_fabrication_kits_to_shipyard"

const ACTIVITY_REWARDS := {
	RACE_ACTIVITY_ID: RACE_REWARD_ID,
	PATROL_ACTIVITY_ID: PATROL_REWARD_ID,
	CONVOY_ACTIVITY_ID: CONVOY_REWARD_ID,
	CARGO_ACTIVITY_ID: CARGO_REWARD_ID,
}
const REWARD_LABELS := {
	RACE_REWARD_ID: "Race record accepted",
	PATROL_REWARD_ID: "Patrol log accepted",
	CONVOY_REWARD_ID: "Emberline escort credit logged",
	CARGO_REWARD_ID: "Fabrication kits returned",
}
const REQUEST_KEYS := [
	"activity_id",
	"activity_generation",
	"reward_id",
	"reward_authority",
	"granted",
]
const RECORD_KEYS := [
	"schema_version",
	"payload_kind",
	"authority_id",
	"store_id",
	"receipt_serial",
	"total_receipts",
	"reward_counts",
	"last_receipt",
]
const RECEIPT_KEYS := [
	"receipt_id",
	"activity_id",
	"activity_generation",
	"reward_id",
	"reward_label",
	"granted",
	"replay_allowed",
]

var _store: RefCounted
var _configured := false
var _commit_active := false
var _record: Dictionary = {}
var _consumed_generations: Dictionary = {}
var _last_result: Dictionary = {}


func configure(store: RefCounted) -> Dictionary:
	if _configured or store == null \
			or not store.has_method(&"get_snapshot") \
			or not store.has_method(&"get_generation") \
			or not store.has_method(&"commit"):
		return _reject(&"reward_authority_configuration_invalid")
	var payload: Variant = store.call(&"get_snapshot")
	if not payload is Dictionary:
		return _reject(&"reward_store_snapshot_invalid")
	var candidate := _empty_record()
	if (payload as Dictionary).has(String(SLOT_ID)):
		var stored: Variant = (payload as Dictionary).get(String(SLOT_ID))
		var validation := validate_record(stored)
		if not bool(validation.get("accepted", false)):
			return _reject(StringName(validation.get(
				"reason", &"reward_store_payload_corrupt"
			)))
		candidate = (stored as Dictionary).duplicate(true)
	_store = store
	_record = candidate
	_configured = true
	return _accept(&"reward_authority_configured")


## Accepts only the exact request produced by NearbyActivityRewardAdapter. The
## adapter and this authority both fence a completion generation, so a repeated
## signal cannot advance either the receipt serial or the atomic store.
func commit(request: Variant) -> Dictionary:
	if not _configured or _store == null:
		return _reject(&"reward_authority_unavailable")
	if _commit_active:
		return _reject(&"reward_commit_reentrant")
	var request_validation := _validate_request(request)
	if not bool(request_validation.get("accepted", false)):
		return _reject(StringName(request_validation.get(
			"reason", &"reward_request_invalid"
		)))
	var accepted_request := request as Dictionary
	var activity_id := StringName(accepted_request.get("activity_id", &""))
	var activity_generation := int(accepted_request.get("activity_generation", 0))
	var reward_id := StringName(accepted_request.get("reward_id", &""))
	if int(_consumed_generations.get(activity_id, -1)) == activity_generation:
		return _reject(&"reward_generation_already_committed")

	_commit_active = true
	var payload: Variant = _store.call(&"get_snapshot")
	if not payload is Dictionary:
		_commit_active = false
		return _reject(&"reward_store_snapshot_invalid")
	var current := _empty_record()
	if (payload as Dictionary).has(String(SLOT_ID)):
		var stored: Variant = (payload as Dictionary).get(String(SLOT_ID))
		var stored_validation := validate_record(stored)
		if not bool(stored_validation.get("accepted", false)):
			_commit_active = false
			return _reject(StringName(stored_validation.get(
				"reason", &"reward_store_payload_corrupt"
			)))
		current = (stored as Dictionary).duplicate(true)

	var receipt_serial := int(current.get("receipt_serial", 0)) + 1
	if receipt_serial < 1 or receipt_serial > MAX_SAFE_GENERATION:
		_commit_active = false
		return _reject(&"reward_receipt_serial_exhausted")
	var reward_counts := (current.get("reward_counts", {}) as Dictionary).duplicate(true)
	var reward_key := String(reward_id)
	reward_counts[reward_key] = int(reward_counts.get(reward_key, 0)) + 1
	var receipt := {
		"receipt_id": receipt_serial,
		"activity_id": String(activity_id),
		"activity_generation": activity_generation,
		"reward_id": reward_key,
		"reward_label": String(REWARD_LABELS[reward_id]),
		"granted": true,
		"replay_allowed": false,
	}.duplicate(true)
	var next_record := {
		"schema_version": SCHEMA_VERSION,
		"payload_kind": PAYLOAD_KIND,
		"authority_id": String(AUTHORITY_ID),
		"store_id": String(SLOT_ID),
		"receipt_serial": receipt_serial,
		"total_receipts": receipt_serial,
		"reward_counts": reward_counts,
		"last_receipt": receipt,
	}.duplicate(true)
	var next_validation := validate_record(next_record)
	if not bool(next_validation.get("accepted", false)):
		_commit_active = false
		return _reject(StringName(next_validation.get(
			"reason", &"reward_store_payload_corrupt"
		)))
	var store_generation := int(_store.call(&"get_generation"))
	if store_generation < 0 or store_generation >= 2_147_483_647:
		_commit_active = false
		return _reject(&"reward_store_generation_exhausted")
	var next_payload := (payload as Dictionary).duplicate(true)
	next_payload[String(SLOT_ID)] = next_record
	var committed := _store.call(
		&"commit",
		next_payload,
		store_generation,
		"%s%010d" % [COMMIT_PREFIX, store_generation + 1]
	) as Dictionary
	_commit_active = false
	if not bool(committed.get("accepted", false)):
		var failure := _reject(&"reward_store_commit_rejected")
		failure["store_result"] = committed.duplicate(true)
		_last_result = failure.duplicate(true)
		return failure
	_consumed_generations[activity_id] = activity_generation
	_record = next_record
	var result := {
		"accepted": true,
		"reason": &"reward_receipt_committed",
		"reward_authority_id": AUTHORITY_ID,
		"reward_store_id": SLOT_ID,
		"granted": true,
		"store_generation": int(_store.call(&"get_generation")),
		"receipt": receipt.duplicate(true),
	}.duplicate(true)
	_last_result = result.duplicate(true)
	return result


func validate_record(candidate: Variant) -> Dictionary:
	if not candidate is Dictionary:
		return _result(false, &"reward_store_payload_corrupt")
	var record := candidate as Dictionary
	if not _has_exact_keys(record, RECORD_KEYS) \
			or not _integral(record.get("schema_version")) \
			or int(record.get("schema_version", 0)) != SCHEMA_VERSION \
			or str(record.get("payload_kind", "")) != PAYLOAD_KIND \
			or StringName(record.get("authority_id", &"")) != AUTHORITY_ID \
			or StringName(record.get("store_id", &"")) != SLOT_ID \
			or not _integral(record.get("receipt_serial")) \
			or not _integral(record.get("total_receipts")) \
			or not record.get("reward_counts") is Dictionary \
			or not record.get("last_receipt") is Dictionary:
		return _result(false, &"reward_store_payload_corrupt")
	var receipt_serial := int(record.get("receipt_serial", -1))
	var total_receipts := int(record.get("total_receipts", -1))
	if receipt_serial < 0 or receipt_serial > MAX_SAFE_GENERATION \
			or total_receipts != receipt_serial:
		return _result(false, &"reward_store_payload_corrupt")
	var count_sum := 0
	for raw_reward_id: Variant in (record.get("reward_counts", {}) as Dictionary):
		var reward_id := StringName(str(raw_reward_id))
		var count: Variant = (record.reward_counts as Dictionary).get(raw_reward_id)
		if not REWARD_LABELS.has(reward_id) or not _integral(count) \
				or int(count) < 1 or int(count) > MAX_SAFE_GENERATION:
			return _result(false, &"reward_store_payload_corrupt")
		count_sum += int(count)
	if count_sum != total_receipts:
		return _result(false, &"reward_store_payload_corrupt")
	var receipt := record.get("last_receipt", {}) as Dictionary
	if total_receipts == 0:
		if not receipt.is_empty():
			return _result(false, &"reward_store_payload_corrupt")
		return _result(true, &"reward_store_payload_valid")
	if not _has_exact_keys(receipt, RECEIPT_KEYS) \
			or not _integral(receipt.get("receipt_id")) \
			or int(receipt.get("receipt_id", -1)) != receipt_serial \
			or not _integral(receipt.get("activity_generation")) \
			or int(receipt.get("activity_generation", 0)) < 1 \
			or int(receipt.get("activity_generation", 0)) > MAX_SAFE_GENERATION \
			or receipt.get("granted") is not bool \
			or not bool(receipt.get("granted", false)) \
			or receipt.get("replay_allowed") is not bool \
			or bool(receipt.get("replay_allowed", true)):
		return _result(false, &"reward_store_payload_corrupt")
	var activity_id := StringName(receipt.get("activity_id", &""))
	var reward_id := StringName(receipt.get("reward_id", &""))
	if not ACTIVITY_REWARDS.has(activity_id) \
			or StringName(ACTIVITY_REWARDS[activity_id]) != reward_id \
			or not REWARD_LABELS.has(reward_id) \
			or str(receipt.get("reward_label", "")) != str(REWARD_LABELS[reward_id]) \
			or int((record.reward_counts as Dictionary).get(String(reward_id), 0)) < 1:
		return _result(false, &"reward_store_payload_corrupt")
	return _result(true, &"reward_store_payload_valid")


func get_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"configured": _configured,
		"reward_authority_id": AUTHORITY_ID,
		"reward_store_id": SLOT_ID,
		"store_generation": int(_store.call(&"get_generation")) if _store != null else -1,
		"record": _record.duplicate(true),
		"last_result": _last_result.duplicate(true),
		"commit_active": _commit_active,
		"reward_grant_authority": _configured,
		"activity_authority": false,
		"inventory_authority": false,
		"currency_authority": false,
		"ship_authority": false,
		"berth_authority": false,
		"combat_authority": false,
		"network_authority": false,
	}.duplicate(true)


func _validate_request(candidate: Variant) -> Dictionary:
	if not candidate is Dictionary:
		return _result(false, &"reward_request_invalid")
	var request := candidate as Dictionary
	if not _has_exact_keys(request, REQUEST_KEYS) \
			or not _integral(request.get("activity_generation")) \
			or request.get("reward_authority") is not bool \
			or bool(request.get("reward_authority", true)) \
			or request.get("granted") is not bool \
			or bool(request.get("granted", true)):
		return _result(false, &"reward_request_invalid")
	var generation := int(request.get("activity_generation", 0))
	var activity_id := StringName(request.get("activity_id", &""))
	var reward_id := StringName(request.get("reward_id", &""))
	if generation < 1 or generation > MAX_SAFE_GENERATION:
		return _result(false, &"reward_request_invalid")
	if not ACTIVITY_REWARDS.has(activity_id):
		return _result(false, &"reward_activity_unknown")
	if StringName(ACTIVITY_REWARDS[activity_id]) != reward_id:
		return _result(false, &"reward_contract_mismatch")
	return _result(true, &"reward_request_valid")


func _empty_record() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"payload_kind": PAYLOAD_KIND,
		"authority_id": String(AUTHORITY_ID),
		"store_id": String(SLOT_ID),
		"receipt_serial": 0,
		"total_receipts": 0,
		"reward_counts": {},
		"last_receipt": {},
	}.duplicate(true)


func _has_exact_keys(value: Dictionary, keys: Array) -> bool:
	if value.size() != keys.size():
		return false
	for key: Variant in keys:
		if not value.has(key):
			return false
	return true


func _integral(value: Variant) -> bool:
	return value is int or (
		value is float and is_finite(float(value)) and float(value) == floor(float(value))
	)


func _accept(reason: StringName) -> Dictionary:
	var result := _result(true, reason)
	_last_result = result.duplicate(true)
	return result


func _reject(reason: StringName) -> Dictionary:
	var result := _result(false, reason)
	_last_result = result.duplicate(true)
	return result


func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {"accepted": accepted, "reason": reason}
