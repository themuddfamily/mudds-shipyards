class_name CinderLoadmasterAudioProductionBinding
extends Node

## Caller-injected production bridge for Cinder's detached loadmaster receipts.
## Cinder remains the role/seat/manifest authority; this node only forwards
## accepted presentation records into the audio-owned binding.

signal semantic_cue_emitted(
		source_id: StringName,
		cue_id: StringName,
		intensity: float,
		world_position: Vector3,
	)
signal semantic_crew_cue_emitted(cue_id: StringName, role: StringName, intensity: float)

const AUDIO_BINDING := preload("res://scripts/audio/cinder_loadmaster_audio_binding.gd")
const SOURCE_ID: StringName = &"cinder_loadmaster"

var _craft: Node
var _audio: RefCounted
var _attached := false
var _generation := 0

func attach(craft: Node, audio: RefCounted = null) -> Dictionary:
	if _attached:
		return _result(false, &"already_attached")
	if craft == null or not is_instance_valid(craft):
		return _result(false, &"invalid_craft")
	if not craft.has_signal(&"loadmaster_manifest_intent_accepted") \
		or not craft.has_signal(&"loadmaster_manifest_cleared"):
		return _result(false, &"signal_contract_missing")
	var binding: RefCounted = audio if audio != null else AUDIO_BINDING.new()
	if not binding.has_method(&"attach") \
		or not binding.has_signal(&"semantic_loadmaster_cue_emitted"):
		return _result(false, &"audio_binding_contract_missing")
	var binding_generation := _generation
	if binding.has_method(&"get_snapshot"):
		binding_generation = int(binding.get_snapshot().get("generation", binding_generation))
	var attached: Dictionary = binding.attach(binding_generation)
	if not bool(attached.get("accepted", false)):
		return attached
	_craft = craft
	_audio = binding
	_craft.connect(&"loadmaster_manifest_intent_accepted", _on_manifest_accepted)
	_craft.connect(&"loadmaster_manifest_cleared", _on_manifest_cleared)
	_audio.connect(&"semantic_loadmaster_cue_emitted", _on_audio_cue)
	_attached = true
	return _result(true, &"attached")

func present_rejected(result: Dictionary) -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	return _audio.present_rejected(
		StringName(result.get("reason", &"")),
		int(result.get("request_sequence", -1)),
	)

func detach() -> Dictionary:
	if not _attached:
		return _result(true, &"already_detached")
	if is_instance_valid(_craft):
		if _craft.is_connected(&"loadmaster_manifest_intent_accepted", _on_manifest_accepted):
			_craft.disconnect(&"loadmaster_manifest_intent_accepted", _on_manifest_accepted)
		if _craft.is_connected(&"loadmaster_manifest_cleared", _on_manifest_cleared):
			_craft.disconnect(&"loadmaster_manifest_cleared", _on_manifest_cleared)
	if _audio != null and _audio.is_connected(&"semantic_loadmaster_cue_emitted", _on_audio_cue):
		_audio.disconnect(&"semantic_loadmaster_cue_emitted", _on_audio_cue)
	if _audio != null:
		_audio.detach()
	_craft = null
	_audio = null
	_attached = false
	_generation += 1
	return _result(true, &"detached")

func get_snapshot() -> Dictionary:
	return {
		"attached": _attached,
		"generation": _generation,
		"source_id": SOURCE_ID,
		"audio": _audio.get_snapshot() if _audio != null else {"attached": false},
		"authority": {"role": false, "seat": false, "manifest": false, "cargo": false, "audio_cues": true},
	}.duplicate(true)

func _exit_tree() -> void:
	detach()

func _on_manifest_accepted(receipt: Dictionary) -> void:
	if _attached:
		_audio.present_manifest_receipt(receipt)

func _on_manifest_cleared(generation: int, reason: StringName) -> void:
	if _attached:
		_audio.present_released(reason)

func _on_audio_cue(cue_id: StringName, intensity: float, _perspective: StringName) -> void:
	semantic_cue_emitted.emit(SOURCE_ID, cue_id, clampf(intensity, 0.0, 1.0), Vector3.ZERO)
	semantic_crew_cue_emitted.emit(cue_id, &"passenger", clampf(intensity, 0.0, 1.0))

func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {"accepted": accepted, "reason": reason, "generation": _generation}.duplicate(true)
