extends RefCounted

## Namespaced atomic-store bridge for one interrupted surface visit.
##
## A surface visit (Aurora, Rime) that is running when `Main` leaves the tree is
## recorded as a small detached description instead of being cancelled, so the
## next `Main` can put the same pilot back on the same world with the same craft.
## Aurora's bridge came first and Rime's was a copy of it; this is the one
## implementation both wrappers now configure with their payload kind, reason
## prefix and optional-activity progress validator.
##
## The record is deliberately tiny and carries no authority. It names the visit
## phase, the craft by its registered home berth, whether the pilot was out of
## the seat, and the optional activity's route progress. It restores no berth
## lease, no landing, no movement, no reward or actor state; the resume path
## re-establishes physical ownership through the same production calls a fresh
## visit uses. `UserDataStore` remains the only filesystem and transaction
## authority.

const SCHEMA_VERSION := 1
const RECORD_KEYS := [
	"schema_version",
	"payload_kind",
	"slot_id",
	"visit",
	"receipt_sha256",
]
const BASE_VISIT_KEYS := [
	"visit_state",
	"craft_home_berth_id",
	"on_foot",
]
## The visit phases a resume is meaningful from. A visit interrupted mid-jump or
## mid-transition has no stable place to put the pilot, so it is recorded as the
## nearest settled phase rather than replayed.
const RESUMABLE_VISIT_STATES := ["landed", "surface"]

var _reason_prefix := ""
var _payload_kind := ""
## The activity script whose static `valid_progress(candidate)` vets progress.
var _survey_script: GDScript
## Aurora's first records carried no survey key and remain loadable; worlds
## whose records always carried one require it.
var _survey_required := false

var _store: RefCounted
var _slot_id: StringName = &""
var _loaded_receipt := ""


func _init(
		reason_prefix: String, payload_kind: String, survey_script: GDScript,
		survey_required: bool,
	) -> void:
	_reason_prefix = reason_prefix
	_payload_kind = payload_kind
	_survey_script = survey_script
	_survey_required = survey_required


func configure(store: RefCounted, slot_id: StringName) -> Dictionary:
	if _store != null or store == null or str(slot_id).strip_edges().is_empty() \
			or not store.has_method(&"load") or not store.has_method(&"commit") \
			or not store.has_method(&"get_snapshot") \
			or not store.has_method(&"get_generation"):
		return _result(false, _reason("visit_persistence_configuration_invalid"))
	_store = store
	_slot_id = slot_id
	return _result(true, _reason("visit_persistence_configured"))


func is_configured() -> bool:
	return _store != null and not str(_slot_id).strip_edges().is_empty()


## Atomically replaces this slot with the detached visit description.
func save_interrupted_visit(visit: Variant, commit_id: String) -> Dictionary:
	if not is_configured() or commit_id.strip_edges().is_empty():
		return _result(false, _reason("visit_save_invalid"))
	var normalized := normalize_visit(visit)
	if not bool(normalized.get("accepted", false)):
		return normalized
	var payload_visit := normalized.get("visit", {}) as Dictionary
	var record := {
		"schema_version": float(SCHEMA_VERSION),
		"payload_kind": _payload_kind,
		"slot_id": String(_slot_id),
		"visit": payload_visit,
		"receipt_sha256": digest_visit(payload_visit),
	}
	var expected_generation := int(_store.call(&"get_generation"))
	var payload := _store.call(&"get_snapshot") as Dictionary
	payload[String(_slot_id)] = record
	var committed := _store.call(
		&"commit", payload, expected_generation, "%s-%010d" % [commit_id, expected_generation + 1]
	) as Dictionary
	committed["binding_reason"] = (
		_reason("visit_saved") if bool(committed.get("accepted", false))
		else &"store_rejected"
	)
	committed["receipt_sha256"] = str(record.get("receipt_sha256", ""))
	return committed


## Loads a passive resume description. The caller reconstructs the visit through
## ordinary production calls and then retires this receipt.
func load_interrupted_visit() -> Dictionary:
	if not is_configured():
		return _result(false, _reason("visit_persistence_unavailable"))
	var loaded := _store.call(&"load") as Dictionary
	if not bool(loaded.get("accepted", false)):
		return loaded
	var payload := loaded.get("payload", {}) as Dictionary
	var slot_key := String(_slot_id)
	if not payload.has(slot_key):
		return _result(false, _reason("visit_not_found"))
	var validation := validate_record(payload.get(slot_key))
	if not bool(validation.get("accepted", false)):
		return validation
	var record := payload.get(slot_key) as Dictionary
	_loaded_receipt = str(record.get("receipt_sha256", ""))
	return {
		"accepted": true,
		"reason": _reason("visit_loaded"),
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
		return _result(false, _reason("visit_retire_invalid"))
	if expected_receipt_sha256 != _loaded_receipt:
		return _result(false, _reason("visit_receipt_not_observed"))
	if int(_store.call(&"get_generation")) != expected_store_generation:
		return _result(false, _reason("visit_store_generation_stale"))
	var payload := _store.call(&"get_snapshot") as Dictionary
	var slot_key := String(_slot_id)
	if not payload.has(slot_key):
		return _result(false, _reason("visit_not_found"))
	var validation := validate_record(payload.get(slot_key))
	if not bool(validation.get("accepted", false)):
		return validation
	var record := payload.get(slot_key) as Dictionary
	if str(record.get("receipt_sha256", "")) != expected_receipt_sha256:
		return _result(false, _reason("visit_receipt_mismatch"))
	payload.erase(slot_key)
	var committed := _store.call(
		&"commit", payload, expected_store_generation, commit_id
	) as Dictionary
	committed["binding_reason"] = (
		_reason("visit_retired") if bool(committed.get("accepted", false))
		else &"store_rejected"
	)
	if bool(committed.get("accepted", false)):
		_loaded_receipt = ""
	return committed


## Normalizes a caller's visit description into the exact wire record. An
## unsettled phase is folded onto the nearest settled one rather than refused,
## because a pilot interrupted mid-transition still deserves their visit back.
func normalize_visit(candidate: Variant) -> Dictionary:
	if candidate is not Dictionary:
		return _result(false, _reason("visit_record_invalid"))
	var source := candidate as Dictionary
	var state := str(source.get("visit_state", ""))
	var berth_id := str(source.get("craft_home_berth_id", "")).strip_edges()
	if berth_id.is_empty() or berth_id.length() > 128:
		return _result(false, _reason("visit_craft_unidentified"))
	var progress: Variant = source.get("survey", {})
	if not _survey_progress_valid(progress):
		return _result(false, _reason("survey_progress_invalid"))
	# UserDataStore's JSON round-trip decodes numbers as floats. Hash the same
	# representation on both sides, preserving the original three-field digest.
	var normalized_progress := (progress as Dictionary).duplicate(true)
	for key in ["schema_version", "state", "generation", "next_checkpoint_index"]:
		if normalized_progress.has(key):
			normalized_progress[key] = float(normalized_progress[key])
	var on_foot := bool(source.get("on_foot", false))
	if not RESUMABLE_VISIT_STATES.has(state):
		state = "surface" if on_foot else "landed"
	return _result(true, _reason("visit_normalized"), {
		"visit": {
			"visit_state": state,
			"craft_home_berth_id": berth_id,
			"on_foot": on_foot,
			"survey": normalized_progress,
		},
	})


func validate_record(candidate: Variant) -> Dictionary:
	if candidate is not Dictionary:
		return _result(false, _reason("visit_record_invalid"))
	var record := candidate as Dictionary
	if record.size() != RECORD_KEYS.size():
		return _result(false, _reason("visit_record_invalid"))
	for key: String in RECORD_KEYS:
		if not record.has(key):
			return _result(false, _reason("visit_record_invalid"))
	if int(record.get("schema_version", 0)) != SCHEMA_VERSION \
			or str(record.get("payload_kind", "")) != _payload_kind \
			or str(record.get("slot_id", "")) != String(_slot_id):
		return _result(false, _reason("visit_record_invalid"))
	var visit: Variant = record.get("visit")
	if visit is not Dictionary:
		return _result(false, _reason("visit_record_invalid"))
	var visit_record := visit as Dictionary
	var expected_visit_size := BASE_VISIT_KEYS.size() \
		+ (1 if _survey_required or visit_record.has("survey") else 0)
	if visit_record.size() != expected_visit_size:
		return _result(false, _reason("visit_record_invalid"))
	for key: String in BASE_VISIT_KEYS:
		if not visit_record.has(key):
			return _result(false, _reason("visit_record_invalid"))
	if _survey_required and not visit_record.has("survey"):
		return _result(false, _reason("visit_record_invalid"))
	if not RESUMABLE_VISIT_STATES.has(str(visit_record.get("visit_state", ""))):
		return _result(false, _reason("visit_state_unresumable"))
	if str(visit_record.get("craft_home_berth_id", "")).strip_edges().is_empty():
		return _result(false, _reason("visit_craft_unidentified"))
	if not _survey_progress_valid(visit_record.get("survey", {})):
		return _result(false, _reason("survey_progress_invalid"))
	if visit_record.get("on_foot") is not bool:
		return _result(false, _reason("visit_record_invalid"))
	if str(record.get("receipt_sha256", "")) != digest_visit(visit_record):
		return _result(false, _reason("visit_receipt_mismatch"))
	return _result(true, _reason("visit_record_valid"))


func get_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"configured": is_configured(),
		"slot_id": _slot_id,
		"payload_kind": _payload_kind,
		"observed_receipt_sha256": _loaded_receipt,
		"filesystem_authority": false,
		"movement_authority": false,
		"reward_authority": false,
		"berth_authority": false,
	}.duplicate(true)


static func digest_visit(visit: Dictionary) -> String:
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


func _reason(suffix: String) -> StringName:
	return StringName("%s_%s" % [_reason_prefix, suffix])


func _survey_progress_valid(candidate: Variant) -> bool:
	return _survey_script != null and bool(_survey_script.call(&"valid_progress", candidate))
