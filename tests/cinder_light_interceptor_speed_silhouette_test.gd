extends SceneTree

const Interceptor := preload("res://scripts/ships/cinder_light_interceptor.gd")

var _assertions := 0
var _failures: Array[String] = []


func _initialize() -> void:
	var first := Interceptor.new() as CinderLightInterceptor
	var second := Interceptor.new() as CinderLightInterceptor
	root.add_child(first)
	root.add_child(second)
	await process_frame

	var first_rails := _batch(first, ^"InterceptorSpeedRailBatch")
	var second_rails := _batch(second, ^"InterceptorSpeedRailBatch")
	var first_blades := _batch(first, ^"InterceptorWingtipBladeBatch")
	var second_blades := _batch(second, ^"InterceptorWingtipBladeBatch")
	_check(
		first_rails != null and second_rails != null
			and first_blades != null and second_blades != null,
		"both production copies retain their paired chase-distance recognition batches"
	)
	if first_rails != null and second_rails != null \
			and first_blades != null and second_blades != null:
		_check(
			first_rails.multimesh.mesh == second_rails.multimesh.mesh
				and first_rails.material_override == second_rails.material_override
				and first_blades.multimesh.mesh == second_blades.multimesh.mesh
				and first_blades.material_override == second_blades.material_override,
			"copies share immutable rail, blade and finish resources without merging renderer ownership"
		)
		var rail_material := first_rails.material_override as StandardMaterial3D
		_check(
			first_rails.multimesh.mesh is BoxMesh
				and (first_rails.multimesh.mesh as BoxMesh).size.is_equal_approx(Interceptor.SPEED_RAIL_SIZE)
				and first_rails.multimesh.instance_count == 2
				and first_rails.multimesh.visible_instance_count == 2
				and first_rails.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				and rail_material != null
				and rail_material.emission_enabled
				and rail_material.emission.is_equal_approx(Interceptor.CANOPY_COLOR)
				and is_equal_approx(rail_material.emission_energy_multiplier, 2.4),
			"the swept cyan rails retain their efficient mirrored luminous recipe"
		)
		_check(
			first_blades.multimesh.mesh is BoxMesh
				and (first_blades.multimesh.mesh as BoxMesh).size.is_equal_approx(Interceptor.WINGTIP_BLADE_SIZE)
				and first_blades.multimesh.instance_count == 2
				and first_blades.multimesh.visible_instance_count == 2
				and first_blades.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				and bool(first_blades.get_meta(&"visual_detail_only", false))
				and bool(first_blades.get_meta(&"presentation_only", false))
				and not bool(first_blades.get_meta(&"gameplay_authority", true)),
			"the canted wingtip blades remain static presentation-only geometry"
		)
		var production_wing := first.get_variant_visual_root().get_node_or_null(
			^"RapidResponseWing"
		) as MeshInstance3D
		var visual_bounds := _batch_bounds(first_rails).merge(_batch_bounds(first_blades))
		_check(
			production_wing != null
				and production_wing.mesh is BoxMesh
				and visual_bounds.position.x >= -(production_wing.mesh as BoxMesh).size.x * 0.5
				and visual_bounds.end.x <= (production_wing.mesh as BoxMesh).size.x * 0.5
				and visual_bounds.position.y >= -Interceptor.HULL_SIZE.y * 0.5
				and visual_bounds.end.y <= Interceptor.HULL_SIZE.y * 0.5
				and visual_bounds.position.z >= -Interceptor.HULL_SIZE.z * 0.5
				and visual_bounds.end.z <= Interceptor.HULL_SIZE.z * 0.5,
			"all new presentation bounds stay inside the existing wing and hull berth envelope"
		)

	var collision := first.get_landing_collision_report()
	var first_audit := first.get_audit_report()
	var second_audit := second.get_audit_report()
	_check(
		bool(collision.get("valid", false))
			and int(collision.get("shape_count", 0)) == 1
			and (collision.get("local_bounds", AABB()) as AABB).is_equal_approx(
				AABB(-Interceptor.HULL_SIZE * 0.5, Interceptor.HULL_SIZE)
			)
			and bool(first_audit.get("valid", false))
			and bool(second_audit.get("valid", false))
			and first_audit.get("evidence_status", &"") == &"NEW"
			and second_audit.get("evidence_status", &"") == &"NEW"
			and bool(first_audit.get("speed_silhouette_visual", {}).get("valid", false))
			and int(first_audit.get("speed_silhouette_visual", {}).get("lights", -1)) == 0
			and int(first_audit.get("speed_silhouette_visual", {}).get("collision_shapes", -1)) == 0
			and not bool(first_audit.get("speed_silhouette_visual", {}).get("gameplay_authority", true)),
		"silhouette polish preserves exact collision and NEW evidence while adding no light or gameplay authority"
	)
	_check(
		first.get_boarding_marker() != null
			and second.get_boarding_marker() != null
			and first.get_cockpit_seat_anchor() != null
			and second.get_cockpit_seat_anchor() != null
			and first.get_weapon_definition().weapon_id == Interceptor.WEAPON_ID
			and second.get_weapon_definition().weapon_id == Interceptor.WEAPON_ID
			and not bool(first_audit.get("berth_authority", true))
			and not bool(first_audit.get("combat_authority", true))
			and not bool(first_audit.get("network_authority", true)),
		"boarding, cockpit, weapons, berth, combat and network contracts remain unchanged"
	)

	first.queue_free()
	second.queue_free()
	await process_frame
	_check(
		not is_instance_valid(first) and not is_instance_valid(second),
		"both craft cleanly leave the lifecycle while immutable silhouette stock remains process-owned"
	)

	if _failures.is_empty():
		print("CINDER_INTERCEPTOR_SPEED_SILHOUETTE: renderers 4->2 instances 4->4 lights +0 collision +0")
		print("PASS cinder_light_interceptor_speed_silhouette_test (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _batch(craft: CinderLightInterceptor, path: NodePath) -> MultiMeshInstance3D:
	var visual := craft.get_variant_visual_root()
	return visual.get_node_or_null(path) as MultiMeshInstance3D if visual != null else null


func _batch_bounds(batch: MultiMeshInstance3D) -> AABB:
	var result := AABB()
	var has_bounds := false
	var transforms: Array = batch.get_meta(&"authored_instance_transforms", [])
	for transform_value in transforms:
		var transformed := ((transform_value as Transform3D) * batch.multimesh.mesh.get_aabb()).abs()
		result = transformed if not has_bounds else result.merge(transformed)
		has_bounds = true
	return result


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
