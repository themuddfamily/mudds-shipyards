extends SceneTree

## Focused presentation regression for the wider lattice, catwalk, and control
## room's station-family finish hierarchy. This is a material-only audit: it
## does not claim geometry, lighting, or performance completion.

const WORLD_SCENE := preload("res://scenes/world/shipyard_world.tscn")

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := WORLD_SCENE.instantiate() as ShipyardWorld
	_check(world != null, "ShipyardWorld instantiates for finish-profile audit")
	if world == null:
		_finish()
		return
	root.add_child(world)
	await process_frame
	var materials := world.get("_materials") as Dictionary
	_check(materials != null, "world exposes its constructed material roster")
	if materials != null:
		_check(_finish_matches(materials.get("deck"), 0.06, 0.72), "walked deck uses the restrained matte finish")
		_check(_finish_matches(materials.get("deck_light"), 0.06, 0.72), "light deck uses the restrained matte finish")
		_check(_finish_matches(materials.get("steel_blue"), 0.30, 0.24), "lattice/control-room trim uses the tight edge finish")
		_check(_finish_matches(materials.get("navy"), 0.18, 0.38), "control-room structural panels use the alloy finish")
		for key in ["ivory", "orange", "red"]:
			_check(
				_finish_matches(materials.get(key), 0.45, 0.12),
				"exterior safety-paint %s retains its coated-metal finish" % key,
			)
		for key in ["deck", "deck_light", "navy", "steel_blue"]:
			var material := materials.get(key) as StandardMaterial3D
			_check(
				material != null and material.uv1_triplanar and material.uv1_world_triplanar
				and material.uv1_scale.is_equal_approx(Vector3.ONE * 0.3),
				"wide-station %s keeps the shared world-metric panel mapping" % key
			)
		for key in ["ivory", "orange", "red"]:
			var painted := materials.get(key) as StandardMaterial3D
			_check(
				painted != null and painted.uv1_triplanar and painted.uv1_world_triplanar
				and painted.uv1_scale.is_equal_approx(Vector3.ONE * 0.3),
				"exterior safety-paint %s joins the shared panel family" % key,
			)
		var rail := world.find_child("BranchRail", true, false) as StaticBody3D
		var post := world.find_child("BranchRailPost", true, false) as StaticBody3D
		var toolbox := world.find_child("StandToolbox", true, false) as StaticBody3D
		_check(
			_surface_material(rail) == materials.get("ivory")
			and _surface_material(post) == materials.get("orange")
			and _surface_material(toolbox) == materials.get("red"),
			"paired catwalk guards and service equipment use the coherent safety-paint family",
		)
		var berth := world.get_central_berth_hero_presentation()
		var structure := (
			berth.get_runtime_material(&"StructuralAlloy")
			if berth != null else null
		)
		_check(
			structure != null and structure.uv1_triplanar and structure.uv1_world_triplanar
			and structure.uv1_scale.is_equal_approx(Vector3.ONE * 0.3)
			and _finish_matches(structure, 0.18, 0.38),
			"central-berth structural alloy uses the shared world-metric alloy finish",
		)
		var primary := berth.get_semantic_root(&"primary_structure") if berth != null else null
		var secondary := berth.get_semantic_root(&"secondary_structure") if berth != null else null
		_check(
			_role_root_uses_material(primary, &"StructuralAlloy", structure)
			and _role_root_uses_material(secondary, &"StructuralAlloy", structure),
			"both authored central-berth beam/frame batches use the mapped structural alloy",
		)
		var berth_audit := berth.get_asset_audit_report() if berth != null else {}
		_check(
			bool(berth_audit.get("valid", false))
			and int(berth_audit.get("runtime_mesh_count", 0)) == 8
			and int(berth_audit.get("runtime_triangle_count", 0)) == 11508,
			"material-only berth finish preserves the authored mesh and triangle contract",
		)
	world.queue_free()
	await process_frame
	_finish()


func _finish_matches(value: Variant, clearcoat: float, roughness: float) -> bool:
	var material := value as StandardMaterial3D
	return material != null and material.clearcoat_enabled \
		and is_equal_approx(material.clearcoat, clearcoat) \
		and is_equal_approx(material.clearcoat_roughness, roughness)


func _surface_material(body: StaticBody3D) -> Material:
	if body == null:
		return null
	var mesh := body.get_node_or_null(^"Mesh") as MeshInstance3D
	return mesh.material_override if mesh != null else null


func _role_root_uses_material(root_node: Node3D, role: StringName, material: Material) -> bool:
	if root_node == null or material == null:
		return false
	var matched := false
	for candidate in root_node.find_children("*", "MeshInstance3D", true, false):
		var mesh := candidate as MeshInstance3D
		if StringName(mesh.get_meta("central_berth_material_role", &"")) != role:
			continue
		matched = true
		if mesh.material_override != material:
			return false
	return matched


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: shipyard_world_material_finish_test (%d assertions)" % _assertions)
	else:
		for failure in _failures:
			push_error("FAIL: " + failure)
		print("FAIL: shipyard_world_material_finish_test (%d assertions, %d failures)" % [_assertions, _failures.size()])
	quit(1 if not _failures.is_empty() else 0)
