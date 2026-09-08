extends SceneTree
const BindingScript := preload("res://scripts/world/ember_planetary_surface_production_binding.gd")
const DirectorScript := preload("res://scripts/activities/activity_director.gd")
class FakeHost:
	var snapshot_count := 0
	var generation := 10
	var attachment_generation := 1
	func get_generation() -> int: return generation
	func get_attachment_generation() -> int: return attachment_generation
	func get_phase() -> int: return 8
	func get_snapshot() -> Dictionary:
		snapshot_count += 1
		return {"host_id": &"ember_surface_loop", "attached": true, "phase_id": &"on_foot", "identities": {"world_id": &"ember_moon"}}
	func get_return_status_snapshot() -> Dictionary:
		return {"attached": true, "phase_id": &"on_foot"}
var _failures := PackedStringArray()
var _reward_calls := 0
func _init() -> void: call_deferred("_run")
func _run() -> void:
	await _test_production_position_progress()
	var host := FakeHost.new()
	var director := DirectorScript.new()
	root.add_child(director)
	var binding := BindingScript.new()
	root.add_child(binding)
	var configured := binding.configure(host, director, Callable(self, "_reward_sink"), 10)
	var started := binding.start_relay_survey()
	var progressed := binding.submit_relay_survey_position(Vector3(180.0, 120009.0, -44.0))
	var saved: Dictionary = binding.get_session_snapshot()
	var detached := binding.detach()
	host.attachment_generation = 2
	var reentered := binding.reenter()
	var restored := binding.restore_session_snapshot(saved)
	var corrupt := binding.restore_session_snapshot({"schema_version": 999})
	var snapshot: Dictionary = binding.get_snapshot().relay_survey
	if not configured.accepted or not started.accepted or not progressed.accepted or not detached.accepted \
			or not reentered.accepted or not restored.accepted or corrupt.accepted \
			or snapshot.activity_id != &"ember_beacon_survey" or snapshot.authority.reward:
		push_error("relay survey production binding lifecycle failed")
		quit(1)
		return
	if not _failures.is_empty():
		push_error("; ".join(_failures))
		quit(1)
		return
	print("EMBER_RELAY_SURVEY_PRODUCTION_BINDING_TEST_OK: registered activity handoff; production route/presentation parity without Host reports")
	quit(0)
func _reward_sink(_receipt: Dictionary) -> Dictionary:
	_reward_calls += 1
	return {"accepted": true, "reason": &"test_reward"}


func _test_production_position_progress() -> void:
	var host := FakeHost.new()
	var bindings := [BindingScript.new(), BindingScript.new()]
	var directors := [DirectorScript.new(), DirectorScript.new()]
	for index in range(2):
		root.add_child(directors[index])
		root.add_child(bindings[index])
		_check(bindings[index].configure(host, directors[index], Callable(self, "_reward_sink"), 10).accepted
			and bindings[index].start_relay_survey().accepted, "matched relay bindings start")
	var held_public: Dictionary = {}
	for position in [Vector3(180, 120009, -44), Vector3.ZERO, Vector3(540, 120030, -210)]:
		var full: Dictionary = bindings[0].submit_relay_survey_position(position)
		var reads := host.snapshot_count
		var focused: Dictionary = bindings[1].submit_relay_survey_position_for_production(position)
		_check(host.snapshot_count == reads, "production relay submissions build zero discarded Host reports")
		_check(focused == {"accepted": full.accepted, "reason": full.reason}, "production acceptance/reason parity")
		var public_state: Dictionary = bindings[0].get_snapshot()
		var focused_state: Dictionary = bindings[1].get_snapshot()
		for key in ["adapter", "relay_survey", "relay_survey_presentation", "sample_rack_interaction"]:
			_check(public_state[key] == focused_state[key], "production route and presentation parity: " + key)
		if held_public.is_empty(): held_public = full
	_check(held_public.adapter.activity_reward.state == &"active"
		and held_public.next_checkpoint_index == 1,
		"public submission keeps its complete detached historical diagnostics")
	var calls := _reward_calls
	for binding in bindings:
		_check(binding.commit_relay_survey_reward().accepted, "production-progressed route commits reward")
		_check(not binding.commit_relay_survey_reward().accepted, "production-progressed route rejects replay")
	_check(_reward_calls == calls + 2, "production progression preserves one callback per completion")
	for node in bindings + directors: node.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition: _failures.append(message)
