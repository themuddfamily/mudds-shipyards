extends SceneTree

## Focused production composition test for the atomic RuntimeSettings store.
## Every Main instance receives an in-memory UserDataStore before entering the
## tree; this suite never reads or writes the developer's real user:// data.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const Settings := preload("res://scripts/settings/runtime_settings.gd")
const Store := preload("res://scripts/persistence/user_data_store.gd")
const Adapter := preload("res://scripts/settings/runtime_settings_store_adapter.gd")
const Profile := preload("res://scripts/settings/input_binding_profile.gd")

const STORE_PATH := "memory://runtime-settings-production.json"
const LEGACY_PATH := "memory://runtime-settings-production-legacy.cfg"

var _assertions := 0
var _failures: Array[String] = []


class FakeFilesystem extends UserDataFilesystem:
	var files: Dictionary = {}
	var fail_write_once := false
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
		if fail_write_once:
			fail_write_once = false
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


class MutableInputProvider:
	extends RefCounted

	var strengths := {}
	var pressed := {}

	func get_action_strength(action: StringName) -> float:
		return float(strengths.get(action, 0.0))

	func is_action_pressed(action: StringName) -> bool:
		return bool(pressed.get(action, false))

	func set_action(action: StringName, strength: float, is_pressed: bool) -> void:
		strengths[action] = strength
		pressed[action] = is_pressed


func _initialize() -> void:
	_run()


func _run() -> void:
	await _test_production_startup_transactions_and_reentry()
	_test_empty_corrupt_newer_and_failed_loads()
	_test_process_lifetime_recreation_identity()
	_restore_project_input_defaults()
	_finish()


func _test_production_startup_transactions_and_reentry() -> void:
	var filesystem := FakeFilesystem.new()
	var store := Store.new(STORE_PATH, filesystem)
	var seeded_settings := Settings.new(LEGACY_PATH)
	seeded_settings.ship_mouse_sensitivity = 0.0067
	seeded_settings.on_foot_mouse_sensitivity = 0.0071
	seeded_settings.camera_fov = 96.0
	seeded_settings.captions_enabled = true
	var seeded_profile := seeded_settings.get_input_binding_profile()
	var fire_bindings: Array[Dictionary] = []
	for binding: Dictionary in seeded_profile.get_bindings(&"fire"):
		if binding.device == Profile.DEVICE_GAMEPAD:
			fire_bindings.append(binding)
	fire_bindings.append({
		"device": Profile.DEVICE_KEYBOARD,
		"type": &"key",
		"physical_keycode": KEY_F13,
	})
	_check(
		seeded_profile.set_bindings(&"fire", fire_bindings)
		and seeded_profile.set_action_options(&"move_forward", {
			"deadzone": 0.31,
			"curve": Profile.CURVE_SQUARED,
			"hold_mode": Profile.HOLD,
		})
		and seeded_profile.set_action_options(&"sprint_boost", {
			"deadzone": 0.0,
			"curve": Profile.CURVE_LINEAR,
			"hold_mode": Profile.TOGGLE,
		})
		and seeded_settings.set_input_binding_profile(seeded_profile),
		"fixture creates one complete validated custom binding and processing profile"
	)
	_check(bool(store.load().accepted), "fixture opens the injected empty store")
	_check(
		bool(store.commit({
			"diagnostics": {"last_session": "keep-me"},
			"save_slots": {"slot_a": {"progress": 42}},
			Adapter.SETTINGS_PAYLOAD_KEY: seeded_settings.to_user_data_payload(),
		}, 0, "fixture-generation-1").accepted),
		"fixture publishes settings beside unrelated diagnostic and save namespaces"
	)

	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(
		game.configure_runtime_settings_persistence(store, LEGACY_PATH),
		"production Main accepts one injected persistence authority before startup"
	)
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame

	var hud := game.get_node_or_null(^"HUD") as GameHUD
	var player := game.get_node_or_null(^"Player") as PlayerController
	var settings := game.get_runtime_settings()
	var startup := game.get_runtime_settings_persistence_report()
	_check(
		int(startup.store_count) == 1
		and int(startup.adapter_count) == 1
		and int(startup.store_instance_id) == store.get_instance_id()
		and int(startup.adapter_instance_id) != 0
		and int(startup.load_attempt_count) == 1
		and bool(startup.load_status.accepted)
		and startup.load_status.reason == &"loaded"
		and bool(startup.load_before_first_apply),
		"startup owns one retained store/adapter and completes exactly one load before first apply"
	)
	_check(
		settings != null
		and hud != null
		and player != null
		and is_equal_approx(settings.camera_fov, 96.0)
		and is_equal_approx(player.mouse_sensitivity, 0.0071)
		and game.get_flyable_ships().size() == 5,
		"validated loaded settings reach the real Player and complete five-ship fleet"
	)
	var ships_match := true
	for fleet_ship: HeroShip in game.get_flyable_ships():
		ships_match = ships_match \
			and is_equal_approx(fleet_ship.mouse_sensitivity, 0.0067) \
			and is_equal_approx(fleet_ship.get_camera_fov(), 96.0)
	_check(ships_match, "every ship consumes the loaded snapshot before production play begins")
	var startup_profile_matches := true
	var startup_generations := PackedInt64Array()
	for fleet_ship: HeroShip in game.get_flyable_ships():
		var source := fleet_ship.get_command_source() as LocalShipInputSource
		startup_profile_matches = startup_profile_matches \
			and source != null \
			and source.get_input_binding_profile().to_dictionary() \
				== settings.get_input_binding_profile().to_dictionary()
		startup_generations.append(source.get_input_profile_generation() if source != null else -1)
	_check(
		startup_profile_matches and startup_generations == PackedInt64Array([3, 3, 3, 3, 3]),
		"startup atomically installs the persisted options into all five production transform banks"
	)
	var curve_source := game.get_flyable_ships()[1].get_local_input_source()
	Input.action_press(&"move_forward", 0.6)
	var curved_command := curve_source.next_command(900)
	Input.action_release(&"move_forward")
	var curve_audit := curve_source.get_input_integration_audit()
	_check(
		is_equal_approx(curved_command.throttle, 0.36)
		and bool(curve_audit.production_input_profile_active)
		and curve_audit.production_input_strength_domain == &"input_map_resolved",
		"production input executes the stored squared curve without applying InputMap's deadzone response twice"
	)
	var hud_binding_report := hud.get_input_binding_report()
	_check(
		_input_map_has_key(&"fire", KEY_F13)
		and not _input_map_has_key(&"fire", KEY_F)
		and int(hud_binding_report.action_count) == 22
		and (hud_binding_report.bindings as Dictionary)[&"fire"]
			== settings.get_input_binding_profile().get_bindings(&"fire"),
		"the complete persisted binding profile reaches InputMap and HUD before input consumers"
	)

	var local_source_ids := PackedInt64Array()
	for fleet_ship: HeroShip in game.get_flyable_ships():
		var source := fleet_ship.get_local_input_source()
		local_source_ids.append(source.get_instance_id())
	var probed_source := game.get_flyable_ships()[0].get_local_input_source()
	var provider := MutableInputProvider.new()
	probed_source.set_input_provider(provider)
	probed_source.next_command(1000)
	provider.set_action(&"sprint_boost", 1.0, true)
	var generations_before_profile_change := _fleet_input_generations(game)
	var live_profile := settings.get_input_binding_profile()
	_check(
		live_profile.set_action_options(&"move_forward", {
			"deadzone": 0.42,
			"curve": Profile.CURVE_SQUARED,
			"hold_mode": Profile.HOLD,
		})
		and settings.set_input_binding_profile(live_profile),
		"RuntimeSettings accepts one live complete processing-profile replacement"
	)
	var live_profiles_match := true
	var live_generations := PackedInt64Array()
	var banks_own_no_input_map := true
	for fleet_ship: HeroShip in game.get_flyable_ships():
		var source := fleet_ship.get_local_input_source()
		live_profiles_match = live_profiles_match \
			and source.get_input_binding_profile().to_dictionary() \
				== settings.get_input_binding_profile().to_dictionary()
		live_generations.append(source.get_input_profile_generation())
		banks_own_no_input_map = banks_own_no_input_map \
			and not bool(source.get_input_integration_audit().bank.mutates_input_map)
	var primed_toggle := probed_source.next_command(1001)
	provider.set_action(&"sprint_boost", 0.0, false)
	probed_source.next_command(1002)
	provider.set_action(&"sprint_boost", 1.0, true)
	var repressed_toggle := probed_source.next_command(1003)
	_check(
		live_profiles_match
		and _generations_advanced(generations_before_profile_change, live_generations, 1)
		and _fleet_local_source_ids(game) == local_source_ids
		and is_equal_approx(InputMap.action_get_deadzone(&"move_forward"), 0.42)
		and banks_own_no_input_map,
		"one live RuntimeSettings change advances all five banks exactly once while RuntimeSettings alone mutates InputMap"
	)
	_check(
		not primed_toggle.boost and repressed_toggle.boost,
		"live profile replacement primes a held toggle without synthesizing flight intent"
	)
	var incomplete := Profile.from_dictionary({
		"schema_version": Profile.SCHEMA_VERSION,
		"bindings": {&"fire": []},
		"action_options": {&"fire": Profile.default_action_options()},
	})
	var generations_before_rejection := live_generations.duplicate()
	_check(
		not settings.set_input_binding_profile(incomplete)
		and _fleet_input_generations(game) == generations_before_rejection
		and is_equal_approx(InputMap.action_get_deadzone(&"move_forward"), 0.42),
		"an incomplete live roster changes neither any bank generation nor InputMap"
	)
	_check(
		not game.configure_runtime_settings_persistence(
			Store.new("memory://late-authority.json", FakeFilesystem.new()),
			"memory://late-legacy.cfg"
		),
		"startup permanently closes the persistence-authority injection seam"
	)

	# Returned status is detached all the way through nested store evidence.
	var detached := game.get_runtime_settings_persistence_report()
	detached.load_status["reason"] = &"consumer_mutation"
	(detached.load_status.store_status as Dictionary)["payload"] = {"tampered": true}
	_check(
		game.get_runtime_settings_persistence_report().load_status.reason == &"loaded"
		and not (
			game.get_runtime_settings_persistence_report().load_status.store_status.payload
			as Dictionary
		).has("tampered"),
		"load and save diagnostics are deeply detached from persistence authority"
	)

	var commit_ids := PackedStringArray()
	hud.setting_change_requested.emit(&"camera_fov", 88.0)
	var changed := game.get_runtime_settings_persistence_report()
	commit_ids.append(str(changed.last_commit_id))
	_check(
		is_equal_approx(settings.camera_fov, 88.0)
		and int(changed.save_attempt_count) == 1
		and int(changed.save_success_count) == 1
		and int(changed.accepted_transaction_count) == 1
		and not bool(changed.unsaved_changes)
		and changed.last_save_status.reason == &"saved"
		and changed.last_commit_id == "runtime-settings-0000000003",
		"an accepted live change commits once with the first deterministic monotonic ID"
	)
	var attempts_before_noop := int(changed.save_attempt_count)
	hud.setting_change_requested.emit(&"camera_fov", 88.0)
	hud.setting_change_requested.emit(&"not_a_setting", true)
	_check(
		int(game.get_runtime_settings_persistence_report().save_attempt_count)
			== attempts_before_noop,
		"an unchanged value and unknown key create no settings transaction or disk write"
	)

	# A synchronous setting signal tries both public transaction entries. The
	# outer HUD transaction remains the only writer and commits after signals end.
	var signal_reentry := func(_setting: StringName, _value: Variant) -> void:
		game._on_settings_save_requested()
		game._on_setting_change_requested(&"ui_scale", 1.3)
	settings.setting_changed.connect(signal_reentry, CONNECT_ONE_SHOT)
	hud.setting_change_requested.emit(&"master_volume", 0.45)
	var after_reentry := game.get_runtime_settings_persistence_report()
	commit_ids.append(str(after_reentry.last_commit_id))
	_check(
		int(after_reentry.save_attempt_count) == 2
		and int(after_reentry.reentrant_rejection_count) == 2
		and is_equal_approx(settings.master_volume, 0.45)
		and is_equal_approx(settings.ui_scale, Settings.DEFAULT_UI_SCALE),
		"settings signals cannot recur into save or a nested settings transaction"
	)

	var disk_before_failure := (filesystem.files[STORE_PATH] as PackedByteArray).duplicate()
	filesystem.fail_write_once = true
	hud.setting_change_requested.emit(&"camera_fov", 91.0)
	var failed := game.get_runtime_settings_persistence_report()
	var failed_candidate_id := str(failed.last_save_status.commit_id)
	var live_failure_applied := is_equal_approx(settings.camera_fov, 91.0)
	for fleet_ship: HeroShip in game.get_flyable_ships():
		live_failure_applied = live_failure_applied \
			and is_equal_approx(fleet_ship.get_camera_fov(), 91.0)
	_check(
		live_failure_applied
		and bool(failed.unsaved_changes)
		and not bool(failed.last_save_status.accepted)
		and failed.last_save_status.reason == &"store_commit_failed"
		and failed.last_save_status.store_reason == &"temp_write_failed"
		and failed.last_commit_id == "runtime-settings-0000000004"
		and int(failed.commit_serial) == 4
		and failed_candidate_id == "runtime-settings-0000000005"
		and filesystem.files[STORE_PATH] == disk_before_failure
		and not filesystem.files.has(STORE_PATH + ".tmp"),
		"failed save keeps the accepted live change, marks it unsaved and preserves canonical disk"
	)
	hud.setting_change_requested.emit(&"camera_fov", 92.0)
	var retried := game.get_runtime_settings_persistence_report()
	commit_ids.append(str(retried.last_commit_id))
	_check(
		not bool(retried.unsaved_changes)
		and bool(retried.last_save_status.accepted)
		and failed_candidate_id == str(retried.last_commit_id)
		and is_equal_approx(settings.camera_fov, 92.0),
		"a retry reuses the unconsumed deterministic ID, publishes live state and clears unsaved state"
	)

	hud.settings_reset_requested.emit()
	var reset := game.get_runtime_settings_persistence_report()
	commit_ids.append(str(reset.last_commit_id))
	_check(
		settings.to_dictionary() == Settings.new(LEGACY_PATH).to_dictionary()
		and bool(reset.last_save_status.accepted)
		and not bool(reset.unsaved_changes),
		"Reset Defaults applies and persists as exactly one atomic transaction"
	)
	hud.settings_save_requested.emit()
	var explicit := game.get_runtime_settings_persistence_report()
	commit_ids.append(str(explicit.last_commit_id))
	_check(
		bool(explicit.last_save_status.accepted)
		and int(explicit.accepted_transaction_count) == 6
		and commit_ids == PackedStringArray([
			"runtime-settings-0000000003",
			"runtime-settings-0000000004",
			"runtime-settings-0000000005",
			"runtime-settings-0000000006",
			"runtime-settings-0000000007",
		]),
		"every committed change, reset and explicit-save ID is bounded, deterministic and monotonic"
	)
	var composed := store.get_snapshot()
	_check(
		(composed.diagnostics as Dictionary).last_session == "keep-me"
		and int((composed.save_slots.slot_a as Dictionary).progress) == 42
		and composed.has(Adapter.SETTINGS_PAYLOAD_KEY),
		"every settings commit preserves unrelated diagnostic and save namespaces"
	)

	var before_detach := game.get_runtime_settings_persistence_report()
	var source_ids_before_detach := _fleet_local_source_ids(game)
	var generations_before_detach := _fleet_input_generations(game)
	var profile_before_detach := settings.get_input_binding_profile().to_dictionary()
	var parent := game.get_parent()
	parent.remove_child(game)
	await process_frame
	var while_detached := game.get_runtime_settings_persistence_report()
	parent.add_child(game)
	await process_frame
	await process_frame
	var after_detach := game.get_runtime_settings_persistence_report()
	_check(
		int(while_detached.store_instance_id) == int(before_detach.store_instance_id)
		and int(while_detached.adapter_instance_id) == int(before_detach.adapter_instance_id)
		and int(after_detach.store_instance_id) == int(before_detach.store_instance_id)
		and int(after_detach.adapter_instance_id) == int(before_detach.adapter_instance_id)
		and int(after_detach.load_attempt_count) == 1
		and int(after_detach.save_attempt_count) == int(before_detach.save_attempt_count)
		and _fleet_local_source_ids(game) == source_ids_before_detach
		and _generations_advanced(
			generations_before_detach,
			_fleet_input_generations(game),
			2,
		)
		and _fleet_profiles_match(game, profile_before_detach),
		"whole-Main detach/re-entry retains settings and all five source/profile identities with only the two lifecycle generation fences"
	)

	game.queue_free()
	await process_frame
	await process_frame


func _test_empty_corrupt_newer_and_failed_loads() -> void:
	var empty_filesystem := FakeFilesystem.new()
	var empty := _initialize_flow(Store.new(STORE_PATH, empty_filesystem), "empty")
	_check(
		bool(empty.report.load_status.accepted)
		and empty.report.load_status.reason == &"empty"
		and (empty.flow as GameFlow).get_runtime_settings().to_dictionary()
			== Settings.new(LEGACY_PATH).to_dictionary()
		and (empty.flow as GameFlow).get_safe_start_recovery_report()
			.policy_snapshot.state == "starting"
		and empty_filesystem.files.has(STORE_PATH),
		"empty settings authority keeps defaults live while the recovery marker owns generation one"
	)
	(empty.flow as GameFlow).free()

	var corrupt_filesystem := FakeFilesystem.new()
	corrupt_filesystem.files[STORE_PATH] = "{corrupt".to_utf8_buffer()
	var corrupt_bytes := (corrupt_filesystem.files[STORE_PATH] as PackedByteArray).duplicate()
	var corrupt := _initialize_flow(Store.new(STORE_PATH, corrupt_filesystem), "corrupt")
	(corrupt.flow as GameFlow)._on_setting_change_requested(&"camera_fov", 87.0)
	var corrupt_after := (corrupt.flow as GameFlow).get_runtime_settings_persistence_report()
	_check(
		not bool(corrupt.report.load_status.accepted)
		and corrupt.report.load_status.reason == &"store_load_failed"
		and corrupt.report.load_status.store_reason == &"no_valid_document"
		and is_equal_approx((corrupt.flow as GameFlow).get_runtime_settings().camera_fov, 87.0)
		and bool(corrupt_after.unsaved_changes)
		and corrupt_filesystem.files[STORE_PATH] == corrupt_bytes,
		"corrupt authority keeps defaults, rejects overwrite and leaves later live changes unsaved"
	)
	(corrupt.flow as GameFlow).free()

	var newer_filesystem := FakeFilesystem.new()
	var newer_store := Store.new(STORE_PATH, newer_filesystem)
	newer_store.load()
	newer_store.commit({
		Adapter.SETTINGS_PAYLOAD_KEY: {
			"schema_version": Settings.USER_DATA_PAYLOAD_SCHEMA_VERSION + 1,
			"values": {},
		},
	}, 0, "future-settings")
	var newer_bytes := (newer_filesystem.files[STORE_PATH] as PackedByteArray).duplicate()
	var newer := _initialize_flow(Store.new(STORE_PATH, newer_filesystem), "newer")
	_check(
		not bool(newer.report.load_status.accepted)
		and newer.report.load_status.reason == &"settings_payload_newer"
		and (newer.flow as GameFlow).get_runtime_settings().to_dictionary()
			== Settings.new(LEGACY_PATH).to_dictionary()
		and newer_filesystem.files[STORE_PATH] == newer_bytes,
		"newer typed settings remain authoritative bytes while this build runs defaults"
	)
	(newer.flow as GameFlow).free()

	var failed_filesystem := FakeFilesystem.new()
	failed_filesystem.files[STORE_PATH] = "unreadable-authority".to_utf8_buffer()
	failed_filesystem.fail_reads = true
	var failed_bytes := (failed_filesystem.files[STORE_PATH] as PackedByteArray).duplicate()
	var failed_load := _initialize_flow(Store.new(STORE_PATH, failed_filesystem), "failed")
	_check(
		not bool(failed_load.report.load_status.accepted)
		and failed_load.report.load_status.reason == &"store_load_failed"
		and failed_load.report.load_status.store_reason == &"no_valid_document"
		and (failed_load.flow as GameFlow).get_runtime_settings().to_dictionary()
			== Settings.new(LEGACY_PATH).to_dictionary()
		and failed_filesystem.files[STORE_PATH] == failed_bytes,
		"filesystem load failure keeps defaults live and never rewrites unreadable authority"
	)
	(failed_load.flow as GameFlow).free()


func _initialize_flow(store: UserDataStore, suffix: String) -> Dictionary:
	var flow := GameFlow.new()
	_check(
		flow.configure_runtime_settings_persistence(
			store,
			"memory://runtime-settings-%s-legacy.cfg" % suffix
		),
		"%s fixture injects its isolated store" % suffix
	)
	flow._initialize_runtime_settings()
	return {
		"flow": flow,
		"report": flow.get_runtime_settings_persistence_report(),
	}


func _test_process_lifetime_recreation_identity() -> void:
	var filesystem := FakeFilesystem.new()
	var store := Store.new("memory://process-lifetime-settings.json", filesystem)
	var seeded := Settings.new("memory://process-lifetime-legacy.cfg")
	seeded.camera_fov = 83.0
	store.load()
	store.commit(
		{Adapter.SETTINGS_PAYLOAD_KEY: seeded.to_user_data_payload()},
		0,
		"process-fixture"
	)
	# This direct pre-start assignment exercises the default production branch
	# without ever letting it construct the real user:// store. Unlike the public
	# injected seam, it deliberately allows the static process composition root.
	var first := GameFlow.new()
	first.set("_runtime_settings_user_data_store", store)
	first.set("_runtime_settings_legacy_path", "memory://process-lifetime-legacy.cfg")
	first._initialize_runtime_settings()
	var first_report := first.get_runtime_settings_persistence_report()
	var settings_id := first.get_runtime_settings().get_instance_id()
	first.free()

	var recreated := GameFlow.new()
	recreated._initialize_runtime_settings()
	var recreated_report := recreated.get_runtime_settings_persistence_report()
	_check(
		first_report.identity_scope == &"process_lifetime"
		and recreated_report.identity_scope == &"process_lifetime"
		and int(recreated_report.store_instance_id) == int(first_report.store_instance_id)
		and int(recreated_report.adapter_instance_id) == int(first_report.adapter_instance_id)
		and recreated.get_runtime_settings().get_instance_id() == settings_id
		and int(recreated_report.load_attempt_count) == 1
		and is_equal_approx(recreated.get_runtime_settings().camera_fov, 83.0),
		"a destroyed and recreated production GameFlow adopts one process-lifetime settings/store/adapter without reloading"
	)
	recreated.free()


func _input_map_has_key(action: StringName, code: Key) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == code:
			return true
	return false


func _fleet_local_source_ids(game: GameFlow) -> PackedInt64Array:
	var result := PackedInt64Array()
	for fleet_ship: HeroShip in game.get_flyable_ships():
		result.append(fleet_ship.get_local_input_source().get_instance_id())
	return result


func _fleet_input_generations(game: GameFlow) -> PackedInt64Array:
	var result := PackedInt64Array()
	for fleet_ship: HeroShip in game.get_flyable_ships():
		result.append(fleet_ship.get_local_input_source().get_input_profile_generation())
	return result


func _fleet_profiles_match(game: GameFlow, expected: Dictionary) -> bool:
	for fleet_ship: HeroShip in game.get_flyable_ships():
		if fleet_ship.get_local_input_source().get_input_binding_profile().to_dictionary() != expected:
			return false
	return true


func _generations_advanced(
		before: PackedInt64Array,
		after: PackedInt64Array,
		expected_delta: int,
	) -> bool:
	if before.size() != after.size():
		return false
	for index: int in range(before.size()):
		if after[index] != before[index] + expected_delta:
			return false
	return true


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
		print("RUNTIME_SETTINGS_PRODUCTION_PERSISTENCE_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	printerr(
		"RUNTIME_SETTINGS_PRODUCTION_PERSISTENCE_TEST_FAILED: %s"
		% "; ".join(_failures)
	)
	quit(1)
