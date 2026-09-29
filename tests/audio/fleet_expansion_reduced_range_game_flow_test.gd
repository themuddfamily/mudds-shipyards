extends SceneTree

## Reduced Dynamic Range set through production GameFlow reaches the Dock
## 04/05/06 craft's own engine and payload audio bindings, and a later toggle
## back off releases them.

const MAIN_SCENE := preload("res://scenes/main.tscn")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	root.add_child(game)
	await process_frame
	game.set_reduced_dynamic_range(true)
	var fleet: Node = null
	for _frame in 600:
		await process_frame
		fleet = game.world.get_fleet_expansion_production_binding() if game.world != null else null
		if fleet != null and bool(fleet.get_fleet_snapshot().get("built", false)):
			break
	_check(fleet != null and bool(fleet.get_fleet_snapshot().get("built", false)),
		"production Main builds the fleet expansion craft")
	if fleet == null:
		_finish(game)
		return
	await process_frame
	_check(_all_reduced(fleet, true), "GameFlow's reduced dynamic range reaches every fleet craft's audio (%s)"
		% _reduced_flags(fleet))
	game.set_reduced_dynamic_range(false)
	await process_frame
	_check(_all_reduced(fleet, false), "turning it off releases every fleet craft's audio (%s)"
		% _reduced_flags(fleet))
	_finish(game)


func _all_reduced(fleet: Node, expected: bool) -> bool:
	var crafts := fleet.get_fleet_snapshot().get("craft", []) as Array
	if crafts.is_empty():
		return false
	for craft: Dictionary in crafts:
		if bool((craft.get("audio", {}) as Dictionary).get("reduced_dynamic_range", not expected)) != expected:
			return false
	return true


func _reduced_flags(fleet: Node) -> String:
	var parts := PackedStringArray()
	for craft: Dictionary in fleet.get_fleet_snapshot().get("craft", []) as Array:
		parts.append("%s=%s" % [craft.get("craft_id"),
			(craft.get("audio", {}) as Dictionary).get("reduced_dynamic_range")])
	return ", ".join(parts)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", message)
	else:
		_failures.append(message)
		push_error("FAIL: " + message)


func _finish(game: Node) -> void:
	game.queue_free()
	await process_frame
	if _failures.is_empty():
		print("FLEET_EXPANSION_REDUCED_RANGE_GAME_FLOW_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		print("FLEET_EXPANSION_REDUCED_RANGE_GAME_FLOW_TEST_FAILED: %s" % "; ".join(_failures))
		quit(1)
