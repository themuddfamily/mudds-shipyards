class_name RuntimeSettingsStoreAdapter
extends RefCounted

## Settings-side composition boundary for the atomic UserDataStore.
##
## RuntimeSettings owns typed validation and live state. UserDataStore owns
## durable bytes, generations, and rollback. This adapter owns only payload-key
## preservation and the one-time ConfigFile import policy. Settings change
## observers may run synchronously during load; nested adapter load/save calls
## are rejected without touching the store.

const Store := preload("res://scripts/persistence/user_data_store.gd")

const DEFAULT_STORE_PATH := "user://mudds_user_data.json"
const SETTINGS_PAYLOAD_KEY := "runtime_settings"
const LEGACY_MIGRATION_COMMIT_ID := "runtime-settings-legacy-v1"

var _settings: RuntimeSettings
var _store: UserDataStore
var _legacy_path: String
var _operation_active := false


func _init(
	settings: RuntimeSettings,
	store: UserDataStore = null,
	legacy_path: String = ""
	) -> void:
	_settings = settings
	_store = store if store != null else Store.new(DEFAULT_STORE_PATH)
	if legacy_path.strip_edges().is_empty():
		_legacy_path = (
			settings.config_path if settings != null else RuntimeSettings.DEFAULT_CONFIG_PATH
		)
	else:
		_legacy_path = legacy_path


## Loads the validated atomic settings section without applying global runtime
## side effects. Legacy ConfigFile data is imported only from an authoritative
## generation-zero empty store and only reaches live state after the atomic
## commit succeeds.
func load() -> Dictionary:
	if _operation_active:
		return _reentrant_status()
	_operation_active = true
	var result := _load()
	_operation_active = false
	return result


func _load() -> Dictionary:
	if _settings == null or _store == null:
		return _status(false, &"invalid_owner", false, false, {})
	var store_load := _store.load()
	if not bool(store_load.accepted):
		return _status(false, &"store_load_failed", false, false, store_load)
	if _is_genuinely_empty(store_load):
		return _load_empty_store(store_load)
	var payload := _store.get_snapshot()
	if not payload.has(SETTINGS_PAYLOAD_KEY):
		return _status(false, &"settings_missing", false, false, store_load)
	var applied := _settings.apply_user_data_payload(payload[SETTINGS_PAYLOAD_KEY])
	if not bool(applied.accepted):
		var reason := (
			&"settings_payload_newer"
			if applied.reason in [&"newer_schema", &"newer_input_binding_profile"]
			else &"settings_payload_invalid"
		)
		return _status(false, reason, false, false, store_load, {
			"payload_reason": applied.reason,
		})
	return _status(true, &"loaded", true, false, store_load)


## Re-loads exact store authority, preserves every unrelated payload key, and
## commits the current validated live snapshot against that generation. An
## invalid/newer settings section or a backup-recovery load requires a separate
## repair decision and is never overwritten by an ordinary save.
## During a display preview, callers supply the confirmed display baseline.
## Only the persisted display fields change; live settings and signals are untouched.
func save(commit_id: String, confirmed_display: Dictionary = {}) -> Dictionary:
	if _operation_active:
		return _reentrant_status()
	_operation_active = true
	var result := _save(commit_id, confirmed_display)
	_operation_active = false
	return result


func _save(commit_id: String, confirmed_display: Dictionary) -> Dictionary:
	if _settings == null or _store == null:
		return _status(false, &"invalid_owner", false, false, {})
	var store_load := _store.load()
	if not bool(store_load.accepted):
		return _status(false, &"store_load_failed", false, false, store_load)
	if store_load.reason == &"primary_invalid_backup_loaded":
		return _status(false, &"store_recovery_required", false, false, store_load)
	var payload := _store.get_snapshot()
	if payload.has(SETTINGS_PAYLOAD_KEY):
		var existing := _settings.validate_user_data_payload(payload[SETTINGS_PAYLOAD_KEY])
		if not bool(existing.accepted):
			var reason := (
				&"settings_payload_newer"
				if existing.reason in [&"newer_schema", &"newer_input_binding_profile"]
				else &"settings_payload_invalid"
			)
			return _status(false, reason, false, false, store_load, {
				"payload_reason": existing.reason,
			})
	var settings_payload := _settings.to_user_data_payload()
	if not confirmed_display.is_empty():
		var display := RuntimeSettings.new()
		display.window_mode = int(confirmed_display.get("window_mode", _settings.window_mode))
		display.display_resolution = String(confirmed_display.get("display_resolution", _settings.display_resolution))
		settings_payload.values.window_mode = String(display.get_window_mode_id())
		settings_payload.values.display_resolution = display.display_resolution
	payload[SETTINGS_PAYLOAD_KEY] = settings_payload
	var committed := _store.commit(payload, _store.get_generation(), commit_id)
	if not bool(committed.accepted):
		return _status(false, &"store_commit_failed", false, false, committed)
	return _status(true, &"saved", false, false, committed)


func _load_empty_store(store_load: Dictionary) -> Dictionary:
	if not _legacy_artifact_exists():
		return _status(true, &"empty", false, false, store_load)
	var staged := RuntimeSettings.new(_legacy_path)
	var legacy_error := staged.load_from_file()
	if legacy_error != OK:
		return _status(false, &"legacy_load_failed", false, false, store_load, {
			"legacy_error": legacy_error,
		})
	var legacy_payload := staged.to_user_data_payload()
	var validated := _settings.validate_user_data_payload(legacy_payload)
	if not bool(validated.accepted):
		return _status(false, &"legacy_payload_invalid", false, false, store_load, {
			"payload_reason": validated.reason,
		})
	var committed := _store.commit(
		{SETTINGS_PAYLOAD_KEY: legacy_payload},
		_store.get_generation(),
		LEGACY_MIGRATION_COMMIT_ID
	)
	if not bool(committed.accepted):
		return _status(false, &"legacy_commit_failed", false, false, committed)
	var applied := _settings.apply_user_data_payload(legacy_payload)
	if not bool(applied.accepted):
		# This is defensive: the exact payload validated above and was committed.
		return _status(false, &"legacy_apply_failed", false, true, committed, {
			"payload_reason": applied.reason,
		})
	return _status(true, &"legacy_imported", true, true, committed)


func _legacy_artifact_exists() -> bool:
	for path in [_legacy_path, _legacy_path + ".tmp", _legacy_path + ".bak"]:
		if FileAccess.file_exists(path):
			return true
	return false


func _reentrant_status() -> Dictionary:
	return _status(false, &"reentrant_call", false, false, {
		"reason": &"not_attempted",
		"generation": _store.get_generation() if _store != null else 0,
	})


static func _is_genuinely_empty(store_load: Dictionary) -> bool:
	return (
		bool(store_load.accepted)
		and store_load.reason == &"empty"
		and store_load.source == &"empty"
		and int(store_load.generation) == 0
		and (store_load.payload as Dictionary).is_empty()
		and store_load.primary_status == "missing"
		and store_load.backup_status == "missing"
	)


static func _status(
	accepted: bool,
	reason: StringName,
	applied: bool,
	migrated_legacy: bool,
	store_status: Dictionary,
	details: Dictionary = {}
	) -> Dictionary:
	var result := {
		"accepted": accepted,
		"reason": reason,
		"applied": applied,
		"migrated_legacy": migrated_legacy,
		"store_reason": store_status.get("reason", &"not_attempted"),
		"generation": int(store_status.get("generation", 0)),
		"store_status": store_status.duplicate(true),
	}
	result.merge(details, true)
	return result
