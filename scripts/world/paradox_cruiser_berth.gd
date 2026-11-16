class_name ParadoxCruiserBerth
extends Node3D

## Original modern Paradox home deck and supported route from the Titan connector.
## The candidate is not spawned here; ShipBerth is the sole docking authority.
const MODULE_ID := &"paradox-cruiser-berth"
const BERTH_ID := &"paradox_home_berth"
const SLOT_ID := &"hub-paradox-cruiser-berth"
const WORLD_LAYER := PhysicsLayers.WORLD
var _enabled := true
var _routes: Dictionary = {}
var _anchor: Marker3D
var _berth: ShipBerth

func _ready() -> void:
	add_to_group(&"station_modules")
	set_meta("station_module", true)
	set_meta("evidence_status", &"modern_interpretation")
	set_process(false)
	set_physics_process(false)
	_anchor = Marker3D.new()
	_anchor.name = "ModuleAnchor"
	add_child(_anchor)
	var deck := StandardMaterial3D.new()
	deck.albedo_color = Color("526970")
	deck.metallic = 0.4
	deck.roughness = 0.6
	StationSurfaceKit.apply_panel_triplanar(deck, 0.3, StationSurfaceKit.PanelFinish.WALKED_DECK)
	var rail := StandardMaterial3D.new()
	rail.albedo_color = Color("a5b8b9")
	rail.metallic = 0.55
	# Clear deck x=-10..10, z=-18..20: the deployed ramp ends at z=18.
	_box("BerthDeck", Vector3(0, -0.2, 1), Vector3(20, 0.4, 38), deck, true)
	# At world yaw -90 this is world x=135, z=38..80. The deck
	# continues the same supported path to world z=90, with no transverse rail.
	_box("SpurConnector", Vector3(-31, -0.2, 19), Vector3(42, 0.4, 2.8), deck, true)
	_rail("DeckSidePort", Vector3(-10.12, 0.62, -0.26), Vector3(0.16, 1.24, 35.48), rail)
	_rail("DeckSideStarboard", Vector3(10.12, 0.62, 1), Vector3(0.16, 1.24, 38), rail)
	_rail("NoseRail", Vector3(0, 0.62, -18.12), Vector3(20.4, 1.24, 0.16), rail)
	_rail("SternRail", Vector3(0, 0.62, 20.12), Vector3(20.4, 1.24, 0.16), rail)
	# Start rails at world z=39.6, outside the old connector crossing.
	_rail("SpurSideNose", Vector3(-30.2, 0.62, 17.48), Vector3(40.4, 1.24, 0.16), rail)
	_rail("SpurSideStern", Vector3(-30.2, 0.62, 20.52), Vector3(40.4, 1.24, 0.16), rail)
	for spec in [[&"approach", Vector3(-40, 0, 19)], [&"stern-apron", Vector3(0, 0, 19)], [&"hatch-control", Vector3(1.9, 0, 14.5)]]:
		var marker := Marker3D.new()
		marker.name = str(spec[0]).to_pascal_case()
		marker.position = spec[1]
		marker.set_meta("station_route_marker", true)
		marker.set_meta("route_id", spec[0])
		if spec[0] == &"approach":
			marker.set_meta(StationModuleContract.CONNECTION_SLOT_META, SLOT_ID)
		add_child(marker)
		_routes[spec[0]] = marker
	_berth = ShipBerth.new()
	_berth.name = "ShipBerth"
	_berth.berth_id = BERTH_ID
	_berth.compatibility_tags = PackedStringArray(["paradox_cruiser"])
	_berth.landing_volume_center = Vector3(0, 3, 2)
	_berth.landing_half_extents = Vector3(9, 4, 17)
	_berth.assist_capture_center = Vector3(0, 12, -28)
	_berth.assist_capture_half_extents = Vector3(28, 18, 42)
	_berth.assist_capture_maximum_speed = 25
	_berth.assist_maximum_tilt_degrees = 65
	_berth.departure_lift_height = 8
	add_child(_berth)
	var landing_volume := Marker3D.new()
	landing_volume.name = "LandingVolumeCenter"
	landing_volume.position = _berth.landing_volume_center
	_berth.add_child(landing_volume)
	var sign := Label3D.new()
	sign.name = "ParadoxBerthSign"
	sign.text = "PARADOX  //  CANDIDATE BERTH\nSTERN ACCESS"
	sign.position = Vector3(4.8, 2.3, 20.2)
	sign.font_size = 36
	sign.outline_size = 6
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(sign)
	set_module_enabled(_enabled)

func _box(node_name: String, center: Vector3, size: Vector3, material: Material, walkable: bool) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = center
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	add_child(body)
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	if walkable:
		body.set_meta("walkable_surface", true)
		body.set_meta("walkable_surface_id", StringName(node_name.to_snake_case()))
		body.set_meta("walkable_surface_kind", &"level")
		body.set_meta("walkable_surface_owner", MODULE_ID)
		body.set_meta("horizontal_area_m2", size.x * size.z)
		var mesh := MeshInstance3D.new()
		mesh.name = "Mesh"
		var box := BoxMesh.new()
		box.size = size
		mesh.mesh = box
		mesh.material_override = material
		body.add_child(mesh)
	return body

func _rail(node_name: String, center: Vector3, size: Vector3, material: Material) -> void:
	var body := _box(node_name, center, size, material, false)
	body.set_meta("station_safety_edge", true)
	body.set_meta("non_walkable_reason", "physical edge rail")
	var along_x := size.x > size.z
	for height in [0.66, 1.15]:
		var mesh := MeshInstance3D.new()
		mesh.name = "Bar%s" % str(height).replace(".", "_")
		mesh.position.y = height - center.y
		var box := BoxMesh.new()
		box.size = Vector3(size.x, 0.1, size.z)
		mesh.mesh = box
		mesh.material_override = material
		body.add_child(mesh)
	var run := size.x if along_x else size.z
	var segments := ceili(run / 2.4)
	for index in segments + 1:
		var mesh := MeshInstance3D.new()
		mesh.name = "Post%02d" % index
		var offset := -run * 0.5 + run * float(index) / segments
		mesh.position = Vector3(offset if along_x else 0, 0, 0 if along_x else offset)
		var box := BoxMesh.new()
		box.size = Vector3(0.12, 1.24, 0.12)
		mesh.mesh = box
		mesh.material_override = material
		body.add_child(mesh)

func get_module_id() -> StringName:
	return MODULE_ID
func get_module_anchor() -> Marker3D:
	return _anchor
func get_route_ids() -> Array[StringName]:
	return [&"approach", &"stern-apron", &"hatch-control"]
func has_route_marker(route_id: StringName) -> bool:
	return _routes.has(route_id)
func get_route_marker(route_id: StringName) -> Marker3D:
	return _routes.get(route_id) as Marker3D
func get_route_transform(route_id: StringName) -> Transform3D:
	var marker := get_route_marker(route_id)
	return marker.global_transform if marker != null else Transform3D.IDENTITY
func get_integration_footprint() -> Dictionary:
	return {"anchor_transform": _anchor.global_transform, "local_min": Vector3(-52.1, -0.4, -18.3), "local_max": Vector3(10.3, 3, 20.7)}
func get_evidence_metadata() -> Dictionary:
	return {"evidence_status": &"modern_interpretation", "content_class": &"NEW", "source_bounded": false, "content_note": "Original Paradox home deck, spur and adjacency, not historical reconstruction."}
func get_component_roster() -> Dictionary:
	return StationModuleContract.build_component_roster(self)
func get_collision_contract() -> Dictionary:
	return StationModuleContract.build_collision_contract(self, WORLD_LAYER, _enabled)
func get_authority_contract() -> Dictionary:
	var contract := StationModuleContract.build_authority_contract(self)
	contract["authority_ids"] = PackedStringArray([str(BERTH_ID)])
	return contract
func get_performance_contract() -> Dictionary:
	return StationModuleContract.build_performance_contract(self, {"static_bodies": 8, "collision_shapes": 8, "mesh_instances": 103, "labels": 1, "lights": 0, "process_loops": 0, "physics_process_loops": 0})
func set_module_enabled(enabled: bool) -> void:
	_enabled = enabled
	StationModuleContract.apply_enabled_state(StationModuleContract.collect_static_bodies(self), WORLD_LAYER, _enabled, self)
	set_process(false)
	set_physics_process(false)
func is_module_enabled() -> bool:
	return _enabled
func get_lifecycle_contract() -> Dictionary:
	return StationModuleContract.build_lifecycle_contract(self, WORLD_LAYER, _enabled, self)
func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if _berth == null:
		errors.append("missing own berth")
	else:
		errors.append_array(_berth.get_validation_errors())
	if not bool(get_collision_contract().all_shapes_present_and_enabled):
		errors.append("deck or rails missing collision")
	if not bool(get_performance_contract().within_budget):
		errors.append("berth exceeds component budget")
	return errors
func get_audit_report() -> Dictionary:
	var errors := get_validation_errors()
	return {"valid": errors.is_empty(), "errors": errors, "module_id": MODULE_ID}
