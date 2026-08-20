extends SceneTree

const RoutingScript := preload("res://scripts/audio/planetary_surface_audio_routing.gd")
var assertions := 0
var failures := PackedStringArray()

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var routing := RoutingScript.new()
	_check(bool(routing.audit().valid), "routing contract audits green")
	var snapshot := routing.get_snapshot()
	_check(snapshot.layer_ids == [&"exterior", &"interior", &"wind", &"landing"] \
		and snapshot.bus_ids == [&"Ambience", &"Wind", &"SurfaceSFX"] \
		and snapshot.bus_ceilings_db[&"Wind"] == -9.0,
		"four layers and three conservative bus ceilings are frozen")
	var exterior := routing.evaluate(_observation(&"exterior", 0.5, &"none", true))
	var exterior_layers := exterior.layers as Dictionary
	_check(bool(exterior.accepted) and exterior_layers[&"exterior"].active \
		and not exterior_layers[&"interior"].active \
		and exterior_layers[&"wind"].active \
		and exterior_layers[&"landing"].active == false,
		"exterior routes wind and ambience while leaving landing idle")
	_check(float(exterior_layers[&"wind"].gain_db) <= -9.0 \
		and int(exterior.maximum_simultaneous_voices) == 4,
		"wind gain never exceeds its bus ceiling and voice count is bounded")
	var cabin := routing.evaluate(_observation(&"cabin", 1.0, &"approach", false))
	var cabin_layers := cabin.layers as Dictionary
	_check(cabin_layers[&"interior"].active and not cabin_layers[&"exterior"].active \
		and not cabin_layers[&"wind"].active and cabin_layers[&"landing"].active,
		"cabin aliases interior and suppresses exterior wind")
	var touchdown := routing.evaluate(_observation(&"exterior", 0.0, &"touchdown", true))
	_check(touchdown.layers[&"landing"].gain_db == -3.0 \
		and touchdown.layers[&"landing"].bus == &"SurfaceSFX",
		"touchdown exposes a bounded one-shot landing layer on SurfaceSFX")
	_check(routing.evaluate({}).reason == &"invalid_observation_schema" \
		and routing.evaluate(_observation(&"hangar", 0.0, &"none", true)).reason == &"invalid_listener_context" \
		and routing.evaluate(_observation(&"exterior", 1.1, &"none", true)).reason == &"invalid_wind_intensity",
		"invalid shape, context, and wind fail closed")
	_finish()

func _observation(context: StringName, wind: float, landing: StringName, grounded: bool) -> Dictionary:
	return {"listener_context": context, "wind_intensity_unitless": wind, "landing_state": landing, "grounded": grounded}

func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)

func _finish() -> void:
	if failures.is_empty():
		print("PLANETARY_SURFACE_AUDIO_ROUTING_TEST_OK: %d assertions" % assertions)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
