extends SceneTree

const ContractScript := preload("res://scripts/world/planetary_biome_weather_handoff_contract.gd")
var _assertions := 0
var _failures := PackedStringArray()

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var contract = ContractScript.new()
	_check(contract.is_definition_valid(), "authored Ember biome and weather handoff validates")
	var snapshot: Dictionary = contract.get_snapshot()
	var identity := snapshot.get("identity", {}) as Dictionary
	_check(identity.get("world_id") == &"ember_moon" and identity.get("region_id") == &"ember_caldera", "handoff is scoped to one authored world region")
	var biomes := snapshot.get("biomes", []) as Array
	_check(biomes.size() >= 2 and biomes[0].get("material_id") == &"regolith_ash_v1", "biomes publish fixed material IDs")
	_check(_all_biomes_have_ordered_altitudes(biomes), "biomes publish ordered body-local altitude bands")
	var weather := snapshot.get("weather_profiles", []) as Array
	_check(weather.size() >= 2 and weather[1].get("kind") == &"dust_front", "weather publishes authored profile kinds")
	_check(_all_weather_have_audio_and_routes(weather), "weather profiles carry opaque audio and route handoffs")
	var authority := snapshot.get("authority", {}) as Dictionary
	_check(not authority.get("terrain_generation", true) and not authority.get("weather_simulation", true), "handoff owns no terrain or weather runtime authority")
	var misaligned = contract.duplicate(true)
	misaligned.biome_material_ids = PackedStringArray(["only_one"])
	_check(_has_error(misaligned.get_validation_errors(), "parallel"), "biome arrays fail closed when not parallel")
	var invalid_weather = contract.duplicate(true)
	invalid_weather.weather_visibility_scale[0] = 1.5
	_check(_has_error(invalid_weather.get_validation_errors(), "visibility"), "weather visibility remains bounded")
	var unsupported = contract.duplicate(true)
	unsupported.weather_kind_ids[0] = "procedural_noise"
	_check(_has_error(unsupported.get_validation_errors(), "weather kind"), "unsupported procedural weather kinds fail closed")
	var detached := contract.get_snapshot()
	(detached.get("biomes", []) as Array)[0]["material_id"] = &"mutated"
	_check((contract.get_snapshot().get("biomes", []) as Array)[0].get("material_id") == &"regolith_ash_v1", "published snapshots are detached")
	_finish()

func _all_biomes_have_ordered_altitudes(items: Array) -> bool:
	for item in items:
		if float(item.get("altitude_min_m", 1.0)) > float(item.get("altitude_max_m", 0.0)):
			return false
	return true

func _all_weather_have_audio_and_routes(items: Array) -> bool:
	for item in items:
		if item.get("audio_hint_id", &"") == &"" or item.get("route_id", &"") == &"":
			return false
	return true

func _has_error(errors: PackedStringArray, needle: String) -> bool:
	for error in errors:
		if String(error).to_lower().contains(needle.to_lower()):
			return true
	return false

func _check(condition: bool, label: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(label)

func _finish() -> void:
	if _failures.is_empty():
		print("planetary_biome_weather_handoff_contract_test: %d assertions passed" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)
