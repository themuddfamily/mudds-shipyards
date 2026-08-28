extends SceneTree

## Focused production route for the existing Cinder activity directory. The
## station starts outside Cinder's streaming envelope, so the test also proves
## the directory's honest unloaded state and the physical defense-board gate.

const MAIN_SCENE := preload("res://scenes/main.tscn")

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame
	var hud := game.hud as GameHUD
	_check(
		hud != null and game.world.get_nearby_sector_cluster() == null,
		"production starts at the shipyard with Cinder deliberately unloaded"
	)
	if hud == null:
		await _finish(game)
		return

	_check(hud.open_activity_board(), "the public Activity Board route opens")
	var activity_page := hud.get("_activity_selection_page") as Control
	var open_button := activity_page.find_child(
		"NearbyActivityOpenButton", true, false
	) as Button
	_check(open_button != null, "the Activity Board publishes a Cinder Sector action")
	if open_button != null:
		open_button.emit_signal("pressed")

	var nearby_page := hud.get("_nearby_activity_page") as Control
	var rows := hud.get("_nearby_activity_rows") as VBoxContainer
	var race_row := _row(rows, &"cinder_reach_checkpoint_route")
	var defense_row := _row(rows, &"station_defense")
	_check(
		nearby_page != null and nearby_page.visible and not activity_page.visible
		and rows != null and rows.get_child_count() == 8,
		"one exclusive page exposes all eight production activity cards"
	)
	_check(
		race_row != null
		and "OUT OF RANGE" in (race_row.get_child(0) as Label).text
		and "FLY TOWARD CINDER REACH TO LOAD" in (race_row.get_child(0) as Label).text
		and (race_row.get_child(1) as Button).disabled
		and (race_row.get_child(2) as Button).disabled
		and (race_row.get_child(3) as Button).disabled,
		"unloaded streamed activities are readable and cannot emit lifecycle requests"
	)
	_check(
		defense_row != null
		and not (defense_row.get_child(1) as Button).disabled
		and not (defense_row.get_child(2) as Button).disabled,
		"station defense remains live because its physical board is station-owned"
	)

	var defense_before: Dictionary = (
		game.world.get_station_defense_content().get_snapshot()
	)
	if defense_row != null:
		(defense_row.get_child(2) as Button).emit_signal("pressed")
	var defense_after: Dictionary = (
		game.world.get_station_defense_content().get_snapshot()
	)
	_check(
		defense_after == defense_before
		and "REPORT ON FOOT TO THE MARKED DECK BOARD" in str(
			(hud.get("_nearby_activity_feedback") as Label).text
		),
		"a remote directory click cannot bypass the physical defense-board gate"
	)
	var defense_board := game.world.get_station_defense_activity_board() as Area3D
	game.player.teleport_to(Transform3D(
		Basis.IDENTITY,
		defense_board.global_position + Vector3(0.0, 0.0, 1.0),
	))
	(defense_row.get_child(2) as Button).emit_signal("pressed")
	_check(
		StringName((
			game.world.get_station_defense_content().get_snapshot().host.activity
			as Dictionary
		).get("state_id", &"")) == &"active"
		and "STATION DEFENSE  //  STARTED" in str(
			(hud.get("_nearby_activity_feedback") as Label).text
		),
		"the same route starts defense after the real on-foot board gate is satisfied"
	)
	var reset := defense_row.get_child(3) as Button
	reset.emit_signal("pressed")
	_check(
		reset.text == "CONFIRM RESET"
		and StringName((
			game.world.get_station_defense_content().get_snapshot().host.activity
			as Dictionary
		).get("state_id", &"")) == &"active",
		"active defense requires the existing explicit reset confirmation"
	)
	reset.emit_signal("pressed")
	_check(
		StringName((
			game.world.get_station_defense_content().get_snapshot().host.activity
			as Dictionary
		).get("state_id", &"")) == &"idle"
		and "STATION DEFENSE  //  RESET" in str(
			(hud.get("_nearby_activity_feedback") as Label).text
		),
		"confirmed reset returns the physical encounter to a clean idle generation"
	)

	var back := nearby_page.find_child(
		"NearbyActivityBackButton", true, false
	) as Button
	if back != null:
		back.emit_signal("pressed")
	_check(
		activity_page.visible and not nearby_page.visible
		and hud.get_viewport().gui_get_focus_owner() == open_button,
		"Back restores the Activity Board and its exact controller focus target"
	)
	await _finish(game)


func _row(rows: VBoxContainer, activity_id: StringName) -> Control:
	if rows == null:
		return null
	for candidate in rows.get_children():
		if StringName(candidate.get_meta(&"activity_id", &"")) == activity_id:
			return candidate as Control
	return null


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: " + message)
	else:
		_failures.append(message)
		push_error("FAIL: " + message)


func _finish(game: GameFlow) -> void:
	if is_instance_valid(game) and is_instance_valid(game.hud):
		game.hud.set_paused(false)
	if is_instance_valid(game):
		game.queue_free()
	await process_frame
	await process_frame
	if _failures.is_empty():
		print("PASS nearby_activity_board_production_route_test (%d assertions)" % _assertions)
		quit(0)
	else:
		quit(1)
