extends SceneTree

## Seeker torpedoes: hit, bounded turn, dodge, shoot-down and launcher loss.
##
## Every warhead is one flight on the live combat authority. This suite proves
## the three player-facing outcomes the torpedo boat exists for — a torpedo that
## reaches you hits once, a hard break across its nose makes it overshoot and
## miss, and a shot that destroys it cancels its hit — plus the bounded seeker
## turn rate and clean teardown when the launcher dies.

const TorpedoPoolScript := preload("res://scripts/combat/seeker_torpedo_projectile.gd")
const Layers := preload("res://scripts/core/physics_layers.gd")

const LAUNCHER_ID := 9601
const GUN_ID := 9602
const LAUNCHER_FACTION: StringName = &"range_defence"
const PLAYER_FACTION: StringName = &"shipyard_flight_test"
const WEAPON_ID: StringName = &"torpedo_boat_seeker"
const GUN_WEAPON_ID: StringName = &"test_fleet_gun"
const TORPEDO_PROFILE := {
	WEAPON_ID: {
		"range": 250.0,
		"damage": 34.0,
		"origin_tolerance": 14.0,
		"projectile_speed": 34.0,
		"projectile_lifetime": 7.5,
		"projectile_radius": 0.6,
	},
}
## The weakest fleet gun (the Cinder light repeater) deals 18 per shot.
const GUN_PROFILE := {GUN_WEAPON_ID: {"range": 400.0, "damage": 18.0, "origin_tolerance": 6.0}}
const TARGET_HEALTH := 200.0

var _assertions := 0
var _failures: PackedStringArray = []
var _intercepted: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var host := Node3D.new()
	host.name = "SeekerTorpedoHost"
	root.add_child(host)
	var authority := LiveCombatAuthority.new()
	authority.name = "CombatAuthority"
	host.add_child(authority)
	var launcher := _make_body(host, "Launcher", Vector3(0.0, 0.0, 0.0), Vector3(3.0, 2.0, 6.0), Layers.SHIP)
	var pool := TorpedoPoolScript.new() as SeekerTorpedoProjectile
	pool.name = "SeekerTorpedoes"
	pool.pool_capacity = 2
	# The pool must hang off its launcher so the resolver's source exclusion
	# covers the torpedo hurtboxes.
	launcher.add_child(pool)
	pool.bind_authority(authority)
	pool.torpedo_intercepted.connect(func(record: Dictionary) -> void: _intercepted.append(record))
	var target := _make_body(host, "Target", Vector3(0.0, 0.0, -60.0), Vector3(4.0, 3.0, 8.0), Layers.SHIP)
	var target_health := Damageable.new()
	target_health.name = "Damageable"
	target_health.maximum_health = TARGET_HEALTH
	target_health.faction_id = PLAYER_FACTION
	target.add_child(target_health)
	var gun := _make_body(host, "PlayerGun", Vector3(30.0, 0.0, -30.0), Vector3(1.0, 1.0, 1.0), Layers.SHIP)
	await process_frame
	await physics_frame
	await physics_frame
	_check(
		authority.register_source(launcher, LAUNCHER_ID, LAUNCHER_FACTION, TORPEDO_PROFILE)
			and authority.register_source(gun, GUN_ID, PLAYER_FACTION, GUN_PROFILE),
		"the launcher registers a travelling torpedo profile and the player gun a hitscan"
	)

	await _test_hit_and_bounded_turn(authority, pool, launcher, target, target_health)
	await _test_dodge(authority, pool, launcher, target, target_health)
	await _test_shoot_down(authority, pool, launcher, target, target_health, gun)
	await _test_launcher_loss(authority, pool, launcher, target)

	var reduced := pool.set_reduced_flash_enabled(true)
	_check(
		bool(reduced.get("reduced_flash", false))
			and not bool(reduced.get("dynamic_light_enabled", true))
			and not bool(reduced.get("flicker", true))
			and float(reduced.get("trail_length_meters", 99.0))
				< SeekerTorpedoProjectile.TRAIL_LENGTH_METERS,
		"reduced flash keeps torpedoes drawn, drops their light and trail, and nothing flickers"
	)
	_check(bool(pool.get_audit_report().get("valid", false)), "the torpedo pool audit is green after every case")
	host.queue_free()
	await process_frame
	await process_frame
	_finish()


func _test_hit_and_bounded_turn(
		authority: LiveCombatAuthority,
		pool: SeekerTorpedoProjectile,
		launcher: Node3D,
		target: Node3D,
		target_health: Damageable
	) -> void:
	target.global_position = Vector3(18.0, 0.0, -60.0)
	await physics_frame
	var origin := launcher.global_position + Vector3(0.0, 0.0, -5.0)
	var launch := pool.launch(launcher, WEAPON_ID, origin, Vector3.FORWARD, target)
	_check(
		bool(launch.get("accepted", false))
			and pool.get_active_torpedo_count() == 1
			and authority.get_active_projectile_flight_count() == 1
			and is_equal_approx(target_health.get_health(), TARGET_HEALTH),
		"a launch opens one authority flight and commits nothing instantly"
	)
	var max_turn_per_second := 0.0
	var previous_direction := Vector3.FORWARD
	var previous_elapsed := 0.0
	var steered := false
	for _index in 600:
		if pool.get_active_torpedo_count() == 0:
			break
		await physics_frame
		var records := pool.get_active_torpedo_records()
		if records.is_empty():
			break
		var record := records[0]
		var direction := record.get("direction", Vector3.FORWARD) as Vector3
		var elapsed := float(record.get("elapsed", 0.0))
		var dt := elapsed - previous_elapsed
		if dt > 0.0:
			var turned := rad_to_deg(previous_direction.angle_to(direction)) / dt
			max_turn_per_second = maxf(max_turn_per_second, turned)
			if turned > 1.0:
				steered = true
		previous_direction = direction
		previous_elapsed = elapsed
	_check(steered, "the torpedo steers toward a target off its launch line")
	_check(
		max_turn_per_second <= SeekerTorpedoProjectile.DEFAULT_TURN_RATE_DEGREES + 0.5,
		"the seeker never turns faster than its bounded %.0f deg/s (observed %.1f)"
			% [SeekerTorpedoProjectile.DEFAULT_TURN_RATE_DEGREES, max_turn_per_second]
	)
	_check(
		is_equal_approx(target_health.get_health(), TARGET_HEALTH - 34.0)
			and authority.get_active_projectile_flight_count() == 0
			and pool.get_active_torpedo_count() == 0,
		"a torpedo that reaches the target commits exactly one 34-point hit"
	)
	target_health.reset_health()


func _test_dodge(
		authority: LiveCombatAuthority,
		pool: SeekerTorpedoProjectile,
		launcher: Node3D,
		target: Node3D,
		target_health: Damageable
	) -> void:
	target.global_position = Vector3(0.0, 0.0, -80.0)
	await physics_frame
	var origin := launcher.global_position + Vector3(0.0, 0.0, -5.0)
	var launch := pool.launch(launcher, WEAPON_ID, origin, Vector3.FORWARD, target)
	_check(bool(launch.get("accepted", false)), "a second torpedo launches at a target dead ahead")
	# Let it arm and close, then break hard across and behind its nose.
	var broke := false
	for _index in 600:
		await physics_frame
		var records := pool.get_active_torpedo_records()
		if records.is_empty():
			break
		var record := records[0]
		var position := record.get("position", Vector3.ZERO) as Vector3
		if not broke and position.distance_to(target.global_position) < 22.0:
			var heading := record.get("direction", Vector3.FORWARD) as Vector3
			var lateral := Vector3.UP.cross(heading).normalized()
			target.global_position = position + lateral * 24.0 - heading * 6.0
			broke = true
	_check(broke, "the target breaks across the torpedo's nose at close range")
	var stats := pool.get_statistics()
	_check(
		is_equal_approx(target_health.get_health(), TARGET_HEALTH)
			and pool.get_active_torpedo_count() == 0
			and authority.get_active_projectile_flight_count() == 0,
		"the overshooting torpedo loses its lock and expires without a hit"
	)
	_check(int(stats.get("resolved", 0)) == 2, "the dodged torpedo still ends as an authoritative resolved miss")


func _test_shoot_down(
		authority: LiveCombatAuthority,
		pool: SeekerTorpedoProjectile,
		launcher: Node3D,
		target: Node3D,
		target_health: Damageable,
		gun: Node3D
	) -> void:
	target.global_position = Vector3(0.0, 0.0, -120.0)
	await physics_frame
	var origin := launcher.global_position + Vector3(0.0, 0.0, -5.0)
	var launch := pool.launch(launcher, WEAPON_ID, origin, Vector3.FORWARD, target)
	var slot_index := int(launch.get("slot_index", -1))
	_check(bool(launch.get("accepted", false)) and slot_index >= 0, "a third torpedo launches")
	for _index in 20:
		await physics_frame
	var hurtbox := pool.get_torpedo_hurtbox(slot_index)
	var shot_origin := gun.global_position
	var shot := authority.submit_hitscan(
		gun, GUN_WEAPON_ID, shot_origin, hurtbox.global_position - shot_origin
	)
	_check(
		bool(shot.get("damaged", false)) and bool(shot.get("destroyed", false)),
		"one fleet-gun hit destroys the torpedo through the ordinary resolver"
	)
	_check(
		_intercepted.size() == 1
			and pool.get_active_torpedo_count() == 0
			and authority.get_active_projectile_flight_count() == 0
			and int(pool.get_statistics().get("intercepted", 0)) == 1,
		"destroying the torpedo abandons its authority flight"
	)
	for _index in 300:
		await physics_frame
	_check(
		is_equal_approx(target_health.get_health(), TARGET_HEALTH),
		"a shot-down torpedo can never deliver its warhead"
	)
	_check(
		hurtbox.collision_layer == 0 and not pool.get_torpedo_damageable(slot_index).damage_enabled,
		"the freed slot stops exposing a hurtbox"
	)


func _test_launcher_loss(
		authority: LiveCombatAuthority,
		pool: SeekerTorpedoProjectile,
		launcher: Node3D,
		target: Node3D
	) -> void:
	target.global_position = Vector3(0.0, 0.0, -200.0)
	await physics_frame
	var origin := launcher.global_position + Vector3(0.0, 0.0, -5.0)
	pool.launch(launcher, WEAPON_ID, origin, Vector3.FORWARD, target)
	pool.launch(launcher, WEAPON_ID, origin + Vector3(2.0, 0.0, 0.0), Vector3.FORWARD, target)
	_check(pool.get_active_torpedo_count() == 2, "two torpedoes fill the bounded pool")
	var saturated := pool.launch(launcher, WEAPON_ID, origin, Vector3.FORWARD, target)
	_check(
		not bool(saturated.get("accepted", true))
			and StringName(saturated.get("status", &"")) == &"pool_saturated"
			and authority.get_active_projectile_flight_count() == 2,
		"a saturated pool refuses before opening a flight"
	)
	var abandoned := pool.abandon_source_torpedoes(launcher, &"launcher_destroyed")
	_check(
		abandoned == 2
			and pool.get_active_torpedo_count() == 0
			and authority.get_active_projectile_flight_count() == 0
			and pool.get_active_burst_count() == 2,
		"losing the launcher fizzles every torpedo it fired and leaves no flight behind"
	)
	for _index in 60:
		await physics_frame
	_check(pool.get_active_burst_count() == 0 and not pool.is_physics_processing(), "the fizzle bursts clear and the idle pool stops processing")


func _make_body(host: Node3D, body_name: String, position: Vector3, size: Vector3, layer: int) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.name = body_name
	body.collision_layer = layer
	body.collision_mask = 0
	host.add_child(body)
	body.global_position = position
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	return body


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("SEEKER_TORPEDO_PROJECTILE_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		print("SEEKER_TORPEDO_PROJECTILE_TEST_FAILED: ", "; ".join(_failures))
		quit(1)
