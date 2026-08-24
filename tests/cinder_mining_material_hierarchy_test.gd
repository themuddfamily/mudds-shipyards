extends SceneTree

const CLUSTER_SCENE := preload("res://scenes/world/components/nearby_sector_cluster.tscn")
const PRESENTATION_PATH := ^"ExtractionPlatform/CinderReachPlatform/MiningActivityPresentation"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var cluster := CLUSTER_SCENE.instantiate() as NearbySectorCluster
	root.add_child(cluster)
	await process_frame
	var presentation := cluster.get_node_or_null(PRESENTATION_PATH) as Node3D
	_check(presentation != null, "production Cinder mining presentation instantiates")
	if presentation == null:
		_finish(cluster)
		return

	var roles := {
		&"service": {
			"key": &"mining_service",
			"nodes": [^"MiningFeedChutes", ^"MiningOreBufferBins"],
			"color": NearbySectorCluster.HULL_SHADOW,
			"metallic": 0.3,
			"roughness": 0.7,
			"coat": Vector2(StationSurfaceKit.WALKED_CLEARCOAT, StationSurfaceKit.WALKED_CLEARCOAT_ROUGHNESS),
		},
		&"structure": {
			"key": &"mining_structure",
			"nodes": [^"HeadframeHeader", ^"MiningHeadframeLegs"],
			"color": NearbySectorCluster.STEEL_BLUE,
			"metallic": 0.5,
			"roughness": 0.36,
			"coat": Vector2(StationSurfaceKit.STRUCTURAL_CLEARCOAT, StationSurfaceKit.STRUCTURAL_CLEARCOAT_ROUGHNESS),
		},
		&"machinery": {
			"key": &"mining_machinery",
			"nodes": [^"OreSeparatorHopper"],
			"color": NearbySectorCluster.HULL_OCHRE,
			"metallic": 0.2,
			"roughness": 0.66,
			"coat": Vector2(StationSurfaceKit.PAINTED_CLEARCOAT, StationSurfaceKit.PAINTED_CLEARCOAT_ROUGHNESS),
		},
		&"trim": {
			"key": &"mining_trim",
			"nodes": [^"MiningHeadframeBraces", ^"HopperServiceBand", ^"MiningOreBufferBands"],
			"color": NearbySectorCluster.KETH_ORANGE,
			"metallic": 0.1,
			"roughness": 0.56,
			"coat": Vector2(StationSurfaceKit.TRIM_CLEARCOAT, StationSurfaceKit.TRIM_CLEARCOAT_ROUGHNESS),
		},
	}
	var distinct_materials := {}
	for role: StringName in roles:
		var spec := roles[role] as Dictionary
		var expected := cluster._materials[spec.key] as StandardMaterial3D
		var coat := spec.coat as Vector2
		distinct_materials[expected.get_instance_id()] = true
		_check(
			expected.albedo_color.is_equal_approx(spec.color as Color)
			and is_equal_approx(expected.metallic, float(spec.metallic))
			and is_equal_approx(expected.roughness, float(spec.roughness))
			and expected.clearcoat_enabled
			and is_equal_approx(expected.clearcoat, coat.x)
			and is_equal_approx(expected.clearcoat_roughness, coat.y),
			"%s keeps its Cinder scalar palette with the shared physical finish" % role
		)
		for node_path: NodePath in spec.nodes:
			var renderer := presentation.get_node_or_null(node_path) as GeometryInstance3D
			_check(
				renderer != null and renderer.material_override == expected,
				"%s renderer %s uses the dedicated material" % [role, node_path]
			)
	_check(distinct_materials.size() == 4, "the mining silhouette exposes four distinct non-emissive finish roles")

	var audit := cluster.get_mining_platform_presentation_audit()
	var counts := audit.counts as Dictionary
	_check(
		bool(audit.valid) and (audit.errors as PackedStringArray).is_empty(),
		"production mining audit accepts the live material hierarchy"
	)
	_check(
		int(counts.renderer_nodes) == 11
		and int(counts.visible_copies) == 18
		and int(counts.surface_submissions) == 11
		and int(counts.mesh_resource_allocations) == 10
		and int(counts.light_nodes) == 2
		and int(counts.descendant_nodes) == 14,
		"material hierarchy preserves every mining render, light, and node budget"
	)

	var feed_chutes := presentation.get_node(^"MiningFeedChutes") as MultiMeshInstance3D
	var original: Material = feed_chutes.material_override
	feed_chutes.material_override = cluster._materials[&"mining_structure"]
	var drifted := cluster.get_mining_platform_presentation_audit()
	_check(
		not bool(drifted.valid)
		and (drifted.errors as PackedStringArray).has("mining_service_material_hierarchy_drift"),
		"production audit rejects a flattened service finish"
	)
	feed_chutes.material_override = original
	_check(bool(cluster.get_mining_platform_presentation_audit().valid), "restoring the finish restores the audit")
	_finish(cluster)


func _finish(cluster: Node) -> void:
	cluster.queue_free()
	if _failures.is_empty():
		print("OK cinder_mining_material_hierarchy_test")
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)
	quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
