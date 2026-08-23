extends SceneTree

const PresentationScript := preload("res://scripts/world/planetary_sky_presentation.gd")

func _init() -> void:
	var presentation := PresentationScript.new()
	var daylight := presentation.present_solar_phase_snapshot({
		"state": &"daylight", "sun_elevation_sine": 1.0,
		"twilight_factor_unitless": 0.0,
	})
	var night := presentation.present_solar_phase_snapshot({
		"state": &"night", "sun_elevation_sine": -1.0,
		"twilight_factor_unitless": 0.0,
	})
	if not daylight.accepted or not night.accepted \
			or daylight.sun_energy_unitless <= night.sun_energy_unitless \
			or daylight.sky_exposure_unitless <= night.sky_exposure_unitless \
			or night.night_visibility_unitless <= daylight.night_visibility_unitless:
		push_error("solar phase presentation mapping failed")
		quit(1)
		return
	print("PLANETARY_SKY_SOLAR_PHASE_INTEGRATION_TEST_OK: bounded day/night mapping")
	quit(0)
