extends SceneTree

const GameFlowType := preload("res://scripts/game/game_flow.gd")
const HudType := preload("res://scripts/ui/hud.gd")
const SafeStartType := preload("res://scripts/recovery/safe_start_production_recovery.gd")
const MainScene := preload("res://scenes/main.tscn")
const SettingsType := preload("res://scripts/settings/runtime_settings.gd")
const StoreType := preload("res://scripts/persistence/user_data_store.gd")
const AdapterType := preload("res://scripts/settings/runtime_settings_store_adapter.gd")
const PolicyType := preload("res://scripts/recovery/safe_start_recovery_policy.gd")
const RecordType := preload("res://scripts/recovery/safe_start_recovery_record.gd")
const STORE_PATH := "memory://safe-audio-hud.json"
const LEGACY_PATH := "memory://safe-audio-hud.cfg"

var _assertions := 0
var _failures: PackedStringArray = []
var _real_main_failure_context: Dictionary = {}


class ActionFilesystem extends UserDataFilesystem:
	var files: Dictionary = {}
	var refuse_next_write := false
	var write_count := 0

	func file_exists(path: String) -> bool: return files.has(path)
	func directory_exists(_path: String) -> bool: return false
	func ensure_parent_directory(_path: String) -> Error: return OK
	func read_bytes(path: String, maximum_bytes: int) -> Dictionary:
		if not files.has(path):
			return {"error": ERR_FILE_NOT_FOUND, "bytes": PackedByteArray()}
		var bytes: PackedByteArray = (files[path] as PackedByteArray).duplicate()
		if bytes.size() > maximum_bytes:
			return {"error": ERR_FILE_CORRUPT, "bytes": PackedByteArray()}
		return {"error": OK, "bytes": bytes}
	func write_bytes_and_flush(path: String, bytes: PackedByteArray) -> Error:
		write_count += 1
		if refuse_next_write:
			refuse_next_write = false
			return ERR_FILE_CANT_WRITE
		files[path] = bytes.duplicate()
		return OK
	func remove_path(path: String) -> Error:
		if not files.has(path): return ERR_FILE_NOT_FOUND
		files.erase(path)
		return OK
	func rename_path(from_path: String, to_path: String) -> Error:
		if not files.has(from_path) or files.has(to_path): return ERR_FILE_CANT_WRITE
		files[to_path] = (files[from_path] as PackedByteArray).duplicate()
		files.erase(from_path)
		return OK


class RecoveryProbe extends SafeStartType:
	var report: Dictionary = {}
	var restore_calls: PackedStringArray = []
	var callable_validity: Array[bool] = []
	var graphics_accept := true
	var audio_accept := true
	var report_reads := 0

	func _init() -> void:
		super(null, null, false)

	func install(generation: int, revision: int) -> void:
		report = {
			"schema_version": 1,
			"report_revision": revision,
			"startup_generation": generation,
			"begin_status": {"accepted": true, "reason": &"startup_begun"},
			"restore_status": {"accepted": true, "reason": &"restored"},
			"stable_status": {"accepted": true, "reason": &"startup_stable"},
			"policy_snapshot": {
				"schema_version": 1,
				"startup_generation": generation,
				"record_generation": revision,
				"state": "stable",
			},
			"graphics_recovery_receipt": {
				"consumed": false,
				"source_store_generation": revision,
				"startup_generation": generation,
				"prior_values": {
					"graphics_profile": "high",
					"window_mode": "fullscreen",
				},
			},
			"audio_recovery_receipt": {
				"consumed": false,
				"source_store_generation": revision,
				"prior_values": {
					"master_volume": 0.8,
					"music_volume": 0.6,
				},
			},
			"restore_readiness_snapshot": {
				"schema_version": 1,
				"stability_confirmed": true,
				"graphics": _ready_domain(),
				"audio": _ready_domain(),
			},
		}.duplicate(true)

	func get_report() -> Dictionary:
		report_reads += 1
		return report.duplicate(true)

	func has_report_changed(generation: int, revision: int) -> bool:
		return generation != int(report.startup_generation) or revision != int(report.report_revision)

	func restore_prior_graphics_profile(persist_settings: Callable) -> Dictionary:
		restore_calls.append("graphics")
		callable_validity.append(persist_settings.is_valid())
		if not graphics_accept:
			return {"accepted": false, "reason": &"restored_profile_save_failed"}
		consume(&"graphics")
		return {"accepted": true, "reason": &"prior_graphics_profile_restored"}

	func restore_prior_audio_profile(persist_settings: Callable) -> Dictionary:
		restore_calls.append("audio")
		callable_validity.append(persist_settings.is_valid())
		if not audio_accept:
			return {"accepted": false, "reason": &"restored_audio_save_failed"}
		consume(&"audio")
		return {"accepted": true, "reason": &"prior_audio_profile_restored"}

	func consume(domain: StringName) -> void:
		var receipt_key := "%s_recovery_receipt" % domain
		(report[receipt_key] as Dictionary)["consumed"] = true
		var domain_readiness := (
			(report.restore_readiness_snapshot as Dictionary)[domain] as Dictionary
		)
		domain_readiness["receipt_available"] = false
		domain_readiness["fallback_active"] = false
		domain_readiness["restore_ready"] = false
		domain_readiness["reason"] = &"receipt_consumed"
		report.report_revision = int(report.report_revision) + 1
		(report.policy_snapshot as Dictionary).record_generation = report.report_revision

	func _ready_domain() -> Dictionary:
		return {
			"receipt_present": true,
			"receipt_available": true,
			"fallback_active": true,
			"restore_ready": true,
			"reason": &"restore_ready",
		}.duplicate(true)


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var hud := HudType.new()
	root.add_child(hud)
	await process_frame
	var flow := GameFlowType.new()
	var recovery := RecoveryProbe.new()
	flow.hud = hud
	flow.set("_safe_start_production_recovery", recovery)
	flow.set("_runtime_settings_persistence_injected", true)
	hud.presentation_intent_requested.connect(
		flow._on_hud_presentation_intent_requested
	)

	recovery.install(4, 8)
	var published := flow._publish_safe_start_recovery_status_to_hud()
	_check(
		bool(published.accepted)
		and hud.get("_runtime_status_kind") == &"safe_start_recovery"
		and (hud.get("_runtime_status_actions") as HBoxContainer).get_child_count() == 2,
		"the current production report publishes through the dedicated keyed HUD source"
	)
	var published_reads := recovery.report_reads
	for tick in range(120):
		flow._advance_safe_start_recovery_physics(1.0 / 60.0)
	_check(recovery.report_reads == published_reads,
		"unchanged recovery ticks do not reconstruct the full diagnostic report")
	var stale := flow._handle_safe_start_recovery_intent(
		_intent(&"restore", 4, 7)
	)
	_check(
		not bool(stale.accepted)
		and stale.reason == &"stale_recovery_fence"
		and recovery.restore_calls.is_empty(),
		"GameFlow independently fences an action to the exact startup generation and report revision"
	)
	var restore_button := (
		(hud.get("_runtime_status_actions") as HBoxContainer).get_child(0) as Button
	)
	restore_button.pressed.emit()
	_check(
		recovery.restore_calls == PackedStringArray(["graphics", "audio"])
		and recovery.callable_validity == [true, true]
		and int(recovery.report.report_revision) == 10
		and flow.get_safe_start_recovery_hud_status().reason == &"restore_completed"
		and int((
			((hud.get("_runtime_status_cards") as Dictionary)[&"safe_start_recovery"] as Dictionary)
				.get("snapshot", {}) as Dictionary
		).revision) == 10,
		"restore uses the existing persistence callable sequentially and republishes the authoritative receipt"
	)

	recovery.install(5, 1)
	recovery.restore_calls.clear()
	recovery.callable_validity.clear()
	recovery.graphics_accept = false
	recovery.audio_accept = true
	flow._advance_safe_start_recovery_physics(1.0 / 60.0)
	var partial := flow._handle_safe_start_recovery_intent(
		_intent(&"restore", 5, 1)
	)
	_check(
		not bool(partial.accepted)
		and partial.reason == &"restore_partially_completed"
		and recovery.restore_calls == PackedStringArray(["graphics", "audio"])
		and not bool((partial.details.domain_results.graphics as Dictionary).accepted)
		and bool((partial.details.domain_results.audio as Dictionary).accepted)
		and int(recovery.report.report_revision) == 2,
		"one failed domain does not suppress the independently ready domain or its partial-success receipt"
	)
	var dismissed := flow._handle_safe_start_recovery_intent(
		_intent(&"keep_safe", 5, 2)
	)
	_check(
		bool(dismissed.accepted)
		and dismissed.reason == &"keep_safe_dismissed"
		and not (hud.get("_runtime_status_cards") as Dictionary).has(&"safe_start_recovery")
		and not bool(dismissed.details.settings_authority)
		and not bool(dismissed.details.filesystem_authority),
		"keep-safe is presentation-only and clears only its source-owned card"
	)
	recovery.report.report_revision = 3
	var suppressed := flow._publish_safe_start_recovery_status_to_hud(true, true)
	_check(
		bool(suppressed.accepted)
		and suppressed.reason == &"dismissed_generation_suppressed"
		and not (hud.get("_runtime_status_cards") as Dictionary).has(&"safe_start_recovery"),
		"later revisions cannot resurrect a dismissed receipt in the same startup generation"
	)

	recovery.install(6, 1)
	recovery.graphics_accept = true
	flow._publish_safe_start_recovery_status_to_hud()
	hud.set_runtime_status_card(&"surface", {
		"title": "SURFACE ROUTE",
		"message": "Foreground owner",
		"actions": [{"id": &"acknowledge", "label": "Acknowledge"}],
	})
	var foreground_action := (
		(hud.get("_runtime_status_actions") as HBoxContainer).get_child(0) as Button
	)
	foreground_action.grab_focus()
	await process_frame
	recovery.report.report_revision = 2
	recovery.report["physics_elapsed_seconds"] = 4.5
	flow._restore_session_recovery_hud_after_reentry()
	_check(
		hud.get("_runtime_status_kind") == &"surface"
		and (hud.get("_runtime_status_actions") as HBoxContainer).get_child(0) == foreground_action
		and hud.get_viewport().gui_get_focus_owner() == foreground_action
		and int((
			((hud.get("_runtime_status_cards") as Dictionary)[&"safe_start_recovery"] as Dictionary)
				.get("snapshot", {}) as Dictionary
		).revision) == 2,
		"re-entry refreshes the retained recovery cursor in the background without promotion or focus theft"
	)
	root.remove_child(hud)
	root.add_child(hud)
	await process_frame
	flow._restore_session_recovery_hud_after_reentry()
	_check(
		(hud.get("_runtime_status_cards") as Dictionary).has(&"safe_start_recovery")
		and hud.get("_runtime_status_kind") == &"surface",
		"whole-HUD detach and reuse retains one keyed receipt and restores it without duplication"
	)

	flow.free()
	hud.queue_free()
	await process_frame
	await _test_real_main_safe_audio_action()
	await _test_real_main_audio_user_edits_and_keep_safe()
	var defaults: RuntimeSettings = SettingsType.new(LEGACY_PATH)
	defaults.reset_to_defaults()
	defaults.apply_input_bindings()
	_finish()


func _new_main_fixture() -> Dictionary:
	var filesystem: ActionFilesystem = ActionFilesystem.new()
	var store: UserDataStore = StoreType.new(STORE_PATH, filesystem)
	var settings: RuntimeSettings = SettingsType.new(LEGACY_PATH)
	settings.master_volume = 0.71
	settings.music_volume = 0.26
	settings.ambience_volume = 0.62
	settings.engine_volume = 0.53
	settings.weapons_volume = 0.44
	settings.ui_volume = 0.35
	settings.camera_fov = 89.0
	settings.ui_scale = 1.3
	settings.reduced_motion = true
	settings.captions_enabled = true
	settings.graphics_profile = SettingsType.GraphicsProfile.HIGH
	settings.window_mode = SettingsType.WindowMode.FULLSCREEN
	var original_typed: Dictionary = settings.to_user_data_payload().duplicate(true)
	store.load()
	var seeded: Dictionary = store.commit({
		AdapterType.SETTINGS_PAYLOAD_KEY: original_typed,
		PolicyType.PAYLOAD_NAMESPACE: {
			"schema_version": RecordType.SCHEMA_VERSION,
			"record_generation": 3,
			"startup_generation": 3,
			"state": RecordType.STATE_STARTING,
			"consecutive_failure_count": RecordType.SAFE_MODE_FAILURE_THRESHOLD - 1,
			"safe_settings_recommended": false,
		},
		"save_slots": {"alpha": {"progress": 19}},
		"foreign_namespace": {"keep": ["unchanged", 42]},
	}, 0, "safe-audio-hud-fixture")
	_check(bool(seeded.get("accepted", false)), "real Main fixture publishes valid isolated authority")
	var original_wire: Dictionary = (store.get_snapshot()[AdapterType.SETTINGS_PAYLOAD_KEY] as Dictionary).duplicate(true)
	var foreign_wire: Dictionary = (store.get_snapshot().foreign_namespace as Dictionary).duplicate(true)
	var main: GameFlow = MainScene.instantiate() as GameFlow
	_real_main_failure_context = {
		"main": main, "store": store, "filesystem": filesystem,
		"original_typed": original_typed, "original_wire": original_wire,
		"foreign_wire": foreign_wire,
	}
	main.set_physics_process(false)
	_check(main.configure_runtime_settings_persistence(store, LEGACY_PATH), "real Main accepts isolated audio-action authority")
	root.add_child(main)
	main.set_physics_process(false)
	await process_frame
	await process_frame
	var hud: GameHUD = main.hud as GameHUD
	var begin_shift: Button = hud.find_child("IntroBeginShiftButton", true, false) as Button
	_check(begin_shift != null and begin_shift.is_visible_in_tree(), "real Main exposes the ordinary Begin Shift button before recovery actions")
	if begin_shift != null:
		begin_shift.pressed.emit()
		await hud.start_requested
	await process_frame
	await process_frame
	_check(main.phase != GameFlow.Phase.INTRO and (hud.get("_hud") as Control).is_visible_in_tree(), "ordinary Begin Shift completes its original intro tween and reveals the real HUD")
	return {
		"main": main, "filesystem": filesystem, "store": store,
		"original_typed": original_typed, "original_wire": original_wire,
		"foreign_wire": foreign_wire,
	}


func _press_recovery_button(hud: GameHUD, label: String) -> bool:
	# Promote the existing source so this test exercises the actual rendered
	# Button callback even when another normal startup card owns the foreground.
	var cards: Dictionary = hud.get("_runtime_status_cards") as Dictionary
	if not cards.has(&"safe_start_recovery"):
		return false
	var card: Dictionary = cards[&"safe_start_recovery"] as Dictionary
	hud.set_runtime_status_card(&"safe_start_recovery", card.get("snapshot", {}) as Dictionary)
	for child: Node in (hud.get("_runtime_status_actions") as HBoxContainer).get_children():
		var button: Button = child as Button
		if button != null and button.text == label:
			button.pressed.emit()
			return true
	return false


func _test_real_main_safe_audio_action() -> void:
	var fixture: Dictionary = await _new_main_fixture()
	var main: GameFlow = fixture.main as GameFlow
	var hud: GameHUD = main.hud as GameHUD
	var filesystem: ActionFilesystem = fixture.filesystem as ActionFilesystem
	var store: UserDataStore = fixture.store as UserDataStore
	var original_typed: Dictionary = fixture.original_typed as Dictionary
	var original_wire: Dictionary = fixture.original_wire as Dictionary
	var foreign_wire: Dictionary = fixture.foreign_wire as Dictionary
	var report: Dictionary = main.get_safe_start_recovery_report()
	var live_before: Dictionary = main.get_runtime_settings().to_user_data_payload()
	_check(
		bool(report.audio_fallback_available)
		and live_before.values.master_volume == original_typed.values.master_volume
		and live_before.values.music_volume == original_typed.values.music_volume
		and (report.audio_recovery_receipt as Dictionary).is_empty(),
		"real Main automatic graphics recovery leaves the complete audio profile untouched"
	)
	var stale_intent: Dictionary = _intent(&"use_safe_audio", int(report.startup_generation), int(report.report_revision))
	var durable_before: PackedByteArray = (filesystem.files[STORE_PATH] as PackedByteArray).duplicate()
	var generation_before: int = store.get_generation()
	filesystem.refuse_next_write = true
	_check(_press_recovery_button(hud, "Use Safe Audio"), "real recovery card offers an explicit Use Safe Audio button")
	var refused: Dictionary = main.get_safe_start_recovery_hud_status()
	_check(
		refused.reason == &"audio_fallback_save_failed"
		and not bool(refused.accepted)
		and bool(refused.details.audio_result.rolled_back_live_settings)
		and main.get_runtime_settings().to_user_data_payload() == live_before
		and filesystem.files[STORE_PATH] == durable_before
		and store.get_generation() == generation_before
		and (main.get_safe_start_recovery_report().audio_recovery_receipt as Dictionary).is_empty(),
		"actual adapter write refusal rolls live audio back and retains durable bytes without creating a receipt"
	)
	var rollback_buses: Dictionary = main.get_runtime_settings().get_audio_bus_levels_db()
	var rollback_mix_matches: bool = true
	for bus_name: StringName in rollback_buses:
		var bus_index: int = AudioServer.get_bus_index(bus_name)
		rollback_mix_matches = rollback_mix_matches and bus_index >= 0
		if bus_index >= 0:
			rollback_mix_matches = rollback_mix_matches and is_equal_approx(AudioServer.get_bus_volume_db(bus_index), float(rollback_buses[bus_name]))
	_check(rollback_mix_matches, "refused persistence restores the running audio buses along with the live settings")
	main._advance_safe_start_recovery_physics(5.0)
	report = main.get_safe_start_recovery_report()
	_check(
		report.policy_snapshot.state == RecordType.STATE_STABLE
		and not bool(report.policy_snapshot.recommendation_available)
		and bool(report.audio_fallback_available),
		"Use Safe Audio remains available after five physics seconds while this startup's graphics fallback is active"
	)
	var stale_result: Dictionary = main._handle_safe_start_recovery_intent(stale_intent)
	_check(not bool(stale_result.accepted) and stale_result.reason == &"stale_recovery_fence", "a pre-stability audio intent cannot bypass the current report fence")
	# Use the existing source publication to foreground this card, then let the
	# normal containers finish sorting before measuring the three real actions.
	var stable_cards: Dictionary = hud.get("_runtime_status_cards") as Dictionary
	var stable_card: Dictionary = stable_cards.get(&"safe_start_recovery", {}) as Dictionary
	hud.set_runtime_status_card(&"safe_start_recovery", stable_card.get("snapshot", {}) as Dictionary)
	await process_frame
	await process_frame
	var geometry: Dictionary = _recovery_action_geometry(hud)
	_check(bool(geometry.get("usable", false)), "all three real recovery actions are visible, focusable and enclosed by their actual panel and viewport", geometry)
	var apply_intent: Dictionary = _intent(&"use_safe_audio", int(report.startup_generation), int(report.report_revision))
	_check(_press_recovery_button(hud, "Use Safe Audio"), "stable real HUD button invokes the existing adapter transaction")
	var applied: Dictionary = main.get_safe_start_recovery_hud_status()
	var expected_safe: Dictionary = live_before.duplicate(true)
	expected_safe.values.master_volume = 0.5
	expected_safe.values.music_volume = 0.0
	# UserDataStore's established JSON contract canonicalizes integer Variants
	# to floats. Keep typed RuntimeSettings and persisted-wire oracles separate.
	var expected_safe_wire: Dictionary = JSON.parse_string(JSON.stringify(expected_safe)) as Dictionary
	_check(
		bool(applied.accepted) and applied.reason == &"audio_fallback_applied"
		and main.get_runtime_settings().to_user_data_payload() == expected_safe
		and store.get_snapshot()[AdapterType.SETTINGS_PAYLOAD_KEY] == expected_safe_wire
		and store.get_snapshot().foreign_namespace == foreign_wire
		and int(store.get_snapshot().save_slots.alpha.progress) == 19,
		"production HUD action persists only master 0.5/music 0 and preserves all other preferences and foreign namespaces",
		{"applied": applied, "typed_expected": expected_safe, "wire_expected": expected_safe_wire, "foreign_expected": foreign_wire}
	)
	var expected_buses: Dictionary = main.get_runtime_settings().get_audio_bus_levels_db()
	var live_mix_matches: bool = true
	for bus_name: StringName in expected_buses:
		var bus_index: int = AudioServer.get_bus_index(bus_name)
		live_mix_matches = live_mix_matches and bus_index >= 0
		if bus_index >= 0:
			live_mix_matches = live_mix_matches and is_equal_approx(AudioServer.get_bus_volume_db(bus_index), float(expected_buses[bus_name]))
	_check(live_mix_matches, "real Main's existing settings signal applies the safe levels to the running audio buses")
	var writes_after_apply: int = filesystem.write_count
	_check(not bool(main._handle_safe_start_recovery_intent(apply_intent).accepted), "successful audio action cannot replay its old HUD fence")
	report = main.get_safe_start_recovery_report()
	var second_apply: Dictionary = main._handle_safe_start_recovery_intent(_intent(&"use_safe_audio", int(report.startup_generation), int(report.report_revision)))
	_check(not bool(second_apply.accepted) and second_apply.reason == &"audio_fallback_already_applied" and filesystem.write_count == writes_after_apply, "a fresh forged intent cannot apply the one-shot audio fallback twice")
	_check(_press_recovery_button(hud, "Restore Previous Graphics And Audio"), "stable existing Restore button includes both real saved profiles")
	_check(
		main.get_safe_start_recovery_hud_status().reason == &"restore_completed"
		and store.get_snapshot()[AdapterType.SETTINGS_PAYLOAD_KEY] == original_wire
		and main.get_runtime_settings().to_user_data_payload() == original_typed
		and bool(main.get_safe_start_recovery_report().audio_recovery_receipt.consumed)
		and bool(main.get_safe_start_recovery_report().graphics_recovery_receipt.consumed),
		"existing Restore returns both prior profiles durably and consumes both receipts",
		{"typed_expected": original_typed, "wire_expected": original_wire}
	)
	report = main.get_safe_start_recovery_report()
	var writes_after_restore: int = filesystem.write_count
	var replay_restore: Dictionary = main._handle_safe_start_recovery_intent(_intent(&"restore", int(report.startup_generation), int(report.report_revision)))
	var replay_audio: Dictionary = main._handle_safe_start_recovery_intent(_intent(&"use_safe_audio", int(report.startup_generation), int(report.report_revision)))
	_check(not bool(replay_restore.accepted) and not bool(replay_audio.accepted) and filesystem.write_count == writes_after_restore, "completed recovery cannot restore or reapply audio through a fresh intent")
	_real_main_failure_context.clear()
	main.free()
	await process_frame


func _test_real_main_audio_user_edits_and_keep_safe() -> void:
	var fixture: Dictionary = await _new_main_fixture()
	var main: GameFlow = fixture.main as GameFlow
	var hud: GameHUD = main.hud as GameHUD
	var filesystem: ActionFilesystem = fixture.filesystem as ActionFilesystem
	var store: UserDataStore = fixture.store as UserDataStore
	_check(_press_recovery_button(hud, "Use Safe Audio"), "real HUD audio action is also available before stability")
	var report: Dictionary = main.get_safe_start_recovery_report()
	var writes_before_stable: int = filesystem.write_count
	var early_restore: Dictionary = main._handle_safe_start_recovery_intent(_intent(&"restore", int(report.startup_generation), int(report.report_revision)))
	_check(not bool(early_restore.accepted) and early_restore.reason == &"restore_unavailable" and filesystem.write_count == writes_before_stable, "audio action does not weaken the existing post-STABLE restoration gate")
	main._advance_safe_start_recovery_physics(5.0)
	main.get_runtime_settings().master_volume = 0.66
	_check(bool(main._persist_runtime_settings().accepted), "an intervening player audio edit persists through the real adapter")
	main._publish_safe_start_recovery_status_to_hud(true, true)
	_check(_press_recovery_button(hud, "Restore Previous Graphics"), "player audio edits withdraw audio restore while graphics remains restorable")
	_check(
		is_equal_approx(main.get_runtime_settings().master_volume, 0.66)
		and is_equal_approx(main.get_runtime_settings().music_volume, 0.0)
		and is_equal_approx(float(store.get_snapshot()[AdapterType.SETTINGS_PAYLOAD_KEY].values.master_volume), 0.66)
		and not bool(main.get_safe_start_recovery_report().audio_recovery_receipt.consumed),
		"Restore preserves the intervening audio edit and retains the unconsumed audio receipt"
	)
	report = main.get_safe_start_recovery_report()
	var writes_before_keep: int = filesystem.write_count
	var before_keep: PackedByteArray = (filesystem.files[STORE_PATH] as PackedByteArray).duplicate()
	_check(_press_recovery_button(hud, "Keep Current Settings"), "real HUD retains the existing Keep Current Settings choice after player edits")
	var dismissed_audio: Dictionary = main._handle_safe_start_recovery_intent(_intent(&"use_safe_audio", int(report.startup_generation), int(report.report_revision)))
	_check(
		not bool(dismissed_audio.accepted) and dismissed_audio.reason == &"stale_recovery_fence"
		and filesystem.write_count == writes_before_keep and filesystem.files[STORE_PATH] == before_keep
		and not (hud.get("_runtime_status_cards") as Dictionary).has(&"safe_start_recovery"),
		"Keep Safe remains presentation-only and fences later audio actions for this startup"
	)
	_real_main_failure_context.clear()
	main.free()
	await process_frame


func _intent(action: StringName, generation: int, revision: int) -> Dictionary:
	return {
		"accepted": true,
		"reason": &"requested",
		"action": action,
		"generation": generation,
		"revision": revision,
		"presentation_only": true,
		"settings_authority": false,
		"filesystem_authority": false,
	}.duplicate(true)


func _recovery_action_geometry(hud: GameHUD) -> Dictionary:
	var panel: PanelContainer = hud.get("_runtime_status_panel") as PanelContainer
	var actions: HBoxContainer = hud.get("_runtime_status_actions") as HBoxContainer
	var panel_rect: Rect2 = panel.get_global_rect()
	var viewport_rect: Rect2 = hud.get_viewport().get_visible_rect()
	var usable: bool = panel.is_visible_in_tree() and actions.get_child_count() == 3
	var buttons: Array[Dictionary] = []
	for child: Node in actions.get_children():
		var button: Button = child as Button
		if button == null:
			usable = false
			continue
		var rect: Rect2 = button.get_global_rect()
		var visible: bool = button.is_visible_in_tree()
		var focusable: bool = button.focus_mode == Control.FOCUS_ALL and not button.disabled
		var panel_encloses: bool = panel_rect.encloses(rect)
		var viewport_encloses: bool = viewport_rect.encloses(rect)
		usable = usable and visible and focusable and rect.has_area() and panel_encloses and viewport_encloses
		buttons.append({
			"label": button.text, "rect": rect, "visible": visible,
			"focusable": focusable, "panel_encloses": panel_encloses,
			"viewport_encloses": viewport_encloses,
		})
	return {"usable": usable, "panel": panel_rect, "viewport": viewport_rect, "buttons": buttons}


func _check(condition: bool, message: String, operands: Dictionary = {}) -> void:
	_assertions += 1
	if not condition:
		var actual: Dictionary = operands.duplicate(true)
		if not _real_main_failure_context.is_empty():
			var main: GameFlow = _real_main_failure_context.get("main") as GameFlow
			var store: UserDataStore = _real_main_failure_context.get("store") as UserDataStore
			if is_instance_valid(main):
				actual["phase"] = main.phase
				if main.get_runtime_settings() != null:
					actual["typed_live"] = main.get_runtime_settings().to_user_data_payload()
				actual["report"] = main.get_safe_start_recovery_report()
				actual["hud_status"] = main.get_safe_start_recovery_hud_status()
				if is_instance_valid(main.hud):
					actual["geometry"] = _recovery_action_geometry(main.hud as GameHUD)
			if store != null:
				actual["wire_store"] = store.get_snapshot()
			actual["original_typed"] = _real_main_failure_context.get("original_typed")
			actual["original_wire"] = _real_main_failure_context.get("original_wire")
			actual["foreign_wire"] = _real_main_failure_context.get("foreign_wire")
		_failures.append(message + "\nACTUAL OPERANDS: " + var_to_str(actual))


func _finish() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _failures.is_empty():
		print(
			"GAME_FLOW_SAFE_START_RECOVERY_HUD_INTEGRATION_TEST_OK (%d assertions)"
			% _assertions
		)
		quit(0)
		return
	for failure in _failures:
		push_error("FAIL: " + failure)
	quit(1)
