extends SceneTree
const BindingScript := preload("res://scripts/world/ember_planetary_surface_production_binding.gd")
const DirectorScript := preload("res://scripts/activities/activity_director.gd")
class FakeHost:
	var generation := 10
	var attachment_generation := 1
	func get_generation() -> int: return generation
	func get_attachment_generation() -> int: return attachment_generation
	func get_phase() -> int: return 8
	func get_snapshot() -> Dictionary: return {"host_id": &"ember_surface_loop", "attached": true, "phase_id": &"on_foot", "identities": {"world_id": &"ember_moon"}}
func _init() -> void: call_deferred("_run")
func _run() -> void:
	var host := FakeHost.new()
	var director := DirectorScript.new()
	root.add_child(director)
	var binding := BindingScript.new()
	root.add_child(binding)
	var configured := binding.configure(host, director, Callable(self, "_reward_sink"), 10)
	var started := binding.start_relay_survey()
	var progressed := binding.submit_relay_survey_position(Vector3(180.0, 120009.0, -44.0))
	var detached := binding.detach()
	host.attachment_generation = 2
	var reentered := binding.reenter()
	var snapshot: Dictionary = binding.get_snapshot().relay_survey
	if not configured.accepted or not started.accepted or not progressed.accepted or not detached.accepted \
			or not reentered.accepted or snapshot.activity_id != &"ember_beacon_survey" or snapshot.authority.reward:
		push_error("relay survey production binding lifecycle failed")
		quit(1)
		return
	print("EMBER_RELAY_SURVEY_PRODUCTION_BINDING_TEST_OK: registered activity handoff")
	quit(0)
func _reward_sink(_receipt: Dictionary) -> Dictionary: return {"accepted": true, "reason": &"test_reward"}
