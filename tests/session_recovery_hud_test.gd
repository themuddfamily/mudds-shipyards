extends SceneTree

const HudType := preload("res://scripts/ui/hud.gd")

var _assertions := 0
var _failures: PackedStringArray = []
var _requests: Array[Dictionary] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var hud := HudType.new()
	root.add_child(hud)
	await process_frame
	hud.set_reduced_motion(true)
	hud.session_recovery_safe_requested.connect(_capture_request.bind(&"safe"))
	hud.session_recovery_continue_requested.connect(_capture_request.bind(&"continue"))
	hud.session_recovery_discard_requested.connect(_capture_request.bind(&"discard"))
	var recovery := {
		"schema_version": 1,
		"state": "running",
		"session_id": 41,
		"startup_generation": 7,
		"unclean_start_count": 2,
		"last_physics_tick": 125,
		"last_elapsed_physics_seconds": 12.5,
	}
	var recommendation := {
		"available": true,
		"requires_caller_choice": true,
		"severity": &"review_prior_session",
		"choices": [&"normal_start", &"safe_graphics_windowed", &"discard"],
		"safe_start_patch": {"values_patch": {"graphics_profile": "low"}},
		"applies_settings": false,
		"persists_settings": false,
	}
	var authentic_recovery := recovery.duplicate(true)
	var authentic_recommendation := recommendation.duplicate(true)
	var presented := hud.present_session_recovery_notice(recovery, recommendation)
	_check(
		bool(presented.accepted)
		and int(presented.recovery_token) == 41
		and int(presented.recovery_generation) == 7
		and not bool(presented.automatic_choice)
		and _requests.is_empty(),
		"presenting detached bridge output makes no automatic recovery choice"
	)
	var panel := hud.get("_recovery_prompt_panel") as PanelContainer
	var detail := hud.get("_recovery_prompt_detail") as Label
	var actions := hud.get("_recovery_prompt_actions") as HBoxContainer
	_check(
		panel.visible
		and detail.text.contains("Session 41 did not close cleanly")
		and detail.text.contains("125 physics ticks (12.50 seconds)")
		and detail.text.contains("Unfinished starts: 2"),
		"the notice truthfully summarizes the interrupted session without claiming a crash"
	)
	_check(
		actions.get_child_count() == 4
		and (actions.get_child(0) as Button).text == "Safe Recovery"
		and (actions.get_child(1) as Button).text == "Continue"
		and (actions.get_child(2) as Button).text == "Discard"
		and (actions.get_child(3) as Button).text == "Save Support Summary",
		"the recovery choices and receipt-fenced support action use readable labels"
	)
	var safe := actions.get_child(0) as Button
	var continue_button := actions.get_child(1) as Button
	var discard := actions.get_child(2) as Button
	_check(
		safe.focus_mode == Control.FOCUS_ALL
		and safe.focus_neighbor_right == safe.get_path_to(continue_button)
		and continue_button.focus_neighbor_left == continue_button.get_path_to(safe)
		and continue_button.focus_neighbor_right == continue_button.get_path_to(discard),
		"controller focus traverses the recovery actions in visual order"
	)
	(recovery as Dictionary)["session_id"] = 999
	((recommendation.safe_start_patch as Dictionary).values_patch as Dictionary)["graphics_profile"] = "ultra"
	var detached := hud.get_session_recovery_notice_snapshot()
	_check(
		int(detached.recovery_snapshot.session_id) == 41
		and detached.recommendation.safe_start_patch.values_patch.graphics_profile == "low"
		and bool(detached.reduced_motion),
		"recovery state is deeply detached and reports the static reduced-motion presentation"
	)
	(detached.recovery_snapshot as Dictionary)["session_id"] = 888
	_check(
		int(hud.get_session_recovery_notice_snapshot().recovery_snapshot.session_id) == 41,
		"the public notice snapshot is also a deep copy"
	)
	var replayed_recovery := authentic_recovery.duplicate(true)
	replayed_recovery["last_physics_tick"] = 999
	var replayed_recommendation := authentic_recommendation.duplicate(true)
	((replayed_recommendation.safe_start_patch as Dictionary).values_patch as Dictionary)[
		"graphics_profile"
	] = "medium"
	_check(
		hud.present_session_recovery_notice(
			replayed_recovery, replayed_recommendation
		).reason == &"replayed_recovery_notice"
		and int(hud.get_session_recovery_notice_snapshot().recovery_snapshot.last_physics_tick) == 125
		and hud.get_session_recovery_notice_snapshot().recommendation.safe_start_patch.values_patch.graphics_profile == "low",
		"same-token same-generation replay is rejected without overwriting retained state"
	)
	var malformed_cases: Array[Dictionary] = []
	var bad_schema := authentic_recovery.duplicate(true)
	bad_schema["schema_version"] = 2
	malformed_cases.append({"snapshot": bad_schema, "recommendation": authentic_recommendation})
	var bad_type := authentic_recovery.duplicate(true)
	bad_type["session_id"] = "41"
	malformed_cases.append({"snapshot": bad_type, "recommendation": authentic_recommendation})
	var bad_tick := authentic_recovery.duplicate(true)
	bad_tick["last_physics_tick"] = -1
	malformed_cases.append({"snapshot": bad_tick, "recommendation": authentic_recommendation})
	var bad_elapsed := authentic_recovery.duplicate(true)
	bad_elapsed["last_elapsed_physics_seconds"] = NAN
	malformed_cases.append({"snapshot": bad_elapsed, "recommendation": authentic_recommendation})
	var bad_count := authentic_recovery.duplicate(true)
	bad_count["unclean_start_count"] = 4
	malformed_cases.append({"snapshot": bad_count, "recommendation": authentic_recommendation})
	var extra_field := authentic_recovery.duplicate(true)
	extra_field["forged"] = true
	malformed_cases.append({"snapshot": extra_field, "recommendation": authentic_recommendation})
	var bad_severity := authentic_recommendation.duplicate(true)
	bad_severity["severity"] = &"automatic_repair"
	malformed_cases.append({"snapshot": authentic_recovery, "recommendation": bad_severity})
	var early_safe_severity := authentic_recommendation.duplicate(true)
	early_safe_severity["severity"] = &"safe_graphics_recommended"
	malformed_cases.append({"snapshot": authentic_recovery, "recommendation": early_safe_severity})
	var threshold_recovery := authentic_recovery.duplicate(true)
	threshold_recovery["unclean_start_count"] = 3
	malformed_cases.append({"snapshot": threshold_recovery, "recommendation": authentic_recommendation})
	var bad_authority := authentic_recommendation.duplicate(true)
	bad_authority["applies_settings"] = true
	malformed_cases.append({"snapshot": authentic_recovery, "recommendation": bad_authority})
	var all_malformed_rejected := true
	for malformed in malformed_cases:
		all_malformed_rejected = all_malformed_rejected and not bool(
			hud.present_session_recovery_notice(
				malformed.snapshot as Dictionary,
				malformed.recommendation as Dictionary
			).get("accepted", true)
		)
	_check(
		all_malformed_rejected
		and detail.text.contains("125 physics ticks (12.50 seconds)")
		and int(hud.get_session_recovery_notice_snapshot().recovery_token) == 41,
		"malformed schema, types, progress, count, severity thresholds, and authority flags never render clamped data"
	)
	var stale := authentic_recovery.duplicate(true)
	stale["session_id"] = 40
	stale["startup_generation"] = 6
	var conflicting := authentic_recovery.duplicate(true)
	conflicting["session_id"] = 42
	conflicting["startup_generation"] = 7
	_check(
		hud.present_session_recovery_notice(stale, authentic_recommendation).reason == &"stale_recovery_generation"
		and hud.present_session_recovery_notice(conflicting, authentic_recommendation).reason == &"recovery_token_mismatch"
		and int(hud.get_session_recovery_notice_snapshot().recovery_token) == 41,
		"stale generations and same-generation token substitution fail without replacing the notice"
	)
	_check(
		not hud._request_session_recovery_action(&"continue", 41, 6)
		and not hud._request_session_recovery_action(&"continue", 42, 7)
		and _requests.is_empty(),
		"action dispatch fences both the exact token and generation"
	)
	safe.pressed.emit()
	continue_button.pressed.emit()
	discard.pressed.emit()
	_check(
		_requests == [{"action": &"safe", "token": 41, "generation": 7}]
		and bool(hud.get_session_recovery_notice_snapshot().choice_latched)
		and safe.disabled and continue_button.disabled and discard.disabled
		and panel.visible,
		"one explicit choice latches the notice and repeated or cross-choice presses cannot emit"
	)
	var report := hud.get_session_recovery_notice_snapshot()
	_check(
		report.authority == {
			"filesystem": false,
			"diagnostic_store": false,
			"settings": false,
			"gameplay": false,
		},
		"the recovery surface declares no filesystem, store, settings, or gameplay authority"
	)
	var viewport_size := Vector2(5120.0, 1440.0)
	var safe_rect := HudType.compute_session_recovery_panel_rect(
		viewport_size, Rect2(Vector2(160.0, 36.0), Vector2(200.0, 40.0)), 1.0
	)
	_check(
		safe_rect.position.x >= 160.0
		and safe_rect.end.x <= viewport_size.x - 200.0
		and safe_rect.position.y >= 36.0
		and safe_rect.end.y <= viewport_size.y - 40.0
		and safe_rect.size.x <= 680.0,
		"the recovery card stays bounded in the ultrawide safe centre band"
	)
	hud.reset_session_recovery_notice()
	_check(
		not bool(hud.get_session_recovery_notice_snapshot().active)
		and not panel.visible
		and actions.get_child_count() == 0,
		"explicit reset clears presentation, focus actions, token, generation, and detached state"
	)
	var continue_recovery := authentic_recovery.duplicate(true)
	continue_recovery["session_id"] = 42
	continue_recovery["startup_generation"] = 8
	_check(
		bool(hud.present_session_recovery_notice(continue_recovery, authentic_recommendation).accepted)
		and hud._request_session_recovery_action(&"continue", 42, 8)
		and _requests.back() == {"action": &"continue", "token": 42, "generation": 8},
		"a fresh notice can emit the dedicated Continue request"
	)
	hud.reset_session_recovery_notice()
	var discard_recovery := authentic_recovery.duplicate(true)
	discard_recovery["session_id"] = 43
	discard_recovery["startup_generation"] = 9
	_check(
		bool(hud.present_session_recovery_notice(discard_recovery, authentic_recommendation).accepted)
		and hud._request_session_recovery_action(&"discard", 43, 9)
		and _requests.back() == {"action": &"discard", "token": 43, "generation": 9},
		"a fresh notice can emit the dedicated Discard request"
	)
	hud.reset_session_recovery_notice()
	var fresh_recovery := authentic_recovery.duplicate(true)
	fresh_recovery["session_id"] = 43
	fresh_recovery["startup_generation"] = 10
	_check(
		bool(hud.present_session_recovery_notice(fresh_recovery, authentic_recommendation).accepted),
		"a reset accepts a fresh caller-owned recovery generation"
	)
	root.remove_child(hud)
	_check(
		not bool(hud.get_session_recovery_notice_snapshot().active)
		and not panel.visible
		and actions.get_child_count() == 0,
		"tree exit performs the same complete recovery cleanup"
	)
	hud.free()
	_finish()


func _capture_request(token: int, generation: int, action: StringName) -> void:
	_requests.append({"action": action, "token": token, "generation": generation})


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("SESSION_RECOVERY_HUD_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error("FAIL: " + failure)
	quit(1)
