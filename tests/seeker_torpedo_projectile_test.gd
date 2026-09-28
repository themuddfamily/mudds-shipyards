extends SceneTree

## Seeker torpedoes: hit, bounded turn, dodge, shoot-down and launcher loss.
##
## Every warhead is one flight on the live combat authority. This suite proves
## the three player-facing outcomes the torpedo boat exists for — a torpedo that
## reaches you hits once, a hard break across its nose makes it overshoot and
## miss, and a shot that destroys it cancels its hit — plus the bounded seeker
## turn rate and clean teardown when the launcher dies. A ship-shaped target
## whose boarding sphere sits off its hull proves the seeker aims and fuses on
## the strikable hull, never on an interaction volume the resolver cannot hit.

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
	await _test_offset_interaction_volume(authority, pool, launcher, host, target)
	await _test_proximity_fuse_near_miss(authority, pool, launcher, host, target_health)
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


## Production hero ships carry a 4.5 m ShipBoardingArea sphere offset from the
## hull on the INTERACTABLE layer, which the hitscan resolver never queries. A
## torpedo arriving from that side must still steer at and strike the hull.
func _test_offset_interaction_volume(
		authority: LiveCombatAuthority,
		pool: SeekerTorpedoProjectile,
		launcher: Node3D,
		host: Node3D,
		original_target: Node3D
	) -> void:
	original_target.global_position = Vector3(200.0, 0.0, 200.0)
	var ship := CharacterBody3D.new()
	ship.name = "BoardableShip"
	ship.collision_layer = Layers.SHIP
	ship.collision_mask = 0
	# The boarding volume is added before the hull, as on the production ships,
	# so a first-shape search would pick it.
	var boarding := Area3D.new()
	boarding.name = "ShipBoardingArea"
	boarding.collision_layer = Layers.INTERACTABLE_AREA_LAYER
	boarding.collision_mask = Layers.INTERACTABLE_AREA_MASK
	boarding.position = Vector3(0.0, 0.0, 6.0)
	ship.add_child(boarding)
	var boarding_shape := CollisionShape3D.new()
	boarding_shape.name = "BoardingRange"
	var sphere := SphereShape3D.new()
	sphere.radius = 4.5
	boarding_shape.shape = sphere
	boarding.add_child(boarding_shape)
	var hull_shape := CollisionShape3D.new()
	hull_shape.name = "HullCollision"
	var hull_box := BoxShape3D.new()
	hull_box.size = Vector3(4.0, 3.0, 8.0)
	hull_shape.shape = hull_box
	ship.add_child(hull_shape)
	var ship_health := Damageable.new()
	ship_health.name = "Damageable"
	ship_health.maximum_health = TARGET_HEALTH
	ship_health.faction_id = PLAYER_FACTION
	ship.add_child(ship_health)
	host.add_child(ship)
	# The boarding sphere faces the launcher: its centre is 6 m nearer than the
	# hull's, and the hull's near face is 2 m beyond the sphere centre.
	ship.global_position = Vector3(0.0, 0.0, -70.0)
	await physics_frame
	await physics_frame

	var aim := pool.call(&"_find_aim_shape", ship) as WeakRef
	_check(
		aim != null and aim.get_ref() == hull_shape,
		"the seeker aims at the hull body, not the off-hull boarding sphere"
	)
	var volume_only := Node3D.new()
	volume_only.name = "VolumeOnlyTarget"
	var lone_area := Area3D.new()
	lone_area.collision_layer = Layers.INTERACTABLE_AREA_LAYER
	volume_only.add_child(lone_area)
	var lone_shape := CollisionShape3D.new()
	lone_shape.shape = SphereShape3D.new()
	lone_area.add_child(lone_shape)
	host.add_child(volume_only)
	_check(
		pool.call(&"_find_aim_shape", volume_only) == null,
		"a target with only interaction volumes falls back to its own origin"
	)
	volume_only.queue_free()

	var resolved: Array[Dictionary] = []
	var on_resolved := func(record: Dictionary, result: Dictionary) -> void:
		resolved.append({"record": record, "result": result})
	pool.torpedo_resolved.connect(on_resolved)
	var origin := launcher.global_position + Vector3(0.0, 0.0, -5.0)
	var launch := pool.launch(launcher, WEAPON_ID, origin, Vector3.FORWARD, ship)
	_check(bool(launch.get("accepted", false)), "a torpedo launches at the boardable ship")
	for _index in 600:
		if pool.get_active_torpedo_count() == 0:
			break
		await physics_frame
	pool.torpedo_resolved.disconnect(on_resolved)
	_check(
		resolved.size() == 1
			and bool((resolved[0].result as Dictionary).get("damaged", false))
			and is_equal_approx(ship_health.get_health(), TARGET_HEALTH - 34.0)
			and authority.get_active_projectile_flight_count() == 0,
		"a torpedo arriving on the boarding-sphere side still strikes the hull once"
	)
	ship.queue_free()
	await physics_frame


## A target with no strikable body uses its origin for seeking. Reaching that
## origin must resolve a miss, without suggesting damage through a full burst.
func _test_proximity_fuse_near_miss(
		authority: LiveCombatAuthority,
		pool: SeekerTorpedoProjectile,
		launcher: Node3D,
		host: Node3D,
		original_health: Damageable
	) -> void:
	var target := Node3D.new()
	target.name = "NearMissTarget"
	host.add_child(target)
	target.global_position = Vector3(0.0, 0.0, -60.0)
	var health := Damageable.new()
	health.name = "Damageable"
	health.maximum_health = TARGET_HEALTH
	health.faction_id = PLAYER_FACTION
	target.add_child(health)
	var original_health_before := original_health.get_health()
	var resolved: Array[Dictionary] = []
	var on_resolved := func(record: Dictionary, result: Dictionary) -> void:
		resolved.append({
			"record": record, "result": result,
			"bursts": pool.get_active_burst_count(),
		})
	pool.torpedo_resolved.connect(on_resolved)
	for reduced_flash in [false, true]:
		pool.set_reduced_flash_enabled(reduced_flash)
		resolved.clear()
		var origin := launcher.global_position + Vector3(0.0, 0.0, -5.0)
		var launch := pool.launch(launcher, WEAPON_ID, origin, Vector3.FORWARD, target)
		_check(bool(launch.get("accepted", false)), "a torpedo launches at an origin without a strikable body")
		for _index in 600:
			if pool.get_active_torpedo_count() == 0:
				break
			await physics_frame
		_check(
			resolved.size() == 1
				and StringName((resolved[0].record as Dictionary).get("terminal_reason", &"")) == &"proximity_fuse"
				and bool((resolved[0].result as Dictionary).get("resolved", false))
				and not bool((resolved[0].result as Dictionary).get("damaged", true))
				and not bool((resolved[0].result as Dictionary).get("hit", true)),
			"an origin-only target produces one authoritative proximity-fuse miss"
		)
		_check(
			is_equal_approx(health.get_health(), TARGET_HEALTH)
				and is_equal_approx(original_health.get_health(), original_health_before)
				and pool.get_active_torpedo_count() == 0
				and authority.get_active_projectile_flight_count() == 0,
			"a proximity-fuse miss changes no health and releases its flight"
		)
		_check(
			resolved.size() == 1 and int(resolved[0].bursts) == 0
				and pool.get_active_burst_count() == 0,
			"a proximity-fuse miss shows no burst (reduced flash: %s)" % reduced_flash
		)
	pool.torpedo_resolved.disconnect(on_resolved)
	pool.set_reduced_flash_enabled(false)
	target.queue_free()
	await physics_frame


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
