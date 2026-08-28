extends SceneTree

## Focused production proof that the nested Cinder interceptor consumes its
## authored handling resource and routes held primary fire through GameFlow's
## shared combat authority. This deliberately exercises the physical HeroShip
## command gate rather than submitting a resolver request directly.

const MAIN_SCENE := preload("res://scenes/main.tscn")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	root.add_child(game)
	var roster := await _await_settled_roster(game)
	var cinder: CinderLightInterceptor
	for candidate: HeroShip in game.get_flyable_ships():
		if candidate.get_ship_id() == GameFlow.CINDER_LIGHT_INTERCEPTOR_SHIP_ID:
			cinder = candidate as CinderLightInterceptor
			break
	_check(cinder != null, "production Main exposes the nested Cinder light interceptor")
	if cinder == null:
		await _finish(game)
		return
	_check(
		game.call(
			&"_find_flyable_ship_by_id",
			GameFlow.CINDER_LIGHT_INTERCEPTOR_LEGACY_SHIP_ID,
		) == cinder,
		"the former hyphenated save identity migrates to the canonical live craft",
	)

	var definition := cinder.get_ship_definition()
	var weapon := cinder.get_weapon_definition()
	var authority := game.get_combat_authority() as LiveCombatAuthority
	_check(
		bool(roster.get("valid", false))
		and int(roster.get("expected_player_source_count", 0)) == 8
		and int(roster.get("expected_source_count", 0)) == 12
		and int(roster.get("actual_source_count", 0)) == 12,
		"production combat settles with Cinder included in the exact eight-player roster",
	)
	_check(
		definition != null
		and definition.is_definition_valid()
		and definition.get_ship_id() == GameFlow.CINDER_LIGHT_INTERCEPTOR_SHIP_ID
		and is_equal_approx(cinder.maximum_speed, definition.maximum_speed)
		and is_equal_approx(cinder.weapon_cooldown, definition.weapon_cooldown)
		and is_equal_approx(cinder.maximum_hull, definition.maximum_hull),
		"the live craft consumes its authored 102 m/s, 0.28 s, and 110-hull definition",
	)
	_check(
		weapon != null
		and weapon.is_definition_valid()
		and weapon.weapon_id == GameFlow.CINDER_LIGHT_INTERCEPTOR_WEAPON_ID
		and is_equal_approx(
			weapon.cadence_shots_per_second, 1.0 / cinder.weapon_cooldown
		),
		"the rapid-repeater definition matches the live HeroShip cadence gate",
	)
	_check(
		authority != null
		and authority.get_source_id(cinder) == 1108
		and authority.get_weapon_profile(
			cinder, GameFlow.CINDER_LIGHT_INTERCEPTOR_WEAPON_ID
		) == {"range": 320.0, "damage": 18.0, "origin_tolerance": 24.0},
		"source 1108 owns the exact live 320 m / 18 damage repeater envelope",
	)

	for craft: HeroShip in game.get_flyable_ships():
		craft.set_piloted(craft == cinder)
	game.active_ship = cinder
	game.phase = GameFlow.Phase.FREE_FLIGHT
	var authored_engine_start_time := cinder.engine_start_time
	cinder.engine_start_time = 0.01
	cinder.request_engine_start()
	for _engine_frame in 12:
		await physics_frame
		if StringName(cinder.get_telemetry().get("engine_state", &"")) == &"ONLINE":
			break
	_check(
		StringName(cinder.get_telemetry().get("engine_state", &"")) == &"ONLINE",
		"the production interceptor reaches its ordinary online weapon prerequisite",
	)

	var emitted_count := [0]
	cinder.projectile_fired.connect(
		func(_origin: Vector3, _direction: Vector3) -> void: emitted_count[0] += 1,
		CONNECT_ONE_SHOT,
	)
	Input.action_press(&"fire")
	await physics_frame
	Input.action_release(&"fire")
	var fire_telemetry := cinder.get_telemetry()
	var result := game.get_last_player_shot_result()
	var request := result.get("request") as ShotRequest
	_check(
		emitted_count[0] == 1
		and bool(result.get("accepted", false))
		and bool(result.get("resolved", false))
		and result.get("source_entity") == cinder
		and request != null
		and request.weapon_id == GameFlow.CINDER_LIGHT_INTERCEPTOR_WEAPON_ID,
		"held primary fire emits once and resolves through Cinder's own production weapon ID",
	)
	_check(
		float(fire_telemetry.get("weapon_heat", 0.0)) > 0.0
		and float(fire_telemetry.get("weapon_cooldown_remaining", 0.0)) > 0.0
		and StringName(fire_telemetry.get("weapon_status", &"")) == &"cooldown"
		and "WPN CYCLING" in String(cinder.call(&"_get_cockpit_system_readout").get("text", "")),
		"the same shot drives visible heat, cooldown, and cockpit cycling feedback",
	)

	cinder.engine_start_time = authored_engine_start_time
	cinder.set_piloted(false)
	await _finish(game)


func _await_settled_roster(game: GameFlow) -> Dictionary:
	var audit: Dictionary = {}
	for _attempt in 120:
		audit = game.get_live_combat_source_roster_audit()
		if bool(audit.get("valid", false)) \
				and int(audit.get("expected_player_source_count", 0)) == 8 \
				and int(audit.get("expected_source_count", 0)) == 12 \
				and int(audit.get("actual_source_count", 0)) == 12:
			return audit
		await process_frame
	return audit


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish(game: Node) -> void:
	Input.action_release(&"fire")
	if is_instance_valid(game):
		game.queue_free()
	for _cleanup_frame in 10:
		await process_frame
	if _failures.is_empty():
		print(
			"CINDER_LIGHT_INTERCEPTOR_COMBAT_PRODUCTION_TEST_OK: %d assertions"
				% _assertions
		)
		quit(0)
	else:
		print(
			"CINDER_LIGHT_INTERCEPTOR_COMBAT_PRODUCTION_TEST_FAILED: %s"
				% "; ".join(_failures)
		)
		quit(1)
