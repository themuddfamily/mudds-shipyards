extends HeroShip

## Original modern standalone hull with continuous landed stern access.
## The reusable shell confers no helm; the production pilot prefab owns its seat.
const PILOT_ORIGIN := Vector3(0, 1.45, -5.5)
const CABIN_VOID := AABB(Vector3(-3, 1, -6.5), Vector3(6, 3.6, 13))
const SECURE_RESERVE := AABB(Vector3(-3, 1, -1), Vector3(2.4, 2.6, 4.8))
const AISLE_RESERVE := AABB(Vector3(0.2, 1, -6.5), Vector3(1.6, 2.6, 13))
const REAR_CORRIDOR_RESERVE := AABB(Vector3(-3, 1, 4.2), Vector3(6, 2.6, 2.3))
const RAMP_POINTS := [Vector3(-1.2,0,0),Vector3(-1.2,-0.08,0),Vector3(-1.2,-0.5,2),
	Vector3(1.2,0,0),Vector3(1.2,-0.08,0),Vector3(1.2,-0.5,2)]
const STOW_ANGLE := PI * 0.5 + atan(0.25)
var _access_fraction := 0.0
var _solid_root: Node3D


## Only the authored pilot composition supplies this real physical seat area.
func is_boardable() -> bool:
	return super.is_boardable() and has_node("ShipBoardingArea") \
		and is_canopy_open() and _access_fraction >= 0.999 and has_supported_exterior_access()


func can_board_from_landed_approach(actor: PlayerController) -> bool:
	if not is_boardable() or not is_instance_valid(actor) or not actor.is_inside_tree() \
			or actor.is_queued_for_deletion() or not actor.is_control_enabled() \
			or actor.is_seated() or not actor.is_on_floor() \
			or actor.collision_layer != PhysicsLayers.PLAYER_BODY_LAYER \
			or actor.collision_mask != PhysicsLayers.PLAYER_BODY_MASK \
			or (actor.get_node("PlayerCollision") as CollisionShape3D).disabled:
		return false
	var point := to_local(actor.global_position)
	return Vector2(point.x-1,point.z+5.5).length() <= 0.45 \
		and absf(point.y-1) <= 0.04 and has_clear_landed_pilot_stand(actor)


## Query the actor's actual normal capsule at the supported interior exit.
## The support surface stays in the query; only the normal contact skin is removed.
func has_clear_landed_pilot_stand(actor: PlayerController) -> bool:
	if not has_supported_exterior_access() or not is_instance_valid(actor):
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


func _sample_ship_command() -> ShipCommand:
	var command := super._sample_ship_command()
	return _neutralized_command_snapshot(command) if _access_blocks_propulsion() else command


func _access_blocks_propulsion() -> bool:
	return _canopy_open or _access_fraction > 0.0 or (_canopy_tween != null and _canopy_tween.is_valid())


func request_engine_start() -> void:
	if not _access_blocks_propulsion():
		super.request_engine_start()


func set_canopy_open(open: bool, duration: float = 0.35) -> void:
	if open and not has_supported_exterior_access():
		return
	super.set_canopy_open(open,duration)


func has_supported_exterior_access() -> bool:
	if not is_inside_tree() or _destroyed or not _landed or _landing_active \
			or _engine_state != ENGINE_OFFLINE or velocity.length() > 0.01:
		return false
	var up := global_basis.y.normalized()
	for point: Vector3 in [Vector3(-0.15,0,11),Vector3(2.15,0,11),Vector3(1,0,12.5)]:
		var world := global_transform * point
		var query := PhysicsRayQueryParameters3D.create(world+up*0.12,world-up*0.12,
			PhysicsLayers.WORLD | PhysicsLayers.SHIP,[get_rid()])
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or (hit.normal as Vector3).dot(up)<0.99 \
				or absf(((hit.position as Vector3)-world).dot(up))>0.03:
			return false
	return true


## Five finite stages reverse exactly on sealing. The inherited canopy tween
## remains the sole clock; all visible and physical pieces share these poses.
func get_access_transforms(open_fraction: float) -> Dictionary:
	var f := clampf(open_fraction,0,1)
	var door := Transform3D(Basis.IDENTITY,Vector3(-2.4*clampf(f*5,0,1),0,0))
	var outer_basis := Basis(Vector3.RIGHT,-STOW_ANGLE*(1-clampf((f-0.6)*5,0,1)))
	var maximum_z := 0.0
	for point: Vector3 in RAMP_POINTS:
		maximum_z = maxf(maximum_z,(outer_basis*point).z)
	var outer_origin := Vector3(1,1-0.5*clampf((f-0.4)*5,0,1),
		7.1+1.9*clampf((f-0.2)*5,0,1)-maxf(0,maximum_z-2))
	var inner_basis := Basis(Vector3.RIGHT,-STOW_ANGLE*(1-clampf((f-0.8)*5,0,1)))
	return {&"SternClosure":door,&"InnerSternRamp":Transform3D(inner_basis,Vector3(1,1,7)),
		&"OuterSternRamp":Transform3D(outer_basis,outer_origin)}


func _set_canopy_open_fraction(open_fraction: float) -> void:
	super._set_canopy_open_fraction(open_fraction)
	_access_fraction = clampf(open_fraction,0,1)
	if not has_node("InnerSternRampCollision"):
		return
	var poses := get_access_transforms(_access_fraction)
	for label: StringName in poses:
		(get_node(String(label)+"Collision") as CollisionShape3D).transform = poses[label]
		(_solid_root.get_node(NodePath(label)) as MeshInstance3D).transform = poses[label]


## Actual convex vertices, not the empty corners of rotated bounding boxes.
func get_landing_collision_report() -> Dictionary:
	var report := super.get_landing_collision_report()
	var bounds := AABB()
	var first := true
	for child in get_children():
		if not child is CollisionShape3D:
			continue
		var collision := child as CollisionShape3D
		if collision.disabled or not collision.shape is ConvexPolygonShape3D:
			continue
		for point: Vector3 in (collision.shape as ConvexPolygonShape3D).points:
			var actual := collision.transform*point
			bounds = AABB(actual,Vector3.ZERO) if first else bounds.expand(actual)
			first = false
	if not first:
		report.local_bounds = bounds
	return report


## The authored physical shell never inherits the cosmetic readout bank.
func get_variant_visual_root() -> Node3D:
	return _solid_root if is_instance_valid(_solid_root) else null


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
	_solid_root = Node3D.new()
	_solid_root.name = "PredatorOriginalShell"
	add_child(_solid_root)
	# HeroShip applies the approved four-degree bank only to this display.
	_visual_root = Node3D.new()
	_visual_root.name = "PredatorCosmeticBank"
	_visual_root.set_meta("presentation_only", true)
	add_child(_visual_root)
	_visual_root.visibility_changed.connect(_sync_solid_root_visibility)
	_sync_solid_root_visibility()
	var armor := _finish(Color("8c9da6"), 0.65)
	var structure := _finish(Color("25333b"), 0.8)
	var accent := _finish(Color("d0a45e"), 0.5)
	var glass := _finish(Color(0.12, 0.47, 0.55, 0.26), 0.18)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var outer := [Vector2(-2.4,-8),Vector2(2.4,-8),Vector2(3.4,-7),Vector2(3.4,7),
		Vector2(2.4,8),Vector2(-2.4,8),Vector2(-3.4,7),Vector2(-3.4,-7)]
	var inner := [Vector2(-2.2,-7.6),Vector2(2.2,-7.6),Vector2(3,-6.6),Vector2(3,6.6),
		Vector2(2.2,7.6),Vector2(-2.2,7.6),Vector2(-3,6.6),Vector2(-3,-6.6)]
	# Remove only the ramp band; the full cabin-to-hinge bridge stays solid.
	_prism("PressureFloor",outer.slice(0,4)+[Vector2(-3.4,7),Vector2(-3.4,-7)],0,1,structure)
	_prism("PortAftFloor",[Vector2(-3.4,7),Vector2(-0.2,7),Vector2(-0.2,8),Vector2(-2.4,8)],0,1,structure)
	_prism("StarboardAftFloor",[Vector2(2.2,7),Vector2(3.4,7),Vector2(2.4,8),Vector2(2.2,8)],0,1,structure)
	_prism("PressureRoof", outer, 4.6, 5, armor)
	for i in 8:
		var next := (i + 1) % 8
		var strip := [outer[i], outer[next], inner[next], inner[i]]
		if i == 0:
			_prism("NoseSill",strip,1,2.4,armor)
			_prism("HelmGlazing",strip,2.4,3.8,glass)
			_prism("NoseHeader",strip,3.8,4.6,armor)
		elif i == 4:
			# Full-width closure retracts into an actual recessed port-wall pocket.
			_prism("SternPortFrame",[Vector2(-2.4,8),Vector2(-0.2,8),Vector2(-0.2,7.6),Vector2(-2.2,7.6)],1,4.6,armor)
			_prism("SternStarboardFrame",[Vector2(2.2,7.6),Vector2(2.4,8),Vector2(2.2,8)],1,4.6,armor)
			_rect("SternClosure",-0.2,2.2,7.25,7.4,1,3.6,structure)
			_rect("SternRampHeader",-0.2,2.2,7.6,8,3.6,4.6,accent)
		elif i == 5:
			# Keep the original outer chamfer. Only the inside face recesses for
			# the closure pocket, aft of every reserved cabin/aisle volume.
			_prism("PressureWall5Forward",[Vector2(-3.4,7),Vector2(-3.15,7.25),Vector2(-2.48,7.25),Vector2(-3,6.6)],1,4.6,armor)
			_prism("PressureWall5Pocket",[Vector2(-3.15,7.25),Vector2(-3,7.4),Vector2(-2.6,7.4),Vector2(-2.6,7.25)],1,4.6,armor)
			_prism("PressureWall5Aft",[Vector2(-3,7.4),Vector2(-2.4,8),Vector2(-2.2,7.6),Vector2(-2.36,7.4)],1,4.6,armor)
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
		_rect(label + "Exhaust",left,right,5.5,6,3.4,3.6,_finish(Color("60cbd1"),0.2))
		_build_exhaust_glow(label, (left+right)*0.5)
	_cockpit_root = Node3D.new()
	_cockpit_root.name = "PilotFixture"
	_solid_root.add_child(_cockpit_root)
	_pilot_seat_anchor = Marker3D.new()
	_pilot_seat_anchor.name = "PilotSeatAnchor"
	_pilot_seat_anchor.position = PILOT_ORIGIN
	_pilot_seat_anchor.set_meta("station_id", &"pilot_station")
	_cockpit_root.add_child(_pilot_seat_anchor)
	# The reusable shell reserves the helm; pilot furniture belongs to its prefab.
	_build_markers_and_camera()
	# Common camera construction creates weapon markers; retire them before
	# deferred component discovery. All direct fire methods are also inert.
	_muzzle_left.free()
	_muzzle_right.free()
	_muzzle_left = null
	_muzzle_right = null
	_boarding_entry_marker = Marker3D.new()
	_boarding_entry_marker.name = "BoardingEntry"
	_boarding_entry_marker.position = Vector3(1,1,-5.5)
	_cockpit_root.add_child(_boarding_entry_marker)
	_boarding_marker.position = Vector3(1,1,-5.5)
	_exit_marker.position = Vector3(1,1,-5.5)
	_camera_pivot.position = Vector3(0,3,0)
	_install_variant_cockpit_system_readout(_visual_root)
	_cockpit_readout.position = Vector3(0,2.75,-6.6)
	var receiver := Marker3D.new()
	receiver.name = "DockingReceiver"
	receiver.position = Vector3(0,2.5,1.5)
	add_child(receiver)
	_canopy_pivot = Node3D.new()
	_canopy_pivot.name = "AccessMotionClock"
	_solid_root.add_child(_canopy_pivot)
	_build_ramp_leaf("InnerSternRamp",accent)
	_build_ramp_leaf("OuterSternRamp",accent)
	_set_canopy_open_fraction(0)
	var panel := MeshInstance3D.new()
	panel.name = "SternAccessControl"
	var panel_shape := BoxMesh.new()
	panel_shape.size = Vector3(0.3,0.3,0.006)
	panel.mesh = panel_shape
	panel.position = Vector3(2.29,1.6,7.985)
	panel.material_override = accent
	_solid_root.add_child(panel)
	ShipCabinHatch.install(_solid_root,self,Vector3(2.29,1.6,7.985))
	_sync_engine_visuals_immediately()


## Preserve inherited hide/restore presentation behavior for the stable shell.
func _sync_solid_root_visibility() -> void:
	if is_instance_valid(_solid_root) and is_instance_valid(_visual_root):
		_solid_root.visible = _visual_root.visible


## A noncolliding light surface sits just aft of each solid exhaust panel.
## Only these overlays participate in inherited engine visibility changes.
func _build_exhaust_glow(label: String, center_x: float) -> void:
	var glow := MeshInstance3D.new()
	glow.name = label + "ExhaustGlow"
	glow.set_meta("presentation_only", true)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.9, 0.14)
	glow.mesh = quad
	glow.position = Vector3(center_x, 3.5, 6.002)
	var material := _finish(Color("60cbd1"), 0.2)
	material.emission_enabled = true
	material.emission = Color("60cbd1")
	material.emission_energy_multiplier = 2.0
	glow.material_override = material
	_solid_root.add_child(glow)
	_engine_core_glows.append(glow)


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
	_solid_root.add_child(mesh)
	return mesh


func _build_ramp_leaf(label: String, material: Material) -> void:
	var collision := CollisionShape3D.new()
	collision.name = label+"Collision"
	var shape := ConvexPolygonShape3D.new()
	shape.points = PackedVector3Array(RAMP_POINTS)
	collision.shape = shape
	add_child(collision)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	var center := Vector3(0,-0.1933333333,0.6666666667)
	for face in [[0,1,2],[3,5,4],[0,3,4,1],[1,4,5,2],[2,5,3,0]]:
		for triangle in ([[face[0],face[1],face[2]]] if face.size()==3 else [[face[0],face[1],face[2]],[face[0],face[2],face[3]]]):
			var a: Vector3 = RAMP_POINTS[triangle[0]]
			var b: Vector3 = RAMP_POINTS[triangle[1]]
			var c: Vector3 = RAMP_POINTS[triangle[2]]
			if (b-a).cross(c-a).dot(a-center)>0:
				var swap := b
				b = c
				c = swap
			surface.add_vertex(a)
			surface.add_vertex(b)
			surface.add_vertex(c)
	surface.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.name = label
	mesh.mesh = surface.commit()
	_solid_root.add_child(mesh)
