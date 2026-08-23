class_name PlanetaryFinalApproachAudioProductionBinding
extends Node

## Caller-injected production bridge for final-approach presentation records.
## Cruise, movement, landing, Host, and playback authority remain upstream.

signal semantic_surface_cue_emitted(cue_id: StringName, intensity: float)

const AUDIO_BINDING := preload("res://scripts/audio/planetary_final_approach_audio_binding.gd")

var _cruise: Node
var _audio: RefCounted
var _attached := false
var _generation := 0

func attach(cruise: Node, audio: RefCounted = null) -> Dictionary:
	if _attached:
		return _result(false, &"already_attached")
	if cruise == null or not is_instance_valid(cruise):
		return _result(false, &"invalid_cruise")
	for signal_name in [&"engagement_changed", &"tick_committed", &"final_approach_completed"]:
		if not cruise.has_signal(signal_name):
			return _result(false, &"signal_contract_missing")
	var binding: RefCounted = audio if audio != null else AUDIO_BINDING.new()
	if not binding.has_method(&"attach") or not binding.has_signal(&"semantic_cue_emitted"):
		return _result(false, &"audio_binding_contract_missing")
	var binding_generation := _generation
	if binding.has_method(&"get_snapshot"):
		binding_generation = int(binding.get_snapshot().get("generation", binding_generation))
	var attached: Dictionary = binding.attach(binding_generation)
	if not bool(attached.get("accepted", false)):
		return attached
	_cruise = cruise
	_audio = binding
	_cruise.connect(&"engagement_changed", _on_engagement_changed)
	_cruise.connect(&"tick_committed", _on_tick_committed)
	_cruise.connect(&"final_approach_completed", _on_completed)
	_audio.connect(&"semantic_cue_emitted", _on_audio_cue)
	_attached = true
	return _result(true, &"attached")

func detach() -> Dictionary:
	if not _attached:
		return _result(true, &"already_detached")
	if is_instance_valid(_cruise):
		for signal_name in [&"engagement_changed", &"tick_committed", &"final_approach_completed"]:
			var callback := _callback_for(signal_name)
			if _cruise.is_connected(signal_name, callback):
				_cruise.disconnect(signal_name, callback)
	if _audio != null and _audio.is_connected(&"semantic_cue_emitted", _on_audio_cue):
		_audio.disconnect(&"semantic_cue_emitted", _on_audio_cue)
	if _audio != null:
		_audio.detach()
	_cruise = null
	_audio = null
	_attached = false
	_generation += 1
	return _result(true, &"detached")

func get_snapshot() -> Dictionary:
	return {
		"attached": _attached,
		"generation": _generation,
		"audio": _audio.get_snapshot() if _audio != null else {"attached": false},
		"authority": {"cruise": false, "movement": false, "landing": false, "host": false, "audio_cues": true},
	}.duplicate(true)

func _exit_tree() -> void:
	detach()

func _on_engagement_changed(snapshot: Dictionary) -> void:
	if _attached:
		_audio.present_snapshot(snapshot)

func _on_tick_committed(receipt: Dictionary) -> void:
	if not _attached:
		return
	if not bool(receipt.get("accepted", false)) and receipt.has("target_generation"):
		var target_generation: Variant = receipt.get("target_generation", -1)
		if not target_generation is int or int(target_generation) < 0:
			return
		var reason := StringName(receipt.get("reason", &""))
		_audio.present_snapshot({"generation": int(receipt.get("generation", _generation)), "final_approach": {"target_generation": int(target_generation), "state_id": &"failed", "reason": reason}})

func _on_completed(receipt: Dictionary) -> void:
	if _attached:
		_audio.present_receipt(receipt)

func _on_audio_cue(_source_id: StringName, cue_id: StringName, intensity: float, _position: Vector3) -> void:
	semantic_surface_cue_emitted.emit(cue_id, clampf(intensity, 0.0, 1.0))

func _callback_for(signal_name: StringName) -> Callable:
	match signal_name:
		&"engagement_changed": return Callable(self, "_on_engagement_changed")
		&"tick_committed": return Callable(self, "_on_tick_committed")
		_: return Callable(self, "_on_completed")

func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {"accepted": accepted, "reason": reason, "generation": _generation}.duplicate(true)
