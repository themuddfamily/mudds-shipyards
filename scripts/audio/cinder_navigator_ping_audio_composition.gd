class_name CinderNavigatorPingAudioComposition
extends Node

const Binding := preload("res://scripts/audio/cinder_navigator_ping_audio_binding.gd")
var _director: Node
var _binding: Node
var _attached := false
var _local_claim: Dictionary = {}
var _local_clear_callback: Callable

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
	var bound: Dictionary = _director.bind_semantic_audio_source(_binding, &"navigator")
	if not bool(bound.get("accepted", false)):
		_binding.detach()
		_binding.queue_free()
		_binding = null
		_director = null
		return bound
	_attached = true
	return {"accepted": true, "reason": &"attached"}

func attach_local(director: Node, claim: Dictionary) -> Dictionary:
	var attached := attach(director)
	if not bool(attached.get("accepted", false)):
		return attached
	_binding.detach()
	var local_attached: Dictionary = _binding.attach_local(claim)
	if not bool(local_attached.get("accepted", false)):
		detach()
		return local_attached
	_local_claim = claim.duplicate()
	_local_clear_callback = _on_local_ping_cleared.bind(_local_claim.duplicate())
	_local_claim.craft.navigator_ping_cleared.connect(_local_clear_callback)
	return local_attached

func present_local_result(result: Dictionary, claim: Dictionary, sequence: int) -> Dictionary:
	return _binding.present_local_result(result, claim, sequence) if _attached else {"accepted": false, "reason": &"detached"}

func retire_local_if_lost() -> void:
	if not _attached or _local_claim.is_empty() or _binding.local_claim_is_current():
		return
	var craft: Variant = _local_claim.get("craft")
	# Leave the source registered until the ship's actual clear owner commits.
	if is_instance_valid(craft) and not (craft.get_navigator_ping_snapshot().get("receipt", {}) as Dictionary).is_empty():
		return
	detach()

func local_is_attached() -> bool:
	return _attached and not _local_claim.is_empty()

func _on_local_ping_cleared(previous: Dictionary, _reason: StringName, claim: Dictionary) -> void:
	if not _attached or claim != _local_claim:
		return
	_binding.present_local_clear(previous, claim)
	retire_local_if_lost()

func present_bridge_result(result: Dictionary) -> Dictionary:
	return _binding.present_bridge_result(result) if _attached else {"accepted": false, "reason": &"detached"}

func present_tombstones(tombstones: Array) -> Dictionary:
	return _binding.present_tombstones(tombstones) if _attached else {"accepted": false, "reason": &"detached"}

func detach() -> Dictionary:
	if not _attached:
		return {"accepted": true, "reason": &"already_detached"}
	_detach_internal(true)
	return {"accepted": true, "reason": &"detached"}

func _exit_tree() -> void:
	_detach_internal(false)

func _detach_internal(free_binding: bool) -> void:
	if not _attached:
		return
	var craft: Variant = _local_claim.get("craft")
	if is_instance_valid(craft) and craft.navigator_ping_cleared.is_connected(_local_clear_callback):
		craft.navigator_ping_cleared.disconnect(_local_clear_callback)
	_local_claim.clear()
	_local_clear_callback = Callable()
	if _director != null and is_instance_valid(_director) and _binding != null and is_instance_valid(_binding):
		_director.unbind_semantic_audio_source(_binding, &"navigator")
	if _binding != null and is_instance_valid(_binding):
		_binding.detach()
		if free_binding:
			_binding.queue_free()
	_binding = null
	_director = null
	_attached = false
