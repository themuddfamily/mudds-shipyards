extends HeroShip

## Owner-approved original modern shell. Historical evidence supports name/role
## only. No production boarding, cabin, passenger, cargo or combat composition.
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
	_prism("LowerDeck", OUTLINE, 0.0, 0.8, structure)
	_prism("ChamferedRoof", OUTLINE, 4.5, 5.0, skin)
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
	# Reuse camera mechanics, then place generic markers at the candidate's
	# declared future poses. Markers provide no access or berth registration.
	_build_markers_and_camera()
	_boarding_marker.position = Vector3(0, 0.8, 7.5)
	_exit_marker.position = Vector3(0, 0, 12)
	_muzzle_left.position = Vector3(0, 1.1, -8.9)
	_muzzle_right.position = _muzzle_left.position
	_camera_pivot.position = Vector3(0, 3.0, 1.0)
	_boarding_entry_marker = Marker3D.new()
	_boarding_entry_marker.name = "FuturePilotApproach"
	_boarding_entry_marker.position = Vector3(0, 0.8, -4.2)
	_cockpit_root.add_child(_boarding_entry_marker)
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
