extends SceneTree

const BindingScript := preload("res://scripts/world/ember_planetary_surface_production_binding.gd")
const DirectorScript := preload("res://scripts/activities/activity_director.gd")

class FakeHost:
	var generation := 4
	var attachment_generation := 1

	func get_generation() -> int: return generation
	func get_attachment_generation() -> int: return attachment_generation
	func get_phase() -> int: return 8
	func get_snapshot() -> Dictionary:
		return {
			"host_id": &"ember_surface_loop",
			"attached": true,
			"phase_id": &"on_foot",
			"identities": {"world_id": &"ember_moon"},
		}

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := FakeHost.new()
	var director := DirectorScript.new()
	var binding := BindingScript.new()
	root.add_child(director)
	root.add_child(binding)
	await process_frame
	var configured := binding.configure(host, director, Callable(self, "_reward_sink"), 4)
	_check(bool(configured.accepted), "Ember composition configures with audio ownership")
	var solar := binding.submit_solar_observation(Vector3.UP, Vector3(0.0, 1.0, 0.0), 1.0)
	var weather := binding.submit_weather_exposure(
		&"caldera_thermal_vent", Vector3(58.0, 120000.0, -4.0),
		0.0, 1.0, 1.0, 0.25, 0.0
	)
	_check(bool(solar.accepted) and bool(weather.accepted), "retained solar/weather snapshots are accepted")
	var audio_snapshot: Dictionary = binding.get_snapshot().surface_audio
	_check(int(audio_snapshot.source_generation) > 0, "audio adapter consumes a fenced environment generation")
	_check(
		(audio_snapshot.binding as Dictionary).voices.size() == 2,
		"production composition retains the two-voice audio ceiling"
	)
	_check(bool(binding.detach().accepted), "surface detach clears audio attachment through the owner")
	host.attachment_generation = 2
	_check(bool(binding.reenter().accepted), "surface re-entry restores audio attachment")
	_check(
		bool((binding.get_snapshot().surface_audio as Dictionary).binding.attached),
		"audio adapter remains attached after re-entry"
	)
	for failure in _failures:
		push_error(failure)
	print("ember_surface_audio_integration_test: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _reward_sink(_receipt: Dictionary) -> Dictionary:
	return {"accepted": true, "reason": &"test_reward"}


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
