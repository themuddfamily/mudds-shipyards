extends SceneTree

const BindingScript := preload("res://scripts/world/ember_planetary_surface_production_binding.gd")
const DirectorScript := preload("res://scripts/activities/activity_director.gd")

class FakeHost:
	var generation := 6
	var attachment_generation := 1
	func get_generation() -> int: return generation
	func get_attachment_generation() -> int: return attachment_generation
	func get_phase() -> int: return 8
	func get_snapshot() -> Dictionary:
		return {"host_id": &"ember_surface_loop", "attached": true, "phase_id": &"on_foot", "identities": {"world_id": &"ember_moon"}}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var host := FakeHost.new()
	var director := DirectorScript.new()
	root.add_child(director)
	var binding := BindingScript.new()
	root.add_child(binding)
	var configured := binding.configure(host, director, Callable(self, "_reward_sink"), 6)
	binding.submit_solar_observation(Vector3.UP, Vector3.DOWN, 0.0)
	binding.submit_weather_exposure(&"caldera_thermal_vent", Vector3(58.0, 120000.0, -4.0), 1000.0, 1.0, 0.2, 1.0 / 60.0, 0.0)
	var markers: Dictionary = binding.get_snapshot().landing_markers
	var detached := binding.detach()
	host.attachment_generation = 2
	var reentered := binding.reenter()
	var restored: Dictionary = binding.get_snapshot().landing_markers
	if not configured.accepted or markers.size() != 2 or not markers[&"ember_caldera_pad"].visible \
			or markers[&"ember_caldera_pad"].recipe.is_empty() or not detached.accepted \
			or not reentered.accepted or not restored[&"ember_caldera_pad"].visible \
			or restored[&"ember_caldera_pad"].authority.landing:
		push_error("landing approach production lifecycle failed")
		quit(1)
		return
	print("EMBER_LANDING_APPROACH_PRODUCTION_BINDING_TEST_OK: authored landing marker lifecycle")
	quit(0)

func _reward_sink(_receipt: Dictionary) -> Dictionary:
	return {"accepted": true, "reason": &"test_reward"}
