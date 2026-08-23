extends SceneTree

const ContractScript := preload("res://scripts/world/planetary_surface_navigation_contract.gd")
const RuntimeScript := preload("res://scripts/world/planetary_surface_hazard_runtime.gd")
const WeatherScript := preload("res://scripts/world/planetary_weather_field.gd")
const ProfileScript := preload("res://scripts/world/definitions/planetary_atmosphere_profile.gd")

var _assertions := 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var runtime := RuntimeScript.new()
	_check(runtime.configure(ContractScript.new()).accepted, "authored hazards configure the runtime")
	_check(
		 runtime.submit_exposure(&"missing", Vector3.ZERO, 1.0, 1.0).reason == &"unknown_hazard",
		"unknown hazards fail closed"
	)
	var heat_position := Vector3(58.0, 120000.0, -4.0)
	_check(
		runtime.submit_exposure(&"caldera_thermal_vent", Vector3.ZERO, 1.0, 1.0).reason == &"hazard_out_of_range",
		"caller position must reach the authored hazard before exposure applies"
	)
	var first := runtime.submit_exposure(
		&"caldera_thermal_vent", heat_position, 1.0, 1.0
	)
	_check(
		first.accepted
			and first.damage_request.requested
			and float(first.damage_request.amount_unitless) == 0.4
			and first.damage_request.health_mutation == false,
		"heat exposure emits a bounded damage request without mutating health"
	)
	for _index in 7:
		runtime.submit_exposure(&"caldera_thermal_vent", heat_position, 1.0, 1.0)
	var escalated := runtime.submit_exposure(
		&"caldera_thermal_vent", heat_position, 1.0, 1.0
	)
	_check(
		escalated.recovery_request.requested
			and escalated.recovery_request.recovery_id == &"return_to_landed_ship"
			and is_equal_approx(float(escalated.exposure_unitless), 0.9),
		"accumulated exposure requests the authored recoverable return"
	)
	var cooled := runtime.submit_exposure(
		&"caldera_thermal_vent", heat_position, 0.0, 1.0
	)
	_check(
		cooled.accepted
			and not cooled.damage_request.requested
			and float(cooled.exposure_unitless) < float(escalated.exposure_unitless),
		"zero exposure cools the hazard accumulator and emits no damage request"
	)
	_check(
		runtime.get_snapshot().authority.health == false
		and runtime.get_snapshot().authority.movement == false,
		"hazard runtime retains no health or movement authority"
	)
	var neutral_profile := ProfileScript.new()
	neutral_profile.weather_intensity_unitless = 0.0
	neutral_profile.wind_velocity_mps = Vector3.ZERO
	var neutral_weather := WeatherScript.new()
	neutral_weather.configure(neutral_profile)
	var neutral_runtime := RuntimeScript.new()
	neutral_runtime.configure(ContractScript.new())
	neutral_runtime.bind_weather_field(neutral_weather)
	var neutral := neutral_runtime.submit_weather_exposure(
		&"caldera_thermal_vent", heat_position, 0.0, 0.0, 0.5, 1.0
	)
	_check(
		neutral.accepted
			and is_equal_approx(float(neutral.exposure_unitless), 0.05)
			and neutral.weather.wind_direction == Vector3.ZERO,
		"neutral weather leaves exposure unchanged and emits no wind direction"
	)
	var storm_profile := ProfileScript.new()
	storm_profile.weather_intensity_unitless = 1.0
	storm_profile.wind_velocity_mps = Vector3(20.0, 0.0, 0.0)
	var storm_weather := WeatherScript.new()
	storm_weather.configure(storm_profile)
	var storm_runtime := RuntimeScript.new()
	storm_runtime.configure(ContractScript.new())
	storm_runtime.bind_weather_field(storm_weather)
	var storm := storm_runtime.submit_weather_exposure(
		&"caldera_thermal_vent", heat_position, 0.0, 0.0, 0.5, 1.0
	)
	_check(
		storm.accepted
			and float(storm.exposure_unitless) > float(neutral.exposure_unitless)
			and storm.weather.wind_direction == Vector3.RIGHT,
		"storm intensity scales exposure and returns authored wind direction"
	)
	var sheltered_runtime := RuntimeScript.new()
	sheltered_runtime.configure(ContractScript.new())
	sheltered_runtime.bind_weather_field(storm_weather)
	var sheltered := sheltered_runtime.submit_weather_exposure(
		&"caldera_thermal_vent", heat_position, 0.0, 0.0, 0.5, 1.0, 1.0
	)
	_check(
		sheltered.accepted
			and float(sheltered.exposure_unitless) < float(storm.exposure_unitless)
			and is_equal_approx(float(sheltered.weather.shelter_factor), 0.25),
		"caller shelter evidence reduces storm exposure without interior authority"
	)
	_finish()


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: planetary_surface_hazard_runtime (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error("FAIL: " + failure)
		quit(1)
