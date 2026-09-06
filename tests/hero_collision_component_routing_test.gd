extends SceneTree

## Focused production coverage for localized Hero collision consequences. The
## real main scene supplies every retained craft and its final collision-derived
## component layout; the test invokes only the small seam immediately after
## CharacterBody3D has resolved a finite contact.

const FLEET_CRAFT_NAMES := [
	"TorrentInterceptor",
	"ArrowReconShip",
	"JovianLightFreighter",
	"ZenithInterceptor",
	"HalyardCrewTransport",
]

const CONTACT_CASES := [
	{
		"name": "aft engine contact",
		"component": ShipComponentDamage.COMPONENT_ENGINE_BAY,
		"surface": &"aft",
		"normal": Vector3.FORWARD,
	},
	{
		"name": "port weapon contact",
		"component": ShipComponentDamage.COMPONENT_PORT_WING,
		"surface": &"port",
		"normal": Vector3.RIGHT,
	},
	{
		"name": "starboard weapon contact",
		"component": ShipComponentDamage.COMPONENT_STARBOARD_WING,
		"surface": &"starboard",
		"normal": Vector3.LEFT,
	},
	{
		"name": "dorsal sensor contact",
		"component": ShipComponentDamage.COMPONENT_CORE_SYSTEMS,
		"surface": &"dorsal",
		"normal": Vector3.DOWN,
	},
]

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		_fail("production main scene loads")
		_finish()
		return
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame

	for craft_name: String in FLEET_CRAFT_NAMES:
		var craft := game.get_node_or_null(craft_name) as HeroShip
		if craft == null:
			_fail("%s exists as a retained HeroShip" % craft_name)
			continue
		_test_craft_contacts(craft, craft_name)

	game.queue_free()
	await process_frame
	_finish()


func _test_craft_contacts(craft: HeroShip, craft_name: String) -> void:
	var component_damage := craft.get_component_damage()
	var model_id := component_damage.get_instance_id()
	var generation := component_damage.get_ledger_generation()
	var bounds: AABB = craft.get_component_damage_report().get("local_bounds", AABB())
	_check(bounds.has_volume(), "%s exposes its final physical component envelope" % craft_name)
	var rejected_hull := float(craft.get_telemetry().get("hull", -1.0))
	var rejected_revision := component_damage.get_revision()
	_check(
		not bool(craft.call(
			"_apply_resolved_collision_damage",
			craft.maximum_hull * 0.12,
			Vector3.INF,
			Vector3.UP
		))
		and is_equal_approx(float(craft.get_telemetry().get("hull", -1.0)), rejected_hull)
		and component_damage.get_revision() == rejected_revision,
		"%s rejects missing contact evidence without inferring hull or component damage" % craft_name
	)

	for contact_case: Dictionary in CONTACT_CASES:
		var spawn_transform := Transform3D(craft.global_basis, craft.global_position)
		_check(
			bool(craft.reset_for_reuse(spawn_transform).get("accepted", false)),
			"%s resets before %s" % [craft_name, contact_case.name]
		)
		generation += 1
		var local_contact := _surface_contact(bounds, contact_case.surface)
		var world_contact := craft.to_global(local_contact)
		var world_normal := (craft.global_basis * (contact_case.normal as Vector3)).normalized()
		var damage_amount := craft.maximum_hull * 0.12
		var hull_before := float(craft.get_telemetry().get("hull", -1.0))
		var accepted := bool(craft.call(
			"_apply_resolved_collision_damage",
			damage_amount,
			world_contact,
			world_normal
		))
		var report := craft.get_component_damage_report()
		var target_id: StringName = contact_case.component
		var exact_target := true
		for component: Dictionary in report.get("components", []) as Array:
			var component_id := StringName(component.get("id", &""))
			var integrity := float(component.get("integrity", -1.0))
			if component_id == target_id:
				exact_target = (
					exact_target
					and integrity < ShipComponentDamage.IMPAIRED_THRESHOLD
					and integrity > ShipComponentDamage.FAILED_THRESHOLD
				)
			else:
				exact_target = exact_target and is_equal_approx(integrity, 1.0)
		_check(
			accepted
			and is_equal_approx(
				float(craft.get_telemetry().get("hull", -1.0)),
				hull_before - damage_amount
			)
			and exact_target,
			"%s %s spends hull damage once and impairs only %s" % [
				craft_name,
				contact_case.name,
				target_id,
			]
		)
		_check(
			component_damage.get_instance_id() == model_id
			and component_damage.get_ledger_generation() == generation,
			"%s %s keeps the same generation-fenced component authority" % [
				craft_name,
				contact_case.name,
			]
		)

	var final_spawn := Transform3D(craft.global_basis, craft.global_position)
	_check(
		bool(craft.reset_for_reuse(final_spawn).get("accepted", false)),
		"%s completes collision recovery" % craft_name
	)
	_check(
		component_damage.get_instance_id() == model_id
		and component_damage.get_ledger_generation() == generation + 1
		and is_equal_approx(float(craft.get_component_damage_report().worst_integrity), 1.0),
		"%s reuse restores the routed region without replacing its ledger" % craft_name
	)


func _surface_contact(bounds: AABB, surface: StringName) -> Vector3:
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
		print("HERO_COLLISION_COMPONENT_ROUTING_TEST_OK")
		quit(0)
	else:
		push_error("Hero collision component routing test failed: %s" % _failures)
		quit(1)
