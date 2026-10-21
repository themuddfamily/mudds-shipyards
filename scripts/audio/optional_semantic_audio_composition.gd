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
var _local_navigator_composition: Node
var _local_navigator_claim: Dictionary = {}
var _client_navigator_result_composition: Node
var _client_navigator_composition: Node
var _client_navigator_context: Dictionary = {}
var _client_navigator_generation := 0
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
	# `detach()` leaves both adapters parented and inert, exactly as the navigator
	# composition below is already retained. Re-creating them on every re-attach
	# instead added a second dead pair to this node on every whole-Main re-entry,
	# so a long session accumulated one abandoned loadmaster and final-approach
	# adapter per station re-entry and never released either.
	if _cinder_adapter == null or not is_instance_valid(_cinder_adapter):
		_cinder_adapter = CINDER_ADAPTER.new()
		_cinder_adapter.name = "CinderLoadmasterAudioProductionBinding"
		add_child(_cinder_adapter)
	if _final_approach_adapter == null or not is_instance_valid(_final_approach_adapter):
		_final_approach_adapter = FINAL_APPROACH_ADAPTER.new()
		_final_approach_adapter.name = "PlanetaryFinalApproachAudioProductionBinding"
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

# Bridge receipts and authorized physical local outcomes have independent
# owners. Changing the bridge generation must not retire a captured local clear.
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

func set_local_navigator_claim(claim: Dictionary) -> Dictionary:
	if not _attached:
		return _result(false, &"local_navigator_unavailable")
	if claim == _local_navigator_claim and _local_navigator_composition != null \
			and _local_navigator_composition.local_is_attached():
		return _result(true, &"local_navigator_unchanged")
	clear_local_navigator()
	if _local_navigator_composition == null or not is_instance_valid(_local_navigator_composition):
		_local_navigator_composition = NAVIGATOR_COMPOSITION.new()
		_local_navigator_composition.name = "CinderSoloNavigatorPingAudioComposition"
		add_child(_local_navigator_composition)
	var attached: Dictionary = _local_navigator_composition.attach_local(_audio_director, claim)
	if bool(attached.get("accepted", false)):
		_local_navigator_claim = claim.duplicate()
	return attached

func present_cinder_local_navigator_result(result: Dictionary, claim: Dictionary, sequence: int) -> Dictionary:
	if not _attached or claim != _local_navigator_claim or _local_navigator_composition == null:
		return _result(false, &"local_navigator_not_attached")
	return _local_navigator_composition.present_local_result(result, claim, sequence)

func retire_local_navigator_if_lost() -> void:
	if _local_navigator_composition != null and is_instance_valid(_local_navigator_composition):
		_local_navigator_composition.retire_local_if_lost()

func clear_local_navigator() -> void:
	if _local_navigator_composition != null and is_instance_valid(_local_navigator_composition):
		_local_navigator_composition.detach()
	_local_navigator_claim.clear()

func present_cinder_navigator_bridge_result(result: Dictionary) -> Dictionary:
	if not _attached or _navigator_generation <= 0 \
			or _navigator_composition == null or not is_instance_valid(_navigator_composition):
		return _result(false, &"navigator_not_attached")
	return _navigator_composition.present_bridge_result(result)

## This client source is independent of host generation and local ledger claims.
## The coordinator supplies an exact live adapter/craft/recipient context.
func set_client_navigator_context(context: Dictionary) -> void:
	if context == _client_navigator_context:
		return
	clear_client_navigator()
	if _attached:
		_client_navigator_context = context.duplicate()

func present_cinder_client_navigator_command(command: Dictionary, context: Dictionary) -> Dictionary:
	if not _attached or context.is_empty() or context != _client_navigator_context:
		return _result(false, &"client_navigator_context_mismatch")
	var captured_context := context.duplicate()
	var action := StringName(command.get("action", &""))
	if action != &"passenger_ping" and action != &"passenger_ping_clear":
		return _result(false, &"unsupported_client_command")
	var generation := int(command.get("ship_generation", 0))
	if _client_navigator_generation == 0:
		# Unknown clears cannot establish a source or manufacture acceptance.
		if action != &"passenger_ping" or generation <= 0:
			return _result(false, &"client_navigator_no_active_receipt")
		if _client_navigator_composition == null or not is_instance_valid(_client_navigator_composition):
			_client_navigator_composition = NAVIGATOR_COMPOSITION.new()
			_client_navigator_composition.name = "CinderClientNavigatorPingAudioComposition"
			add_child(_client_navigator_composition)
		var attached: Dictionary = _client_navigator_composition.attach(_audio_director, generation)
		if not bool(attached.get("accepted", false)):
			return attached
		var source: Node = _client_navigator_composition
		var presented: Dictionary = source.present_receipt(command)
		if not bool(presented.get("accepted", false)):
			source.detach()
			return presented
		if not _attached or captured_context != _client_navigator_context or source != _client_navigator_composition or not source._attached:
			return _result(false, &"client_navigator_retired_during_dispatch")
		_client_navigator_generation = generation
		return presented
	if generation != _client_navigator_generation:
		if generation < _client_navigator_generation or action != &"passenger_ping":
			return _result(false, &"client_navigator_ship_generation_mismatch")
		# A newer actual accepted publication may replace a bridge owner on the
		# same craft instance. Validate it through the existing binding before
		# retiring the old source; malformed data and unknown clears cannot do so.
		var previous_source: Node = _client_navigator_composition
		var replacement: Node = NAVIGATOR_COMPOSITION.new()
		add_child(replacement)
		var attached: Dictionary = replacement.attach(_audio_director, generation)
		if not bool(attached.get("accepted", false)):
			replacement.queue_free()
			return attached
		var presented: Dictionary = replacement.present_receipt(command)
		if not bool(presented.get("accepted", false)):
			replacement.detach()
			replacement.queue_free()
			return presented
		if not _attached or captured_context != _client_navigator_context or previous_source != _client_navigator_composition:
			replacement.detach()
			replacement.queue_free()
			return _result(false, &"client_navigator_retired_during_dispatch")
		previous_source.detach()
		previous_source.queue_free()
		_client_navigator_composition = replacement
		_client_navigator_generation = generation
		return presented
	if action == &"passenger_ping_clear":
		return _client_navigator_composition.present_receipt_clear(command)
	return _client_navigator_composition.present_receipt(command)

## Refusals can precede the first accepted wire receipt. Keep their lifetime
## independent so retiring a chair request cannot suppress its real clear.
func present_cinder_client_navigator_result(result: Dictionary, request: Dictionary, context: Dictionary) -> Dictionary:
	if not _attached or context.is_empty() or context != _client_navigator_context:
		return _result(false, &"client_navigator_context_mismatch")
	if _client_navigator_result_composition == null or not is_instance_valid(_client_navigator_result_composition):
		_client_navigator_result_composition = NAVIGATOR_COMPOSITION.new()
		_client_navigator_result_composition.name = "CinderClientNavigatorResultAudioComposition"
		add_child(_client_navigator_result_composition)
	if not _client_navigator_result_composition._attached:
		var attached: Dictionary = _client_navigator_result_composition.attach(_audio_director)
		if not bool(attached.get("accepted", false)):
			return attached
	return _client_navigator_result_composition.present_client_request_result(result, request)

func clear_client_navigator_results() -> void:
	if is_instance_valid(_client_navigator_result_composition):
		_client_navigator_result_composition.detach()

func clear_client_navigator() -> void:
	clear_client_navigator_results()
	if _client_navigator_composition != null and is_instance_valid(_client_navigator_composition):
		_client_navigator_composition.detach()
	_client_navigator_context.clear()
	_client_navigator_generation = 0

func detach() -> Dictionary:
	clear_client_navigator()
	if not _attached:
		return _result(true, &"already_detached")
	clear_local_navigator()
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
		"local_navigator": {
			"attached": _attached and _local_navigator_composition != null and _local_navigator_composition.local_is_attached(),
		},
		"client_navigator": {
			"attached": _attached and _client_navigator_generation > 0,
			"generation": _client_navigator_generation,
		},
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
