extends HeroShip

## Original modern cruiser, not an authenticated historical silhouette.
## Card 1 reserves a bridge and stern well; access, roles and weapons are unfitted.
## Editable convex sections use metres, +Y up and -Z forward.
const PILOT_ORIGIN := Vector3(0, 1.65, -3.8)


func _wake_engine_for_automatic_demand(_release_dock_latch: bool = true) -> void:
	# Both manual and demand-driven starts retain HeroShip's single timed clock.
	if _engine_state == ENGINE_OFFLINE:
		request_engine_start()


func _uses_torrent_reconstruction_presentation() -> bool:
	return false


func _uses_inherited_primary_weapon() -> bool:
	return false


func set_canopy_open(_open: bool, _duration: float = 0.0) -> void:
	# Physical stern access belongs to the subsequent bounded card.
	pass


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
	_visual_root.name = "ParadoxOriginalShell"
	add_child(_visual_root)
	var armor := _finish(Color("777f8c"), 0.68)
	var dark := _finish(Color("202a37"), 0.8)
	var brass := _finish(Color("ce9b54"), 0.55)
	var glass := _finish(Color(0.12, 0.32, 0.4, 0.28), 0.2)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Long low foredeck: a narrow bow opens into broad clipped shoulders.
	_prism("FacetedForedeck", [Vector2(-3.8,-14), Vector2(3.8,-14),
		Vector2(8,-9), Vector2(8,-5.4), Vector2(-8,-5.4), Vector2(-8,-9)], 0, 2.8, armor)
	_rect("BridgeFoundation", -8, 8, -5.4, 8, 0, 1.2, dark)
	_rect("AftFoundation", -6, 6, 8, 11, 0, 1.2, dark)
	# The interior volume x±2.8, z-5..11, y1.2..4 is completely reserved.
	_rect("ForwardSill", -3.3, 3.3, -5.4, -5, 1.2, 2, dark)
	_rect("ForwardGlazing", -3.3, 3.3, -5.4, -5, 2, 4, glass)
	for side in [-1.0, 1.0]:
		var label := "Port" if side < 0 else "Starboard"
		var inner := minf(side * 2.8, side * 3.3)
		var outer := maxf(side * 2.8, side * 3.3)
		_rect(label + "BridgeWall", inner, outer, -5, 11, 1.2, 4, armor)
		# Independent low shoulder shelves flank the raised bridge.
		_prism(label + "Shoulder", [Vector2(side*3.3,-5.4), Vector2(side*8,-5.4),
			Vector2(side*8,4), Vector2(side*6,8), Vector2(side*3.3,8)], 1.2, 2.8, armor)
		# Two short stern blocks, separated by the inset central boarding well.
		_rect(label + "SternFoot", minf(side*1.2,side*6), maxf(side*1.2,side*6), 11,14,0,1.2,dark)
		_prism(label + "CompactEngine", [Vector2(side*3.3,8), Vector2(side*6,8),
			Vector2(side*6,13.48), Vector2(side*5.5,13.98), Vector2(side*3.3,13.98)], 1.2,3.9,dark)
		_rect(label + "EngineCrown", minf(side*3.6,side*5.7),maxf(side*3.6,side*5.7),9,13,3.9,4.1,brass)
		var core := _rect(label + "Exhaust", minf(side*3.65,side*5.2),maxf(side*3.65,side*5.2),13.98,14,1.7,3.2,_finish(Color("66d7eb"),0.2))
		_engine_core_glows.append(core)
	# Raised aft bridge roof: broad brow and a narrower crown establish 6m height.
	_rect("BridgeRoof", -3.3,3.3,-5.4,11,4,5.6,armor)
	_rect("BridgeCrown", -2.8,2.8,-3,10,5.6,6,brass)
	_rect("SternClosure", -2.8,2.8,11,11.3,1.2,4,dark)
	_rect("WellHeader", -3.3,3.3,11,11.3,4,5.6,armor)
	_cockpit_root = Node3D.new()
	_cockpit_root.name = "PilotFixture"
	_visual_root.add_child(_cockpit_root)
	_pilot_seat_anchor = Marker3D.new()
	_pilot_seat_anchor.name = "PilotSeatAnchor"
	_pilot_seat_anchor.position = PILOT_ORIGIN
	_cockpit_root.add_child(_pilot_seat_anchor)
	_build_markers_and_camera()
	_boarding_marker.position = Vector3(0,1.2,10)
	_exit_marker.position = Vector3(0,0,17)
	_camera_pivot.position = Vector3(0,4,2)
	_muzzle_left.position = Vector3(-0.8,2.7,-14)
	_muzzle_right.position = Vector3(0.8,2.7,-14)
	_canopy_pivot = Node3D.new()
	_canopy_pivot.name = "ReservedSternAccess"
	_visual_root.add_child(_canopy_pivot)
	_sync_engine_visuals_immediately()


func _finish(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = 0.32
	return material


func _rect(label: String, left: float, right: float, front: float, rear: float, bottom: float, top: float, material: Material) -> MeshInstance3D:
	return _prism(label, [Vector2(left,front),Vector2(right,front),Vector2(right,rear),Vector2(left,rear)],bottom,top,material)


## One set of authored convex vertices drives visible faces and physical hull.
func _prism(label: String, footprint: Array, bottom: float, top: float, material: Material) -> MeshInstance3D:
	var polygon := PackedVector2Array(footprint)
	if Geometry2D.is_polygon_clockwise(polygon):
		polygon.reverse()
	var points := PackedVector3Array()
	for height in [bottom, top]:
		for point in polygon:
			points.append(Vector3(point.x,height,point.y))
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
