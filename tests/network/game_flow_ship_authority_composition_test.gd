extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const Composition := preload("res://scripts/network/network_ship_authority_composition.gd")
const CinderCargoHaulerType := preload("res://scripts/ships/cinder_cargo_hauler.gd")

var _failures := PackedStringArray()
var _assertions := 0


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame
	var port := 28000 + (OS.get_process_id() % 1000)
	var session := game.host_network_session(port, 2)
	_check(bool(session.get("accepted", false)), "GameFlow starts the authoritative host session")
	var network := game.get_network_session()
	var composition := game.get("_network_ship_authority_composition") as NetworkShipAuthorityComposition
	_check(composition != null, "host retains one ship authority composition")
	if composition == null:
		await _finish(game)
		return
	var first_ship := game.get_active_ship()
	var first_generation := int(composition.get("_ship_generation"))
	_check(first_ship != null and first_generation > 0, "composition attaches the active ship")
	game._physics_process(1.0 / 60.0)
	_check(
		int(composition.get("_ship_generation")) == first_generation,
		"server caller tick preserves the attached ship generation",
	)
	var replacement := game.get_flyable_ships().filter(func(candidate: HeroShip) -> bool:
		return candidate is CinderCargoHaulerType
	)[0] as HeroShip
	game.set("active_ship", replacement)
	game._physics_process(1.0 / 60.0)
	_check(
		composition.get("_ship") == replacement
			and int(composition.get("_ship_generation")) > first_generation,
		"active ship replacement reattaches a fresh composition generation",
	)
	_check(composition.get("_cinder_bridge") != null, "Cinder replacement retains its loadmaster bridge")
	var halyard_bridge: Variant = game.get("_network_halyard_command_bridge")
	_check(
		halyard_bridge == null or halyard_bridge.get("_halyard") == replacement,
		"ship replacement retires stale Halyard dispatch target",
	)
	var server_sequence := int(game.get("_network_ship_event_sequence"))
	game.set("_network_session_mode", &"client")
	game._physics_process(1.0 / 60.0)
	_check(
		int(game.get("_network_ship_event_sequence")) == server_sequence,
		"client mode never publishes authoritative telemetry",
	)
	_check(
		int(network.get("_cargo_manifest_revision")) == 0,
		"Cinder bridge remains inert until an admitted manifest intent",
	)
	root.remove_child(game)
	await process_frame
	_check(composition.get("_ship") == null, "whole-GameFlow detach clears composition state")
	root.add_child(game)
	await process_frame
	await process_frame
	var restarted := game.host_network_session(port, 2)
	_check(bool(restarted.get("accepted", false)), "re-entry can host a fresh session")
	var reentered := game.get("_network_ship_authority_composition") as NetworkShipAuthorityComposition
	_check(reentered != null and reentered.get("_ship") == game.get_active_ship(), "re-entry reattaches current ship")
	await _finish(game)


func _finish(game: Node) -> void:
	if is_instance_valid(game):
		game.queue_free()
	await process_frame
	if _failures.is_empty():
		print("OK: GameFlow ship authority composition (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
