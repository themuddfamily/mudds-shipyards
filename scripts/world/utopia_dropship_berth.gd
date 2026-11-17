class_name UtopiaDropshipBerth
extends Node3D

## Original modern reachable Utopia deck. This infrastructure never spawns a
## craft; ShipyardWorld authors placement and ShipBerth owns docking authority.
const MODULE_ID := &"utopia-dropship-berth"
const BERTH_ID := &"utopia_home_berth"
const SLOT_ID := &"hub-utopia-dropship-berth"
const WORLD_LAYER := PhysicsLayers.WORLD
const SITE_XZ := Vector2(144,-30)
# Three disjoint plates meet at boundaries. The spine joins the exact
# supported north portal of the production Titan connector at z=36.6.
# All three visible/collision top faces share world y=.38.
const FLOOR_TILES := [
	["BerthDeck",137.5,150.5,-45.0,-15.0],
	["SpurNorth",133.6,136.4,-17.8,36.6],
	["SpurLink",136.4,137.5,-17.8,-15.0],
]
# Exact exterior union; the final-to-first edge is the open supported mouth.
const OUTLINE := [
	Vector2(133.6,36.6),Vector2(133.6,-17.8),Vector2(137.5,-17.8),
	Vector2(137.5,-45),Vector2(150.5,-45),Vector2(150.5,-15),
	Vector2(136.4,-15),Vector2(136.4,36.6),
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
	for spec in [[&"approach",Vector3(-9,0,66.1)],[&"stern-apron",Vector3(0,0,14)],[&"hatch-control",Vector3(-3.4,0,10.1)]]:
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
	_berth.compatibility_tags = PackedStringArray(["utopia_supply"])
	_berth.landing_volume_center = Vector3.ZERO
	_berth.landing_half_extents = Vector3(5.5,6,14)
	_berth.assist_capture_center = Vector3(0,8,-20)
	_berth.assist_capture_half_extents = Vector3(18,14,32)
	_berth.assist_capture_maximum_speed = 28
	_berth.assist_maximum_tilt_degrees = 70
	_berth.departure_lift_height = 4
	add_child(_berth)
	var landing_volume := Marker3D.new()
	landing_volume.name = "LandingVolumeCenter"
	_berth.add_child(landing_volume)
	# The sign belongs to the rear rail. Its solid post and backing match
	# their rendered pieces and stand outside the walk apron and ramp.
	var mount := get_node("SafetyEdge05") as StaticBody3D
	_mounted_box(mount,"SignPost",Vector3(-5.2,1.15,15.12),Vector3(0.12,2.3,0.12),rail)
	_mounted_box(mount,"SignBacking",Vector3(-5.2,2.3,15.12),Vector3(2.2,0.7,0.12),deck)
	var sign := Label3D.new()
	sign.name = "UtopiaBerthSign"
	sign.text = "UTOPIA  //  CANDIDATE BERTH\nSTERN ACCESS"
	sign.position = Vector3(-5.2,2.3,15.185)-mount.position
	sign.font_size = 36
	sign.pixel_size = 0.0015
	sign.outline_size = 6
	mount.add_child(sign)
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

func _mounted_box(body: StaticBody3D, node_name: String, center: Vector3, size: Vector3, material: Material) -> void:
	var collision := CollisionShape3D.new()
	collision.name = node_name + "Collision"
	collision.position = center-body.position
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	mesh.position = collision.position
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	body.add_child(mesh)

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
	return [&"approach", &"stern-apron", &"hatch-control"]
func has_route_marker(route_id: StringName) -> bool:
	return _routes.has(route_id)
func get_route_marker(route_id: StringName) -> Marker3D:
	return _routes.get(route_id) as Marker3D
func get_route_transform(route_id: StringName) -> Transform3D:
	var marker := get_route_marker(route_id)
	return marker.global_transform if marker != null else Transform3D.IDENTITY
func get_integration_footprint() -> Dictionary:
	return {"anchor_transform": _anchor.global_transform, "local_min": Vector3(-10.6, -0.4, -15.2), "local_max": Vector3(6.7, 3, 66.6)}
func get_evidence_metadata() -> Dictionary:
	return {"evidence_status": &"modern_interpretation", "content_class": &"NEW", "source_bounded": false, "content_note": "Original Utopia berth geometry and adjacency, not historical reconstruction."}
func get_component_roster() -> Dictionary:
	return StationModuleContract.build_component_roster(self)
func get_collision_contract() -> Dictionary:
	return StationModuleContract.build_collision_contract(self, WORLD_LAYER, _enabled)
func get_authority_contract() -> Dictionary:
	var contract := StationModuleContract.build_authority_contract(self)
	contract["authority_ids"] = PackedStringArray([str(BERTH_ID)])
	return contract
func get_performance_contract() -> Dictionary:
	return StationModuleContract.build_performance_contract(self, {"static_bodies": 10, "collision_shapes": 12, "mesh_instances": 110, "labels": 1, "lights": 0, "process_loops": 0, "physics_process_loops": 0})
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
