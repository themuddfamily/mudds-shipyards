extends SceneTree

const Catalog := preload("res://scripts/combat/combat_scenario_catalog.gd")

var _failures := PackedStringArray()
var _assertions := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog := Catalog.new()
	_check(catalog.is_configuration_valid(), "the authored scenario catalog validates")
	_check(catalog.get_scenario_ids().size() == 3, "the catalog has three bounded scenarios")
	_check(catalog.get_scenario_ids()[0] == &"courier_intercept", "courier intercept is the first deterministic sortie")
	_check(catalog.get_scenario_ids()[1] == &"paired_wing_break", "paired wing supplies a distinct second sortie")
	_check(catalog.get_scenario_ids()[2] == &"perimeter_hold", "perimeter hold supplies a distinct protection objective")

	var courier := catalog.get_scenario(&"courier_intercept")
	var wing := catalog.get_scenario(&"paired_wing_break")
	var hold := catalog.get_scenario(&"perimeter_hold")
	_check(courier.objective == Catalog.OBJECTIVE_INTERCEPT, "courier scenario exposes the intercept objective")
	_check(wing.objective == Catalog.OBJECTIVE_BREAK_WING, "wing scenario exposes the break-wing objective")
	_check(hold.objective == Catalog.OBJECTIVE_PROTECT_ASSET, "hold scenario exposes the protect-asset objective")
	_check(courier.roster.size() == 2 and wing.roster.size() == 2 and hold.roster.size() == 3, "each scenario has a fixed, bounded roster")
	_check(courier.roster.has(&"standoff_lance") and courier.roster.has(&"press_repeater"), "intercept mixes standoff and press profiles")
	_check(wing.roster.has(&"press_repeater") and wing.roster.has(&"flank_scatter"), "paired wing mixes press and flank profiles")
	_check(hold.roster.has(&"standoff_lance") and hold.roster.has(&"flank_scatter"), "hold scenario keeps long-range and flank variety")

	_check(catalog.get_profile_snapshot(&"standoff_lance").tactics.preferred_engagement_distance == 300.0, "scenario profiles retain their standoff distance")
	_check(catalog.get_profile_snapshot(&"flank_scatter").weapon.weapon_role == &"scatter", "scenario profiles retain their weapon role")
	_check(catalog.get_profile_snapshot(&"missing").is_empty(), "unknown profiles fail closed")
	_check(catalog.select_scenario(0).id == catalog.select_scenario(3).id, "sortie selection wraps deterministically")
	_check(catalog.select_scenario(-1).is_empty(), "negative sortie indexes fail closed")
	_check(catalog.select_scenario(0).id != catalog.select_scenario(1).id, "adjacent sorties are not the same encounter")

	var detached := catalog.get_scenario(&"courier_intercept")
	detached.roster.clear()
	_check(catalog.get_scenario(&"courier_intercept").roster.size() == 2, "scenario snapshots cannot mutate catalog state")

	var pending := catalog.evaluate(&"courier_intercept", {
		"elapsed_seconds": 10.0,
		"runner_distance": 100.0,
		"runner_captured": false,
	})
	_check(bool(pending.accepted) and pending.outcome == Catalog.OUTCOME_PENDING, "an active intercept remains pending")
	_check(catalog.evaluate(&"courier_intercept", {"runner_captured": true}).outcome == Catalog.OUTCOME_CLEARED, "capturing the runner clears the intercept")
	_check(catalog.evaluate(&"courier_intercept", {"runner_distance": 1400.0}).outcome == Catalog.OUTCOME_ESCAPED, "a runner crossing its boundary escapes")
	_check(catalog.evaluate(&"paired_wing_break", {"targets_destroyed": 2}).outcome == Catalog.OUTCOME_CLEARED, "destroying the full wing clears the wing objective")
	_check(catalog.evaluate(&"perimeter_hold", {"elapsed_seconds": 90.0, "protected_health_ratio": 1.0}).outcome == Catalog.OUTCOME_CLEARED, "holding the perimeter through its duration clears it")
	_check(catalog.evaluate(&"perimeter_hold", {"protected_health_ratio": 0.2}).outcome == Catalog.OUTCOME_LOST, "a breached protected asset loses the hold objective")
	_check(catalog.evaluate(&"courier_intercept", {"player_alive": false}).outcome == Catalog.OUTCOME_ABORTED, "player destruction aborts the scenario")
	_check(catalog.evaluate(&"courier_intercept", {"phase_authorized": false}).outcome == Catalog.OUTCOME_WITHDRAWN, "leaving the authorized phase withdraws the scenario")
	_check(catalog.evaluate(&"courier_intercept", {"disengaged": true}).outcome == Catalog.OUTCOME_WITHDRAWN, "explicit disengagement withdraws the scenario")
	_check(catalog.evaluate(&"paired_wing_break", {"elapsed_seconds": 150.0}).outcome == Catalog.OUTCOME_EXPIRED, "an unmet objective reaches its time backstop")
	_check(not bool(catalog.evaluate(&"unknown", {}).accepted), "unknown scenario IDs are rejected")
	_check(not bool(catalog.evaluate(&"courier_intercept", {"elapsed_seconds": NAN}).accepted), "non-finite observations are rejected")

	var snapshot := catalog.get_snapshot()
	_check(snapshot.evidence.status == &"modern_interpretation", "the catalog does not authenticate historical combat content")
	_check(not bool(snapshot.authority.combat_resolution) and not bool(snapshot.authority.damage) and not bool(snapshot.authority.phase), "the catalog owns no gameplay authority")

	_finish()


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: combat scenario catalog (", _assertions, " assertions)")
		quit(0)
	else:
		for failure in _failures:
			push_error("FAIL: " + failure)
		quit(1)
