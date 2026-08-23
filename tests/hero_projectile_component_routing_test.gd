extends SceneTree

## Focused production test for the real CombatResolver -> lifecycle proxy ->
## HeroShip located-damage seam. Rays strike the live collision envelope of all
## five retained craft; no fixture damageable or alternate authority is created.

const ARENA_ORIGIN := Vector3(1200.0, 420.0, -1800.0)
const FLEET_CRAFT_NAMES := [
	"TorrentInterceptor",
	"ArrowReconShip",
	"JovianLightFreighter",
	"ZenithInterceptor",
	"HalyardCrewTransport",
]
const CONTACT_CASES := [
	{
		"name": "aft engine ray",
		"component": ShipComponentDamage.COMPONENT_ENGINE_BAY,
		"surface": &"aft",
	},
	{
		"name": "port weapon ray",
		"component": ShipComponentDamage.COMPONENT_PORT_WING,
		"surface": &"port",
	},
	{
		"name": "starboard weapon ray",
		"component": ShipComponentDamage.COMPONENT_STARBOARD_WING,
		"surface": &"starboard",
	},
	{
		"name": "dorsal sensor ray",
		"component": ShipComponentDamage.COMPONENT_CORE_SYSTEMS,
		"surface": &"dorsal",
	},
]
const MAX_SHOTS_PER_REGION := 4

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		_fail("production main scene loads")
		_finish()
		return
	var game := packed.instantiate() as GameFlow
	root.add_child(game)
	await process_frame
	await physics_frame
	var authority := game.get_combat_authority() as LiveCombatAuthority
	var opponent := game.get_node_or_null("RangeOpponent") as CharacterBody3D
	_check(authority != null and opponent != null, "production projectile authority and source are live")
	if authority == null or opponent == null:
		game.queue_free()
		await process_frame
		_finish()
		return

	var fleet: Array[HeroShip] = []
	for craft_name: String in FLEET_CRAFT_NAMES:
		var craft := game.get_node_or_null(craft_name) as HeroShip
		if craft == null:
			_fail("%s exists as a retained HeroShip" % craft_name)
		else:
			fleet.append(craft)
	for craft_index in fleet.size():
		await _test_craft(authority, opponent, fleet, craft_index)

	opponent.call("deactivate")
	game.queue_free()
	await process_frame
	_finish()


func _test_craft(
	authority: LiveCombatAuthority,
	opponent: CharacterBody3D,
	fleet: Array[HeroShip],
	craft_index: int
	) -> void:
	var craft := fleet[craft_index]
	var craft_name := craft.name
	for index in fleet.size():
		if index == craft_index:
			continue
		fleet[index].global_position = ARENA_ORIGIN + Vector3(1000.0 + index * 200.0, 0.0, 0.0)
	var component_damage := craft.get_component_damage()
	var model_id := component_damage.get_instance_id()
	var generation := component_damage.get_ledger_generation()

	for contact_case: Dictionary in CONTACT_CASES:
		var reset := craft.reset_for_reuse(Transform3D(Basis.IDENTITY, ARENA_ORIGIN))
		_check(bool(reset.get("accepted", false)), "%s resets before %s" % [craft_name, contact_case.name])
		generation += 1
		await physics_frame
		var report := craft.get_component_damage_report()
		var bounds: AABB = report.get("local_bounds", AABB())
		var target_id: StringName = contact_case.component
		var anchor := _component_position(report, target_id)
		var ray_setup := _find_functional_ray(
			craft,
			opponent,
			report,
			bounds,
			anchor,
			target_id,
			contact_case.surface
		)
		_check(not ray_setup.is_empty(), "%s exposes a physical ray to %s" % [craft_name, target_id])
		if ray_setup.is_empty():
			continue
		var local_target: Vector3 = ray_setup.target
		var local_origin: Vector3 = ray_setup.origin
		var ray_origin := craft.to_global(local_origin)
		var ray_target := craft.to_global(local_target)
		opponent.call("activate", Transform3D(Basis.IDENTITY, ray_origin))
		opponent.set_physics_process(false)
		opponent.global_position = ray_origin
		await physics_frame

		var receipt_point_valid := true
		var exact_hull_spend := true
		var resolved_target_only := true
		var damaged := false
		for _shot in MAX_SHOTS_PER_REGION:
			var hull_before := float(craft.get_telemetry().get("hull", -1.0))
			var result := authority.submit_hitscan(
				opponent,
				GameFlow.OPPONENT_WEAPON_ID,
				ray_origin,
				(ray_target - ray_origin).normalized()
			)
			var hit_position: Vector3 = result.get("position", Vector3.INF)
			var applied := float(result.get("applied_damage", 0.0))
			receipt_point_valid = receipt_point_valid \
				and bool(result.get("damaged", false)) \
				and hit_position.is_finite() \
				and _nearest_functional_component(report, craft.to_local(hit_position)) == target_id
			exact_hull_spend = exact_hull_spend and is_equal_approx(
				float(craft.get_telemetry().get("hull", -1.0)),
				hull_before - applied
			)
			var post_report := craft.get_component_damage_report()
			resolved_target_only = resolved_target_only and _only_target_changed(post_report, target_id)
			damaged = component_damage.get_component_integrity(target_id) \
				< ShipComponentDamage.IMPAIRED_THRESHOLD
			if damaged or not bool(result.get("damaged", false)):
				break

		_check(
			receipt_point_valid and exact_hull_spend and resolved_target_only and damaged,
			"%s %s preserves its finite receipt and impairs only %s" % [
				craft_name,
				contact_case.name,
				target_id,
			]
		)
		_check(
			component_damage.get_instance_id() == model_id
			and component_damage.get_ledger_generation() == generation,
			"%s %s stays on the existing generation-fenced ledger" % [craft_name, contact_case.name]
		)

	var fallback_reset := craft.reset_for_reuse(Transform3D(Basis.IDENTITY, ARENA_ORIGIN))
	_check(bool(fallback_reset.get("accepted", false)), "%s resets before generic fallback" % craft_name)
	generation += 1
	var fallback_hull := float(craft.get_telemetry().get("hull", -1.0))
	craft.apply_damage(1.0)
	var fallback_report := craft.get_component_damage_report()
	var shared_integrity := -1.0
	var fallback_uniform := true
	for component: Dictionary in fallback_report.get("components", []) as Array:
		var integrity := float(component.get("integrity", -1.0))
		if shared_integrity < 0.0:
			shared_integrity = integrity
		else:
			fallback_uniform = fallback_uniform and is_equal_approx(integrity, shared_integrity)
	_check(
		is_equal_approx(float(craft.get_telemetry().get("hull", -1.0)), fallback_hull - 1.0)
		and fallback_uniform
		and shared_integrity < 1.0
		and component_damage.get_instance_id() == model_id
		and component_damage.get_ledger_generation() == generation,
		"%s positionless damage retains the generic fallback on the same authority" % craft_name
	)


func _ray_origin(bounds: AABB, anchor: Vector3, surface: StringName) -> Vector3:
	match surface:
		&"aft":
			return Vector3(anchor.x, anchor.y, bounds.end.z + 6.0)
		&"port":
			return Vector3(bounds.position.x - 6.0, anchor.y, anchor.z)
		&"starboard":
			return Vector3(bounds.end.x + 6.0, anchor.y, anchor.z)
		&"dorsal":
			return Vector3(anchor.x, bounds.end.y + 6.0, anchor.z)
	return anchor


func _find_functional_ray(
	craft: HeroShip,
	opponent: CharacterBody3D,
	report: Dictionary,
	bounds: AABB,
	anchor: Vector3,
	target_id: StringName,
	surface: StringName
	) -> Dictionary:
	var candidates: Array[Vector3] = [anchor]
	if surface in [&"port", &"starboard"]:
		# Some retained wing collision is much thinner than the overall fuselage
		# envelope. Probe a bounded static grid to find a real side ray whose
		# resolved physics contact is nearest the declared wing anchor.
		for y_fraction in [0.12, 0.28, 0.44, 0.60, 0.76]:
			for z_fraction in [0.18, 0.34, 0.50, 0.66, 0.82]:
				candidates.append(Vector3(
					anchor.x,
					bounds.position.y + bounds.size.y * y_fraction,
					bounds.position.z + bounds.size.z * z_fraction
				))
	var space_state := craft.get_world_3d().direct_space_state
	for local_target: Vector3 in candidates:
		var local_origin := _ray_origin(bounds, local_target, surface)
		var world_origin := craft.to_global(local_origin)
		var world_target := craft.to_global(local_target)
		var query_end := world_origin + (world_target - world_origin).normalized() \
			* (bounds.size.length() + 20.0)
		var query := PhysicsRayQueryParameters3D.create(
			world_origin,
			query_end,
			craft.collision_layer
		)
		query.exclude = [opponent.get_rid()]
		var hit := space_state.intersect_ray(query)
		if hit.get("collider") != craft:
			continue
		var hit_position := hit.get("position", Vector3.INF) as Vector3
		if hit_position.is_finite() \
			and _nearest_functional_component(report, craft.to_local(hit_position)) == target_id:
			return {"origin": local_origin, "target": local_target}
	return {}


func _component_position(report: Dictionary, component_id: StringName) -> Vector3:
	for component: Dictionary in report.get("components", []) as Array:
		if StringName(component.get("id", &"")) == component_id:
			return component.get("local_position", Vector3.INF) as Vector3
	return Vector3.INF


func _nearest_functional_component(report: Dictionary, local_position: Vector3) -> StringName:
	var nearest: StringName = &""
	var nearest_distance := INF
	for component: Dictionary in report.get("components", []) as Array:
		var component_id := StringName(component.get("id", &""))
		if not ShipComponentDamage.COLLISION_FUNCTIONAL_COMPONENTS.has(component_id):
			continue
		var position := component.get("local_position", Vector3.INF) as Vector3
		var distance := position.distance_squared_to(local_position)
		if distance < nearest_distance:
			nearest = component_id
			nearest_distance = distance
	return nearest


func _only_target_changed(report: Dictionary, target_id: StringName) -> bool:
	for component: Dictionary in report.get("components", []) as Array:
		var component_id := StringName(component.get("id", &""))
		var integrity := float(component.get("integrity", -1.0))
		if component_id == target_id:
			if integrity >= 1.0:
				return false
		elif not is_equal_approx(integrity, 1.0):
			return false
	return true


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_fail(message)


func _fail(message: String) -> void:
	_failures.append(message)
	push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("Hero projectile component routing test passed")
		quit(0)
	else:
		push_error("Hero projectile component routing test failed: %s" % [_failures])
		quit(1)
