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

	var presentation := zenith.get_zenith_authored_presentation()
	var asset_root := presentation.get_asset_root() as Node3D
	var port := asset_root.get_node_or_null(
		^"ModernSystems/LOD0/PortEnginePlume"
	) as MeshInstance3D
	var starboard := asset_root.get_node_or_null(
		^"ModernSystems/LOD0/StarboardEnginePlume"
	) as MeshInstance3D
	var batch := asset_root.get_node_or_null(
		^"ModernSystems/LOD0/CloseEnginePlumeBatch"
	) as MultiMeshInstance3D
	_check(
		port != null and starboard != null
		and port.mesh == starboard.mesh
		and port.mesh.get_surface_count() + starboard.mesh.get_surface_count() == 2
		and port.material_override == starboard.material_override
		and port.transform.is_equal_approx(
			Transform3D(Basis.IDENTITY, Vector3(-2.2, 0.38, 5.08))
		)
		and starboard.transform.is_equal_approx(
			Transform3D(Basis.IDENTITY, Vector3(2.2, 0.38, 5.08))
		),
		"two protected close plume nodes use one mesh while retaining exact transforms and material"
	)
	_check(
		batch != null and batch.multimesh != null
		and batch.multimesh.mesh == port.mesh
		and batch.multimesh.instance_count == 2
		and batch.multimesh.mesh.get_surface_count() == 1
		and batch.layers == 1 and port.layers == 0 and starboard.layers == 0,
		"the existing close plume MultiMesh still renders two copies in one submission"
	)
	zenith.engine_start_time = 0.01
	zenith.set_piloted(true)
	zenith.request_engine_start()
	await physics_frame
	_check(
		port.visible and starboard.visible
		and batch.visible and batch.multimesh.visible_instance_count == 2,
		"engine startup retains independent plume visibility control and two rendered copies"
	)

	var identity_before := zenith.get_zenith_runtime_identity_report().current as Dictionary
	zenith.update_zenith_lod_for_distance(1000.0)
	zenith.update_zenith_lod_for_distance(0.0)
	_check(
		zenith.get_zenith_runtime_identity_report().current == identity_before
		and bool(zenith.get_zenith_audit_report().valid),
		"whole-ship LOD cycling preserves shared resources and the production audit"
	)

	zenith.queue_free()
	await process_frame
	if _failures.is_empty():
		print("PASS zenith_close_plume_mesh_sharing_test (mesh resources 2->1)")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
