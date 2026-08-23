extends SceneTree

const AudioBinding := preload("res://scripts/audio/jovian_copilot_navigation_audio_binding.gd")
const JovianScene := preload("res://scenes/ships/jovian_light_freighter.tscn")

var _events: Array[Dictionary] = []
var _assertions := 0
var _failures := PackedStringArray()

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var audio := AudioBinding.new()
	audio.semantic_copilot_cue_emitted.connect(_on_cue)
	_check(bool(audio.attach().accepted), "copilot audio binding attaches")
	_check(bool(audio.present_perspective(&"cockpit").accepted), "cockpit perspective is accepted")
	var receipt := {"role": &"copilot_navigation_support", "navigation_generation": 1,
		"request_sequence": 4, "route_id": &"jovian_freight_berth", "target_id": &"jovian_freight_berth"}
	_check(bool(audio.present_accepted_receipt(receipt).accepted), "accepted route receipt is presented")
	_check(_has(&"copilot_route_confirmed") and _events[0].perspective == &"cockpit", "route confirmation is cockpit-scoped")
	_check(bool(audio.present_accepted_receipt(receipt).accepted), "duplicate route receipt is safely accepted")
	_check(_events.size() == 1, "duplicate route receipt does not spam")
	_check(bool(audio.present_rejected_result({"reason": &"stale_sequence"}).accepted), "stale occupant result is presented")
	_check(_has(&"copilot_navigation_rejected"), "stale occupant cue emits")
	_check(bool(audio.present_cleared(2, &"role_handoff").accepted), "handoff clear is presented")
	_check(_has(&"copilot_navigation_reset"), "handoff/reset cue emits")
	_check(int(audio.get_snapshot().maximum_simultaneous_voices) == 2, "copilot cues keep two-voice ceiling")

	var craft := JovianScene.instantiate()
	root.add_child(craft)
	await process_frame
	await physics_frame
	_check(bool(craft.get_copilot_navigation_audio_snapshot().get("attached", false)), "production Jovian composes copilot audio binding")
	craft.queue_free()
	await process_frame
	for failure in _failures:
		push_error(failure)
	print("jovian_copilot_navigation_audio_integration_test: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)

func _on_cue(cue_id: StringName, intensity: float, perspective: StringName) -> void:
	_events.append({"cue_id": cue_id, "intensity": intensity, "perspective": perspective})

func _has(cue_id: StringName) -> bool:
	for event in _events:
		if event.cue_id == cue_id:
			return true
	return false

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
