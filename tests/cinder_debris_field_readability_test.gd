extends SceneTree

## Focused presentation regression for the existing Cinder traversal debris.
## It protects only the player-visible contract introduced here: one neutral
## vertex-colour batch, larger gameplay-distance shards, and distinct cool/warm
## flanks. Collision, route order, rewards, and activity authority stay elsewhere.

const CLUSTER_SCENE := preload("res://scenes/world/components/nearby_sector_cluster.tscn")

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(Vector2i(1280, 720))
		root.size = Vector2i(1280, 720)
	var cluster := CLUSTER_SCENE.instantiate() as NearbySectorCluster
	root.add_child(cluster)
	await process_frame
	var chips := cluster.get_node_or_null(^"DebrisField/DebrisChips") as MultiMeshInstance3D
	_check(chips != null and chips.multimesh != null, "the production debris batch exists")
	if chips == null or chips.multimesh == null:
		await _finish(cluster)
		return

	var mesh := chips.multimesh.mesh as ArrayMesh
	var material := mesh.surface_get_material(0) as StandardMaterial3D if mesh != null else null
	_check(
		material != null
		and material.vertex_color_use_as_albedo
		and material.albedo_color.is_equal_approx(NearbySectorCluster.DEBRIS_CHIP_NEUTRAL_BASE)
		and not material.emission_enabled,
		"the batch exposes its authored vertex palette without dark base multiplication or glow"
	)
	_check(
		NearbySectorCluster.DEBRIS_CHIP_MESH_SIZE.is_equal_approx(Vector3(1.4, 0.85, 1.8))
		and is_equal_approx(NearbySectorCluster.DEBRIS_CHIP_MINIMUM_SCALE, 0.85)
		and is_equal_approx(NearbySectorCluster.DEBRIS_CHIP_MAXIMUM_SCALE, 2.75),
		"shard silhouettes retain the gameplay-distance size floor"
	)

	var cluster_indices := chips.get_meta(
		&"authored_cluster_indices", PackedInt32Array()
	) as PackedInt32Array
	# Dummy headless renderers return zeroed live MultiMesh buffers. The authored
	# CPU colours are retained beside the existing authored position recipe so
	# this contract measures the same data submitted to a real renderer.
	var authored_colors := chips.get_meta(
		&"authored_instance_colors", PackedColorArray()
	) as PackedColorArray
	var cool_samples: Array[Color] = []
	var warm_samples: Array[Color] = []
	for index in mini(authored_colors.size(), cluster_indices.size()):
		var color := authored_colors[index]
		if cluster_indices[index] % 2 == 0:
			cool_samples.append(color)
		else:
			warm_samples.append(color)
	var cool_average := _average(cool_samples)
	var warm_average := _average(warm_samples)
	print(
		"CINDER_DEBRIS_PALETTE: cool=%s warm=%s distance=%.4f size=%s scale=%.3f..%.3f" % [
			str(cool_average), str(warm_average),
			Vector3(cool_average.r, cool_average.g, cool_average.b).distance_to(
				Vector3(warm_average.r, warm_average.g, warm_average.b)
			), str(NearbySectorCluster.DEBRIS_CHIP_MESH_SIZE),
			NearbySectorCluster.DEBRIS_CHIP_MINIMUM_SCALE,
			NearbySectorCluster.DEBRIS_CHIP_MAXIMUM_SCALE,
		]
	)
	_check(
		cool_samples.size() == 260 and warm_samples.size() == 260,
		"all 520 existing shards divide evenly across the four port and four starboard clusters"
	)
	_check(
		cool_average.b > cool_average.r
		and warm_average.r > warm_average.b
		and Vector3(cool_average.r, cool_average.g, cool_average.b).distance_to(
			Vector3(warm_average.r, warm_average.g, warm_average.b)
		) >= 0.16,
		"the route keeps a measurable cool-port / warm-starboard colour separation"
	)
	_check(
		StringName(chips.get_meta(&"visual_palette_id", &""))
			== &"cinder-cool-port-warm-starboard"
		and bool(chips.get_meta(&"presentation_only", false))
		and chips.find_children("*", "CollisionObject3D", true, false).is_empty()
		and chips.find_children("*", "Light3D", true, false).is_empty()
		and cluster.get_cluster_audit_report().get("evidence_status") == &"modern_interpretation",
		"the readability pass remains presentation-only modern interpretation"
	)
	if DisplayServer.get_name() != "headless":
		await _capture_debris_corridor()

	await _finish(cluster)


func _average(colors: Array[Color]) -> Color:
	if colors.is_empty():
		return Color.BLACK
	var total := Color(0.0, 0.0, 0.0, 0.0)
	for color in colors:
		total += color
	return total / float(colors.size())


func _capture_debris_corridor() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("07121c")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("718ca5")
	environment.ambient_light_energy = 0.42
	world_environment.environment = environment
	root.add_child(world_environment)

	var key := DirectionalLight3D.new()
	key.light_color = Color("f3dfca")
	key.light_energy = 1.15
	key.shadow_enabled = false
	key.rotation_degrees = Vector3(-42.0, -28.0, 0.0)
	root.add_child(key)

	var camera := Camera3D.new()
	camera.position = Vector3(28.0, 72.0, -175.0)
	camera.fov = 72.0
	camera.far = 1200.0
	root.add_child(camera)
	camera.look_at(Vector3(30.0, -28.0, -430.0), Vector3.UP)
	camera.current = true
	for _unused in 5:
		await process_frame
	var output_dir := "res://artifacts/nearby-sector"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	var output_path := "%s/debris_field_readability.png" % output_dir
	var image := root.get_texture().get_image()
	var result := image.save_png(output_path)
	_check(result == OK, "the bounded debris-corridor capture writes successfully")
	print("CINDER_DEBRIS_CAPTURE: %s (%dx%d)" % [output_path, image.get_width(), image.get_height()])


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish(cluster: Node) -> void:
	cluster.queue_free()
	await process_frame
	if _failures.is_empty():
		print("PASS cinder_debris_field_readability_test (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
