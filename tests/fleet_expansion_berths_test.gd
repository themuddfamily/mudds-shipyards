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
	_check(berths.get_pad_ids() == [&"dock_04_cargo", &"dock_05_bomber"], "Dock 04 cargo and Dock 05 bomber are stable authored IDs")
	for pad_id in berths.get_pad_ids():
		var contract := berths.get_landing_contract(pad_id)
		_check(bool(contract.get("accepted", false)) and (contract.get("landing_anchor", Vector3.INF) as Vector3).is_finite(), "landing contract is finite for %s" % pad_id)
		_check(not bool(contract.get("ship_authority", true)) and not bool(contract.get("berth_lease_authority", true)), "contract remains caller-owned for %s" % pad_id)
	var unknown := berths.get_landing_contract(&"dock_99")
	_check(not bool(unknown.get("accepted", true)), "unknown pad IDs fail closed")
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
