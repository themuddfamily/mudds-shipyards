extends SceneTree

const WORLD_SCENE := preload("res://scenes/world/shipyard_world.tscn")

var _assertions := 0
var _failures: Array[String] = []


func _initialize() -> void:
	var world := WORLD_SCENE.instantiate() as ShipyardWorld
	root.add_child(world)
	await process_frame
	await process_frame
	var binding := world.get_fleet_expansion_production_binding()
	_check(binding != null and binding.get_parent() == world, "ShipyardWorld owns the fleet expansion production binding")
	var audit := world.get_fleet_expansion_production_audit_report()
	_check(bool(audit.get("valid", false)), "ShipyardWorld publishes a valid Dock 04/05/06 production audit")
	var snapshot := audit.get("snapshot", {}) as Dictionary
	var craft := snapshot.get("craft", []) as Array
	_check(craft.size() == 3, "production integration publishes cargo, bomber, and interceptor")
	var expected := [&"dock_04_cargo", &"dock_05_bomber", &"dock_06_interceptor"]
	for index in craft.size():
		var row := craft[index] as Dictionary
		_check(row.get("pad_id", &"") == expected[index] and bool(row.get("attached", false)), "Dock %s remains attached" % expected[index])
	world.queue_free()
	await process_frame
	if _failures.is_empty():
		print("PASS fleet_expansion_shipyard_integration_test (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
