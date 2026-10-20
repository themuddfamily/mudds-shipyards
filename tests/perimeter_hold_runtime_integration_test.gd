extends SceneTree

## Focused staged runtime qualification. Production actors, resolver, collider
## and sole Damageable run live; manually supplied physics deltas bound the
## 90-second objective checks. This is not an ordinary native input journey.
# Reuse the existing isolated persistence backend; loading its Script never
# instantiates another Main or runs that suite's lifecycle.
const MainRouteFixture := preload("res://tests/heavy_breach_game_flow_production_route_test.gd")
const MAIN_SCENE := MainRouteFixture.MAIN_SCENE
const Store := MainRouteFixture.Store
const FRAME_BUDGET := MainRouteFixture.FRAME_BUDGET
const PICKET := preload("res://scenes/ships/standoff_picket_opponent.tscn")
const SCATTER := preload("res://scenes/ships/flanking_skirmisher_opponent.tscn")
const PRESS := preload("res://scenes/ships/press_repeater_opponent.tscn")
const ASSET := preload("res://scenes/activities/station_defense_perimeter_asset.tscn")
var _failures: Array[String] = []
var _assertions := 0


func _init() -> void:
	if "--production-case" in OS.get_cmdline_user_args():
		call_deferred(&"_run_production_case")
	else:
		call_deferred(&"_run")


func _run() -> void:
	var fixture := await _fixture()
	var director: EncounterScenarioDirector = fixture.director
	var asset: StationDefensePerimeterAsset = fixture.asset
	var damageable := asset.get_damageable_component()
	var health_owner_id := damageable.get_instance_id()
	_check(director.begin_perimeter_hold(fixture.target, asset), "Hold launches its dedicated live roster")
	_check(director.get_roster().size() == 3 and fixture.scatter.get_wing_role() == WingCoordinator.ROLE_FLANKER,
		"the three live opponents include the existing scatter's real rear-arc flanker role")
	_check(fixture.picket.is_combat_source_registered() and fixture.scatter.is_combat_source_registered()
		and fixture.press.is_combat_source_registered(), "every actor uses the one live resolver")
	fixture.press.global_transform = Transform3D(Basis.IDENTITY, Vector3(0, 0, 30))
	await physics_frame
	fixture.press.call(&"_fire_at_target", asset.global_position)
	_check(is_equal_approx(damageable.get_health(), 231.0)
		and bool(fixture.press.get_last_shot_result().get("damaged", false)),
		"the dedicated press fires real resolver damage into the asset's sole Damageable")
	director.abort()
	_assert_clean(fixture, "explicit abort")
	_check(asset.renew(asset.handle_generation).accepted and damageable.get_instance_id() == health_owner_id
		and is_equal_approx(damageable.get_health(), 240.0), "renewal resets the same authoritative health child")
	var generation := director.get_scenario_generation()
	_check(director.begin_perimeter_hold(fixture.target, asset)
		and director.get_scenario_generation() > generation, "the same actors can enter a new director generation")
	_check(not director.is_picket_dispatch_authorized(fixture.picket, generation), "old picket fire grants cannot cross generation reuse")
	# Put the registered bounded test weapon beside each live craft. All hull
	# destruction below passes through physical ray resolution and its adapter.
	for actor: Node3D in [fixture.picket, fixture.scatter, fixture.press]:
		fixture.gun.global_position = actor.global_position + Vector3(0, 0, 24)
		await physics_frame
		var hit := fixture.authority.submit_hitscan(fixture.gun, &"hull_clear", fixture.gun.global_position,
			(actor.global_position - fixture.gun.global_position).normalized()) as Dictionary
		_check(bool(hit.get("damaged", false)) and actor.get_health() <= 0.0 and not actor.is_active(), "real resolver damage destroys %s" % actor.name)
	director.call(&"_physics_process", 89.99)
	_check(director.is_running() and director.get_outcome() == &"pending"
		and director.get_audit_report().active_roster == 0 and director.get_validation_errors().is_empty(),
		"destroying every attacker leaves a valid timed defense pending before 90 seconds")
	director.call(&"_physics_process", 0.02)
	_check(director.get_outcome() == &"cleared", "a healthy core clears after 90 accumulated physics seconds")
	_assert_clean(fixture, "timed clear")

	_check(asset.renew(asset.handle_generation).accepted and director.begin_perimeter_hold(fixture.target, asset),
		"a subsequent loss case renews the original asset")
	fixture.gun.global_position = asset.global_position + Vector3(0, 0, 20)
	await physics_frame
	director.set("_elapsed", 90.0)
	var boundary := fixture.authority.submit_hitscan(fixture.gun, &"integrity_boundary", fixture.gun.global_position,
		(asset.global_position - fixture.gun.global_position).normalized()) as Dictionary
	_check(bool(boundary.get("damaged", false)) and is_equal_approx(damageable.get_health(), 84.0)
		and director.get_outcome() == &"lost", "actual integrity at exactly 35% loses before simultaneous 90-second completion")
	_assert_clean(fixture, "integrity loss on the damage frame")
	var retained_health := damageable.get_health()
	fixture.press.call(&"_fire_at_target", asset.global_position)
	_check(is_equal_approx(damageable.get_health(), retained_health), "a committed shot cannot dispatch after the concluding call")

	asset.renew(asset.handle_generation)
	_check(director.begin_perimeter_hold(fixture.target, asset), "player-loss case starts")
	fixture.host.remove_child(fixture.target)
	_check(director.get_outcome() == &"aborted", "target tree exit synchronously aborts Hold")
	_assert_clean(fixture, "player removal")
	fixture.host.add_child(fixture.target)
	asset.renew(asset.handle_generation)
	_check(director.begin_perimeter_hold(fixture.target, asset), "disengagement case starts")
	fixture.target.global_position = Vector3(10000, 0, 0)
	director.call(&"_physics_process", director.disengage_grace)
	_check(director.get_outcome() == &"withdrawn", "flying clear of origin and every attacker withdraws Hold")
	_assert_clean(fixture, "disengagement")
	fixture.target.global_position = Vector3.ZERO
	asset.renew(asset.handle_generation)
	_check(director.begin_perimeter_hold(fixture.target, asset), "asset removal case starts")
	fixture.host.remove_child(asset)
	_check(director.get_outcome() == &"lost", "asset tree exit synchronously loses Hold")
	_assert_clean(fixture, "asset removal without an intervening frame")
	fixture.host.add_child(asset)
	asset.renew(asset.handle_generation)
	_check(director.begin_perimeter_hold(fixture.target, asset), "teardown case starts")
	fixture.host.remove_child(director)
	_check(director.get_outcome() == &"withdrawn", "director teardown withdraws its live roster")
	_assert_clean(fixture, "director teardown")
	director.free()
	fixture.host.queue_free()
	await process_frame
	await process_frame
	if _failures.is_empty():
		print("PERIMETER_HOLD_RUNTIME_INTEGRATION_TEST_OK (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _fixture() -> Dictionary:
	var host := Node3D.new()
	root.add_child(host)
	var authority := LiveCombatAuthority.new()
	authority.name = "CombatAuthority"
	host.add_child(authority)
	var target := Node3D.new()
	host.add_child(target)
	var asset := ASSET.instantiate() as StationDefensePerimeterAsset
	host.add_child(asset)
	var director := EncounterScenarioDirector.new()
	director.name = "EncounterScenarios"
	director.hud_path = NodePath("../AbsentHUD")
	host.add_child(director)
	director.set_physics_process(false)
	var actors: Array[Node3D] = []
	for scene: PackedScene in [PICKET, SCATTER, PRESS]:
		var actor := scene.instantiate() as Node3D
		actor.name = ["PerimeterPicket", "PerimeterScatter", "PerimeterPress"][actors.size()]
		actor.set("source_id", 2131 + actors.size())
		actor.set("pulse_presentation_path", NodePath("../AbsentPulse"))
		actor.set("combat_audio_path", NodePath("../AbsentAudio"))
		actor.set("hud_path", NodePath("../AbsentHUD"))
		if actor is StandoffPicketOpponent:
			actor.set("defender_path", NodePath("../AbsentDefender"))
		host.add_child(actor)
		actor.set_physics_process(false)
		actors.append(actor)
	actors[0].set("_siege_lance_audio_binding", null)
	var gun := Node3D.new()
	host.add_child(gun)
	_check(authority.register_source(gun, 9011, &"test_pilot", {
		&"hull_clear": {"range": 50.0, "damage": 200.0, "origin_tolerance": 2.0},
		&"integrity_boundary": {"range": 50.0, "damage": 156.0, "origin_tolerance": 2.0},
	}), "the test's bounded live weapon is registered under its own identity")
	await physics_frame
	return {"host": host, "authority": authority, "target": target, "asset": asset,
		"director": director, "picket": actors[0], "scatter": actors[1], "press": actors[2], "gun": gun}


func _assert_clean(fixture: Dictionary, reason: String) -> void:
	_check(fixture.director.get_roster().is_empty(), "%s clears the retained roster" % reason)
	for actor: Node3D in [fixture.picket, fixture.scatter, fixture.press]:
		_check(not actor.is_active() and not actor.is_combat_source_registered()
			and not fixture.director.is_fire_authorized(actor), "%s withdraws %s and its source/fire grants" % [reason, actor.name])


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)


## Separately budgeted actual-Main case. The default staged checks and this
## embodied route each retain their own unchanged 90-second external cap.
func _run_production_case() -> void:
	var game := await _verify_perimeter_board_departure()
	await _clean_up(game)
	if _failures.is_empty():
		print("PERIMETER_HOLD_PRODUCTION_ROUTE_TEST_OK (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


## This staged production-route fixture selects the fourth posted contract,
## then uses the same live E sensor, Arrow seat handoff and physical thrust
## departure as the original Breach fixture. Native ordinary input stays open.
func _verify_perimeter_board_departure() -> GameFlow:
	var game := MAIN_SCENE.instantiate() as GameFlow
	game.configure_runtime_settings_persistence(Store.new("memory://hold-route.json", MainRouteFixture.MemoryFilesystem.new()))
	root.add_child(game)
	await process_frame
	await physics_frame
	game.canopy_motion_time = 0.0
	game.boarding_motion_time = 0.04
	game.start_shift()
	var world := game.world as ShipyardWorld
	var board := world.get_heavy_breach_activity_board() as HeavyBreachActivityBoard
	var arrow := game.get_node(^"ArrowReconShip") as HeroShip
	var director := game.get_node(^"EncounterScenarios") as EncounterScenarioDirector
	var hud := game.hud as GameHUD
	board.set("_offered_index", 3)
	board.call(&"_refresh_board_label")
	var player := game.player as PlayerController
	player.teleport_to(Transform3D(Basis.IDENTITY, board.global_position + Vector3(0, 0, 2)))
	_check(await _wait_until(func() -> bool: return game.station_interaction_candidate == board),
		"the physical sensor discovers the fourth posted Hold contract")
	game.set("_network_session_mode", &"client")
	_check(not bool(game.call(&"_arm_heavy_breach_sortie", board)) and not board.is_sortie_armed(),
		"network clients cannot arm local Perimeter Hold combat")
	game.set("_network_session_mode", &"")
	await _press_action(&"interact", 1)
	_check(board.is_sortie_armed() and not director.is_running()
		and "PERIMETER HOLD" in str(hud.get_activity_objective_report().text),
		"physical E arms Hold on foot and presents its dedicated title before combat")
	game.set("_network_session_mode", &"client")
	var refused := board.launch_armed_sortie(arrow, int(board.get_snapshot().sortie_generation))
	_check(not refused.accepted and board.is_sortie_armed() and not director.is_running(),
		"a retained Hold admission cannot launch duplicate local combat on a network client")
	game.set("_network_session_mode", &"")
	player.teleport_to(Transform3D(Basis.IDENTITY, arrow.get_boarding_position() + Vector3(0, 0.05, 0)))
	_check(await _wait_until(func() -> bool: return game.boarding_candidate == arrow),
		"the Hold pilot physically discovers Arrow's boarding area")
	await _press_action(&"interact", 1)
	_check(await _wait_until(func() -> bool: return game.phase == GameFlow.Phase.START_ENGINES),
		"Hold retains the complete production craft boarding handoff")
	_check(board.is_sortie_armed() and not director.is_running(),
		"boarding alone cannot consume Hold's physical departure requirement")
	Input.action_press(&"move_forward")
	var launched := await _wait_until(func() -> bool:
		return (game.phase == GameFlow.Phase.FREE_FLIGHT and director.is_running()
			and director.get_active_scenario() == EncounterScenarioDirector.SCENARIO_PERIMETER_HOLD))
	Input.action_release(&"move_forward")
	_check(launched and director.get_roster().size() == 3 and not board.is_sortie_armed(),
		"real berth departure launches the three-contact Hold in normal FREE_FLIGHT")
	await physics_frame
	await process_frame
	var text := str(hud.get_activity_objective_report().text)
	_check("PERIMETER HOLD" in text and "REMAINING / 90s" in text and "INTEGRITY 100%" in text,
		"the production activity HUD shows Hold's countdown and measured live integrity")
	_check(bool(game.get_live_combat_source_roster_audit().valid),
		"the normal production source census includes all three distinct Hold registrations")
	var asset := world.get_perimeter_hold_asset()
	director.set("_elapsed", 90.0)
	director.call(&"_physics_process", 0.0)
	for _frame in 3:
		await physics_frame
		await process_frame
	_check(director.get_outcome() == &"cleared" and not "Defend the protected core" in str(hud.get("_objective_source_text"))
		and (hud.get("_objective_kicker") as Label).text != "PERIMETER HOLD",
		"a timed Hold clear restores the primary free-flight objective")
	_check(int(game.get_activity_reward_report().authority.record.total_receipts) == 0,
		"a Hold clear produces no saved Breach or Torpedo reward")
	asset.renew(asset.handle_generation)
	_check(director.begin_perimeter_hold(arrow, asset), "phase withdrawal case reuses the same production actors")
	game.phase = GameFlow.Phase.RETURN_TO_YARD
	_check(director.get_outcome() == &"withdrawn", "leaving FREE_FLIGHT concludes Hold inside the phase assignment")
	for actor_path: NodePath in [^"PerimeterPicket", ^"PerimeterScatter", ^"PerimeterPress"]:
		var actor := game.get_node(actor_path)
		_check(not actor.is_active() and not actor.is_combat_source_registered(),
			"phase assignment synchronously withdraws %s and its source" % actor.name)
	game.phase = GameFlow.Phase.FREE_FLIGHT
	asset.renew(asset.handle_generation)
	_check(director.begin_perimeter_hold(arrow, asset), "network withdrawal case starts in solo flight")
	game.set("_network_session_mode", &"client")
	game.call(&"_withdraw_perimeter_hold_for_network")
	_check(director.get_outcome() == &"withdrawn" and director.get_roster().is_empty(),
		"adopting network authority synchronously withdraws local Hold combat")
	game.set("_network_session_mode", &"")
	return game


func _wait_until(predicate: Callable) -> bool:
	for _frame in FRAME_BUDGET:
		if bool(predicate.call()):
			return true
		await physics_frame
		await process_frame
	return bool(predicate.call())


func _press_action(action: StringName, physics_ticks: int) -> void:
	Input.action_press(action)
	for _tick in maxi(physics_ticks, 1):
		await physics_frame
	Input.action_release(action)
	await physics_frame
	await process_frame


func _clean_up(game: GameFlow) -> void:
	Input.action_release(&"interact")
	Input.action_release(&"move_forward")
	if is_instance_valid(game) and is_instance_valid(game.hud):
		game.hud.set_paused(false)
	if is_instance_valid(game):
		game.queue_free()
	for _frame in 3:
		await process_frame
