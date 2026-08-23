extends SceneTree

const Binding := preload("res://scripts/world/fleet_expansion_production_binding.gd")

var _assertions := 0
var _failures: Array[String] = []


func _initialize() -> void:
	var binding := Binding.new()
	root.add_child(binding)
	await process_frame
	await process_frame
	var audit := binding.get_audit_report()
	_check(bool(audit.get("valid", false)) and int(audit.get("fleet_count", 0)) == 3, "production binding composes three NEW craft and three typed berth slots")
	var snapshot := binding.get_fleet_snapshot()
	_check((snapshot.get("craft", []) as Array).size() == 3, "fleet snapshot publishes all composed craft")
	for craft in snapshot.get("craft", []) as Array:
		_check(bool((craft as Dictionary).get("attached", false)) and (craft as Dictionary).get("boarding_anchor", Vector3.INF) is Vector3, "each craft is attached with a boarding anchor")
	var detached := binding.detach_craft(&"cinder_long_range_bomber")
	_check(bool(detached.get("accepted", false)), "typed bomber detach succeeds")
	var reattached := binding.reattach_craft(&"cinder_long_range_bomber")
	_check(bool(reattached.get("accepted", false)), "detached bomber can be safely reused")
	_check(bool(binding.get_audit_report().get("valid", false)), "detach/reuse leaves the composition valid")
	binding.queue_free()
	await process_frame
	if _failures.is_empty():
		print("PASS fleet_expansion_production_binding_test (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
