class_name EncounterScenarioDirector
extends Node

## Owns the *objective* of a combat encounter, and nothing else.
##
## The single-interceptor encounter has exactly one objective — destroy the
## other ship — and exactly one exit. This director adds scenarios with
## different objectives (intercept a runner before it crosses a boundary; break
## a coordinated pair) without becoming a second owner of anything the core loop
## already owns.
##
## ### What it deliberately does not own
##
## It never assigns `GameFlow.phase`, never applies damage, never registers a
## combat source, never touches a berth lease or a landing claim, and never
## holds a phase open. `GameFlow` still exits `INTERCEPTOR_ENGAGEMENT` exactly
## when the defender dies, whatever this director is doing. A scenario running
## here can therefore *fail to terminate* only in the sense of leaving its own
## opponents flying; it structurally cannot prevent the player from finishing,
## fleeing, landing, dying or quitting. That containment is the reason a new
## objective type is safe to add at all.
##
## ### Termination
##
## SANDBOX-002 records a defect where a picket lance can land during
## `RETURN_TO_YARD` because dispatch was authorized once and never re-checked.
## The general defect is an opponent or scenario reaching a state the loop
## cannot exit. Every scenario here is therefore terminated by **six**
## independent conditions, checked every physics step in this order:
##
##   1. `ABORTED`   — the player's craft is gone, destroyed, or out of the tree.
##   2. `WITHDRAWN` — the host coordinator has left the authorized phase.
##   3. `CLEARED`   — the objective was met.
##   4. `ESCAPED`   — the objective was lost on its own terms (the runner got out).
##   5. `WITHDRAWN` — the player has stayed beyond `disengage_radius` for
##                    `disengage_grace` seconds. This is the branch for a player
##                    who simply refuses to engage and flies away.
##   6. `EXPIRED`   — `scenario_time_limit` accumulated physics seconds elapsed.
##                    This is the unconditional backstop: it does not read the
##                    player, the host, or the opponents, so it still fires when
##                    every other condition has been mis-wired.
##
## Conditions 1, 2, 5 and 6 do not depend on the player doing anything, and 6
## does not depend on anything at all. There is no branch on which a scenario
## stays `RUNNING`.
##
## Concluding is synchronous and total: `_stand_down()` deactivates every
## dispatched craft and dismisses the wing in the same call that records the
## outcome, and `is_fire_authorized()` starts returning false before that call
## returns. A charge committed on the concluding frame is withheld rather than
## delivered — see `ResolverBackedOpponent._fire_at_target()`.
##
## Evidence status: modern_interpretation. No original Keth Shipyards mission,
## objective, patrol, or scenario is authenticated or claimed by this component.

signal scenario_began(scenario_id: StringName)
signal scenario_concluded(scenario_id: StringName, outcome: StringName)
signal courier_distress_broadcast(position: Vector3)

const SCHEMA_VERSION := 1
const COMPONENT_ID: StringName = &"encounter-scenario-director"
const EVIDENCE_STATUS: StringName = &"modern_interpretation"

const SCENARIO_NONE: StringName = &"none"
## Intercept-before-it-escapes. A courier runs a boundary vector; hurting it
## brings its escort wing in behind you.
const SCENARIO_COURIER_INTERCEPT: StringName = &"courier_intercept"
## A coordinated pair. One craft holds your nose, the other only shoots you in
## the back, and they trade those jobs when you turn.
const SCENARIO_PAIRED_WING: StringName = &"paired_wing"
## A caller-owned station/convoy anchor is guarded by the same coordinated pair.
const SCENARIO_STATION_DEFENSE: StringName = &"station_defense"
## A caller-owned cargo target is the objective while an escort anchor is the
## protected reference for the paired interdictor/guard wing.
const SCENARIO_CONVOY_INTERDICTION: StringName = &"convoy_interdiction"
const SCENARIO_IDS: Array[StringName] = [
	SCENARIO_COURIER_INTERCEPT, SCENARIO_PAIRED_WING, SCENARIO_STATION_DEFENSE,
	SCENARIO_CONVOY_INTERDICTION,
]

const STATE_IDLE: StringName = &"idle"
const STATE_ARMING: StringName = &"arming"
const STATE_RUNNING: StringName = &"running"
const STATE_CONCLUDED: StringName = &"concluded"

const OUTCOME_PENDING: StringName = &"pending"
## The player met the objective.
const OUTCOME_CLEARED: StringName = &"cleared"
## The runner crossed its boundary. The scenario is over and lost; nothing is
## left flying and nothing about the core loop changed.
const OUTCOME_ESCAPED: StringName = &"escaped"
## The player left — the phase changed under the scenario, or he flew away and
## stayed away.
const OUTCOME_WITHDRAWN: StringName = &"withdrawn"
## The player's craft was destroyed or removed.
const OUTCOME_ABORTED: StringName = &"aborted"
## The unconditional time backstop.
const OUTCOME_EXPIRED: StringName = &"expired"
const TERMINAL_OUTCOMES: Array[StringName] = [
	OUTCOME_CLEARED, OUTCOME_ESCAPED, OUTCOME_WITHDRAWN, OUTCOME_ABORTED, OUTCOME_EXPIRED,
]
const TACTIC_SUPPRESS: StringName = &"suppress"
const TACTIC_FLANK_UNDER_COVER: StringName = &"flank_under_cover"
const TACTIC_ENGAGE: StringName = &"engage"
const TACTIC_WITHHOLD: StringName = &"withhold"
const TACTIC_DISENGAGE: StringName = &"disengage"
const TACTIC_GUARD: StringName = &"guard"
const TACTIC_INTERCEPT: StringName = &"intercept"
const TACTIC_DEFEND: StringName = &"defend"
const TACTIC_INTERDICT: StringName = &"interdict"
const TACTIC_SCREEN_GUARD: StringName = &"screen_guard"

const CONTENT_NOTE := (
	"The scenario roster, objectives, boundary distances, escort trigger, paired-wing "
	+ "suppression opening, caller-owned protected-anchor defense, and every timing "
	+ "value are an original modern interpretation. They do not "
	+ "reproduce or claim any authenticated historical Keth Shipyards mission, "
	+ "patrol, objective, or scenario."
)

@export_category("Scenario direction")
@export var enabled := true
## Scenarios are run in this order, one per entry into the authorized phase,
## cycling. A second sortie is therefore a different fight, which is the whole
## point of the roster.
@export var scenario_sequence: Array[StringName] = [
	SCENARIO_COURIER_INTERCEPT, SCENARIO_PAIRED_WING,
]
## Accumulated physics seconds after the phase opens before a scenario launches,
## so it reads as a second contact rather than as part of the first spawn.
@export_range(0.0, 30.0, 0.1) var start_delay := 4.5
## The unconditional backstop. No scenario can outlive this, whatever else the
## player, the host or the opponents do.
@export_range(10.0, 600.0, 1.0) var scenario_time_limit := 150.0
## A player this far from the scenario's own origin, for this long, has left.
@export_range(50.0, 4000.0, 10.0) var disengage_radius := 700.0
@export_range(0.5, 60.0, 0.5) var disengage_grace := 7.0

@export_category("Courier intercept")
## Distance from its launch point at which the runner is gone.
@export_range(100.0, 4000.0, 10.0) var escape_distance := 1400.0
## Hull ratio below which the courier broadcasts and its escort launches.
@export_range(0.0, 1.0, 0.01) var distress_hull_ratio := 0.82
@export_range(0.0, 20.0, 0.1) var escort_response_delay := 2.4

@export_category("Paired wing tactic")
## Opening window in which the anchor supplies suppressive fire while the
## flanker moves for the rear arc. Existing opponents consume this director's
## dispatch-frame fire gate; the resolver and each craft's movement/arc rules
## remain the sole authorities for what happens after the intent.
@export_range(0.0, 10.0, 0.1) var suppression_lead_time := 2.2
## Threat distance from the caller-owned anchor at which the guard wing opens
## crossfire. Outside it, the anchor-role craft intercepts while its peer guards.
@export_range(25.0, 1000.0, 5.0) var defense_trigger_radius := 180.0

@export_category("Encounter wiring")
@export var encounter_host_path := NodePath("..")
@export var wing_coordinator_path := NodePath("WingCoordinator")
@export var hud_path := NodePath("../HUD")
@export var courier_path := NodePath("../CourierRunner")
@export var skirmisher_paths: Array[NodePath] = [
	NodePath("../WingSkirmisherLead"), NodePath("../WingSkirmisherWing"),
]

var _state: StringName = STATE_IDLE
var _scenario: StringName = SCENARIO_NONE
var _outcome: StringName = OUTCOME_PENDING
var _elapsed := 0.0
var _arming_elapsed := 0.0
var _disengaged_elapsed := 0.0
var _escort_elapsed := 0.0
var _sequence_cursor := 0
var _phase_was_authorized := false
var _launched := false
var _escort_launched := false
var _distress_broadcast := false
var _scenario_origin := Vector3.ZERO
var _courier_launch_origin := Vector3.ZERO
var _target: Node3D
var _protected_anchor: Node3D
var _cargo_target: Node3D
var _scenario_generation := 0
var _roster: Array[Node3D] = []
var _completed_runs := 0
var _outcome_counts: Dictionary = {}
var _halfway_warned := false


func _physics_process(delta: float) -> void:
	if not _is_current():
		return
	if not enabled or not is_finite(delta) or delta < 0.0:
		return
	_update_arming(delta)
	if _state != STATE_RUNNING:
		return
	_elapsed += delta
	if _scenario == SCENARIO_COURIER_INTERCEPT:
		_update_courier_scenario(delta)
	var outcome := _evaluate_termination(delta)
	if outcome != OUTCOME_PENDING:
		_conclude(outcome)


# --------------------------------------------------------- public state ----

func get_state() -> StringName:
	return _state


func get_active_scenario() -> StringName:
	return _scenario


func get_outcome() -> StringName:
	return _outcome


func get_elapsed() -> float:
	return _elapsed


func get_scenario_generation() -> int:
	return _scenario_generation


func get_convoy_interdiction_receipt(expected_generation: int = 0) -> Dictionary:
	if _scenario != SCENARIO_CONVOY_INTERDICTION or not _is_current():
		return {"accepted": false, "reason": &"convoy_inactive"}
	if expected_generation > 0 and expected_generation != _scenario_generation:
		return {"accepted": false, "reason": &"stale_generation"}
	return {
		"accepted": true,
		"generation": _scenario_generation,
		"scenario": _scenario,
		"cargo_target": String(_cargo_target.name) if is_instance_valid(_cargo_target) else "",
		"cargo_target_instance_id": _cargo_target.get_instance_id()
			if is_instance_valid(_cargo_target) else 0,
		"escort_anchor": String(_protected_anchor.name) if is_instance_valid(_protected_anchor) else "",
		"escort_anchor_instance_id": _protected_anchor.get_instance_id()
			if is_instance_valid(_protected_anchor) else 0,
		"authority": {"motion": false, "fire": false, "damage": false},
	}.duplicate(true)


func is_running() -> bool:
	return _state == STATE_RUNNING


func is_concluded() -> bool:
	return _state == STATE_CONCLUDED


func get_completed_run_count() -> int:
	return _completed_runs


func get_outcome_counts() -> Dictionary:
	return _outcome_counts.duplicate(true)


func is_distress_broadcast() -> bool:
	return _distress_broadcast


func is_escort_launched() -> bool:
	return _escort_launched


## Fraction of the runner's boundary run that is complete, 0..1. Deliberately a
## pure function of distance rather than of time, so it reads the same whether
## the player chased hard or not at all.
func get_escape_progress() -> float:
	if _scenario != SCENARIO_COURIER_INTERCEPT:
		return 0.0
	var courier := _get_courier()
	if not is_instance_valid(courier) or escape_distance <= 0.0:
		return 0.0
	return clampf(
		courier.global_position.distance_to(_courier_launch_origin) / escape_distance,
		0.0,
		1.0
	)


## The craft currently dispatched by the running scenario. A copy: a caller
## cannot enlist or drop a participant by mutating the returned array.
func get_roster() -> Array[Node3D]:
	var live: Array[Node3D] = []
	for member in _roster:
		if is_instance_valid(member):
			live.append(member)
	return live


## The single fire gate for every craft this director dispatched. Asked on the
## frame a shot is dispatched, not on the frame its charge began.
func is_fire_authorized(member: Node) -> bool:
	if not _is_current():
		return false
	if _state != STATE_RUNNING:
		return false
	if not is_instance_valid(member) or not _roster.has(member):
		return false
	if not _is_phase_authorized():
		return false
	var coordinator := _get_wing_coordinator()
	if (
		is_instance_valid(coordinator)
		and member is Node3D
		and coordinator.is_member_disengaging(member as Node3D)
	):
		return false
	if _scenario == SCENARIO_STATION_DEFENSE:
		if not _is_protected_anchor_alive():
			return false
		if is_instance_valid(coordinator):
			var role := coordinator.get_role(member as Node3D)
			if role == WingCoordinator.ROLE_ANCHOR:
				return true
			return _target.global_position.distance_to(
				_protected_anchor.global_position
			) <= defense_trigger_radius
	if _scenario == SCENARIO_CONVOY_INTERDICTION:
		if not _is_convoy_interdiction_live():
			return false
		if is_instance_valid(coordinator):
			return coordinator.get_role(member as Node3D) == WingCoordinator.ROLE_ANCHOR \
				or not coordinator.is_member_disengaging(member as Node3D)
		return true
	if _paired_wing_suppression_active():
		if is_instance_valid(coordinator):
			return coordinator.get_role(member as Node3D) == WingCoordinator.ROLE_ANCHOR
	return true


## Detached maneuver/fire intent for the live paired-wing tactic. Opponents use
## `is_fire_authorized()` directly; this snapshot makes the simultaneous anchor
## suppression and covered flanking decision inspectable without owning motion,
## aim, ray queries, or damage.
func get_member_tactic_intent(member: Node) -> Dictionary:
	var authorized := is_fire_authorized(member)
	var action := TACTIC_WITHHOLD
	var role := WingCoordinator.ROLE_UNASSIGNED
	var coordinator := _get_wing_coordinator()
	if is_instance_valid(coordinator) and member is Node3D:
		role = coordinator.get_role(member as Node3D)
	var disengaging := (
		is_instance_valid(coordinator)
		and member is Node3D
		and coordinator.is_member_disengaging(member as Node3D)
	)
	if disengaging:
		action = TACTIC_DISENGAGE
	elif _scenario == SCENARIO_CONVOY_INTERDICTION and _is_convoy_interdiction_live():
		if role == WingCoordinator.ROLE_ANCHOR:
			action = TACTIC_INTERDICT
		elif role == WingCoordinator.ROLE_FLANKER:
			action = TACTIC_SCREEN_GUARD
	elif _scenario == SCENARIO_STATION_DEFENSE and _is_protected_anchor_alive():
		if role == WingCoordinator.ROLE_ANCHOR:
			action = TACTIC_INTERCEPT
		elif _target.global_position.distance_to(
				_protected_anchor.global_position
			) <= defense_trigger_radius:
			action = TACTIC_DEFEND
		else:
			action = TACTIC_GUARD
	elif _paired_wing_suppression_active():
		action = (
			TACTIC_SUPPRESS
			if role == WingCoordinator.ROLE_ANCHOR
			else TACTIC_FLANK_UNDER_COVER
		)
	elif authorized:
		action = TACTIC_ENGAGE
	return {
		"action": action,
		"fire_authorized": authorized,
		"role": role,
		"suppression_active": _paired_wing_suppression_active(),
		"disengaging": disengaging,
		"elapsed": _elapsed,
		"protected_anchor": (
			String(_protected_anchor.name) if is_instance_valid(_protected_anchor) else ""
		),
		"cargo_target": (
			String(_cargo_target.name) if is_instance_valid(_cargo_target) else ""
		),
		"generation": _scenario_generation,
	}.duplicate(true)


func _paired_wing_suppression_active() -> bool:
	return (
		_state == STATE_RUNNING
		and _scenario == SCENARIO_PAIRED_WING
		and suppression_lead_time > 0.0
		and _elapsed < suppression_lead_time
	)


# ------------------------------------------------------------ lifecycle ----

## Starts a scenario immediately, bypassing the phase watch. The production path
## goes through `_update_arming`; this exists so a suite can drive one branch
## deterministically without staging a whole guided sortie.
func begin_scenario(scenario_id: StringName, target: Node3D) -> bool:
	return _begin_scenario(scenario_id, target, null)


## Explicit admission for the caller-owned defense anchor. The director retains
## only the live Node identity for scenario distance/loss observations and never
## mutates its transform, health, collision, ownership, or lifecycle.
func begin_station_defense(target: Node3D, protected_anchor: Node3D) -> bool:
	return _begin_scenario(SCENARIO_STATION_DEFENSE, target, protected_anchor)


## Admits one generation-fenced convoy objective. The caller target remains the
## disengagement/phase observer; attackers receive the separate cargo target and
## escort anchor through the existing coordinator target seam.
func begin_convoy_interdiction(
		caller_target: Node3D,
		cargo_target: Node3D,
		escort_anchor: Node3D
	) -> bool:
	if not _is_live_anchor(cargo_target) or not _is_live_anchor(escort_anchor):
		return false
	return _begin_scenario(
		SCENARIO_CONVOY_INTERDICTION,
		caller_target,
		escort_anchor,
		cargo_target,
	)


func _begin_scenario(
		scenario_id: StringName,
		target: Node3D,
		protected_anchor: Node3D,
		cargo_target: Node3D = null
	) -> bool:
	if not _is_current():
		return false
	# An unknown identifier is refused by return value rather than by an engine
	# diagnostic: `get_validation_errors()` already names an unrecognised entry
	# in the authored roster, and the frozen matrix treats stray warnings in a
	# suite log as failures.
	if not SCENARIO_IDS.has(scenario_id):
		return false
	if _state == STATE_RUNNING:
		return false
	if (
		not is_instance_valid(target)
		or target.is_queued_for_deletion()
		or not target.is_inside_tree()
	):
		return false
	if scenario_id == SCENARIO_STATION_DEFENSE and not _is_live_anchor(protected_anchor):
		return false
	if scenario_id == SCENARIO_CONVOY_INTERDICTION \
			and (not _is_live_anchor(protected_anchor) or not _is_live_anchor(cargo_target)):
		return false
	_reset_run_state()
	_protected_anchor = protected_anchor if scenario_id == SCENARIO_STATION_DEFENSE else null
	if scenario_id == SCENARIO_CONVOY_INTERDICTION:
		_protected_anchor = protected_anchor
		_cargo_target = cargo_target
	else:
		_cargo_target = null
	_scenario = scenario_id
	_target = target
	_scenario_generation += 1
	_scenario_origin = target.global_position
	_state = STATE_RUNNING
	_outcome = OUTCOME_PENDING
	match scenario_id:
		SCENARIO_COURIER_INTERCEPT:
			_launch_courier()
		SCENARIO_PAIRED_WING:
			_launch_wing()
		SCENARIO_STATION_DEFENSE:
			_launch_wing(_protected_anchor.global_position)
		SCENARIO_CONVOY_INTERDICTION:
			_launch_wing(_protected_anchor.global_position)
	if _roster.is_empty():
		# Nothing could be staged. Terminating immediately is the only honest
		# result; leaving the director RUNNING with an empty roster is precisely
		# the non-terminating state this component exists to make impossible.
		_conclude(OUTCOME_ABORTED)
		return false
	_launched = true
	scenario_began.emit(_scenario)
	_announce_begin()
	return true


## Ends a running scenario on the caller's behalf. Idempotent.
func abort(outcome: StringName = OUTCOME_ABORTED) -> void:
	if not _is_current():
		return
	if _state != STATE_RUNNING:
		return
	_conclude(outcome if TERMINAL_OUTCOMES.has(outcome) else OUTCOME_ABORTED)


func _update_arming(delta: float) -> void:
	var authorized := _is_phase_authorized()
	if not authorized:
		if _phase_was_authorized:
			# Leaving the phase resets the arming latch and advances the roster,
			# so the next sortie is the next scenario rather than a repeat.
			if _state == STATE_RUNNING:
				_conclude(OUTCOME_WITHDRAWN)
			_state = STATE_IDLE if _state != STATE_CONCLUDED else _state
			_arming_elapsed = 0.0
		_phase_was_authorized = false
		return
	if not _phase_was_authorized:
		_phase_was_authorized = true
		_arming_elapsed = 0.0
		if _state == STATE_CONCLUDED:
			_state = STATE_IDLE
	if _state != STATE_IDLE:
		return
	_arming_elapsed += delta
	if _arming_elapsed < start_delay:
		return
	var target := _resolve_host_target()
	if not is_instance_valid(target):
		return
	var scenario := _next_scenario()
	if scenario == SCENARIO_NONE:
		# An empty or unrecognised roster stages nothing and never retries within
		# this phase entry. `enabled` is an authored export and is not mutated
		# here, so a scene fix takes effect without a restart.
		_arming_elapsed = 0.0
		return
	_arming_elapsed = 0.0
	if begin_scenario(scenario, target):
		_sequence_cursor += 1


func _next_scenario() -> StringName:
	if scenario_sequence.is_empty():
		return SCENARIO_NONE
	var candidate := scenario_sequence[_sequence_cursor % scenario_sequence.size()]
	return candidate if SCENARIO_IDS.has(candidate) else SCENARIO_NONE


func _is_current() -> bool:
	return is_inside_tree() and not is_queued_for_deletion()


# ---------------------------------------------------------- termination ----

func _evaluate_termination(delta: float) -> StringName:
	# 1. The player is gone.
	if not _is_target_alive():
		return OUTCOME_ABORTED
	if _scenario == SCENARIO_STATION_DEFENSE and not _is_protected_anchor_alive():
		return OUTCOME_ABORTED
	if _scenario == SCENARIO_CONVOY_INTERDICTION and not _is_protected_anchor_alive():
		return OUTCOME_ABORTED
	# 2. The host left the authorized phase.
	if not _is_phase_authorized():
		return OUTCOME_WITHDRAWN
	# 3/4. The objective resolved on its own terms.
	var objective := _evaluate_objective()
	if objective != OUTCOME_PENDING:
		return objective
	# 5. The player flew away and stayed away.
	if _is_player_disengaged():
		_disengaged_elapsed += delta
		if _disengaged_elapsed >= disengage_grace:
			return OUTCOME_WITHDRAWN
	else:
		_disengaged_elapsed = 0.0
	# 6. The unconditional backstop.
	if _elapsed >= scenario_time_limit:
		return OUTCOME_EXPIRED
	return OUTCOME_PENDING


## Disengagement is measured against **both** the place the encounter started
## and every craft still in it, and requires being clear of all of them.
##
## Either half alone gets a branch wrong. Distance from the scenario origin
## alone would call a player who is chasing the runner a player who has left,
## because chasing means travelling. Distance from the live craft alone would
## call a player who is standing still and letting the runner go a player who
## has left, because the runner is the thing doing the travelling — and that
## player should get `ESCAPED`, which is a different outcome with a different
## meaning. Requiring both is what separates "he went away" from "it went away".
func _is_player_disengaged() -> bool:
	if not is_instance_valid(_target):
		return false
	var position := _target.global_position
	if position.distance_to(_scenario_origin) <= disengage_radius:
		return false
	for member in _roster:
		if _is_participant_active(member) and position.distance_to(member.global_position) <= disengage_radius:
			return false
	return true


func _evaluate_objective() -> StringName:
	if not _launched:
		return OUTCOME_PENDING
	match _scenario:
		SCENARIO_COURIER_INTERCEPT:
			var courier := _get_courier()
			if not _is_participant_active(courier):
				return OUTCOME_CLEARED
			if courier.global_position.distance_to(_courier_launch_origin) >= escape_distance:
				return OUTCOME_ESCAPED
		SCENARIO_PAIRED_WING:
			if _active_roster_count() == 0:
				return OUTCOME_CLEARED
		SCENARIO_STATION_DEFENSE:
			if _active_roster_count() == 0:
				return OUTCOME_CLEARED
		SCENARIO_CONVOY_INTERDICTION:
			if not _is_live_objective(_cargo_target):
				return OUTCOME_CLEARED
			if _cargo_target.global_position.distance_to(_scenario_origin) >= escape_distance:
				return OUTCOME_ESCAPED
	return OUTCOME_PENDING


func _conclude(outcome: StringName) -> void:
	if _state == STATE_CONCLUDED:
		return
	# The state flips before the stand-down runs, so `is_fire_authorized()` is
	# already false for anything that reacts inside `_stand_down()`.
	_state = STATE_CONCLUDED
	_outcome = outcome
	_completed_runs += 1
	_outcome_counts[outcome] = int(_outcome_counts.get(outcome, 0)) + 1
	_stand_down()
	_announce_conclusion(outcome)
	scenario_concluded.emit(_scenario, outcome)


func _stand_down() -> void:
	var coordinator := _get_wing_coordinator()
	if is_instance_valid(coordinator):
		coordinator.set_target(null)
		coordinator.dismiss_all()
	for member in _roster:
		if not is_instance_valid(member):
			continue
		if member.has_method(&"is_active") and bool(member.call(&"is_active")):
			member.call(&"deactivate")
	_roster.clear()
	_target = null
	_protected_anchor = null
	_cargo_target = null


func _reset_run_state() -> void:
	_stand_down()
	_elapsed = 0.0
	_disengaged_elapsed = 0.0
	_escort_elapsed = 0.0
	_launched = false
	_escort_launched = false
	_distress_broadcast = false
	_halfway_warned = false
	_outcome = OUTCOME_PENDING


# ------------------------------------------------------------ scenarios ----

func _launch_courier() -> void:
	var courier := _get_courier()
	if not is_instance_valid(courier) or not is_instance_valid(_target):
		return
	# The runner enters ahead of and above the player, already pointed out, so
	# the read on first sight is "that one is leaving", not "that one is coming".
	var player_forward := -_target.global_basis.z
	if player_forward.length_squared() <= 0.001:
		player_forward = Vector3.FORWARD
	player_forward = player_forward.normalized()
	var lateral := Vector3.UP.cross(player_forward)
	if lateral.length_squared() <= 0.001:
		lateral = Vector3.RIGHT
	lateral = lateral.normalized()
	# Close enough to be legible on the frame the toast announces it. An earlier
	# placement put the runner 210 m out and well off the player's axis, and by
	# the time he had read the toast it was a two-pixel smudge leaving the top of
	# the screen — an objective the player cannot see is not an objective. It
	# still enters ahead and above, so the first read is "that one is leaving".
	var spawn := (
		_target.global_position
		+ player_forward * 120.0
		+ lateral * 26.0
		+ Vector3.UP * 18.0
	)
	var run_heading := (player_forward * 0.94 + lateral * 0.22 + Vector3.UP * 0.1).normalized()
	var up := Vector3.UP if absf(run_heading.dot(Vector3.UP)) < 0.965 else Vector3.FORWARD
	courier.activate(Transform3D(Basis.looking_at(run_heading, up).orthonormalized(), spawn))
	courier.set_target(_target)
	if courier.has_method(&"set_escape_run"):
		courier.call(&"set_escape_run", spawn, run_heading, escape_distance)
	_courier_launch_origin = spawn
	_roster.append(courier)


func _launch_wing(anchor_position: Vector3 = Vector3.INF) -> void:
	var engagement_target := _cargo_target if _scenario == SCENARIO_CONVOY_INTERDICTION else _target
	if not is_instance_valid(engagement_target):
		return
	var coordinator := _get_wing_coordinator()
	var origin := anchor_position if anchor_position.is_finite() else _target.global_position
	var player_forward := -engagement_target.global_basis.z
	if player_forward.length_squared() <= 0.001:
		player_forward = Vector3.FORWARD
	player_forward = player_forward.normalized()
	var lateral := Vector3.UP.cross(player_forward)
	if lateral.length_squared() <= 0.001:
		lateral = Vector3.RIGHT
	lateral = lateral.normalized()
	# The pair enters split, one high and one low on opposite flanks. Entering
	# together would read as one contact and would hand the coordinator two
	# identical frontal claims on its first evaluation.
	var placements := [
		origin + player_forward * 96.0 + lateral * 78.0 + Vector3.UP * 30.0,
		origin - player_forward * 74.0 - lateral * 88.0 - Vector3.UP * 22.0,
	]
	var index := 0
	for member in _get_skirmishers():
		if not is_instance_valid(member):
			continue
		var spawn: Vector3 = placements[index % placements.size()]
		var facing := engagement_target.global_position - spawn
		if facing.length_squared() <= 0.001:
			facing = player_forward
		facing = facing.normalized()
		var up := Vector3.UP if absf(facing.dot(Vector3.UP)) < 0.965 else Vector3.FORWARD
		member.activate(Transform3D(Basis.looking_at(facing, up).orthonormalized(), spawn))
		member.set_target(engagement_target)
		if is_instance_valid(coordinator):
			coordinator.enlist(member)
		_roster.append(member)
		index += 1
	if is_instance_valid(coordinator):
		coordinator.set_target(engagement_target)
		# One immediate assignment so the pair never spends a frame with two
		# unassigned craft, which would briefly read as two anchors.
		coordinator.update_assignments(0.0)


func _update_courier_scenario(delta: float) -> void:
	var courier := _get_courier()
	if not _is_participant_active(courier):
		return
	if not _distress_broadcast and _participant_health_ratio(courier) < distress_hull_ratio:
		_distress_broadcast = true
		_escort_elapsed = 0.0
		if courier.has_method(&"begin_distress_broadcast"):
			courier.call(&"begin_distress_broadcast")
		courier_distress_broadcast.emit(courier.global_position)
		_toast(
			"Courier distress call",
			"It is calling an escort — expect company behind you",
			3.4
		)
	if _distress_broadcast and not _escort_launched:
		_escort_elapsed += delta
		if _escort_elapsed >= escort_response_delay:
			_escort_launched = true
			_launch_wing(courier.global_position)
			_toast("Escort wing inbound", "Two contacts closing on your six", 3.4)
	if not _halfway_warned and get_escape_progress() >= 0.5:
		_halfway_warned = true
		_toast("Courier at half boundary range", "Close now or lose it", 3.0)


# ---------------------------------------------------------- host access ----

func _is_phase_authorized() -> bool:
	var host := get_node_or_null(encounter_host_path)
	if host is GameFlow:
		return (host as GameFlow).phase == GameFlow.Phase.INTERCEPTOR_ENGAGEMENT
	# A non-coordinator host (isolated fixtures, evidence harnesses, tools) has
	# no phase to read. `begin_scenario()` is then the only entry point, and the
	# remaining five terminating conditions still apply in full.
	return _state == STATE_RUNNING


func _resolve_host_target() -> Node3D:
	var host := get_node_or_null(encounter_host_path)
	if is_instance_valid(host) and host.has_method(&"get_active_ship"):
		var active_ship := host.call(&"get_active_ship") as Node3D
		if is_instance_valid(active_ship) and active_ship.is_inside_tree():
			return active_ship
	return null


func _is_target_alive() -> bool:
	if (
		not is_instance_valid(_target)
		or _target.is_queued_for_deletion()
		or not _target.is_inside_tree()
	):
		return false
	if _target.has_method(&"is_destroyed") and bool(_target.call(&"is_destroyed")):
		return false
	return true


func _is_live_anchor(anchor: Node3D) -> bool:
	return (
		is_instance_valid(anchor)
		and not anchor.is_queued_for_deletion()
		and anchor.is_inside_tree()
	)


func _is_protected_anchor_alive() -> bool:
	if not _is_live_anchor(_protected_anchor):
		return false
	if _protected_anchor.has_method(&"is_destroyed") \
			and bool(_protected_anchor.call(&"is_destroyed")):
		return false
	return true


func _is_live_objective(objective: Node3D) -> bool:
	if not _is_live_anchor(objective):
		return false
	return not objective.has_method(&"is_destroyed") \
		or not bool(objective.call(&"is_destroyed"))


func _is_convoy_interdiction_live() -> bool:
	return _is_live_objective(_cargo_target) and _is_protected_anchor_alive()


func _get_courier() -> Node3D:
	return get_node_or_null(courier_path) as Node3D


func _get_skirmishers() -> Array[Node3D]:
	var members: Array[Node3D] = []
	for path in skirmisher_paths:
		var member := get_node_or_null(path) as Node3D
		if is_instance_valid(member):
			members.append(member)
	return members


func _get_wing_coordinator() -> WingCoordinator:
	return get_node_or_null(wing_coordinator_path) as WingCoordinator


func _is_participant_active(member: Node3D) -> bool:
	return (
		is_instance_valid(member)
		and member.is_inside_tree()
		and member.has_method(&"is_active")
		and bool(member.call(&"is_active"))
	)


func _active_roster_count() -> int:
	var count := 0
	for member in _roster:
		if _is_participant_active(member):
			count += 1
	return count


func _participant_health_ratio(member: Node3D) -> float:
	if not is_instance_valid(member) or not member.has_method(&"get_health"):
		return 1.0
	var maximum := 1.0
	var declared: Variant = member.get(&"maximum_health")
	if declared is float or declared is int:
		maximum = maxf(0.001, float(declared))
	return clampf(float(member.call(&"get_health")) / maximum, 0.0, 1.0)


# --------------------------------------------------------- presentation ----

## Scenario readability deliberately runs through `HUD.toast` only. The
## objective line belongs to `GameFlow`, which rewrites it on every phase
## transition; a second writer would race it and leave stale text on screen.
func _toast(title: String, detail: String, duration: float) -> void:
	var hud := get_node_or_null(hud_path)
	if is_instance_valid(hud) and hud.has_method(&"toast"):
		hud.call(&"toast", title, detail, duration)


func _announce_begin() -> void:
	match _scenario:
		SCENARIO_COURIER_INTERCEPT:
			_toast(
				"Courier breaking for the boundary",
				"Stop it before it clears the yard perimeter",
				4.0
			)
		SCENARIO_PAIRED_WING:
			_toast(
				"Wing pair on approach",
				"Two contacts, split high and low — do not give them your back",
				4.0
			)
		SCENARIO_STATION_DEFENSE:
			_toast(
				"Guard wing holding the station",
				"Break its intercept before closing on the protected anchor",
				4.0
			)
		SCENARIO_CONVOY_INTERDICTION:
			_toast(
				"Convoy interdiction wing",
				"One attacker pressures the cargo while its wing screens the escort",
				4.0
			)


func _announce_conclusion(outcome: StringName) -> void:
	match outcome:
		OUTCOME_CLEARED:
			if _scenario == SCENARIO_COURIER_INTERCEPT:
				_toast("Courier intercepted", "The boundary run is stopped", 3.2)
			elif _scenario == SCENARIO_CONVOY_INTERDICTION:
				_toast("Cargo protected", "The interdiction wing is broken", 3.2)
			else:
				_toast("Wing broken", "Both contacts are down", 3.2)
		OUTCOME_ESCAPED:
			_toast(
				"Cargo escaped" if _scenario == SCENARIO_CONVOY_INTERDICTION else "Courier escaped",
				"It cleared the perimeter — contact lost",
				3.6,
			)
		OUTCOME_WITHDRAWN:
			_toast("Contacts disengaged", "The scenario broke off and withdrew", 3.0)
		OUTCOME_EXPIRED:
			_toast("Contacts withdrawn", "They have run out of endurance and left", 3.0)
		OUTCOME_ABORTED:
			pass


# ------------------------------------------------------------- audit ----

func get_evidence_metadata() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"evidence_status": EVIDENCE_STATUS,
		"historically_supported": false,
		"authenticated_original_mission": false,
		"authenticated_original_objective": false,
		"claims_historical_scenario_name": false,
		"modern_interpretations": PackedStringArray([
			"intercept-before-it-escapes objective and its boundary distance",
			"coordinated pair objective and its split entry",
			"anchor suppression opening while its flanker maneuvers under cover",
			"generation-fenced convoy cargo interdiction with escort screening",
			"distress broadcast and escort response timing",
			"every scenario duration, radius, and delay",
		]),
		"explicit_unknowns": PackedStringArray([
			"any historical opposing mission, patrol, objective, or scenario",
		]),
		"content_note": CONTENT_NOTE,
	}.duplicate(true)


func get_audit_report() -> Dictionary:
	var errors := get_validation_errors()
	var roster_names := PackedStringArray()
	for member in _roster:
		if is_instance_valid(member):
			roster_names.append(String(member.name))
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"valid": errors.is_empty(),
		"errors": errors,
		"evidence": get_evidence_metadata(),
		"enabled": enabled,
		"state": _state,
		"scenario": _scenario,
		"outcome": _outcome,
		"elapsed": _elapsed,
		"launched": _launched,
		"roster": roster_names,
		"active_roster": _active_roster_count(),
		"completed_runs": _completed_runs,
		"scenario_generation": _scenario_generation,
		"outcome_counts": _outcome_counts.duplicate(true),
		"courier": {
			"distress_broadcast": _distress_broadcast,
			"escort_launched": _escort_launched,
			"escape_progress": get_escape_progress(),
		},
		"bounds": {
			"scenario_time_limit": scenario_time_limit,
			"disengage_radius": disengage_radius,
			"disengage_grace": disengage_grace,
			"escape_distance": escape_distance,
			"start_delay": start_delay,
			"suppression_lead_time": suppression_lead_time,
			"defense_trigger_radius": defense_trigger_radius,
		},
		"protected_anchor": (
			String(_protected_anchor.name) if is_instance_valid(_protected_anchor) else ""
		),
		"cargo_target": String(_cargo_target.name) if is_instance_valid(_cargo_target) else "",
	}.duplicate(true)


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	for scenario_id in scenario_sequence:
		if not SCENARIO_IDS.has(scenario_id):
			errors.append("scenario sequence names an unknown scenario '%s'" % scenario_id)
	if not is_finite(scenario_time_limit) or scenario_time_limit <= 0.0:
		errors.append("the scenario time limit must be finite and positive")
	if not is_finite(disengage_grace) or disengage_grace < 0.0:
		errors.append("the disengage grace must be finite and non-negative")
	if not is_finite(escape_distance) or escape_distance <= 0.0:
		errors.append("the escape distance must be finite and positive")
	if not is_finite(suppression_lead_time) \
			or suppression_lead_time < 0.0 or suppression_lead_time > 10.0:
		errors.append("the suppression lead time must stay inside its finite 0..10 second bound")
	if not is_finite(defense_trigger_radius) \
			or defense_trigger_radius < 25.0 or defense_trigger_radius > 1000.0:
		errors.append("the defense trigger radius must stay inside its finite 25..1000 metre bound")
	if _state == STATE_RUNNING and _scenario == SCENARIO_STATION_DEFENSE \
			and not _is_protected_anchor_alive():
		errors.append("a running station defense must retain its caller-owned protected anchor")
	if _state == STATE_RUNNING and _scenario == SCENARIO_CONVOY_INTERDICTION \
			and not _is_convoy_interdiction_live():
		errors.append("a running convoy interdiction must retain its cargo and escort anchors")
	if not is_finite(_elapsed) or _elapsed < 0.0:
		errors.append("scenario elapsed time must be finite and non-negative")
	if _state == STATE_RUNNING and _elapsed > scenario_time_limit:
		errors.append("a running scenario has outlived its unconditional time limit")
	if _state == STATE_RUNNING and _launched and _active_roster_count() == 0:
		errors.append("a running scenario retains no live participant")
	if _state != STATE_RUNNING and not _roster.is_empty():
		errors.append("a scenario that is not running still holds a dispatched roster")
	if _state == STATE_CONCLUDED and _outcome == OUTCOME_PENDING:
		errors.append("a concluded scenario must record a terminal outcome")
	if _state == STATE_RUNNING and _outcome != OUTCOME_PENDING:
		errors.append("a running scenario must not already record an outcome")
	return errors
