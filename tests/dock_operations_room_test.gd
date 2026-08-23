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
	var relocated_console := room.get_node_or_null(^"DispatchConsole03") as StaticBody3D if room != null else null
	var relocated_screen := room.get_node_or_null(^"DispatchScreen03") as MeshInstance3D if room != null else null
	var relocated_stool := room.get_node_or_null(^"DispatchStool03") as StaticBody3D if room != null else null
	_check(
		relocated_console != null
		and relocated_console.position.is_equal_approx(Vector3(45.5, 1.02, 24.75))
		and relocated_screen != null
		and relocated_screen.position.is_equal_approx(Vector3(45.5, 1.48, 24.28))
		and relocated_stool != null
		and relocated_stool.position.is_equal_approx(Vector3(45.5, 0.73, 25.55)),
		"dispatch station 03 moves as one assembly into the front-right corner"
	)
	var east_west_arrival_clear := true
	if room != null:
		for body in room.find_children("*", "StaticBody3D", true, false):
			var station_body := body as StaticBody3D
			if station_body.position.z >= 28.25 and station_body.position.z <= 28.85:
				east_west_arrival_clear = east_west_arrival_clear and station_body.position.x < 42.5
	_check(east_west_arrival_clear, "the east-west arrival line at z 28.5 is clear through the room")

	var lockers_clear_of_annex_aisle := true
	if room != null:
		for locker in room.find_children("DockEquipmentLocker*", "StaticBody3D", false, false):
			lockers_clear_of_annex_aisle = lockers_clear_of_annex_aisle and (locker as Node3D).position.x < 38.1
	_check(lockers_clear_of_annex_aisle, "west-wall lockers do not intrude into the Annex approach aisle")

	var room_lights := room.find_children("*", "Light3D", true, false) if room != null else []
	var bounded_room_lights := room_lights.size() == 2
	for candidate in room_lights:
		var room_light := candidate as OmniLight3D
		bounded_room_lights = bounded_room_lights \
			and room_light != null \
			and is_equal_approx(room_light.light_energy, 0.82) \
			and is_equal_approx(room_light.omni_range, 9.0) \
			and is_equal_approx(room_light.omni_attenuation, 1.45) \
			and room_light.light_color.is_equal_approx(Color("d9f6f3")) \
			and not room_light.shadow_enabled \
			and room_light.distance_fade_enabled \
			and bool(room_light.get_meta("localized_room_practical", false))
	_check(bounded_room_lights, "two bounded ceiling practicals light only the Dock Operations room")
	var floor_corners_covered := room_lights.size() == 2
	for floor_corner in [
		Vector3(37.5, 0.40, 23.5), Vector3(48.5, 0.40, 23.5),
		Vector3(37.5, 0.40, 30.5), Vector3(48.5, 0.40, 30.5),
	]:
		var corner_covered := false
		for candidate in room_lights:
			var room_light := candidate as OmniLight3D
			corner_covered = corner_covered or (
				room_light != null
				and room_light.global_position.distance_to(floor_corner) < room_light.omni_range
			)
		floor_corners_covered = floor_corners_covered and corner_covered
	_check(floor_corners_covered, "every room-floor corner falls inside at least one practical's range")
	_check(
		room != null
		and room.find_children("OperationsCeilingLight*Body", "MeshInstance3D", false, false).size() == 2
		and room.find_children("OperationsCeilingLight*Lens", "MeshInstance3D", false, false).size() == 2,
		"each room light has a roof-seated housing and visible ceiling lens"
	)

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
