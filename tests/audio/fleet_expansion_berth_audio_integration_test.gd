extends SceneTree

const Production := preload("res://scripts/world/fleet_expansion_production_binding.gd")
const AudioBinding := preload("res://scripts/audio/fleet_expansion_berth_audio_binding.gd")

var _events: Array[StringName] = []
var _assertions := 0
var _failures := PackedStringArray()

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var audio := AudioBinding.new()
	audio.semantic_berth_cue_emitted.connect(_on_cue)
	_check(bool(audio.attach().accepted), "expanded berth audio attaches")
	for pad_id in [&"dock_04_cargo", &"dock_05_bomber", &"dock_06_interceptor"]:
		_check(bool(audio.present_pad_snapshot({"pad_id": pad_id, "lease_state_id": &"available"}).accepted), "expanded pad approach is presented")
	_check(_events.size() == 3, "three expanded pad approach cues emit")
	_check(bool(audio.present_pad_snapshot({"pad_id": &"dock_04_cargo", "lease_state_id": &"occupied", "craft_id": &"cinder_cargo_hauler"}).accepted), "cargo pad secured cue emits")
	_check(bool(audio.present_release(&"dock_04_cargo", 1).accepted), "cargo pad release cue emits")
	_check(int(audio.get_snapshot().maximum_simultaneous_voices) == 2, "expanded berth audio keeps two-voice ceiling")

	var production := Production.new()
	root.add_child(production)
	await process_frame
	await process_frame
	var fleet := production.get_fleet_snapshot()
	_check(bool(fleet.berth_audio.attached), "production fleet composes expanded berth audio")
	_check(int(fleet.berth_audio.maximum_simultaneous_voices) == 2, "production berth audio remains bounded")
	_check(fleet.craft.size() == 3, "production fleet retains all three expanded craft")
	var released := production.detach_craft(&"cinder_cargo_hauler")
	_check(bool(released.accepted), "production cargo craft release reaches berth audio seam")
	production.queue_free()
	await process_frame
	for failure in _failures:
		push_error(failure)
	print("fleet_expansion_berth_audio_integration_test: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)

func _on_cue(cue_id: StringName, _pad_id: StringName, _intensity: float) -> void:
	_events.append(cue_id)

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
