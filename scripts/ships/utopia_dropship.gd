class_name UtopiaDropship
extends HeroShip

## Original modern Utopia pilot foundation; A3 supplies only the name and role.
## Metres, +Y up, -Z forward. Cargo, physical access, berths and crew are later
## cards: reservation markers below are inert, never capabilities or writers.
const DEFINITION := preload("res://assets/ships/utopia_provisional.tres")
const HULL_BOUNDS := AABB(Vector3(-4.5, 0.0, -8.5), Vector3(9.0, 4.8, 17.0))
const PILOT_FEET := Vector3(0.0, 0.8, -5.8)
const PILOT_EYE := Vector3(0.0, 2.56, -6.05)
const FUTURE_ENTRY := Vector3(0.8, 0.8, -5.8)
var _original_shell: Node3D


func _init() -> void:
	ship_definition = DEFINITION
	cockpit_camera_position = PILOT_EYE


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
	_add_section_box("CargoDeck", Vector3(-3.1, 0, -7), Vector3(3.1, 0.8, 8.5), cream)
	_add_section_box("CargoCrown", Vector3(-3.1, 4.6, -7), Vector3(3.1, 4.8, 8.5), cream)
	_add_section_box("PortCargoWall", Vector3(-3.1, 0.8, -6.8), Vector3(-2.9, 4.6, 7.5), cream)
	_add_section_box("StarboardCargoWall", Vector3(2.9, 0.8, -6.8), Vector3(3.1, 4.6, 7.5), cream)
	_add_section_box("BowSill", Vector3(-3.1, 0.8, -7), Vector3(3.1, 1.6, -6.8), orange)
	_add_section_box("BowWindshield", Vector3(-3.1, 1.6, -7), Vector3(3.1, 4.6, -6.8), glass)
	_add_section_box("PortSternCheek", Vector3(-3.1, 0.8, 7.5), Vector3(-1.2, 4.6, 8.5), cream)
	_add_section_box("StarboardSternCheek", Vector3(1.2, 0.8, 7.5), Vector3(3.1, 4.6, 8.5), cream)
	_add_section_box("SternHeader", Vector3(-1.2, 3.2, 7.5), Vector3(1.2, 4.6, 8.5), cream)
	_add_section_box("RecessedSternHatch", Vector3(-1.2, 0.8, 8.3), Vector3(1.2, 3.2, 8.5), orange)
	_add_section_box("PortAftLiftHousing", Vector3(-4.5, 0, 4), Vector3(-3.1, 2.2, 8.5), orange)
	_add_section_box("StarboardAftLiftHousing", Vector3(3.1, 0, 4), Vector3(4.5, 2.2, 8.5), orange)
	_add_nose_wedge(cream)
	_pilot_seat_anchor = _reservation_marker("pilot_station", PILOT_FEET, self)
	_pilot_seat_anchor.set_meta("station_id", &"pilot_station")
	_boarding_entry_marker = _reservation_marker("FutureHelmStand", FUTURE_ENTRY, self)
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
	_boarding_marker.free()
	_boarding_marker = null
	_exit_marker.free()
	_exit_marker = null
	_camera_pivot.position = Vector3(0, 5.4, 3.5)
	_cockpit_camera.reparent(self, false)
	_cockpit_camera.position = PILOT_EYE
	var status := _install_variant_cockpit_system_readout(_cockpit_root)
	status.position = Vector3(0, 1.7, -6.65)
	status.font_size = 30
	status.pixel_size = 0.0012
	# The aft contact plate remains an opaque closed hatch in this foundation.
	# No MovingInteriorFrame, interaction area, passenger seat or cargo writer.
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
