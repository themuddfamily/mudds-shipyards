class_name SafeStartProductionRecovery
extends RefCounted

## Production composition for SafeStartRecoveryPolicy.
##
## GameFlow owns construction order, `_physics_process()` delta, the settings
## adapter transaction callback, and the explicit orderly-shutdown call. This
## retained RefCounted owns only recovery state, validation, deterministic
## identities, and detached diagnostics.

const Policy := preload("res://scripts/recovery/safe_start_recovery_policy.gd")
const Record := preload("res://scripts/recovery/safe_start_recovery_record.gd")
const Adapter := preload("res://scripts/settings/runtime_settings_store_adapter.gd")

const COMMIT_PREFIX := "safe-start-"
const STABILITY_PHYSICS_SECONDS := 5.0
const STABILITY_EPSILON := 0.000001
const RECOMMENDATION_PRESERVED_KEYS := [
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

var _settings: RuntimeSettings
var _store: UserDataStore
var _identity_scope: StringName
var _policy: SafeStartRecoveryPolicy
var _initialized := false
var _restore_status: Dictionary = {}
var _begin_status: Dictionary = {}
var _last_refresh_status: Dictionary = {}
var _stable_status: Dictionary = {}
var _orderly_shutdown_status: Dictionary = {}
var _recommendation_status: Dictionary = {}
var _startup_generation := 0
var _physics_elapsed := 0.0
var _stability_transition_attempted := false
var _restore_attempt_count := 0
var _transition_attempt_count := 0
var _transition_success_count := 0
var _last_commit_id := ""
var _begin_attempted_before_first_apply := false
var _starting_before_first_apply := false


func _init(
	settings: RuntimeSettings,
	store: UserDataStore,
	injected_authority: bool
	) -> void:
	_settings = settings
	_store = store
	_identity_scope = (
		&"injected_main_lifetime" if injected_authority else &"process_lifetime"
	)


## Called once after RuntimeSettingsStoreAdapter.load(). `persist_settings` is a
## synchronous, startup-only callback to GameFlow's existing adapter transaction
## seam and is never retained by this process-lifetime object.
func initialize(
	load_status: Dictionary,
	persist_settings: Callable
	) -> void:
	if _initialized:
		return
	_initialized = true
	if _store == null or _settings == null:
		_restore_status = _local_status(false, &"store_unavailable")
		_begin_status = _local_status(false, &"not_attempted")
		return
	_policy = Policy.new(_store) as SafeStartRecoveryPolicy
	var store_status := load_status.get("store_status", {}) as Dictionary
	if not bool(store_status.get("accepted", false)):
		_restore_status = _local_status(
			false,
			&"store_load_unavailable",
			{"store_status": store_status}
		)
		_begin_status = _local_status(false, &"not_attempted")
		return
	_restore_attempt_count += 1
	_restore_status = _policy.restore(_store.get_generation()).duplicate(true)
	if not bool(_restore_status.get("accepted", false)):
		_begin_status = _local_status(false, &"restore_rejected")
		return
	if load_status.get("reason") in [
		&"settings_payload_invalid", &"settings_payload_newer",
	]:
		_begin_status = _local_status(
			false,
			&"settings_authority_blocked",
			{"settings_reason": load_status.get("reason")}
		)
		return
	var restored_snapshot := _policy.get_snapshot()
	var prior_startup_generation := int(restored_snapshot.get("startup_generation", 0))
	if prior_startup_generation >= Record.MAX_SAFE_JSON_INTEGER:
		_begin_status = _local_status(false, &"startup_generation_exhausted")
		return
	_startup_generation = prior_startup_generation + 1
	var commit_id := _commit_id(&"begin")
	if commit_id.is_empty():
		_begin_status = _local_status(false, &"commit_id_exhausted")
		return
	_transition_attempt_count += 1
	_begin_status = _policy.mark_startup_begin(
		_startup_generation,
		int(restored_snapshot.get("record_generation", -1)),
		_store.get_generation(),
		commit_id
	).duplicate(true)
	if not bool(_begin_status.get("accepted", false)):
		return
	if _begin_status.get("reason") == &"startup_begun":
		_transition_success_count += 1
		_last_commit_id = commit_id
	_recommendation_status = _apply_recommendation(
		_policy.get_recommended_runtime_settings_patch(),
		persist_settings
	)
	# The adapter transaction advances the shared store generation. A policy
	# restore refreshes in-memory generation evidence without a second disk load.
	if bool(_recommendation_status.get("store_generation_changed", false)):
		_refresh_policy()


func note_first_settings_apply() -> void:
	if _begin_attempted_before_first_apply:
		return
	_begin_attempted_before_first_apply = _initialized and not _begin_status.is_empty()
	_starting_before_first_apply = (
		bool(_begin_status.get("accepted", false))
		and str(_policy.get_snapshot().get("state", "") if _policy != null else "")
			== Record.STATE_STARTING
	)


func advance_physics(delta: float) -> void:
	if (
		_policy == null
		or not bool(_begin_status.get("accepted", false))
		or _stability_transition_attempted
		or delta <= 0.0
		or is_nan(delta)
		or is_inf(delta)
	):
		return
	if str(_policy.get_snapshot().get("state", "")) != Record.STATE_STARTING:
		return
	_physics_elapsed = minf(STABILITY_PHYSICS_SECONDS, _physics_elapsed + delta)
	if _physics_elapsed + STABILITY_EPSILON < STABILITY_PHYSICS_SECONDS:
		return
	_physics_elapsed = STABILITY_PHYSICS_SECONDS
	_stability_transition_attempted = true
	var refreshed := _refresh_policy()
	if not bool(refreshed.get("accepted", false)):
		_stable_status = _local_status(
			false, &"policy_refresh_failed", {"policy_status": refreshed}
		)
		return
	var snapshot := _policy.get_snapshot()
	var commit_id := _commit_id(&"stable")
	if commit_id.is_empty():
		_stable_status = _local_status(false, &"commit_id_exhausted")
		return
	_transition_attempt_count += 1
	_stable_status = _policy.mark_stable_after_physics_window(
		_startup_generation,
		int(snapshot.get("record_generation", -1)),
		_store.get_generation(),
		commit_id
	).duplicate(true)
	if (
		bool(_stable_status.get("accepted", false))
		and _stable_status.get("reason") == &"startup_stable"
	):
		_transition_success_count += 1
		_last_commit_id = commit_id


func mark_orderly_shutdown() -> Dictionary:
	if _policy == null or not _initialized:
		_orderly_shutdown_status = _local_status(false, &"policy_unavailable")
		return _orderly_shutdown_status.duplicate(true)
	var refreshed := _refresh_policy()
	if not bool(refreshed.get("accepted", false)):
		_orderly_shutdown_status = _local_status(
			false,
			&"policy_refresh_failed",
			{"policy_status": refreshed}
		)
		return _orderly_shutdown_status.duplicate(true)
	var snapshot := _policy.get_snapshot()
	var commit_id := _commit_id(&"clean")
	if commit_id.is_empty():
		_orderly_shutdown_status = _local_status(false, &"commit_id_exhausted")
		return _orderly_shutdown_status.duplicate(true)
	_transition_attempt_count += 1
	_orderly_shutdown_status = _policy.mark_clean_shutdown(
		_startup_generation,
		int(snapshot.get("record_generation", -1)),
		_store.get_generation(),
		commit_id
	).duplicate(true)
	if (
		bool(_orderly_shutdown_status.get("accepted", false))
		and _orderly_shutdown_status.get("reason") == &"clean_shutdown"
	):
		_transition_success_count += 1
		_last_commit_id = commit_id
	return _orderly_shutdown_status.duplicate(true)


func validate_recommendation(recommendation: Dictionary) -> Dictionary:
	var expected_keys := [
		"schema_version",
		"recommendation_id",
		"target_payload_namespace",
		"required_runtime_settings_payload_schema_version",
		"values_patch",
		"preserve_unlisted_values",
		"preserved_value_keys",
		"applies_settings",
		"persists_settings",
	]
	if not _has_exact_string_keys(recommendation, expected_keys):
		return _local_status(false, &"recommendation_fields_invalid")
	var schema: Variant = recommendation.get("schema_version")
	var recommendation_id: Variant = recommendation.get("recommendation_id")
	var target_namespace: Variant = recommendation.get("target_payload_namespace")
	var required_settings_schema: Variant = recommendation.get(
		"required_runtime_settings_payload_schema_version"
	)
	if (
		not schema is int
		or not recommendation_id is String
		or not target_namespace is String
		or not required_settings_schema is int
		or not recommendation.get("preserve_unlisted_values") is bool
		or not recommendation.get("applies_settings") is bool
		or not recommendation.get("persists_settings") is bool
	):
		return _local_status(false, &"recommendation_types_invalid")
	if (
		int(schema) != Policy.RECOMMENDATION_SCHEMA_VERSION
		or str(recommendation_id) != Policy.RECOMMENDATION_ID
		or str(target_namespace) != Adapter.SETTINGS_PAYLOAD_KEY
		or int(required_settings_schema)
			!= RuntimeSettings.USER_DATA_PAYLOAD_SCHEMA_VERSION
		or recommendation.get("preserve_unlisted_values") != true
		or recommendation.get("applies_settings") != false
		or recommendation.get("persists_settings") != false
	):
		return _local_status(false, &"recommendation_contract_invalid")
	var patch: Variant = recommendation.get("values_patch")
	if not patch is Dictionary or patch != {
		"graphics_profile": "low",
		"window_mode": "windowed",
	}:
		return _local_status(false, &"recommendation_patch_invalid")
	var preserved: Variant = recommendation.get("preserved_value_keys")
	if not preserved is Array or preserved != RECOMMENDATION_PRESERVED_KEYS:
		return _local_status(false, &"recommendation_preservation_invalid")
	return _local_status(true, &"validated")


func get_report() -> Dictionary:
	var policy_snapshot := _policy.get_snapshot() if _policy != null else {}
	return {
		"schema_version": 1,
		"policy_count": 1 if _policy != null else 0,
		"policy_instance_id": _policy.get_instance_id() if _policy != null else 0,
		"identity_scope": _identity_scope,
		"initialized": _initialized,
		"startup_generation": _startup_generation,
		"restore_attempt_count": _restore_attempt_count,
		"transition_attempt_count": _transition_attempt_count,
		"transition_success_count": _transition_success_count,
		"restore_status": _restore_status.duplicate(true),
		"begin_status": _begin_status.duplicate(true),
		"last_refresh_status": _last_refresh_status.duplicate(true),
		"stable_status": _stable_status.duplicate(true),
		"orderly_shutdown_status": _orderly_shutdown_status.duplicate(true),
		"recommendation_status": _recommendation_status.duplicate(true),
		"policy_snapshot": policy_snapshot.duplicate(true),
		"last_commit_id": _last_commit_id,
		"commit_clock": &"store_generation_successor",
		"commit_generation_limit": UserDataStore.MAX_GENERATION,
		"startup_generation_limit": Record.MAX_SAFE_JSON_INTEGER,
		"physics_stability_seconds": STABILITY_PHYSICS_SECONDS,
		"physics_elapsed_seconds": _physics_elapsed,
		"stability_transition_attempted": _stability_transition_attempted,
		"physics_time_owner": &"game_flow_physics_delta",
		"wall_clock_used": false,
		"idle_process_time_used": false,
		"begin_attempted_before_first_apply": _begin_attempted_before_first_apply,
		"starting_before_first_apply": _starting_before_first_apply,
		"whole_main_detach_is_shutdown": false,
		"whole_main_reentry_is_restart": false,
		"automatic_clean_shutdown_inference": false,
		"orderly_shutdown_seam": &"mark_orderly_shutdown",
		"recommendation_patch_keys": PackedStringArray([
			"graphics_profile", "window_mode",
		]),
		"settings_authority": &"runtime_settings_store_adapter",
		"gameplay_authority": false,
		"reward_authority": false,
	}.duplicate(true)


func _apply_recommendation(
	recommendation: Dictionary,
	persist_settings: Callable
	) -> Dictionary:
	if recommendation.is_empty():
		return _local_status(true, &"not_recommended")
	var validation := validate_recommendation(recommendation)
	if not bool(validation.get("accepted", false)):
		return validation
	if _store.get_loaded_source() == &"backup":
		return _local_status(false, &"store_recovery_required")
	var store_payload := _store.get_snapshot()
	if store_payload.has(Adapter.SETTINGS_PAYLOAD_KEY):
		var existing_validation := _settings.validate_user_data_payload(
			store_payload[Adapter.SETTINGS_PAYLOAD_KEY]
		)
		if not bool(existing_validation.get("accepted", false)):
			return _local_status(
				false,
				&"settings_authority_rejected",
				{"payload_reason": existing_validation.get("reason")}
			)
	var before_payload := _settings.to_user_data_payload()
	var merged_payload := before_payload.duplicate(true)
	var merged_values := merged_payload.get("values", {}) as Dictionary
	merged_values["graphics_profile"] = "low"
	merged_values["window_mode"] = "windowed"
	merged_payload["values"] = merged_values
	var merged_validation := _settings.validate_user_data_payload(merged_payload)
	if not bool(merged_validation.get("accepted", false)):
		return _local_status(
			false,
			&"merged_settings_invalid",
			{"payload_reason": merged_validation.get("reason")}
		)
	if not _preserved_values_match(before_payload, merged_payload):
		return _local_status(false, &"preserved_values_changed")
	var applied := _settings.apply_user_data_payload(merged_payload)
	if not bool(applied.get("accepted", false)):
		return _local_status(
			false, &"merged_settings_apply_failed", {"apply_status": applied}
		)
	if not persist_settings.is_valid():
		_settings.apply_user_data_payload(before_payload)
		return _local_status(false, &"settings_persistence_unavailable", {
			"rolled_back_live_settings": true,
		})
	var generation_before := _store.get_generation()
	var saved := persist_settings.call() as Dictionary
	if not bool(saved.get("accepted", false)):
		_settings.apply_user_data_payload(before_payload)
		return _local_status(false, &"settings_save_failed", {
			"save_status": saved,
			"rolled_back_live_settings": true,
			"store_generation_changed": _store.get_generation() != generation_before,
		})
	return _local_status(true, &"settings_merged", {
		"save_status": saved,
		"rolled_back_live_settings": false,
		"store_generation_changed": _store.get_generation() != generation_before,
	})


func _preserved_values_match(before: Dictionary, after: Dictionary) -> bool:
	var before_values := before.get("values", {}) as Dictionary
	var after_values := after.get("values", {}) as Dictionary
	for key: String in RECOMMENDATION_PRESERVED_KEYS:
		if before_values.get(key) != after_values.get(key):
			return false
	return true


func _refresh_policy() -> Dictionary:
	if _policy == null or _store == null:
		_last_refresh_status = _local_status(false, &"policy_unavailable")
		return _last_refresh_status.duplicate(true)
	_restore_attempt_count += 1
	_last_refresh_status = _policy.restore(_store.get_generation()).duplicate(true)
	return _last_refresh_status.duplicate(true)


func _commit_id(transition: StringName) -> String:
	if _store == null:
		return ""
	var next_generation := _store.get_generation() + 1
	if next_generation < 1 or next_generation > UserDataStore.MAX_GENERATION:
		return ""
	return "%s%s-%010d" % [COMMIT_PREFIX, String(transition), next_generation]


func _local_status(
	accepted: bool,
	reason: StringName,
	details: Dictionary = {}
	) -> Dictionary:
	var result := {
		"accepted": accepted,
		"reason": reason,
		"store_generation": _store.get_generation() if _store != null else 0,
	}
	result.merge(details, true)
	return result.duplicate(true)


static func _has_exact_string_keys(candidate: Dictionary, expected: Array) -> bool:
	if candidate.size() != expected.size():
		return false
	for key: Variant in candidate:
		if not key is String or not expected.has(key):
			return false
	for key: String in expected:
		if not candidate.has(key):
			return false
	return true
