extends SceneTree

const AtmosphereScene := preload("res://scenes/world/components/aurora_temperate_atmosphere_composition.tscn")
const WaterScript := preload("res://scripts/world/planetary_water_presentation.gd")
const PracticalScript := preload("res://scripts/world/planetary_settlement_practical_presentation.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var atmosphere := AtmosphereScene.instantiate() as PlanetaryAtmosphereComposition
	root.add_child(atmosphere)
	var water := WaterScript.new()
	var practical := PracticalScript.new()
	root.add_child(water)
	root.add_child(practical)
	await process_frame
	var configured: bool = atmosphere.configure().accepted and water.configure().accepted and practical.configure(&"ember_habitat_spine").accepted
	var recipe := atmosphere.apply_retained_presentation_recipe({"state": &"night", "sun_elevation_sine": -1.0}, {"cloud_opacity_unitless": 0.8, "altitude_m": 0.0})
	water.apply_presentation_recipe({"sun_energy_unitless": 0.4}, {"sky_exposure_unitless": 0.3, "wind_velocity_mps": Vector3(100.0, 0.0, 0.0)})
	practical.apply_solar_phase({"state": &"night", "sun_elevation_sine": -1.0})
	var low: bool = atmosphere.apply_graphics_profile(&"low").accepted and water.apply_graphics_profile(&"low").accepted and practical.apply_graphics_profile(&"low").accepted
	var low_snapshot := practical.get_snapshot()
	var high: bool = atmosphere.apply_graphics_profile(&"high").accepted and water.apply_graphics_profile(&"high").accepted and practical.apply_graphics_profile(&"high").accepted
	if not configured or not recipe.accepted or not low or not high or low_snapshot.energy > 0.4501 or atmosphere.get_presentation_snapshot().graphics_profile != &"high":
		push_error("graphics profile presentation lifecycle failed")
		quit(1)
		return
	print("PLANETARY_PRESENTATION_GRAPHICS_PROFILE_TEST_OK: low/high bounded presentation")
	quit(0)
