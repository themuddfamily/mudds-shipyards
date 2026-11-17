extends HeroShip

## Original modern Dynamic: supported physical port access and one pilot.
## Main composes its single helm; full combat qualification remains separate.
## Component positions below follow this shell; health/stages/repair stay shared.
## Metres, +Y up, -Z forward; every solid section owns matching mesh vertices.
const PILOT_ORIGIN := Vector3(0, 0.50, -0.8)
const FUTURE_ENTRY := Vector3(-0.9, 0.55, 0.4)
const CENTER_MUZZLE := Vector3(0, 0.9, -4.9)
const ROOF_OPEN_ANGLE := asin(1.9 / sqrt(4.24 * 4.24 + 0.2 * 0.2)) - atan2(0.2, 4.24)
var _original_shell: Node3D
var _access_leaves: Array[Dictionary] = []
var _access_fraction := 0.0


## One existing five-section ledger, placed on real candidate solids rather
## than the fighter template's empty-space anchors. A single logical engine
## section is anchored at the starboard aft engine; both engines retain the
## existing common mobility channel. No new forward-hull mobility binding.
class DynamicComponentDamage:
	extends ShipComponentDamage

	func _derive_layout(local_bounds: AABB) -> Dictionary:
		var layout := super._derive_layout(local_bounds)
		if layout.is_empty():
			return layout
		layout[COMPONENT_FORWARD_HULL].local_position = Vector3(0.85,1.2,-4.3)
		layout[COMPONENT_PORT_WING].local_position = Vector3(-3.6,1.2,2.8)
		layout[COMPONENT_STARBOARD_WING].local_position = Vector3(3.6,1.2,2.8)
		layout[COMPONENT_CORE_SYSTEMS].local_position = Vector3(0,3,2.06)
		layout[COMPONENT_ENGINE_BAY].local_position = Vector3(3.15,2.15,4.9)
		return layout


func can_board_from_landed_approach(actor: PlayerController) -> bool:
	if not is_boardable() or not is_instance_valid(actor) or not actor.is_inside_tree() \
			or actor.is_queued_for_deletion() or not actor.is_control_enabled() \
			or actor.is_seated() or not actor.is_on_floor() \
			or actor.collision_layer != PhysicsLayers.PLAYER_BODY_LAYER \
			or actor.collision_mask != PhysicsLayers.PLAYER_BODY_MASK \
			or (actor.get_node("PlayerCollision") as CollisionShape3D).disabled:
		return false
	var point := to_local(actor.global_position)
	return Vector2(point.x-FUTURE_ENTRY.x,point.z-FUTURE_ENTRY.z).length() <= 0.16 \
		and absf(point.y-FUTURE_ENTRY.y) <= 0.04 and has_clear_landed_pilot_stand(actor)


## Query the actor's actual normal capsule at the supported interior exit.
## The support surface stays in the query; only the normal contact skin is removed.
func has_clear_landed_pilot_stand(actor: PlayerController) -> bool:
	if not is_access_supported() or not is_instance_valid(actor):
		return false
	var collision := actor.get_node_or_null("PlayerCollision") as CollisionShape3D
	if collision == null or not collision.shape is CapsuleShape3D:
		return false
	var capsule := collision.shape.duplicate() as CapsuleShape3D
	capsule.radius -= 0.005
	capsule.height -= 0.01
	var pose := get_exit_transform() * collision.transform
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = pose
	query.margin = 0
	query.collision_mask = PhysicsLayers.WORLD | PhysicsLayers.SHIP
	query.exclude = [actor.get_rid()]
	if not get_world_3d().direct_space_state.intersect_shape(query,16).is_empty():
		return false
	var up := global_basis.y.normalized()
	var feet := get_exit_transform().origin
	var support := PhysicsRayQueryParameters3D.create(feet+up*0.06,feet-up*0.06,
		PhysicsLayers.WORLD | PhysicsLayers.SHIP,[actor.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(support)
	return not hit.is_empty() and hit.collider == self and (hit.normal as Vector3).dot(up) > 0.99


func _uses_torrent_reconstruction_presentation() -> bool:
	return false


func get_variant_visual_root() -> Node3D:
	return _original_shell


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
	var damage := DynamicComponentDamage.new()
	damage.name = "ShipComponentDamage"
	add_child(damage)
	install_shared_damage_presentation(Vector3(-3.6,1.2,2.8),
		Vector3(3.15,2.15,4.9),Vector3(0,3,2.06),8)
	collision_layer = PhysicsLayers.SHIP_BODY_LAYER
	collision_mask = PhysicsLayers.SHIP_BODY_MASK
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	floor_stop_on_slope = false
	set_meta("geometry_status", &"original_modern_candidate")
	set_meta("authenticated_historical_silhouette", false)
	_original_shell = Node3D.new()
	_original_shell.name = "DynamicOriginalShell"
	add_child(_original_shell)
	# Solid sections stay in exactly the same frame as their root colliders.
	# HeroShip's cosmetic visual bank affects only the non-solid readout rig.
	_visual_root = Node3D.new()
	_visual_root.name = "DynamicPilotPresentation"
	add_child(_visual_root)
	var armor := _finish(Color("98adb3"), 0.55)
	var structure := _finish(Color("233743"), 0.8)
	var accent := _finish(Color("dc8961"), 0.5)
	var glass := _finish(Color(0.14, 0.65, 0.73, 0.18), 0.18)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Chamfered central tub supports the entire future recess at y=0.55.
	_prism("CentralFloor", [Vector2(-1.1,-5),Vector2(1.1,-5),
		Vector2(1.6,-4.4),Vector2(1.6,4.5),Vector2(1.1,5),
		Vector2(-1.1,5),Vector2(-1.5,4.5),Vector2(-1.5,-4.4)],0,0.55,structure)
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
	_build_access(armor, glass, accent)
	_rect("StarboardSill",1.5,1.6,-2,2,0.55,0.85,accent)
	_rect("StarboardGlazing",1.5,1.6,-2,2,0.85,3.4,glass)
	_cockpit_root = Node3D.new()
	_cockpit_root.name = "PilotFixture"
	_visual_root.add_child(_cockpit_root)
	_pilot_seat_anchor = Marker3D.new()
	_pilot_seat_anchor.name = "PilotSeatAnchor"
	_pilot_seat_anchor.position = PILOT_ORIGIN
	_pilot_seat_anchor.set_meta("station_id", &"pilot_station")
	add_child(_pilot_seat_anchor)
	# Actual cushion follows HeroShip's present +.72m seated hip convention.
	_rect("PilotPedestal",-.12,.12,-.95,-.7,0.55,1.17,structure)
	_rect("PilotCushion",-.28,.28,-1.15,-.5,1.17,1.27,accent)
	_rect("PilotBack",-.28,.28,-.5,-.38,1.27,2.02,structure)
	_build_markers_and_camera()
	_cockpit_camera.reparent(self, false)
	_cockpit_camera.position = cockpit_camera_position
	_boarding_marker.position = FUTURE_ENTRY
	_exit_marker.position = FUTURE_ENTRY
	_boarding_entry_marker = Marker3D.new()
	_boarding_entry_marker.name = "BoardingEntry"
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


func _has_deck_support() -> bool:
	if not is_inside_tree():
		return false
	# The real hull, deployed ramp edges and physical operator must all have
	# the same support plane. Broad proximity to a berth is insufficient.
	for point in [Vector3.ZERO,Vector3(-5.2,0,-0.95),Vector3(-5.2,0,0.95),Vector3(-5.9,0,-2.4)]:
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
		# Outer carriage moves above the still-stowed inner section. It lowers
		# only after both deployed footprints meet exactly at their common edge.
		var slide := clampf(fraction / 0.6, 0.0, 1.0)
		var lower := clampf((fraction - 0.8) / 0.2, 0.0, 1.0)
		for point in leaf.open:
			points.append(point + Vector3(0.7 * (1.0 - slide), 0.5 * (1.0 - lower), 0))
	elif leaf.mesh.name == &"PortRamp1":
		var extend := clampf((fraction - 0.6) / 0.2, 0.0, 1.0)
		for point in leaf.open:
			points.append(point + Vector3(-0.15 * (1.0 - extend), 0, 0))
	elif leaf.mesh.name == &"PortSealedAccess":
		# The side spans the aft shoulder's z range. Raise its lower edge
		# above that armor before hinging outward; the complete hinge arc
		# stays above y=4.1-sqrt(2.55^2+.1^2)=1.548, clear of y<=1.5.
		var rise := clampf(fraction / 0.6, 0.0, 1.0)
		var swing := clampf((fraction - 0.6) / 0.4, 0.0, 1.0)
		var hinge := Vector3(-1.6,3.4 + 0.7 * rise,0)
		var rotation := Basis(Vector3.FORWARD, PI * 0.5 * swing)
		for point in leaf.closed:
			points.append(hinge + rotation * (point + Vector3.UP * 0.7 * rise - hinge))
	elif leaf.mesh.name == &"CanopyRoof":
		var hinge := Vector3(0,3.4,2.12)
		var rotation := Basis(Vector3.RIGHT, ROOF_OPEN_ANGLE * fraction)
		for point in leaf.closed:
			points.append(hinge + rotation * (point - hinge))
	else:
		var phase := clampf(fraction / 0.6, 0.0, 1.0)
		for i in leaf.closed.size():
			points.append((leaf.closed[i] as Vector3).lerp(leaf.open[i], phase))
	return points


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
	_original_shell.add_child(mesh)
	_access_leaves.append({"collision":collision,"mesh":mesh,"closed":closed,"open":opened,"material":material})


func _leaf_mesh(points: PackedVector3Array, material: Material) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	var center := Vector3.ZERO
	for point in points:
		center += point / float(points.size())
	# Corresponding bottom/top corners preserve rigid hinges and ramp slopes.
	var triangles := [0,1,2,0,2,3,6,5,4,7,6,4,4,1,0,4,5,1,5,2,1,5,6,2,6,3,2,6,7,3,7,0,3,7,4,0]
	for i in range(0,triangles.size(),3):
		var a := points[triangles[i]]
		var b := points[triangles[i+1]]
		var c := points[triangles[i+2]]
		if (b-a).cross(c-a).length_squared() > 0.00000001:
			_triangle(surface,a,b,c,center)
	return surface.commit()


func _box_points(left: float, right: float, front: float, rear: float, bottom: float, top: float) -> PackedVector3Array:
	return PackedVector3Array([Vector3(left,bottom,front),Vector3(right,bottom,front),Vector3(right,bottom,rear),Vector3(left,bottom,rear),Vector3(left,top,front),Vector3(right,top,front),Vector3(right,top,rear),Vector3(left,top,rear)])


func _build_access(armor: Material, glass: Material, accent: Material) -> void:
	# HeroShip owns the animation clock; this empty authority pivot never
	# rotates solid presentation independently from its root collision.
	_canopy_pivot = Node3D.new()
	_canopy_pivot.name = "CanopyMotionAuthority"
	_original_shell.add_child(_canopy_pivot)
	var sill := _box_points(-1.6,-1.5,-2,2,0.55,0.85)
	var dropped := sill.duplicate()
	for i in dropped.size():
		dropped[i] -= Vector3.UP * 0.5
	_moving_leaf("PortSill",sill,dropped,accent)
	var side := _box_points(-1.6,-1.5,-2,2,0.85,3.4)
	_moving_leaf("PortSealedAccess",side,side,glass)
	var roof := _box_points(-1.5,1.5,-2.12,2.12,3.4,3.6)
	_moving_leaf("CanopyRoof",roof,roof,armor)
	for index in 2:
		var left := -5.2 + index * 1.85
		var opened := _box_points(left,left + 1.85,-1,1,0,0)
		for i in opened.size():
			var progress := (opened[i].x + 5.2) / 3.7
			opened[i].y = progress * (0.55 if i >= 4 else 0.47)
		var closed := opened.duplicate()
		for i in closed.size():
			closed[i] += Vector3(0.7,0.5,0) if index == 0 else Vector3(-0.15,0,0)
		_moving_leaf("PortRamp" + str(index),closed,opened,accent)
	var boarding := ShipBoardingArea.new()
	boarding.name = "ShipBoardingArea"
	boarding.prompt_text = "[ E ]  BOARD DYNAMIC CANDIDATE"
	boarding.position = FUTURE_ENTRY
	add_child(boarding)
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.22
	shape.shape = sphere
	boarding.add_child(shape)
	ShipCabinHatch.install(self,self,Vector3(-4.2,1.6,-2.4))
	# Physical fixed control is ahead of the z±2 hinged-side sweep and the
	# z±1 ramp, within the adopted closed envelope. Reach remains unchanged.
	_rect("PortControlBracket",-4.3,-1.6,-2.5,-2.3,1.5,1.7,accent)


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
	_original_shell.add_child(mesh)
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
