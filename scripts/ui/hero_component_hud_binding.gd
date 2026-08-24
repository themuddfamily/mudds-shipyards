class_name HeroComponentHudBinding
extends RefCounted

## Presentation-only bridge from one retained HeroShip to the real flight HUD.
## Both endpoints remain authoritative for their existing domains; this object
## only requests detached reports and forwards them for rendering.

var _hud_reference: WeakRef
var _ship_reference: WeakRef
var _presentation_requested := false
var _tree_suspended := false
var _repairing_component_id: StringName = &""
var _accepted_ledger_generation := 0
var _accepted_report_revision := -1
var _accepted_report: Dictionary = {}


func attach(hud: Node, ship: Node) -> bool:
	detach()
	if (
		not is_instance_valid(hud)
		or not is_instance_valid(ship)
		or not ship.has_method("get_component_damage_report")
		or not ship.has_signal("component_damage_changed")
	):
		return false
	_hud_reference = weakref(hud)
	_ship_reference = weakref(ship)
	ship.connect(&"component_damage_changed", _on_component_damage_changed)
	if ship.has_signal("component_repair_progressed"):
		ship.connect(&"component_repair_progressed", _on_component_repair_progressed)
	if ship.has_signal("hull_changed"):
		ship.connect(&"hull_changed", _on_hull_changed)
	ship.connect(&"tree_exiting", _on_ship_tree_exiting)
	ship.connect(&"tree_entered", _on_ship_tree_entered)
	return true


func detach() -> void:
	var ship := _get_ship()
	if is_instance_valid(ship):
		_disconnect_if_connected(ship, &"component_damage_changed", _on_component_damage_changed)
		_disconnect_if_connected(ship, &"component_repair_progressed", _on_component_repair_progressed)
		_disconnect_if_connected(ship, &"hull_changed", _on_hull_changed)
		_disconnect_if_connected(ship, &"tree_exiting", _on_ship_tree_exiting)
		_disconnect_if_connected(ship, &"tree_entered", _on_ship_tree_entered)
	_clear_hud()
	_hud_reference = null
	_ship_reference = null
	_presentation_requested = false
	_tree_suspended = false
	_repairing_component_id = &""
	_accepted_ledger_generation = 0
	_accepted_report_revision = -1
	_accepted_report = {}


func set_presenting(enabled: bool) -> void:
	_presentation_requested = enabled
	if enabled and not _tree_suspended:
		refresh()
	else:
		_clear_hud()


func suspend_for_tree_exit() -> void:
	_tree_suspended = true
	_clear_hud()


func resume_after_tree_entry() -> void:
	_tree_suspended = false
	if _presentation_requested:
		refresh()


func refresh() -> bool:
	var hud := _get_hud()
	var ship := _get_ship()
	if (
		_tree_suspended
		or not _presentation_requested
		or not is_instance_valid(hud)
		or not is_instance_valid(ship)
		or not hud.is_inside_tree()
		or not ship.is_inside_tree()
	):
		_clear_hud()
		return false
	var report := ship.call("get_component_damage_report") as Dictionary
	var order := _report_order(report)
	if order < 0:
		return false
	if order > 0:
		# An unpaired report advance is damage/reset observation, not evidence of
		# repair. A repair marker may only arrive through its matching receipt.
		_repairing_component_id = &""
		_accept_report(report)
	elif _accepted_report.is_empty():
		return false
	else:
		# Re-entry and mode changes may request the current tuple again. Repaint
		# only the cached accepted payload, never divergent equal-revision data.
		report = _accepted_report.duplicate(true)
	_present_report(hud, report)
	return true


func _present_report(hud: Node, report: Dictionary) -> void:
	if not _repairing_component_id.is_empty():
		report["repairing_component_id"] = _repairing_component_id
	hud.call("_present_bound_hero_component_report", report)
	_apply_steady_state_semantics(hud)


func is_attached() -> bool:
	return is_instance_valid(_get_hud()) and is_instance_valid(_get_ship())


func get_bound_ship_instance_id() -> int:
	var ship := _get_ship()
	return ship.get_instance_id() if is_instance_valid(ship) else 0


func _on_component_damage_changed(_component_id: StringName, _state: int, _integrity: float) -> void:
	refresh()


func _on_hull_changed(_current: float, _maximum: float) -> void:
	# Hull remains unrelated authority; its signal is only a reliable notification
	# that a localized component observation has just committed at finer-than-stage cadence.
	refresh()


func _on_component_repair_progressed(progress: Dictionary) -> void:
	var progress_generation := _strict_int(progress, "generation", -1)
	var progress_revision := _strict_int(progress, "revision", -1)
	if (
		progress_generation != _accepted_ledger_generation
		or progress_revision <= _accepted_report_revision
	):
		return
	var hud := _get_hud()
	var ship := _get_ship()
	if (
		_tree_suspended
		or not _presentation_requested
		or not is_instance_valid(hud)
		or not is_instance_valid(ship)
		or not hud.is_inside_tree()
		or not ship.is_inside_tree()
	):
		_clear_hud()
		return
	var report := ship.call("get_component_damage_report") as Dictionary
	if (
		_strict_int(report, "ledger_generation", -1) != progress_generation
		or _strict_int(report, "revision", -1) != progress_revision
		or _report_order(report) <= 0
	):
		return
	var repair_match := _match_repair_progress(progress, report)
	if not bool(repair_match.get("accepted", false)):
		return
	_repairing_component_id = StringName(repair_match.get("component_id", &""))
	_accept_report(report)
	_present_report(hud, report)


func _match_repair_progress(progress: Dictionary, report: Dictionary) -> Dictionary:
	var progress_components := progress.get("components", []) as Array
	if (
		progress_components.is_empty()
		or _strict_int(progress, "component_count", -1) != progress_components.size()
	):
		return {"accepted": false}
	var report_by_id: Dictionary = {}
	for raw_report_component in report.get("components", []) as Array:
		if not raw_report_component is Dictionary:
			return {"accepted": false}
		var report_component := raw_report_component as Dictionary
		var report_id := StringName(report_component.get("id", &""))
		if report_id.is_empty():
			return {"accepted": false}
		report_by_id[report_id] = report_component
	var worst_integrity := 2.0
	var repaired_component: StringName = &""
	for raw_progress_component in progress_components:
		if not raw_progress_component is Dictionary:
			return {"accepted": false}
		var progress_component := raw_progress_component as Dictionary
		var component_id := StringName(progress_component.get("component_id", &""))
		if component_id.is_empty() or not report_by_id.has(component_id):
			return {"accepted": false}
		var report_component := report_by_id.get(component_id, {}) as Dictionary
		var progress_integrity := float(progress_component.get("integrity", -1.0))
		var report_integrity := float(report_component.get("integrity", -2.0))
		if (
			not is_finite(progress_integrity)
			or not is_equal_approx(progress_integrity, report_integrity)
			or StringName(progress_component.get("state_id", &""))
			!= StringName(report_component.get("state_id", &"invalid"))
		):
			return {"accepted": false}
		if report_integrity < worst_integrity:
			worst_integrity = report_integrity
			repaired_component = component_id
	return {
		"accepted": true,
		"component_id": repaired_component if worst_integrity < 1.0 else &"",
	}


func _report_order(report: Dictionary) -> int:
	var generation := _strict_int(report, "ledger_generation", -1)
	var revision := _strict_int(report, "revision", -1)
	if generation <= 0 or revision < 0:
		return -1
	if generation < _accepted_ledger_generation:
		return -1
	if generation == _accepted_ledger_generation:
		if revision < _accepted_report_revision:
			return -1
		return 0 if revision == _accepted_report_revision else 1
	return 1


func _accept_report(report: Dictionary) -> void:
	_accepted_ledger_generation = _strict_int(report, "ledger_generation", 0)
	_accepted_report_revision = _strict_int(report, "revision", -1)
	_accepted_report = report.duplicate(true)


func _strict_int(snapshot: Dictionary, key: String, fallback: int) -> int:
	var value: Variant = snapshot.get(key, null)
	return int(value) if value is int else fallback


## Keeps the existing safe-area/scaling label in place while moving actionable
## state to the front of the line. ASCII marks remain legible without colour,
## animation, or a new focus target.
func _apply_steady_state_semantics(hud: Node) -> void:
	if not hud.has_method("get_hero_component_hud_snapshot"):
		return
	var snapshot := hud.call("get_hero_component_hud_snapshot") as Dictionary
	var wording := StringName(snapshot.get("wording", &"nominal"))
	var semantic_lead := ""
	match wording:
		&"repairing":
			semantic_lead = "[+] RECOVERY"
		&"failed":
			semantic_lead = "[X] FAILURE"
		&"critical", &"degraded":
			semantic_lead = "[!] DAMAGE"
		_:
			return
	var label := hud.find_child("ComponentStatus", true, false) as Label
	if not is_instance_valid(label):
		return
	label.text = "%s  //  %s  %03d%%  //  %s" % [
		semantic_lead,
		str(snapshot.get("component_name", "UNKNOWN")),
		clampi(int(snapshot.get("percentage", 0)), 0, 100),
		String(wording).to_upper(),
	]
	var presenter: RefCounted = hud.get("_component_degradation_presenter") as RefCounted
	if is_instance_valid(presenter):
		snapshot["text"] = label.text
		presenter.set("_snapshot", snapshot.duplicate(true))


func _on_ship_tree_exiting() -> void:
	_tree_suspended = true
	_clear_hud()


func _on_ship_tree_entered() -> void:
	_tree_suspended = false
	var hud := _get_hud()
	if _presentation_requested and is_instance_valid(hud):
		hud.call_deferred("_resume_bound_hero_component_report_after_reentry")


func _disconnect_if_connected(source: Object, signal_name: StringName, callback: Callable) -> void:
	if source.has_signal(signal_name) and source.is_connected(signal_name, callback):
		source.disconnect(signal_name, callback)


func _clear_hud() -> void:
	var hud := _get_hud()
	if is_instance_valid(hud):
		hud.call("_clear_bound_hero_component_report")


func _get_hud() -> Node:
	return _hud_reference.get_ref() as Node if _hud_reference != null else null


func _get_ship() -> Node:
	return _ship_reference.get_ref() as Node if _ship_reference != null else null
