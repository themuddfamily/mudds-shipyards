extends SceneTree

# Resolve the concrete subtype before shared HeroShip references to avoid retained script resources.
const ArrowShipType := preload("res://scripts/ships/arrow_recon_ship.gd")

const CLUSTER_SCENE := preload("res://scenes/world/components/nearby_sector_cluster.tscn")
const JOVIAN_SCENE := preload("res://scenes/ships/jovian_light_freighter.tscn")
const BINDING := preload("res://scripts/world/fleet_expansion_production_binding.gd")

var _assertions := 0
var _failures: Array[String] = []


func _initialize() -> void:
	var cluster := CLUSTER_SCENE.instantiate() as Node3D
	root.add_child(cluster)
	var production := BINDING.new()
	root.add_child(production)
	await process_frame
	await process_frame
	var activity := cluster.get_node_or_null(^"ActivityBinding") as Node
	# The authored activity receives a manifest only from its occupied Jovian
	# berth. Fleet forwarding must use that live authority, not an empty route.
	var source_ship := JOVIAN_SCENE.instantiate() as HeroShip
	root.add_child(source_ship)
	await process_frame
	var berth := cluster.get_cinder_cargo_access().get_berth() as ShipBerth
	var lease := berth.try_reserve(source_ship, source_ship.get_ship_definition())
	_check(not lease.is_empty() and berth.occupy(source_ship, lease),
		"the real occupied Jovian berth supplies the activity manifest")
	var bound: Dictionary = production.bind_cargo_activity(activity)
	_check(bool(bound.get("accepted", false)), "Dock04 composes the existing cargo activity bridge")
	var cargo := production.get_node(^"cinder_cargo_hauler") as Node
	var cargo_anchors: Array = cargo.call("get_cargo_transfer_anchors")
	var anchor_id: StringName = StringName((cargo_anchors[0] as Node).name)
	var snapshot_before := production.get_fleet_snapshot()
	var bomber_before: Dictionary = ((snapshot_before.get("craft", []) as Array)[1] as Dictionary).duplicate(true)
	var interceptor_before: Dictionary = ((snapshot_before.get("craft", []) as Array)[2] as Dictionary).duplicate(true)
	var started: Dictionary = production.start_cargo_activity(anchor_id)
	_check(bool(started.get("accepted", false)), "caller-owned cargo start forwards through Dock04")
	var phase: Dictionary = production.submit_cargo_activity_phase(&"load_crate", anchor_id)
	_check(bool(phase.get("accepted", false)), "caller-owned cargo phase forwards through Dock04")
	var detached: Dictionary = production.detach_craft(&"cinder_cargo_hauler")
	_check(bool(detached.get("accepted", false)), "Dock04 detach resets and clears the cargo activity bridge")
	_check(not bool((production.get_fleet_snapshot().get("cargo_activity", {}) as Dictionary).get("bound", true)), "stale cargo bridge is fenced after detach")
	var reattached: Dictionary = production.reattach_craft(&"cinder_cargo_hauler")
	_check(bool(reattached.get("accepted", false)), "Dock04 can reattach the same hauler")
	var rebound: Dictionary = production.bind_cargo_activity(activity)
	_check(bool(rebound.get("accepted", false)), "caller can rebind cargo activity after re-entry")
	var restarted: Dictionary = production.start_cargo_activity(anchor_id)
	_check(bool(restarted.get("accepted", false)), "re-entry starts a fresh fenced cargo generation")
	var final_rows := production.get_fleet_snapshot().get("craft", []) as Array
	_check(final_rows[1] == bomber_before and final_rows[2] == interceptor_before, "cargo activity lifecycle does not affect bomber or interceptor")
	production.detach_craft(&"cinder_cargo_hauler")
	berth.release(source_ship, lease)
	production.queue_free()
	source_ship.queue_free()
	cluster.queue_free()
	await process_frame
	await process_frame
	if _failures.is_empty():
		print("PASS fleet_expansion_cargo_activity_integration_test (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
