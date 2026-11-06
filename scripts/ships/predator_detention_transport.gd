extends HeroShip

## Card 1: original modern standalone hull and unarmed pilot flight only.
## The supported void and reserved future poses confer no access, crew or cell authority.
const PILOT_ORIGIN := Vector3(0, 1.45, -5.5)
const CABIN_VOID := AABB(Vector3(-3, 1, -6.5), Vector3(6, 3.6, 13))
const SECURE_RESERVE := AABB(Vector3(-3, 1, -1), Vector3(2.4, 2.6, 4.8))
const AISLE_RESERVE := AABB(Vector3(0.2, 1, -6.5), Vector3(1.6, 2.6, 13))
const REAR_CORRIDOR_RESERVE := AABB(Vector3(-3, 1, 4.2), Vector3(6, 2.6, 2.3))


func _uses_torrent_reconstruction_presentation() -> bool:
	return false


func _uses_inherited_primary_weapon() -> bool:
	return false


func _uses_weapon_component_fallback_emitters() -> bool:
	return false


func _get_weapon_unavailable_reason(_modifiers: Dictionary = {}) -> StringName:
	return &"unarmed"


func _get_weapon_fire_status_from_modifiers(_modifiers: Dictionary) -> Dictionary:
	return {"ready": false, "status": &"unarmed", "reason": &"unarmed", "heat": 0.0,
		"cooldown_remaining": 0.0, "recovery_remaining": 0.0}


func _fire_weapon() -> void:
	pass


func _fire_weapon_with_aim(_crew_origin: Vector3 = Vector3.INF, _crew_direction: Vector3 = Vector3.ZERO) -> void:
	pass


func _get_cockpit_system_readout() -> Dictionary:
	return {"text": "UNARMED  //  DETENTION TRANSPORT", "color": Color("8de8e4")}


func _wake_engine_for_automatic_demand(_release_dock_latch: bool = true) -> void:
	# Both start paths use the same real inherited 3.8-second spool.
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
	_visual_root.name = "PredatorOriginalShell"
	add_child(_visual_root)
	var armor := _finish(Color("8c9da6"), 0.65)
	var structure := _finish(Color("25333b"), 0.8)
	var accent := _finish(Color("d0a45e"), 0.5)
	var glass := _finish(Color(0.12, 0.47, 0.55, 0.26), 0.18)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var outer := [Vector2(-2.4,-8),Vector2(2.4,-8),Vector2(3.4,-7),Vector2(3.4,7),
		Vector2(2.4,8),Vector2(-2.4,8),Vector2(-3.4,7),Vector2(-3.4,-7)]
	var inner := [Vector2(-2.2,-7.6),Vector2(2.2,-7.6),Vector2(3,-6.6),Vector2(3,6.6),
		Vector2(2.2,7.6),Vector2(-2.2,7.6),Vector2(-3,6.6),Vector2(-3,-6.6)]
	_prism("PressureFloor", outer, 0, 1, structure)
	_prism("PressureRoof", outer, 4.6, 5, armor)
	for i in 8:
		var next := (i + 1) % 8
		var strip := [outer[i], outer[next], inner[next], inner[i]]
		if i == 0:
			_prism("NoseSill",strip,1,2.4,armor)
			_prism("HelmGlazing",strip,2.4,3.8,glass)
			_prism("NoseHeader",strip,3.8,4.6,armor)
		elif i == 4:
			# Closed recessed 2.4m ramp; no deploy/open interaction is installed.
			_prism("SternPortFrame",[Vector2(-2.4,8),Vector2(-0.2,8),Vector2(-0.2,7.6),Vector2(-2.2,7.6)],1,4.6,armor)
			_prism("SternStarboardFrame",[Vector2(2.2,7.6),Vector2(2.4,8),Vector2(2.2,8)],1,4.6,armor)
			_rect("StowedRecessedSternRamp",-0.2,2.2,7.6,7.85,1,3.6,structure)
			_rect("SternRampHeader",-0.2,2.2,7.6,8,3.6,4.6,accent)
		else:
			_prism("PressureWall%d" % i,strip,1,4.6,armor)
	# Solid secure-compartment partition with a narrow observation window.
	_rect("SecureLowerWall",-0.8,-0.6,-1,3.8,1,2.5,structure)
	_rect("SecureUpperWall",-0.8,-0.6,-1,3.8,3.1,4.6,structure)
	_rect("SecureForwardPier",-0.8,-0.6,-1,0.3,2.5,3.1,structure)
	_rect("SecureAftPier",-0.8,-0.6,1.5,3.8,2.5,3.1,structure)
	_rect("SecureObservationWindow",-0.8,-0.6,0.3,1.5,2.5,3.1,glass)
	_rect("SecureForwardBulkhead",-3,-0.6,-1.2,-1,1,4.6,armor)
	_rect("SecureAftBulkhead",-3,-0.6,3.8,4,1,4.6,armor)
	for side in [-1.0,1.0]:
		var label := "Port" if side < 0 else "Starboard"
		var left := minf(side*3.4,side*4.5)
		var right := maxf(side*3.4,side*4.5)
		_prism(label + "EnginePod",[Vector2(left,-5),Vector2(right,-4.5),Vector2(right,5.5),Vector2(left,6)],1.1,3.4,structure)
		var glow := _rect(label + "Exhaust",left,right,5.5,6,3.4,3.6,_finish(Color("60cbd1"),0.2))
		_engine_core_glows.append(glow)
	_cockpit_root = Node3D.new()
	_cockpit_root.name = "PilotFixture"
	_visual_root.add_child(_cockpit_root)
	_pilot_seat_anchor = Marker3D.new()
	_pilot_seat_anchor.name = "PilotSeatAnchor"
	_pilot_seat_anchor.position = PILOT_ORIGIN
	_pilot_seat_anchor.set_meta("station_id", &"pilot_station")
	_cockpit_root.add_child(_pilot_seat_anchor)
	# Physical chairs are a later card; the anchor alone reserves the exact helm.
	_build_markers_and_camera()
	# Common camera construction creates weapon markers; retire them before
	# deferred component discovery. All direct fire methods are also inert.
	_muzzle_left.free()
	_muzzle_right.free()
	_muzzle_left = null
	_muzzle_right = null
	_boarding_marker.position = Vector3(1,1,-5.5)
	_exit_marker.position = Vector3(1,0,9)
	_camera_pivot.position = Vector3(0,3,0)
	_install_variant_cockpit_system_readout(_cockpit_root)
	_cockpit_readout.position = Vector3(0,2.75,-6.6)
	var receiver := Marker3D.new()
	receiver.name = "DockingReceiver"
	receiver.position = Vector3(0,2.5,1.5)
	add_child(receiver)
	_sync_engine_visuals_immediately()


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
