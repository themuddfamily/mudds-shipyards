extends SceneTree

## Focused production-Jovian proof for one steady engine-bay silhouette cue.
## Damage enters only through HeroShip.apply_damage; this presentation consumes
## the existing ledger stage and leaves every freighter gameplay lane intact.

const JOVIAN_SCENE := preload("res://scenes/ships/jovian_light_freighter.tscn")
const ShipComponentDamageType := preload("res://scripts/combat/ship_component_damage.gd")

var _assertions := 0
var _failures: PackedStringArray = []


func _initialize() -> void:
	var freighter := JOVIAN_SCENE.instantiate() as JovianLightFreighter
	root.add_child(freighter)
	await process_frame
	await physics_frame

	var cue := freighter.get_jovian_visual_root().get_node(
		^"StarboardAftEngineDamageCue"
	) as Node3D
	var nominal := freighter.get_engine_damage_cue_snapshot()
	var lane_identity := _lane_identity(freighter)
	_check(
		cue != null
			and nominal.get("component_id", &"") \
				== ShipComponentDamageType.COMPONENT_ENGINE_BAY
			and nominal.get("stage", &"") == &"nominal"
			and not bool(nominal.get("visible", true))
			and not bool(nominal.get("damage_authority", true))
			and not bool(nominal.get("repair_authority", true))
			and not bool(nominal.get("processes", true))
			and not bool(nominal.get("flashes", true))
			and cue.process_mode == Node.PROCESS_MODE_DISABLED
			and cue.find_children("*", "Timer", true, false).is_empty()
			and cue.find_children("*", "Light3D", true, false).is_empty()
			and cue.find_children("*", "CollisionObject3D", true, false).is_empty()
			and cue.find_children("*", "CollisionShape3D", true, false).is_empty(),
		"the retained cue boots hidden and owns no timing, lighting, collision, damage, or repair authority"
	)

	var scorch := cue.get_node(^"EngineBreachScorch") as MeshInstance3D
	var vane := cue.get_node(^"EngineIsolationBlade") as MeshInstance3D
	var vane_material := vane.material_override as StandardMaterial3D
	_check(
		cue.get_child_count() == 2
			and scorch.mesh is BoxMesh
			and vane.mesh is BoxMesh
			and vane_material != null
			and vane_material.emission_enabled
			and vane_material.emission.is_equal_approx(
				JovianLightFreighter.ENGINE_DAMAGE_VANE_COLOR
			)
			and not cue.is_processing()
			and not cue.is_physics_processing(),
		"one dark footprint and one steady hot blade form the non-animated cue"
	)
	var bounds := nominal.get("local_bounds", AABB()) as AABB
	var aft_collision := freighter.get_node(^"AftHullCollision") as CollisionShape3D
	var aft_box := aft_collision.shape as BoxShape3D
	var support_bounds := (
		aft_collision.transform * AABB(-aft_box.size * 0.5, aft_box.size)
	).abs()
	_check(
		is_equal_approx(bounds.position.y, support_bounds.end.y)
			and bounds.position.x >= support_bounds.position.x
			and bounds.end.x <= support_bounds.end.x
			and bounds.position.z >= support_bounds.position.z
			and bounds.end.z <= support_bounds.end.z
			and vane.position.y - (vane.mesh as BoxMesh).size.y * 0.5
				<= scorch.position.y + (scorch.mesh as BoxMesh).size.y * 0.5,
		"the whole footprint rests on the real aft-hull collider and supports the raised blade"
	)

	var engine_position := _component_local_position(
		freighter, ShipComponentDamageType.COMPONENT_ENGINE_BAY
	)
	var hull_before := float(freighter.get_telemetry().get("hull", -1.0))
	# Leave enough impairment headroom that the craft's legitimate berth-repair
	# tick cannot cross back to nominal during the short chase/re-entry probe.
	var damage_amount := freighter.maximum_hull * 0.15
	freighter.apply_damage(
		damage_amount,
		freighter.to_global(engine_position),
		Vector3.BACK
	)
	var damaged := freighter.get_engine_damage_cue_snapshot()
	_check(
		is_equal_approx(
			float(freighter.get_telemetry().get("hull", -1.0)),
			hull_before - damage_amount
		)
			and freighter.get_component_damage().get_component_state(
				ShipComponentDamageType.COMPONENT_ENGINE_BAY
			) == ShipComponentDamageType.ComponentState.IMPAIRED
			and damaged.get("stage", &"") == &"impaired"
			and bool(damaged.get("visible", false)),
		"production HeroShip.apply_damage alone reveals the impaired engine-bay silhouette"
	)

	freighter.set_piloted(true)
	for _frame in 4:
		await process_frame
	var vane_bounds: AABB = cue.transform * vane.transform * vane.mesh.get_aabb()
	var chase_camera := freighter.get_camera()
	var projected_height_px := vane_bounds.size.y * 720.0 / (
		2.0 * freighter.maximum_chase_camera_distance
		* tan(deg_to_rad(chase_camera.fov) * 0.5)
	)
	_check(
		chase_camera.is_position_in_frustum(
			freighter.to_global(vane_bounds.get_center())
		)
			and projected_height_px >= 10.0
			and vane_bounds.position.z > 9.25
			and vane_bounds.position.x > 0.0,
		"the starboard-aft blade remains chase-visible even at maximum normal zoom"
	)
	freighter.set_piloted(false)
	_check(
		_lane_identity(freighter) == lane_identity
			and bool(freighter.get_defensive_weapon_visual_report().get("valid", false)),
		"damage presentation preserves cargo, passenger, engineer, copilot, boarding, and weapon lanes"
	)

	var cue_id := cue.get_instance_id()
	root.remove_child(freighter)
	await process_frame
	root.add_child(freighter)
	await process_frame
	_check(
		cue.get_instance_id() == cue_id
			and bool(freighter.get_engine_damage_cue_snapshot().get("visible", false))
			and freighter.get_engine_damage_cue_snapshot().get("stage", &"") == &"impaired"
			and _lane_identity(freighter) == lane_identity,
		"detach and re-entry retain the same steady cue and every freighter lane"
	)

	var reset := freighter.reset_for_reuse(freighter.global_transform)
	var recovered := freighter.get_engine_damage_cue_snapshot()
	_check(
		bool(reset.get("accepted", false))
			and cue.get_instance_id() == cue_id
			and recovered.get("stage", &"") == &"nominal"
			and not bool(recovered.get("visible", true))
			and is_equal_approx(
				float(freighter.get_telemetry().get("hull", -1.0)),
				freighter.maximum_hull
			)
			and _lane_identity(freighter) == lane_identity
			and bool(freighter.get_defensive_weapon_visual_report().get("valid", false)),
		"pooled reuse restores the cue in place without disturbing any freighter contract"
	)

	freighter.queue_free()
	await process_frame
	_finish()


func _component_local_position(ship: HeroShip, component_id: StringName) -> Vector3:
	for component in ship.get_component_damage_report().get("components", []) as Array:
		if StringName((component as Dictionary).get("id", &"")) == component_id:
			return (component as Dictionary).get("local_position", Vector3.INF) as Vector3
	return Vector3.INF


func _lane_identity(freighter: JovianLightFreighter) -> Dictionary:
	return {
		"cargo_hardpoints": _instance_ids(freighter.get_cargo_hardpoints()),
		"passenger_seats": _instance_ids(freighter.get_passenger_seat_anchors()),
		"engineer": freighter.get_engineer_seat_anchor().get_instance_id(),
		"copilot": freighter.get_copilot_seat_anchor().get_instance_id(),
		"boarding_point": freighter.get_node(^"BoardingPoint").get_instance_id(),
		"boarding_area": freighter.get_node(^"ShipBoardingArea").get_instance_id(),
		"left_muzzle": freighter.get_node(^"LeftMuzzle").get_instance_id(),
		"right_muzzle": freighter.get_node(^"RightMuzzle").get_instance_id(),
	}


func _instance_ids(nodes: Array) -> PackedInt64Array:
	var ids := PackedInt64Array()
	for node in nodes:
		ids.append((node as Node).get_instance_id())
	return ids


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("JOVIAN_ENGINE_DAMAGE_SILHOUETTE_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error("FAIL: %s" % failure)
	quit(1)
