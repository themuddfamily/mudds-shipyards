extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const DOOR_SCENE := preload("res://scenes/world/components/station_door.tscn")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	root.add_child(game)
	await process_frame
	await physics_frame
	var report: Dictionary = game.world.get_station_interaction_audit_report()
	_check(bool(report.get("valid", false)), "production station interaction roster passes its route-module audit")
	_check(int(report.get("door_count", 0)) >= 5, "all production module doors are represented in the interaction roster")
	_check(
		int(report.get("registered_module_count", 0)) == int(game.world.get_station_route_registry_report().get("module_count", -1)),
		"interaction audit derives its ownership set from the live route registry"
	)
	_check(not bool(report.get("owns_interaction_authority", true)), "interaction audit remains read-only")

	# A door placed directly under the world is an orphaned control: it must not
	# silently become a valid interaction just because it has the right Area3D.
	var orphan := DOOR_SCENE.instantiate() as StationDoor
	orphan.name = "OrphanInteractionDoor"
	game.world.add_child(orphan)
	await process_frame
	var orphan_report: Dictionary = game.world.get_station_interaction_audit_report()
	_check(not bool(orphan_report.get("valid", true)), "orphaned station control fails closed without a registered module")
	_check(
		"not owned by a registered route module" in "; ".join(orphan_report.get("errors", PackedStringArray()) as PackedStringArray),
		"orphan failure identifies the missing topology ownership"
	)
	orphan.queue_free()
	game.queue_free()
	await process_frame
	await process_frame
	_finish()


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("STATION_INTERACTION_TOPOLOGY_TEST_OK")
		quit(0)
	else:
		print("STATION_INTERACTION_TOPOLOGY_TEST_FAILED: ", "; ".join(_failures))
		quit(1)
