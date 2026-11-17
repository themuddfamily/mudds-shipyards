class_name UtopiaDropship
extends HeroShip

## Original modern Utopia pilot foundation; A3 supplies only the name and role.
## Metres, +Y up, -Z forward. Supported landed stern access is physical;
## one ordinary helm and two local passenger chairs are fitted in Main only.
const WEAPON := preload("res://assets/weapons/jovian_combat_pulse.tres")
const DEFINITION := preload("res://assets/ships/utopia_provisional.tres")
const HULL_BOUNDS := AABB(Vector3(-4.5, 0.0, -8.5), Vector3(9.0, 4.8, 17.0))
const PILOT_FEET := Vector3(0.0, 0.8, -5.8)
const PILOT_EYE := Vector3(0.0, 2.56, -6.05)
const FUTURE_ENTRY := Vector3(0.8, 0.8, -5.8)
const RAMP_STOW_ANGLE := -PI / 2.0 - atan(0.8 / 4.5)
const ACCESS_MOTION_SECONDS := 1.2
@export var local_passenger_chairs_fitted := false
const CREW_FRAME_ID := &"utopia_local_chair_frame"
const CREW_IDS := [&"passenger_port_00", &"passenger_starboard_00"]
const CREW_POSITIONS := [Vector3(-2,0.8,-3.6), Vector3(2,0.8,-3.6)]
const CREW_STANDS := [Vector3(-0.7,0.8,-3.6), Vector3(0.7,0.8,-3.6)]
const LOCAL_CABIN := AABB(Vector3(-2.9,0.8,-6.8),Vector3(5.8,3.8,14.3))
var _crew_anchors: Array[Marker3D] = []
var _crew_role_authority: CrewSeatRoleAuthority
var _interior_frame: MovingInteriorFrame
var _original_shell: Node3D
var _access_leaves: Array[Dictionary] = []
var _access_fraction := 0.0


func _init() -> void:
	ship_definition = DEFINITION
	cockpit_camera_position = PILOT_EYE


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


func get_weapon_definition() -> WeaponDefinition:
	return WEAPON


func is_boardable() -> bool:
	return super.is_boardable() and is_access_supported() and _access_fraction > 0.999 and not is_access_motion_active()


func _uses_torrent_reconstruction_presentation() -> bool:
	return false


func get_variant_visual_root() -> Node3D:
	return _original_shell


func _uses_weapon_component_fallback_emitters() -> bool:
	# The logical muzzle sits 0.2m beyond the nose; no physical fitting does.
	return false


func _get_weapon_targeting_distance() -> float:
	return 650.0 * lerpf(FAILED_SENSOR_MANUAL_AIM_DISTANCE_FACTOR, 1.0,
		_get_damage_targeting_multiplier())


func _wake_engine_for_automatic_demand(release_dock_latch: bool = true) -> void:
	# Demand must traverse the same timed OFFLINE -> STARTING -> ONLINE edges
	# as an explicit start. A held command never restarts the spool timer.
	if _engine_state != ENGINE_OFFLINE or _destroyed or _hull <= 0.0:
		return
	var retained_latch := _docked_latch
	request_engine_start()
	if not release_dock_latch:
		_docked_latch = retained_latch


func _build_ship() -> void:
	if _built:
		return
	_built = true
	collision_layer = PhysicsLayers.SHIP_BODY_LAYER
	collision_mask = PhysicsLayers.SHIP_BODY_MASK
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	floor_stop_on_slope = false
	_original_shell = Node3D.new()
	_original_shell.name = "UtopiaOriginalShell"
	_original_shell.set_meta("design_origin", &"original_modern_interpretation")
	_original_shell.set_meta("name_to_model_status", &"unknown")
	add_child(_original_shell)
	# Keep solid shell and root collision in the same physical frame. The common
	# visual bank is reserved for the non-solid cockpit presentation hierarchy.
	_visual_root = Node3D.new()
	_visual_root.name = "UtopiaPilotPresentation"
	add_child(_visual_root)
	_cockpit_root = Node3D.new()
	_cockpit_root.name = "CockpitInterior"
	_visual_root.add_child(_cockpit_root)
	var cream := _shell_material(Color("e7dfca"), 0.30, 0.62)
	var orange := _shell_material(Color("f46e24"), 0.22, 0.56)
	var glass := _shell_material(Color(0.12, 0.30, 0.34, 0.16), 0.12, 0.18)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# All sections are convex and meet only at faces/edges. No enclosing cabin
	# collider exists: the full reserved hold is genuinely hollow above y=.8.
	_add_section_box("CargoDeck", Vector3(-3.1, 0, -7), Vector3(3.1, 0.8, 8), cream)
	_add_section_box("CargoCrown", Vector3(-3.1, 4.6, -7), Vector3(3.1, 4.8, 8.5), cream)
	_add_section_box("PortCargoWall", Vector3(-3.1, 0.8, -6.8), Vector3(-2.9, 4.6, 7.5), cream)
	_add_section_box("StarboardCargoWall", Vector3(2.9, 0.8, -6.8), Vector3(3.1, 4.6, 7.5), cream)
	_add_section_box("BowSill", Vector3(-3.1, 0.8, -7), Vector3(3.1, 1.6, -6.8), orange)
	_add_section_box("BowWindshield", Vector3(-3.1, 1.6, -7), Vector3(3.1, 4.6, -6.8), glass)
	_add_section_box("PortSternCheek", Vector3(-3.1, 0.8, 7.5), Vector3(-1.2, 4.6, 8.5), cream)
	_add_section_box("StarboardSternCheek", Vector3(1.2, 0.8, 7.5), Vector3(3.1, 4.6, 8.5), cream)
	_add_section_box("SternHeader", Vector3(-1.2, 3.2, 7.5), Vector3(1.2, 4.6, 8.5), cream)
	_add_section_box("PortAftLiftHousing", Vector3(-4.5, 0, 4), Vector3(-3.1, 2.2, 8.5), orange)
	_add_section_box("StarboardAftLiftHousing", Vector3(3.1, 0, 4), Vector3(4.5, 2.2, 8.5), orange)
	_build_stern_access(orange)
	_add_nose_wedge(cream)
	# Activate the adopted feet-frame helm. Fitted chair solids remain a later
	# craft gate; this physical stand and the full centre aisle stay unchanged.
	_pilot_seat_anchor = _reservation_marker("pilot_station", PILOT_FEET, self)
	_pilot_seat_anchor.set_meta("reservation_only", false)
	_pilot_seat_anchor.set_meta("station_id", &"pilot_station")
	_boarding_entry_marker = _reservation_marker("HelmStand", FUTURE_ENTRY, self)
	_reservation_marker("DockingReceiver", Vector3.ZERO, self)
	var racks := Node3D.new()
	racks.name = "FutureRackReservations"
	racks.set_meta("reservation_only", true)
	add_child(racks)
	for side in [-1.0, 1.0]:
		for index in range(4):
			_reservation_marker("%sRack%02d" % ["Port" if side < 0 else "Starboard", index],
				Vector3(side * 2.0, 0.8, -1.2 + index * 2.0), racks)
	# Reuse only the common functional camera rig, then replace its temporary
	# logical gun markers. Neither camera rig nor markers grant boarding access.
	_build_markers_and_camera()
	_muzzle_left.free()
	_muzzle_right.free()
	_muzzle_left = _reservation_marker("CenterMuzzle", Vector3(0, 1.5, -8.7), self)
	_muzzle_left.set_meta("reservation_only", false)
	_muzzle_right = _muzzle_left
	_boarding_marker.position = FUTURE_ENTRY
	_exit_marker.position = FUTURE_ENTRY
	var boarding := ShipBoardingArea.new()
	boarding.name = "ShipBoardingArea"
	boarding.prompt_text = "[ E ]  BOARD UTOPIA CANDIDATE"
	boarding.position = FUTURE_ENTRY
	add_child(boarding)
	var interaction := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.22
	interaction.shape = sphere
	boarding.add_child(interaction)
	_camera_pivot.position = Vector3(0, 5.4, 3.5)
	_cockpit_camera.reparent(self, false)
	_cockpit_camera.position = PILOT_EYE
	var status := _install_variant_cockpit_system_readout(_cockpit_root)
	status.position = Vector3(0, 1.7, -6.65)
	status.font_size = 30
	status.pixel_size = 0.0012
	if local_passenger_chairs_fitted:
		_build_local_passenger_chairs(cream, orange)
	# Cargo reservations remain inert; no travelling cabin is granted.
	_canopy_open = false


func _shell_material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material


func _reservation_marker(node_name: String, pose: Vector3, parent: Node) -> Marker3D:
	var marker := Marker3D.new()
	marker.name = node_name
	marker.position = pose
	marker.set_meta("reservation_only", true)
	parent.add_child(marker)
	return marker


func _add_section_box(section_name: String, low: Vector3, high: Vector3, material: Material) -> void:
	var box := BoxMesh.new()
	box.size = high - low
	box.material = material
	var points := PackedVector3Array()
	for x in [-0.5, 0.5]:
		for y in [-0.5, 0.5]:
			for z in [-0.5, 0.5]:
				points.append(Vector3(x, y, z) * box.size)
	_install_section(section_name, (low + high) * 0.5, box, points)


func _install_section(section_name: String, origin: Vector3, mesh: Mesh, points: PackedVector3Array) -> void:
	var visual := MeshInstance3D.new()
	visual.name = section_name
	visual.position = origin
	visual.mesh = mesh
	_original_shell.add_child(visual)
	var collider := CollisionShape3D.new()
	collider.name = section_name + "Collision"
	collider.position = origin
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	collider.shape = shape
	add_child(collider)


func _add_nose_wedge(material: Material) -> void:
	# Broad, low bow tapers in both height and width towards the nose. Its
	# upper surface stays below the fixed pilot eye and its forward sightline.
	var points := PackedVector3Array([
		Vector3(-4.2, 0, -8.5), Vector3(4.2, 0, -8.5),
		Vector3(4.2, 0.6, -8.5), Vector3(-4.2, 0.6, -8.5),
		Vector3(-4.5, 0, -7), Vector3(4.5, 0, -7),
		Vector3(4.5, 1.6, -7), Vector3(-4.5, 1.6, -7),
	])
	var centre := Vector3(0, 0.55, -7.75)
	var faces := [[0, 1, 2, 3], [4, 7, 6, 5], [0, 4, 5, 1],
		[3, 2, 6, 7], [0, 3, 7, 4], [1, 5, 6, 2]]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	for face: Array in faces:
		var a := points[int(face[0])]
		var b := points[int(face[1])]
		var c := points[int(face[2])]
		var normal := (b - a).cross(c - a).normalized()
		if normal.dot((a + b + c) / 3.0 - centre) < 0:
			normal = -normal
		# Godot's front-facing winding is clockwise when viewed from outside;
		# keep explicit outward vertex normals independent of index winding.
		var order := face.duplicate()
		if (b - a).cross(c - a).dot(normal) > 0:
			order.reverse()
		for triangle: Array in [[order[0], order[1], order[2]], [order[0], order[2], order[3]]]:
			for index: int in triangle:
				surface.set_normal(normal)
				surface.add_vertex(points[index])
	_install_section("BroadWedgeNose", Vector3.ZERO, surface.commit(), points)


func _has_access_deck_support() -> bool:
	if not is_inside_tree(): return false
	for point in [Vector3.ZERO, Vector3(-1.15, 0, 12.5), Vector3(1.15, 0, 12.5), Vector3(-3.4, 0, 10.1)]:
		var origin := to_global(point)
		var query := PhysicsRayQueryParameters3D.create(origin + global_basis.y * 0.1,
			origin - global_basis.y * 0.2, PhysicsLayers.WORLD | PhysicsLayers.SHIP)
		query.exclude = [get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or (hit.normal as Vector3).dot(global_basis.y) <= 0.95: return false
	return true


func is_access_motion_active() -> bool:
	return _canopy_tween != null and _canopy_tween.is_valid()


func is_access_supported() -> bool:
	return not _destroyed and not _landing_active and _landed and velocity.length() < 0.01 \
		and _engine_state == ENGINE_OFFLINE and _has_access_deck_support()


func set_canopy_open(open: bool, duration: float = ACCESS_MOTION_SECONDS) -> void:
	if is_access_motion_active() or (open and not is_access_supported()): return
	# Local-only chairs must retain their supported exit until the guest stands.
	if not open and _crew_role_authority != null and not (_crew_role_authority.get_snapshot().get("assignments",[]) as Array).is_empty(): return
	# The common physical control requests .35s; the complete five-piece
	# mechanism needs its authored minimum, including when operated by Player.
	super.set_canopy_open(open, maxf(duration, ACCESS_MOTION_SECONDS))


func _access_blocks_propulsion() -> bool:
	return _canopy_open or _access_fraction > 0.0 or is_access_motion_active()


func request_engine_start() -> void:
	if not _access_blocks_propulsion(): super.request_engine_start()


func _sample_ship_command() -> ShipCommand:
	var command := super._sample_ship_command()
	return _neutralized_command_snapshot(command) if _access_blocks_propulsion() else command


func _set_canopy_open_fraction(open_fraction: float) -> void:
	super._set_canopy_open_fraction(open_fraction)
	_access_fraction = clampf(open_fraction, 0, 1)
	for leaf in _access_leaves:
		var points := _access_leaf_points(leaf, _access_fraction)
		(leaf.collision.shape as ConvexPolygonShape3D).points = points
		leaf.mesh.mesh = _access_mesh(points, leaf.material)


func _phase(fraction: float, start: float, finish: float) -> float:
	return clampf((fraction - start) / (finish - start), 0, 1)


func _access_leaf_points(leaf: Dictionary, fraction: float) -> PackedVector3Array:
	if leaf.has("ramp_index"):
		return _ramp_points(leaf.ramp_index, leaf.open, fraction)
	var points := PackedVector3Array()
	# Clear the jambs aft before sliding the two rigid halves sideways.
	var offset := Vector3(float(leaf.side) * 1.2 * _phase(fraction, 0.08, 0.16),
		0, 0.3 * _phase(fraction, 0, 0.08))
	for point in leaf.closed: points.append(point + offset)
	return points


func _ramp_points(index: int, opened: PackedVector3Array, fraction: float) -> PackedVector3Array:
	var original_front := Vector3(0, 0.8 - index * (0.8 / 3.0), 8 + index * 1.5)
	# Outside first: the still-stowed neighbouring leaves cannot obstruct a
	# travelling leaf. The same scalar trajectory seals in exact reverse.
	var start := 0.16 + (2 - index) * 0.28
	var angle := RAMP_STOW_ANGLE
	var front := Vector3(0, 0.8, 7.65 + index * 0.15)
	if fraction <= start + 0.04:
		front.y += 0.15 * _phase(fraction, start, start + 0.04)
	elif fraction <= start + 0.12:
		front.y = 0.95
		front.z = lerpf(front.z, original_front.z, _phase(fraction, start + 0.04, start + 0.12))
	elif fraction <= start + 0.16:
		front = Vector3(0, lerpf(0.95, original_front.y + 0.15,
			_phase(fraction, start + 0.12, start + 0.16)), original_front.z)
	elif fraction <= start + 0.24:
		angle *= 1 - _phase(fraction, start + 0.16, start + 0.24)
		front = original_front + Vector3.UP * 0.15
	else:
		angle = 0
		front = original_front + Vector3.UP * 0.15 * (1 - _phase(fraction, start + 0.24, start + 0.28))
	var rotation := Basis(Vector3.RIGHT, angle)
	var rotated := PackedVector3Array()
	var maximum_z := -INF
	for point in opened:
		var posed := rotation * (point - original_front)
		rotated.append(posed)
		maximum_z = maxf(maximum_z, posed.z)
	if fraction > start + 0.16 and fraction <= start + 0.24:
		# A leaf's radial reach exceeds its horizontal run during rotation.
		# Bound every real corner, keeping the next leaf's joint unobstructed.
		front.z = minf(original_front.z, original_front.z + 1.5 - maximum_z)
	var points := PackedVector3Array()
	for point in rotated: points.append(point + front)
	return points


func _access_box(left: float, right: float, front: float, rear: float, bottom: float, top: float) -> PackedVector3Array:
	return PackedVector3Array([Vector3(left, bottom, front), Vector3(right, bottom, front),
		Vector3(right, bottom, rear), Vector3(left, bottom, rear), Vector3(left, top, front),
		Vector3(right, top, front), Vector3(right, top, rear), Vector3(left, top, rear)])


func _moving_access_leaf(label: String, closed: PackedVector3Array, opened: PackedVector3Array, material: Material, extra: Dictionary) -> void:
	var collision := CollisionShape3D.new()
	collision.name = label + "Collision"
	var shape := ConvexPolygonShape3D.new()
	shape.points = closed
	collision.shape = shape
	add_child(collision)
	var mesh := MeshInstance3D.new()
	mesh.name = label
	mesh.mesh = _access_mesh(closed, material)
	_original_shell.add_child(mesh)
	var leaf := {"collision":collision, "mesh":mesh, "closed":closed, "open":opened, "material":material}
	leaf.merge(extra)
	_access_leaves.append(leaf)


func _access_mesh(points: PackedVector3Array, material: Material) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	var center := Vector3.ZERO
	for point in points: center += point / float(points.size())
	var triangles := [0,1,2,0,2,3,6,5,4,7,6,4,4,1,0,4,5,1,5,2,1,5,6,2,6,3,2,6,7,3,7,0,3,7,4,0]
	for i in range(0, triangles.size(), 3):
		var a := points[triangles[i]]
		var b := points[triangles[i + 1]]
		var c := points[triangles[i + 2]]
		var normal := (b - a).cross(c - a).normalized()
		if normal.is_zero_approx(): continue
		if normal.dot((a + b + c) / 3.0 - center) < 0: normal = -normal
		for point in ([a, c, b] if (b - a).cross(c - a).dot(normal) > 0 else [a, b, c]):
			surface.set_normal(normal)
			surface.add_vertex(point)
	return surface.commit()


func _build_stern_access(orange: Material) -> void:
	_canopy_pivot = Node3D.new()
	_canopy_pivot.name = "SternAccessMotionAuthority"
	_original_shell.add_child(_canopy_pivot)
	for side in [-1, 1]:
		var closed := _access_box(-1.2 if side < 0 else 0, 0 if side < 0 else 1.2, 8.3, 8.5, 0.8, 3.2)
		_moving_access_leaf("SternPortClosure" if side < 0 else "SternStarboardClosure",
			closed, closed, orange, {"side":side})
	for index in 3:
		var opened := _access_box(-1.2, 1.2, 8 + 1.5 * index, 9.5 + 1.5 * index, 0, 0)
		for i in opened.size(): opened[i].y = (12.5 - opened[i].z) / 4.5 * (0.8 if i >= 4 else 0.72)
		_moving_access_leaf("SternRamp" + str(index), _ramp_points(index, opened, 0),
			opened, orange, {"ramp_index":index})
	_add_section_box("SternPortControlBracket", Vector3(-3.55, 2.2, 8), Vector3(-3.25, 2.4, 8.3), orange)
	ShipCabinHatch.install(self, self, Vector3(-3.4, 2.4, 8.3))


## The existing seat transition requires a frame owner. This manual frame has
## no occupancy sensor; its report opens only at this exact supported home.
func _build_local_passenger_chairs(structure: Material, cushion: Material) -> void:
	for index in 2:
		var point: Vector3 = CREW_POSITIONS[index]
		var label := "PortPassenger" if index == 0 else "StarboardPassenger"
		_add_section_box(label + "Pedestal", point+Vector3(-0.28,0,-0.20),point+Vector3(0.28,0.54,0.26),structure)
		_add_section_box(label + "Cushion", point+Vector3(-0.46,0.54,-0.25),point+Vector3(0.46,0.68,0.42),cushion)
		_add_section_box(label + "Back", point+Vector3(-0.46,0.68,0.42),point+Vector3(0.46,1.62,0.58),structure)
		var anchor := _reservation_marker(String(CREW_IDS[index]),point,self)
		anchor.set_meta("reservation_only",false)
		anchor.set_meta("station_id",CREW_IDS[index])
		anchor.set_meta("crew_role",&"passenger")
		anchor.set_meta("seat_type",&"physical")
		_crew_anchors.append(anchor)
	_interior_frame = MovingInteriorFrame.new()
	_interior_frame.name = "MovingInteriorFrame"
	_interior_frame.auto_register_from_volume = false
	add_child(_interior_frame)
	_interior_frame.configure(self,LOCAL_CABIN)


func is_local_chair_access_supported() -> bool:
	if not local_passenger_chairs_fitted or not is_instance_valid(_interior_frame) \
			or not is_access_supported() or _access_fraction < 0.999 or is_access_motion_active():
		return false
	var game := get_parent() as GameFlow
	if game == null or not is_instance_valid(game.world) or get_home_berth_id() != &"utopia_home_berth":
		return false
	var berth := game.world.get_berth_node(&"utopia_home_berth") as ShipBerth
	return berth != null and berth.get_occupant() == self and berth.get_reservation_owner() == self \
		and global_transform.is_equal_approx(berth.get_dock_transform())


func get_interior_frame() -> MovingInteriorFrame:
	return _interior_frame


func get_in_flight_cabin_report() -> Dictionary:
	return {"supported": is_local_chair_access_supported(), "status": &"local_home_chairs_only",
		"frame": _interior_frame, "local_bounds": LOCAL_CABIN,
		"stand_transform": global_transform*Transform3D(Basis.IDENTITY,FUTURE_ENTRY)}


func get_crew_seat_role_contract(anchor: Marker3D) -> Dictionary:
	var index := _crew_anchors.find(anchor)
	if _destroyed or not local_passenger_chairs_fitted or index < 0 or not is_instance_valid(anchor) \
			or anchor.get_parent() != self or anchor.name != CREW_IDS[index]:
		return {}
	var stand := global_transform*Transform3D(Basis(Vector3.UP,-PI*0.5 if index == 0 else PI*0.5),CREW_STANDS[index])
	return {"role": &"passenger", "vessel_id": get_ship_id(), "seat_id": CREW_IDS[index],
		"seat": anchor, "entry_transform": stand, "exit_transform": stand,
		"frame": _interior_frame, "seat_type": &"physical", "role_label": "Passenger"}


func _install_solo_crew_seat() -> void:
	if not is_inside_tree(): return
	for anchor in _crew_anchors:
		if anchor.get_node_or_null("SoloPassengerSeatInteraction") == null:
			ShipCrewSeat.install(anchor,self)


func _crew_seat_records() -> Array[Dictionary]:
	return [{"seat_id": &"pilot_station", "role": &"pilot", "anchor_id": &"pilot_station"},
		{"seat_id": CREW_IDS[0], "role": &"passenger", "anchor_id": CREW_IDS[0]},
		{"seat_id": CREW_IDS[1], "role": &"passenger", "anchor_id": CREW_IDS[1]}]


func register_crew_seat_roster(authority: CrewSeatRoleAuthority) -> Dictionary:
	if not is_local_chair_access_supported() or authority == null or _crew_anchors.size() != 2:
		return {"accepted": false, "status": &"local_chairs_unavailable"}
	var snapshot := authority.get_snapshot()
	if bool(snapshot.get("roster_sealed",false)) or not (snapshot.get("seats",[]) as Array).is_empty():
		return {"accepted": false, "status": &"utopia_roster_mismatch"}
	for record in _crew_seat_records():
		var result := authority.register_seat(record.seat_id,get_ship_id(),record.role,CREW_FRAME_ID,1,record.anchor_id)
		if not bool(result.get("accepted",false)): return result
	return authority.seal_roster([&"pilot",&"passenger"])


func attach_crew_role_authority(authority: CrewSeatRoleAuthority) -> Dictionary:
	if not is_local_chair_access_supported() or authority == null \
			or (_crew_role_authority != null and _crew_role_authority != authority):
		return {"accepted": false, "status": &"authority_unavailable"}
	var snapshot := authority.get_snapshot()
	var seats: Array = snapshot.get("seats",[])
	if not bool(snapshot.get("roster_sealed",false)) or seats.size() != 3:
		return {"accepted": false, "status": &"utopia_roster_mismatch"}
	for expected in _crew_seat_records():
		var matched := false
		for record: Dictionary in seats:
			if record.get("seat_id") == expected.seat_id and record.get("role") == expected.role \
					and record.get("anchor_id") == expected.anchor_id and record.get("vessel_id") == get_ship_id() \
					and record.get("frame_id") == CREW_FRAME_ID and int(record.get("seat_generation",0)) == 1:
				matched = true
		if not matched: return {"accepted": false, "status": &"utopia_roster_mismatch"}
	_crew_role_authority = authority
	return {"accepted": true, "status": &"authority_attached"}


func detach_crew_role_authority(authority: CrewSeatRoleAuthority) -> bool:
	if authority == null or authority != _crew_role_authority \
			or not (authority.get_snapshot().get("assignments",[]) as Array).is_empty(): return false
	_crew_role_authority = null
	return true


func get_crew_role_authority() -> CrewSeatRoleAuthority:
	return _crew_role_authority


func attach_solo_crew_role_occupant(avatar_id: StringName, seat: ShipCrewSeat, occupant: Node3D) -> Dictionary:
	if not is_local_chair_access_supported() or _reset_for_reuse_mutation_blocked() \
			or _crew_role_authority == null or not is_instance_valid(seat) or seat.get_ship() != self:
		return {"accepted": false, "status": &"occupancy_identity_mismatch"}
	var assignment := _crew_role_authority.get_assignment(1,avatar_id)
	var contract := seat.get_role_contract()
	if contract.is_empty() or assignment.get("vessel_id") != get_ship_id() \
			or assignment.get("seat_id") != contract.get("seat_id") or assignment.get("role") != &"passenger" \
			or assignment.get("frame_id") != CREW_FRAME_ID or assignment.get("anchor_id") != contract.get("seat_id") \
			or int(assignment.get("seat_generation",0)) != 1:
		return {"accepted": false, "status": &"occupancy_identity_mismatch"}
	return super.attach_solo_crew_role_occupant(avatar_id,seat,occupant)


func has_clear_local_chair_stand(actor: PlayerController, seat: ShipCrewSeat) -> bool:
	if not is_local_chair_access_supported() or not is_instance_valid(actor) \
			or not is_instance_valid(seat) or seat.get_ship() != self or seat.get_role_contract().is_empty(): return false
	var collision := actor.get_node_or_null("PlayerCollision") as CollisionShape3D
	if collision == null or not collision.shape is CapsuleShape3D: return false
	var capsule := collision.shape.duplicate() as CapsuleShape3D
	capsule.radius -= 0.005
	capsule.height -= 0.01
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = seat.get_exit_transform()*collision.transform
	query.margin = 0
	query.collision_mask = PhysicsLayers.WORLD | PhysicsLayers.SHIP
	query.exclude = [actor.get_rid()]
	var state := get_world_3d().direct_space_state
	if not state.intersect_shape(query,16).is_empty(): return false
	var feet := seat.get_exit_transform().origin
	var up := global_basis.y.normalized()
	var ray := PhysicsRayQueryParameters3D.create(feet+up*0.06,feet-up*0.06,query.collision_mask,[actor.get_rid()])
	var hit := state.intersect_ray(ray)
	return not hit.is_empty() and hit.collider == self and (hit.normal as Vector3).dot(up) > 0.99
