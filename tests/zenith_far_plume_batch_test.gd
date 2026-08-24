extends SceneTree

const ZENITH_SCENE := preload("res://scenes/ships/zenith_interceptor.tscn")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var zenith := ZENITH_SCENE.instantiate() as ZenithInterceptor
	root.add_child(zenith)
	await process_frame
	await physics_frame

	var asset_root := zenith.get_zenith_authored_presentation().call(
		"get_asset_root"
	) as Node3D
	var batch := asset_root.get_node_or_null(
		"ModernSystems/LOD1/FarEnginePlumeBatch"
	) as MultiMeshInstance3D
	var port := asset_root.find_child(
		"LOD1PortEnginePlume", true, false
	) as MeshInstance3D
	var starboard := asset_root.find_child(
		"LOD1StarboardEnginePlume", true, false
	) as MeshInstance3D
	_check(
		batch != null and batch.multimesh != null
		and batch.multimesh.instance_count == 2
		and batch.multimesh.mesh == port.mesh
		and batch.material_override == port.material_override
		and port.material_override == starboard.material_override
		and batch.layers == 1 and port.layers == 0 and starboard.layers == 0,
		"far plumes retain both authored authorities and render through one exact batch"
	)
	_check(
		port.mesh.get_surface_count() + starboard.mesh.get_surface_count() == 2
		and batch.multimesh.mesh.get_surface_count() == 1,
		"far plume geometry submissions decrease from two to one"
	)
	_check(
		bool(zenith.get_zenith_audit_report().valid)
		and str(zenith.get_zenith_evidence_report().evidence_scope) == "B7_frames_373_467_only",
		"batching leaves the production audit and bounded evidence scope unchanged"
	)

	zenith.engine_start_time = 0.01
	zenith.set_piloted(true)
	zenith.request_engine_start()
	await physics_frame
	var transforms := batch.get_meta("authored_instance_transforms", []) as Array
	_check(
		batch.visible and batch.multimesh.visible_instance_count == 2
		and transforms.size() == 2
		and (transforms[0] as Transform3D).is_equal_approx(port.transform)
		and (transforms[1] as Transform3D).is_equal_approx(starboard.transform),
		"startup mirrors both protected plume transforms and visible copies"
	)

	var identity_before := zenith.get_zenith_runtime_identity_report().current as Dictionary
	zenith.update_zenith_lod_for_distance(1000.0)
	zenith.update_zenith_lod_for_distance(0.0)
	_check(
		zenith.get_zenith_runtime_identity_report().current == identity_before,
		"whole-ship LOD cycling preserves the batch and authored resource identities"
	)

	zenith.queue_free()
	await process_frame
	if _failures.is_empty():
		print("PASS zenith_far_plume_batch_test (far submissions 2->1)")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
