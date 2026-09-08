extends RefCounted

## Shared optical treatment of retained engine plume meshes. The craft remains
## responsible for mounts, scale, visibility, damage, LOD and release/reuse.
## The shader integrates a soft hot core inside the existing mesh envelope;
## it adds no geometry, lights, particle emitters or time-dependent flicker.
const PLUME_SHADER := preload("res://shaders/ships/engine_exhaust.gdshader")
static var _materials: Dictionary = {}


static func install(plume: MeshInstance3D, axis: Vector3 = Vector3.UP, anchor_inlet: bool = false) -> void:
	if plume.mesh == null or plume.has_meta(&"soft_engine_exhaust"):
		return
	var source := plume.get_active_material(0) as StandardMaterial3D
	var color := Color("63efff")
	if source != null:
		color = source.emission if source.emission_enabled else source.albedo_color
	var key := color.to_html()
	var retained := _materials.get(key) as WeakRef
	var material := retained.get_ref() as ShaderMaterial if retained != null else null
	if material == null:
		material = ShaderMaterial.new()
		material.resource_name = "SoftEngineExhaust"
		material.shader = PLUME_SHADER
		material.set_shader_parameter(&"exhaust_color", color)
		material.set_shader_parameter(&"intensity", 4.0)
		_materials[key] = weakref(material)
	plume.material_override = material
	configure_geometry(plume, plume.mesh, axis)
	plume.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	plume.set_meta(&"soft_engine_exhaust", true)
	if anchor_inlet:
		var bounds := plume.mesh.get_aabb()
		var inlet := bounds.get_center() - axis * bounds.size.dot(axis.abs()) * 0.5
		plume.set_meta(&"exhaust_inlet_local", inlet)
		plume.set_meta(&"exhaust_mount", plume.transform * inlet)


## Also accepts a MultiMeshInstance3D whose slots use the same plume mesh.
## Instance uniforms belong to the retained renderer, not the shared material.
static func configure_geometry(renderer: GeometryInstance3D, mesh: Mesh, axis: Vector3 = Vector3.UP) -> void:
	var bounds := mesh.get_aabb()
	renderer.set_instance_shader_parameter(&"plume_center", bounds.get_center())
	renderer.set_instance_shader_parameter(&"plume_half_size", bounds.size * 0.5)
	renderer.set_instance_shader_parameter(&"plume_axis", axis)
	renderer.set_instance_shader_parameter(&"plume_damage_mix", 0.0)


static func create_damage_overlay() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.resource_name = "EngineExhaustDamageOverlay"
	material.shader = PLUME_SHADER
	material.set_shader_parameter(&"damage_pass", true)
	return material


## Preserve the authored nozzle attachment while a centered primitive changes
## length. Imported meshes and native +Z meshes keep their own existing origin.
static func sync_inlet(plume: MeshInstance3D) -> void:
	if not plume.has_meta(&"exhaust_mount"):
		return
	plume.position = (plume.get_meta(&"exhaust_mount") as Vector3) - plume.basis * (plume.get_meta(&"exhaust_inlet_local") as Vector3)
