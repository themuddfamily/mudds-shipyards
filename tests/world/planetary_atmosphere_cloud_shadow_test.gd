extends SceneTree

const CompositionScene := preload("res://scenes/world/components/aurora_temperate_atmosphere_composition.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var composition := CompositionScene.instantiate() as PlanetaryAtmosphereComposition
	root.add_child(composition)
	await process_frame
	if not composition.configure().accepted:
		push_error("composition configure failed")
		quit(1)
		return
	var applied := composition.apply_retained_presentation_recipe(
		{"state": &"daylight", "sun_elevation_sine": 0.7, "twilight_factor_unitless": 0.0},
		{"intensity_unitless": 0.8, "gust_factor_unitless": 1.1, "shelter_scalar": 0.0, "wind_velocity_mps": Vector3(80.0, 0.0, 0.0)}
	)
	var shadow := composition.get_node(^"OwnedCloudShadowProjection") as MeshInstance3D
	if not applied.accepted or shadow == null or not shadow.visible:
		push_error("owned cloud shadow projection was not enabled")
		quit(1)
		return
	print("PLANETARY_ATMOSPHERE_CLOUD_SHADOW_TEST_OK: bounded owned projection")
	quit(0)
