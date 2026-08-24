extends SceneTree

const BINDING := preload("res://scripts/audio/planetary_travel_audio_binding.gd")

class SnapshotSession extends RefCounted:
	signal presentation_changed(snapshot: Dictionary)

	var snapshot: Dictionary = {}

	func get_presentation_snapshot() -> Dictionary:
		return snapshot.duplicate(true)

var _assertions := 0
var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var binding := BINDING.new()
	_check(bool(binding.attach().get("accepted", false)), "travel audio binding attaches")
	var cues: Array[StringName] = []
	binding.semantic_travel_cue_emitted.connect(func(cue_id: StringName, _intensity: float): cues.append(cue_id))
	for state_id: StringName in [&"orbit_approach", &"atmospheric_entry", &"landed", &"takeoff", &"ascent", &"orbit_return", &"completed"]:
		_check(bool(binding.present_snapshot({"generation": 1, "state_id": state_id}).get("accepted", false)), "state emits %s" % state_id)
	_check(cues.size() == 7, "all travel transitions emit one cue")
	var mix_update := binding.present_snapshot({"generation": 1, "state_id": &"ascent", "last_sample": {"speed_meters_per_second": 80_000.0, "atmosphere_density_unitless": 0.6}})
	var mix := binding.get_snapshot().get("mix", {}) as Dictionary
	_check(bool(mix_update.get("accepted", false)) and float(mix.get("wind_gain_unitless", 0.0)) > 0.0 and float(mix.get("low_pass_hz", 18_000.0)) < 18_000.0, "same-state detached samples update bounded atmospheric mix")
	_check(bool(binding.present_snapshot({"generation": 1, "state_id": &"completed"}).get("accepted", false)), "returned-to-station transition remains audible after mix update")
	_check(binding.present_snapshot({"generation": 1, "state_id": &"completed"}).get("reason", &"") == &"duplicate_state", "repeated state is deduplicated")
	binding.set_reduced_dynamic_range(true)
	_check(bool(binding.detach().get("accepted", false)), "detach clears travel presentation lifecycle")
	_check(binding.present_snapshot({"generation": 1, "state_id": &"landed"}).get("reason", &"") == &"not_attached", "detached binding rejects stale snapshots")
	_check(int(binding.get_snapshot().get("maximum_simultaneous_voices", 0)) == 2, "travel cue voice ceiling remains two")
	var retained_session := SnapshotSession.new()
	retained_session.snapshot = {"generation": 8, "state_id": &"ascent", "atmosphere_density_unitless": 0.3, "speed_unitless": 0.8}
	var rebound := BINDING.new()
	var rebound_cues: Array[StringName] = []
	rebound.semantic_travel_cue_emitted.connect(func(cue_id: StringName, _intensity: float): rebound_cues.append(cue_id))
	_check(bool(rebound.attach(retained_session).get("accepted", false)), "retained session binding attaches")
	var rebound_snapshot := rebound.get_snapshot()
	var rebound_mix := rebound_snapshot.get("mix", {}) as Dictionary
	_check(rebound_cues.is_empty() and rebound_snapshot.last_state_id == &"ascent" and float(rebound_mix.get("wind_gain_unitless", 0.0)) > 0.0, "initial retained snapshot primes mix without replaying an ascent cue")
	retained_session.snapshot = {"generation": 9, "state_id": &"orbit_return", "atmosphere_density_unitless": 0.0, "speed_unitless": 0.5}
	retained_session.presentation_changed.emit(retained_session.snapshot)
	_check(rebound_cues == [&"planetary_orbit_return"], "next retained phase transition remains audible")
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
