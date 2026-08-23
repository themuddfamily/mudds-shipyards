extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")

var _assertions := 0
var _failures: Array[String] = []


func _initialize() -> void:
	var flow := MAIN_SCENE.instantiate() as GameFlow
	root.add_child(flow)
	# ShipyardWorld assembles its production binding deferred by one frame.
	await process_frame
	await process_frame
	await process_frame
	var startup_registered := flow.get_flyable_ships()
	_check(startup_registered.any(func(candidate: HeroShip) -> bool:
		return candidate.get_ship_id() == &"cinder-cargo-hauler"
	), "startup refresh discovers nested production craft")
	flow._resolve_scene_bindings()
	flow._register_flyable_ships()
	var registered := flow.get_flyable_ships()
	var ids := {}
	var berths := {}
	var expansion_count := 0
	for candidate in registered:
		ids[candidate.get_ship_id()] = true
		berths[candidate.get_home_berth_id()] = true
		if candidate.get_ship_id() in [
			&"cinder-cargo-hauler",
			&"cinder-long-range-bomber",
			&"cinder-light-interceptor",
		]:
			expansion_count += 1
	_check(expansion_count == 3, "all three production craft enter the flyable registry")
	_check(ids.size() == registered.size(), "registered ship IDs remain unique")
	_check(berths.size() == registered.size(), "registered home berth IDs remain unique")
	_check(registered.any(func(candidate: HeroShip) -> bool:
		return candidate.get_ship_id() == &"cinder-cargo-hauler"
	), "cargo hauler is available as a switch target")
	flow.queue_free()
	await process_frame
	if _failures.is_empty():
		print("PASS game_flow_fleet_expansion_registration_test (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
