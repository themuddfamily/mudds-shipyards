extends SceneTree

const CompositionScene := preload("res://scenes/world/components/aurora_temperate_atmosphere_composition.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var composition := CompositionScene.instantiate() as PlanetaryAtmosphereComposition
	root.add_child(composition)
	await process_frame
	if not composition.configure().accepted:
		push_error("atmosphere composition configure failed")
		quit(1)
		return
	var applied := composition.apply_retained_presentation_recipe(
		{"state": &"daylight", "sun_elevation_sine": 0.6, "twilight_factor_unitless": 0.0},
		{"intensity_unitless": 0.3, "cloud_opacity_unitless": 0.2, "altitude_m": 10000.0}
	)
	var snapshot := composition.get_presentation_snapshot()
	root.remove_child(composition)
	await process_frame
	root.add_child(composition)
	await process_frame
	var reentered := composition.get_presentation_snapshot()
	if not applied.accepted or applied.aerial_factor_unitless < 0.49 \
			or applied.aerial_factor_unitless > 0.51 or snapshot.fog_sky_affect < 0.0 \
			or reentered.recipe.aerial_factor_unitless < 0.49 \
			or reentered.recipe.aerial_factor_unitless > 0.51:
		push_error("bounded aerial atmosphere response lifecycle failed")
		quit(1)
		return
	print("PLANETARY_ATMOSPHERE_AERIAL_RESPONSE_TEST_OK: bounded aerial response lifecycle")
	quit(0)
