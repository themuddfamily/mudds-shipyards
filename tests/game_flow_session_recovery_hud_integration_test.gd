extends SceneTree

const GameFlowType := preload("res://scripts/game/game_flow.gd")
const HudType := preload("res://scripts/ui/hud.gd")
const BridgeType := preload("res://scripts/diagnostics/session_diagnostic_lifecycle_bridge.gd")
const SafeStartType := preload("res://scripts/recovery/safe_start_production_recovery.gd")

var _assertions := 0
var _failures: PackedStringArray = []


class SafeRecoveryProbe extends SafeStartType:
	var applied_generations: Array[int] = []
	var accept_application := true

	func _init() -> void:
		super(null, null, false)

	func get_recovery_recommendation_patch() -> Dictionary:
		return {
			"values_patch": {
				"graphics_profile": "low",
				"window_mode": "windowed",
			},
			"applies_settings": false,
			"persists_settings": false,
		}.duplicate(true)

	func apply_current_session_safe_graphics(expected_startup_generation: int) -> Dictionary:
		applied_generations.append(expected_startup_generation)
		if not accept_application:
			return {"accepted": false, "reason": &"safe_graphics_apply_failed"}
		return {
			"accepted": true,
			"reason": &"safe_graphics_applied_current_session",
			"persisted": false,
			"startup_generation": expected_startup_generation,
		}.duplicate(true)


class RecoveryBridgeProbe extends BridgeType:
	var recovery_snapshot: Dictionary = {}
	var safe_choices: Array[StringName] = []
	var acknowledge_count := 0
	var discard_count := 0

	func _init() -> void:
		super(null, null, null)

	func install(token: int, generation: int, unclean_count: int = 1) -> void:
		recovery_snapshot = {
			"schema_version": 1,
			"state": "running",
			"session_id": token,
			"startup_generation": generation,
			"unclean_start_count": unclean_count,
			"last_physics_tick": 240,
			"last_elapsed_physics_seconds": 4.0,
		}.duplicate(true)

	func get_recovery_available_snapshot() -> Dictionary:
		return recovery_snapshot.duplicate(true)

	func get_recovery_recommendation(safe_start_patch: Dictionary = {}) -> Dictionary:
		if recovery_snapshot.is_empty():
			return {"available": false, "requires_caller_choice": false}
		return {
			"available": true,
			"requires_caller_choice": true,
			"severity": (
				&"safe_graphics_recommended"
				if int(recovery_snapshot.get("unclean_start_count", 0)) >= 3
				else &"review_prior_session"
			),
			"choices": [&"normal_start", &"safe_graphics_windowed", &"discard"],
			"safe_start_patch": safe_start_patch.duplicate(true),
			"applies_settings": false,
			"persists_settings": false,
		}.duplicate(true)

	func choose_recovery(
		choice: StringName,
		safe_graphics_apply: Callable = Callable()
	) -> Dictionary:
		safe_choices.append(choice)
		if choice != &"safe_graphics_windowed" or not safe_graphics_apply.is_valid():
			return {"accepted": false, "reason": &"invalid_recovery_choice"}
		var generation := int(recovery_snapshot.get("startup_generation", 0))
		var applied := safe_graphics_apply.call(generation) as Dictionary
		if bool(applied.get("accepted", false)):
			recovery_snapshot.clear()
			return {"accepted": true, "reason": &"recovery_acknowledged"}
		return applied.duplicate(true)

	func acknowledge_recovery() -> Dictionary:
		acknowledge_count += 1
		if recovery_snapshot.is_empty():
			return {"accepted": false, "reason": &"no_recovery_available"}
		recovery_snapshot.clear()
		return {"accepted": true, "reason": &"recovery_acknowledged"}

	func discard_recovery() -> Dictionary:
		discard_count += 1
		if recovery_snapshot.is_empty():
			return {"accepted": false, "reason": &"no_recovery_available"}
		recovery_snapshot.clear()
		return {"accepted": true, "reason": &"recovery_discarded"}

	func get_snapshot() -> Dictionary:
		return {"recovery_available": not recovery_snapshot.is_empty()}.duplicate(true)


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var hud := HudType.new()
	root.add_child(hud)
	await process_frame
	var flow := GameFlowType.new()
	var bridge := RecoveryBridgeProbe.new()
	var safe_recovery := SafeRecoveryProbe.new()
	flow.hud = hud
	flow.set("_session_diagnostics_bridge", bridge)
	flow.set("_safe_start_production_recovery", safe_recovery)
	bridge.install(51, 4, 3)
	flow._connect_session_recovery_hud_signals()
	flow._publish_recovery_choice_to_hud()
	var notice := hud.get_session_recovery_notice_snapshot()
	_check(
		bool(notice.active)
		and int(notice.recovery_token) == 51
		and int(notice.recovery_generation) == 4
		and bridge.safe_choices.is_empty()
		and bridge.acknowledge_count == 0
		and bridge.discard_count == 0,
		"production publishes the authentic bridge receipt without choosing for the player"
	)
	var stale := flow._handle_hud_session_recovery_choice(
		&"normal_start", 50, 4
	)
	_check(
		not bool(stale.accepted)
		and stale.reason == &"stale_recovery_fence"
		and not bridge.recovery_snapshot.is_empty()
		and bridge.acknowledge_count == 0,
		"GameFlow independently rejects a forged recovery token without consuming the receipt"
	)
	var actions := hud.get("_recovery_prompt_actions") as HBoxContainer
	(actions.get_child(0) as Button).pressed.emit()
	await process_frame
	_check(
		bridge.safe_choices == [&"safe_graphics_windowed"]
		and safe_recovery.applied_generations == [4]
		and bridge.acknowledge_count == 0
		and bridge.discard_count == 0
		and bridge.recovery_snapshot.is_empty(),
		"Safe Recovery reaches only the existing generation-fenced safe graphics callback"
	)
	_check(
		not bool(hud.get_session_recovery_notice_snapshot().active)
		and flow.get_session_diagnostics_snapshot().recovery_hud.choice == &"safe_graphics_windowed"
		and not bool(flow.get_session_diagnostics_snapshot().recovery_hud.automatic_choice),
		"an accepted safe result clears the notice and remains a detached explicit HUD result"
	)
	bridge.install(52, 5)
	flow._publish_recovery_choice_to_hud()
	actions = hud.get("_recovery_prompt_actions") as HBoxContainer
	(actions.get_child(1) as Button).pressed.emit()
	await process_frame
	_check(
		bridge.acknowledge_count == 1
		and bridge.safe_choices.size() == 1
		and bridge.discard_count == 0
		and bridge.recovery_snapshot.is_empty(),
		"Continue acknowledges the bridge receipt without applying safe settings or discarding"
	)
	bridge.install(53, 6)
	flow._publish_recovery_choice_to_hud()
	actions = hud.get("_recovery_prompt_actions") as HBoxContainer
	(actions.get_child(2) as Button).pressed.emit()
	await process_frame
	_check(
		bridge.discard_count == 1
		and bridge.acknowledge_count == 1
		and bridge.safe_choices.size() == 1
		and bridge.recovery_snapshot.is_empty(),
		"Discard clears through the bridge discard seam and no other recovery authority"
	)
	bridge.install(54, 7, 2)
	flow._publish_recovery_choice_to_hud()
	root.remove_child(hud)
	_check(
		not bool(hud.get_session_recovery_notice_snapshot().active)
		and not bridge.recovery_snapshot.is_empty(),
		"HUD detach clears presentation without consuming the caller-owned bridge receipt"
	)
	root.add_child(hud)
	await process_frame
	flow._restore_session_recovery_hud_after_reentry()
	notice = hud.get_session_recovery_notice_snapshot()
	_check(
		bool(notice.active)
		and int(notice.recovery_token) == 54
		and int(notice.recovery_generation) == 7
		and bridge.acknowledge_count == 1
		and bridge.discard_count == 1
		and safe_recovery.applied_generations == [4],
		"re-entry reconnects once and truthfully re-presents the still-current bridge receipt"
	)
	safe_recovery.accept_application = false
	actions = hud.get("_recovery_prompt_actions") as HBoxContainer
	(actions.get_child(0) as Button).pressed.emit()
	var failed_status := flow.get_session_diagnostics_snapshot().recovery_hud as Dictionary
	_check(
		not bool(failed_status.accepted)
		and failed_status.reason == &"safe_graphics_apply_failed"
		and not bridge.recovery_snapshot.is_empty()
		and bool(hud.get_session_recovery_notice_snapshot().active)
		and bool(hud.get_session_recovery_notice_snapshot().choice_latched)
		and safe_recovery.applied_generations == [4, 7],
		"a failed safe callback retains the truthful receipt and latched result without inventing another choice"
	)
	flow.free()
	hud.queue_free()
	await process_frame
	_finish()


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("GAME_FLOW_SESSION_RECOVERY_HUD_INTEGRATION_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error("FAIL: " + failure)
	quit(1)
