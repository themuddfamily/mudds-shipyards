extends SceneTree

const GameFlowType := preload("res://scripts/game/game_flow.gd")
const CinderType := preload("res://scripts/ships/cinder_long_range_bomber.gd")

class HudProbe extends CanvasLayer:
	var snapshots: Array[Dictionary] = []

	func update_network_session_status(snapshot: Dictionary) -> void:
		snapshots.append(snapshot.duplicate(true))


var _assertions := 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var flow := GameFlowType.new()
	var hud := HudProbe.new()
	var bomber := CinderType.new()
	root.add_child(bomber)
	flow.hud = hud
	flow.active_ship = bomber
	flow._piloting = true
	flow._publish_network_session_snapshot(&"connected", &"client", "Ready.")
	_check(hud.snapshots.size() == 1 and hud.snapshots[0].local_role == &"pilot", "publication marks the local piloting role")
	_check(hud.snapshots[0].controlled_craft == bomber.get_display_name() and int(hud.snapshots[0].generation) == 1, "publication includes craft name and generation")
	flow._piloting = false
	flow._publish_network_session_snapshot(&"disconnected", &"client", "Closed.")
	_check(hud.snapshots[1].local_role == &"observer" and hud.snapshots[1].state == &"disconnected", "disconnect clears local pilot ownership")
	bomber.queue_free()
	hud.free()
	flow.free()
	await process_frame
	if _failures.is_empty():
		print("GAME_FLOW_NETWORK_ROLE_PUBLICATION_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)
