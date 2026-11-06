extends HeroShip

## Original editable modern interpretation; A3 establishes name/role only.
## Card 1 is a standalone pilot fixture. Access/chairs/Main/combat come later.
## Metres, +Y up, -Z forward. Cabin is reserved, never a solid hull box.
const PILOT_ORIGIN := Vector3(0, 1.45, -6.5)
const OUTER := [Vector2(-2.7, -10), Vector2(2.7, -10),
	Vector2(3.5, -8.8), Vector2(3.5, 8), Vector2(2.7, 10),
	Vector2(-2.7, 10), Vector2(-3.5, 8), Vector2(-3.5, -8.8)]
const INNER := [Vector2(-2.2, -7.5), Vector2(2.2, -7.5),
	Vector2(2.8, -7), Vector2(2.8, 8), Vector2(2.2, 8),
	Vector2(-2.2, 8), Vector2(-2.8, 8), Vector2(-2.8, -7)]


## Preserve the approved timed spool even for ordinary automatic demand.
## HeroShip remains the sole engine clock and movement owner.
func _wake_engine_for_automatic_demand(_release_dock_latch: bool = true) -> void:
	if _engine_state == ENGINE_OFFLINE:
		request_engine_start()


func _uses_torrent_reconstruction_presentation() -> bool:
	return false


func _uses_inherited_primary_weapon() -> bool:
	# The approved combat installation belongs to card 7, not this fixture.
	return false


func set_canopy_open(_open: bool, _duration: float = 0.0) -> void:
	# No physical access is installed or advertised by card 1.
	pass


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
	_visual_root.name = "VortexOriginalShell"
	add_child(_visual_root)
	var skin := _vortex_finish(Color("626c88"), 0.62)
	var frame := _vortex_finish(Color("1c2638"), 0.8)
	var accent := _vortex_finish(Color("e0af70"), 0.5)
	var glazing := _vortex_finish(Color(0.12, 0.28, 0.35, 0.28), 0.18)
	glazing.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glazing.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Broad chamfered cabin pod. Stern deck stops at the recessed closure;
	# separate cheeks preserve the full 20m silhouette and future ramp space.
	_prism("CabinDeck", [OUTER[0], OUTER[1], OUTER[2], Vector2(3.5, 8),
		Vector2(-3.5, 8), OUTER[7]], 0, 1, frame)
	_prism("CabinRoof", OUTER, 4.5, 5, skin)
	for edge in [1, 2, 6, 7]:
		var next: int = (int(edge) + 1) % OUTER.size()
		_prism("PodWall%d" % edge, [OUTER[edge], OUTER[next], INNER[next], INNER[edge]], 1, 4.5, skin)
	var nose := [OUTER[0], OUTER[1], INNER[1], INNER[0]]
	_prism("NoseSill", nose, 1, 2, frame)
	_prism("FlightDeckGlazing", nose, 2, 3.8, glazing)
	_prism("NoseBrow", nose, 3.8, 4.5, skin)
	_prism("SternHeader", [Vector2(-2.2, 8), Vector2(2.2, 8),
		Vector2(2.7, 10), Vector2(-2.7, 10)], 3.6, 4.5, frame)
	for side in [-1.0, 1.0]:
		var label := "Port" if side < 0 else "Starboard"
		_prism(label + "SternCheek", [Vector2(side * 1.2, 8), Vector2(side * 3.5, 8),
			Vector2(side * 2.7, 10), Vector2(side * 1.2, 10)], 0, 3.6, skin)
		# Separate long side nacelles have tapered noses and inset aft exhausts.
		_prism(label + "EngineHousing", [Vector2(side * 3.5, -5), Vector2(side * 4.3, -5),
			Vector2(side * 5, -3.5), Vector2(side * 5, 7.5),
			Vector2(side * 4.7, 8.5), Vector2(side * 3.5, 8.5)], 1.2, 3.5, frame)
		_vortex_box(label + "EngineStripe", Vector3(side * 4.25, 3.52, 1.5), Vector3(0.7, 0.04, 9), accent)
		var core := _vortex_box(label + "EngineCore", Vector3(side * 4.2, 2.35, 8.45), Vector3(0.85, 1.15, 0.03), _vortex_finish(Color("68cde0"), 0.2))
		_engine_core_glows.append(core)
	_prism("RecessedSternClosure", [Vector2(-1.2, 7.8), Vector2(1.2, 7.8),
		Vector2(1.2, 8), Vector2(-1.2, 8)], 1, 3.6, accent)
	# Visible non-colliding helm fitout; pilot attachment uses the actual anchor.
	_vortex_box("PilotChair", Vector3(0, 1.38, -6.5), Vector3(0.85, 0.25, 0.85), frame)
	_vortex_box("PilotBack", Vector3(0, 1.95, -6.1), Vector3(0.85, 1.0, 0.18), skin)
	_vortex_box("HelmConsole", Vector3(0, 1.65, -7.2), Vector3(1.2, 0.45, 0.45), frame)
	_cockpit_root = Node3D.new()
	_cockpit_root.name = "PilotFixture"
	_visual_root.add_child(_cockpit_root)
	_pilot_seat_anchor = Marker3D.new()
	_pilot_seat_anchor.name = "pilot_station"
	_pilot_seat_anchor.position = PILOT_ORIGIN
	_cockpit_root.add_child(_pilot_seat_anchor)
	_build_markers_and_camera()
	_boarding_marker.position = Vector3(0, 1, -5)
	_exit_marker.position = Vector3(0, 0, 13)
	_camera_pivot.position = Vector3(0, 3, 1)
	_muzzle_left.position = Vector3(0, 2.6, -10)
	_muzzle_right.position = _muzzle_left.position
	_canopy_pivot = Node3D.new()
	_canopy_pivot.name = "ReservedSternAccess"
	_visual_root.add_child(_canopy_pivot)
	_sync_engine_visuals_immediately()


func _vortex_finish(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = 0.25
	return material


func _vortex_box(label: String, origin: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = origin
	_visual_root.add_child(mesh)
	return mesh


## Each convex section supplies the same editable vertices to mesh and shape.
## No collision section bridges across the reserved central cabin.
func _prism(label: String, footprint: Array, bottom: float, top: float, material: Material) -> void:
	var polygon := PackedVector2Array(footprint)
	if Geometry2D.is_polygon_clockwise(polygon):
		polygon.reverse()
	var points := PackedVector3Array()
	for height in [bottom, top]:
		for point in polygon:
			points.append(Vector3(point.x, height, point.y))
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
		for index in [indices[i + 2], indices[i + 1], indices[i]]:
			surface.add_vertex(points[index])
		for index in [indices[i], indices[i + 1], indices[i + 2]]:
			surface.add_vertex(points[index + count])
	for i in count:
		var next := (i + 1) % count
		for index in [i, next, i + count, next, next + count, i + count]:
			surface.add_vertex(points[index])
	surface.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.name = label
	mesh.mesh = surface.commit()
	_visual_root.add_child(mesh)
