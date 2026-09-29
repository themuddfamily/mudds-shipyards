extends SceneTree
## Cinder's platform, structure, beacon and belt activities measure the pilot
## against anchors authored in the streamed Cinder root's frame. A planet visit
## round trip leaves the common origin away from the authored one (a Rime
## abandon measured ShipyardWorld at (-31, -4.2, -48.5)), so these activities
## must start and hold from the live, visible places after that translation.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const MINING := preload("res://scripts/world/cinder_mining_platform_activity.gd")
const SCAN := preload("res://scripts/world/cinder_abandoned_structure_scan_activity.gd")
const BEACON := preload("res://scripts/world/cinder_beacon_traversal_activity.gd")
const BELT_ROUTE := preload("res://assets/activities/cinder_asteroid_field_threading_run.tres")
const ROUNDTRIP_ORIGIN_OFFSET := Vector3(-31.0, -4.203125, -48.5)

var _failures: Array[String] = []
var _assertions := 0


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame
	game.set_physics_process(false)
	var bootstrap := game.cinder_streaming_bootstrap
	var ship := game.get_flyable_ships()[1] as HeroShip
	ship.set_piloted(true)
	game.active_ship = ship
	game.set("_piloting", true)
	game.phase = GameFlow.Phase.FREE_FLIGHT
	game.set("_sortie_departed_berth", true)
	ship.global_position = bootstrap.to_global(MINING.APPROACH_ANCHOR)
	game.call("_physics_process", 0.1)
	for _i in 30:
		if bootstrap.get_loaded_instance() != null:
			break
		await process_frame
	var cluster := bootstrap.get_loaded_instance() as Node3D
	var binding := cluster.get_node_or_null(^"ActivityBinding") if cluster != null else null
	_check(binding != null, "the ship's own sample streams Cinder and its activity binding in")
	if binding == null:
		await _finish(game)
		return
	for common_root: Node3D in [game.world, bootstrap, game.cinder_convoy_host]:
		common_root.global_position += ROUNDTRIP_ORIGIN_OFFSET

	ship.global_position = bootstrap.to_global(MINING.APPROACH_ANCHOR)
	var mining := game.call("_start_nearby_activity", binding, &"cinder_platform_mining_run") as Dictionary
	_check(bool(mining.get("accepted", false)),
		"mining starts at the visible platform approach after an origin rebase (%s)" % mining.get("reason", &""))
	game.call("_physics_process", 0.1)
	var held := (binding.call(&"get_snapshot") as Dictionary).get("mining", {}) as Dictionary
	_check(StringName(held.get("state_id", &"")) == &"active",
		"holding at the visible platform keeps extracting after an origin rebase (%s)" % held.get("state_id", &""))
	binding.call(&"reset_mining_activity")

	ship.global_position = bootstrap.to_global(SCAN.APPROACH_ANCHOR)
	var scan := game.call("_start_nearby_activity", binding, &"cinder_derelict_structure_scan") as Dictionary
	_check(bool(scan.get("accepted", false)),
		"the structure scan starts at the visible derelict after an origin rebase (%s)" % scan.get("reason", &""))
	binding.call(&"reset_structure_scan")

	ship.global_position = bootstrap.to_global(BEACON.BEACONS[0])
	var beacon := game.call("_start_nearby_activity", binding, &"cinder_debris_beacon_traversal") as Dictionary
	_check(bool(beacon.get("accepted", false)),
		"the beacon traversal starts at the visible first beacon after an origin rebase (%s)" % beacon.get("reason", &""))
	if bool(beacon.get("accepted", false)):
		for index in 2:
			ship.global_position = bootstrap.to_global(BEACON.BEACONS[index])
			game.call("_physics_process", 0.1)
		var traversal := (binding.call(&"get_snapshot") as Dictionary).get("beacon_traversal", {}) as Dictionary
		_check(int(traversal.get("next_beacon_index", -1)) >= 2,
			"flying through the visible first two beacons advances the traversal after an origin rebase (next %d)"
				% int(traversal.get("next_beacon_index", -1)))
	binding.call(&"reset_beacon_traversal")

	ship.global_position = bootstrap.to_global(BELT_ROUTE.get_checkpoint_position(0))
	var belt := game.call("_start_nearby_activity", binding, &"cinder_asteroid_field_threading_run") as Dictionary
	_check(bool(belt.get("accepted", false)),
		"the belt threading run opens at the visible first gate after an origin rebase (%s)" % belt.get("reason", &""))
	await _finish(game)


func _check(ok: bool, message: String) -> void:
	_assertions += 1
	if ok:
		print("PASS: ", message)
	else:
		_failures.append(message)
		push_error("FAIL: " + message)


func _finish(game: GameFlow) -> void:
	if is_instance_valid(game):
		game.queue_free()
	await process_frame
	await process_frame
	if _failures.is_empty():
		print("CINDER_NEARBY_ACTIVITY_ORIGIN_REBASE_TEST_OK: %d assertions" % _assertions)
	else:
		print("CINDER_NEARBY_ACTIVITY_ORIGIN_REBASE_TEST_FAILED: ", ", ".join(_failures))
	quit(0 if _failures.is_empty() else 1)
