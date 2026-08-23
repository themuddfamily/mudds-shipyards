class_name EmberRelaySurveyPersistenceBinding
extends RefCounted

## Namespaced atomic-store bridge for one terminal Ember relay-survey receipt.
## It persists only an already committed reward observation and restores no
## ActivityDirector or reward authority.

const SCHEMA_VERSION := 1
const PAYLOAD_KIND := "ember_relay_survey_completion"
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


func get_store_generation() -> int:
	return int(_store.call(&"get_generation")) if _configured() else -1


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
	var completion_payload := {
		"world_id": WORLD_ID,
		"activity_id": ACTIVITY_ID,
		"activity_generation": int(committed.get("activity_generation", 0)),
		"reward_id": REWARD_ID,
		"reward_store_id": REWARD_STORE_ID,
		"reward_authority_id": REWARD_AUTHORITY_ID,
		"committed_reward": committed,
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
