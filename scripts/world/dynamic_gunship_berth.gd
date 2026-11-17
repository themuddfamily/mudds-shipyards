class_name DynamicGunshipBerth
extends Node3D

## Original modern reachable Dynamic deck. This infrastructure never spawns a
## craft; ShipyardWorld authors placement and ShipBerth owns docking authority.
const MODULE_ID := &"dynamic-gunship-berth"
const BERTH_ID := &"dynamic_home_berth"
const SLOT_ID := &"hub-dynamic-gunship-berth"
const WORLD_LAYER := PhysicsLayers.WORLD
const SITE_XZ := Vector2(108,-30)
# Six disjoint plates meet only at their boundaries, including the old
# StarboardBerthNode's actual z=7 edge and y=-.02 top plane.
const FLOOR_TILES := [
	["BerthDeck",101.0,115.0,-37.0,-23.0],
	["SpurEntry",41.6,44.4,-13.4,7.0],
	["SpurTurn",44.4,56.4,-13.4,-10.6],
	["SpurSouth",53.6,56.4,-45.4,-13.4],
	["SpurEast",56.4,101.0,-45.4,-42.6],
	["SpurNorth",98.2,101.0,-42.6,-28.6],
]
# Exact exterior of that union; the final-to-first edge is the open station
# mouth. No rail crosses a turn, the apron join or the physical port approach.
const OUTLINE := [
	Vector2(41.6,7),Vector2(41.6,-13.4),Vector2(53.6,-13.4),
	Vector2(53.6,-45.4),Vector2(101,-45.4),Vector2(101,-37),
	Vector2(115,-37),Vector2(115,-23),Vector2(101,-23),
	Vector2(101,-28.6),Vector2(98.2,-28.6),Vector2(98.2,-42.6),
	Vector2(56.4,-42.6),Vector2(56.4,-10.6),Vector2(44.4,-10.6),Vector2(44.4,7),
]
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
	for tile in FLOOR_TILES:
		var center := Vector2((tile[1]+tile[2])*0.5,(tile[3]+tile[4])*0.5)-SITE_XZ
		_box(tile[0],Vector3(center.x,-0.2,center.y),Vector3(tile[2]-tile[1],0.4,tile[4]-tile[3]),deck,true)
	for index in OUTLINE.size()-1:
		var start: Vector2 = OUTLINE[index]
		var end: Vector2 = OUTLINE[index+1]
		var direction := (end-start).normalized()
		var outside := Vector2(direction.y,-direction.x)*0.12
		var center := (start+end)*0.5+outside-SITE_XZ
		var size := Vector3(absf(end.x-start.x),1.24,absf(end.y-start.y))
		if size.x < 0.001: size.x = 0.16
		if size.z < 0.001: size.z = 0.16
		_rail("SafetyEdge%02d" % index,Vector3(center.x,0.62,center.y),size,rail)
	for spec in [[&"approach",Vector3(-65,0,35.5)],[&"port-apron",Vector3(-7,0,0)],[&"hatch-control",Vector3(-5.9,0,-2.4)]]:
		var marker := Marker3D.new()
		marker.name = str(spec[0]).to_pascal_case()
		marker.position = spec[1]
		marker.set_meta("station_route_marker",true)
		marker.set_meta("route_id",spec[0])
		if spec[0] == &"approach": marker.set_meta(StationModuleContract.CONNECTION_SLOT_META,SLOT_ID)
		add_child(marker)
		_routes[spec[0]] = marker
	_berth = ShipBerth.new()
	_berth.name = "ShipBerth"
	_berth.berth_id = BERTH_ID
	_berth.compatibility_tags = PackedStringArray(["dynamic_gunship"])
	_berth.landing_volume_center = Vector3.ZERO
	_berth.landing_half_extents = Vector3(6.2,5.8,6)
	_berth.assist_capture_center = Vector3(0,8,-18)
	_berth.assist_capture_half_extents = Vector3(18,12,26)
	_berth.assist_capture_maximum_speed = 27
	_berth.assist_maximum_tilt_degrees = 68
	_berth.departure_lift_height = 3.5
	add_child(_berth)
	var landing_volume := Marker3D.new()
	landing_volume.name = "LandingVolumeCenter"
	_berth.add_child(landing_volume)
	var sign := Label3D.new()
	sign.name = "DynamicBerthSign"
	sign.text = "DYNAMIC  //  CANDIDATE BERTH\nPORT ACCESS"
	sign.position = Vector3(-4.5,2.3,6.9)
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
	var segments := ceili((run - 0.12) / 2.4)
	for index in segments + 1:
		var mesh := MeshInstance3D.new()
		mesh.name = "Post%02d" % index
		var offset := -run * 0.5 + 0.06 + (run - 0.12) * float(index) / segments
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
	return [&"approach", &"port-apron", &"hatch-control"]
func has_route_marker(route_id: StringName) -> bool:
	return _routes.has(route_id)
func get_route_marker(route_id: StringName) -> Marker3D:
	return _routes.get(route_id) as Marker3D
func get_route_transform(route_id: StringName) -> Transform3D:
	var marker := get_route_marker(route_id)
	return marker.global_transform if marker != null else Transform3D.IDENTITY
func get_integration_footprint() -> Dictionary:
	return {"anchor_transform": _anchor.global_transform, "local_min": Vector3(-66.6, -0.4, -15.6), "local_max": Vector3(7.2, 3, 37)}
func get_evidence_metadata() -> Dictionary:
	return {"evidence_status": &"modern_interpretation", "content_class": &"NEW", "source_bounded": false, "content_note": "Original Dynamic berth geometry and adjacency, not historical reconstruction."}
func get_component_roster() -> Dictionary:
	return StationModuleContract.build_component_roster(self)
func get_collision_contract() -> Dictionary:
	return StationModuleContract.build_collision_contract(self, WORLD_LAYER, _enabled)
func get_authority_contract() -> Dictionary:
	var contract := StationModuleContract.build_authority_contract(self)
	contract["authority_ids"] = PackedStringArray([str(BERTH_ID)])
	return contract
func get_performance_contract() -> Dictionary:
	return StationModuleContract.build_performance_contract(self, {"static_bodies": 21, "collision_shapes": 21, "mesh_instances": 320, "labels": 1, "lights": 0, "process_loops": 0, "physics_process_loops": 0})
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
