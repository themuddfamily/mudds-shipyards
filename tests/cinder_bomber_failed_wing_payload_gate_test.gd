extends SceneTree

## A failed bomber wing must hold the payload release exactly as a failed wing
## holds every other craft's cannon, and repair must reopen it. Production Main
## drives the real GameFlow fire edge into the Cinder payload authority.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const ComponentDamage := preload("res://scripts/combat/ship_component_damage.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	root.add_child(game)
	for _frame in 4:
		await process_frame
		await physics_frame
	var bomber: CinderLongRangeBomber
	for candidate: HeroShip in game.get_flyable_ships():
		if candidate is CinderLongRangeBomber:
			bomber = candidate as CinderLongRangeBomber
			break
	_check(bomber != null, "production Main exposes the flyable Cinder bomber")
	if bomber == null:
		await _finish(game)
		return

	game.set_process(false)
	game.set_physics_process(false)
	bomber.set_physics_process(false)
	game.active_ship = bomber
	game._piloting = true
	game.phase = GameFlow.Phase.FREE_FLIGHT
	bomber.set_piloted(true)
	bomber.set("_engine_state", HeroShip.ENGINE_ONLINE)
	game.call(&"_reset_lifecycle_command_cursor")

	var model := bomber.get_component_damage()
	model.record_damage(
		bomber.maximum_hull * 2.0,
		_component_local_position(bomber, ComponentDamage.COMPONENT_STARBOARD_WING)
	)
	_check(
		model.get_component_state(ComponentDamage.COMPONENT_STARBOARD_WING)
			== ComponentDamage.ComponentState.FAILED
		and bomber.get_weapon_fire_status().get("reason", &"") == &"weapon_component_failed",
		"the starboard wing has failed and the craft's own fire status reports it",
	)

	var fire := InputEventAction.new()
	fire.action = &"fire"
	fire.pressed = true
	game.call(&"_unhandled_input", fire)
	var blocked := game.get_bomber_payload_loop_snapshot()
	_check(
		int(blocked.get("request_sequence", -1)) == 0
		and (blocked.get("projectiles", []) as Array).is_empty()
		and int(bomber.get_payload_authority_snapshot().get("ammunition_remaining", 0)) == 4
		and (blocked.get("last_result", {}) as Dictionary).get("reason", &"")
			== &"weapon_component_failed",
		"a failed wing holds the payload release and spends no ammunition (loop=%s)" % blocked,
	)
	_check(
		String(bomber.call(&"_get_cockpit_system_readout").get("text", "")).contains("LOCKED"),
		"the cockpit payload line reads locked while the wing is failed",
	)

	var before := model.get_component_integrity(ComponentDamage.COMPONENT_STARBOARD_WING)
	model.tick_component_repair(
		ComponentDamage.COMPONENT_STARBOARD_WING,
		(1.0 - before) / maxf(model.repair_rate_per_second, 0.001) + 0.1,
		true
	)
	game.call(&"_unhandled_input", fire)
	var released := game.get_bomber_payload_loop_snapshot()
	_check(
		int(released.get("request_sequence", 0)) == 1
		and (released.get("projectiles", []) as Array).size() == 1
		and int(bomber.get_payload_authority_snapshot().get("ammunition_remaining", 0)) == 3
		and bool((released.get("last_result", {}) as Dictionary).get("accepted", false)),
		"repairing the wing reopens the payload release (loop=%s)" % released,
	)
	await _finish(game)


func _component_local_position(ship: HeroShip, component_id: StringName) -> Vector3:
	for component_variant in ship.get_component_damage_report().get("components", []) as Array:
		var component := component_variant as Dictionary
		if StringName(component.get("id", &"")) == component_id:
			return component.get("local_position", Vector3.ZERO) as Vector3
	return Vector3.ZERO


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish(game: GameFlow) -> void:
	if is_instance_valid(game):
		game.queue_free()
	await process_frame
	await process_frame
	if _failures.is_empty():
		print("CINDER_BOMBER_FAILED_WING_PAYLOAD_GATE_TEST_OK (%d assertions)" % _assertions)
		quit(0)
	else:
		print("CINDER_BOMBER_FAILED_WING_PAYLOAD_GATE_TEST_FAILED: %s" % "; ".join(_failures))
		quit(1)
