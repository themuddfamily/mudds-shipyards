extends SceneTree

## Focused Bulwark proof for one retained component-damage silhouette. Damage
## enters only through HeroShip.apply_damage; the cue observes the existing
## starboard-wing ledger and never owns timing, damage, repair, collision,
## boarding, gunner, or weapon behavior.

const Bulwark := preload("res://scripts/ships/bulwark_heavy_gunship.gd")
const ShipComponentDamageType := preload("res://scripts/combat/ship_component_damage.gd")

var _assertions := 0
var _failures: PackedStringArray = []


func _initialize() -> void:
	var craft := Bulwark.new() as BulwarkHeavyGunship
	root.add_child(craft)
	await process_frame
	await physics_frame

	var visual := craft.get_node(^"BulwarkHeavyGunshipVisual") as Node3D
	var cue := visual.get_node(^"StarboardWeaponShoulderDamageCue") as Node3D
	var scorch := cue.get_node(^"ShoulderBreachScorch") as MeshInstance3D
	var vane := cue.get_node(^"RaisedBreachVane") as MeshInstance3D
	var nominal := craft.get_component_damage_cue_snapshot()
	_check(
		cue.process_mode == Node.PROCESS_MODE_DISABLED
			and nominal.get("component_id", &"")
				== ShipComponentDamageType.COMPONENT_STARBOARD_WING
			and nominal.get("stage", &"") == &"nominal"
			and not bool(nominal.get("visible", true))
			and not bool(nominal.get("processes", true))
			and not bool(nominal.get("flashes", true))
			and not bool(nominal.get("damage_authority", true))
			and not bool(nominal.get("repair_authority", true))
			and cue.find_children("*", "Timer", true, false).is_empty()
			and cue.find_children("*", "Light3D", true, false).is_empty()
			and cue.find_children("*", "CollisionObject3D", true, false).is_empty(),
		"the retained cue boots hidden with no process, flash, light, collision, damage, or repair authority"
	)
	var scorch_material := scorch.material_override as StandardMaterial3D
	var vane_material := vane.material_override as StandardMaterial3D
	_check(
		int(nominal.get("renderer_nodes", -1)) == 2
			and cue.get_child_count() == 2
			and scorch.mesh is BoxMesh and vane.mesh is BoxMesh
			and not scorch.mesh.resource_local_to_scene
			and not vane.mesh.resource_local_to_scene
			and scorch_material != null and not scorch_material.emission_enabled
			and vane_material != null and vane_material.emission_enabled
			and vane_material.emission.is_equal_approx(BulwarkHeavyGunship.DAMAGE_VANE_COLOR),
		"one dark shoulder breach and one steady hot vane form the complete cue"
	)

	var lane_ids := _functional_lane_ids(craft)
	var gunner_feedback_before := craft.get_gunner_station_feedback_snapshot()
	var collision_report := craft.get_landing_collision_report()
	var collision_bounds := collision_report.get("local_bounds", AABB()) as AABB
	var component_report := craft.get_component_damage_report()
	var component_bounds := component_report.get("local_bounds", AABB()) as AABB
	var expected_starboard_anchor := collision_bounds.get_center() + Vector3(
		collision_bounds.size.x * 0.5 * 0.78,
		collision_bounds.size.y * 0.5 * 0.12,
		0.0
	)
	var starboard_anchor := _component_local_position(
		craft, ShipComponentDamageType.COMPONENT_STARBOARD_WING
	)
	_check(
		bool(collision_report.get("valid", false))
			and int(collision_report.get("shape_count", 0)) == 3
			and component_bounds.is_equal_approx(collision_bounds)
			and starboard_anchor.is_equal_approx(expected_starboard_anchor)
			and is_equal_approx(
				float(component_report.get("maximum_hull", -1.0)), craft.maximum_hull
			),
		"the live component ledger derives its bounds and starboard anchor from the final three-shape Bulwark collision envelope"
	)
	var hull_before := float(craft.get_telemetry().get("hull", -1.0))
	var damage_amount := craft.maximum_hull * 0.15
	# Strike the real upper surface of the authored shoulder breach location, not
	# the component ledger anchor. This fails if production still uses Torrent's
	# inherited collision layout or if the cue drifts off the Bulwark shoulder.
	var shoulder_surface_hit := scorch.to_global(
		Vector3(0.0, BulwarkHeavyGunship.DAMAGE_SCORCH_SIZE.y * 0.5, 0.0)
	)
	craft.apply_damage(
		damage_amount,
		shoulder_surface_hit,
		Vector3.UP
	)
	var damaged := craft.get_component_damage_cue_snapshot()
	_check(
		craft.get_component_damage().get_component_state(
			ShipComponentDamageType.COMPONENT_STARBOARD_WING
		) == ShipComponentDamageType.ComponentState.IMPAIRED
			and is_equal_approx(
				float(craft.get_telemetry().get("hull", -1.0)), hull_before - damage_amount
			)
			and damaged.get("stage", &"") == &"impaired"
			and bool(damaged.get("visible", false)),
		"production HeroShip.apply_damage alone reveals the impaired starboard-weapon shoulder"
	)

	var shoulder_collision := craft.get_node(^"BulwarkShoulderCollision") as CollisionShape3D
	var shoulder_shape := shoulder_collision.shape as BoxShape3D
	var shoulder_bounds := (
		shoulder_collision.transform
		* AABB(-shoulder_shape.size * 0.5, shoulder_shape.size)
	).abs()
	var scorch_bounds := _renderer_local_bounds(cue, scorch)
	var vane_bounds := _renderer_local_bounds(cue, vane)
	_check(
		shoulder_bounds.intersects(scorch_bounds)
			and shoulder_bounds.intersects(vane_bounds)
			and vane_bounds.end.y - shoulder_bounds.end.y >= 1.0,
		"the scorch and vane root on the production shoulder shell while the vane breaks its upper silhouette"
	)

	var cue_bounds := damaged.get("local_bounds", AABB()) as AABB
	var camera := craft.get_camera()
	var projected_height_px := (vane_bounds.end.y - shoulder_bounds.end.y) * 720.0 \
		/ (
			2.0 * craft.maximum_chase_camera_distance
			* tan(deg_to_rad(camera.fov) * 0.5)
		)
	_check(
		camera.is_position_in_frustum(craft.to_global(cue_bounds.get_center()))
			and projected_height_px >= 10.0,
		"the steady breach is in the normal chase frustum and resolves as a meaningful raised silhouette at maximum zoom"
	)
	var left_muzzle := craft.get_node(^"LeftMuzzle") as Marker3D
	var right_muzzle := craft.get_node(^"RightMuzzle") as Marker3D
	var gunner := craft.get_gunner_station_anchor()
	var boarding := craft.get_node(^"BoardingPoint") as Marker3D
	_check(
		cue_bounds.position.z > maxf(left_muzzle.position.z, right_muzzle.position.z)
			and cue_bounds.position.x > gunner.position.x + BulwarkHeavyGunship.GUNNER_STATION_LOCAL_POSITION.x
			and cue_bounds.position.x > 0.0 and boarding.position.x < 0.0
			and _functional_lane_ids(craft) == lane_ids
			and craft.get_gunner_station_feedback_snapshot() == gunner_feedback_before,
		"the aft starboard cue preserves both forward weapon lanes, the central gunner lane, and port boarding"
	)

	var cue_id := cue.get_instance_id()
	var cue_transform := cue.transform
	var nominal_vane_transform := vane.transform
	var vane_material_id := vane_material.get_instance_id()
	for _frame in 4:
		await process_frame
	_check(
		cue.visible
			and cue.transform.is_equal_approx(cue_transform)
			and vane.material_override.get_instance_id() == vane_material_id
			and craft.get_component_damage_cue_snapshot().get("stage", &"") == &"impaired",
		"the impaired presentation remains steady across frames without animation or flashing"
	)

	craft.apply_damage(craft.maximum_hull * 0.10, shoulder_surface_hit, Vector3.UP)
	var failed := craft.get_component_damage_cue_snapshot()
	var failed_vane_bounds := _renderer_local_bounds(cue, vane)
	_check(
		craft.get_component_damage().get_component_state(
			ShipComponentDamageType.COMPONENT_STARBOARD_WING
		) == ShipComponentDamageType.ComponentState.FAILED
			and failed.get("stage", &"") == &"failed"
			and failed.get("silhouette_pose", &"") == &"failed_outboard_canted"
			and not vane.transform.is_equal_approx(nominal_vane_transform)
			and failed_vane_bounds.position.x - vane_bounds.position.x >= 0.5,
		"the existing failed starboard wing cants its retained vane beyond the shoulder as a localized non-color silhouette"
	)

	root.remove_child(craft)
	await process_frame
	root.add_child(craft)
	await process_frame
	_check(
		visual.get_node(^"StarboardWeaponShoulderDamageCue").get_instance_id() == cue_id
			and bool(craft.get_component_damage_cue_snapshot().get("visible", false))
			and craft.get_component_damage_cue_snapshot().get("stage", &"") == &"failed"
			and _functional_lane_ids(craft) == lane_ids,
		"detach and re-entry retain one failed cue without replacing functional ship lanes"
	)

	var reset := craft.reset_for_reuse(craft.global_transform)
	var recovered := craft.get_component_damage_cue_snapshot()
	_check(
		bool(reset.get("accepted", false))
			and recovered.get("stage", &"") == &"nominal"
			and not bool(recovered.get("visible", true))
			and visual.get_node(^"StarboardWeaponShoulderDamageCue").get_instance_id() == cue_id
			and craft.get_component_damage().get_component_state(
				ShipComponentDamageType.COMPONENT_STARBOARD_WING
			) == ShipComponentDamageType.ComponentState.NOMINAL
			and vane.transform.is_equal_approx(nominal_vane_transform)
			and _functional_lane_ids(craft) == lane_ids,
		"pooled reuse restores the exact nominal vane pose in place and preserves gunner, boarding, and weapon identity"
	)

	craft.queue_free()
	await process_frame
	_finish()


func _component_local_position(ship: HeroShip, component_id: StringName) -> Vector3:
	for component in ship.get_component_damage_report().get("components", []) as Array:
		if StringName((component as Dictionary).get("id", &"")) == component_id:
			return (component as Dictionary).get("local_position", Vector3.INF) as Vector3
	return Vector3.INF


func _renderer_local_bounds(cue: Node3D, renderer: MeshInstance3D) -> AABB:
	return (cue.transform * renderer.transform * renderer.mesh.get_aabb()).abs()


func _functional_lane_ids(craft: BulwarkHeavyGunship) -> PackedInt64Array:
	return PackedInt64Array([
		craft.get_node(^"LeftMuzzle").get_instance_id(),
		craft.get_node(^"RightMuzzle").get_instance_id(),
		craft.get_node(^"BoardingPoint").get_instance_id(),
		craft.get_node(^"BulwarkBoardingArea").get_instance_id(),
		craft.get_gunner_station_anchor().get_instance_id(),
	])


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("BULWARK_COMPONENT_DAMAGE_SILHOUETTE_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	print("BULWARK_COMPONENT_DAMAGE_SILHOUETTE_TEST_FAILED: %s" % "; ".join(_failures))
	quit(1)
