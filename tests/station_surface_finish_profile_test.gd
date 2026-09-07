extends SceneTree

const StationSurfaceKit = preload("res://scripts/world/station_surface_kit.gd")

## Focused contract for the station's material hierarchy. This intentionally
## does not instantiate the world or render a frame: the profile is a pure
## presentation adapter over the manufactured microfinish map family.

var _failures: Array[String] = []


func _init() -> void:
	var material := StandardMaterial3D.new()
	material.metallic = 0.72
	material.roughness = 0.64
	_check(StationSurfaceKit.apply_panel_triplanar(material, 0.22), "registered panel maps bind")
	_check(
		material.albedo_texture.resource_path == "res://assets/materials/manufactured-paint-albedo.png"
		and material.normal_texture.resource_path == "res://assets/materials/manufactured-paint-normal.png"
		and material.roughness_texture.resource_path == "res://assets/materials/manufactured-paint-roughness.png",
		"station surfaces use fine manufactured grain instead of repeated embossed tiles"
	)
	_check(
		is_equal_approx(material.metallic, 0.72)
		and is_equal_approx(material.roughness, 0.64)
		and material.uv1_world_triplanar
		and material.uv1_scale.is_equal_approx(Vector3.ONE * 0.22),
		"microfinish preserves authored alloy response and continuous world scale"
	)
	_check(material.clearcoat_enabled, "panel finish enables clearcoat")
	_check(
		is_equal_approx(material.clearcoat, StationSurfaceKit.STRUCTURAL_CLEARCOAT)
		and is_equal_approx(material.clearcoat_roughness, StationSurfaceKit.STRUCTURAL_CLEARCOAT_ROUGHNESS),
		"default panel finish is structural alloy"
	)

	var deck := StandardMaterial3D.new()
	StationSurfaceKit.apply_panel_triplanar(
		deck, 0.30, StationSurfaceKit.PanelFinish.WALKED_DECK
	)
	_check(
		is_equal_approx(deck.clearcoat, StationSurfaceKit.WALKED_CLEARCOAT)
		and is_equal_approx(deck.clearcoat_roughness, StationSurfaceKit.WALKED_CLEARCOAT_ROUGHNESS),
		"walked deck has a broad low-gloss response"
	)

	var trim := StandardMaterial3D.new()
	StationSurfaceKit.apply_panel_triplanar(
		trim, 0.22, StationSurfaceKit.PanelFinish.METAL_TRIM
	)
	_check(
		is_equal_approx(trim.clearcoat, StationSurfaceKit.TRIM_CLEARCOAT)
		and is_equal_approx(trim.clearcoat_roughness, StationSurfaceKit.TRIM_CLEARCOAT_ROUGHNESS),
		"metal trim retains a tight highlight response"
	)

	if _failures.is_empty():
		print("OK station_surface_finish_profile_test")
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)
	quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
