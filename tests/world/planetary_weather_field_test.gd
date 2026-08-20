extends SceneTree

const ProfileScript := preload("res://scripts/world/definitions/planetary_atmosphere_profile.gd")
const FieldScript := preload("res://scripts/world/planetary_weather_field.gd")

var _assertions := 0
var _failures := PackedStringArray()

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var field = FieldScript.new()
	_check(field.sample(0.0, Vector3.ZERO, 0.0, 0.0).reason == &"not_configured", "unconfigured field rejects samples")
	var profile := ProfileScript.new() as PlanetaryAtmosphereProfile
	_check(bool(field.configure(profile).accepted), "valid atmosphere profile configures weather field")
	_check(bool(field.audit().valid), "configured field audit is valid")
	var base := field.sample(3_000.0, Vector3.ZERO, 0.0, 10.0)
	var repeat := field.sample(3_000.0, Vector3.ZERO, 0.0, 10.0)
	_check(bool(base.accepted) and base == repeat, "same caller inputs are deterministic")
	var top := field.sample(6_000.0, Vector3.ZERO, 0.0, 10.0)
	_check(float(base.cloud_layer_factor_unitless) == 0.0 and float(top.cloud_layer_factor_unitless) == 0.0, "cloud top is exclusive")
	var middle := field.sample(4_500.0, Vector3.ZERO, 0.0, 10.0)
	_check(is_equal_approx(float(middle.cloud_layer_factor_unitless), 0.5), "cloud layer interpolation is bounded")
	var fog := field.sample(0.0, Vector3.ZERO, profile.fog_end_distance_m, 0.0)
	_check(is_equal_approx(float(fog.fog_factor_unitless), profile.fog_density_unitless), "fog reaches configured density at end distance")
	var invalid := field.sample(0.0, Vector3.ZERO, 0.0, -1.0)
	_check(invalid.reason == &"invalid_caller_time", "negative caller time is rejected")
	var duplicate := field.configure(ProfileScript.new() as PlanetaryAtmosphereProfile)
	_check(duplicate.reason == &"already_configured", "configuration is immutable")
	_check(field.audit().authority.clock == false and field.audit().authority.renderer == false, "field owns no clock or renderer authority")
	_finish()

func _check(condition: bool, label: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(label)

func _finish() -> void:
	if _failures.is_empty():
		print("PLANETARY_WEATHER_FIELD_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		printerr("PLANETARY_WEATHER_FIELD_TEST_FAIL: %s" % ", ".join(_failures))
		quit(1)
