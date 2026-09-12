extends SceneTree

## Focused component proof and gameplay-distance capture for the Cinder cargo
## hauler's presentation-only external load frame.

const Hauler := preload("res://scripts/ships/cinder_cargo_hauler.gd")
const RESOLUTION := Vector2i(1280, 720)

var _assertions := 0
var _failures: PackedStringArray = []


func _initialize() -> void:
	root.size = RESOLUTION
	var stage := Node3D.new()
	root.add_child(stage)
	_build_capture_environment(stage)

	var craft := Hauler.new() as CinderCargoHauler
	stage.add_child(craft)
	await process_frame
	craft.set_process(false)
	craft.set_physics_process(false)

	var batch := craft.get_node_or_null(
		^"CinderCargoVisual/CargoFrameRibBatch"
	) as MultiMeshInstance3D
	var multi := batch.multimesh if batch != null else null
	var mesh := multi.mesh as ArrayMesh if multi != null else null
	_check(
		batch != null
			and multi != null
			and multi.instance_count == 8
			and mesh != null
			and mesh.get_aabb().size.is_equal_approx(Hauler.CARGO_FRAME_RIB_SIZE)
			and batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON,
		"one eight-piece freight-frame batch is present on the production hauler"
	)
	_check(
		batch != null
			and batch.get_meta(&"presentation_only", false)
			and batch.get_meta(&"color_independent", false)
			and batch.get_meta(&"silhouette_role", &"") == &"cargo_load_frame"
			and not batch.get_meta(&"animated", true)
			and batch.find_children("*", "CollisionObject3D", true, false).is_empty()
			and batch.find_children("*", "Light3D", true, false).is_empty(),
		"the repeated shape cue adds no collision, light, animation, or authority"
	)

	var transforms := batch.get_meta(&"authored_instance_transforms", []) as Array \
			if batch != null else []
	var port_count := 0
	var starboard_count := 0
	var bounded := transforms.size() == 8 and mesh != null
	var aperture_clear := bounded
	for transform_variant in transforms:
		var transform := transform_variant as Transform3D
		port_count += 1 if transform.origin.x < 0.0 else 0
		starboard_count += 1 if transform.origin.x > 0.0 else 0
		bounded = bounded \
			and absf(transform.origin.x) + mesh.get_aabb().size.x * 0.5 <= 3.40 \
			and transform.origin.y - mesh.get_aabb().size.y * 0.5 >= -1.16 \
			and transform.origin.y + mesh.get_aabb().size.y * 0.5 <= 1.57 \
			and absf(transform.origin.z) + mesh.get_aabb().size.z * 0.5 <= 6.0
		aperture_clear = aperture_clear \
			and (transform.origin.x > 0.0 \
				or absf(transform.origin.z) - mesh.get_aabb().size.z * 0.5 >= 2.30)
	_check(
		bounded and aperture_clear and port_count == 4 and starboard_count == 4,
		"the mirrored ribs stay inside the exact shell and clear the port aperture"
	)

	# A rib is 2.4 m tall: at the authored 24 m review distance and a 60-degree
	# vertical field of view it occupies over 62 pixels on a 720-line viewport.
	var projected_height_px := Hauler.CARGO_FRAME_RIB_SIZE.y * RESOLUTION.y \
			/ (2.0 * 24.0 * tan(deg_to_rad(60.0) * 0.5))
	_check(
		projected_height_px >= 60.0,
		"the repeated freight frame resolves at normal gameplay distance"
	)
	_check(
		craft.get_boarding_marker().position.is_equal_approx(Vector3(-3.4, -1.1, 0.0))
			and craft.get_cargo_transfer_anchors().size() == Hauler.CARGO_CAPACITY
			and bool(craft.get_landing_collision_report().get("valid", false))
			and not bool(craft.get_audit_report().get("cargo_transfer_authority", true))
			and not bool(craft.get_audit_report().get("network_authority", true))
			and craft.get_meta(&"evidence_status", &"") == &"NEW",
		"boarding, cargo seams, collision, authority, and NEW status remain unchanged"
	)

	var port_mount := craft.get_node_or_null(^"CinderCargoVisual/EngineRetentionSaddles") as MeshInstance3D
	var other := Hauler.new() as CinderCargoHauler
	stage.add_child(other)
	var retained_mount := other.get_node_or_null(^"CinderCargoVisual/EngineRetentionSaddles") as MeshInstance3D
	var mounts_valid := port_mount != null and retained_mount != null
	if mounts_valid:
		mounts_valid = port_mount.mesh == retained_mount.mesh \
			and port_mount.mesh.get_aabb().position.z > Hauler.PORT_APERTURE_Z_MAX \
			and port_mount.get_meta(&"presentation_only", false) \
			and port_mount.find_children("*", "CollisionObject3D", true, false).is_empty()
	_check(mounts_valid, "paired engine saddles share geometry across craft and stay behind the boarding opening")
	# Intersect the emitted housing triangles, independently of its profile
	# builder. Sampling both ends of each mounting footprint catches a curved
	# shroud slipping away from collars, roof covers or radiator feet.
	var housing_contact := true
	var contact_samples := 0
	for side in [-1.0, 1.0]:
		var tag := "Port" if side < 0 else "Starboard"
		var shroud := craft.get_node("CinderCargoVisual/" + tag + "EngineShroud") as MeshInstance3D
		var plates := craft.get_variant_visual_root().find_children(tag + "NacelleAccess*Gasket", "MeshInstance3D", false, false)
		housing_contact = housing_contact and plates.size() == 2
		for plate_node in plates:
			var plate := plate_node as MeshInstance3D
			for dx in [-0.36, 0.36]:
				for dz in [-0.27, 0.27]:
					var foot := plate.global_position + Vector3(dx, -0.014, dz)
					var hit: Variant = _housing_hit(shroud, foot + Vector3.UP, Vector3.DOWN)
					contact_samples += 1
					housing_contact = housing_contact and hit != null and absf((hit as Vector3).y - foot.y) < 0.025
		var radiator := craft.get_node("CinderCargoVisual/" + tag + "NacelleRadiator") as Node3D
		for dy in [-0.20, 0.20]:
			for dz in [-0.54, 0.54]:
				var foot := radiator.to_global(Vector3(dy, -0.025, dz))
				var outward := Vector3(side, 0, 0)
				var hit: Variant = _housing_hit(shroud, foot + outward, -outward)
				contact_samples += 1
				housing_contact = housing_contact and hit != null and absf((hit as Vector3).x - foot.x) < 0.03
		# Use actual inner-collar vertices, excluding the sloping shear webs.
		# The inner face should sit 15 mm inside the housing at each sampled
		# lower outboard shoulder at each end, with no air gap through its foot.
		var collar_arrays := port_mount.mesh.surface_get_arrays(0)
		var collar_points: PackedVector3Array = collar_arrays[Mesh.ARRAY_VERTEX]
		var collar_normals: PackedVector3Array = collar_arrays[Mesh.ARRAY_NORMAL]
		for station in [3.53, 3.77, 4.53, 4.77]:
			var sampled := {}
			for i in collar_points.size():
				var point := port_mount.to_global(collar_points[i])
				if not is_equal_approx(point.z, station) or point.x * side <= 3.75 or point.y >= 0.4:
					continue
				var radial := (point - Vector3(side * 3.75, 0.4, point.z)).normalized()
				# Inner side-wall normals face the housing axis. This selects
				# emitted inner-ring vertices at tapered AND full-size ends.
				if collar_normals[i].dot(radial) >= -0.5 or sampled.has(point):
					continue
				sampled[point] = true
				var hit: Variant = _housing_hit(shroud, point + radial, -radial)
				contact_samples += 1
				housing_contact = housing_contact and hit != null and (hit as Vector3).distance_to(point) < 0.025
			_check(sampled.size() >= 6, tag + " collar checks sample emitted inner-ring vertices at " + str(station))

	_check(housing_contact and contact_samples >= 40, "formed housings retain triangle contact with collar feet, roof access gaskets and radiator mounts")
	var retained_ribs := other.get_node_or_null(^"CinderCargoVisual/CargoFrameRibBatch") as MultiMeshInstance3D
	var belt := craft.get_node_or_null(^"CinderCargoVisual/ContinuousFreightLoadFrame") as MeshInstance3D
	var retained_belt := other.get_node_or_null(^"CinderCargoVisual/ContinuousFreightLoadFrame") as MeshInstance3D
	_check(retained_ribs != null and retained_ribs.multimesh.mesh == mesh
		and belt != null and retained_belt != null and belt.mesh == retained_belt.mesh,
		"formed ribs and continuous belts retain immutable shared stock across haulers")
	var belts_valid := belt != null
	if belts_valid:
		var arrays := belt.mesh.surface_get_arrays(0)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for triangle in range(0, indices.size(), 3):
			var a := indices[triangle]
			var b := indices[triangle + 1]
			var c := indices[triangle + 2]
			var outward := (points[c] - points[a]).cross(points[b] - points[a]).normalized()
			belts_valid = belts_valid and outward.dot(normals[a]) > 0.98
		for point in points:
			belts_valid = belts_valid and point.is_finite() and absf(point.z) >= Hauler.PORT_APERTURE_Z_MAX
	_check(belts_valid, "formed belts have exterior winding and leave the boarding bay clear")
	other.queue_free()
	var surfaces_valid := mounts_valid
	if mounts_valid:
		var arrays := port_mount.mesh.surface_get_arrays(0)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
		surfaces_valid = uv.size() == points.size() and tangents.size() == points.size() * 4
		for triangle in range(0, points.size(), 3):
			var outward := (points[triangle + 2] - points[triangle]).cross(points[triangle + 1] - points[triangle]).normalized()
			surfaces_valid = surfaces_valid and outward.dot(normals[triangle]) > 0.99
			for corner in 3:
				var i := triangle + corner
				var tangent := Vector3(tangents[i * 4], tangents[i * 4 + 1], tangents[i * 4 + 2])
				surfaces_valid = surfaces_valid and tangent.is_finite() and tangent.length() > 0.9 \
					and absf(normals[i].dot(tangent)) < 0.01
	_check(surfaces_valid, "mounting collars and closed shear webs have exterior winding, UVs and usable tangents")

	var camera := Camera3D.new()
	camera.fov = 48.0
	camera.near = 0.1
	camera.far = 100.0
	camera.position = Vector3(-16.0, 7.0, 21.0)
	camera.look_at_from_position(camera.position, Vector3(0.0, 0.25, 0.4), Vector3.UP)
	camera.current = true
	stage.add_child(camera)
	for _frame in 6:
		await process_frame
	var output_dir := "res://artifacts/cinder_cargo_hauler_freight_frame"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	var capture_path := "%s/gameplay_distance_port_aft.png" % output_dir
	var save_error := ERR_UNAVAILABLE
	if DisplayServer.get_name() != "headless":
		var viewport_texture := root.get_texture()
		var image := viewport_texture.get_image() if viewport_texture != null else null
		if image != null:
			save_error = image.save_png(ProjectSettings.globalize_path(capture_path))
	# Dummy/headless rendering intentionally has no viewport texture. The same
	# focused test writes the review image when run through a real renderer.
	_check(
		save_error == OK or DisplayServer.get_name() == "headless",
		"the gameplay-distance freight-frame capture saves when rendering is available"
	)

	craft.queue_free()
	await process_frame
	if _failures.is_empty():
		if save_error == OK:
			print("CINDER_CARGO_HAULER_FREIGHT_FRAME_CAPTURE %s" % capture_path)
		print("PASS cinder_cargo_hauler_freight_frame_visual_test (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _housing_hit(housing: MeshInstance3D, origin: Vector3, direction: Vector3) -> Variant:
	var faces := housing.mesh.get_faces()
	var closest: Variant = null
	var distance := INF
	for triangle in range(0, faces.size(), 3):
		var hit: Variant = Geometry3D.ray_intersects_triangle(origin, direction,
			housing.to_global(faces[triangle]), housing.to_global(faces[triangle + 1]), housing.to_global(faces[triangle + 2]))
		if hit != null and origin.distance_to(hit as Vector3) < distance:
			closest = hit
			distance = origin.distance_to(hit as Vector3)
	return closest


func _build_capture_environment(stage: Node3D) -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("071018")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("698096")
	environment.ambient_light_energy = 0.44
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	stage.add_child(world_environment)
	var key := DirectionalLight3D.new()
	key.light_color = Color("ffe1b8")
	key.light_energy = 2.2
	key.rotation_degrees = Vector3(-42.0, 32.0, 0.0)
	stage.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color("5dd9e2")
	rim.light_energy = 0.72
	rim.rotation_degrees = Vector3(-12.0, -145.0, 0.0)
	stage.add_child(rim)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
