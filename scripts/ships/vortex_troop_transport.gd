extends HeroShip

## Original editable modern interpretation; A3 establishes name/role only.
## Standalone physical access and pilot fixture; chairs/Main/combat come later.
## Metres, +Y up, -Z forward. Cabin is reserved, never a solid hull box.
const PILOT_ORIGIN := Vector3(0, 1.45, -6.5)
const CABIN_VOID := AABB(Vector3(-2.2, 1, -7.5), Vector3(4.4, 2.6, 15))
const ACCESS_MOTION_SECONDS := 0.35
var _access_fraction := 0.0
var _ramp_hinge: Node3D
var _ramp_toe_hinge: Node3D
var _ramp_first_collision: CollisionShape3D
var _ramp_toe_collision: CollisionShape3D
var _interior_frame: MovingInteriorFrame


func _sample_ship_command() -> ShipCommand:
	var command := super._sample_ship_command()
	if _access_blocks_propulsion():
		return _neutralized_command_snapshot(command)
	return command


func _access_blocks_propulsion() -> bool:
	return _canopy_open or _access_fraction > 0.0 \
		or (_canopy_tween != null and _canopy_tween.is_valid())


func request_engine_start() -> void:
	if not _access_blocks_propulsion():
		super.request_engine_start()


func has_supported_exterior_access() -> bool:
	if not is_inside_tree() or _destroyed or not _landed or _landing_active \
			or _engine_state != ENGINE_OFFLINE or velocity.length() > 0.01:
		return false
	var up := global_basis.y.normalized()
	for point: Vector3 in [Vector3(-1.15, 0, 12), Vector3(1.15, 0, 12), Vector3(0, 0, 14)]:
		var world := global_transform * point
		var ray := PhysicsRayQueryParameters3D.create(world + up * 0.12, world - up * 0.12,
			PhysicsLayers.WORLD | PhysicsLayers.SHIP, [get_rid()])
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		if hit.is_empty() or (hit.normal as Vector3).dot(up) < 0.99 \
				or absf(((hit.position as Vector3) - world).dot(up)) > 0.03:
			return false
	return true


func get_interior_frame() -> MovingInteriorFrame:
	return _interior_frame


func get_in_flight_cabin_report() -> Dictionary:
	return {"supported": not _destroyed and is_instance_valid(_interior_frame),
		"frame": _interior_frame, "local_bounds": CABIN_VOID,
		"stand_transform": get_boarding_entry_transform()}


## The existing tween is the sole access clock. Every physical piece receives
## the exact rigid transform of its visible leaf, including intermediate poses.
func _set_canopy_open_fraction(open_fraction: float) -> void:
	super._set_canopy_open_fraction(open_fraction)
	_access_fraction = clampf(open_fraction, 0, 1)
	for side in [-1.0, 1.0]:
		var label := "Port" if side < 0 else "Starboard"
		var offset := Vector3(side * 1.2 * _access_fraction, 0, 0)
		get_node(label + "SternDoorCollision").position = offset
		_visual_root.get_node(label + "SternDoor").position = offset
	var folded := 1.0 - _access_fraction
	var main_fold := smoothstep(0.5, 1, folded)
	_ramp_hinge.position = Vector3(0, 1, 8 + 0.2 * main_fold)
	_ramp_hinge.rotation.x = -PI * 0.5 * smoothstep(0.5, 1, folded)
	# Lift the toe clear of the first leaf before folding. Its sloped distal
	# edge otherwise initially swings beyond z12; compensate that exact rigid
	# projection at the toe hinge, without retracting the first leaf into deck.
	var toe_angle := PI * smoothstep(0.1, 0.5, folded)
	var toe_retreat := maxf(0, 0.5 * sin(toe_angle) + 2 * cos(toe_angle) - 2)
	_ramp_toe_hinge.position = Vector3(0,
		-0.5 + 0.16 * smoothstep(0, 0.1, folded) - 0.06 * main_fold, 2 - toe_retreat)
	_ramp_toe_hinge.rotation.x = -toe_angle
	_ramp_first_collision.transform = _ramp_hinge.transform
	_ramp_toe_collision.transform = _ramp_hinge.transform * _ramp_toe_hinge.transform

const OUTER := [Vector2(-2.7, -10), Vector2(2.7, -10),
	Vector2(3.5, -8.8), Vector2(3.5, 8), Vector2(2.7, 10),
	Vector2(-2.7, 10), Vector2(-3.5, 8), Vector2(-3.5, -8.8)]
const INNER := [Vector2(-2.2, -7.5), Vector2(2.2, -7.5),
	Vector2(2.8, -7), Vector2(2.8, 8), Vector2(2.2, 8),
	Vector2(-2.2, 8), Vector2(-2.8, 8), Vector2(-2.8, -7)]


## Preserve the approved timed spool even for ordinary automatic demand.
## HeroShip remains the sole engine clock and movement owner.
func _wake_engine_for_automatic_demand(_release_dock_latch: bool = true) -> void:
	if _engine_state == ENGINE_OFFLINE:
		request_engine_start()


func _uses_torrent_reconstruction_presentation() -> bool:
	return false


func _uses_inherited_primary_weapon() -> bool:
	# The approved combat installation belongs to card 7, not this fixture.
	return false


func set_canopy_open(open: bool, duration: float = ACCESS_MOTION_SECONDS) -> void:
	if open and not has_supported_exterior_access():
		return
	super.set_canopy_open(open, duration)


func _build_ship() -> void:
	if _built:
		return
	_built = true
	collision_layer = PhysicsLayers.SHIP_BODY_LAYER
	collision_mask = PhysicsLayers.SHIP_BODY_MASK
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	set_meta("authenticated_historical_silhouette", false)
	set_meta("geometry_status", &"original_modern_candidate")
	_visual_root = Node3D.new()
	_visual_root.name = "VortexOriginalShell"
	add_child(_visual_root)
	var skin := _vortex_finish(Color("626c88"), 0.62)
	var frame := _vortex_finish(Color("1c2638"), 0.8)
	var accent := _vortex_finish(Color("e0af70"), 0.5)
	var glazing := _vortex_finish(Color(0.12, 0.28, 0.35, 0.28), 0.18)
	glazing.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glazing.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Broad chamfered cabin pod. Stern deck stops at the recessed closure;
	# separate cheeks preserve the full 20m silhouette and future ramp space.
	_prism("CabinDeck", [OUTER[0], OUTER[1], OUTER[2], Vector2(3.5, 8),
		Vector2(-3.5, 8), OUTER[7]], 0, 1, frame)
	_prism("CabinRoof", OUTER, 4.5, 5, skin)
	for edge in [1, 2, 6, 7]:
		var next: int = (int(edge) + 1) % OUTER.size()
		_prism("PodWall%d" % edge, [OUTER[edge], OUTER[next], INNER[next], INNER[edge]], 1, 4.5, skin)
	var nose := [OUTER[0], OUTER[1], INNER[1], INNER[0]]
	_prism("NoseSill", nose, 1, 2, frame)
	_prism("FlightDeckGlazing", nose, 2, 3.8, glazing)
	_prism("NoseBrow", nose, 3.8, 4.5, skin)
	_prism("SternHeader", [Vector2(-2.2, 8), Vector2(2.2, 8),
		Vector2(2.7, 10), Vector2(-2.7, 10)], 3.6, 4.5, frame)
	for side in [-1.0, 1.0]:
		var label := "Port" if side < 0 else "Starboard"
		_prism(label + "SternCheek", [Vector2(side * 1.2, 8), Vector2(side * 3.5, 8),
			Vector2(side * 2.7, 10), Vector2(side * 1.2, 10)], 0, 3.6, skin)
		# Separate long side nacelles have tapered noses and inset aft exhausts.
		_prism(label + "EngineHousing", [Vector2(side * 3.5, -5), Vector2(side * 4.3, -5),
			Vector2(side * 5, -3.5), Vector2(side * 5, 7.5),
			Vector2(side * 4.7, 8.5), Vector2(side * 3.5, 8.5)], 1.2, 3.5, frame)
		_vortex_box(label + "EngineStripe", Vector3(side * 4.25, 3.52, 1.5), Vector3(0.7, 0.04, 9), accent)
		var core := _vortex_box(label + "EngineCore", Vector3(side * 4.2, 2.35, 8.45), Vector3(0.85, 1.15, 0.03), _vortex_finish(Color("68cde0"), 0.2))
		_engine_core_glows.append(core)
	# Two sideways leaves clear the full 2.4m aperture within the hull envelope.
	for side in [-1.0, 1.0]:
		var label := "Port" if side < 0 else "Starboard"
		_prism(label + "SternDoor", [Vector2(0, 7.8), Vector2(side * 1.2, 7.8),
			Vector2(side * 1.2, 8), Vector2(0, 8)], 1, 3.6, accent)
	# Visible non-colliding helm fitout; pilot attachment uses the actual anchor.
	_vortex_box("PilotChair", Vector3(0, 1.38, -6.5), Vector3(0.85, 0.25, 0.85), frame)
	_vortex_box("PilotBack", Vector3(0, 1.95, -6.1), Vector3(0.85, 1.0, 0.18), skin)
	_vortex_box("HelmConsole", Vector3(0, 1.65, -7.2), Vector3(1.2, 0.45, 0.45), frame)
	_cockpit_root = Node3D.new()
	_cockpit_root.name = "PilotFixture"
	_visual_root.add_child(_cockpit_root)
	_pilot_seat_anchor = Marker3D.new()
	_pilot_seat_anchor.name = "pilot_station"
	_pilot_seat_anchor.position = PILOT_ORIGIN
	_cockpit_root.add_child(_pilot_seat_anchor)
	_build_markers_and_camera()
	_boarding_marker.position = Vector3(0, 1, -5)
	_boarding_entry_marker = Marker3D.new()
	_boarding_entry_marker.name = "PilotApproach"
	_cockpit_root.add_child(_boarding_entry_marker)
	_boarding_entry_marker.position = Vector3(0, 1, -5)
	_exit_marker.position = Vector3(0, 0, 13)
	_camera_pivot.position = Vector3(0, 3, 1)
	_muzzle_left.position = Vector3(0, 2.6, -10)
	_muzzle_right.position = _muzzle_left.position
	_canopy_pivot = Node3D.new()
	_build_access_ramp(frame)
	_canopy_pivot.name = "AccessMotionClock"
	_visual_root.add_child(_canopy_pivot)
	_set_canopy_open_fraction(0)
	_interior_frame = MovingInteriorFrame.new()
	_interior_frame.name = "MovingInteriorFrame"
	var volume := Area3D.new()
	volume.name = "CabinOccupancy"
	volume.collision_layer = 0
	volume.collision_mask = PhysicsLayers.PLAYER
	volume.position = CABIN_VOID.get_center()
	var volume_collision := CollisionShape3D.new()
	var volume_shape := BoxShape3D.new()
	volume_shape.size = CABIN_VOID.size
	volume_collision.shape = volume_shape
	volume.add_child(volume_collision)
	add_child(volume)
	add_child(_interior_frame)
	_interior_frame.configure(self, CABIN_VOID, volume)
	_interior_frame.occupant_registered.connect(_on_cabin_occupancy_changed)
	_interior_frame.occupant_unregistered.connect(_on_cabin_occupancy_changed)
	_vortex_box("SternAccessControl", Vector3(1.1, 1.4, 9.98), Vector3(0.18, 0.25, 0.006), accent)
	ShipCabinHatch.install(_visual_root, self, Vector3(1.1, 1.4, 9.98))
	_sync_engine_visuals_immediately()


func _build_access_ramp(material: Material) -> void:
	_ramp_hinge = Node3D.new()
	_ramp_hinge.name = "SternRampHinge"
	_visual_root.add_child(_ramp_hinge)
	_ramp_toe_hinge = Node3D.new()
	_ramp_toe_hinge.name = "RampToeHinge"
	_ramp_hinge.add_child(_ramp_toe_hinge)
	_ramp_first_collision = _ramp_leaf("SternRampFirst", _ramp_hinge, 0.08, material)
	_ramp_toe_collision = _ramp_leaf("SternRampToe", _ramp_toe_hinge, 0, material)


func _ramp_leaf(label: String, parent: Node3D, toe_depth: float, material: Material) -> CollisionShape3D:
	var points := PackedVector3Array([
		Vector3(-1.2, 0, 0), Vector3(1.2, 0, 0),
		Vector3(1.2, -0.5, 2), Vector3(-1.2, -0.5, 2),
		Vector3(-1.2, -0.08, 0), Vector3(1.2, -0.08, 0),
		Vector3(1.2, -0.5 - toe_depth, 2), Vector3(-1.2, -0.5 - toe_depth, 2)])
	var collision := CollisionShape3D.new()
	collision.name = label + "Collision"
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	collision.shape = shape
	add_child(collision)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	for face in [[0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4], [3, 7, 6, 2], [0, 4, 7, 3], [1, 2, 6, 5]]:
		for triangle in [[face[0], face[1], face[2]], [face[0], face[2], face[3]]]:
			if (points[triangle[1]] - points[triangle[0]]).cross(points[triangle[2]] - points[triangle[0]]).length_squared() < 0.000001:
				continue
			for index in [triangle[2], triangle[1], triangle[0]]:
				surface.add_vertex(points[index])
	surface.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.name = label
	mesh.mesh = surface.commit()
	parent.add_child(mesh)
	return collision


func _on_cabin_occupancy_changed(_occupant: Node3D, _exit_velocity: Vector3 = Vector3.ZERO, _reason: StringName = &"") -> void:
	if not _destroyed:
		collision_mask = PhysicsLayers.SHIP_BODY_MASK & ~PhysicsLayers.PLAYER \
			if _interior_frame.get_occupant_count() > 0 else PhysicsLayers.SHIP_BODY_MASK


func _vortex_finish(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = 0.25
	return material


func _vortex_box(label: String, origin: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = origin
	_visual_root.add_child(mesh)
	return mesh


## Each convex section supplies the same editable vertices to mesh and shape.
## No collision section bridges across the reserved central cabin.
func _prism(label: String, footprint: Array, bottom: float, top: float, material: Material) -> void:
	var polygon := PackedVector2Array(footprint)
	if Geometry2D.is_polygon_clockwise(polygon):
		polygon.reverse()
	var points := PackedVector3Array()
	for height in [bottom, top]:
		for point in polygon:
			points.append(Vector3(point.x, height, point.y))
	var collider := CollisionShape3D.new()
	collider.name = label + "Collision"
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	collider.shape = shape
	add_child(collider)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	var indices := Geometry2D.triangulate_polygon(polygon)
	var count := polygon.size()
	for i in range(0, indices.size(), 3):
		for index in [indices[i + 2], indices[i + 1], indices[i]]:
			surface.add_vertex(points[index])
		for index in [indices[i], indices[i + 1], indices[i + 2]]:
			surface.add_vertex(points[index + count])
	for i in count:
		var next := (i + 1) % count
		for index in [i, next, i + count, next, next + count, i + count]:
			surface.add_vertex(points[index])
	surface.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.name = label
	mesh.mesh = surface.commit()
	_visual_root.add_child(mesh)
