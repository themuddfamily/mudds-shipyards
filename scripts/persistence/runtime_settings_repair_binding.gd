class_name RuntimeSettingsRepairBinding
extends RefCounted

## Caller-owned repair plan for a RuntimeSettings section whose envelope loader
## recovered a verified backup. RuntimeSettingsStoreAdapter and UserDataStore
## remain the settings and filesystem authorities; this object only fences the
## explicit inspect -> prepare -> commit decision.

const Adapter := preload("res://scripts/settings/runtime_settings_store_adapter.gd")
const Store := preload("res://scripts/persistence/user_data_store.gd")

const _RETRY_SAFE_STORE_REASONS := [
	&"parent_directory_failed",
	&"temp_write_failed",
	&"temp_sync_failed",
	&"temp_verification_failed",
	&"stale_temp_cleanup_failed",
	&"backup_cleanup_failed",
	&"backup_publication_failed",
	&"corrupt_primary_cleanup_failed",
]
const _RECONCILE_STORE_REASONS := [
	&"authority_changed",
	&"authority_changed_during_staging",
	&"directory_sync_failed",
	&"atomic_replace_failed",
	&"published_verification_failed",
	&"published_directory_sync_failed",
]

var _adapter: RuntimeSettingsStoreAdapter
var _store: UserDataStore
var _attached := false
var _observed_generation := -1
var _confirmation := ""
var _kind: StringName = &""
var _prepared := false
var _prepared_payload: Dictionary = {}
var _prepared_commit_id := ""
var _consumed_confirmation := ""
var _last_status: Dictionary = {}


func configure(adapter: RuntimeSettingsStoreAdapter, store: UserDataStore) -> Dictionary:
	if adapter == null or store == null:
		return _status(false, &"invalid_owner")
	_adapter = adapter
	_store = store
	_attached = true
	_reset_plan()
	_last_status = _status(true, &"configured")
	return _last_status.duplicate(true)


func set_attached(attached: bool) -> void:
	_attached = attached
	if not attached:
		# A prepared write is never carried across a detach. Re-entry must inspect
		# the current authority again before a caller can confirm it.
		_reset_plan()


func is_attached() -> bool:
	return _attached and _adapter != null and _store != null


## Inspects an adapter load result. Only a validated backup-loaded settings
## payload is repairable here; corrupt/newer typed data remains fail-closed.
func inspect(load_status: Dictionary) -> Dictionary:
	if not is_attached():
		return _remember(_status(false, &"detached"))
	_reset_plan()
	if load_status.get("store_reason", &"") == &"newer_schema" \
			or load_status.get("reason", &"") == &"settings_payload_newer":
		return _remember(_status(false, &"unsupported_newer_schema"))
	if not bool(load_status.get("accepted", false)):
		return _remember(_status(false, &"load_not_repairable"))
	if load_status.get("reason", &"") != &"loaded" \
			or load_status.get("store_reason", &"") != &"primary_invalid_backup_loaded":
		return _remember(_status(false, &"no_repair_available"))
	var generation := _store.get_generation()
	if generation <= 0 or int(load_status.get("generation", -1)) != generation:
		return _remember(_status(false, &"stale_load_generation"))
	var snapshot := _store.get_snapshot()
	if not snapshot.has(Adapter.SETTINGS_PAYLOAD_KEY):
		return _remember(_status(false, &"settings_payload_missing"))
	_kind = &"promote_verified_backup"
	_observed_generation = generation
	_confirmation = _make_confirmation(generation, snapshot)
	_last_status = _status(true, &"repair_available", {
		"kind": _kind,
		"generation": generation,
		"confirmation": _confirmation,
		"preserves_unrelated_payload": true,
		"newer_schema": false,
	})
	return _last_status.duplicate(true)


## Creates a frozen write plan after the caller presents the exact token from
## inspect(). The payload is the store snapshot, never a reconstructed settings
## namespace, so unrelated caller-owned keys survive the repair.
func prepare(confirmation: String, commit_id: String) -> Dictionary:
	if not is_attached():
		return _remember(_status(false, &"detached"))
	if _confirmation.is_empty() or confirmation != _confirmation:
		return _remember(_status(false, &"confirmation_mismatch"))
	if confirmation == _consumed_confirmation:
		return _remember(_status(false, &"replay_rejected"))
	if _store.get_generation() != _observed_generation:
		return _remember(_status(false, &"stale_store_generation"))
	if commit_id.strip_edges().is_empty():
		return _remember(_status(false, &"commit_id_required"))
	_prepared_payload = _store.get_snapshot()
	_prepared_commit_id = commit_id
	_prepared = true
	_last_status = _status(true, &"repair_prepared", {
		"kind": _kind,
		"generation": _observed_generation,
		"confirmation": _confirmation,
		"commit_id": commit_id,
	})
	return _last_status.duplicate(true)


## Publishes through UserDataStore's existing atomic transaction. Only failures
## known to precede authority changes retain the plan; ambiguous publication or
## changed topology is reconciled and requires a fresh inspect/prepare decision.
func commit(confirmation: String) -> Dictionary:
	if not is_attached():
		return _remember(_status(false, &"detached"))
	if confirmation != _confirmation:
		return _remember(_status(false, &"confirmation_mismatch"))
	if confirmation == _consumed_confirmation:
		return _remember(_status(false, &"replay_rejected"))
	if not _prepared:
		return _remember(_status(false, &"not_prepared"))
	if _store.get_generation() != _observed_generation:
		return _remember(_status(false, &"stale_store_generation"))
	var result := _store.commit(
		_prepared_payload,
		_observed_generation,
		_prepared_commit_id
	).duplicate(true)
	if not bool(result.get("accepted", false)):
		var reason := StringName(result.get("reason", &""))
		if reason in _RETRY_SAFE_STORE_REASONS:
			result["repair_retryable"] = true
			return _remember(result)
		result["repair_retryable"] = false
		result["repair_authority_cleared"] = true
		if reason in _RECONCILE_STORE_REASONS:
			result["repair_reconciliation"] = _store.load().duplicate(true)
		_reset_plan()
		return _remember(result)
	_consumed_confirmation = _confirmation
	_prepared = false
	_prepared_payload.clear()
	_last_status = result
	_last_status["reason"] = &"repair_committed"
	_last_status["repair_retryable"] = false
	return _last_status.duplicate(true)


func get_report() -> Dictionary:
	return {
		"schema_version": 1,
		"attached": is_attached(),
		"kind": _kind,
		"observed_generation": _observed_generation,
		"prepared": _prepared,
		"confirmation_consumed": not _consumed_confirmation.is_empty(),
		"last_status": _last_status.duplicate(true),
	}.duplicate(true)


func _reset_plan() -> void:
	_observed_generation = -1
	_confirmation = ""
	_kind = &""
	_prepared = false
	_prepared_payload.clear()
	_prepared_commit_id = ""
	_consumed_confirmation = ""


func _make_confirmation(generation: int, snapshot: Dictionary) -> String:
	return JSON.stringify({
		"kind": _kind,
		"generation": generation,
		"payload": snapshot,
	}).sha256_text()


func _remember(status: Dictionary) -> Dictionary:
	_last_status = status.duplicate(true)
	return _last_status.duplicate(true)


func _status(accepted: bool, reason: StringName, extra: Dictionary = {}) -> Dictionary:
	var result := {"accepted": accepted, "reason": reason}
	result.merge(extra, true)
	return result
