extends SceneTree

## Focused production coverage for component-routed impact placement. Every case
## uses the retained main-scene craft, its final component layout, and the
## existing HeroDamageImpact allocation; no presentation fixture is constructed.

const TEST_ORIGIN := Vector3(900.0, 260.0, -1400.0)
const FLEET_CRAFT_NAMES := [
	"TorrentInterceptor",
	"ArrowReconShip",
	"JovianLightFreighter",
	"ZenithInterceptor",
	"HalyardCrewTransport",
]
const CASES := [
	{
		"name": "collision engine",
		"component": ShipComponentDamage.COMPONENT_ENGINE_BAY,
		"surface": &"aft",
		"collision": true,
		"deferred": false,
	},
	{
		"name": "projectile port weapon",
		"component": ShipComponentDamage.COMPONENT_PORT_WING,
		"surface": &"port",
		"collision": false,
		"deferred": false,
	},
	{
		"name": "projectile starboard weapon",
		"component": ShipComponentDamage.COMPONENT_STARBOARD_WING,
		"surface": &"starboard",
		"collision": false,
		"deferred": false,
	},
	{
		"name": "deferred projectile sensor",
		"component": ShipComponentDamage.COMPONENT_CORE_SYSTEMS,
		"surface": &"dorsal",
		"collision": false,
		"deferred": true,
	},
]

var _failures: Array[String] = []
var _next_receipt_id := 7000


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

	for craft_name: String in FLEET_CRAFT_NAMES:
		var craft := game.get_node_or_null(craft_name) as HeroShip
		if craft == null:
			_fail("%s exists as a retained HeroShip" % craft_name)
			continue
		await _test_craft(craft)

	game.queue_free()
	await process_frame
	_finish()


func _test_craft(craft: HeroShip) -> void:
	var presentation := craft.get_damage_presentation()
	for impact_case: Dictionary in CASES:
		var reset := craft.reset_for_reuse(Transform3D(Basis.IDENTITY, TEST_ORIGIN))
		_check(bool(reset.get("accepted", false)), "%s resets before %s" % [craft.name, impact_case.name])
		await process_frame
		var report := craft.get_component_damage_report()
		var bounds: AABB = report.get("local_bounds", AABB())
		var component_id: StringName = impact_case.component
		var local_anchor := _component_position(report, component_id)
		var expected_world_anchor := craft.to_global(local_anchor)
		var local_hit := _surface_point(bounds, impact_case.surface)
		var world_hit := craft.to_global(local_hit)
		var world_normal := (craft.global_basis * _surface_normal(impact_case.surface)).normalized()
		var deferred := bool(impact_case.deferred)
		var receipt_id := _next_receipt_id if deferred else -1
		_next_receipt_id += 1
		var damage_amount := craft.maximum_hull * 0.12

		if bool(impact_case.collision):
			craft.call("_apply_resolved_collision_damage", damage_amount, world_hit, world_normal)
		else:
			craft.apply_damage(damage_amount, world_hit, world_normal, receipt_id, deferred)

		if deferred:
			_check(
				presentation.get_pending_damage_presentation_count() == 1
				and presentation.get_live_world_effect_count() == 0,
				"%s %s remains invisible until its receipt commits" % [craft.name, impact_case.name]
			)
			_check(
				craft.commit_deferred_damage_presentation(receipt_id),
				"%s %s commits through the existing receipt" % [craft.name, impact_case.name]
			)

		var impact := _find_live_impact()
		_check(
			impact != null
			and impact.global_position.distance_to(expected_world_anchor) < 0.001
			and impact.global_position.distance_to(world_hit) > 0.05,
			"%s %s places the burst at the accepted %s anchor" % [
				craft.name,
				impact_case.name,
				component_id,
			]
		)
		_check(
			presentation.get_live_world_effect_count() == 1
			and impact != null
			and impact.get_child_count() == 3
			and impact.get_node_or_null("ImpactSparks") is CPUParticles3D
			and impact.get_node_or_null("ImpactFlash") is MeshInstance3D
			and impact.get_node_or_null("ImpactLight") is OmniLight3D,
			"%s %s reuses the single existing four-node impact family" % [craft.name, impact_case.name]
		)

	var fallback_reset := craft.reset_for_reuse(Transform3D(Basis.IDENTITY, TEST_ORIGIN))
	_check(bool(fallback_reset.get("accepted", false)), "%s resets before positionless fallback" % craft.name)
	await process_frame
	craft.apply_damage(1.0)
	_check(
		presentation.get_live_world_effect_count() == 0
		and presentation.get_pending_damage_presentation_count() == 0,
		"%s positionless damage keeps the generic no-impact fallback" % craft.name
	)
	var cleanup_reset := craft.reset_for_reuse(Transform3D(Basis.IDENTITY, TEST_ORIGIN))
	await process_frame
	_check(
		bool(cleanup_reset.get("accepted", false))
		and presentation.get_live_world_effect_count() == 0
		and presentation.get_pending_damage_presentation_count() == 0,
		"%s reuse clears routed impact and receipt state" % craft.name
	)


func _component_position(report: Dictionary, component_id: StringName) -> Vector3:
	for component: Dictionary in report.get("components", []) as Array:
		if StringName(component.get("id", &"")) == component_id:
			return component.get("local_position", Vector3.INF) as Vector3
	return Vector3.INF


func _surface_point(bounds: AABB, surface: StringName) -> Vector3:
	var centre := bounds.get_center()
	match surface:
		&"aft":
			return Vector3(centre.x, centre.y, bounds.end.z)
		&"port":
			return Vector3(bounds.position.x, centre.y, centre.z)
		&"starboard":
			return Vector3(bounds.end.x, centre.y, centre.z)
		&"dorsal":
			return Vector3(centre.x, bounds.end.y, centre.z)
	return centre


func _surface_normal(surface: StringName) -> Vector3:
	match surface:
		&"aft":
			return Vector3.FORWARD
		&"port":
			return Vector3.RIGHT
		&"starboard":
			return Vector3.LEFT
		&"dorsal":
			return Vector3.DOWN
	return Vector3.UP


func _find_live_impact() -> Node3D:
	for child: Node in root.get_children():
		if child is Node3D and child.name.to_lower().begins_with("herodamageimpact"):
			return child as Node3D
	return null


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
		print("Hero component impact anchor presentation test passed")
		quit(0)
	else:
		push_error("Hero component impact anchor presentation test failed: %s" % [_failures])
		quit(1)
