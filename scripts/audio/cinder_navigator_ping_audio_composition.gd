class_name CinderNavigatorPingAudioComposition
extends Node

const Binding := preload("res://scripts/audio/cinder_navigator_ping_audio_binding.gd")
var _director: Node
var _binding: Node
var _attached := false

func attach(director: Node, generation: int = 0) -> Dictionary:
	if _attached or director == null or not is_instance_valid(director):
		return {"accepted": false, "reason": &"invalid_or_attached"}
	if not director.has_method(&"bind_semantic_audio_source") or not director.has_method(&"unbind_semantic_audio_source"):
		return {"accepted": false, "reason": &"director_contract_missing"}
	_director = director
	_binding = Binding.new()
	add_child(_binding)
	var attached: Dictionary = _binding.attach(generation)
	if not bool(attached.get("accepted", false)):
		_binding.queue_free()
		_binding = null
		_director = null
		return attached
	var bound: Dictionary = _director.bind_semantic_audio_source(_binding, &"crew")
	if not bool(bound.get("accepted", false)):
		_binding.detach()
		_binding.queue_free()
		_binding = null
		_director = null
		return bound
	_attached = true
	return {"accepted": true, "reason": &"attached"}

func present_bridge_result(result: Dictionary) -> Dictionary:
	return _binding.present_bridge_result(result) if _attached else {"accepted": false, "reason": &"detached"}

func present_tombstones(tombstones: Array) -> Dictionary:
	return _binding.present_tombstones(tombstones) if _attached else {"accepted": false, "reason": &"detached"}

func detach() -> Dictionary:
	if not _attached:
		return {"accepted": true, "reason": &"already_detached"}
	_director.unbind_semantic_audio_source(_binding, &"crew")
	_binding.detach()
	_binding.queue_free()
	_binding = null
	_director = null
	_attached = false
	return {"accepted": true, "reason": &"detached"}
