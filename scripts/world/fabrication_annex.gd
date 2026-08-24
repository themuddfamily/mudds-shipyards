class_name FabricationAnnex
extends Node3D

## Standalone fabrication floor for a future station integration pass. Everything
## here is a modern interpretation: it carries routes and collision, but owns no
## ship, berth, combat, reward, interaction, or activity authority.

const MODULE_ID := &"fabrication_annex"
const WORLD_LAYER := PhysicsLayers.WORLD
const EVIDENCE_STATUS := &"modern_interpretation"
const INTERPRETATION_LABEL := &"new"
const SOURCE_CONFIDENCE := &"none"
const GROSS_HORIZONTAL_AREA_M2 := 480.0
const FIXED_EQUIPMENT_FOOTPRINT_M2 := 69.30
const FLOOR_AFTER_FIXED_EQUIPMENT_M2 := 410.70
const LUMINAIRE_SIZE := Vector3(1.8, 0.12, 0.3)
const WORK_BAY_SURFACE_SIZE := Vector3(8.0, 0.4, 14.0)
const WORK_BAY_SURFACE_POSITIONS := [
	Vector3(-7.0, -0.2, 11.0),
	Vector3(7.0, -0.2, 11.0),
]
const WORK_BAY_SURFACE_BATCH_KEY := "deck:8.000:0.400:14.000"
const NON_WORK_BAY_SURFACE_DEFINITIONS := [
	{
		"id": &"connector_apron",
		"label": "ConnectorApron",
		"size": Vector3(8.0, 0.4, 4.0),
		"position": Vector3(0.0, -0.2, 2.0),
		"area": 32.0,
	},
	{
		"id": &"central_through_aisle",
		"label": "CentralThroughAisle",
		"size": Vector3(6.0, 0.4, 14.0),
		"position": Vector3(0.0, -0.2, 11.0),
		"area": 84.0,
	},
	{
		"id": &"port_side_bypass",
		"label": "PortSideBypass",
		"size": Vector3(3.0, 0.4, 14.0),
		"position": Vector3(-12.5, -0.2, 11.0),
		"area": 42.0,
	},
	{
		"id": &"starboard_side_bypass",
		"label": "StarboardSideBypass",
		"size": Vector3(3.0, 0.4, 14.0),
		"position": Vector3(12.5, -0.2, 11.0),
		"area": 42.0,
	},
	{
		"id": &"rear_cross_aisle",
		"label": "RearCrossAisle",
		"size": Vector3(28.0, 0.4, 2.0),
		"position": Vector3(0.0, -0.2, 19.0),
		"area": 56.0,
	},
]
const NON_WORK_BAY_SURFACE_RENDER_NAME := &"FloorSlabRenderBatch"
const ROOF_COLUMN_SIZE := Vector3(0.45, 5.6, 0.45)
const ROOF_COLUMN_POSITIONS := [
	Vector3(-11.0, 2.8, 4.5),
	Vector3(-11.0, 2.8, 19.0),
	Vector3(-3.0, 2.8, 4.5),
	Vector3(-3.0, 2.8, 19.0),
	Vector3(3.0, 2.8, 4.5),
	Vector3(3.0, 2.8, 19.0),
	Vector3(11.0, 2.8, 4.5),
	Vector3(11.0, 2.8, 19.0),
]
const ROOF_COLUMN_BATCH_KEY := "structure:0.450:5.600:0.450"
const FABRICATOR_BASE_SIZE := Vector3(4.0, 0.4, 3.0)
const FABRICATOR_BASE_POSITIONS := [
	Vector3(-7.0, 0.2, 7.0),
	Vector3(-7.0, 0.2, 15.0),
	Vector3(7.0, 0.2, 7.0),
	Vector3(7.0, 0.2, 15.0),
]
const FABRICATOR_BASE_BATCH_KEY := "machine:4.000:0.400:3.000"
const WORK_BENCH_SIZE := Vector3(1.0, 0.9, 3.0)
const WORK_BENCH_POSITIONS := [
	Vector3(-3.5, 0.45, 7.0),
	Vector3(-3.5, 0.45, 15.0),
	Vector3(3.5, 0.45, 7.0),
	Vector3(3.5, 0.45, 15.0),
]
const WORK_BENCH_BATCH_KEY := "structure:1.000:0.900:3.000"
const MATERIAL_RACK_SIZE := Vector3(0.8, 2.2, 2.4)
const SOURCE_PRACTICAL_RANGE_M := 8.0
const PAIRED_POOL_RANGE_M := 11.75
const SOURCE_PRACTICAL_ENERGY := 3.2
const PAIRED_POOL_ENERGY := 4.8
const PRACTICAL_ATTENUATION := 1.0
const PRACTICAL_FADE_BEGIN_M := 18.0
const PRACTICAL_FADE_LENGTH_M := 8.0
const LUMINAIRE_POSITIONS := [
	Vector3(-8.5, 4.72, 7.0),
	Vector3(-8.5, 4.72, 14.5),
	Vector3(0.0, 4.72, 7.0),
	Vector3(0.0, 4.72, 14.5),
	Vector3(8.5, 4.72, 7.0),
	Vector3(8.5, 4.72, 14.5),
]
const PAIRED_POOL_DEFINITIONS := [
	{
		"pool_id": &"port",
		"node_name": &"PracticalPoolPort",
		"position": Vector3(-8.5, 4.6, 10.75),
		"color": Color("ffe0b0"),
		"source_positions": [Vector3(-8.5, 4.6, 7.0), Vector3(-8.5, 4.6, 14.5)],
	},
	{
		"pool_id": &"central",
		"node_name": &"PracticalPoolCentral",
		"position": Vector3(0.0, 4.6, 10.75),
		"color": Color("c9e2dd"),
		"source_positions": [Vector3(0.0, 4.6, 7.0), Vector3(0.0, 4.6, 14.5)],
	},
	{
		"pool_id": &"starboard",
		"node_name": &"PracticalPoolStarboard",
		"position": Vector3(8.5, 4.6, 10.75),
		"color": Color("ffe0b0"),
		"source_positions": [Vector3(8.5, 4.6, 7.0), Vector3(8.5, 4.6, 14.5)],
	},
]

const ROUTE_TRANSFORMS := {
	&"annex_inbound": Transform3D(Basis.IDENTITY, Vector3(0.0, 0.15, 0.0)),
	&"annex_central": Transform3D(Basis.IDENTITY, Vector3(0.0, 0.15, 11.0)),
	&"annex_port_bay": Transform3D(Basis.IDENTITY, Vector3(-7.0, 0.15, 11.0)),
	&"annex_starboard_bay": Transform3D(Basis.IDENTITY, Vector3(7.0, 0.15, 11.0)),
	&"annex_port_service": Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-14.0, 0.15, 12.0)),
	&"annex_starboard_service": Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(14.0, 0.15, 12.0)),
	&"annex_rear_cross": Transform3D(Basis.IDENTITY, Vector3(0.0, 0.15, 19.0)),
}
const CONNECTION_SLOTS := {
	&"annex_inbound": &"fabrication_annex_inbound",
}
const PERFORMANCE_BUDGETS := {
	"mesh_instances": 1,
	"multi_mesh_instances": 36,
	"geometry_instances": 37,
	"visible_geometry_copies": 203,
	"multi_mesh_drawn_copies": 198,
	"static_bodies": 34,
	"collision_shapes": 34,
	"labels": 6,
	"lights": 3,
	"process_loops": 0,
	"physics_process_loops": 0,
	"nodes": 123,
}
const OBSERVATION_GATE_PERFORMANCE_BUDGETS := {
	"mesh_instances": 1,
	"multi_mesh_instances": 36,
	"geometry_instances": 37,
	"visible_geometry_copies": 204,
	"multi_mesh_drawn_copies": 199,
	"static_bodies": 35,
	"collision_shapes": 35,
	"labels": 6,
	"lights": 3,
	"process_loops": 0,
	"physics_process_loops": 0,
	"nodes": 125,
}

## Production integration seam. The standalone module keeps its complete rear
## rail; ShipyardWorld opts into an atomic four-metre opening only when the
## collision-backed Observation connector is present at the same boundary.
@export var observation_rear_gate_open := false

var _built := false
var _enabled := true
var _build_root: Node3D
var _route_markers: Dictionary = {}
var _materials: Dictionary = {}
var _mesh_cache: Dictionary = {}
var _mesh_batches: Dictionary = {}
var _authored_batch_transforms: Dictionary = {}
var _name_counters: Dictionary = {}


func _ready() -> void:
	set_meta(&"station_module", true)
	add_to_group(&"station_modules", true)
	_build_once()


func _build_once() -> void:
	if _built:
		return
	_built = true
	_build_root = Node3D.new()
	_build_root.name = "GeneratedAnnex"
	add_child(_build_root)
	_make_materials()
	_build_routes()
	_build_floor()
	_build_guardrails()
	_build_work_bays()
	_build_structure_and_dressing()
	_build_lighting()
	_flush_mesh_batches()
	set_module_enabled(_enabled)


func _make_materials() -> void:
	# One shared map family, separated by the physical finish each part performs.
	# Keeping the authored colours and scalar PBR values here preserves the
	# annex's cool steel/teal identity while the response identifies walked,
	# structural, painted-machine and close metal surfaces at player range.
	_materials[&"deck"] = _panel_material(
		Color("34414a"), 0.72, 0.45, StationSurfaceKit.PanelFinish.WALKED_DECK
	)
	_materials[&"structure"] = _panel_material(
		Color("202a31"), 0.76, 0.45, StationSurfaceKit.PanelFinish.STRUCTURAL_ALLOY
	)
	_materials[&"machine"] = _panel_material(
		Color("68727a"), 0.62, 0.5, StationSurfaceKit.PanelFinish.PAINTED_METAL
	)
	_materials[&"hazard"] = _panel_material(
		Color("d58b27"), 0.5, 0.35, StationSurfaceKit.PanelFinish.PAINTED_METAL
	)
	_materials[&"rail"] = _panel_material(
		Color("aeb9bc"), 0.5, 0.55, StationSurfaceKit.PanelFinish.METAL_TRIM
	)
	_materials[&"accent"] = _panel_material(
		Color("3b9ca2"), 0.38, 0.4, StationSurfaceKit.PanelFinish.METAL_TRIM
	)
	_materials[&"ceiling"] = _panel_material(
		Color("151d23"), 0.86, 0.32, StationSurfaceKit.PanelFinish.STRUCTURAL_ALLOY
	)
	_materials[&"floor_inlay"] = _panel_material(
		Color("19353b"), 0.64, 0.28, StationSurfaceKit.PanelFinish.WALKED_DECK
	)
	_materials[&"luminous"] = _emissive_material(Color("64d9dc"), 1.7)


func _panel_material(
		color: Color,
		roughness: float,
		metallic: float,
		finish: StationSurfaceKit.PanelFinish
	) -> StandardMaterial3D:
	var result := _material(color, roughness, metallic)
	# 0.30 is the production-compliant large station-module panel scale.
	StationSurfaceKit.apply_panel_triplanar(result, 0.30, finish)
	# The shared recipe owns maps and clearcoat only, never this room's hue.
	result.albedo_color = color
	return result


func _material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = roughness
	result.metallic = metallic
	return result


func _emissive_material(color: Color, energy: float) -> StandardMaterial3D:
	var result := _material(color.darkened(0.38), 0.32, 0.18)
	result.emission_enabled = true
	result.emission = color
	result.emission_energy_multiplier = energy
	return result


func _build_routes() -> void:
	for route_id: StringName in ROUTE_TRANSFORMS:
		var marker := Marker3D.new()
		marker.name = String(route_id).to_pascal_case()
		marker.transform = ROUTE_TRANSFORMS[route_id]
		if CONNECTION_SLOTS.has(route_id):
			marker.set_meta(StationModuleContract.CONNECTION_SLOT_META, CONNECTION_SLOTS[route_id])
		_build_root.add_child(marker)
		_route_markers[route_id] = marker


func _build_floor() -> void:
	# These five differently sized slabs share one immutable walked-deck finish.
	# Their presentation is one combined surface; collision and census ownership
	# stay on five independently named bodies at the exact authored transforms.
	for definition_variant in NON_WORK_BAY_SURFACE_DEFINITIONS:
		var definition := definition_variant as Dictionary
		_add_surface(
			definition.id as StringName,
			definition.label as String,
			definition.size as Vector3,
			definition.position as Vector3,
			float(definition.area)
		)
	_add_batched_surface(&"port_work_bay", "PortWorkBay", WORK_BAY_SURFACE_POSITIONS[0], 112.0)
	_add_batched_surface(&"starboard_work_bay", "StarboardWorkBay", WORK_BAY_SURFACE_POSITIONS[1], 112.0)
	_add_combined_floor_render()


func _add_surface(id: StringName, label: String, size: Vector3, at: Vector3, area: float) -> void:
	var body := _add_collision_only(label, size, at)
	_tag_surface(body, id, area)


func _add_combined_floor_render() -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var authored_parts: Array[Dictionary] = []
	for definition_variant in NON_WORK_BAY_SURFACE_DEFINITIONS:
		var definition := definition_variant as Dictionary
		var transform := Transform3D(Basis.IDENTITY, definition.position as Vector3)
		# The source meshes are intentionally transient. The committed combined
		# surface is the only retained mesh resource for this five-piece family.
		tool.append_from(
			StationSurfaceKit.rounded_box_mesh(definition.size as Vector3),
			0,
			transform
		)
		authored_parts.append({
			"id": definition.id,
			"size": definition.size,
			"transform": transform,
		})
	var renderer := MeshInstance3D.new()
	renderer.name = NON_WORK_BAY_SURFACE_RENDER_NAME
	renderer.mesh = tool.commit()
	renderer.material_override = _materials[&"deck"]
	renderer.set_meta(&"fabrication_floor_render_parts", authored_parts)
	renderer.set_meta(&"authored_visible_copy_count", authored_parts.size())
	_build_root.add_child(renderer)


func _add_batched_surface(id: StringName, label: String, at: Vector3, area: float) -> void:
	# The two work-bay slabs retain independent collision/census bodies. Their
	# identical immutable deck renderers share one submission at the same poses.
	var body := _add_collision_only(label, WORK_BAY_SURFACE_SIZE, at)
	_tag_surface(body, id, area)
	_add_mesh("WorkBaySurface", WORK_BAY_SURFACE_SIZE, at, &"deck")


func _tag_surface(body: StaticBody3D, id: StringName, area: float) -> void:
	body.set_meta(&"walkable_surface", true)
	body.set_meta(&"walkable_surface_id", id)
	body.set_meta(&"walkable_surface_kind", &"level")
	body.set_meta(&"walkable_surface_owner", MODULE_ID)
	body.set_meta(&"horizontal_area_m2", area)


func _build_guardrails() -> void:
	# Outer edge protection leaves deliberate four-metre service gates at z=12.
	for x in [-14.0, 14.0]:
		for z in [7.0, 17.0]:
			_add_rail_run(Vector3(x, 0.72, z), Vector3(0.14, 1.44, 6.0))
	if observation_rear_gate_open:
		var north_return := _add_rail_run(Vector3(-8.0, 0.72, 20.0), Vector3(12.0, 1.44, 0.14))
		north_return.set_meta(&"fabrication_rear_rail_return_segment", &"north")
		var south_return := _add_rail_run(Vector3(8.0, 0.72, 20.0), Vector3(12.0, 1.44, 0.14))
		south_return.set_meta(&"fabrication_rear_rail_return_segment", &"south")
	else:
		_add_rail_run(Vector3(0.0, 0.72, 20.0), Vector3(28.0, 1.44, 0.14))
	for x in [-4.0, 4.0]:
		_add_rail_run(Vector3(x, 0.72, 2.0), Vector3(0.14, 1.44, 4.0))


func _add_rail_run(at: Vector3, collider_size: Vector3) -> StaticBody3D:
	# The conservative 1.44 m collision volume must never be rendered: doing so
	# turns every rail into an opaque waist-high wall. The actual two rails and
	# posts below remain the complete visible assembly.
	var collider := _add_collision_only("GuardrailCollider", collider_size, at)
	collider.set_meta(&"safety_rail", true)
	var horizontal := collider_size.x > collider_size.z
	var rail_size := Vector3(collider_size.x, 0.1, collider_size.z)
	for y in [0.55, 1.1]:
		_add_mesh("Rail", rail_size, Vector3(at.x, y, at.z), &"rail")
	var length := collider_size.x if horizontal else collider_size.z
	var count := int(floor(length / 2.0))
	for index in count + 1:
		var offset := -length * 0.5 + minf(length, float(index) * 2.0)
		var position := at
		if horizontal:
			position.x += offset
		else:
			position.z += offset
		_add_mesh("RailPost", Vector3(0.12, 1.2, 0.12), Vector3(position.x, 0.6, position.z), &"rail")
	return collider


func _add_collision_only(label: String, size: Vector3, at: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = _next_stable_name(label)
	body.position = at
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	shape.name = "Collision"
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	_build_root.add_child(body)
	return body


func _build_work_bays() -> void:
	for raw_side in [-1.0, 1.0]:
		var side: float = raw_side
		var bay_x: float = side * 7.0
		var bench_x: float = side * 3.5
		var rack_x: float = side * 10.6
		for z in [7.0, 15.0]:
			_add_batched_fixed_equipment("FabricatorBase", FABRICATOR_BASE_SIZE, Vector3(bay_x, 0.2, z), &"machine")
			_add_mesh("FabricatorDeck", Vector3(3.55, 0.1, 2.55), Vector3(bay_x, 0.45, z), &"floor_inlay")
			_add_mesh("FabricatorColumn", Vector3(0.5, 2.8, 0.5), Vector3(bay_x - side * 1.45, 1.8, z - 1.0), &"structure")
			_add_mesh("FabricatorColumn", Vector3(0.5, 2.8, 0.5), Vector3(bay_x + side * 1.45, 1.8, z - 1.0), &"structure")
			_add_mesh("FabricatorGantry", Vector3(3.4, 0.45, 0.55), Vector3(bay_x, 3.0, z - 1.0), &"hazard")
			_add_mesh("FabricatorHead", Vector3(1.1, 1.5, 1.1), Vector3(bay_x, 1.65, z), &"accent")
			_add_mesh("FabricatorNozzle", Vector3(0.28, 0.72, 0.28), Vector3(bay_x, 0.75, z), &"luminous")
			_add_mesh("FabricatorControl", Vector3(0.18, 0.72, 1.05), Vector3(bay_x - side * 1.76, 1.25, z + 0.55), &"machine")
			_add_mesh("FabricatorStatus", Vector3(0.08, 0.18, 0.72), Vector3(bay_x - side * 1.87, 1.35, z + 0.55), &"luminous")
			_add_batched_fixed_equipment("WorkBench", WORK_BENCH_SIZE, Vector3(bench_x, 0.45, z), &"structure")
			_add_mesh("BenchBackboard", Vector3(0.16, 1.35, 2.7), Vector3(bench_x + side * 0.42, 1.5, z), &"machine")
			for tool_z in [-0.72, 0.0, 0.72]:
				_add_mesh("ToolDock", Vector3(0.12, 0.22, 0.3), Vector3(bench_x - side * 0.1, 1.62, z + tool_z), &"hazard")
			_add_batched_fixed_equipment("MaterialRack", MATERIAL_RACK_SIZE, Vector3(rack_x, 1.1, z), &"structure")
			for shelf_y in [0.55, 1.15, 1.75]:
				_add_mesh("RackShelf", Vector3(0.86, 0.08, 2.3), Vector3(rack_x, shelf_y, z), &"hazard")
			for canister_z in [-0.72, 0.0, 0.72]:
				_add_mesh("RackCanister", Vector3(0.42, 0.42, 0.42), Vector3(rack_x - side * 0.08, 1.42, z + canister_z), &"accent")


func _build_structure_and_dressing() -> void:
	for column_position in ROOF_COLUMN_POSITIONS:
		_add_batched_fixed_equipment(
			"RoofColumn",
			ROOF_COLUMN_SIZE,
			column_position as Vector3,
			&"structure"
		)
	for z in [5.0, 11.0, 17.0]:
		_add_mesh("OverheadCrossbeam", Vector3(27.0, 0.45, 0.5), Vector3(0.0, 5.35, z), &"structure")
	# Deep ceiling coffers and longitudinal spines turn the former open frame
	# into a complete industrial hall while retaining the central clerestory.
	for x in [-8.25, 8.25]:
		for z in [7.65, 12.55, 17.45]:
			_add_mesh("CeilingCoffer", Vector3(9.8, 0.18, 4.5), Vector3(x, 5.52, z), &"ceiling")
	for x in [-13.1, -3.2, 3.2, 13.1]:
		_add_mesh("RoofSpine", Vector3(0.34, 0.34, 15.3), Vector3(x, 5.15, 12.25), &"structure")
	for z in [6.5, 9.5, 12.5, 15.5, 18.5]:
		_add_mesh("ClerestoryRib", Vector3(5.8, 0.16, 0.24), Vector3(0.0, 5.5, z), &"rail")

	# A layered portal and shallow fascia give the inbound threshold a readable
	# facade without introducing collision or narrowing the six-metre route.
	for x in [-8.5, 8.5]:
		_add_mesh("EntryFascia", Vector3(10.4, 1.15, 0.32), Vector3(x, 4.45, 4.42), &"ceiling")
	for x in [-2.72, 2.72]:
		_add_mesh("EntryJamb", Vector3(0.26, 4.2, 0.34), Vector3(x, 2.35, 4.34), &"hazard")
	_add_mesh("EntryHeader", Vector3(5.7, 0.64, 0.38), Vector3(0.0, 4.55, 4.38), &"structure")
	_add_mesh("EntryLightBand", Vector3(5.25, 0.1, 0.12), Vector3(0.0, 4.72, 4.14), &"luminous")
	_add_mesh("MainSignBacking", Vector3(6.2, 1.05, 0.16), Vector3(0.0, 3.4, 4.25), &"structure")
	for x in [-7.0, 7.0]:
		_add_mesh("BaySignBacking", Vector3(4.4, 0.82, 0.14), Vector3(x, 3.65, 10.0), &"structure")
	# Low curb makes bay zoning legible without closing any approach.
	for x in [-3.0, 3.0]:
		for z in [6.0, 16.0]:
			_add_mesh("HazardCurb", Vector3(0.22, 0.08, 4.0), Vector3(x, 0.04, z), &"hazard")
	for x in [-9.5, 9.5]:
		_add_mesh("ServiceConduit", Vector3(0.22, 0.22, 13.0), Vector3(x, 4.65, 11.0), &"accent")
	# Flush deck graphics ground each work cell and keep the central route clear.
	for x in [-9.45, -4.55, 4.55, 9.45]:
		_add_mesh("BayGuideLine", Vector3(0.09, 0.025, 14.7), Vector3(x, 0.018, 12.15), &"floor_inlay")
	for x in [-7.0, 7.0]:
		for z in [5.05, 10.9, 13.1, 18.95]:
			_add_mesh("BayCrossMark", Vector3(4.72, 0.027, 0.09), Vector3(x, 0.02, z), &"hazard")
	for x in [-2.55, 2.55]:
		_add_mesh("AisleGuide", Vector3(0.1, 0.028, 14.8), Vector3(x, 0.021, 12.1), &"luminous")
	_add_label("FABRICATION ANNEX", Vector3(0.0, 3.4, 4.25), 0.65)
	_add_label("PORT BAY", Vector3(-7.0, 3.65, 10.0), 0.5)
	_add_label("STARBOARD BAY", Vector3(7.0, 3.65, 10.0), 0.5)


func _add_label(text: String, at: Vector3, font_size: float) -> void:
	# One culled face per viewing direction prevents Godot's rear-face text from
	# reading as a giant mirrored word across the hall.
	for rear_facing in [false, true]:
		var label := Label3D.new()
		label.name = "%s%s" % [text.to_pascal_case(), "Rear" if rear_facing else "Front"]
		label.text = text
		label.position = at + Vector3(0.0, 0.0, 0.1 if rear_facing else -0.1)
		label.rotation.y = 0.0 if rear_facing else PI
		label.font_size = 72
		label.pixel_size = font_size / 72.0
		label.modulate = Color("d9ffff")
		label.outline_modulate = Color("071216")
		label.outline_size = 12
		label.double_sided = false
		_build_root.add_child(label)


func _build_lighting() -> void:
	# All six visible fittings stay at their authored ceiling positions. Only the
	# shadowless light volumes are consolidated: each longitudinal same-colour
	# pair becomes one midpoint pool whose radius contains both former spheres.
	for luminaire_position in LUMINAIRE_POSITIONS:
		_add_mesh("Luminaire", LUMINAIRE_SIZE, luminaire_position as Vector3, &"luminous")
	for definition_variant in PAIRED_POOL_DEFINITIONS:
		var definition := definition_variant as Dictionary
		var light := OmniLight3D.new()
		light.name = StringName(definition.node_name)
		light.position = definition.position as Vector3
		light.light_color = definition.color as Color
		light.light_energy = PAIRED_POOL_ENERGY
		light.omni_range = PAIRED_POOL_RANGE_M
		light.omni_attenuation = PRACTICAL_ATTENUATION
		light.shadow_enabled = false
		light.distance_fade_enabled = true
		light.distance_fade_begin = PRACTICAL_FADE_BEGIN_M
		light.distance_fade_length = PRACTICAL_FADE_LENGTH_M
		light.set_meta(&"fabrication_paired_pool", definition.pool_id)
		_build_root.add_child(light)


func _add_solid(label: String, size: Vector3, at: Vector3, material_id: StringName) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = _next_stable_name(label)
	body.position = at
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	shape.name = "Collision"
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	mesh.name = "%sMesh" % label
	mesh.mesh = StationSurfaceKit.rounded_box_mesh_cached(size, _mesh_cache)
	mesh.material_override = _materials[material_id]
	body.add_child(mesh)
	_build_root.add_child(body)
	return body


func _add_batched_fixed_equipment(
		label: String,
		size: Vector3,
		at: Vector3,
		material_id: StringName
	) -> StaticBody3D:
	# Collision identity remains one body/shape per physical column. Only its
	# identical, presentation-only child renderer moves into the existing batch
	# path, preserving the same cached mesh, material and local visible pose.
	var body := _add_collision_only(label, size, at)
	body.set_meta(&"fixed_equipment_footprint", true)
	body.set_meta(
		&"fixed_equipment_id",
		StringName("%s_%0.2f_%0.2f" % [label.to_snake_case(), at.x, at.z])
	)
	_add_mesh(label, size, at, material_id)
	return body


func _add_mesh(label: String, size: Vector3, at: Vector3, material_id: StringName) -> void:
	# Non-colliding repeated dressing is submitted by size/material batch. This
	# keeps the broad room legible without paying one scene node and draw submit
	# for every post, shelf, brace, and luminaire.
	var key := "%s:%0.3f:%0.3f:%0.3f" % [material_id, size.x, size.y, size.z]
	if not _mesh_batches.has(key):
		_mesh_batches[key] = {"label": label, "size": size, "material_id": material_id, "transforms": []}
	(_mesh_batches[key].transforms as Array).append(Transform3D(Basis.IDENTITY, at))


func _flush_mesh_batches() -> void:
	for key: String in _mesh_batches:
		var batch := _mesh_batches[key] as Dictionary
		var transforms := batch.transforms as Array
		var multi_mesh := MultiMesh.new()
		multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
		multi_mesh.mesh = StationSurfaceKit.rounded_box_mesh_cached(batch.size as Vector3, _mesh_cache)
		multi_mesh.instance_count = transforms.size()
		for index in transforms.size():
			multi_mesh.set_instance_transform(index, transforms[index] as Transform3D)
		multi_mesh.buffer = _multi_mesh_transform_buffer(transforms)
		var instance := MultiMeshInstance3D.new()
		instance.name = _next_stable_name("%sBatch" % str(batch.label))
		instance.multimesh = multi_mesh
		instance.material_override = _materials[batch.material_id]
		instance.set_meta(&"fabrication_annex_batch_key", key)
		_build_root.add_child(instance)
		_authored_batch_transforms[key] = transforms.duplicate(true)
	_mesh_batches.clear()


func _multi_mesh_transform_buffer(transforms: Array) -> PackedFloat32Array:
	var buffer := PackedFloat32Array()
	buffer.resize(transforms.size() * 12)
	for index in transforms.size():
		var value := transforms[index] as Transform3D
		var offset := index * 12
		buffer[offset + 0] = value.basis.x.x
		buffer[offset + 1] = value.basis.y.x
		buffer[offset + 2] = value.basis.z.x
		buffer[offset + 3] = value.origin.x
		buffer[offset + 4] = value.basis.x.y
		buffer[offset + 5] = value.basis.y.y
		buffer[offset + 6] = value.basis.z.y
		buffer[offset + 7] = value.origin.y
		buffer[offset + 8] = value.basis.x.z
		buffer[offset + 9] = value.basis.y.z
		buffer[offset + 10] = value.basis.z.z
		buffer[offset + 11] = value.origin.z
	return buffer


func _next_stable_name(label: String) -> String:
	var index := int(_name_counters.get(label, 0))
	_name_counters[label] = index + 1
	return label if index == 0 else "%s%02d" % [label, index]


func get_module_id() -> StringName:
	return MODULE_ID


func get_module_anchor() -> Node3D:
	return self


func get_route_ids() -> Array[StringName]:
	var route_ids: Array[StringName] = []
	for route_id: StringName in ROUTE_TRANSFORMS:
		route_ids.append(route_id)
	return route_ids


func has_route_marker(route_id: StringName) -> bool:
	return _route_markers.has(route_id) and is_instance_valid(_route_markers[route_id])


func get_route_marker(route_id: StringName) -> Node3D:
	return _route_markers.get(route_id) as Node3D


func get_route_transform(route_id: StringName) -> Transform3D:
	var marker := get_route_marker(route_id)
	return marker.global_transform if marker != null else Transform3D()


func get_connection_slots() -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	for route_id: StringName in CONNECTION_SLOTS:
		var marker := get_route_marker(route_id)
		slots.append({
			"slot_id": CONNECTION_SLOTS[route_id],
			"route_id": route_id,
			"local_transform": marker.transform if marker != null else Transform3D(),
		})
	return slots.duplicate(true)


func get_standable_surface_roster() -> Array[Dictionary]:
	var roster: Array[Dictionary] = []
	for raw_body in StationModuleContract.collect_static_bodies(self):
		var body := raw_body as StaticBody3D
		if not bool(body.get_meta(&"walkable_surface", false)):
			continue
		var shape := _body_box_shape(body)
		roster.append({
			"id": StringName(body.get_meta(&"walkable_surface_id", &"")),
			"kind": StringName(body.get_meta(&"walkable_surface_kind", &"")),
			"size_m": Vector2(shape.size.x, shape.size.z) if shape != null else Vector2.ZERO,
			"horizontal_area_m2": _horizontal_footprint_m2(body),
			"local_transform": body.transform,
			"body_path": get_path_to(body),
		})
	roster.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.id) < str(b.id))
	return roster


func get_fixed_equipment_footprint_roster() -> Array[Dictionary]:
	var roster: Array[Dictionary] = []
	for raw_body in StationModuleContract.collect_static_bodies(self):
		var body := raw_body as StaticBody3D
		if not bool(body.get_meta(&"fixed_equipment_footprint", false)):
			continue
		var shape := _body_box_shape(body)
		roster.append({
			"id": StringName(body.get_meta(&"fixed_equipment_id", &"")),
			"size_m": Vector2(shape.size.x, shape.size.z) if shape != null else Vector2.ZERO,
			"horizontal_footprint_m2": _horizontal_footprint_m2(body),
			"local_transform": body.transform,
			"body_path": get_path_to(body),
		})
	roster.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.id) < str(b.id))
	return roster


func get_walkable_area_contract() -> Dictionary:
	var slab_union := _sum_roster_area(get_standable_surface_roster(), &"horizontal_area_m2")
	var fixed_equipment := _sum_roster_area(get_fixed_equipment_footprint_roster(), &"horizontal_footprint_m2")
	return {
		"method": &"live_box_collision_projected_level_union_minus_live_fixed_equipment_footprints",
		"station_census_contribution_m2": slab_union,
		"gross_horizontal_area_m2": slab_union,
		"fixed_equipment_footprint_m2": fixed_equipment,
		"floor_after_fixed_equipment_m2": slab_union - fixed_equipment,
		"full_clear_walkable_area_claimed": false,
		"unsubtracted_obstruction_classes": PackedStringArray(["guardrails", "edge collision"]),
		"true_ramp_area_m2": 0.0,
		"projected_ramp_area_m2": 0.0,
		"surface_count": get_standable_surface_roster().size(),
		"fixed_equipment_count": get_fixed_equipment_footprint_roster().size(),
		"station_census_scope": &"authoritative_usable_level_collision_surface_union",
	}


func get_render_submission_contract() -> Dictionary:
	var mesh_nodes := find_children("*", "MeshInstance3D", true, false)
	var mesh_submissions := mesh_nodes.size()
	var mesh_drawn_copies := 0
	for raw_mesh in mesh_nodes:
		var mesh_node := raw_mesh as MeshInstance3D
		mesh_drawn_copies += int(mesh_node.get_meta(&"authored_visible_copy_count", 1))
	var batch_nodes := find_children("*", "MultiMeshInstance3D", true, false)
	var drawn_copies := 0
	var buffer_float_count := 0
	var stored_transform_count := 0
	var buffers_match_authored := batch_nodes.size() == _authored_batch_transforms.size()
	var live_batch_keys := PackedStringArray()
	for raw_node in batch_nodes:
		var node := raw_node as MultiMeshInstance3D
		var batch_key := str(node.get_meta(&"fabrication_annex_batch_key", ""))
		live_batch_keys.append(batch_key)
		var authored := _authored_batch_transforms.get(batch_key, []) as Array
		var multi_mesh := node.multimesh
		if multi_mesh == null:
			buffers_match_authored = false
			continue
		var forward_plus_buffer := RenderingServer.multimesh_get_buffer(multi_mesh.get_rid())
		drawn_copies += multi_mesh.instance_count
		buffer_float_count += forward_plus_buffer.size()
		stored_transform_count += authored.size()
		var expected_buffer := _multi_mesh_transform_buffer(authored)
		buffers_match_authored = (
			buffers_match_authored
			and forward_plus_buffer.size() == multi_mesh.instance_count * 12
			and authored.size() == multi_mesh.instance_count
			and forward_plus_buffer == expected_buffer
		)
	live_batch_keys.sort()
	return {
		"multi_mesh_batches": batch_nodes.size(),
		"multi_mesh_drawn_copies": drawn_copies,
		"mesh_instance_submissions": mesh_submissions,
		"geometry_submissions": mesh_submissions + batch_nodes.size(),
		"visible_geometry_copies": mesh_drawn_copies + drawn_copies,
		"authored_transform_count": stored_transform_count,
		"forward_plus_buffer_float_count": buffer_float_count,
		"forward_plus_buffers_match_authored": buffers_match_authored,
		"batch_keys": live_batch_keys,
		"authored_batch_transforms": _authored_batch_transforms.duplicate(true),
	}


func get_floor_render_optimization_contract() -> Dictionary:
	var renderer := _build_root.get_node_or_null(NodePath(str(NON_WORK_BAY_SURFACE_RENDER_NAME))) \
		as MeshInstance3D
	var live_parts := (
		renderer.get_meta(&"fabrication_floor_render_parts", []) as Array
		if renderer != null
		else []
	)
	var parts_exact := live_parts.size() == NON_WORK_BAY_SURFACE_DEFINITIONS.size()
	for index in mini(live_parts.size(), NON_WORK_BAY_SURFACE_DEFINITIONS.size()):
		var live := live_parts[index] as Dictionary
		var expected := NON_WORK_BAY_SURFACE_DEFINITIONS[index] as Dictionary
		parts_exact = parts_exact \
			and StringName(live.get("id", &"")) == StringName(expected.id) \
			and (live.get("size", Vector3.ZERO) as Vector3).is_equal_approx(expected.size as Vector3) \
			and (live.get("transform", Transform3D()) as Transform3D).is_equal_approx(
				Transform3D(Basis.IDENTITY, expected.position as Vector3)
			)
	var mesh := renderer.mesh as ArrayMesh if renderer != null else null
	var vertex_count := 0
	if mesh != null and mesh.get_surface_count() == 1:
		var arrays := mesh.surface_get_arrays(0)
		if arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array:
			vertex_count = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var render_state_exact: bool = (
		renderer != null
		and renderer.name == NON_WORK_BAY_SURFACE_RENDER_NAME
		and mesh != null
		and mesh.get_surface_count() == 1
		and vertex_count == NON_WORK_BAY_SURFACE_DEFINITIONS.size() * 324
		and mesh.get_aabb().is_equal_approx(AABB(Vector3(-14.0, -0.4, 0.0), Vector3(28.0, 0.4, 20.0)))
		and renderer.material_override == _materials[&"deck"]
		and renderer.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		and is_zero_approx(renderer.visibility_range_begin)
		and is_zero_approx(renderer.visibility_range_end)
		and is_zero_approx(renderer.extra_cull_margin)
		and int(renderer.get_meta(&"authored_visible_copy_count", 0))
			== NON_WORK_BAY_SURFACE_DEFINITIONS.size()
	)
	var collision_exact := true
	var collision_count := 0
	for definition_variant in NON_WORK_BAY_SURFACE_DEFINITIONS:
		var definition := definition_variant as Dictionary
		var matched_body: StaticBody3D = null
		for raw_body in StationModuleContract.collect_static_bodies(self):
			var body := raw_body as StaticBody3D
			if StringName(body.get_meta(&"walkable_surface_id", &"")) == StringName(definition.id):
				matched_body = body
				break
		if matched_body != null:
			collision_count += 1
		var shape := _body_box_shape(matched_body) if matched_body != null else null
		collision_exact = collision_exact \
			and matched_body != null \
			and matched_body.position.is_equal_approx(definition.position as Vector3) \
			and shape != null \
			and shape.size.is_equal_approx(definition.size as Vector3) \
			and matched_body.find_children("*", "MeshInstance3D", false, false).is_empty()
	return {
		"valid": parts_exact and render_state_exact and collision_exact,
		"family": &"non_work_bay_walked_deck_presentation",
		"before": {
			"renderer_submissions": 5,
			"presentation_nodes": 5,
			"visible_geometry_copies": 5,
			"retained_mesh_resources": 4,
		},
		"after": {
			"renderer_submissions": 1 if renderer != null else 0,
			"presentation_nodes": 1 if renderer != null else 0,
			"visible_geometry_copies": int(renderer.get_meta(&"authored_visible_copy_count", 0)) if renderer != null else 0,
			"retained_mesh_resources": 1 if mesh != null else 0,
		},
		"delta": {
			"renderer_submissions": -4,
			"presentation_nodes": -4,
			"retained_mesh_resources": -3,
		},
		"authored_parts": live_parts.duplicate(true),
		"visual_parts_exact": parts_exact,
		"render_state_and_combined_geometry_exact": render_state_exact,
		"combined_vertex_count": vertex_count,
		"collision_body_count": collision_count,
		"collision_transforms_and_shapes_exact": collision_exact,
	}.duplicate(true)


func get_work_bay_surface_render_optimization_contract() -> Dictionary:
	var batch: MultiMeshInstance3D = null
	for raw_batch in find_children("*", "MultiMeshInstance3D", true, false):
		var candidate := raw_batch as MultiMeshInstance3D
		if str(candidate.get_meta(&"fabrication_annex_batch_key", "")) \
				== WORK_BAY_SURFACE_BATCH_KEY:
			batch = candidate
			break
	var authored := _authored_batch_transforms.get(WORK_BAY_SURFACE_BATCH_KEY, []) as Array
	var transforms_exact := authored.size() == WORK_BAY_SURFACE_POSITIONS.size()
	for index in mini(authored.size(), WORK_BAY_SURFACE_POSITIONS.size()):
		var transform := authored[index] as Transform3D
		transforms_exact = transforms_exact \
			and transform.basis.is_equal_approx(Basis.IDENTITY) \
			and transform.origin.is_equal_approx(WORK_BAY_SURFACE_POSITIONS[index] as Vector3)
	var collision_bodies: Array[StaticBody3D] = []
	for raw_body in StationModuleContract.collect_static_bodies(self):
		var body := raw_body as StaticBody3D
		if StringName(body.get_meta(&"walkable_surface_id", &"")) in [
			&"port_work_bay", &"starboard_work_bay"
		]:
			collision_bodies.append(body)
	collision_bodies.sort_custom(
		func(first: StaticBody3D, second: StaticBody3D) -> bool:
			return str(first.get_meta(&"walkable_surface_id")) \
				< str(second.get_meta(&"walkable_surface_id"))
	)
	var collision_exact := collision_bodies.size() == WORK_BAY_SURFACE_POSITIONS.size()
	for index in mini(collision_bodies.size(), WORK_BAY_SURFACE_POSITIONS.size()):
		var body := collision_bodies[index]
		var shape := _body_box_shape(body)
		collision_exact = collision_exact \
			and body.position.is_equal_approx(WORK_BAY_SURFACE_POSITIONS[index] as Vector3) \
			and shape != null \
			and shape.size.is_equal_approx(WORK_BAY_SURFACE_SIZE) \
			and body.find_children("*", "MeshInstance3D", false, false).is_empty()
	var batch_exact: bool = (
		batch != null
		and batch.name == &"WorkBaySurfaceBatch"
		and batch.multimesh != null
		and batch.multimesh.instance_count == WORK_BAY_SURFACE_POSITIONS.size()
		and batch.multimesh.mesh == StationSurfaceKit.rounded_box_mesh_cached(
			WORK_BAY_SURFACE_SIZE, _mesh_cache
		)
		and batch.material_override == _materials[&"deck"]
		and batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		and is_zero_approx(batch.visibility_range_begin)
		and is_zero_approx(batch.visibility_range_end)
		and is_zero_approx(batch.extra_cull_margin)
	)
	return {
		"valid": batch_exact and transforms_exact and collision_exact,
		"family": &"walkable_work_bay_surface_presentation",
		"before": {
			"renderer_submissions": 2,
			"visible_geometry_copies": 2,
			"presentation_nodes": 2,
			"primitive_mesh_resources": 1,
		},
		"after": {
			"renderer_submissions": 1 if batch != null else 0,
			"visible_geometry_copies": (
				batch.multimesh.instance_count
				if batch != null and batch.multimesh != null
				else 0
			),
			"presentation_nodes": 1 if batch != null else 0,
			"primitive_mesh_resources": (
				1
				if batch != null and batch.multimesh != null and batch.multimesh.mesh != null
				else 0
			),
		},
		"delta": {"renderer_submissions": -1, "presentation_nodes": -1},
		"authored_transforms": authored.duplicate(true),
		"visual_transforms_exact": transforms_exact,
		"render_state_exact": batch_exact,
		"collision_body_count": collision_bodies.size(),
		"collision_transforms_and_shapes_exact": collision_exact,
	}.duplicate(true)


func get_roof_column_render_optimization_contract() -> Dictionary:
	var batch: MultiMeshInstance3D = null
	for raw_batch in find_children("*", "MultiMeshInstance3D", true, false):
		var candidate := raw_batch as MultiMeshInstance3D
		if str(candidate.get_meta(&"fabrication_annex_batch_key", "")) \
				== ROOF_COLUMN_BATCH_KEY:
			batch = candidate
			break
	var authored := _authored_batch_transforms.get(ROOF_COLUMN_BATCH_KEY, []) as Array
	var transforms_exact := authored.size() == ROOF_COLUMN_POSITIONS.size()
	for index in mini(authored.size(), ROOF_COLUMN_POSITIONS.size()):
		var transform := authored[index] as Transform3D
		transforms_exact = transforms_exact \
			and transform.basis.is_equal_approx(Basis.IDENTITY) \
			and transform.origin.is_equal_approx(ROOF_COLUMN_POSITIONS[index] as Vector3)
	var collision_bodies: Array[StaticBody3D] = []
	for raw_body in StationModuleContract.collect_static_bodies(self):
		var body := raw_body as StaticBody3D
		if str(body.get_meta(&"fixed_equipment_id", "")).begins_with("roof_column_"):
			collision_bodies.append(body)
	collision_bodies.sort_custom(
		func(first: StaticBody3D, second: StaticBody3D) -> bool:
			return str(first.name) < str(second.name)
	)
	var collision_exact := collision_bodies.size() == ROOF_COLUMN_POSITIONS.size()
	for index in mini(collision_bodies.size(), ROOF_COLUMN_POSITIONS.size()):
		var body := collision_bodies[index]
		var shape := _body_box_shape(body)
		var expected_name := "RoofColumn" if index == 0 else "RoofColumn%02d" % index
		collision_exact = collision_exact \
			and str(body.name) == expected_name \
			and body.position.is_equal_approx(ROOF_COLUMN_POSITIONS[index] as Vector3) \
			and shape != null \
			and shape.size.is_equal_approx(ROOF_COLUMN_SIZE) \
			and body.find_children("*", "MeshInstance3D", false, false).is_empty()
	var batch_exact: bool = (
		batch != null
		and batch.name == &"RoofColumnBatch"
		and batch.multimesh != null
		and batch.multimesh.instance_count == ROOF_COLUMN_POSITIONS.size()
		and batch.multimesh.mesh != null
		and batch.material_override == _materials[&"structure"]
	)
	return {
		"valid": batch_exact and transforms_exact and collision_exact,
		"family": &"physical_roof_column_presentation",
		"before": {
			"mesh_instance_nodes": 8,
			"multi_mesh_instance_nodes": 0,
			"renderer_submissions": 8,
			"visible_geometry_copies": 8,
			"primitive_mesh_resources": 1,
			"presentation_nodes": 8,
		},
		"after": {
			"mesh_instance_nodes": 0,
			"multi_mesh_instance_nodes": 1 if batch != null else 0,
			"renderer_submissions": 1 if batch != null else 0,
			"visible_geometry_copies": (
				batch.multimesh.instance_count
				if batch != null and batch.multimesh != null
				else 0
			),
			"primitive_mesh_resources": (
				1
				if batch != null and batch.multimesh != null and batch.multimesh.mesh != null
				else 0
			),
			"presentation_nodes": 1 if batch != null else 0,
		},
		"delta": {
			"renderer_submissions": -7,
			"presentation_nodes": -7,
			"primitive_mesh_resources": 0,
		},
		"authored_transforms": authored.duplicate(true),
		"visual_transforms_exact": transforms_exact,
		"collision_body_count": collision_bodies.size(),
		"collision_names_transforms_and_shapes_exact": collision_exact,
	}.duplicate(true)


func get_fabricator_base_render_optimization_contract() -> Dictionary:
	var batch: MultiMeshInstance3D = null
	for raw_batch in find_children("*", "MultiMeshInstance3D", true, false):
		var candidate := raw_batch as MultiMeshInstance3D
		if str(candidate.get_meta(&"fabrication_annex_batch_key", "")) == FABRICATOR_BASE_BATCH_KEY:
			batch = candidate
			break
	var authored := _authored_batch_transforms.get(FABRICATOR_BASE_BATCH_KEY, []) as Array
	var transforms_exact := authored.size() == FABRICATOR_BASE_POSITIONS.size()
	for index in mini(authored.size(), FABRICATOR_BASE_POSITIONS.size()):
		var transform := authored[index] as Transform3D
		transforms_exact = transforms_exact \
			and transform.basis.is_equal_approx(Basis.IDENTITY) \
			and transform.origin.is_equal_approx(FABRICATOR_BASE_POSITIONS[index] as Vector3)
	var collision_bodies: Array[StaticBody3D] = []
	for raw_body in StationModuleContract.collect_static_bodies(self):
		var body := raw_body as StaticBody3D
		if str(body.get_meta(&"fixed_equipment_id", "")).begins_with("fabricator_base_"):
			collision_bodies.append(body)
	collision_bodies.sort_custom(
		func(first: StaticBody3D, second: StaticBody3D) -> bool:
			return str(first.name) < str(second.name)
	)
	var collision_exact := collision_bodies.size() == FABRICATOR_BASE_POSITIONS.size()
	for index in mini(collision_bodies.size(), FABRICATOR_BASE_POSITIONS.size()):
		var body := collision_bodies[index]
		var shape := _body_box_shape(body)
		var expected_name := "FabricatorBase" if index == 0 else "FabricatorBase%02d" % index
		collision_exact = collision_exact \
			and str(body.name) == expected_name \
			and body.position.is_equal_approx(FABRICATOR_BASE_POSITIONS[index] as Vector3) \
			and shape != null \
			and shape.size.is_equal_approx(FABRICATOR_BASE_SIZE) \
			and body.find_children("*", "MeshInstance3D", false, false).is_empty()
	var batch_exact: bool = (
		batch != null
		and batch.name == &"FabricatorBaseBatch"
		and batch.multimesh != null
		and batch.multimesh.instance_count == FABRICATOR_BASE_POSITIONS.size()
		and batch.multimesh.mesh == StationSurfaceKit.rounded_box_mesh_cached(FABRICATOR_BASE_SIZE, _mesh_cache)
		and batch.material_override == _materials[&"machine"]
		and batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		and is_zero_approx(batch.visibility_range_begin)
		and is_zero_approx(batch.visibility_range_end)
		and is_zero_approx(batch.extra_cull_margin)
	)
	return {
		"valid": batch_exact and transforms_exact and collision_exact,
		"family": &"physical_fabricator_base_presentation",
		"before": {
			"renderer_submissions": 4,
			"visible_geometry_copies": 4,
			"presentation_nodes": 4,
		},
		"after": {
			"renderer_submissions": 1 if batch != null else 0,
			"visible_geometry_copies": (
				batch.multimesh.instance_count
				if batch != null and batch.multimesh != null
				else 0
			),
			"presentation_nodes": 1 if batch != null else 0,
		},
		"delta": {"renderer_submissions": -3, "presentation_nodes": -3},
		"authored_transforms": authored.duplicate(true),
		"visual_transforms_exact": transforms_exact,
		"render_state_exact": batch_exact,
		"collision_body_count": collision_bodies.size(),
		"collision_names_transforms_and_shapes_exact": collision_exact,
	}.duplicate(true)


func get_work_bench_render_optimization_contract() -> Dictionary:
	var batch: MultiMeshInstance3D = null
	for raw_batch in find_children("*", "MultiMeshInstance3D", true, false):
		var candidate := raw_batch as MultiMeshInstance3D
		if str(candidate.get_meta(&"fabrication_annex_batch_key", "")) == WORK_BENCH_BATCH_KEY:
			batch = candidate
			break
	var authored := _authored_batch_transforms.get(WORK_BENCH_BATCH_KEY, []) as Array
	var transforms_exact := authored.size() == WORK_BENCH_POSITIONS.size()
	for index in mini(authored.size(), WORK_BENCH_POSITIONS.size()):
		var transform := authored[index] as Transform3D
		transforms_exact = transforms_exact \
			and transform.basis.is_equal_approx(Basis.IDENTITY) \
			and transform.origin.is_equal_approx(WORK_BENCH_POSITIONS[index] as Vector3)
	var collision_bodies: Array[StaticBody3D] = []
	for raw_body in StationModuleContract.collect_static_bodies(self):
		var body := raw_body as StaticBody3D
		if str(body.get_meta(&"fixed_equipment_id", "")).begins_with("work_bench_"):
			collision_bodies.append(body)
	collision_bodies.sort_custom(
		func(first: StaticBody3D, second: StaticBody3D) -> bool:
			return str(first.name) < str(second.name)
	)
	var collision_exact := collision_bodies.size() == WORK_BENCH_POSITIONS.size()
	for index in mini(collision_bodies.size(), WORK_BENCH_POSITIONS.size()):
		var body := collision_bodies[index]
		var shape := _body_box_shape(body)
		var expected_name := "WorkBench" if index == 0 else "WorkBench%02d" % index
		var expected_position := WORK_BENCH_POSITIONS[index] as Vector3
		var expected_id := StringName("work_bench_%0.2f_%0.2f" % [expected_position.x, expected_position.z])
		collision_exact = collision_exact \
			and str(body.name) == expected_name \
			and body.position.is_equal_approx(expected_position) \
			and StringName(body.get_meta(&"fixed_equipment_id", &"")) == expected_id \
			and shape != null \
			and shape.size.is_equal_approx(WORK_BENCH_SIZE) \
			and body.find_children("*", "MeshInstance3D", false, false).is_empty()
	var batch_exact: bool = (
		batch != null
		and batch.name == &"WorkBenchBatch"
		and batch.multimesh != null
		and batch.multimesh.instance_count == WORK_BENCH_POSITIONS.size()
		and batch.multimesh.mesh == StationSurfaceKit.rounded_box_mesh_cached(WORK_BENCH_SIZE, _mesh_cache)
		and batch.material_override == _materials[&"structure"]
		and batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		and is_zero_approx(batch.visibility_range_begin)
		and is_zero_approx(batch.visibility_range_end)
		and is_zero_approx(batch.extra_cull_margin)
	)
	return {
		"valid": batch_exact and transforms_exact and collision_exact,
		"family": &"physical_work_bench_presentation",
		"before": {
			"renderer_submissions": 4,
			"visible_geometry_copies": 4,
			"presentation_nodes": 4,
		},
		"after": {
			"renderer_submissions": 1 if batch != null else 0,
			"visible_geometry_copies": (
				batch.multimesh.instance_count
				if batch != null and batch.multimesh != null
				else 0
			),
			"presentation_nodes": 1 if batch != null else 0,
		},
		"delta": {"renderer_submissions": -3, "presentation_nodes": -3},
		"authored_transforms": authored.duplicate(true),
		"visual_transforms_exact": transforms_exact,
		"render_state_exact": batch_exact,
		"collision_body_count": collision_bodies.size(),
		"collision_names_transforms_shapes_and_ids_exact": collision_exact,
	}.duplicate(true)


func get_lighting_contract() -> Dictionary:
	var pools: Array[Dictionary] = []
	var exact_pool_roster := true
	var coverage_preserved := true
	for definition_variant in PAIRED_POOL_DEFINITIONS:
		var definition := definition_variant as Dictionary
		var node := _build_root.get_node_or_null(NodePath(str(definition.node_name))) as OmniLight3D
		var source_positions := definition.source_positions as Array
		var sources_contained := source_positions.size() == 2
		for source_position_variant in source_positions:
			var source_position := source_position_variant as Vector3
			sources_contained = sources_contained and (
				source_position.distance_to(definition.position as Vector3)
					+ SOURCE_PRACTICAL_RANGE_M
				<= PAIRED_POOL_RANGE_M + 0.000001
			)
		coverage_preserved = coverage_preserved and sources_contained
		var exact: bool = (
			node != null
			and node.position.is_equal_approx(definition.position as Vector3)
			and node.light_color.is_equal_approx(definition.color as Color)
			and is_equal_approx(node.light_energy, PAIRED_POOL_ENERGY)
			and is_equal_approx(node.omni_range, PAIRED_POOL_RANGE_M)
			and is_equal_approx(node.omni_attenuation, PRACTICAL_ATTENUATION)
			and not node.shadow_enabled
			and node.distance_fade_enabled
			and is_equal_approx(node.distance_fade_begin, PRACTICAL_FADE_BEGIN_M)
			and is_equal_approx(node.distance_fade_length, PRACTICAL_FADE_LENGTH_M)
			and StringName(node.get_meta(&"fabrication_paired_pool", &""))
				== definition.pool_id
		)
		exact_pool_roster = exact_pool_roster and exact
		pools.append({
			"pool_id": definition.pool_id,
			"node_name": definition.node_name,
			"position": node.position if node != null else Vector3.ZERO,
			"color": node.light_color if node != null else Color.TRANSPARENT,
			"energy": node.light_energy if node != null else 0.0,
			"range_m": node.omni_range if node != null else 0.0,
			"attenuation": node.omni_attenuation if node != null else 0.0,
			"fade_begin_m": node.distance_fade_begin if node != null else 0.0,
			"fade_length_m": node.distance_fade_length if node != null else 0.0,
			"shadow_enabled": node.shadow_enabled if node != null else true,
			"source_positions": source_positions.duplicate(true),
			"source_range_m": SOURCE_PRACTICAL_RANGE_M,
			"sources_geometrically_contained": sources_contained,
		})
	var luminaire_key := "luminous:%0.3f:%0.3f:%0.3f" % [
		LUMINAIRE_SIZE.x, LUMINAIRE_SIZE.y, LUMINAIRE_SIZE.z,
	]
	var authored_luminaires := _authored_batch_transforms.get(luminaire_key, []) as Array
	var luminaires_exact := authored_luminaires.size() == LUMINAIRE_POSITIONS.size()
	for index in mini(authored_luminaires.size(), LUMINAIRE_POSITIONS.size()):
		luminaires_exact = luminaires_exact and (
			(authored_luminaires[index] as Transform3D).origin.is_equal_approx(
				LUMINAIRE_POSITIONS[index] as Vector3
			)
		)
	return {
		"schema_version": 1,
		"source_practical_count": 6,
		"paired_pool_count": pools.size(),
		"luminaire_count": authored_luminaires.size(),
		"pool_energy": PAIRED_POOL_ENERGY,
		"pool_range_m": PAIRED_POOL_RANGE_M,
		"attenuation": PRACTICAL_ATTENUATION,
		"source_energy": SOURCE_PRACTICAL_ENERGY,
		"source_range_m": SOURCE_PRACTICAL_RANGE_M,
		"pair_midpoint_offset_m": 3.75,
		"exact_pool_roster": exact_pool_roster,
		"coverage_preserved": coverage_preserved,
		"luminaires_exact": luminaires_exact,
		"pools": pools.duplicate(true),
		"luminaire_transforms": authored_luminaires.duplicate(true),
	}


func get_deterministic_naming_contract() -> Dictionary:
	var fallback_paths := PackedStringArray()
	var paths := PackedStringArray([str(get_path())])
	var allocated_names := 0
	var duplicate_sibling_name_count := 0
	for count in _name_counters.values():
		allocated_names += int(count)
	var parents: Array[Node] = [self]
	parents.append_array(find_children("*", "", true, false))
	for parent in parents:
		var sibling_names := {}
		for child in parent.get_children():
			var child_name := str(child.name)
			if sibling_names.has(child_name):
				duplicate_sibling_name_count += 1
			sibling_names[child_name] = true
	for node in find_children("*", "", true, false):
		var relative_path := str(get_path_to(node))
		paths.append(relative_path)
		for segment in relative_path.split("/"):
			if segment.begins_with("@"):
				fallback_paths.append(relative_path)
				break
	paths.sort()
	return {
		"node_count": paths.size(),
		"generated_name_allocation_count": allocated_names,
		"auto_generated_fallback_path_count": fallback_paths.size(),
		"auto_generated_fallback_paths": fallback_paths,
		"duplicate_sibling_name_count": duplicate_sibling_name_count,
		"stable_paths": paths,
	}


func get_integration_footprint() -> Dictionary:
	return {"local_min": Vector3(-14.2, -0.4, 0.0), "local_max": Vector3(14.2, 5.6, 20.2), "anchor_transform": global_transform}


func get_evidence_metadata() -> Dictionary:
	return {
		"evidence_status": EVIDENCE_STATUS,
		"interpretation_label": INTERPRETATION_LABEL,
		"source_confidence": SOURCE_CONFIDENCE,
		"source_bounded": false,
		"authenticated_original_geometry": false,
		"registered_evidence_anchors": PackedStringArray(),
		"content_note": "A new modern interpretation; no source-authentic geometry or historical layout is claimed.",
	}


func get_component_roster() -> Dictionary:
	var roster := StationModuleContract.build_component_roster(self)
	roster["connection_slots"] = get_connection_slots()
	roster["standable_surfaces"] = get_standable_surface_roster()
	roster["fixed_equipment_footprints"] = get_fixed_equipment_footprint_roster()
	roster["walkable_area"] = get_walkable_area_contract()
	roster["render_submissions"] = get_render_submission_contract()
	roster["lighting"] = get_lighting_contract()
	roster["deterministic_naming"] = get_deterministic_naming_contract()
	return roster


func get_collision_contract() -> Dictionary:
	return StationModuleContract.build_collision_contract(self, WORLD_LAYER, _enabled)


func get_authority_contract() -> Dictionary:
	var contract := StationModuleContract.build_authority_contract(self)
	contract["ship_authority"] = &"none"
	contract["berth_authority"] = &"none"
	contract["combat_authority"] = &"none"
	contract["activity_authority"] = &"none"
	contract["reward_authority"] = &"none"
	return contract


func get_rear_observation_gate_contract() -> Dictionary:
	var segments: Array[Dictionary] = []
	for raw_body in StationModuleContract.collect_static_bodies(self):
		var body := raw_body as StaticBody3D
		var segment_id := StringName(body.get_meta(&"fabrication_rear_rail_return_segment", &""))
		if segment_id.is_empty():
			continue
		var shape := _body_box_shape(body)
		segments.append({
			"segment_id": segment_id,
			"body_path": get_path_to(body),
			"local_center": body.position,
			"world_center": body.global_position,
			"size": shape.size if shape != null else Vector3.ZERO,
		})
	segments.sort_custom(
		func(first: Dictionary, second: Dictionary) -> bool:
			return str(first.segment_id) < str(second.segment_id)
	)
	return {
		"enabled": observation_rear_gate_open,
		"opening_local_x": Vector2(-2.0, 2.0),
		"opening_width_m": 4.0,
		"rear_boundary_local_z": 20.0,
		"returned_segments": segments,
	}


func _active_performance_budgets() -> Dictionary:
	return OBSERVATION_GATE_PERFORMANCE_BUDGETS if observation_rear_gate_open else PERFORMANCE_BUDGETS


func get_performance_contract() -> Dictionary:
	var budgets := _active_performance_budgets()
	var contract := StationModuleContract.build_performance_contract(self, budgets)
	var render := get_render_submission_contract()
	contract["multi_mesh_instances"] = render.multi_mesh_batches
	contract["multi_mesh_drawn_copies"] = render.multi_mesh_drawn_copies
	contract["geometry_instances"] = render.geometry_submissions
	contract["visible_geometry_copies"] = render.visible_geometry_copies
	var nodes := find_children("*", "", true, false).size() + 1
	contract["nodes"] = nodes
	contract["within_budget"] = (
		bool(contract.within_budget)
		and int(contract.multi_mesh_instances) <= int(budgets.multi_mesh_instances)
		and int(contract.multi_mesh_drawn_copies) <= int(budgets.multi_mesh_drawn_copies)
		and int(contract.geometry_instances) <= int(budgets.geometry_instances)
		and int(contract.visible_geometry_copies) <= int(budgets.visible_geometry_copies)
		and nodes <= int(budgets.nodes)
	)
	return contract


func set_module_enabled(enabled: bool) -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	_enabled = enabled
	if _build_root == null:
		return
	StationModuleContract.apply_enabled_state(StationModuleContract.collect_static_bodies(self), WORLD_LAYER, _enabled, _build_root)


func is_module_enabled() -> bool:
	return _enabled


func get_lifecycle_contract() -> Dictionary:
	return StationModuleContract.build_lifecycle_contract(self, WORLD_LAYER, _enabled, _build_root)


func get_audit_report() -> Dictionary:
	var errors := get_validation_errors()
	return {
		"valid": errors.is_empty(),
		"errors": errors.duplicate(),
		"module_id": MODULE_ID,
		"lighting": get_lighting_contract(),
	}


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	var area := get_walkable_area_contract()
	if not is_equal_approx(float(area.station_census_contribution_m2), GROSS_HORIZONTAL_AREA_M2):
		errors.append("live standable slab union drifted")
	if _standable_surface_overlap_m2() > 0.0001:
		errors.append("standable slabs overlap and no longer form the published union")
	if not is_equal_approx(float(area.fixed_equipment_footprint_m2), FIXED_EQUIPMENT_FOOTPRINT_M2):
		errors.append("live fixed-equipment footprint drifted")
	if not is_equal_approx(float(area.floor_after_fixed_equipment_m2), FLOOR_AFTER_FIXED_EQUIPMENT_M2):
		errors.append("floor-after-fixed-equipment arithmetic drifted")
	for route_id: StringName in ROUTE_TRANSFORMS:
		var marker := get_route_marker(route_id)
		if marker == null or not marker.transform.is_equal_approx(ROUTE_TRANSFORMS[route_id]):
			errors.append("route marker drifted: %s" % route_id)
		elif CONNECTION_SLOTS.has(route_id) and StationModuleContract.new().read_connection_slot_id(marker) != CONNECTION_SLOTS[route_id]:
			errors.append("connection slot drifted: %s" % route_id)
	var collision := get_collision_contract()
	if not bool(collision.all_layers_match_lifecycle) or not bool(collision.all_masks_zero) or not bool(collision.all_shapes_present_and_enabled):
		errors.append("collision contract drifted")
	var authority := get_authority_contract()
	if int(authority.ship_berth_count) != 0 or int(authority.landing_or_interaction_area_count) != 0 or int(authority.activity_node_count) != 0:
		errors.append("forbidden gameplay authority entered the annex")
	var performance := get_performance_contract()
	var budgets := _active_performance_budgets()
	if not bool(performance.within_budget):
		errors.append("performance budget exceeded")
	for budget_key in ["mesh_instances", "multi_mesh_instances", "multi_mesh_drawn_copies", "geometry_instances", "visible_geometry_copies", "static_bodies", "collision_shapes", "labels", "lights", "nodes"]:
		if int(performance.get(budget_key, -1)) != int(budgets.get(budget_key, -2)):
			errors.append("frozen performance count drifted: %s" % budget_key)
	var lighting := get_lighting_contract()
	if not bool(lighting.exact_pool_roster):
		errors.append("paired practical pool roster drifted")
	if not bool(lighting.coverage_preserved):
		errors.append("paired practical pools no longer contain both source volumes")
	if not bool(lighting.luminaires_exact):
		errors.append("the six authored luminaire meshes drifted")
	var render := get_render_submission_contract()
	if not bool(render.forward_plus_buffers_match_authored) or int(render.authored_transform_count) != int(render.multi_mesh_drawn_copies):
		errors.append("Forward+ MultiMesh buffers drifted from authored transforms")
	if not bool(get_roof_column_render_optimization_contract().valid):
		errors.append("roof-column presentation batch or physical roster drifted")
	if not bool(get_fabricator_base_render_optimization_contract().valid):
		errors.append("fabricator-base presentation batch or physical roster drifted")
	if not bool(get_work_bench_render_optimization_contract().valid):
		errors.append("work-bench presentation batch or physical roster drifted")
	if not bool(get_work_bay_surface_render_optimization_contract().valid):
		errors.append("work-bay surface presentation batch or physical roster drifted")
	if not bool(get_floor_render_optimization_contract().valid):
		errors.append("non-work-bay floor presentation batch or physical roster drifted")
	var naming := get_deterministic_naming_contract()
	var expected_name_allocations := 71 if observation_rear_gate_open else 70
	if int(naming.node_count) != int(budgets.nodes) or int(naming.generated_name_allocation_count) != expected_name_allocations or int(naming.auto_generated_fallback_path_count) != 0 or int(naming.duplicate_sibling_name_count) != 0:
		errors.append("deterministic runtime naming drifted")
	var rear_gate := get_rear_observation_gate_contract()
	if observation_rear_gate_open:
		var returned := rear_gate.returned_segments as Array
		var exact_segments := returned.size() == 2
		var expected_centers := {&"north": Vector3(-8.0, 0.72, 20.0), &"south": Vector3(8.0, 0.72, 20.0)}
		for entry_variant in returned:
			var entry := entry_variant as Dictionary
			var segment_id := StringName(entry.segment_id)
			exact_segments = exact_segments \
				and expected_centers.has(segment_id) \
				and (entry.local_center as Vector3).is_equal_approx(expected_centers[segment_id] as Vector3) \
				and (entry.size as Vector3).is_equal_approx(Vector3(12.0, 1.44, 0.14))
		if not exact_segments:
			errors.append("Observation rear gate returned rail segments drifted")
	var lifecycle := get_lifecycle_contract()
	if not bool(lifecycle.visible_matches_enabled) or not bool(lifecycle.collision_matches_enabled):
		errors.append("lifecycle state drifted")
	return errors


func _body_box_shape(body: StaticBody3D) -> BoxShape3D:
	if body == null:
		return null
	for raw_shape in body.find_children("*", "CollisionShape3D", false, false):
		var collision := raw_shape as CollisionShape3D
		if collision.shape is BoxShape3D:
			return collision.shape as BoxShape3D
	return null


func _body_collision_shape(body: StaticBody3D) -> CollisionShape3D:
	if body == null:
		return null
	for raw_shape in body.find_children("*", "CollisionShape3D", false, false):
		return raw_shape as CollisionShape3D
	return null


func _horizontal_footprint_m2(body: StaticBody3D) -> float:
	var collision := _body_collision_shape(body)
	if collision == null or not (collision.shape is BoxShape3D):
		return 0.0
	var size := (collision.shape as BoxShape3D).size
	var basis := (body.transform * collision.transform).basis
	var edge_x := basis * Vector3(size.x, 0.0, 0.0)
	var edge_z := basis * Vector3(0.0, 0.0, size.z)
	return absf(edge_x.x * edge_z.z - edge_x.z * edge_z.x)


func _sum_roster_area(roster: Array[Dictionary], key: StringName) -> float:
	var total := 0.0
	for entry in roster:
		total += float(entry.get(key, 0.0))
	return total


func _standable_surface_overlap_m2() -> float:
	var bodies: Array[StaticBody3D] = []
	for raw_body in StationModuleContract.collect_static_bodies(self):
		var body := raw_body as StaticBody3D
		if bool(body.get_meta(&"walkable_surface", false)):
			bodies.append(body)
	var overlap := 0.0
	for first_index in bodies.size():
		var first := _horizontal_bounds(bodies[first_index])
		for second_index in range(first_index + 1, bodies.size()):
			var second := _horizontal_bounds(bodies[second_index])
			var width := maxf(0.0, minf(first.max_x, second.max_x) - maxf(first.min_x, second.min_x))
			var depth := maxf(0.0, minf(first.max_z, second.max_z) - maxf(first.min_z, second.min_z))
			overlap += width * depth
	return overlap


func _horizontal_bounds(body: StaticBody3D) -> Dictionary:
	var collision := _body_collision_shape(body)
	if collision == null or not (collision.shape is BoxShape3D):
		return {"min_x": 0.0, "max_x": 0.0, "min_z": 0.0, "max_z": 0.0}
	var size := (collision.shape as BoxShape3D).size
	var combined := body.transform * collision.transform
	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF
	for x_sign in [-1.0, 1.0]:
		for z_sign in [-1.0, 1.0]:
			var corner := combined * Vector3(size.x * 0.5 * x_sign, 0.0, size.z * 0.5 * z_sign)
			min_x = minf(min_x, corner.x)
			max_x = maxf(max_x, corner.x)
			min_z = minf(min_z, corner.z)
			max_z = maxf(max_z, corner.z)
	return {"min_x": min_x, "max_x": max_x, "min_z": min_z, "max_z": max_z}
