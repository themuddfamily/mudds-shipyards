extends HeroShip

## Original modern Katana foundation: closed hull and one pilot only.
## Access, Main registration, weapons and travelling interiors are not fitted.
## Editable convex sections use metres, +Y up and -Z forward.
const PILOT_ORIGIN := Vector3(0, 0.55, -1)
const RESERVED_RECESS := AABB(Vector3(-1.5, 0.6, -2), Vector3(3, 2.9, 4.5))


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
	_rect("CockpitFloor", -1.6,1.6,-6,6,0,0.6,structure)
	_rect("BluntNose", -1.6,1.6,-6,-2.1,0.6,1.8,armor)
	_rect("ForwardSill", -1.6,1.6,-2.1,-2,0.6,1.8,copper)
	_rect("ForwardGlazing", -1.6,1.6,-2.1,-2,1.8,3.5,glass)
	_rect("AftTub", -1.6,1.6,2.5,6,0.6,2.0,armor)
	_rect("AftCockpitWall", -1.6,1.6,2.5,2.7,2.0,3.5,structure)
	# Walls reserve the complete x±1.5 recess above its 0.6m supported floor.
	_rect("PortSill", -1.6,-1.5,-2,2.5,0.6,1.0,armor)
	_rect("PortClosedGlazing", -1.6,-1.5,-2,2.5,1.0,3.5,glass)
	_rect("StarboardSill", 1.5,1.6,-2,2.5,0.6,1.0,armor)
	_rect("StarboardGlazing", 1.5,1.6,-2,2.5,1.0,3.5,glass)
	_rect("CanopyRoof", -1.6,1.6,-2.1,2.7,3.5,3.8,armor)
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
	_boarding_marker.position = Vector3(-0.9,0.6,0)
	_exit_marker.position = Vector3(-6.5,0,0)
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
