extends SceneTree

## Contract for the compact, modern Dock Operations room in UpperOperations.
## It is deliberately presentation-only: the room may furnish the pod but must
## not consume berth, route, activity, or guide-light authority.

const WORLD_SCENE := preload("res://scenes/world/shipyard_world.tscn")

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := WORLD_SCENE.instantiate() as ShipyardWorld
	_check(world != null, "production ShipyardWorld instantiates")
	if world == null:
		_finish()
		return
	root.add_child(world)
	await process_frame

	var room := world.get_node_or_null(^"UpperOperations/DockOperationsRoom") as Node3D
	_check(
		room != null
		and bool(room.get_meta("presentation_only", false))
		and not bool(room.get_meta("historical_form_identified", true)),
		"Dock Operations remains a bounded modern presentation room"
	)
	_check(
		room != null
		and room.get_node_or_null(^"DockStatusBoard") is MeshInstance3D
		and room.get_node_or_null(^"DockStatusField") is MeshInstance3D
		and room.get_node_or_null(^"DockPlotTable") is StaticBody3D,
		"room has a seated status board and a collision-backed dispatch plot"
	)

	var console_count := 0
	var seat_count := 0
	for station_index in 3:
		if room != null and room.get_node_or_null(NodePath("DispatchConsole%02d" % (station_index + 1))) is StaticBody3D:
			console_count += 1
		if room != null and room.get_node_or_null(NodePath("DispatchSeat%02d" % (station_index + 1))) is StaticBody3D:
			seat_count += 1
	_check(console_count == 3 and seat_count == 3, "three dispatch stations and three physical seats are present")

	var lockers_clear_of_annex_aisle := true
	if room != null:
		for locker in room.find_children("DockEquipmentLocker*", "StaticBody3D", false, false):
			lockers_clear_of_annex_aisle = lockers_clear_of_annex_aisle and (locker as Node3D).position.x < 38.1
	_check(lockers_clear_of_annex_aisle, "west-wall lockers do not intrude into the Annex approach aisle")

	var room_lights := room.find_children("*", "Light3D", true, false) if room != null else []
	_check(room_lights.is_empty(), "room preserves the frozen UpperOperations guide-light allocation")

	world.queue_free()
	await process_frame
	_finish()


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", message)
	else:
		_failures.append(message)
		push_error("FAIL: " + message)


func _finish() -> void:
	if _failures.is_empty():
		print("DOCK_OPERATIONS_ROOM_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		push_error("DOCK_OPERATIONS_ROOM_TEST_FAILED: %s" % _failures)
		quit(1)
