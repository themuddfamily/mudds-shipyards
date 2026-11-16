extends HeroShip

## Original modern cruiser, not an authenticated historical silhouette.
## Continuous stern access with physical local crew; weapons remain unfitted.
## Editable convex sections use metres, +Y up and -Z forward.
const PILOT_ORIGIN := Vector3(0, 1.65, -3.8)
const CABIN_VOID := AABB(Vector3(-2.8, 1.2, -5), Vector3(5.6, 2.8, 19))
const RAMP_POINTS := [Vector3(-1.2,0,0), Vector3(-1.2,-0.68,2), Vector3(-1.2,-1.2,4),
	Vector3(1.2,0,0), Vector3(1.2,-0.68,2), Vector3(1.2,-1.2,4)]
const CREW_FRAME_ID := &"paradox_walkable_interior"
const CREW_IDS := [&"gunner_station", &"passenger_station"]
const CREW_ANCHOR_NAMES := [&"GunnerStationAnchor", &"PassengerStationAnchor"]
const CREW_ROLES := [&"gunner", &"passenger"]
const CREW_POSITIONS := [Vector3(-1.8,1.65,-0.5), Vector3(1.8,1.65,2.8)]
const CREW_STANDS := [Vector3(-0.8,1.2,-0.5), Vector3(0.8,1.2,2.8)]
var _crew_anchors: Array[Marker3D] = []
var _crew_role_authority: CrewSeatRoleAuthority
var _crew_generation := 1
var _access_fraction := 0.0
var _solid_root: Node3D
var _ramp_collision: CollisionShape3D
var _ramp_mesh: MeshInstance3D
var _interior_frame: MovingInteriorFrame


## A world-transform round trip may place supported soles micrometres below
## the authored floor. Normalize only that residue, retaining strict walls/roof.
class ParadoxInteriorFrame:
	extends MovingInteriorFrame

	func _physics_process(delta: float) -> void:
		# Retire a walker on the first coordinator tick after its soles leave
		# the supported room, rather than carrying it until its trailing capsule
		# has entirely exited the occupancy sensor.
		for occupant_id: int in _occupants.keys():
			var state: Dictionary = _occupants[occupant_id]
			var occupant: Variant = (state.occupant as WeakRef).get_ref()
			if is_instance_valid(occupant) and not contains_world_position(occupant.global_position):
				unregister_occupant(occupant, true, &"left_supported_cabin")
		super._physics_process(delta)

	func contains_world_position(world_position: Vector3) -> bool:
		var moving := get_moving_frame()
		if not world_position.is_finite() or not is_instance_valid(moving):
			return false
		var point := moving.global_transform.affine_inverse() * world_position
		var bounds := get_interior_bounds()
		if point.y < bounds.position.y and point.y >= bounds.position.y - 0.0001:
			point.y = bounds.position.y
		return bounds.has_point(point)


## Only the authored pilot composition supplies this real physical seat area.
func is_boardable() -> bool:
	if not super.is_boardable() or not has_node("ShipBoardingArea"):
		return false
	# The existing bounded moving cabin can return its OFFLINE walker to the
	# helm while sealed. GameFlow retains that exact registered-cabin context.
	if not _landed:
		return is_instance_valid(_interior_frame)
	return is_canopy_open() and _access_fraction >= 0.999 and has_supported_exterior_access()


func can_board_from_landed_approach(actor: PlayerController) -> bool:
	if not is_boardable() or not is_instance_valid(actor) or not actor.is_inside_tree() \
			or actor.is_queued_for_deletion() or not actor.is_control_enabled() \
			or actor.is_seated() or not actor.is_on_floor() \
			or actor.collision_layer != PhysicsLayers.PLAYER_BODY_LAYER \
			or actor.collision_mask != PhysicsLayers.PLAYER_BODY_MASK \
			or (actor.get_node("PlayerCollision") as CollisionShape3D).disabled:
		return false
	var point := to_local(actor.global_position)
	return Vector2(point.x,point.z+2.4).length() <= 0.45 \
		and absf(point.y-1.2) <= 0.04 and has_clear_landed_pilot_stand(actor)


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
	return _neutralized_command_snapshot(command) if _canopy_open or _access_fraction > 0.0001 else command


func request_engine_start() -> void:
	if not _canopy_open and _access_fraction <= 0.0001:
		super.request_engine_start()


func _wake_engine_for_automatic_demand(_release_dock_latch: bool = true) -> void:
	# Both manual and demand-driven starts retain HeroShip's single timed clock.
	if _engine_state == ENGINE_OFFLINE:
		request_engine_start()


func _uses_torrent_reconstruction_presentation() -> bool:
	return false


func _uses_inherited_primary_weapon() -> bool:
	return false


func _uses_weapon_component_fallback_emitters() -> bool:
	return false


func _get_weapon_unavailable_reason(_modifiers: Dictionary = {}) -> StringName:
	return &"primary_not_fitted"


func _get_weapon_fire_status_from_modifiers(_modifiers: Dictionary) -> Dictionary:
	return {"ready": false, "status": &"primary_not_fitted", "reason": &"primary_not_fitted", "heat": 0.0,
		"cooldown_remaining": 0.0, "recovery_remaining": 0.0}


func _fire_weapon() -> void:
	pass


func _fire_weapon_with_aim(_crew_origin: Vector3 = Vector3.INF, _crew_direction: Vector3 = Vector3.ZERO) -> void:
	pass


func _get_cockpit_system_readout() -> Dictionary:
	return {"text": "PRIMARY NOT FITTED  //  CRUISER", "color": Color("8de8e4")}



func set_canopy_open(open: bool, duration: float = 0.35) -> void:
	if open and not has_supported_exterior_access():
		return
	super.set_canopy_open(open, duration)


func has_supported_exterior_access() -> bool:
	if not is_inside_tree() or _destroyed or not _landed or _landing_active \
			or _engine_state != ENGINE_OFFLINE or velocity.length() > 0.01:
		return false
	var up := global_basis.y.normalized()
	for point: Vector3 in [Vector3(-1.15,0,18), Vector3(1.15,0,18), Vector3(0,0,19.5)]:
		var world := global_transform * point
		var query := PhysicsRayQueryParameters3D.create(world + up * 0.12, world - up * 0.12,
			PhysicsLayers.WORLD | PhysicsLayers.SHIP, [get_rid()])
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or (hit.normal as Vector3).dot(up) < 0.99 \
				or absf(((hit.position as Vector3) - world).dot(up)) > 0.03:
			return false
	return true


func get_interior_frame() -> MovingInteriorFrame:
	return _interior_frame


func get_cabin_containment_coordinator() -> MovingInteriorFrame:
	return _interior_frame


func get_in_flight_cabin_report() -> Dictionary:
	return {"supported": not _destroyed and is_instance_valid(_interior_frame),
		"status": &"walkable_cabin", "frame": _interior_frame,
		"stand_transform": global_transform * Transform3D(Basis.IDENTITY, Vector3(0,1.2,-2.4)),
		"local_bounds": CABIN_VOID}


## One inherited tween owns the clock. A small hinge carriage compensates the
## rigid leaf's diagonal sweep; its toe can never overshoot the declared berth.
func _set_canopy_open_fraction(open_fraction: float) -> void:
	super._set_canopy_open_fraction(open_fraction)
	_access_fraction = clampf(open_fraction, 0.0, 1.0)
	if not is_instance_valid(_ramp_collision):
		return
	var pose := get_access_ramp_transform(_access_fraction)
	_ramp_collision.transform = pose
	_ramp_mesh.transform = pose
	for side in [-1.0,1.0]:
		var label := "PortHatchLeaf" if side < 0 else "StarboardHatchLeaf"
		var offset := Vector3(side * 1.2 * _access_fraction,0,0)
		get_node(label + "Collision").position = offset
		_solid_root.get_node(label).position = offset


## Pure authored carriage geometry; the inherited clock calls this same function
## used to measure the full sweep without advancing a live ship's motion state.
func get_access_ramp_transform(open_fraction: float) -> Transform3D:
	var fraction := clampf(open_fraction,0.0,1.0)
	var angle := (1.0 - fraction) * (PI * 0.5 + atan(0.3))
	var basis := Basis(Vector3.RIGHT,-angle)
	var maximum_z := 0.0
	for point: Vector3 in RAMP_POINTS:
		maximum_z = maxf(maximum_z,(basis*point).z)
	var allowed_extension := 4.0*smoothstep(0.0,0.2,fraction)
	return Transform3D(basis,Vector3(0,1.2,14-maxf(0.0,maximum_z-allowed_extension)))


## The folded triangular leaf is not an axis-aligned box. Transform its actual
## convex points so the existing landing owner receives the real full hull,
## rather than the unoccupied corners of a rotated debug bounding box.
func get_landing_collision_report() -> Dictionary:
	var report := super.get_landing_collision_report()
	var combined := AABB()
	var first := true
	for child in get_children():
		if not child is CollisionShape3D:
			continue
		var collision := child as CollisionShape3D
		if collision.disabled or not collision.shape is ConvexPolygonShape3D:
			continue
		for point: Vector3 in (collision.shape as ConvexPolygonShape3D).points:
			var actual := collision.transform*point
			combined = AABB(actual,Vector3.ZERO) if first else combined.expand(actual)
			first = false
	if not first:
		report.local_bounds = combined
	return report


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
	_solid_root.name = "ParadoxOriginalShell"
	add_child(_solid_root)
	_visual_root = Node3D.new()
	_visual_root.name = "ParadoxCosmeticBank"
	_visual_root.set_meta("presentation_only", true)
	add_child(_visual_root)
	_visual_root.visibility_changed.connect(_sync_solid_root_visibility)
	_sync_solid_root_visibility()
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
		_rect(label + "Exhaust", minf(side*3.65,side*5.2),maxf(side*3.65,side*5.2),13.98,14,1.7,3.2,_finish(Color("66d7eb"),0.2))
		_build_exhaust_glow(label, side * 4.425)
	# Raised aft bridge roof: broad brow and a narrower crown establish 6m height.
	_rect("BridgeRoof", -3.3,3.3,-5.4,11,4,5.6,armor)
	_rect("BridgeCrown", -2.8,2.8,-3,10,5.6,6,brass)
	_rect("VestibuleFloor", -1.2,1.2,11,14,0,1.2,dark)
	for side in [-1.0,1.0]:
		var label := "Port" if side < 0 else "Starboard"
		_rect(label + "HatchCheek", minf(side*2.4,side*2.8),maxf(side*2.4,side*2.8),11,11.3,1.2,4,dark)
		_rect(label + "VestibuleWall", minf(side*2.8,side*3.3),maxf(side*2.8,side*3.3),11,14,1.2,4,armor)
		_rect(label + "RearCheek", minf(side*1.2,side*2.8),maxf(side*1.2,side*2.8),13.8,14,1.2,4,armor)
	_rect("PortHatchLeaf", -1.2,0,11,11.3,1.2,4,dark)
	_rect("StarboardHatchLeaf", 0,1.2,11,11.3,1.2,4,dark)
	_rect("PortVestibuleRoof", -3.3,-1.2,11.3,14,4,4.15,armor)
	_rect("StarboardVestibuleRoof", 1.2,3.3,11.3,14,4,4.15,armor)
	_rect("WellHeader", -3.3,3.3,11,11.3,4,5.6,armor)
	_cockpit_root = Node3D.new()
	_cockpit_root.name = "PilotFixture"
	_solid_root.add_child(_cockpit_root)
	_pilot_seat_anchor = Marker3D.new()
	_pilot_seat_anchor.name = "PilotSeatAnchor"
	_pilot_seat_anchor.position = PILOT_ORIGIN
	_pilot_seat_anchor.set_meta("station_id", &"pilot_station")
	_cockpit_root.add_child(_pilot_seat_anchor)
	_build_markers_and_camera()
	_boarding_marker.position = Vector3(0,1.2,10)
	_exit_marker.position = Vector3(0,0,17)
	_camera_pivot.position = Vector3(0,4,2)
	_muzzle_left.free()
	_muzzle_right.free()
	_muzzle_left = null
	_muzzle_right = null
	if has_node("ShipBoardingArea"):
		_boarding_entry_marker = Marker3D.new()
		_boarding_entry_marker.name = "BoardingEntry"
		_boarding_entry_marker.position = Vector3(0,1.2,-2.4)
		_cockpit_root.add_child(_boarding_entry_marker)
		_boarding_marker.position = Vector3(0,1.2,-2.4)
		_exit_marker.position = Vector3(0,1.2,-2.4)
		_exit_marker.rotation = Vector3.ZERO
		_build_local_crew_chairs(dark, brass)
		_install_variant_cockpit_system_readout(_visual_root)
		_cockpit_readout.position = Vector3(0,3.1,-4.9)
	_canopy_pivot = Node3D.new()
	_canopy_pivot.name = "AccessMotionClock"
	_solid_root.add_child(_canopy_pivot)
	_build_access_ramp(brass)
	_set_canopy_open_fraction(0)
	_interior_frame = ParadoxInteriorFrame.new()
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
	panel_mesh.size = Vector3(0.32,0.32,0.006)
	panel.mesh = panel_mesh
	panel.position = Vector3(1.9,1.6,13.997)
	panel.material_override = brass
	_solid_root.add_child(panel)
	ShipCabinHatch.install(_solid_root, self, Vector3(1.9,1.6,13.98))
	if has_node("ShipBoardingArea"):
		var inside_panel := MeshInstance3D.new()
		inside_panel.name = "InteriorAccessControl"
		inside_panel.mesh = panel_mesh
		inside_panel.position = Vector3(1.9,2,10.8)
		inside_panel.material_override = brass
		_solid_root.add_child(inside_panel)
		var inside_hatch := ShipCabinHatch.install(_solid_root,self,inside_panel.position)
		inside_hatch.name = "InteriorHatchInteraction"
	_sync_engine_visuals_immediately()


## The stable physical shell shares inherited hide/restore lifecycle state.
func get_variant_visual_root() -> Node3D:
	return _solid_root if is_instance_valid(_solid_root) else null


func _sync_solid_root_visibility() -> void:
	if is_instance_valid(_solid_root) and is_instance_valid(_visual_root):
		_solid_root.visible = _visual_root.visible


## The exhaust panel remains solid and visible OFFLINE; only light is cosmetic.
func _build_exhaust_glow(label: String, center_x: float) -> void:
	var glow := MeshInstance3D.new()
	glow.name = label + "ExhaustGlow"
	glow.set_meta("presentation_only", true)
	var quad := QuadMesh.new()
	quad.size = Vector2(1.5, 1.45)
	glow.mesh = quad
	glow.position = Vector3(center_x,2.45,14.002)
	var material := _finish(Color("66d7eb"),0.2)
	material.emission_enabled = true
	material.emission = Color("66d7eb")
	material.emission_energy_multiplier = 2.0
	glow.material_override = material
	_solid_root.add_child(glow)
	_engine_core_glows.append(glow)


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
	_solid_root.add_child(mesh)
	return mesh


func _on_cabin_occupancy_changed(_occupant: Node3D, _exit_velocity: Vector3 = Vector3.ZERO, _reason: StringName = &"") -> void:
	if not _destroyed:
		collision_mask = PhysicsLayers.SHIP_BODY_MASK & ~PhysicsLayers.PLAYER \
			if _interior_frame.get_occupant_count() > 0 else PhysicsLayers.SHIP_BODY_MASK


func _build_access_ramp(material: Material) -> void:
	_ramp_collision = CollisionShape3D.new()
	_ramp_collision.name = "SternRampCollision"
	var shape := ConvexPolygonShape3D.new()
	shape.points = PackedVector3Array(RAMP_POINTS)
	_ramp_collision.shape = shape
	add_child(_ramp_collision)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	var center := Vector3(0,-0.6266666667,2)
	for face in [[0,1,2], [3,5,4], [0,3,4,1], [1,4,5,2], [2,5,3,0]]:
		for triangle in ([[face[0],face[1],face[2]]] if face.size() == 3 else [[face[0],face[1],face[2]],[face[0],face[2],face[3]]]):
			var a: Vector3 = RAMP_POINTS[triangle[0]]
			var b: Vector3 = RAMP_POINTS[triangle[1]]
			var c: Vector3 = RAMP_POINTS[triangle[2]]
			# Godot front faces use clockwise winding.
			if (b-a).cross(c-a).dot(a-center) > 0:
				var swap := b
				b = c
				c = swap
			surface.add_vertex(a)
			surface.add_vertex(b)
			surface.add_vertex(c)
	surface.generate_normals()
	_ramp_mesh = MeshInstance3D.new()
	_ramp_mesh.name = "SternRamp"
	_ramp_mesh.mesh = surface.commit()
	_solid_root.add_child(_ramp_mesh)


## The pilot prefab opts into these chairs; standalone hull geometry is unchanged.
func _build_local_crew_chairs(structure: Material, cushion: Material) -> void:
	if not has_node("CrewFurniture"):
		return
	for index in 2:
		var point: Vector3 = CREW_POSITIONS[index]
		var label := "Gunner" if index == 0 else "Passenger"
		_rect(label + "Seat", point.x-0.4,point.x+0.4,point.z-0.4,point.z+0.4,1.2,1.65,cushion)
		_rect(label + "Back",point.x-0.4,point.x+0.4,point.z+0.4,point.z+0.58,1.65,2.75,structure)
		var anchor := Marker3D.new()
		anchor.name = CREW_ANCHOR_NAMES[index]
		anchor.position = point
		anchor.set_meta("station_id", CREW_IDS[index])
		anchor.set_meta("crew_role", CREW_ROLES[index])
		anchor.set_meta("seat_type", &"physical")
		_solid_root.add_child(anchor)
		_crew_anchors.append(anchor)


func get_crew_seat_role_contract(anchor: Marker3D) -> Dictionary:
	var index := _crew_anchors.find(anchor)
	if _destroyed or index < 0 or not is_instance_valid(anchor) or anchor.name != CREW_ANCHOR_NAMES[index] \
			or anchor.get_parent() != _solid_root:
		return {}
	var stand := global_transform * Transform3D(Basis(Vector3.UP,-PI*0.5 if index == 0 else PI*0.5), CREW_STANDS[index])
	return {"role": CREW_ROLES[index], "vessel_id": get_ship_id(), "seat_id": CREW_IDS[index],
		"seat": anchor, "entry_transform": stand, "exit_transform": stand,
		"frame": _interior_frame, "seat_type": &"physical", "role_label": String(CREW_ROLES[index])}


func _install_solo_crew_seat() -> void:
	if not is_inside_tree():
		return
	for index in _crew_anchors.size():
		var anchor := _crew_anchors[index]
		var interaction := "Solo%sSeatInteraction" % String(CREW_ROLES[index]).capitalize()
		if anchor.get_node_or_null(interaction) == null:
			ShipCrewSeat.install(anchor, self)


func _crew_seat_records() -> Array[Dictionary]:
	return [
		{"seat_id": &"pilot_station", "role": &"pilot", "anchor_id": &"pilot_station"},
		{"seat_id": CREW_IDS[0], "role": CREW_ROLES[0], "anchor_id": CREW_IDS[0]},
		{"seat_id": CREW_IDS[1], "role": CREW_ROLES[1], "anchor_id": CREW_IDS[1]},
	]


## Existing authority owns all assignments; never replace or extend another roster.
func register_crew_seat_roster(authority: CrewSeatRoleAuthority) -> Dictionary:
	if _destroyed or authority == null or _crew_anchors.size() != 2:
		return {"accepted": false, "status": &"authority_unavailable"}
	var snapshot := authority.get_snapshot()
	if bool(snapshot.get("roster_sealed", false)) or not (snapshot.get("seats", []) as Array).is_empty():
		return {"accepted": false, "status": &"paradox_roster_mismatch"}
	for record in _crew_seat_records():
		var result := authority.register_seat(record.seat_id,get_ship_id(),record.role,CREW_FRAME_ID,_crew_generation,record.anchor_id)
		if not bool(result.get("accepted", false)):
			return result
	return authority.seal_roster([&"pilot", &"gunner", &"passenger"])


func attach_crew_role_authority(authority: CrewSeatRoleAuthority) -> Dictionary:
	if _destroyed or authority == null or _crew_anchors.size() != 2 \
			or (_crew_role_authority != null and _crew_role_authority != authority):
		return {"accepted": false, "status": &"authority_unavailable"}
	var snapshot := authority.get_snapshot()
	if not bool(snapshot.get("roster_sealed", false)):
		return {"accepted": false, "status": &"roster_not_sealed"}
	var seats: Array = snapshot.get("seats", [])
	if seats.size() != 3:
		return {"accepted": false, "status": &"paradox_roster_mismatch"}
	for expected in _crew_seat_records():
		var matched := false
		for record: Dictionary in seats:
			if record.get("seat_id") == expected.seat_id and record.get("role") == expected.role \
					and record.get("anchor_id") == expected.anchor_id and record.get("vessel_id") == get_ship_id() \
					and record.get("frame_id") == CREW_FRAME_ID and int(record.get("seat_generation", 0)) == _crew_generation:
				matched = true
		if not matched:
			return {"accepted": false, "status": &"paradox_roster_mismatch"}
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


func attach_solo_crew_role_occupant(avatar_id: StringName, seat: ShipCrewSeat, occupant: Node3D) -> Dictionary:
	if _destroyed or _reset_for_reuse_mutation_blocked() or _crew_role_authority == null \
			or not is_instance_valid(seat) or seat.get_ship() != self:
		return {"accepted": false, "status": &"occupancy_identity_mismatch"}
	var assignment := _crew_role_authority.get_assignment(1, avatar_id)
	var contract := seat.get_role_contract()
	if contract.is_empty() or assignment.get("vessel_id") != get_ship_id() \
			or assignment.get("seat_id") != contract.get("seat_id") or assignment.get("role") != contract.get("role") \
			or assignment.get("frame_id") != CREW_FRAME_ID or assignment.get("anchor_id") != contract.get("seat_id") \
			or int(assignment.get("seat_generation", 0)) != _crew_generation:
		return {"accepted": false, "status": &"occupancy_identity_mismatch"}
	return super.attach_solo_crew_role_occupant(avatar_id, seat, occupant)


## No fitted defensive cannon exists until its separate accepted weapon card.
func request_solo_crew_weapon_power(_avatar_id: StringName, _seat: ShipCrewSeat, _occupant: Node3D, _occupant_peer_id: int = 1) -> bool:
	return false
