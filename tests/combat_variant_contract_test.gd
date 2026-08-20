extends SceneTree

const Contract := preload("res://scripts/combat/combat_variant_contract.gd")

var _failures := PackedStringArray()
var _assertions := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var contract := Contract.new()
	_check(contract.is_configuration_valid(), "the varied combat contract validates")
	var ids := contract.get_variant_ids()
	_check(ids.size() == 4, "the bounded slice exposes four encounter variants")
	var opponents := {}
	var weapons := {}
	var strategies := {}
	var objectives := {}
	for variant_id in ids:
		var variant := contract.get_variant(variant_id)
		_check(not variant.is_empty(), "each advertised variant has a detached definition")
		opponents[variant.opponent_id] = true
		weapons[variant.weapon.weapon_id] = true
		strategies[variant.strategy] = true
		objectives[variant.objective] = true
		_check(contract.is_low_friction_recovery(variant_id), "each variant keeps crash recovery low friction")
		var budget := contract.get_recovery_budget(variant_id)
		_check(
			float(budget.recovery_seconds) <= 3.0
			and float(budget.invulnerability_seconds) <= 1.0
			and float(budget.resume_seconds) <= 5.0,
			"each recovery budget remains short enough for arcade re-entry"
		)
	_check(opponents.size() == 4, "opponent identities are laterally distinct")
	_check(weapons.size() == 3, "repeater, lance and scatter weapons are represented")
	_check(strategies.size() == 4, "runner, standoff, press and flank tactics are represented")
	_check(objectives.size() == 3, "intercept, wing-break and protection objectives are represented")

	var courier := contract.evaluate(&"courier_repeater", 70.0, 0.98, 1.0)
	_check(
		bool(courier.accepted)
		and courier.action == &"fire"
		and courier.objective == Contract.OBJECTIVE_INTERCEPT,
		"the courier variant produces an aimed dispatch envelope for its objective"
	)
	var lance := contract.evaluate(&"picket_lance", 50.0, 0.99, 1.0)
	_check(lance.action == &"retreat", "the standoff lance keeps its close-range safety read")
	var flank := contract.evaluate(&"flanker_scatter", 60.0, 0.99, 1.0, false)
	_check(flank.action == &"flank" and not bool(flank.fire_authorized), "a safed flanker cannot bypass its role gate")
	_check(not bool(contract.evaluate(&"unknown", 1.0, 1.0, 1.0).accepted), "unknown variants fail closed")
	_check(not bool(contract.evaluate(&"courier_repeater", NAN, 1.0, 1.0).accepted), "invalid observations fail closed")

	var detached := contract.get_variant(&"courier_repeater")
	detached.weapon.range = 1.0
	detached.recovery.recovery_seconds = 99.0
	_check(
		float(contract.get_variant(&"courier_repeater").weapon.range) == 260.0
		and float(contract.get_recovery_budget(&"courier_repeater").recovery_seconds) == 1.5,
		"variant snapshots cannot mutate the catalog"
	)

	var snapshot := contract.get_snapshot()
	_check(snapshot.evidence.status == &"modern_interpretation", "authored combat breadth is not historical evidence")
	_check(
		not bool(snapshot.authority.combat_resolution)
		and not bool(snapshot.authority.damage)
		and not bool(snapshot.authority.damage_commit),
		"the variant contract owns no resolution or damage authority"
	)
	_check(
		snapshot.authority_chain.damage_commit_owner_count == 1
		and not bool(snapshot.authority_chain.duplicate_damage_authority)
		and snapshot.authority_chain.resolution_owner == &"combat_resolver",
		"one resolver and one damage adapter remain the only commit path"
	)
	_check(not bool(snapshot.authority.recovery), "recovery timing remains caller-owned")

	var invalid := Contract.new([{
		"variant_id": &"invalid_variant",
		"opponent_id": &"bad opponent",
		"scenario_id": &"bad scenario",
		"objective": &"unknown_objective",
		"strategy": &"unknown_strategy",
		"weapon": {"weapon_id": &"bad", "weapon_role": &"bad"},
		"tactics": {},
		"recovery": {"recovery_seconds": 8.0, "invulnerability_seconds": 4.0, "resume_seconds": 1.0},
	}])
	_check(not invalid.is_configuration_valid(), "invalid variant and recovery data fail closed")

	_finish()


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: combat variant contract (", _assertions, " assertions)")
		quit(0)
	else:
		for failure in _failures:
			push_error("FAIL: " + failure)
		quit(1)
