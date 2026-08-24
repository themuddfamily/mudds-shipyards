extends SceneTree

const Presenter := preload("res://scripts/ui/safe_start_recovery_presenter.gd")
const HudType := preload("res://scripts/ui/hud.gd")
var _failures: PackedStringArray = []
var _intents: Array[Dictionary] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var presenter := Presenter.new()
	var active_report := _report(4, 8, "starting", false, false)
	var snapshot := presenter.present_receipt(active_report)
	_check(
		snapshot.status == &"safe_mode_active"
		and snapshot.readiness == "[STABILITY CHECK]"
		and snapshot.next_action == "Keep current settings until startup stability is confirmed."
		and snapshot.message.contains("SAFE GRAPHICS + SAFE AUDIO ACTIVE")
		and snapshot.message.contains("NEXT ACTION //")
		and bool(snapshot.color_independent),
		"active graphics/audio fallbacks expose a text-labelled stability next action"
	)
	_check(
		snapshot.actions.size() == 1
		and snapshot.actions[0].id == &"keep_safe"
		and snapshot.actions[0].focusable,
		"restore stays unavailable until the authoritative stability record confirms readiness"
	)
	_check(
		not bool(presenter.request_restore(4, 8).accepted)
		and bool(presenter.request_keep_safe(4, 8).accepted)
		and not bool(presenter.request_keep_safe(4, 8).settings_authority)
		and not bool(presenter.request_keep_safe(4, 8).filesystem_authority),
		"pre-stability recovery actions return presentation intents without settings authority"
	)
	var detached := presenter.get_snapshot()
	(detached.details as Dictionary)["stability_confirmed"] = true
	(detached.actions as Array).clear()
	_check(
		not bool(presenter.get_snapshot().details.stability_confirmed)
		and presenter.get_snapshot().actions.size() == 1,
		"presented recovery details and action rows are detached"
	)

	var stable_report := _report(4, 9, "stable", false, false)
	var ready := presenter.present_receipt(stable_report)
	_check(
		ready.status == &"restore_ready"
		and ready.readiness == "[RESTORE READY]"
		and ready.next_action.contains("graphics and audio")
		and ready.actions.size() == 2
		and ready.actions[0].label == "Restore Previous Graphics And Audio",
		"stable authoritative receipts name the exact graphics/audio restore opportunity"
	)
	_check(
		bool(presenter.request_restore(4, 9).accepted)
		and presenter.request_restore(4, 8).reason == &"stale_revision"
		and presenter.request_keep_safe(3, 9).reason == &"stale_generation",
		"recovery intents can be fenced to the exact visible generation and revision"
	)
	var stale := presenter.present_receipt(active_report)
	_check(
		not bool(stale.accepted)
		and stale.reason == &"stale_revision"
		and presenter.get_snapshot().status == &"restore_ready",
		"an older recovery revision cannot replace the current next action"
	)
	var telemetry_replay := stable_report.duplicate(true)
	telemetry_replay["physics_elapsed_seconds"] = 4.5
	_check(
		presenter.present_receipt(telemetry_replay).status == &"restore_ready",
		"same-cursor non-presentation telemetry is an idempotent replay"
	)
	var conflict_report := stable_report.duplicate(true)
	(conflict_report.audio_recovery_receipt as Dictionary)["consumed"] = true
	_check(
		presenter.present_receipt(conflict_report).reason == &"revision_conflict"
		and presenter.get_snapshot().details.audio_restore_available,
		"same-cursor divergent recovery data is rejected without changing the view"
	)
	var wrong_generation_type := stable_report.duplicate(true)
	(wrong_generation_type.policy_snapshot as Dictionary)["startup_generation"] = "4"
	_check(
		presenter.present_receipt(wrong_generation_type).reason == &"invalid_cursor",
		"generation and revision fencing retains exact integer types"
	)

	var changed_report := stable_report.duplicate(true)
	changed_report.report_revision = 10
	(changed_report.restore_readiness_snapshot.audio as Dictionary)["fallback_active"] = false
	(changed_report.restore_readiness_snapshot.audio as Dictionary)["restore_ready"] = false
	(changed_report.restore_readiness_snapshot.audio as Dictionary)["reason"] = &"live_settings_changed"
	var changed := presenter.present_receipt(changed_report)
	_check(
		changed.status == &"restore_ready"
		and changed.actions[0].label == "Restore Previous Graphics"
		and not bool(changed.details.audio_restore_ready)
		and changed.fallback_summary.contains("AUDIO FALLBACK NOT ACTIVE"),
		"live-setting evidence limits restore readiness to domains still using the fallback"
	)

	var complete_report := _report(4, 11, "stable", true, true)
	(complete_report.policy_snapshot as Dictionary)["record_generation"] = 9
	var complete := presenter.present_receipt(complete_report)
	_check(
		complete.status == &"recovery_complete"
		and complete.readiness == "[RECOVERY COMPLETE]"
		and complete.actions.size() == 1
		and not bool(presenter.request_restore(4, 10).accepted),
		"consumed graphics/audio receipts clearly report completion without replaying restore"
	)
	var blocked_report := _report(5, 1, "starting", true, true)
	blocked_report.begin_status = {"accepted": false, "reason": &"settings_authority_blocked"}
	var blocked := presenter.present_receipt(blocked_report)
	_check(
		blocked.status == &"recovery_blocked"
		and blocked.readiness == "[ACTION REQUIRED]"
		and blocked.next_action.contains("Review Settings Recovery")
		and blocked.actions.is_empty(),
		"corrupt-settings authority is visibly preserved and directs the player to recovery review"
	)
	var unavailable_presenter := Presenter.new()
	var unavailable := unavailable_presenter.present_receipt(_store_unavailable_report())
	_check(
		unavailable.status == &"recovery_blocked"
		and unavailable.generation == 0
		and unavailable.revision == 1
		and unavailable.details.blocked_reason == &"store_unavailable",
		"missing store authority receives a visible fail-closed recovery status"
	)
	var detached_state := presenter.detach()
	_check(
		detached_state.status == &"detached"
		and presenter.get_snapshot().actions.is_empty()
		and not bool(presenter.request_keep_safe().accepted),
		"detach clears retained recovery rows and intents"
	)
	var reused := presenter.present_receipt(_report(1, 1, "starting", false, true))
	_check(
		reused.generation == 1
		and reused.revision == 1
		and reused.fallback_summary == "SAFE GRAPHICS ACTIVE // AUDIO FALLBACK NOT ACTIVE",
		"detached presenter reuse starts a fresh cursor and names a graphics-only fallback"
	)
	var invalid_report := _report(2, 1, "starting", false, false)
	invalid_report.erase("audio_recovery_receipt")
	var invalid := presenter.present_receipt(invalid_report)
	_check(
		invalid.status == &"invalid"
		and invalid.actions.size() == 1
		and not bool(presenter.request_restore().accepted),
		"incomplete authoritative receipts fail closed to keep-safe only"
	)

	var hud := HudType.new()
	root.add_child(hud)
	await process_frame
	hud.presentation_intent_requested.connect(_on_intent)
	var choice := hud.apply_recovery_choice_snapshot({
		"available": true, "requires_caller_choice": true, "severity": &"safe_graphics_recommended",
	})
	_check(choice.status == &"choice_required" and bool(hud._recovery_prompt_panel.visible), "diagnostic recovery snapshot opens the blocking choice prompt")
	_check(hud._recovery_prompt_actions.get_child_count() == 3, "normal safe-graphics and discard choices are focusable")
	var first_choice := hud._recovery_prompt_actions.get_child(0) as Button
	var last_choice := hud._recovery_prompt_actions.get_child(2) as Button
	_check(first_choice.focus_mode == Control.FOCUS_ALL and first_choice.focus_neighbor_right == first_choice.get_path_to(hud._recovery_prompt_actions.get_child(1)), "recovery choices have deterministic controller focus order")
	_check(last_choice.focus_neighbor_right == last_choice.get_path_to(hud._recovery_prompt_dismiss_button) and first_choice.tooltip_text.contains("Recovery choice"), "recovery choices link to dismiss and expose readable descriptions")
	hud._request_recovery_choice(&"safe_graphics_windowed")
	_check(_intents.size() == 1 and _intents[0].choice == &"safe_graphics_windowed", "HUD emits only the caller-owned recovery choice intent")
	hud.apply_recovery_choice_snapshot({"available": true, "requires_caller_choice": true, "severity": &"review_prior_session"})
	_check(bool(hud._recovery_prompt_panel.visible), "failed or retried recovery publication retains the prompt")
	hud.apply_recovery_choice_snapshot({"available": false, "requires_caller_choice": false})
	_check(not bool(hud._recovery_prompt_panel.visible), "accepted recovery publication clears the prompt")
	hud.free()
	if _failures.is_empty():
		print("SAFE_START_RECOVERY_PRESENTER_TEST_OK: 24 assertions")
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)
	quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _on_intent(kind: StringName, payload: Dictionary) -> void:
	if kind == &"recovery":
		_intents.append(payload.duplicate(true))


func _report(
		generation: int,
		revision: int,
		state: String,
		graphics_consumed: bool,
		audio_consumed: bool
		) -> Dictionary:
	return {
		"schema_version": 1,
		"report_revision": revision,
		"startup_generation": generation,
		"begin_status": {"accepted": true, "reason": &"startup_begun"},
		"restore_status": {"accepted": true, "reason": &"restored"},
		"stable_status": (
			{"accepted": true, "reason": &"startup_stable"}
			if state == "stable" else {"accepted": false, "reason": &"not_attempted"}
		),
		"policy_snapshot": {
			"schema_version": 1,
			"startup_generation": generation,
			"record_generation": revision,
			"state": state,
		},
		"graphics_recovery_receipt": {
			"consumed": graphics_consumed,
			"source_store_generation": revision,
			"startup_generation": generation,
			"prior_values": {
				"graphics_profile": "high",
				"window_mode": "fullscreen",
			},
		},
		"audio_recovery_receipt": {
			"consumed": audio_consumed,
			"source_store_generation": revision,
			"prior_values": {"master_volume": 0.8, "music_volume": 0.6},
		},
		"restore_readiness_snapshot": {
			"schema_version": 1,
			"stability_confirmed": state == "stable",
			"graphics": _domain_readiness(not graphics_consumed, state == "stable"),
			"audio": _domain_readiness(not audio_consumed, state == "stable"),
		},
	}


func _domain_readiness(fallback_active: bool, stable: bool) -> Dictionary:
	var receipt_available := fallback_active
	return {
		"receipt_present": true,
		"receipt_available": receipt_available,
		"fallback_active": fallback_active,
		"restore_ready": receipt_available and stable,
		"reason": (
			&"restore_ready" if receipt_available and stable
			else &"stability_pending" if receipt_available
			else &"receipt_consumed"
		),
	}


func _store_unavailable_report() -> Dictionary:
	return {
		"schema_version": 1,
		"report_revision": 1,
		"startup_generation": 0,
		"begin_status": {"accepted": false, "reason": &"not_attempted"},
		"restore_status": {"accepted": false, "reason": &"store_unavailable"},
		"stable_status": {},
		"policy_snapshot": {},
		"graphics_recovery_receipt": {},
		"audio_recovery_receipt": {},
		"restore_readiness_snapshot": {
			"schema_version": 1,
			"stability_confirmed": false,
			"graphics": _empty_domain_readiness(),
			"audio": _empty_domain_readiness(),
		},
	}


func _empty_domain_readiness() -> Dictionary:
	return {
		"receipt_present": false,
		"receipt_available": false,
		"fallback_active": false,
		"restore_ready": false,
		"reason": &"no_receipt",
	}
