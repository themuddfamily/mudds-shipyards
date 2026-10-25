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
		and rows != null and rows.get_child_count() == 10,
		"one exclusive page exposes nine activities and the hulk salvage guide"
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

	# The Activity Board intentionally pauses the world, so close it before
	# exercising the real caller-sampled production streaming route. No activity
	# intent or page-open refresh is emitted between the transition and the report:
	# the coordinator signal itself must update the retained cards.
	hud.set_paused(false)
	var cinder_anchor := CinderStreamingBootstrap.EXPECTED_NAVIGATION_ANCHOR
	var toward_station := (Vector3.ZERO - cinder_anchor).normalized()
	game.player.teleport_to(Transform3D(
		Basis.IDENTITY,
		cinder_anchor + toward_station * 499.9,
	))
	var cinder_loaded := await _wait_for_cinder_residency(game, true)
	race_row = _row(rows, &"cinder_reach_checkpoint_route")
	var loaded_report := hud.get_nearby_activity_report()
	_check(
		cinder_loaded
		and bool((loaded_report.get("snapshot", {}) as Dictionary).get(
			"binding_available", false
		))
		and not nearby_page.is_visible_in_tree()
		and race_row != null
		and "OUT OF RANGE" not in (race_row.get_child(0) as Label).text
		and not (race_row.get_child(1) as Button).disabled
		and not (race_row.get_child(2) as Button).disabled
		and not (race_row.get_child(3) as Button).disabled,
		"crossing Cinder's real load radius refreshes the retained directory immediately"
	)

	game.player.teleport_to(game.world.get_player_spawn())
	var cinder_unloaded := await _wait_for_cinder_residency(game, false)
	race_row = _row(rows, &"cinder_reach_checkpoint_route")
	var unloaded_report := hud.get_nearby_activity_report()
	_check(
		cinder_unloaded
		and not bool((unloaded_report.get("snapshot", {}) as Dictionary).get(
			"binding_available", true
		))
		and not nearby_page.is_visible_in_tree()
		and race_row != null
		and "OUT OF RANGE" in (race_row.get_child(0) as Label).text
		and (race_row.get_child(1) as Button).disabled
		and (race_row.get_child(2) as Button).disabled
		and (race_row.get_child(3) as Button).disabled,
		"crossing Cinder's real unload radius restores disabled retained cards"
	)
	_check(hud.open_activity_board(), "the refreshed Activity Board reopens after return")
	open_button.emit_signal("pressed")
	_check(
		nearby_page.visible and not activity_page.visible,
		"the reopened directory presents the already-refreshed unloaded state"
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
	var content: StationDefenseEncounterContent = game.world.get_station_defense_content() as StationDefenseEncounterContent
	var before_arm_generation: int = content.get_generation()
	(defense_row.get_child(2) as Button).emit_signal("pressed")
	var arm := defense_board.call(&"get_launch_arm_snapshot") as Dictionary
	var arm_result := defense_board.call(&"get_last_result") as Dictionary
	var armed_snapshot: Dictionary = content.get_snapshot()
	_check(
		bool(arm_result.get("accepted", false)) and StringName(arm_result.get("reason", &"")) == &"launch_armed"
		and bool(arm.get("armed", false)) and int(arm.get("arm_id", 0)) > 0
		and int(arm.get("actor_instance_id", 0)) == game.player.get_instance_id()
		and int(arm.get("content_instance_id", 0)) == content.get_instance_id()
		and int(arm.get("generation", -1)) == before_arm_generation
		and content.get_generation() == before_arm_generation
		and StringName(armed_snapshot.host.activity.get("state_id", &"")) == &"idle"
		and int(armed_snapshot.host.active_entity_count) == 0
		and "STATION DEFENSE  //  ARMED  //  BOARD A CRAFT AND DEPART" in str(
			(hud.get("_nearby_activity_feedback") as Label).text
		),
		"the same route arms defense after the real on-foot board gate without starting enemies or advancing generation"
	)
	# Disclosed content-owner fixture for the existing active/reset UI checks.
	# This does not exercise or qualify ordinary physical boarding and launch.
	var owner_start: Dictionary = content.start(content.get_generation())
	var active_snapshot: Dictionary = content.get_snapshot()
	_check(bool(owner_start.get("accepted", false))
		and StringName(active_snapshot.host.activity.get("state_id", &"")) == &"active"
		and int(active_snapshot.host.active_entity_count) == 1
		and not bool((defense_board.call(&"get_launch_arm_snapshot") as Dictionary).get("armed", true)),
		"the disclosed content-owner fixture starts the first active wave and retires the earlier launch arm")
	game.call(&"_sync_activity_hud")
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


func _wait_for_cinder_residency(game: GameFlow, expected_loaded: bool) -> bool:
	# Unload intentionally includes the production half-second presentation fade,
	# so use a frame budget rather than a wall-clock sleep.
	for _frame in 240:
		await physics_frame
		await process_frame
		var cluster_available := is_instance_valid(
			game.world.get_nearby_sector_cluster()
		)
		if cluster_available == expected_loaded:
			return true
	return false


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
