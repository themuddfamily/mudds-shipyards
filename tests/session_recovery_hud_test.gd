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
		"state": &"running",
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
		actions.get_child_count() == 3
		and (actions.get_child(0) as Button).text == "Safe Recovery"
		and (actions.get_child(1) as Button).text == "Continue"
		and (actions.get_child(2) as Button).text == "Discard",
		"the three explicit player choices use the requested readable labels"
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
	var stale := recovery.duplicate(true)
	stale["session_id"] = 40
	stale["startup_generation"] = 6
	var conflicting := recovery.duplicate(true)
	conflicting["session_id"] = 42
	conflicting["startup_generation"] = 7
	_check(
		hud.present_session_recovery_notice(stale, recommendation).reason == &"stale_recovery_generation"
		and hud.present_session_recovery_notice(conflicting, recommendation).reason == &"recovery_token_mismatch"
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
		_requests == [
			{"action": &"safe", "token": 41, "generation": 7},
			{"action": &"continue", "token": 41, "generation": 7},
			{"action": &"discard", "token": 41, "generation": 7},
		]
		and panel.visible,
		"each choice emits its dedicated exact fenced request and the HUD does not assume its outcome"
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
	var fresh_recovery := stale.duplicate(true)
	fresh_recovery["session_id"] = 43
	fresh_recovery["startup_generation"] = 8
	_check(
		bool(hud.present_session_recovery_notice(fresh_recovery, recommendation).accepted),
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
