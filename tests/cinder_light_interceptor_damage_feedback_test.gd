extends SceneTree

const Interceptor := preload("res://scripts/ships/cinder_light_interceptor.gd")
const ShipComponentDamageType := preload("res://scripts/combat/ship_component_damage.gd")

var _assertions := 0
var _failures: PackedStringArray = []


func _initialize() -> void:
	var craft := Interceptor.new()
	root.add_child(craft)
	await process_frame
	var visual := craft.get_variant_visual_root()
	var hull := visual.get_node_or_null("HighVisibilityHull") as MeshInstance3D
	var aft_fin := visual.get_node_or_null("AftRecognitionFin") as MeshInstance3D
	var lens := visual.get_node_or_null("EngineDamageBeaconLens") as MeshInstance3D
	var light := visual.get_node_or_null("EngineDamageBeaconLight") as OmniLight3D
	var material := lens.get_active_material(0) as StandardMaterial3D if lens != null else null
	_check(
		lens != null and light != null and material != null
		and not lens.visible and not light.visible
		and bool(lens.get_meta(&"presentation_only", false))
		and not bool(lens.get_meta(&"damage_authority", true))
		and bool(light.get_meta(&"reduced_flash_safe", false))
		and not bool(light.get_meta(&"animated", true)),
		"the production interceptor starts with one static presentation-only engine beacon hidden"
	)
	var hull_bounds := _visual_local_mesh_bounds(hull)
	var fin_bounds := _visual_local_mesh_bounds(aft_fin)
	var lens_bounds := _visual_local_mesh_bounds(lens)
	var hull_aft_projection := _aft_projection(hull_bounds)
	var fin_aft_projection := _aft_projection(fin_bounds)
	var lens_aft_projection := _aft_projection(lens_bounds)
	_check(
		lens_bounds.position.z > 0.0
		and lens_bounds.position.x > 0.0
		and not lens_bounds.intersects(fin_bounds)
		and not lens_aft_projection.intersects(fin_aft_projection)
		and lens_aft_projection.position.y \
			> hull_aft_projection.position.y + hull_aft_projection.size.y
		and light.position.is_equal_approx(lens.position),
		"the upper-starboard aft mount clears both hull and recognition-fin silhouettes from behind"
	)

	var model := craft.get_component_damage()
	var engine_position := _component_local_position(
		craft, ShipComponentDamageType.COMPONENT_ENGINE_BAY
	)
	var damage_per_hit := craft.maximum_hull * 0.1
	craft.apply_damage(
		damage_per_hit,
		craft.to_global(engine_position),
		craft.global_basis.z
	)
	_check(
		is_equal_approx(
			float(craft.get_telemetry().get("hull", -1.0)),
			craft.maximum_hull * 0.9
		)
		and model.get_component_state(ShipComponentDamageType.COMPONENT_ENGINE_BAY) \
			== ShipComponentDamageType.ComponentState.IMPAIRED
		and lens.visible and light.visible
		and material.emission.is_equal_approx(Interceptor.ENGINE_DAMAGE_IMPAIRED_COLOR)
		and is_equal_approx(material.emission_energy_multiplier, 3.2)
		and is_equal_approx(light.light_energy, 3.2 * 0.48),
		"the production apply_damage entry routes engine impairment into a steady amber exterior cue"
	)

	craft.apply_damage(
		damage_per_hit,
		craft.to_global(engine_position),
		craft.global_basis.z
	)
	_check(
		is_equal_approx(
			float(craft.get_telemetry().get("hull", -1.0)),
			craft.maximum_hull * 0.8
		)
		and model.get_component_state(ShipComponentDamageType.COMPONENT_ENGINE_BAY) \
			== ShipComponentDamageType.ComponentState.FAILED
		and lens.visible and light.visible
		and material.emission.is_equal_approx(Interceptor.ENGINE_DAMAGE_FAILED_COLOR)
		and is_equal_approx(material.emission_energy_multiplier, 5.0)
		and is_equal_approx(light.light_energy, 5.0 * 0.48),
		"the second production damage hit strengthens engine failure to the same steady red cue"
	)

	var lens_id := lens.get_instance_id()
	var light_id := light.get_instance_id()
	root.remove_child(craft)
	await process_frame
	root.add_child(craft)
	await process_frame
	_check(
		lens.get_instance_id() == lens_id and light.get_instance_id() == light_id
		and lens.visible and light.visible
		and material.emission.is_equal_approx(Interceptor.ENGINE_DAMAGE_FAILED_COLOR),
		"detach/re-entry preserves the failed cue on the same reusable presentation nodes"
	)

	var reset := craft.reset_for_reuse(craft.global_transform)
	_check(
		bool(reset.get("accepted", false))
		and model.get_component_state(ShipComponentDamageType.COMPONENT_ENGINE_BAY) \
			== ShipComponentDamageType.ComponentState.NOMINAL
		and not lens.visible and not light.visible
		and is_zero_approx(material.emission_energy_multiplier)
		and is_zero_approx(light.light_energy),
		"the inherited reuse transaction restores nominal state and clears the beacon"
	)
	_check(
		craft.find_children("EngineDamageBeaconLens", "MeshInstance3D", true, false).size() == 1
		and craft.find_children("EngineDamageBeaconLight", "OmniLight3D", true, false).size() == 1
		and model.get_signal_connection_list(&"component_state_changed").size() == 1,
		"re-entry and reset retain one cue and the existing single component presentation signal"
	)

	craft.queue_free()
	await process_frame
	_finish()


func _component_local_position(ship: HeroShip, component_id: StringName) -> Vector3:
	for component in ship.get_component_damage_report().get("components", []) as Array:
		if StringName((component as Dictionary).get("id", &"")) == component_id:
			return (component as Dictionary).get("local_position", Vector3.ZERO) as Vector3
	return Vector3.ZERO


func _visual_local_mesh_bounds(instance: MeshInstance3D) -> AABB:
	if instance == null or instance.mesh == null:
		return AABB()
	return (instance.transform * instance.mesh.get_aabb()).abs()


## Orthographic aft view projects local X/Y while looking toward local -Z.
func _aft_projection(bounds: AABB) -> Rect2:
	return Rect2(
		Vector2(bounds.position.x, bounds.position.y),
		Vector2(bounds.size.x, bounds.size.y)
	)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("CINDER_LIGHT_INTERCEPTOR_DAMAGE_FEEDBACK_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error("FAIL: %s" % failure)
	quit(1)
