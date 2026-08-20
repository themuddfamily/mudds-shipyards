extends SceneTree

## Bounded interaction evidence for ROADMAP 576.  This suite reads the live
## station only: the contract owns no route or interaction authority and every
## red-path mutation below is restored before the next audit.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const CONTRACT := preload("res://scripts/world/station_interaction_contract.gd")

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "production Main instantiates for station interaction evidence")
	if game == null:
		_finish()
		return
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame

	var world := game.get_node_or_null(^"ShipyardWorld") as ShipyardWorld
	_check(world != null, "production Main owns the live ShipyardWorld")
	if world == null:
		game.queue_free()
		await process_frame
		_finish()
		return

	var registry_before := world.get_station_route_registry_report()
	var contract = CONTRACT.new()
	var report := contract.audit(world)
	_check(bool(report.get("valid", false)), "live station interaction contract is valid")
	_check(int(report.get("schema_version", 0)) == 1, "interaction contract schema is explicit")
	_check(int(report.get("module_count", 0)) == int(registry_before.get("module_count", -1)), "interaction audit covers every registered module")
	_check(int(report.get("route_marker_count", 0)) == int(registry_before.get("resolved_route_marker_count", -1)), "interaction audit resolves every published route marker")
	_check(int(report.get("door_count", 0)) == 5, "live station publishes the five embodied StationDoor targets")
	_check(int(report.get("reachable_door_count", 0)) == int(report.get("door_count", -1)), "every live StationDoor is reachable from a route marker with the production interaction sphere")
	_check(not bool(report.get("owns_topology", true)), "interaction contract remains read-only and owns no topology")
	_check(not bool(report.get("owns_interaction_authority", true)), "interaction contract remains separate from GameFlow and StationDoor authority")

	var deferred := report.get("deferred_landmarks", []) as Array
	_check(int(report.get("deferred_landmark_count", 0)) == 3, "deferred landmark roster contains the two internal pads and one empty dock")
	_check(_count_kind(deferred, &"deferred_connection_route") == 2, "deferred internal routes remain explicitly non-connection routes")
	_check(_count_kind(deferred, &"deferred_dock") == 1, "exactly one empty dock remains a deferred presentation landmark")
	for row in deferred:
		_check((row as Dictionary).get("errors", PackedStringArray()).is_empty(), "every deferred landmark carries an explicit non-authoritative contract")

	# Route-marker metadata drift must turn the read-only audit red while leaving
	# the world's published topology report untouched.
	var aft := world.get_node_or_null(^"AftJunctionStack") as Node
	var approach := aft.get_route_marker(&"approach") as Node3D if aft != null else null
	_check(approach != null, "Aft approach marker is available for the structured-red probe")
	if approach != null:
		var original_route_id: Variant = approach.get_meta("route_id", null)
		approach.set_meta("route_id", &"wrong-route-id")
		var red := contract.audit(world)
		_check(not bool(red.get("valid", true)), "route-marker identity drift turns the interaction audit red")
		approach.set_meta("route_id", original_route_id)
		var restored := contract.audit(world)
		_check(bool(restored.get("valid", false)), "restoring route-marker identity returns the interaction audit to green")

	# Door layer drift is an interaction defect, not a topology edit.
	var first_door := world.find_children("*", "StationDoor", true, false)[0] as StationDoor
	var original_mask := first_door.collision_mask
	first_door.collision_mask = 1
	var door_red := contract.audit(world)
	_check(not bool(door_red.get("valid", true)), "active interaction mask drift turns the interaction audit red")
	first_door.collision_mask = original_mask
	var restored_door := contract.audit(world)
	_check(bool(restored_door.get("valid", false)), "restoring the door interaction mask returns the audit to green")

	# A deferred dock may remain visible as a landmark, but it may not quietly
	# become a station endpoint or acquire berth authority.
	var comb := world.get_fleet_dock_comb()
	var deferred_marker := comb.get_deferred_dock_marker(&"deferred-dock-03") if comb != null else null
	_check(deferred_marker != null, "the deferred dock marker is available for the authority-boundary probe")
	if deferred_marker != null:
		deferred_marker.set_meta("station_connection_slot", &"forbidden-slot")
		var deferred_red := contract.audit(world)
		_check(not bool(deferred_red.get("valid", true)), "a deferred dock claiming a route slot turns the audit red")
		deferred_marker.remove_meta("station_connection_slot")
		var restored_deferred := contract.audit(world)
		_check(bool(restored_deferred.get("valid", false)), "restoring the deferred dock declaration returns the audit to green")

	_check(registry_before == world.get_station_route_registry_report(), "all interaction probes leave the published route topology byte-for-byte equivalent")
	game.queue_free()
	await process_frame
	await process_frame
	_finish()


func _count_kind(rows: Array, kind: StringName) -> int:
	var count := 0
	for row in rows:
		if StringName((row as Dictionary).get("kind", &"")) == kind:
			count += 1
	return count


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("STATION_INTERACTION_CONTRACT_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		print("STATION_INTERACTION_CONTRACT_TEST_FAILED: ", "; ".join(_failures))
		quit(1)
