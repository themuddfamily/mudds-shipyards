extends SceneTree

const GameFlowType := preload("res://scripts/game/game_flow.gd")
const HudType := preload("res://scripts/ui/hud.gd")
const SafeStartType := preload("res://scripts/recovery/safe_start_production_recovery.gd")

var _assertions := 0
var _failures: PackedStringArray = []


class RecoveryProbe extends SafeStartType:
	var report: Dictionary = {}
	var restore_calls: PackedStringArray = []
	var callable_validity: Array[bool] = []
	var graphics_accept := true
	var audio_accept := true

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
		return report.duplicate(true)

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
	flow._publish_safe_start_recovery_status_to_hud()
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
	_finish()


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


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
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
