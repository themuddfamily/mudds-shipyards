extends SceneTree

## Regression for the painted hull shells of the two craft that still build
## their airframes procedurally. Both wear the shared manufactured fleet
## coating rather than a per-craft panel swatch, and the checkpoints that
## settled that look are named against each assertion below so the contract
## can be re-derived rather than guessed at:
##
## - 8e464d28c / a8431e222 / 3662efcbf (2026-09-07) reshaped the Arrow and the
##   inhabited shells onto manufactured geometry and bound
##   `ShipSurfaceDetail.bind_manufactured_paint` to their hull families, which
##   replaced the earlier `arrow-hull-*-v1` / `jovian-hull-*-v1` swatch
##   bindings on those materials. Geometry now owns panel seams, so the craft
##   read apart by tint and projection scale instead of by swatch.
## - 007f94f0b (2026-09-10) "Remove cloudy roughness variation from fleet
##   paint" dropped the coating roughness map: broad variation read as dents on
##   flat hull panels, so the caller's uniform scalar roughness is now the
##   rendered roughness.
## - 549e52ac6 (2026-09-10) "Soften manufactured fleet paint relief under
##   station light" lowered the coating relief from 0.32 to 0.12.
##
## The derived `*-hull-normal-v1` maps are still registered assets and are
## still bound to each craft's *structural* materials; this suite covers the
## painted hull shells only.

const ARROW_SCENE := preload("res://scenes/ships/arrow_recon_ship.tscn")
const JOVIAN_SCENE := preload("res://scenes/ships/jovian_light_freighter.tscn")

const COATING_ALBEDO := "manufactured-paint-albedo"
const COATING_NORMAL := "manufactured-paint-normal"
const COATING_NORMAL_SCALE := 0.12
const ARROW_PANEL_SWATCH := "arrow-hull-albedo-v1"
const ARROW_TRIPLANAR_SCALE := 0.34
const JOVIAN_TRIPLANAR_SCALE := 0.24

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
	_check_family(arrow_materials, ["pearl", "ceramic"], "Arrow", ARROW_TRIPLANAR_SCALE)
	var jovian_materials: Dictionary = jovian.get("_jovian_materials")
	_check_family(
		jovian_materials,
		["hull_warm", "hull_cool"],
		"Jovian",
		JOVIAN_TRIPLANAR_SCALE
	)
	var arrow_pearl := arrow_materials.pearl as StandardMaterial3D
	var jovian_warm := jovian_materials.hull_warm as StandardMaterial3D
	_check(
		not _resource_path(jovian_warm.albedo_texture).contains(ARROW_PANEL_SWATCH),
		"Jovian no longer reuses the Arrow candidate's panel swatch"
	)
	# The two craft share one coating tile on purpose, so the separation the
	# older per-craft swatches provided has to come from the properties the
	# craft still own individually.
	_check(
		not arrow_pearl.albedo_color.is_equal_approx(jovian_warm.albedo_color)
		and not is_equal_approx(arrow_pearl.uv1_scale.x, jovian_warm.uv1_scale.x),
		"Jovian stays visually separate from the Arrow through its own tint and projection scale"
	)
	arrow.queue_free()
	jovian.queue_free()
	await process_frame
	_finish()


func _check_family(
		materials: Dictionary,
		keys: Array,
		label: String,
		triplanar_scale: float
	) -> void:
	for key: String in keys:
		var material := materials.get(key) as StandardMaterial3D
		_check(material != null, "%s %s material exists" % [label, key])
		if material == null:
			continue
		_check(
			_resource_path(material.albedo_texture).contains(COATING_ALBEDO),
			"%s %s uses its registered base-colour map" % [label, key]
		)
		_check(material.normal_enabled and material.normal_scale > 0.0, "%s %s enables a subtle normal response" % [label, key])
		_check(
			_resource_path(material.normal_texture).contains(COATING_NORMAL)
			and is_equal_approx(material.normal_scale, COATING_NORMAL_SCALE),
			"%s %s normal map remains registered to its albedo layout" % [label, key]
		)
		_check(
			material.roughness_texture == null and material.roughness > 0.0,
			"%s %s renders the authored scalar roughness with no roughness map" % [label, key]
		)
		_check(material.uv1_triplanar, "%s %s keeps stable procedural triplanar mapping" % [label, key])
		_check(
			is_equal_approx(material.uv1_scale.x, triplanar_scale)
			and material.uv1_scale.is_equal_approx(Vector3.ONE * triplanar_scale),
			"%s %s keeps its own coating projection scale" % [label, key]
		)


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
