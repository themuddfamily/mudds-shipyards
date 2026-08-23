class_name OptionalSemanticAudioComposition
extends Node

## Optional presentation composition for caller-owned Cinder and Ember cruise
## sources. It owns adapters and router registration only; gameplay authority
## remains with the injected craft/cruise owners.

const CINDER_ADAPTER := preload("res://scripts/audio/cinder_loadmaster_audio_production_binding.gd")
const FINAL_APPROACH_ADAPTER := preload("res://scripts/audio/planetary_final_approach_audio_production_binding.gd")
const NAVIGATOR_COMPOSITION := preload("res://scripts/audio/cinder_navigator_ping_audio_composition.gd")

var _audio_director: Node
var _cinder_adapter: Node
var _final_approach_adapter: Node
var _navigator_composition: Node
var _cinder_craft: Node
var _cruise: Node
var _navigator_generation := 0
var _attached := false

func attach(
		audio_director: Node,
		cinder_craft: Node = null,
		cruise: Node = null,
		navigator_generation: int = 0
) -> Dictionary:
	if _attached:
		return _result(false, &"already_attached")
	if navigator_generation < 0:
		return _result(false, &"invalid_navigator_generation")
	if audio_director == null or not is_instance_valid(audio_director) \
			or not audio_director.has_method(&"bind_semantic_audio_source") \
			or not audio_director.has_method(&"unbind_semantic_audio_source"):
		return _result(false, &"audio_director_contract_missing")
	_audio_director = audio_director
	_cinder_adapter = CINDER_ADAPTER.new()
	_final_approach_adapter = FINAL_APPROACH_ADAPTER.new()
	add_child(_cinder_adapter)
	add_child(_final_approach_adapter)
	_attached = true
	var result := set_sources(cinder_craft, cruise)
	if not bool(result.get("accepted", false)):
		detach()
		return result
	result = set_navigator_generation(navigator_generation)
	if not bool(result.get("accepted", false)):
		detach()
		return result
	return _result(true, &"attached")

func set_sources(cinder_craft: Node = null, cruise: Node = null) -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	var result := _replace_cinder(cinder_craft)
	if not bool(result.get("accepted", false)):
		return result
	return _replace_cruise(cruise)

func present_cinder_rejected(result: Dictionary) -> Dictionary:
	if not _attached or _cinder_adapter == null:
		return _result(false, &"not_attached")
	return _cinder_adapter.present_rejected(result)

func set_navigator_generation(generation: int) -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	if generation < 0:
		return _result(false, &"invalid_navigator_generation")
	if generation == _navigator_generation:
		return _result(true, &"navigator_unchanged")
	if _navigator_composition != null and is_instance_valid(_navigator_composition):
		_navigator_composition.detach()
	_navigator_generation = 0
	if generation == 0:
		return _result(true, &"navigator_unbound")
	if _navigator_composition == null or not is_instance_valid(_navigator_composition):
		_navigator_composition = NAVIGATOR_COMPOSITION.new()
		_navigator_composition.name = "CinderNavigatorPingAudioComposition"
		add_child(_navigator_composition)
	var attached: Dictionary = _navigator_composition.attach(_audio_director, generation)
	if not bool(attached.get("accepted", false)):
		return attached
	_navigator_generation = generation
	return _result(true, &"navigator_bound")

func present_cinder_navigator_bridge_result(result: Dictionary) -> Dictionary:
	if not _attached or _navigator_generation <= 0 \
			or _navigator_composition == null or not is_instance_valid(_navigator_composition):
		return _result(false, &"navigator_not_attached")
	return _navigator_composition.present_bridge_result(result)

func detach() -> Dictionary:
	if not _attached:
		return _result(true, &"already_detached")
	_unbind(&"crew", _cinder_adapter)
	_unbind(&"planetary", _final_approach_adapter)
	if _navigator_composition != null and is_instance_valid(_navigator_composition):
		_navigator_composition.detach()
	if _cinder_adapter != null:
		_cinder_adapter.detach()
	if _final_approach_adapter != null:
		_final_approach_adapter.detach()
	_cinder_craft = null
	_cruise = null
	_navigator_generation = 0
	_audio_director = null
	_attached = false
	return _result(true, &"detached")

func get_snapshot() -> Dictionary:
	return {
		"attached": _attached,
		"cinder": _cinder_adapter.get_snapshot() if _cinder_adapter != null else {"attached": false},
		"final_approach": _final_approach_adapter.get_snapshot() if _final_approach_adapter != null else {"attached": false},
		"navigator": {
			"attached": _attached and _navigator_generation > 0,
			"generation": _navigator_generation,
			"presentation_only": true,
		},
		"authority": {
			"role": false,
			"cargo": false,
			"cruise": false,
			"movement": false,
			"network": false,
			"seat": false,
			"playback": false,
			"audio_cues": true,
		},
	}.duplicate(true)

func _replace_cinder(craft: Node) -> Dictionary:
	if _cinder_craft == craft:
		return _result(true, &"cinder_unchanged")
	_unbind(&"crew", _cinder_adapter)
	if _cinder_adapter.get_snapshot().get("attached", false):
		_cinder_adapter.detach()
	_cinder_craft = null
	if craft == null:
		return _result(true, &"cinder_unbound")
	var attached: Dictionary = _cinder_adapter.attach(craft)
	if not bool(attached.get("accepted", false)):
		return attached
	var bound: Dictionary = _audio_director.bind_semantic_audio_source(_cinder_adapter, &"crew")
	if not bool(bound.get("accepted", false)):
		_cinder_adapter.detach()
		return bound
	_cinder_craft = craft
	return _result(true, &"cinder_bound")

func _replace_cruise(cruise: Node) -> Dictionary:
	if _cruise == cruise:
		return _result(true, &"cruise_unchanged")
	_unbind(&"planetary", _final_approach_adapter)
	if _final_approach_adapter.get_snapshot().get("attached", false):
		_final_approach_adapter.detach()
	_cruise = null
	if cruise == null:
		return _result(true, &"cruise_unbound")
	var attached: Dictionary = _final_approach_adapter.attach(cruise)
	if not bool(attached.get("accepted", false)):
		return attached
	var bound: Dictionary = _audio_director.bind_semantic_audio_source(_final_approach_adapter, &"planetary")
	if not bool(bound.get("accepted", false)):
		_final_approach_adapter.detach()
		return bound
	_cruise = cruise
	return _result(true, &"cruise_bound")

func _unbind(source_id: StringName, source: Node) -> void:
	if _audio_director != null and is_instance_valid(_audio_director) and source != null:
		_audio_director.unbind_semantic_audio_source(source, source_id)

func _exit_tree() -> void:
	detach()

func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {"accepted": accepted, "reason": reason}.duplicate(true)
