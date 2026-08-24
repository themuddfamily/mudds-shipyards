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
	var ledger_generation := int(report.get("ledger_generation", 0))
	if ledger_generation < _accepted_ledger_generation:
		return false
	if ledger_generation > _accepted_ledger_generation:
		# A repair marker belongs to one component-ledger lifecycle only. Reuse
		# advances that authority generation before the new nominal report arrives.
		_repairing_component_id = &""
	_accepted_ledger_generation = ledger_generation
	if not _repairing_component_id.is_empty():
		report["repairing_component_id"] = _repairing_component_id
	hud.call("_present_bound_hero_component_report", report)
	_apply_steady_state_semantics(hud)
	return true


func is_attached() -> bool:
	return is_instance_valid(_get_hud()) and is_instance_valid(_get_ship())


func get_bound_ship_instance_id() -> int:
	var ship := _get_ship()
	return ship.get_instance_id() if is_instance_valid(ship) else 0


func _on_component_damage_changed(_component_id: StringName, _state: int, _integrity: float) -> void:
	_repairing_component_id = &""
	refresh()


func _on_hull_changed(_current: float, _maximum: float) -> void:
	# Hull remains unrelated authority; its signal is only a reliable notification
	# that a localized component observation has just committed at finer-than-stage cadence.
	_repairing_component_id = &""
	refresh()


func _on_component_repair_progressed(progress: Dictionary) -> void:
	if int(progress.get("generation", 0)) < _accepted_ledger_generation:
		return
	var worst_integrity := 2.0
	var repaired_component: StringName = &""
	for raw_component in progress.get("components", []) as Array:
		if not raw_component is Dictionary:
			continue
		var component := raw_component as Dictionary
		var integrity := clampf(float(component.get("integrity", 0.0)), 0.0, 1.0)
		if integrity < worst_integrity:
			worst_integrity = integrity
			repaired_component = StringName(component.get("component_id", &""))
	_repairing_component_id = repaired_component if worst_integrity < 1.0 else &""
	refresh()


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
