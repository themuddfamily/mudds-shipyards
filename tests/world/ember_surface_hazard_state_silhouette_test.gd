extends SceneTree

const Presentation := preload("res://scripts/world/ember_surface_hazard_zone_presentation.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var presentation := Presentation.new()
	root.add_child(presentation)
	var configured: Dictionary = presentation.configure({
		"id": &"ember_thermal_vent",
		"display_name": "Thermal Vent",
		"position_body_local_m": Vector3.ZERO,
	}, 3.0)
	var recovery_configured: Dictionary = presentation.configure_recovery_target({
		"id": &"ember_service_bunker",
		"position_body_local_m": Vector3(8.0, 0.0, 0.0),
	})
	var beacon := presentation.get_node_or_null(^"OwnedHazardBeacon") as MeshInstance3D
	var initial_mesh_count := presentation.find_children("*", "MeshInstance3D", true, false).size()
	if not configured.accepted or not recovery_configured.accepted or beacon == null:
		_fail("hazard state-silhouette fixture did not configure")
		return

	var safe := presentation.get_snapshot()
	var safe_scale := beacon.scale
	var safe_base := beacon.position.y - 1.2 * safe_scale.y
	var warning_result: Dictionary = presentation.apply_status({
		"hazard_id": &"ember_thermal_vent", "state": &"warning",
	})
	var warning := presentation.get_snapshot()
	var warning_scale := beacon.scale
	var warning_base := beacon.position.y - 1.2 * warning_scale.y
	var recovery_result: Dictionary = presentation.apply_status({
		"hazard_id": &"ember_thermal_vent", "state": &"recovery_required",
		"recovery_request": {"generation": 1},
	})
	var recovery := presentation.get_snapshot()
	var recovery_scale := beacon.scale
	var recovery_base := beacon.position.y - 1.2 * recovery_scale.y
	var material := beacon.material_override as StandardMaterial3D
	var final_mesh_count := presentation.find_children("*", "MeshInstance3D", true, false).size()

	if safe.state_shape != &"low_broad_safe_marker" \
			or warning.state_shape != &"upright_cone" \
			or recovery.state_shape != &"tall_spire_with_direction_dashes" \
			or not safe_scale.is_equal_approx(Vector3(1.35, 0.24, 1.35)) \
			or not warning_scale.is_equal_approx(Vector3.ONE) \
			or not recovery_scale.is_equal_approx(Vector3(0.72, 1.35, 0.72)) \
			or not is_zero_approx(safe_base) or not is_zero_approx(warning_base) \
			or not is_zero_approx(recovery_base):
		_fail("safe, warning, and recovery markers lack distinct surface-rooted silhouettes")
		return
	if not warning_result.accepted or not recovery_result.accepted \
			or not recovery.recovery_cue.visible \
			or material == null or material.emission_energy_multiplier > 2.4001 \
			or initial_mesh_count != final_mesh_count \
			or not presentation.find_children("*", "Light3D", true, false).is_empty() \
			or presentation.is_processing() or presentation.is_physics_processing():
		_fail("state silhouettes added flashing, light, renderer, or lifecycle behavior")
		return

	var detached: Dictionary = presentation.detach()
	var reentered: Dictionary = presentation.reenter()
	var restored := presentation.get_snapshot()
	if not detached.accepted or not reentered.accepted \
			or restored.state != &"clear" \
			or restored.state_shape != &"low_broad_safe_marker" \
			or not beacon.scale.is_equal_approx(Vector3(1.35, 0.24, 1.35)) \
			or restored.recovery_cue.visible:
		_fail("detach and reentry did not restore the safe presentation state")
		return

	presentation.queue_free()
	print("EMBER_HAZARD_STATE_SILHOUETTE_TEST_OK: safe pad / warning cone / recovery spire")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
