extends SceneTree

const Berths := preload("res://scripts/world/fleet_expansion_berths.gd")

var _assertions := 0
var _failures: Array[String] = []


func _initialize() -> void:
	var berths := Berths.new()
	root.add_child(berths)
	await process_frame
	var audit := berths.get_audit_report()
	_check(bool(audit.get("valid", false)), "two expansion pads build within their geometry budget")
	_check(audit.get("evidence_status", &"") == &"NEW" and not bool(audit.get("historically_supported", true)), "the expansion makes no historical berth claim")
	_check(berths.get_pad_ids() == [&"dock_04_cargo", &"dock_05_bomber", &"dock_06_interceptor"], "Dock 04 cargo, Dock 05 bomber, and Dock 06 interceptor are stable authored IDs")
	for pad_id in berths.get_pad_ids():
		var contract := berths.get_landing_contract(pad_id)
		_check(bool(contract.get("accepted", false)) and (contract.get("landing_anchor", Vector3.INF) as Vector3).is_finite(), "landing contract is finite for %s" % pad_id)
		_check(not bool(contract.get("ship_authority", true)) and not bool(contract.get("berth_lease_authority", true)), "contract remains caller-owned for %s" % pad_id)
	var unknown := berths.get_landing_contract(&"dock_99")
	_check(not bool(unknown.get("accepted", true)), "unknown pad IDs fail closed")
	var craft := Node3D.new()
	craft.set_meta(&"evidence_status", &"NEW")
	root.add_child(craft)
	await process_frame
	var attached := berths.attach_craft(&"dock_04_cargo", craft, &"cinder_cargo_hauler")
	_check(bool(attached.get("accepted", false)) and craft.global_position == attached.get("landing_anchor", Vector3.INF), "Dock 04 accepts a NEW craft at its exact landing anchor")
	var duplicate := berths.attach_craft(&"dock_05_bomber", craft, &"cinder_cargo_hauler")
	_check(not bool(duplicate.get("accepted", true)) and duplicate.get("reason", &"") == &"craft_already_attached", "one craft cannot occupy multiple expansion pads")
	var foreign := Node3D.new()
	foreign.set_meta(&"evidence_status", &"NEW")
	root.add_child(foreign)
	await process_frame
	var foreign_detach := berths.detach_craft(&"dock_04_cargo", foreign)
	_check(not bool(foreign_detach.get("accepted", true)) and foreign_detach.get("reason", &"") == &"foreign_craft", "foreign detach requests fail closed")
	var detached := berths.detach_craft(&"dock_04_cargo", craft)
	_check(bool(detached.get("accepted", false)) and not bool(berths.get_attachment_snapshot(&"dock_04_cargo").get("attached", true)), "the owner detaches and clears a reusable pad")
	craft.queue_free()
	foreign.queue_free()
	berths.queue_free()
	await process_frame
	if _failures.is_empty():
		print("PASS fleet_expansion_berths_test (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
