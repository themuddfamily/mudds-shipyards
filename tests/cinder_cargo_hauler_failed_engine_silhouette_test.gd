extends SceneTree

## Focused proof that the production engine-bay FAILED state has a local,
## steady silhouette read independent of its existing damage colour.

const Hauler := preload("res://scripts/ships/cinder_cargo_hauler.gd")
const ShipComponentDamageType := preload("res://scripts/combat/ship_component_damage.gd")

var _assertions := 0
var _failures: PackedStringArray = []


func _initialize() -> void:
	var craft := Hauler.new() as CinderCargoHauler
	root.add_child(craft)
	await process_frame
	var shoulders := craft.get_node_or_null(
		^"CinderCargoVisual/CargoShoulderBatch"
	) as MultiMeshInstance3D
	var nominal := _presented_transforms(shoulders)
	var capture_requested := OS.get_cmdline_user_args().has("--capture")
	if capture_requested:
		_setup_comparison_camera()
		await _capture("/tmp/cinder-cargo-engine-nominal.png")
	var engine_position := _component_local_position(
		craft, ShipComponentDamageType.COMPONENT_ENGINE_BAY
	)
	for _attempt in 4:
		if craft.get_component_damage().get_component_state(
			ShipComponentDamageType.COMPONENT_ENGINE_BAY
		) == ShipComponentDamageType.ComponentState.FAILED:
			break
		craft.apply_damage(craft.maximum_hull * 0.1, craft.to_global(engine_position), Vector3.UP)
		await process_frame
	if capture_requested:
		await _capture("/tmp/cinder-cargo-engine-failed.png")

	var failed := _presented_transforms(shoulders)
	var roof_top := Hauler.HULL_SIZE.y * 0.5
	var raised_top := _top_of_instance(shoulders, failed[2])
	var collapsed_top := _top_of_instance(shoulders, failed[3])
	_check(
		craft.get_component_damage().get_component_state(
			ShipComponentDamageType.COMPONENT_ENGINE_BAY
		) == ShipComponentDamageType.ComponentState.FAILED
			and shoulders.get_meta(&"damage_state", &"") == &"failed"
			and not failed[2].is_equal_approx(nominal[2])
			and not failed[3].is_equal_approx(nominal[3])
			and raised_top > roof_top + 0.20
			and collapsed_top < roof_top,
		"failed engine bay keeps one aft rail raised and collapses the other below the roof silhouette"
	)
	_check(
		is_equal_approx(failed[2].origin.x, -failed[3].origin.x)
			and not is_equal_approx(failed[2].basis.get_scale().y, failed[3].basis.get_scale().y)
			and not bool(shoulders.get_meta(&"damage_authority", true))
			and not bool(shoulders.get_meta(&"animated", true)),
		"the failed silhouette is localized, asymmetric, and presentation-only rather than a colour or animation cue"
	)

	var reset := craft.reset_for_reuse(craft.global_transform)
	_check(
		bool(reset.get("accepted", false))
			and shoulders.get_meta(&"damage_state", &"") == &"nominal"
			and _presented_transforms(shoulders) == nominal,
		"repair/reuse restores the exact nominal retained-geometry pose"
	)
	craft.queue_free()
	await process_frame
	_finish()


func _component_local_position(ship: HeroShip, component_id: StringName) -> Vector3:
	for component in ship.get_component_damage_report().get("components", []) as Array:
		if StringName((component as Dictionary).get("id", &"")) == component_id:
			return (component as Dictionary).get("local_position", Vector3.ZERO) as Vector3
	return Vector3.ZERO


func _presented_transforms(batch: MultiMeshInstance3D) -> Array[Transform3D]:
	var transforms: Array[Transform3D] = []
	if batch == null:
		return transforms
	for transform in batch.get_meta(&"presented_instance_transforms", []) as Array:
		transforms.append(transform as Transform3D)
	return transforms


func _top_of_instance(batch: MultiMeshInstance3D, transform: Transform3D) -> float:
	if batch == null or batch.multimesh == null:
		return -INF
	return (transform * batch.multimesh.mesh.get_aabb()).abs().end.y


func _setup_comparison_camera() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("091116")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b9c9cf")
	environment.ambient_light_energy = 0.45
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	root.add_child(world_environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48.0, 28.0, 0.0)
	light.light_energy = 1.45
	root.add_child(light)
	var camera := Camera3D.new()
	var origin := Vector3(0.0, 4.6, 23.0)
	camera.global_transform = Transform3D(
		Basis.looking_at((Vector3(0.0, 0.45, 0.8) - origin).normalized(), Vector3.UP), origin
	)
	camera.fov = 52.0
	camera.current = true
	root.add_child(camera)


func _capture(path: String) -> void:
	for _frame in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_check(
		image != null and not image.is_empty() and image.save_png(path) == OK,
		"Forward+ comparison capture writes %s" % path
	)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("CINDER_CARGO_HAULER_FAILED_ENGINE_SILHOUETTE_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error("FAIL: %s" % failure)
	quit(1)
