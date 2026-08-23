extends SceneTree

const BindingScript := preload("res://scripts/world/ember_planetary_surface_production_binding.gd")
const DirectorScript := preload("res://scripts/activities/activity_director.gd")

class FakeHost:
	var generation := 7
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
	var configured := binding.configure(host, director, Callable(self, "_reward_sink"), 7)
	var practicals: Dictionary = binding.get_snapshot().settlement_practicals
	var solar := binding.submit_solar_observation(Vector3.UP, Vector3.DOWN, 0.0)
	var night: Dictionary = binding.get_snapshot().settlement_practicals
	var detached := binding.detach()
	host.attachment_generation = 2
	var reentered := binding.reenter()
	var restored: Dictionary = binding.get_snapshot().settlement_practicals
	var first_id: StringName = &"ember_habitat_spine"
	if not configured.accepted or practicals.size() != 4 or not solar.accepted \
			or not night[first_id].visible or not detached.accepted \
			or not reentered.accepted or not restored[first_id].visible \
			or restored[first_id].structure_id != first_id \
			or restored[first_id].authority.gameplay:
		push_error("settlement practical production lifecycle failed")
		quit(1)
		return
	print("EMBER_SETTLEMENT_PRACTICAL_PRODUCTION_BINDING_TEST_OK: authored practical lifecycle")
	quit(0)

func _reward_sink(_receipt: Dictionary) -> Dictionary:
	return {"accepted": true, "reason": &"test_reward"}
