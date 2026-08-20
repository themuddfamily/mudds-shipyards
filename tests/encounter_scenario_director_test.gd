extends SceneTree

## Focused regression for `EncounterScenarioDirector`.
##
## This suite exists for one reason: **a scenario must terminate on every
## branch**. `bugs.md` records SANDBOX-002, where an opponent could act after
## the state that authorized it had ended, and the roadmap's P0 list names an
## unrecoverable soft-lock as the one class of defect that stops all other work.
## A new objective type — "stop it before it leaves", "break the pair" — is
## exactly the kind of feature that introduces one, because it invents a way for
## an encounter to be neither won nor lost.
##
## So every branch is driven to a terminal outcome here, including the two the
## player does not choose (his craft dies; the phase changes under him) and the
## two that look like non-events (he flies away; he does nothing at all). After
## each one the suite asserts the same four things: a terminal outcome is
## recorded, the roster is empty, nothing is still flying, and no craft retains a
## live combat registration.
##
## The last section is the important one. It proves the unconditional time
## backstop fires with the objective made permanently unreachable — no craft can
## die, the player cannot be caught, and nothing else can resolve — because a
## backstop that only works when something else would have worked anyway is not
## a backstop.

const DirectorScript := preload("res://scripts/combat/encounter_scenario_director.gd")
const CoordinatorScript := preload("res://scripts/combat/wing_coordinator.gd")
const AuthorityScript := preload("res://scripts/combat/live_combat_authority.gd")
const COURIER_SCENE := preload("res://scenes/ships/courier_runner_opponent.tscn")
const SKIRMISHER_SCENE := preload("res://scenes/ships/flanking_skirmisher_opponent.tscn")

## Short, bounded values so every branch resolves inside a frame budget. The
## production values are asserted separately, from the real scene.
const TEST_ESCAPE_DISTANCE := 180.0
const TEST_TIME_LIMIT := 12.0
const TEST_DISENGAGE_RADIUS := 200.0
const TEST_DISENGAGE_GRACE := 0.6
const FRAME_BUDGET := 900

var _failures: Array[String] = []
var _assertion_count := 0
var _conclusions: Array[Dictionary] = []


## Stand-in for the player's craft. Carries the two seams the director reads and
## nothing else, so the suite is not measuring `HeroShip`.
class EncounterTarget:
	extends CharacterBody3D

	var destroyed := false

	func _ready() -> void:
		var shape := CollisionShape3D.new()
		shape.name = "TargetCollision"
		var box := BoxShape3D.new()
		box.size = Vector3(4.0, 2.0, 8.0)
		shape.shape = box
		add_child(shape)

	func is_destroyed() -> bool:
		return destroyed


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var original_children := root.get_child_count()
	await _test_courier_cleared_when_intercepted()
	await _test_courier_escapes_when_ignored()
	await _test_player_flight_withdraws_the_scenario()
	await _test_player_loss_aborts_the_scenario()
	await _test_queued_target_is_rejected_before_scenario_mutation()
	await _test_paired_wing_cleared_when_broken()
	await _test_time_backstop_with_an_unreachable_objective()
	await _test_fire_authorization_is_withdrawn_on_the_concluding_frame()
	await _test_production_bounds_and_audit()
	_check(
		root.get_child_count() == original_children,
		"every scenario fixture cleans up without leaving scene nodes"
	)
	_finish()


# ------------------------------------------------------ terminating branches ----

func _test_courier_cleared_when_intercepted() -> void:
	var fixture := await _make_fixture()
	var director: EncounterScenarioDirector = fixture.director
	var courier: CourierRunnerOpponent = fixture.courier
	_check(
		director.begin_scenario(EncounterScenarioDirector.SCENARIO_COURIER_INTERCEPT, fixture.target),
		"the courier intercept scenario starts against a live target"
	)
	_check(
		director.is_running() and courier.is_active(),
		"the runner is dispatched and the director is running"
	)
	_check(
		courier.get_escape_progress() < 0.05,
		"the runner starts its boundary run at its launch point"
	)
	# Branch 1: the player meets the objective.
	courier.apply_damage(courier.maximum_health, courier.global_position)
	await _advance_until(func() -> bool: return director.is_concluded(), 60)
	_check(
		director.get_outcome() == EncounterScenarioDirector.OUTCOME_CLEARED,
		"destroying the runner concludes the scenario as cleared (%s)"
			% director.get_outcome()
	)
	await _assert_fully_terminated(fixture, "courier intercepted")
	await _free_fixture(fixture)


func _test_courier_escapes_when_ignored() -> void:
	var fixture := await _make_fixture()
	var director: EncounterScenarioDirector = fixture.director
	var courier: CourierRunnerOpponent = fixture.courier
	director.begin_scenario(EncounterScenarioDirector.SCENARIO_COURIER_INTERCEPT, fixture.target)
	# Branch 2: the player refuses to engage and simply sits still. Nothing is
	# shot, nothing is chased, and the encounter still has to end.
	var reached := await _advance_until(func() -> bool: return director.is_concluded(), FRAME_BUDGET)
	_check(reached, "an ignored runner still concludes its scenario inside the frame budget")
	_check(
		director.get_outcome() == EncounterScenarioDirector.OUTCOME_ESCAPED,
		"an ignored runner crosses the boundary and concludes as escaped (%s)"
			% director.get_outcome()
	)
	_check(
		not courier.is_active(),
		"the escaped runner is stood down rather than left flying past the boundary"
	)
	_check(
		_last_conclusion_outcome() == EncounterScenarioDirector.OUTCOME_ESCAPED,
		"the escape outcome is announced on the scenario_concluded signal"
	)
	await _assert_fully_terminated(fixture, "courier escaped")
	await _free_fixture(fixture)


func _test_player_flight_withdraws_the_scenario() -> void:
	var fixture := await _make_fixture()
	var director: EncounterScenarioDirector = fixture.director
	var target: EncounterTarget = fixture.target
	director.begin_scenario(EncounterScenarioDirector.SCENARIO_PAIRED_WING, target)
	_check(director.is_running(), "the paired wing scenario starts against a live target")
	# Travelling a long way from where the fight started is not disengagement if
	# the fight came with you. A player who is chasing — or being chased — is
	# hundreds of metres from the scenario origin and still very much in it.
	for member in director.get_roster():
		(member as RangeOpponent).acceleration = 0.0
		(member as RangeOpponent).velocity = Vector3.ZERO
	target.global_position = Vector3(0.0, 0.0, TEST_DISENGAGE_RADIUS * 6.0)
	for member in director.get_roster():
		(member as Node3D).global_position = target.global_position + Vector3(0.0, 0.0, 30.0)
	await _advance_physics(int(TEST_DISENGAGE_GRACE * 60.0) + 30)
	_check(
		director.is_running(),
		"a player far from the scenario origin but still beside its craft has not disengaged"
	)

	# Branch 3: the player leaves everything behind. Crossing the radius is not
	# enough on its own — the grace exists so a fast pass through the edge of the
	# bubble does not cancel a fight the player is still in.
	for member in director.get_roster():
		(member as Node3D).global_position = Vector3.ZERO
	await _advance_physics(2)
	_check(
		director.is_running(),
		"crossing the disengage radius does not immediately withdraw the scenario"
	)
	var reached := await _advance_until(func() -> bool: return director.is_concluded(), 300)
	_check(reached, "a player who leaves and stays away concludes the scenario")
	_check(
		director.get_outcome() == EncounterScenarioDirector.OUTCOME_WITHDRAWN,
		"a player who leaves and stays away withdraws the scenario (%s)"
			% director.get_outcome()
	)
	await _assert_fully_terminated(fixture, "player disengaged")
	await _free_fixture(fixture)


func _test_player_loss_aborts_the_scenario() -> void:
	var fixture := await _make_fixture()
	var director: EncounterScenarioDirector = fixture.director
	var target: EncounterTarget = fixture.target
	director.begin_scenario(EncounterScenarioDirector.SCENARIO_PAIRED_WING, target)
	# Branch 4: the player dies. The scenario has to release everything it
	# dispatched before the coordinator's own recovery path runs.
	target.destroyed = true
	var reached := await _advance_until(func() -> bool: return director.is_concluded(), 60)
	_check(reached, "the loss of the player's craft concludes the scenario")
	_check(
		director.get_outcome() == EncounterScenarioDirector.OUTCOME_ABORTED,
		"the loss of the player's craft aborts the scenario (%s)" % director.get_outcome()
	)
	await _assert_fully_terminated(fixture, "player destroyed")
	await _free_fixture(fixture)


func _test_queued_target_is_rejected_before_scenario_mutation() -> void:
	var fixture := await _make_fixture()
	var director: EncounterScenarioDirector = fixture.director
	var authority: LiveCombatAuthority = fixture.authority
	var target: EncounterTarget = fixture.target
	var courier: CourierRunnerOpponent = fixture.courier
	var scenario_began: Array[StringName] = []
	director.scenario_began.connect(func(scenario_id: StringName) -> void:
		scenario_began.append(scenario_id)
	)
	var completed_before := director.get_completed_run_count()
	target.queue_free()
	var accepted := director.begin_scenario(
		EncounterScenarioDirector.SCENARIO_COURIER_INTERCEPT, target
	)
	_check(
		not accepted
		and target.is_inside_tree()
		and target.is_queued_for_deletion()
		and director.get_state() == EncounterScenarioDirector.STATE_IDLE
		and director.get_active_scenario() == EncounterScenarioDirector.SCENARIO_NONE
		and director.get_outcome() == EncounterScenarioDirector.OUTCOME_PENDING
		and director.get_completed_run_count() == completed_before
		and director.get_roster().is_empty()
		and not courier.is_active()
		and not courier.is_combat_source_registered()
		and authority.get_resolver().get_registered_source_count() == 0
		and scenario_began.is_empty(),
		"a queued target rejects scenario admission before state, roster, source, or signal mutation"
	)
	await process_frame
	_check(
		not is_instance_valid(target)
		and director.get_state() == EncounterScenarioDirector.STATE_IDLE
		and director.get_roster().is_empty()
		and not courier.is_active()
		and authority.get_resolver().get_registered_source_count() == 0
		and scenario_began.is_empty(),
		"queued target disposal cannot leave a latent scenario after rejected admission"
	)
	await _free_fixture(fixture)


func _test_paired_wing_cleared_when_broken() -> void:
	var fixture := await _make_fixture()
	var director: EncounterScenarioDirector = fixture.director
	var lead: FlankingSkirmisherOpponent = fixture.skirmishers[0]
	var wing: FlankingSkirmisherOpponent = fixture.skirmishers[1]
	director.begin_scenario(EncounterScenarioDirector.SCENARIO_PAIRED_WING, fixture.target)
	await _advance_physics(4)
	_check(
		lead.is_active() and wing.is_active(),
		"the paired wing dispatches both craft"
	)
	var coordinator: WingCoordinator = fixture.coordinator
	_check(
		coordinator.get_active_member_count() == 2 and coordinator.get_anchor() != null,
		"the dispatched pair is enlisted and holds exactly one anchor"
	)
	# Half a wing is not a cleared objective.
	lead.apply_damage(lead.maximum_health, lead.global_position)
	await _advance_physics(4)
	_check(
		director.is_running(),
		"destroying one half of the wing does not conclude the scenario"
	)
	_check(
		coordinator.get_anchor() == wing,
		"the surviving craft is promoted to anchor and fights head-on"
	)
	wing.apply_damage(wing.maximum_health, wing.global_position)
	var reached := await _advance_until(func() -> bool: return director.is_concluded(), 60)
	_check(reached, "destroying the whole wing concludes the scenario")
	_check(
		director.get_outcome() == EncounterScenarioDirector.OUTCOME_CLEARED,
		"destroying the whole wing concludes the scenario as cleared (%s)"
			% director.get_outcome()
	)
	_check(
		coordinator.get_member_count() == 0,
		"a concluded wing scenario dismisses its whole roster from the coordinator"
	)
	await _assert_fully_terminated(fixture, "wing broken")
	await _free_fixture(fixture)


func _test_time_backstop_with_an_unreachable_objective() -> void:
	var fixture := await _make_fixture()
	var director: EncounterScenarioDirector = fixture.director
	var target: EncounterTarget = fixture.target
	# Every other terminating condition is deliberately made unreachable:
	#   * the objective cannot resolve — nothing may be destroyed;
	#   * the player is alive and inside the bubble, so neither the abort nor the
	#     disengage branch can fire;
	#   * the fixture host has no phase, so the phase branch cannot fire.
	# Only the unconditional backstop is left. If it does not fire, the scenario
	# runs forever, which is the exact failure this component exists to prevent.
	director.scenario_time_limit = 2.5
	director.begin_scenario(EncounterScenarioDirector.SCENARIO_PAIRED_WING, target)
	await _advance_physics(4)
	target.global_position = Vector3.ZERO
	for member in director.get_roster():
		# Pinned out of reach of each other and unable to be caught: nothing in
		# this scenario can change state except the clock.
		(member as Node3D).global_position = Vector3(0.0, 900.0, 0.0)
	var reached := await _advance_until(func() -> bool: return director.is_concluded(), FRAME_BUDGET)
	_check(reached, "the unconditional time backstop concludes an unreachable objective")
	_check(
		director.get_outcome() == EncounterScenarioDirector.OUTCOME_EXPIRED,
		"an unreachable objective expires rather than running forever (%s)"
			% director.get_outcome()
	)
	_check(
		not target.is_destroyed() and target.global_position.distance_to(Vector3.ZERO) < 1.0,
		"the backstop fired while the player was alive, present, and had done nothing"
	)
	await _assert_fully_terminated(fixture, "scenario expired")
	await _free_fixture(fixture)


# --------------------------------------------------- fire authorization ----

func _test_fire_authorization_is_withdrawn_on_the_concluding_frame() -> void:
	var fixture := await _make_fixture()
	var director: EncounterScenarioDirector = fixture.director
	var courier: CourierRunnerOpponent = fixture.courier
	director.begin_scenario(EncounterScenarioDirector.SCENARIO_COURIER_INTERCEPT, fixture.target)
	await _advance_physics(2)
	_check(
		director.is_fire_authorized(courier),
		"a dispatched craft holds fire authorization while its scenario runs"
	)
	_check(
		not director.is_fire_authorized(fixture.skirmishers[0]),
		"a craft that this scenario did not dispatch holds no fire authorization"
	)
	_check(
		not director.is_fire_authorized(null),
		"an invalid craft holds no fire authorization"
	)

	# The SANDBOX-002 shape: a charge is committed, and the encounter ends before
	# it would be dispatched. The shot must be withheld, not delivered.
	var withheld_before := courier.get_shots_withheld()
	var fired_before := courier.get_shots_fired()
	courier.set("_telegraph_remaining", 0.0)
	director.abort(EncounterScenarioDirector.OUTCOME_WITHDRAWN)
	_check(
		not director.is_fire_authorized(courier),
		"fire authorization is false the instant the scenario concludes"
	)
	# The craft is stood down by the conclusion, so re-arm it by hand and prove
	# the gate refuses even a craft that believes it is live and aimed.
	courier.activate(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, -60.0)))
	courier.set_target(fixture.target)
	courier.call("_fire_at_target", fixture.target.global_position)
	_check(
		courier.get_shots_withheld() == withheld_before + 1
		and courier.get_shots_fired() == fired_before,
		"a shot dispatched after the scenario concluded is withheld, not resolved"
	)
	_check(
		String(courier.get_last_shot_result().get("status", &"")) == "fire_unauthorized",
		"the withheld shot records why it was refused"
	)
	courier.deactivate()
	await _free_fixture(fixture)


# --------------------------------------------------------------- audit ----

func _test_production_bounds_and_audit() -> void:
	var director := DirectorScript.new() as EncounterScenarioDirector
	_check(
		director.get_validation_errors().is_empty(),
		"the authored production director defaults pass their own audit"
	)
	_check(
		director.scenario_time_limit > 0.0 and is_finite(director.scenario_time_limit),
		"the production time backstop is finite and positive"
	)
	_check(
		director.scenario_sequence.size() >= 2
		and director.scenario_sequence[0] != director.scenario_sequence[1],
		"the production roster runs at least two different scenarios in sequence"
	)
	for scenario_id in director.scenario_sequence:
		_check(
			EncounterScenarioDirector.SCENARIO_IDS.has(scenario_id),
			"the production roster names only declared scenarios (%s)" % scenario_id
		)
	_check(
		director.get_state() == EncounterScenarioDirector.STATE_IDLE
		and director.get_outcome() == EncounterScenarioDirector.OUTCOME_PENDING,
		"a fresh director is idle and records no outcome"
	)
	_check(
		not director.begin_scenario(&"not_a_scenario", null),
		"an unknown scenario identifier is refused"
	)
	var report := director.get_audit_report()
	report["state"] = &"tampered"
	_check(
		director.get_state() == EncounterScenarioDirector.STATE_IDLE,
		"the audit report is a deep copy and cannot mutate director state"
	)
	_check(
		String(report.evidence.evidence_status) == "modern_interpretation"
		and not bool(report.evidence.historically_supported)
		and not bool(report.evidence.claims_historical_scenario_name),
		"the scenario roster is declared as an unregistered modern interpretation"
	)

	# RED: a running scenario that has outlived its own backstop is red.
	director.set("_state", EncounterScenarioDirector.STATE_RUNNING)
	director.set("_elapsed", director.scenario_time_limit + 1.0)
	_check(
		_errors_mention(director.get_validation_errors(), "outlived its unconditional time limit"),
		"RED: a scenario running past its time limit turns the audit red"
	)
	# RED: a concluded scenario without a terminal outcome is red.
	director.set("_state", EncounterScenarioDirector.STATE_CONCLUDED)
	director.set("_elapsed", 0.0)
	_check(
		_errors_mention(director.get_validation_errors(), "must record a terminal outcome"),
		"RED: a concluded scenario with no recorded outcome turns the audit red"
	)
	director.free()


# ------------------------------------------------------------- helpers ----

func _assert_fully_terminated(fixture: Dictionary, branch: String) -> void:
	var director: EncounterScenarioDirector = fixture.director
	_check(
		EncounterScenarioDirector.TERMINAL_OUTCOMES.has(director.get_outcome()),
		"%s: the scenario records a terminal outcome" % branch
	)
	_check(
		director.get_roster().is_empty(),
		"%s: the concluded scenario holds no dispatched roster" % branch
	)
	var still_flying := PackedStringArray()
	var still_registered := PackedStringArray()
	for craft in _all_opponents(fixture):
		if craft.is_active():
			still_flying.append(String(craft.name))
		if craft.is_combat_source_registered():
			still_registered.append(String(craft.name))
	_check(
		still_flying.is_empty(),
		"%s: no craft is left flying after the scenario ends (%s)"
			% [branch, ", ".join(still_flying)]
	)
	_check(
		still_registered.is_empty(),
		"%s: no craft retains a live combat registration (%s)"
			% [branch, ", ".join(still_registered)]
	)
	_check(
		director.get_validation_errors().is_empty(),
		"%s: the concluded director passes its own audit" % branch
	)
	await _advance_physics(2)


func _all_opponents(fixture: Dictionary) -> Array[ResolverBackedOpponent]:
	var craft: Array[ResolverBackedOpponent] = [fixture.courier]
	for member in fixture.skirmishers:
		craft.append(member)
	return craft


func _last_conclusion_outcome() -> StringName:
	if _conclusions.is_empty():
		return &""
	return _conclusions[_conclusions.size() - 1].get("outcome", &"")


func _errors_mention(errors: PackedStringArray, fragment: String) -> bool:
	for error in errors:
		if error.contains(fragment):
			return true
	return false


# ------------------------------------------------------------- fixture ----

func _make_fixture() -> Dictionary:
	_conclusions.clear()
	var host := Node3D.new()
	host.name = "ScenarioTestWorld"
	root.add_child(host)

	var authority := AuthorityScript.new() as LiveCombatAuthority
	authority.name = "CombatAuthority"
	host.add_child(authority)

	var target := EncounterTarget.new()
	target.name = "EncounterTarget"
	host.add_child(target)
	target.global_position = Vector3.ZERO

	var director := DirectorScript.new() as EncounterScenarioDirector
	director.name = "EncounterScenarios"
	director.escape_distance = TEST_ESCAPE_DISTANCE
	director.scenario_time_limit = TEST_TIME_LIMIT
	director.disengage_radius = TEST_DISENGAGE_RADIUS
	director.disengage_grace = TEST_DISENGAGE_GRACE
	director.encounter_host_path = NodePath("..")
	director.hud_path = NodePath("../MissingHud")
	director.courier_path = NodePath("../CourierRunner")
	director.skirmisher_paths = [
		NodePath("../WingSkirmisherLead"), NodePath("../WingSkirmisherWing"),
	]
	host.add_child(director)

	var coordinator := CoordinatorScript.new() as WingCoordinator
	coordinator.name = "WingCoordinator"
	director.add_child(coordinator)

	var courier := COURIER_SCENE.instantiate() as CourierRunnerOpponent
	courier.name = "CourierRunner"
	_wire(courier)
	host.add_child(courier)

	var skirmishers: Array[FlankingSkirmisherOpponent] = []
	for index in 2:
		var member := SKIRMISHER_SCENE.instantiate() as FlankingSkirmisherOpponent
		member.name = "WingSkirmisherLead" if index == 0 else "WingSkirmisherWing"
		member.source_id = 2103 + index
		_wire(member)
		host.add_child(member)
		skirmishers.append(member)

	director.scenario_concluded.connect(_on_scenario_concluded)
	await process_frame
	await physics_frame
	await process_frame
	return {
		"host": host,
		"authority": authority,
		"director": director,
		"coordinator": coordinator,
		"target": target,
		"courier": courier,
		"skirmishers": skirmishers,
	}


func _wire(craft: ResolverBackedOpponent) -> void:
	craft.combat_authority_path = NodePath("../CombatAuthority")
	# The pooled visual and voice banks are deliberately absent: this suite
	# measures scenario termination, not presentation, and both seams already
	# fail closed when unavailable.
	craft.pulse_presentation_path = NodePath("../MissingPulse")
	craft.combat_audio_path = NodePath("../MissingAudio")
	craft.hud_path = NodePath("../MissingHud")
	craft.encounter_host_path = NodePath("..")
	craft.scenario_director_path = NodePath("../EncounterScenarios")


func _free_fixture(fixture: Dictionary) -> void:
	var host := fixture.get("host") as Node3D
	if is_instance_valid(host):
		root.remove_child(host)
		host.queue_free()
	for _index in 8:
		await process_frame


func _advance_physics(frames: int) -> void:
	for _index in frames:
		await physics_frame
		await process_frame


func _advance_until(condition: Callable, frame_budget: int) -> bool:
	for _index in frame_budget:
		if bool(condition.call()):
			return true
		await physics_frame
		await process_frame
	return bool(condition.call())


func _on_scenario_concluded(scenario_id: StringName, outcome: StringName) -> void:
	_conclusions.append({"scenario": scenario_id, "outcome": outcome})


# ------------------------------------------------------------- harness ----

func _check(condition: bool, description: String) -> void:
	_assertion_count += 1
	if condition:
		print("PASS: %s" % description)
	else:
		_failures.append(description)
		print("FAIL: %s" % description)


func _finish() -> void:
	if _failures.is_empty():
		print("ENCOUNTER_SCENARIO_DIRECTOR_TEST_OK: %d assertions" % _assertion_count)
		quit(0)
	else:
		print("ENCOUNTER_SCENARIO_DIRECTOR_TEST_FAILED: ", "; ".join(_failures))
		quit(1)
