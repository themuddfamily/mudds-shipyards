extends SceneTree

const BINDING := preload("res://scripts/audio/planetary_travel_audio_binding.gd")
const PRODUCTION := preload("res://scripts/world/ember_surface_loop_production_binding.gd")

var _assertions := 0
var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var production := PRODUCTION.new()
	_check(production.get_planetary_travel_audio_snapshot().get("attached", true) == false, "Ember production exposes an unbound travel-audio seam")
	var binding := BINDING.new()
	_check(bool(binding.attach().get("accepted", false)), "travel audio binding attaches")
	var cues: Array[StringName] = []
	binding.semantic_travel_cue_emitted.connect(func(cue_id: StringName, _intensity: float): cues.append(cue_id))
	for state_id: StringName in [&"orbit_approach", &"atmospheric_entry", &"landed", &"takeoff", &"ascent", &"orbit_return", &"completed"]:
		_check(bool(binding.present_snapshot({"generation": 1, "state_id": state_id}).get("accepted", false)), "state emits %s" % state_id)
	_check(cues.size() == 7, "all travel transitions emit one cue")
	_check(binding.present_snapshot({"generation": 1, "state_id": &"completed"}).get("reason", &"") == &"duplicate_state", "repeated state is deduplicated")
	binding.set_reduced_dynamic_range(true)
	_check(bool(binding.detach().get("accepted", false)), "detach clears travel presentation lifecycle")
	_check(binding.present_snapshot({"generation": 1, "state_id": &"landed"}).get("reason", &"") == &"not_attached", "detached binding rejects stale snapshots")
	_check(int(binding.get_snapshot().get("maximum_simultaneous_voices", 0)) == 2, "travel cue voice ceiling remains two")
	if _failures.is_empty():
		print("PASS planetary_travel_audio_binding_test (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
