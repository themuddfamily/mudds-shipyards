extends SceneTree

## Focused production-Cinder proof for one static component-damage cue. Damage
## enters only through HeroShip.apply_damage; the bomber consumes the existing
## starboard-wing stage without adding damage, repair, timing, or interaction.

const Bomber := preload("res://scripts/ships/cinder_long_range_bomber.gd")
const ShipComponentDamageType := preload("res://scripts/combat/ship_component_damage.gd")

var _assertions := 0
var _failures: PackedStringArray = []


func _initialize() -> void:
	var bomber := Bomber.new() as CinderLongRangeBomber
	root.add_child(bomber)
	await process_frame
	await physics_frame

	var nominal := bomber.get_component_damage_cue_snapshot()
	var nominal_cue := bomber.get_variant_visual_root().get_node(
		^"StarboardWingDamageCue"
	) as Node3D
	_check(
		nominal.get("component_id", &"") == ShipComponentDamageType.COMPONENT_STARBOARD_WING
			and nominal.get("stage", &"") == &"nominal"
			and not bool(nominal.get("visible", true))
			and not bool(nominal.get("damage_authority", true))
			and not bool(nominal.get("repair_authority", true))
			and not bool(nominal.get("processes", true))
			and not bool(nominal.get("flashes", true))
			and nominal_cue.process_mode == Node.PROCESS_MODE_DISABLED
			and nominal_cue.find_children("*", "CollisionObject3D", true, false).is_empty()
			and nominal_cue.find_children("*", "Area3D", true, false).is_empty(),
		"the retained cue boots hidden and owns no damage, repair, timer, or flashing authority"
	)
	var scorch := nominal_cue.get_node(^"DamageScorch") as MeshInstance3D
	var vane := nominal_cue.get_node(^"ExposedDamageVane") as MeshInstance3D
	var scorch_material := scorch.material_override as StandardMaterial3D
	var vane_material := vane.material_override as StandardMaterial3D
	_check(
		nominal_cue.get_child_count() == 2
			and scorch.mesh is BoxMesh and vane.mesh is BoxMesh
			and not scorch.mesh.resource_local_to_scene
			and not vane.mesh.resource_local_to_scene
			and not scorch_material.resource_local_to_scene
			and not vane_material.resource_local_to_scene
			and not scorch_material.emission_enabled
			and vane_material.emission_enabled
			and vane_material.emission.is_equal_approx(CinderLongRangeBomber.DAMAGE_VANE_COLOR),
		"the dark breach and steady hot vane use exactly two immutable presentation recipes"
	)
	_check(
		bool(bomber.begin_payload_generation(1).get("accepted", false)),
		"the existing payload generation remains active before component damage"
	)

	var starboard_position := _component_local_position(
		bomber, ShipComponentDamageType.COMPONENT_STARBOARD_WING
	)
	var hull_before := float(bomber.get_telemetry().get("hull", -1.0))
	var damage_amount := bomber.maximum_hull * 0.15
	bomber.apply_damage(
		damage_amount,
		bomber.to_global(starboard_position),
		Vector3.UP
	)
	var damaged := bomber.get_component_damage_cue_snapshot()
	var component_state := bomber.get_component_damage().get_component_state(
		ShipComponentDamageType.COMPONENT_STARBOARD_WING
	)
	_check(
		is_equal_approx(
			float(bomber.get_telemetry().get("hull", -1.0)),
			hull_before - damage_amount
		)
			and component_state == ShipComponentDamageType.ComponentState.IMPAIRED
			and damaged.get("stage", &"") == &"impaired"
			and bool(damaged.get("visible", false)),
		"production HeroShip.apply_damage alone impairs the starboard wing and reveals its cue"
	)

	var cue_bounds := damaged.get("local_bounds", AABB()) as AABB
	var chase_camera := bomber.get_camera()
	var cue_world_center := bomber.to_global(cue_bounds.get_center())
	var hardpoints_clear := true
	for hardpoint in bomber.get_payload_hardpoints():
		hardpoints_clear = hardpoints_clear and not cue_bounds.has_point(
			bomber.to_local((hardpoint as Marker3D).global_position)
		)
	_check(
		bool(damaged.get("view_lane_clear", false))
			and cue_bounds.position.x > CinderLongRangeBomber.HULL_SIZE.x * 0.5
			and chase_camera.is_position_in_frustum(cue_world_center)
			and hardpoints_clear,
		"the raised outboard vane is chase-visible while the central cockpit/aim and all payload lanes stay clear"
	)
	if OS.get_cmdline_user_args().has("--capture"):
		await _capture_damage_cue(bomber)
		bomber.queue_free()
		await process_frame
		_finish()
		return

	var cue := bomber.get_variant_visual_root().get_node(^"StarboardWingDamageCue") as Node3D
	var cue_instance_id := cue.get_instance_id()
	var payload_before_reentry := bomber.get_payload_authority_snapshot()
	_check(
		cue.visible
			and cue.get_instance_id() == cue_instance_id
			and bomber.get_component_damage_cue_snapshot().get("stage", &"") == &"impaired",
		"the damaged silhouette is a steady retained state rather than an animation or flash"
	)

	root.remove_child(bomber)
	await process_frame
	root.add_child(bomber)
	await process_frame
	var payload_after_reentry := bomber.get_payload_authority_snapshot()
	_check(
		bomber.get_variant_visual_root().get_node(^"StarboardWingDamageCue").get_instance_id()
				== cue_instance_id
			and bomber.get_component_damage_cue_snapshot().get("stage", &"") == &"impaired"
			and bool(bomber.get_component_damage_cue_snapshot().get("visible", false))
			and bool(payload_after_reentry.get("active", false))
			and int(payload_after_reentry.get("generation", -1))
				== int(payload_before_reentry.get("generation", -2))
			and int(payload_after_reentry.get("ammunition_remaining", -1))
				== int(payload_before_reentry.get("ammunition_remaining", -2)),
		"detach/re-entry retains one damaged cue and the exact active payload generation/budget"
	)

	var reset := bomber.reset_for_reuse(bomber.global_transform)
	var recovered := bomber.get_component_damage_cue_snapshot()
	_check(
		bool(reset.get("accepted", false))
			and recovered.get("stage", &"") == &"nominal"
			and not bool(recovered.get("visible", true))
			and bomber.get_variant_visual_root().get_node(^"StarboardWingDamageCue").get_instance_id()
				== cue_instance_id
			and not bool(bomber.get_payload_authority_snapshot().get("active", true))
			and is_equal_approx(
				float(bomber.get_telemetry().get("hull", -1.0)), bomber.maximum_hull
			)
			and bomber.get_component_damage().get_component_state(
				ShipComponentDamageType.COMPONENT_STARBOARD_WING
			) == ShipComponentDamageType.ComponentState.NOMINAL,
		"HeroShip reuse restores nominal presentation in place and preserves payload teardown"
	)
	_check(
		bool(bomber.reset_payload_for_reuse(2).get("accepted", false))
			and bool(bomber.get_payload_authority_snapshot().get("active", false))
			and int(bomber.get_payload_authority_snapshot().get("generation", -1)) == 2
			and int(bomber.get_payload_authority_snapshot().get("ammunition_remaining", -1))
				== CinderLongRangeBomber.PAYLOAD_AMMUNITION
			and not bool(bomber.get_component_damage_cue_snapshot().get("visible", true)),
		"the next pooled payload generation starts cleanly without reviving stale damage"
	)

	var second := Bomber.new() as CinderLongRangeBomber
	root.add_child(second)
	await process_frame
	var second_cue := second.get_component_damage_cue_snapshot()
	_check(
		damaged.get("mesh_resource_ids", PackedInt64Array())
				== second_cue.get("mesh_resource_ids", PackedInt64Array())
			and damaged.get("material_resource_ids", PackedInt64Array())
				== second_cue.get("material_resource_ids", PackedInt64Array())
			and int(second_cue.get("renderer_nodes_per_copy", -1)) == 2
			and int(second_cue.get("geometry_submissions_per_copy", -1)) == 2
			and bool(second.get_audit_report().get("valid", false)),
		"pooled bomber copies share two immutable cue recipes while retaining per-craft visibility"
	)

	bomber.queue_free()
	second.queue_free()
	await process_frame
	_finish()


func _component_local_position(ship: HeroShip, component_id: StringName) -> Vector3:
	for component in ship.get_component_damage_report().get("components", []) as Array:
		if StringName((component as Dictionary).get("id", &"")) == component_id:
			return (component as Dictionary).get("local_position", Vector3.INF) as Vector3
	return Vector3.INF


func _capture_damage_cue(bomber: CinderLongRangeBomber) -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("071016")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("8fa5ab")
	environment.ambient_light_energy = 0.55
	world_environment.environment = environment
	root.add_child(world_environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
	light.light_color = Color("dbe9e7")
	light.light_energy = 1.3
	root.add_child(light)
	bomber.set_piloted(true)
	for _frame in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	var save_error := root.get_texture().get_image().save_png(
		"/tmp/cinder-bomber-component-damage-cue.png"
	)
	_check(save_error == OK, "the focused damaged-bomber capture writes successfully")
	bomber.set_piloted(false)
	world_environment.queue_free()
	light.queue_free()


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("CINDER_BOMBER_COMPONENT_DAMAGE_CUE_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	print("CINDER_BOMBER_COMPONENT_DAMAGE_CUE_TEST_FAILED: %s" % "; ".join(_failures))
	quit(1)
