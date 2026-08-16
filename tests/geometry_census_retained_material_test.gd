extends SceneTree

## Focused fixture for the geometry census's two material views. It deliberately
## retains resources that are not bound at the frozen phase, shares resources
## across ordinary and MultiMesh bindings, and hides one texture behind a
## ShaderMaterial parameter. The expected union is exact, so omissions and
## double-counting both turn this suite red.

const CENSUS_SCRIPT := preload("res://tools/geometry_census.gd")


class MaterialCatalogFixture:
	extends Node3D

	var retained_component_catalog: Dictionary = {}


var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var fixture := MaterialCatalogFixture.new()
	fixture.name = "MaterialCatalogFixture"
	root.add_child(fixture)

	var override_material := StandardMaterial3D.new()
	var overlay_material := StandardMaterial3D.new()
	var mesh_surface_material := StandardMaterial3D.new()
	var surface_override_material := StandardMaterial3D.new()
	var multimesh_surface_material := StandardMaterial3D.new()
	var shader_material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = "shader_type spatial; uniform sampler2D retained_texture;"
	shader_material.shader = shader
	var image := Image.create(2, 3, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var shader_texture := ImageTexture.create_from_image(image)
	shader_material.set_shader_parameter(&"retained_texture", shader_texture)

	var mesh := BoxMesh.new()
	mesh.material = mesh_surface_material
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "OrdinaryMesh"
	mesh_instance.mesh = mesh
	mesh_instance.material_override = override_material
	mesh_instance.material_overlay = overlay_material
	mesh_instance.set_surface_override_material(0, surface_override_material)
	fixture.add_child(mesh_instance)

	var multimesh_mesh := BoxMesh.new()
	multimesh_mesh.material = multimesh_surface_material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = multimesh_mesh
	multimesh.instance_count = 1
	var multimesh_instance := MultiMeshInstance3D.new()
	multimesh_instance.name = "InstancedMesh"
	multimesh_instance.multimesh = multimesh
	multimesh_instance.material_override = shader_material
	# Shared deliberately: the bound union must deduplicate by resource identity.
	multimesh_instance.material_overlay = overlay_material
	fixture.add_child(multimesh_instance)

	var retained_catalog_material := StandardMaterial3D.new()
	var retained_next_pass := StandardMaterial3D.new()
	var freed_catalog_object := Node.new()
	retained_catalog_material.next_pass = retained_next_pass
	fixture.retained_component_catalog = {
		"freed_object_slot": freed_catalog_object,
		"unbound_alternative": retained_catalog_material,
		"shared_bound_material": override_material,
	}
	freed_catalog_object.free()

	var census := CENSUS_SCRIPT.MaterialResourceCensus.new()
	census.collect_bound(fixture)
	census.collect_retained(fixture)

	_check(census.bound_materials.size() == 6, "frozen-phase census covers override, overlay, ordinary surface/override and MultiMesh surface/override exactly once")
	_check(census.retained_materials.size() == 8, "retained union adds the unbound component-catalog material and its next-pass dependency")
	_check(census.retained_materials.size() > census.bound_materials.size(), "retained and bound material views cannot collapse into the same sampled count")
	_check(census.retained_shaders.size() == 1, "retained union follows the ShaderMaterial shader dependency")
	_check(census.retained_textures.size() == 1, "retained union follows ShaderMaterial parameter textures")
	_check(census.texture_bytes_upper_bound() == 24, "retained 2x3 RGBA texture reports the exact uncompressed upper bound")
	_check(census.skipped_freed_object_references >= 1, "freed catalog slots are reported and skipped without truncating traversal")
	var bound_fingerprint := census.bound_fingerprint()
	var retained_fingerprint := census.retained_fingerprint()
	_check(not bound_fingerprint.is_empty() and bound_fingerprint == census.bound_fingerprint(), "bound fingerprint is stable across repeated reads")
	_check(not retained_fingerprint.is_empty() and retained_fingerprint == census.retained_fingerprint(), "retained fingerprint is stable across repeated reads")
	var repeated_census := CENSUS_SCRIPT.MaterialResourceCensus.new()
	repeated_census.collect_bound(fixture)
	repeated_census.collect_retained(fixture)
	_check(
		bound_fingerprint == repeated_census.bound_fingerprint()
		and retained_fingerprint == repeated_census.retained_fingerprint(),
		"independent collectors produce identical deterministic fingerprints"
	)

	fixture.queue_free()
	await process_frame
	_finish()


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("GEOMETRY_CENSUS_RETAINED_MATERIAL_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	print("GEOMETRY_CENSUS_RETAINED_MATERIAL_TEST_FAILED: %d of %d assertions failed" % [_failures.size(), _assertions])
	for failure in _failures:
		print(" - ", failure)
	quit(1)
