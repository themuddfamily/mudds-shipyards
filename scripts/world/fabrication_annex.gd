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
	"mesh_instances": 34,
	"multi_mesh_instances": 12,
	"geometry_instances": 46,
	"visible_geometry_copies": 128,
	"multi_mesh_drawn_copies": 94,
	"static_bodies": 34,
	"collision_shapes": 34,
	"labels": 3,
	"lights": 6,
	"process_loops": 0,
	"physics_process_loops": 0,
	"nodes": 132,
}

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
	_materials[&"deck"] = _material(Color("34414a"), 0.72, 0.45, true)
	_materials[&"structure"] = _material(Color("202a31"), 0.76, 0.45, true)
	_materials[&"machine"] = _material(Color("68727a"), 0.62, 0.5, true)
	_materials[&"hazard"] = _material(Color("d58b27"), 0.5, 0.35, false)
	_materials[&"rail"] = _material(Color("aeb9bc"), 0.5, 0.55, false)
	_materials[&"accent"] = _material(Color("3b9ca2"), 0.38, 0.4, false)


func _material(color: Color, roughness: float, metallic: float, panel: bool) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = roughness
	result.metallic = metallic
	if panel:
		# 0.30 is the production-compliant large station-module panel scale.
		StationSurfaceKit.apply_panel_triplanar(result, 0.30)
		result.albedo_color = color
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
	_add_surface(&"connector_apron", "ConnectorApron", Vector3(8.0, 0.4, 4.0), Vector3(0.0, -0.2, 2.0), 32.0)
	_add_surface(&"central_through_aisle", "CentralThroughAisle", Vector3(6.0, 0.4, 14.0), Vector3(0.0, -0.2, 11.0), 84.0)
	_add_surface(&"port_work_bay", "PortWorkBay", Vector3(8.0, 0.4, 14.0), Vector3(-7.0, -0.2, 11.0), 112.0)
	_add_surface(&"starboard_work_bay", "StarboardWorkBay", Vector3(8.0, 0.4, 14.0), Vector3(7.0, -0.2, 11.0), 112.0)
	_add_surface(&"port_side_bypass", "PortSideBypass", Vector3(3.0, 0.4, 14.0), Vector3(-12.5, -0.2, 11.0), 42.0)
	_add_surface(&"starboard_side_bypass", "StarboardSideBypass", Vector3(3.0, 0.4, 14.0), Vector3(12.5, -0.2, 11.0), 42.0)
	_add_surface(&"rear_cross_aisle", "RearCrossAisle", Vector3(28.0, 0.4, 2.0), Vector3(0.0, -0.2, 19.0), 56.0)


func _add_surface(id: StringName, label: String, size: Vector3, at: Vector3, area: float) -> void:
	var body := _add_solid(label, size, at, &"deck")
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
	_add_rail_run(Vector3(0.0, 0.72, 20.0), Vector3(28.0, 1.44, 0.14))
	for x in [-4.0, 4.0]:
		_add_rail_run(Vector3(x, 0.72, 2.0), Vector3(0.14, 1.44, 4.0))


func _add_rail_run(at: Vector3, collider_size: Vector3) -> void:
	_add_solid("GuardrailCollider", collider_size, at, &"rail")
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


func _build_work_bays() -> void:
	for raw_side in [-1.0, 1.0]:
		var side: float = raw_side
		var bay_x: float = side * 7.0
		var bench_x: float = side * 3.5
		var rack_x: float = side * 10.6
		for z in [7.0, 15.0]:
			_add_fixed_equipment("FabricatorBase", Vector3(4.0, 0.4, 3.0), Vector3(bay_x, 0.2, z), &"machine")
			_add_mesh("FabricatorColumn", Vector3(0.5, 2.8, 0.5), Vector3(bay_x - side * 1.45, 1.8, z - 1.0), &"structure")
			_add_mesh("FabricatorColumn", Vector3(0.5, 2.8, 0.5), Vector3(bay_x + side * 1.45, 1.8, z - 1.0), &"structure")
			_add_mesh("FabricatorGantry", Vector3(3.4, 0.45, 0.55), Vector3(bay_x, 3.0, z - 1.0), &"hazard")
			_add_mesh("FabricatorHead", Vector3(1.1, 1.5, 1.1), Vector3(bay_x, 1.65, z), &"accent")
			_add_fixed_equipment("WorkBench", Vector3(1.0, 0.9, 3.0), Vector3(bench_x, 0.45, z), &"structure")
			_add_fixed_equipment("MaterialRack", Vector3(0.8, 2.2, 2.4), Vector3(rack_x, 1.1, z), &"structure")
			for shelf_y in [0.55, 1.15, 1.75]:
				_add_mesh("RackShelf", Vector3(0.86, 0.08, 2.3), Vector3(rack_x, shelf_y, z), &"hazard")


func _build_structure_and_dressing() -> void:
	for x in [-11.0, -3.0, 3.0, 11.0]:
		for z in [4.5, 19.0]:
			_add_fixed_equipment("RoofColumn", Vector3(0.45, 5.6, 0.45), Vector3(x, 2.8, z), &"structure")
	for z in [5.0, 11.0, 17.0]:
		_add_mesh("OverheadCrossbeam", Vector3(27.0, 0.45, 0.5), Vector3(0.0, 5.35, z), &"structure")
	# Low curb makes bay zoning legible without closing any approach.
	for x in [-3.0, 3.0]:
		for z in [6.0, 16.0]:
			_add_mesh("HazardCurb", Vector3(0.22, 0.08, 4.0), Vector3(x, 0.04, z), &"hazard")
	for x in [-9.5, 9.5]:
		_add_mesh("ServiceConduit", Vector3(0.22, 0.22, 13.0), Vector3(x, 4.65, 11.0), &"accent")
	_add_label("FABRICATION ANNEX", Vector3(0.0, 3.4, 4.25), 0.65)
	_add_label("PORT BAY", Vector3(-7.0, 3.65, 10.0), 0.5)
	_add_label("STARBOARD BAY", Vector3(7.0, 3.65, 10.0), 0.5)


func _add_label(text: String, at: Vector3, font_size: float) -> void:
	var label := Label3D.new()
	label.name = text.to_pascal_case()
	label.text = text
	label.position = at
	label.font_size = 72
	label.pixel_size = font_size / 72.0
	label.modulate = Color("cbe9e7")
	label.outline_size = 8
	_build_root.add_child(label)


func _build_lighting() -> void:
	for x in [-8.5, 0.0, 8.5]:
		for z in [7.0, 14.5]:
			var light := OmniLight3D.new()
			light.name = _next_stable_name("PracticalLight")
			light.position = Vector3(x, 4.6, z)
			light.light_color = Color("c9e2dd") if x == 0.0 else Color("ffe0b0")
			light.light_energy = 3.2
			light.omni_range = 8.0
			light.shadow_enabled = false
			light.distance_fade_enabled = true
			light.distance_fade_begin = 18.0
			light.distance_fade_length = 8.0
			_build_root.add_child(light)
			_add_mesh("Luminaire", Vector3(1.8, 0.12, 0.3), Vector3(x, 4.72, z), &"accent")


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


func _add_fixed_equipment(label: String, size: Vector3, at: Vector3, material_id: StringName) -> StaticBody3D:
	var body := _add_solid(label, size, at, material_id)
	body.set_meta(&"fixed_equipment_footprint", true)
	body.set_meta(&"fixed_equipment_id", StringName("%s_%0.2f_%0.2f" % [label.to_snake_case(), at.x, at.z]))
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


func get_route_ids() -> PackedStringArray:
	return PackedStringArray(ROUTE_TRANSFORMS.keys())


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
	var mesh_submissions := find_children("*", "MeshInstance3D", true, false).size()
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
		"visible_geometry_copies": mesh_submissions + drawn_copies,
		"authored_transform_count": stored_transform_count,
		"forward_plus_buffer_float_count": buffer_float_count,
		"forward_plus_buffers_match_authored": buffers_match_authored,
		"batch_keys": live_batch_keys,
		"authored_batch_transforms": _authored_batch_transforms.duplicate(true),
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


func get_performance_contract() -> Dictionary:
	var contract := StationModuleContract.build_performance_contract(self, PERFORMANCE_BUDGETS)
	var render := get_render_submission_contract()
	contract["multi_mesh_instances"] = render.multi_mesh_batches
	contract["multi_mesh_drawn_copies"] = render.multi_mesh_drawn_copies
	contract["geometry_instances"] = render.geometry_submissions
	contract["visible_geometry_copies"] = render.visible_geometry_copies
	var nodes := find_children("*", "", true, false).size() + 1
	contract["nodes"] = nodes
	contract["within_budget"] = (
		bool(contract.within_budget)
		and int(contract.multi_mesh_instances) <= int(PERFORMANCE_BUDGETS.multi_mesh_instances)
		and int(contract.multi_mesh_drawn_copies) <= int(PERFORMANCE_BUDGETS.multi_mesh_drawn_copies)
		and int(contract.geometry_instances) <= int(PERFORMANCE_BUDGETS.geometry_instances)
		and int(contract.visible_geometry_copies) <= int(PERFORMANCE_BUDGETS.visible_geometry_copies)
		and nodes <= int(PERFORMANCE_BUDGETS.nodes)
	)
	return contract


func set_module_enabled(enabled: bool) -> void:
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
	return {"valid": errors.is_empty(), "errors": errors.duplicate(), "module_id": MODULE_ID}


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
	if not bool(performance.within_budget):
		errors.append("performance budget exceeded")
	for budget_key in ["mesh_instances", "multi_mesh_instances", "multi_mesh_drawn_copies", "geometry_instances", "visible_geometry_copies", "static_bodies", "collision_shapes", "labels", "lights", "nodes"]:
		if int(performance.get(budget_key, -1)) != int(PERFORMANCE_BUDGETS.get(budget_key, -2)):
			errors.append("frozen performance count drifted: %s" % budget_key)
	var render := get_render_submission_contract()
	if not bool(render.forward_plus_buffers_match_authored) or int(render.authored_transform_count) != int(render.multi_mesh_drawn_copies):
		errors.append("Forward+ MultiMesh buffers drifted from authored transforms")
	var naming := get_deterministic_naming_contract()
	if int(naming.node_count) != int(PERFORMANCE_BUDGETS.nodes) or int(naming.generated_name_allocation_count) != 52 or int(naming.auto_generated_fallback_path_count) != 0 or int(naming.duplicate_sibling_name_count) != 0:
		errors.append("deterministic runtime naming drifted")
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
