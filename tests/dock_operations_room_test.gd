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
	var west_wall_bank_exact := true
	for station_index in 3:
		var expected_z := 24.5 + float(station_index) * 2.5
		var console := room.get_node_or_null(NodePath("DispatchConsole%02d" % (station_index + 1))) as StaticBody3D if room != null else null
		var screen := room.get_node_or_null(NodePath("DispatchScreen%02d" % (station_index + 1))) as MeshInstance3D if room != null else null
		var stool := room.get_node_or_null(NodePath("DispatchStool%02d" % (station_index + 1))) as StaticBody3D if room != null else null
		west_wall_bank_exact = west_wall_bank_exact \
			and console != null \
			and console.position.is_equal_approx(Vector3(38.25, 1.02, expected_z)) \
			and is_equal_approx(console.rotation_degrees.y, -90.0) \
			and screen != null \
			and screen.position.is_equal_approx(Vector3(38.72, 1.48, expected_z)) \
			and stool != null \
			and stool.position.is_equal_approx(Vector3(37.45, 0.73, expected_z))
	_check(west_wall_bank_exact, "all three dispatch stations form one exact west-wall bank")
	var keyline_audit := world.get_dock_operations_keyline_allocation_audit()
	_check(
		bool(keyline_audit.valid)
		and keyline_audit.before == {
			"family_nodes": 3,
			"renderer_nodes": 3,
			"structural_submissions": 3,
			"mesh_resources": 1,
			"material_resources": 1,
			"drawn_copies": 3,
		}
		and keyline_audit.current == {
			"family_nodes": 4,
			"renderer_nodes": 1,
			"structural_submissions": 1,
			"mesh_resources": 1,
			"material_resources": 1,
			"drawn_copies": 3,
		},
		"dispatch keylines record nodes 3->4, renderers/submissions 3->1, resources 1->1, and copies 3->3"
	)
	var keyline_paths_exact := room != null
	for keyline_index in 3:
		var anchor := room.get_node_or_null(NodePath(
			"DispatchKeyline%02d" % (keyline_index + 1)
		)) as Marker3D if room != null else null
		keyline_paths_exact = (
			keyline_paths_exact
			and anchor != null
			and anchor.position.is_equal_approx(Vector3(
				38.18, 1.67, 24.5 + float(keyline_index) * 2.5
			))
			and anchor.rotation_degrees.is_equal_approx(Vector3(-20.0, -90.0, 0.0))
			and anchor.get_child_count() == 0
			and bool(anchor.get_meta("batched_visual_anchor", false))
		)
	var keyline_batch := room.get_node_or_null(
		^"DispatchKeylineRenderBatch"
	) as MultiMeshInstance3D if room != null else null
	_check(
		keyline_paths_exact
		and keyline_batch != null
		and keyline_batch.multimesh.instance_count == 3
		and bool(keyline_audit.stable_paths_exact)
		and bool(keyline_audit.transforms_exact)
		and int(keyline_audit.collision_nodes) == 0
		and int(keyline_audit.interaction_nodes) == 0,
		"three stable keyline paths retain exact rotated poses while one authority-free batch draws them"
	)
	if room != null:
		var first_keyline := room.get_node(^"DispatchKeyline01") as Marker3D
		var original_transform := first_keyline.transform
		first_keyline.position.x += 0.04
		var red_keyline_audit := world.get_dock_operations_keyline_allocation_audit()
		first_keyline.transform = original_transform
		_check(
			not bool(red_keyline_audit.valid)
			and (red_keyline_audit.errors as PackedStringArray).has(
				"dock_operations_keyline_anchor_state_drift"
			)
			and bool(world.get_dock_operations_keyline_allocation_audit().valid),
			"moving one stable keyline anchor turns the transform audit red and restores cleanly"
		)
	var east_west_arrival_clear := true
	if room != null:
		for body in room.find_children("*", "StaticBody3D", true, false):
			var station_body := body as StaticBody3D
			if station_body.position.z >= 28.25 and station_body.position.z <= 28.85:
				east_west_arrival_clear = east_west_arrival_clear and station_body.position.x < 42.5
	_check(east_west_arrival_clear, "the east-west arrival line at z 28.5 is clear through the room")
	var central_floor_clear := true
	if room != null:
		for body in room.find_children("*", "StaticBody3D", true, false):
			var station_body := body as StaticBody3D
			central_floor_clear = central_floor_clear and not (
				station_body.position.x >= 40.0
				and station_body.position.z >= 24.5
				and station_body.position.z <= 28.8
			)
	_check(central_floor_clear, "the room centre is free of console, table, seat, and locker collision")
	var cargo_root := world.get_node_or_null(^"CargoAndMachinery") as Node3D
	var foreign_cargo_clear := true
	if cargo_root != null:
		for cargo in cargo_root.find_children("Cargo*", "StaticBody3D", false, false):
			var cargo_body := cargo as StaticBody3D
			foreign_cargo_clear = foreign_cargo_clear and not (
				cargo_body.position.x >= 37.0
				and cargo_body.position.x <= 49.0
				and cargo_body.position.z >= 23.0
				and cargo_body.position.z <= 31.0
			)
	_check(foreign_cargo_clear, "global cargo dressing does not occupy the Dock Operations pod")
	var plot_table := room.get_node_or_null(^"DockPlotTable") as StaticBody3D if room != null else null
	_check(
		plot_table != null and plot_table.position.is_equal_approx(Vector3(45.4, 0.78, 29.6)),
		"the plotting table occupies the back-right perimeter instead of the room centre"
	)
	var status_field := room.get_node_or_null(^"DockStatusField") as MeshInstance3D if room != null else null
	var status_material := status_field.material_override as StandardMaterial3D if status_field != null else null
	_check(
		status_material != null
		and status_material.emission_enabled
		and is_equal_approx(status_material.emission_energy_multiplier, 0.35)
		and status_material.albedo_color.is_equal_approx(Color("3a7479")),
		"the large traffic board uses an exposure-safe dark-screen recipe"
	)

	_check(
		room != null and room.find_children("DockEquipmentLocker*", "StaticBody3D", false, false).is_empty(),
		"obsolete lockers do not replace the cleared centre with an entrance obstruction"
	)

	var room_lights := room.find_children("*", "Light3D", true, false) if room != null else []
	var bounded_room_lights := room_lights.size() == 2
	for candidate in room_lights:
		var room_light := candidate as SpotLight3D
		bounded_room_lights = bounded_room_lights \
			and room_light != null \
			and is_equal_approx(room_light.light_energy, 1.6) \
			and is_equal_approx(room_light.spot_range, 8.5) \
			and is_equal_approx(room_light.spot_angle, 55.0) \
			and is_equal_approx(room_light.spot_angle_attenuation, 0.55) \
			and is_equal_approx(room_light.spot_attenuation, 0.85) \
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
			var room_light := candidate as SpotLight3D
			if room_light == null:
				continue
			var to_corner: Vector3 = floor_corner - room_light.global_position
			var cone_angle := rad_to_deg(acos(clampf((-room_light.global_basis.z).normalized().dot(to_corner.normalized()), -1.0, 1.0)))
			corner_covered = corner_covered or (
				to_corner.length() < room_light.spot_range
				and cone_angle < room_light.spot_angle
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
