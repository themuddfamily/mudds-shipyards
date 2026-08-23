extends SceneTree

const AUDIO_DIRECTOR := preload("res://scripts/audio/audio_director.gd")
const STATION := preload("res://scripts/audio/station_defense_audio_binding.gd")
const CINDER := preload("res://scripts/audio/cinder_cargo_transfer_audio_binding.gd")

var _assertions := 0
var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var director := AUDIO_DIRECTOR.new()
	var events: Array[Dictionary] = []
	director.semantic_cue_emitted.connect(func(source_id: StringName, cue_id: StringName, intensity: float, position: Vector3): events.append({"source": source_id, "cue": cue_id, "intensity": intensity, "position": position}))
	var station := STATION.new()
	var cinder := CINDER.new()
	_check(bool(station.register_audio_director(director).get("accepted", false)), "station defense registers the director sink")
	_check(bool(cinder.attach().get("accepted", false)), "Cinder cargo binding attaches")
	_check(bool(cinder.register_audio_director(director).get("accepted", false)), "Cinder cargo registers the director sink")
	station.call("_emit_cue", &"station_defense_completed", &"station_wave", 1.0)
	cinder.present_transfer_receipt({"generation": 0, "transaction_id": &"cargo_tx", "event_id": &"pickup_accepted", "accepted": true})
	_check(events.size() == 2, "both production bindings forward normalized cues")
	_check(events[0].source == &"station_defense" and events[0].cue == &"station_defense_completed", "station cue uses normalized source and ID")
	_check(events[1].source == &"cinder_cargo" and events[1].cue == &"cargo_transfer_pickup_accepted", "cargo cue uses normalized source and ID")
	_check(events[0].position == Vector3.ZERO and is_equal_approx(float(events[1].intensity), 1.0), "normalized payload carries bounded position and intensity")
	_check(bool(station.unregister_audio_director().get("accepted", false)), "station deregisters on lifecycle end")
	_check(bool(cinder.unregister_audio_director().get("accepted", false)), "cargo deregisters on lifecycle end")
	_check(bool(cinder.detach().get("accepted", false)), "cargo detach remains clean after deregistration")
	if _failures.is_empty():
		print("PASS station_cinder_audio_director_integration_test (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
