extends SceneTree

const CompositionScene := preload("res://scenes/world/components/aurora_temperate_atmosphere_composition.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var composition := CompositionScene.instantiate() as PlanetaryAtmosphereComposition
	root.add_child(composition)
	await process_frame
	var configured := composition.configure()
	if not configured.accepted:
		push_error("composition configure failed: %s" % configured.reason)
		quit(1)
		return
	var rig := composition.get_atmosphere_rig()
	var sun := rig.get_sun_light()
	var cloud := rig.get_cloud_shell()
	var applied := composition.apply_retained_presentation_recipe(
		{"state": &"night", "sun_elevation_sine": -1.0, "twilight_factor_unitless": 0.0},
		{"intensity_unitless": 0.7, "gust_factor_unitless": 1.1, "shelter_scalar": 0.2, "wind_velocity_mps": Vector3(100.0, 0.0, 0.0)}
	)
	if not applied.accepted or sun.light_energy < 0.1 or sun.light_energy > 1.3 \
			or cloud.transparency < 0.0 or cloud.transparency > 1.0:
		push_error("live atmosphere recipe application failed")
		quit(1)
		return
	print("PLANETARY_ATMOSPHERE_COMPOSITION_RECIPE_TEST_OK: live bounded recipe applied")
	quit(0)
