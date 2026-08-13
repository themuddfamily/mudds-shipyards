extends SceneTree

const ARROW_SCENE := preload("res://scenes/ships/arrow_recon_ship.tscn")
const JOVIAN_SCENE := preload("res://scenes/ships/jovian_light_freighter.tscn")

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var arrow := ARROW_SCENE.instantiate() as ArrowReconShip
	var jovian := JOVIAN_SCENE.instantiate() as JovianLightFreighter
	root.add_child(arrow)
	root.add_child(jovian)
	await process_frame
	var arrow_materials: Dictionary = arrow.get("_arrow_materials")
	_check_family(arrow_materials, ["pearl", "ceramic"], "arrow-hull", "Arrow")
	var jovian_materials: Dictionary = jovian.get("_jovian_materials")
	_check_family(jovian_materials, ["hull_warm", "hull_cool"], "jovian-hull", "Jovian")
	_check(
		_resource_path((jovian_materials.hull_warm as StandardMaterial3D).albedo_texture).contains("jovian-hull-albedo-v1"),
		"Jovian no longer reuses the Arrow candidate's panel swatch"
	)
	arrow.queue_free()
	jovian.queue_free()
	await process_frame
	_finish()


func _check_family(materials: Dictionary, keys: Array, expected_stem: String, label: String) -> void:
	for key: String in keys:
		var material := materials.get(key) as StandardMaterial3D
		_check(material != null, "%s %s material exists" % [label, key])
		if material == null:
			continue
		_check(
			_resource_path(material.albedo_texture).contains("%s-albedo-v1" % expected_stem),
			"%s %s uses its registered base-colour map" % [label, key]
		)
		_check(material.normal_enabled and material.normal_scale > 0.0, "%s %s enables a subtle normal response" % [label, key])
		_check(
			_resource_path(material.normal_texture).contains("%s-normal-v1" % expected_stem),
			"%s %s normal map remains registered to its albedo layout" % [label, key]
		)
		_check(
			_resource_path(material.roughness_texture).contains("%s-roughness-v1" % expected_stem),
			"%s %s roughness map remains registered to its albedo layout" % [label, key]
		)
		_check(material.uv1_triplanar, "%s %s keeps stable procedural triplanar mapping" % [label, key])


func _resource_path(resource: Resource) -> String:
	return resource.resource_path if resource != null else ""


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("FLEET_PBR_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		print("FLEET_PBR_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
