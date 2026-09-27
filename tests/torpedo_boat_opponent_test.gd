extends SceneTree

## Torpedo boat: lock cue, reduced flash, teardown, and the Torpedo Run contract.
##
## The lock cue is presentation only and derived from state the craft already
## owns: STALKING while it hunts, LOCKING (three discrete closing bracket steps)
## while its charge runs, TRACKING while one of its torpedoes is in the air. The
## second half proves the Heavy Breach board posts Torpedo Run, launches it
## through the director, pays one reward for a cleared run, rotates back, and
## that a cancelled run stands the boat down with no torpedo or flight left.

const TorpedoBoatScene := preload("res://scenes/ships/torpedo_boat_opponent.tscn")
const DirectorScript := preload("res://scripts/combat/encounter_scenario_director.gd")
const BoardScript := preload("res://scripts/activities/heavy_breach_activity_board.gd")
const CatalogScript := preload("res://scripts/combat/combat_scenario_catalog.gd")
const Layers := preload("res://scripts/core/physics_layers.gd")

var _assertions := 0
var _failures: PackedStringArray = []
var _reward_requests: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var host := Node3D.new()
	host.name = "TorpedoBoatHost"
	root.add_child(host)
	var authority := LiveCombatAuthority.new()
	authority.name = "CombatAuthority"
	host.add_child(authority)
	var target := CharacterBody3D.new()
	target.name = "PlayerCraft"
	target.collision_layer = Layers.SHIP
	host.add_child(target)
	var target_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.0, 3.0, 8.0)
	target_shape.shape = box
	target.add_child(target_shape)
	var target_health := Damageable.new()
	target_health.name = "Damageable"
	target_health.maximum_health = 500.0
	target_health.faction_id = &"shipyard_flight_test"
	target.add_child(target_health)
	target.global_position = Vector3(0.0, 0.0, -150.0)
	var boat := TorpedoBoatScene.instantiate() as TorpedoBoatOpponent
	host.add_child(boat)
	await process_frame
	await physics_frame

	await _test_lock_cue(authority, boat, target)
	await _test_scenario_contract(host, authority, boat, target)
	_test_catalog()

	host.queue_free()
	await process_frame
	await process_frame
	_finish()


func _test_lock_cue(authority: LiveCombatAuthority, boat: TorpedoBoatOpponent, target: Node3D) -> void:
	_check(
		boat.get_weapon_id() == TorpedoBoatOpponent.TORPEDO_WEAPON_ID
			and CombatResolver.profile_is_projectile(
				boat.get_weapon_profiles().get(TorpedoBoatOpponent.TORPEDO_WEAPON_ID, {})
			),
		"the boat registers its torpedo with a travel envelope through the fail-closed converter"
	)
	_check(
		not bool(boat.get_lock_cue_snapshot().get("active", true)),
		"a dormant boat shows no lock cue"
	)
	var facing := (target.global_position - Vector3.ZERO).normalized()
	boat.activate(Transform3D(Basis.looking_at(facing, Vector3.UP), Vector3.ZERO))
	boat.set_target(target)
	boat.call(&"_update_presentation", 0.0)
	var generation := int(boat.get_lock_cue_snapshot().get("activation_generation", 0))
	_check(
		boat.is_combat_source_registered()
			and authority.get_source_id(boat) == TorpedoBoatOpponent.DEFAULT_SOURCE_ID,
		"activation registers the boat's stable source identity"
	)
	_check(
		StringName(boat.get_lock_cue_snapshot().get("posture", &"")) == TorpedoBoatOpponent.POSTURE_STALKING
			and generation > 0,
		"an active boat with a live target reads STALKING"
	)
	# Drive the inherited charge through its three lock steps.
	var widths: Array[float] = []
	for fraction: float in [1.0, 0.5, 0.1]:
		boat.set("_telegraph_remaining", boat.telegraph_time * fraction)
		boat.call(&"_update_presentation", 0.0)
		var snapshot := boat.get_lock_cue_snapshot()
		var cue := boat.get_node(^"TorpedoLockCue") as Node3D
		var stroke := cue.get_child(1) as MeshInstance3D
		widths.append(absf(stroke.position.x))
		_check(
			StringName(snapshot.get("posture", &"")) == TorpedoBoatOpponent.POSTURE_LOCKING
				and bool(snapshot.get("active", false)),
			"a running charge reads LOCKING (%.0f%% remaining)" % (fraction * 100.0)
		)
	_check(
		widths.size() == 3 and widths[0] > widths[1] and widths[1] > widths[2],
		"the lock brackets close in discrete steps as the charge completes"
	)
	var same_step_a := boat.get_node(^"TorpedoLockCue").get_child(0).transform as Transform3D
	boat.set("_telegraph_remaining", boat.telegraph_time * 0.12)
	boat.call(&"_update_presentation", 0.016)
	var same_step_b := boat.get_node(^"TorpedoLockCue").get_child(0).transform as Transform3D
	_check(same_step_a.is_equal_approx(same_step_b), "two frames of one lock step photograph identically")

	# Reduced flash: the strokes stay, only their punch drops.
	var reduced := boat.set_reduced_flash_enabled(true)
	var cue_stroke := boat.get_node(^"TorpedoLockCue").get_child(0) as MeshInstance3D
	var material := cue_stroke.material_override as StandardMaterial3D
	_check(
		bool((reduced.get("lock_cue", {}) as Dictionary).get("active", false))
			and is_equal_approx(material.emission_energy_multiplier, TorpedoBoatOpponent.REDUCED_FLASH_LOCK_EMISSION_ENERGY)
			and not bool((reduced.get("lock_cue", {}) as Dictionary).get("flicker", true))
			and bool((reduced.get("torpedo_presentation", {}) as Dictionary).get("reduced_flash", false)),
		"reduced flash keeps the lock cue visible at lower emission and never flickers"
	)
	boat.set_reduced_flash_enabled(false)
	_check(
		is_equal_approx(
			(cue_stroke.material_override as StandardMaterial3D).emission_energy_multiplier,
			TorpedoBoatOpponent.LOCK_EMISSION_ENERGY
		),
		"turning reduced flash off restores the full lock emission"
	)

	# Launch: the charge completes into one torpedo and the cue reads TRACKING.
	boat.set("_telegraph_remaining", 0.0)
	boat.call(&"_fire_at_target", target.global_position)
	boat.call(&"_update_presentation", 0.0)
	var pool := boat.get_torpedo_pool()
	_check(
		boat.get_torpedoes_launched() == 1
			and pool.get_active_torpedo_count() == 1
			and authority.get_active_projectile_flight_count() == 1
			and pool.get_parent() == boat,
		"a completed lock launches exactly one torpedo from a pool the launcher owns"
	)
	_check(
		StringName(boat.get_lock_cue_snapshot().get("posture", &"")) == TorpedoBoatOpponent.POSTURE_TRACKING,
		"with its torpedo in the air the boat reads TRACKING"
	)
	boat.deactivate()
	_check(
		not bool(boat.get_lock_cue_snapshot().get("active", true))
			and pool.get_active_torpedo_count() == 0
			and authority.get_active_projectile_flight_count() == 0
			and not boat.is_combat_source_registered(),
		"standing the boat down clears the cue, its torpedoes, their flights and its registration"
	)

	# A reactivated boat is a new epoch; destruction also takes torpedoes down.
	boat.activate(Transform3D(Basis.looking_at(facing, Vector3.UP), Vector3.ZERO))
	boat.set_target(target)
	boat.call(&"_update_presentation", 0.0)
	_check(
		int(boat.get_lock_cue_snapshot().get("activation_generation", 0)) > generation,
		"the cue follows the new activation generation, never a stale one"
	)
	boat.call(&"_fire_at_target", target.global_position)
	_check(pool.get_active_torpedo_count() == 1, "the reactivated boat can launch again")
	boat.apply_damage(boat.get_maximum_health() * 4.0, boat.global_position)
	_check(
		boat.get_health() <= 0.0
			and not boat.is_active()
			and pool.get_active_torpedo_count() == 0
			and authority.get_active_projectile_flight_count() == 0
			and not bool(boat.get_lock_cue_snapshot().get("active", true)),
		"destroying the boat fizzles its torpedo and clears the cue"
	)
	_check(boat.get_resolver_backed_errors().is_empty(), "the dormant boat's authority audit is green")


func _test_scenario_contract(
		host: Node3D,
		authority: LiveCombatAuthority,
		boat: TorpedoBoatOpponent,
		target: Node3D
	) -> void:
	var director := DirectorScript.new() as EncounterScenarioDirector
	director.name = "EncounterScenarios"
	host.add_child(director)
	director.torpedo_boat_path = director.get_path_to(boat)
	boat.scenario_director_path = boat.get_path_to(director)
	var objective := Node3D.new()
	objective.name = "ProtectedObjective"
	host.add_child(objective)
	var board := BoardScript.new() as HeavyBreachActivityBoard
	board.name = "HeavyBreachActivityBoard"
	host.add_child(board)
	await process_frame
	board.global_position = target.global_position + Vector3(1.0, 0.0, 0.0)
	_check(
		bool(board.configure_external_owners(objective, director, authority).get("accepted", false))
			and bool(board.configure_reward_handoff(_on_reward_requested).get("accepted", false)),
		"the board binds the director, authority and reward handoff"
	)
	_check(
		board.get_offered_scenario() == EncounterScenarioDirector.SCENARIO_HEAVY_BREACH,
		"a fresh board posts Heavy Breach first"
	)
	# Post the second contract directly; the rotation itself is checked below.
	board.set("_offered_index", 1)
	_check(
		board.get_interaction_prompt() == "[ E ]  ARM TORPEDO RUN SORTIE",
		"the board prompt names the posted Torpedo Run"
	)
	_check(board.interact(target, board.get_generation()), "the board launches the posted Torpedo Run")
	var generation := director.get_scenario_generation()
	_check(
		director.get_active_scenario() == EncounterScenarioDirector.SCENARIO_TORPEDO_RUN
			and director.is_board_sortie_running()
			and boat.is_active()
			and director.get_roster().has(boat)
			and director.is_fire_authorized(boat)
			and bool(director.get_torpedo_run_receipt(generation).get("accepted", false)),
		"Torpedo Run dispatches the boat as the only authorized participant"
	)
	_check(
		StringName(director.get_member_tactic_intent(boat).get("action", &""))
			== EncounterScenarioDirector.TACTIC_TORPEDO_ATTACK,
		"the director publishes the torpedo-attack intent for the boat"
	)
	boat.apply_damage(boat.get_maximum_health() * 4.0, boat.global_position)
	await physics_frame
	await physics_frame
	_check(
		director.get_outcome() == EncounterScenarioDirector.OUTCOME_CLEARED
			and _reward_requests.size() == 1
			and int(_reward_requests[0].get("activity_generation", 0)) == generation,
		"killing the boat clears the run and pays exactly one reward for that generation"
	)
	_check(
		_reward_requests.size() == 1
			and StringName(_reward_requests[0].get("activity_id", &"")) == &"shipyard_torpedo_run"
			and StringName(_reward_requests[0].get("reward_id", &"")) == &"return_torpedo_run_credit",
		"a cleared Torpedo Run files its own reward id rather than Heavy Breach credit"
	)
	board.call(&"_on_scenario_concluded", EncounterScenarioDirector.SCENARIO_TORPEDO_RUN, EncounterScenarioDirector.OUTCOME_CLEARED)
	_check(_reward_requests.size() == 1, "a duplicate conclusion cannot pay the run twice")
	_check(
		board.get_offered_scenario() == EncounterScenarioDirector.SCENARIO_HEAVY_BREACH,
		"a concluded Torpedo Run rotates the board back to Heavy Breach"
	)

	# Abandon: a cancelled run stands the boat down cleanly and pays nothing.
	board.set("_offered_index", 1)
	_check(board.interact(target, board.get_generation()), "a second Torpedo Run launches")
	boat.set("_telegraph_remaining", 0.0)
	boat.call(&"_fire_at_target", target.global_position)
	var pool := boat.get_torpedo_pool()
	_check(pool.get_active_torpedo_count() == 1, "the dispatched boat gets a torpedo away")
	var reset := board.abort_and_reset(target, board.get_generation())
	_check(
		bool(reset.get("aborted", false))
			and director.get_outcome() == EncounterScenarioDirector.OUTCOME_WITHDRAWN
			and not boat.is_active()
			and pool.get_active_torpedo_count() == 0
			and authority.get_active_projectile_flight_count() == 0
			and _reward_requests.size() == 1,
		"abandoning the run stands the boat down with no torpedo, flight or reward left"
	)
	_check(director.get_validation_errors().is_empty(), "the director audit is green after the abandoned run")


func _test_catalog() -> void:
	var catalog := CatalogScript.new() as CombatScenarioCatalog
	_check(catalog.is_configuration_valid(), "the combat scenario catalog stays valid with Torpedo Run")
	var scenario := catalog.get_scenario(&"torpedo_run")
	_check(
		not scenario.is_empty()
			and StringName(scenario.get("primary_profile", &"")) == &"seeker_torpedo"
			and not catalog.get_profile_snapshot(&"seeker_torpedo").is_empty(),
		"the catalog registers Torpedo Run with the seeker-torpedo profile"
	)
	var cleared := catalog.evaluate(&"torpedo_run", {"targets_destroyed": 1, "elapsed_seconds": 30.0})
	_check(
		StringName(cleared.get("outcome", &"")) == CombatScenarioCatalog.OUTCOME_CLEARED,
		"destroying the boat clears the catalog's Torpedo Run"
	)


func _on_reward_requested(request: Dictionary) -> Dictionary:
	_reward_requests.append(request.duplicate(true))
	return {"accepted": true, "receipt": {"receipt_id": _reward_requests.size()}}


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("TORPEDO_BOAT_OPPONENT_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		print("TORPEDO_BOAT_OPPONENT_TEST_FAILED: ", "; ".join(_failures))
		quit(1)
