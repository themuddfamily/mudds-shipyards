extends SceneTree

const MainScene := preload("res://scenes/main.tscn")

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
		_check(not markers.any(func(marker: Variant) -> bool: return marker is Dictionary and marker.get("id") == &"cinder_cargo_terminal"), "unloaded cluster removes its cargo marker")
	game.free()
	await process_frame
	if _failures.is_empty():
		print("GAME_FLOW_MINIMAP_ACTIVITY_MARKERS_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)
