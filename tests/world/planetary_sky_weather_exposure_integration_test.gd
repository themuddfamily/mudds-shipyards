extends SceneTree

const PresentationScript := preload("res://scripts/world/planetary_sky_presentation.gd")

func _init() -> void:
	var presentation := PresentationScript.new()
	var mapped := presentation.present_weather_exposure_snapshot({
		"intensity_unitless": 0.8,
		"gust_factor_unitless": 1.2,
		"shelter_scalar": 0.75,
		"wind_velocity_mps": Vector3(2000.0, 0.0, 0.0),
	})
	if not mapped.accepted \
			or mapped.fog_density_unitless < 0.0 or mapped.fog_density_unitless > 1.0 \
			or mapped.cloud_visibility_unitless < 0.0 or mapped.cloud_visibility_unitless > 1.0 \
			or mapped.wind_velocity_mps.length() > 1000.0 \
			or mapped.shelter_factor_unitless <= 0.0:
		push_error("weather exposure presentation mapping failed")
		quit(1)
		return
	print("PLANETARY_SKY_WEATHER_EXPOSURE_INTEGRATION_TEST_OK: bounded weather mapping")
	quit(0)
