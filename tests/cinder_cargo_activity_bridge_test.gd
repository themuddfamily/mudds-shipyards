extends SceneTree

const CLUSTER_SCENE := preload("res://scenes/world/components/nearby_sector_cluster.tscn")
const CRAFT := preload("res://scripts/ships/cinder_cargo_hauler.gd")
const BRIDGE := preload("res://scripts/ships/cinder_cargo_activity_bridge.gd")

var _assertions := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var cluster := CLUSTER_SCENE.instantiate() as Node3D
	root.add_child(cluster)
	await process_frame
	var binding := cluster.get_node_or_null(^"ActivityBinding") as Node
	var craft := CRAFT.new()
	root.add_child(craft)
	await process_frame
	var bridge := BRIDGE.new()
	var bound: Dictionary = bridge.bind(craft, binding)
	_check(bool(bound.get("accepted", false)), "bridge binds the flyable cargo craft to the authored activity")
	var anchor := StringName(craft.get_cargo_transfer_anchors()[0].name)
	var started: Dictionary = bridge.start(anchor)
	_check(bool(started.get("accepted", false)), "bridge forwards a validated cargo-run start intent")
	var rejected_anchor: Dictionary = bridge.submit_phase(&"load_crate", &"foreign_anchor")
	_check(not bool(rejected_anchor.get("accepted", true)) and rejected_anchor.get("reason", &"") == &"unknown_transfer_anchor", "foreign transfer anchors fail closed")
	var phase: Dictionary = bridge.submit_phase(&"load_crate", anchor)
	_check(bool(phase.get("accepted", false)), "bridge forwards a validated phase receipt")
	var detached: Dictionary = bridge.detach()
	_check(bool(detached.get("accepted", false)), "detach resets active cargo state and clears the bridge")
	_check(not bool(bridge.get_snapshot().get("bound", true)), "detach clears craft and binding identity")
	craft.queue_free()
	cluster.queue_free()
	await process_frame
	if _failures.is_empty():
		print("PASS cinder_cargo_activity_bridge_test (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
