extends SceneTree

const Presentation := preload("res://scripts/world/ember_surface_hazard_zone_presentation.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var presentation := Presentation.new()
	root.add_child(presentation)
	var anchor := Vector3(10.0, 2.0, -4.0)
	var target := Vector3(18.0, 2.0, 2.0)
	var configured: Dictionary = presentation.configure({
		"id": &"ember_thermal_vent",
		"display_name": "Thermal Vent",
		"position_body_local_m": anchor,
	}, 3.0)
	var recovery_configured: Dictionary = presentation.configure_recovery_target({
		"id": &"ember_service_bunker",
		"position_body_local_m": target,
	})
	var batches := presentation.find_children(
		"RecoveryDirectionDashBatch", "MultiMeshInstance3D", true, false
	)
	var legacy_dashes := presentation.find_children("RecoveryDirectionDash*", "MeshInstance3D", true, false)
	if not configured.accepted or not recovery_configured.accepted \
			or batches.size() != 1 or not legacy_dashes.is_empty():
		_fail("recovery cue did not consolidate its four immutable dash resources")
		return

	var batch := batches[0] as MultiMeshInstance3D
	var multi := batch.multimesh
	var path_start := anchor + (target - anchor).normalized() * 3.0
	var path_length := target.distance_to(path_start)
	var expected_length := minf(0.75, path_length / 5.0)
	var expected_direction := (target - path_start).normalized()
	var expected_basis := Basis.looking_at(expected_direction, Vector3.UP)
	var buffer := multi.buffer if multi != null else PackedFloat32Array()
	if multi == null or multi.instance_count != 4 or multi.mesh == null \
			or not multi.mesh is BoxMesh or not (multi.mesh as BoxMesh).size.is_equal_approx(Vector3.ONE) \
			or batch.material_override == null or buffer.size() != 48:
		_fail("recovery cue batch does not use one shared unit-box mesh for four instances")
		return
	for index in 4:
		# RenderingServer transform readback can be identity in headless mode, so
		# verify the exact renderer buffer submitted by the production node.
		var transform := _transform_from_buffer(buffer, index)
		var progress := float(index + 1) / 5.0
		var expected_position := (path_start - anchor).lerp(target - anchor, progress) \
				+ Vector3.UP * 0.16
		var expected_scale := Vector3(0.22 + float(index) * 0.18, 0.08, expected_length)
		if not transform.origin.is_equal_approx(expected_position) \
				or not transform.basis.get_scale().is_equal_approx(expected_scale) \
				or not transform.basis.orthonormalized().is_equal_approx(expected_basis):
			_fail("batched dash %d changed its authored position or progressive-width silhouette" % index)
			return

	var warning: Dictionary = presentation.apply_status({
		"hazard_id": &"ember_thermal_vent", "state": &"warning",
	})
	var perimeter := presentation.get_node_or_null(^"OwnedHazardPerimeter") as MeshInstance3D
	var warning_color := (perimeter.material_override as StandardMaterial3D).albedo_color \
			if perimeter != null else Color.TRANSPARENT
	var warning_snapshot: Dictionary = presentation.get_snapshot()
	var recovery: Dictionary = presentation.apply_status({
		"hazard_id": &"ember_thermal_vent", "state": &"recovery_required",
		"recovery_request": {"generation": 1},
	})
	var recovery_color := (perimeter.material_override as StandardMaterial3D).albedo_color
	var snapshot: Dictionary = presentation.get_snapshot()
	if not warning.accepted or not recovery.accepted \
			or not warning_color.is_equal_approx(Color(1.0, 0.42, 0.04, 0.58)) \
			or not recovery_color.is_equal_approx(Color(1.0, 0.12, 0.04, 0.72)) \
			or warning_snapshot.recovery_cue.visible \
			or not (batch.material_override as StandardMaterial3D).albedo_color.is_equal_approx( \
				Color(0.92, 0.96, 1.0, 1.0)) \
			or not batch.visible or not snapshot.recovery_cue.visible \
			or snapshot.recovery_cue.active_generation != 1 \
			or not snapshot.recovery_cue.static \
			or presentation.is_processing() or presentation.is_physics_processing() \
			or snapshot.recovery_cue.color_independent_shape != &"progressive_width_dashes" \
			or snapshot.authority.damage or snapshot.authority.movement \
			or not presentation.find_children("*", "CollisionObject3D", true, false).is_empty() \
			or not presentation.find_children("*", "NavigationRegion3D", true, false).is_empty():
		_fail("batching changed cue readability, static reduced-flash behavior, or authority boundaries")
		return

	var cleared: Dictionary = presentation.apply_status({
		"hazard_id": &"ember_thermal_vent", "state": &"clear",
		"recovery_request": {"generation": 1},
	})
	var stale_replay: Dictionary = presentation.apply_status({
		"hazard_id": &"ember_thermal_vent", "state": &"recovery_required",
		"recovery_request": {"generation": 1},
	})
	var replay_snapshot: Dictionary = presentation.get_snapshot()
	if not cleared.accepted or stale_replay.accepted \
			or stale_replay.reason != &"stale_hazard_recovery_generation" \
			or replay_snapshot.state != &"clear" or replay_snapshot.recovery_cue.visible \
			or replay_snapshot.recovery_cue.retired_generation != 1:
		_fail("a cleared recovery episode replayed its stale direction cue")
		return

	var fresh_recovery: Dictionary = presentation.apply_status({
		"hazard_id": &"ember_thermal_vent", "state": &"recovery_required",
		"recovery_request": {"generation": 2},
	})
	var stale_clear: Dictionary = presentation.apply_status({
		"hazard_id": &"ember_thermal_vent", "state": &"clear",
		"recovery_request": {"generation": 1},
	})
	var fresh_snapshot: Dictionary = presentation.get_snapshot()
	var detached: Dictionary = presentation.detach()
	var detached_snapshot: Dictionary = presentation.get_snapshot()
	var reentered: Dictionary = presentation.reenter()
	var reentered_snapshot: Dictionary = presentation.get_snapshot()
	var detached_replay: Dictionary = presentation.apply_status({
		"hazard_id": &"ember_thermal_vent", "state": &"recovery_required",
		"recovery_request": {"generation": 2},
	})
	if not fresh_recovery.accepted or stale_clear.accepted \
			or fresh_snapshot.state != &"recovery_required" \
			or not fresh_snapshot.recovery_cue.visible or not detached.accepted \
			or detached_snapshot.visible or detached_snapshot.recovery_cue.visible \
			or not reentered.accepted or not reentered_snapshot.visible \
			or reentered_snapshot.state != &"clear" or reentered_snapshot.recovery_cue.visible \
			or detached_replay.accepted or presentation.get_snapshot().recovery_cue.visible:
		_fail("batching changed detach, reentry, or clear-state lifecycle transitions")
		return

	presentation.queue_free()
	print("EMBER_HAZARD_CUE_BATCH_TEST_OK: meshes 4->1 renderers 4->1 submissions 4->1")
	quit(0)


func _transform_from_buffer(buffer: PackedFloat32Array, index: int) -> Transform3D:
	var offset := index * 12
	return Transform3D(
		Basis(
			Vector3(buffer[offset], buffer[offset + 4], buffer[offset + 8]),
			Vector3(buffer[offset + 1], buffer[offset + 5], buffer[offset + 9]),
			Vector3(buffer[offset + 2], buffer[offset + 6], buffer[offset + 10])
		),
		Vector3(buffer[offset + 3], buffer[offset + 7], buffer[offset + 11])
	)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
