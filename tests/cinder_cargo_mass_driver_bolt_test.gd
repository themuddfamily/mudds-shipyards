extends SceneTree

## The Cinder cargo hauler's mass driver is a travelling bolt, not a hitscan.
##
## Proves the authored travel envelope, the fail-closed resolver conversion, and
## the live flight-ledger path GameFlow uses for the hauler: a launch commits
## nothing, the slug crosses the gap under its own travel, the authority commits
## exactly one hit on arrival, and reduced flash keeps the slug readable.

const Cargo := preload("res://scripts/ships/cinder_cargo_hauler.gd")
const MassDriverBoltPoolScript := preload("res://scripts/combat/mass_driver_bolt_pool.gd")
const ResolverProfile := preload("res://scripts/combat/weapon_definition_resolver_profile.gd")
const Layers := preload("res://scripts/core/physics_layers.gd")
const GameFlowScript := preload("res://scripts/game/game_flow.gd")

const PLAYER_FACTION: StringName = &"shipyard_flight_test"
const TARGET_HEALTH := 100.0
const TARGET_DISTANCE := 60.0

var _assertions := 0
var _failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var host := Node3D.new()
	host.name = "CargoMassDriverBoltHost"
	root.add_child(host)
	var cargo := Cargo.new() as CinderCargoHauler
	cargo.name = "CinderCargoHauler"
	host.add_child(cargo)
	await process_frame
	await physics_frame

	# Authored envelope.
	var definition := cargo.get_weapon_definition()
	_check(
		definition != null and definition.is_definition_valid()
			and definition.weapon_id == Cargo.WEAPON_ID,
		"the hauler publishes a valid mass-driver WeaponDefinition"
	)
	_check(
		definition.is_projectile_resolution() and definition.has_projectile_travel_envelope()
			and is_equal_approx(definition.projectile_speed_mps, Cargo.MASS_DRIVER_SPEED_MPS)
			and is_equal_approx(definition.projectile_lifetime_seconds, Cargo.MASS_DRIVER_LIFETIME_SECONDS)
			and is_equal_approx(definition.projectile_radius_meters, Cargo.MASS_DRIVER_RADIUS_METERS),
		"the PROJECTILE definition now carries a complete authored travel envelope"
	)
	_check(
		definition.projectile_speed_mps * definition.projectile_lifetime_seconds
			>= definition.range_meters - 0.001,
		"the slug can fly its whole registered range before its lifetime ends"
	)
	_check(
		is_equal_approx(definition.cadence_shots_per_second, 1.0 / cargo.weapon_cooldown),
		"the authored cadence matches the hull's own fire gate, so GameFlow's migration accepts it"
	)
	var profiles := ResolverProfile.to_resolver_profiles(
		definition, PLAYER_FACTION, GameFlowScript.CINDER_CARGO_ORIGIN_TOLERANCE_METERS
	)
	var profile := profiles.get(Cargo.WEAPON_ID, {}) as Dictionary
	_check(
		profiles.size() == 1 and ResolverProfile.profile_is_projectile(profile),
		"the fail-closed converter emits a travelling resolver profile for the mass driver"
	)
	_check(
		int(GameFlowScript.PLAYER_SOURCE_IDS.get(Cargo.COMPONENT_ID, 0)) == 1109
			and GameFlowScript.CINDER_CARGO_WEAPON_ID == Cargo.WEAPON_ID,
		"GameFlow registers the hauler as player source 1109 with the mass-driver identity"
	)

	# Live flight-ledger path.
	var authority := LiveCombatAuthority.new()
	authority.name = "CargoBoltAuthority"
	host.add_child(authority)
	var target_fixture := _make_target(host, cargo.global_position - cargo.global_basis.z * TARGET_DISTANCE)
	var target_health := target_fixture.damageable as Damageable
	var pool := MassDriverBoltPoolScript.new() as MassDriverBoltPool
	pool.name = "PlayerMassDriverBolts"
	pool.pool_capacity = 3
	host.add_child(pool)
	pool.bind_authority(authority)
	await process_frame
	await physics_frame
	await physics_frame
	_check(
		authority.register_source(cargo, 1109, PLAYER_FACTION, profiles),
		"the hauler registers its travelling weapon through the ordinary authority seam"
	)
	var origin := cargo.global_position - cargo.global_basis.z * 7.0
	var direction := ((target_fixture.entity as Node3D).global_position - origin).normalized()
	var launch := pool.launch(cargo, Cargo.WEAPON_ID, origin, direction)
	_check(
		bool(launch.get("accepted", false))
			and pool.get_active_bolt_count() == 1
			and authority.get_active_projectile_flight_count() == 1
			and is_equal_approx(target_health.get_health(), TARGET_HEALTH),
		"a trigger pull opens one authority flight and commits nothing instantly"
	)
	var record := pool.get_active_bolt_records()[0] as Dictionary
	_check(
		is_equal_approx(float(record.get("speed", 0.0)), Cargo.MASS_DRIVER_SPEED_MPS)
			and is_equal_approx(float(record.get("range", 0.0)), definition.range_meters),
		"the slug flies the envelope returned on the authority ticket"
	)
	var landed := false
	var frames := 0
	for _index in 240:
		if pool.get_active_bolt_count() == 0:
			landed = true
			break
		frames += 1
		await physics_frame
	_check(frames >= 2, "the slug takes real travel time to cross %.0f m" % TARGET_DISTANCE)
	_check(
		landed and is_equal_approx(target_health.get_health(), TARGET_HEALTH - definition.damage_per_hit),
		"the arrival commits exactly one mass-driver hit through the resolver"
	)
	_check(
		authority.get_active_projectile_flight_count() == 0
			and int(pool.get_statistics().get("resolved", 0)) == 1
			and bool(pool.get_audit_report().get("valid", false)),
		"no flight outlives the resolved slug and the pool audit stays green"
	)
	var reduced := pool.set_reduced_flash_enabled(true)
	_check(
		bool(reduced.get("reduced_flash", false))
			and not bool(reduced.get("dynamic_light_enabled", true)),
		"reduced flash drops the slug's moving light while keeping it drawn"
	)
	pool.set_reduced_flash_enabled(false)

	authority.forget_source(cargo, 1109)
	host.queue_free()
	await process_frame
	await process_frame
	_finish()


func _make_target(host: Node3D, position: Vector3) -> Dictionary:
	var area := Area3D.new()
	area.name = "MassDriverTarget"
	area.collision_layer = Layers.DAMAGEABLE_TARGET_AREA_LAYER
	area.collision_mask = Layers.DAMAGEABLE_TARGET_AREA_MASK
	host.add_child(area)
	area.global_position = position
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6.0, 6.0, 2.0)
	shape.shape = box
	area.add_child(shape)
	var damageable := Damageable.new()
	damageable.name = "Damageable"
	damageable.maximum_health = TARGET_HEALTH
	damageable.faction_id = &"range_defence"
	area.add_child(damageable)
	return {"entity": area, "damageable": damageable}


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("CINDER_CARGO_MASS_DRIVER_BOLT_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		print("CINDER_CARGO_MASS_DRIVER_BOLT_TEST_FAILED: ", "; ".join(_failures))
		quit(1)
