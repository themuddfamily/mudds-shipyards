extends HeroShip

## Owner-adopted original modern trial; A4 authenticates no historical model.
## Supported physical stern access; no pilot claim, passenger or Main grant.
const PILOT_ORIGIN := Vector3(0, 0.9, -4.7)
const PILOT_ENTRY := Vector3(-0.75, 0.9, -3.3)
const CABIN_VOID := AABB(Vector3(-2, 0.9, -5.6), Vector3(4, 2.5, 11.2))
const AISLE_RESERVE := AABB(Vector3(-0.7, 0.9, -3.3), Vector3(1.4, 2.5, 8.9))
const PORT_CHAIR_RESERVE := AABB(Vector3(-1.7, 0.9, -1.1), Vector3(0.9, 2.0, 1.2))
const STARBOARD_CHAIR_RESERVE := AABB(Vector3(0.8, 0.9, -1.1), Vector3(0.9, 2.0, 1.2))
const RAMP_STOW_ANGLE := -PI * 0.5 - atan(0.3)
var _original_shell: Node3D
var _access_leaves: Array[Dictionary] = []
var _access_fraction := 0.0


func get_variant_visual_root() -> Node3D:
	return _original_shell


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
	return {"text": "UNARMED  //  SALYUT TRANSPORT", "color": Color("e7c483")}


func _wake_engine_for_automatic_demand(_release_dock_latch: bool = true) -> void:
	# Demand and explicit start share the real 2.9-second inherited spool clock.
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
	_original_shell = Node3D.new()
	_original_shell.name = "SalyutOriginalShell"
	add_child(_original_shell)
	# Solid mesh sections share the root collision frame during turns. Only the
	# cosmetic presentation receives HeroShip's bank; authority frames stay fixed.
	_visual_root = Node3D.new()
	_visual_root.name = "SalyutPilotPresentation"
	add_child(_visual_root)
	var white := _salyut_finish(Color("e1e5e3"), 0.6)
	var keel := _salyut_finish(Color("253039"), 0.8)
	var ochre := _salyut_finish(Color("bf8f40"), 0.5)
	var glass := _salyut_finish(Color(0.16, 0.40, 0.47, 0.23), 0.15)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var blue := _salyut_finish(Color("70c6ce"), 0.3)
	blue.emission_enabled = true
	blue.emission = Color("70c6ce")
	blue.emission_energy_multiplier = 1.4
	# Six editable footprint vertices. The entire upper shell shears 0.6m aft,
	# giving a sloping glazed bow and a short hexagonal pressure cabin.
	var outer := [Vector2(-2.6,-7),Vector2(2.6,-7),Vector2(3,0),
		Vector2(2.6,6.4),Vector2(-2.6,6.4),Vector2(-3,0)]
	var inner := [Vector2(-2.3,-6.7),Vector2(2.3,-6.7),Vector2(2.7,0),
		Vector2(2.3,6.1),Vector2(-2.3,6.1),Vector2(-2.7,0)]
	_salyut_section("KeelFloor", outer, 0, 0.9, keel)
	_salyut_section("UpperPressureRoof", outer, 4.2, 4.5, white)
	for index in 6:
		var next := (index+1)%6
		var strip := [outer[index],outer[next],inner[next],inner[index]]
		if index == 0:
			_salyut_section("BowLowerSill", strip, 0.9, 1.8, white)
			_salyut_section("SlopingBowGlazing", strip, 1.8, 3.7, glass)
			_salyut_section("BowHeader", strip, 3.7, 4.2, white)
		elif index == 3:
			# Separate jambs leave the full physical stern opening.
			_salyut_section("SternPortJamb",[Vector2(-2.6,6.4),Vector2(-1.1,6.4),
				Vector2(-1.1,6.1),Vector2(-2.3,6.1)],0.9,3.3,white)
			_salyut_section("SternStarboardJamb",[Vector2(1.1,6.1),Vector2(2.3,6.1),
				Vector2(2.6,6.4),Vector2(1.1,6.4)],0.9,3.3,white)
			_salyut_section("OchreEntryBand",strip,3.3,3.45,ochre)
			_salyut_section("SternHeader",strip,3.45,4.2,white)
			_build_stern_access(keel,ochre)
		else:
			_salyut_section("HexPressureWall%d" % index,strip,0.9,4.2,white)
	for side in [-1.0,1.0]:
		var label := "Port" if side < 0 else "Starboard"
		# Compact pods lie outside the pressure shell, with no shared solid volume.
		var pod := [Vector2(side*2.90625,1.5),Vector2(side*3.65,1.5),
			Vector2(side*4,2.2),Vector2(side*4,5.7),Vector2(side*2.64375,5.7)]
		_salyut_section(label+"AftDrivePod",pod,1.1,2.9,keel)
		_salyut_rect(label+"DriveCore",minf(side*2.64375,side*4),
			maxf(side*2.64375,side*4),5.7,5.9,1.1,2.9,blue)
	_cockpit_root = Node3D.new()
	_cockpit_root.name = "PilotFixture"
	# Pilot, entry and eye frames follow the physical ship without cosmetic bank.
	add_child(_cockpit_root)
	_pilot_seat_anchor = Marker3D.new()
	_pilot_seat_anchor.name = "PilotSeatAnchor"
	_pilot_seat_anchor.position = PILOT_ORIGIN
	_pilot_seat_anchor.set_meta("station_id", &"pilot_station")
	_cockpit_root.add_child(_pilot_seat_anchor)
	_build_markers_and_camera()
	# The common camera constructor also creates these; retire both immediately.
	_muzzle_left.free()
	_muzzle_right.free()
	_muzzle_left = null
	_muzzle_right = null
	_boarding_marker.position = PILOT_ENTRY
	_exit_marker.position = PILOT_ENTRY
	_exit_marker.rotation = Vector3.ZERO
	_boarding_entry_marker = Marker3D.new()
	_boarding_entry_marker.name = "BoardingEntry"
	_boarding_entry_marker.position = PILOT_ENTRY
	_cockpit_root.add_child(_boarding_entry_marker)
	_camera_pivot.position = Vector3(0,3,0)
	_install_variant_cockpit_system_readout(_cockpit_root)
	_cockpit_readout.position = Vector3(0,1.98,-5.75)
	var receiver := Marker3D.new()
	receiver.name = "DockingReceiver"
	add_child(receiver)
	_sync_engine_visuals_immediately()


func _has_access_deck_support() -> bool:
	if not is_inside_tree(): return false
	for point in [Vector3.ZERO,Vector3(-1.05,0,10),Vector3(1.05,0,10),Vector3(-2.3,0,8.6)]:
		var origin := to_global(point)
		var query := PhysicsRayQueryParameters3D.create(origin+global_basis.y*0.1,origin-global_basis.y*0.2,PhysicsLayers.WORLD|PhysicsLayers.SHIP)
		query.exclude = [get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or (hit.normal as Vector3).dot(global_basis.y) <= 0.95: return false
	return true


func is_access_motion_active() -> bool:
	return _canopy_tween != null and _canopy_tween.is_valid()


func is_access_supported() -> bool:
	return not _destroyed and not _landing_active and _landed and velocity.length() < 0.01 and _engine_state == ENGINE_OFFLINE and _has_access_deck_support()


func set_canopy_open(open: bool, duration: float = 0.65) -> void:
	if is_access_motion_active() or (open and not is_access_supported()): return
	super.set_canopy_open(open,duration)


func _access_blocks_propulsion() -> bool:
	return _canopy_open or _access_fraction > 0.0 or is_access_motion_active()


func request_engine_start() -> void:
	if not _access_blocks_propulsion(): super.request_engine_start()


func _sample_ship_command() -> ShipCommand:
	var command := super._sample_ship_command()
	return _neutralized_command_snapshot(command) if _access_blocks_propulsion() else command


func _set_canopy_open_fraction(open_fraction: float) -> void:
	super._set_canopy_open_fraction(open_fraction)
	_access_fraction = clampf(open_fraction,0,1)
	for leaf in _access_leaves:
		var points := _access_leaf_points(leaf,_access_fraction)
		(leaf.collision.shape as ConvexPolygonShape3D).points = points
		leaf.mesh.mesh = _access_mesh(points,leaf.material)


func _phase(fraction: float, start: float, finish: float) -> float:
	return clampf((fraction-start)/(finish-start),0,1)


func _access_leaf_points(leaf: Dictionary, fraction: float) -> PackedVector3Array:
	if leaf.has("ramp_index"):
		return _ramp_points(leaf.ramp_index,leaf.open,fraction)
	var points := PackedVector3Array()
	var offset := Vector3(float(leaf.side)*1.1*_phase(fraction,0.15,0.3),0,-0.2*_phase(fraction,0,0.15))
	for point in leaf.closed: points.append(point+offset)
	return points


func _ramp_points(index: int, opened: PackedVector3Array, fraction: float) -> PackedVector3Array:
	var original_front := Vector3(0,0.9-index*0.45,7+index*1.5)
	var angle := RAMP_STOW_ANGLE
	var front := Vector3.ZERO
	if index == 1:
		if fraction <= 0.3:
			var travel := _phase(fraction,0.15,0.3)
			front = Vector3(2.2*_phase(fraction,0,0.15),0.9-0.3*travel,lerpf(6.82-0.04*absf(sin(RAMP_STOW_ANGLE)),8.5,travel))
		elif fraction <= 0.4:
			front = Vector3(2.2*(1-_phase(fraction,0.3,0.4)),0.6,8.5)
		elif fraction <= 0.6:
			angle *= 1-_phase(fraction,0.4,0.6)
			front = Vector3(0,0.6,8.5)
		else:
			angle = 0
			front = Vector3(0,0.6-0.15*_phase(fraction,0.6,0.65),8.5)
	else:
		if fraction <= 0.75:
			var lift := _phase(fraction,0.65,0.75)
			front = Vector3(0,0.9+0.15*lift,7-0.08*absf(sin(RAMP_STOW_ANGLE))*(1-lift))
		elif fraction <= 0.95:
			angle *= 1-_phase(fraction,0.75,0.95)
			front = Vector3(0,1.05,7)
		else:
			angle = 0
			front = Vector3(0,1.05-0.15*_phase(fraction,0.95,1),7)
	var rotation := Basis(Vector3.RIGHT,angle)
	var rotated := PackedVector3Array()
	var maximum_z := -INF
	for point in opened:
		var posed := rotation*(point-original_front)
		rotated.append(posed)
		maximum_z = maxf(maximum_z,posed.z)
	# A 1.5m leaf has a 1.566m hinge radius. Compensate every actual
	# rotated corner during swing, then lower only at the exact final join.
	if (index == 1 and fraction > 0.4 and fraction <= 0.6) or (index == 0 and fraction > 0.75 and fraction <= 0.95):
		front.z = minf(front.z,(10.0 if index == 1 else 8.5)-maximum_z)
	var points := PackedVector3Array()
	for point in rotated: points.append(point+front)
	return points


func _access_box(left: float, right: float, front: float, rear: float, bottom: float, top: float, shear: bool = false) -> PackedVector3Array:
	var points := PackedVector3Array([Vector3(left,bottom,front),Vector3(right,bottom,front),Vector3(right,bottom,rear),Vector3(left,bottom,rear),Vector3(left,top,front),Vector3(right,top,front),Vector3(right,top,rear),Vector3(left,top,rear)])
	if shear:
		for i in points.size(): points[i].z += 0.6*clampf((points[i].y-0.9)/3.3,0,1)
	return points


func _moving_access_leaf(label: String, closed: PackedVector3Array, opened: PackedVector3Array, material: Material, extra: Dictionary) -> void:
	var collision := CollisionShape3D.new()
	collision.name = label+"Collision"
	var shape := ConvexPolygonShape3D.new()
	shape.points = closed
	collision.shape = shape
	add_child(collision)
	var mesh := MeshInstance3D.new()
	mesh.name = label
	mesh.mesh = _access_mesh(closed,material)
	_original_shell.add_child(mesh)
	var leaf := {"collision":collision,"mesh":mesh,"closed":closed,"open":opened,"material":material}
	leaf.merge(extra)
	_access_leaves.append(leaf)


func _access_mesh(points: PackedVector3Array, material: Material) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	var center := Vector3.ZERO
	for point in points: center += point/float(points.size())
	var triangles := [0,1,2,0,2,3,6,5,4,7,6,4,4,1,0,4,5,1,5,2,1,5,6,2,6,3,2,6,7,3,7,0,3,7,4,0]
	for i in range(0,triangles.size(),3):
		var a := points[triangles[i]]
		var b := points[triangles[i+1]]
		var c := points[triangles[i+2]]
		if (b-a).cross(c-a).length_squared() > 0.00000001: _salyut_triangle(surface,a,b,c,center)
	return surface.commit()


func _build_stern_access(keel: Material, ochre: Material) -> void:
	_canopy_pivot = Node3D.new()
	_canopy_pivot.name = "SternAccessMotionAuthority"
	_original_shell.add_child(_canopy_pivot)
	_salyut_rect("SternVestibule",-1.1,1.1,6.4,7,0.82,0.9,keel,false)
	for side in [-1,1]:
		var closed := _access_box(-1.1 if side < 0 else 0,0 if side < 0 else 1.1,6.1,6.22,0.9,3.3,true)
		_moving_access_leaf("SternPortClosure" if side < 0 else "SternStarboardClosure",closed,closed,keel,{"side":side})
	for index in 2:
		var opened := _access_box(-1.1,1.1,7+1.5*index,8.5+1.5*index,0,0)
		for i in opened.size(): opened[i].y = (10-opened[i].z)/3*(0.9 if i >= 4 else 0.82)
		_moving_access_leaf("SternRamp"+str(index),_ramp_points(index,opened,0),opened,ochre,{"ramp_index":index})
	_salyut_rect("SternPortControlBracket",-2.15,-1.85,6.4,6.65,1.5,1.7,ochre,true)
	ShipCabinHatch.install(self,self,Vector3(-2,1.6,6.72))


func _salyut_finish(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = 0.2
	return material


func _salyut_rect(label: String, left: float, right: float, front: float, rear: float,
		bottom: float, top: float, material: Material, shear: bool = true) -> MeshInstance3D:
	return _salyut_section(label,[Vector2(left,front),Vector2(right,front),
		Vector2(right,rear),Vector2(left,rear)],bottom,top,material,shear)


## A shared authored vertex list supplies the convex shape and every mesh face.
## The bounded shear is affine within each section, preserving convexity.
func _salyut_section(label: String, footprint: Array, bottom: float, top: float,
		material: Material, shear: bool = true) -> MeshInstance3D:
	var polygon := PackedVector2Array(footprint)
	if Geometry2D.is_polygon_clockwise(polygon):
		polygon.reverse()
	var points := PackedVector3Array()
	for height in [bottom,top]:
		var shift := 0.6*clampf((height-0.9)/3.3,0,1) if shear else 0.0
		for point in polygon:
			points.append(Vector3(point.x,height,point.y+shift))
	var collision := CollisionShape3D.new()
	collision.name = label+"Collision"
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	collision.shape = shape
	add_child(collision)
	var center := Vector3.ZERO
	for point in points:
		center += point
	center /= float(points.size())
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	var count := polygon.size()
	var indices := Geometry2D.triangulate_polygon(polygon)
	for index in range(0,indices.size(),3):
		_salyut_triangle(surface,points[indices[index]],points[indices[index+1]],points[indices[index+2]],center)
		_salyut_triangle(surface,points[count+indices[index]],points[count+indices[index+1]],points[count+indices[index+2]],center)
	for index in count:
		var next := (index+1)%count
		_salyut_triangle(surface,points[index],points[next],points[index+count],center)
		_salyut_triangle(surface,points[next],points[next+count],points[index+count],center)
	var mesh := MeshInstance3D.new()
	mesh.name = label
	mesh.mesh = surface.commit()
	_original_shell.add_child(mesh)
	return mesh


func _salyut_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, center: Vector3) -> void:
	var normal := (b-a).cross(c-a).normalized()
	if normal.dot(a-center) < 0:
		normal = -normal
	# Godot front faces wind clockwise; normals point out of the solid.
	if (b-a).cross(c-a).dot(normal) > 0:
		var swap := b
		b = c
		c = swap
	surface.set_normal(normal)
	surface.add_vertex(a)
	surface.add_vertex(b)
	surface.add_vertex(c)
