extends SceneTree

const Layers := preload("res://scripts/core/physics_layers.gd")
const ShotRequestScript := preload("res://scripts/combat/shot_request.gd")
const DamageableScript := preload("res://scripts/combat/damageable.gd")
const CombatResolverScript := preload("res://scripts/combat/combat_resolver.gd")

const SOURCE_ID := 9001
const SOURCE_FACTION: StringName = &"keth"

var _failures: Array[String] = []
var _damage_events: Array[Dictionary] = []
var _destruction_events: Array[Dictionary] = []
var _reset_events: Array[Vector2] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var original_root_child_count := root.get_child_count()
	var host := Node3D.new()
	host.name = "CombatResolverTestWorld"
	root.add_child(host)

	var resolver := CombatResolverScript.new() as CombatResolver
	resolver.name = "AuthorityCombatResolver"
	host.add_child(resolver)

	var shooter := _make_compound_shooter("Shooter", Vector3(0.0, 0.0, 8.0))
	host.add_child(shooter)
	var second_shooter := Node3D.new()
	second_shooter.name = "SecondShooter"
	second_shooter.position = Vector3(50.0, 0.0, 8.0)
	host.add_child(second_shooter)
	var enemy_body_fixture := _make_damageable_body(
		"EnemyBody", Vector3.ZERO, &"raider", 40.0
	)
	host.add_child(enemy_body_fixture.entity)
	var enemy_area_fixture := _make_damageable_area(
		"EnemyAreaEntity", Vector3(5.0, 0.0, 0.0), &"raider", 30.0
	)
	host.add_child(enemy_area_fixture.entity)
	var friendly_fixture := _make_damageable_body(
		"FriendlyBody", Vector3(-5.0, 0.0, 0.0), SOURCE_FACTION, 35.0
	)
	host.add_child(friendly_fixture.entity)
	var occluded_fixture := _make_damageable_body(
		"OccludedBody", Vector3(10.0, 0.0, -2.0), &"raider", 25.0
	)
	host.add_child(occluded_fixture.entity)
	var world_blocker := _make_body(
		"WorldBlocker", Vector3(5.0, 0.0, 3.0), Layers.WORLD, 1.2
	)
	host.add_child(world_blocker)

	var enemy_body := enemy_body_fixture.damageable as Damageable
	var enemy_area := enemy_area_fixture.damageable as Damageable
	var friendly := friendly_fixture.damageable as Damageable
	var occluded := occluded_fixture.damageable as Damageable
	enemy_body.damage_applied.connect(_on_damage_applied)
	enemy_body.destroyed.connect(_on_destroyed)
	enemy_body.reset.connect(_on_reset)

	await process_frame
	await physics_frame
	await physics_frame

	var weapon_profiles := {
		&"pulse_cannon": {
			"range": 30.0,
			"damage": 20.0,
			"origin_tolerance": 2.0,
		}
	}
	_check(
		resolver.register_source(SOURCE_ID, shooter, SOURCE_FACTION, weapon_profiles),
		"authority registers source identity, collision root, faction, and weapon profile"
	)
	_test_request_contract(shooter)
	var null_result := resolver.resolve_hitscan(null)
	_check(null_result.status == &"invalid_request" and not null_result.accepted, "null request returns a structured validation rejection")
	for required_key: String in [
		"accepted", "resolved", "hit", "damaged", "destroyed", "status", "reason",
		"request", "collider", "damageable", "target_entity", "position", "normal",
		"distance", "applied_damage", "remaining_health", "last_sequence",
		"source_entity", "source_id", "source_faction_id", "target_faction_id",
		"damage_result",
	]:
		_check(null_result.has(required_key), "structured result always defines '%s'" % required_key)
	resolver.set_multiplayer_authority(2)
	var denied := resolver.resolve_hitscan(_shot(shooter, 1, Vector3.ZERO))
	_check(denied.status == &"not_authority" and not denied.accepted, "non-authority resolver cannot resolve hitscan")
	resolver.set_multiplayer_authority(1)
	_check(resolver.get_tracked_source_count() == 0, "authority rejection cannot consume source sequence")

	# A world-layer collider is authoritative occlusion even with a valid target
	# directly behind it.
	var blocked_request := _shot(shooter, 1, occluded_fixture.collider.global_position)
	blocked_request.source_entity = null
	var blocked := resolver.resolve_hitscan(blocked_request)
	_check(blocked.accepted and blocked.hit, "valid authority request resolves a physical hit")
	_check(blocked.source_entity == shooter and blocked.source_faction_id == SOURCE_FACTION, "ID-only request resolves its authority-owned source context")
	_check(blocked.status == &"world_blocked", "world geometry blocks the target behind it")
	_check(blocked.collider == world_blocker, "world blocker is the nearest collider")
	_check(is_equal_approx(occluded.get_health(), 25.0), "world-occluded damageable receives no damage")

	# The source ray begins inside the shooter's own body. Exclusion must still
	# reach the arbitrary Damageable component attached to the target body.
	var body_hit := resolver.resolve_hitscan(_shot(shooter, 2, enemy_body_fixture.collider.global_position))
	_check(body_hit.status == &"damaged" and body_hit.collider == enemy_body_fixture.collider, "compound shooter body and sibling hurtbox are excluded from hitscan")
	_check(body_hit.damageable == enemy_body and body_hit.target_entity == enemy_body_fixture.collider, "body-owned damageable resolves generically")
	_check(is_equal_approx(enemy_body.get_health(), 20.0), "body target receives authoritative damage")
	_check(body_hit.applied_damage == 20.0 and body_hit.remaining_health == 20.0, "structured result reports applied damage and health")

	# Equal and older sequences are rejected before physics or damage. A lethal
	# newer request then proves destruction is emitted only once.
	var duplicate := resolver.resolve_hitscan(_shot(shooter, 2, enemy_body_fixture.collider.global_position))
	var out_of_order := resolver.resolve_hitscan(_shot(shooter, 1, enemy_body_fixture.collider.global_position))
	_check(duplicate.status == &"duplicate_sequence" and not duplicate.accepted, "duplicate source sequence is rejected")
	_check(out_of_order.status == &"out_of_order_sequence" and not out_of_order.accepted, "out-of-order source sequence is rejected")
	_check(is_equal_approx(enemy_body.get_health(), 20.0), "replayed sequences cannot apply damage")
	var lethal := resolver.resolve_hitscan(_shot(shooter, 3, enemy_body_fixture.collider.global_position))
	_check(lethal.status == &"destroyed" and lethal.destroyed, "lethal result reports target destruction")
	_check(enemy_body.is_destroyed() and is_zero_approx(enemy_body.get_health()), "damageable clamps lethal health to zero")
	_check(_damage_events.size() == 2 and _destruction_events.size() == 1, "damage and destruction signals fire exactly once per accepted hit")
	if not _destruction_events.is_empty():
		var death := _destruction_events[0]
		_check(death.source.source_id == SOURCE_ID and death.source.weapon_id == &"pulse_cannon", "destruction signal preserves source context")
		_check((death.position as Vector3).is_finite() and (death.normal as Vector3).is_finite(), "destruction signal preserves finite world hit geometry")

	enemy_body.reset_health(60.0)
	_check(not enemy_body.is_destroyed() and is_equal_approx(enemy_body.get_health(), 60.0), "reset re-arms a destroyed damageable at its new maximum")
	_check(_reset_events.size() == 1 and _reset_events[0].is_equal_approx(Vector2(60.0, 60.0)), "reset lifecycle emits restored health")
	_check(enemy_body.get_last_hit_context().position == Vector3.INF, "reset clears stale hit context")

	# The second arbitrary fixture attaches its component beside a nested Area3D,
	# proving owner/area lookup does not depend on a specific target script.
	var area_hit := resolver.resolve_hitscan(_shot(shooter, 4, enemy_area_fixture.collider.global_position))
	_check(area_hit.status == &"damaged" and area_hit.collider == enemy_area_fixture.collider, "hitscan queries Area3D hurtboxes")
	_check(area_hit.damageable == enemy_area and area_hit.target_entity == enemy_area_fixture.entity, "sibling damageable resolves through the area owner hierarchy")
	_check(is_equal_approx(enemy_area.get_health(), 10.0), "area-owned target receives damage")

	# Same-faction targets remain physical blockers but are only damaged when the
	# resolver (or an individual call) explicitly enables friendly fire.
	var friendly_request := _shot(shooter, 5, friendly_fixture.collider.global_position)
	friendly_request.faction_id = &""
	var friendly_block := resolver.resolve_hitscan(friendly_request)
	_check(friendly_block.status == &"friendly_fire_blocked" and friendly_block.hit, "friendly target blocks while friendly fire is disabled")
	_check(friendly_block.source_faction_id == SOURCE_FACTION, "empty request faction is replaced by registered authority faction")
	_check(is_equal_approx(friendly.get_health(), 35.0), "friendly-fire rejection preserves health")
	resolver.allow_friendly_fire = true
	var friendly_hit := resolver.resolve_hitscan(_shot(shooter, 6, friendly_fixture.collider.global_position))
	_check(friendly_hit.status == &"damaged" and is_equal_approx(friendly.get_health(), 15.0), "authority-owned friendly-fire option applies damage")
	resolver.allow_friendly_fire = false

	# Malformed high-sequence input never advances the replay ledger. A lower,
	# valid follow-up remains accepted and simply misses empty space.
	var invalid := _shot(shooter, 100, Vector3(20.0, 0.0, 0.0))
	invalid.direction = Vector3.ZERO
	var invalid_result := resolver.resolve_hitscan(invalid)
	_check(invalid_result.status == &"invalid_request" and not invalid_result.accepted, "invalid request is rejected before resolution")
	_check(resolver.get_last_sequence(shooter, SOURCE_ID) == 6, "invalid request does not consume its sequence")
	var spoofed := _shot(shooter, 100, Vector3(20.0, 0.0, 0.0))
	spoofed.damage = 2000.0
	var spoofed_result := resolver.resolve_hitscan(spoofed)
	_check(spoofed_result.status == &"weapon_data_mismatch" and not spoofed_result.accepted, "authority rejects spoofed weapon damage")
	var remote_origin := _shot(shooter, 100, Vector3(20.0, 0.0, 0.0))
	remote_origin.origin = Vector3(1000.0, 0.0, 0.0)
	var remote_result := resolver.resolve_hitscan(remote_origin)
	_check(remote_result.status == &"origin_out_of_bounds" and not remote_result.accepted, "authority rejects shots outside source origin envelope")
	var miss := resolver.resolve_hitscan(_shot(shooter, 7, Vector3(20.0, 0.0, 0.0)))
	_check(miss.status == &"miss" and miss.accepted and not miss.hit, "valid unobstructed ray returns a structured miss")
	_check(resolver.get_last_sequence(shooter, SOURCE_ID) == 7, "new valid request advances source ledger")
	_check(resolver.get_tracked_source_count() == 1, "one source owns one node-scoped ledger entry")
	_check(
		resolver.register_source(SOURCE_ID + 1, second_shooter, &"allied", weapon_profiles),
		"second physical source receives an independent authority registration"
	)
	var independent_source := _shot(second_shooter, 0, Vector3(60.0, 0.0, 0.0))
	independent_source.source_id = SOURCE_ID + 1
	independent_source.faction_id = &"allied"
	var independent_result := resolver.resolve_hitscan(independent_source)
	_check(independent_result.status == &"miss" and independent_result.accepted, "another source may begin its own monotonic sequence")
	_check(resolver.get_tracked_source_count() == 2, "sequence history is partitioned per source")

	# Tree removal is a streaming boundary, not identity retirement. The live
	# registration disappears, but the exact source may re-register and its
	# captured request remains stale.
	host.remove_child(second_shooter)
	await process_frame
	_check(
		resolver.get_registered_source_count() == 1
		and resolver.get_tracked_source_count() == 2
		and resolver.get_last_sequence(null, SOURCE_ID + 1) == 0,
		"temporary source exit drops only its live registration"
	)
	var identity_impostor := Node3D.new()
	identity_impostor.name = "IdentityImpostor"
	host.add_child(identity_impostor)
	_check(
		not resolver.register_source(
			SOURCE_ID + 1, identity_impostor, &"allied", weapon_profiles
		),
		"a different live instance cannot take over a temporarily detached identity"
	)
	identity_impostor.queue_free()
	await process_frame
	host.add_child(second_shooter)
	await process_frame
	_check(
		resolver.register_source(SOURCE_ID + 1, second_shooter, &"allied", weapon_profiles),
		"the same physical source can restore its authority registration"
	)
	var reentry_replay := resolver.resolve_hitscan(independent_source)
	_check(
		reentry_replay.status == &"duplicate_sequence" and not reentry_replay.accepted,
		"a captured pre-exit request remains rejected after same-instance re-entry"
	)
	var post_reentry := _shot(second_shooter, 1, Vector3(60.0, 0.0, 0.0))
	post_reentry.source_id = SOURCE_ID + 1
	post_reentry.faction_id = &"allied"
	_check(
		resolver.resolve_hitscan(post_reentry).accepted
		and resolver.get_last_sequence(second_shooter, SOURCE_ID + 1) == 1,
		"same-instance re-entry resumes at the next monotonic sequence"
	)

	var ephemeral_source := Node3D.new()
	ephemeral_source.name = "EphemeralEntityOnlySource"
	ephemeral_source.position = Vector3(80.0, 0.0, 8.0)
	host.add_child(ephemeral_source)
	_check(
		resolver.register_source(0, ephemeral_source, &"neutral_test", weapon_profiles),
		"entity-only source can be authority-registered without a network id"
	)
	var entity_only_shot := _shot(ephemeral_source, 0, Vector3(90.0, 0.0, 0.0))
	entity_only_shot.source_id = 0
	entity_only_shot.faction_id = &"neutral_test"
	_check(resolver.resolve_hitscan(entity_only_shot).status == &"miss", "entity-only source resolves through its instance-keyed authority record")
	_check(resolver.get_tracked_source_count() == 3 and resolver.get_registered_source_count() == 3, "ephemeral source owns isolated registration and sequence state")
	ephemeral_source.queue_free()
	await process_frame
	_check(resolver.get_tracked_source_count() == 2 and resolver.get_registered_source_count() == 2, "source tree exit automatically releases registration and sequence state")

	# Stable IDs are also reclaimed once their physical owner is genuinely freed;
	# repeated despawns therefore cannot create unbounded stale history.
	var churn_is_bounded := true
	for churn_index in 8:
		var churn_source := Node3D.new()
		churn_source.name = "FreedStableSource%d" % churn_index
		churn_source.position = Vector3(100.0 + churn_index * 3.0, 0.0, 8.0)
		host.add_child(churn_source)
		var churn_source_id := SOURCE_ID + 100 + churn_index
		churn_is_bounded = (
			churn_is_bounded
			and resolver.register_source(
				churn_source_id, churn_source, &"transient_test", weapon_profiles
			)
		)
		var churn_shot := _shot(
			churn_source,
			0,
			churn_source.global_position + Vector3.RIGHT * 2.0
		)
		churn_shot.source_id = churn_source_id
		churn_shot.faction_id = &"transient_test"
		churn_is_bounded = churn_is_bounded and resolver.resolve_hitscan(churn_shot).accepted
		churn_source.queue_free()
		await process_frame
		churn_is_bounded = (
			churn_is_bounded
			and resolver.get_registered_source_count() == 2
			and resolver.get_tracked_source_count() == 2
		)
	_check(churn_is_bounded, "freed stable sources leave no unbounded replay history")

	resolver.forget_source(second_shooter, SOURCE_ID + 1)
	_check(
		resolver.get_last_sequence(second_shooter, SOURCE_ID + 1) == -1
		and resolver.get_registered_source_count() == 1
		and resolver.get_tracked_source_count() == 1,
		"explicit forget erases both registration and retained replay ledger"
	)
	_check(
		resolver.register_source(SOURCE_ID + 1, second_shooter, &"allied", weapon_profiles)
		and resolver.resolve_hitscan(independent_source).accepted,
		"explicitly forgotten identity may deliberately begin a fresh sequence epoch"
	)
	resolver.forget_source(second_shooter, SOURCE_ID + 1)
	resolver.forget_source(shooter, SOURCE_ID)
	_check(resolver.get_tracked_source_count() == 0 and resolver.get_registered_source_count() == 0, "despawn cleanup forgets source registration and ledger")

	host.queue_free()
	await process_frame
	await process_frame
	await process_frame
	_check(root.get_child_count() == original_root_child_count, "combat resolver fixture cleans up every scene node")
	_finish()


func _test_request_contract(shooter: Node) -> void:
	var request := _shot(shooter, 0, Vector3.ZERO)
	request.direction = Vector3(0.0, 0.0, -4.0)
	_check(request is ShotRequest and request.is_valid(), "ShotRequest is typed and validates a complete request")
	_check(request.get_normalized_direction().is_equal_approx(Vector3.FORWARD), "ShotRequest normalizes direction without mutating payload")
	_check(request.get_source_key() == "source_id:%d" % SOURCE_ID, "explicit source id supplies stable replay identity")
	var missing := ShotRequestScript.new() as ShotRequest
	_check(not missing.is_valid() and missing.get_validation_errors().size() >= 5, "ShotRequest reports all malformed required fields")


func _shot(
	shooter: Node,
	sequence: int,
	target_position: Vector3
	) -> ShotRequest:
	var source_position := (shooter as Node3D).global_position
	var direction := (target_position - source_position).normalized()
	if direction.length_squared() <= 0.000001:
		direction = Vector3.FORWARD
	return ShotRequestScript.new(
		shooter,
		SOURCE_ID,
		SOURCE_FACTION,
		&"pulse_cannon",
		sequence,
		source_position,
		direction,
		30.0,
		20.0
	) as ShotRequest


func _make_compound_shooter(fixture_name: String, position: Vector3) -> Node3D:
	var entity := Node3D.new()
	entity.name = fixture_name
	entity.position = position
	var body := _make_body("PhysicalBody", Vector3.ZERO, Layers.SHIP, 0.9)
	entity.add_child(body)
	var sibling_hurtbox := Area3D.new()
	sibling_hurtbox.name = "SiblingHurtbox"
	sibling_hurtbox.position = Vector3(0.0, 0.0, -0.2)
	sibling_hurtbox.collision_layer = Layers.TARGET
	sibling_hurtbox.collision_mask = Layers.NONE
	sibling_hurtbox.monitoring = false
	sibling_hurtbox.monitorable = true
	sibling_hurtbox.add_child(_make_collision_shape(1.1))
	entity.add_child(sibling_hurtbox)
	return entity


func _make_damageable_body(
	fixture_name: String,
	position: Vector3,
	faction: StringName,
	health: float
	) -> Dictionary:
	var body := _make_body(fixture_name, position, Layers.TARGET, 1.0)
	var damageable := DamageableScript.new() as Damageable
	damageable.name = "Damageable"
	damageable.faction_id = faction
	damageable.maximum_health = health
	body.add_child(damageable)
	return {"entity": body, "collider": body, "damageable": damageable}


func _make_damageable_area(
	fixture_name: String,
	position: Vector3,
	faction: StringName,
	health: float
	) -> Dictionary:
	var entity := Node3D.new()
	entity.name = fixture_name
	entity.position = position
	var area := Area3D.new()
	area.name = "Hurtbox"
	area.collision_layer = Layers.TARGET
	area.collision_mask = Layers.NONE
	area.monitoring = false
	area.monitorable = true
	area.add_child(_make_collision_shape(1.0))
	entity.add_child(area)
	var damageable := DamageableScript.new() as Damageable
	damageable.name = "Damageable"
	damageable.faction_id = faction
	damageable.maximum_health = health
	entity.add_child(damageable)
	return {"entity": entity, "collider": area, "damageable": damageable}


func _make_body(
	fixture_name: String,
	position: Vector3,
	layer: int,
	radius: float
	) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = fixture_name
	body.position = position
	body.collision_layer = layer
	body.collision_mask = Layers.NONE
	body.add_child(_make_collision_shape(radius))
	return body


func _make_collision_shape(radius: float) -> CollisionShape3D:
	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	collision.shape = sphere
	return collision


func _on_damage_applied(
	amount: float,
	current: float,
	maximum: float,
	hit_position: Vector3,
	hit_normal: Vector3,
	source_context: Dictionary
	) -> void:
	_damage_events.append({
		"amount": amount,
		"current": current,
		"maximum": maximum,
		"position": hit_position,
		"normal": hit_normal,
		"source": source_context,
	})


func _on_destroyed(
	hit_position: Vector3,
	hit_normal: Vector3,
	source_context: Dictionary
	) -> void:
	_destruction_events.append({
		"position": hit_position,
		"normal": hit_normal,
		"source": source_context,
	})


func _on_reset(current: float, maximum: float) -> void:
	_reset_events.append(Vector2(current, maximum))


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("COMBAT_RESOLVER_TEST_OK")
		quit(0)
	else:
		print("COMBAT_RESOLVER_TEST_FAILED: ", "; ".join(_failures))
		quit(1)
