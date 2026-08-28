extends SceneTree

const MainScene := preload("res://scenes/main.tscn")
const Route := preload("res://assets/activities/cinder_reach_checkpoint_route.tres")

var _assertions := 0
var _failures: PackedStringArray = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := MainScene.instantiate() as GameFlow
	root.add_child(game)
	await process_frame
	await physics_frame
	var snapshot := game.get_minimap_snapshot()
	var markers := snapshot.get("objective_markers", []) as Array
	_check(snapshot.has("objective_markers"), "production minimap snapshot publishes objective marker roster")
	var board_found := false
	for marker_variant in markers:
		if marker_variant is Dictionary and marker_variant.get("id") == &"station_defense_activity_board":
			board_found = true
			_check(int(marker_variant.get("generation", -1)) >= 0, "station defense board marker carries generation")
	_check(board_found, "production ShipyardWorld contributes the station defense board marker")
	var cluster: NearbySectorCluster = (game.get_node("ShipyardWorld") as ShipyardWorld).get_nearby_sector_cluster()
	if is_instance_valid(cluster):
		var cargo_found := false
		for marker_variant in markers:
			if marker_variant is Dictionary and marker_variant.get("id") == &"cinder_cargo_terminal":
				cargo_found = true
				_check(int(marker_variant.get("generation", -1)) >= 0, "cargo terminal marker carries generation")
		_check(cargo_found, "loaded NearbySectorCluster contributes the cargo terminal marker")
	else:
		_check(
			_find_marker(markers, &"cinder_cargo_terminal").is_empty(),
			"unloaded cluster removes its cargo marker"
		)

	# Stand in for the completed physical boarding/launch transition while the
	# production race adapter remains the sole route lifecycle owner.
	var fleet := game.get_flyable_ships()
	game.active_ship = fleet[1] as HeroShip
	game.set("_piloting", true)
	game.phase = GameFlow.Phase.FREE_FLIGHT
	game.call("_start_default_free_flight_activity")
	var running_snapshot := game.get_minimap_snapshot()
	var running_markers := running_snapshot.get("objective_markers", []) as Array
	var route_marker := _find_marker(running_markers, &"active_route_checkpoint")
	_check(not route_marker.is_empty(), "a running production route contributes one next-checkpoint marker")
	if not route_marker.is_empty():
		_check(
			(route_marker.get("position", Vector3.INF) as Vector3).is_equal_approx(
				Route.get_checkpoint_position(0)
			)
			and int(route_marker.get("generation", 0)) >= 1,
			"the route marker observes the authored first checkpoint and live generation"
		)
	_check(
		game.fail_active_activity(&"marker_test_finished"),
		"the normal activity lifecycle accepts the focused terminal transition"
	)
	var terminal_markers := (
		game.get_minimap_snapshot().get("objective_markers", []) as Array
	)
	_check(
		_find_marker(terminal_markers, &"active_route_checkpoint").is_empty(),
		"terminal activity state removes route guidance without retaining a stale target"
	)
	game.free()
	await process_frame
	if _failures.is_empty():
		print("GAME_FLOW_MINIMAP_ACTIVITY_MARKERS_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _find_marker(markers: Array, marker_id: StringName) -> Dictionary:
	for marker_variant in markers:
		if marker_variant is Dictionary \
				and marker_variant.get("id", &"") == marker_id:
			return (marker_variant as Dictionary).duplicate(true)
	return {}

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)
