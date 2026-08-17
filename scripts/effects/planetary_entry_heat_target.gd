class_name PlanetaryEntryHeatTarget
extends Node3D

## Authored, collision-free renderer target for PlanetaryEntryHeatPresentation.
##
## This node does not configure the presentation or infer a ship. The caller
## explicitly attaches the target to an appropriate visual anchor and supplies
## a validated atmosphere profile to the child adapter.

const SCHEMA_VERSION := 1
const COMPONENT_ID: StringName = &"planetary-entry-heat-target"
const OVERLAY_NODE_NAME: StringName = &"Overlay"
const PRESENTATION_NODE_NAME: StringName = &"Presentation"
const OWNED_PARAMETER: StringName = &"entry_effect_intensity_unitless"
const AUTHORED_SHADER := preload(
	"res://scripts/rendering/planetary_entry_heat_overlay.gdshader"
)
const AUTHORED_SHADER_SHA256 := "84cb6aee9e549840ae82a29114ea5d20ccfd20553b7ee3e763ef4522d5c1f1a9"
const EXPECTED_SHADER_PARAMETER_TYPES := {
	"entry_effect_intensity_unitless": TYPE_FLOAT,
	"entry_heat_color": TYPE_COLOR,
	"entry_heat_max_alpha": TYPE_FLOAT,
	"entry_heat_emission_multiplier": TYPE_FLOAT,
	"entry_heat_fresnel_exponent": TYPE_FLOAT,
}
const EXPECTED_SHADER_DECLARATIONS := [
	"uniform float entry_effect_intensity_unitless : hint_range(0.0, 1.0) = 0.0;",
	"uniform vec4 entry_heat_color : source_color = vec4(1.0, 0.22, 0.035, 1.0);",
	"uniform float entry_heat_max_alpha : hint_range(0.0, 1.0) = 0.62;",
	"uniform float entry_heat_emission_multiplier : hint_range(0.0, 16.0) = 5.0;",
	"uniform float entry_heat_fresnel_exponent : hint_range(0.25, 8.0) = 2.4;",
]
const EXPECTED_DISPLAY_PARAMETERS := {
	"entry_heat_color": Color(1.0, 0.22, 0.035, 1.0),
	"entry_heat_max_alpha": 0.62,
	"entry_heat_emission_multiplier": 5.0,
	"entry_heat_fresnel_exponent": 2.4,
}
const EXPECTED_AUTHORED_VISUAL_BOUNDS := AABB(
	Vector3(-4.0, -2.0, -7.0), Vector3(8.0, 4.0, 14.0)
)
const EXPECTED_STANDOFF_M := 0.25
const EXPECTED_RADIAL_SEGMENTS := 32
const EXPECTED_RINGS := 16
const AUTHORITY := {
	"renderer": true,
	"gameplay": false,
	"streaming": false,
	"save": false,
	"network": false,
	"physics": false,
	"world_generation": false,
	"terrain_generation": false,
	"collision_generation": false,
	"origin_shift": false,
	"weather_clock": false,
	"audio": false,
}
const ADJACENT_AUTHORITY := {
	"collision": false,
	"damage": false,
	"movement": false,
	"ship_visibility": false,
	"engine_presentation": false,
	"damage_presentation": false,
	"gameplay_heat": false,
	"physics_drag": false,
	"weather": false,
	"time": false,
	"audio": false,
	"streaming": false,
	"save": false,
	"network": false,
	"visual_quality": false,
}
const EVIDENCE := {
	"content_class": &"NEW",
	"status": &"modern_interpretation",
	"source_bounded": false,
	"confidence": &"none",
}

@export var authored_visual_bounds := EXPECTED_AUTHORED_VISUAL_BOUNDS
@export_range(0.0, 10.0, 0.01) var overlay_standoff_m := EXPECTED_STANDOFF_M

var _authored_mesh_instance_id := 0
var _authored_material_instance_id := 0
var _authored_shader_instance_id := 0


func _ready() -> void:
	var overlay := get_overlay()
	var material := get_material()
	var mesh := overlay.mesh if overlay != null else null
	var shader := material.shader if material != null else null
	_authored_mesh_instance_id = mesh.get_instance_id() if mesh != null else 0
	_authored_material_instance_id = (
		material.get_instance_id() if material != null else 0
	)
	_authored_shader_instance_id = (
		shader.get_instance_id() if shader != null else 0
	)


func get_overlay() -> MeshInstance3D:
	return get_node_or_null(NodePath(String(OVERLAY_NODE_NAME))) as MeshInstance3D


func get_material() -> ShaderMaterial:
	var overlay := get_overlay()
	if overlay == null:
		return null
	return overlay.material_override as ShaderMaterial


func get_presentation() -> PlanetaryEntryHeatPresentation:
	return get_node_or_null(
		NodePath(String(PRESENTATION_NODE_NAME))
	) as PlanetaryEntryHeatPresentation


func get_expanded_visual_bounds() -> AABB:
	return authored_visual_bounds.grow(overlay_standoff_m)


func is_contract_valid() -> bool:
	return bool(audit().get("valid", false))


func audit() -> Dictionary:
	var errors := PackedStringArray()
	var overlay := get_overlay()
	var presentation := get_presentation()
	if get_child_count() != 2:
		errors.append("exactly_two_direct_children_required")
	if overlay == null:
		errors.append("overlay_missing")
	if presentation == null:
		errors.append("presentation_missing")
	if authored_visual_bounds != EXPECTED_AUTHORED_VISUAL_BOUNDS \
			or overlay_standoff_m != EXPECTED_STANDOFF_M:
		errors.append("authored_bounds_drift")
	if not _aabb_is_finite_and_bounded(authored_visual_bounds):
		errors.append("authored_bounds_invalid")
	if _authored_mesh_instance_id == 0 \
			or _authored_material_instance_id == 0 \
			or _authored_shader_instance_id == 0:
		errors.append("authored_resource_identity_not_captured")
	if overlay != null:
		_validate_overlay(errors, overlay)
	if _contains_forbidden_authority_node(self):
		errors.append("forbidden_authority_node_present")
	if not _evidence_contract_is_valid(EVIDENCE):
		errors.append("evidence_contract_drift")
	if is_processing() or is_physics_processing() \
			or has_method("_process") or has_method("_physics_process"):
		errors.append("target_gained_process_authority")
	errors.sort()
	var material := get_material()
	var shader := material.shader if material != null else null
	var mesh := overlay.mesh if overlay != null else null
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"valid": errors.is_empty(),
		"errors": errors,
		"authored_visual_bounds": authored_visual_bounds,
		"expanded_visual_bounds": get_expanded_visual_bounds(),
		"overlay_standoff_m": overlay_standoff_m,
		"nodes": {
			"direct_child_count": get_child_count(),
			"mesh_instance_count": _count_type(self, &"MeshInstance3D"),
			"collision_object_count": _count_type(self, &"CollisionObject3D"),
			"collision_shape_count": _count_type(self, &"CollisionShape3D"),
			"light_count": _count_type(self, &"Light3D"),
			"particle_count": _count_type(self, &"GPUParticles3D"),
			"audio_count": _count_type(self, &"AudioStreamPlayer3D"),
		},
		"renderer": {
			"overlay_available": overlay != null,
			"mesh_resource_instance_id": mesh.get_instance_id() if mesh != null else 0,
			"material_instance_id": material.get_instance_id() if material != null else 0,
			"shader_instance_id": shader.get_instance_id() if shader != null else 0,
			"surface_count": mesh.get_surface_count() if mesh != null else 0,
			"material_local_to_scene": material.resource_local_to_scene if material != null else false,
			"intensity_baseline": material.get_shader_parameter(OWNED_PARAMETER) if material != null else null,
		},
		"performance": {
			"renderer_node_count": 1,
			"surface_count": 1,
			"submission_hint_count": 1,
			"live_material_count_per_target": 1,
			"shared_mesh_resource_count": 1,
			"shared_shader_resource_count": 1,
			"process_loop_count": 0,
		},
		"capabilities": {
			"authored_target_resource_ownership": true,
			"exclusive_live_material": true,
			"immutable_shared_mesh": true,
			"immutable_shared_shader": true,
			"bounded_overlay_geometry": true,
			"high_low_same_target_contract": true,
			"physical_bow_shock": false,
			"directional_airflow_shape": false,
			"ship_integration": false,
		},
		"evidence": EVIDENCE.duplicate(true),
		"authority": AUTHORITY.duplicate(true),
		"adjacent_authority": ADJACENT_AUTHORITY.duplicate(true),
	}.duplicate(true)


func get_audit_report() -> Dictionary:
	return audit().duplicate(true)


func _validate_overlay(errors: PackedStringArray, overlay: MeshInstance3D) -> void:
	var expanded := get_expanded_visual_bounds()
	if overlay.name != OVERLAY_NODE_NAME \
			or overlay.position != expanded.get_center() \
			or overlay.rotation != Vector3.ZERO \
			or overlay.scale != expanded.size * 0.5:
		errors.append("overlay_transform_drift")
	if overlay.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF \
			or overlay.gi_mode != GeometryInstance3D.GI_MODE_DISABLED \
			or overlay.visibility_range_begin != 0.0 \
			or overlay.visibility_range_end != 0.0:
		errors.append("overlay_renderer_contract_drift")
	if not overlay.mesh is SphereMesh:
		errors.append("overlay_mesh_type_invalid")
	else:
		var sphere := overlay.mesh as SphereMesh
		if sphere.get_instance_id() != _authored_mesh_instance_id:
			errors.append("overlay_mesh_identity_drift")
		if sphere.radius != 1.0 or sphere.height != 2.0 \
				or sphere.radial_segments != EXPECTED_RADIAL_SEGMENTS \
				or sphere.rings != EXPECTED_RINGS \
				or sphere.get_surface_count() != 1:
			errors.append("overlay_mesh_recipe_drift")
	var material := overlay.material_override as ShaderMaterial
	if material == null or not material.resource_local_to_scene:
		errors.append("exclusive_material_contract_invalid")
	else:
		if material.get_instance_id() != _authored_material_instance_id:
			errors.append("overlay_material_identity_drift")
		var shader := material.shader
		if shader == null or shader.get_mode() != Shader.MODE_SPATIAL:
			errors.append("entry_shader_contract_invalid")
		elif shader != AUTHORED_SHADER \
				or shader.get_instance_id() != _authored_shader_instance_id:
			errors.append("entry_shader_identity_drift")
		elif not _shader_has_exact_parameter_contract(shader):
			errors.append("entry_shader_schema_drift")
		elif shader.code.sha256_text() != AUTHORED_SHADER_SHA256:
			errors.append("entry_shader_source_drift")
		if not _display_parameters_are_authored(material):
			errors.append("entry_display_parameter_drift")
		var intensity: Variant = material.get_shader_parameter(OWNED_PARAMETER)
		if not (intensity is float or intensity is int) \
				or not is_finite(float(intensity)) \
				or float(intensity) < 0.0 or float(intensity) > 1.0:
			errors.append("entry_intensity_out_of_bounds")
		elif get_presentation() != null \
				and not bool(get_presentation().get_state_snapshot().configured) \
				and float(intensity) != 0.0:
			errors.append("authored_entry_intensity_baseline_not_zero")


func _shader_has_exact_parameter_contract(shader: Shader) -> bool:
	for declaration: String in EXPECTED_SHADER_DECLARATIONS:
		if not shader.code.contains(declaration):
			return false
	var found := {}
	for entry: Dictionary in shader.get_shader_uniform_list():
		var name := String(entry.get("name", ""))
		if EXPECTED_SHADER_PARAMETER_TYPES.has(name):
			found[name] = int(entry.get("type", TYPE_NIL))
	if found.size() != EXPECTED_SHADER_PARAMETER_TYPES.size():
		return false
	for name: String in EXPECTED_SHADER_PARAMETER_TYPES:
		if int(found.get(name, TYPE_NIL)) != int(
			EXPECTED_SHADER_PARAMETER_TYPES[name]
		):
			return false
	return true


func _display_parameters_are_authored(material: ShaderMaterial) -> bool:
	for parameter_name: String in EXPECTED_DISPLAY_PARAMETERS:
		if material.get_shader_parameter(parameter_name) \
				!= EXPECTED_DISPLAY_PARAMETERS[parameter_name]:
			return false
	return true


func _aabb_is_finite_and_bounded(bounds: AABB) -> bool:
	if not bounds.position.is_finite() or not bounds.size.is_finite():
		return false
	if bounds.size.x < 0.1 or bounds.size.y < 0.1 or bounds.size.z < 0.1:
		return false
	if bounds.size.x > 1000.0 or bounds.size.y > 1000.0 \
			or bounds.size.z > 1000.0:
		return false
	return bounds.position.abs().max_axis_index() >= 0 \
		and bounds.position.length() <= 2000.0


func _evidence_contract_is_valid(candidate: Dictionary) -> bool:
	return candidate.size() == 4 \
		and candidate.get("content_class") == &"NEW" \
		and candidate.get("status") == &"modern_interpretation" \
		and candidate.get("source_bounded") is bool \
		and candidate.get("source_bounded") == false \
		and candidate.get("confidence") == &"none"


func _contains_forbidden_authority_node(node: Node) -> bool:
	for child in node.get_children():
		if child is CollisionObject3D or child is CollisionShape3D \
				or child is Light3D or child is GPUParticles3D \
				or child is AudioStreamPlayer or child is Timer \
				or child is AnimationPlayer:
			return true
		if _contains_forbidden_authority_node(child):
			return true
	return false


func _count_type(node: Node, type_name: StringName) -> int:
	var count := 1 if node.is_class(String(type_name)) else 0
	for child in node.get_children():
		count += _count_type(child, type_name)
	return count
