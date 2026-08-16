extends SceneTree

## Locks the encounter-authority coupling that makes GameFlow's two ungated
## combat handlers safe.
##
## `GameFlow._on_opponent_projectile_fired()` reads no coordinator gate: it
## submits authoritative damage for every `RangeOpponent.projectile_fired`
## emission it receives. That is only sound because the emitter itself is the
## gate. `RangeOpponent._fire_at_target()` refuses unless `_active` is true, and
## `_active` is owned end to end by the coordinator's encounter lifecycle:
##
##   * `opponent.activate()` is reached from exactly one place,
##     `_begin_interceptor_engagement()`, which sets
##     `Phase.INTERCEPTOR_ENGAGEMENT` immediately before it;
##   * the encounter has exactly two exits, and both clear `_active`
##     synchronously, inside the same call that ends the phase --
##     `_destroy_interceptor()` for the defender's own death, and
##     `_recover_from_destroyed_ship()` for the pilot's.
##
## `GameFlow._on_target_destroyed()` fails closed outside
## `Phase.LAUNCH`/`Phase.TARGET_PRACTICE` and has no fallback, so a dropped
## authorization would be permanent -- `authorize_target_destruction()` is
## one-shot. That drop stays unreachable only while the two facts asserted below
## hold: player fire is safed in every phase that the gate rejects while a drone
## is live, and the interceptor engagement (the first phase in which player fire
## is live but the target gate is shut) cannot begin until every drone is
## already destroyed and counted.
##
## Widening either weapon authorization, or moving either deactivation off the
## phase-ending call, reopens a real damage window. This test is the tripwire.

const OPPONENT_ARENA_OFFSET := Vector3(0.0, 0.0, 60.0)
const ARENA_ORIGIN := Vector3(600.0, 90.0, -900.0)
const DRONE_ARENA_ORIGIN := Vector3(900.0, 120.0, -1200.0)
const POST_EXIT_PHYSICS_FRAMES := 320
const LIVE_FIRE_PHYSICS_FRAMES := 320

var _failures: Array[String] = []
var _game: GameFlow
var _opponent: CharacterBody3D
var _hero: HeroShip
var _emissions: Array[Dictionary] = []
var _opponent_active_at_destroyed_signal := true


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		_fail("main scene loads for the encounter authority gate test")
		_finish()
		return
	_game = packed.instantiate() as GameFlow
	root.add_child(_game)
	await process_frame
	await physics_frame

	var world := _game.get_node("ShipyardWorld") as Node3D
	_hero = _game.get_node("TorrentInterceptor") as HeroShip
	_opponent = _game.get_node("RangeOpponent") as CharacterBody3D
	var picket := _game.get_node_or_null("StandoffPicket")
	if picket != null:
		# The picket resolves its own lance directly on the shared resolver and is
		# dispatched by its own escort timer. Hold it dormant so the assertions
		# below observe only the defender seam under test.
		picket.set("escort_enabled", false)
		picket.call("deactivate")

	# Record the coordinator state at every `projectile_fired` emission, ahead of
	# GameFlow's own handler, so the sample is taken before the shot can change
	# the phase it is being judged against.
	var flow_handler := Callable(_game, "_on_opponent_projectile_fired")
	_check(
		_opponent.projectile_fired.is_connected(flow_handler),
		"the production coordinator owns the defender's ungated fire handler"
	)
	_opponent.projectile_fired.disconnect(flow_handler)
	_opponent.projectile_fired.connect(_record_emission)
	_opponent.projectile_fired.connect(flow_handler)
	_opponent.destroyed.connect(_record_opponent_destroyed)

	# ------------------------------------------------------------------ boot --
	_check(
		not bool(_opponent.call("is_active")),
		"the defender boots dormant, so the ungated fire handler is unreachable at rest"
	)
	_check(
		_game.total_targets == int(world.call("get_target_count")) and _game.total_targets > 0,
		"the coordinator's target quota matches the world's generated drone roster"
	)
	_check(
		_game.destroyed_targets == 0 and int(world.call("get_destroyed_target_count")) == 0,
		"no drone destruction is credited before the sortie begins"
	)

	# --------------------------------------- engagement entry needs a clear range --
	# The first phase in which player fire is live while `_on_target_destroyed()`
	# is shut is INTERCEPTOR_ENGAGEMENT. It cannot be entered with a live drone.
	_hero.global_transform = Transform3D(Basis.IDENTITY, ARENA_ORIGIN)
	_game.active_ship = _hero
	_game.set("_piloting", true)
	_game.set("_sandbox_sortie", false)
	_game.set("_launch_registered", false)
	_game.phase = GameFlow.Phase.LAUNCH
	_game.call("_update_pilot_flow")
	_check(
		_game.phase == GameFlow.Phase.TARGET_PRACTICE
		and not bool(_opponent.call("is_active")),
		"launch with drones still standing routes to target practice, never to the engagement"
	)

	# ------------------------------------- safed phases cannot destroy a drone --
	# Every phase the target gate rejects while a drone is live must also refuse
	# the shot, otherwise the one-shot authorization would be dropped forever.
	var drones := _live_drones(world)
	_check(drones.size() == _game.total_targets, "every generated drone is live before the sortie")
	if drones.is_empty():
		await _clean_up()
		_finish()
		return
	var probe_drone := drones[0] as StaticBody3D
	_hero.global_position = DRONE_ARENA_ORIGIN
	_place_drone(probe_drone, DRONE_ARENA_ORIGIN + Vector3(0.0, 0.0, -30.0))
	await physics_frame
	var drone_origin := DRONE_ARENA_ORIGIN + Vector3(0.0, 0.0, -5.5)
	var drone_direction := Vector3(0.0, 0.0, -1.0)
	var safed_phases: Array[GameFlow.Phase] = [
		GameFlow.Phase.APPROACH_SHIP,
		GameFlow.Phase.BOARDING,
		GameFlow.Phase.START_ENGINES,
		GameFlow.Phase.SHUT_DOWN,
		GameFlow.Phase.DISEMBARKING,
		GameFlow.Phase.FREE_FLIGHT,
		GameFlow.Phase.RECOVERING,
	]
	var drone_health_before := float(probe_drone.get_meta("health", 0.0))
	for safed_phase in safed_phases:
		_game.phase = safed_phase
		_game.call("_on_projectile_fired", drone_origin, drone_direction, _hero)
		var safed_result: Dictionary = _game.call("get_last_player_shot_result")
		_check(
			not bool(safed_result.get("damaged", false))
			and is_equal_approx(float(probe_drone.get_meta("health", 0.0)), drone_health_before)
			and not bool(probe_drone.get_meta("destroyed", false)),
			"phase %d safes player fire, so no drone authorization can be dropped there"
				% int(safed_phase)
		)

	# A non-guided craft is likewise reserved out of the range while the guided
	# activity is still pending, in a phase whose target gate is also shut.
	var arrow := _game.get_node("ArrowReconShip") as HeroShip
	var arrow_active_before := _game.active_ship
	_game.active_ship = arrow
	arrow.global_position = DRONE_ARENA_ORIGIN
	_game.phase = GameFlow.Phase.FREE_FLIGHT
	await physics_frame
	_game.call("_on_projectile_fired", drone_origin, drone_direction, arrow)
	var reserved_result: Dictionary = _game.call("get_last_player_shot_result")
	_check(
		reserved_result.get("status") == &"guided_range_reserved"
		and not bool(probe_drone.get_meta("destroyed", false)),
		"a sandbox craft cannot destroy a guided range drone into the shut target gate"
	)
	_game.active_ship = arrow_active_before
	arrow.global_position = ARENA_ORIGIN + Vector3(400.0, 0.0, 0.0)

	# ------------------------------------- authorized destruction is counted 1:1 --
	_game.phase = GameFlow.Phase.TARGET_PRACTICE
	_hero.global_position = DRONE_ARENA_ORIGIN
	await physics_frame
	var counted_before := _game.destroyed_targets
	for _shot in 4:
		if bool(probe_drone.get_meta("destroyed", false)):
			break
		_game.call("_on_projectile_fired", drone_origin, drone_direction, _hero)
		await physics_frame
	_check(
		bool(probe_drone.get_meta("destroyed", false))
		and _game.destroyed_targets == counted_before + 1,
		"an authorized drone destruction inside the open gate is credited exactly once"
	)
	# The one-shot authorization cannot be re-earned, so no second credit exists.
	_game.call("_on_projectile_fired", drone_origin, drone_direction, _hero)
	_check(
		_game.destroyed_targets == counted_before + 1,
		"a re-shot dead drone never issues a second authorization to drop or double count"
	)

	# ------------------------------------------- live encounter, ungated handler --
	_restore_arena_pilot(true)
	var hull_before := float(_hero.get_telemetry().get("hull", 0.0))
	_emissions.clear()
	for _frame in LIVE_FIRE_PHYSICS_FRAMES:
		await physics_frame
		if not _emissions.is_empty():
			break
	_check(
		not _emissions.is_empty(),
		"the defender's own physics reaches the coordinator's ungated fire handler"
	)
	_check(
		float(_hero.get_telemetry().get("hull", 0.0)) < hull_before,
		"defender fire resolves authoritative damage through the shared resolver"
	)

	# --------------------------------------------- exit one: the pilot is lost --
	var emissions_before_pilot_loss := _emissions.size()
	_hero.call("apply_damage", 10000.0, _hero.global_position, Vector3.UP, -1, false)
	_check(
		not bool(_opponent.call("is_active")),
		"losing the pilot clears the defender's fire latch inside the same call that ends the phase"
	)
	_check(
		_game.phase != GameFlow.Phase.INTERCEPTOR_ENGAGEMENT,
		"losing the pilot ends the interceptor engagement"
	)
	# Put a live, in-range, in-cone craft back in front of the defender. A latch
	# that outlived the phase would resume firing on it; a cleared one cannot.
	_restore_arena_pilot(false)
	await _hold_firing_solution(POST_EXIT_PHYSICS_FRAMES)
	_check(
		_emissions.size() == emissions_before_pilot_loss,
		"a defender whose encounter ended cannot resume firing on a returning pilot"
	)

	# ----------------------------------------- exit two: the defender is lost --
	_restore_arena_pilot(true)
	await physics_frame
	var emissions_before_defender_loss := _emissions.size()
	_opponent.call("apply_damage", 10000.0, _opponent.global_position, -1, false)
	_check(
		not _opponent_active_at_destroyed_signal,
		"the defender's fire latch is already clear when its destruction is published"
	)
	_check(
		not bool(_opponent.call("is_active"))
		and _game.phase == GameFlow.Phase.RETURN_TO_YARD,
		"destroying the defender ends the engagement and its authority to fire together"
	)
	_restore_arena_pilot(false)
	await _hold_firing_solution(POST_EXIT_PHYSICS_FRAMES)
	_check(
		_emissions.size() == emissions_before_defender_loss,
		"a destroyed defender cannot resume firing on a restored in-range pilot"
	)

	# ---------------------------------------------- every emission was in phase --
	var out_of_phase := 0
	for record in _emissions:
		if (
			int(record.get("phase", -1)) != int(GameFlow.Phase.INTERCEPTOR_ENGAGEMENT)
			or not bool(record.get("active", false))
			or not bool(record.get("piloting", false))
			or not bool(record.get("active_ship_is_guided", false))
		):
			out_of_phase += 1
	_check(
		out_of_phase == 0,
		"every defender emission observed by the ungated handler was inside a live encounter"
	)

	await _clean_up()
	_finish()


## Restores a healthy, in-range, in-cone pilot in front of the defender. When
## `arm_encounter` is true the coordinator's engagement is set up as well; when it
## is false only the physical opportunity to fire is restored, so a defender that
## kept a stale fire latch would be observed taking that opportunity.
func _restore_arena_pilot(arm_encounter: bool) -> void:
	_hero.call("reset_for_reuse", Transform3D(Basis.IDENTITY, ARENA_ORIGIN))
	_game.active_ship = _hero
	_game.set("_piloting", true)
	_game.set("_recovering", false)
	_game.set("_transition_busy", false)
	_opponent.global_position = ARENA_ORIGIN + OPPONENT_ARENA_OFFSET
	if arm_encounter:
		_game.phase = GameFlow.Phase.INTERCEPTOR_ENGAGEMENT
		_opponent.call("activate", Transform3D(Basis.IDENTITY, ARENA_ORIGIN + OPPONENT_ARENA_OFFSET))
	_opponent.call("set_target", _hero)
	_opponent.look_at(_hero.global_position, Vector3.UP)


## Steps physics while re-imposing a perfect firing solution every frame: the
## defender is held at its engagement offset, aimed straight down the barrel at a
## healthy in-range pilot. Only `_active` can still refuse the shot, so a latch
## that outlived its encounter is observed firing within the first cooldown.
func _hold_firing_solution(frames: int) -> void:
	for _frame in frames:
		if is_instance_valid(_opponent) and is_instance_valid(_hero):
			_opponent.global_position = _hero.global_position + OPPONENT_ARENA_OFFSET
			_opponent.look_at(_hero.global_position, Vector3.UP)
			_opponent.set("_cooldown_remaining", 0.0)
		await physics_frame


func _place_drone(drone: StaticBody3D, world_position: Vector3) -> void:
	drone.global_position = world_position
	var drone_parent := drone.get_parent() as Node3D
	if drone_parent != null:
		drone.set_meta("base_position", drone_parent.to_local(world_position))


func _live_drones(world: Node) -> Array:
	var found: Array = []
	for candidate in world.find_children("*", "StaticBody3D", true, false):
		if (
			bool(candidate.get_meta("is_shipyard_target", false))
			and not bool(candidate.get_meta("destroyed", false))
		):
			found.append(candidate)
	return found


func _record_emission(_origin: Vector3, _direction: Vector3) -> void:
	_emissions.append({
		"phase": int(_game.phase),
		"active": bool(_opponent.call("is_active")),
		"piloting": bool(_game.get("_piloting")),
		"active_ship_is_guided": _game.active_ship == _hero,
	})


func _record_opponent_destroyed(_position: Vector3) -> void:
	_opponent_active_at_destroyed_signal = bool(_opponent.call("is_active"))


func _clean_up() -> void:
	if is_instance_valid(_game):
		_game.queue_free()
	await process_frame
	await process_frame
	await process_frame


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_fail(description)


func _fail(description: String) -> void:
	_failures.append(description)
	push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("COMBAT_ENCOUNTER_AUTHORITY_GATE_TEST_OK")
		quit(0)
	else:
		print("COMBAT_ENCOUNTER_AUTHORITY_GATE_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
