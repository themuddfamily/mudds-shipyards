extends SceneTree

const Production := preload("res://scripts/world/ember_surface_loop_production_binding.gd")
const Session := preload("res://scripts/world/planetary_travel_session.gd")

var _assertions := 0
var _failures := PackedStringArray()

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var production := Production.new()
	var session := Session.new()
	_check(not bool(production.get_planetary_travel_audio_snapshot().get("attached", true)), "production starts without a travel audio binding")
	_check(bool(production.bind_planetary_travel_audio(session).accepted), "production binds the retained travel session audio seam")
	_check(bool(production.get_planetary_travel_audio_snapshot().get("attached", false)), "production retains the travel audio binding")
	session.presentation_changed.emit({"generation": 1, "state_id": &"orbit_approach", "atmosphere_density_unitless": 0.0, "speed_unitless": 0.2})
	_check(production.get_planetary_travel_audio_snapshot().last_state_id == &"orbit_approach", "orbit presentation reaches production travel audio")
	_check(int(production.get_planetary_travel_audio_snapshot().get("maximum_simultaneous_voices", 0)) == 2, "travel audio remains bounded")
	_check(bool(production.detach_planetary_travel_audio().accepted), "production detaches travel audio cleanly")
	_check(not bool(production.get_planetary_travel_audio_snapshot().get("attached", true)), "detached production travel audio rejects stale lifecycle")
	for failure in _failures:
		push_error(failure)
	print("planetary_travel_audio_production_integration_test: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
