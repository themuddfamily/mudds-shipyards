class_name EmberSurfaceLoopAudioComposition
extends Node

## Audio-only composition for a caller-owned Ember surface-loop owner. It owns
## one retained presentation adapter and one targeted planetary registration.

const AUDIO_BINDING := preload("res://scripts/audio/ember_surface_loop_audio_production_binding.gd")
const SOURCE_ID: StringName = &"planetary"

var _audio_director: Node
var _owner: Node
var _binding: Node
var _attached := false

func attach(audio_director: Node, owner: Node, perspective: StringName = &"exterior") -> Dictionary:
	if _attached:
		return _result(false, &"already_attached")
	if audio_director == null or not is_instance_valid(audio_director) \
			or not audio_director.has_method(&"bind_semantic_audio_source") \
			or not audio_director.has_method(&"unbind_semantic_audio_source"):
		return _result(false, &"audio_director_contract_missing")
	if owner == null or not is_instance_valid(owner) or not owner.has_method(&"get_snapshot"):
		return _result(false, &"owner_contract_missing")
	_audio_director = audio_director
	_owner = owner
	_binding = AUDIO_BINDING.new()
	add_child(_binding)
	var attached: Dictionary = _binding.attach(owner, perspective)
	if not bool(attached.get("accepted", false)):
		detach()
		return attached
	var bound: Dictionary = _audio_director.bind_semantic_audio_source(_binding, SOURCE_ID)
	if not bool(bound.get("accepted", false)):
		detach()
		return bound
	_attached = true
	return _result(true, &"attached")

func detach() -> Dictionary:
	if not _attached and _binding == null:
		return _result(true, &"already_detached")
	if _audio_director != null and is_instance_valid(_audio_director) and _binding != null:
		_audio_director.unbind_semantic_audio_source(_binding, SOURCE_ID)
	if _binding != null:
		_binding.detach()
		if is_instance_valid(_binding):
			remove_child(_binding)
			_binding.free()
	_audio_director = null
	_owner = null
	_binding = null
	_attached = false
	return _result(true, &"detached")

func get_snapshot() -> Dictionary:
	return {"attached": _attached, "binding": _binding.get_snapshot() if _binding != null else {"attached": false}, "authority": {"host": false, "movement": false, "landing": false, "audio_cues": true}}.duplicate(true)

func _exit_tree() -> void:
	detach()

func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {"accepted": accepted, "reason": reason}.duplicate(true)
