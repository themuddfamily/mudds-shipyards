extends SceneTree

const BINDING := preload("res://scripts/world/fleet_expansion_production_binding.gd")

var _assertions := 0
var _failures: Array[String] = []


func _initialize() -> void:
	var binding := BINDING.new()
	root.add_child(binding)
	await process_frame
	await process_frame
	for row in binding.get_fleet_snapshot().get("craft", []) as Array:
		var craft_id: StringName = (row as Dictionary).get("craft_id", &"")
		var contract: Dictionary = binding.get_craft_compatibility_contract(craft_id)
		_check(bool(contract.get("accepted", false)) and bool(contract.get("valid", false)), "%s has an exact berth/access compatibility contract" % craft_id)
		_check((contract.get("seat_anchor", Vector3.INF) as Vector3).is_finite() and (contract.get("boarding_anchor", Vector3.INF) as Vector3).is_finite(), "%s publishes finite seat and boarding anchors" % craft_id)
		var reset: Dictionary = binding.reset_craft_for_reuse(craft_id)
		_check(bool(reset.get("accepted", false)) and int(reset.get("receipt_id", 0)) > 0, "%s accepts one HeroShip reuse reset generation" % craft_id)
		_check(bool(reset.get("attachment_preserved", false)), "%s remains attached after reuse reset" % craft_id)
	binding.queue_free()
	await process_frame
	if _failures.is_empty():
		print("PASS fleet_expansion_production_lifecycle_test (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
