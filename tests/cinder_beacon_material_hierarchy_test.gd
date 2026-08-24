extends SceneTree

const CLUSTER_SCENE := preload("res://scenes/world/components/nearby_sector_cluster.tscn")
const BEACON_NAMES := [
	"RouteBeaconAlpha", "RouteBeaconBravo", "RouteBeaconCharlie", "RouteBeaconDelta",
]

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var cluster := CLUSTER_SCENE.instantiate() as NearbySectorCluster
	root.add_child(cluster)
	await process_frame
	var route_root := cluster.get_node(^"RouteBeacons") as Node3D
	var roles := {
		&"structure": {
			"key": &"beacon_structure",
			"nodes": [^"Mast", ^"VaneSpar"],
			"color": NearbySectorCluster.STEEL_BLUE,
			"metallic": 0.5,
			"roughness": 0.36,
			"coat": Vector2(
				StationSurfaceKit.STRUCTURAL_CLEARCOAT,
				StationSurfaceKit.STRUCTURAL_CLEARCOAT_ROUGHNESS
			),
		},
		&"painted": {
			"key": &"beacon_painted_body",
			"nodes": [^"CounterVane"],
			"color": NearbySectorCluster.HULL_OCHRE,
			"metallic": 0.2,
			"roughness": 0.66,
			"coat": Vector2(
				StationSurfaceKit.PAINTED_CLEARCOAT,
				StationSurfaceKit.PAINTED_CLEARCOAT_ROUGHNESS
			),
		},
		&"service": {
			"key": &"beacon_service_body",
			"nodes": [^"SignBoard"],
			"color": NearbySectorCluster.HULL_SHADOW,
			"metallic": 0.3,
			"roughness": 0.7,
			"coat": Vector2(
				StationSurfaceKit.WALKED_CLEARCOAT,
				StationSurfaceKit.WALKED_CLEARCOAT_ROUGHNESS
			),
		},
		&"trim": {
			"key": &"beacon_trim",
			"nodes": [^"TrimRing"],
			"color": NearbySectorCluster.KETH_ORANGE,
			"metallic": 0.1,
			"roughness": 0.56,
			"coat": Vector2(
				StationSurfaceKit.TRIM_CLEARCOAT,
				StationSurfaceKit.TRIM_CLEARCOAT_ROUGHNESS
			),
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
			and not expected.emission_enabled
			and expected.clearcoat_enabled
			and is_equal_approx(expected.clearcoat, coat.x)
			and is_equal_approx(expected.clearcoat_roughness, coat.y),
			"%s keeps its exact Cinder scalar recipe with its physical finish" % role
		)
		for beacon_name: String in BEACON_NAMES:
			var beacon := route_root.get_node(NodePath(beacon_name)) as Node3D
			for node_path: NodePath in spec.nodes:
				var renderer := beacon.get_node(node_path) as GeometryInstance3D
				_check(
					renderer.material_override == expected,
					"%s %s uses the dedicated %s material" % [beacon_name, node_path, role]
				)
	_check(distinct_materials.size() == 4, "beacons expose four distinct non-emissive finish roles")

	var alpha := route_root.get_node(^"RouteBeaconAlpha") as Node3D
	var signal_ring := alpha.get_node(^"SignalRing") as MeshInstance3D
	var home_lens := alpha.get_node(^"HomeLampLens") as MeshInstance3D
	var outbound_lens := alpha.get_node(^"OutboundLampLens") as MeshInstance3D
	var signal_material := signal_ring.material_override as StandardMaterial3D
	var home_material := home_lens.material_override as StandardMaterial3D
	var outbound_material := outbound_lens.material_override as StandardMaterial3D
	_check(
		signal_material == cluster._materials[&"orange_glow"]
		and signal_material.emission_enabled
		and signal_material.emission.is_equal_approx(NearbySectorCluster.KETH_ORANGE)
		and is_equal_approx(signal_material.emission_energy_multiplier, 1.4)
		and home_material.emission_enabled
		and home_material.emission.is_equal_approx(NearbySectorCluster.KETH_CYAN)
		and is_equal_approx(home_material.emission_energy_multiplier, 1.6)
		and outbound_material.emission_enabled
		and outbound_material.emission.is_equal_approx(NearbySectorCluster.KETH_ORANGE)
		and is_equal_approx(outbound_material.emission_energy_multiplier, 1.6),
		"material hierarchy preserves the exact authored emissive route and lamp recipes"
	)

	var audit := cluster.get_beacon_traversal_presentation_audit()
	_check(
		bool(audit.valid) and (audit.errors as PackedStringArray).is_empty(),
		"production beacon audit accepts the live material hierarchy"
	)
	var mast := alpha.get_node(^"Mast") as MeshInstance3D
	var original := mast.material_override
	mast.material_override = cluster._materials[&"beacon_painted_body"]
	var drifted := cluster.get_beacon_traversal_presentation_audit()
	_check(
		not bool(drifted.valid)
		and (drifted.errors as PackedStringArray).has(
			"beacon_traversal_structure_material_hierarchy_drift"
		),
		"production audit rejects flattened structural beacon hardware"
	)
	mast.material_override = original
	_check(bool(cluster.get_beacon_traversal_presentation_audit().valid), "restoring the finish restores the audit")

	cluster.queue_free()
	await process_frame
	if _failures.is_empty():
		print("OK cinder_beacon_material_hierarchy_test")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
