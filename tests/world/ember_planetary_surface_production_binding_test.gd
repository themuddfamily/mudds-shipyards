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
		return {"host_id": &"ember_surface_loop", "attached": true, "phase_id": &"on_foot", "identities": {"world_id": &"ember_moon"}}

var _assertions := 0
var _failures := PackedStringArray()

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var host := FakeHost.new()
	var director := DirectorScript.new()
	root.add_child(director)
	var binding := BindingScript.new()
	var configured := binding.configure(host, director, Callable(self, "_reward_sink"), 4)
	_check(configured.accepted and configured.runtime.composition_generation == 1 and configured.runtime.navigation.state == &"idle" and configured.runtime.hazard.configured and configured.runtime.water.state == &"idle" and configured.runtime.landmarks.configured and configured.runtime.settlement.configured, "one generation-fenced Ember composition retains all planetary runtimes")
	var discovered := binding.discover_settlements(Vector3(92.0, 120000.5, -18.0), 20.0)
	var entered := binding.enter_settlement(&"ember_habitat_spine", Vector3(92.0, 120000.5, -18.0))
	_check(discovered.accepted and entered.accepted and entered.receipt.route_id == &"ember_pad_to_settlement_spine", "production composition forwards authored discovery and entry")
	_check(binding.detach().accepted and binding.get_snapshot().state == &"detached" and binding.get_snapshot().settlement.state == &"detached", "detaching publishes the surface composition and settlement state")
	host.attachment_generation = 2
	_check(binding.reenter().accepted and binding.get_snapshot().state == &"bound" and binding.get_snapshot().settlement.state == &"inside" and binding.enter_settlement(&"ember_habitat_spine", Vector3(92.0, 120000.5, -18.0)).reason == &"settlement_entry_already_consumed", "re-entry preserves the settlement handoff without duplicate entry authority")
	director.queue_free()
	await process_frame
	if not _failures.is_empty():
		for failure in _failures: push_error(failure)
		quit(1)
		return
	print("EMBER_PLANETARY_SURFACE_PRODUCTION_BINDING_TEST_OK: %d assertions" % _assertions)
	quit(0)

func _reward_sink(_receipt: Dictionary) -> Dictionary:
	return {"accepted": true, "reason": &"test_reward"}

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition: _failures.append(message)
