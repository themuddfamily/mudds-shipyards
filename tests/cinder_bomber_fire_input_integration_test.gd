extends SceneTree

## Production proof that the remappable `fire` action keeps its held HeroShip
## meaning while its rising edge reaches GameFlow's Cinder payload authority.

const MAIN_SCENE := preload("res://scenes/main.tscn")

var _assertions := 0
var _failures := PackedStringArray()


class FakeInputProvider:
	extends RefCounted

	var strengths: Dictionary = {}
	var pressed: Dictionary = {}

	func get_action_strength(action: StringName) -> float:
		return float(strengths.get(action, 0.0))

	func is_action_pressed(action: StringName) -> bool:
		return bool(pressed.get(action, false))

	func set_pressed(action: StringName, value: bool) -> void:
		pressed[action] = value
		strengths[action] = 1.0 if value else 0.0


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
	var provider := FakeInputProvider.new()
	var source := bomber.get_command_source() as LocalShipInputSource
	source.set_input_provider(provider)
	game.call(&"_reset_lifecycle_command_cursor")

	var inherited_shots := [0]
	bomber.projectile_fired.connect(
		func(_origin: Vector3, _direction: Vector3) -> void:
			inherited_shots[0] += 1
	)
	bomber.call(&"_physics_process", 1.0 / 60.0)
	provider.set_pressed(&"fire", true)
	bomber.call(&"_physics_process", 1.0 / 60.0)
	var pressed_command := bomber.get_last_ship_command()
	bomber.call(&"_physics_process", 1.0 / 60.0)
	var held_command := bomber.get_last_ship_command()
	_check(
		pressed_command.fire and pressed_command.fire_pressed
		and held_command.fire and not held_command.fire_pressed,
		"the remapped physical action carries one rising edge beside continuous held fire",
	)
	_check(
		inherited_shots[0] == 0
		and is_zero_approx(float(bomber.get("_weapon_timer")))
		and is_zero_approx(float(bomber.get("_weapon_heat"))),
		"Cinder suppresses inherited cannon emission, cadence, and heat unconditionally",
	)

	# The edge command has already been overwritten by a newer held snapshot, but
	# the source-owned FIFO must still converge and release it exactly once.
	game.call(&"_consume_active_ship_command_edges")
	var physical_release := game.get_bomber_payload_loop_snapshot()
	var authority_after_physical := bomber.get_payload_authority_snapshot()
	_check(
		bool(physical_release.get("active", false))
		and int(physical_release.get("request_sequence", 0)) == 1
		and (physical_release.get("projectiles", []) as Array).size() == 1
		and int(authority_after_physical.get("ammunition_remaining", 0)) == 3,
		"the delayed physical edge converges GameFlow authority and releases one payload",
	)
	game.call(&"_consume_active_ship_command_edges")
	_check(
		int(game.get_bomber_payload_loop_snapshot().get("request_sequence", 0)) == 1,
		"holding fire and polling an empty FIFO cannot release a second payload",
	)

	provider.set_pressed(&"fire", false)
	bomber.call(&"_physics_process", 1.0 / 60.0)
	game.call(&"_consume_active_ship_command_edges")
	bomber.advance_payload_cooldown(1.0)
	var synthetic_fire := InputEventAction.new()
	synthetic_fire.action = &"fire"
	synthetic_fire.pressed = true
	game.call(&"_unhandled_input", synthetic_fire)
	var synthetic_release := game.get_bomber_payload_loop_snapshot()
	_check(
		int(synthetic_release.get("request_sequence", 0)) == 2
		and (synthetic_release.get("projectiles", []) as Array).size() == 2
		and int(bomber.get_payload_authority_snapshot().get("ammunition_remaining", 0)) == 2,
		"synthetic InputEventAction fire enters the same ordered production release path",
	)

	# A client may sample the same edge but must not converge, mutate ammunition,
	# or manufacture another authoritative projectile.
	bomber.advance_payload_cooldown(1.0)
	game._network_session_mode = &"client"
	game.call(&"_unhandled_input", synthetic_fire)
	var client_result := game.get_bomber_payload_loop_snapshot()
	_check(
		int(client_result.get("request_sequence", 0)) == 2
		and (client_result.get("projectiles", []) as Array).size() == 2
		and int(bomber.get_payload_authority_snapshot().get("ammunition_remaining", 0)) == 2
		and (client_result.get("last_result", {}) as Dictionary).get("reason", &"")
			== &"client_projectile_authority_forbidden",
		"client fire fails closed before payload authority can admit a release",
	)

	# Even a direct legacy call remains unable to reach the inherited pulse path.
	bomber.call(&"_fire_weapon")
	_check(
		inherited_shots[0] == 0
		and is_zero_approx(float(bomber.get("_weapon_timer")))
		and is_zero_approx(float(bomber.get("_weapon_heat"))),
		"a direct legacy fire call cannot bypass Cinder's inherited-cannon suppression",
	)
	await _finish(game)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish(game: Node) -> void:
	if is_instance_valid(game):
		game.queue_free()
	await process_frame
	await physics_frame
	if _failures.is_empty():
		print("CINDER_BOMBER_FIRE_INPUT_INTEGRATION_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		print("CINDER_BOMBER_FIRE_INPUT_INTEGRATION_TEST_FAILED: ", "; ".join(_failures))
		quit(1)
