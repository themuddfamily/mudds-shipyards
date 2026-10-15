class_name EmberRelaySurveyPersistenceBinding
extends RefCounted

## Namespaced atomic-store bridge for one Ember relay-survey slot. It persists
## either an already committed reward observation or a detached active-journey
## recovery receipt, and restores no ActivityDirector, movement, or reward
## authority.

const ReturnPersistenceAdapterScript := preload(
	"res://scripts/world/planetary_return_persistence_adapter.gd"
)
const SCHEMA_VERSION := 1
const PAYLOAD_KIND := "ember_relay_survey_completion"
const ACTIVE_JOURNEY_PAYLOAD_KIND := "ember_relay_survey_active_journey"
const ACTIVITY_ID := "ember_beacon_survey"
const WORLD_ID := "ember_moon"
const REWARD_ID := "ember_beacon_data"
const REWARD_STORE_ID := "game_flow_reward_store"
const REWARD_AUTHORITY_ID := "game_flow_reward_authority"
const OPTIONAL_CHECKPOINT_ID := "ember_bunker_gantry_log"
const OPTIONAL_INTERACTION_ID := "ember_bunker_gantry_survey"
const OPTIONAL_RESPONSE_ID := "ember_bunker_service_alcove"

var _store: RefCounted
var _slot_id: StringName = &""
var _active_journey_adapter: RefCounted
var _loaded_active_journey_receipt := ""


func configure(store: RefCounted, slot_id: StringName) -> Dictionary:
	if _store != null or store == null or str(slot_id).strip_edges().is_empty() \
			or not store.has_method(&"load") or not store.has_method(&"commit") \
			or not store.has_method(&"get_snapshot") \
			or not store.has_method(&"get_generation"):
		return _result(false, &"survey_persistence_configuration_invalid")
	_store = store
	_slot_id = slot_id
	return _result(true, &"survey_persistence_configured")


func save(surface_snapshot: Variant, commit_id: String) -> Dictionary:
	if not _configured() or commit_id.strip_edges().is_empty():
		return _result(false, &"survey_persistence_save_invalid")
	var captured := capture(surface_snapshot)
	if not bool(captured.get("accepted", false)):
		return captured
	var expected_generation := int(_store.call(&"get_generation"))
	var payload := _store.call(&"get_snapshot") as Dictionary
	payload[String(_slot_id)] = captured.record
	var committed := _store.call(
		&"commit", payload, expected_generation, commit_id
	) as Dictionary
	committed["binding_reason"] = (
		&"saved" if bool(committed.get("accepted", false)) else &"store_rejected"
	)
	return committed


func load() -> Dictionary:
	if not _configured():
		return _result(false, &"survey_persistence_unavailable")
	var loaded := _store.call(&"load") as Dictionary
	if not bool(loaded.get("accepted", false)):
		return loaded
	var payload := loaded.get("payload", {}) as Dictionary
	var slot_key := String(_slot_id)
	if not payload.has(slot_key):
		return _result(false, &"survey_persistence_not_found")
	var record: Variant = payload.get(slot_key)
	if record is Dictionary and str(
		(record as Dictionary).get("payload_kind", "")
	) == ACTIVE_JOURNEY_PAYLOAD_KIND:
		return _result(false, &"survey_persistence_active_journey_present")
	var validation := validate_record(record)
	if not bool(validation.get("accepted", false)):
		return validation
	return {
		"accepted": true,
		"reason": &"survey_persistence_loaded",
		"store_generation": int(loaded.get("generation", -1)),
		"completion": (record as Dictionary).completion.duplicate(true),
		"reward_replay_allowed": false,
	}.duplicate(true)


## Atomically replaces this slot with a detached active-journey recovery
## receipt. The existing UserDataStore remains the only filesystem and
## transaction authority; this bridge captures no actor or reward capability.
func save_interrupted_journey(
		session_contract: Object,
		route_snapshot: Variant,
		commit_id: String
	) -> Dictionary:
	if not _configured() or commit_id.strip_edges().is_empty():
		return _result(false, &"survey_active_journey_save_invalid")
	var adapter := ReturnPersistenceAdapterScript.new() as RefCounted
	var captured := adapter.call(
		&"capture_interrupted_journey", session_contract, route_snapshot
	) as Dictionary
	if not bool(captured.get("accepted", false)):
		return captured
	var recovery := _wire_copy(captured) as Dictionary
	var record := {
		"schema_version": float(SCHEMA_VERSION),
		"payload_kind": ACTIVE_JOURNEY_PAYLOAD_KIND,
		"slot_id": String(_slot_id),
		"receipt_sha256": _digest(recovery),
		# Keep the established five-key wire envelope. `payload_kind` defines
		# whether this legacy-named field is a completion or a recovery receipt.
		"completion": recovery,
	}
	var expected_generation := int(_store.call(&"get_generation"))
	var payload := _store.call(&"get_snapshot") as Dictionary
	var debts := _completed_debts(payload)
	if not bool(debts.get("accepted", false)):
		return debts
	if not (debts.records as Array).is_empty():
		if debts.records[0].completion.route_identity != recovery.route_identity:
			return _result(false, &"survey_completed_debt_conflict")
		# Keep the original durable identity through adoption and shutdown. Only
		# the reward authority's atomic payment may remove this obligation.
		return _result(true, &"survey_completed_debt_retained")
	payload[String(_slot_id)] = record
	var committed := _store.call(
		&"commit", payload, expected_generation, commit_id
	) as Dictionary
	committed["binding_reason"] = (
		&"active_journey_saved" if bool(committed.get("accepted", false)) \
		else &"store_rejected"
	)
	committed["receipt_sha256"] = str(recovery.get("receipt_sha256", ""))
	return committed


## Loads a passive resume description. The caller must separately reconstruct
## the correct frame, restore the detached save-session contract with a fresh
## attachment generation, and then retire this receipt.
## An already observed receipt may be re-read by its exact hash immediately
## before retirement, preserving unrelated commits made since admission.
func load_interrupted_journey(expected_receipt_sha256: String = "") -> Dictionary:
	if not _configured():
		return _result(false, &"survey_persistence_unavailable")
	var refreshing: bool = not expected_receipt_sha256.is_empty()
	if refreshing and (expected_receipt_sha256 != _loaded_active_journey_receipt \
			or _loaded_active_journey_receipt.is_empty()):
		return _result(false, &"survey_active_journey_receipt_not_observed")
	if not refreshing and not _loaded_active_journey_receipt.is_empty():
		return _result(false, &"survey_active_journey_already_loaded")
	var loaded := _store.call(&"load") as Dictionary
	if not bool(loaded.get("accepted", false)):
		return loaded
	var payload := loaded.get("payload", {}) as Dictionary
	var slot_key := String(_slot_id)
	if not payload.has(slot_key):
		return _result(false, &"survey_active_journey_not_found")
	var record: Variant = payload.get(slot_key)
	var validation := validate_interrupted_journey_record(record)
	if not bool(validation.get("accepted", false)):
		return validation
	if refreshing and str((record as Dictionary).completion.get("receipt_sha256", "")) \
			!= expected_receipt_sha256:
		return _result(false, &"survey_active_journey_receipt_mismatch")
	_active_journey_adapter = ReturnPersistenceAdapterScript.new() as RefCounted
	var restored := _active_journey_adapter.call(
		&"restore_interrupted_journey",
		(record as Dictionary).get("completion", {})
	) as Dictionary
	if not bool(restored.get("accepted", false)):
		return restored
	_loaded_active_journey_receipt = str(restored.get("receipt_sha256", ""))
	return {
		"accepted": true,
		"reason": &"survey_active_journey_loaded",
		"store_generation": int(loaded.get("generation", -1)),
		"recovery": restored.duplicate(true),
		"movement_replay_allowed": false,
		"reward_replay_allowed": false,
	}.duplicate(true)


## Removes only the exact active receipt observed at the supplied store
## generation. Callers do this after their own save-session contract accepts
## re-entry so a crash before adoption remains retryable.
func retire_interrupted_journey(
		expected_store_generation: int,
		expected_receipt_sha256: String,
		commit_id: String
	) -> Dictionary:
	if not _configured() or expected_store_generation < 0 \
			or expected_receipt_sha256.length() != 64 \
			or commit_id.strip_edges().is_empty():
		return _result(false, &"survey_active_journey_retire_invalid")
	if expected_receipt_sha256 != _loaded_active_journey_receipt:
		return _result(false, &"survey_active_journey_receipt_not_observed")
	if int(_store.call(&"get_generation")) != expected_store_generation:
		return _result(false, &"survey_active_journey_store_generation_stale")
	var payload := _store.call(&"get_snapshot") as Dictionary
	var slot_key := String(_slot_id)
	if not payload.has(slot_key):
		return _result(false, &"survey_active_journey_not_found")
	var record: Variant = payload.get(slot_key)
	var validation := validate_interrupted_journey_record(record)
	if not bool(validation.get("accepted", false)):
		return validation
	var recovery := (record as Dictionary).get("completion", {}) as Dictionary
	if str(recovery.get("receipt_sha256", "")) != expected_receipt_sha256:
		return _result(false, &"survey_active_journey_receipt_mismatch")
	payload.erase(slot_key)
	var committed := _store.call(
		&"commit", payload, expected_store_generation, commit_id
	) as Dictionary
	committed["binding_reason"] = (
		&"active_journey_retired" if bool(committed.get("accepted", false)) \
		else &"store_rejected"
	)
	if bool(committed.get("accepted", false)):
		_loaded_active_journey_receipt = ""
		_active_journey_adapter = null
	return committed


func get_store_generation() -> int:
	return int(_store.call(&"get_generation")) if _configured() else -1


func get_declined_slot_id() -> String:
	return String(_slot_id) + "_declined"


## Plan inside Main's single Start Fresh transaction. The original envelope
## stays passive; neither its coordinates nor incomplete route can be resumed.
func plan_decline(payload: Dictionary) -> Dictionary:
	if not _configured():
		return _result(false, &"survey_persistence_unavailable")
	var key := String(_slot_id)
	var archive := get_declined_slot_id()
	if payload.has(archive):
		var checked := validate_interrupted_journey_record(payload[archive])
		if not bool(checked.get("accepted", false)):
			return checked
	if not payload.has(key):
		return {"accepted": true, "payload": payload}
	if not payload[key] is Dictionary:
		return _result(false, &"survey_active_journey_payload_corrupt")
	var record := payload[key] as Dictionary
	if str(record.get("payload_kind", "")) == PAYLOAD_KIND:
		var checked := validate_record(record)
		if not bool(checked.get("accepted", false)):
			return checked
		return {"accepted": true, "payload": payload}
	var checked := validate_interrupted_journey_record(record)
	if not bool(checked.get("accepted", false)):
		return checked
	var next := payload.duplicate(true)
	if next.has(archive) and next[archive] != record \
			and bool(next[archive].completion.route_identity.complete):
		# A completed obligation must be paid before another trip can replace it.
		return _result(false, &"survey_declined_completion_pending")
	next[archive] = record.duplicate(true)
	next.erase(key)
	return {"accepted": true, "payload": next}


## Only completed observations are useful on a genuinely new arrival. No
## detached session/position is adopted by this reader.
func load_declined_completion() -> Dictionary:
	if not _configured():
		return _result(false, &"survey_persistence_unavailable")
	var payload := _store.call(&"get_snapshot") as Dictionary
	var key := get_declined_slot_id()
	if not payload.has(key):
		return _result(false, &"survey_declined_completion_not_found")
	if not _store.has_method(&"get_loaded_source") \
			or _store.call(&"get_loaded_source") != &"primary":
		return _result(false, &"survey_declined_store_untrusted")
	var checked := validate_interrupted_journey_record(payload[key])
	if not bool(checked.get("accepted", false)):
		return checked
	var recovery := (payload[key].completion as Dictionary).duplicate(true)
	if not bool(recovery.route_identity.complete):
		return _result(false, &"survey_declined_completion_not_found")
	return {"accepted": true, "reason": &"survey_declined_completion_loaded",
		"recovery": recovery, "store_generation": get_store_generation()}


func validate_completed_debt(route: Dictionary, receipt: String) -> Dictionary:
	if not _configured() or not _store.has_method(&"get_loaded_source") \
			or _store.call(&"get_loaded_source") != &"primary":
		return _result(false, &"survey_declined_store_untrusted")
	var debts := _completed_debts(_store.call(&"get_snapshot") as Dictionary)
	if not bool(debts.get("accepted", false)):
		return debts
	if (debts.records as Array).is_empty():
		return _result(false, &"survey_completed_debt_not_found")
	var recovery: Dictionary = debts.records[0].completion
	# Use the existing wire numeric representation for strict dictionary equality.
	var normalized := _wire_copy(route) as Dictionary
	if recovery.route_identity != normalized or str(recovery.receipt_sha256) != receipt:
		return _result(false, &"survey_completed_debt_changed")
	return _result(true, &"survey_completed_debt_valid")


## Called by the existing reward authority while constructing its one CAS.
## Removing debt and granting its reward must never be separate writes.
func plan_completed_payment(payload: Dictionary, activity_generation: int) -> Dictionary:
	var debts := _completed_debts(payload)
	if not bool(debts.get("accepted", false)):
		return debts
	var next := payload.duplicate(true)
	for record: Dictionary in debts.records:
		if int(record.completion.route_identity.activity_generation) != activity_generation:
			return _result(false, &"survey_completed_debt_generation_mismatch")
	for key: String in debts.get("keys", []):
		next.erase(key)
	var active_key := String(_slot_id)
	if next.has(active_key) and str(next[active_key].get("payload_kind", "")) == ACTIVE_JOURNEY_PAYLOAD_KIND:
		# The last autosave may precede the final observation. It must not be
		# another recovery path for an activity whose reward is now committed.
		var route: Dictionary = next[active_key].completion.route_identity
		if int(route.activity_generation) != activity_generation:
			return _result(false, &"survey_completed_debt_generation_mismatch")
		next.erase(active_key)
	return {"accepted": true, "payload": next}


func _completed_debts(payload: Dictionary) -> Dictionary:
	var records: Array[Dictionary] = []
	var keys: Array[String] = []
	var other_record := false
	for key: String in [String(_slot_id), get_declined_slot_id()]:
		if not payload.has(key):
			continue
		var value: Variant = payload[key]
		if key == String(_slot_id) and value is Dictionary \
				and str(value.get("payload_kind", "")) == PAYLOAD_KIND:
			var terminal := validate_record(value)
			if not bool(terminal.get("accepted", false)):
				return terminal
			other_record = true
			continue
		var checked := validate_interrupted_journey_record(value)
		if not bool(checked.get("accepted", false)):
			return checked
		var record := value as Dictionary
		if not bool(record.completion.route_identity.complete):
			other_record = other_record or key == String(_slot_id)
			continue
		if not records.is_empty() and records[0] != record:
			return _result(false, &"survey_completed_debt_conflict")
		records.append(record.duplicate(true))
		keys.append(key)
	if not records.is_empty() and other_record:
		return _result(false, &"survey_completed_debt_conflict")
	return {"accepted": true, "records": records, "keys": keys}


func capture(surface_snapshot: Variant) -> Dictionary:
	if not surface_snapshot is Dictionary:
		return _result(false, &"survey_completion_snapshot_invalid")
	var surface := surface_snapshot as Dictionary
	var adapter := surface.get("adapter", {}) as Dictionary
	var runtime := adapter.get("activity_reward", {}) as Dictionary
	var survey := surface.get("relay_survey", {}) as Dictionary
	var route := survey.get("mandatory_route", {}) as Dictionary
	var optional := survey.get("optional_checkpoint", {}) as Dictionary
	var interaction := surface.get("survey_interaction", {}) as Dictionary
	var committed := runtime.get("committed_reward", {}) as Dictionary
	var authority_result := committed.get("authority_result", {}) as Dictionary
	if StringName(runtime.get("state", &"")) != &"completed" \
			or StringName(runtime.get("completed_activity_id", &"")) != ACTIVITY_ID \
			or not (runtime.get("pending_reward", {}) as Dictionary).is_empty() \
			or StringName(committed.get("world_id", &"")) != WORLD_ID \
			or StringName(committed.get("activity_id", &"")) != ACTIVITY_ID \
			or StringName(committed.get("reward_id", &"")) != REWARD_ID \
			or StringName(committed.get("reward_store_id", &"")) != REWARD_STORE_ID \
			or StringName(committed.get("reward_authority_id", &"")) \
				!= REWARD_AUTHORITY_ID \
			or not bool(authority_result.get("accepted", false)) \
			or StringName(route.get("activity_id", &"")) != ACTIVITY_ID \
			or int(route.get("checkpoint_count", -1)) != 2 \
			or int(route.get("next_checkpoint_index", -1)) != 2 \
			or not bool(route.get("complete", false)) \
			or int(route.get("activity_generation", -1)) \
				!= int(committed.get("activity_generation", -2)):
		return _result(false, &"survey_completion_not_committed")
	var optional_completion := _capture_optional_completion(
		optional, interaction, int(committed.get("activity_generation", -1))
	)
	if bool(optional.get("completed", false)) \
			and not bool(optional_completion.get("accepted", false)):
		return optional_completion
	# The process-local RefCounted identity is passive diagnostic evidence.
	# JSON numbers cannot reliably roundtrip its signed 64-bit value, so retain
	# exact decimal text in the saved copy while live authority keeps its int.
	var persisted_reward := committed.duplicate(true)
	var persisted_authority := persisted_reward.get("authority_result", {}) as Dictionary
	var persisted_evidence := persisted_authority.get("evidence", {}) as Dictionary
	if persisted_evidence.get("session_instance_id") is int:
		persisted_evidence["session_instance_id"] = str(persisted_evidence.session_instance_id)
	var completion_payload := {
		"world_id": WORLD_ID,
		"activity_id": ACTIVITY_ID,
		"activity_generation": int(committed.get("activity_generation", 0)),
		"reward_id": REWARD_ID,
		"reward_store_id": REWARD_STORE_ID,
		"reward_authority_id": REWARD_AUTHORITY_ID,
		"committed_reward": persisted_reward,
		"mandatory_route": route,
		"presentation_state": "reward_confirmed",
		"reward_replay_allowed": false,
	}
	completion_payload["optional_checkpoint"] = (
		optional_completion.get("completion", {"completed": false}) as Dictionary
	).duplicate(true)
	var completion := _wire_copy(completion_payload) as Dictionary
	var record := {
		"schema_version": float(SCHEMA_VERSION),
		"payload_kind": PAYLOAD_KIND,
		"slot_id": String(_slot_id),
		"receipt_sha256": _digest(completion),
		"completion": completion,
	}
	return {
		"accepted": true,
		"reason": &"survey_completion_captured",
		"record": record.duplicate(true),
	}.duplicate(true)


func validate_record(candidate: Variant) -> Dictionary:
	if not candidate is Dictionary:
		return _result(false, &"survey_persistence_payload_corrupt")
	var record := candidate as Dictionary
	if record.size() != 5 or not _integral(record.get("schema_version")) \
			or int(record.get("schema_version", 0)) != SCHEMA_VERSION \
			or str(record.get("payload_kind", "")) != PAYLOAD_KIND \
			or StringName(record.get("slot_id", &"")) != _slot_id \
			or not record.get("receipt_sha256") is String \
			or not record.get("completion") is Dictionary:
		return _result(false, &"survey_persistence_payload_corrupt")
	var completion := record.completion as Dictionary
	if str(record.receipt_sha256) != _digest(completion) \
			or str(completion.get("world_id", "")) != WORLD_ID \
			or str(completion.get("activity_id", "")) != ACTIVITY_ID \
			or str(completion.get("reward_id", "")) != REWARD_ID \
			or str(completion.get("reward_store_id", "")) != REWARD_STORE_ID \
			or str(completion.get("reward_authority_id", "")) != REWARD_AUTHORITY_ID \
			or not _integral(completion.get("activity_generation")) \
			or int(completion.get("activity_generation", 0)) < 1 \
			or completion.get("reward_replay_allowed") is not bool \
			or bool(completion.get("reward_replay_allowed", true)) \
			or str(completion.get("presentation_state", "")) != "reward_confirmed" \
			or not completion.get("committed_reward") is Dictionary \
			or not completion.get("mandatory_route") is Dictionary:
		return _result(false, &"survey_persistence_payload_corrupt")
	var reward := completion.committed_reward as Dictionary
	var route := completion.mandatory_route as Dictionary
	if str(reward.get("activity_id", "")) != ACTIVITY_ID \
			or str(reward.get("reward_id", "")) != REWARD_ID \
			or not reward.get("authority_result") is Dictionary \
			or not bool((reward.authority_result as Dictionary).get("accepted", false)) \
			or str(route.get("activity_id", "")) != ACTIVITY_ID \
			or not _integral(route.get("checkpoint_count")) \
			or int(route.get("checkpoint_count", 0)) != 2 \
			or not _integral(route.get("next_checkpoint_index")) \
			or int(route.get("next_checkpoint_index", 0)) != 2 \
			or route.get("complete") is not bool or not bool(route.get("complete", false)):
		return _result(false, &"survey_persistence_payload_corrupt")
	# Records written before optional checkpoint persistence remain valid terminal
	# receipts and simply restore without the bunker response.
	var optional: Variant = completion.get(
		"optional_checkpoint", {"completed": false, "replay_allowed": false}
	)
	if not optional is Dictionary or not _validate_optional_completion(
		optional as Dictionary, int(completion.get("activity_generation", -1))
	):
		return _result(false, &"survey_persistence_payload_corrupt")
	return _result(true, &"survey_persistence_payload_valid")


func validate_interrupted_journey_record(candidate: Variant) -> Dictionary:
	if not candidate is Dictionary:
		return _result(false, &"survey_active_journey_payload_corrupt")
	var record := candidate as Dictionary
	if record.size() != 5 or not _integral(record.get("schema_version")) \
			or int(record.get("schema_version", 0)) != SCHEMA_VERSION \
			or str(record.get("payload_kind", "")) != ACTIVE_JOURNEY_PAYLOAD_KIND \
			or StringName(record.get("slot_id", &"")) != _slot_id \
			or not record.get("receipt_sha256") is String \
			or not record.get("completion") is Dictionary:
		return _result(false, &"survey_active_journey_payload_corrupt")
	var recovery := record.get("completion", {}) as Dictionary
	if str(record.get("receipt_sha256", "")) != _digest(recovery):
		return _result(false, &"survey_active_journey_payload_corrupt")
	var adapter := ReturnPersistenceAdapterScript.new() as RefCounted
	var restored := adapter.call(&"restore_interrupted_journey", recovery) as Dictionary
	if not bool(restored.get("accepted", false)):
		return restored
	return _result(true, &"survey_active_journey_payload_valid")


func _capture_optional_completion(
		checkpoint: Dictionary, interaction: Dictionary, activity_generation: int
	) -> Dictionary:
	if not bool(checkpoint.get("completed", false)):
		return {
			"accepted": true,
			"completion": {"completed": false, "replay_allowed": false},
		}
	var receipt := interaction.get("last_receipt", {}) as Dictionary
	if StringName(checkpoint.get("checkpoint_id", &"")) != OPTIONAL_CHECKPOINT_ID \
			or StringName(checkpoint.get("interaction_id", &"")) != OPTIONAL_INTERACTION_ID \
			or int(checkpoint.get("activity_generation", -1)) != activity_generation \
			or int(checkpoint.get("current_activity_generation", -1)) != activity_generation \
			or int(checkpoint.get("run_generation", -1)) < 1 \
			or int(checkpoint.get("attachment_generation", -1)) < 1 \
			or bool(checkpoint.get("historical_claim", true)) \
			or StringName(checkpoint.get("content_class", &"")) != &"NEW" \
			or StringName(checkpoint.get("interpretation_status", &"")) \
				!= &"modern_interpretation" \
			or not bool(interaction.get("completed", false)) \
			or StringName(interaction.get("interaction_id", &"")) != OPTIONAL_INTERACTION_ID \
			or StringName(receipt.get("interaction_id", &"")) != OPTIONAL_INTERACTION_ID \
			or StringName(receipt.get("world_id", &"")) != WORLD_ID \
			or StringName(receipt.get("completion_response_id", &"")) != OPTIONAL_RESPONSE_ID \
			or int(receipt.get("host_generation", -2)) \
				!= int(checkpoint.get("run_generation", -1)) \
			or int(receipt.get("attachment_generation", -2)) \
				!= int(checkpoint.get("attachment_generation", -1)) \
			or bool(receipt.get("activity_started", true)) \
			or bool(receipt.get("reward_granted", true)) \
			or bool(receipt.get("historical_claim", true)):
		return _result(false, &"survey_optional_completion_not_committed")
	return {
		"accepted": true,
		"completion": {
			"completed": true,
			"checkpoint_id": OPTIONAL_CHECKPOINT_ID,
			"interaction_id": OPTIONAL_INTERACTION_ID,
			"completion_response_id": OPTIONAL_RESPONSE_ID,
			"activity_generation": activity_generation,
			"source_run_generation": int(checkpoint.get("run_generation", -1)),
			"source_attachment_generation": int(
				checkpoint.get("attachment_generation", -1)
			),
			"content_class": "NEW",
			"interpretation_status": "modern_interpretation",
			"historical_claim": false,
			"replay_allowed": false,
		},
	}.duplicate(true)


func _validate_optional_completion(optional: Dictionary, activity_generation: int) -> bool:
	if optional.get("completed") is not bool \
			or optional.get("replay_allowed") is not bool \
			or bool(optional.get("replay_allowed", true)):
		return false
	if not bool(optional.completed):
		return optional.size() == 2
	return str(optional.get("checkpoint_id", "")) == OPTIONAL_CHECKPOINT_ID \
		and str(optional.get("interaction_id", "")) == OPTIONAL_INTERACTION_ID \
		and str(optional.get("completion_response_id", "")) == OPTIONAL_RESPONSE_ID \
		and _integral(optional.get("activity_generation")) \
		and int(optional.get("activity_generation", -1)) == activity_generation \
		and _integral(optional.get("source_run_generation")) \
		and int(optional.get("source_run_generation", -1)) >= 1 \
		and _integral(optional.get("source_attachment_generation")) \
		and int(optional.get("source_attachment_generation", -1)) >= 1 \
		and str(optional.get("content_class", "")) == "NEW" \
		and str(optional.get("interpretation_status", "")) == "modern_interpretation" \
		and optional.get("historical_claim") is bool \
		and not bool(optional.get("historical_claim", true))


func _configured() -> bool:
	return _store != null and is_instance_valid(_store) and not _slot_id.is_empty()


func _wire_copy(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			var copied := {}
			var keys := (value as Dictionary).keys()
			keys.sort_custom(func(left: Variant, right: Variant) -> bool: return str(left) < str(right))
			for key in keys:
				copied[str(key)] = _wire_copy((value as Dictionary)[key])
			return copied
		TYPE_ARRAY:
			var array := []
			for child in value as Array: array.append(_wire_copy(child))
			return array
		TYPE_STRING_NAME:
			return str(value)
		TYPE_INT:
			return float(value)
	return value


func _digest(value: Dictionary) -> String:
	return JSON.stringify(_wire_copy(value)).sha256_text()


func _integral(value: Variant) -> bool:
	return value is int or (value is float and is_finite(value) and value == floor(value))


func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {"accepted": accepted, "reason": reason}.duplicate(true)
