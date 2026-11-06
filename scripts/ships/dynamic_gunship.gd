extends HeroShip

## Original modern Dynamic card-one foundation, not a historical reconstruction.
## Closed, single-pilot hull only: physical access and combat integration follow
## in later cards. Metres, +Y up, -Z forward; every shell section owns its mesh.
const PILOT_ORIGIN := Vector3(0, 0.50, -0.8)
const FUTURE_ENTRY := Vector3(-0.9, 0.55, 0.4)
const CENTER_MUZZLE := Vector3(0, 0.9, -4.9)


func _uses_torrent_reconstruction_presentation() -> bool:
	return false


func _uses_weapon_component_fallback_emitters() -> bool:
	return false


func _wake_engine_for_automatic_demand(_release_dock_latch: bool = true) -> void:
	# Automatic demand uses the same real 2.1-second clock as explicit start.
	# Repeated held commands must neither skip nor restart that clock.
	if _engine_state == ENGINE_OFFLINE:
		request_engine_start()


func _get_weapon_targeting_distance() -> float:
	return 360.0 * lerpf(FAILED_SENSOR_MANUAL_AIM_DISTANCE_FACTOR, 1.0,
		_get_damage_targeting_multiplier())


func _build_ship() -> void:
	if _built:
		return
	_built = true
	collision_layer = PhysicsLayers.SHIP_BODY_LAYER
	collision_mask = PhysicsLayers.SHIP_BODY_MASK
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	floor_stop_on_slope = false
	set_meta("geometry_status", &"original_modern_candidate")
	set_meta("authenticated_historical_silhouette", false)
	_visual_root = Node3D.new()
	_visual_root.name = "DynamicOriginalShell"
	add_child(_visual_root)
	var armor := _finish(Color("98adb3"), 0.55)
	var structure := _finish(Color("233743"), 0.8)
	var accent := _finish(Color("dc8961"), 0.5)
	var glass := _finish(Color(0.14, 0.65, 0.73, 0.18), 0.18)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Chamfered central tub supports the entire future recess at y=0.55.
	_prism("CentralFloor", [Vector2(-1.1,-5),Vector2(1.1,-5),
		Vector2(1.6,-4.4),Vector2(1.6,4.5),Vector2(1.1,5),
		Vector2(-1.1,5),Vector2(-1.6,4.5),Vector2(-1.6,-4.4)],0,0.55,structure)
	# The low centre nose leaves a real open bore at y=.9 beyond z=-4.8.
	_prism("LowNose", [Vector2(-1.1,-5),Vector2(1.1,-5),
		Vector2(1.6,-4.4),Vector2(1.6,-2.12),
		Vector2(-1.6,-2.12),Vector2(-1.6,-4.4)],0.55,0.72,armor)
	for side in [-1.0,1.0]:
		var label := "Port" if side < 0 else "Starboard"
		_prism(label + "NoseCheek", [Vector2(side*0.18,-4.8),
			Vector2(side*1.25,-4.8),Vector2(side*1.6,-4.4),
			Vector2(side*1.6,-2.12),Vector2(side*0.18,-2.12)],0.72,1.7,armor)
		# Low separated shoulders begin aft of the future z=-1..1 ramp.
		_prism(label + "Shoulder", [Vector2(side*1.6,1.2),
			Vector2(side*3.6,1.2),Vector2(side*4.5,2.2),
			Vector2(side*4.5,4.3),Vector2(side*3.8,4.8),
			Vector2(side*1.6,4.5)],0,1.5,armor)
		_rect(label + "EngineBlock", minf(side*2.2,side*4.1),
			maxf(side*2.2,side*4.1),2.3,4.85,1.5,2.8,structure)
		var exhaust := _finish(Color("58cbd7"),0.25)
		exhaust.emission_enabled = true
		exhaust.emission = Color("286b75")
		_rect(label + "ExhaustFace", minf(side*2.2,side*4.1),
			maxf(side*2.2,side*4.1),4.85,5,1.5,2.8,exhaust)
	# Recess x=-1.5..1.5,z=-2..2 is hollow above the supported floor.
	_rect("ForwardSill",-1.6,1.6,-2.12,-2,0.55,1.7,accent)
	_rect("ForwardGlazing",-1.6,1.6,-2.12,-2,1.7,3.4,glass)
	_rect("AftTub",-1.6,1.6,2,4.5,0.55,2.0,armor)
	_rect("AftPressureWall",-1.6,1.6,2,2.12,2.0,3.4,structure)
	_rect("PortSill",-1.6,-1.5,-2,2,0.55,0.85,accent)
	_rect("PortSealedAccess",-1.6,-1.5,-2,2,0.85,3.4,glass)
	_rect("StarboardSill",1.5,1.6,-2,2,0.55,0.85,accent)
	_rect("StarboardGlazing",1.5,1.6,-2,2,0.85,3.4,glass)
	_rect("CanopyRoof",-1.6,1.6,-2.12,2.12,3.4,3.6,armor)
	_cockpit_root = Node3D.new()
	_cockpit_root.name = "PilotFixture"
	_visual_root.add_child(_cockpit_root)
	_pilot_seat_anchor = Marker3D.new()
	_pilot_seat_anchor.name = "PilotSeatAnchor"
	_pilot_seat_anchor.position = PILOT_ORIGIN
	_pilot_seat_anchor.set_meta("station_id", &"pilot_station")
	_cockpit_root.add_child(_pilot_seat_anchor)
	# Actual cushion follows HeroShip's present +.72m seated hip convention.
	_rect("PilotPedestal",-.12,.12,-.95,-.7,0.55,1.17,structure)
	_rect("PilotCushion",-.28,.28,-1.15,-.5,1.17,1.27,accent)
	_rect("PilotBack",-.28,.28,-.5,-.38,1.27,2.02,structure)
	_build_markers_and_camera()
	_boarding_marker.position = FUTURE_ENTRY
	_exit_marker.position = Vector3(-5.5,0,0.4)
	_boarding_entry_marker = Marker3D.new()
	_boarding_entry_marker.name = "FutureEntry"
	_boarding_entry_marker.position = FUTURE_ENTRY
	add_child(_boarding_entry_marker)
	_camera_pivot.position = Vector3(0,2.2,0)
	# Retain HeroShip's camera construction while replacing both temporary
	# emitter markers with exactly one centre origin, including held fire.
	_muzzle_left.free()
	_muzzle_right.free()
	_muzzle_left = Marker3D.new()
	_muzzle_left.name = "CenterMuzzle"
	_muzzle_left.position = CENTER_MUZZLE
	add_child(_muzzle_left)
	_muzzle_right = _muzzle_left
	var receiver := Marker3D.new()
	receiver.name = "DockingReceiver"
	add_child(receiver)
	_cockpit_readout = Label3D.new()
	_cockpit_readout.name = "FlightDataReadout"
	_cockpit_readout.position = Vector3(0,1.5,-1.82)
	_cockpit_readout.font_size = 36
	_cockpit_readout.pixel_size = 0.001
	_cockpit_readout.modulate = Color("8de8e4")
	_cockpit_readout.text = "OFFLINE  //  HOLD"
	_cockpit_readout.set_meta("presentation_only", true)
	_cockpit_root.add_child(_cockpit_readout)


func _finish(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = 0.28
	return material


func _rect(label: String, left: float, right: float, front: float, rear: float,
		bottom: float, top: float, material: Material) -> MeshInstance3D:
	return _prism(label,[Vector2(left,front),Vector2(right,front),
		Vector2(right,rear),Vector2(left,rear)],bottom,top,material)


## Each editable convex footprint is the sole source of both collision points
## and visible triangles. Collision stays directly under the CharacterBody3D.
func _prism(label: String, footprint: Array, bottom: float, top: float,
		material: Material) -> MeshInstance3D:
	var polygon := PackedVector2Array(footprint)
	if Geometry2D.is_polygon_clockwise(polygon):
		polygon.reverse()
	var points := PackedVector3Array()
	var centroid := Vector3.ZERO
	for height in [bottom,top]:
		for point in polygon:
			var vertex := Vector3(point.x,height,point.y)
			points.append(vertex)
			centroid += vertex
	centroid /= float(points.size())
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
		_triangle(surface,points[indices[i]],points[indices[i+1]],points[indices[i+2]],centroid)
		_triangle(surface,points[indices[i]+count],points[indices[i+1]+count],points[indices[i+2]+count],centroid)
	for i in count:
		var next := (i+1)%count
		_triangle(surface,points[i],points[next],points[i+count],centroid)
		_triangle(surface,points[next],points[next+count],points[i+count],centroid)
	var mesh := MeshInstance3D.new()
	mesh.name = label
	mesh.mesh = surface.commit()
	_visual_root.add_child(mesh)
	return mesh


func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		centroid: Vector3) -> void:
	var normal := (b-a).cross(c-a).normalized()
	if normal.dot((a+b+c)/3.0-centroid) < 0.0:
		normal = -normal
	else:
		# Godot front faces use clockwise winding when viewed from outside.
		var swap := b
		b = c
		c = swap
	for vertex in [a,b,c]:
		surface.set_normal(normal)
		surface.add_vertex(vertex)
