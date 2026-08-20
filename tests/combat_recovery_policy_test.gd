extends SceneTree

const Policy := preload("res://scripts/combat/combat_recovery_policy.gd")
var _failures: Array[String] = []
var _assertions := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var policy = Policy.new(2.0, 0.75)
	_check(policy.get_validation_errors().is_empty(), "default recovery window validates")
	_check(bool(policy.begin(1).get("accepted", false)), "a new crash generation starts recovery")
	_check(policy.is_invulnerable(), "early recovery is invulnerable")
	_check(not bool(policy.begin(1).get("accepted", true)), "duplicate generation cannot restart recovery")
	_check(not bool(policy.tick(0.1, 0).get("accepted", true)), "stale generation cannot advance recovery")
	_check(bool(policy.tick(0.75, 1).get("accepted", false)) and not policy.is_invulnerable(), "invulnerability ends at its bounded window")
	_check(bool(policy.tick(1.25, 1).get("accepted", false)) and policy.is_ready(), "recovery becomes ready at the exact budget")
	_check(not bool(policy.tick(0.1, 1).get("accepted", true)), "a ready generation cannot accumulate time twice")
	_check(bool(policy.begin(2).get("accepted", false)), "a later lifecycle generation can recover independently")
	_check(policy.get_snapshot().get("generation", 0) == 2, "snapshot is generation-bound and detached")
	_finish()

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)

func _finish() -> void:
	if _failures.is_empty():
		print("PASS: combat recovery policy (", _assertions, " assertions)")
		quit(0)
	else:
		for failure in _failures:
			push_error("FAIL: " + failure)
		quit(1)
