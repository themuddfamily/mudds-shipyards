extends SceneTree

const Binding := preload("res://scripts/audio/cinder_cargo_terminal_audio_binding.gd")
const ActivityBinding := preload("res://scripts/world/nearby_sector_activity_binding.gd")

var _assertions := 0
var _failures := PackedStringArray()
var _cues: Array[StringName] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var audio := Binding.new()
	audio.semantic_terminal_cue_emitted.connect(func(cue_id: StringName, _terminal_id: StringName, _intensity: float) -> void: _cues.append(cue_id))
	_check(bool(audio.attach().accepted), "terminal audio attaches")
	for state in [&"unavailable", &"ready", &"carrying", &"at_terminal", &"committed", &"stale_rejected", &"reset"]:
		_check(bool(audio.present_snapshot({"terminal_id": &"cinder_destination", "terminal_generation": 1, "state_id": state}).accepted), "%s state is accepted" % state)
	_check(_cues.size() == 7, "terminal states emit one cue each")
	_check(bool(audio.present_snapshot({"terminal_id": &"cinder_destination", "terminal_generation": 1, "state_id": &"reset"}).accepted), "duplicate reset is accepted")
	_check(_cues.size() == 7, "duplicate terminal state does not spam")
	_check(int(audio.get_snapshot().maximum_simultaneous_voices) == 2, "terminal audio keeps two-voice ceiling")
	_check(bool(audio.detach().accepted), "terminal audio detaches")

	var production := ActivityBinding.new()
	production.add_child(Node3D.new())
	root.add_child(production)
	await process_frame
	var production_audio: Dictionary = production.get_cinder_cargo_terminal_audio_snapshot()
	_check(bool(production_audio.get("attached", false)), "NearbySectorActivityBinding composes terminal audio")
	_check(production_audio.get("authority", {}).get("inventory", true) == false, "terminal audio owns no inventory authority")
	production.queue_free()
	await process_frame
	for failure in _failures:
		push_error(failure)
	print("cinder_cargo_terminal_audio_integration_test: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
