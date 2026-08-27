extends SceneTree

## Focused Forward+ render and structural regression for the Halyard cabin's
## non-interactive fore/aft silhouette cue.

const HALYARD_SCENE := preload("res://scenes/ships/halyard_crew_transport.tscn")
const OUTPUT_PATH := "res://artifacts/halyard_cabin_forward_taper.png"
const STOWAGE_PATHS := [
	NodePath("WalkableInterior/CrewCabin/PortOverheadStowage"),
	NodePath("WalkableInterior/CrewCabin/StarboardOverheadStowage"),
]

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_2X
	root.add_child(viewport)

	var world := Node3D.new()
	viewport.add_child(world)
	var environment := WorldEnvironment.new()
	var resource := Environment.new()
	resource.background_mode = Environment.BG_COLOR
	resource.background_color = Color("06111a")
	resource.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	resource.ambient_light_color = Color("9eb3aa")
	resource.ambient_light_energy = 0.28
	resource.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.environment = resource
	world.add_child(environment)

	var craft := HALYARD_SCENE.instantiate() as HeroShip
	world.add_child(craft)
	await process_frame
	await physics_frame
	_check(craft != null, "Halyard production scene instantiates")
	if craft == null:
		_finish(viewport)
		return

	var stowages: Array[MeshInstance3D] = []
	for path in STOWAGE_PATHS:
		var stowage := craft.get_node_or_null(path) as MeshInstance3D
		_check(stowage != null, "%s remains present" % path)
		if stowage != null:
			stowages.append(stowage)
			_check(stowage.get_child_count() == 0, "%s stays childless visual dressing" % path)
			_check(stowage.get_meta("orientation_cue", &"") == &"flight_deck_forward", "%s identifies the flight deck only as presentation" % path)
			_check(stowage.mesh != null and stowage.mesh.resource_name == "HalyardCabinForwardTaperStowage", "%s uses the tapered cabin mesh" % path)
			var material := stowage.material_override as StandardMaterial3D
			_check(material == craft.get_variant_materials().get("hull_olive") and not material.emission_enabled, "%s uses the existing matte identity material" % path)
			_check(not stowage.has_meta("route_id") and not stowage.has_meta("seat_id") and not stowage.has_meta("interaction_id"), "%s grants no route, seat or interaction semantics" % path)
	if stowages.size() == 2:
		_check(stowages[0].mesh == stowages[1].mesh, "both existing lockers share one renderer resource")
		var bounds := stowages[0].mesh.get_aabb()
		_check(bounds.position.is_equal_approx(Vector3(-0.55, -0.26, -3.60)) and bounds.size.is_equal_approx(Vector3(1.10, 0.52, 7.20)), "taper preserves the existing locker envelope")
		var vertices := stowages[0].mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var forward_width := _width_at_z(vertices, -3.60)
		var aft_width := _width_at_z(vertices, 3.60)
		_check(is_equal_approx(forward_width, 0.56) and is_equal_approx(aft_width, 1.10), "locker silhouette narrows only toward ship-local forward (-Z)")

	var camera := Camera3D.new()
	camera.position = craft.to_global(Vector3(0.0, 2.10, 1.90))
	camera.fov = 72.0
	camera.near = 0.05
	camera.far = 300.0
	camera.current = true
	world.add_child(camera)
	camera.look_at(craft.to_global(Vector3(0.0, 2.05, -9.35)), Vector3.UP)
	for _frame in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	var image := viewport.get_texture().get_image()
	_check(image != null and not image.is_empty(), "Forward+ produced a cabin frame")
	if image != null and not image.is_empty():
		_check(image.save_png(ProjectSettings.globalize_path(OUTPUT_PATH)) == OK, "cabin frame saves")

	_finish(viewport)


func _width_at_z(vertices: PackedVector3Array, target_z: float) -> float:
	var minimum := INF
	var maximum := -INF
	for vertex in vertices:
		if is_equal_approx(vertex.z, target_z):
			minimum = minf(minimum, vertex.x)
			maximum = maxf(maximum, vertex.x)
	return maximum - minimum


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish(viewport: SubViewport) -> void:
	viewport.queue_free()
	if _failures.is_empty():
		print("HALYARD_CABIN_ORIENTATION_CUE_OK")
		quit(0)
	else:
		print("HALYARD_CABIN_ORIENTATION_CUE_FAILED: ", "; ".join(_failures))
		quit(1)
