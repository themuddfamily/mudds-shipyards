extends SceneTree

const HudType := preload("res://scripts/ui/hud.gd")
const SafeAreaType := preload("res://scripts/ui/ultrawide_safe_area_contract.gd")

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
	var settings_page := hud.get("_settings_page") as Control
	var save := settings_page.find_child("SettingsSaveButton", true, false) as Button
	var back := settings_page.find_child("SettingsBackButton", true, false) as Button
	_check(
		panel.visible
		and title.text == "SETTINGS BACKUP RECOVERY AVAILABLE"
		and detail.text.contains("Nothing will be repaired until you confirm")
		and button.visible
		and not button.disabled
		and button.focus_mode == Control.FOCUS_ALL,
		"backup recovery is explicit, controller-focusable, and never automatic"
	)
	_check(
		save.get_node(save.focus_neighbor_bottom) == button
		and button.get_node(button.focus_neighbor_top) == save
		and button.get_node(button.focus_neighbor_bottom) == back
		and back.get_node(back.focus_neighbor_top) == button,
		"visible recovery action is linked into the real controller focus path"
	)
	await process_frame
	var stable_rect := panel.get_global_rect()
	await process_frame
	var settings_rect := settings_page.get_global_rect()
	var safe_rect := SafeAreaType.safe_rect(Vector2(5120.0, 1440.0), hud.get_effective_ui_scale())
	_check(
		hud.is_reduced_motion()
		and panel.get_global_rect() == stable_rect
		and panel.modulate == Color.WHITE,
		"reduced motion keeps the recovery notice static and fully readable"
	)
	_check(
		safe_rect.encloses(settings_rect),
		"32:9 layout keeps the recovery notice's settings page inside the readable safe band"
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
		"schema_version": 1,
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
		"schema_version": 1,
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
		"schema_version": 1,
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

	_check(not hud.present_runtime_settings_repair_report({
		"schema_version": 2,
		"attached": true,
		"last_status": available.last_status.duplicate(true),
	}), "future repair report is rejected")
	_check(
		title.text == "SETTINGS RECOVERY STATUS UNAVAILABLE"
		and not button.visible
		and not hud.get_runtime_settings_repair_presentation().confirmation_available
		and save.focus_neighbor_bottom.is_empty()
		and back.focus_neighbor_top.is_empty(),
		"future report clears the old token and controller links before showing unavailable"
	)
	_check(not hud.present_runtime_settings_repair_report({
		"schema_version": 1,
		"attached": true,
		"last_status": "malformed",
	}), "malformed repair status is rejected")
	button.pressed.emit()
	_check(
		emitted == [token]
		and title.text == "SETTINGS RECOVERY STATUS UNAVAILABLE"
		and not hud.get_runtime_settings_repair_presentation().confirmation_available,
		"malformed status cannot replay an earlier confirmation or overwrite unavailable text"
	)
	var incomplete_available := available.duplicate(true)
	incomplete_available.last_status.erase("preserves_unrelated_payload")
	_check(
		not hud.present_runtime_settings_repair_report(incomplete_available)
		and not button.visible,
		"incomplete backup contract cannot become actionable"
	)

	hud.present_runtime_settings_repair_report(available)
	hud.present_runtime_settings_repair_report({"attached": false})
	_check(
		not panel.visible and hud.get_runtime_settings_repair_presentation().report.is_empty(),
		"caller detach clears the notice and detached report"
	)
	hud.present_runtime_settings_repair_report({
		"schema_version": 1,
		"attached": true,
		"last_status": {
			"accepted": true,
			"reason": &"repair_available",
			"kind": &"promote_verified_backup",
			"generation": 8,
			"confirmation": "reset-token",
			"preserves_unrelated_payload": true,
			"newer_schema": false,
		},
	})
	hud.clear_runtime_settings_repair_report()
	_check(
		not panel.visible
		and not hud.get_runtime_settings_repair_presentation().confirmation_available,
		"caller state reset clears the action token"
	)
	hud.present_runtime_settings_repair_report({
		"schema_version": 1,
		"attached": true,
		"last_status": {
			"accepted": true,
			"reason": &"repair_available",
			"kind": &"promote_verified_backup",
			"generation": 9,
			"confirmation": "detach-token",
			"preserves_unrelated_payload": true,
			"newer_schema": false,
		},
	})
	root.remove_child(hud)
	_check(
		not panel.visible
		and hud.get_runtime_settings_repair_presentation().report.is_empty()
		and not hud.get_runtime_settings_repair_presentation().confirmation_available,
		"actual HUD exit-tree clears the detached report and confirmation"
	)
	hud.free()
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
