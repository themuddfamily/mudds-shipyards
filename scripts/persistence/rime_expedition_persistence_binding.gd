class_name RimeExpeditionPersistenceBinding
extends RefCounted

## Namespaced atomic-store bridge for one interrupted Rime visit.
##
## A Rime expedition running when `Main` leaves the tree is recorded as a small
## detached description - the settled visit phase, the craft named by its
## registered home berth, whether the pilot was out of the seat, and the
## optional ice-core survey's route progress - so the next `Main` can put the
## same pilot back on Rime with the same craft. It restores no berth lease,
## landing, movement, reward or actor state; the resume path re-establishes
## physical ownership through the same production calls a fresh visit uses.
## `UserDataStore` remains the only filesystem and transaction authority.

const SurveyType := preload("res://scripts/activities/rime_ice_core_survey.gd")
const SCHEMA_VERSION := 1
const PAYLOAD_KIND := "rime_expedition_active_visit"
const RECORD_KEYS := [
	"schema_version",
	"payload_kind",
	"slot_id",
	"visit",
	"receipt_sha256",
]
const VISIT_KEYS := [
	"visit_state",
	"craft_home_berth_id",
	"on_foot",
	"survey",
]
const RESUMABLE_VISIT_STATES := ["landed", "surface"]

var _store: RefCounted
var _slot_id: StringName = &""
var _loaded_receipt := ""


func configure(store: RefCounted, slot_id: StringName) -> Dictionary:
	if _store != null or store == null or str(slot_id).strip_edges().is_empty() \
			or not store.has_method(&"load") or not store.has_method(&"commit") \
			or not store.has_method(&"get_snapshot") \
			or not store.has_method(&"get_generation"):
		return _result(false, &"rime_visit_persistence_configuration_invalid")
	_store = store
	_slot_id = slot_id
	return _result(true, &"rime_visit_persistence_configured")


func is_configured() -> bool:
	return _store != null and not str(_slot_id).strip_edges().is_empty()


## Atomically replaces this slot with the detached visit description.
func save_interrupted_visit(visit: Variant, commit_id: String) -> Dictionary:
	if not is_configured() or commit_id.strip_edges().is_empty():
		return _result(false, &"rime_visit_save_invalid")
	var normalized := normalize_visit(visit)
	if not bool(normalized.get("accepted", false)):
		return normalized
	var payload_visit := normalized.get("visit", {}) as Dictionary
	var record := {
		"schema_version": float(SCHEMA_VERSION),
		"payload_kind": PAYLOAD_KIND,
		"slot_id": String(_slot_id),
		"visit": payload_visit,
		"receipt_sha256": _digest(payload_visit),
	}
	var expected_generation := int(_store.call(&"get_generation"))
	var payload := _store.call(&"get_snapshot") as Dictionary
	payload[String(_slot_id)] = record
	var committed := _store.call(
		&"commit", payload, expected_generation,
		"%s-%010d" % [commit_id, expected_generation + 1]
	) as Dictionary
	committed["binding_reason"] = (
		&"rime_visit_saved" if bool(committed.get("accepted", false))
		else &"store_rejected"
	)
	committed["receipt_sha256"] = str(record.get("receipt_sha256", ""))
	return committed


## Loads a passive resume description; the caller reconstructs the visit
## through ordinary production calls and then retires this receipt.
func load_interrupted_visit() -> Dictionary:
	if not is_configured():
		return _result(false, &"rime_visit_persistence_unavailable")
	var loaded := _store.call(&"load") as Dictionary
	if not bool(loaded.get("accepted", false)):
		return loaded
	var payload := loaded.get("payload", {}) as Dictionary
	var slot_key := String(_slot_id)
	if not payload.has(slot_key):
		return _result(false, &"rime_visit_not_found")
	var validation := validate_record(payload.get(slot_key))
	if not bool(validation.get("accepted", false)):
		return validation
	var record := payload.get(slot_key) as Dictionary
	_loaded_receipt = str(record.get("receipt_sha256", ""))
	return {
		"accepted": true,
		"reason": &"rime_visit_loaded",
		"store_generation": int(loaded.get("generation", -1)),
		"visit": (record.get("visit", {}) as Dictionary).duplicate(true),
		"receipt_sha256": _loaded_receipt,
		"movement_replay_allowed": false,
		"reward_replay_allowed": false,
	}.duplicate(true)


## Removes only the exact receipt observed at the supplied store generation, so
## a crash before the resume completes leaves the visit retryable.
func retire_interrupted_visit(
		expected_store_generation: int,
		expected_receipt_sha256: String,
		commit_id: String
	) -> Dictionary:
	if not is_configured() or expected_store_generation < 0 \
			or expected_receipt_sha256.length() != 64 \
			or commit_id.strip_edges().is_empty():
		return _result(false, &"rime_visit_retire_invalid")
	if expected_receipt_sha256 != _loaded_receipt:
		return _result(false, &"rime_visit_receipt_not_observed")
	if int(_store.call(&"get_generation")) != expected_store_generation:
		return _result(false, &"rime_visit_store_generation_stale")
	var payload := _store.call(&"get_snapshot") as Dictionary
	var slot_key := String(_slot_id)
	if not payload.has(slot_key):
		return _result(false, &"rime_visit_not_found")
	var validation := validate_record(payload.get(slot_key))
	if not bool(validation.get("accepted", false)):
		return validation
	var record := payload.get(slot_key) as Dictionary
	if str(record.get("receipt_sha256", "")) != expected_receipt_sha256:
		return _result(false, &"rime_visit_receipt_mismatch")
	payload.erase(slot_key)
	var committed := _store.call(
		&"commit", payload, expected_store_generation, commit_id
	) as Dictionary
	committed["binding_reason"] = (
		&"rime_visit_retired" if bool(committed.get("accepted", false))
		else &"store_rejected"
	)
	if bool(committed.get("accepted", false)):
		_loaded_receipt = ""
	return committed


## Normalizes a caller's visit description into the exact wire record. An
## unsettled phase folds onto the nearest settled one rather than being refused.
func normalize_visit(candidate: Variant) -> Dictionary:
	if candidate is not Dictionary:
		return _result(false, &"rime_visit_record_invalid")
	var source := candidate as Dictionary
	var state := str(source.get("visit_state", ""))
	var berth_id := str(source.get("craft_home_berth_id", "")).strip_edges()
	if berth_id.is_empty() or berth_id.length() > 128:
		return _result(false, &"rime_visit_craft_unidentified")
	var progress: Variant = source.get("survey", {})
	if not SurveyType.valid_progress(progress):
		return _result(false, &"rime_survey_progress_invalid")
	# UserDataStore's JSON round-trip decodes numbers as floats. Hash the same
	# representation on both sides.
	var normalized_progress := (progress as Dictionary).duplicate(true)
	for key in ["schema_version", "state", "generation", "next_checkpoint_index"]:
		if normalized_progress.has(key):
			normalized_progress[key] = float(normalized_progress[key])
	var on_foot := bool(source.get("on_foot", false))
	if not RESUMABLE_VISIT_STATES.has(state):
		state = "surface" if on_foot else "landed"
	return _result(true, &"rime_visit_normalized", {
		"visit": {
			"visit_state": state,
			"craft_home_berth_id": berth_id,
			"on_foot": on_foot,
			"survey": normalized_progress,
		},
	})


func validate_record(candidate: Variant) -> Dictionary:
	if candidate is not Dictionary:
		return _result(false, &"rime_visit_record_invalid")
	var record := candidate as Dictionary
	if record.size() != RECORD_KEYS.size():
		return _result(false, &"rime_visit_record_invalid")
	for key: String in RECORD_KEYS:
		if not record.has(key):
			return _result(false, &"rime_visit_record_invalid")
	if int(record.get("schema_version", 0)) != SCHEMA_VERSION \
			or str(record.get("payload_kind", "")) != PAYLOAD_KIND \
			or str(record.get("slot_id", "")) != String(_slot_id):
		return _result(false, &"rime_visit_record_invalid")
	var visit: Variant = record.get("visit")
	if visit is not Dictionary:
		return _result(false, &"rime_visit_record_invalid")
	var visit_record := visit as Dictionary
	if visit_record.size() != VISIT_KEYS.size():
		return _result(false, &"rime_visit_record_invalid")
	for key: String in VISIT_KEYS:
		if not visit_record.has(key):
			return _result(false, &"rime_visit_record_invalid")
	if not RESUMABLE_VISIT_STATES.has(str(visit_record.get("visit_state", ""))):
		return _result(false, &"rime_visit_state_unresumable")
	if str(visit_record.get("craft_home_berth_id", "")).strip_edges().is_empty():
		return _result(false, &"rime_visit_craft_unidentified")
	if not SurveyType.valid_progress(visit_record.get("survey", {})):
		return _result(false, &"rime_survey_progress_invalid")
	if visit_record.get("on_foot") is not bool:
		return _result(false, &"rime_visit_record_invalid")
	if str(record.get("receipt_sha256", "")) != _digest(visit_record):
		return _result(false, &"rime_visit_receipt_mismatch")
	return _result(true, &"rime_visit_record_valid")


func get_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"configured": is_configured(),
		"slot_id": _slot_id,
		"payload_kind": PAYLOAD_KIND,
		"observed_receipt_sha256": _loaded_receipt,
		"filesystem_authority": false,
		"movement_authority": false,
		"reward_authority": false,
		"berth_authority": false,
	}.duplicate(true)


static func _digest(visit: Dictionary) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(JSON.stringify(visit, "", true, true).to_utf8_buffer())
	return context.finish().hex_encode()


static func _result(
		accepted: bool, reason: StringName, extra: Dictionary = {}
	) -> Dictionary:
	var result := {"accepted": accepted, "reason": reason}
	for key: Variant in extra:
		result[key] = extra[key]
	return result.duplicate(true)
