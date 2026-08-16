class_name ObservationLogisticsSpur
extends Node3D

## Standalone NEW station expansion: a long exposed connector feeding two
## separated pads whose far bridge closes a second return path.
##
## Nothing here is reconstructed. The layout, dimensions, station function,
## fittings and adjacency are project-original modern interpretation. The module
## deliberately owns no berth, interaction, activity, audio, spawn, lease or
## network authority.

const SCHEMA_VERSION := 1
const MODULE_ID: StringName = &"observation-logistics-spur"
const CONTENT_CLASS: StringName = &"NEW"
const EVIDENCE_STATUS: StringName = &"modern_interpretation"
const WORLD_LAYER := PhysicsLayers.WORLD

const ORIGIN_SLOT: StringName = &"observation-logistics-spur-origin"
const OBSERVATION_SLOT: StringName = &"observation-logistics-spur-observation-pad"
const LOGISTICS_SLOT: StringName = &"observation-logistics-spur-logistics-pad"

const FOOTPRINT_MIN := Vector3(-13.4, -0.3, 0.0)
const FOOTPRINT_MAX := Vector3(13.4, 4.4, 39.5)
const WALKABLE_AREA_M2 := 426.0

## The five rectangles touch at their boundaries without overlapping in plan,
## so their exact union equals the sum of their horizontal areas: 88 + 80 + 120
## + 120 + 18 = 426 m².
const WALKABLE_SURFACE_SPECS := [
	{
		"id": &"exposed-connector",
		"node_name": "ExposedConnectorDeck",
		"center": Vector3(0.0, -0.15, 11.0),
		"size": Vector3(4.0, 0.30, 22.0),
		"area_m2": 88.0,
	},
	{
		"id": &"pad-cross-landing",
		"node_name": "PadCrossLanding",
		"center": Vector3(0.0, -0.15, 24.0),
		"size": Vector3(20.0, 0.30, 4.0),
		"area_m2": 80.0,
	},
	{
		"id": &"observation-pad",
		"node_name": "ObservationPad",
		"center": Vector3(-8.0, -0.15, 32.0),
		"size": Vector3(10.0, 0.30, 12.0),
		"area_m2": 120.0,
	},
	{
		"id": &"logistics-pad",
		"node_name": "LogisticsPad",
		"center": Vector3(8.0, -0.15, 32.0),
		"size": Vector3(10.0, 0.30, 12.0),
		"area_m2": 120.0,
	},
	{
		"id": &"far-return-bridge",
		"node_name": "FarReturnBridge",
		"center": Vector3(0.0, -0.15, 38.0),
		"size": Vector3(6.0, 0.30, 3.0),
		"area_m2": 18.0,
	},
]

const CONNECTION_SLOT_SPECS := {
	&"origin": {
		"slot_id": ORIGIN_SLOT,
		"local_transform": Transform3D(Basis.IDENTITY, Vector3.ZERO),
	},
	&"observation-pad": {
		"slot_id": OBSERVATION_SLOT,
		"local_transform": Transform3D(Basis.IDENTITY, Vector3(-8.0, 0.0, 32.0)),
	},
	&"logistics-pad": {
		"slot_id": LOGISTICS_SLOT,
		"local_transform": Transform3D(Basis.IDENTITY, Vector3(8.0, 0.0, 32.0)),
	},
}

const CONTENT_NOTE := (
	"NEW project-original station content. No source establishes an observation/logistics "
	+ "spur, these functions, this exposed 24 m approach, two-pad plan, alternate return "
	+ "bridge, dimensions, materials, fittings, or adjacency. Every authored claim is "
	+ "modern_interpretation and no historical reconstruction is asserted."
)

@onready var _module_anchor: Marker3D = %ModuleAnchor
@onready var _origin_connection: Marker3D = %OriginConnection
@onready var _connector_midpoint: Marker3D = %ConnectorMidpoint
@onready var _cross_landing: Marker3D = %CrossLanding
@onready var _observation_pad: Marker3D = %ObservationPadMarker
@onready var _logistics_pad: Marker3D = %LogisticsPadMarker
@onready var _far_return: Marker3D = %FarReturn

var _materials: Dictionary = {}
var _route_markers: Dictionary = {}
var _walkable_surfaces: Array[StaticBody3D] = []
var _built := false
var _module_enabled := true


func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	if not _built:
		_built = true
		_create_materials()
		_index_routes()
		_build_module()
		_apply_metadata()
	_apply_enabled_state()


func get_module_id() -> StringName:
	return MODULE_ID


func get_module_anchor() -> Marker3D:
	return _module_anchor


func get_route_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for route_id: StringName in _route_markers.keys():
		result.append(route_id)
	result.sort()
	return result


func has_route_marker(route_id: StringName) -> bool:
	return _route_markers.has(route_id)


func get_route_marker(route_id: StringName) -> Marker3D:
	return _route_markers.get(route_id) as Marker3D


func get_route_transform(route_id: StringName) -> Transform3D:
	var marker := get_route_marker(route_id)
	return marker.global_transform if marker != null else Transform3D.IDENTITY


func get_connection_slots() -> Dictionary:
	var result := {}
	for route_id: StringName in CONNECTION_SLOT_SPECS.keys():
		var spec := CONNECTION_SLOT_SPECS[route_id] as Dictionary
		result[route_id] = {
			"slot_id": StringName(spec.slot_id),
			"local_transform": (spec.local_transform as Transform3D),
			"world_transform": global_transform * (spec.local_transform as Transform3D),
		}
	return result.duplicate(true)


func get_walkable_surface_roster() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for spec_variant in WALKABLE_SURFACE_SPECS:
		var spec := spec_variant as Dictionary
		result.append({
			"surface_id": StringName(spec.id),
			"node_name": str(spec.node_name),
			"local_center": spec.center as Vector3,
			"size": spec.size as Vector3,
			"horizontal_area_m2": float(spec.area_m2),
			"kind": &"level",
		})
	return result.duplicate(true)


func get_walkable_area_m2() -> float:
	return WALKABLE_AREA_M2


func get_integration_footprint() -> Dictionary:
	return {
		"anchor_transform": _module_anchor.global_transform,
		"local_min": FOOTPRINT_MIN,
		"local_max": FOOTPRINT_MAX,
		"local_size": FOOTPRINT_MAX - FOOTPRINT_MIN,
		"approach_axis_local": Vector3.FORWARD,
		"module_extends_local": Vector3.BACK,
	}


func get_evidence_metadata() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"module_id": MODULE_ID,
		"content_class": CONTENT_CLASS,
		"evidence_status": EVIDENCE_STATUS,
		"source_bounded": false,
		"references": PackedStringArray(),
		"content_note": CONTENT_NOTE,
		"supported_invariants": PackedStringArray(),
		"modern_interpretations": PackedStringArray([
			"the complete module and its location",
			"observation and logistics functions",
			"all geometry, dimensions, materials, fittings, lighting and dressing",
		]),
	}


func get_component_roster() -> Dictionary:
	var roster := StationModuleContract.build_component_roster(self)
	roster["schema_version"] = SCHEMA_VERSION
	roster["module_id"] = MODULE_ID
	roster["walkable_surface_count"] = _walkable_surfaces.size()
	roster["walkable_area_m2"] = WALKABLE_AREA_M2
	roster["connection_slot_count"] = CONNECTION_SLOT_SPECS.size()
	return roster


func get_collision_contract() -> Dictionary:
	var contract := StationModuleContract.build_collision_contract(self, WORLD_LAYER, _module_enabled)
	contract["schema_version"] = SCHEMA_VERSION
	return contract


func get_authority_contract() -> Dictionary:
	var contract := StationModuleContract.build_authority_contract(self)
	contract["schema_version"] = SCHEMA_VERSION
	return contract


func get_performance_contract() -> Dictionary:
	# Exact standalone build census, frozen rather than estimated: 133 descendant
	# nodes, 48 MeshInstance3D nodes, one MultiMesh submission holding ten repeated
	# visual markers, 33 bodies/shapes, one Label3D and six practicals. The module
	# owns no processing callback. Any later content must declare its cost here.
	var contract := StationModuleContract.build_performance_contract(self, {
		"mesh_instances": 48,
		"static_bodies": 33,
		"collision_shapes": 33,
		"labels": 1,
		"lights": 6,
		"process_loops": 0,
		"physics_process_loops": 0,
	})
	contract["schema_version"] = SCHEMA_VERSION
	return contract


func set_module_enabled(enabled: bool) -> void:
	_module_enabled = enabled
	_apply_enabled_state()


func is_module_enabled() -> bool:
	return _module_enabled


func get_lifecycle_contract() -> Dictionary:
	var contract := StationModuleContract.build_lifecycle_contract(
		self, WORLD_LAYER, _module_enabled, self
	)
	contract["schema_version"] = SCHEMA_VERSION
	contract["built"] = _built
	contract["build_generation"] = 1
	return contract


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if _module_anchor == null or not _module_anchor.global_transform.is_finite():
		errors.append("module anchor is missing or non-finite")
	if _route_markers.size() != 6:
		errors.append("route registry must expose exactly six loop waypoints")
	if _walkable_surfaces.size() != WALKABLE_SURFACE_SPECS.size():
		errors.append("walkable surface roster must contain exactly five bodies")
	var area := 0.0
	for spec_variant in WALKABLE_SURFACE_SPECS:
		var spec := spec_variant as Dictionary
		area += float(spec.area_m2)
		var body := get_node_or_null(NodePath("Structure/Walkable/%s" % str(spec.node_name))) as StaticBody3D
		if body == null:
			errors.append("walkable surface is missing: %s" % str(spec.id))
			continue
		if StringName(body.get_meta("walkable_surface_id", &"")) != StringName(spec.id) \
				or StringName(body.get_meta("walkable_surface_kind", &"")) != &"level" \
				or not bool(body.get_meta("walkable_surface", false)):
			errors.append("walkable surface metadata drifted: %s" % str(spec.id))
		if not body.position.is_equal_approx(spec.center as Vector3):
			errors.append("walkable surface transform drifted: %s" % str(spec.id))
		var shape := body.get_node_or_null(^"CollisionShape3D") as CollisionShape3D
		var box := shape.shape as BoxShape3D if shape != null else null
		if box == null or not box.size.is_equal_approx(spec.size as Vector3):
			errors.append("walkable surface extent drifted: %s" % str(spec.id))
	if not is_equal_approx(area, WALKABLE_AREA_M2):
		errors.append("walkable surface area roster no longer totals exactly 426 m2")
	for route_id: StringName in CONNECTION_SLOT_SPECS.keys():
		var marker := get_route_marker(route_id)
		var spec := CONNECTION_SLOT_SPECS[route_id] as Dictionary
		if marker == null \
				or not marker.transform.is_equal_approx(spec.local_transform as Transform3D) \
				or StationModuleContract.new().read_connection_slot_id(marker) != StringName(spec.slot_id):
			errors.append("connection slot transform or identity drifted: %s" % route_id)
	var authority := get_authority_contract()
	if not (authority.authority_ids as PackedStringArray).is_empty() \
			or int(authority.ship_berth_count) != 0 \
			or int(authority.landing_or_interaction_area_count) != 0 \
			or int(authority.audio_node_count) != 0 \
			or int(authority.activity_node_count) != 0 \
			or int(authority.lease_authority_count) != 0 \
			or int(authority.spawn_authority_count) != 0 \
			or StringName(authority.network_authority_role) != &"none":
		errors.append("standalone spur must own zero gameplay authorities")
	var collision := get_collision_contract()
	if not bool(collision.all_layers_match_lifecycle) \
			or not bool(collision.all_masks_zero) \
			or not bool(collision.all_shapes_present_and_enabled):
		errors.append("collision contract does not match lifecycle")
	if not bool(get_performance_contract().within_budget):
		errors.append("module exceeds its frozen performance budgets")
	var lifecycle := get_lifecycle_contract()
	if not bool(lifecycle.reversible) \
			or not bool(lifecycle.visible_matches_enabled) \
			or not bool(lifecycle.collision_matches_enabled) \
			or not bool(lifecycle.process_matches_lifecycle):
		errors.append("lifecycle state is not reversible and quiescent")
	return errors


func audit() -> Dictionary:
	var errors := get_validation_errors()
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"module_id": MODULE_ID,
		"content_class": CONTENT_CLASS,
		"evidence_status": EVIDENCE_STATUS,
		"connection_slots": get_connection_slots(),
		"surface_roster": get_walkable_surface_roster(),
		"walkable_area_m2": WALKABLE_AREA_M2,
		"alternate_return_path": true,
		"authority": get_authority_contract(),
		"performance": get_performance_contract(),
		"footprint": get_integration_footprint(),
	}


func get_audit_report() -> Dictionary:
	return audit().duplicate(true)


func _apply_enabled_state() -> void:
	StationModuleContract.apply_enabled_state(
		StationModuleContract.collect_static_bodies(self), WORLD_LAYER, _module_enabled, self
	)
	set_process(false)
	set_physics_process(false)


func _index_routes() -> void:
	_route_markers = {
		&"origin": _origin_connection,
		&"connector-midpoint": _connector_midpoint,
		&"cross-landing": _cross_landing,
		&"observation-pad": _observation_pad,
		&"logistics-pad": _logistics_pad,
		&"far-return": _far_return,
	}
	for route_id: StringName in _route_markers.keys():
		var marker := _route_markers[route_id] as Marker3D
		marker.set_meta("station_route_marker", true)
		marker.set_meta("route_id", route_id)
	for route_id: StringName in CONNECTION_SLOT_SPECS.keys():
		var marker := get_route_marker(route_id)
		var spec := CONNECTION_SLOT_SPECS[route_id] as Dictionary
		marker.set_meta(StationModuleContract.CONNECTION_SLOT_META, StringName(spec.slot_id))


func _build_module() -> void:
	var structure := Node3D.new()
	structure.name = "Structure"
	add_child(structure)
	var walkable := Node3D.new()
	walkable.name = "Walkable"
	structure.add_child(walkable)
	for spec_variant in WALKABLE_SURFACE_SPECS:
		var spec := spec_variant as Dictionary
		var body := _box(
			walkable,
			str(spec.node_name),
			spec.center as Vector3,
			spec.size as Vector3,
			_materials["deck"],
			true
		) as StaticBody3D
		body.set_meta("walkable_surface", true)
		body.set_meta("walkable_surface_id", StringName(spec.id))
		body.set_meta("walkable_surface_kind", &"level")
		body.set_meta("walkable_surface_owner", MODULE_ID)
		body.set_meta("horizontal_area_m2", float(spec.area_m2))
		_walkable_surfaces.append(body)

	var safety := Node3D.new()
	safety.name = "SafetyRails"
	structure.add_child(safety)
	_build_safety_rails(safety)
	var dressing := Node3D.new()
	dressing.name = "Dressing"
	structure.add_child(dressing)
	_build_dressing(dressing)
	_build_lighting(dressing)


func _build_safety_rails(parent: Node3D) -> void:
	# Connector sides and the exposed cross-landing perimeter. Gaps coincide only
	# with a touching walkable rectangle, never with open void.
	for side in [-1.0, 1.0]:
		_safety_rail(parent, "ConnectorRail", Vector3(float(side) * 2.12, 0.62, 11.0), Vector3(0.16, 1.24, 21.8))
	_safety_rail(parent, "CrossSouthWest", Vector3(-6.1, 0.62, 21.88), Vector3(7.8, 1.24, 0.16))
	_safety_rail(parent, "CrossSouthEast", Vector3(6.1, 0.62, 21.88), Vector3(7.8, 1.24, 0.16))
	_safety_rail(parent, "CrossNorthVoid", Vector3(0.0, 0.62, 26.12), Vector3(5.7, 1.24, 0.16))
	_safety_rail(parent, "CrossWest", Vector3(-10.12, 0.62, 24.0), Vector3(0.16, 1.24, 4.0))
	_safety_rail(parent, "CrossEast", Vector3(10.12, 0.62, 24.0), Vector3(0.16, 1.24, 4.0))
	# Pad outside edges and inner edges up to the far bridge opening.
	for side in [-1.0, 1.0]:
		var outer_x := float(side) * 13.12
		var inner_x := float(side) * 2.88
		_safety_rail(parent, "PadOuterRail", Vector3(outer_x, 0.62, 32.0), Vector3(0.16, 1.24, 12.0))
		_safety_rail(parent, "PadInnerRail", Vector3(inner_x, 0.62, 31.1), Vector3(0.16, 1.24, 10.2))
		_safety_rail(parent, "PadFarRail", Vector3(float(side) * 8.5, 0.62, 38.12), Vector3(9.0, 1.24, 0.16))
	# The far bridge itself has north/south rails and turns the two pad routes into
	# a loop instead of two dead ends.
	_safety_rail(parent, "FarBridgeSouthRail", Vector3(0.0, 0.62, 36.38), Vector3(5.7, 1.24, 0.16))
	_safety_rail(parent, "FarBridgeNorthRail", Vector3(0.0, 0.62, 39.62), Vector3(6.2, 1.24, 0.16))


func _safety_rail(parent: Node3D, node_name: String, position: Vector3, size: Vector3) -> void:
	var rail := _box(parent, node_name, position, size, _materials["rail"], true) as StaticBody3D
	rail.set_meta("station_safety_edge", true)
	rail.set_meta("non_walkable_reason", "physical fall-protection rail at exposed deck edge")


func _build_dressing(parent: Node3D) -> void:
	# Observation pad: three low, outboard instruments and one backed bench. The
	# centre and inner edge stay clear for the alternate-return circulation.
	for console_index in 3:
		var console_z := 28.6 + float(console_index) * 2.8
		_box(parent, "ObservationConsole", Vector3(-11.45, 0.48, console_z), Vector3(0.72, 0.96, 1.35), _materials["shell"], true)
		_box(parent, "ObservationLens", Vector3(-11.05, 0.76, console_z), Vector3(0.035, 0.26, 0.92), _materials["cyan"], false)
	_box(parent, "ObservationBench", Vector3(-5.0, 0.30, 28.0), Vector3(2.6, 0.60, 0.62), _materials["shell"], true)
	# Logistics pad: restrained pallet stacks remain along the outboard edge.
	for stack_index in 3:
		var stack_z := 28.8 + float(stack_index) * 2.75
		_box(parent, "LogisticsPallet", Vector3(11.15, 0.12, stack_z), Vector3(2.4, 0.24, 1.55), _materials["rail"], true)
		for tier_index in 2:
			_box(parent, "LogisticsCase", Vector3(11.15, 0.48 + float(tier_index) * 0.58, stack_z), Vector3(2.1, 0.52, 1.28), _materials["cargo"], true)
	# Sparse connector rhythm provides scale without narrowing its 4 m lane.
	var connector_marker_transforms: Array[Transform3D] = []
	for bay_index in 5:
		var bay_z := 3.0 + float(bay_index) * 4.0
		for side in [-1.0, 1.0]:
			connector_marker_transforms.append(
				Transform3D(Basis.IDENTITY, Vector3(float(side) * 1.88, 0.22, bay_z))
			)
	_multimesh_boxes(
		parent, "ConnectorMarkers", Vector3(0.10, 0.44, 0.62), _materials["amber"], connector_marker_transforms
	)
	_label(parent, "AreaIdentity", "OBSERVATION  //  LOGISTICS", Vector3(0.0, 1.65, 26.25), Color("dbe8e4"))


func _build_lighting(parent: Node3D) -> void:
	var fixtures := [
		[Vector3(0.0, 2.8, 7.0), Color("8fe8ef")],
		[Vector3(0.0, 2.8, 18.0), Color("8fe8ef")],
		[Vector3(0.0, 2.8, 23.5), Color("dbe8e4")],
		[Vector3(-8.0, 2.8, 32.0), Color("8fe8ef")],
		[Vector3(8.0, 2.8, 32.0), Color("f4bf72")],
		[Vector3(0.0, 2.8, 38.0), Color("dbe8e4")],
	]
	for fixture_index in fixtures.size():
		var fixture := fixtures[fixture_index] as Array
		var fixture_position := fixture[0] as Vector3
		var fixture_color := fixture[1] as Color
		_box(parent, "LightMast", fixture_position + Vector3(0, -1.4, 0), Vector3(0.16, 2.8, 0.16), _materials["rail"], false)
		_box(parent, "LightLens", fixture_position, Vector3(0.42, 0.18, 0.42), _emissive_material(fixture_color), false)
		var light := OmniLight3D.new()
		light.name = "Practical%02d" % (fixture_index + 1)
		light.position = fixture_position + Vector3(0, -0.16, 0)
		light.light_color = fixture_color
		light.light_energy = 0.72
		light.omni_range = 8.0
		light.omni_attenuation = 1.8
		light.shadow_enabled = false
		light.distance_fade_enabled = true
		light.distance_fade_begin = 55.0
		light.distance_fade_length = 18.0
		parent.add_child(light)


func _apply_metadata() -> void:
	add_to_group("station_modules")
	set_meta("station_module", true)
	set_meta("module_id", MODULE_ID)
	set_meta("content_class", CONTENT_CLASS)
	set_meta("evidence_status", EVIDENCE_STATUS)
	set_meta("authenticated_original_geometry", false)
	set_meta("content_note", CONTENT_NOTE)


func _create_materials() -> void:
	_materials["deck"] = _material(Color("59666b"), 0.34, 0.46)
	_materials["rail"] = _material(Color("263238"), 0.54, 0.62)
	_materials["shell"] = _material(Color("9ca7a6"), 0.42, 0.30)
	_materials["cargo"] = _material(Color("735c3d"), 0.66, 0.18)
	_materials["cyan"] = _emissive_material(Color("58dce5"))
	_materials["amber"] = _emissive_material(Color("e5a94e"))


func _material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material


func _emissive_material(color: Color) -> StandardMaterial3D:
	var material := _material(color.darkened(0.30), 0.28, 0.18)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.8
	return material


func _box(
		parent: Node3D,
		node_name: String,
		position: Vector3,
		size: Vector3,
		material: Material,
		collidable: bool
	) -> Node3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	if collidable:
		var body := StaticBody3D.new()
		body.name = node_name
		body.position = position
		body.collision_layer = WORLD_LAYER
		body.collision_mask = 0
		parent.add_child(body)
		var visible := MeshInstance3D.new()
		visible.name = "Mesh"
		visible.mesh = mesh
		visible.material_override = material
		body.add_child(visible)
		var collision := CollisionShape3D.new()
		collision.name = "CollisionShape3D"
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
		return body
	var visible := MeshInstance3D.new()
	visible.name = node_name
	visible.position = position
	visible.mesh = mesh
	visible.material_override = material
	visible.set_meta("visual_detail_only", true)
	parent.add_child(visible)
	return visible


func _multimesh_boxes(
		parent: Node3D,
		node_name: String,
		size: Vector3,
		material: Material,
		transforms: Array[Transform3D]
	) -> MultiMeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = box
	multi.instance_count = transforms.size()
	for transform_index in transforms.size():
		multi.set_instance_transform(transform_index, transforms[transform_index])
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multi
	instance.material_override = material
	instance.set_meta("visual_detail_only", true)
	instance.set_meta("authored_instance_transforms", transforms.duplicate())
	parent.add_child(instance)
	return instance


func _label(parent: Node3D, node_name: String, text: String, position: Vector3, color: Color) -> void:
	var label := Label3D.new()
	label.name = node_name
	label.text = text
	label.position = position
	label.rotation_degrees = Vector3(0, 180, 0)
	label.font_size = 52
	label.modulate = color
	label.outline_size = 8
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	parent.add_child(label)
