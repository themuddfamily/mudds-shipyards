extends SceneTree

const BOARD_SCRIPT := preload("res://scripts/activities/station_defense_activity_board.gd")
const PHYSICS_LAYERS := preload("res://scripts/core/physics_layers.gd")

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var board := BOARD_SCRIPT.new() as Area3D
	root.add_child(board)
	await process_frame

	var console_body := board.get_node_or_null(^"CollisionBackedConsole") as StaticBody3D
	var console_collision := (
		console_body.get_node_or_null(^"Collision") as CollisionShape3D
		if console_body != null else null
	)
	var interaction_collision := board.get_node_or_null(^"InteractionCollision") as CollisionShape3D
	var identity_label := board.get_node_or_null(^"ActivityLabel") as Label3D
	var status_label := board.get_node_or_null(^"StatusLabel") as Label3D
	_check(
		console_body != null
		and console_collision != null and not console_collision.disabled
		and interaction_collision != null and not interaction_collision.disabled
		and identity_label != null and "STATION DEFENSE" in identity_label.text
		and status_label != null
		and board.collision_layer == PHYSICS_LAYERS.INTERACTABLE_AREA_LAYER,
		"readability display preserves the physical board identity and both collision seams"
	)

	board.call("_on_content_snapshot_changed", _snapshot(&"idle", 3))
	var ready: Dictionary = board.get_presentation_snapshot()
	_check(
		ready.state_id == &"idle"
		and int(ready.generation) == 3
		and ready.text == "READY\nINTERACT TO DEPLOY"
		and status_label.text == ready.text,
		"the authoritative idle generation presents a clear deployment-ready state"
	)

	board.call("_on_content_snapshot_changed", _snapshot(&"active", 4, 2, 3, 3))
	var active: Dictionary = board.get_presentation_snapshot()
	_check(
		active.state_id == &"active"
		and active.text == "WAVE 2 / 3\nTHREATS 3"
		and status_label.text == active.text,
		"the active snapshot presents current wave position and remaining threats"
	)

	var history_before_stale := (
		board.get_session_persistence_snapshot().history as Dictionary
	).duplicate(true)
	board.call("_on_content_snapshot_changed", _snapshot(&"completed", 3, 3, 3, 0))
	var after_stale: Dictionary = board.get_presentation_snapshot()
	_check(
		after_stale == active
		and status_label.text == active.text
		and board.get_session_persistence_snapshot().history == history_before_stale,
		"an older generation cannot replace presentation or repopulate terminal history"
	)

	board.call("_on_content_snapshot_changed", _snapshot(&"failed", 4, 2, 3, 3))
	var failed: Dictionary = board.get_presentation_snapshot()
	_check(
		failed.state_id == &"failed"
		and failed.text == "DEFENSE OFFLINE\nRECOVERY REQUIRED"
		and status_label.text == failed.text,
		"a terminal failure on the current generation makes recovery explicit"
	)

	board.call("_on_content_snapshot_changed", _snapshot(&"idle", 5))
	var recovered: Dictionary = board.get_presentation_snapshot()
	var board_snapshot: Dictionary = board.get_snapshot()
	_check(
		recovered.state_id == &"idle"
		and int(recovered.generation) == 5
		and recovered.text == "READY\nINTERACT TO DEPLOY"
		and bool(recovered.steady)
		and int(board_snapshot.process_loops) == 0
		and board.find_children("*", "Timer", true, false).is_empty(),
		"a fresh reset generation clears terminal copy without timers, flashing, or a process owner"
	)

	board.queue_free()
	await process_frame
	_finish()


func _snapshot(
		state_id: StringName,
		generation: int,
		wave_number: int = 0,
		wave_count: int = 3,
		remaining: int = 4
	) -> Dictionary:
	return {
		"host": {
			"activity": {
				"state_id": state_id,
				"generation": generation,
				"wave_number": wave_number,
				"wave_count": wave_count,
				"remaining_hostile_count": remaining,
			}
		}
	}


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
		return
	_failures.append(description)
	push_error("FAIL: %s" % description)


func _finish() -> void:
	if _failures.is_empty():
		print("STATION_DEFENSE_ACTIVITY_BOARD_READABILITY_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	print("STATION_DEFENSE_ACTIVITY_BOARD_READABILITY_TEST_FAILED: ", "; ".join(_failures))
	quit(1)
