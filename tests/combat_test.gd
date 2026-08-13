extends SceneTree

const OPPONENT_SCENE := "res://scenes/ships/range_opponent.tscn"
const SHIP_LAYER := 1 << 2
const TARGET_LAYER := 1 << 5

var _failures: Array[String] = []
var _health_events: Array[Vector2] = []
var _destroyed_positions: Array[Vector3] = []
var _shots: Array[Dictionary] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var original_root_child_count := root.get_child_count()
	var host := Node3D.new()
	host.name = "CombatTestWorld"
	root.add_child(host)

	var packed := load(OPPONENT_SCENE) as PackedScene
	if packed == null:
		_fail("RangeOpponent scene loads")
		await _clean_up(host, null)
		_finish()
		return

	var opponent := packed.instantiate() as CharacterBody3D
	if opponent == null:
		_fail("RangeOpponent scene instantiates as CharacterBody3D")
		await _clean_up(host, null)
		_finish()
		return

	opponent.connect(&"projectile_fired", Callable(self, "_on_projectile_fired"))
	opponent.connect(&"health_changed", Callable(self, "_on_health_changed"))
	opponent.connect(&"destroyed", Callable(self, "_on_destroyed"))
	var target := _make_target()
	host.add_child(target)
	host.add_child(opponent)
	opponent.call("set_target", target)
	await process_frame
	await physics_frame

	# The packed defender is safe to keep in a live scene before its encounter.
	_check(not bool(opponent.call("is_active")), "opponent starts dormant")
	_check(not opponent.visible, "dormant opponent is hidden")
	_check(opponent.collision_layer == 0 and opponent.collision_mask == 0, "dormant opponent cannot collide")
	_check(is_zero_approx(float(opponent.call("get_health"))), "dormant opponent has no stale health")
	_check(opponent.get_node_or_null("RangeInterceptorVisual") != null, "opponent presentation is built while dormant")
	opponent.call("apply_damage", 10.0, Vector3(1.0, 2.0, 3.0))
	for _frame in 3:
		await physics_frame
	_check(_health_events.is_empty(), "dormant opponent ignores damage")
	_check(_shots.is_empty(), "dormant opponent cannot fire")

	# Activation restores all authoritative combat state and collision.
	var spawn := Transform3D(Basis(Vector3.UP, 0.35), Vector3(7.0, 12.0, -18.0))
	opponent.call("activate", spawn)
	var maximum_health := float(opponent.get("maximum_health"))
	_check(bool(opponent.call("is_active")), "activation enables the opponent")
	_check(opponent.visible, "activation reveals the opponent")
	_check(opponent.global_position.is_equal_approx(spawn.origin), "activation applies its world-space spawn")
	_check(
		opponent.collision_layer == SHIP_LAYER | TARGET_LAYER,
		"activation exposes both the physical ship and target collision layers"
	)
	_check(opponent.collision_mask == 1 | SHIP_LAYER, "activation collides with world and ships")
	_check(is_equal_approx(float(opponent.call("get_health")), maximum_health), "activation restores maximum health")
	_check(_health_events.size() == 1 and _health_event_matches(0, maximum_health, maximum_health), "activation reports restored health")

	var damage_sparks := opponent.get_node_or_null("DamageSparks") as CPUParticles3D
	var engine_smoke := opponent.get_node_or_null("EngineSmoke") as CPUParticles3D
	var visual_root := opponent.get_node_or_null("RangeInterceptorVisual") as Node3D
	_check(damage_sparks != null and not damage_sparks.emitting, "healthy stage has no damage sparks")
	_check(engine_smoke != null and not engine_smoke.emitting, "healthy stage has no engine smoke")

	# Damage progresses through readable healthy, damaged, and critical stages.
	var first_hit := opponent.global_position + Vector3(0.8, 0.3, -1.2)
	opponent.call("apply_damage", maximum_health * 0.4, first_hit)
	_check(is_equal_approx(float(opponent.call("get_health")), maximum_health * 0.6), "damage reduces authoritative health")
	_check(damage_sparks != null and damage_sparks.emitting, "damaged stage emits persistent sparks")
	_check(engine_smoke != null and not engine_smoke.emitting, "damaged stage does not enter critical smoke early")

	opponent.call("apply_damage", maximum_health * 0.3, first_hit + Vector3.UP)
	_check(is_equal_approx(float(opponent.call("get_health")), maximum_health * 0.3), "second hit reaches critical health")
	_check(damage_sparks != null and damage_sparks.emitting, "critical stage retains damage sparks")
	_check(engine_smoke != null and engine_smoke.emitting, "critical stage emits engine smoke")
	_check(_health_events.size() == 3, "each accepted damage event reports health")

	# A lethal hit disables the physical craft and leaves a staged debris burst.
	var death_position := opponent.global_position
	opponent.call("apply_damage", maximum_health, first_hit + Vector3.RIGHT)
	_check(is_zero_approx(float(opponent.call("get_health"))), "lethal damage clamps health to zero")
	_check(not bool(opponent.call("is_active")), "lethal damage deactivates the opponent")
	_check(opponent.collision_layer == 0 and opponent.collision_mask == 0, "destroyed opponent stops colliding")
	_check(visual_root != null and not visual_root.visible, "destroyed hull leaves active play immediately")
	_check(_destroyed_positions.size() == 1 and _destroyed_positions[0].is_equal_approx(death_position), "destruction reports its world position once")
	_check(opponent.get_node_or_null("InterceptorDestructionBurst") != null, "destruction creates a spark burst")
	_check(opponent.get_node_or_null("DestructionSmoke") != null, "destruction creates a smoke burst")
	_check(opponent.get_node_or_null("DestructionFlash") != null, "destruction creates a flash")
	_check(_count_debris(opponent) == 10, "destruction creates the complete physical debris stage")
	var events_after_destruction := _health_events.size()
	opponent.call("apply_damage", 1.0, death_position)
	_check(_health_events.size() == events_after_destruction and _destroyed_positions.size() == 1, "destroyed opponent ignores repeated damage")

	# Reactivation must synchronously remove death effects and produce a clean craft.
	var respawn_basis := Basis(Vector3.UP, -0.42).scaled(Vector3(1.3, 0.8, 1.1))
	var respawn := Transform3D(respawn_basis, Vector3(-11.0, 6.0, 9.0))
	opponent.call("activate", respawn)
	_check(bool(opponent.call("is_active")) and opponent.visible, "destroyed opponent can reactivate")
	_check(opponent.global_position.is_equal_approx(respawn.origin), "reactivation applies a new spawn")
	_check(is_equal_approx(absf(opponent.global_basis.determinant()), 1.0), "reactivation normalizes the spawn basis")
	_check(is_equal_approx(float(opponent.call("get_health")), maximum_health), "reactivation restores health")
	_check(visual_root != null and visual_root.visible, "reactivation restores the hull presentation")
	_check(damage_sparks != null and not damage_sparks.emitting and engine_smoke != null and not engine_smoke.emitting, "reactivation clears damage stages")
	_check(not _has_destruction_effects(opponent), "reactivation clears every destruction effect")

	# Pin translation while retaining the real attitude and weapon state machines.
	# Directly-above and directly-below targets exercise the polar look-up fallback.
	opponent.set("cruise_speed", 0.0)
	opponent.set("chase_speed", 0.0)
	opponent.set("turn_speed_degrees", 240.0)
	opponent.set("telegraph_time", 0.1)
	opponent.set("weapon_cooldown", 0.2)
	opponent.set("engagement_range", 100.0)
	var above_origin := opponent.global_position
	target.global_position = above_origin + Vector3.UP * 42.0
	await physics_frame
	var above_shot_index := _shots.size()
	var fired_above := await _wait_for_shot(above_shot_index, 120)
	_check(fired_above, "opponent fires at a target directly above")
	if fired_above:
		await process_frame
		_validate_vertical_shot(opponent, target, _shots[above_shot_index], 1.0, "above")
	_check(opponent.global_basis.x.is_finite() and opponent.global_basis.y.is_finite() and opponent.global_basis.z.is_finite(), "vertical tracking keeps a finite attitude basis")

	# Reset combat state so the opposite pole also starts with the normal charge.
	var below_origin := Vector3(14.0, 10.0, -6.0)
	opponent.call("activate", Transform3D(Basis.IDENTITY, below_origin))
	target.global_position = below_origin + Vector3.DOWN * 42.0
	await physics_frame
	var below_shot_index := _shots.size()
	var fired_below := await _wait_for_shot(below_shot_index, 120)
	_check(fired_below, "opponent fires at a target directly below")
	if fired_below:
		await process_frame
		_validate_vertical_shot(opponent, target, _shots[below_shot_index], -1.0, "below")
	_check(opponent.global_basis.x.is_finite() and opponent.global_basis.y.is_finite() and opponent.global_basis.z.is_finite(), "inverse vertical tracking keeps a finite attitude basis")

	await _clean_up(host, opponent)
	_check(root.get_child_count() == original_root_child_count, "combat fixture cleans up all scene nodes")
	_finish()


func _make_target() -> CharacterBody3D:
	var target := CharacterBody3D.new()
	target.name = "VerticalCombatTarget"
	target.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	target.collision_layer = SHIP_LAYER
	target.collision_mask = 0
	var collision := CollisionShape3D.new()
	collision.name = "TargetCollision"
	var sphere := SphereShape3D.new()
	sphere.radius = 2.5
	collision.shape = sphere
	target.add_child(collision)
	return target


func _wait_for_shot(starting_count: int, maximum_frames: int) -> bool:
	for _frame in maximum_frames:
		await physics_frame
		if _shots.size() > starting_count:
			return true
	return false


func _validate_vertical_shot(
	opponent: CharacterBody3D,
	target: CharacterBody3D,
	shot: Dictionary,
	vertical_sign: float,
	description: String
) -> void:
	var origin: Vector3 = shot.get("origin", Vector3.ZERO)
	var direction: Vector3 = shot.get("direction", Vector3.ZERO)
	var expected := (target.global_position - origin).normalized()
	_check(origin.is_finite() and direction.is_finite(), "%s shot has finite geometry" % description)
	_check(is_equal_approx(direction.length(), 1.0), "%s shot direction is normalized" % description)
	_check(direction.dot(expected) > 0.9999, "%s shot converges on the target center" % description)
	_check(direction.y * vertical_sign > 0.99, "%s shot preserves the vertical firing direction" % description)
	var query := PhysicsRayQueryParameters3D.create(
		origin,
		origin + direction * 100.0,
		SHIP_LAYER,
		[opponent.get_rid()]
	)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var hit := opponent.get_world_3d().direct_space_state.intersect_ray(query)
	_check(hit.get("collider") == target, "%s shot ray physically intersects its target" % description)


func _health_event_matches(index: int, current: float, maximum: float) -> bool:
	if index < 0 or index >= _health_events.size():
		return false
	return _health_events[index].is_equal_approx(Vector2(current, maximum))


func _count_debris(opponent: Node) -> int:
	var count := 0
	for child in opponent.get_children():
		if String(child.name).begins_with("HullDebris"):
			count += 1
	return count


func _has_destruction_effects(opponent: Node) -> bool:
	return (
		opponent.get_node_or_null("InterceptorDestructionBurst") != null
		or opponent.get_node_or_null("DestructionSmoke") != null
		or opponent.get_node_or_null("DestructionFlash") != null
		or _count_debris(opponent) > 0
	)


func _clean_up(host: Node, opponent: Node) -> void:
	if is_instance_valid(opponent) and opponent.has_method("deactivate"):
		opponent.call("deactivate")
	if is_instance_valid(host):
		host.queue_free()
	await process_frame
	await process_frame
	await process_frame


func _on_projectile_fired(origin: Vector3, direction: Vector3) -> void:
	_shots.append({"origin": origin, "direction": direction})


func _on_health_changed(current: float, maximum: float) -> void:
	_health_events.append(Vector2(current, maximum))


func _on_destroyed(position: Vector3) -> void:
	_destroyed_positions.append(position)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_fail(description)


func _fail(description: String) -> void:
	_failures.append(description)
	push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("COMBAT_TEST_OK")
		quit(0)
	else:
		print("COMBAT_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
