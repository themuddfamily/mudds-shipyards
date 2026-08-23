extends SceneTree

const HudType := preload("res://scripts/ui/hud.gd")

var _assertions := 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var hud := HudType.new()
	root.add_child(hud)
	await process_frame
	hud.set_reduced_motion(true)
	hud.layout_for_viewport(Vector2(5120.0, 1440.0))
	var token := "detached-confirmation-token"
	var available := {
		"schema_version": 1,
		"attached": true,
		"last_status": {
			"accepted": true,
			"reason": &"repair_available",
			"kind": &"promote_verified_backup",
			"generation": 7,
			"confirmation": token,
			"preserves_unrelated_payload": true,
			"newer_schema": false,
		},
	}
	_check(hud.present_runtime_settings_repair_report(available), "verified backup report is presented")
	available.last_status.confirmation = "mutated-after-ingress"
	var panel := hud.get("_settings_repair_panel") as PanelContainer
	var title := hud.get("_settings_repair_title") as Label
	var detail := hud.get("_settings_repair_detail") as Label
	var button := hud.get("_settings_repair_confirm_button") as Button
	_check(
		panel.visible
		and title.text == "SETTINGS BACKUP RECOVERY AVAILABLE"
		and detail.text.contains("Nothing will be repaired until you confirm")
		and button.visible
		and not button.disabled
		and button.focus_mode == Control.FOCUS_ALL,
		"backup recovery is explicit, controller-focusable, and never automatic"
	)
	var emitted: Array[String] = []
	hud.settings_repair_confirmation_requested.connect(
		func(confirmation: String) -> void: emitted.append(confirmation)
	)
	button.pressed.emit()
	_check(
		emitted == [token] and title.text == "SETTINGS BACKUP RECOVERY AVAILABLE",
		"confirmation emits the detached token once without fabricating success"
	)
	var presentation := hud.get_runtime_settings_repair_presentation()
	_check(
		presentation.authority == {"persistence": false, "store": false, "commit": false}
		and presentation.report.last_status.confirmation == token,
		"HUD retains a deep copy and exposes no settings repair authority"
	)

	_check(hud.present_runtime_settings_repair_report({
		"attached": true,
		"last_status": {"accepted": false, "reason": &"unsupported_newer_schema"},
	}), "newer settings report remains visibly fail-closed")
	_check(
		title.text == "NEWER SETTINGS DATA PRESERVED"
		and detail.text.contains("not changed or downgraded")
		and not button.visible,
		"newer authority cannot expose the repair action"
	)
	_check(hud.present_runtime_settings_repair_report({
		"attached": true,
		"last_status": {"accepted": false, "reason": &"load_not_repairable"},
	}), "corrupt settings report remains visibly fail-closed")
	_check(
		title.text == "SETTINGS RECOVERY BLOCKED"
		and detail.text.contains("left unchanged")
		and not button.visible,
		"corrupt authority cannot be presented as repaired"
	)
	_check(hud.present_runtime_settings_repair_report({
		"attached": true,
		"last_status": {
			"accepted": false,
			"reason": &"published_directory_sync_failed",
			"repair_authority_cleared": true,
		},
	}), "ambiguous publication remains visibly fail-closed")
	_check(
		title.text == "SETTINGS REPAIR RESULT AMBIGUOUS"
		and detail.text.contains("No success is being reported")
		and not button.visible,
		"ambiguous repair never fabricates success or retry authority"
	)

	hud.present_runtime_settings_repair_report(available)
	hud.present_runtime_settings_repair_report({"attached": false})
	_check(
		not panel.visible and hud.get_runtime_settings_repair_presentation().report.is_empty(),
		"caller detach clears the notice and detached report"
	)
	hud.present_runtime_settings_repair_report({
		"attached": true,
		"last_status": {
			"accepted": true,
			"reason": &"repair_available",
			"kind": &"promote_verified_backup",
			"generation": 8,
			"confirmation": "reset-token",
		},
	})
	hud.clear_runtime_settings_repair_report()
	_check(
		not panel.visible
		and not hud.get_runtime_settings_repair_presentation().confirmation_available,
		"caller state reset clears the action token"
	)
	hud.queue_free()
	await process_frame
	if _failures.is_empty():
		print("RUNTIME_SETTINGS_REPAIR_HUD_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error("FAIL: " + failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
