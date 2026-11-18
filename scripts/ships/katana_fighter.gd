extends HeroShip

## Original modern Katana: physical port access and one pilot.
## Main fits one adopted pilot pulse; no travelling interior is fitted.
## Editable convex sections use metres, +Y up and -Z forward.
@export var pilot_weapon_fitted := false
const FUTURE_ENTRY := Vector3(-0.9,0.6,0)
const CENTER_MUZZLE := Vector3(0,1,-6.2)
const PILOT_ORIGIN := Vector3(0, 0.55, -1)
const RESERVED_RECESS := AABB(Vector3(-1.5, 0.6, -2), Vector3(3, 2.9, 4.5))
var _access_leaves: Array[Dictionary] = []
var _access_fraction := 0.0
var _original_shell: Node3D
var _primary_emission_pending := false
var _primary_emission_origin := Vector3.INF
var _primary_emission_direction := Vector3.ZERO


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
		# Stow outside the sill; slide above the inner leaf, then lower only
		# after the inner leaf extends and their footprints meet at one edge.
		var slide := clampf(fraction / 0.6, 0.0, 1.0)
		var lower := clampf((fraction - 0.8) / 0.2, 0.0, 1.0)
		var offset := Vector3(2.1 * (1.0 - slide), 0.5 * (1.0 - lower), 0)
		for point in leaf.open:
			points.append(point + offset)
	elif leaf.mesh.name == &"PortRamp1":
		# Hold clear of the descending sill until its top is below the wedge.
		var extend := clampf((fraction - 0.6) / 0.2, 0.0, 1.0)
		for point in leaf.open:
			points.append(point + Vector3(-0.15 * (1.0 - extend), 0, 0))
	else:
		var phase := clampf(fraction / 0.6, 0.0, 1.0) if leaf.mesh.name == &"PortSill" else fraction
		for i in leaf.closed.size():
			points.append((leaf.closed[i] as Vector3).lerp(leaf.open[i], phase))
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
	_original_shell.add_child(mesh)
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
	_original_shell.add_child(_canopy_pivot)
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
				closed[i] += Vector3(2.1,0.5,0)
		else:
			for i in closed.size():
				closed[i] += Vector3(-0.15,0,0)
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
	return pilot_weapon_fitted


func get_variant_visual_root() -> Node3D:
	return _original_shell


func _uses_weapon_component_fallback_emitters() -> bool:
	return false


func _get_weapon_targeting_distance() -> float:
	return 480.0 * lerpf(FAILED_SENSOR_MANUAL_AIM_DISTANCE_FACTOR,1.0,_get_damage_targeting_multiplier())


## Pilot fire belongs to the actual physical seat reservation, independently
## of the active craft pointer or a caller setting the piloted flag.
func get_primary_pilot_claim_is_current() -> bool:
	if not pilot_weapon_fitted or not is_inside_tree() or is_queued_for_deletion() or _destroyed or _hull <= 0.0 \
			or not _piloted or _remote_piloted or _canopy_open or _access_fraction > 0.0001:
		return false
	var area := get_node_or_null("ShipBoardingArea") as ShipBoardingArea
	var actor := area.get_reservation_token() as PlayerController if area != null else null
	return is_instance_valid(actor) and actor.is_inside_tree() and not actor.is_queued_for_deletion() \
		and actor.is_seated_at(get_pilot_seat_anchor()) and not actor.is_station_seated() \
		and not actor.has_meta(SOLO_CREW_ROLE_OCCUPANT_META)


func _get_weapon_unavailable_reason(modifiers: Dictionary = {}) -> StringName:
	if not get_primary_pilot_claim_is_current():
		return &"primary_pilot_required"
	return super._get_weapon_unavailable_reason(modifiers)


## Keep HeroShip's exact cooldown, inherited heat and camera convergence. The
## only new capability is one synchronous, single-use current-pilot emission.
func _fire_weapon_with_aim(crew_origin: Vector3 = Vector3.INF, crew_direction: Vector3 = Vector3.ZERO) -> void:
	# Crew aiming and synthetic callbacks cannot mint a pilot emission.
	if crew_origin != Vector3.INF or crew_direction != Vector3.ZERO or _primary_emission_pending \
			or not get_primary_pilot_claim_is_current():
		return
	var modifiers := get_operational_modifiers()
	var fire_power := _get_damage_weapon_multiplier()
	if not bool(get_weapon_fire_status().get("ready", false)):
		return
	_weapon_timer = weapon_cooldown / fire_power
	_weapon_heat = clampf(_weapon_heat + WEAPON_HEAT_PER_SHOT, 0.0, 1.0)
	if _weapon_heat >= 1.0:
		_weapon_overheated = true
		_weapon_overheat_remaining = WEAPON_OVERHEAT_DURATION
	var muzzle := _muzzle_left if _fire_from_left else _muzzle_right
	_fire_from_left = not _fire_from_left
	var aiming_camera := get_camera()
	var screen_center := aiming_camera.get_viewport().get_visible_rect().size * 0.5
	var camera_direction := aiming_camera.project_ray_normal(screen_center).normalized()
	var ray_origin := aiming_camera.global_position
	if crew_origin.is_finite() and crew_direction.is_finite() and not crew_direction.is_zero_approx():
		ray_origin = crew_origin
		camera_direction = crew_direction.normalized()
	var targeting_distance := _get_weapon_targeting_distance()
	var ray_end := ray_origin + camera_direction * targeting_distance
	var convergence_point := ray_end
	# Resolve the reticle ray first so both offset cannons converge exactly on
	# nearby geometry and range drones. Damage remains owned by game_flow.gd;
	# this query only corrects the emitted direction.
	if is_inside_tree() and not bool(modifiers.get("targeting_disabled", false)):
		var exclusions: Array[RID] = [get_rid()]
		if crew_origin.is_finite():
			for child in find_children("*", "CollisionObject3D", true, false):
				exclusions.append((child as CollisionObject3D).get_rid())
		var query := PhysicsRayQueryParameters3D.create(
			ray_origin,
			ray_end,
			WEAPON_AIM_MASK,
			exclusions
		)
		query.collide_with_areas = true
		query.collide_with_bodies = true
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			convergence_point = hit.get("position", ray_end)
	var aimed_direction := (convergence_point - muzzle.global_position).normalized()
	_primary_emission_origin = muzzle.global_position
	_primary_emission_direction = aimed_direction
	_primary_emission_pending = true
	projectile_fired.emit(_primary_emission_origin, _primary_emission_direction)
	_primary_emission_pending = false
	_primary_emission_origin = Vector3.INF
	_primary_emission_direction = Vector3.ZERO



func consume_primary_emission(origin: Vector3, direction: Vector3) -> bool:
	if not _primary_emission_pending or not get_primary_pilot_claim_is_current() \
			or origin != _primary_emission_origin or direction != _primary_emission_direction:
		return false
	_primary_emission_pending = false
	return true


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
	# Authored solids remain in the exact collision frame. Cosmetic bank owns
	# a separate presentation root, as on the other physical pilot prefabs.
	_original_shell = Node3D.new()
	_original_shell.name = "KatanaOriginalShell"
	add_child(_original_shell)
	_visual_root = Node3D.new()
	_visual_root.name = "KatanaPilotPresentation"
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
	# The deployed sill top is .5, below the ramp's .508..52 underside here.
	_sliding_box("PortSill", -1.6,-1.5,-2,2.5,0.6,1.0,-0.5,armor)
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
	_original_shell.add_child(_cockpit_root)
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
	_original_shell.add_child(mesh)
	return mesh
