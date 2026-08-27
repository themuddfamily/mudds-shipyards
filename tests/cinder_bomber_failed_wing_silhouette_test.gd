extends SceneTree

## Focused presentation regression for the existing Cinder starboard-wing
## failure stage. The test drives the established component ledger directly;
## the bomber only observes that state and changes no gameplay authority.

const Bomber := preload("res://scripts/ships/cinder_long_range_bomber.gd")
const ComponentDamage := preload("res://scripts/combat/ship_component_damage.gd")

var _assertions := 0
var _failures: PackedStringArray = []


func _initialize() -> void:
	var bomber := Bomber.new() as CinderLongRangeBomber
	root.add_child(bomber)
	await process_frame

	var cue := bomber.get_variant_visual_root().get_node(^"StarboardWingDamageCue") as Node3D
	var vane := cue.get_node(^"ExposedDamageVane") as MeshInstance3D
	var nominal_transform := vane.transform
	var node_count := cue.get_child_count()
	var mesh_id := vane.mesh.get_instance_id()
	var material_id := vane.material_override.get_instance_id()
	var model := bomber.get_component_damage()
	var nominal_image: Image
	if OS.get_cmdline_user_args().has("--capture"):
		nominal_image = await _capture_stage(bomber)
	model.record_damage(
		bomber.maximum_hull * 2.0,
		_component_local_position(bomber, ComponentDamage.COMPONENT_STARBOARD_WING)
	)
	await process_frame
	var failed := bomber.get_component_damage_cue_snapshot()
	_check(
		failed.get("stage", &"") == &"failed"
			and failed.get("silhouette_pose", &"") == &"failed_outboard_canted"
			and bool(failed.get("visible", false))
			and not (failed.get("vane_local_transform", Transform3D.IDENTITY) as Transform3D)
				.is_equal_approx(nominal_transform),
		"the existing failed wing state creates a localized outboard canted silhouette"
	)
	_check(
		vane.position.is_equal_approx(CinderLongRangeBomber.DAMAGE_VANE_FAILED_POSITION)
			and is_equal_approx(vane.rotation_degrees.z, CinderLongRangeBomber.DAMAGE_VANE_FAILED_ROTATION_DEGREES.z)
			and cue.get_child_count() == node_count
			and vane.mesh.get_instance_id() == mesh_id
			and vane.material_override.get_instance_id() == material_id,
		"failure only reposes retained geometry and does not allocate another renderer or material"
	)
	if nominal_image != null:
		var failed_image := await _capture_stage(bomber)
		_check(
			failed_image != null
				and failed_image.get_size() == nominal_image.get_size()
				and failed_image.get_data() != nominal_image.get_data(),
			"Forward+ chase capture visibly differs between nominal and failed retained silhouettes"
		)

	_repair_component_to(model, ComponentDamage.COMPONENT_STARBOARD_WING, 1.0)
	await process_frame
	var repaired := bomber.get_component_damage_cue_snapshot()
	_check(
		repaired.get("stage", &"") == &"nominal"
			and repaired.get("silhouette_pose", &"") == &"nominal_upright"
			and not bool(repaired.get("visible", true))
			and (repaired.get("vane_local_transform", Transform3D.IDENTITY) as Transform3D)
				.is_equal_approx(nominal_transform),
		"repair restores the exact authored nominal vane transform in place"
	)

	bomber.queue_free()
	await process_frame
	_finish()


func _component_local_position(ship: HeroShip, component_id: StringName) -> Vector3:
	for component_variant in ship.get_component_damage_report().get("components", []) as Array:
		var component := component_variant as Dictionary
		if StringName(component.get("id", &"")) == component_id:
			return component.get("local_position", Vector3.ZERO) as Vector3
	return Vector3.ZERO


func _repair_component_to(model: ShipComponentDamage, component_id: StringName, integrity: float) -> void:
	var before := model.get_component_integrity(component_id)
	var delta := maxf(
		(integrity - before) / maxf(model.repair_rate_per_second, 0.001),
		0.001
	)
	model.tick_component_repair(component_id, delta, true)


func _capture_stage(bomber: CinderLongRangeBomber) -> Image:
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
	var image := root.get_texture().get_image()
	bomber.set_piloted(false)
	world_environment.queue_free()
	light.queue_free()
	await process_frame
	return image


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: %s" % message)
		return
	_failures.append(message)
	push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("CINDER_BOMBER_FAILED_WING_SILHOUETTE_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	print("CINDER_BOMBER_FAILED_WING_SILHOUETTE_TEST_FAILED: %s" % "; ".join(_failures))
	quit(1)
