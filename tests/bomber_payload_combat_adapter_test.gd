extends SceneTree

## Focused integration for one bomber payload terminal through CombatResolver.
## The adapter owns no world query or health mutation; fixtures prove the
## existing resolver chain handles enemy, friendly, and occluding geometry once.

const Layers := preload("res://scripts/core/physics_layers.gd")
const DamageableType := preload("res://scripts/combat/damageable.gd")
const LiveAuthority := preload("res://scripts/combat/live_combat_authority.gd")
const Projectile := preload("res://scripts/combat/bomber_payload_projectile.gd")
const Adapter := preload("res://scripts/combat/bomber_payload_combat_adapter.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := Node3D.new()
	host.name = "BomberPayloadCombatAdapterFixture"
	root.add_child(host)
	var live_authority := LiveAuthority.new() as LiveCombatAuthority
	host.add_child(live_authority)
	var source := Node3D.new()
	source.name = "BomberSource"
	source.position = Vector3(0.0, 0.0, 10.0)
	host.add_child(source)
	var enemy := _make_damageable_body("Enemy", Vector3(0.0, 0.0, 0.0), &"raider", 40.0)
	host.add_child(enemy.entity)
	var friendly := _make_damageable_body("Friendly", Vector3(4.0, 0.0, 0.0), &"blue", 40.0)
	host.add_child(friendly.entity)
	await process_frame
	await physics_frame
	_check(
		live_authority.register_source(
			source,
			500,
			&"blue",
			{&"bomber_payload_release": {"range": 30.0, "damage": 20.0, "origin_tolerance": 20.0}}
		),
		"the resolver registers the bomber source and authoritative payload profile"
	)
	var adapter = Adapter.new(1)
	_check(bool(adapter.begin_generation(1).accepted), "the adapter starts its generation fence")
	var enemy_projectile := _terminal_projectile(1, 1, Vector3(0.0, 0.0, 0.0), false)
	var enemy_result: Dictionary = adapter.consume_terminal_intent(1, enemy_projectile, source, 500, live_authority)
	var resolved: Dictionary = enemy_result.get("resolver_result", {}) as Dictionary
	_check(
		bool(enemy_result.accepted)
			and enemy_result.reason == &"impact_resolved"
			and resolved.status == &"damaged"
			and is_equal_approx(float(enemy.damageable.get_health()), 20.0),
		"an enemy impact traverses the resolver and applies authoritative damage once"
	)
	_check(
		adapter.consume_terminal_intent(1, enemy_projectile, source, 500, live_authority).reason == &"duplicate_terminal_intent"
			and is_equal_approx(float(enemy.damageable.get_health()), 20.0),
		"the same terminal intent cannot damage or score twice"
	)

	var friendly_projectile := _terminal_projectile(1, 2, Vector3(4.0, 0.0, 0.0), false)
	var friendly_result: Dictionary = adapter.consume_terminal_intent(1, friendly_projectile, source, 500, live_authority)
	_check(
		bool(friendly_result.accepted)
			and friendly_result.resolver_result.status == &"friendly_fire_blocked"
			and is_equal_approx(float(friendly.damageable.get_health()), 40.0),
		"same-faction impact remains a physical blocker but is rejected by resolver policy"
	)

	var blocker := _make_body("WorldBlocker", Vector3(0.0, 0.0, 5.0), Layers.WORLD, 1.0)
	host.add_child(blocker)
	await physics_frame
	var occluded_projectile := _terminal_projectile(1, 3, Vector3(0.0, 0.0, 0.0), false)
	var occluded_result: Dictionary = adapter.consume_terminal_intent(1, occluded_projectile, source, 500, live_authority)
	_check(
		bool(occluded_result.accepted)
			and occluded_result.resolver_result.status == &"world_blocked"
			and is_equal_approx(float(enemy.damageable.get_health()), 20.0),
		"world occlusion wins before the endpoint target and prevents further damage"
	)
	blocker.queue_free()
	await physics_frame

	var expiry_projectile := _terminal_projectile(1, 4, Vector3(0.0, 0.0, 0.0), true)
	var expiry_result: Dictionary = adapter.consume_terminal_intent(1, expiry_projectile, source, 500, live_authority)
	_check(
		bool(expiry_result.accepted)
			and expiry_result.reason == &"expiry_forwarded"
			and adapter.get_snapshot().last_release_sequence == 4
			and live_authority.get_resolver().get_last_sequence(source, 500) == 3,
		"expiry is acknowledged without inventing a resolver damage request"
	)
	_check(adapter.consume_terminal_intent(2, expiry_projectile, source, 500, live_authority).reason == &"unauthorized_source", "a non-server adapter caller cannot consume terminals")

	_check(bool(adapter.detach(&"ship_reused").accepted), "adapter detach clears the consumed terminal ledger")
	_check(adapter.reset_for_reuse(1).reason == &"stale_generation", "adapter re-entry cannot reuse its old generation")
	_check(bool(adapter.reset_for_reuse(2).accepted), "adapter re-entry requires a newer generation")
	var stale_projectile := _terminal_projectile(1, 5, Vector3(0.0, 0.0, 0.0), false)
	_check(adapter.consume_terminal_intent(1, stale_projectile, source, 500, live_authority).reason == &"stale_generation", "old projectile generation cannot cross adapter re-entry")
	var fresh_projectile := _terminal_projectile(2, 5, Vector3(0.0, 0.0, 0.0), false)
	var fresh_result: Dictionary = adapter.consume_terminal_intent(1, fresh_projectile, source, 500, live_authority)
	_check(
		bool(fresh_result.accepted)
			and fresh_result.resolver_result.status == &"destroyed"
			and is_equal_approx(float(enemy.damageable.get_health()), 0.0),
		"the new generation accepts a fresh terminal and routes one final damage event"
	)

	host.queue_free()
	await process_frame
	if _failures.is_empty():
		print("PASS: bomber payload combat adapter (", _assertions, " assertions)")
		quit(0)
	else:
		for failure in _failures:
			push_error("FAIL: " + failure)
		quit(1)


func _terminal_projectile(generation: int, release_sequence: int, endpoint: Vector3, expiry: bool) -> BomberPayloadProjectile:
	var projectile := Projectile.new(1, Vector3.ZERO, 1.0, 100.0, 100.0) as BomberPayloadProjectile
	projectile.begin_generation(generation)
	projectile.consume_release_record(1, _release(generation, release_sequence))
	if expiry:
		projectile.advance(9.0)
	else:
		projectile.submit_impact(1, endpoint, Vector3.BACK)
	return projectile


func _release(generation: int, release_sequence: int) -> Dictionary:
	return {
		"schema_version": 1,
		"record_id": "bomber_payload_release_%06d" % release_sequence,
		"release_sequence": release_sequence,
		"generation": generation,
		"actor_id": &"bomber_gunner",
		"request_sequence": release_sequence,
		"payload_id": &"cinder_payload_alpha",
		"weapon_id": &"bomber_payload_release",
		"presentation_id": &"payload_release_flash",
		"audio_id": &"payload_release_audio",
		"release_position": Vector3(0.0, 0.0, 10.0),
		"release_velocity": Vector3(0.0, 0.0, -20.0),
		"ammunition_remaining": 3,
		"cooldown_remaining": 1.0,
	}


func _make_damageable_body(name: String, position: Vector3, faction: StringName, health: float) -> Dictionary:
	var body := _make_body(name, position, Layers.TARGET, 1.0)
	var damageable := DamageableType.new() as Damageable
	damageable.name = "Damageable"
	damageable.faction_id = faction
	damageable.maximum_health = health
	body.add_child(damageable)
	return {"entity": body, "collider": body, "damageable": damageable}


func _make_body(name: String, position: Vector3, layer: int, radius: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name
	body.position = position
	body.collision_layer = layer
	body.collision_mask = Layers.NONE
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	shape.shape = sphere
	body.add_child(shape)
	return body


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
