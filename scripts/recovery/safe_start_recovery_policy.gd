class_name SafeStartRecoveryPolicy
extends RefCounted

## Explicit, generation-safe startup recovery policy over UserDataStore.
##
## The caller owns store loading, startup identities, physics-window evidence,
## clean-shutdown timing, and deterministic commit IDs. This service has no
## process callback and never applies or persists RuntimeSettings values.

signal transition_committed(
	transition: StringName,
	snapshot: Dictionary,
	store_generation: int
)
signal recommendation_available(
	recommendation: Dictionary,
	snapshot: Dictionary,
	store_generation: int
)

const Record := preload("res://scripts/recovery/safe_start_recovery_record.gd")
const Settings := preload("res://scripts/settings/runtime_settings.gd")

const PAYLOAD_NAMESPACE := "safe_start_recovery"
const RECOMMENDATION_SCHEMA_VERSION := 1
const RECOMMENDATION_ID := "safe_start_low_graphics_windowed_v1"

const _PRESERVED_RUNTIME_SETTING_KEYS := [
	"ship_mouse_sensitivity",
	"on_foot_mouse_sensitivity",
	"invert_ship_y",
	"invert_on_foot_y",
	"camera_fov",
	"master_volume",
	"ambience_volume",
	"engine_volume",
	"weapons_volume",
	"ui_volume",
	"music_volume",
	"control_preset",
	"ui_scale",
	"colorblind_palette",
	"reduced_motion",
	"captions_enabled",
	"input_binding_profile",
]

var _store: UserDataStore
var _record: SafeStartRecoveryRecord = Record.new()
var _restored := false
var _restored_store_generation := 0
var _operation_active := false


func _init(store: UserDataStore = null) -> void:
	_store = store


## Restores only the injected store's current in-memory authority. The caller
## must call UserDataStore.load() first and pass that exact generation.
func restore(expected_store_generation: int) -> Dictionary:
	if _operation_active:
		return _result(false, &"reentrant_call", {"store_reason": &"not_attempted"})
	_operation_active = true
	var result := _restore(expected_store_generation)
	_operation_active = false
	return result


## Begins one caller-identified startup. A different startup generation after a
## persisted STARTING state confirms exactly one prior unfinished startup.
func mark_startup_begin(
	startup_generation: int,
	expected_record_generation: int,
	expected_store_generation: int,
	commit_id: String
	) -> Dictionary:
	if _operation_active:
		return _result(false, &"reentrant_call", {"store_reason": &"not_attempted"})
	_operation_active = true
	var result := _mark_startup_begin(
		startup_generation,
		expected_record_generation,
		expected_store_generation,
		commit_id
	)
	_operation_active = false
	return result


## The caller invokes this only after its chosen physics-stability window has
## completed. This successful startup resets the consecutive-failure count.
func mark_stable_after_physics_window(
	startup_generation: int,
	expected_record_generation: int,
	expected_store_generation: int,
	commit_id: String
	) -> Dictionary:
	if _operation_active:
		return _result(false, &"reentrant_call", {"store_reason": &"not_attempted"})
	_operation_active = true
	var result := _mark_stable_after_physics_window(
		startup_generation,
		expected_record_generation,
		expected_store_generation,
		commit_id
	)
	_operation_active = false
	return result


## Records a caller-confirmed clean shutdown. This closes a STARTING marker so
## it cannot be counted as unfinished on the next startup; only STABLE resets
## failures accumulated by earlier unfinished startups.
func mark_clean_shutdown(
	startup_generation: int,
	expected_record_generation: int,
	expected_store_generation: int,
	commit_id: String
	) -> Dictionary:
	if _operation_active:
		return _result(false, &"reentrant_call", {"store_reason": &"not_attempted"})
	_operation_active = true
	var result := _mark_clean_shutdown(
		startup_generation,
		expected_record_generation,
		expected_store_generation,
		commit_id
	)
	_operation_active = false
	return result


func get_snapshot() -> Dictionary:
	var snapshot := _record.to_dictionary()
	snapshot["restored"] = _restored
	snapshot["store_generation"] = _restored_store_generation
	snapshot["safe_mode_failure_threshold"] = Record.SAFE_MODE_FAILURE_THRESHOLD
	snapshot["maximum_consecutive_failures"] = Record.MAX_CONSECUTIVE_FAILURES
	snapshot["recommendation_available"] = _record.safe_settings_recommended
	return snapshot.duplicate(true)


## A two-key merge recommendation. Every unlisted RuntimeSettings value remains
## caller-owned and must be copied unchanged by any later production adapter.
func get_recommended_runtime_settings_patch() -> Dictionary:
	if not _record.safe_settings_recommended:
		return {}
	return {
		"schema_version": RECOMMENDATION_SCHEMA_VERSION,
		"recommendation_id": RECOMMENDATION_ID,
		"target_payload_namespace": "runtime_settings",
		"required_runtime_settings_payload_schema_version": (
			Settings.USER_DATA_PAYLOAD_SCHEMA_VERSION
		),
		"values_patch": {
			"graphics_profile": "low",
			"window_mode": "windowed",
		},
		"preserve_unlisted_values": true,
		"preserved_value_keys": _PRESERVED_RUNTIME_SETTING_KEYS.duplicate(),
		"applies_settings": false,
		"persists_settings": false,
	}.duplicate(true)


func audit() -> Dictionary:
	var record_audit := _record.audit()
	var recommendation := get_recommended_runtime_settings_patch()
	return {
		"valid": bool(record_audit.valid),
		"record_audit": record_audit.duplicate(true),
		"snapshot": get_snapshot(),
		"recommendation": recommendation,
		"authority": {
			"wall_clock": false,
			"physics_time": false,
			"process_hooks": false,
			"startup_lifecycle": false,
			"clean_shutdown_detection": false,
			"settings_application": false,
			"settings_persistence": false,
			"game_flow": false,
			"hud": false,
			"os_crash_detection": false,
			"commit_identity": false,
		},
	}.duplicate(true)


func _restore(expected_store_generation: int) -> Dictionary:
	if _store == null:
		return _result(false, &"no_store")
	if _store.get_loaded_source() == &"none":
		return _result(false, &"store_not_loaded")
	if not _is_valid_store_generation(expected_store_generation) \
		or expected_store_generation != _store.get_generation():
		return _result(false, &"stale_store_generation")
	var payload := _store.get_snapshot()
	if not payload.has(PAYLOAD_NAMESPACE):
		_record = Record.new()
		_restored = true
		_restored_store_generation = expected_store_generation
		return _result(true, &"empty")
	var decoded := Record.decode(payload.get(PAYLOAD_NAMESPACE))
	if not bool(decoded.accepted):
		_restored = false
		return _record_rejection(decoded)
	_record = (decoded.record as SafeStartRecoveryRecord).duplicate_record()
	_restored = true
	_restored_store_generation = expected_store_generation
	return _result(true, &"restored")


func _mark_startup_begin(
	startup_generation: int,
	expected_record_generation: int,
	expected_store_generation: int,
	commit_id: String
	) -> Dictionary:
	if not _valid_commit_token(commit_id):
		return _result(false, &"invalid_commit_id")
	if not _is_valid_startup_generation(startup_generation):
		return _result(false, &"invalid_startup_generation")
	var preflight := _preflight_mutation(
		expected_record_generation, expected_store_generation
	)
	if not bool(preflight.accepted):
		return preflight
	if _record.state == Record.STATE_STARTING \
		and startup_generation == _record.startup_generation:
		return _result(true, &"already_started")
	if startup_generation <= _record.startup_generation:
		return _result(false, &"stale_startup_generation")
	if _record.record_generation >= Record.MAX_SAFE_JSON_INTEGER:
		return _result(false, &"record_generation_exhausted")
	var failures := _record.consecutive_failure_count
	if _record.state == Record.STATE_STARTING:
		failures = mini(failures + 1, Record.MAX_CONSECUTIVE_FAILURES)
	var next := Record.new(
		_record.record_generation + 1,
		Record.STATE_STARTING,
		startup_generation,
		failures,
		failures >= Record.SAFE_MODE_FAILURE_THRESHOLD
	)
	return _commit_record(next, expected_store_generation, commit_id, &"startup_begun")


func _mark_stable_after_physics_window(
	startup_generation: int,
	expected_record_generation: int,
	expected_store_generation: int,
	commit_id: String
	) -> Dictionary:
	if not _valid_commit_token(commit_id):
		return _result(false, &"invalid_commit_id")
	if not _is_valid_startup_generation(startup_generation):
		return _result(false, &"invalid_startup_generation")
	var preflight := _preflight_mutation(
		expected_record_generation, expected_store_generation
	)
	if not bool(preflight.accepted):
		return preflight
	if startup_generation != _record.startup_generation:
		return _result(false, &"wrong_startup_generation")
	if _record.state == Record.STATE_STABLE:
		return _result(true, &"already_stable")
	if _record.state != Record.STATE_STARTING:
		return _result(false, &"startup_not_in_progress")
	if _record.record_generation >= Record.MAX_SAFE_JSON_INTEGER:
		return _result(false, &"record_generation_exhausted")
	var next := Record.new(
		_record.record_generation + 1,
		Record.STATE_STABLE,
		startup_generation,
		0,
		false
	)
	return _commit_record(next, expected_store_generation, commit_id, &"startup_stable")


func _mark_clean_shutdown(
	startup_generation: int,
	expected_record_generation: int,
	expected_store_generation: int,
	commit_id: String
	) -> Dictionary:
	if not _valid_commit_token(commit_id):
		return _result(false, &"invalid_commit_id")
	if not _is_valid_startup_generation(startup_generation):
		return _result(false, &"invalid_startup_generation")
	var preflight := _preflight_mutation(
		expected_record_generation, expected_store_generation
	)
	if not bool(preflight.accepted):
		return preflight
	if startup_generation != _record.startup_generation:
		return _result(false, &"wrong_startup_generation")
	if _record.state == Record.STATE_CLEAN_SHUTDOWN:
		return _result(true, &"already_clean")
	if _record.state not in [Record.STATE_STARTING, Record.STATE_STABLE]:
		return _result(false, &"startup_not_active")
	if _record.record_generation >= Record.MAX_SAFE_JSON_INTEGER:
		return _result(false, &"record_generation_exhausted")
	var next := Record.new(
		_record.record_generation + 1,
		Record.STATE_CLEAN_SHUTDOWN,
		startup_generation,
		_record.consecutive_failure_count,
		_record.safe_settings_recommended
	)
	return _commit_record(next, expected_store_generation, commit_id, &"clean_shutdown")


func _preflight_mutation(
	expected_record_generation: int,
	expected_store_generation: int
	) -> Dictionary:
	if _store == null:
		return _result(false, &"no_store")
	if not _restored:
		return _result(false, &"not_restored")
	if _store.get_loaded_source() == &"backup":
		return _result(false, &"store_recovery_required")
	if not _is_valid_store_generation(expected_store_generation) \
		or expected_store_generation != _store.get_generation():
		return _result(false, &"stale_store_generation")
	if expected_store_generation != _restored_store_generation:
		return _result(false, &"stale_policy_snapshot")
	if not _is_valid_record_generation(expected_record_generation) \
		or expected_record_generation != _record.record_generation:
		return _result(false, &"stale_record_generation")
	var payload := _store.get_snapshot()
	if not payload.has(PAYLOAD_NAMESPACE):
		if _record.record_generation != 0:
			return _result(false, &"stale_policy_snapshot")
		return {"accepted": true}
	var decoded := Record.decode(payload.get(PAYLOAD_NAMESPACE))
	if not bool(decoded.accepted):
		return _record_rejection(decoded)
	var persisted := decoded.record as SafeStartRecoveryRecord
	if persisted.to_dictionary() != _record.to_dictionary():
		return _result(false, &"stale_policy_snapshot")
	return {"accepted": true}


func _commit_record(
	next: SafeStartRecoveryRecord,
	expected_store_generation: int,
	commit_id: String,
	transition: StringName
	) -> Dictionary:
	var payload := _store.get_snapshot()
	payload[PAYLOAD_NAMESPACE] = next.to_dictionary()
	var committed := _store.commit(payload, expected_store_generation, commit_id)
	if not bool(committed.accepted):
		return _result(false, &"store_commit_failed", {
			"store_reason": committed.reason,
			"store_status": committed.duplicate(true),
		})
	var recommendation_was_available := _record.safe_settings_recommended
	_record = next.duplicate_record()
	_restored_store_generation = int(committed.generation)
	var snapshot := get_snapshot()
	transition_committed.emit(
		transition,
		snapshot.duplicate(true),
		_restored_store_generation
	)
	if _record.safe_settings_recommended and not recommendation_was_available:
		recommendation_available.emit(
			get_recommended_runtime_settings_patch(),
			snapshot.duplicate(true),
			_restored_store_generation
		)
	return _result(true, transition, {
		"store_reason": committed.reason,
		"store_status": committed.duplicate(true),
	})


func _record_rejection(decoded: Dictionary) -> Dictionary:
	var record_reason := StringName(decoded.get("reason", &"invalid_record"))
	return _result(
		false,
		&"record_schema_newer" if record_reason == &"newer_schema" else &"invalid_record",
		{"record_reason": record_reason}
	)


func _result(
	accepted: bool,
	reason: StringName,
	details: Dictionary = {}
	) -> Dictionary:
	var result := {
		"accepted": accepted,
		"reason": reason,
		"store_generation": _store.get_generation() if _store != null else 0,
		"record_generation": _record.record_generation,
		"snapshot": get_snapshot(),
		"recommendation": get_recommended_runtime_settings_patch(),
	}
	result.merge(details, true)
	return result.duplicate(true)


static func _is_valid_store_generation(generation: int) -> bool:
	return generation >= 0 and generation <= UserDataStore.MAX_GENERATION


static func _is_valid_record_generation(generation: int) -> bool:
	return generation >= 0 and generation <= Record.MAX_SAFE_JSON_INTEGER


static func _is_valid_startup_generation(generation: int) -> bool:
	return generation > 0 and generation <= Record.MAX_SAFE_JSON_INTEGER


static func _valid_commit_token(commit_id: String) -> bool:
	if commit_id.length() < 1 or commit_id.length() > 64:
		return false
	for character in commit_id:
		var code := character.unicode_at(0)
		var allowed := (code >= 48 and code <= 57) \
			or (code >= 65 and code <= 90) \
			or (code >= 97 and code <= 122) \
			or character in ["-", "_", ".", ":"]
		if not allowed:
			return false
	return true
