class_name UtopiaDropship
extends HeroShip

## Original modern Utopia pilot foundation; A3 supplies only the name and role.
## Metres, +Y up, -Z forward. Supported landed stern access is physical;
## cargo, berths and crew reservations remain inert, never capabilities/writers.
const DEFINITION := preload("res://assets/ships/utopia_provisional.tres")
const HULL_BOUNDS := AABB(Vector3(-4.5, 0.0, -8.5), Vector3(9.0, 4.8, 17.0))
const PILOT_FEET := Vector3(0.0, 0.8, -5.8)
const PILOT_EYE := Vector3(0.0, 2.56, -6.05)
const FUTURE_ENTRY := Vector3(0.8, 0.8, -5.8)
const RAMP_STOW_ANGLE := -PI / 2.0 - atan(0.8 / 4.5)
const ACCESS_MOTION_SECONDS := 1.2
var _original_shell: Node3D
var _access_leaves: Array[Dictionary] = []
var _access_fraction := 0.0


func _init() -> void:
	ship_definition = DEFINITION
	cockpit_camera_position = PILOT_EYE


func _uses_torrent_reconstruction_presentation() -> bool:
	return false


func get_variant_visual_root() -> Node3D:
	return _original_shell


func _uses_weapon_component_fallback_emitters() -> bool:
	# The logical muzzle sits 0.2m beyond the nose; no physical fitting does.
	return false


func _get_weapon_targeting_distance() -> float:
	return 650.0 * lerpf(FAILED_SENSOR_MANUAL_AIM_DISTANCE_FACTOR, 1.0,
		_get_damage_targeting_multiplier())


func _wake_engine_for_automatic_demand(release_dock_latch: bool = true) -> void:
	# Demand must traverse the same timed OFFLINE -> STARTING -> ONLINE edges
	# as an explicit start. A held command never restarts the spool timer.
	if _engine_state != ENGINE_OFFLINE or _destroyed or _hull <= 0.0:
		return
	var retained_latch := _docked_latch
	request_engine_start()
	if not release_dock_latch:
		_docked_latch = retained_latch


func _build_ship() -> void:
	if _built:
		return
	_built = true
	collision_layer = PhysicsLayers.SHIP_BODY_LAYER
	collision_mask = PhysicsLayers.SHIP_BODY_MASK
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	floor_stop_on_slope = false
	_original_shell = Node3D.new()
	_original_shell.name = "UtopiaOriginalShell"
	_original_shell.set_meta("design_origin", &"original_modern_interpretation")
	_original_shell.set_meta("name_to_model_status", &"unknown")
	add_child(_original_shell)
	# Keep solid shell and root collision in the same physical frame. The common
	# visual bank is reserved for the non-solid cockpit presentation hierarchy.
	_visual_root = Node3D.new()
	_visual_root.name = "UtopiaPilotPresentation"
	add_child(_visual_root)
	_cockpit_root = Node3D.new()
	_cockpit_root.name = "CockpitInterior"
	_visual_root.add_child(_cockpit_root)
	var cream := _shell_material(Color("e7dfca"), 0.30, 0.62)
	var orange := _shell_material(Color("f46e24"), 0.22, 0.56)
	var glass := _shell_material(Color(0.12, 0.30, 0.34, 0.16), 0.12, 0.18)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# All sections are convex and meet only at faces/edges. No enclosing cabin
	# collider exists: the full reserved hold is genuinely hollow above y=.8.
	_add_section_box("CargoDeck", Vector3(-3.1, 0, -7), Vector3(3.1, 0.8, 8), cream)
	_add_section_box("CargoCrown", Vector3(-3.1, 4.6, -7), Vector3(3.1, 4.8, 8.5), cream)
	_add_section_box("PortCargoWall", Vector3(-3.1, 0.8, -6.8), Vector3(-2.9, 4.6, 7.5), cream)
	_add_section_box("StarboardCargoWall", Vector3(2.9, 0.8, -6.8), Vector3(3.1, 4.6, 7.5), cream)
	_add_section_box("BowSill", Vector3(-3.1, 0.8, -7), Vector3(3.1, 1.6, -6.8), orange)
	_add_section_box("BowWindshield", Vector3(-3.1, 1.6, -7), Vector3(3.1, 4.6, -6.8), glass)
	_add_section_box("PortSternCheek", Vector3(-3.1, 0.8, 7.5), Vector3(-1.2, 4.6, 8.5), cream)
	_add_section_box("StarboardSternCheek", Vector3(1.2, 0.8, 7.5), Vector3(3.1, 4.6, 8.5), cream)
	_add_section_box("SternHeader", Vector3(-1.2, 3.2, 7.5), Vector3(1.2, 4.6, 8.5), cream)
	_add_section_box("PortAftLiftHousing", Vector3(-4.5, 0, 4), Vector3(-3.1, 2.2, 8.5), orange)
	_add_section_box("StarboardAftLiftHousing", Vector3(3.1, 0, 4), Vector3(4.5, 2.2, 8.5), orange)
	_build_stern_access(orange)
	_add_nose_wedge(cream)
	_pilot_seat_anchor = _reservation_marker("pilot_station", PILOT_FEET, self)
	_pilot_seat_anchor.set_meta("station_id", &"pilot_station")
	_boarding_entry_marker = _reservation_marker("FutureHelmStand", FUTURE_ENTRY, self)
	_reservation_marker("DockingReceiver", Vector3.ZERO, self)
	var racks := Node3D.new()
	racks.name = "FutureRackReservations"
	racks.set_meta("reservation_only", true)
	add_child(racks)
	for side in [-1.0, 1.0]:
		for index in range(4):
			_reservation_marker("%sRack%02d" % ["Port" if side < 0 else "Starboard", index],
				Vector3(side * 2.0, 0.8, -1.2 + index * 2.0), racks)
	# Reuse only the common functional camera rig, then replace its temporary
	# logical gun markers. Neither camera rig nor markers grant boarding access.
	_build_markers_and_camera()
	_muzzle_left.free()
	_muzzle_right.free()
	_muzzle_left = _reservation_marker("CenterMuzzle", Vector3(0, 1.5, -8.7), self)
	_muzzle_left.set_meta("reservation_only", false)
	_muzzle_right = _muzzle_left
	_boarding_marker.free()
	_boarding_marker = null
	_exit_marker.free()
	_exit_marker = null
	_camera_pivot.position = Vector3(0, 5.4, 3.5)
	_cockpit_camera.reparent(self, false)
	_cockpit_camera.position = PILOT_EYE
	var status := _install_variant_cockpit_system_readout(_cockpit_root)
	status.position = Vector3(0, 1.7, -6.65)
	status.font_size = 30
	status.pixel_size = 0.0012
	# No MovingInteriorFrame, boarding area, passenger seat or cargo writer.
	_canopy_open = false


func _shell_material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material


func _reservation_marker(node_name: String, pose: Vector3, parent: Node) -> Marker3D:
	var marker := Marker3D.new()
	marker.name = node_name
	marker.position = pose
	marker.set_meta("reservation_only", true)
	parent.add_child(marker)
	return marker


func _add_section_box(section_name: String, low: Vector3, high: Vector3, material: Material) -> void:
	var box := BoxMesh.new()
	box.size = high - low
	box.material = material
	var points := PackedVector3Array()
	for x in [-0.5, 0.5]:
		for y in [-0.5, 0.5]:
			for z in [-0.5, 0.5]:
				points.append(Vector3(x, y, z) * box.size)
	_install_section(section_name, (low + high) * 0.5, box, points)


func _install_section(section_name: String, origin: Vector3, mesh: Mesh, points: PackedVector3Array) -> void:
	var visual := MeshInstance3D.new()
	visual.name = section_name
	visual.position = origin
	visual.mesh = mesh
	_original_shell.add_child(visual)
	var collider := CollisionShape3D.new()
	collider.name = section_name + "Collision"
	collider.position = origin
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	collider.shape = shape
	add_child(collider)


func _add_nose_wedge(material: Material) -> void:
	# Broad, low bow tapers in both height and width towards the nose. Its
	# upper surface stays below the fixed pilot eye and its forward sightline.
	var points := PackedVector3Array([
		Vector3(-4.2, 0, -8.5), Vector3(4.2, 0, -8.5),
		Vector3(4.2, 0.6, -8.5), Vector3(-4.2, 0.6, -8.5),
		Vector3(-4.5, 0, -7), Vector3(4.5, 0, -7),
		Vector3(4.5, 1.6, -7), Vector3(-4.5, 1.6, -7),
	])
	var centre := Vector3(0, 0.55, -7.75)
	var faces := [[0, 1, 2, 3], [4, 7, 6, 5], [0, 4, 5, 1],
		[3, 2, 6, 7], [0, 3, 7, 4], [1, 5, 6, 2]]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	for face: Array in faces:
		var a := points[int(face[0])]
		var b := points[int(face[1])]
		var c := points[int(face[2])]
		var normal := (b - a).cross(c - a).normalized()
		if normal.dot((a + b + c) / 3.0 - centre) < 0:
			normal = -normal
		# Godot's front-facing winding is clockwise when viewed from outside;
		# keep explicit outward vertex normals independent of index winding.
		var order := face.duplicate()
		if (b - a).cross(c - a).dot(normal) > 0:
			order.reverse()
		for triangle: Array in [[order[0], order[1], order[2]], [order[0], order[2], order[3]]]:
			for index: int in triangle:
				surface.set_normal(normal)
				surface.add_vertex(points[index])
	_install_section("BroadWedgeNose", Vector3.ZERO, surface.commit(), points)


func _has_access_deck_support() -> bool:
	if not is_inside_tree(): return false
	for point in [Vector3.ZERO, Vector3(-1.15, 0, 12.5), Vector3(1.15, 0, 12.5), Vector3(-3.4, 0, 10.1)]:
		var origin := to_global(point)
		var query := PhysicsRayQueryParameters3D.create(origin + global_basis.y * 0.1,
			origin - global_basis.y * 0.2, PhysicsLayers.WORLD | PhysicsLayers.SHIP)
		query.exclude = [get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or (hit.normal as Vector3).dot(global_basis.y) <= 0.95: return false
	return true


func is_access_motion_active() -> bool:
	return _canopy_tween != null and _canopy_tween.is_valid()


func is_access_supported() -> bool:
	return not _destroyed and not _landing_active and _landed and velocity.length() < 0.01 \
		and _engine_state == ENGINE_OFFLINE and _has_access_deck_support()


func set_canopy_open(open: bool, duration: float = ACCESS_MOTION_SECONDS) -> void:
	if is_access_motion_active() or (open and not is_access_supported()): return
	# The common physical control requests .35s; the complete five-piece
	# mechanism needs its authored minimum, including when operated by Player.
	super.set_canopy_open(open, maxf(duration, ACCESS_MOTION_SECONDS))


func _access_blocks_propulsion() -> bool:
	return _canopy_open or _access_fraction > 0.0 or is_access_motion_active()


func request_engine_start() -> void:
	if not _access_blocks_propulsion(): super.request_engine_start()


func _sample_ship_command() -> ShipCommand:
	var command := super._sample_ship_command()
	return _neutralized_command_snapshot(command) if _access_blocks_propulsion() else command


func _set_canopy_open_fraction(open_fraction: float) -> void:
	super._set_canopy_open_fraction(open_fraction)
	_access_fraction = clampf(open_fraction, 0, 1)
	for leaf in _access_leaves:
		var points := _access_leaf_points(leaf, _access_fraction)
		(leaf.collision.shape as ConvexPolygonShape3D).points = points
		leaf.mesh.mesh = _access_mesh(points, leaf.material)


func _phase(fraction: float, start: float, finish: float) -> float:
	return clampf((fraction - start) / (finish - start), 0, 1)


func _access_leaf_points(leaf: Dictionary, fraction: float) -> PackedVector3Array:
	if leaf.has("ramp_index"):
		return _ramp_points(leaf.ramp_index, leaf.open, fraction)
	var points := PackedVector3Array()
	# Clear the jambs aft before sliding the two rigid halves sideways.
	var offset := Vector3(float(leaf.side) * 1.2 * _phase(fraction, 0.08, 0.16),
		0, 0.3 * _phase(fraction, 0, 0.08))
	for point in leaf.closed: points.append(point + offset)
	return points


func _ramp_points(index: int, opened: PackedVector3Array, fraction: float) -> PackedVector3Array:
	var original_front := Vector3(0, 0.8 - index * (0.8 / 3.0), 8 + index * 1.5)
	# Outside first: the still-stowed neighbouring leaves cannot obstruct a
	# travelling leaf. The same scalar trajectory seals in exact reverse.
	var start := 0.16 + (2 - index) * 0.28
	var angle := RAMP_STOW_ANGLE
	var front := Vector3(0, 0.8, 7.65 + index * 0.15)
	if fraction <= start + 0.04:
		front.y += 0.15 * _phase(fraction, start, start + 0.04)
	elif fraction <= start + 0.12:
		front.y = 0.95
		front.z = lerpf(front.z, original_front.z, _phase(fraction, start + 0.04, start + 0.12))
	elif fraction <= start + 0.16:
		front = Vector3(0, lerpf(0.95, original_front.y + 0.15,
			_phase(fraction, start + 0.12, start + 0.16)), original_front.z)
	elif fraction <= start + 0.24:
		angle *= 1 - _phase(fraction, start + 0.16, start + 0.24)
		front = original_front + Vector3.UP * 0.15
	else:
		angle = 0
		front = original_front + Vector3.UP * 0.15 * (1 - _phase(fraction, start + 0.24, start + 0.28))
	var rotation := Basis(Vector3.RIGHT, angle)
	var rotated := PackedVector3Array()
	var maximum_z := -INF
	for point in opened:
		var posed := rotation * (point - original_front)
		rotated.append(posed)
		maximum_z = maxf(maximum_z, posed.z)
	if fraction > start + 0.16 and fraction <= start + 0.24:
		# A leaf's radial reach exceeds its horizontal run during rotation.
		# Bound every real corner, keeping the next leaf's joint unobstructed.
		front.z = minf(original_front.z, original_front.z + 1.5 - maximum_z)
	var points := PackedVector3Array()
	for point in rotated: points.append(point + front)
	return points


func _access_box(left: float, right: float, front: float, rear: float, bottom: float, top: float) -> PackedVector3Array:
	return PackedVector3Array([Vector3(left, bottom, front), Vector3(right, bottom, front),
		Vector3(right, bottom, rear), Vector3(left, bottom, rear), Vector3(left, top, front),
		Vector3(right, top, front), Vector3(right, top, rear), Vector3(left, top, rear)])


func _moving_access_leaf(label: String, closed: PackedVector3Array, opened: PackedVector3Array, material: Material, extra: Dictionary) -> void:
	var collision := CollisionShape3D.new()
	collision.name = label + "Collision"
	var shape := ConvexPolygonShape3D.new()
	shape.points = closed
	collision.shape = shape
	add_child(collision)
	var mesh := MeshInstance3D.new()
	mesh.name = label
	mesh.mesh = _access_mesh(closed, material)
	_original_shell.add_child(mesh)
	var leaf := {"collision":collision, "mesh":mesh, "closed":closed, "open":opened, "material":material}
	leaf.merge(extra)
	_access_leaves.append(leaf)


func _access_mesh(points: PackedVector3Array, material: Material) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	var center := Vector3.ZERO
	for point in points: center += point / float(points.size())
	var triangles := [0,1,2,0,2,3,6,5,4,7,6,4,4,1,0,4,5,1,5,2,1,5,6,2,6,3,2,6,7,3,7,0,3,7,4,0]
	for i in range(0, triangles.size(), 3):
		var a := points[triangles[i]]
		var b := points[triangles[i + 1]]
		var c := points[triangles[i + 2]]
		var normal := (b - a).cross(c - a).normalized()
		if normal.is_zero_approx(): continue
		if normal.dot((a + b + c) / 3.0 - center) < 0: normal = -normal
		for point in ([a, c, b] if (b - a).cross(c - a).dot(normal) > 0 else [a, b, c]):
			surface.set_normal(normal)
			surface.add_vertex(point)
	return surface.commit()


func _build_stern_access(orange: Material) -> void:
	_canopy_pivot = Node3D.new()
	_canopy_pivot.name = "SternAccessMotionAuthority"
	_original_shell.add_child(_canopy_pivot)
	for side in [-1, 1]:
		var closed := _access_box(-1.2 if side < 0 else 0, 0 if side < 0 else 1.2, 8.3, 8.5, 0.8, 3.2)
		_moving_access_leaf("SternPortClosure" if side < 0 else "SternStarboardClosure",
			closed, closed, orange, {"side":side})
	for index in 3:
		var opened := _access_box(-1.2, 1.2, 8 + 1.5 * index, 9.5 + 1.5 * index, 0, 0)
		for i in opened.size(): opened[i].y = (12.5 - opened[i].z) / 4.5 * (0.8 if i >= 4 else 0.72)
		_moving_access_leaf("SternRamp" + str(index), _ramp_points(index, opened, 0),
			opened, orange, {"ramp_index":index})
	_add_section_box("SternPortControlBracket", Vector3(-3.55, 2.2, 8), Vector3(-3.25, 2.4, 8.3), orange)
	ShipCabinHatch.install(self, self, Vector3(-3.4, 2.4, 8.3))
