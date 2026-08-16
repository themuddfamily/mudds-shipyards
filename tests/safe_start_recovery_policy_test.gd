extends SceneTree

const Policy := preload("res://scripts/recovery/safe_start_recovery_policy.gd")
const Record := preload("res://scripts/recovery/safe_start_recovery_record.gd")
const Settings := preload("res://scripts/settings/runtime_settings.gd")
const Store := preload("res://scripts/persistence/user_data_store.gd")

const STORE_PATH := "memory://safe_start_recovery.json"

var _assertions := 0
var _failures := PackedStringArray()


class FakeFilesystem extends UserDataFilesystem:
	var files: Dictionary = {}
	var fail_write_once := false
	var partial_write_on_failure := false

	func file_exists(path: String) -> bool:
		return files.has(path)

	func directory_exists(_path: String) -> bool:
		return false

	func ensure_parent_directory(_path: String) -> Error:
		return OK

	func read_bytes(path: String, maximum_bytes: int) -> Dictionary:
		if not files.has(path):
			return {"error": ERR_FILE_NOT_FOUND, "bytes": PackedByteArray()}
		var bytes := (files[path] as PackedByteArray).duplicate()
		if bytes.size() > maximum_bytes:
			return {"error": ERR_FILE_CORRUPT, "bytes": PackedByteArray()}
		return {"error": OK, "bytes": bytes}

	func write_bytes_and_flush(path: String, bytes: PackedByteArray) -> Error:
		if fail_write_once:
			fail_write_once = false
			if partial_write_on_failure:
				files[path] = bytes.slice(0, maxi(1, bytes.size() / 2))
			return ERR_FILE_CANT_WRITE
		files[path] = bytes.duplicate()
		return OK

	func remove_path(path: String) -> Error:
		if not files.has(path):
			return ERR_FILE_NOT_FOUND
		files.erase(path)
		return OK

	func rename_path(from_path: String, to_path: String) -> Error:
		if not files.has(from_path):
			return ERR_FILE_NOT_FOUND
		if files.has(to_path):
			return ERR_ALREADY_EXISTS
		files[to_path] = (files[from_path] as PackedByteArray).duplicate()
		files.erase(from_path)
		return OK


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_first_start_and_detached_namespace_composition()
	_test_unfinished_threshold_recommendation_and_stable_reset()
	_test_atomic_failure_and_generation_race()
	_test_newer_malformed_and_backup_authority()
	_test_bounds_and_explicit_authority()
	_finish()


func _test_first_start_and_detached_namespace_composition() -> void:
	var filesystem := FakeFilesystem.new()
	var store := Store.new(STORE_PATH, filesystem)
	store.load()
	var settings := _custom_settings()
	store.commit({
		"career": {"credits": 44},
		"runtime_settings": settings.to_user_data_payload(),
	}, 0, "fixture-base")
	var adjacent_before := store.get_snapshot()
	var policy := Policy.new(store) as SafeStartRecoveryPolicy
	var restored := policy.restore(1)
	_check(
		bool(restored.accepted)
		and restored.reason == &"empty"
		and int(restored.record_generation) == 0
		and restored.snapshot.state == Record.STATE_IDLE,
		"an already-loaded store with no recovery namespace restores the typed empty record"
	)
	var begun := policy.mark_startup_begin(1, 0, 1, "startup-1-begin")
	_check(
		bool(begun.accepted)
		and begun.reason == &"startup_begun"
		and int(begun.store_generation) == 2
		and int(begun.record_generation) == 1
		and begun.snapshot.state == Record.STATE_STARTING
		and int(begun.snapshot.consecutive_failure_count) == 0
		and (begun.recommendation as Dictionary).is_empty(),
		"the first explicit startup marker commits without claiming an unfinished predecessor"
	)
	var stored := store.get_snapshot()
	_check(
		stored.career == adjacent_before.career
		and stored.runtime_settings == adjacent_before.runtime_settings
		and stored.has(Policy.PAYLOAD_NAMESPACE),
		"the recovery commit preserves unrelated career and RuntimeSettings namespaces exactly"
	)
	var mutated := begun as Dictionary
	(mutated.snapshot as Dictionary)["state"] = "forged"
	(mutated.recommendation as Dictionary)["forged"] = true
	var audit := policy.audit()
	(audit.authority as Dictionary)["wall_clock"] = true
	(audit.snapshot as Dictionary)["record_generation"] = -1
	_check(
		policy.get_snapshot().state == Record.STATE_STARTING
		and int(policy.get_snapshot().record_generation) == 1
		and not bool(policy.audit().authority.wall_clock),
		"results, snapshots, recommendations, and nested audits are detached from caller mutation"
	)
	var bytes_before := (filesystem.files[STORE_PATH] as PackedByteArray).duplicate()
	var duplicate := policy.mark_startup_begin(1, 1, 2, "startup-1-duplicate")
	_check(
		bool(duplicate.accepted)
		and duplicate.reason == &"already_started"
		and store.get_generation() == 2
		and filesystem.files[STORE_PATH] == bytes_before,
		"same-generation startup reentry is an idempotent no-commit acknowledgement"
	)


func _test_unfinished_threshold_recommendation_and_stable_reset() -> void:
	var filesystem := FakeFilesystem.new()
	var store := Store.new(STORE_PATH, filesystem)
	store.load()
	var settings := _custom_settings()
	store.commit({
		"runtime_settings": settings.to_user_data_payload(),
		"save_slot": {"pilot_rank": 6},
	}, 0, "threshold-base")
	var settings_before := (store.get_snapshot().runtime_settings as Dictionary).duplicate(true)
	var policy: SafeStartRecoveryPolicy
	for startup_generation in range(1, Record.SAFE_MODE_FAILURE_THRESHOLD + 1):
		policy = Policy.new(store) as SafeStartRecoveryPolicy
		var restore := policy.restore(store.get_generation())
		var snapshot := policy.get_snapshot()
		var begin := policy.mark_startup_begin(
			startup_generation,
			int(snapshot.record_generation),
			int(restore.store_generation),
			"startup-%d-begin" % startup_generation
		)
		_check(
			bool(begin.accepted)
			and int(begin.snapshot.consecutive_failure_count) == startup_generation - 1
			and not bool(begin.snapshot.safe_settings_recommended),
			"unfinished predecessor %d increments once below the safe-mode threshold"
			% (startup_generation - 1)
		)

	policy = Policy.new(store) as SafeStartRecoveryPolicy
	policy.restore(store.get_generation())
	var transition_probe := {"calls": [], "committed": false}
	var recommendation_probe := {"calls": [], "committed": false, "patch": {}}
	var transition_callback := func(
		_transition: StringName, snapshot: Dictionary, store_generation: int
	) -> void:
		transition_probe["committed"] = (
			int(snapshot.record_generation) == policy.get_snapshot().record_generation
			and store_generation == store.get_generation()
		)
		(transition_probe.calls as Array).append_array(
			_reentrant_calls(policy, snapshot, store_generation)
		)
		snapshot["state"] = "signal_forged"
	var recommendation_callback := func(
		patch: Dictionary, snapshot: Dictionary, store_generation: int
	) -> void:
		recommendation_probe["committed"] = (
			bool(snapshot.safe_settings_recommended)
			and store_generation == store.get_generation()
		)
		recommendation_probe["patch"] = patch.duplicate(true)
		(recommendation_probe.calls as Array).append_array(
			_reentrant_calls(policy, snapshot, store_generation)
		)
		(patch.values_patch as Dictionary)["graphics_profile"] = "forged"
	policy.transition_committed.connect(transition_callback)
	policy.recommendation_available.connect(recommendation_callback)
	var threshold_before := policy.get_snapshot()
	var threshold := policy.mark_startup_begin(
		Record.SAFE_MODE_FAILURE_THRESHOLD + 1,
		int(threshold_before.record_generation),
		store.get_generation(),
		"startup-threshold-begin"
	)
	policy.transition_committed.disconnect(transition_callback)
	policy.recommendation_available.disconnect(recommendation_callback)
	_check(
		bool(threshold.accepted)
		and int(threshold.snapshot.consecutive_failure_count)
			== Record.SAFE_MODE_FAILURE_THRESHOLD
		and bool(threshold.snapshot.safe_settings_recommended)
		and bool(transition_probe.committed)
		and bool(recommendation_probe.committed)
		and _all_reentrant(transition_probe.calls as Array)
		and _all_reentrant(recommendation_probe.calls as Array),
		"the documented unfinished-start threshold commits before both signals and rejects every nested mutation"
	)
	var patch := policy.get_recommended_runtime_settings_patch()
	var patched_settings := settings_before.duplicate(true)
	for key: String in patch.values_patch:
		(patched_settings.values as Dictionary)[key] = patch.values_patch[key]
	var preserved := true
	for key: String in patch.preserved_value_keys:
		preserved = preserved \
			and (patched_settings.values as Dictionary)[key] \
			== (settings_before.values as Dictionary)[key]
	_check(
		patch.recommendation_id == Policy.RECOMMENDATION_ID
		and patch.values_patch == {
			"graphics_profile": "low",
			"window_mode": "windowed",
		}
		and bool(patch.preserve_unlisted_values)
		and not bool(patch.applies_settings)
		and not bool(patch.persists_settings)
		and preserved
		and bool(settings.validate_user_data_payload(patched_settings).accepted)
		and bool(Store.validate_payload(patch).valid),
		"the detached typed patch selects low/windowed while preserving every control, binding, accessibility, camera, and audio value"
	)
	_check(
		store.get_snapshot().runtime_settings == settings_before
		and int(store.get_snapshot().save_slot.pilot_rank) == 6,
		"publishing a recommendation neither applies nor persists settings and preserves adjacent save data"
	)

	for startup_generation in range(
		Record.SAFE_MODE_FAILURE_THRESHOLD + 2,
		Record.MAX_CONSECUTIVE_FAILURES + 5
	):
		policy = Policy.new(store) as SafeStartRecoveryPolicy
		policy.restore(store.get_generation())
		var before := policy.get_snapshot()
		policy.mark_startup_begin(
			startup_generation,
			int(before.record_generation),
			store.get_generation(),
			"startup-%d-begin" % startup_generation
		)
	_check(
		int(policy.get_snapshot().consecutive_failure_count)
			== Record.MAX_CONSECUTIVE_FAILURES,
		"the consecutive unfinished-start count saturates at its documented bound"
	)
	var active_generation := int(policy.get_snapshot().startup_generation)
	var stable := policy.mark_stable_after_physics_window(
		active_generation,
		int(policy.get_snapshot().record_generation),
		store.get_generation(),
		"startup-stable"
	)
	_check(
		bool(stable.accepted)
		and stable.snapshot.state == Record.STATE_STABLE
		and int(stable.snapshot.consecutive_failure_count) == 0
		and not bool(stable.snapshot.safe_settings_recommended)
		and (stable.recommendation as Dictionary).is_empty(),
		"explicit stability after the caller's physics window resets failures and recommendation"
	)
	var stable_bytes := (filesystem.files[STORE_PATH] as PackedByteArray).duplicate()
	var already_stable := policy.mark_stable_after_physics_window(
		active_generation,
		int(stable.record_generation),
		int(stable.store_generation),
		"startup-stable-duplicate"
	)
	_check(
		already_stable.reason == &"already_stable"
		and filesystem.files[STORE_PATH] == stable_bytes,
		"stable reentry is idempotent and performs no duplicate commit"
	)
	var next := policy.mark_startup_begin(
		active_generation + 1,
		int(stable.record_generation),
		int(stable.store_generation),
		"startup-after-stable"
	)
	var clean := policy.mark_clean_shutdown(
		active_generation + 1,
		int(next.record_generation),
		int(next.store_generation),
		"startup-clean-shutdown"
	)
	var clean_bytes := (filesystem.files[STORE_PATH] as PackedByteArray).duplicate()
	var already_clean := policy.mark_clean_shutdown(
		active_generation + 1,
		int(clean.record_generation),
		int(clean.store_generation),
		"startup-clean-duplicate"
	)
	var duplicate_clean_preserved: bool = (
		filesystem.files[STORE_PATH] == clean_bytes
	)
	var after_clean := policy.mark_startup_begin(
		active_generation + 2,
		int(clean.record_generation),
		int(clean.store_generation),
		"startup-after-clean"
	)
	_check(
		int(next.snapshot.consecutive_failure_count) == 0
		and clean.snapshot.state == Record.STATE_CLEAN_SHUTDOWN
		and already_clean.reason == &"already_clean"
		and duplicate_clean_preserved
		and filesystem.files[STORE_PATH] != clean_bytes
		and int(after_clean.snapshot.consecutive_failure_count) == 0,
		"clean shutdown closes the marker without inventing a failure on the next startup"
	)


func _test_atomic_failure_and_generation_race() -> void:
	var filesystem := FakeFilesystem.new()
	var store := Store.new(STORE_PATH, filesystem)
	store.load()
	var policy := Policy.new(store) as SafeStartRecoveryPolicy
	policy.restore(0)
	var before := policy.get_snapshot()
	filesystem.fail_write_once = true
	filesystem.partial_write_on_failure = true
	var failed := policy.mark_startup_begin(1, 0, 0, "failed-startup-commit")
	_check(
		not bool(failed.accepted)
		and failed.reason == &"store_commit_failed"
		and failed.store_reason == &"temp_write_failed"
		and policy.get_snapshot() == before
		and store.get_generation() == 0
		and not filesystem.files.has(STORE_PATH)
		and not filesystem.files.has(STORE_PATH + ".tmp"),
		"atomic write failure preserves local record and disk authority while removing partial staging"
	)

	filesystem = FakeFilesystem.new()
	var winner := Store.new(STORE_PATH, filesystem)
	winner.load()
	winner.commit({"career": {"credits": 1}}, 0, "race-base")
	var stale_store := Store.new(STORE_PATH, filesystem)
	stale_store.load()
	policy = Policy.new(stale_store) as SafeStartRecoveryPolicy
	policy.restore(1)
	winner.commit({"career": {"credits": 2}, "winner": true}, 1, "race-winner")
	var winner_bytes := (filesystem.files[STORE_PATH] as PackedByteArray).duplicate()
	before = policy.get_snapshot()
	var raced := policy.mark_startup_begin(1, 0, 1, "race-loser")
	_check(
		not bool(raced.accepted)
		and raced.reason == &"store_commit_failed"
		and raced.store_reason == &"authority_changed"
		and stale_store.get_generation() == 1
		and policy.get_snapshot() == before
		and filesystem.files[STORE_PATH] == winner_bytes,
		"a stale loaded authority cannot overwrite a competing generation or drift local state"
	)


func _test_newer_malformed_and_backup_authority() -> void:
	var cases := [
		{
			"label": "newer",
			"record": {"schema_version": Record.SCHEMA_VERSION + 1, "future": true},
			"reason": &"record_schema_newer",
			"record_reason": &"newer_schema",
		},
		{
			"label": "malformed",
			"record": {"schema_version": Record.SCHEMA_VERSION},
			"reason": &"invalid_record",
			"record_reason": &"record_fields_invalid",
		},
		{
			"label": "unsafe-schema",
			"record": {
				"schema_version": float(Record.MAX_SAFE_JSON_INTEGER) + 1.0,
			},
			"reason": &"invalid_record",
			"record_reason": &"schema_invalid",
		},
	]
	for case in cases:
		var filesystem := FakeFilesystem.new()
		var store := Store.new(STORE_PATH, filesystem)
		store.load()
		store.commit({
			"career": {"credits": 81},
			Policy.PAYLOAD_NAMESPACE: case.record,
		}, 0, "%s-record" % case.label)
		var bytes_before := (filesystem.files[STORE_PATH] as PackedByteArray).duplicate()
		var policy := Policy.new(store) as SafeStartRecoveryPolicy
		var restored := policy.restore(1)
		var mutation := policy.mark_startup_begin(1, 0, 1, "must-not-overwrite")
		_check(
			not bool(restored.accepted)
			and restored.reason == case.reason
			and restored.record_reason == case.record_reason
			and not bool(mutation.accepted)
			and mutation.reason == &"not_restored"
			and store.get_generation() == 1
			and filesystem.files[STORE_PATH] == bytes_before,
			"%s recovery namespace is never restored partially or overwritten"
			% case.label
		)

	var filesystem := FakeFilesystem.new()
	var authority := Store.new(STORE_PATH, filesystem)
	authority.load()
	var authority_policy := Policy.new(authority) as SafeStartRecoveryPolicy
	authority_policy.restore(0)
	authority_policy.mark_startup_begin(1, 0, 0, "backup-startup")
	var payload := authority.get_snapshot()
	payload["career"] = {"credits": 82}
	authority.commit(payload, 1, "backup-successor")
	filesystem.files[STORE_PATH] = "{corrupt-primary".to_utf8_buffer()
	var corrupt_primary := (filesystem.files[STORE_PATH] as PackedByteArray).duplicate()
	var backup_before := (filesystem.files[STORE_PATH + ".bak"] as PackedByteArray).duplicate()
	var recovered_store := Store.new(STORE_PATH, filesystem)
	var recovered := recovered_store.load()
	var recovered_policy := Policy.new(recovered_store) as SafeStartRecoveryPolicy
	var restored_backup := recovered_policy.restore(int(recovered.generation))
	var refused := recovered_policy.mark_startup_begin(
		2,
		int(restored_backup.record_generation),
		int(recovered.generation),
		"implicit-repair-forbidden"
	)
	_check(
		bool(restored_backup.accepted)
		and not bool(refused.accepted)
		and refused.reason == &"store_recovery_required"
		and filesystem.files[STORE_PATH] == corrupt_primary
		and filesystem.files[STORE_PATH + ".bak"] == backup_before,
		"backup authority may be inspected but ordinary policy mutation cannot repair a corrupt primary"
	)


func _test_bounds_and_explicit_authority() -> void:
	var filesystem := FakeFilesystem.new()
	var store := Store.new(STORE_PATH, filesystem)
	store.load()
	var policy := Policy.new(store) as SafeStartRecoveryPolicy
	var before_restore := policy.get_snapshot()
	_check(
		policy.mark_startup_begin(1, 0, 0, "before-restore").reason == &"not_restored"
		and policy.get_snapshot() == before_restore,
		"policy mutation requires an explicit restore of caller-loaded store authority"
	)
	policy.restore(0)
	var before := policy.get_snapshot()
	var invalids := [
		policy.mark_startup_begin(0, 0, 0, "invalid-zero-startup"),
		policy.mark_startup_begin(
			Record.MAX_SAFE_JSON_INTEGER + 1, 0, 0, "invalid-large-startup"
		),
		policy.mark_startup_begin(1, 0, 0, "contains/a/path"),
		policy.mark_startup_begin(1, 1, 0, "stale-record"),
		policy.mark_startup_begin(1, 0, 1, "stale-store"),
	]
	var all_rejected := true
	for result in invalids:
		all_rejected = all_rejected and not bool((result as Dictionary).accepted)
	_check(
		all_rejected
		and policy.get_snapshot() == before
		and store.get_generation() == 0
		and filesystem.files.is_empty(),
		"invalid IDs, unsafe generations, stale generations, and path-like commit tokens fail without mutation"
	)
	var expected_authority := {
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
	}
	var source := FileAccess.get_file_as_string(
		"res://scripts/recovery/safe_start_recovery_policy.gd"
	)
	_check(
		policy.audit().authority == expected_authority
		and not source.contains("func _process")
		and not source.contains("func _physics_process")
		and not source.contains("Time.")
		and not source.contains("apply_user_data_payload")
		and not source.contains("AudioServer")
		and not source.contains("DisplayServer"),
		"the foundation owns no clock, process hook, settings application, presentation, or OS crash authority"
	)


func _custom_settings() -> RuntimeSettings:
	var settings := Settings.new() as RuntimeSettings
	settings.ship_mouse_sensitivity = 0.0061
	settings.on_foot_mouse_sensitivity = 0.0052
	settings.invert_ship_y = true
	settings.camera_fov = 89.0
	settings.master_volume = 0.71
	settings.ambience_volume = 0.62
	settings.engine_volume = 0.53
	settings.weapons_volume = 0.44
	settings.ui_volume = 0.35
	settings.music_volume = 0.26
	settings.graphics_profile = Settings.GraphicsProfile.HIGH
	settings.window_mode = Settings.WindowMode.FULLSCREEN
	settings.control_preset = Settings.ControlPreset.CLASSIC
	settings.ui_scale = 1.2
	settings.colorblind_palette = Settings.ColorblindPalette.DEUTERANOPIA
	settings.reduced_motion = true
	settings.captions_enabled = true
	return settings


func _reentrant_calls(
	policy: SafeStartRecoveryPolicy,
	snapshot: Dictionary,
	store_generation: int
	) -> Array:
	var record_generation := int(snapshot.record_generation)
	var startup_generation := int(snapshot.startup_generation)
	return [
		policy.restore(store_generation),
		policy.mark_startup_begin(
			startup_generation + 100,
			record_generation,
			store_generation,
			"nested-begin"
		),
		policy.mark_stable_after_physics_window(
			startup_generation,
			record_generation,
			store_generation,
			"nested-stable"
		),
		policy.mark_clean_shutdown(
			startup_generation,
			record_generation,
			store_generation,
			"nested-clean"
		),
	]


func _all_reentrant(results: Array) -> bool:
	if results.is_empty():
		return false
	for result in results:
		var outcome := result as Dictionary
		if bool(outcome.get("accepted", true)) \
			or outcome.get("reason") != &"reentrant_call" \
			or outcome.get("store_reason") != &"not_attempted":
			return false
	return true


func _check(condition: bool, label: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", label)
	else:
		_failures.append(label)
		push_error("FAIL: %s" % label)


func _finish() -> void:
	if _failures.is_empty():
		print("SAFE_START_RECOVERY_POLICY_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	printerr(
		"SAFE_START_RECOVERY_POLICY_TEST_FAILED: %d/%d assertions failed"
		% [_failures.size(), _assertions]
	)
	for failure in _failures:
		printerr(" - ", failure)
	quit(1)
