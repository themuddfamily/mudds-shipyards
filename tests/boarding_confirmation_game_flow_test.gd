extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")

var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	root.add_child(game)
	await process_frame
	await physics_frame
	game.canopy_motion_time = 0.0
	game.boarding_motion_time = 0.0
	game.start_shift()
	await process_frame
	_check(_presented_state(game) == &"approach", "real start_shift reaches the boarding presentation bridge")

	var player := game.player as PlayerController
	var ship := game.ship as HeroShip
	var area := ship.get_node_or_null("ShipBoardingArea") as ShipBoardingArea
	var definition := ship.get_ship_definition()
	var approach_view := (game.get_boarding_confirmation_presentation_report().adapter as Dictionary).view as Dictionary
	_check(
		str(approach_view.message).contains(definition.get_role().to_upper())
		and str(approach_view.message).contains("%.0f M/S BASE" % definition.maximum_speed)
		and str(approach_view.message).contains("MAX HULL %.0f" % definition.maximum_hull),
		"production approach bridge presents the active craft's rated definition facts",
	)
	_check(
		player.begin_boarding(player.global_transform, ship.get_pilot_seat_anchor(), 0.0),
		"production player enters a conflicting seated state for the failure reproduction",
	)
	await process_frame
	game.call(&"_board_ship", ship)
	_check(
		await _wait_until(func() -> bool: return _presented_state(game) == &"rejected", 30),
		"failed production board reaches the rejected bridge state",
	)
	_check(
		area != null and not area.is_reserved() and area.get_reservation_token() == null,
		"failed production board releases the exact player reservation",
	)
	_check(game.phase == GameFlow.Phase.APPROACH_SHIP, "failed production board returns to approach")
	await process_frame
	await process_frame
	_check(_presented_state(game) == &"rejected",
		"idle prompt refresh preserves the readable rejection")
	await create_timer(2.9).timeout
	game.call(&"_present_boarding_confirmation", &"available", ship)
	_check(_presented_state(game) == &"available",
		"the ordinary hatch prompt returns after the refusal reading window")
	var available_view := (game.get_boarding_confirmation_presentation_report().adapter as Dictionary).view as Dictionary
	_check(
		str(available_view.message).contains("PRESS INTERACT TO BOARD")
		and str(available_view.message).contains("MAX HULL %.0f" % definition.maximum_hull),
		"production available card preserves ordinary Interact and rated hull guidance",
	)

	player.force_recovery_to_on_foot(game.world.get_player_spawn())
	await process_frame
	game.call(&"_board_ship", ship)
	_check(
		await _wait_until(func() -> bool: return game.phase == GameFlow.Phase.START_ENGINES, 60),
		"real production board reaches the pilot seat",
	)
	_check(_presented_state(game) == &"seated", "successful production board reaches the seated bridge state")
	_check(
		area.is_reserved() and area.get_reservation_token() == player,
		"successful bridge observation preserves ShipBoardingArea's exact token authority",
	)
	var parent := game.get_parent()
	parent.remove_child(game)
	await process_frame
	_check(not area.is_reserved(), "detached Main retires its boarding reservation")
	parent.add_child(game)
	_check(
		await _wait_until(func() -> bool:
			return area.get_reservation_token() == player, 120),
		"whole-Main re-entry restores the exact retained pilot reservation",
	)
	_check(player.is_seated() and ship.is_piloted(),
		"restoring the reservation preserves the already seated pilot")
	var contender := Node3D.new()
	game.add_child(contender)
	_check(not area.try_reserve(contender) and area.get_reservation_token() == player,
		"a contender cannot replace the restored pilot reservation")

	_check_light_choice_bridge(game)
	_check_bomber_choice_bridge(game)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Input.action_release(&"interact")
	game.queue_free()
	await process_frame
	if _failures.is_empty():
		print("BOARDING_CONFIRMATION_GAME_FLOW_TEST_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _presented_state(game: GameFlow) -> StringName:
	var report := game.get_boarding_confirmation_presentation_report()
	var adapter := report.get("adapter", {}) as Dictionary
	var view := adapter.get("view", {}) as Dictionary
	return StringName(view.get("state", &""))


func _wait_until(predicate: Callable, frame_budget: int) -> bool:
	for _frame in frame_budget:
		if bool(predicate.call()):
			return true
		await process_frame
		await physics_frame
	return bool(predicate.call())


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_failures.append("FAIL: " + message)


func _check_light_choice_bridge(game: GameFlow) -> void:
	var light := game.call(&"_find_flyable_ship_by_id", &"cinder_light_interceptor") as HeroShip
	_check(light != null, "Main supplies the actual registered Light instance for the choice bridge")
	if light == null:
		return
	var light_area := light.get_node_or_null("ShipBoardingArea") as ShipBoardingArea
	_check(light_area != null, "registered Light retains its real boarding area")
	if light_area == null:
		return
	var before := _choice_authority_snapshot(game, light)
	for state in [&"approach", &"available"]:
		game.call(&"_present_boarding_confirmation", state, light)
		var view := _choice_view(game)
		var expected_title := "[>] MOVE TO CINDER LIGHT INTERCEPTOR" if state == &"approach" else "[+] CINDER LIGHT INTERCEPTOR"
		var expected_instruction := "LOOK FOR THE BOARDING PROMPT" if state == &"approach" else "PRESS INTERACT TO BOARD"
		_check(view.state == state and view.title == expected_title
			and view.message == "FAST RESPONSE // HIGH DRAG WHEN COASTING\nLIGHT INTERCEPTOR | 102 M/S BASE | MAX HULL 110\n" + expected_instruction
			and view.get("light_choice_ship_id") == &"cinder_light_interceptor",
			"Main's actual Light %s producer carries registry trade-off and rated facts" % state)
		_check(not bool(view.reservation_authority) and not bool(view.transition_authority), "Light choice remains presentation-only")
		if state == &"available":
			_check(str(view.message).contains("PRESS INTERACT TO BOARD"), "Light keeps the ordinary Interact instruction")
	_check(_choice_authority_snapshot(game, light) == before, "Light choice reads preserve full resource, component, weapon, seat, reservation and save snapshots")
	# Existing successful boarding above supplies a genuinely seated player.
	# Set only the observed busy fixture for the bridge's transition states;
	# this is a producer regression, not an ordinary Light access journey.
	_check(light_area.try_reserve(game.player), "transition fixture holds a real Light reservation")
	game.call(&"_remember_boarding_confirmation_reservation", light_area, game.player, game.get("_transition_generation"))
	var was_busy: bool = game.get("_transition_busy")
	for state in [&"reserved", &"boarding", &"seated", &"disembarking", &"rejected"]:
		game.set("_transition_busy", state in [&"boarding", &"disembarking"])
		var state_before := _choice_authority_snapshot(game, light)
		game.call(&"_present_boarding_confirmation", state, light, &"seat_occupied" if state == &"rejected" else &"")
		var view := _choice_view(game)
		_check(view.state == state and not (str(view.title) + str(view.message)).contains("FAST RESPONSE")
			and not str(view.message).contains("MAX HULL"), "Light %s preserves the exclusive transition/refusal reading" % state)
		_check(_choice_authority_snapshot(game, light) == state_before, "Light %s presentation cannot mutate gameplay or saved state" % state)
	game.set("_transition_busy", was_busy)
	light_area.release_reservation(game.player)
	game.call(&"_clear_boarding_confirmation_reservation")
	for craft in game.ships:
		if craft == light:
			continue
		var craft_before := _choice_authority_snapshot(game, craft)
		for state in [&"approach", &"available"]:
			game.call(&"_present_boarding_confirmation", state, craft)
			var view := _choice_view(game)
			_check(view.state == state and not (str(view.title) + str(view.message)).contains("FAST RESPONSE")
				and str(view.message).contains("MAX HULL"), "%s %s has only its existing rated facts" % [craft.get_ship_id(), state])
		_check(_choice_authority_snapshot(game, craft) == craft_before, "unrelated craft choice preserves all gameplay and save facts")


func _check_bomber_choice_bridge(game: GameFlow) -> void:
	var bomber := game.call(&"_find_flyable_ship_by_id", &"cinder_long_range_bomber") as HeroShip
	_check(bomber != null, "Main supplies the actual registered Bomber instance for the choice bridge")
	if bomber == null:
		return
	var bomber_area := bomber.get_node_or_null("ShipBoardingArea") as ShipBoardingArea
	_check(bomber_area != null, "registered Bomber retains its real boarding area")
	if bomber_area == null:
		return
	var before := _choice_authority_snapshot(game, bomber)
	for state in [&"approach", &"available"]:
		game.call(&"_present_boarding_confirmation", state, bomber)
		var view := _choice_view(game)
		var expected_title := "[>] MOVE TO CINDER LONG-RANGE BOMBER" if state == &"approach" else "[+] CINDER LONG-RANGE BOMBER"
		var expected_instruction := "LOOK FOR THE BOARDING PROMPT" if state == &"approach" else "PRESS INTERACT TO BOARD"
		_check(view.state == state and view.title == expected_title
			and view.message == "TOUGH HULL & BRAKES // SLOW TURN / FIRE\nLONG-RANGE BOMBER | 72 M/S BASE | MAX HULL 240\n" + expected_instruction
			and view.get("bomber_choice_ship_id") == &"cinder_long_range_bomber",
			"Main's actual Bomber %s producer carries registry trade-off and rated facts" % state)
		_check(not bool(view.reservation_authority) and not bool(view.transition_authority), "Bomber choice remains presentation-only")
		if state == &"available":
			_check(str(view.message).contains("PRESS INTERACT TO BOARD"), "Bomber keeps the ordinary Interact instruction")
	_check(_choice_authority_snapshot(game, bomber) == before, "Bomber choice reads preserve full resource, component, weapon, seat, reservation and save snapshots")
	# Existing successful boarding above supplies a genuinely seated player.
	# Set only the observed busy fixture for the bridge's transition states;
	# this is a producer regression, not an ordinary Bomber access journey.
	_check(bomber_area.try_reserve(game.player), "transition fixture holds a real Bomber reservation")
	game.call(&"_remember_boarding_confirmation_reservation", bomber_area, game.player, game.get("_transition_generation"))
	var was_busy: bool = game.get("_transition_busy")
	for state in [&"reserved", &"boarding", &"seated", &"disembarking", &"rejected"]:
		game.set("_transition_busy", state in [&"boarding", &"disembarking"])
		var state_before := _choice_authority_snapshot(game, bomber)
		game.call(&"_present_boarding_confirmation", state, bomber, &"seat_occupied" if state == &"rejected" else &"")
		var view := _choice_view(game)
		_check(view.state == state and not (str(view.title) + str(view.message)).contains("TOUGH HULL")
			and not str(view.message).contains("MAX HULL"), "Bomber %s preserves the exclusive transition/refusal reading" % state)
		_check(_choice_authority_snapshot(game, bomber) == state_before, "Bomber %s presentation cannot mutate gameplay or saved state" % state)
	game.set("_transition_busy", was_busy)
	bomber_area.release_reservation(game.player)
	game.call(&"_clear_boarding_confirmation_reservation")

func _choice_view(game: GameFlow) -> Dictionary:
	return (game.get_boarding_confirmation_presentation_report().adapter as Dictionary).view as Dictionary


func _choice_authority_snapshot(game: GameFlow, craft: HeroShip) -> Dictionary:
	var definition_properties := {}
	var definition := craft.get_ship_definition()
	for property in definition.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_STORAGE:
			definition_properties[property.name] = definition.get(property.name)
	var store := game.get("_runtime_settings_user_data_store") as UserDataStore
	var areas: Array = []
	for candidate in game.ships:
		var area := candidate.get_node_or_null("ShipBoardingArea") as ShipBoardingArea
		areas.append({"id": candidate.get_instance_id(), "piloted": candidate.is_piloted(),
			"reserved": area.is_reserved() if area != null else false,
			"token": area.get_reservation_token() if area != null else null})
	var component := craft.get_component_damage()
	return {
		"definition_id": definition.get_instance_id(), "definition": definition_properties,
		"flight": definition.get_flight_profile(), "systems": definition.get_systems_profile(),
		"components": component.get_ledger_snapshot() if component != null else {},
		"component_revision": component.get_revision() if component != null else -1,
		"weapon": craft.get_weapon_fire_status(), "weapon_profiles": game.call(&"_get_player_weapon_profiles", craft),
		"hull": craft.get("_hull"), "engine": craft.get("_engine_state"),
		"velocity": craft.velocity, "transform": craft.global_transform,
		"areas": areas, "player_seated": game.player.is_seated(),
		"player_transform": game.player.global_transform, "player_parent": game.player.get_parent(),
		"phase": game.phase, "active_ship": game.active_ship,
		"generation": game.get("_transition_generation"), "busy": game.get("_transition_busy"),
		"save": store.get_snapshot() if store != null else {},
		"save_generation": store.get_generation() if store != null else -1,
		"save_commit": store.get_commit_metadata() if store != null else {},
	}.duplicate(true)
