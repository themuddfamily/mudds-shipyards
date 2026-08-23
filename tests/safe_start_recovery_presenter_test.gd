extends SceneTree

const Presenter := preload("res://scripts/ui/safe_start_recovery_presenter.gd")
const HudType := preload("res://scripts/ui/hud.gd")
var _failures: PackedStringArray = []
var _intents: Array[Dictionary] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var presenter := Presenter.new()
	var snapshot := presenter.present_receipt({
		"graphics_recovery_receipt": {"consumed": false, "prior_values": {"graphics_profile": "high"}},
		"audio_recovery_receipt": {"consumed": false, "prior_values": {"music_volume": 0.6}},
		"stability_confirmed": true,
	})
	_check(snapshot.status == &"safe_mode_active" and snapshot.title == "Safe Settings Active", "recovery receipt becomes explicit safe-mode copy")
	_check(snapshot.actions.size() == 2 and snapshot.actions[0].focusable and snapshot.actions[1].focusable, "restore and keep-safe actions are controller-focusable")
	_check(presenter.request_restore().accepted and presenter.request_keep_safe().accepted, "recovery actions return external presentation intents")
	var detached := presenter.get_snapshot()
	(detached.details as Dictionary)["stability_confirmed"] = false
	_check(bool(presenter.get_snapshot().details.stability_confirmed), "presented recovery details are detached")
	var invalid := presenter.present_receipt({"graphics_recovery_receipt": {}})
	_check(invalid.status == &"invalid" and invalid.actions.size() == 1 and presenter.request_restore().accepted == false, "incomplete receipts fail closed to keep-safe only")
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
		print("SAFE_START_RECOVERY_PRESENTER_TEST_OK: 11 assertions")
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
