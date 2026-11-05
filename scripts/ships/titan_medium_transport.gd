extends HeroShip

## Owner-approved original modern shell. Historical evidence supports name/role
## only. Physical fixture access/cabin; no production Main boarding, passenger,
## cargo or combat composition.
## All editable points are metres in ship-local coordinates, -Z forward.
const PILOT_ORIGIN := Vector3(0.0, 0.75, -5.8)
const PILOT_EYE := Vector3(0.0, 2.51, -6.05)
const CABIN_VOID := AABB(Vector3(-2.7, 0.8, -6.8), Vector3(5.4, 2.5, 14.3))
const OUTLINE := [Vector2(-3.8, -9), Vector2(3.8, -9),
	Vector2(4.8, -8), Vector2(4.8, 8), Vector2(3.8, 9),
	Vector2(-3.8, 9), Vector2(-4.8, 8), Vector2(-4.8, -8)]
const INNER := [Vector2(-3.2, -7.4), Vector2(3.2, -7.4),
	Vector2(4.0, -6.6), Vector2(4.0, 7.2), Vector2(3.2, 8),
	Vector2(-3.2, 8), Vector2(-4.0, 7.2), Vector2(-4.0, -6.6)]

const ACCESS_MOTION_SECONDS := 1.2
var _access_fraction := 0.0
var _ramp_hinge: Node3D
var _ramp_toe_hinge: Node3D
var _ramp_first_collision: CollisionShape3D
var _ramp_toe_collision: CollisionShape3D
var _interior_frame: MovingInteriorFrame


## Keep controller ownership: reject unsafe intent before its immutable command
## reaches automatic engine demand, berth departure lift, or flight integration.
func _sample_ship_command() -> ShipCommand:
	var command := super._sample_ship_command()
	if _canopy_open or _access_fraction > 0.0001:
		return _neutralized_command_snapshot(command)
	return command


func request_engine_start() -> void:
	if not _canopy_open and _access_fraction <= 0.0001:
		super.request_engine_start()


## This is exterior access refusal, not Main's pilot/berth exit qualification.
## The ramp needs a level supporting apron at its toe and at the exit marker.
func set_canopy_open(open: bool, duration: float = ACCESS_MOTION_SECONDS) -> void:
	if open and not _has_supported_exterior_access():
		return
	super.set_canopy_open(open, duration)


func _has_supported_exterior_access() -> bool:
	if not is_inside_tree() or _destroyed or not _landed or _landing_active \
			or _engine_state != ENGINE_OFFLINE or velocity.length() > 0.01:
		return false
	var space := get_world_3d().direct_space_state
	for point: Vector3 in [Vector3(-1.15, 0, 13), Vector3(1.15, 0, 13), Vector3(0, 0, 14.5)]:
		var world := global_transform * point
		var up := global_basis.y.normalized()
		var ray := PhysicsRayQueryParameters3D.create(world + up * 0.12, world - up * 0.12,
			PhysicsLayers.WORLD | PhysicsLayers.SHIP, [get_rid()])
		var hit := space.intersect_ray(ray)
		if hit.is_empty() or (hit.normal as Vector3).dot(up) < 0.99 \
				or absf(((hit.position as Vector3) - world).dot(up)) > 0.03:
			return false
	return true


func get_interior_frame() -> MovingInteriorFrame:
	return _interior_frame


func get_in_flight_cabin_report() -> Dictionary:
	var supported := not _destroyed and is_instance_valid(_interior_frame)
	return {"supported": supported, "status": &"walkable_cabin" if supported else &"interior_unavailable",
		"frame": _interior_frame, "stand_transform": get_boarding_entry_transform(),
		"local_bounds": CABIN_VOID}


## The inherited tween remains the sole motion clock. Visuals and both physical
## leaves receive precisely the same rigid transforms at every fraction.
func _set_canopy_open_fraction(open_fraction: float) -> void:
	super._set_canopy_open_fraction(open_fraction)
	_access_fraction = clampf(open_fraction, 0.0, 1.0)
	var hatch_offset := Vector3(0, 3.2 * _access_fraction, 0)
	get_node("ClosedSternBlankCollision").position = hatch_offset
	_visual_root.get_node("ClosedSternBlank").position = hatch_offset
	var folded := 1.0 - _access_fraction
	_ramp_hinge.position = Vector3(0, 0.8, 8 + 0.12 * folded)
	# A quarter turn stores the 2.5m leaf below the y3.3 header; making
	# its sloped diagonal vertical would intrude 3.2cm into that header.
	_ramp_hinge.rotation.x = -PI * 0.5 * smoothstep(0.5, 1.0, folded)
	_ramp_toe_hinge.position = Vector3(0, -0.4 + 0.10 * folded, 2.5)
	_ramp_toe_hinge.rotation.x = -PI * smoothstep(0.0, 0.5, folded)
	_ramp_first_collision.transform = _ramp_hinge.transform
	_ramp_toe_collision.transform = _ramp_hinge.transform * _ramp_toe_hinge.transform


func _uses_torrent_reconstruction_presentation() -> bool:
	return false


func _uses_inherited_primary_weapon() -> bool:
	return false


func _fire_weapon() -> void:
	# Combat is a later, separately accepted production integration child.
	pass


func _build_ship() -> void:
	if _built:
		return
	_built = true
	collision_layer = PhysicsLayers.SHIP_BODY_LAYER
	collision_mask = PhysicsLayers.SHIP_BODY_MASK
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	floor_stop_on_slope = false
	set_meta("authenticated_historical_silhouette", false)
	set_meta("geometry_status", &"original_modern_candidate")
	_visual_root = Node3D.new()
	_visual_root.name = "TitanOriginalShell"
	add_child(_visual_root)
	var skin := _finish(Color("879b9f"), 0.65)
	var structure := _finish(Color("263b49"), 0.8)
	var stripe := _finish(Color("d4a557"), 0.5)
	var glass := _finish(Color(0.16, 0.45, 0.52, 0.35), 0.15)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Split the stern deck around the true descending ramp, with no flat lip
	# under z8..9. Split the roof around the vertical hatch's real slider slot.
	_prism("LowerDeck", [OUTLINE[0], OUTLINE[1], OUTLINE[2], Vector2(4.8, 8), Vector2(-4.8, 8), OUTLINE[7]], 0.0, 0.8, structure)
	_prism("ChamferedRoof", [OUTLINE[0], OUTLINE[1], OUTLINE[2], Vector2(4.8, 7.8), Vector2(-4.8, 7.8), OUTLINE[7]], 4.5, 5.0, skin)
	for side in [-1.0, 1.0]:
		var label := "Port" if side < 0 else "Starboard"
		_prism(label + "SternDeck", [Vector2(side * 1.2, 8), Vector2(side * 4.8, 8), Vector2(side * 3.8, 9), Vector2(side * 1.2, 9)], 0, 0.8, structure)
		_prism(label + "SliderSlotRoof", [Vector2(side * 1.2, 7.8), Vector2(side * 4.8, 7.8), Vector2(side * 4.8, 8), Vector2(side * 3.8, 9), Vector2(side * 1.2, 9)], 4.5, 5, skin)
	_prism("AftSliderSlotRoof", [Vector2(-1.2, 8), Vector2(1.2, 8), Vector2(1.2, 9), Vector2(-1.2, 9)], 4.5, 5, skin)
	for edge in range(1, 8):
		if edge == 4:
			# Recessed stern closure is at z=8, with side cheeks reaching z=9.
			_prism("PortVestibuleCheek", [Vector2(-3.8, 9), Vector2(-1.2, 9), Vector2(-1.2, 8), Vector2(-3.2, 8)], 0.8, 4.5, skin)
			_prism("StarboardVestibuleCheek", [Vector2(1.2, 9), Vector2(3.8, 9), Vector2(3.2, 8), Vector2(1.2, 8)], 0.8, 4.5, skin)
			_prism("SternHeader", [Vector2(-1.2, 8), Vector2(1.2, 8), Vector2(1.2, 9), Vector2(-1.2, 9)], 3.3, 4.5, structure)
		else:
			var next := (edge + 1) % 8
			_prism("ShellPanel%d" % edge, [OUTLINE[edge], OUTLINE[next], INNER[next], INNER[edge]], 0.8, 4.5, skin)
	var nose := [OUTLINE[0], OUTLINE[1], INNER[1], INNER[0]]
	_prism("NoseSill", nose, 0.8, 1.7, structure)
	_prism("ForwardGlazing", nose, 1.7, 3.6, glass)
	_prism("NoseCrown", nose, 3.6, 4.5, skin)
	_prism("ClosedSternBlank", [Vector2(-1.2, 7.8), Vector2(1.2, 7.8), Vector2(1.2, 8), Vector2(-1.2, 8)], 0.8, 3.3, stripe)
	for side in [-1.0, 1.0]:
		var label := "Port" if side < 0.0 else "Starboard"
		_prism(label + "EngineBox", [Vector2(side * 4.8, 1.5), Vector2(side * 6, 1.5), Vector2(side * 6, 6.5), Vector2(side * 4.8, 6.5)], 1.1, 3.2, structure)
		var glow := MeshInstance3D.new()
		glow.name = label + "EngineCore"
		var core := BoxMesh.new()
		core.size = Vector3(0.85, 0.8, 0.03)
		glow.mesh = core
		glow.position = Vector3(side * 5.4, 2.15, 6.52)
		var glow_material := _finish(Color("65dce5"), 0.3)
		glow_material.emission_enabled = true
		glow_material.emission = Color("65dce5")
		glow.material_override = glow_material
		_visual_root.add_child(glow)
		_engine_core_glows.append(glow)
	_cockpit_root = Node3D.new()
	_cockpit_root.name = "PilotFixture"
	_visual_root.add_child(_cockpit_root)
	_pilot_seat_anchor = Marker3D.new()
	_pilot_seat_anchor.name = "pilot_station"
	_pilot_seat_anchor.position = PILOT_ORIGIN
	_pilot_seat_anchor.set_meta("crew_role", &"pilot")
	_pilot_seat_anchor.set_meta("seat_type", &"physical")
	_cockpit_root.add_child(_pilot_seat_anchor)
	# Reuse camera mechanics and expose the real access/helm approach markers.
	# Main boarding and berth registration remain later composition work.
	_build_markers_and_camera()
	_boarding_marker.position = Vector3(1.9, 0.8, 8.98)
	_exit_marker.position = Vector3(0, 0, 14.5)
	_muzzle_left.position = Vector3(0, 1.1, -8.9)
	_muzzle_right.position = _muzzle_left.position
	_camera_pivot.position = Vector3(0, 3.0, 1.0)
	_boarding_entry_marker = Marker3D.new()
	_boarding_entry_marker.name = "PilotApproach"
	_boarding_entry_marker.position = Vector3(0, 0.8, -4.2)
	_cockpit_root.add_child(_boarding_entry_marker)
	_build_access_ramp(structure)
	# A real canopy pivot lets the inherited motion clock and completion signal
	# drive this variant without building any fighter canopy geometry.
	_canopy_pivot = Node3D.new()
	_canopy_pivot.name = "AccessMotionClock"
	_visual_root.add_child(_canopy_pivot)
	_set_canopy_open_fraction(0.0)
	_interior_frame = MovingInteriorFrame.new()
	_interior_frame.name = "MovingInteriorFrame"
	var volume := Area3D.new()
	volume.name = "CabinOccupancy"
	volume.collision_layer = 0
	volume.collision_mask = PhysicsLayers.PLAYER
	volume.position = CABIN_VOID.get_center()
	var volume_collision := CollisionShape3D.new()
	var volume_shape := BoxShape3D.new()
	volume_shape.size = CABIN_VOID.size
	volume_collision.shape = volume_shape
	volume.add_child(volume_collision)
	add_child(volume)
	add_child(_interior_frame)
	_interior_frame.configure(self, CABIN_VOID, volume)
	_interior_frame.occupant_registered.connect(_on_cabin_occupancy_changed)
	_interior_frame.occupant_unregistered.connect(_on_cabin_occupancy_changed)
	var panel := MeshInstance3D.new()
	panel.name = "SternAccessControl"
	var panel_mesh := BoxMesh.new()
	panel_mesh.size = Vector3(0.32, 0.32, 0.006)
	panel.mesh = panel_mesh
	panel.material_override = stripe
	panel.position = Vector3(1.9, 1.6, 8.997)
	_visual_root.add_child(panel)
	ShipCabinHatch.install(_visual_root, self, Vector3(1.9, 1.6, 8.98))
	_sync_engine_visuals_immediately()


func _finish(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = 0.25
	return material


## One convex prism owns matching visible triangles and physical collision.
## Independent pieces meet at faces; none spans the reserved cabin volume.
func _prism(label: String, footprint: Array, bottom: float, top: float, material: Material) -> void:
	var polygon := PackedVector2Array(footprint)
	if Geometry2D.is_polygon_clockwise(polygon):
		polygon.reverse()
	var points := PackedVector3Array()
	for height in [bottom, top]:
		for point in polygon:
			points.append(Vector3(point.x, height, point.y))
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	var collider := CollisionShape3D.new()
	collider.name = label + "Collision"
	collider.shape = shape
	add_child(collider)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	var triangles := Geometry2D.triangulate_polygon(polygon)
	var count := polygon.size()
	for i in range(0, triangles.size(), 3):
		for index in [triangles[i + 2], triangles[i + 1], triangles[i]]:
			surface.add_vertex(points[index])
		for index in [triangles[i], triangles[i + 1], triangles[i + 2]]:
			surface.add_vertex(points[index + count])
	for i in range(count):
		var next := (i + 1) % count
		for index in [i, next, i + count, next, next + count, i + count]:
			surface.add_vertex(points[index])
	surface.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.name = label
	mesh.mesh = surface.commit()
	_visual_root.add_child(mesh)


func _build_access_ramp(material: Material) -> void:
	_ramp_hinge = Node3D.new()
	_ramp_hinge.name = "SternRampHinge"
	_visual_root.add_child(_ramp_hinge)
	_ramp_toe_hinge = Node3D.new()
	_ramp_toe_hinge.name = "RampToeHinge"
	_ramp_hinge.add_child(_ramp_toe_hinge)
	_ramp_first_collision = _ramp_leaf("SternRampFirst", _ramp_hinge, 0.08, material)
	_ramp_toe_collision = _ramp_leaf("SternRampToe", _ramp_toe_hinge, 0.0, material)


func _ramp_leaf(label: String, parent: Node3D, toe_depth: float, material: Material) -> CollisionShape3D:
	# Both leaves descend 0.4m across 2.5m. The last leaf tapers exactly
	# to the apron plane, so neither visual nor collision protrudes below y0.
	var points := PackedVector3Array([
		Vector3(-1.2, 0, 0), Vector3(1.2, 0, 0),
		Vector3(1.2, -0.4, 2.5), Vector3(-1.2, -0.4, 2.5),
		Vector3(-1.2, -0.08, 0), Vector3(1.2, -0.08, 0),
		Vector3(1.2, -0.4 - toe_depth, 2.5), Vector3(-1.2, -0.4 - toe_depth, 2.5)])
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	var collision := CollisionShape3D.new()
	collision.name = label + "Collision"
	collision.shape = shape
	add_child(collision)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	for face in [[0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4], [3, 7, 6, 2], [0, 4, 7, 3], [1, 2, 6, 5]]:
		for index in [face[0], face[1], face[2], face[0], face[2], face[3]]:
			surface.add_vertex(points[index])
	surface.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.name = label
	mesh.mesh = surface.commit()
	parent.add_child(mesh)
	return collision


## Use the established large-craft policy: its own carried walkers must not
## become obstacles to the hull's move_and_slide(). Their capsules still mask
## Ship and continue colliding with the physical deck and cabin walls.
func _on_cabin_occupancy_changed(_occupant: Node3D, _exit_velocity: Vector3 = Vector3.ZERO, _reason: StringName = &"") -> void:
	if not _destroyed:
		collision_mask = PhysicsLayers.SHIP_BODY_MASK & ~PhysicsLayers.PLAYER \
			if _interior_frame.get_occupant_count() > 0 else PhysicsLayers.SHIP_BODY_MASK
