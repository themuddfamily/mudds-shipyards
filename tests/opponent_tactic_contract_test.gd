extends SceneTree

const Contract := preload("res://scripts/combat/opponent_tactic_contract.gd")

var _failures := PackedStringArray()
var _assertions := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var weapon_profiles := {
		&"test_repeater": {
			"range": 220.0,
			"damage": 8.0,
			"origin_tolerance": 22.0,
		},
	}
	var tactics := {
		"engagement_range": 170.0,
		"preferred_engagement_distance": 52.0,
		"minimum_arming_range": 24.0,
		"aim_cosine": 0.9,
		"retreat_health_ratio": 0.2,
		"telegraph_time": 0.62,
		"weapon_cooldown": 1.55,
	}
	var contract = Contract.new(
		&"test_press",
		Contract.STRATEGY_PRESS,
		&"test_repeater",
		weapon_profiles[&"test_repeater"],
		tactics
	)
	_check(contract.is_configuration_valid(), "a resolver-backed weapon/tactic profile validates")
	_check(
		contract.evaluate(60.0, 0.98, 1.0).action == Contract.ACTION_FIRE,
		"an aimed target inside the envelope receives a deterministic fire intent"
	)
	_check(
		contract.evaluate(240.0, 0.98, 1.0).action == Contract.ACTION_CLOSE,
		"a distant target receives a close intent"
	)
	_check(
		contract.evaluate(10.0, 0.98, 1.0).action == Contract.ACTION_RETREAT,
		"a target inside the minimum band receives a retreat intent"
	)
	_check(
		contract.evaluate(60.0, 0.1, 1.0).action == Contract.ACTION_HOLD
			and not bool(contract.evaluate(60.0, 0.1, 1.0).fire_authorized),
		"an unaligned target cannot fire merely by being in range"
	)
	_check(
		contract.evaluate(80.0, 0.98, 0.1).action == Contract.ACTION_RETREAT,
		"low hull health takes priority over a valid firing solution"
	)
	var snapshot = contract.get_snapshot()
	weapon_profiles[&"test_repeater"].range = 9999.0
	tactics.engagement_range = 1.0
	_check(
		is_equal_approx(float(snapshot.weapon.range), 220.0)
			and is_equal_approx(float(contract.get_weapon_profile().range), 220.0)
			and is_equal_approx(float(contract.get_tactics_profile().engagement_range), 170.0),
		"the contract snapshots source dictionaries instead of retaining mutable aliases"
	)
	# Restore the caller-owned dictionaries before constructing the two other
	# archetypes; the preceding mutation is deliberately part of the alias test.
	weapon_profiles[&"test_repeater"].range = 220.0
	tactics.engagement_range = 170.0
	var flank := Contract.new(
		&"test_flank",
		Contract.STRATEGY_FLANK,
		&"test_repeater",
		weapon_profiles[&"test_repeater"],
		tactics
	)
	_check(
		flank.evaluate(60.0, 0.98, 1.0, false).action == Contract.ACTION_FLANK
			and not bool(flank.evaluate(60.0, 0.98, 1.0, false).fire_authorized),
		"a coordinator-safed flanker cannot fire"
	)
	var runner := Contract.new(
		&"test_runner",
		Contract.STRATEGY_RUNNER,
		&"test_repeater",
		weapon_profiles[&"test_repeater"],
		tactics
	)
	_check(
		runner.evaluate(60.0, 0.98, 1.0).action == Contract.ACTION_FIRE,
		"a runner keeps its escape motion policy while still allowing a rear deterrent shot"
	)
	_check(
		not Contract.new(&"bad tactic", Contract.STRATEGY_PRESS, &"test_repeater", weapon_profiles[&"test_repeater"], tactics).is_configuration_valid(),
		"unstable tactic IDs fail closed"
	)
	_check(
		not contract.evaluate(NAN, 0.9, 1.0).accepted
			and not contract.evaluate(80.0, 2.0, 1.0).accepted,
		"non-finite and out-of-domain observations are rejected"
	)
	_check(
		contract.get_snapshot().authority.combat_resolution == false
			and contract.get_snapshot().authority.damage == false,
		"the contract owns no combat or damage authority"
	)
	_finish()


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: opponent tactic contract (", _assertions, " assertions)")
		quit(0)
	else:
		for failure in _failures:
			push_error("FAIL: " + failure)
		quit(1)
