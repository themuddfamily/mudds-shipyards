extends HeroShip

## Original modern Katana: physical port access and one pilot.
## Main registration, weapons and travelling interiors are not fitted.
## Editable convex sections use metres, +Y up and -Z forward.
const PILOT_ORIGIN := Vector3(0, 0.55, -1)
const RESERVED_RECESS := AABB(Vector3(-1.5, 0.6, -2), Vector3(3, 2.9, 4.5))
var _access_leaves: Array[Dictionary] = []
var _access_fraction := 0.0


func _has_deck_support() -> bool:
	if not is_inside_tree():
		return false
	for point in [Vector3.ZERO,Vector3(-6,0,-1.05),Vector3(-6,0,1.05),Vector3(-6.6,0,1.6)]:
		var origin := to_global(point)
		var query := PhysicsRayQueryParameters3D.create(origin + global_basis.y * 0.1, origin - global_basis.y * 0.2, PhysicsLayers.WORLD | PhysicsLayers.SHIP)
		query.exclude = [get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or (hit.normal as Vector3).dot(global_basis.y) <= 0.95:
			return false
	return true


func is_access_motion_active() -> bool:
	return _canopy_tween != null and _canopy_tween.is_valid()


func is_access_supported() -> bool:
	return not _destroyed and not _landing_active and _landed and velocity.length() < 0.01 and _engine_state == ENGINE_OFFLINE and _has_deck_support()


func is_boardable() -> bool:
	return super.is_boardable() and is_access_supported() and _access_fraction > 0.999 and not is_access_motion_active()


func set_canopy_open(open: bool, duration: float = 0.65) -> void:
	if is_access_motion_active() or (open and not is_access_supported()):
		return
	super.set_canopy_open(open, duration)


func request_engine_start() -> void:
	if _canopy_open or is_access_motion_active() or _access_fraction > 0.001:
		return
	super.request_engine_start()


func _set_canopy_open_fraction(open_fraction: float) -> void:
	super._set_canopy_open_fraction(open_fraction)
	_access_fraction = clampf(open_fraction, 0.0, 1.0)
	for leaf in _access_leaves:
		var points := _access_leaf_points(leaf, _access_fraction)
		(leaf.collision.shape as ConvexPolygonShape3D).points = points
		leaf.mesh.mesh = _leaf_mesh(points, leaf.material)


func _access_leaf_points(leaf: Dictionary, fraction: float) -> PackedVector3Array:
	var points := PackedVector3Array()
	if leaf.mesh.name == &"PortRamp0":
		# Slide above the fixed inner leaf, then lower only after their
		# footprints meet at a single edge. Closing lifts before retracting.
		var offset := Vector3.ZERO
		if fraction <= 0.8:
			var phase := fraction / 0.8
			offset = Vector3(2.25 * (1.0-phase),0.5-0.3*phase,0)
		else:
			offset.y = 0.2 * (1.0-(fraction-0.8)/0.2)
		for point in leaf.open:
			points.append(point + offset)
	else:
		for i in leaf.closed.size():
			points.append((leaf.closed[i] as Vector3).lerp(leaf.open[i], fraction))
	return points


## Rigid translation segments use bounded endpoints (including the outer
## carriage staging pose). Each entire segment lies in their convex envelope;
## no hinge arc can overshoot the closed/deployed limits.
func _moving_leaf(label: String, closed: PackedVector3Array, opened: PackedVector3Array, material: Material) -> void:
	var collision := CollisionShape3D.new()
	collision.name = label + "Collision"
	var shape := ConvexPolygonShape3D.new()
	shape.points = closed
	collision.shape = shape
	add_child(collision)
	var mesh := MeshInstance3D.new()
	mesh.name = label
	mesh.mesh = _leaf_mesh(closed, material)
	mesh.material_override = material
	_visual_root.add_child(mesh)
	_access_leaves.append({"collision":collision,"mesh":mesh,"closed":closed,"open":opened,"material":material})


func _leaf_mesh(points: PackedVector3Array, material: Material) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	# Bottom then top, each with the same counterclockwise x/z footprint.
	var triangles := [0,1,2,0,2,3,6,5,4,7,6,4,4,1,0,4,5,1,5,2,1,5,6,2,6,3,2,6,7,3,7,0,3,7,4,0]
	for triangle in range(0,triangles.size(),3):
		var a := points[triangles[triangle]]
		var b := points[triangles[triangle+1]]
		var c := points[triangles[triangle+2]]
		if (b-a).cross(c-a).length_squared() < 0.00000001:
			continue
		for index in [triangles[triangle+2],triangles[triangle+1],triangles[triangle]]:
			surface.add_vertex(points[index])
	surface.generate_normals()
	return surface.commit()


func _box_points(left: float, right: float, front: float, rear: float, bottom: float, top: float) -> PackedVector3Array:
	return PackedVector3Array([Vector3(left,bottom,front),Vector3(right,bottom,front),Vector3(right,bottom,rear),Vector3(left,bottom,rear),Vector3(left,top,front),Vector3(right,top,front),Vector3(right,top,rear),Vector3(left,top,rear)])


func _sliding_box(label: String, left: float, right: float, front: float, rear: float, bottom: float, top: float, rise: float, material: Material) -> void:
	var closed := _box_points(left,right,front,rear,bottom,top)
	var opened := closed.duplicate()
	for i in opened.size():
		opened[i] += Vector3.UP * rise
	_moving_leaf(label,closed,opened,material)


func _build_access(material: Material) -> void:
	_canopy_pivot = Node3D.new()
	_canopy_pivot.name = "CanopyMotionAuthority"
	_visual_root.add_child(_canopy_pivot)
	for index in 2:
		var left := -6.0 + index * 2.25
		var right := left + 2.25
		var opened := _box_points(left,right,-1.1,1.1,0,0)
		for i in opened.size():
			var progress := (opened[i].x + 6.0) / 4.5
			opened[i].y = progress * (0.6 if i >= 4 else 0.52)
		var closed := opened.duplicate()
		if index == 0:
			for i in closed.size():
				closed[i] += Vector3(2.25,0.5,0)
		_moving_leaf("PortRamp" + str(index),closed,opened,material)
	var boarding := ShipBoardingArea.new()
	boarding.name = "ShipBoardingArea"
	boarding.position = Vector3(-0.9,0.6,0)
	add_child(boarding)
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.22
	shape.shape = sphere
	boarding.add_child(shape)
	ShipCabinHatch.install(self,self,Vector3(-5.4,1.6,2.3))
	# A visible fixed bracket reaches the safe aft approach while remaining
	# inside the closed envelope and outside the ramp's z±1.1 swept strip.
	_rect("PortControlBracket",-5.5,-1.6,2.2,2.4,1.45,1.65,material)



func _uses_torrent_reconstruction_presentation() -> bool:
	return false


func _uses_inherited_primary_weapon() -> bool:
	return false


func _wake_engine_for_automatic_demand(_release_dock_latch: bool = true) -> void:
	# Retain the inherited single 2.3-second clock for both start paths.
	if _engine_state == ENGINE_OFFLINE:
		request_engine_start()


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
	_visual_root.name = "KatanaOriginalShell"
	add_child(_visual_root)
	var armor := _finish(Color("b5c2c5"), 0.6)
	var structure := _finish(Color("263640"), 0.8)
	var copper := _finish(Color("d99461"), 0.48)
	var glass := _finish(Color(0.12, 0.52, 0.62, 0.22), 0.18)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Broad straight-sided cockpit tub, blunt squared nose and low aft deck.
	_rect("CockpitFloor", -1.5,1.6,-6,6,0,0.6,structure)
	_rect("BluntNose", -1.6,1.6,-6,-2.1,0.6,1.8,armor)
	_rect("ForwardSill", -1.6,1.6,-2.1,-2,0.6,1.8,copper)
	_rect("ForwardGlazing", -1.6,1.6,-2.1,-2,1.8,3.5,glass)
	_rect("AftTub", -1.6,1.6,2.5,6,0.6,2.0,armor)
	_rect("AftCockpitWall", -1.6,1.6,2.5,2.7,2.0,3.5,structure)
	# Walls reserve the complete x±1.5 recess above its 0.6m supported floor.
	_sliding_box("PortSill", -1.6,-1.5,-2,2.5,0.6,1.0,-0.4,armor)
	_sliding_box("PortClosedGlazing", -1.6,-1.5,-2,2.5,1.0,3.5,2.0,glass)
	_rect("StarboardSill", 1.5,1.6,-2,2.5,0.6,1.0,armor)
	_rect("StarboardGlazing", 1.5,1.6,-2,2.5,1.0,3.5,glass)
	_sliding_box("CanopyRoof", -1.6,1.6,-2.1,2.7,3.5,3.8,2.0,armor)
	for side in [-1.0,1.0]:
		var label := "Port" if side < 0 else "Starboard"
		# Compact aft shoulders begin behind z=+2.7: the future port ramp's
		# z±1.1 approach is untouched, with no borrowed sibling rail silhouette.
		_prism(label + "AftOutrigger", [Vector2(side*1.6,2.7),Vector2(side*4.4,2.7),
			Vector2(side*5.5,3.6),Vector2(side*5.5,5.4),Vector2(side*4.9,6),Vector2(side*1.6,6)],0,1.4,armor)
		_rect(label + "EngineHousing", minf(side*2.4,side*4.4),maxf(side*2.4,side*4.4),3.2,5.8,1.4,2.1,structure)
		var glow := _rect(label + "Exhaust", minf(side*2.5,side*4.3),maxf(side*2.5,side*4.3),5.8,6,1.4,2.1,_finish(Color("5ce1ed"),0.2))
		_engine_core_glows.append(glow)
	_cockpit_root = Node3D.new()
	_cockpit_root.name = "PilotFixture"
	_visual_root.add_child(_cockpit_root)
	_pilot_seat_anchor = Marker3D.new()
	_pilot_seat_anchor.name = "PilotSeatAnchor"
	_pilot_seat_anchor.position = PILOT_ORIGIN
	_pilot_seat_anchor.set_meta("station_id", &"pilot_station")
	_cockpit_root.add_child(_pilot_seat_anchor)
	# Seat presentation occupies only the seated pilot; it grants no interaction
	# or passenger authority and does not fill the reserved walking recess.
	_seat_part("PilotCushion", Vector3(0,1.22,-1),Vector3(0.56,0.1,0.65),copper)
	_seat_part("PilotBack", Vector3(0,1.6,-0.6),Vector3(0.56,0.75,0.12),structure)
	_build_markers_and_camera()
	_build_access(copper)
	_boarding_entry_marker = Marker3D.new()
	_boarding_entry_marker.name = "BoardingEntry"
	_boarding_entry_marker.position = Vector3(-0.9,0.6,0)
	_cockpit_root.add_child(_boarding_entry_marker)
	_boarding_marker.position = Vector3(-0.9,0.6,0)
	_exit_marker.position = Vector3(-0.9,0.6,0)
	_camera_pivot.position = Vector3(0,2.3,0)
	_muzzle_left.position = Vector3(0,1,-6.2)
	_muzzle_right.position = _muzzle_left.position
	var receiver := Marker3D.new()
	receiver.name = "DockingReceiver"
	add_child(receiver)
	_sync_engine_visuals_immediately()


func _seat_part(label: String, origin: Vector3, size: Vector3, material: Material) -> void:
	var part := MeshInstance3D.new()
	part.name = label
	var box := BoxMesh.new()
	box.size = size
	part.mesh = box
	part.material_override = material
	part.position = origin
	_cockpit_root.add_child(part)
	var collision := CollisionShape3D.new()
	collision.name = label + "Collision"
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position = origin
	add_child(collision)


func _finish(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = 0.3
	return material


func _rect(label: String, left: float, right: float, front: float, rear: float, bottom: float, top: float, material: Material) -> MeshInstance3D:
	return _prism(label,[Vector2(left,front),Vector2(right,front),Vector2(right,rear),Vector2(left,rear)],bottom,top,material)


## A single authored convex footprint drives both editable mesh and collision.
func _prism(label: String, footprint: Array, bottom: float, top: float, material: Material) -> MeshInstance3D:
	var polygon := PackedVector2Array(footprint)
	if Geometry2D.is_polygon_clockwise(polygon):
		polygon.reverse()
	var points := PackedVector3Array()
	for height in [bottom,top]:
		for point in polygon:
			points.append(Vector3(point.x,height,point.y))
	var collision := CollisionShape3D.new()
	collision.name = label + "Collision"
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	collision.shape = shape
	add_child(collision)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	var indices := Geometry2D.triangulate_polygon(polygon)
	var count := polygon.size()
	for i in range(0,indices.size(),3):
		for index in [indices[i+2],indices[i+1],indices[i]]:
			surface.add_vertex(points[index])
		for index in [indices[i],indices[i+1],indices[i+2]]:
			surface.add_vertex(points[index+count])
	for i in count:
		var next := (i+1)%count
		for index in [i,next,i+count,next,next+count,i+count]:
			surface.add_vertex(points[index])
	surface.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.name = label
	mesh.mesh = surface.commit()
	_visual_root.add_child(mesh)
	return mesh
