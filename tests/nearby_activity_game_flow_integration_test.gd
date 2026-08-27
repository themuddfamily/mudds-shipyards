extends SceneTree

const GameFlowType := preload("res://scripts/game/game_flow.gd")
const HUD_SCENE := preload("res://scenes/ui/hud.tscn")

class BindingProbe extends Node3D:
	var starts: Array[StringName] = []
	var resets: Array[StringName] = []
	var patrol_actor_instance_id := 0
	var patrol_state := {
		"state_id": &"idle",
		"phase_id": &"idle",
		"generation": 0,
		"next_checkpoint_index": 0,
		"completed_checkpoint_count": 0,
		"checkpoint_count": 5,
	}

	func get_snapshot() -> Dictionary:
		return {
			"schema_version": 1,
			"activity_id": &"nearby",
			"host": {"activity": {"state_id": &"available"}},
			"patrol": patrol_state.duplicate(true),
			"generation": 3,
		}

	func start_race() -> Dictionary:
		starts.append(&"cinder_reach_checkpoint_route")
		return {"accepted": true, "reason": &"started", "snapshot": get_snapshot()}

	func reset_race() -> Dictionary:
		resets.append(&"cinder_reach_checkpoint_route")
		return {"accepted": true, "reason": &"reset", "snapshot": get_snapshot()}

	func start_patrol(patrol_actor: Variant = null) -> Dictionary:
		starts.append(&"cinder_relay_patrol")
		patrol_actor_instance_id = (
			patrol_actor.get_instance_id() if patrol_actor is Node3D else 0
		)
		patrol_state.merge({
			"state_id": &"active",
			"phase_id": &"travel",
			"generation": int(patrol_state.get("generation", 0)) + 1,
		}, true)
		return {"accepted": true, "reason": &"started", "snapshot": get_snapshot()}

	func reset_patrol() -> Dictionary:
		resets.append(&"cinder_relay_patrol")
		patrol_state.merge({
			"state_id": &"idle",
			"phase_id": &"idle",
			"generation": int(patrol_state.get("generation", 0)) + 1,
		}, true)
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


class ShipProbe extends HeroShip:
	func _ready() -> void:
		pass


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

	var retained_hud := HUD_SCENE.instantiate() as GameHUD
	root.add_child(retained_hud)
	var active_ship := ShipProbe.new()
	root.add_child(active_ship)
	await process_frame
	flow.world = world
	flow.hud = retained_hud
	flow.active_ship = active_ship
	retained_hud.nearby_activity_intent_requested.connect(
		flow._on_hud_nearby_activity_intent_requested
	)
	flow._sync_nearby_activity_hud()
	var patrol_row := _activity_row(retained_hud, &"cinder_relay_patrol")
	var start_button := patrol_row.get_child(2) as Button if patrol_row != null else null
	_check(
		patrol_row != null
			and start_button != null
			and _activity_text(patrol_row).contains("AVAILABLE")
			and _activity_text(patrol_row).contains("PATROL READY"),
		"the retained HUD exposes the public AVAILABLE patrol action",
	)
	if start_button != null:
		start_button.emit_signal(&"pressed")
	patrol_row = _activity_row(retained_hud, &"cinder_relay_patrol")
	_check(
		binding.starts == [&"cinder_reach_checkpoint_route", &"cinder_relay_patrol"]
			and binding.patrol_actor_instance_id == active_ship.get_instance_id()
			and StringName(binding.patrol_state.get("state_id", &"")) == &"active"
			and StringName(binding.patrol_state.get("phase_id", &"")) == &"travel"
			and _activity_text(patrol_row).contains("ACTIVE")
			and _activity_text(patrol_row).contains("APPROACH BEACON 1/5"),
		"the real retained START button routes through GameFlow to ACTIVE/TRAVEL",
	)
	var reset_button := patrol_row.get_child(3) as Button if patrol_row != null else null
	if reset_button != null:
		reset_button.emit_signal(&"pressed")
	_check(
		reset_button != null
			and reset_button.text == "CONFIRM RESET"
			and binding.resets == [&"cinder_reach_checkpoint_route"],
		"the first retained RESET press preserves the active patrol for confirmation",
	)
	if reset_button != null:
		reset_button.emit_signal(&"pressed")
	patrol_row = _activity_row(retained_hud, &"cinder_relay_patrol")
	_check(
		binding.resets == [&"cinder_reach_checkpoint_route", &"cinder_relay_patrol"]
			and StringName(binding.patrol_state.get("state_id", &"")) == &"idle"
			and _activity_text(patrol_row).contains("AVAILABLE")
			and _activity_text(patrol_row).contains("PATROL READY"),
		"the confirmed retained RESET routes through GameFlow back to AVAILABLE",
	)

	flow.hud = null
	flow.active_ship = null
	retained_hud.queue_free()
	active_ship.queue_free()
	hud.free()
	world.free()
	flow.free()
	for _frame in 3:
		await process_frame
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


func _activity_row(hud: GameHUD, activity_id: StringName) -> Control:
	var rows := hud.get("_nearby_activity_rows") as VBoxContainer
	for candidate in rows.get_children() if rows != null else []:
		if StringName(candidate.get_meta(&"activity_id", &"")) == activity_id:
			return candidate as Control
	return null


func _activity_text(row: Control) -> String:
	return str((row.get_child(0) as Label).text) if row != null else ""
