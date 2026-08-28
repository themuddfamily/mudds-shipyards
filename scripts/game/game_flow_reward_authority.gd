class_name GameFlowRewardAuthority
extends RefCounted

## The production reward authority for the four GameFlow-owned route activities,
## the Cinder derelict scan and beacon run, the physical Heavy Breach board, and
## the retained Ember relay survey. It turns their non-authoritative completion
## handoffs into one persisted Shipyard return-incentive receipt. It owns no
## activity, inventory, currency, ship, berth, combat, or network state.

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
const CINDER_SCAN_ACTIVITY_ID: StringName = &"cinder_derelict_structure_scan"
const CINDER_BEACON_ACTIVITY_ID: StringName = &"cinder_debris_beacon_traversal"
const HEAVY_BREACH_ACTIVITY_ID: StringName = &"shipyard_heavy_breach"
const EMBER_RELAY_ACTIVITY_ID: StringName = &"ember_beacon_survey"

const RACE_REWARD_ID: StringName = &"return_race_record_to_shipyard"
const PATROL_REWARD_ID: StringName = &"return_patrol_log_to_shipyard"
const CONVOY_REWARD_ID: StringName = &"return_convoy_credit_to_shipyard"
const CARGO_REWARD_ID: StringName = &"return_fabrication_kits_to_shipyard"
const CINDER_SCAN_REWARD_ID: StringName = &"derelict_material_sample"
const CINDER_BEACON_REWARD_ID: StringName = &"debris_route_navigation_data"
const HEAVY_BREACH_REWARD_ID: StringName = &"return_heavy_breach_credit"
const EMBER_RELAY_REWARD_ID: StringName = &"ember_beacon_data"

const ACTIVITY_REWARDS := {
	RACE_ACTIVITY_ID: RACE_REWARD_ID,
	PATROL_ACTIVITY_ID: PATROL_REWARD_ID,
	CONVOY_ACTIVITY_ID: CONVOY_REWARD_ID,
	CARGO_ACTIVITY_ID: CARGO_REWARD_ID,
	CINDER_SCAN_ACTIVITY_ID: CINDER_SCAN_REWARD_ID,
	CINDER_BEACON_ACTIVITY_ID: CINDER_BEACON_REWARD_ID,
	HEAVY_BREACH_ACTIVITY_ID: HEAVY_BREACH_REWARD_ID,
	EMBER_RELAY_ACTIVITY_ID: EMBER_RELAY_REWARD_ID,
}
const REWARD_LABELS := {
	RACE_REWARD_ID: "Race record accepted",
	PATROL_REWARD_ID: "Patrol log accepted",
	CONVOY_REWARD_ID: "Emberline escort credit logged",
	CARGO_REWARD_ID: "Fabrication kits returned",
	CINDER_SCAN_REWARD_ID: "Derelict material sample recorded",
	CINDER_BEACON_REWARD_ID: "Debris navigation data recorded",
	HEAVY_BREACH_REWARD_ID: "Heavy Breach credit logged",
	EMBER_RELAY_REWARD_ID: "Survey data accepted",
}
const REQUEST_KEYS := [
	"activity_id",
	"activity_generation",
	"reward_id",
	"reward_authority",
	"granted",
]
const EMBER_RELAY_REQUEST_KEYS := [
	"activity_generation", "activity_id", "attachment_generation",
	"objective_id", "production_commit_id", "production_evidence",
	"recovery_id", "return_target_id", "reward_authority_id", "reward_id",
	"reward_store_id", "run_generation", "world_id",
]
const EMBER_RELAY_EVIDENCE_KEYS := [
	"activity_generation", "actor_instance_id", "actor_kind", "caller_serial",
	"completion_attachment_generation", "craft_instance_id",
	"host_attachment_generation", "host_generation", "host_instance_id",
	"owner_generation", "physics_frame", "session_instance_id",
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


## Accepts only an exact request produced by NearbyActivityRewardAdapter or the
## retained Ember surface binding. Each producer and this authority fence a
## completion generation, so a repeated signal cannot advance either the
## receipt serial or the atomic store.
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
	var nearby_request := _has_exact_keys(request, REQUEST_KEYS)
	var ember_request := _has_exact_keys(request, EMBER_RELAY_REQUEST_KEYS)
	if not nearby_request and not ember_request:
		return _result(false, &"reward_request_invalid")
	if not _integral(request.get("activity_generation")):
		return _result(false, &"reward_request_invalid")
	if nearby_request and (
		request.get("reward_authority") is not bool
		or bool(request.get("reward_authority", true))
		or request.get("granted") is not bool
		or bool(request.get("granted", true))
	):
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
	# The Ember survey is admitted only through its evidence-bearing surface
	# binding contract; the compact nearby-activity shape cannot impersonate it.
	if activity_id == EMBER_RELAY_ACTIVITY_ID and not ember_request:
		return _result(false, &"reward_request_invalid")
	if ember_request:
		var ember_rejection := _validate_ember_relay_request(request)
		if not ember_rejection.is_empty():
			return _result(false, ember_rejection)
	return _result(true, &"reward_request_valid")


func _validate_ember_relay_request(request: Dictionary) -> StringName:
	if StringName(request.get("activity_id", &"")) != EMBER_RELAY_ACTIVITY_ID \
			or StringName(request.get("reward_id", &"")) != EMBER_RELAY_REWARD_ID \
			or StringName(request.get("world_id", &"")) != &"ember_moon" \
			or StringName(request.get("objective_id", &"")) \
				!= &"survey_beacon_network" \
			or StringName(request.get("reward_store_id", &"")) != SLOT_ID \
			or StringName(request.get("reward_authority_id", &"")) \
				!= AUTHORITY_ID \
			or StringName(request.get("return_target_id", &"")) \
				!= &"mudds_shipyards" \
			or StringName(request.get("recovery_id", &"")) \
				!= &"return_to_landed_ship" \
			or not _integral(request.get("run_generation")) \
			or int(request.get("run_generation", 0)) < 1 \
			or not _integral(request.get("attachment_generation")) \
			or int(request.get("attachment_generation", 0)) < 1:
		return &"reward_request_invalid"
	var expected_commit_id := "ember-relay-survey:%d:%d" % [
		int(request.get("run_generation", 0)),
		int(request.get("activity_generation", 0)),
	]
	if str(request.get("production_commit_id", "")) != expected_commit_id:
		return &"reward_request_invalid"
	var evidence_value: Variant = request.get("production_evidence")
	if not evidence_value is Dictionary \
			or not _has_exact_keys(
				evidence_value as Dictionary, EMBER_RELAY_EVIDENCE_KEYS
			):
		return &"reward_request_invalid"
	var evidence := evidence_value as Dictionary
	for key in EMBER_RELAY_EVIDENCE_KEYS:
		if key == "actor_kind":
			continue
		if not evidence.get(key) is int:
			return &"reward_request_invalid"
	if not evidence.get("actor_kind") is StringName \
			or StringName(evidence.get("actor_kind", &"")) != &"player" \
			or int(evidence.get("activity_generation", 0)) \
				!= int(request.get("activity_generation", -1)) \
			or int(evidence.get("completion_attachment_generation", 0)) \
				!= int(request.get("attachment_generation", -1)):
		return &"reward_request_invalid"
	return &""


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
