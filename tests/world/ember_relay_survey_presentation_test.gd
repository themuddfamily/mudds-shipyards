extends SceneTree
const BindingScript := preload("res://scripts/world/ember_planetary_surface_production_binding.gd")
const DirectorScript := preload("res://scripts/activities/activity_director.gd")
class FakeHost:
	var generation := 11
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
	var configured := binding.configure(host, director, Callable(self, "_reward_sink"), 11)
	var started := binding.start_relay_survey()
	var presentation: Dictionary = binding.get_snapshot().relay_survey_presentation
	var detached := binding.detach()
	host.attachment_generation = 2
	var reentered := binding.reenter()
	var restored: Dictionary = binding.get_snapshot().relay_survey_presentation
	if not configured.accepted or not started.accepted or not presentation.relay_visible \
			or presentation.return_visible or not detached.accepted or not reentered.accepted \
			or restored.authority.activity or restored.relay_anchor != Vector3(180.0, 120009.0, -44.0):
		push_error("relay survey presentation lifecycle failed")
		quit(1)
		return
	print("EMBER_RELAY_SURVEY_PRESENTATION_TEST_OK: detached objective presentation lifecycle")
	quit(0)
func _reward_sink(_receipt: Dictionary) -> Dictionary: return {"accepted": true, "reason": &"test_reward"}
