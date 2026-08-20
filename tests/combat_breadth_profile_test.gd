extends SceneTree

const Profile := preload("res://scripts/combat/combat_breadth_profile.gd")

var _failures := PackedStringArray()
var _assertions := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var profiles: Array = Profile.build_examples()
	_check(profiles.size() == 3, "the bounded catalog contains three detached loadout examples")
	var ids := {}
	var roles := {}
	for profile in profiles:
		_check(profile is Profile and profile.is_configuration_valid(), "each example validates without runtime authority")
		_check(not ids.has(profile.get_profile_id()), "profile IDs are unique")
		_check(not roles.has(profile.get_weapon_profile().weapon_role), "weapon roles are laterally distinct")
		ids[profile.get_profile_id()] = true
		roles[profile.get_weapon_profile().weapon_role] = true
		var snapshot: Dictionary = profile.get_snapshot()
		_check(snapshot.evidence.status == &"modern_interpretation", "combat breadth remains explicitly modern interpretation")
		_check(not bool(snapshot.authority.combat_resolution) and not bool(snapshot.authority.damage), "profile owns no combat or damage authority")
	_check(roles.size() == 3, "repeater, lance, and scatter roles remain distinct")

	var press: Profile = profiles[0]
	var fire := press.evaluate(70.0, 0.98, 1.0)
	_check(bool(fire.accepted) and fire.action == &"fire" and bool(fire.fire_authorized), "press repeater authorizes an aimed in-band shot")
	_check(fire.damage_per_shot == 9.0 and fire.cadence_shots_per_second == 5.5, "dispatch metadata carries the immutable repeater envelope")
	var lance: Profile = profiles[1]
	_check(lance.evaluate(50.0, 0.99, 1.0).action == &"retreat", "standoff lance rejects its too-close arming distance")
	_check(lance.evaluate(300.0, 0.99, 1.0).action == &"fire", "standoff lance fires only from its long preferred band")
	var scatter: Profile = profiles[2]
	_check(scatter.evaluate(60.0, 0.99, 1.0, false).action == &"flank", "safed flanker cannot skip its coordinator role gate")
	_check(scatter.evaluate(60.0, 0.99, 1.0).action == &"fire", "ready flanker can use its short-range scatter envelope")

	var mutable_weapon := {
		"weapon_id": &"mutating",
		"weapon_role": Profile.ROLE_REPEATER,
		"range": 200.0,
		"damage_per_shot": 10.0,
		"cadence_shots_per_second": 2.0,
		"spread_degrees": 1.0,
		"origin_tolerance": 20.0,
	}
	var mutable_tactics := {
		"engagement_range": 180.0,
		"preferred_engagement_distance": 70.0,
		"minimum_arming_range": 10.0,
		"aim_cosine": 0.9,
		"retreat_health_ratio": 0.2,
		"telegraph_time": 0.2,
		"weapon_cooldown": 0.5,
	}
	var detached := Profile.new(&"detached", &"test_opponent", mutable_weapon, &"press", mutable_tactics)
	mutable_weapon.range = 1.0
	mutable_tactics.engagement_range = 1.0
	_check(detached.is_configuration_valid(), "a complete custom breadth profile validates")
	_check(detached.get_weapon_profile().range == 200.0 and detached.get_tactic_profile().engagement_range == 180.0, "source dictionaries cannot mutate captured breadth data")
	var invalid_weapon := mutable_weapon.duplicate(true)
	invalid_weapon.weapon_role = &"unknown"
	var invalid := Profile.new(&"invalid", &"test_opponent", invalid_weapon, &"press", mutable_tactics)
	_check(not invalid.is_configuration_valid(), "unknown weapon roles fail closed")

	_finish()


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: combat breadth profile (", _assertions, " assertions)")
		quit(0)
	else:
		for failure in _failures:
			push_error("FAIL: " + failure)
		quit(1)
