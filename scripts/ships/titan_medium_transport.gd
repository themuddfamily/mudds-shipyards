extends HeroShip

## Owner-approved original modern shell. Historical evidence supports name/role
## only. Physical Main pilot/access/cabin and two ordinary passenger chairs;
## cargo and combat compose through Main; network qualification remains open.
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


## This original transport's sections sit on its actual nose, side-engine
## boxes, roof core and aft header. Keep the inherited ledger, stage curve,
## radii and repair owner; only the physical placement and nose binding differ.
class TitanComponentDamage:
	extends ShipComponentDamage

	func _derive_layout(local_bounds: AABB) -> Dictionary:
		var layout := super._derive_layout(local_bounds)
		if layout.is_empty():
			return layout
		layout[COMPONENT_FORWARD_HULL].local_position = Vector3(0, 2.6, -8.2)
		layout[COMPONENT_PORT_WING].local_position = Vector3(-5.4, 2.15, 4)
		layout[COMPONENT_STARBOARD_WING].local_position = Vector3(5.4, 2.15, 4)
		layout[COMPONENT_CORE_SYSTEMS].local_position = Vector3(0, 4.75, 0)
		layout[COMPONENT_ENGINE_BAY].local_position = Vector3(0, 3.9, 8.5)
		return layout

	func get_operational_modifiers() -> Dictionary:
		var modifiers := super.get_operational_modifiers()
		if modifiers.is_empty():
			return modifiers
		# A damaged nose limits safe propulsion through the same controller
		# channel as the aft engine bay. The weaker surviving section wins.
		var nose := _ledger.get_component_performance_multiplier(COMPONENT_FORWARD_HULL)
		modifiers.mobility_multiplier = minf(float(modifiers.mobility_multiplier), nose)
		modifiers.mobility_disabled = bool(modifiers.mobility_disabled) \
			or _ledger.is_component_disabled(COMPONENT_FORWARD_HULL)
		return modifiers


## Transform round trips at this elevated, rotated deck can place supported
## feet a few micrometres below y=.8. Normalize only that floor residue;
## the authored walls, ceiling and real falls remain strict.
class TitanInteriorFrame:
	extends MovingInteriorFrame

	func contains_world_position(world_position: Vector3) -> bool:
		var moving := get_moving_frame()
		if not world_position.is_finite() or not has_interior_bounds() \
				or not is_instance_valid(moving) or not moving.is_inside_tree() \
				or moving.is_queued_for_deletion():
			return false
		var pose := moving.global_transform
		pose.basis = pose.basis.orthonormalized()
		var point := pose.affine_inverse() * world_position
		var bounds := get_interior_bounds()
		if not point.is_finite() or not bounds.position.is_finite() or not bounds.size.is_finite():
			return false
		if point.y < bounds.position.y and point.y >= bounds.position.y - 0.0001:
			point.y = bounds.position.y
		return bounds.has_point(point)

const PASSENGER_IDS := [&"passenger_port_01", &"passenger_starboard_01"]
const CREW_FRAME_ID := &"titan_walkable_interior"
var _passenger_anchors: Array[Marker3D] = []
var _crew_role_authority: CrewSeatRoleAuthority
var cargo_custody_guard: Callable
var cargo_launch_guard: Callable
var lifecycle_reset_guard: Callable
var _crew_generation := 1
var _retired_destruction_serial := -1

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
	if _canopy_open or _access_fraction > 0.0001 or (cargo_custody_guard.is_valid() and not cargo_custody_guard.call()):
		return _neutralized_command_snapshot(command)
	return command


## This transport's approved spool is part of its live pilot controls. The
## shared fighter wake hook is immediate; reuse the inherited timed owner here
## rather than replacing the engine clock or changing any existing craft.
func _wake_engine_for_automatic_demand(_release_dock_latch: bool = true) -> void:
	if _engine_state == ENGINE_OFFLINE:
		request_engine_start()


func request_engine_start() -> void:
	if not _canopy_open and _access_fraction <= 0.0001 and (not cargo_custody_guard.is_valid() or cargo_custody_guard.call()) and (not cargo_launch_guard.is_valid() or cargo_launch_guard.call()):
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


## Boarding discovery belongs at the helm. The stern control only opens the
## physical hatch: players reach this station by walking the deployed ramp.
func get_boarding_position() -> Vector3:
	return get_boarding_entry_transform().origin


func get_exterior_boarding_waypoints(_from_position: Vector3 = Vector3.INF) -> Array[Transform3D]:
	# A nonempty physical route also identifies an already-carried cabin walker
	# to Main's existing interior-to-seat handoff. No shell-crossing direct climb.
	var result: Array[Transform3D] = []
	for point in [Vector3(0, 0, 14.5), Vector3(0, 0, 13),
			Vector3(0, 0.4, 10.5), Vector3(0, 0.8, 8), Vector3(0, 0.8, 6.5)]:
		result.append(global_transform * Transform3D(Basis.IDENTITY, point))
	return result


func has_supported_exterior_access() -> bool:
	return _has_supported_exterior_access()


func get_interior_frame() -> MovingInteriorFrame:
	return _interior_frame


## Opt this hull into the same current coordinator predicate for both physical
## boarding discovery and Player's cached cabin containment. Player verifies
## the live owner, exact bounds and registered occupant before using it.
func get_cabin_containment_coordinator() -> MovingInteriorFrame:
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


func _build_ship() -> void:
	if _built:
		return
	_built = true
	var damage := TitanComponentDamage.new()
	damage.name = "ShipComponentDamage"
	add_child(damage)
	install_shared_damage_presentation(Vector3(-5.4, 2.15, 4),
		Vector3(0, 3.9, 8.5), Vector3(0, 4.75, 0), 12)
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
	# Leave the centre bore ahead of the skin: the approved muzzle is z=-8.9,
	# with centre sill ending at -8.8. Side cheeks retain the full hull bounds.
	_prism("PortNoseSill", [OUTLINE[0], Vector2(-0.45, -9), Vector2(-0.45, -7.4), INNER[0]], 0.8, 1.7, structure)
	_prism("StarboardNoseSill", [Vector2(0.45, -9), OUTLINE[1], INNER[1], Vector2(0.45, -7.4)], 0.8, 1.7, structure)
	_prism("CentreNoseSill", [Vector2(-0.45, -8.8), Vector2(0.45, -8.8), Vector2(0.45, -7.4), Vector2(-0.45, -7.4)], 0.8, 1.7, structure)
	var cannon := MeshInstance3D.new()
	cannon.name = "CentreDefensiveCannon"
	var barrel := CylinderMesh.new()
	barrel.top_radius = 0.13
	barrel.bottom_radius = 0.18
	barrel.height = 0.5
	cannon.mesh = barrel
	cannon.rotation.x = PI * 0.5
	cannon.position = Vector3(0, 1.1, -8.65)
	cannon.material_override = structure
	_visual_root.add_child(cannon)
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
	# The stern marker remains the physical exterior access control.
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
	# The standalone geometry fixture has no berth or Main pilot provider.
	if not home_berth_id.is_empty():
		var boarding := ShipBoardingArea.new()
		boarding.name = "ShipBoardingArea"
		boarding.position = Vector3(0, 0.8, -4.2)
		boarding.prompt_text = "[ E ] TAKE TITAN PILOT SEAT"
		var boarding_collision := CollisionShape3D.new()
		boarding_collision.name = "BoardingRange"
		var boarding_shape := SphereShape3D.new()
		boarding_shape.radius = 4.5
		boarding_collision.shape = boarding_shape
		boarding.add_child(boarding_collision)
		add_child(boarding)
	_build_passenger_chairs(structure, stripe)
	_build_access_ramp(structure)
	# A real canopy pivot lets the inherited motion clock and completion signal
	# drive this variant without building any fighter canopy geometry.
	_canopy_pivot = Node3D.new()
	_canopy_pivot.name = "AccessMotionClock"
	_visual_root.add_child(_canopy_pivot)
	_set_canopy_open_fraction(0.0)
	_interior_frame = TitanInteriorFrame.new()
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


## Every chair publishes its own immutable authored identity and supported pose.
func get_crew_seat_role_contract(anchor: Marker3D) -> Dictionary:
	var index := _passenger_anchors.find(anchor)
	if _destroyed or index < 0 or not is_instance_valid(anchor) or anchor.name != PASSENGER_IDS[index]:
		return {}
	var entry := global_transform * Transform3D(Basis.IDENTITY, Vector3(-0.9 if index == 0 else 0.9, 0.8, 1.8))
	return {"role": &"passenger", "vessel_id": get_ship_id(), "seat_id": PASSENGER_IDS[index],
		"seat": anchor, "entry_transform": entry, "exit_transform": entry,
		"frame": _interior_frame, "seat_type": &"physical",
		"role_label": "port passenger" if index == 0 else "starboard passenger"}


func _install_solo_crew_seat() -> void:
	if not is_inside_tree():
		return
	for anchor in _passenger_anchors:
		if anchor.get_node_or_null("SoloPassengerSeatInteraction") == null:
			ShipCrewSeat.install(anchor, self)


func _crew_seat_records() -> Array[Dictionary]:
	return [
		{"seat_id": &"pilot_station", "role": &"pilot", "anchor_id": &"pilot_station"},
		{"seat_id": PASSENGER_IDS[0], "role": &"passenger", "anchor_id": PASSENGER_IDS[0]},
		{"seat_id": PASSENGER_IDS[1], "role": &"passenger", "anchor_id": PASSENGER_IDS[1]},
	]


## Register into the existing authority; this ship never owns a second ledger.
func register_crew_seat_roster(authority: CrewSeatRoleAuthority) -> Dictionary:
	if _destroyed or authority == null:
		return {"accepted": false, "status": &"authority_unavailable"}
	for record in _crew_seat_records():
		var result := authority.register_seat(record.seat_id, get_ship_id(), record.role, CREW_FRAME_ID, _crew_generation, record.anchor_id)
		if not bool(result.get("accepted", false)):
			return result
	return authority.seal_roster([&"pilot", &"passenger"])


func attach_crew_role_authority(authority: CrewSeatRoleAuthority) -> Dictionary:
	if _destroyed or authority == null or (_crew_role_authority != null and _crew_role_authority != authority):
		return {"accepted": false, "status": &"authority_unavailable"}
	var snapshot := authority.get_snapshot()
	if not bool(snapshot.get("roster_sealed", false)):
		return {"accepted": false, "status": &"roster_not_sealed"}
	var seats: Array = snapshot.get("seats", [])
	if seats.size() != 3:
		return {"accepted": false, "status": &"titan_roster_mismatch"}
	for expected in _crew_seat_records():
		var matched := false
		for record: Dictionary in seats:
			if record.get("seat_id") == expected.seat_id and record.get("role") == expected.role \
					and record.get("anchor_id") == expected.anchor_id and record.get("vessel_id") == get_ship_id() \
					and record.get("frame_id") == CREW_FRAME_ID and int(record.get("seat_generation", 0)) == _crew_generation:
				matched = true
		if not matched:
			return {"accepted": false, "status": &"titan_roster_mismatch"}
	_crew_role_authority = authority
	return {"accepted": true, "status": &"authority_attached"}


func detach_crew_role_authority(authority: CrewSeatRoleAuthority) -> bool:
	if authority == null or authority != _crew_role_authority \
			or not (authority.get_snapshot().get("assignments", []) as Array).is_empty():
		return false
	_crew_role_authority = null
	return true


func get_crew_role_authority() -> CrewSeatRoleAuthority:
	return _crew_role_authority


func _build_passenger_chairs(structure: Material, cushion: Material) -> void:
	for index in 2:
		var x := -2.0 if index == 0 else 2.0
		var label := "PortPassenger" if index == 0 else "StarboardPassenger"
		# Narrow chairs leave x=-1.4..1.4 clear, including the 1.4m aisle.
		_prism(label + "Pedestal", [Vector2(x - 0.25, 1.55), Vector2(x + 0.25, 1.55), Vector2(x + 0.25, 2.05), Vector2(x - 0.25, 2.05)], 0.8, 1.35, structure)
		_prism(label + "Cushion", [Vector2(x - 0.5, 1.3), Vector2(x + 0.5, 1.3), Vector2(x + 0.5, 2.3), Vector2(x - 0.5, 2.3)], 1.35, 1.47, cushion)
		_prism(label + "Back", [Vector2(x - 0.5, 2.3), Vector2(x + 0.5, 2.3), Vector2(x + 0.5, 2.43), Vector2(x - 0.5, 2.43)], 1.47, 2.65, structure)
		var anchor := Marker3D.new()
		anchor.name = PASSENGER_IDS[index]
		anchor.position = Vector3(x, 0.75, 1.8)
		anchor.set_meta("crew_role", &"passenger")
		anchor.set_meta("seat_type", &"physical")
		_visual_root.add_child(anchor)
		_passenger_anchors.append(anchor)


## The shared occupant handoff remains the only metadata/frame mutator. Fence
## the complete Titan seat identity first, including current roster generation.
func attach_solo_crew_role_occupant(avatar_id: StringName, seat: ShipCrewSeat, occupant: Node3D) -> Dictionary:
	if _destroyed or _reset_for_reuse_mutation_blocked() or _crew_role_authority == null or not is_instance_valid(seat) or seat.get_ship() != self:
		return {"accepted": false, "status": &"occupancy_identity_mismatch"}
	var assignment := _crew_role_authority.get_assignment(1, avatar_id)
	var contract := seat.get_role_contract()
	if contract.is_empty() or assignment.get("vessel_id") != get_ship_id() \
			or assignment.get("seat_id") != contract.get("seat_id") or assignment.get("role") != &"passenger" \
			or assignment.get("frame_id") != CREW_FRAME_ID or assignment.get("anchor_id") != contract.get("seat_id") \
			or int(assignment.get("seat_generation", 0)) != _crew_generation:
		return {"accepted": false, "status": &"occupancy_identity_mismatch"}
	return super.attach_solo_crew_role_occupant(avatar_id, seat, occupant)


## Main owns the supported recovery pose; the existing frame/Player/role owners
## retire their own state before the normal pilot recall/regeneration proceeds.
func recover_destroyed_local_occupants(recovery: Transform3D) -> void:
	if not _destroyed or _retired_destruction_serial == _destruction_serial:
		return
	_retired_destruction_serial = _destruction_serial
	var occupants := _interior_frame.get_registered_occupants()
	var area := get_node_or_null("ShipBoardingArea") as ShipBoardingArea
	var pilot: PlayerController
	if area != null:
		pilot = area.get_reservation_token() as PlayerController
		if is_instance_valid(pilot) and pilot not in occupants:
			occupants.append(pilot)
		area.clear_reservation()
	var passenger_index := 0
	for occupant in occupants:
		var metadata: Dictionary = occupant.get_meta(SOLO_CREW_ROLE_OCCUPANT_META, {})
		if metadata.get("craft") == self:
			occupant.remove_meta(SOLO_CREW_ROLE_OCCUPANT_META)
		_interior_frame.unregister_occupant(occupant, false, &"ship_destroyed")
		if occupant is PlayerController:
			var actor := occupant as PlayerController
			var target := recovery
			if occupant != pilot:
				target.origin += target.basis.x * (-1.5 if passenger_index == 0 else 1.5)
				passenger_index += 1
			actor.force_recovery_to_on_foot(target)
			actor.set_camera_active(true)
			actor.set_control_enabled(true)
	if _crew_role_authority != null:
		_crew_role_authority.release_peer(1, 1)
		_crew_role_authority = null
	_crew_generation += 1
	set_piloted(false)
	if get_camera() != null:
		get_camera().current = false


func _preflight_variant_reset_for_reuse(spawn_transform: Transform3D) -> Dictionary:
	var area := get_node_or_null("ShipBoardingArea") as ShipBoardingArea
	if _piloted or _interior_frame.get_occupant_count() > 0 or (area != null and area.is_reserved()) \
			or (_crew_role_authority != null and not (_crew_role_authority.get_snapshot().assignments as Array).is_empty()):
		return {"accepted": false, "reason": &"titan_occupied"}
	if lifecycle_reset_guard.is_valid() and not lifecycle_reset_guard.call(spawn_transform):
		return {"accepted": false, "reason": &"titan_lifecycle_changed"}
	return {"accepted": true}


func _commit_variant_reset_for_reuse(_context: Dictionary) -> void:
	_set_canopy_open_fraction(0.0)
