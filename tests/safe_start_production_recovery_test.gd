extends SceneTree

## Focused production composition coverage for SafeStartRecoveryPolicy. Every
## fixture injects an in-memory filesystem; this suite never touches user://.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const Settings := preload("res://scripts/settings/runtime_settings.gd")
const Store := preload("res://scripts/persistence/user_data_store.gd")
const Adapter := preload("res://scripts/settings/runtime_settings_store_adapter.gd")
const Policy := preload("res://scripts/recovery/safe_start_recovery_policy.gd")
const Record := preload("res://scripts/recovery/safe_start_recovery_record.gd")

const STORE_PATH := "memory://safe-start-production.json"
const LEGACY_PATH := "memory://safe-start-production-legacy.cfg"

var _assertions := 0
var _failures: Array[String] = []


class FakeFilesystem extends UserDataFilesystem:
	var files: Dictionary = {}
	var write_count := 0
	var fail_write_number := -1
	var fail_reads := false

	func file_exists(path: String) -> bool:
		return files.has(path)

	func directory_exists(_path: String) -> bool:
		return false

	func ensure_parent_directory(_path: String) -> Error:
		return OK

	func read_bytes(path: String, maximum_bytes: int) -> Dictionary:
		if not files.has(path):
			return {"error": ERR_FILE_NOT_FOUND, "bytes": PackedByteArray()}
		if fail_reads:
			return {"error": ERR_FILE_CANT_READ, "bytes": PackedByteArray()}
		var bytes := (files[path] as PackedByteArray).duplicate()
		if bytes.size() > maximum_bytes:
			return {"error": ERR_FILE_CORRUPT, "bytes": PackedByteArray()}
		return {"error": OK, "bytes": bytes}

	func write_bytes_and_flush(path: String, bytes: PackedByteArray) -> Error:
		write_count += 1
		if write_count == fail_write_number:
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


func _initialize() -> void:
	_run()


func _run() -> void:
	await _test_startup_physics_reentry_and_explicit_shutdown()
	_test_physics_window_at_fixed_rates()
	_test_recommendation_merge_and_atomic_failure()
	_test_transition_write_failures()
	_test_corrupt_newer_backup_and_failed_authority()
	_test_process_lifetime_recreation_identity()
	_restore_project_input_defaults()
	_finish()


func _test_startup_physics_reentry_and_explicit_shutdown() -> void:
	var filesystem := FakeFilesystem.new()
	var store := Store.new(STORE_PATH, filesystem)
	var game := MAIN_SCENE.instantiate() as GameFlow
	game.set_physics_process(false)
	_check(
		game.configure_runtime_settings_persistence(store, LEGACY_PATH),
		"real Main accepts the isolated persistence composition before startup"
	)
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	await process_frame
	var startup := game.get_safe_start_recovery_report()
	_check(
		int(startup.policy_count) == 1
		and int(startup.policy_instance_id) != 0
		and int(startup.startup_generation) == 1
		and bool(startup.restore_status.accepted)
		and startup.restore_status.reason == &"empty"
		and bool(startup.begin_status.accepted)
		and startup.begin_status.reason == &"startup_begun"
		and startup.policy_snapshot.state == Record.STATE_STARTING
		and bool(startup.begin_attempted_before_first_apply)
		and bool(startup.starting_before_first_apply)
		and int(game.get_runtime_settings_persistence_report().load_attempt_count) == 1,
		"store load, policy restore and STARTING commit precede the first settings consumer"
	)
	_check(
		store.get_generation() == 1
		and store.get_snapshot().has(Policy.PAYLOAD_NAMESPACE)
		and startup.last_commit_id == "safe-start-begin-0000000001"
		and startup.commit_clock == &"store_generation_successor"
		and not bool(startup.wall_clock_used)
		and not bool(startup.idle_process_time_used),
		"first startup publishes one deterministic bounded generation without a wall clock"
	)

	var baseline_elapsed := float(startup.physics_elapsed_seconds)
	game._advance_safe_start_recovery_physics(0.0)
	game._advance_safe_start_recovery_physics(-1.0)
	game._advance_safe_start_recovery_physics(NAN)
	game._advance_safe_start_recovery_physics(INF)
	_check(
		is_equal_approx(
			float(game.get_safe_start_recovery_report().physics_elapsed_seconds),
			baseline_elapsed
		)
		and game.get_safe_start_recovery_report().policy_snapshot.state
			== Record.STATE_STARTING,
		"zero, negative and non-finite deltas cannot advance startup stability"
	)

	for _tick in 120:
		game._physics_process(1.0 / 60.0)
	var before_detach := game.get_safe_start_recovery_report()
	var bytes_before_detach := (filesystem.files[STORE_PATH] as PackedByteArray).duplicate()
	var parent := game.get_parent()
	parent.remove_child(game)
	await process_frame
	await process_frame
	var detached := game.get_safe_start_recovery_report()
	parent.add_child(game)
	game.set_physics_process(false)
	await process_frame
	await process_frame
	var reentered := game.get_safe_start_recovery_report()
	_check(
		is_equal_approx(
			float(before_detach.physics_elapsed_seconds), baseline_elapsed + 2.0
		)
		and int(detached.policy_instance_id) == int(before_detach.policy_instance_id)
		and int(reentered.policy_instance_id) == int(before_detach.policy_instance_id)
		and int(reentered.startup_generation) == 1
		and int(reentered.transition_success_count)
			== int(before_detach.transition_success_count)
		and int(game.get_runtime_settings_persistence_report().load_attempt_count) == 1
		and filesystem.files[STORE_PATH] == bytes_before_detach,
		"whole-Main detach/re-entry preserves policy identity/time and is neither restart nor failure"
	)

	var remaining := (
		GameFlow.SAFE_START_STABILITY_PHYSICS_SECONDS
		- float(reentered.physics_elapsed_seconds)
	)
	game._physics_process(remaining - (1.0 / 60.0))
	var below_boundary := game.get_safe_start_recovery_report()
	game._physics_process(1.0 / 60.0)
	var stable := game.get_safe_start_recovery_report()
	_check(
		below_boundary.policy_snapshot.state == Record.STATE_STARTING
		and not bool(below_boundary.stability_transition_attempted)
		and stable.policy_snapshot.state == Record.STATE_STABLE
		and bool(stable.stability_transition_attempted)
		and is_equal_approx(float(stable.physics_elapsed_seconds), 5.0)
		and stable.stable_status.reason == &"startup_stable"
		and stable.last_commit_id == "safe-start-stable-0000000002"
		and store.get_generation() == 2,
		"the exact five-second caller physics boundary commits STABLE once"
	)

	parent.remove_child(game)
	await process_frame
	parent.add_child(game)
	game.set_physics_process(false)
	await process_frame
	var before_orderly := game.get_safe_start_recovery_report()
	_check(
		before_orderly.policy_snapshot.state == Record.STATE_STABLE
		and before_orderly.orderly_shutdown_status.is_empty()
		and not bool(before_orderly.automatic_clean_shutdown_inference),
		"detach/free hooks never infer a clean shutdown"
	)
	# Detach solely so the real Exit button can exercise its production signal
	# route without ending this focused test's SceneTree.
	parent.remove_child(game)
	var exit_button := game.find_child("ExitButton", true, false) as Button
	if exit_button != null:
		exit_button.pressed.emit()
	var orderly := (
		game.get_safe_start_recovery_report().orderly_shutdown_status as Dictionary
	)
	var orderly_bytes := (filesystem.files[STORE_PATH] as PackedByteArray).duplicate()
	game.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	var duplicate := (
		game.get_safe_start_recovery_report().orderly_shutdown_status as Dictionary
	)
	_check(
		exit_button != null
		and bool(orderly.accepted)
		and orderly.reason == &"clean_shutdown"
		and bool(duplicate.accepted)
		and duplicate.reason == &"already_clean"
		and game.get_safe_start_recovery_report().policy_snapshot.state
			== Record.STATE_CLEAN_SHUTDOWN
		and filesystem.files[STORE_PATH] == orderly_bytes
		and store.get_generation() == 3,
		"HUD exit and window-manager close both use the explicit idempotent orderly seam"
	)
	parent.add_child(game)
	game.set_physics_process(false)
	await process_frame
	game.queue_free()
	await process_frame
	await process_frame
	_check(
		store.get_snapshot()[Policy.PAYLOAD_NAMESPACE].state
			== Record.STATE_CLEAN_SHUTDOWN
		and filesystem.files[STORE_PATH] == orderly_bytes,
		"freeing Main after the explicit seam adds no inferred lifecycle transaction"
	)


func _test_physics_window_at_fixed_rates() -> void:
	for hz: int in [30, 120]:
		var filesystem := FakeFilesystem.new()
		var flow := GameFlow.new()
		flow.configure_runtime_settings_persistence(
			Store.new("memory://safe-start-%d.json" % hz, filesystem),
			"memory://safe-start-%d.cfg" % hz
		)
		flow._initialize_runtime_settings()
		flow.set("_initialized", true)
		var total_ticks := int(GameFlow.SAFE_START_STABILITY_PHYSICS_SECONDS * hz)
		for _tick in total_ticks - 1:
			flow._physics_process(1.0 / float(hz))
		var before := flow.get_safe_start_recovery_report()
		flow._physics_process(1.0 / float(hz))
		var after := flow.get_safe_start_recovery_report()
		_check(
			before.policy_snapshot.state == Record.STATE_STARTING
			and after.policy_snapshot.state == Record.STATE_STABLE
			and is_equal_approx(float(after.physics_elapsed_seconds), 5.0),
			"physics stability lands on the same five-second boundary at %d Hz" % hz
		)
		flow.free()


func _test_recommendation_merge_and_atomic_failure() -> void:
	var filesystem := FakeFilesystem.new()
	var store := Store.new(STORE_PATH, filesystem)
	var seeded := _custom_settings()
	var original_payload := seeded.to_user_data_payload()
	store.load()
	store.commit({
		"diagnostics": {"session": "preserve"},
		"save_slots": {"alpha": {"progress": 19}},
		Adapter.SETTINGS_PAYLOAD_KEY: original_payload,
		Policy.PAYLOAD_NAMESPACE: _threshold_predecessor_record(),
	}, 0, "recommendation-fixture")
	var canonical_original_payload := (
		store.get_snapshot()[Adapter.SETTINGS_PAYLOAD_KEY] as Dictionary
	).duplicate(true)
	filesystem.write_count = 0
	var flow := GameFlow.new()
	flow.configure_runtime_settings_persistence(store, LEGACY_PATH)
	flow._initialize_runtime_settings()
	var report := flow.get_safe_start_recovery_report()
	var settings_payload := store.get_snapshot()[Adapter.SETTINGS_PAYLOAD_KEY] as Dictionary
	_check(
		report.begin_status.snapshot.consecutive_failure_count
			== Record.SAFE_MODE_FAILURE_THRESHOLD
		and bool(report.recommendation_status.accepted)
		and report.recommendation_status.reason == &"settings_merged"
		and settings_payload.values.graphics_profile == "low"
		and settings_payload.values.window_mode == "windowed"
		and flow.get_runtime_settings().graphics_profile == Settings.GraphicsProfile.LOW
		and flow.get_runtime_settings().window_mode == Settings.WindowMode.WINDOWED,
		"threshold recommendation validates and atomically installs only low/windowed"
	)
	var wrong_type := (report.begin_status.recommendation as Dictionary).duplicate(true)
	wrong_type["schema_version"] = 1.0
	var extra_field := (report.begin_status.recommendation as Dictionary).duplicate(true)
	extra_field["forged"] = true
	var expanded_patch := (report.begin_status.recommendation as Dictionary).duplicate(true)
	(expanded_patch.values_patch as Dictionary)["camera_fov"] = 55.0
	_check(
		flow._validate_safe_start_recommendation(wrong_type).reason
			== &"recommendation_types_invalid"
		and flow._validate_safe_start_recommendation(extra_field).reason
			== &"recommendation_fields_invalid"
		and flow._validate_safe_start_recommendation(expanded_patch).reason
			== &"recommendation_patch_invalid",
		"production rejects type drift, extra fields and any recommendation wider than two keys"
	)
	var preserved := true
	for key: String in GameFlow.SAFE_START_RECOMMENDATION_PRESERVED_KEYS:
		preserved = preserved \
			and settings_payload.values[key] == canonical_original_payload.values[key]
	_check(
		preserved
		and store.get_snapshot().diagnostics.session == "preserve"
		and int(store.get_snapshot().save_slots.alpha.progress) == 19
		and store.get_generation() == 3
		and flow.get_runtime_settings_persistence_report().last_commit_id
			== "runtime-settings-0000000003"
		and report.policy_snapshot.store_generation == 3,
		"recommendation preserves bindings/controls/accessibility/audio/camera and adjacent namespaces"
	)
	var audio_fallback := flow._safe_start_production_recovery.apply_audio_recovery_fallback(
		Callable(flow, "_persist_runtime_settings")
	)
	_check(
		bool(audio_fallback.accepted)
		and audio_fallback.reason == &"audio_fallback_applied"
		and is_equal_approx(flow.get_runtime_settings().master_volume, 0.5)
		and is_equal_approx(flow.get_runtime_settings().music_volume, 0.0),
		"caller-authorized safe-start audio fallback applies validated neutral levels"
	)
	var fallback_payload := (
		store.get_snapshot()[Adapter.SETTINGS_PAYLOAD_KEY] as Dictionary
	).duplicate(true)
	flow.set("_initialized", true)
	flow._physics_process(GameFlow.SAFE_START_STABILITY_PHYSICS_SECONDS)
	_check(
		flow.get_safe_start_recovery_report().policy_snapshot.state
			== Record.STATE_STABLE
		and store.get_generation() == 5
		and store.get_snapshot()[Adapter.SETTINGS_PAYLOAD_KEY] == fallback_payload,
		"STABLE refreshes the policy after the adapter's shared-store recommendation commit"
	)
	var restored_profile := flow._safe_start_production_recovery.restore_prior_graphics_profile(
		Callable(flow, "_persist_runtime_settings")
	)
	_check(
		bool(restored_profile.accepted)
		and restored_profile.reason == &"prior_graphics_profile_restored"
		and flow.get_runtime_settings().graphics_profile == Settings.GraphicsProfile.HIGH
		and flow.get_runtime_settings().window_mode == Settings.WindowMode.FULLSCREEN
		and store.get_snapshot()[Adapter.SETTINGS_PAYLOAD_KEY].values.graphics_profile == "high"
		and store.get_snapshot()[Adapter.SETTINGS_PAYLOAD_KEY].values.window_mode == "fullscreen",
		"stable safe-start recovery explicitly restores the one-time prior graphics profile"
	)
	var restored_audio := flow._safe_start_production_recovery.restore_prior_audio_profile(
		Callable(flow, "_persist_runtime_settings")
	)
	_check(
		bool(restored_audio.accepted)
		and restored_audio.reason == &"prior_audio_profile_restored"
		and is_equal_approx(flow.get_runtime_settings().master_volume, 0.71)
		and is_equal_approx(flow.get_runtime_settings().music_volume, 0.26),
		"stable safe-start recovery restores the one-time prior audio profile"
	)
	var repeated_restore := flow._safe_start_production_recovery.restore_prior_graphics_profile(
		Callable(flow, "_persist_runtime_settings")
	)
	_check(
		not bool(repeated_restore.accepted)
		and repeated_restore.reason == &"recovery_receipt_consumed",
		"the graphics recovery receipt cannot be replayed"
	)
	var repeated_audio_restore := flow._safe_start_production_recovery.restore_prior_audio_profile(
		Callable(flow, "_persist_runtime_settings")
	)
	_check(
		not bool(repeated_audio_restore.accepted)
		and repeated_audio_restore.reason == &"audio_recovery_receipt_consumed",
		"the audio recovery receipt cannot be replayed"
	)
	flow.free()

	filesystem = FakeFilesystem.new()
	store = Store.new(STORE_PATH, filesystem)
	store.load()
	store.commit({
		"diagnostics": {"session": "preserve-on-failure"},
		Adapter.SETTINGS_PAYLOAD_KEY: original_payload,
		Policy.PAYLOAD_NAMESPACE: _threshold_predecessor_record(),
	}, 0, "recommendation-failure-fixture")
	canonical_original_payload = (
		store.get_snapshot()[Adapter.SETTINGS_PAYLOAD_KEY] as Dictionary
	).duplicate(true)
	filesystem.write_count = 0
	filesystem.fail_write_number = 2
	flow = GameFlow.new()
	flow.configure_runtime_settings_persistence(store, LEGACY_PATH)
	flow._initialize_runtime_settings()
	report = flow.get_safe_start_recovery_report()
	_check(
		not bool(report.recommendation_status.accepted)
		and report.recommendation_status.reason == &"settings_save_failed"
		and bool(report.recommendation_status.rolled_back_live_settings)
		and flow.get_runtime_settings().to_dictionary() == seeded.to_dictionary()
		and store.get_snapshot()[Adapter.SETTINGS_PAYLOAD_KEY]
			== canonical_original_payload
		and store.get_snapshot().diagnostics.session == "preserve-on-failure"
		and store.get_generation() == 2
		and not filesystem.files.has(STORE_PATH + ".tmp"),
		"failed recommendation save rolls live state back and preserves durable settings authority"
	)
	flow.free()


func _test_transition_write_failures() -> void:
	var begin_filesystem := FakeFilesystem.new()
	begin_filesystem.fail_write_number = 1
	var begin_store := Store.new(
		"memory://safe-start-begin-failure.json", begin_filesystem
	)
	var begin_flow := GameFlow.new()
	begin_flow.configure_runtime_settings_persistence(begin_store, LEGACY_PATH)
	begin_flow._initialize_runtime_settings()
	var begin_report := begin_flow.get_safe_start_recovery_report()
	_check(
		not bool(begin_report.begin_status.accepted)
		and begin_report.begin_status.reason == &"store_commit_failed"
		and begin_report.begin_status.store_reason == &"temp_write_failed"
		and begin_report.policy_snapshot.state == Record.STATE_IDLE
		and begin_store.get_generation() == 0
		and not begin_filesystem.files.has("memory://safe-start-begin-failure.json")
		and not begin_filesystem.files.has("memory://safe-start-begin-failure.json.tmp"),
		"failed STARTING publication preserves empty disk and never advances local policy"
	)
	begin_flow.free()

	var stable_filesystem := FakeFilesystem.new()
	var stable_store := Store.new(
		"memory://safe-start-stable-failure.json", stable_filesystem
	)
	var stable_flow := GameFlow.new()
	stable_flow.configure_runtime_settings_persistence(stable_store, LEGACY_PATH)
	stable_flow._initialize_runtime_settings()
	stable_flow.set("_initialized", true)
	stable_filesystem.fail_write_number = 2
	stable_flow._physics_process(GameFlow.SAFE_START_STABILITY_PHYSICS_SECONDS)
	var stable_report := stable_flow.get_safe_start_recovery_report()
	var writes_after_failure := stable_filesystem.write_count
	stable_flow._physics_process(1.0)
	_check(
		not bool(stable_report.stable_status.accepted)
		and stable_report.stable_status.reason == &"store_commit_failed"
		and stable_report.policy_snapshot.state == Record.STATE_STARTING
		and bool(stable_report.stability_transition_attempted)
		and stable_store.get_generation() == 1
		and stable_filesystem.write_count == writes_after_failure
		and not stable_filesystem.files.has("memory://safe-start-stable-failure.json.tmp"),
		"failed STABLE publication remains conservatively STARTING without per-frame write retries"
	)
	stable_flow.free()


func _test_corrupt_newer_backup_and_failed_authority() -> void:
	var invalid_filesystem := FakeFilesystem.new()
	var invalid_store := Store.new(STORE_PATH, invalid_filesystem)
	invalid_store.load()
	invalid_store.commit({
		Adapter.SETTINGS_PAYLOAD_KEY: {
			"schema_version": Settings.USER_DATA_PAYLOAD_SCHEMA_VERSION,
			"values": {"graphics_profile": "broken"},
		},
		Policy.PAYLOAD_NAMESPACE: _threshold_predecessor_record(),
	}, 0, "invalid-settings")
	var invalid_bytes := (invalid_filesystem.files[STORE_PATH] as PackedByteArray).duplicate()
	var invalid_flow := GameFlow.new()
	invalid_flow.configure_runtime_settings_persistence(invalid_store, LEGACY_PATH)
	invalid_flow._initialize_runtime_settings()
	var invalid_report := invalid_flow.get_safe_start_recovery_report()
	_check(
		invalid_flow.get_runtime_settings_persistence_report().load_status.reason
			== &"settings_payload_invalid"
		and invalid_report.begin_status.reason == &"settings_authority_blocked"
		and invalid_filesystem.files[STORE_PATH] == invalid_bytes
		and invalid_store.get_generation() == 1,
		"corrupt RuntimeSettings authority blocks STARTING and recommendation writes byte-for-byte"
	)
	invalid_flow.free()

	var newer_filesystem := FakeFilesystem.new()
	var newer_store := Store.new(STORE_PATH, newer_filesystem)
	newer_store.load()
	newer_store.commit({
		Adapter.SETTINGS_PAYLOAD_KEY: {
			"schema_version": Settings.USER_DATA_PAYLOAD_SCHEMA_VERSION + 1,
			"values": {},
		},
		Policy.PAYLOAD_NAMESPACE: _threshold_predecessor_record(),
	}, 0, "newer-settings")
	var newer_bytes := (newer_filesystem.files[STORE_PATH] as PackedByteArray).duplicate()
	var newer_flow := GameFlow.new()
	newer_flow.configure_runtime_settings_persistence(newer_store, LEGACY_PATH)
	newer_flow._initialize_runtime_settings()
	_check(
		newer_flow.get_runtime_settings_persistence_report().load_status.reason
			== &"settings_payload_newer"
		and newer_flow.get_safe_start_recovery_report().begin_status.reason
			== &"settings_authority_blocked"
		and newer_filesystem.files[STORE_PATH] == newer_bytes,
		"newer RuntimeSettings authority is never rewritten by this build"
	)
	newer_flow.free()

	var recovery_newer_filesystem := FakeFilesystem.new()
	var recovery_newer_store := Store.new(STORE_PATH, recovery_newer_filesystem)
	recovery_newer_store.load()
	recovery_newer_store.commit({
		Adapter.SETTINGS_PAYLOAD_KEY: _custom_settings().to_user_data_payload(),
		Policy.PAYLOAD_NAMESPACE: {
			"schema_version": Record.SCHEMA_VERSION + 1,
			"future": true,
		},
	}, 0, "newer-recovery")
	var recovery_newer_bytes := (
		recovery_newer_filesystem.files[STORE_PATH] as PackedByteArray
	).duplicate()
	var recovery_newer_flow := GameFlow.new()
	recovery_newer_flow.configure_runtime_settings_persistence(
		recovery_newer_store, LEGACY_PATH
	)
	recovery_newer_flow._initialize_runtime_settings()
	var recovery_newer_report := recovery_newer_flow.get_safe_start_recovery_report()
	_check(
		not bool(recovery_newer_report.restore_status.accepted)
		and recovery_newer_report.restore_status.reason == &"record_schema_newer"
		and recovery_newer_report.begin_status.reason == &"restore_rejected"
		and recovery_newer_filesystem.files[STORE_PATH] == recovery_newer_bytes
		and recovery_newer_flow.get_runtime_settings().to_dictionary()
			== _custom_settings().to_dictionary(),
		"newer recovery authority is retained exactly while valid settings still load"
	)
	recovery_newer_flow.free()

	var backup_filesystem := FakeFilesystem.new()
	var authority := Store.new(STORE_PATH, backup_filesystem)
	authority.load()
	authority.commit({
		Adapter.SETTINGS_PAYLOAD_KEY: _custom_settings().to_user_data_payload(),
		Policy.PAYLOAD_NAMESPACE: _threshold_predecessor_record(),
	}, 0, "backup-authority")
	var successor := authority.get_snapshot()
	successor["diagnostics"] = {"newer": true}
	authority.commit(successor, 1, "primary-successor")
	backup_filesystem.files[STORE_PATH] = "{corrupt-primary".to_utf8_buffer()
	var corrupt_primary := (backup_filesystem.files[STORE_PATH] as PackedByteArray).duplicate()
	var backup_before := (backup_filesystem.files[STORE_PATH + ".bak"] as PackedByteArray).duplicate()
	var backup_flow := GameFlow.new()
	backup_flow.configure_runtime_settings_persistence(
		Store.new(STORE_PATH, backup_filesystem), LEGACY_PATH
	)
	backup_flow._initialize_runtime_settings()
	var backup_report := backup_flow.get_safe_start_recovery_report()
	_check(
		backup_report.begin_status.reason == &"store_recovery_required"
		and backup_filesystem.files[STORE_PATH] == corrupt_primary
		and backup_filesystem.files[STORE_PATH + ".bak"] == backup_before,
		"backup recovery may load for presentation but cannot repair or advance authority implicitly"
	)
	backup_flow.free()

	var failed_filesystem := FakeFilesystem.new()
	failed_filesystem.files[STORE_PATH] = "unreadable".to_utf8_buffer()
	failed_filesystem.fail_reads = true
	var failed_before := (failed_filesystem.files[STORE_PATH] as PackedByteArray).duplicate()
	var failed_flow := GameFlow.new()
	failed_flow.configure_runtime_settings_persistence(
		Store.new(STORE_PATH, failed_filesystem), LEGACY_PATH
	)
	failed_flow._initialize_runtime_settings()
	_check(
		failed_flow.get_safe_start_recovery_report().restore_status.reason
			== &"store_load_unavailable"
		and failed_flow.get_safe_start_recovery_report().begin_status.reason
			== &"not_attempted"
		and failed_flow.get_runtime_settings().to_dictionary()
			== Settings.new(LEGACY_PATH).to_dictionary()
		and failed_filesystem.files[STORE_PATH] == failed_before,
		"failed store load leaves defaults live and performs no recovery mutation"
	)
	failed_flow.free()


func _test_process_lifetime_recreation_identity() -> void:
	var filesystem := FakeFilesystem.new()
	var store := Store.new("memory://safe-start-process.json", filesystem)
	var first := GameFlow.new()
	first.set("_runtime_settings_user_data_store", store)
	first.set("_runtime_settings_legacy_path", "memory://safe-start-process.cfg")
	first._initialize_runtime_settings()
	var first_report := first.get_safe_start_recovery_report()
	first.free()
	var recreated := GameFlow.new()
	recreated._initialize_runtime_settings()
	var recreated_report := recreated.get_safe_start_recovery_report()
	_check(
		first_report.identity_scope == &"process_lifetime"
		and recreated_report.identity_scope == &"process_lifetime"
		and int(recreated_report.policy_instance_id) == int(first_report.policy_instance_id)
		and int(recreated_report.startup_generation) == int(first_report.startup_generation)
		and int(recreated_report.transition_attempt_count)
			== int(first_report.transition_attempt_count)
		and int(recreated.get_runtime_settings_persistence_report().load_attempt_count) == 1
		and store.get_generation() == 1,
		"destroyed/recreated production GameFlow adopts one process policy without reload or restart"
	)
	recreated.free()


func _threshold_predecessor_record() -> Dictionary:
	return {
		"schema_version": Record.SCHEMA_VERSION,
		"record_generation": 3,
		"state": Record.STATE_STARTING,
		"startup_generation": 3,
		"consecutive_failure_count": Record.SAFE_MODE_FAILURE_THRESHOLD - 1,
		"safe_settings_recommended": false,
	}


func _custom_settings() -> RuntimeSettings:
	var settings := Settings.new(LEGACY_PATH) as RuntimeSettings
	settings.ship_mouse_sensitivity = 0.0061
	settings.on_foot_mouse_sensitivity = 0.0052
	settings.invert_ship_y = true
	settings.invert_on_foot_y = true
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
	settings.ui_scale = 1.3
	settings.colorblind_palette = Settings.ColorblindPalette.DEUTERANOPIA
	settings.reduced_motion = true
	settings.captions_enabled = true
	return settings


func _restore_project_input_defaults() -> void:
	var settings := Settings.new(LEGACY_PATH)
	settings.reset_to_defaults()
	settings.apply_input_bindings()


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("SAFE_START_PRODUCTION_RECOVERY_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	printerr("SAFE_START_PRODUCTION_RECOVERY_TEST_FAILED: %s" % "; ".join(_failures))
	quit(1)
