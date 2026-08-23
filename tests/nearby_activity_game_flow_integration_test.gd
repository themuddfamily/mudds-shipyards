extends SceneTree

const GameFlowType := preload("res://scripts/game/game_flow.gd")

class BindingProbe extends Node3D:
	var starts: Array[StringName] = []
	var resets: Array[StringName] = []

	func get_snapshot() -> Dictionary:
		return {"schema_version": 1, "activity_id": &"nearby", "host": {"activity": {"state_id": &"available"}}, "generation": 3}

	func start_race() -> Dictionary:
		starts.append(&"cinder_reach_checkpoint_route")
		return {"accepted": true, "reason": &"started", "snapshot": get_snapshot()}

	func reset_race() -> Dictionary:
		resets.append(&"cinder_reach_checkpoint_route")
		return {"accepted": true, "reason": &"reset", "snapshot": get_snapshot()}


class ClusterProbe extends Node3D:
	func _init() -> void:
		var binding := BindingProbe.new()
		binding.name = "ActivityBinding"
		add_child(binding)


class WorldProbe extends Node3D:
	var cluster := ClusterProbe.new()

	func _init() -> void:
		add_child(cluster)

	func get_nearby_sector_cluster() -> Node3D:
		return cluster


class HudProbe extends CanvasLayer:
	var snapshots: Array[Dictionary] = []
	var cleared := 0

	func set_nearby_activity_snapshot(snapshot: Dictionary) -> void:
		snapshots.append(snapshot.duplicate(true))

	func clear_nearby_activity_snapshot() -> void:
		cleared += 1


var _assertions := 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var flow := GameFlowType.new()
	var world := WorldProbe.new()
	var hud := HudProbe.new()
	flow.world = world
	flow.hud = hud
	flow._sync_nearby_activity_hud()
	_check(hud.snapshots.size() == 1 and hud.snapshots[0].activity_id == &"nearby", "binding snapshot reaches retained HUD")
	flow._on_hud_nearby_activity_intent_requested({"reason": &"start_requested", "activity_id": &"cinder_reach_checkpoint_route"})
	var binding := world.cluster.get_node(^"ActivityBinding") as BindingProbe
	_check(binding.starts == [&"cinder_reach_checkpoint_route"], "start intent routes through binding authority")
	flow._on_hud_nearby_activity_intent_requested({"reason": &"reset_requested", "activity_id": &"cinder_reach_checkpoint_route"})
	_check(binding.resets == [&"cinder_reach_checkpoint_route"], "reset intent routes through binding authority")
	flow._on_hud_nearby_activity_intent_requested({"reason": &"start_requested", "activity_id": &"unknown"})
	_check(binding.starts.size() == 1, "unknown activity cannot invoke a binding method")
	flow.world = null
	flow._sync_nearby_activity_hud()
	_check(hud.cleared == 1, "unloaded nearby cluster clears stale HUD snapshot")
	if _failures.is_empty():
		print("NEARBY_ACTIVITY_GAME_FLOW_INTEGRATION_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)
