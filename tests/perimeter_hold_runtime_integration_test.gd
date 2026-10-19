extends SceneTree

## Focused staged runtime qualification. Production actors, resolver, collider
## and sole Damageable run live; manually supplied physics deltas bound the
## 90-second objective checks. This is not an ordinary native input journey.
const PICKET := preload("res://scenes/ships/standoff_picket_opponent.tscn")
const SCATTER := preload("res://scenes/ships/flanking_skirmisher_opponent.tscn")
const PRESS := preload("res://scenes/ships/press_repeater_opponent.tscn")
const ASSET := preload("res://scenes/activities/station_defense_perimeter_asset.tscn")
var _failures: Array[String] = []
var _assertions := 0


func _init() -> void:
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
		_check(bool(hit.get("damaged", false)) and actor.is_destroyed(), "real resolver damage destroys %s" % actor.name)
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
