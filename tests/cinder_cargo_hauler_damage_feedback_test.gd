extends SceneTree

const Hauler := preload("res://scripts/ships/cinder_cargo_hauler.gd")
const ShipComponentDamageType := preload("res://scripts/combat/ship_component_damage.gd")

var _assertions := 0
var _failures: PackedStringArray = []


func _initialize() -> void:
	var craft := Hauler.new()
	root.add_child(craft)
	await process_frame
	var shoulders := craft.get_node_or_null(
		^"CinderCargoVisual/CargoShoulderBatch"
	) as MultiMeshInstance3D
	var model := craft.get_component_damage()
	var nominal_transforms := _presented_transforms(shoulders)
	var nominal_material := shoulders.material_override if shoulders != null else null
	var cargo_paths := _cargo_anchor_paths(craft)
	var loadmaster_anchor_id := craft.get_loadmaster_station_anchor().get_instance_id()
	var loadmaster_interaction_id := craft.get_loadmaster_interaction().get_instance_id()
	_check(
		shoulders != null and shoulders.multimesh.instance_count == 4
		and shoulders.get_meta(&"damage_component_id", &"") \
			== ShipComponentDamageType.COMPONENT_ENGINE_BAY
		and not bool(shoulders.get_meta(&"damage_authority", true))
		and not bool(shoulders.get_meta(&"animated", true))
		and shoulders.get_meta(&"damage_state", &"") == &"nominal",
		"the production hauler starts with one steady presentation-only shoulder cue in nominal state"
	)

	var engine_position := _component_local_position(
		craft, ShipComponentDamageType.COMPONENT_ENGINE_BAY
	)
	craft.apply_damage(
		craft.maximum_hull * 0.1,
		craft.to_global(engine_position),
		craft.global_basis.z
	)
	var damaged_transforms := _presented_transforms(shoulders)
	var damaged_material := shoulders.material_override as StandardMaterial3D
	_check(
		model.get_component_state(ShipComponentDamageType.COMPONENT_ENGINE_BAY) \
			== ShipComponentDamageType.ComponentState.IMPAIRED
		and is_equal_approx(
			float(craft.get_telemetry().get("hull", -1.0)), craft.maximum_hull * 0.9
		)
		and shoulders.get_meta(&"damage_state", &"") == &"impaired"
		and damaged_material != null
		and damaged_material.albedo_color.is_equal_approx(
			Hauler.ENGINE_DAMAGE_SHOULDER_COLOR
		)
		and damaged_material.emission.is_equal_approx(
			Hauler.ENGINE_DAMAGE_SHOULDER_COLOR
		),
		"production HeroShip.apply_damage drives the existing engine ledger into a steady amber hauler cue"
	)
	_check(
		damaged_transforms[0].is_equal_approx(nominal_transforms[0])
		and damaged_transforms[1].is_equal_approx(nominal_transforms[1])
		and not damaged_transforms[2].is_equal_approx(nominal_transforms[2])
		and not damaged_transforms[3].is_equal_approx(nominal_transforms[3])
		and is_equal_approx(
			damaged_transforms[2].basis.get_scale().y,
			Hauler.ENGINE_DAMAGE_SHOULDER_Y_SCALE
		),
		"only the aft shoulder pair rises into the engine-isolation silhouette"
	)

	var hull_top := Hauler.HULL_SIZE.y * 0.5
	var damaged_bounds := shoulders.get_meta(&"presented_local_bounds", AABB()) as AABB
	var silhouette_clearance := damaged_bounds.end.y - hull_top
	# A 70-degree exterior camera at 24 m resolves this clearance to at least
	# five pixels on a conservative 720-line gameplay viewport.
	var projected_clearance_px := silhouette_clearance * 720.0 \
		/ (2.0 * 24.0 * tan(deg_to_rad(70.0) * 0.5))
	_check(
		silhouette_clearance >= 0.24 and projected_clearance_px >= 5.0,
		"the raised rails clear the hull roof by a gameplay-distance-visible screen projection"
	)
	_check(
		_damaged_shoulders_have_collision_support(craft, shoulders),
		"every raised solid-looking shoulder corner remains supported by the production collision shell"
	)
	_check(
		_cargo_anchor_paths(craft) == cargo_paths
		and craft.get_audit_report().get("cargo_transfer_authority", true) == false
		and craft.get_loadmaster_station_anchor().get_instance_id() == loadmaster_anchor_id
		and craft.get_loadmaster_interaction().get_instance_id() == loadmaster_interaction_id,
		"damage presentation preserves cargo anchors, loadmaster identity, and authority boundaries"
	)

	var shoulder_id := shoulders.get_instance_id()
	root.remove_child(craft)
	await process_frame
	root.add_child(craft)
	await process_frame
	_check(
		shoulders.get_instance_id() == shoulder_id
		and shoulders.get_meta(&"damage_state", &"") == &"impaired"
		and _presented_transforms(shoulders) == damaged_transforms,
		"detach and re-entry retain the impaired cue on the same authored batch"
	)

	var reset := craft.reset_for_reuse(craft.global_transform)
	_check(
		bool(reset.get("accepted", false))
		and model.get_component_state(ShipComponentDamageType.COMPONENT_ENGINE_BAY) \
			== ShipComponentDamageType.ComponentState.NOMINAL
		and shoulders.get_meta(&"damage_state", &"") == &"nominal"
		and _presented_transforms(shoulders) == nominal_transforms
		and shoulders.material_override == nominal_material
		and _cargo_anchor_paths(craft) == cargo_paths
		and craft.get_loadmaster_station_anchor().get_instance_id() == loadmaster_anchor_id
		and craft.get_loadmaster_interaction().get_instance_id() == loadmaster_interaction_id,
		"pool reuse restores the nominal silhouette and preserves the cargo contract"
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


func _damaged_shoulders_have_collision_support(
		craft: Hauler,
		shoulders: MultiMeshInstance3D
	) -> bool:
	if shoulders == null or shoulders.multimesh == null:
		return false
	var collision_bounds: Array[AABB] = []
	for node in craft.find_children("*", "CollisionShape3D", true, false):
		var shape_node := node as CollisionShape3D
		if shape_node.name.begins_with("CargoHull") and shape_node.shape is BoxShape3D:
			var box := shape_node.shape as BoxShape3D
			collision_bounds.append(
				(shape_node.transform * AABB(-box.size * 0.5, box.size)).abs()
			)
	for index in [2, 3]:
		var instance_bounds := (
			_presented_transforms(shoulders)[index] \
			* shoulders.multimesh.mesh.get_aabb()
		).abs()
		for x in [instance_bounds.position.x, instance_bounds.end.x]:
			for y in [instance_bounds.position.y, instance_bounds.end.y]:
				for z in [instance_bounds.position.z, instance_bounds.end.z]:
					var supported := false
					for collision_bound in collision_bounds:
						if collision_bound.grow(0.001).has_point(Vector3(x, y, z)):
							supported = true
							break
					if not supported:
						return false
	return true


func _cargo_anchor_paths(craft: Hauler) -> PackedStringArray:
	var paths := PackedStringArray()
	for anchor in craft.get_cargo_transfer_anchors():
		paths.append(str(craft.get_path_to(anchor)))
	return paths


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("CINDER_CARGO_HAULER_DAMAGE_FEEDBACK_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error("FAIL: %s" % failure)
	quit(1)
